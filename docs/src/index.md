```@meta
CurrentModule = OMFrontend
```

# OMFrontend.jl

`OMFrontend` is the Julia port of the OpenModelica frontend. It parses Modelica
source, lowers it through SCode, and produces the DAE / flat-Modelica
representation consumed by [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl)
and the wider [OM.jl](https://github.com/OpenModelica/OM.jl) toolchain.

## What this package does

* Parses Modelica via [OMParser.jl](https://github.com/OpenModelica/OMParser.jl)
  and produces an [Absyn](https://github.com/OpenModelica/Absyn.jl) tree.
* Translates the abstract syntax tree to
  [SCode](https://github.com/OpenModelica/SCode.jl).
* Instantiates SCode into the [DAE.jl](https://github.com/OpenModelica/DAE.jl)
  representation suitable for backend lowering.
* Optionally produces flat Modelica for inspection or downstream use.

## Installation

OMFrontend lives in the `OpenModelicaRegistry`. Add the registry once, then
install the package:

```julia
using Pkg
Pkg.Registry.add("General")
Pkg.Registry.add(Pkg.RegistrySpec(url = "https://github.com/OpenModelica/OpenModelicaRegistry.git"))
Pkg.add("OMFrontend")
```

## Quick example

```julia
using OMFrontend

p = OMFrontend.parseFile("MyModel.mo")
scode = OMFrontend.translateToSCode(p)
(dae, cache) = OMFrontend.instantiateSCodeToDAE("MyModel", scode)
```

See [Getting started](@ref) for a longer walk-through and the
[API reference](@ref) for the full list of public entry points.

## Project layout

| Path                 | Purpose                                        |
|----------------------|------------------------------------------------|
| `src/OMFrontend.jl`  | Top-level module: re-exports, precompilation.  |
| `src/NewFrontend/`   | Modern instantiation pipeline (NF*).           |
| `src/FrontendUtil/`  | Shared utilities used by the frontend passes.  |
| `src/Util/`          | Hash maps, AVL trees, flag handling, etc.      |
| `src/AbsynToSCode.jl`| Absyn -> SCode lowering.                       |
| `src/AbsynUtil.jl`   | Absyn helpers and traversals.                  |
| `src/SCodeUtil.jl`   | SCode helpers and traversals.                  |
| `src/main.jl`        | Convenience entry points (`parseFile`, ...).   |

## Index

```@index
```
