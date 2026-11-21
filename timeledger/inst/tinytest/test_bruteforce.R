# Independent brute-force implementation on small random integer timelines.
# It expands every record to one cell per time unit and computes everything
# from those cells, sharing no code with the interval engine.

bf_runs <- function(x) {
  # Maximal runs of TRUE in a logical vector: start (0-based) and end.
  r <- rle(x)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths
  data.frame(start = starts[r$values], end = ends[r$values])
}

bf_one_to_one <- function(ep, al, ov) {
  # Exhaustive search over all matchings. ov[i, j] is the overlap between
  # episode i and alarm j. Objective: number of pairs, then total overlap,
  # then prefer the set whose time-ordered pair indices are smallest when
  # compared from the latest pair backwards.
  ne <- nrow(ep)
  na <- nrow(al)
  best <- list(n = 0, tot = 0, pairs = matrix(integer(), 0, 2))
  edges <- which(ov > 0, arr.ind = TRUE)
  if (!nrow(edges)) return(best$pairs)
  edges <- edges[order(ep$start[edges[, 1]], al$start[edges[, 2]]), , drop = FALSE]
  m <- nrow(edges)
  key_of <- function(sel) sort(sel, decreasing = TRUE)
  better <- function(sel, cur) {
    n1 <- length(sel)
    t1 <- sum(ov[edges[sel, , drop = FALSE]])
    if (n1 != cur$n) return(n1 > cur$n)
    if (abs(t1 - cur$tot) > 1e-9) return(t1 > cur$tot)
    a <- key_of(sel)
    b <- key_of(cur$sel)
    for (k in seq_along(a)) if (a[k] != b[k]) return(a[k] < b[k])
    FALSE
  }
  cur <- list(n = 0, tot = 0, sel = integer())
  rec <- function(k, sel, used_e, used_a) {
    if (k > m) {
      if (better(sel, cur)) {
        cur <<- list(n = length(sel), tot = sum(ov[edges[sel, , drop = FALSE]]),
                     sel = sel)
      }
      return(invisible())
    }
    rec(k + 1, sel, used_e, used_a)
    e <- edges[k, 1]
    a <- edges[k, 2]
    if (!(e %in% used_e) && !(a %in% used_a)) {
      rec(k + 1, c(sel, k), c(used_e, e), c(used_a, a))
    }
  }
  rec(1, integer(), integer(), integer())
  edges[cur$sel, , drop = FALSE]
}

bf_eval <- function(Tn, ref_lab, resp) {
  ev <- ref_lab == "AF"
  known <- ref_lab != "unknown"
  ans <- resp %in% c("positive", "negative")
  pos <- resp == "positive"
  ep <- bf_runs(ev)
  al <- bf_runs(pos)
  ov <- matrix(0, nrow(ep), nrow(al))
  for (i in seq_len(nrow(ep))) for (j in seq_len(nrow(al))) {
    cells <- seq_len(Tn) > ep$start[i] & seq_len(Tn) <= ep$end[i] &
      seq_len(Tn) > al$start[j] & seq_len(Tn) <= al$end[j]
    ov[i, j] <- sum(cells & ev & pos)
  }
  pairs <- bf_one_to_one(ep, al, ov)
  any_ev <- vapply(seq_len(nrow(al)), function(j) any(ov[, j] > 0), TRUE)
  matched <- seq_len(nrow(al)) %in% pairs[, 2]
  al_known <- vapply(seq_len(nrow(al)), function(j) {
    sum(known[(al$start[j] + 1):al$end[j]])
  }, 0)
  false <- !any_ev & !matched & al_known > 0
  list(answered = sum(known & ans), known = sum(known), tp = sum(ev & pos),
       event = sum(ev), event_answered = sum(ev & ans),
       positive_known = sum(pos & known), positive_target = sum(pos),
       unanswered = sum(!ans), episodes = nrow(ep),
       detected = length(unique(pairs[, 1])),
       detected_any = sum(rowSums(ov > 0) > 0),
       alarms_false = sum(false), alarms_redundant = sum(any_ev & !matched),
       pairs = pairs, ep = ep, al = al)
}

to_intervals <- function(lab) {
  r <- rle(lab)
  ends <- cumsum(r$lengths)
  data.frame(start = ends - r$lengths, end = ends, value = r$values,
             stringsAsFactors = FALSE)
}

set.seed(20261120)
n_cases <- 300
mismatch <- 0
for (case in seq_len(n_cases)) {
  Tn <- sample(5:40, 1)
  ref_lab <- sample(c("AF", "N", "unknown"), Tn, replace = TRUE,
                    prob = c(0.35, 0.5, 0.15))
  # Make runs longer so that episodes and alarms have structure.
  ref_lab <- rep(ref_lab, each = 1)[seq_len(Tn)]
  resp <- sample(c("positive", "negative", "abstain", "unknown"), Tn,
                 replace = TRUE, prob = c(0.35, 0.45, 0.1, 0.1))
  bf <- bf_eval(Tn, ref_lab, resp)
  ri <- to_intervals(ref_lab)
  ref <- data.frame(record = "r", start = ri$start, end = ri$end,
                    label = ri$value)
  pi <- to_intervals(resp)
  pi <- pi[pi$value != "unknown", ]
  prd <- data.frame(record = "r", detector = "D", start = pi$start,
                    end = pi$end, response = pi$value)
  # Randomly split some prediction rows: results must not change.
  if (nrow(prd) && runif(1) < 0.5) {
    k <- sample(nrow(prd), 1)
    if (prd$end[k] - prd$start[k] >= 2) {
      mid <- prd$start[k] + 1
      extra <- prd[k, ]
      extra$start <- mid
      prd$end[k] <- mid
      prd <- rbind(prd, extra)
    }
  }
  if (!nrow(prd)) next
  led <- tl_ledger(tl_records("r", 0, Tn), ref, prd[sample(nrow(prd)), ],
                   event = "AF", unknown = "unknown", time_unit = "min")
  m <- tl_match(led)
  cb <- tl_contributions(led, m)
  ok <- c(cb$answered == bf$answered, cb$known == bf$known, cb$tp == bf$tp,
          cb$event == bf$event, cb$event_answered == bf$event_answered,
          cb$positive_known == bf$positive_known,
          cb$positive_target == bf$positive_target,
          cb$unanswered == bf$unanswered,
          cb$episodes_eligible == bf$episodes,
          cb$episodes_detected == bf$detected,
          cb$alarms_false == bf$alarms_false,
          cb$alarms_redundant == bf$alarms_redundant)
  # Same pairs, not only the same count.
  if (nrow(bf$pairs)) {
    eid <- sprintf("r:e%03d", bf$pairs[, 1])
    aid <- sprintf("r:D:a%03d", bf$pairs[, 2])
    ok <- c(ok, setequal(paste(eid, aid), paste(m$pairs$episode_id, m$pairs$alarm_id)))
  } else {
    ok <- c(ok, nrow(m$pairs) == 0)
  }
  ma <- tl_match(led, policy = "any_overlap")
  ok <- c(ok, sum(ma$episodes$detected) == bf$detected_any)
  if (!all(ok)) mismatch <- mismatch + 1
}
expect_equal(mismatch, 0)
