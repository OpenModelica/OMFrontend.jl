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

module Graph

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

EdgeFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function

EqualFunc = Function
PrintFunc = Function

EqualFunc = Function
PrintFunc = Function

EqualFunc = Function
PrintFunc = Function

NodeToString = Function

NodeToString = Function

CondFunc = Function

CondFunc = Function

EqualFunc = Function
CompareFunc = Function

EqualFunc = Function

EqualFunc = Function

import Frontend.Error

import ListUtil

NodeType = Any

ArgType = Any

"""
  This function will build a graph given a list of nodes, an edge function, and
  an extra argument to the edge function. The edge function should generate a
  list of edges for any given node in the list. From this information a graph
  represented by an adjacency list will be built.

  NOTE: There is no check that there is only unique edges for each node.
  This module assumes that you do not build a graph with duplicate edges!
"""
function buildGraph(
  inNodes::List{<:NodeType},
  inEdgeFunc::EdgeFunc,
  inEdgeArg::ArgType,
)::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph =
    ListUtil.threadTuple(inNodes, ListUtil.map1(inNodes, inEdgeFunc, inEdgeArg))
  return outGraph
end

"""This function will build an empty graph given a list of nodes."""
function emptyGraph(inNodes::List{<:NodeType})::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph = ListUtil.map(inNodes, emptyGraphHelper)
  return outGraph
end

function emptyGraphHelper(nt::NodeType)::Tuple{NodeType, List{NodeType}}
  local out::Tuple{NodeType, List{NodeType}}

  @assign out = (nt, nil)
  return out
end

