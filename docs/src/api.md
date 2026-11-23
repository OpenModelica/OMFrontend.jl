```@meta
CurrentModule = OMFrontend
```

# API reference

The functions for users come first, the developer functions after them. Both are `public` (Julia's REPL help marks
other names as internal). `OMFrontend.USER_API` and `OMFrontend.DEVELOPER_API` list them; the tests check that each
name is in its section below. The flags have their own page, [Flags](@ref), and the API for graphical editors its
own, [GUI API (experimental)](@ref).

## Public API

Translate Modelica to flat Modelica with named arguments, check a model, read a class. These functions print only
warnings while they work; a model that cannot be translated raises a short `ModelicaError` with the model's
messages. `debug!` is the developer mode with full stack traces.

```@docs
OMFrontend.instantiate
OMFrontend.flatModelica
OMFrontend.check
OMFrontend.classNames
OMFrontend.source
OMFrontend.description
OMFrontend.documentation
OMFrontend.variables
OMFrontend.parameters
OMFrontend.exportJSON
OMFrontend.componentGraphics
OMFrontend.installLibrary
OMFrontend.libraries
OMFrontend.setFlags
OMFrontend.FlatModelica
OMFrontend.CheckResult
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
OMFrontend.loadBundledMSL
OMFrontend.loadLibrary
OMFrontend.loadPackageDirectory
OMFrontend.loadInstalledLibrary
OMFrontend.toFlatModelica
OMFrontend.toString
OMFrontend.exportSCodeRepresentationToFile
OMFrontend.enableDumpDebug
OMFrontend.disableDumpDebug
OMFrontend.removeQuotesFromFlatModelica
OMFrontend.julia_main
```

## Index

```@index
Pages = ["api.md"]
```
