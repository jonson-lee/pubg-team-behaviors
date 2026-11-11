# Player Behavior and Final Placement in PUBG

IBA6101 Statistical Analysis group project · Final Circle

We study how combat, mobility, and recovery behaviors are associated with normalized final placement in PUBG Solo-FPP. The measures are recorded after a match. Survival time affects the opportunities to accumulate actions, so the analyses describe associations among recorded behaviors and placement.

## Data and variables

The Kaggle training file has 4,446,966 records in 47,965 matches. The Solo-FPP subset contains 536,762 records in 5,679 matches. After removing the single record with missing placement, the eligible pool contains 536,761 records in 5,678 matches. We retain valid records in multi-record groups and keep extreme behavior values.

| Role | Variables |
| --- | --- |
| Outcome | `winPlacePerc`, normalized final placement from 0 to 1. Higher values indicate better placement. |
| Match context | `numGroups`, the number of groups represented in the match data |
| Combat | `kills` and `damageDealt` |
| Mobility and recovery | `walkDistance`, `boosts`, and `heals` |
| Audit and grouping | `Id`, `matchId`, and `groupId` |

We obtain the original `train_V2.csv` from Kaggle and verify its SHA-256 before preparation. The script sorts eligible match IDs, draws 200 whole matches using seed `6101`, and saves 18,935 records. Seed `6102` defines the fixed 160-match training and 40-match evaluation split. The local output retains all records from each selected match together. [Source and checksum](../data/meta/pubg_source.md) · [Preparation and reproduction](../README.md)

## Hypotheses

H1 and H2 use the coefficients of the full model.

- **H1, combat.** Under $H_{0,1}$, the coefficients of `kills` and `damageDealt` are both zero. Under $H_{A,1}$, at least one is nonzero.
- **H2, mobility and recovery.** Under $H_{0,2}$, the coefficients of `walkDistance`, `boosts`, and `heals` are all zero. Under $H_{A,2}$, at least one is nonzero.
- **H3, relative contribution.** Under $H_{0,3}$, the difference $D$ between the mobility and recovery increment and the combat increment is at most zero. Under $H_{A,3}$, $D>0$.

The four regression models contain an intercept and `numGroups`. The context model uses only these terms. The combat and mobility/recovery models add the corresponding sets of variables. The full model includes both sets. All fitted-model comparisons for inference use the same 200 matches and 18,935 records.

For either set, the incremental $R^2$ is the full model's $R^2$ minus the $R^2$ of the model that omits that set. The difference is

$$
D = \Delta R^2_{\mathrm{mobility/recovery}} - \Delta R^2_{\mathrm{combat}}
  = R^2_{\mathrm{context+mobility/recovery}} - R^2_{\mathrm{context+combat}}.
$$

The primary model uses equal record weights. CR1 standard errors cluster by match, with coefficient tests referenced to $t(G-1)$ for $G$ match clusters. H1 and H2 use cluster-robust Wald $F(q,G-1)$ tests with two and three restrictions, respectively. Holm adjustment applies to the two joint tests within each specification. For H3, we draw whole matches with replacement using seed `6103`. Each of the 1,000 draws gives a paired difference $D$. We report the two-sided 95% percentile interval.

## Sensitivity and prediction checks

The `log1p` sensitivity transforms each behavior variable and retains the original response and `numGroups`. Group-equal WLS gives each retained record a weight of $1/n_{mg}$, where $n_{mg}$ counts the records in its match and group. Correlations, VIFs, and the training-set exploration describe overlap among the behavior variables. Prediction checks fit on the 160 training matches and evaluate on the 40 previously examined matches. The team modeling supplement reports record-weighted prediction metrics for all specifications, including group-equal WLS. [Team modeling review](../../modeling/Modeling_Review.md)

The 2026-11-11 H3 sensitivity analysis uses the full 200-match sample. It retains either `kills` or `damageDealt` as the sole combat variable and fits the original-scale and `log1p` variants for each choice. All four variants use the same 1,000 whole-match resamples, and all four 95% intervals for $D$ lie above zero. The comparison concerns three mobility and recovery variables and one combat indicator. The supplementary combat Wald test uses one restriction and the mobility and recovery test uses three. [H3 sensitivity results](../../modeling/H3_Sensitivity_Summary.md)
