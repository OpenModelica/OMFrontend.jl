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

module FlagsUtil

Base.Experimental.@compiler_options(optimize=0, compile=min, infer=no)

using MetaModelica
#= ExportAll is not good practice but it makes it so that we do not have to write export after each function :( =#
using ExportAll

import ..Flags
import ..Corba
import ..Error
import ..ErrorExt
import ..Global
import ..ListUtil
import ..Print
import ..Settings
import ..StringUtil
import ..System
import ..Util
import ..Gettext
#=  This is a list of all debug flags, to keep track of which flags are used. A
=#
#=  flag can not be used unless it's in this list, and the list is checked at
=#
#=  initialization so that all flags are sorted by index (and thus have unique
=#
#=  indices).
=#

const allDebugFlags = list(Flags.FAILTRACE, Flags.CEVAL, Flags.CHECK_BACKEND_DAE, Flags.PARMODAUTO, Flags.PTHREADS, Flags.EVENTS, Flags.DUMP_INLINE_SOLVER, Flags.EVAL_FUNC, Flags.GEN, Flags.DYN_LOAD, Flags.GENERATE_CODE_CHEAT, Flags.CGRAPH_GRAPHVIZ_FILE, Flags.CGRAPH_GRAPHVIZ_SHOW, Flags.GC_PROF, Flags.CHECK_DAE_CREF_TYPE, Flags.CHECK_ASUB, Flags.INSTANCE, Flags.CACHE, Flags.RML, Flags.TAIL, Flags.LOOKUP, Flags.PATTERNM_SKIP_FILTER_UNUSED_AS_BINDINGS, Flags.PATTERNM_ALL_INFO, Flags.PATTERNM_DCE, Flags.PATTERNM_MOVE_LAST_EXP, Flags.EXPERIMENTAL_REDUCTIONS, Flags.EVAL_PARAM, Flags.TYPES, Flags.SHOW_STATEMENT, Flags.DUMP, Flags.DUMP_GRAPHVIZ, Flags.EXEC_STAT, Flags.TRANSFORMS_BEFORE_DUMP, Flags.DAE_DUMP_GRAPHV, Flags.INTERACTIVE_TCP, Flags.INTERACTIVE_CORBA, Flags.INTERACTIVE_DUMP, Flags.RELIDX, Flags.DUMP_REPL, Flags.DUMP_FP_REPL, Flags.DUMP_PARAM_REPL, Flags.DUMP_PP_REPL, Flags.DUMP_EA_REPL, Flags.DEBUG_ALIAS, Flags.TEARING_DUMP, Flags.JAC_DUMP, Flags.JAC_DUMP2, Flags.JAC_DUMP_EQN, Flags.JAC_WARNINGS, Flags.DUMP_SPARSE, Flags.DUMP_SPARSE_VERBOSE, Flags.BLT_DUMP, Flags.DUMMY_SELECT, Flags.DUMP_DAE_LOW, Flags.DUMP_INDX_DAE, Flags.OPT_DAE_DUMP, Flags.EXEC_HASH, Flags.PARAM_DLOW_DUMP, Flags.DUMP_ENCAPSULATECONDITIONS, Flags.SHORT_OUTPUT, Flags.COUNT_OPERATIONS, Flags.CGRAPH, Flags.UPDMOD, Flags.STATIC, Flags.TPL_PERF_TIMES, Flags.CHECK_SIMPLIFY, Flags.SCODE_INST, Flags.WRITE_TO_BUFFER, Flags.DUMP_BACKENDDAE_INFO, Flags.GEN_DEBUG_SYMBOLS, Flags.DUMP_STATESELECTION_INFO, Flags.DUMP_EQNINORDER, Flags.SEMILINEAR, Flags.UNCERTAINTIES, Flags.SHOW_START_ORIGIN, Flags.DUMP_SIMCODE, Flags.DUMP_INITIAL_SYSTEM, Flags.GRAPH_INST, Flags.GRAPH_INST_RUN_DEP, Flags.GRAPH_INST_GEN_GRAPH, Flags.GRAPH_INST_SHOW_GRAPH, Flags.DUMP_CONST_REPL, Flags.SHOW_EQUATION_SOURCE, Flags.LS_ANALYTIC_JACOBIAN, Flags.NLS_ANALYTIC_JACOBIAN, Flags.INLINE_SOLVER, Flags.HPCOM, Flags.INITIALIZATION, Flags.INLINE_FUNCTIONS, Flags.DUMP_SCC_GRAPHML, Flags.TEARING_DUMPVERBOSE, Flags.DISABLE_SINGLE_FLOW_EQ, Flags.DUMP_DISCRETEVARS_INFO, Flags.ADDITIONAL_GRAPHVIZ_DUMP, Flags.INFO_XML_OPERATIONS, Flags.HPCOM_DUMP, Flags.RESOLVE_LOOPS_DUMP, Flags.DISABLE_WINDOWS_PATH_CHECK_WARNING, Flags.DISABLE_RECORD_CONSTRUCTOR_OUTPUT, Flags.IMPL_ODE, Flags.EVAL_FUNC_DUMP, Flags.PRINT_STRUCTURAL, Flags.ITERATION_VARS, Flags.ALLOW_RECORD_TOO_MANY_FIELDS, Flags.HPCOM_MEMORY_OPT, Flags.DUMP_SYNCHRONOUS, Flags.STRIP_PREFIX, Flags.DO_SCODE_DEP, Flags.SHOW_INST_CACHE_INFO, Flags.DUMP_UNIT, Flags.DUMP_EQ_UNIT, Flags.DUMP_EQ_UNIT_STRUCT, Flags.SHOW_DAE_GENERATION, Flags.RESHUFFLE_POST, Flags.SHOW_EXPANDABLE_INFO, Flags.DUMP_HOMOTOPY, Flags.OMC_RELOCATABLE_FUNCTIONS, Flags.GRAPHML, Flags.USEMPI, Flags.DUMP_CSE, Flags.DUMP_CSE_VERBOSE, Flags.NO_START_CALC, Flags.CONSTJAC, Flags.VISUAL_XML, Flags.VECTORIZE, Flags.CHECK_EXT_LIBS, Flags.RUNTIME_STATIC_LINKING, Flags.SORT_EQNS_AND_VARS, Flags.DUMP_SIMPLIFY_LOOPS, Flags.DUMP_RTEARING, Flags.DIS_SYMJAC_FMI20, Flags.EVAL_OUTPUT_ONLY, Flags.HARDCODED_START_VALUES, Flags.DUMP_FUNCTIONS, Flags.DEBUG_DIFFERENTIATION, Flags.DEBUG_DIFFERENTIATION_VERBOSE, Flags.FMU_EXPERIMENTAL, Flags.DUMP_DGESV, Flags.MULTIRATE_PARTITION, Flags.DUMP_EXCLUDED_EXP, Flags.DEBUG_ALGLOOP_JACOBIAN, Flags.DISABLE_JACSCC, Flags.FORCE_NLS_ANALYTIC_JACOBIAN, Flags.DUMP_LOOPS, Flags.DUMP_LOOPS_VERBOSE, Flags.SKIP_INPUT_OUTPUT_SYNTACTIC_SUGAR, Flags.OMC_RECORD_ALLOC_WORDS, Flags.TOTAL_TEARING_DUMP, Flags.TOTAL_TEARING_DUMPVERBOSE, Flags.PARALLEL_CODEGEN, Flags.SERIALIZED_SIZE, Flags.BACKEND_KEEP_ENV_GRAPH, Flags.DUMPBACKENDINLINE, Flags.DUMPBACKENDINLINE_VERBOSE, Flags.BLT_MATRIX_DUMP, Flags.LIST_REVERSE_WRONG_ORDER, Flags.PARTITION_INITIALIZATION, Flags.EVAL_PARAM_DUMP, Flags.NF_UNITCHECK, Flags.DISABLE_COLORING, Flags.MERGE_ALGORITHM_SECTIONS, Flags.WARN_NO_NOMINAL, Flags.REDUCE_DAE, Flags.IGNORE_CYCLES, Flags.ALIAS_CONFLICTS, Flags.SUSAN_MATCHCONTINUE_DEBUG, Flags.OLD_FE_UNITCHECK, Flags.EXEC_STAT_EXTRA_GC, Flags.DEBUG_DAEMODE, Flags.NF_SCALARIZE, Flags.NF_EVAL_CONST_ARG_FUNCS, Flags.NF_EXPAND_OPERATIONS, Flags.NF_API, Flags.NF_API_DYNAMIC_SELECT, Flags.NF_API_NOISE, Flags.FMI20_DEPENDENCIES, Flags.WARNING_MINMAX_ATTRIBUTES, Flags.NF_EXPAND_FUNC_ARGS, Flags.DUMP_JL, Flags.DUMP_ASSC, Flags.SPLIT_CONSTANT_PARTS_SYMJAC, Flags.NF_DUMP_FLAT, Flags.DUMP_FORCE_FMI_ATTRIBUTES, Flags.DUMP_FORCE_FMI_INTERNAL_VARIABLES, Flags.NF_PARALLEL, Flags.NF_SEPARATE_INSTANTIATION)::List

