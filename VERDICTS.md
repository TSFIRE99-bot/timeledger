# Two verdicts (2026-11-20)

## 1. Software complete: yes, with three checks still to run elsewhere

What is done and verified on the development machine:

* Installable source package `timeledger` 0.1.0, base R only, 28 exported
  functions, all documented with examples.
* 204 numerical test expectations, all passing (`results/tests_summary.csv`):
  the mandatory 100-minute fixture, the zero-overlap burden fixture, every edge
  case in the specification, shift/split/shuffle invariants, input validation,
  WFDB round trips, and an independent brute-force implementation compared on
  300 random timelines with zero disagreements.
* `R CMD check`: Status OK (`results/R_CMD_check.log`), run with
  `--no-manual --ignore-vignettes` because LaTeX and knitr could not run here.
* The epicmp-compatible mode agrees with the compiled WFDB 10.7.0 `epicmp`
  executable in 218 of 218 record-by-policy comparisons.
* Both vignettes' code runs end to end (`tools/run_vignette_code.R`).
* Frozen analysis plan, versioned data manifest with SHA-256 for 539 files,
  executable comparator scripts, benchmarks with machine specification, and a
  single reproduction script (`reproduce.sh`).

Not yet verified, because this machine blocks compiled R packages:

1. Rendering the two vignettes and the PDF manual (`R CMD check --as-cran`
   with no skips). The CI workflow in `timeledger/.github/workflows` does this.
2. Rendering the article with rjtools (page count, figure placement, the
   rjtools `initial_check_article()` checks).
3. Executing harbinger, yardstick and ivs themselves; the audit read their
   source code instead.

## 2. Ready for The R Journal: no

The journal's own requirements and its listed reasons for desk rejection
(journal.r-project.org/submissions.html, read 2026-11-20) decide this. The
missing evidence, precisely:

1. **CRAN availability.** Required for consideration. The package has not been
   submitted. Needs: public repository, CI passing on all platforms, CRAN
   acceptance.
2. **Maturity and maintenance.** The journal names "length of time on CRAN,
   release history, recent updates, and ongoing development activity" as
   desk-rejection grounds. The package is one day old with one version.
   Needs: time on CRAN and at least one maintenance release responding to
   real issues.
3. **Demonstrated use by others.** Required ("citations in publications, use
   in applied or research work, use in downstream analyses, or adoption by
   other packages"). There is none. The independent-user exercise in
   `paper/USER_EXERCISE.md` is prepared but has not been run, and no outside
   person has seen the package. Needs: at least one genuine outside user or
   use case, reported separately from internal testing.
4. **Credible second application from outside the author's own work.** The
   sleep-apnea transfer uses real expert annotations but a detector written
   here. Needs: an external researcher's detector output in a non-AF domain.
5. **Public reproducibility.** Everything is in a local git repository only.
   Needs: a public repository and an archived version with a DOI, and a
   reviewer-time check that the reproduction runs within the journal's
   10-minute guidance (the full LTAFDB analysis takes longer; the article reads
   saved results, which the journal allows, but this should be stated).
6. **Rendered article.** The rjtools PDF/HTML has not been produced, so the
   20-page limit and the rjtools checks are unverified. The prose is about
   4,100 words with four figures and one table, which should fit.

What is defensible already: the comparison with the best existing workflows
(executable, with a decision inventory and measured consequences), the
verified agreement with the reference AF implementation, and real-data
results on two corpora with a pre-registered plan, including a result that
matters to the user story (a quality gate that looks neutral on answered time
costs 7.6 points of full-period AF capture on LTAFDB, and the shared-time
comparison hides it by discarding 16.8% of eligible episodes).

The honest summary: the software and the evidence about its behaviour are
strong enough to support a submission later. The evidence about adoption and
maturity that the journal asks for cannot be produced by writing more; it
needs time, a CRAN release and outside users.
