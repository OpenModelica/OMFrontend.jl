#= Libraries loaded into the session (useLibrary!) come along to flattenModelWithLibraries without
   `libraries`; two loaded libraries may not share a top-level name. Installed in a temporary
   directory: Lib 1.0.0 and 2.0.0 (constant k = 1, 2), and App, which uses Lib 2.0.0. =#
@testset "loaded libraries" begin
  local dir = mktempdir()
  for (v, k) in (("1.0.0", 1), ("2.0.0", 2))
    mkpath(joinpath(dir, "Lib $v"))
    write(joinpath(dir, "Lib $v", "package.mo"), """
      package Lib
        constant Real k = $k;
        annotation(version = "$v");
      end Lib;
      """)
  end
  mkpath(joinpath(dir, "App 1.0.0"))
  write(joinpath(dir, "App 1.0.0", "package.mo"), """
    package App
      model M
        Real y = 10 * Lib.k;
      end M;
      annotation(version = "1.0.0", uses(Lib(version = "2.0.0")));
    end App;
    """)
  local model = joinpath(dir, "UsesLib.mo")
  write(model, "model UsesLib\n  Real y = Lib.k;\nend UsesLib;\n")
  flat(name, file; kwargs...) = OMFrontend.toFlatModelica(OMFrontend.flattenModelWithLibraries(name, file; kwargs...))
  local v1 = OMFrontend.loadInstalledLibrary("Lib"; version = "1.0.0", installDir = dir)
  local v2 = OMFrontend.loadInstalledLibrary("Lib"; version = "2.0.0", installDir = dir)
  @test isempty(OMFrontend.loadedLibraries())
  @test OMFrontend.useLibrary!(v1) == v1
  @test OMFrontend.loadedLibraries() == [v1]
  @test occursin("= 1.0", flat("UsesLib", model))
  #= the other version: at the load, and named in `libraries` =#
  local e = try OMFrontend.useLibrary!(v2); nothing catch err; err end
  @test e isa ErrorException && occursin(v1, e.msg) && occursin(v2, e.msg) && occursin("unloadLibrary", e.msg)
  @test_throws ErrorException flat("UsesLib", model; libraries = [v2])
  @test OMFrontend.unloadLibrary(v1) == [v1]
  @test !haskey(OMFrontend.LIBRARY_CACHE, v1)
  @test_throws ErrorException OMFrontend.unloadLibrary(v1)
  #= a library with the one it uses: that one is loaded with it, and unloaded with it =#
  local app = OMFrontend.useLibrary!(OMFrontend.loadInstalledLibrary("App"; version = "1.0.0", installDir = dir))
  @test OMFrontend.loadedLibraries() == [app, v2]
  @test occursin("= 2.0", flat("UsesLib", model))
  @test occursin("20.0", flat("App.M", ""))
  @test_throws ErrorException OMFrontend.unloadLibrary(v2)
  @test OMFrontend.unloadLibrary(app) == [app, v2]
  @test isempty(OMFrontend.loadedLibraries())
  #= a loaded Modelica is the MSL of MSL = true; another MSL_Version is an error =#
  local fake = joinpath(dir, "Modelica.mo")
  write(fake, "package Modelica\n  constant Real c = 7.0;\n  annotation(version = \"9.9.9\");\nend Modelica;\n")
  write(model, "model UsesLib\n  Real y = Modelica.c;\nend UsesLib;\n")
  OMFrontend.useLibrary!(OMFrontend.loadLibrary(fake))
  try
    @test OMFrontend.loadedModelica() == "Modelica"
    @test occursin("= 7.0", flat("UsesLib", model; MSL = true))
    @test_throws ErrorException flat("UsesLib", model; MSL = true, MSL_Version = "MSL:3.2.3")
  finally
    OMFrontend.unloadLibrary("Modelica")
  end
end
