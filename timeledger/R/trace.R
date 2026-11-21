#' Inspect the ledger rows behind a number
#'
#' `tl_trace()` returns the ledger rows of one record that intersect a time
#' window. `tl_explain()` returns the rows behind one alarm or one episode,
#' with the matching decision attached, so a false alarm or a missed episode
#' can be followed down to the exact intervals that produced it.
#'
#' @param ledger A `tl_ledger`.
#' @param record Record identifier.
#' @param from,to Time window (half-open).
#' @param detector Optional detector(s) to keep.
#' @return A plain data frame of ledger rows.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' tl_trace(led, "rec1", 35, 65)
#' m <- tl_match(led)
#' tl_explain(led, m, alarm = m$alarms$alarm_id[m$alarms$status == "false"])
#' tl_explain(led, m, episode = "rec1:e002")
#' @export
tl_trace <- function(ledger, record, from = -Inf, to = Inf, detector = NULL) {
  L <- as.data.frame(ledger)
  k <- L$record == record & L$end > from & L$start < to
  if (!is.null(detector)) k <- k & L$detector %in% detector
  out <- L[k, , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' @rdname tl_trace
#' @param match A `tl_match` computed from `ledger`.
#' @param alarm An alarm identifier from `match$alarms`.
#' @param episode An episode identifier from `match$episodes`.
#' @export
tl_explain <- function(ledger, match, alarm = NULL, episode = NULL) {
  stopifnot(inherits(match, "tl_match"))
  s <- match$settings
  if (s$learning_period > 0) {
    rec <- attr(ledger, "records")
    ledger <- tl_split(ledger, data.frame(record = rec$record,
                                          time = rec$start + s$learning_period,
                                          stringsAsFactors = FALSE))
  }
  ar <- .alarm_runs(ledger, s$alarm_merge_gap, s$alarm_min_duration)
  L <- as.data.frame(ledger)
  L$alarm_id <- ar$row_alarm
  if (!is.null(alarm)) {
    if (length(alarm) != 1) stop("Give one alarm identifier.", call. = FALSE)
    a <- match$alarms[match$alarms$alarm_id == alarm, ]
    if (!nrow(a)) stop("Unknown alarm identifier.", call. = FALSE)
    rows <- L[L$alarm_id %in% alarm, ]
    rows$decision <- a$status
    rows$matched_episode <- a$episode_id
    rownames(rows) <- NULL
    return(rows)
  }
  if (!is.null(episode)) {
    if (length(episode) != 1) stop("Give one episode identifier.", call. = FALSE)
    e <- match$episodes[match$episodes$episode_id == episode, ]
    if (!nrow(e)) stop("Unknown episode identifier.", call. = FALSE)
    memb <- strsplit(e$members[1], "+", fixed = TRUE)[[1]]
    rows <- L[L$ref_episode %in% memb, ]
    rows$episode_detected <- e$detected[match(rows$detector, e$detector)]
    rows$episode_eligible <- e$eligible[match(rows$detector, e$detector)]
    rows$matched_alarm <- e$alarm_id[match(rows$detector, e$detector)]
    rownames(rows) <- NULL
    return(rows)
  }
  stop("Give `alarm` or `episode`.", call. = FALSE)
}

#' Timeline plot of one record
#'
#' Draws the reference, each detector's responses, and optionally the time
#' included in a comparison, using base graphics. Colours distinguish
#' positive, negative, abstained, no-input and unknown responses; the
#' reference lane distinguishes event, non-event and unknown time.
#'
#' @param x A `tl_ledger`.
#' @param record Record to draw (defaults to the first).
#' @param from,to Time window.
#' @param detectors Detectors to draw (defaults to all).
#' @param include Optional named list of logical vectors (one value per
#'   ledger row) drawn as extra lanes, e.g. the rows kept in a shared-time
#'   comparison.
#' @param time_scale Divide times by this for the axis (e.g. 60 to show
#'   minutes when times are in seconds).
#' @param xlab Axis label.
#' @param legend Draw a legend?
#' @param ... Passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @examples
#' fx <- tl_fixture("two_detectors")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' plot(led, xlab = "minutes")
#' @export
plot.tl_ledger <- function(x, record = NULL, from = NULL, to = NULL,
                           detectors = NULL, include = NULL, time_scale = 1,
                           xlab = "time", legend = TRUE, ...) {
  L <- as.data.frame(x)
  if (is.null(record)) record <- L$record[1]
  if (is.null(detectors)) detectors <- attr(x, "detectors")
  L <- L[L$record == record, ]
  if (is.null(from)) from <- min(L$start)
  if (is.null(to)) to <- max(L$end)
  ref_col <- c(event = "#b2182b", nonevent = "#d9d9d9", unknown = "white")
  resp_col <- c(positive = "#b2182b", negative = "#d9d9d9",
                abstain = "#f4a582", no_input = "#252525", unknown = "white")
  lanes <- c("reference", detectors, names(include))
  n <- length(lanes)
  graphics::plot(NA, xlim = c(from, to) / time_scale, ylim = c(0.5, n + 0.5),
                 yaxt = "n", ylab = "", xlab = xlab, bty = "n", ...)
  graphics::axis(2, at = n:1, labels = lanes, las = 1, tick = FALSE)
  r1 <- L[L$detector == L$detector[1], ]
  graphics::rect(r1$start / time_scale, n - 0.35, r1$end / time_scale,
                 n + 0.35, col = ref_col[r1$reference], border = NA)
  unk <- r1$reference == "unknown"
  if (any(unk)) {
    graphics::rect(r1$start[unk] / time_scale, n - 0.35,
                   r1$end[unk] / time_scale, n + 0.35, density = 20,
                   col = "grey40", border = NA)
  }
  for (j in seq_along(detectors)) {
    y <- n - j
    r <- L[L$detector == detectors[j], ]
    graphics::rect(r$start / time_scale, y - 0.35, r$end / time_scale,
                   y + 0.35, col = resp_col[r$response], border = NA)
    u <- r$response == "unknown"
    if (any(u)) {
      graphics::rect(r$start[u] / time_scale, y - 0.35, r$end[u] / time_scale,
                     y + 0.35, density = 20, col = "grey40", border = NA)
    }
  }
  if (!is.null(include)) {
    full <- as.data.frame(x)
    for (j in seq_along(include)) {
      y <- n - length(detectors) - j
      keep <- include[[j]][full$record == record &
                             full$detector == full$detector[full$record == record][1]]
      r <- r1[keep, ]
      graphics::rect(r$start / time_scale, y - 0.2, r$end / time_scale,
                     y + 0.2, col = "#2166ac", border = NA)
    }
  }
  if (legend) {
    graphics::legend("bottom", horiz = TRUE, bty = "n", cex = 0.75,
                     inset = c(0, -0.02), xpd = NA,
                     fill = c(resp_col[1:4], "white"),
                     density = c(NA, NA, NA, NA, 20),
                     legend = c("event / positive", "non-event / negative",
                                "abstain", "no input", "unknown"))
  }
  invisible(x)
}
