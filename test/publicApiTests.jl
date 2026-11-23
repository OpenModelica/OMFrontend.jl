#= The public API (instantiate, flatModelica, classNames, variables, debug!): named arguments, quiet by default,
   short errors (ModelicaError). =#

const DECAY_MODEL = """
model Decay
  parameter Real k = 2;
  Real x(start = 1, fixed = true);
equation
  der(x) = -k * x;
end Decay;
"""

"""What `f()` raises, or `nothing`; with stdout and stderr captured, returned as `(raised, printed)`."""
function _raisedAndPrinted(f::F)::Tuple{Any, String} where {F <: Function}
  local raised::Any = nothing
  local printed::String = mktemp() do path::String, io::IOStream
    redirect_stdio(stdout = io, stderr = io) do
      try
        f()
      catch e
        raised = e
      end
    end
    close(io)
    read(path, String)
  end
  return (raised, printed)
end

@testset "Public API" begin
  @testset "instantiate: a string, a file, a class of a library" begin
    local fm::OMFrontend.FlatModelica = OMFrontend.instantiate(string = DECAY_MODEL)
    @test fm.name == "Decay"
    @test OMFrontend.variables(fm) == ["k", "x"]
    local text::String = string(fm)
    @test occursin("der(x) = ", text)
    @test !occursin("/*Equality*/", text)
    @test text == OMFrontend.flatModelica("Decay"; string = DECAY_MODEL)
    @test sprint(show, MIME"text/plain"(), fm) == text
    @test repr(fm) == "FlatModelica(\"Decay\")"
    mktempdir() do dir::String
      local file::String = joinpath(dir, "Decay.mo")
      write(file, DECAY_MODEL)
      @test string(OMFrontend.instantiate(file = file)) == text
      @test OMFrontend.classNames(file = file) == ["Decay"]
      local lib::String = joinpath(dir, "TinyLib.mo")
      write(lib, "package TinyLib model Gain parameter Real g = 3; Real y = g * time; end Gain; end TinyLib;")
      @test OMFrontend.variables(OMFrontend.instantiate("TinyLib.Gain"; libraries = [lib])) == ["g", "y"]
      @test OMFrontend.classNames("TinyLib"; libraries = [lib]) == ["Gain"]
    end
    local nested::String = "package P model A end A; model C end C; end P; model B end B;"
    @test OMFrontend.classNames(string = nested) == ["P", "B"]
    @test OMFrontend.classNames("P"; string = nested) == ["A", "C"]
    #= The Modelica Standard Library comes without naming it. =#
    @test "PID_Controller" in OMFrontend.classNames("Modelica.Blocks.Examples")
  end

  @testset "Errors: short, with the model's messages, nothing printed" begin
    local (syntax, printed) = _raisedAndPrinted(() -> OMFrontend.instantiate(string = "model M Real x equation x = 1; end M;"))
    @test syntax isa OMFrontend.ModelicaError
    @test startswith(only(syntax.messages), "<string>:1:16: Expected ';'")
    @test isempty(printed)
    local (typing, printed2) = _raisedAndPrinted(() -> OMFrontend.instantiate(string = "model M Real x; equation x = true; end M;"))
    @test typing isa OMFrontend.ModelicaError
    @test typing.messages == ["<string>:1:26: Error: Type mismatch in equation x = true of type Real = Boolean."]
    @test startswith(sprint(showerror, typing), "ModelicaError: <string>:1:26: Error: Type mismatch")
    @test isempty(printed2)
    #= Raised outside a catch: no internal exception under it in the REPL. =#
    local stacked::Int = try
      OMFrontend.instantiate(string = "model M Real x; equation x = true; end M;")
      0
    catch
      length(current_exceptions())
    end
    @test stacked == 1
    #= An unknown name is the model's error, as omc reports it (it was an internal lookup warning). =#
    local unknown::Any = try
      OMFrontend.instantiate(string = replace(DECAY_MODEL, "-k * x" => "-k * y"))
    catch e
      e
    end
    @test unknown isa OMFrontend.ModelicaError
    @test unknown.messages == ["<string>:5:3: Error: Variable y not found in scope Decay."]
    @test_throws OMFrontend.ModelicaError OMFrontend.instantiate("N"; string = "model M end M;")
    @test_throws ArgumentError OMFrontend.instantiate(string = "model A end A; model B end B;")
    @test_throws ArgumentError OMFrontend.instantiate(file = "no/such/file.mo")
    @test_throws ArgumentError OMFrontend.instantiate("A"; file = "A.mo", string = "model A end A;")
  end

  @testset "debug!: the internal failure, the messages on stderr" begin
    @test OMFrontend.debug!(true)
    try
      local (raised, printed) = _raisedAndPrinted(() -> OMFrontend.instantiate(string = "model M Real x; equation x = true; end M;"))
      @test !(raised isa OMFrontend.ModelicaError)
      @test occursin("Type mismatch in equation x = true", printed)
    finally
      OMFrontend.debug!(false)
    end
    @test !OMFrontend.DEBUG[]
  end
end
