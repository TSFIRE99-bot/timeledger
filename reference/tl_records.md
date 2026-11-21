# Describe the recordings to be evaluated

Builds the record table that anchors every other input. Each record has
its own clock: `start` and `end` give the target period, in the same
time unit as the interval tables, and intervals are half-open,
\\\[start, end)\\.

## Usage

``` r
tl_records(record, start = 0, end, subject = record, fs = NA_real_,
  n_samples = NA_real_)
```

## Arguments

- record:

  Character record identifiers (unique).

- start,end:

  Numeric start and end of the target period of each record.

- subject:

  Identifier of the person each record comes from. Records from the same
  subject are resampled together by
  [`tl_bootstrap()`](https://tsfire99-bot.github.io/timeledger/reference/tl_bootstrap.md).
  Defaults to `record`, which asserts that every record comes from a
  different person.

- fs:

  Optional sampling frequency in Hz, used to check sample indices.

- n_samples:

  Optional number of samples in the source signal or annotation
  timeline, used to check sample indices.

## Value

A data frame with class `tl_records`.

## Examples

``` r
tl_records(c("r1", "r2"), start = 0, end = c(100, 120), fs = 250)
#>   record start end subject  fs n_samples
#> 1     r1     0 100      r1 250        NA
#> 2     r2     0 120      r2 250        NA
```
