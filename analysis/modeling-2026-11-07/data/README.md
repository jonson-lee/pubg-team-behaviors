# 数据说明

`pubg_sample.csv` 是本次建模使用的分析样本。从原有 `建模-1107.RData` 中的 `df` 对象导出；该对象与工作区中的 `pubg_sample` 内容一致。导出没有重新抽样、筛选记录、修改变量或重新划分训练集和测试集。

样本共有 18,935 行、19 列；其中 `split` 为 `train` 的记录有 15,204 行，为 `test` 的记录有 3,731 行。每一行是一条玩家记录。本次模型直接使用的结果变量、六个解释变量和划分标签没有缺失值。

## 本次分析使用的字段

| 字段 | 含义 |
| --- | --- |
| `winPlacePerc` | 标准化的最终排名，0–1，越高表示排名越靠前 |
| `numGroups` | 比赛中的队伍数量 |
| `kills` | 击杀次数 |
| `damageDealt` | 造成的伤害量 |
| `walkDistance` | 步行距离 |
| `boosts` | 使用增益物品的次数 |
| `heals` | 使用治疗物品的次数 |
| `split` | 已保存的训练集或测试集标签 |

其余字段原样保留：`Id`、`groupId`、`matchId`、`matchType`、`maxPlace`、`DBNOs`、`revives`、`rideDistance`、`swimDistance`、`group_size`、`group_weight`。本次脚本不使用这些字段拟合模型，也不使用 `group_weight` 加权。

原文件夹未提供原始数据下载地址、完整字段字典、样本筛选脚本或训练测试划分脚本，因此本目录支持从已保存的分析样本重新建模，不覆盖从原始数据开始的全部处理过程。`group_size` 和 `group_weight` 的具体生成规则也未随原文件提供。
