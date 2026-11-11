# PUBG 数据说明

项目已确定使用 Kaggle PUBG Finish Placement Prediction 数据。

## 已提交的研究样本

- [pubg_sample.csv](../processed/pubg_sample.csv)：Solo-FPP 200 场比赛、18,935 条记录、19 列，约 2 MB。
- 样本包含 winPlacePerc、行为字段、比赛与组标识、组权重及 train/test 标签。
- 训练 160 场、15,204 条记录；留出 40 场、3,731 条记录。保留原有整场划分。
- SHA-256：`9a42ab4c47e2ed07cd95fe5035be577027fb3ae7cfdfd847d2cb7f2f038e048c`。

变量字典、抽样名单和准备审计见 [队友交付包](../../deliverables/pre_model/README.md)。包内研究样本与仓库根目录使用同一文件。

## 原始文件获取

完整 train_V2.csv 在本地保留。需要从原始数据重建样本时，通过 [Kaggle 官方数据页面](https://www.kaggle.com/competitions/pubg-finish-placement-prediction/data) 下载 train_V2.csv，按包内说明放入 data/raw/pubg/ 并执行准备入口。原始下载文件保持只读。

来源、原始 SHA-256 和全量核验见 [pubg_source.md](pubg_source.md)。
