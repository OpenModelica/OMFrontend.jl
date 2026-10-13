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
  #= ... and keep that value as their binding (Medium.data[1] = SingleGasesData.CH4 reads it):
     the CEVAL_BINDING was dropped as temporary when converted for the backend. =#
  local ch4 = only(filter(v -> OMFrontend.Frontend.toString(v.name) == "Modelica.Media.IdealGases.Common.SingleGasesData.CH4",
                          fm.variables))
  @test OMFrontend.Frontend.isvariant(ch4.binding, OMFrontend.Frontend.FLAT_BINDING)
end
