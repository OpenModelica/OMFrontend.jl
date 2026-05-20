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

Base.Experimental.@compiler_options(optimize=0, compile=min, infer=no)

using MetaModelica
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

    data::Integer
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
    debugFlags::Array{Bool}
    configFlags::Array{FlagData}
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

#=  Change this to a proper enum when we have support for them.
=#

const MODELICA = 1::Integer

const METAMODELICA = 2::Integer

const PARMODELICA = 3::Integer

const OPTIMICA = 4::Integer

const PDEMODELICA = 5::Integer

const collapseArrayExpressionsText =
  Gettext.gettext("Simplifies {x[1],x[2],x[3]} → x for arrays of whole variable references (simplifies code generation).")::Gettext.TranslatableContent
#=  DEBUG FLAGS
=#

const FAILTRACE =
  DEBUG_FLAG(
    1,
    "failtrace",
    false,
    Gettext.gettext("Sets whether to print a failtrace or not."),
  )::DebugFlag
const CEVAL =
  DEBUG_FLAG(
    2,
    "ceval",
    false,
    Gettext.gettext("Prints extra information from Ceval."),
  )::DebugFlag
const CHECK_BACKEND_DAE =
  DEBUG_FLAG(
    3,
    "checkBackendDae",
    false,
    Gettext.gettext("Do some simple analyses on the datastructure from the frontend to check if it is consistent."),
  )::DebugFlag
const PARMODAUTO =
  DEBUG_FLAG(
    4,
    "parmodauto",
    false,
    Gettext.gettext("Experimental: Enable parallelization of independent systems of equations in the translated model."),
  )::DebugFlag
const PTHREADS =
  DEBUG_FLAG(
    5,
    "pthreads",
    false,
    Gettext.gettext("Experimental: Unused parallelization."),
  )::DebugFlag
const EVENTS =
  DEBUG_FLAG(6, "events", true, Gettext.gettext("Turns on/off events handling."))::DebugFlag
const DUMP_INLINE_SOLVER =
  DEBUG_FLAG(
    7,
    "dumpInlineSolver",
    false,
    Gettext.gettext("Dumps the inline solver equation system."),
  )::DebugFlag
const EVAL_FUNC =
  DEBUG_FLAG(
    8,
    "evalfunc",
    true,
    Gettext.gettext("Turns on/off symbolic function evaluation."),
  )::DebugFlag
const GEN =
  DEBUG_FLAG(
    9,
    "gen",
    false,
    Gettext.gettext("Turns on/off dynamic loading of functions that are compiled during translation. Only enable this if external functions are needed to calculate structural parameters or constants."),
  )::DebugFlag
const DYN_LOAD =
  DEBUG_FLAG(
    10,
    "dynload",
    false,
    Gettext.gettext("Display debug information about dynamic loading of compiled functions."),
  )::DebugFlag
const GENERATE_CODE_CHEAT =
  DEBUG_FLAG(
    11,
    "generateCodeCheat",
    false,
    Gettext.gettext("Used to generate code for the bootstrapped compiler."),
  )::DebugFlag
const CGRAPH_GRAPHVIZ_FILE =
  DEBUG_FLAG(
    12,
    "cgraphGraphVizFile",
    false,
    Gettext.gettext("Generates a graphviz file of the connection graph."),
  )::DebugFlag
const CGRAPH_GRAPHVIZ_SHOW =
  DEBUG_FLAG(
    13,
    "cgraphGraphVizShow",
    false,
    Gettext.gettext("Displays the connection graph with the GraphViz lefty tool."),
  )::DebugFlag
const GC_PROF =
  DEBUG_FLAG(
    14,
    "gcProfiling",
    false,
    Gettext.gettext("Prints garbage collection stats to standard output."),
  )::DebugFlag
const CHECK_DAE_CREF_TYPE =
  DEBUG_FLAG(
    15,
    "checkDAECrefType",
    false,
    Gettext.gettext("Enables extra type checking for cref expressions."),
  )::DebugFlag
const CHECK_ASUB =
  DEBUG_FLAG(
    16,
    "checkASUB",
    false,
    Gettext.gettext("Prints out a warning if an ASUB is created from a CREF expression."),
  )::DebugFlag
const INSTANCE =
  DEBUG_FLAG(
    17,
    "instance",
    false,
    Gettext.gettext("Prints extra failtrace from InstanceHierarchy."),
  )::DebugFlag
const CACHE =
  DEBUG_FLAG(
    18,
    "Cache",
    true,
    Gettext.gettext("Turns off the instantiation cache."),
  )::DebugFlag
const RML =
  DEBUG_FLAG(
    19,
    "rml",
    false,
    Gettext.gettext("Converts Modelica-style arrays to lists."),
  )::DebugFlag
const TAIL =
  DEBUG_FLAG(
    20,
    "tail",
    false,
    Gettext.gettext("Prints out a notification if tail recursion optimization has been applied."),
  )::DebugFlag
const LOOKUP =
  DEBUG_FLAG(
    21,
    "lookup",
    false,
    Gettext.gettext("Print extra failtrace from lookup."),
  )::DebugFlag
const PATTERNM_SKIP_FILTER_UNUSED_AS_BINDINGS =
  DEBUG_FLAG(22, "patternmSkipFilterUnusedBindings", false, Gettext.notrans(""))::DebugFlag
const PATTERNM_ALL_INFO =
  DEBUG_FLAG(
    23,
    "patternmAllInfo",
    false,
    Gettext.gettext("Adds notifications of all pattern-matching optimizations that are performed."),
  )::DebugFlag
const PATTERNM_DCE =
  DEBUG_FLAG(
    24,
    "patternmDeadCodeElimination",
    true,
    Gettext.gettext("Performs dead code elimination in match-expressions."),
  )::DebugFlag
const PATTERNM_MOVE_LAST_EXP =
  DEBUG_FLAG(
    25,
    "patternmMoveLastExp",
    true,
    Gettext.gettext("Optimization that moves the last assignment(s) into the result of a match-expression. For example: equation c = fn(b); then c; => then fn(b);"),
  )::DebugFlag
const EXPERIMENTAL_REDUCTIONS =
  DEBUG_FLAG(
    26,
    "experimentalReductions",
    false,
    Gettext.gettext("Turns on custom reduction functions (OpenModelica extension)."),
  )::DebugFlag
const EVAL_PARAM =
  DEBUG_FLAG(
    27,
    "evaluateAllParameters",
    false,
    Gettext.gettext("Evaluates all parameters if set."),
  )::DebugFlag
const TYPES =
  DEBUG_FLAG(
    28,
    "types",
    false,
    Gettext.gettext("Prints extra failtrace from Types."),
  )::DebugFlag
const SHOW_STATEMENT =
  DEBUG_FLAG(
    29,
    "showStatement",
    false,
    Gettext.gettext("Shows the statement that is currently being evaluated when evaluating a script."),
  )::DebugFlag
const DUMP =
  DEBUG_FLAG(
    30,
    "dump",
    false,
    Gettext.gettext("Dumps the absyn representation of a program."),
  )::DebugFlag
const DUMP_GRAPHVIZ =
  DEBUG_FLAG(
    31,
    "graphviz",
    false,
    Gettext.gettext("Dumps the absyn representation of a program in graphviz format."),
  )::DebugFlag
const EXEC_STAT =
  DEBUG_FLAG(
    32,
    "execstat",
    false,
    Gettext.gettext("Prints out execution statistics for the compiler."),
  )::DebugFlag
const TRANSFORMS_BEFORE_DUMP =
  DEBUG_FLAG(
    33,
    "transformsbeforedump",
    false,
    Gettext.gettext("Applies transformations required for code generation before dumping flat code."),
  )::DebugFlag
const DAE_DUMP_GRAPHV =
  DEBUG_FLAG(
    34,
    "daedumpgraphv",
    false,
    Gettext.gettext("Dumps the DAE in graphviz format."),
  )::DebugFlag
const INTERACTIVE_TCP =
  DEBUG_FLAG(
    35,
    "interactive",
    false,
    Gettext.gettext("Starts omc as a server listening on the socket interface."),
  )::DebugFlag
const INTERACTIVE_CORBA =
  DEBUG_FLAG(
    36,
    "interactiveCorba",
    false,
    Gettext.gettext("Starts omc as a server listening on the Corba interface."),
  )::DebugFlag
const INTERACTIVE_DUMP =
  DEBUG_FLAG(
    37,
    "interactivedump",
    false,
    Gettext.gettext("Prints out debug information for the interactive server."),
  )::DebugFlag
const RELIDX =
  DEBUG_FLAG(
    38,
    "relidx",
    false,
    Gettext.notrans("Prints out debug information about relations, that are used as zero crossings."),
  )::DebugFlag
const DUMP_REPL =
  DEBUG_FLAG(
    39,
    "dumprepl",
    false,
    Gettext.gettext("Dump the found replacements for simple equation removal."),
  )::DebugFlag
const DUMP_FP_REPL =
  DEBUG_FLAG(
    40,
    "dumpFPrepl",
    false,
    Gettext.gettext("Dump the found replacements for final parameters."),
  )::DebugFlag
const DUMP_PARAM_REPL =
  DEBUG_FLAG(
    41,
    "dumpParamrepl",
    false,
    Gettext.gettext("Dump the found replacements for remove parameters."),
  )::DebugFlag
const DUMP_PP_REPL =
  DEBUG_FLAG(
    42,
    "dumpPPrepl",
    false,
    Gettext.gettext("Dump the found replacements for protected parameters."),
  )::DebugFlag
const DUMP_EA_REPL =
  DEBUG_FLAG(
    43,
    "dumpEArepl",
    false,
    Gettext.gettext("Dump the found replacements for evaluate annotations (evaluate=true) parameters."),
  )::DebugFlag
const DEBUG_ALIAS =
  DEBUG_FLAG(
    44,
    "debugAlias",
    false,
    Gettext.gettext("Dumps some information about the process of removeSimpleEquations."),
  )::DebugFlag
const TEARING_DUMP =
  DEBUG_FLAG(
    45,
    "tearingdump",
    false,
    Gettext.gettext("Dumps tearing information."),
  )::DebugFlag
const JAC_DUMP =
  DEBUG_FLAG(
    46,
    "symjacdump",
    false,
    Gettext.gettext("Dumps information about symbolic Jacobians. Can be used only with postOptModules: generateSymbolicJacobian, generateSymbolicLinearization."),
  )::DebugFlag
const JAC_DUMP2 =
  DEBUG_FLAG(
    47,
    "symjacdumpverbose",
    false,
    Gettext.gettext("Dumps information in verbose mode about symbolic Jacobians. Can be used only with postOptModules: generateSymbolicJacobian, generateSymbolicLinearization."),
  )::DebugFlag
const JAC_DUMP_EQN =
  DEBUG_FLAG(
    48,
    "symjacdumpeqn",
    false,
    Gettext.gettext("Dump for debug purpose of symbolic Jacobians. (deactivated now)."),
  )::DebugFlag
const JAC_WARNINGS =
  DEBUG_FLAG(
    49,
    "symjacwarnings",
    false,
    Gettext.gettext("Prints warnings regarding symoblic jacbians."),
  )::DebugFlag
const DUMP_SPARSE =
  DEBUG_FLAG(
    50,
    "dumpSparsePattern",
    false,
    Gettext.gettext("Dumps sparse pattern with coloring used for simulation."),
  )::DebugFlag
const DUMP_SPARSE_VERBOSE =
  DEBUG_FLAG(
    51,
    "dumpSparsePatternVerbose",
    false,
    Gettext.gettext("Dumps in verbose mode sparse pattern with coloring used for simulation."),
  )::DebugFlag
const BLT_DUMP =
  DEBUG_FLAG(
    52,
    "bltdump",
    false,
    Gettext.gettext("Dumps information from index reduction."),
  )::DebugFlag
const DUMMY_SELECT =
  DEBUG_FLAG(
    53,
    "dummyselect",
    false,
    Gettext.gettext("Dumps information from dummy state selection heuristic."),
  )::DebugFlag
const DUMP_DAE_LOW =
  DEBUG_FLAG(
    54,
    "dumpdaelow",
    false,
    Gettext.gettext("Dumps the equation system at the beginning of the back end."),
  )::DebugFlag
const DUMP_INDX_DAE =
  DEBUG_FLAG(
    55,
    "dumpindxdae",
    false,
    Gettext.gettext("Dumps the equation system after index reduction and optimization."),
  )::DebugFlag
const OPT_DAE_DUMP =
  DEBUG_FLAG(
    56,
    "optdaedump",
    false,
    Gettext.gettext("Dumps information from the optimization modules."),
  )::DebugFlag
const EXEC_HASH =
  DEBUG_FLAG(
    57,
    "execHash",
    false,
    Gettext.gettext("Measures the time it takes to hash all simcode variables before code generation."),
  )::DebugFlag
