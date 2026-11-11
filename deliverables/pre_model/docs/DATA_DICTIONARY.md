# 数据准备变量字典

准备脚本保留 16 个原始字段并构造 3 个衍生字段。模型使用指定响应、行为变量与 `numGroups`。

| 字段 | 含义与单位 | 用途 |
| --- | --- | --- |
| `Id` | 玩家比赛记录的标识 | 核查记录唯一性并排序 |
| `groupId` | 比赛内组标识 | 与 `matchId` 组成组键 |
| `matchId` | 比赛标识 | 整场抽样、划分与聚类 |
| `matchType` | 比赛模式 | 选取 `solo-fpp` |
| `winPlacePerc` | 0 至 1 的归一化最终名次，越高越好 | 响应 |
| `numGroups` | 该场数据中记录的组数 | 比赛上下文 |
| `maxPlace` | 该场现有数据中的最差名次 | 结构核验 |
| `kills` | 击杀次数 | 战斗变量 |
| `damageDealt` | 累计造成的伤害量，扣除自伤 | 战斗变量 |
| `walkDistance` | 步行距离，米 | 移动变量 |
| `boosts` | Boost 物品使用次数 | 补给变量 |
| `heals` | 治疗物品使用次数 | 恢复变量 |
| `DBNOs` | 击倒敌方但未直接淘汰的次数 | Solo-FPP 恒为零 |
| `revives` | 救起队友次数 | Solo-FPP 恒为零 |
| `rideDistance` | 载具移动距离，米 | 结合其他距离识别异常候选 |
| `swimDistance` | 游泳距离，米 | 结合其他距离识别异常候选 |
| `group_size` | 所选数据中同一组的有效记录数 | 构建组等权权重 |
| `group_weight` | 组内记录数的倒数 | 每组记录总权重为一 |
| `split` | `train` 或 `test` | 固定整场 160/40 划分标签 |

`Id` 的唯一性适用于玩家比赛记录。分析中的 `test` 标签指该研究的 40 场留出比赛。 [字段来源](../data/meta/pubg_source.md) · [抽样与划分](PREPARATION_REPORT.md)
