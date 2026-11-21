# Figures for the article, drawn with base graphics from saved results.
# Each function draws on the current device; `make_all()` writes PDF and PNG.
suppressPackageStartupMessages(library(timeledger))

lanes_plot <- function(led, record, from, to, scale, xlab, lanes, main = "") {
  plot(led, record = record, from = from, to = to, time_scale = scale,
       xlab = xlab, include = lanes, legend = TRUE, main = main, cex.axis = 0.8)
}

fig_fixture <- function() {
  fx <- tl_fixture("acceptance")
  led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
  known <- led$reference != "unknown"
  ans <- led$response %in% c("positive", "negative")
  op <- par(mar = c(4, 9, 2.5, 1))
  on.exit(par(op))
  lanes_plot(led, "rec1", 0, 100, 1, "minutes",
             list(`answered time` = known & ans, `full period` = known))
}

fig_record <- function(db = "ltafdb") {
  ex <- readRDS(file.path("results", db, "exhibit.rds"))
  rec <- ex$exhibit$record_largest_AB_gap
  led <- ex$ledger[ex$ledger$record == rec, ]
  attr(led, "detectors") <- c("A_answer", "B_quality")
  # Pre-specified window: the 4-hour window with the most Policy B abstention
  # (searched on a 30-minute grid).
  b <- led[led$detector == "B_quality" & led$response == "abstain", ]
  grid <- seq(0, max(led$end) - 4 * 3600, by = 1800)
  ab <- vapply(grid, function(g) sum(pmax(0, pmin(b$end, g + 4 * 3600) -
                                             pmax(b$start, g))), 0)
  from <- grid[which.max(ab)]
  A <- led[led$detector == "A_answer", ]
  B <- led[led$detector == "B_quality", ]
  known <- A$reference != "unknown"
  ansA <- A$response %in% c("positive", "negative")
  ansB <- B$response %in% c("positive", "negative")
  inc <- list(`A own` = rep(known & ansA, 2), `B own` = rep(known & ansB, 2),
              shared = rep(known & ansA & ansB, 2))
  op <- par(mar = c(4, 7, 2.5, 1))
  on.exit(par(op))
  plot(led, record = rec, from = from, to = from + 4 * 3600, time_scale = 3600,
       detectors = c("A_answer", "B_quality"), include = inc,
       xlab = sprintf("hours since start of LTAFDB record %s", rec), cex.axis = 0.8)
  invisible(list(record = rec, from = from))
}

fig_estimates <- function() {
  rows <- list()
  for (db in c("afdb", "ltafdb")) {
    b <- read.csv(file.path("results", db, "bootstrap_pooled.csv"))
    s <- read.csv(file.path("results", db, "bootstrap_shared.csv"))
    s$metric <- paste0(s$metric, "_shared")
    x <- rbind(b, s)
    x$db <- toupper(db)
    rows[[db]] <- x[!grepl(" - ", x$detector), ]
  }
  x <- do.call(rbind, rows)
  show <- c(answered_sensitivity = "Sensitivity, own answered time",
            answered_sensitivity_shared = "Sensitivity, shared answered time",
            full_capture = "Full-period AF capture",
            answer_coverage = "Answer coverage")
  x <- x[x$metric %in% names(show), ]
  layout(matrix(1:2, 1), widths = c(2.15, 1))
  op <- par(oma = c(2.2, 0, 0, 0))
  on.exit({par(op); layout(1)})
  for (db in c("AFDB", "LTAFDB")) {
    y <- x[x$db == db, ]
    pos <- rev(seq_along(show))
    par(mar = if (db == "AFDB") c(2.5, 14, 2, 0.6) else c(2.5, 0.6, 2, 1))
    plot(NA, xlim = c(0.75, 1), ylim = c(0.5, length(show) + 0.5), yaxt = "n",
         ylab = "", xlab = "", main = db, cex.main = 0.9, cex.axis = 0.8)
    if (db == "AFDB") axis(2, at = pos, labels = show, las = 1, cex.axis = 0.8)
    for (k in seq_along(show)) {
      for (d in c("A_answer", "B_quality")) {
        z <- y[y$metric == names(show)[k] & y$detector == d, ]
        off <- if (d == "A_answer") 0.13 else -0.13
        col <- if (d == "A_answer") "#2166ac" else "#b2182b"
        segments(z$lower, pos[k] + off, z$upper, pos[k] + off, col = col)
        points(z$estimate, pos[k] + off, pch = if (d == "A_answer") 16 else 17,
               col = col)
      }
    }
  }
  mtext("estimate with 95% subject-level bootstrap interval", side = 1,
        outer = TRUE, line = 0.2, cex = 0.75, adj = 0.75)
  par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
  plot.new()
  legend("bottomleft", c("A: answer when possible", "B: quality-gated"),
         pch = c(16, 17), col = c("#2166ac", "#b2182b"), bty = "n",
         cex = 0.75, horiz = TRUE)
}

fig_benchmark <- function() {
  x <- read.csv("results/benchmarks/scaling.csv")
  x <- x[!grepl("naive", x$factor), ]
  f <- unique(x$factor)
  cols <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a")
  op <- par(mar = c(4, 4, 1, 1))
  on.exit(par(op))
  plot(NA, log = "xy", xlim = range(x$ledger_rows), ylim = range(x$seconds),
       xlab = "ledger rows", ylab = "elapsed seconds (ledger + match + metrics)")
  for (i in seq_along(f)) {
    y <- x[x$factor == f[i], ]
    lines(y$ledger_rows, y$seconds, type = "b", pch = 15 + i, col = cols[i])
  }
  legend("topleft", f, col = cols, pch = 16:19, lty = 1, bty = "n", cex = 0.7)
}

make_all <- function(dir = "paper/figures") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  specs <- list(fixture = list(fig_fixture, 7, 2.6),
                record = list(fig_record, 7.5, 3.2),
                estimates = list(fig_estimates, 8, 3.2),
                benchmark = list(fig_benchmark, 6, 4))
  for (nm in names(specs)) {
    s <- specs[[nm]]
    pdf(file.path(dir, paste0(nm, ".pdf")), width = s[[2]], height = s[[3]])
    s[[1]]()
    dev.off()
    png(file.path(dir, paste0(nm, ".png")), width = s[[2]], height = s[[3]],
        units = "in", res = 200)
    s[[1]]()
    dev.off()
  }
  invisible(TRUE)
}

if (sys.nframe() == 0) make_all()
