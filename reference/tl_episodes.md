# Reference episodes

Collects the reference event intervals of a ledger into episodes. An
episode keeps one identifier even when gaps in observation or prediction
cut it into several ledger rows, so clipping never creates extra
physiological episodes. The table separates what was observed from what
was not: an episode already in progress when the recording starts has
`onset_status = "recording_start"`, and one that follows unknown
reference time has `onset_status = "after_unknown_reference"`. Only
episodes with `onset_status = "observed"` have a known onset.

## Usage

``` r
tl_episodes(ledger, merge_gap = 0)
```

## Arguments

- ledger:

  A `tl_ledger`.

- merge_gap:

  Episodes of the same record separated by known non-event time no
  longer than this are merged (in the ledger's time unit). Episodes
  separated by unknown reference time are never merged.

## Value

A data frame with one row per episode: `episode_id`, `record`, `start`,
`end` (span), `event_time` (event time on reference-known rows of the
ledger), `n_fragments`, `onset_status`, `offset_status`, and `members`
(original identifiers merged into this episode).

## Examples

``` r
fx <- tl_fixture("acceptance")
tl_episodes(tl_ledger(fx$records, fx$reference, fx$predictions,
                      time_unit = "min"))
#>   episode_id record start end event_time n_fragments onset_status offset_status
#> 1  rec1:e001   rec1    10  20         10           1     observed      observed
#> 2  rec1:e002   rec1    40  60         20           1     observed      observed
#>     members
#> 1 rec1:e001
#> 2 rec1:e002
```
