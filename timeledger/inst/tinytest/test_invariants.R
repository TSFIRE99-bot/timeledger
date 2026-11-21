# Invariants: shifting both timelines, splitting constant-state intervals and
# shuffling rows must leave all results unchanged.
fx <- tl_fixture("two_detectors")
base_led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
base <- tl_metrics(base_led, tl_match(base_led), level = "pooled")

same <- function(a, b) {
  isTRUE(all.equal(a$estimate, b$estimate)) &&
    isTRUE(all.equal(a$numerator, b$numerator)) &&
    isTRUE(all.equal(a$denominator, b$denominator))
}

# Shift every timeline (records, reference, predictions) by the same offset.
for (off in c(-37.5, 1000, 1e6)) {
  sh <- fx
  sh$records$start <- sh$records$start + off
  sh$records$end <- sh$records$end + off
  for (nm in c("reference", "predictions")) {
    sh[[nm]]$start <- sh[[nm]]$start + off
    sh[[nm]]$end <- sh[[nm]]$end + off
  }
  led <- tl_ledger(sh$records, sh$reference, sh$predictions, time_unit = "min")
  expect_true(same(base, tl_metrics(led, tl_match(led), level = "pooled")))
}

# Split constant-state intervals at arbitrary points (inputs and ledger).
sp <- fx
cut_rows <- function(d, at) {
  out <- list()
  for (i in seq_len(nrow(d))) {
    cuts <- at[at > d$start[i] & at < d$end[i]]
    b <- c(d$start[i], cuts, d$end[i])
    r <- d[rep(i, length(b) - 1), ]
    r$start <- b[-length(b)]
    r$end <- b[-1]
    out[[i]] <- r
  }
  do.call(rbind, out)
}
sp$reference <- cut_rows(sp$reference, c(3.3, 15, 50.5, 77))
sp$predictions <- cut_rows(sp$predictions, c(5, 16, 44.25, 92))
led <- tl_ledger(sp$records, sp$reference, sp$predictions, time_unit = "min")
expect_true(same(base, tl_metrics(led, tl_match(led), level = "pooled")))
led2 <- tl_split(base_led, c(1, 2, 33.3, 64.9))
expect_true(same(base, tl_metrics(led2, tl_match(led2), level = "pooled")))
expect_true(all(tl_check(led2)$ok))

# Shuffle input rows.
set.seed(1)
for (k in 1:5) {
  sf <- fx
  sf$reference <- sf$reference[sample(nrow(sf$reference)), ]
  sf$predictions <- sf$predictions[sample(nrow(sf$predictions)), ]
  led <- tl_ledger(sf$records, sf$reference, sf$predictions, time_unit = "min")
  expect_true(same(base, tl_metrics(led, tl_match(led), level = "pooled")))
}

# Records are independent: adding a record does not change another's rows.
two <- fx
r2 <- fx$reference
r2$record <- "rec2"
p2 <- fx$predictions
p2$record <- "rec2"
two$records <- tl_records(c("rec1", "rec2"), 0, 100)
two$reference <- rbind(fx$reference, r2)
two$predictions <- rbind(fx$predictions, p2)
led <- tl_ledger(two$records, two$reference, two$predictions, time_unit = "min")
m <- tl_metrics(led, tl_match(led), level = "record")
a <- m[m$record == "rec1", ]
b <- m[m$record == "rec2", ]
expect_equal(a$estimate, b$estimate)
# Pooled over two identical records: ratios are unchanged, while counts and
# minute totals double.
p <- tl_metrics(led, tl_match(led), level = "pooled")
ratio <- !(p$unit %in% c("count", "minutes"))
expect_equal(p$estimate[ratio], base$estimate[ratio])
expect_equal(p$estimate[!ratio], 2 * base$estimate[!ratio])
