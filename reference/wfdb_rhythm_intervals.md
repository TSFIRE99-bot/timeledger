# Reference rhythm intervals from WFDB rhythm annotations

Converts rhythm annotations (`symbol == "+"` with an `aux` label such as
`"(AFIB"`) into half-open reference intervals. Each label holds until
the next rhythm annotation, and the last one holds until `end_sample`.

## Usage

``` r
wfdb_rhythm_intervals(ann, record, fs, end_sample, start_sample = 0,
  before_first = "(unlabelled)")
```

## Arguments

- ann:

  Annotations from
  [`read_wfdb_ann()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_ann.md).

- record:

  Record identifier.

- fs:

  Sampling frequency in Hz.

- end_sample:

  End of the reference period in samples (e.g. the header `n_samples`).
  Required: annotation-only records may have no length.

- start_sample:

  Start of the reference period.

- before_first:

  Label for time before the first rhythm annotation.

## Details

Time before the first rhythm annotation has no stated rhythm. By default
it is labelled `"(unlabelled)"`, which
[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
treats as unknown when passed in `unknown`; set `before_first` to a
rhythm label to adopt another convention explicitly.

## Value

A data frame with `record`, `start`, `end` (seconds), `start_sample`,
`end_sample` and `label`.

## Examples

``` r
atr <- system.file("extdata", "04015.atr", package = "timeledger")
hea <- read_wfdb_header(system.file("extdata", "04015.hea",
                                    package = "timeledger"))
wfdb_rhythm_intervals(read_wfdb_ann(atr), "04015", hea$fs, hea$n_samples)
#>    record    start       end start_sample end_sample        label
#> 1   04015    0.000     0.120            0         30 (unlabelled)
#> 2   04015    0.120   410.336           30     102584           (N
#> 3   04015  410.336   478.416       102584     119604        (AFIB
#> 4   04015  478.416   487.092       119604     121773           (N
#> 5   04015  487.092   488.776       121773     122194        (AFIB
#> 6   04015  488.776   533.392       122194     133348           (N
#> 7   04015  533.392   667.428       133348     166857        (AFIB
#> 8   04015  667.428  4384.980       166857    1096245           (N
#> 9   04015 4384.980  4392.216      1096245    1098054        (AFIB
#> 10  04015 4392.216  4541.184      1098054    1135296           (N
#> 11  04015 4541.184  4558.380      1135296    1139595        (AFIB
#> 12  04015 4558.380  5689.744      1139595    1422436           (N
#> 13  04015 5689.744  5694.192      1422436    1423548        (AFIB
#> 14  04015 5694.192  5837.108      1423548    1459277           (N
#> 15  04015 5837.108  5841.664      1459277    1460416        (AFIB
#> 16  04015 5841.664 36823.040      1460416    9205760           (N
```
