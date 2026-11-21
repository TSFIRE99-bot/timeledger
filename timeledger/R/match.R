#' Match reference episodes to alarms
#'
#' Pairs reference episodes with detector alarms under a named policy and
#' records the overlap behind every decision.
#'
#' **Overlap.** The overlap between an episode and an alarm is the ledger time
#' on which the reference is the event, the row belongs to the episode, and
#' the detector response is positive. Intervals that only touch (one ends
#' where the other starts) have zero overlap.
#'
#' **Eligibility.** With `scope = "full"`, an episode is eligible when its
#' reference-known event time after the learning period is at least
#' `min_episode_time`. With `scope = "answered"`, the time counted is event
#' time on which the detector answered (positive or negative). Ineligible
#' episodes are kept in the output with the reason.
#'
#' **Policies.**
#' * `"any_overlap"`: an episode is detected when any alarm overlaps it by
#'   more than `min_overlap`; an alarm is matched when it overlaps any
#'   eligible episode. One alarm may detect several episodes, and several
#'   alarms may share one episode. This is the rule used by WFDB `epicmp`
#'   for AF episodes (see [wfdb_epicmp_af()] for the full compatible
#'   procedure).
#' * `"one_to_one"`: each episode is matched to at most one alarm and each
#'   alarm to at most one episode. Pairs are eligible when their overlap
#'   exceeds `min_overlap`. The matching maximises the number of pairs, then
#'   the total overlap; remaining ties are broken towards pairs that occur
#'   earlier in time. Because neither episodes nor alarms overlap among
#'   themselves, the candidate pairs never cross in time, and the optimum is
#'   found exactly by dynamic programming over the time-ordered pairs.
#'
#' Alarms are classified as `"matched"`, `"redundant"` (overlaps an eligible
#' episode but was not paired, which happens only under `"one_to_one"`, e.g.
#' a second alarm during one episode), `"false"` (no overlap with any
#' reference event), `"ineligible_overlap"` (overlaps only ineligible
#' episodes), `"unassessable"` (no reference-known time) or
#' `"learning_period"`.
#'
#' **Latency** is reported only when the episode onset was observed, the
#' matched alarm has an `issued_at` time, and the detector was answering at
#' the onset. Otherwise `latency` is `NA` and `latency_status` says why.
#'
#' @param ledger A `tl_ledger`.
#' @param policy `"one_to_one"` or `"any_overlap"`.
#' @param scope `"full"` or `"answered"`; see Eligibility.
#' @param min_overlap Pairs need overlap strictly greater than this.
#' @param min_episode_time Minimum counted event time for eligibility.
#' @param learning_period Time at the start of each record excluded from
#'   matching (episodes are clipped; alarms ending inside it are set aside).
#' @param episode_merge_gap,alarm_merge_gap,alarm_min_duration Passed to
#'   [tl_episodes()] and [tl_alarms()].
#' @return An object of class `tl_match`: a list with `episodes` (one row per
#'   episode and detector), `alarms`, `pairs` and `settings`.
#' @examples
#' fx <- tl_fixture("acceptance")
#' led <- tl_ledger(fx$records, fx$reference, fx$predictions,
#'                  time_unit = "min")
#' m <- tl_match(led)
#' m$episodes
#' m$alarms
#' @export
tl_match <- function(ledger, policy = c("one_to_one", "any_overlap"),
                     scope = c("full", "answered"), min_overlap = 0,
                     min_episode_time = 0, learning_period = 0,
                     episode_merge_gap = 0, alarm_merge_gap = 0,
                     alarm_min_duration = 0) {
  stopifnot(inherits(ledger, "tl_ledger"))
  policy <- match.arg(policy)
  scope <- match.arg(scope)
  rec <- attr(ledger, "records")
  if (learning_period > 0) {
    ledger <- tl_split(ledger, data.frame(record = rec$record,
                                          time = rec$start + learning_period,
                                          stringsAsFactors = FALSE))
  }
  eps <- tl_episodes(ledger, merge_gap = episode_merge_gap)
  ar <- .alarm_runs(ledger, alarm_merge_gap, alarm_min_duration)
  alarms <- ar$alarms
  L <- as.data.frame(ledger)
  L$alarm_id <- ar$row_alarm
  # Map original episode ids to (possibly merged) episode ids.
  memb <- strsplit(eps$members, "+", fixed = TRUE)
  map <- stats::setNames(rep(eps$episode_id, lengths(memb)), unlist(memb))
  L$episode_id <- unname(map[L$ref_episode])
  L$episode_id[L$reference != "event"] <- NA_character_
  # Learning period: drop the first `learning_period` of each record.
  lp_end <- rec$start[match(L$record, rec$record)] + learning_period
  in_eval <- L$start >= lp_end
  dets <- attr(ledger, "detectors")
  ep_rows <- list()
  al_rows <- list()
  pair_rows <- list()
  for (d in dets) {
    Ld <- L[L$detector == d, ]
    ev <- Ld[!is.na(Ld$episode_id) & in_eval[L$detector == d], ]
    counted <- if (scope == "full") ev else ev[ev$response %in% .answered, ]
    ct <- tapply(counted$duration, counted$episode_id, sum)
    e <- eps
    e$detector <- rep(d, nrow(e))
    e$counted_time <- ifelse(e$episode_id %in% names(ct), ct[e$episode_id], 0)
    e$eligible <- e$counted_time > 0 & e$counted_time >= min_episode_time
    e$eligibility_reason <- ifelse(e$eligible, NA_character_,
                                   ifelse(e$counted_time > 0,
                                          "below min_episode_time",
                                          if (scope == "full")
                                            "no reference-known event time in scope"
                                          else "no answered event time"))
    # Candidate pairs: overlap of eligible episodes with alarms.
    ov <- ev[ev$response == "positive" & !is.na(ev$alarm_id), ]
    if (nrow(ov)) {
      pr <- stats::aggregate(duration ~ episode_id + alarm_id, data = ov,
                             FUN = sum)
      names(pr)[3] <- "overlap"
    } else {
      pr <- data.frame(episode_id = character(), alarm_id = character(),
                       overlap = numeric(), stringsAsFactors = FALSE)
    }
    pr <- pr[pr$overlap > min_overlap, , drop = FALSE]
    elig_pr <- pr[pr$episode_id %in% e$episode_id[e$eligible], , drop = FALSE]
    a <- alarms[alarms$detector == d, , drop = FALSE]
    if (policy == "one_to_one") {
      chosen <- .match_one_to_one(elig_pr, e, a)
    } else {
      chosen <- elig_pr
    }
    chosen$detector <- rep(d, nrow(chosen))
    # Episode outcomes.
    e$detected <- e$eligible & e$episode_id %in% chosen$episode_id
    first <- chosen[order(chosen$episode_id,
                          a$start[match(chosen$alarm_id, a$alarm_id)]), ]
    first <- first[!duplicated(first$episode_id), ]
    e$alarm_id <- first$alarm_id[match(e$episode_id, first$episode_id)]
    e$overlap <- ifelse(is.na(e$alarm_id), 0,
                        first$overlap[match(e$episode_id, first$episode_id)])
    e$n_alarms <- as.integer(table(factor(elig_pr$episode_id,
                                          levels = e$episode_id)))
    lat <- .latency(e, a, Ld)
    e$latency <- lat$latency
    e$latency_status <- lat$status
    ep_rows[[d]] <- e
    # Alarm outcomes.
    lp_alarm <- a$end <= rec$start[match(a$record, rec$record)] + learning_period
    any_ev <- tapply(Ld$duration[Ld$reference == "event" & !is.na(Ld$alarm_id)],
                     Ld$alarm_id[Ld$reference == "event" & !is.na(Ld$alarm_id)],
                     sum)
    touches_ev <- a$alarm_id %in% names(any_ev)
    touches_elig <- a$alarm_id %in% elig_pr$alarm_id
    a$status <- ifelse(lp_alarm, "learning_period",
                ifelse(a$alarm_id %in% chosen$alarm_id, "matched",
                ifelse(touches_elig, "redundant",
                ifelse(touches_ev, "ineligible_overlap",
                ifelse(a$known_time <= 0, "unassessable", "false")))))
    a$episode_id <- chosen$episode_id[match(a$alarm_id, chosen$alarm_id)]
    a$overlap <- ifelse(is.na(a$episode_id), 0,
                        chosen$overlap[match(a$alarm_id, chosen$alarm_id)])
    al_rows[[d]] <- a
    pair_rows[[d]] <- chosen
  }
  bind <- function(x) {
    y <- do.call(rbind, x)
    rownames(y) <- NULL
    y
  }
  structure(list(episodes = bind(ep_rows), alarms = bind(al_rows),
                 pairs = bind(pair_rows),
                 settings = list(policy = policy, scope = scope,
                                 min_overlap = min_overlap,
                                 min_episode_time = min_episode_time,
                                 learning_period = learning_period,
                                 episode_merge_gap = episode_merge_gap,
                                 alarm_merge_gap = alarm_merge_gap,
                                 alarm_min_duration = alarm_min_duration,
                                 time_unit = attr(ledger, "settings")$time_unit)),
            class = "tl_match")
}

