# Write detector responses as WFDB rhythm annotations

WFDB test annotation files describe rhythm as a state that holds until
the next rhythm annotation. They cannot express abstention or missing
input: every stretch of time is some rhythm. This writer therefore needs
an explicit label for responses other than positive, and the choice is
recorded by the caller.

## Usage

``` r
write_wfdb_rhythm(path, predictions, fs, positive_label = "(AFIB",
  other_label = "(N", start_sample = 0)
```

## Arguments

- path:

  Output annotation file.

- predictions:

  Prediction rows of one record and detector (columns `start`, `end`,
  `response`), in seconds.

- fs:

  Sampling frequency in Hz.

- positive_label,other_label:

  Rhythm labels for positive and for all other responses (negative,
  abstain, uncovered time).

- start_sample:

  Sample at which the first rhythm label starts.

## Value

`path`, invisibly.
