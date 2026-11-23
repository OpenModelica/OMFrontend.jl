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

"""
The flat model of class `M` in `model`, or its error messages, with `flags` set (`setFlags`); the flags are restored
after.
"""
function _flatWith(model::String; flags...)::String
  local saved::OMFrontend.Frontend.Flags.Flag = OMFrontend.Frontend.FlagsUtil.backupFlags()
  try
    OMFrontend.setFlags(; flags...)
    return string(OMFrontend.instantiate("M"; string = model))
  catch e
    e isa OMFrontend.ModelicaError || rethrow()
    return join(e.messages, "\n")
  finally
    OMFrontend.Frontend.FlagsUtil.saveFlags(saved)
  end
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
    @test only(syntax.messages) == "<string>:1:16: Error: Expected ';' after the element but found 'equation'"
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

  @testset "check, parameters, modifiers, source, description, documentation" begin
    local documented::String = replace(DECAY_MODEL, "model Decay\n" => "model Decay \"Exponential decay\"\n",
      "end Decay;" => "  annotation(Documentation(info = \"<html>A \\\"decay\\\".</html>\"));\nend Decay;")
    #= omc's checkModel counts (equal to omc's on 18 MSL 4.1.0 examples, see the 3.1.0 report). =#
    local ok::OMFrontend.CheckResult = OMFrontend.check(string = DECAY_MODEL)
    @test (ok.ok, ok.equations, ok.variables) == (true, 1, 1)
    @test sprint(show, MIME"text/plain"(), ok) == "Check of Decay completed successfully.\nClass Decay has 1 equation(s) and 1 variable(s)."
    local pid::OMFrontend.CheckResult = OMFrontend.check("Modelica.Blocks.Examples.PID_Controller")
    @test (pid.equations, pid.variables) == (89, 89)
    local failed::OMFrontend.CheckResult = OMFrontend.check(string = "model M Real x; equation x = true; end M;")
    @test !failed.ok && length(failed.messages) == 1
    @test endswith(sprint(show, MIME"text/plain"(), failed), "Check of M failed with 1 error(s).")
    local fm::OMFrontend.FlatModelica = OMFrontend.instantiate(string = DECAY_MODEL)
    @test OMFrontend.parameters(fm) == ["k" => "2.0"]
    local modified::OMFrontend.FlatModelica = OMFrontend.instantiate(string = DECAY_MODEL, modifiers = ["k = 3", "x(start = 2)"])
    @test modified.name == "Decay" && OMFrontend.parameters(modified) == ["k" => "3.0"]
    @test occursin("start = 2.0", string(modified))
    local wrong::Any = try OMFrontend.instantiate(string = DECAY_MODEL, modifiers = ["kk = 3"]) catch e; e end
    @test wrong isa OMFrontend.ModelicaError && occursin("Modified element kk not found in class Decay", only(wrong.messages))
    @test OMFrontend.source("Decay"; string = documented) == strip(documented)
    @test OMFrontend.description("Decay"; string = documented) == "Exponential decay"
    @test OMFrontend.documentation("Decay"; string = documented) == "<html>A \"decay\".</html>"
    @test OMFrontend.description("Decay"; string = DECAY_MODEL) == "" == OMFrontend.documentation("Decay"; string = DECAY_MODEL)
    local pidSource::String = OMFrontend.source("Modelica.Blocks.Continuous.PID")
    @test startswith(pidSource, "block PID \"PID controller in additive description form\"\n") && endswith(pidSource, "end PID;")
    @test OMFrontend.description("Modelica.Blocks.Examples.PID_Controller") == "Demonstrates the usage of a Continuous.LimPID controller"
    @test startswith(OMFrontend.documentation("Modelica.Blocks.Examples.PID_Controller"), "<html>")
  end

  @testset "User and developer functions: public, each in its section of docs/src/api.md" begin
    local api::String = read(joinpath(@__DIR__, "..", "docs", "src", "api.md"), String)
    local sectionNames(title::String)::Vector{Symbol} = begin
      local section::String = split(split(api, "## " * title)[2], "\n## ")[1]
      local block::String = split(split(section, "```@docs")[2], "```")[1]
      Symbol[Symbol(replace(strip(l), "OMFrontend." => "")) for l in split(block, '\n') if !isempty(strip(l))]
    end
    @test Set(sectionNames("Public API")) == Set(OMFrontend.USER_API)
    @test Set(sectionNames("Pipeline API (developers)")) == Set(OMFrontend.DEVELOPER_API)
    @test all(n -> Base.ispublic(OMFrontend, n), (OMFrontend.USER_API..., OMFrontend.DEVELOPER_API...))
    @test !Base.ispublic(OMFrontend, :_instantiate)
  end

  @testset "Errors: one format, `file:line:column: Severity: text`, the source line under it" begin
    #= The last message of each model, as omc reports it. =#
    local cases::Vector{Pair{String, String}} = [
      "model M Real x equation x = 1; end M;" =>
        "<string>:1:16: Error: Expected ';' after the element but found 'equation'",
      "model M Real x; equation x = true; end M;" =>
        "<string>:1:26: Error: Type mismatch in equation x = true of type Real = Boolean.",
      "model M Real x; equation der(x) = -y; end M;" => "<string>:1:26: Error: Variable y not found in scope M.",
      "model M Foo f; end M;" => "<string>:1:9: Error: Class Foo not found in scope M.",
      "model A parameter Real k = 1; end A; model M A a(kk = 2); end M;" =>
        "<string>:1:50: Error: Modified element kk not found in class A.",
      "model M Real x[2] = {1, 2, 3}; end M;" =>
        "<string>:1:9: Error: Type mismatch in binding ‘x = {1, 2, 3}‘, expected array dimensions [2], got [3].",
      "model M Real x = sin(1, 2); end M;" =>
        "<string>:1:9: Error: No matching function found for sin(/*Integer*/ 1, /*Integer*/ 2).\nCandidates are:\n  sin(Real x) => Real",
      "model M Real x; equation if 1 then x = 1; else x = 2; end if; end M;" =>
        "<string>:1:26: Error: Type error in conditional '1'. Expected Boolean, got Integer.",
      "model M Real x; Real x; end M;" => "<string>:1:17: Error: An element with name x is already declared in this scope."]
    for (model, expected) in cases
      local e::Any = try OMFrontend.instantiate("M"; string = model) catch err; err end
      @test e isa OMFrontend.ModelicaError && e.messages[end] == expected
    end
    local typing::OMFrontend.ModelicaError = try
      OMFrontend.instantiate(string = "model M Real x; equation x = true; end M;")
    catch e
      e
    end
    @test sprint(showerror, typing) == "ModelicaError: <string>:1:26: Error: Type mismatch in equation x = true of type " *
                                       "Real = Boolean.\n  model M Real x; equation x = true; end M;\n                           ^"
    @test sprint(show, MIME"text/plain"(), OMFrontend.check(string = "model M Real x; equation x = true; end M;")) ==
          sprint(showerror, typing)[length("ModelicaError: ") + 1:end] * "\nCheck of M failed with 1 error(s)."
  end

  @testset "setFlags: each flag, on a small model" begin
    #= Debug flags. =#
    @test occursin("Real x = k * time", _flatWith("model M parameter Real k = 2; Real x = k * time; end M;"))
    @test occursin("Real x = 2.0 * time",
                   _flatWith("model M parameter Real k = 2; Real x = k * time; end M;"; evaluateAllParameters = true))
    local f::String = "function f input Real a; output Real b; algorithm b := a + 1; end f; model M Real y = f(2) * time; end M;"
    @test occursin("Real y = 3.0 * time", _flatWith(f))
    @test occursin("Real y = 'f'(2.0) * time", _flatWith(f; nfEvalConstArgFuncs = false))
    local g::String = "function g input Real a; output Real b; algorithm b := 2 * a; annotation(Inline = true); end g; " *
                      "model M Real y = g(time); end M;"
    @test occursin("Real y = 2.0 * time", _flatWith(g))
    @test occursin("Real y = 'g'(time)", _flatWith(g; inlineFunctions = false))
    @test occursin("Type mismatch in equation x = true", _flatWith("model M Real x; equation x = true; end M;"))
    @test occursin("x = 1.0;", _flatWith("model M Real x; equation x = true; end M;"; nfAPI = true))
    local dynamic::String = "model M Real x = DynamicSelect(1.0, time); end M;"
    @test occursin("Real x = 1.0;", _flatWith(dynamic; nfAPI = true))
    @test occursin("DynamicSelect(1.0, time)", _flatWith(dynamic; nfAPI = true, nfAPIDynamicSelect = true))
    local assertFails::String = "function h input Real a; output Real b; algorithm assert(a > 10, \"small\"); b := a; end h; " *
                                "model M Real y = h(2) * time; end M;"
    @test occursin("- NFSimplifyExp.simplifyCall failed to evaluate h(2.0)",
                   last(_raisedAndPrinted(() -> _flatWith(assertFails; failtrace = true))))
    local overconstrained::String = """
      record R Real x;
        function equalityConstraint input R a; input R b; output Real r[1]; algorithm r := {a.x - b.x}; end equalityConstraint;
      end R;
      connector C R r; flow Real f; end C;
      model M C a, b; equation Connections.root(a.r); connect(a, b); a.r.x = time; a.f = 1; end M;
      """
    @test occursin("- addConnection(a.r, b.r)\nRoots: a.r\n", last(_raisedAndPrinted(() -> _flatWith(overconstrained; cgraph = true))))
    local printed::String = last(_raisedAndPrinted(() -> _flatWith(replace(DECAY_MODEL, "Decay" => "M"); execstat = true)))
    @test occursin("Execstat Instantiation -> time: ", printed) && occursin("resolveConnections: ", printed)
    local dumps::String = joinpath(OMFrontend.Frontend.logDir(), "frontend", "flat")
    isdir(dumps) && rm(dumps; recursive = true)
    _flatWith(replace(DECAY_MODEL, "Decay" => "M"); nfDumpFlat = true)
    @test "M_afterFlatten.mo" in readdir(dumps)
    #= Options. =#
    local promote::String = "model M Real x[2, 1] = promote({time, 2 * time}, 2); end M;"
    @test occursin("requires the --std=experimental flag", _flatWith(promote))
    @test occursin("'x[2,1]' = 2.0 * time", _flatWith(promote; std = "experimental"))
    local stream::String = """
      connector P Real p; flow Real m; stream Real h; end P;
      model S P port; parameter Real h0; equation port.p = 1; port.h = h0; end S;
      model M S a(h0 = 1), b(h0 = 2), c(h0 = 3); Real hmix = inStream(a.port.h);
      equation connect(a.port, b.port); connect(a.port, c.port); a.port.m = time; b.port.m = 1 - time; end M;
      """
    @test occursin("OMCPositiveMax((-'b.port.m'), 1.0e-7)", _flatWith(stream))
    @test occursin("OMCPositiveMax((-'b.port.m'), 0.001)", _flatWith(stream; flowThreshold = 1e-3))
    local loop::String = "function s input Integer n; output Integer t = 0; algorithm for i in 1:n loop t := t + i; end for; " *
                         "end s; model M Real y = s(200) * time; end M;"
    @test occursin("Real y = 20100.0 * time", _flatWith(loop))
    @test occursin("Real y = 's'(200) * time", _flatWith(loop; evalLoopLimit = 100))
    local recursion::String = "function r input Integer n; output Integer t; algorithm t := if n <= 0 then 0 else r(n - 1) + 1; " *
                              "end r; model M Real y = r(50) * time; end M;"
    @test occursin("Real y = 50.0 * time", _flatWith(recursion))
    @test occursin("Real y = 'r'(50) * time", _flatWith(recursion; evalRecursionLimit = 10))
    local reinit::String = "model M Real x(start = 1); equation der(x) = -x; algorithm when x < 0.5 then reinit(x, 1); end when; end M;"
    @test occursin("Operator reinit may not be used in an algorithm section", _flatWith(reinit))
    @test occursin("reinit(x, 1.0);", _flatWith(reinit; allowNonStandardModelica = ["reinitInAlgorithms"]))
    local annotated::String = replace(reinit, "end M;" =>
      "annotation(__OpenModelica_commandLineOptions = \"--allowNonStandardModelica=reinitInAlgorithms\"); end M;")
    @test occursin("reinit(x, 1.0);", _flatWith(annotated))
    @test occursin("Operator reinit may not be used", _flatWith(annotated; ignoreCommandLineOptionsAnnotation = true))
    local piModel::String = "model M Real x = Modelica.Constants.pi * time; end M;"
    @test occursin("Real x = 3.141592653589793 * time", _flatWith(piModel))
    @test occursin("Variable Modelica.Constants.pi not found in scope M", _flatWith(piModel; loadMissingLibraries = false))
    #= Wrong names and values change no flag. =#
    @test_throws ArgumentError OMFrontend.setFlags(execstat = true, foo = 1)
    @test !OMFrontend.Frontend.Flags.isSet(OMFrontend.Frontend.Flags.EXEC_STAT)
    @test_throws ArgumentError OMFrontend.setFlags(execstat = 1)
    @test_throws ArgumentError OMFrontend.setFlags(evalLoopLimit = 1.5)
    @test_throws ArgumentError OMFrontend.setFlags(std = "4.0")
    @test_throws ArgumentError OMFrontend.setFlags(allowNonStandardModelica = ["protectedAccess"])
    @test_throws ArgumentError OMFrontend.setFlags(nfScalarize = false)
    #= The documentation lists every flag (docs/src/flags.md). =#
    local page::String = read(joinpath(@__DIR__, "..", "docs", "src", "flags.md"), String)
    @test all(n -> occursin("| `$(n)` |", page),
              (OMFrontend._flagNames(OMFrontend._debugFlags())..., OMFrontend._flagNames(OMFrontend._options())...))
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
