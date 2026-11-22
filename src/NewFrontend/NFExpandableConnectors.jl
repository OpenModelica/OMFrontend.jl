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

function elaborate(
  flatModel::FLAT_MODEL,
  connections::CONNECTIONS,
)::Tuple{FLAT_MODEL, CONNECTIONS}

  local expandable_conns::List{CONNECTION}
  local undeclared_conns::List{CONNECTION}
  local conns::List{CONNECTION}
  local vars::List{VARIABLE}
  local csets::ConnectionSets.Sets
  local csets_array::Vector{List{CONNECTOR}}

  #= Sort the connections based on whether they involve expandable connectors,
     virtual/potentially present connectors, or only normal connectors. =#
   (expandable_conns, undeclared_conns, conns) =
    sortConnections(connections.connections)
  #= Don't do anything if there aren't any expandable connectors in the model. =#
  if listEmpty(expandable_conns) && listEmpty(undeclared_conns)
    return (flatModel, connections)
  end
  #= Create a graph from the connections. Expandable connectors connect to
     expandable connectors, while virtual/potentially present connectors connect
     to the expandable connector they belong to. =#
  @assign csets =
    ConnectionSets.emptySets(listLength(expandable_conns) + listLength(undeclared_conns))
  @assign csets = addExpandableConnectorsToSets(expandable_conns, csets)
   (undeclared_conns, csets) =
    ListUtil.mapFold(undeclared_conns, addUndeclaredConnectorToSets, csets, CONNECTION, ConnectionSets.Sets)
  #= Extract the sets of connected connectors. =#
  (csets_array, _) = ConnectionSets.extractSets(csets)
  #= for set in csets_array loop
     print(\"Expandable connection set:\\n\");
     print(List.toString(set, Connector.toString, \"\", \"{\", \", \", \"}\", true) + \"\\n\");
     end for;
     Augment the expandable connectors with the necessary elements, mark
     connected potentially present variables as present, and add the
     created variables to the flat model. =#
  vars = arrayList(flatModel.variables) #TODO: Change the submodule so they are always vectors
  for set in csets_array
    vars = elaborateExpandableSet(set, vars)
  end
  #= Update the connections and put them back in the list of connections. =#
  conns = ListUtil.fold(undeclared_conns, updateUndeclaredConnection, conns, List{CONNECTION})
  conns = ListUtil.fold(expandable_conns, updateExpandableConnection, conns, List{CONNECTION})
  @assign connections.connections = conns
  #= Update the attributes of potentially present variables so that they have
     the same attributes as their node. Their connector type will have changed
     if they've been marked as present. =#
  vars = list(updatePotentiallyPresentVariable(v) for v in vars)
  @assign flatModel.variables = listArray(vars)
  return (flatModel, connections)
end

"""
  Sorts the connections into different categories of connectors based on
  whether they involve expandable connectors, virtual/potentially present
  connector, or only normal connectors.
"""
function sortConnections(
  conns::List{<:CONNECTION},
)::Tuple{List{CONNECTION}, List{CONNECTION}, List{CONNECTION}}
  local normalConnections::List{CONNECTION} = nil
  local undeclaredConnections::List{CONNECTION} = nil
  local expandableConnections::List{CONNECTION} = nil

  local c1::CONNECTOR
  local c2::CONNECTOR
  local is_undeclared1::Bool
  local is_undeclared2::Bool
  local is_expandable1::Bool
  local is_expandable2::Bool

  for conn in conns
    @match CONNECTION(lhs = c1, rhs = c2) = conn
    is_undeclared1 = isUndeclared(c1.cty)
    is_undeclared2 = isUndeclared(c2.cty)
    is_expandable1 = isExpandable(c1.cty)
    is_expandable2 = isExpandable(c2.cty)
    if is_expandable1 || is_expandable2
      if is_expandable1 && is_expandable2
        @assign expandableConnections = _cons(conn, expandableConnections)
      else
        Error.addSourceMessageAndFail(
          Error.EXPANDABLE_NON_EXPANDABLE_CONNECTION,
          list(
            toString(if is_expandable1
              c1
            else
              c2
            end),
            toString(if is_expandable1
              c2
            else
              c1
            end),
          ),
          c1.source,
        )
      end
    elseif is_undeclared1 || is_undeclared2
      if is_undeclared1 && is_undeclared2
        Error.addSourceMessageAndFail(
          Error.UNDECLARED_CONNECTION,
          list(toString(c1), toString(c2)),
          c1.source,
        )
      else
        @assign undeclaredConnections = _cons(conn, undeclaredConnections)
      end
    else
      @assign normalConnections = _cons(conn, normalConnections)
    end
  end
  #= An expandable connector may only connect to another expandable connector.
     Both sides can't be undeclared, one must be a declared component. =#
  @assign normalConnections = listReverseInPlace(normalConnections)
  return (expandableConnections, undeclaredConnections, normalConnections)
end

function addExpandableConnectorsToSets(
  conns::List{<:CONNECTION},
  csets::ConnectionSets.Sets,
)::ConnectionSets.Sets
  local c1::CONNECTOR
  local c2::CONNECTOR
  for conn in conns
    @match CONNECTION(lhs = c1, rhs = c2) = conn
    @assign csets = addConnectionToSets(c1, c2, csets)
    @assign csets = addNestedExpandableConnectorsToSets(c1, c2, csets)
  end
  return csets
end

function addNestedExpandableConnectorsToSets(
  c1::CONNECTOR,
  c2::CONNECTOR,
  csets::ConnectionSets.Sets,
)::ConnectionSets.Sets

  local ecl1::List{CONNECTOR}
  local ecl2::List{CONNECTOR}
  local oec::Option{CONNECTOR}

  @assign ecl1 = getExpandableConnectorsInConnector(c1)
  @assign ecl2 = getExpandableConnectorsInConnector(c2)
  if listEmpty(ecl1) && listEmpty(ecl2)
    return csets
  end
  #= The nested ones' own nested expandable connectors too (omc; omc ExpandableConnector8). =#
  local conns::List{CONNECTION} = nil
  for ec1 in ecl1
     (ecl2, oec) =
      ListUtil.deleteMemberOnTrue(ec1, ecl2, isNodeNameEqual, CONNECTOR)
    if isSome(oec)
      conns = _cons(CONNECTION(ec1, Util.getOption(oec)), conns)
    end
  end
  @assign csets = addExpandableConnectorsToSets(conns, csets)
  return csets
end

function getExpandableConnectorsInConnector(c1::CONNECTOR)::List{CONNECTOR}
  local ecl::List{CONNECTOR}

  local nodes::List{InstNode}
  local par_name::ComponentRef
  local name::ComponentRef
  local ty::ModelicaType

  ecl = begin
    @match c1 begin
      CONNECTOR(
        name = par_name,
        ty = TYPE_COMPLEX(
          complexTy = COMPLEX_EXPANDABLE_CONNECTOR(expandableConnectors = nodes),
        ),
      ) => begin
        @assign ecl = nil
        for n in nodes
          @assign ty = getType(n)
          @assign name = prefixCref(n, ty, nil, par_name)
          @assign ecl = _cons(
            fromCref(
              name,
              ty,
              InstNode_info(n),
            ),
            ecl,
          )
        end
        ecl
      end

      _ => begin
        nil
      end
    end
  end
  return ecl
end

function addUndeclaredConnectorToSets(
  conn::CONNECTION,
  csets::ConnectionSets.Sets,
)::Tuple{CONNECTION, ConnectionSets.Sets}

  local c1::CONNECTOR
  local c2::CONNECTOR
  local c::CONNECTOR
  local ec::CONNECTOR

  @match CONNECTION(lhs = c1, rhs = c2) = conn
  #= Figure out which connector to add, and create a virtual connector if necessary. =#
  if isUndeclared(c1.cty)
    if isVirtual(c1.cty)
      @assign c1 = makeVirtualConnector(c1, c2)
      @assign conn = CONNECTION(c1, c2)
    end
    @assign c = c1
  else
    if isVirtual(c2.cty)
      @assign c2 = makeVirtualConnector(c2, c1)
      @assign conn = CONNECTION(c1, c2)
    end
    @assign c = c2
  end
  #= Create a parent connector for the undeclared connector, i.e. the expandable
     connector it should be added to. The type here is wrong, but it doesn't matter. =#
  @assign ec = CONNECTOR(
    rest(c.name),
    c.ty,
    c.face,
    ConnectorType.EXPANDABLE,
    c.source,
  )
  #= Add a connection between the undeclared connector and the expandable connector. =#
  @assign csets = addConnectionToSets(c, ec, csets)
  return (conn, csets)
end

function addConnectionToSets(
  c1::CONNECTOR,
  c2::CONNECTOR,
  csets::ConnectionSets.Sets,
)::ConnectionSets.Sets

  #= The connection sets are not used to represent actual connections here, only
     to keep track of which expandable connectors that are associated. So to
     make sure we only get one instance of each expandable connector in the sets
     we make sure the face of all the connectors we add is the same. =#
  csets = ConnectionSets.merge(
    setOutside(c1),
    setOutside(c2),
    csets,
  )
  return csets
end

function makeVirtualConnector(
  virtualConnector::CONNECTOR,
  normalConnector::CONNECTOR,
)::CONNECTOR
  local newConnector::CONNECTOR

  local virtual_cref::ComponentRef
  local normal_cref::ComponentRef
  local ty::ModelicaType
  local nodeV::InstNode

  virtual_cref = virtualConnector.name
  normal_cref = normalConnector.name
  ty = normalConnector.ty
  #=  TODO: Update the virtual connector with the created node. =#
  nodeV = node(normal_cref)
  nodeV = clone(nodeV)
  nodeV = rename(firstName(virtual_cref), nodeV)
  nodeV = setParent(
    node(rest(virtual_cref)),
    nodeV,
  )
  virtual_cref = prefixCref(
    nodeV,
    ty,
    nil,
    rest(virtual_cref),
  )
  #=  TODO: This needs more work, the new connector might be a complex connector.  =#
  newConnector = CONNECTOR(
    virtual_cref,
    ty,
    virtualConnector.face,
    virtualConnector.cty,
    virtualConnector.source,
  )
  return newConnector
end

function elaborateExpandableSet(
  set::List{<:CONNECTOR},
  vars::List{<:VARIABLE},
)::List{VARIABLE}
  local exp_conns::List{CONNECTOR} = nil
  local exp_set_lst::List{CONNECTOR} = nil
  #= Deduplicate undeclared elements by node name (isNodeNameEqual semantics).
     Identity-based sets are unusable here: objectid of the deeply immutable
     connector would content-hash the reachable instance graph. =#
  local seenNames = Set{String}()
  for c in set
    if isExpandable(c.cty)
      exp_conns = _cons(c, exp_conns)
    elseif isUndeclared(c.cty)
      local elemName = name(node(c.name))
      if !(elemName in seenNames)
        push!(seenNames, elemName)
        exp_set_lst = _cons(c, exp_set_lst)
      end
      markComponentPresent(node(name(c)))
    end
  end
  for ec in exp_conns
    vars = augmentExpandableConnector(ec, exp_set_lst, vars)
  end
  return vars
end

function markComponentPresent(node::InstNode)
  local comp::Component
  local cty::ConnectorType.TYPE
  comp = component(node)
  cty = connectorType(comp)
  if isPotentiallyPresent(cty)
    cty = setPresent(cty)
    comp = setConnectorType(cty, comp)
    node = updateComponent!(comp, node)
    #= Its children too (a declared connector in an expandable bus, `connect(bus.c, c)`: c's
       potentials and flows; omc markComponentPresent). =#
    if isComplex(getType(comp))
      applyComponents(classTree(getClass(classInstance(comp))), markComponentPresent)
    end
  end
  return node
end

function augmentExpandableConnector(
  conn::CONNECTOR,
  expandableSet::List{<:CONNECTOR},
  vars::List{<:VARIABLE},
  )::List{VARIABLE}

  local exp_name::ComponentRef
  local elem_name::ComponentRef
  local exp_node::InstNode
  local comp_node::InstNode
  local cls_node::InstNode
  local nodeElem::InstNode
  local cls::Class
  local cls_tree::ClassTree
  local nodes::List{InstNode} = nil
  local ty::ModelicaType
  local complex_ty::ComplexType

  exp_name = name(conn)
  exp_node = node(exp_name)
  if isName(exp_node)
    Error.addInternalError(
      "Augmenting a virtual element in an expandable connector is not yet supported.",
      conn.source,
    )
    fail()
  end
  #= A copy: the elements of an array of components share the connector's class, each element's
     connector is augmented (a[1].ec.y, a[2].ec.y; omc ExpandableConnector4). =#
  cls_node = clone(classScope(exp_node))
  cls = getClass(cls_node)
  cls_tree = classTree(cls)
  #= Go through the union of elements the expandable connector should have. =#
  for c in expandableSet
    elem_name = name(c)
    nodeElem = node(elem_name)
    comp_node = lookupElementNode(name(nodeElem), cls_tree)
    if isEmpty(comp_node)
      nodes = _cons(nodeElem, nodes)
      ty = c.ty
      elem_name = prefixCref(nodeElem, ty, nil, exp_name)
      vars = createVirtualVariables(elem_name, ty, c.source, vars)
    else
      comp_node = lookupElementNode(name(nodeElem), cls_tree)
      comp_node = resolveInner(comp_node)
      if isComponent(comp_node)
        comp_node = markComponentPresent(comp_node)
        cls_tree = replaceElementNode(name(nodeElem), comp_node, cls_tree)
      else
        Error.addInternalError(
          getInstanceName() + " got non-component element",
          sourceInfo(),
        )
      end
    end
  end
  #= If the element doesn't already exist, add it to the list of elements to be
     added to the connector.
     TODO: This needs more work, the new connector might be a complex connector.
     If the element already exists and is a potentially present component,
     change it to be present. =#
  if !listEmpty(nodes)
    cls_tree = addElementsToFlatTree(nodes, cls_tree)
    cls = setClassTree(cls_tree, cls)
  end
  #= Create a normal non-expandable complex type for the augmented expandable connector. =#
  complex_ty = makeConnectorType(cls_tree, false)
  ty = TYPE_COMPLEX(cls_node, complex_ty)
  ty = liftArrayLeftList(ty, arrayDims(getType(exp_node))) #Change from pstream
  cls = setType(ty, cls)
  cls_node = updateClass(cls, cls_node)
  exp_node = componentApply(exp_node, setType, ty)
  return vars
end

function createVirtualVariables(connectorName::ComponentRef, connectorType::ModelicaType, info::SourceInfo, vars::List{VARIABLE})
  local var::VARIABLE
  local name::ComponentRef
  local ty::ModelicaType
  if isComplex(connectorType)
    for comp in complexComponents(connectorType)
      ty = getType(comp)
      name = prefixCref(comp, ty, nil, connectorName)
      vars = createVirtualVariables(name, ty, info, vars)
    end
  else
    var = VARIABLE(connectorName, connectorType,
                   EMPTY_BINDING,
                   Visibility.PUBLIC,
                   DEFAULT_ATTR,# Should be augmented,
                   [],
                   SOME(SCode.COMMENT(NONE(),
                                      SOME("virtual variable in expandable connector"))),
                   info)
    vars = _cons(var, vars)
  end
  vars
end

function updateUndeclaredConnection(
  conn::CONNECTION,
  conns::List{<:CONNECTION},
)::List{CONNECTION}

  @assign conns = _cons(conn, conns)
  return conns
end

function updateExpandableConnection(
  conn::CONNECTION,
  conns::List{<:CONNECTION},
)::List{CONNECTION}

  local c1::CONNECTOR
  local c2::CONNECTOR
  local ty1::ModelicaType
  local ty2::ModelicaType
  local mk::MatchKindType
  local e1::Expression
  local e2::Expression

  @match CONNECTION(lhs = c1, rhs = c2) = conn
   (c1, ty1) = updateExpandableConnector(c1)
   (c2, ty2) = updateExpandableConnector(c2)
  #= Check that the types match now that the connectors have been augmented. =#
  e1 = CREF_EXPRESSION(ty1, name(c1))
  e2 = CREF_EXPRESSION(ty2, name(c2))
   (_, _, _, mk) = matchExpressions(e1, ty1, e2, ty2, #=allowUnknown=# true)
  if isIncompatibleMatch(mk)
    Error.addSourceMessageAndFail(
      Error.INVALID_CONNECTOR_VARIABLE,
      list(toString(e1), toString(e2)),
      c1.source,
    )
  end
  conns = _cons(CONNECTION(c1, c2), conns)
  return conns
end

function updateExpandableConnector(conn::CONNECTOR)::Tuple{CONNECTOR, ModelicaType}
  local ty::ModelicaType
  local name::ComponentRef
  @match CONNECTOR(name = name, ty = ty) = conn
  name = updateNodeType(name)
  ty = setArrayElementType(
    ty,
    arrayElementType(nodeType(name)),
  )
  conn = CONNECTOR(name, ty, conn.face, conn.cty, conn.source)
  return (conn, ty)
end

function updatePotentiallyPresentVariable(var::VARIABLE)::VARIABLE
  if isPotentiallyPresent(var.attributes.connectorType)
    @assign var.attributes =
      getAttributes(component(node(var.name)))
  end
  return var
end
