# Auditable Time Accounting for Evaluating Continuous Event Detectors: The R Package 'timeledger'

Abstract.
Detectors that run continuously on long recordings, such as monitors for atrial fibrillation in 24-hour electrocardiograms, rarely answer for every second. They lose their input, decline to answer when the signal is poor, and split one true event into several alarms. Two detectors evaluated on the same recordings can then report sensitivities computed over different time, and the difference is usually invisible in the published number. The R package timeledger reduces the reference annotations, the input availability and every detector's responses to one table of disjoint half-open intervals per record. Unknown reference, missing input, abstention and a negative answer are separate states, and time without a prediction is never silently counted as negative. Every reported quantity is a sum over that table and carries its numerator, denominator and excluded time, so any number can be traced to the seconds behind it. The package adds an exact one-to-one episode matching rule, paired comparisons on each detector's own, shared and full time, a subject-level bootstrap, and a base R reader for WFDB annotation files whose atrial fibrillation statistics agree with the WFDB program epicmp on all 109 records of two PhysioNet databases. On the Long Term AF Database, a quality-gated policy of a published detector matched the ungated policy on answered time but captured less atrial fibrillation over the full period.




# Introduction

Suppose a recording lasts 100 minutes and has a complete reference rhythm
annotation. Atrial fibrillation (AF) occurs on $[10, 20)$ and $[40, 60)$
minutes. A detector flags $[10, 20)$ and $[70, 80)$, abstains on $[40, 60)$
because the signal looked poor, and answers "no AF" the rest of the time
(Figure 1).

How good is the detector? On the 80 minutes it answered, it flagged all 10
minutes of AF it saw, so its sensitivity is 100%. Over the full period it
flagged 10 of 30 AF minutes, or 33%. It detected one of two AF episodes and
raised one false alarm, which is 0.75 per answered hour. Its predicted AF
burden on answered time is 25%, while the true burden on the same time is
12.5%. Had it answered the 20 abstained minutes, its full-period predicted
burden would lie anywhere between 20% and 40%. All of these statements are
correct, and a paper that reports "sensitivity" without saying which time it
was computed on leaves the reader unable to tell which one was made.

[Figure 1: The 100-minute example. Top lane: reference (dark = AF). Middle lane: detector responses (dark = AF flagged, light = no AF, orange = abstained). Bottom lanes: time used by answered-time metrics and by full-period metrics.]


Real recordings add more ways to lose time. Continuous monitors lose electrode contact,
their beat detectors stop, and quality gates withhold answers during noise.
Reference annotations can begin hours into a recording. When two detectors are
compared on the same recordings, each one's answered time differs, and the
comparison silently depends on what the analyst did with the unanswered time.
Common tools make that choice by default, in opposite directions. The
evaluation function of harbinger [@harbinger] begins by replacing
missing detections with "no event", while the sensitivity function of
yardstick [@yardstick] drops missing estimates by default
(`na_rm = TRUE`). The WFDB program `epicmp`, the reference implementation of
the AF episode statistics in ANSI/AAMI EC38 [@wfdb; @ec38], reads detector
output as rhythm annotations, in which every stretch of time has some rhythm,
so abstention cannot be expressed at all.

The central design decision of timeledger is to build, before any metric is computed, one table per record of disjoint
half-open time intervals that states what was known about each stretch of
time: the reference state (event, non-event, or unknown), whether the monitor
had input (available, unavailable, or unknown), and each detector's response.
The response keeps four situations apart: an actual negative answer, which can
be right or wrong; an abstention, where input was available and the detector
declined; missing input, where no answer was possible; and an unknown response,
where there is no prediction row and the caller did not declare what that
means. Every metric in the package is then a sum over rows of this table, the
*time ledger*, and is reported with its numerator, its denominator and the time
it excludes. Because the ledger is an ordinary data frame, any surprising
number can be traced to the intervals that produced it.

The rest of the article describes existing software, the design of the ledger
and its metrics, episode matching, the interface, an application to two public
long-term AF databases, a transfer to sleep apnea annotations, a comparison with
the strongest conventional R workflow, and performance.

# Existing software

