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

#= A function only a structural mode calls is one of the model's functions (none were collected:
   the backend's mode code called an undefined function) =#
@testset "A structural mode's functions" begin
  res = flattenFM("ModeFunction", "./VSS/ModeFunction.mo")
  @test [OMFrontend.Frontend.AbsynUtil.pathString(f.path) for f in OMFrontend.cacheToFunctionList(res[2])] == ["twice"]
end

#= The class a recompilation modifies is the model's (the reversed program's head was the
   input's last class: Modelica for a model using the MSL), the other classes are kept for it =#
@testset "The SCode of a model with recompilation" begin
  res = flattenFM("GrowFirst", "./VSS/RecompilationTwoClasses.mo")
  @test OMFrontend.Frontend.SCodeUtil.elementName(res[1].scodeProgram.data) == "GrowFirst"
  @test [OMFrontend.Frontend.SCodeUtil.elementName(c) for c in OMFrontend.recompilationProgram("GrowFirst")] == ["Other"]
end
