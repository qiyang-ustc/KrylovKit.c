# KrylovKitC

`KrylovKitC` exposes the native real-valued Krylov kernels used by the release
benchmark.

Release benchmark contract:

- native CPU versus KrylovKit.jl CPU on Oblix with `--cpus 4 --mem 4G`;
- native CUDA versus KrylovKit.jl CUDA/CuArray on Snellius H100 with one H100
  and `--mem 180G`;
- real `Float64` inputs on both backends;
- `chi = 32,64,96,128,160,192,224,256`;
- warmup 3, repeats 11;
- residuals and convergence metadata are reported.

If the KrylovKit.jl CUDA baseline cannot run on CuArray, the GPU benchmark must
fail instead of changing backend.

## Acknowledgements and Citation

`KrylovKitC` is downstream engineering work built around KrylovKit.jl as the
oracle and reference implementation. We deeply thank Jutho for KrylovKit.jl:
the Julia implementation defines the numerical behavior, convergence metadata,
and correctness target that the native C++/CUDA kernels preserve.

If you use this code, please also cite KrylovKit.jl and Jutho's work. The
optimized kernels here are validated against KrylovKit.jl; they do not replace
the scientific and software credit of the upstream project.

## Release Benchmark Results

These are warmed single-kernel timings. They are not full-solve timings.
`native/KrylovKit` is the ratio of median warmed kernel runtimes.

CPU results were run on Oblix `lerner` with `4` CPU cores and `4G` memory.

| chi | native (s) | KrylovKit.jl (s) | native/KrylovKit | native relres | Krylov relres | Krylov iter/ops | status |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 32 | 0.002793 | 0.002895 | 0.965 | 4.21e-13 | 4.21e-13 | 3/54 | pass |
| 64 | 0.016546 | 0.020674 | 0.800 | 7.35e-15 | 7.70e-15 | 7/102 | pass |
| 96 | 0.041220 | 0.054037 | 0.763 | 8.43e-14 | 8.41e-14 | 8/114 | pass |
| 128 | 0.107942 | 0.157869 | 0.684 | 1.90e-13 | 1.90e-13 | 11/150 | pass |
| 160 | 0.139071 | 0.195852 | 0.710 | 1.20e-13 | 1.20e-13 | 8/114 | pass |
| 192 | 0.270277 | 0.375508 | 0.720 | 1.90e-13 | 1.90e-13 | 10/138 | pass |
| 224 | 0.384228 | 0.527623 | 0.728 | 8.66e-13 | 8.67e-13 | 9/126 | pass |
| 256 | 0.519593 | 0.700108 | 0.742 | 1.33e-13 | 1.33e-13 | 8/114 | pass |

GPU results were run on Snellius H100 with one H100, `16` CPU cores, and
`180G` host memory.

| chi | native CUDA (s) | KrylovKit.jl CUDA (s) | native/KrylovKit | native relres | Krylov relres | Krylov iter/ops | status |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 32 | 0.010915 | 0.102201 | 0.107 | 4.21e-13 | 4.21e-13 | 3/54 | pass |
| 64 | 0.022938 | 0.223261 | 0.103 | 7.39e-15 | 8.01e-15 | 7/102 | pass |
| 96 | 0.026469 | 0.254427 | 0.104 | 8.34e-14 | 8.35e-14 | 8/114 | pass |
| 128 | 0.034568 | 0.345495 | 0.100 | 1.90e-13 | 1.91e-13 | 11/150 | pass |
| 160 | 0.026530 | 0.257488 | 0.103 | 1.19e-13 | 1.20e-13 | 8/114 | pass |
| 192 | 0.032699 | 0.318887 | 0.103 | 1.91e-13 | 1.90e-13 | 10/138 | pass |
| 224 | 0.032093 | 0.289089 | 0.111 | 8.67e-13 | 8.67e-13 | 9/126 | pass |
| 256 | 0.027755 | 0.257879 | 0.108 | 1.33e-13 | 1.33e-13 | 8/114 | pass |
