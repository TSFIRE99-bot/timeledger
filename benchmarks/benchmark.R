# Runtime and peak memory of timeledger as record duration, number of
# intervals, number of detectors and fragmentation grow, varied one at a time.
# Peak memory is R's "max used" (Vcells + Ncells, MB) after gc(reset = TRUE);
# elapsed time is the median of `reps` runs. The `bench` package could not be
# loaded on the development machine (compiled code blocked), so base R timers
# are used.
# Usage: Rscript benchmarks/benchmark.R
suppressPackageStartupMessages(library(timeledger))
set.seed(42)

synth <- function(hours, n_pred_rows, n_detectors = 1, n_episodes = 20,
                  record = "r") {
  T <- hours * 3600
  # Reference: n_episodes AF episodes at random positions, rest non-AF.
  cuts <- sort(runif(2 * n_episodes, 0, T))
  lab <- rep(c("N", "AF"), length.out = length(cuts) + 1)
  ref <- data.frame(record = record, start = c(0, cuts), end = c(cuts, T),
                    label = lab)
  prd <- do.call(rbind, lapply(seq_len(n_detectors), function(d) {
    b <- sort(unique(c(0, runif(n_pred_rows - 1, 0, T), T)))
    n <- length(b) - 1
    data.frame(record = record, detector = paste0("D", d), start = b[-length(b)],
               end = b[-1], response = sample(c("positive", "negative", "abstain"),
                                              n, replace = TRUE,
                                              prob = c(0.3, 0.65, 0.05)))
  }))
  list(records = tl_records(record, 0, T), reference = ref, predictions = prd)
}

measure <- function(x, reps = 3) {
  run <- function() {
    led <- tl_ledger(x$records, x$reference, x$predictions)
    m <- tl_match(led)
    tl_metrics(led, m, level = "pooled")
    nrow(led)
  }
  t <- numeric(reps)
  for (i in seq_len(reps)) {
    invisible(gc(reset = TRUE))
    t[i] <- system.time(n <- run())[["elapsed"]]
    g <- gc()
  }
  peak <- sum(g[, ncol(g)])  # max used, MB
  c(seconds = stats::median(t), peak_mb = peak, ledger_rows = n)
}

grid <- rbind(
  data.frame(factor = "duration (h), 6 decisions per minute", hours = c(1, 24, 168, 720),
             rows = c(1, 24, 168, 720) * 360, detectors = 1, episodes = 20),
  data.frame(factor = "prediction rows, 24 h fixed", hours = 24,
             rows = c(1e3, 1e4, 1e5, 4e5), detectors = 1, episodes = 20),
  data.frame(factor = "detectors, 24 h, 8640 rows each", hours = 24, rows = 8640,
             detectors = c(1, 2, 4, 8), episodes = 20),
  data.frame(factor = "reference episodes, 24 h, 8640 rows", hours = 24, rows = 8640,
             detectors = 1, episodes = c(10, 100, 1000, 4000)))
res <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  x <- synth(g$hours, g$rows, g$detectors, g$episodes)
  cbind(g, t(measure(x, reps = if (g$rows * g$detectors > 2e5) 1 else 3)))
}))

# Naive alternative: expand a 24 h record to one row per second (and estimate
# the size at the sampling rate of AFDB, 250 Hz) before tabulating.
naive <- function(x, step = 1) {
  T <- x$records$end
  tt <- seq(0, T - step, by = step) + step / 2
  ri <- findInterval(tt, x$reference$start)
  pi <- findInterval(tt, x$predictions$start)
  ev <- x$reference$label[ri] == "AF"
  pos <- x$predictions$response[pi] == "positive"
  sum(ev & pos) / sum(ev)
}
x24 <- synth(24, 8640, 1, 20)
invisible(gc(reset = TRUE))
tn <- system.time(naive(x24, 1))[["elapsed"]]
gn <- gc()
naive_row <- data.frame(factor = "naive per-second expansion, 24 h", hours = 24,
                        rows = 86400, detectors = 1, episodes = 20,
                        seconds = tn, peak_mb = sum(gn[, ncol(gn)]),
                        ledger_rows = 86400)
res <- rbind(res, naive_row)
# Cells needed at 250 Hz for 24 h and one stream (not run).
cells_250 <- 24 * 3600 * 250

info <- list(R = R.version.string, platform = R.version$platform,
             os = utils::sessionInfo()$running,
             cpu = tryCatch(system2("powershell", c("-NoProfile", "-Command",
                   "(Get-CimInstance Win32_Processor).Name"), stdout = TRUE),
                   error = function(e) NA),
             cores = parallel::detectCores(),
             ram_gb = tryCatch(round(as.numeric(system2("powershell", c("-NoProfile", "-Command",
                   "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"),
                   stdout = TRUE)) / 2^30, 1), error = function(e) NA),
             cells_per_stream_24h_250Hz = cells_250,
             timeledger = as.character(packageVersion("timeledger")))
dir.create("results/benchmarks", showWarnings = FALSE, recursive = TRUE)
write.csv(res, "results/benchmarks/scaling.csv", row.names = FALSE)
dput(info, "results/benchmarks/machine.txt")
print(res, digits = 3, row.names = FALSE)
str(info)
