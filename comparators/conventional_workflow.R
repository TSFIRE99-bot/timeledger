# The strongest conventional workflow an experienced R user could reasonably
# write without timeledger, applied to the same predictions and definitions.
#
# Interval arithmetic uses a sort-and-sweep helper (`ov`) that does what
# ivs::iv_set_intersect() or IRanges::intersect() would do. Those packages
# could not be loaded on the development machine (compiled code blocked by
# the operating system's application control policy), so the helper is
# written in base R; it is checked against brute-force expansion below.
#
# Two plausible analysts are implemented. Both are reasonable; they differ in
# one decision each about time that has no answer.
#   conv_fill: time without a positive answer is "no AF" (abstention, lost
#              input and missing rows all become negatives); the denominator
#              is the whole recording. This is what writing predictions into a
#              WFDB test annotation file forces.
#   conv_drop: unanswered time is removed (the na.rm = TRUE habit); all rates
#              use answered time.
# Both follow the WFDB convention that time before the first rhythm
# annotation is not AF, because nothing in the files says otherwise.
#
# Usage: Rscript comparators/conventional_workflow.R
source("analysis/common.R")

# Total overlap of two sets of disjoint intervals [s, e).
ov <- function(as, ae, bs, be) {
  if (!length(as) || !length(bs)) return(0)
  bp <- sort(unique(c(as, ae, bs, be)))
  st <- bp[-length(bp)]
  en <- bp[-1]
  ia <- findInterval(st, as)
  ib <- findInterval(st, bs)
  ina <- ia > 0 & st < ae[pmax(ia, 1)]
  inb <- ib > 0 & st < be[pmax(ib, 1)]
  sum((en - st)[ina & inb])
}
# Runs of TRUE rows of a sorted interval table, merged when adjacent.
runs <- function(s, e) {
  if (!length(s)) return(list(s = numeric(), e = numeric()))
  new <- c(TRUE, s[-1] != e[-length(e)])
  g <- cumsum(new)
  list(s = as.numeric(tapply(s, g, min)), e = as.numeric(tapply(e, g, max)))
}
any_ov <- function(s1, e1, s2, e2) {
  # For each interval 1, does it overlap any interval 2 (positive length)?
  vapply(seq_along(s1), function(i) any(s2 < e1[i] & e2 > s1[i]), TRUE)
}

conventional <- function(db, mode = c("fill", "drop")) {
  mode <- match.arg(mode)
  out <- list()
  for (r in db$records$record) {
    T_end <- db$records$end[db$records$record == r]
    ref <- db$reference[db$reference$record == r, ]
    afr <- runs(ref$start[ref$label == "(AFIB"], ref$end[ref$label == "(AFIB"])
    for (d in unique(db$predictions$detector)) {
      p <- db$predictions[db$predictions$record == r & db$predictions$detector == d, ]
      p <- p[order(p$start), ]
      pos <- runs(p$start[p$response == "positive"], p$end[p$response == "positive"])
      ans <- runs(p$start[p$response %in% c("positive", "negative")],
                  p$end[p$response %in% c("positive", "negative")])
      if (mode == "fill") {
        den_time <- T_end
        af_den <- sum(afr$e - afr$s)
        tp <- ov(afr$s, afr$e, pos$s, pos$e)
        elig <- rep(TRUE, length(afr$s))
      } else {
        den_time <- sum(ans$e - ans$s)
        af_den <- ov(afr$s, afr$e, ans$s, ans$e)
        tp <- ov(afr$s, afr$e, pos$s, pos$e)
        elig <- vapply(seq_along(afr$s), function(i)
          ov(afr$s[i], afr$e[i], ans$s, ans$e) > 0, TRUE)
      }
      # Episodes: >= 30 s of AF (same eligibility rule as the primary analysis).
      long <- (afr$e - afr$s) >= 30
      det <- any_ov(afr$s, afr$e, pos$s, pos$e)
      fa <- !any_ov(pos$s, pos$e, afr$s, afr$e)
      out[[length(out) + 1]] <- data.frame(
        record = r, detector = d, analysis = paste0("conv_", mode),
        time_den = den_time, af_den = af_den, tp = tp,
        pos_time = sum(pos$e - pos$s),
        episodes = sum(elig & long), detected = sum(elig & long & det),
        alarms = length(pos$s), false_alarms = sum(fa))
    }
  }
  do.call(rbind, out)
}

pool <- function(x) {
  a <- aggregate(cbind(time_den, af_den, tp, pos_time, episodes, detected,
                       false_alarms) ~ detector + analysis, data = x, FUN = sum)
  data.frame(detector = a$detector, analysis = a$analysis,
             sensitivity = a$tp / a$af_den,
             episode_sensitivity = a$detected / a$episodes,
             false_alarms_per_hour = a$false_alarms / (a$time_den / 3600),
             hours_in_denominator = a$time_den / 3600)
}

# Check the sweep helper against brute-force expansion.
set.seed(3)
for (k in 1:200) {
  g <- sort(sample(0:60, 8))
  h <- sort(sample(0:60, 8))
  a <- matrix(g, ncol = 2, byrow = TRUE)
  b <- matrix(h, ncol = 2, byrow = TRUE)
  a <- a[a[, 2] > a[, 1], , drop = FALSE]
  b <- b[b[, 2] > b[, 1], , drop = FALSE]
  cells <- 0:59 + 0.5
  inA <- vapply(cells, function(t) any(t > a[, 1] & t < a[, 2]), TRUE)
  inB <- vapply(cells, function(t) any(t > b[, 1] & t < b[, 2]), TRUE)
  stopifnot(ov(a[, 1], a[, 2], b[, 1], b[, 2]) == sum(inA & inB))
}

rows <- list()
for (db_name in c("afdb", "ltafdb")) {
  db <- load_database(file.path("rawdata", db_name))
  cf <- conventional(db, "fill")
  cd <- conventional(db, "drop")
  conv <- rbind(pool(cf), pool(cd))
  led <- readRDS(file.path("results", db_name, "ledger.rds"))
  mm <- readRDS(file.path("results", db_name, "match_compare.rds"))$m1
  met <- tl_metrics(led, mm, level = "pooled")
  g <- function(d, nm) met$estimate[met$detector == d & met$metric == nm]
  tl <- do.call(rbind, lapply(unique(met$detector), function(d) rbind(
    data.frame(detector = d, analysis = "timeledger_full_period",
               sensitivity = g(d, "full_capture"),
               episode_sensitivity = g(d, "episode_sensitivity"),
               false_alarms_per_hour = g(d, "false_alarms_per_known_hour"),
               hours_in_denominator = met$denominator[met$detector == d &
                                                        met$metric == "answer_coverage"] / 3600),
    data.frame(detector = d, analysis = "timeledger_answered_time",
               sensitivity = g(d, "answered_sensitivity"),
               episode_sensitivity = NA,
               false_alarms_per_hour = g(d, "false_alarms_per_answered_hour"),
               hours_in_denominator = met$denominator[met$detector == d &
                                                        met$metric == "false_alarms_per_answered_hour"] / 3600))))
  both <- rbind(conv, tl)
  both$database <- db_name
  rows[[db_name]] <- both
}
res <- do.call(rbind, rows)
res <- res[order(res$database, res$analysis, res$detector), ]
dir.create("results/comparators", showWarnings = FALSE)
write.csv(res, "results/comparators/conventional_vs_timeledger.csv", row.names = FALSE)
print(res, digits = 4, row.names = FALSE)
