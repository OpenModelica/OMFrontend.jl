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

using Revise
import OMFrontend

OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, true)
#import OM
#using OMFrontend
using BenchmarkTools
begin
  packagePath = dirname(realpath(Base.find_package("OMFrontend")))
  packagePath *= "/.."
  pathToTest = packagePath * "/test/Models/HelloWorld.mo"
  p = OMParser.parseFile(pathToTest, 1)
  s = OMFrontend.Frontend.AbsynToSCode.translateAbsyn2SCode(p)

  packagePath = dirname(realpath(Base.find_package("OMFrontend")))
  packagePath *= "/.."
  pathToLib = packagePath * "/lib/NFModelicaBuiltin.mo"
  #= The external C stuff can be a bit flaky.. =#
  GC.enable(false)
  p = OMParser.parseFile(pathToLib, 2 #== MetaModelica ==#)
  builtinSCode = OMFrontend.Frontend.AbsynToSCode.translateAbsyn2SCode(p)

  program = listAppend(builtinSCode, s)
  path = OMFrontend.Frontend.AbsynUtil.stringPath("HelloWorld")
  @info "Timings concerning compiling core modules for instantiation:"
  @time res1 = OMFrontend.Frontend.instClassInProgram(path, program)
  GC.enable(true)
end;

function flattenModelInMSL_TST(modelName::String; MSL_V = "MSL_4_1_0", scalarize = true)
  local mslSCode
  if !haskey(OMFrontend.LIBRARY_CACHE, MSL_V)
    mslSCode = OMFrontend.initLoadMSL(MSL_Version= MSL_V)
    return (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, mslSCode; scalarize = scalarize)
  end
  local mslSCode = OMFrontend.LIBRARY_CACHE[MSL_V]
  return (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, mslSCode; scalarize=scalarize)
end



# precompile_prefix = "Modelica.Electrical.Analog.Examples"
# precompile_model_names = [
#     "IdealTriacCircuit",
#   "NandGate",
#   "AmplifierWithOpAmpDetailed",
#   "SimpleTriacCircuit"
# ]

# @info "Precompiling...."
# for p in precompile_model_names
#     @info "Translating: $(p)"
#     @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
#     @info "Done!"
#   end
# @info "Done"
# precompile_prefix = "Modelica.Mechanics.Rotational.Examples"
# precompile_model_names = [
#   "RollingWheel",
#   "OneWayClutch",
#   "SimpleGearShift"
# ]
# @info "Precompiling...."
# for p in precompile_model_names
#     @info "Translating: $(p)"
#     @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
#     @info "Done!"
#   end
# @info "Done"


# precompile_prefix = "Modelica.Mechanics.Rotational.Components"
# precompile_model_names = [
#     "Spring",
#     "Fixed",
#     "Inertia",
#     "Disc",
#     "Damper",
#     "SpringDamper",
#     "ElastoBacklash",
#     "ElastoBacklash2",
#     "BearingFriction",
#     "Brake",
#     "Clutch",
#     "OneWayClutch",
#     "IdealGear",
#     "LossyGear",
#     "IdealPlanetary",
#     "Gearbox",
#     "IdealGearR2T",
#     "IdealRollingWheel"
# ]
# @info "Precompiling...."
# for p in precompile_model_names
#     @info "Translating: $(p)"
#     @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
#     @info "Done!"
#   end
# @info "Done"

precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
precompile_model_names = [
  "Pendulum",
  "DoublePendulum",
  # "DoublePendulumInitTip",
  # "ForceAndTorque",
  # "FreeBody",
  # "InitSpringConstant",
  # "LineForceWithTwoMasses",
  # "PendulumWithSpringDamper",
  # "PointGravity",
  # "PointGravityWithPointMasses",
  # "PointGravityWithPointMasses2",
  # "SpringDamperSystem",
  # "SpringMassSystem",
  # "SpringWithMass",
  # "ThreeSprings",
  # "RollingWheel",
  #  "RollingWheelSetDriving",
  # "RollingWheelSetPulling",
  # "HeatLosses",
  # "UserDefinedGravityField",
  # "Surfaces"
]

@info "Precompiling...."
for p in precompile_model_names
  @info "Translating: $(p)"
  #@time OMFrontend.Frontend.MemoryUtil.initialize(400000)
  @info "Running"
  @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
  @info "Done!"
  end
@info "Done"



@info "Precompiling...."
precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
precompile_model_names = [
  "Engine1a",
  "Engine1b",
  "Engine1b_analytic",
#  "EngineV6"
]
for p in precompile_model_names
  @info "Translating: $(p)"
  name = string(precompile_prefix, ".", p)
  #@time OMFrontend.Frontend.MemoryUtil.initialize(400000)
  GC.gc()
  @time flattenModelInMSL_TST(name; MSL_V = "MSL_4_1_0")
  @info "Done!"
end
@info "Done"

#OMFrontend.Frontend.MemoryUtil.initialize(400000)

import Profile
using Profile, PProf
using StatProfilerHTML

function profileMemV6()
  precompile_model_names = [
    #"Engine1a",
    #"Engine1b",
    #"Engine1b_analytic",
    "EngineV6"
  ]
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  p = "EngineV6"
  @info "Prerunning the engine for some data..."
  @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
  @profilehtml begin
    for p in precompile_model_names
      @info "Translating: $(p)"
      flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @info "Done!"
    end
  end
  Profile.Allocs.clear()
  Profile.init(1000001, 0.1)
  #PProf.Allocs.pprof()
  for p in precompile_model_names
    @info "Translating: $(p)"
    Profile.Allocs.@profile sample_rate=0.01 flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end
  PProf.Allocs.pprof()
end

function runPendulum()
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
  precompile_model_names = [
    "DoublePendulum"
  ]

  for p in precompile_model_names
    @info "Translating: $(p)"
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end
end

function profileMemPendulum()
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
  precompile_model_names = [
    "DoublePendulum"
  ]

  for p in precompile_model_names
    @info "Translating: $(p)"
    flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end

  Profile.Allocs.clear()
  Profile.init(10000001, 0.0001)
  #PProf.Allocs.pprof()
  @info "Running profile HTML"
  @profilehtml begin
    for p in precompile_model_names
      @info "Translating: $(p)"
      Profile.Allocs.@profile sample_rate=0.01 flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @info "Done!"
    end
    PProf.Allocs.pprof()
  end
end

function runEngine()
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  precompile_model_names = [
    "Engine1a"
  ]
  for p in precompile_model_names
    @info "Translating: $(p)"
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end
end

function profileMemEngine()
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  precompile_model_names = [
    "Engine1a"
  ]
  for p in precompile_model_names
    @info "Translating: $(p)"
    flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end
    precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  precompile_model_names = [
    "Engine1a"
  ]
  for p in precompile_model_names
    @info "Translating: $(p)"
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end

  Profile.Allocs.clear()
  Profile.init(10000001, 0.001)
  @profilehtml begin
    for p in precompile_model_names
      @info "Translating: $(p)"
      @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @info "Done!"
    end
  end

  Profile.Allocs.clear()
  Profile.init(10000001, 0.0001)
  #PProf.Allocs.pprof()
  @info "Profiling memory..."
  for p in precompile_model_names
    @info "Translating: $(p)"
    Profile.Allocs.@profile sample_rate=0.1 flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
    @info "Done!"
  end
  PProf.Allocs.pprof()
end


function profile2()
  precompile_model_names = [
    #"Engine1a",
    #"Engine1b",
    #"Engine1b_analytic",
    "EngineV6"
  ]
  Profile.clear()
  Profile.init(1000001, 0.1)
  @info "Running profile HTML"
  #Profile.init(100, 0.0001)
  @info "Setting profile settings..."
  @profilehtml begin
    for p in precompile_model_names
      @info "Translating: $(p)"
      flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_1_0")
      @info "Done!"
    end
  end
end
include("testProduceEngine.jl")
