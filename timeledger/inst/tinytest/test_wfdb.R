# WFDB adapter and epicmp-compatible comparison.
hea <- read_wfdb_header(system.file("extdata", "04015.hea", package = "timeledger"))
expect_equal(hea$fs, 250)
expect_equal(hea$n_samples, 9205760)
expect_true(hea$has_signals)

atr <- read_wfdb_ann(system.file("extdata", "04015.atr", package = "timeledger"),
                     fs = 250)
rh <- atr[atr$symbol == "+", ]
expect_equal(nrow(rh), 15L)
expect_equal(rh$sample[1], 30)
expect_true(all(rh$aux %in% c("(N", "(AFIB")))

qrs <- read_wfdb_ann(system.file("extdata", "04015.qrs", package = "timeledger"))
b <- wfdb_beats(qrs, 250)
expect_equal(nrow(b), 44005L)
expect_equal(max(b$sample), 8999941)

# Round trip through the writer, with long gaps (SKIP) and aux strings.
tmp <- tempfile(fileext = ".tst")
write_wfdb_ann(tmp, atr)
back <- read_wfdb_ann(tmp)
expect_identical(back$sample, atr$sample)
expect_identical(back$aux, atr$aux)
tmp2 <- tempfile(fileext = ".tst")
write_wfdb_ann(tmp2, qrs)
expect_identical(read_wfdb_ann(tmp2)$sample, qrs$sample)
odd <- data.frame(sample = c(5, 70000, 2e6), type = 28L, aux = c("(N", "(AFIB", "(AB"))
write_wfdb_ann(tmp, odd)
expect_identical(read_wfdb_ann(tmp)$aux, odd$aux)
expect_identical(read_wfdb_ann(tmp)$sample, odd$sample)

# Rhythm intervals: time before the first label is explicitly unlabelled.
ri <- wfdb_rhythm_intervals(atr, "04015", 250, hea$n_samples)
expect_equal(ri$label[1], "(unlabelled)")
expect_equal(ri$end_sample[1], 30)
expect_equal(sum(ri$end_sample - ri$start_sample), hea$n_samples)
expect_error(wfdb_rhythm_intervals(atr, "x", 250, 0), "end_sample")

# epicmp conventions on hand-made annotation streams (fs = 1 for clarity).
r <- function(s, a) data.frame(sample = s, type = 28L, aux = a)
ref <- r(c(0, 400, 600, 1000, 1200), c("(N", "(AFIB", "(N", "(AFIB", "(N"))
# Touching only: test AF [600, 1000) touches both reference episodes.
tst <- r(c(0, 600, 1000), c("(N", "(AFIB", "(N"))
x <- wfdb_epicmp_af(ref, tst, n_samples = 2000, fs = 1)
expect_equal(c(x$STP, x$FN, x$PTP, x$FP), c(0L, 2L, 0L, 1L))
# Learning period: episodes ending before 300 samples are ignored.
ref2 <- r(c(0, 100, 200, 400, 600), c("(N", "(AFIB", "(N", "(AFIB", "(N"))
x <- wfdb_epicmp_af(ref2, ref2, n_samples = 2000, fs = 1)
expect_equal(c(x$STP, x$FN), c(1L, 0L))
expect_equal(x$ref_duration, 200)
# One long test episode matches two reference episodes (not one-to-one).
tst <- r(c(0, 450, 1100), c("(N", "(AFIB", "(N"))
x <- wfdb_epicmp_af(ref, tst, n_samples = 2000, fs = 1)
expect_equal(c(x$STP, x$FN, x$PTP, x$FP), c(2L, 0L, 1L, 0L))
expect_equal(x$ref_overlap, 150 + 100)
# AFL ends an AF episode.
ref3 <- r(c(0, 400, 500, 600), c("(N", "(AFIB", "(AFL", "(N"))
x <- wfdb_epicmp_af(ref3, r(c(0, 400), c("(N", "(AFIB")), n_samples = 2000, fs = 1)
expect_equal(x$ref_duration, 100)
# An unterminated episode ends at the record end.
expect_equal(x$test_duration, 1600)
# Zero record length selects nothing (epicmp's end_time = -1 behaviour).
x <- wfdb_epicmp_af(ref, ref, n_samples = 0, fs = 1)
expect_equal(c(x$STP, x$FN, x$PTP, x$FP), c(0L, 0L, 0L, 0L))
expect_true(is.na(x$ESe))
# -x excludes reference AFL from +P.
ref4 <- r(c(0, 400, 500, 900), c("(N", "(AFIB", "(AFL", "(N"))
tst4 <- r(c(0, 550, 700), c("(N", "(AFIB", "(N"))
expect_equal(wfdb_epicmp_af(ref4, tst4, 2000, 1)$FP, 1L)
expect_equal(wfdb_epicmp_af(ref4, tst4, 2000, 1, exclude_afl = TRUE)$FP, 0L)

# Writing responses as rhythm: abstention cannot be represented and is
# written with the non-AF label.
p <- data.frame(start = c(0, 10, 20, 30), end = c(10, 20, 30, 40),
                response = c("negative", "positive", "abstain", "positive"))
write_wfdb_rhythm(tmp, p, fs = 100)
w <- read_wfdb_ann(tmp)
expect_equal(w$aux, c("(N", "(AFIB", "(N", "(AFIB", "(N"))
expect_equal(w$sample, c(0, 1000, 2000, 3000, 4000))

# Parse the matrix output of the executable.
out <- c("AF episode-by-episode comparison results for record 04015",
         "Reference annotator: atr", "     Test annotator: tst", "",
         "           Episode sensitivity:  50% (1/2)",
         " Episode positive predictivity: 100% (1/1)",
         "          Duration sensitivity:  42% (1:23.456/3:20.000)",
         "Duration positive predictivity:  90% (1:23.456/1:32.700)")
pe <- wfdb_parse_epicmp(out)
expect_equal(c(pe$STP, pe$FN, pe$PTP, pe$FP), c(1, 1, 1, 0))
expect_equal(pe$ref_overlap, 83.456)
expect_equal(pe$ref_duration, 200)