#=  This is a list of all configuration flags. A flag can not be used unless it's
=#
#=  in this list, and the list is checked at initialization so that all flags are
=#
#=  sorted by index (and thus have unique indices).
=#
const allConfigFlags = list(Flags.DEBUG, Flags.HELP, Flags.RUNNING_TESTSUITE, Flags.SHOW_VERSION, Flags.TARGET, Flags.GRAMMAR, Flags.ANNOTATION_VERSION, Flags.LANGUAGE_STANDARD, Flags.SHOW_ERROR_MESSAGES, Flags.SHOW_ANNOTATIONS, Flags.NO_SIMPLIFY, Flags.PRE_OPT_MODULES, Flags.CHEAPMATCHING_ALGORITHM, Flags.MATCHING_ALGORITHM, Flags.INDEX_REDUCTION_METHOD, Flags.POST_OPT_MODULES, Flags.SIMCODE_TARGET, Flags.ORDER_CONNECTIONS, Flags.TYPE_INFO, Flags.KEEP_ARRAYS, Flags.MODELICA_OUTPUT, Flags.SILENT, Flags.CORBA_SESSION, Flags.NUM_PROC, Flags.LATENCY, Flags.BANDWIDTH, Flags.INST_CLASS, Flags.VECTORIZATION_LIMIT, Flags.SIMULATION_CG, Flags.EVAL_PARAMS_IN_ANNOTATIONS, Flags.CHECK_MODEL, Flags.CEVAL_EQUATION, Flags.UNIT_CHECKING, Flags.TRANSLATE_DAE_STRING, Flags.GENERATE_LABELED_SIMCODE, Flags.REDUCE_TERMS, Flags.REDUCTION_METHOD, Flags.DEMO_MODE, Flags.LOCALE_FLAG, Flags.DEFAULT_OPENCL_DEVICE, Flags.MAXTRAVERSALS, Flags.DUMP_TARGET, Flags.DELAY_BREAK_LOOP, Flags.TEARING_METHOD, Flags.TEARING_HEURISTIC, Flags.SCALARIZE_MINMAX, Flags.STRICT, Flags.SCALARIZE_BINDINGS, Flags.CORBA_OBJECT_REFERENCE_FILE_PATH, Flags.HPCOM_SCHEDULER, Flags.HPCOM_CODE, Flags.REWRITE_RULES_FILE, Flags.REPLACE_HOMOTOPY, Flags.GENERATE_SYMBOLIC_JACOBIAN, Flags.GENERATE_SYMBOLIC_LINEARIZATION, Flags.INT_ENUM_CONVERSION, Flags.PROFILING_LEVEL, Flags.RESHUFFLE, Flags.GENERATE_DYN_OPTIMIZATION_PROBLEM, Flags.MAX_SIZE_FOR_SOLVE_LINIEAR_SYSTEM, Flags.CPP_FLAGS, Flags.REMOVE_SIMPLE_EQUATIONS, Flags.DYNAMIC_TEARING, Flags.SYM_SOLVER, Flags.LOOP2CON, Flags.FORCE_TEARING, Flags.SIMPLIFY_LOOPS, Flags.RTEARING, Flags.FLOW_THRESHOLD, Flags.MATRIX_FORMAT, Flags.PARTLINTORN, Flags.INIT_OPT_MODULES, Flags.MAX_MIXED_DETERMINED_INDEX, Flags.USE_LOCAL_DIRECTION, Flags.DEFAULT_OPT_MODULES_ORDERING, Flags.PRE_OPT_MODULES_ADD, Flags.PRE_OPT_MODULES_SUB, Flags.POST_OPT_MODULES_ADD, Flags.POST_OPT_MODULES_SUB, Flags.INIT_OPT_MODULES_ADD, Flags.INIT_OPT_MODULES_SUB, Flags.PERMISSIVE, Flags.HETS, Flags.DEFAULT_CLOCK_PERIOD, Flags.INST_CACHE_SIZE, Flags.MAX_SIZE_LINEAR_TEARING, Flags.MAX_SIZE_NONLINEAR_TEARING, Flags.NO_TEARING_FOR_COMPONENT, Flags.CT_STATE_MACHINES, Flags.DAE_MODE, Flags.INLINE_METHOD, Flags.SET_TEARING_VARS, Flags.SET_RESIDUAL_EQNS, Flags.IGNORE_COMMAND_LINE_OPTIONS_ANNOTATION, Flags.CALCULATE_SENSITIVITIES, Flags.ALARM, Flags.TOTAL_TEARING, Flags.IGNORE_SIMULATION_FLAGS_ANNOTATION, Flags.DYNAMIC_TEARING_FOR_INITIALIZATION, Flags.PREFER_TVARS_WITH_START_VALUE, Flags.EQUATIONS_PER_FILE, Flags.EVALUATE_FINAL_PARAMS, Flags.EVALUATE_PROTECTED_PARAMS, Flags.REPLACE_EVALUATED_PARAMS, Flags.CONDENSE_ARRAYS, Flags.WFC_ADVANCED, Flags.GRAPHICS_EXP_MODE, Flags.TEARING_STRICTNESS, Flags.INTERACTIVE, Flags.ZEROMQ_FILE_SUFFIX, Flags.HOMOTOPY_APPROACH, Flags.IGNORE_REPLACEABLE, Flags.LABELED_REDUCTION, Flags.DISABLE_EXTRA_LABELING, Flags.LOAD_MSL_MODEL, Flags.Load_PACKAGE_FILE, Flags.BUILDING_FMU, Flags.BUILDING_MODEL, Flags.POST_OPT_MODULES_DAE, Flags.EVAL_LOOP_LIMIT, Flags.EVAL_RECURSION_LIMIT, Flags.SINGLE_INSTANCE_AGLSOLVER, Flags.SHOW_STRUCTURAL_ANNOTATIONS, Flags.INITIAL_STATE_SELECTION, Flags.LINEARIZATION_DUMP_LANGUAGE, Flags.NO_ASSC, Flags.FULL_ASSC, Flags.USE_ZEROMQ_IN_SIM, Flags.ZEROMQ_PUB_PORT, Flags.ZEROMQ_SUB_PORT, Flags.ZEROMQ_JOB_ID, Flags.ZEROMQ_SERVER_ID, Flags.ZEROMQ_CLIENT_ID, Flags.FMI_VERSION, Flags.FLAT_MODELICA)::List

"""Create a new flags structure and read the given arguments."""
function new(inArgs::List{<:String})::List{String}
  local outArgs::List{String}
  _ = loadFlags()
  outArgs = readArgs(inArgs)
  outArgs
end

"""Saves the flags with setGlobalRoot."""
function saveFlags(inFlags::Flags.Flag)
  setGlobalRoot(Global.flagsIndex, inFlags)
end

function createConfigFlags() ::Array{Flags.FlagData}
  local configFlags::Array{Flags.FlagData}
  configFlags = listArray(list(flag.defaultValue for flag in allConfigFlags))
  configFlags
end

function createDebugFlags() ::Array{Bool}
  local debugFlags::Array{Bool}
  debugFlags = listArray(list(flag.default for flag in allDebugFlags))
  debugFlags
end

"""
  Loads the flags with getGlobalRoot. Creates a new flags structure if it
  hasn't been created yet.
"""
function loadFlags(initialize::Bool = true)::Flags.FLAGS
  local flags::Flags.Flag
  try
    flags = Flags.getFlags()
  catch
    if initialize
      checkDebugFlags()
      checkConfigFlags()
      flags = Flags.FLAGS(createDebugFlags(), createConfigFlags())
      saveFlags(flags)
    else
      @error("Failed loading Flags \n")
      flags = Flags.NO_FLAGS()
      fail()
    end
  end
  flags
end

"""Creates a copy of the existing flags."""
function backupFlags() ::Flags.Flag
  local outFlags::Flags.Flag
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}
  @match Flags.FLAGS(debug_flags, config_flags) = loadFlags()
  outFlags = Flags.FLAGS(arrayCopy(debug_flags), arrayCopy(config_flags))
  outFlags
end

"""Resets all debug flags to their default values."""
function resetDebugFlags()
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}

  @match Flags.FLAGS(_, config_flags) = loadFlags()
  debug_flags = createDebugFlags()
  saveFlags(Flags.FLAGS(debug_flags, config_flags))
end

"""Resets all configuration flags to their default values."""
function resetConfigFlags()
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}

  @match Flags.FLAGS(debug_flags, _) = loadFlags()
  config_flags = createConfigFlags()
  saveFlags(Flags.FLAGS(debug_flags, config_flags))
end

"""Checks that the flags listed in allDebugFlags have sequential and unique indices."""
function checkDebugFlags()
  local index::Int = 0
  local err_str::String

  for flag in allDebugFlags
    index = index + 1
    if flag.index != index
      err_str = "Invalid flag '" + flag.name + "' with index " + String(flag.index) + " (expected " + String(index) + ") in Flags.allDebugFlags. Make sure that all flags are present and ordered correctly!"
      #Error.terminateError(err_str, sourceInfo())
      println(err_str)
      println("Terminating...")
      fail()
    end
  end
  #=  If the flag indices are borked, print an error and terminate the compiler.
  =#
  #=  Only failing here could cause an infinite loop of trying to load the flags.
  =#
end

"""Checks that the flags listed in allConfigFlags have sequential and unique indices."""
function checkConfigFlags()
  local index::Int = 0
  local err_str::String

  for flag in allConfigFlags
    index = index + 1
    if flag.index != index
      err_str = "Invalid flag '" + flag.name + "' with index " + String(flag.index) + " (expected " + String(index) + ") in Flags.allConfigFlags. Make sure that all flags are present and ordered correctly!"
      @error err_str
      @error "Terminate error: Failing."
      fail()
      #Error.terminateError(err_str, sourceInfo())
    end
  end
  #=  If the flag indices are borked, print an error and terminate the compiler.
  =#
  #=  Only failing here could cause an infinite loop of trying to load the flags.
  =#
end

"""Sets the value of a debug flag, and returns the old value."""
function set(inFlag::Flags.DebugFlag, inValue::Bool) ::Bool
  local outOldValue::Bool
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}
  @match Flags.FLAGS(debug_flags, config_flags) = loadFlags()
  (debug_flags, outOldValue) = updateDebugFlagArray(debug_flags, inValue, inFlag)
  saveFlags(Flags.FLAGS(debug_flags, config_flags))
  outOldValue
