> 历史材料：本文件保留早期 Squad-FPP 分析方案；当前 Solo-FPP 协议见 [Proposal](../deliverables/pre_model/reports/Proposal.md)。

# IBA6101 Analysis Plan (R)

**Status:** Draft for team review
**Language:** The reproducible analysis is implemented in **R**.
**Course alignment:** IBA6101 topic chain *random variables → probability distributions →
hypothesis testing → linear regression → experimental design* (see Lecture 1 and the course
notes). This document maps each project method to its course source so the report can be checked
against the grading expectations.

> 本文件是分析方法的唯一权威说明（single source of truth）。任何特征、变换、模型顺序的改动
> 必须先改本文件，再改代码，避免事后挑选结果（post-hoc fishing）。

---

## 0. Why R

- The course teaches statistics and regression conceptually (descriptive and inferential
  statistics, hypothesis testing, linear regression); R expresses these directly and
  transparently (`lm`, `anova`, `t.test`, `boot`).
- R has first-class support for the required diagnostics (residuals, VIF, robust/cluster SE) and
  for reproducible reporting (R Markdown / Quarto).
- Mixed skill in the team is handled by a documented pipeline in `code/`, not by ad-hoc notebooks.

---

## 1. Environment and reproducibility

- **Tooling:** R + RStudio; `renv` to pin package versions; scripts under `code/`.
- **Core packages (by role):**

| Role | Packages |
|---|---|
| Data I/O & wrangling | `data.table` (chunked/fast CSV), `dplyr`, `tidyverse` |
| Descriptive stats & figures | `ggplot2`, `moments`/`e1071`, `corrplot` |
| Modelling & tests | base `lm`/`aov`/`t.test`/`kruskal.test`, `car`, `lmtest`, `sandwich`, `clubSandwich` or `fixest` |
| Resampling / validation | `boot`, `rsample` |
| Reporting | `broom`, `modelsummary`/`stargazer`, Quarto / R Markdown |

- **Reproducibility rules:** raw CSVs are read-only; every script writes derived data to
  `data/processed/` and reports to `reports/`, recording filters, row counts, and (where
  practical) checksums.

---

## 2. Data audit and team aggregation

- Read only the needed columns with `data.table::fread(..., select=)`.
- Filter `matchType` to `squad-fpp` (primary), `duo-fpp` and `solo-fpp` (supplementary); exclude
  `normal-*`, `crash*`, `flare*` and other special modes.
- Aggregate player rows to one team per match on `matchId + groupId`; teammates share
  `winPlacePerc`.
- Integrity checks: duplicate identifiers, missing `winPlacePerc`, impossible values, team-size
  distribution, within-match outcome consistency.

**Course source:** population vs sample, individual, variable classification
(qualitative/quantitative, discrete/continuous).

---

## 3. Descriptive statistics

- **Centre:** `mean`, `median`. **Spread:** `sd`, `var`, `IQR`, `range`, five-number summary.
- **Shape:** compare mean vs median for skew direction; `moments::skewness`.
- **Figures:** histograms (unimodal/bimodal/uniform, left/right skew), boxplots with the
  1.5×IQR rule, scatterplots, dot plots.
- **Association:** correlation matrix and collinearity checks before choosing transformations.

**Course source:** measures of centre and spread, mean/median skew rule, boxplot five-number
summary, histogram shape.

---

## 4. Sampling, bias, and dependence

- State explicitly that the data are **observational and not a simple random sample**; document
  possible under-coverage, non-response, and response bias.
- Compare behaviour and placement across standard modes; treat `matchType` as a stratification
  variable.
- Quantify within-match dependence (e.g. intraclass correlation) to justify the team-level unit
  and cluster-aware inference.

**Course source:** SRS / stratified / systematic / cluster sampling; the four bias types;
observational vs designed study.

---

## 5. Random variables and distributions

- Examine the distribution of `winPlacePerc` and each behaviour variable (zero inflation, heavy
  right skew).
- Apply `log1p` to skewed count/distance variables and standardize (z-score) explanatory
  variables so effects are comparable.
- Use QQ plots and density plots to check distributional assumptions.

