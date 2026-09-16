# 来源卡：League of Legends Diamond Ranked Games (10 min)

| 项 | 值 |
|----|----|
| 数据源 | Kaggle Dataset |
| Slug | `bobbyscience/league-of-legends-diamond-ranked-games-10-min` |
| URL | https://www.kaggle.com/datasets/bobbyscience/league-of-legends-diamond-ranked-games-10-min |
| License | 见数据集页（个人/学术分析通常可用） |
| 下载日期 | 2026-09-07 |
| 行×列 | 9,879 × 40 |
| 文件 | `high_diamond_ranked_10min.csv`（1.4MB） |

## sha256

`82b2e23279097c2dac616e966eb2911711c428d41b6382b4cdb15da4892f9ca6`

## 字段要点

- 每行 = 一场高分段(钻石)排位赛前 **10 分钟**快照 + 结局。
- 目标：`blueWins`（0/1，蓝方是否获胜）。
- 特征均为 **10 分钟内可知**的信息（如 `blueWardsPlaced`, `blueFirstBlood`, `blueKills`, `blueGoldDiff`, `blueExperienceDiff`…，红方同构），**天然无未来信息泄露**——非常适合预测建模入门。
- 局限：仅前 10 分钟数据；样本为钻石段。

## 引用

数据集页引用信息见 https://www.kaggle.com/datasets/bobbyscience/league-of-legends-diamond-ranked-games-10-min
