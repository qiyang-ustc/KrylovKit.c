# KrylovKit.c Benchmarks

These scripts compare KrylovKit.jl against `KrylovKitC`, using the native core
currently implemented in `TenetNative`.

Run from the repository root:

```sh
julia --project=benchmarks/krylovkit -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmarks/krylovkit --startup-file=no benchmarks/krylovkit/run_cpu.jl
julia --project=benchmarks/krylovkit --startup-file=no benchmarks/krylovkit/run_gpu.jl
```

Default release sizes:

- CPU: `KRYLOVKITC_CHIS=32,64,128`
- H100: `KRYLOVKITC_CHIS=64,128,256`

Override `KRYLOVKITC_CHIS=8,16` only for smoke tests.
