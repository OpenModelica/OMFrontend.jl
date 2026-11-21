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

#= The overconstrained connection graph (Modelica Language Specification 3.6, section 9.4).

The nodes are the overconstrained crefs (records with an equalityConstraint function, like a frame's
orientation), numbered in the order they are met. `Connections.branch` adds a branch, `connect` an edge,
`Connections.root` and `Connections.potentialRoot` mark roots. A spanning forest is built with
union-find over the node numbers: definite roots first, then the branches, then the connect edges (an
edge that would close a loop is broken), then the potential roots by priority (one per tree that has no
root yet). A broken connect is replaced by the equalityConstraint equations of its connectors.
`Connections.rooted` and `Connections.isRoot` are then evaluated from the roots and the distances to them.

A Connections.branch under an if-equation on a discrete condition (dynamic overconstrained connectors),

  if closed then
    Connections.branch(port_a.omegaRef, port_b.omegaRef);
    port_a.omegaRef = port_b.omegaRef;
  end if;

is resolved once per mode (each conditional branch present or not), and the equations that differ
between the modes become one if-equation over the conditions. At run time the event that changes a
condition switches to that mode's roots and equations; nothing is rebuilt. Removing a branch that is a
tree edge splits one tree, and a potential root of the new part takes it, so every mode has as many
equations; the modes are checked to be balanced. Not supported (an error): an else or elseif in the
if-equation, more than one Connections.branch in it, a conditional branch whose presence changes which
connects break (a breaker on one of two parallel lines), and mode equations that are not scalar. =#

"""An operator of Modelica's `Connections` package (`Connections.branch`, ...): one of the `CONNECTIONS_OPERATOR_*`
constants, `CONNECTIONS_OPERATOR_NONE` for any other call."""
const ConnectionsOperator = UInt8
"""`Connections.branch(a, b)`."""
const CONNECTIONS_OPERATOR_BRANCH::ConnectionsOperator = 0x01
"""`Connections.root(a)`."""
const CONNECTIONS_OPERATOR_ROOT::ConnectionsOperator = 0x02
"""`Connections.potentialRoot(a[, priority])`."""
const CONNECTIONS_OPERATOR_POTENTIAL_ROOT::ConnectionsOperator = 0x03
"""`Connections.isRoot(a)`."""
const CONNECTIONS_OPERATOR_IS_ROOT::ConnectionsOperator = 0x04
"""`Connections.rooted(a)` (and the deprecated `rooted(a)`)."""
const CONNECTIONS_OPERATOR_ROOTED::ConnectionsOperator = 0x05
"""`Connections.uniqueRoot(a, message)`."""
const CONNECTIONS_OPERATOR_UNIQUE_ROOT::ConnectionsOperator = 0x06
"""`Connections.uniqueRootIndices(roots, nodes, message)`."""
const CONNECTIONS_OPERATOR_UNIQUE_ROOT_INDICES::ConnectionsOperator = 0x07
"""Not an operator of `Connections`."""
const CONNECTIONS_OPERATOR_NONE::ConnectionsOperator = 0x08

"""A pair of node ids: a branch, or a potential root and its priority."""
const IdPair = Tuple{Int, Int}

"""
    OCC_EDGE(lhs, rhs, connect)

An edge from a `connect`: the node ids of two overconstrained crefs it connects, and the index of the
connect in `OCC_GRAPH.connects`, whose equalityConstraint equations replace it when the edge breaks.
"""
struct OCC_EDGE
  lhs::Int
  rhs::Int
  connect::Int
end

"""
    OCC_GRAPH(crefs, ids, definiteRoots, potentialRoots, branches, edges, connects)

The overconstrained connection graph of a model. Node `id` is the cref `crefs[id]`; `ids` maps a cref
back to its id. `definiteRoots` (Connections.root), `potentialRoots` (Connections.potentialRoot, with
the priority), `branches` (Connections.branch) and `edges` (connect) in the order of the equations.
`connects` holds the connects that have edges.
"""
struct OCC_GRAPH
  crefs::Vector{ComponentRef}
  ids::Dict{CrefHashKey, Int}
  definiteRoots::Vector{Int}
  potentialRoots::Vector{IdPair}
  branches::Vector{IdPair}
  edges::Vector{OCC_EDGE}
  connects::Vector{CONNECTION}
end

"""An empty graph."""
OCC_GRAPH() = OCC_GRAPH(ComponentRef[], Dict{CrefHashKey, Int}(), Int[], IdPair[], IdPair[], OCC_EDGE[], CONNECTION[])

"""
    OCC_RESULT(roots, broken)

The spanning forest of an `OCC_GRAPH`: its roots (node ids) and, per edge, whether it is broken.
"""
struct OCC_RESULT
  roots::Vector{Int}
  broken::Vector{Bool}
end

"""The id of `cref` in `graph`, added as a node if it is none yet."""
function nodeId!(graph::OCC_GRAPH, cref::ComponentRef)::Int
  local key::CrefHashKey = CrefHashKey(cref)
  local id::Int = get(graph.ids, key, 0)
  if id == 0
    push!(graph.crefs, cref)
    id = length(graph.crefs)
    graph.ids[key] = id
  end
  return id
end

"""The id of `cref` in `graph`, 0 if it is no node."""
nodeIdOrZero(graph::OCC_GRAPH, cref::ComponentRef)::Int = get(graph.ids, CrefHashKey(cref), 0)

"""`graph` with the branches `extra` added after its own (shares the nodes)."""
function withBranches(graph::OCC_GRAPH, extra::Vector{IdPair})::OCC_GRAPH
  return OCC_GRAPH(graph.crefs, graph.ids, graph.definiteRoots, graph.potentialRoots,
                   vcat(graph.branches, extra), graph.edges, graph.connects)
