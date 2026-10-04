#= OMFrontend finds its own lib/ (builtin library, bundled MSL) from where it is loaded.
   It used Base.find_package("OMFrontend"), which resolves the name only where the active
   environment lists OMFrontend directly: with only OM or OMBackend in an environment it
   returned nothing, and the precompile workload and the MSL loading failed there. =#
@testset "packageRoot" begin
  root = OMFrontend.packageRoot()
  @test isfile(joinpath(root, "lib", "NFModelicaBuiltin.mo"))
  @test isfile(joinpath(root, "lib", "Modelica", "MSL_3_2_3.mo"))
  #= src/test.jl is a benchmark script, not part of the package. =#
  local users = String[]
  for (dir, _, files) in walkdir(joinpath(root, "src")), f in files
    endswith(f, ".jl") && f != "test.jl" || continue
    occursin("find_package(\"OMFrontend\")", read(joinpath(dir, f), String)) && push!(users, f)
  end
  @test isempty(users)
end
