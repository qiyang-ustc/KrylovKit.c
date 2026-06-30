# KrylovKit.c Benchmarks

The release benchmark suite measures warmed Krylov eigensolver kernel timing.
It is not a VUMPS benchmark.

Allowed comparisons:

- CPU on Oblix: native CPU versus KrylovKit.jl CPU, both `Float64`.
- GPU on Snellius H100: native CUDA versus KrylovKit.jl CUDA/CuArray, both
  real `Float64`.

Default sweep:

- `KRYLOVKITC_CHIS=32,64,96,128,160,192,224,256`
- `KRYLOVKITC_WARMUP=3`
- `KRYLOVKITC_REPEATS=11`
- `KRYLOVKITC_TOL=1e-12`
- `KRYLOVKITC_KRYLOVDIM=30`
- `KRYLOVKITC_MAXITER=100`
- `KRYLOVKITC_PHYS=2`
- `KRYLOVKITC_HOWMANY=1`
- `KRYLOVKITC_ALLOW_FAILURES=false`

Run all official jobs through jobctl:

```bash
bash benchmarks/run_release_suite.sh
```
