#=
  01_load_msl.jl

  Flatten a model that depends on the Modelica Standard Library.

  Two ways to make MSL available to OMFrontend:

    1. `loadBundledMSL` — uses the MSL snapshot shipped inside OMFrontend.jl
       under `lib/Modelica/`. No OpenModelica installation required.

    2. `loadInstalledLibrary("Modelica")` — uses an MSL installed under
       `~/.openmodelica/libraries/` (managed by the OpenModelica installer
       or `installLibrary`). Use this when you need a specific MSL version
       or any other library available through `libraries()`.
=#

using OMFrontend

const HERE = @__DIR__
const MODEL_FILE = joinpath(HERE, "Models", "SimpleCircuitMSL.mo")

# --- Option A: bundled MSL (default version 3.2.3) -------------------------
mslKey = OMFrontend.loadBundledMSL(version = "3.2.3")

(fm, _funcs) = OMFrontend.flattenModelWithLibraries(
  "ElectricalTest.SimpleCircuit",
  MODEL_FILE;
  libraries = [mslKey],
)

println("=== Flat model via bundled MSL ===")
println(OMFrontend.toString(fm))

# --- Option B: installed Modelica library ----------------------------------
# Requires Modelica to be present under ~/.openmodelica/libraries/.
# Falls back to a clear message when the install is not available.
try
  installedKey = OMFrontend.loadInstalledLibrary("Modelica")
  (fm2, _) = OMFrontend.flattenModelWithLibraries(
    "ElectricalTest.SimpleCircuit",
    MODEL_FILE;
    libraries = [installedKey],
  )
  println("=== Flat model via installed Modelica ($installedKey) ===")
  println(OMFrontend.toString(fm2))
catch e
  @info "Skipping installed-Modelica branch: $e"
end
