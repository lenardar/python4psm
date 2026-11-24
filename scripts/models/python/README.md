# Python implementation

English | [简体中文](README.zh-CN.md)

The US payer model was run with Python 3.12.14 and PyHEOR 0.6.0. Model inputs are specified in [parameters.py](parameters.py), and [model.py](model.py) defines the state occupancy and reward calculations.

## Execution

Execute the following commands from this directory.

```sh
python3 -m venv ../../../.venv
../../../.venv/bin/python -m pip install -r requirements.txt
../../../.venv/bin/python run.py --base-only
../../../.venv/bin/python run.py --psa 1000
```

The analysis writes results and plots to [output/pyheor](../../../output/pyheor/). The 15-year model uses three-week cycles, log-logistic progression-free survival and generalised gamma overall survival in each arm. Changes to unit drug prices require corresponding revisions to the per-cycle drug costs. The reference case includes adverse-event costs and sets the adverse-event disutility switch to zero.

The base-case run exports `model.xlsx` with a dedicated terminal state and prints the change in total cost relative to the reference case for each strategy.

One-way sensitivity analyses generally vary inputs by ±10%, with discount rates ranging from 0% to 5%. Probabilistic sensitivity analysis uses serial execution, the distributions specified in the parameter file and seed 20261031. Survival parameters are sampled independently. Inputs without a specified distribution remain fixed.
