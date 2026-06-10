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

#=  TODO: We should have an Any type =#
#= The binary tree data structure. =#
abstract type Tree end

mutable struct NODE <: Tree
  key::Key #= The key of the node. =#
  value::Value
  height::Int #= Height of tree, used for balancing =#
  left::Tree #= Left subtree. =#
  right::Tree #= Right subtree. =#
end

mutable struct LEAF <: Tree
  key::Key #= The key of the node. =#
  value::Value
end

struct EMPTY <: Tree
end

#=
valueStr
Need to be implemented by the client
=#
keyCompare::Function = (inKey1::Key, inKey2::Key) -> begin
  res = inKey1 == inKey2
  return res
end

"""  Return an empty tree """
function new()::Tree
  local outTree::Tree = EMPTY()
  return outTree
end

"""  Gets a value from the tree given a key. """
function hasKey(inTree::Tree, inKey::Key)
  #= Iterative AVL membership check. Avoids the tuple `(key_comp, inTree)`
     allocation per recursion of the old `@match` lowering. =#
  local cur = inTree
  while true
    if cur isa NODE
      local c = keyCompare(inKey, cur.key)
      if c == 0
        return true
      elseif c > 0
        cur = cur.right
      else
        cur = cur.left
      end
    elseif cur isa LEAF
      return keyCompare(inKey, cur.key) == 0
    else
      return false
    end
  end
end

