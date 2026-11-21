# Duration totals for every state in a ledger

Duration totals for every state in a ledger

## Usage

``` r
# S3 method for class 'tl_ledger'
summary(object,
  by = c("reference", "observation", "response"), ...)
```

## Arguments

- object:

  A `tl_ledger`.

- by:

  Columns to cross-tabulate; defaults to reference state, observation
  status and response.

- ...:

  Unused.

## Value

A data frame of total durations per detector and state combination, with
the share of the target period.

## Examples

``` r
fx <- tl_fixture("acceptance")
summary(tl_ledger(fx$records, fx$reference, fx$predictions,
                  time_unit = "min"))
#>   detector reference observation response duration share
#> 2        D  nonevent     unknown negative       60   0.6
#> 1        D     event     unknown  abstain       20   0.2
#> 3        D     event     unknown positive       10   0.1
#> 4        D  nonevent     unknown positive       10   0.1
```
