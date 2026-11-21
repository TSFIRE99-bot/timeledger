# Read a WFDB header file

Parses the record line of a WFDB `.hea` file. Headers of annotation-only
records (no signals) are supported; their `n_samples` may be zero, which
means the record length is not defined.

## Usage

``` r
read_wfdb_header(path)
```

## Arguments

- path:

  Path to the `.hea` file.

## Value

A list with `record`, `n_signals`, `fs`, `n_samples`, `base_time`,
`base_date` and `has_signals`.

## Examples

``` r
hea <- system.file("extdata", "04015.hea", package = "timeledger")
read_wfdb_header(hea)
#> $record
#> [1] "04015"
#> 
#> $n_signals
#> [1] 2
#> 
#> $fs
#> [1] 250
#> 
#> $n_samples
#> [1] 9205760
#> 
#> $base_time
#> [1] "9:00:00"
#> 
#> $base_date
#> [1] NA
#> 
#> $has_signals
#> [1] TRUE
#> 
```
