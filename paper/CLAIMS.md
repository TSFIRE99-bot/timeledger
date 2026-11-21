# Claim-to-evidence table

Every claim in `paper/timeledger.Rmd` about accuracy, usability, efficiency or
novelty, with the file or executable calculation that supports it. "Status"
says whether the evidence was produced and checked in this repository.

| # | Claim (section) | Evidence | Status |
|---|---|---|---|
| 1 | The 100-minute example gives coverage 80%, answered sensitivity 100%, capture 1/3, episodes 1/2, one unmatched alarm, 0.75 false alarms per answered hour, burden 25% vs 12.5%, bounds 20% to 40% (Introduction) | `timeledger/inst/tinytest/test_acceptance.R` | passing (results/tests_summary.csv) |
| 2 | harbinger replaces missing detections with "no event" (Introduction, Existing software) | harbinger 2.1.707 source, `R/har_eval.R` line 51; tarball SHA-256 cc9c89c6... | read, not executed |
| 3 | yardstick sensitivity drops missing estimates by default (same) | yardstick 1.5.0 source, `R/class-sens.R`, `na_rm = TRUE`; tarball SHA-256 95ae54b1... | read, not executed |
| 4 | epicmp cannot represent abstention; any overlap is a match; AFL ends AF; 5-min learning period; undefined length selects nothing | WFDB 10.7.0 `app/epicmp.c`; executable runs in `results/*/epicmp_check.csv`; test `test_wfdb.R` | executed |
| 5 | No located tool combines per-system answered time, abstention reasons, matching and paired comparison (Existing software) | `audit/PRIOR_ART.md` (searches listed; failure to locate is not proof of absence) | audit, falsifiable |
| 6 | Ledger never expands to samples; validation catches the listed input errors | `R/ledger.R`, `R/validate.R`; `test_validation.R`, `test_edge_cases.R` | passing |
| 7 | One-to-one matching is exact | DP in `R/match.R`; exhaustive search in `test_bruteforce.R` (300 random timelines, 0 mismatches) | passing |
| 8 | 204 test expectations | `results/tests_summary.csv` | generated |
| 9 | Data: 25 AFDB records (254 h), 84 LTAFDB records (1961 h); two AFDB records without signals or length | `results/*/inclusion.csv`; `data-raw/MANIFEST.csv` (SHA-256 of every file) | generated |
| 10 | Detector thresholds are those of Dash et al. (2009), Table 1, selected on AFDB | paper PDF, Table 1 (retrieved 2026-11-20); `analysis/common.R` | checked against source |
| 11 | Analysis plan committed before any detector run; one logged correction; LTAFDB after AFDB with no setting changes | git history: plan commit 2b30505 precedes runner and results commits; change log in `analysis/ANALYSIS_PLAN.md` | verifiable in git |
| 12 | epicmp agreement 50/50 (AFDB) and 168/168 (LTAFDB); ledger with epicmp conventions 46/50 and 168/168; exceptions are 00735 and 03665 | `results/*/epicmp_check.csv`, `results/*/epicmp_vs_timeledger_conventions.csv` | executed |
| 13 | LTAFDB: B coverage 88.1% vs A 96.7%; answered sensitivity 0.948 vs 0.947; false alarms 1.66 vs 2.84; capture 0.841 vs 0.917, difference -0.076 (CI -0.131 to -0.035); 93 h vs 9 h AF abstained | `results/ltafdb/bootstrap_pooled.csv`, `compare_table.csv` | generated |
| 14 | Shared comparison discards 230 h known time, 117 h AF, 445 of 2654 episodes | `results/ltafdb/compare_discarded.csv` | generated |
| 15 | Episode sensitivity 95.7% (any overlap) vs 45.5% (one-to-one), LTAFDB, Policy A | `results/ltafdb/metrics_any_overlap.csv`, `bootstrap_pooled.csv` | generated |
| 16 | Pooled 2.84 vs record median 0.14 false alarms per known hour | `results/ltafdb/metrics_record_mean.csv` | generated |
| 17 | Unlabelled time as (N raises false alarms 2.835 to 2.888 | `results/ltafdb/sensitivity_analyses.csv` | generated |
| 18 | Records are independent subjects | database documentation (assumption, stated in text) | assumption |
| 19 | Simulated outages: answered sensitivity unchanged, capture 0.931 to 0.745 / 0.654 | `results/simulation/outages_afdb_summary.csv` | generated (simulated) |
| 20 | Apnea-ECG transfer numbers; record-level resampling | `results/apnea/*.csv`; detector rule committed before first run (git) | generated |
| 21 | Conventional analysts disagree: 0.841 vs 0.917 (fill) and 0.948 vs 0.947 (drop) | `results/comparators/conventional_vs_timeledger.csv` | executed |
| 22 | Decision inventory and measured consequences | `results/comparators/decision_inventory.csv` | compiled from rows above |
| 23 | timescoring/sed_eval values on the fixture; CPSC scorer fails on NumPy 2.5.5 | `results/comparators/python_comparators.json` | executed |
| 24 | Runtime: 30-day record 2.6 s; 400k rows 4.2 s; 1,205,762 LTAFDB ledger rows; machine | `results/benchmarks/scaling.csv`, `machine.txt`, `results/ltafdb/session.txt` | generated |
| 25 | Package depends only on base R; R CMD check status OK without vignettes and manual | `timeledger/DESCRIPTION`; `results/R_CMD_check.log` | generated (partial check) |
| 26 | Vignette code runs | `tools/run_vignette_code.R` output (chunks executed, rendering not done) | executed, not rendered |
| 27 | Not on CRAN; no outside users | statement of fact | true at time of writing |
