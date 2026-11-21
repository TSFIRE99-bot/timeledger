#' Additive contributions of each record
#'
#' Every metric in [tl_metrics()] is a ratio of sums, so it can be computed
#' from per-record totals. This function returns those totals, one row per
#' record and detector. They are the unit of resampling in [tl_bootstrap()].
#'
#' Durations are in the ledger's time unit. Columns:
#' `target` (T), `known` (reference-known, K), `answered` (answered and
#' reference-known, A), `answered_any` (answered anywhere in the target),
#' `unanswered` (abstain, no input or unknown response anywhere in the
#' target), `positive_target`, `positive_known`, `event` (E),
#' `event_answered`, `tp`, `nonevent_answered`, `tn`, `fp_time`,
#' `known_input` and `answered_input` (reference-known time with input
#' available, and the answered part of it), `missed_negative`,
#' `missed_abstain`, `missed_no_input`, `missed_unknown` (event time by
#' response), `positive_unknown_ref` (positive time with unknown reference),
#' and, when `match` is given, `episodes_eligible`, `episodes_detected`,
#' `alarms`, `alarms_matched`, `alarms_redundant`, `alarms_false`,
#' `alarms_unassessable`, `alarms_ineligible`.
#'
#' @param ledger A `tl_ledger`.
#' @param match Optional `tl_match` from the same ledger.
#' @return A data frame with one row per record and detector.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' tl_contributions(led, tl_match(led))
#' @export
tl_contributions <- function(ledger, match = NULL) {
  stopifnot(inherits(ledger, "tl_ledger"))
  L <- as.data.frame(ledger)
  rec <- attr(ledger, "records")
  known <- L$reference != "unknown"
  ans <- L$response %in% .answered
  ev <- L$reference == "event"
  ne <- L$reference == "nonevent"
  pos <- L$response == "positive"
  neg <- L$response == "negative"
  inp <- L$observation == "available"
  d <- L$duration
  key <- factor(.group_key(L$record, L$detector))
  s <- function(w) as.numeric(tapply(d * w, key, sum))
  first <- !duplicated(key)
  ord <- match(levels(key), key[first])
  out <- data.frame(record = L$record[first][ord],
                    detector = L$detector[first][ord],
                    stringsAsFactors = FALSE)
  out$subject <- rec$subject[match(out$record, rec$record)]
  out$target <- s(1)
  out$known <- s(known)
  out$answered <- s(known & ans)
  out$answered_any <- s(ans)
  out$unanswered <- s(!ans)
  out$positive_target <- s(pos)
  out$positive_known <- s(pos & known)
  out$event <- s(ev)
  out$event_answered <- s(ev & ans)
  out$tp <- s(ev & pos)
  out$nonevent_answered <- s(ne & ans)
  out$tn <- s(ne & neg)
  out$fp_time <- s(ne & pos)
  out$known_input <- s(known & inp)
  out$answered_input <- s(known & inp & ans)
  out$missed_negative <- s(ev & neg)
  out$missed_abstain <- s(ev & L$response == "abstain")
  out$missed_no_input <- s(ev & L$response == "no_input")
  out$missed_unknown <- s(ev & L$response == "unknown")
  out$positive_unknown_ref <- s(pos & !known)
  if (!is.null(match)) {
    stopifnot(inherits(match, "tl_match"))
    e <- match$episodes
    a <- match$alarms
    k_e <- .group_key(e$record, e$detector)
    k_a <- .group_key(a$record, a$detector)
    k_o <- .group_key(out$record, out$detector)
    cnt <- function(k, w) {
      v <- tapply(as.numeric(w), factor(k, levels = k_o), sum)
      v[is.na(v)] <- 0
      as.numeric(v)
    }
    out$episodes_eligible <- cnt(k_e, e$eligible)
    out$episodes_detected <- cnt(k_e, e$detected)
    out$alarms <- cnt(k_a, a$status != "learning_period")
    out$alarms_matched <- cnt(k_a, a$status == "matched")
    out$alarms_redundant <- cnt(k_a, a$status == "redundant")
    out$alarms_false <- cnt(k_a, a$status == "false")
    out$alarms_unassessable <- cnt(k_a, a$status == "unassessable")
    out$alarms_ineligible <- cnt(k_a, a$status == "ineligible_overlap")
  }
  out <- out[order(out$detector, out$record), ]
  rownames(out) <- NULL
  attr(out, "time_unit") <- attr(ledger, "settings")$time_unit
  attr(out, "match_settings") <- if (!is.null(match)) match$settings
  out
}