Table 1 summarises the tools inspected for this work, with
versions. The interval algebra itself is well served in R by ivs
[@ivs] and IRanges [@lawrence2013]. Event-detection frameworks such as
harbinger score per-observation detections, optionally with a
tolerance window. Classification metrics in yardstick operate on
vectors of truth and estimate. Outside R, `timescoring`, the scoring library of
the SzCORE seizure-detection framework [@timescoring], and `sed_eval`
[@mesaros2016] score events with tolerances, and pyannote.metrics
[@bredin2017] accepts an evaluation map that restricts the scored region of each
reference file. For AF, `epicmp` [@wfdb] and the scoring program of the China
Physiological Signal Challenge 2021 [@cpsc2021] define reference statistics.
Selective prediction, where a model may abstain, has its own literature on
coverage and selective risk [@geifman2019], but none of the located software
applies it to time-indexed events.

[Table 1]
WFDB epicmp | 10.7.0 | not representable | any overlap
CPSC 2021 scorer | 2021 release | not representable | onset/offset bands
harbinger | 2.1.707 | scored as no event | soft window
yardstick | 1.5.0 | dropped by default | none
ivs / IRanges | 0.2.0 / 2.46.0 | left to the analyst | left to the analyst
timescoring | 0.0.7 | scored as no event | overlap with tolerances
sed_eval | 0.2.1 | scored as no event | collars
pyannote.metrics | docs 2026 | scored region per file | none


None of these tools keeps unanswered time as a category of its own with a
reason, reports each metric with the time it excludes, or compares detectors on
their own, shared and full time while keeping an interval-level record. A
determined analyst can write all of this with ivs; the section on the
conventional workflow below counts the decisions that this requires and shows
two plausible versions that disagree.

# Design

## The ledger

`tl_ledger()` takes four ordinary data frames: the records (one row per record,
with the start and end of its target period), the reference intervals with
their labels, an optional table of input availability, and the predictions,
one row per interval and detector with a response of `"positive"`,
`"negative"` or `"abstain"`. All intervals are half-open, $[start, end)$, in a
time unit declared once. Each record has its own clock, so many records can
start at zero. When sample indices and a sampling frequency are supplied, they
are checked against the times.

For every record the function collects the boundaries of all streams, cuts the
target period at each of them, and finds the covering row of each stream by
binary search (`findInterval()`). It never expands a recording into one row per
sample. The result has one row per elementary interval and detector, with the
reference state and label, a reference episode identifier, the observation
status and its reason, the response, where the response came from
(a prediction row, an unavailable-input declaration, or a declared meaning for
missing rows), the reason for an abstention, the time the decision was issued,
and the row numbers of the source rows. A prediction made while input was
declared unavailable is kept and flagged as a conflict rather than overwritten.

Before building anything, the inputs are validated. Reversed intervals,
overlapping rows with contradictory states, rows that refer to unknown records,
sample indices that are fractional, negative, beyond the end of the record or
inconsistent with the times, and streams that lie entirely outside their
record's target period (a typical symptom of a clock-origin mismatch) are
errors. Exact duplicates, overlapping rows with the same state and rows that
overhang the target period are repaired with a warning. All issues are kept as
an attribute of the ledger. `tl_check()` verifies that, for every record and
detector, the rows are contiguous and sum to the declared target period.

Missing prediction rows deserve their own rule. A gap in a prediction table can
mean that the device was off, that the detector abstained, that it answered
"no event", or simply that nobody knows. timeledger requires the caller
to say which through the argument `missing`, and its default is `"unknown"`.
Missing input is only recorded when an observation table declares it; it is
never inferred from a missing score.

## Metrics and their denominators

Write $K$ for reference-known time, $A$ for the part of it on which the
detector answered, $E$ for reference event time, and $TP$ for event time
flagged positive. The main duration metrics are answer coverage $A/K$,
answered-time sensitivity $TP/E_A$ where $E_A$ is event time during answered
time, and full-period capture $TP/E$, in which unanswered event time counts as
missed and is broken down by its reason. Event burden is reported as the
predicted and reference event fractions on the same answered time, their
difference in percentage points and its size in minutes. The bounds on
full-period predicted burden, $P/T$ and $(P+U)/T$ for positive time $P$,
unanswered time $U$ and target duration $T$, state how much the predicted
burden could change if the unanswered time were filled in with the answered
labels held fixed. They bound the prediction, not the true burden.

