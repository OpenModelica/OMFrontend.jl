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

@UniontypeDecl Replaceable

module ConnectorType

import ..Frontend.NFType

const TYPE = Int8

using MetaModelica
using ExportAll

const NON_CONNECTOR::Int8 = 0
const POTENTIAL::Int8 = intBitLShift(1, 0) #= A connector element without a prefix. =#
const FLOW::Int8 = intBitLShift(1, 1) #= A connector element with flow prefix. =#
const STREAM::Int8 = intBitLShift(1, 2) #= A connector element with stream prefix. =#
const POTENTIALLY_PRESENT::Int8 = intBitLShift(1, 3) #= An element declared inside an expandable connector. =#
const VIRTUAL::Int8 = intBitLShift(1, 4) #= A virtual connector used in a connection. =#
const CONNECTOR::Int8 = intBitLShift(1, 5) #= A non-expandable connector that contains elements. =#
const EXPANDABLE::Int8 = intBitLShift(1, 6) #= An expandable connector. =#
#=  flow/stream =#
const FLOW_STREAM_MASK::Int8 = intBitOr(FLOW, STREAM)
#=  potential/flow/stream =#
const PREFIX_MASK::Int8 = intBitOr(POTENTIAL, FLOW_STREAM_MASK)
#=  Some kind of connector, where anything inside an expandable connector also counts. =#
const CONNECTOR_MASK::Int8 = intBitOr(CONNECTOR, intBitOr(EXPANDABLE, POTENTIALLY_PRESENT))
#=  An element in an expandable connector. =#
const UNDECLARED_MASK::Int8 = intBitOr(VIRTUAL, POTENTIALLY_PRESENT)
@exportAll()
end

function fromSCode(scodeCty::SCode.ConnectorType)::Int
  local cty::Int
  cty = begin
    @match scodeCty begin
      SCode.POTENTIAL(__) => begin
        0
      end
      SCode.FLOW(__) => begin
        ConnectorType.FLOW
      end
      SCode.STREAM(__) => begin
        ConnectorType.STREAM
      end
    end
  end
  return cty
end

function toDAE(cty::T)::DAE.ConnectorType where {T <: Integer}
  local dcty::DAE.ConnectorType
  if intBitAnd(cty, ConnectorType.POTENTIAL) > 0
    dcty = DAE.POTENTIAL()
  elseif intBitAnd(cty, ConnectorType.FLOW) > 0
    dcty = DAE.FLOW()
  elseif intBitAnd(cty, ConnectorType.STREAM) > 0
    dcty = DAE.STREAM(NONE())
  else
    dcty = DAE.NON_CONNECTOR()
  end
  return dcty
end

function merge(
  outerCty::T,
  innerCty::T,
  node::InstNode,
  isClass::Bool = false,
)::T where {T <: Integer}
  local cty::T
  #=  If both the outer and the inner has flow or stream, give an error.=#
  if (intBitAnd(outerCty, ConnectorType.FLOW_STREAM_MASK) > 0) && (intBitAnd(innerCty, ConnectorType.FLOW_STREAM_MASK) > 0)
    printPrefixError(toString(outerCty), toString(innerCty), node)
  end
  cty = intBitOr(outerCty, innerCty)
  return cty
end

function isPotential(cty::T)::Bool where {T <: Integer}
  b = intBitAnd(cty, ConnectorType.POTENTIAL) > 0
  return b
end

function setPotential(cty::T)::T where {T <: Integer}
  cty = intBitOr(cty, ConnectorType.POTENTIAL)
  return cty
end

function isFlow(cty::T)::Bool where {T <: Integer}
  local b::Bool
  b = intBitAnd(cty, ConnectorType.FLOW) > 0
  return b
end

function isStream(cty::T)::Bool where {T <: Integer}
  local b::Bool
  b = intBitAnd(cty, ConnectorType.STREAM) > 0
  return b
end

function isFlowOrStream(cty::T)::Bool where {T <: Integer}
  local isFlowOrStream::Bool
  isFlowOrStream = intBitAnd(cty, ConnectorType.FLOW_STREAM_MASK) > 0
  return isFlowOrStream
end

function unsetFlowStream(cty::T)::T where {T <: Integer}
  cty = intBitAnd(cty, intBitNot(ConnectorType.FLOW_STREAM_MASK))
  return cty
end

