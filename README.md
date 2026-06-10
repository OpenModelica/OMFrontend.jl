[![Github Action CI](https://github.com/JKRT/OMFrontend.jl/workflows/CI/badge.svg)](https://github.com/JKRT/OMFrontend.jl/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://JKRT.github.io/OMFrontend.jl/dev/)
[![License: OSMC-PL](https://img.shields.io/badge/license-OSMC--PL-lightgrey.svg)](OSMC-License.txt)

# OMFrontend.jl

An implementation of the OpenModelica New Frontend (NF) in Julia.
The package parses Modelica source, lowers it to SCode, and instantiates it
into FlatModelica or DAE form.

For the full compiler suite that builds on top of this package, see
[OpenModelica.jl](https://github.com/JKRT/OM.jl). The API exposed here is
deliberately low-level; for higher-level use cases, prefer OM.jl.

## Library Coverage

The flattening pipeline has been validated against the full Modelica Standard
Library. Both MSL 3.2.3 and MSL 4.0.0 are bundled and ready to use without
any additional installation. Models from every major MSL sub-package
(Blocks, Mechanics, Electrical, Fluid, Media, and MultiBody) flatten
correctly and produce verified flat Modelica output.

Third-party libraries (such as the Modelica Buildings Library) can be
installed via `installLibrary` and loaded via `loadInstalledLibrary`.

## Release Status

This package is the primary frontend used by OM.jl for Modelica flattening.
The core flattening pipeline is stable. Extensions such as VSS (Variable
Structured Systems) and the GUI editing API are active areas where
interfaces may still evolve.

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

The shortest path from source to a flat model is `flattenModel`:

```julia
using OMFrontend
(FM, functions) = OMFrontend.flattenModel("HelloWorld", "HelloWorld.mo")
println(OMFrontend.toString(FM))
```

The output is the flat representation of the model:

```
class HelloWorld
  Real x(fixed = true, start = 1.0);
  parameter Real a = 1.0;
equation
  der(x) = -a * x;
end HelloWorld;
```

If finer control is needed, the same result can be produced step by step:

```julia
absynProgram  = OMFrontend.parseFile("HelloWorld.mo")
scodeProgram  = OMFrontend.translateToSCode(absynProgram)
(FM, funcs)   = OMFrontend.instantiateSCodeToFM("HelloWorld", scodeProgram)
```

To obtain the DAE form instead of FlatModelica, call `instantiateSCodeToDAE`
on the SCode program returned by `translateToSCode`. See
[DAE.jl](https://github.com/JKRT/DAE.jl) for the data structure.

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
mslKey = OMFrontend.loadInstalledLibrary("Modelica"; version = "4.0.0")

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
OMFrontend.exportDAERepresentationToFile("HelloWorld.flat.mo", str)
```

For debugging the lowering pipeline, `OMFrontend.enableDumpDebug()` writes the
flat model after each compiler phase to the working directory.
`OMFrontend.disableDumpDebug()` turns it off again.

### Issues, Questions, and Contributing

OMFrontend.jl is a component of [OM.jl](https://github.com/JKRT/OM.jl), and
the API reflects that low-level role.

For questions or collaboration ideas, contact details are available on my
[LiU page](https://liu.se/en/employee/johti17).

## Licenses

OMFrontend.jl itself is distributed under the **OSMC Public License (OSMC-PL)**;
see `OSMC-License.txt`.

Third-party Modelica libraries included in the test suite (`test/3rdParty/`)
carry their own licenses and are not covered by OSMC-PL:

| Library | License | Source |
|---|---|---|
| [Modelica Buildings Library](https://github.com/lbl-srg/modelica-buildings) | Modified BSD (3-clause) | Lawrence Berkeley National Laboratory |

See `test/3rdParty/README.md` for the full license text of each third-party
library.
