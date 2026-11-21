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

module Flags

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl DebugFlag
@UniontypeDecl ConfigFlag
@UniontypeDecl FlagData
@UniontypeDecl FlagVisibility
@UniontypeDecl Flag
@UniontypeDecl ValidOptions

import ..Gettext
import ..Global

@Uniontype DebugFlag begin
  @Record DEBUG_FLAG begin
    index::Int #= Unique index. =#
    name::String #= The name of the flag used by -d =#
    default::Bool #= Default enabled or not =#
    description::Gettext.TranslatableContent #= A description of the flag. =#
  end
end

@Uniontype ConfigFlag begin
  @Record CONFIG_FLAG begin
    index::Int #= Unique index. =#
    name::String #= The whole name of the flag. =#
    shortname::Option{String} #= A short name one-character name for the flag. =#
    visibility::FlagVisibility #= Whether the flag is visible to the user or not. =#
    defaultValue::FlagData #= The default value of the flag. =#
    validOptions::Option{ValidOptions} #= The valid options for the flag. =#
    description::Gettext.TranslatableContent #= A description of the flag. =#
  end
end

#= This uniontype is used to store the values of configuration flags. =#
@Uniontype FlagData begin
  @Record EMPTY_FLAG begin
  end

  @Record BOOL_FLAG begin
    data::Bool
  end

  @Record INT_FLAG begin
    data::Int
  end

  @Record INT_LIST_FLAG begin
    data::List{Integer}
  end

  @Record REAL_FLAG begin
    data::AbstractFloat
  end

  @Record STRING_FLAG begin
    data::String
  end

  @Record STRING_LIST_FLAG begin
    data::List{String}
  end

  @Record ENUM_FLAG begin

    data::Int
    validValues::List{Tuple{String, Integer}} #= The valid values of the enum. =#
  end
end

#= This uniontype is used to specify the visibility of a configuration flag. =#
@Uniontype FlagVisibility begin
  @Record INTERNAL begin

  end

  @Record EXTERNAL begin

  end
end

#= The structure which stores the flags. =#
@Uniontype Flag begin
  @Record FLAGS begin
    #= Concrete Vector types: these fields are read in the hottest
       instantiation paths and an abstract field type boxes every access. =#
    debugFlags::Vector{Bool}
    configFlags::Vector{FlagData}
  end

  @Record NO_FLAGS begin
  end
end

#= Specifies valid options for a flag. =#
@Uniontype ValidOptions begin
  @Record STRING_OPTION begin
    options::List{String}
  end

  @Record STRING_DESC_OPTION begin
    options::List{Tuple{String, Gettext.TranslatableContent}}
  end
end

const FAILTRACE =
  DEBUG_FLAG(
    1,
    "failtrace",
    false,
    Gettext.gettext("Sets whether to print a failtrace or not."),
  )::DebugFlag
const CGRAPH_GRAPHVIZ_FILE =
  DEBUG_FLAG(
    2,
    "cgraphGraphVizFile",
    false,
    Gettext.gettext("Generates a graphviz file of the connection graph."),
  )::DebugFlag
const CGRAPH_GRAPHVIZ_SHOW =
  DEBUG_FLAG(
    3,
    "cgraphGraphVizShow",
    false,
    Gettext.gettext("Displays the connection graph with the GraphViz lefty tool."),
  )::DebugFlag
const EVAL_PARAM =
  DEBUG_FLAG(
    4,
    "evaluateAllParameters",
    false,
    Gettext.gettext("Evaluates all parameters if set."),
  )::DebugFlag
const EXEC_STAT =
  DEBUG_FLAG(
    5,
    "execstat",
    false,
    Gettext.gettext("Prints out execution statistics for the compiler."),
  )::DebugFlag
const CGRAPH =
  DEBUG_FLAG(
    6,
    "cgraph",
    false,
    Gettext.gettext("Prints out connection graph information."),
  )::DebugFlag
const INLINE_FUNCTIONS =
  DEBUG_FLAG(
    7,
    "inlineFunctions",
    true,
    Gettext.gettext("Controls if function inlining should be performed."),
  )::DebugFlag
const DISABLE_SINGLE_FLOW_EQ =
  DEBUG_FLAG(
    8,
    "disableSingleFlowEq",
    false,
    Gettext.gettext("Disables the generation of single flow equations."),
  )::DebugFlag
const INFO_XML_OPERATIONS =
  DEBUG_FLAG(
    9,
    "infoXmlOperations",
    false,
    Gettext.gettext("Enables output of the operations in the _info.xml file when translating models."),
  )::DebugFlag

