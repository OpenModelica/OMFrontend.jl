#=
Regression coverage for Modelica.Magnetic examples. ArmatureStroke triggers
the `component(::CLASS_NODE)` MatchFailure path in `reconstructRecordInstances`
unless the guard in `NFFlatModel.jl` skips reconstruction when the parent
node is not a `COMPONENT_NODE`. This pins the fix.
=#
@testset "Modelica.Magnetic.FluxTubes (frontend flatten)" begin
  prefix = "Modelica.Magnetic.FluxTubes.Examples.MovingCoilActuator"
  @test typeof(flattenModelInMSL_TST("$(prefix).ArmatureStroke")[1]) == OMFrontend.Frontend.FLAT_MODEL
end
