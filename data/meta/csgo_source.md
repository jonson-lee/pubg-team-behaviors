# 来源卡：CS:GO Round Winner Classification

| 项 | 值 |
|----|----|
| 数据源 | Kaggle Dataset |
| Slug | `christianlillelund/csgo-round-winner-classification` |
| URL | https://www.kaggle.com/datasets/christianlillelund/csgo-round-winner-classification |
| License | 见数据集页 |
| 下载日期 | 2026-09-07 |
| 行×列 | 122,410 × 97 |
| 文件 | `csgo_round_snapshots.csv`（50MB） |

## sha256

`e985101012756f365b4003ebbbb16012f5f4c513b83e1999545f618183113827`

## 字段要点

- 每行 = 一局 CS:GO 比赛中某一**回合的一个快照**（涉及 CT 反恐方 / T 恐怖方状态）。
- 目标：CT 是否赢得该回合（可对照 `round_winner` 相关列确认）。
- 关键列：`time_left`（剩余时间）、`ct_score`/`t_score`（双方得分）、`map`（地图）、`bomb_planted`、双方血量/经济/枪械、位置等。
- ⚠️ **必须注意层级**：同一场比赛的多个回合高度相关，切分训练/测试要**按 match/round 分组**，避免"同场回合串漏"；正式建模前先看有无 match_id 字段或按回合顺序做分组切分。

## 引用

https://www.kaggle.com/datasets/christianlillelund/csgo-round-winner-classification
