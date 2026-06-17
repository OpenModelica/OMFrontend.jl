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

module DiffAlgorithm

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

FunEquals = Function
FunWhitespace = Function
ToString = Function
partialPrintDiff = Function

FunEquals = Function
FunWhitespace = Function
ToString = Function

FunEquals = Function
FunWhitespace = Function
ToString = Function

FunEquals = Function
FunWhitespace = Function
ToString = Function

FunEquals = Function

FunEquals = Function

FunEquals = Function

import Frontend.Print

import ListUtil
import Frontend.System

Diff = (() -> begin #= Enumeration =#
  Add = 1
  Delete = 2
  Equal = 3
  () -> (Add; Delete; Equal)
end)()

function diff(
  seq1::List{T},
  seq2::List{T},
  equals::FunEquals,
  isWhitespace::FunWhitespace,
  toString::ToString,
) where {T}
  local out::List{Tuple{Diff, List{T}}}

  local start1::Int
  local end1::Int
  local start2::Int
  local end2::Int
  local len1::Int
  local len2::Int
  local arr1::Array{T}
  local arr2::Array{T}

  @assign arr1 = listArray(seq1)
  @assign arr2 = listArray(seq2)
  @assign start1 = 1
  @assign start2 = 1
  @assign end1 = arrayLength(arr1)
  @assign end2 = arrayLength(arr2)
  @assign out =
    diffSeq(arr1, arr2, equals, isWhitespace, toString, start1, end1, start2, end2)
  return out
end

function printDiffTerminalColor() end

function printDiffXml() end

function printActual() end

function diffSeq(
  arr1::Array{T},
  arr2::Array{T},
  equals::FunEquals,
  isWhitespace::FunWhitespace,
  toString::ToString,
  inStart1::Int,
  inEnd1::Int,
  inStart2::Int,
  inEnd2::Int,
  inPrefixes::List{Tuple{Diff, List{T}}} = nil,
  inSuffixes::List{Tuple{Diff, List{T}}} = nil,
) where {T}
  local out::List{Tuple{Diff, List{T}}}

  local start1::Int = inStart1
  local end1::Int = inEnd1
  local start2::Int = inStart2
  local end2::Int = inEnd2
  local len1::Int
  local len2::Int
  local prefixes::List{Tuple{Diff, List{T}}} = inPrefixes
  local suffixes::List{Tuple{Diff, List{T}}} = inSuffixes

  @assign len1 = end1 - start1 + 1
  @assign len2 = end2 - start2 + 1
  #=  Some of these tricks were inspired by diff-match-patch:
  =#
  #=    https:code.google.com/p/google-diff-match-patch/
  =#
  #=  They do checks that are trivial and optimal, but could significantly
  =#
  #=    slow down the rest of Myer's diff algorithm
  =#
  #=  Check if either sequence is empty. Trivial to diff.
  =#
  if len1 < 1 && len2 < 1
    @assign out = ListUtil.append_reverse(prefixes, suffixes)
    return out
  elseif len1 < 1
    @assign out = ListUtil.append_reverse(
      prefixes,
      _cons((Diff.Add, list(arr2[e] for e = start2:end2)), suffixes),
    )
    return out
  elseif len2 < 1
    @assign out = ListUtil.append_reverse(
      prefixes,
      _cons((Diff.Delete, list(arr1[e] for e = start1:end1)), suffixes),
    )
    return out
  end
  #=  Note the horrible syntax for short-circuit evaluation
  =#
  #=  Check if the sequences are equal. Trivial diff.
  =#
  if if len1 == len2
    min(@do_threaded_for equals(e1, e2) (e1, e2) (arr1, arr2))
  else
    false
  end
    @assign out = list((Diff.Equal, list(arr1[e] for e = start1:end1)))
    return out
  end
  #=  trim off common prefix; guaranteed to be a good solution
  =#
  @assign (prefixes, start1, start2) =
    trimCommonPrefix(arr1, start1, end1, arr2, start2, end2, equals, prefixes)
  #=  trim off common suffix; guaranteed to be a good solution
  =#
  @assign (suffixes, end1, end2) =
    trimCommonSuffix(arr1, start1, end1, arr2, start2, end2, equals, suffixes)
  #=  Check if anything changed and iterate. A sequence could now be empty.
  =#
  if start1 != inStart1 || start2 != inStart2 || end1 != inEnd1 || end2 != inEnd2
    @assign out = diffSeq(
      arr1,
      arr2,
      equals,
      isWhitespace,
      toString,
      start1,
      end1,
      start2,
      end2,
      inPrefixes = prefixes,
      inSuffixes = suffixes,
    )
    return out
  else
    @assign out = begin
      @matchcontinue () begin
        () => begin
          onlyAdditions(
            arr1,
            arr2,
            equals,
            isWhitespace,
            toString,
            start1,
            end1,
            start2,
            end2,
          )
        end

        () => begin
          onlyRemovals(arr1, arr2, equals, isWhitespace, toString, start1, end1, start2, end2)
        end

        _ => begin
          myersGreedyDiff(arr1, arr2, equals, start1, end1, start2, end2)
        end
      end
    end
    @assign out = ListUtil.append_reverse(prefixes, listAppend(out, suffixes))
    return out
  end
  #=  TODO: cleanup
  =#
  fail()
  return out
