# PUBG Finish Placement Prediction 数据来源

原始数据来自 Kaggle 的 PUBG Finish Placement Prediction 竞赛。参与者可按竞赛规则自行取得原始训练文件 `train_V2.csv`，放在 `deliverables/pre_model/data/raw/pubg/`。数据准备入口在读取记录前核验来源文件。 [官方数据页](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/data) · [官方规则](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/rules) · [复现说明](../../README.md)

| 文件 | 数据行数 | SHA-256 |
| --- | ---: | --- |
| `train_V2.csv` | 4,446,966 | `435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36` |

训练文件有 29 列，涉及 47,965 场比赛。响应 `winPlacePerc` 表示从 0 到 1 的归一化最终名次。官方字段说明将 `maxPlace` 定义为该场现有数据中的最差名次，将 `numGroups` 定义为有记录的组数。因此，整场抽样保留的是下载文件中抽中比赛的全部有效记录。 [官方字段说明](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/data)

固定抽样使用种子 `6101`，整场划分使用种子 `6102`。两份生成的 CSV 和准备审计写入 `deliverables/pre_model/data/processed/` 供本地复现。 [字段字典](../../docs/DATA_DICTIONARY.md) · [准备核验](../../docs/PREPARATION_REPORT.md)
