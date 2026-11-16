#=
Regression coverage for Modelica.Media examples.
=#
@testset "Modelica.Media.Examples (frontend flatten)" begin
  prefix = "Modelica.Media.Examples"
  #= The package constants SingleGasesData.CH4, ... are collected with the binding the
     constant evaluation made from their fields (CEVAL_BINDING), which the subscript
     bounds check could not read (MatchFailure in getTypedExp). =#
  local fm = flattenModelInMSL_TST("$(prefix).Tests.MediaTestModels.IdealGases.SimpleNaturalGas")[1]
  @test typeof(fm) == OMFrontend.Frontend.FLAT_MODEL
  #= ... and kept that value as their binding (Medium.data[1] = SingleGasesData.CH4 read it): the CEVAL_BINDING was
     dropped as temporary when converted for the backend. The inlined bodies that read them have their package constants
     evaluated now (NFInline, as the model's own were): none is collected, as in omc's flat model. =#
  @test !any(v -> occursin("SingleGasesData", OMFrontend.Frontend.toString(v.name)), fm.variables)
end
