# Beat annotations from a WFDB annotation table

Beat annotations from a WFDB annotation table

## Usage

``` r
wfdb_beats(ann, fs)
```

## Arguments

- ann:

  Annotations from
  [`read_wfdb_ann()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_ann.md).

- fs:

  Sampling frequency in Hz.

## Value

A data frame with `sample`, `time` (seconds) and `symbol` for beat
annotations only.

## Examples

``` r
qrs <- system.file("extdata", "04015.qrs", package = "timeledger")
head(wfdb_beats(read_wfdb_ann(qrs), fs = 250))
#>   sample  time symbol
#> 1     61 0.244      N
#> 2    200 0.800      N
#> 3    358 1.432      N
#> 4    584 2.336      N
#> 5    729 2.916      N
#> 6    873 3.492      N
```
