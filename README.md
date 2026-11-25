[![Github Action CI](https://github.com/OpenModelica/OMFrontend.jl/workflows/CI/badge.svg)](https://github.com/OpenModelica/OMFrontend.jl/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://openmodelica.github.io/OMFrontend.jl/coverage.json)](https://github.com/OpenModelica/OMFrontend.jl/actions/workflows/ci.yml?query=branch%3Amaster)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://OpenModelica.github.io/OMFrontend.jl/dev/)
[![License: AGPL-3.0 or OSMC-PL](https://img.shields.io/badge/license-AGPL--3.0%20or%20OSMC--PL-lightgrey.svg)](LICENSE.md)

# OMFrontend.jl

An implementation of the OpenModelica New Frontend (NF) in Julia.
The package parses Modelica source, lowers it to SCode, and instantiates it
into a flat model (FlatModelica).

For the full compiler suite that builds on top of this package, see
[OpenModelica.jl](https://github.com/OpenModelica/OM.jl). The API exposed here is
deliberately low-level; for higher-level use cases, prefer OM.jl.

## Library Coverage

The flattening pipeline has been validated against the full Modelica Standard
Library. Both MSL 3.2.3 and MSL 4.1.0 are bundled and ready to use without
any additional installation. Models from every major MSL sub-package
(Blocks, Mechanics, Electrical, Fluid, Media, and MultiBody) flatten
correctly and produce verified flat Modelica output.

Third-party libraries (such as the Modelica Buildings Library) can be
installed via `installLibrary` and loaded via `loadInstalledLibrary`.

## Installation

```julia
using Pkg
Pkg.add("OMFrontend")
```

Versions from 4.0.0 on are registered in the General registry. The versions before 4.0.0 are only in the
[OpenModelicaRegistry](https://github.com/OpenModelica/OpenModelicaRegistry). If `Pkg.add` does not find the
package, or you need a version before 4.0.0, add that registry once and install again:

```julia
using Pkg
Pkg.Registry.add("General")
Pkg.Registry.add(Pkg.RegistrySpec(url = "https://github.com/OpenModelica/OpenModelicaRegistry.git"))
Pkg.add("OMFrontend")
```

## Release Status

This package is the primary frontend used by OM.jl for Modelica flattening.
The core flattening pipeline is stable.

## Example Use

Given the following Modelica model in `HelloWorld.mo`:

```modelica
model HelloWorld
  Real x(start = 1, fixed = true);
  parameter Real a = 1;
equation
  der(x) = -a * x;
end HelloWorld;
```

The shortest path from source to a flat model is `instantiate`:

```julia
using OMFrontend
fm = OMFrontend.instantiate(file = "HelloWorld.mo")
```

The result shows as flat Modelica:

```
model 'HelloWorld'
  public Real x(fixed = true, start = 1.0);
  public parameter Real a = 1.0;
equation
  der(x) = (-a * x);
end 'HelloWorld';
```

The model can also be a string, `OMFrontend.instantiate(string = "model M ... end M;")`, or a class of a
library: `OMFrontend.instantiate("Modelica.Blocks.Examples.PID_Controller")` (the Modelica Standard Library 4.1.0
comes without naming it; other libraries with `libraries = ["MyLib/package.mo"]`). `flatModelica` returns the
text, `classNames` lists classes. A model that cannot be translated raises a short `ModelicaError` with its
messages (`<string>:5:3: Error: Variable y not found in scope HelloWorld.`); `OMFrontend.debug!(true)` gives
developers the full stack trace.

If finer control is needed, the same result can be produced step by step:

```julia
absynProgram  = OMFrontend.parseFile("HelloWorld.mo")
scodeProgram  = OMFrontend.translateToSCode(absynProgram)
(FM, funcs)   = OMFrontend.instantiateSCodeToFM("HelloWorld", scodeProgram)
```

The flat model is the only output of the frontend. The SCode data structures are
in `OMFrontend.SCode` (`src/SCode`; formerly the package SCode.jl).

### Discovering and Loading Installed Libraries

`libraries()` returns all Modelica libraries found in the OpenModelica
installation directory (`~/.openmodelica/libraries/`) plus any non-bundled
entries in the package's own `lib/Modelica/` folder:

```julia
avail = OMFrontend.libraries()
# avail["Modelica"] => [(version="4.1.0", path="...", source=:installed), ...]
```

`loadInstalledLibrary` resolves a library by name and optional version, loads
it into the cache, and returns the cache key:

```julia
mslKey = OMFrontend.loadInstalledLibrary("Modelica"; version = "4.1.0")
# => "Modelica_4_1_0"
```

If `version` is omitted, the first discovered version is used. A prefix match
is accepted when no exact match exists (e.g. `"4.1"` matches `"4.1.0"`).

### Flattening Models from the Modelica Standard Library

Load the MSL once, then flatten any model against it:

```julia
mslKey = OMFrontend.loadInstalledLibrary("Modelica"; version = "4.1.0")

(FM, funcs) = OMFrontend.flattenModelWithLibraries(
  "Modelica.Electrical.Analog.Examples.AD_DA_conversion",
  "MyModel.mo";          # omit or pass "" if model is inside the MSL itself
  libraries = [mslKey],
)
```

> **Note:** `flattenModelWithMSL` and `initLoadMSL` are deprecated. They
> continue to work but emit a deprecation warning. Prefer
> `loadInstalledLibrary` + `flattenModelWithLibraries`.

### Combining a User Model with Multiple Libraries

Custom libraries can be loaded once and then combined freely:

```julia
mslKey      = OMFrontend.loadInstalledLibrary("Modelica"; version = "4.1.0")
buildingsKey = OMFrontend.loadPackageDirectory("/path/to/Buildings")

(FM, funcs) = OMFrontend.flattenModelWithLibraries(
  "Buildings.Controls.OBC.ASHRAE.G36.AHUs.SingleZone.VAV.Controller",
  "";
  libraries = [buildingsKey, mslKey],
)
```

`loadLibrary(path)` loads a single-file `.mo` library;
`loadPackageDirectory(path)` handles directory trees with `package.mo` files.

### Inspecting and Exporting Results

A flat model and its function tree can be rendered as a string or written to
disk:

```julia
str = OMFrontend.toFlatModelica((FM, funcs))
write("HelloWorld.flat.mo", str)
```

For debugging the lowering pipeline, `OMFrontend.enableDumpDebug()` writes the
flat model after each compiler phase to the working directory.
`OMFrontend.disableDumpDebug()` turns it off again.

## Bug Reports and Contributions

All contributions are welcome: bug reports, fixes, tests, documentation.

- Report a bug as an [issue](https://github.com/OpenModelica/OMFrontend.jl/issues),
  with the smallest Modelica model that shows it and the OMFrontend.jl version.
- Send changes as pull requests. Every fix should, where possible, include a small
  test that reproduces the issue: the smallest model that fails before the fix and
  passes after it, in `test/`.

OMFrontend.jl is a component of [OM.jl](https://github.com/OpenModelica/OM.jl), and
the API reflects that low-level role.

For questions or collaboration ideas, contact details are available on my
[LiU page](https://liu.se/en/employee/johti17).

## Documentation

The documentation is built with Documenter.jl from `docs/`: the pages are the
home page, getting started, the API reference and the utilities
(`OMFrontend.ListUtil`, `OMFrontend.ArrayUtil`).

* Online: <https://OpenModelica.github.io/OMFrontend.jl/> (the development version
  under `/dev/`, a release under `/stable/` and `/vX.Y.Z/`).
* In Julia: every documented function has its docstring in the help mode,
  for example `?OMFrontend.flattenModel`; `names(OMFrontend)` lists the public names.
* Locally, from the repository root (the HTML is written to `docs/build/`):

```julia
julia> import Pkg
julia> Pkg.activate("docs")
julia> Pkg.develop(path = ".")   # and the sibling packages, as in the Installation section
julia> include("docs/make.jl")
```

## Licenses

OMFrontend.jl is distributed under the **OSMC Public License 1.8 (OSMC-PL)** or the
**GNU Affero General Public License version 3 (AGPL v3)**, at the recipient's choice;
[LICENSE.md](LICENSE.md) holds both. `OMFrontend.ListUtil` and `OMFrontend.ArrayUtil`,
formerly the packages ListUtil.jl and ArrayUtil.jl, are part of OMFrontend.jl.
