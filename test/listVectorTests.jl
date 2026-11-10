#=
Lists where Vectors are stored and Vectors where lists are expected, in expressions and subscripts
(found by the ImmutableList 0.6.0 review). The models in ./Models/ListVectorSites.mo that failed
before; the functions that models do not reach (their inputs are built here).
=#

import ImmutableList

const LIST_VECTOR_SITES = "./Models/ListVectorSites.mo"

"""
    listVectorFlat(model::String)::String

The flat Modelica of `ListVectorSites.<model>` (scalarized).
"""
function listVectorFlat(model::String)::String
  return OMFrontend.toFlatModelica(OMFrontend.flattenModel("ListVectorSites." * model, LIST_VECTOR_SITES))
end

"""
    listVectorRhs(model::String)::OMFrontend.Frontend.Expression

The right-hand side of the last equation of `ListVectorSites.<model>` flattened with arrays kept.
"""
function listVectorRhs(model::String)::OMFrontend.Frontend.Expression
  local (fm, _) = OMFrontend.flattenModel("ListVectorSites." * model, LIST_VECTOR_SITES; scalarize = false)
  return fm.equations[end].rhs
end

@testset "Lists and Vectors in expressions and subscripts" begin
  local F = OMFrontend.Frontend
  local I = F.INTEGER_EXPRESSION
  local intVector(xs::Vector{Int})::F.Expression =
    F.makeArray(F.TYPE_ARRAY(F.TYPE_INTEGER(), ImmutableList.list(F.fromInteger(length(xs)))),
                F.Expression[I(x) for x in xs]; literal = true)
  local slice24::F.Subscript = F.SUBSCRIPT_SLICE(intVector([2, 4]))

  @testset "a field of an empty array of records (recordElement)" begin
    local flat::String = listVectorFlat("EmptyRecordArray")
    @test occursin("constant Real sc = 0.0;", flat)
  end

  @testset "matrix() of a constant 3-dimensional array (toScalar, evalBuiltinMatrix2)" begin
    local flat::String = listVectorFlat("MatrixOfThreeDims")
    @test occursin("'mc[1,1]' = 1.0;", flat) && occursin("'mc[1,2]' = 2.0;", flat)
    @test occursin("'mc[2,1]' = 3.0;", flat) && occursin("'mc[2,2]' = 4.0;", flat)
    #= the parameter stays a subscripted call; its subscripts print in order =#
    @test occursin(r"'m\[1,2\]' = 'subscript[^']*'\(matrix\([^)]*\),1,2\);", flat)
  end

  @testset "a range subscripted with a literal slice (applySubscriptRange)" begin
    local r::F.Expression = F.applySubscript(slice24, F.makeRange(I(1), F.NONE(), I(5)), ImmutableList.nil)
    @test r isa F.ARRAY_EXPRESSION && F.toString(r) == "{2, 4}"
  end

  @testset "a type name subscripted with a slice (applySubscriptTypename)" begin
    local r::F.Expression = F.applySubscript(F.SUBSCRIPT_SLICE(intVector([1, 2])),
                                             F.TYPENAME_EXPRESSION(F.TYPE_BOOLEAN()), ImmutableList.nil)
    @test r isa F.ARRAY_EXPRESSION && F.toString(r) == "{false, true}"
  end

  @testset "der(x)[i] is der(x[i]), as in OpenModelica (applySubscriptCall)" begin
    local derx::F.Expression = listVectorRhs("DerSubscript")
    local r::F.Expression = F.applySubscript(F.SUBSCRIPT_INDEX(I(1)), derx, ImmutableList.nil)
    @test r isa F.CALL_EXPRESSION && F.toString(r) == "der(x[1])"
  end

  @testset "operator record constructor bindings: other calls kept (patchOperatorRecordConstructorBinding)" begin
    local derx::F.Expression = listVectorRhs("DerSubscript")
    local preb::F.Expression = listVectorRhs("PreSubscript")
    @test F.patchOperatorRecordConstructorBinding_traverser(derx, preb.call.fn) === derx
  end

  @testset "a subscripted type name is reported (checkUnsubscriptableCref)" begin
    #= The frontend prints its error messages when it fails. =#
    local printed::String = mktemp() do path::String, io::IOStream
      local failed::Bool = false
      redirect_stdout(io) do
        try
          listVectorFlat("TypenameSubscript")
        catch
          failed = true
        end
      end
      flush(io)
      failed ? read(path, String) : ""
    end
    @test occursin("Wrong number of subscripts in E[2:3] (1 subscripts for 0 dimensions)", printed)
  end

  @testset "subscripts scalarized (Subscript.scalarize, scalarizeList)" begin
    local subs = F.scalarize(slice24, F.fromInteger(5))
    @test subs isa ImmutableList.Cons{F.Subscript} && map(F.toString, collect(subs)) == ["2", "4"]
    local all = F.scalarizeList(ImmutableList.Cons{F.Subscript}(F.SUBSCRIPT_INDEX(I(3)), ImmutableList.nil),
                                ImmutableList.list(F.fromInteger(5), F.fromInteger(2)))
    @test [map(F.toString, collect(s)) for s in all] == [["3"], ["1", "2"]]
  end
end
