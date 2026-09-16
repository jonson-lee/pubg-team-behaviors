# IBA6101 Final Project Context

**Status:** Go (Grill Me completed 2026-09-12)  
**Course:** IBA6101 - Statistical Analysis  
**Working title:** *Which In-Game Behaviors Should a PUBG Team Train First? Statistical Analysis of Team Behaviors and Final Placement in Squad-FPP Matches*

## 1. Business problem

PUBG team coaches have limited training time and need to decide which controllable in-game capabilities should receive priority. This project uses historical match data to identify behavior categories that are stably associated with better final placement and to convert the evidence into a training-priority ranking.

The project is a post-match training-diagnostic study. It is not a live prediction system, an intervention experiment, or a claim that changing a behavior will causally improve placement.

## 2. Objective and research questions

### Objective

Estimate the association between team-level in-game behavior and final placement percentile, quantify uncertainty, and provide an evidence-based priority order for team training.

### Research questions

1. How are team behaviors and final placement distributed in standard Squad-FPP matches?
2. Do combat, mobility/resources, and team-coordination behavior blocks provide incremental explanatory power after match-context controls?
3. Are the estimated relationships stable across reasonable model specifications and match-level resampling?
4. Do the main relationships differ in Duo-FPP and Solo-FPP comparison samples?
5. What training priorities can be recommended without overstating observational evidence?

## 3. Confirmed scope

- **Primary sample:** `matchType == squad-fpp`.
- **Supplementary samples:** `duo-fpp` and `solo-fpp` for robustness and scope comparison.
- **Excluded:** `normal-*`, `crash*`, `flare*`, and other special/event modes.
- **Primary unit:** one team in one match, identified by `matchId + groupId`.
- **Primary outcome:** team `winPlacePerc` (0-1 final placement percentile). Teammates share the same outcome.
- **Supplementary outcome:** whether the team is in the top 10% of the relevant match, used only for an interpretable business check.
- **Team size:** 6-7 members, consistent with the course final-project requirement; final names and IDs remain TBD.

The primary sample audit found approximately 1.76 million player rows, 18,576 matches, and 506,161 team-match records for `squad-fpp`. Counts are recomputed by the reproducible pipeline before analysis.

## 4. Data and source

The required main data are the Kaggle PUBG Finish Placement Prediction files:

- `data/raw/pubg/train_V2.csv` (source card records 4,446,966 lines including the header)
- `data/raw/pubg/test_V2.csv` (source card records 1,934,174 lines including the header)
- `data/meta/pubg_source.md` (source, license, hashes, field notes and leakage warnings)

Raw files are read-only. Processing scripts must write derived data to a separate processed/output location and record row counts, filters, and checksums where practical.

## 5. Variable governance

### Primary explanatory blocks

- **Combat:** kills, damage dealt, assists, headshot kills, kill streaks and related team aggregates.
- **Mobility and resources:** walking, riding and swimming distance, heals, boosts, and weapons acquired.
- **Team coordination:** revives, DBNO-related measures, assists and other team-level coordination aggregates where the field definition is defensible.

Aggregates may include team total, mean, maximum, dispersion and per-member normalized versions. Exact fields and transformations are finalized after EDA using a documented rule, not by searching for favorable p-values.

### Context controls

Use match-structure variables such as `maxPlace` and `numGroups` when they improve comparability. `matchType` is fixed in the primary sample and remains a stratification variable for comparisons.

### Excluded from the primary explanatory model

`killPlace`, `matchDuration`, `rankPoints`, `winPoints`, `killPoints`, `Id`, `groupId`, and `matchId` are excluded from the primary behavior model. The first group is post-match or outcome-proximal; the second group is an identifier; the points fields represent prior skill or rating context rather than a trainable behavior. Sensitivity analyses may add an explicitly labeled prior-skill control, but may not present it as a training lever.

## 6. Statistical design

- Begin with descriptive statistics, distributions, outliers, missingness, and within-match dependence checks.
- Use a context-only mean/baseline model, then add behavior blocks in a pre-specified order.
- Use multiple linear regression for the continuous `winPlacePerc` outcome, with transformations or nonlinear terms only when justified by EDA and documented before final comparison.
- Report coefficients, standardized effects where useful, 95% confidence intervals, robust or cluster-aware standard errors, residual diagnostics, and partial/adjusted explanatory measures.
- Test behavior blocks jointly with nested-model comparisons; individual p-values are not the sole basis for recommendations.
- Hold out complete `matchId` groups for sample-out-of-match validation. Never split individual player rows from the same match across partitions.
- Use match-level bootstrap or an equivalent cluster-aware procedure for stability checks.

## 7. Hypothesis framework

The following families are fixed before EDA:

1. Combat variables provide incremental explanatory power beyond match context.
2. Mobility and resource variables provide incremental explanatory power beyond match context and combat.
3. Team-coordination variables provide incremental explanatory power beyond the preceding blocks.

The main tests are two-sided. Direction, magnitude, uncertainty, and stability are reported together. Nonlinearity and cross-mode differences are pre-declared extensions, not unrestricted searches.

## 8. Evidence boundary and generalizability

The data are observational, version-limited, and not a simple random sample of all PUBG games or players. Conclusions are limited to the sampled matches and to settings with similar rules, version, and player composition. The report must not claim causal effects, current-version universality, or a measurable training ROI.

## 9. Course alignment

The project follows the Lecture 1 emphasis on decision-making under uncertainty, descriptive and inferential statistics, sampling/dependence and bias, hypothesis testing, linear regression, and experimental-design reasoning. It is designed for a 6-7 person final project worth 30% of the course grade (20% report, 10% presentation); project consultation attendance is separately worth 5%.

## 10. Success and exit gate

Proceed to final recommendations only if all four conditions hold:

1. Data integrity and team aggregation pass documented checks; no target leakage is found.
2. At least one pre-specified behavior block has a stable, practically meaningful association, with direction consistent across reasonable specifications and match-level resampling.
3. The model improves on the training-mean baseline on a complete-match holdout, with a target of at least 5% RMSE improvement.
4. The result supports at least one clear training-priority statement with uncertainty and limitations attached.

If these conditions fail, first revise transformations or stratification. If no stable actionable signal remains, switch to Dota 2 or LoL and re-evaluate the project question rather than forcing a PUBG conclusion.

