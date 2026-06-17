@testset "Structural transitions" begin
  @test typeof(OMFrontend.parseFile("./VSS/BreakingPendulum.mo")) == Absyn.PROGRAM
  @test typeof(OMFrontend.parseFile("./VSS/SimpleSingleMode.mo")) == Absyn.PROGRAM
  res = flattenFM("SimpleSingleMode", "./VSS/SimpleSingleMode.mo")
  @test typeof(res[1]) == OMFrontend.Frontend.FLAT_MODEL
  res = flattenFM("BreakingPendulum", "./VSS/BreakingPendulum.mo")
  @test typeof(res[1]) == OMFrontend.Frontend.FLAT_MODEL
end

#= Try recompilation =#
@testset "Structural recompilation" begin
  res = flattenFM("ArrayGrow", "./VSS/ArrayGrow.mo")
  @test typeof(res[1]) == OMFrontend.Frontend.FLAT_MODEL
end
