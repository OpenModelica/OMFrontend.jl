#= Arrays kept (scalarize = false): the flat model keeps array variables, for-equations and
   array equations; Frontend.scalarizeKeptArrays turns it into the model a scalarizing
   flatten gives (same variables, same equations up to their order). =#
const KEEP_ARRAYS_FILE = "./KeepArrays/KeepArrays.mo"

const _FLOW_SUM = r"^\(?-?[\w.\[\]$]+\)?(?:[-+][\w.\[\]$]+)+=0\.0$"

"""
  An equation (its text without spaces) with the terms of a connection's flow sum sorted. The
  connection sets keep their connectors in insertion order, and the two flattens add the flows of
  an array connector in a different order, so a sum's terms may come in a different order.
"""
function _canonicalEquation(eq::String)::String
  occursin(_FLOW_SUM, eq) || return eq
  local terms::Vector{String} = [m.match for m in eachmatch(r"\(?[-+]?[\w.\[\]$]+\)?", replace(eq, "=0.0" => ""))]
  local signed::Vector{String} = [(startswith(t, "(-") || startswith(t, "-") ? "-" : "+") * strip(t, ['(', ')', '-', '+']) for t in terms]
  return join(sort(signed)) * "=0.0"
end

function _flatEquationSet(fm)
  local F = OMFrontend.Frontend
  return sort([_canonicalEquation(replace(F.toString(eq), " " => "")) for eq in fm.equations])
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

@testset "A parameter field of a component array read in its class: the reference kept" begin
  #= dp_nominal_pos evaluated in the elements' shared class is the field over all of them ({2.0, 3.0, 1.0}), an
     operand of another type than the Real the equation was typed for: kept as the reference (NFEvalConstants;
     Buildings' PressureDrop[nRes] resSeries) =#
  local program = OMFrontend.OMParser.parseString("""
    package FieldThroughBinding
      model NominalResistance
        parameter Real dp_nominal;
        final parameter Real dp_nominal_pos = abs(dp_nominal);
        final parameter Boolean computeFlowResistance = dp_nominal_pos > 1e-10 annotation(Evaluate = true);
        Real dp = dp_nominal_pos * time;
        Real y;
      equation
        if computeFlowResistance then
          y = dp / sqrt(dp_nominal_pos);
        else
          y = 0;
        end if;
      end NominalResistance;
      model M
        parameter Integer n = 3;
        parameter Real dp_nominal = 1;
        NominalResistance res[n](dp_nominal = {dp_nominal * (1 + mod(i, 3)) for i in 1:n});
      end M;
    end FieldThroughBinding;
    """)
  local (fm, _) = OMFrontend.instantiateSCodeToFM("FieldThroughBinding.M", OMFrontend.translateToSCode(program); scalarize = false)
  local flat = OMFrontend.toString(fm)
  @test occursin("res[\$i1].y = res[\$i1].dp / sqrt(res[\$i1].dp_nominal_pos)", flat)
  @test !occursin("sqrt({", flat)
end
