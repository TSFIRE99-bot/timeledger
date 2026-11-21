# Additive contributions of each record

Every metric in
[`tl_metrics()`](https://tsfire99-bot.github.io/timeledger/reference/tl_metrics.md)
is a ratio of sums, so it can be computed from per-record totals. This
function returns those totals, one row per record and detector. They are
the unit of resampling in
[`tl_bootstrap()`](https://tsfire99-bot.github.io/timeledger/reference/tl_bootstrap.md).

## Usage

``` r
tl_contributions(ledger, match = NULL)
```

## Arguments

- ledger:

  A `tl_ledger`.

- match:

  Optional `tl_match` from the same ledger.

## Details

Durations are in the ledger's time unit. Columns: `target` (T), `known`
(reference-known, K), `answered` (answered and reference-known, A),
`answered_any` (answered anywhere in the target), `unanswered` (abstain,
no input or unknown response anywhere in the target), `positive_target`,
`positive_known`, `event` (E), `event_answered`, `tp`,
`nonevent_answered`, `tn`, `fp_time`, `known_input` and `answered_input`
(reference-known time with input available, and the answered part of
it), `missed_negative`, `missed_abstain`, `missed_no_input`,
`missed_unknown` (event time by response), `positive_unknown_ref`
(positive time with unknown reference), and, when `match` is given,
`episodes_eligible`, `episodes_detected`, `alarms`, `alarms_matched`,
`alarms_redundant`, `alarms_false`, `alarms_unassessable`,
`alarms_ineligible`.

## Value

A data frame with one row per record and detector.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
tl_contributions(led, tl_match(led))
#>   record detector subject target known answered answered_any unanswered
#> 1   rec1        D    rec1    100   100       80           80         20
#>   positive_target positive_known event event_answered tp nonevent_answered tn
#> 1              20             20    30             10 10                70 60
#>   fp_time known_input answered_input missed_negative missed_abstain
#> 1      10           0              0               0             20
#>   missed_no_input missed_unknown positive_unknown_ref episodes_eligible
#> 1               0              0                    0                 2
#>   episodes_detected alarms alarms_matched alarms_redundant alarms_false
#> 1                 1      2              1                0            1
#>   alarms_unassessable alarms_ineligible
#> 1                   0                 0
```