end

function addToList(
  inlst::List{Tuple{Diff, List{T}}},
  ind::Diff,
  inacc::List{T},
  newd::Diff,
  t::T,
) where {T}
  local acc::List{T} = inacc
  local d::Diff = newd
  local lst::List{Tuple{Diff, List{T}}} = inlst

  if ind == newd
    @assign acc = _cons(t, acc)
  else
    if !listEmpty(inacc)
      @assign lst = _cons((ind, listReverse(acc)), lst)
    end
    @assign acc = list(t)
  end
  return (lst, d, acc)
end

function endList(inlst::List{Tuple{Diff, List{T}}}, ind::Diff, inacc::List{T}) where {T}
  local lst::List{Tuple{Diff, List{T}}} = inlst

  if !listEmpty(inacc)
    @assign lst = _cons((ind, listReverse(inacc)), lst)
  end
  return lst
end

function onlyAdditions(
  arr1::Array{T},
  arr2::Array{T},
  equals::FunEquals,
  isWhitespace::FunWhitespace,
  toString::ToString,
  start1::Int,
  end1::Int,
  start2::Int,
  end2::Int,
) where {T}
  local out::List{Tuple{Diff, List{T}}}

  local x::Int = 0
  local y::Int = 0
  local d::Diff = Diff.Equal
  local lst::List{T} = nil

  @assign out = nil
  #=  print(\"Try only additions\\n\");
  =#
  while start1 + x <= end1 && start2 + y <= end2
    if equals(arr1[start1 + x], arr2[start2 + y])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Equal, arr1[start1 + x])
      @assign x = x + 1
      @assign y = y + 1
    elseif isWhitespace(arr1[start1 + x])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Delete, arr1[start1 + x])
      @assign x = x + 1
    else
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Add, arr2[start2 + y])
      @assign y = y + 1
    end
  end
  #=  print(\"Try only additions\"+String(x)+\",\"+String(y)+\"\\n\");
  =#
  #=  print(\"1: \" + System.trim(toString(arr1[start1+x]))+\"\\n\");
  =#
  #=  print(\"2: \" + System.trim(toString(arr2[start2+y]))+\"\\n\");
  =#
  #=  print(\"Both equal\\n\");
  =#
  #=  print(\"Deleting: \" + toString(arr1[start1+x])+\"\\n\");
  =#
  #=  print(\"Adding: \" + toString(arr2[start2+y])+\"\\n\");
  =#
  while start1 + x <= end1
    if isWhitespace(arr1[start1 + x])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Delete, arr1[start1 + x])
      @assign x = x + 1
    else
      fail()
    end
  end
  while start2 + y <= end2
    if isWhitespace(arr2[start2 + y])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Add, arr2[start2 + y])
      @assign y = y + 1
    else
      fail()
    end
  end
  @assign out = endList(out, d, lst)
  #=  print(\"It is only additions :)\\n\");
  =#
  @assign out = listReverse(out)
  return out
