# Path from here to an R Journal submission

Steps are in order. Each step says who does it. Steps marked "you" send
something under your name or need your email; they cannot be done for you.

## 1. Make the repository public (you, one click)

GitHub > TSFIRE99-bot/timeledger > Settings > General > Danger zone > Change
visibility > Public. CRAN checks the URL and BugReports links in DESCRIPTION,
and the journal requires public code and data. Before doing this, decide
whether TSFIRE99-bot is the account you want permanently attached to the
package; transferring later breaks links in the published record.

## 2. Pre-submission checks (you upload, results come to your email)

1. Build the source tarball (on any machine where R packages load, or download
   it from the CI artifact):
   `R CMD build timeledger`
2. Upload `timeledger_0.1.0.tar.gz` at https://win-builder.r-project.org/upload.aspx
   (R-devel). Results arrive at the maintainer email within about 30 minutes.
3. Fix anything other than the "New submission" note.
4. Update `timeledger/cran-comments.md` with the win-builder result.

## 3. CRAN submission (you)

1. Go to https://cran.r-project.org/submit.html and upload the tarball and the
   contents of `cran-comments.md`.
2. Click the confirmation link CRAN emails to the maintainer address.
3. Answer reviewer requests promptly; first-submission review often asks for
   small changes (for example `\value` sections or example run times). Resubmit
   with the version number unchanged unless asked otherwise.

## 4. Build the record the journal asks for (you, over months)

The journal lists these as reasons for desk rejection when missing:

* Time on CRAN and a release history: plan at least one maintenance release
  (0.1.1 or 0.2.0) that responds to real issues or feedback.
* Demonstrated use by others: run the exercise in `paper/USER_EXERCISE.md`
  with at least one outside R user; invite researchers who evaluate continuous
  detectors (drafts in `paper/OUTREACH_DRAFTS.md`); record genuine use only.
* A second application from outside your own work: ask one such researcher for
  permission to show their detector output in a non-AF domain.

## 5. Archive and submit the article (you)

1. Done: archived on Zenodo, all-versions DOI 10.5281/zenodo.24489065
   (version 0.1.0 record 10.5281/zenodo.24489181), cited in the article.
2. Update the article: CRAN version, release history, any outside use, and
   remove `draft: true`.
3. Check the rendered PDF from the `render-article` CI artifact (20-page limit,
   abstract under 250 words) and run `rjtools::initial_check_article("paper")`.
4. Re-run the AI-detector check and keep the generative-AI disclosure accurate.
5. Zip the paper folder, results and `_Rpackages.txt`, and submit through the
   form at https://journal.r-project.org/submissions.html with the motivation
   letter.