const PARAM_DLOW_DUMP =
  DEBUG_FLAG(
    58,
    "paramdlowdump",
    false,
    Gettext.gettext("Enables dumping of the parameters in the order they are calculated."),
  )::DebugFlag
const DUMP_ENCAPSULATECONDITIONS =
  DEBUG_FLAG(
    59,
    "dumpEncapsulateConditions",
    false,
    Gettext.gettext("Dumps the results of the preOptModule encapsulateWhenConditions."),
  )::DebugFlag
const SHORT_OUTPUT =
  DEBUG_FLAG(
    60,
    "shortOutput",
    false,
    Gettext.gettext("Enables short output of the simulate() command. Useful for tools like OMNotebook."),
  )::DebugFlag
const COUNT_OPERATIONS =
  DEBUG_FLAG(61, "countOperations", false, Gettext.gettext("Count operations."))::DebugFlag
const CGRAPH =
  DEBUG_FLAG(
    62,
    "cgraph",
    false,
    Gettext.gettext("Prints out connection graph information."),
  )::DebugFlag
const UPDMOD =
  DEBUG_FLAG(
    63,
    "updmod",
    false,
    Gettext.gettext("Prints information about modification updates."),
  )::DebugFlag
const STATIC =
  DEBUG_FLAG(
    64,
    "static",
    false,
    Gettext.gettext("Enables extra debug output from the static elaboration."),
  )::DebugFlag
const TPL_PERF_TIMES =
  DEBUG_FLAG(
    65,
    "tplPerfTimes",
    false,
    Gettext.gettext("Enables output of template performance data for rendering text to file."),
  )::DebugFlag
const CHECK_SIMPLIFY =
  DEBUG_FLAG(
    66,
    "checkSimplify",
    false,
    Gettext.gettext("Enables checks for expression simplification and prints a notification whenever an undesirable transformation has been performed."),
  )::DebugFlag
const SCODE_INST =
  DEBUG_FLAG(
    67,
    "newInst",
    false,
    Gettext.gettext("Enables experimental new instantiation phase."),
  )::DebugFlag
const WRITE_TO_BUFFER =
  DEBUG_FLAG(
    68,
    "writeToBuffer",
    false,
    Gettext.gettext("Enables writing simulation results to buffer."),
  )::DebugFlag
const DUMP_BACKENDDAE_INFO =
  DEBUG_FLAG(
    69,
    "backenddaeinfo",
    false,
    Gettext.gettext("Enables dumping of back-end information about system (Number of equations before back-end,...)."),
  )::DebugFlag
const GEN_DEBUG_SYMBOLS =
  DEBUG_FLAG(
    70,
    "gendebugsymbols",
    false,
    Gettext.gettext("Generate code with debugging symbols."),
  )::DebugFlag
const DUMP_STATESELECTION_INFO =
  DEBUG_FLAG(
    71,
    "stateselection",
    false,
    Gettext.gettext("Enables dumping of selected states. Extends -d=backenddaeinfo."),
  )::DebugFlag
const DUMP_EQNINORDER =
  DEBUG_FLAG(
    72,
    "dumpeqninorder",
    false,
    Gettext.gettext("Enables dumping of the equations in the order they are calculated."),
  )::DebugFlag
const SEMILINEAR =
  DEBUG_FLAG(
    73,
    "semiLinear",
    false,
    Gettext.gettext("Enables dumping of the optimization information when optimizing calls to semiLinear."),
  )::DebugFlag
const UNCERTAINTIES =
  DEBUG_FLAG(
    74,
    "uncertainties",
    false,
    Gettext.gettext("Enables dumping of status when calling modelEquationsUC."),
  )::DebugFlag
const SHOW_START_ORIGIN =
  DEBUG_FLAG(
    75,
    "showStartOrigin",
    false,
    Gettext.gettext("Enables dumping of the DAE startOrigin attribute of the variables."),
  )::DebugFlag
const DUMP_SIMCODE =
  DEBUG_FLAG(
    76,
    "dumpSimCode",
    false,
    Gettext.gettext("Dumps the simCode model used for code generation."),
  )::DebugFlag
const DUMP_INITIAL_SYSTEM =
  DEBUG_FLAG(
    77,
    "dumpinitialsystem",
    false,
    Gettext.gettext("Dumps the initial equation system."),
  )::DebugFlag
const GRAPH_INST =
  DEBUG_FLAG(
    78,
    "graphInst",
    false,
    Gettext.gettext("Do graph based instantiation."),
  )::DebugFlag
const GRAPH_INST_RUN_DEP =
  DEBUG_FLAG(
    79,
    "graphInstRunDep",
    false,
    Gettext.gettext("Run scode dependency analysis. Use with -d=graphInst"),
  )::DebugFlag
const GRAPH_INST_GEN_GRAPH =
  DEBUG_FLAG(
    80,
    "graphInstGenGraph",
    false,
    Gettext.gettext("Dumps a graph of the program. Use with -d=graphInst"),
  )::DebugFlag
const GRAPH_INST_SHOW_GRAPH =
  DEBUG_FLAG(
    81,
    "graphInstShowGraph",
    false,
    Gettext.gettext("Display a graph of the program interactively. Use with -d=graphInst"),
  )::DebugFlag
const DUMP_CONST_REPL =
  DEBUG_FLAG(
    82,
    "dumpConstrepl",
    false,
    Gettext.gettext("Dump the found replacements for constants."),
  )::DebugFlag
const SHOW_EQUATION_SOURCE =
  DEBUG_FLAG(
    83,
    "showEquationSource",
    false,
    Gettext.gettext("Display the element source information in the dumped DAE for easier debugging."),
  )::DebugFlag
const LS_ANALYTIC_JACOBIAN =
  DEBUG_FLAG(
    84,
    "LSanalyticJacobian",
    false,
    Gettext.gettext("Enables analytical jacobian for linear strong components. Defaults to false"),
  )::DebugFlag
const NLS_ANALYTIC_JACOBIAN =
  DEBUG_FLAG(
    85,
    "NLSanalyticJacobian",
    true,
    Gettext.gettext("Enables analytical jacobian for non-linear strong components without user-defined function calls, for that see forceNLSanalyticJacobian"),
  )::DebugFlag
const INLINE_SOLVER =
  DEBUG_FLAG(
    86,
    "inlineSolver",
    false,
    Gettext.gettext("Generates code for inline solver."),
  )::DebugFlag
const HPCOM =
  DEBUG_FLAG(
    87,
    "hpcom",
    false,
    Gettext.gettext("Enables parallel calculation based on task-graphs."),
  )::DebugFlag
const INITIALIZATION =
  DEBUG_FLAG(
    88,
    "initialization",
    false,
    Gettext.gettext("Shows additional information from the initialization process."),
  )::DebugFlag
const INLINE_FUNCTIONS =
  DEBUG_FLAG(
    89,
    "inlineFunctions",
    true,
    Gettext.gettext("Controls if function inlining should be performed."),
  )::DebugFlag
const DUMP_SCC_GRAPHML =
  DEBUG_FLAG(
    90,
    "dumpSCCGraphML",
    false,
    Gettext.gettext("Dumps graphml files with the strongly connected components."),
  )::DebugFlag
const TEARING_DUMPVERBOSE =
  DEBUG_FLAG(
    91,
    "tearingdumpV",
    false,
    Gettext.gettext("Dumps verbose tearing information."),
  )::DebugFlag
const DISABLE_SINGLE_FLOW_EQ =
  DEBUG_FLAG(
    92,
    "disableSingleFlowEq",
    false,
    Gettext.gettext("Disables the generation of single flow equations."),
  )::DebugFlag
const DUMP_DISCRETEVARS_INFO =
  DEBUG_FLAG(
    93,
    "discreteinfo",
    false,
    Gettext.gettext("Enables dumping of discrete variables. Extends -d=backenddaeinfo."),
  )::DebugFlag
const ADDITIONAL_GRAPHVIZ_DUMP =
  DEBUG_FLAG(
    94,
    "graphvizDump",
    false,
    Gettext.gettext("Activates additional graphviz dumps (as .dot files). It can be used in addition to one of the following flags: {dumpdaelow|dumpinitialsystems|dumpindxdae}."),
  )::DebugFlag
const INFO_XML_OPERATIONS =
  DEBUG_FLAG(
    95,
    "infoXmlOperations",
    false,
    Gettext.gettext("Enables output of the operations in the _info.xml file when translating models."),
  )::DebugFlag
const HPCOM_DUMP =
  DEBUG_FLAG(
    96,
    "hpcomDump",
    false,
    Gettext.gettext("Dumps additional information on the parallel execution with hpcom."),
  )::DebugFlag
const RESOLVE_LOOPS_DUMP =
  DEBUG_FLAG(
    97,
    "resolveLoopsDump",
    false,
    Gettext.gettext("Debug Output for ResolveLoops Module."),
  )::DebugFlag
const DISABLE_WINDOWS_PATH_CHECK_WARNING =
  DEBUG_FLAG(
    98,
    "disableWindowsPathCheckWarning",
    false,
    Gettext.gettext("Disables warnings on Windows if OPENMODELICAHOME/MinGW is missing."),
  )::DebugFlag
const DISABLE_RECORD_CONSTRUCTOR_OUTPUT =
  DEBUG_FLAG(
    99,
    "disableRecordConstructorOutput",
    false,
    Gettext.gettext("Disables output of record constructors in the flat code."),
  )::DebugFlag

const IMPL_ODE =
  DEBUG_FLAG(
    100,
    "implOde",
    false,
    Gettext.gettext("activates implicit codegen"),
  )::DebugFlag
const EVAL_FUNC_DUMP =
  DEBUG_FLAG(
    101,
    "evalFuncDump",
    false,
    Gettext.gettext("dumps debug information about the function evaluation"),
  )::DebugFlag
const PRINT_STRUCTURAL =
  DEBUG_FLAG(
    102,
    "printStructuralParameters",
    false,
    Gettext.gettext("Prints the structural parameters identified by the front-end"),
  )::DebugFlag
const ITERATION_VARS =
  DEBUG_FLAG(
    103,
    "iterationVars",
    false,
    Gettext.gettext("Shows a list of all iteration variables."),
  )::DebugFlag
const ALLOW_RECORD_TOO_MANY_FIELDS =
  DEBUG_FLAG(
    104,
    "acceptTooManyFields",
    false,
    Gettext.gettext("Accepts passing records with more fields than expected to a function. This is not allowed, but is used in Fluid.Dissipation. See https://trac.modelica.org/Modelica/ticket/1245 for details."),
  )::DebugFlag
const HPCOM_MEMORY_OPT =
  DEBUG_FLAG(
    105,
    "hpcomMemoryOpt",
    false,
    Gettext.gettext("Optimize the memory structure regarding the selected scheduler"),
  )::DebugFlag
const DUMP_SYNCHRONOUS =
  DEBUG_FLAG(
    106,
    "dumpSynchronous",
    false,
    Gettext.gettext("Dumps information of the clock partitioning."),
  )::DebugFlag
const STRIP_PREFIX =
  DEBUG_FLAG(
    107,
    "stripPrefix",
    true,
    Gettext.gettext("Strips the environment prefix from path/crefs. Defaults to true."),
  )::DebugFlag
const DO_SCODE_DEP =
  DEBUG_FLAG(
    108,
    "scodeDep",
    true,
    Gettext.gettext("Does scode dependency analysis prior to instantiation. Defaults to true."),
  )::DebugFlag
const SHOW_INST_CACHE_INFO =
  DEBUG_FLAG(
    109,
    "showInstCacheInfo",
    false,
    Gettext.gettext("Prints information about instantiation cache hits and additions. Defaults to false."),
  )::DebugFlag
const DUMP_UNIT =
  DEBUG_FLAG(
    110,
    "dumpUnits",
    false,
    Gettext.gettext("Dumps all the calculated units."),
  )::DebugFlag
const DUMP_EQ_UNIT =
  DEBUG_FLAG(
    111,
    "dumpEqInUC",
    false,
    Gettext.gettext("Dumps all equations handled by the unit checker."),
  )::DebugFlag
const DUMP_EQ_UNIT_STRUCT =
  DEBUG_FLAG(
    112,
    "dumpEqUCStruct",
    false,
    Gettext.gettext("Dumps all the equations handled by the unit checker as tree-structure."),
  )::DebugFlag
const SHOW_DAE_GENERATION =
  DEBUG_FLAG(
    113,
    "showDaeGeneration",
    false,
    Gettext.gettext("Show the dae variable declarations as they happen."),
  )::DebugFlag
const RESHUFFLE_POST =
  DEBUG_FLAG(
    114,
    "reshufflePost",
    false,
    Gettext.gettext("Reshuffles the systems of equations."),
  )::DebugFlag
const SHOW_EXPANDABLE_INFO =
  DEBUG_FLAG(
    115,
    "showExpandableInfo",
    false,
    Gettext.gettext("Show information about expandable connector handling."),
  )::DebugFlag
