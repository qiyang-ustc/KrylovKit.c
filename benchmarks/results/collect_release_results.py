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
    parser.add_argument("--cpu-run-id", required=True)
    parser.add_argument("--cpu-csv", type=Path, required=True)
    parser.add_argument("--cpu-host-env", type=Path, required=True)
    parser.add_argument("--h100-run-id", required=True)
    parser.add_argument("--h100-csv", type=Path, required=True)
    parser.add_argument("--h100-host-env", type=Path, required=True)
    parser.add_argument("--source-kind", default="public_main")
    parser.add_argument("--outdir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()

    copy_required(args.cpu_csv, args.outdir / "krylovkitc_cpu.csv")
    copy_required(args.cpu_host_env, args.outdir / "krylovkitc_cpu_host_env.txt")
    copy_required(args.h100_csv, args.outdir / "krylovkitc_h100.csv")
    copy_required(args.h100_host_env, args.outdir / "krylovkitc_h100_host_env.txt")

    metadata = args.outdir / "metadata.toml"
    metadata.write_text(
        "\n".join(
            [
                f"generated_at_utc = {quote(datetime.now(timezone.utc).isoformat())}",
                f"source_kind = {quote(args.source_kind)}",
                "",
                "[krylovkitc_cpu]",
                f"run_id = {quote(args.cpu_run_id)}",
                'summary = "benchmarks/results/krylovkitc_cpu.csv"',
                'host_env = "benchmarks/results/krylovkitc_cpu_host_env.txt"',
                "",
                "[krylovkitc_h100]",
                f"run_id = {quote(args.h100_run_id)}",
                'summary = "benchmarks/results/krylovkitc_h100.csv"',
                'host_env = "benchmarks/results/krylovkitc_h100_host_env.txt"',
                "",
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
