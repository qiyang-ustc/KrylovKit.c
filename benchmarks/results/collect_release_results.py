#!/usr/bin/env python3
"""Collect compact KrylovKit.c release benchmark artifacts.

This script copies jobctl result summaries into the small files committed to the
repository. It intentionally does not copy full logs or run directories.
"""

from __future__ import annotations

import argparse
import shutil
from datetime import datetime, timezone
from pathlib import Path


def copy_required(src: Path, dst: Path) -> None:
    if not src.is_file():
        raise SystemExit(f"missing input: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cpu-run-id")
    parser.add_argument("--cpu-csv", type=Path)
    parser.add_argument("--cpu-host-env", type=Path)
    parser.add_argument("--cpu-source-kind", default="public_main")
    parser.add_argument("--cpu-note", default="")
    parser.add_argument("--h100-run-id")
    parser.add_argument("--h100-csv", type=Path)
    parser.add_argument("--h100-host-env", type=Path)
    parser.add_argument("--h100-source-kind", default="public_main")
    parser.add_argument("--h100-status", default="")
    parser.add_argument("--source-kind", default="public_main")
    parser.add_argument("--outdir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()

    has_cpu = args.cpu_run_id or args.cpu_csv or args.cpu_host_env
    has_h100 = args.h100_run_id or args.h100_csv or args.h100_host_env
    if not has_cpu and not has_h100:
        raise SystemExit("provide at least one CPU or H100 artifact")
    if has_cpu and not (args.cpu_run_id and args.cpu_csv and args.cpu_host_env):
        raise SystemExit("CPU artifact requires --cpu-run-id, --cpu-csv, and --cpu-host-env")
    if has_h100 and not (args.h100_run_id and args.h100_csv and args.h100_host_env):
        raise SystemExit("H100 artifact requires --h100-run-id, --h100-csv, and --h100-host-env")

    if has_cpu:
        copy_required(args.cpu_csv, args.outdir / "krylovkitc_cpu.csv")
        copy_required(args.cpu_host_env, args.outdir / "krylovkitc_cpu_host_env.txt")
    if has_h100:
        copy_required(args.h100_csv, args.outdir / "krylovkitc_h100.csv")
        copy_required(args.h100_host_env, args.outdir / "krylovkitc_h100_host_env.txt")

    lines = [
        f"generated_at_utc = {quote(datetime.now(timezone.utc).isoformat())}",
        f"source_kind = {quote(args.source_kind)}",
        "",
    ]
    if has_cpu:
        lines.extend(
            [
                "[krylovkitc_cpu]",
                f"run_id = {quote(args.cpu_run_id)}",
                f"source_kind = {quote(args.cpu_source_kind)}",
                'summary = "benchmarks/results/krylovkitc_cpu.csv"',
                'host_env = "benchmarks/results/krylovkitc_cpu_host_env.txt"',
            ]
        )
        if args.cpu_note:
            lines.append(f"note = {quote(args.cpu_note)}")
        lines.append("")
    if has_h100:
        lines.extend(
            [
                "[krylovkitc_h100]",
                f"run_id = {quote(args.h100_run_id)}",
                f"source_kind = {quote(args.h100_source_kind)}",
                'summary = "benchmarks/results/krylovkitc_h100.csv"',
                'host_env = "benchmarks/results/krylovkitc_h100_host_env.txt"',
            ]
        )
        if args.h100_status:
            lines.append(f"status = {quote(args.h100_status)}")
        lines.append("")

    metadata = args.outdir / "metadata.toml"
    metadata.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
