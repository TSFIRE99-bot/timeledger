# Compare two detectors on own, shared and full time

A common-time comparison can be fair for one question and still discard
the hard periods that matter for another. `tl_compare()` therefore
reports each detector on its own answered time, both detectors on the
time when both answered, and full-period quantities, and it states how
much reference-known time and how many eligible episodes the shared
comparison discards.

## Usage

``` r
tl_compare(ledger, detectors = attr(ledger, "detectors")[1:2], ...)
```

## Arguments

- ledger:

  A `tl_ledger` with at least two detectors.

- detectors:

  The two detectors to compare.

- ...:

  Matching settings passed to
  [`tl_match()`](https://tsfire99-bot.github.io/timeledger/reference/tl_match.md).

## Value

An object of class `tl_compare`: a list with `own` and `shared`
(`tl_metrics`), `own_match` and `shared_match` (`tl_match`),
`shared_ledger`, `discarded` (time and episodes per detector) and
`table` (pooled estimates side by side).

## Examples

``` r
fx <- tl_fixture("two_detectors")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
cmp <- tl_compare(led, c("A", "B"))
cmp$table
#>                                metric      own_A      own_B   shared_A
#> 1                     answer_coverage  1.0000000  0.7000000  1.0000000
#> 2         answer_coverage_given_input         NA         NA         NA
#> 3                answered_sensitivity  0.7555556  0.8400000  0.7200000
#> 4                answered_specificity  0.9090909  1.0000000  0.8888889
#> 5                        full_capture  0.7555556  0.4666667  0.7200000
#> 6                        duration_ppv  0.8717949  1.0000000  0.7826087
#> 7                 episode_sensitivity  1.0000000  0.6666667  1.0000000
#> 8      false_alarms_per_answered_hour  0.6000000  0.0000000  0.8571429
#> 9         false_alarms_per_known_hour  0.6000000  0.0000000  0.8571429
#> 10 unmatched_alarms_per_answered_hour  0.6000000  0.0000000  0.8571429
#> 11               pred_burden_answered  0.3900000  0.3000000  0.3285714
#> 12                ref_burden_answered  0.4500000  0.3571429  0.3571429
#> 13                    ref_burden_full  0.4500000  0.4500000  0.3571429
#> 14                     burden_diff_pp -6.0000000 -5.7142857 -2.8571429
#> 15                 burden_bound_lower  0.3900000  0.2100000  0.3900000
#> 16                 burden_bound_upper  0.3900000  0.5100000  0.3900000
#> 17                   burden_error_min -6.0000000 -4.0000000 -2.0000000
#> 18                missed_negative_min 11.0000000  4.0000000  7.0000000
#> 19                 missed_abstain_min  0.0000000 20.0000000  0.0000000
#> 20                missed_no_input_min  0.0000000  0.0000000  0.0000000
#> 21                 missed_unknown_min  0.0000000  0.0000000  0.0000000
#> 22                   unmatched_alarms  1.0000000  0.0000000  1.0000000
#>      shared_B
#> 1   1.0000000
#> 2          NA
#> 3   0.8400000
#> 4   1.0000000
#> 5   0.8400000
#> 6   1.0000000
#> 7   1.0000000
#> 8   0.0000000
#> 9   0.0000000
#> 10  0.0000000
#> 11  0.3000000
#> 12  0.3571429
#> 13  0.3571429
#> 14 -5.7142857
#> 15  0.2100000
#> 16  0.5100000
#> 17 -4.0000000
#> 18  4.0000000
#> 19  0.0000000
#> 20  0.0000000
#> 21  0.0000000
#> 22  0.0000000
cmp$discarded
#>   detector known_time_own known_time_shared known_time_discarded
#> 1        A            100                70                   30
#> 2        B            100                70                   30
#>   event_time_discarded episodes_eligible_own episodes_eligible_shared
#> 1                   20                     3                        2
#> 2                   20                     3                        2
#>   episodes_discarded discarded_episode_ids
#> 1                  1             rec1:e002
#> 2                  1             rec1:e002
```
