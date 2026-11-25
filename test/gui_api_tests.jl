const GUI_API = OMFrontend.GUI_API

@testset "GUI_API editing" begin
  sourceModel = joinpath(@__DIR__, "Models", "GUIAPIEditing.mo")

  mktempdir() do tmpDir
    workModel = joinpath(tmpDir, "GUIAPIEditing.mo")
    cp(sourceModel, workModel)

    session = GUI_API.loadModel(workModel)
    diagram = GUI_API.getDiagram(session, "GUIAPIEditing.Example")

    @test diagram.coordinateSystem["preserveAspectRatio"] == false
    @test length(diagram.nodes) == 2
    @test length(diagram.connections) == 1
    @test diagram.nodes[1].componentPath == "GUIAPIEditing.Example.src"
    @test diagram.nodes[1].origin == (-60.0, 0.0)
    @test diagram.connections[1].points == [(-50.0, 0.0), (50.0, 0.0)]

    placementResult =
      GUI_API.updateComponentPlacement(session,
                                       "GUIAPIEditing.Example.src",
                                       Dict(:extent => ((-30.0, 0.0), (-10.0, 20.0)),
                                            :rotation => 90.0))
    @test placementResult.ok

    lineResult =
      GUI_API.updateConnectionAnnotation(session,
                                         diagram.connections[1].id,
                                         Dict(:points => [(-20.0, 0.0), (0.0, 20.0), (20.0, 0.0)]))
    @test lineResult.ok

    updatedDiagram = GUI_API.getDiagram(session, "GUIAPIEditing.Example")
    @test updatedDiagram.nodes[1].origin == (-20.0, 10.0)
    @test updatedDiagram.nodes[1].rotation == 90.0
    @test updatedDiagram.connections[1].points == [(-20.0, 0.0), (0.0, 20.0), (20.0, 0.0)]

    deleteResult = GUI_API.deleteConnection(session, updatedDiagram.connections[1].id)
    @test deleteResult.ok
    @test isempty(GUI_API.getDiagram(session, "GUIAPIEditing.Example").connections)

    createResult =
      GUI_API.createConnection(session,
                               "src.p",
                               "load.n";
                               classPath = "GUIAPIEditing.Example",
                               linePatch = Dict(:points => [(-10.0, 0.0), (10.0, 0.0)]))
    @test createResult.ok
    recreatedDiagram = GUI_API.getDiagram(session, "GUIAPIEditing.Example")
    @test length(recreatedDiagram.connections) == 1
    @test recreatedDiagram.connections[1].points == [(-10.0, 0.0), (10.0, 0.0)]

    saved = GUI_API.saveModel(session)
    @test saved.path == workModel
    reloaded = GUI_API.loadModel(workModel)
    reloadedDiagram = GUI_API.getDiagram(reloaded, "GUIAPIEditing.Example")
    @test reloadedDiagram.nodes[1].rotation == 90.0
    @test length(reloadedDiagram.connections) == 1

    #= the delegates get a temporary copy of the source, removed when they return: check it while they run =#
    compileCalls = Tuple{String, Bool}[]
    GUI_API.setExecutionDelegates!(
      compileModel = (classPath, modelFile; kwargs...) -> begin
        push!(compileCalls, (classPath, isfile(modelFile) && read(modelFile, String) == session.sourceText))
        return :compiled
      end,
      exportFlatModelica = (classPath, modelFile; kwargs...) -> begin
        push!(compileCalls, (classPath, isfile(modelFile) && read(modelFile, String) == session.sourceText))
        return "flat-modelica"
      end,
    )

    @test GUI_API.compileModel(session, "GUIAPIEditing.Example") == :compiled
    @test GUI_API.exportFlatModelica(session, "GUIAPIEditing.Example") == "flat-modelica"
    @test length(compileCalls) == 2
    @test all(call -> call[1] == "GUIAPIEditing.Example", compileCalls)
    @test all(call -> call[2], compileCalls)
  end
end
