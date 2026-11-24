import shutil
import subprocess
import sys
import tempfile
from io import StringIO
from pathlib import Path

import numpy as np
import pandas as pd
import pyheor as ph
from scipy.special import gammaincc

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(ROOT / "scripts/models/python"))
from model import build_model
from parameters import AE, COSTS, SURVIVAL, UTILITIES, parameters


def python_outputs():
    records, _ = parameters()

    def totals(overrides=None, flat=False):
        model, _, _ = build_model()
        for key, value in (overrides or {}).items():
            model.add_param(key, value)
        if flat:
            for arm in model.strategy_names:
                for endpoint in ("PFS", "OS"):
                    model.set_survival(arm, endpoint, ph.KaplanMeier([0, model.n_cycles], [1., 1.]))
        return model.run_base_case().summary().set_index("Strategy")

    baseline = totals()
    terminal = baseline["Total Cost"] - totals({"cost_terminal": 0})["Total Cost"]
    units = dict.fromkeys(UTILITIES, 1)
    no_discount = totals({"discount_cost": 0, "discount_qaly": 0})
    matched = {name: records[name.replace("dato", "icc")]["base"]
               for name in records if "dato" in name}
    matched["cost_port"] = 0
    equal = totals(matched)
    delta = equal.loc["Dato"] - equal.loc["ICC"]
    costs = {name: 0 for name in records if name.startswith(("cost_", "ae_cost_"))}
    flat = totals({**units, "discount_qaly": 0}, flat=True)
    return pd.DataFrame({"qaly": totals(units)["QALYs"], "terminal": terminal,
                         "no_dr_cost": no_discount["Total Cost"], "no_dr_qaly": no_discount["QALYs"],
                         "zero": totals(costs)["Total Cost"], "years": flat["QALYs"],
                         "delta_cost": delta["Total Cost"], "delta_qaly": delta["QALYs"]})


def expected_outputs(arm):
    years = 3 / 52
    boundaries = np.arange(261)
    months = boundaries * years * 12
    prefix = arm.lower() + "_os_gg_"
    survival = gammaincc(SURVIVAL[prefix + "shape"],
                         SURVIVAL[prefix + "lambda"] * months ** SURVIVAL[prefix + "delta"])
    weights = 1.03 ** (-years * boundaries[:-1])
    life_years = years * np.dot(weights, (survival[:-1] + survival[1:]) / 2)
    terminal = 27600.25 * np.dot(weights, survival[:-1] - survival[1:])
    key = arm.lower()
    mu = SURVIVAL[f"{key}_pfs_llogis_mu"]
    sigma = SURVIVAL[f"{key}_pfs_llogis_sigma"]
    pfs = np.minimum(survival, 1 / (1 + (months / np.exp(mu)) ** (1 / sigma)))
    pfs_cycles = np.sum((pfs[1:] + pfs[:-1]) / 2)
    pd = survival - pfs
    pd_cycles = np.sum((pd[1:] + pd[:-1]) / 2)
    raw_qaly = years * (pfs_cycles * UTILITIES[f"u_{key}_pfs"] + pd_cycles * UTILITIES[f"u_{key}_pd"])
    pfs_cost = COSTS[f"cost_{key}_pfs"] + COSTS["cost_monitoring"] + COSTS["cost_admin"]
    if key == "icc":
        pfs_cost += COSTS["cost_port"]
    records, _ = parameters()
    ae_cost = sum(records[f"ae_{key}_{ae}"]["base"] * records[f"ae_cost_{ae}"]["base"] for ae in AE)
    raw_cost = (pfs_cycles * pfs_cost + pd_cycles * COSTS[f"cost_{key}_pd"]
                + ae_cost + COSTS["cost_terminal"] * (1 - survival[-1]))
    return {"qaly": life_years, "terminal": terminal, "no_dr_cost": raw_cost,
            "no_dr_qaly": raw_qaly, "zero": 0, "years": 15, "delta_cost": 0, "delta_qaly": 0}


def main():
    outputs = {"Python": python_outputs()}
    with tempfile.TemporaryDirectory() as tmp:
        r_csv = Path(tmp) / "r.csv"
        subprocess.run(["Rscript", HERE / "check_r.R", ROOT, r_csv], cwd=ROOT, check=True)
        outputs["R"] = pd.read_csv(r_csv).set_index("arm")
        copy = Path(tmp) / ("verification_" + Path(tmp).name + ".xlsm")
        shutil.copyfile(ROOT / "workbooks/model/Dato_vs_ICC_CEA_US.xlsm", copy)
        excel = subprocess.check_output(["osascript", HERE / "check_excel.applescript", copy], text=True)
        outputs["Excel"] = pd.read_csv(StringIO(excel)).set_index("arm")
    rows = []
    for metric, label in [("qaly", "Unit utilities: QALYs"),
                          ("no_dr_cost", "Zero discount rates: total cost (US$)"),
                          ("no_dr_qaly", "Zero discount rates: QALYs"),
                          ("delta_cost", "Identical inputs: incremental cost (US$)"),
                          ("delta_qaly", "Identical inputs: incremental QALYs"),
                          ("zero", "All costs zero: total cost (US$)"),
                          ("years", "Survival fixed at one: undiscounted life-years"),
                          ("terminal", "Terminal care removed: reduction in total cost (US$)")]:
        incremental = metric.startswith("delta_")
        for arm in (("Dato",) if incremental else ("ICC", "Dato")):
            expected = expected_outputs(arm)
            arm_label = "Dato-DXd minus ICC" if incremental else {"Dato": "Dato-DXd", "ICC": "ICC"}[arm]
            row = {"Test": label, "Arm": arm_label,
                   "Expected": expected[metric]}
            for platform in ("Excel", "R", "Python"):
                value = outputs[platform].loc[arm, metric]
                np.testing.assert_allclose(value, expected[metric], atol=1e-8, rtol=1e-12,
                                           err_msg=f"{platform}, {arm}, {metric}")
                row[platform] = value
            rows.append(row)
    table = pd.DataFrame(rows)
    out = ROOT / "output" / "verification"
    out.mkdir(parents=True, exist_ok=True)
    table.to_csv(out / "verification_checks.csv", index=False)
    print(table.to_string(index=False))


if __name__ == "__main__":
    main()