end

"""
  Goes over the connections and equations of `flatModel` and
  1. builds the overconstrained connection graph from connect, Connections.branch, Connections.root,
     Connections.potentialRoot and Connections.uniqueRoot (the calls are removed from the equations),
  2. breaks it into a spanning forest and returns the broken connects with the equalityConstraint
     equations that replace them,
  3. evaluates Connections.isRoot, Connections.rooted, rooted and Connections.uniqueRootIndices.
"""
function handleOverconstrainedConnections(flatModel::FLAT_MODEL,
                                          conns::CONNECTIONS,
                                          modelNameQualified::String)::Tuple{FLAT_MODEL, BrokenEdges}
  local graph::OCC_GRAPH = OCC_GRAPH()
  local eql::Vector{Equation} = Equation[]
  local ieql::Vector{Equation}
  local vars::Vector{VARIABLE}
  local tables::OCC_TABLES
  local conditionals::Vector{CONDITIONAL_BRANCH} = CONDITIONAL_BRANCH[]
  local result::OCC_RESULT
  @EXECSTAT "    oc:collectGraph" for conn in conns.connections
    addConnectEdges!(graph, conn)
  end
  if Flags.isSet(Flags.CGRAPH)
    for e in graph.edges
      print("- addConnection(" + toString(graph.crefs[e.lhs]) + ", " + toString(graph.crefs[e.rhs]) + ")\n")
    end
  end
  for eq in flatModel.equations
    local cb::Union{Nothing, CONDITIONAL_BRANCH} = conditionalBranch(eq)
    if cb !== nothing
      push!(conditionals, cb)
    elseif !addOperatorCall!(graph, eq)
      push!(eql, eq)
    end
  end
  if isempty(conditionals)
    @EXECSTAT "    oc:findResultGraph" result = findResultGraph(graph)
    @EXECSTAT "    oc:rootTables" tables = rootTables(graph, result)
    @EXECSTAT "    oc:evalOperators" begin
      eql = evalConnectionsOperators(graph, tables, eql)
      ieql = evalConnectionsOperators(graph, tables, flatModel.initialEquations)
    end
    @EXECSTAT "    oc:evalBindings" vars = evalConnectionsOperators(graph, tables, flatModel.variables)
  else
    @EXECSTAT "    oc:modes" (eql, ieql, vars, result) = resolveModes(graph, conditionals, modelNameQualified, eql,
                                                                     flatModel.initialEquations, flatModel.variables)
  end
  if Flags.isSet(Flags.CGRAPH)
    print("Roots: " + stringDelimitList(String[toString(graph.crefs[r]) for r in result.roots], ", ") + "\n")
    print("Broken connections: " + stringDelimitList(String[edgeString(graph, e)
                                                              for (e, b) in zip(graph.edges, result.broken) if b], ", ") + "\n")
  end
  local broken::BrokenEdges = brokenEdges(graph, result)
  @EXECSTAT "    oc:removeBroken" eql = removeBrokenConnects(eql, broken)
  @assign begin
    flatModel.variables = vars
    flatModel.equations = eql
    flatModel.initialEquations = ieql
  end
  return (flatModel, broken)
end

"""Adds the edges of `conn` to `graph`: one per pair of overconstrained crefs in its two connectors."""
function addConnectEdges!(graph::OCC_GRAPH, conn::CONNECTION)::OCC_GRAPH
  local lhs_crefs::List{ComponentRef} = getOverconstrainedCrefs(conn.lhs)
  if listEmpty(lhs_crefs)
    return graph
  end
  local rhs_crefs::List{ComponentRef} = getOverconstrainedCrefs(conn.rhs)
  if listLength(lhs_crefs) != listLength(rhs_crefs)
    Error.addInternalError(getInstanceName() + " got connectors with different overconstrained components in " +
                           toString(conn), conn.lhs.source)
    fail()
  end
  push!(graph.connects, conn)
  local connect::Int = length(graph.connects)
  for (l, r) in zip(lhs_crefs, rhs_crefs)
    push!(graph.edges, OCC_EDGE(nodeId!(graph, l), nodeId!(graph, r), connect))
  end
  return graph
end

"""
  Adds `eq` to `graph` if it is a call to Connections.root, potentialRoot, uniqueRoot or branch, and
  returns whether it was one (the equation is then dropped).
"""
function addOperatorCall!(graph::OCC_GRAPH, @nospecialize(eq::Equation))::Bool
  if !(isvariant(eq, EQUATION_NORETCALL) && eq.exp isa CALL_EXPRESSION && isvariant(eq.exp.call, TYPED_CALL))
    return false
  end
  local call::Call = eq.exp.call
  local op::ConnectionsOperator = identifyConnectionsOperator(name(call.fn))
  local args::Vector{Expression} = call.arguments
  if op == CONNECTIONS_OPERATOR_ROOT
    push!(graph.definiteRoots, nodeId!(graph, toCref(only(args))))
  elseif op == CONNECTIONS_OPERATOR_POTENTIAL_ROOT
    @match INTEGER_EXPRESSION(value = priority) = evalExp(args[2])
    push!(graph.potentialRoots, (nodeId!(graph, toCref(args[1])), priority))
  elseif op == CONNECTIONS_OPERATOR_UNIQUE_ROOT
    #= Accepted and dropped: uniqueRoot only matters for uniqueRootIndices, which is not implemented. =#
  elseif op == CONNECTIONS_OPERATOR_BRANCH
    push!(graph.branches, (nodeId!(graph, toCref(args[1])), nodeId!(graph, toCref(args[2]))))
  else
    return false
  end
  return true
