#' Small worked examples with known answers
#'
#' * `"acceptance"`: a 100-minute recording with complete reference. True
#'   AF on `[10, 20)` and `[40, 60)`; the detector flags
#'   `[10, 20)` and `[70, 80)`, abstains on `[40, 60)` and
#'   otherwise answers "no AF". Under one-to-one positive-overlap matching:
#'   answer coverage 80%, answered-time sensitivity 100%, full-period capture
#'   33.3%, episode detection 1/2, one unmatched alarm, 0.75 false alarms per
#'   answered hour, predicted burden 25% and reference burden 12.5% on
#'   answered time, and full-period predicted burden between 20% and 40%.
#' * `"burden_mismatch"`: predicted and reference AF durations are equal
#'   (20 minutes each) but never overlap, so the burden error is zero while
#'   no AF time is captured.
#' * `"two_detectors"`: detector A answers throughout; detector B declines
#'   during the hardest period. B looks better on its own answered time and
#'   captures less AF over the full period.
#'
#' Times are in minutes; build the ledger with `time_unit = "min"`.
#'
#' @param name Fixture name.
#' @return A list with `records`, `reference` and `predictions`.
#' @examples
#' str(tl_fixture("acceptance"))
#' @export
tl_fixture <- function(name = c("acceptance", "burden_mismatch",
                                "two_detectors")) {
  name <- match.arg(name)
  rec <- tl_records("rec1", start = 0, end = 100)
  if (name == "acceptance") {
    ref <- data.frame(record = "rec1", start = c(0, 10, 20, 40, 60),
                      end = c(10, 20, 40, 60, 100),
                      label = c("non-AF", "AF", "non-AF", "AF", "non-AF"))
    prd <- data.frame(record = "rec1", detector = "D",
                      start = c(0, 10, 20, 40, 60, 70, 80),
                      end = c(10, 20, 40, 60, 70, 80, 100),
                      response = c("negative", "positive", "negative",
                                   "abstain", "negative", "positive",
                                   "negative"),
                      reason = c(NA, NA, NA, "low signal quality", NA, NA, NA))
  } else if (name == "burden_mismatch") {
    ref <- data.frame(record = "rec1", start = c(0, 10, 30),
                      end = c(10, 30, 100),
                      label = c("non-AF", "AF", "non-AF"))
    prd <- data.frame(record = "rec1", detector = "D",
                      start = c(0, 50, 70), end = c(50, 70, 100),
                      response = c("negative", "positive", "negative"))
  } else {
    ref <- data.frame(record = "rec1", start = c(0, 10, 20, 40, 60, 85),
                      end = c(10, 20, 40, 60, 85, 100),
                      label = c("non-AF", "AF", "non-AF", "AF", "non-AF",
                                "AF"))
    prd <- rbind(
      data.frame(record = "rec1", detector = "A",
                 start = c(0, 12, 20, 42, 58, 70, 75, 85, 90),
                 end = c(12, 20, 42, 58, 70, 75, 85, 90, 100),
                 response = c("negative", "positive", "negative", "positive",
                              "negative", "positive", "negative", "negative",
                              "positive"), reason = NA),
      data.frame(record = "rec1", detector = "B",
                 start = c(0, 11, 20, 35, 65, 85, 88),
                 end = c(11, 20, 35, 65, 85, 88, 100),
                 response = c("negative", "positive", "negative", "abstain",
                              "negative", "negative", "positive"),
                 reason = c(NA, NA, NA, "low signal quality", NA, NA, NA)))
  }
  list(records = rec, reference = ref, predictions = prd)
}

