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

module BasePVector  #=TODO: Originally partial =#

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl Vector
@UniontypeDecl Node

MapFunc = Function

FoldFunc = Function

MapFunc = Function

MapFunc = Function

FoldFunc = Function

FoldFunc = Function

T = Integer
#=  Should be Any.
=#
import ListUtil

import Frontend.MetaModelica.Dangerous

@Uniontype Vector begin
  @Record VECTOR begin

    root::Node #= The tree containing the elements. =#
    tail::Array{Node} #= The last added elements. =#
    size::Int #= The number of elements in the Vector. =#
    shift::Int #= Height of the tree * 5. =#
  end
end

@Uniontype Node begin
  @Record NODE begin

    children::Array{Node}
  end

  @Record VALUE begin

    value::T
  end

  @Record EMPTY begin

  end
end

#=  Some constants used internally by the Vector. Since modifications are
=#
#=  non-destructive we can have an empty Vector as a constant instead of
=#
#=  creating a new Vector each time we need an empty one.
=#
const EMPTY_NODE = NODE(arrayCreate(32, EMPTY()))::Node
const EMPTY_VEC = VECTOR(EMPTY_NODE, arrayCreate(0, EMPTY()), 0, 5)::Vector

"""Returns a new empty Vector."""
function new()::Vector
  local outVector::Vector = EMPTY_VEC
  return outVector
end

"""Appends a value to the end of the Vector."""
function add(inVector::Vector, inValue::T)::Vector
  local outVector::Vector = inVector

  @assign outVector = begin
    local tail::Array{Node}
    local nodes::Array{Node}
    local root::Node
    local tail_node::Node
    local sz::Int
    local shift::Int
    #=  Space left in the tail, insert the value in the tail.
    =#
    @match outVector begin
      VECTOR(tail = tail) where {(arrayLength(tail) < 32)} => begin
        @assign outVector.tail = tailAdd(tail, VALUE(inValue))
        @assign outVector.size = outVector.size + 1
        outVector
      end

      VECTOR(root, tail, sz, shift) => begin
        #=  No space left in the tail. Push the tail into the tree and create a new
        =#
        #=  tail to add the value to.
        =#
        @assign (root, shift) = pushTail(root, tail, sz, shift)
        @assign tail = arrayCreate(1, VALUE(inValue))
        VECTOR(root, tail, sz + 1, shift)
      end
    end
  end
  return outVector
end

"""
  Appends a list of values to the end of the Vector. This function is more
  efficient than calling add multiple times, since it doesn't need to create a
  new Vector for each added element.
"""
function addList(inVector::Vector, inList::List{<:T})::Vector
  local outVector::Vector = inVector

  local tail::Array{Node}
  local root::Node
  local sz::Int
  local shift::Int
  local tail_len::Int
  local list_len::Int
  local rest_len::Int
  local rest::List{T} = inList
  local node_lst::List{Node}
  local e::T

  @match VECTOR(root, tail, sz, shift) = inVector
  @assign tail_len = arrayLength(tail)
  @assign list_len = listLength(inList)
  #=  Check if we have enough space left in the tail for the whole list.
  =#
  if tail_len + list_len <= 32
    @assign node_lst = list(VALUE(v) for v in inList)
    @assign tail = arrayAppend(tail, listArray(node_lst))
    @assign sz = sz + list_len
  else
    if tail_len < 32
      @assign node_lst = nil
      for i = (tail_len + 1):32
        @match _cons(e, rest) = rest
        @assign node_lst = _cons(VALUE(e), node_lst)
      end
      @assign tail = arrayAppend(tail, ListUtil.listArrayReverse(node_lst))
    end
    @assign sz = sz + 32 - tail_len
    @assign rest_len = list_len - (32 - tail_len)
    @assign (root, shift) = pushTail(root, tail, sz, shift)
    while rest_len > 32
      @assign tail = MetaModelica.Dangerous.arrayCreateNoInit(32, EMPTY())
      for i = 1:32
        @match _cons(e, rest) = rest
        @assign tail[i] = VALUE(e)
      end
      @assign sz = sz + 32
      @assign (root, shift) = pushTail(root, tail, sz, shift)
      @assign rest_len = rest_len - 32
    end
    @assign node_lst = list(VALUE(v) for v in rest)
    @assign tail = listArray(node_lst)
    @assign sz = sz + arrayLength(tail)
  end
  #=  Space left in the tail, just append the list to the it.
  =#
  #=  More elements than can fit in the tail.
  =#
  #=  If the tail isn't already full, fill it up.
  =#
  #=  Keep track of the size so we know where to push new nodes.
  =#
  #=  Push the now full tail into the tree.
  =#
  #=  While we have more than 32 elements left to add, take 32 of them at a
  =#
  #=  time and push them down into the tree.
  =#
  #=  Make a new tail of the remaining elements.
  =#
  @assign outVector = VECTOR(root, tail, sz, shift)
  return outVector
