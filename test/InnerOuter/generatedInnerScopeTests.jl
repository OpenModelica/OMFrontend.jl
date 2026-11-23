#= Tests for inner/outer fixes in Lookup.jl.
   1. generateInner: qualify relative type paths before reparenting.
   2. resolveInnerCref: fix `node` variable shadowing + skip protection check for inner/outer.
=#

const INNER_OUTER_DIR = joinpath(@__DIR__)

@testset "Generated inner scope qualification" begin
  @test nothing !== OM.flatten(
    "GeneratedInnerScope1",
    joinpath(INNER_OUTER_DIR, "GeneratedInnerScope1.mo"),
    MSL=false
  )
end

@testset "Protected outer with inner/outer resolution" begin
  @test nothing !== OM.flatten(
    "ProtectedOuterTest1",
    joinpath(INNER_OUTER_DIR, "ProtectedOuterTest1.mo"),
    MSL=false
  )
end
