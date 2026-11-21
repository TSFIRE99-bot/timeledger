# Non-AF transfer case: obstructive sleep apnea minutes in the PhysioNet
# Apnea-ECG Database 1.0.0 (Penzel et al. 2000), 70 records with expert
# minute-by-minute apnea annotations (.apn) and machine-generated beat
# annotations (.qrs, sqrs125). The same timeledger engine is used with the
# event label "A"; nothing in the package is AF-specific.
#
# Demonstration detector, fixed before any label was inspected (committed
# before the first run). It is deliberately simple; its accuracy is not a
# claim of this work.
#   * Input: unaudited beat times only.
#   * RR intervals outside [0.4, 2.0] s are treated as artefacts.
#   * Minute m is scored from beats in the 5-minute window [m - 2, m + 3)
#     minutes. Heart rate (60 / RR) is smoothed with a 5-beat moving average;
#     the minute is "apnea" when the interquartile range of the smoothed heart
#     rate exceeds 6 beats per minute (cyclic variation of heart rate).
#   * The detector abstains ("insufficient valid beats") when fewer than 150
#     valid RR intervals fall in the window or more than 20% are artefacts.
#   * Decisions are retrospective: the label of minute m is issued at the end
#     of its window (m + 3 minutes).
# Subjects: the public description does not identify which records share a
# subject, so uncertainty is reported at the record level and labelled so.
source("analysis/common.R")
dir <- "rawdata/apnea-ecg"
recs <- sort(sub("\\.apn$", "", list.files(dir, "^[a-z][0-9]{2}\\.apn$")))

apnea_record <- function(r) {
  hea <- read_wfdb_header(file.path(dir, paste0(r, ".hea")))
  fs <- hea$fs
  apn <- read_wfdb_ann(file.path(dir, paste0(r, ".apn")))
  qrs <- read_wfdb_ann(file.path(dir, paste0(r, ".qrs")))
  T_end <- hea$n_samples / fs
  # Reference: each annotation labels the minute that starts at it.
  st <- apn$sample / fs
  ref <- data.frame(record = r, start = st, end = pmin(st + 60, T_end),
                    label = apn$symbol)
  ref <- ref[ref$end > ref$start, ]
  bt <- wfdb_beats(qrs, fs)$time
  rr <- diff(bt)
  tm <- bt[-1]
  ok <- rr >= 0.4 & rr <= 2.0
  hr <- 60 / rr
  sm <- stats::filter(hr, rep(1 / 5, 5), sides = 2)
  minutes <- seq(0, floor(T_end / 60) - 1)
  dec <- lapply(minutes, function(m) {
    w <- tm >= (m - 2) * 60 & tm < (m + 3) * 60
    n_ok <- sum(w & ok)
    frac_bad <- if (sum(w)) mean(!ok[w]) else 1
    if (n_ok < 150 || frac_bad > 0.2) {
      return(c(NA, 1))
    }
    x <- sm[w & ok]
    x <- x[!is.na(x)]
    c(as.numeric(stats::IQR(x) > 6), 0)
  })
  dec <- do.call(rbind, dec)
  resp <- ifelse(dec[, 2] == 1, "abstain", ifelse(dec[, 1] == 1, "positive", "negative"))
  prd <- data.frame(record = r, detector = "CVHR_demo", start = minutes * 60,
                    end = pmin((minutes + 1) * 60, T_end), response = resp,
                    reason = ifelse(resp == "abstain", "insufficient valid beats", NA),
                    issued_at = pmin((minutes + 3) * 60, T_end))
  list(ref = ref, prd = prd[prd$end > prd$start, ], end = T_end, fs = fs,
       n_samples = hea$n_samples)
}

x <- lapply(recs, apnea_record)
records <- tl_records(recs, 0, vapply(x, `[[`, 0, "end"),
                      fs = vapply(x, `[[`, 0, "fs"),
                      n_samples = vapply(x, `[[`, 0, "n_samples"))
reference <- do.call(rbind, lapply(x, `[[`, "ref"))
predictions <- do.call(rbind, lapply(x, `[[`, "prd"))
led <- tl_ledger(records, reference, predictions, event = "A",
                 unknown = character(), missing = "unknown")
stopifnot(all(tl_check(led)$ok))
m <- tl_match(led, min_episode_time = 60)
met <- tl_metrics(led, m)
out <- "results/apnea"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
write.csv(as.data.frame(met), file.path(out, "metrics.csv"), row.names = FALSE)
write.csv(summary(led), file.path(out, "ledger_state_totals.csv"), row.names = FALSE)

# The challenge-style score: per-minute accuracy over all annotated minutes,
# which forces abstained minutes to count as wrong (or to be dropped).
cb <- tl_contributions(led, m)
pc <- colSums(cb[, c("tp", "tn", "known", "answered")])
acc <- data.frame(score = c("minute accuracy, abstained minutes counted as errors",
                            "minute accuracy on answered minutes only"),
                  value = c((pc[["tp"]] + pc[["tn"]]) / pc[["known"]],
                            (pc[["tp"]] + pc[["tn"]]) / pc[["answered"]]),
                  minutes_in_denominator = c(pc[["known"]], pc[["answered"]]) / 60)
write.csv(acc, file.path(out, "minute_accuracy.csv"), row.names = FALSE)
bt <- tl_bootstrap(cb, c("full_capture", "answered_sensitivity", "answer_coverage",
                         "answered_specificity", "episode_sensitivity"),
                   B = 2000, seed = 20261120)
bt$resampling_unit <- "record (subject identity not available)"
write.csv(bt, file.path(out, "bootstrap_record_level.csv"), row.names = FALSE)
lat <- m$episodes[m$episodes$detected, c("latency", "latency_status")]
write.csv(as.data.frame(table(lat$latency_status)), file.path(out, "latency_status.csv"),
          row.names = FALSE)
print(tl_get(met, c("answer_coverage", "answered_sensitivity", "answered_specificity",
                    "full_capture", "episode_sensitivity",
                    "false_alarms_per_known_hour", "burden_bound_lower",
                    "burden_bound_upper", "ref_burden_full")), digits = 3)
print(acc)
print(bt, digits = 3)
print(table(lat$latency_status))
print(summary(lat$latency[lat$latency_status == "observed"] / 60))
