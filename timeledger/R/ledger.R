#' Build the time ledger
#'
#' `tl_ledger()` is the centre of the package. It cuts every record's target
#' period into disjoint half-open intervals \eqn{[start, end)}, splitting
#' wherever the reference state, the observation status, or any detector's
#' response changes. Each row states what was known about that stretch of
#' time, so every metric in the package is a sum over ledger rows and can be
#' traced back to the seconds behind it.
#'
#' Four conditions that are often merged are kept apart:
#' * reference `"unknown"`: correctness cannot be assessed;
#' * response `"no_input"`: the reference may be known, but the monitor had no
#'   input, so a prediction was impossible;
#' * response `"abstain"`: input was available and the detector declined;
#' * response `"negative"`: an actual "no event" answer that can be right or
#'   wrong.
#'
#' Time not covered by any prediction row is not silently treated as
#' negative. Its meaning comes from `missing`, which defaults to `"unknown"`.
#' A missing score is never used to infer that the device was not worn; that
#' needs an explicit `observation` table.
#'
#' @param records Record table, usually from [tl_records()]: columns `record`,
#'   `start`, `end`, and optionally `subject`, `fs`, `n_samples`.
#' @param reference Reference intervals: columns `record`, `start`, `end`,
#'   `label`. Optional `episode` gives a physiological episode identifier that
#'   is kept when an episode is interrupted, and optional `start_sample`,
#'   `end_sample` are checked against `fs`. Target time without a reference
#'   row is `"unknown"`.
#' @param predictions Detector responses: columns `record`, `detector`,
#'   `start`, `end`, `response` (`"positive"`, `"negative"` or `"abstain"`).
#'   Optional columns: `reason` (why the detector abstained), `issued_at`
#'   (time the decision became available, used for latency).
#' @param observation Optional input-availability intervals: columns `record`,
#'   `start`, `end`, `status` (`"available"` or `"unavailable"`), and
#'   optional `reason`. Uncovered time has status `"unknown"`.
#' @param event Reference labels that count as the target event.
#' @param unknown Reference labels that mean the reference is unknown. `NA`
#'   labels are always unknown. All other labels are non-events.
#' @param missing Meaning of target time with no prediction row: one of
#'   `"unknown"`, `"abstain"`, `"negative"`, `"no_input"`. Either one value
#'   or a named vector with one value per detector.
#' @param time_unit Unit of all times: `"ms"`, `"s"`, `"min"` or `"h"`. Used
#'   only to report rates per hour and errors in minutes.
#' @param on_warning What to do with warnings found during validation:
#'   `"keep"` (store them as the `issues` attribute) or `"error"`.
#' @return A data frame of class `tl_ledger` with one row per interval and
#'   detector. Columns: `record`, `detector`, `start`, `end`, `duration`,
#'   `reference`, `ref_label`, `ref_episode`, `ref_reason`, `observation`,
#'   `obs_reason`, `response`, `response_source`, `response_reason`,
#'   `issued_at`, `conflict`, `ref_row`, `obs_row`, `pred_row`. Attributes hold
#'   the cleaned inputs, the settings and the validation issues.
#' @seealso [tl_check()], [tl_metrics()], [tl_match()], [tl_trace()]
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' led
#' tl_check(led)
#' @export
tl_ledger <- function(records, reference, predictions, observation = NULL,
                      event = "AF", unknown = "unknown", missing = "unknown",
                      time_unit = "s", on_warning = c("keep", "error")) {
  on_warning <- match.arg(on_warning)
  .unit_seconds(time_unit)
  rc <- .check_records(records)
  issues <- rc$issues
  .stop_on(issues)
  records <- rc$records

  if (is.null(predictions$reason)) predictions$reason <- rep(NA_character_, nrow(predictions))
  if (is.null(predictions$issued_at)) predictions$issued_at <- rep(NA_real_, nrow(predictions))
  ref <- .prepare_stream(reference, "reference", "label", records)
  prd <- .prepare_stream(predictions, "predictions", "response", records,
                         key = "detector",
                         allowed = c("positive", "negative", "abstain"))
  issues <- rbind(issues, ref$issues, prd$issues)
  if (!is.null(observation)) {
    if (is.null(observation$reason)) observation$reason <- rep(NA_character_, nrow(observation))
    obs <- .prepare_stream(observation, "observation", "status", records,
                           allowed = c("available", "unavailable"))
    issues <- rbind(issues, obs$issues)
    obs <- obs$data
  } else {
    obs <- data.frame(record = character(), start = numeric(),
                      end = numeric(), status = character(),
                      reason = character(), .row = integer(),
                      stringsAsFactors = FALSE)
  }
  .stop_on(issues)
  if (on_warning == "error") .stop_on(issues, "warning")
  ref <- ref$data
  prd <- prd$data
  detectors <- unique(as.character(predictions$detector))
  if (!length(detectors)) stop("`predictions` has no detector.", call. = FALSE)
  missing <- .resolve_missing(missing, detectors)

  # Reference states and episode identifiers.
  ref$state <- ifelse(is.na(ref$label) | ref$label %in% unknown, "unknown",
                      ifelse(ref$label %in% event, "event", "nonevent"))
  ref <- ref[order(ref$record, ref$start), , drop = FALSE]
  ref$episode <- .episode_ids(ref)
  if (is.null(ref$reason)) ref$reason <- rep(NA_character_, nrow(ref))

  pieces <- lapply(records$record, function(r) {
    .ledger_one(r, records[records$record == r, ], ref[ref$record == r, ],
                obs[obs$record == r, ], prd[prd$record == r, ], detectors,
                missing)
  })
  led <- do.call(rbind, pieces)
  rownames(led) <- NULL
  notes <- .ledger_notes(led)
  issues <- rbind(issues, notes)
  rownames(issues) <- NULL
  structure(led, class = c("tl_ledger", "data.frame"),
            records = records, reference_rows = ref, prediction_rows = prd,
            observation_rows = obs, detectors = detectors,
            settings = list(event = event, unknown = unknown,
                            missing = missing, time_unit = time_unit),
            issues = issues)
}

