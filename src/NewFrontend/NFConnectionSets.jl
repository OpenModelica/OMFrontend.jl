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

#=
Original code by Per Ost
Rewritten by John Tinnerholm(johti17)
(Hence not automatic logic beware here may be bugs...)
=#
module ConnectionSets

using MetaModelica
using ExportAll

import DataStructures
import ListUtil
import Base.string
import Base.length

import ..NFConnector
import ..CONNECTOR
import ..NFConnections
import ..Frontend.CONNECTION
import ..Frontend.split
import ..Frontend.toString
import ..Frontend.toDebugString
import ..Frontend.isEqual
import ..Frontend.name
import ..Frontend.isPrefix
const Connector = NFConnector
const Connections = NFConnections
const Entry = Connector

#= NOTE: the hash renders the cref to a string on purpose. The dict iteration
   order in extractSets defines the connection-equation output order that the
   reference tests encode; a structural hash permutes it. =#
function Base.hash(conn::Entry, h::UInt)
  local str = toString(conn.name)
  local hv = Base.hash(str, h)
  return hv
end

Base.isequal(entry1::Entry, entry2::Entry) = begin
  b = isEqual(entry1.name, entry2.name) && entry1.face == entry2.face
  return b
end

#= Using the Disjoint set data structure =#
struct Sets
  nodes::Vector{Int}  #"An array of nodes"
  elements::Dict{Entry, Int} #A Entry->Integer hashtable, see bottom of file.";
  nodeCount::Int #"The number of nodes stored in the sets."
end

function string(s::Sets)
  str = "Nodes:" * toString(s.nodes) * "\n"
  str *= "Node Count:$(s.nodeCount)\n"
  str *= "Elements:\n"
  for e in s.elements
    str *= "$(toString(e[1]))| node_index:$(e[2])\n"
  end
  return str
end

"""
Creates a new disjoint-sets structure.
Ignore the set count as per Adrians comment.
"""
function emptySets(setCount)
  sz = max(setCount, 3)
  nodes = arrayCreate(sz, -1)
  elements = Dict{Entry, Int}()
  return Sets(nodes, elements, 0)
end

"""Creates a new DisjointSets from a list of connection and flow variables."""
function fromConnections(connections)
  #ENV["JULIA_DEBUG"] = "" #Activate debug
#  #@debug "fromConnections: Our connections" connections
  local sz = listLength(connections.connections) + listLength(connections.flows)
  local sets::Sets = emptySets(sz) # duh, is not possible to give sz size hint to DisjointSets! -Adrian Pop
  #@debug "Sets before from connections $(string(sets))"
  # Add flow variable to the sets, unless disabled by flag.
  # Do this here if NF_SCALARIZE to use fast addList for scalarized flows.
  # if ! Flags.isSet(Flags.DISABLE_SINGLE_FLOW_EQ) && Flags.isSet(Flags.NF_SCALARIZE) then
  #@debug "Before ListUtil 1 $(string(sets))"
  sets = ListUtil.fold(connections.flows, addConnector, sets)
  # end
  # Add the connections.
  #@debug "Before ListUtil 2 $(string(sets))"
  sets = ListUtil.fold1(connections.connections, addConnection, connections.broken, sets)
  # Add remaining flow variables to the sets, unless disabled by flag.
  # Do this after addConnection if not NF_SCALARIZE to get array dims right.
  #if ! Flags.isSet(Flags.DISABLE_SINGLE_FLOW_EQ) && ! Flags.isSet(Flags.NF_SCALARIZE) then
  #sets = ListUtil.fold(connections.flows, addSingleConnector, sets)
  #end
  #@debug "Sets after from connections $(string(sets))"
  return sets
end

"""Adds a single connector to the connection sets."""
function addScalarConnector(conn, sets)
  sets = add(sets, conn)
  return sets
end

    "Adds a connection to the sets, which means merging the two sets that the
     connectors belong to, unless they already belong to the same set."

function addConnection(connection, broken, sets)
  local conns
  conns = split(connection);
  if ! listEmpty(broken)
    conns = list(c for c in conns if !(isBroken(c.lhs, c.rhs, broken)))
  end
  #TODO: Check variability of connectors. It's an error if either
  #connector is constant/parameter while the other isn't.
  for conn in conns
    sets = merge(conn.lhs, conn.rhs, sets);
  end
  return sets
