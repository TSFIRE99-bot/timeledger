# Validate evaluation inputs without building a ledger

Runs every check that
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
runs and returns the issues found. Errors stop
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md);
warnings and notes are kept as the `issues` attribute of the ledger.

## Usage

``` r
tl_validate(records, reference, predictions, observation = NULL)
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

## Value

A data frame of issues with columns `severity` (`"error"`, `"warning"`
or `"note"`), `table`, `record`, `row` (row number in the input table),
`issue` and `detail`. It has zero rows when nothing was found.

## Examples

``` r
fx <- tl_fixture("acceptance")
tl_validate(fx$records, fx$reference, fx$predictions)
#> [1] severity table    record   row      issue    detail  
#> <0 rows> (or 0-length row.names)
```
