# 来源卡：PUBG Finish Placement Prediction（Kaggle 竞赛）

| 项 | 值 |
|----|----|
| 数据源 | Kaggle Competition（官方） |
| Slug | `pubg-finish-placement-prediction` |
| URL | https://www.kaggle.com/competitions/pubg-finish-placement-prediction |
| License | 竞赛数据，仅供竞赛/学习用途（详见竞赛 Rules） |
| 下载日期 | 2026-09-07 |
| 下载方式 | Kaggle CLI + `KAGGLE_API_TOKEN`（新版 access token 支持竞赛数据） |

## 文件与规模

| 文件 | 行数(含表头) | 大小 | 说明 |
|------|------|------|------|
| `train_V2.csv` | 4,446,966 | 660MB | 训练集，含目标列 |
| `test_V2.csv` | 1,934,174 | 273MB | 测试集，无目标列 |
| `sample_submission_V2.csv` | 1,934,174 | 33MB | 提交样例 |

## sha256

- train_V2.csv `435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36`
- test_V2.csv `bf8c26335517a5a1d992afc2be1bb9bf747d6e763c72e47be69866ee178aa533`

## 字段要点

每行 = 单个玩家在一场比赛中的结算数据。目标/响应为连续变量 `winPlacePerc`（0~1，最终名次分位，越高越好）。

- 层级：`groupId`（队伍）嵌套在 `matchId`（比赛）内 → **非独立样本**，建模需按 matchId/groupId 分组处理。
- 玩家局内行为：`assists, boosts, damageDealt, DBNOs, headshotKills, heals, kills, killStreaks, longestKill, revives, rideDistance, roadKills, swimDistance, teamKills, vehicleDestroys, walkDistance, weaponsAcquired`。
- 名次相关：`killPlace, matchPlace, maxPlace`、积分 `killPoints/rankPoints/winPoints`。
- 比赛属性：`matchDuration, matchType, numGroups`。
- ⚠️ **信息泄露风险**：`matchDuration` 等是局后才确定的字段，预测"最终排名"时若用于训练会过高估计模型；建模时需做字段审计（参考 Kaggle 常见 EDA 结论）。
- 需用 `test` 集的 `Id` 对齐提交格式；`sample_submission_V2.csv` 是模板。
