# Partitioned survival modelling in Python

English | [简体中文](README.zh-CN.md)

This tutorial shows Excel and R users how to build a three-state partitioned survival model in Python, conduct a cost-effectiveness analysis and verify the results against independent R and Excel implementations. The worked example compares datopotamab deruxtecan with investigator’s choice of chemotherapy from a US payer perspective using survival data from TROPION-Breast01.

## Model and base-case results

The model estimates occupancy in three states: progression-free, progressed disease and death. Both treatment arms use log-logistic extrapolation for progression-free survival (PFS) and generalised gamma extrapolation for overall survival (OS). Costs and quality-adjusted life-years (QALYs) accrue over a 15-year horizon in three-week cycles, with annual discounting at 3.00%. The reference implementation uses the life-table method for within-cycle state occupancy.

The reference estimates are an incremental cost of US$186,033.88 and an incremental gain of 0.037 QALYs for datopotamab deruxtecan. [Arm-level outcomes](output/pyheor/base_case.csv) · [Incremental outcomes](output/pyheor/icer.csv)

## Analysis materials

The repository separates [analysis code](scripts/), [source survival data](data/survival/), [Excel workbooks](workbooks/) and [generated outputs](output/).

| Component | Materials |
|---|---|
| Survival analysis | [Kaplan–Meier reconstruction and parametric fitting](scripts/survival_analysis/README.md) · [Distribution comparisons](output/survival_analysis/parameters/model_comparison.csv) |
| Model implementation | [Python](scripts/models/python/README.md) · [R](scripts/models/r/README.md) · [Excel model](workbooks/model/Dato_vs_ICC_CEA_US.xlsm) · [Excel parameters](workbooks/model/Param_US.xlsx) |
| Base case and sensitivity analyses | [Python outputs](output/pyheor/) · [R outputs](output/heemod/) |
| Implementation scenarios | [Scenario definitions and calculations](scripts/scenarios/run_scenarios.py) |
| Cross-platform verification | [Six black-box checks against expected outcomes](scripts/verification/run_checks.py) |
| Computational performance | [Timing protocol, measurements and summaries](scripts/benchmark/README.md) |

## Implementation scenarios

Each of the seven scenarios changes one setting in the Python base case.

<details>
<summary>Reference settings and modifications for all seven scenarios</summary>

| Scenario | Reference setting | Scenario setting |
|---|---|---|
| OS parameterisation - incorrect generalised gamma scale (1/λ) | Generalised gamma scale λ^(−1/δ) | Set the scale to 1/λ for both OS curves |
| Survival time conversion - 4 weeks per month | 3 × 12/52 months per cycle | 3/4 months per cycle |
| Survival time conversion - 30.44 days per month | 3 × 12/52 months per cycle | 21/30.44 months per cycle |
| Discount rate conversion - linear approximation | Effective cycle rate (1 + r)^y − 1 | Use r × y as the cycle rate |
| State occupancy - start-of-cycle estimate | Mean of start and end occupancy | Weight state costs and QALYs by start-of-cycle occupancy |
| State occupancy - end-of-cycle estimate | Mean of start and end occupancy | Weight state costs and QALYs by end-of-cycle occupancy |
| Survival curve crossing - raise OS to PFS | Cap PFS at OS | Preserve fitted PFS and use OS = max(OS, PFS) at each boundary |

In the discount formula, r denotes the annual rate and y the cycle length in years.

</details>

[Absolute outcomes](output/scenarios/scenario_results.csv) · [Changes relative to the base case](output/scenarios/relative_changes.csv)

## Reproducing the analyses

Run all commands from the repository root.

### Python

The base case and seven scenarios use Python 3.12.14 and PyHEOR 0.6.0.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r scripts/models/python/requirements.txt
.venv/bin/python scripts/models/python/run.py --base-only
.venv/bin/python scripts/scenarios/run_scenarios.py
```

### R

With R 4.5.2, restore the packages used for modelling and survival analysis. [Dependency lockfile](renv.lock)

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript scripts/models/r/run.R --base-only
```

### Cross-platform verification

After setting up Python and R, run the six black-box checks on macOS with desktop Excel installed. [Expected and observed outcomes](output/verification/verification_checks.csv)

```sh
.venv/bin/python scripts/verification/run_checks.py
```

## License

The original code in this repository is released under the [MIT License](LICENSE). Third-party materials retain their respective licenses.
