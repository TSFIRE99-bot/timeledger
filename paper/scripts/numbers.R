# Collects every number quoted in the article from saved result files.
# Sourced by the article; run from the repository root.
rd <- function(...) read.csv(file.path("results", ...), stringsAsFactors = FALSE,
                             colClasses = c(record = "character"))
rd0 <- function(...) read.csv(file.path("results", ...), stringsAsFactors = FALSE)
f2 <- function(x, d = 2) formatC(x, digits = d, format = "f")
f3 <- function(x) f2(x, 3)
pct <- function(x, d = 1) paste0(formatC(100 * x, digits = d, format = "f"), "%")
ci <- function(r, fmt = f3) sprintf("%s (95%% CI %s to %s)", fmt(r$estimate),
                                    fmt(r$lower), fmt(r$upper))
N <- list()
load_db <- function(db) {
  inc <- rd(db, "inclusion.csv")
  bt <- rd0(db, "bootstrap_pooled.csv")
  bs <- rd0(db, "bootstrap_shared.csv")
  ct <- rd0(db, "compare_table.csv")
  dc <- rd0(db, "compare_discarded.csv")
  ep <- rd(db, "epicmp_check.csv")
  ev <- rd(db, "epicmp_vs_timeledger_conventions.csv")
  sa <- rd0(db, "sensitivity_analyses.csv")
  rm <- rd0(db, "metrics_record_mean.csv")
  ao <- rd0(db, "metrics_any_overlap.csv")
  b <- function(det, m) bt[bt$detector == det & bt$metric == m, ]
  s <- function(det, m) bs[bs$detector == det & bs$metric == m, ]
  list(
    n = nrow(inc), hours = sum(inc$duration_h), af_hours = sum(inc$af_h),
    unlabelled_hours = sum(inc$unlabelled_h),
    max_unlabelled = inc[which.max(inc$unlabelled_h), c("record", "unlabelled_h")],
    no_signal = inc$record[!inc$has_signals],
    b = b, s = s, ct = ct, dc = dc,
    epicmp_n = nrow(ep), epicmp_agree = sum(ep$counts_agree & ep$durations_agree),
    conv_n = nrow(ev),
    conv_agree = sum(with(ev, exe_STP == tl_STP & exe_FN == tl_FN & exe_PTP == tl_PTP &
                            exe_FP == tl_FP & abs(exe_ref_duration_s - tl_ref_duration_s) < 0.002 &
                            abs(exe_ref_overlap_s - tl_ref_overlap_s) < 0.002 &
                            abs(exe_test_duration_s - tl_test_duration_s) < 0.002)),
    ev = ev, sa = sa, rm = rm,
    any_ep = function(det) ao$estimate[ao$detector == det & ao$metric == "episode_sensitivity"],
    tab = function(m, col) ct[ct$metric == m, col])
}
# One environment per database, so the helper functions see their own tables.
for (db in c("afdb", "ltafdb")) N[[db]] <- load_db(db)
cv <- rd0("comparators", "conventional_vs_timeledger.csv")
N$conv <- function(db, an, det, col = "sensitivity")
  cv[cv$database == db & cv$analysis == an & cv$detector == det, col]
sim <- rd0("simulation", "outages_afdb_summary.csv")
N$sim <- function(mode, m) sim[sim$mode == mode & sim$metric == m, "estimate.mean"]
N$sim_range <- function(mode, m) unlist(sim[sim$mode == mode & sim$metric == m,
                                            c("estimate.min", "estimate.max")])
ap <- rd0("apnea", "metrics.csv")
ap <- ap[ap$level == "pooled", ]
N$apnea <- function(m) ap$estimate[ap$metric == m]
N$apnea_acc <- rd0("apnea", "minute_accuracy.csv")
N$apnea_bt <- rd0("apnea", "bootstrap_record_level.csv")
N$apnea_n <- length(unique(rd0("apnea", "metrics.csv")$record)) - 1
bm <- rd0("benchmarks", "scaling.csv")
N$bm <- bm
N$machine <- dget("results/benchmarks/machine.txt")
js <- paste(readLines("results/comparators/python_comparators.json", warn = FALSE),
            collapse = " ")
jnum <- function(block, key) {
  seg <- regmatches(js, regexpr(sprintf('"%s": \\{[^}]*\\}', block), js))
  as.numeric(sub(".*: ", "", regmatches(seg, regexpr(sprintf('"%s": [-0-9.e]+', key), seg))))
}
N$py <- list(ts_sample = jnum("timescoring", "sample_sensitivity"),
             ts_event = jnum("timescoring", "event_sensitivity"),
             ts_default = jnum("timescoring", "default_params_event_sensitivity"),
             ts_default_fp = jnum("timescoring", "default_params_fp"),
             ts_fpday = jnum("timescoring", "event_fp_per_day"),
             sed_seg = jnum("sed_eval", "segment_recall"),
             sed_event = jnum("sed_eval", "event_recall"))
tests <- rd0("tests_summary.csv")
N$tests <- tests
N$n_expect <- sum(tests$results)