const VISUAL_XML =
  DEBUG_FLAG(
    10,
    "visxml",
    false,
    Gettext.gettext("Outputs a xml-file that contains information for visualization."),
  )::DebugFlag
const NF_SCALARIZE =
  DEBUG_FLAG(
    11,
    "nfScalarize",
    true,
    Gettext.gettext("Run scalarization in NF, default true."),
  )::DebugFlag
const NF_EVAL_CONST_ARG_FUNCS =
  DEBUG_FLAG(
    12,
    "nfEvalConstArgFuncs",
    true,
    Gettext.gettext("Evaluate all functions with constant arguments in the new frontend."),
  )::DebugFlag
const NF_EXPAND_OPERATIONS =
  DEBUG_FLAG(
    13,
    "nfExpandOperations",
    true,
    Gettext.gettext("Expand all unary/binary operations to scalar expressions in the new frontend."),
  )::DebugFlag
const NF_API =
  DEBUG_FLAG(
    14,
    "nfAPI",
    false,
    Gettext.gettext("Enables experimental new instantiation use in the OMC API."),
  )::DebugFlag
const NF_API_DYNAMIC_SELECT =
  DEBUG_FLAG(
    15,
    "nfAPIDynamicSelect",
    false,
    Gettext.gettext("Show DynamicSelect(static, dynamic) in annotations. Default to false and will select the first (static) expression"),
  )::DebugFlag
const NF_EXPAND_FUNC_ARGS =
  DEBUG_FLAG(
    16,
    "nfExpandFuncArgs",
    false,
    Gettext.gettext("Expand all function arguments in the new frontend."),
  )::DebugFlag
const NF_DUMP_FLAT =
  DEBUG_FLAG(
    17,
    "nfDumpFlat",
    false,
    Gettext.gettext("Dumps the flat model structure before generating the DAE."),
  )::DebugFlag
const NF_PARALLEL =
  DEBUG_FLAG(
    18,
    "nfParallel",
    false,
    Gettext.gettext("Opt-in parallelism for OMFrontend phases beyond Absyn-to-SCode (e.g. future parallel instantiation). The Absyn-to-SCode parallel branch is proven safe and runs unconditionally based on `Threads.nthreads()`; this flag does not control it. Reserved for opt-in branches whose correctness is not yet proven. Default off."),
  )::DebugFlag
const NF_SEPARATE_INSTANTIATION =
  DEBUG_FLAG(
    19,
    "nfSeparateInstantiation",
    false,
    Gettext.gettext("Flatten each top-level component into its own structural submodel so index reduction can run separately per component. Default off."),
  )::DebugFlag
"""
Complexity gate for the user-`Inline=true` path: inlining is skipped when the body (or its worst-case form after
substitution) exceeds the thresholds in `NFInline`. Default on; `Flags.INLINE_FUNCTIONS_COMPLEXITY_GATE[] = false`
inlines every `Inline=true` body.
"""
const INLINE_FUNCTIONS_COMPLEXITY_GATE = Ref{Bool}(true)

const DEBUG =
  CONFIG_FLAG(
    1,
    "debug",
    SOME("d"),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Sets debug flags. Use --help=debug to see available flags."),
  )::ConfigFlag
const LANGUAGE_STANDARD =
  CONFIG_FLAG(
    2,
    "std",
    NONE(),
    EXTERNAL(),
    ENUM_FLAG(
      1000,
      list(
        ("1.x", 10),
        ("2.x", 20),
        ("3.0", 30),
        ("3.1", 31),
        ("3.2", 32),
        ("3.3", 33),
        ("3.4", 34),
        ("3.5", 35),
        ("3.6", 36),
        ("latest", 1000),
        ("experimental", 9999),
      ),
    ),
    SOME(STRING_OPTION(list("1.x", "2.x", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "latest", "experimental"))),
    Gettext.gettext("Sets the language standard that should be used."),
  )::ConfigFlag
const CHECK_MODEL =
  CONFIG_FLAG(
    3,
    "checkModel",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Set when checkModel is used to turn on specific features for checking."),
  )::ConfigFlag

const FLOW_THRESHOLD =
  CONFIG_FLAG(
    4,
    "flowThreshold",
    NONE(),
    EXTERNAL(),
    REAL_FLAG(1e-7),
    NONE(),
    Gettext.gettext("Sets the minium threshold for stream flow rates"),
  )::ConfigFlag
const USE_LOCAL_DIRECTION =
  CONFIG_FLAG(
    5,
    "useLocalDirection",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Keeps the input/output prefix for all variables in the flat model, not only top-level ones."),
  )::ConfigFlag
