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

module P_UnorderedSet

using MetaModelica
using ExportAll

#= Hash set with user-provided hash and equality functions.
   Follows the OpenModelica UnorderedSet API.
   Internally wraps a Dict{Any,Bool} for simplicity. =#

mutable struct UnorderedSet
  data::Dict{Any,Bool}
  hashFn::Base.Function
  eqFn::Base.Function
end

# OpenModelica's NFUnorderedSet exposes the set type as `USet`.
const USet = UnorderedSet

function new(hashFn::Base.Function, eqFn::Base.Function)
  return UnorderedSet(Dict{Any,Bool}(), hashFn, eqFn)
end

function new(hashFn::Base.Function, eqFn::Base.Function, _bucketCount::Int)
  return UnorderedSet(Dict{Any,Bool}(), hashFn, eqFn)
end

function fromList(lst, hashFn::Base.Function, eqFn::Base.Function)
  s = new(hashFn, eqFn)
  for e in lst
    s.data[e] = true
  end
  return s
end

function add(elem, s::UnorderedSet)
  s.data[elem] = true
end

function addNew(elem, s::UnorderedSet)
  s.data[elem] = true
end

function addUnique(elem, s::UnorderedSet)
  s.data[elem] = true
end

function remove(elem, s::UnorderedSet)::Bool
  if haskey(s.data, elem)
    delete!(s.data, elem)
    return true
  end
  return false
end

function get(elem, s::UnorderedSet)
  if haskey(s.data, elem)
    return SOME(elem)
  end
  return nothing
end

function getOrFail(elem, s::UnorderedSet)
  if haskey(s.data, elem)
    return elem
  end
  error("UnorderedSet.getOrFail: element not found")
end

contains(elem, s::UnorderedSet) = haskey(s.data, elem)

function first(s::UnorderedSet)
  return Base.first(Base.keys(s.data))
end

function size(s::UnorderedSet)::Int
  return length(s.data)
end

function isEmpty(s::UnorderedSet)::Bool
  return Base.isempty(s.data)
end

function toList(s::UnorderedSet)
  return list(k for k in Base.keys(s.data))
end

function toArray(s::UnorderedSet)
  return collect(Base.keys(s.data))
end

function copy(s::UnorderedSet)
  return UnorderedSet(Base.copy(s.data), s.hashFn, s.eqFn)
end

function fold(s::UnorderedSet, func, startValue)
  result = startValue
  for k in Base.keys(s.data)
    result = func(k, result)
  end
  return result
end

function apply(s::UnorderedSet, func)
  newData = Dict{Any,Bool}()
  for k in Base.keys(s.data)
    newData[func(k)] = true
  end
  s.data = newData
end

function all(s::UnorderedSet, func)::Bool
  for k in Base.keys(s.data)
    if !func(k)
      return false
    end
  end
  return true
end

function any(s::UnorderedSet, func)::Bool
  for k in Base.keys(s.data)
    if func(k)
      return true
    end
  end
  return false
end

function none(s::UnorderedSet, func)::Bool
  return !any(s, func)
end

function merge(s1::UnorderedSet, s2::UnorderedSet)
  for k in Base.keys(s2.data)
    s1.data[k] = true
  end
end

function clear(s::UnorderedSet)
  empty!(s.data)
end

function toString(s::UnorderedSet, fn, delimiter::String = "\n")
  entries = String[fn(k) for k in Base.keys(s.data)]
  return join(entries, delimiter)
end

@exportAll()
end
