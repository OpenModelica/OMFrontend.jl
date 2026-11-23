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

## Translating a model

```julia
using OMFrontend
fm = OMFrontend.instantiate("MyModel"; file = "MyModel.mo")
fm = OMFrontend.instantiate(string = "model M Real x(start = 1); equation der(x) = -x; end M;")
fm = OMFrontend.instantiate("Modelica.Blocks.Examples.PID_Controller")
```

`instantiate` returns a `FlatModelica`, shown as flat Modelica text; `flatModelica` returns the text itself.
`model` can be left out when the file or string has one top-level class. `libraries` names the libraries a model
uses (a `.mo` file, a package directory, an installed library, `"Modelica 3.2.3"`); the Modelica Standard Library
4.1.0 comes without naming it. `classNames("Modelica.Blocks.Examples")` lists the classes in a package.

A model that cannot be translated raises a `ModelicaError` with the model's messages, one per line:

```
ModelicaError: <string>:1:26: Error: Type mismatch in equation x = true of type Real = Boolean.
```

Nothing else is printed but warnings. `OMFrontend.debug!(true)` is the developer mode: the failure keeps its Julia
stack trace and library loading logs its progress.

## The pipeline step by step

`instantiate` runs these steps; each is available on its own.

### Parsing a Modelica file

```julia
using OMFrontend
program = OMFrontend.parseFile("MyModel.mo")
```

`parseFile` invokes the parser (OpenModelicaParser.jl) and returns an
`OpenModelicaParser.Absyn.Program`. The Absyn tree is
the closest representation to the original textual model.

### Lowering to SCode

```julia
scodeProgram = OMFrontend.translateToSCode(program)
```

SCode is a lowered, modification-free representation. Most semantic checks
operate on SCode rather than Absyn.

### Producing the flat model

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
