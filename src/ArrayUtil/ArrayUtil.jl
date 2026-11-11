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

module ArrayUtil

using MetaModelica
#= ExportAll is not good practice but it makes it so that we do not have to write export after each function :( =#
using ExportAll
using MetaModelica.Dangerous: arrayGetNoBoundsChecking, arrayUpdateNoBoundsChecking, arrayCreateNoInit

""" Takes an array and a function over the elements of the array, which is
applied for each element.  Since it will update the array values the returned
array must have the same type, and thus the applied function must also return
the same type. """
function mapNoCopy(inArray::Vector{T}, inFunc::F) where {T, F<:Function}
  local outArray::Vector{T} = inArray
  for i in 1:arrayLength(inArray)
    arrayUpdate(inArray, i, inFunc(arrayGetNoBoundsChecking(inArray, i)))
  end
  outArray
end

""" Same as arrayMapNoCopy, but with an additional arguments that's updated for
each call. """
function mapNoCopy_1(inArray::Vector{T}, inFunc::F, inArg::ArgT) where {T, ArgT, F<:Function}
  local outArg = inArg
  local outArray::Vector{T} = inArray
  local e::T
  for i in 1:arrayLength(inArray)
    (e, outArg) = inFunc((arrayGetNoBoundsChecking(inArray, i), outArg))
    arrayUpdate(inArray, i, e)
  end
  (outArray, outArg)
end

function downheap(inArray::Array{<:ModelicaInteger}, n::ModelicaInteger, vIn::ModelicaInteger) ::Array{ModelicaInteger}
  local v::ModelicaInteger = vIn
  local w::ModelicaInteger = 2 * v + 1
  local tmp::ModelicaInteger
  while w < n
    if w + 1 < n
      if inArray[w + 2] > inArray[w + 1]
        w = w + 1
      end
    end
    if inArray[v + 1] >= inArray[w + 1]
      return inArray
    end
    tmp = inArray[v + 1]
    inArray[v + 1] = inArray[w + 1]
    inArray[w + 1] = tmp
    v = w
    w = 2 * v + 1
  end
  inArray
end

function heapSort(inArray::Array{<:ModelicaInteger}) ::Array{ModelicaInteger}
  local n::ModelicaInteger = arrayLength(inArray)
  local tmp::ModelicaInteger
  for v in intDiv(n, 2) - 1:(-1):0
    inArray = downheap(inArray, n, v)
  end
  for v in n:(-1):2
    tmp = inArray[1]
    inArray[1] = inArray[v]
    inArray[v] = tmp
    inArray = downheap(inArray, v - 1, 0)
  end
  inArray
end

function findFirstOnTrue(inArray::Vector{T}, inPredicate::F) where {T, F<:Function}
  local outElement::Option{T}

  outElement = NONE()
  for e in inArray
    if inPredicate(e)
      outElement = SOME(e)
      break
    end
  end
  outElement
end

function findFirstOnTrueWithIdx(inArray::Vector{T}, inPredicate::F) where {T, F<:Function}
  local idxOut::ModelicaInteger = -1
  local outElement::Option{T}
  local idx::ModelicaInteger = 1
  outElement = NONE()
  for e in inArray
    if inPredicate(e)
      idxOut = idx
      outElement = SOME(e)
      break
    end
    idx = idx + 1
  end
  (outElement, idxOut)
end

""" Takes an array and a list of indices, and returns a new array with the
indexed elements. Will fail if any index is out of bounds. """
function select(inArray::Vector{T}, inIndices::List)  where {T}
  local outArray::Vector{T}
  local i::ModelicaInteger = 1
  outArray = arrayCreateNoInit(listLength(inIndices), inArray[1])
  for e in inIndices
    arrayUpdate(outArray, i, arrayGet(inArray, e))
    i = i + 1
  end
  outArray
end

