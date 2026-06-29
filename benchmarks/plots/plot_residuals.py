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


if len(sys.argv) != 3:
    raise SystemExit("usage: plot_residuals.py input.csv-or-tsv output.svg")

input_path = Path(sys.argv[1])
rows = load_rows(input_path)
chis = [int(r["chi"]) for r in rows]
xpos = list(range(len(rows)))
backend = rows[0].get("backend", "")
is_cpu = "cpu" in input_path.name or backend == "cpu"
gate = 1e-12 if is_cpu else 1e-10
title = (
    "KrylovKit.c CPU residuals (preliminary subset)"
    if is_cpu
    else "KrylovKit.c H100 residuals"
)
series = []
labels = {
    "native_relres": "KrylovKit.c",
    "krylov_relres": "KrylovKit.jl",
    "master_err": "TeneT.jl master",
    "tenetc_err": "TeneT.c",
}
for name in ("native_relres", "krylov_relres", "master_err", "tenetc_err"):
    if name in rows[0]:
        values = [float(r[name]) for r in rows if r.get(name)]
        if len(values) == len(rows):
            series.append((labels.get(name, name), values))

fig, ax = plt.subplots(figsize=(7.0, 4.2), constrained_layout=True)
palette = ["#3568a7", "#c76f00", "#6b7280", "#007f5f"]
all_values = []
for color, (name, ys) in zip(palette, series):
    all_values.extend(ys)
    ax.plot(xpos, ys, marker="o", linewidth=2.0, markersize=5.5, label=name, color=color)
ax.axhline(gate, color="#b45f4d", linestyle="--", linewidth=1.1, label=f"gate {gate:.0e}")

ax.set_xticks(xpos)
ax.set_xticklabels([str(c) for c in chis])
ax.set_xlabel("bond dimension chi")
ax.set_ylabel("relative residual")
ax.set_yscale("log")
ax.set_title(title)
if all_values:
    ax.set_ylim(min(all_values) * 0.65, max(gate * 3.0, max(all_values) * 1.8))
ax.grid(axis="y", which="both", alpha=0.28)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(loc="center right", frameon=False)
fig.savefig(sys.argv[2])
