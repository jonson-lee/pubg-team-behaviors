# Final Circle · 建模前交付包

整理日期：2026-10-14（Asia/Shanghai）。本次交付范围为**研究设计、数据核验、固定抽样与 PUBG 研究样本**，供队友审核。

当前课程方案使用 **Solo-FPP**。GitHub 原有 Squad-FPP 材料属于早期方向，两者的研究单位与变量组不同，请以本包为本次审阅对象。

本包是从现有项目整理出的阶段材料，不是建模之前的预注册记录。本地已有首轮试跑，本次导出不含模型结果。

## 队友先看什么

1. [研究提案与分析协议](reports/Proposal.md)：核对研究问题、H1–H3、变量组和方法。
2. [数据准备核验](docs/PREPARATION_REPORT.md)：核对有效样本、共享组结局、异常候选和划分规则。
3. [变量字典](docs/DATA_DICTIONARY.md)：确认变量含义、单位和各标识字段的用途。
4. [项目约定](docs/PROJECT_CONTEXT.md)：确认研究边界及重要方法选择。

需要反馈的重点：Solo-FPP 范围是否符合课程要求；两个战斗变量与三个移动补给变量的选择是否合理；共享组结局和比赛内相关是否解释清楚；四模型与假设检验是否容易在报告中说明。

## 本包内容

| 文件 | 用途 |
| --- | --- |
| `code/prepare_data.R` | 原始数据审计、筛选、整场抽样与固定划分。 |
| `code/run_preparation.R` | 仅运行数据准备的入口。 |
| `data/meta/pubg_source.md` | 来源、字段与原始 SHA-256。 |
| `data/processed/data_audit.json` | 数据准备审计的公开摘要。 |
| `data/processed/selected_matches.csv` | 200 场匿名比赛标识、划分标签与记录数。 |
| `data/processed/pubg_sample.csv` | 可直接使用的研究样本，18,935 条记录、19 列，约 2 MB。 |
| `package_manifest.json` | 导出范围、软件版本及文件校验值。 |

本包包含 PUBG 研究样本。完整原始 CSV、姓名学号、正式提交 PDF、模型代码或结果未纳入。缺失响应记录的标识明细已从公开审计摘要移除。

## 如何使用研究样本

解压后可直接读取 `data/processed/pubg_sample.csv`。它包含响应、行为字段、组权重和 `split` 标签；分析变量含义见变量字典。训练与留出按 `matchId` 区分，不能重新按记录随机划分。

```r
sample <- read.csv("data/processed/pubg_sample.csv")
```

GitHub 仓库根目录的 `data/processed/pubg_sample.csv` 同步保存该样本，文件校验值与本包一致。

## 如何从原始文件复现数据准备

需要 R、`data.table` 和 `jsonlite`。已核验版本为 R 4.4.2、`data.table` 1.16.2、`jsonlite` 1.8.9。

```r
install.packages(c("data.table", "jsonlite"))
```

按 [数据来源说明](data/meta/pubg_source.md) 自行下载 `train_V2.csv`，放在本包根目录下的 `data/raw/pubg/`。进入本包目录后执行：

```bash
Rscript code/run_preparation.R
```

入口会核验原始文件 SHA-256，并生成 `data/processed/pubg_sample.csv`、`selected_matches.csv`、`data_audit.json`。生成的本地完整审计含被排除记录的匿名标识；公开版仅保留该记录的数量与剔除规则。原始文件保持只读，入口不拟合模型。

## 后续阶段

队友审阅研究范围、变量解释、抽样与推断方案后，再按小组讨论推进建模结果复核、课程报告和展示。
