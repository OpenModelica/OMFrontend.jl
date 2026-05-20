#=
Regression coverage for Modelica.Fluid examples. Each entry used to fail with
`UndefVarError: isIterator` because `BindingExpression.isIterator(::Expression)`
declared a local `isIterator::Bool` that shadowed the recursive dispatch into
`isIterator(::ComponentRef)`. Fix lives in
`OMFrontend.jl/src/NewFrontend/BindingExpression.jl`; these tests pin the fix.
=#
@testset "Modelica.Fluid.Examples (frontend flatten)" begin
  prefix = "Modelica.Fluid.Examples"
  @test typeof(flattenModelInMSL_TST("$(prefix).BranchingDynamicPipes")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).HeatExchanger.HeatExchangerSimulation")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).HeatingSystem")[1]) == OMFrontend.Frontend.FLAT_MODEL
  @test typeof(flattenModelInMSL_TST("$(prefix).IncompressibleFluidNetwork")[1]) == OMFrontend.Frontend.FLAT_MODEL
end
