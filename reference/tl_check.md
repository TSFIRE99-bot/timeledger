# Check the accounting identities of a ledger

Verifies that, for every record and detector, the ledger rows are
contiguous, do not overlap, and add up to the declared target period.

## Usage

``` r
tl_check(ledger, tol = 1e-09)
```

## Arguments

- ledger:

  A `tl_ledger`.

- tol:

  Numerical tolerance for the duration identity.

## Value

A data frame with one row per record and detector: target duration,
ledger duration, whether rows are contiguous, and `ok`.

## Examples

``` r
fx <- tl_fixture("acceptance")
tl_check(tl_ledger(fx$records, fx$reference, fx$predictions,
                   time_unit = "min"))
#>   record detector target ledger contiguous starts_at_target   ok
#> 1   rec1        D    100    100       TRUE             TRUE TRUE
```
