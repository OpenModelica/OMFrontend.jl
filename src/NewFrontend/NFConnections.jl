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

@UniontypeDecl NFConnections

const BrokenEdges = List
const BrokenEdge = Tuple

@Uniontype NFConnections begin
  @Record CONNECTIONS begin
    connections::List{Connection}
    flows::List{Connector}
    broken::BrokenEdges
  end
end

const Connections = NFConnections

function makeConnectors(
  cref::ComponentRef,
  ty::NFType,
  source::DAE.ElementSource,
)::List{Connector}
  local connectors::List{Connector}

  local cref_exp::Expression
  local cr::ComponentRef
  local expanded::Bool

  cr = evaluateSubscripts(cref)
  #= If we are to expand the connectors or not. Let's assume we do for now=#
  #= Change by John (johti17) 2021-04-26=#
  # if !Flags.isSet(Flags.NF_SCALARIZE)
  #   @assign connectors = list(Connector.fromCref(
  #     cr,
  #     getSubscriptedType(cr),
  #     source,
  #   ))
  #   return connectors
  # end
  cref_exp =
    CREF_EXPRESSION(getSubscriptedType(cr), cr)
  (cref_exp, expanded) = expand(cref_exp)
  if expanded
    connectors = fromExp(cref_exp, source)
  else
    Error.assertion(
      false,
      getInstanceName() +
      " failed to expand connector `" +
      toString(cref) +
      "\\n",
      ElementSource_getInfo(source),
    )
  end
  #=  Connectors should only have structural parameter subscripts, so it
  =#
  #=  should always be possible to expand them.
  =#
  return connectors
end

#= The element crefs of a variable name whose parts have array types (r.p.i of a component
   array r: r[1].p.i, r[2].p.i, ...). Unlike ExpandExp.expandCref this also expands the
   scope parts of the name. =#
function _expandArrayParts(cref::ComponentRef)::Vector{ComponentRef}
  if !isvariant(cref, COMPONENT_REF_CREF)
    return ComponentRef[cref]
  end
  local rests = _expandArrayParts(cref.restCref)
  local dims = arrayDims(cref.ty)
  local out = ComponentRef[]
  if !listEmpty(cref.subscripts) || listEmpty(dims)
    for rest in rests
      push!(out, COMPONENT_REF_CREF(cref.node, cref.subscripts, cref.ty, cref.origin, rest))
    end
    return out
  end
  local subLists = Any[nil]
  for dim in Iterators.reverse(Base.collect(dims))
    local next_lists = Any[]
    local range_iter = fromDim(dim)
    local vals = Expression[]
    while hasNext(range_iter)
      (range_iter, v) = next(range_iter)
      push!(vals, v)
    end
    for v in vals, l in subLists
      push!(next_lists, Cons{Subscript}(SUBSCRIPT_INDEX(v), l))
    end
    subLists = next_lists
  end
  for rest in rests, subs in subLists
    push!(out, COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest))
  end
  return out
end

function collect(flatModel::FlatModel)::Tuple{FlatModel, Connections}
  local conns::Connections = new()
  local comp::Component
  local cr::ComponentRef
  local lhs::ComponentRef
  local rhs::ComponentRef
  local c1::Connector
  local c2::Connector
  local source::DAE.ElementSource
  local eql::Vector{Equation} = Equation[]
  local cl1::List{Connector}
  local cl2::List{Connector}
  local e1::Expression
  local e2::Expression
  local ty1::M_Type
  local ty2::M_Type
  local b1::Bool
  local b2::Bool
  #=  Collect all flow variables. =#
  for var in flatModel.variables
    comp = component(node(var.name))
    if isFlow(comp)
      if Flags.isSet(Flags.NF_SCALARIZE) || !isArray(var.ty)
        c1 = fromFacedCref(
          var.name,
          var.ty,
          Face.INSIDE,
          #=ElementSource.createElementSource(P_Component.info(comp)),=#
          DAE.emptyElementSource
        )
        @assign conns = addFlow(c1, conns)
      else
        #= Not scalarizing: an array flow variable, also one whose dimensions are on a prefix
           part (r.p.i of a component array r), is added per element like the connects
           (r[1].p.i); Connector.split only expands the last part's dimensions. =#
        local elty = arrayElementType(var.ty)
        for cr in _expandArrayParts(var.name)
          c1 = fromFacedCref(cr, elty, Face.INSIDE, DAE.emptyElementSource)
          @assign conns = addFlow(c1, conns)
        end
      end
    end
  end
  #=  Collect all connects.
  =#
  for eq in flatModel.equations
    eql = begin
      @match eq begin
        EQUATION_CONNECT(
          lhs = CREF_EXPRESSION(ty = ty1, cref = lhs),
          rhs = CREF_EXPRESSION(ty = ty2, cref = rhs),
          source = source,
        ) => begin
          if !(
            isDeleted(lhs) ||
            isDeleted(rhs)
          )
            cl1 = makeConnectors(lhs, ty1, source)
            cl2 = makeConnectors(rhs, ty2, source)
            for c1 in cl1
              @match Cons{Connector}(c2, cl2) = cl2
              conns = addConnection(CONNECTION(c1, c2), conns)
            end
          end
          eql
        end

        _ => begin
          push!(eql, eq)
        end
      end
    end
  end
  if !listEmpty(conns.connections)
    @assign flatModel.equations = eql
  end
  return (flatModel, conns)
end

function addBroken(broken::BrokenEdges, conns::Connections)
  conns = CONNECTIONS(conns.connections, conns.flows, broken)
  return conns
end

function addFlow(conn::Connector, conns::Connections)
  local connsFlows = Cons{Connector}(conn, conns.flows)
  conns = CONNECTIONS(conns.connections, connsFlows, conns.broken)
  return conns
end

function addConnection(conn::Connection, conns::Connections)
  local connsConnections = Cons{Connection}(conn, conns.connections)
  conns = CONNECTIONS(connsConnections, conns.flows, conns.broken)
  return conns
end

function fromConnectionList(connl::List{<:Connection})
  local conns::Connections
  conns = CONNECTIONS(connl, nil, nil)
  return conns
end

function new()::Connections
  local conns::Connections = CONNECTIONS(nil, nil, nil)
  return conns
end