function isEmpty(tree::Tree)::Bool
  local isEmpty::Bool
   isEmpty = begin
    @match tree begin
      EMPTY(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isEmpty
end

"""  Converts the tree to a flat list of keys (in order). """
function listKeys(inTree::Tree, lst::List{<:Key} = nil)

   lst = begin
    @match inTree begin
      LEAF(__) => begin
        Cons{Key}(inTree.key, lst)
      end

      NODE(__) => begin
        lst = listKeys(inTree.right, lst)
        lst = Cons{Key}(inTree.key, lst)
        lst = listKeys(inTree.left, lst)
        lst
      end

      _ => begin
        lst
      end
    end
  end
  return lst
end

"""Converts the tree to a flat list of keys (in order)."""
function listKeysReverse(inTree::Tree, lst::List{<:Key} = nil)

   lst = begin
    @match inTree begin
      LEAF(__) => begin
        Cons{Key}(inTree.key, lst)
      end

      NODE(__) => begin
        lst = listKeysReverse(inTree.left, lst)
        lst = Cons{Key}(inTree.key, lst)
        lst = listKeysReverse(inTree.right, lst)
        lst
      end

      _ => begin
        lst
      end
    end
  end
  return lst
end


"""
  Prints the tree to a string using UTF-8 box-drawing characters to construct a
  graphical view of the tree.
"""
function printTreeStr(inTree::Tree)
  local outString::String
  local left::Tree
  local right::Tree
  outString = begin
    @match inTree begin
      EMPTY(__) => begin
        "EMPTY()"
      end
      LEAF(__) => begin
        printNodeStr(inTree)
      end
      NODE(left = left, right = right) => begin
        printTreeStr2(left, true, "") +
        printNodeStr(inTree) +
        "
        " +
        printTreeStr2(right, false, "")
      end
    end
  end
  return outString
end

function referenceEqOrEmpty(t1::Tree, t2::Tree)
  if t1 isa EMPTY && t2 isa EMPTY
    return true
  end
  return referenceEq(t1, t2)
end

"""Balances a Tree"""
function balance(inTree::Tree)
  local outTree::Tree = inTree
  outTree = begin
    local lh::Int
    local rh::Int
    local diff::Int
    local child::Tree
    local balanced_tree::Tree
    @match outTree begin
      LEAF(__) => begin
        inTree
      end
      NODE(__) => begin
        lh = height(outTree.left)
        rh = height(outTree.right)
        diff = lh - rh
        if diff < (-1)
          balanced_tree = if calculateBalance(outTree.right) > 0
            rotateLeft(setTreeLeftRight(
              outTree,
              outTree.left,
              rotateRight(outTree.right),
            ))
          else
            rotateLeft(outTree)
          end
        elseif diff > 1
          balanced_tree = if calculateBalance(outTree.left) < 0
            rotateRight(setTreeLeftRight(
              outTree,
              rotateLeft(outTree.left),
              outTree.right,
            ))
          else
            rotateRight(outTree)
          end
        elseif outTree.height != max(lh, rh) + 1
           outTree.height = max(lh, rh) + 1
          balanced_tree = outTree
        else
          balanced_tree = outTree
        end
        balanced_tree
      end
    end
  end
  return outTree
end


function height(inNode::Tree)::Int
  local outHeight::Int
   outHeight = begin
    @match inNode begin
      NODE(__) => begin
        inNode.height
      end
      LEAF(__) => begin
        1
      end
      _ => begin
        0
      end
    end
  end
  return outHeight
end

function calculateBalance(inNode::Tree)::Int
  local outBalance::Int

  outBalance = begin
    @match inNode begin
      NODE(__) => begin
        height(inNode.left) - height(inNode.right)
      end

      LEAF(__) => begin
        0
      end

      _ => begin
        0
      end
    end
  end
  return outBalance
end

"""Performs an AVL left rotation on the given tree."""
function rotateLeft(inNode::Tree)
  local outNode::Tree = inNode

   outNode = begin
    local node::Tree
    local child::Tree
    @match outNode begin
      NODE(right = child && NODE(__)) => begin
        node = setTreeLeftRight(outNode, outNode.left, child.left)
        setTreeLeftRight(child, node, child.right)
      end

      NODE(right = child && LEAF(__)) => begin
        node = setTreeLeftRight(outNode, outNode.left, EMPTY())
        setTreeLeftRight(child, node, EMPTY())
      end

      _ => begin
        inNode
      end
    end
  end
  return outNode
end

"""Performs an AVL right rotation on the given tree."""
function rotateRight(inNode::Tree)::Tree
  local outNode::Tree = inNode
   outNode = begin
    local node::Tree
    local child::Tree
    @match outNode begin
      NODE(left = child && NODE(__)) => begin
        node = setTreeLeftRight(outNode, child.right, outNode.right)
        setTreeLeftRight(child, child.left, node)
      end

      NODE(left = child && LEAF(__)) => begin
        node = setTreeLeftRight(outNode, EMPTY(), outNode.right)
        setTreeLeftRight(child, EMPTY(), node)
      end
      _ => begin
        inNode
      end
    end
  end
  return outNode
end

"""Helper function to printTreeStr."""
function printTreeStr2(inTree::Tree, isLeft::Bool, inIndent::String)
  local outString::String
  local val_node::Option{ValueNode}
  local left::Option{Tree}
  local right::Option{Tree}
  local left_str::String
  local right_str::String
  outString = begin
    @match inTree begin
      NODE(__) => begin
        printTreeStr2(inTree.left, true, inIndent * (
          if isLeft
            "     "
          else
            " │   "
          end
        )) *
        inIndent *
        (
          if isLeft
            " ┌"
          else
            " └"
          end
        ) *
        "────" *
        printNodeStr(inTree) *
        "
        " *
        printTreeStr2(inTree.right, false, inIndent * (
          if isLeft
            " │   "
          else
            "     "
          end
        ))
      end

      _ => begin
        ""
      end
    end
  end
  return outString
end


"""="""
function printNodeStr(inNode::Tree)
  outString = begin
    @match inNode begin
      NODE(__) => begin
        "(" * keyStr(inNode.key) * ", " * valueStr(inNode.value) * ")"
      end

      LEAF(__) => begin
        "(" * keyStr(inNode.key) * ", " * valueStr(inNode.value) * ")"
      end
    end
  end
  return outString
end


#= Default conflict resolving function for add. =#
"""Conflict resolving function for add which fails on conflict."""
function addConflictFail(newValue::Value, oldValue::Value, key::Key)
  fail()
end
addConflictDefault = addConflictFail

"""Conflict resolving function for add which replaces the old value with the new."""
function addConflictReplace(newValue::Value, oldValue::Value, key::Key)
  local value::Value = newValue
  return value
end

"""Conflict resolving function for add which keeps the old value."""
function addConflictKeep(newValue::Value, oldValue::Value, key::Key)
  local value::Value = oldValue
  return value
end

"""Inserts a new node in the tree."""
function add(
  inTree::Tree,
  inKey::Key,
  inValue::Value,
  conflictFunc::Function = addConflictDefault,
)::Tree #= Used to resolve conflicts. =#
  local tree::Tree = inTree

   tree = begin
    local key::Key
    local value::Value
    local key_comp::Int
    local outTree::Tree
    #=  Empty tree.
    =#
    @match tree begin
      EMPTY(__) => begin
        LEAF(inKey, inValue)
      end

      NODE(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
           tree.left = add(tree.left, inKey, inValue, conflictFunc)
        elseif key_comp == 1
           tree.right = add(tree.right, inKey, inValue, conflictFunc)
        else
           value = conflictFunc(inValue, tree.value, key)
          if !referenceEq(tree.value, value)
             tree.value = value
          end
        end
        #=  Replace left branch.
        =#
        #=  Replace right branch.
        =#
        #=  Use the given function to resolve the conflict.
        =#
        if key_comp == 0
          tree
        else
          balance(tree)
        end
      end
      LEAF(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
           outTree = NODE(tree.key, tree.value, 2, LEAF(inKey, inValue), EMPTY())
        elseif key_comp == 1
           outTree = NODE(tree.key, tree.value, 2, EMPTY(), LEAF(inKey, inValue))
        else
           value = conflictFunc(inValue, tree.value, key)
          if !referenceEq(tree.value, value)
             tree.value = value
          end
           outTree = tree
        end
        if key_comp == 0
          outTree
        else
          balance(outTree)
        end
      end
    end
  end
  return tree
end

"""  Adds a list of key-value pairs to the tree. """
function addList(
  tree::Tree,
  inValues::List{<:Tuple{<:Key, Value}},
  conflictFunc::Function = addConflictDefault,
)::Tree #= Used to resolve conflicts. =#

  local key::Key
  local value::Value

  for t in inValues
     (key, value) = t
     tree = add(tree, key, value, conflictFunc)
  end
  return tree
end

""" Alias for add that replaces the node in case of conflict. """
function update(tree::Tree, key::Key, value::Value)::Tree
  local outTree::Tree = add(tree, key, value, addConflictReplace)
  return outTree
end

"""
  Fetches a value from the tree given a key, or fails if no value is associated
  with the key.
"""
function get(tree::Tree, key::Key)
  local value::Value
  local k::Key
  k = tree.key
  local kc = keyCompare(key, k)
  if kc == 0
    return tree.value
  end
  value = begin
    if kc == 0
      tree.value
    elseif kc == 1 && tree isa NODE
      get(tree.right, key)
    elseif kc == -1 && tree isa NODE
      get(tree.left, key)
    else
      fail()
    end
  end
  return value
end

"""
Get on an empty tree results in failure...
"""
@noinline function get(tree::EMPTY, key::Key)
  fail()
end

"""
Like `getOpt` but returns the value directly on a hit and `nothing` on a
miss. Saves the `SOME(value)` wrapper allocation that `getOpt` pays on
every successful lookup; Julia represents `Union{Value, Nothing}` as a
tagged pointer with no heap struct.
"""
function tryGet(tree::Tree, key::Key)
  local cur = tree
  while true
    if cur isa NODE
      local c = keyCompare(key, cur.key)
      if c == 0
        return cur.value
      elseif c > 0
        cur = cur.right
      else
        cur = cur.left
      end
    elseif cur isa LEAF
      return keyCompare(key, cur.key) == 0 ? cur.value : nothing
    else
      return nothing
    end
  end
end

"""
  Fetches a value from the tree given a key, or returns NONE if no value is
  associated with the key.
"""
function getOpt(tree::Tree, key::Key)
  #= Iterative AVL lookup. The previous implementation tupled
     `(keyCompare(...), tree)` for `@match`, which the macro lowered to a
     small allocation per node visited; on AVL chains thousands deep during
     instantiation that totalled megabytes. =#
  local cur = tree
  while true
    if cur isa NODE
      local c = keyCompare(key, cur.key)
      if c == 0
        return SOME(cur.value)
      elseif c > 0
        cur = cur.right
      else
        cur = cur.left
      end
    elseif cur isa LEAF
      return keyCompare(key, cur.key) == 0 ? SOME(cur.value) : NONE()
    else
      return NONE()
    end
  end
end

"""Creates a new tree from a list of key-value pairs."""
function fromList(
  inValues::List{<:Tuple{<:Key, Value}},
  conflictFunc::Function = addConflictDefault,
)::Tree #= Used to resolve conflicts. =#
  local tree::Tree = EMPTY()

  local key::Key
  local value::Value

  for t in inValues
     (key, value) = t
     tree = add(tree, key, value, conflictFunc)
  end
  return tree
end


function fromVector(
  inValues::Vector{Tuple{Key, Value}},
  conflictFunc::Function = addConflictDefault,
  )::Tree #= Used to resolve conflicts. =#
  local tree::Tree = EMPTY()
  local key::Key
  local value::Value
  for t in inValues
     (key, value) = t
     tree = add(tree, key, value, conflictFunc)
  end
  return tree
end

function fromVector(
  inValues::Vector{Value},
  inKeys::Vector{Key},
  conflictFunc::Function = addConflictDefault,
  )::Tree #= Used to resolve conflicts. =#
  local tree::Tree = EMPTY()
  local key::Key
  local value::Value
  for (key, val) in zip(inKeys, inValues)
     tree = add(tree, key, val, conflictFunc)
  end
  return tree
end



"""Converts the tree to a flat list of key-value tuples."""
function toList(
  inTree::Tree,
  lst::List{<:Tuple{<:Key, Value}} = nil,
  )#::List{Tuple{Key, Value}}
  lst = begin
    local key::Key
    local value::Value
    @match inTree begin
      NODE(key = key, value = value) => begin
         lst = toList(inTree.right, lst)
         lst = Cons{Tuple{Key, Value}}((key, value), lst)
         lst = toList(inTree.left, lst)
        lst
      end
      LEAF(key = key, value = value) => begin
        Cons{Tuple{Key, Value}}((key, value), lst)
      end
      _ => begin
        lst
      end
    end
  end
  return lst
end

"""
  Creates a vector from a tree. Not tested yet
"""
function toVector!(
  inTree::Tree,
  vec::Vector{Tuple{Key, Value}} = Tuple{Key, Value}[],
  )#::List{Tuple{Key, Value}}
  vec = begin
    local key::Key
    local value::Value
    @match inTree begin
      NODE(key = key, value = value) => begin
        toVector(inTree.right, vec)
        vec = push!(vec, (key, value))
        toVector(inTree.left, vec)
        vec
      end
      LEAF(key = key, value = value) => begin
        push!((vec, (key, value)))
      end
      _ => begin
        vec
      end
    end
  end
  return vec
end

""" Constructs a list of all the values in the tree. """
function listValues(tree::Tree, lst::List{T} = nil) where {T <: Value}
   lst = begin
    local value::Value
    @match tree begin
      NODE(value = value) => begin
        lst = listValues(tree.right, lst)
        lst = Cons{Value}(value, lst)
        lst = listValues(tree.left, lst)
        lst
      end
      LEAF(value = value) => begin
        Cons{Value}(value, lst)
      end
      _ => begin
        lst
      end
    end
  end
  return lst
end

"""
  Same as listValues but creates a vector from a tree instead.
  This function modifies the vector inplace, it then returns the result.
"""
function vectorValues!(tree::Tree, vec::Vector{T} = Value[]) where {T <: Value}
  vec = @match tree begin
    NODE(value = value) => begin
      vectorValues!(tree.right, vec)
      push!(vec, value)
      vectorValues!(tree.left, vec)
      vec
    end
    LEAF(value = value) => begin
      push!(vec, value)
    end
    _ => begin
      vec
    end
  end
  return reverse!(vec)
end


"""Joins two trees by adding the second one to the first."""
function join(
  tree::Tree,
  treeToJoin::Tree,
  conflictFunc::Function = addConflictDefault,
  )
   tree = begin
    @match treeToJoin begin
      EMPTY(__) => begin
        tree
      end
      NODE(__) => begin
         tree = add(tree, treeToJoin.key, treeToJoin.value, conflictFunc)
         tree = join(tree, treeToJoin.left, conflictFunc)
         tree = join(tree, treeToJoin.right, conflictFunc)
        tree
      end

      LEAF(__) => begin
        add(tree, treeToJoin.key, treeToJoin.value, conflictFunc)
      end
    end
  end
  return tree
end

"""
  Traverses the tree in depth-first pre-order and applies the given function to
  each node, but without constructing a new tree like with map.
"""
function forEach(tree::Tree, func::Function)
  return  _ = begin
    @match tree begin
      NODE(__) => begin
        forEach(tree.left, func)
        func(tree.key, tree.value)
        forEach(tree.right, func)
        ()
      end

      LEAF(__) => begin
        func(tree.key, tree.value)
        ()
      end

      EMPTY(__) => begin
        ()
      end
    end
  end
end

function intersection()
  return fail()
end

"""
  Traverses the tree in depth-first pre-order and applies the given function to
  each node, constructing a new tree with the resulting nodes.
"""
function map(inTree::Tree, inFunc::Function)::Tree
  local outTree::Tree = inTree
  outTree = begin
    local key::Key
    local value::Value
    local new_value::Value
    local branch::Tree
    local new_branch::Tree
    @match outTree begin
      NODE(key = key, value = value) => begin
         new_branch = map(outTree.left, inFunc)
        if !referenceEq(new_branch, outTree.left)
           outTree.left = new_branch
        end
         new_value = inFunc(key, value)
        if !referenceEq(value, new_value)
           outTree.value = new_value
        end
         new_branch = map(outTree.right, inFunc)
        if !referenceEq(new_branch, outTree.right)
           outTree.right = new_branch
        end
        outTree
      end
      LEAF(key = key, value = value) => begin
         new_value = inFunc(key, value)
        if !referenceEq(value, new_value)
          outTree.value = new_value
        end
        outTree
      end
      _ => begin
        inTree
      end
    end
  end
  return outTree
end

"""
  Traverses the tree in depth-first pre-order and applies the given function to
  each node, in the process updating the given argument.
"""
function fold(inTree::Tree, inFunc::Function, inStartValue::FT) where {FT}
  local outResult = inStartValue
  outResult = begin
    local key::Key
    local value::Value
    @match inTree begin
      NODE(key = key, value = value) => begin
        outResult = fold(inTree.left, inFunc, outResult)
        outResult = inFunc(key, value, outResult)
        outResult = fold(inTree.right, inFunc, outResult)
        outResult
      end
      LEAF(key = key, value = value) => begin
        outResult = inFunc(key, value, outResult)
        outResult
      end
      _ => begin
        outResult
      end
    end
  end
  return outResult
end

"""Like fold, but takes two fold arguments."""
function fold_2(
  tree::Tree,
  foldFunc::Function,
  foldArg1::FT1,
  foldArg2::FT2,
) where {FT1, FT2}

   () = begin
    @match tree begin
      NODE(__) => begin
         (foldArg1, foldArg2) = fold_2(tree.left, foldFunc, foldArg1, foldArg2)
         (foldArg1, foldArg2) = foldFunc(tree.key, tree.value, foldArg1, foldArg2)
         (foldArg1, foldArg2) = fold_2(tree.right, foldFunc, foldArg1, foldArg2)
        ()
      end

      LEAF(__) => begin
         (foldArg1, foldArg2) = foldFunc(tree.key, tree.value, foldArg1, foldArg2)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return (foldArg1, foldArg2)
end

"""
  Like fold, but if the fold function returns false it will not continue down
  into the tree (but will still continue with other branches).
"""
function foldCond(tree::Tree, foldFunc::Function, value::FT) where {FT}

   value = begin
    local c::Bool
    @match tree begin
      NODE(__) => begin
         (value, c) = foldFunc(tree.key, tree.value, value)
        if c
           value = foldCond(tree.left, foldFunc, value)
           value = foldCond(tree.right, foldFunc, value)
        end
        value
      end

      LEAF(__) => begin
         (value, c) = foldFunc(tree.key, tree.value, value)
        value
      end

      _ => begin
        value
      end
    end
  end
  return value
end

"""
  Traverses the tree in depth-first pre-order and applies the given function to
  each node, constructing a new tree with the resulting nodes. mapFold also
  takes an extra argument which is updated on each call to the given function.
"""
function mapFold(inTree::Tree, inFunc::Function, inStartValue::FT) where {FT}
  local outResult::FT = inStartValue
  local outTree::Tree = inTree

   outTree = begin
    local key::Key
    local value::Value
    local new_value::Value
    local branch::Tree
    local new_branch::Tree
    @match outTree begin
      NODE(key = key, value = value) => begin
         (new_branch, outResult) = mapFold(outTree.left, inFunc, outResult)
        if !referenceEq(new_branch, outTree.left)
           outTree.left = new_branch
        end
         (new_value, outResult) = inFunc(key, value, outResult)
        if !referenceEq(value, new_value)
           outTree.value = new_value
        end
         (new_branch, outResult) = mapFold(outTree.right, inFunc, outResult)
        if !referenceEq(new_branch, outTree.right)
           outTree.right = new_branch
        end
        outTree
      end

      LEAF(key = key, value = value) => begin
         (new_value, outResult) = inFunc(key, value, outResult)
        if !referenceEq(value, new_value)
           outTree.value = new_value
        end
        outTree
      end

      _ => begin
        inTree
      end
    end
  end
  return (outTree, outResult)
end

function setTreeLeftRight(orig::Tree, left::Tree = EMPTY(), right::Tree = EMPTY())
  #= If both children are EMPTY, the result is a LEAF (or the orig LEAF). =#
  if left isa EMPTY && right isa EMPTY
    return orig isa NODE ? LEAF(orig.key, orig.value) : orig
  end
  if orig isa NODE && referenceEqOrEmpty(orig.left, left) && referenceEqOrEmpty(orig.right, right)
    return orig
  end
  return NODE(orig.key, orig.value, max(height(left), height(right)) + 1, left, right)
end
