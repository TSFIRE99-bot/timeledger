## Submission

This is a new submission.

## Test environments

* GitHub Actions: ubuntu-latest (R release and R devel), windows-latest (R
  release), macos-latest (R release), `R CMD check --as-cran` with vignettes
  and the PDF manual.
* Local: Windows 11, R 4.6.2.
* win-builder (R devel): [to be run before submission]

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission.

## Notes for CRAN

* The package depends only on base R (graphics, stats, utils).
* `inst/extdata` contains three small annotation files (about 90 kB) of one
  record of the MIT-BIH Atrial Fibrillation Database, redistributed under the
  Open Data Commons Attribution License v1.0; provenance is documented in
  `data-raw/README.md`.
* All examples run in well under 5 seconds; the tests run in about 10 seconds.
