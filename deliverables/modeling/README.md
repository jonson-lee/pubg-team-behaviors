# PUBG Solo-FPP 建模补充

团队在固定的 200 场比赛样本上复现了原尺度 OLS、`log1p` OLS 和组等权 WLS，并补充了训练集上的击杀系数分解、逐项删变量、二次项和 Cook 距离诊断。结果与使用限制见[建模审阅摘要](Modeling_Review.md)。

## 运行

在项目或仓库根目录运行下列命令。脚本使用基础 R，默认读取准备程序生成的 `deliverables/pre_model/data/processed/pubg_sample.csv`，并校验固定样本的 MD5 为 `c40153ed85bdc34afc0d99be24eaa740`。先按[数据准备说明](../pre_model/README.md)从竞赛原始数据生成固定样本。

```bash
Rscript --vanilla deliverables/modeling/run_team_modeling.R
```

也可以指定样本路径和输出父目录。

```bash
Rscript --vanilla deliverables/modeling/run_team_modeling.R /path/to/pubg_sample.csv /path/to/output
```

默认输出在本目录的 `runs/` 下，每次运行生成独立结果目录。查看该目录中的 `STATUS.txt` 和 `00_audit/` 确认运行状态与历史数值对照。逐条预测、比赛标识、模型对象、诊断图和运行日志均属于本地运行文件。版本库提供脚本、使用说明和聚合摘要。

## 分析范围

- 全 200 场用于既有四模型的关联分析、按比赛聚类的 CR1 推断和 H3 整场 bootstrap。三个规格共享由种子 `6103` 生成的 1,000 次抽样。
- 160 场训练集用于训练探索、删变量、二次项、Cook 敏感性和候选预测拟合。40 场既有留出集用于评估训练拟合。
- 团队脚本的留出误差按记录等权计算，另报告按场平均 MAE。组等权 WLS 的拟合采用组内记录数倒数权重。主分析另有按组等权评价的 WLS 指标，比较时请对照权重口径。
- 本入口源于团队整合代码、建模输出和原研究协议。部分统计模块根据已提供的结果与方法重建。报告中的候选比较来自已查看的留出集，属于补充评价。
