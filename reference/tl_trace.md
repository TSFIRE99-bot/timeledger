# Inspect the ledger rows behind a number

`tl_trace()` returns the ledger rows of one record that intersect a time
window. `tl_explain()` returns the rows behind one alarm or one episode,
with the matching decision attached, so a false alarm or a missed
episode can be followed down to the exact intervals that produced it.

## Usage

``` r
tl_trace(ledger, record, from = -Inf, to = Inf, detector = NULL)
tl_explain(ledger, match, alarm = NULL, episode = NULL)
```

## Arguments

- ledger:

  A `tl_ledger`.

- record:

  Record identifier.

- from,to:

  Time window (half-open).

- detector:

  Optional detector(s) to keep.

- match:

  A `tl_match` computed from `ledger`.

- alarm:

  An alarm identifier from `match$alarms`.

- episode:

  An episode identifier from `match$episodes`.

## Value

A plain data frame of ledger rows.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
tl_trace(led, "rec1", 35, 65)
#>   record detector start end duration reference ref_label ref_episode ref_reason
#> 1   rec1        D    20  40       20  nonevent    non-AF        <NA>       <NA>
#> 2   rec1        D    40  60       20     event        AF   rec1:e002       <NA>
#> 3   rec1        D    60  70       10  nonevent    non-AF        <NA>       <NA>
#>   observation obs_reason response response_source    response_reason issued_at
#> 1     unknown       <NA> negative      prediction               <NA>        NA
#> 2     unknown       <NA>  abstain      prediction low signal quality        NA
#> 3     unknown       <NA> negative      prediction               <NA>        NA
#>   conflict ref_row obs_row pred_row
#> 1    FALSE       3      NA        3
#> 2    FALSE       4      NA        4
#> 3    FALSE       5      NA        5
m <- tl_match(led)
tl_explain(led, m, alarm = m$alarms$alarm_id[m$alarms$status == "false"])
#>   record detector start end duration reference ref_label ref_episode ref_reason
#> 1   rec1        D    70  80       10  nonevent    non-AF        <NA>       <NA>
#>   observation obs_reason response response_source response_reason issued_at
#> 1     unknown       <NA> positive      prediction            <NA>        NA
#>   conflict ref_row obs_row pred_row    alarm_id decision matched_episode
#> 1    FALSE       5      NA        6 rec1:D:a002    false            <NA>
tl_explain(led, m, episode = "rec1:e002")
#>   record detector start end duration reference ref_label ref_episode ref_reason
#> 1   rec1        D    40  60       20     event        AF   rec1:e002       <NA>
#>   observation obs_reason response response_source    response_reason issued_at
#> 1     unknown       <NA>  abstain      prediction low signal quality        NA
#>   conflict ref_row obs_row pred_row alarm_id episode_detected episode_eligible
#> 1    FALSE       4      NA        4     <NA>            FALSE             TRUE
#>   matched_alarm
#> 1          <NA>
```
