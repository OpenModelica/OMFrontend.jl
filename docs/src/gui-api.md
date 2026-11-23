```@meta
CurrentModule = OMFrontend.GUI_API
```

# GUI API (experimental)

`OMFrontend.GUI_API` is an API for graphical model editors: load a model, read its diagram (components, placements,
connections), edit placements and connections as text patches of the source, save, and compile or simulate through
delegates. It is experimental: its names may change in a minor release, and its tests run only on request
(`OMFRONTEND_TEST_GUI_API=1`).

## Types

```@docs
OMFrontend.GUI_API.SourceSpan
OMFrontend.GUI_API.TextPatch
OMFrontend.GUI_API.ValidationResult
OMFrontend.GUI_API.OperationResult
OMFrontend.GUI_API.SaveResult
OMFrontend.GUI_API.DiagramNode
OMFrontend.GUI_API.DiagramConnection
OMFrontend.GUI_API.DiagramModel
OMFrontend.GUI_API.ModelSession
```

## Functions

```@docs
OMFrontend.GUI_API.setExecutionDelegates!
OMFrontend.GUI_API.loadModel
OMFrontend.GUI_API.validateModel
OMFrontend.GUI_API.getDiagram
OMFrontend.GUI_API.updateComponentPlacement
OMFrontend.GUI_API.createConnection
OMFrontend.GUI_API.updateConnectionAnnotation
OMFrontend.GUI_API.deleteConnection
OMFrontend.GUI_API.saveModel
OMFrontend.GUI_API.compileModel
OMFrontend.GUI_API.simulateModel
OMFrontend.GUI_API.exportFlatModelica
```

## Index

```@index
Pages = ["gui-api.md"]
```
