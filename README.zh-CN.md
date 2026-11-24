# 基于 Python 的分区生存模型

[English](README.md) | 简体中文

本教程面向使用 Excel 或 R 的卫生经济学建模者，以 TROPION-Breast01 为例，演示如何在 Python 中构建三状态分区生存模型、开展成本效果分析，并使用独立的 R 和 Excel 实现验证结果。研究采用美国支付方视角，比较 datopotamab deruxtecan 与研究者选择的化疗方案。

## 模型与基础分析结果

模型估计无进展生存（PFS）、疾病进展后生存及死亡三种状态的队列占比。两个治疗组均采用对数逻辑斯蒂分布外推无进展生存，采用广义 gamma 分布外推总生存（OS）。模型时间跨度为 15 年，周期长度为 3 周，成本与质量调整生命年（QALY）的年贴现率均为 3.00%。参考实现采用生命表法估计周期内的平均状态占比。

在参考实现中，datopotamab deruxtecan 相对化疗方案的增量成本为 186,033.88 美元，增量健康产出为 0.037 QALY。[分组结果](output/pyheor/base_case.csv) · [增量结果](output/pyheor/icer.csv)

## 分析材料

项目按用途分为[分析代码](scripts/)、[生存分析原始数据](data/survival/)、[Excel 工作簿](workbooks/)和[计算结果](output/)。

| 分析内容 | 研究材料 |
|---|---|
| 生存分析 | [Kaplan–Meier 曲线重建与参数拟合](scripts/survival_analysis/README.zh-CN.md) · [分布比较](output/survival_analysis/parameters/model_comparison.csv) |
| 模型实现 | [Python](scripts/models/python/README.zh-CN.md) · [R](scripts/models/r/README.zh-CN.md) · [Excel 模型](workbooks/model/Dato_vs_ICC_CEA_US.xlsm) · [Excel 参数](workbooks/model/Param_US.xlsx) |
| 基础分析与敏感性分析 | [Python 结果](output/pyheor/) · [R 结果](output/heemod/) |
| 实现情景分析 | [情景定义与计算](scripts/scenarios/run_scenarios.py) |
| 跨平台验证 | [六项黑箱验证及预期结果计算](scripts/verification/run_checks.py) |
| 计算性能 | [计时方案、观测记录与汇总](scripts/benchmark/README.zh-CN.md) |

## 实现情景分析

以 Python 基础模型为参照，每次改变一项设定，共评估七个情景。

<details>
<summary>七个情景的参考设定与具体改动</summary>

| 情景名称 | 参考设定 | 情景设定 |
|---|---|---|
| OS 参数化 - 广义 gamma 尺度误设为 1/λ | 广义 gamma 尺度为 λ^(−1/δ) | 两组 OS 曲线的尺度均取 1/λ |
| 生存时间换算 - 每月按 4 周 | 每周期 3 × 12/52 个月 | 每周期 3/4 个月 |
| 生存时间换算 - 每月按 30.44 天 | 每周期 3 × 12/52 个月 | 每周期 21/30.44 个月 |
| 贴现率换算 - 线性近似 | 有效周期贴现率为 (1 + r)^y − 1 | 周期贴现率取 r × y |
| 状态占比 - 按周期初估计 | 取周期初与周期末占比的均值 | 以期初占比计算本周期状态成本与 QALY |
| 状态占比 - 按周期末估计 | 取周期初与周期末占比的均值 | 以期末占比计算本周期状态成本与 QALY |
| 生存曲线交叉 - 将 OS 上调至 PFS | 将 PFS 截至 OS | 保留拟合的 PFS，在交叉处取 OS = max(OS, PFS) |

r 表示年贴现率，y 表示以年为单位的周期长度。

</details>

[各情景绝对结果](output/scenarios/scenario_results.csv) · [相对基础分析的变化](output/scenarios/relative_changes.csv)

## 分析复现

以下命令均在项目根目录执行。

### Python

使用 Python 3.12.14 和 PyHEOR 0.6.0 运行基础分析与七个实现情景。

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r scripts/models/python/requirements.txt
.venv/bin/python scripts/models/python/run.py --base-only
.venv/bin/python scripts/scenarios/run_scenarios.py
```

### R

使用 R 4.5.2，通过 renv 恢复模型与生存分析依赖。[锁文件](renv.lock)

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript scripts/models/r/run.R --base-only
```

### 跨平台验证

完成上述两个环境的配置后，在安装桌面版 Excel 的 macOS 上运行六项黑盒检验。[预期值与三平台结果](output/verification/verification_checks.csv)

```sh
.venv/bin/python scripts/verification/run_checks.py
```

## 许可证

本项目的原创代码采用 [MIT 许可证](LICENSE)。第三方材料遵循各自的许可条款。
