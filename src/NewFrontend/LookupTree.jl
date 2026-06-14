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

module LookupTree

using MetaModelica
using ExportAll

struct IMPORT{T}
  index::T
end

struct COMPONENT{T}
  index::T
end

struct CLASS{T}
  index::T
end

struct FAILED_LOOKUP
end

const Entry = Union{IMPORT, COMPONENT,CLASS, FAILED_LOOKUP}

const Key = String
# Concrete (isbits) value union so the Dict stores entries inline, no per-entry box.
const Value = Union{IMPORT{Int}, COMPONENT{Int}, CLASS{Int}, FAILED_LOOKUP}
const FAILURE = FAILED_LOOKUP()

const valueStr = Function
const ConflictFunc = Function
const EachFunc = Function
const FoldFunc = Function
const MapFunc = Function

# A name lookup index: name -> entry. Backed by a Julia Dict; iteration
# functions reproduce the sorted-key order of the former AVL tree so that any
# downstream ordering stays bitwise identical.
const Tree = Dict{Key, Value}

keyCompare(inKey1::String, inKey2::String) = stringCompare(inKey1, inKey2)

keyStr = (key) -> key

@inline _sortedKeys(tree::Tree) = sort!(collect(keys(tree)); lt = (a, b) -> keyCompare(a, b) < 0)

# Constructor shims so literal trees built in NFBuiltin (NODE/LEAF/EMPTY) compose
# into a Dict without change. The height argument is ignored.
EMPTY()::Tree = Dict{Key, Value}()
LEAF(key::Key, value::Value)::Tree = Dict{Key, Value}(key => value)
function NODE(key::Key, value::Value, height, left::Tree, right::Tree)::Tree
  local d = Dict{Key, Value}()
  merge!(d, left, right)
  d[key] = value
  return d
end

"""Return an empty tree."""
new()::Tree = Dict{Key, Value}()

isEmpty(tree::Tree)::Bool = isempty(tree)

"""True if the key is present."""
hasKey(tree::Tree, key::Key)::Bool = haskey(tree, key)

#= Conflict resolving functions for add. =#
"""Conflict resolving function for add which fails on conflict."""
addConflictFail(newValue::Value, oldValue::Value, key::Key) = fail()

addConflictDefault::Function = addConflictFail

"""Conflict resolving function for add which replaces the old value with the new."""
addConflictReplace(newValue::Value, oldValue::Value, key::Key)::Value = newValue

"""Conflict resolving function for add which keeps the old value."""
addConflictKeep(newValue::Value, oldValue::Value, key::Key)::Value = oldValue

"""Inserts a new entry, mutating and returning the tree."""
function add(
  tree::Tree,
  inKey::Key,
  inValue::Value,
  conflictFunc::ConflictFunc = addConflictDefault,
)::Tree
  if haskey(tree, inKey)
    tree[inKey] = conflictFunc(inValue, tree[inKey], inKey)
  else
    tree[inKey] = inValue
  end
  return tree
end

"""Adds a list of key-value pairs to the tree."""
function addList(
  tree::Tree,
  inValues::List{<:Tuple{<:Key, Value}},
  conflictFunc::ConflictFunc = addConflictDefault,
)::Tree
  for (key, value) in inValues
    add(tree, key, value, conflictFunc)
  end
  return tree
end

"""Alias for add that replaces the value in case of conflict."""
update(tree::Tree, key::Key, value::Value)::Tree = add(tree, key, value, addConflictReplace)

"""
Fetches a value from the tree given a key, or returns FAILURE if absent.
"""
get(tree::Tree, key::Key) = Base.get(tree, key, FAILURE)

"""
Fetches a value from the tree given a key, or NONE if absent.
"""
getOpt(tree::Tree, key::Key)::Option{Value} = haskey(tree, key) ? SOME(tree[key]) : NONE()

