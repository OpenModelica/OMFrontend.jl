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

using OpenModelicaParser.Absyn

import ..ListUtil

import ..Frontend.Util
import ..Frontend.System

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::Info


"""
  The ElementSpec type contains the name of the element, and this function
  extracts this name.
"""
function elementSpecName(inElementSpec::ElementSpec)::Ident

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

"""returns the componentRef of an expression if matches."""
function expCref(exp::Exp)::ComponentRef
  local cr::ComponentRef

  @match CREF(cr) = exp
  return cr
end

function printComponentRefStr(cr::ComponentRef)::String

  local s1::String
  local s2::String
  local child::ComponentRef
  @match cr begin
    CREF_IDENT(s1, _) => begin
      s1
    end

    CREF_QUAL(s1, _, child) => begin
      s2 = printComponentRefStr(child)
      s1 = s1 + "." + s2
      s1
    end

    CREF_FULLYQUALIFIED(child) => begin
      s2 = printComponentRefStr(child)
      s1 = "." + s2
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

"""Returns true if two paths are equal."""
function pathEqual(inPath1::Path, inPath2::Path)::Bool
  local outBoolean::Bool

  outBoolean = begin
    local id1::String
    local id2::String
    local res::Bool
    local path1::Path
    local path2::Path
    #= fully qual vs. path =#
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
        res = if stringEq(id1, id2)
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
  #= path vs. fully qual
     ident vs. ident
     qual ident vs. qual ident
     other return false =#
  return outBoolean
end

"""This function simply converts a Path to a string."""
function typeSpecPathString(tp::TypeSpec)::String

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

"""Converts a TypeSpec to Path"""
function typeSpecPath(tp::TypeSpec)::Path

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

"""Returns the dimensions of a TypeSpec."""
function typeSpecDimensions(inTypeSpec::TypeSpec)::ArrayDim

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

  #= First, calculate the length of the string to be generated =#
  p1 = if usefq
    path
  else
    makeNotFullyQualified(path)
  end
  _ = begin
    @match p1 begin
      IDENT(__) => begin
        #= Do not allocate memory if we're just going to copy the only identifier =#
        s = p1.name
        return s
        ()
      end
      _ => begin
        ()
      end
    end
  end
  p2 = p1
  b = true
  while b
    (p2, len, count, b) = begin
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
  s = pathStringWork(p1, (len - 1) * dlen + count, delimiter, dlen, reverse)
  return s
end

"""
I rewrote this to not use the string allocator - John
"""
function pathStringWork(
  inPath::Path,
  ::Int,
  delimiter::String,
  dlen::Int,
  ::Bool,
)::String
  local s::String
  local p::Path = inPath
  local b::Bool = true
  local count::Int = 0
  #= Allocate a string of the exact required length =#
  local sb = IOBuffer() #System.StringAllocator = System.StringAllocator(len)

  #= Fill the string =#
  while b
    (p, count, b) = begin
      @match p begin
        IDENT(__) => begin
          print(sb, p.name)
          (p, count + stringLength(p.name), false)
        end

        QUALIFIED(__) => begin
          print(sb, p.name)
          print(sb, delimiter)
          (p.path, count + stringLength(p.name) + dlen, true)
        end

        FULLYQUALIFIED(__) => begin
          print(sb, delimiter)
          (p.path, count + dlen, true)
        end
      end
    end
  end
  #= Return the string =#
  s = String(take!(sb))
  #  @info s
  return s
end

function pathCompare(ip1::Path, ip2::Path)::Int
  local o::Int

  o = begin
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
        o = stringCompare(i1, i2)
        o = if o == 0
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

  o = begin
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
        o = stringCompare(i1, i2)
        o = if o == 0
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
  local parts::Vector{SubString{String}} = split(str, ".")
  local path::Path = IDENT(String(parts[end]))
  for i in length(parts) - 1:-1:1
    path = QUALIFIED(String(parts[i]), path)
  end
  return path