end

"""Enables a debug flag."""
function enableDebug(inFlag::Flags.DebugFlag) ::Bool
  local outOldValue::Bool
  outOldValue = set(inFlag, true)
  outOldValue
end

"""Disables a debug flag."""
function disableDebug(inFlag::Flags.DebugFlag) ::Bool
  local outOldValue::Bool

  outOldValue = set(inFlag, false)
  outOldValue
end

"""Returns the valid options of a single-string configuration flag."""
function getConfigOptionsStringList(inFlag::Flags.ConfigFlag) ::Tuple{List{String}, List{String}}
  local outComments::List{String}
  local outOptions::List{String}

  (outOptions, outComments) = begin
    local options::List{Tuple{String, Gettext.TranslatableContent}}
    local flags::List{String}
    @match inFlag begin
      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_DESC_OPTION(options)))  => begin
        (ListUtil.map(options, Util.tuple21), ListUtil.mapMap(options, Util.tuple22, Gettext.translateContent))
      end

      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_OPTION(flags)))  => begin
        (flags, ListUtil.fill("", listLength(flags)))
      end
    end
  end
  (outOptions, outComments)
end

"""Updates the value of a debug flag in the debug flag array."""
function updateDebugFlagArray(inFlags::Array{<:Bool}, inValue::Bool, inFlag::Flags.DebugFlag) ::Tuple{Array{Bool}, Bool}
  local outOldValue::Bool
  local outFlags::Array{Bool}

  local index::Int

  @match Flags.DEBUG_FLAG(index = index) = inFlag
  outOldValue = arrayGet(inFlags, index)
  outFlags = arrayUpdate(inFlags, index, inValue)
  (outFlags, outOldValue)
end

"""Updates the value of a configuration flag in the configuration flag array."""
function updateConfigFlagArray(inFlags::Array{<:Flags.FlagData}, inValue::Flags.FlagData, inFlag::Flags.ConfigFlag) ::Array{Flags.FlagData}
  local outFlags::Array{Flags.FlagData}

  local index::Int

  @match Flags.CONFIG_FLAG(index = index) = inFlag
  outFlags = arrayUpdate(inFlags, index, inValue)
  applySideEffects(inFlag, inValue)
  outFlags
end

"""
  Reads the command line arguments to the compiler and sets the flags
  accordingly. Returns a list of arguments that were not consumed, such as the
  model filename.
"""
function readArgs(inArgs::List{<:String}) ::List{String}
  local outArgs::List{String} = nil
  local flags::Flags.Flag
  #local numError::Int
  local arg::String
  local rest_args::List{String} = inArgs

  #numError = Error.getNumErrorMessages() TODO fix this structure
  flags = loadFlags()
  while ! listEmpty(rest_args)
    @match _cons(arg, rest_args) = rest_args
    if arg == "--"
      break
    else
      if ! readArg(arg, flags)
        outArgs = _cons(arg, outArgs)
      end
    end
  end
  #=  Stop parsing arguments if -- is encountered.
  =#
  outArgs = ListUtil.append_reverse(outArgs, rest_args)
  _ = ListUtil.map2(outArgs, System.iconv, "UTF-8", "UTF-8")
  #Error.assertionOrAddSourceMessage(numError == Error.getNumErrorMessages(), Error.UTF8_COMMAND_LINE_ARGS, nil, Util.dummyInfo)
  saveFlags(flags)
  #=  after reading all flags, handle the deprecated ones =#
  handleDeprecatedFlags()
  outArgs
end

"""
  Reads a single command line argument. Returns true if the argument was
  consumed, otherwise false.
"""
function readArg(inArg::String, inFlags::Flags.Flag) ::Bool
  local outConsumed::Bool

  local flagtype::String
  local len::Int

  flagtype = stringGetStringChar(inArg, 1)
  len = stringLength(inArg)
  #=  Flags beginning with + can be both short and long, i.e. +h or +help.
  =#
  if flagtype == "+"
    if len == 1
      parseFlag(inArg, Flags.NO_FLAGS())
    else
      parseFlag(System.substring(inArg, 2, len), inFlags, flagtype)
    end
    outConsumed = true
  elseif flagtype == "-"
    if len == 1
      parseFlag(inArg, Flags.NO_FLAGS())
    elseif len == 2
      parseFlag(System.substring(inArg, 2, 2), inFlags, flagtype)
    elseif stringGetStringChar(inArg, 2) == "-"
      if len < 4 || stringGetStringChar(inArg, 4) == "="
        parseFlag(inArg, Flags.NO_FLAGS())
      else
        parseFlag(System.substring(inArg, 3, len), inFlags, "--")
      end
    else
      if stringGetStringChar(inArg, 3) == "="
        parseFlag(System.substring(inArg, 2, len), inFlags, flagtype)
      else
        parseFlag(inArg, Flags.NO_FLAGS())
      end
    end
    outConsumed = true
  else
    outConsumed = false
  end
  #=  + alone is not a valid flag.
  =#
  #=  Flags beginning with - must have another - for long flags, i.e. -h or --help.
  =#
  #=  - alone is not a valid flag.
  =#
  #=  Short flag without argument, i.e. -h.
  =#
  #=  Short flags may not be used with --, i.e. --h or --h=debug.
  =#
  #=  Long flag, i.e. --help or --help=debug.
  =#
  #=  Short flag with argument, i.e. -h=debug.
  =#
  #=  Long flag used with -, i.e. -help, which is not allowed.
  =#
  #=  Arguments that don't begin with + or - are not flags, ignore them.
  =#
  outConsumed
end

"""Parses a single flag."""
function parseFlag(inFlag::String, inFlags::Flags.Flag, inFlagPrefix::String = "")
  local flag::String
  local values::List{String}

  @match _cons(flag, values) = System.strtok(inFlag, "=")
  values = ListUtil.flatten(ListUtil.map1(values, System.strtok, ","))
  parseConfigFlag(flag, values, inFlags, inFlagPrefix)
end

"""Tries to look up the flag with the given name, and set it to the given value."""
function parseConfigFlag(inFlag::String, inValues::List{<:String}, inFlags::Flags.Flag, inFlagPrefix::String)
  local config_flag::Flags.ConfigFlag

  config_flag = lookupConfigFlag(inFlag, inFlagPrefix)
  evaluateConfigFlag(config_flag, inValues, inFlags)
end

"""Lookup up the flag with the given name in the list of configuration flags."""
function lookupConfigFlag(inFlag::String, inFlagPrefix::String) ::Flags.ConfigFlag
  local outFlag::Flags.ConfigFlag

  try
    outFlag = ListUtil.getMemberOnTrue(inFlag, allConfigFlags, matchConfigFlag)
  catch
    Error.addMessage(Error.UNKNOWN_OPTION, list(inFlagPrefix + inFlag))
    fail()
  end
  outFlag
end

function configFlagEq(inFlag1::Flags.ConfigFlag, inFlag2::Flags.ConfigFlag) ::Bool
  local eq::Bool

  eq = begin
    local index1::Int
    local index2::Int
    @match (inFlag1, inFlag2) begin
      (Flags.CONFIG_FLAG(index = index1), Flags.CONFIG_FLAG(index = index2))  => begin
        index1 == index2
      end
    end
  end
  eq
end

function setAdditionalOptModules(inFlag::Flags.ConfigFlag, inOppositeFlag::Flags.ConfigFlag, inValues::List{<:String})
  local values::List{String}

  for value in inValues
    values = Flags.getConfigStringList(inOppositeFlag)
    values = ListUtil.removeOnTrue(value, stringEq, values)
    setConfigStringList(inOppositeFlag, values)
    values = Flags.getConfigStringList(inFlag)
    values = ListUtil.removeOnTrue(value, stringEq, values)
    setConfigStringList(inFlag, _cons(value, values))
  end
  #=  remove value from inOppositeFlag
  =#
  #=  add value to inFlag
  =#
end

"""Evaluates a given flag and it's arguments."""
function evaluateConfigFlag(inFlag::Flags.ConfigFlag, inValues::List{<:String}, inFlags::Flags.Flag)
  _ = begin
    local debug_flags::Array{Bool}
    local config_flags::Array{Flags.FlagData}
    local values::List{String}
    #=  Special case for +d, +debug, set the given debug flags.
    =#
    @match (inFlag, inFlags) begin
      (Flags.CONFIG_FLAG(index = 1), Flags.FLAGS(debugFlags = debug_flags))  => begin
        ListUtil.map1_0(inValues, setDebugFlag, debug_flags)
        ()
      end

      (Flags.CONFIG_FLAG(index = 2), _)  => begin
        values = ListUtil.map(inValues, System.tolower)
        System.gettextInit(if Flags.getConfigString(Flags.RUNNING_TESTSUITE) == ""
                           Flags.getConfigString(Flags.LOCALE_FLAG)
                           else
                           "C"
                           end)
        print(printHelp(values))
        setConfigString(Flags.HELP, "omc")
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.PRE_OPT_MODULES_ADD))  => begin
        setAdditionalOptModules(Flags.PRE_OPT_MODULES_ADD, Flags.PRE_OPT_MODULES_SUB, inValues)
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.PRE_OPT_MODULES_SUB))  => begin
        setAdditionalOptModules(Flags.PRE_OPT_MODULES_SUB, Flags.PRE_OPT_MODULES_ADD, inValues)
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.POST_OPT_MODULES_ADD))  => begin
        setAdditionalOptModules(Flags.POST_OPT_MODULES_ADD, Flags.POST_OPT_MODULES_SUB, inValues)
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.POST_OPT_MODULES_SUB))  => begin
        setAdditionalOptModules(Flags.POST_OPT_MODULES_SUB, Flags.POST_OPT_MODULES_ADD, inValues)
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.INIT_OPT_MODULES_ADD))  => begin
        setAdditionalOptModules(Flags.INIT_OPT_MODULES_ADD, Flags.INIT_OPT_MODULES_SUB, inValues)
        ()
      end

      (_, _) where (configFlagEq(inFlag, Flags.INIT_OPT_MODULES_SUB))  => begin
        setAdditionalOptModules(Flags.INIT_OPT_MODULES_SUB, Flags.INIT_OPT_MODULES_ADD, inValues)
        ()
      end

      (_, Flags.FLAGS(configFlags = config_flags))  => begin
        setConfigFlag(inFlag, config_flags, inValues)
        ()
      end
    end
  end
  #=  Special case for +h, +help, show help text.
  =#
  #=  Special case for --preOptModules+=<value>
  =#
  #=  Special case for --preOptModules-=<value>
  =#
  #=  Special case for --postOptModules+=<value>
  =#
  #=  Special case for --postOptModules-=<value>
  =#
  #=  Special case for --initOptModules+=<value>
  =#
  #=  Special case for --initOptModules-=<value>
  =#
  #=  All other configuration flags, set the flag to the given values.
  =#
