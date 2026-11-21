# Extract one metric as a compact table

Extract one metric as a compact table

## Usage

``` r
tl_get(metrics, metric, level = "pooled")
```

## Arguments

- metrics:

  A `tl_metrics` object.

- metric:

  Metric name(s).

- level:

  `"pooled"` or `"record"`.

## Value

The matching rows as a plain data frame.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
tl_get(tl_metrics(led), "full_capture")
#>    level   record detector       metric  estimate numerator denominator
#> 1 pooled <pooled>        D full_capture 0.3333333        10          30
#>         unit excluded_time undefined_reason
#> 1 proportion             0             <NA>
```
