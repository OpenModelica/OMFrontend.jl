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
    local fm = flattenModelInMSL_TST("Modelica.Electrical.Batteries.Examples.CCCV_StackRC"; MSL_V = "MSL_4_1_0")[1]
    @test typeof(fm) == OMFrontend.Frontend.FLAT_MODEL
    local bindingOf = n -> OMFrontend.Frontend.toString(only(filter(v -> OMFrontend.Frontend.toString(v.name) == n, fm.variables)).binding)
    @test bindingOf("stackData.cellData[1, 1].Qnom") == "stackData.cellDataDegraded.Qnom"
    @test bindingOf("stackData.cellData[2, 1].Qnom") == "stackData.cellDataOriginal.Qnom"
  finally
    OMFrontend.Frontend.PARALLEL_INST[] = parallel
  end
end

#= cellData = {{if ... then cellDataDegraded else cellDataOriginal ...}}: the field types of that binding were not
   typed, parallel typing then deduced OCV_SOC_internal's rows from another table (1 run in 3: Real[3, 2] for
   Real[29, 2]). Parallel flattens equal the serial one. =#
@testset "Modelica.Electrical.Batteries record bindings (parallel typing)" begin
  local name = "Modelica.Electrical.Batteries.Examples.CCCV_StackRC"
  local flat = () -> OMFrontend.toFlatModelica(flattenModelInMSL_TST(name; MSL_V = "MSL_4_1_0", scalarize = false))
  local parallel::Bool = OMFrontend.Frontend.PARALLEL_INST[]
  local serial::String = ""
  OMFrontend.Frontend.PARALLEL_INST[] = false
  try
    serial = flat()
  finally
    OMFrontend.Frontend.PARALLEL_INST[] = parallel
  end
  @test occursin("'stack.cell.cell.ocv_soc.table'[3, 2, 29, 2]", serial)
  if Threads.nthreads() >= 2
    OMFrontend.Frontend.PARALLEL_INST[] = true
    try
      @test all(==(serial), (flat() for _ in 1:4))
    finally
      OMFrontend.Frontend.PARALLEL_INST[] = parallel
    end
  end
end
