# 数据准备变量字典

本表对应准备脚本保留的 16 个原始字段及 3 个衍生字段。原始 CSV 共 29 列；模型方案仅使用指定响应、五个行为变量与 `numGroups`。

| 字段 | 含义与单位 | 用途 |
| --- | --- | --- |
| `Id` | 匿名玩家比赛记录标识 | 唯一性与排序；不是跨比赛玩家身份。 |
| `groupId` | 比赛内组标识 | 与 matchId 组成组键。 |
| `matchId` | 匿名比赛标识 | 整场抽样、划分与聚类。 |
| `matchType` | 比赛模式 | 仅保留 solo-fpp。 |
| `winPlacePerc` | [0,1] 归一化最终名次，越高越好 | 响应。 |
| `numGroups` | 数据中记录的比赛组数 | 比赛上下文。 |
| `maxPlace` | 该场现有数据中的最差名次 | 结构核验；不直接进入模型。 |
| `kills` | 击杀次数 | 战斗变量。 |
| `damageDealt` | 累计造成的伤害量，扣除自伤 | 战斗变量。 |
| `walkDistance` | 步行距离，米 | 移动变量。 |
| `boosts` | Boost 物品使用次数 | 补给变量。 |
| `heals` | 治疗物品使用次数 | 恢复变量。 |
| `DBNOs` | 击倒敌方但未直接淘汰的次数 | Solo-FPP 恒零，不进入模型。 |
| `revives` | 救起队友次数 | Solo-FPP 恒零，不进入模型。 |
| `rideDistance` | 载具移动距离，米 | 与其他距离共同识别异常候选。 |
| `swimDistance` | 游泳距离，米 | 与其他距离共同识别异常候选。 |
| `group_size` | 所选数据中同一组的有效记录数 | 构建组等权权重。 |
| `group_weight` | 1 / group_size | 每组记录总权重为一。 |
| `split` | train 或 test | 固定整场 160/40 划分标签。 |

字段来源和全量数据说明见 [pubg_source.md](../data/meta/pubg_source.md)。`test` 标签指本项目留出比赛，不是 Kaggle 的无响应竞赛测试文件。
