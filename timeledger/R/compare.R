#' Split ledger rows at given times
#'
#' Adds breakpoints without changing any state, so all duration metrics are
#' unchanged. Useful before a learning period or a time-of-day restriction.
#'
#' @param ledger A `tl_ledger`.
#' @param at Either a numeric vector of times applied to every record, or a
#'   data frame with columns `record` and `time`.
#' @return The `tl_ledger` with the extra breakpoints.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' nrow(tl_split(led, 15))
#' @export
tl_split <- function(ledger, at) {
  stopifnot(inherits(ledger, "tl_ledger"))
  if (is.numeric(at)) {
    rec <- attr(ledger, "records")
    at <- expand.grid(record = rec$record, time = at,
                      stringsAsFactors = FALSE)
  }
  .require_cols(at, c("record", "time"), "at")
  L <- ledger
  for (i in seq_len(nrow(at))) {
    hit <- which(L$record == at$record[i] & L$start < at$time[i] &
                   L$end > at$time[i])
    if (!length(hit)) next
    right <- L[hit, ]
    right$start <- at$time[i]
    L$end[hit] <- at$time[i]
    L <- rbind(L, right)
  }
  L$duration <- L$end - L$start
  L <- L[order(L$record, L$detector, L$start), ]
  rownames(L) <- NULL
  keep_attr <- c("records", "reference_rows", "prediction_rows",
                 "observation_rows", "detectors", "settings", "issues",
                 "restrictions")
  at_attr <- attributes(ledger)
  for (a in intersect(keep_attr, names(at_attr))) attr(L, a) <- at_attr[[a]]
  class(L) <- c("tl_ledger", "data.frame")
  L
}

.subset_detectors <- function(ledger, detectors) {
  miss <- setdiff(detectors, attr(ledger, "detectors"))
  if (length(miss)) {
    stop(sprintf("Unknown detector(s): %s.", paste(miss, collapse = ", ")),
         call. = FALSE)
  }
  x <- ledger[ledger$detector %in% detectors, ]
  attr(x, "detectors") <- detectors
  x
}

#' Compare two detectors on own, shared and full time
#'
#' A common-time comparison can be fair for one question and still discard
#' the hard periods that matter for another. `tl_compare()` therefore reports
#' each detector on its own answered time, both detectors on the time when
#' both answered, and full-period quantities, and it states how much
#' reference-known time and how many eligible episodes the shared comparison
#' discards.
#'
#' @param ledger A `tl_ledger` with at least two detectors.
#' @param detectors The two detectors to compare.
#' @param ... Matching settings passed to [tl_match()].
#' @return An object of class `tl_compare`: a list with `own` and `shared`
#'   (`tl_metrics`), `own_match` and `shared_match` (`tl_match`),
#'   `shared_ledger`, `discarded` (time and episodes per detector) and
#'   `table` (pooled estimates side by side).
#' @examples
#' fx <- tl_fixture("two_detectors")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' cmp <- tl_compare(led, c("A", "B"))
#' cmp$table
#' cmp$discarded
#' @export
tl_compare <- function(ledger, detectors = attr(ledger, "detectors")[1:2],
                       ...) {
  stopifnot(length(detectors) == 2)
  led <- .subset_detectors(ledger, detectors)
  own_m <- tl_match(led, ...)
  own <- tl_metrics(led, own_m)
  ans <- led$response %in% .answered
  key <- .group_key(led$record, led$start)
  kA <- key[led$detector == detectors[1] & ans]
  kB <- key[led$detector == detectors[2] & ans]
  both <- key %in% intersect(kA, kB)
  shared_led <- tl_restrict(led, both, "outside shared answered time")
  sh_m <- tl_match(shared_led, ...)
  sh <- tl_metrics(shared_led, sh_m)
  disc <- do.call(rbind, lapply(detectors, function(d) {
    o <- own_m$episodes[own_m$episodes$detector == d, ]
    s <- sh_m$episodes[sh_m$episodes$detector == d, ]
    lost <- o$episode_id[o$eligible & !(o$episode_id %in% s$episode_id[s$eligible])]
    kn_own <- sum(led$duration[led$detector == d & led$reference != "unknown"])
    kn_sh <- sum(shared_led$duration[shared_led$detector == d &
                                       shared_led$reference != "unknown"])
    ev_own <- sum(led$duration[led$detector == d & led$reference == "event"])
    ev_sh <- sum(shared_led$duration[shared_led$detector == d &
                                       shared_led$reference == "event"])
    data.frame(detector = d, known_time_own = kn_own,
               known_time_shared = kn_sh,
               known_time_discarded = kn_own - kn_sh,
               event_time_discarded = ev_own - ev_sh,
               episodes_eligible_own = sum(o$eligible),
               episodes_eligible_shared = sum(s$eligible),
               episodes_discarded = length(lost),
               discarded_episode_ids = paste(lost, collapse = ";"),
               stringsAsFactors = FALSE)
  }))
  pick <- function(m, nm) {
    p <- m[m$level == "pooled", ]
    p$estimate[match(paste(detectors, nm), paste(p$detector, p$metric))]
  }
  mets <- unique(own$metric)
  tab <- do.call(rbind, lapply(mets, function(nm) {
    data.frame(metric = nm,
               own_1 = pick(own, nm)[1], own_2 = pick(own, nm)[2],
               shared_1 = pick(sh, nm)[1], shared_2 = pick(sh, nm)[2],
               stringsAsFactors = FALSE)
  }))
  names(tab) <- c("metric", paste0("own_", detectors), paste0("shared_", detectors))
  structure(list(own = own, shared = sh, own_match = own_m,
                 shared_match = sh_m, shared_ledger = shared_led,
                 discarded = disc, table = tab, detectors = detectors),
            class = "tl_compare")
}

