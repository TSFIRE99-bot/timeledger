# Extract and run the R chunks of each vignette (eval = FALSE and
# include = FALSE chunks are skipped). Used where knitr cannot be loaded; on a
# normal machine, R CMD build renders the vignettes.
# Usage: Rscript tools/run_vignette_code.R file1.Rmd [file2.Rmd ...]
args <- commandArgs(TRUE)
for (f in args) {
  x <- readLines(f, warn = FALSE)
  starts <- grep("^```[{]r", x)
  ends <- grep("^```[[:space:]]*$", x)
  code <- character()
  for (s in starts) {
    e <- ends[ends > s][1]
    if (grepl("eval[[:space:]]*=[[:space:]]*FALSE", x[s]) ||
        grepl("include[[:space:]]*=[[:space:]]*FALSE", x[s])) next
    code <- c(code, x[(s + 1):(e - 1)])
  }
  cat("==== ", f, " (", length(code), " lines)\n", sep = "")
  grDevices::pdf(NULL)
  env <- new.env()
  for (ex in parse(text = code)) {
    res <- withVisible(eval(ex, env))
    if (res$visible) print(res$value)
  }
  grDevices::dev.off()
  cat("==== OK ", f, "\n", sep = "")
}
