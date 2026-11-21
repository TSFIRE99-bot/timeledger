# Input validation.
rec <- tl_records("r", 0, 100)
ref <- data.frame(record = "r", start = c(0, 50), end = c(50, 100),
                  label = c("N", "AF"))
prd <- data.frame(record = "r", detector = "D", start = 0, end = 100,
                  response = "negative")

iss <- tl_validate(rec, ref, prd)
expect_equal(nrow(iss[iss$severity == "error", ]), 0L)

# Reversed interval.
bad <- ref
bad$end[1] <- -5
expect_error(tl_ledger(rec, bad, prd), "reversed interval")
iss <- tl_validate(rec, bad, prd)
expect_true("reversed interval (end < start)" %in% iss$issue)

# Contradictory overlapping labels.
bad <- rbind(ref, data.frame(record = "r", start = 40, end = 60, label = "AF"))
expect_error(tl_ledger(rec, bad, prd), "contradictory")
# Same-state overlaps are merged with a warning.
ok <- rbind(ref, data.frame(record = "r", start = 60, end = 70, label = "AF"))
led <- tl_ledger(rec, ok, prd)
expect_true("overlapping intervals with the same state merged" %in%
              attr(led, "issues")$issue)
expect_equal(sum(led$duration[led$reference == "event"]), 50)

# Contradictory predictions from one detector.
bp <- rbind(prd, data.frame(record = "r", detector = "D", start = 10, end = 20,
                            response = "positive"))
expect_error(tl_ledger(rec, ref, bp), "contradictory")
# The same rows under two detector names are fine.
bp$detector[2] <- "E"
expect_silent(tl_ledger(rec, ref, bp))

# Unknown record, invalid response, missing column.
expect_error(tl_ledger(rec, transform(ref, record = "zz"), prd), "not present")
expect_error(tl_ledger(rec, ref, transform(prd, response = "maybe")), "must be one of")
expect_error(tl_ledger(rec, ref[, -4], prd), "missing required column")
expect_error(tl_ledger(rec, ref, prd, missing = "probably"), "`missing` must use")

# Clock-origin mismatch: every row outside the target period.
off <- transform(prd, start = start + 1e6, end = end + 1e6)
expect_error(tl_ledger(rec, ref, off), "clock origin")
# Partial overhang is clipped with a warning.
over <- transform(prd, end = 130)
led <- tl_ledger(rec, ref, over)
expect_true("interval clipped to the target period" %in% attr(led, "issues")$issue)
expect_true(all(tl_check(led)$ok))

# Records table problems.
expect_error(tl_ledger(tl_records(c("r", "r"), 0, 100), ref, prd), "duplicate record")
expect_error(tl_ledger(tl_records("r", 10, 5), ref, prd), "end <= start")

# Sample indices: whole numbers and consistent with time.
recs <- tl_records("r", 0, 100, fs = 10, n_samples = 1000)
rs <- transform(ref, start_sample = start * 10, end_sample = end * 10)
expect_silent(tl_ledger(recs, rs, prd))
rs2 <- rs
rs2$start_sample[2] <- 500.5
expect_error(tl_ledger(recs, rs2, prd), "whole number")
rs3 <- rs
rs3$start_sample[2] <- 300
expect_error(tl_ledger(recs, rs3, prd), "disagrees")

# Warnings can be made fatal.
expect_error(tl_ledger(rec, ref, over, on_warning = "error"), "warning")
