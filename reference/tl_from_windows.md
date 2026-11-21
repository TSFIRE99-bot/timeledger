# Turn window decisions into prediction intervals

Detectors usually score windows. How a window's decision becomes an
interval is an analysis choice that changes the results, so it is made
explicit here.

## Usage

``` r
tl_from_windows(record, detector, decided_at, response, window_start = NULL,
  window_end = NULL, reason = NA_character_, mode = c("hold", "window"),
  max_hold = Inf, until = NULL, gap_response = NULL,
  gap_reason = "no current decision")
```

## Arguments

- record,detector:

  Identifiers (recycled).

- decided_at:

  Time each decision became available.

- response:

  `"positive"`, `"negative"` or `"abstain"`.

- window_start,window_end:

  Window bounds (needed for `mode = "window"`).

- reason:

  Optional reason for each decision (e.g. why it abstained).

- mode:

  `"hold"` or `"window"`.

- max_hold:

  Longest time a held decision stays valid.

- until:

  Optional end of each record (recycled over records in order of first
  appearance, or named by record). The last held decision of a record
  stays valid until `until` or for `max_hold`, whichever comes first;
  with neither, the last decision has no defined end and is dropped.

- gap_response:

  Optional response for uncovered time between the first and last
  decision (e.g. `"abstain"`).

- gap_reason:

  Reason stored with `gap_response` rows.

## Details

- `mode = "hold"` (real time): a decision issued at `decided_at` holds
  from that moment until the next decision of the same record and
  detector, or for at most `max_hold`. This uses no future signal.

- `mode = "window"` (retrospective): each decision is assigned to its
  own window `[window_start, window_end)`. Where windows overlap, the
  window decided last wins. Window ends must increase with window
  starts.

Time not covered by any decision gets no row; its meaning is then set by
the `missing` argument of
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md),
unless `gap_response` is given.

## Value

A prediction table for
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
with an `issued_at` column.

## Examples

``` r
tl_from_windows("r1", "D", decided_at = c(10, 20, 30),
                response = c("negative", "positive", "negative"),
                max_hold = 15)
#>   record detector start end response reason issued_at
#> 1     r1        D    10  20 negative   <NA>        10
#> 2     r1        D    20  30 positive   <NA>        20
#> 3     r1        D    30  45 negative   <NA>        30
```
