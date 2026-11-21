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

module AbsynUtil

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

const ModFunc = Function

using OpenModelicaParser.Absyn

import ..ListUtil

import ..Frontend.Util
import ..Frontend.System

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::Info

const TypeA = Any
const Type_a = Any
const Argument = Any
const Arg = Any
#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

#=  stefan
=#

function makeIdentPathFromString(s::String)::Path
  local p::Path

  @assign p = IDENT(s)
  return p
end

"""
  The ElementSpec type contains the name of the element, and this function
  extracts this name.
"""
function elementSpecName(inElementSpec::ElementSpec)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    @match inElementSpec begin
      CLASSDEF(class_ = CLASS(name = n)) => begin
        n
      end

      COMPONENTS(components = COMPONENTITEM(component = COMPONENT(name = n)) <| nil()) =>
        begin
          n
        end
    end
  end
  return outIdent
end

"""returns the componentRef of an expression if matches."""
function expCref(exp::Exp)::ComponentRef
  local cr::ComponentRef

  @match CREF(cr) = exp
  return cr
end

function printComponentRefStr(cr::ComponentRef)::String
  local ostring::String

  @assign ostring = begin
    local s1::String
    local s2::String
    local child::ComponentRef
    @match cr begin
      CREF_IDENT(s1, _) => begin
        s1
      end

      CREF_QUAL(s1, _, child) => begin
        @assign s2 = printComponentRefStr(child)
        @assign s1 = s1 + "." + s2
        s1
      end

      CREF_FULLYQUALIFIED(child) => begin
        @assign s2 = printComponentRefStr(child)
        @assign s1 = "." + s2
        s1
      end

      ALLWILD(__) => begin
        "__"
      end

      WILD(__) => begin
        "_"
      end
    end
  end
  return ostring
end

"""Returns true if two paths are equal."""
function pathEqual(inPath1::Path, inPath2::Path)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id1::String
    local id2::String
    local res::Bool
    local path1::Path
    local path2::Path
    #=  fully qual vs. path
    =#
    @match (inPath1, inPath2) begin
      (FULLYQUALIFIED(path1), path2) => begin
        pathEqual(path1, path2)
      end

      (path1, FULLYQUALIFIED(path2)) => begin
        pathEqual(path1, path2)
      end

      (IDENT(id1), IDENT(id2)) => begin
        stringEq(id1, id2)
      end

      (QUALIFIED(id1, path1), QUALIFIED(id2, path2)) => begin
        @assign res = if stringEq(id1, id2)
          pathEqual(path1, path2)
        else
          false
        end
        res
      end

      _ => begin
        false
      end
    end
  end
  #=  path vs. fully qual
  =#
  #=  ident vs. ident
  =#
  #=  qual ident vs. qual ident
  =#
  #=  other return false
  =#
  return outBoolean
end

