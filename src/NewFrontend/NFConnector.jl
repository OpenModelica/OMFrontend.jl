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

const Face = (() -> begin #= Enumeration =#
  INSIDE = 1
  OUTSIDE = 2
  () -> (INSIDE; OUTSIDE)
end)()
const FaceType = Int

@Uniontype NFConnector begin
  @Record CONNECTOR begin
    name::ComponentRef
    ty::NFType
    face::FaceType
    cty::ConnectorType.TYPE
    source::DAE.ElementSource
  end
end
const Connector = NFConnector

const ScalarizeSetting = (() -> begin #= Enumeration =#
                    NONE = 1  #= a[2].b[2] => {a[2].b[2]} =#
                    PREFIX = 2  #= a[2].b[2] => {a[1].b[2], a[2].b[2]} =#
                    ALL = 3  #= a[2].b[2] => {a[1].b[1], a[1].b[2], a[2].b[1], a[2].b[2]} =#
                    () -> (NONE; PREFIX; ALL)  #= a[2].b[2] => {a[1].b[1], a[1].b[2], a[2].b[1], a[2].b[2]} =#
                    end)()

const ScalarizeSettingType = Int

#= Wrapper to avoid shadowing by the `scalarize` parameter of ScalarizeSettingType =#
scalarizeCref(cref::ComponentRef)::List{ComponentRef} = scalarize(cref)

"""Splits a connector into its primitive components."""
function split(
  conn::Connector,
  scalarize::ScalarizeSettingType = if Flags.isSet(Flags.NF_SCALARIZE)
    ScalarizeSetting.ALL
  else
    ScalarizeSetting.NONE
  end,
)::List{Connector}
  local connl::List{Connector}

  connl = splitImpl(conn.name, conn.ty, conn.face, conn.source, conn.cty, scalarize)
  return connl
end

function hash(conn::Connector, mod::Int)::Int
  return hash(conn.name, mod)
end

function toString(conn::CONNECTOR)::String
  return toString(conn.name)
end


function Base.string(conn::CONNECTOR)::String
  return toString(conn.name)
end

function name(conn::Connector)::ComponentRef
  return conn.name
end

function isExpandable(conn::Connector)::Bool
  return ConnectorType.isExpandable(conn.cty)
end

function isDeleted(conn::Connector)::Bool
  return isDeleted(conn.name)
end

function setOutside(conn::Connector)::Connector
  if conn.face != Face.OUTSIDE
    conn = CONNECTOR(conn.name, conn.ty, Face.OUTSIDE, conn.cty, conn.source)
  end
  return conn
end

function isInside(conn::Connector)::Bool
  #=  Needed due to #4502
  =#
  return conn.face == Face.INSIDE
end

function isOutside(conn::Connector)::Bool
  #=  Needed due to #4502
  =#
  return conn.face == Face.OUTSIDE
end

function isNodeNameEqual(conn1::Connector, conn2::Connector)::Bool
  local isEqual::Bool =
    name(node(conn1.name)) ==
    name(node(conn2.name))
  return isEqual
end

function isPrefix(conn1::Connector, conn2::Connector)::Bool
  return isPrefix(conn1.name, conn2.name)
end

function isEqual(conn1::Connector, conn2::Connector)::Bool
  return isEqual(conn1.name, conn2.name) && conn1.face == conn2.face
end

function variability(conn::Connector)::VariabilityType
  return variability(component(node(conn.name)))
end

function Connector_getInfo(conn::Connector)::SourceInfo
  return conn.source.info
end

function getType(conn::Connector)::M_Type
  return conn.ty
end

"""Constructs a list of Connectors from a cref or an array of crefs."""
function fromExp(
  exp::Expression,
  source::DAE.ElementSource,
  conns::List{<:Connector} = nil
)::List{Connector}
  conns = begin
    @match exp begin
      CREF_EXPRESSION(__) => begin
        Cons{Connector}(fromCref(exp.cref, exp.ty, source), conns)
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
  ty::NFType,
  face::FaceType,
  source::DAE.ElementSource,
)::Connector
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

function fromCref(cref::ComponentRef, ty::NFType, source::DAE.ElementSource)::Connector
  return fromFacedCref(cref, ty, crefFace(cref), source)
end

function splitImpl2(
  name::ComponentRef,
  face::FaceType,
  source::DAE.ElementSource,
  comps::List{<:InstNode},
  scalarize::ScalarizeSettingType,
  conns::List{<:Connector},
  dims::List{<:Dimension},
)::List{Connector}

  local c::Component
  local cref::ComponentRef
  local ty::M_Type
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

function addSubscripts(subscripts::List{Subscript}, conn::Connector)
  @assign begin
    conn.name = mergeSubscripts(subscripts, conn.name; applyToScope = true)
    conn.ty = subscript(conn.ty, subscripts)
  end
  return conn
end

function splitImpl(
  name::ComponentRef,
  ty::NFType,
  face::FaceType,
  source::DAE.ElementSource,
  cty::ConnectorType.TYPE,
  scalarize::ScalarizeSettingType,
  conns::List{<:Connector} = nil,
  dims::List{<:Dimension} = nil,
)::List{Connector} #= accumulated dimensions if splitArrays = false =#
  conns = begin
    local ety::M_Type
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
        Cons{Connector}(CONNECTOR(name, liftArrayLeftList(ty, dims), face, cty, source), conns)
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
      ) where {(scalarize >= ScalarizeSetting.PREFIX)} => begin
        for c in scalarizeCref(name)
          conns = splitImpl(c, ety, face, source, cty, scalarize, conns, dims)
        end
        conns
      end

      TYPE_ARRAY(elementType = ety) => begin
        if scalarize == ScalarizeSetting.ALL
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
        Cons{Connector}(CONNECTOR(name, liftArrayLeftList(ty, dims), face, cty, source), conns)
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
function crefFace(cref::ComponentRef)::FaceType
  local face::FaceType
  face = begin
    @match cref begin
      COMPONENT_REF_CREF(restCref = COMPONENT_REF_EMPTY(__)) => begin
        Face.OUTSIDE
      end

      _ => begin
        if isConnector(node(firstNonScope(
          cref,
        )))
          Face.OUTSIDE
        else
          Face.INSIDE
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

function isArray(conn::Connector)
  return isArray(conn.ty)
end
