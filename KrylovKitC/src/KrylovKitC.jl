module KrylovKitC

import TenetNative

export build_native_krylov,
       native_krylov_library,
       native_krylov_capabilities,
       native_eigsolve,
       native_linsolve,
       TENET_NATIVE_KRYLOV_ABI_VERSION,
       TENET_NATIVE_KRYLOV_ABI_VERSION_STRING

const TENET_NATIVE_KRYLOV_ABI_VERSION = TenetNative.TENET_NATIVE_KRYLOV_ABI_VERSION
const TENET_NATIVE_KRYLOV_ABI_VERSION_STRING = TenetNative.TENET_NATIVE_KRYLOV_ABI_VERSION_STRING

"""
    build_native_krylov(; target=:cpu, prefix=...)

Build the native Krylov backend. This is the release-facing alias for the
current TenetNative build function.
"""
function build_native_krylov(; target::Symbol=:cpu, prefix::AbstractString=joinpath(@__DIR__, "..", "deps"))
    return TenetNative.build_native_arnoldi(; target, prefix)
end

"""
    native_krylov_library(; target=:cpu, lib=nothing, autobuild=true)

Resolve the shared library used by `native_eigsolve` and `native_linsolve`.
"""
function native_krylov_library(; lib=nothing, target::Symbol=:cpu, autobuild::Bool=true)
    return TenetNative.native_arnoldi_library(; lib, target, autobuild)
end

native_krylov_capabilities(; kwargs...) =
    TenetNative.native_krylov_capabilities(; kwargs...)

native_eigsolve(args...; kwargs...) =
    TenetNative.native_eigsolve(args...; kwargs...)

native_linsolve(args...; kwargs...) =
    TenetNative.native_linsolve(args...; kwargs...)

end
