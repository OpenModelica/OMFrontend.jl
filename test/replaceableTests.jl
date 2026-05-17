function _flattenFM_replaceable(model::String, file::String)
  local sp = OMFrontend.parseFile(file)
  local scode = OMFrontend.translateToSCode(sp)
  return OMFrontend.instantiateSCodeToFM(model, scode)
end

const _REPL_PKG_FILE = "./Models/ReplaceablePkgTest.mo"

@testset "Replaceable package: simple partial-extends" begin
  (fm, _) = _flattenFM_replaceable("ReplaceablePkgTest", _REPL_PKG_FILE)
  local s = OMFrontend.toString(fm)
  @test occursin("p_start", s)
  @test occursin("T_start", s)
end

@testset "Replaceable package: abstract function + abstract type (Buildings pattern)" begin
  (fm, _) = _flattenFM_replaceable("HeaterDryAir", _REPL_PKG_FILE)
  local s = OMFrontend.toString(fm)
  @test occursin("h_start", s)
end

@testset "Replaceable partial function called via partial default (Buildings/PartialMedium pattern)" begin
  # UsePartialDefault calls P.compute where P is still the partial default.
  # This is invalid Modelica; the frontend should reject it gracefully.
  # With the CLASS_TREE_EXPANDED_TREE no-op fix the crash (MethodError) is
  # gone -- the error is now a controlled assertion. The @test_broken tracks
  # that full redeclaration-context propagation (Fix #2) is still outstanding.
  @test_broken begin
    (fm, _) = _flattenFM_replaceable("UsePartialDefault", _REPL_PKG_FILE)
    true
  end
end
