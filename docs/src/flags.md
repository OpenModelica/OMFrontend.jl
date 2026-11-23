```@meta
CurrentModule = OMFrontend
```

# Flags

[`setFlags`](@ref) sets flags of the frontend by name, for the Julia session:

```julia
OMFrontend.setFlags(execstat = true)                       # a debug flag: true or false
OMFrontend.setFlags(evalLoopLimit = 10^6, std = "3.6")     # options: a value of their type
OMFrontend.setFlags(allowNonStandardModelica = ["reinitInAlgorithms"])
```

An unknown name or a value of the wrong type raises an `ArgumentError`, and then no flag changes. The names are
omc's (`-d=execstat`, `--evalLoopLimit=...`); only these flags exist in OMFrontend. The tests check one model per
flag (`test/publicApiTests.jl`) and that this page lists each one.

## Debug flags

| Flag | Default | Effect |
|:--|:--|:--|
| `evaluateAllParameters` | `false` | Evaluates all parameters, not only structural ones: `x = k * time` becomes `x = 2.0 * time`. |
| `nfEvalConstArgFuncs` | `true` | Evaluates functions called with constant arguments: `f(2)` becomes its value. |
| `inlineFunctions` | `true` | Inlines functions with `annotation(Inline = true)`. |
| `nfAPI` | `false` | The instantiation for graphical editors (omc's API): array bindings stay bindings, a Boolean is accepted as a Real, `DynamicSelect(static, dynamic)` becomes `static`. |
| `nfAPIDynamicSelect` | `false` | With `nfAPI`: keeps `DynamicSelect(static, dynamic)`. |
| `execstat` | `false` | Prints the time and the allocations of each phase: `Execstat <phase> -> time: ...` and `<phase>: <s> seconds (...)`. |
| `failtrace` | `false` | Prints the function calls that could not be evaluated: `- NFSimplifyExp.simplifyCall failed to evaluate h(2.0)`. |
| `cgraph` | `false` | Prints the connection graph of overconstrained connectors: `- addConnection(a.r, b.r)`, the roots, the broken connections. |
| `nfDumpFlat` | `false` | Writes the flat model after each phase to `<temp>/OMJL/<pid>_<time>/frontend/flat/<model>_<phase>.mo` (also `enableDumpDebug`). |

Each translation sets `nfScalarize`, `nfExpandOperations` and `nfExpandFuncArgs` from `instantiate`'s argument
`scalarize`, and `nfSeparateInstantiation` from `instantiateSCodeToFM`'s argument `separateInstantiation`;
`setFlags` refuses them.

## Options

| Flag | Default | Effect |
|:--|:--|:--|
| `std` | `"latest"` | The Modelica version: `"1.x"`, `"2.x"`, `"3.0"` to `"3.6"`, `"latest"`, `"experimental"`. `"experimental"` allows `promote`. |
| `flowThreshold` | `1.0e-7` | The smallest flow rate in the mixing equations of `inStream`: `OMCPositiveMax(-m, flowThreshold)`. |
| `evalLoopLimit` | `100000` | The most loop iterations in the evaluation of a function call; beyond it the call stays in the model. |
| `evalRecursionLimit` | `256` | The deepest recursion in the evaluation of a function call; beyond it the call stays in the model. |
| `allowNonStandardModelica` | `[]` | Non-standard Modelica to accept: `"nonStdEnumerationAsIntegers"`, `"nonStdTopLevelOuter"`, `"reinitInAlgorithms"`, `"implicitParameterStartAttribute"`, `"illegalConditionalContext"`. |
| `ignoreCommandLineOptionsAnnotation` | `false` | Ignores a class's `__OpenModelica_commandLineOptions` annotation (which sets options, such as `--allowNonStandardModelica=...`, for that class). |
| `loadMissingLibraries` | `true` | Loads the Modelica Standard Library when a model refers to `Modelica` without loading it. |

## Environment variables

Read when OMFrontend loads.

| Variable | Default | Effect |
|:--|:--|:--|
| `OMFRONTEND_PARALLEL_INST` | `true` | Instantiates sibling components in parallel when Julia has threads. |
| `OMFRONTEND_CACHE_INST` | `true` | Instantiates a class once for its identical scalar components, within one translation. |
| `OMFRONTEND_NO_PRECOMPILE_WORKLOAD` | unset | Set: precompilation runs no models (OM.jl sets it; its own workload runs the frontend). |
