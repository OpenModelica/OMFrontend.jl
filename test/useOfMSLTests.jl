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
