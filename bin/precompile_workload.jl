#=
  Driven by PackageCompiler at sysimage build time.

  Loading OMFrontend already triggers a substantial workload via __init__
  (parses NFModelicaBuiltin, instantiates HelloWorld) and via the
  PrecompileTools @compile_workload registered in src/Precompilation/precompilation.jl.
  We additionally exercise the public entry points so they are traced
  with concrete input types and baked into the resulting sysimage.
=#

using OMFrontend
import OpenModelicaParser

let
    pkgRoot     = dirname(dirname(realpath(Base.find_package("OMFrontend"))))
    helloWorld  = joinpath(pkgRoot, "test", "Models", "HelloWorld.mo")

    # Anchor the OpenModelicaParser ccall-helper methods. The ccall library-name
    # expression `ccall((:f, ensure_installed_lib_path()), ...)` does not
    # always propagate `ensure_installed_lib_path` through reachability
    # analysis (juliac --trim=unsafe drops the no-arg method despite the
    # call site being live). Calling them as plain Julia functions here
    # forces the specializations into the compiled image.
    OpenModelicaParser.ensure_installed_lib_path()
    contents = read(helloWorld, String)
    OpenModelicaParser.parseString(contents, helloWorld, Int64(1), Int64(1000))

    program = OpenModelicaParser.parseFile(helloWorld, Int64(1), Int64(1000))

    # Drive last_parse_error_message via a deliberate parse failure so the
    # OMParser_lastErrorMessage / OMParser_clearLastErrorMessage ccalls are
    # also seen.
    try
        OpenModelicaParser.parseString("model NotValid invalid syntax;", "<bad>",
                             Int64(1), Int64(1000))
    catch e
        e isa OpenModelicaParser.ParseError || rethrow()
    end

    scode = OMFrontend.translateToSCode(program)
    OMFrontend.instantiateSCodeToFM("HelloWorld", scode)
end
