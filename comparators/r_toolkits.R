# Execute harbinger, yardstick and ivs on the same inputs as timeledger.
# Runs in CI (the development machine could not load compiled packages).
# Inputs: the two_detectors fixture (minutes) and AFDB record 04015 shipped
# with timeledger (seconds), using the detector from the comparing-monitors
# vignette. Per-observation tools get one observation per minute (fixture) or
# per second (04015); abstained time is NA in the detection vector, which is
# how a user would represent "no answer".
# Usage: Rscript comparators/r_toolkits.R results/comparators/r_toolkits.csv
suppressPackageStartupMessages({
  library(timeledger)
  library(harbinger)
  library(yardstick)
  library(ivs)
})
out_file <- commandArgs(TRUE)[1]

grid_vectors <- function(led, det, step) {
  L <- as.data.frame(led)
  L <- L[L$detector == det, ]
  t <- seq(min(L$start), max(L$end) - step, by = step) + step / 2
  i <- findInterval(t, L$start)
  ref <- L$reference[i]
  resp <- L$response[i]
  keep <- ref != "unknown"
  list(event = ref[keep] == "event",
       detection = ifelse(resp[keep] == "positive", TRUE,
                          ifelse(resp[keep] == "negative", FALSE, NA)))
}

run_case <- function(name, led, det, step) {
  g <- grid_vectors(led, det, step)
  h <- daltoolbox::evaluate(harbinger::har_eval(), g$detection, g$event)
  lv <- c("event", "none")
  truth <- factor(ifelse(g$event, "event", "none"), levels = lv)
  est <- factor(ifelse(is.na(g$detection), NA,
                       ifelse(g$detection, "event", "none")), levels = lv)
  ys <- yardstick::sens_vec(truth, est)
  ys_keep <- yardstick::sens_vec(truth, est, na_rm = FALSE)
  # ivs: event time flagged positive, by interval intersection.
  L <- as.data.frame(led)
  L <- L[L$detector == det, ]
  ev <- ivs::iv_groups(ivs::iv(L$start[L$reference == "event"],
                               L$end[L$reference == "event"]))
  po <- ivs::iv_groups(ivs::iv(L$start[L$response == "positive"],
                               L$end[L$response == "positive"]))
  ov <- ivs::iv_set_intersect(ev, po)
  tp_ivs <- sum(ivs::iv_end(ov) - ivs::iv_start(ov))
  m <- tl_metrics(led, level = "pooled")
  get <- function(nm) m$estimate[m$detector == det & m$metric == nm]
  num <- function(nm) m$numerator[m$detector == det & m$metric == nm]
  data.frame(case = name, detector = det, observation_step = step,
             harbinger_sensitivity = h$sensitivity,
             yardstick_sensitivity_default = ys,
             yardstick_sensitivity_na_rm_false = ys_keep,
             timeledger_full_capture = get("full_capture"),
             timeledger_answered_sensitivity = get("answered_sensitivity"),
             ivs_true_positive_time = tp_ivs,
             timeledger_true_positive_time = num("full_capture"))
}

fx <- tl_fixture("two_detectors")
led_fx <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
ac <- tl_fixture("acceptance")
led_ac <- tl_ledger(ac$records, ac$reference, ac$predictions, time_unit = "min")

# AFDB 04015 with the vignette's detector.
ext <- function(f) system.file("extdata", f, package = "timeledger")
hea <- read_wfdb_header(ext("04015.hea"))
atr <- read_wfdb_ann(ext("04015.atr"))
beats <- wfdb_beats(read_wfdb_ann(ext("04015.qrs")), hea$fs)
ref <- wfdb_rhythm_intervals(atr, "04015", hea$fs, hea$n_samples)
bt <- beats$time
rr <- diff(bt)
ends <- seq(64, length(rr), by = 8)
stat <- t(vapply(ends, function(e) {
  x <- rr[(e - 63):e]
  c(sqrt(mean(diff(x)^2)) / mean(x), mean(x < 0.3 | x > 2))
}, numeric(2)))
ra <- ifelse(stat[, 1] > 0.1, "positive", "negative")
rb <- ifelse(stat[, 2] > 0.05, "abstain", ra)
T_end <- hea$n_samples / hea$fs
pred <- rbind(tl_from_windows("04015", "A", bt[ends + 1], ra, until = max(bt)),
              tl_from_windows("04015", "B", bt[ends + 1], rb, until = max(bt)))
led_rec <- tl_ledger(tl_records("04015", 0, T_end), ref, pred,
                     event = "(AFIB", unknown = "(unlabelled)", missing = "abstain")

res <- rbind(run_case("acceptance fixture", led_ac, "D", 1),
             run_case("two_detectors fixture", led_fx, "A", 1),
             run_case("two_detectors fixture", led_fx, "B", 1),
             run_case("AFDB 04015", led_rec, "A", 1),
             run_case("AFDB 04015", led_rec, "B", 1))
res$harbinger_version <- as.character(packageVersion("harbinger"))
res$yardstick_version <- as.character(packageVersion("yardstick"))
res$ivs_version <- as.character(packageVersion("ivs"))
dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
write.csv(res, out_file, row.names = FALSE)
print(res, digits = 4)
