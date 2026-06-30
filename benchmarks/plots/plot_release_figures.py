#!/usr/bin/env python3
"""Generate release README figures from committed KrylovKit.c artifacts."""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "benchmarks" / "results"
FIGURES = ROOT / "KrylovKitC" / "docs" / "figures"

BLUE = "#2f67a8"
ORANGE = "#c56a00"
RED = "#b45f4d"
GRAY = "#52575c"
LIGHT_GRID = "#b9c0c9"

plt.rcParams.update(
    {
        "font.size": 10,
        "axes.titlesize": 13,
        "axes.labelsize": 10.5,
        "legend.fontsize": 9,
        "svg.fonttype": "none",
    }
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def speedup(row: dict[str, str]) -> float:
    return 1.0 / float(row["native_over_krylov"])


def measured_note(rows: list[dict[str, str]], target: int) -> str:
    if len(rows) >= target:
        return f"{len(rows)} measured chi values"
    return f"partial: {len(rows)}/{target} planned chi values measured"


def finish(fig, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path)
    plt.close(fig)


def plot_speedup(rows: list[dict[str, str]], path: Path, *, title: str, target: int) -> None:
    chis = [int(r["chi"]) for r in rows]
    values = [speedup(r) for r in rows]
    xpos = list(range(len(rows)))
    colors = [RED if y < 1.0 or r.get("status") == "fail" else BLUE for y, r in zip(values, rows)]

    fig, ax = plt.subplots(figsize=(7.2, 4.2), constrained_layout=True)
    bars = ax.bar(xpos, values, width=0.62, color=colors, edgecolor="#263238", linewidth=0.7)
    ax.axhline(1.0, color=GRAY, linestyle="--", linewidth=1.0)
    for bar, y, row in zip(bars, values, rows):
        ax.text(bar.get_x() + bar.get_width() / 2, y + max(values) * 0.035, f"{y:.2f}x",
                ha="center", va="bottom", fontsize=9)
        if row.get("status") == "fail":
            ax.text(bar.get_x() + bar.get_width() / 2, y + max(values) * 0.075, "gate fail",
                    ha="center", va="bottom", fontsize=8, color=RED, fontweight="bold")

    ax.text(0.01, 0.98, measured_note(rows, target), transform=ax.transAxes,
            ha="left", va="top", fontsize=8.5, color=GRAY)
    ax.text(len(rows) - 0.45, 1.0 + max(max(values), 1.0) * 0.025, "parity",
            ha="right", va="bottom", fontsize=8.5, color=GRAY)
    ax.set_xticks(xpos)
    ax.set_xticklabels([str(c) for c in chis])
    ax.set_xlabel("bond dimension chi")
    ax.set_ylabel("speedup (KrylovKit.jl / KrylovKit.c)")
    ax.set_title(title)
    ax.set_ylim(0, max(max(values) * 1.18, 1.25))
    ax.grid(axis="y", alpha=0.28, color=LIGHT_GRID)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    finish(fig, path)


def plot_residuals(rows: list[dict[str, str]], path: Path, *, title: str, gate: float) -> None:
    chis = [int(r["chi"]) for r in rows]
    xpos = list(range(len(rows)))
    native = [float(r["native_relres"]) for r in rows]
    krylov = [float(r["krylov_relres"]) for r in rows]
    all_values = native + krylov

    fig, ax = plt.subplots(figsize=(7.2, 4.2), constrained_layout=True)
    ax.plot(xpos, native, marker="o", linewidth=2.0, markersize=5.5, color=BLUE, label="KrylovKit.c")
    ax.plot(xpos, krylov, marker="o", linewidth=2.0, markersize=5.5, color=ORANGE, label="KrylovKit.jl")
    ax.axhline(gate, color=RED, linestyle="--", linewidth=1.1, label=f"gate {gate:.0e}")
    ax.set_xticks(xpos)
    ax.set_xticklabels([str(c) for c in chis])
    ax.set_xlabel("bond dimension chi")
    ax.set_ylabel("relative residual")
    ax.set_yscale("log")
    ax.set_ylim(min(all_values) * 0.65, max(gate * 3.0, max(all_values) * 1.8))
    ax.set_title(title)
    ax.grid(axis="y", which="both", alpha=0.28, color=LIGHT_GRID)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(loc="center right", frameon=False)
    finish(fig, path)


def plot_runtime(rows: list[dict[str, str]], path: Path, *, title: str, target: int) -> None:
    chis = [int(r["chi"]) for r in rows]
    xpos = list(range(len(rows)))
    native = [float(r["native_seconds_median"]) for r in rows]
    krylov = [float(r["krylov_seconds_median"]) for r in rows]
    width = 0.34

    fig, ax = plt.subplots(figsize=(7.2, 4.2), constrained_layout=True)
    ax.bar([x - width / 2 for x in xpos], native, width=width, color=BLUE,
           edgecolor="#263238", linewidth=0.6, label="KrylovKit.c")
    ax.bar([x + width / 2 for x in xpos], krylov, width=width, color=ORANGE,
           edgecolor="#263238", linewidth=0.6, label="KrylovKit.jl")
    ax.text(0.01, 0.98, measured_note(rows, target), transform=ax.transAxes,
            ha="left", va="top", fontsize=8.5, color=GRAY)
    ax.set_xticks(xpos)
    ax.set_xticklabels([str(c) for c in chis])
    ax.set_xlabel("bond dimension chi")
    ax.set_ylabel("median wall time (s)")
    ax.set_title(title)
    ax.grid(axis="y", alpha=0.28, color=LIGHT_GRID)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(loc="upper left", bbox_to_anchor=(0.01, 0.92), frameon=False)
    finish(fig, path)


def main() -> None:
    cpu = read_csv(RESULTS / "krylovkitc_cpu.csv")
    h100 = read_csv(RESULTS / "krylovkitc_h100.csv")
    plot_speedup(
        cpu,
        FIGURES / "krylovkitc_cpu_speedup.svg",
        title="CPU backend on Snellius H100 node, MPS-like eigsolve\nwarmup=2 repeat=9 tol=1e-12",
        target=8,
    )
    plot_speedup(
        h100,
        FIGURES / "krylovkitc_h100_speedup.svg",
        title="Snellius H100 CUDA fast path, MPS-like eigsolve\nwarmup=3 repeat=11 tol=1e-12",
        target=8,
    )
    plot_residuals(
        h100,
        FIGURES / "krylovkitc_h100_residuals.svg",
        title="Snellius H100 residuals, MPS-like eigsolve\nwarmup=3 repeat=11 tol=1e-12",
        gate=1e-10,
    )
    plot_runtime(
        h100,
        FIGURES / "krylovkitc_h100_runtime.svg",
        title="Snellius H100 absolute runtime, MPS-like eigsolve\nwarmup=3 repeat=11 tol=1e-12",
        target=8,
    )


if __name__ == "__main__":
    main()
