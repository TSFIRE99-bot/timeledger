# Print, summary, subsetting and plot methods.
fx <- tl_fixture("two_detectors")
led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")

out <- capture.output(print(led))
expect_true(grepl("^<tl_ledger> ", out[1]))
expect_true(any(grepl("detector\\(s\\): A, B", out)))

s <- summary(led)
expect_equal(sum(s$duration[s$detector == "A"]), 100)
expect_equal(sum(s$share[s$detector == "B"]), 1)
s2 <- summary(led, by = "response")
expect_equal(sort(unique(s2$response)), c("abstain", "negative", "positive"))

df <- as.data.frame(led)
expect_identical(class(df), "data.frame")
expect_null(attr(df, "records"))
sub <- led[led$detector == "A", ]
expect_true(inherits(sub, "tl_ledger"))
expect_false(inherits(led[, c("start", "end")], "tl_ledger"))

m <- tl_match(led)
expect_true(any(grepl("eligible episodes detected", capture.output(print(m)))))
met <- tl_metrics(led, m)
expect_true(grepl("^<tl_metrics>", capture.output(print(met))[1]))
expect_silent(capture.output(print(met[, c("metric", "estimate")])))
g <- tl_get(met, "full_capture", level = "record")
expect_equal(nrow(g), 2L)

cmp <- tl_compare(led, c("A", "B"))
pc <- capture.output(print(cmp))
expect_true(grepl("A vs B", pc[1]))
expect_true(any(grepl("Discarded", pc)))

tr <- tl_trace(led, "rec1", 30, 50, detector = "B")
expect_true(all(tr$detector == "B"))
expect_true(all(tr$end > 30 & tr$start < 50))
expect_error(tl_explain(led, m), "Give")
expect_error(tl_explain(led, m, alarm = "nope"), "Unknown alarm")
expect_error(tl_explain(led, m, episode = "nope"), "Unknown episode")

# Plots draw without error on a null device, with and without extra lanes.
grDevices::pdf(NULL)
expect_silent(plot(led))
expect_silent(plot(led, from = 10, to = 60, detectors = "B", legend = FALSE,
                   include = list(shared = cmp$shared_ledger$reference != "unknown")))
unk <- tl_ledger(fx$records, fx$reference[-1, ], fx$predictions[fx$predictions$start > 0, ],
                 time_unit = "min")
expect_silent(plot(unk, time_scale = 60, xlab = "hours"))
grDevices::dev.off()

# Unit handling.
expect_error(tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "days"),
             "time_unit")
led_h <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "h")
mh <- tl_metrics(led_h, tl_match(led_h), level = "pooled")
expect_equal(mh$estimate[mh$metric == "burden_error_min" & mh$detector == "A"],
             60 * met$estimate[met$metric == "burden_error_min" & met$detector == "A" &
                                 met$level == "pooled"])
