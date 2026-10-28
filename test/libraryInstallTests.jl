#= installLibrary from any git repository (local repositories here, as a URL), and the libraries a library uses,
   resolved before it loads: a missing one stops the load by name; another version of the same major version, or
   the bundled MSL for the MSL's packages, stands in. =#
@testset "library install and dependencies" begin
  local git(dir, args...) = run(pipeline(`git -C $dir -c user.name=t -c user.email=t@t $args`; stdout = devnull, stderr = devnull))
  local repo(files, tags) = begin
    local d = mktempdir()
    for (path, text) in files
      mkpath(dirname(joinpath(d, path)))
      write(joinpath(d, path), text)
    end
    git(d, "init", "-q"); git(d, "add", "."); git(d, "commit", "-q", "-m", "release")
    foreach(t -> git(d, "tag", t), tags)
    d
  end
  local lib(name, version, uses = "") = """
    package $name
      model M
        Real x(start = 0.0, fixed = true);
      equation
        der(x) = 1.0;
      end M;
      annotation(version = "$version"$(isempty(uses) ? "" : ", uses($uses)"));
    end $name;
    """
  local dest = mktempdir()
  #= the package in its folder, tag v<version> =#
  local r1 = repo(["TestLib/package.mo" => lib("TestLib", "1.0.0", "LibB(version = \"1.0.0\")"), "README.md" => "x"],
                  ["v1.0.0", "v1.1.0"])
  local path = OMFrontend.installLibrary("TestLib"; version = "1.0.0", url = r1, dest = dest)
  @test path == joinpath(dest, "TestLib 1.0.0") && isfile(joinpath(path, "package.mo"))
  @test OMFrontend.installLibrary("TestLib"; version = "1.0.0", url = r1, dest = dest) == path
  #= the package at the repository's root, tag <version> =#
  local r2 = repo(["package.mo" => lib("RootLib", "2.0.0")], ["2.0.0"])
  @test isfile(joinpath(OMFrontend.installLibrary("RootLib"; version = "2.0.0", url = r2, dest = dest), "package.mo"))
  #= checked: another package's name installs nothing, a tag that does not exist fails, a version that the package
     does not declare warns =#
  @test_throws ErrorException OMFrontend.installLibrary("Other"; version = "1.0.0", url = r1, dest = dest)
  @test !isdir(joinpath(dest, "Other 1.0.0"))
  @test_throws ErrorException OMFrontend.installLibrary("TestLib"; version = "9.9.9", url = r1, dest = dest)
  @test_logs (:warn, r"declares version 1.0.0") match_mode = :any OMFrontend.installLibrary("TestLib"; version = "1.1.0", url = r1, dest = dest)
  @test_throws ErrorException OMFrontend.installLibrary("NotRegistered"; version = "1.0.0")
  #= the version annotation, not the uses' or a conversion's =#
  local pkg = joinpath(mktempdir(), "package.mo")
  write(pkg, "package P annotation(uses(Q(version = \"3.0.0\")), conversion(from(version = \"0.9\", script = \"s\")), version = \"1.2.3\"); end P;")
  @test OMFrontend._packageVersion(pkg) == "1.2.3" && OMFrontend._packageName(pkg) == "P"
  #= a used library that is not installed: the load stops before parsing, naming it =#
  local msg = try
    OMFrontend.loadInstalledLibrary("TestLib"; version = "1.0.0", installDir = dest, forceReload = true)
    ""
  catch e
    sprint(showerror, e)
  end
  @test occursin("LibB 1.0.0", msg) && occursin("not installed", msg)
  @test !haskey(OMFrontend.LIBRARY_CACHE, "TestLib_1_0_0")
  #= another version of the same major version stands in =#
  mkpath(joinpath(dest, "LibB 1.2.0"))
  write(joinpath(dest, "LibB 1.2.0", "package.mo"), lib("LibB", "1.2.0"))
  local key = OMFrontend.loadInstalledLibrary("TestLib"; version = "1.0.0", installDir = dest, forceReload = true)
  @test OMFrontend.LIBRARY_DEPENDENCIES[key] == ["LibB_1_2_0"]
  #= the MSL's packages from the bundled MSL of the same major version (uses 4.0.0, 4.1.0 bundled) =#
  mkpath(joinpath(dest, "UsesMSL 1.0.0"))
  write(joinpath(dest, "UsesMSL 1.0.0", "package.mo"),
        lib("UsesMSL", "1.0.0", "Modelica(version = \"4.0.0\"), ModelicaServices(version = \"4.0.0\")"))
  local mslKey = OMFrontend.loadInstalledLibrary("UsesMSL"; installDir = dest)
  @test OMFrontend.LIBRARY_DEPENDENCIES[mslKey] == ["MSL_4_1_0"]
  #= a resource of a library loaded from any directory: from the directory it was loaded from (LIBRARY_ROOTS) =#
  mkpath(joinpath(dest, "ResLib 1.0.0", "Resources"))
  write(joinpath(dest, "ResLib 1.0.0", "package.mo"), lib("ResLib", "1.0.0"))
  write(joinpath(dest, "ResLib 1.0.0", "Resources", "data.txt"), "1 2 3")
  OMFrontend.loadInstalledLibrary("ResLib"; installDir = dest)
  @test OMFrontend.Frontend.resolveModelicaUri("modelica://ResLib/Resources/data.txt") ==
        joinpath(dest, "ResLib 1.0.0", "Resources", "data.txt")
  #= ...and of a library loaded as a package directory, also when it comes from the disk cache =#
  local pkgDir = joinpath(mktempdir(), "DirLib")
  mkpath(joinpath(pkgDir, "Resources"))
  write(joinpath(pkgDir, "package.mo"), "package DirLib\nend DirLib;\n")
  write(joinpath(pkgDir, "Resources", "data.txt"), "1 2 3")
  for _ in 1:2
    delete!(OMFrontend.LIBRARY_ROOTS, "DirLib")
    OMFrontend.loadPackageDirectory(pkgDir)
    @test OMFrontend.Frontend.resolveModelicaUri("modelica://DirLib/Resources/data.txt") ==
          joinpath(pkgDir, "Resources", "data.txt")
  end
  #= the default directories: OM.jl's first (installLibrary's), then OpenModelica's =#
  @test OMFrontend.libraryDirectories() == [OMFrontend.omjlLibraryDir(), OMFrontend.openModelicaLibraryDir()]
  @test endswith(OMFrontend.omjlLibraryDir(), joinpath("OMJL", "libraries"))
  @test endswith(OMFrontend.openModelicaLibraryDir(), joinpath(".openmodelica", "libraries"))
end