end

"""Converts a list of strings into a qualified path."""
function stringListPath(paths::List{<:String})::Path

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
      p = stringListPath(rest_str)
      QUALIFIED(str, p)
    end
  end
end

"""Returns the last ident (after last dot) in a path"""
function pathLastIdent(inPath::Path)::String

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

"""Returns the last ident (after last dot) in a path"""
function pathLast(path::Path)::Path

  path = begin
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

function pathToStringList(path::Path)::List{String}
  local outPaths::List{String}

  outPaths = listReverse(pathToStringListWork(path, nil))
  return outPaths
end

function pathToStringListWork(path::Path, acc::List{<:String})::List{String}

  local n::String
  local p::Path
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

#= stefan =#

"""This function joins two paths"""
function joinPaths(inPath1::Path, inPath2::Path)::Path

  local str::Ident
  local p2::Path
  local p_1::Path
  local p::Path
  @match (inPath1, inPath2) begin
    (IDENT(name = str), p2) => begin
      QUALIFIED(str, p2)
    end

    (QUALIFIED(name = str, path = p), p2) => begin
      p_1 = joinPaths(p, p2)
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

"""
  This function converts a ComponentRef to a Path, if possible.
  If the component reference contains subscripts, it will silently fail.
"""
function crefToPath(inComponentRef::ComponentRef)::Path

  local i::Ident
  local p::Path
  local c::ComponentRef
  @match inComponentRef begin
    CREF_IDENT(name = i, subscripts = nil()) => begin
      IDENT(i)
    end

    CREF_QUAL(name = i, subscripts = nil(), componentRef = c) => begin
      p = crefToPath(c)
      QUALIFIED(i, p)
    end

    CREF_FULLYQUALIFIED(componentRef = c) => begin
      p = crefToPath(c)
      FULLYQUALIFIED(p)
    end
  end
end

"""This function converts a Path to a ComponentRef."""
function pathToCref(inPath::Path)::ComponentRef

  local i::Ident
  local c::ComponentRef
  local p::Path
  @match inPath begin
    IDENT(name = i) => begin
      CREF_IDENT(i, nil)
    end

    QUALIFIED(name = i, path = p) => begin
      c = pathToCref(p)
      CREF_QUAL(i, nil, c)
    end

    FULLYQUALIFIED(p) => begin
      c = pathToCref(p)
      crefMakeFullyQualified(c)
    end
  end
end

#= stefan =#

"""Returns first ident from a ComponentRef"""
function crefFirstIdent(inCref::ComponentRef)::Ident

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

"""Makes a component reference fully qualified unless it already is."""
function crefMakeFullyQualified(inComponentRef::ComponentRef)::ComponentRef

  @match inComponentRef begin
    CREF_FULLYQUALIFIED(__) => begin
      inComponentRef
    end

    _ => begin
      CREF_FULLYQUALIFIED(inComponentRef)
    end
  end
end

function subscriptEqual(inSubscript1::Subscript, inSubscript2::Subscript)::Bool

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

"""Returns true if two expressions are equal"""
function expEqual(exp1::Exp, exp2::Exp)::Bool
  local equal::Bool

  equal = begin
    local b::Bool
    local x::Exp
    local y::Exp
    local i::Int
    local r::String
    #= real vs. integer =#
    @matchcontinue (exp1, exp2) begin
      (INTEGER(i), REAL(r)) => begin
        b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (REAL(r), INTEGER(i)) => begin
        b = realEq(intReal(i), System.stringReal(r))
        b
      end

      (x, y) => begin
        valueEq(x, y)
      end
    end
  end
  #= anything else, exact match! =#
  return equal
end

IteratorIndexedCref = Tuple

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or OUTER()
"""
isOuter(io::InnerOuter)::Bool = isvariant(io, INNER_OUTER) || isvariant(io, OUTER)

"""
  @author: adrpo
  this function returns true if the given InnerOuter
  is one of INNER_OUTER() or INNER()