.stop_on <- function(issues, level = "error") {
  bad <- issues[issues$severity == level, , drop = FALSE]
  if (nrow(bad)) {
    show <- utils::head(bad, 10)
    msg <- paste(sprintf("- %s, record %s, row %s: %s %s", show$table,
                         show$record, show$row, show$issue,
                         ifelse(nzchar(show$detail), paste0("(", show$detail, ")"),
                                "")), collapse = "\n")
    more <- if (nrow(bad) > 10) sprintf("\n... and %d more", nrow(bad) - 10) else ""
    stop(sprintf("Input validation found %d %s(s):\n%s%s\nRun tl_validate() for the full table.",
                 nrow(bad), level, msg, more), call. = FALSE)
  }
  invisible(TRUE)
}

.resolve_missing <- function(missing, detectors) {
  if (!all(missing %in% .missing_meanings)) {
    stop(sprintf("`missing` must use: %s.",
                 paste(.missing_meanings, collapse = ", ")), call. = FALSE)
  }
  if (is.null(names(missing))) {
    if (length(missing) != 1) {
      stop("An unnamed `missing` must have length 1.", call. = FALSE)
    }
    return(stats::setNames(rep(missing, length(detectors)), detectors))
  }
  absent <- setdiff(detectors, names(missing))
  if (length(absent)) {
    stop(sprintf("`missing` has no entry for detector(s): %s.",
                 paste(absent, collapse = ", ")), call. = FALSE)
  }
  missing[detectors]
}

# Episode identifiers: a user-supplied `episode` column wins; otherwise
# contiguous event rows form one episode.
.episode_ids <- function(ref) {
  if (!is.null(ref$episode)) {
    id <- ifelse(ref$state == "event" & !is.na(ref$episode),
                 paste(ref$record, ref$episode, sep = ":"), NA_character_)
    return(id)
  }
  ev <- ref$state == "event"
  prev_ev <- c(FALSE, ev[-length(ev)])
  prev_end <- c(-Inf, ref$end[-nrow(ref)])
  prev_rec <- c("", ref$record[-nrow(ref)])
  new <- ev & !(prev_ev & prev_end == ref$start & prev_rec == ref$record)
  k <- stats::ave(as.numeric(new), ref$record, FUN = cumsum)
  ifelse(ev, sprintf("%s:e%03d", ref$record, as.integer(k)), NA_character_)
}

.cover <- function(st, s, e) {
  if (!length(s)) return(rep(NA_integer_, length(st)))
  i <- findInterval(st, s)
  ok <- i > 0
  ok[ok] <- st[ok] < e[i[ok]]
  ifelse(ok, i, NA_integer_)
}

