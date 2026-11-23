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

module SCodeUtil

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

const FilterFunc = Function

import ..SCode
import OpenModelicaParser.Absyn

import ..Frontend.AbsynUtil
import ..Frontend.Util
import ..ListUtil

const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::SourceInfo

"""Removes submods from a modifier based on a filter function."""
function filterSubMods(mod::SCode.Mod, filter::FilterFunc)::SCode.Mod

  @assign mod = begin
    @match mod begin
      SCode.MOD(__) => begin
        @assign mod.subModLst = list(m for m in mod.subModLst if filter(m))
        begin
          @match mod begin
            SCode.MOD(subModLst = nil(), binding = NONE()) => begin
              SCode.NOMOD()
            end

            _ => begin
              mod
            end
          end
        end
      end

      _ => begin
        mod
      end
    end
  end
  return mod
end

function filterGivenSubModNames(submod::SCode.NAMEMOD; namesToKeep::List{String})
  listMember(submod.ident, namesToKeep)
end

function removeGivenSubModNames(submod::SCode.NAMEMOD; namesToRemove::List{String})
  !(listMember(submod.ident, namesToRemove))
end

"""The elements of a class's own parts (`model extends X` included), or `nil` for another class definition."""
function _classPartsElements(cls::SCode.Element)::List{SCode.Element}
  cls isa SCode.CLASS || return nil
  local cdef::SCode.ClassDef = cls.classDef
  cdef isa SCode.PARTS && return cdef.elementLst
  (cdef isa SCode.CLASS_EXTENDS && cdef.composition isa SCode.PARTS) && return cdef.composition.elementLst
  return nil
end

"""Whether `id` names an element of a class (`getElementNamed`)."""
function hasElementNamed(id::SCode.Ident, cls::SCode.Element)::Bool
  for e in _classPartsElements(cls)
    (e isa SCode.COMPONENT || e isa SCode.CLASS) && e.name == id && return true
  end
  return false
end

"""The first component or class named `id` of a class's parts; `fail()` when there is none (`hasElementNamed`)."""
function getElementNamed(id::SCode.Ident, cls::SCode.Element)::SCode.Element
  for e in _classPartsElements(cls)
    (e isa SCode.COMPONENT || e isa SCode.CLASS) && e.name == id && return e
  end
  fail()
end

"""Returns true if Variability is constant, otherwise false"""
isConstant(inVariability::SCode.Variability)::Bool = isvariant(inVariability, SCode.CONST)

"""retrieves the element info"""
function elementInfo(e::SCode.Element)::SourceInfo
  local info::SourceInfo

  @assign info = begin
    local i::SourceInfo
    @match e begin
      SCode.COMPONENT(info = i) => begin
        i
      end

      SCode.CLASS(info = i) => begin
        i
      end

      SCode.EXTENDS(info = i) => begin
        i
      end

      SCode.IMPORT(info = i) => begin
        i
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return info
end

function elementName(e::SCode.Element)::String
  local s::String

  @assign s = begin
    @match e begin
      SCode.COMPONENT(name = s) => begin
        s
      end

      SCode.CLASS(name = s) => begin
        s
      end
    end
  end
  return s
end

"""Gets all elements that have an element name from the list"""
function elementNames(elts::List{<:SCode.Element})::List{String}
  local names::List{String}

  @assign names = ListUtil.fold(elts, elementNamesWork, nil, List{String})
  return names
end

"""Gets all elements that have an element name from the list"""
function elementNamesWork(e::SCode.Element, acc::List{<:String})::List{String}

  local s::String
  @match (e, acc) begin
    (SCode.COMPONENT(name = s), _) => begin
      _cons(s, acc)
    end

    (SCode.CLASS(name = s), _) => begin
      _cons(s, acc)
    end

    _ => begin
      acc
    end
  end
end

function elementNameEqual(inElement1::SCode.Element, inElement2::SCode.Element)::Bool

  @match (inElement1, inElement2) begin
    (SCode.CLASS(__), SCode.CLASS(__)) => begin
      inElement1.name == inElement2.name
    end

    (SCode.COMPONENT(__), SCode.COMPONENT(__)) => begin
      inElement1.name == inElement2.name
    end

    (SCode.DEFINEUNIT(__), SCode.DEFINEUNIT(__)) => begin
      inElement1.name == inElement2.name
    end

    (SCode.EXTENDS(__), SCode.EXTENDS(__)) => begin
      AbsynUtil.pathEqual(inElement1.baseClassPath, inElement2.baseClassPath)
    end

    (SCode.IMPORT(__), SCode.IMPORT(__)) => begin
      AbsynUtil.importEqual(inElement1.imp, inElement2.imp)
    end

    _ => begin
      false
    end
  end
end