end #=addConnection=#

function addConnector(conn, sets)
  sets = addList(split(conn), sets)
  #@debug "After addConnector $(string(sets))"
  return sets
end

""" Adds a connector to the sets if it does not already exist  """
function addSingleConnector(conn, sets)
  for c in #= Connector. =# split(conn)
    sets = find(c, sets)
  end
  return sets
end

"""What is the definition here?"""
function isBroken(c1, c2, broken)::Bool
  local cr1 = name(c1)
  local cr2 = name(c2)
  local b = false
  # print("Check: connect(" + ComponentRef.toString(cr1) + ", " + ComponentRef.toString(cr2) + ")\n");
  for c in broken
    @match ((lhs, rhs, _)) = c
    if (isPrefix(lhs, cr1) && isPrefix(rhs, cr2)) || (isPrefix(lhs, cr2) && isPrefix(rhs, cr1))
      # print("Ignore broken: connect(" + Connector.toString(c1) + ", " + Connector.toString(c2) + ")\n")
      b = true
      break
    end
  end
  return b;
end

""" Merges the two sets that the given entry belong to """
function merge(conn1, conn2, sets)
  #@debug "Sets before merge: $(string(sets))"
  #= Get the index of the two sets now. =#
  (set1Idx, sets) = findSet(conn1, sets);
  (set2Idx, sets) = findSet(conn2, sets);
  #= We need to access the integer internals of disjoint set.=#
  sets = union(set1Idx, set2Idx, sets)
  #@debug "Sets after merge: $(string(sets))"
  #= Return the modified set=#
  return sets
end

 """This function finds and returns the set that the given entry belongs to.
  The set is represented by the root node of the tree. If the entry does not
  have a corresponding node in the forest, then a new set with the entry as the
  only element will be added to the forest and returned.

   The reason why this function also returns the sets is because it does path
   compression, and the disjoint-set structure may therefore be changed during
   look up."""
function findSet(entry, sets)
#protected
  local index::Int
  #Look up the index of the entry.
  (updatedSets, index) = find(entry, sets)
  # Return the index of the root of the tree that the entry belongs to.
  set = findRoot(index, updatedSets.nodes);
  return (set, updatedSets)
end

"""Returns the index of the root of the tree that a node belongs to."""
function findRoot(nodeIndex::Int, nodes::Vector)
  rootIndex::Int = nodeIndex;
#protected
  parent = nodes[nodeIndex]
  idx = nodeIndex;
  # Follow the parent indices until we find a negative index, which indicates a root.
  while parent > 0
    rootIndex = parent;
    parent = nodes[parent];
  end
  # Path compression. Attach each of the traversed nodes directly to the root,
  # to speed up repeated calls.
  parent = nodes[nodeIndex];
  while parent > 0
    arrayUpdate(nodes, idx, rootIndex);
    idx = parent;
    parent = nodes[parent];
  end
  return rootIndex
end


"""
Merges two sets into one. This is done by attaching one set-tree to the
other. The ranks are compared to determine which of the trees is the
smallest, and that one is attached to the larger one to keep the trees as
flat as possible.
"""
function union(set1::Int, set2::Int, sets)
  local rank1
  local rank2
  #@debug "Sets before union"
  if set1 != set2
    # Assume that the indices actually point to root nodes, in which case the
    # entries in the node array is actually the ranks of the nodes.
    rank1 = sets.nodes[set1];
    rank2 = sets.nodes[set2];
    if rank1 > rank2
      #First set is smallest, attach it to the second set.
      arrayUpdate(sets.nodes, set2, set1);
    elseif rank1 < rank2
      # Second set is smallest, attach it to the first set.
      arrayUpdate(sets.nodes, set1, set2);
    else
      #Both sets are the same size. Attach the second to the first, and
      #increase the rank of the first with one (which means decreasing it,
      # since the rank is stored as a negative number).
      arrayUpdate(sets.nodes, set1, sets.nodes[set1] - 1);
      arrayUpdate(sets.nodes, set2, set1);
    end
  end
  #@debug "Sets after union"
  return sets