**Course source:** discrete vs continuous random variables; probability distributions.

---

## 6. Hypothesis testing

- Group comparisons across modes: `t.test`, `aov`, and `kruskal.test` when normality fails.
- **Block joint tests** are the primary tests: nested-model comparison with partial F-tests
  (`anova()`), not individual p-values.
- Supplementary Top-10% indicator via logistic regression (`glm`, family = binomial).
- Main tests are two-sided; report direction, magnitude, uncertainty, and stability together.

**Course source:** hypothesis-testing framework (null/alternative, significance, two-sided
testing).

---

## 7. Linear regression (core)

- Fit `lm(winPlacePerc ~ context + combat + mobility + coordination)` and nested variants in the
  pre-specified order: **context → +combat → +mobility/resources → +coordination**.
- Report coefficients, standardized effects, incremental R², and partial F-tests per block.
- **Diagnostics:** residuals vs fitted, QQ plot, `car::vif()` (multicollinearity),
  `lmtest::bptest()` (heteroskedasticity), Cook's distance / leverage for influential points.
- **Robust inference:** cluster-robust standard errors by `matchId`
  (`sandwich::vcovCL` + `lmtest::coeftest`, or `fixest::feols(..., cluster = ~matchId)`).
- Non-linear terms are added only when EDA justifies them and the decision is recorded here first.

**Course source:** linear regression.

---

## 8. Experimental-design reasoning

- State explicitly that this is an **observational study with no random assignment**; therefore
  no causal claims, no treatment-effect language, and no ROI estimates.
- Discuss confounding, reverse timing, and post-match measurement as threats to interpretation.
- Note why controls/placebo/blinding (designed-experiment tools) do not apply.

**Course source:** observational vs experimental design; treatment, control, placebo, blinding.

---

## 9. Resampling and validation

- Split and resample by **complete `matchId`**; never split player rows from one match.
- `matchId`-level bootstrap (`boot`) for stability of coefficients and block contributions.
- Report RMSE, MAE, and sample-out-of-match R² against the training-mean baseline.
- **Evidence gate:** at least 5% RMSE improvement over the training-mean baseline on complete-match
  holdout (see `PROJECT_CONTEXT.md`).

**Course source:** sampling distribution, central limit theorem, bootstrap.

---

## 10. Reporting

- Reproducible Quarto / R Markdown report: code → figures → tables → text in one document.
- `modelsummary`/`stargazer` for regression tables; `ggplot2` for a consistent figure style.
- Business output ranks training areas by standardized association, interval width, stability,
  and controllability, with explicit non-causal wording and limitations.

**Course source:** the four functions of statistics — collection, analysis, interpretation,
presentation.

---

## 11. Pipeline (code layout)

```
code/
  R/config.R          # paths, behaviour-block column groups, modes
  R/io.R              # read + filter
  R/audit.R           # team aggregation + integrity checks
  00_setup.R          # install/load packages
  01_data_audit.R     # milestone M1: audit + data dictionary
  02_eda.R            # milestone M2: EDA + feature freeze
  03_models.R         # milestones M3/M4: nested models + validation
```

Run order: `00_setup.R` → `01_data_audit.R` → `02_eda.R` → `03_models.R`.

---

## 12. Course-to-method mapping (for the report)

| Course module | Project method | R implementation |
|---|---|---|
| Variables & data types | feature classification, dictionaries | `config.R`, data dictionary |
| Descriptive statistics | centre/spread, skew, boxplot | `summary`, `moments`, `ggplot2` |
| Sampling & bias | observational limits, stratification, ICC | grouping, `ICC`/variance decomposition |
| Random variables & distributions | skew/zero-inflation, transforms | `log1p`, `scale`, QQ/density plots |
| Hypothesis testing | mode comparisons, block joint tests | `t.test`, `aov`, `kruskal.test`, `anova` |
| Linear regression | nested behaviour-block models | `lm`, `car`, `sandwich`, `fixest` |
| Experimental design | non-causal reasoning, confounders | discussion + sensitivity models |
| Resampling | match-level bootstrap, holdout | `boot`, `rsample` |
