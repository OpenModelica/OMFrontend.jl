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
end
