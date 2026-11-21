# WFDB adapter: AF-specific and file-format code lives here, outside the
# general interval engine.

.wfdb_codes <- c("N", "L", "R", "a", "V", "F", "J", "A", "S", "E", "j", "/",
                 "Q", "~", "", "|", "", "s", "T", "*", "D", "\"", "=", "p",
                 "B", "^", "t", "+", "u", "?", "!", "[", "]", "e", "n", "@",
                 "x", "f", "(", ")", "r")
.wfdb_beat_codes <- c(1:13, 25, 30, 34, 35, 38, 41)

#' Read a WFDB header file
#'
#' Parses the record line of a WFDB `.hea` file. Headers of annotation-only
#' records (no signals) are supported; their `n_samples` may be zero, which
#' means the record length is not defined.
#'
#' @param path Path to the `.hea` file.
#' @return A list with `record`, `n_signals`, `fs`, `n_samples`,
#'   `base_time`, `base_date` and `has_signals`.
#' @examples
#' hea <- system.file("extdata", "04015.hea", package = "timeledger")
#' read_wfdb_header(hea)
#' @export
read_wfdb_header <- function(path) {
  x <- readLines(path, warn = FALSE)
  x <- trimws(x[!grepl("^\\s*#", x) & nzchar(trimws(x))])
  tok <- strsplit(x[1], "\\s+")[[1]]
  fs <- if (length(tok) >= 3) as.numeric(sub("[/(].*$", "", tok[3])) else 250
  ns <- if (length(tok) >= 4) as.numeric(tok[4]) else NA_real_
  list(record = sub("/.*$", "", tok[1]), n_signals = as.integer(tok[2]),
       fs = fs, n_samples = ns,
       base_time = if (length(tok) >= 5) tok[5] else NA_character_,
       base_date = if (length(tok) >= 6) tok[6] else NA_character_,
       has_signals = as.integer(tok[2]) > 0)
}

#' Read and write WFDB annotation files
#'
#' `read_wfdb_ann()` decodes the MIT binary annotation format in base R,
#' including `SKIP`, `NUM`, `SUB`, `CHN` and `AUX` pseudo-annotations.
#' `write_wfdb_ann()` writes the same format; it is used to hand test
#' annotations to WFDB `epicmp`.
#'
#' @param path File path.
#' @param fs Optional sampling frequency; adds a `time` column in seconds.
#' @return `read_wfdb_ann()`: a data frame with `sample`, `type` (numeric
#'   code), `symbol`, `subtype`, `chan`, `num`, `aux` and optionally
#'   `time`. `write_wfdb_ann()`: `path`, invisibly.
#' @examples
#' atr <- system.file("extdata", "04015.atr", package = "timeledger")
#' a <- read_wfdb_ann(atr, fs = 250)
#' a[a$symbol == "+", c("sample", "time", "aux")]
#' tmp <- tempfile(fileext = ".tst")
#' write_wfdb_ann(tmp, a)
#' identical(read_wfdb_ann(tmp)$sample, a$sample)
#' @export
read_wfdb_ann <- function(path, fs = NULL) {
  sz <- file.info(path)$size
  raw <- readBin(path, "raw", n = sz)
  w <- readBin(raw, "integer", n = sz %/% 2, size = 2, signed = FALSE,
               endian = "little")
  n <- length(w)
  A <- w %/% 1024L
  I <- w %% 1024L
  smp <- numeric(n)
  typ <- integer(n)
  sub <- integer(n)
  chn <- integer(n)
  num <- integer(n)
  aux <- character(n)
  k <- 0L
  t <- 0
  cur_chan <- 0L
  cur_num <- 0L
  i <- 1L
  while (i <= n) {
    a <- A[i]
    v <- I[i]
    if (a == 0L && v == 0L) break
    if (a == 59L) {
      if (i + 2L > n) break
      val <- w[i + 1L] * 65536 + w[i + 2L]
      if (val >= 2^31) val <- val - 2^32
      t <- t + val
      i <- i + 3L
      next
    }
    if (a == 60L) {
      cur_num <- if (v >= 512L) v - 1024L else v
      if (k > 0L) num[k] <- cur_num
      i <- i + 1L
      next
    }
    if (a == 61L) {
      if (k > 0L) sub[k] <- v
      i <- i + 1L
      next
    }
    if (a == 62L) {
      cur_chan <- v
      if (k > 0L) chn[k] <- v
      i <- i + 1L
      next
    }
    if (a == 63L) {
      nb <- v
      words <- (nb + 1L) %/% 2L
      if (k > 0L && nb > 0L) {
        b <- raw[(2L * i + 1L):(2L * i + nb)]
        b <- b[b != as.raw(0)]
        aux[k] <- rawToChar(b)
      }
      i <- i + 1L + words
      next
    }
    t <- t + v
    k <- k + 1L
    smp[k] <- t
    typ[k] <- a
    chn[k] <- cur_chan
    num[k] <- cur_num
    i <- i + 1L
  }
  idx <- seq_len(k)
  sym <- ifelse(typ[idx] >= 1L & typ[idx] <= length(.wfdb_codes),
                .wfdb_codes[pmax(typ[idx], 1L)], "?")
  out <- data.frame(sample = smp[idx], type = typ[idx], symbol = sym,
                    subtype = sub[idx], chan = chn[idx], num = num[idx],
                    aux = aux[idx], stringsAsFactors = FALSE)
  if (!is.null(fs)) out$time <- out$sample / fs
  out
}

