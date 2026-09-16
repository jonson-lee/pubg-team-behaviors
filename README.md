# Which In-Game Behaviors Should a PUBG Team Train First?

> Statistical analysis of team behaviors and final placement in Squad-FPP matches.
> IBA6101 Statistical Analysis — group project.
>
> Squad-FPP 对局中队伍行为与最终名次的统计分析。IBA6101《统计分析》小组课程项目。

---

## Overview | 项目概述

**EN** — PUBG team coaches have limited training time and must decide which controllable in-game
capabilities to prioritize. This project uses historical match data to identify behavior categories
that are stably associated with better final placement and to convert the evidence into an
uncertainty-aware training-priority ranking. It is a post-match training-diagnostic study: not a live
prediction system, not an intervention experiment, and not a causal claim.

**中文** — PUBG 战队的训练时间有限，教练需要决定优先训练哪些可控能力。本项目利用历史对局数据，找出与
最终名次稳定相关的队伍行为类别，并据此给出带有不确定性说明的训练优先级排序。它是赛后诊断研究，
**不是**实时预测系统，**不是**干预实验，也不主张因果效应。

---

## Research questions | 研究问题

1. How are team behaviors and final placement distributed in standard Squad-FPP matches?
2. Do combat, mobility/resources, and team-coordination behavior blocks provide incremental
   explanatory power after match-context controls?
3. Are the relationships stable across reasonable model specifications and match-level resampling?
4. Do the main relationships differ in Duo-FPP and Solo-FPP comparison samples?
5. What training priorities can be recommended without overstating observational evidence?

---

## Data and license | 数据与许可

- **Source:** Kaggle *PUBG Finish Placement Prediction* (`train_V2.csv`, `test_V2.csv`).
- **Primary sample:** `matchType == squad-fpp`; supplementary `duo-fpp` and `solo-fpp`.
  Excluded: `normal-*`, `crash*`, `flare*`, and other special/event modes.
- **Primary unit:** one team in one match (`matchId + groupId`); teammates share the same outcome.
- **Primary outcome:** team `winPlacePerc` (0–1 final placement percentile).
- **Access:** raw CSVs are **not** committed. Download from Kaggle and place them under
  `data/raw/pubg/`. Source cards (source, license, hashes, leakage warnings) are in `data/meta/`.

> 原始 CSV 不入库，需自行从 Kaggle 下载到 `data/raw/pubg/`。数据来源卡（来源、许可、哈希、泄漏提示）
> 见 `data/meta/`。

---

## Repository structure | 仓库结构

```
data/
  meta/          # source cards: origin, license, hashes, field/leakage notes
  raw/           # raw Kaggle CSVs (git-ignored, local only)
deliverables/    # proposal and other course deliverables
docs/            # project context, decision log, next actions
```

---

## Method | 方法

- Aggregate player rows to one team per match (`matchId + groupId`) after integrity checks.
- Descriptive statistics, distributions, outliers, missingness, and within-match dependence checks.
- Context-only baseline, then nested linear models adding behavior blocks in a pre-specified order:
  **combat** → **mobility & resources** → **team coordination**.
- Report coefficients, standardized effects, 95% confidence intervals, cluster-aware standard errors,
  residual diagnostics, and block-level nested-model tests.
- Hold out complete `matchId` groups; use match-level bootstrap for stability. Two-sided tests;
  Duo/Solo as robustness checks.

---

## Setup and reproducibility | 环境与复现

Raw data must be downloaded from Kaggle into `data/raw/pubg/`. The reproducible analysis pipeline
will be added here as it is implemented.

> 需先将 Kaggle 原始数据放入 `data/raw/pubg/`；可复现分析流水线将随实现补充。

---

## Results | 结果

Analysis in progress. The evidence gate is defined in `docs/PROJECT_CONTEXT.md` (data integrity,
a stable and practically meaningful behavior-block association, out-of-match improvement over the
training-mean baseline, and at least one clear training-priority statement).

> 分析进行中，证据门槛见 `docs/PROJECT_CONTEXT.md`。

---

## Limitations | 局限

Observational and version-limited data; not a simple random sample of all matches or players.
Conclusions are limited to the sampled matches and settings with similar rules and player composition.
No causal effects, current-version universality, or measurable training-ROI claims.

> 观察性、受版本限制的数据，并非全体对局/玩家的随机样本；结论仅限所采样对局，不作因果或 ROI 主张。

---

## Team | 团队

Group coursework project. Member names and student IDs are intentionally omitted from this repository;
the focus is on the project itself.

> 小组课程项目。为保护隐私，仓库不包含成员姓名与学号，内容仅聚焦项目本身。

## Acknowledgements | 致谢

PUBG Finish Placement Prediction dataset (Kaggle); built for the IBA6101 course.
