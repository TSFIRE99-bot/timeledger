#' Describe the recordings to be evaluated
#'
#' Builds the record table that anchors every other input. Each record has its
#' own clock: `start` and `end` give the target period, in the same time unit
#' as the interval tables, and intervals are half-open, \eqn{[start, end)}.
#'
#' @param record Character record identifiers (unique).
#' @param start,end Numeric start and end of the target period of each record.
#' @param subject Identifier of the person each record comes from. Records from
#'   the same subject are resampled together by [tl_bootstrap()]. Defaults to
#'   `record`, which asserts that every record comes from a different person.
#' @param fs Optional sampling frequency in Hz, used to check sample indices.
#' @param n_samples Optional number of samples in the source signal or
#'   annotation timeline, used to check sample indices.
#' @return A data frame with class `tl_records`.
#' @examples
#' tl_records(c("r1", "r2"), start = 0, end = c(100, 120), fs = 250)
#' @export
tl_records <- function(record, start = 0, end, subject = record,
                       fs = NA_real_, n_samples = NA_real_) {
  n <- length(record)
  out <- data.frame(record = as.character(record),
                    start = rep_len(as.numeric(start), n),
                    end = rep_len(as.numeric(end), n),
                    subject = rep_len(as.character(subject), n),
                    fs = rep_len(as.numeric(fs), n),
                    n_samples = rep_len(as.numeric(n_samples), n),
                    stringsAsFactors = FALSE)
  class(out) <- c("tl_records", "data.frame")
  out
}

.check_records <- function(records) {
  .require_cols(records, c("record", "start", "end"), "records")
  records <- as.data.frame(records, stringsAsFactors = FALSE)
  records$record <- as.character(records$record)
  if (is.null(records$subject)) records$subject <- records$record
  if (is.null(records$fs)) records$fs <- NA_real_
  if (is.null(records$n_samples)) records$n_samples <- NA_real_
  records$subject <- as.character(records$subject)
  iss <- .empty_issues()
  bad <- is.na(records$record) | !is.finite(records$start) |
    !is.finite(records$end)
  if (any(bad)) {
    iss <- rbind(iss, .issue("error", "records", records$record[bad],
                             which(bad), "missing or non-finite value"))
  }
  dup <- duplicated(records$record)
  if (any(dup)) {
    iss <- rbind(iss, .issue("error", "records", records$record[dup],
                             which(dup), "duplicate record identifier"))
  }
  rev <- which(!bad & records$end <= records$start)
  if (length(rev)) {
    iss <- rbind(iss, .issue("error", "records", records$record[rev], rev,
                             "target period has end <= start"))
  }
  fsbad <- which(!is.na(records$fs) & records$fs <= 0)
  if (length(fsbad)) {
    iss <- rbind(iss, .issue("error", "records", records$record[fsbad], fsbad,
                             "sampling frequency must be positive"))
  }
  list(records = records, issues = iss)
}

