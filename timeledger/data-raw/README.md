# Provenance of inst/extdata

Files `04015.hea`, `04015.atr` and `04015.qrs` are copied unchanged from the
MIT-BIH Atrial Fibrillation Database, version 1.0.0, on PhysioNet:
<https://physionet.org/content/afdb/1.0.0/> (Moody GB, Mark RG. A new method
for detecting atrial fibrillation using R-R intervals. Computers in Cardiology
10:227-230, 1983; Goldberger AL et al. PhysioBank, PhysioToolkit, and PhysioNet.
Circulation 101(23):e215-e220, 2000). License: Open Data Commons Attribution
License v1.0.

They were downloaded on 2026-11-20 with `data-raw/download_physionet.sh` in
the reproduction repository and checked against the database's
`SHA256SUMS.txt`. `.atr` holds the reference rhythm annotations, `.qrs` the
unaudited beat annotations, `.hea` the record header. No waveform files are
included.

To recreate:

```sh
for f in 04015.hea 04015.atr 04015.qrs; do
  curl -L -O https://physionet.org/files/afdb/1.0.0/$f
done
```
