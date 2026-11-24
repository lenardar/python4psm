# 模型运行时间实验

[English](README.md) | 简体中文

三平台均进行 50 轮概率敏感性分析（PSA），每轮抽样 1,000 次。运行时间以中位数和四分位数报告。

[计时汇总](../../output/benchmark/psa_runtime.csv) · [三平台比较图](../../output/benchmark/psa_runtime.png)

Excel 在同一工作簿中重复运行，计时包括工作表写入。R 和 Python 每轮使用新进程，并在计时前运行一次基础分析。

在项目根目录执行以下命令，从原始记录生成汇总表和比较图。

```sh
.venv/bin/python scripts/benchmark/plot_benchmark.py
```

[实验步骤](benchmark_notes.txt) · [Excel 计时工作簿](../../workbooks/benchmark/US_benchmark.xlsm)
