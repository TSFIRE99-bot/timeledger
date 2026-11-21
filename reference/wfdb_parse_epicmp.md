# Parse the matrix-format output of WFDB epicmp

Parse the matrix-format output of WFDB epicmp

## Usage

``` r
wfdb_parse_epicmp(text)
```

## Arguments

- text:

  Character vector with the output of \`epicmp -r REC -a REF TEST\` (AF
  section).

## Value

A list with the episode counts and the durations (in seconds, as printed
with millisecond resolution).
