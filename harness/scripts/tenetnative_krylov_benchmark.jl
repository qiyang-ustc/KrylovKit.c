using Dates
using LinearAlgebra
using Printf
using Random

using KrylovKit

const _TENET_NATIVE_REF = Ref{Any}(nothing)

function tenet_native_module(repo::AbstractString)
    mod = _TENET_NATIVE_REF[]
    mod isa Module && return mod
    try
        @eval using TenetNative
        mod = getfield(Main, :TenetNative)
        _TENET_NATIVE_REF[] = mod
        return mod
    catch err
        err isa InterruptException && rethrow()
    end
    source = joinpath(repo, "TenetNative", "src", "TenetNative.jl")
    isfile(source) || error("TenetNative source not found at $source")
    Base.include(Main, source)
    mod = getfield(Main, :TenetNative)
    _TENET_NATIVE_REF[] = mod
    return mod
end

function parse_args(argv)
    opts = Dict{String,String}(
        "repo" => normpath(joinpath(@__DIR__, "..", "..")),
        "outdir" => joinpath(tempdir(), "tenetnative_krylov_benchmark"),
        "backend" => "cpu",
        "problem" => "eigsolve",
        "native-mode" => "fastpath",
        "linsolve-algorithm" => "gmres",
        "chis" => "16,32,64",
        "phys" => "2",
        "max-k" => "30",
        "howmany" => "1",
        "tol" => "1e-12",
        "krylov-maxiter" => "100",
        "allow-failures" => "false",
        "warmup" => "1",
        "repeats" => "3",
        "seed" => "20260628",
        "max-ratio" => "1.10",
        "max-lambda-abs-diff" => "",
        "max-solution-relerr" => "",
        "max-native-relres" => "",
        "max-krylov-relres" => "",
        "lin-a0" => "1.0",
        "lin-a1" => "-0.1",
        "cpu-lib" => get(ENV, "TENET_NATIVE_ARNOLDI_LIB", ""),
        "cuda-lib" => get(ENV, "TENET_NATIVE_ARNOLDI_CUDA_LIB", ""),
    )
    i = 1
    while i <= length(argv)
        arg = argv[i]
        startswith(arg, "--") || error("unexpected positional argument: $arg")
        key = arg[3:end]
        if key in ("help", "h")
            println("""
            Usage:
              julia --project=<env> harness/scripts/tenetnative_krylov_benchmark.jl [options]

            Options:
              --repo PATH
              --outdir PATH
              --backend cpu|cuda
              --problem eigsolve|linsolve
              --native-mode fastpath|generic|dense
              --linsolve-algorithm gmres|cg|bicgstab
              --chis 16,32,64
              --phys INT
              --max-k INT
              --howmany INT
              --tol FLOAT
              --krylov-maxiter INT
              --allow-failures true|false
              --warmup INT
              --repeats INT
              --seed INT
              --max-ratio FLOAT
              --max-lambda-abs-diff FLOAT
              --max-solution-relerr FLOAT
              --max-native-relres FLOAT
              --max-krylov-relres FLOAT
              --lin-a0 FLOAT
              --lin-a1 FLOAT
              --cpu-lib PATH
              --cuda-lib PATH
            """)
            exit(0)
        end
        i == length(argv) && error("missing value for $arg")
        opts[key] = argv[i + 1]
        i += 2
    end
    return (;
        repo = opts["repo"],
        outdir = opts["outdir"],
        backend = lowercase(opts["backend"]),
        problem = lowercase(opts["problem"]),
        native_mode = lowercase(opts["native-mode"]),
        linsolve_algorithm = lowercase(opts["linsolve-algorithm"]),
        chis = [parse(Int, strip(s)) for s in split(opts["chis"], ',') if !isempty(strip(s))],
        phys = parse(Int, opts["phys"]),
        max_k = parse(Int, opts["max-k"]),
        howmany = parse(Int, opts["howmany"]),
        tol = parse(Float64, opts["tol"]),
        krylov_maxiter = parse(Int, opts["krylov-maxiter"]),
        allow_failures = lowercase(opts["allow-failures"]) in ("1", "true", "yes"),
        warmup = parse(Int, opts["warmup"]),
        repeats = parse(Int, opts["repeats"]),
        seed = parse(Int, opts["seed"]),
        max_ratio = parse(Float64, opts["max-ratio"]),
        max_lambda_abs_diff = isempty(opts["max-lambda-abs-diff"]) ? nothing : parse(Float64, opts["max-lambda-abs-diff"]),
        max_solution_relerr = isempty(opts["max-solution-relerr"]) ? nothing : parse(Float64, opts["max-solution-relerr"]),
        max_native_relres = isempty(opts["max-native-relres"]) ? nothing : parse(Float64, opts["max-native-relres"]),
        max_krylov_relres = isempty(opts["max-krylov-relres"]) ? nothing : parse(Float64, opts["max-krylov-relres"]),
        lin_a0 = parse(Float64, opts["lin-a0"]),
        lin_a1 = parse(Float64, opts["lin-a1"]),
        cpu_lib = isempty(opts["cpu-lib"]) ? nothing : opts["cpu-lib"],
        cuda_lib = isempty(opts["cuda-lib"]) ? nothing : opts["cuda-lib"],
    )
