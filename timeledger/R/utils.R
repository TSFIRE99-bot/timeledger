# Internal constants and helpers ------------------------------------------------

.ref_states  <- c("event", "nonevent", "unknown")
.obs_states  <- c("available", "unavailable", "unknown")
.resp_states <- c("positive", "negative", "abstain", "no_input", "unknown")
.answered    <- c("positive", "negative")
.missing_meanings <- c("unknown", "abstain", "negative", "no_input")

.unit_seconds <- function(unit) {
  switch(unit, ms = 0.001, s = 1, min = 60, h = 3600,
         stop("`time_unit` must be one of \"ms\", \"s\", \"min\" or \"h\".",
              call. = FALSE))
}

# Convert a duration expressed in `time_unit` to hours / minutes.
.to_hours <- function(x, time_unit) x * .unit_seconds(time_unit) / 3600
.to_minutes <- function(x, time_unit) x * .unit_seconds(time_unit) / 60

.require_cols <- function(df, cols, name) {
  if (!is.data.frame(df)) {
    stop(sprintf("`%s` must be a data frame.", name), call. = FALSE)
  }
  miss <- setdiff(cols, names(df))
  if (length(miss)) {
    stop(sprintf("`%s` is missing required column(s): %s.", name,
                 paste(miss, collapse = ", ")), call. = FALSE)
  }
  invisible(TRUE)
}

.issue <- function(severity, table, record, row, issue, detail = "") {
  n <- max(length(record), length(row), length(issue), 1L)
  if (!length(record)) record <- NA_character_
  if (!length(row)) row <- NA_integer_
  data.frame(severity = rep_len(severity, n), table = rep_len(table, n),
             record = rep_len(as.character(record), n),
             row = rep_len(as.integer(row), n),
             issue = rep_len(issue, n), detail = rep_len(as.character(detail), n),
             stringsAsFactors = FALSE)
}

.empty_issues <- function() {
  data.frame(severity = character(), table = character(), record = character(),
             row = integer(), issue = character(), detail = character(),
             stringsAsFactors = FALSE)
}

# A ratio that keeps its numerator, denominator and an explicit reason when it
# cannot be computed.
.ratio <- function(num, den, zero_reason) {
  est <- ifelse(den > 0, num / den, NA_real_)
  why <- ifelse(den > 0, NA_character_, zero_reason)
  list(estimate = est, reason = why)
}

.group_key <- function(...) {
  do.call(paste, c(list(...), sep = "\r"))
}

# Run identifiers: a new run starts whenever `new` is TRUE.
.run_id <- function(new) cumsum(new)
