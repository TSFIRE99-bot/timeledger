# Read and write WFDB annotation files

`read_wfdb_ann()` decodes the MIT binary annotation format in base R,
including `SKIP`, `NUM`, `SUB`, `CHN` and `AUX` pseudo-annotations.
`write_wfdb_ann()` writes the same format; it is used to hand test
annotations to WFDB `epicmp`.

## Usage

``` r
read_wfdb_ann(path, fs = NULL)
write_wfdb_ann(path, ann)
```

## Arguments

- path:

  File path.

- fs:

  Optional sampling frequency; adds a `time` column in seconds.

- ann:

  A data frame with `sample` and `type` (or `symbol`), and optionally
  `aux`, `subtype`, `chan`, `num`.

## Value

`read_wfdb_ann()`: a data frame with `sample`, `type` (numeric code),
`symbol`, `subtype`, `chan`, `num`, `aux` and optionally `time`.
`write_wfdb_ann()`: `path`, invisibly.

## Examples

``` r
atr <- system.file("extdata", "04015.atr", package = "timeledger")
a <- read_wfdb_ann(atr, fs = 250)
a[a$symbol == "+", c("sample", "time", "aux")]
#>     sample     time   aux
#> 1       30    0.120    (N
#> 2   102584  410.336 (AFIB
#> 3   119604  478.416    (N
#> 4   121773  487.092 (AFIB
#> 5   122194  488.776    (N
#> 6   133348  533.392 (AFIB
#> 7   166857  667.428    (N
#> 8  1096245 4384.980 (AFIB
#> 9  1098054 4392.216    (N
#> 10 1135296 4541.184 (AFIB
#> 11 1139595 4558.380    (N
#> 12 1422436 5689.744 (AFIB
#> 13 1423548 5694.192    (N
#> 14 1459277 5837.108 (AFIB
#> 15 1460416 5841.664    (N
tmp <- tempfile(fileext = ".tst")
write_wfdb_ann(tmp, a)
identical(read_wfdb_ann(tmp)$sample, a$sample)
#> [1] TRUE
```
