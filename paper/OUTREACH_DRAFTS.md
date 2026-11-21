# Release and outreach drafts (nothing has been sent or posted)

The decisions to release, to contact anyone and to submit are the author's.
These are drafts only.

## Release checklist

1. Choose the public repository host and replace `OWNER` in
   `timeledger/DESCRIPTION` (URL, BugReports) and the maintainer email
   placeholder.
2. Push the package. The GitHub Actions check should pass on all four
   configurations; it also builds the vignettes and the PDF manual.
3. Run `R CMD check --as-cran` on win-builder and R-hub.
4. Submit to CRAN, and send the article to the journal only after CRAN has
   accepted the package.
5. Archive the reproduction repository with a DOI (for example on Zenodo) and
   cite that exact version in the article.

## Short announcement (for a mailing list, forum or social post)

> timeledger is a new R package for evaluating detectors that run on long
> recordings and do not always answer. It splits each recording into
> intervals that say what the reference was, whether the device had input and
> what each detector answered, and computes every metric from that table with
> its denominator attached. It also matches episodes to alarms under a named
> rule and compares two detectors on each one's own time, shared time and the
> full period. Base R only. Feedback and use cases are welcome: [link]

## Message to a researcher who evaluates continuous detectors

> Dear Dr. [name],
>
> I read your paper on [topic] and noticed that you report performance on the
> time your system scored. I have written an R package, timeledger, that
> computes the same quantities while keeping unscored time and its reasons
> visible, and compares systems on their own, shared and full time. If you have
> a few minutes, I would value your view on whether it would have helped with
> your evaluation, and on what is missing. A two-page example is here: [link].
>
> With thanks,
> Tejas Menneni
