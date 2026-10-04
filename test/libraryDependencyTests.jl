#= A model of an installed library flattens with the library's key alone: the
   libraries its `uses` annotation names, loaded by loadInstalledLibrary, come along
   (LIBRARY_DEPENDENCIES, libraryClosure). Two libraries installed in a temporary
   directory: LibA uses LibB. =#
@testset "library dependencies" begin
  local dir = mktempdir()
  mkpath(joinpath(dir, "LibB 1.0.0"))
  write(joinpath(dir, "LibB 1.0.0", "package.mo"), """
    package LibB
      model Source
        Real y = 2.0;
      end Source;
      annotation(version = "1.0.0");
    end LibB;
    """)
  mkpath(joinpath(dir, "LibA 1.0.0"))
  write(joinpath(dir, "LibA 1.0.0", "package.mo"), """
    package LibA
      model M
        LibB.Source s;
        Real x(start = 0.0, fixed = true);
      equation
        der(x) = s.y;
      end M;
      annotation(version = "1.0.0", uses(LibB(version = "1.0.0")));
    end LibA;
    """)
  local key = OMFrontend.loadInstalledLibrary("LibA"; version = "1.0.0", installDir = dir)
  @test key == "LibA_1_0_0"
  @test OMFrontend.LIBRARY_DEPENDENCIES[key] == ["LibB_1_0_0"]
  @test OMFrontend.libraryClosure([key]) == ["LibA_1_0_0", "LibB_1_0_0"]
  @test OMFrontend.libraryClosure(["LibB_1_0_0", key]) == ["LibB_1_0_0", "LibA_1_0_0"]
  local flat = OMFrontend.toFlatModelica(OMFrontend.flattenModelWithLibraries("LibA.M", ""; libraries = [key]))
  @test occursin("s.y", flat)
end
