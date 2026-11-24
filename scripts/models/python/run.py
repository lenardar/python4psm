import argparse
import os
os.environ.setdefault("MPLCONFIGDIR", "/tmp/mbc_us_matplotlib")
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import pyheor as ph
from model import build_model
from parameters import ROOT, REFERENCE_RESULTS


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-only", action="store_true")
    parser.add_argument("--psa", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20261031)
    args = parser.parse_args()
    out = ROOT / "output" / "pyheor"
    out.mkdir(parents=True, exist_ok=True)
    model, records, config = build_model()
    base = model.run_base_case()
    summary = base.summary()
    summary.to_csv(out / "base_case.csv", index=False)
    base.icer().to_csv(out / "icer.csv", index=False)
    comparison = []
    for arm, label in model.strategy_labels.items():
        result = summary.loc[summary.Strategy == label].iloc[0]
        expected = REFERENCE_RESULTS[arm]
        comparison.append(dict(strategy=arm, excel_cost=expected["cost"],
            pyheor_cost=result["Total Cost"], cost_difference=result["Total Cost"]-expected["cost"],
            excel_qaly=expected["qaly"], pyheor_qaly=result["QALYs"],
            qaly_difference=result["QALYs"]-expected["qaly"]))
    comparison = pd.DataFrame(comparison)
    comparison.to_csv(out / "excel_comparison.csv", index=False)
    print(comparison.to_string(index=False), flush=True)

    export_model, _, _ = build_model(use_terminal_state=True)
    export_base = export_model.run_base_case()
    ph.export_excel_model(export_base, out / "model.xlsx")

    base_cost = summary.set_index("Strategy")["Total Cost"]
    export_cost = export_base.summary().set_index("Strategy")["Total Cost"]
    reduction = base_cost - export_cost
    for strategy in base_cost.index:
        print(f"{strategy}: total cost reduction from the base case "
              f"US${reduction[strategy]:,.2f} ({reduction[strategy] / base_cost[strategy]:.2%})")

    def save(fig, filename):
        fig.savefig(out / filename, dpi=180, bbox_inches="tight")
        plt.close(fig)

    save(base.plot_trace(), "state_trace.png")
    if args.base_only:
        return
    names = [name for name, x in records.items() if x["low"] != x["high"]]
    owsa = model.run_owsa(params=names, wtp=config["wtp"])
    owsa.summary().to_csv(out / "owsa.csv", index=False)
    save(owsa.plot_tornado(), "tornado.png")
    psa = model.run_psa(n_sim=args.psa, seed=args.seed)
    psa.summary().to_csv(out / "psa_summary.csv", index=False)
    psa.ce_table.to_csv(out / "psa_samples.csv", index=False)
    save(psa.plot_scatter(wtp=config["wtp"]), "psa_scatter.png")
    save(psa.plot_ceac(wtp_range=(0, config["ceac_max"]),
         n_wtp=int(config["ceac_max"] / config["ceac_step"]) + 1, smooth=False), "ceac.png")


if __name__ == "__main__":
    main()
