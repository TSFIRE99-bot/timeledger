# Run the rjtools submission checks one at a time, so that one failing check
# does not hide the others. rjtools 1.0.18.1's check_spelling() stops with an
# error on articles produced by its own R Markdown template (it looks for a
# "\section*{References}" line that the template does not write), so spelling
# is checked with the spelling package instead.
# Usage: Rscript tools/rj_checks.R paper
path <- commandArgs(TRUE)[1]
unlink(Sys.glob(file.path(path, c("*.log", "*.aux", "*.out"))))
checks <- c("check_wrappers", "check_filenames", "check_unnecessary_files",
            "check_cover_letter", "check_title", "check_section",
            "check_abstract", "check_proposed_pkg", "check_packages_available")
for (ch in checks) {
  f <- get0(ch, envir = asNamespace("rjtools"))
  if (is.null(f)) next
  cat("\n--", ch, "\n")
  tryCatch(if (ch == "check_proposed_pkg") f("timeledger") else f(path),
           error = function(e) cat("check stopped with an error:", conditionMessage(e), "\n"))
}
cat("\n-- spelling (spelling package, en-US)\n")
words <- spelling::spell_check_files(file.path(path, "timeledger.Rmd"), lang = "en-US",
                                     ignore = readLines(file.path(path, "WORDLIST")))
print(words)
