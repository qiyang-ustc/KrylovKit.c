# Release JobFiles

These JobFiles are thin release entrypoints. They call the benchmark scripts in
`benchmarks/` and leave raw logs/results under the job run directory.

Use small `chis=8,16` overrides only for smoke tests. Formal benchmark claims
must use the expanded defaults and committed compact artifacts.

Default release matrix:

- CPU Oblix: `16,24,32,48,64,96,128,192`, warmup 2, repeat 9.
- H100 Snellius: `32,48,64,96,128,192,256,384`, warmup 3, repeat 11.

The default `repo` parameters point at public-repo checkout locations on the
target hosts. Override them with `-p repo=/path/to/KrylovKit.c` when needed.
