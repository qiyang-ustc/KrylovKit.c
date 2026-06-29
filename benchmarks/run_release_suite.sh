#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

jobctl run "$repo_root/benchmarks/jobfiles/oblix_krylovkitc_cpu.jobfile.yaml" \
  --title "KrylovKit.c expanded CPU sweep" \
  --tag krylovkitc --tag release --tag cpu

jobctl run "$repo_root/benchmarks/jobfiles/snellius_krylovkitc_h100.jobfile.yaml" \
  --title "KrylovKit.c expanded H100 sweep" \
  --tag krylovkitc --tag release --tag h100