end

"""Enables a debug flag given as a string, or disables it if it's prefixed with -."""
function setDebugFlag(inFlag::String, inFlags::Array{<:Bool})
  local negated::Bool
  local neg1::Bool
  local neg2::Bool
  local flag_str::String

  neg1 = stringEq(stringGetStringChar(inFlag, 1), "-")
  neg2 = System.strncmp("no", inFlag, 2) == 0
  negated = neg1 || neg2
  flag_str = if negated
    Util.stringRest(inFlag)
  else
    inFlag
  end
  flag_str = if neg2
    Util.stringRest(flag_str)
  else
    flag_str
  end
  setDebugFlag2(flag_str, ! negated, inFlags)
end

function setDebugFlag2(inFlag::String, inValue::Bool, inFlags::Array{<:Bool})
  _ = begin
    local flag::Flags.DebugFlag
    @matchcontinue (inFlag, inValue, inFlags) begin
      (_, _, _)  => begin
        flag = ListUtil.getMemberOnTrue(inFlag, allDebugFlags, matchDebugFlag)
        (_, _) = updateDebugFlagArray(inFlags, inValue, flag)
        ()
      end

      _  => begin
        Error.addMessage(Error.UNKNOWN_DEBUG_FLAG, list(inFlag))
        fail()
      end
    end
  end
end

"""Returns true if the given flag has the given name, otherwise false."""
function matchDebugFlag(inFlagName::String, inFlag::Flags.DebugFlag) ::Bool
  local outMatches::Bool

  local name::String

  @match Flags.DEBUG_FLAG(name = name) = inFlag
  outMatches = stringEq(inFlagName, name)
  outMatches
end

"""Returns true if the given flag has the given name, otherwise false."""
function matchConfigFlag(inFlagName::String, inFlag::Flags.ConfigFlag) ::Bool
  local outMatches::Bool

  local opt_shortname::Option{String}
  local name::String
  local shortname::String

  #=  A configuration flag may have two names, one long and one short.
  =#
  @match Flags.CONFIG_FLAG(name = name, shortname = opt_shortname) = inFlag
  shortname = Util.getOptionOrDefault(opt_shortname, "")
  outMatches = stringEq(inFlagName, shortname) || stringEq(System.tolower(inFlagName), System.tolower(name))
  outMatches
end

"""
  Sets the value of a configuration flag, where the value is given as a list of
  strings.
"""
function setConfigFlag(inFlag::Flags.ConfigFlag, inConfigData::Array{<:Flags.FlagData}, inValues::List{<:String})
  local data::Flags.FlagData
  local default_value::Flags.FlagData
  local name::String
  local validOptions::Option{Flags.ValidOptions}

  @match Flags.CONFIG_FLAG(name = name, defaultValue = default_value, validOptions = validOptions) = inFlag
  data = stringFlagData(inValues, default_value, validOptions, name)
  _ = updateConfigFlagArray(inConfigData, data, inFlag)
end

"""
  Converts a list of strings into a FlagData value. The expected type is also
  given so that the value can be typechecked.
"""
function stringFlagData(inValues::List{<:String}, inExpectedType::Flags.FlagData, validOptions::Option{<:Flags.ValidOptions}, inName::String) ::Flags.FlagData
  local outValue::Flags.FlagData

  outValue = begin
    local b::Bool
    local i::Int
    local ilst::List{Integer}
    local s::String
    local et::String
    local at::String
    local enums::List{Tuple{String, Integer}}
    local flags::List{String}
    local slst::List{String}
    local options::Flags.ValidOptions
    #=  A boolean value.
    =#
    @matchcontinue (inValues, inExpectedType, validOptions, inName) begin
      (s <|  nil(), Flags.BOOL_FLAG(__), _, _)  => begin
        b = Util.stringBool(s)
        Flags.BOOL_FLAG(b)
      end

      ( nil(), Flags.BOOL_FLAG(__), _, _)  => begin
        Flags.BOOL_FLAG(true)
      end

      (s <|  nil(), Flags.INT_FLAG(__), _, _)  => begin
        i = stringInt(s)
        @match true = stringEq(intString(i), s)
        Flags.INT_FLAG(i)
      end

      (slst, Flags.INT_LIST_FLAG(__), _, _)  => begin
        ilst = ListUtil.map(slst, stringInt)
        Flags.INT_LIST_FLAG(ilst)
      end

      (s <|  nil(), Flags.REAL_FLAG(__), _, _)  => begin
        Flags.REAL_FLAG(System.stringReal(s))
      end

      (s <|  nil(), Flags.STRING_FLAG(__), SOME(options), _)  => begin
        flags = getValidStringOptions(options)
        @match true = listMember(s, flags)
        Flags.STRING_FLAG(s)
      end

      (s <|  nil(), Flags.STRING_FLAG(__), NONE(), _)  => begin
        Flags.STRING_FLAG(s)
      end

      (_, Flags.STRING_LIST_FLAG(__), _, _)  => begin
        Flags.STRING_LIST_FLAG(inValues)
      end

      (s <|  nil(), Flags.ENUM_FLAG(validValues = enums), _, _)  => begin
        i = Util.assoc(s, enums)
        Flags.ENUM_FLAG(i, enums)
      end

      (_, _, NONE(), _)  => begin
        et = printExpectedTypeStr(inExpectedType)
        at = printActualTypeStr(inValues)
        Error.addMessage(Error.INVALID_FLAG_TYPE, list(inName, et, at))
        fail()
      end

      (_, _, SOME(options), _)  => begin
        flags = getValidStringOptions(options)
        et = stringDelimitList(flags, ", ")
        at = printActualTypeStr(inValues)
        Error.addMessage(Error.INVALID_FLAG_TYPE_STRINGS, list(inName, et, at))
        fail()
      end
    end
  end
  #=  No value, but a boolean flag => enable the flag.
  =#
  #=  An integer value.
  =#
  #=  integer list.
  =#
  #=  A real value.
  =#
  #=  A string value.
  =#
  #=  A multiple-string value.
  =#
  #=  An enumeration value.
  =#
  #=  Type mismatch, print error.
  =#
  outValue
end

"""Prints the expected type as a string."""
function printExpectedTypeStr(inType::Flags.FlagData) ::String
  local outTypeStr::String

  outTypeStr = begin
    local enums::List{Tuple{String, Integer}}
    local enum_strs::List{String}
    @match inType begin
      Flags.BOOL_FLAG(__)  => begin
        "a boolean value"
      end

      Flags.INT_FLAG(__)  => begin
        "an integer value"
      end

      Flags.REAL_FLAG(__)  => begin
        "a floating-point value"
      end

      Flags.STRING_FLAG(__)  => begin
        "a string"
      end

      Flags.STRING_LIST_FLAG(__)  => begin
        "a comma-separated list of strings"
      end

      Flags.ENUM_FLAG(validValues = enums)  => begin
        enum_strs = ListUtil.map(enums, Util.tuple21)
        "one of the values {" + stringDelimitList(enum_strs, ", ") + "}"
      end
    end
  end
  outTypeStr
end

"""Prints the actual type as a string."""
function printActualTypeStr(inType::List{<:String}) ::String
  local outTypeStr::String

  outTypeStr = begin
    local s::String
    local i::Int
    @matchcontinue inType begin
      nil()  => begin
        "nothing"
      end

      s <|  nil()  => begin
        Util.stringBool(s)
        "the boolean value " + s
      end

      s <|  nil()  => begin
        i = stringInt(s)
        @match true = stringEq(intString(i), s)
        "the number " + intString(i)
      end

      s <|  nil()  => begin
        "the string \\" + s + "\\"
      end

      _  => begin
        "a list of values."
      end
    end
  end
  #=  intString returns 0 on failure, so this is to make sure that it
  =#
  #=  actually succeeded.
  =#
  #= case {s}
  =#
  #=   equation
  =#
  #=     System.stringReal(s);
  =#
  #=   then
  =#
  #=     \"the number \" + intString(i);
  =#
  outTypeStr
end

"""Checks if two config flags have the same index."""
function configFlagsIsEqualIndex(inFlag1::Flags.ConfigFlag, inFlag2::Flags.ConfigFlag) ::Bool
  local outEqualIndex::Bool

  local index1::Int
  local index2::Int

  @match Flags.CONFIG_FLAG(index = index1) = inFlag1
  @match Flags.CONFIG_FLAG(index = index2) = inFlag2
  outEqualIndex = intEq(index1, index2)
  outEqualIndex
