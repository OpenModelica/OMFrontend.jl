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


#= Cref-keyed table backed by a Julia Dict with structural hash/equality.
   Replaces the ported BaseHashTable closure-tuple representation. =#
module NFHashTable

using MetaModelica

import ..Frontend
import ..Frontend.NFComponentRef
import ..Frontend.CrefHashKey

const ComponentRef = NFComponentRef
const Key = ComponentRef
const Value = Int
const HashTable = Dict{CrefHashKey, Value}

emptyHashTable()::HashTable = HashTable()
emptyHashTableSized(::Int)::HashTable = HashTable()

function add(entry::Tuple{<:ComponentRef, <:Value}, t::HashTable)::HashTable
  t[CrefHashKey(entry[1])] = entry[2]
  return t
end

#= Fails (KeyError) when the key is missing, like BaseHashTable.get. =#
get(key::ComponentRef, t::HashTable)::Value = t[CrefHashKey(key)]

getOrNothing(key::ComponentRef, t::HashTable)::Union{Value, Nothing} =
  Base.get(t, CrefHashKey(key), nothing)

hasKey(key::ComponentRef, t::HashTable)::Bool = haskey(t, CrefHashKey(key))

end
