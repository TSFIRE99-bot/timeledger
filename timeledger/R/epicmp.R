#' WFDB epicmp-compatible AF episode comparison
#'
#' Reproduces the AF episode-by-episode and duration statistics of the WFDB
#' program `epicmp` (version 10.7.0) for the conventions listed below, so
#' that results can be checked against the reference implementation. This
#' is a compatibility mode for a verified subset of `epicmp` behaviour, not
#' a claim of compliance with ANSI/AAMI EC38 or EC57. Agreement with the
#' executable was tested on the records described in the package's
#' verification report.
#'
#' Conventions reproduced (all times in samples):
#' * AF episodes begin at a rhythm annotation whose label starts with
#'   `"(AFIB"` and end at the next rhythm annotation with any other label.
#'   Atrial flutter (`"(AFL"`) therefore ends an AF episode.
#' * An episode still open at the end of the file ends at the later of the
#'   comparison end time and the last annotation read from that file (of
#'   any type).
#' * The comparison starts at `start_time` (default 5 minutes, the
#'   `epicmp` learning period); episodes of the annotator being scored are
#'   clipped to \[`start_time`, `end_time`\] and the other annotator's
#'   episodes are not clipped.
#' * The default end is the record length; when the record length is zero
#'   or unknown, `epicmp` uses `end_time = -1`, which selects no episodes.
#'   This is reproduced.
#' * Any positive overlap makes a match; one test episode can match several
#'   reference episodes and vice versa. Episodes shorter than `min_length`
#'   are ignored for the scored annotator (`-i`); `exclude_short_all`
#'   applies the `-I` behaviour to the other annotator as well.
#' * `exclude_afl = TRUE` excludes reference atrial flutter from the
#'   positive-predictivity pass (`-x`, EC38:1998 behaviour).
#'
#' @param ref,test Annotation tables from [read_wfdb_ann()] (all
#'   annotations, not only rhythm, because the last annotation time matters).
#' @param n_samples Record length in samples (0 or `NA` when undefined).
#' @param fs Sampling frequency (used for the default `start_time`).
#' @param start_time,end_time Comparison period in samples. `end_time =
#'   NULL` uses the record length.
#' @param min_length Minimum episode length in samples.
#' @param exclude_short_all Apply `min_length` to both annotators (`-I`).
#' @param exclude_afl Exclude reference AFL from the +P pass (`-x`).
#' @return A list with `STP`, `FN`, `PTP`, `FP` (episode counts),
#'   `ref_overlap`, `ref_duration`, `test_overlap`, `test_duration` (in
#'   samples) and the four percentages `ESe`, `EPP`, `DSe`, `DPP` rounded as
#'   `epicmp` prints them.
#' @examples
#' ref <- data.frame(sample = c(0, 100000, 200000), type = 28L,
#'                   aux = c("(N", "(AFIB", "(N"))
#' tst <- data.frame(sample = c(0, 120000, 260000), type = 28L,
#'                   aux = c("(N", "(AFIB", "(N"))
#' wfdb_epicmp_af(ref, tst, n_samples = 300000, fs = 250)
#' @export
wfdb_epicmp_af <- function(ref, test, n_samples, fs, start_time = 300 * fs,
                           end_time = NULL, min_length = 0,
                           exclude_short_all = FALSE, exclude_afl = FALSE) {
  if (is.null(end_time)) {
    end_time <- if (is.na(n_samples) || n_samples == 0) -1 else n_samples
  }
  if (end_time > 0 && end_time < start_time) stop("improper interval")
  anns <- list(.epi_stream(ref), .epi_stream(test))
  sens <- .epicmp_pass(anns, a = 1L, b = 2L, start_time, end_time, min_length,
                       exclude_short_all, NULL)
  excl <- if (exclude_afl) .epi_exclusions(anns[[1]], start_time, end_time) else NULL
  ppv <- .epicmp_pass(anns, a = 2L, b = 1L, start_time, end_time, min_length,
                      exclude_short_all, excl)
  pct <- function(a, b) if (b <= 0) NA_integer_ else as.integer(floor(100 * a / b + 0.5))
  list(STP = sens$match, FN = sens$mismatch, PTP = ppv$match,
       FP = ppv$mismatch, ref_overlap = sens$overlap,
       ref_duration = sens$duration, test_overlap = ppv$overlap,
       test_duration = ppv$duration,
       ESe = pct(sens$match, sens$match + sens$mismatch),
       EPP = pct(ppv$match, ppv$match + ppv$mismatch),
       DSe = pct(sens$overlap, sens$duration),
       DPP = pct(ppv$overlap, ppv$duration))
}

.epi_stream <- function(ann) {
  ann <- ann[order(ann$sample), ]
  if (is.null(ann$type)) ann$type <- match(ann$symbol, .wfdb_codes)
  aux <- ann$aux
  aux[is.na(aux)] <- ""
  list(time = ann$sample, rhythm = ann$type == 28L, aux = aux)
}

# Sequential episode reader mirroring find_episode(): state is the position
# in the annotation stream.
.epi_reader <- function(s, type = "AF") {
  pos <- 0L
  n <- length(s$time)
  starts_ep <- if (type == "AF") {
    s$rhythm & startsWith(s$aux, "(AFIB")
  } else {
    s$rhythm & startsWith(s$aux, "(AFL")
  }
  ends_ep <- if (type == "AF") {
    s$rhythm & !startsWith(s$aux, "(AFIB")
  } else {
    s$rhythm & !startsWith(s$aux, "(AFL")
  }
  next_episode <- function(end_time) {
    st <- 0
    en <- 0
    repeat {
      pos <<- pos + 1L
      if (pos > n) return(c(0, 0))
      if (starts_ep[pos]) break
    }
    st <- s$time[pos]
    tt <- s$time[pos]
    repeat {
      pos <<- pos + 1L
      if (pos > n) {
        en <- if (end_time > tt) end_time else tt
        return(c(st, en))
      }
      tt <- s$time[pos]
      if (ends_ep[pos]) return(c(st, s$time[pos]))
    }
  }
  list(next_episode = next_episode)
}

