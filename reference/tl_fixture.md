# Small worked examples with known answers

- `"acceptance"`: a 100-minute recording with complete reference. True
  AF on \\\[10, 20)\\ and \\\[40, 60)\\; the detector flags \\\[10,
  20)\\ and \\\[70, 80)\\, abstains on \\\[40, 60)\\ and otherwise
  answers "no AF". Under one-to-one positive-overlap matching: answer
  coverage 80%, answered-time sensitivity 100%, full-period capture
  33.3%, episode detection 1/2, one unmatched alarm, 0.75 false alarms
  per answered hour, predicted burden 25% and reference burden 12.5% on
  answered time, and full-period predicted burden between 20% and 40%.

- `"burden_mismatch"`: predicted and reference AF durations are equal
  (20 minutes each) but never overlap, so the burden error is zero while
  no AF time is captured.

- `"two_detectors"`: detector A answers throughout; detector B declines
  during the hardest period. B looks better on its own answered time and
  captures less AF over the full period.

## Usage

``` r
tl_fixture(name = c("acceptance", "burden_mismatch", "two_detectors"))
```

## Arguments

- name:

  Fixture name.

## Details

Times are in minutes; build the ledger with `time_unit = "min"`.

## Value

A list with `records`, `reference` and `predictions`.

## Examples

``` r
str(tl_fixture("acceptance"))
#> List of 3
#>  $ records    :Classes ‘tl_records’ and 'data.frame':    1 obs. of  6 variables:
#>   ..$ record   : chr "rec1"
#>   ..$ start    : num 0
#>   ..$ end      : num 100
#>   ..$ subject  : chr "rec1"
#>   ..$ fs       : num NA
#>   ..$ n_samples: num NA
#>  $ reference  :'data.frame': 5 obs. of  4 variables:
#>   ..$ record: chr [1:5] "rec1" "rec1" "rec1" "rec1" ...
#>   ..$ start : num [1:5] 0 10 20 40 60
#>   ..$ end   : num [1:5] 10 20 40 60 100
#>   ..$ label : chr [1:5] "non-AF" "AF" "non-AF" "AF" ...
#>  $ predictions:'data.frame': 7 obs. of  6 variables:
#>   ..$ record  : chr [1:7] "rec1" "rec1" "rec1" "rec1" ...
#>   ..$ detector: chr [1:7] "D" "D" "D" "D" ...
#>   ..$ start   : num [1:7] 0 10 20 40 60 70 80
#>   ..$ end     : num [1:7] 10 20 40 60 70 80 100
#>   ..$ response: chr [1:7] "negative" "positive" "negative" "abstain" ...
#>   ..$ reason  : chr [1:7] NA NA NA "low signal quality" ...
```
