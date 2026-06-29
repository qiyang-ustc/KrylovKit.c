function env_value(name::String, default::String)
    value = get(ENV, name, "")
    return isempty(value) ? default : value
end

repo = normpath(joinpath(@__DIR__, "..", ".."))
script = joinpath(repo, "harness", "scripts", "tenetnative_krylov_benchmark.jl")
outdir = env_value("KRYLOVKITC_OUTDIR", joinpath(repo, "results", "krylovkitc_h100"))

cmd = `$(Base.julia_cmd()) --project=$(joinpath(repo, "benchmarks", "krylovkit")) --startup-file=no $script
    --repo $repo
    --outdir $outdir
    --backend cuda
    --problem $(env_value("KRYLOVKITC_PROBLEM", "eigsolve"))
    --native-mode $(env_value("KRYLOVKITC_NATIVE_MODE", "fastpath"))
    --linsolve-algorithm $(env_value("KRYLOVKITC_LINSOLVE_ALGORITHM", "gmres"))
    --chis $(env_value("KRYLOVKITC_CHIS", "64,128,256"))
    --phys $(env_value("KRYLOVKITC_PHYS", "2"))
    --max-k $(env_value("KRYLOVKITC_KRYLOVDIM", "30"))
    --howmany $(env_value("KRYLOVKITC_HOWMANY", "1"))
    --tol $(env_value("KRYLOVKITC_TOL", "1e-12"))
    --krylov-maxiter $(env_value("KRYLOVKITC_MAXITER", "100"))
    --allow-failures $(env_value("KRYLOVKITC_ALLOW_FAILURES", "false"))
    --warmup $(env_value("KRYLOVKITC_WARMUP", "2"))
    --repeats $(env_value("KRYLOVKITC_REPEATS", "7"))
    --seed $(env_value("KRYLOVKITC_SEED", "20260628"))
    --max-ratio $(env_value("KRYLOVKITC_MAX_RATIO", "0.75"))
    --max-lambda-abs-diff $(env_value("KRYLOVKITC_MAX_LAMBDA_ABS_DIFF", "2e-10"))
    --max-solution-relerr $(env_value("KRYLOVKITC_MAX_SOLUTION_RELERR", "2e-10"))
    --max-native-relres $(env_value("KRYLOVKITC_MAX_NATIVE_RELRES", "1e-10"))
    --max-krylov-relres $(env_value("KRYLOVKITC_MAX_KRYLOV_RELRES", "1e-10"))
    --lin-a0 $(env_value("KRYLOVKITC_LIN_A0", "1.0"))
    --lin-a1 $(env_value("KRYLOVKITC_LIN_A1", "-0.1"))`

run(cmd)
