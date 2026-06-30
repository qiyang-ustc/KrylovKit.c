# KrylovKit.c

This release benchmark measures warmed Krylov kernel timing against KrylovKit.jl
on the same backend and the same real `Float64` arithmetic.

Official CPU results are run on Oblix with `--cpus 4 --mem 4G`. Official GPU
results are run on Snellius H100 with one H100 allocation and `--mem 180G`.
CPU and GPU results are reported as separate tables.

The release sweep is `chi = 32,64,96,128,160,192,224,256`, with 3 warmup runs
and 11 timed repeats. Krylov residuals, iteration counts, operation counts, and
correctness status are part of the benchmark output.
