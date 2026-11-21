# Mandatory acceptance fixture (100-minute recording).
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
m <- tl_match(led, policy = "one_to_one")
met <- tl_metrics(led, m, level = "pooled")
get <- function(nm) met$estimate[met$metric == nm]
num <- function(nm) met$numerator[met$metric == nm]
den <- function(nm) met$denominator[met$metric == nm]

expect_true(all(tl_check(led)$ok))
expect_equal(get("answer_coverage"), 0.80)
expect_equal(c(num("answer_coverage"), den("answer_coverage")), c(80, 100))
expect_equal(get("answered_sensitivity"), 1)
expect_equal(c(num("answered_sensitivity"), den("answered_sensitivity")), c(10, 10))
expect_equal(get("full_capture"), 1 / 3)
expect_equal(c(num("full_capture"), den("full_capture")), c(10, 30))
expect_equal(get("episode_sensitivity"), 0.5)
expect_equal(c(num("episode_sensitivity"), den("episode_sensitivity")), c(1, 2))
expect_equal(get("unmatched_alarms"), 1)
expect_equal(get("false_alarms_per_answered_hour"), 1 / (80 / 60))
expect_equal(get("false_alarms_per_answered_hour"), 0.75)
expect_equal(get("pred_burden_answered"), 0.25)
expect_equal(c(num("pred_burden_answered"), den("pred_burden_answered")), c(20, 80))
expect_equal(get("ref_burden_answered"), 0.125)
expect_equal(get("burden_bound_lower"), 0.20)
expect_equal(get("burden_bound_upper"), 0.40)
# The unanswered AF is visible as missed opportunity with its reason.
expect_equal(get("missed_abstain_min"), 20)
expect_equal(get("missed_negative_min"), 0)

# The same outputs hold with times in seconds.
fx_s <- fx
fx_s$records$end <- fx_s$records$end * 60
for (nm in c("reference", "predictions")) {
  fx_s[[nm]]$start <- fx_s[[nm]]$start * 60
  fx_s[[nm]]$end <- fx_s[[nm]]$end * 60
}
led_s <- tl_ledger(fx_s$records, fx_s$reference, fx_s$predictions, time_unit = "s")
met_s <- tl_metrics(led_s, tl_match(led_s), level = "pooled")
expect_equal(met_s$estimate[met_s$metric == "false_alarms_per_answered_hour"], 0.75)
expect_equal(met_s$estimate[met_s$metric == "full_capture"], 1 / 3)

# The false alarm can be traced to its source interval.
fa <- m$alarms[m$alarms$status == "false", ]
expect_equal(nrow(fa), 1L)
tr <- tl_explain(led, m, alarm = fa$alarm_id)
expect_equal(tr$start, 70)
expect_equal(tr$end, 80)
expect_equal(tr$reference, "nonevent")
# The missed episode traces to its abstained minutes and their reason.
ex <- tl_explain(led, m, episode = "rec1:e002")
expect_equal(sum(ex$duration), 20)
expect_true(all(ex$response == "abstain"))
expect_equal(unique(ex$response_reason), "low signal quality")

# Second mandatory fixture: equal durations, zero overlap.
fx2 <- tl_fixture("burden_mismatch")
led2 <- tl_ledger(fx2$records, fx2$reference, fx2$predictions, time_unit = "min")
met2 <- tl_metrics(led2, tl_match(led2), level = "pooled")
g2 <- function(nm) met2$estimate[met2$metric == nm]
expect_equal(g2("burden_diff_pp"), 0)
expect_equal(g2("burden_error_min"), 0)
expect_equal(g2("full_capture"), 0)
expect_equal(g2("answered_sensitivity"), 0)
expect_equal(g2("pred_burden_answered"), g2("ref_burden_answered"))