end

"""
  Gives warnings when deprecated flags are used. Sets newer flags if
  appropriate.
"""
function handleDeprecatedFlags()
  local remaining_flags::List{String}

  #=  At some point in the future remove all these flags and do the checks in
  =#
  #=  parseConfigFlag or something like that...
  =#
  #=  DEBUG FLAGS
  =#
  if Flags.isSet(Flags.NF_UNITCHECK)
    disableDebug(Flags.NF_UNITCHECK)
    setConfigBool(Flags.UNIT_CHECKING, true)
    Error.addMessage(Error.DEPRECATED_FLAG, list("-d=frontEndUnitCheck", "--unitChecking"))
  end
  if Flags.isSet(Flags.OLD_FE_UNITCHECK)
    disableDebug(Flags.OLD_FE_UNITCHECK)
    setConfigBool(Flags.UNIT_CHECKING, true)
    Error.addMessage(Error.DEPRECATED_FLAG, list("-d=oldFrontEndUnitCheck", "--unitChecking"))
  end
  if Flags.isSet(Flags.INTERACTIVE_TCP)
    disableDebug(Flags.INTERACTIVE_TCP)
    setConfigString(Flags.INTERACTIVE, "tcp")
    Error.addMessage(Error.DEPRECATED_FLAG, list("-d=interactive", "--interactive=tcp"))
    print("The flag -d=interactive is depreciated. Please use --interactive=tcp instead.\\n")
  end
  #=  The error message might get lost, so also print it directly here.
  =#
  if Flags.isSet(Flags.INTERACTIVE_CORBA)
    disableDebug(Flags.INTERACTIVE_CORBA)
    setConfigString(Flags.INTERACTIVE, "corba")
    Error.addMessage(Error.DEPRECATED_FLAG, list("-d=interactiveCorba", "--interactive=corba"))
    print("The flag -d=interactiveCorba is depreciated. Please use --interactive=corba instead.\\n")
  end
  #=  The error message might get lost, so also print it directly here.
  =#
  #=  add other deprecated flags here...
  =#
  #=  CONFIG_FLAGS
  =#
  remaining_flags = nil
  for flag in Flags.getConfigStringList(Flags.PRE_OPT_MODULES)
    if flag == "unitChecking"
      setConfigBool(Flags.UNIT_CHECKING, true)
      Error.addMessage(Error.DEPRECATED_FLAG, list("--preOptModules=unitChecking", "--unitChecking"))
    else
      remaining_flags = _cons(flag, remaining_flags)
    end
  end
  #= elseif flag ==
  =#
  #=  add other deprecated flags here...
  =#
  setConfigStringList(Flags.PRE_OPT_MODULES, listReverse(remaining_flags))
  remaining_flags = nil
  for flag in Flags.getConfigStringList(Flags.PRE_OPT_MODULES_ADD)
    if flag == "unitChecking"
      setConfigBool(Flags.UNIT_CHECKING, true)
      Error.addMessage(Error.DEPRECATED_FLAG, list("--preOptModules+=unitChecking", "--unitChecking"))
    else
      remaining_flags = _cons(flag, remaining_flags)
    end
  end
  #= elseif flag ==
  =#
  #=  add other deprecated flags here...
  =#
  setConfigStringList(Flags.PRE_OPT_MODULES_ADD, listReverse(remaining_flags))
  #=  add other deprecated flags here...
  =#
end

"""Some flags have side effects, which are handled by this function."""
function applySideEffects(inFlag::Flags.ConfigFlag, inValue::Flags.FlagData)
  _ = begin
    local value::Bool
    local corba_name::String
    local corba_objid_path::String
    local zeroMQFileSuffix::String
    #=  +showErrorMessages needs to be sent to the C runtime.
    =#
    @matchcontinue (inFlag, inValue) begin
      (_, _)  => begin
        @match true = configFlagsIsEqualIndex(inFlag, Flags.SHOW_ERROR_MESSAGES)
        @match Flags.BOOL_FLAG(data = value) = inValue
        ErrorExt.setShowErrorMessages(value)
        ()
      end

      (_, _)  => begin
        @match true = configFlagsIsEqualIndex(inFlag, Flags.CORBA_OBJECT_REFERENCE_FILE_PATH)
        @match Flags.STRING_FLAG(data = corba_objid_path) = inValue
        Corba.setObjectReferenceFilePath(corba_objid_path)
        ()
      end

      (_, _)  => begin
        @match true = configFlagsIsEqualIndex(inFlag, Flags.CORBA_SESSION)
        @match Flags.STRING_FLAG(data = corba_name) = inValue
        Corba.setSessionName(corba_name)
        ()
      end

      _  => begin
        ()
      end
    end
  end
  #=  The corba object reference file path needs to be sent to the C runtime.
  =#
  #=  The corba session name needs to be sent to the C runtime.
  =#
end

"""Sets the value of a configuration flag."""
function setConfigValue(inFlag::Flags.ConfigFlag, inValue::Flags.FlagData)
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}
  local flags::Flags.Flag

  flags = loadFlags()
  @match Flags.FLAGS(debug_flags, config_flags) = flags
  config_flags = updateConfigFlagArray(config_flags, inValue, inFlag)
  saveFlags(Flags.FLAGS(debug_flags, config_flags))
end

"""Sets the value of a boolean configuration flag."""
function setConfigBool(inFlag::Flags.ConfigFlag, inValue::Bool)
  setConfigValue(inFlag, Flags.BOOL_FLAG(inValue))
end

"""Sets the value of an integer configuration flag."""
function setConfigInt(inFlag::Flags.ConfigFlag, inValue::Int)
  setConfigValue(inFlag, Flags.INT_FLAG(inValue))
end

"""Sets the value of a real configuration flag."""
function setConfigReal(inFlag::Flags.ConfigFlag, inValue::ModelicaReal)
  setConfigValue(inFlag, Flags.REAL_FLAG(inValue))
end

"""Sets the value of a string configuration flag."""
function setConfigString(inFlag::Flags.ConfigFlag, inValue::String)
  setConfigValue(inFlag, Flags.STRING_FLAG(inValue))
end

"""Sets the value of a multiple-string configuration flag."""
function setConfigStringList(inFlag::Flags.ConfigFlag, inValue::List{<:String})
  setConfigValue(inFlag, Flags.STRING_LIST_FLAG(inValue))
end

"""Sets the value of an enumeration configuration flag."""
function setConfigEnum(inFlag::Flags.ConfigFlag, inValue::Int)
  local valid_values::List{Tuple{String, Integer}}

  @match Flags.CONFIG_FLAG(defaultValue = Flags.ENUM_FLAG(validValues = valid_values)) = inFlag
  setConfigValue(inFlag, Flags.ENUM_FLAG(inValue, valid_values))
end

#=  Used by the print functions below to indent descriptions.
=#

const descriptionIndent = "                            "::String

