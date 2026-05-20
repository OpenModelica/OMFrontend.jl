function flattenModelInMSL_TST(modelName::String; MSL_V = "MSL_3_2_3")
  local key = OMFrontend.loadBundledMSL(version = MSL_V)
  local lib = OMFrontend.LIBRARY_CACHE[key]
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, lib)
end

@test begin
  try
    OMFrontend.loadBundledMSL(version = "3.2.3")
    true
  catch e
    @error "Failed loading bundled MSL 3.2.3:" e
    false
  end
end

#= Simple check that we can flatten the models without exceptions =#
@info "Testing components of the Modelica standard library"
@testset "Modelica Blocks" begin
  @info "Testing Modelica.Blocks.Continuous"
  include("continuous.jl")
  include("sources.jl")
  @testset "Discrete" begin
    #@test typeof(flattenModelInMSL_TST("Modelica.Blocks.Discrete.Sampler")[1]) == OMFrontend.Frontend.FLAT_MODEL
  end
  @testset "Math" begin
    include("math.jl")
  end
  @testset "Mechanics" begin
    @info "Testing Mechanics.Rotational"
    include("rotational.jl")
    @info "Testing Mechanics.Translational"
    include("translational.jl")
    @info "Testing Modelica.Mechanics.MultiBody"
    include("multibody.jl")
  end #= End Mechanics=#
  @testset "Electrical" begin
    @info "Testing Modelica.Electrical.Analog"
    include("analog.jl")
    @info "Testing Modelica.Electrical.Batteries"
    #include("batteries.jl")
  end
  @testset "Fluid" begin
    @info "Testing Modelica.Fluid.Examples"
    include("fluid.jl")
  end
  @testset "Magnetic" begin
    @info "Testing Modelica.Magnetic.FluxTubes"
    include("magnetic.jl")
  end
end
