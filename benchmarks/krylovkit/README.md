# Krylov Kernel Runners

`run_cpu.jl` emits CPU rows for native KrylovKit.c and KrylovKit.jl CPU.
`run_gpu.jl` emits GPU rows for native CUDA and KrylovKit.jl CUDA/CuArray.

Both runners call `harness/scripts/tenetnative_krylov_benchmark.jl`, which
records warmed timings, residuals, iteration counts, operation counts,
correctness status, and performance status.

The GPU runner must use CuArray for both implementations. It must fail rather
than changing backend.
