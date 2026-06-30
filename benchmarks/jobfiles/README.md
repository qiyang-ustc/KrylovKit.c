# Release JobFiles

Official release jobs:

- `oblix_krylovkitc_cpu.jobfile.yaml`: CPU run on Oblix `lerner`, requested
  as `--partition lerner --cpus 4 --mem 4G --time 02:00:00`.
- `snellius_krylovkitc_h100.jobfile.yaml`: GPU run on Snellius H100, requested
  as `--partition gpu_h100 --gres gpu:h100:1 --cpus 16 --mem 180G`.

Both jobs prebuild the native library before timed measurement and copy the
final CSV to the artifact name used by the release README.