# Metric definitions: name, numerator expression, denominator expression,
# unit, scale, reason when the denominator is zero.
.metric_defs <- function(tu) {
  hr <- .unit_seconds(tu) / 3600
  mn <- .unit_seconds(tu) / 60
  list(
    list("answer_coverage", "answered", "known", "proportion", 1,
         "no reference-known target time"),
    list("answer_coverage_given_input", "answered_input", "known_input",
         "proportion", 1, "input availability not declared"),
    list("answered_sensitivity", "tp", "event_answered", "proportion", 1,
         "no event time during answered time"),
    list("answered_specificity", "tn", "nonevent_answered", "proportion", 1,
         "no non-event time during answered time"),
    list("full_capture", "tp", "event", "proportion", 1,
         "no reference-known event time"),
    list("duration_ppv", "tp", "positive_known", "proportion", 1,
         "no positive time on reference-known rows"),
    list("episode_sensitivity", "episodes_detected", "episodes_eligible",
         "proportion", 1, "no eligible episodes"),
    list("false_alarms_per_answered_hour", "alarms_false", "answered",
         "per hour", 1 / hr, "no answered reference-known time"),
    list("false_alarms_per_known_hour", "alarms_false", "known",
         "per hour", 1 / hr, "no reference-known time"),
    list("unmatched_alarms_per_answered_hour", "unmatched", "answered",
         "per hour", 1 / hr, "no answered reference-known time"),
    list("pred_burden_answered", "positive_known", "answered", "proportion",
         1, "no answered reference-known time"),
    list("ref_burden_answered", "event_answered", "answered", "proportion",
         1, "no answered reference-known time"),
    list("ref_burden_full", "event", "known", "proportion", 1,
         "no reference-known time"),
    list("burden_diff_pp", "burden_diff", "answered", "percentage points",
         100, "no answered reference-known time"),
    list("burden_bound_lower", "positive_target", "target", "proportion", 1,
         "empty target period"),
    list("burden_bound_upper", "positive_or_unanswered", "target",
         "proportion", 1, "empty target period")
  )
}

#' Performance metrics with their denominators
#'
#' Computes every headline quantity together with its numerator,
#' denominator, units, the time excluded from it, and an explicit reason
#' whenever it is undefined. Results are given per record and pooled over
#' records (ratio of sums, which weights records by their duration). Use
#' [tl_record_mean()] for equal-record summaries.
#'
#' Definitions (all durations from the ledger; "known" means the reference
#' is known):
#' * `answer_coverage`: answered known time / known time.
#' * `answer_coverage_given_input`: the same restricted to time with input
#'   declared available.
#' * `answered_sensitivity`: correctly flagged event time / event time
#'   during answered time.
#' * `full_capture`: correctly flagged event time / all known event time.
#'   Unanswered event time counts as missed; its reasons are reported as
#'   `missed_*_min` rows.
#' * `episode_sensitivity`: detected / eligible episodes under the matching
#'   policy in `match`.
#' * `false_alarms_per_*_hour`: alarms with no reference-event overlap per
#'   answered (or known) hour; `unmatched_alarms_per_answered_hour` also
#'   counts redundant alarms.
#' * `pred_burden_answered`, `ref_burden_answered`: predicted and reference
#'   event fractions on the same answered time; `ref_burden_full`: reference
#'   event fraction over known time; `burden_diff_pp` is their difference in
#'   percentage points and `burden_error_min` in minutes.
#' * `burden_bound_lower`, `burden_bound_upper`: the range of full-period
#'   predicted burden compatible with completing the unanswered time,
#'   keeping the answered labels fixed. This bounds the prediction, not the
#'   true burden.
#'
#' @param ledger A `tl_ledger`.
#' @param match Optional `tl_match`; needed for episode and alarm metrics.
#' @param level `"both"`, `"record"` or `"pooled"`.
#' @return A data frame of class `tl_metrics` with columns `level`,
#'   `record`, `detector`, `metric`, `estimate`, `numerator`, `denominator`,
#'   `unit`, `excluded_time` (reference-unknown time left out of known-time
#'   denominators) and `undefined_reason`.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' tl_metrics(led, tl_match(led), level = "pooled")
#' @export
tl_metrics <- function(ledger, match = NULL, level = c("both", "record",
                                                      "pooled")) {
  level <- match.arg(level)
  cb <- tl_contributions(ledger, match)
  .metrics_from_contrib(cb, level)
}

