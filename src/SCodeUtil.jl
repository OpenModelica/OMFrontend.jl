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
    local prefixes1::SCode.PREFIXES
    local prefixes2::SCode.PREFIXES
    local en1::SCode.Encapsulated
    local en2::SCode.Encapsulated
    local p1::SCode.Partial
    local p2::SCode.Partial
    local restr1::SCode.Restriction
    local restr2::SCode.Restriction
    local attr1::SCode.ATTR
    local attr2::SCode.ATTR
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
  #= otherwise false =#
  return equal
end

#= stefan =#

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
  #= operator record
     expandable connectors
     non expandable connectors
     operator
     BTH =#
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

function enumEqual(e1::SCode.ENUM, e2::SCode.ENUM)::Bool
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
  #= ignore comments here. =#
  return isEqual
end

"""Returns true if Two ClassDef's are equal"""
function classDefEqual(cdef1::SCode.ClassDef, cdef2::SCode.ClassDef)::Bool
  local equal::Bool

  @assign equal = begin
    local elts1::List{SCode.Element}
    local elts2::List{SCode.Element}
    local eqns1::List{SCode.EQUATION}
    local eqns2::List{SCode.EQUATION}
    local ieqns1::List{SCode.EQUATION}
    local ieqns2::List{SCode.EQUATION}
    local algs1::List{SCode.ALGORITHM}
    local algs2::List{SCode.ALGORITHM}
    local ialgs1::List{SCode.ALGORITHM}
    local ialgs2::List{SCode.ALGORITHM}
    local cons1::List{SCode.CONSTRAINTS}
    local cons2::List{SCode.CONSTRAINTS}
    local attr1::SCode.ATTR
    local attr2::SCode.ATTR
    local tySpec1::Absyn.TypeSpec
    local tySpec2::Absyn.TypeSpec
    local p1::Absyn.Path
    local p2::Absyn.Path
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local elst1::List{SCode.ENUM}
    local elst2::List{SCode.ENUM}
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

"""Returns true if two Algorithm's are equal."""
function algorithmEqual(alg1::SCode.ALGORITHM, alg2::SCode.ALGORITHM)::Bool
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
  #= false otherwise! =#
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
  #= base it on equality for now as the ones below are not implemented!
     Don't compare comments and line numbers
     maybe replace failure/equality with these:
     case(Absyn.ALG_IF(_,_,_,_),Absyn.ALG_IF(_,_,_,_)) then false;  TODO: SCode.ALG_IF
     case (Absyn.ALG_FOR(_,_),Absyn.ALG_FOR(_,_)) then false;  TODO: SCode.ALG_FOR
     case (Absyn.ALG_WHILE(_,_),Absyn.ALG_WHILE(_,_)) then false;  TODO: SCode.ALG_WHILE
     case(Absyn.ALG_WHEN_A(_,_,_),Absyn.ALG_WHEN_A(_,_,_)) then false; TODO: SCode.ALG_WHILE
     case (Absyn.ALG_NORETCALL(_,_),Absyn.ALG_NORETCALL(_,_)) then false; TODO: SCode.ALG_NORETCALL =#
  return equal
end

"""Returns true if two equations are equal."""
function equationEqual(eqn1::SCode.EQUATION, eqn2::SCode.EQUATION)::Bool
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
  #= TODO: elsewhen not checked yet.
     otherwise false =#
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
    local submodlst1::List{SCode.NAMEMOD}
    local submodlst2::List{SCode.NAMEMOD}
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
  inSubModLst1::List{<:SCode.NAMEMOD},
  inSubModLst2::List{<:SCode.NAMEMOD},
)::Bool
  local equal::Bool

  @assign equal = begin
    local id1::SCode.Ident
    local id2::SCode.Ident
    local mod1::SCode.Mod
    local mod2::SCode.Mod
    local ss1::List{SCode.Subscript}
    local ss2::List{SCode.Subscript}
    local subModLst1::List{SCode.NAMEMOD}
    local subModLst2::List{SCode.NAMEMOD}
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