"""
  This function will sort a graph topologically. It takes a graph represented
  by an adjacency list and a node equality function, and returns a list of the
  nodes ordered by dependencies (a node x is dependent on y if there is an edge
  from x to y). This function assumes that all edges in the graph are unique.

  It is of course only possible to sort an acyclic graph topologically. If the
  graph contains cycles this function will return the nodes that it could sort
  as the first return value, and the remaining graph that contains cycles as the
  second value.
"""
function topologicalSort(
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::Tuple{List{NodeType}, List{Tuple{NodeType, List{NodeType}}}}
  local outRemainingGraph::List{Tuple{NodeType, List{NodeType}}}
  local outNodes::List{NodeType}

  local start_nodes::List{Tuple{NodeType, List{NodeType}}}
  local rest_nodes::List{Tuple{NodeType, List{NodeType}}}

  @assign (rest_nodes, start_nodes) = ListUtil.splitOnTrue(inGraph, hasOutgoingEdges)
  @assign (outNodes, outRemainingGraph) =
    topologicalSort2(start_nodes, rest_nodes, nil, inEqualFunc)
  return (outNodes, outRemainingGraph)
end

"""
  Helper function to topologicalSort, does most of the actual work.
  inStartNodes is a list of start nodes that have no outgoing edges, i.e. no
  dependencies. inRestNodes is the rest of the nodes in the graph.
"""
function topologicalSort2(
  inStartNodes::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inRestNodes::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inAccumNodes::List{<:NodeType},
  inEqualFunc::EqualFunc,
)::Tuple{List{NodeType}, List{Tuple{NodeType, List{NodeType}}}}
  local outRemainingGraph::List{Tuple{NodeType, List{NodeType}}}
  local outNodes::List{NodeType}

  @assign (outNodes, outRemainingGraph) = begin
    local node1::NodeType
    local rest_start::List{Tuple{NodeType, List{NodeType}}}
    local rest_start_::List{Tuple{NodeType, List{NodeType}}}
    local rest_rest::List{Tuple{NodeType, List{NodeType}}}
    local new_start::List{Tuple{NodeType, List{NodeType}}}
    local result::List{NodeType}
    #=  No more nodes to sort, reverse the accumulated nodes (because of
    =#
    #=  accumulation order) and return it with the (hopefully empty) remaining
    =#
    #=  graph.
    =#
    @match (inStartNodes, inRestNodes, inAccumNodes, inEqualFunc) begin
      (nil(), _, _, _) => begin
        (listReverse(inAccumNodes), inRestNodes)
      end

      (rest_start, nil(), _, _) => begin
        #=  If the remaining graph is empty we don't need to do much more, just
        =#
        #=  append the rest of the start nodes to the result.
        =#
        @assign result = inAccumNodes
        for n in rest_start
          @match (node1, nil) = n
          @assign result = _cons(node1, result)
        end
        @assign result = listReverse(result)
        (result, nil)
      end

      ((node1, nil()) <| rest_start, rest_rest, _, _) => begin
        @assign rest_rest = ListUtil.map2(rest_rest, removeEdge, node1, inEqualFunc)
        @assign (rest_rest, new_start) = ListUtil.splitOnTrue(rest_rest, hasOutgoingEdges)
        @assign rest_start_ = listAppend(rest_start, new_start)
        @assign (result, rest_rest) = topologicalSort2(
          rest_start_,
          rest_rest,
          _cons(node1, inAccumNodes),
          inEqualFunc,
        )
        (result, rest_rest)
      end
    end
  end
  #=  Remove the first start node from the graph.
  =#
  #=  Fetch any new nodes that has no dependencies.
  =#
  #=  Append those nodes to the list of start nodes.
  =#
  #=  Add the first node to the list of sorted nodes and continue with the
  =#
  #=  rest of the nodes.
  =#
  return (outNodes, outRemainingGraph)
end

"""Returns true if the given node has no outgoing edges, otherwise false."""
function hasOutgoingEdges(inNode::Tuple{<:NodeType, List{<:NodeType}})::Bool
  local outHasOutEdges::Bool

  @assign outHasOutEdges = begin
    @match inNode begin
      (_, nil()) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return outHasOutEdges
end

"""
  Takes a node with it's edges and a node that's been removed from the graph,
  and removes the edge if it exists in the edge list.
"""
function removeEdge(
  inNode::Tuple{<:NodeType, List{<:NodeType}},
  inRemovedNode::NodeType,
  inEqualFunc::EqualFunc,
)::Tuple{NodeType, List{NodeType}}
  local outNode::Tuple{NodeType, List{NodeType}}

  local node::NodeType
  local edges::List{NodeType}

  @assign (node, edges) = inNode
  @assign (edges, _) = ListUtil.deleteMemberOnTrue(inRemovedNode, edges, inEqualFunc)
  @assign outNode = (node, edges)
  return outNode
end

"""
  Returns the cycles in a given graph. It will check each node, and if that
  node is part of a cycle it will return the cycle. It will also remove the
  other nodes in the cycle from the list of remaining nodes to check, so the
  result will be a list of unique cycles.

  This function is not very efficient, so it shouldn't be used for any
  performance critical tasks.  It's meant to be used together with
  topologicalSort to print an error message if any cycles are detected.
"""
function findCycles(
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::List{List{NodeType}}
  local outCycles::List{List{NodeType}}

  @assign outCycles = findCycles2(inGraph, inGraph, inEqualFunc)
  return outCycles
end

"""Helper function to findCycles."""
function findCycles2(
  inNodes::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::List{List{NodeType}}
  local outCycles::List{List{NodeType}}

  @assign outCycles = begin
    local node::Tuple{NodeType, List{NodeType}}
    local rest_nodes::List{Tuple{NodeType, List{NodeType}}}
    local cycle::List{NodeType}
    local rest_cycles::List{List{NodeType}}
    @matchcontinue (inNodes, inGraph, inEqualFunc) begin
      (nil(), _, _) => begin
        nil
      end

      (node <| rest_nodes, _, _) => begin
        @match SOME(cycle) = findCycleForNode(node, inGraph, nil, inEqualFunc)
        @assign rest_nodes = removeNodesFromGraph(cycle, rest_nodes, inEqualFunc)
        @assign rest_cycles = findCycles2(rest_nodes, inGraph, inEqualFunc)
        _cons(cycle, rest_cycles)
      end

      (_ <| rest_nodes, _, _) => begin
        @assign rest_cycles = findCycles2(rest_nodes, inGraph, inEqualFunc)
        rest_cycles
      end
    end
  end
  #=  Try and find a cycle for the first node.
  =#
  #=  If previous case failed we couldn't find a cycle for that node, so
  =#
  #=  continue with the rest of the nodes.
  =#
  return outCycles
end

"""
  Tries to find a cycle in the graph starting from a given node. This function
  returns an optional cycle, because it's possible that it will encounter a
  cycle in which the given node is not a part. This makes it possible to
  continue searching for another cycle. This function will therefore return some
  cycle if one was found, or fail or return NONE() if no cycle could be found. A
  given node might be part of several cycles, but this function will stop as
  soon as it finds one cycle.
"""
function findCycleForNode(
  inNode::Tuple{<:NodeType, List{<:NodeType}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inVisitedNodes::List{<:NodeType},
  inEqualFunc::EqualFunc,
)::Option{List{NodeType}}
  local outCycle::Option{List{NodeType}}

  @assign outCycle = begin
    local node::NodeType
    local start_node::NodeType
    local edges::List{NodeType}
    local visited_nodes::List{NodeType}
    local cycle::List{NodeType}
    local is_start_node::Bool
    local opt_cycle::Option{List{NodeType}}
    @matchcontinue (inNode, inGraph, inVisitedNodes, inEqualFunc) begin
      ((node, _), _, _ <| _, _) => begin
        @match true = ListUtil.isMemberOnTrue(node, inVisitedNodes, inEqualFunc)
        @assign start_node = ListUtil.last(inVisitedNodes)
        @assign is_start_node = inEqualFunc(node, start_node)
        @assign opt_cycle = if is_start_node
          SOME(inVisitedNodes)
        else
          NONE()
        end
        opt_cycle
      end

      ((node, edges), _, _, _) => begin
        @assign visited_nodes = _cons(node, inVisitedNodes)
        @assign cycle = findCycleForNode2(edges, inGraph, visited_nodes, inEqualFunc)
        SOME(cycle)
      end
    end
  end
  #=  Check if we have already visited this node.
  =#
  #=  Check if the current node is the start node, in that case we're back
  =#
  #=  where we started and we have a cycle. Otherwise we just encountered a
  =#
  #=  cycle in the graph that the start node is not part of.
  =#
  #=  If we have not visited the current node yet we add it to the list of
  =#
  #=  visited nodes, and then call findCycleForNode2 on the edges of the node.
  =#
  return outCycle
end

"""
  Helper function to findCycleForNode. Calls findNodeInGraph on each node in
  the given list.
"""
function findCycleForNode2(
  inNodes::List{<:NodeType},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inVisitedNodes::List{<:NodeType},
  inEqualFunc::EqualFunc,
)::List{NodeType}
  local outCycle::List{NodeType}

  @assign outCycle = begin
    local node::NodeType
    local rest_nodes::List{NodeType}
    local cycle::List{NodeType}
    local graph_node::Tuple{NodeType, List{NodeType}}
    #=  Try and find a cycle by following this edge.
    =#
    @matchcontinue (inNodes, inGraph, inVisitedNodes, inEqualFunc) begin
      (node <| _, _, _, _) => begin
        @assign graph_node = findNodeInGraph(node, inGraph, inEqualFunc)
        @match SOME(cycle) =
          findCycleForNode(graph_node, inGraph, inVisitedNodes, inEqualFunc)
        cycle
      end

      (_ <| rest_nodes, _, _, _) => begin
        @assign cycle = findCycleForNode2(rest_nodes, inGraph, inVisitedNodes, inEqualFunc)
        cycle
      end
    end
  end
  #=  No cycle found in previous case, check the rest of the edges.
  =#
  return outCycle
end

"""
  Returns a node and its edges from a graph given a node to search for, or
  fails if no such node exists in the graph.
"""
function findNodeInGraph(
  inNode::NodeType,
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::Tuple{NodeType, List{NodeType}}
  local outNode::Tuple{NodeType, List{NodeType}}

  @assign outNode = begin
    local node::NodeType
    local graph_node::Tuple{NodeType, List{NodeType}}
    local rest_graph::List{Tuple{NodeType, List{NodeType}}}
    @matchcontinue (inNode, inGraph, inEqualFunc) begin
      (_, graph_node && (node, _) <| _, _) => begin
        @match true = inEqualFunc(inNode, node)
        graph_node
      end

      (_, _ <| rest_graph, _) => begin
        findNodeInGraph(inNode, rest_graph, inEqualFunc)
      end
    end
  end
  return outNode
end

"""
  Returns the index in the list of the node  from a graph given a node to search for, or
  fails if no such node exists in the graph.
"""
function findIndexofNodeInGraph(
  inNode::NodeType,
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
  inIndex::Int,
)::Int
  local outIndex::Int

  @assign outIndex = begin
    local node::NodeType
    local graph_node::Tuple{NodeType, List{NodeType}}
    local rest_graph::List{Tuple{NodeType, List{NodeType}}}
    @matchcontinue (inNode, inGraph, inEqualFunc, inIndex) begin
      (_, (node, _) <| _, _, _) => begin
        @match true = inEqualFunc(inNode, node)
        inIndex
      end

      (_, _ <| rest_graph, _, _) => begin
        findIndexofNodeInGraph(inNode, rest_graph, inEqualFunc, inIndex + 1)
      end
    end
  end
  return outIndex
end

"""
  Removed a list of nodes from the graph. Note that only the nodes are removed
  and not any edges pointing at the nodes.
"""
function removeNodesFromGraph(
  inNodes::List{<:NodeType},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph = begin
    local graph_node::Tuple{NodeType, List{NodeType}}
    local rest_graph::List{Tuple{NodeType, List{NodeType}}}
    local rest_nodes::List{NodeType}
    local node::NodeType
    @matchcontinue (inNodes, inGraph, inEqualFunc) begin
      (nil(), _, _) => begin
        inGraph
      end

      (_, nil(), _) => begin
        nil
      end

      (_, (node, _) <| rest_graph, _) => begin
        @match (rest_nodes, SOME(_)) =
          ListUtil.deleteMemberOnTrue(node, inNodes, inEqualFunc)
        removeNodesFromGraph(rest_nodes, rest_graph, inEqualFunc)
      end

      (_, graph_node <| rest_graph, _) => begin
        @assign rest_graph = removeNodesFromGraph(inNodes, rest_graph, inEqualFunc)
        _cons(graph_node, rest_graph)
      end
    end
  end
  return outGraph
end

"""
  This function transposes a graph by given a graph and vertex list.
  To call this, use transposeGraph(emptyGraphOnlyNodes,graph,eqFunction).
"""
function transposeGraph(
  intmpGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph = begin
    local node::NodeType
    local nodeList::List{NodeType}
    local vertex::Tuple{NodeType, List{NodeType}}
    local restGraph::List{Tuple{NodeType, List{NodeType}}}
    local tmpGraph::List{Tuple{NodeType, List{NodeType}}}
    @matchcontinue (intmpGraph, inGraph, inEqualFunc) begin
      (_, nil(), _) => begin
        intmpGraph
      end

      (_, (node, nodeList) <| restGraph, _) => begin
        @assign tmpGraph =
          ListUtil.fold2(nodeList, insertNodetoGraph, node, inEqualFunc, intmpGraph)
        @assign tmpGraph = transposeGraph(tmpGraph, restGraph, inEqualFunc)
        tmpGraph
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.transpose failed."),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return outGraph
end

"""
  This function takes nodes and a vertex and inserts
  the vertex to list of nodes of the graph.
"""
function insertNodetoGraph(
  inNode::NodeType,
  inVertex::NodeType,
  inEqualFunc::EqualFunc,
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
)::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph = begin
    local node::NodeType
    local rest::List{NodeType}
    local restGraph::List{Tuple{NodeType, List{NodeType}}}
    @matchcontinue (inNode, inVertex, inEqualFunc, inGraph) begin
      (_, _, _, nil()) => begin
        nil
      end

      (_, _, _, (node, rest) <| restGraph) => begin
        @match true = inEqualFunc(node, inNode)
        @assign rest = ListUtil.unionList(list(rest, list(inVertex)))
        @assign restGraph = insertNodetoGraph(inNode, inVertex, inEqualFunc, restGraph)
        _cons((node, rest), restGraph)
      end

      (_, _, _, (node, rest) <| restGraph) => begin
        @match false = inEqualFunc(node, inNode)
        @assign restGraph = insertNodetoGraph(inNode, inVertex, inEqualFunc, restGraph)
        _cons((node, rest), restGraph)
      end
    end
  end
  return outGraph
end

"""
  This function searches for a starting node in M
  all reachable nodes. Call with start node in M: allReachableNodes((start,{}),graph,eqFn).
"""
function allReachableNodes(
  intmpstorage::Tuple{<:List{<:NodeType}, List{<:NodeType}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::List{NodeType}
  local reachableNodes::List{NodeType} #= Is NONE() on error to prevent recursion =#

  @match SOME(reachableNodes) = allReachableNodesWork(intmpstorage, inGraph, inEqualFunc)
  return reachableNodes #= Is NONE() on error to prevent recursion =#
end

"""
  This function searches for a starting node in M
  all reachable nodes. Call with start node in M: allReachableNodes((start,{}),graph,eqFn).
"""
function allReachableNodesWork(
  intmpstorage::Tuple{<:List{<:NodeType}, List{<:NodeType}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
)::Option{List{NodeType}}
  local reachableNodes::Option{List{NodeType}} #= Is NONE() on error to prevent recursion =#

  @assign reachableNodes = begin
    local tmpstorage::Tuple{List{NodeType}, List{NodeType}}
    local node::NodeType
    local edges::List{NodeType}
    local M::List{NodeType}
    local L::List{NodeType}
    local restGraph::List{Tuple{NodeType, List{NodeType}}}
    @matchcontinue (intmpstorage, inGraph, inEqualFunc) begin
      ((nil(), L), _, _) => begin
        @assign L = listReverse(L)
        SOME(L)
      end

      ((node <| M, L), _, _) => begin
        ListUtil.getMemberOnTrue(node, L, inEqualFunc)
        allReachableNodesWork((M, L), inGraph, inEqualFunc)
      end

      ((node <| M, L), _, _) => begin
        @assign L = _cons(node, L)
        @assign (_, edges) = findNodeInGraph(node, inGraph, inEqualFunc)
        @assign M = listAppend(edges, M)
        allReachableNodesWork((M, L), inGraph, inEqualFunc)
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.allReachableNodes failed."),
          sourceInfo(),
        )
        NONE()
      end
    end
  end
  #= print(\" List size 1 \" + intString(listLength(L)) + \"\\n\");
  =#
  #= print(\" List size 2 \" + intString(listLength(edges)) + \"\\n\");
  =#
  #= print(\" List size 3 \" + intString(listLength(edges)) + \"\\n\");
  =#
  #= print(\"Start new round! \\n\");
  =#
  return reachableNodes #= Is NONE() on error to prevent recursion =#
end

"""
  A greedy partial distance-2 coloring algorithm.
  procedure G REEDY PARTIAL D2C OLORING(Gb = (V1 ,V2 , E))
  Let u1 , u2 , . . ., un be a given ordering of V2 , where n = |V2 |
  Initialize forbiddenColors with some value a in V2
  for i = 1 to n do
  for each vertex w such that (ui , w) in E do
  for each colored vertex x such that (w, x) in E do
  forbiddenColors[color[x]] <- ui
  color[ui ] <- min{c > 0 : forbiddenColors[c] = ui }
"""
function partialDistance2color(
  toColorNodes::List{<:NodeType},
  inforbiddenColor::Array{<:Option{<:List{<:NodeType}}},
  inColors::List{<:Integer},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inGraphT::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inColored::Array{<:Integer},
  inEqualFunc::EqualFunc,
  inPrintFunc::PrintFunc,
)::Array{Integer}
  local outColored::Array{Integer}

  @assign outColored = begin
    local node::NodeType
    local rest::List{NodeType}
    local nodes::List{NodeType}
    local forbiddenColor::Array{Option{List{NodeType}}}
    local colored::Array{Integer}
    local color::Int
    local index::Int
    @matchcontinue (
      toColorNodes,
      inforbiddenColor,
      inColors,
      inGraph,
      inGraphT,
      inColored,
      inEqualFunc,
      inPrintFunc,
    ) begin
      (nil(), _, _, _, _, _, _, _) => begin
        inColored
      end

      (node <| rest, _, _, _, _, _, _, _) => begin
        @assign index = arrayLength(inColored) - listLength(rest)
        @assign (_, nodes) = findNodeInGraph(node, inGraphT, inEqualFunc)
        @assign forbiddenColor = addForbiddenColors(
          node,
          nodes,
          inColored,
          inforbiddenColor,
          inGraph,
          inEqualFunc,
          inPrintFunc,
        )
        @assign color = arrayFindMinColorIndex(
          forbiddenColor,
          node,
          1,
          arrayLength(inColored) + 1,
          inEqualFunc,
          inPrintFunc,
        )
        @assign colored = arrayUpdate(inColored, index, color)
        @assign colored = partialDistance2color(
          rest,
          forbiddenColor,
          inColors,
          inGraph,
          inGraphT,
          colored,
          inEqualFunc,
          inPrintFunc,
        )
        colored
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.partialDistance2color failed."),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return outColored
end

function addForbiddenColors(
  inNode::NodeType,
  inNodes::List{<:NodeType},
  inColored::Array{<:Integer},
  inForbiddenColor::Array{<:Option{<:List{<:NodeType}}},
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inEqualFunc::EqualFunc,
  inPrintFunc::PrintFunc,
)::Array{Option{List{NodeType}}}
  local outForbiddenColor::Array{Option{List{NodeType}}}

  @assign outForbiddenColor = begin
    local node::NodeType
    local rest::List{NodeType}
    local nodes::List{NodeType}
    local indexes::List{Integer}
    local indexesColor::List{Integer}
    local indexesStr::List{String}
    local forbiddenColor::Array{Option{List{NodeType}}}
    local forbiddenColor1::Array{Option{List{NodeType}}}
    local listOptFobiddenColors::List{Option{List{NodeType}}}
    local listFobiddenColors::List{List{NodeType}}
    @matchcontinue (
      inNode,
      inNodes,
      inColored,
      inForbiddenColor,
      inGraph,
      inEqualFunc,
      inPrintFunc,
    ) begin
      (_, nil(), _, _, _, _, _) => begin
        inForbiddenColor
      end

      (_, node <| rest, _, forbiddenColor, _, _, _) => begin
        @assign (_, nodes) = findNodeInGraph(node, inGraph, inEqualFunc)
        @assign indexes =
          ListUtil.map3(nodes, findIndexofNodeInGraph, inGraph, inEqualFunc, 1)
        @assign indexes = ListUtil.select1(indexes, arrayElemetGtZero, inColored)
        @assign indexesColor = ListUtil.map1(indexes, getArrayElem, inColored)
        ListUtil.map2_0(
          indexesColor,
          arrayUpdateListAppend,
          forbiddenColor,
          SOME(list(inNode)),
        )
        @assign forbiddenColor1 = addForbiddenColors(
          inNode,
          rest,
          inColored,
          forbiddenColor,
          inGraph,
          inEqualFunc,
          inPrintFunc,
        )
        forbiddenColor1
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.addForbiddenColors failed."),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return outForbiddenColor
end

function getArrayElem(inIndex::Int, inArray::Array{<:Type_a})::Type_a
  local outElem::Type_a

  @assign outElem = arrayGet(inArray, inIndex)
  return outElem
end

function arrayUpdateListAppend(
  inIndex::Int,
  inArray::Array{<:Option{<:List{<:NodeType}}},
  inNode::Option{<:List{<:NodeType}},
)
  local arrayElem::List{NodeType}

  return @assign _ = begin
    local arrElem::List{NodeType}
    @matchcontinue (inIndex, inArray) begin
      (_, _) => begin
        arrayUpdate(inArray, inIndex, inNode)
        ()
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.arrayUpdateListAppend failed."),
          sourceInfo(),
        )
        fail()
      end
    end
  end
end

function arrayElemetGtZero(inIndex::Int, inArray::Array{<:Integer})::Bool
  local outBoolean::Bool

  @assign outBoolean = intGt(arrayGet(inArray, inIndex), 0)
  return outBoolean
end

function arrayFindMinColorIndex(
  inForbiddenColor::Array{<:Option{<:List{<:NodeType}}},
  inNode::NodeType,
  inIndex::Int,
  inmaxIndex::Int,
  inEqualFunc::EqualFunc,
  inPrintFunc::PrintFunc,
)::Int
  local outColor::Int

  @assign outColor = begin
    local nodes::List{NodeType}
    local index::Int
    @matchcontinue (inForbiddenColor, inNode, inIndex, inmaxIndex, inEqualFunc, inPrintFunc) begin
      (_, _, _, _, _, _) => begin
        @match NONE() = arrayGet(inForbiddenColor, inIndex)
        inIndex
      end

      (_, _, _, _, _, _) => begin
        @match SOME(nodes) = arrayGet(inForbiddenColor, inIndex)
        @shouldFail @assign _ = ListUtil.getMemberOnTrue(inNode, nodes, inEqualFunc)
        inIndex
      end

      _ => begin
        @match SOME(nodes) = arrayGet(inForbiddenColor, inIndex)
        ListUtil.getMemberOnTrue(inNode, nodes, inEqualFunc)
        @assign index = arrayFindMinColorIndex(
          inForbiddenColor,
          inNode,
          inIndex + 1,
          inmaxIndex,
          inEqualFunc,
          inPrintFunc,
        )
        index
      end
    end
  end
  #= print(\"Found color on index : \" + intString(inIndex) + \"\\n\");
  =#
  #= inPrintFunc(nodes,\"FobiddenColors:\" );
  =#
  #= print(\"Found color on index : \" + intString(inIndex) + \"\\n\");
  =#
  #= inPrintFunc(nodes,\"FobiddenColors:\" );
  =#
  #= print(\"Not found color on index : \" + intString(inIndex) + \"\\n\");
  =#
  return outColor
end

function printGraph(
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inPrintFunc::NodeToString,
)::String
  local outString::String

  @assign outString =
    stringDelimitList(ListUtil.map1(inGraph, printNode, inPrintFunc), "\\n")
  return outString
end

function printNode(
  inNode::Tuple{<:NodeType, List{<:NodeType}},
  inPrintFunc::NodeToString,
)::String
  local outString::String

  local node::NodeType
  local edges::List{NodeType}
  local node_str::String
  local edges_str::String

  @assign (node, edges) = inNode
  @assign node_str = inPrintFunc(node)
  @assign edges_str = stringDelimitList(ListUtil.map(edges, inPrintFunc), ", ")
  @assign outString = node_str + ": " + edges_str
  return outString
end

#= /* Functions for Integer graphs */ =#

"""
  This function prints an Integer Graph.
  Useful for debuging.
"""
function printGraphInt(inGraph::List{<:Tuple{<:Integer, List{<:Integer}}})
  return @assign _ = begin
    local node::Int
    local edges::List{Integer}
    local strEdges::List{String}
    local restGraph::List{Tuple{Integer, List{Integer}}}
    @match inGraph begin
      nil() => begin
        ()
      end

      (node, edges) <| restGraph => begin
        print("Node : " + intString(node) + " Edges: ")
        @assign strEdges = ListUtil.map(edges, intString)
        @assign strEdges = ListUtil.map1(strEdges, stringAppend, " ")
        ListUtil.map_0(strEdges, print)
        print("\\n")
        printGraphInt(restGraph)
        ()
      end
    end
  end
end

"""
  This function prints an Integer List Nodes.
  Useful for debuging.
"""
function printNodesInt(inListNodes::List{<:Integer}, inName::String)
  return @assign _ = begin
    local strNodes::List{String}
    @match (inListNodes, inName) begin
      (nil(), _) => begin
        print(inName + "\\n")
        ()
      end

      (_, _) => begin
        print(inName + " : ")
        @assign strNodes = ListUtil.map(inListNodes, intString)
        @assign strNodes = ListUtil.map1(strNodes, stringAppend, " ")
        ListUtil.map_0(strNodes, print)
        print("\\n")
        ()
      end
    end
  end
end

"""
  This function searches for a starting node in M
  all reachabel nodes. Call with start nodes in M. The
  result is collected in L.
"""
function allReachableNodesInt(
  intmpstorage::Tuple{<:List{<:Integer}, List{<:Integer}},
  inGraph::Array{<:Tuple{<:Integer, List{<:Integer}}},
  inMaxGraphNode::Int,
  inMaxNodexIndex::Int,
)::List{Integer}
  local reachableNodes::List{Integer}

  @assign reachableNodes = begin
    local tmpstorage::Tuple{List{Integer}, List{Integer}}
    local node::Int
    local edges::List{Integer}
    local M::List{Integer}
    local L::List{Integer}
    @matchcontinue (intmpstorage, inGraph, inMaxGraphNode, inMaxNodexIndex) begin
      ((nil(), L), _, _, _) => begin
        L
      end

      ((node <| M, L), _, _, _) => begin
        @assign L = ListUtil.union(L, list(node))
        @match false = intGe(node, inMaxGraphNode)
        @assign (_, edges) = arrayGet(inGraph, node)
        @assign edges = ListUtil.filter1OnTrue(edges, ListUtil.notMember, L)
        @assign M = ListUtil.union(M, edges)
        @assign reachableNodes =
          allReachableNodesInt((M, L), inGraph, inMaxGraphNode, inMaxNodexIndex)
        reachableNodes
      end

      ((node <| M, L), _, _, _) => begin
        @assign L = ListUtil.union(L, list(node))
        @match true = intGe(node, inMaxGraphNode)
        @assign reachableNodes =
          allReachableNodesInt((M, L), inGraph, inMaxGraphNode, inMaxNodexIndex)
        reachableNodes
      end

      _ => begin
        Error.addSourceMessage(
          Error.INTERNAL_ERROR,
          list("Graph.allReachableNodesInt failed."),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return reachableNodes
end

"""
  A greedy partial distance-2 coloring algorithm.
  procedure GREEDY PARTIAL D2COLORING(Gb = (V1 ,V2 , E))
  Let u1 , u2 , . . ., un be a given ordering of V2 , where n = |V2 |
  Initialize forbiddenColors with some value a in V2
  for i = 1 to n do
  for each vertex w such that (ui , w) in E do
  for each colored vertex x such that (w, x) in E do
  forbiddenColors[color[x]] <- ui
  color[ui ] <- min{c > 0 : forbiddenColors[c] = ui }
"""
function partialDistance2colorInt(
  inGraphT::List{<:Tuple{<:Integer, List{<:Integer}}},
  inforbiddenColor::Array{<:Integer},
  inColors::List{<:Integer},
  inGraph::Array{<:Tuple{<:Integer, List{<:Integer}}},
  inColored::Array{<:Integer},
)
  local node::Int
  local color::Int
  local nodes::List{Integer}
  local forbiddenColor::Array{Integer}
  local color::Int
  local restGraph::List{Tuple{Integer, List{Integer}}}

  return try
    for tpl in inGraphT
      @assign (node, nodes) = tpl
      addForbiddenColorsInt(node, nodes, inColored, inforbiddenColor, inGraph)
      @assign color = arrayFindMinColorIndexInt(inforbiddenColor, node)
      arrayUpdate(inColored, node, color)
    end
  catch
    Error.addSourceMessage(
      Error.INTERNAL_ERROR,
      list("Graph.partialDistance2colorInt failed."),
      sourceInfo(),
    )
  end
end

function addForbiddenColorsInt(
  inNode::Int,
  nodes::List{<:Integer},
  inColored::Array{<:Integer},
  forbiddenColor::Array{<:Integer},
  inGraph::Array{<:Tuple{<:Integer, List{<:Integer}}},
)
  local indexes::List{Integer}

  return try
    for node in nodes
      @assign (_, indexes) = arrayGet(inGraph, node)
      updateForbiddenColorArrayInt(indexes, inColored, forbiddenColor, inNode)
    end
  catch
    Error.addSourceMessage(
      Error.INTERNAL_ERROR,
      list("Graph.addForbiddenColors failed."),
      sourceInfo(),
    )
    fail()
  end
end

function updateForbiddenColorArrayInt(
  inIndexes::List{<:Integer},
  inColored::Array{<:Integer},
  inForbiddenColor::Array{<:Integer},
  inNode::Int,
)
  local colorIndex::Int

  return for index in inIndexes
    @assign colorIndex = arrayGet(inColored, index)
    if colorIndex > 0
      arrayUpdate(inForbiddenColor, colorIndex, inNode)
    end
  end
end

function arrayFindMinColorIndexInt(
  inForbiddenColor::Array{<:Integer},
  inNode::Int,
)::Int
  local outColor::Int = 1

  while true
    if arrayGet(inForbiddenColor, outColor) != inNode
      return outColor
    else
      @assign outColor = outColor + 1
    end
  end
  return outColor
end

"""
  Removes any node for which the given function evaluates to false, as well as
  any edge pointing at that node.
"""
function filterGraph(
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  inCondFunc::CondFunc,
)::List{Tuple{NodeType, List{NodeType}}}
  local outGraph::List{Tuple{NodeType, List{NodeType}}}

  @assign outGraph = ListUtil.accumulateMapAccum1(inGraph, filterGraph2, inCondFunc)
  return outGraph
end

"""Helper function to filterGraph."""
function filterGraph2(
  inNode::Tuple{<:NodeType, List{<:NodeType}},
  inCondFunc::CondFunc,
  inAccumGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
)::List{Tuple{NodeType, List{NodeType}}}
  local outNode::List{Tuple{NodeType, List{NodeType}}}

  @assign outNode = begin
    local node::NodeType
    local edges::List{NodeType}
    @matchcontinue (inNode, inCondFunc, inAccumGraph) begin
      ((node, _), _, _) => begin
        @match false = inCondFunc(node)
        inAccumGraph
      end

      ((node, edges), _, _) => begin
        @assign edges = ListUtil.filterOnTrue(edges, inCondFunc)
        _cons((node, edges), inAccumGraph)
      end
    end
  end
  return outNode
end

"""Merges the nodes of two different graphs. Needs an ordering function in order to be efficient."""
function merge(
  graph1::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  graph2::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  eqFunc::EqualFunc,
  compareFunc::CompareFunc,
)::List{Tuple{NodeType, List{NodeType}}}
  local graph::List{Tuple{NodeType, List{NodeType}}}

  @assign graph =
    merge2(ListUtil.sort(listAppend(graph1, graph2), compareFunc), eqFunc, nil)
  return graph
end

function merge2(
  inGraph::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  eqFunc::EqualFunc,
  inAcc::List{<:Tuple{<:NodeType, List{<:NodeType}}},
)::List{Tuple{NodeType, List{NodeType}}}
  local graph::List{Tuple{NodeType, List{NodeType}}}

  @assign graph = begin
    local rest::List{Tuple{NodeType, List{NodeType}}}
    local node::Tuple{NodeType, List{NodeType}}
    local n1::NodeType
    local n2::NodeType
    local e1::List{NodeType}
    local e2::List{NodeType}
    local b::Bool
    @match (inGraph, eqFunc, inAcc) begin
      (nil(), _, _) => begin
        listReverse(inAcc)
      end

      (node <| nil(), _, _) => begin
        listReverse(_cons(node, inAcc))
      end

      ((n1, e1) <| (n2, e2) <| rest, _, _) => begin
        @assign b = eqFunc(n1, n2)
        @assign (node, rest) = merge3(b, n1, e1, n2, e2, rest, eqFunc)
        merge2(rest, eqFunc, _cons(node, inAcc))
      end
    end
  end
  return graph
end

function merge3(
  b::Bool,
  n1::NodeType,
  e1::List{<:NodeType},
  n2::NodeType,
  e2::List{<:NodeType},
  rest::List{<:Tuple{<:NodeType, List{<:NodeType}}},
  eqFunc::EqualFunc,
)::Tuple{Tuple{NodeType, List{NodeType}}, List{Tuple{NodeType, List{NodeType}}}}
  local outRest::List{Tuple{NodeType, List{NodeType}}}
  local elt::Tuple{NodeType, List{NodeType}}

  @assign (elt, outRest) = begin
    @match (b, n1, e1, n2, e2, rest, eqFunc) begin
      (true, _, _, _, _, _, _) => begin
        ((n1, ListUtil.unionOnTrue(e1, e2, eqFunc)), rest)
      end

      (false, _, _, _, _, _, _) => begin
        ((n1, e1), _cons((n2, e2), rest))
      end
    end
  end
  return (elt, outRest)
end

@exportAll()
end
