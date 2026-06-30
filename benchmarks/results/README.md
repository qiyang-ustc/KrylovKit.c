# Release Results

Official result artifacts are produced by jobctl. The Snellius H100 and Oblix
CPU artifacts are present.

Expected artifacts:

- `krylov_kernel_gpu_snellius_h100.csv`: completed, `run-2d663d37beac`.
- `krylov_kernel_cpu_oblix.csv`: completed, `run-7bb192d4cc94`.

Each CSV must contain 8 `chi` rows and include residual, iteration, operation,
correctness, and performance-status columns.