end

"""The root of the set of node `i`; halves the path on the way."""
function findRoot!(parent::Vector{Int}, i::Int)::Int
  while parent[i] != i
    parent[i] = parent[parent[i]]
    i = parent[i]
  end
  return i
end

"""Unites the sets of nodes `a` and `b` (by rank); false if they are in one set already."""
function unite!(parent::Vector{Int}, rank::Vector{UInt8}, a::Int, b::Int)::Bool
  local ra::Int = findRoot!(parent, a)
  local rb::Int = findRoot!(parent, b)
  if ra == rb
    return false
  end
  if rank[ra] < rank[rb]
    parent[ra] = rb
  elseif rank[ra] > rank[rb]
    parent[rb] = ra
  else
    parent[rb] = ra
    rank[ra] += 0x01
  end
  return true
end

"""
  The spanning forest of `graph`. A virtual node joins all roots: the definite roots first, then the
  branches, then the edges in order (an edge within one set breaks), then the potential roots by
  ascending priority, equal priorities by name (as omc), each one that is not yet in a rooted set.
"""
function findResultGraph(graph::OCC_GRAPH)::OCC_RESULT
  local n::Int = length(graph.crefs) + 1
  local virtualRoot::Int = n
  local parent::Vector{Int} = Base.collect(1:n)
  local rank::Vector{UInt8} = zeros(UInt8, n)
  local roots::Vector{Int} = Int[]
  for r in graph.definiteRoots
    unite!(parent, rank, r, virtualRoot)
    push!(roots, r)
  end
  for (a, b) in graph.branches
    unite!(parent, rank, a, b)
  end
  local broken::Vector{Bool} = Vector{Bool}(undef, length(graph.edges))
  for (i, e) in enumerate(graph.edges)
    broken[i] = !unite!(parent, rank, e.lhs, e.rhs)
  end
  for (r, _) in sortedPotentialRoots(graph)
    if unite!(parent, rank, r, virtualRoot)
      push!(roots, r)
    end
  end
  return OCC_RESULT(roots, broken)
end

"""The potential roots by ascending priority; equal priorities by the cref's name."""
function sortedPotentialRoots(graph::OCC_GRAPH)::Vector{IdPair}
  local prs::Vector{IdPair} = graph.potentialRoots
  if length(prs) < 2
    return prs
  end
  local keys::Vector{Tuple{Int, String}} = Tuple{Int, String}[(p, toString(graph.crefs[r])) for (r, p) in prs]
  return prs[sortperm(keys)]
end

"""The broken edges as the connection handling takes them: the crefs and the equalityConstraint equations."""
function brokenEdges(graph::OCC_GRAPH, result::OCC_RESULT)::BrokenEdges
  local origin::ORIGIN_Type = intBitOr(ORIGIN_EQUATION, ORIGIN_CONNECT)
  local equations::Dict{Int, List{Equation}} = Dict{Int, List{Equation}}()
  local out::Vector{Tuple{ComponentRef, ComponentRef, List{Equation}}} = Tuple{ComponentRef, ComponentRef, List{Equation}}[]
  for (e, b) in zip(graph.edges, result.broken)
    b || continue
    local eqs::List{Equation} = get!(equations, e.connect) do
      local c::CONNECTION = graph.connects[e.connect]
      arrayList(generateEqualityConstraintEquation(c.lhs.name, c.lhs.ty, c.rhs.name, c.rhs.ty, origin, c.lhs.source))
    end
    push!(out, (graph.crefs[e.lhs], graph.crefs[e.rhs], eqs))
  end
  return arrayList(out)
end

"""`connect(a, b)` for an edge, for traces."""
edgeString(graph::OCC_GRAPH, e::OCC_EDGE)::String =
  "connect(" + toString(graph.crefs[e.lhs]) + ", " + toString(graph.crefs[e.rhs]) + ")"

#= Per-translation caches for the function refs used in generated
   equalityConstraint equations. Lookup + instantiation only depend on the
   connector class (equalityConstraint) or the top scope (fill), not on the
   individual connection. =#
const _EQ_CONSTRAINT_FN_CACHE = Dict{UInt64, Tuple{ComponentRef, InstNode}}()
const _FILL_FN_CACHE = Dict{UInt64, Tuple{ComponentRef, InstNode}}()

"""Empties the equalityConstraint and fill function caches (at the start of a translation)."""
function resetConnectionGraphCaches()
  empty!(_EQ_CONSTRAINT_FN_CACHE)
  empty!(_FILL_FN_CACHE)
  return nothing
end

"""
  What the Connections operators are evaluated with: each node's distance to the nearest root in the
  spanning forest (-1 for a node no root reaches), and whether the node is a root.
"""
struct OCC_TABLES
  distance::Vector{Int}
  isRoot::Vector{Bool}
end

"""The tables of `result` (the spanning forest and the roots of `graph`)."""
function rootTables(graph::OCC_GRAPH, result::OCC_RESULT)::OCC_TABLES
  local isRoot::Vector{Bool} = fill(false, length(graph.crefs))
  for r in result.roots
    isRoot[r] = true
  end
  return OCC_TABLES(rootDistances(graph, result), isRoot)
end

