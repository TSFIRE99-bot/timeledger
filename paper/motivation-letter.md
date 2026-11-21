---
output: pdf_document
fontsize: 12pt
---

\thispagestyle{empty}
\today

Editor
The R Journal
\bigskip

Dear Editor,
\bigskip

Please consider the article "timeledger: Auditable Time Accounting for
Evaluating Continuous Event Detectors in R" for publication in The R Journal.

Researchers who compare detectors on long recordings, such as arrhythmia
monitors on Holter data, sleep apnea scorers or seizure detectors, have to
decide what to do with time when a detector had no input or declined to
answer. In R, harbinger quietly scores missing detections as "no event", and
yardstick quietly drops them. On the Long Term AF Database the two choices lead to
different conclusions about the same pair of detector policies. timeledger
gives that time its own labels and prints each metric next to its denominator.
Any number can be traced back to the intervals that produced it. Its atrial fibrillation statistics agree with the WFDB reference program
epicmp on all 109 records of two PhysioNet databases.

The package depends only on base R, includes 204 numerical test expectations
and two vignettes, and every number in the article is computed from saved
results in a public reproduction repository.

[Before submission: the package must be on CRAN, and this paragraph should
report the CRAN release date, release history and any outside use. Do not
submit while those facts are missing.]

\bigskip
\bigskip

Regards,

Tejas Menneni
Columbus State Community College
