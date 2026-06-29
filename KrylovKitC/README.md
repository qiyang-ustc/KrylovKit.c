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

Current CPU artifact is a partial pre-public subset because the public-main
Oblix run was previously blocked by node availability. It is kept visible but
not used as a headline claim.

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual |
| ---: | ---: | ---: | ---: | ---: |
| 32 | 0.001561 | 0.001451 | 0.93x | 4.21e-13 |
| 64 | 0.009271 | 0.011164 | 1.20x | 6.35e-15 |
| 128 | 0.065306 | 0.082468 | 1.26x | 5.16e-14 |

![KrylovKit.c CPU speedup](docs/figures/krylovkitc_cpu_speedup.svg)

### H100

Public-main H100 run `run-af7601bb0e53`, Snellius `gpu_h100`, commit
`40926d4`, warmup 2, repeat 7, tolerance `1e-12`.

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |
| ---: | ---: | ---: | ---: | ---: | :--- |
| 64 | 0.022977 | 0.019388 | 0.84x | 2.91e-14 | performance gate failed |
| 128 | 0.023078 | 0.092304 | 4.00x | 5.75e-13 | passed |
| 256 | 0.036957 | 0.481650 | 13.03x | 6.00e-14 | passed |

The `chi=64` row passes the residual gate but fails the performance gate. It is
reported rather than hidden.

![KrylovKit.c H100 speedup](docs/figures/krylovkitc_h100_speedup.svg)

![KrylovKit.c H100 residuals](docs/figures/krylovkitc_h100_residuals.svg)

![KrylovKit.c H100 runtime](docs/figures/krylovkitc_h100_runtime.svg)

## Expanded Release Sweep

```sh
bash benchmarks/run_release_suite.sh
```

Planned matrix:

| Backend | chi values | warmup | repeats | tolerance |
| :--- | :--- | ---: | ---: | ---: |
| CPU Oblix | `16,24,32,48,64,96,128,192` | 2 | 9 | `1e-12` |
| H100 Snellius | `32,48,64,96,128,192,256,384` | 3 | 11 | `1e-12` |

No claim is made for missing, timed-out, or smoke-test rows.

## Limitations

- This is not full KrylovKit.jl feature coverage.
- Generic callbacks are correctness paths first; they are not a general speedup
  claim.
- Current CPU artifact is partial until the expanded Oblix run completes.
- Complex CUDA is not yet a headline performance claim.