Episode metrics come from a matching (next section): episode sensitivity is the
number of detected over eligible reference episodes, and false alarms are
alarms that overlap no reference event, reported per answered hour and per
reference-known hour. Each metric is returned as a row with its numerator,
denominator, unit, excluded time and, when the denominator is zero, the reason
it is undefined. Results are given per record and pooled as ratios of sums,
which weight records by duration; `tl_record_mean()` gives equal-record
summaries. Because every metric is a ratio of additive per-record totals,
`tl_bootstrap()` resamples subjects (never seconds, windows or episodes) and
recomputes pooled metrics from those totals, with the same resampled subjects
for every detector so that differences are paired [@davison1997]. Replicates
with an empty denominator are counted and reported.

`tl_compare()` reports two detectors on each one's own answered time, on the
time when both answered, and over the full period. It also reports how much
reference-known time, event time and how many eligible episodes the shared
comparison discards. The shared restriction is implemented by marking the
excluded rows as reference-unknown with a reason, so the restricted ledger
still sums to the target period and can be inspected like any other.

## Episodes and matching

Reference episodes are maximal runs of event time; a user-supplied episode
identifier is kept when an episode is cut by a gap, so clipping does not create
extra physiological episodes. Each episode records whether its onset was
observed, was already in progress at the start of the recording, or followed
unknown reference time. Alarms are maximal runs of positive response, with
optional merging of close runs and a minimum duration.

The overlap between an episode and an alarm is the ledger time on which both
hold, so intervals that only touch do not overlap. Two named policies are
provided. Under `"any_overlap"`, the rule of `epicmp`, an episode is detected by
any overlapping alarm, and one long alarm can detect several episodes. Under
`"one_to_one"`, each episode and each alarm is used at most once; the matching
maximises the number of pairs, then the total overlap, and remaining ties go to
pairs that occur earlier in time. Episodes are disjoint among themselves and so
are alarms, so the candidate pairs never cross in time and each alarm's pairs
are contiguous once sorted. The optimum then follows from a recursion of the
same form as weighted interval scheduling, which `tl_match()` solves exactly in
linear time after sorting. Alarms that are not matched are classified as
redundant (they overlap an eligible episode already matched), false, overlapping
only ineligible episodes, unassessable (no reference-known time), or inside a
learning period. `tl_explain()` returns the ledger rows behind any alarm or
episode together with the matching decision.

Detection latency is reported only when the onset was observed, the detector
was answering at the onset, and decision times were supplied. It is the time
from the onset to the issue time of the matched alarm's first positive decision
inside the episode. An alarm already active when the episode began has no
latency. `tl_from_windows()` makes the timing of window decisions explicit: a
real-time decision holds from its issue time until the next decision, while a
retrospective decision is assigned to its own window.

## Implementation

The package uses S3 classes on plain data frames (`tl_ledger`, `tl_match`,
`tl_metrics`, `tl_compare`) with `print()`, `summary()` and `plot()` methods, so
results can be handled with any R tooling. It depends only on base R
(graphics, stats, utils). WFDB support lives in a separate
adapter layer: `read_wfdb_ann()` and `write_wfdb_ann()` read and write the MIT
annotation format in base R, `wfdb_rhythm_intervals()` turns rhythm annotations
into reference intervals and labels time before the first rhythm annotation as
`"(unlabelled)"`, and `wfdb_epicmp_af()` reproduces the `epicmp` AF statistics
for the conventions documented in its help page. The tests (tinytest,
@vanderloo2021) contain 204 expectations, including the 100-minute
example above, a fixture in which predicted and true burden are equal while no
AF minute overlaps, and a comparison against an independently written
brute-force implementation that expands random integer timelines to one cell
per time unit and enumerates all matchings.

# Using the package

The workflow has four steps: build and check the ledger, match, compute
metrics, and inspect.

```r
library(timeledger)
fx <- tl_fixture("acceptance")
led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 event = "AF", time_unit = "min")
all(tl_check(led)$ok)
m <- tl_match(led, policy = "one_to_one")
met <- tl_metrics(led, m, level = "pooled")
subset(met, metric %in% c("answer_coverage", "answered_sensitivity",
                          "full_capture", "episode_sensitivity"),
       c(metric, estimate, numerator, denominator))
tl_explain(led, m, episode = "rec1:e002")[, c("start", "end", "response",
                                              "response_reason")]
```


