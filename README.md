# timeledger: package, analyses and article

This repository holds the R package `timeledger` and everything needed to
reproduce the article "timeledger: Auditable Time Accounting for Evaluating
Continuous Event Detectors in R".

| Path | Contents |
|---|---|
| `timeledger/` | The R package (base R only; tests in `inst/tinytest`, vignettes in `vignettes/`) |
| `analysis/` | Frozen analysis plan, detector, database runs, simulation, apnea transfer, figures |
| `comparators/` | epicmp build script and binary, conventional R workflow, Python toolkits |
| `benchmarks/` | Scaling benchmarks |
| `audit/` | Prior-art audit and the primary sources that were read |
| `results/` | Every saved result behind a number in the article |
| `paper/` | Article (rjtools R Markdown), bibliography, figures, claim-to-evidence table, letter, drafts |
| `data-raw/` | PhysioNet download script and SHA-256 manifest (data are not redistributed) |
| `tools/` | Rd generator, vignette-code runner, inline renderer, test summary |
| `VERDICTS.md` | Whether the software is complete and whether it is ready for The R Journal |

Archived on Zenodo: https://doi.org/10.5281/zenodo.24489065 (all versions).

Reproduce everything with `bash reproduce.sh` (about 15 minutes, needs
internet for the PhysioNet download).

This project is separate from the author's earlier `ecgrobust` study of
classifier robustness to noise: it shares no code, models or analysis with it,
and addresses evaluation accounting for continuous monitors rather than
classifier accuracy.

Generative AI (Claude, Anthropic) was used to write code and draft text; see
the disclosure in the article.
