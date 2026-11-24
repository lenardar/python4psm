# Python 模型实现

[English](README.md) | 简体中文

美国支付方视角模型的运行环境为 Python 3.12.14 和 PyHEOR 0.6.0。模型输入见 [parameters.py](parameters.py)，状态占比、成本和 QALY 的计算见 [model.py](model.py)。

在本目录执行以下命令。

```sh
python3 -m venv ../../../.venv
../../../.venv/bin/python -m pip install -r requirements.txt
../../../.venv/bin/python run.py --base-only
../../../.venv/bin/python run.py --psa 1000
```

结果表和图形保存在 [output/pyheor](../../../output/pyheor/)。

基础分析使用内置终末状态导出 `model.xlsx`，并输出各策略相对于基准模型的总成本差额。

模型时限为 15 年，每个周期为 3 周。两组均用对数逻辑斯蒂分布外推 PFS，用广义 gamma 分布外推 OS。药品成本按周期输入，调整药价时需重新计算每周期费用。基准分析计入不良事件费用，不良事件效用损失设为零（`ae_enabled=0`）。

OWSA 默认上下浮动 10%，贴现率取 0–5%。PSA 按参数文件指定的分布串行抽样，随机种子为 20261031。生存参数独立抽样；未设置分布的参数固定。