"""
Takes an array and a function over the elements of the array, which is
applied to each element. The updated elements will form a new array, leaving
the original array unchanged.
"""
function map(inArray::Vector{TI}, inFunc::F) where {TI, F<:Function}
  local len = arrayLength(inArray)
  if len == 0
    return Any[]
  end
  # Base.map widens the element type at runtime; preallocating from the first
  # result's concrete type fails when later results are other records of the
  # same uniontype.
  local out = Base.map(inFunc, inArray)
  # An array of lists keeps the abstract eltype: rows mutate between Cons and
  # Nil in place downstream.
  if eltype(out) !== List && eltype(out) <: List
    return convert(Vector{List}, out)
  end
  return out
end

""" Takes an array, an extra arguments, and a function over the elements of the
array, which is applied to each element. The updated elements will form a new
array, leaving the original array unchanged. """
function map1(inArray::Vector{TI}, inFunc::F, inArg::ArgT) where {TI, ArgT, F<:Function}
  local len::ModelicaInteger = arrayLength(inArray)
  if len == 0
    return listArray(nil)
  end
  # Base.map widens the element type at runtime (see map).
  return Base.map(e -> inFunc(e, inArg), inArray)
end

""" Applies a non-returning function to all elements in an array. """
function map0(inArray::Vector{T}, inFunc::F) where {T, F<:Function}
  for e in inArray
    inFunc(e)
  end
end

""" As map, but takes a list in and creates an array from the result. """
function mapList(inList::List{TI}, inFunc::F) where {TI, F<:Function}
  if listEmpty(inList)
    return []
  end
  # collect widens the element type at runtime (see map).
  return Base.collect(inFunc(e) for e in inList)
end

"""
Takes a vector, an extra argument and a function. The function will be applied
to each element in the list, and the extra argument will be passed to the
function and updated.
"""
function mapFold(inArray::Vector{T}, inFunc::F, inArg::FT) where {T, FT, F<:Function}
  local outArg = inArg
  local outArr = Vector{T}(undef, length(inArray))
  for (i,e) in enumerate(inArray)
    (res, outArg) = inFunc(e, outArg)
    outArr[i] = res
  end
  return (outArr, outArg)
end

"""
```mapFoldSO``
  Same as map fold. Applies the function to the map, however, it does not return the extra argument.
"""
function mapFoldSO(inArray::Vector{T}, inFunc::F, inArg::FT) where {T, FT, F<:Function}
  local outArg::FT = inArg
  local outArr = Vector{T}(undef, length(inArray))
  for (i,e) in enumerate(inArray)
    res = inFunc(e, outArg)
    outArr[i] = res
  end
  return outArr
end

function mapFoldRef(inArray::Vector{T}, inFunc::F, inArg::FT, outRefArg::Ref{FT}) where {T, FT, F<:Function}
  local outArg::FT = inArg
  local outArr = Vector{T}(undef, length(inArray))
  for (i,e) in enumerate(inArray)
    res = inFunc(e, outRefArg)
    outArr[i] = res
  end
  return outArr
end



"""
```
map1Fold
```
Takes a Vector, an extra argument, an extra constant argument, and a function.
The function will be applied to each element in the list, and the extra
argument will be passed to the function and updated.
"""
function map1Fold(inVec::Vector{TI}, inFunc::F, inConstArg::ArgT1, inArg, TY = Any) where {TI, ArgT1, F<:Function}
  local outArg = inArg
  local outVec::Vector{TY} = Vector{TY}()
  local res::Any
  for e in inVec
    (res, outArg) = inFunc(e, inConstArg, outArg)
    outVec = push!(outVec, res)
  end
  return outVec, outArg
end

""" Applies a function to only the elements given by the sorted list of indices. """
function mapIndices(inList::Vector{T}, indices::Vector{Int}, func::F) where {T, F<:Function}
  local outList::Vector{T} = T[i for i in inList]
  if isempty(indices)
    return outList
  end
  for index in indices
    outList[index] = func(inList[index])
  end
  return outList
end


"""
Applies a function to only the elements given by the sorted list of indices.
inline variant of ```mapIndices```
"""
function mapIndices!(inList::Vector{T}, indices::Vector{Int}, func::F) where {T, F<:Function}
  if isempty(indices)
    return inList
  end
  for index in indices
    inList[index] = func(inList[index])
  end
  return inList
