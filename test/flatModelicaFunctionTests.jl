#=
The flat Modelica of models with functions (found by the general review, 2026-11-09): an external
function (no body) and the function tree of a model with one function (a leaf) or none (empty).
=#

const FLAT_MODELICA_FUNCTIONS = "./Models/FlatModelicaFunctions.mo"

@testset "Flat Modelica of models with functions" begin
  @testset "an external function" begin
    local flat::String = OMFrontend.toFlatModelica(OMFrontend.flattenModel("FlatModelicaFunctions.ExternalFunction",
                                                                           FLAT_MODELICA_FUNCTIONS))
    @test occursin("external \"C\" y = ext_sin(x);", flat)
    @test occursin("public Real y = 'FlatModelicaFunctions.extSin'(time);", flat)
  end

  @testset "the function tree passed separately: $(model)" for (model, fn) in (("OneFunction", "twice"),
                                                                                ("NoFunction", ""))
    local (fm, functions) = OMFrontend.flattenModel("FlatModelicaFunctions." * model, FLAT_MODELICA_FUNCTIONS)
    local flat::String = OMFrontend.toFlatModelica(fm, functions)
    @test occursin("public Real y = ", flat)
    @test isempty(fn) ? !occursin("function", flat) : occursin("function 'FlatModelicaFunctions.$(fn)'", flat)
  end
end
