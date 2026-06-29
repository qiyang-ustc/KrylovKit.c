using Test
using KrylovKitC

@testset "KrylovKitC API" begin
    @test TENET_NATIVE_KRYLOV_ABI_VERSION >= 4
    @test occursin("krylov", TENET_NATIVE_KRYLOV_ABI_VERSION_STRING)
    @test native_eigsolve isa Function
    @test native_linsolve isa Function
    @test native_krylov_library isa Function
end

if get(ENV, "KRYLOVKITC_RUN_RELEASE_GATE", "0") == "1"
    include(joinpath(@__DIR__, "..", "..", "TenetNative", "test", "native_krylovkit_parity.jl"))
end
