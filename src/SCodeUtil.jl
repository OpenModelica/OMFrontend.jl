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
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

const FilterFunc = Function
const FoldFunc = Function
const TraverseFunc = Function

import SCode
import Absyn

import ..Frontend.AbsynUtil
import ..Frontend.Util
import ListUtil

const Argument = Any
const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::SourceInfo

"""Removes all submodifiers from the Mod."""
function stripSubmod(inMod::SCode.Mod)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local fp::SCode.Final
    local ep::SCode.Each
    local binding::Option{Absyn.Exp}
    local info::SourceInfo
    @match inMod begin
      SCode.MOD(fp, ep, _, binding, info) => begin
        SCode.MOD(fp, ep, nil, binding, info)
      end

      _ => begin
        inMod
      end
    end
  end
  return outMod
end

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

function filterGivenSubModNames(submod::SCode.SubMod; namesToKeep::List{String})
  listMember(submod.ident, namesToKeep)
end

function removeGivenSubModNames(submod::SCode.SubMod; namesToRemove::List{String})
  !(listMember(submod.ident, namesToRemove))
end


"""  Return the Element with the name given as first argument from the Class. """
function getElementNamed(inIdent::SCode.Ident, inClass::SCode.Element)::SCode.Element
  local outElement::SCode.Element
  outElement = begin
    local elt::SCode.Element
    local id::String
    local elts::List{SCode.Element}
    @match (inIdent, inClass) begin
      (id, SCode.CLASS(classDef = SCode.PARTS(elementLst = elts))) => begin
        elt = getElementNamedFromElts(id, elts)
        elt
      end

      (
        id,
        SCode.CLASS(#= /* adrpo: handle also the case model extends X then X; */ =#
          classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = elts)),
        ),
      ) => begin
        @assign elt = getElementNamedFromElts(id, elts)
        elt
      end
    end
  end
  return outElement
end

"""
  Helper function to getElementNamed.
"""
function getElementNamedFromElts(
  inIdent::SCode.Ident,
  inElementLst::List{<:SCode.Element},
)::SCode.Element
  local outElement::SCode.Element
  outElement = begin
    local elt::SCode.Element
    local comp::SCode.Element
    local cdef::SCode.Element
    local id2::String
    local id1::String
    local xs::List{SCode.Element}
    @matchcontinue (inIdent, inElementLst) begin
      #= Case 1. Components. =#
      (id2, comp <| xs) => begin
        @match SCode.COMPONENT(name = id1) = comp
        @match true = stringEq(id1, id2)
        comp
      end

      (id2, SCode.COMPONENT(name = id1) <| xs) => begin
        @match false = stringEq(id1, id2)
        elt = getElementNamedFromElts(id2, xs)
        elt
      end

      (id2, SCode.CLASS(name = id1) <| xs) => begin
        @match false = stringEq(id1, id2)
        elt = getElementNamedFromElts(id2, xs)
        elt
      end

      (id2, SCode.EXTENDS(__) <| xs) => begin
        elt = getElementNamedFromElts(id2, xs)
        elt
      end

      (id2, cdef <| xs && SCode.CLASS(name = id1) <| xs) => begin
        @match true = stringEq(id1, id2)
        cdef
      end
      #=  Try next. =#
      (id2, h <| xs) => begin
        elt = getElementNamedFromElts(id2, xs)
        elt
      end
    end
  end
  return outElement
end

"""
Author BZ, 2009-01
check if an element is of type EXTENDS or not.
"""
function isElementExtends(ele::SCode.Element)::Bool
  local isExtend::Bool

  @assign isExtend = begin
    @match ele begin
      SCode.EXTENDS(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isExtend
end

"""Check if an element extends another class."""
function isElementExtendsOrClassExtends(ele::SCode.Element)::Bool
  local isExtend::Bool

  @assign isExtend = begin
    @match ele begin
      SCode.EXTENDS(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isExtend
end

"""check if an element is not of type CLASS_EXTENDS."""
function isNotElementClassExtends(ele::SCode.Element)::Bool
  local isExtend::Bool

  @assign isExtend = begin
    @match ele begin
      SCode.CLASS(classDef = SCode.CLASS_EXTENDS(__)) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return isExtend
end

"""Returns true if Variability indicates a parameter or constant."""
function isParameterOrConst(inVariability::SCode.Variability)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inVariability begin
      SCode.PARAM(__) => begin
        true
      end

      SCode.CONST(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Returns true if Variability is constant, otherwise false"""
function isConstant(inVariability::SCode.Variability)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inVariability begin
      SCode.CONST(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Counts the number of ClassParts of a Class."""
function countParts(inClass::SCode.Element)::Int
  local outInteger::Int

  @assign outInteger = begin
    local res::Int
    local elts::List{SCode.Element}
    @matchcontinue inClass begin
      SCode.CLASS(classDef = SCode.PARTS(elementLst = elts)) => begin
        @assign res = listLength(elts)
        res
      end

      SCode.CLASS(
        classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = elts)),
      ) => begin
        @assign res = listLength(elts)
        res
      end

      _ => begin
        0
      end
    end
  end
  #= /* adrpo: handle also model extends X ... parts ... end X; */ =#
  return outInteger
end

"""Return a string list of all component names of a class."""
function componentNames(inClass::SCode.Element)::List{String}
  local outStringLst::List{String}

  @assign outStringLst = begin
    local res::List{String}
    local elts::List{SCode.Element}
    @match inClass begin
      SCode.CLASS(classDef = SCode.PARTS(elementLst = elts)) => begin
        @assign res = componentNamesFromElts(elts)
        res
      end

      SCode.CLASS(
        classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = elts)),
      ) => begin
        @assign res = componentNamesFromElts(elts)
        res
      end

      _ => begin
        nil
      end
    end
  end
  #= /* adrpo: handle also the case model extends X end X;*/ =#
  return outStringLst
end

"""Helper function to componentNames."""
function componentNamesFromElts(inElements::List{<:SCode.Element})::List{String}
  local outComponentNames::List{String}

  @assign outComponentNames = ListUtil.filterMap(inElements, componentName)
  return outComponentNames
end

function componentName(inComponent::SCode.Element)::String
  local outName::String

  @match SCode.COMPONENT(name = outName) = inComponent
  return outName
end

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

function elementNameInfo(inElement::SCode.Element)::Tuple{String, SourceInfo}
  local outInfo::SourceInfo
  local outName::String

  @assign (outName, outInfo) = begin
    local name::String
    local info::SourceInfo
    @match inElement begin
      SCode.COMPONENT(name = name, info = info) => begin
        (name, info)
      end

      SCode.CLASS(name = name, info = info) => begin
        (name, info)
      end
    end
  end
  return (outName, outInfo)
end

"""Gets all elements that have an element name from the list"""
function elementNames(elts::List{<:SCode.Element})::List{String}
  local names::List{String}

  @assign names = ListUtil.fold(elts, elementNamesWork, nil)
  return names
end

"""Gets all elements that have an element name from the list"""
function elementNamesWork(e::SCode.Element, acc::List{<:String})::List{String}
  local out::List{String}

  @assign out = begin
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
  return out
end

function renameElement(inElement::SCode.Element, inName::String)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local pf::SCode.Prefixes
    local ep::SCode.Encapsulated
    local pp::SCode.Partial
    local res::SCode.Restriction
    local cdef::SCode.ClassDef
    local i::SourceInfo
    local attr::SCode.Attributes
    local ty::Absyn.TypeSpec
    local mod::SCode.Mod
    local cmt::SCode.Comment
    local cond::Option{Absyn.Exp}
    @match (inElement, inName) begin
      (SCode.CLASS(_, pf, ep, pp, res, cdef, cmt, i), _) => begin
        SCode.CLASS(inName, pf, ep, pp, res, cdef, cmt, i)
      end

      (SCode.COMPONENT(_, pf, attr, ty, mod, cmt, cond, i), _) => begin
        SCode.COMPONENT(inName, pf, attr, ty, mod, cmt, cond, i)
      end
    end
  end
  return outElement
end

function elementNameEqual(inElement1::SCode.Element, inElement2::SCode.Element)::Bool
  local outEqual::Bool

  @assign outEqual = begin
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
  return outEqual
end

function enumName(e::SCode.Enum)::String
  local s::String

  @assign s = begin
    @match e begin
      SCode.ENUM(literal = s) => begin
        s
      end
    end
  end
  return s
end

