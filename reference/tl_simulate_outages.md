# Simulated input outages for controlled experiments

Places non-overlapping outages in each record and removes the affected
prediction time, so that
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
marks it as `"no_input"`. Every row produced carries a reason starting
with `"simulated"`; results from these experiments must be labelled as
simulated.

## Usage

``` r
tl_simulate_outages(ledger, n, duration,
  mode = c("random", "event_concentrated"), seed = NULL, max_tries = 1000)
```

## Arguments

- ledger:

  A `tl_ledger` (used for records, reference and predictions).

- n:

  Number of outages per record.

- duration:

  Duration of each outage.

- mode:

  `"random"` or `"event_concentrated"`.

- seed:

  Optional random seed.

- max_tries:

  Attempts per outage before giving up on a placement.

## Details

`mode = "random"` draws outage start times uniformly over the target
period. `mode = "event_concentrated"` is a deliberately artificial
stress test: outage start times are drawn uniformly over reference event
time. It tests how an evaluation behaves when missingness concentrates
on events; it says nothing about whether real devices fail during
events.

## Value

A list with `observation` (for
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md))
and `predictions` (the original prediction rows with outage time
removed).

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
sim <- tl_simulate_outages(led, n = 2, duration = 5, seed = 1)
sim$observation
#>   record    start       end      status                    reason
#> 1   rec1  0.00000  25.22332   available                      <NA>
#> 2   rec1 25.22332  30.22332 unavailable simulated outage (random)
#> 3   rec1 30.22332  35.35177   available                      <NA>
#> 4   rec1 35.35177  40.35177 unavailable simulated outage (random)
#> 5   rec1 40.35177 100.00000   available                      <NA>
```
