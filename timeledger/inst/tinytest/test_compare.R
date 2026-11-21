# Paired comparisons and the subject bootstrap.
fx <- tl_fixture("two_detectors")
led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
cmp <- tl_compare(led, c("A", "B"))
tab <- cmp$table
row <- function(nm) tab[tab$metric == nm, ]

# B abstains on [35, 65): it looks better on its own answered time...
expect_true(row("answered_sensitivity")$own_B > row("answered_sensitivity")$own_A)
# ...and captures less AF over the full period.
expect_true(row("full_capture")$own_B < row("full_capture")$own_A)
# Exact values from the fixture.
expect_equal(row("full_capture")$own_A, (8 + 16 + 10) / 45)
expect_equal(row("full_capture")$own_B, (9 + 12) / 45)
expect_equal(row("answer_coverage")$own_B, 0.7)
expect_equal(row("answered_sensitivity")$own_B, 21 / 25)

# Shared time is where both answered: B's abstention removes 30 minutes,
# 20 of them AF, from both detectors' denominators.
d <- cmp$discarded
expect_equal(d$known_time_discarded, c(30, 30))
expect_equal(d$event_time_discarded, c(20, 20))
expect_equal(d$episodes_discarded, c(1L, 1L))
expect_equal(row("answered_sensitivity")$shared_A, (8 + 10) / 25)
expect_equal(row("answered_sensitivity")$shared_B, (9 + 12) / 25)
expect_true(all(tl_check(cmp$shared_ledger)$ok))

# Bootstrap: identical records give zero-width intervals; differences are
# paired and reproducible with a seed.
recs <- tl_records(paste0("s", 1:6), 0, 100, subject = paste0("p", c(1, 1, 2, 3, 4, 5)))
mk <- function(tbl) do.call(rbind, lapply(recs$record, function(r) transform(tbl, record = r)))
led6 <- tl_ledger(recs, mk(fx$reference), mk(fx$predictions), time_unit = "min")
cb <- tl_contributions(led6, tl_match(led6))
bt <- tl_bootstrap(cb, c("full_capture", "answer_coverage"), B = 300, seed = 7)
fc <- bt[bt$metric == "full_capture", ]
expect_equal(fc$estimate[fc$detector == "A"], 34 / 45)
expect_equal(fc$lower[fc$detector == "A"], fc$upper[fc$detector == "A"])
expect_equal(fc$estimate[fc$detector == "B - A"], 21 / 45 - 34 / 45)
expect_equal(unique(bt$n_subjects), 5L)
expect_identical(bt, tl_bootstrap(cb, c("full_capture", "answer_coverage"), B = 300, seed = 7))
# Record-mean summary agrees here because records are identical.
bm <- tl_bootstrap(cb, "full_capture", B = 50, seed = 1, summary = "record_mean")
expect_equal(bm$estimate[bm$detector == "A"], 34 / 45)

# Undefined replicates are counted, not hidden.
cb2 <- cb[cb$detector == "A", ]
cb2$event[cb2$subject != "p1"] <- 0
cb2$tp[cb2$subject != "p1"] <- 0
bu <- tl_bootstrap(cb2, "full_capture", B = 500, seed = 3)
expect_true(bu$n_undefined > 0)
expect_true(bu$n_undefined < 500)

# Equal-record means count undefined records separately.
met <- tl_metrics(led6, tl_match(led6))
rm <- tl_record_mean(met)
expect_equal(rm$n_defined[rm$detector == "A" & rm$metric == "full_capture"], 6L)

# Simulated outages remove prediction time and become no_input.
sim <- tl_simulate_outages(led, n = 3, duration = 5, seed = 11)
expect_true(all(grepl("^simulated", sim$observation$reason[sim$observation$status == "unavailable"])))
led_o <- tl_ledger(fx$records, fx$reference, sim$predictions,
                   observation = sim$observation, time_unit = "min")
expect_true(all(tl_check(led_o)$ok))
expect_equal(sum(led_o$duration[led_o$response == "no_input" & led_o$detector == "A"]), 15)
expect_false(any(led_o$conflict))
sim_e <- tl_simulate_outages(led, n = 2, duration = 4, mode = "event_concentrated", seed = 2)
un <- sim_e$observation[sim_e$observation$status == "unavailable", ]
starts_in_af <- vapply(un$start, function(s) any(s >= fx$reference$start[fx$reference$label == "AF"] &
                                                   s < fx$reference$end[fx$reference$label == "AF"]), TRUE)
expect_true(all(starts_in_af))

# Window helpers.
w <- tl_from_windows("r", "D", decided_at = c(10, 20, 30),
                     response = c("negative", "positive", "negative"),
                     max_hold = 15, until = 40)
expect_equal(w$start, c(10, 20, 30))
expect_equal(w$end, c(20, 30, 40))
expect_equal(w$issued_at, c(10, 20, 30))
ww <- tl_from_windows("r", "D", decided_at = c(10, 15, 20),
                      response = c("negative", "positive", "negative"),
                      window_start = c(0, 5, 10), window_end = c(10, 15, 20),
                      mode = "window")
expect_equal(ww$start, c(0, 5, 10, 15))
expect_equal(ww$response, c("negative", "positive", "negative", "negative"))
