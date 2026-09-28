# code/ — Reproducible R analysis pipeline

The project analysis is implemented in **R**. Method choices are documented in
`docs/ANALYSIS_PLAN_R.md`; do not change features or model order in code before updating that
document.

## Setup

```r
# from the repository root
Rscript code/00_setup.R      # install/load required packages
```

Optional (recommended for reproducibility):

```r
renv::init()                 # creates renv.lock so every team member matches versions
```

## Run order (from the repository root)

```powershell
Rscript code/01_data_audit.R   # M1: filter, aggregate to teams, integrity checks
Rscript code/02_eda.R          # M2: descriptive stats, figures, feature freeze
Rscript code/03_models.R       # M3/M4: nested models, diagnostics, validation
```

Raw CSVs are read-only and live in `data/raw/pubg/` (git-ignored). Derived tables are written to
`data/processed/`; reports and figures to `reports/`.

## Layout

```
code/
  R/config.R        paths, behaviour-block column groups, modes
  R/io.R            read + filter helpers
  R/audit.R         team aggregation + integrity checks
  00_setup.R        install/load packages
  01_data_audit.R   milestone M1
  02_eda.R          milestone M2
  03_models.R       milestones M3/M4
```
