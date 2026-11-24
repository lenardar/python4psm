# 生存分析

[English](README.md) | 简体中文

本分析根据 TROPION-Breast01 全球人群的生存曲线重建 Dato-DXd 组与研究者选择化疗（ICC）组的个体患者数据，供美国支付方视角的成本效果分析使用。

## 目录

| 目录 | 内容 |
| --- | --- |
| `data/survival/` | 按终点和治疗组保存的 KM 曲线数字化坐标 |
| `output/survival_analysis/data/` | 预处理坐标、风险人数核对结果、重建的个体患者数据（IPD） |
| `scripts/survival_analysis/` | 数据转换、IPD 重建和生存模型拟合代码 |
| `output/survival_analysis/parameters/` | 最终拟合参数及模型选择结果 |

文件名以 `pfs_` 或 `os_` 区分终点，涉及单组数据时再加 `dato` 或 `icc`。

## 参考文献与曲线来源

### PFS：主要结果，Figure 2A

Bardia A, et al. Datopotamab Deruxtecan Versus Chemotherapy in Previously Treated Inoperable/Metastatic Hormone Receptor–Positive Human Epidermal Growth Factor Receptor 2–Negative Breast Cancer: Primary Results From TROPION-Breast01. *Journal of Clinical Oncology*. 2025;43(3):285–296.