"""Returns true if two Atributes are equal"""
function attributesEqual(attr1::SCode.ATTR, attr2::SCode.ATTR)::Bool
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
    local comment::Option{SCode.COMMENT}
    local algs1::List{Absyn.AlgorithmItem}
    local algs2::List{Absyn.AlgorithmItem}
    local algsLst::List{List{Absyn.AlgorithmItem}}
    local abranches::List{Tuple{Absyn.Exp, List{Absyn.AlgorithmItem}}}
    @match stmt begin
      SCode.ALG_ASSIGN(assignComponent, value, _, info) => begin
        Absyn.ALGORITHMITEM(Absyn.ALG_ASSIGN(assignComponent, value), NONE(), info)
      end

      SCode.ALG_IF(boolExpr, trueBranch, branches, elseBranch, _, info) => begin
        @assign algs1 = ListUtil.map(trueBranch, statementToAlgorithmItem, Absyn.AlgorithmItem)
        @assign conditions = ListUtil.map(branches, Util.tuple21, Absyn.Exp)
        @assign stmtsList = ListUtil.map(branches, Util.tuple22, List{SCode.Statement})
        @assign algsLst = ListUtil.mapList(stmtsList, statementToAlgorithmItem, Absyn.AlgorithmItem)
        @assign abranches = ListUtil.threadTuple(conditions, algsLst, Tuple{Absyn.Exp, List{Absyn.AlgorithmItem}})
        @assign algs2 = ListUtil.map(elseBranch, statementToAlgorithmItem, Absyn.AlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_IF(boolExpr, algs1, abranches, algs2), NONE(), info)
      end

      SCode.ALG_FOR(iterator, range, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem, Absyn.AlgorithmItem)
        Absyn.ALGORITHMITEM(
          Absyn.ALG_FOR(list(Absyn.ITERATOR(iterator, NONE(), range)), algs1),
          NONE(),
          info,
        )
      end

      SCode.ALG_PARFOR(iterator, range, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem, Absyn.AlgorithmItem)
        Absyn.ALGORITHMITEM(
          Absyn.ALG_PARFOR(list(Absyn.ITERATOR(iterator, NONE(), range)), algs1),
          NONE(),
          info,
        )
      end

      SCode.ALG_WHILE(boolExpr, body, _, info) => begin
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem, Absyn.AlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_WHILE(boolExpr, algs1), NONE(), info)
      end

      SCode.ALG_WHEN_A(branches, _, info) => begin
        @match _cons(boolExpr, conditions) = ListUtil.map(branches, Util.tuple21, Absyn.Exp)
        @assign stmtsList = ListUtil.map(branches, Util.tuple22, List{SCode.Statement})
        @match _cons(algs1, algsLst) =
          ListUtil.mapList(stmtsList, statementToAlgorithmItem, Absyn.AlgorithmItem)
        @assign abranches = ListUtil.threadTuple(conditions, algsLst, Tuple{Absyn.Exp, List{Absyn.AlgorithmItem}})
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
        @assign algs1 = ListUtil.map(body, statementToAlgorithmItem, Absyn.AlgorithmItem)
        Absyn.ALGORITHMITEM(Absyn.ALG_FAILURE(algs1), NONE(), info)
      end
    end
  end
  return algi
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

eachBool(inEach::SCode.EACH) = true
eachBool(inEach::SCode.NOT_EACH) = false

function prefixesRedeclare(inPrefixes::SCode.PREFIXES)::SCode.Redeclare
  local outRedeclare::SCode.Redeclare

  @match SCode.PREFIXES(redeclarePrefix = outRedeclare) = inPrefixes
  return outRedeclare
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

function prefixesFinal(inPrefixes::SCode.PREFIXES)::SCode.Final
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
function prefixesEqual(prefixes1::SCode.PREFIXES, prefixes2::SCode.PREFIXES)::Bool
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
function prefixesReplaceable(prefixes::SCode.PREFIXES)::SCode.Replaceable
  local repl::SCode.Replaceable

  @match SCode.PREFIXES(replaceablePrefix = repl) = prefixes
  return repl
end

function elementPrefixes(inElement::SCode.Element)::SCode.PREFIXES
  local outPrefixes::SCode.PREFIXES

  @assign outPrefixes = begin
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
  return outPrefixes
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

"""
 Returns the annotation with the given name in the element, or fails if no
 such annotation could be found.
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
  local hasAnn::Bool

  @assign hasAnn = begin
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
  return hasAnn
end

"""check if the named annotation is present and has value true"""
function commentHasBooleanNamedAnnotation(comm::SCode.COMMENT, annotationName::String)::Bool
  local outB::Bool

  @assign outB = begin
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
  return outB
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
  local evalIsTrue::Bool

  @assign evalIsTrue = begin
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
  return evalIsTrue
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
    local i::Absyn.Ident
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
    local els::SCode.Program
    local e::SCode.Element
    local p::Absyn.Path
    local i::Absyn.Ident
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
  @auhtor: adrpo
  get the modification in component
"""
function getComponentMod(inE::SCode.Element)::SCode.Mod
  local outMod::SCode.Mod

  @match SCode.COMPONENT(modifications = outMod) = inE
  return outMod
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
  local outIsBuiltin::Bool

  @assign outIsBuiltin = begin
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
  return outIsBuiltin
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

"""Returns the comment of an element."""
function getElementComment(inElement::SCode.Element)::Option{SCode.COMMENT}
  local outComment::Option{SCode.COMMENT}

  @assign outComment = begin
    local cmt::SCode.COMMENT
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

function mergeModifiers(inNewMod::SCode.Mod, inOldMod::SCode.Mod)::SCode.Mod
  local outMod::SCode.Mod

  @assign outMod = begin
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
  inNew::List{<:SCode.NAMEMOD},
  inOld::List{<:SCode.NAMEMOD},
)::List{SCode.NAMEMOD}
  local outSubs::List{SCode.NAMEMOD}

  @assign outSubs = begin
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
  return outSubs
end

function removeSub(inSub::SCode.NAMEMOD, inOld::List{<:SCode.NAMEMOD})::List{SCode.NAMEMOD}
  local outSubs::List{SCode.NAMEMOD}

  @assign outSubs = begin
    local rest::List{SCode.NAMEMOD}
    local id1::SCode.Ident
    local id2::SCode.Ident
    local idxs1::List{SCode.Subscript}
    local idxs2::List{SCode.Subscript}
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
  return outSubs
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

function mergeSCodeOptAnn(
  inModOuter::Option{<:SCode.ANNOTATION},
  inModInner::Option{<:SCode.ANNOTATION},
)::Option{SCode.ANNOTATION}
  local outMod::Option{SCode.ANNOTATION}

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
  return outMod
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
  local mod::SCode.Mod
  mod = begin
    local ann::SCode.ANNOTATION
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
function mapStatementExps(stmt::SCode.Statement, func)::SCode.Statement
  return stmt
end

@exportAll()
end
