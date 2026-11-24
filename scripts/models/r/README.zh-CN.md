# R 模型实现

[English](README.md) | 简体中文

美国支付方视角的模型使用 heemod 1.1.0。模型输入见 [parameters.R](parameters.R)，状态占比、成本和 QALY 的计算见 [model.R](model.R)。

## 安装与运行

使用 R 4.5.2，在项目根目录恢复[锁文件](../../../renv.lock)中的包版本并运行分析。

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript scripts/models/r/run.R --base-only
Rscript scripts/models/r/run.R --psa 1000
```

结果表和图形保存在 [output/heemod](../../../output/heemod/)。

模型时限为 15 年，每个周期为 3 周。两组均用对数逻辑斯蒂分布外推 PFS，用广义 gamma 分布外推 OS。药品成本按周期输入，调整药价时需重新计算每周期费用。基准分析计入不良事件费用，不良事件效用损失设为零（`ae_enabled=0`）。

当 PFS 高于 OS 时，模型取 OS 的值作为 PFS。周期内状态占比按生命表法估计，临终照护费用按本周期新增死亡人数计算。

DSA 默认上下浮动 10%，贴现率取 0–5%。PSA 使用参数文件指定的分布，种子为 20261031。生存参数独立抽样；未设置分布的参数固定。