#' @rdname read_wfdb_ann
#' @param ann A data frame with `sample` and `type` (or `symbol`), and
#'   optionally `aux`, `subtype`, `chan`, `num`.
#' @export
write_wfdb_ann <- function(path, ann) {
  if (is.null(ann$type)) ann$type <- match(ann$symbol, .wfdb_codes)
  if (is.null(ann$aux)) ann$aux <- ""
  if (is.null(ann$subtype)) ann$subtype <- 0L
  if (is.null(ann$chan)) ann$chan <- 0L
  if (is.null(ann$num)) ann$num <- 0L
  ann$aux[is.na(ann$aux)] <- ""
  ann <- ann[order(ann$sample), ]
  words <- vector("list", nrow(ann))
  prev <- 0
  pnum <- 0L
  pchan <- 0L
  for (i in seq_len(nrow(ann))) {
    dt <- ann$sample[i] - prev
    if (dt > 1023 || dt < 0) {
      u <- if (dt < 0) dt + 2^32 else dt
      wi <- c(59L * 1024L, as.integer(u %/% 65536), as.integer(u %% 65536),
              as.integer(ann$type[i]) * 1024L)
    } else {
      wi <- as.integer(ann$type[i]) * 1024L + as.integer(dt)
    }
    prev <- ann$sample[i]
    if (ann$subtype[i] != 0L) wi <- c(wi, 61L * 1024L + as.integer(ann$subtype[i]))
    if (ann$chan[i] != pchan) {
      wi <- c(wi, 62L * 1024L + as.integer(ann$chan[i]))
      pchan <- ann$chan[i]
    }
    if (ann$num[i] != pnum) {
      v <- as.integer(ann$num[i])
      wi <- c(wi, 60L * 1024L + if (v < 0) v + 1024L else v)
      pnum <- ann$num[i]
    }
    if (nzchar(ann$aux[i])) {
      b <- charToRaw(ann$aux[i])
      nb <- length(b)
      if (nb %% 2L) b <- c(b, as.raw(0))
      bw <- readBin(b, "integer", n = length(b) %/% 2L, size = 2,
                    signed = FALSE, endian = "little")
      wi <- c(wi, 63L * 1024L + nb, bw)
    }
    words[[i]] <- wi
  }
  out <- c(unlist(words), 0L)
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(as.integer(out), con, size = 2, endian = "little")
  invisible(path)
}

