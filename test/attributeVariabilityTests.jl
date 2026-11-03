#= The builtin attributes have parameter variability: a non-structural parameter's binding is one (a parameter computed
   by an external call), a discrete one is an error (OpenModelica's NFTyping.typeTypeAttribute). =#
const _ATTRIBUTE_VARIABILITY_FILE = "./Models/AttributeVariabilityTest.mo"

@testset "a start bound to a parameter computed by an external call" begin
  (fm, _) = flattenFM("AttributeVariabilityTest.StartOfExternalParameter", _ATTRIBUTE_VARIABILITY_FILE)
  @test occursin("start = s", OMFrontend.toString(fm))
end

@testset "a start bound to a discrete variable is rejected" begin
  @test_throws MetaModelica.MetaModelicaGeneralException flattenFM("AttributeVariabilityTest.StartOfDiscrete",
                                                                   _ATTRIBUTE_VARIABILITY_FILE)
end