const DUMP_HOMOTOPY =
  DEBUG_FLAG(
    116,
    "dumpHomotopy",
    false,
    Gettext.gettext("Dumps the results of the postOptModule optimizeHomotopyCalls."),
  )::DebugFlag
const OMC_RELOCATABLE_FUNCTIONS =
  DEBUG_FLAG(
    117,
    "relocatableFunctions",
    false,
    Gettext.gettext("Generates relocatable code: all functions become function pointers and can be replaced at run-time."),
  )::DebugFlag
const GRAPHML =
  DEBUG_FLAG(
    118,
    "graphml",
    false,
    Gettext.gettext("Dumps .graphml files for the bipartite graph after Index Reduction and a task graph for the SCCs. Can be displayed with yEd. "),
  )::DebugFlag
const USEMPI =
  DEBUG_FLAG(
    119,
    "useMPI",
    false,
    Gettext.gettext("Add MPI init and finalize to main method (CPPruntime). "),
  )::DebugFlag
const DUMP_CSE =
  DEBUG_FLAG(
    120,
    "dumpCSE",
    false,
    Gettext.gettext("Additional output for CSE module."),
  )::DebugFlag
const DUMP_CSE_VERBOSE =
  DEBUG_FLAG(
    121,
    "dumpCSE_verbose",
    false,
    Gettext.gettext("Additional output for CSE module."),
  )::DebugFlag
const NO_START_CALC =
  DEBUG_FLAG(
    122,
    "disableStartCalc",
    false,
    Gettext.gettext("Deactivates the pre-calculation of start values during compile-time."),
  )::DebugFlag

const CONSTJAC =
  DEBUG_FLAG(
    123,
    "constjac",
    false,
    Gettext.gettext("solves linear systems with constant Jacobian and variable b-Vector symbolically"),
  )::DebugFlag

const VISUAL_XML =
  DEBUG_FLAG(
    124,
    "visxml",
    false,
    Gettext.gettext("Outputs a xml-file that contains information for visualization."),
  )::DebugFlag
const ADD_SCALED_VARS =
  DEBUG_FLAG(
    125,
    "addScaledVars",
    false,
    Gettext.gettext("Adds an alias equation var_nrom = var/nominal where var is state\\nDeprecated flag: Use --postOptModules+=addScaledVars_states instead."),
  )::DebugFlag
const VECTORIZE =
  DEBUG_FLAG(
    125,
    "vectorize",
    false,
    Gettext.gettext("Activates vectorization in the backend."),
  )::DebugFlag
const CHECK_EXT_LIBS =
  DEBUG_FLAG(
    126,
    "buildExternalLibs",
    true,
    Gettext.gettext("Use the autotools project in the Resources folder of the library to build missing external libraries."),
  )::DebugFlag
const RUNTIME_STATIC_LINKING =
  DEBUG_FLAG(
    127,
    "runtimeStaticLinking",
    false,
    Gettext.gettext("Use the static simulation runtime libraries (C++ simulation runtime)."),
  )::DebugFlag
const SORT_EQNS_AND_VARS =
  DEBUG_FLAG(
    128,
    "dumpSortEqnsAndVars",
    false,
    Gettext.gettext("Dumps debug output for the modules sortEqnsVars."),
  )::DebugFlag
const DUMP_SIMPLIFY_LOOPS =
  DEBUG_FLAG(
    129,
    "dumpSimplifyLoops",
    false,
    Gettext.gettext("Dump between steps of simplifyLoops"),
  )::DebugFlag
const DUMP_RTEARING =
  DEBUG_FLAG(
    130,
    "dumpRecursiveTearing",
    false,
    Gettext.gettext("Dump between steps of recursiveTearing"),
  )::DebugFlag
const DIS_SYMJAC_FMI20 =
  DEBUG_FLAG(
    131,
    "disableDirectionalDerivatives",
    true,
    Gettext.gettext("For FMI 2.0 only dependecy analysis will be perform."),
  )::DebugFlag
const EVAL_OUTPUT_ONLY =
  DEBUG_FLAG(
    132,
    "evalOutputOnly",
    false,
    Gettext.gettext("Generates equations to calculate outputs only."),
  )::DebugFlag
const HARDCODED_START_VALUES =
  DEBUG_FLAG(
    133,
    "hardcodedStartValues",
    false,
    Gettext.gettext("Embed the start values of variables and parameters into the c++ code and do not read it from xml file."),
  )::DebugFlag
const DUMP_FUNCTIONS =
  DEBUG_FLAG(
    134,
    "dumpFunctions",
    false,
    Gettext.gettext("Add functions to backend dumps."),
  )::DebugFlag
const DEBUG_DIFFERENTIATION =
  DEBUG_FLAG(
    135,
    "debugDifferentiation",
    false,
    Gettext.gettext("Dumps debug output for the differentiation process."),
  )::DebugFlag
const DEBUG_DIFFERENTIATION_VERBOSE =
  DEBUG_FLAG(
    136,
    "debugDifferentiationVerbose",
    false,
    Gettext.gettext("Dumps verbose debug output for the differentiation process."),
  )::DebugFlag
const FMU_EXPERIMENTAL =
  DEBUG_FLAG(
    137,
    "fmuExperimental",
    false,
    Gettext.gettext("Include an extra function in the FMU fmi2GetSpecificDerivatives."),
  )::DebugFlag
const DUMP_DGESV =
  DEBUG_FLAG(
    138,
    "dumpdgesv",
    false,
    Gettext.gettext("Enables dumping of the information whether DGESV is used to solve linear systems."),
  )::DebugFlag
const MULTIRATE_PARTITION =
  DEBUG_FLAG(
    139,
    "multirate",
    false,
    Gettext.gettext("The solver can switch partitions in the system."),
  )::DebugFlag
const DUMP_EXCLUDED_EXP =
  DEBUG_FLAG(
    140,
    "dumpExcludedSymJacExps",
    false,
    Gettext.gettext("This flags dumps all expression that are excluded from differentiation of a symbolic Jacobian."),
  )::DebugFlag
const DEBUG_ALGLOOP_JACOBIAN =
  DEBUG_FLAG(
    141,
    "debugAlgebraicLoopsJacobian",
    false,
    Gettext.gettext("Dumps debug output while creating symbolic jacobians for non-linear systems."),
  )::DebugFlag
const DISABLE_JACSCC =
  DEBUG_FLAG(
    142,
    "disableJacsforSCC",
    false,
    Gettext.gettext("Disables calculation of jacobians to detect if a SCC is linear or non-linear. By disabling all SCC will handled like non-linear."),
  )::DebugFlag
const FORCE_NLS_ANALYTIC_JACOBIAN =
  DEBUG_FLAG(
    143,
    "forceNLSanalyticJacobian",
    false,
    Gettext.gettext("Forces calculation analytical jacobian also for non-linear strong components with user-defined functions."),
  )::DebugFlag
const DUMP_LOOPS =
  DEBUG_FLAG(144, "dumpLoops", false, Gettext.gettext("Dumps loop equation."))::DebugFlag
const DUMP_LOOPS_VERBOSE =
  DEBUG_FLAG(
    145,
    "dumpLoopsVerbose",
    false,
    Gettext.gettext("Dumps loop equation and enhanced adjacency matrix."),
  )::DebugFlag
const SKIP_INPUT_OUTPUT_SYNTACTIC_SUGAR =
  DEBUG_FLAG(
    146,
    "skipInputOutputSyntacticSugar",
    false,
    Gettext.gettext("Used when bootstrapping to preserve the input output parsing of the code output by the list command."),
  )::DebugFlag
const OMC_RECORD_ALLOC_WORDS =
  DEBUG_FLAG(
    147,
    "metaModelicaRecordAllocWords",
    false,
    Gettext.gettext("Instrument the source code to record memory allocations (requires run-time and generated files compiled with -DOMC_RECORD_ALLOC_WORDS)."),
  )::DebugFlag
const TOTAL_TEARING_DUMP =
  DEBUG_FLAG(
    148,
    "totaltearingdump",
    false,
    Gettext.gettext("Dumps total tearing information."),
  )::DebugFlag
const TOTAL_TEARING_DUMPVERBOSE =
  DEBUG_FLAG(
    149,
    "totaltearingdumpV",
    false,
    Gettext.gettext("Dumps verbose total tearing information."),
  )::DebugFlag
const PARALLEL_CODEGEN =
  DEBUG_FLAG(
    150,
    "parallelCodegen",
    true,
    Gettext.gettext("Enables code generation in parallel (disable this if compiling a model causes you to run out of RAM)."),
  )::DebugFlag
const SERIALIZED_SIZE =
  DEBUG_FLAG(
    151,
    "reportSerializedSize",
    false,
    Gettext.gettext("Reports serialized sizes of various data structures used in the compiler."),
  )::DebugFlag
const BACKEND_KEEP_ENV_GRAPH =
  DEBUG_FLAG(
    152,
    "backendKeepEnv",
    true,
    Gettext.gettext("When enabled, the environment is kept when entering the backend, which enables CevalFunction (function interpretation) to work. This module not essential for the backend to function in most cases, but can improve simulation performance by evaluating functions. The drawback to keeping the environment graph in memory is that it is huge (~80% of the total memory in use when returning the frontend DAE)."),
  )::DebugFlag
const DUMPBACKENDINLINE =
  DEBUG_FLAG(
    153,
    "dumpBackendInline",
    false,
    Gettext.gettext("Dumps debug output while inline function."),
  )::DebugFlag
const DUMPBACKENDINLINE_VERBOSE =
  DEBUG_FLAG(
    154,
    "dumpBackendInlineVerbose",
    false,
    Gettext.gettext("Dumps debug output while inline function."),
  )::DebugFlag
const BLT_MATRIX_DUMP =
  DEBUG_FLAG(
    155,
    "bltmatrixdump",
    false,
    Gettext.gettext("Dumps the blt matrix in html file. IE seems to be very good in displaying large matrices."),
  )::DebugFlag
const LIST_REVERSE_WRONG_ORDER =
  DEBUG_FLAG(
    156,
    "listAppendWrongOrder",
    true,
    Gettext.gettext("Print notifications about bad usage of listAppend."),
  )::DebugFlag
const PARTITION_INITIALIZATION =
  DEBUG_FLAG(
    157,
    "partitionInitialization",
    true,
    Gettext.gettext("This flag controls if partitioning is applied to the initialization system."),
  )::DebugFlag
const EVAL_PARAM_DUMP =
  DEBUG_FLAG(
    158,
    "evalParameterDump",
    false,
    Gettext.gettext("Dumps information for evaluating parameters."),
  )::DebugFlag
const NF_UNITCHECK =
  DEBUG_FLAG(
    159,
    "frontEndUnitCheck",
    false,
    Gettext.gettext("Checks the consistency of units in equation."),
  )::DebugFlag
const DISABLE_COLORING =
  DEBUG_FLAG(
    160,
    "disableColoring",
    false,
    Gettext.gettext("Disables coloring algorithm while spasity detection."),
  )::DebugFlag
const MERGE_ALGORITHM_SECTIONS =
  DEBUG_FLAG(
    161,
    "mergeAlgSections",
    false,
    Gettext.gettext("Disables coloring algorithm while sparsity detection."),
  )::DebugFlag
const WARN_NO_NOMINAL =
  DEBUG_FLAG(
    162,
    "warnNoNominal",
    false,
    Gettext.gettext("Prints the iteration variables in the initialization and simulation DAE, which do not have a nominal value."),
  )::DebugFlag
const REDUCE_DAE =
  DEBUG_FLAG(
    163,
    "backendReduceDAE",
    false,
    Gettext.gettext("Prints all Reduce DAE debug information."),
  )::DebugFlag
const IGNORE_CYCLES =
  DEBUG_FLAG(
    164,
    "ignoreCycles",
    false,
    Gettext.gettext("Ignores cycles between constant/parameter components."),
  )::DebugFlag
const ALIAS_CONFLICTS =
  DEBUG_FLAG(
    165,
    "aliasConflicts",
    false,
    Gettext.gettext("Dumps alias sets with different start or nominal values."),
  )::DebugFlag
const SUSAN_MATCHCONTINUE_DEBUG =
  DEBUG_FLAG(
    166,
    "susanDebug",
    false,
    Gettext.gettext("Makes Susan generate code using try/else to better debug which function broke the expected match semantics."),
  )::DebugFlag
const OLD_FE_UNITCHECK =
  DEBUG_FLAG(
    167,
    "oldFrontEndUnitCheck",
    false,
    Gettext.gettext("Checks the consistency of units in equation (for the old front-end)."),
  )::DebugFlag
const EXEC_STAT_EXTRA_GC =
  DEBUG_FLAG(
    168,
    "execstatGCcollect",
    false,
    Gettext.gettext("When running execstat, also perform an extra full garbage collection."),
  )::DebugFlag