.metrics_from_contrib <- function(cb, level = "both") {
  tu <- attr(cb, "time_unit")
  pooled <- NULL
  if (level %in% c("both", "pooled")) {
    num_cols <- setdiff(names(cb), c("record", "detector", "subject"))
    pooled <- stats::aggregate(cb[num_cols], by = list(detector = cb$detector),
                               FUN = sum)
    pooled$record <- "<pooled>"
    pooled$subject <- NA_character_
    pooled <- pooled[, names(cb)]
  }
  rows <- switch(level, both = rbind(cb, pooled), record = cb,
                 pooled = pooled)
  lev <- ifelse(rows$record == "<pooled>", "pooled", "record")
  rows$unmatched <- if (!is.null(rows$alarms_matched)) {
    rows$alarms_false + rows$alarms_redundant
  } else NA_real_
  rows$burden_diff <- rows$positive_known - rows$event_answered
  rows$positive_or_unanswered <- rows$positive_target + rows$unanswered
  has_match <- !is.null(rows$episodes_eligible)
  out <- list()
  for (def in .metric_defs(tu)) {
    nm <- def[[1]]
    if (!has_match && (grepl("episode|alarm", nm))) next
    num <- rows[[def[[2]]]]
    den <- rows[[def[[3]]]]
    r <- .ratio(num, den, def[[6]])
    out[[nm]] <- data.frame(level = lev, record = rows$record,
                            detector = rows$detector, metric = nm,
                            estimate = r$estimate * def[[5]],
                            numerator = num, denominator = den,
                            unit = def[[4]],
                            excluded_time = rows$target - rows$known,
                            undefined_reason = r$reason,
                            stringsAsFactors = FALSE)
  }
  mins <- .unit_seconds(tu) / 60
  add_min <- function(nm, col, note) {
    data.frame(level = lev, record = rows$record, detector = rows$detector,
               metric = nm, estimate = rows[[col]] * mins,
               numerator = rows[[col]], denominator = NA_real_,
               unit = "minutes", excluded_time = rows$target - rows$known,
               undefined_reason = NA_character_, stringsAsFactors = FALSE)
  }
  out$burden_error_min <- add_min("burden_error_min", "burden_diff")
  for (m in c("missed_negative", "missed_abstain", "missed_no_input",
              "missed_unknown")) {
    out[[m]] <- add_min(paste0(m, "_min"), m)
  }
  if (has_match) {
    out$unmatched_alarms <- data.frame(
      level = lev, record = rows$record, detector = rows$detector,
      metric = "unmatched_alarms", estimate = rows$unmatched,
      numerator = rows$unmatched, denominator = NA_real_, unit = "count",
      excluded_time = rows$target - rows$known,
      undefined_reason = NA_character_, stringsAsFactors = FALSE)
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res <- res[order(res$level != "pooled", res$detector, res$record), ]
  rownames(res) <- NULL
  structure(res, class = c("tl_metrics", "data.frame"), time_unit = tu)
}

#' Equal-record summaries of metrics
#'
#' Averages per-record estimates so that each record (or, with
#' `by = "subject"`, each subject) counts once, whatever its duration.
#' Records whose metric is undefined are left out and counted.
#'
#' @param metrics A `tl_metrics` object computed with `level` `"both"` or
#'   `"record"`.
#' @return A data frame with `detector`, `metric`, `mean`, `median`,
#'   `n_defined` and `n_undefined`.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' tl_record_mean(tl_metrics(led))
#' @export
tl_record_mean <- function(metrics) {
  r <- metrics[metrics$level == "record", ]
  if (!nrow(r)) stop("`metrics` has no record-level rows.", call. = FALSE)
  g <- split(r, list(r$detector, r$metric), drop = TRUE)
  out <- do.call(rbind, lapply(g, function(x) {
    v <- x$estimate
    data.frame(detector = x$detector[1], metric = x$metric[1],
               mean = if (any(!is.na(v))) mean(v, na.rm = TRUE) else NA_real_,
               median = if (any(!is.na(v))) stats::median(v, na.rm = TRUE) else NA_real_,
               n_defined = sum(!is.na(v)), n_undefined = sum(is.na(v)),
               stringsAsFactors = FALSE)
  }))
  rownames(out) <- NULL
  out[order(out$detector, out$metric), ]
}

#' @export
print.tl_metrics <- function(x, digits = 4, ...) {
  y <- as.data.frame(x)
  class(y) <- "data.frame"
  y$estimate <- signif(y$estimate, digits)
  cat(sprintf("<tl_metrics> time unit: %s\n", attr(x, "time_unit")))
  print(y[, c("level", "record", "detector", "metric", "estimate",
              "numerator", "denominator", "unit", "undefined_reason")],
        row.names = FALSE)
  invisible(x)
}

#' Extract one metric as a compact table
#'
#' @param metrics A `tl_metrics` object.
#' @param metric Metric name(s).
#' @param level `"pooled"` or `"record"`.
#' @return The matching rows as a plain data frame.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' tl_get(tl_metrics(led), "full_capture")
#' @export
tl_get <- function(metrics, metric, level = "pooled") {
  y <- as.data.frame(metrics)
  class(y) <- "data.frame"
  y <- y[y$metric %in% metric & y$level %in% level, , drop = FALSE]
  rownames(y) <- NULL
  y
}
