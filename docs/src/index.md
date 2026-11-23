```@meta
CurrentModule = OMFrontend
```

# OMFrontend.jl

`OMFrontend` is the Julia port of the OpenModelica frontend. It parses Modelica
source, lowers it through SCode, and produces the flat model
(`FLAT_MODEL`, printable as flat Modelica) consumed by [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl)
and the wider [OM.jl](https://github.com/OpenModelica/OM.jl) toolchain.

## What this package does

* Parses Modelica via [OpenModelicaParser.jl](https://github.com/OpenModelica/OpenModelicaParser.jl)
  and produces an Absyn tree (`OpenModelicaParser.Absyn`).
* Translates the abstract syntax tree to SCode (`OMFrontend.SCode`).
* Instantiates SCode into a flat model (`FLAT_MODEL`) for backend lowering.
* Optionally prints the flat model as flat Modelica for inspection.

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

fm = OMFrontend.instantiate("MyModel"; file = "MyModel.mo")
print(fm)        # flat Modelica
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
