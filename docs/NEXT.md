# IBA6101 Next Steps

## Immediate milestone: reproducible data audit

- [ ] Create a read-only input manifest for the PUBG files and record source-card hashes.
- [ ] Implement chunked filtering for `squad-fpp`, `duo-fpp`, and `solo-fpp`.
- [ ] Aggregate player rows to `matchId + groupId` and verify that each team has one outcome.
- [ ] Check duplicate identifiers, missing `winPlacePerc`, impossible values, team-size distributions, and within-match outcome consistency.
- [ ] Save a data dictionary for every retained feature and every exclusion.

## EDA and hypothesis preparation

- [ ] Plot the outcome and behavior-block distributions; document skew, outliers, and zero inflation.
- [ ] Compare team-level behavior and placement across standard modes.
- [ ] Quantify correlations and multicollinearity before choosing transformations.
- [ ] Freeze the exact feature list, transformations, and nested-model order in the analysis log.
- [ ] Produce the baseline descriptive table and pre-specified hypothesis test plan.

## Modeling and validation

- [ ] Fit the context-only mean/baseline model.
- [ ] Fit nested linear models: context, + combat, + mobility/resources, + coordination.
- [ ] Use complete-match holdout partitions and cluster-aware standard errors or bootstrap.
- [ ] Check residual behavior, influential observations, heteroskedasticity, and sensitivity to transformations.
- [ ] Report RMSE, MAE, sample-out-of-match R2, block-level tests, standardized effects, and confidence intervals.
- [ ] Run the Top-10 supplementary check and duo/solo robustness analysis.

## Business interpretation and deliverables

- [ ] Rank training areas by effect magnitude, uncertainty, stability, and controllability.
- [ ] Write recommendations with explicit non-causal language and no ROI claims.
- [ ] Document limitations: observational design, version/sampling bias, post-match measurement, and omitted confounding.
- [ ] Prepare an English report, figures/tables, reproducible code, data README, and 10-minute presentation outline after the analysis stabilizes.
- [ ] Replace team-name and student-ID placeholders once the 6-7 person team is confirmed.

## Exit gate

Use the four conditions in `PROJECT_CONTEXT.md`. If the gate fails, revise the design once with evidence; if no stable actionable signal remains, switch to Dota 2 or LoL rather than forcing a conclusion.