For two detectors, `tl_compare(led, c("A", "B"))` returns both detectors on
own, shared and full time and the discarded time, and
`tl_bootstrap(tl_contributions(led, m), metrics, B = 2000)` gives paired
subject-level intervals. The package vignettes run the same steps on an AFDB
record shipped with the package.

# Application to two long-term AF databases

## Data, detector and analysis plan

The analysis used the MIT-BIH Atrial Fibrillation Database (AFDB,
25 records, 254 hours; @moody1983) and the Long Term AF
Database (LTAFDB, 84 records, 1961 hours; @petrutiu2007),
both from PhysioNet [@goldberger2000; @pollard2026] under the Open Data
Commons Attribution License. Only annotation files were used. Two AFDB records
(00735 and 03665) have no signal files and no
record length in their headers; their target period was declared as ending at
their last annotation. The detector was the RR-interval rule of @dash2009,
with its published thresholds, applied to 128-interval windows of the
databases' unaudited beat annotations every 16 beats, using past beats only.
Policy A answered whenever possible. Policy B used the same detector and
abstained when more than 5% of a window's RR intervals were outside
$[0.3, 2.0]$ s, a beat-series plausibility gate. These are two policies of one
detector. The thresholds were chosen by the original authors on AFDB, so AFDB
results are not independent of threshold selection.

The analysis plan, including detector rules, rhythm mapping, matching
settings, primary outcomes and the bootstrap, was committed to the repository
before any detector was run. One correction was logged before the first full
run: a cap on how long a decision could be held was shorter than the interval
between decisions, so the rule was changed to expire decisions only when beats
stopped for 10 s. The LTAFDB analysis ran after the AFDB analysis, with no
settings changed. The beat streams end before the recordings do (by about 14
minutes in AFDB), and that time was declared as unavailable input. Reference
time before the first rhythm annotation was treated as unknown; it amounts to
25.7 hours in LTAFDB, 18.9
of them in record 64.

## Agreement with epicmp

`epicmp` from WFDB 10.7.0 was compiled from source and run with default
options on every record and policy, with the detector output written as WFDB
test annotations. Its episode counts and durations agreed exactly with
`wfdb_epicmp_af()` in 50 of 50 AFDB comparisons
and 168 of 168 LTAFDB comparisons. A ledger
configured with the same conventions (abstention and unlabelled time counted as
non-AF, a 5-minute learning period, any-overlap matching) reproduced the
executable in 168 of 168 LTAFDB comparisons and in
46 of 50 AFDB comparisons. The four AFDB exceptions are
the two annotation-only records, for which `epicmp` selects no episodes because
the record length is undefined; the ledger, with the declared target period,
scored 8
AF episodes and 105
false alarms for Policy A in those records.

## Results

[Figure 2: Four hours of LTAFDB record 122, the record with the largest difference in answered time between the two policies (chosen by that rule before results were inspected). The window is the 4-hour span with the most Policy B abstention. Lower lanes show the time used by each comparison.]


On LTAFDB, Policy B answered 88.1%
of reference-known time and Policy A 96.7%.
On each policy's own answered time the two had the same sensitivity,
0.947 for A and
0.948 for B (paired
difference 0.001 (95% CI -0.003 to 0.005)), and B
raised fewer false alarms per reference-known hour,
1.66 against
2.84
(difference -1.17 (95% CI -2.81 to -0.13)).
Over the full period B captured less AF:
0.841 against
0.917
(difference -0.076 (95% CI -0.131 to -0.035)). B abstained on
93 hours of AF, against
9 for A (Figure
3).

A comparison restricted to the time when both policies answered shows the two
as identical (sensitivity
0.948 and
0.948), because it discards
230 hours of reference-known time,
117 hours of them AF, and
445 of 2654 eligible
episodes. That comparison is fair for the question "how accurate is each
policy when it answers?", and it removes exactly the periods that separate the
policies for the question "how much AF does each policy find?". The ranking on
false alarms favoured B under every denominator; what changed was the AF time
it missed.