"""Prints out help for the given list of topics."""
function printHelp(inTopics::List{<:String}) ::String
  local help::String

  help = begin
    local desc::Gettext.TranslatableContent
    local rest_topics::List{String}
    local strs::List{String}
    local data::List{String}
    local str::String
    local name::String
    local str1::String
    local str1a::String
    local str1b::String
    local str2::String
    local str3::String
    local str3a::String
    local str3b::String
    local str4::String
    local str5::String
    local str5a::String
    local str5b::String
    local str6::String
    local str7::String
    local str7a::String
    local str7b::String
    local str8::String
    local str9::String
    local str9a::String
    local str9b::String
    local str10::String
    local config_flag::Flags.ConfigFlag
    local topics::List{Tuple{String, String}}
    @matchcontinue inTopics begin
      nil()  => begin
        printUsage()
      end

      "omc" <|  nil()  => begin
        printUsage()
      end

      "omcall-sphinxoutput" <|  nil()  => begin
        printUsageSphinxAll()
      end

      "topics" <|  nil()  => begin
        topics = list(("omc", System.gettext("The command-line options available for omc.")), ("debug", System.gettext("Flags that enable debugging, diagnostics, and research prototypes.")), ("optmodules", System.gettext("Flags that determine which symbolic methods are used to produce the causalized equation system.")), ("simulation", System.gettext("The command-line options available for simulation executables generated by OpenModelica.")), ("<flagname>", System.gettext("Displays option descriptions for multi-option flag <flagname>.")), ("topics", System.gettext("This help-text.")))
        str = System.gettext("The available topics (help(\\topics\\)) are as follows:\\n")
        strs = ListUtil.map(topics, makeTopicString)
        help = str + stringDelimitList(strs, "\\n") + "\\n"
        help
      end

      "simulation" <|  nil()  => begin
        help = System.gettext("The simulation executable takes the following flags:\\n\\n") + System.getSimulationHelpText(true)
        help
      end

      "simulation-sphinxoutput" <|  nil()  => begin
        help = System.gettext("The simulation executable takes the following flags:\\n\\n") + System.getSimulationHelpText(true, sphinx = true)
        help
      end

      "debug" <|  nil()  => begin
        str1 = System.gettext("The debug flag takes a comma-separated list of flags which are used by the\\ncompiler for debugging or experimental purposes.\\nFlags prefixed with \\-\\ or \\no\\ will be disabled.\\n")
        str2 = System.gettext("The available flags are (+ are enabled by default, - are disabled):\\n\\n")
        strs = list(printDebugFlag(flag) for flag in ListUtil.sort(allDebugFlags, compareDebugFlags))
        help = stringAppendList(_cons(str1, _cons(str2, strs)))
        help
      end

      "optmodules" <|  nil()  => begin
        str1 = System.gettext("The --preOptModules flag sets the optimization modules which are used before the\\nmatching and index reduction in the back end. These modules are specified as a comma-separated list.")
        str1 = stringAppendList(StringUtil.wordWrap(str1, System.getTerminalWidth(), "\\n"))
        @match Flags.CONFIG_FLAG(defaultValue = Flags.STRING_LIST_FLAG(data = data)) = Flags.PRE_OPT_MODULES
        str1a = System.gettext("The modules used by default are:") + "\\n--preOptModules=" + stringDelimitList(data, ",")
        str1b = System.gettext("The valid modules are:")
        str2 = printFlagValidOptionsDesc(Flags.PRE_OPT_MODULES)
        str3 = System.gettext("The --matchingAlgorithm sets the method that is used for the matching algorithm, after the pre optimization modules.")
        str3 = stringAppendList(StringUtil.wordWrap(str3, System.getTerminalWidth(), "\\n"))
        @match Flags.CONFIG_FLAG(defaultValue = Flags.STRING_FLAG(data = str3a)) = Flags.MATCHING_ALGORITHM
        str3a = System.gettext("The method used by default is:") + "\\n--matchingAlgorithm=" + str3a
        str3b = System.gettext("The valid methods are:")
        str4 = printFlagValidOptionsDesc(Flags.MATCHING_ALGORITHM)
        str5 = System.gettext("The --indexReductionMethod sets the method that is used for the index reduction, after the pre optimization modules.")
        str5 = stringAppendList(StringUtil.wordWrap(str5, System.getTerminalWidth(), "\\n"))
        @match Flags.CONFIG_FLAG(defaultValue = Flags.STRING_FLAG(data = str5a)) = Flags.INDEX_REDUCTION_METHOD
        str5a = System.gettext("The method used by default is:") + "\\n--indexReductionMethod=" + str5a
        str5b = System.gettext("The valid methods are:")
        str6 = printFlagValidOptionsDesc(Flags.INDEX_REDUCTION_METHOD)
        str7 = System.gettext("The --initOptModules then sets the optimization modules which are used after the index reduction to optimize the system for initialization, specified as a comma-separated list.")
        str7 = stringAppendList(StringUtil.wordWrap(str7, System.getTerminalWidth(), "\\n"))
        @match Flags.CONFIG_FLAG(defaultValue = Flags.STRING_LIST_FLAG(data = data)) = Flags.INIT_OPT_MODULES
        str7a = System.gettext("The modules used by default are:") + "\\n--initOptModules=" + stringDelimitList(data, ",")
        str7b = System.gettext("The valid modules are:")
        str8 = printFlagValidOptionsDesc(Flags.INIT_OPT_MODULES)
        str9 = System.gettext("The --postOptModules then sets the optimization modules which are used after the index reduction to optimize the system for simulation, specified as a comma-separated list.")
        str9 = stringAppendList(StringUtil.wordWrap(str9, System.getTerminalWidth(), "\\n"))
        @match Flags.CONFIG_FLAG(defaultValue = Flags.STRING_LIST_FLAG(data = data)) = Flags.POST_OPT_MODULES
        str9a = System.gettext("The modules used by default are:") + "\\n--postOptModules=" + stringDelimitList(data, ",")
        str9b = System.gettext("The valid modules are:")
        str10 = printFlagValidOptionsDesc(Flags.POST_OPT_MODULES)
        help = stringAppendList(list(str1, "\\n\\n", str1a, "\\n\\n", str1b, "\\n", str2, "\\n", str3, "\\n\\n", str3a, "\\n\\n", str3b, "\\n", str4, "\\n", str5, "\\n\\n", str5a, "\\n\\n", str5b, "\\n", str6, "\\n", str7, "\\n\\n", str7a, "\\n\\n", str7b, "\\n", str8, "\\n", str9, "\\n\\n", str9a, "\\n\\n", str9b, "\\n", str10, "\\n"))
        help
      end

      str <|  nil()  => begin
        config_flag = ListUtil.getMemberOnTrue(str, allConfigFlags, matchConfigFlag)
        @match Flags.CONFIG_FLAG(name = name, description = desc) = config_flag
        str1 = "-" + name
        str2 = stringAppendList(StringUtil.wordWrap(Gettext.translateContent(desc), System.getTerminalWidth(), "\\n"))
        str = printFlagValidOptionsDesc(config_flag)
        help = stringAppendList(list(str1, "\\n", str2, "\\n", str))
        help
      end

      str <|  nil()  => begin
        "I'm sorry, I don't know what " + str + " is.\\n"
      end

      str <| rest_topics && _ <| _  => begin
        str = printHelp(list(str)) + "\\n"
        help = printHelp(rest_topics)
        str + help
      end
    end
  end
  #= case {\"mos\"} then System.gettext(\"TODO: Write help-text\");
  =#
  #= (\"mos\",System.gettext(\"Help on the command-line and scripting environments, including OMShell and OMNotebook.\")),
  =#
  #=  pre-optimization
  =#
  #=  matching
  =#
  #=  index reduction
  =#
  #=  post-optimization (initialization)
  =#
  #=  post-optimization (simulation)
  =#
  help
end

function getValidOptionsAndDescription(flagName::String) ::Tuple{List{String}, String, List{String}}
  local descriptions::List{String}
  local mainDescriptionStr::String
  local validStrings::List{String}

  local validOptions::Flags.ValidOptions
  local mainDescription::Gettext.TranslatableContent

  @match Flags.CONFIG_FLAG(description = mainDescription, validOptions = SOME(validOptions)) = ListUtil.getMemberOnTrue(flagName, allConfigFlags, matchConfigFlag)
  mainDescriptionStr = Gettext.translateContent(mainDescription)
  (validStrings, descriptions) = getValidOptionsAndDescription2(validOptions)
  (validStrings, mainDescriptionStr, descriptions)
end

function getValidOptionsAndDescription2(validOptions::Flags.ValidOptions) ::Tuple{List{String}, List{String}}
  local descriptions::List{String}
  local validStrings::List{String}

  (validStrings, descriptions) = begin
    local options::List{Tuple{String, Gettext.TranslatableContent}}
    @match validOptions begin
      Flags.STRING_OPTION(validStrings)  => begin
        (validStrings, nil)
      end

      Flags.STRING_DESC_OPTION(options)  => begin
        validStrings = ListUtil.map(options, Util.tuple21)
        descriptions = ListUtil.mapMap(options, Util.tuple22, Gettext.translateContent)
        (validStrings, descriptions)
      end
    end
  end
  (validStrings, descriptions)
end

function compareDebugFlags(flag1::Flags.DebugFlag, flag2::Flags.DebugFlag) ::Bool
  local b::Bool

  local name1::String
  local name2::String

  @match Flags.DEBUG_FLAG(name = name1) = flag1
  @match Flags.DEBUG_FLAG(name = name2) = flag2
  b = stringCompare(name1, name2) > 0
  b
end

function makeTopicString(topic::Tuple{<:String, String}) ::String
  local str::String

  local str1::String
  local str2::String

  (str1, str2) = topic
  str1 = Util.stringPadRight(str1, 13, " ")
  str = stringAppendList(StringUtil.wordWrap(str1 + str2, System.getTerminalWidth(), "\\n               "))
  str
end

"""Prints out the usage text for the compiler."""
function printUsage() ::String
  local usage::String

  Print.clearBuf()
  Print.printBuf("OpenModelica Compiler ")
  Print.printBuf(Settings.getVersionNr())
  Print.printBuf("\\n")
  Print.printBuf(System.gettext("Copyright © 2019 Open Source Modelica Consortium (OSMC)\\n"))
  Print.printBuf(System.gettext("Distributed under OMSC-PL and GPL, see www.openmodelica.org\\n\\n"))
  #= Print.printBuf(\"Please check the System Guide for full information about flags.\\n\");
  =#
  Print.printBuf(System.gettext("Usage: omc [Options] (Model.mo | Script.mos) [Libraries | .mo-files] \\n* Libraries: Fully qualified names of libraries to load before processing Model or Script.\\n             The libraries should be separated by spaces: Lib1 Lib2 ... LibN.\\n"))
  Print.printBuf(System.gettext("\\n* Options:\\n"))
  Print.printBuf(printAllConfigFlags())
  Print.printBuf(System.gettext("\\nFor more details on a specific topic, use --help=topics or help(\\topics\\)\\n\\n"))
  Print.printBuf(System.gettext("* Examples:\\n"))
  Print.printBuf(System.gettext("  omc Model.mo             will produce flattened Model on standard output.\\n"))
  Print.printBuf(System.gettext("  omc -s Model.mo          will produce simulation code for the model:\\n"))
  Print.printBuf(System.gettext("                            * Model.c           The model C code.\\n"))
  Print.printBuf(System.gettext("                            * Model_functions.c The model functions C code.\\n"))
  Print.printBuf(System.gettext("                            * Model.makefile    The makefile to compile the model.\\n"))
  Print.printBuf(System.gettext("                            * Model_init.xml    The initial values.\\n"))
  #= Print.printBuf(\"\\tomc Model.mof            will produce flattened Model on standard output\\n\");
  =#
  Print.printBuf(System.gettext("  omc Script.mos           will run the commands from Script.mos.\\n"))
  Print.printBuf(System.gettext("  omc Model.mo Modelica    will first load the Modelica library and then produce \\n                            flattened Model on standard output.\\n"))
  Print.printBuf(System.gettext("  omc Model1.mo Model2.mo  will load both Model1.mo and Model2.mo, and produce \\n                            flattened Model1 on standard output.\\n"))
  Print.printBuf(System.gettext("  *.mo (Modelica files) \\n"))
  #= Print.printBuf(\"\\t*.mof (Flat Modelica files) \\n\");
  =#
  Print.printBuf(System.gettext("  *.mos (Modelica Script files)\\n\\n"))
  Print.printBuf(System.gettext("For available simulation flags, use --help=simulation.\\n\\n"))
  Print.printBuf(System.gettext("Documentation is available in the built-in package OpenModelica.Scripting or\\nonline <https://build.openmodelica.org/Documentation/OpenModelica.Scripting.html>.\\n"))
  usage = Print.getString()
  Print.clearBuf()
  usage
