# Cluster bootstrap for pooled metrics and paired differences

Resamples subjects (not seconds, windows, beats or episodes) with
replacement and recomputes pooled metrics from the per-record
contributions. All detectors share the same resampled subjects, so
differences between detectors are paired. Replicates whose denominator
is zero are undefined; they are counted and left out of the percentile
interval.

## Usage

``` r
tl_bootstrap(contributions, metrics, B = 2000, conf = 0.95,
  summary = c("pooled", "record_mean"), seed = NULL)
```

## Arguments

- contributions:

  Output of
  [`tl_contributions()`](https://tsfire99-bot.github.io/timeledger/reference/tl_contributions.md),
  possibly row-bound across several ledgers that share subjects.

- metrics:

  Metric names from
  [`tl_metrics()`](https://tsfire99-bot.github.io/timeledger/reference/tl_metrics.md)
  whose numerator and denominator are both additive (all ratio metrics
  are).

- B:

  Number of bootstrap replicates.

- conf:

  Confidence level of the percentile interval.

- summary:

  `"pooled"` (ratio of resampled sums) or `"record_mean"` (mean of
  per-record ratios over the resampled records).

- seed:

  Optional random seed.

## Value

A data frame with one row per detector (and per difference between the
first detector and each other one) and metric: `estimate`, `lower`,
`upper`, `B`, `n_undefined`, `n_subjects`.

## Examples

``` r
fx <- tl_fixture("two_detectors")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
cb <- tl_contributions(led, tl_match(led))
tl_bootstrap(cb, c("full_capture", "answer_coverage"), B = 200, seed = 1)
#>   detector          metric   estimate      lower      upper   B n_undefined
#> 1        A    full_capture  0.7555556  0.7555556  0.7555556 200           0
#> 2        B    full_capture  0.4666667  0.4666667  0.4666667 200           0
#> 3    B - A    full_capture -0.2888889 -0.2888889 -0.2888889 200           0
#> 4        A answer_coverage  1.0000000  1.0000000  1.0000000 200           0
#> 5        B answer_coverage  0.7000000  0.7000000  0.7000000 200           0
#> 6    B - A answer_coverage -0.3000000 -0.3000000 -0.3000000 200           0
#>   n_subjects
#> 1          1
#> 2          1
#> 3          1
#> 4          1
#> 5          1
#> 6          1
```
