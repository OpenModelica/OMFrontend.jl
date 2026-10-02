#=
  Export structural-mode Modelica models to hierarchy/flat JSON.
  Author: johti17

  Reproduces what /home/johti17/Projects/INRIA/John/flatten_structuralMode.jl
  did externally, against the now-in-tree OMFrontend public API.
=#

using OMFrontend

const BASE_DIR = @__DIR__
const MODEL_DIR = joinpath(BASE_DIR, "StructuralMode", "STRUCTURAL_MODE_MODELS")
const REGULAR_DIR = joinpath(BASE_DIR, "StructuralMode", "REGULAR_MODELS")
const OUTPUT_DIR = joinpath(BASE_DIR, "StructuralMode", "out")
mkpath(OUTPUT_DIR)

# Self-contained structural-mode models (nested Pendulum / Table definitions)
OMFrontend.exportJSON(
  "CoupledPenduli",
  joinpath(MODEL_DIR, "CoupledPenduli_structuralMode.mo");
  output_dir = OUTPUT_DIR,
  base_name = "CoupledPenduli_SF",
  class_mapping = Dict("p1" => "Pendulum", "p2" => "Pendulum", "tb" => "Table"),
)

OMFrontend.exportJSON(
  "CoupledPenduli",
  joinpath(MODEL_DIR, "CoupledPenduliEnergy_structuralMode.mo");
  output_dir = OUTPUT_DIR,
  base_name = "CoupledPenduliEnergy_SF",
  class_mapping = Dict("p1" => "Pendulum", "p2" => "Pendulum", "tb" => "Table"),
)

OMFrontend.exportJSON(
  "CoupledPendulums",
  joinpath(MODEL_DIR, "coupledPenduli_CoupledPendulums_structuralMode.mo");
  output_dir = OUTPUT_DIR,
  base_name = "coupledPenduli_CoupledPendulums_SF",
)

# MSL-backed models. The library name is resolved via loadInstalledLibrary.
OMFrontend.exportJSON(
  "Pendulum",
  joinpath(REGULAR_DIR, "Pendulum.mo"),
  "Modelica";
  output_dir = OUTPUT_DIR,
  base_name = "Pendulum_SF",
)

OMFrontend.exportJSON(
  "Pendulum",
  joinpath(MODEL_DIR, "Pendulum_structuralMode.mo"),
  "Modelica";
  output_dir = OUTPUT_DIR,
  base_name = "Pendulum_structuralMode_SF",
)

@info "All models exported to $(OUTPUT_DIR)."
