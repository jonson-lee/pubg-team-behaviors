# 来源卡：Dota2 Games Results（UCI）

| 项 | 值 |
|----|----|
| 名称 | Dota2 Games Results |
| 来源 | UCI Machine Learning Repository |
| URL | https://archive.ics.uci.edu/dataset/367/online+game+dota2+dataset |
| 直链 | https://archive.ics.uci.edu/static/public/367/dota2+games+results.zip |
| DOI | 10.24432/C5W593 |
| License | CC BY 4.0 |
| 检索/下载日期 | 2026-09-07 |
| 行×列 | Train 92,650 × 117；Test 10,294 × 117（合计 102,944，与官网一致）|
| 缺失值 | 无 |

## sha256 校验

- dota2Train.csv `16823bf0ad99b4931e94809268807ef398edb7b1288b12b384aeddbee3d9ebda`
- dota2Test.csv `bcc9ce564421db7340b1464dedd2691bb18af06613726ff72d142ffc2ee2aff9`

## 字段含义（前 4 列 + 英雄指示）

每行 = 一场比赛（radiant/dire 视角）。

| 列 | 含义 |
|----|------|
| 0 | `win`：本队是否获胜（1 = 胜，-1 = 负）→ 0/1 化后即分类目标 |
| 1 | `clusterid`：赛区/机房编号（ID，建模时通常剔除） |
| 2 | `gamemode`：游戏模式（如 All Pick），分类特征 |
| 3 | `gametype`：天梯/普通等，分类特征 |
| 4–116 | 英雄指示：共 113 位英雄，1 = 本队选出该英雄，-1 = 对方选出，0 = 未选出；每行恰好五个 1 与五个 -1 |

## 特点与注意

- 采集自 2016-08-13 约 2 小时窗口 → **版本偏老**，结论宜限定"当时版本"，可作讨论点。
- 仅含**赛前可知道**的英雄选择信息，无局内经济/时间数据 → 是干净、无泄露的起点数据。
- 英雄指示变量非常稀疏（113 列中仅 10 个非零）→ 描述统计时可留意。

## 引用

Tridgell, S. (2016). Dota2 Games Results [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5W593