const DEBUG_DAEMODE =
  DEBUG_FLAG(
    169,
    "debugDAEmode",
    false,
    Gettext.gettext("Dump debug output for the DAEmode."),
  )::DebugFlag
const NF_SCALARIZE =
  DEBUG_FLAG(
    170,
    "nfScalarize",
    true,
    Gettext.gettext("Run scalarization in NF, default true."),
  )::DebugFlag
const NF_EVAL_CONST_ARG_FUNCS =
  DEBUG_FLAG(
    171,
    "nfEvalConstArgFuncs",
    true,
    Gettext.gettext("Evaluate all functions with constant arguments in the new frontend."),
  )::DebugFlag
const NF_EXPAND_OPERATIONS =
  DEBUG_FLAG(
    172,
    "nfExpandOperations",
    true,
    Gettext.gettext("Expand all unary/binary operations to scalar expressions in the new frontend."),
  )::DebugFlag
const NF_API =
  DEBUG_FLAG(
    173,
    "nfAPI",
    false,
    Gettext.gettext("Enables experimental new instantiation use in the OMC API."),
  )::DebugFlag
const NF_API_DYNAMIC_SELECT =
  DEBUG_FLAG(
    174,
    "nfAPIDynamicSelect",
    false,
    Gettext.gettext("Show DynamicSelect(static, dynamic) in annotations. Default to false and will select the first (static) expression"),
  )::DebugFlag
const NF_API_NOISE =
  DEBUG_FLAG(
    175,
    "nfAPINoise",
    false,
    Gettext.gettext("Enables error display for the experimental new instantiation use in the OMC API."),
  )::DebugFlag
const FMI20_DEPENDENCIES =
  DEBUG_FLAG(
    176,
    "disableFMIDependency",
    false,
    Gettext.gettext("Disables the dependency analysis and generation for FMI 2.0."),
  )::DebugFlag
const WARNING_MINMAX_ATTRIBUTES =
  DEBUG_FLAG(
    177,
    "warnMinMax",
    true,
    Gettext.gettext("Makes a warning assert from min/max variable attributes instead of error."),
  )::DebugFlag
const NF_EXPAND_FUNC_ARGS =
  DEBUG_FLAG(
    178,
    "nfExpandFuncArgs",
    false,
    Gettext.gettext("Expand all function arguments in the new frontend."),
  )::DebugFlag
const DUMP_JL =
  DEBUG_FLAG(
    179,
    "dumpJL",
    false,
    Gettext.gettext("Dumps the absyn representation of a program as a Julia representation"),
  )::DebugFlag
const DUMP_ASSC =
  DEBUG_FLAG(
    180,
    "dumpASSC",
    false,
    Gettext.gettext("Dumps the conversion process of analytical to structural singularities."),
  )::DebugFlag
const SPLIT_CONSTANT_PARTS_SYMJAC =
  DEBUG_FLAG(
    181,
    "symJacConstantSplit",
    false,
    Gettext.gettext("Generates all symbolic Jacobians with splitted constant parts."),
  )::DebugFlag
const NF_DUMP_FLAT =
  DEBUG_FLAG(
    182,
    "nfDumpFlat",
    false,
    Gettext.gettext("Dumps the flat model structure before generating the DAE."),
  )::DebugFlag
const DUMP_FORCE_FMI_ATTRIBUTES =
  DEBUG_FLAG(
    183,
    "force-fmi-attributes",
    false,
    Gettext.gettext("Force to export all fmi attributes to the modelDescription.xml, including those which have default values"),
  )::DebugFlag
const DUMP_FORCE_FMI_INTERNAL_VARIABLES =
  DEBUG_FLAG(
    184,
    "force-fmi-internal-variables",
    false,
    Gettext.gettext("Force to export all internal variables (eg: CSE) to the modelDescription.xml"),
  )::DebugFlag
const NF_PARALLEL =
  DEBUG_FLAG(
    185,
    "nfParallel",
    false,
    Gettext.gettext("Opt-in parallelism for OMFrontend phases beyond Absyn-to-SCode (e.g. future parallel instantiation). The Absyn-to-SCode parallel branch is proven safe and runs unconditionally based on `Threads.nthreads()`; this flag does not control it. Reserved for opt-in branches whose correctness is not yet proven. Default off."),
  )::DebugFlag
#= Runtime-toggleable complexity gate for the user-`Inline=true` path. Skips
   inlining when the body (or worst-case post-substitution form) exceeds the
   tunable thresholds in `NFInline`. Default on. Flip via
   `OMFrontend.Frontend.INLINE_FUNCTIONS_COMPLEXITY_GATE[] = false` to revert
   to inlining every `Inline=true` body unconditionally. =#
const INLINE_FUNCTIONS_COMPLEXITY_GATE = Ref{Bool}(true)

#=  CONFIGURATION FLAGS
=#
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
const HELP =
  CONFIG_FLAG(
    2,
    "help",
    SOME("h"),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Displays the help text. Use --help=topics for more information."),
  )::ConfigFlag
const RUNNING_TESTSUITE =
  CONFIG_FLAG(
    3,
    "running-testsuite",
    NONE(),
    INTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Used when running the testsuite."),
  )::ConfigFlag
const SHOW_VERSION =
  CONFIG_FLAG(
    4,
    "version",
    SOME("-v"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Print the version and exit."),
  )::ConfigFlag
const TARGET =
  CONFIG_FLAG(
    5,
    "target",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("gcc"),
    SOME(STRING_OPTION(list(
      "gcc",
      "msvc",
      "msvc10",
      "msvc12",
      "msvc13",
      "msvc15",
      "msvc19",
      "vxworks69",
      "debugrt",
    ))),
    Gettext.gettext("Sets the target compiler to use."),
  )::ConfigFlag
const GRAMMAR =
  CONFIG_FLAG(
    6,
    "grammar",
    SOME("g"),
    EXTERNAL(),
    ENUM_FLAG(
      MODELICA,
      list(
        ("Modelica", MODELICA),
        ("MetaModelica", METAMODELICA),
        ("ParModelica", PARMODELICA),
        ("Optimica", OPTIMICA),
        ("PDEModelica", PDEMODELICA),
      ),
    ),
    SOME(STRING_OPTION(list(
      "Modelica",
      "MetaModelica",
      "ParModelica",
      "Optimica",
      "PDEModelica",
    ))),
    Gettext.gettext("Sets the grammar and semantics to accept."),
  )::ConfigFlag
const ANNOTATION_VERSION =
  CONFIG_FLAG(
    7,
    "annotationVersion",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("3.x"),
    SOME(STRING_OPTION(list("1.x", "2.x", "3.x"))),
    Gettext.gettext("Sets the annotation version that should be used."),
  )::ConfigFlag
const LANGUAGE_STANDARD =
  CONFIG_FLAG(
    8,
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
        ("latest", 1000),
      ),
    ),
    SOME(STRING_OPTION(list("1.x", "2.x", "3.1", "3.2", "3.3", "latest"))),
    Gettext.gettext("Sets the language standard that should be used."),
  )::ConfigFlag
const SHOW_ERROR_MESSAGES =
  CONFIG_FLAG(
    9,
    "showErrorMessages",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Show error messages immediately when they happen."),
  )::ConfigFlag
const SHOW_ANNOTATIONS =
  CONFIG_FLAG(
    10,
    "showAnnotations",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Show annotations in the flattened code."),
  )::ConfigFlag
const NO_SIMPLIFY =
  CONFIG_FLAG(
    11,
    "noSimplify",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Do not simplify expressions if set."),
  )::ConfigFlag
const removeSimpleEquationDesc =
  Gettext.gettext("Performs alias elimination and removes constant variables from the DAE, replacing all occurrences of the old variable reference with the new value (constants) or variable reference (alias elimination).")::Gettext.TranslatableContent

const PRE_OPT_MODULES =
  CONFIG_FLAG(
    12,
    "preOptModules",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(list(
      "normalInlineFunction",
      "evaluateParameters",
      "simplifyIfEquations",
      "expandDerOperator",
      "clockPartitioning",
      "findStateOrder",
      "replaceEdgeChange",
      "inlineArrayEqn",
      "removeEqualRHS",
      "removeSimpleEquations",
      "comSubExp",
      "evalFunc",
      "encapsulateWhenConditions",
    )),
    SOME(STRING_DESC_OPTION(list(
      (
        "introduceOutputAliases",
        Gettext.gettext("Introduces aliases for top-level outputs."),
      ),
      ("clockPartitioning", Gettext.gettext("Does the clock partitioning.")),
      ("collapseArrayExpressions", collapseArrayExpressionsText),
      (
        "comSubExp",
        Gettext.gettext("Introduces alias assignments for variables which are assigned to simple terms i.e. a = b/c; d = b/c; --> a=d"),
      ),
      (
        "dumpDAE",
        Gettext.gettext("dumps the DAE representation of the current transformation state"),
      ),
      (
        "dumpDAEXML",
        Gettext.gettext("dumps the DAE as xml representation of the current transformation state"),
      ),
      (
        "encapsulateWhenConditions",
        Gettext.gettext("This module replaces each when condition with a boolean variable."),
      ),
      ("evalFunc", Gettext.gettext("evaluates functions partially")),
      (
        "evaluateParameters",
        Gettext.gettext("Evaluates parameters with annotation(Evaluate=true). Use '--evaluateFinalParameters=true' or '--evaluateProtectedParameters=true' to specify additional parameters to be evaluated. Use '--replaceEvaluatedParameters=true' if the evaluated parameters should be replaced in the DAE. To evaluate all parameters in the Frontend use -d=evaluateAllParameters."),
      ),
      (
        "expandDerOperator",
        Gettext.notrans("Expands der(expr) using Derive.differentiteExpTime."),
      ),
      ("findStateOrder", Gettext.notrans("Sets derivative information to states.")),
      (
        "inlineArrayEqn",
        Gettext.gettext("This module expands all array equations to scalar equations."),
      ),
      (
        "normalInlineFunction",
        Gettext.gettext("Perform function inlining for function with annotation Inline=true."),
      ),
      (
        "inputDerivativesForDynOpt",
        Gettext.gettext("Allowed derivatives of inputs in dyn. optimization."),
      ),
      (
        "introduceDerAlias",
        Gettext.notrans("Adds for every der-call an alias equation e.g. dx = der(x)."),
      ),
      (
        "removeEqualRHS",
        Gettext.notrans("Detects equal expressions of the form a=<exp> and b=<exp> and substitutes them to get speed up."),
      ),
      (
        "removeProtectedParameters",
        Gettext.gettext("Replace all parameters with protected=true in the system."),
      ),
      ("removeSimpleEquations", removeSimpleEquationDesc),
      (
        "removeUnusedParameter",
        Gettext.gettext("Strips all parameter not present in the equations from the system."),
      ),
      (
        "removeUnusedVariables",
        Gettext.gettext("Strips all variables not present in the equations from the system."),
      ),
      (
        "removeVerySimpleEquations",
        Gettext.gettext("[Experimental] Like removeSimpleEquations, but less thorough. Note that this always uses the experimental new alias elimination, --removeSimpleEquations=new, which makes it unstable. In particular, MultiBody systems fail to translate correctly. It can be used for simple (but large) systems of equations."),
      ),
      (
        "replaceEdgeChange",
        Gettext.gettext("Replace edge(b) = b and not pre(b) and change(b) = v <> pre(v)."),
      ),
      (
        "residualForm",
        Gettext.gettext("Transforms simple equations x=y to zero-sum equations 0=y-x."),
      ),
      ("resolveLoops", Gettext.gettext("resolves linear equations in loops")),
      (
        "simplifyAllExpressions",
        Gettext.notrans("Does simplifications on all expressions."),
      ),
      (
        "simplifyIfEquations",
        Gettext.gettext("Tries to simplify if equations by use of information from evaluated parameters."),
      ),
      ("sortEqnsVars", Gettext.notrans("Heuristic sorting for equations and variables.")),
      (
        "unitChecking",
        Gettext.gettext("Does advanced unit checking which consists of two parts: 1. calculation of unspecified unit information for variables; 2. consistency check for all equations based on unit information. Please note: This module is still experimental."),
      ),
      (
        "wrapFunctionCalls",
        Gettext.gettext("This module introduces variables for each function call and substitutes all these calls with the newly introduced variables."),
      ),
    ))),
    Gettext.gettext("Sets the pre optimization modules to use in the back end. See --help=optmodules for more info."),
  )::ConfigFlag
