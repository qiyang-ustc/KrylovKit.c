# Reproducing KrylovKit.c Results

All release results must be generated from scripts under `benchmarks/krylovkit`
or the equivalent jobfiles that call those scripts.

Required metadata:

- KrylovKit.c commit and dirty status.
- KrylovKit.jl version.
- Julia version.
- CPU/GPU model.
- BLAS/CUDA/cuBLAS/cuTENSOR versions.
- Threads and environment variables.
- Problem size, tolerance, `krylovdim`, `maxiter`, and seed.

Recommended commands from the repository root:

```sh
julia --project=KrylovKitC -e 'using Pkg; Pkg.instantiate()'
julia --project=TenetNative --startup-file=no benchmarks/krylovkit/run_cpu.jl
julia --project=FastTeneT --startup-file=no benchmarks/krylovkit/run_gpu.jl
python3 benchmarks/plots/plot_speedup.py results/krylovkit_cpu.csv results/figures/krylovkit_cpu_speedup.png
```

This branch contains local unregistered workspace dependency wiring for the
benchmark environment.
