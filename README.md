# KrylovKit.c

Preview / benchmark artifact for native CPU/CUDA Krylov-style eigensolver and
linear-solver experiments. This is not a complete standard linear algebra
library release. The Julia package lives in `KrylovKitC/`; install with:

```julia
using Pkg
Pkg.add(url="https://github.com/qiyang-ustc/KrylovKit.c", subdir="KrylovKitC")
```

## Acknowledgement

KrylovKit.jl is the reference implementation and semantic baseline for this
work. We are grateful to Jutho Haegeman and the KrylovKit.jl contributors for
the clear API, documentation, and algorithmic design. This repository is not a
replacement for KrylovKit.jl; it is a native backend for workloads where a
C/CUDA ABI, device-resident buffers, or specialized fast paths are useful.

If this code is useful in your work, please cite and acknowledge the original
KrylovKit.jl work by Jutho Haegeman and contributors. If you use it through the
TeneT.c tensor-network benchmarks, please also cite and acknowledge TeneT.jl by
Xingyu Zhang and contributors. Please do not cite this repository as the
scientific source; treat it as an engineering backend and benchmark artifact.

## Layout

- `KrylovKitC/`: release-facing Julia wrapper package.
- `TenetNative/`: native C++/CUDA implementation used by the wrapper.
- `benchmarks/`: CPU/H100 benchmark scripts, jobfiles, plotting scripts, and
  artifact conventions.
- `harness/scripts/tenetnative_krylov_benchmark.jl`: benchmark runner used by
  the checked-in jobfiles.

## Preliminary Performance Snapshot

The figures below are generated from compact summaries in `benchmarks/results/`.
`benchmarks/results/metadata.toml` records the source run for each artifact.
The H100 summary is a public-main measurement; the CPU summary is still a
pre-public subset because the public-main Oblix run was cancelled when the
requested node was unavailable/reserved. Small `chi=8` and `chi=16` runs are
smoke tests only.

![KrylovKit.c CPU speedup benchmark](KrylovKitC/docs/figures/krylovkitc_cpu_speedup.svg)

![KrylovKit.c CPU residual benchmark](KrylovKitC/docs/figures/krylovkitc_cpu_residuals.svg)

![KrylovKit.c H100 speedup benchmark](KrylovKitC/docs/figures/krylovkitc_h100_speedup.svg)

![KrylovKit.c H100 residual benchmark](KrylovKitC/docs/figures/krylovkitc_h100_residuals.svg)

See `KrylovKitC/README.md` for the full tables, run IDs, tolerances, and
reproduction commands.
