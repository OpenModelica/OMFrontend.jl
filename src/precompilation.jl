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
"""
  Some routine to cache more native code for this package.
  Not meant to be used by users.
  The functionality of this file is called during the precompilation phase.
"""
function workload()
  @info "Precompiling builtin libraries..."
  @info "NOTE: This version of OMFrontend only supports Julia versions greater than 1.10"
  if ! haskey(NFModelicaBuiltinCache, "NFModelicaBuiltin")
    @info "Locating external libraries.."
    pathToLib = joinpath(packageRoot(), "lib", "NFModelicaBuiltin.mo")
    #= The external C stuff can be a bit flaky.. =#
    GC.enable(false)
    p = parseFile(pathToLib, 2 #= MetaModelica =#)
    @info "Translating builtin library to SCode.."
    translateToSCode(Absyn.PROGRAM(nil, Absyn.TOP()))
    s = translateToSCode(p)
    @info "SCode translation done. Saving the library in the cache."
    NFModelicaBuiltinCache["NFModelicaBuiltin"] = s
    @info "Builtin Library Loaded!"

    #=Enable GC again.=#
    GC.enable(true)
  end
  @info "Builtin libraries successfully precompiled!"
  @info "Initial compiler module interfaces are compiled!"
  #= Make sure that we load the builtin scode =#
  pathToLib = joinpath(packageRoot(), "lib", "NFModelicaBuiltin.mo")
  #= The external C stuff can be a bit flaky.. =#
  GC.enable(false)
  p = OpenModelicaParser.parseFile(pathToLib, 2 #= MetaModelica=#)
  builtinSCode = Frontend.AbsynToSCode.translateAbsyn2SCode(p)
  GC.enable(true)
  #= End preamble
     Load the Modelica Standard Library =#
  @info "Loading Version 4.1.0 of the Modelica Standard Library"
  local MSL_V_STARTUP  = "MSL_4_1_0"
  initLoadMSL(MSL_Version= MSL_V_STARTUP)
  #= Instantiate the HelloWorld module
     This will precompile a significant part of the frontend. =#
  pathToTest = joinpath(packageRoot(), "test", "Models", "HelloWorld.mo")
  p = OpenModelicaParser.parseFile(pathToTest, 1)
  s = Frontend.AbsynToSCode.translateAbsyn2SCode(p)
  @info "Compiling core modules. This might take awhile.."
  Frontend.Global.initialize()
  # make sure we have all the flags loaded!
  Frontend.FlagsUtil.loadFlags()
  program = listAppend(builtinSCode, s)
  path = Frontend.AbsynUtil.stringPath("HelloWorld")
  @info "Timings concerning compiling core modules for instantiation:"
  @time res1 = Frontend.instClassInProgramFM(path, program)
  #= For other developers reading this.
     Comment out below if you are using revise and want to have faster feedback when changing different datatypes.
     -John 2023-06-22 =#
  @info "Testing to load MSL models"
  function flattenModelInMSL_TST(modelName::String; MSL_V, scalarize::Bool = true)
    if !haskey(OMFrontend.LIBRARY_CACHE, MSL_V)
      OMFrontend.initLoadMSL(MSL_Version= MSL_V)
    end
    local libraryAsScoded = OMFrontend.LIBRARY_CACHE[MSL_V]
    return OMFrontend.instantiateSCodeToFM(modelName, libraryAsScoded; scalarize = scalarize)
  end
  #= Each model is flattened scalarized and with the arrays kept (scalarize = false, OM's translate): the arrays-kept
     path compiles code of its own (2026-11-16: the first flatten of PID_Controller in OM compiled 890 new instances
     with a workload of scalarized flattens only). =#
  precompile_prefix = "Modelica.Electrical.Analog.Examples"
  precompile_model_names = [
    "IdealTriacCircuit",
    "NandGate",
    "AmplifierWithOpAmpDetailed",
    "SimpleTriacCircuit"
  ]
  for p in precompile_model_names
    @info "Translating: $(p)"
    try
      @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0", scalarize = false)
    catch e
      @warn "Precompilation workload failed for $(p)" exception=(e, catch_backtrace())
    end
  end
  precompile_prefix = "Modelica.Mechanics.Rotational.Examples"
  precompile_model_names = [
    "RollingWheel",
    "OneWayClutch",
    "SimpleGearShift"
  ]
  @info "Time spent precompiling MSL models in: $(precompile_prefix)"
  for p in precompile_model_names
    @info "Translating: $(string(precompile_prefix, ".", p))"
    try
      @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0", scalarize = false)
    catch e
      @warn "Precompilation workload failed for $(p)" exception=(e, catch_backtrace())
    end
  end
  #= One model from each of Batteries, QuasiStatic, Digital and Fluid (with Media): their first flatten compiled
     0.3-0.8 s of frontend code not reached by the models above (2026-11-19, 14 MSL models in a fresh process). =#
  for p in ("Modelica.Electrical.Batteries.Examples.BatteryDischargeCharge",
            "Modelica.Electrical.QuasiStatic.SinglePhase.Examples.Transformer",
            "Modelica.Electrical.Digital.Examples.Counter3",
            "Modelica.Fluid.Examples.Tanks.EmptyTanks")
    @info "Translating: $(p)"
    try
      @time flattenModelInMSL_TST(p; MSL_V = "MSL_4_1_0")
      @time flattenModelInMSL_TST(p; MSL_V = "MSL_4_1_0", scalarize = false)
    catch e
      @warn "Precompilation workload failed for $(p)" exception=(e, catch_backtrace())
    end
  end
  #= One MultiBody model with the arrays kept: frames, orientation records and their functions. =#
  @info "Translating: Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum"
  try
    @time flattenModelInMSL_TST("Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum"; MSL_V = "MSL_4_1_0",
                                scalarize = false)
  catch e
    @warn "Precompilation workload failed for DoublePendulum" exception=(e, catch_backtrace())
  end

  #= MultiBody examples commented out to speed up precompilation (nullRotation is slow)
     precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
     @info "Checking MSL Examples in $(precompile_prefix)"
     precompile_model_names = [
       "DoublePendulum",
       "DoublePendulumInitTip",
       "ForceAndTorque",
       "FreeBody"
     ]
     for p in precompile_model_names
       @info "Translating: $(string(precompile_prefix, ".", p))"
       try
         @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
       catch e
         @warn "Precompilation workload failed for $(p)" exception=(e, catch_backtrace())
       end
     end

     precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
     @info "Checking MSL Examples in $(precompile_prefix)"
     precompile_model_names = [
       "Engine1a",
       "Engine1b",
       "Engine1b_analytic"
     ]
     for p in precompile_model_names
       @info "Translating: $(string(precompile_prefix, ".", p))"
       try
         @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
       catch e
         @warn "Precompilation workload failed for $(p)" exception=(e, catch_backtrace())
       end
     end =#
  @info "Core compiler modules are successfully precompiled!"
  @info "Compiler modules are successfully precompiled!"
  #@info "Initializing initial memory buffers..."
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
  let skipped::Int = runPrecompileStatements()
    skipped > 0 && @info "Precompile statements skipped: $(skipped) (regenerate with utilities/precompileStatements.jl)"
  end
end
