```@meta
CurrentModule = OMFrontend
```

# API reference

The reference below lists the documented API intended for users and tooling.

## Public API

Translate Modelica to flat Modelica with named arguments. These functions print only warnings while they work;
a model that cannot be translated raises a short `ModelicaError` with the model's messages. `debug!` is the
developer mode with full stack traces.

```@docs
OMFrontend.instantiate
OMFrontend.flatModelica
OMFrontend.classNames
OMFrontend.variables
OMFrontend.FlatModelica
OMFrontend.ModelicaError
OMFrontend.debug!
```

## Pipeline API (developers)

The steps `instantiate` runs, the library cache, and the older entry points.

```@docs
OMFrontend.parseFile
OMFrontend.translateToSCode
OMFrontend.instantiateSCodeToFM
OMFrontend.flattenModel
OMFrontend.flattenModelWithMSL
OMFrontend.flattenModelWithLibraries
OMFrontend.loadMSL
OMFrontend.loadLibrary
OMFrontend.loadPackageDirectory
OMFrontend.toFlatModelica
OMFrontend.toString
OMFrontend.exportSCodeRepresentationToFile
OMFrontend.enableDumpDebug
OMFrontend.disableDumpDebug
OMFrontend.removeQuotesFromFlatModelica
OMFrontend.julia_main
```

## GUI API

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
Pages = ["api.md"]
```
