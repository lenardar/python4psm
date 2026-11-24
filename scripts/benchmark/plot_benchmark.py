import os
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/mbc_us_matplotlib")
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

out = Path(__file__).resolve().parents[2] / "output" / "benchmark"
sources = [
    ("Excel", "Excel", "excel/excel_psa_times.csv"),
    ("R", "heemod", "baseline/benchmark_times.csv"),
    ("Python", "pyheor", "pyheor_0_6_0_default/benchmark_pyheor_0_6_0_default_times.csv"),
]
rows = []
for platform, engine, filename in sources:
    records = pd.read_csv(out / "runs" / filename)
    psa = records.loc[(records.engine == engine) & (records.task.str.lower() == "psa")]
    assert sorted(psa.trial) == list(range(1, 51))
    assert psa.psa_draws.eq(1000).all() and psa.seconds.gt(0).all()
    rows.append(dict(platform=platform, repetitions=len(psa), draws=1000,
                     median_seconds=psa.seconds.median(), q25_seconds=psa.seconds.quantile(.25),
                     q75_seconds=psa.seconds.quantile(.75)))

summary = pd.DataFrame(rows)
summary.to_csv(out / "psa_runtime.csv", index=False)
fig, ax = plt.subplots(figsize=(6, 4), layout="constrained")
median = summary.median_seconds
ax.errorbar(summary.platform, median, yerr=[median - summary.q25_seconds, summary.q75_seconds - median],
            fmt="D", color="#355C7D", capsize=5)
for platform, value, upper in zip(summary.platform, median, summary.q75_seconds):
    ax.annotate(f"{value:.1f} s", (platform, upper), xytext=(0, 8),
                textcoords="offset points", ha="center")
ax.set_ylabel("PSA runtime (seconds), median and IQR")
ax.set_ylim(0, summary.q75_seconds.max() * 1.18)
ax.margins(x=.2)
fig.savefig(out / "psa_runtime.png", dpi=200)
plt.close(fig)
