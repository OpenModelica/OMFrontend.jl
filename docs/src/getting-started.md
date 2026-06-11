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

`parseFile` invokes the OMParser bridge and returns an
[`Absyn.Program`](https://github.com/OpenModelica/Absyn.jl). The Absyn tree is
the closest representation to the original textual model.

## Lowering to SCode

```julia
scodeProgram = OMFrontend.translateToSCode(program)
```

SCode is a lowered, modification-free representation. Most semantic checks
operate on SCode rather than Absyn.

## Producing a DAE

```julia
(dae, cache) = OMFrontend.instantiateSCodeToDAE("MyModel", scodeProgram)
```

The instantiation pass elaborates the chosen model, resolves modifications,
expands inheritance, and emits a [`DAE.DAElist`](https://github.com/OpenModelica/DAE.jl)
together with the type cache used during lookup.

## Producing flat Modelica

For tooling that wants a textual, fully-flat view of the model:

```julia
(flat, cache) = OMFrontend.instantiateSCodeToFM("MyModel", scodeProgram)
```

## Where to go next

- The [API reference](@ref) lists the documented public entry points.
- Models from the [Modelica Standard Library](https://github.com/modelica/ModelicaStandardLibrary)
  exercise a wide cross-section of the frontend; the `test/` directory in the
  source tree contains a curated subset that runs in CI.
- For backend lowering, see
  [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl).
