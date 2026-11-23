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
The list functions of OMFrontend (OpenModelica's List package, the part the frontend uses).

Every function that builds a list takes the element type `TO` of the result as its last argument and builds
`Cons{TO}` cells; the result is a `TypedList{TO}` (`nil` or a `Cons{TO}`). A fold takes the type of its accumulator
(`TO` for `fold`, `TA` for the argument of `mapFold`). The caller passes the element type it declares
(`List{Subscript}` → `Subscript`), so the result is stored without a conversion (`convert` copies a list of another
element type cell by cell) and every local in the loops has a concrete or small union type.

A list argument may have cells of any element type: it is read, and copied only where a result needs `Cons{TO}` cells
and the input has others.

Small functions that take an element as an argument (`isMemberOnTrue`, `consOnTrue`, ...) are `@inline`: a call with
an argument of abstract type (`Expression`, `Subscript`) is a run-time dispatch unless it is inlined.

Failures (`fail()`) are kept where OpenModelica's functions fail: callers inside `@matchcontinue` rely on them.
"""
module ListUtil

using MetaModelica
using ExportAll
import ImmutableList

"""
    TypedList{T}

A list built by ListUtil: `nil` or a `Cons{T}`. A `List{T}` field or variable holds it without a conversion.
"""
const TypedList{T} = Union{Nil{Any}, Cons{T}}

#= ---------------------------------------------------------------------------------------------------------------
   Building lists
   --------------------------------------------------------------------------------------------------------------- =#

"""
    _reverseTyped(::Type{TO}, acc) -> TypedList{TO}

The accumulator `acc`, built reversed, in order. An accumulator of zero or one element is returned as it is.
"""
_reverseTyped(::Type{TO}, ::Nil) where {TO} = nil
function _reverseTyped(::Type{TO}, acc::Cons{TO})::Cons{TO} where {TO}
  acc.tail isa Nil && return acc
  local out::Cons{TO} = Cons{TO}(acc.head, nil)
  local cur::Union{Nil, Cons{TO}} = acc.tail
  while cur isa Cons{TO}
    out = Cons{TO}(cur.head, out)
    cur = cur.tail
  end
  return out
end

"""
    _reverseOnto(::Type{TO}, lst, acc) -> TypedList{TO}

The elements of `lst` in reverse order in front of `acc`, in `Cons{TO}` cells.
"""
_reverseOnto(::Type{TO}, ::Nil, acc::TypedList{TO}) where {TO} = acc
function _reverseOnto(::Type{TO}, lst::Cons{T}, acc::TypedList{TO})::Cons{TO} where {TO, T}
  local out::TypedList{TO} = acc
  for e::T in lst
    out = Cons{TO}(e, out)
  end
  return out
end

"""
    _typed(::Type{TO}, lst) -> TypedList{TO}

`lst` as a `TypedList{TO}`: itself when it is empty or has `Cons{TO}` cells, else a copy.
"""
_typed(::Type{TO}, ::Nil) where {TO} = nil
_typed(::Type{TO}, lst::Cons{TO}) where {TO} = lst
_typed(::Type{TO}, lst::Cons{T}) where {TO, T} = _reverseTyped(TO, _reverseOnto(TO, lst, nil))

"""
    _copyOnto(::Type{TO}, lst, acc) -> TypedList{TO}

The elements of `lst`, in order, in front of `acc`; `lst` itself is shared when `acc` is empty.
"""
_copyOnto(::Type{TO}, ::Nil, acc::TypedList{TO}) where {TO} = acc
_copyOnto(::Type{TO}, lst::Cons{T}, ::Nil) where {TO, T} = _typed(TO, lst)
function _copyOnto(::Type{TO}, lst::Cons{T}, acc::Cons{TO})::Cons{TO} where {TO, T}
  return _reverseOnto(TO, _reverseOnto(TO, lst, nil), acc)
end

"""
    _vector(::Type{TO}, lst) -> Vector{TO}

The elements of `lst` in a vector.
"""
function _vector(::Type{TO}, lst::List{T})::Vector{TO} where {TO, T}
  local v::Vector{TO} = Vector{TO}(undef, listLength(lst))
  local i::Int = 0
  for e::T in lst
    i += 1
    v[i] = e
  end
  return v
end

"""
    _fromVector(::Type{TO}, v) -> TypedList{TO}

The elements of `v`, in order, as a list.
"""
function _fromVector(::Type{TO}, v::Vector{TO})::TypedList{TO} where {TO}
  local out::TypedList{TO} = nil
  for i in length(v):-1:1
    out = Cons{TO}(v[i], out)
  end
  return out
end

"""
    _norm(lst) -> Union{Nil{Any}, Cons{T}}

A rest of a list (a `tail` field, of type `Union{Nil, Cons{T}}`) with its empty list as `nil`.
"""
_norm(::Nil) = nil
_norm(lst::Cons{T}) where {T} = lst

#= ---------------------------------------------------------------------------------------------------------------
   Creating and taking apart
   --------------------------------------------------------------------------------------------------------------- =#

"""
    fill(inElement, inCount, TO) -> TypedList{TO}

A list of `inCount` copies of `inElement`. Example: `fill(2, 3, Int) => {2, 2, 2}`.
"""
@inline function fill(inElement::TO, inCount::Int, ::Type{TO})::TypedList{TO} where {TO}
  local out::TypedList{TO} = nil
  for _ in 1:inCount
    out = Cons{TO}(inElement, out)
  end
  return out
end

"""
    consOnTrue(inCondition, inElement, inList, TO) -> TypedList{TO}

`inElement` in front of `inList` if `inCondition` holds, else `inList`.
"""
@inline function consOnTrue(inCondition::Bool, inElement::TO, inList::List{T}, ::Type{TO})::TypedList{TO} where {TO, T}
  local rest::TypedList{TO} = _typed(TO, inList)
  return inCondition ? Cons{TO}(inElement, rest) : rest
end

"""
    append_reverse(inList1, inList2, TO) -> TypedList{TO}

The elements of `inList1` in reverse order in front of `inList2`.
"""
function append_reverse(inList1::List{T1}, inList2::List{T2}, ::Type{TO})::TypedList{TO} where {T1, T2, TO}
  return _reverseOnto(TO, inList1, _typed(TO, inList2))
end

"""
    set(inList, inN, inElement, TO) -> TypedList{TO}

`inList` with the element at the one-based position `inN` replaced. Example: `set({2,1,4,2}, 2, 3, Int) => {2,3,4,2}`.
"""
function set(inList::List{T}, inN::Int, inElement::TO, ::Type{TO})::TypedList{TO} where {T, TO}
  inN > 0 || fail()
  local (before, after) = splitr(inList, inN - 1, TO)
  return _reverseOnto(TO, before, Cons{TO}(inElement, _typed(TO, stripFirst(after))))
end

""" All elements but the first; fails if the list is empty. """
rest(inList::Cons{T}) where {T} = _norm(inList.tail)
rest(::Nil) = fail()

""" The last element of a list; fails if the list is empty. """
function last(inList::Cons{T})::T where {T}
  local cur::Cons{T} = inList
  while cur.tail isa Cons{T}
    cur = cur.tail
  end
  return cur.head
end
last(::Nil) = fail()

"""
    firstN(inList, inN, TO) -> TypedList{TO}

The first `inN` elements; fails if there are fewer.
"""
function firstN(inList::List{T}, inN::Int, ::Type{TO})::TypedList{TO} where {T, TO}
  inN >= 0 || fail()
  local acc::TypedList{TO} = nil
  local cur::Union{Nil, Cons{T}} = inList
  for _ in 1:inN
    cur isa Cons{T} || fail()
    acc = Cons{TO}(cur.head, acc)
    cur = cur.tail
  end
  return _reverseTyped(TO, acc)
end

"""
    lastN(inList, inN) -> List

The last `inN` elements (shared with `inList`); fails if there are fewer.
"""
function lastN(inList::List{T}, inN::Int) where {T}
  inN >= 0 || fail()
  return stripN(inList, listLength(inList) - inN)
end

""" All elements but the first (shared); the empty list for the empty list. """
stripFirst(inList::Cons{T}) where {T} = _norm(inList.tail)
stripFirst(::Nil) = nil

"""
    stripN(inList, inN) -> List

`inList` without its first `inN` elements (shared); fails if there are fewer or `inN` is negative.
"""
function stripN(inList::Cons{T}, inN::Int) where {T}
  inN >= 0 || fail()
  local cur::Union{Nil, Cons{T}} = inList
  for _ in 1:inN
    cur isa Cons{T} || fail()
    cur = cur.tail
  end
  return _norm(cur)
end
stripN(::Nil, inN::Int) = inN == 0 ? nil : fail()

"""
    split(inList, inPosition, TO) -> (TypedList{TO}, List)

The first `inPosition` elements and the rest (shared). Example: `split({1, 2, 5, 7}, 2, Int) => ({1, 2}, {5, 7})`.
"""
function split(inList::List{T}, inPosition::Int, ::Type{TO}) where {T, TO}
  local (before, after) = splitr(inList, inPosition, TO)
  return (_reverseTyped(TO, before), after)
end

"""
    splitr(inList, inPosition, TO) -> (TypedList{TO}, List)

As `split`, the first list reversed. Example: `splitr({1, 2, 5, 7}, 2, Int) => ({2, 1}, {5, 7})`.
"""
function splitr(inList::Cons{T}, inPosition::Int, ::Type{TO}) where {T, TO}
  inPosition >= 0 || fail()
  local acc::TypedList{TO} = nil
  local cur::Union{Nil, Cons{T}} = inList
  for _ in 1:inPosition
    cur isa Cons{T} || fail()
    acc = Cons{TO}(cur.head, acc)
    cur = cur.tail
  end
  return (acc, _norm(cur))
end
splitr(::Nil, inPosition::Int, ::Type{TO}) where {TO} = inPosition == 0 ? (nil, nil) : fail()

"""
    splitOnTrue(inList, inFunc, TO) -> (TypedList{TO}, TypedList{TO})

The elements for which `inFunc` holds and the others, each in the order of `inList`.
"""
function splitOnTrue(inList::List{T}, inFunc::F, ::Type{TO}) where {T, F<:Function, TO}
  local yes::TypedList{TO} = nil
  local no::TypedList{TO} = nil
  for e::T in inList
    if inFunc(e)
      yes = Cons{TO}(e, yes)
    else
      no = Cons{TO}(e, no)
    end
  end
  return (_reverseTyped(TO, yes), _reverseTyped(TO, no))
end

"""
    splitLast(inList, TO) -> (TO, TypedList{TO})

The last element and the elements before it; fails if the list is empty.
Example: `splitLast({3, 5, 7}, Int) => (7, {3, 5})`.
"""
function splitLast(inList::Cons{T}, ::Type{TO})::Tuple{TO, TypedList{TO}} where {T, TO}
  local acc::TypedList{TO} = nil
  local cur::Cons{T} = inList
  while cur.tail isa Cons{T}
    acc = Cons{TO}(cur.head, acc)
    cur = cur.tail
  end
  return (cur.head, _reverseTyped(TO, acc))
end
splitLast(::Nil, ::Type{TO}) where {TO} = fail()

"""
    partition(inList, inPartitionLength, TO) -> TypedList{List{TO}}

`inList` in parts of `inPartitionLength` elements, the last one shorter if needed.
Example: `partition({1, 2, 3, 4, 5}, 2, Int) => {{1, 2}, {3, 4}, {5}}`.
"""
function partition(inList::List{T}, inPartitionLength::Int, ::Type{TO})::TypedList{List{TO}} where {T, TO}
  inPartitionLength > 0 || fail()
  local acc::TypedList{List{TO}} = nil
  local part::TypedList{TO} = nil
  local k::Int = 0
  for e::T in inList
    part = Cons{TO}(e, part)
    k += 1
    if k == inPartitionLength
      acc = Cons{List{TO}}(_reverseTyped(TO, part), acc)
      part = nil
      k = 0
    end
  end
  part isa Cons && (acc = Cons{List{TO}}(_reverseTyped(TO, part), acc))
  return _reverseTyped(List{TO}, acc)
end

"""
    trim(lst, pred_func) -> List

`lst` without the elements at its head for which `pred_func` holds (shared).
Example: `trim({2, 4, 3, 6}, iseven) => {3, 6}`.
"""
function trim(lst::Cons{T}, pred_func::F) where {T, F<:Function}
  local cur::Union{Nil, Cons{T}} = lst
  while cur isa Cons{T} && pred_func(cur.head)
    cur = cur.tail
  end
  return _norm(cur)
end
trim(::Nil, ::F) where {F<:Function} = nil

"""
    filterOnTrue(inList, inFilterFunc, TO) -> TypedList{TO}

The elements for which `inFilterFunc` holds, in order. Example: `filterOnTrue({1, 2, 3, 4}, iseven, Int) => {2, 4}`.
"""
function filterOnTrue(inList::List{T}, inFilterFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    inFilterFunc(e) && (acc = Cons{TO}(e, acc))
  end
  return _reverseTyped(TO, acc)
end

""" True if the list has exactly one element. """
hasOneElement(inList::Cons{T}) where {T} = inList.tail isa Nil
hasOneElement(::Nil) = false

#= ---------------------------------------------------------------------------------------------------------------
   Sorting, unique elements and unions
   --------------------------------------------------------------------------------------------------------------- =#

"""
    sort(inList, inCompFunc, TO) -> TypedList{TO}

`inList` sorted (stable); `inCompFunc(a, b)` is true when `a` comes after `b`.
Example: `sort({2, 1, 3}, intGt, Int) => {1, 2, 3}`.
"""
function sort(inList::List{T}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  local v::Vector{TO} = _vector(TO, inList)
  Base.sort!(v; alg = Base.MergeSort, lt = (x::TO, y::TO) -> inCompFunc(y, x)::Bool)
  return _fromVector(TO, v)
end

"""
    sortedUnique(inList, inCompFunc, TO) -> TypedList{TO}

The elements of a sorted list without repeats; `inCompFunc` tells whether two neighbors are equal.
"""
function sortedUnique(inList::List{T}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  local acc::TypedList{TO} = nil
  local cur::Union{Nil, Cons{T}} = inList
  while cur isa Cons{T}
    local e::T = cur.head
    cur = cur.tail
    if cur isa Nil || !inCompFunc(e, cur.head)
      acc = Cons{TO}(e, acc)
    end
  end
  return _reverseTyped(TO, acc)
end

"""
    uniqueOnTrue(inList, inCompFunc, TO) -> TypedList{TO}

The elements of `inList` without duplicates (`inCompFunc`), the first occurrence kept.
"""
function uniqueOnTrue(inList::List{T}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  return _reverseTyped(TO, _unionAdd(nil, inList, inCompFunc, TO))
end

"""
    unionEltOnTrue(inElement, inList, inCompFunc, TO) -> TypedList{TO}

`inElement` in front of `inList` unless an element of `inList` equals it (`inCompFunc`).
"""
@inline function unionEltOnTrue(inElement::TO, inList::List{T}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {TO, T, F<:Function}
  return consOnTrue(!isMemberOnTrue(inElement, inList, inCompFunc), inElement, inList, TO)
end

"""
    union(inList1, inList2, TO) -> TypedList{TO}

The elements of both lists without duplicates (`isequal`). Example: `union({0, 1}, {2, 1}, Int) => {0, 1, 2}`.
An empty list and a list give that list as it is.
"""
function union(inList1::Cons{T1}, inList2::Cons{T2}, ::Type{TO})::TypedList{TO} where {T1, T2, TO}
  return _fromVector(TO, Base.union(_vector(TO, inList1), _vector(TO, inList2)))
end
union(::Nil, inList2::List{T2}, ::Type{TO}) where {T2, TO} = _typed(TO, inList2)
union(inList1::Cons{T1}, ::Nil, ::Type{TO}) where {T1, TO} = _typed(TO, inList1)

"""
    unionOnTrue(inList1, inList2, inCompFunc, TO) -> TypedList{TO}

The elements of both lists without duplicates (`inCompFunc`), in order of first occurrence.
Example: `unionOnTrue({1, 2}, {2, 3}, intEq, Int) => {1, 2, 3}`.
"""
function unionOnTrue(inList1::List{T1}, inList2::List{T2}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {T1, T2, F<:Function, TO}
  local acc::TypedList{TO} = _unionAdd(nil, inList1, inCompFunc, TO)
  return _reverseTyped(TO, _unionAdd(acc, inList2, inCompFunc, TO))
end

"""
    _unionAdd(acc, inList, inCompFunc, TO) -> TypedList{TO}

The elements of `inList` not yet in `acc` (`inCompFunc`) pushed onto `acc`. The membership loop is written out: a
call with an element of abstract type and a union argument is a run-time dispatch.
"""
function _unionAdd(acc::TypedList{TO}, inList::List{T}, inCompFunc::F, ::Type{TO})::TypedList{TO} where {TO, T, F<:Function}
  local out::TypedList{TO} = acc
  for e::T in inList
    local seen::Bool = false
    for x::TO in out
      inCompFunc(e, x) && (seen = true; break)
    end
    seen || (out = Cons{TO}(e, out))
  end
  return out
end

#= ---------------------------------------------------------------------------------------------------------------
   Mapping
   --------------------------------------------------------------------------------------------------------------- =#

"""
    map(inList, inFunc, TO) -> TypedList{TO}

`inFunc` applied to each element.
"""
function map(inList::List{T}, inFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inFunc(e), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    map1(inList, inMapFunc, inArg1, TO) -> TypedList{TO}

`inMapFunc(e, inArg1)` for each element.
"""
function map1(inList::List{T}, inMapFunc::F, inArg1::A1, ::Type{TO})::TypedList{TO} where {T, F<:Function, A1, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inMapFunc(e, inArg1), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    map2(inList, inFunc, inArg1, inArg2, TO) -> TypedList{TO}

`inFunc(e, inArg1, inArg2)` for each element.
"""
function map2(inList::List{T}, inFunc::F, inArg1::A1, inArg2::A2, ::Type{TO})::TypedList{TO} where {T, F<:Function, A1, A2, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inFunc(e, inArg1, inArg2), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    map3(inList, inFunc, inArg1, inArg2, inArg3, TO) -> TypedList{TO}

`inFunc(e, inArg1, inArg2, inArg3)` for each element.
"""
function map3(inList::List{T}, inFunc::F, inArg1::A1, inArg2::A2, inArg3::A3, ::Type{TO})::TypedList{TO} where {T, F<:Function, A1, A2, A3, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inFunc(e, inArg1, inArg2, inArg3), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    mapMap(inList, inMapFunc1, inMapFunc2, TO) -> TypedList{TO}

`inMapFunc2(inMapFunc1(e))` for each element.
"""
function mapMap(inList::List{T}, inMapFunc1::F1, inMapFunc2::F2, ::Type{TO})::TypedList{TO} where {T, F1<:Function, F2<:Function, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inMapFunc2(inMapFunc1(e)), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    map1_0(inList, inFunc, inArg1)

`inFunc(e, inArg1)` for each element, for its side effects.
"""
function map1_0(inList::List{T}, inFunc::F, inArg1::A1)::Nothing where {T, F<:Function, A1}
  for e::T in inList
    inFunc(e, inArg1)
  end
  return nothing
end

"""
    map1_2(inList, inFunc, inArg1, TO1, TO2) -> (TypedList{TO1}, TypedList{TO2})

The two results of `inFunc(e, inArg1)` for each element, as two lists.
"""
function map1_2(inList::List{T}, inFunc::F, inArg1::A1, ::Type{TO1}, ::Type{TO2})::Tuple{TypedList{TO1}, TypedList{TO2}} where {T, F<:Function, A1, TO1, TO2}
  local acc1::TypedList{TO1} = nil
  local acc2::TypedList{TO2} = nil
  for e::T in inList
    local e1::TO1
    local e2::TO2
    (e1, e2) = inFunc(e, inArg1)
    acc1 = Cons{TO1}(e1, acc1)
    acc2 = Cons{TO2}(e2, acc2)
  end
  return (_reverseTyped(TO1, acc1), _reverseTyped(TO2, acc2))
end

"""
    map2Option(inList, inFunc, inArg1, inArg2, TO) -> TypedList{TO}

`inFunc(e, inArg1, inArg2)` for each `SOME(e)`; `NONE()` elements are left out.
"""
function map2Option(inList::List{Option{TI}}, inFunc::F, inArg1::A1, inArg2::A2, ::Type{TO})::TypedList{TO} where {TI, F<:Function, A1, A2, TO}
  local acc::TypedList{TO} = nil
  for oe::Option{TI} in inList
    oe isa Some{TI} && (acc = Cons{TO}(inFunc(something(oe), inArg1, inArg2), acc))
  end
  return _reverseTyped(TO, acc)
end

"""
    mapFlat(inList, inMapFunc, TO) -> TypedList{TO}

The lists `inMapFunc(e)` joined, the last first (OpenModelica's `List.mapFlat`: the reverse of
`listAppend(inMapFunc(e_n), ... listAppend(inMapFunc(e_1), {}))`).
"""
function mapFlat(inList::List{T}, inMapFunc::F, ::Type{TO})::TypedList{TO} where {T, F<:Function, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = _copyOnto(TO, inMapFunc(e), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    mapList(inListList, inFunc, TO) -> TypedList{List{TO}}

`inFunc` applied to each element of each list. Example: `mapList({{1, 2}, {3}}, intString, String) => {{"1", "2"}, {"3"}}`.
"""
function mapList(inListList::List{L}, inFunc::F, ::Type{TO})::TypedList{List{TO}} where {L, F<:Function, TO}
  local acc::TypedList{List{TO}} = nil
  for lst::L in inListList
    acc = Cons{List{TO}}(map(lst, inFunc, TO), acc)
  end
  return _reverseTyped(List{TO}, acc)
end

"""
    map2List(inListList, inFunc, inArg1, inArg2, TO) -> TypedList{List{TO}}

`inFunc(e, inArg1, inArg2)` for each element of each list.
"""
function map2List(inListList::List{L}, inFunc::F, inArg1::A1, inArg2::A2, ::Type{TO})::TypedList{List{TO}} where {L, F<:Function, A1, A2, TO}
  local acc::TypedList{List{TO}} = nil
  for lst::L in inListList
    acc = Cons{List{TO}}(map2(lst, inFunc, inArg1, inArg2, TO), acc)
  end
  return _reverseTyped(List{TO}, acc)
end

"""
    mapAllValueBool(inList, inMapFunc, inValue) -> Bool

True if `inMapFunc(e)` equals `inValue` (`valueEq`) for every element and no call fails.
"""
function mapAllValueBool(inList::List{T}, inMapFunc::F, inValue::V)::Bool where {T, F<:Function, V}
  try
    for e::T in inList
      valueEq(inMapFunc(e), inValue) || return false
    end
  catch
    return false
  end
  return true
end

#= ---------------------------------------------------------------------------------------------------------------
   Folding
   --------------------------------------------------------------------------------------------------------------- =#

"""
    fold(inList, inFoldFunc, inStartValue, TO) -> TO

`inFoldFunc(e, acc)` over the elements, from `inStartValue`. Example: `fold({1, 2, 3}, intAdd, 2, Int) => 8`.
"""
function fold(inList::List{T}, inFoldFunc::F, inStartValue::TO, ::Type{TO})::TO where {T, F<:Function, TO}
  local out::TO = inStartValue
  for e::T in inList
    out = inFoldFunc(e, out)
  end
  return out
end

"""
    foldr(inList, inFoldFunc, inStartValue, TO) -> TO

As `fold`, with the arguments of `inFoldFunc` swapped: `inFoldFunc(acc, e)`.
"""
function foldr(inList::List{T}, inFoldFunc::F, inStartValue::TO, ::Type{TO})::TO where {T, F<:Function, TO}
  local out::TO = inStartValue
  for e::T in inList
    out = inFoldFunc(out, e)
  end
  return out
end

"""
    fold1(inList, inFoldFunc, inExtraArg, inStartValue, TO) -> TO

`inFoldFunc(e, inExtraArg, acc)` over the elements, from `inStartValue`.
"""
function fold1(inList::List{T}, inFoldFunc::F, inExtraArg::A1, inStartValue::TO, ::Type{TO})::TO where {T, F<:Function, A1, TO}
  local out::TO = inStartValue
  for e::T in inList
    out = inFoldFunc(e, inExtraArg, out)
  end
  return out
end

"""
    foldList1(inList, inFoldFunc, inExtraArg1, inStartValue, TO) -> TO

`fold1` over the elements of each list of `inList`.
"""
function foldList1(inList::List{L}, inFoldFunc::F, inExtraArg1::A1, inStartValue::TO, ::Type{TO})::TO where {L, F<:Function, A1, TO}
  local out::TO = inStartValue
  for lst::L in inList
    out = fold1(lst, inFoldFunc, inExtraArg1, out, TO)
  end
  return out
end

"""
    applyAndFold(inList, inFoldFunc, inApplyFunc, inFoldArg, TO) -> TO

`inFoldFunc(inApplyFunc(e), acc)` over the elements, from `inFoldArg`.
"""
function applyAndFold(inList::List{T}, inFoldFunc::F1, inApplyFunc::F2, inFoldArg::TO, ::Type{TO})::TO where {T, F1<:Function, F2<:Function, TO}
  local out::TO = inFoldArg
  for e::T in inList
    out = inFoldFunc(inApplyFunc(e), out)
  end
  return out
end

"""
    reduce(inList, inReduceFunc, TO) -> TO

`inReduceFunc` over the elements, left to right; fails for the empty list. Example: `reduce({1, 2, 3}, intAdd, Int) => 6`.
"""
function reduce(inList::Cons{T}, inReduceFunc::F, ::Type{TO})::TO where {T, F<:Function, TO}
  local out::TO = inList.head
  for e::T in inList.tail
    out = inReduceFunc(out, e)
  end
  return out
end
reduce(::Nil, ::F, ::Type{TO}) where {F<:Function, TO} = fail()

"""
    mapFold(inList, inFunc, inArg, TO, TA) -> (TypedList{TO}, TA)

`(e1, arg) = inFunc(e, arg)` for each element; the list of the `e1` and the last `arg`.
"""
function mapFold(inList::List{T}, inFunc::F, inArg::TA, ::Type{TO}, ::Type{TA})::Tuple{TypedList{TO}, TA} where {T, F<:Function, TO, TA}
  local arg::TA = inArg
  local acc::TypedList{TO} = nil
  for e::T in inList
    local res::TO
    (res, arg) = inFunc(e, arg)
    acc = Cons{TO}(res, acc)
  end
  return (_reverseTyped(TO, acc), arg)
end

"""
    mapFoldSO(inList, inFunc, inArg, TO) -> TypedList{TO}

`inFunc(e, inArg)` for each element (`mapFold` where the argument is not updated).
"""
function mapFoldSO(inList::List{T}, inFunc::F, inArg::A1, ::Type{TO})::TypedList{TO} where {T, F<:Function, A1, TO}
  local acc::TypedList{TO} = nil
  for e::T in inList
    acc = Cons{TO}(inFunc(e, inArg), acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    map1Fold(inList, inFunc, inConstArg, inArg, TO, TA) -> (TypedList{TO}, TA)

`(e1, arg) = inFunc(e, inConstArg, arg)` for each element; the list of the `e1` and the last `arg`.
"""
function map1Fold(inList::List{T}, inFunc::F, inConstArg::A1, inArg::TA, ::Type{TO}, ::Type{TA})::Tuple{TypedList{TO}, TA} where {T, F<:Function, A1, TO, TA}
  local arg::TA = inArg
  local acc::TypedList{TO} = nil
  for e::T in inList
    local res::TO
    (res, arg) = inFunc(e, inConstArg, arg)
    acc = Cons{TO}(res, acc)
  end
  return (_reverseTyped(TO, acc), arg)
end

"""
    map2FoldCheckReferenceEq(inList, inFunc, inConstArg, inConstArg2, inArg, TO, TA) -> (TypedList{TO}, TA)

`(e1, arg) = inFunc(e, inConstArg, inConstArg2, arg)` for each element. The list is `inList` itself, without
allocating, when every `e1` is the element it came from (`referenceEq`) and `inList` has `Cons{TO}` cells;
otherwise a new list.
"""
function map2FoldCheckReferenceEq(inList::List{T}, inFunc::F, inConstArg::A1, inConstArg2::A2, inArg::TA,
                                  ::Type{TO}, ::Type{TA})::Tuple{TypedList{TO}, TA} where {T, F<:Function, A1, A2, TO, TA}
  local arg::TA = inArg
  local acc::TypedList{TO} = nil
  local nEq::Int = 0
  local allEq::Bool = true
  for e::T in inList
    local res::TO
    (res, arg) = inFunc(e, inConstArg, inConstArg2, arg)
    if allEq
      if referenceEq(e, res)
        nEq += 1
        continue
      end
      allEq = false
      local k::Int = 0
      for x::T in inList
        k == nEq && break
        acc = Cons{TO}(x, acc)
        k += 1
      end
    end
    acc = Cons{TO}(res, acc)
  end
  allEq && return (_typed(TO, inList), arg)
  return (_reverseTyped(TO, acc), arg)
end

#= ---------------------------------------------------------------------------------------------------------------
   Joining lists
   --------------------------------------------------------------------------------------------------------------- =#

"""
    flatten(inList, TO) -> TypedList{TO}

The lists of `inList` joined. Example: `flatten({{1, 2}, {3, 4, 5}, {6}, {}}, Int) => {1, 2, 3, 4, 5, 6}`.
"""
function flatten(inList::List{L}, ::Type{TO})::TypedList{TO} where {L, TO}
  local acc::TypedList{TO} = nil
  for lst::L in inList
    acc = _reverseOnto(TO, lst, acc)
  end
  return _reverseTyped(TO, acc)
end

"""
    flattenReverse(inList, TO) -> TypedList{TO}

The lists of `inList` joined, the last first, each one in its own order (OpenModelica's `List.flattenReverse`).
"""
function flattenReverse(inList::List{L}, ::Type{TO})::TypedList{TO} where {L, TO}
  local acc::TypedList{TO} = nil
  for lst::L in inList
    acc = _copyOnto(TO, lst, acc)
  end
  return acc
end

"""
    threadTuple(inList1, inList2, TO) -> TypedList{TO}

The pairs of elements at the same position, up to the end of the shorter list; `TO` is the pair type.
Example: `threadTuple({1, 2}, {true, false}, Tuple{Int, Bool}) => {(1, true), (2, false)}`.
"""
function threadTuple(inList1::List{T1}, inList2::List{T2}, ::Type{TO})::TypedList{TO} where {T1, T2, TO<:Tuple}
  local acc::TypedList{TO} = nil
  local r1::Union{Nil, Cons{T1}} = inList1
  local r2::Union{Nil, Cons{T2}} = inList2
  while r1 isa Cons{T1} && r2 isa Cons{T2}
    acc = Cons{TO}((r1.head, r2.head), acc)
    r1 = r1.tail
    r2 = r2.tail
  end
  return _reverseTyped(TO, acc)
end

"""
    threadMapAllValue(inList1, inList2, inMapFunc, inValue)

Fails unless the lists have the same length and `inMapFunc(e1, e2)` equals `inValue` (`valueEq`) for every pair.
"""
function threadMapAllValue(inList1::List{T1}, inList2::List{T2}, inMapFunc::F, inValue::V)::Nothing where {T1, T2, F<:Function, V}
  local r1::Union{Nil, Cons{T1}} = inList1
  local r2::Union{Nil, Cons{T2}} = inList2
  while r1 isa Cons{T1} && r2 isa Cons{T2}
    valueEq(inMapFunc(r1.head, r2.head), inValue) || fail()
    r1 = r1.tail
    r2 = r2.tail
  end
  r1 isa Nil && r2 isa Nil || fail()
  return nothing
end

"""
    isEqualOnTrue(inList1, inList2, inCompFunc) -> Bool

True if the lists have the same length and `inCompFunc` holds for each pair of elements.
"""
function isEqualOnTrue(inList1::List{T1}, inList2::List{T2}, inCompFunc::F)::Bool where {T1, T2, F<:Function}
  local r1::Union{Nil, Cons{T1}} = inList1
  local r2::Union{Nil, Cons{T2}} = inList2
  while r1 isa Cons{T1} && r2 isa Cons{T2}
    inCompFunc(r1.head, r2.head) || return false
    r1 = r1.tail
    r2 = r2.tail
  end
  return r1 isa Nil && r2 isa Nil
end

#= ---------------------------------------------------------------------------------------------------------------
   Searching
   --------------------------------------------------------------------------------------------------------------- =#

""" True if `inFunc` holds for every element. """
function all(inList::List{T}, inFunc::F)::Bool where {T, F<:Function}
  for e::T in inList
    inFunc(e) || return false
  end
  return true
end

""" True if `inFindFunc` holds for an element. """
function exist(inList::List{T}, inFindFunc::F)::Bool where {T, F<:Function}
  for e::T in inList
    inFindFunc(e) && return true
  end
  return false
end

""" True if `inFindFunc(e, inExtraArg)` holds for an element. """
@inline function exist1(inList::List{T}, inFindFunc::F, inExtraArg::A1)::Bool where {T, F<:Function, A1}
  for e::T in inList
    inFindFunc(e, inExtraArg) && return true
  end
  return false
end

""" True if `inCompFunc(inValue, e)` holds for an element. """
@inline function isMemberOnTrue(inValue::V, inList::List{T}, inCompFunc::F)::Bool where {V, T, F<:Function}
  for e::T in inList
    inCompFunc(inValue, e) && return true
  end
  return false
end

""" The first element for which `inCompFunc(inValue, e)` holds; fails if there is none. """
@inline function getMemberOnTrue(inValue::V, inList::List{T}, inCompFunc::F)::T where {V, T, F<:Function}
  for e::T in inList
    inCompFunc(inValue, e) && return e
  end
  fail()
end

""" The first element for which `inFunc` holds; fails if there is none. """
function find(inList::List{T}, inFunc::F)::T where {T, F<:Function}
  for e::T in inList
    inFunc(e) && return e
  end
  fail()
end

""" The first element for which `inFunc(e, arg1)` holds; fails if there is none. """
@inline function find1(inList::List{T}, inFunc::F, arg1::A1)::T where {T, F<:Function, A1}
  for e::T in inList
    inFunc(e, arg1) && return e
  end
  fail()
end

""" `SOME` of the first element for which `pred_func` holds, `NONE()` if there is none. """
function findOption(lst::List{T}, pred_func::F)::Option{T} where {T, F<:Function}
  for e::T in lst
    pred_func(e) && return SOME(e)
  end
  return NONE()
end

""" The one-based position of the first element for which `inPredFunc` holds, -1 if there is none. """
function positionOnTrue(inList::List{T}, inPredFunc::F)::Int where {T, F<:Function}
  local pos::Int = 1
  for e::T in inList
    inPredFunc(e) && return pos
    pos += 1
  end
  return -1
end

#= ---------------------------------------------------------------------------------------------------------------
   Removing and replacing
   --------------------------------------------------------------------------------------------------------------- =#

"""
    deleteMemberOnTrue(inValue, inList, inCompareFunc, TO) -> (TypedList{TO}, Option{TO})

`inList` without the first element for which `inCompareFunc(inValue, e)` holds, and `SOME` of that element;
`(inList, NONE())` if there is none. Example: `deleteMemberOnTrue(2, {1, 2, 3, 2}, intEq, Int) => ({1, 3, 2}, SOME(2))`.
"""
function deleteMemberOnTrue(inValue::V, inList::List{T}, inCompareFunc::F, ::Type{TO})::Tuple{TypedList{TO}, Option{TO}} where {V, T, F<:Function, TO}
  local acc::TypedList{TO} = nil
  local cur::Union{Nil, Cons{T}} = inList
  while cur isa Cons{T}
    local e::T = cur.head
    cur = cur.tail
    inCompareFunc(inValue, e) && return (_reverseOnto(TO, acc, _typed(TO, cur)), SOME{TO}(e))
    acc = Cons{TO}(e, acc)
  end
  return (_typed(TO, inList), NONE())
end

"""
    replaceOnTrue(inReplacement, inList, inFunc, TO) -> (TypedList{TO}, Bool)

`inList` with the first element for which `inFunc` holds replaced by `inReplacement`, and whether one was.
Example: `replaceOnTrue(4, {1, 2, 3}, isTwo, Int) => ({1, 4, 3}, true)`.
"""
function replaceOnTrue(inReplacement::TO, inList::List{T}, inFunc::F, ::Type{TO})::Tuple{TypedList{TO}, Bool} where {TO, T, F<:Function}
  local acc::TypedList{TO} = nil
  local cur::Union{Nil, Cons{T}} = inList
  while cur isa Cons{T}
    local e::T = cur.head
    cur = cur.tail
    inFunc(e) && return (_reverseOnto(TO, acc, Cons{TO}(inReplacement, _typed(TO, cur))), true)
    acc = Cons{TO}(e, acc)
  end
  return (_typed(TO, inList), false)
end

#= ---------------------------------------------------------------------------------------------------------------
   Strings
   --------------------------------------------------------------------------------------------------------------- =#

"""
    toString(inList, inPrintFunc, inListNameStr, inBeginStr, inDelimitStr, inEndStr, inPrintEmpty) -> String

`inListNameStr`, `inBeginStr`, the elements printed with `inPrintFunc` separated by `inDelimitStr`, and `inEndStr`.
An empty list gives `inListNameStr * inBeginStr * inEndStr`, or only `inListNameStr` if `inPrintEmpty` is false.
Example: `toString({1, 2, 3}, intString, "nums", "{", ";", "}", true) => "nums{1;2;3}"`.
"""
function toString(inList::List{T}, inPrintFunc::F, inListNameStr::String, inBeginStr::String, inDelimitStr::String,
                  inEndStr::String, inPrintEmpty::Bool)::String where {T, F<:Function}
  inList isa Nil && return inPrintEmpty ? inListNameStr * inBeginStr * inEndStr : inListNameStr
  local io::IOBuffer = IOBuffer()
  write(io, inListNameStr)
  write(io, inBeginStr)
  local firstElement::Bool = true
  for e::T in inList
    firstElement || write(io, inDelimitStr)
    write(io, inPrintFunc(e)::String)
    firstElement = false
  end
  write(io, inEndStr)
  return String(take!(io))
end

@exportAll()
end
