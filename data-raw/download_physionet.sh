#!/usr/bin/env bash
# Download annotation and header files (no waveforms) for MIT-BIH AFDB 1.0.0 and LTAFDB 1.0.0.
# Usage: bash data-raw/download_physionet.sh <outdir>
set -euo pipefail
OUT=${1:-rawdata}
for db in afdb ltafdb; do
  mkdir -p "$OUT/$db"
  base="https://physionet.org/files/$db/1.0.0"
  curl -sfL -m 120 "$base/" -o "$OUT/$db/index.html"
  for f in $(grep -oE 'href="[^"/]+\.(hea|atr|qrs|qrsc|txt|md|html)"' "$OUT/$db/index.html" | sed 's/href="//;s/"//'); do
    [ -s "$OUT/$db/$f" ] || curl -sfL --retry 5 --retry-delay 3 -m 300 "$base/$f" -o "$OUT/$db/$f" || echo "FAILED $db/$f"
  done
  for f in RECORDS ANNOTATORS SHA256SUMS.txt LICENSE.txt; do
    curl -sfL --retry 3 -m 120 "$base/$f" -o "$OUT/$db/$f" || echo "missing $db/$f"
  done
done
echo DONE
