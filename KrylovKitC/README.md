# KrylovKit.c

`KrylovKitC` exposes a native CPU/CUDA backend for KrylovKit-style solvers. It
is a benchmark-first engineering backend, not a complete standard linear
algebra library and not a replacement for KrylovKit.jl.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/qiyang-ustc/KrylovKit.c", subdir="KrylovKitC")
```

## Acknowledgement And Citation

KrylovKit.jl is the reference implementation and semantic baseline. We are
grateful to Jutho Haegeman and the KrylovKit.jl contributors for the API,
documentation, and algorithmic design. Please cite and acknowledge KrylovKit.jl
by Jutho Haegeman and contributors when this backend is useful in scientific
work. Please do not cite KrylovKit.c as the scientific source.

If this package is used through TeneT.c, please also cite and acknowledge
TeneT.jl by Xingyu Zhang and contributors.

## API Surface

```julia
using KrylovKitC

A = randn(128, 128)
x0 = randn(128)
vals, vecs, info = native_eigsolve(A, x0, 1, :LM; krylovdim=30, tol=1e-12)
```

The release wrapper forwards to the native core in `TenetNative` while keeping a
separate package boundary for downstream users.

## What Is Measured

| Area | Coverage |
| :--- | :--- |
| Eigensolver | `native_eigsolve`, Arnoldi/Krylov-Schur style API |
| Linsolver | `native_linsolve`, GMRES/CG/BiCGStab |
| Scalars | CPU `Float64`, CPU `ComplexF64`, CUDA `Float64` fast path |
| Operators | Dense matrix, CPU callback, MPS-like native fast path |
| Baseline | KrylovKit.jl on the same generated problems |

The current performance headline is restricted to the MPS-like fast path.
Generic callbacks are correctness-tested but not advertised as generally faster
than KrylovKit.jl.

## Correctness Gate

Run the release gate with:

```sh
KRYLOVKITC_RUN_RELEASE_GATE=1 julia --project=KrylovKitC -e 'using Pkg; Pkg.test()'
```

The gate includes:

| Category | Cases |
| :--- | :--- |
| Dense oracle | real/complex normal, Hermitian, non-normal |
| Spectral edge cases | clustered, repeated, conjugate pairs, defective/Jordan-like |
| Arnoldi behavior | exact breakdown, nonconvergence, `howmany > 1` |
| Selectors | `:LM/:SM/:LR/:SR/:LI/:SI` |
| Complex semantics | conjugate inner product and adjoint behavior |
| Linsolve | zero RHS, shifted `a0+a1A`, GMRES, CG, BiCGStab, ill-conditioned case |
| Backend parity | dense matrix, CPU callback, MPS fast path, CUDA fast path when available |

Acceptance thresholds:

| Backend | Residual gate |
| :--- | ---: |
| CPU `Float64/ComplexF64` | `<= 1e-12` |
| H100 CUDA fast path | `<= 1e-10` |

## Performance Evidence

Figures and tables are generated from committed CSV artifacts in
`benchmarks/results/`.

```sh
python3 benchmarks/plots/plot_release_figures.py
```

### CPU

Public-main CPU-backend run `run-f694c0e7c4c6`, Snellius `gpu_h100` allocation,
commit `0528720`, warmup 2, repeat 9, tolerance `1e-12`. This run uses the CPU
backend only; the H100 allocation was used because the intended CPU queues were
unavailable.

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |
| ---: | ---: | ---: | ---: | ---: | :--- |
| 16 | 0.001050 | 0.001130 | 1.08x | 1.97e-15 | pass |
| 24 | 0.001927 | 0.002018 | 1.05x | 2.38e-15 | pass |
| 32 | 0.003094 | 0.003195 | 1.03x | 4.14e-13 | pass |
| 48 | 0.006475 | 0.007992 | 1.23x | 3.55e-13 | pass |
| 64 | 0.011071 | 0.014583 | 1.32x | 4.22e-13 | pass |
| 96 | 0.031303 | 0.040733 | 1.30x | 2.20e-14 | pass |
| 128 | 0.086324 | 0.110771 | 1.28x | 2.48e-13 | pass |
| 192 | 0.217434 | 0.268270 | 1.23x | 6.52e-13 | pass |

![KrylovKit.c CPU speedup](docs/figures/krylovkitc_cpu_speedup.svg)

### H100

Public-main H100 run `run-f72efffee4ec`, Snellius `gpu_h100`, commit
`0528720`, warmup 3, repeat 11, tolerance `1e-12`. This section compares the
KrylovKit.c CUDA native fast path with KrylovKit.jl running the CPU operator
baseline on the same generated MPS-like problem. It is not a GPU-vs-GPU
KrylovKit comparison.

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |
| ---: | ---: | ---: | ---: | ---: | :--- |
| 32 | 0.011202 | 0.002558 | 0.23x | 4.21e-13 | fail |
| 48 | 0.016955 | 0.007982 | 0.47x | 6.87e-14 | fail |
| 64 | 0.017269 | 0.014545 | 0.84x | 1.69e-13 | fail |
| 96 | 0.020586 | 0.048505 | 2.36x | 3.92e-14 | pass |
| 128 | 0.017296 | 0.063785 | 3.69x | 1.25e-13 | pass |
| 192 | 0.032724 | 0.215429 | 6.58x | 1.91e-13 | pass |
| 256 | 0.037303 | 0.470568 | 12.61x | 1.85e-13 | pass |
| 384 | 0.039811 | 1.082068 | 27.18x | 6.81e-14 | pass |

The `chi=32,48,64` rows pass the residual gate but fail the H100 performance
gate. They are reported rather than hidden.

![KrylovKit.c H100 speedup](docs/figures/krylovkitc_h100_speedup.svg)

![KrylovKit.c H100 residuals](docs/figures/krylovkitc_h100_residuals.svg)

![KrylovKit.c H100 runtime](docs/figures/krylovkitc_h100_runtime.svg)

## Expanded Release Sweep

```sh
bash benchmarks/run_release_suite.sh
```

Measured matrix:

| Backend | chi values | warmup | repeats | tolerance |
| :--- | :--- | ---: | ---: | ---: |
| CPU backend on Snellius H100 node | `16,24,32,48,64,96,128,192` | 2 | 9 | `1e-12` |
| H100 Snellius CUDA fast path vs KrylovKit.jl CPU baseline | `32,48,64,96,128,192,256,384` | 3 | 11 | `1e-12` |

No claim is made for missing, timed-out, or smoke-test rows.

## Limitations

- This is not full KrylovKit.jl feature coverage.
- Generic callbacks are correctness paths first; they are not a general speedup
  claim.
- CPU-backend timing is from a Snellius H100-node allocation, not an Oblix CPU
  node. Regular CPU queues were unavailable for this measurement.
- H100 speedups are CUDA native fast path versus KrylovKit.jl CPU baseline, not
  a comparison against a KrylovKit.jl GPU backend.
- Complex CUDA is not yet a headline performance claim.