end

"""Prints out the usage text for the compiler."""
function printUsageSphinxAll() ::String
  local usage::String

  local s::String

  Print.clearBuf()
  s = "OpenModelica Compiler Flags"
  Print.printBuf(s)
  Print.printBuf("\\n")
  Print.printBuf(sum("=" for e in 1:stringLength(s)))
  Print.printBuf("\\n")
  Print.printBuf(System.gettext("Usage: omc [Options] (Model.mo | Script.mos) [Libraries | .mo-files]\\n\\n* Libraries: Fully qualified names of libraries to load before processing Model or Script.\\n  The libraries should be separated by spaces: Lib1 Lib2 ... LibN.\\n"))
  Print.printBuf("\\n.. _omcflags-options :\\n\\n")
  s = System.gettext("Options")
  Print.printBuf(s)
  Print.printBuf("\\n")
  Print.printBuf(sum("-" for e in 1:stringLength(s)))
  Print.printBuf("\\n\\n")
  for flag in allConfigFlags
    Print.printBuf(printConfigFlagSphinx(flag))
  end
  Print.printBuf("\\n.. _omcflag-debug-section:\\n\\n")
  s = System.gettext("Debug flags")
  Print.printBuf(s)
  Print.printBuf("\\n")
  Print.printBuf(sum("-" for e in 1:stringLength(s)))
  Print.printBuf("\\n\\n")
  Print.printBuf(System.gettext("The debug flag takes a comma-separated list of flags which are used by the\\ncompiler for debugging or experimental purposes.\\nFlags prefixed with \\-\\ or \\no\\ will be disabled.\\n"))
  Print.printBuf(System.gettext("The available flags are (+ are enabled by default, - are disabled):\\n\\n"))
  for flag in ListUtil.sort(allDebugFlags, compareDebugFlags)
    Print.printBuf(printDebugFlag(flag, sphinx = true))
  end
  Print.printBuf("\\n.. _omcflag-optmodules-section:\\n\\n")
  s = System.gettext("Flags for Optimization Modules")
  Print.printBuf(s)
  Print.printBuf("\\n")
  Print.printBuf(sum("-" for e in 1:stringLength(s)))
  Print.printBuf("\\n\\n")
  Print.printBuf("Flags that determine which symbolic methods are used to produce the causalized equation system.\\n\\n")
  Print.printBuf(System.gettext("The :ref:`--preOptModules <omcflag-preOptModules>` flag sets the optimization modules which are used before the\\nmatching and index reduction in the back end. These modules are specified as a comma-separated list."))
  Print.printBuf("\\n\\n")
  Print.printBuf(System.gettext("The :ref:`--matchingAlgorithm <omcflag-matchingAlgorithm>` sets the method that is used for the matching algorithm, after the pre optimization modules."))
  Print.printBuf("\\n\\n")
  Print.printBuf(System.gettext("The :ref:`--indexReductionMethod <omcflag-indexReductionMethod>` sets the method that is used for the index reduction, after the pre optimization modules."))
  Print.printBuf("\\n\\n")
  Print.printBuf(System.gettext("The :ref:`--initOptModules <omcflag-initOptModules>` then sets the optimization modules which are used after the index reduction to optimize the system for initialization, specified as a comma-separated list."))
  Print.printBuf("\\n\\n")
  Print.printBuf(System.gettext("The :ref:`--postOptModules <omcflag-postOptModules>` then sets the optimization modules which are used after the index reduction to optimize the system for simulation, specified as a comma-separated list."))
  Print.printBuf("\\n\\n")
  usage = Print.getString()
  Print.clearBuf()
  usage
end

"""Prints all configuration flags to a string."""
function printAllConfigFlags() ::String
  local outString::String

  outString = stringAppendList(ListUtil.map(allConfigFlags, printConfigFlag))
  outString
end

"""Prints a configuration flag to a string."""
function printConfigFlag(inFlag::Flags.ConfigFlag) ::String
  local outString::String

  outString = begin
    local desc::Gettext.TranslatableContent
    local name::String
    local desc_str::String
    local flag_str::String
    local delim_str::String
    local opt_str::String
    local wrapped_str::List{String}
    @match inFlag begin
      Flags.CONFIG_FLAG(visibility = Flags.INTERNAL(__))  => begin
        ""
      end

      Flags.CONFIG_FLAG(description = desc)  => begin
        desc_str = Gettext.translateContent(desc)
        name = Util.stringPadRight(printConfigFlagName(inFlag), 28, " ")
        flag_str = stringAppendList(list(name, " ", desc_str))
        delim_str = descriptionIndent + "  "
        wrapped_str = StringUtil.wordWrap(flag_str, System.getTerminalWidth(), delim_str)
        opt_str = printValidOptions(inFlag)
        flag_str = stringDelimitList(wrapped_str, "\\n") + opt_str + "\\n"
        flag_str
      end
    end
  end
  outString
end

"""Prints a configuration flag to a restructured text string."""
function printConfigFlagSphinx(inFlag::Flags.ConfigFlag) ::String
  local outString::String

  outString = begin
    local desc::Gettext.TranslatableContent
    local name::String
    local longName::String
    local desc_str::String
    local flag_str::String
    local delim_str::String
    local opt_str::String
    local wrapped_str::List{String}
    @match inFlag begin
      Flags.CONFIG_FLAG(visibility = Flags.INTERNAL(__))  => begin
        ""
      end

      Flags.CONFIG_FLAG(description = desc)  => begin
        desc_str = Gettext.translateContent(desc)
        desc_str = System.stringReplace(desc_str, "--help=debug", ":ref:`--help=debug <omcflag-debug-section>`")
        desc_str = System.stringReplace(desc_str, "--help=optmodules", ":ref:`--help=optmodules <omcflag-optmodules-section>`")
        (name, longName) = printConfigFlagName(inFlag, sphinx = true)
        opt_str = printValidOptionsSphinx(inFlag)
        flag_str = stringAppendList(list(".. _omcflag-", longName, ":\\n\\n:ref:`", name, "<omcflag-", longName, ">`\\n\\n", desc_str, "\\n", opt_str + "\\n"))
        flag_str
      end
    end
  end
  outString
end

"""
  Prints out the name of a configuration flag, formatted for use by
  printConfigFlag.
"""
function printConfigFlagName(inFlag::Flags.ConfigFlag, sphinx::Bool = false) ::Tuple{String, String}
  local longName::String
  local outString::String

  (outString, longName) = begin
    local name::String
    local shortname::String
    @match inFlag begin
      Flags.CONFIG_FLAG(name = name, shortname = SOME(shortname))  => begin
        shortname = if sphinx
          "-" + shortname
        else
          Util.stringPadLeft("-" + shortname, 4, " ")
        end
        (stringAppendList(list(shortname, ", --", name)), name)
      end

      Flags.CONFIG_FLAG(name = name, shortname = NONE())  => begin
        ((if sphinx
          "--"
          else
          "      --"
          end) + name, name)
      end
    end
  end
  (outString, longName)
end

"""Prints out the valid options of a configuration flag to a string."""
function printValidOptions(inFlag::Flags.ConfigFlag) ::String
  local outString::String

  outString = begin
    local strl::List{String}
    local opt_str::String
    local descl::List{Tuple{String, Gettext.TranslatableContent}}
    @match inFlag begin
      Flags.CONFIG_FLAG(validOptions = NONE())  => begin
        ""
      end

      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_OPTION(options = strl)))  => begin
        opt_str = descriptionIndent + "   " + System.gettext("Valid options:") + " " + stringDelimitList(strl, ", ")
        strl = StringUtil.wordWrap(opt_str, System.getTerminalWidth(), descriptionIndent + "     ")
        opt_str = stringDelimitList(strl, "\\n")
        opt_str = "\\n" + opt_str
        opt_str
      end

      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_DESC_OPTION(options = descl)))  => begin
        opt_str = "\\n" + descriptionIndent + "   " + System.gettext("Valid options:") + "\\n" + stringAppendList(list(printFlagOptionDescShort(d) for d in descl))
        opt_str
      end
    end
  end
  outString
end

"""Prints out the valid options of a configuration flag to a string."""
function printValidOptionsSphinx(inFlag::Flags.ConfigFlag) ::String
  local outString::String

  outString = begin
    local strl::List{String}
    local opt_str::String
    local descl::List{Tuple{String, Gettext.TranslatableContent}}
    @match inFlag begin
      Flags.CONFIG_FLAG(validOptions = NONE())  => begin
        "\\n" + defaultFlagSphinx(inFlag.defaultValue) + "\\n"
      end

      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_OPTION(options = strl)))  => begin
        opt_str = "\\n" + defaultFlagSphinx(inFlag.defaultValue) + " " + System.gettext("Valid options") + ":\\n\\n" + sum("* " + s + "\\n" for s in strl)
        opt_str
      end

      Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_DESC_OPTION(options = descl)))  => begin
        opt_str = "\\n" + defaultFlagSphinx(inFlag.defaultValue) + " " + System.gettext("Valid options") + ":\\n\\n" + sum(printFlagOptionDesc(s, sphinx = true) for s in descl)
        opt_str
      end
    end
  end
  outString
end

