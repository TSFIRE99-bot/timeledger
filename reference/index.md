# Package index

## Build and check the ledger

- [`tl_records()`](https://tsfire99-bot.github.io/timeledger/reference/tl_records.md)
  : Describe the recordings to be evaluated
- [`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
  : Build the time ledger
- [`tl_validate()`](https://tsfire99-bot.github.io/timeledger/reference/tl_validate.md)
  : Validate evaluation inputs without building a ledger
- [`tl_check()`](https://tsfire99-bot.github.io/timeledger/reference/tl_check.md)
  : Check the accounting identities of a ledger
- [`summary(`*`<tl_ledger>`*`)`](https://tsfire99-bot.github.io/timeledger/reference/summary.tl_ledger.md)
  : Duration totals for every state in a ledger
- [`tl_split()`](https://tsfire99-bot.github.io/timeledger/reference/tl_split.md)
  : Split ledger rows at given times
- [`tl_restrict()`](https://tsfire99-bot.github.io/timeledger/reference/tl_restrict.md)
  : Restrict a ledger to part of its time

## Episodes, alarms and matching

- [`tl_episodes()`](https://tsfire99-bot.github.io/timeledger/reference/tl_episodes.md)
  : Reference episodes
- [`tl_alarms()`](https://tsfire99-bot.github.io/timeledger/reference/tl_alarms.md)
  : Alarms raised by each detector
- [`tl_match()`](https://tsfire99-bot.github.io/timeledger/reference/tl_match.md)
  : Match reference episodes to alarms

## Metrics, comparisons and uncertainty

- [`tl_metrics()`](https://tsfire99-bot.github.io/timeledger/reference/tl_metrics.md)
  : Performance metrics with their denominators
- [`tl_get()`](https://tsfire99-bot.github.io/timeledger/reference/tl_get.md)
  : Extract one metric as a compact table
- [`tl_record_mean()`](https://tsfire99-bot.github.io/timeledger/reference/tl_record_mean.md)
  : Equal-record summaries of metrics
- [`tl_contributions()`](https://tsfire99-bot.github.io/timeledger/reference/tl_contributions.md)
  : Additive contributions of each record
- [`tl_compare()`](https://tsfire99-bot.github.io/timeledger/reference/tl_compare.md)
  : Compare two detectors on own, shared and full time
- [`tl_bootstrap()`](https://tsfire99-bot.github.io/timeledger/reference/tl_bootstrap.md)
  : Cluster bootstrap for pooled metrics and paired differences

## Inspect

- [`tl_trace()`](https://tsfire99-bot.github.io/timeledger/reference/tl_trace.md)
  [`tl_explain()`](https://tsfire99-bot.github.io/timeledger/reference/tl_trace.md)
  : Inspect the ledger rows behind a number
- [`plot(`*`<tl_ledger>`*`)`](https://tsfire99-bot.github.io/timeledger/reference/plot.tl_ledger.md)
  : Timeline plot of one record

## Prepare predictions and experiments

- [`tl_from_windows()`](https://tsfire99-bot.github.io/timeledger/reference/tl_from_windows.md)
  : Turn window decisions into prediction intervals
- [`tl_simulate_outages()`](https://tsfire99-bot.github.io/timeledger/reference/tl_simulate_outages.md)
  : Simulated input outages for controlled experiments
- [`tl_fixture()`](https://tsfire99-bot.github.io/timeledger/reference/tl_fixture.md)
  : Small worked examples with known answers

## WFDB files and epicmp compatibility

- [`read_wfdb_header()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_header.md)
  : Read a WFDB header file
- [`read_wfdb_ann()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_ann.md)
  [`write_wfdb_ann()`](https://tsfire99-bot.github.io/timeledger/reference/read_wfdb_ann.md)
  : Read and write WFDB annotation files
- [`wfdb_rhythm_intervals()`](https://tsfire99-bot.github.io/timeledger/reference/wfdb_rhythm_intervals.md)
  : Reference rhythm intervals from WFDB rhythm annotations
- [`wfdb_beats()`](https://tsfire99-bot.github.io/timeledger/reference/wfdb_beats.md)
  : Beat annotations from a WFDB annotation table
- [`write_wfdb_rhythm()`](https://tsfire99-bot.github.io/timeledger/reference/write_wfdb_rhythm.md)
  : Write detector responses as WFDB rhythm annotations
- [`wfdb_epicmp_af()`](https://tsfire99-bot.github.io/timeledger/reference/wfdb_epicmp_af.md)
  : WFDB epicmp-compatible AF episode comparison
- [`wfdb_parse_epicmp()`](https://tsfire99-bot.github.io/timeledger/reference/wfdb_parse_epicmp.md)
  : Parse the matrix-format output of WFDB epicmp
