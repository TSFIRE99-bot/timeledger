# timeledger

Auditable time accounting for evaluating detectors of events in long,
continuous recordings.

Two monitors read the same 24-hour ECG. One skips four hard hours. Judged only
on the hours it answered, it can beat the other monitor and still miss more
atrial fibrillation (AF) over the day. It can even report the right number of
AF minutes while flagging the wrong ones. timeledger keeps the reference, the
input status and each detector's answers in one table of non-overlapping time
intervals, and every number it reports is computed from that table.

```r
library(timeledger)
fx <- tl_fixture("acceptance")              # the 100-minute example
led <- tl_ledger(fx$records, fx$reference, fx$predictions, time_unit = "min")
m <- tl_match(led, policy = "one_to_one")
tl_get(tl_metrics(led, m), c("answer_coverage", "answered_sensitivity",
                             "full_capture", "episode_sensitivity"))
tl_explain(led, m, episode = "rec1:e002")   # the seconds behind a missed episode
```

What it keeps apart:

| Situation | Ledger state |
|---|---|
| Reference rhythm unknown | `reference = "unknown"`, left out of truth-based denominators |
| Monitor had no input | `response = "no_input"`, from an explicit observation table |
| Input available, detector declined | `response = "abstain"`, with its reason |
| Detector answered "no event" | `response = "negative"` |
| No prediction row and no declared meaning | `response = "unknown"` (never silently negative) |

Main functions: `tl_ledger()`, `tl_check()`, `tl_metrics()`, `tl_match()`
(one-to-one with exact dynamic programming, or any-overlap), `tl_compare()`
(own, shared and full time), `tl_bootstrap()` (subject-level, paired),
`tl_trace()` / `tl_explain()`, `plot()`; WFDB adapters `read_wfdb_ann()`,
`write_wfdb_ann()`, `wfdb_rhythm_intervals()`, and `wfdb_epicmp_af()`, which
reproduces the AF statistics of WFDB `epicmp` 10.7.0 (verified against the
executable on 109 records under two detector policies; this is a
compatibility mode, not a claim of standards compliance).

The package depends only on base R (`graphics`, `stats`, `utils`).

## Citation

Menneni T (2026). timeledger: Auditable Time Accounting for Evaluating
Continuous Event Detectors. Archived at https://doi.org/10.5281/zenodo.24489065.

## Installation

```r
# development version (not yet on CRAN)
install.packages("timeledger_0.1.0.tar.gz", repos = NULL, type = "source")
```

## Status

Version 0.1.0 is a first release. It has not yet been used by anyone other
than its author. Bug reports and use cases are welcome via the issue tracker.

## Data

`inst/extdata` contains the annotation files of record 04015 of the MIT-BIH
Atrial Fibrillation Database (Moody and Mark 1983), distributed by PhysioNet
under the Open Data Commons Attribution License v1.0. See `data-raw/README.md`.
