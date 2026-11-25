# Tests of the command line interface (src/API/cli.jl): every command, its help, its options and
# its usage errors. The CLI writes to the file descriptors 1 and 2, so the output is taken from
# files that stand in for them.
# Author: John Tinnerholm

"""
    runCLI(args)::Tuple{Int64, String, String}

The exit code, standard output and standard error of the CLI with `args`.
"""
function runCLI(args::Vector{String})::Tuple{Int64, String, String}
  local outPath::String = tempname()
  local errPath::String = tempname()
  local code::Ref{Cint} = Ref{Cint}(-1)
  open(outPath, "w") do out::IOStream
    open(errPath, "w") do err::IOStream
      redirect_stdio(stdout = out, stderr = err) do
        code[] = OMFrontend._runCLI(args)
      end
    end
  end
  local result::Tuple{Int64, String, String} = (Int64(code[]), read(outPath, String), read(errPath, String))
  rm(outPath); rm(errPath)
  return result
end

"""
    runMain(args)::Tuple{Int64, String}

The exit code and standard error of `julia_main` with `args` as the command line.
"""
function runMain(args::Vector{String})::Tuple{Int64, String}
  local saved::Vector{String} = copy(ARGS)
  local errPath::String = tempname()
  local code::Ref{Cint} = Ref{Cint}(-1)
  try
    empty!(ARGS); append!(ARGS, args)
    open(errPath, "w") do err::IOStream
      redirect_stdio(stdout = devnull, stderr = err) do
        code[] = OMFrontend.julia_main()
      end
    end
  finally
    empty!(ARGS); append!(ARGS, saved)
  end
  local text::String = read(errPath, String)
  rm(errPath)
  return (Int64(code[]), text)
end

@testset "CLI" begin
  local dir::String = mktempdir()
  local model::String = joinpath(dir, "Decay.mo")
  write(model, """
    model Decay
      parameter Real 'k' = 2;
      Real x[2](each start = 1);
    equation
      der(x) = -'k' * x;
    end Decay;
    """)

  @testset "help and version" begin
    for args::Vector{String} in (String[], ["-h"], ["--help"], ["help"], ["help", "help"], ["help", "version"])
      local (code::Int64, out::String, _) = runCLI(args)
      @test code == 0
      @test occursin("Usage: OMFrontend <command>", out)
    end
    for (command::String, usage::String) in (("flatten", "flatten <ModelName>"), ("parse", "parse <PATH>"), ("scode", "scode <PATH>"))
      @test occursin(usage, runCLI(["help", command])[2])
      @test occursin(usage, runCLI([command, "--help"])[2])
      @test occursin(usage, runCLI([command, "-h"])[2])
    end
    local (code::Int64, _, err::String) = runCLI(["help", "nope"])
    @test code == 2
    @test occursin("help: unknown command \"nope\"", err)
    for args::Vector{String} in (["version"], ["-V"], ["--version"])
      @test runCLI(args)[2] == "OMFrontend $(pkgversion(OMFrontend))\n"
    end
    @test runCLI(["nope"])[1] == 2
    @test occursin("Unknown command: nope", runCLI(["nope"])[3])
  end

  @testset "flatten" begin
    local (code::Int64, out::String, _) = runCLI(["flatten", "Decay", "--file", model])
    @test code == 0
    @test occursin("model Decay\n", out)
    @test occursin("der('x[1]') = (-k * 'x[1]');", out)
    @test occursin("model 'Decay'\n", runCLI(["flatten", "Decay", "--file", model, "--keep-quotes"])[2])
    @test occursin("der(x) = (-k * x);", runCLI(["flatten", "Decay", "--file", model, "--no-scalarize"])[2])
    local flatFile::String = joinpath(dir, "Decay.flat.mo")
    local (codeOut::Int64, outOut::String, errOut::String) = runCLI(["flatten", "Decay", "--file", model, "--out", flatFile])
    @test codeOut == 0 && isempty(outOut)
    @test occursin("Wrote flat Modelica to $flatFile", errOut)
    @test occursin("der('x[1]')", read(flatFile, String))
    @test runCLI(["flatten"])[1] == 2
    @test occursin("expected exactly one model name (got 2)", runCLI(["flatten", "A", "B"])[3])
    @test occursin("at least one of --file or --msl is required", runCLI(["flatten", "Decay"])[3])
    @test_throws ArgumentError("Unknown option: --nope") runCLI(["flatten", "Decay", "--nope"])
    @test_throws ArgumentError("Missing value for --file") runCLI(["flatten", "Decay", "--file"])
  end

  @testset "flatten a model of the Modelica Standard Library" begin
    local (code::Int64, out::String, _) =
      runCLI(["flatten", "Modelica.Electrical.Analog.Examples.CharacteristicIdealDiodes", "--msl", "MSL:4.1.0"])
    @test code == 0
    #= without --keep-quotes the dots of the names are underscores =#
    @test occursin("model Modelica_Electrical_Analog_Examples_CharacteristicIdealDiodes\n", out)
  end

  @testset "parse" begin
    local (code::Int64, out::String, _) = runCLI(["parse", model])
    @test code == 0
    @test out == "Parsed $model successfully (grammar = 1).\n"
    local dump::String = joinpath(dir, "Decay.absyn")
    local (_, _, err::String) = runCLI(["parse", model, "--grammar", "1", "--out", dump])
    @test occursin("Dump written to $dump.", err)
    @test occursin("Decay", read(dump, String))
    @test occursin("expected exactly one path (got 0)", runCLI(["parse"])[3])
  end

  @testset "scode" begin
    local (code::Int64, out::String, _) = runCLI(["scode", model])
    @test code == 0
    @test occursin("Decay", out)
    local dump::String = joinpath(dir, "Decay.scode")
    @test occursin("Wrote SCode to $dump", runCLI(["scode", model, "--out", dump])[3])
    @test occursin("Decay", read(dump, String))
    @test runCLI(["scode", model, model])[1] == 2
  end

  @testset "julia_main: the exit codes of a binary" begin
    @test runMain(["version"])[1] == 0
    local (code::Int64, err::String) = runMain(["flatten", "Decay", "--nope"])
    @test code == 1
    @test occursin("OMFrontend CLI error", err)
  end
end
