#!/usr/bin/env python3
import csv
import sys
from pathlib import Path

import matplotlib.pyplot as plt


plt.rcParams.update(
    {
        "font.size": 10,
        "axes.titlesize": 13,
        "axes.labelsize": 11,
        "legend.fontsize": 9,
        "svg.fonttype": "none",
    }
)


def load_rows(path):
    with open(path, newline="") as handle:
        dialect = csv.Sniffer().sniff(handle.read(4096), delimiters=",\t")
        handle.seek(0)
        return list(csv.DictReader(handle, dialect=dialect))


def speedup(row):
    if "native_over_krylov" in row and row["native_over_krylov"]:
        return 1.0 / float(row["native_over_krylov"])
    if "ratio_tenetc_over_master" in row and row["ratio_tenetc_over_master"]:
        return 1.0 / float(row["ratio_tenetc_over_master"])
    if "ratio_fasttenet_over_master" in row and row["ratio_fasttenet_over_master"]:
        return 1.0 / float(row["ratio_fasttenet_over_master"])
    raise KeyError("no speedup ratio column found")


if len(sys.argv) != 3:
    raise SystemExit("usage: plot_speedup.py input.csv-or-tsv output.svg")

input_path = Path(sys.argv[1])
rows = load_rows(input_path)
chis = [int(r["chi"]) for r in rows]
ys = [speedup(r) for r in rows]
xpos = list(range(len(rows)))
backend = rows[0].get("backend", "")
is_cpu = "cpu" in input_path.name or backend == "cpu"
title = (
    "KrylovKit.c CPU speedup (preliminary subset)"
    if is_cpu
    else "KrylovKit.c H100 speedup"
)

fig, ax = plt.subplots(figsize=(7.0, 4.2), constrained_layout=True)
colors = ["#b45f4d" if y < 1.0 else "#3568a7" for y in ys]
bars = ax.bar(xpos, ys, width=0.62, color=colors, edgecolor="#263238", linewidth=0.7)
ax.axhline(1.0, color="#4f4f4f", linestyle="--", linewidth=1.0)

for bar, y, row in zip(bars, ys, rows):
    label = f"{y:.2f}x"
    ax.text(
        bar.get_x() + bar.get_width() / 2,
        y + max(ys) * 0.035,
        label,
        ha="center",
        va="bottom",
        fontsize=9,
        color="#1f1f1f",
    )
    if row.get("status") == "fail":
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            max(0.04, y * 0.58),
            "gate fail",
            ha="center",
            va="center",
            fontsize=8,
            color="white",
            fontweight="bold",
        )

ax.set_xticks(xpos)
ax.set_xticklabels([str(c) for c in chis])
ax.set_xlabel("bond dimension chi")
ax.set_ylabel("speedup (KrylovKit.jl / KrylovKit.c)")
ax.set_title(title)
ax.set_ylim(0, max(max(ys) * 1.18, 1.25))
ax.grid(axis="y", alpha=0.28)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.text(
    0.01,
    0.98,
    "median wall time; values above parity favor KrylovKit.c",
    transform=ax.transAxes,
    ha="left",
    va="top",
    fontsize=8.5,
    color="#555555",
)
ax.text(
    len(rows) - 0.5,
    1.0 + max(max(ys), 1.0) * 0.025,
    "parity",
    ha="right",
    va="bottom",
    fontsize=8.5,
    color="#555555",
)
fig.savefig(sys.argv[2])
