# Edge cases listed in the specification.
rec <- tl_records("r", 0, 100)
ref_std <- data.frame(record = "r", start = c(0, 10, 20, 40, 60),
                      end = c(10, 20, 40, 60, 100),
                      label = c("N", "AF", "N", "AF", "N"))
pred <- function(start, end, response, detector = "D") {
  data.frame(record = "r", detector = detector, start = start, end = end,
             response = response)
}
run <- function(ref, prd, records = rec, ...) {
  led <- tl_ledger(records, ref, prd, time_unit = "min", ...)
  m <- tl_match(led)
  met <- tl_metrics(led, m, level = "pooled")
  list(led = led, m = m, met = met,
       get = function(nm) met$estimate[met$metric == nm],
       why = function(nm) met$undefined_reason[met$metric == nm])
}

# All abstained.
x <- run(ref_std, pred(0, 100, "abstain"))
expect_equal(x$get("answer_coverage"), 0)
expect_true(is.na(x$get("answered_sensitivity")))
expect_equal(x$why("answered_sensitivity"), "no event time during answered time")
expect_equal(x$get("full_capture"), 0)
expect_equal(x$get("burden_bound_lower"), 0)
expect_equal(x$get("burden_bound_upper"), 1)
expect_true(is.na(x$get("false_alarms_per_answered_hour")))

# No true events.
x <- run(data.frame(record = "r", start = 0, end = 100, label = "N"),
         pred(c(0, 50, 60), c(50, 60, 100), c("negative", "positive", "negative")))
expect_true(is.na(x$get("full_capture")))
expect_equal(x$why("full_capture"), "no reference-known event time")
expect_true(is.na(x$get("episode_sensitivity")))
expect_equal(x$why("episode_sensitivity"), "no eligible episodes")
expect_equal(x$get("false_alarms_per_answered_hour"), 0.6)
expect_equal(x$get("answered_specificity"), 0.9)

# No predicted events.
x <- run(ref_std, pred(0, 100, "negative"))
expect_equal(x$get("full_capture"), 0)
expect_equal(x$get("episode_sensitivity"), 0)
expect_equal(x$get("unmatched_alarms"), 0)
expect_true(is.na(x$get("duration_ppv")))

# Unknown reference throughout.
x <- run(data.frame(record = "r", start = 0, end = 100, label = "unknown"),
         pred(c(0, 50), c(50, 100), c("negative", "positive")))
expect_true(is.na(x$get("answer_coverage")))
expect_equal(x$why("answer_coverage"), "no reference-known target time")
expect_equal(x$m$alarms$status, "unassessable")
expect_equal(x$get("burden_bound_lower"), 0.5)
# Missing reference rows behave the same as explicit unknown labels.
x2 <- run(data.frame(record = "r", start = 0, end = 0.5, label = "unknown")[0, ],
          pred(c(0, 50), c(50, 100), c("negative", "positive")))
expect_true(is.na(x2$get("answer_coverage")))

# A single long episode covering the whole record (already in progress).
x <- run(data.frame(record = "r", start = 0, end = 100, label = "AF"),
         pred(c(0, 30), c(30, 100), c("negative", "positive")))
e <- tl_episodes(x$led)
expect_equal(nrow(e), 1L)
expect_equal(e$onset_status, "recording_start")
expect_equal(e$offset_status, "recording_end")
expect_equal(x$get("full_capture"), 0.7)
expect_equal(x$m$episodes$latency_status, "onset not observed (recording_start)")

# Duplicate rows are dropped with a warning and do not change results.
dup <- rbind(pred(c(0, 10, 20), c(10, 20, 100), c("negative", "positive", "negative")),
             pred(10, 20, "positive"))
x <- run(ref_std, dup)
iss <- attr(x$led, "issues")
expect_true(any(iss$issue == "duplicate interval dropped"))
expect_equal(x$get("full_capture"), 1 / 3)

# One alarm spanning two episodes.
sp <- pred(c(0, 15, 50), c(15, 50, 100), c("negative", "positive", "negative"))
x <- run(ref_std, sp)
expect_equal(nrow(x$m$alarms), 1L)
expect_equal(x$get("episode_sensitivity"), 0.5)   # one-to-one
ao <- tl_metrics(x$led, tl_match(x$led, policy = "any_overlap"), "pooled")
expect_equal(ao$estimate[ao$metric == "episode_sensitivity"], 1)

# Several alarms during one episode: one matched, the others redundant.
mu <- pred(c(0, 41, 43, 45, 47, 60), c(41, 43, 45, 47, 60, 100),
           c("negative", "positive", "negative", "positive", "negative", "negative"))
x <- run(ref_std, mu)
expect_equal(sort(x$m$alarms$status), c("matched", "redundant"))
expect_equal(x$get("false_alarms_per_answered_hour"), 0)
expect_equal(x$get("unmatched_alarms"), 1)
expect_equal(x$m$episodes$n_alarms[x$m$episodes$episode_id == "r:e002"], 2L)
# Merging alarms closer than 3 minutes gives one alarm.
mm <- tl_match(x$led, alarm_merge_gap = 3)
expect_equal(nrow(mm$alarms), 1L)

# Adjacent intervals: touching does not count as overlap.
ad <- pred(c(0, 20, 40), c(20, 40, 100), c("negative", "positive", "negative"))
x <- run(ref_std, ad)
expect_equal(x$m$alarms$status, "false")
expect_equal(x$get("episode_sensitivity"), 0)
# Adjacent reference rows with the same label form one episode.
x <- run(data.frame(record = "r", start = c(0, 10, 15, 20), end = c(10, 15, 20, 100),
                    label = c("N", "AF", "AF", "N")),
         pred(0, 100, "negative"))
expect_equal(nrow(tl_episodes(x$led)), 1L)

