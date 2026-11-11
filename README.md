# Final Circle · PUBG 数据准备

当前课程方案使用 `solo-fpp` 玩家比赛记录，研究赛后行为与最终名次的关联。

- [研究协议与准备材料](deliverables/pre_model/README.md)
- [研究样本](data/processed/pubg_sample.csv)：18,935 条记录、200 场，固定 160/40 场划分。
- [原始数据获取与校验](data/meta/README.md)
- [更新日志](CHANGELOG.md)

## 运行数据准备

在 `deliverables/pre_model/` 中，按来源说明下载 `train_V2.csv` 到 `data/raw/pubg/`。需要 R、`data.table`、`jsonlite` 和 `shasum`。

```bash
Rscript code/run_preparation.R
Rscript code/tests/test_preparation.R
```

准备脚本核验原始 SHA-256、计数字段和固定比赛模式；三个输出先暂存和备份，替换失败则回滚。测试使用合成数据，不依赖模型代码或分析结果。固定样本的内容与校验值保持不变。

本轮更新仅包含准备代码、数据测试及脱敏文档。完整原始文件、成员资料、正式提交 PDF 和本地分析成果不随此次更新发布。数据使用受 [Kaggle Rules](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/rules) 约束，公开再分发的明确依据仍待确认。

根目录 `code/`、旧提案与历史 EDA 属于早期 Squad-FPP 方向。当前审阅以 `deliverables/pre_model/` 为准；旧材料保留历史标记，不能与当前模式或统计口径混用。