end



""" Find function, replication of the functionality in DisjointSets.mo """
function find(entry, sets)::Tuple
  local idx::Int = get(sets.elements, entry, 0)
  if idx > 0
    return (sets, idx)
  end
  #= The node does not exist, create a new one. =#
  (sets, idx) = add(entry, sets)
  return (sets, idx)
end

"""
  Returns an array indexed by the group index
  each pos contains a set Vector{List{Entry}}
  Author:johti17
"""
function extractSets(sets::Sets)
  #@debug("Sets before extractSets $(string(sets))")
#  input Sets sets;
#  output array<list<Entry>> setsArray "An array with all the sets.";
#  output Sets assignedSets "Sets with the roots assigned to sets.";
  local nodes
  local set_idx::Int = 0
  local idx::Int
  local entries;
  local e::Entry;
  nodes = sets.nodes;
  #Go through each node and assign a unique set index to each root node.
  #The index is stored as a negative number to mark the node as a root.
  for i in 1:sets.nodeCount
    if nodes[i] < 0
      set_idx = set_idx + 1;
      nodes[i] = -set_idx;
    end
  end
  #Create an array of lists to store the sets in, and fetch the list of
  #entry-index pairs stored in the hashtable.
  local setsArray = List{Entry}[] #arrayCreate(set_idx, list());
  for _ in 1:set_idx
    push!(setsArray, list())
  end
  entries = sets.elements
  #Go through each entry-index pair.
  for p in entries
    (e, idx) = p
    #Follow the parent indices until we find the root.
    set_idx = nodes[idx]
    while set_idx > 0
      set_idx = nodes[set_idx]
    end
    #Negate the set index to get the actual index.
    set_idx = -set_idx;
    #Add the entry to the list pointed to by the set index.
    setsArray[set_idx] = _cons(e, setsArray[set_idx])
  end
  assignedSets = Sets(nodes, sets.elements, sets.nodeCount);
  #@debug "Sets after extractSets $(string(assignedSets))"
  #@debug "Sets array: $(toString(setsArray))"
  #= !Remove potentially empty sets! =#
  filter!((s)-> !(s isa Nil), setsArray)
  return (setsArray, assignedSets)
end

function toString(setsArr::Vector{Int64})
  str = "["
  for e in setsArr
    str *=  "Element:" * String(e) * ","
  end
  str *= "]"
  return str
end

function toString(setsArr::Vector{Any})
  str = "["
  for e in setsArr
    str *=  "Element:" * String(e) * ","
  end
  str *= "]"
  return str
end

"""
  Add a list of entries to the disjoint-sets forrest
"""
function addList(entries::List{T}, sets) where {T}
  #@debug "Calling addList $(string(sets))"
  #= Make a new set
  see below in the original impl:
  Sets.DISJOINT_SETS(nodes, elements, node_count) = sets;=#
  for e in entries
    (sets, idx) = add(e, sets)
  end
  #@debug "Sets after addList $(string(sets))"
  return sets
end

"""
  Replication of the add function in DisjointSets
  Adds an entry to the disjoint-sets forest. This function assumes that the
   entry does not already exist in the forest. If the entry might exist already,
   use find instead.
"""
function add(entry, sets::Sets)::Tuple
  #@debug "Sets before add $(string(sets))"
  local nodes::Vector{Int}
  local elements::Dict
  local node_count::Int
  @match Sets(nodes, elements, node_count) = sets
  local index = node_count + 1
  # Make sure that we have enough space in the node array. New nodes have the
  # value -1, so we don't actually need to add a node to the array, just expand
  # it and fill the new places with -1.
  if index > length(nodes)
#    nodes = Array.expand(realInt(intReal(index) * 1.4), nodes, -1);
    push!(nodes, -1) #Letting it expand automatically by via Julia...
  end
  # Register the node index in the index table.
  elements[entry] = index #BaseHashTable.addNoUpdCheck((entry, index), elements);
  setsR = Sets(nodes, elements, index)
  return (setsR, index)
end

"""
  Returns the length of the set datastructure
"""
function length(s::Sets)
  return length(s.elements)
end

@exportAll()
end #=NFConnectiosSets=#
