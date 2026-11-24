# Computational performance

English | [简体中文](README.zh-CN.md)

Each platform completed 50 repetitions of probabilistic sensitivity analysis (PSA) with 1,000 draws per repetition. Runtime is reported as the median and quartiles.

[Timing summary](../../output/benchmark/psa_runtime.csv) · [Runtime comparison](../../output/benchmark/psa_runtime.png)

Excel reused the same workbook and included worksheet output in elapsed time. Each R and Python repetition used a fresh process with an untimed base-case warm-up.

Run the following command from the repository root to generate the summary and figure from the timing records.

```sh
.venv/bin/python scripts/benchmark/plot_benchmark.py
```

[Measurement protocol](benchmark_notes.txt) · [Excel benchmark workbook](../../workbooks/benchmark/US_benchmark.xlsm)