"""Returns true if the connector type has the connector bit set, otherwise false."""
function isConnector(cty::Int)::Bool
  local isConnector::Bool
  isConnector = intBitAnd(cty::Int8, ConnectorType.CONNECTOR::Int8) > 0
  return isConnector
end

function setConnector(cty::T)::T where {T <: Integer}
  cty = intBitOr(cty, ConnectorType.CONNECTOR)
  return cty
end

"""  Returns true if the connector type has the connector, expandable, or
     potentially present bits set, otherwise false. """
function isConnectorType(cty::T)::Bool where {T <: Integer}
  local isConnector::Bool
  isConnector = cty & ConnectorType.CONNECTOR_MASK > 0
  return isConnector
end

function isExpandable(cty::T)::Bool where {T <: Integer}
  local isExpandable::Bool
  isExpandable = intBitAnd(cty, ConnectorType.EXPANDABLE) > 0
  return isExpandable
end

function setExpandable(cty::T)::T where {T <: Integer}
  cty = intBitOr(cty, ConnectorType.EXPANDABLE)
  return cty
end

"""
  Returns true if the connector type has the potentially present or virtual
  bits set, otherwise false.
"""
function isUndeclared(cty::T)::Bool where {T <: Integer}
  local isExpandableElement::Bool

  @assign isExpandableElement = intBitAnd(cty, ConnectorType.UNDECLARED_MASK) > 0
  return isExpandableElement
end

function isVirtual(cty::T)::Bool where {T <: Integer}
  local isV::Bool
  isV = intBitAnd(cty, ConnectorType.VIRTUAL) > 0
  return isV
end

function isPotentiallyPresent(cty::T)::Bool where {T <: Integer}
  local b::Bool
  b = intBitAnd(cty, ConnectorType.POTENTIALLY_PRESENT) > 0
  return b
end

function setPresent(cty::T)::T where {T <: Integer}
  cty = intBitAnd(cty, intBitNot(ConnectorType.POTENTIALLY_PRESENT))
  return cty
end

function toString(cty::T)::String where {T <: Integer}
  local str::String
  if intBitAnd(cty, ConnectorType.FLOW) > 0
    @assign str = "flow string(cty)"
  elseif intBitAnd(cty, ConnectorType.STREAM) > 0
    @assign str = "stream string(cty)"
  elseif intBitAnd(cty, ConnectorType.EXPANDABLE) > 0
    @assign str = "expandable string(cty)"
  elseif intBitAnd(cty, ConnectorType.POTENTIAL) > 0
    @assign str = "potential string(cty)"
  else
    str = "Unspecified"
  end
  return str
end

function unparse(cty::T)::String where {T <: Integer}
  local str::String

  if intBitAnd(cty, ConnectorType.FLOW) > 0
    @assign str = "flow "
  elseif intBitAnd(cty, ConnectorType.STREAM) > 0
    @assign str = "stream "
  else
    @assign str = ""
  end
  return str
end