# Partial reference coverage: uncovered time is unknown and excluded.
x <- run(data.frame(record = "r", start = c(20, 40), end = c(40, 60), label = c("N", "AF")),
         pred(c(0, 40), c(40, 100), c("negative", "positive")))
expect_equal(x$met$denominator[x$met$metric == "answer_coverage"], 40)
expect_equal(x$met$excluded_time[x$met$metric == "answer_coverage"], 60)
expect_equal(x$get("full_capture"), 1)
expect_equal(tl_episodes(x$led)$onset_status, "observed")
expect_equal(tl_episodes(x$led)$offset_status, "before_unknown_reference")

# Different sampling rates and several records whose clocks start at zero.
recs <- tl_records(c("a", "b"), 0, c(10, 20), fs = c(250, 128),
                   n_samples = c(2500, 2560))
ref2 <- data.frame(record = c("a", "a", "b", "b"), start = c(0, 5, 0, 10),
                   end = c(5, 10, 10, 20), label = c("N", "AF", "N", "AF"),
                   start_sample = c(0, 1250, 0, 1280),
                   end_sample = c(1250, 2500, 1280, 2560))
prd2 <- data.frame(record = c("a", "b"), detector = "D", start = 0,
                   end = c(10, 20), response = "positive")
led <- tl_ledger(recs, ref2, prd2, time_unit = "s")
cb <- tl_contributions(led)
expect_equal(cb$event[cb$record == "a"], 5)
expect_equal(cb$event[cb$record == "b"], 10)
expect_true(all(tl_check(led)$ok))
bad <- ref2
bad$end_sample[2] <- 3000
expect_error(tl_ledger(recs, bad, prd2), "beyond the end")

# Missing predictions: meaning must be declared, never silently negative.
gap <- pred(c(0, 50), c(30, 100), c("negative", "negative"))
x <- run(ref_std, gap)
expect_true(all(x$led$response[x$led$start >= 30 & x$led$end <= 50] == "unknown"))
expect_equal(x$get("missed_unknown_min"), 10)
x <- run(ref_std, gap, missing = "negative")
expect_equal(x$get("missed_negative_min"), 30)

# Input unavailable vs abstention vs negative.
obs <- data.frame(record = "r", start = c(0, 45, 50), end = c(45, 50, 100),
                  status = c("available", "unavailable", "available"),
                  reason = c(NA, "electrode off", NA))
prd <- pred(c(0, 40, 50), c(40, 50, 100), c("negative", "abstain", "negative"))
led <- tl_ledger(rec, ref_std, prd, observation = obs, time_unit = "min")
L <- as.data.frame(led)
expect_equal(L$response[L$start == 40], "abstain")
expect_equal(L$response[L$start == 45], "no_input")
expect_equal(L$response_reason[L$start == 45], "electrode off")
met <- tl_metrics(led, level = "pooled")
expect_equal(met$estimate[met$metric == "answer_coverage_given_input"], 90 / 95)
expect_equal(met$estimate[met$metric == "missed_no_input_min"], 5)
# An answer during declared unavailability is flagged, not hidden.
prd_c <- pred(c(0, 50), c(50, 100), c("negative", "negative"))
led_c <- tl_ledger(rec, ref_std, prd_c, observation = obs, time_unit = "min")
expect_true(any(led_c$conflict))
expect_true(any(attr(led_c, "issues")$issue ==
                  "detector answered while input was declared unavailable"))

# A user-supplied episode id survives a reference gap.
refg <- data.frame(record = "r", start = c(0, 40, 50, 55, 70),
                   end = c(40, 50, 55, 70, 100),
                   label = c("N", "AF", "unknown", "AF", "N"),
                   episode = c(NA, "ep1", NA, "ep1", NA))
x <- run(refg, pred(0, 100, "negative"))
e <- tl_episodes(x$led)
expect_equal(nrow(e), 1L)
expect_equal(e$n_fragments, 2L)
expect_equal(e$event_time, 25)
# Without ids, the same reference gives two fragments that are not merged
# across unknown time, even with a merge gap.
refg$episode <- NULL
x <- run(refg, pred(0, 100, "negative"))
expect_equal(nrow(tl_episodes(x$led, merge_gap = 10)), 2L)
# Known non-event gaps can be merged.
refm <- data.frame(record = "r", start = c(0, 40, 50, 52, 70),
                   end = c(40, 50, 52, 70, 100), label = c("N", "AF", "N", "AF", "N"))
x <- run(refm, pred(0, 100, "negative"))
expect_equal(nrow(tl_episodes(x$led, merge_gap = 2)), 1L)
expect_equal(nrow(tl_episodes(x$led, merge_gap = 1)), 2L)

# Latency needs an observed onset, issued_at and an answering detector.
pl <- tl_from_windows("r", "D", decided_at = c(0, 12, 22, 45, 61),
                      response = c("negative", "positive", "negative",
                                   "positive", "negative"))
x <- run(ref_std, pl)
ep <- x$m$episodes
expect_equal(ep$latency[ep$episode_id == "r:e001"], 2)
expect_equal(ep$latency[ep$episode_id == "r:e002"], 5)
expect_true(all(ep$latency_status == "observed"))

# An alarm that was already active at onset has no latency.
pe <- tl_from_windows("r", "D", decided_at = c(0, 5, 22, 45, 61),
                      response = c("negative", "positive", "negative",
                                   "positive", "negative"), until = 100)
x <- run(ref_std, pe)
ep <- x$m$episodes
expect_equal(ep$latency_status[ep$episode_id == "r:e001"], "alarm already active at onset")
expect_true(is.na(ep$latency[ep$episode_id == "r:e001"]))
expect_equal(ep$latency[ep$episode_id == "r:e002"], 5)
