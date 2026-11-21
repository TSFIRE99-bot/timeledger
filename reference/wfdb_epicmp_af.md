# WFDB epicmp-compatible AF episode comparison

Reproduces the AF episode-by-episode and duration statistics of the WFDB
program `epicmp` (version 10.7.0) for the conventions listed below, so
that results can be checked against the reference implementation. This
is a compatibility mode for a verified subset of `epicmp` behaviour, not
a claim of compliance with ANSI/AAMI EC38 or EC57. Agreement with the
executable was tested on the records described in the package's
verification report.

## Usage

``` r
wfdb_epicmp_af(ref, test, n_samples, fs, start_time = 300 * fs,
  end_time = NULL, min_length = 0, exclude_short_all = FALSE,
  exclude_afl = FALSE)
```

## Arguments

- ref,test:

  Annotation tables from
  [`read_wfdb_ann()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_ann.md)
  (all annotations, not only rhythm, because the last annotation time
  matters).

- n_samples:

  Record length in samples (0 or `NA` when undefined).

- fs:

  Sampling frequency (used for the default `start_time`).

- start_time,end_time:

  Comparison period in samples. \`end_time = NULL\` uses the record
  length.

- min_length:

  Minimum episode length in samples.

- exclude_short_all:

  Apply `min_length` to both annotators (`-I`).

- exclude_afl:

  Exclude reference AFL from the +P pass (`-x`).

## Details

Conventions reproduced (all times in samples):

- AF episodes begin at a rhythm annotation whose label starts with
  `"(AFIB"` and end at the next rhythm annotation with any other label.
  Atrial flutter (`"(AFL"`) therefore ends an AF episode.

- An episode still open at the end of the file ends at the later of the
  comparison end time and the last annotation read from that file (of
  any type).

- The comparison starts at `start_time` (default 5 minutes, the `epicmp`
  learning period); episodes of the annotator being scored are clipped
  to \\`start_time`, `end_time`\\ and the other annotator's episodes are
  not clipped.

- The default end is the record length; when the record length is zero
  or unknown, `epicmp` uses `end_time = -1`, which selects no episodes.
  This is reproduced.

- Any positive overlap makes a match; one test episode can match several
  reference episodes and vice versa. Episodes shorter than `min_length`
  are ignored for the scored annotator (`-i`); `exclude_short_all`
  applies the `-I` behaviour to the other annotator as well.

- `exclude_afl = TRUE` excludes reference atrial flutter from the
  positive-predictivity pass (`-x`, EC38:1998 behaviour).

## Value

A list with `STP`, `FN`, `PTP`, `FP` (episode counts), `ref_overlap`,
`ref_duration`, `test_overlap`, `test_duration` (in samples) and the
four percentages `ESe`, `EPP`, `DSe`, `DPP` rounded as `epicmp` prints
them.

## Examples

``` r
ref <- data.frame(sample = c(0, 100000, 200000), type = 28L,
                  aux = c("(N", "(AFIB", "(N"))
tst <- data.frame(sample = c(0, 120000, 260000), type = 28L,
                  aux = c("(N", "(AFIB", "(N"))
wfdb_epicmp_af(ref, tst, n_samples = 300000, fs = 250)
#> $STP
#> [1] 1
#> 
#> $FN
#> [1] 0
#> 
#> $PTP
#> [1] 1
#> 
#> $FP
#> [1] 0
#> 
#> $ref_overlap
#> [1] 80000
#> 
#> $ref_duration
#> [1] 1e+05
#> 
#> $test_overlap
#> [1] 80000
#> 
#> $test_duration
#> [1] 140000
#> 
#> $ESe
#> [1] 100
#> 
#> $EPP
#> [1] 100
#> 
#> $DSe
#> [1] 80
#> 
#> $DPP
#> [1] 57
#> 
```
