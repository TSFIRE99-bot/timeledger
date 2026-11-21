#!/usr/bin/env bash
# One command to reproduce every result behind the article, from a clean clone.
# Needs: R (>= 4.1) with the tinytest package, bash, curl, Python 3 (only for
# the optional Python comparators), and a C compiler for the optional epicmp
# build. Total time on an 8-core laptop: about 15 minutes, most of it reading
# LTAFDB annotation files.
set -euo pipefail
R=${RSCRIPT:-Rscript}

# 1. Data (annotation files only, about 40 MB), checked against PhysioNet SHA-256 sums.
bash data-raw/download_physionet.sh rawdata
for db in afdb ltafdb; do (cd rawdata/$db && grep -E '\.(atr|hea|qrs|qrsc)$' SHA256SUMS.txt | sha256sum -c --quiet -); done

# 2. Package: documentation, install, tests.
$R tools/make_rd.R timeledger
R CMD INSTALL timeledger
$R tools/run_tests.R

# 3. epicmp 10.7.0 reference executable (skip if comparators/epicmp/bin/epicmp exists).
[ -x comparators/epicmp/bin/epicmp ] || [ -x comparators/epicmp/bin/epicmp.exe ] || bash comparators/epicmp/build_epicmp.sh

# 4. Analyses (frozen plan in analysis/ANALYSIS_PLAN.md).
$R analysis/run_database.R afdb
$R analysis/run_database.R ltafdb
$R analysis/simulate_outages.R
$R analysis/apnea_transfer.R
$R comparators/conventional_workflow.R
$R benchmarks/benchmark.R

# 5. Optional Python comparators (timescoring, sed_eval, CPSC 2021 scorer).
if command -v python3 >/dev/null; then
  python3 -m pip install --target .pydeps timescoring==0.0.7 sed_eval==0.2.1 "setuptools<81" wfdb
  python3 comparators/python_comparators.py .pydeps results/comparators/python_comparators.json
fi

# 6. Figures and the article.
$R analysis/figures.R
$R -e 'rmarkdown::render("paper/timeledger.Rmd")'