function defaultFlagSphinx(flag::Flags.FlagData) ::String
  local str::String

  str = begin
    local i::Int
    @match flag begin
      Flags.BOOL_FLAG(__)  => begin
        System.gettext("Boolean (default") + " ``" + boolString(flag.data) + "``)."
      end

      Flags.INT_FLAG(__)  => begin
        System.gettext("Integer (default") + " ``" + intString(flag.data) + "``)."
      end

      Flags.REAL_FLAG(__)  => begin
        System.gettext("Real (default") + " ``" + realString(flag.data) + "``)."
      end

      Flags.STRING_FLAG("")  => begin
        System.gettext("String (default *empty*).")
      end

      Flags.STRING_FLAG(__)  => begin
        System.gettext("String (default") + " " + flag.data + ")."
      end

      Flags.STRING_LIST_FLAG(data =  nil())  => begin
        System.gettext("String list (default *empty*).")
      end

      Flags.STRING_LIST_FLAG(__)  => begin
        System.gettext("String list (default") + " " + stringDelimitList(flag.data, ",") + ")."
      end

      Flags.ENUM_FLAG(__)  => begin
        for f in flag.validValues
          (str, i) = f
          if i == flag.data
            str = System.gettext("String (default ") + " " + str + ")."
            return
          end
        end
        "#ENUM_FLAG Failed#" + anyString(flag)
      end

      _  => begin
        "Unknown default value" + anyString(flag)
      end
    end
  end
  str
end

"""Prints out the name of a flag option."""
function printFlagOptionDescShort(inOption::Tuple{<:String, Gettext.TranslatableContent}, sphinx::Bool = false) ::String
  local outString::String

  local name::String

  (name, _) = inOption
  outString = (if sphinx
               "* "
               else
               descriptionIndent + "    * "
               end) + name + "\\n"
  outString
end

"""
  Prints out the names and descriptions of the valid options for a
  configuration flag.
"""
function printFlagValidOptionsDesc(inFlag::Flags.ConfigFlag) ::String
  local outString::String

  local options::List{Tuple{String, Gettext.TranslatableContent}}

  @match Flags.CONFIG_FLAG(validOptions = SOME(Flags.STRING_DESC_OPTION(options = options))) = inFlag
  outString = sum(printFlagOptionDesc(o) for o in options)
  outString
end

function sphinxMathMode(s::String) ::String
  local o::String = s

  local i::Int
  local strs::List{String}
  local s1::String
  local s2::String
  local s3::String

  (i, strs) = System.regex(o, "^(.*)[]([^]*)[](.*)", 4, extended = true)
  if i == 4
    @match _cons(_, _cons(s1, _cons(s2, _cons(s3, _)))) = strs
    o = s1 + " :math:`" + s2 + "` " + s3
  end
  o
end

function removeSphinxMathMode(s::String) ::String
  local o::String = s

  local i::Int
  local strs::List{String}
  local s1::String
  local s2::String
  local s3::String

  (i, strs) = System.regex(o, "^(.*):math:`([^`]*)[`](.*)", 4, extended = true)
  if i == 4
    o = removeSphinxMathMode(stringAppendList(listRest(strs)))
  end
  o
end

"""Helper function to printFlagValidOptionsDesc."""
function printFlagOptionDesc(inOption::Tuple{<:String, Gettext.TranslatableContent}, sphinx::Bool = false) ::String
  local outString::String

  local desc::Gettext.TranslatableContent
  local name::String
  local desc_str::String
  local str::String

  (name, desc) = inOption
  desc_str = Gettext.translateContent(desc)
  if sphinx
    desc_str = sum(System.trim(s) for s in System.strtok(desc_str, "\\n"))
    outString = "* " + name + " (" + desc_str + ")\\n"
  else
    str = Util.stringPadRight(" * " + name + " ", 30, " ") + removeSphinxMathMode(desc_str)
    outString = stringDelimitList(StringUtil.wordWrap(str, System.getTerminalWidth(), descriptionIndent + "    "), "\\n") + "\\n"
  end
  outString
end

"""Prints out name and description of a debug flag."""
function printDebugFlag(inFlag::Flags.DebugFlag, sphinx::Bool = false) ::String
  local outString::String

  local desc::Gettext.TranslatableContent
  local name::String
  local desc_str::String
  local default::Bool

  @match Flags.DEBUG_FLAG(default = default, name = name, description = desc) = inFlag
  desc_str = Gettext.translateContent(desc)
  if sphinx
    desc_str = stringDelimitList(list(System.trim(s) for s in System.strtok(desc_str, "\\n")), "\\n  ")
    outString = "\\n.. _omcflag-debug-" + name + ":\\n\\n" + ":ref:`" + name + " <omcflag-debug-" + name + ">`" + " (default: " + (if default
                                                                                                                                   "on"
                                                                                                                                   else
                                                                                                                                   "off"
                                                                                                                                   end) + ")\\n  " + desc_str + "\\n"
  else
    outString = Util.stringPadRight((if default
                                     " + "
                                     else
                                     " - "
                                     end) + name + " ", 26, " ") + removeSphinxMathMode(desc_str)
    outString = stringDelimitList(StringUtil.wordWrap(outString, System.getTerminalWidth(), descriptionIndent), "\\n") + "\\n"
  end
  outString
end

"""Prints out name of a debug flag."""
function debugFlagName(inFlag::Flags.DebugFlag) ::String
  local name::String

  @match Flags.DEBUG_FLAG(name = name) = inFlag
  name
end

"""Prints out name of a debug flag."""
function configFlagName(inFlag::Flags.ConfigFlag) ::String
  local name::String

  @match Flags.CONFIG_FLAG(name = name) = inFlag
  name
end

function getValidStringOptions(inOptions::Flags.ValidOptions) ::List{String}
  local validOptions::List{String}

  validOptions = begin
    local options::List{Tuple{String, Gettext.TranslatableContent}}
    @match inOptions begin
      Flags.STRING_OPTION(validOptions)  => begin
        validOptions
      end

      Flags.STRING_DESC_OPTION(options)  => begin
        ListUtil.map(options, Util.tuple21)
      end
    end
  end
  validOptions
end

function flagDataEq(data1::Flags.FlagData, data2::Flags.FlagData) ::Bool
  local eq::Bool

  eq = begin
    @match (data1, data2) begin
      (Flags.EMPTY_FLAG(__), Flags.EMPTY_FLAG(__))  => begin
        true
      end

      (Flags.BOOL_FLAG(__), Flags.BOOL_FLAG(__))  => begin
        data1.data == data2.data
      end

      (Flags.INT_FLAG(__), Flags.INT_FLAG(__))  => begin
        data1.data == data2.data
      end

      (Flags.INT_LIST_FLAG(__), Flags.INT_LIST_FLAG(__))  => begin
        ListUtil.isEqualOnTrue(data1.data, data2.data, intEq)
      end

      (Flags.REAL_FLAG(__), Flags.REAL_FLAG(__))  => begin
        data1.data == data2.data
      end

      (Flags.STRING_FLAG(__), Flags.STRING_FLAG(__))  => begin
        data1.data == data2.data
      end

      (Flags.STRING_LIST_FLAG(__), Flags.STRING_LIST_FLAG(__))  => begin
        ListUtil.isEqualOnTrue(data1.data, data2.data, stringEq)
      end

      (Flags.ENUM_FLAG(__), Flags.ENUM_FLAG(__))  => begin
        referenceEq(data1.validValues, data2.validValues) && data1.data == data2.data
      end

      _  => begin
        false
      end
    end
  end
  eq
end

function flagDataString(flagData::Flags.FlagData) ::String
  local str::String

  str = begin
    @match flagData begin
      Flags.BOOL_FLAG(__)  => begin
        boolString(flagData.data)
      end

      Flags.INT_FLAG(__)  => begin
        intString(flagData.data)
      end

      Flags.INT_LIST_FLAG(__)  => begin
        ListUtil.toString(flagData.data, intString, "", "", ",", "", false)
      end

      Flags.REAL_FLAG(__)  => begin
        realString(flagData.data)
      end

      Flags.STRING_FLAG(__)  => begin
        flagData.data
      end

      Flags.STRING_LIST_FLAG(__)  => begin
        stringDelimitList(flagData.data, ",")
      end

      Flags.ENUM_FLAG(__)  => begin
        Util.tuple21(listGet(flagData.validValues, flagData.data))
      end

      _  => begin
        ""
      end
    end
  end
  str
end

"""
  Goes through all the existing flags, and returns a list of all flags with
  values that differ from the default. The format of each string is flag=value.
"""
function unparseFlags() ::List{String}
  local flagStrings::List{String} = nil

  local flags::Flags.Flag
  local debug_flags::Array{Bool}
  local config_flags::Array{Flags.FlagData}
  local name::String
  local strl::List{String} = nil

  try
    @match Flags.FLAGS(debugFlags = debug_flags, configFlags = config_flags) = loadFlags(false)
  catch
    return flagStrings
  end
  for f in allConfigFlags
    if ! flagDataEq(f.defaultValue, config_flags[f.index])
      name = begin
        @match f.shortname begin
          SOME(name)  => begin
            "-" + name
          end

          _  => begin
            "--" + f.name
          end
        end
      end
      flagStrings = _cons(name + "=" + flagDataString(config_flags[f.index]), flagStrings)
    end
  end
  for f in allDebugFlags
    if f.default != debug_flags[f.index]
      strl = _cons(f.name, strl)
    end
  end
  if ! listEmpty(strl)
    flagStrings = _cons("-d=" + stringDelimitList(strl, ","), flagStrings)
  end
  flagStrings
end

#= So that we can use wildcard imports and named imports when they do occur. Not good Julia practice =#
@exportAll()
end