"""
  The distance of each node to the nearest root over the branches and the unbroken connect edges (the
  spanning forest, as omc's buildRootedTable), -1 for a node no root reaches.
"""
function rootDistances(graph::OCC_GRAPH, result::OCC_RESULT)::Vector{Int}
  local n::Int = length(graph.crefs)
  local broken::Vector{Bool} = result.broken
  #= Adjacency in compressed rows: the neighbours of node i are adj[first[i]:first[i + 1] - 1]. =#
  local first::Vector{Int} = zeros(Int, n + 1)
  for (a, b) in graph.branches
    first[a] += 1
    first[b] += 1
  end
  for (k, e) in enumerate(graph.edges)
    broken[k] && continue
    first[e.lhs] += 1
    first[e.rhs] += 1
  end
  local total::Int = 1
  for i in 1:n
    local d::Int = first[i]
    first[i] = total
    total += d
  end
  first[n + 1] = total
  local adj::Vector{Int} = Vector{Int}(undef, total - 1)
  local fill::Vector{Int} = first[1:n]
  local link!(a::Int, b::Int) = (adj[fill[a]] = b; fill[a] += 1; adj[fill[b]] = a; fill[b] += 1)
  for (a, b) in graph.branches
    link!(a, b)
  end
  for (k, e) in enumerate(graph.edges)
    broken[k] || link!(e.lhs, e.rhs)
  end
  local distance::Vector{Int} = fill!(Vector{Int}(undef, n), -1)
  local queue::Vector{Int} = Int[]
  for r in result.roots
    if distance[r] < 0
      distance[r] = 0
      push!(queue, r)
    end
  end
  local head::Int = 1
  while head <= length(queue)
    local i::Int = queue[head]
    head += 1
    for k in first[i]:first[i + 1] - 1
      local j::Int = adj[k]
      if distance[j] < 0
        distance[j] = distance[i] + 1
        push!(queue, j)
      end
    end
  end
  return distance
end

"""The other end of the last branch (in equation order) that has node `id`, 0 if none has."""
function branchPartner(graph::OCC_GRAPH, id::Int)::Int
  for k in length(graph.branches):-1:1
    local (a, b) = graph.branches[k]
    a == id && return b
    b == id && return a
  end
  return 0
end

"""True for calls to the Connections operators that evalConnectionsOperators replaces (rooted, isRoot, uniqueRootIndices)."""
function isConnectionsOperatorCall(exp::Expression)::Bool
  if !(exp isa CALL_EXPRESSION)
    return false
  end
  local call = exp.call
  return isvariant(call, TYPED_CALL) &&
    identifyConnectionsOperator(name(call.fn)) != CONNECTIONS_OPERATOR_NONE
end

"""
  `equations` with Connections.rooted, rooted, Connections.isRoot and Connections.uniqueRootIndices
  evaluated for the roots `roots` of `graph`:
  - rooted(a) is true if a is closer to a root than the other end of its branch,
  - isRoot(a) is true if a is a root,
  - uniqueRootIndices gives 1 per root (not implemented further).
  See Modelica_StateGraph2 and https://www.ep.liu.se/ecp/043/041/ecp09430108.pdf for uniqueRootIndices.
"""
function evalConnectionsOperators(graph::OCC_GRAPH, tables::OCC_TABLES, equations::Vector{Equation})::Vector{Equation}
  if isempty(equations) || !System.getUsesConnectionsOperators()
    return equations
  end
  local out::Vector{Equation} = Vector{Equation}(undef, length(equations))
  for (k, eq) in enumerate(equations)
    local info::SourceInfo = Equation_info(eq)
    out[k] = mapExp(eq, x -> contains(x, isConnectionsOperatorCall) ?
                             map(x, y -> evalConnectionsOperator(y, graph, tables, info)) : x)
  end
  return out
end

"""
  `variables` with the Connections operators in their bindings evaluated, as in equations
  (`Boolean ra = Connections.rooted(a.ref)`).
"""
function evalConnectionsOperators(graph::OCC_GRAPH, tables::OCC_TABLES, variables::Vector{VARIABLE})::Vector{VARIABLE}
  if !System.getUsesConnectionsOperators()
    return variables
  end
  local out::Vector{VARIABLE} = variables
  for (k, v) in enumerate(variables)
    containsExp(v.binding, isConnectionsOperatorCall) || continue
    if out === variables
      out = copy(variables)
    end
    out[k] = withBinding(v, mapExp(v.binding, y -> evalConnectionsOperator(y, graph, tables, v.info)))
  end
  return out
end

"""`v` with the binding `b`."""
withBinding(v::VARIABLE, b::Binding)::VARIABLE =
  VARIABLE(v.name, v.ty, b, v.visibility, v.attributes, v.typeAttributes, v.comment, v.info)

"""`exp` evaluated if it is a call of Connections.rooted, isRoot or uniqueRootIndices; else `exp`."""
function evalConnectionsOperator(exp::Expression, graph::OCC_GRAPH, tables::OCC_TABLES, info::SourceInfo)::Expression
  if !(exp isa CALL_EXPRESSION) || !isvariant(exp.call, TYPED_CALL)
    return exp
  end
  local call::Call = exp.call
  local op::ConnectionsOperator = identifyConnectionsOperator(name(call.fn))
  local args::Vector{Expression} = call.arguments
  if op == CONNECTIONS_OPERATOR_ROOTED || op == CONNECTIONS_OPERATOR_IS_ROOT
    local arg::Expression = only(args)
    #= A zero-size array argument: false. =#
    if arg isa ARRAY_EXPRESSION && isempty(arg.elements)
      return BOOLEAN_EXPRESSION(false)
    end
    local id::Int = nodeIdOrZero(graph, toCref(arg))
    if op == CONNECTIONS_OPERATOR_IS_ROOT
      return BOOLEAN_EXPRESSION(id > 0 && tables.isRoot[id])
    end
    local partner::Int = id > 0 ? branchPartner(graph, id) : 0
    if partner == 0
      local str::String = toString(arg)
      Error.addSourceMessage(Error.OCG_MISSING_BRANCH, list(str, str, str), info)
      return BOOLEAN_EXPRESSION(false)
    end
    #= Unreached by any root: true, as omc. =#
    local d1::Int = tables.distance[id]
    local d2::Int = tables.distance[partner]
    return BOOLEAN_EXPRESSION(d1 < 0 || d2 < 0 || d1 < d2)
  elseif op == CONNECTIONS_OPERATOR_UNIQUE_ROOT_INDICES
    @match ARRAY_EXPRESSION(elements = elements) = args[1]
    return makeArray(TYPE_INTEGER(), Expression[INTEGER_EXPRESSION(1) for _ in elements])
  end
  return exp