#' @export
print.tl_compare <- function(x, ...) {
  cat(sprintf("<tl_compare> %s vs %s\n", x$detectors[1], x$detectors[2]))
  print(x$table, row.names = FALSE, digits = 4)
  cat("\nDiscarded by restricting to shared answered time:\n")
  print(x$discarded[, c("detector", "known_time_discarded",
                        "event_time_discarded", "episodes_discarded")],
        row.names = FALSE)
  invisible(x)
}

#' Cluster bootstrap for pooled metrics and paired differences
#'
#' Resamples subjects (not seconds, windows, beats or episodes) with
#' replacement and recomputes pooled metrics from the per-record
#' contributions. All detectors share the same resampled subjects, so
#' differences between detectors are paired. Replicates whose denominator is
#' zero are undefined; they are counted and left out of the percentile
#' interval.
#'
#' @param contributions Output of [tl_contributions()], possibly row-bound
#'   across several ledgers that share subjects.
#' @param metrics Metric names from [tl_metrics()] whose numerator and
#'   denominator are both additive (all ratio metrics are).
#' @param B Number of bootstrap replicates.
#' @param conf Confidence level of the percentile interval.
#' @param summary `"pooled"` (ratio of resampled sums) or `"record_mean"`
#'   (mean of per-record ratios over the resampled records).
#' @param seed Optional random seed.
#' @return A data frame with one row per detector (and per difference
#'   between the first detector and each other one) and metric:
#'   `estimate`, `lower`, `upper`, `B`, `n_undefined`, `n_subjects`.
#' @examples
#' fx <- tl_fixture("two_detectors")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' cb <- tl_contributions(led, tl_match(led))
#' tl_bootstrap(cb, c("full_capture", "answer_coverage"), B = 200, seed = 1)
#' @export
tl_bootstrap <- function(contributions, metrics, B = 2000, conf = 0.95,
                         summary = c("pooled", "record_mean"), seed = NULL) {
  summary <- match.arg(summary)
  cb <- contributions
  tu <- attr(cb, "time_unit")
  if (is.null(tu)) tu <- "s"
  cb$unmatched <- if (!is.null(cb$alarms_false)) cb$alarms_false + cb$alarms_redundant else NA
  cb$burden_diff <- cb$positive_known - cb$event_answered
  cb$positive_or_unanswered <- cb$positive_target + cb$unanswered
  defs <- .metric_defs(tu)
  names(defs) <- vapply(defs, `[[`, "", 1)
  bad <- setdiff(metrics, names(defs))
  if (length(bad)) stop(sprintf("Unknown or non-ratio metric(s): %s.",
                                paste(bad, collapse = ", ")), call. = FALSE)
  if (!is.null(seed)) set.seed(seed)
  subj <- sort(unique(cb$subject))
  ns <- length(subj)
  W <- matrix(0L, ns, B)
  for (b in seq_len(B)) {
    W[, b] <- tabulate(sample.int(ns, ns, replace = TRUE), ns)
  }
  dets <- unique(cb$detector)
  alpha <- (1 - conf) / 2
  stat_for <- function(x, def) {
    num <- x[[def[[2]]]]
    den <- x[[def[[3]]]]
    si <- match(x$subject, subj)
    if (summary == "pooled") {
      Sn <- as.numeric(tapply(num, factor(si, levels = seq_len(ns)), sum))
      Sd <- as.numeric(tapply(den, factor(si, levels = seq_len(ns)), sum))
      Sn[is.na(Sn)] <- 0
      Sd[is.na(Sd)] <- 0
      est <- if (sum(Sd) > 0) sum(Sn) / sum(Sd) * def[[5]] else NA_real_
      tn <- colSums(W * Sn)
      td <- colSums(W * Sd)
      rep <- ifelse(td > 0, tn / td * def[[5]], NA_real_)
    } else {
      r <- ifelse(den > 0, num / den * def[[5]], NA_real_)
      ok <- !is.na(r)
      est <- if (any(ok)) mean(r[ok]) else NA_real_
      # Weight each record by how many times its subject was drawn.
      Wr <- W[si, , drop = FALSE] * ok
      rr <- ifelse(ok, r, 0)
      cnt <- colSums(Wr)
      rep <- ifelse(cnt > 0, colSums(Wr * rr) / cnt, NA_real_)
    }
    list(est = est, rep = rep)
  }
  rows <- list()
  for (m in metrics) {
    def <- defs[[m]]
    res <- lapply(dets, function(d) stat_for(cb[cb$detector == d, ], def))
    names(res) <- dets
    for (d in dets) {
      rows[[length(rows) + 1]] <- .boot_row(d, m, res[[d]]$est,
                                            res[[d]]$rep, alpha, B, ns)
    }
    for (d in dets[-1]) {
      rows[[length(rows) + 1]] <- .boot_row(
        paste(d, "-", dets[1]), m, res[[d]]$est - res[[dets[1]]]$est,
        res[[d]]$rep - res[[dets[1]]]$rep, alpha, B, ns)
    }
  }
  out <- do.call(rbind, rows)
  attr(out, "summary") <- summary
  out
}

.boot_row <- function(name, metric, est, rep, alpha, B, ns) {
  ok <- !is.na(rep)
  q <- if (any(ok)) stats::quantile(rep[ok], c(alpha, 1 - alpha),
                                    names = FALSE) else c(NA, NA)
  data.frame(detector = name, metric = metric, estimate = est,
             lower = q[1], upper = q[2], B = B, n_undefined = sum(!ok),
             n_subjects = ns, stringsAsFactors = FALSE)
}