#= \"resolveLoops\",
=#
const CHEAPMATCHING_ALGORITHM =
  CONFIG_FLAG(
    13,
    "cheapmatchingAlgorithm",
    NONE(),
    EXTERNAL(),
    INT_FLAG(3),
    SOME(STRING_DESC_OPTION(list(
      ("0", Gettext.gettext("No cheap matching.")),
      (
        "1",
        Gettext.gettext("Cheap matching, traverses all equations and match the first free variable."),
      ),
      (
        "3",
        Gettext.gettext("Random Karp-Sipser: R. M. Karp and M. Sipser. Maximum matching in sparse random graphs."),
      ),
    ))),
    Gettext.gettext("Sets the cheap matching algorithm to use. A cheap matching algorithm gives a jump start matching by heuristics."),
  )::ConfigFlag
const MATCHING_ALGORITHM =
  CONFIG_FLAG(
    14,
    "matchingAlgorithm",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("PFPlusExt"),
    SOME(STRING_DESC_OPTION(list(
      ("BFSB", Gettext.gettext("Breadth First Search based algorithm.")),
      ("DFSB", Gettext.gettext("Depth First Search based algorithm.")),
      (
        "MC21A",
        Gettext.gettext("Depth First Search based algorithm with look ahead feature."),
      ),
      (
        "PF",
        Gettext.gettext("Depth First Search based algorithm with look ahead feature."),
      ),
      (
        "PFPlus",
        Gettext.gettext("Depth First Search based algorithm with look ahead feature and fair row traversal."),
      ),
      ("HK", Gettext.gettext("Combined BFS and DFS algorithm.")),
      ("HKDW", Gettext.gettext("Combined BFS and DFS algorithm.")),
      ("ABMP", Gettext.gettext("Combined BFS and DFS algorithm.")),
      ("PR", Gettext.gettext("Matching algorithm using push relabel mechanism.")),
      (
        "DFSBExt",
        Gettext.gettext("Depth First Search based Algorithm external c implementation."),
      ),
      (
        "BFSBExt",
        Gettext.gettext("Breadth First Search based Algorithm external c implementation."),
      ),
      (
        "MC21AExt",
        Gettext.gettext("Depth First Search based Algorithm with look ahead feature external c implementation."),
      ),
      (
        "PFExt",
        Gettext.gettext("Depth First Search based Algorithm with look ahead feature external c implementation."),
      ),
      (
        "PFPlusExt",
        Gettext.gettext("Depth First Search based Algorithm with look ahead feature and fair row traversal external c implementation."),
      ),
      (
        "HKExt",
        Gettext.gettext("Combined BFS and DFS algorithm external c implementation."),
      ),
      (
        "HKDWExt",
        Gettext.gettext("Combined BFS and DFS algorithm external c implementation."),
      ),
      (
        "ABMPExt",
        Gettext.gettext("Combined BFS and DFS algorithm external c implementation."),
      ),
      (
        "PRExt",
        Gettext.gettext("Matching algorithm using push relabel mechanism external c implementation."),
      ),
      ("BB", Gettext.gettext("BBs try.")),
    ))),
    Gettext.gettext("Sets the matching algorithm to use. See --help=optmodules for more info."),
  )::ConfigFlag
const INDEX_REDUCTION_METHOD =
  CONFIG_FLAG(
    15,
    "indexReductionMethod",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("dynamicStateSelection"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("Skip index reduction")),
      ("uode", Gettext.gettext("Use the underlying ODE without the constraints.")),
      (
        "dynamicStateSelection",
        Gettext.gettext("Simple index reduction method, select (dynamic) dummy states based on analysis of the system."),
      ),
      (
        "dummyDerivatives",
        Gettext.gettext("Simple index reduction method, select (static) dummy states based on heuristic."),
      ),
    ))),
    Gettext.gettext("Sets the index reduction method to use. See --help=optmodules for more info."),
  )::ConfigFlag
const POST_OPT_MODULES =
  CONFIG_FLAG(
    16,
    "postOptModules",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(list(
      "lateInlineFunction",
      "wrapFunctionCalls",
      "inlineArrayEqn",
      "constantLinearSystem",
      "simplifysemiLinear",
      "removeSimpleEquations",
      "simplifyComplexFunction",
      "solveSimpleEquations",
      "tearingSystem",
      "inputDerivativesUsed",
      "calculateStrongComponentJacobians",
      "calculateStateSetsJacobians",
      "symbolicJacobian",
      "removeConstants",
      "simplifyTimeIndepFuncCalls",
      "simplifyAllExpressions",
      "findZeroCrossings",
      "collapseArrayExpressions",
    )),
    SOME(STRING_DESC_OPTION(list(
      (
        "addScaledVars_states",
        Gettext.notrans("added var_norm = var/nominal, where var is state"),
      ),
      (
        "addScaledVars_inputs",
        Gettext.notrans("added var_norm = var/nominal, where var is input"),
      ),
      (
        "addTimeAsState",
        Gettext.gettext("Experimental feature: this replaces each occurrence of variable time with a new introduced state time with equation der(time) = 1.0"),
      ),
      (
        "calculateStateSetsJacobians",
        Gettext.gettext("Generates analytical jacobian for dynamic state selection sets."),
      ),
      (
        "calculateStrongComponentJacobians",
        Gettext.gettext("Generates analytical jacobian for torn linear and non-linear strong components. By default linear components and non-linear components with user-defined function calls are skipped. See also debug flags: LSanalyticJacobian, NLSanalyticJacobian and forceNLSanalyticJacobian"),
      ),
      ("collapseArrayExpressions", collapseArrayExpressionsText),
      (
        "constantLinearSystem",
        Gettext.gettext("Evaluates constant linear systems (a*x+b*y=c; d*x+e*y=f; a,b,c,d,e,f are constants) at compile-time."),
      ),
      (
        "countOperations",
        Gettext.gettext("Count the mathematical operations of the system."),
      ),
      ("cseBinary", Gettext.gettext("Common Sub-expression Elimination")),
      (
        "dumpComponentsGraphStr",
        Gettext.notrans("Dumps the assignment graph used to determine strong components to format suitable for Mathematica"),
      ),
      (
        "dumpDAE",
        Gettext.gettext("dumps the DAE representation of the current transformation state"),
      ),
      (
        "dumpDAEXML",
        Gettext.gettext("dumps the DAE as xml representation of the current transformation state"),
      ),
      (
        "evaluateParameters",
        Gettext.gettext("Evaluates parameters with annotation(Evaluate=true). Use '--evaluateFinalParameters=true' or '--evaluateProtectedParameters=true' to specify additional parameters to be evaluated. Use '--replaceEvaluatedParameters=true' if the evaluated parameters should be replaced in the DAE. To evaluate all parameters in the Frontend use -d=evaluateAllParameters."),
      ),
      ("extendDynamicOptimization", Gettext.gettext("Move loops to constraints.")),
      (
        "generateSymbolicLinearization",
        Gettext.gettext("Generates symbolic linearization matrices A,B,C,D for linear model:\\n\\t:math:`\\\\dot{x} = Ax + Bu `\\n\\t:math:`y = Cx +Du`"),
      ),
      (
        "generateSymbolicSensitivities",
        Gettext.gettext("Generates symbolic Sensivities matrix, where der(x) is differentiated w.r.t. param."),
      ),
      (
        "inlineArrayEqn",
        Gettext.gettext("This module expands all array equations to scalar equations."),
      ),
      (
        "inputDerivativesUsed",
        Gettext.gettext("Checks if derivatives of inputs are need to calculate the model."),
      ),
      (
        "lateInlineFunction",
        Gettext.gettext("Perform function inlining for function with annotation LateInline=true."),
      ),
      ("partlintornsystem", Gettext.notrans("partitions linear torn systems.")),
      ("recursiveTearing", Gettext.notrans("inline and repeat tearing")),
      (
        "reduceDynamicOptimization",
        Gettext.notrans("Removes equations which are not needed for the calculations of cost and constraints. This module requires -d=reduceDynOpt."),
      ),
      ("relaxSystem", Gettext.notrans("relaxation from gausian elemination")),
      ("removeConstants", Gettext.gettext("Remove all constants in the system.")),
      (
        "removeEqualRHS",
        Gettext.notrans("Detects equal function calls of the form a=f(b) and c=f(b) and substitutes them to get speed up."),
      ),
      ("removeSimpleEquations", removeSimpleEquationDesc),
      (
        "removeUnusedParameter",
        Gettext.gettext("Strips all parameter not present in the equations from the system to get speed up for compilation of target code."),
      ),
      (
        "removeUnusedVariables",
        Gettext.notrans("Strips all variables not present in the equations from the system to get speed up for compilation of target code."),
      ),
      ("reshufflePost", Gettext.gettext("Reshuffles algebraic loops.")),
      (
        "simplifyAllExpressions",
        Gettext.notrans("Does simplifications on all expressions."),
      ),
      (
        "simplifyComplexFunction",
        Gettext.notrans("Some simplifications on complex functions (complex refers to the internal data structure)"),
      ),
      (
        "simplifyConstraints",
        Gettext.notrans("Rewrites nonlinear constraints into box constraints if possible. This module requires +gDynOpt."),
      ),
      (
        "simplifyLoops",
        Gettext.notrans("Simplifies algebraic loops. This modules requires +simplifyLoops."),
      ),
      (
        "simplifyTimeIndepFuncCalls",
        Gettext.gettext("Simplifies time independent built in function calls like pre(param) -> param, der(param) -> 0.0, change(param) -> false, edge(param) -> false."),
      ),
      ("simplifysemiLinear", Gettext.gettext("Simplifies calls to semiLinear.")),
      ("solveLinearSystem", Gettext.notrans("solve linear system with newton step")),
      ("solveSimpleEquations", Gettext.notrans("Solves simple equations")),
      (
        "symSolver",
        Gettext.notrans("Rewrites the ode system for implicit Euler method. This module requires +symSolver."),
      ),
      (
        "symbolicJacobian",
        Gettext.notrans("Detects the sparse pattern of the ODE system and calculates also the symbolic Jacobian if flag '--generateSymbolicJacobian' is enabled."),
      ),
      ("tearingSystem", Gettext.notrans("For method selection use flag tearingMethod.")),
      (
        "wrapFunctionCalls",
        Gettext.gettext("This module introduces variables for each function call and substitutes all these calls with the newly introduced variables."),
      ),
    ))),
    Gettext.gettext("Sets the post optimization modules to use in the back end. See --help=optmodules for more info."),
  )::ConfigFlag
const SIMCODE_TARGET =
  CONFIG_FLAG(
    17,
    "simCodeTarget",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("C"),
    SOME(STRING_OPTION(list(
      "None",
      "Adevs",
      "C",
      "Cpp",
      "omsicpp",
      "CSharp",
      "ExperimentalEmbeddedC",
      "Java",
      "JavaScript",
      "omsic",
      "sfmi",
      "XML",
      "MidC",
    ))),
    Gettext.gettext("Sets the target language for the code generation."),
  )::ConfigFlag
const ORDER_CONNECTIONS =
  CONFIG_FLAG(
    18,
    "orderConnections",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Orders connect equations alphabetically if set."),
  )::ConfigFlag