end

"""A Connections.branch(a, b) under `if condition then ... end if`, with the branch's other equations."""
struct CONDITIONAL_BRANCH
  a::ComponentRef
  b::ComponentRef
  condition::Expression
  body::Vector{Equation}
  source::SourceInfo
end

"""At most 2^8 modes."""
const MAX_CONDITIONAL_BRANCHES = 8

"""True if `eq` is a call of Connections.branch."""
function isBranchCall(@nospecialize(eq::Equation))::Bool
  return isvariant(eq, EQUATION_NORETCALL) && eq.exp isa CALL_EXPRESSION && isvariant(eq.exp.call, TYPED_CALL) &&
    identifyConnectionsOperator(name(eq.exp.call.fn)) == CONNECTIONS_OPERATOR_BRANCH
end

"""
  The conditional branch `eq` states, or nothing when `eq` is not an if-equation
  whose body calls Connections.branch.
"""
function conditionalBranch(@nospecialize(eq::Equation))::Union{Nothing, CONDITIONAL_BRANCH}
  isvariant(eq, EQUATION_IF) || return nothing
  any(br -> isvariant(br, EQUATION_BRANCH) && any(isBranchCall, br.body), eq.branches) || return nothing
  if length(eq.branches) != 1
    error("Connections.branch in an if-equation with more than one branch is not supported: " * toString(eq))
  end
  local br = only(eq.branches)
  local calls = filter(isBranchCall, br.body)
  length(calls) == 1 || error("more than one Connections.branch in one if-equation is not supported: " * toString(eq))
  local args::Vector{Expression} = only(calls).exp.call.arguments
  return CONDITIONAL_BRANCH(toCref(args[1]), toCref(args[2]), br.condition, filter(e -> !isBranchCall(e), br.body), eq.source)
end

isActive(mode::Int, i::Int)::Bool = isodd(mode >> (i - 1))

"""
  Resolves the graph for every mode of the conditional branches `cbs` and returns the equations (the
  mode-dependent ones as one if-equation over the conditions), the initial equations, the variables
  (a mode-dependent binding as an if-expression over the conditions), and the result with all
  branches present, whose broken edges hold for every mode.
"""
function resolveModes(graph::OCC_GRAPH, cbs::Vector{CONDITIONAL_BRANCH}, modelNameQualified::String,
                      eqs::Vector{Equation}, ieqs::Vector{Equation},
                      vars::Vector{VARIABLE})::Tuple{Vector{Equation}, Vector{Equation}, Vector{VARIABLE}, OCC_RESULT}
  local k::Int = length(cbs)
  k <= MAX_CONDITIONAL_BRANCHES ||
    error("$k conditional Connections.branch calls in $modelNameQualified; at most $MAX_CONDITIONAL_BRANCHES are supported")
  local cbIds::Vector{IdPair} = IdPair[(nodeId!(graph, cb.a), nodeId!(graph, cb.b)) for cb in cbs]
  #= All branches present first: the if-equation's first case. =#
  local modes::Vector{Int} = Base.collect((1 << k) - 1:-1:0)
  local graphs::Vector{OCC_GRAPH} = OCC_GRAPH[withBranches(graph, IdPair[cbIds[i] for i in 1:k if isActive(m, i)]) for m in modes]
  local results::Vector{OCC_RESULT} = OCC_RESULT[findResultGraph(g) for g in graphs]
  #= The broken connects decide which connect equations are kept: one set for all modes. =#
  for (m, r) in zip(modes, results)
    r.broken == Base.first(results).broken ||
      error("the conditional branches of $modelNameQualified break different connections in mode " *
            modeString(cbs, m) * " than with all of them present")
  end
  local tables::Vector{OCC_TABLES} = OCC_TABLES[rootTables(g, r) for (g, r) in zip(graphs, results)]
  local outEqs::Vector{Equation} = modeEquations(eqs, cbs, modes, tables, graphs, true)
  local outIeqs::Vector{Equation} = modeEquations(ieqs, cbs, modes, tables, graphs, false)
  local outVars::Vector{VARIABLE} = modeVariables(vars, cbs, modes, tables, graphs)
  return (outEqs, outIeqs, outVars, Base.first(results))
end

