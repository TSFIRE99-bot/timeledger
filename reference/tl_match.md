# Match reference episodes to alarms

Pairs reference episodes with detector alarms under a named policy and
records the overlap behind every decision.

## Usage

``` r
tl_match(ledger, policy = c("one_to_one", "any_overlap"),
  scope = c("full", "answered"), min_overlap = 0, min_episode_time = 0,
  learning_period = 0, episode_merge_gap = 0, alarm_merge_gap = 0,
  alarm_min_duration = 0)
```

## Arguments

- ledger:

  A `tl_ledger`.

- policy:

  `"one_to_one"` or `"any_overlap"`.

- scope:

  `"full"` or `"answered"`; see Eligibility.

- min_overlap:

  Pairs need overlap strictly greater than this.

- min_episode_time:

  Minimum counted event time for eligibility.

- learning_period:

  Time at the start of each record excluded from matching (episodes are
  clipped; alarms ending inside it are set aside).

- episode_merge_gap,alarm_merge_gap,alarm_min_duration:

  Passed to
  [`tl_episodes()`](https://tsfire99-bot.github.io/timeledger/reference/tl_episodes.md)
  and
  [`tl_alarms()`](https://tsfire99-bot.github.io/timeledger/reference/tl_alarms.md).

## Details

**Overlap.** The overlap between an episode and an alarm is the ledger
time on which the reference is the event, the row belongs to the
episode, and the detector response is positive. Intervals that only
touch (one ends where the other starts) have zero overlap.

**Eligibility.** With `scope = "full"`, an episode is eligible when its
reference-known event time after the learning period is at least
`min_episode_time`. With `scope = "answered"`, the time counted is event
time on which the detector answered (positive or negative). Ineligible
episodes are kept in the output with the reason.

**Policies.**

- `"any_overlap"`: an episode is detected when any alarm overlaps it by
  more than `min_overlap`; an alarm is matched when it overlaps any
  eligible episode. One alarm may detect several episodes, and several
  alarms may share one episode. This is the rule used by WFDB `epicmp`
  for AF episodes (see
  [`wfdb_epicmp_af()`](https://tsfire99-bot.github.io/timeledger/reference/wfdb_epicmp_af.md)
  for the full compatible procedure).

- `"one_to_one"`: each episode is matched to at most one alarm and each
  alarm to at most one episode. Pairs are eligible when their overlap
  exceeds `min_overlap`. The matching maximises the number of pairs,
  then the total overlap; remaining ties are broken towards pairs that
  occur earlier in time. Because neither episodes nor alarms overlap
  among themselves, the candidate pairs never cross in time, and the
  optimum is found exactly by dynamic programming over the time-ordered
  pairs.

Alarms are classified as `"matched"`, `"redundant"` (overlaps an
eligible episode but was not paired, which happens only under
`"one_to_one"`, e.g. a second alarm during one episode), `"false"` (no
overlap with any reference event), `"ineligible_overlap"` (overlaps only
ineligible episodes), `"unassessable"` (no reference-known time) or
`"learning_period"`.

**Latency** is the time from the episode onset to the issue time of the
first positive decision of the matched alarm inside the episode. It is
reported only when the onset was observed, the detector was answering at
the onset, and `issued_at` was supplied. When the alarm was already
active at the onset (a decision issued before the onset still holds),
latency is not defined and `latency_status` is
`"alarm already active at onset"`. Otherwise `latency` is `NA` and
`latency_status` says why.

## Value

An object of class `tl_match`: a list with `episodes` (one row per
episode and detector), `alarms`, `pairs` and `settings`.

## Examples

``` r
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 time_unit = "min")
m <- tl_match(led)
m$episodes
#>   episode_id record start end event_time n_fragments onset_status offset_status
#> 1  rec1:e001   rec1    10  20         10           1     observed      observed
#> 2  rec1:e002   rec1    40  60         20           1     observed      observed
#>     members detector counted_time eligible eligibility_reason detected
#> 1 rec1:e001        D           10     TRUE               <NA>     TRUE
#> 2 rec1:e002        D           20     TRUE               <NA>    FALSE
#>      alarm_id overlap n_alarms latency         latency_status
#> 1 rec1:D:a001      10        1      NA issued_at not supplied
#> 2        <NA>       0        0      NA           not detected
m$alarms
#>      alarm_id record detector start end positive_time known_time issued_at
#> 1 rec1:D:a001   rec1        D    10  20            10         10        NA
#> 2 rec1:D:a002   rec1        D    70  80            10         10        NA
#>    status episode_id overlap
#> 1 matched  rec1:e001      10
#> 2   false       <NA>       0
```
