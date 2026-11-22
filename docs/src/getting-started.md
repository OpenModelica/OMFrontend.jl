```@meta
CurrentModule = OMFrontend
```

# Getting started

## Setup

OMFrontend depends on several sibling packages from the
[OM.jl](https://github.com/OpenModelica/OM.jl) project. The simplest way to develop
against it is to clone the umbrella repository, which carries each sibling as a
git submodule:

```sh
git clone --recursive https://github.com/OpenModelica/OM.jl
cd OM.jl/OMFrontend.jl
julia --project -e 'import Pkg; Pkg.instantiate()'
```

When using the registered package directly, `Pkg.add("OMFrontend")` resolves
the same dependency graph through `OpenModelicaRegistry`.

## Parsing a Modelica file

```julia
using OMFrontend
program = OMFrontend.parseFile("MyModel.mo")
```

`parseFile` invokes the parser (OpenModelicaParser.jl) and returns an
`OpenModelicaParser.Absyn.Program`. The Absyn tree is
the closest representation to the original textual model.

## Lowering to SCode

```julia
scodeProgram = OMFrontend.translateToSCode(program)
```

SCode is a lowered, modification-free representation. Most semantic checks
operate on SCode rather than Absyn.

## Producing the flat model

```julia
(flat, funcs) = OMFrontend.instantiateSCodeToFM("MyModel", scodeProgram)
```

The instantiation pass elaborates the chosen model, resolves modifications,
expands inheritance, and flattens the result into a `FLAT_MODEL`
together with its function tree. This is the output of the frontend and the
input of [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl).

For a textual view of the flat model:

```julia
str = OMFrontend.toFlatModelica((flat, funcs))
```

## Where to go next

- The [API reference](@ref) lists the documented public entry points.
- Models from the [Modelica Standard Library](https://github.com/modelica/ModelicaStandardLibrary)
  exercise a wide cross-section of the frontend; the `test/` directory in the
  source tree contains a curated subset that runs in CI.
- For backend lowering, see
  [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl).