# Exact maximum matching for non-crossing interval pairs. Pairs are sorted by
# episode start then alarm start; for pair k, the conflicting pairs (sharing
# its episode or alarm) form a contiguous block ending at k - 1, so
# F[k] = best(F[k - 1], F[p(k)] + w[k]) with w = (1, overlap) compared
# lexicographically. Ties keep F[k - 1], which prefers earlier pairs.
.match_one_to_one <- function(pr, e, a) {
  if (!nrow(pr)) return(pr)
  es <- e$start[match(pr$episode_id, e$episode_id)]
  as <- a$start[match(pr$alarm_id, a$alarm_id)]
  # Pairs from different records never conflict; order by record first.
  er <- e$record[match(pr$episode_id, e$episode_id)]
  o <- order(er, es, as)
  pr <- pr[o, , drop = FALSE]
  m <- nrow(pr)
  first_ep <- match(pr$episode_id, pr$episode_id)
  first_al <- match(pr$alarm_id, pr$alarm_id)
  p <- pmin(first_ep, first_al) - 1L
  # The recursion needs each alarm's pairs to be contiguous after sorting
  # (episode pairs are contiguous by construction). This holds whenever
  # episodes and alarms are each non-overlapping; check it anyway.
  idx <- seq_len(m)
  contig <- tapply(idx, pr$alarm_id, function(i) max(i) - min(i) + 1L == length(i))
  if (!all(contig)) {
    stop("Internal error: crossing episode-alarm pairs.", call. = FALSE)
  }
  cnt <- numeric(m + 1L)
  tot <- numeric(m + 1L)
  take <- logical(m)
  for (k in seq_len(m)) {
    c1 <- cnt[k]
    t1 <- tot[k]
    c2 <- cnt[p[k] + 1L] + 1
    t2 <- tot[p[k] + 1L] + pr$overlap[k]
    better <- c2 > c1 || (c2 == c1 && t2 > t1 + 1e-12 * max(1, abs(t1)))
    take[k] <- better
    cnt[k + 1L] <- if (better) c2 else c1
    tot[k + 1L] <- if (better) t2 else t1
  }
  sel <- integer()
  k <- m
  while (k >= 1L) {
    if (take[k]) {
      sel <- c(k, sel)
      k <- p[k]
    } else {
      k <- k - 1L
    }
  }
  out <- pr[sel, , drop = FALSE]
  rownames(out) <- NULL
  out
}

