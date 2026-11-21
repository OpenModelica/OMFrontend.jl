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

"""How far `split` scalarizes a connector: `SCALARIZE_NONE`, `SCALARIZE_PREFIX` or `SCALARIZE_ALL` (ordered)."""
const ScalarizeSetting = UInt8
"""`a[2].b[2]` => `{a[2].b[2]}`."""
const SCALARIZE_NONE::ScalarizeSetting = 0x01
"""`a[2].b[2]` => `{a[1].b[2], a[2].b[2]}`: the prefix's arrays are split."""
const SCALARIZE_PREFIX::ScalarizeSetting = 0x02
"""`a[2].b[2]` => `{a[1].b[1], a[1].b[2], a[2].b[1], a[2].b[2]}`: all arrays are split."""
const SCALARIZE_ALL::ScalarizeSetting = 0x03

#= Wrapper to avoid shadowing by the `scalarize` parameter of ScalarizeSetting =#
scalarizeCref(cref::ComponentRef)::List{ComponentRef} = scalarize(cref)

"""Splits a connector into its primitive components."""
#= Connection sets hold scalars also when not scalarizing (FRONTEND_SCALARIZE off): connects in
   for-loops are unrolled per element, so flows added as whole arrays (NONE) never met the
   connected elements and unconnected-flow equations  covered connected elements. =#
function split(
  conn::CONNECTOR,
  scalarize::ScalarizeSetting = SCALARIZE_ALL,
)::List{CONNECTOR}
  local connl::List{CONNECTOR}

  connl = splitImpl(conn.name, conn.ty, conn.face, conn.source, conn.cty, scalarize)
  return connl
end

function hash(conn::CONNECTOR, mod::Int)::Int
  return hash(conn.name, mod)
end

function toString(conn::CONNECTOR)::String
  return toString(conn.name)
end


function Base.string(conn::CONNECTOR)::String
  return toString(conn.name)
end

function name(conn::CONNECTOR)::ComponentRef
  return conn.name
end

function isExpandable(conn::CONNECTOR)::Bool
  return ConnectorType.isExpandable(conn.cty)
end

function isDeleted(conn::CONNECTOR)::Bool
  return isDeleted(conn.name)
end

function setOutside(conn::CONNECTOR)::CONNECTOR
  if conn.face != FACE_OUTSIDE
    conn = CONNECTOR(conn.name, conn.ty, FACE_OUTSIDE, conn.cty, conn.source)
  end
  return conn
end

function isOutside(conn::CONNECTOR)::Bool
  #=  Needed due to #4502
  =#
  return conn.face == FACE_OUTSIDE
end

function isNodeNameEqual(conn1::CONNECTOR, conn2::CONNECTOR)::Bool
  local isEqual::Bool =
    name(node(conn1.name)) ==
    name(node(conn2.name))
  return isEqual
end

function isPrefix(conn1::CONNECTOR, conn2::CONNECTOR)::Bool
  return isPrefix(conn1.name, conn2.name)
end

function isEqual(conn1::CONNECTOR, conn2::CONNECTOR)::Bool
  return isEqual(conn1.name, conn2.name) && conn1.face == conn2.face
end

function variability(conn::CONNECTOR)::VariabilityType
  return variability(component(node(conn.name)))
end

function getType(conn::CONNECTOR)::ModelicaType
  return conn.ty
end