end

function onlyRemovals(
  arr1::Array{T},
  arr2::Array{T},
  equals::FunEquals,
  isWhitespace::FunWhitespace,
  toString::ToString,
  start1::Int,
  end1::Int,
  start2::Int,
  end2::Int,
) where {T}
  local out::List{Tuple{Diff, List{T}}}

  local x::Int = 0
  local y::Int = 0
  local d::Diff = Diff.Equal
  local lst::List{T} = nil

  @assign out = nil
  #=  print(\"Try only removals\\n\");
  =#
  while start1 + x <= end1 && start2 + y <= end2
    if equals(arr1[start1 + x], arr2[start2 + y])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Equal, arr1[start1 + x])
      @assign x = x + 1
      @assign y = y + 1
    elseif isWhitespace(arr2[start2 + y])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Add, arr2[start2 + y])
      @assign y = y + 1
    else
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Delete, arr1[start1 + x])
      @assign x = x + 1
    end
  end
  #=  print(\"Try only removals\"+String(x)+\",\"+String(y)+\"\\n\");
  =#
  #=  print(\"1: \" + System.trim(toString(arr1[start1+x]))+\"\\n\");
  =#
  #=  print(\"2: \" + System.trim(toString(arr2[start2+y]))+\"\\n\");
  =#
  #=  print(\"Both equal\\n\");
  =#
  #=  print(\"Deleting: \" + toString(arr1[start1+x])+\"\\n\");
  =#
  #=  print(\"Adding: \" + toString(arr2[start2+y])+\"\\n\");
  =#
  while start1 + x <= end1
    if isWhitespace(arr1[start1 + x])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Delete, arr1[start1 + x])
      @assign x = x + 1
    else
      fail()
    end
  end
  while start2 + y <= end2
    if isWhitespace(arr2[start2 + y])
      @assign (out, d, lst) = addToList(out, d, lst, Diff.Add, arr2[start2 + y])
      @assign y = y + 1
    else
      fail()
    end
  end
  @assign out = endList(out, d, lst)
  #=  print(\"It is only additions :)\\n\");
  =#
  @assign out = listReverse(out)
  return out
end

function myersGreedyDiff(
  arr1::Array{T},
  arr2::Array{T},
  equals::FunEquals,
  start1::Int,
  end1::Int,
  start2::Int,
  end2::Int,
) where {T}
  local out::List{Tuple{Diff, List{T}}}

  local len1::Int
  local len2::Int
  local maxIter::Int
  local sz::Int
  local middle::Int
  local x::Int
  local y::Int
  local V::Array{Integer}
  local paths::Array{List{Tuple{Integer, Integer}}}
  local prevPath::List{Tuple{Integer, Integer}}

  #=  Greedy LCS/SES
  =#
  @assign len1 = end1 - start1 + 1
  @assign len2 = end2 - start2 + 1
  @assign maxIter = len1 + len2
  @assign sz = 2 * maxIter + 1
  @assign middle = maxIter + 1
  @assign V = arrayCreate(sz, 0)
  @assign paths = arrayCreate(sz, nil)
  for D = 0:maxIter
    for k = (-D):2:D
      if k == (-D) || k != D && V[k - 1 + middle] < V[k + 1 + middle]
        @assign x = V[k + 1 + middle]
        @assign prevPath = paths[k + 1 + middle]
      else
        @assign x = V[k - 1 + middle] + 1
        @assign prevPath = paths[k - 1 + middle]
      end
      @assign y = x - k
      @assign paths[k + middle] = _cons((x, y), prevPath)
      while if x < len1 && y < len2
        equals(arr1[start1 + x], arr2[start2 + y])
      else
        false
      end
        @assign x = x + 1
        @assign y = y + 1
        @assign paths[k + middle] = _cons((x, y), paths[k + middle])
      end
      @assign V[k + middle] = x
      if x >= len1 && y >= len2
        @assign out = myersGreedyPathToDiff(arr1, arr2, start1, start2, paths[k + middle])
        return out
      end
    end
  end
  #=  Length of an SES is D
  =#
  print("myersDiff: This cannot happen")
  fail()
  return out
