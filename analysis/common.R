# Shared code for the real-data analyses. Implements ANALYSIS_PLAN.md.
suppressPackageStartupMessages(library(timeledger))

# ---- Detector: RR irregularity rule (Dash et al. 2009, Table 1) ------------
# Window statistics for 128-interval segments ending at every 16th beat.
rri_windows <- function(beat_t, L = 128L, step = 16L) {
  rr <- diff(beat_t)
  n <- length(rr)
  if (n < L) return(NULL)
  ends <- seq.int(L, n, by = step)
  idx <- outer(seq_len(L) - L, ends, "+")
  X <- matrix(rr[idx], nrow = L)
  mrr <- colMeans(X)
  d <- X[-1, , drop = FALSE] - X[-L, , drop = FALSE]
  rmssd <- sqrt(colMeans(d^2))
  mid <- X[2:(L - 1), , drop = FALSE]
  tp <- colSums((mid > X[1:(L - 2), , drop = FALSE] & mid > X[3:L, , drop = FALSE]) |
                  (mid < X[1:(L - 2), , drop = FALSE] & mid < X[3:L, , drop = FALSE]))
  tpr <- tp / L
  S <- apply(X, 2, sort)
  core <- S[9:(L - 8), , drop = FALSE]
  se <- apply(core, 2, function(x) {
    r <- range(x)
    if (r[2] - r[1] <= 0) return(0)
    b <- cut(x, breaks = seq(r[1], r[2], length.out = 17), include.lowest = TRUE)
    p <- tabulate(b, 16) / length(x)
    p <- p[p > 0]
    sum(p * log(p)) / log(1 / 16)
  })
  implaus <- colMeans(X < 0.3 | X > 2.0)
  data.frame(decided_at = beat_t[ends + 1L], nrmssd = rmssd / mrr, tpr = tpr,
             se = se, implausible = implaus)
}

rri_predictions <- function(record, beat_t, target_end, policy = c("A", "B"),
                            detector = NULL) {
  policy <- match.arg(policy)
  if (is.null(detector)) detector <- c(A = "A_answer", B = "B_quality")[[policy]]
  w <- rri_windows(beat_t)
  if (is.null(w)) {
    return(data.frame(record = record, detector = detector, start = 0,
                      end = target_end, response = "abstain",
                      reason = "warm-up (fewer than 128 RR intervals)",
                      issued_at = NA_real_))
  }
  af <- w$nrmssd > 0.1 & w$tpr > 0.54 & w$tpr < 0.77 & w$se > 0.7
  resp <- ifelse(af, "positive", "negative")
  why <- rep(NA_character_, nrow(w))
  if (policy == "B") {
    bad <- w$implausible > 0.05
    resp[bad] <- "abstain"
    why[bad] <- "implausible RR intervals"
  }
  # Each decision holds until the next one. A held decision expires 10 s
  # after the last beat when beats stop (change log entry 1).
  p <- tl_from_windows(record, detector, decided_at = w$decided_at,
                       response = resp, reason = why, mode = "hold",
                       until = max(beat_t) + 10)
  p <- p[p$start < target_end, ]
  p$end <- pmin(p$end, target_end)
  g <- which(diff(beat_t) > 10)
  if (length(g)) {
    holes <- data.frame(record = record, start = beat_t[g] + 10,
                        end = beat_t[g + 1])
    holes <- holes[holes$start >= min(p$start) & holes$end <= max(p$end), ]
    if (nrow(holes)) {
      p <- timeledger:::.subtract_intervals(p, holes)
      p <- rbind(p, data.frame(record = record, detector = detector,
                               start = holes$start, end = holes$end,
                               response = "abstain", reason = "no recent beats",
                               issued_at = NA_real_))
      p <- p[order(p$start), ]
    }
  }
  head_row <- data.frame(record = record, detector = detector, start = 0,
                         end = min(p$start), response = "abstain",
                         reason = "warm-up (fewer than 128 RR intervals)",
                         issued_at = NA_real_)
  tail_row <- data.frame(record = record, detector = detector,
                         start = max(p$end), end = target_end,
                         response = "abstain", reason = "no recent beats",
                         issued_at = NA_real_)
  out <- rbind(head_row[head_row$end > head_row$start, ], p,
               tail_row[tail_row$end > tail_row$start, ])
  rownames(out) <- NULL
  out
}

# ---- Database loading ---------------------------------------------------------
load_record <- function(dir, rec) {
  hea <- read_wfdb_header(file.path(dir, paste0(rec, ".hea")))
  atr <- read_wfdb_ann(file.path(dir, paste0(rec, ".atr")))
  qrs <- read_wfdb_ann(file.path(dir, paste0(rec, ".qrs")))
  fs <- hea$fs
  if (is.na(hea$n_samples) || hea$n_samples == 0) {
    n_samples <- max(c(atr$sample, qrs$sample)) + 1
    length_source <- "declared from annotations"
  } else {
    n_samples <- hea$n_samples
    length_source <- "header"
  }
  beats <- wfdb_beats(qrs, fs)
  list(record = rec, hea = hea, atr = atr, qrs = qrs, fs = fs,
       n_samples = n_samples, length_source = length_source,
       target_end = n_samples / fs, beats = beats)
}

