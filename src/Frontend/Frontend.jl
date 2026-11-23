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

"""
  Main module.
  This module provides the entry to the translated code and associated tweaks and quirks.
"""
module Frontend

#= Import the parser for precompilation
   We also use it at the top level(!) =#
import OpenModelicaParser
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
import OpenModelicaParser.Absyn
import ..ArrayUtil
import ..ListUtil
import ..SCode
import PrecompileTools
import ConstructionBase
import LinearAlgebra
import Base.@nospecializeinfer

"""Utility functions."""
function toString(vec::Vector{T}) where {T}
  buffer = IOBuffer()
  println(buffer, "[")
  for v in vec
    print(buffer, toString(v), ",")
  end
  println(buffer, "]")
  String(take!(buffer))
end

function toString(vec::List{T}) where {T}
  buffer = IOBuffer()
  println(buffer, "{")
  for v in vec
    println(buffer, toString(v), " ,")
  end
  println(buffer, "}")
  String(take!(buffer))
end

#= Top level functionality =#

include("../Util/Pointer.jl")
include("../Util/System.jl")
include("../Util/Gettext.jl")
include("../Util/ErrorTypes.jl")
include("../Util/ErrorExt.jl")
include("../Util/Error.jl")
import .P_Pointer
const Pointer = P_Pointer.Pointer
include("../Util/Mutable.jl")
include("../Util/utilityMacros.jl")
include("../Util/UnorderedMap.jl")
import .P_UnorderedMap
const UnorderedMap = P_UnorderedMap
include("../Util/UnorderedSet.jl")
import .P_UnorderedSet
const UnorderedSet = P_UnorderedSet
#= Include various utility structures =#
include("../Util/Global.jl")
include("../Util/Settings.jl")
include("../Util/Print.jl")
include("../Util/Util.jl")
include("../Util/StringUtil.jl")
include("../Util/Flags.jl")
include("../Util/FlagsUtil.jl")
#= omc's Config, as far as the frontend asks it. The language standard is the latest (omc's
   default), so Modelica 3.3's synchronous features are allowed (Clock, hold, sample, ...). =#
module Config
  import ..Flags
  synchronousFeaturesAllowed()::Bool = true
  #= omc's LanguageStandard; each value is its --std flag value. =#
  module LanguageStandard
    const V1_x = 10
    const V2_x = 20
    const V3_0 = 30
    const V3_1 = 31
    const V3_2 = 32
    const V3_3 = 33
    const V3_4 = 34
    const V3_5 = 35
    const V3_6 = 36
    const latest = 1000
    const experimental = 9999
  end
  getLanguageStandard()::Int = Flags.getConfigEnum(Flags.LANGUAGE_STANDARD)
  languageStandardAtLeast(std::Int)::Bool = getLanguageStandard() >= std
  languageStandardAtMost(std::Int)::Bool = getLanguageStandard() <= std
end
include("../Util/ExecStat.jl")
include("../Util/IOStreamExt.jl")
include("../Util/IOStream.jl")
include("../Absyn/AbsynUtil.jl")
include("../SCode/SCodeUtil.jl")
include("../SCode/SCodeDump.jl")
include("../SCode/AbsynToSCode.jl")
#= Include interfaces and aliases New Frontend=#
include("../FrontendInterfaces/Interfaces.jl")
include("../FrontendInterfaces/Alias.jl")
include("PerfHelpers.jl")
#= Other modules =#
include("Expression.jl")
include("Type.jl")
include("ComplexType.jl")
include("Prefixes.jl")
include("../FrontendInterfaces/FlatInterfaces.jl")
include("Component.jl")
include("Import.jl")
include("LookupTree.jl")
include("DuplicateTree.jl")
include("ClassTree.jl")
include("Equation.jl")

include("InstNode.jl")
include("Sections.jl")
include("Record.jl")
include("OperatorOverloading.jl")
include("ComponentRef.jl")
include("Binding.jl")
include("Modifier.jl")
include("Ceval.jl")
include("Dimension.jl")
include("Typing.jl")

include("Scalarize.jl")

include("Class.jl")
include("ExpressionIterator.jl")
include("InstUtil.jl")
include("Inst.jl")
include("Algorithm.jl")
include("Statement.jl")
include("Variable.jl")
include("FlatModel.jl")
include("Connector.jl")
include("Connection.jl")
include("Connections.jl")

include("ConnectionSets.jl")

include("CardinalityTable.jl")

include("ConnectEquations.jl")
import .CardinalityTable
include("FunctionDerivative.jl")

include("Function.jl")

include("Subscript.jl")

include("Flatten.jl")

include("Restriction.jl")

include("Lookup.jl")

include("LookupState.jl")

@exportAll
#= Overconstrained connectors =#
include("OCCGraph.jl")
@exportAll
include("BuiltinFuncs.jl")
include("Builtin.jl")
#import ..Builtin
include("BindingExpression.jl")

include("../Util/ModelicaExternalC.jl")
include("EvalFunction.jl")
include("EvalFunctionExt.jl")

include("Call.jl")

include("BuiltinCall.jl")

include("Operator.jl")
#= after Operator.jl: its methods dispatch on OPERATOR =#
include("RerollConnects.jl")

include("TypeCheck.jl")

include("ExpandableConnectors.jl")

include("EvalConstants.jl")

include("ExpandExp.jl")

include("SimplifyModel.jl")
include("SimplifyExp.jl")
include("Package.jl")
#= Model verification =#
include("VerifyModel.jl")
include("checkModel.jl")
include("Inline.jl")
#=  Builtin functions =#
include("RangeIterator.jl")

#= JSON export of FLAT_MODEL (structural-mode components and templates). =#
include("../Export/StructuralModeJSON.jl")

end
