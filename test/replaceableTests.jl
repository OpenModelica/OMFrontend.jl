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

@testset "Replaceable partial function called via partial default is rejected (OMC parity)" begin
  # UsePartialDefault calls P.compute where P is left at its partial default
  # (AbstractFnPkg2) and never redeclared, so compute is a partial function.
  # This is invalid Modelica; OMC rejects it with "P is partial, name lookup
  # is not allowed in partial classes." The frontend must reject it too.
  @test_throws MetaModelica.MetaModelicaGeneralException _flattenFM_replaceable(
    "UsePartialDefault", _REPL_PKG_FILE)
end
