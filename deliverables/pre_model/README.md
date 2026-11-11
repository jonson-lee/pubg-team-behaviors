# Solo-FPP 数据准备与 H3 复现

本项目研究 200 场 Solo-FPP 比赛的赛后行为与归一化最终名次。准备脚本依据固定种子，从原始竞赛数据生成 18,935 条研究记录和 160/40 场训练及留出划分。 [研究协议](reports/Proposal.md) · [数据准备核验](docs/PREPARATION_REPORT.md) · [变量字典](docs/DATA_DICTIONARY.md)

## 准备环境与输入

使用 R、`data.table`、`jsonlite` 和 `shasum`。通过 Kaggle 竞赛页面按规则取得 `train_V2.csv`，解压后放在仓库内的 `deliverables/pre_model/data/raw/pubg/train_V2.csv`。准备程序按来源卡的 SHA-256 核验输入。 [数据来源与校验值](data/meta/pubg_source.md)

在仓库根目录依次执行以下命令。

```bash
Rscript --vanilla deliverables/pre_model/code/run_preparation.R
Rscript --vanilla deliverables/pre_model/code/run_h3_sensitivity.R
Rscript --vanilla deliverables/modeling/run_team_modeling.R
```

准备程序在 `deliverables/pre_model/data/processed/` 生成固定样本、比赛名单与审计信息。H3 程序在 `deliverables/pre_model/reports/analysis/h3-sensitivity-2026-11-11/` 生成四个规格的结果及运行清单。团队程序读取同一份生成样本，将结果写入 `deliverables/modeling/runs/` 下的独立运行目录。这些目录用于本地复现。 [H3 汇总结果](../modeling/H3_Sensitivity_Summary.md) · [团队建模说明](../modeling/README.md)

## 合成数据测试

以下测试使用临时合成记录，覆盖抽样、组权重、输出回滚、CR1 推断及单一战斗指标的整场 bootstrap。

```bash
Rscript --vanilla deliverables/pre_model/code/tests/test_preparation.R
Rscript --vanilla deliverables/pre_model/code/tests/test_statistics.R
```
