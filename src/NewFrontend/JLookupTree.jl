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

"""
  Experimental reimplementation
  of the lookup tree using the Julia dict.
"""
module JLookupTree

using ExportAll
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo

import ..LookupTree
const Key = LookupTree.Key
const Value = LookupTree.Entry
const Tree = Dict{Key, Value}
const ConflictFunc = Function

function hasKey(t::Tree, k::Key)::Bool
  local hk = in(k, keys(t))
  return hk
end

function setValue!(t::Tree, k, v)
  if in(k, keys(t))
    @info "Conflict. Lets redo..."
    fail() #Conflict
  else
    t[k] = v
  end
end

function getIndex(t::Tree, i)
  return t[i]
end

const addConflictDefault = fail

function add(
  tree::Tree,
  inKey::Key,
  inValue::Value,
  conflictFunc::ConflictFunc = addConflictDefault,
  )::Tree
  setValue!(tree, k, v)
end

function addList(tree::Tree,
                 inValues::Cons,
                 conflictFunc::ConflictFunc = addConflictDefault)
  for (k,v) in inValues
    setValue!(tree, k, v)
  end
  return tree
end

function get(tree::Tree, key::Key)
  tree[key]
end

@exportAll
end