end

"""Returns the element at the given index. Fails if the index is out of bounds."""
function get(inVector::Vector, inIndex::Int)::T
  local outValue::T

  local tail_off::Int = tailOffset(length(inVector))
  local nodes::Array{Node}

  if inIndex <= tail_off
    @match NODE(children = nodes) = nodeParent(inVector, inIndex)
    @match VALUE(outValue) = nodes[intBitAnd(inIndex - 1, 31) + 1]
  else
    @match VECTOR(tail = nodes) = inVector
    @match VALUE(outValue) = nodes[inIndex - tail_off]
  end
  #=  Look the element up in the tree.
  =#
  #=  Look the element up in the tail.
  =#
  return outValue
end

"""
  Sets the element at the given index to the given value. Fails if the index is
  out of bounds.
"""
function set(inVector::Vector, inIndex::Int, inValue::T)::Vector
  local outVector::Vector = inVector

  @assign outVector = begin
    local tail_off::Int
    @match outVector begin
      VECTOR(__) => begin
        @match true = inIndex > 0 && inIndex <= outVector.size
        @assign tail_off = tailOffset(outVector.size)
        if inIndex <= tail_off
          @assign outVector.root =
            nodeSet(outVector.root, inIndex, VALUE(inValue), outVector.shift)
        else
          @assign outVector.tail = arrayCopy(outVector.tail)
          arrayUpdate(outVector.tail, inIndex - tail_off, VALUE(inValue))
        end
        #=  The element is in the tree.
        =#
        #=  The element is in the tail.
        =#
        outVector
      end
    end
  end
  return outVector
end

"""Returns the last value in the Vector. Fails if the Vector is empty."""
function last(inVector::Vector)::T
  local outValue::T

  local tail::Array{Node}

  @match VECTOR(tail = tail) = inVector
  @match VALUE(outValue) = tail[arrayLength(tail)]
  return outValue
end

"""Removes the last value in the Vector. Fails if the Vector is empty."""
function pop(inVector::Vector)::Vector
  local outVector::Vector = inVector

  @assign outVector = begin
    local tail::Array{Node}
    local nodes::Array{Node}
    local root::Node
    local sz::Int
    local shift::Int
    #=  Fail if the Vector is empty.
    =#
    @match outVector begin
      VECTOR(size = 0) => begin
        fail()
      end

      VECTOR(size = 1) => begin
        EMPTY_VEC
      end

      VECTOR(tail = tail) where {(arrayLength(tail) > 1)} => begin
        #=  Vector with one element => empty Vector.
        =#
        #=  Tail contains more than one element, remove the last of them.
        =#
        @assign outVector.tail = tailPop(tail)
        @assign outVector.size = outVector.size - 1
        outVector
      end

      VECTOR(root, tail, sz, shift) => begin
        #=  Tail contains one element. Remove the last added tail from the tree, and
        =#
        #=  use it as the new tail.
        =#
        @match NODE(children = tail) = nodeParent(inVector, sz - 2)
        @assign root = popTail(root, shift, sz)
        if isEmptyNode(root)
          @assign root = EMPTY_NODE
        end
        #=  The node removed from the tree was the last,
        =#
        #=  replace the tree with an empty tree.
        =#
        @match NODE(children = nodes) = root
        if shift > 5 && isEmptyNode(nodes[2])
          @assign root = nodes[1]
          @assign shift = shift - 5
        end
        #=  If the root node only has one child, replace the root with it to
        =#
        #=  reduce the height of the tree.
        =#
        VECTOR(root, tail, sz - 1, shift)
      end
    end
  end
  return outVector