"""
  Author BZ 2009-01
  Check whether two type specs are equal or not.
"""
function typeSpecEqual(a::TypeSpec, b::TypeSpec)::Bool
  local ob::Bool

  @assign ob = begin
    local p1::Path
    local p2::Path
    local oad1::Option{ArrayDim}
    local oad2::Option{ArrayDim}
    local lst1::List{TypeSpec}
    local lst2::List{TypeSpec}
    local i1::Ident
    local i2::Ident
    local pos1::Int
    local pos2::Int
    #=  first try full equality
    =#
    @matchcontinue (a, b) begin
      (TPATH(p1, oad1), TPATH(p2, oad2)) => begin
        @match true = pathEqual(p1, p2)
        @match true = optArrayDimEqual(oad1, oad2)
        true
      end

      (TCOMPLEX(p1, lst1, oad1), TCOMPLEX(p2, lst2, oad2)) => begin
        @match true = pathEqual(p1, p2)
        @match true = ListUtil.isEqualOnTrue(lst1, lst2, typeSpecEqual)
        @match true = optArrayDimEqual(oad1, oad2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return ob
end

"""
  Author BZ
  helper function for typeSpecEqual
"""
function optArrayDimEqual(oad1::Option{<:ArrayDim}, oad2::Option{<:ArrayDim})::Bool
  local b::Bool

  @assign b = begin
    local ad1::List{Subscript}
    local ad2::List{Subscript}
    @matchcontinue (oad1, oad2) begin
      (SOME(ad1), SOME(ad2)) => begin
        @match true = ListUtil.isEqualOnTrue(ad1, ad2, subscriptEqual)
        true
      end

      (NONE(), NONE()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

"""This function simply converts a Path to a string."""
function typeSpecPathString(tp::TypeSpec)::String
  local s::String

  @assign s = begin
    local p::Path
    @match tp begin
      TCOMPLEX(path = p) => begin
        pathString(p)
      end

      TPATH(path = p) => begin
        pathString(p)
      end
    end
  end
  return s
end

"""Converts a TypeSpec to Path"""
function typeSpecPath(tp::TypeSpec)::Path
  local op::Path

  @assign op = begin
    local p::Path
    @match tp begin
      TCOMPLEX(path = p) => begin
        p
      end

      TPATH(path = p) => begin
        p
      end
    end
  end
  return op
end

"""Returns the dimensions of a TypeSpec."""
function typeSpecDimensions(inTypeSpec::TypeSpec)::ArrayDim
  local outDimensions::ArrayDim

  @assign outDimensions = begin
    local dim::ArrayDim
    @match inTypeSpec begin
      TPATH(arrayDim = SOME(dim)) => begin
        dim
      end

      TCOMPLEX(arrayDim = SOME(dim)) => begin
        dim
      end

      _ => begin
        nil
      end
    end
  end
  return outDimensions
end

"""This function simply converts a Path to a string."""
function pathString(
  path::Path,
  delimiter::String = ".",
  usefq::Bool = true,
  reverse::Bool = false,
)::String
  local s::String
  local p1::Path
  local p2::Path
  local count::Int = 0
  local len::Int = 0
  local dlen::Int = stringLength(delimiter)
  local b::Bool

  #=  First, calculate the length of the string to be generated
  =#
  @assign p1 = if usefq
    path
  else
    makeNotFullyQualified(path)
  end
  _ = begin
    @match p1 begin
      IDENT(__) => begin
        #=  Do not allocate memory if we're just going to copy the only identifier
        =#
        @assign s = p1.name
        return s
        ()
      end
      _ => begin
        ()
      end
    end
  end
  @assign p2 = p1
  @assign b = true
  while b
    @assign (p2, len, count, b) = begin
      @match p2 begin
        IDENT(__) => begin
          (p2, len + 1, count + stringLength(p2.name), false)
        end

        QUALIFIED(__) => begin
          (p2.path, len + 1, count + stringLength(p2.name), true)
        end

        FULLYQUALIFIED(__) => begin
          (p2.path, len + 1, count, true)
        end
      end
    end
  end
  @assign s = pathStringWork(p1, (len - 1) * dlen + count, delimiter, dlen, reverse)
  return s
end

"""
I rewrote this to not use the string allocator - John
"""
function pathStringWork(
  inPath::Path,
  len::Int,
  delimiter::String,
  dlen::Int,
  reverse::Bool,
)::String
  local s::String = ""
  local p::Path = inPath
  local b::Bool = true
  local count::Int = 0
  #=  Allocate a string of the exact required length
  =#
  local sb = IOBuffer() #System.StringAllocator = System.StringAllocator(len)

  #=  Fill the string
  =#
  while b
    (p, count, b) = begin
      @match p begin
        IDENT(__) => begin
          print(sb, p.name)
          (p, count + stringLength(p.name), false)
        end

        QUALIFIED(__) => begin
          # System.stringAllocatorStringCopy(
          #   sb,
          #   p.name,
          #   if reverse
          #     len - count - dlen - stringLength(p.name)
          #   else
          #     count
          #   end,
          # )
          # System.stringAllocatorStringCopy(sb, delimiter, if reverse
          #     len - count - dlen
          #   else
          #     count + stringLength(p.name)
          #   end)
          print(sb, p.name)
          print(sb, delimiter)
          (p.path, count + stringLength(p.name) + dlen, true)
        end

        FULLYQUALIFIED(__) => begin
          # System.stringAllocatorStringCopy(sb, delimiter, if reverse
          #   len - count - dlen
          # else
          #   count
          # end)
          print(sb, delimiter)
          (p.path, count + dlen, true)
        end
      end
    end
  end
  #=  Return the string
  =#
  s = String(take!(sb))
  #  @info s
  return s
end

function pathStringNoQual(path::Path, delimiter::String = ".",
                          usefq::Bool = false, reverse::Bool = false)
  return pathString(path, delimiter, usefq, reverse)
end

function pathStringDefault(path::Path)::String
  local s::String = pathString(path)
  return s
end

function pathCompare(ip1::Path, ip2::Path)::Int
  local o::Int

  @assign o = begin
    local p1::Path
    local p2::Path
    local i1::String
    local i2::String
    @match (ip1, ip2) begin
      (FULLYQUALIFIED(p1), FULLYQUALIFIED(p2)) => begin
        pathCompare(p1, p2)
      end

      (FULLYQUALIFIED(__), _) => begin
        1
      end

      (_, FULLYQUALIFIED(__)) => begin
        -1
      end

      (QUALIFIED(i1, p1), QUALIFIED(i2, p2)) => begin
        @assign o = stringCompare(i1, i2)
        @assign o = if o == 0
          pathCompare(p1, p2)
        else
          o
        end
        o
      end

      (QUALIFIED(__), _) => begin
        1
      end

      (_, QUALIFIED(__)) => begin
        -1
      end

      (IDENT(i1), IDENT(i2)) => begin
        stringCompare(i1, i2)
      end
    end
  end
  return o
end

function pathCompareNoQual(ip1::Path, ip2::Path)::Int
  local o::Int

  @assign o = begin
    local p1::Path
    local p2::Path
    local i1::String
    local i2::String
    @match (ip1, ip2) begin
      (FULLYQUALIFIED(p1), p2) => begin
        pathCompareNoQual(p1, p2)
      end

      (p1, FULLYQUALIFIED(p2)) => begin
        pathCompareNoQual(p1, p2)
      end

      (QUALIFIED(i1, p1), QUALIFIED(i2, p2)) => begin
        @assign o = stringCompare(i1, i2)
        @assign o = if o == 0
          pathCompare(p1, p2)
        else
          o
        end
        o
      end

      (QUALIFIED(__), _) => begin
        1
      end

      (_, QUALIFIED(__)) => begin
        -1
      end

      (IDENT(i1), IDENT(i2)) => begin
        stringCompare(i1, i2)
      end
    end
  end
  return o
end

"""Converts a string into a qualified path."""
function stringPath(str::String)::Path
  local qualifiedPath::Path
  local paths::List{String}
  paths = arrayList(split(str, ".")) #Util.stringSplitAtChar(str, ".")
  qualifiedPath = stringListPath(paths)
  return qualifiedPath
end

"""Converts a list of strings into a qualified path."""
function stringListPath(paths::List{<:String})::Path
  local qualifiedPath::Path

  @assign qualifiedPath = begin
    local str::String
    local rest_str::List{String}
    local p::Path
    @matchcontinue paths begin
      nil() => begin
        fail()
      end

      str <| nil() => begin
        IDENT(str)
      end

      str <| rest_str => begin
        @assign p = stringListPath(rest_str)
        QUALIFIED(str, p)
      end
    end
  end
  return qualifiedPath
end

"""Returns the last ident (after last dot) in a path"""
function pathLastIdent(inPath::Path)::String
  local outIdent::String

  @assign outIdent = begin
    local id::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(path = p) => begin
        pathLastIdent(p)
      end

      IDENT(name = id) => begin
        id
      end

      FULLYQUALIFIED(path = p) => begin
        pathLastIdent(p)
      end
    end
  end
  return outIdent
end

"""Returns the last ident (after last dot) in a path"""
function pathLast(path::Path)::Path

  @assign path = begin
    local p::Path
    @match path begin
      QUALIFIED(path = p) => begin
        pathLast(p)
      end

      IDENT(__) => begin
        path
      end

      FULLYQUALIFIED(path = p) => begin
        pathLast(p)
      end
    end
  end
  return path
end

"""Returns the first ident (before first dot) in a path"""
function pathFirstIdent(inPath::Path)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    local p::Path
    @match inPath begin
      FULLYQUALIFIED(path = p) => begin
        pathFirstIdent(p)
      end

      QUALIFIED(name = n) => begin
        n
      end

      IDENT(name = n) => begin
        n
      end
    end
  end
  return outIdent
end

function pathSecondIdent(inPath::Path)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    local n::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(path = QUALIFIED(name = n)) => begin
        n
      end

      QUALIFIED(path = IDENT(name = n)) => begin
        n
      end

      FULLYQUALIFIED(path = p) => begin
        pathSecondIdent(p)
      end
    end
  end
  return outIdent
end

"""Returns the prefix of a path, i.e. this.is.a.path => this.is.a"""
function pathPrefix(path::Path)::Path
  local prefix::Path

  @assign prefix = begin
    local p::Path
    local n::Ident
    @matchcontinue path begin
      FULLYQUALIFIED(path = p) => begin
        pathPrefix(p)
      end

      QUALIFIED(name = n, path = IDENT(__)) => begin
        IDENT(n)
      end

      QUALIFIED(name = n, path = p) => begin
        @assign p = pathPrefix(p)
        QUALIFIED(n, p)
      end
    end
  end
  return prefix
end

"""Prefixes a path with an identifier."""
function prefixPath(prefix::Ident, path::Path)::Path
  local outPath::Path

  @assign outPath = QUALIFIED(prefix, path)
  return outPath
end

"""
  Adds a suffix to a path. Ex:
  suffixPath(a.b.c, 'd') => a.b.c.d
"""
function suffixPath(inPath::Path, inSuffix::Ident)::Path
  local outPath::Path

  @assign outPath = begin
    local name::Ident
    local path::Path
    @match (inPath, inSuffix) begin
      (IDENT(name), _) => begin
        QUALIFIED(name, IDENT(inSuffix))
      end

      (QUALIFIED(name, path), _) => begin
        @assign path = suffixPath(path, inSuffix)
        QUALIFIED(name, path)
      end

      (FULLYQUALIFIED(path), _) => begin
        @assign path = suffixPath(path, inSuffix)
        FULLYQUALIFIED(path)
      end
    end
  end
  return outPath
end

function pathToStringList(path::Path)::List{String}
  local outPaths::List{String}

  @assign outPaths = listReverse(pathToStringListWork(path, nil))
  return outPaths
end

function pathToStringListWork(path::Path, acc::List{<:String})::List{String}
  local outPaths::List{String}

  @assign outPaths = begin
    local n::String
    local p::Path
    local strings::List{String}
    @match (path, acc) begin
      (IDENT(name = n), _) => begin
        _cons(n, acc)
      end

      (FULLYQUALIFIED(path = p), _) => begin
        pathToStringListWork(p, acc)
      end

      (QUALIFIED(name = n, path = p), _) => begin
        pathToStringListWork(p, _cons(n, acc))
      end
    end
  end
  return outPaths
end

"""Returns true if prefixPath is a prefix of path, false otherwise."""
function pathPrefixOf(prefixPath::Path, path::Path)::Bool
  local isPrefix::Bool

  @assign isPrefix = begin
    local p::Path
    local p2::Path
    local id::String
    local id2::String
    @matchcontinue (prefixPath, path) begin
      (FULLYQUALIFIED(p), p2) => begin
        pathPrefixOf(p, p2)
      end

      (p, FULLYQUALIFIED(p2)) => begin
        pathPrefixOf(p, p2)
      end

      (IDENT(id), IDENT(id2)) => begin
        stringEq(id, id2)
      end

      (IDENT(id), QUALIFIED(name = id2)) => begin
        stringEq(id, id2)
      end

      (QUALIFIED(id, p), QUALIFIED(id2, p2)) => begin
        @match true = stringEq(id, id2)
        @match true = pathPrefixOf(p, p2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return isPrefix
end

"""
  Author BZ 2009-08
  Function for getting ComponentRefs out from Subscripts
"""
function getCrefsFromSubs(
  isubs::List{<:Subscript},
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local crefs::List{ComponentRef}

  @assign crefs = begin
    local crefs1::List{ComponentRef}
    local exp::Exp
    local subs::List{Subscript}
    @match (isubs, includeSubs, includeFunctions) begin
      (nil(), _, _) => begin
        nil
      end

      (NOSUB(__) <| subs, _, _) => begin
        getCrefsFromSubs(subs, includeSubs, includeFunctions)
      end

      (SUBSCRIPT(exp) <| subs, _, _) => begin
        @assign crefs1 = getCrefsFromSubs(subs, includeSubs, includeFunctions)
        @assign crefs = getCrefFromExp(exp, includeSubs, includeFunctions)
        listAppend(crefs, crefs1)
      end
    end
  end
  return crefs
end

"""
  Returns a flattened list of the
  component references in an expression
"""
function getCrefFromExp(
  inExp::Exp,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local cr::ComponentRef
    local l1::List{ComponentRef}
    local l2::List{ComponentRef}
    local res::List{ComponentRef}
    local e1::ComponentCondition
    local e2::ComponentCondition
    local e3::ComponentCondition
    local op::Operator
    local e4::List{Tuple{ComponentCondition, ComponentCondition}}
    local farg::FunctionArgs
    local expl::List{ComponentCondition}
    local expll::List{List{ComponentCondition}}
    local subs::List{Subscript}
    local lstres1::List{List{ComponentRef}}
    local crefll::List{List{ComponentRef}}
    @match (inExp, includeSubs, includeFunctions) begin
      (INTEGER(__), _, _) => begin
        nil
      end

      (REAL(__), _, _) => begin
        nil
      end

      (STRING(__), _, _) => begin
        nil
      end

      (BOOL(__), _, _) => begin
        nil
      end

      (CREF(componentRef = ALLWILD(__)), _, _) => begin
        nil
      end

      (CREF(componentRef = WILD(__)), _, _) => begin
        nil
      end

      (CREF(componentRef = cr), false, _) => begin
        list(cr)
      end

      (CREF(componentRef = cr), true, _) => begin
        @assign subs = getSubsFromCref(cr, includeSubs, includeFunctions)
        @assign l1 = getCrefsFromSubs(subs, includeSubs, includeFunctions)
        _cons(cr, l1)
      end

      (BINARY(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (UNARY(exp = e1), _, _) => begin
        @assign res = getCrefFromExp(e1, includeSubs, includeFunctions)
        res
      end

      (LBINARY(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (LUNARY(exp = e1), _, _) => begin
        @assign res = getCrefFromExp(e1, includeSubs, includeFunctions)
        res
      end

      (RELATION(exp1 = e1, exp2 = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (IFEXP(ifExp = e1, trueBranch = e2, elseBranch = e3), _, _) => begin
        ListUtil.flatten(list(
          getCrefFromExp(e1, includeSubs, includeFunctions),
          getCrefFromExp(e2, includeSubs, includeFunctions),
          getCrefFromExp(e3, includeSubs, includeFunctions),
        ), ComponentRef)
      end

      (CALL(function_ = cr, functionArgs = farg), _, _) => begin
        @assign res = getCrefFromFarg(farg, includeSubs, includeFunctions)
        @assign res = if includeFunctions
          _cons(cr, res)
        else
          res
        end
        res
      end

      (PARTEVALFUNCTION(function_ = cr, functionArgs = farg), _, _) => begin
        @assign res = getCrefFromFarg(farg, includeSubs, includeFunctions)
        @assign res = if includeFunctions
          _cons(cr, res)
        else
          res
        end
        res
      end

      (ARRAY(arrayExp = expl), _, _) => begin
        @assign lstres1 = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions, List{ComponentRef})
        @assign res = ListUtil.flatten(lstres1, ComponentRef)
        res
      end

      (MATRIX(matrix = expll), _, _) => begin
        @assign res = ListUtil.flatten(ListUtil.flatten(ListUtil.map2List(expll, getCrefFromExp, includeSubs, includeFunctions, List{ComponentRef}),
                                                        List{ComponentRef}), ComponentRef)
        res
      end

      (RANGE(start = e1, step = SOME(e3), stop = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign l2 = listAppend(l1, l2)
        @assign l1 = getCrefFromExp(e3, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (RANGE(start = e1, step = NONE(), stop = e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (END(__), _, _) => begin
        nil
      end

      (TUPLE(expressions = expl), _, _) => begin
        @assign crefll = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions, List{ComponentRef})
        @assign res = ListUtil.flatten(crefll, ComponentRef)
        res
      end

      (CODE(__), _, _) => begin
        nil
      end

      (AS(exp = e1), _, _) => begin
        getCrefFromExp(e1, includeSubs, includeFunctions)
      end

      (CONS(e1, e2), _, _) => begin
        @assign l1 = getCrefFromExp(e1, includeSubs, includeFunctions)
        @assign l2 = getCrefFromExp(e2, includeSubs, includeFunctions)
        @assign res = listAppend(l1, l2)
        res
      end

      (LIST(expl), _, _) => begin
        @assign crefll = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions, List{ComponentRef})
        @assign res = ListUtil.flatten(crefll, ComponentRef)
        res
      end

      (MATCHEXP(__), _, _) => begin
        fail()
      end

      (DOT(__), _, _) => begin
        getCrefFromExp(inExp.exp, includeSubs, includeFunctions)
      end

      _ => begin
        Error.addInternalError(
          getInstanceName() + " failed " + printExp(inExp),
          sourceInfo(),
        )
        fail()
      end
    end
  end
  #=  TODO: Handle else if-branches.
  =#
  #=  inExp.index is only allowed to contain names to index the function call; not crefs that are evaluated in any way
  =#
  return outComponentRefLst
end

"""
  Returns the flattened list of all component references
  present in a list of function arguments.
"""
function getCrefFromFarg(
  inFunctionArgs::FunctionArgs,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local l1::List{List{ComponentRef}}
    local l2::List{List{ComponentRef}}
    local fl1::List{ComponentRef}
    local fl2::List{ComponentRef}
    local fl3::List{ComponentRef}
    local res::List{ComponentRef}
    local expl::List{ComponentCondition}
    local nargl::List{NamedArg}
    local iterators::ForIterators
    local exp::Exp
    @match (inFunctionArgs, includeSubs, includeFunctions) begin
      (FUNCTIONARGS(args = expl, argNames = nargl), _, _) => begin
        @assign l1 = ListUtil.map2(expl, getCrefFromExp, includeSubs, includeFunctions, List{ComponentRef})
        @assign fl1 = ListUtil.flatten(l1, ComponentRef)
        @assign l2 = ListUtil.map2(nargl, getCrefFromNarg, includeSubs, includeFunctions, List{ComponentRef})
        @assign fl2 = ListUtil.flatten(l2, ComponentRef)
        @assign res = listAppend(fl1, fl2)
        res
      end

      (FOR_ITER_FARG(exp, _, iterators), _, _) => begin
        @assign l1 = ListUtil.map2Option(
          ListUtil.map(iterators, iteratorRange, Option{Exp}),
          getCrefFromExp,
          includeSubs,
          includeFunctions,
          List{ComponentRef},
        )
        @assign l2 = ListUtil.map2Option(
          ListUtil.map(iterators, iteratorGuard, Option{Exp}),
          getCrefFromExp,
          includeSubs,
          includeFunctions,
          List{ComponentRef},
        )
        @assign fl1 = ListUtil.flatten(l1, ComponentRef)
        @assign fl2 = ListUtil.flatten(l2, ComponentRef)
        @assign fl3 = getCrefFromExp(exp, includeSubs, includeFunctions)
        @assign res = listAppend(fl1, listAppend(fl2, fl3))
        res
      end
    end
  end
  return outComponentRefLst
end

function iteratorRange(iterator::ForIterator)::Option{Exp}
  local range::Option{Exp}

  @match ITERATOR(range = range) = iterator
  return range
end

function iteratorGuard(iterator::ForIterator)::Option{Exp}
  local guardExp::Option{Exp}

  @match ITERATOR(guardExp = guardExp) = iterator
  return guardExp
end

#=  stefan
=#

"""returns the names from a list of NamedArgs as a string list"""
function getNamedFuncArgNamesAndValues(
  inNamedArgList::List{<:NamedArg},
)::Tuple{List{String}, List{Exp}}
  local outExpList::List{Exp}
  local outStringList::List{String}

  @assign (outStringList, outExpList) = begin
    local cdr::List{NamedArg}
    local s::String
    local e::Exp
    local slst::List{String}
    local elst::List{Exp}
    @match inNamedArgList begin
      nil() => begin
        (nil, nil)
      end

      NAMEDARG(argName = s, argValue = e) <| cdr => begin
        @assign (slst, elst) = getNamedFuncArgNamesAndValues(cdr)
        (_cons(s, slst), _cons(e, elst))
      end
    end
  end
  return (outStringList, outExpList)
end

"""
  Returns the flattened list of all component references
  present in a list of named function arguments.
"""
function getCrefFromNarg(
  inNamedArg::NamedArg,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{ComponentRef} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local outComponentRefLst::List{ComponentRef}

  @assign outComponentRefLst = begin
    local res::List{ComponentRef}
    local exp::ComponentCondition
    @match (inNamedArg, includeSubs, includeFunctions) begin
      (NAMEDARG(argValue = exp), _, _) => begin
        @assign res = getCrefFromExp(exp, includeSubs, includeFunctions)
        res
      end
    end
  end
  return outComponentRefLst
end

"""This function joins two paths"""
function joinPaths(inPath1::Path, inPath2::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local str::Ident
    local p2::Path
    local p_1::Path
    local p::Path
    @match (inPath1, inPath2) begin
      (IDENT(name = str), p2) => begin
        QUALIFIED(str, p2)
      end

      (QUALIFIED(name = str, path = p), p2) => begin
        @assign p_1 = joinPaths(p, p2)
        QUALIFIED(str, p_1)
      end

      (FULLYQUALIFIED(p), p2) => begin
        joinPaths(p, p2)
      end

      (p, FULLYQUALIFIED(p2)) => begin
        joinPaths(p, p2)
      end
    end
  end
  return outPath
end

"""
  Returns the path given as argument to
  the function minus the last ident.
"""
function stripLast(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local str::Ident
    local p::Path
    @match inPath begin
      QUALIFIED(name = str, path = IDENT(__)) => begin
        IDENT(str)
      end

      QUALIFIED(name = str, path = p) => begin
        @assign p = stripLast(p)
        QUALIFIED(str, p)
      end

      FULLYQUALIFIED(p) => begin
        @assign p = stripLast(p)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""
  This function converts a ComponentRef to a Path, if possible.
  If the component reference contains subscripts, it will silently fail.
"""
function crefToPath(inComponentRef::ComponentRef)::Path
  local outPath::Path

  @assign outPath = begin
    local i::Ident
    local p::Path
    local c::ComponentRef
    @match inComponentRef begin
      CREF_IDENT(name = i, subscripts = nil()) => begin
        IDENT(i)
      end

      CREF_QUAL(name = i, subscripts = nil(), componentRef = c) => begin
        @assign p = crefToPath(c)
        QUALIFIED(i, p)
      end

      CREF_FULLYQUALIFIED(componentRef = c) => begin
        @assign p = crefToPath(c)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""This function converts a Path to a ComponentRef."""
function pathToCref(inPath::Path)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    local i::Ident
    local c::ComponentRef
    local p::Path
    @match inPath begin
      IDENT(name = i) => begin
        CREF_IDENT(i, nil)
      end

      QUALIFIED(name = i, path = p) => begin
        @assign c = pathToCref(p)
        CREF_QUAL(i, nil, c)
      end

      FULLYQUALIFIED(p) => begin
        @assign c = pathToCref(p)
        crefMakeFullyQualified(c)
      end
    end
  end
  return outComponentRef
end

function crefSetLastSubs(
  inCref::ComponentRef,
  inSubscripts::List{<:Subscript},
)::ComponentRef
  local outCref::ComponentRef = inCref

  @assign outCref = begin
    @match outCref begin
      CREF_IDENT(__) => begin
        @assign outCref.subscripts = inSubscripts
        outCref
      end

      CREF_QUAL(__) => begin
        @assign outCref.componentRef = crefSetLastSubs(outCref.componentRef, inSubscripts)
        outCref
      end

      CREF_FULLYQUALIFIED(__) => begin
        @assign outCref.componentRef = crefSetLastSubs(outCref.componentRef, inSubscripts)
        outCref
      end
    end
  end
  return outCref
end

"""
  Author: BZ, 2009-09
  Extract subscripts of crefs.
"""
function getSubsFromCref(
  cr::ComponentRef,
  includeSubs::Bool,
  includeFunctions::Bool,
)::List{Subscript} #= note that if you say includeSubs = false then you won't get the functions from array subscripts =#
  local subscripts::List{Subscript}

  @assign subscripts = begin
    local subs2::List{Subscript}
    local child::ComponentRef
    @match (cr, includeSubs, includeFunctions) begin
      (CREF_IDENT(_, subs2), _, _) => begin
        subs2
      end

      (CREF_QUAL(_, subs2, child), _, _) => begin
        @assign subscripts = getSubsFromCref(child, includeSubs, includeFunctions)
        @assign subscripts = ListUtil.unionOnTrue(subscripts, subs2, subscriptEqual, Subscript)
        subscripts
      end

      (CREF_FULLYQUALIFIED(child), _, _) => begin
        @assign subscripts = getSubsFromCref(child, includeSubs, includeFunctions)
        subscripts
      end
    end
  end
  return subscripts
end

#=  stefan
=#

"""Returns first ident from a ComponentRef"""
function crefFirstIdent(inCref::ComponentRef)::Ident
  local outIdent::Ident

  @assign outIdent = begin
    @match inCref begin
      CREF_IDENT(__) => begin
        inCref.name
      end

      CREF_QUAL(__) => begin
        inCref.name
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefFirstIdent(inCref.componentRef)
      end
    end
  end
  return outIdent
end

function crefSecondIdent(cref::ComponentRef)::Ident
  local ident::Ident

  @assign ident = begin
    @match cref begin
      CREF_QUAL(__) => begin
        crefFirstIdent(cref.componentRef)
      end

      CREF_FULLYQUALIFIED(__) => begin
        crefSecondIdent(cref.componentRef)
      end
    end
  end
  return ident
end

"""Makes a component reference fully qualified unless it already is."""
function crefMakeFullyQualified(inComponentRef::ComponentRef)::ComponentRef
  local outComponentRef::ComponentRef

  @assign outComponentRef = begin
    @match inComponentRef begin
      CREF_FULLYQUALIFIED(__) => begin
        inComponentRef
      end

      _ => begin
        CREF_FULLYQUALIFIED(inComponentRef)
      end
    end
  end
  return outComponentRef
end

"""
  Checks if the name of a ComponentRef is
  equal to the name of another ComponentRef, including subscripts.
  See also crefEqualNoSubs.
"""
function crefEqual(iCr1::ComponentRef, iCr2::ComponentRef)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id::Ident
    local id2::Ident
    local ss1::List{Subscript}
    local ss2::List{Subscript}
    local cr1::ComponentRef
    local cr2::ComponentRef
    @matchcontinue (iCr1, iCr2) begin
      (CREF_IDENT(name = id, subscripts = ss1), CREF_IDENT(name = id2, subscripts = ss2)) => begin
        @match true = stringEq(id, id2)
        @match true = subscriptsEqual(ss1, ss2)
        true
      end

      (
        CREF_QUAL(name = id, subscripts = ss1, componentRef = cr1),
        CREF_QUAL(name = id2, subscripts = ss2, componentRef = cr2),
      ) => begin
        @match true = stringEq(id, id2)
        @match true = subscriptsEqual(ss1, ss2)
        @match true = crefEqual(cr1, cr2)
        true
      end

      (CREF_FULLYQUALIFIED(componentRef = cr1), CREF_FULLYQUALIFIED(componentRef = cr2)) => begin
        crefEqual(cr1, cr2)
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

function subscriptEqual(inSubscript1::Subscript, inSubscript2::Subscript)::Bool
  local outIsEqual::Bool

  @assign outIsEqual = begin
    local e1::Exp
    local e2::Exp
    @match (inSubscript1, inSubscript2) begin
      (NOSUB(__), NOSUB(__)) => begin
        true
      end

      (SUBSCRIPT(e1), SUBSCRIPT(e2)) => begin
        expEqual(e1, e2)
      end

      _ => begin
        false
      end
    end
  end
  return outIsEqual
end

"""Checks if two subscript lists are equal."""
function subscriptsEqual(inSubList1::List{<:Subscript}, inSubList2::List{<:Subscript})::Bool
  local outIsEqual::Bool

  @assign outIsEqual = ListUtil.isEqualOnTrue(inSubList1, inSubList2, subscriptEqual)
  return outIsEqual
end

"""
  Checks if the name of a ComponentRef is equal to the name
  of another ComponentRef without checking subscripts.
  See also crefEqual.
"""
function crefEqualNoSubs(cr1::ComponentRef, cr2::ComponentRef)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local rest1::ComponentRef
    local rest2::ComponentRef
    local id::Ident
    local id2::Ident
    @matchcontinue (cr1, cr2) begin
      (CREF_IDENT(name = id), CREF_IDENT(name = id2)) => begin
        @match true = stringEq(id, id2)
        true
      end

      (
        CREF_QUAL(name = id, componentRef = rest1),
        CREF_QUAL(name = id2, componentRef = rest2),
      ) => begin
        @match true = stringEq(id, id2)
        @match true = crefEqualNoSubs(rest1, rest2)
        true
      end

      (
        CREF_FULLYQUALIFIED(componentRef = rest1),
        CREF_FULLYQUALIFIED(componentRef = rest2),
      ) => begin
        crefEqualNoSubs(rest1, rest2)
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Returns true if two expressions are equal"""
function expEqual(exp1::Exp, exp2::Exp)::Bool
  local equal::Bool

  @assign equal = begin
    local b::Bool
    local x::Exp
    local y::Exp
    local i::Int
    local r::String
    #=  real vs. integer
    =#
    @matchcontinue (exp1, exp2) begin
      (INTEGER(i), REAL(r)) => begin
        @assign b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (REAL(r), INTEGER(i)) => begin
        @assign b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (x, y) => begin
        valueEq(x, y)
      end
    end
  end
  #=  anything else, exact match!
  =#
  return equal
end

IteratorIndexedCref = Tuple

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or OUTER()
"""
function isOuter(io::InnerOuter)::Bool
  local isItAnOuter::Bool

  @assign isItAnOuter = begin
    @match io begin
      INNER_OUTER(__) => begin
        true
      end

      OUTER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isItAnOuter
end

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or INNER()
"""
function isInner(io::InnerOuter)::Bool
  local isItAnInner::Bool

  @assign isItAnInner = begin
    @match io begin
      INNER_OUTER(__) => begin
        true
      end

      INNER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isItAnInner
end

"""Returns true if the InnerOuter is OUTER, false otherwise."""
function isOnlyOuter(inIO::InnerOuter)::Bool
  local outOnlyOuter::Bool

  @assign outOnlyOuter = begin
    @match inIO begin
      OUTER(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outOnlyOuter
end

"""Returns true if two InnerOuter's are equal"""
function innerOuterEqual(io1::InnerOuter, io2::InnerOuter)::Bool
  local res::Bool

  @assign res = begin
    @match (io1, io2) begin
      (INNER(__), INNER(__)) => begin
        true
      end

      (OUTER(__), OUTER(__)) => begin
        true
      end

      (INNER_OUTER(__), INNER_OUTER(__)) => begin
        true
      end

      (NOT_INNER_OUTER(__), NOT_INNER_OUTER(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""Makes a path not fully qualified unless it already is."""
function makeNotFullyQualified(inPath::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local path::Path
    @match inPath begin
      FULLYQUALIFIED(path) => begin
        path
      end

      _ => begin
        inPath
      end
    end
  end
  return outPath
end

"""Compares two import elements."""
function importEqual(im1::Import, im2::Import)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    local id::Ident
    local id2::Ident
    local p1::Path
    local p2::Path
    @matchcontinue (im1, im2) begin
      (NAMED_IMPORT(name = id, path = p1), NAMED_IMPORT(name = id2, path = p2)) => begin
        @match true = stringEq(id, id2)
        @match true = pathEqual(p1, p2)
        true
      end

      (QUAL_IMPORT(path = p1), QUAL_IMPORT(path = p2)) => begin
        @match true = pathEqual(p1, p2)
        true
      end

      (UNQUAL_IMPORT(path = p1), UNQUAL_IMPORT(path = p2)) => begin
        @match true = pathEqual(p1, p2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Transforms an if-expression to canonical form (without else-if branches)"""
function canonIfExp(inExp::Exp)::Exp
  local outExp::Exp

  @assign outExp = begin
    local cond::Exp
    local tb::Exp
    local eb::Exp
    local ei_cond::Exp
    local ei_tb::Exp
    local e::Exp
    local eib::List{Tuple{Exp, Exp}}
    @match inExp begin
      IFEXP(elseIfBranch = nil()) => begin
        inExp
      end

      IFEXP(
        ifExp = cond,
        trueBranch = tb,
        elseBranch = eb,
        elseIfBranch = (ei_cond, ei_tb) <| eib,
      ) => begin
        @assign e = canonIfExp(IFEXP(ei_cond, ei_tb, eb, eib))
        IFEXP(cond, tb, e, nil)
      end
    end
  end
  return outExp
end

function crefIdent(cr::ComponentRef)::String
  local str::String

  @match CREF_IDENT(str, nil) = cr
  return str
end

function pathIsIdent(inPath::Path)::Bool
  local outIsIdent::Bool

  @assign outIsIdent = begin
    @match inPath begin
      IDENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsIdent
end

function isInput(inDirection::Direction)::Bool
  local outIsInput::Bool

  @assign outIsInput = begin
    @match inDirection begin
      INPUT(__) => begin
        true
      end

      INPUT_OUTPUT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsInput
end

function isOutput(inDirection::Direction)::Bool
  local outIsOutput::Bool

  @assign outIsOutput = begin
    @match inDirection begin
      OUTPUT(__) => begin
        true
      end

      INPUT_OUTPUT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsOutput
end

function directionEqual(inDirection1::Direction, inDirection2::Direction)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (inDirection1, inDirection2) begin
      (BIDIR(__), BIDIR(__)) => begin
        true
      end

      (INPUT(__), INPUT(__)) => begin
        true
      end

      (OUTPUT(__), OUTPUT(__)) => begin
        true
      end

      (INPUT_OUTPUT(__), INPUT_OUTPUT(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

function isFieldEqual(isField1::IsField, isField2::IsField)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (isField1, isField2) begin
      (NONFIELD(__), NONFIELD(__)) => begin
        true
      end

      (FIELD(__), FIELD(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

# Current OMC signature: replace the last identifier by name.
function pathSetLastIdent(inPath::Path, ident::String)::Path
  return pathSetLastIdent(inPath, IDENT(ident))
end

function pathSetLastIdent(inPath::Path, inLastIdent::Path)::Path
  local outPath::Path

  @assign outPath = begin
    local p::Path
    local n::String
    @match (inPath, inLastIdent) begin
      (IDENT(__), _) => begin
        inLastIdent
      end

      (QUALIFIED(n, p), _) => begin
        @assign p = pathSetLastIdent(p, inLastIdent)
        QUALIFIED(n, p)
      end

      (FULLYQUALIFIED(p), _) => begin
        @assign p = pathSetLastIdent(p, inLastIdent)
        FULLYQUALIFIED(p)
      end
    end
  end
  return outPath
end

"""Returns the import name of a named or qualified import."""
function importName(inImport::Import)::Ident
  local outName::Ident

  @assign outName = begin
    local name::Ident
    local path::Path
    #=  Named import has a given name, 'import D = A.B.C' => D.
    =#
    @match inImport begin
      NAMED_IMPORT(name = name) => begin
        name
      end

      QUAL_IMPORT(path = path) => begin
        pathLastIdent(path)
      end
    end
  end
  #=  Qualified import uses the last identifier, 'import A.B.C' => C.
  =#
  return outName
end

"""
  This function takes an old annotation as first argument and a new
  annotation as  second argument and merges the two.
  Annotation \\\"parts\\\" that exist in both the old and the new annotation
  will be changed according to the new definition. For instance,
  merge_annotations(annotation(x=1,y=2),annotation(x=3))
  => annotation(x=3,y=2)
"""
function mergeAnnotations(inAnnotation1::Annotation, inAnnotation2::Annotation)::Annotation
  local outAnnotation::Annotation

  @assign outAnnotation = begin
    local oldmods::List{ElementArg}
    local newmods::List{ElementArg}
    local a::Annotation
    @match (inAnnotation1, inAnnotation2) begin
      (ANNOTATION(elementArgs = nil()), a) => begin
        a
      end

      (ANNOTATION(elementArgs = oldmods), ANNOTATION(elementArgs = newmods)) => begin
        ANNOTATION(mergeAnnotations2(oldmods, newmods))
      end
    end
  end
  return outAnnotation
end

function mergeAnnotations2(
  oldmods::List{<:ElementArg},
  newmods::List{<:ElementArg},
)::List{ElementArg}
  local res::List{ElementArg} = listReverse(oldmods)

  local mods::List{ElementArg}
  local b::Bool
  local p::Path
  local mod1::ElementArg
  local mod2::ElementArg

  for mod in newmods
    @match MODIFICATION(path = p) = mod
    try
      @assign mod2 = ListUtil.find(res, (p) -> isModificationOfPath(path = p))
      @assign mod1 = subModsInSameOrder(mod2, mod)
      @match (res, true) =
        ListUtil.replaceOnTrue(mod1, res, (p) -> isModificationOfPath(path = p), ElementArg)
    catch
      @assign res = _cons(mod, res)
    end
  end
  @assign res = listReverse(res)
  return res
end

"""returns true or false if the given path is in the list of modifications"""
function isModificationOfPath(mod::ElementArg, path::Path)::Bool
  local yes::Bool

  @assign yes = begin
    local id1::String
    local id2::String
    @match (mod, path) begin
      (MODIFICATION(path = IDENT(name = id1)), IDENT(name = id2)) => begin
        id1 == id2
      end

      _ => begin
        false
      end
    end
  end
  return yes
end

function subModsInSameOrder(oldmod::ElementArg, newmod::ElementArg)::ElementArg
  local mod::ElementArg

  @assign mod = begin
    local args1::List{ElementArg}
    local args2::List{ElementArg}
    local res::List{ElementArg}
    local arg2::ElementArg
    local eq1::EqMod
    local eq2::EqMod
    local p::Path
    #=  mod1 or mod2 has no submods
    =#
    @match (oldmod, newmod) begin
      (_, MODIFICATION(modification = NONE())) => begin
        newmod
      end

      (MODIFICATION(modification = NONE()), _) => begin
        newmod
      end

      (
        MODIFICATION(modification = SOME(CLASSMOD(args1, _))),
        arg2 && MODIFICATION(modification = SOME(CLASSMOD(args2, eq2))),
      ) => begin
        #=  mod1
        =#
        #=  Delete all items from args2 that are not in args1
        =#
        @assign res = nil
        for arg1 in args1
          @match MODIFICATION(path = p) = arg1
          if ListUtil.exist(args2, (p) -> isModificationOfPath(path = p))
            @assign res = _cons(arg1, res)
          end
        end
        @assign res = listReverse(res)
        #=  Merge the annotations
        =#
        @assign res = mergeAnnotations2(res, args2)
        @assign arg2.modification = SOME(CLASSMOD(res, eq2))
        arg2
      end
    end
  end
  return mod
end

function typeSpecString(inTs::TypeSpec)::String
  local outStr::String

  @assign outStr = Absyn.dumpTypeSpec(inTs)
  return outStr
end

function crefString(inCr::ComponentRef)::String
  local outStr::String

  @assign outStr = Absyn.dumpCref(inCr)
  return outStr
end

"""An import clause as Modelica, without `import` and the semicolon: `SI = Modelica.Units.SI`, `A.B`, `A.B.*`,
`A.{b, c = d}`."""
function importString(inImp::Import)::String
  return @match inImp begin
    NAMED_IMPORT(__) => inImp.name + " = " + Absyn.dumpPath(inImp.path)
    QUAL_IMPORT(__) => Absyn.dumpPath(inImp.path)
    UNQUAL_IMPORT(__) => Absyn.dumpPath(inImp.path) + ".*"
    GROUP_IMPORT(__) => Absyn.dumpPath(inImp.prefix) + ".{" +
      join(String[g isa GROUP_IMPORT_NAME ? g.name : (g::GROUP_IMPORT_RENAME).rename * " = " * g.name for g in inImp.groups],
           ", ") + "}"
  end
end

"""Helper function to getNamedAnnotationInElementitemlist."""
function getNamedAnnotationStr(
  inAbsynElementArgLst::List{<:ElementArg},
  id::Path,
  f::ModFunc,
)::Option{TypeA}
  local outString::Option{TypeA}

  @assign outString = begin
    local str::TypeA
    local ann::ElementArg
    local mod::Option{Modification}
    local xs::List{ElementArg}
    local id1::Ident
    local id2::Ident
    local rest::Path
    @matchcontinue (inAbsynElementArgLst, id, f) begin
      (MODIFICATION(path = IDENT(name = id1), modification = mod) <| _, IDENT(id2), _) =>
        begin
          @match true = stringEq(id1, id2)
          @assign str = f(mod)
          SOME(str)
        end

      (
        MODIFICATION(
          path = IDENT(name = id1),
          modification = SOME(CLASSMOD(elementArgLst = xs)),
        ) <| _,
        QUALIFIED(name = id2, path = rest),
        _,
      ) => begin
        @match true = stringEq(id1, id2)
        getNamedAnnotationStr(xs, rest, f)
      end

      (_ <| xs, _, _) => begin
        getNamedAnnotationStr(xs, id, f)
      end
    end
  end
  return outString
end

function isAlgorithmItem(inAlg::AlgorithmItem)::Bool
  local outIsClass::Bool

  @assign outIsClass = begin
    @match inAlg begin
      ALGORITHMITEM(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsClass
end

function isNamedPathIdent(path::Absyn.Path, name::String)::Bool
  local res::Bool

  @assign res = begin
    @match path begin
      IDENT(__) => begin
        path.name == name
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""An expression as Modelica (Absyn.jl's printer)."""
printExp(exp::Exp)::String = Absyn.dumpExp(exp)

@exportAll()
end