.ledger_one <- function(r, rec, ref, obs, prd, detectors, missing) {
  bp <- c(rec$start, rec$end, ref$start, ref$end, obs$start, obs$end,
          prd$start, prd$end)
  bp <- sort(unique(bp[bp >= rec$start & bp <= rec$end]))
  st <- bp[-length(bp)]
  en <- bp[-1]
  n <- length(st)
  ri <- .cover(st, ref$start, ref$end)
  oi <- .cover(st, obs$start, obs$end)
  reference <- ifelse(is.na(ri), "unknown", ref$state[ri])
  ref_reason <- ifelse(is.na(ri), "no reference interval",
                       ifelse(reference == "unknown",
                              paste0("reference label: ", ref$label[ri]),
                              NA_character_))
  observation <- ifelse(is.na(oi), "unknown", obs$status[oi])
  obs_reason <- ifelse(is.na(oi), NA_character_, obs$reason[oi])
  base <- data.frame(record = rep(r, n), start = st, end = en,
                     duration = en - st, reference = reference,
                     ref_label = ifelse(is.na(ri), NA_character_,
                                        ref$label[ri]),
                     ref_episode = ifelse(is.na(ri), NA_character_,
                                          ref$episode[ri]),
                     ref_reason = ref_reason, observation = observation,
                     obs_reason = obs_reason,
                     ref_row = ifelse(is.na(ri), NA_integer_, ref$.row[ri]),
                     obs_row = ifelse(is.na(oi), NA_integer_, obs$.row[oi]),
                     stringsAsFactors = FALSE)
  out <- lapply(detectors, function(d) {
    p <- prd[prd$detector == d, , drop = FALSE]
    pi <- .cover(st, p$start, p$end)
    has <- !is.na(pi)
    resp <- ifelse(has, p$response[pi], missing[[d]])
    src <- ifelse(has, "prediction", paste0("declared missing: ", missing[[d]]))
    why <- ifelse(has, p$reason[pi], "no prediction row")
    unavail <- observation == "unavailable"
    conflict <- unavail & resp %in% .answered & has
    to_noinput <- unavail & !(resp %in% .answered)
    resp[to_noinput] <- "no_input"
    src[to_noinput] <- "observation unavailable"
    why[to_noinput] <- ifelse(is.na(obs_reason[to_noinput]),
                              "input unavailable", obs_reason[to_noinput])
    cbind(base[, c("record", "start", "end", "duration")],
          detector = d,
          base[, c("reference", "ref_label", "ref_episode", "ref_reason",
                   "observation", "obs_reason")],
          response = resp, response_source = src, response_reason = why,
          issued_at = ifelse(has, p$issued_at[pi], NA_real_),
          conflict = conflict,
          base[, c("ref_row", "obs_row")],
          pred_row = ifelse(has, p$.row[pi], NA_integer_),
          stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out)
  out[, c("record", "detector", setdiff(names(out), c("record", "detector")))]
}

.ledger_notes <- function(led) {
  iss <- .empty_issues()
  c1 <- led$conflict
  if (any(c1)) {
    iss <- rbind(iss, .issue("warning", "ledger", led$record[c1], NA,
                             "detector answered while input was declared unavailable",
                             sprintf("%s [%s, %s)", led$detector[c1],
                                     led$start[c1], led$end[c1])))
  }
  iss
}

#' Check the accounting identities of a ledger
#'
#' Verifies that, for every record and detector, the ledger rows are
#' contiguous, do not overlap, and add up to the declared target period.
#'
#' @param ledger A `tl_ledger`.
#' @param tol Numerical tolerance for the duration identity.
#' @return A data frame with one row per record and detector: target
#'   duration, ledger duration, whether rows are contiguous, and `ok`.
#' @examples
#' fx <- tl_fixture("acceptance")
#' tl_check(tl_ledger(fx$records, fx$reference, fx$predictions,
#'                    time_unit = "min"))
#' @export
tl_check <- function(ledger, tol = 1e-9) {
  rec <- attr(ledger, "records")
  g <- split(ledger, list(ledger$record, ledger$detector), drop = TRUE)
  res <- lapply(g, function(x) {
    x <- x[order(x$start), ]
    tgt <- rec$end[rec$record == x$record[1]] - rec$start[rec$record == x$record[1]]
    contiguous <- nrow(x) < 2 || all(abs(x$start[-1] - x$end[-nrow(x)]) <= tol)
    data.frame(record = x$record[1], detector = x$detector[1],
               target = tgt, ledger = sum(x$duration),
               contiguous = contiguous,
               starts_at_target = abs(x$start[1] - rec$start[rec$record == x$record[1]]) <= tol,
               ok = contiguous && abs(sum(x$duration) - tgt) <= tol * max(1, tgt),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  out
}

#' Duration totals for every state in a ledger
#'
#' @param object A `tl_ledger`.
#' @param by Columns to cross-tabulate; defaults to reference state,
#'   observation status and response.
#' @param ... Unused.
#' @return A data frame of total durations per detector and state
#'   combination, with the share of the target period.
#' @examples
#' fx <- tl_fixture("acceptance")
#' summary(tl_ledger(fx$records, fx$reference, fx$predictions,
#'                   time_unit = "min"))
#' @export
summary.tl_ledger <- function(object, by = c("reference", "observation",
                                              "response"), ...) {
  x <- as.data.frame(object)
  f <- stats::as.formula(paste("duration ~", paste(c("detector", by),
                                                    collapse = " + ")))
  a <- stats::aggregate(f, data = x, FUN = sum)
  tot <- stats::aggregate(duration ~ detector, data = x, FUN = sum)
  a$share <- a$duration / tot$duration[match(a$detector, tot$detector)]
  a[order(a$detector, -a$duration), ]
}

#' @export
print.tl_ledger <- function(x, n = 10, ...) {
  rec <- attr(x, "records")
  iss <- attr(x, "issues")
  cat(sprintf("<tl_ledger> %d rows | %d record(s) | detector(s): %s | time unit: %s\n",
              nrow(x), nrow(rec), paste(attr(x, "detectors"), collapse = ", "),
              attr(x, "settings")$time_unit))
  if (!is.null(iss) && nrow(iss)) {
    tab <- table(iss$severity)
    cat("Validation issues:", paste(names(tab), tab, sep = "=", collapse = ", "),
        "(see attr(x, \"issues\"))\n")
  }
  cols <- c("record", "detector", "start", "end", "reference", "observation",
            "response", "response_reason")
  print(utils::head(as.data.frame(x)[, cols], n), row.names = FALSE)
  if (nrow(x) > n) cat(sprintf("... %d more rows\n", nrow(x) - n))
  invisible(x)
}

#' @export
as.data.frame.tl_ledger <- function(x, ...) {
  class(x) <- "data.frame"
  attributes(x)[c("records", "reference_rows", "prediction_rows",
                  "observation_rows", "detectors", "settings",
                  "issues")] <- NULL
  x
}

# Subsetting keeps the ledger class only when the attributes still apply.
#' @export
`[.tl_ledger` <- function(x, i, j, drop = FALSE) {
  at <- attributes(x)
  y <- as.data.frame(x)[i, j, drop = drop]
  if (is.data.frame(y) && all(names(x) %in% names(y))) {
    for (a in c("records", "reference_rows", "prediction_rows",
                "observation_rows", "detectors", "settings", "issues")) {
      attr(y, a) <- at[[a]]
    }
    class(y) <- c("tl_ledger", "data.frame")
  }
  y
}

#' Restrict a ledger to part of its time
#'
#' Rows outside `keep` have their reference state set to `"unknown"`, with
#' the reason recorded in `ref_reason`. Because every reference-based metric
#' is computed on reference-known time, this removes the rows from all
#' denominators while leaving them visible for inspection. Durations still
#' add up to the target period.
#'
#' @param ledger A `tl_ledger`.
#' @param keep Logical vector, one value per ledger row.
#' @param reason Text stored in `ref_reason` for the excluded rows.
#' @return The modified `tl_ledger`, with the restriction logged in the
#'   `restrictions` attribute.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' late <- tl_restrict(led, led$start >= 50, "before minute 50")
#' tl_metrics(late, tl_match(late))
#' @export
tl_restrict <- function(ledger, keep, reason) {
  stopifnot(inherits(ledger, "tl_ledger"), is.logical(keep),
            length(keep) == nrow(ledger))
  keep[is.na(keep)] <- FALSE
  drop <- !keep & ledger$reference != "unknown"
  ledger$ref_reason[drop] <- reason
  ledger$reference[drop] <- "unknown"
  ledger$ref_episode[!keep] <- ledger$ref_episode[!keep]
  attr(ledger, "restrictions") <- c(attr(ledger, "restrictions"), reason)
  ledger
}