end

function myersGreedyPathToDiff(
  arr1::Array{T},
  arr2::Array{T},
  start1::Int,
  start2::Int,
  paths::List{Tuple{Integer, Integer}},
) where {T}
  local out::List{Tuple{Diff, List{T}}} = nil

  local x1::Int
  local x2::Int
  local y1::Int
  local y2::Int
  local d1::Diff = Diff.Equal
  local d2::Diff = Diff.Equal
  local lst::List{T} = nil
  local t::T

  @match _cons((x2, y2), _) = paths
  #=  starting point
  =#
  for path in listRest(paths)
    @assign (x1, y1) = path
    if x2 - x1 == 1 && y2 - y1 == 1
      @assign d1 = Diff.Equal
      @assign t = arr1[start1 + x1]
    elseif x2 - x1 == 1 && y2 == y1
      @assign d1 = Diff.Delete
      @assign t = arr1[start1 + x1]
    elseif y2 - y1 == 1 && x2 == x1
      @assign d1 = Diff.Add
      @assign t = arr2[start2 + y1]
    else
      print("myersGreedyPathToDiff: This cannot happen\\n")
      fail()
    end
    if listEmpty(lst)
      @assign lst = list(t)
    elseif d1 == d2
      @assign lst = _cons(t, lst)
    else
      @assign out = _cons((d2, lst), out)
      @assign lst = list(t)
    end
    @assign d2 = d1
    @assign x2 = x1
    @assign y2 = y1
  end
  #=  Diagonal
  =#
  #=  Horizontal is addition
  =#
  #=  Vertical is deletion
  =#
  #=  Else is WTF?
  =#
  if !listEmpty(lst)
    @assign out = _cons((d2, lst), out)
  end
  return out
end

function trimCommonPrefix(
  arr1::Array{T},
  inStart1::Int,
  end1::Int,
  arr2::Array{T},
  inStart2::Int,
  end2::Int,
  equals::FunEquals,
  acc::List{Tuple{Diff, List{T}}},
) where {T}
  local start1::Int = inStart1
  local start2::Int = inStart2
  local prefixes::List{Tuple{Diff, List{T}}} = acc

  local lst::List{T} = nil

  while if start1 <= end1 && start2 <= end2
    equals(arr1[start1], arr2[start2])
  else
    false
  end
    @assign lst = _cons(arr1[start1], lst)
    @assign start1 = start1 + 1
    @assign start2 = start2 + 1
  end
  if !listEmpty(lst)
    @assign prefixes = _cons((Diff.Equal, listReverse(lst)), prefixes)
  end
  return (prefixes, start1, start2)
end

function trimCommonSuffix(
  arr1::Array{T},
  start1::Int,
  inEnd1::Int,
  arr2::Array{T},
  start2::Int,
  inEnd2::Int,
  equals::FunEquals,
  acc::List{Tuple{Diff, List{T}}},
) where {T}
  local end1::Int = inEnd1
  local end2::Int = inEnd2
  local suffixes::List{Tuple{Diff, List{T}}} = acc

  local lst::List{T} = nil

  while if start1 <= end1 && start2 <= end2
    equals(arr1[end1], arr2[end2])
  else
    false
  end
    @assign lst = _cons(arr1[end1], lst)
    @assign end1 = end1 - 1
    @assign end2 = end2 - 1
  end
  if !listEmpty(lst)
    @assign suffixes = _cons((Diff.Equal, lst), suffixes)
  end
  return (suffixes, end1, end2)
end

@exportAll()
end
