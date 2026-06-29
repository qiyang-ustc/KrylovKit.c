# Release JobFiles

These JobFiles are thin release entrypoints. They call the benchmark scripts in
`benchmarks/` and leave raw logs/results under the job run directory.

Use small `*_CHIS=8,16` overrides only for smoke tests. Formal benchmark claims
must use the default large sizes and committed compact artifacts.

The default `repo` parameters point at public-repo checkout locations on the
target hosts. Override them with `-p repo=/path/to/KrylovKit.c` when needed.
