#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
* VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the OSMC (Open Source Modelica Consortium)
* Public License (OSMC-PL) are obtained from OSMC, either from the above
* address, from the URLs:
* http://www.openmodelica.org or
* https://github.com/OpenModelica/ or
* http://www.ida.liu.se/projects/OpenModelica,
* and in the OpenModelica distribution.
*
* GNU AGPL version 3 is obtained from:
* https://www.gnu.org/licenses/licenses.html#GPL
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#

using PrecompileTools

#= ---------------------------------------------------------------------------------------------------------------
   The precompile display: one line per step, a mark, the step and its time, in color when Julia has color. Julia
   shows it live above its progress bar when `using OMFrontend` precompiles the package, and after the bar when
   Pkg precompiles it as a dependency.
   --------------------------------------------------------------------------------------------------------------- =#

"""The time the display started (`time_ns`), 0 when the workload does not run."""
const PRECOMPILE_START = Ref{UInt64}(0)

"""The stream of the display: stdout, in color when Julia runs with color (`--color`, passed on to precompilation)."""
_precompileIO()::IOContext = IOContext(stdout, :color => Base.get_have_color())

"""`ns` nanoseconds as `850 ms` or `1.9 s`."""
function _duration(ns::UInt64)::String
  local s::Float64 = ns / 1e9
  return s < 1 ? string(round(Int, 1000 * s), " ms") : string(round(s; digits = 1), " s")
end

"""The display's header: the package, Julia, the threads, and the pipeline the workload compiles."""
function _precompileHeader(io::IOContext)::Nothing
  PRECOMPILE_START[] = time_ns()
  local version::String = string(something(pkgversion(@__MODULE__), "dev"))
  println(io)
  printstyled(io, "  OMFrontend ", version; bold = true, color = :blue)
  printstyled(io, "   precompiling with Julia ", VERSION, "\n"; color = :light_black)
  printstyled(io, "  Modelica ▸ Parse ▸ SCode ▸ Instantiate ▸ Type, flatten ▸ Flat model\n"; color = :blue)
  return nothing
end

"""A bar of `width` cells, `done` of `total` filled."""
function _bar(done::Int, total::Int, width::Int = 16)::String
  local filled::Int = round(Int, width * done / total)
  return "━"^filled * "─"^(width - filled)
end

"""
Runs `f` and prints `✓ <prefix><label>  <time>`; when `f` throws, `✗ <prefix><label>` and the error as a warning (the
workload goes on). `prefix` is printed in blue (a progress bar).
"""
function _precompileStep(f::F, io::IOContext, label::String; prefix::String = "")::Nothing where {F <: Function}
  local t0::UInt64 = time_ns()
  local failed::Bool = false
  try
    f()
  catch e
    failed = true
    @warn "Precompilation workload failed: $(label)" exception = (e, catch_backtrace())
  end
  printstyled(io, failed ? "  ✗ " : "  ✓ "; color = failed ? :red : :green, bold = failed)
  printstyled(io, prefix; color = :blue)
  print(io, rpad(label, 60 - length(prefix)))
  printstyled(io, failed ? "failed\n" : _duration(time_ns() - t0) * "\n"; color = failed ? :red : :light_black)
  return nothing
end

"""`Modelica.Electrical.Analog.Examples.NandGate` as `NandGate (Analog)`: a line of the display fits 80 columns."""
function _shortName(name::String)::String
  local parts::Vector{SubString{String}} = split(name, '.')
  local domain::SubString{String} = parts[2] in ("Electrical", "Mechanics") ? parts[3] : parts[2]
  return string(parts[end], " (", domain, ")")
end

"""The flat model of `modelName` in the cached library `MSL_V`, the arrays scalarized or kept."""
function _flattenInMSL(modelName::String, MSL_V::String; scalarize::Bool = true)
  haskey(LIBRARY_CACHE, MSL_V) || initLoadMSL(MSL_Version = MSL_V)
  return instantiateSCodeToFM(modelName, LIBRARY_CACHE[MSL_V]; scalarize = scalarize)
end

"""
The models the workload flattens, scalarized and with the arrays kept (OM's translate; 2026-11-16: the first flatten
of PID_Controller in OM compiled 890 new instances after a workload of scalarized flattens only). Batteries,
QuasiStatic, Digital and Fluid compiled 0.3-0.8 s of frontend code the others do not reach (2026-11-19). The
MultiBody model, frames, orientation records and their functions, only with the arrays kept.
"""
const PRECOMPILE_MODELS = (
  "Modelica.Electrical.Analog.Examples.IdealTriacCircuit" => true,
  "Modelica.Electrical.Analog.Examples.NandGate" => true,
  "Modelica.Electrical.Analog.Examples.AmplifierWithOpAmpDetailed" => true,
  "Modelica.Electrical.Analog.Examples.SimpleTriacCircuit" => true,
  "Modelica.Mechanics.Rotational.Examples.RollingWheel" => true,
  "Modelica.Mechanics.Rotational.Examples.OneWayClutch" => true,
  "Modelica.Mechanics.Rotational.Examples.SimpleGearShift" => true,
  "Modelica.Electrical.Batteries.Examples.BatteryDischargeCharge" => true,
  "Modelica.Electrical.QuasiStatic.SinglePhase.Examples.Transformer" => true,
  "Modelica.Electrical.Digital.Examples.Counter3" => true,
  "Modelica.Fluid.Examples.Tanks.EmptyTanks" => true,
  "Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum" => false)

