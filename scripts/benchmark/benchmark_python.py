import csv
import gc
import os
import sys
from time import perf_counter
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/mbc_us_matplotlib")
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/models/python"))
from model import build_model


def main():
    target, trial, n_psa = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    seed = 20261031 + trial
    warm, _, _ = build_model()
    warm.run_base_case()
    del warm
    gc.collect()
    start = perf_counter()
    model, records, config = build_model()
    base = model.run_base_case()
    base_seconds = perf_counter() - start
    names = [n for n, p in records.items() if p["low"] != p["high"]]
    gc.collect()
    start = perf_counter()
    owsa = model.run_owsa(params=names, wtp=config["wtp"])
    owsa_seconds = perf_counter() - start
    gc.collect()
    start = perf_counter()
    psa = model.run_psa(n_sim=n_psa, seed=seed, progress=False)
    psa_seconds = perf_counter() - start
    assert len(psa.ce_table) == 2 * n_psa
    assert len(owsa.summary()) == len(names)
    with open(target, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["engine", "trial", "task", "seconds", "psa_draws", "owsa_parameters", "seed"])
        for task, seconds in [("base", base_seconds), ("owsa", owsa_seconds), ("psa", psa_seconds)]:
            writer.writerow(["pyheor", trial, task, seconds, n_psa, len(names), seed])


if __name__ == "__main__":
    main()
