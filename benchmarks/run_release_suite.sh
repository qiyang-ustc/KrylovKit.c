#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

jobctl run "$repo_root/benchmarks/jobfiles/oblix_krylovkitc_cpu.jobfile.yaml" \
  --title "KrylovKit.c warmed kernel CPU sweep on Oblix" \
  --tag krylovkitc --tag release --tag cpu --tag oblix \
  --backend slurm --server oblix --partition lerner --cpus 4 --mem 4G --time 02:00:00

jobctl run "$repo_root/benchmarks/jobfiles/snellius_krylovkitc_h100.jobfile.yaml" \
  --title "KrylovKit.c warmed kernel GPU sweep on Snellius H100" \
  --tag krylovkitc --tag release --tag h100 --tag snellius \
  --backend slurm --server snellius \
  --partition gpu_h100 --gres gpu:h100:1 --cpus 16 --mem 180G --time 01:30:00
