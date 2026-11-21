# Full analysis of one database, as specified in ANALYSIS_PLAN.md.
# Usage: Rscript analysis/run_database.R afdb|ltafdb [rawdata_dir]
args <- commandArgs(TRUE)
db_name <- args[1]
raw <- if (length(args) > 1) args[2] else "rawdata"
source("analysis/common.R")
out <- file.path("results", db_name)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
timing <- list()
tic <- function(k) timing[[k]] <<- Sys.time()
dir <- file.path(raw, db_name)

tic("load")
db <- load_database(dir)
write.csv(db$inclusion, file.path(out, "inclusion.csv"), row.names = FALSE)
tic("ledger")
led <- tl_ledger(db$records, db$reference, db$predictions, db$observation,
                 event = "(AFIB", unknown = "(unlabelled)", time_unit = "s")
chk <- tl_check(led)
stopifnot(all(chk$ok))
write.csv(chk, file.path(out, "ledger_check.csv"), row.names = FALSE)
iss <- attr(led, "issues")
write.csv(iss, file.path(out, "validation_issues.csv"), row.names = FALSE)
sm <- summary(led)
write.csv(sm, file.path(out, "ledger_state_totals.csv"), row.names = FALSE)
rs <- summary(led, by = c("response", "response_reason"))
write.csv(rs, file.path(out, "response_reasons.csv"), row.names = FALSE)

tic("match")
m1 <- tl_match(led, policy = "one_to_one", min_episode_time = 30)
m2 <- tl_match(led, policy = "any_overlap", min_episode_time = 30)
met1 <- tl_metrics(led, m1)
met2 <- tl_metrics(led, m2, level = "pooled")
write.csv(as.data.frame(met1), file.path(out, "metrics_primary.csv"), row.names = FALSE)
write.csv(as.data.frame(met2), file.path(out, "metrics_any_overlap.csv"), row.names = FALSE)
write.csv(tl_record_mean(met1), file.path(out, "metrics_record_mean.csv"), row.names = FALSE)
write.csv(m1$alarms, file.path(out, "alarms_primary.csv"), row.names = FALSE)
write.csv(m1$episodes, file.path(out, "episodes_primary.csv"), row.names = FALSE)

tic("compare")
cmp <- tl_compare(led, c("A_answer", "B_quality"), policy = "one_to_one",
                  min_episode_time = 30)
write.csv(cmp$table, file.path(out, "compare_table.csv"), row.names = FALSE)
write.csv(cmp$discarded, file.path(out, "compare_discarded.csv"), row.names = FALSE)
write.csv(as.data.frame(cmp$shared), file.path(out, "metrics_shared.csv"), row.names = FALSE)

tic("bootstrap")
boot_metrics <- c("full_capture", "false_alarms_per_known_hour", "answer_coverage",
                  "episode_sensitivity", "burden_diff_pp", "answered_sensitivity")
cb <- tl_contributions(led, m1)
write.csv(cb, file.path(out, "contributions.csv"), row.names = FALSE)
bt <- tl_bootstrap(cb, boot_metrics, B = 2000, seed = 20261120)
bt_rm <- tl_bootstrap(cb, boot_metrics, B = 2000, seed = 20261120,
                      summary = "record_mean")
write.csv(bt, file.path(out, "bootstrap_pooled.csv"), row.names = FALSE)
write.csv(bt_rm, file.path(out, "bootstrap_record_mean.csv"), row.names = FALSE)
cbs <- tl_contributions(cmp$shared_ledger, cmp$shared_match)
bts <- tl_bootstrap(cbs, c("answered_sensitivity", "false_alarms_per_known_hour",
                           "burden_diff_pp"), B = 2000, seed = 20261120)
write.csv(bts, file.path(out, "bootstrap_shared.csv"), row.names = FALSE)

tic("sensitivity")
s1 <- tl_ledger(db$records, db$reference, db$predictions, db$observation,
                event = c("(AFIB", "(AFL"), unknown = "(unlabelled)")
ref2 <- db$reference
ref2$label[ref2$label == "(unlabelled)"] <- "(N"
s2 <- tl_ledger(db$records, ref2, db$predictions, db$observation,
                event = "(AFIB", unknown = "(unlabelled)")
sens <- rbind(
  cbind(analysis = "primary", tl_get(met1, boot_metrics)),
  cbind(analysis = "S1: AFL counted as AF",
        tl_get(tl_metrics(s1, tl_match(s1, min_episode_time = 30)), boot_metrics)),
  cbind(analysis = "S2: unlabelled time counted as (N",
        tl_get(tl_metrics(s2, tl_match(s2, min_episode_time = 30)), boot_metrics)))
write.csv(sens, file.path(out, "sensitivity_analyses.csv"), row.names = FALSE)

tic("epicmp")
exe <- normalizePath("comparators/epicmp/bin/epicmp.exe")
ep <- run_epicmp_check(db, dir, exe, file.path(tempdir(), paste0("epicmp_", db_name)))
write.csv(ep, file.path(out, "epicmp_check.csv"), row.names = FALSE)

# timeledger configured to the epicmp conventions, for the same records.
pe <- db$predictions
pe$response[pe$response == "abstain"] <- "negative"
le <- tl_ledger(db$records, ref2, pe, NULL, event = "(AFIB", unknown = "(unlabelled)")
le <- tl_split(le, 300)
le <- tl_restrict(le, le$start >= 300, "epicmp learning period (first 5 min)")
me <- tl_match(le, policy = "any_overlap")
cbe <- tl_contributions(le, me)
conv <- merge(ep, data.frame(record = cbe$record, detector = cbe$detector,
                             tl_STP = cbe$episodes_detected,
                             tl_FN = cbe$episodes_eligible - cbe$episodes_detected,
                             tl_PTP = cbe$alarms_matched, tl_FP = cbe$alarms_false,
                             tl_ref_overlap_s = cbe$tp, tl_ref_duration_s = cbe$event,
                             tl_test_duration_s = cbe$positive_known),
              by = c("record", "detector"))
write.csv(conv, file.path(out, "epicmp_vs_timeledger_conventions.csv"), row.names = FALSE)

tic("exhibit")
rec_unknown <- db$inclusion$record[which.max(db$inclusion$unlabelled_h)]
ans <- cb[, c("record", "detector", "answered")]
wide <- reshape(ans, idvar = "record", timevar = "detector", direction = "wide")
rec_ab <- wide$record[which.max(abs(wide$answered.A_answer - wide$answered.B_quality))]
exhibit <- list(record_largest_unknown = rec_unknown, record_largest_AB_gap = rec_ab)
saveRDS(list(ledger = led[led$record %in% c(rec_unknown, rec_ab), ],
             match = m1, compare_discarded = cmp$discarded, exhibit = exhibit),
        file.path(out, "exhibit.rds"))
saveRDS(led, file.path(out, "ledger.rds"))
saveRDS(list(m1 = m1, cmp = cmp), file.path(out, "match_compare.rds"))
tic("end")
tt <- diff(do.call(c, timing))
units(tt) <- "secs"
dput(list(session = session_record(), exhibit = exhibit,
          seconds = setNames(as.numeric(tt), names(timing)[-1]),
          n_ledger_rows = nrow(led)),
     file.path(out, "session.txt"))
cat("done", db_name, "rows:", nrow(led), "\n")
print(round(setNames(as.numeric(tt), names(timing)[-length(timing)]), 1))
