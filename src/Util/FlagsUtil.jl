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

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
#= ExportAll is not good practice but it makes it so that we do not have to write export after each function :( =#
using ExportAll

import ..Flags
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
"""
All debug flags, by index: a flag is used only through this list, and `checkDebugFlags` checks at initialization
that each entry's index is its position.
"""
const allDebugFlags = list(
  Flags.FAILTRACE,
  Flags.EVAL_PARAM,
  Flags.EXEC_STAT,
  Flags.CGRAPH,
  Flags.INLINE_FUNCTIONS,
  Flags.DISABLE_SINGLE_FLOW_EQ,
  Flags.INFO_XML_OPERATIONS,
  Flags.VISUAL_XML,
  Flags.FRONTEND_SCALARIZE,
  Flags.NF_EVAL_CONST_ARG_FUNCS,
  Flags.NF_EXPAND_OPERATIONS,
  Flags.NF_API,
  Flags.NF_API_DYNAMIC_SELECT,
  Flags.NF_EXPAND_FUNC_ARGS,
  Flags.NF_DUMP_FLAT,
  Flags.NF_PARALLEL,
  Flags.NF_SEPARATE_INSTANTIATION,
)::List

"""
All configuration flags, by index (`Flags.DEBUG`, `-d=`, is 1): a flag is used only through this list, and
`checkConfigFlags` checks at initialization that each entry's index is its position.
"""
const allConfigFlags = list(
  Flags.DEBUG,
  Flags.LANGUAGE_STANDARD,
  Flags.CHECK_MODEL,
  Flags.FLOW_THRESHOLD,
  Flags.USE_LOCAL_DIRECTION,
  Flags.IGNORE_COMMAND_LINE_OPTIONS_ANNOTATION,
  Flags.EVAL_LOOP_LIMIT,
  Flags.EVAL_RECURSION_LIMIT,
  Flags.ALLOW_NON_STANDARD_MODELICA,
  Flags.LOAD_MISSING_LIBRARIES,
)::List

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

"""Checks that the flags listed in allDebugFlags have sequential and unique indices."""
function checkDebugFlags()
  local index::Int = 0
  local err_str::String

  for flag in allDebugFlags
    index = index + 1
    if flag.index != index
      err_str = "Invalid flag '" + flag.name + "' with index " + string(flag.index) + " (expected " + string(index) + ") in Flags.allDebugFlags. Make sure that all flags are present and ordered correctly!"
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
      err_str = "Invalid flag '" + flag.name + "' with index " + string(flag.index) + " (expected " + string(index) + ") in Flags.allConfigFlags. Make sure that all flags are present and ordered correctly!"
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

"""
Evaluates a configuration flag and its arguments: `-d=`/`--debug=` (config flag 1) sets the given debug flags, any
other flag gets the given values.
"""
function evaluateConfigFlag(inFlag::Flags.ConfigFlag, inValues::List{<:String}, inFlags::Flags.Flag)
  local debug_flags::Vector{Bool}
  local config_flags::Vector{Flags.FlagData}
  @match Flags.FLAGS(debugFlags = debug_flags, configFlags = config_flags) = inFlags
  if inFlag.index == Flags.DEBUG.index
    ListUtil.map1_0(inValues, setDebugFlag, debug_flags)
  else
    setConfigFlag(inFlag, config_flags, inValues)
  end
  nothing
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
        "the string \"" + s + "\""
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

"""Sets the value of a string configuration flag."""
function setConfigString(inFlag::Flags.ConfigFlag, inValue::String)
  setConfigValue(inFlag, Flags.STRING_FLAG(inValue))
end

"""Sets the value of a multiple-string configuration flag."""
function setConfigStringList(inFlag::Flags.ConfigFlag, inValue::List{<:String})
  setConfigValue(inFlag, Flags.STRING_LIST_FLAG(inValue))
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

#= So that we can use wildcard imports and named imports when they do occur. Not good Julia practice =#
@exportAll()
end