end



""" Takes an array, a function, and a start value. The function is applied to
each array element, and the start value is passed to the function and
updated. """
function fold(inArray::Vector{T},
              inFunction::F,
              inStartValue) where {T, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, outResult)
  end
  outResult
end

# Fold accumulators stay untyped here and in foldIndex, mapFold and mapNoCopy_1: a
# start value such as nil is narrower than the declared fold type the callback returns.
""" Takes an array, a function, and a start value. The function is applied to
each array element, and the start value is passed to the function and
updated. """
function fold1(inArray::Vector{T}, inFunction::F, inArg::ArgT, inStartValue::FoldT) where {T, FoldT, ArgT, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg, outResult)
  end
  outResult
end

""" Takes an array, a function, a constant parameter, and a start value. The
function is applied to each array element, and the start value is passed to
the function and updated. """
function fold2(inArray::Vector{T}, inFunction::F, inArg1::ArgT1, inArg2::ArgT2, inStartValue::FoldT) where {T, FoldT, ArgT1, ArgT2, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg1, inArg2, outResult)
  end
  outResult
end

""" Takes an array, a function, a constant parameter, and a start value. The
function is applied to each array element, and the start value is passed to
the function and updated. """
function fold3(inArray::Vector{T}, inFunction::F, inArg1::ArgT1, inArg2::ArgT2, inArg3::ArgT3, inStartValue::FoldT) where {T, FoldT, ArgT1, ArgT2, ArgT3, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg1, inArg2, inArg3, outResult)
  end
  outResult
end

""" Takes an array, a function, four constant parameters, and a start value. The
function is applied to each array element, and the start value is passed to
the function and updated. """
function fold4(inArray::Vector{T}, inFunction::F, inArg1::ArgT1, inArg2::ArgT2, inArg3::ArgT3, inArg4::ArgT4, inStartValue::FoldT) where {T, FoldT, ArgT1, ArgT2, ArgT3, ArgT4, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg1, inArg2, inArg3, inArg4, outResult)
  end
  outResult
end

""" Takes an array, a function, four constant parameters, and a start value. The
function is applied to each array element, and the start value is passed to
the function and updated. """
function fold5(inArray::Vector{T}, inFunction::F, inArg1::ArgT1, inArg2::ArgT2, inArg3::ArgT3, inArg4::ArgT4, inArg5::ArgT5, inStartValue::FoldT) where {T, FoldT, ArgT1, ArgT2, ArgT3, ArgT4, ArgT5, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg1, inArg2, inArg3, inArg4, inArg5, outResult)
  end
  outResult
end

""" Takes an array, a function, four constant parameters, and a start value. The
function is applied to each array element, and the start value is passed to
the function and updated. """
function fold6(inArray::Vector{T}, inFunction::F, inArg1::ArgT1, inArg2::ArgT2, inArg3::ArgT3, inArg4::ArgT4, inArg5::ArgT5, inArg6::ArgT6, inStartValue::FoldT) where {T, FoldT, ArgT1, ArgT2, ArgT3, ArgT4, ArgT5, ArgT6, F<:Function}
  local outResult = inStartValue
  for e in inArray
    outResult = inFunction(e, inArg1, inArg2, inArg3, inArg4, inArg5, inArg6, outResult)
  end
  outResult
end

""" Takes an array, a function, and a start value. The function is applied to
each array element, and the start value is passed to the function and
updated, additional the index of the passed element is also passed to the function. """
function foldIndex(inArray::Vector{T}, inFunction::F, inStartValue::FoldT) where {T, FoldT, F<:Function}
  local outResult = inStartValue
  local e::T
  for i in 1:arrayLength(inArray)
    e = arrayGet(inArray, i)
    outResult = inFunction(e, i, outResult)
  end
  outResult
end

