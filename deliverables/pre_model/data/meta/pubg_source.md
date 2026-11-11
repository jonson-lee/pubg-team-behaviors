# 来源卡：PUBG Finish Placement Prediction

| 项 | 值 |
| --- | --- |
| 数据源 | Kaggle Competition |
| Slug | `pubg-finish-placement-prediction` |
| URL | https://www.kaggle.com/competitions/pubg-finish-placement-prediction |
| 使用条款 | 以竞赛 Rules 为准；未独立核验具体许可条款。 |
| 下载日期 | 2026-09-07 |
| 下载方式 | Kaggle CLI |

## 原始文件与校验

| 文件 | 数据行数（不含表头） | 大小 | 说明 |
| --- | --- | --- | --- |
| `train_V2.csv` | 4,446,966 | 660 MB | 含响应变量，当前分析输入。 |
| `test_V2.csv` | 1,934,174 | 273 MB | 无响应变量，当前分析未使用。 |
| `sample_submission_V2.csv` | 1,934,174 | 33 MB | 竞赛提交模板，当前分析未使用。 |

- `train_V2.csv` SHA-256：`435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36`
- `test_V2.csv` SHA-256：`bf8c26335517a5a1d992afc2be1bb9bf747d6e763c72e47be69866ee178aa533`

## 字段与解释

每行是一名玩家在一场比赛中的结算记录。响应 `winPlacePerc` 为 [0, 1] 的归一化名次，越高越好，取值受名次结构限制。

- `Id`、`groupId`、`matchId` 分别标识记录、组与比赛。组键为 `(matchId, groupId)`；同组可能共享响应，同场记录也不独立。记录唯一不证明跨比赛玩家身份唯一。
- 当前行为变量：`kills`、`damageDealt`、`walkDistance`、`boosts`、`heals`；比赛上下文：`numGroups`。
- 其他行为字段包括 `assists`、`DBNOs`、`headshotKills`、`killStreaks`、`longestKill`、`revives`、`rideDistance`、`roadKills`、`swimDistance`、`teamKills`、`vehicleDestroys`、`weaponsAcquired`。
- 名次和积分字段包括 `killPlace`、`maxPlace`、`killPoints`、`rankPoints`、`winPoints`；本地 CSV 没有 `matchPlace`。比赛属性还包括 `matchDuration`、`matchType`。
- 数据是赛后累计行为。存活更久也可能积累更多行为，关联不能解释为策略的因果效果，也不能据此声称赛前或实时预测。

## 本地全量核验（2026-10-08）

- 训练文件为 4,446,966 条记录、29 列、47,965 个 `matchId`。全文件仅一个缺失单元，位于 `winPlacePerc`；非缺失响应均在 [0, 1]。
- `solo-fpp` 为 536,762 条记录、5,679 场；剔除唯一响应缺失且 `maxPlace=numGroups=1` 的记录后，剩余 536,761 条记录、5,678 场。
- 此模式 `DBNOs` 和 `revives` 全为 0；所有 `Id` 唯一。
- 11,459 个 `(matchId, groupId)` 组合含多条记录，涉及 24,763 条记录、5,063 场比赛，组内非缺失响应一致。不能假定单人模式每个组恰好一条记录。
- `numGroups < maxPlace` 不自动视为错误；若整场剔除多记录组，只剩 615 场、56,925 条记录。当前协议保留有效记录并按比赛聚类。
- 核验方式为分块读取全部训练 CSV，汇总比赛及组的计数、缺失值与响应范围；另逐行核验测试集和模板各有 1,934,174 条记录。原始文件未修改。

数据准备入口、依赖和本次交付范围见 [README](../../README.md)，研究协议见 [Proposal.md](../../reports/Proposal.md)。
