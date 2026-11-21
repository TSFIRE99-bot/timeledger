#' Reference episodes
#'
#' Collects the reference event intervals of a ledger into episodes. An
#' episode keeps one identifier even when gaps in observation or prediction
#' cut it into several ledger rows, so clipping never creates extra
#' physiological episodes. The table separates what was observed from what
#' was not: an episode already in progress when the recording starts has
#' `onset_status = "recording_start"`, and one that follows unknown reference
#' time has `onset_status = "after_unknown_reference"`. Only episodes with
#' `onset_status = "observed"` have a known onset.
#'
#' @param ledger A `tl_ledger`.
#' @param merge_gap Episodes of the same record separated by known non-event
#'   time no longer than this are merged (in the ledger's time unit).
#'   Episodes separated by unknown reference time are never merged.
#' @return A data frame with one row per episode: `episode_id`, `record`,
#'   `start`, `end` (span), `event_time` (event time on reference-known
#'   rows of the ledger), `n_fragments`, `onset_status`, `offset_status`,
#'   and `members` (original identifiers merged into this episode).
#' @examples
#' fx <- tl_fixture("acceptance")
#' tl_episodes(tl_ledger(fx$records, fx$reference, fx$predictions,
#'                       time_unit = "min"))
#' @export
tl_episodes <- function(ledger, merge_gap = 0) {
  stopifnot(inherits(ledger, "tl_ledger"))
  ref <- attr(ledger, "reference_rows")
  rec <- attr(ledger, "records")
  d1 <- attr(ledger, "detectors")[1]
  # Use one detector's rows: the reference columns are identical across
  # detectors.
  L <- ledger[ledger$detector == d1 & !is.na(ledger$ref_episode), ]
  empty <- data.frame(episode_id = character(), record = character(),
                      start = numeric(), end = numeric(),
                      event_time = numeric(), n_fragments = integer(),
                      onset_status = character(), offset_status = character(),
                      members = character(), stringsAsFactors = FALSE)
  if (!nrow(L)) return(empty)
  ev <- ref[!is.na(ref$episode), ]
  sp <- stats::aggregate(cbind(start, end) ~ episode + record, data = ev,
                         FUN = function(z) z[1])
  sp$start <- tapply(ev$start, ev$episode, min)[sp$episode]
  sp$end <- tapply(ev$end, ev$episode, max)[sp$episode]
  sp$n_fragments <- as.integer(table(ev$episode)[sp$episode])
  # Event time that is still reference-known in the ledger (restrictions
  # turn excluded rows into unknown time).
  known <- L[L$reference == "event", ]
  et <- tapply(known$duration, known$ref_episode, sum)
  sp$event_time <- ifelse(sp$episode %in% names(et), et[sp$episode], 0)
  sp <- sp[order(sp$record, sp$start), ]
  # Episode spans of different identifiers must not interleave.
  if (nrow(sp) > 1) {
    same <- sp$record[-1] == sp$record[-nrow(sp)]
    bad <- same & sp$start[-1] < sp$end[-nrow(sp)]
    if (any(bad)) {
      stop(sprintf("Reference episodes overlap or interleave (e.g. %s and %s).",
                   sp$episode[which(bad)[1]], sp$episode[which(bad)[1] + 1]),
           call. = FALSE)
    }
  }
  # Onset and offset status from the neighbouring reference rows.
  refk <- ref[order(ref$record, ref$start), ]
  # State of the reference row that ends where the episode starts, and of
  # the row that starts where it ends (keyed lookups, linear time).
  before <- refk$state[match(.group_key(sp$record, sp$start),
                             .group_key(refk$record, refk$end))]
  after <- refk$state[match(.group_key(sp$record, sp$end),
                            .group_key(refk$record, refk$start))]
  before[is.na(before)] <- "unknown"
  after[is.na(after)] <- "unknown"
  rs <- rec$start[match(sp$record, rec$record)]
  re <- rec$end[match(sp$record, rec$record)]
  sp$onset_status <- ifelse(sp$start <= rs, "recording_start",
                            ifelse(before == "nonevent", "observed",
                                   "after_unknown_reference"))
  sp$offset_status <- ifelse(sp$end >= re, "recording_end",
                             ifelse(after == "nonevent", "observed",
                                    "before_unknown_reference"))
  sp$members <- sp$episode
  if (merge_gap > 0 && nrow(sp) > 1) {
    sp <- .merge_episodes(sp, refk, merge_gap)
  }
  out <- data.frame(episode_id = sp$episode, record = sp$record,
                    start = sp$start, end = sp$end,
                    event_time = as.numeric(sp$event_time),
                    n_fragments = sp$n_fragments,
                    onset_status = sp$onset_status,
                    offset_status = sp$offset_status,
                    members = sp$members, stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}

.merge_episodes <- function(sp, refk, gap) {
  grp <- integer(nrow(sp))
  g <- 1L
  grp[1] <- g
  for (i in seq_len(nrow(sp))[-1]) {
    same <- sp$record[i] == sp$record[i - 1]
    gap_len <- sp$start[i] - sp$end[i - 1]
    between <- refk[refk$record == sp$record[i] & refk$start < sp$start[i] &
                      refk$end > sp$end[i - 1], ]
    covered <- sum(pmin(between$end, sp$start[i]) -
                     pmax(between$start, sp$end[i - 1]))
    known_gap <- nrow(between) > 0 && all(between$state == "nonevent") &&
      abs(covered - gap_len) < 1e-9
    if (!(same && gap_len <= gap && known_gap)) g <- g + 1L
    grp[i] <- g
  }
  out <- do.call(rbind, lapply(split(sp, grp), function(x) {
    data.frame(episode = x$episode[1], record = x$record[1],
               start = min(x$start), end = max(x$end),
               n_fragments = sum(x$n_fragments),
               event_time = sum(x$event_time),
               onset_status = x$onset_status[1],
               offset_status = x$offset_status[nrow(x)],
               members = paste(x$members, collapse = "+"),
               stringsAsFactors = FALSE)
  }))
  out
}

#' Alarms raised by each detector
#'
#' An alarm is a maximal run of positive responses in the ledger. Runs
#' separated by no more than `merge_gap` (of any other response) are merged,
#' and alarms with less than `min_duration` of positive time are dropped and
#' reported in the `suppressed` attribute.
#'
#' @param ledger A `tl_ledger`.
#' @param merge_gap Maximum gap between positive runs merged into one alarm.
#' @param min_duration Minimum positive time for an alarm to count.
#' @return A data frame with one row per alarm: `alarm_id`, `record`,
#'   `detector`, `start`, `end`, `positive_time`, `known_time` (positive time
#'   on reference-known rows), `issued_at` (earliest decision time among the
#'   contributing prediction rows, when supplied).
#' @examples
#' fx <- tl_fixture("acceptance")
#' tl_alarms(tl_ledger(fx$records, fx$reference, fx$predictions,
#'                     time_unit = "min"))
#' @export
tl_alarms <- function(ledger, merge_gap = 0, min_duration = 0) {
  res <- .alarm_runs(ledger, merge_gap, min_duration)
  out <- res$alarms
  attr(out, "suppressed") <- res$suppressed
  out
}

# Returns alarms and the ledger-row-to-alarm map.
.alarm_runs <- function(ledger, merge_gap = 0, min_duration = 0) {
  L <- as.data.frame(ledger)
  L$.i <- seq_len(nrow(L))
  pos <- L[L$response == "positive", , drop = FALSE]
  empty <- data.frame(alarm_id = character(), record = character(),
                      detector = character(), start = numeric(),
                      end = numeric(), positive_time = numeric(),
                      known_time = numeric(), issued_at = numeric(),
                      stringsAsFactors = FALSE)
  row_alarm <- rep(NA_character_, nrow(L))
  if (!nrow(pos)) {
    return(list(alarms = empty, row_alarm = row_alarm, suppressed = empty))
  }
  pos <- pos[order(pos$record, pos$detector, pos$start), ]
  key <- .group_key(pos$record, pos$detector)
  prev_end <- c(-Inf, pos$end[-nrow(pos)])
  prev_key <- c("", key[-length(key)])
  new <- key != prev_key | (pos$start - prev_end) > merge_gap
  run <- .run_id(new)
  k <- stats::ave(as.numeric(new), key, FUN = cumsum)
  ids <- sprintf("%s:%s:a%03d", pos$record, pos$detector, as.integer(k))
  a <- data.frame(alarm_id = ids[!duplicated(run)],
                  record = pos$record[!duplicated(run)],
                  detector = pos$detector[!duplicated(run)],
                  start = as.numeric(tapply(pos$start, run, min)),
                  end = as.numeric(tapply(pos$end, run, max)),
                  positive_time = as.numeric(tapply(pos$duration, run, sum)),
                  known_time = as.numeric(tapply(
                    pos$duration * (pos$reference != "unknown"), run, sum)),
                  issued_at = as.numeric(tapply(pos$issued_at, run, function(z) {
                    if (all(is.na(z))) NA_real_ else min(z, na.rm = TRUE)
                  })),
                  stringsAsFactors = FALSE)
  keep <- a$positive_time >= min_duration
  row_alarm[pos$.i] <- ids
  row_alarm[!(row_alarm %in% a$alarm_id[keep])] <- NA_character_
  list(alarms = a[keep, , drop = FALSE], row_alarm = row_alarm,
       suppressed = a[!keep, , drop = FALSE])
}