""" Takes a list and a function operating on two elements of the array.
The function performs a reduction of the array to a single value using the
function. Example:
reduce([1, 2, 3], intAdd) => 6 """
function reduce(inArray::Vector{T}, inFunction::F) where {T, F<:Function}
  local outResult::T
  local rest::List{T}
  outResult = arrayGet(inArray, 1)
  for i in 2:arrayLength(inArray)
    outResult = inFunction(outResult, arrayGet(inArray, i))
  end
  outResult
end

""" Like arrayUpdate, but with the index first so it can be used with List.map. """
function updateIndexFirst(inIndex::ModelicaInteger, inValue, inArray::Vector)
  arrayUpdate(inArray, inIndex, inValue)
end

""" Like arrayGet, but with the index first so it can used with List.map. """
function getIndexFirst(inIndex::ModelicaInteger, inArray::Vector)
  local outElement = arrayGet(inArray, inIndex)
  outElement
end

""" Replaces the element with the given index in the second array with the value
of the corresponding element in the first array. """
function updatewithArrayIndexFirst(inIndex::ModelicaInteger, inArraySrc::Vector{T}, inArrayDest::Vector{T})  where {T}
  arrayUpdate(inArrayDest, inIndex, inArraySrc[inIndex])
end

function updatewithListIndexFirst(inList::List{ModelicaInteger}, inStartIndex::ModelicaInteger, inArraySrc::Vector{T}, inArrayDest::Vector{T})  where {T}
  for i in inStartIndex:inStartIndex + listLength(inList) - 1
    arrayUpdate(inArrayDest, i, inArraySrc[i])
  end
end

function updateElementListAppend(inIndex::ModelicaInteger, inValue::List{T}, inArray::Array{List{T}})  where {T}
  arrayUpdate(inArray, inIndex, listAppend(inArray[inIndex], inValue))
end

""" Takes
- an element,
- a position (1..n)
- an array and
- a fill value
The function replaces the value at the given position in the array, if the
given position is out of range, the fill value is used to padd the array up
to that element position and then insert the value at the position.

Example:
replaceAtWithFill('A', 5, {'a', 'b', 'c'}, 'dummy') => {'a', 'b', 'c', 'dummy', 'A'} """
function replaceAtWithFill(inPos::ModelicaInteger, inTypeReplace::T, inTypeFill::T, inArray::Vector{T})  where {T}
  local outArray::Vector{T}

  outArray = expandToSize(inPos, inArray, inTypeFill)
  arrayUpdate(outArray, inPos, inTypeReplace)
  outArray
end

""" Expands an array to the given size, or does nothing if the array is already
large enough. """
function expandToSize(inNewSize::ModelicaInteger, inArray::Vector, inFill)
  local outArray::Vector
  if inNewSize <= arrayLength(inArray)
    outArray = inArray
  else
    outArray = Vector{Base.typejoin(eltype(inArray), typeof(inFill))}(undef, inNewSize)
    fill!(outArray, inFill)
    copyto!(outArray, 1, inArray, 1, arrayLength(inArray))
  end
  outArray
end

""" Increases the number of elements of an array with inN. Each new element is
assigned the value inFill. """
function expand(inN::ModelicaInteger, inArray::Vector, inFill)
  local outArray::Vector
  local len::ModelicaInteger
  if inN < 1
    outArray = inArray
  else
    len = arrayLength(inArray)
    outArray = Vector{Base.typejoin(eltype(inArray), typeof(inFill))}(undef, len + inN)
    copyto!(outArray, 1, inArray, 1, len)
    setRange(len + 1, len + inN, outArray, inFill)
  end
  outArray
end

