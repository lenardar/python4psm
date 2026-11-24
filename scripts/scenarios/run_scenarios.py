import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pyheor as ph

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "models" / "python"))
from model import build_model, survival_curve
from parameters import REFERENCE_RESULTS, ROOT


SCENARIOS = {
    "base": "Reference implementation",
    "scale": "OS parameterisation - incorrect generalised gamma scale (1/λ)",
    "four_weeks": "Survival time conversion - 4 weeks per month",
    "calendar_month": "Survival time conversion - 30.44 days per month",
    "discount": "Discount rate conversion - linear approximation",
    "beginning": "State occupancy - start-of-cycle estimate",
    "end": "State occupancy - end-of-cycle estimate",
    "crossing": "Survival curve crossing - raise OS to PFS",
}


def boundary_curves(model, params, config, arm, scenario):
    cycles = np.arange(model.n_cycles + 1)
    months_per_cycle = model.cycle.in_unit("month")
    if scenario == "four_weeks":
        months_per_cycle = config["cycle_weeks"] / 4
    elif scenario == "calendar_month":
        months_per_cycle = config["cycle_weeks"] * 7 / 30.44
    months = cycles * months_per_cycle
    curves = {}
    for endpoint in ("pfs", "os"):
        prefix = f"{arm}_{endpoint}"
        fitted = survival_curve(params, prefix, config["distributions"][arm][endpoint])
        if scenario == "scale" and endpoint == "os":
            fitted = ph.from_flexsurv(
                "gengamma.orig", shape=params[f"{prefix}_gg_delta"],
                scale=1 / params[f"{prefix}_gg_lambda"], k=params[f"{prefix}_gg_shape"],
            )
        curves[endpoint] = fitted.survival(months)
    return cycles, curves["pfs"], curves["os"]


def run(scenario):
    if scenario == "discount":
        model, records, config = build_model(cycle_rate=lambda r, y: r * y)
    else:
        model, records, config = build_model()
    params = {name: record["base"] for name, record in records.items()}
    if scenario in ("beginning", "end"):
        model.method = scenario

    for arm in model.strategy_names:
        cycles, pfs, os = boundary_curves(model, params, config, arm, scenario)
        if scenario == "base":
            crossed = np.flatnonzero(pfs > os)
            if crossed.size:
                first = crossed[0]
                print(f"{arm}: first raw crossing at boundary {first}, "
                      f"{first * model.cycle.years:.3f} years; OS {os[first]:.4%}")
        if scenario in ("scale", "four_weeks", "calendar_month", "crossing"):
            if scenario == "crossing":
                os = np.maximum(os, pfs)
            model.set_survival(arm, "PFS", ph.KaplanMeier(cycles, pfs))
            model.set_survival(arm, "OS", ph.KaplanMeier(cycles, os))

    summary = model.run_base_case().summary().set_index("Strategy")
    row = {}
    for arm, label in model.strategy_labels.items():
        for col, metric in [("Total Cost", "cost"), ("QALYs", "qaly"), ("LYs", "ly")]:
            row[f"{arm}_{metric}"] = summary.loc[label, col]
    for metric in ("cost", "qaly", "ly"):
        row[f"delta_{metric}"] = row[f"dato_{metric}"] - row[f"icc_{metric}"]
    row["icer"] = row["delta_cost"] / row["delta_qaly"]
    return row


def main():
    results = pd.DataFrame.from_dict(
        {label: run(key) for key, label in SCENARIOS.items()}, orient="index"
    ).rename_axis("Scenario")
    reference = results.iloc[0]
    for arm, expected in REFERENCE_RESULTS.items():
        for metric, value in expected.items():
            np.testing.assert_allclose(reference[f"{arm}_{metric}"], value, rtol=1e-11)

    metrics = ["icc_cost", "dato_cost", "icc_qaly", "dato_qaly", "icer"]
    changes = 100 * (results[metrics].iloc[1:] / reference[metrics] - 1)
    changes.columns = ["ICC cost (%)", "Dato-DXd cost (%)", "ICC QALYs (%)",
                       "Dato-DXd QALYs (%)", "ICER (%)"]
    changes["Interpretation"] = np.where(
        (results.delta_cost.iloc[1:] < 0) & (results.delta_qaly.iloc[1:] < 0),
        "Both increments reverse sign (Dato-DXd less costly and less effective)", ""
    )
    out = ROOT / "output" / "scenarios"
    out.mkdir(parents=True, exist_ok=True)
    results.to_csv(out / "scenario_results.csv")
    changes.to_csv(out / "relative_changes.csv")
    print(results.to_string())
    print(changes.to_string())


if __name__ == "__main__":
    main()