"""Constructs a list of Connectors from a cref or an array of crefs."""
function fromExp(
  exp::Expression,
  source::SourceInfo,
  conns::List{<:CONNECTOR} = nil
)::List{CONNECTOR}
  conns = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        Cons{CONNECTOR}(fromCref(exp.cref, exp.ty, source), conns)
      end
      ARRAY_EXPRESSION(__) => begin
        #= Lets do it in reverse order to keep the test output the same. =#
        for i in reverse(eachindex(exp.elements))
          conns = fromExp(exp.elements[i], source, conns)
        end
        conns
      end
      _ => begin
        Error.assertion(
          false,
          getInstanceName() +
          " got unknown expression " +
          toString(exp),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return conns
end

function fromFacedCref(
  cref::ComponentRef,
  ty::ModelicaType,
  face::Face,
  source::SourceInfo,
)::CONNECTOR
  local nodeVar::InstNode = node(cref)
  local comp::Component
  local cty::ConnectorType.TYPE

  if isComponent(nodeVar)
    comp = component(nodeVar)
    cty = connectorType(comp)
  else
    cty = intBitOr(ConnectorType.VIRTUAL, ConnectorType.POTENTIAL)
  end
  return CONNECTOR(simplifySubscripts(cref), ty, face, cty, source)
end

function fromCref(cref::ComponentRef, ty::ModelicaType, source::SourceInfo)::CONNECTOR
  return fromFacedCref(cref, ty, crefFace(cref), source)
end

function splitImpl2(
  name::ComponentRef,
  face::Face,
  source::SourceInfo,
  comps::List{<:InstNode},
  scalarize::ScalarizeSetting,
  conns::List{<:CONNECTOR},
  dims::List{<:Dimension},
)::List{CONNECTOR}

  local c::Component
  local cref::ComponentRef
  local ty::ModelicaType
  local cty::ConnectorType.TYPE

  for comp in comps
    c = component(comp)
    ty = getType(c)
    cty = connectorType(c)
    if ! isPotentiallyPresent(cty)
      cref = append(
        fromNode(comp, ty),
        name,
      )
      conns = splitImpl(cref, ty, face, source, cty, scalarize, conns, dims)
    end
  end
  return conns
end

function addSubscripts(subscripts::List{Subscript}, conn::CONNECTOR)
  @assign begin
    conn.name = mergeSubscripts(subscripts, conn.name; applyToScope = true)
    conn.ty = subscript(conn.ty, subscripts)
  end
  return conn
end

function splitImpl(
  name::ComponentRef,
  ty::ModelicaType,
  face::Face,
  source::SourceInfo,
  cty::ConnectorType.TYPE,
  scalarize::ScalarizeSetting,
  conns::List{<:CONNECTOR} = nil,
  dims::List{<:Dimension} = nil,
)::List{CONNECTOR} #= accumulated dimensions if splitArrays = false =#
  conns = begin
    local ety::ModelicaType
    local ct::ComplexType
    local tree::ClassTree
    @match ty begin
      TYPE_COMPLEX(complexTy = ct && COMPLEX_CONNECTOR(__)) => begin
        conns = splitImpl2(name, face, source, ct.potentials, scalarize, conns, dims)
        conns = splitImpl2(name, face, source, ct.flows, scalarize, conns, dims)
        conns = splitImpl2(name, face, source, ct.streams, scalarize, conns, dims)
        conns
      end

      TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(__)) => begin
        Cons{CONNECTOR}(CONNECTOR(name, liftArrayLeftList(ty, dims), face, cty, source), conns)
      end

      TYPE_COMPLEX(__) => begin
        tree = classTree(getClass(ty.cls))
        conns = splitImpl2(
          name,
          face,
          source,
          arrayList(getComponents(tree)),
          scalarize,
          conns,
          dims,
        )
        conns
      end

      TYPE_ARRAY(
        elementType = ety && TYPE_COMPLEX(__),
      ) where {(scalarize >= SCALARIZE_PREFIX)} => begin
        for c in scalarizeCref(name)
          conns = splitImpl(c, ety, face, source, cty, scalarize, conns, dims)
        end
        conns
      end

      TYPE_ARRAY(elementType = ety) => begin
        if scalarize == SCALARIZE_ALL
          for c in scalarizeCref(name)
            conns = splitImpl(c, ety, face, source, cty, scalarize, conns, dims)
          end
        else
          if !isEmptyArray(ty)
            conns = splitImpl(
              name,
              ety,
              face,
              source,
              cty,
              scalarize,
              conns,
              listAppend(dims, ty.dimensions),
            )
          end
        end
        conns
      end

      _ => begin
        Cons{CONNECTOR}(CONNECTOR(name, liftArrayLeftList(ty, dims), face, cty, source), conns)
      end
    end
  end
  return conns
end

"""
  Determines whether a cref refers to an inside or outside connector, where
  an outside connector is a connector where the first part of the cref is a
  connector, and an inside connector all other crefs.
"""
function crefFace(cref::ComponentRef)::Face
  local face::Face
  face = begin
    @match cref begin
      COMPONENT_REF_CREF(restCref = COMPONENT_REF_EMPTY(__)) => begin
        FACE_OUTSIDE
      end

      _ => begin
        if isConnector(node(firstNonScope(
          cref,
        )))
          FACE_OUTSIDE
        else
          FACE_INSIDE
        end
      end
    end
  end
  #=  Simple identifiers must be connectors and thus outside.
  =#
  #=  Otherwise, check first part of the cref.
  =#
  return face
end

function isArray(conn::CONNECTOR)
  return isArray(conn.ty)
end
