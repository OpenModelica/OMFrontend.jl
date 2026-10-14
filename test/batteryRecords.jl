#=
Record parameters bound to records (MSL 4 Modelica.Electrical.Batteries), flattened serially:
the binding split is under test, not the parallel typing.
=#
@testset "Modelica.Electrical.Batteries record bindings (frontend flatten)" begin
  local parallel = OMFrontend.Frontend.PARALLEL_INST[]
  OMFrontend.Frontend.PARALLEL_INST[] = false
  try
    #= stackData(cellDataOriginal = cellDataOriginal): the record under its binding information
       was not split, so its constant CellType had no value (1.7.2's check refused it); and
       cellData[Ns, Np] = {{if anyTrue(...) then cellDataDegraded else cellDataOriginal ...}}:
       each element the record its condition chooses (omc). =#
    local fm = flattenModelInMSL_TST("Modelica.Electrical.Batteries.Examples.CCCV_StackRC"; MSL_V = "MSL_4_0_0")[1]
    @test typeof(fm) == OMFrontend.Frontend.FLAT_MODEL
    local bindingOf = n -> OMFrontend.Frontend.toString(only(filter(v -> OMFrontend.Frontend.toString(v.name) == n, fm.variables)).binding)
    @test bindingOf("stackData.cellData[1, 1].Qnom") == "stackData.cellDataDegraded.Qnom"
    @test bindingOf("stackData.cellData[2, 1].Qnom") == "stackData.cellDataOriginal.Qnom"
  finally
    OMFrontend.Frontend.PARALLEL_INST[] = parallel
  end
end
