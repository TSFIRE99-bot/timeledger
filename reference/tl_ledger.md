# Build the time ledger

`tl_ledger()` is the centre of the package. It cuts every record's
target period into disjoint half-open intervals `[start, end)`,
splitting wherever the reference state, the observation status, or any
detector's response changes. Each row states what was known about that
stretch of time, so every metric in the package is a sum over ledger
rows and can be traced back to the seconds behind it.

## Usage

``` r
tl_ledger(records, reference, predictions, observation = NULL, event = "AF",
  unknown = "unknown", missing = "unknown", time_unit = "s",
  on_warning = c("keep", "error"))
```

## Arguments

- records:

  Record table, usually from
  [`tl_records()`](https://tsfire99-bot.github.io/timeledger/reference/tl_records.md):
  columns `record`, `start`, `end`, and optionally `subject`, `fs`,
  `n_samples`.

- reference:

  Reference intervals: columns `record`, `start`, `end`, `label`.
  Optional `episode` gives a physiological episode identifier that is
  kept when an episode is interrupted, and optional `start_sample`,
  `end_sample` are checked against `fs`. Target time without a reference
  row is `"unknown"`.

- predictions:

  Detector responses: columns `record`, `detector`, `start`, `end`,
  `response` (`"positive"`, `"negative"` or `"abstain"`). Optional
  columns: `reason` (why the detector abstained), `issued_at` (time the
  decision became available, used for latency).

- observation:

  Optional input-availability intervals: columns `record`, `start`,
  `end`, `status` (`"available"` or `"unavailable"`), and optional
  `reason`. Uncovered time has status `"unknown"`.

- event:

  Reference labels that count as the target event.

- unknown:

  Reference labels that mean the reference is unknown. `NA` labels are
  always unknown. All other labels are non-events.

- missing:

  Meaning of target time with no prediction row: one of `"unknown"`,
  `"abstain"`, `"negative"`, `"no_input"`. Either one value or a named
  vector with one value per detector.

- time_unit:

  Unit of all times: `"ms"`, `"s"`, `"min"` or `"h"`. Used only to
  report rates per hour and errors in minutes.

- on_warning:

  What to do with warnings found during validation: `"keep"` (store them
  as the `issues` attribute) or `"error"`.

## Details

Four conditions that are often merged are kept apart:

- reference `"unknown"`: correctness cannot be assessed;

- response `"no_input"`: the reference may be known, but the monitor had
  no input, so a prediction was impossible;

- response `"abstain"`: input was available and the detector declined;

- response `"negative"`: an actual "no event" answer that can be right
  or wrong.

Time not covered by any prediction row is not silently treated as
negative. Its meaning comes from `missing`, which defaults to
`"unknown"`. A missing score is never used to infer that the device was
not worn; that needs an explicit `observation` table.

## Value

A data frame of class `tl_ledger` with one row per interval and
detector. Columns: `record`, `detector`, `start`, `end`, `duration`,
`reference`, `ref_label`, `ref_episode`, `ref_reason`, `observation`,
`obs_reason`, `response`, `response_source`, `response_reason`,
`issued_at`, `conflict`, `ref_row`, `obs_row`, `pred_row`. Attributes
hold the cleaned inputs, the settings and the validation issues.

## See also

[`tl_check()`](https://tsfire99-bot.github.io/timeledger/reference/tl_check.md),
[`tl_metrics()`](https://tsfire99-bot.github.io/timeledger/reference/tl_metrics.md),
[`tl_match()`](https://tsfire99-bot.github.io/timeledger/reference/tl_match.md),
[`tl_trace()`](https://tsfire99-bot.github.io/timeledger/reference/tl_trace.md)

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
led
#> <tl_ledger> 7 rows | 1 record(s) | detector(s): D | time unit: min
#>  record detector start end reference observation response    response_reason
#>    rec1        D     0  10  nonevent     unknown negative               <NA>
#>    rec1        D    10  20     event     unknown positive               <NA>
#>    rec1        D    20  40  nonevent     unknown negative               <NA>
#>    rec1        D    40  60     event     unknown  abstain low signal quality
#>    rec1        D    60  70  nonevent     unknown negative               <NA>
#>    rec1        D    70  80  nonevent     unknown positive               <NA>
#>    rec1        D    80 100  nonevent     unknown negative               <NA>
tl_check(led)
#>   record detector target ledger contiguous starts_at_target   ok
#> 1   rec1        D    100    100       TRUE             TRUE TRUE
```
