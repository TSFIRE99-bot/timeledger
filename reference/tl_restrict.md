# Restrict a ledger to part of its time

Rows outside `keep` have their reference state set to `"unknown"`, with
the reason recorded in `ref_reason`. Because every reference-based
metric is computed on reference-known time, this removes the rows from
all denominators while leaving them visible for inspection. Durations
still add up to the target period.

## Usage

``` r
tl_restrict(ledger, keep, reason)
```

## Arguments

- ledger:

  A `tl_ledger`.

- keep:

  Logical vector, one value per ledger row.

- reason:

  Text stored in `ref_reason` for the excluded rows.

## Value

The modified `tl_ledger`, with the restriction logged in the
`restrictions` attribute.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
late <- tl_restrict(led, led$start >= 50, "before minute 50")
tl_metrics(late, tl_match(late))
#> <tl_metrics> time unit: min
#>   level   record detector                             metric estimate numerator
#>  pooled <pooled>        D                    answer_coverage     1.00        40
#>  pooled <pooled>        D        answer_coverage_given_input       NA         0
#>  pooled <pooled>        D               answered_sensitivity       NA         0
#>  pooled <pooled>        D               answered_specificity     0.75        30
#>  pooled <pooled>        D                       full_capture       NA         0
#>  pooled <pooled>        D                       duration_ppv     0.00         0
#>  pooled <pooled>        D                episode_sensitivity       NA         0
#>  pooled <pooled>        D     false_alarms_per_answered_hour     1.50         1
#>  pooled <pooled>        D        false_alarms_per_known_hour     1.50         1
#>  pooled <pooled>        D unmatched_alarms_per_answered_hour     1.50         1
#>  pooled <pooled>        D               pred_burden_answered     0.25        10
#>  pooled <pooled>        D                ref_burden_answered     0.00         0
#>  pooled <pooled>        D                    ref_burden_full     0.00         0
#>  pooled <pooled>        D                     burden_diff_pp    25.00        10
#>  pooled <pooled>        D                 burden_bound_lower     0.20        20
#>  pooled <pooled>        D                 burden_bound_upper     0.40        40
#>  pooled <pooled>        D                   burden_error_min    10.00        10
#>  pooled <pooled>        D                missed_negative_min     0.00         0
#>  pooled <pooled>        D                 missed_abstain_min     0.00         0
#>  pooled <pooled>        D                missed_no_input_min     0.00         0
#>  pooled <pooled>        D                 missed_unknown_min     0.00         0
#>  pooled <pooled>        D                   unmatched_alarms     1.00         1
#>  record     rec1        D                    answer_coverage     1.00        40
#>  record     rec1        D        answer_coverage_given_input       NA         0
#>  record     rec1        D               answered_sensitivity       NA         0
#>  record     rec1        D               answered_specificity     0.75        30
#>  record     rec1        D                       full_capture       NA         0
#>  record     rec1        D                       duration_ppv     0.00         0
#>  record     rec1        D                episode_sensitivity       NA         0
#>  record     rec1        D     false_alarms_per_answered_hour     1.50         1
#>  record     rec1        D        false_alarms_per_known_hour     1.50         1
#>  record     rec1        D unmatched_alarms_per_answered_hour     1.50         1
#>  record     rec1        D               pred_burden_answered     0.25        10
#>  record     rec1        D                ref_burden_answered     0.00         0
#>  record     rec1        D                    ref_burden_full     0.00         0
#>  record     rec1        D                     burden_diff_pp    25.00        10
#>  record     rec1        D                 burden_bound_lower     0.20        20
#>  record     rec1        D                 burden_bound_upper     0.40        40
#>  record     rec1        D                   burden_error_min    10.00        10
#>  record     rec1        D                missed_negative_min     0.00         0
#>  record     rec1        D                 missed_abstain_min     0.00         0
#>  record     rec1        D                missed_no_input_min     0.00         0
#>  record     rec1        D                 missed_unknown_min     0.00         0
#>  record     rec1        D                   unmatched_alarms     1.00         1
#>  denominator              unit                   undefined_reason
#>           40        proportion                               <NA>
#>            0        proportion    input availability not declared
#>            0        proportion no event time during answered time
#>           40        proportion                               <NA>
#>            0        proportion      no reference-known event time
#>           10        proportion                               <NA>
#>            0        proportion               no eligible episodes
#>           40          per hour                               <NA>
#>           40          per hour                               <NA>
#>           40          per hour                               <NA>
#>           40        proportion                               <NA>
#>           40        proportion                               <NA>
#>           40        proportion                               <NA>
#>           40 percentage points                               <NA>
#>          100        proportion                               <NA>
#>          100        proportion                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA             count                               <NA>
#>           40        proportion                               <NA>
#>            0        proportion    input availability not declared
#>            0        proportion no event time during answered time
#>           40        proportion                               <NA>
#>            0        proportion      no reference-known event time
#>           10        proportion                               <NA>
#>            0        proportion               no eligible episodes
#>           40          per hour                               <NA>
#>           40          per hour                               <NA>
#>           40          per hour                               <NA>
#>           40        proportion                               <NA>
#>           40        proportion                               <NA>
#>           40        proportion                               <NA>
#>           40 percentage points                               <NA>
#>          100        proportion                               <NA>
#>          100        proportion                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA           minutes                               <NA>
#>           NA             count                               <NA>
```
