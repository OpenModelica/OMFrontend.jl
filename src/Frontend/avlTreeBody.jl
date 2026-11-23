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

# The AVL tree functions of DuplicateTree and ModTable (omc's BaseAvlTree), one copy included by both modules.
# The including module defines before the include: `Key` (String), `Value`, and the tree type `Tree` with the
# variants `EMPTY()`, `LEAF(key, value)`, `NODE(key, value, height, left, right)`; after it: `addConflictDefault`
# and `add(tree, key, value, conflictFunc = addConflictDefault)`.

"""The order of two keys: -1, 0 or 1 (`stringCompare`)."""
keyCompare(inKey1::Key, inKey2::Key)::Int = stringCompare(inKey1, inKey2)

"""  Return an empty tree """
function new()::Tree
  local outTree::Tree = EMPTY()
  return outTree
end

"""  Gets a value from the tree given a key. """
function hasKey(inTree::Tree, inKey::Key)
  local cur = inTree
  while true
    if isvariant(cur, NODE)
      local c = keyCompare(inKey, cur.key)
      if c == 0
        return true
      elseif c > 0
        cur = cur.right
      else
        cur = cur.left
      end
    elseif isvariant(cur, LEAF)
      return keyCompare(inKey, cur.key) == 0
    else
      return false
    end
  end
end

isEmpty(tree::Tree)::Bool = isvariant(tree, EMPTY)

"""  Converts the tree to a flat list of keys (in order). """
function listKeys(inTree::Tree, lst::List{<:Key} = nil)

   lst = begin
    @match inTree begin
      LEAF(__) => Cons{Key}(inTree.key, lst)

      NODE(__) => begin
        lst = listKeys(inTree.right, lst)
        lst = Cons{Key}(inTree.key, lst)
        lst = listKeys(inTree.left, lst)
        lst
      end

      _ => lst
    end
  end
  return lst
end

"""Converts the tree to a flat list of keys (in order)."""
function listKeysReverse(inTree::Tree, lst::List{<:Key} = nil)

   lst = begin
    @match inTree begin
      LEAF(__) => Cons{Key}(inTree.key, lst)

      NODE(__) => begin
        lst = listKeysReverse(inTree.left, lst)
        lst = Cons{Key}(inTree.key, lst)
        lst = listKeysReverse(inTree.right, lst)
        lst
      end

      _ => lst
    end
  end
  return lst
end

function referenceEqOrEmpty(t1::Tree, t2::Tree)
  if isvariant(t1, EMPTY) && isvariant(t2, EMPTY)
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
    local balanced_tree::Tree
    @match outTree begin
      LEAF(__) => inTree
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
          balanced_tree = NODE(outTree.key, outTree.value, max(lh, rh) + 1, outTree.left, outTree.right)
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
   @match inNode begin
     NODE(__) => inNode.height
     LEAF(__) => 1
     _ => 0
   end
end

function calculateBalance(inNode::Tree)::Int

  @match inNode begin
    NODE(__) => height(inNode.left) - height(inNode.right)

    LEAF(__) => 0

    _ => 0
  end
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

      _ => inNode
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
      _ => inNode
    end
  end
  return outNode
end

"""Conflict resolving function for add which fails on conflict."""
function addConflictFail(::Value, ::Value, ::Key)
  fail()
end

"""Conflict resolving function for add which replaces the old value with the new."""
function addConflictReplace(newValue::Value, ::Value, ::Key)
  local value::Value = newValue
  return value
end

"""Conflict resolving function for add which keeps the old value."""
function addConflictKeep(::Value, oldValue::Value, ::Key)
  local value::Value = oldValue
  return value
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
  if isvariant(tree, EMPTY)
    fail()
  end
  local k::Key = tree.key
  local kc = keyCompare(key, k)
  if kc == 0
    return tree.value
  end
  value = begin
    if kc == 1 && isvariant(tree, NODE)
      get(tree.right, key)
    elseif kc == -1 && isvariant(tree, NODE)
      get(tree.left, key)
    else
      fail()
    end
  end
  return value
end

"""
  Fetches a value from the tree given a key, or returns NONE if no value is
  associated with the key.
"""
function getOpt(tree::Tree, key::Key)
  local cur = tree
  while true
    if isvariant(cur, NODE)
      local c = keyCompare(key, cur.key)
      if c == 0
        return SOME(cur.value)
      elseif c > 0
        cur = cur.right
      else
        cur = cur.left
      end
    elseif isvariant(cur, LEAF)
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
      LEAF(key = key, value = value) => Cons{Tuple{Key, Value}}((key, value), lst)
      _ => lst
    end
  end
  return lst
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
      LEAF(value = value) => Cons{Value}(value, lst)
      _ => lst
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
    LEAF(value = value) => push!(vec, value)
    _ => vec
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
      EMPTY(__) => tree
      NODE(__) => begin
         tree = add(tree, treeToJoin.key, treeToJoin.value, conflictFunc)
         tree = join(tree, treeToJoin.left, conflictFunc)
         tree = join(tree, treeToJoin.right, conflictFunc)
        tree
      end

      LEAF(__) => add(tree, treeToJoin.key, treeToJoin.value, conflictFunc)
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

      EMPTY(__) => ()
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
    @match outTree begin
      NODE(key = key, value = value) => begin
         new_left = map(outTree.left, inFunc)
         new_value = inFunc(key, value)
         new_right = map(outTree.right, inFunc)
        if referenceEq(new_left, outTree.left) && referenceEq(value, new_value) && referenceEq(new_right, outTree.right)
          outTree
        else
          NODE(key, new_value, outTree.height, new_left, new_right)
        end
      end
      LEAF(key = key, value = value) => begin
         new_value = inFunc(key, value)
        if referenceEq(value, new_value)
          outTree
        else
          LEAF(key, new_value)
        end
      end
      _ => inTree
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
      _ => outResult
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

     _ => ()
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

      _ => value
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
    @match outTree begin
      NODE(key = key, value = value) => begin
         (new_left, outResult) = mapFold(outTree.left, inFunc, outResult)
         (new_value, outResult) = inFunc(key, value, outResult)
         (new_right, outResult) = mapFold(outTree.right, inFunc, outResult)
        if referenceEq(new_left, outTree.left) && referenceEq(value, new_value) && referenceEq(new_right, outTree.right)
          outTree
        else
          NODE(key, new_value, outTree.height, new_left, new_right)
        end
      end

      LEAF(key = key, value = value) => begin
         (new_value, outResult) = inFunc(key, value, outResult)
        if referenceEq(value, new_value)
          outTree
        else
          LEAF(key, new_value)
        end
      end

      _ => inTree
    end
  end
  return (outTree, outResult)
end

function setTreeLeftRight(orig::Tree, left::Tree = EMPTY(), right::Tree = EMPTY())
  local res::Tree
  res = begin
    @match (orig, left, right) begin
      (NODE(__), EMPTY(__), EMPTY(__)) => LEAF(orig.key, orig.value)

      (LEAF(__), EMPTY(__), EMPTY(__)) => orig

      (NODE(__), _, _) => begin
        if referenceEqOrEmpty(orig.left, left) && referenceEqOrEmpty(orig.right, right)
          orig
        else
          NODE(orig.key, orig.value, max(height(left), height(right)) + 1, left, right)
        end
      end

      (LEAF(__), _, _) => NODE(orig.key, orig.value, max(height(left), height(right)) + 1, left, right)
    end
  end
  return res
end
