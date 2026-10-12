#=
Test for the multibody components
=#
@testset "Modelica.Mechanics.MultiBody.Parts" begin
  @info "Modelica.Mechanics.MultiBody.Parts"
  prefix = "Modelica.Mechanics.MultiBody.Parts"
  #= The parts declare `outer World world`: flattened on their own, omc refuses them (a
     top-level outer) unless --allowNonStandardModelica=nonStdTopLevelOuter. =#
  local flags = OMFrontend.Frontend.FlagsUtil.backupFlags()
  OMFrontend.Frontend.FlagsUtil.readArgs(OMFrontend.Frontend.list("--allowNonStandardModelica=nonStdTopLevelOuter"))
  try
    @test typeof(flattenModelInMSL_TST("$(prefix).Fixed")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).FixedTranslation")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).Body")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).BodyShape")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).BodyBox")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).BodyCylinder")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).PointMass")[1]) == OMFrontend.Frontend.FLAT_MODEL
    @test typeof(flattenModelInMSL_TST("$(prefix).Mounting1D")[1]) == OMFrontend.Frontend.FLAT_MODEL
  finally
    OMFrontend.Frontend.FlagsUtil.saveFlags(flags)
  end
end

@testset "Testing to Flatten Modelica.Mechanics.MultiBody.Examples.Elementary..." begin
  @info "Testing to Flatten Modelica.Mechanics.MultiBody.Examples.Elementary"
  prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
  @test typeof(flattenModelInMSL_TST("$(prefix).DoublePendulum")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).DoublePendulumInitTip")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).ForceAndTorque")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).FreeBody")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).InitSpringConstant")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).LineForceWithTwoMasses")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).Pendulum")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).PendulumWithSpringDamper")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).PointGravity")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).PointGravityWithPointMasses")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).PointGravityWithPointMasses2")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).SpringDamperSystem")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).SpringMassSystem")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).SpringWithMass")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).ThreeSprings")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).RollingWheel")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).RollingWheelSetDriving")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).RollingWheelSetPulling")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).HeatLosses")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).UserDefinedGravityField")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).Surfaces")[1]) == OMFrontend.Frontend.FLAT_MODEL
  #= Add more examples here! =#
end #= Modelica.Mechanics.MultiBody.Examples.Elementary=#


@testset "Testing to Flatten Modelica.Mechanics.MultiBody.Examples.Loops.Utilities" begin
  prefix = "Modelica.Mechanics.MultiBody.Examples.Loops.Utilities"
  @info "Testing to flatten $prefix"
  @test typeof(flattenModelInMSL_TST("$(prefix).Cylinder")[1]) == OMFrontend.Frontend.FLAT_MODEL
end
#=
Test some of the models in loops including the V6 Engine model
=#
@testset "Testing to Flatten Modelica.Mechanics.MultiBody.Examples.Loops..." begin
  @info "Testing to Flatten Modelica.Mechanics.MultiBody.Examples.Loops"
  prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  @test typeof(flattenModelInMSL_TST("$(prefix).Engine1a")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).Engine1b")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).Engine1b_analytic")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).EngineV6")[1]) == OMFrontend.Frontend.FLAT_MODEL
end #= Modelica.Mechanics.MultiBody.Examples.Elementary=#