const TYPE_INFO =
  CONFIG_FLAG(
    19,
    "typeinfo",
    SOME("t"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Prints out extra type information if set."),
  )::ConfigFlag
const KEEP_ARRAYS =
  CONFIG_FLAG(
    20,
    "keepArrays",
    SOME("a"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Sets whether to split arrays or not."),
  )::ConfigFlag
const MODELICA_OUTPUT =
  CONFIG_FLAG(
    21,
    "modelicaOutput",
    SOME("m"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Enables valid modelica output for flat modelica."),
  )::ConfigFlag
const SILENT =
  CONFIG_FLAG(
    22,
    "silent",
    SOME("q"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Turns on silent mode."),
  )::ConfigFlag
const CORBA_SESSION =
  CONFIG_FLAG(
    23,
    "corbaSessionName",
    SOME("c"),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Sets the name of the corba session if -d=interactiveCorba or --interactive=corba is used."),
  )::ConfigFlag
const NUM_PROC =
  CONFIG_FLAG(
    24,
    "numProcs",
    SOME("n"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the number of processors to use (0=default=auto)."),
  )::ConfigFlag
const LATENCY =
  CONFIG_FLAG(
    25,
    "latency",
    SOME("l"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the latency for parallel execution."),
  )::ConfigFlag
const BANDWIDTH =
  CONFIG_FLAG(
    26,
    "bandwidth",
    SOME("b"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the bandwidth for parallel execution."),
  )::ConfigFlag
const INST_CLASS =
  CONFIG_FLAG(
    27,
    "instClass",
    SOME("i"),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Instantiate the class given by the fully qualified path."),
  )::ConfigFlag
const VECTORIZATION_LIMIT =
  CONFIG_FLAG(
    28,
    "vectorizationLimit",
    SOME("v"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the vectorization limit, arrays and matrices larger than this will not be vectorized."),
  )::ConfigFlag
const SIMULATION_CG =
  CONFIG_FLAG(
    29,
    "simulationCg",
    SOME("s"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Turns on simulation code generation."),
  )::ConfigFlag
const EVAL_PARAMS_IN_ANNOTATIONS =
  CONFIG_FLAG(
    30,
    "evalAnnotationParams",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Sets whether to evaluate parameters in annotations or not."),
  )::ConfigFlag
const CHECK_MODEL =
  CONFIG_FLAG(
    31,
    "checkModel",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Set when checkModel is used to turn on specific features for checking."),
  )::ConfigFlag
const CEVAL_EQUATION =
  CONFIG_FLAG(
    32,
    "cevalEquation",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.notrans(""),
  )::ConfigFlag
const UNIT_CHECKING =
  CONFIG_FLAG(
    33,
    "unitChecking",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.notrans(""),
  )::ConfigFlag
const TRANSLATE_DAE_STRING =
  CONFIG_FLAG(
    34,
    "translateDAEString",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.notrans(""),
  )::ConfigFlag
const GENERATE_LABELED_SIMCODE =
  CONFIG_FLAG(
    35,
    "generateLabeledSimCode",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Turns on labeled SimCode generation for reduction algorithms."),
  )::ConfigFlag
const REDUCE_TERMS =
  CONFIG_FLAG(
    36,
    "reduceTerms",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Turns on reducing terms for reduction algorithms."),
  )::ConfigFlag
const REDUCTION_METHOD =
  CONFIG_FLAG(
    37,
    "reductionMethod",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("deletion"),
    SOME(STRING_OPTION(list("deletion", "substitution", "linearization"))),
    Gettext.gettext("Sets the reduction method to be used."),
  )::ConfigFlag
const DEMO_MODE =
  CONFIG_FLAG(
    38,
    "demoMode",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Disable Warning/Error Massages."),
  )::ConfigFlag
const LOCALE_FLAG =
  CONFIG_FLAG(
    39,
    "locale",
    NONE(),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Override the locale from the environment."),
  )::ConfigFlag
const DEFAULT_OPENCL_DEVICE =
  CONFIG_FLAG(
    40,
    "defaultOCLDevice",
    SOME("o"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the default OpenCL device to be used for parallel execution."),
  )::ConfigFlag
const MAXTRAVERSALS =
  CONFIG_FLAG(
    41,
    "maxTraversals",
    NONE(),
    EXTERNAL(),
    INT_FLAG(2),
    NONE(),
    Gettext.gettext("Maximal traversals to find simple equations in the acausal system."),
  )::ConfigFlag
const DUMP_TARGET =
  CONFIG_FLAG(
    42,
    "dumpTarget",
    NONE(),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Redirect the dump to file. If the file ends with .html HTML code is generated."),
  )::ConfigFlag
const DELAY_BREAK_LOOP =
  CONFIG_FLAG(
    43,
    "delayBreakLoop",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Enables (very) experimental code to break algebraic loops using the delay() operator. Probably messes with initialization."),
  )::ConfigFlag
const TEARING_METHOD =
  CONFIG_FLAG(
    44,
    "tearingMethod",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("cellier"),
    SOME(STRING_DESC_OPTION(list(
      (
        "noTearing",
        Gettext.gettext("Skip tearing. This breaks models with mixed continuous-integer/boolean unknowns"),
      ),
      (
        "minimalTearing",
        Gettext.gettext("Minimal tearing method to only tear discrete variables."),
      ),
      (
        "omcTearing",
        Gettext.gettext("Tearing method developed by TU Dresden: Frenkel, Schubert."),
      ),
      (
        "cellier",
        Gettext.gettext("Tearing based on Celliers method, revised by FH Bielefeld: Täuber, Patrick"),
      ),
    ))),
    Gettext.gettext("Sets the tearing method to use. Select no tearing or choose tearing method."),
  )::ConfigFlag
const TEARING_HEURISTIC =
  CONFIG_FLAG(
    45,
    "tearingHeuristic",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("MC3"),
    SOME(STRING_DESC_OPTION(list(
      (
        "MC1",
        Gettext.gettext("Original cellier with consideration of impossible assignments and discrete Vars."),
      ),
      ("MC2", Gettext.gettext("Modified cellier, drop first step.")),
      (
        "MC11",
        Gettext.gettext("Modified MC1, new last step 'count impossible assignments'."),
      ),
      (
        "MC21",
        Gettext.gettext("Modified MC2, new last step 'count impossible assignments'."),
      ),
      (
        "MC12",
        Gettext.gettext("Modified MC1, step 'count impossible assignments' before last step."),
      ),
      (
        "MC22",
        Gettext.gettext("Modified MC2, step 'count impossible assignments' before last step."),
      ),
      (
        "MC13",
        Gettext.gettext("Modified MC1, build sum of impossible assignment and causalizable equations, choose var with biggest sum."),
      ),
      (
        "MC23",
        Gettext.gettext("Modified MC2, build sum of impossible assignment and causalizable equations, choose var with biggest sum."),
      ),
      (
        "MC231",
        Gettext.gettext("Modified MC23, Two rounds, choose better potentials-set."),
      ),
      (
        "MC3",
        Gettext.gettext("Modified cellier, build sum of impossible assignment and causalizable equations for all vars, choose var with biggest sum."),
      ),
      (
        "MC4",
        Gettext.gettext("Modified cellier, use all heuristics, choose var that occurs most in potential sets"),
      ),
    ))),
    Gettext.gettext("Sets the tearing heuristic to use for Cellier-tearing."),
  )::ConfigFlag

const SCALARIZE_MINMAX =
  CONFIG_FLAG(
    46,
    "scalarizeMinMax",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Scalarizes the builtin min/max reduction operators if true."),
  )::ConfigFlag
const STRICT =
  CONFIG_FLAG(
    47,
    "strict",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Enables stricter enforcement of Modelica language rules."),
  )::ConfigFlag
const SCALARIZE_BINDINGS =
  CONFIG_FLAG(
    48,
    "scalarizeBindings",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Always scalarizes bindings if set."),
  )::ConfigFlag
const CORBA_OBJECT_REFERENCE_FILE_PATH =
  CONFIG_FLAG(
    49,
    "corbaObjectReferenceFilePath",
    NONE(),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Sets the path for corba object reference file if -d=interactiveCorba is used."),
  )::ConfigFlag
const HPCOM_SCHEDULER =
  CONFIG_FLAG(
    50,
    "hpcomScheduler",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("level"),
    NONE(),
    Gettext.gettext("Sets the scheduler for task graph scheduling (list | listr | level | levelfix | ext | metis | mcp | taskdep | tds | bls | rand | none). Default: level."),
  )::ConfigFlag
const HPCOM_CODE =
  CONFIG_FLAG(
    51,
    "hpcomCode",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("openmp"),
    NONE(),
    Gettext.gettext("Sets the code-type produced by hpcom (openmp | pthreads | pthreads_spin | tbb | mpi). Default: openmp."),
  )::ConfigFlag
const REWRITE_RULES_FILE =
  CONFIG_FLAG(
    52,
    "rewriteRulesFile",
    NONE(),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Activates user given rewrite rules for Absyn expressions. The rules are read from the given file and are of the form rewrite(fromExp, toExp);"),
  )::ConfigFlag
const REPLACE_HOMOTOPY =
  CONFIG_FLAG(
    53,
    "replaceHomotopy",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("none"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("Default, do not replace homotopy.")),
      ("actual", Gettext.gettext("Replace homotopy(actual, simplified) with actual.")),
      (
        "simplified",
        Gettext.gettext("Replace homotopy(actual, simplified) with simplified."),
      ),
    ))),
    Gettext.gettext("Replaces homotopy(actual, simplified) with the actual expression or the simplified expression. Good for debugging models which use homotopy. The default is to not replace homotopy."),
  )::ConfigFlag
const GENERATE_SYMBOLIC_JACOBIAN =
  CONFIG_FLAG(
    54,
    "generateSymbolicJacobian",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Generates symbolic Jacobian matrix, where der(x) is differentiated w.r.t. x. This matrix can be used by dassl or ida solver with simulation flag '-jacobian'."),
  )::ConfigFlag
const GENERATE_SYMBOLIC_LINEARIZATION =
  CONFIG_FLAG(
    55,
    "generateSymbolicLinearization",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Generates symbolic linearization matrices A,B,C,D for linear model:\\n\\t\\t:math:`\\\\dot x = Ax + Bu`\\n\\t\\t:math:`y = Cx +Du`"),
  )::ConfigFlag
const INT_ENUM_CONVERSION =
  CONFIG_FLAG(
    56,
    "intEnumConversion",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Allow Integer to enumeration conversion."),
  )::ConfigFlag
const PROFILING_LEVEL =
  CONFIG_FLAG(
    57,
    "profiling",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("none"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("Generate code without profiling")),
      (
        "blocks",
        Gettext.gettext("Generate code for profiling function calls as well as linear and non-linear systems of equations"),
      ),
      (
        "blocks+html",
        Gettext.gettext("Like blocks, but also run xsltproc and gnuplot to generate an html report"),
      ),
      (
        "all",
        Gettext.gettext("Generate code for profiling of all functions and equations"),
      ),
      (
        "all_perf",
        Gettext.gettext("Generate code for profiling of all functions and equations with additional performance data using the papi-interface (cpp-runtime)"),
      ),
      (
        "all_stat",
        Gettext.gettext("Generate code for profiling of all functions and equations with additional statistics (cpp-runtime)"),
      ),
    ))),
    Gettext.gettext("Sets the profiling level to use. Profiled equations and functions record execution time and count for each time step taken by the integrator."),
  )::ConfigFlag
const RESHUFFLE =
  CONFIG_FLAG(
    58,
    "reshuffle",
    NONE(),
    EXTERNAL(),
    INT_FLAG(1),
    NONE(),
    Gettext.gettext("sets tolerance of reshuffling algorithm: 1: conservative, 2: more tolerant, 3 resolve all"),
  )::ConfigFlag
const GENERATE_DYN_OPTIMIZATION_PROBLEM =
  CONFIG_FLAG(
    59,
    "gDynOpt",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Generate dynamic optimization problem based on annotation approach."),
  )::ConfigFlag

const MAX_SIZE_FOR_SOLVE_LINIEAR_SYSTEM =
  CONFIG_FLAG(
    60,
    "maxSizeSolveLinearSystem",
    NONE(),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Max size for solveLinearSystem."),
  )::ConfigFlag
const CPP_FLAGS =
  CONFIG_FLAG(
    61,
    "cppFlags",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(list("")),
    NONE(),
    Gettext.gettext("Sets extra flags for compilation with the C++ compiler (e.g. +cppFlags=-O3,-Wall)"),
  )::ConfigFlag
const REMOVE_SIMPLE_EQUATIONS =
  CONFIG_FLAG(
    62,
    "removeSimpleEquations",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("default"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("Disables module")),
      (
        "default",
        Gettext.gettext("Performs alias elimination and removes constant variables. Default case uses in preOpt phase the fastAcausal and in postOpt phase the causal implementation."),
      ),
      (
        "causal",
        Gettext.gettext("Performs alias elimination and removes constant variables. Causal implementation."),
      ),
      (
        "fastAcausal",
        Gettext.gettext("Performs alias elimination and removes constant variables. fastImplementation fastAcausal."),
      ),
      (
        "allAcausal",
        Gettext.gettext("Performs alias elimination and removes constant variables. Implementation allAcausal."),
      ),
      ("new", Gettext.gettext("New implementation (experimental)")),
    ))),
    Gettext.gettext("Specifies method that removes simple equations."),
  )::ConfigFlag
const DYNAMIC_TEARING =
  CONFIG_FLAG(
    63,
    "dynamicTearing",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("false"),
    SOME(STRING_DESC_OPTION(list(
      ("false", Gettext.gettext("No dynamic tearing.")),
      ("true", Gettext.gettext("Dynamic tearing for linear and nonlinear systems.")),
      ("linear", Gettext.gettext("Dynamic tearing only for linear systems.")),
      ("nonlinear", Gettext.gettext("Dynamic tearing only for nonlinear systems.")),
    ))),
    Gettext.gettext("Activates dynamic tearing (TearingSet can be changed automatically during runtime, strict set vs. casual set.)"),
  )::ConfigFlag
const SYM_SOLVER =
  CONFIG_FLAG(
    64,
    "symSolver",
    NONE(),
    EXTERNAL(),
    ENUM_FLAG(0, list(("none", 0), ("impEuler", 1), ("expEuler", 2))),
    SOME(STRING_OPTION(list("none", "impEuler", "expEuler"))),
    Gettext.gettext("Activates symbolic implicit solver (original system is not changed)."),
  )::ConfigFlag
const LOOP2CON =
  CONFIG_FLAG(
    65,
    "loop2con",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("none"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("Disables module")),
      ("lin", Gettext.gettext("linear loops --> constraints")),
      ("noLin", Gettext.gettext("no linear loops --> constraints")),
      ("all", Gettext.gettext("loops --> constraints")),
    ))),
    Gettext.gettext("Specifies method that transform loops in constraints. hint: using initial guess from file!"),
  )::ConfigFlag
