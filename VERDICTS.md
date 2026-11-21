# Two verdicts (updated 2026-11-21)

## 1. Software complete: yes

Verified, not assumed:

* `R CMD check --as-cran`, including vignettes and the PDF manual, on GitHub
  Actions: Ubuntu (R release and R devel), macOS and Windows (R release). See
  the R-CMD-check workflow of the latest commit.
* 229 numerical test expectations, all passing, covering the mandatory
  100-minute fixture, the zero-overlap burden fixture, every edge case in the
  specification, shift/split/shuffle invariants, input validation, WFDB round
  trips, print/plot methods, and an independent brute-force implementation
  compared on 300 random timelines. Test coverage 92.3% (covr, in the
  pkgdown-coverage workflow). The check ends with Status: 1 NOTE (the HTML
  manual check skips HTML Tidy and math rendering, which the runner lacks).
* The epicmp-compatible mode agrees with the compiled WFDB 10.7.0 `epicmp` in
  218 of 218 record-by-policy comparisons.
* harbinger 2.1.707, yardstick 1.5.0 and ivs 0.2.0 were executed in CI on the
  same inputs (`results/comparators/r_toolkits.csv`).
* The article renders with rjtools to 9 pages and passes every rjtools
  structural check (file names, title case, sentence-case sections, plain-text
  abstract, motivation letter, cited packages available). The one remaining
  note is that the package is not yet on CRAN.
* Documentation website built by pkgdown (served once the repository is
  public), CITATION file, NEWS, cran-comments.md, a frozen analysis plan,
  a SHA-256 data manifest and a single reproduction script.

## 2. Ready for The R Journal: not yet

The R Journal's requirements (journal.r-project.org/submissions.html) make
the following non-negotiable, and none of them can be produced by more writing
or more code in this repository:

1. **CRAN availability.** Required for consideration. Ready to submit: make
   the repository public, run win-builder, upload at cran.r-project.org/submit.html
   and click the confirmation email (steps in SUBMISSION.md). Only the
   maintainer can do this.
2. **Maturity.** Desk-rejection reasons include short time on CRAN, little
   release history and no ongoing development. Needs months on CRAN and at
   least one maintenance release that answers real issues.
3. **Demonstrated use by others.** Needs at least one genuine outside user or
   downstream use, reported separately from internal testing. The exercise in
   `paper/USER_EXERCISE.md` and the drafts in `paper/OUTREACH_DRAFTS.md` are
   ready; nobody outside has used the package yet.
4. **A second application from outside the author's own work** would make the
   transfer claim much stronger than the apnea example with a detector written
   here.

What is already as strong as the journal could ask: an executed comparison
with the most relevant R packages showing that they silently answer different
questions under the same name; agreement with the reference AF implementation;
results on two public corpora under a plan committed before any detector ran;
and a rendered article that passes the journal's own checks.

Honest bottom line: the software and the article are in submission shape. The
acceptance odds now depend on the CRAN release, time, and real users, in that
order. Submitting before those exist would most likely end in desk rejection
for the reasons the journal itself lists.
