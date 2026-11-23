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

module DuplicateTree
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo

import ..LookupTree
import ..InstNode
import ..Util.referenceCompare

struct DUPLICATE_TREE_ENTRY{T0 <: LookupTree.Entry}
  entry::T0
  node::Option
  children::Vector{DUPLICATE_TREE_ENTRY}
  ty::Int
end

#= Singelton uniontype =#
const Entry = DUPLICATE_TREE_ENTRY
const Key = String
const Value = Entry

#= The binary tree data structure. Compacted so the recursive left/right
   spine is concretely typed (TreeData) for inference-friendly traversal. =#
@CUniontype Tree begin
  EMPTY()
  LEAF(key::Key, value::Value)
  NODE(key::Key, value::Value, height::Int, left::Tree, right::Tree)
end

struct EntryTypeStruct{T0 <: Integer}
  DUPLICATE::T0
  REDECLARE::T0
  ENTRY::T0
end

const EntryType = EntryTypeStruct(#=DUPLICATE=# 1,  #=REDCLARE=# 2 , #= ENTRY =# 3)

function newRedeclare(entry::LookupTree.Entry)
  DUPLICATE_TREE_ENTRY{LookupTree.Entry}(entry, NONE(), Entry[], EntryType.REDECLARE)
end

function newDuplicate(kept::LookupTree.Entry, duplicate::LookupTree.Entry)
  DUPLICATE_TREE_ENTRY{LookupTree.Entry}(kept, NONE(), Entry[newEntry(duplicate)], EntryType.DUPLICATE)
end

function newEntry(entry::LookupTree.Entry)
  DUPLICATE_TREE_ENTRY{LookupTree.Entry}(entry, NONE(), Entry[], EntryType.ENTRY)
end

function idExistsInEntry(id::LookupTree.Entry, entry::Entry)
  local exists::Bool
    exists =
    LookupTree.isEqual(id, entry.entry) || any((child) -> idExistsInEntry(id, child), entry.children)
  return exists
end

# The AVL tree functions shared with ModTable.
include("avlTreeBody.jl")

const addConflictDefault = addConflictReplace

"""Inserts a new node in the tree."""
function add(
  @nospecialize(inTree::Tree),
  inKey::Key,
  @nospecialize(inValue::Value),
  @nospecialize(conflictFunc::Function = addConflictDefault),
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

end