end

"""
  Returns a new Vector where the given function has been applied to each
  element in sequential order.
"""
function map(inVector::Vector, inFunc::MapFunc)::Vector
  local outVector::Vector = inVector

  @assign outVector = begin
    @match outVector begin
      VECTOR(__) => begin
        @assign outVector.root = mapNode(outVector.root, inFunc)
        @assign outVector.tail = mapNodeArray(outVector.tail, inFunc)
        outVector
      end
    end
  end
  return outVector
end

"""
  Applies the given function to each element in the Vector, updating the given
  argument as it goes along.
"""
function fold(inVector::Vector, inFunc::FoldFunc, inStartValue::FT) where {FT}
  local outResult::FT

  local root::Node
  local tail::Array{Node}

  @match VECTOR(root = root, tail = tail) = inVector
  @assign outResult = foldNode(root, inFunc, inStartValue)
  @assign outResult = foldNodeArray(tail, inFunc, outResult)
  return outResult
end

"""Returns the number of elements in the Vector."""
function size(inVector::Vector)::Int
  local outSize::Int

  @match VECTOR(size = outSize) = inVector
  return outSize
end

#=  Alias for size, since size can't be used inside this package (the compiler
=#
#=  mistakes it for the builtin size).
=#
@ExtendedFunction length size()

"""Returns true if the Vector is empty, otherwise false."""
function isEmpty(inVector::Vector)::Bool
  local outIsEmpty::Bool

  local sz::Int

  @match VECTOR(size = sz) = inVector
  @assign outIsEmpty = sz == 0
  return outIsEmpty
end

"""Creates a Vector from a list."""
function fromList(inList::List{<:T})::Vector
  local outVector::Vector = addList(EMPTY_VEC, inList)
  return outVector
end

"""Creates a list from a Vector."""
function toList(inVector::Vector)::List{T}
  local outList::List{T} = listReverse(toReversedList(inVector))
  return outList
end

function toReversedList(inVector::Vector)::List{T}
  local outList::List{T} = fold(inVector, cons, nil)
  return outList
end

"""Creates a Vector from an array."""
function fromArray(inArray::Array{<:T})::Vector
  local outVector::Vector = addList(EMPTY_VEC, arrayList(inArray))
  return outVector
end

"""Creates an array from a Vector."""
function toArray(inVector::Vector)::Array{T}
  local outArray::Array{T} = listArray(toList(inVector))
  return outArray
end

function printDebug(inVector::Vector)
  local root::Node
  local tail::Array{Node}
  local sz::Int
  local shift::Int

  @match VECTOR(root, tail, sz, shift) = inVector
  print("PVector(size = " + intString(sz) + ", shift = " + intString(shift) + "):\\n")
  print("  tail: [")
  for e in tail
    printDebugNode(e, "")
  end
  print("]")
  printDebugNode(root, "  ")
  return print("\\n")
end

function printDebugNode(inNode::Node, inIndent::String)
  return @assign _ = begin
    @match inNode begin
      NODE(__) => begin
        print("\\n" + inIndent + "[")
        for i = 1:arrayLength(inNode.children)
          printDebugNode(arrayGet(inNode.children, i), inIndent + "  ")
        end
        print("],")
        ()
      end

      VALUE(__) => begin
        print(anyString(inNode.value) + ", ")
        ()
      end

      EMPTY(__) => begin
        print("E, ")
        ()
      end
    end
  end
end