"""
  `vars` with the Connections operators in their bindings evaluated for every mode; a binding that
  differs between modes becomes an if-expression over the mode conditions.
"""
function modeVariables(vars::Vector{VARIABLE}, cbs::Vector{CONDITIONAL_BRANCH}, modes::Vector{Int},
                       tables::Vector{OCC_TABLES}, graphs::Vector{OCC_GRAPH})::Vector{VARIABLE}
  if !System.getUsesConnectionsOperators()
    return vars
  end
  local out::Vector{VARIABLE} = vars
  for (k, v) in enumerate(vars)
    containsExp(v.binding, isConnectionsOperatorCall) || continue
    if out === vars
      out = copy(vars)
    end
    local perMode::Vector{Binding} = Binding[mapExp(v.binding, y -> evalConnectionsOperator(y, graphs[j], tables[j], v.info))
                                             for j in eachindex(modes)]
    #= The distinct values, each with the modes that give it. =#
    local values::Vector{Expression} = Expression[]
    local valueModes::Vector{Vector{Int}} = Vector{Int}[]
    local valueStrs::Vector{String} = String[]
    for (j, b) in enumerate(perMode)
      local e::Expression = getExp(b)
      local s::String = toString(e)
      local g::Int = something(findfirst(==(s), valueStrs), 0)
      if g == 0
        push!(values, e); push!(valueModes, Int[modes[j]]); push!(valueStrs, s)
      else
        push!(valueModes[g], modes[j])
      end
    end
    local exp::Expression = values[end]
    for g in length(values) - 1:-1:1
      local cond::Expression = foldl((a, b) -> LBINARY_EXPRESSION(a, makeOr(TYPE_BOOLEAN()), b),
                                     (modeCondition(cbs, m) for m in valueModes[g]))
      exp = IF_EXPRESSION(cond, values[g], exp)
    end
    out[k] = withBinding(v, length(values) == 1 ? Base.first(perMode) : setTypedExp(exp, Base.first(perMode)))
  end
  return out
end

"""The conditions of `mode` as text, for errors."""
modeString(cbs::Vector{CONDITIONAL_BRANCH}, mode::Int) =
  Base.join((toString(cbs[i].condition) * (isActive(mode, i) ? " = true" : " = false") for i in eachindex(cbs)), ", ")

"""
  `eqs` with the Connections operators evaluated for every mode. The equations
  alike in all modes stay; the others, with the bodies of the active
  conditional branches (`withBodies`), become one if-equation over the modes.
"""
function modeEquations(eqs::Vector{Equation}, cbs::Vector{CONDITIONAL_BRANCH}, modes::Vector{Int},
                       tables::Vector{OCC_TABLES}, graphs::Vector{OCC_GRAPH}, withBodies::Bool)::Vector{Equation}
  local dependent = Equation[]
  local out = Equation[]
  for eq in eqs
    push!(usesConnectionsOperators(eq) ? dependent : out, eq)
  end
  local perMode = Base.map(eachindex(modes)) do j
    local decided = Equation[]
    for eq in evalConnectionsOperators(graphs[j], tables[j], dependent)
      appendDecided!(decided, eq)
    end
    if withBodies
      for i in eachindex(cbs)
        isActive(modes[j], i) || continue
        for eq in evalConnectionsOperators(graphs[j], tables[j], cbs[i].body)
          appendDecided!(decided, eq)
        end
      end
    end
    decided
  end
  local strs = [Base.map(toString, p) for p in perMode]
  #= The equations common to all modes, counted: an equation twice in every mode
     is common twice. =#
  local tally(v) = (d = Dict{String, Int}(); foreach(x -> d[x] = get(d, x, 0) + 1, v); d)
  local tallies = Base.map(tally, strs)
  local common = Dict(k => minimum(t -> get(t, k, 0), tallies) for k in Base.keys(Base.first(tallies)))
  #= `eqs` without the common ones (`taken`: with them). =#
  local split(eqs, ks) = begin
    local budget = copy(common)
    local rest = Equation[]
    local taken = Equation[]
    for (eq, k) in zip(eqs, ks)
      get(budget, k, 0) > 0 ? (budget[k] -= 1; push!(taken, eq)) : push!(rest, eq)
    end
    (rest, taken)
  end
  append!(out, split(Base.first(perMode), Base.first(strs))[2])
  #= Per mode what it adds beyond the common equations; modes that add the same
     equations share one branch (one per distinct root assignment). =#
  local groups = Tuple{Vector{String}, Vector{Equation}, Vector{Int}}[]
  for (j, m) in enumerate(modes)
    local own = split(perMode[j], strs[j])[1]
    local ownStrs = sort!(Base.map(toString, own))
    local g = findfirst(grp -> grp[1] == ownStrs, groups)
    g === nothing ? push!(groups, (ownStrs, own, [m])) : push!(groups[g][3], m)
  end
  length(groups) == 1 && (append!(out, groups[1][2]); return out)
  local counts = Base.map(g -> sum(scalarEquationCount, g[2]; init = 0), groups)
  all(==(Base.first(counts)), counts) ||
    error("the modes of the conditional Connections.branch calls have different numbers of equations: " *
          Base.join(("$(modeString(cbs, g[3][1])): $c" for (g, c) in zip(groups, counts)), "; "))
  local branches = EquationBranch[]
  for (j, g) in enumerate(groups)
    local cond = j == length(groups) ? BOOLEAN_EXPRESSION(true) :
      foldl((a, b) -> LBINARY_EXPRESSION(a, makeOr(TYPE_BOOLEAN()), b), (modeCondition(cbs, m) for m in g[3]))
    push!(branches, EQUATION_BRANCH(cond, Variability.DISCRETE, g[2]))
  end
  push!(out, EQUATION_IF(branches, isempty(cbs) ? AbsynUtil.dummyInfo : Base.first(cbs).source))
  return out
end