function toDebugString(cty::T)::String where {T <: Integer}
  local str::String
  local strl::List{String} = nil
  suffix = "(Number:$cty)"
  if intBitAnd(cty, ConnectorType.POTENTIAL) > 0
    @assign strl = _cons("potential $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.FLOW) > 0
    @assign strl = _cons("flow $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.STREAM) > 0
    @assign strl = _cons("stream $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.POTENTIALLY_PRESENT) > 0
    @assign strl = _cons("potentially present $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.VIRTUAL) > 0
    @assign strl = _cons("virtual $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.CONNECTOR) > 0
    @assign strl = _cons("connector $suffix", strl)
  end
  if intBitAnd(cty, ConnectorType.EXPANDABLE) > 0
    @assign strl = _cons("expandable $suffix", strl)
  end
  @assign str = stringDelimitList(strl, " ")
  return str
end

module Parallelism
  const NON_PARALLEL::Int8 = 1
  const GLOBAL::Int8 = 2
  const LOCAL::Int8 = 3
end

const ParallelismType = Int8

const VariabilityType = Int8
module Variability
const VariabilityType = Int8
const CONSTANT::VariabilityType = 1
const STRUCTURAL_PARAMETER::VariabilityType = 2
const PARAMETER::VariabilityType = 3
const NON_STRUCTURAL_PARAMETER::VariabilityType = 4
const DISCRETE::VariabilityType = 5
const IMPLICITLY_DISCRETE::VariabilityType = 6
const CONTINUOUS::VariabilityType = 7

const variabilityStrings = ["CONSTANT",
                            "STRUCTURAL_PARAMETER",
                            "PARAMETER",
                            "NON_STRUCTURAL_PARAMETER",
                            "DISCRETE",
                            "IMPLICITLY_DISCRETE",
                            "CONTINUOUS",]

function variabilityAsString(var::Int)
  return variabilityStrings[var]
end

end


const DirectionType = Int8
struct DirectionStruct
  NONE::DirectionType
  INPUT::DirectionType
  OUTPUT::DirectionType
end
const Direction = DirectionStruct(1, 2, 3)

const InnerOuterType = Int8
struct InnerOuterStruct
  NOT_INNER_OUTER::InnerOuterType
  INNER::InnerOuterType
  OUTER::InnerOuterType
  INNER_OUTER::InnerOuterType
end

const InnerOuter = InnerOuterStruct(1, 2, 3, 4)

struct VisibilityStruct{T0 <: Int8}
  PUBLIC::T0
  PROTECTED::T0
end

const VisibilityType = Int8
const Visibility = VisibilityStruct{Int8}(1, 2)

@Uniontype Replaceable begin
  @Record REPLACEABLE begin
    constrainingClass::Option{InstNode}
  end

  @Record NOT_REPLACEABLE begin
  end
end

function parallelismFromSCode(scodePar::SCode.Parallelism)::ParallelismType
  local par::ParallelismType
  @assign par = begin
    @match scodePar begin
      SCode.PARGLOBAL(__) => begin
        Parallelism.GLOBAL
      end
      SCode.PARLOCAL(__) => begin
        Parallelism.LOCAL
      end
      SCode.NON_PARALLEL(__) => begin
        Parallelism.NON_PARALLEL
      end
    end
  end
  return par
end

function parallelismToSCode(par)
  local spar
  spar = begin
    @match par begin
      Parallelism.GLOBAL => begin
        SCODE.PARGLOBAL()
      end
      Parallelism.LOCAL => begin
        SCODE.PARLOCAL()
      end
      Parallelism.NON_PARALLEL => begin
        SCode.NON_PARALLEL()
      end
    end
  end
  return spar
end

function parallelismToDAE(par)::DAE.VarParallelism
  local dpar::DAE.VarParallelism
  @assign dpar = begin
    @match par begin
      Parallelism.GLOBAL => begin
        DAE.PARGLOBAL()
      end
      Parallelism.LOCAL => begin
        DAE.PARLOCAL()
      end

      Parallelism.NON_PARALLEL => begin
        DAE.NON_PARALLEL()
      end
    end
  end
  return dpar
end

function parallelismString(par)::String
  local str::String

  @assign str = begin
    @match par begin
      Parallelism.GLOBAL => begin
        "parglobal"
      end

      Parallelism.LOCAL => begin
        "parlocal"
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function unparseParallelism(par)::String
  local str::String

  @assign str = begin
    @match par begin
      Parallelism.GLOBAL => begin
        "parglobal "
      end

      Parallelism.LOCAL => begin
        "parlocal "
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function mergeParallelism(
  outerPar,
  innerPar,
  node::InstNode,
)
  local par

  if outerPar == Parallelism.NON_PARALLEL
    @assign par = innerPar
  elseif innerPar == Parallelism.NON_PARALLEL
    @assign par = outerPar
  elseif innerPar == outerPar
    @assign par = innerPar
  else
    printPrefixError(parallelismString(outerPar), parallelismString(innerPar), node)
  end
  return par
end

function variabilityFromSCode(scodeVar::SCode.Variability)
  local var
  @assign var = begin
    @match scodeVar begin
      SCode.CONST(__) => begin
        Variability.CONSTANT
      end
      SCode.PARAM(__) => begin
        Variability.PARAMETER
      end
      SCode.DISCRETE(__) => begin
        Variability.DISCRETE
      end
      SCode.VAR(__) => begin
        Variability.CONTINUOUS
      end
    end
  end
  return var
end

function variabilityToSCode(var)::SCode.Variability
  local scodeVar::SCode.Variability

  scodeVar = begin
    @match var begin
      Variability.CONSTANT => begin
        SCode.CONST()
      end

      Variability.STRUCTURAL_PARAMETER => begin
        SCode.PARAM()
      end

      Variability.PARAMETER => begin
        SCode.PARAM()
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        SCode.PARAM()
      end

      Variability.DISCRETE => begin
        SCode.DISCRETE()
      end

      _ => begin
        SCode.VAR()
      end
    end
  end
  return scodeVar
end

function variabilityToDAE(var)::DAE.VarKind
  local varKind::DAE.VarKind

  @assign varKind = begin
    @match var begin
      Variability.CONSTANT => begin
        DAE.CONST()
      end

      Variability.STRUCTURAL_PARAMETER => begin
        DAE.PARAM()
      end

      Variability.PARAMETER => begin
        DAE.PARAM()
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        DAE.PARAM()
      end

      Variability.DISCRETE => begin
        DAE.DISCRETE()
      end

      _ => begin
        DAE.VARIABLE()
      end
    end
  end
  return varKind
end

function variabilityToDAEConst(var)::DAE.Const
  local M_const::DAE.Const

  @assign M_const = begin
    @match var begin
      Variability.CONSTANT => begin
        DAE.C_CONST()
      end

      Variability.STRUCTURAL_PARAMETER => begin
        DAE.C_PARAM()
      end

      Variability.PARAMETER => begin
        DAE.C_PARAM()
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        DAE.C_PARAM()
      end

      _ => begin
        DAE.C_VAR()
      end
    end
  end
  return M_const
end

function variabilityString(var)::String
  local str::String

  @assign str = begin
    @match var begin
      Variability.CONSTANT => begin
        "constant"
      end

      Variability.STRUCTURAL_PARAMETER => begin
        "parameter"
      end

      Variability.PARAMETER => begin
        "parameter"
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        "parameter"
      end

      Variability.DISCRETE => begin
        "discrete"
      end

      Variability.IMPLICITLY_DISCRETE => begin
        "discrete"
      end

      Variability.CONTINUOUS => begin
        "continuous"
      end
    end
  end
  return str
end

function unparseVariability(var::VariabilityType, ty::NFType)::String
  local str::String
  @assign str = begin
    @match var begin
      Variability.CONSTANT => begin
        "constant "
      end

      Variability.STRUCTURAL_PARAMETER => begin
        "parameter "
      end

      Variability.PARAMETER => begin
        "parameter "
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        "parameter "
      end

      Variability.DISCRETE => begin
        if isDiscrete(ty)
          ""
        else
          "discrete "
        end
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function variabilityMax(var1::Int8, var2::Int8)::Int8
  local var = if var1 > var2
    var1
  else
    var2
  end
  return var
end

function variabilityMin(var1::Int8, var2::Int8)::Int8
  local var = if var1 > var2
    var2
  else
    var1
  end
  return var
end

function effectiveVariability(inVar)
  local outVar

  @assign outVar = begin
    @match inVar begin
      Variability.STRUCTURAL_PARAMETER => begin
        Variability.PARAMETER
      end

      Variability.NON_STRUCTURAL_PARAMETER => begin
        Variability.PARAMETER
      end

      Variability.IMPLICITLY_DISCRETE => begin
        Variability.DISCRETE
      end

      _ => begin
        inVar
      end
    end
  end
  return outVar
end

function directionFromSCode(scodeDir::Absyn.Direction)
  local dir

  @assign dir = begin
    @match scodeDir begin
      Absyn.INPUT(__) => begin
        Direction.INPUT
      end
      Absyn.OUTPUT(__) => begin
        Direction.OUTPUT
      end
      _ => begin
        Direction.NONE
      end
    end
  end
  return dir
end

function directionToDAE(dir)::DAE.VarDirection
  local ddir::DAE.VarDirection
  @assign ddir = begin
    @match dir begin
      Direction.INPUT => begin
        DAE.INPUT()
      end
      Direction.OUTPUT => begin
        DAE.OUTPUT()
      end
      _ => begin
        DAE.BIDIR()
      end
    end
  end
  return ddir
end

function directionToAbsyn(dir)::Absyn.Direction
  local adir::Absyn.Direction

  @assign adir = begin
    @match dir begin
      Direction.INPUT => begin
        Absyn.INPUT()
      end

      Direction.OUTPUT => begin
        Absyn.OUTPUT()
      end

      _ => begin
        Absyn.BIDIR()
      end
    end
  end
  return adir
end

function directionString(dir)::String
  local str::String

  @assign str = begin
    @match dir begin
      Direction.INPUT => begin
        "input"
      end

      Direction.OUTPUT => begin
        "output"
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function unparseDirection(dir)::String
  local str::String

  @assign str = begin
    @match dir begin
      Direction.INPUT => begin
        "input "
      end

      Direction.OUTPUT => begin
        "output "
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function mergeDirection(
  outerDir,
  innerDir,
  node::InstNode,
  allowSame::Bool = false,
)
  local dir

  if outerDir == Direction.NONE
    @assign dir = innerDir
  elseif innerDir == Direction.NONE
    @assign dir = outerDir
  elseif allowSame && outerDir == innerDir
    @assign dir = innerDir
  else
    printPrefixError(directionString(outerDir), directionString(innerDir), node)
  end
  return dir
end

function innerOuterFromSCode(scodeIO::Absyn.InnerOuter)
  local io
  @assign io = begin
    @match scodeIO begin
      Absyn.NOT_INNER_OUTER(__) => begin
        InnerOuter.NOT_INNER_OUTER
      end
      Absyn.INNER(__) => begin
        InnerOuter.INNER
      end
      Absyn.OUTER(__) => begin
        InnerOuter.OUTER
      end
      Absyn.INNER_OUTER(__) => begin
        InnerOuter.INNER_OUTER
      end
    end
  end
  return io
end

function innerOuterToAbsyn(inIO)::Absyn.InnerOuter
  local outIO::Absyn.InnerOuter

  @assign outIO = begin
    @match inIO begin
      InnerOuter.NOT_INNER_OUTER => begin
        Absyn.NOT_INNER_OUTER()
      end

      InnerOuter.INNER => begin
        Absyn.INNER()
      end

      InnerOuter.OUTER => begin
        Absyn.OUTER()
      end

      InnerOuter.INNER_OUTER => begin
        Absyn.INNER_OUTER()
      end
    end
  end
  return outIO
end

function innerOuterString(io)::String
  local str::String

  @assign str = begin
    @match io begin
      InnerOuter.INNER => begin
        "inner"
      end

      InnerOuter.OUTER => begin
        "outer"
      end

      InnerOuter.INNER_OUTER => begin
        "inner outer"
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function unparseInnerOuter(io)::String
  local str::String

  @assign str = begin
    @match io begin
      InnerOuter.INNER => begin
        "inner "
      end

      InnerOuter.OUTER => begin
        "outer "
      end

      InnerOuter.INNER_OUTER => begin
        "inner outer "
      end

      _ => begin
        ""
      end
    end
  end
  return str
end

function visibilityFromSCode(scodeVis::SCode.Visibility)
  vis = begin
    @match scodeVis begin
      SCode.PUBLIC(__) => begin
        Visibility.PUBLIC
      end
      _ => begin
        Visibility.PROTECTED
      end
    end
  end
  return vis
end

function visibilityToDAE(vis)::DAE.VarVisibility
  local dvis::DAE.VarVisibility = if vis == Visibility.PUBLIC
    DAE.PUBLIC()
  else
    DAE.PROTECTED()
  end
  return dvis
end

function visibilityToSCode(vis)::SCode.Visibility
  local scodeVis::SCode.Visibility = if vis == Visibility.PUBLIC
    SCode.PUBLIC()
  else
    SCode.PROTECTED()
  end
  return scodeVis
end

function visibilityString(vis)::String
  local str::String = if vis == Visibility.PUBLIC
    "public"
  else
    "protected"
  end
  return str
end

function unparseVisibility(vis)::String
  local str::String = if vis == Visibility.PROTECTED
    "protected "
  else
    ""
  end
  return str
end

function mergeVisibility(outerVis, innerVis)::VisibilityType
  local vis = if outerVis == Visibility.PROTECTED
    outerVis
  else
    innerVis
  end
  return vis
end

function unparseReplaceable(repl::Replaceable)::String
  local str::String
  str = begin
    @match repl begin
      REPLACEABLE(__) => begin
        "replaceable "
      end
      _ => begin
        ""
      end
    end
  end
  return str
end

function printPrefixError(outerPrefix::String, innerPrefix::String, node::InstNode)
  Error.addSourceMessage(
    Error.INVALID_TYPE_PREFIX,
    list(outerPrefix, typeName(node), name(node), innerPrefix),
    InstNode_info(node),
  )
  return fail()
end