const IGNORE_COMMAND_LINE_OPTIONS_ANNOTATION =
  CONFIG_FLAG(
    6,
    "ignoreCommandLineOptionsAnnotation",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Ignores the command line options specified as annotation in the class."),
  )::ConfigFlag
const EVAL_LOOP_LIMIT =
  CONFIG_FLAG(
    7,
    "evalLoopLimit",
    NONE(),
    EXTERNAL(),
    INT_FLAG(100000),
    NONE(),
    Gettext.gettext("The loop iteration limit used when evaluating constant function calls."),
  )::ConfigFlag
const EVAL_RECURSION_LIMIT =
  CONFIG_FLAG(
    8,
    "evalRecursionLimit",
    NONE(),
    EXTERNAL(),
    INT_FLAG(256),
    NONE(),
    Gettext.gettext("The recursion limit used when evaluating constant function calls."),
  )::ConfigFlag
const ALLOW_NON_STANDARD_MODELICA =
  CONFIG_FLAG(
    9,
    "allowNonStandardModelica",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    SOME(STRING_DESC_OPTION(list(
      ("nonStdMultipleExternalDeclarations", Gettext.gettext("Allow several external declarations in functions.")),
      ("nonStdEnumerationAsIntegers", Gettext.gettext("Allow enumeration as integer without casting via Integer(Enum).")),
      ("nonStdIntegersAsEnumeration", Gettext.gettext("Allow integer as enumeration without casting via Enum(Integer).")),
      ("nonStdDifferentCaseFileVsClassName", Gettext.gettext("Allow directory or file with different case in the name than the contained class name.")),
      ("nonStdTopLevelOuter", Gettext.gettext("Allow top level outer.")),
      ("protectedAccess", Gettext.gettext("Allow access of protected elements")),
      ("reinitInAlgorithms", Gettext.gettext("Allow reinit in algorithm sections")),
      ("unbalancedModel", Gettext.gettext("Allow models to be locally unbalanced and to have unbalanced connectors")),
      ("implicitParameterStartAttribute", Gettext.gettext("Allow fixed parameters with no binding or start attribute")),
    ))),
    Gettext.gettext("Flags to allow non-standard Modelica (omc)."),
  )::ConfigFlag
const LOAD_MISSING_LIBRARIES =
  CONFIG_FLAG(
    10,
    "loadMissingLibraries",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Automatically try to load a library a model refers to but that is not loaded (omc)."),
  )::ConfigFlag

"""
  Loads the flags with getGlobalRoot. Assumes flags have been loaded.
"""
function getFlags(initialize::Bool = true)::Flag
  local flags::Flag = getGlobalRoot(Global.flagsIndex)
  return flags
end

"""Checks if a debug flag is set."""
function isSet(inFlag::DebugFlag)::Bool
  local flags = getFlags()
  flags isa FLAGS || return false
  return flags.debugFlags[inFlag.index]
end

"""Returns the value of a configuration flag."""
function getConfigValue(inFlag::ConfigFlag)::FlagData
  local flags = getFlags()
  return (flags::FLAGS).configFlags[inFlag.index]
end

"""Whether a string list configuration flag has the given option (omc Flags.isConfigFlagSet)."""
function isConfigFlagSet(inFlag::ConfigFlag, option::String)::Bool
  local flags = getFlags()
  flags isa FLAGS || return false
  inFlag.index <= length(flags.configFlags) || return false
  local v = flags.configFlags[inFlag.index]
  return v isa STRING_LIST_FLAG && listMember(option, v.data)
end

"""Returns the value of a boolean configuration flag."""
function getConfigBool(inFlag::ConfigFlag)::Bool
  local outValue::Bool

  @match BOOL_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

"""Returns the value of an integer configuration flag."""
function getConfigInt(inFlag::ConfigFlag)::Int
  local outValue::Int

  @match INT_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

"""Returns the value of a real configuration flag."""
function getConfigReal(inFlag::ConfigFlag)::AbstractFloat
  local outValue::AbstractFloat

  @match REAL_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

"""Returns the value of a string configuration flag."""
function getConfigString(inFlag::ConfigFlag)::String
  local outValue::String

  @match STRING_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

"""Returns the value of a multiple-string configuration flag."""
function getConfigStringList(inFlag::ConfigFlag)::List{String}
  local outValue::List{String}

  @match STRING_LIST_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

"""Returns the value of an enumeration configuration flag."""
function getConfigEnum(inFlag::ConfigFlag)::Int
  local outValue::Int

  @match ENUM_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

@exportAll()
end
