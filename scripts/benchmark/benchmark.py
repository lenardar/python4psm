import argparse
import csv
import hashlib
import json
import os
import platform
import subprocess
import sys
import tempfile
from importlib.metadata import version
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--repeats", type=int, default=50)
parser.add_argument("--psa", type=int, default=1000)
parser.add_argument("--engine", choices=["both", "pyheor", "heemod"], default="both")
parser.add_argument("--label", default="")
args = parser.parse_args()
if args.label and (args.label in {".", ".."} or Path(args.label).name != args.label):
    parser.error("--label must be a single directory name")
out = ROOT / "output" / "benchmark" / "runs" / (args.label or "baseline")
out.mkdir(parents=True, exist_ok=True)
prefix = "benchmark" + ("_" + args.label if args.label else "")
env = os.environ.copy()
for name in ["OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"]:
    env[name] = "1"
env["MPLCONFIGDIR"] = "/tmp/mbc_us_matplotlib"
commands = {
    "pyheor": [sys.executable, str(HERE / "benchmark_python.py")],
    "heemod": ["Rscript", str(HERE / "benchmark_r.R")],
}
files = [HERE / "benchmark_python.py", HERE / "benchmark_r.R"] + [p for folder in ["scripts/models/python", "scripts/models/r"]
         for p in (ROOT / folder).iterdir() if p.suffix in (".py", ".R")]
metadata = dict(
    started_utc=datetime.now(timezone.utc).isoformat(),
    platform=platform.platform(), architecture=platform.machine(),
    python=platform.python_version(), repeats=args.repeats, psa_draws=args.psa,
    package_versions={"pyheor": version("pyheor"), "heemod": "1.1.0"},
    engine_selection=args.engine,
    cycles=260, strategies=2, fresh_process_per_replicate=True,
    warmup="One untimed base case per process",
    thread_limits={k: env[k] for k in env if k.endswith("NUM_THREADS") or k == "VECLIB_MAXIMUM_THREADS"},
    timed="Elapsed time for native calculation calls, including model construction for the base case.",
    source_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
)
(out / f"{prefix}_environment.json").write_text(json.dumps(metadata, indent=2))
raw = out / f"{prefix}_times.csv"
columns = ["engine", "trial", "task", "seconds", "psa_draws", "owsa_parameters", "seed"]
with raw.open("w", newline="") as f:
    csv.writer(f).writerow(columns)
with tempfile.TemporaryDirectory(prefix="us_cea_benchmark_") as tmp, (out / f"{prefix}.log").open("w") as log:
    for trial in range(1, args.repeats + 1):
        order = ["heemod", "pyheor"] if trial % 2 else ["pyheor", "heemod"]
        if args.engine != "both":
            order = [args.engine]
        for engine in order:
            target = Path(tmp) / "replicate.csv"
            worker_args = [str(target), str(trial), str(args.psa)]
            subprocess.run(commands[engine] + worker_args,
                           cwd=ROOT, env=env, stdout=log, stderr=log, check=True)
            rows = pd.read_csv(target)
            assert len(rows) == 3 and rows.seconds.gt(0).all()
            rows.to_csv(raw, mode="a", header=False, index=False)
            print(f"{trial}/{args.repeats} {engine}: " + ", ".join(
                f"{row.task} {row.seconds:.3f}s" for row in rows.itertuples()), flush=True)

data = pd.read_csv(raw)
summary = data.groupby(["task", "engine"]).seconds.agg(
    n="count", median="median", mean="mean", sd="std", minimum="min", maximum="max",
    q25=lambda x: x.quantile(.25), q75=lambda x: x.quantile(.75))
summary.to_csv(out / f"{prefix}_summary.csv")
print(summary.to_string(), flush=True)
if args.engine == "both":
    ratios = summary["median"].unstack("engine")
    ratios["heemod_over_pyheor"] = ratios.heemod / ratios.pyheor
    ratios.to_csv(out / f"{prefix}_ratios.csv")
    print(ratios.to_string(), flush=True)
