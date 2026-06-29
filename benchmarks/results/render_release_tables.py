#!/usr/bin/env python3
"""Render Markdown tables from committed KrylovKit.c benchmark CSVs."""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "benchmarks" / "results"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def speedup(row: dict[str, str]) -> float:
    return 1.0 / float(row["native_over_krylov"])


def render(rows: list[dict[str, str]], title: str) -> list[str]:
    lines = [
        f"## {title}",
        "",
        "| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |",
        "| ---: | ---: | ---: | ---: | ---: | :--- |",
    ]
    for row in rows:
        lines.append(
            "| {chi} | {native:.6f} | {krylov:.6f} | {speedup:.2f}x | {resid:.2e} | {status} |".format(
                chi=row["chi"],
                native=float(row["native_seconds_median"]),
                krylov=float(row["krylov_seconds_median"]),
                speedup=speedup(row),
                resid=float(row["native_relres"]),
                status=row.get("status", ""),
            )
        )
    lines.append("")
    return lines


def main() -> None:
    lines = ["# Generated Benchmark Tables", ""]
    lines += render(read_csv(RESULTS / "krylovkitc_cpu.csv"), "CPU")
    lines += render(read_csv(RESULTS / "krylovkitc_h100.csv"), "H100")
    (RESULTS / "summary.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
