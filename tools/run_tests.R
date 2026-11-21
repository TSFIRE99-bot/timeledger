# Run the installed package's tinytest suite and save a summary.
# Usage: Rscript tools/run_tests.R
library(tinytest)
library(timeledger)
r <- run_test_dir(system.file("tinytest", package = "timeledger"), verbose = 0)
d <- as.data.frame(r)
s <- aggregate(cbind(results = rep(1, nrow(d)), fails = !d$result) ~ file,
               data = d, FUN = sum)
s$passes <- s$results - s$fails
write.csv(s, "results/tests_summary.csv", row.names = FALSE)
print(s)
cat("total expectations:", sum(s$results), " failures:", sum(s$fails), "\n")