"""Helper function to set."""
function nodeSet(inNode::Node, inIndex::Int, inValue::Node, inLevel::Int)::Node
  local outNode::Node

  local children::Array{Node}
  local idx::Int

  @match NODE(children = children) = inNode
  @assign children = arrayCopy(children)
  if inLevel == 0
    arrayUpdate(children, intBitAnd(inIndex - 1, 31) + 1, inValue)
  else
    @assign idx = intBitAnd(intBitRShift(inIndex - 1, inLevel), 31) + 1
    arrayUpdate(children, idx, nodeSet(children[idx], inIndex, inValue, inLevel - 5))
  end
  #=  If we reached a leaf, replace its value with the new value.
  =#
  #=  Otherwise, continue to traverse the tree until we find the correct leaf.
  =#
  @assign outNode = NODE(children)
  return outNode
end

"""Helper function to add. Adds a node to the end of the tail."""
function tailAdd(inTail::Array{<:Node}, inNode::Node)::Array{Node}
  local outTail::Array{Node}

  local new_len::Int = arrayLength(inTail) + 1

  @assign outTail = MetaModelica.Dangerous.arrayCreateNoInit(new_len, EMPTY())
  for i = 1:(new_len - 1)
    arrayUpdate(outTail, i, inTail[i])
  end
  @assign outTail[new_len] = inNode
  return outTail
end

"""Helper function to add. Pushed a tail into the tree as a new node."""
function pushTail(
  inRoot::Node,
  inTail::Array{<:Node},
  inSize::Int,
  inShift::Int,
)::Tuple{Node, Integer}
  local outShift::Int
  local outRoot::Node

  local tail_node::Node = NODE(inTail)
  local nodes::Array{Node}

  #=  Do we have any space left in the tree?
  =#
  if intBitRShift(inSize, 5) > intBitLShift(1, inShift)
    @assign nodes = arrayCreate(32, EMPTY())
    arrayUpdate(nodes, 1, inRoot)
    arrayUpdate(nodes, 2, newPath(tail_node, inShift))
    @assign outRoot = NODE(nodes)
    @assign outShift = inShift + 5
  else
    @assign outRoot = pushTail2(inRoot, inShift, inSize, tail_node)
    @assign outShift = inShift
  end
  #=  No space left, add another level to the tree by creating a new root node
  =#
  #=  with the old root and the pushed tail node as the first and second child.
  =#
  #=  Space left in the tree, just push the tail node down to the correct place.
  =#
  return (outRoot, outShift)
end

"""Helper function to pushTail. Does the actual pushing."""
function pushTail2(inNode::Node, inLevel::Int, inSize::Int, inTail::Node)::Node
  local outNode::Node

  @assign outNode = begin
    local idx::Int
    local children::Array{Node}
    local node::Node
    #=  A node, push the tail into it.
    =#
    @match inNode begin
      NODE(__) => begin
        @assign children = arrayCopy(inNode.children)
        @assign idx = intBitAnd(intBitRShift(inSize - 1, inLevel), 31) + 1
        @assign node = if inLevel == 5
          inTail
        else
          pushTail2(children[idx], inLevel - 5, inSize, inTail)
        end
        arrayUpdate(children, idx, node)
        NODE(children)
      end

      EMPTY(__) => begin
        newPath(inTail, inLevel)
      end
    end
  end
  #=  An empty leaf, make a new path for the tail node.
  =#
  return outNode
end

"""Returns a new tail array with the last element removed."""
function tailPop(inTail::Array{<:Node})::Array{Node}
  local outTail::Array{Node}

  local new_len::Int = arrayLength(inTail) - 1

  @assign outTail = MetaModelica.Dangerous.arrayCreateNoInit(new_len, EMPTY())
  for i = 1:new_len
    arrayUpdate(outTail, i, inTail[i])
  end
  return outTail
end

