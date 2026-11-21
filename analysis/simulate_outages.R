# Controlled experiment (SIMULATED outages) on AFDB, Policy A, as planned:
# 6 outages of 20 minutes per record, seeds 1-20, random vs event-concentrated.
# The event-concentrated mode is an artificial stress test of the evaluator;
# it says nothing about whether real devices fail during AF.
source("analysis/common.R")
db <- load_database("rawdata/afdb")
pa <- db$predictions[db$predictions$detector == "A_answer", ]
base <- tl_ledger(db$records, db$reference, pa, NULL, event = "(AFIB",
                  unknown = "(unlabelled)")
keep <- c("full_capture", "answered_sensitivity", "answer_coverage",
          "false_alarms_per_known_hour", "episode_sensitivity",
          "burden_bound_lower", "burden_bound_upper", "pred_burden_answered",
          "ref_burden_full")
b0 <- tl_get(tl_metrics(base, tl_match(base, min_episode_time = 30)), keep)
rows <- list(data.frame(mode = "none", seed = NA, metric = b0$metric,
                        estimate = b0$estimate))
for (mode in c("random", "event_concentrated")) {
  for (s in 1:20) {
    sim <- tl_simulate_outages(base, n = 6, duration = 20 * 60, mode = mode, seed = s)
    led <- tl_ledger(db$records, db$reference, sim$predictions, sim$observation,
                     event = "(AFIB", unknown = "(unlabelled)")
    stopifnot(all(tl_check(led)$ok))
    g <- tl_get(tl_metrics(led, tl_match(led, min_episode_time = 30)), keep)
    rows[[length(rows) + 1]] <- data.frame(mode = mode, seed = s, metric = g$metric,
                                           estimate = g$estimate)
  }
}
res <- do.call(rbind, rows)
dir.create("results/simulation", showWarnings = FALSE)
write.csv(res, "results/simulation/outages_afdb.csv", row.names = FALSE)
summ <- aggregate(estimate ~ mode + metric, data = res,
                  FUN = function(x) c(mean = mean(x), min = min(x), max = max(x)))
summ <- do.call(data.frame, summ)
write.csv(summ, "results/simulation/outages_afdb_summary.csv", row.names = FALSE)
print(summ, digits = 3)