#' Turn window decisions into prediction intervals
#'
#' Detectors usually score windows. How a window's decision becomes an
#' interval is an analysis choice that changes the results, so it is made
#' explicit here.
#'
#' * `mode = "hold"` (real time): a decision issued at `decided_at` holds
#'   from that moment until the next decision of the same record and
#'   detector, or for at most `max_hold`. This uses no future signal.
#' * `mode = "window"` (retrospective): each decision is assigned to its own
#'   window `[window_start, window_end)`. Where windows overlap, the
#'   window decided last wins. Window ends must increase with window starts.
#'
#' Time not covered by any decision gets no row; its meaning is then set by
#' the `missing` argument of [tl_ledger()], unless `gap_response` is given.
#'
#' @param record,detector Identifiers (recycled).
#' @param decided_at Time each decision became available.
#' @param response `"positive"`, `"negative"` or `"abstain"`.
#' @param window_start,window_end Window bounds (needed for
#'   `mode = "window"`).
#' @param reason Optional reason for each decision (e.g. why it abstained).
#' @param mode `"hold"` or `"window"`.
#' @param max_hold Longest time a held decision stays valid.
#' @param until Optional end of each record (recycled over records in order
#'   of first appearance, or named by record). The last held decision of a
#'   record stays valid until `until` or for `max_hold`, whichever comes
#'   first; with neither, the last decision has no defined end and is
#'   dropped.
#' @param gap_response Optional response for uncovered time between the
#'   first and last decision (e.g. `"abstain"`).
#' @param gap_reason Reason stored with `gap_response` rows.
#' @return A prediction table for [tl_ledger()] with an `issued_at` column.
#' @examples
#' tl_from_windows("r1", "D", decided_at = c(10, 20, 30),
#'                 response = c("negative", "positive", "negative"),
#'                 max_hold = 15)
#' @export
tl_from_windows <- function(record, detector, decided_at, response,
                            window_start = NULL, window_end = NULL,
                            reason = NA_character_,
                            mode = c("hold", "window"), max_hold = Inf,
                            until = NULL, gap_response = NULL,
                            gap_reason = "no current decision") {
  mode <- match.arg(mode)
  n <- length(decided_at)
  d <- data.frame(record = rep_len(as.character(record), n),
                  detector = rep_len(as.character(detector), n),
                  decided_at = as.numeric(decided_at),
                  response = rep_len(as.character(response), n),
                  reason = rep_len(as.character(reason), n),
                  stringsAsFactors = FALSE)
  if (mode == "window") {
    if (is.null(window_start) || is.null(window_end)) {
      stop("`mode = \"window\"` needs `window_start` and `window_end`.",
           call. = FALSE)
    }
    d$ws <- rep_len(as.numeric(window_start), n)
    d$we <- rep_len(as.numeric(window_end), n)
  }
  recs <- unique(d$record)
  if (!is.null(until) && is.null(names(until))) {
    until <- stats::setNames(rep_len(as.numeric(until), length(recs)), recs)
  }
  out <- lapply(split(d, list(d$record, d$detector), drop = TRUE), function(x) {
    if (mode == "hold") {
      x <- x[order(x$decided_at), ]
      last_end <- if (!is.null(until) && x$record[1] %in% names(until)) {
        until[[x$record[1]]]
      } else Inf
      nxt <- c(x$decided_at[-1], last_end)
      end <- pmin(nxt, x$decided_at + max_hold)
      p <- data.frame(record = x$record, detector = x$detector,
                      start = x$decided_at, end = end,
                      response = x$response, reason = x$reason,
                      issued_at = x$decided_at, stringsAsFactors = FALSE)
      p <- p[is.finite(p$end) & p$end > p$start, ]
    } else {
      x <- x[order(x$ws, x$decided_at), ]
      if (is.unsorted(x$we)) {
        stop("Window ends must increase with window starts.", call. = FALSE)
      }
      bp <- sort(unique(c(x$ws, x$we)))
      st <- bp[-length(bp)]
      en <- bp[-1]
      # The latest-starting window that covers [st, en) was decided last
      # among those covering it when windows have increasing ends.
      i <- findInterval(st, x$ws)
      ok <- i > 0
      ok[ok] <- st[ok] < x$we[i[ok]]
      p <- data.frame(record = x$record[1], detector = x$detector[1],
                      start = st[ok], end = en[ok],
                      response = x$response[i[ok]], reason = x$reason[i[ok]],
                      issued_at = x$decided_at[i[ok]],
                      stringsAsFactors = FALSE)
    }
    if (!is.null(gap_response) && nrow(p) > 1) {
      g <- which(p$start[-1] > p$end[-nrow(p)])
      if (length(g)) {
        p <- rbind(p, data.frame(record = p$record[1], detector = p$detector[1],
                                 start = p$end[g], end = p$start[g + 1],
                                 response = gap_response, reason = gap_reason,
                                 issued_at = NA_real_,
                                 stringsAsFactors = FALSE))
        p <- p[order(p$start), ]
      }
    }
    p
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

#' Simulated input outages for controlled experiments
#'
#' Places non-overlapping outages in each record and removes the affected
#' prediction time, so that [tl_ledger()] marks it as `"no_input"`. Every
#' row produced carries a reason starting with `"simulated"`; results from
#' these experiments must be labelled as simulated.
#'
#' `mode = "random"` draws outage start times uniformly over the target
#' period. `mode = "event_concentrated"` is a deliberately artificial stress
#' test: outage start times are drawn uniformly over reference event time.
#' It tests how an evaluation behaves when missingness concentrates on
#' events; it says nothing about whether real devices fail during events.
#'
#' @param ledger A `tl_ledger` (used for records, reference and predictions).
#' @param n Number of outages per record.
#' @param duration Duration of each outage.
#' @param mode `"random"` or `"event_concentrated"`.
#' @param seed Optional random seed.
#' @param max_tries Attempts per outage before giving up on a placement.
#' @return A list with `observation` (for [tl_ledger()]) and `predictions`
#'   (the original prediction rows with outage time removed).
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' sim <- tl_simulate_outages(led, n = 2, duration = 5, seed = 1)
#' sim$observation
#' @export
tl_simulate_outages <- function(ledger, n, duration,
                                mode = c("random", "event_concentrated"),
                                seed = NULL, max_tries = 1000) {
  mode <- match.arg(mode)
  if (!is.null(seed)) set.seed(seed)
  rec <- attr(ledger, "records")
  ref <- attr(ledger, "reference_rows")
  why <- paste0("simulated outage (", mode, ")")
  obs <- lapply(rec$record, function(r) {
    rs <- rec$start[rec$record == r]
    re <- rec$end[rec$record == r]
    ev <- ref[ref$record == r & ref$state == "event", ]
    placed <- matrix(numeric(), 0, 2)
    tries <- 0
    while (nrow(placed) < n && tries < max_tries) {
      tries <- tries + 1
      if (mode == "random") {
        s <- stats::runif(1, rs, re - duration)
      } else {
        if (!nrow(ev)) break
        w <- ev$end - ev$start
        k <- sample.int(nrow(ev), 1, prob = w)
        s <- stats::runif(1, ev$start[k], ev$end[k])
        s <- min(s, re - duration)
      }
      e <- s + duration
      if (nrow(placed) && any(s < placed[, 2] & e > placed[, 1])) next
      placed <- rbind(placed, c(s, e))
    }
    if (!nrow(placed)) {
      return(data.frame(record = r, start = rs, end = re, status = "available",
                        reason = NA_character_, stringsAsFactors = FALSE))
    }
    placed <- placed[order(placed[, 1]), , drop = FALSE]
    bp <- sort(unique(c(rs, re, placed)))
    st <- bp[-length(bp)]
    en <- bp[-1]
    out <- vapply(st, function(t) any(t >= placed[, 1] & t < placed[, 2]),
                  logical(1))
    data.frame(record = r, start = st, end = en,
               status = ifelse(out, "unavailable", "available"),
               reason = ifelse(out, why, NA_character_),
               stringsAsFactors = FALSE)
  })
  obs <- do.call(rbind, obs)
  prd <- attr(ledger, "prediction_rows")
  prd <- prd[, setdiff(names(prd), ".row")]
  un <- obs[obs$status == "unavailable", ]
  cut <- .subtract_intervals(prd, un)
  list(observation = obs, predictions = cut)
}

# Remove the time covered by `holes` (per record) from interval rows of `x`.
.subtract_intervals <- function(x, holes) {
  if (!nrow(holes)) return(x)
  # Holes are disjoint within a record. Rows of `x` may belong to several
  # detectors, so work per record and detector group, splitting rows at hole
  # boundaries and dropping the pieces inside holes.
  grp <- if (!is.null(x$detector)) .group_key(x$record, x$detector) else x$record
  out <- lapply(split(x, grp), function(p) {
    h <- holes[holes$record == p$record[1], ]
    if (!nrow(h)) return(p)
    h <- h[order(h$start), ]
    p <- p[order(p$start), ]
    bp <- sort(unique(c(p$start, p$end, h$start, h$end)))
    st <- bp[-length(bp)]
    en <- bp[-1]
    pi <- .cover(st, p$start, p$end)
    hi <- .cover(st, h$start, h$end)
    keep <- !is.na(pi) & is.na(hi)
    r <- p[pi[keep], , drop = FALSE]
    r$start <- st[keep]
    r$end <- en[keep]
    # Re-join consecutive pieces of the same source row.
    if (nrow(r) > 1) {
      src <- pi[keep]
      new <- c(TRUE, src[-1] != src[-length(src)] | r$start[-1] != r$end[-nrow(r)])
      run <- .run_id(new)
      ends <- as.numeric(tapply(r$end, run, max))
      r <- r[new, , drop = FALSE]
      r$end <- ends
    }
    r
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}
