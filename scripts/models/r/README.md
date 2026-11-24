# R implementation

English | [简体中文](README.zh-CN.md)

The US payer model uses heemod 1.1.0. Model inputs are specified in [parameters.R](parameters.R), and [model.R](model.R) defines the state occupancy and reward calculations.

## Execution

Using R 4.5.2, execute the following commands from the repository root to restore the [locked dependencies](../../../renv.lock) and run the analyses.

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript scripts/models/r/run.R --base-only
Rscript scripts/models/r/run.R --psa 1000
```

Results and plots are written to [output/heemod](../../../output/heemod/). Both arms use log-logistic progression-free survival (PFS) and generalised gamma overall survival (OS) over 15 years in three-week cycles. PFS is capped at OS. The life-table method estimates state occupancy. Terminal care costs accrue from new deaths in each cycle. Per-cycle drug costs require revision when unit prices change. The reference case includes adverse-event costs and sets adverse-event disutility to zero.

Deterministic sensitivity analyses generally vary inputs by ±10%, with discount rates ranging from 0% to 5%. Probabilistic sensitivity analysis uses the distributions specified in the parameter file and seed 20261031. Survival parameters are sampled independently. Inputs without a specified distribution remain fixed.