""" Resizes an array with the given factor if the array is smaller than the
requested size. """
function expandOnDemand(inNewSize::ModelicaInteger #= The number of elements that should fit in the array. =#, inArray::Vector{T} #= The array to resize. =#, inExpansionFactor::ModelicaReal #= The factor to resize the array with. =#, inFillValue::T #= The value to fill the new part of the array. =#)  where {T}
  local outArray::Vector{T} #= The resulting array. =#

  local new_size::ModelicaInteger
  local len::ModelicaInteger = arrayLength(inArray)

  if inNewSize <= len
    outArray = inArray
  else
    # The grown size must actually FIT the request; the factor alone undersizes
    # small arrays (len 0-2) and the caller then writes out of bounds.
    new_size = max(realInt(intReal(len) * inExpansionFactor), inNewSize)
    outArray = Vector{T}(undef, new_size)
    copyto!(outArray, 1, inArray, 1, len)
    setRange(len + 1, new_size, outArray, inFillValue)
  end
  outArray #= The resulting array. =#
end

""" Concatenates an element to a list element of an array. The array may be typed
Vector{List} (untyped element lists); do not constrain the element to the list type. """
function consToElement(inIndex::ModelicaInteger, inElement, inArray::Array{<:List})
  outArray = arrayUpdate(inArray, inIndex, inElement <| inArray[inIndex])
  outArray
end

""" Appends a list to a list element of an array. """
function appendToElement(inIndex::ModelicaInteger, inElements::List, inArray::Array)
  local outArray::Array
  outArray = arrayUpdate(inArray, inIndex, listAppend(inArray[inIndex], inElements))
  outArray
end

""" Returns a new array with the list elements added to the end of the given array. """
function appendList(arr::Vector{T}, lst::List{T})  where {T}
  local outArray::Vector{T}
  local arr_len::ModelicaInteger = arrayLength(arr)
  local lst_len::ModelicaInteger
  local e::T
  local rest::List{T}
  if listEmpty(lst)
    outArray = arr
  elseif arr_len == 0
    outArray = listArray(lst)
  else
    lst_len = listLength(lst)
    outArray = arrayCreateNoInit(arr_len + lst_len, arr[1])
    copy(arr, outArray)
    rest = lst
    for i in arr_len + 1:arr_len + lst_len
      @match e <| rest = rest
      arrayUpdateNoBoundsChecking(outArray, i, e)
    end
  end
  outArray
end

"""
 Returns the input array with the list elements added to the end of the given array.
@author:johti17
"""
function appendList!(arr::Vector{T}, lst::Cons{T}) where {T}
  local outArray::Vector{T}
  local arr_len::ModelicaInteger = length(arr)
  local e::T
  if arr_len == 0
    arr = listArray(lst)
  else
    local lstLen::Int = length(lst)
    resize!(arr, (arr_len + lstLen))
    local i::Int = 1
    for e in lst
      arr[i + arr_len] = e
      i += 1
    end
  end
  arr
end

function appendList!(arr::Vector{T}, lst::Nil) where {T}
  return arr
end

"""
Returns true if the given predicate function returns true for all elements in
the given Vector.
"""
function all(inList::Vector{T}, inFunc::F) where {T, F<:Function}
  local outResult::Bool = false
  for e in inList
    if ! inFunc(e)
      outResult = false
      return outResult
    end
  end
  outResult = true
  return outResult
end

"""
Returns true if the given predicate function returns true for any element in
the given Vector.
"""
function any(inArray::Vector{T}, inFunc::F) where {T, F<:Function}
  local outResult::Bool = false
  for e in inArray
    if inFunc(e)
      outResult = true
      return outResult
    end
  end
  return outResult
end


""" Copies all values from inArraySrc to inArrayDest. Fails if inArraySrc is
larger than inArrayDest.

NOTE: There's also a builtin arrayCopy operator that should be used if the
purpose is only to duplicate an array. """
function copy(inArraySrc::Vector{T}, inArrayDest::Vector{T})  where {T}
  local outArray::Vector{T} = inArrayDest

  if arrayLength(inArraySrc) > arrayLength(inArrayDest)
    fail()
  end
  for i in 1:arrayLength(inArraySrc)
    arrayUpdateNoBoundsChecking(outArray, i, arrayGetNoBoundsChecking(inArraySrc, i))
  end
  outArray
end

""" Copies the first inN values from inArraySrc to inArrayDest. Fails if
inN is larger than either inArraySrc or inArrayDest. """
function copyN(inArraySrc::Vector{T}, inArrayDest::Vector{T}, inN::ModelicaInteger)  where {T}
  local outArray::Vector{T} = inArrayDest
  if inN > arrayLength(inArrayDest) || inN > arrayLength(inArraySrc)
    fail()
  end
  for i in 1:inN
    arrayUpdateNoBoundsChecking(outArray, i, arrayGetNoBoundsChecking(inArraySrc, i))
  end
  outArray
end

""" Copies a range of elements from one array to another. """
function copyRange(srcArray::Vector{T} #= The array to copy from. =#, dstArray::Vector{T} #= The array to insert into. =#, srcFirst::ModelicaInteger #= The index of the first element to copy. =#, srcLast::ModelicaInteger #= The index of the last element to copy. =#, dstPos::ModelicaInteger #= The index to begin inserting at. =#)  where {T}
  local offset::ModelicaInteger = dstPos - srcFirst
  if srcFirst > srcLast || srcLast > arrayLength(srcArray) || offset + srcLast > arrayLength(dstArray)
    fail()
  end
  for i in srcFirst:srcLast
    arrayUpdateNoBoundsChecking(dstArray, offset + i, arrayGetNoBoundsChecking(srcArray, i))
  end
end

""" Creates an array<Integer> of size inLen with the values set to the range of 1:inLen. """
function createIntRange(inLen::ModelicaInteger) ::Array{ModelicaInteger}
  local outArray::Array{ModelicaInteger}
  outArray = arrayCreateNoInit(inLen, 0)
  for i in 1:inLen
    arrayUpdateNoBoundsChecking(outArray, i, i)
  end
  outArray
end

""" Sets the elements in positions inStart to inEnd to inValue. """
function setRange(inStart::ModelicaInteger, inEnd::ModelicaInteger, inArray::Vector{T}, inValue::T)  where {T}
  local outArray::Vector{T} = inArray
  if inStart > arrayLength(inArray)
    fail()
  end
  for i in inStart:inEnd
    arrayUpdate(inArray, i, inValue)
  end
  outArray
end

""" Gets the elements between inStart and inEnd. """
function getRange(inStart::ModelicaInteger, inEnd::ModelicaInteger, inArray::Vector{T})  where {T}
  local outList::List{T} = nil
  local value::T
  if inStart > arrayLength(inArray)
    fail()
  end
  for i in inStart:inEnd
    value = arrayGet(inArray, i)
    outList = value <| outList
  end
  outList
end

""" Returns the index of the given element in the array, or 0 if it wasn't found. """
function position(inArray::Vector{T}, inElement::T, inFilledSize::ModelicaInteger = arrayLength(inArray) #= The filled size of the array. =#)  where {T}
  local outIndex::ModelicaInteger
  local e::T
  for i in 1:inFilledSize
    if valueEq(inElement, inArray[i])
      outIndex = i
      return outIndex
    end
  end
  outIndex = 0
  outIndex
end

""" Takes a value and returns the first element for which the comparison
function returns true, along with that elements position in the array. """
function getMemberOnTrue(inValue::VT, inArray::Array{ET}, inFunction::F) where {VT, ET, F<:Function}
  local outIndex::ModelicaInteger
  local outElement::ET
  for i in 1:arrayLength(inArray)
    if inFunction(inValue, arrayGetNoBoundsChecking(inArray, i))
      outElement = arrayGetNoBoundsChecking(inArray, i)
      outIndex = i
      return (outElement, outIndex)
    end
  end
  fail()
  (outElement, outIndex)
end

""" reverses the elements in an array """
function reverse(inArray::Vector{T})  where {T}
  local outArray::Vector{T}
  local size::ModelicaInteger
  local i::ModelicaInteger
  local elem1::T
  local elem2::T
  outArray = inArray
  size = arrayLength(inArray)
  for i in 1:div(size, 2)
    elem1 = arrayGet(inArray, i)
    elem2 = arrayGet(inArray, size - i + 1)
    outArray = arrayUpdate(outArray, i, elem2)
    outArray = arrayUpdate(outArray, size - i + 1, elem1)
  end
  outArray
end

""" output true if all lists in the array are empty """
function arrayListsEmpty(arr::Array{List{T}})  where {T}
  local isEmpty::Bool
  isEmpty = fold(arr, arrayListsEmpty1, true)
  isEmpty
end

function arrayListsEmpty1(lst::List{T}, isEmptyIn::Bool)  where {T}
  local isEmptyOut::Bool
  isEmptyOut = listEmpty(lst) && isEmptyIn
  isEmptyOut
end

""" Checks if two arrays are equal. """
function isEqual(inArr1::Vector{T}, inArr2::Vector{T})  where {T}
  local outIsEqual::Bool = true
  local arrLength::ModelicaInteger
  arrLength = arrayLength(inArr1)
  if ! intEq(arrLength, arrayLength(inArr2))
    fail()
  end
  for i in 1:arrLength
    if ! valueEq(inArr1[i], inArr2[i])
      outIsEqual = false
      break
    end
  end
  outIsEqual
end

""" Returns true if a certain element exists in the given array as indicated by
the given predicate function. """
function exist(arr::Vector{T}, pred::F) where {T, F<:Function}
  local exists::Bool
  for e in arr
    if pred(e)
      exists = true
      return exists
    end
  end
  exists = false
  exists
end

function insertList(arr::Vector{T}, lst::List{T}, startPos::ModelicaInteger)  where {T}
  local i::ModelicaInteger = startPos
  for e in lst
    arr[i] = e
    i = i + 1
  end
  arr
end

"""
Goes through an Array and removes all elements which are equal to the given
value, using the given comparison function.
@author:johti17
"""
function removeOnTrue(val::T, compFunc::F, arr::Vector{T0}) where {T, T0, F<:Function}
  [i for i in arr if ! compFunc(val, i)]
end

"""
Takes a list and a position, and splits the list at the position given.
Example:
```
julia> split([1, 2, 5, 7], 2) => ([1, 2], [5, 7])
```
"""
function split(inArr::Vector{T},  inPosition::Int) where {T}
  local outArr1 = T[]
  local outArr2 = T[]
  local pos::Int
  local a1 = T[]
  local a2 = Base.copy(inArr)
  local e::T
  @match true = inPosition >= 0
  pos = inPosition
  for i in 1:pos
    e = popfirst!(a2)
    push!(a1, e)
  end
  outArr1 = a1
  outArr2 = a2
  return (outArr1, outArr2)
end

"""
function partition(inList::Vector{T}, inPartitionLength::Int) where {T}
Partitions a vector of elements into sublists of length n.
Example:
```
julia> partition([1, 2, 3, 4, 5], 2) => [[1, 2], [3, 4], [5]]
```
"""
function partition(inV::Vector{T}, inPartitionLength::ModelicaInteger)  where {T}
  @match true = inPartitionLength > 0
  local vLength = length(inV)
  outPartitions::Vector{Vector{T}} = Vector{T}[]
  if vLength == 0
    return Vector{T}[]#outPartitions
  elseif inPartitionLength >= vLength
    return Vector{T}[inV]
  end #Else proceed
  #=
  Declare local vars
  =#
  local vWork::Vector = inV
  for i in 1:div(vLength, inPartitionLength)
    (part, vWork) = split(vWork, inPartitionLength)
    push!(outPartitions, part)
  end
  #= And the remainder =#
  if ! isempty(vWork)
    push!(outPartitions, vWork)
  end
  return outPartitions
end

"""
Fills an array with inElement inCount times.
"""
function fill(inElement::T, inCount::Int) where {T}
  return Base.fill(inElement, inCount)
end

"""
Transposes a vector of vectors
Example:
```
julia:> transposeArray([[1, 2, 3], [4, 5, 6]])
3-element Vector{Vector{Int64}}:
 [1, 4]
 [2, 5]
 [3, 6]
```
"""
function transposeArray(arr::Vector{Vector{T}}) where {T}
  local N = length(arr)
  local M = length(arr[1])
  local outArr = Vector{Vector{T}}(undef, M)
  for i in 1:M
    col = Vector{T}(undef, N)
    local cntr = 0
    for j in 1:N
      col[j] = arr[j][i]
    end
    outArr[i] = col
  end
  return outArr
end

"""
  Converts an array of type T into string representation.
"""
function toString(arr::Vector{T},
                  toStringFunc::F,
                  pathString::String,
                  beginStr::String,
                  delimiter::String,
                  endStr::String,
                  printBeginEndIfEmpty::Bool) where {T, F<:Function}
  local buffer = IOBuffer()
  if isempty(arr) && printBeginEndIfEmpty
    print(buffer, pathString)
    print(buffer, beginStr)
    print(buffer, endStr)
  elseif isempty(arr)
    print(buffer, pathString)
  else
    print(buffer, pathString)
    print(buffer, beginStr)
    local len = length(arr)
    for i in 1:len
      local e::T = arr[i]
      print(buffer, toStringFunc(e))
      if i != len
        print(buffer, delimiter)
      end
    end
    print(buffer, endStr)
  end
  return String(take!(buffer))
end

function allEqual(vec::Vector, fun::F) where {F<:Function}
  for e1 in vec
    for e2 in vec
      fun(e1, e2) || return false
    end
  end
  return true
end

"""
    compare(arr1, arr2, comp_func) -> Int

Compare two arrays element-wise using `comp_func(e1, e2)` which must return
an integer (-1, 0, or 1). Returns the result of the first non-zero comparison,
or compares array lengths if all corresponding elements are equal.
"""
function compare(arr1::Vector, arr2::Vector, comp_func)
  local n = min(length(arr1), length(arr2))
  for i in 1:n
    local c = comp_func(arr1[i], arr2[i])
    if c != 0
      return c
    end
  end
  return length(arr1) < length(arr2) ? -1 : (length(arr1) > length(arr2) ? 1 : 0)
end

"""
    generate(n, gen_func) -> Vector

Generate a vector of `n` elements by calling `gen_func(i)` for `i` in `1:n`.
"""
function generate(n::Int, gen_func)
  return [gen_func(i) for i in 1:n]
end

"""
    isEqualOnTrue(arr1, arr2, eq_func) -> Bool

Return true if `arr1` and `arr2` have the same length and `eq_func(arr1[i], arr2[i])`
returns true for all corresponding pairs.
"""
function isEqualOnTrue(arr1::Vector, arr2::Vector, eq_func)
  if length(arr1) != length(arr2)
    return false
  end
  for i in 1:length(arr1)
    if !eq_func(arr1[i], arr2[i])
      return false
    end
  end
  return true
end

"""
    mapBoolAnd(arr, pred_func) -> Bool

Apply `pred_func` to each element of `arr`; return true only if all
applications return true (logical AND over mapped results).
"""
function mapBoolAnd(arr::Vector, pred_func)
  for e in arr
    if !pred_func(e)
      return false
    end
  end
  return true
end

"""
    threadMap(arr1, arr2, map_func) -> Vector

Apply `map_func(arr1[i], arr2[i])` for each index, returning a new vector
of the results. Both input arrays must have the same length.
"""
function threadMap(arr1::Vector, arr2::Vector, map_func)
  local n = length(arr1)
  local result = Vector{Any}(undef, n)
  for i in 1:n
    result[i] = map_func(arr1[i], arr2[i])
  end
  return result
end

"""
    transpose(arr::Vector{Vector{T}}) -> Vector{Vector{T}}

Transpose a vector of vectors (matrix in row-major form).
Returns a new vector of vectors where rows become columns and vice versa.

Example: `transpose([[1,2,3], [4,5,6]])` returns `[[1,4], [2,5], [3,6]]`.
"""
function transpose(arr::Vector{Vector{T}}) where {T}
  if isempty(arr)
    return Vector{Vector{T}}()
  end
  local nrows = length(arr)
  local ncols = length(arr[1])
  local result = Vector{Vector{T}}(undef, ncols)
  for j in 1:ncols
    local col = Vector{T}(undef, nrows)
    for i in 1:nrows
      col[i] = arr[i][j]
    end
    result[j] = col
  end
  return result
end

#= So that we can use wildcard imports and named imports when they do occur. Not good Julia practice =#
@exportAll()
end