#' Reference rhythm intervals from WFDB rhythm annotations
#'
#' Converts rhythm annotations (`symbol == "+"` with an `aux` label such as
#' `"(AFIB"`) into half-open reference intervals. Each label holds until the
#' next rhythm annotation, and the last one holds until `end_sample`.
#'
#' Time before the first rhythm annotation has no stated rhythm. By default
#' it is labelled `"(unlabelled)"`, which [tl_ledger()] treats as unknown
#' when passed in `unknown`; set `before_first` to a rhythm label to adopt
#' another convention explicitly.
#'
#' @param ann Annotations from [read_wfdb_ann()].
#' @param record Record identifier.
#' @param fs Sampling frequency in Hz.
#' @param end_sample End of the reference period in samples (e.g. the header
#'   `n_samples`). Required: annotation-only records may have no length.
#' @param start_sample Start of the reference period.
#' @param before_first Label for time before the first rhythm annotation.
#' @return A data frame with `record`, `start`, `end` (seconds),
#'   `start_sample`, `end_sample` and `label`.
#' @examples
#' atr <- system.file("extdata", "04015.atr", package = "timeledger")
#' hea <- read_wfdb_header(system.file("extdata", "04015.hea",
#'                                     package = "timeledger"))
#' wfdb_rhythm_intervals(read_wfdb_ann(atr), "04015", hea$fs, hea$n_samples)
#' @export
wfdb_rhythm_intervals <- function(ann, record, fs, end_sample,
                                  start_sample = 0,
                                  before_first = "(unlabelled)") {
  if (missing(end_sample) || is.na(end_sample) || end_sample <= start_sample) {
    stop("`end_sample` must be given and greater than `start_sample`.",
         call. = FALSE)
  }
  rh <- ann[ann$symbol == "+" & grepl("^\\(", ann$aux), ]
  rh <- rh[rh$sample >= start_sample & rh$sample < end_sample, ]
  rh <- rh[order(rh$sample), ]
  s <- rh$sample
  lab <- rh$aux
  if (!length(s) || s[1] > start_sample) {
    s <- c(start_sample, s)
    lab <- c(before_first, lab)
  }
  e <- c(s[-1], end_sample)
  keep <- e > s
  data.frame(record = as.character(record), start = s[keep] / fs,
             end = e[keep] / fs, start_sample = s[keep],
             end_sample = e[keep], label = lab[keep],
             stringsAsFactors = FALSE)
}

#' Beat annotations from a WFDB annotation table
#'
#' @param ann Annotations from [read_wfdb_ann()].
#' @param fs Sampling frequency in Hz.
#' @return A data frame with `sample`, `time` (seconds) and `symbol` for
#'   beat annotations only.
#' @examples
#' qrs <- system.file("extdata", "04015.qrs", package = "timeledger")
#' head(wfdb_beats(read_wfdb_ann(qrs), fs = 250))
#' @export
wfdb_beats <- function(ann, fs) {
  b <- ann[ann$type %in% .wfdb_beat_codes, c("sample", "symbol")]
  b$time <- b$sample / fs
  rownames(b) <- NULL
  b[, c("sample", "time", "symbol")]
}

#' Write detector responses as WFDB rhythm annotations
#'
#' WFDB test annotation files describe rhythm as a state that holds until
#' the next rhythm annotation. They cannot express abstention or missing
#' input: every stretch of time is some rhythm. This writer therefore needs
#' an explicit label for responses other than positive, and the choice is
#' recorded by the caller.
#'
#' @param path Output annotation file.
#' @param predictions Prediction rows of one record and detector (columns
#'   `start`, `end`, `response`), in seconds.
#' @param fs Sampling frequency in Hz.
#' @param positive_label,other_label Rhythm labels for positive and for all
#'   other responses (negative, abstain, uncovered time).
#' @param start_sample Sample at which the first rhythm label starts.
#' @return `path`, invisibly.
#' @export
write_wfdb_rhythm <- function(path, predictions, fs, positive_label = "(AFIB",
                              other_label = "(N", start_sample = 0) {
  p <- predictions[order(predictions$start), ]
  s <- round(p$start * fs)
  e <- round(p$end * fs)
  # Step function: the label in force from each breakpoint onward is that
  # of the row covering it; uncovered time gets `other_label`.
  bp <- sort(unique(c(start_sample, s, e)))
  i <- .cover(bp, s, e)
  lab <- ifelse(!is.na(i) & p$response[pmax(i, 1L)] == "positive" & !is.na(i),
                positive_label, other_label)
  chg <- c(TRUE, lab[-1] != lab[-length(lab)])
  write_wfdb_ann(path, data.frame(sample = bp[chg], type = 28L,
                                  aux = lab[chg], stringsAsFactors = FALSE))
}
