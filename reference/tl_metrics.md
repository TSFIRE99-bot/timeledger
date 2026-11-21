# Performance metrics with their denominators

Computes every headline quantity together with its numerator,
denominator, units, the time excluded from it, and an explicit reason
whenever it is undefined. Results are given per record and pooled over
records (ratio of sums, which weights records by their duration). Use
[`tl_record_mean()`](https://tsfire99-bot.github.io/timeledger/reference/tl_record_mean.md)
for equal-record summaries.

## Usage

``` r
tl_metrics(ledger, match = NULL, level = c("both", "record", "pooled"))
```

## Arguments

- ledger:

  A `tl_ledger`.

- match:

  Optional `tl_match`; needed for episode and alarm metrics.

- level:

  `"both"`, `"record"` or `"pooled"`.

## Details

Definitions (all durations from the ledger; "known" means the reference
is known):

- `answer_coverage`: answered known time / known time.

- `answer_coverage_given_input`: the same restricted to time with input
  declared available.

- `answered_sensitivity`: correctly flagged event time / event time
  during answered time.

- `full_capture`: correctly flagged event time / all known event time.
  Unanswered event time counts as missed; its reasons are reported as
  `missed_*_min` rows.

- `episode_sensitivity`: detected / eligible episodes under the matching
  policy in `match`.

- `false_alarms_per_*_hour`: alarms with no reference-event overlap per
  answered (or known) hour; `unmatched_alarms_per_answered_hour` also
  counts redundant alarms.

- `pred_burden_answered`, `ref_burden_answered`: predicted and reference
  event fractions on the same answered time; `ref_burden_full`:
  reference event fraction over known time; `burden_diff_pp` is their
  difference in percentage points and `burden_error_min` in minutes.

- `burden_bound_lower`, `burden_bound_upper`: the range of full-period
  predicted burden compatible with completing the unanswered time,
  keeping the answered labels fixed. This bounds the prediction, not the
  true burden.

## Value

A data frame of class `tl_metrics` with columns `level`, `record`,
`detector`, `metric`, `estimate`, `numerator`, `denominator`, `unit`,
`excluded_time` (reference-unknown time left out of known-time
denominators) and `undefined_reason`.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
tl_metrics(led, tl_match(led), level = "pooled")
#> <tl_metrics> time unit: min
#>   level   record detector                             metric estimate numerator
#>  pooled <pooled>        D                    answer_coverage   0.8000        80
#>  pooled <pooled>        D        answer_coverage_given_input       NA         0
#>  pooled <pooled>        D               answered_sensitivity   1.0000        10
#>  pooled <pooled>        D               answered_specificity   0.8571        60
#>  pooled <pooled>        D                       full_capture   0.3333        10
#>  pooled <pooled>        D                       duration_ppv   0.5000        10
#>  pooled <pooled>        D                episode_sensitivity   0.5000         1
#>  pooled <pooled>        D     false_alarms_per_answered_hour   0.7500         1
#>  pooled <pooled>        D        false_alarms_per_known_hour   0.6000         1
#>  pooled <pooled>        D unmatched_alarms_per_answered_hour   0.7500         1
#>  pooled <pooled>        D               pred_burden_answered   0.2500        20
#>  pooled <pooled>        D                ref_burden_answered   0.1250        10
#>  pooled <pooled>        D                    ref_burden_full   0.3000        30
#>  pooled <pooled>        D                     burden_diff_pp  12.5000        10
#>  pooled <pooled>        D                 burden_bound_lower   0.2000        20
#>  pooled <pooled>        D                 burden_bound_upper   0.4000        40
#>  pooled <pooled>        D                   burden_error_min  10.0000        10
#>  pooled <pooled>        D                missed_negative_min   0.0000         0
#>  pooled <pooled>        D                 missed_abstain_min  20.0000        20
#>  pooled <pooled>        D                missed_no_input_min   0.0000         0
#>  pooled <pooled>        D                 missed_unknown_min   0.0000         0
#>  pooled <pooled>        D                   unmatched_alarms   1.0000         1
#>  denominator              unit                undefined_reason
#>          100        proportion                            <NA>
#>            0        proportion input availability not declared
#>           10        proportion                            <NA>
#>           70        proportion                            <NA>
#>           30        proportion                            <NA>
#>           20        proportion                            <NA>
#>            2        proportion                            <NA>
#>           80          per hour                            <NA>
#>          100          per hour                            <NA>
#>           80          per hour                            <NA>
#>           80        proportion                            <NA>
#>           80        proportion                            <NA>
#>          100        proportion                            <NA>
#>           80 percentage points                            <NA>
#>          100        proportion                            <NA>
#>          100        proportion                            <NA>
#>           NA           minutes                            <NA>
#>           NA           minutes                            <NA>
#>           NA           minutes                            <NA>
#>           NA           minutes                            <NA>
#>           NA           minutes                            <NA>
#>           NA             count                            <NA>
```
