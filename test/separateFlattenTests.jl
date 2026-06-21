#=
  Separate-instantiation flatten tests.

  With `separateInstantiation` off, a normal assembly model is fully inlined.
  With it on, each top-level component is kept as its own entry in
  `structuralSubmodels` (reusing the structural-mode storage) so the backend can
  run index reduction per component. The flag is set per flatten call, so it
  does not leak to later flattens.
=#
const _SEP_MODEL_FILE = joinpath(@__DIR__, "Models", "CoupledPenduliNormal.mo")
_sepNSub(fm) = OMFrontend.Frontend.listLength(fm.structuralSubmodels)

@testset "flag off: assembly is fully inlined" begin
  (fm, _) = OMFrontend.flattenModel("CoupledPenduli", _SEP_MODEL_FILE)
  @test _sepNSub(fm) == 0
  @test length(fm.variables) > 0   # component variables inlined at top level
end

@testset "flag on: each top-level component split out" begin
  (fm, _) = OMFrontend.flattenModel("CoupledPenduli", _SEP_MODEL_FILE;
                                    separateInstantiation = true)
  @test _sepNSub(fm) == 3
  names = Set(sm.name for sm in fm.structuralSubmodels)
  @test names == Set(["tb", "p1", "p2"])
  # The three coupling equations stay at the top level; the component
  # variables move into the submodels.
  @test length(fm.equations) == 3
  @test length(fm.variables) == 0
end

@testset "flag does not leak to later flattens" begin
  (fm, _) = OMFrontend.flattenModel("CoupledPenduli", _SEP_MODEL_FILE)
  @test _sepNSub(fm) == 0
end
