#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

jobctl run "$repo_root/benchmarks/jobfiles/oblix_krylovkitc_cpu.jobfile.yaml" \
  --title "KrylovKit.c expanded CPU sweep" \
  --tag krylovkitc --tag release --tag cpu \
  --cpus 4 --mem 16G --time 04:00:00

jobctl run "$repo_root/benchmarks/jobfiles/snellius_krylovkitc_h100.jobfile.yaml" \
  --title "KrylovKit.c expanded H100 sweep" \
  --tag krylovkitc --tag release --tag h100 \
  --partition gpu_h100 --gres gpu:1 --mem 16G --time 01:30:00
