# Final Circle · Solo-FPP 准备材料

更新日期：2026-10-14（Asia/Shanghai）。本目录包含当前研究协议、数据准备代码及既有研究样本。它是阶段材料的导出，不是预注册记录；本轮不发布新的分析成果。

## 阅读入口

- [研究协议](reports/Proposal.md)：研究问题、变量组与方法。
- [准备核验](docs/PREPARATION_REPORT.md)：筛选、抽样与划分。
- [变量字典](docs/DATA_DICTIONARY.md)和[方法约定](docs/PROJECT_CONTEXT.md)。
- [样本](data/processed/pubg_sample.csv)、[比赛名单](data/processed/selected_matches.csv)及[公开审计](data/processed/data_audit.json)。样本为 18,935 条、200 场，与仓库根目录副本使用同一文件。

## 运行

需要 R、`data.table`、`jsonlite` 和 `shasum`；已验证 R 4.4.2、data.table 1.16.2、jsonlite 1.8.9。按 [来源卡](data/meta/pubg_source.md) 下载 `train_V2.csv` 到本目录的 `data/raw/pubg/`，再执行：

```bash
Rscript code/run_preparation.R
Rscript code/tests/test_preparation.R
```

准备入口核验来源哈希、整数计数与固定 `solo-fpp` 模式，输出三个 processed 文件。输出先暂存与备份，替换错误或 R 中断时恢复原状态；恢复失败保留备份并报告路径。此恢复保证不涵盖进程强制终止、掉电或多进程并发写入。

回归测试只使用合成记录，覆盖模式误改／缺列／缺失、只读目标、暂存／备份失败、发布回滚、首次生成清理和备份保留，无需模型代码、结果或原始下载文件。固定样本、比赛名单和公开审计保持原值；文件校验见 `package_manifest.json`。

本轮不加入成员资料、完整原始 CSV、正式提交 PDF、模型代码或新模型结果。公开审计不含被排除记录的标识明细；本地重建的完整审计包含该明细，不要直接覆盖公开摘要或分享恢复备份。数据使用受官方规则约束，公开再分发的明确依据仍待确认。