record_inputs <- function(r, before_first = "(unlabelled)") {
  ref <- wfdb_rhythm_intervals(r$atr, r$record, r$fs, r$n_samples,
                               before_first = before_first)
  bt <- r$beats$time
  obs <- data.frame(record = r$record,
                    start = c(0, min(bt), max(bt)),
                    end = c(min(bt), max(bt), r$target_end),
                    status = c("unavailable", "available", "unavailable"),
                    reason = c("beat annotation stream not started", NA,
                               "beat annotation stream ended"))
  obs <- obs[obs$end > obs$start, ]
  pa <- rri_predictions(r$record, bt, r$target_end, "A")
  pb <- rri_predictions(r$record, bt, r$target_end, "B")
  list(reference = ref, observation = obs, predictions = rbind(pa, pb))
}

inclusion_row <- function(r, ref) {
  rh <- r$atr[r$atr$symbol == "+", ]
  unl <- sum((ref$end - ref$start)[ref$label == "(unlabelled)"])
  af <- sum((ref$end - ref$start)[ref$label == "(AFIB"])
  data.frame(record = r$record, has_signals = r$hea$has_signals, fs = r$fs,
             header_n_samples = r$hea$n_samples, length_source = r$length_source,
             duration_h = r$target_end / 3600, n_rhythm_annotations = nrow(rh),
             unlabelled_h = unl / 3600, af_h = af / 3600,
             n_beats = nrow(r$beats),
             first_beat_s = min(r$beats$time), last_beat_s = max(r$beats$time),
             reference_analysis = "included",
             detector_analysis = if (nrow(r$beats) > 128) "included" else "excluded: <128 beats",
             epicmp_default = if (r$length_source == "header") "compared" else
               "epicmp selects no episodes (record length undefined)",
             waveform_tasks = if (r$hea$has_signals) "possible" else "not possible: no signal files",
             stringsAsFactors = FALSE)
}

load_database <- function(dir, before_first = "(unlabelled)") {
  recs <- readLines(file.path(dir, "RECORDS"))
  recs <- recs[nzchar(recs)]
  rr <- lapply(recs, function(x) load_record(dir, x))
  inp <- lapply(rr, record_inputs, before_first = before_first)
  records <- tl_records(recs, 0, vapply(rr, `[[`, 0, "target_end"),
                        fs = vapply(rr, `[[`, 0, "fs"),
                        n_samples = vapply(rr, `[[`, 0, "n_samples"))
  list(raw = rr, records = records,
       reference = do.call(rbind, lapply(inp, `[[`, "reference")),
       observation = do.call(rbind, lapply(inp, `[[`, "observation")),
       predictions = do.call(rbind, lapply(inp, `[[`, "predictions")),
       inclusion = do.call(rbind, Map(inclusion_row, rr, lapply(inp, `[[`, "reference"))))
}

# ---- epicmp cross-check -------------------------------------------------------
run_epicmp_check <- function(db, dir, exe, workdir) {
  dir.create(workdir, showWarnings = FALSE, recursive = TRUE)
  rows <- list()
  for (r in db$raw) {
    for (d in unique(db$predictions$detector)) {
      p <- db$predictions[db$predictions$record == r$record &
                            db$predictions$detector == d, ]
      file.copy(file.path(dir, paste0(r$record, c(".hea", ".atr"))), workdir,
                overwrite = TRUE)
      tst <- file.path(workdir, paste0(r$record, ".tst"))
      write_wfdb_rhythm(tst, p, r$fs)
      old <- setwd(workdir)
      out <- tryCatch(system2(exe, c("-r", r$record, "-a", "atr", "tst", "-A", "-"),
                              stdout = TRUE, stderr = TRUE,
                              env = "WFDB=."), error = function(e) conditionMessage(e))
      setwd(old)
      ex <- tryCatch(wfdb_parse_epicmp(out), error = function(e) NULL)
      ours <- wfdb_epicmp_af(r$atr, read_wfdb_ann(tst), n_samples = r$hea$n_samples,
                             fs = r$fs)
      to_s <- function(x) x / r$fs
      rows[[length(rows) + 1]] <- data.frame(
        record = r$record, detector = d,
        exe_STP = ex$STP, exe_FN = ex$FN, exe_PTP = ex$PTP, exe_FP = ex$FP,
        r_STP = ours$STP, r_FN = ours$FN, r_PTP = ours$PTP, r_FP = ours$FP,
        exe_ref_overlap_s = ex$ref_overlap, r_ref_overlap_s = to_s(ours$ref_overlap),
        exe_ref_duration_s = ex$ref_duration, r_ref_duration_s = to_s(ours$ref_duration),
        exe_test_overlap_s = ex$test_overlap, r_test_overlap_s = to_s(ours$test_overlap),
        exe_test_duration_s = ex$test_duration, r_test_duration_s = to_s(ours$test_duration),
        stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, rows)
  tol <- 0.0015  # epicmp prints durations with millisecond resolution
  res$counts_agree <- with(res, exe_STP == r_STP & exe_FN == r_FN &
                             exe_PTP == r_PTP & exe_FP == r_FP)
  res$durations_agree <- with(res, abs(exe_ref_overlap_s - r_ref_overlap_s) < tol &
                                abs(exe_ref_duration_s - r_ref_duration_s) < tol &
                                abs(exe_test_overlap_s - r_test_overlap_s) < tol &
                                abs(exe_test_duration_s - r_test_duration_s) < tol)
  res
}

session_record <- function() {
  list(time = format(Sys.time(), tz = "UTC", usetz = TRUE), R = R.version.string,
       platform = R.version$platform, os = utils::sessionInfo()$running,
       timeledger = as.character(utils::packageVersion("timeledger")))
}
