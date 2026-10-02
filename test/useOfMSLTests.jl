@info "Testing components of the Modelica standard library"

@testset "MSL Loading tests" begin
  @test begin
    try
      OMFrontend.loadBundledMSL(version = "3.2.3")
      true
    catch e
      @error "Failed loading bundled MSL 3.2.3:" e
      false
    end
  end

  @test true == begin
    key = OMFrontend.loadBundledMSL(version = "3.2.3")
    res = OMFrontend.flattenModelWithLibraries("ElectricalTest.SimpleCircuit",
                                               "./MSL_Use/SimpleCircuitMSL.mo";
                                               libraries = [key])
    println(OMFrontend.toString(first(res)))
    true
  end

  @test true == begin
    key = OMFrontend.loadBundledMSL(version = "3.2.3")
    res = OMFrontend.flattenModelWithLibraries("TransmissionLine",
                                               "./MSL_Use/TransmissionLine.mo";
                                               libraries = [key])
    println(OMFrontend.toString(first(res)))
    true
  end

  #= Expandable-connector buses at scale (control buses with virtual elements). =#
  @test begin
    key = OMFrontend.loadBundledMSL(version = "4.0.0")
    lib = OMFrontend.LIBRARY_CACHE[key]
    (fm, _) = OMFrontend.instantiateSCodeToFM(
      "Modelica.Mechanics.MultiBody.Examples.Systems.RobotR3.FullRobot", lib)
    length(fm.equations) > 4000
  end
end

#= The parallel path gives the serial path's flat model, on every run. A parameter bound to a
   structural parameter's cref becomes structural when its binding is typed; with the bindings
   typed in parallel, which parameters did (and were folded) varied from run to run. =#
@testset "Parallel typing gives the serial flat model" begin
  if Threads.nthreads() < 2
    @test_skip "needs 2 or more threads"
  else
    local key = OMFrontend.loadBundledMSL(version = "3.2.3")
    local lib = OMFrontend.LIBRARY_CACHE[key]
    flat(m) = OMFrontend.toString(first(OMFrontend.instantiateSCodeToFM(m, lib)))
    for m in ("Modelica.Electrical.Machines.Examples.ControlledDCDrives.PositionControlledDCPM",
              "Modelica.Magnetic.FundamentalWave.Examples.BasicMachines.AIMS_Start")
      local par = OMFrontend.Frontend.PARALLEL_INST[]
      local serial = try
        OMFrontend.Frontend.PARALLEL_INST[] = false
        flat(m)
      finally
        OMFrontend.Frontend.PARALLEL_INST[] = par
      end
      @test all(==(serial), (flat(m) for _ in 1:4))
    end
  end
end
