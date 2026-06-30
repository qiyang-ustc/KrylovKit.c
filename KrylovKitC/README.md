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