[Figure 3: Pooled estimates with 95% subject-level paired bootstrap intervals (2000 replicates; one record per subject per the database documentation).]


On AFDB the gate rarely fired. Answer coverage was
97.2% for B and
97.7% for A, full-period capture
differed by -0.004 (95% CI -0.012 to -0.001), and B abstained on
32 minutes of AF against
7 for A. In both policies,
109 minutes of AF fell after
the beat stream had ended and were missed with no input, which is why
full-period capture (0.931) is below
answered-time sensitivity (0.950)
even for Policy A.

The matching rule changed the episode results more than the policy did. With
any-overlap matching, Policy A detected
95.7% of eligible LTAFDB episodes; with one-to-one
matching it detected 45.5%.
LTAFDB contains many AF episodes separated by short runs of other rhythms, and
a detector with a 128-beat window holds one alarm across several of them.
The two numbers answer different questions, which is why the package requires
the rule to be named.

Equal-record summaries differed from pooled ones. For Policy A on LTAFDB the
pooled false-alarm rate was
2.84 per
reference-known hour, while the median record had
0.14;
a few records produce most false alarms. Counting the unlabelled time before
the first rhythm annotation as normal rhythm, as `epicmp` does implicitly,
raised Policy A's pooled LTAFDB false-alarm rate from
2.835
to 2.888
per hour.

## A controlled experiment

To check the evaluator's behaviour when input is lost, six 20-minute outages
per record were placed on AFDB in 20 simulated replicates, either at random or,
as a deliberately artificial stress test, starting inside AF. This tests the
evaluation, not whether real devices fail during AF. Answered-time sensitivity
stayed at 0.950 with random outages
and 0.949 with
event-concentrated outages, against 0.950
without outages. Full-period capture fell from 0.931
to 0.745 and 0.654,
and predicted burden on answered time fell from
0.467 to
0.415 under
event-concentrated outages, with bounds widening to
34% to
52%.

# Application to sleep apnea

The engine has no AF-specific code. The Apnea-ECG Database [@penzel2000]
contains 70 overnight records with expert annotations of apnea for
each minute and machine-generated beat annotations. A deliberately simple
detector, fixed before any label was inspected, scored each minute from the
cyclic variation of heart rate in a 5-minute window and abstained when too few
valid beats were available; its decisions are retrospective, issued at the end
of each window. The same calls, with `event = "A"`, gave answer coverage
98.6%, answered-time sensitivity
0.718, full-period capture
0.712 and episode sensitivity
0.593. The per-minute accuracy used by the
original challenge was 0.737 when abstained minutes
count as errors and 0.748 on answered minutes only. The
public description does not say which records come from the same subject, so
intervals were computed by resampling records and are labelled as such. The
accuracy of this detector is not a claim of this work; the example shows that
the evaluation carries over to another binary event stream with its own timing
semantics.

# Comparison with a conventional workflow

The strongest alternative an experienced R user could write combines an
interval library with a page of custom code. The reproduction repository
contains such a workflow, written in base R (the interval sweep it uses is the
operation provided by ivs) and checked against brute-force expansion.
Two analysts were implemented who differ in one decision each. The first
treats any time without a positive answer as "no AF", the default of
harbinger; the second drops unanswered time, the default of
yardstick. Given identical definitions, both reproduce the
corresponding ledger quantities to the last digit. They disagree with each
other on the conclusion: for LTAFDB the first finds Policy B worse
(sensitivity 0.841 against
0.917), and the second finds the
two equal (0.948 against
0.947). Each analyst also uses any-overlap
matching without naming it.

Counting consequential decisions is more informative than counting lines of
code. The workflow required explicit choices about the meaning of missing
prediction rows, abstention, missing input, reference time before the first
rhythm label, atrial flutter, the matching rule, touching intervals, the minimum
episode duration, the learning period, records without a stated length, the
false-alarm exposure, pooled versus equal-record summaries, and the unit of
resampling. Table 2 lists the decisions whose effect was measured on
these data, with the default of each tool. In timeledger each of them is
an argument, a ledger state, or a reported column.