"""Return true if Class is a record."""
function isRecord(inClass::SCode.Element)::Bool

  @match inClass begin
    SCode.CLASS(restriction = SCode.R_RECORD(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""Return true if Class is a operator record."""
function isOperatorRecord(inClass::SCode.Element)::Bool

  @match inClass begin
    SCode.CLASS(restriction = SCode.R_RECORD(true)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""Return true if Class is a function."""
function isFunction(inClass::SCode.Element)::Bool

  @match inClass begin
    SCode.CLASS(restriction = SCode.R_FUNCTION(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""
  restriction is operator or operator function.
  Otherwise false is returned.
"""
function isOperator(el::SCode.Element)::Bool

  @match el begin
    SCode.CLASS(restriction = SCode.R_OPERATOR(__)) => begin
      true
    end

    SCode.CLASS(restriction = SCode.R_FUNCTION(SCode.FR_OPERATOR_FUNCTION(__))) => begin
      true
    end

    _ => begin
      false
    end
  end
end

#= stefan =#

"""This function returns the components from a class"""
function getClassElements(cl::SCode.Element)::List{SCode.Element}
  local elts::List{SCode.Element}

  @assign elts = begin
    @match cl begin
      SCode.CLASS(classDef = SCode.PARTS(elementLst = elts)) => begin
        elts
      end

      SCode.CLASS(
        classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = elts)),
      ) => begin
        elts
      end

      _ => begin
        nil
      end
    end
  end
  return elts
end

isComponent(elt::SCode.Element)::Bool = isvariant(elt, SCode.COMPONENT)

isClass(inElement::SCode.Element)::Bool = isvariant(inElement, SCode.CLASS)

const knownExternalCFunctions =
  list(
    "sin",
    "cos",
    "tan",
    "asin",
    "acos",
    "atan",
    "atan2",
    "sinh",
    "cosh",
    "tanh",
    "exp",
    "log",
    "log10",
    "sqrt",
  )::List

"""
The builtin name of an external or parallel function: one declared `external "builtin"` (its
external name, else its own), or an external "C" function of the known math functions (by its own
name, or by its external name with its output and its arguments the function's own); `""` for any
other function.
"""
function isBuiltinFunction(cl::SCode.Element, inVars::List{<:String}, outVars::List{<:String})::String
  (cl isa SCode.CLASS && cl.restriction isa SCode.R_FUNCTION && cl.classDef isa SCode.PARTS) || return ""
  local fres::SCode.FunctionRestriction = cl.restriction.functionRestriction
  local is_external::Bool = fres isa SCode.FR_EXTERNAL_FUNCTION
  (is_external || fres isa SCode.FR_PARALLEL_FUNCTION) || return ""
  local ext_opt::Option{SCode.EXTERNALDECL} = cl.classDef.externalDecl
  ext_opt === nothing && return ""
  local ext::SCode.EXTERNALDECL = something(ext_opt)
  local lang::String = ext.lang === nothing ? "" : something(ext.lang)
  local fn_name::String = ext.funcName === nothing ? cl.name : something(ext.funcName)
  lang == "builtin" && return fn_name
  (is_external && lang == "C" && listMember(fn_name, knownExternalCFunctions)) || return ""
  ext.funcName === nothing && return fn_name
  ext.output_ === nothing && return ""
  local out::Absyn.ComponentRef = something(ext.output_)
  (out isa Absyn.CREF_IDENT && listEmpty(out.subscripts)) || return ""
  (listLength(outVars) == 1 && listHead(outVars) == out.name) || return ""
  listLength(ext.args) == listLength(inVars) || return ""
  for (arg, var) in zip(ext.args, inVars)
    (arg isa Absyn.CREF && arg.componentRef isa Absyn.CREF_IDENT && arg.componentRef.name == var) || return ""
  end
  return fn_name
end

"""Extracts the SourceInfo from a Statement."""
function getStatementInfo(inStatement::SCode.Statement)::SourceInfo

  @match inStatement begin
    SCode.ALG_ASSIGN(__) => begin
      inStatement.info
    end

    SCode.ALG_IF(__) => begin
      inStatement.info
    end

    SCode.ALG_FOR(__) => begin
      inStatement.info
    end

    SCode.ALG_PARFOR(__) => begin
      inStatement.info
    end

    SCode.ALG_WHILE(__) => begin
      inStatement.info
    end

    SCode.ALG_WHEN_A(__) => begin
      inStatement.info
    end

    SCode.ALG_ASSERT(__) => begin
      inStatement.info
    end

    SCode.ALG_TERMINATE(__) => begin
      inStatement.info
    end

    SCode.ALG_REINIT(__) => begin
      inStatement.info
    end

    SCode.ALG_NORETCALL(__) => begin
      inStatement.info
    end

    SCode.ALG_RETURN(__) => begin
      inStatement.info
    end

    SCode.ALG_BREAK(__) => begin
      inStatement.info
    end

    SCode.ALG_FAILURE(__) => begin
      inStatement.info
    end

    SCode.ALG_TRY(__) => begin
      inStatement.info
    end

    SCode.ALG_CONTINUE(__) => begin
      inStatement.info
    end

    _ => begin
      Error.addInternalError("SCodeUtil.getStatementInfo failed", sourceInfo())
      AbsynUtil.dummyInfo
    end
  end
end

function prependSubModToMod(subMod::SCode.NAMEMOD, mod::SCode.Mod)
  mod = begin
    @match mod begin
      SCode.NOMOD(__)  => begin
        SCode.MOD(SCode.NOT_FINAL(),
                  SCode.NOT_EACH(),
                  list(subMod),
                  NONE(),
                  AbsynUtil.dummyInfo)
      end
      SCode.MOD(__)  => begin
        @assign mod.subModLst = _cons(subMod, mod.subModLst)
        mod
      end
    end
  end
  mod
end

"""returns true for PUBLIC and false for PROTECTED"""
function visibilityBool(inVisibility::SCode.Visibility)::Bool

  @match inVisibility begin
    SCode.PUBLIC(__) => begin
      true
    end

    SCode.PROTECTED(__) => begin
      false
    end
  end
end

eachBool(::SCode.EACH) = true
eachBool(::SCode.NOT_EACH) = false

function prefixesRedeclare(inPrefixes::SCode.PREFIXES)::SCode.Redeclare
  local outRedeclare::SCode.Redeclare

  @match SCode.PREFIXES(redeclarePrefix = outRedeclare) = inPrefixes
  return outRedeclare
end

function redeclareBool(inRedeclare::SCode.Redeclare)::Bool

  @match inRedeclare begin
    SCode.REDECLARE(__) => begin
      true
    end

    SCode.NOT_REDECLARE(__) => begin
      false
    end
  end
end

function boolRedeclare(inBoolRedeclare::Bool)::SCode.Redeclare

  @match inBoolRedeclare begin
    true => begin
      SCode.REDECLARE()
    end

    false => begin
      SCode.NOT_REDECLARE()
    end
  end
end

function replaceableBool(inReplaceable::SCode.Replaceable)::Bool

  @match inReplaceable begin
    SCode.REPLACEABLE(__) => begin
      true
    end

    SCode.NOT_REPLACEABLE(__) => begin
      false
    end
  end
end

function encapsulatedBool(inEncapsulated::SCode.Encapsulated)::Bool

  @match inEncapsulated begin
    SCode.ENCAPSULATED(__) => begin
      true
    end

    SCode.NOT_ENCAPSULATED(__) => begin
      false
    end
  end
end

function boolEncapsulated(inBoolEncapsulated::Bool)::SCode.Encapsulated

  @match inBoolEncapsulated begin
    true => begin
      SCode.ENCAPSULATED()
    end

    false => begin
      SCode.NOT_ENCAPSULATED()
    end
  end
end

function boolPartial(inBoolPartial::Bool)::SCode.Partial

  @match inBoolPartial begin
    true => begin
      SCode.PARTIAL()
    end

    false => begin
      SCode.NOT_PARTIAL()
    end
  end
end

function prefixesFinal(inPrefixes::SCode.PREFIXES)::SCode.Final
  local outFinal::SCode.Final

  @match SCode.PREFIXES(finalPrefix = outFinal) = inPrefixes
  return outFinal
end

function finalBool(inFinal::SCode.Final)::Bool

  @match inFinal begin
    SCode.FINAL(__) => begin
      true
    end

    SCode.NOT_FINAL(__) => begin
      false
    end
  end
end

function boolFinal(inBoolFinal::Bool)::SCode.Final
  local outFinal::SCode.Final

  @assign outFinal = if inBoolFinal
    SCode.FINAL()
  else
    SCode.NOT_FINAL()
  end
  return outFinal
end

function prefixesVisibility(inPrefixes::SCode.PREFIXES)::SCode.Visibility
  local outVisibility::SCode.Visibility

  @match SCode.PREFIXES(visibility = outVisibility) = inPrefixes
  return outVisibility
end

"""Returns the replaceable part"""
function prefixesReplaceable(prefixes::SCode.PREFIXES)::SCode.Replaceable
  local repl::SCode.Replaceable

  @match SCode.PREFIXES(replaceablePrefix = repl) = prefixes
  return repl
end

function elementPrefixes(inElement::SCode.Element)::SCode.PREFIXES

  local pf::SCode.PREFIXES
  @match inElement begin
    SCode.CLASS(prefixes = pf) => begin
      pf
    end

    SCode.COMPONENT(prefixes = pf) => begin
      pf
    end
  end
end

function isElementReplaceable(inElement::SCode.Element)::Bool
  local isReplaceable::Bool

  local pf::SCode.PREFIXES

  @assign pf = elementPrefixes(inElement)
  @assign isReplaceable = replaceableBool(prefixesReplaceable(pf))
  return isReplaceable
end

function isElementRedeclare(inElement::SCode.Element)::Bool
  local isRedeclare::Bool

  local pf::SCode.PREFIXES

  @assign pf = elementPrefixes(inElement)
  @assign isRedeclare = redeclareBool(prefixesRedeclare(pf))
  return isRedeclare
end

function prefixesInnerOuter(inPrefixes::SCode.PREFIXES)::Absyn.InnerOuter
  local outInnerOuter::Absyn.InnerOuter

  @match SCode.PREFIXES(innerOuter = outInnerOuter) = inPrefixes
  return outInnerOuter
end

"""Return the variability attribute from Attributes"""
function attrVariability(attr::SCode.ATTR)::SCode.Variability

  local v::SCode.Variability
  @match attr begin
    SCode.ATTR(variability = v) => begin
      v
    end
  end
end

"""The annotation of an extends, class or component element, or `NONE()`."""
function _elementAnnotation(element::SCode.Element)::Option{SCode.ANNOTATION}
  element isa SCode.EXTENDS && return element.ann
  element isa SCode.CLASS && return element.cmt.annotation_
  element isa SCode.COMPONENT && return element.comment.annotation_
  return NONE()
end

"""Whether the annotation of an element has an entry `name = value` (`getElementNamedAnnotation`)."""
function hasElementNamedAnnotation(element::SCode.Element, name::String)::Bool
  local annOpt::Option{SCode.ANNOTATION} = _elementAnnotation(element)
  isNone(annOpt) && return false
  local mod::SCode.Mod = Util.getOption(annOpt).modification
  mod isa SCode.MOD || return false
  for sm in mod.subModLst
    hasNamedAnnotation(sm, name) && return true
  end
  return false
end

"""
 Returns the annotation with the given name in the element, or fails if no
 such annotation could be found (`hasElementNamedAnnotation`).
"""
function getElementNamedAnnotation(element::SCode.Element, name::String)::Absyn.Exp
  local exp::Absyn.Exp
  local ann::SCode.ANNOTATION
  ann = begin
    @match element begin
      SCode.EXTENDS(ann = SOME(ann)) => begin
        ann
      end

      SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))) => begin
        ann
      end

      SCode.COMPONENT(comment = SCode.COMMENT(annotation_ = SOME(ann))) => begin
        ann
      end
    end
  end
  (exp, _) = getNamedAnnotation(ann, name)
  return exp
end

"""
  Checks if the given annotation contains an entry with the given name with the
  value true.
"""
function getNamedAnnotation(
  inAnnotation::SCode.ANNOTATION,
  inName::String,
)::Tuple{Absyn.Exp, SourceInfo}
  local info::SourceInfo
  local exp::Absyn.Exp

  local submods::List{SCode.NAMEMOD}

  @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = inAnnotation
  @match SCode.NAMEMOD(mod = SCode.MOD(info = info, binding = SOME(exp))) =
    ListUtil.find1(submods, hasNamedAnnotation, inName)
  return (exp, info)
end

"""
  Checks if a submod has the same name as the given name, and if its binding
  in that case is true.
"""
function hasNamedAnnotation(inSubMod::SCode.NAMEMOD, inName::String)::Bool

  local id::String
  @match (inSubMod, inName) begin
    (SCode.NAMEMOD(ident = id, mod = SCode.MOD(binding = SOME(_))), _) => begin
      stringEq(id, inName)
    end

    _ => begin
      false
    end
  end
end

"""
  Returns the modifier with the given name if it can be found in the
  annotation, otherwise an empty modifier.
"""
function lookupNamedAnnotation(ann::SCode.ANNOTATION, name::String)::SCode.Mod
  local mod::SCode.Mod

  local submods::List{SCode.NAMEMOD}
  local id::String

  @assign mod = begin
    @match ann begin
      SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) => begin
        for sm in submods
          @match SCode.NAMEMOD(id, mod) = sm
          if id == name
            return mod
          end
        end
        SCode.NOMOD()
      end

      _ => begin
        SCode.NOMOD()
      end
    end
  end
  return mod
end

"""Returns a list of modifiers with the given name found in the annotation."""
function lookupNamedAnnotations(ann::SCode.ANNOTATION, name::String)::List{SCode.Mod}
  local mods::List{SCode.Mod} = nil

  local submods::List{SCode.NAMEMOD}
  local id::String
  local mod::SCode.Mod

  @assign mods = begin
    @match ann begin
      SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) => begin
        for sm in submods
          @match SCode.NAMEMOD(id, mod) = sm
          if id == name
            @assign mods = _cons(mod, mods)
          end
        end
        mods
      end

      _ => begin
        nil
      end
    end
  end
  return mods
end

function hasBooleanNamedAnnotationInClass(
  inClass::SCode.Element,
  namedAnnotation::String,
)::Bool

  local ann::SCode.ANNOTATION
  @match (inClass, namedAnnotation) begin
    (SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))), _) => begin
      hasBooleanNamedAnnotation(ann, namedAnnotation)
    end

    _ => begin
      false
    end
  end
end

"""check if the named annotation is present and has value true"""
function commentHasBooleanNamedAnnotation(comm::SCode.COMMENT, annotationName::String)::Bool

  local ann::SCode.ANNOTATION
  @match (comm, annotationName) begin
    (SCode.COMMENT(annotation_ = SOME(ann)), _) => begin
      hasBooleanNamedAnnotation(ann, annotationName)
    end

    _ => begin
      false
    end
  end
end

"""
  Checks if the given annotation contains an entry with the given name with the
  value true.
"""
function hasBooleanNamedAnnotation(inAnnotation::SCode.ANNOTATION, inName::String)::Bool
  local outHasEntry::Bool

  local submods::List{SCode.NAMEMOD}

  @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = inAnnotation
  @assign outHasEntry = ListUtil.exist1(submods, hasBooleanNamedAnnotation2, inName)
  return outHasEntry
end

"""
  Checks if a submod has the same name as the given name, and if its binding
  in that case is true.
"""
function hasBooleanNamedAnnotation2(inSubMod::SCode.NAMEMOD, inName::String)::Bool

  local id::String
  @match inSubMod begin
    SCode.NAMEMOD(ident = id, mod = SCode.MOD(binding = SOME(Absyn.BOOL(value = true)))) => begin
      stringEq(id, inName)
    end

    _ => begin
      false
    end
  end
end

"""
  @author: adrpo
  returns true if annotation(Evaluate = true) is present,
  otherwise false
"""
# Pinned-OMC API: bare Comment in, Option{Bool} out (SOME(v) only for a
# boolean-valued Evaluate annotation). The Option{Comment} -> Bool method below
# serves the old frontend; the translated NF calls this one.
function getEvaluateAnnotation(cmt::SCode.COMMENT)::Option{Bool}
  if cmt isa SCode.COMMENT && isSome(cmt.annotation_)
    local ann = Util.getOption(cmt.annotation_)
    local mod = lookupNamedAnnotation(ann, "Evaluate")
    if mod isa SCode.MOD && isSome(mod.binding)
      local bexp = Util.getOption(mod.binding)
      if bexp isa Absyn.BOOL
        return SOME(bexp.value)
      end
    end
  end
  return NONE()
end

function getEvaluateAnnotation(inCommentOpt::Option{<:SCode.COMMENT})::Bool

  local ann::SCode.ANNOTATION
  @match inCommentOpt begin
    SOME(SCode.COMMENT(annotation_ = SOME(ann))) => begin
      hasBooleanNamedAnnotation(ann, "Evaluate")
    end

    _ => begin
      false
    end
  end
end

function getModifierBinding(inMod::SCode.Mod)::Option{Absyn.Exp}

  local binding::Absyn.Exp
  @match inMod begin
    SCode.MOD(binding = SOME(binding)) => begin
      SOME(binding)
    end

    _ => begin
      NONE()
    end
  end
end

function isElementProtected(inElement::SCode.Element)::Bool
  local outIsProtected::Bool

  @assign outIsProtected = !visibilityBool(elementVisibility(inElement))
  return outIsProtected
end

function elementVisibility(element::SCode.Element)::SCode.Visibility
  return @match element begin
    SCode.IMPORT(__) => element.visibility
    SCode.EXTENDS(__) => element.visibility
    SCode.CLASS(__) => prefixesVisibility(element.prefixes)
    SCode.COMPONENT(__) => prefixesVisibility(element.prefixes)
    SCode.DEFINEUNIT(__) => element.visibility
  end
end

function isElementEncapsulated(inElement::SCode.Element)::Bool

  @match inElement begin
    SCode.CLASS(encapsulatedPrefix = SCode.ENCAPSULATED(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""
 Replace the element in program at the specified path (includes the element name).
 if the element does not exist at that location then it fails.
 this function will fail if any of the path prefixes
 to the element are not found in the given program
"""
function replaceOrAddElementInProgram(
  inProgram::SCode.Program,
  inElement::SCode.Element,
  inClassPath::Absyn.Path,
)::SCode.Program
  local sp::SCode.Program
  local e::SCode.Element
  local p::Absyn.Path
  local i::Absyn.Ident
  @match (inProgram, inElement, inClassPath) begin
    (_, _, Absyn.QUALIFIED(i, p)) => begin
      e = getElementWithId(inProgram, i)
      sp = getElementsFromElement(inProgram, e)
      sp = replaceOrAddElementInProgram(sp, inElement, p)
      e = replaceElementsInElement(inProgram, e, sp)
      sp = replaceOrAddElementWithId(inProgram, e, i)
      sp
    end

    (_, _, Absyn.IDENT(i)) => begin
      sp = replaceOrAddElementWithId(inProgram, inElement, i)
      sp
    end

    (_, _, Absyn.FULLYQUALIFIED(p)) => begin
      sp = replaceOrAddElementInProgram(inProgram, inElement, p)
      sp
    end
  end
end

"""
  replace the class in program at the specified id.
  if the class does not exist at that location then is is added
"""
function replaceOrAddElementWithId(
  inProgram::SCode.Program,
  inElement::SCode.Element,
  inId::SCode.Ident,
)::SCode.Program
  local outProgram::SCode.Program

  @assign outProgram = begin
    local sp::SCode.Program
    local rest::SCode.Program
    local e::SCode.Element
    local p::Absyn.Path
    local i::Absyn.Ident
    local n::Absyn.Ident
    @matchcontinue (inProgram, inElement, inId) begin
      (SCode.CLASS(name = n) <| rest, _, i) => begin
        @match true = stringEq(n, i)
        _cons(inElement, rest)
      end

      (SCode.COMPONENT(name = n) <| rest, _, i) => begin
        @match true = stringEq(n, i)
        _cons(inElement, rest)
      end

      (SCode.EXTENDS(baseClassPath = p) <| rest, _, i) => begin
        @match true = stringEq(AbsynUtil.pathString(p), i)
        _cons(inElement, rest)
      end

      (e <| rest, _, i) => begin
        @assign sp = replaceOrAddElementWithId(rest, inElement, i)
        _cons(e, sp)
      end

      (nil(), _, _) => begin
        @assign sp = list(inElement)
        sp
      end
    end
  end
  #= not found, add it =#
  return outProgram
end

function getElementsFromElement(
  inProgram::SCode.Program,
  inElement::SCode.Element,
)::SCode.Program
  local outProgram::SCode.Program

  @assign outProgram = begin
    local els::SCode.Program
    local e::SCode.Element
    local p::Absyn.Path
    #= a class with parts =#
    @match (inProgram, inElement) begin
      (_, SCode.CLASS(classDef = SCode.PARTS(elementLst = els))) => begin
        els
      end

      (
        _,
        SCode.CLASS(
          classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = els)),
        ),
      ) => begin
        els
      end

      (_, SCode.CLASS(classDef = SCode.DERIVED(typeSpec = Absyn.TPATH(path = p)))) =>
        begin
          @assign e = getElementWithPath(inProgram, p)
          @assign els = getElementsFromElement(inProgram, e)
          els
        end
    end
  end
  #= a class extends
     a derived class =#
  return outProgram
end

"""replaces elements in element, it will search for elements pointed by derived"""
function replaceElementsInElement(
  inProgram::SCode.Program,
  inElement::SCode.Element,
  inElements::List,
)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local e::SCode.Element
    local name::SCode.Ident #= the name of the class =#
    local prefixes::SCode.PREFIXES #= the common class or component prefixes =#
    local encapsulatedPrefix::SCode.Encapsulated #= the encapsulated prefix =#
    local partialPrefix::SCode.Partial #= the partial prefix =#
    local restriction::SCode.Restriction #= the restriction of the class =#
    local classDef::SCode.ClassDef #= the class specification =#
    local info::SourceInfo #= the class information =#
    local cmt::SCode.COMMENT
    #= a class with parts, non derived =#
    @matchcontinue (inProgram, inElement, inElements) begin
      (
        _,
        SCode.CLASS(
          name,
          prefixes,
          encapsulatedPrefix,
          partialPrefix,
          restriction,
          classDef,
          cmt,
          info,
        ),
        _,
      ) => begin
        @match (classDef, NONE()) =
          replaceElementsInClassDef(inProgram, classDef, inElements)
        SCode.CLASS(
          name,
          prefixes,
          encapsulatedPrefix,
          partialPrefix,
          restriction,
          classDef,
          cmt,
          info,
        )
      end

      (_, SCode.CLASS(classDef = classDef), _) => begin
        @match (classDef, SOME(e)) =
          replaceElementsInClassDef(inProgram, classDef, inElements)
        e
      end
    end
  end
  #= a class derived =#
  return outElement
end

"""
  Replaces the elements in class definition.
  if derived a SOME(element) is returned,
  otherwise the modified class def and NONE()
"""
function replaceElementsInClassDef(
  inProgram::SCode.Program,
  classDef::SCode.ClassDef,
  inElements::SCode.Program,
)::Tuple{SCode.ClassDef, Option{SCode.Element}}
  local outElementOpt::Option{SCode.Element}

  @assign outElementOpt = begin
    local e::SCode.Element
    local p::Absyn.Path
    local composition::SCode.ClassDef
    #= a derived class =#
    @match classDef begin
      SCode.DERIVED(typeSpec = Absyn.TPATH(path = p)) => begin
        @assign e = getElementWithPath(inProgram, p)
        @assign e = replaceElementsInElement(inProgram, e, inElements)
        SOME(e)
      end

      SCode.PARTS(__) => begin
        #= a parts =#
        @assign classDef.elementLst = inElements
        NONE()
      end

      SCode.CLASS_EXTENDS(composition = composition) => begin
        #= a class extends =#
        @assign (composition, outElementOpt) =
          replaceElementsInClassDef(inProgram, composition, inElements)
        if isNone(outElementOpt)
          @assign classDef.composition = composition
        end
        outElementOpt
      end
    end
  end
  return (classDef, outElementOpt)
end

"""
  returns the element from the program having the name as the id.
  if the element does not exist it fails
"""
function getElementWithId(inProgram::SCode.Program, inId::String)::SCode.Element

  local rest::SCode.Program
  local e::SCode.Element
  local p::Absyn.Path
  local i::Absyn.Ident
  local n::Absyn.Ident
  @match (inProgram, inId) begin
    (e <| _ && SCode.CLASS(name = n) <| _, i) where {(stringEq(n, i))} => begin
      e
    end

    (e <| _ && SCode.COMPONENT(name = n) <| _, i) where {(stringEq(n, i))} => begin
      e
    end

    (
      e <| _ && SCode.EXTENDS(baseClassPath = p) <| _,
      i,
    ) where {(stringEq(AbsynUtil.pathString(p), i))} => begin
      e
    end

    (_ <| rest, i) => begin
      getElementWithId(rest, i)
    end
  end
end

"""
  returns the element from the program having the name as the id.
  if the element does not exist it fails
"""
function getElementWithPath(inProgram::SCode.Program, inPath::Absyn.Path)::SCode.Element

  local sp::SCode.Program
  local e::SCode.Element
  local p::Absyn.Path
  local i::Absyn.Ident
  @match (inProgram, inPath) begin
    (_, Absyn.FULLYQUALIFIED(p)) => begin
      getElementWithPath(inProgram, p)
    end

    (_, Absyn.IDENT(i)) => begin
      @assign e = getElementWithId(inProgram, i)
      e
    end

    (_, Absyn.QUALIFIED(i, p)) => begin
      @assign e = getElementWithId(inProgram, i)
      @assign sp = getElementsFromElement(inProgram, e)
      @assign e = getElementWithPath(sp, p)
      e
    end
  end
end

"""
  @auhtor: adrpo
  get the modification in component
"""
function getComponentMod(inE::SCode.Element)::SCode.Mod
  local outMod::SCode.Mod

  @match SCode.COMPONENT(modifications = outMod) = inE
  return outMod
end

function isClassExtends(cls::SCode.Element)::Bool

  @match cls begin
    SCode.CLASS(classDef = SCode.CLASS_EXTENDS(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

function getClassDef(inClass::SCode.Element)::SCode.ClassDef
  local outCdef::SCode.ClassDef

  @assign outCdef = begin
    @match inClass begin
      SCode.CLASS(classDef = outCdef) => begin
        outCdef
      end
    end
  end
  return outCdef
end

#= A break of an inherited component or connect-equation (Modelica 3.6; omc isBreakSubMod). =#
function isBreakSubMod(subMod::SCode.NAMEMOD)::Bool
  return subMod.mod isa SCode.BREAK_COMPONENT || subMod.mod isa SCode.BREAK_CONNECT
end

function getClassRestriction(inElement::SCode.Element)::SCode.Restriction
  local outRestriction::SCode.Restriction

  @match SCode.CLASS(restriction = outRestriction) = inElement
  return outRestriction
end

function isBuiltinElement(inElement::SCode.Element)::Bool

  local ann::SCode.ANNOTATION
  @match inElement begin
    SCode.CLASS(
      classDef = SCode.PARTS(
        externalDecl = SOME(SCode.EXTERNALDECL(lang = SOME("builtin"))),
      ),
    ) => begin
      true
    end

    SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))) => begin
      hasBooleanNamedAnnotation(ann, "__OpenModelica_builtin")
    end

    _ => begin
      false
    end
  end
end

function isRestrictionImpure(inRestr::SCode.Restriction, hasZeroOutputPreMSL3_2::Bool)::Bool

  @match (inRestr, hasZeroOutputPreMSL3_2) begin
    (SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(true)), _) => begin
      true
    end

    (SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(true)), _) => begin
      true
    end

    (SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(false)), false) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""Returns the comment of an element."""
function getElementComment(inElement::SCode.Element)::Option{SCode.COMMENT}

  local cmt::SCode.COMMENT
  @match inElement begin
    SCode.COMPONENT(comment = cmt) => begin
      SOME(cmt)
    end

    SCode.CLASS(cmt = cmt) => begin
      SOME(cmt)
    end

    _ => begin
      NONE()
    end
  end
end

function mergeModifiers(inNewMod::SCode.Mod, inOldMod::SCode.Mod)::SCode.Mod

  local f1::SCode.Final
  local f2::SCode.Final
  local e1::SCode.Each
  local e2::SCode.Each
  local sl1::List{SCode.NAMEMOD}
  local sl2::List{SCode.NAMEMOD}
  local sl::List{SCode.NAMEMOD}
  local b1::Option{Absyn.Exp}
  local b2::Option{Absyn.Exp}
  local b::Option{Absyn.Exp}
  local i1::SourceInfo
  local m::SCode.Mod
  @matchcontinue (inNewMod, inOldMod) begin
    (_, SCode.NOMOD(__)) => begin
      inNewMod
    end

    (SCode.NOMOD(__), _) => begin
      inOldMod
    end

    (SCode.REDECL(__), _) => begin
      inNewMod
    end

    (SCode.MOD(f1, e1, sl1, b1, i1), SCode.MOD(f2, e2, sl2, b2, _)) => begin
      @assign b = mergeBindings(b1, b2)
      @assign sl = mergeSubMods(sl1, sl2)
      if referenceEq(b, b1) && referenceEq(sl, sl1)
        @assign m = inNewMod
      elseif referenceEq(b, b2) &&
             referenceEq(sl, sl2) &&
             valueEq(f1, f2) &&
             valueEq(e1, e2)
        @assign m = inOldMod
      else
        @assign m = SCode.MOD(f1, e1, sl, b, i1)
      end
      m
    end

    _ => begin
      inNewMod
    end
  end
end

function mergeBindings(
  inNew::Option{<:Absyn.Exp},
  inOld::Option{<:Absyn.Exp},
)::Option{Absyn.Exp}

  @match (inNew, inOld) begin
    (SOME(_), _) => begin
      inNew
    end

    (NONE(), _) => begin
      inOld
    end
  end
end

function mergeSubMods(
  inNew::List{<:SCode.NAMEMOD},
  inOld::List{<:SCode.NAMEMOD},
)::List{SCode.NAMEMOD}

  local sl::List{SCode.NAMEMOD}
  local rest::List{SCode.NAMEMOD}
  local old::List{SCode.NAMEMOD}
  local s::SCode.NAMEMOD
  @matchcontinue (inNew, inOld) begin
    (nil(), _) => begin
      inOld
    end

    (s <| rest, _) => begin
      @assign old = removeSub(s, inOld)
      @assign sl = mergeSubMods(rest, old)
      _cons(s, sl)
    end

    _ => begin
      inNew
    end
  end
end

function removeSub(inSub::SCode.NAMEMOD, inOld::List{<:SCode.NAMEMOD})::List{SCode.NAMEMOD}

  local rest::List{SCode.NAMEMOD}
  local id1::SCode.Ident
  local id2::SCode.Ident
  local s::SCode.NAMEMOD
  @matchcontinue (inSub, inOld) begin
    (_, nil()) => begin
      inOld
    end

    (SCode.NAMEMOD(ident = id1), SCode.NAMEMOD(ident = id2) <| rest) => begin
      @match true = stringEqual(id1, id2)
      rest
    end

    (_, s <| rest) => begin
      @assign rest = removeSub(inSub, rest)
      _cons(s, rest)
    end
  end
end

"""Return true if Class is a partial."""
function isPackage(inClass::SCode.Element)::Bool

  @match inClass begin
    SCode.CLASS(restriction = SCode.R_PACKAGE(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

"""Return true if Class is a partial."""
function isPartial(inClass::SCode.Element)::Bool

  @match inClass begin
    SCode.CLASS(partialPrefix = SCode.PARTIAL(__)) => begin
      true
    end

    _ => begin
      false
    end
  end
end

isEmptyMod(mod::SCode.Mod)::Bool = isvariant(mod, SCode.NOMOD)

function getConstrainingMod(element::SCode.Element)::SCode.Mod
  local mod::SCode.Mod

  @assign mod = begin
    @match element begin
      SCode.CLASS(
        prefixes = SCode.PREFIXES(
          replaceablePrefix = SCode.REPLACEABLE(
            cc = SOME(SCode.CONSTRAINCLASS(modifier = mod)),
          ),
        ),
      ) => begin
        mod
      end

      SCode.CLASS(classDef = SCode.DERIVED(modifications = mod)) => begin
        mod
      end

      SCode.COMPONENT(
        prefixes = SCode.PREFIXES(
          replaceablePrefix = SCode.REPLACEABLE(
            cc = SOME(SCode.CONSTRAINCLASS(modifier = mod)),
          ),
        ),
      ) => begin
        mod
      end

      SCode.COMPONENT(modifications = mod) => begin
        mod
      end

      _ => begin
        SCode.NOMOD()
      end
    end
  end
  return mod
end

function isEmptyClassDef(cdef::SCode.ClassDef)::Bool

  @match cdef begin
    SCode.PARTS(__) => begin
      listEmpty(cdef.elementLst) &&
        listEmpty(cdef.normalEquationLst) &&
        listEmpty(cdef.initialEquationLst) &&
        listEmpty(cdef.normalAlgorithmLst) &&
        listEmpty(cdef.initialAlgorithmLst) &&
        isNone(cdef.externalDecl)
    end

    SCode.CLASS_EXTENDS(__) => begin
      isEmptyClassDef(cdef.composition)
    end

    SCode.ENUMERATION(__) => begin
      listEmpty(cdef.enumLst)
    end

    _ => begin
      true
    end
  end
end

function mergeSCodeOptAnn(
  inModOuter::Option{<:SCode.ANNOTATION},
  inModInner::Option{<:SCode.ANNOTATION},
)::Option{SCode.ANNOTATION}

  local mod1::SCode.Mod
  local mod2::SCode.Mod
  local mod::SCode.Mod
  @match (inModOuter, inModInner) begin
    (NONE(), _) => begin
      inModInner
    end

    (_, NONE()) => begin
      inModOuter
    end

    (SOME(SCode.ANNOTATION(mod1)), SOME(SCode.ANNOTATION(mod2))) => begin
      @assign mod = SCodeUtil.mergeSCodeMods(mod1, mod2)
      SOME(SCode.ANNOTATION(mod))
    end
  end
end

function mergeSCodeMods(inModOuter::SCode.Mod, inModInner::SCode.Mod)::SCode.Mod

  local f1::SCode.Final
  local e1::SCode.Each
  local subMods1::List{SCode.NAMEMOD}
  local subMods2::List{SCode.NAMEMOD}
  local b1::Option{Absyn.Exp}
  local b2::Option{Absyn.Exp}
  local info::SourceInfo
  @match (inModOuter, inModInner) begin
    (SCode.NOMOD(__), _) => begin
      inModInner
    end

    (_, SCode.NOMOD(__)) => begin
      inModOuter
    end

    (SCode.MOD(f1, e1, subMods1, b1, info), SCode.MOD(_, _, subMods2, b2, _)) => begin
      @assign subMods2 = listAppend(subMods1, subMods2)
      @assign b1 = if isSome(b1)
        b1
      else
        b2
      end
      SCode.MOD(f1, e1, subMods2, b1, info)
    end
  end
end

#= Functions needed by translated NFFrontEnd =#

"""Look up an annotation by name, returning its modifier or NOMOD."""
function lookupAnnotation(ann::SCode.ANNOTATION, name::String)::SCode.Mod
  local mod::SCode.Mod
  mod = begin
    local submods::List{SCode.NAMEMOD}
    @match ann begin
      SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) => begin
        for sm in submods
          @match SCode.NAMEMOD(ident = id, mod = m) = sm
          if id == name
            return m
          end
        end
        SCode.NOMOD()
      end
      _ => SCode.NOMOD()
    end
  end
  return mod
end

function lookupAnnotationBinding(ann::SCode.ANNOTATION, name::String)::Option{Absyn.Exp}
  return getModifierBinding(lookupAnnotation(ann, name))
end

"""Look up an annotation on an SCode element (CLASS or COMPONENT)."""
function lookupElementAnnotation(elem::SCode.Element, name::String)::SCode.Mod
  local ann::SCode.ANNOTATION
  @match elem begin
    SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))) => lookupAnnotation(ann, name)
    SCode.COMPONENT(comment = SCode.COMMENT(annotation_ = SOME(ann))) => lookupAnnotation(ann, name)
    _ => SCode.NOMOD()
  end
end

"""Look up the binding of an annotation on an SCode element."""
function lookupElementAnnotationBinding(elem::SCode.Element, name::String)::Option{Absyn.Exp}
  local binding::Option{Absyn.Exp}
  local mod::SCode.Mod = lookupElementAnnotation(elem, name)
  binding = @match mod begin
    SCode.MOD(binding = b) => b
    _ => nothing
  end
  return binding
end

"""Check if a class definition has equation or algorithm sections."""
#= Whether the class definition directly contains any sections (with checkExternal, also an
   external declaration); omc SCodeUtil.classDefHasSections. =#
function classDefHasSections(classDef::SCode.ClassDef, checkExternal::Bool = false)::Bool
  local hasSections::Bool
  hasSections = @match classDef begin
    SCode.PARTS() => begin
      !(listEmpty(classDef.normalEquationLst) &&
        listEmpty(classDef.initialEquationLst) &&
        listEmpty(classDef.normalAlgorithmLst) &&
        listEmpty(classDef.initialAlgorithmLst) &&
        (!checkExternal || isNone(classDef.externalDecl)))
    end
    SCode.CLASS_EXTENDS() => classDefHasSections(classDef.composition, checkExternal)
    _ => false
  end
  return hasSections
end

"""The class body (ClassDef) of a CLASS element; for a class extends, the definition it contains."""
function getClassBody(elem::SCode.Element)::SCode.ClassDef
  local classDef::SCode.ClassDef
  @match SCode.CLASS(classDef = classDef) = elem
  return @match classDef begin
    SCode.CLASS_EXTENDS(__) => classDef.composition
    _ => classDef
  end
end

"""Check if an algorithm section is non-empty."""
function isNonEmptyAlgorithm(alg::SCode.ALGORITHM)::Bool
  local nonEmpty::Bool
  nonEmpty = @match alg begin
    SCode.ALGORITHM(statements = stmts) => !listEmpty(stmts)
    _ => false
  end
  return nonEmpty
end

"""Extract SourceInfo from an SCode equation."""
function getEquationInfo(eq::SCode.EEquation)::SourceInfo
  local info::SourceInfo
  info = @match eq begin
    SCode.EQ_IF(info = i) => i
    SCode.EQ_EQUALS(info = i) => i
    SCode.EQ_PDE(info = i) => i
    SCode.EQ_CONNECT(info = i) => i
    SCode.EQ_FOR(info = i) => i
    SCode.EQ_WHEN(info = i) => i
    SCode.EQ_ASSERT(info = i) => i
    SCode.EQ_TERMINATE(info = i) => i
    SCode.EQ_REINIT(info = i) => i
    SCode.EQ_NORETCALL(info = i) => i
    _ => AbsynUtil.dummyInfo
  end
  return info
end

"""Map a function over expressions in statements. Stub - returns unchanged."""
function mapStatementExps(stmt::SCode.Statement, _)::SCode.Statement
  return stmt
end

@exportAll()
end
