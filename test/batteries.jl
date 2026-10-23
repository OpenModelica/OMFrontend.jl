#= Testing a selection of basic components =#
@testset "Batteries.ParameterRecords" begin
  prefix = "Modelica.Electrical.Batteries.ParameterRecords"
  @test typeof(flattenModelInMSL_TST(prefix * ".ExampleData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST(prefix * ".StackData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST(prefix * ".CellData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL

  prefix = "Modelica.Electrical.Batteries.ParameterRecords.TransientData"
  #@test typeof(flattenModelInMSL_TST(prefix * ".ExampleData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
  #@test typeof(flattenModelInMSL_TST(prefix * ".CellData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST(prefix * ".RCData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
  prefix = "Modelica.Electrical.Batteries.Examples"
  @test typeof(flattenModelInMSL_TST(prefix * ".RCData"; MSL_V = "MSL_4_1_0")[1]) == OMFrontend.Frontend.FLAT_MODEL
end #= End Analog =#