# Validate and normalise one interval stream (reference, observation or
# predictions). `key` names the grouping columns inside a record (e.g.
# "detector"); `state` names the column holding the state label.
.prepare_stream <- function(df, name, state, records, key = character(),
                            allowed = NULL) {
  .require_cols(df, c("record", "start", "end", state, key), name)
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  df$.row <- seq_len(nrow(df))
  df$record <- as.character(df$record)
  df$start <- as.numeric(df$start)
  df$end <- as.numeric(df$end)
  df[[state]] <- as.character(df[[state]])
  for (k in key) df[[k]] <- as.character(df[[k]])
  iss <- .empty_issues()
  if (!nrow(df)) return(list(data = df, issues = iss))

  bad <- is.na(df$record) | !is.finite(df$start) | !is.finite(df$end)
  if (state != "label") bad <- bad | is.na(df[[state]])
  if (any(bad)) {
    iss <- rbind(iss, .issue("error", name, df$record[bad], df$.row[bad],
                             "missing or non-finite value"))
  }
  if (!is.null(allowed)) {
    wrong <- !bad & !(df[[state]] %in% allowed)
    if (any(wrong)) {
      iss <- rbind(iss, .issue("error", name, df$record[wrong],
                               df$.row[wrong],
                               sprintf("`%s` must be one of: %s", state,
                                       paste(allowed, collapse = ", ")),
                               df[[state]][wrong]))
    }
  }
  unk <- !bad & !(df$record %in% records$record)
  if (any(unk)) {
    iss <- rbind(iss, .issue("error", name, df$record[unk], df$.row[unk],
                             "record not present in `records`"))
  }
  rev <- !bad & df$end < df$start
  if (any(rev)) {
    iss <- rbind(iss, .issue("error", name, df$record[rev], df$.row[rev],
                             "reversed interval (end < start)",
                             sprintf("[%s, %s)", df$start[rev], df$end[rev])))
  }
  zero <- !bad & df$end == df$start
  if (any(zero)) {
    iss <- rbind(iss, .issue("warning", name, df$record[zero],
                             df$.row[zero],
                             "zero-length interval dropped"))
  }
  # Sample indices, when supplied, must be whole, non-negative and consistent
  # with the time columns and the record's sampling frequency.
  if (all(c("start_sample", "end_sample") %in% names(df))) {
    iss <- rbind(iss, .check_samples(df, name, records, bad))
  }
  keep <- !(bad | rev | zero | unk)
  if (any(iss$severity == "error")) {
    return(list(data = df[keep, , drop = FALSE], issues = iss))
  }
  df <- df[keep, , drop = FALSE]

  # Clip to the target period of each record.
  m <- match(df$record, records$record)
  rs <- records$start[m]
  re <- records$end[m]
  outside <- df$end <= rs | df$start >= re
  part <- !outside & (df$start < rs | df$end > re)
  if (any(outside)) {
    # A stream that lies entirely outside a record's target period usually
    # means a clock-origin mismatch, not an intentional choice.
    allout <- tapply(outside, df$record, all)
    clk <- names(allout)[allout]
    if (length(clk)) {
      iss <- rbind(iss, .issue("error", name, clk, NA,
                               "every row lies outside the target period; check the clock origin"))
    }
    iss <- rbind(iss, .issue("warning", name, df$record[outside],
                             df$.row[outside],
                             "interval outside the target period dropped"))
  }
  if (any(part)) {
    iss <- rbind(iss, .issue("warning", name, df$record[part],
                             df$.row[part],
                             "interval clipped to the target period"))
  }
  df <- df[!outside, , drop = FALSE]
  m <- match(df$record, records$record)
  df$start <- pmax(df$start, records$start[m])
  df$end <- pmin(df$end, records$end[m])

  # Exact duplicates are dropped with a warning.
  sig <- .group_key(df$record, if (length(key)) df[[key[1]]] else "",
                    df$start, df$end, df[[state]])
  dup <- duplicated(sig)
  if (any(dup)) {
    iss <- rbind(iss, .issue("warning", name, df$record[dup], df$.row[dup],
                             "duplicate interval dropped"))
    df <- df[!dup, , drop = FALSE]
  }

  # Overlaps inside a stream: contradictory states are errors, identical
  # states are merged.
  grp <- if (length(key)) .group_key(df$record, df[[key[1]]]) else df$record
  o <- order(grp, df$start, df$end)
  df <- df[o, , drop = FALSE]
  grp <- grp[o]
  if (nrow(df) > 1) {
    prev_end <- stats::ave(df$end, grp, FUN = function(x) {
      c(-Inf, cummax(x)[-length(x)])
    })
    ov <- df$start < prev_end
    if (any(ov)) {
      # Compare each overlapping row with the row that set the running end.
      idx <- which(ov)
      prev_state <- df[[state]][idx - 1L]
      contra <- idx[prev_state != df[[state]][idx] |
                      is.na(prev_state) != is.na(df[[state]][idx])]
      if (length(contra)) {
        iss <- rbind(iss, .issue("error", name, df$record[contra],
                                 df$.row[contra],
                                 "overlapping intervals with contradictory states",
                                 sprintf("[%s, %s) state %s overlaps previous state %s",
                                         df$start[contra], df$end[contra],
                                         df[[state]][contra],
                                         df[[state]][contra - 1L])))
      }
      same <- setdiff(idx, contra)
      if (length(same)) {
        iss <- rbind(iss, .issue("warning", name, df$record[same],
                                 df$.row[same],
                                 "overlapping intervals with the same state merged"))
        run <- .run_id(!ov | seq_along(ov) %in% contra)
        first <- !duplicated(run)
        ends <- tapply(df$end, run, max)
        df <- df[first, , drop = FALSE]
        df$end <- as.numeric(ends[as.character(run[first])])
      }
    }
  }
  rownames(df) <- NULL
  list(data = df, issues = iss)
}

.check_samples <- function(df, name, records, bad) {
  iss <- .empty_issues()
  m <- match(df$record, records$record)
  fs <- records$fs[m]
  ns <- records$n_samples[m]
  ss <- df$start_sample
  es <- df$end_sample
  nonint <- !bad & ((!is.na(ss) & ss != round(ss)) |
                      (!is.na(es) & es != round(es)))
  neg <- !bad & ((!is.na(ss) & ss < 0) | (!is.na(es) & es < 0))
  over <- !bad & !is.na(ns) & ((!is.na(es) & es > ns) |
                                 (!is.na(ss) & ss > ns))
  incons <- !bad & !is.na(fs) & !is.na(ss) &
    (abs(ss / fs - df$start) > 1 / fs | abs(es / fs - df$end) > 1 / fs)
  for (p in list(list(nonint, "sample index is not a whole number"),
                 list(neg, "negative sample index"),
                 list(over, "sample index beyond the end of the record"),
                 list(incons, "sample index disagrees with time and fs"))) {
    w <- which(p[[1]] %in% TRUE)
    if (length(w)) {
      iss <- rbind(iss, .issue("error", name, df$record[w], df$.row[w], p[[2]]))
    }
  }
  iss
}

#' Validate evaluation inputs without building a ledger
#'
#' Runs every check that [tl_ledger()] runs and returns the issues found.
#' Errors stop [tl_ledger()]; warnings and notes are kept as the `issues`
#' attribute of the ledger.
#'
#' @inheritParams tl_ledger
#' @return A data frame of issues with columns `severity` (`"error"`,
#'   `"warning"` or `"note"`), `table`, `record`, `row` (row number in the
#'   input table), `issue` and `detail`. It has zero rows when nothing was
#'   found.
#' @examples
#' fx <- tl_fixture("acceptance")
#' tl_validate(fx$records, fx$reference, fx$predictions)
#' @export
tl_validate <- function(records, reference, predictions, observation = NULL) {
  rc <- .check_records(records)
  if (any(rc$issues$severity == "error")) return(rc$issues)
  out <- list(rc$issues,
              .prepare_stream(reference, "reference", "label",
                              rc$records)$issues,
              .prepare_stream(predictions, "predictions", "response",
                              rc$records, key = "detector",
                              allowed = c("positive", "negative",
                                          "abstain"))$issues)
  if (!is.null(observation)) {
    out[[4]] <- .prepare_stream(observation, "observation", "status",
                                rc$records,
                                allowed = c("available", "unavailable"))$issues
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}