.epi_exclusions <- function(refstream, start_time, end_time) {
  rd <- .epi_reader(refstream, "AFL")
  ex <- matrix(numeric(), 0, 2)
  repeat {
    e <- rd$next_episode(end_time)
    if (!(0 < e[2] && e[2] < start_time)) break
  }
  if (e[2] == 0) return(ex)
  while (0 < e[2] && (end_time == 0 || e[1] < end_time)) {
    ex <- rbind(ex, e)
    e <- rd$next_episode(end_time)
  }
  ex
}

.epicmp_pass <- function(anns, a, b, start_time, end_time, min_length,
                         Iflag, excl) {
  ra <- .epi_reader(anns[[a]])
  rb <- .epi_reader(anns[[b]])
  match <- 0L
  mismatch <- 0L
  total_duration <- 0
  total_overlap <- 0
  repeat {
    ea <- ra$next_episode(end_time)
    if (!(0 < ea[2] && ea[2] < start_time)) break
  }
  if (ea[2] == 0) {
    return(list(match = 0L, mismatch = 0L, duration = 0, overlap = 0))
  }
  if (ea[1] < start_time) ea[1] <- start_time
  eb <- rb$next_episode(end_time)
  while (ea[2] != 0 && (end_time == 0 || ea[1] < end_time)) {
    if (end_time > 0 && ea[2] > end_time) ea[2] <- end_time
    duration <- ea[2] - ea[1]
    if (!is.null(excl) && nrow(excl)) {
      for (i in seq_len(nrow(excl))) {
        if (ea[2] <= excl[i, 1]) break
        if (excl[i, 1] <= ea[1] && ea[1] <= excl[i, 2]) {
          if (ea[2] <= excl[i, 2]) {
            duration <- -1
            break
          } else {
            duration <- duration - (ea[1] - excl[i, 2])
            ea[1] <- excl[i, 2]
          }
        } else if (ea[1] <= excl[i, 1] && excl[i, 1] <= ea[2]) {
          if (excl[i, 2] < ea[2]) {
            duration <- duration - (excl[i, 2] - excl[i, 1])
          } else {
            duration <- duration - (ea[2] - excl[i, 1])
            ea[2] <- excl[i, 1]
          }
        }
      }
    }
    if (duration < min_length) {
      # Mirrors the C code: an excluded or short episode is skipped (note the
      # comparison is against min_length, so duration -1 is skipped too).
      ea <- ra$next_episode(end_time)
      next
    }
    total_duration <- total_duration + duration
    # find_overlap()
    overlap <- 0
    if (eb[2] != 0) {
      gone <- FALSE
      while (eb[2] < ea[1]) {
        eb <- rb$next_episode(end_time)
        if (eb[1] == 0) {
          gone <- TRUE
          break
        }
      }
      if (!gone && !(eb[1] > ea[2])) {
        repeat {
          if (Iflag && eb[2] - eb[1] < min_length) {
            eb <- rb$next_episode(end_time)
            if (!(0 < eb[1] && eb[1] < ea[2])) break
            next
          }
          o_start <- if (eb[1] < ea[1]) ea[1] else eb[1]
          o_end <- if (eb[2] > ea[2]) ea[2] else eb[2]
          overlap <- overlap + (o_end - o_start)
          if (eb[2] >= ea[2]) break
          eb <- rb$next_episode(end_time)
          if (!(0 < eb[1] && eb[1] < ea[2])) break
        }
      }
    }
    if (overlap > 0) {
      match <- match + 1L
      total_overlap <- total_overlap + overlap
    } else {
      mismatch <- mismatch + 1L
    }
    ea <- ra$next_episode(end_time)
  }
  list(match = match, mismatch = mismatch, duration = total_duration,
       overlap = total_overlap)
}

#' Parse the matrix-format output of WFDB epicmp
#'
#' @param text Character vector with the output of `epicmp -r REC -a REF
#'   TEST` (AF section).
#' @return A list with the episode counts and the durations (in seconds,
#'   as printed with millisecond resolution).
#' @export
wfdb_parse_epicmp <- function(text) {
  grab <- function(lab) {
    l <- grep(lab, text, fixed = TRUE, value = TRUE)[1]
    m <- regmatches(l, regexpr("\\(([^/]+)/([^)]+)\\)", l))
    parts <- strsplit(gsub("[()]", "", m), "/")[[1]]
    parts
  }
  tsec <- function(x) {
    x <- trimws(x)
    p <- as.numeric(strsplit(x, ":")[[1]])
    sum(p * 60^(rev(seq_along(p)) - 1))
  }
  es <- as.numeric(grab("Episode sensitivity"))
  ep <- as.numeric(grab("Episode positive predictivity"))
  ds <- grab("Duration sensitivity")
  dp <- grab("Duration positive predictivity")
  list(STP = es[1], FN = es[2] - es[1], PTP = ep[1], FP = ep[2] - ep[1],
       ref_overlap = tsec(ds[1]), ref_duration = tsec(ds[2]),
       test_overlap = tsec(dp[1]), test_duration = tsec(dp[2]))
}
