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

#= Import the parser for precompilation=#
#= We also use it at the top level(!) =#
import OMParser
using MetaModelica
using ExportAll
import Absyn
import ArrayUtil
import DAE
import ListUtil
import SCode
import PrecompileTools
import Base.@nospecializeinfer
#= Import the execstat macro from the enclosing module..=#
import ..@EXECSTAT

using MetaModelica:FunctionWrappers

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

include("./Util/ElementSource.jl")
include("./Util/Pointer.jl")
include("./Util/System.jl")
include("./Util/Corba.jl")
include("./Util/Gettext.jl")
include("./Util/ErrorTypes.jl")
include("./Util/ErrorExt.jl")
include("./Util/Error.jl")
import .P_Pointer
const Pointer = P_Pointer.Pointer
include("./Util/Mutable.jl")
include("./Util/utilityMacros.jl")
include("./Util/UnorderedMap.jl")
import .P_UnorderedMap
const UnorderedMap = P_UnorderedMap
include("./Util/UnorderedSet.jl")
import .P_UnorderedSet
const UnorderedSet = P_UnorderedSet
#= Include various utility structures =#
include("./Util/BaseAvlSet.jl")
include("./Util/BaseAvlTree.jl")
include("./Util/BaseHashTable.jl")
include("./Util/BaseHashSet.jl")

include("./Util/Global.jl")
include("./Util/Settings.jl")
include("./Util/Print.jl")
include("./Util/Util.jl")
include("./Util/StringUtil.jl")
include("./Util/Flags.jl")
include("./Util/FlagsUtil.jl")
include("./Util/ExecStat.jl")
include("./Util/IOStreamExt.jl")
include("./Util/IOStream.jl")
include("./AbsynUtil.jl")
include("./SCodeUtil.jl")
include("./SCodeDump.jl")
include("./AbsynToSCode.jl")
#= Minimal Values stub (OMC legacy, needed by toDAEValue in BindingExpression.jl) =#
module Values
  using MetaModelica
  import Absyn
  abstract type Value end
  struct INTEGER_EXPRESSION <: Value; value::Int; end
  struct REAL_EXPRESSION <: Value; value::Float64; end
  struct STRING_EXPRESSION <: Value; value::String; end
  struct BOOL <: Value; value::Bool; end
  struct ENUM_LITERAL <: Value; name::Absyn.Path; index::Int; end
  struct RECORD <: Value; path::Absyn.Path; orderd::List; comp::List; index::Int; end
  struct ARRAY <: Value; valueLst::List; dims::List; end
end

module ValuesUtil
  import ..Values
  using MetaModelica
  function makeArray(vals::List)::Values.Value
    Values.ARRAY(vals, list(listLength(vals)))
  end
  function makeReal(r::Float64)::Values.Value
    Values.REAL_EXPRESSION(r)
  end
end

#=Utility for frontend=#
include("./FrontendUtil/Prefix.jl")
#= Include interfaces and aliases New Frontend=#
include("./FrontendInterfaces/NFInterfaces.jl")
include("./FrontendInterfaces/NFAlias.jl")
include("./NewFrontend/NFPerfHelpers.jl")
#= Other modules =#
include("./NewFrontend/NFExpression.jl")
include("./NewFrontend/NFType.jl")
include("./NewFrontend/NFComplexType.jl")
include("./NewFrontend/NFPrefixes.jl")
include("./NewFrontend/NFComponent.jl")
include("./NewFrontend/NFEquation.jl")

#= Declare the signature for a M_Function early.. =#
abstract type M_Function end
struct M_FUNCTION <: M_Function
  path::Absyn.Path
  node::InstNode
  inputs::List{InstNode}
  outputs::List{InstNode}
  locals::List{InstNode}
  slots::List{Slot}
  returnType::NFType
  attributes::DAE.FunctionAttributes
  derivatives::List{FunctionDerivative}
  status::Pointer
  callCounter::Pointer
