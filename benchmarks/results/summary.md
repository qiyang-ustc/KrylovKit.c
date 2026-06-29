# Generated Benchmark Tables

## CPU

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |
| ---: | ---: | ---: | ---: | ---: | :--- |
| 32 | 0.001561 | 0.001451 | 0.93x | 4.21e-13 | pass |
| 64 | 0.009271 | 0.011164 | 1.20x | 6.35e-15 | pass |
| 128 | 0.065306 | 0.082468 | 1.26x | 5.16e-14 | pass |

## H100

| chi | KrylovKit.c median (s) | KrylovKit.jl median (s) | speedup | native residual | status |
| ---: | ---: | ---: | ---: | ---: | :--- |
| 64 | 0.022977 | 0.019388 | 0.84x | 2.91e-14 | fail |
| 128 | 0.023078 | 0.092304 | 4.00x | 5.75e-13 | pass |
| 256 | 0.036957 | 0.481650 | 13.03x | 6.00e-14 | pass |
