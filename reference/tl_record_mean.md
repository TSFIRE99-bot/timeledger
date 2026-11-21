# Equal-record summaries of metrics

Averages per-record estimates so that each record (or, with
`by = "subject"`, each subject) counts once, whatever its duration.
Records whose metric is undefined are left out and counted.

## Usage

``` r
tl_record_mean(metrics)
```

## Arguments

- metrics:

  A `tl_metrics` object computed with `level` `"both"` or `"record"`.

## Value

A data frame with `detector`, `metric`, `mean`, `median`, `n_defined`
and `n_undefined`.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
tl_record_mean(tl_metrics(led))
#>    detector                      metric       mean     median n_defined
#> 1         D             answer_coverage  0.8000000  0.8000000         1
#> 2         D answer_coverage_given_input         NA         NA         0
#> 3         D        answered_sensitivity  1.0000000  1.0000000         1
#> 4         D        answered_specificity  0.8571429  0.8571429         1
#> 5         D          burden_bound_lower  0.2000000  0.2000000         1
#> 6         D          burden_bound_upper  0.4000000  0.4000000         1
#> 7         D              burden_diff_pp 12.5000000 12.5000000         1
#> 8         D            burden_error_min 10.0000000 10.0000000         1
#> 9         D                duration_ppv  0.5000000  0.5000000         1
#> 10        D                full_capture  0.3333333  0.3333333         1
#> 11        D          missed_abstain_min 20.0000000 20.0000000         1
#> 12        D         missed_negative_min  0.0000000  0.0000000         1
#> 13        D         missed_no_input_min  0.0000000  0.0000000         1
#> 14        D          missed_unknown_min  0.0000000  0.0000000         1
#> 15        D        pred_burden_answered  0.2500000  0.2500000         1
#> 16        D         ref_burden_answered  0.1250000  0.1250000         1
#> 17        D             ref_burden_full  0.3000000  0.3000000         1
#>    n_undefined
#> 1            0
#> 2            1
#> 3            0
#> 4            0
#> 5            0
#> 6            0
#> 7            0
#> 8            0
#> 9            0
#> 10           0
#> 11           0
#> 12           0
#> 13           0
#> 14           0
#> 15           0
#> 16           0
#> 17           0
```
