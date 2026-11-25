# Tests of the precompile workload (src/Precompilation/precompilation.jl): every step succeeds, and
# the display shows a failing step and goes on.
# Author: John Tinnerholm

@testset "Precompile workload" begin
  @test OMFrontend._duration(UInt64(850_000_000)) == "850 ms"
  @test OMFrontend._duration(UInt64(1_940_000_000)) == "1.9 s"
  @test OMFrontend._bar(4, 8, 8) == "━━━━────"
  @test OMFrontend._shortName("Modelica.Electrical.Analog.Examples.NandGate") == "NandGate (Analog)"
  @test OMFrontend._shortName("Modelica.Fluid.Examples.Tanks.EmptyTanks") == "EmptyTanks (Fluid)"

  local io::IOBuffer = IOBuffer()
  local context::IOContext = IOContext(io, :color => false)
  @test_logs (:warn, r"Precompilation workload failed: broken") OMFrontend._precompileStep(() -> error("boom"), context, "broken")
  OMFrontend._precompileStep(() -> nothing, context, "works"; prefix = "1/1 ")
  local display::String = String(take!(io))
  @test occursin("✗ broken", display) && occursin("failed", display)
  @test occursin("✓ 1/1 works", display)

  #= the whole workload, as when the package precompiles: no step fails =#
  local shown::String = mktemp() do path::String, file::IOStream
    redirect_stdout(file) do
      OMFrontend.workload()
    end
    flush(file)
    read(path, String)
  end
  @test occursin("Modelica ▸ Parse ▸ SCode", shown)
  @test count("✓", shown) == 3 + length(OMFrontend.PRECOMPILE_MODELS)
  @test !occursin("✗", shown)
end
