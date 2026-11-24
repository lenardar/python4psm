# Reconstruction and extrapolation of survival outcomes

English | [简体中文](README.zh-CN.md)

The analysis reconstructs individual patient data from published Kaplan–Meier curves for the global intention-to-treat population of TROPION-Breast01. Progression-free survival (PFS) is taken from the blinded independent central review in Figure 2A of the primary analysis. Overall survival (OS) is taken from Figure 1A of the final OS analysis. [Primary analysis](https://doi.org/10.1200/JCO.24.00920) · [Final OS analysis](https://doi.org/10.1016/j.annonc.2025.12.017)

## Reproduction

Execute the scripts in the following order from the project root. The first script uses ggplot2, the second uses IPDfromKM 0.1.10 and the third uses flexsurv 2.3.2. Package versions are reported in the [session records](../../output/survival_analysis/sessions/). [Analysis code](./)

```sh
Rscript scripts/survival_analysis/plot_digitized_curves.R
Rscript scripts/survival_analysis/reconstruct_ipd.R
Rscript scripts/survival_analysis/fit_survival.R
```

## Data and reconstruction

Reconstruction uses the [digitised coordinates](../../data/survival/) from the published Kaplan–Meier curves. [Diagnostic plots](../../output/survival_analysis/images/) show the digitised profiles and overlays of reconstructed Kaplan–Meier estimates. The [data directory](../../output/survival_analysis/data/) includes preprocessed coordinates, reconstructed event records, risk-set counts and reconstruction diagnostics. Times are expressed in months. In the reconstructed files, status 1 indicates an event and status 0 indicates censoring. Reconstruction is independent for each arm and endpoint, so patient identifiers apply only within each file.

The reconstruction uses digitised coordinates and published numbers at risk. Published OS event counts (223 and 213 for datopotamab deruxtecan and chemotherapy, respectively) were supplied as auxiliary inputs. The reconstructed counts were 219 and 211. PFS reconstruction used no total-event constraint. Reconstructed median PFS was 6.92 and 4.73 months, and median OS was 19.10 and 18.19 months. Of 36 risk-set counts, 35 matched the published counts. The remaining difference was one patient in the chemotherapy OS risk set at month 15. [Reconstruction method](https://pmc.ncbi.nlm.nih.gov/articles/PMC8168323/)

## Parametric extrapolation

Six distributions were fitted separately for each arm and endpoint: exponential, Weibull, Gompertz, log-logistic, log-normal and generalised gamma. Model selection statistics describe relative fit within each arm and endpoint. Parameter uncertainty is conditional on the reconstructed data. The economic base case uses log-logistic PFS and generalised gamma OS in both arms. [Model comparisons](../../output/survival_analysis/parameters/model_comparison.csv) · [Parameter estimates](../../output/survival_analysis/parameters/flexsurv_parameters.csv) · [Fitted models](../../output/survival_analysis/parameters/flexsurv_models.rds)

The Excel parameter tables record the parameter mapping and compatibility with the workbook formulae. For generalised gamma fits, the sign of the flexsurv shape parameter Q determines the required gamma tail. The datopotamab deruxtecan PFS fit has negative Q and requires the lower tail. Agreement between the transformed and native survival functions was evaluated over 0.001–180 months. [Conversion checks](../../output/survival_analysis/parameters/parameter_conversion_check.csv)
