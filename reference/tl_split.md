# Split ledger rows at given times

Adds breakpoints without changing any state, so all duration metrics are
unchanged. Useful before a learning period or a time-of-day restriction.

## Usage

``` r
tl_split(ledger, at)
```

## Arguments

- ledger:

  A `tl_ledger`.

- at:

  Either a numeric vector of times applied to every record, or a data
  frame with columns `record` and `time`.

## Value

The `tl_ledger` with the extra breakpoints.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
nrow(tl_split(led, 15))
#> [1] 8
```