const FORCE_TEARING =
  CONFIG_FLAG(
    66,
    "forceTearing",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Use tearing set even if it is not smaller than the original component."),
  )::ConfigFlag
const SIMPLIFY_LOOPS =
  CONFIG_FLAG(
    67,
    "simplifyLoops",
    NONE(),
    EXTERNAL(),
    INT_FLAG(0),
    SOME(STRING_DESC_OPTION(list(
      ("0", Gettext.gettext("do nothing")),
      ("1", Gettext.gettext("special modification of residual expressions")),
      (
        "2",
        Gettext.gettext("special modification of residual expressions with helper variables"),
      ),
    ))),
    Gettext.gettext("Simplify algebraic loops."),
  )::ConfigFlag
const RTEARING =
  CONFIG_FLAG(
    68,
    "recursiveTearing",
    NONE(),
    EXTERNAL(),
    INT_FLAG(0),
    SOME(STRING_DESC_OPTION(list(
      ("0", Gettext.gettext("do nothing")),
      ("1", Gettext.gettext("linear tearing set of size 1")),
      ("2", Gettext.gettext("linear tearing")),
    ))),
    Gettext.gettext("Inline and repeat tearing."),
  )::ConfigFlag
const FLOW_THRESHOLD =
  CONFIG_FLAG(
    69,
    "flowThreshold",
    NONE(),
    EXTERNAL(),
    REAL_FLAG(1e-7),
    NONE(),
    Gettext.gettext("Sets the minium threshold for stream flow rates"),
  )::ConfigFlag
const MATRIX_FORMAT =
  CONFIG_FLAG(
    70,
    "matrixFormat",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("dense"),
    NONE(),
    Gettext.gettext("Sets the matrix format type in cpp runtime which should be used (dense | sparse ). Default: dense."),
  )::ConfigFlag
const PARTLINTORN =
  CONFIG_FLAG(
    71,
    "partlintorn",
    NONE(),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the limit for partitionin of linear torn systems."),
  )::ConfigFlag
const INIT_OPT_MODULES =
  CONFIG_FLAG(
    72,
    "initOptModules",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(list(
      "simplifyComplexFunction",
      "tearingSystem",
      "solveSimpleEquations",
      "calculateStrongComponentJacobians",
      "simplifyAllExpressions",
      "collapseArrayExpressions",
    )),
    SOME(STRING_DESC_OPTION(list(
      (
        "calculateStrongComponentJacobians",
        Gettext.gettext("Generates analytical jacobian for torn linear and non-linear strong components. By default linear components and non-linear components with user-defined function calls are skipped. See also debug flags: LSanalyticJacobian, NLSanalyticJacobian and forceNLSanalyticJacobian"),
      ),
      ("collapseArrayExpressions", collapseArrayExpressionsText),
      (
        "constantLinearSystem",
        Gettext.gettext("Evaluates constant linear systems (a*x+b*y=c; d*x+e*y=f; a,b,c,d,e,f are constants) at compile-time."),
      ),
      ("extendDynamicOptimization", Gettext.gettext("Move loops to constraints.")),
      (
        "generateHomotopyComponents",
        Gettext.gettext("Finds the parts of the DAE that have to be handled by the homotopy solver and creates a strong component out of it."),
      ),
      (
        "inlineHomotopy",
        Gettext.gettext("Experimental: Inlines the homotopy expression to allow symbolic simplifications."),
      ),
      (
        "inputDerivativesUsed",
        Gettext.gettext("Checks if derivatives of inputs are need to calculate the model."),
      ),
      ("recursiveTearing", Gettext.notrans("inline and repeat tearing")),
      (
        "reduceDynamicOptimization",
        Gettext.notrans("Removes equations which are not needed for the calculations of cost and constraints. This module requires -d=reduceDynOpt."),
      ),
      (
        "replaceHomotopyWithSimplified",
        Gettext.notrans("Replaces the homotopy expression homotopy(actual, simplified) with the simplified part."),
      ),
      (
        "simplifyAllExpressions",
        Gettext.notrans("Does simplifications on all expressions."),
      ),
      (
        "simplifyComplexFunction",
        Gettext.notrans("Some simplifications on complex functions (complex refers to the internal data structure)"),
      ),
      (
        "simplifyConstraints",
        Gettext.notrans("Rewrites nonlinear constraints into box constraints if possible. This module requires +gDynOpt."),
      ),
      (
        "simplifyLoops",
        Gettext.notrans("Simplifies algebraic loops. This modules requires +simplifyLoops."),
      ),
      ("solveSimpleEquations", Gettext.notrans("Solves simple equations")),
      ("tearingSystem", Gettext.notrans("For method selection use flag tearingMethod.")),
      (
        "wrapFunctionCalls",
        Gettext.gettext("This module introduces variables for each function call and substitutes all these calls with the newly introduced variables."),
      ),
    ))),
    Gettext.gettext("Sets the initialization optimization modules to use in the back end. See --help=optmodules for more info."),
  )::ConfigFlag
const MAX_MIXED_DETERMINED_INDEX =
  CONFIG_FLAG(
    73,
    "maxMixedDeterminedIndex",
    NONE(),
    EXTERNAL(),
    INT_FLAG(10),
    NONE(),
    Gettext.gettext("Sets the maximum mixed-determined index that is handled by the initialization."),
  )::ConfigFlag
const USE_LOCAL_DIRECTION =
  CONFIG_FLAG(
    74,
    "useLocalDirection",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Keeps the input/output prefix for all variables in the flat model, not only top-level ones."),
  )::ConfigFlag
const DEFAULT_OPT_MODULES_ORDERING =
  CONFIG_FLAG(
    75,
    "defaultOptModulesOrdering",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("If this is activated, then the specified pre-/post-/init-optimization modules will be rearranged to the recommended ordering."),
  )::ConfigFlag
