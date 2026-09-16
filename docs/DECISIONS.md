# IBA6101 Project Decisions

All decisions below were confirmed during the 2026-09-12 Grill Me review.

| ID | Decision | Rationale / implication | Status |
|---|---|---|---|
| D001 | Use a coach-facing business problem | The course examples are decision-centered; the project must end in an operational recommendation. | Confirmed |
| D002 | Prioritize statistical explanation over leaderboard-style prediction | The course emphasizes descriptive/inferential statistics, hypothesis testing, and linear regression. | Confirmed |
| D003 | Define the decision as post-match training-priority allocation | The available PUBG fields are mostly observed after a match; do not frame the study as live prediction. | Confirmed |
| D004 | Use `matchId + groupId` as the primary unit | Teammates share the outcome; player-level rows would create pseudo-replication. | Confirmed |
| D005 | Make `squad-fpp` the primary sample | It is the largest clean standard mode relevant to team coaching. | Confirmed |
| D006 | Use `duo-fpp` and `solo-fpp` only for supplementary checks | These modes test portability without mixing heterogeneous rules into the main model. | Confirmed |
| D007 | Use `winPlacePerc` as the primary outcome | It preserves continuous placement information and aligns with the linear-regression course topic. | Confirmed |
| D008 | Use Top-10 status only as a secondary business indicator | A binary threshold is easy to explain but discards information and is not the primary statistical target. | Confirmed |
| D009 | Enforce a strict leakage and variable-governance boundary | Exclude post-match ranking proxies, identifiers, and prior-rating fields from the primary behavior model. | Confirmed |
| D010 | Limit generalization to comparable sampled matches and versions | Kaggle data are observational and not a simple random sample of all PUBG games. | Confirmed |
| D011 | Pre-specify three hypothesis families | Combat, mobility/resources, and team coordination will be tested as blocks to reduce post-hoc fishing. | Confirmed |
| D012 | Process the full `squad-fpp` sample in chunks | The raw file is large, but the primary subset is feasible; raw data remain read-only. | Confirmed |
| D013 | Split and resample by complete `matchId` | This preserves the within-match dependence structure and prevents cross-partition leakage. | Confirmed |
| D014 | Report training-priority ranking, not causal ROI | Training cost, intervention assignment, and causal counterfactuals are unavailable. | Confirmed |
| D015 | Adopt the explicit exit gate in `PROJECT_CONTEXT.md` | If no stable signal or baseline improvement remains, revise the question or switch dataset. | Confirmed |
| D016 | Project status is Go | All Grill Me questions were accepted; proceed to reproducible EDA and analysis. | Confirmed |

## Decisions to revisit only with evidence

- Exact feature transformations, winsorization thresholds, and missing-value rules after EDA.
- Whether a prior-rating sensitivity control is useful and clearly separable from trainable behavior.
- Whether the 5% RMSE improvement gate is attainable without compromising inferential validity.
- Whether later course announcements add a project rubric, required format, or deadline.

