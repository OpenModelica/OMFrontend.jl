#= GUI_API driven as a GUI would drive it (a mock GUI): load a model, read its diagram, move a component, create,
   restyle and delete connections, save, and hand the model to compile/simulate/export callbacks.
   Author: John Tinnerholm =#
import OMFrontend.GUI_API as G

const GUI_MODEL = """
connector Pin
  Real v;
  flow Real i;
end Pin;

model Resistor
  parameter Real R = 1;
  Pin p annotation(Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
  Pin n annotation(Placement(transformation(extent = {{90, -10}, {110, 10}})));
equation
  p.v - n.v = R * p.i;
  p.i + n.i = 0;
end Resistor;

model Ground
  Pin p;
equation
  p.v = 0;
end Ground;

model Circuit
  Resistor r1(R = 2) annotation(Placement(transformation(origin = {-40, 0}, extent = {{-10, -10}, {10, 10}})));
  Resistor r2 annotation(Placement(transformation(origin = {40, 0}, extent = {{-10, -10}, {10, 10}}, rotation = 90)));
  Ground g annotation(Placement(transformation(origin = {0, -60}, extent = {{-10, -10}, {10, 10}})));
equation
  connect(r1.n, r2.p) annotation(Line(points = {{-30, 0}, {30, 0}}, color = {0, 0, 255}));
  connect(r2.n, g.p);
  annotation(Diagram(coordinateSystem(extent = {{-100, -100}, {100, 100}})));
end Circuit;
"""

"""The model file written to a fresh temporary directory."""
function _guiModelFile()::String
  local path::String = joinpath(mktempdir(), "Circuit.mo")
  write(path, GUI_MODEL)
  return path
end

"""The diagram node of `name` (the last part of its path)."""
function _node(d::G.DiagramModel, name::String)::G.DiagramNode
  return only(filter(n -> endswith(n.componentPath, name), d.nodes))
end

@testset "GUI_API through a mock GUI" begin
  local path::String = _guiModelFile()
  local s::G.ModelSession = G.loadModel(path)

  @testset "load, validate, read the diagram" begin
    @test G.validateModel(s, "Circuit").ok
    @test !G.validateModel(s, "NoSuchClass").ok
    local d::G.DiagramModel = G.getDiagram(s, "Circuit")
    @test length(d.nodes) == 3
    @test length(d.connections) == 2
    @test _node(d, "r1").origin == (-40.0, 0.0)
    @test _node(d, "r2").rotation == 90.0
    @test _node(d, "r1").typePath == "Resistor"
    local c1::G.DiagramConnection = d.connections[1]
    @test (c1.fromConnector, c1.toConnector) == ("r1.n", "r2.p")
    @test c1.points == [(-30.0, 0.0), (30.0, 0.0)]
    @test c1.color == (0, 0, 255)
    @test d.connections[2].color === nothing
    @test haskey(d.coordinateSystem, "extent")
    @test G.getDiagram(s, "Circuit"; view = :Icon).view == :Icon
    @test_throws ErrorException G.getDiagram(s, "NoSuchClass")
  end

  @testset "move a component" begin
    local r::G.OperationResult = G.updateComponentPlacement(s, "r1", Dict("origin" => (-50.0, 20.0), "rotation" => 180.0))
    @test r.ok
    local n::G.DiagramNode = _node(G.getDiagram(s, "Circuit"), "r1")
    @test n.origin == (-50.0, 20.0)
    @test n.rotation == 180.0
    @test occursin("r1(R = 2)", s.sourceText)
  end

  @testset "create, restyle and delete a connection" begin
    local r::G.OperationResult = G.createConnection(s, "r1.p", "g.p"; classPath = "Circuit")
    @test r.ok && r.resourceId !== nothing
    @test length(G.getDiagram(s, "Circuit").connections) == 3
    @test occursin("connect(r1.p, g.p)", s.sourceText)
    local u::G.OperationResult = G.updateConnectionAnnotation(s, r.resourceId, Dict("color" => (255, 0, 0)))
    @test u.ok
    local c::G.DiagramConnection = only(filter(c -> c.id == r.resourceId, G.getDiagram(s, "Circuit").connections))
    @test c.color == (255, 0, 0)
    @test G.deleteConnection(s, r.resourceId).ok
    @test !occursin("connect(r1.p, g.p)", s.sourceText)
    @test length(G.getDiagram(s, "Circuit").connections) == 2
    @test !G.deleteConnection(s, "no-such-id").ok
    @test !G.updateConnectionAnnotation(s, "no-such-id", Dict("color" => (1, 2, 3))).ok
  end

  @testset "save and load again" begin
    local target::String = joinpath(dirname(path), "Saved.mo")
    local saved::G.SaveResult = G.saveModel(s; targetPath = target)
    @test saved.path == target && saved.bytesWritten == sizeof(read(target, String))
    local s2::G.ModelSession = G.loadModel(target)
    @test _node(G.getDiagram(s2, "Circuit"), "r1").origin == (-50.0, 20.0)
    @test read(path, String) == GUI_MODEL
  end

  @testset "compile, simulate and export through callbacks" begin
    local calls::Vector{Tuple{Symbol, String, String}} = Tuple{Symbol, String, String}[]
    G.setExecutionDelegates!(
      compileModel = (cls, file; kw...) -> (push!(calls, (:compile, cls, read(file, String))); :compiled),
      simulateModel = (cls, file; kw...) -> (push!(calls, (:simulate, cls, read(file, String))); get(kw, :stopTime, 0.0)),
      exportFlatModelica = (cls, file; kw...) -> string(OMFrontend.instantiate(cls; file = file)))
    @test G.compileModel(s, "Circuit") == :compiled
    @test G.simulateModel(s, "Circuit"; stopTime = 2.0) == 2.0
    @test [c[1] for c in calls] == [:compile, :simulate]
    @test all(c -> c[3] == s.sourceText, calls)
    @test occursin("r1.R", G.exportFlatModelica(s, "Circuit"))
  end
end