end

include("./NewFrontend/NFInstNode.jl")
include("./NewFrontend/NFSections.jl")
include("./NewFrontend/NFRecord.jl")
include("./NewFrontend/NFOperatorOverloading.jl")
include("./NewFrontend/NFCeval.jl")
include("./NewFrontend/NFDimension.jl")
include("./NewFrontend/NFComponentRef.jl")
include("./NewFrontend/NFBinding.jl")
include("./NewFrontend/NFTyping.jl")

include("./NewFrontend/NFScalarize.jl")

include("./NewFrontend/NFClass.jl")
include("./NewFrontend/NFExpressionIterator.jl")
include("./NewFrontend/NFInstUtil.jl")
include("./NewFrontend/NFModifier.jl")
include("./NewFrontend/NFInst.jl")
include("./NewFrontend/NFAlgorithm.jl")
include("./NewFrontend/NFStatement.jl")
include("./NewFrontend/NFVariable.jl")
include("./NewFrontend/NFFlatModel.jl")
include("./NewFrontend/NFConnector.jl")
include("./NewFrontend/NFConnections.jl")
include("./NewFrontend/NFConnection.jl")

include("./NewFrontend/NFConnectionSets.jl")

include("./NewFrontend/NFCardinalityTable.jl")

include("./NewFrontend/NFConnectEquations.jl")
import .NFCardinalityTable
include("./NewFrontend/NFFunctionDerivative.jl")

include("./NewFrontend/NFFunction.jl")

include("./NewFrontend/NFSubscript.jl")

include("./NewFrontend/NFFlatten.jl")

include("./NewFrontend/NFConvertDAE.jl")

include("./NewFrontend/NFRestriction.jl")

include("./NewFrontend/NFImport.jl")



#= Add the trees =#
include("./NewFrontend/LookupTree.jl")
include("./NewFrontend/DuplicateTree.jl")
include("./NewFrontend/JLookupTree.jl")

include("./NewFrontend/NFClassTree.jl")

include("./NewFrontend/NFLookup.jl")

include("./NewFrontend/NFLookupState.jl")

@exportAll
#= For over constrained connectors =#
include("./NewFrontend/NFHashTable.jl")
include("./NewFrontend/NFHashTable3.jl")
include("./NewFrontend/NFHashTableCG.jl")
include("./NewFrontend/NFOCConnectionGraph.jl")
#= End =#
@exportAll
include("./NewFrontend/NFBuiltinFuncs.jl")
include("./NewFrontend/NFBuiltin.jl")
#import ..NFBuiltin
include("./NewFrontend/BindingExpression.jl")
include("./NewFrontend/BindingExpression!.jl")

include("./Util/ModelicaExternalC.jl")
include("./NewFrontend/NFEvalFunction.jl")

include("./NewFrontend/NFCall.jl")

include("./NewFrontend/NFBuiltinCall.jl")

include("./NewFrontend/NFOperator.jl")

include("./NewFrontend/NFTypeCheck.jl")

include("./NewFrontend/NFExpandableConnectors.jl")

include("./NewFrontend/NFEvalConstants.jl")

include("./NewFrontend/NFExpandExp.jl")

#= TODO: NOT IN USE=#
#include("./NewFrontend/NFUnit.jl")
#include("./NewFrontend/NFHashTableCrToUnit.jl")
#include("./NewFrontend/NFUnitCheck.jl")
#=################# =#
include("./NewFrontend/NFSimplifyModel.jl")
include("./NewFrontend/NFSimplifyExp.jl")
include("./NewFrontend/NFPackage.jl")
#= Model verification =#
include("./NewFrontend/NFVerifyModel.jl")
include("./NewFrontend/NFInline.jl")
#=  Builtin functions =#
include("./NewFrontend/NFRangeIterator.jl")


#= Custom memory...=#
include("./Util/Memory.jl")

end