"""
Compiles the frontend while OMFrontend precompiles: the builtin library, the Modelica Standard Library 4.1.0, a
small model, then the models of `PRECOMPILE_MODELS`. Not meant for users.
"""
function workload()
  local io::IOContext = _precompileIO()
  _precompileHeader(io)
  #= The library loads print @info lines; the display has its own. Warnings still show. =#
  Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Warn)) do
    _workloadSteps(io)
  end
  return nothing
end

"""The steps of `workload`, each a line of the display."""
function _workloadSteps(io::IOContext)::Nothing
  local pathToLib::String = joinpath(packageRoot(), "lib", "NFModelicaBuiltin.mo")
  _precompileStep(io, "Builtin library (NFModelicaBuiltin.mo)") do
    #= The external C stuff can be a bit flaky.. =#
    GC.enable(false)
    try
      if !haskey(NFModelicaBuiltinCache, "NFModelicaBuiltin")
        translateToSCode(Absyn.PROGRAM(nil, Absyn.TOP()))
        NFModelicaBuiltinCache["NFModelicaBuiltin"] = translateToSCode(parseFile(pathToLib, 2 #= MetaModelica =#))
      end
    finally
      GC.enable(true)
    end
  end
  _precompileStep(() -> initLoadMSL(MSL_Version = "MSL_4_1_0"), io, "Modelica Standard Library 4.1.0")
  _precompileStep(io, "Core modules (HelloWorld)") do
    GC.enable(false)
    local builtinSCode = try
      Frontend.AbsynToSCode.translateAbsyn2SCode(OpenModelicaParser.parseFile(pathToLib, 2))
    finally
      GC.enable(true)
    end
    local p = OpenModelicaParser.parseFile(joinpath(packageRoot(), "test", "Models", "HelloWorld.mo"), 1)
    local s = Frontend.AbsynToSCode.translateAbsyn2SCode(p)
    Frontend.Global.initialize()
    Frontend.FlagsUtil.loadFlags()
    Frontend.instClassInProgramFM(Frontend.AbsynUtil.stringPath("HelloWorld"), listAppend(builtinSCode, s))
  end
  local n::Int = length(PRECOMPILE_MODELS)
  for (i, (name, scalarized)) in enumerate(PRECOMPILE_MODELS)
    local prefix::String = string(_bar(i, n), " ", lpad(i, 2), "/", n, "  ")
    _precompileStep(io, _shortName(name); prefix = prefix) do
      scalarized && _flattenInMSL(name, "MSL_4_1_0")
      _flattenInMSL(name, "MSL_4_1_0"; scalarize = false)
    end
  end
  return nothing
end

PrecompileTools.@compile_workload begin
  #= When building inside OM, OM's own @compile_workload re-exercises the frontend and is the
     bake that PERSISTS (OM is the leaf package); this intermediate-package workload is then
     redundant AND invalidated by later loads. Set OMFRONTEND_NO_PRECOMPILE_WORKLOAD=1 to skip
     it in the OM build (mirrors OMBACKEND_NO_PRECOMPILE_WORKLOAD). Standalone OMFrontend
     precompiles (no env var) still run it. =#
  if get(ENV, "OMFRONTEND_NO_PRECOMPILE_WORKLOAD", "") == ""
    workload()
  end
end

"""
The names of the traced precompile statements: OMFrontend and every package loaded with it, under the names the
trace prints (`ImmutableList.ListDef.Cons`, `Accessors.PropertyLens`), bound when OMFrontend precompiles.
"""
module PrecompileNames
  import ..OMFrontend
  for m in values(Base.loaded_modules)
    isdefined(@__MODULE__, nameof(m)) || Core.eval(@__MODULE__, :(const $(nameof(m)) = $m))
  end
end

"""The precompile statements traced from cold flattens of MSL models (`utilities/precompileStatements.jl`)."""
const PRECOMPILE_STATEMENTS_FILE = joinpath(@__DIR__, "precompileStatements.txt")
include_dependency(PRECOMPILE_STATEMENTS_FILE)

"""
Compiles the methods a cold flatten of MSL models still compiled at run time after the workload (traced over
models of each MSL domain, `utilities/coldFlatten.jl`). A statement whose names no longer resolve, after a
change of the code, is skipped; the number skipped is returned.
"""
function runPrecompileStatements()::Int
  local skipped::Int = 0
  for line in eachline(PRECOMPILE_STATEMENTS_FILE)
    isempty(line) && continue
    try
      Core.eval(PrecompileNames, Meta.parse(line))::Bool || (skipped += 1)
    catch
      skipped += 1
    end
  end
  return skipped
end

if ccall(:jl_generating_output, Cint, ()) == 1
  let io::IOContext = _precompileIO(), t0::UInt64 = time_ns(), skipped::Int = runPrecompileStatements()
    if PRECOMPILE_START[] > 0
      printstyled(io, "  ✓ "; color = :green)
      print(io, rpad("Traced precompile statements" * (skipped > 0 ? " ($(skipped) skipped)" : ""), 60))
      printstyled(io, _duration(time_ns() - t0), "\n"; color = :light_black)
      printstyled(io, "  Workload done in ", _duration(time_ns() - PRECOMPILE_START[]), "\n"; bold = true, color = :blue)
    end
    skipped > 0 && @info "Precompile statements skipped: $(skipped) (regenerate with utilities/precompileStatements.jl)"
  end
end