"""`equations` without the connect equations of the broken edges (either orientation)."""
function removeBrokenConnects(equations::Vector{Equation}, broken::BrokenEdges)::Vector{Equation}
  if listEmpty(broken)
    return equations
  end
  local brokenPairs::Set{Tuple{CrefHashKey, CrefHashKey}} = Set{Tuple{CrefHashKey, CrefHashKey}}()
  for (c1, c2, _) in broken
    push!(brokenPairs, (CrefHashKey(c1), CrefHashKey(c2)))
    push!(brokenPairs, (CrefHashKey(c2), CrefHashKey(c1)))
  end
  local out::Vector{Equation} = Equation[]
  for eq in equations
    if isvariant(eq, EQUATION_CONNECT) && eq.lhs isa CREF_EXPRESSION && eq.rhs isa CREF_EXPRESSION
      local lhs::ComponentRef = eq.lhs.cref
      local rhs::ComponentRef = eq.rhs.cref
      if !(isDeleted(lhs) || isDeleted(rhs)) && (CrefHashKey(lhs), CrefHashKey(rhs)) in brokenPairs
        continue
      end
    end
    push!(out, eq)
  end
  return out
end

"""
  The equation `{0, ...} = equalityConstraint(a, b)` that replaces the broken connect of `clhs` and `crhs`: for the
  first pair of overconstrained crefs in the two connectors. Empty if the model has no overconstrained connectors.
"""
function generateEqualityConstraintEquation(clhs::ComponentRef,
                                            lhs_ty::ModelicaType,
                                            crhs::ComponentRef,
                                            rhs_ty::ModelicaType,
                                            origin::ORIGIN_Type,
                                            source::SourceInfo)::Vector{Equation}
  local eqsEqualityConstraint::Vector{Equation} = Equation[]
  local c1::CONNECTOR
  local c2::CONNECTOR
  local cc1::CONNECTOR
  local cc2::CONNECTOR
  local cl1::List{CONNECTOR}
  local cl2::List{CONNECTOR}
  local cref::ComponentRef
  local eql::Vector{Equation} = Equation[]
  local expLHS::Expression
  local expRHS::Expression
  local fcref_lhs::ComponentRef
  local fcref_rhs::ComponentRef
  local fn_node_lhs::InstNode
  local fn_node_rhs::InstNode
  local lhs::ComponentRef
  local lhsArr::ComponentRef
  local lhsl::List{CONNECTOR}
  local lst::List{Expression}
  local msg::Expression
  local priority::Int
  local replaceEq::Equation
  local rhs::ComponentRef
  local rhsArr::ComponentRef
  local rhsl::List{CONNECTOR}
  local root::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType
  local ty::ModelicaType
  local var::VariabilityType
  if ! System.getHasOverconstrainedConnectors()
    return eqsEqualityConstraint
  end
  if ! (isDeleted(clhs) || isDeleted(crhs))
    cl1 = makeConnectors(clhs, lhs_ty, source)
    cl2 = makeConnectors(crhs, rhs_ty, source)
    for c1 in cl1
      @match _cons(c2, cl2) = cl2
      lhsl = split(c1)
      rhsl = split(c2)
      for cc1 in lhsl
        @match _cons(cc2, rhsl) = rhsl
        if ! (isDeleted(cc1) || isDeleted(cc2))
          lhs = name(cc1)
          rhs = name(cc2)
          if isOverconstrainedCref(lhs) && isOverconstrainedCref(rhs)
            lhs = getOverconstrainedCref(lhs)
            rhs = getOverconstrainedCref(rhs)
            lhsArr = Base.first(stripSubscripts(lhs))
            rhsArr = Base.first(stripSubscripts(rhs))
            ty1 = getComponentType(lhsArr)
            ty2 = getComponentType(rhsArr)
            local eqScope = classScope(node(lhs))
            (fcref_rhs, fn_node_rhs) = get!(_EQ_CONSTRAINT_FN_CACHE, _refId(eqScope)) do
              local fc = lookupFunctionSimple("equalityConstraint", eqScope)
              local (fc2, fn2, _) = instFunctionRef(fc, source)
              (fc2, fn2)
            end
            expRHS = CALL_EXPRESSION(UNTYPED_CALL(fcref_rhs, Expression[CREF_EXPRESSION(ty1, lhsArr), CREF_EXPRESSION(ty2, rhsArr)], Expression[], fn_node_rhs))
            (expRHS, ty, var) = typeExp(expRHS, origin, source)
            local fillScope = topScope(node(clhs))
            (fcref_lhs, fn_node_lhs) = get!(_FILL_FN_CACHE, _refId(fillScope)) do
              local fc = lookupFunctionSimple("fill", fillScope)
              local (fc2, fn2, _) = instFunctionRef(fc, source)
              (fc2, fn2)
            end
            local argLst::List{Expression} = Cons{Expression}(REAL_EXPRESSION(0.0), ListUtil.map(arrayDims(ty), sizeExp, Expression))
            expLHS = CALL_EXPRESSION(UNTYPED_CALL(fcref_lhs, listArray(argLst), Expression[], fn_node_lhs))
            (expLHS, ty, var) = typeExp(expLHS, origin, source)
            replaceEq = EQUATION_EQUALITY(expRHS, expLHS, ty, source)
            eqsEqualityConstraint = [replaceEq]
            return eqsEqualityConstraint
          end
        end
      end
    end
  end
  eqsEqualityConstraint
end

"""The distinct overconstrained crefs in `conn` (its arrays of records split)."""
function getOverconstrainedCrefs(conn::CONNECTOR)::List{ComponentRef}
  local crefs::List{ComponentRef}
  local conns::List{CONNECTOR}
  conns = split(conn, SCALARIZE_PREFIX)
  crefs = list(getOverconstrainedCref(c.name) for c in conns if (!(isDeleted(c)) && isOverconstrainedCref(c.name)))

  crefs = ListUtil.uniqueOnTrue(crefs, isEqual, ComponentRef)
  crefs
