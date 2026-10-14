# PUBG 数据说明

已提交的 [研究样本](../processed/pubg_sample.csv) 为 18,935 条、19 列、200 场 Solo-FPP 比赛，固定训练／留出划分为 160／40 场。样本及包内副本保持原值，SHA-256 为 `9a42ab4c47e2ed07cd95fe5035be577027fb3ae7cfdfd847d2cb7f2f038e048c`。

从 [Kaggle 官方 Data 页](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/data) 获取 `train_V2.csv`，放到 `deliverables/pre_model/data/raw/pubg/` 后执行准备入口。原始训练文件的 SHA-256 必须为 `435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36`，不能用未知文件自行计算的哈希跳过来源审核。

来源与条款见 [pubg_source.md](pubg_source.md)，变量、准备审计和运行方法见 [准备材料](../../deliverables/pre_model/README.md)。本轮未增加源记录；公开再分发的明确依据仍待确认。