"""Removes the last tail added to the given node."""
function popTail(inNode::Node, inLevel::Int, inSize::Int)::Node
  local outNode::Node

  local idx::Int
  local children::Array{Node}
  local child::Node

  @assign idx = intBitAnd(intBitRShift(inSize - 2, inLevel), 31) + 1
  @assign outNode = begin
    @match inNode begin
      NODE(children = children) where {(inLevel > 5)} => begin
        #=  More than one level in the tree, update nodes recursively.
        =#
        @assign outNode = popTail(children[idx], inLevel - 5, inSize)
        if !(isEmptyNode(outNode) && idx == 1)
          @assign children = arrayCopy(children)
          arrayUpdate(children, idx, outNode)
          @assign outNode = NODE(children)
        end
        outNode
      end

      _ where {(idx == 1)} => begin
        EMPTY()
      end

      NODE(children = children) => begin
        #=  Popping the last node, return empty node.
        =#
        #=  Any other case, just replace the node with an empty node.
        =#
        @assign children = arrayCopy(children)
        arrayUpdate(children, idx, EMPTY())
        NODE(children)
      end
    end
  end
  return outNode
end

"""Returns the parent to the node with the given index."""
function nodeParent(inVector::Vector, inIndex::Int)::Node
  local outNode::Node

  local node::Node
  local children::Array{Node}
  local shift::Int

  @match VECTOR(root = outNode, shift = shift) = inVector
  for level = shift:(-5):1
    @match NODE(children = children) = outNode
    @assign outNode = children[intBitAnd(intBitRShift(inIndex - 1, level), 31) + 1]
  end
  return outNode
end

"""
  Returns the tail offset, i.e. the number of elements in the vector - the
  number of elements in the tail.
"""
function tailOffset(inSize::Int)::Int
  local outOffset::Int = if inSize < 32
    0
  else
    intBitLShift(intBitRShift(inSize - 1, 5), 5)
  end
  return outOffset
end

"""Creates a new node and sets the given node as the first child in the new node."""
function liftNode(inNode::Node)::Node
  local outNode::Node

  local nodes::Array{Node}

  @assign nodes = arrayCreate(32, EMPTY())
  arrayUpdate(nodes, 1, inNode)
  @assign outNode = NODE(nodes)
  return outNode
end

"""Creates a new path of a given length with the given node as leaf."""
function newPath(inNode::Node, inLevel::Int)::Node
  local outNode::Node

  @assign outNode = if inLevel > 0
    liftNode(newPath(inNode, inLevel - 5))
  else
    inNode
  end
  return outNode
end

"""Returns true if the given node is empty, otherwise false."""
function isEmptyNode(inNode::Node)::Bool
  local outIsEmpty::Bool

  @assign outIsEmpty = begin
    @match inNode begin
      EMPTY(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsEmpty
end

"""Helper function to map, maps over a single node."""
function mapNode(inNode::Node, inFunc::MapFunc)::Node
  local outNode::Node

  @assign outNode = begin
    @match inNode begin
      NODE(__) => begin
        NODE(mapNodeArray(inNode.children, inFunc))
      end

      VALUE(__) => begin
        VALUE(inFunc(inNode.value))
      end

      _ => begin
        inNode
      end
    end
  end
  return outNode
end

"""Helper function to map, maps over an array of nodes."""
function mapNodeArray(inNodes::Array{<:Node}, inFunc::MapFunc)::Array{Node}
  local outNodes::Array{Node}

  @assign outNodes = arrayCopy(inNodes)
  for i = 1:arrayLength(outNodes)
    MetaModelica.Dangerous.arrayUpdateNoBoundsChecking(
      outNodes,
      i,
      mapNode(MetaModelica.Dangerous.arrayGetNoBoundsChecking(outNodes, i), inFunc),
    )
  end
  return outNodes
end

"""Helper function to fold, folds over a single node."""
function foldNode(inNode::Node, inFunc::FoldFunc, inStartValue::FT) where {FT}
  local outResult::FT

  @assign outResult = begin
    @match inNode begin
      NODE(__) => begin
        foldNodeArray(inNode.children, inFunc, inStartValue)
      end

      VALUE(__) => begin
        inFunc(inNode.value, inStartValue)
      end

      _ => begin
        inStartValue
      end
    end
  end
  return outResult
end

"""Helper function to fold, folds over an array of nodes."""
function foldNodeArray(inNodes::Array{Node}, inFunc::FoldFunc, inStartValue::FT) where {FT}
  local outResult::FT = inStartValue

  for node in inNodes
    @assign outResult = foldNode(node, inFunc, outResult)
  end
  return outResult
end

@exportAll()
end
