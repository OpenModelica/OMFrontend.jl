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

module ModTable

import ..ModifierImpl
import ..ModifierScope
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
using ..Frontend

const Key = String

@enum TreeTag::UInt8 EMPTY_TAG LEAF_TAG NODE_TAG
"""
    Tree

The modifier table, an AVL tree from names to modifiers: one tagged struct for all variants (`tag`).

- `EMPTY()`: no fields (a shared singleton).
- `LEAF(key, value)`: one entry.
- `NODE(key, value, height, left, right)`: an entry with its subtrees.

A variant's fields are the first ones of the struct; the others stay `#undef` (never read for that variant).
`value` is a `ModifierImpl{Tree}`, the frontend's `Modifier` (defined after this module, as it holds a `Tree`).
"""
struct Tree
  tag::TreeTag
  key::Key
  value::ModifierImpl{Tree}
  height::Int
  left::Tree
  right::Tree
  Tree(tag) = new(tag)
  Tree(tag, key, value) = new(tag, key, value)
  Tree(tag, key, value, height, left, right) = new(tag, key, value, height, left, right)
end

const Value = ModifierImpl{Tree}

const _EMPTY = Tree(EMPTY_TAG)
EMPTY() = _EMPTY
LEAF(key, value) = Tree(LEAF_TAG, key, value)
LEAF(; key, value) = LEAF(key, value)
NODE(key, value, height, left, right) = Tree(NODE_TAG, key, value, height, left, right)
NODE(; key, value, height, left, right) = NODE(key, value, height, left, right)

@registerVariants Tree begin
  EMPTY()
  LEAF(key, value)
  NODE(key, value, height, left, right)
end

"""`@assign` on a `Tree`: rebuilt from its variant's own fields (the default reads the `#undef` ones)."""
function MetaModelica.Accessors.ConstructionBase.setproperties(obj::Tree, patch::NamedTuple)
  local pick(f::Symbol) = haskey(patch, f) ? getfield(patch, f) : getfield(obj, f)
  obj.tag === EMPTY_TAG && return obj
  obj.tag === LEAF_TAG && return Tree(LEAF_TAG, pick(:key), pick(:value))
  return Tree(NODE_TAG, pick(:key), pick(:value), pick(:height), pick(:left), pick(:right))
end

# The AVL tree functions shared with DuplicateTree.
include("avlTreeBody.jl")

const addConflictDefault = addConflictFail

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
    #= Empty tree. =#
    @match tree begin
      EMPTY(__) => LEAF(inKey, inValue)

      NODE(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          balance(NODE(tree.key, tree.value, tree.height, add(tree.left, inKey, inValue, conflictFunc), tree.right))
        elseif key_comp == 1
          balance(NODE(tree.key, tree.value, tree.height, tree.left, add(tree.right, inKey, inValue, conflictFunc)))
        else
           value = conflictFunc(inValue, tree.value, key)
          if referenceEq(tree.value, value)
            tree
          else
            NODE(tree.key, value, tree.height, tree.left, tree.right)
          end
        end
      end
      LEAF(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          balance(NODE(tree.key, tree.value, 2, LEAF(inKey, inValue), EMPTY()))
        elseif key_comp == 1
          balance(NODE(tree.key, tree.value, 2, EMPTY(), LEAF(inKey, inValue)))
        else
          value = conflictFunc(inValue, tree.value, key)
          if referenceEq(tree.value, value)
            tree
          else
            LEAF(tree.key, value)
          end
        end
      end
    end
  end
  return tree
end

"""
modtable specific add. Calls merge instead of conflict func.
"""
function add(
  inTree::Tree,
  inKey::Key,
  inValue::Value,
  scope::ModifierScope,
  prefix::List{String}
)::Tree #= Used to resolve conflicts. =#
  local tree::Tree = inTree

   tree = begin
    local key::Key
    local value::Value
    local key_comp::Int
    #= Empty tree. =#
    @match tree begin
      EMPTY(__) => LEAF(inKey, inValue)

      NODE(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          balance(NODE(tree.key, tree.value, tree.height, add(tree.left, inKey, inValue, scope, prefix), tree.right))
        elseif key_comp == 1
          balance(NODE(tree.key, tree.value, tree.height, tree.left, add(tree.right, inKey, inValue, scope, prefix)))
        else
           value = mergeLocal(inValue, tree.value, key, scope, prefix)
          if referenceEq(tree.value, value)
            tree
          else
            NODE(tree.key, value, tree.height, tree.left, tree.right)
          end
        end
      end
      LEAF(key = key) => begin
         key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          balance(NODE(tree.key, tree.value, 2, LEAF(inKey, inValue), EMPTY()))
        elseif key_comp == 1
          balance(NODE(tree.key, tree.value, 2, EMPTY(), LEAF(inKey, inValue)))
        else
          value = mergeLocal(inValue, tree.value, key, scope, prefix)
          if referenceEq(tree.value, value)
            tree
          else
            LEAF(tree.key, value)
          end
        end
      end
    end
  end
  return tree
end

function fromVector(
  inValues::Vector{<:Value},
  inKeys::Vector{Key},
  scope::ModifierScope,
  prefix::List{String}
  )::Tree #= Used to resolve conflicts. =#
  local tree::Tree = EMPTY()
  for (key, val) in zip(inKeys, inValues)
    tree = add(tree, key, val, scope, prefix)
  end
  return tree
end

"""
`tree` with the entries of `treeToJoin` added; an entry in both is merged (`mergeLocal` in `scope`, under `prefix`).
"""
function join(tree::Tree, treeToJoin::Tree, scope::ModifierScope, prefix::List{String})::Tree
   tree = begin
    @match treeToJoin begin
      EMPTY(__) => tree
      NODE(__) => begin
         tree = add(tree, treeToJoin.key, treeToJoin.value, scope, prefix)
         tree = join(tree, treeToJoin.left, scope, prefix)
         tree = join(tree, treeToJoin.right, scope, prefix)
        tree
      end

      LEAF(__) => add(tree, treeToJoin.key, treeToJoin.value, scope, prefix)
    end
  end
  return tree
end

@exportAll()
end
