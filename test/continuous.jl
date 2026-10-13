  @testset "Continuous" begin
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.Integrator")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.LimIntegrator")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.Derivative")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.FirstOrder")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.SecondOrder")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.PI")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.PID")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.LimPID")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.TransferFunction")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.StateSpace")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.Der")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.LowpassButterworth")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("Modelica.Blocks.Continuous.CriticalDamping")[1]) == OMFrontend.Frontend.FLAT_MODEL
    #= Filter's f_cut has no default value. =#
    @test typeof(withNonStandardModelica(() -> flattenModelInMSL_TST("Modelica.Blocks.Continuous.Filter"),
                                         "implicitParameterStartAttribute")[1]) == OMFrontend.Frontend.FLAT_MODEL
  end