[Table 2]
Meaning of time with no prediction row | no event | dropped | state of previous rhythm annotation | LTAFDB B sensitivity 0.948 with unanswered time dropped vs 0.841 with it scored as no AF
Reference time before first rhythm label | not AF | not AF | not AF | LTAFDB A false alarms per known hour 2.835 (unknown) vs 2.888 (counted as normal)
Atrial flutter | analyst choice | analyst choice | ends AF episode; included in +P unless -x | AFDB A full capture 0.931 (AFL not AF) vs 0.919 (AFL as AF)
Episode matching rule | any overlap | any overlap | any overlap | LTAFDB A episode sensitivity 0.455 (one-to-one) vs 0.957 (any overlap)
Records without a stated length | analyst choice | analyst choice | no episodes selected | AFDB 00735 and 03665: 8 episodes and 105 false alarms scored vs none by epicmp
False-alarm exposure | recording hours | answered hours | not reported | LTAFDB B 1.89 per answered hour vs 1.67 per known hour
Pooled versus equal-record summary | analyst choice | analyst choice | per record | LTAFDB A false alarms per known hour 2.84 pooled vs 0.14 median record


The Python libraries behave similarly on the 100-minute example. With zero
tolerances, `timescoring` and `sed_eval` report sample or segment sensitivity
0.333 and event sensitivity 0.500; abstained
time can only be scored as "no event". The default `timescoring` parameters,
which split events longer than 5 minutes and merge events less than 90 s apart,
change the event sensitivity to 0.333 with
2 false positives. The CPSC 2021 scorer, as distributed,
fails with current NumPy because it uses the removed alias `np.float`.

# Performance

[Figure 4: Elapsed time to build the ledger, match and compute pooled metrics for synthetic records, varying one factor at a time.]


Run time grows with the number of ledger rows, not with recording duration
(Figure 4). A 30-day record with a decision every 10 s
(259,235 rows) took
2.6 s, and a 24-hour record with
400,000 prediction rows took
4.2 s on an
Intel(R) Core(TM) Ultra 7 258V with 31.6 GB of memory under
R version 4.6.2 (2026-10-29 ucrt). The full LTAFDB analysis
(1,205,762
ledger rows for two policies) ran in a few minutes, most of it spent reading
annotation files. A crude alternative that expands a day to one row per second
computes a single ratio faster, but it is exact only at that resolution, keeps
no record of which rows produced a number, and at the 250 Hz sampling rate of
AFDB would need 21,600,000
cells per stream and day.

# Limitations

timeledger is new. It is not yet on CRAN, it has not been used by anyone
other than its author, and the independent-user exercise in the repository has
not been run. The detector in the application is a published rule implemented
without its ectopic-beat filter, applied to unaudited beat annotations, and its
thresholds were derived on AFDB; its performance is not a claim of this work.
Treating the databases' records as independent subjects relies on their
documentation. Input availability in the public data is known only where beat
annotations stop; abstention reasons are those of the detector. The
`epicmp`-compatible mode reproduces a verified subset of `epicmp` behaviour and
does not establish compliance with ANSI/AAMI EC38. Nothing here supports claims
about clinical safety, device performance in deployment or patient outcomes.

The development machine blocked compiled R packages, so the vignettes and this
article were not rendered there, harbinger, yardstick and
ivs were inspected from source rather than executed, and
`R CMD check` was run without building the vignettes or the PDF manual. The
repository includes a continuous-integration workflow that runs the complete
check on three platforms.

# Summary

timeledger turns the bookkeeping of a continuous-monitoring evaluation
into one inspectable table. It keeps unanswered time and its reasons visible,
puts the denominator next to every estimate, makes the episode matching rule an
explicit choice, and reports paired comparisons on the time each question
needs. On LTAFDB, a quality gate that left answered-time sensitivity unchanged and
reduced false alarms lowered full-period AF capture by
8.3%
of its ungated value, and the shared-time comparison that hid this discarded
16.8% of the
eligible episodes. The package, the analysis code and every saved result
behind the numbers in this article are available in the reproduction
repository.

# Acknowledgements and use of generative AI

The author used Claude (Anthropic), a large language model, to help write the
package code, tests, analysis scripts and a draft of this manuscript. The author
reviewed, ran and edited all code and text and takes responsibility for the
content.
