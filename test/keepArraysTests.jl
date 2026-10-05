#= Arrays kept (scalarize = false): the flat model keeps array variables, for-equations and
   array equations; Frontend.scalarizeKeptArrays turns it into the model a scalarizing
   flatten gives (same variables, same equations up to their order). =#
const KEEP_ARRAYS_FILE = "./KeepArrays/KeepArrays.mo"

function _flatEquationSet(fm)
  local F = OMFrontend.Frontend
  return sort([replace(F.toString(eq), " " => "") for eq in fm.equations])
end

_flatVariableSet(fm) = sort([OMFrontend.Frontend.toString(v.name) for v in fm.variables])

function _keepAndScalarized(model)
  local scode = OMFrontend.translateToSCode(OMFrontend.parseFile(KEEP_ARRAYS_FILE))
  local (kept, _) = OMFrontend.instantiateSCodeToFM(model, scode; scalarize = false)
  local (scal, _) = OMFrontend.instantiateSCodeToFM(model, scode; scalarize = true)
  return (kept, scal)
end

@testset "Arrays kept, then scalarized" begin
  for m in ("ArrayDecay", "ArrayDecayVec", "Chain", "ComponentArrayConnects", "RecordArray", "WholeArrayArgument")
    @testset "$m" begin
      local (kept, scal) = _keepAndScalarized("KeepArrays." * m)
      #= Arrays are kept: fewer variables than the scalarized model. =#
      @test length(kept.variables) < length(scal.variables)
      local conv = OMFrontend.Frontend.scalarizeKeptArrays(kept)
      @test _flatVariableSet(conv) == _flatVariableSet(scal)
      @test _flatEquationSet(conv) == _flatEquationSet(scal)
    end
  end
end

@testset "Connects of a component array are resolved" begin
  local scode = OMFrontend.translateToSCode(OMFrontend.parseFile(KEEP_ARRAYS_FILE))
  local text = OMFrontend.toFlatModelica(OMFrontend.instantiateSCodeToFM("KeepArrays.ComponentArrayConnects", scode; scalarize = false))
  @test !occursin("connect(", text)
  @test occursin("'t.g1.y'[1] = /*Equality*/'t.g2.u'[1]", text) || occursin("'t.g2.u'[1] = /*Equality*/'t.g1.y'[1]", text)
end