"""
isInner(io::InnerOuter)::Bool = isvariant(io, INNER_OUTER) || isvariant(io, INNER)

"""Returns true if the InnerOuter is OUTER, false otherwise."""
isOnlyOuter(inIO::InnerOuter)::Bool = isvariant(inIO, OUTER)

"""Makes a path not fully qualified unless it already is."""
function makeNotFullyQualified(inPath::Path)::Path

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

"""Compares two import elements."""
function importEqual(im1::Import, im2::Import)::Bool

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

pathIsIdent(inPath::Path)::Bool = isvariant(inPath, IDENT)

isInput(inDirection::Direction)::Bool = isvariant(inDirection, INPUT) || isvariant(inDirection, INPUT_OUTPUT)

isOutput(inDirection::Direction)::Bool = isvariant(inDirection, OUTPUT) || isvariant(inDirection, INPUT_OUTPUT)

"""Returns the import name of a named or qualified import."""
function importName(inImport::Import)::Ident
  local outName::Ident

  outName = begin
    local name::Ident
    local path::Path
    #= Named import has a given name, 'import D = A.B.C' => D. =#
    @match inImport begin
      NAMED_IMPORT(name = name) => begin
        name
      end

      QUAL_IMPORT(path = path) => begin
        pathLastIdent(path)
      end
    end
  end
  #= Qualified import uses the last identifier, 'import A.B.C' => C. =#
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

function mergeAnnotations2(
  oldmods::List{<:ElementArg},
  newmods::List{<:ElementArg},
)::List{ElementArg}
  local res::List{ElementArg} = listReverse(oldmods)

  local mod1::ElementArg
  local mod2::ElementArg

  for mod in newmods
    @match MODIFICATION(path = p) = mod
    try
      mod2 = ListUtil.find(res, (p) -> isModificationOfPath(path = p))
      mod1 = subModsInSameOrder(mod2, mod)
      @match (res, true) =
        ListUtil.replaceOnTrue(mod1, res, (p) -> isModificationOfPath(path = p), ElementArg)
    catch
      res = _cons(mod, res)
    end
  end
  res = listReverse(res)
  return res
end

"""returns true or false if the given path is in the list of modifications"""
function isModificationOfPath(mod::ElementArg, path::Path)::Bool

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

function subModsInSameOrder(oldmod::ElementArg, newmod::ElementArg)::ElementArg

  local args1::List{ElementArg}
  local args2::List{ElementArg}
  local res::List{ElementArg}
  local arg2::ElementArg
  local eq2::EqMod
  #= mod1 or mod2 has no submods =#
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
      #= mod1
         Delete all items from args2 that are not in args1 =#
      res = nil
      for arg1 in args1
        @match MODIFICATION(path = p) = arg1
        if ListUtil.exist(args2, (p) -> isModificationOfPath(path = p))
          res = _cons(arg1, res)
        end
      end
      res = listReverse(res)
      #= Merge the annotations =#
      res = mergeAnnotations2(res, args2)
      @assign arg2.modification = SOME(CLASSMOD(res, eq2))
      arg2
    end
  end
end

function typeSpecString(inTs::TypeSpec)::String
  local outStr::String

  outStr = Absyn.dumpTypeSpec(inTs)
  return outStr
end

function crefString(inCr::ComponentRef)::String
  local outStr::String

  outStr = Absyn.dumpCref(inCr)
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

isAlgorithmItem(inAlg::AlgorithmItem)::Bool = isvariant(inAlg, ALGORITHMITEM)

function isNamedPathIdent(path::Absyn.Path, name::String)::Bool

  @match path begin
    IDENT(__) => begin
      path.name == name
    end

    _ => begin
      false
    end
  end
end

"""An expression as Modelica (Absyn.jl's printer)."""
printExp(exp::Exp)::String = Absyn.dumpExp(exp)

@exportAll()
end