- DOI：[10.1200/JCO.24.00920](https://doi.org/10.1200/JCO.24.00920)
- [免费全文及图表（PMC）](https://pmc.ncbi.nlm.nih.gov/articles/PMC11771365/)
- [期刊 PDF](https://ascopubs.org/doi/pdfdirect/10.1200/JCO.24.00920)
- 曲线：全球意向治疗（ITT）人群，盲态独立中心评审（BICR）的 PFS，**Figure 2A**。
- 核对指标：HR 0.63（95% CI 0.52–0.76）。
- 年份说明：2024 年在线发表，2025 年正式卷期。

### OS：最终分析，Figure 1A

Datopotamab deruxtecan versus chemotherapy in previously treated inoperable/metastatic hormone receptor-positive, HER2-negative breast cancer: final overall survival analysis of the phase III TROPION-Breast01 study. *Annals of Oncology*. 2026;37(5):663–674.

- DOI：[10.1016/j.annonc.2025.12.017](https://doi.org/10.1016/j.annonc.2025.12.017)
- [开放获取全文及图表（ScienceDirect）](https://www.sciencedirect.com/science/article/pii/S0923753425063379)
- [期刊全文](https://www.annalsofoncology.org/article/S0923-7534%2825%2906337-9/fulltext)
- 曲线：全球 ITT 人群的最终 OS，**Figure 1A**。
- 核对指标：中位 OS 为 Dato-DXd 18.6 个月、ICC 18.3 个月；HR 1.01（95% CI 0.83–1.22）。
- 年份说明：2025 年在线发表，2026 年正式卷期。

## 重画提取曲线

在项目根目录运行：

```sh
Rscript scripts/survival_analysis/plot_digitized_curves.R
```

依赖 R 包 `ggplot2`。输出为 `output/survival_analysis/images/pfs_redrawn.png`、`output/survival_analysis/images/os_redrawn.png` 及对应的 PDF 矢量图。

图中以直线依次连接原始提取点。显示范围限定为时间非负、概率 0–1：OS 的 Dato 数据有 3 个概率略大于 1 的点，ICC 有 1 个负时间点及 1 个概率略大于 1 的点，脚本会打印这些数量。


## IPD 重建

使用 `IPDfromKM 0.1.10` 的 `preprocess(maxy = 1)` 和 `getIPD()`，风险人数来自两张原图的对应面板。保留包的默认预处理（去除部分异常点、处理回升及越界坐标、补充起点）。预处理后的坐标单独保存。

```sh
Rscript scripts/survival_analysis/reconstruct_ipd.R
```

- `output/survival_analysis/data/*_ipd.csv`：四组重建数据；时间单位为月，`status=1` 表示事件、`status=0` 表示删失。四组独立重建，`patient_id` 在各文件内独立编号。
- `output/survival_analysis/data/*_preprocessed.csv`：包预处理后的点。
- `output/survival_analysis/data/ipd_summary.csv`：样本数、事件数、中位生存期及与有效原始点的误差。
- `output/survival_analysis/data/ipd_risk_counts.csv`：原图风险人数与重建数据逐时点对照。
- `output/survival_analysis/images/*_ipd_overlay.png`、对应 PDF：重建 KM 阶梯线与原始提取点叠图。
- `output/survival_analysis/sessions/reconstruct_ipd_session.txt`：运行环境版本。

OS 输入已发表事件数（Dato 223、ICC 213）；PFS 重建采用 `tot.events=NULL`。两组 OS 重建事件数分别为 219 和 211。重建中位 PFS 为 6.92/4.73 月（发表值 6.9/4.9）；中位 OS 为 19.10/18.19 月（发表值 18.6/18.3）。36 个风险人数检查点中，35 个一致，OS ICC 的 15 月为 212（原图 213）。

参数拟合使用上述重建 IPD。曲线重建误差以数字化坐标与重建阶梯线在对应时点的生存概率差衡量。

方法参考：Liu N, Zhou Y, Lee JJ. *IPDfromKM: reconstruct individual patient data from published Kaplan–Meier survival curves*. BMC Medical Research Methodology. 2021;21:111. [全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC8168323/)；[包文档](https://search.r-project.org/CRAN/refmans/IPDfromKM/html/preprocess.html)。


## 参数生存模型及 AIC/BIC

使用 `flexsurv 2.3.2`，四组分别拟合 Exponential、Weibull、Gompertz、Log logistic、Log normal、Generalized Gamma，共 24 个模型。时间单位为月。

```sh
Rscript scripts/survival_analysis/fit_survival.R
```

- `output/survival_analysis/parameters/*_excel_parameters.csv`：按 Excel「疗效」页的分布顺序和逐参数行布局，前五列为分布、参数、估计值、AIC、BIC；后附公式兼容标记及说明。
- `output/survival_analysis/parameters/model_comparison.csv`：24 个模型的 logLik、AIC、BIC、组内排名及与组内最小值之差。
- `output/survival_analysis/parameters/flexsurv_parameters.csv`：原生参数、标准误及 95% 置信区间。
- `output/survival_analysis/parameters/flexsurv_models.rds`：全部模型对象，保留协方差等信息。
- `output/survival_analysis/parameters/parameter_conversion_check.csv`：转换后生存函数与 flexsurv 在 0.001–180 月检查点的最大概率差。

AIC = −2 logLik + 2k；BIC = −2 logLik + k log(n)。n 为本组全部重建患者数（含删失），k 为自由参数数。在每个治疗组和终点内对六种模型排序。参数置信区间以重建的 IPD 为条件估计。

### 与原 Excel 的参数转换

| 分布 | Excel 参数定义（对应 flexsurv 输出） |
| --- | --- |
| Exponential | λ = rate |
| Weibull | λ = scale^(−shape)，γ = shape |
| Gompertz | λ = rate，γ = shape |
| Log logistic | λ = log(scale)，γ = 1/shape |
| Log normal | λ = meanlog，γ = sdlog |
| Generalized Gamma | γ = 1/Q²，δ = Q/σ，λ = exp(−μδ)/Q² |

广义 Gamma 使用 `gengamma` 的稳定参数化估计 μ、σ、Q。Q > 0 时，上述转换满足原 Excel 的 S(t) = 1 − GammaCDF(λt^δ; γ, 1)。Dato-DXd 组 PFS 的 Q < 0，对应的生存函数为 S(t) = GammaCDF(λt^δ; γ, 1)。 该项已标记 `excel_formula_compatible=FALSE`，AIC 和 BIC 基于允许 Q 取正值或负值的 `gengamma` 拟合。`gengamma.orig` 对应 Q > 0 的参数空间。各分布在 t = 0 时均取 S(0) = 1；Gompertz 的 γ = 0 极限为指数分布。

24 个模型均收敛，参数协方差矩阵均为正定。参数转换前后的生存概率最大差值小于 1e-8。AIC 和 BIC 的排序结果均显示，Dato-DXd 组 PFS 以对数正态分布拟合最优，ICC 组 PFS 以对数逻辑斯蒂分布最优，两组 OS 均以 Weibull 分布最优。成本效果基础模型两组均采用对数逻辑斯蒂分布拟合 PFS、广义 gamma 分布拟合 OS。

参数化参考：[flexsurvreg 官方文档](https://chjackson.github.io/flexsurv/reference/flexsurvreg.html)、[Generalized Gamma 原参数化](https://chjackson.github.io/flexsurv/reference/GenGamma.orig.html)。