end

"""True if a part of `cref` is an overconstrained (equalityConstraint) type."""
function isOverconstrainedCref(cref::ComponentRef) ::Bool
  local b::Bool = false
  local node::InstNode
  local rest::ComponentRef
  b = begin
    @match cref begin
      COMPONENT_REF_CREF(node = node, origin = Origin.CREF, restCref = rest)  => begin
        isOverdetermined(getClass(node)) || isOverconstrainedCref(rest)
      end
      _  => begin
        false
      end
    end
  end
  b
end

"""The prefix of `cref` that ends with its last overconstrained part: `frame_a.R` for `frame_a.R.T`."""
function getOverconstrainedCref(cref::ComponentRef)::ComponentRef
  local c::ComponentRef
  local node::InstNode
  local rest::ComponentRef
  c = begin
    @match cref begin
      COMPONENT_REF_CREF(node = node, origin = Origin.CREF, restCref = rest)  => begin
        if isOverdetermined(getClass(node))
          cref
        else
          getOverconstrainedCref(rest)
        end
      end
    end
  end
  c
end

"""True if `eq` calls a Connections operator that is evaluated (rooted, isRoot, uniqueRootIndices)."""
usesConnectionsOperators(@nospecialize(eq::Equation))::Bool =
  foldExp(eq, (x, found) -> found || contains(x, isConnectionsOperatorCall), false)

"""The condition of `mode`: each conditional branch's condition, negated where the branch is absent."""
function modeCondition(cbs::Vector{CONDITIONAL_BRANCH}, mode::Int)::Expression
  local lit(i) = isActive(mode, i) ? cbs[i].condition :
    LUNARY_EXPRESSION(makeNot(TYPE_BOOLEAN()), cbs[i].condition)
  return foldl((a, b) -> LBINARY_EXPRESSION(a, makeAnd(TYPE_BOOLEAN()), b), (lit(i) for i in eachindex(cbs)))
end

"""
  Appends `eq` to `out`, an if-equation reduced by its conditions that are
  now literals (the evaluated Connections operators): a false branch is
  dropped, a true one taken when no undecided branch precedes it.
"""
function appendDecided!(out::Vector{Equation}, @nospecialize(eq::Equation))::Vector{Equation}
  if !isvariant(eq, EQUATION_IF)
    push!(out, eq)
    return out
  end
  local kept = EquationBranch[]
  for br in eq.branches
    if !isvariant(br, EQUATION_BRANCH)
      push!(kept, br)
      continue
    end
    local cond = simplify(br.condition)
    if cond isa BOOLEAN_EXPRESSION
      cond.value || continue
      if isempty(kept)
        foreach(e -> appendDecided!(out, e), br.body)
        return out
      end
      push!(kept, EQUATION_BRANCH(cond, br.conditionVar, br.body))
      break
    end
    push!(kept, EQUATION_BRANCH(cond, br.conditionVar, br.body))
  end
  isempty(kept) || push!(out, EQUATION_IF(kept, eq.source))
  return out
end

"""The scalar equations `eq` stands for; an error for the kinds the modes cannot count yet."""
function scalarEquationCount(@nospecialize(eq::Equation))::Int
  if isvariant(eq, EQUATION_EQUALITY) || isvariant(eq, EQUATION_ARRAY_EQUALITY)
    #= isScalar holds for records too (Orientation: 12 scalars). =#
    (isScalar(eq.ty) && !isComplex(eq.ty)) && return 1
  elseif isvariant(eq, EQUATION_CREF_EQUALITY)
    local ty = eq.lhs isa Expression ? typeOf(eq.lhs) : getSubscriptedType(eq.lhs)
    (isScalar(ty) && !isComplex(ty)) && return 1
  elseif isvariant(eq, EQUATION_IF) && !isempty(eq.branches) && isvariant(Base.first(eq.branches), EQUATION_BRANCH)
    return sum(scalarEquationCount, Base.first(eq.branches).body; init = 0)
  end
  error("an equation that differs between the modes of conditional Connections.branch calls is not scalar: " *
        toString(eq))
end

"""The `Connections` operator `functionName` names, `CONNECTIONS_OPERATOR_NONE` for any other function."""
function identifyConnectionsOperator(functionName::Absyn.Path)::ConnectionsOperator
  local call::ConnectionsOperator
  call = begin
    local name::String
    @match functionName begin
      Absyn.QUALIFIED(name = "Connections", path = Absyn.IDENT(name = name))  => begin
        begin
          @match name begin
            "branch"  => begin
              CONNECTIONS_OPERATOR_BRANCH
            end

            "root"  => begin
              CONNECTIONS_OPERATOR_ROOT
            end

            "potentialRoot"  => begin
              CONNECTIONS_OPERATOR_POTENTIAL_ROOT
            end

            "isRoot"  => begin
              CONNECTIONS_OPERATOR_IS_ROOT
            end

            "rooted"  => begin
              CONNECTIONS_OPERATOR_ROOTED
            end

            "uniqueRoot"  => begin
              CONNECTIONS_OPERATOR_UNIQUE_ROOT
            end

            "uniqueRootIndices"  => begin
              CONNECTIONS_OPERATOR_UNIQUE_ROOT_INDICES
            end

            _  => begin
              CONNECTIONS_OPERATOR_NONE
            end
          end
        end
      end

      Absyn.IDENT(name = "rooted")  => begin
        CONNECTIONS_OPERATOR_ROOTED
      end

      _  => begin
        CONNECTIONS_OPERATOR_NONE
      end
    end
  end
  call
end
