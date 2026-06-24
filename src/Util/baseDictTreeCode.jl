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

#= Dict-backed drop-in for baseAvlTreeCode.jl.

   Textually included into a tree submodule that has already defined `const Key`
   and `const Value`. The tree is a `Dict{Key,Value}`; lookup/insert use the
   key type's `hash`/`isequal` (correct for value types like `String`).
   `keyCompare` is used ONLY to order iteration so output matches the former
   AVL in-order (sorted) traversal. Both `keyCompare` and `addConflictDefault`
   are reassignable globals the includer overrides after the include, mirroring
   baseAvlTreeCode.jl. =#

const Tree = Dict{Key, Value}

#= Overridden by the includer; the AVL used a Bool placeholder here too. =#
keyCompare::Function = (inKey1::Key, inKey2::Key) -> (inKey1 == inKey2)

@inline _sortedKeys(tree::Tree) = sort!(collect(keys(tree)); lt = (a, b) -> keyCompare(a, b) < 0)

function addConflictFail(newValue::Value, oldValue::Value, key::Key)
  fail()
end
addConflictReplace(newValue::Value, oldValue::Value, key::Key)::Value = newValue
addConflictKeep(newValue::Value, oldValue::Value, key::Key)::Value = oldValue
addConflictDefault = addConflictFail

"""Return an empty tree."""
new()::Tree = Dict{Key, Value}()
EMPTY()::Tree = Dict{Key, Value}()

isEmpty(tree::Tree)::Bool = isempty(tree)

hasKey(tree::Tree, key::Key)::Bool = haskey(tree, key)

"""Insert an entry, mutating and returning the tree."""
function add(
  inTree::Tree,
  inKey::Key,
  inValue::Value,
  conflictFunc::Function = addConflictDefault,
)::Tree
  if haskey(inTree, inKey)
    inTree[inKey] = conflictFunc(inValue, inTree[inKey], inKey)
  else
    inTree[inKey] = inValue
  end
  return inTree
end

function addList(
  tree::Tree,
  inValues::List,
  conflictFunc::Function = addConflictDefault,
)::Tree
  for (key, value) in inValues
    add(tree, key, value, conflictFunc)
  end
  return tree
end

update(tree::Tree, key::Key, value::Value)::Tree = add(tree, key, value, addConflictReplace)

"""Fetch a value or fail if absent."""
function get(tree::Tree, key::Key)
  haskey(tree, key) ? tree[key] : fail()
end

"""Fetch a value or return `nothing` if absent (no Option allocation)."""
tryGet(tree::Tree, key::Key) = Base.get(tree, key, nothing)

"""Fetch a value or NONE if absent."""
getOpt(tree::Tree, key::Key)::Option{Value} = haskey(tree, key) ? SOME(tree[key]) : NONE()

function fromList(
  inValues::List,
  conflictFunc::Function = addConflictDefault,
)::Tree
  local tree = Dict{Key, Value}()
  for (key, value) in inValues
    add(tree, key, value, conflictFunc)
  end
  return tree
end

"""Flat list of (key, value) tuples in key order."""
function toList(inTree::Tree, lst::List = nil)
  local ks = _sortedKeys(inTree)
  local res = lst
  for i = length(ks):-1:1
    res = Cons{Tuple{Key, Value}}((ks[i], inTree[ks[i]]), res)
  end
  return res
end

function toVector(inTree::Tree)
  local vec = Pair[]
  for k in _sortedKeys(inTree)
    push!(vec, k => inTree[k])
  end
  return vec
end

"""List of values in key order."""
function listValues(tree::Tree, lst::List = nil)
  local ks = _sortedKeys(tree)
  local res = lst
  for i = length(ks):-1:1
    res = Cons{Value}(tree[ks[i]], res)
  end
  return res
end

function listKeys(inTree::Tree, lst::List = nil)
  local ks = _sortedKeys(inTree)
  local res = lst
  for i = length(ks):-1:1
    res = Cons{Key}(ks[i], res)
  end
  return res
end

function listKeysReverse(inTree::Tree, lst::List = nil)
  local ks = _sortedKeys(inTree)
  local res = lst
  for k in ks
    res = Cons{Key}(k, res)
  end
  return res
end

function join(
  tree::Tree,
  treeToJoin::Tree,
  conflictFunc::Function = addConflictDefault,
)::Tree
  for k in _sortedKeys(treeToJoin)
    add(tree, k, treeToJoin[k], conflictFunc)
  end
  return tree
end

function forEach(tree::Tree, func::Function)
  for k in _sortedKeys(tree)
    func(k, tree[k])
  end
  return nothing
end

function map(inTree::Tree, inFunc::Function)::Tree
  local d = Dict{Key, Value}()
  for k in _sortedKeys(inTree)
    d[k] = inFunc(k, inTree[k])
  end
  return d
end

function fold(inTree::Tree, inFunc::Function, inStartValue::FT) where {FT}
  local acc = inStartValue
  for k in _sortedKeys(inTree)
    acc = inFunc(k, inTree[k], acc)
  end
  return acc
end

function fold_2(
  tree::Tree,
  foldFunc::Function,
  foldArg1::FT1,
  foldArg2::FT2,
) where {FT1, FT2}
  for k in _sortedKeys(tree)
    (foldArg1, foldArg2) = foldFunc(k, tree[k], foldArg1, foldArg2)
  end
  return (foldArg1, foldArg2)
end

function foldCond(tree::Tree, foldFunc::Function, value::FT) where {FT}
  for k in _sortedKeys(tree)
    (value, _) = foldFunc(k, tree[k], value)
  end
  return value
end

function mapFold(inTree::Tree, inFunc::Function, inStartValue::FT) where {FT}
  local acc = inStartValue
  local d = Dict{Key, Value}()
  for k in _sortedKeys(inTree)
    (nv, acc) = inFunc(k, inTree[k], acc)
    d[k] = nv
  end
  return (d, acc)
end

function printTreeStr(inTree::Tree)::String
  local parts = String[]
  for k in _sortedKeys(inTree)
    push!(parts, string(k))
  end
  return Base.join(parts, ", ")
end
