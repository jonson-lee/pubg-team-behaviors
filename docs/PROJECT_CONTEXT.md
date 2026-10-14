# 当前项目约定

更新日期：2026-10-14（Asia/Shanghai）。

Final Circle 的 IBA6101 项目使用 `solo-fpp` 的玩家比赛记录。响应为 `winPlacePerc`；战斗变量为 `kills`、`damageDealt`；移动与恢复变量为 `walkDistance`、`boosts`、`heals`；比赛上下文为 `numGroups`。

组键为 `(matchId, groupId)`。抽样、划分和推断按比赛处理，保留有效多记录组和异常候选；记录 Id 不能确认跨比赛真实玩家身份。结论限定为赛后关联。

完整当前协议、方法选择和数据核验统一放在 [准备材料](../deliverables/pre_model/README.md)。当前入口为 `deliverables/pre_model/code/run_preparation.R`，根目录 `code/` 和旧设计文档属于历史方向。

原始数据只读；准备输出经暂存、备份后替换，错误或 R 中断时回滚，恢复失败保留备份路径。模式校验固定要求 `solo-fpp`。当前样本、比赛名单和公开审计保持原值。

云端更新限于准备代码、合成回归测试和脱敏说明；排除成员资料、完整原始数据、被排除记录的标识明细及新的分析成果。来源和使用条款见 [来源卡](../data/meta/pubg_source.md)。
