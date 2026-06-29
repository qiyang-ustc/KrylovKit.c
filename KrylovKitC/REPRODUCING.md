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
KRYLOVKITC_RUN_RELEASE_GATE=1 julia --project=KrylovKitC -e 'using Pkg; Pkg.test()'
julia --project=benchmarks/krylovkit -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmarks/krylovkit --startup-file=no benchmarks/krylovkit/run_cpu.jl
julia --project=benchmarks/krylovkit --startup-file=no benchmarks/krylovkit/run_gpu.jl
python3 benchmarks/plots/plot_speedup.py benchmarks/results/krylovkitc_cpu.csv KrylovKitC/docs/figures/krylovkitc_cpu_speedup.svg
```

Use the JobFiles in `benchmarks/jobfiles/` for audited CPU/H100 runs. Commit only
compact summaries and host metadata from jobctl artifacts.
