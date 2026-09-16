# 项目数据层说明（Data Architecture）

> 目录内只放"数据"相关，分析代码/报告另见上层 `code/`、`reports/`。

```
Project/
├── data/
│   ├── raw/          原始下载数据（只读，绝不在此修改）
│   │   ├── pubg/      ⭐ 主选数据集：Kaggle PUBG（已入库 ✅）
│   │   ├── dota2/     ◐ 备选数据集：UCI Dota2（已入库 ✅）
│   │   ├── lol/       o 参考/对照：Kaggle LoL（已入库 ✅）
│   │   └── csgo/      o 参考/对照：Kaggle CS:GO（已入库 ✅）
│   ├── processed/    清洗/衍生后的分析用数据（脚本产出）
│   └── meta/         数据字典、来源卡片、引用与校验
```

## 归档约定

1. **raw/ 只读**：任何清洗脚本不得覆盖 raw 文件；输出一律进 `processed/`。
2. 每个数据集在 `meta/` 留一张"来源卡"：URL、检索日期、行×列、license、sha256、字段含义。
3. 以"游戏"为单位分目录；若同游戏多版本数据，加子目录或版本后缀。
4. 下载方式：匿名可下（UCI）直接 curl；Kaggle 需 Kaggle API token（见 `meta/kaggle_setup.md` 或对话说明）。

## 当前入库清单

> 选型：**PUBG 为主选**（连续目标 `winPlacePerc`，最适合课程线性回归主线，样本量大），**Dota2 为备选/对照组**（0/1 胜负，可做分类对照）。LoL/CS:GO 作参考。

| 游戏 | 数据源 | 文件 | 规模 | 角色 | 状态 |
|------|--------|------|------|------|------|
| PUBG | Kaggle 竞赛（官方） | `train_V2.csv`, `test_V2.csv`, `sample_submission_V2.csv` | 4,446,966 + 1,934,174 行 | ⭐ 主选 | ✅ 已入库 |
| Dota2 | UCI Games Results | `dota2Train.csv`, `dota2Test.csv` | 92,650 + 10,294 行 × 117 列 | ◐ 备选 | ✅ 已入库 |
| LoL | Kaggle `bobbyscience/...diamond-ranked-games-10-min` | `high_diamond_ranked_10min.csv` | 9,879 × 40 | o 参考 | ✅ 已入库 |
| CS:GO | Kaggle `christianlillelund/csgo-round-winner-classification` | `csgo_round_snapshots.csv` | 122,410 × 97 | o 参考 | ✅ 已入库 |
