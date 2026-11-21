# Alarms raised by each detector

An alarm is a maximal run of positive responses in the ledger. Runs
separated by no more than `merge_gap` (of any other response) are
merged, and alarms with less than `min_duration` of positive time are
dropped and reported in the `suppressed` attribute.

## Usage

``` r
tl_alarms(ledger, merge_gap = 0, min_duration = 0)
```

## Arguments

- ledger:

  A `tl_ledger`.

- merge_gap:

  Maximum gap between positive runs merged into one alarm.

- min_duration:

  Minimum positive time for an alarm to count.

## Value

A data frame with one row per alarm: `alarm_id`, `record`, `detector`,
`start`, `end`, `positive_time`, `known_time` (positive time on
reference-known rows), `issued_at` (earliest decision time among the
contributing prediction rows, when supplied).

## Examples

``` r
fx <- tl_fixture("acceptance")
tl_alarms(tl_ledger(fx$records, fx$reference, fx$predictions,
                    time_unit = "min"))
#>      alarm_id record detector start end positive_time known_time issued_at
#> 1 rec1:D:a001   rec1        D    10  20            10         10        NA
#> 2 rec1:D:a002   rec1        D    70  80            10         10        NA
```
