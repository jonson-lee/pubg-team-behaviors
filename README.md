# Final Circle · PUBG 课程项目

当前课程方案使用 `solo-fpp` 玩家比赛记录，研究赛后行为与最终名次的关联。

- [研究协议与准备材料](deliverables/pre_model/README.md)
- [建模补充与复现说明](deliverables/modeling/README.md)
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

数据准备与建模补充的材料范围见各自入口。数据来源和使用说明见[数据说明](data/meta/README.md)。

根目录 `code/`、旧提案与历史 EDA 属于早期 Squad-FPP 方向。当前 Solo-FPP 审阅使用上面的研究协议、数据准备和建模入口；旧材料保留历史标记，不能与当前模式或统计口径混用。