const PRE_OPT_MODULES_ADD =
  CONFIG_FLAG(
    76,
    "preOptModules+",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Enables additional pre-optimization modules, e.g. --preOptModules+=module1,module2 would additionally enable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const PRE_OPT_MODULES_SUB =
  CONFIG_FLAG(
    77,
    "preOptModules-",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Disables a list of pre-optimization modules, e.g. --preOptModules-=module1,module2 would disable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const POST_OPT_MODULES_ADD =
  CONFIG_FLAG(
    78,
    "postOptModules+",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Enables additional post-optimization modules, e.g. --postOptModules+=module1,module2 would additionally enable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const POST_OPT_MODULES_SUB =
  CONFIG_FLAG(
    79,
    "postOptModules-",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Disables a list of post-optimization modules, e.g. --postOptModules-=module1,module2 would disable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const INIT_OPT_MODULES_ADD =
  CONFIG_FLAG(
    80,
    "initOptModules+",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Enables additional init-optimization modules, e.g. --initOptModules+=module1,module2 would additionally enable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const INIT_OPT_MODULES_SUB =
  CONFIG_FLAG(
    81,
    "initOptModules-",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Disables a list of init-optimization modules, e.g. --initOptModules-=module1,module2 would disable module1 and module2. See --help=optmodules for more info."),
  )::ConfigFlag
const PERMISSIVE =
  CONFIG_FLAG(
    82,
    "permissive",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Disables some error checks to allow erroneous models to compile."),
  )::ConfigFlag
const HETS =
  CONFIG_FLAG(
    83,
    "hets",
    NONE(),
    INTERNAL(),
    STRING_FLAG("none"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("do nothing")),
      ("derCalls", Gettext.gettext("sort terms based on der-calls")),
    ))),
    Gettext.gettext("Heuristic equation terms sort"),
  )::ConfigFlag
const DEFAULT_CLOCK_PERIOD =
  CONFIG_FLAG(
    84,
    "defaultClockPeriod",
    NONE(),
    INTERNAL(),
    REAL_FLAG(1.0),
    NONE(),
    Gettext.gettext("Sets the default clock period (in seconds) for state machines (default: 1.0)."),
  )::ConfigFlag
const INST_CACHE_SIZE =
  CONFIG_FLAG(
    85,
    "instCacheSize",
    NONE(),
    EXTERNAL(),
    INT_FLAG(25343),
    NONE(),
    Gettext.gettext("Sets the size of the internal hash table used for instantiation caching."),
  )::ConfigFlag
const MAX_SIZE_LINEAR_TEARING =
  CONFIG_FLAG(
    86,
    "maxSizeLinearTearing",
    NONE(),
    EXTERNAL(),
    INT_FLAG(200),
    NONE(),
    Gettext.gettext("Sets the maximum system size for tearing of linear systems (default 200)."),
  )::ConfigFlag
const MAX_SIZE_NONLINEAR_TEARING =
  CONFIG_FLAG(
    87,
    "maxSizeNonlinearTearing",
    NONE(),
    EXTERNAL(),
    INT_FLAG(10000),
    NONE(),
    Gettext.gettext("Sets the maximum system size for tearing of nonlinear systems (default 10000)."),
  )::ConfigFlag
const NO_TEARING_FOR_COMPONENT =
  CONFIG_FLAG(
    88,
    "noTearingForComponent",
    NONE(),
    EXTERNAL(),
    INT_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Deactivates tearing for the specified components.\\nUse '-d=tearingdump' to find out the relevant indexes."),
  )::ConfigFlag
const CT_STATE_MACHINES =
  CONFIG_FLAG(
    89,
    "ctStateMachines",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Experimental: Enable continuous-time state machine prototype"),
  )::ConfigFlag
const DAE_MODE =
  CONFIG_FLAG(
    90,
    "daeMode",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Generates code to simulate models in DAE mode. The whole system is passed directly to the DAE solver SUNDIALS/IDA and no algebraic solver is involved in the simulation process."),
  )::ConfigFlag
const INLINE_METHOD =
  CONFIG_FLAG(
    91,
    "inlineMethod",
    NONE(),
    EXTERNAL(),
    ENUM_FLAG(1, list(("replace", 1), ("append", 2))),
    SOME(STRING_OPTION(list("replace", "append"))),
    Gettext.gettext(
      "Sets the inline method to use.\\n" +
      "replace : This method inlines by replacing in place all expressions. Might lead to very long expression.\\n" +
      "append  : This method inlines by adding additional variables to the whole system. Might lead to much bigger system.",
    ),
  )::ConfigFlag
const SET_TEARING_VARS =
  CONFIG_FLAG(
    92,
    "setTearingVars",
    NONE(),
    EXTERNAL(),
    INT_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Sets the tearing variables by its strong component indexes. Use '-d=tearingdump' to find out the relevant indexes.\\nUse following format: '--setTearingVars=(sci,n,t1,...,tn)*', with sci = strong component index, n = number of tearing variables, t1,...tn = tearing variables.\\nE.g.: '--setTearingVars=4,2,3,5' would select variables 3 and 5 in strong component 4."),
  )::ConfigFlag
const SET_RESIDUAL_EQNS =
  CONFIG_FLAG(
    93,
    "setResidualEqns",
    NONE(),
    EXTERNAL(),
    INT_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Sets the residual equations by its strong component indexes. Use '-d=tearingdump' to find out the relevant indexes for the collective equations.\\nUse following format: '--setResidualEqns=(sci,n,r1,...,rn)*', with sci = strong component index, n = number of residual equations, r1,...rn = residual equations.\\nE.g.: '--setResidualEqns=4,2,3,5' would select equations 3 and 5 in strong component 4.\\nOnly works in combination with 'setTearingVars'."),
  )::ConfigFlag
const IGNORE_COMMAND_LINE_OPTIONS_ANNOTATION =
  CONFIG_FLAG(
    94,
    "ignoreCommandLineOptionsAnnotation",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Ignores the command line options specified as annotation in the class."),
  )::ConfigFlag
const CALCULATE_SENSITIVITIES =
  CONFIG_FLAG(
    95,
    "calculateSensitivities",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Generates sensitivities variables and matrixes."),
  )::ConfigFlag
const ALARM =
  CONFIG_FLAG(
    96,
    "alarm",
    SOME("r"),
    EXTERNAL(),
    INT_FLAG(0),
    NONE(),
    Gettext.gettext("Sets the number seconds until omc timeouts and exits. Used by the testing framework to terminate infinite running processes."),
  )::ConfigFlag
const TOTAL_TEARING =
  CONFIG_FLAG(
    97,
    "totalTearing",
    NONE(),
    EXTERNAL(),
    INT_LIST_FLAG(nil),
    NONE(),
    Gettext.gettext("Activates total tearing (determination of all possible tearing sets) for the specified components.\\nUse '-d=tearingdump' to find out the relevant indexes."),
  )::ConfigFlag
const IGNORE_SIMULATION_FLAGS_ANNOTATION =
  CONFIG_FLAG(
    98,
    "ignoreSimulationFlagsAnnotation",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Ignores the simulation flags specified as annotation in the class."),
  )::ConfigFlag
const DYNAMIC_TEARING_FOR_INITIALIZATION =
  CONFIG_FLAG(
    99,
    "dynamicTearingForInitialization",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Enable Dynamic Tearing also for the initialization system."),
  )::ConfigFlag
const PREFER_TVARS_WITH_START_VALUE =
  CONFIG_FLAG(
    100,
    "preferTVarsWithStartValue",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Prefer tearing variables with start value for initialization."),
  )::ConfigFlag
const EQUATIONS_PER_FILE =
  CONFIG_FLAG(
    101,
    "equationsPerFile",
    NONE(),
    EXTERNAL(),
    INT_FLAG(2000),
    NONE(),
    Gettext.gettext("Generate code for at most this many equations per C-file (partially implemented in the compiler)."),
  )::ConfigFlag
const EVALUATE_FINAL_PARAMS =
  CONFIG_FLAG(
    102,
    "evaluateFinalParameters",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Evaluates all the final parameters in addition to parameters with annotation(Evaluate=true)."),
  )::ConfigFlag
const EVALUATE_PROTECTED_PARAMS =
  CONFIG_FLAG(
    103,
    "evaluateProtectedParameters",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Evaluates all the protected parameters in addition to parameters with annotation(Evaluate=true)."),
  )::ConfigFlag
const REPLACE_EVALUATED_PARAMS =
  CONFIG_FLAG(
    104,
    "replaceEvaluatedParameters",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Replaces all the evaluated parameters in the DAE."),
  )::ConfigFlag
const CONDENSE_ARRAYS =
  CONFIG_FLAG(
    105,
    "condenseArrays",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(true),
    NONE(),
    Gettext.gettext("Sets whether array expressions containing function calls are condensed or not."),
  )::ConfigFlag
const WFC_ADVANCED =
  CONFIG_FLAG(
    106,
    "wfcAdvanced",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("wrapFunctionCalls ignores more then default cases, e.g. exp, sin, cos, log, (experimental flag)"),
  )::ConfigFlag
const GRAPHICS_EXP_MODE =
  CONFIG_FLAG(
    107,
    "graphicsExpMode",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Sets whether we are in graphics exp mode (evaluating icons)."),
  )::ConfigFlag
const TEARING_STRICTNESS =
  CONFIG_FLAG(
    108,
    "tearingStrictness",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("strict"),
    SOME(STRING_DESC_OPTION(list(
      (
        "casual",
        Gettext.gettext("Loose tearing rules using ExpressionSolve to determine the solvability instead of considering the partial derivative. Allows to solve for everything that is analytically possible. This could lead to singularities during simulation."),
      ),
      (
        "strict",
        Gettext.gettext("Robust tearing rules by consideration of the partial derivative. Allows to divide by parameters that are not equal to or close to zero."),
      ),
      (
        "veryStrict",
        Gettext.gettext("Very strict tearing rules that do not allow to divide by any parameter. Use this if you aim at overriding parameters after compilation with values equal to or close to zero."),
      ),
    ))),
    Gettext.gettext("Sets the strictness of the tearing method regarding the solvability restrictions."),
  )::ConfigFlag
const INTERACTIVE =
  CONFIG_FLAG(
    109,
    "interactive",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("none"),
    SOME(STRING_DESC_OPTION(list(
      ("none", Gettext.gettext("do nothing")),
      (
        "corba",
        Gettext.gettext("Starts omc as a server listening on the socket interface."),
      ),
      ("tcp", Gettext.gettext("Starts omc as a server listening on the Corba interface.")),
      (
        "zmq",
        Gettext.gettext("Starts omc as a ZeroMQ server listening on the socket interface."),
      ),
    ))),
    Gettext.gettext("Sets the interactive mode for omc."),
  )::ConfigFlag
const ZEROMQ_FILE_SUFFIX =
  CONFIG_FLAG(
    110,
    "zeroMQFileSuffix",
    SOME("z"),
    EXTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("Sets the file suffix for zeroMQ port file if --interactive=zmq is used."),
  )::ConfigFlag
const HOMOTOPY_APPROACH =
  CONFIG_FLAG(
    111,
    "homotopyApproach",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("equidistantGlobal"),
    SOME(STRING_DESC_OPTION(list(
      (
        "equidistantLocal",
        Gettext.gettext("Local homotopy approach with equidistant lambda steps. The homotopy parameter only effects the local strongly connected component."),
      ),
      (
        "adaptiveLocal",
        Gettext.gettext("Local homotopy approach with adaptive lambda steps. The homotopy parameter only effects the local strongly connected component."),
      ),
      (
        "equidistantGlobal",
        Gettext.gettext("Default, global homotopy approach with equidistant lambda steps. The homotopy parameter effects the entire initialization system."),
      ),
      (
        "adaptiveGlobal",
        Gettext.gettext("Global homotopy approach with adaptive lambda steps. The homotopy parameter effects the entire initialization system."),
      ),
    ))),
    Gettext.gettext("Sets the homotopy approach."),
  )::ConfigFlag
const IGNORE_REPLACEABLE =
  CONFIG_FLAG(
    112,
    "ignoreReplaceable",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Sets whether to ignore replaceability or not when redeclaring."),
  )::ConfigFlag
const LABELED_REDUCTION =
  CONFIG_FLAG(
    113,
    "labeledReduction",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Turns on labeling and reduce terms to do whole process of reduction."),
  )::ConfigFlag
const DISABLE_EXTRA_LABELING =
  CONFIG_FLAG(
    114,
    "disableExtraLabeling",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Disable adding extra label into the whole experssion with more than one term and +,- operations."),
  )::ConfigFlag
const LOAD_MSL_MODEL =
  CONFIG_FLAG(
    115,
    "loadMSLModel",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Used to know loadFile doesn't need to be called in cpp-runtime (for labeled model reduction)."),
  )::ConfigFlag
const Load_PACKAGE_FILE =
  CONFIG_FLAG(
    116,
    "loadPackageFile",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("used when the outside name is different with the inside name of the packge, in cpp-runtime (for labeled model reduction)."),
  )::ConfigFlag
const BUILDING_FMU =
  CONFIG_FLAG(
    117,
    "",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Is true when building an FMU (so the compiler can look for URIs to package as FMI resources)."),
  )::ConfigFlag
const BUILDING_MODEL =
  CONFIG_FLAG(
    118,
    "",
    NONE(),
    INTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Is true when building a model (as opposed to running a Modelica script)."),
  )::ConfigFlag
const POST_OPT_MODULES_DAE =
  CONFIG_FLAG(
    119,
    "postOptModulesDAE",
    NONE(),
    EXTERNAL(),
    STRING_LIST_FLAG(list(
      "lateInlineFunction",
      "wrapFunctionCalls",
      "simplifysemiLinear",
      "simplifyComplexFunction",
      "removeConstants",
      "simplifyTimeIndepFuncCalls",
      "simplifyAllExpressions",
      "findZeroCrossings",
      "createDAEmodeBDAE",
      "detectDAEmodeSparsePattern",
      "setEvaluationStage",
    )),
    NONE(),
    Gettext.gettext("Sets the optimization modules for the DAEmode in the back end. See --help=optmodules for more info."),
  )::ConfigFlag
#= \"replaceDerCalls\",
=#
const EVAL_LOOP_LIMIT =
  CONFIG_FLAG(
    120,
    "evalLoopLimit",
    NONE(),
    EXTERNAL(),
    INT_FLAG(100000),
    NONE(),
    Gettext.gettext("The loop iteration limit used when evaluating constant function calls."),
  )::ConfigFlag
const EVAL_RECURSION_LIMIT =
  CONFIG_FLAG(
    121,
    "evalRecursionLimit",
    NONE(),
    EXTERNAL(),
    INT_FLAG(256),
    NONE(),
    Gettext.gettext("The recursion limit used when evaluating constant function calls."),
  )::ConfigFlag
const SINGLE_INSTANCE_AGLSOLVER =
  CONFIG_FLAG(
    122,
    "singleInstanceAglSolver",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Sets to instantiate only  one algebraic loop solver all algebraic loops"),
  )::ConfigFlag
const SHOW_STRUCTURAL_ANNOTATIONS =
  CONFIG_FLAG(
    123,
    "showStructuralAnnotations",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Show annotations affecting the solution process in the flattened code."),
  )::ConfigFlag
const INITIAL_STATE_SELECTION =
  CONFIG_FLAG(
    124,
    "initialStateSelection",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Activates the state selection inside initialization to avoid singularities."),
  )::ConfigFlag
const LINEARIZATION_DUMP_LANGUAGE =
  CONFIG_FLAG(
    125,
    "linearizationDumpLanguage",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("modelica"),
    SOME(STRING_OPTION(list("modelica", "matlab", "julia", "python"))),
    Gettext.gettext("Sets the target language for the produced code of linearization. Only works with '--generateSymbolicLinearization' and 'linearize(modelName)'."),
  )::ConfigFlag
const NO_ASSC =
  CONFIG_FLAG(
    126,
    "noASSC",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Disables analytical to structural singularity conversion."),
  )::ConfigFlag
const FULL_ASSC =
  CONFIG_FLAG(
    127,
    "fullASSC",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Enables full equation replacement for BLT transformation from the ASSC algorithm."),
  )::ConfigFlag
const USE_ZEROMQ_IN_SIM =
  CONFIG_FLAG(
    128,
    "useZeroMQInSim",
    NONE(),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Configures to use zeroMQ in simulation runtime to exchange information via ZeroMQ with other applications"),
  )::ConfigFlag
const ZEROMQ_PUB_PORT =
  CONFIG_FLAG(
    129,
    "zeroMQPubPort",
    NONE(),
    EXTERNAL(),
    INT_FLAG(3203),
    NONE(),
    Gettext.gettext("Configures port number for simulation runtime to send information via ZeroMQ"),
  )::ConfigFlag
const ZEROMQ_SUB_PORT =
  CONFIG_FLAG(
    130,
    "zeroMQSubPort",
    NONE(),
    EXTERNAL(),
    INT_FLAG(3204),
    NONE(),
    Gettext.gettext("Configures port number for simulation runtime to receive information via ZeroMQ"),
  )::ConfigFlag
const ZEROMQ_JOB_ID =
  CONFIG_FLAG(
    131,
    "zeroMQJOBID",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("empty"),
    NONE(),
    Gettext.gettext("Configures the ID with which the omc api call is labelled for zeroMQ communication."),
  )::ConfigFlag
const ZEROMQ_SERVER_ID =
  CONFIG_FLAG(
    132,
    "zeroMQServerID",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("empty"),
    NONE(),
    Gettext.gettext("Configures the ID with which server application is labelled for zeroMQ communication."),
  )::ConfigFlag
const ZEROMQ_CLIENT_ID =
  CONFIG_FLAG(
    133,
    "zeroMQClientID",
    NONE(),
    EXTERNAL(),
    STRING_FLAG("empty"),
    NONE(),
    Gettext.gettext("Configures the ID with which the client application is labelled for zeroMQ communication."),
  )::ConfigFlag
const FMI_VERSION =
  CONFIG_FLAG(
    134,
    "",
    NONE(),
    INTERNAL(),
    STRING_FLAG(""),
    NONE(),
    Gettext.gettext("returns the FMI Version either 1.0 or 2.0."),
  )::ConfigFlag
const FLAT_MODELICA =
  CONFIG_FLAG(
    135,
    "flatModelica",
    SOME("f"),
    EXTERNAL(),
    BOOL_FLAG(false),
    NONE(),
    Gettext.gettext("Outputs experimental flat Modelica."),
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
  local outValue::Bool
  local debug_flags::Array{Bool}
  local flags::Flag
  local index::Int
  @match DEBUG_FLAG(index = index) = inFlag
  flags = getFlags()
  @match FLAGS(debugFlags = debug_flags) = flags
  outValue = arrayGet(debug_flags, index)
  return outValue
end

"""Returns the value of a configuration flag."""
function getConfigValue(inFlag::ConfigFlag)::FlagData
  local outValue::FlagData

  local config_flags::Array{FlagData}
  local index::Int
  local flags::Flag
  local name::String

  @match CONFIG_FLAG(name = name, index = index) = inFlag
  @assign flags = getFlags()
  @match FLAGS(configFlags = config_flags) = flags
  @assign outValue = arrayGet(config_flags, index)
  return outValue
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

"""Returns the value of an integer configuration flag."""
function getConfigIntList(inFlag::ConfigFlag)::List{Integer}
  local outValue::List{Integer}

  @match INT_LIST_FLAG(data = outValue) = getConfigValue(inFlag)
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
function getConfigEnum(inFlag::ConfigFlag)::Integer
  local outValue::Integer

  @match ENUM_FLAG(data = outValue) = getConfigValue(inFlag)
  return outValue
end

@exportAll()
end
