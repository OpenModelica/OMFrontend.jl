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

module P_UnorderedMap

using MetaModelica
using ExportAll

#= Hash map with user-provided hash and equality functions.
   Follows the OpenModelica UnorderedMap API.
   Internally wraps a Dict for simplicity. =#

mutable struct UnorderedMap
  data::Dict{Any,Any}
  hashFn::Base.Function
  eqFn::Base.Function
end

# OpenModelica's NFUnorderedMap exposes the map type as `Map`.
const Map = UnorderedMap

function new(hashFn::Base.Function, eqFn::Base.Function)
  return UnorderedMap(Dict{Any,Any}(), hashFn, eqFn)
end

function new(hashFn::Base.Function, eqFn::Base.Function, _bucketCount::Integer)
  return UnorderedMap(Dict{Any,Any}(), hashFn, eqFn)
end

function add(key, value, m::UnorderedMap)
  m.data[key] = value
end

function tryAdd(key, value, m::UnorderedMap)
  if !haskey(m.data, key)
    m.data[key] = value
    return value
  end
  return m.data[key]
end

function addNew(key, value, m::UnorderedMap)
  m.data[key] = value
end

function addUnique(key, value, m::UnorderedMap)
  m.data[key] = value
end

function addUpdate(key, updateFn, m::UnorderedMap)
  if haskey(m.data, key)
    m.data[key] = updateFn(SOME(m.data[key]))
  else
    m.data[key] = updateFn(nothing)
  end
end

function get(key, m::UnorderedMap)
  if haskey(m.data, key)
    return SOME(m.data[key])
  end
  return nothing
end

function getSafe(key, m::UnorderedMap, info)
  if haskey(m.data, key)
    return m.data[key]
  end
  error("UnorderedMap.getSafe: key not found")
end

function getOrFail(key, m::UnorderedMap)
  return m.data[key]
end

function getOrDefault(key, m::UnorderedMap, default)
  return Base.get(m.data, key, default)
end

function getKey(key, m::UnorderedMap)
  if haskey(m.data, key)
    return SOME(key)
  end
  return nothing
end

contains(key, m::UnorderedMap) = haskey(m.data, key)

function first(m::UnorderedMap)
  return Base.first(Base.values(m.data))
end

function firstKey(m::UnorderedMap)
  return Base.first(Base.keys(m.data))
end

function keyAt(m::UnorderedMap, index::Integer)
  return collect(Base.keys(m.data))[index]
end

function valueAt(m::UnorderedMap, index::Integer)
  return collect(Base.values(m.data))[index]
end

function size(m::UnorderedMap)::Integer
  return length(m.data)
end

function isEmpty(m::UnorderedMap)::Bool
  return Base.isempty(m.data)
end

function toList(m::UnorderedMap)
  return list((k, v) for (k, v) in m.data)
end

function keyList(m::UnorderedMap)
  return list(k for k in Base.keys(m.data))
end

function valueList(m::UnorderedMap)
  return list(v for v in Base.values(m.data))
end

function toArray(m::UnorderedMap)
  return [(k, v) for (k, v) in m.data]
end

function keyArray(m::UnorderedMap)
  return collect(Base.keys(m.data))
end

function valueArray(m::UnorderedMap)
  return collect(Base.values(m.data))
end

function clear(m::UnorderedMap)
  empty!(m.data)
end

function apply(m::UnorderedMap, func)
  for (k, v) in m.data
    m.data[k] = func(v)
  end
end

function fold(m::UnorderedMap, func, startValue)
  result = startValue
  for (k, v) in m.data
    result = func(k, v, result)
  end
  return result
end

function remove(key, m::UnorderedMap)::Bool
  if haskey(m.data, key)
    delete!(m.data, key)
    return true
  end
  return false
end

function copy(m::UnorderedMap)
  return UnorderedMap(Base.copy(m.data), m.hashFn, m.eqFn)
end

function deepCopy(m::UnorderedMap, fn)
  newData = Dict{Any,Any}()
  for (k, v) in m.data
    newData[k] = fn(v)
  end
  return UnorderedMap(newData, m.hashFn, m.eqFn)
end

function toString(m::UnorderedMap, keyFn, valFn, delimiter::String = "\n")
  entries = String["($(keyFn(k)), $(valFn(v)))" for (k, v) in m.data]
  return join(entries, delimiter)
end

function toJSON(m::UnorderedMap, keyFn, valFn)
  return toString(m, keyFn, valFn, ", ")
end

function fromLists(keysList, valsList, hashFn, eqFn)
  m = new(hashFn, eqFn)
  ks = collect(keysList)
  vs = collect(valsList)
  for (k, v) in zip(ks, vs)
    m.data[k] = v
  end
  return m
end

function merge(m1::UnorderedMap, m2::UnorderedMap, info)
  result = copy(m1)
  for (k, v) in m2.data
    result.data[k] = v
  end
  return result
end

function subMap(m::UnorderedMap, lst)
  sub = new(m.hashFn, m.eqFn)
  for k in lst
    sub.data[k] = getSafe(k, m, nothing)
  end
  return sub
end

function all(m::UnorderedMap, func)::Bool
  for v in Base.values(m.data)
    if !func(v)
      return false
    end
  end
  return true
end

function any(m::UnorderedMap, func)::Bool
  for v in Base.values(m.data)
    if func(v)
      return true
    end
  end
  return false
end

function none(m::UnorderedMap, func)::Bool
  return !any(m, func)
end

@exportAll()
end
