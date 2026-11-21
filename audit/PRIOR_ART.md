# Prior-art audit

Audit date: 2026-11-20 (UTC-5). Each entry states what was inspected, how, and
what it does and does not do for the user story below. "Not found" means that a
search did not locate the feature; it is not proof that the feature is absent.

## User story

An analyst has reference rhythm annotations and predictions from two continuous
monitors. The monitors cover different portions of the same recordings,
sometimes abstain, and may split one true event into several alarms. The
analyst wants to compare performance over each monitor's answered time, over
time when both answered, and over the full period with known reference rhythm,
and to inspect the exact intervals behind any surprising number.

## Environment constraint that shaped this audit

On the development machine (Windows 11, R 4.6.2), the operating system's
application control policy blocked every compiled CRAN package DLL. R packages
with compiled code (including ivs, IRanges, yardstick, harbinger, data.table,
testthat, knitr, rmarkdown, rjtools, bench) could be installed but not loaded.
For those packages the audit reads the released source code; it does not
execute them. Python packages and locally compiled C programs did run.

## Inspected tools

| Tool | Version, date, license | How inspected | Relevant behaviour | Gap for the user story |
|---|---|---|---|---|
| WFDB `epicmp` (C) | WFDB 10.7.0 (source `app/epicmp.c`, last revised 24 Apr 2020), GPL-2+ | Source read; compiled from source with zig 0.17.1 (`x86_64-windows-gnu`); run on all 25 AFDB and 84 LTAFDB records under two detector policies | Reference implementation of the EC38 AF episode and duration statistics: 5-minute learning period, any positive overlap is a match (not one-to-one), AF ends at any other rhythm label (so AFL ends AF), unterminated episodes end at the record end; with an undefined record length it selects no episodes | Test annotations are rhythm states, so abstention and missing input cannot be represented; no notion of a per-system scored region; no per-interval audit output; records without a header length are silently empty (observed on AFDB 00735 and 03665) |
| CPSC 2021 `score_2021.py` | GitHub CPSC-Committee/cpsc2021-python-entry, retrieved 2026-11-20 | Source read; run on a synthetic record | Scores onset/offset positions within beat-based tolerance bands plus a record-level class; AF and AFL pooled | No abstention or coverage; fails on NumPy >= 1.24 (`np.float`), observed with NumPy 2.5.5 |
| harbinger (R) | 2.1.707, CRAN 2026-07-10, MIT | Source read (`R/har_eval.R`, `R/har_eval_soft.R`) | Per-observation confusion counts; `evaluate.har_eval` begins `detection[is.na(detection)] <- FALSE`; soft evaluation with a tolerance window | Missing predictions are silently scored as "no event"; per-sample input (a 24-hour 250 Hz record needs 21.6 million rows per stream); no episodes, no abstention, no scored-region accounting |
| yardstick (R) | 1.5.0, CRAN, MIT | Source read (`R/class-sens.R`) | Classification metrics on vectors; `na_rm = TRUE` by default strips missing estimates | Missing predictions are silently dropped, which reports answered-time sensitivity under the name sensitivity; no time, episodes or coverage |
| ivs (R) | 0.2.0, CRAN 2023-03, MIT | Source and documentation read | Right-open interval vectors with overlap location and set operations | Provides the interval algebra but none of the evaluation decisions; all of them must be written by the analyst (see `comparators/conventional_workflow.R`) |
| IRanges (Bioconductor) | 2.46.0, Artistic-2.0 | Documentation | Integer ranges, `findOverlaps`, set operations | Same as ivs; integer coordinates |
| timescoring (Python, SzCORE) | 0.0.7, PyPI | Installed and run on the 100-minute fixture | Sample and event scoring with start/end tolerances, minimum overlap, splitting of long events (default 5 min) and merging of close events (default 90 s); false positives per 24 h over the whole recording | Abstained time can only be scored as "no event"; defaults change answers (event sensitivity 1/2 with zero tolerances, 1/3 with defaults); no per-system scored region |
| sed_eval (Python, DCASE) | 0.2.1, PyPI | Installed and run on the fixture (needed setuptools < 81 for `pkg_resources` on Python 3.13) | Segment- and event-based metrics with collars | No abstention or scored region per system; `t_collar` must be > 0 |
| pyannote.metrics (Python) | Documentation retrieved 2026-11-20 | Documentation read | Every metric accepts a `uem` timeline restricting the scored region; detailed components returned | Scored region is per reference file, not per system; no abstention reasons, no answered-versus-full comparison, no burden bounds |

## Searches with no tool found

CRAN, Bioconductor and web searches (2026-11-20) for: selective prediction,
abstention, reject option, risk-coverage evaluation; monitoring coverage and
answered-time denominators; event-based evaluation with per-system scored
regions; alarm burden per exposure; interval scoring for continuous monitors.
Results: method papers (e.g. SelectiveNet, deep selective classification
benchmarks), a 2011 gene-expression reject-option paper, fairness
post-processing (aif360 reject option classification), and the event-detection
packages listed above. No R package was found that combines per-system
answered time, abstention reasons, episode matching and paired comparison.
This is a failure to locate, not proof of absence.

## Where two plausible implementations disagree (executed)

`comparators/conventional_workflow.R` implements two analysts who differ in one
decision each about unanswered time (`conv_fill`, the harbinger default;
`conv_drop`, the yardstick default). On LTAFDB with the frozen detector:

* Policy B looks equal to Policy A under `conv_drop` (sensitivity 0.948 vs
  0.947) and clearly worse under `conv_fill` (0.841 vs 0.917).
* Episode sensitivity is 0.957 under any-overlap matching and 0.455 under
  one-to-one matching for the same alarms (Policy A).

See `results/comparators/conventional_vs_timeledger.csv` and
`results/comparators/decision_inventory.csv`.

## Conclusion of the audit

The interval algebra is available (ivs, IRanges), the reference AF statistics
are available (epicmp), and several toolkits score events. None that was
located keeps unanswered time as its own category with a reason, reports a
metric together with the time it excludes, and supports a paired comparison on
own, shared and full time with an interval-level audit trail. That combination
is the contribution claimed for timeledger. It remains a claim that reviewers
can test, and it would fail if a maintained tool doing this were found.