"""Return true if Class is a record."""
function isRecord(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(restriction = SCode.R_RECORD(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Return true if Class is a type"""
function isTypeVar(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(restriction = SCode.R_TYPE(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Return true if Class is a operator record."""
function isOperatorRecord(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(restriction = SCode.R_RECORD(true)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Return true if Class is a function."""
function isFunction(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(restriction = SCode.R_FUNCTION(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Return true if restriction is a function."""
function isFunctionRestriction(inRestriction::SCode.Restriction)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inRestriction begin
      SCode.R_FUNCTION(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""
  restriction is function or external function.
  Otherwise false is returned.
"""
function isFunctionOrExtFunctionRestriction(r::SCode.Restriction)::Bool
  local res::Bool

  @assign res = begin
    @match r begin
      SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(__)) => begin
        true
      end

      SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""
  restriction is operator or operator function.
  Otherwise false is returned.
"""
function isOperator(el::SCode.Element)::Bool
  local res::Bool

  @assign res = begin
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
  return res
end

"""Returns the class name of a Class."""
function className(inClass::SCode.Element)::String
  local outName::String

  @match SCode.CLASS(name = outName) = inClass
  return outName
end

"""
  author: PA
  Sets the partial attribute of a Class
"""
function classSetPartial(inClass::SCode.Element, inPartial::SCode.Partial)::SCode.Element
  local outClass::SCode.Element

  @assign outClass = begin
    local id::String
    local enc::SCode.Encapsulated
    local partialPrefix::SCode.Partial
    local restr::SCode.Restriction
    local def::SCode.ClassDef
    local info::SourceInfo
    local prefixes::SCode.Prefixes
    local cmt::SCode.Comment
    @match (inClass, inPartial) begin
      (
        SCode.CLASS(
          name = id,
          prefixes = prefixes,
          encapsulatedPrefix = enc,
          restriction = restr,
          classDef = def,
          cmt = cmt,
          info = info,
        ),
        partialPrefix,
      ) => begin
        SCode.CLASS(id, prefixes, enc, partialPrefix, restr, def, cmt, info)
      end
    end
  end
  return outClass
end

"""
  returns true if two elements are equal,
  i.e. for a component have the same type,
  name, and attributes, etc.
"""
function elementEqual(element1::SCode.Element, element2::SCode.Element)::Bool
  local equal::Bool

  @assign equal = begin
    local name1::SCode.Ident
    local name2::SCode.Ident
    local prefixes1::SCode.Prefixes
    local prefixes2::SCode.Prefixes
    local en1::SCode.Encapsulated
    local en2::SCode.Encapsulated
    local p1::SCode.Partial
    local p2::SCode.Partial
    local restr1::SCode.Restriction
    local restr2::SCode.Restriction
    local attr1::SCode.Attributes
    local attr2::SCode.Attributes
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local tp1::Absyn.TypeSpec
    local tp2::Absyn.TypeSpec
    local im1::Absyn.Import
    local im2::Absyn.Import
    local path1::Absyn.Path
    local path2::Absyn.Path
    local os1::Option{String}
    local os2::Option{String}
    local or1::Option{AbstractFloat}
    local or2::Option{AbstractFloat}
    local cond1::Option{Absyn.Exp}
    local cond2::Option{Absyn.Exp}
    local cd1::SCode.ClassDef
    local cd2::SCode.ClassDef
    @matchcontinue (element1, element2) begin
      (
        SCode.CLASS(name1, prefixes1, en1, p1, restr1, cd1, _, _),
        SCode.CLASS(name2, prefixes2, en2, p2, restr2, cd2, _, _),
      ) => begin
        @match true = stringEq(name1, name2)
        @match true = prefixesEqual(prefixes1, prefixes2)
        @match true = valueEq(en1, en2)
        @match true = valueEq(p1, p2)
        @match true = restrictionEqual(restr1, restr2)
        @match true = classDefEqual(cd1, cd2)
        true
      end

      (
        SCode.COMPONENT(name1, prefixes1, attr1, tp1, mod1, _, cond1, _),
        SCode.COMPONENT(name2, prefixes2, attr2, tp2, mod2, _, cond2, _),
      ) => begin
        equality(cond1, cond2)
        @match true = stringEq(name1, name2)
        @match true = prefixesEqual(prefixes1, prefixes2)
        @match true = attributesEqual(attr1, attr2)
        @match true = modEqual(mod1, mod2)
        @match true = AbsynUtil.typeSpecEqual(tp1, tp2)
        true
      end

      (SCode.EXTENDS(path1, _, mod1, _, _), SCode.EXTENDS(path2, _, mod2, _, _)) => begin
        @match true = AbsynUtil.pathEqual(path1, path2)
        @match true = modEqual(mod1, mod2)
        true
      end

      (SCode.IMPORT(imp = im1), SCode.IMPORT(imp = im2)) => begin
        @match true = AbsynUtil.importEqual(im1, im2)
        true
      end

      (SCode.DEFINEUNIT(name1, _, os1, or1), SCode.DEFINEUNIT(name2, _, os2, or2)) =>
        begin
          @match true = stringEq(name1, name2)
          equality(os1, os2)
          equality(or1, or2)
          true
        end

      _ => begin
        false
      end
    end
  end
  #=  otherwise false
  =#
  return equal
end

#=  stefan
=#

"""returns true if 2 annotations are equal"""
function annotationEqual(annotation1::SCode.Annotation, annotation2::SCode.Annotation)::Bool
  local equal::Bool

  local mod1::SCode.Mod
  local mod2::SCode.Mod

  @match SCode.ANNOTATION(modification = mod1) = annotation1
  @match SCode.ANNOTATION(modification = mod2) = annotation2
  @assign equal = modEqual(mod1, mod2)
  return equal
end

"""Returns true if two Restriction's are equal."""
function restrictionEqual(restr1::SCode.Restriction, restr2::SCode.Restriction)::Bool
  local equal::Bool

  @assign equal = begin
    local funcRest1::SCode.FunctionRestriction
    local funcRest2::SCode.FunctionRestriction
    @match (restr1, restr2) begin
      (SCode.R_CLASS(__), SCode.R_CLASS(__)) => begin
        true
      end

      (SCode.R_OPTIMIZATION(__), SCode.R_OPTIMIZATION(__)) => begin
        true
      end

      (SCode.R_MODEL(__), SCode.R_MODEL(__)) => begin
        true
      end

      (SCode.R_RECORD(true), SCode.R_RECORD(true)) => begin
        true
      end

      (SCode.R_RECORD(false), SCode.R_RECORD(false)) => begin
        true
      end

      (SCode.R_BLOCK(__), SCode.R_BLOCK(__)) => begin
        true
      end

      (SCode.R_CONNECTOR(true), SCode.R_CONNECTOR(true)) => begin
        true
      end

      (SCode.R_CONNECTOR(false), SCode.R_CONNECTOR(false)) => begin
        true
      end

      (SCode.R_OPERATOR(__), SCode.R_OPERATOR(__)) => begin
        true
      end

      (SCode.R_TYPE(__), SCode.R_TYPE(__)) => begin
        true
      end

      (SCode.R_PACKAGE(__), SCode.R_PACKAGE(__)) => begin
        true
      end

      (SCode.R_FUNCTION(funcRest1), SCode.R_FUNCTION(funcRest2)) => begin
        funcRestrictionEqual(funcRest1, funcRest2)
      end

      (SCode.R_ENUMERATION(__), SCode.R_ENUMERATION(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_INTEGER(__), SCode.R_PREDEFINED_INTEGER(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_REAL(__), SCode.R_PREDEFINED_REAL(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_STRING(__), SCode.R_PREDEFINED_STRING(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_BOOLEAN(__), SCode.R_PREDEFINED_BOOLEAN(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_CLOCK(__), SCode.R_PREDEFINED_CLOCK(__)) => begin
        true
      end

      (SCode.R_PREDEFINED_ENUMERATION(__), SCode.R_PREDEFINED_ENUMERATION(__)) => begin
        true
      end

      (SCode.R_UNIONTYPE(__), SCode.R_UNIONTYPE(__)) => begin
        min(@do_threaded_for t1 == t2 (t1, t2) (restr1.typeVars, restr2.typeVars))
      end

      _ => begin
        false
      end
    end
  end
  #=  operator record
  =#
  #=  expandable connectors
  =#
  #=  non expandable connectors
  =#
  #=  operator
  =#
  #=  BTH
  =#
  return equal
end

function funcRestrictionEqual(
  funcRestr1::SCode.FunctionRestriction,
  funcRestr2::SCode.FunctionRestriction,
)::Bool
  local equal::Bool

  @assign equal = begin
    local b1::Bool
    local b2::Bool
    @match (funcRestr1, funcRestr2) begin
      (SCode.FR_NORMAL_FUNCTION(b1), SCode.FR_NORMAL_FUNCTION(b2)) => begin
        boolEq(b1, b2)
      end

      (SCode.FR_EXTERNAL_FUNCTION(b1), SCode.FR_EXTERNAL_FUNCTION(b2)) => begin
        boolEq(b1, b2)
      end

      (SCode.FR_OPERATOR_FUNCTION(__), SCode.FR_OPERATOR_FUNCTION(__)) => begin
        true
      end

      (SCode.FR_RECORD_CONSTRUCTOR(__), SCode.FR_RECORD_CONSTRUCTOR(__)) => begin
        true
      end

      (SCode.FR_PARALLEL_FUNCTION(__), SCode.FR_PARALLEL_FUNCTION(__)) => begin
        true
      end

      (SCode.FR_KERNEL_FUNCTION(__), SCode.FR_KERNEL_FUNCTION(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

function enumEqual(e1::SCode.Enum, e2::SCode.Enum)::Bool
  local isEqual::Bool

  @assign isEqual = begin
    local s1::String
    local s2::String
    local b1::Bool
    @match (e1, e2) begin
      (SCode.ENUM(s1, _), SCode.ENUM(s2, _)) => begin
        @assign b1 = stringEq(s1, s2)
        b1
      end
    end
  end
  #=  ignore comments here.
  =#
  return isEqual
end

"""Returns true if Two ClassDef's are equal"""
function classDefEqual(cdef1::SCode.ClassDef, cdef2::SCode.ClassDef)::Bool
  local equal::Bool

  @assign equal = begin
    local elts1::List{SCode.Element}
    local elts2::List{SCode.Element}
    local eqns1::List{SCode.Equation}
    local eqns2::List{SCode.Equation}
    local ieqns1::List{SCode.Equation}
    local ieqns2::List{SCode.Equation}
    local algs1::List{SCode.AlgorithmSection}
    local algs2::List{SCode.AlgorithmSection}
    local ialgs1::List{SCode.AlgorithmSection}
    local ialgs2::List{SCode.AlgorithmSection}
    local cons1::List{SCode.ConstraintSection}
    local cons2::List{SCode.ConstraintSection}
    local attr1::SCode.Attributes
    local attr2::SCode.Attributes
    local tySpec1::Absyn.TypeSpec
    local tySpec2::Absyn.TypeSpec
    local p1::Absyn.Path
    local p2::Absyn.Path
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local elst1::List{SCode.Enum}
    local elst2::List{SCode.Enum}
    local ilst1::List{SCode.Ident}
    local ilst2::List{SCode.Ident}
    local clsttrs1::List{Absyn.NamedArg}
    local clsttrs2::List{Absyn.NamedArg}
    @match (cdef1, cdef2) begin
      (
        SCode.PARTS(elts1, eqns1, ieqns1, algs1, ialgs1, _, _, _),
        SCode.PARTS(elts2, eqns2, ieqns2, algs2, ialgs2, _, _, _),
      ) => begin
        ListUtil.threadMapAllValue(elts1, elts2, elementEqual, true)
        ListUtil.threadMapAllValue(eqns1, eqns2, equationEqual, true)
        ListUtil.threadMapAllValue(ieqns1, ieqns2, equationEqual, true)
        ListUtil.threadMapAllValue(algs1, algs2, algorithmEqual, true)
        ListUtil.threadMapAllValue(ialgs1, ialgs2, algorithmEqual, true)
        true
      end

      (SCode.DERIVED(tySpec1, mod1, attr1), SCode.DERIVED(tySpec2, mod2, attr2)) => begin
        @match true = AbsynUtil.typeSpecEqual(tySpec1, tySpec2)
        @match true = modEqual(mod1, mod2)
        @match true = attributesEqual(attr1, attr2)
        true
      end

      (SCode.ENUMERATION(elst1), SCode.ENUMERATION(elst2)) => begin
        ListUtil.threadMapAllValue(elst1, elst2, enumEqual, true)
        true
      end

      (
        SCode.CLASS_EXTENDS(
          mod1,
          SCode.PARTS(elts1, eqns1, ieqns1, algs1, ialgs1, _, _, _),
        ),
        SCode.CLASS_EXTENDS(
          mod2,
          SCode.PARTS(elts2, eqns2, ieqns2, algs2, ialgs2, _, _, _),
        ),
      ) => begin
        ListUtil.threadMapAllValue(elts1, elts2, elementEqual, true)
        ListUtil.threadMapAllValue(eqns1, eqns2, equationEqual, true)
        ListUtil.threadMapAllValue(ieqns1, ieqns2, equationEqual, true)
        ListUtil.threadMapAllValue(algs1, algs2, algorithmEqual, true)
        ListUtil.threadMapAllValue(ialgs1, ialgs2, algorithmEqual, true)
        @match true = modEqual(mod1, mod2)
        true
      end

      (SCode.PDER(_, ilst1), SCode.PDER(_, ilst2)) => begin
        ListUtil.threadMapAllValue(ilst1, ilst2, stringEq, true)
        true
      end

      _ => begin
        fail()
      end
    end
  end
  #= /* adrpo: TODO! FIXME! are these below really needed??!!
      as far as I can tell we handle all the cases.
     case(cdef1, cdef2)
       equation
         equality(cdef1=cdef2);
       then true;

     case(cdef1, cdef2)
       equation
         failure(equality(cdef1=cdef2));
       then false;*/ =#
  return equal
end

"""Returns true if two Option<ArrayDim> are equal"""
function arraydimOptEqual(
  adopt1::Option{<:Absyn.ArrayDim},
  adopt2::Option{<:Absyn.ArrayDim},
)::Bool
  local equal::Bool

  @assign equal = begin
    local lst1::List{Absyn.Subscript}
    local lst2::List{Absyn.Subscript}
    local blst::List{Bool}
    @matchcontinue (adopt1, adopt2) begin
      (NONE(), NONE()) => begin
        true
      end

      (SOME(lst1), SOME(lst2)) => begin
        ListUtil.threadMapAllValue(lst1, lst2, subscriptEqual, true)
        true
      end

      (SOME(_), SOME(_)) => begin
        false
      end
    end
  end
  #=  oth. false
  =#
  return equal
end

"""Returns true if two Absyn.Subscript are equal"""
function subscriptEqual(sub1::Absyn.Subscript, sub2::Absyn.Subscript)::Bool
  local equal::Bool

  @assign equal = begin
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    @match (sub1, sub2) begin
      (Absyn.NOSUB(__), Absyn.NOSUB(__)) => begin
        true
      end

      (Absyn.SUBSCRIPT(e1), Absyn.SUBSCRIPT(e2)) => begin
        AbsynUtil.expEqual(e1, e2)
      end
    end
  end
  return equal
end

"""Returns true if two Algorithm's are equal."""
function algorithmEqual(alg1::SCode.AlgorithmSection, alg2::SCode.AlgorithmSection)::Bool
  local equal::Bool

  @assign equal = begin
    local a1::List{SCode.Statement}
    local a2::List{SCode.Statement}
    @matchcontinue (alg1, alg2) begin
      (SCode.ALGORITHM(a1), SCode.ALGORITHM(a2)) => begin
        ListUtil.threadMapAllValue(a1, a2, algorithmEqual2, true)
        true
      end

      _ => begin
        false
      end
    end
  end
  #=  false otherwise!
  =#
  return equal
end

"""Returns true if two Absyn.Algorithm are equal."""
function algorithmEqual2(ai1::SCode.Statement, ai2::SCode.Statement)::Bool
  local equal::Bool

  @assign equal = begin
    local alg1::Absyn.Algorithm
    local alg2::Absyn.Algorithm
    local a1::SCode.Statement
    local a2::SCode.Statement
    local cr1::Absyn.ComponentRef
    local cr2::Absyn.ComponentRef
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local e11::Absyn.Exp
    local e12::Absyn.Exp
    local e21::Absyn.Exp
    local e22::Absyn.Exp
    local b1::Bool
    local b2::Bool
    @matchcontinue (ai1, ai2) begin
      (
        SCode.ALG_ASSIGN(assignComponent = Absyn.CREF(cr1), value = e1),
        SCode.ALG_ASSIGN(assignComponent = Absyn.CREF(cr2), value = e2),
      ) => begin
        @assign b1 = AbsynUtil.crefEqual(cr1, cr2)
        @assign b2 = AbsynUtil.expEqual(e1, e2)
        @assign equal = boolAnd(b1, b2)
        equal
      end

      (
        SCode.ALG_ASSIGN(assignComponent = e11 && Absyn.TUPLE(_), value = e12),
        SCode.ALG_ASSIGN(assignComponent = e21 && Absyn.TUPLE(_), value = e22),
      ) => begin
        @assign b1 = AbsynUtil.expEqual(e11, e21)
        @assign b2 = AbsynUtil.expEqual(e12, e22)
        @assign equal = boolAnd(b1, b2)
        equal
      end

      (a1, a2) => begin
        @match Absyn.ALGORITHMITEM(algorithm_ = alg1) = statementToAlgorithmItem(a1)
        @match Absyn.ALGORITHMITEM(algorithm_ = alg2) = statementToAlgorithmItem(a2)
        equality(alg1, alg2)
        true
      end

      _ => begin
        false
      end
    end
  end
  #=  base it on equality for now as the ones below are not implemented!
  =#
  #=  Don't compare comments and line numbers
  =#
  #=  maybe replace failure/equality with these:
  =#
  #= case(Absyn.ALG_IF(_,_,_,_),Absyn.ALG_IF(_,_,_,_)) then false;  TODO: SCode.ALG_IF
  =#
  #= case (Absyn.ALG_FOR(_,_),Absyn.ALG_FOR(_,_)) then false;  TODO: SCode.ALG_FOR
  =#
  #= case (Absyn.ALG_WHILE(_,_),Absyn.ALG_WHILE(_,_)) then false;  TODO: SCode.ALG_WHILE
  =#
  #= case(Absyn.ALG_WHEN_A(_,_,_),Absyn.ALG_WHEN_A(_,_,_)) then false; TODO: SCode.ALG_WHILE
  =#
  #= case (Absyn.ALG_NORETCALL(_,_),Absyn.ALG_NORETCALL(_,_)) then false; TODO: SCode.ALG_NORETCALL
  =#
  return equal
end

"""Returns true if two equations are equal."""
function equationEqual(eqn1::SCode.Equation, eqn2::SCode.Equation)::Bool
  local equal::Bool

  local eq1::SCode.EEquation
  local eq2::SCode.EEquation

  @match SCode.EQUATION(eEquation = eq1) = eqn1
  @match SCode.EQUATION(eEquation = eq2) = eqn2
  @assign equal = equationEqual2(eq1, eq2)
  return equal
end

"""Helper function to equationEqual"""
function equationEqual2(eq1::SCode.EEquation, eq2::SCode.EEquation)::Bool
  local equal::Bool

  @assign equal = begin
    local tb1::List{List{SCode.EEquation}}
    local tb2::List{List{SCode.EEquation}}
    local cond1::Absyn.Exp
    local cond2::Absyn.Exp
    local ifcond1::List{Absyn.Exp}
    local ifcond2::List{Absyn.Exp}
    local e11::Absyn.Exp
    local e12::Absyn.Exp
    local e21::Absyn.Exp
    local e22::Absyn.Exp
    local exp1::Absyn.Exp
    local exp2::Absyn.Exp
    local c1::Absyn.Exp
    local c2::Absyn.Exp
    local m1::Absyn.Exp
    local m2::Absyn.Exp
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local cr11::Absyn.ComponentRef
    local cr12::Absyn.ComponentRef
    local cr21::Absyn.ComponentRef
    local cr22::Absyn.ComponentRef
    local cr1::Absyn.ComponentRef
    local cr2::Absyn.ComponentRef
    local id1::Absyn.Ident
    local id2::Absyn.Ident
    local fb1::List{SCode.EEquation}
    local fb2::List{SCode.EEquation}
    local eql1::List{SCode.EEquation}
    local eql2::List{SCode.EEquation}
    local elst1::List{SCode.EEquation}
    local elst2::List{SCode.EEquation}
    @matchcontinue (eq1, eq2) begin
      (
        SCode.EQ_IF(condition = ifcond1, thenBranch = tb1, elseBranch = fb1),
        SCode.EQ_IF(condition = ifcond2, thenBranch = tb2, elseBranch = fb2),
      ) => begin
        @match true = equationEqual22(tb1, tb2)
        ListUtil.threadMapAllValue(fb1, fb2, equationEqual2, true)
        ListUtil.threadMapAllValue(ifcond1, ifcond2, AbsynUtil.expEqual, true)
        true
      end

      (
        SCode.EQ_EQUALS(expLeft = e11, expRight = e12),
        SCode.EQ_EQUALS(expLeft = e21, expRight = e22),
      ) => begin
        @match true = AbsynUtil.expEqual(e11, e21)
        @match true = AbsynUtil.expEqual(e12, e22)
        true
      end

      (
        SCode.EQ_PDE(expLeft = e11, expRight = e12, domain = cr1),
        SCode.EQ_PDE(expLeft = e21, expRight = e22, domain = cr2),
      ) => begin
        @match true = AbsynUtil.expEqual(e11, e21)
        @match true = AbsynUtil.expEqual(e12, e22)
        @match true = AbsynUtil.crefEqual(cr1, cr2)
        true
      end

      (
        SCode.EQ_CONNECT(crefLeft = cr11, crefRight = cr12),
        SCode.EQ_CONNECT(crefLeft = cr21, crefRight = cr22),
      ) => begin
        @match true = AbsynUtil.crefEqual(cr11, cr21)
        @match true = AbsynUtil.crefEqual(cr12, cr22)
        true
      end

      (
        SCode.EQ_FOR(index = id1, range = SOME(exp1), eEquationLst = eql1),
        SCode.EQ_FOR(index = id2, range = SOME(exp2), eEquationLst = eql2),
      ) => begin
        ListUtil.threadMapAllValue(eql1, eql2, equationEqual2, true)
        @match true = AbsynUtil.expEqual(exp1, exp2)
        @match true = stringEq(id1, id2)
        true
      end

      (
        SCode.EQ_FOR(index = id1, range = NONE(), eEquationLst = eql1),
        SCode.EQ_FOR(index = id2, range = NONE(), eEquationLst = eql2),
      ) => begin
        ListUtil.threadMapAllValue(eql1, eql2, equationEqual2, true)
        @match true = stringEq(id1, id2)
        true
      end

      (
        SCode.EQ_WHEN(condition = cond1, eEquationLst = elst1),
        SCode.EQ_WHEN(condition = cond2, eEquationLst = elst2),
      ) => begin
        ListUtil.threadMapAllValue(elst1, elst2, equationEqual2, true)
        @match true = AbsynUtil.expEqual(cond1, cond2)
        true
      end

      (
        SCode.EQ_ASSERT(condition = c1, message = m1),
        SCode.EQ_ASSERT(condition = c2, message = m2),
      ) => begin
        @match true = AbsynUtil.expEqual(c1, c2)
        @match true = AbsynUtil.expEqual(m1, m2)
        true
      end

      (SCode.EQ_REINIT(__), SCode.EQ_REINIT(__)) => begin
        @match true = AbsynUtil.expEqual(eq1.cref, eq2.cref)
        @match true = AbsynUtil.expEqual(eq1.expReinit, eq2.expReinit)
        true
      end

      (SCode.EQ_NORETCALL(exp = e1), SCode.EQ_NORETCALL(exp = e2)) => begin
        @match true = AbsynUtil.expEqual(e1, e2)
        true
      end

      _ => begin
        false
      end
    end
  end
  #=  TODO: elsewhen not checked yet.
  =#
  #=  otherwise false
  =#
  return equal
end

"""
  Author BZ
  Helper function for equationEqual2, does compare list<list<equation>> (else ifs in ifequations.)
"""
function equationEqual22(
  inTb1::List{<:List{<:SCode.EEquation}},
  inTb2::List{<:List{<:SCode.EEquation}},
)::Bool
  local bOut::Bool

  @assign bOut = begin
    local tb_1::List{SCode.EEquation}
    local tb_2::List{SCode.EEquation}
    local tb1::List{List{SCode.EEquation}}
    local tb2::List{List{SCode.EEquation}}
    @matchcontinue (inTb1, inTb2) begin
      (nil(), nil()) => begin
        true
      end

      (_, nil()) => begin
        false
      end

      (nil(), _) => begin
        false
      end

      (tb_1 <| tb1, tb_2 <| tb2) => begin
        ListUtil.threadMapAllValue(tb_1, tb_2, equationEqual2, true)
        @match true = equationEqual22(tb1, tb2)
        true
      end

      (_ <| _, _ <| _) => begin
        false
      end
    end
  end
  return bOut
end

"""Return true if two Mod:s are equal"""
function modEqual(mod1::SCode.Mod, mod2::SCode.Mod)::Bool
  local equal::Bool

  @assign equal = begin
    local f1::SCode.Final
    local f2::SCode.Final
    local each1::SCode.Each
    local each2::SCode.Each
    local submodlst1::List{SCode.SubMod}
    local submodlst2::List{SCode.SubMod}
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local elt1::SCode.Element
    local elt2::SCode.Element
    @matchcontinue (mod1, mod2) begin
      (
        SCode.MOD(f1, each1, submodlst1, SOME(e1), _),
        SCode.MOD(f2, each2, submodlst2, SOME(e2), _),
      ) => begin
        @match true = valueEq(f1, f2)
        @match true = eachEqual(each1, each2)
        @match true = subModsEqual(submodlst1, submodlst2)
        @match true = AbsynUtil.expEqual(e1, e2)
        true
      end

      (
        SCode.MOD(f1, each1, submodlst1, NONE(), _),
        SCode.MOD(f2, each2, submodlst2, NONE(), _),
      ) => begin
        @match true = valueEq(f1, f2)
        @match true = eachEqual(each1, each2)
        @match true = subModsEqual(submodlst1, submodlst2)
        true
      end

      (SCode.NOMOD(__), SCode.NOMOD(__)) => begin
        true
      end

      (SCode.REDECL(f1, each1, elt1), SCode.REDECL(f2, each2, elt2)) => begin
        @match true = valueEq(f1, f2)
        @match true = eachEqual(each1, each2)
        @match true = elementEqual(elt1, elt2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Return true if two subModifier lists are equal"""
function subModsEqual(
  inSubModLst1::List{<:SCode.SubMod},
  inSubModLst2::List{<:SCode.SubMod},
)::Bool
  local equal::Bool

  @assign equal = begin
    local id1::SCode.Ident
    local id2::SCode.Ident
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local ss1::List{SCode.Subscript}
    local ss2::List{SCode.Subscript}
    local subModLst1::List{SCode.SubMod}
    local subModLst2::List{SCode.SubMod}
    @matchcontinue (inSubModLst1, inSubModLst2) begin
      (nil(), nil()) => begin
        true
      end

      (SCode.NAMEMOD(id1, mod1) <| subModLst1, SCode.NAMEMOD(id2, mod2) <| subModLst2) =>
        begin
          @match true = stringEq(id1, id2)
          @match true = modEqual(mod1, mod2)
          @match true = subModsEqual(subModLst1, subModLst2)
          true
        end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two subscript lists are equal"""
function subscriptsEqual(
  inSs1::List{<:SCode.Subscript},
  inSs2::List{<:SCode.Subscript},
)::Bool
  local equal::Bool

  @assign equal = begin
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local ss1::List{SCode.Subscript}
    local ss2::List{SCode.Subscript}
    @matchcontinue (inSs1, inSs2) begin
      (nil(), nil()) => begin
        true
      end

      (Absyn.NOSUB(__) <| ss1, Absyn.NOSUB(__) <| ss2) => begin
        subscriptsEqual(ss1, ss2)
      end

      (Absyn.SUBSCRIPT(e1) <| ss1, Absyn.SUBSCRIPT(e2) <| ss2) => begin
        @match true = AbsynUtil.expEqual(e1, e2)
        @match true = subscriptsEqual(ss1, ss2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two Atributes are equal"""
function attributesEqual(attr1::SCode.Attributes, attr2::SCode.Attributes)::Bool
  local equal::Bool

  @assign equal = begin
    local prl1::SCode.Parallelism
    local prl2::SCode.Parallelism
    local var1::SCode.Variability
    local var2::SCode.Variability
    local ct1::SCode.ConnectorType
    local ct2::SCode.ConnectorType
    local ad1::Absyn.ArrayDim
    local ad2::Absyn.ArrayDim
    local dir1::Absyn.Direction
    local dir2::Absyn.Direction
    local if1::Absyn.IsField
    local if2::Absyn.IsField
    @matchcontinue (attr1, attr2) begin
      (
        SCode.ATTR(ad1, ct1, prl1, var1, dir1, if1),
        SCode.ATTR(ad2, ct2, prl2, var2, dir2, if2),
      ) => begin
        @match true = arrayDimEqual(ad1, ad2)
        @match true = valueEq(ct1, ct2)
        @match true = parallelismEqual(prl1, prl2)
        @match true = variabilityEqual(var1, var2)
        @match true = AbsynUtil.directionEqual(dir1, dir2)
        @match true = AbsynUtil.isFieldEqual(if1, if2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two Parallelism prefixes are equal"""
function parallelismEqual(prl1::SCode.Parallelism, prl2::SCode.Parallelism)::Bool
  local equal::Bool

  @assign equal = begin
    @match (prl1, prl2) begin
      (SCode.PARGLOBAL(__), SCode.PARGLOBAL(__)) => begin
        true
      end

      (SCode.PARLOCAL(__), SCode.PARLOCAL(__)) => begin
        true
      end

      (SCode.NON_PARALLEL(__), SCode.NON_PARALLEL(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two Variablity prefixes are equal"""
function variabilityEqual(var1::SCode.Variability, var2::SCode.Variability)::Bool
  local equal::Bool

  @assign equal = begin
    @match (var1, var2) begin
      (SCode.VAR(__), SCode.VAR(__)) => begin
        true
      end

      (SCode.DISCRETE(__), SCode.DISCRETE(__)) => begin
        true
      end

      (SCode.PARAM(__), SCode.PARAM(__)) => begin
        true
      end

      (SCode.CONST(__), SCode.CONST(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Return true if two arraydims are equal"""
function arrayDimEqual(iad1::Absyn.ArrayDim, iad2::Absyn.ArrayDim)::Bool
  local equal::Bool

  @assign equal = begin
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local ad1::Absyn.ArrayDim
    local ad2::Absyn.ArrayDim
    @matchcontinue (iad1, iad2) begin
      (nil(), nil()) => begin
        true
      end

      (Absyn.NOSUB(__) <| ad1, Absyn.NOSUB(__) <| ad2) => begin
        @match true = arrayDimEqual(ad1, ad2)
        true
      end

      (Absyn.SUBSCRIPT(e1) <| ad1, Absyn.SUBSCRIPT(e2) <| ad2) => begin
        @match true = AbsynUtil.expEqual(e1, e2)
        @match true = arrayDimEqual(ad1, ad2)
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Sets the restriction of a SCode Class"""
function setClassRestriction(r::SCode.Restriction, cl::SCode.Element)::SCode.Element
  local outCl::SCode.Element

  @assign outCl = begin
    local parts::SCode.ClassDef
    local p::SCode.Partial
    local e::SCode.Encapsulated
    local id::SCode.Ident
    local info::SourceInfo
    local prefixes::SCode.Prefixes
    local oldR::SCode.Restriction
    local cmt::SCode.Comment
    #=  check if restrictions are equal, so you can return the same thing!
    =#
    @matchcontinue (r, cl) begin
      (_, SCode.CLASS(restriction = oldR)) => begin
        @match true = restrictionEqual(r, oldR)
        cl
      end

      (_, SCode.CLASS(id, prefixes, e, p, _, parts, cmt, info)) => begin
        SCode.CLASS(id, prefixes, e, p, r, parts, cmt, info)
      end
    end
  end
  #=  not equal, change
  =#
  return outCl
end

"""Sets the name of a SCode Class"""
function setClassName(name::SCode.Ident, cl::SCode.Element)::SCode.Element
  local outCl::SCode.Element

  @assign outCl = begin
    local parts::SCode.ClassDef
    local p::SCode.Partial
    local e::SCode.Encapsulated
    local info::SourceInfo
    local prefixes::SCode.Prefixes
    local r::SCode.Restriction
    local id::SCode.Ident
    local cmt::SCode.Comment
    #=  check if restrictions are equal, so you can return the same thing!
    =#
    @matchcontinue (name, cl) begin
      (_, SCode.CLASS(name = id)) => begin
        @match true = stringEqual(name, id)
        cl
      end

      (_, SCode.CLASS(_, prefixes, e, p, r, parts, cmt, info)) => begin
        SCode.CLASS(name, prefixes, e, p, r, parts, cmt, info)
      end
    end
  end
  #=  not equal, change
  =#
  return outCl
end

function makeClassPartial(inClass::SCode.Element)::SCode.Element
  local outClass::SCode.Element = inClass

  @assign outClass = begin
    @match outClass begin
      SCode.CLASS(partialPrefix = SCode.NOT_PARTIAL(__)) => begin
        @assign outClass.partialPrefix = SCode.PARTIAL()
        outClass
      end

      _ => begin
        outClass
      end
    end
  end
  return outClass
end

"""Sets the partial prefix of a SCode Class"""
function setClassPartialPrefix(
  partialPrefix::SCode.Partial,
  cl::SCode.Element,
)::SCode.Element
  local outCl::SCode.Element

  @assign outCl = begin
    local parts::SCode.ClassDef
    local e::SCode.Encapsulated
    local id::SCode.Ident
    local info::SourceInfo
    local restriction::SCode.Restriction
    local prefixes::SCode.Prefixes
    local oldPartialPrefix::SCode.Partial
    local cmt::SCode.Comment
    #=  check if partial prefix are equal, so you can return the same thing!
    =#
    @matchcontinue (partialPrefix, cl) begin
      (_, SCode.CLASS(partialPrefix = oldPartialPrefix)) => begin
        @match true = valueEq(partialPrefix, oldPartialPrefix)
        cl
      end

      (_, SCode.CLASS(id, prefixes, e, _, restriction, parts, cmt, info)) => begin
        SCode.CLASS(id, prefixes, e, partialPrefix, restriction, parts, cmt, info)
      end
    end
  end
  #=  not the same, change
  =#
  return outCl
end

function findIteratorIndexedCrefsInEEquations(
  inEqs::List{<:SCode.EEquation},
  inIterator::String,
  inCrefs::List{<:AbsynUtil.IteratorIndexedCref} = nil,
)::List{AbsynUtil.IteratorIndexedCref}
  local outCrefs::List{AbsynUtil.IteratorIndexedCref}

  @assign outCrefs =
    ListUtil.fold1(inEqs, findIteratorIndexedCrefsInEEquation, inIterator, inCrefs)
  return outCrefs
end

function findIteratorIndexedCrefsInEEquation(
  inEq::SCode.EEquation,
  inIterator::String,
  inCrefs::List{<:AbsynUtil.IteratorIndexedCref} = nil,
)::List{AbsynUtil.IteratorIndexedCref}
  local outCrefs::List{AbsynUtil.IteratorIndexedCref}

  @assign outCrefs = foldEEquationsExps(
    inEq,
    (inIterator) -> AbsynUtil.findIteratorIndexedCrefs(inIterator = inIterator),
    inCrefs,
  )
  return outCrefs
end

function findIteratorIndexedCrefsInStatements(
  inStatements::List{<:SCode.Statement},
  inIterator::String,
  inCrefs::List{<:AbsynUtil.IteratorIndexedCref} = nil,
)::List{AbsynUtil.IteratorIndexedCref}
  local outCrefs::List{AbsynUtil.IteratorIndexedCref}

  @assign outCrefs =
    ListUtil.fold1(inStatements, findIteratorIndexedCrefsInStatement, inIterator, inCrefs)
  return outCrefs
end

function findIteratorIndexedCrefsInStatement(
  inStatement::SCode.Statement,
  inIterator::String,
  inCrefs::List{<:AbsynUtil.IteratorIndexedCref} = nil,
)::List{AbsynUtil.IteratorIndexedCref}
  local outCrefs::List{AbsynUtil.IteratorIndexedCref}

  @assign outCrefs = foldStatementsExps(
    inStatement,
    (inIterator) -> AbsynUtil.findIteratorIndexedCrefs(inIterator = inIterator),
    inCrefs,
  )
  return outCrefs
end

"""Filters out the components from the given list of elements, as well as their names."""
function filterComponents(
  inElements::List{<:SCode.Element},
)::Tuple{List{SCode.Element}, List{String}}
  local outComponentNames::List{String}
  local outComponents::List{SCode.Element}

  @assign (outComponents, outComponentNames) = ListUtil.map_2(inElements, filterComponents2)
  return (outComponents, outComponentNames)
end

function filterComponents2(inElement::SCode.Element)::Tuple{SCode.Element, String}
  local outName::String
  local outComponent::SCode.Element

  @match SCode.COMPONENT(name = outName) = inElement
  @assign outComponent = inElement
  return (outComponent, outName)
end

"""This function returns the components from a class"""
function getClassComponents(cl::SCode.Element)::Tuple{List{SCode.Element}, List{String}}
  local compNames::List{String}
  local compElts::List{SCode.Element}
  (compElts, compNames) = begin
    local elts::List{SCode.Element}
    local comps::List{SCode.Element}
    local names::List{String}
    @match cl begin
      SCode.CLASS(classDef = SCode.PARTS(elementLst = elts)) => begin
        @assign (comps, names) = filterComponents(elts)
        (comps, names)
      end

      SCode.CLASS(
        classDef = SCode.CLASS_EXTENDS(composition = SCode.PARTS(elementLst = elts)),
      ) => begin
        @assign (comps, names) = filterComponents(elts)
        (comps, names)
      end
    end
  end
  return (compElts, compNames)
end

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

"""
  Creates an EnumType element from an enumeration literal and an optional
  comment.
"""
function makeEnumType(inEnum::SCode.Enum, inInfo::SourceInfo)::SCode.Element
  local outEnumType::SCode.Element

  local literal::String
  local comment::SCode.Comment

  @match SCode.ENUM(literal = literal, comment = comment) = inEnum
  checkValidEnumLiteral(literal, inInfo)
  @assign outEnumType = SCode.COMPONENT(
    literal,
    SCode.defaultPrefixes,
    SCode.defaultConstAttr,
    Absyn.TPATH(Absyn.IDENT("EnumType"), NONE()),
    SCode.NOMOD(),
    comment,
    NONE(),
    inInfo,
  )
  return outEnumType
end

"""
  Returns the more constant of two Variabilities
  (considers VAR() < DISCRETE() < PARAM() < CONST()),
  similarly to Types.constOr.
"""
function variabilityOr(
  inConst1::SCode.Variability,
  inConst2::SCode.Variability,
)::SCode.Variability
  local outConst::SCode.Variability

  @assign outConst = begin
    @match (inConst1, inConst2) begin
      (SCode.CONST(__), _) => begin
        SCode.CONST()
      end

      (_, SCode.CONST(__)) => begin
        SCode.CONST()
      end

      (SCode.PARAM(__), _) => begin
        SCode.PARAM()
      end

      (_, SCode.PARAM(__)) => begin
        SCode.PARAM()
      end

      (SCode.DISCRETE(__), _) => begin
        SCode.DISCRETE()
      end

      (_, SCode.DISCRETE(__)) => begin
        SCode.DISCRETE()
      end

      _ => begin
        SCode.VAR()
      end
    end
  end
  return outConst
end

"""
  Transforms SCode.Statement back to Absyn.AlgorithmItem. Discards the comment.
  Only to be used to unparse statements again.
"""
function statementToAlgorithmItem(stmt::SCode.Statement)::Absyn.AlgorithmItem
  local algi::Absyn.AlgorithmItem

  @assign algi = begin
    local functionCall::Absyn.ComponentRef
    local assignComponent::Absyn.Exp
    local boolExpr::Absyn.Exp
    local value::Absyn.Exp
    local iterator::String
    local range::Option{Absyn.Exp}
    local functionArgs::Absyn.FunctionArgs
    local info::SourceInfo
    local conditions::List{Absyn.Exp}
    local stmtsList::List{List{SCode.Statement}}
    local body::List{SCode.Statement}
    local trueBranch::List{SCode.Statement}
    local elseBranch::List{SCode.Statement}
    local branches::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
    local comment::Option{SCode.Comment}
    local algs1::List{Absyn.AlgorithmItem}
    local algs2::List{Absyn.AlgorithmItem}
    local algsLst::List{List{Absyn.AlgorithmItem}}
    local abranches::List{Tuple{Absyn.Exp, List{Absyn.AlgorithmItem}}}
    @match stmt begin
      SCode.ALG_ASSIGN(assignComponent, value, _, info) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_ASSIGN(assignComponent, value), NONE(), info)
      end

      SCode.ALG_IF(boolExpr, trueBranch, branches, elseBranch, _, info) => begin
        @assign algs1 = ListUtil.map(trueBranch, statementToAlgorithmItem)
        @assign conditions = ListUtil.map(branches, Util.tuple21)
        @assign stmtsList = ListUtil.map(branches, Util.tuple22)
        @assign algsLst = ListUtil.mapList(stmtsList, statementToAlgorithmItem)
        @assign abranches = ListUtil.threadTuple(conditions, algsLst)
        @assign algs2 = ListUtil.map(elseBranch, statementToAlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_IF(boolExpr, algs1, abranches, algs2), NONE(), info)
      end

      SCode.ALG_FOR(iterator, range, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem)
        Absyn.ALGORITHMITEM(
          Absyn.ALG_FOR(list(Absyn.ITERATOR(iterator, NONE(), range)), algs1),
          NONE(),
          info,
        )
      end

      SCode.ALG_PARFOR(iterator, range, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem)
        Absyn.ALGORITHMITEM(
          Absyn.ALG_PARFOR(list(Absyn.ITERATOR(iterator, NONE(), range)), algs1),
          NONE(),
          info,
        )
      end

      SCode.ALG_WHILE(boolExpr, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_WHILE(boolExpr, algs1), NONE(), info)
      end

      SCode.ALG_WHEN_A(branches, _, info) => begin
        @match _cons(boolExpr, conditions) = ListUtil.map(branches, Util.tuple21)
        @assign stmtsList = ListUtil.map(branches, Util.tuple22)
        @match _cons(algs1, algsLst) =
          ListUtil.mapList(stmtsList, statementToAlgorithmItem)
        @assign abranches = ListUtil.threadTuple(conditions, algsLst)
        Absyn.ALGORITHMITEM(Absyn.ALG_WHEN_A(boolExpr, algs1, abranches), NONE(), info)
      end

      SCode.ALG_ASSERT(__) => begin
        Absyn.ALGORITHMITEM(
          Absyn.ALG_NORETCALL(
            Absyn.CREF_IDENT("assert", nil),
            Absyn.FUNCTIONARGS(list(stmt.condition, stmt.message, stmt.level), nil),
          ),
          NONE(),
          stmt.info,
        )
      end

      SCode.ALG_TERMINATE(__) => begin
        Absyn.ALGORITHMITEM(
          Absyn.ALG_NORETCALL(
            Absyn.CREF_IDENT("terminate", nil),
            Absyn.FUNCTIONARGS(list(stmt.message), nil),
          ),
          NONE(),
          stmt.info,
        )
      end

      SCode.ALG_REINIT(__) => begin
        Absyn.ALGORITHMITEM(
          Absyn.ALG_NORETCALL(
            Absyn.CREF_IDENT("reinit", nil),
            Absyn.FUNCTIONARGS(list(stmt.cref, stmt.newValue), nil),
          ),
          NONE(),
          stmt.info,
        )
      end

      SCode.ALG_NORETCALL(
        Absyn.CALL(function_ = functionCall, functionArgs = functionArgs),
        _,
        info,
      ) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_NORETCALL(functionCall, functionArgs), NONE(), info)
      end

      SCode.ALG_RETURN(_, info) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_RETURN(), NONE(), info)
      end

      SCode.ALG_BREAK(_, info) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_BREAK(), NONE(), info)
      end

      SCode.ALG_CONTINUE(_, info) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_CONTINUE(), NONE(), info)
      end

      SCode.ALG_FAILURE(body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_FAILURE(algs1), NONE(), info)
      end
    end
  end
  return algi
end

function equationFileInfo(eq::SCode.EEquation)::SourceInfo
  local info::SourceInfo

  @assign info = begin
    @match eq begin
      SCode.EQ_IF(info = info) => begin
        info
      end

      SCode.EQ_EQUALS(info = info) => begin
        info
      end

      SCode.EQ_PDE(info = info) => begin
        info
      end

      SCode.EQ_CONNECT(info = info) => begin
        info
      end

      SCode.EQ_FOR(info = info) => begin
        info
      end

      SCode.EQ_WHEN(info = info) => begin
        info
      end

      SCode.EQ_ASSERT(info = info) => begin
        info
      end

      SCode.EQ_TERMINATE(info = info) => begin
        info
      end

      SCode.EQ_REINIT(info = info) => begin
        info
      end

      SCode.EQ_NORETCALL(info = info) => begin
        info
      end
    end
  end
  return info
end

"""Checks if a Mod is empty (or only an equality binding is present)"""
function emptyModOrEquality(mod::SCode.Mod)::Bool
  local b::Bool

  @assign b = begin
    @match mod begin
      SCode.NOMOD(__) => begin
        true
      end

      SCode.MOD(subModLst = nil()) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function isComponentWithDirection(elt::SCode.Element, dir1::Absyn.Direction)::Bool
  local b::Bool

  @assign b = begin
    local dir2::Absyn.Direction
    @match (elt, dir1) begin
      (SCode.COMPONENT(attributes = SCode.ATTR(direction = dir2)), _) => begin
        AbsynUtil.directionEqual(dir1, dir2)
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function isComponent(elt::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match elt begin
      SCode.COMPONENT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function isNotComponent(elt::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match elt begin
      SCode.COMPONENT(__) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return b
end

function isClassOrComponent(inElement::SCode.Element)::Bool
  local outIsClassOrComponent::Bool

  @assign outIsClassOrComponent = begin
    @match inElement begin
      SCode.CLASS(__) => begin
        true
      end

      SCode.COMPONENT(__) => begin
        true
      end
    end
  end
  return outIsClassOrComponent
end

function isClass(inElement::SCode.Element)::Bool
  local outIsClass::Bool

  @assign outIsClass = begin
    @match inElement begin
      SCode.CLASS(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsClass
end

"""
  Calls the given function on the equation and all its subequations, and
  updates the argument for each call.
"""
function foldEEquations(
  inEquation::SCode.EEquation,
  inFunc::FoldFunc,
  inArg::ArgT,
) where {ArgT}
  local outArg::ArgT

  @assign outArg = inFunc(inEquation, inArg)
  @assign outArg = begin
    local eql::List{SCode.EEquation}
    @match inEquation begin
      SCode.EQ_IF(__) => begin
        @assign outArg =
          ListUtil.foldList1(inEquation.thenBranch, foldEEquations, inFunc, outArg)
        ListUtil.fold1(inEquation.elseBranch, foldEEquations, inFunc, outArg)
      end

      SCode.EQ_FOR(__) => begin
        ListUtil.fold1(inEquation.eEquationLst, foldEEquations, inFunc, outArg)
      end

      SCode.EQ_WHEN(__) => begin
        @assign outArg =
          ListUtil.fold1(inEquation.eEquationLst, foldEEquations, inFunc, outArg)
        for branch in inEquation.elseBranches
          @assign (_, eql) = branch
          @assign outArg = ListUtil.fold1(eql, foldEEquations, inFunc, outArg)
        end
        outArg
      end
    end
  end
  return outArg
end

"""
  Calls the given function on all expressions inside the equation, and updates
  the argument for each call.
"""
function foldEEquationsExps(
  inEquation::SCode.EEquation,
  inFunc::FoldFunc,
  inArg::ArgT,
) where {ArgT}
  local outArg::ArgT = inArg

  @assign outArg = begin
    local exp::Absyn.Exp
    local eql::List{SCode.EEquation}
    @match inEquation begin
      SCode.EQ_IF(__) => begin
        @assign outArg = ListUtil.fold(inEquation.condition, inFunc, outArg)
        @assign outArg =
          ListUtil.foldList1(inEquation.thenBranch, foldEEquationsExps, inFunc, outArg)
        ListUtil.fold1(inEquation.elseBranch, foldEEquationsExps, inFunc, outArg)
      end

      SCode.EQ_EQUALS(__) => begin
        @assign outArg = inFunc(inEquation.expLeft, outArg)
        @assign outArg = inFunc(inEquation.expRight, outArg)
        outArg
      end

      SCode.EQ_PDE(__) => begin
        @assign outArg = inFunc(inEquation.expLeft, outArg)
        @assign outArg = inFunc(inEquation.expRight, outArg)
        outArg
      end

      SCode.EQ_CONNECT(__) => begin
        @assign outArg = inFunc(Absyn.CREF(inEquation.crefLeft), outArg)
        @assign outArg = inFunc(Absyn.CREF(inEquation.crefRight), outArg)
        outArg
      end

      SCode.EQ_FOR(__) => begin
        if isSome(inEquation.range)
          @match SOME(exp) = inEquation.range
          @assign outArg = inFunc(exp, outArg)
        end
        ListUtil.fold1(inEquation.eEquationLst, foldEEquationsExps, inFunc, outArg)
      end

      SCode.EQ_WHEN(__) => begin
        @assign outArg =
          ListUtil.fold1(inEquation.eEquationLst, foldEEquationsExps, inFunc, outArg)
        for branch in inEquation.elseBranches
          @assign (exp, eql) = branch
          @assign outArg = inFunc(exp, outArg)
          @assign outArg = ListUtil.fold1(eql, foldEEquationsExps, inFunc, outArg)
        end
        outArg
      end

      SCode.EQ_ASSERT(__) => begin
        @assign outArg = inFunc(inEquation.condition, outArg)
        @assign outArg = inFunc(inEquation.message, outArg)
        @assign outArg = inFunc(inEquation.level, outArg)
        outArg
      end

      SCode.EQ_TERMINATE(__) => begin
        inFunc(inEquation.message, outArg)
      end

      SCode.EQ_REINIT(__) => begin
        @assign outArg = inFunc(inEquation.cref, outArg)
        @assign outArg = inFunc(inEquation.expReinit, outArg)
        outArg
      end

      SCode.EQ_NORETCALL(__) => begin
        inFunc(inEquation.exp, outArg)
      end
    end
  end
  return outArg
end

"""
  Calls the given function on all expressions inside the statement, and updates
  the argument for each call.
"""
function foldStatementsExps(
  inStatement::SCode.Statement,
  inFunc::FoldFunc,
  inArg::ArgT,
) where {ArgT}
  local outArg::ArgT = inArg

  @assign outArg = begin
    local exp::Absyn.Exp
    local stmts::List{SCode.Statement}
    @match inStatement begin
      SCode.ALG_ASSIGN(__) => begin
        @assign outArg = inFunc(inStatement.assignComponent, outArg)
        @assign outArg = inFunc(inStatement.value, outArg)
        outArg
      end

      SCode.ALG_IF(__) => begin
        @assign outArg = inFunc(inStatement.boolExpr, outArg)
        @assign outArg =
          ListUtil.fold1(inStatement.trueBranch, foldStatementsExps, inFunc, outArg)
        for branch in inStatement.elseIfBranch
          @assign (exp, stmts) = branch
          @assign outArg = inFunc(exp, outArg)
          @assign outArg = ListUtil.fold1(stmts, foldStatementsExps, inFunc, outArg)
        end
        outArg
      end

      SCode.ALG_FOR(__) => begin
        if isSome(inStatement.range)
          @match SOME(exp) = inStatement.range
          @assign outArg = inFunc(exp, outArg)
        end
        ListUtil.fold1(inStatement.forBody, foldStatementsExps, inFunc, outArg)
      end

      SCode.ALG_PARFOR(__) => begin
        if isSome(inStatement.range)
          @match SOME(exp) = inStatement.range
          @assign outArg = inFunc(exp, outArg)
        end
        ListUtil.fold1(inStatement.parforBody, foldStatementsExps, inFunc, outArg)
      end

      SCode.ALG_WHILE(__) => begin
        @assign outArg = inFunc(inStatement.boolExpr, outArg)
        ListUtil.fold1(inStatement.whileBody, foldStatementsExps, inFunc, outArg)
      end

      SCode.ALG_WHEN_A(__) => begin
        for branch in inStatement.branches
          @assign (exp, stmts) = branch
          @assign outArg = inFunc(exp, outArg)
          @assign outArg = ListUtil.fold1(stmts, foldStatementsExps, inFunc, outArg)
        end
        outArg
      end

      SCode.ALG_ASSERT(__) => begin
        @assign outArg = inFunc(inStatement.condition, outArg)
        @assign outArg = inFunc(inStatement.message, outArg)
        @assign outArg = inFunc(inStatement.level, outArg)
        outArg
      end

      SCode.ALG_TERMINATE(__) => begin
        inFunc(inStatement.message, outArg)
      end

      SCode.ALG_REINIT(__) => begin
        @assign outArg = inFunc(inStatement.cref, outArg)
        inFunc(inStatement.newValue, outArg)
      end

      SCode.ALG_NORETCALL(__) => begin
        inFunc(inStatement.exp, outArg)
      end

      SCode.ALG_FAILURE(__) => begin
        ListUtil.fold1(inStatement.stmts, foldStatementsExps, inFunc, outArg)
      end

      SCode.ALG_TRY(__) => begin
        @assign outArg =
          ListUtil.fold1(inStatement.body, foldStatementsExps, inFunc, outArg)
        ListUtil.fold1(inStatement.elseBody, foldStatementsExps, inFunc, outArg)
      end

      SCode.ALG_RETURN(__) => begin
        outArg
      end

      SCode.ALG_BREAK(__) => begin
        outArg
      end

      SCode.ALG_CONTINUE(__) => begin
        outArg
      end
    end
  end
  #=  No else case, to make this function break if a new statement is added to SCode.
  =#
  return outArg
end

"""
  Traverses a list of SCode.EEquations, calling traverseEEquations on each SCode.EEquation
  in the list.
"""
function traverseEEquationsList(
  inEEquations::List{<:SCode.EEquation},
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{List{SCode.EEquation}, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outEEquations::List{SCode.EEquation}

  @assign (outEEquations, outTuple) =
    ListUtil.mapFold(inEEquations, traverseEEquations, inTuple)
  return (outEEquations, outTuple)
end

"""
  Traverses an SCode.EEquation. For each SCode.EEquation it finds it calls the given
  function with the SCode.EEquation and an extra argument which is passed along.
"""
function traverseEEquations(
  inEEquation::SCode.EEquation,
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{SCode.EEquation, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outEEquation::SCode.EEquation

  local traverser::TraverseFunc
  local arg::Argument
  local eq::SCode.EEquation

  @assign (traverser, arg) = inTuple
  @assign (eq, arg) = traverser((inEEquation, arg))
  @assign (outEEquation, outTuple) = traverseEEquations2(eq, (traverser, arg))
  return (outEEquation, outTuple)
end

"""Helper function to traverseEEquations, does the actual traversing."""
function traverseEEquations2(
  inEEquation::SCode.EEquation,
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{SCode.EEquation, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outEEquation::SCode.EEquation

  @assign (outEEquation, outTuple) = begin
    local tup::Tuple{TraverseFunc, Argument}
    local e1::Absyn.Exp
    local oe1::Option{Absyn.Exp}
    local expl1::List{Absyn.Exp}
    local then_branch::List{List{SCode.EEquation}}
    local else_branch::List{SCode.EEquation}
    local eql::List{SCode.EEquation}
    local else_when::List{Tuple{Absyn.Exp, List{SCode.EEquation}}}
    local comment::SCode.Comment
    local info::SourceInfo
    local index::SCode.Ident
    @match (inEEquation, inTuple) begin
      (SCode.EQ_IF(expl1, then_branch, else_branch, comment, info), tup) => begin
        @assign (then_branch, tup) =
          ListUtil.mapFold(then_branch, traverseEEquationsList, tup)
        @assign (else_branch, tup) = traverseEEquationsList(else_branch, tup)
        (SCode.EQ_IF(expl1, then_branch, else_branch, comment, info), tup)
      end

      (SCode.EQ_FOR(index, oe1, eql, comment, info), tup) => begin
        @assign (eql, tup) = traverseEEquationsList(eql, tup)
        (SCode.EQ_FOR(index, oe1, eql, comment, info), tup)
      end

      (SCode.EQ_WHEN(e1, eql, else_when, comment, info), tup) => begin
        @assign (eql, tup) = traverseEEquationsList(eql, tup)
        @assign (else_when, tup) =
          ListUtil.mapFold(else_when, traverseElseWhenEEquations, tup)
        (SCode.EQ_WHEN(e1, eql, else_when, comment, info), tup)
      end

      _ => begin
        (inEEquation, inTuple)
      end
    end
  end
  return (outEEquation, outTuple)
end

"""
  Traverses all SCode.EEquations in an else when branch, calling the given function
  on each SCode.EEquation.
"""
function traverseElseWhenEEquations(
  inElseWhen::Tuple{<:Absyn.Exp, List{<:SCode.EEquation}},
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{Tuple{Absyn.Exp, List{SCode.EEquation}}, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outElseWhen::Tuple{Absyn.Exp, List{SCode.EEquation}}

  local exp::Absyn.Exp
  local eql::List{SCode.EEquation}

  @assign (exp, eql) = inElseWhen
  @assign (eql, outTuple) = traverseEEquationsList(eql, inTuple)
  @assign outElseWhen = (exp, eql)
  return (outElseWhen, outTuple)
end

"""
  Traverses a list of SCode.EEquations, calling the given function on each Absyn.Exp
  it encounters.
"""
function traverseEEquationListExps(
  inEEquations::List{<:SCode.EEquation},
  traverser::TraverseFunc,
  inArg::Argument,
)::Tuple{List{SCode.EEquation}, Argument}
  local outArg::Argument
  local outEEquations::List{SCode.EEquation}

  @assign (outEEquations, outArg) =
    ListUtil.map1Fold(inEEquations, traverseEEquationExps, traverser, inArg)
  return (outEEquations, outArg)
end

"""
  Traverses an SCode.EEquation, calling the given function on each Absyn.Exp it
  encounters. This funcion is intended to be used together with
  traverseEEquations, and does NOT descend into sub-EEquations.
"""
function traverseEEquationExps(
  inEEquation::SCode.EEquation,
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{SCode.EEquation, Argument}
  local outArg::Argument
  local outEEquation::SCode.EEquation

  @assign (outEEquation, outArg) = begin
    local traverser::TraverseFunc
    local arg::Argument
    local tup::Tuple{TraverseFunc, Argument}
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local e3::Absyn.Exp
    local expl1::List{Absyn.Exp}
    local then_branch::List{List{SCode.EEquation}}
    local else_branch::List{SCode.EEquation}
    local eql::List{SCode.EEquation}
    local else_when::List{Tuple{Absyn.Exp, List{SCode.EEquation}}}
    local comment::SCode.Comment
    local info::SourceInfo
    local cr1::Absyn.ComponentRef
    local cr2::Absyn.ComponentRef
    local domain::Absyn.ComponentRef
    local index::SCode.Ident
    @match (inEEquation, inFunc, inArg) begin
      (SCode.EQ_IF(expl1, then_branch, else_branch, comment, info), traverser, arg) =>
        begin
          @assign (expl1, arg) = AbsynUtil.traverseExpList(expl1, traverser, arg)
          (SCode.EQ_IF(expl1, then_branch, else_branch, comment, info), arg)
        end

      (SCode.EQ_EQUALS(e1, e2, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (e2, arg) = traverser(e2, arg)
        (SCode.EQ_EQUALS(e1, e2, comment, info), arg)
      end

      (SCode.EQ_PDE(e1, e2, domain, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (e2, arg) = traverser(e2, arg)
        (SCode.EQ_PDE(e1, e2, domain, comment, info), arg)
      end

      (SCode.EQ_CONNECT(cr1, cr2, comment, info), _, _) => begin
        @assign (cr1, arg) = traverseComponentRefExps(cr1, inFunc, inArg)
        @assign (cr2, arg) = traverseComponentRefExps(cr2, inFunc, arg)
        (SCode.EQ_CONNECT(cr1, cr2, comment, info), arg)
      end

      (SCode.EQ_FOR(index, SOME(e1), eql, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.EQ_FOR(index, SOME(e1), eql, comment, info), arg)
      end

      (SCode.EQ_WHEN(e1, eql, else_when, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (else_when, arg) =
          ListUtil.map1Fold(else_when, traverseElseWhenExps, traverser, arg)
        (SCode.EQ_WHEN(e1, eql, else_when, comment, info), arg)
      end

      (SCode.EQ_ASSERT(e1, e2, e3, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (e2, arg) = traverser(e2, arg)
        @assign (e3, arg) = traverser(e3, arg)
        (SCode.EQ_ASSERT(e1, e2, e3, comment, info), arg)
      end

      (SCode.EQ_TERMINATE(e1, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.EQ_TERMINATE(e1, comment, info), arg)
      end

      (SCode.EQ_REINIT(e1, e2, comment, info), traverser, _) => begin
        @assign (e1, arg) = traverser(e1, inArg)
        @assign (e2, arg) = traverser(e2, arg)
        (SCode.EQ_REINIT(e1, e2, comment, info), arg)
      end

      (SCode.EQ_NORETCALL(e1, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.EQ_NORETCALL(e1, comment, info), arg)
      end

      _ => begin
        (inEEquation, inArg)
      end
    end
  end
  return (outEEquation, outArg)
end

"""
  Traverses the subscripts of a component reference and calls the given
  function on the subscript expressions.
"""
function traverseComponentRefExps(
  inCref::Absyn.ComponentRef,
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{Absyn.ComponentRef, Argument}
  local outArg::Argument
  local outCref::Absyn.ComponentRef

  @assign (outCref, outArg) = begin
    local name::Absyn.Ident
    local subs::List{Absyn.Subscript}
    local cr::Absyn.ComponentRef
    local arg::Argument
    @match (inCref, inFunc, inArg) begin
      (Absyn.CREF_FULLYQUALIFIED(componentRef = cr), _, _) => begin
        @assign (cr, arg) = traverseComponentRefExps(cr, inFunc, inArg)
        (AbsynUtil.crefMakeFullyQualified(cr), arg)
      end

      (Absyn.CREF_QUAL(name = name, subscripts = subs, componentRef = cr), _, _) => begin
        @assign (cr, arg) = traverseComponentRefExps(cr, inFunc, inArg)
        @assign (subs, arg) = ListUtil.map1Fold(subs, traverseSubscriptExps, inFunc, arg)
        (Absyn.CREF_QUAL(name, subs, cr), arg)
      end

      (Absyn.CREF_IDENT(name = name, subscripts = subs), _, _) => begin
        @assign (subs, arg) = ListUtil.map1Fold(subs, traverseSubscriptExps, inFunc, inArg)
        (Absyn.CREF_IDENT(name, subs), arg)
      end

      (Absyn.WILD(__), _, _) => begin
        (inCref, inArg)
      end
    end
  end
  return (outCref, outArg)
end

"""Calls the given function on the subscript expression."""
function traverseSubscriptExps(
  inSubscript::Absyn.Subscript,
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{Absyn.Subscript, Argument}
  local outArg::Argument
  local outSubscript::Absyn.Subscript

  @assign (outSubscript, outArg) = begin
    local sub_exp::Absyn.Exp
    local traverser::TraverseFunc
    local arg::Argument
    @match (inSubscript, inFunc, inArg) begin
      (Absyn.SUBSCRIPT(subscript = sub_exp), traverser, arg) => begin
        @assign (sub_exp, arg) = traverser(sub_exp, arg)
        (Absyn.SUBSCRIPT(sub_exp), arg)
      end

      (Absyn.NOSUB(__), _, _) => begin
        (inSubscript, inArg)
      end
    end
  end
  return (outSubscript, outArg)
end

"""
  Traverses the expressions in an else when branch, and calls the given
  function on the expressions.
"""
function traverseElseWhenExps(
  inElseWhen::Tuple{<:Absyn.Exp, List{<:SCode.EEquation}},
  traverser::TraverseFunc,
  inArg::Argument,
)::Tuple{Tuple{Absyn.Exp, List{SCode.EEquation}}, Argument}
  local outArg::Argument
  local outElseWhen::Tuple{Absyn.Exp, List{SCode.EEquation}}

  local exp::Absyn.Exp
  local eql::List{SCode.EEquation}

  @assign (exp, eql) = inElseWhen
  @assign (exp, outArg) = traverser(exp, inArg)
  @assign outElseWhen = (exp, eql)
  return (outElseWhen, outArg)
end

"""
  Calls the given function on the value expression associated with a named
  function argument.
"""
function traverseNamedArgExps(
  inArg::Absyn.NamedArg,
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{Absyn.NamedArg, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outArg::Absyn.NamedArg

  local traverser::TraverseFunc
  local arg::Argument
  local name::Absyn.Ident
  local value::Absyn.Exp

  @assign (traverser, arg) = inTuple
  @match Absyn.NAMEDARG(argName = name, argValue = value) = inArg
  @assign (value, arg) = traverser(value, arg)
  @assign outArg = Absyn.NAMEDARG(name, value)
  @assign outTuple = (traverser, arg)
  return (outArg, outTuple)
end

"""Calls the given function on the expression associated with a for iterator."""
function traverseForIteratorExps(
  inIterator::Absyn.ForIterator,
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{Absyn.ForIterator, Argument}
  local outArg::Argument
  local outIterator::Absyn.ForIterator

  @assign (outIterator, outArg) = begin
    local traverser::TraverseFunc
    local arg::Argument
    local ident::Absyn.Ident
    local guardExp::Absyn.Exp
    local range::Absyn.Exp
    @match (inIterator, inFunc, inArg) begin
      (Absyn.ITERATOR(ident, NONE(), NONE()), _, arg) => begin
        (Absyn.ITERATOR(ident, NONE(), NONE()), arg)
      end

      (Absyn.ITERATOR(ident, NONE(), SOME(range)), traverser, arg) => begin
        @assign (range, arg) = traverser(range, arg)
        (Absyn.ITERATOR(ident, NONE(), SOME(range)), arg)
      end

      (Absyn.ITERATOR(ident, SOME(guardExp), SOME(range)), traverser, arg) => begin
        @assign (guardExp, arg) = traverser(guardExp, arg)
        @assign (range, arg) = traverser(range, arg)
        (Absyn.ITERATOR(ident, SOME(guardExp), SOME(range)), arg)
      end

      (Absyn.ITERATOR(ident, SOME(guardExp), NONE()), traverser, arg) => begin
        @assign (guardExp, arg) = traverser(guardExp, arg)
        (Absyn.ITERATOR(ident, SOME(guardExp), NONE()), arg)
      end
    end
  end
  return (outIterator, outArg)
end

"""Calls traverseStatement on each statement in the given list."""
function traverseStatementsList(
  inStatements::List{<:SCode.Statement},
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{List{SCode.Statement}, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outStatements::List{SCode.Statement}

  @assign (outStatements, outTuple) =
    ListUtil.mapFold(inStatements, traverseStatements, inTuple)
  return (outStatements, outTuple)
end

"""
  Traverses all statements in the given statement in a top-down approach where
  the given function is applied to each statement found, beginning with the given
  statement.
"""
function traverseStatements(
  inStatement::SCode.Statement,
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{SCode.Statement, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outStatement::SCode.Statement

  local traverser::TraverseFunc
  local arg::Argument
  local stmt::SCode.Statement

  @assign (traverser, arg) = inTuple
  @assign (stmt, arg) = traverser((inStatement, arg))
  @assign (outStatement, outTuple) = traverseStatements2(stmt, (traverser, arg))
  return (outStatement, outTuple)
end

"""
  Helper function to traverseStatements. Goes through each statement contained
  in the given statement and calls traverseStatements on them.
"""
function traverseStatements2(
  inStatement::SCode.Statement,
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{SCode.Statement, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outStatement::SCode.Statement

  @assign (outStatement, outTuple) = begin
    local traverser::TraverseFunc
    local arg::Argument
    local tup::Tuple{TraverseFunc, Argument}
    local e::Absyn.Exp
    local stmts1::List{SCode.Statement}
    local stmts2::List{SCode.Statement}
    local branches::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
    local comment::SCode.Comment
    local info::SourceInfo
    local iter::String
    local range::Option{Absyn.Exp}
    @match (inStatement, inTuple) begin
      (SCode.ALG_IF(e, stmts1, branches, stmts2, comment, info), tup) => begin
        @assign (stmts1, tup) = traverseStatementsList(stmts1, tup)
        @assign (branches, tup) =
          ListUtil.mapFold(branches, traverseBranchStatements, tup)
        @assign (stmts2, tup) = traverseStatementsList(stmts2, tup)
        (SCode.ALG_IF(e, stmts1, branches, stmts2, comment, info), tup)
      end

      (SCode.ALG_FOR(iter, range, stmts1, comment, info), tup) => begin
        @assign (stmts1, tup) = traverseStatementsList(stmts1, tup)
        (SCode.ALG_FOR(iter, range, stmts1, comment, info), tup)
      end

      (SCode.ALG_PARFOR(iter, range, stmts1, comment, info), tup) => begin
        @assign (stmts1, tup) = traverseStatementsList(stmts1, tup)
        (SCode.ALG_PARFOR(iter, range, stmts1, comment, info), tup)
      end

      (SCode.ALG_WHILE(e, stmts1, comment, info), tup) => begin
        @assign (stmts1, tup) = traverseStatementsList(stmts1, tup)
        (SCode.ALG_WHILE(e, stmts1, comment, info), tup)
      end

      (SCode.ALG_WHEN_A(branches, comment, info), tup) => begin
        @assign (branches, tup) = ListUtil.mapFold(branches, traverseBranchStatements, tup)
        (SCode.ALG_WHEN_A(branches, comment, info), tup)
      end

      (SCode.ALG_FAILURE(stmts1, comment, info), tup) => begin
        @assign (stmts1, tup) = traverseStatementsList(stmts1, tup)
        (SCode.ALG_FAILURE(stmts1, comment, info), tup)
      end

      _ => begin
        (inStatement, inTuple)
      end
    end
  end
  return (outStatement, outTuple)
end

"""
  Helper function to traverseStatements2. Calls traverseStatement each
  statement in a given branch.
"""
function traverseBranchStatements(
  inBranch::Tuple{<:Absyn.Exp, List{<:SCode.Statement}},
  inTuple::Tuple{<:TraverseFunc, Argument},
)::Tuple{Tuple{Absyn.Exp, List{SCode.Statement}}, Tuple{TraverseFunc, Argument}}
  local outTuple::Tuple{TraverseFunc, Argument}
  local outBranch::Tuple{Absyn.Exp, List{SCode.Statement}}

  local exp::Absyn.Exp
  local stmts::List{SCode.Statement}

  @assign (exp, stmts) = inBranch
  @assign (stmts, outTuple) = traverseStatementsList(stmts, inTuple)
  @assign outBranch = (exp, stmts)
  return (outBranch, outTuple)
end

"""
  Traverses a list of statements and calls the given function on each
  expression found.
"""
function traverseStatementListExps(
  inStatements::List{<:SCode.Statement},
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{List{SCode.Statement}, Argument}
  local outArg::Argument
  local outStatements::List{SCode.Statement}

  @assign (outStatements, outArg) =
    ListUtil.map1Fold(inStatements, traverseStatementExps, inFunc, inArg)
  return (outStatements, outArg)
end

"""
  Applies the given function to each expression in the given statement. This
  function is intended to be used together with traverseStatements, and does NOT
  descend into sub-statements.
"""
function traverseStatementExps(
  inStatement::SCode.Statement,
  inFunc::TraverseFunc,
  inArg::Argument,
)::Tuple{SCode.Statement, Argument}
  local outArg::Argument
  local outStatement::SCode.Statement

  @assign (outStatement, outArg) = begin
    local traverser::TraverseFunc
    local arg::Argument
    local tup::Tuple{TraverseFunc, Argument}
    local iterator::String
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local e3::Absyn.Exp
    local stmts1::List{SCode.Statement}
    local stmts2::List{SCode.Statement}
    local branches::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
    local comment::SCode.Comment
    local info::SourceInfo
    local cref::Absyn.ComponentRef
    @match (inStatement, inFunc, inArg) begin
      (SCode.ALG_ASSIGN(e1, e2, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (e2, arg) = traverser(e2, arg)
        (SCode.ALG_ASSIGN(e1, e2, comment, info), arg)
      end

      (SCode.ALG_IF(e1, stmts1, branches, stmts2, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        @assign (branches, arg) =
          ListUtil.map1Fold(branches, traverseBranchExps, traverser, arg)
        (SCode.ALG_IF(e1, stmts1, branches, stmts2, comment, info), arg)
      end

      (SCode.ALG_FOR(iterator, SOME(e1), stmts1, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.ALG_FOR(iterator, SOME(e1), stmts1, comment, info), arg)
      end

      (SCode.ALG_PARFOR(iterator, SOME(e1), stmts1, comment, info), traverser, arg) =>
        begin
          @assign (e1, arg) = traverser(e1, arg)
          (SCode.ALG_PARFOR(iterator, SOME(e1), stmts1, comment, info), arg)
        end

      (SCode.ALG_WHILE(e1, stmts1, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.ALG_WHILE(e1, stmts1, comment, info), arg)
      end

      (SCode.ALG_WHEN_A(branches, comment, info), traverser, arg) => begin
        @assign (branches, arg) =
          ListUtil.map1Fold(branches, traverseBranchExps, traverser, arg)
        (SCode.ALG_WHEN_A(branches, comment, info), arg)
      end

      (SCode.ALG_ASSERT(__), traverser, arg) => begin
        @assign (e1, arg) = traverser(inStatement.condition, arg)
        @assign (e2, arg) = traverser(inStatement.message, arg)
        @assign (e3, arg) = traverser(inStatement.level, arg)
        (SCode.ALG_ASSERT(e1, e2, e3, inStatement.comment, inStatement.info), arg)
      end

      (SCode.ALG_TERMINATE(__), traverser, arg) => begin
        @assign (e1, arg) = traverser(inStatement.message, arg)
        (SCode.ALG_TERMINATE(e1, inStatement.comment, inStatement.info), arg)
      end

      (SCode.ALG_REINIT(__), traverser, arg) => begin
        @assign (e1, arg) = traverser(inStatement.cref, arg)
        @assign (e2, arg) = traverser(inStatement.newValue, arg)
        (SCode.ALG_REINIT(e1, e2, inStatement.comment, inStatement.info), arg)
      end

      (SCode.ALG_NORETCALL(e1, comment, info), traverser, arg) => begin
        @assign (e1, arg) = traverser(e1, arg)
        (SCode.ALG_NORETCALL(e1, comment, info), arg)
      end

      _ => begin
        (inStatement, inArg)
      end
    end
  end
  return (outStatement, outArg)
end

"""Calls the given function on each expression found in an if or when branch."""
function traverseBranchExps(
  inBranch::Tuple{<:Absyn.Exp, List{<:SCode.Statement}},
  traverser::TraverseFunc,
  inArg::Argument,
)::Tuple{Tuple{Absyn.Exp, List{SCode.Statement}}, Argument}
  local outArg::Argument
  local outBranch::Tuple{Absyn.Exp, List{SCode.Statement}}

  local arg::Argument
  local exp::Absyn.Exp
  local stmts::List{SCode.Statement}

  @assign (exp, stmts) = inBranch
  @assign (exp, outArg) = traverser(exp, inArg)
  @assign outBranch = (exp, stmts)
  return (outBranch, outArg)
end

function elementIsClass(el::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match el begin
      SCode.CLASS(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function elementIsImport(inElement::SCode.Element)::Bool
  local outIsImport::Bool

  @assign outIsImport = begin
    @match inElement begin
      SCode.IMPORT(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsImport
end

function elementIsPublicImport(el::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match el begin
      SCode.IMPORT(visibility = SCode.PUBLIC(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function elementIsProtectedImport(el::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match el begin
      SCode.IMPORT(visibility = SCode.PROTECTED(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return b
end

function getElementClass(el::SCode.Element)::SCode.Element
  local cl::SCode.Element

  @assign cl = begin
    @match el begin
      SCode.CLASS(__) => begin
        el
      end

      _ => begin
        fail()
      end
    end
  end
  return cl
end

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

function isBuiltinFunction(
  cl::SCode.Element,
  inVars::List{<:String},
  outVars::List{<:String},
)::String
  local name::String

  @assign name = begin
    local outVar1::String
    local outVar2::String
    local argsStr::List{String}
    local args::List{Absyn.Exp}
    @match (cl, inVars, outVars) begin
      (
        SCode.CLASS(
          name = name,
          restriction = SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(
              funcName = NONE(),
              lang = SOME("builtin"),
            )),
          ),
        ),
        _,
        _,
      ) => begin
        name
      end

      (
        SCode.CLASS(
          restriction = SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(
              funcName = SOME(name),
              lang = SOME("builtin"),
            )),
          ),
        ),
        _,
        _,
      ) => begin
        name
      end

      (
        SCode.CLASS(
          name = name,
          restriction = SCode.R_FUNCTION(SCode.FR_PARALLEL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(
              funcName = NONE(),
              lang = SOME("builtin"),
            )),
          ),
        ),
        _,
        _,
      ) => begin
        name
      end

      (
        SCode.CLASS(
          restriction = SCode.R_FUNCTION(SCode.FR_PARALLEL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(
              funcName = SOME(name),
              lang = SOME("builtin"),
            )),
          ),
        ),
        _,
        _,
      ) => begin
        name
      end

      (
        SCode.CLASS(
          restriction = SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(
              funcName = SOME(name),
              lang = SOME("C"),
              output_ = SOME(Absyn.CREF_IDENT(outVar2, nil())),
              args = args,
            )),
          ),
        ),
        _,
        outVar1 <| nil(),
      ) => begin
        @match true = listMember(name, knownExternalCFunctions)
        @match true = outVar2 == outVar1
        @assign argsStr = ListUtil.mapMap(args, AbsynUtil.expCref, AbsynUtil.crefIdent)
        equality(argsStr, inVars)
        name
      end

      (
        SCode.CLASS(
          name = name,
          restriction = SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(__)),
          classDef = SCode.PARTS(
            externalDecl = SOME(SCode.EXTERNALDECL(funcName = NONE(), lang = SOME("C"))),
          ),
        ),
        _,
        _,
      ) => begin
        @match true = listMember(name, knownExternalCFunctions)
        name
      end
    end
  end
  return name
end

"""Extracts the SourceInfo from an SCode.EEquation."""
function getEEquationInfo(inEEquation::SCode.EEquation)::SourceInfo
  local outInfo::SourceInfo

  @assign outInfo = begin
    local info::SourceInfo
    @match inEEquation begin
      SCode.EQ_IF(info = info) => begin
        info
      end

      SCode.EQ_EQUALS(info = info) => begin
        info
      end

      SCode.EQ_PDE(info = info) => begin
        info
      end

      SCode.EQ_CONNECT(info = info) => begin
        info
      end

      SCode.EQ_FOR(info = info) => begin
        info
      end

      SCode.EQ_WHEN(info = info) => begin
        info
      end

      SCode.EQ_ASSERT(info = info) => begin
        info
      end

      SCode.EQ_TERMINATE(info = info) => begin
        info
      end

      SCode.EQ_REINIT(info = info) => begin
        info
      end

      SCode.EQ_NORETCALL(info = info) => begin
        info
      end
    end
  end
  return outInfo
end

"""Extracts the SourceInfo from a Statement."""
function getStatementInfo(inStatement::SCode.Statement)::SourceInfo
  local outInfo::SourceInfo

  @assign outInfo = begin
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
  return outInfo
end

function prependSubModToMod(subMod::SCode.SubMod, mod::SCode.Mod)
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

"""Adds a given element to a class definition. Only implemented for PARTS."""
function addElementToClass(
  inElement::SCode.Element,
  inClassDef::SCode.Element,
)::SCode.Element
  local outClassDef::SCode.Element

  local cdef::SCode.ClassDef

  @match SCode.CLASS(classDef = cdef) = inClassDef
  @assign cdef = addElementToCompositeClassDef(inElement, cdef)
  @assign outClassDef = setElementClassDefinition(cdef, inClassDef)
  return outClassDef
end

"""Adds a given element to a PARTS class definition."""
function addElementToCompositeClassDef(
  inElement::SCode.Element,
  inClassDef::SCode.ClassDef,
)::SCode.ClassDef
  local outClassDef::SCode.ClassDef

  local el::List{SCode.Element}
  local nel::List{SCode.Equation}
  local iel::List{SCode.Equation}
  local nal::List{SCode.AlgorithmSection}
  local ial::List{SCode.AlgorithmSection}
  local nco::List{SCode.ConstraintSection}
  local ed::Option{SCode.ExternalDecl}
  local clsattrs::List{Absyn.NamedArg}

  @match SCode.PARTS(el, nel, iel, nal, ial, nco, clsattrs, ed) = inClassDef
  @assign outClassDef =
    SCode.PARTS(_cons(inElement, el), nel, iel, nal, ial, nco, clsattrs, ed)
  return outClassDef
end

function setElementClassDefinition(
  inClassDef::SCode.ClassDef,
  inElement::SCode.Element,
)::SCode.Element
  local outElement::SCode.Element

  local n::SCode.Ident
  local pf::SCode.Prefixes
  local pp::SCode.Partial
  local ep::SCode.Encapsulated
  local r::SCode.Restriction
  local i::SourceInfo
  local cmt::SCode.Comment

  @match SCode.CLASS(n, pf, ep, pp, r, _, cmt, i) = inElement
  @assign outElement = SCode.CLASS(n, pf, ep, pp, r, inClassDef, cmt, i)
  return outElement
end

"""returns true for PUBLIC and false for PROTECTED"""
function visibilityBool(inVisibility::SCode.Visibility)::Bool
  local bVisibility::Bool

  @assign bVisibility = begin
    @match inVisibility begin
      SCode.PUBLIC(__) => begin
        true
      end

      SCode.PROTECTED(__) => begin
        false
      end
    end
  end
  return bVisibility
end

"""returns for PUBLIC true and for PROTECTED false"""
function boolVisibility(inBoolVisibility::Bool)::SCode.Visibility
  local outVisibility::SCode.Visibility

  @assign outVisibility = begin
    @match inBoolVisibility begin
      true => begin
        SCode.PUBLIC()
      end

      false => begin
        SCode.PROTECTED()
      end
    end
  end
  return outVisibility
end

function visibilityEqual(
  inVisibility1::SCode.Visibility,
  inVisibility2::SCode.Visibility,
)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (inVisibility1, inVisibility2) begin
      (SCode.PUBLIC(__), SCode.PUBLIC(__)) => begin
        true
      end

      (SCode.PROTECTED(__), SCode.PROTECTED(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outEqual
end

eachBool(inEach::SCode.EACH) = true
eachBool(inEach::SCode.NOT_EACH) = false

function boolEach(inBoolEach::Bool)
  if inBoolEach
    return SCode.EACH()
  else
    return SCode.NOT_EACH()
  end
end

function prefixesRedeclare(inPrefixes::SCode.Prefixes)::SCode.Redeclare
  local outRedeclare::SCode.Redeclare

  @match SCode.PREFIXES(redeclarePrefix = outRedeclare) = inPrefixes
  return outRedeclare
end

function prefixesSetRedeclare(
  inPrefixes::SCode.Prefixes,
  inRedeclare::SCode.Redeclare,
)::SCode.Prefixes
  local outPrefixes::SCode.Prefixes

  local v::SCode.Visibility
  local f::SCode.Final
  local io::Absyn.InnerOuter
  local rp::SCode.Replaceable

  @match SCode.PREFIXES(v, _, f, io, rp) = inPrefixes
  @assign outPrefixes = SCode.PREFIXES(v, inRedeclare, f, io, rp)
  return outPrefixes
end

function prefixesSetReplaceable(
  inPrefixes::SCode.Prefixes,
  inReplaceable::SCode.Replaceable,
)::SCode.Prefixes
  local outPrefixes::SCode.Prefixes

  local v::SCode.Visibility
  local f::SCode.Final
  local io::Absyn.InnerOuter
  local rd::SCode.Redeclare

  @match SCode.PREFIXES(v, rd, f, io, _) = inPrefixes
  @assign outPrefixes = SCode.PREFIXES(v, rd, f, io, inReplaceable)
  return outPrefixes
end

function redeclareBool(inRedeclare::SCode.Redeclare)::Bool
  local bRedeclare::Bool

  @assign bRedeclare = begin
    @match inRedeclare begin
      SCode.REDECLARE(__) => begin
        true
      end

      SCode.NOT_REDECLARE(__) => begin
        false
      end
    end
  end
  return bRedeclare
end

function boolRedeclare(inBoolRedeclare::Bool)::SCode.Redeclare
  local outRedeclare::SCode.Redeclare

  @assign outRedeclare = begin
    @match inBoolRedeclare begin
      true => begin
        SCode.REDECLARE()
      end

      false => begin
        SCode.NOT_REDECLARE()
      end
    end
  end
  return outRedeclare
end

function replaceableBool(inReplaceable::SCode.Replaceable)::Bool
  local bReplaceable::Bool

  @assign bReplaceable = begin
    @match inReplaceable begin
      SCode.REPLACEABLE(__) => begin
        true
      end

      SCode.NOT_REPLACEABLE(__) => begin
        false
      end
    end
  end
  return bReplaceable
end

function replaceableOptConstraint(
  inReplaceable::SCode.Replaceable,
)::Option{SCode.ConstrainClass}
  local outOptConstrainClass::Option{SCode.ConstrainClass}

  @assign outOptConstrainClass = begin
    local cc::Option{SCode.ConstrainClass}
    @match inReplaceable begin
      SCode.REPLACEABLE(cc) => begin
        cc
      end

      SCode.NOT_REPLACEABLE(__) => begin
        NONE()
      end
    end
  end
  return outOptConstrainClass
end

function boolReplaceable(
  inBoolReplaceable::Bool,
  inOptConstrainClass::Option{<:SCode.ConstrainClass},
)::SCode.Replaceable
  local outReplaceable::SCode.Replaceable

  @assign outReplaceable = begin
    @match (inBoolReplaceable, inOptConstrainClass) begin
      (true, _) => begin
        SCode.REPLACEABLE(inOptConstrainClass)
      end

      (false, SOME(_)) => begin
        print("Ignoring constraint class because replaceable prefix is not present!\\n")
        SCode.NOT_REPLACEABLE()
      end

      (false, _) => begin
        SCode.NOT_REPLACEABLE()
      end
    end
  end
  return outReplaceable
end

function encapsulatedBool(inEncapsulated::SCode.Encapsulated)::Bool
  local bEncapsulated::Bool

  @assign bEncapsulated = begin
    @match inEncapsulated begin
      SCode.ENCAPSULATED(__) => begin
        true
      end

      SCode.NOT_ENCAPSULATED(__) => begin
        false
      end
    end
  end
  return bEncapsulated
end

function boolEncapsulated(inBoolEncapsulated::Bool)::SCode.Encapsulated
  local outEncapsulated::SCode.Encapsulated

  @assign outEncapsulated = begin
    @match inBoolEncapsulated begin
      true => begin
        SCode.ENCAPSULATED()
      end

      false => begin
        SCode.NOT_ENCAPSULATED()
      end
    end
  end
  return outEncapsulated
end

function partialBool(inPartial::SCode.Partial)::Bool
  local bPartial::Bool

  @assign bPartial = begin
    @match inPartial begin
      SCode.PARTIAL(__) => begin
        true
      end

      SCode.NOT_PARTIAL(__) => begin
        false
      end
    end
  end
  return bPartial
end

function boolPartial(inBoolPartial::Bool)::SCode.Partial
  local outPartial::SCode.Partial

  @assign outPartial = begin
    @match inBoolPartial begin
      true => begin
        SCode.PARTIAL()
      end

      false => begin
        SCode.NOT_PARTIAL()
      end
    end
  end
  return outPartial
end

function prefixesFinal(inPrefixes::SCode.Prefixes)::SCode.Final
  local outFinal::SCode.Final

  @match SCode.PREFIXES(finalPrefix = outFinal) = inPrefixes
  return outFinal
end

function finalBool(inFinal::SCode.Final)::Bool
  local bFinal::Bool

  @assign bFinal = begin
    @match inFinal begin
      SCode.FINAL(__) => begin
        true
      end

      SCode.NOT_FINAL(__) => begin
        false
      end
    end
  end
  return bFinal
end

function finalEqual(inFinal1::SCode.Final, inFinal2::SCode.Final)::Bool
  local bFinal::Bool

  @assign bFinal = begin
    @match (inFinal1, inFinal2) begin
      (SCode.FINAL(__), SCode.FINAL(__)) => begin
        true
      end

      (SCode.NOT_FINAL(__), SCode.NOT_FINAL(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return bFinal
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

function connectorTypeEqual(
  inConnectorType1::SCode.ConnectorType,
  inConnectorType2::SCode.ConnectorType,
)::Bool
  local outEqual::Bool

  @assign outEqual = begin
    @match (inConnectorType1, inConnectorType2) begin
      (SCode.POTENTIAL(__), SCode.POTENTIAL(__)) => begin
        true
      end

      (SCode.FLOW(__), SCode.FLOW(__)) => begin
        true
      end

      (SCode.STREAM(__), SCode.STREAM(__)) => begin
        true
      end
    end
  end
  return outEqual
end

function potentialBool(inConnectorType::SCode.ConnectorType)::Bool
  local outPotential::Bool

  @assign outPotential = begin
    @match inConnectorType begin
      SCode.POTENTIAL(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outPotential
end

function flowBool(inConnectorType::SCode.ConnectorType)::Bool
  local outFlow::Bool

  @assign outFlow = begin
    @match inConnectorType begin
      SCode.FLOW(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outFlow
end

function boolFlow(inBoolFlow::Bool)::SCode.ConnectorType
  local outFlow::SCode.ConnectorType

  @assign outFlow = begin
    @match inBoolFlow begin
      true => begin
        SCode.FLOW()
      end

      _ => begin
        SCode.POTENTIAL()
      end
    end
  end
  return outFlow
end

function streamBool(inStream::SCode.ConnectorType)::Bool
  local bStream::Bool

  @assign bStream = begin
    @match inStream begin
      SCode.STREAM(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return bStream
end

function boolStream(inBoolStream::Bool)::SCode.ConnectorType
  local outStream::SCode.ConnectorType

  @assign outStream = begin
    @match inBoolStream begin
      true => begin
        SCode.STREAM()
      end

      _ => begin
        SCode.POTENTIAL()
      end
    end
  end
  return outStream
end

function mergeAttributesFromClass(
  inAttributes::SCode.Attributes,
  inClass::SCode.Element,
)::SCode.Attributes
  local outAttributes::SCode.Attributes

  @assign outAttributes = begin
    local cls_attr::SCode.Attributes
    local attr::SCode.Attributes
    @match (inAttributes, inClass) begin
      (_, SCode.CLASS(classDef = SCode.DERIVED(attributes = cls_attr))) => begin
        @match SOME(attr) = mergeAttributes(inAttributes, SOME(cls_attr))
        attr
      end

      _ => begin
        inAttributes
      end
    end
  end
  return outAttributes
end

"""
  @author: adrpo
  Function that is used with Derived classes,
  merge the derived Attributes with the optional Attributes returned from ~instClass~.
"""
function mergeAttributes(
  ele::SCode.Attributes,
  oEle::Option{<:SCode.Attributes},
)::Option{SCode.Attributes}
  local outoEle::Option{SCode.Attributes}

  @assign outoEle = begin
    local p1::SCode.Parallelism
    local p2::SCode.Parallelism
    local p::SCode.Parallelism
    local v1::SCode.Variability
    local v2::SCode.Variability
    local v::SCode.Variability
    local d1::Absyn.Direction
    local d2::Absyn.Direction
    local d::Absyn.Direction
    local isf1::Absyn.IsField
    local isf2::Absyn.IsField
    local isf::Absyn.IsField
    local ad1::Absyn.ArrayDim
    local ad2::Absyn.ArrayDim
    local ad::Absyn.ArrayDim
    local ct1::SCode.ConnectorType
    local ct2::SCode.ConnectorType
    local ct::SCode.ConnectorType
    @match (ele, oEle) begin
      (_, NONE()) => begin
        SOME(ele)
      end

      (
        SCode.ATTR(ad1, ct1, p1, v1, d1, isf1),
        SOME(SCode.ATTR(_, ct2, p2, v2, d2, isf2)),
      ) => begin
        @assign ct = propagateConnectorType(ct1, ct2)
        @assign p = propagateParallelism(p1, p2)
        @assign v = propagateVariability(v1, v2)
        @assign d = propagateDirection(d1, d2)
        @assign isf = propagateIsField(isf1, isf2)
        @assign ad = ad1
        SOME(SCode.ATTR(ad, ct, p, v, d, isf))
      end
    end
  end
  #=  TODO! CHECK if ad1 == ad2!
  =#
  return outoEle
end

function prefixesVisibility(inPrefixes::SCode.Prefixes)::SCode.Visibility
  local outVisibility::SCode.Visibility

  @match SCode.PREFIXES(visibility = outVisibility) = inPrefixes
  return outVisibility
end

function prefixesSetVisibility(
  inPrefixes::SCode.Prefixes,
  inVisibility::SCode.Visibility,
)::SCode.Prefixes
  local outPrefixes::SCode.Prefixes

  local rd::SCode.Redeclare
  local f::SCode.Final
  local io::Absyn.InnerOuter
  local rp::SCode.Replaceable

  @match SCode.PREFIXES(_, rd, f, io, rp) = inPrefixes
  @assign outPrefixes = SCode.PREFIXES(inVisibility, rd, f, io, rp)
  return outPrefixes
end

"""Returns true if two each attributes are equal"""
function eachEqual(each1::SCode.Each, each2::SCode.Each)::Bool
  local equal::Bool

  @assign equal = begin
    @match (each1, each2) begin
      (SCode.NOT_EACH(__), SCode.NOT_EACH(__)) => begin
        true
      end

      (SCode.EACH(__), SCode.EACH(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two replaceable attributes are equal"""
function replaceableEqual(r1::SCode.Replaceable, r2::SCode.Replaceable)::Bool
  local equal::Bool

  @assign equal = begin
    local p1::Absyn.Path
    local p2::Absyn.Path
    local m1::SCode.Mod
    local m2::SCode.Mod
    @matchcontinue (r1, r2) begin
      (SCode.NOT_REPLACEABLE(__), SCode.NOT_REPLACEABLE(__)) => begin
        true
      end

      (
        SCode.REPLACEABLE(SOME(SCode.CONSTRAINCLASS(
          constrainingClass = p1,
          modifier = m1,
        ))),
        SCode.REPLACEABLE(SOME(SCode.CONSTRAINCLASS(
          constrainingClass = p2,
          modifier = m2,
        ))),
      ) => begin
        @match true = AbsynUtil.pathEqual(p1, p2)
        @match true = modEqual(m1, m2)
        true
      end

      (SCode.REPLACEABLE(NONE()), SCode.REPLACEABLE(NONE())) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns true if two prefixes are equal"""
function prefixesEqual(prefixes1::SCode.Prefixes, prefixes2::SCode.Prefixes)::Bool
  local equal::Bool

  @assign equal = begin
    local v1::SCode.Visibility
    local v2::SCode.Visibility
    local rd1::SCode.Redeclare
    local rd2::SCode.Redeclare
    local f1::SCode.Final
    local f2::SCode.Final
    local io1::Absyn.InnerOuter
    local io2::Absyn.InnerOuter
    local rpl1::SCode.Replaceable
    local rpl2::SCode.Replaceable
    @matchcontinue (prefixes1, prefixes2) begin
      (SCode.PREFIXES(v1, rd1, f1, io1, rpl1), SCode.PREFIXES(v2, rd2, f2, io2, rpl2)) =>
        begin
          @match true = valueEq(v1, v2)
          @match true = valueEq(rd1, rd2)
          @match true = valueEq(f1, f2)
          @match true = AbsynUtil.innerOuterEqual(io1, io2)
          @match true = replaceableEqual(rpl1, rpl2)
          true
        end

      _ => begin
        false
      end
    end
  end
  return equal
end

"""Returns the replaceable part"""
function prefixesReplaceable(prefixes::SCode.Prefixes)::SCode.Replaceable
  local repl::SCode.Replaceable

  @match SCode.PREFIXES(replaceablePrefix = repl) = prefixes
  return repl
end

function elementPrefixes(inElement::SCode.Element)::SCode.Prefixes
  local outPrefixes::SCode.Prefixes

  @assign outPrefixes = begin
    local pf::SCode.Prefixes
    @match inElement begin
      SCode.CLASS(prefixes = pf) => begin
        pf
      end

      SCode.COMPONENT(prefixes = pf) => begin
        pf
      end
    end
  end
  return outPrefixes
end

function isElementReplaceable(inElement::SCode.Element)::Bool
  local isReplaceable::Bool

  local pf::SCode.Prefixes

  @assign pf = elementPrefixes(inElement)
  @assign isReplaceable = replaceableBool(prefixesReplaceable(pf))
  return isReplaceable
end

function isElementRedeclare(inElement::SCode.Element)::Bool
  local isRedeclare::Bool

  local pf::SCode.Prefixes

  @assign pf = elementPrefixes(inElement)
  @assign isRedeclare = redeclareBool(prefixesRedeclare(pf))
  return isRedeclare
end

function prefixesInnerOuter(inPrefixes::SCode.Prefixes)::Absyn.InnerOuter
  local outInnerOuter::Absyn.InnerOuter

  @match SCode.PREFIXES(innerOuter = outInnerOuter) = inPrefixes
  return outInnerOuter
end

function prefixesSetInnerOuter(
  prefixes::SCode.Prefixes,
  innerOuter::Absyn.InnerOuter,
)::SCode.Prefixes

  @assign prefixes.innerOuter = innerOuter
  return prefixes
end

function removeAttributeDimensions(inAttributes::SCode.Attributes)::SCode.Attributes
  local outAttributes::SCode.Attributes

  local ct::SCode.ConnectorType
  local v::SCode.Variability
  local p::SCode.Parallelism
  local d::Absyn.Direction
  local isf::Absyn.IsField

  @match SCode.ATTR(_, ct, p, v, d, isf) = inAttributes
  @assign outAttributes = SCode.ATTR(nil, ct, p, v, d, isf)
  return outAttributes
end

function setAttributesDirection(
  attributes::SCode.Attributes,
  direction::Absyn.Direction,
)::SCode.Attributes

  @assign attributes.direction = direction
  return attributes
end

"""Return the variability attribute from Attributes"""
function attrVariability(attr::SCode.Attributes)::SCode.Variability
  local var::SCode.Variability

  @assign var = begin
    local v::SCode.Variability
    @match attr begin
      SCode.ATTR(variability = v) => begin
        v
      end
    end
  end
  return var
end

function setAttributesVariability(
  attributes::SCode.Attributes,
  variability::SCode.Variability,
)::SCode.Attributes

  @assign attributes.variability = variability
  return attributes
end

function isDerivedClassDef(inClassDef::SCode.ClassDef)::Bool
  local isDerived::Bool

  @assign isDerived = begin
    @match inClassDef begin
      SCode.DERIVED(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isDerived
end

function isConnector(inRestriction::SCode.Restriction)::Bool
  local isConnector::Bool

  @assign isConnector = begin
    @match inRestriction begin
      SCode.R_CONNECTOR(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isConnector
end

function removeBuiltinsFromTopScope(inProgram::SCode.Program)::SCode.Program
  local outProgram::SCode.Program

  @assign outProgram = ListUtil.filterOnTrue(inProgram, isNotBuiltinClass)
  return outProgram
end

function isNotBuiltinClass(inClass::SCode.Element)::Bool
  local b::Bool

  @assign b = begin
    @match inClass begin
      SCode.CLASS(
        classDef = SCode.PARTS(
          externalDecl = SOME(SCode.EXTERNALDECL(lang = SOME("builtin"))),
        ),
      ) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return b
end

"""
 Returns the annotation with the given name in the element, or fails if no
 such annotation could be found.
"""
function getElementNamedAnnotation(element::SCode.Element, name::String)::Absyn.Exp
  local exp::Absyn.Exp
  local ann::SCode.Annotation
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
  inAnnotation::SCode.Annotation,
  inName::String,
)::Tuple{Absyn.Exp, SourceInfo}
  local info::SourceInfo
  local exp::Absyn.Exp

  local submods::List{SCode.SubMod}

  @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = inAnnotation
  @match SCode.NAMEMOD(mod = SCode.MOD(info = info, binding = SOME(exp))) =
    ListUtil.find1(submods, hasNamedAnnotation, inName)
  return (exp, info)
end

"""
  Checks if a submod has the same name as the given name, and if its binding
  in that case is true.
"""
function hasNamedAnnotation(inSubMod::SCode.SubMod, inName::String)::Bool
  local outIsMatch::Bool

  @assign outIsMatch = begin
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
  return outIsMatch
end

"""
  Returns the modifier with the given name if it can be found in the
  annotation, otherwise an empty modifier.
"""
function lookupNamedAnnotation(ann::SCode.Annotation, name::String)::SCode.Mod
  local mod::SCode.Mod

  local submods::List{SCode.SubMod}
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
function lookupNamedAnnotations(ann::SCode.Annotation, name::String)::List{SCode.Mod}
  local mods::List{SCode.Mod} = nil

  local submods::List{SCode.SubMod}
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
  local hasAnn::Bool

  @assign hasAnn = begin
    local ann::SCode.Annotation
    @match (inClass, namedAnnotation) begin
      (SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))), _) => begin
        hasBooleanNamedAnnotation(ann, namedAnnotation)
      end

      _ => begin
        false
      end
    end
  end
  return hasAnn
end

function hasBooleanNamedAnnotationInComponent(
  inComponent::SCode.Element,
  namedAnnotation::String,
)::Bool
  local hasAnn::Bool

  @assign hasAnn = begin
    local ann::SCode.Annotation
    @match (inComponent, namedAnnotation) begin
      (SCode.COMPONENT(comment = SCode.COMMENT(annotation_ = SOME(ann))), _) => begin
        hasBooleanNamedAnnotation(ann, namedAnnotation)
      end

      _ => begin
        false
      end
    end
  end
  return hasAnn
end

"""check if the named annotation is present and has value true"""
function optCommentHasBooleanNamedAnnotation(
  comm::Option{<:SCode.Comment},
  annotationName::String,
)::Bool
  local outB::Bool

  @assign outB = begin
    local ann::SCode.Annotation
    @match (comm, annotationName) begin
      (SOME(SCode.COMMENT(annotation_ = SOME(ann))), _) => begin
        hasBooleanNamedAnnotation(ann, annotationName)
      end

      _ => begin
        false
      end
    end
  end
  return outB
end

"""check if the named annotation is present and has value true"""
function commentHasBooleanNamedAnnotation(comm::SCode.Comment, annotationName::String)::Bool
  local outB::Bool

  @assign outB = begin
    local ann::SCode.Annotation
    @match (comm, annotationName) begin
      (SCode.COMMENT(annotation_ = SOME(ann)), _) => begin
        hasBooleanNamedAnnotation(ann, annotationName)
      end

      _ => begin
        false
      end
    end
  end
  return outB
end

"""
  Checks if the given annotation contains an entry with the given name with the
  value true.
"""
function hasBooleanNamedAnnotation(inAnnotation::SCode.Annotation, inName::String)::Bool
  local outHasEntry::Bool

  local submods::List{SCode.SubMod}

  @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = inAnnotation
  @assign outHasEntry = ListUtil.exist1(submods, hasBooleanNamedAnnotation2, inName)
  return outHasEntry
end

"""
  Checks if a submod has the same name as the given name, and if its binding
  in that case is true.
"""
function hasBooleanNamedAnnotation2(inSubMod::SCode.SubMod, inName::String)::Bool
  local outIsMatch::Bool

  @assign outIsMatch = begin
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
  return outIsMatch
end

"""
  @author: adrpo
  returns true if annotation(Evaluate = true) is present,
  otherwise false
"""
function getEvaluateAnnotation(inCommentOpt::Option{<:SCode.Comment})::Bool
  local evalIsTrue::Bool

  @assign evalIsTrue = begin
    local ann::SCode.Annotation
    @match inCommentOpt begin
      SOME(SCode.COMMENT(annotation_ = SOME(ann))) => begin
        hasBooleanNamedAnnotation(ann, "Evaluate")
      end

      _ => begin
        false
      end
    end
  end
  return evalIsTrue
end

function getInlineTypeAnnotationFromCmt(inComment::SCode.Comment)::Option{SCode.Annotation}
  local outAnnotation::Option{SCode.Annotation}

  @assign outAnnotation = begin
    local ann::SCode.Annotation
    @match inComment begin
      SCode.COMMENT(annotation_ = SOME(ann)) => begin
        getInlineTypeAnnotation(ann)
      end

      _ => begin
        NONE()
      end
    end
  end
  return outAnnotation
end

function getInlineTypeAnnotation(inAnnotation::SCode.Annotation)::Option{SCode.Annotation}
  local outAnnotation::Option{SCode.Annotation}

  @assign outAnnotation = begin
    local submods::List{SCode.SubMod}
    local inline_mod::SCode.SubMod
    local fp::SCode.Final
    local ep::SCode.Each
    local info::SourceInfo
    @matchcontinue inAnnotation begin
      SCode.ANNOTATION(SCode.MOD(fp, ep, submods, _, info)) => begin
        @assign inline_mod = ListUtil.find(submods, isInlineTypeSubMod)
        SOME(SCode.ANNOTATION(SCode.MOD(fp, ep, list(inline_mod), NONE(), info)))
      end

      _ => begin
        NONE()
      end
    end
  end
  return outAnnotation
end

function isInlineTypeSubMod(inSubMod::SCode.SubMod)::Bool
  local outIsInlineType::Bool

  @assign outIsInlineType = begin
    @match inSubMod begin
      SCode.NAMEMOD(ident = "Inline") => begin
        true
      end

      SCode.NAMEMOD(ident = "LateInline") => begin
        true
      end

      SCode.NAMEMOD(ident = "InlineAfterIndexReduction") => begin
        true
      end
    end
  end
  return outIsInlineType
end

function appendAnnotationToComment(
  inAnnotation::SCode.Annotation,
  inComment::SCode.Comment,
)::SCode.Comment
  local outComment::SCode.Comment

  @assign outComment = begin
    local cmt::Option{String}
    local fp::SCode.Final
    local ep::SCode.Each
    local mods1::List{SCode.SubMod}
    local mods2::List{SCode.SubMod}
    local b::Option{Absyn.Exp}
    local info::SourceInfo
    @match (inAnnotation, inComment) begin
      (_, SCode.COMMENT(NONE(), cmt)) => begin
        SCode.COMMENT(SOME(inAnnotation), cmt)
      end

      (
        SCode.ANNOTATION(modification = SCode.MOD(subModLst = mods1)),
        SCode.COMMENT(SOME(SCode.ANNOTATION(SCode.MOD(fp, ep, mods2, b, info))), cmt),
      ) => begin
        @assign mods2 = listAppend(mods1, mods2)
        SCode.COMMENT(SOME(SCode.ANNOTATION(SCode.MOD(fp, ep, mods2, b, info))), cmt)
      end
    end
  end
  return outComment
end

function getModifierInfo(inMod::SCode.Mod)::SourceInfo
  local outInfo::SourceInfo

  @assign outInfo = begin
    local info::SourceInfo
    local el::SCode.Element
    @match inMod begin
      SCode.MOD(info = info) => begin
        info
      end

      SCode.REDECL(element = el) => begin
        elementInfo(el)
      end

      _ => begin
        AbsynUtil.dummyInfo
      end
    end
  end
  return outInfo
end

function getModifierBinding(inMod::SCode.Mod)::Option{Absyn.Exp}
  local outBinding::Option{Absyn.Exp}

  @assign outBinding = begin
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
  return outBinding
end

function getComponentCondition(element::SCode.Element)::Option{Absyn.Exp}
  local condition::Option{Absyn.Exp}

  @assign condition = begin
    @match element begin
      SCode.COMPONENT(__) => begin
        element.condition
      end

      _ => begin
        NONE()
      end
    end
  end
  return condition
end

function removeComponentCondition(inElement::SCode.Element)::SCode.Element
  local outElement::SCode.Element

  local name::SCode.Ident
  local pf::SCode.Prefixes
  local attr::SCode.Attributes
  local ty::Absyn.TypeSpec
  local mod::SCode.Mod
  local cmt::SCode.Comment
  local info::SourceInfo

  @match SCode.COMPONENT(name, pf, attr, ty, mod, cmt, _, info) = inElement
  @assign outElement = SCode.COMPONENT(name, pf, attr, ty, mod, cmt, NONE(), info)
  return outElement
end

"""
  Returns true if the given element is an element with the inner prefix,
  otherwise false.
"""
function isInnerComponent(inElement::SCode.Element)::Bool
  local outIsInner::Bool

  @assign outIsInner = begin
    local io::Absyn.InnerOuter
    @match inElement begin
      SCode.COMPONENT(prefixes = SCode.PREFIXES(innerOuter = io)) => begin
        AbsynUtil.isInner(io)
      end

      _ => begin
        false
      end
    end
  end
  return outIsInner
end

function makeElementProtected(inElement::SCode.Element)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local name::SCode.Ident
    local attr::SCode.Attributes
    local ty::Absyn.TypeSpec
    local mod::SCode.Mod
    local cmt::SCode.Comment
    local cnd::Option{Absyn.Exp}
    local info::SourceInfo
    local rdp::SCode.Redeclare
    local fp::SCode.Final
    local io::Absyn.InnerOuter
    local rpp::SCode.Replaceable
    local bc::SCode.Path
    local ann::Option{SCode.Annotation}
    @match inElement begin
      SCode.COMPONENT(prefixes = SCode.PREFIXES(visibility = SCode.PROTECTED(__))) =>
        begin
          inElement
        end

      SCode.COMPONENT(
        name,
        SCode.PREFIXES(_, rdp, fp, io, rpp),
        attr,
        ty,
        mod,
        cmt,
        cnd,
        info,
      ) => begin
        SCode.COMPONENT(
          name,
          SCode.PREFIXES(SCode.PROTECTED(), rdp, fp, io, rpp),
          attr,
          ty,
          mod,
          cmt,
          cnd,
          info,
        )
      end

      SCode.EXTENDS(visibility = SCode.PROTECTED(__)) => begin
        inElement
      end

      SCode.EXTENDS(bc, _, mod, ann, info) => begin
        SCode.EXTENDS(bc, SCode.PROTECTED(), mod, ann, info)
      end

      _ => begin
        inElement
      end
    end
  end
  return outElement
end

function isElementPublic(inElement::SCode.Element)::Bool
  local outIsPublic::Bool

  @assign outIsPublic = visibilityBool(prefixesVisibility(elementPrefixes(inElement)))
  return outIsPublic
end

function isElementProtected(inElement::SCode.Element)::Bool
  local outIsProtected::Bool

  @assign outIsProtected = !visibilityBool(prefixesVisibility(elementPrefixes(inElement)))
  return outIsProtected
end

function isElementEncapsulated(inElement::SCode.Element)::Bool
  local outIsEncapsulated::Bool

  @assign outIsEncapsulated = begin
    @match inElement begin
      SCode.CLASS(encapsulatedPrefix = SCode.ENCAPSULATED(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsEncapsulated
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
  local outProgram::SCode.Program
  outProgram = begin
    local sp::SCode.Program
    local c::SCode.Element
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
  return outProgram
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
    local c::SCode.Element
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
  #=  not found, add it
  =#
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
    local i::Absyn.Ident
    #=  a class with parts
    =#
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
  #=  a class extends
  =#
  #=  a derived class
  =#
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
    local els::SCode.Program
    local e::SCode.Element
    local p::Absyn.Path
    local i::Absyn.Ident
    local name::SCode.Ident #= the name of the class =#
    local prefixes::SCode.Prefixes #= the common class or component prefixes =#
    local encapsulatedPrefix::SCode.Encapsulated #= the encapsulated prefix =#
    local partialPrefix::SCode.Partial #= the partial prefix =#
    local restriction::SCode.Restriction #= the restriction of the class =#
    local classDef::SCode.ClassDef #= the class specification =#
    local info::SourceInfo #= the class information =#
    local cmt::SCode.Comment
    #=  a class with parts, non derived
    =#
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
  #=  a class derived
  =#
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
    #=  a derived class
    =#
    @match classDef begin
      SCode.DERIVED(typeSpec = Absyn.TPATH(path = p)) => begin
        @assign e = getElementWithPath(inProgram, p)
        @assign e = replaceElementsInElement(inProgram, e, inElements)
        SOME(e)
      end

      SCode.PARTS(__) => begin
        #=  a parts
        =#
        @assign classDef.elementLst = inElements
        NONE()
      end

      SCode.CLASS_EXTENDS(composition = composition) => begin
        #=  a class extends
        =#
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
  local outElement::SCode.Element

  @assign outElement = begin
    local sp::SCode.Program
    local rest::SCode.Program
    local c::SCode.Element
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
  return outElement
end

"""
  returns the element from the program having the name as the id.
  if the element does not exist it fails
"""
function getElementWithPath(inProgram::SCode.Program, inPath::Absyn.Path)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local sp::SCode.Program
    local rest::SCode.Program
    local c::SCode.Element
    local e::SCode.Element
    local p::Absyn.Path
    local i::Absyn.Ident
    local n::Absyn.Ident
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
  return outElement
end

"""
Retrieves the name of a SCode element.
Returns the name as a string.
"""
function getElementName(e::SCode.Element)::String
  local s::String

  @assign s = begin
    local p::Absyn.Path
    @match e begin
      SCode.COMPONENT(name = s) => begin
        s
      end

      SCode.CLASS(name = s) => begin
        s
      end

      SCode.EXTENDS(baseClassPath = p) => begin
        AbsynUtil.pathString(p)
      end
    end
  end
  return s
end

"""
  @auhtor: adrpo
  set the base class path in extends
"""
function setBaseClassPath(inE::SCode.Element, inBcPath::Absyn.Path)::SCode.Element
  local outE::SCode.Element

  local bc::SCode.Path
  local v::SCode.Visibility
  local m::SCode.Mod
  local a::Option{SCode.Annotation}
  local i::SourceInfo

  @match SCode.EXTENDS(bc, v, m, a, i) = inE
  @assign outE = SCode.EXTENDS(inBcPath, v, m, a, i)
  return outE
end

"""
  @auhtor: adrpo
  return the base class path in extends
"""
function getBaseClassPath(inE::SCode.Element)::Absyn.Path
  local outBcPath::Absyn.Path

  local bc::SCode.Path
  local v::SCode.Visibility
  local m::SCode.Mod
  local a::Option{SCode.Annotation}
  local i::SourceInfo

  @match SCode.EXTENDS(baseClassPath = outBcPath) = inE
  return outBcPath
end

"""
  @auhtor: adrpo
  set the typespec path in component
"""
function setComponentTypeSpec(inE::SCode.Element, inTypeSpec::Absyn.TypeSpec)::SCode.Element
  local outE::SCode.Element

  local n::SCode.Ident
  local pr::SCode.Prefixes
  local atr::SCode.Attributes
  local ts::Absyn.TypeSpec
  local cmt::SCode.Comment
  local cnd::Option{Absyn.Exp}
  local bc::SCode.Path
  local v::SCode.Visibility
  local m::SCode.Mod
  local a::Option{SCode.Annotation}
  local i::SourceInfo

  @match SCode.COMPONENT(n, pr, atr, ts, m, cmt, cnd, i) = inE
  @assign outE = SCode.COMPONENT(n, pr, atr, inTypeSpec, m, cmt, cnd, i)
  return outE
end

"""
  @auhtor: adrpo
  get the typespec path in component
"""
function getComponentTypeSpec(inE::SCode.Element)::Absyn.TypeSpec
  local outTypeSpec::Absyn.TypeSpec

  @match SCode.COMPONENT(typeSpec = outTypeSpec) = inE
  return outTypeSpec
end

"""
  @auhtor: adrpo
  set the modification in component
"""
function setComponentMod(inE::SCode.Element, inMod::SCode.Mod)::SCode.Element
  local outE::SCode.Element

  local n::SCode.Ident
  local pr::SCode.Prefixes
  local atr::SCode.Attributes
  local ts::Absyn.TypeSpec
  local cmt::SCode.Comment
  local cnd::Option{Absyn.Exp}
  local bc::SCode.Path
  local v::SCode.Visibility
  local m::SCode.Mod
  local a::Option{SCode.Annotation}
  local i::SourceInfo

  @match SCode.COMPONENT(n, pr, atr, ts, m, cmt, cnd, i) = inE
  @assign outE = SCode.COMPONENT(n, pr, atr, ts, inMod, cmt, cnd, i)
  return outE
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

function isDerivedClass(inClass::SCode.Element)::Bool
  local isDerived::Bool

  @assign isDerived = begin
    @match inClass begin
      SCode.CLASS(classDef = SCode.DERIVED(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isDerived
end

function isClassExtends(cls::SCode.Element)::Bool
  local isCE::Bool

  @assign isCE = begin
    @match cls begin
      SCode.CLASS(classDef = SCode.CLASS_EXTENDS(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isCE
end

"""
  @auhtor: adrpo
  set the base class path in extends
"""
function setDerivedTypeSpec(inE::SCode.Element, inTypeSpec::Absyn.TypeSpec)::SCode.Element
  local outE::SCode.Element

  local n::SCode.Ident
  local pr::SCode.Prefixes
  local atr::SCode.Attributes
  local ep::SCode.Encapsulated
  local pp::SCode.Partial
  local res::SCode.Restriction
  local cd::SCode.ClassDef
  local i::SourceInfo
  local ts::Absyn.TypeSpec
  local ann::Option{SCode.Annotation}
  local cmt::SCode.Comment
  local m::SCode.Mod

  @match SCode.CLASS(n, pr, ep, pp, res, cd, cmt, i) = inE
  @match SCode.DERIVED(ts, m, atr) = cd
  @assign cd = SCode.DERIVED(inTypeSpec, m, atr)
  @assign outE = SCode.CLASS(n, pr, ep, pp, res, cd, cmt, i)
  return outE
end

"""
  @auhtor: adrpo
  set the base class path in extends
"""
function getDerivedTypeSpec(inE::SCode.Element)::Absyn.TypeSpec
  local outTypeSpec::Absyn.TypeSpec

  @match SCode.CLASS(classDef = SCode.DERIVED(typeSpec = outTypeSpec)) = inE
  return outTypeSpec
end

"""
  @auhtor: adrpo
  set the base class path in extends
"""
function getDerivedMod(inE::SCode.Element)::SCode.Mod
  local outMod::SCode.Mod

  @match SCode.CLASS(classDef = SCode.DERIVED(modifications = outMod)) = inE
  return outMod
end

function setClassPrefixes(inPrefixes::SCode.Prefixes, cl::SCode.Element)::SCode.Element
  local outCl::SCode.Element

  @assign outCl = begin
    local parts::SCode.ClassDef
    local e::SCode.Encapsulated
    local id::SCode.Ident
    local info::SourceInfo
    local restriction::SCode.Restriction
    local prefixes::SCode.Prefixes
    local pp::SCode.Partial
    local cmt::SCode.Comment
    #=  not the same, change
    =#
    @match (inPrefixes, cl) begin
      (_, SCode.CLASS(id, _, e, pp, restriction, parts, cmt, info)) => begin
        SCode.CLASS(id, inPrefixes, e, pp, restriction, parts, cmt, info)
      end
    end
  end
  return outCl
end

function makeEquation(inEEq::SCode.EEquation)::SCode.Equation
  local outEq::SCode.Equation

  @assign outEq = SCode.EQUATION(inEEq)
  return outEq
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

"""
 @author: adrpo
 returns true if equations contains reinit
"""
function equationsContainReinit(inEqs::List{<:SCode.EEquation})::Bool
  local hasReinit::Bool

  @assign hasReinit = begin
    local b::Bool
    @match inEqs begin
      _ => begin
        @assign b = ListUtil.applyAndFold(inEqs, boolOr, equationContainReinit, false)
        b
      end
    end
  end
  return hasReinit
end

"""
@author: johti17
Returns true if the equations contains an Connections.branch call.
"""
function equationsContainConnectorsBranch(inEqs::List{<:SCode.EEquation})::Bool
  local hasReinit::Bool
  @assign hasReinit = begin
    local b::Bool
    @match inEqs begin
      _ => begin
        @assign b = ListUtil.applyAndFold(inEqs, boolOr, equationContainConnectorsBranch, false)
        b
      end
    end
  end
  return hasReinit
end


"""
  Returns true if the equation contains a Connectors.branch statement
"""
function equationContainConnectorsBranch(inEq::SCode.EEquation)::Bool
  local hasBranch::Bool
  @assign hasBranch = begin
    local b::Bool
    local eqs::List{SCode.EEquation}
    local eqs_lst::List{List{SCode.EEquation}}
    local tpl_el::List{Tuple{Absyn.Exp, List{SCode.EEquation}}}
    @match inEq begin
      SCode.EQ_NORETCALL(Absyn.CALL(
        Absyn.CREF_QUAL("Connections", Nil{Any}(),
                        Absyn.CREF_IDENT("branch", Nil{Any}())), _, _), _, _) => true
      SCode.EQ_WHEN(eEquationLst = eqs, elseBranches = tpl_el) => begin
        b = equationsContainConnectorsBranch(eqs)
        eqs_lst = ListUtil.map(tpl_el, Util.tuple22)
        b = ListUtil.applyAndFold(eqs_lst, boolOr, equationsContainConnectorsBranch, b)
        b
      end

      SCode.EQ_IF(thenBranch = eqs_lst, elseBranch = eqs) => begin
        b = equationsContainConnectorsBranch(eqs)
        b = ListUtil.applyAndFold(eqs_lst, boolOr, equationsContainConnectorsBranch, b)
        b
      end

      SCode.EQ_FOR(eEquationLst = eqs) => begin
        b = equationsContainConnectorsBranch(eqs)
        b
      end

      _ => begin
        false
      end
    end
  end
  return hasBranch
end

"""
@author: adrpo
 returns true if equation contains reinit
"""
function equationContainReinit(inEq::SCode.EEquation)::Bool
  local hasReinit::Bool

  @assign hasReinit = begin
    local b::Bool
    local eqs::List{SCode.EEquation}
    local eqs_lst::List{List{SCode.EEquation}}
    local tpl_el::List{Tuple{Absyn.Exp, List{SCode.EEquation}}}
    @match inEq begin
      SCode.EQ_REINIT(__) => begin
        true
      end

      SCode.EQ_WHEN(eEquationLst = eqs, elseBranches = tpl_el) => begin
        @assign b = equationsContainReinit(eqs)
        @assign eqs_lst = ListUtil.map(tpl_el, Util.tuple22)
        @assign b = ListUtil.applyAndFold(eqs_lst, boolOr, equationsContainReinit, b)
        b
      end

      SCode.EQ_IF(thenBranch = eqs_lst, elseBranch = eqs) => begin
        @assign b = equationsContainReinit(eqs)
        @assign b = ListUtil.applyAndFold(eqs_lst, boolOr, equationsContainReinit, b)
        b
      end

      SCode.EQ_FOR(eEquationLst = eqs) => begin
        @assign b = equationsContainReinit(eqs)
        b
      end

      _ => begin
        false
      end
    end
  end
  return hasReinit
end

"""
  @author:
  returns true if statements contains reinit
"""
function algorithmsContainReinit(inAlgs::List{<:SCode.Statement})::Bool
  local hasReinit::Bool

  @assign hasReinit = begin
    local b::Bool
    @match inAlgs begin
      _ => begin
        @assign b = ListUtil.applyAndFold(inAlgs, boolOr, algorithmContainReinit, false)
        b
      end
    end
  end
  return hasReinit
end

"""
  @author:
  returns true if statement contains reinit
"""
function algorithmContainReinit(inAlg::SCode.Statement)::Bool
  local hasReinit::Bool

  @assign hasReinit = begin
    local b::Bool
    local b1::Bool
    local b2::Bool
    local b3::Bool
    local algs::List{SCode.Statement}
    local algs1::List{SCode.Statement}
    local algs2::List{SCode.Statement}
    local algs_lst::List{List{SCode.Statement}}
    local tpl_alg::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
    @match inAlg begin
      SCode.ALG_REINIT(__) => begin
        true
      end

      SCode.ALG_WHEN_A(branches = tpl_alg) => begin
        @assign algs_lst = ListUtil.map(tpl_alg, Util.tuple22)
        @assign b =
          ListUtil.applyAndFold(algs_lst, boolOr, algorithmsContainReinit, false)
        b
      end

      SCode.ALG_IF(trueBranch = algs1, elseIfBranch = tpl_alg, elseBranch = algs2) =>
        begin
          @assign b1 = algorithmsContainReinit(algs1)
          @assign algs_lst = ListUtil.map(tpl_alg, Util.tuple22)
          @assign b2 =
            ListUtil.applyAndFold(algs_lst, boolOr, algorithmsContainReinit, b1)
          @assign b3 = algorithmsContainReinit(algs2)
          @assign b = boolOr(b1, boolOr(b2, b3))
          b
        end

      SCode.ALG_FOR(forBody = algs) => begin
        @assign b = algorithmsContainReinit(algs)
        b
      end

      SCode.ALG_WHILE(whileBody = algs) => begin
        @assign b = algorithmsContainReinit(algs)
        b
      end

      _ => begin
        false
      end
    end
  end
  return hasReinit
end

function getClassPartialPrefix(inElement::SCode.Element)::SCode.Partial
  local outPartial::SCode.Partial

  @match SCode.CLASS(partialPrefix = outPartial) = inElement
  return outPartial
end

function getClassRestriction(inElement::SCode.Element)::SCode.Restriction
  local outRestriction::SCode.Restriction

  @match SCode.CLASS(restriction = outRestriction) = inElement
  return outRestriction
end

function isRedeclareSubMod(inSubMod::SCode.SubMod)::Bool
  local outIsRedeclare::Bool

  @assign outIsRedeclare = begin
    @match inSubMod begin
      SCode.NAMEMOD(mod = SCode.REDECL(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsRedeclare
end

function componentMod(inElement::SCode.Element)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local mod::SCode.Mod
    @match inElement begin
      SCode.COMPONENT(modifications = mod) => begin
        mod
      end

      _ => begin
        SCode.NOMOD()
      end
    end
  end
  return outMod
end

function elementMod(inElement::SCode.Element)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local mod::SCode.Mod
    @match inElement begin
      SCode.COMPONENT(modifications = mod) => begin
        mod
      end

      SCode.CLASS(classDef = SCode.DERIVED(modifications = mod)) => begin
        mod
      end

      SCode.CLASS(classDef = SCode.CLASS_EXTENDS(modifications = mod)) => begin
        mod
      end

      SCode.EXTENDS(modifications = mod) => begin
        mod
      end
    end
  end
  return outMod
end

"""
  Sets the modifier of an element, or fails if the element is not capable of
  having a modifier.
"""
function setElementMod(inElement::SCode.Element, inMod::SCode.Mod)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local n::SCode.Ident
    local pf::SCode.Prefixes
    local attr::SCode.Attributes
    local ty::Absyn.TypeSpec
    local cmt::SCode.Comment
    local cnd::Option{Absyn.Exp}
    local i::SourceInfo
    local ep::SCode.Encapsulated
    local pp::SCode.Partial
    local res::SCode.Restriction
    local cdef::SCode.ClassDef
    local bc::Absyn.Path
    local vis::SCode.Visibility
    local ann::Option{SCode.Annotation}
    @match (inElement, inMod) begin
      (SCode.COMPONENT(n, pf, attr, ty, _, cmt, cnd, i), _) => begin
        SCode.COMPONENT(n, pf, attr, ty, inMod, cmt, cnd, i)
      end

      (SCode.CLASS(n, pf, ep, pp, res, cdef, cmt, i), _) => begin
        @assign cdef = setClassDefMod(cdef, inMod)
        SCode.CLASS(n, pf, ep, pp, res, cdef, cmt, i)
      end

      (SCode.EXTENDS(bc, vis, _, ann, i), _) => begin
        SCode.EXTENDS(bc, vis, inMod, ann, i)
      end
    end
  end
  return outElement
end

function setClassDefMod(inClassDef::SCode.ClassDef, inMod::SCode.Mod)::SCode.ClassDef
  local outClassDef::SCode.ClassDef

  @assign outClassDef = begin
    local bc::SCode.Ident
    local cdef::SCode.ClassDef
    local ty::Absyn.TypeSpec
    local attr::SCode.Attributes
    @match (inClassDef, inMod) begin
      (SCode.DERIVED(ty, _, attr), _) => begin
        SCode.DERIVED(ty, inMod, attr)
      end

      (SCode.CLASS_EXTENDS(_, cdef), _) => begin
        SCode.CLASS_EXTENDS(inMod, cdef)
      end

      _ => begin
        inClassDef
      end
    end
  end
  return outClassDef
end

function isBuiltinElement(inElement::SCode.Element)::Bool
  local outIsBuiltin::Bool

  @assign outIsBuiltin = begin
    local ann::SCode.Annotation
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
  return outIsBuiltin
end

function partitionElements(
  inElements::List{<:SCode.Element},
)::Tuple{
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
}
  local outDefineUnits::List{SCode.Element}
  local outImports::List{SCode.Element}
  local outExtends::List{SCode.Element}
  local outClasses::List{SCode.Element}
  local outComponents::List{SCode.Element}

  @assign (outComponents, outClasses, outExtends, outImports, outDefineUnits) =
    partitionElements2(inElements, nil, nil, nil, nil, nil)
  return (outComponents, outClasses, outExtends, outImports, outDefineUnits)
end

function partitionElements2(
  inElements::List{<:SCode.Element},
  inComponents::List{<:SCode.Element},
  inClasses::List{<:SCode.Element},
  inExtends::List{<:SCode.Element},
  inImports::List{<:SCode.Element},
  inDefineUnits::List{<:SCode.Element},
)::Tuple{
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
  List{SCode.Element},
}
  local outDefineUnits::List{SCode.Element}
  local outImports::List{SCode.Element}
  local outExtends::List{SCode.Element}
  local outClasses::List{SCode.Element}
  local outComponents::List{SCode.Element}

  @assign (outComponents, outClasses, outExtends, outImports, outDefineUnits) = begin
    local el::SCode.Element
    local rest_el::List{SCode.Element}
    local comp::List{SCode.Element}
    local cls::List{SCode.Element}
    local ext::List{SCode.Element}
    local imp::List{SCode.Element}
    local def::List{SCode.Element}
    @match (inElements, inComponents, inClasses, inExtends, inImports, inDefineUnits) begin
      (el && SCode.COMPONENT(__) <| rest_el, comp, cls, ext, imp, def) => begin
        @assign (comp, cls, ext, imp, def) =
          partitionElements2(rest_el, _cons(el, comp), cls, ext, imp, def)
        (comp, cls, ext, imp, def)
      end

      (el && SCode.CLASS(__) <| rest_el, comp, cls, ext, imp, def) => begin
        @assign (comp, cls, ext, imp, def) =
          partitionElements2(rest_el, comp, _cons(el, cls), ext, imp, def)
        (comp, cls, ext, imp, def)
      end

      (el && SCode.EXTENDS(__) <| rest_el, comp, cls, ext, imp, def) => begin
        @assign (comp, cls, ext, imp, def) =
          partitionElements2(rest_el, comp, cls, _cons(el, ext), imp, def)
        (comp, cls, ext, imp, def)
      end

      (el && SCode.IMPORT(__) <| rest_el, comp, cls, ext, imp, def) => begin
        @assign (comp, cls, ext, imp, def) =
          partitionElements2(rest_el, comp, cls, ext, _cons(el, imp), def)
        (comp, cls, ext, imp, def)
      end

      (el && SCode.DEFINEUNIT(__) <| rest_el, comp, cls, ext, imp, def) => begin
        @assign (comp, cls, ext, imp, def) =
          partitionElements2(rest_el, comp, cls, ext, imp, _cons(el, def))
        (comp, cls, ext, imp, def)
      end

      (nil(), comp, cls, ext, imp, def) => begin
        (
          listReverse(comp),
          listReverse(cls),
          listReverse(ext),
          listReverse(imp),
          listReverse(def),
        )
      end
    end
  end
  return (outComponents, outClasses, outExtends, outImports, outDefineUnits)
end

function isExternalFunctionRestriction(inRestr::SCode.FunctionRestriction)::Bool
  local isExternal::Bool

  @assign isExternal = begin
    @match inRestr begin
      SCode.FR_EXTERNAL_FUNCTION(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isExternal
end

function isImpureFunctionRestriction(inRestr::SCode.FunctionRestriction)::Bool
  local isExternal::Bool

  @assign isExternal = begin
    @match inRestr begin
      SCode.FR_EXTERNAL_FUNCTION(true) => begin
        true
      end

      SCode.FR_NORMAL_FUNCTION(true) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isExternal
end

function isRestrictionImpure(inRestr::SCode.Restriction, hasZeroOutputPreMSL3_2::Bool)::Bool
  local isExternal::Bool

  @assign isExternal = begin
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
  return isExternal
end

function setElementVisibility(
  inElement::SCode.Element,
  inVisibility::SCode.Visibility,
)::SCode.Element
  local outElement::SCode.Element

  @assign outElement = begin
    local name::SCode.Ident
    local prefs::SCode.Prefixes
    local attr::SCode.Attributes
    local ty::Absyn.TypeSpec
    local mod::SCode.Mod
    local cmt::SCode.Comment
    local cond::Option{Absyn.Exp}
    local info::SourceInfo
    local ep::SCode.Encapsulated
    local pp::SCode.Partial
    local res::SCode.Restriction
    local cdef::SCode.ClassDef
    local bc::Absyn.Path
    local ann::Option{SCode.Annotation}
    local imp::Absyn.Import
    local unit::Option{String}
    local weight::Option{AbstractFloat}
    @match (inElement, inVisibility) begin
      (SCode.COMPONENT(name, prefs, attr, ty, mod, cmt, cond, info), _) => begin
        @assign prefs = prefixesSetVisibility(prefs, inVisibility)
        SCode.COMPONENT(name, prefs, attr, ty, mod, cmt, cond, info)
      end

      (SCode.CLASS(name, prefs, ep, pp, res, cdef, cmt, info), _) => begin
        @assign prefs = prefixesSetVisibility(prefs, inVisibility)
        SCode.CLASS(name, prefs, ep, pp, res, cdef, cmt, info)
      end

      (SCode.EXTENDS(bc, _, mod, ann, info), _) => begin
        SCode.EXTENDS(bc, inVisibility, mod, ann, info)
      end

      (SCode.IMPORT(imp, _, info), _) => begin
        SCode.IMPORT(imp, inVisibility, info)
      end

      (SCode.DEFINEUNIT(name, _, unit, weight), _) => begin
        SCode.DEFINEUNIT(name, inVisibility, unit, weight)
      end
    end
  end
  return outElement
end

"""Returns true if the given element is a class with the given name, otherwise false."""
function isClassNamed(inName::SCode.Ident, inClass::SCode.Element)::Bool
  local outIsNamed::Bool

  @assign outIsNamed = begin
    local name::SCode.Ident
    @match (inName, inClass) begin
      (_, SCode.CLASS(name = name)) => begin
        stringEq(inName, name)
      end

      _ => begin
        false
      end
    end
  end
  return outIsNamed
end

"""Returns the comment of an element."""
function getElementComment(inElement::SCode.Element)::Option{SCode.Comment}
  local outComment::Option{SCode.Comment}

  @assign outComment = begin
    local cmt::SCode.Comment
    local cdef::SCode.ClassDef
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
  return outComment
end

"""Removes the annotation from a comment."""
function stripAnnotationFromComment(
  inComment::Option{<:SCode.Comment},
)::Option{SCode.Comment}
  local outComment::Option{SCode.Comment}

  @assign outComment = begin
    local str::Option{String}
    local cmt::Option{SCode.Comment}
    @match inComment begin
      SOME(SCode.COMMENT(_, str)) => begin
        SOME(SCode.COMMENT(NONE(), str))
      end

      _ => begin
        NONE()
      end
    end
  end
  return outComment
end

function isOverloadedFunction(inElement::SCode.Element)::Bool
  local isOverloaded::Bool

  @assign isOverloaded = begin
    @match inElement begin
      SCode.CLASS(classDef = SCode.OVERLOAD(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isOverloaded
end

"""
  @author: adrpo
  this function merges the original declaration with the redeclared declaration, see 7.3.2 in Spec.
  - modifiers from the constraining class on derived classes are merged into the new declaration
  - modifiers from the original derived classes are merged into the new declaration
  - if the original declaration has no constraining type the derived declaration is used
  - prefixes and attributes are merged
  same with components
  TODO! how about non-short class definitions with constrained by with modifications?
"""
function mergeWithOriginal(inNew::SCode.Element, inOld::SCode.Element)::SCode.Element
  local outNew::SCode.Element

  @assign outNew = begin
    local n::SCode.Element
    local o::SCode.Element
    local name1::SCode.Ident
    local name2::SCode.Ident
    local prefixes1::SCode.Prefixes
    local prefixes2::SCode.Prefixes
    local en1::SCode.Encapsulated
    local en2::SCode.Encapsulated
    local p1::SCode.Partial
    local p2::SCode.Partial
    local restr1::SCode.Restriction
    local restr2::SCode.Restriction
    local attr1::SCode.Attributes
    local attr2::SCode.Attributes
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local tp1::Absyn.TypeSpec
    local tp2::Absyn.TypeSpec
    local im1::Absyn.Import
    local im2::Absyn.Import
    local path1::Absyn.Path
    local path2::Absyn.Path
    local os1::Option{String}
    local os2::Option{String}
    local or1::Option{AbstractFloat}
    local or2::Option{AbstractFloat}
    local cond1::Option{Absyn.Exp}
    local cond2::Option{Absyn.Exp}
    local cd1::SCode.ClassDef
    local cd2::SCode.ClassDef
    local cm::SCode.Comment
    local i::SourceInfo
    local mCCNew::SCode.Mod
    local mCCOld::SCode.Mod
    #=  for functions return the new one!
    =#
    @matchcontinue (inNew, inOld) begin
      (_, _) => begin
        @match true = isFunction(inNew)
        inNew
      end

      (
        SCode.CLASS(name1, prefixes1, en1, p1, restr1, cd1, cm, i),
        SCode.CLASS(_, prefixes2, _, _, _, cd2, _, _),
      ) => begin
        @assign mCCNew = getConstrainedByModifiers(prefixes1)
        @assign mCCOld = getConstrainedByModifiers(prefixes2)
        @assign cd1 = mergeClassDef(cd1, cd2, mCCNew, mCCOld)
        @assign prefixes1 = propagatePrefixes(prefixes2, prefixes1)
        @assign n = SCode.CLASS(name1, prefixes1, en1, p1, restr1, cd1, cm, i)
        n
      end

      _ => begin
        inNew
      end
    end
  end
  return outNew
end

function getConstrainedByModifiers(inPrefixes::SCode.Prefixes)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local m::SCode.Mod
    @match inPrefixes begin
      SCode.PREFIXES(
        replaceablePrefix = SCode.REPLACEABLE(SOME(SCode.CONSTRAINCLASS(modifier = m))),
      ) => begin
        m
      end

      _ => begin
        SCode.NOMOD()
      end
    end
  end
  return outMod
end

"""
  @author: adrpo
  see mergeWithOriginal
"""
function mergeClassDef(
  inNew::SCode.ClassDef,
  inOld::SCode.ClassDef,
  inCCModNew::SCode.Mod,
  inCCModOld::SCode.Mod,
)::SCode.ClassDef
  local outNew::SCode.ClassDef

  @assign outNew = begin
    local n::SCode.ClassDef
    local o::SCode.ClassDef
    local ts1::Absyn.TypeSpec
    local ts2::Absyn.TypeSpec
    local m1::SCode.Mod
    local m2::SCode.Mod
    local a1::SCode.Attributes
    local a2::SCode.Attributes
    @match (inNew, inOld, inCCModNew, inCCModOld) begin
      (SCode.DERIVED(ts1, m1, a1), SCode.DERIVED(_, m2, a2), _, _) => begin
        @assign m2 = mergeModifiers(m2, inCCModOld)
        @assign m1 = mergeModifiers(m1, inCCModNew)
        @assign m2 = mergeModifiers(m1, m2)
        @assign a2 = propagateAttributes(a2, a1)
        @assign n = SCode.DERIVED(ts1, m2, a2)
        n
      end
    end
  end
  return outNew
end

function mergeModifiers(inNewMod::SCode.Mod, inOldMod::SCode.Mod)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local f1::SCode.Final
    local f2::SCode.Final
    local e1::SCode.Each
    local e2::SCode.Each
    local sl1::List{SCode.SubMod}
    local sl2::List{SCode.SubMod}
    local sl::List{SCode.SubMod}
    local b1::Option{Absyn.Exp}
    local b2::Option{Absyn.Exp}
    local b::Option{Absyn.Exp}
    local i1::SourceInfo
    local i2::SourceInfo
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
  return outMod
end

function mergeBindings(
  inNew::Option{<:Absyn.Exp},
  inOld::Option{<:Absyn.Exp},
)::Option{Absyn.Exp}
  local outBnd::Option{Absyn.Exp}

  @assign outBnd = begin
    @match (inNew, inOld) begin
      (SOME(_), _) => begin
        inNew
      end

      (NONE(), _) => begin
        inOld
      end
    end
  end
  return outBnd
end

function mergeSubMods(
  inNew::List{<:SCode.SubMod},
  inOld::List{<:SCode.SubMod},
)::List{SCode.SubMod}
  local outSubs::List{SCode.SubMod}

  @assign outSubs = begin
    local sl::List{SCode.SubMod}
    local rest::List{SCode.SubMod}
    local old::List{SCode.SubMod}
    local s::SCode.SubMod
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
  return outSubs
end

function removeSub(inSub::SCode.SubMod, inOld::List{<:SCode.SubMod})::List{SCode.SubMod}
  local outSubs::List{SCode.SubMod}

  @assign outSubs = begin
    local rest::List{SCode.SubMod}
    local id1::SCode.Ident
    local id2::SCode.Ident
    local idxs1::List{SCode.Subscript}
    local idxs2::List{SCode.Subscript}
    local s::SCode.SubMod
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
  return outSubs
end

function mergeComponentModifiers(
  inNewComp::SCode.Element,
  inOldComp::SCode.Element,
)::SCode.Element
  local outComp::SCode.Element

  @assign outComp = begin
    local n1::SCode.Ident
    local n2::SCode.Ident
    local p1::SCode.Prefixes
    local p2::SCode.Prefixes
    local a1::SCode.Attributes
    local a2::SCode.Attributes
    local t1::Absyn.TypeSpec
    local t2::Absyn.TypeSpec
    local m1::SCode.Mod
    local m2::SCode.Mod
    local m::SCode.Mod
    local c1::SCode.Comment
    local c2::SCode.Comment
    local cnd1::Option{Absyn.Exp}
    local cnd2::Option{Absyn.Exp}
    local i1::SourceInfo
    local i2::SourceInfo
    local c::SCode.Element
    @match (inNewComp, inOldComp) begin
      (
        SCode.COMPONENT(n1, p1, a1, t1, m1, c1, cnd1, i1),
        SCode.COMPONENT(_, _, _, _, m2, _, _, _),
      ) => begin
        @assign m = mergeModifiers(m1, m2)
        @assign c = SCode.COMPONENT(n1, p1, a1, t1, m, c1, cnd1, i1)
        c
      end
    end
  end
  return outComp
end

function propagateAttributes(
  inOriginalAttributes::SCode.Attributes,
  inNewAttributes::SCode.Attributes,
  inNewTypeIsArray::Bool = false,
)::SCode.Attributes
  local outNewAttributes::SCode.Attributes

  local dims1::Absyn.ArrayDim
  local dims2::Absyn.ArrayDim
  local ct1::SCode.ConnectorType
  local ct2::SCode.ConnectorType
  local prl1::SCode.Parallelism
  local prl2::SCode.Parallelism
  local var1::SCode.Variability
  local var2::SCode.Variability
  local dir1::Absyn.Direction
  local dir2::Absyn.Direction
  local if1::Absyn.IsField
  local if2::Absyn.IsField

  @match SCode.ATTR(dims1, ct1, prl1, var1, dir1, if1) = inOriginalAttributes
  @match SCode.ATTR(dims2, ct2, prl2, var2, dir2, if2) = inNewAttributes
  #=  If the new component has an array type, don't propagate the old dimensions.
  =#
  #=  E.g. type Real3 = Real[3];
  =#
  #=       replaceable Real x[:];
  =#
  #=       comp(redeclare Real3 x) => Real[3] x
  =#
  if !inNewTypeIsArray
    @assign dims2 = propagateArrayDimensions(dims1, dims2)
  end
  @assign ct2 = propagateConnectorType(ct1, ct2)
  @assign prl2 = propagateParallelism(prl1, prl2)
  @assign var2 = propagateVariability(var1, var2)
  @assign dir2 = propagateDirection(dir1, dir2)
  @assign if2 = propagateIsField(if1, if2)
  @assign outNewAttributes = SCode.ATTR(dims2, ct2, prl2, var2, dir2, if2)
  return outNewAttributes
end

function propagateArrayDimensions(
  inOriginalDims::Absyn.ArrayDim,
  inNewDims::Absyn.ArrayDim,
)::Absyn.ArrayDim
  local outNewDims::Absyn.ArrayDim

  @assign outNewDims = begin
    @match (inOriginalDims, inNewDims) begin
      (_, nil()) => begin
        inOriginalDims
      end

      _ => begin
        inNewDims
      end
    end
  end
  return outNewDims
end

function propagateConnectorType(
  inOriginalConnectorType::SCode.ConnectorType,
  inNewConnectorType::SCode.ConnectorType,
)::SCode.ConnectorType
  local outNewConnectorType::SCode.ConnectorType

  @assign outNewConnectorType = begin
    @match (inOriginalConnectorType, inNewConnectorType) begin
      (_, SCode.POTENTIAL(__)) => begin
        inOriginalConnectorType
      end

      _ => begin
        inNewConnectorType
      end
    end
  end
  return outNewConnectorType
end

function propagateParallelism(
  inOriginalParallelism::SCode.Parallelism,
  inNewParallelism::SCode.Parallelism,
)::SCode.Parallelism
  local outNewParallelism::SCode.Parallelism

  @assign outNewParallelism = begin
    @match (inOriginalParallelism, inNewParallelism) begin
      (_, SCode.NON_PARALLEL(__)) => begin
        inOriginalParallelism
      end

      _ => begin
        inNewParallelism
      end
    end
  end
  return outNewParallelism
end

function propagateVariability(
  inOriginalVariability::SCode.Variability,
  inNewVariability::SCode.Variability,
)::SCode.Variability
  local outNewVariability::SCode.Variability

  @assign outNewVariability = begin
    @match (inOriginalVariability, inNewVariability) begin
      (_, SCode.VAR(__)) => begin
        inOriginalVariability
      end

      _ => begin
        inNewVariability
      end
    end
  end
  return outNewVariability
end

function propagateDirection(
  inOriginalDirection::Absyn.Direction,
  inNewDirection::Absyn.Direction,
)::Absyn.Direction
  local outNewDirection::Absyn.Direction

  @assign outNewDirection = begin
    @match (inOriginalDirection, inNewDirection) begin
      (_, Absyn.BIDIR(__)) => begin
        inOriginalDirection
      end

      _ => begin
        inNewDirection
      end
    end
  end
  return outNewDirection
end

function propagateIsField(
  inOriginalIsField::Absyn.IsField,
  inNewIsField::Absyn.IsField,
)::Absyn.IsField
  local outNewIsField::Absyn.IsField

  @assign outNewIsField = begin
    @matchcontinue (inOriginalIsField, inNewIsField) begin
      (_, Absyn.NONFIELD(__)) => begin
        inOriginalIsField
      end

      _ => begin
        inNewIsField
      end
    end
  end
  return outNewIsField
end

function propagateAttributesVar(
  inOriginalVar::SCode.Element,
  inNewVar::SCode.Element,
  inNewTypeIsArray::Bool,
)::SCode.Element
  local outNewVar::SCode.Element

  local name::SCode.Ident
  local pref1::SCode.Prefixes
  local pref2::SCode.Prefixes
  local attr1::SCode.Attributes
  local attr2::SCode.Attributes
  local ty::Absyn.TypeSpec
  local mod::SCode.Mod
  local cmt::SCode.Comment
  local cond::Option{Absyn.Exp}
  local info::SourceInfo

  @match SCode.COMPONENT(prefixes = pref1, attributes = attr1) = inOriginalVar
  @match SCode.COMPONENT(name, pref2, attr2, ty, mod, cmt, cond, info) = inNewVar
  @assign pref2 = propagatePrefixes(pref1, pref2)
  @assign attr2 = propagateAttributes(attr1, attr2, inNewTypeIsArray)
  @assign outNewVar = SCode.COMPONENT(name, pref2, attr2, ty, mod, cmt, cond, info)
  return outNewVar
end

function propagateAttributesClass(
  inOriginalClass::SCode.Element,
  inNewClass::SCode.Element,
)::SCode.Element
  local outNewClass::SCode.Element

  local name::SCode.Ident
  local pref1::SCode.Prefixes
  local pref2::SCode.Prefixes
  local ep::SCode.Encapsulated
  local pp::SCode.Partial
  local res::SCode.Restriction
  local cdef::SCode.ClassDef
  local cmt::SCode.Comment
  local info::SourceInfo

  @match SCode.CLASS(prefixes = pref1) = inOriginalClass
  @match SCode.CLASS(name, pref2, ep, pp, res, cdef, cmt, info) = inNewClass
  @assign pref2 = propagatePrefixes(pref1, pref2)
  @assign outNewClass = SCode.CLASS(name, pref2, ep, pp, res, cdef, cmt, info)
  return outNewClass
end

function propagatePrefixes(
  inOriginalPrefixes::SCode.Prefixes,
  inNewPrefixes::SCode.Prefixes,
)::SCode.Prefixes
  local outNewPrefixes::SCode.Prefixes

  local vis1::SCode.Visibility
  local vis2::SCode.Visibility
  local io1::Absyn.InnerOuter
  local io2::Absyn.InnerOuter
  local rdp::SCode.Redeclare
  local fp::SCode.Final
  local rpp::SCode.Replaceable

  @match SCode.PREFIXES(visibility = vis1, innerOuter = io1) = inOriginalPrefixes
  @match SCode.PREFIXES(vis2, rdp, fp, io2, rpp) = inNewPrefixes
  @assign io2 = propagatePrefixInnerOuter(io1, io2)
  @assign outNewPrefixes = SCode.PREFIXES(vis2, rdp, fp, io2, rpp)
  return outNewPrefixes
end

function propagatePrefixInnerOuter(
  inOriginalIO::Absyn.InnerOuter,
  inIO::Absyn.InnerOuter,
)::Absyn.InnerOuter
  local outIO::Absyn.InnerOuter

  @assign outIO = begin
    @match (inOriginalIO, inIO) begin
      (_, Absyn.NOT_INNER_OUTER(__)) => begin
        inOriginalIO
      end

      _ => begin
        inIO
      end
    end
  end
  return outIO
end

"""Return true if Class is a partial."""
function isPackage(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(restriction = SCode.R_PACKAGE(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""Return true if Class is a partial."""
function isPartial(inClass::SCode.Element)::Bool
  local outBoolean::Bool

  @assign outBoolean = begin
    @match inClass begin
      SCode.CLASS(partialPrefix = SCode.PARTIAL(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outBoolean
end

"""
  Return true if the given element is allowed in a package, i.e. if it's a
  constant or non-component element. Otherwise returns false.
"""
function isValidPackageElement(inElement::SCode.Element)::Bool
  local outIsValid::Bool

  @assign outIsValid = begin
    @match inElement begin
      SCode.COMPONENT(attributes = SCode.ATTR(variability = SCode.CONST(__))) => begin
        true
      end

      SCode.COMPONENT(__) => begin
        false
      end

      _ => begin
        true
      end
    end
  end
  return outIsValid
end

"""returns true if a Class fulfills the requirements of an external object"""
function classIsExternalObject(cl::SCode.Element)::Bool
  local res::Bool

  @assign res = begin
    local els::List{SCode.Element}
    @match cl begin
      SCode.CLASS(classDef = SCode.PARTS(elementLst = els)) => begin
        isExternalObject(els)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""
  Returns true if the element list fulfills the condition of an External Object.
  An external object extends the builtinClass ExternalObject, and has two local
  functions, destructor and constructor.
"""
function isExternalObject(els::List{<:SCode.Element})::Bool
  local res::Bool

  @assign res = begin
    @matchcontinue els begin
      _ => begin
        @match 3 = listLength(els)
        @match true = hasExtendsOfExternalObject(els)
        @match true = hasExternalObjectDestructor(els)
        @match true = hasExternalObjectConstructor(els)
        true
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""returns true if element list contains 'extends ExternalObject;'"""
function hasExtendsOfExternalObject(inEls::List{<:SCode.Element})::Bool
  local res::Bool

  @assign res = begin
    local els::List{SCode.Element}
    local path::Absyn.Path
    @match inEls begin
      nil() => begin
        false
      end

      SCode.EXTENDS(
        baseClassPath = path,
      )  where {(AbsynUtil.pathEqual(path, Absyn.IDENT("ExternalObject")))} => begin
        true
      end

      _ <| els => begin
        hasExtendsOfExternalObject(els)
      end
    end
  end
  return res
end

"""returns true if element list contains 'function destructor .. end destructor'"""
function hasExternalObjectDestructor(inEls::List{<:SCode.Element})::Bool
  local res::Bool

  @assign res = begin
    local els::List{SCode.Element}
    @match inEls begin
      SCode.CLASS(name = "destructor") <| _ => begin
        true
      end

      _ <| els => begin
        hasExternalObjectDestructor(els)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""returns true if element list contains 'function constructor ... end constructor'"""
function hasExternalObjectConstructor(inEls::List{<:SCode.Element})::Bool
  local res::Bool

  @assign res = begin
    local els::List{SCode.Element}
    @match inEls begin
      SCode.CLASS(name = "constructor") <| _ => begin
        true
      end

      _ <| els => begin
        hasExternalObjectConstructor(els)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

"""returns the class 'function destructor .. end destructor' from element list"""
function getExternalObjectDestructor(inEls::List{<:SCode.Element})::SCode.Element
  local cl::SCode.Element

  @assign cl = begin
    local els::List{SCode.Element}
    @match inEls begin
      cl && SCode.CLASS(name = "destructor") <| _ => begin
        cl
      end

      _ <| els => begin
        getExternalObjectDestructor(els)
      end
    end
  end
  return cl
end

"""returns the class 'function constructor ... end constructor' from element list"""
function getExternalObjectConstructor(inEls::List{<:SCode.Element})::SCode.Element
  local cl::SCode.Element

  @assign cl = begin
    local els::List{SCode.Element}
    @match inEls begin
      cl && SCode.CLASS(name = "constructor") <| _ => begin
        cl
      end

      _ <| els => begin
        getExternalObjectConstructor(els)
      end
    end
  end
  return cl
end

function isInstantiableClassRestriction(inRestriction::SCode.Restriction)::Bool
  local outIsInstantiable::Bool

  @assign outIsInstantiable = begin
    @match inRestriction begin
      SCode.R_CLASS(__) => begin
        true
      end

      SCode.R_MODEL(__) => begin
        true
      end

      SCode.R_RECORD(__) => begin
        true
      end

      SCode.R_BLOCK(__) => begin
        true
      end

      SCode.R_CONNECTOR(__) => begin
        true
      end

      SCode.R_TYPE(__) => begin
        true
      end

      SCode.R_ENUMERATION(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsInstantiable
end

function isInitial(inInitial::SCode.Initial)::Bool
  local isIn::Bool

  @assign isIn = begin
    @match inInitial begin
      SCode.INITIAL(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isIn
end

"""check if the restrictions are the same for redeclared classes"""
function checkSameRestriction(
  inResNew::SCode.Restriction,
  inResOrig::SCode.Restriction,
  inInfoNew::SourceInfo,
  inInfoOrig::SourceInfo,
)::Tuple{SCode.Restriction, SourceInfo}
  local outInfo::SourceInfo
  local outRes::SCode.Restriction

  @assign (outRes, outInfo) = begin
    @match (inResNew, inResOrig, inInfoNew, inInfoOrig) begin
      (_, _, _, _) => begin
        (inResNew, inInfoNew)
      end
    end
  end
  #=  todo: check if the restrictions are the same for redeclared classes
  =#
  return (outRes, outInfo)
end

"""
  @auhtor: adrpo
  set the name of the component
"""
function setComponentName(inE::SCode.Element, inName::SCode.Ident)::SCode.Element
  local outE::SCode.Element

  local n::SCode.Ident
  local pr::SCode.Prefixes
  local atr::SCode.Attributes
  local ts::Absyn.TypeSpec
  local cmt::SCode.Comment
  local cnd::Option{Absyn.Exp}
  local bc::SCode.Path
  local v::SCode.Visibility
  local m::SCode.Mod
  local a::Option{SCode.Annotation}
  local i::SourceInfo

  @match SCode.COMPONENT(n, pr, atr, ts, m, cmt, cnd, i) = inE
  @assign outE = SCode.COMPONENT(inName, pr, atr, ts, m, cmt, cnd, i)
  return outE
end

function isArrayComponent(inElement::SCode.Element)::Bool
  local outIsArray::Bool

  @assign outIsArray = begin
    @match inElement begin
      SCode.COMPONENT(attributes = SCode.ATTR(arrayDims = _ <| _)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outIsArray
end

function isEmptyMod(mod::SCode.Mod)::Bool
  local isEmpty::Bool

  @assign isEmpty = begin
    @match mod begin
      SCode.NOMOD(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isEmpty
end

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
  local isEmpty::Bool

  @assign isEmpty = begin
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
  return isEmpty
end

"""Strips all annotations and/or comments from a program."""
function stripCommentsFromProgram(
  program::SCode.Program,
  stripAnnotations::Bool,
  stripComments::Bool,
)::SCode.Program

  @assign program =
    list(stripCommentsFromElement(e, stripAnnotations, stripComments) for e in program)
  return program
end

function stripCommentsFromElement(
  element::SCode.Element,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.Element

  @assign () = begin
    @match element begin
      SCode.EXTENDS(__) => begin
        if stripAnn
          @assign element.ann = NONE()
        end
        @assign element.modifications =
          stripCommentsFromMod(element.modifications, stripAnn, stripCmt)
        ()
      end

      SCode.CLASS(__) => begin
        @assign element.classDef =
          stripCommentsFromClassDef(element.classDef, stripAnn, stripCmt)
        @assign element.cmt = stripCommentsFromComment(element.cmt, stripAnn, stripCmt)
        ()
      end

      SCode.COMPONENT(__) => begin
        @assign element.modifications =
          stripCommentsFromMod(element.modifications, stripAnn, stripCmt)
        @assign element.comment =
          stripCommentsFromComment(element.comment, stripAnn, stripCmt)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return element
end

function stripCommentsFromMod(mod::SCode.Mod, stripAnn::Bool, stripCmt::Bool)::SCode.Mod

  @assign () = begin
    @match mod begin
      SCode.MOD(__) => begin
        @assign mod.subModLst =
          list(stripCommentsFromSubMod(m, stripAnn, stripCmt) for m in mod.subModLst)
        ()
      end

      SCode.REDECL(__) => begin
        @assign mod.element = stripCommentsFromElement(mod.element, stripAnn, stripCmt)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return mod
end

function stripCommentsFromSubMod(
  submod::SCode.SubMod,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.SubMod

  @assign submod.mod = stripCommentsFromMod(submod.mod, stripAnn, stripCmt)
  return submod
end

function stripCommentsFromClassDef(
  cdef::SCode.ClassDef,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.ClassDef

  @assign cdef = begin
    local el::List{SCode.Element}
    local eql::List{SCode.Equation}
    local ieql::List{SCode.Equation}
    local alg::List{SCode.AlgorithmSection}
    local ialg::List{SCode.AlgorithmSection}
    local ext::Option{SCode.ExternalDecl}
    @match cdef begin
      SCode.PARTS(__) => begin
        @assign el =
          list(stripCommentsFromElement(e, stripAnn, stripCmt) for e in cdef.elementLst)
        @assign eql = list(
          stripCommentsFromEquation(eq, stripAnn, stripCmt)
          for eq in cdef.normalEquationLst
        )
        @assign ieql = list(
          stripCommentsFromEquation(ieq, stripAnn, stripCmt)
          for ieq in cdef.initialEquationLst
        )
        @assign alg = list(
          stripCommentsFromAlgorithm(a, stripAnn, stripCmt)
          for a in cdef.normalAlgorithmLst
        )
        @assign ialg = list(
          stripCommentsFromAlgorithm(ia, stripAnn, stripCmt)
          for ia in cdef.initialAlgorithmLst
        )
        @assign ext = stripCommentsFromExternalDecl(cdef.externalDecl, stripAnn, stripCmt)
        SCode.PARTS(el, eql, ieql, alg, ialg, cdef.constraintLst, cdef.clsattrs, ext)
      end

      SCode.CLASS_EXTENDS(__) => begin
        @assign cdef.modifications =
          stripCommentsFromMod(cdef.modifications, stripAnn, stripCmt)
        @assign cdef.composition =
          stripCommentsFromClassDef(cdef.composition, stripAnn, stripCmt)
        cdef
      end

      SCode.DERIVED(__) => begin
        @assign cdef.modifications =
          stripCommentsFromMod(cdef.modifications, stripAnn, stripCmt)
        cdef
      end

      SCode.ENUMERATION(__) => begin
        @assign cdef.enumLst =
          list(stripCommentsFromEnum(e, stripAnn, stripCmt) for e in cdef.enumLst)
        cdef
      end

      _ => begin
        cdef
      end
    end
  end
  return cdef
end

function stripCommentsFromEnum(enum::SCode.Enum, stripAnn::Bool, stripCmt::Bool)::SCode.Enum

  @assign enum.comment = stripCommentsFromComment(enum.comment, stripAnn, stripCmt)
  return enum
end

function stripCommentsFromComment(
  cmt::SCode.Comment,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.Comment

  if stripAnn
    @assign cmt.annotation_ = NONE()
  end
  if stripCmt
    @assign cmt.comment = NONE()
  end
  return cmt
end

function stripCommentsFromExternalDecl(
  extDecl::Option{<:SCode.ExternalDecl},
  stripAnn::Bool,
  stripCmt::Bool,
)::Option{SCode.ExternalDecl}

  local ext_decl::SCode.ExternalDecl

  if isSome(extDecl) && stripAnn
    @match SOME(ext_decl) = extDecl
    @assign ext_decl.annotation_ = NONE()
    @assign extDecl = SOME(ext_decl)
  end
  return extDecl
end

function stripCommentsFromEquation(
  eq::SCode.Equation,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.Equation

  @assign eq.eEquation = stripCommentsFromEEquation(eq.eEquation, stripAnn, stripCmt)
  return eq
end

function stripCommentsFromEEquation(
  eq::SCode.EEquation,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.EEquation

  @assign () = begin
    @match eq begin
      SCode.EQ_IF(__) => begin
        @assign eq.thenBranch = list(
          list(stripCommentsFromEEquation(e, stripAnn, stripCmt) for e in branch)
          for branch in eq.thenBranch
        )
        @assign eq.elseBranch =
          list(stripCommentsFromEEquation(e, stripAnn, stripCmt) for e in eq.elseBranch)
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_EQUALS(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_PDE(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_CONNECT(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_FOR(__) => begin
        @assign eq.eEquationLst = list(
          stripCommentsFromEEquation(e, stripAnn, stripCmt) for e in eq.eEquationLst
        )
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_WHEN(__) => begin
        @assign eq.eEquationLst = list(
          stripCommentsFromEEquation(e, stripAnn, stripCmt) for e in eq.eEquationLst
        )
        @assign eq.elseBranches = list(
          stripCommentsFromWhenEqBranch(b, stripAnn, stripCmt) for b in eq.elseBranches
        )
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_ASSERT(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_TERMINATE(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_REINIT(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end

      SCode.EQ_NORETCALL(__) => begin
        @assign eq.comment = stripCommentsFromComment(eq.comment, stripAnn, stripCmt)
        ()
      end
    end
  end
  return eq
end

function stripCommentsFromWhenEqBranch(
  branch::Tuple{<:Absyn.Exp, List{<:SCode.EEquation}},
  stripAnn::Bool,
  stripCmt::Bool,
)::Tuple{Absyn.Exp, List{SCode.EEquation}}

  local cond::Absyn.Exp
  local body::List{SCode.EEquation}

  @assign (cond, body) = branch
  @assign body = list(stripCommentsFromEEquation(e, stripAnn, stripCmt) for e in body)
  @assign branch = (cond, body)
  return branch
end

function stripCommentsFromAlgorithm(
  alg::SCode.AlgorithmSection,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.AlgorithmSection

  @assign alg.statements =
    list(stripCommentsFromStatement(s, stripAnn, stripCmt) for s in alg.statements)
  return alg
end

function stripCommentsFromStatement(
  stmt::SCode.Statement,
  stripAnn::Bool,
  stripCmt::Bool,
)::SCode.Statement

  @assign () = begin
    @match stmt begin
      SCode.ALG_ASSIGN(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_IF(__) => begin
        @assign stmt.trueBranch = list(
          stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.trueBranch
        )
        @assign stmt.elseIfBranch = list(
          stripCommentsFromStatementBranch(b, stripAnn, stripCmt)
          for b in stmt.elseIfBranch
        )
        @assign stmt.elseBranch = list(
          stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.elseBranch
        )
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_FOR(__) => begin
        @assign stmt.forBody =
          list(stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.forBody)
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_PARFOR(__) => begin
        @assign stmt.parforBody = list(
          stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.parforBody
        )
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_WHILE(__) => begin
        @assign stmt.whileBody = list(
          stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.whileBody
        )
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_WHEN_A(__) => begin
        @assign stmt.branches = list(
          stripCommentsFromStatementBranch(b, stripAnn, stripCmt) for b in stmt.branches
        )
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_ASSERT(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_TERMINATE(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_REINIT(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_NORETCALL(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_RETURN(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_BREAK(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_FAILURE(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_TRY(__) => begin
        @assign stmt.body =
          list(stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.body)
        @assign stmt.elseBody =
          list(stripCommentsFromStatement(s, stripAnn, stripCmt) for s in stmt.elseBody)
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end

      SCode.ALG_CONTINUE(__) => begin
        @assign stmt.comment = stripCommentsFromComment(stmt.comment, stripAnn, stripCmt)
        ()
      end
    end
  end
  return stmt
end

function stripCommentsFromStatementBranch(
  branch::Tuple{<:Absyn.Exp, List{<:SCode.Statement}},
  stripAnn::Bool,
  stripCmt::Bool,
)::Tuple{Absyn.Exp, List{SCode.Statement}}

  local cond::Absyn.Exp
  local body::List{SCode.Statement}

  @assign (cond, body) = branch
  @assign body = list(stripCommentsFromStatement(s, stripAnn, stripCmt) for s in body)
  @assign branch = (cond, body)
  return branch
end

function checkValidEnumLiteral(inLiteral::String, inInfo::SourceInfo)
  if listMember(inLiteral, list("quantity", "min", "max", "start", "fixed"))
    Error.addSourceMessage(Error.INVALID_ENUM_LITERAL, list(inLiteral), inInfo)
    fail()
  end
end

"""get the redeclare-as-element elements"""
function isRedeclareElement(element::SCode.Element)::Bool
  local isElement::Bool

  @assign isElement = begin
    @match element begin
      SCode.COMPONENT(prefixes = SCode.PREFIXES(redeclarePrefix = SCode.REDECLARE(__))) =>
        begin
          true
        end

      SCode.CLASS(classDef = SCode.CLASS_EXTENDS(__)) => begin
        false
      end

      SCode.CLASS(prefixes = SCode.PREFIXES(redeclarePrefix = SCode.REDECLARE(__))) =>
        begin
          true
        end

      _ => begin
        false
      end
    end
  end
  #=  redeclare-as-element component
  =#
  #=  not redeclare class extends
  =#
  #=  redeclare-as-element class!, not class extends
  =#
  return isElement
end

function mergeSCodeOptAnn(
  inModOuter::Option{<:SCode.Annotation},
  inModInner::Option{<:SCode.Annotation},
)::Option{SCode.Annotation}
  local outMod::Option{SCode.Annotation}

  @assign outMod = begin
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
  return outMod
end

function mergeSCodeMods(inModOuter::SCode.Mod, inModInner::SCode.Mod)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
    local f1::SCode.Final
    local f2::SCode.Final
    local e1::SCode.Each
    local e2::SCode.Each
    local subMods1::List{SCode.SubMod}
    local subMods2::List{SCode.SubMod}
    local b1::Option{Absyn.Exp}
    local b2::Option{Absyn.Exp}
    local info::SourceInfo
    @match (inModOuter, inModInner) begin
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
  return outMod
end

#= Functions needed by translated NFFrontEnd =#

"""Check if the named annotation is present and has value false."""
function optCommentHasBooleanNamedAnnotationFalse(
  comm::Option,
  annotationName::String,
)::Bool
  local outB::Bool
  outB = begin
    local ann::SCode.Annotation
    local submods::List{SCode.SubMod}
    @match comm begin
      SOME(SCode.COMMENT(annotation_ = SOME(ann))) => begin
        @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = ann
        ListUtil.exist1(submods, hasBooleanNamedAnnotationFalse2, annotationName)
      end
      _ => false
    end
  end
  return outB
end

function hasBooleanNamedAnnotationFalse2(inSubMod::SCode.SubMod, inName::String)::Bool
  local outIsMatch::Bool
  outIsMatch = begin
    local id::String
    @match inSubMod begin
      SCode.NAMEMOD(ident = id, mod = SCode.MOD(binding = SOME(Absyn.BOOL(value = false)))) => begin
        stringEq(id, inName)
      end
      _ => false
    end
  end
  return outIsMatch
end

"""Look up an annotation by name, returning its modifier or NOMOD."""
function lookupAnnotation(ann::SCode.Annotation, name::String)::SCode.Mod
  local mod::SCode.Mod
  mod = begin
    local submods::List{SCode.SubMod}
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

"""Look up all annotations with the given name, returning a list of modifiers."""
function lookupAnnotations(ann::SCode.Annotation, name::String)::List{SCode.Mod}
  local mods::List{SCode.Mod} = nil
  @match SCode.ANNOTATION(modification = SCode.MOD(subModLst = submods)) = ann
  for sm in submods
    @match SCode.NAMEMOD(ident = id, mod = m) = sm
    if id == name
      mods = Cons(m, mods)
    end
  end
  mods = listReverse(mods)
  return mods
end

"""Look up an annotation on an SCode element (CLASS or COMPONENT)."""
function lookupElementAnnotation(elem::SCode.Element, name::String)::SCode.Mod
  local mod::SCode.Mod
  mod = begin
    local ann::SCode.Annotation
    @match elem begin
      SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))) => lookupAnnotation(ann, name)
      SCode.COMPONENT(comment = SCode.COMMENT(annotation_ = SOME(ann))) => lookupAnnotation(ann, name)
      _ => SCode.NOMOD()
    end
  end
  return mod
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

"""Look up a boolean annotation modifier on an SCode element."""
function lookupBooleanAnnotationMod(elem::SCode.Element, name::String)::Bool
  local b::Bool
  local mod::SCode.Mod = lookupElementAnnotation(elem, name)
  b = @match mod begin
    SCode.MOD(binding = SOME(Absyn.BOOL(value = v))) => v
    _ => false
  end
  return b
end

"""Look up a sub-modifier by name inside a modifier."""
function lookupModInMod(name::String, mod::SCode.Mod)::SCode.Mod
  local outMod::SCode.Mod
  outMod = begin
    local submods::List{SCode.SubMod}
    @match mod begin
      SCode.MOD(subModLst = submods) => begin
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
  return outMod
end

"""Check if a class definition has equation or algorithm sections."""
function classDefHasSections(classDef::SCode.ClassDef)::Bool
  local hasSections::Bool
  hasSections = @match classDef begin
    SCode.PARTS() => begin
      !(listEmpty(classDef.normalEquationLst) &&
        listEmpty(classDef.initialEquationLst) &&
        listEmpty(classDef.normalAlgorithmLst) &&
        listEmpty(classDef.initialAlgorithmLst))
    end
    _ => false
  end
  return hasSections
end

"""Get the class body (ClassDef) from a CLASS element."""
function getClassBody(elem::SCode.Element)::SCode.ClassDef
  local classDef::SCode.ClassDef
  @match SCode.CLASS(classDef = classDef) = elem
  return classDef
end

"""Check if an algorithm section is non-empty."""
function isNonEmptyAlgorithm(alg::SCode.AlgorithmSection)::Bool
  local nonEmpty::Bool
  nonEmpty = @match alg begin
    SCode.ALGORITHM(statements = stmts) => !listEmpty(stmts)
    _ => false
  end
  return nonEmpty
end

"""Check if an element has a named external call."""
function hasNamedExternalCall(elem::SCode.Element, name::String)::Bool
  local found::Bool
  found = begin
    @match elem begin
      SCode.CLASS(classDef = SCode.PARTS(externalDecl = SOME(SCode.EXTERNALDECL(funcName = SOME(fname))))) => begin
        fname == name
      end
      _ => false
    end
  end
  return found
end

"""Extract the annotation from an optional comment."""
function optCommentAnnotation(comment::Option)::Option{SCode.Annotation}
  local ann::Option{SCode.Annotation}
  ann = @match comment begin
    SOME(SCode.COMMENT(annotation_ = a)) => a
    _ => nothing
  end
  return ann
end

"""Append an annotation to an optional comment."""
function appendAnnotationToCommentOption(
  inAnnotation::SCode.Annotation,
  inComment::Option,
)::Option{SCode.Comment}
  local outComment::Option{SCode.Comment}
  outComment = @match inComment begin
    SOME(cmt) => SOME(appendAnnotationToComment(inAnnotation, cmt))
    _ => SOME(SCode.COMMENT(SOME(inAnnotation), nothing))
  end
  return outComment
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

"""Map a function over the statements of an algorithm section."""
function mapAlgorithmStatements(
  alg::SCode.AlgorithmSection,
  func,
)::SCode.AlgorithmSection
  local outAlg::SCode.AlgorithmSection
  outAlg = @match alg begin
    SCode.ALGORITHM(statements = stmts) => begin
      SCode.ALGORITHM(list(func(s) for s in stmts))
    end
  end
  return outAlg
end

"""Map a function over expressions in an equation list."""
function mapEquationsList(
  eqs::List{SCode.Equation},
  func,
)::List{SCode.Equation}
  return list(mapEquation(eq, func) for eq in eqs)
end

function mapEquation(eq::SCode.Equation, func)::SCode.Equation
  @match SCode.EQUATION(eEquation = eeq) = eq
  return SCode.EQUATION(mapEEquation(eeq, func))
end

"""Map a function over expressions in an EEquation. Stub - returns unchanged."""
function mapEEquation(eq::SCode.EEquation, func)::SCode.EEquation
  return eq
end

"""Map a function over expressions in equations. Stub - returns unchanged."""
function mapEquationExps(eq::SCode.EEquation, func)::SCode.EEquation
  return eq
end

"""Map a function over expressions in statements. Stub - returns unchanged."""
function mapStatementExps(stmt::SCode.Statement, func)::SCode.Statement
  return stmt
end

@exportAll()
end
