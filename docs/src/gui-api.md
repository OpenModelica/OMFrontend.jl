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
SourceSpan
TextPatch
ValidationResult
OperationResult
SaveResult
DiagramNode
DiagramConnection
DiagramModel
ModelSession
```

## Functions

```@docs
setExecutionDelegates!
loadModel
validateModel
getDiagram
updateComponentPlacement
createConnection
updateConnectionAnnotation
deleteConnection
saveModel
compileModel
simulateModel
exportFlatModelica
```

## Index

```@index
Pages = ["gui-api.md"]
```
