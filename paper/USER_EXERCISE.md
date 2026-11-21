# Independent-user exercise (not yet run)

Status: prepared, not run. No outside person has used the package. Results of
this exercise must be recorded separately from internal testing, and only
after it has actually been run.

## Participant

An R user who has not seen the package or this repository, ideally someone who
evaluates detectors or classifiers in their own work. Note how many years they
have used R and in what field, but leave out their name unless they say you
may use it.

## Materials

* The installed package (`R CMD INSTALL timeledger_0.1.0.tar.gz`).
* The package help pages and the two vignettes, nothing else.
* LTAFDB record 122: `rawdata/ltafdb/122.hea`, `122.atr`, `122.qrs`.
* The two policies' predictions for that record, extracted with
  `analysis/common.R` and saved as `exercise/predictions_122.csv`, without
  being told which policy abstains more.

## Tasks (give them in this order, one at a time)

1. Build a ledger for record 122 with both policies and check that it adds up.
2. Compare the two policies. Which is better, and by what measure?
3. Explain in one or two sentences why their full-period AF capture differs
   while their answered-time sensitivity does not.
4. Pick any false alarm of Policy B and show the exact time intervals behind it.
5. Find out how much AF time the shared-time comparison leaves out.

## What to record

* Time to complete each task, and whether it was completed without help.
* Every point where they got stuck, the help page or error message they were
  reading at that moment, and what they tried.
* Any result they misread (for example, reading answered-time sensitivity as
  full-period sensitivity).
* Their own words on what they would change.

## After the session

Write each sticking point as an issue in the tracker, change the package or
documentation, and note in NEWS.md which changes came from user feedback.