end

timestamp_utc() = Dates.format(now(UTC), dateformat"yyyymmddTHHMMSS")

function generate_case(seed::Integer, chi::Integer, phys::Integer)
    rng = MersenneTwister(seed)
    scale = inv(sqrt(Float64(chi * phys)))
    A = zeros(Float64, chi, phys, chi)
    for s in 1:phys
        S = scale .* randn(rng, chi, chi)
        A[:, s, :] .= 0.5 .* (S .+ S')
    end
    x0 = randn(rng, chi, chi)
    return (; A, x0)
end

function two_layer_apply(Aup, Adn, X; transpose::Bool=false)
    chi, phys, chi2 = size(Aup)
    chi == chi2 || error("Aup must be chi x phys x chi")
    size(Adn) == size(Aup) || error("Adn size mismatch")
    size(X) == (chi, chi) || error("X size mismatch")
    Y = similar(X)
    fill!(Y, zero(eltype(Y)))
    for s in 1:phys
        A = Aup[:, s, :]
        B = Adn[:, s, :]
        if transpose
            Y .+= A * X * Base.transpose(B)
        else
            Y .+= Base.transpose(A) * X * B
        end
    end
    return Y
end

function two_layer_dense_matrix(A)
    chi = size(A, 1)
    n = chi * chi
    M = Matrix{Float64}(undef, n, n)
    e = zeros(Float64, n)
    for col in 1:n
        e[col] = 1.0
        M[:, col] .= vec(two_layer_apply(A, A, reshape(e, chi, chi)))
        e[col] = 0.0
    end
    return M
end

function _select_eig_indices(vals, howmany::Integer)
    order = sortperm(abs.(vals); rev=true)
    return order[1:min(howmany, length(order))]
end

function dominant_pair_krylov(A, x0; tol::Real, krylovdim::Integer,
                              maxiter::Integer, howmany::Integer=1)
    chi = size(A, 1)
    v0 = vec(copy(x0))
    op = function(v)
        X = reshape(v, chi, chi)
        return vec(two_layer_apply(A, A, X))
    end
    vals, vecs, info = KrylovKit.eigsolve(
        op,
        v0,
        howmany,
        :LM;
        krylovdim=Int(krylovdim),
        tol=Float64(tol),
        maxiter=Int(maxiter),
    )
    selected = _select_eig_indices(vals, howmany)
    lambdas = vals[selected]
    ys = [reshape(vecs[idx], chi, chi) for idx in selected]
    return (; lambda=lambdas[1], y=ys[1], lambdas, ys, info)
end

function dominant_pair_krylov_dense(M, x0; tol::Real, krylovdim::Integer,
                                    maxiter::Integer, howmany::Integer=1)
    chi = size(x0, 1)
    v0 = vec(copy(x0))
    vals, vecs, info = KrylovKit.eigsolve(
        x -> M * x,
        v0,
        howmany,
        :LM;
        krylovdim=Int(krylovdim),
        tol=Float64(tol),
        maxiter=Int(maxiter),
    )
    selected = _select_eig_indices(vals, howmany)
    lambdas = vals[selected]
    ys = [reshape(vecs[idx], chi, chi) for idx in selected]
    return (; lambda=lambdas[1], y=ys[1], lambdas, ys, info)
end

function eigenpair_relres(A, y, lambda)
    fy = two_layer_apply(A, A, y)
    ynorm = norm(y)
    return norm(fy .- lambda .* y) / max(norm(fy), abs(lambda) * ynorm, ynorm, 1.0)
end

function eigenpairs_relres(A, ys, lambdas)
    return maximum(eigenpair_relres(A, ys[i], lambdas[i]) for i in eachindex(lambdas))
end

function shifted_apply(A, x::AbstractVector, a0::Real, a1::Real)
    chi = size(A, 1)
    X = reshape(x, chi, chi)
    return a0 .* x .+ a1 .* vec(two_layer_apply(A, A, X))
end

function shifted_apply_dense(M::AbstractMatrix, x::AbstractVector, a0::Real, a1::Real)
    return a0 .* x .+ a1 .* (M * x)
end

function linsolve_relres(A, x::AbstractVector, b::AbstractVector, a0::Real, a1::Real)
    fx = shifted_apply(A, x, a0, a1)
    return norm(b .- fx) / max(norm(b), norm(fx), 1.0)
end

function linsolve_relres_dense(M::AbstractMatrix, x::AbstractVector, b::AbstractVector,
                               a0::Real, a1::Real)
    fx = shifted_apply_dense(M, x, a0, a1)
    return norm(b .- fx) / max(norm(b), norm(fx), 1.0)
end

function solution_relerr(x, xref)
    return norm(x .- xref) / max(norm(x), norm(xref), 1.0)
end

function sync_backend(backend::AbstractString)
    if backend == "cuda"
        @eval using CUDA
        Base.invokelatest(CUDA.synchronize)
    end
    return nothing
end

function to_backend(A::Array{Float64,3}, x0::Array{Float64,2}, backend::AbstractString)
    if backend == "cpu"
        return A, x0
    elseif backend == "cuda"
        @eval using CUDA
        Base.invokelatest(CUDA.allowscalar, false)
        return Base.invokelatest(CUDA.CuArray, A), Base.invokelatest(CUDA.CuArray, x0)
    end
    error("unsupported backend $backend")
end

function materialize_matrix(X, backend::AbstractString)
    if backend == "cuda"
        return Base.invokelatest(Array, X)
    end
    return copy(X)
end

function materialize_vector(X, backend::AbstractString)
    if backend == "cuda"
        return vec(Base.invokelatest(Array, X))
    end
    return vec(copy(X))
end

function native_generic_dominant(TN::Module, A, x0, opts)
    chi = size(A, 1)
    v0 = vec(copy(x0))
    op = function(v)
        X = reshape(v, chi, chi)
        return vec(two_layer_apply(A, A, X))
    end
    vals, vecs, info = Base.invokelatest(
        TN.native_eigsolve,
        op,
        v0,
        opts.howmany,
        :LM;
        krylovdim=opts.max_k,
        maxiter=opts.krylov_maxiter,
        tol=opts.tol,
        lib=opts.cpu_lib,
    )
    ys = [reshape(vecs[i], chi, chi) for i in eachindex(vals)]
    return (; lambda=vals[1], y=ys[1], lambdas=vals, ys, info)
end

function native_dense_dominant(TN::Module, M, x0, opts)
    chi = size(x0, 1)
    vals, vecs, info = Base.invokelatest(
        TN.native_eigsolve,
        M,
        vec(copy(x0)),
        opts.howmany,
        :LM;
        krylovdim=opts.max_k,
        maxiter=opts.krylov_maxiter,
        tol=opts.tol,
        lib=opts.cpu_lib,
    )
    ys = [reshape(vecs[i], chi, chi) for i in eachindex(vals)]
    return (; lambda=vals[1], y=ys[1], lambdas=vals, ys, info)
end

function native_generic_linsolve(TN::Module, A, x0, opts)
    chi = size(A, 1)
    b = vec(copy(x0))
    op = function(v)
        X = reshape(v, chi, chi)
        return vec(two_layer_apply(A, A, X))
    end
    x, info = Base.invokelatest(
        TN.native_linsolve,
        op,
        b,
        nothing,
        opts.lin_a0,
        opts.lin_a1;
        algorithm=Symbol(opts.linsolve_algorithm),
        krylovdim=opts.max_k,
        maxiter=opts.krylov_maxiter,
        tol=opts.tol,
        lib=opts.cpu_lib,
    )
    return (; x, info)
end

function native_dense_linsolve(TN::Module, M, x0, opts)
    b = vec(copy(x0))
    x, info = Base.invokelatest(
        TN.native_linsolve,
        M,
        b,
        nothing,
        opts.lin_a0,
        opts.lin_a1;
        algorithm=Symbol(opts.linsolve_algorithm),
        krylovdim=opts.max_k,
        maxiter=opts.krylov_maxiter,
        tol=opts.tol,
        lib=opts.cpu_lib,
    )
    return (; x, info)
end

function native_dominant(TN::Module, A, x0, backend::AbstractString, opts)
    if opts.native_mode == "dense"
        backend == "cpu" || error("native-mode=dense currently supports backend=cpu only")
        return native_dense_dominant(TN, A, x0, opts)
    end
    if opts.native_mode == "generic"
        backend == "cpu" || error("native-mode=generic currently supports backend=cpu only")
        return native_generic_dominant(TN, A, x0, opts)
    end
    if backend == "cpu"
        result = Base.invokelatest(
            TN.tenet_native_dominant_two_layer_d_cpu,
            A,
            A,
            x0;
            max_k=opts.max_k,
            breakdown_tol=opts.tol,
            lib=opts.cpu_lib,
        )
        return (; lambda=result.lambda, y=result.y)
    elseif backend == "cuda"
        result = Base.invokelatest(
            TN.tenet_native_dominant_two_layer_d_cuda,
            A,
            A,
            x0;
            max_k=opts.max_k,
            breakdown_tol=opts.tol,
            lib=opts.cuda_lib,
        )
        return (; lambda=result.lambda, y=result.y)
    end
    error("unsupported backend $backend")
end

function native_linsolve_case(TN::Module, A, x0, backend::AbstractString, opts)
    backend == "cpu" || error("problem=linsolve currently supports backend=cpu only")
    if opts.native_mode == "dense"
        return native_dense_linsolve(TN, A, x0, opts)
    elseif opts.native_mode == "generic"
        return native_generic_linsolve(TN, A, x0, opts)
    end
    error("problem=linsolve supports native-mode=generic or dense, got $(opts.native_mode)")
end

function native_case(TN::Module, case_backend, case_x0, backend::AbstractString, opts)
    if opts.problem == "eigsolve"
        return native_dominant(TN, case_backend, case_x0, backend, opts)
    elseif opts.problem == "linsolve"
        return native_linsolve_case(TN, case_backend, case_x0, backend, opts)
    end
    error("unsupported problem $(opts.problem)")
end

function time_native(TN::Module, case_backend, case_x0, backend::AbstractString, opts)
    timings = Float64[]
    result = nothing
    for _ in 1:opts.warmup
        result = native_case(TN, case_backend, case_x0, backend, opts)
        sync_backend(backend)
    end
    for _ in 1:opts.repeats
        GC.gc()
        t0 = time_ns()
        result = native_case(TN, case_backend, case_x0, backend, opts)
        sync_backend(backend)
        push!(timings, (time_ns() - t0) / 1e9)
    end
    return result, timings
end

function linsolve_krylov(A, x0; algorithm::AbstractString, tol::Real,
                         krylovdim::Integer, maxiter::Integer, a0::Real,
                         a1::Real)
    chi = size(A, 1)
    b = vec(copy(x0))
    op = function(v)
        X = reshape(v, chi, chi)
        return vec(two_layer_apply(A, A, X))
    end
    x, info = if algorithm == "cg"
        KrylovKit.linsolve(
            op,
            b,
            zero(b),
            KrylovKit.CG(; maxiter=Int(maxiter), tol=Float64(tol)),
            Float64(a0),
            Float64(a1),
        )
    elseif algorithm == "bicgstab"
        KrylovKit.linsolve(
            op,
            b,
            zero(b),
            KrylovKit.BiCGStab(; maxiter=Int(maxiter), tol=Float64(tol)),
            Float64(a0),
            Float64(a1),
        )
    else
        KrylovKit.linsolve(
            op,
            b,
            zero(b),
            Float64(a0),
            Float64(a1);
            krylovdim=Int(krylovdim),
            tol=Float64(tol),
            maxiter=Int(maxiter),
        )
    end
    return (; x, info)
end

function linsolve_krylov_dense(M, x0; algorithm::AbstractString, tol::Real,
                               krylovdim::Integer, maxiter::Integer, a0::Real,
                               a1::Real)
    b = vec(copy(x0))
    x, info = if algorithm == "cg"
        KrylovKit.linsolve(
            x -> M * x,
            b,
            zero(b),
            KrylovKit.CG(; maxiter=Int(maxiter), tol=Float64(tol)),
            Float64(a0),
            Float64(a1),
        )
    elseif algorithm == "bicgstab"
        KrylovKit.linsolve(
            x -> M * x,
            b,
            zero(b),
            KrylovKit.BiCGStab(; maxiter=Int(maxiter), tol=Float64(tol)),
            Float64(a0),
            Float64(a1),
        )
    else
        KrylovKit.linsolve(
            x -> M * x,
            b,
            zero(b),
            Float64(a0),
            Float64(a1);
            krylovdim=Int(krylovdim),
            tol=Float64(tol),
            maxiter=Int(maxiter),
        )
    end
    return (; x, info)
end

function krylov_case(case_cpu, x0_cpu, opts; dense_matrix=nothing)
    if opts.problem == "eigsolve"
        return dense_matrix === nothing ?
            dominant_pair_krylov(case_cpu, x0_cpu;
                                 tol=opts.tol,
                                 krylovdim=opts.max_k,
                                 maxiter=opts.krylov_maxiter,
                                 howmany=opts.howmany) :
            dominant_pair_krylov_dense(dense_matrix, x0_cpu;
                                       tol=opts.tol,
                                       krylovdim=opts.max_k,
                                       maxiter=opts.krylov_maxiter,
                                       howmany=opts.howmany)
    elseif opts.problem == "linsolve"
        return dense_matrix === nothing ?
            linsolve_krylov(case_cpu, x0_cpu;
                            algorithm=opts.linsolve_algorithm,
                            tol=opts.tol,
                            krylovdim=opts.max_k,
                            maxiter=opts.krylov_maxiter,
                            a0=opts.lin_a0,
                            a1=opts.lin_a1) :
            linsolve_krylov_dense(dense_matrix, x0_cpu;
                                  algorithm=opts.linsolve_algorithm,
                                  tol=opts.tol,
                                  krylovdim=opts.max_k,
                                  maxiter=opts.krylov_maxiter,
                                  a0=opts.lin_a0,
                                  a1=opts.lin_a1)
    end
    error("unsupported problem $(opts.problem)")
end

function time_krylov(case_cpu, x0_cpu, opts; dense_matrix=nothing)
    timings = Float64[]
    result = nothing
    for _ in 1:opts.warmup
        result = krylov_case(case_cpu, x0_cpu, opts; dense_matrix)
    end
    for _ in 1:opts.repeats
        GC.gc()
        t0 = time_ns()
        result = krylov_case(case_cpu, x0_cpu, opts; dense_matrix)
        push!(timings, (time_ns() - t0) / 1e9)
    end
    return result, timings
end

median_seconds(xs::AbstractVector{<:Real}) = sort(collect(Float64, xs))[cld(length(xs), 2)]

default_correctness_gate(backend::AbstractString) =
    backend == "cuda" ? 2e-11 : 1e-12

resolve_gate(value::Union{Nothing,Float64}, backend::AbstractString) =
    isnothing(value) ? default_correctness_gate(backend) : value

function info_value(info, name::Symbol, default)
    info === nothing && return default
    name in propertynames(info) || return default
    return getproperty(info, name)
end

function info_int(info, name::Symbol)
    value = info_value(info, name, missing)
    value === missing && return -1
    value isa Bool && return Int(value)
    value isa Integer && return Int(value)
    value isa AbstractVector && return count(!iszero, value)
    return -1
end

function info_float(info, name::Symbol)
    value = info_value(info, name, missing)
    value === missing && return NaN
    value isa Real && return Float64(value)
    value isa AbstractVector && return isempty(value) ? NaN : maximum(Float64.(abs.(value)))
    return NaN
end

function result_info(result)
    return :info in propertynames(result) ? result.info : nothing
end

function write_csv(path::AbstractString, rows)
    open(path, "w") do io
        println(io, join((
            "backend", "problem", "native_mode", "chi", "phys", "max_k", "howmany", "tol", "krylov_maxiter",
            "linsolve_algorithm",
            "warmup", "repeats", "native_seconds_min", "native_seconds_median",
            "krylov_seconds_min", "krylov_seconds_median", "native_over_krylov",
            "max_lambda_abs_diff", "max_solution_relerr", "max_native_relres", "max_krylov_relres",
            "native_converged", "krylov_converged", "native_numiter", "krylov_numiter",
            "native_numops", "krylov_numops", "native_info_normres", "krylov_info_normres",
            "native_lambda", "krylov_lambda_real", "krylov_lambda_imag",
            "lambda_abs_diff", "solution_relerr", "native_relres", "krylov_relres",
            "lin_a0", "lin_a1", "status",
        ), ','))
        for row in rows
            println(io, join((
                row.backend,
                row.problem,
                row.native_mode,
                row.chi,
                row.phys,
                row.max_k,
                row.howmany,
                @sprintf("%.3e", row.tol),
                row.krylov_maxiter,
                row.linsolve_algorithm,
                row.warmup,
                row.repeats,
                @sprintf("%.9g", row.native_seconds_min),
                @sprintf("%.9g", row.native_seconds_median),
                @sprintf("%.9g", row.krylov_seconds_min),
                @sprintf("%.9g", row.krylov_seconds_median),
                @sprintf("%.9g", row.native_over_krylov),
                @sprintf("%.9g", row.max_lambda_abs_diff),
                @sprintf("%.9g", row.max_solution_relerr),
                @sprintf("%.9g", row.max_native_relres),
                @sprintf("%.9g", row.max_krylov_relres),
                row.native_converged,
                row.krylov_converged,
                row.native_numiter,
                row.krylov_numiter,
                row.native_numops,
                row.krylov_numops,
                @sprintf("%.9g", row.native_info_normres),
                @sprintf("%.9g", row.krylov_info_normres),
                @sprintf("%.17g", row.native_lambda),
                @sprintf("%.17g", real(row.krylov_lambda)),
                @sprintf("%.17g", imag(row.krylov_lambda)),
                @sprintf("%.9g", row.lambda_abs_diff),
                @sprintf("%.9g", row.solution_relerr),
                @sprintf("%.9g", row.native_relres),
                @sprintf("%.9g", row.krylov_relres),
                @sprintf("%.17g", row.lin_a0),
                @sprintf("%.17g", row.lin_a1),
                row.status,
            ), ','))
        end
    end
    return path
end

function write_markdown(path::AbstractString, rows, opts)
    open(path, "w") do io
        println(io, "# TenetNative vs KrylovKit Benchmark")
        println(io)
        println(io, "- repo: `", opts.repo, "`")
        println(io, "- backend: `", opts.backend, "`")
        println(io, "- problem: `", opts.problem, "`")
        println(io, "- native_mode: `", opts.native_mode, "`")
        println(io, "- chis: `", join(opts.chis, ","), "`")
        println(io, "- phys: `", opts.phys, "`")
        println(io, "- max_k: `", opts.max_k, "`")
        println(io, "- howmany: `", opts.howmany, "`")
        println(io, "- tol: `", @sprintf("%.3e", opts.tol), "`")
        println(io, "- krylov_maxiter: `", opts.krylov_maxiter, "`")
        println(io, "- warmup/repeats: `", opts.warmup, "/", opts.repeats, "`")
        println(io, "- max_ratio gate: `", @sprintf("%.3f", opts.max_ratio), "`")
        println(io, "- max_lambda_abs_diff gate: `", @sprintf("%.3e", rows[1].max_lambda_abs_diff), "`")
        println(io, "- max_solution_relerr gate: `", @sprintf("%.3e", rows[1].max_solution_relerr), "`")
        println(io, "- max_native_relres gate: `", @sprintf("%.3e", rows[1].max_native_relres), "`")
        println(io, "- max_krylov_relres gate: `", @sprintf("%.3e", rows[1].max_krylov_relres), "`")
        if opts.problem == "linsolve"
            println(io, "- linsolve_algorithm: `", opts.linsolve_algorithm, "`")
            println(io, "- linsolve operator: `", opts.lin_a0, " + ", opts.lin_a1, "A`")
        end
        println(io)
        if opts.problem == "eigsolve"
            println(io, "| backend | problem | native mode | chi | native median (s) | krylov median (s) | ratio | |lambda native-krylov| | native relres | krylov relres | status |")
            println(io, "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
        else
            println(io, "| backend | problem | native mode | chi | native median (s) | krylov median (s) | ratio | solution relerr | native relres | krylov relres | status |")
            println(io, "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
        end
        for row in rows
            accuracy_metric = opts.problem == "eigsolve" ? row.lambda_abs_diff : row.solution_relerr
            println(
                io,
                "| ", row.backend,
                " | ", row.problem,
                " | ", row.native_mode,
                " | ", row.chi,
                " | ", @sprintf("%.6f", row.native_seconds_median),
                " | ", @sprintf("%.6f", row.krylov_seconds_median),
                " | ", @sprintf("%.4f", row.native_over_krylov),
                " | ", @sprintf("%.3e", accuracy_metric),
                " | ", @sprintf("%.3e", row.native_relres),
                " | ", @sprintf("%.3e", row.krylov_relres),
                " | ", row.status, " |",
            )
        end
    end
    return path
end

function main(argv)
    opts = parse_args(argv)
    opts.backend in ("cpu", "cuda") || error("backend must be cpu or cuda")
    opts.problem in ("eigsolve", "linsolve") || error("problem must be eigsolve or linsolve")
    opts.native_mode in ("fastpath", "generic", "dense") ||
        error("native-mode must be fastpath, generic, or dense")
    opts.linsolve_algorithm in ("gmres", "cg", "bicgstab") ||
        error("linsolve-algorithm must be gmres, cg, or bicgstab")
    opts.problem == "eigsolve" || opts.native_mode in ("generic", "dense") ||
        error("problem=linsolve supports native-mode=generic or dense")
    opts.native_mode == "fastpath" || opts.backend == "cpu" ||
        error("native-mode=$(opts.native_mode) currently supports backend=cpu only")
    opts.problem == "eigsolve" || opts.backend == "cpu" ||
        error("problem=linsolve currently supports backend=cpu only")
    opts.phys > 0 || error("phys must be positive")
    opts.max_k > 0 || error("max-k must be positive")
    opts.howmany > 0 || error("howmany must be positive")
    opts.repeats > 0 || error("repeats must be positive")
    opts.warmup >= 0 || error("warmup must be nonnegative")
    !isempty(opts.chis) || error("chis must be nonempty")
    all(>(0), opts.chis) || error("all chis must be positive")
    opts.problem == "eigsolve" || opts.howmany == 1 ||
        error("howmany is only meaningful for problem=eigsolve")
    opts.howmany == 1 || opts.native_mode in ("generic", "dense") ||
        error("howmany>1 requires native-mode=generic or dense")
    if opts.howmany > 1
        max_n = maximum(chi -> chi * chi, opts.chis)
        opts.max_k >= max_n ||
            error("howmany>1 currently requires full Arnoldi: max-k=$(opts.max_k) must be >= max chi^2=$max_n")
    end
    opts.backend == "cpu" || isnothing(opts.cuda_lib) || isfile(opts.cuda_lib) ||
        error("cuda lib not found: $(opts.cuda_lib)")
    isnothing(opts.cpu_lib) || isfile(opts.cpu_lib) || error("cpu lib not found: $(opts.cpu_lib)")
    if opts.problem == "eigsolve" && opts.native_mode == "fastpath"
        restarts_env = get(ENV, "TENET_NATIVE_ARNOLDI_RESTARTS", "")
        if isempty(restarts_env)
            ENV["TENET_NATIVE_ARNOLDI_RESTARTS"] = string(opts.krylov_maxiter)
        elseif tryparse(Int, restarts_env) != opts.krylov_maxiter
            error("TENET_NATIVE_ARNOLDI_RESTARTS=$restarts_env must match krylov-maxiter=$(opts.krylov_maxiter) for fair fastpath benchmark")
        end
    end

    if !isnothing(opts.cpu_lib)
        ENV["TENET_NATIVE_ARNOLDI_LIB"] = opts.cpu_lib
    end
    if opts.backend == "cuda" && !isnothing(opts.cuda_lib)
        ENV["TENET_NATIVE_ARNOLDI_CUDA_LIB"] = opts.cuda_lib
    end

    TN = tenet_native_module(opts.repo)
    mkpath(opts.outdir)
    lambda_gate = resolve_gate(opts.max_lambda_abs_diff, opts.backend)
    solution_gate = resolve_gate(opts.max_solution_relerr, opts.backend)
    native_relres_gate = resolve_gate(opts.max_native_relres, opts.backend)
    krylov_relres_gate = resolve_gate(opts.max_krylov_relres, opts.backend)
    rows = NamedTuple[]
    for (index, chi) in enumerate(opts.chis)
        seed = opts.seed + index - 1
        case = generate_case(seed, chi, opts.phys)
        dense_matrix = opts.native_mode == "dense" ? two_layer_dense_matrix(case.A) : nothing
        backend_A, backend_x0 = opts.native_mode == "dense" ?
            (dense_matrix, case.x0) :
            to_backend(case.A, case.x0, opts.backend)

        native_result, native_timings = time_native(TN, backend_A, backend_x0, opts.backend, opts)
        krylov_result, krylov_timings = time_krylov(case.A, case.x0, opts;
                                                   dense_matrix=dense_matrix)

        native_median = median_seconds(native_timings)
        krylov_median = median_seconds(krylov_timings)
        ratio = native_median / max(krylov_median, eps(Float64))
        native_info = result_info(native_result)
        krylov_info = result_info(krylov_result)
        native_converged = info_int(native_info, :converged)
        krylov_converged = info_int(krylov_info, :converged)
        native_numiter = info_int(native_info, :numiter)
        krylov_numiter = info_int(krylov_info, :numiter)
        native_numops = info_int(native_info, :numops)
        krylov_numops = info_int(krylov_info, :numops)
        native_info_normres = info_float(native_info, :normres)
        krylov_info_normres = info_float(krylov_info, :normres)

        native_lambda = NaN
        krylov_lambda = complex(NaN, NaN)
        lambda_abs_diff = NaN
        sol_relerr = NaN
        native_relres = NaN
        krylov_relres = NaN
        if opts.problem == "eigsolve"
            native_lambdas = :lambdas in propertynames(native_result) ?
                native_result.lambdas : [native_result.lambda]
            native_ys = :ys in propertynames(native_result) ?
                [materialize_matrix(y, opts.backend) for y in native_result.ys] :
                [materialize_matrix(native_result.y, opts.backend)]
            krylov_lambdas = :lambdas in propertynames(krylov_result) ?
                krylov_result.lambdas : [krylov_result.lambda]
            krylov_ys = :ys in propertynames(krylov_result) ?
                [Matrix{Float64}(real.(y)) for y in krylov_result.ys] :
                [Matrix{Float64}(real.(krylov_result.y))]
            native_relres = eigenpairs_relres(case.A, native_ys, native_lambdas)
            krylov_relres = eigenpairs_relres(case.A, krylov_ys, krylov_lambdas)
            native_lambda = native_lambdas[1]
            krylov_lambda = krylov_lambdas[1]
            lambda_abs_diff = maximum(abs.(native_lambdas .- krylov_lambdas))
        else
            b = vec(copy(case.x0))
            native_x = materialize_vector(native_result.x, opts.backend)
            krylov_x = vec(copy(krylov_result.x))
            native_relres = dense_matrix === nothing ?
                linsolve_relres(case.A, native_x, b, opts.lin_a0, opts.lin_a1) :
                linsolve_relres_dense(dense_matrix, native_x, b, opts.lin_a0, opts.lin_a1)
            krylov_relres = dense_matrix === nothing ?
                linsolve_relres(case.A, krylov_x, b, opts.lin_a0, opts.lin_a1) :
                linsolve_relres_dense(dense_matrix, krylov_x, b, opts.lin_a0, opts.lin_a1)
            sol_relerr = solution_relerr(native_x, krylov_x)
        end

        status = if opts.problem == "eigsolve"
            (
                ratio <= opts.max_ratio &&
                lambda_abs_diff <= lambda_gate &&
                native_relres <= native_relres_gate &&
                krylov_relres <= krylov_relres_gate
            ) ? "pass" : "fail"
        else
            (
                ratio <= opts.max_ratio &&
                sol_relerr <= solution_gate &&
                native_relres <= native_relres_gate &&
                krylov_relres <= krylov_relres_gate &&
                native_converged > 0 &&
                krylov_converged > 0
            ) ? "pass" : "fail"
        end

        push!(rows, (
            backend = opts.backend,
            problem = opts.problem,
            native_mode = opts.native_mode,
            chi,
            phys = opts.phys,
            max_k = opts.max_k,
            howmany = opts.howmany,
            tol = opts.tol,
            krylov_maxiter = opts.krylov_maxiter,
            linsolve_algorithm = opts.linsolve_algorithm,
            warmup = opts.warmup,
            repeats = opts.repeats,
            native_seconds_min = minimum(native_timings),
            native_seconds_median = native_median,
            krylov_seconds_min = minimum(krylov_timings),
            krylov_seconds_median = krylov_median,
            native_over_krylov = ratio,
            max_lambda_abs_diff = lambda_gate,
            max_solution_relerr = solution_gate,
            max_native_relres = native_relres_gate,
            max_krylov_relres = krylov_relres_gate,
            native_converged,
            krylov_converged,
            native_numiter,
            krylov_numiter,
            native_numops,
            krylov_numops,
            native_info_normres,
            krylov_info_normres,
            native_lambda,
            krylov_lambda,
            lambda_abs_diff,
            solution_relerr = sol_relerr,
            native_relres,
            krylov_relres,
            lin_a0 = opts.lin_a0,
            lin_a1 = opts.lin_a1,
            status,
        ))
        if opts.problem == "eigsolve"
            @printf(
                "TENET_NATIVE_BENCHMARK_CASE backend=%s problem=%s native_mode=%s chi=%d native_median_seconds=%.6f krylov_median_seconds=%.6f ratio=%.6f lambda_abs_diff=%.3e max_lambda_abs_diff=%.3e native_relres=%.3e max_native_relres=%.3e krylov_relres=%.3e max_krylov_relres=%.3e status=%s\n",
                opts.backend, opts.problem, opts.native_mode, chi, native_median,
                krylov_median, ratio, lambda_abs_diff, lambda_gate, native_relres,
                native_relres_gate, krylov_relres, krylov_relres_gate, status,
            )
        else
            @printf(
                "TENET_NATIVE_BENCHMARK_CASE backend=%s problem=%s native_mode=%s linsolve_algorithm=%s chi=%d native_median_seconds=%.6f krylov_median_seconds=%.6f ratio=%.6f solution_relerr=%.3e max_solution_relerr=%.3e native_relres=%.3e max_native_relres=%.3e krylov_relres=%.3e max_krylov_relres=%.3e lin_a0=%.6g lin_a1=%.6g status=%s\n",
                opts.backend, opts.problem, opts.native_mode, opts.linsolve_algorithm, chi, native_median,
                krylov_median, ratio, sol_relerr, solution_gate, native_relres,
                native_relres_gate, krylov_relres, krylov_relres_gate, opts.lin_a0,
                opts.lin_a1, status,
            )
        end
    end

    stem = if opts.backend == "cuda"
        "native_h100_benchmark"
    elseif opts.problem == "linsolve"
        opts.native_mode == "dense" ? "native_cpu_dense_linsolve_benchmark" :
        opts.native_mode == "generic" ? "native_cpu_generic_linsolve_benchmark" :
        "native_cpu_linsolve_benchmark"
    else
        opts.native_mode == "dense" ? "native_cpu_dense_benchmark" :
        opts.native_mode == "generic" ? "native_cpu_generic_benchmark" :
        "native_cpu_benchmark"
    end
    csv_path = write_csv(joinpath(opts.outdir, stem * ".csv"), rows)
    md_path = write_markdown(joinpath(opts.outdir, stem * ".md"), rows, opts)
    if !all(row -> row.status == "pass", rows)
        msg = "benchmark regression detected; see $csv_path and $md_path"
        opts.allow_failures ? @warn(msg) : error(msg)
    end
    println("TENET_NATIVE_BENCHMARK_DONE csv=$csv_path md=$md_path backend=$(opts.backend) timestamp=$(timestamp_utc())")
end

main(ARGS)
