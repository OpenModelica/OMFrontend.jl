#=
Regression coverage for Modelica.Media examples.
=#
@testset "Modelica.Media.Examples (frontend flatten)" begin
  prefix = "Modelica.Media.Examples"
  #= The package constants SingleGasesData.CH4, ... are collected with the binding the
     constant evaluation made from their fields (CEVAL_BINDING), which the subscript
     bounds check could not read (MatchFailure in getTypedExp). =#
  @test typeof(flattenModelInMSL_TST("$(prefix).Tests.MediaTestModels.IdealGases.SimpleNaturalGas")[1]) == OMFrontend.Frontend.FLAT_MODEL
end