.latency <- function(e, a, Ld) {
  n <- nrow(e)
  lat <- rep(NA_real_, n)
  st <- rep(NA_character_, n)
  for (i in seq_len(n)) {
    if (!isTRUE(e$detected[i])) {
      st[i] <- "not detected"
      next
    }
    if (e$onset_status[i] != "observed") {
      st[i] <- paste0("onset not observed (", e$onset_status[i], ")")
      next
    }
    iss <- a$issued_at[match(e$alarm_id[i], a$alarm_id)]
    if (is.na(iss)) {
      st[i] <- "issued_at not supplied"
      next
    }
    at_onset <- Ld[Ld$record == e$record[i] & Ld$start == e$start[i], ]
    if (!nrow(at_onset) || !(at_onset$response[1] %in% .answered)) {
      st[i] <- "detector not answering at onset"
      next
    }
    lat[i] <- iss - e$start[i]
    st[i] <- "observed"
  }
  list(latency = lat, status = st)
}

#' @export
print.tl_match <- function(x, ...) {
  s <- x$settings
  cat(sprintf("<tl_match> policy=%s scope=%s min_overlap=%s learning_period=%s\n",
              s$policy, s$scope, s$min_overlap, s$learning_period))
  e <- x$episodes
  a <- x$alarms
  for (d in unique(e$detector)) {
    ed <- e[e$detector == d, ]
    ad <- a[a$detector == d, , drop = FALSE]
    tab <- table(factor(ad$status, levels = c("matched", "redundant", "false",
                                              "ineligible_overlap",
                                              "unassessable",
                                              "learning_period")))
    cat(sprintf("  %s: %d/%d eligible episodes detected; alarms: %s\n", d,
                sum(ed$detected), sum(ed$eligible),
                paste(names(tab), tab, sep = "=", collapse = ", ")))
  }
  invisible(x)
}