"""Creates a new tree from a list of key-value pairs."""
function fromList(
  inValues::List{<:Tuple{<:Key, Value}},
  conflictFunc::ConflictFunc = addConflictDefault,
)::Tree
  local tree = Dict{Key, Value}()
  for (key, value) in inValues
    add(tree, key, value, conflictFunc)
  end
  return tree
end

"""Converts the tree to a flat list of key-value tuples in key order."""
function toList(inTree::Tree, lst::List = nil)::List{Tuple{Key, Value}}
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

"""Constructs a list of all the values in key order."""
function listValues(tree::Tree, lst::List = nil)
  local ks = _sortedKeys(tree)
  local res = lst
  for i = length(ks):-1:1
    res = Cons{Value}(tree[ks[i]], res)
  end
  return res
end

"""Constructs a list of all keys in order."""
function listKeys(inTree::Tree, lst::List = nil)
  local ks = _sortedKeys(inTree)
  local res = lst
  for i = length(ks):-1:1
    res = Cons{Key}(ks[i], res)
  end
  return res
end

"""Constructs a list of all keys in reverse order."""
function listKeysReverse(inTree::Tree, lst::List = nil)::List{Key}
  local ks = _sortedKeys(inTree)
  local res = lst
  for k in ks
    res = Cons{Key}(k, res)
  end
  return res
end

"""Joins two trees by adding the second one to the first."""
function join(
  tree::Tree,
  treeToJoin::Tree,
  conflictFunc::ConflictFunc = addConflictDefault,
)::Tree
  for k in _sortedKeys(treeToJoin)
    add(tree, k, treeToJoin[k], conflictFunc)
  end
  return tree
end

"""Applies func to each (key, value) in key order."""
function forEach(tree::Tree, func::EachFunc)
  for k in _sortedKeys(tree)
    func(k, tree[k])
  end
  return nothing
end

"""Maps func over the values, returning a new tree."""
function map(inTree::Tree, inFunc::MapFunc)::Tree
  local d = Dict{Key, Value}()
  for k in _sortedKeys(inTree)
    d[k] = inFunc(k, inTree[k])
  end
  return d
end

"""Folds func over (key, value) in key order, threading the accumulator."""
function fold(inTree::Tree, inFunc::FoldFunc, inStartValue::FT) where {FT}
  local acc = inStartValue
  for k in _sortedKeys(inTree)
    acc = inFunc(k, inTree[k], acc)
  end
  return acc
end

"""Like fold, but threads two accumulators."""
function fold_2(
  tree::Tree,
  foldFunc::FoldFunc,
  foldArg1::FT1,
  foldArg2::FT2,
) where {FT1, FT2}
  for k in _sortedKeys(tree)
    (foldArg1, foldArg2) = foldFunc(k, tree[k], foldArg1, foldArg2)
  end
  return (foldArg1, foldArg2)
end

"""Like fold; the fold function additionally returns a continue flag."""
function foldCond(tree::Tree, foldFunc::FoldFunc, value::FT) where {FT}
  for k in _sortedKeys(tree)
    (value, _) = foldFunc(k, tree[k], value)
  end
  return value
end

"""Maps func over the values while threading an accumulator."""
function mapFold(inTree::Tree, inFunc::MapFunc, inStartValue::FT) where {FT}
  local acc = inStartValue
  local d = Dict{Key, Value}()
  for k in _sortedKeys(inTree)
    (nv, acc) = inFunc(k, inTree[k], acc)
    d[k] = nv
  end
  return (d, acc)
end

"""Textual listing of the tree, key order. Debug aid."""
function printTreeStr(inTree::Tree)::String
  local parts = String[]
  for k in _sortedKeys(inTree)
    push!(parts, keyStr(k))
  end
  return Base.join(parts, ", ")
end

function isImport(entry::IMPORT)::Bool
  true
end

function isImport(entry::Entry)::Bool
  false
end

function isEqual(entry1::Entry, entry2::Entry)::Bool
  index(entry1) == index(entry2)
end

function index(entry::Entry)
  return entry.index
end

@exportAll()
end
