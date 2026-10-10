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

module AbsynToSCode

using MetaModelica
using ExportAll

import Absyn
import SCode
import ListUtil

import ..AbsynUtil
import ..SCodeUtil
import ..Util
import ..System

using Distributed

const ASSERTION_LEVEL_ERROR =
  Absyn.CREF(Absyn.CREF_FULLYQUALIFIED(Absyn.CREF_QUAL(
    "AssertionLevel",
    nil,
    Absyn.CREF_IDENT("error", nil),
  )))::Absyn.Exp

"""
  This function takes an Absyn.Program
  and constructs a SCode.Program from it.
  This particular version of translate tries to fix any uniontypes
  in the inProgram before translating further. This should probably
  be moved into Parser.parse since you have to modify the tree every
  single time you translate...
"""
function translateAbsyn2SCode(inProgram::Absyn.Program)
  local outProgram::SCode.Program
   outProgram = begin
    local spInitial::SCode.Program
    local sp::SCode.Program
    local inClasses::List{Absyn.Class}
    local initialClasses::List{Absyn.Class}
    @match inProgram begin
      _ => begin
        #            InstHashTable.init()
        @match Absyn.PROGRAM(classes = inClasses) = inProgram
        System.setHasInnerOuterDefinitions(false)
        System.setHasExpandableConnectors(false)
        System.setHasOverconstrainedConnectors(false)
        System.setHasStreamConnectors(false)
        # Top-level fan-out is too small (typical input has 1 top-level class,
        # MSL has 3 wildly unbalanced ones) for thread spawning to be worthwhile.
        # The parallel branch fires deeper, inside `translateEitemlist`, where
        # every `Absyn.ElementItem` is independent and counts in the dozens.
        sp = list(translateClass(c) for c in inClasses)
      end
    end
  end
  return outProgram
end

function translateClass(inClass::Absyn.Class)
  local outClass::SCode.Element
   outClass = translateClass2(inClass, 0)
  return outClass
end

"""This functions converts an Absyn.Class to a SCode.Class."""
function translateClass2(inClass::Absyn.Class, inNumMessages::Int)::SCode.Element
  local outClass::SCode.Element
   outClass = begin
    local d_1::SCode.ClassDef
    local r_1::SCode.Restriction
    local c::Absyn.Class
    local n::String
    local p::Bool
    local f::Bool
    local e::Bool
    local r::Absyn.Restriction
    local d::Absyn.ClassDef
    local file_info::SourceInfo
    local scodeClass::SCode.Element
    local sFin::SCode.Final
    local sEnc::SCode.Encapsulated
    local sPar::SCode.Partial
    local cmt::SCode.Comment
    @matchcontinue (inClass, inNumMessages) begin
      (
        c && Absyn.CLASS(
          name = n,
          partialPrefix = p,
          finalPrefix = f,
          encapsulatedPrefix = e,
          restriction = r,
          body = d,
          info = file_info,
        ),
        _,
      ) => begin
         r_1 = translateRestriction(c, r)
         (d_1, cmt) = translateClassdef(d, file_info, r_1)
         sFin = SCodeUtil.boolFinal(f)
         sEnc = SCodeUtil.boolEncapsulated(e)
         sPar = SCodeUtil.boolPartial(p)
         scodeClass = SCode.CLASS(
          n,
          SCode.PREFIXES(
            SCode.PUBLIC(),
            SCode.NOT_REDECLARE(),
            sFin,
            Absyn.NOT_INNER_OUTER(),
            SCode.NOT_REPLACEABLE(),
          ),
          sEnc,
          sPar,
          r_1,
          d_1,
          cmt,
          file_info,
        )
        scodeClass
      end

      (Absyn.CLASS(name = n, info = file_info), _) => begin
        n = "AbsynToSCode.translateClass2 failed: " + n
        @error n
        fail()
      end
    end
  end
  return outClass
end

#= mahge: FIX HERE. Check for proper input and output
=#
"""declarations in operators according to the specifications."""
function translateOperatorDef(
  inClassDef::Absyn.ClassDef,
  operatorName::Absyn.Ident,
  info::SourceInfo,
)::Tuple{SCode.ClassDef, SCode.Comment}
  local cmt::SCode.Comment
  local outOperDef::SCode.ClassDef

   (outOperDef, cmt) = begin
    local cmtString::Option{String}
    local els::List{SCode.Element}
    local anns::List{SCode.Annotation}
    local parts::List{Absyn.ClassPart}
    local scodeCmt::Option{SCode.Comment}
    local opName::SCode.Ident
    local aann::List{Absyn.Annotation}
    local ann::Option{SCode.Annotation}
    @match (inClassDef, operatorName, info) begin
      (Absyn.PARTS(classParts = parts, ann = aann, comment = cmtString), _, _) => begin
         els = translateClassdefElements(parts)
         cmt = translateCommentList(aann, cmtString)
        (SCode.PARTS(els, nil, nil, nil, nil, nil, nil, NONE()), cmt)
      end

      _ => begin
        fail()
      end
    end
  end
  return (outOperDef, cmt)
end

function getOperatorGivenName(inOperatorFunction::SCode.Element)::Absyn.Path
  local outName::Absyn.Path

   outName = begin
    local name::SCode.Ident
    @match inOperatorFunction begin
      SCode.CLASS(name, _, _, _, SCode.R_FUNCTION(SCode.FR_OPERATOR_FUNCTION(__)), _, _, _) => begin
        Absyn.IDENT(name)
      end
    end
  end
  return outName
end

function getOperatorQualName(
  inOperatorFunction::SCode.Element,
  operName::SCode.Ident,
)::SCode.Path
  local outName::SCode.Path

   outName = begin
    local name::SCode.Ident
    local opname::SCode.Ident
    @match (inOperatorFunction, operName) begin
      (SCode.CLASS(name, _, _, _, SCode.R_FUNCTION(_), _, _, _), opname) => begin
        AbsynUtil.joinPaths(Absyn.IDENT(opname), Absyn.IDENT(name))
      end
    end
  end
  return outName
end

function getListofQualOperatorFuncsfromOperator(inOperator::SCode.Element)::List{SCode.Path}
  local outNames::List{SCode.Path}

   outNames = begin
    local els::List{SCode.Element}
    local opername::SCode.Ident
    local names::List{SCode.Path}
    #= If operator get the list of functions in it.
    =#
    @match inOperator begin
      SCode.CLASS(
        opername,
        _,
        _,
        _,
        SCode.R_OPERATOR(__),
        SCode.PARTS(elementLst = els),
        _,
        _,
      ) => begin
         names = ListUtil.map1(els, getOperatorQualName, opername)
        names
      end

      SCode.CLASS(
        opername,
        _,
        _,
        _,
        SCode.R_FUNCTION(SCode.FR_OPERATOR_FUNCTION(__)),
        _,
        _,
        _,
      ) => begin
         names = list(Absyn.IDENT(opername))
        names
      end
    end
  end
  #= If operator function return its name
  =#
  return outNames
end

function translatePurity(inPurity::Absyn.FunctionPurity)::Bool
  local outPurity::Bool

   outPurity = begin
    @match inPurity begin
      Absyn.IMPURE(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return outPurity
end

#=  Changed to public! krsta
=#

"""Convert a class restriction."""
function translateRestriction(
  inClass::Absyn.Class,
  inRestriction::Absyn.Restriction,
)::SCode.Restriction
  local outRestriction::SCode.Restriction

   outRestriction = begin
    local d::Absyn.Class
    local name::Absyn.Path
    local index::Int
    local singleton::Bool
    local isImpure::Bool
    local moved::Bool
    local purity::Absyn.FunctionPurity
    local typeVars::List{String}
    #=  ?? Only normal functions can have 'external'
    =#
    @match (inClass, inRestriction) begin
      (d, Absyn.R_FUNCTION(Absyn.FR_NORMAL_FUNCTION(purity))) => begin
         isImpure = translatePurity(purity)
        if containsExternalFuncDecl(d)
          SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(isImpure))
        else
          SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(isImpure))
        end
      end

      (_, Absyn.R_FUNCTION(Absyn.FR_OPERATOR_FUNCTION(__))) => begin
        SCode.R_FUNCTION(SCode.FR_OPERATOR_FUNCTION())
      end

      (_, Absyn.R_FUNCTION(Absyn.FR_PARALLEL_FUNCTION(__))) => begin
        SCode.R_FUNCTION(SCode.FR_PARALLEL_FUNCTION())
      end

      (_, Absyn.R_FUNCTION(Absyn.FR_KERNEL_FUNCTION(__))) => begin
        SCode.R_FUNCTION(SCode.FR_KERNEL_FUNCTION())
      end

      (_, Absyn.R_CLASS(__)) => begin
        SCode.R_CLASS()
      end

      (_, Absyn.R_OPTIMIZATION(__)) => begin
        SCode.R_OPTIMIZATION()
      end

      (_, Absyn.R_MODEL(__)) => begin
        SCode.R_MODEL()
      end

      (_, Absyn.R_RECORD(__)) => begin
        SCode.R_RECORD(false)
      end

      (_, Absyn.R_OPERATOR_RECORD(__)) => begin
        SCode.R_RECORD(true)
      end

      (_, Absyn.R_BLOCK(__)) => begin
        SCode.R_BLOCK()
      end

      (_, Absyn.R_CONNECTOR(__)) => begin
        SCode.R_CONNECTOR(false)
      end

      (_, Absyn.R_EXP_CONNECTOR(__)) => begin
        System.setHasExpandableConnectors(true)
        SCode.R_CONNECTOR(true)
      end

      (_, Absyn.R_OPERATOR(__)) => begin
        SCode.R_OPERATOR()
      end

      (_, Absyn.R_TYPE(__)) => begin
        SCode.R_TYPE()
      end

      (_, Absyn.R_PACKAGE(__)) => begin
        SCode.R_PACKAGE()
      end

      (_, Absyn.R_ENUMERATION(__)) => begin
        SCode.R_ENUMERATION()
      end

      (_, Absyn.R_PREDEFINED_INTEGER(__)) => begin
        SCode.R_PREDEFINED_INTEGER()
      end

      (_, Absyn.R_PREDEFINED_REAL(__)) => begin
        SCode.R_PREDEFINED_REAL()
      end

      (_, Absyn.R_PREDEFINED_STRING(__)) => begin
        SCode.R_PREDEFINED_STRING()
      end

      (_, Absyn.R_PREDEFINED_BOOLEAN(__)) => begin
        SCode.R_PREDEFINED_BOOLEAN()
      end

      (_, Absyn.R_PREDEFINED_CLOCK(__)) => begin
        SCode.R_PREDEFINED_CLOCK()
      end

      (_, Absyn.R_PREDEFINED_ENUMERATION(__)) => begin
        SCode.R_PREDEFINED_ENUMERATION()
      end

      (_, Absyn.R_METARECORD(name, index, singleton, moved, typeVars)) => begin
        SCode.R_METARECORD(name, index, singleton, moved, typeVars)
      end

      (Absyn.CLASS(body = Absyn.PARTS(typeVars = typeVars)), Absyn.R_UNIONTYPE(__)) =>
        begin
          SCode.R_UNIONTYPE(typeVars)
        end

      (_, Absyn.R_UNIONTYPE(__)) => begin
        SCode.R_UNIONTYPE(nil)
      end
    end
  end
  #=  BTH
  =#
  #= MetaModelica extension, added by x07simbj
  =#
  #= /*MetaModelica extension added by x07simbj */ =#
  #= /*MetaModelica extension added by x07simbj */ =#
  return outRestriction
end

"""Returns true if the Absyn.Class contains an external function declaration."""
function containsExternalFuncDecl(inClass::Absyn.Class)::Bool
  local outBoolean::Bool

   outBoolean = begin
    local res::Bool
    local b::Bool
    local c::Bool
    local d::Bool
    local a::String
    local e::Absyn.Restriction
    local rest::List{Absyn.ClassPart}
    local cmt::Option{String}
    local file_info::SourceInfo
    local ann::List{Absyn.Annotation}
    @match inClass begin
      Absyn.CLASS(body = Absyn.PARTS(classParts = Absyn.EXTERNAL(__) <| _)) => begin
        true
      end

      Absyn.CLASS(
        name = a,
        partialPrefix = b,
        finalPrefix = c,
        encapsulatedPrefix = d,
        restriction = e,
        body = Absyn.PARTS(classParts = _ <| rest, comment = cmt, ann = ann),
        info = file_info,
      ) => begin
        containsExternalFuncDecl(Absyn.CLASS(
          a,
          b,
          c,
          d,
          e,
          Absyn.PARTS(nil, nil, rest, ann, cmt),
          file_info,
        ))
      end

      Absyn.CLASS(body = Absyn.CLASS_EXTENDS(parts = Absyn.EXTERNAL(__) <| _)) => begin
        true
      end

      Absyn.CLASS(
        name = a,
        partialPrefix = b,
        finalPrefix = c,
        encapsulatedPrefix = d,
        restriction = e,
        body = Absyn.CLASS_EXTENDS(parts = _ <| rest, comment = cmt, ann = ann),
        info = file_info,
      ) => begin
        containsExternalFuncDecl(Absyn.CLASS(
          a,
          b,
          c,
          d,
          e,
          Absyn.PARTS(nil, nil, rest, ann, cmt),
          file_info,
        ))
      end

      _ => begin
        false
      end
    end
  end
  #= /* adrpo: handling also the case model extends X external ... end X; */ =#
  #= /* adrpo: handling also the case model extends X external ... end X; */ =#
  return outBoolean
end

""" @author: adrpo
    translates from Absyn.ElementAttributes to SCode.Attributes
"""
function translateAttributes(
  inEA::Absyn.ElementAttributes,
  extraArrayDim::List{<:Absyn.Subscript},
  )::SCode.Attributes
  local outA::SCode.Attributes
   outA = begin
    local f::Bool
    local s::Bool
    local v::Absyn.Variability
    local p::Absyn.Parallelism
    local adim::Absyn.ArrayDim
    local extraADim::Absyn.ArrayDim
    local dir::Absyn.Direction
    local fi::Absyn.IsField
    local ct::SCode.ConnectorType
    local sp::SCode.Parallelism
     local sv::SCode.Variability
    @match (inEA, extraArrayDim) begin
      (Absyn.ATTR(f, s, p, v, dir, fi, adim, mo), extraADim) => begin
        ct = translateConnectorType(f, s)
        sv = translateVariability(v)
        sp = translateParallelism(p)
        adim = listAppend(extraADim, adim)
        #@debug "Value of mode in translate Attributes" mo
        SCode.ATTR(adim, ct, sp, sv, dir, fi, mo)
      end
    end
  end
  return outA
end

function translateConnectorType(inFlow::Bool, inStream::Bool)::SCode.ConnectorType
  local outType::SCode.ConnectorType

   outType = begin
    @match (inFlow, inStream) begin
      (false, false) => begin
        SCode.POTENTIAL()
      end

      (true, false) => begin
        SCode.FLOW()
      end

      (false, true) => begin
        SCode.STREAM()
      end

      (true, true) => begin
        #=  Both flow and stream is not allowed by the grammar, so this shouldn't be  possible. =#
        fail()
      end
    end
  end
  return outType
end

"""
  This function converts an Absyn.ClassDef to a SCode.ClassDef.
  For the DERIVED case, the conversion is fairly trivial, but for
  the PARTS case more work is needed.
  The result contains separate lists for:
  elements, equations and algorithms, which are mixed in the input.
  LS: Divided the translateClassdef into separate functions for collecting the different parts
"""
function translateClassdef(
  inClassDef::Absyn.ClassDef,
  info::SourceInfo,
  re::SCode.Restriction,
)::Tuple{SCode.ClassDef, SCode.Comment}
  local outComment::SCode.Comment
  local outClassDef::SCode.ClassDef

   (outClassDef, outComment) = begin
    local mod::SCode.Mod
    local t::Absyn.TypeSpec
    local attr::Absyn.ElementAttributes
    local a::List{Absyn.ElementArg}
    local cmod::List{Absyn.ElementArg}
    local cmt::Option{Absyn.Comment}
    local cmtString::Option{String}
    local els::List{SCode.Element}
    local tvels::List{SCode.Element}
    local anns::List{SCode.Annotation}
    local eqs::List{SCode.Equation}
    local initeqs::List{SCode.Equation}
    local als::List{SCode.AlgorithmSection}
    local initals::List{SCode.AlgorithmSection}
    local cos::List{SCode.ConstraintSection}
    local decl::Option{SCode.ExternalDecl}
    local parts::List{Absyn.ClassPart}
    local vars::List{String}
    local lst_1::List{SCode.Enum}
    local lst::List{Absyn.EnumLiteral}
    local scodeCmt::SCode.Comment
    local path::Absyn.Path
    local pathLst::List{Absyn.Path}
    local typeVars::List{String}
    local scodeAttr::SCode.Attributes
    local classAttrs::List{Absyn.NamedArg}
    local ann::List{Absyn.Annotation}
    @match (inClassDef, info) begin
      (Absyn.DERIVED(typeSpec = t, attributes = attr, arguments = a, comment = cmt), _) =>
        begin
          checkTypeSpec(t, info)
           mod = translateMod(
            SOME(Absyn.CLASSMOD(a, Absyn.NOMOD())),
            SCode.NOT_FINAL(),
            SCode.NOT_EACH(),
            info,
          ) #= TODO: attributes of derived classes =#
           scodeAttr = translateAttributes(attr, nil)
           scodeCmt = translateComment(cmt)
          (SCode.DERIVED(t, mod, scodeAttr), scodeCmt)
        end

      (
        Absyn.PARTS(
          typeVars = typeVars,
          classAttrs = classAttrs,
          classParts = parts,
          ann = ann,
          comment = cmtString,
        ),
        _,
      ) => begin
         typeVars = begin
          @match re begin
            SCode.R_METARECORD(__) => begin
              ListUtil.union(typeVars, re.typeVars)
            end

            SCode.R_UNIONTYPE(__) => begin
              ListUtil.union(typeVars, re.typeVars)
            end

            _ => begin
              typeVars
            end
          end
        end
         tvels = ListUtil.map1(typeVars, makeTypeVarElement, info)
         els = translateClassdefElements(parts)
         els = listAppend(tvels, els)
         eqs = translateClassdefEquations(parts)
         initeqs = translateClassdefInitialequations(parts)
         als = translateClassdefAlgorithms(parts)
         initals = translateClassdefInitialalgorithms(parts)
         cos = translateClassdefConstraints(parts)
         scodeCmt = translateCommentList(ann, cmtString)
         decl = translateClassdefExternaldecls(parts)
         decl = translateAlternativeExternalAnnotation(decl, scodeCmt)
        (SCode.PARTS(els, eqs, initeqs, als, initals, cos, classAttrs, decl), scodeCmt)
      end

      (Absyn.ENUMERATION(Absyn.ENUMLITERALS(enumLiterals = lst), cmt), _) => begin
         lst_1 = translateEnumlist(lst)
         scodeCmt = translateComment(cmt)
        (SCode.ENUMERATION(lst_1), scodeCmt)
      end

      (Absyn.ENUMERATION(Absyn.ENUM_COLON(__), cmt), _) => begin
         scodeCmt = translateComment(cmt)
        (SCode.ENUMERATION(nil), scodeCmt)
      end

      (Absyn.OVERLOAD(pathLst, cmt), _) => begin
         scodeCmt = translateComment(cmt)
        (SCode.OVERLOAD(pathLst), scodeCmt)
      end

      (
        Absyn.CLASS_EXTENDS(
          modifications = cmod,
          ann = ann,
          comment = cmtString,
          parts = parts,
        ),
        _,
      ) => begin
         els = translateClassdefElements(parts)
         eqs = translateClassdefEquations(parts)
         initeqs = translateClassdefInitialequations(parts)
         als = translateClassdefAlgorithms(parts)
         initals = translateClassdefInitialalgorithms(parts)
         cos = translateClassdefConstraints(parts)
         mod = translateMod(
          SOME(Absyn.CLASSMOD(cmod, Absyn.NOMOD())),
          SCode.NOT_FINAL(),
          SCode.NOT_EACH(),
          AbsynUtil.dummyInfo,
        )
         scodeCmt = translateCommentList(ann, cmtString)
         decl = translateClassdefExternaldecls(parts)
         decl = translateAlternativeExternalAnnotation(decl, scodeCmt)
        (
          SCode.CLASS_EXTENDS(
            mod,
            SCode.PARTS(els, eqs, initeqs, als, initals, cos, nil, decl),
          ),
          scodeCmt,
        )
      end

      (Absyn.PDER(functionName = path, vars = vars, comment = cmt), _) => begin
         scodeCmt = translateComment(cmt)
        (SCode.PDER(path, vars), scodeCmt)
      end

      _ => begin
        fail()
      end
    end
  end
  return (outClassDef, outComment)
end

"""
  first class annotation instead, since it is very common that an element
  annotation is used for this purpose.
  For instance, instead of external \\\"C\\\" annotation(Library=\\\"foo.lib\\\";
  it says external \\\"C\\\" ; annotation(Library=\\\"foo.lib\\\";
"""
function translateAlternativeExternalAnnotation(
  decl::Option{<:SCode.ExternalDecl},
  comment::SCode.Comment,
)::Option{SCode.ExternalDecl}
  local outDecl::Option{SCode.ExternalDecl}

   outDecl = begin
    local name::Option{SCode.Ident}
    local l::Option{String}
    local out::Option{Absyn.ComponentRef}
    local a::List{Absyn.Exp}
    local ann1::Option{SCode.Annotation}
    local ann2::Option{SCode.Annotation}
    local ann::Option{SCode.Annotation}
    #=  none
    =#
    @match (decl, comment) begin
      (NONE(), _) => begin
        NONE()
      end

      (
        SOME(SCode.EXTERNALDECL(name, l, out, a, ann1)),
        SCode.COMMENT(annotation_ = ann2),
      ) => begin
         ann = SCodeUtil.mergeSCodeOptAnn(ann1, ann2)
        SOME(SCode.EXTERNALDECL(name, l, out, a, ann))
      end
    end
  end
  #=  Else, merge =#
  return outDecl
end

function mergeSCodeAnnotationsFromParts(
  part::Absyn.ClassPart,
  inMod::Option{<:SCode.Annotation},
)::Option{SCode.Annotation}
  local outMod::Option{SCode.Annotation}

   outMod = begin
    local aann::Absyn.Annotation
    local ann::Option{SCode.Annotation}
    local rest::List{Absyn.ElementItem}
    @match (part, inMod) begin
      (Absyn.EXTERNAL(_, SOME(aann)), _) => begin
         ann = translateAnnotation(aann)
         ann = SCodeUtil.mergeSCodeOptAnn(ann, inMod)
        ann
      end

      (Absyn.PUBLIC(_ <| rest), _) => begin
        mergeSCodeAnnotationsFromParts(Absyn.PUBLIC(rest), inMod)
      end

      (Absyn.PROTECTED(_ <| rest), _) => begin
        mergeSCodeAnnotationsFromParts(Absyn.PROTECTED(rest), inMod)
      end

      _ => begin
        inMod
      end
    end
  end
  return outMod
end

"""
  Convert an EnumLiteral list to an Ident list.
  Comments are lost.
"""
function translateEnumlist(
  inAbsynEnumLiteralLst::List{<:Absyn.EnumLiteral},
)::List{SCode.Enum}
  local outEnumLst::List{SCode.Enum}

   outEnumLst = begin
    local res::List{SCode.Enum}
    local id::String
    local cmtOpt::Option{Absyn.Comment}
    local cmt::SCode.Comment
    local rest::List{Absyn.EnumLiteral}
    @match inAbsynEnumLiteralLst begin
      nil() => begin
        nil
      end

      Absyn.ENUMLITERAL(id, cmtOpt) <| rest => begin
         cmt = translateComment(cmtOpt)
         res = translateEnumlist(rest)
        _cons(SCode.ENUM(id, cmt), res)
      end
    end
  end
  return outEnumLst
end

"""Convert an Absyn.ClassPart list to an Element list."""
function translateClassdefElements(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.Element}
  local outElementLst::List{SCode.Element}

   outElementLst = begin
    local els::List{SCode.Element}
    local es_1::List{SCode.Element}
    local els_1::List{SCode.Element}
    local es::List{Absyn.ElementItem}
    local rest::List{Absyn.ClassPart}
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.PUBLIC(contents = es) <| rest => begin
         es_1 = translateEitemlist(es, SCode.PUBLIC())
         els = translateClassdefElements(rest)
         els = listAppend(es_1, els)
        els
      end

      Absyn.PROTECTED(contents = es) <| rest => begin
         es_1 = translateEitemlist(es, SCode.PROTECTED())
         els = translateClassdefElements(rest)
         els = listAppend(es_1, els)
        els
      end

      _ <| rest => begin
        translateClassdefElements(rest)
      end
    end
  end
  #= /* ignore all other than PUBLIC and PROTECTED, i.e. elements */ =#
  return outElementLst
end

"""Convert an Absyn.ClassPart list to an Equation list."""
function translateClassdefEquations(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.Equation}
  local outEquationLst::List{SCode.Equation}

   outEquationLst = begin
    local eqs::List{SCode.Equation}
    local eql_1::List{SCode.Equation}
    local eqs_1::List{SCode.Equation}
    local eql::List{Absyn.EquationItem}
    local rest::List{Absyn.ClassPart}
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.EQUATIONS(contents = eql) <| rest => begin
         eql_1 = translateEquations(eql, false)
         eqs = translateClassdefEquations(rest)
         eqs_1 = listAppend(eqs, eql_1)
        eqs_1
      end

      _ <| rest => begin
         eqs = translateClassdefEquations(rest)
        eqs
      end
    end
  end
  #= /* ignore everthing other than equations */ =#
  return outEquationLst
end

"""Convert an Absyn.ClassPart list to an initial Equation list."""
function translateClassdefInitialequations(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.Equation}
  local outEquationLst::List{SCode.Equation}

   outEquationLst = begin
    local eqs::List{SCode.Equation}
    local eql_1::List{SCode.Equation}
    local eqs_1::List{SCode.Equation}
    local eql::List{Absyn.EquationItem}
    local rest::List{Absyn.ClassPart}
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.INITIALEQUATIONS(contents = eql) <| rest => begin
         eql_1 = translateEquations(eql, true)
         eqs = translateClassdefInitialequations(rest)
         eqs_1 = listAppend(eqs, eql_1)
        eqs_1
      end

      _ <| rest => begin
         eqs = translateClassdefInitialequations(rest)
        eqs
      end
    end
  end
  #= /* ignore everthing other than equations */ =#
  return outEquationLst
end

"""Convert an Absyn.ClassPart list to an Algorithm list."""
function translateClassdefAlgorithms(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.AlgorithmSection}
  local outAlgorithmLst::List{SCode.AlgorithmSection}

   outAlgorithmLst = begin
    local als::List{SCode.AlgorithmSection}
    local als_1::List{SCode.AlgorithmSection}
    local al_1::List{SCode.Statement}
    local al::List{Absyn.AlgorithmItem}
    local rest::List{Absyn.ClassPart}
    local cp::Absyn.ClassPart
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.ALGORITHMS(contents = al) <| rest => begin
         al_1 = translateClassdefAlgorithmitems(al)
         als = translateClassdefAlgorithms(rest)
         als_1 = _cons(SCode.ALGORITHM(al_1), als)
        als_1
      end

      cp <| rest => begin
         als = translateClassdefAlgorithms(rest)
        als
      end

      _ => begin
        fail()
      end
    end
  end
  #= /* ignore everthing other than algorithms */ =#
  return outAlgorithmLst
end

"""Convert an Absyn.ClassPart list to an Constraint list."""
function translateClassdefConstraints(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.ConstraintSection}
  local outConstraintLst::List{SCode.ConstraintSection}

   outConstraintLst = begin
    local cos::List{SCode.ConstraintSection}
    local cos_1::List{SCode.ConstraintSection}
    local consts::List{Absyn.Exp}
    local rest::List{Absyn.ClassPart}
    local cp::Absyn.ClassPart
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.CONSTRAINTS(contents = consts) <| rest => begin
         cos = translateClassdefConstraints(rest)
         cos_1 = _cons(SCode.CONSTRAINTS(consts), cos)
        cos_1
      end

      cp <| rest => begin
         cos = translateClassdefConstraints(rest)
        cos
      end

      _ => begin
        fail()
      end
    end
  end
  #= /* ignore everthing other than Constraints */ =#
  return outConstraintLst
end

"""Convert an Absyn.ClassPart list to an initial Algorithm list."""
function translateClassdefInitialalgorithms(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::List{SCode.AlgorithmSection}
  local outAlgorithmLst::List{SCode.AlgorithmSection}

   outAlgorithmLst = begin
    local als::List{SCode.AlgorithmSection}
    local als_1::List{SCode.AlgorithmSection}
    local stmts::List{SCode.Statement}
    local al::List{Absyn.AlgorithmItem}
    local rest::List{Absyn.ClassPart}
    @match inAbsynClassPartLst begin
      nil() => begin
        nil
      end

      Absyn.INITIALALGORITHMS(contents = al) <| rest => begin
         stmts = translateClassdefAlgorithmitems(al)
         als = translateClassdefInitialalgorithms(rest)
         als_1 = _cons(SCode.ALGORITHM(stmts), als)
        als_1
      end

      _ <| rest => begin
         als = translateClassdefInitialalgorithms(rest)
        als
      end
    end
  end
  #= /* ignore everthing other than algorithms */ =#
  return outAlgorithmLst
end

function translateClassdefAlgorithmitems(
  inStatements::List{<:Absyn.AlgorithmItem},
)::List{SCode.Statement}
  local outStatements::List{SCode.Statement}

   outStatements = list(
    translateClassdefAlgorithmItem(stmt)
    for stmt in inStatements if AbsynUtil.isAlgorithmItem(stmt)
  )
  return outStatements
end

"""Translates an Absyn algorithm (statement) into SCode statement."""
function translateClassdefAlgorithmItem(inAlgorithm::Absyn.AlgorithmItem)::SCode.Statement
  local outStatement::SCode.Statement

  local absynComment::Option{Absyn.Comment}
  local comment::SCode.Comment
  local info::SourceInfo
  local alg::Absyn.Algorithm

  @match Absyn.ALGORITHMITEM(algorithm_ = alg, comment = absynComment, info = info) =
    inAlgorithm
   (comment, info) = translateCommentWithLineInfoChanges(absynComment, info)
   outStatement = begin
    local body::List{SCode.Statement}
    local else_body::List{SCode.Statement}
    local branches::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
    local iter_name::String
    local iter_range::Option{Absyn.Exp}
    local stmt::SCode.Statement
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local e3::Absyn.Exp
    local cr::Absyn.ComponentRef
    @match alg begin
      Absyn.ALG_ASSIGN(__) => begin
        SCode.ALG_ASSIGN(alg.assignComponent, alg.value, comment, info)
      end

      Absyn.ALG_IF(__) => begin
         body = translateClassdefAlgorithmitems(alg.trueBranch)
         else_body = translateClassdefAlgorithmitems(alg.elseBranch)
         branches = translateAlgBranches(alg.elseIfAlgorithmBranch)
        SCode.ALG_IF(alg.ifExp, body, branches, else_body, comment, info)
      end

      Absyn.ALG_FOR(__) => begin
         body = translateClassdefAlgorithmitems(alg.forBody)
        #=  Convert for-loops with multiple iterators into nested for-loops.
        =#
        for i in listReverse(alg.iterators)
           (iter_name, iter_range) = translateIterator(i, info)
           body = list(SCode.ALG_FOR(iter_name, iter_range, body, comment, info))
        end
        listHead(body)
      end

      Absyn.ALG_PARFOR(__) => begin
         body = translateClassdefAlgorithmitems(alg.parforBody)
        #=  Convert for-loops with multiple iterators into nested for-loops.
        =#
        for i in listReverse(alg.iterators)
           (iter_name, iter_range) = translateIterator(i, info)
           body =
            list(SCode.ALG_PARFOR(iter_name, iter_range, body, comment, info))
        end
        listHead(body)
      end

      Absyn.ALG_WHILE(__) => begin
         body = translateClassdefAlgorithmitems(alg.whileBody)
        SCode.ALG_WHILE(alg.boolExpr, body, comment, info)
      end

      Absyn.ALG_WHEN_A(__) => begin
         branches = translateAlgBranches(_cons(
          (alg.boolExpr, alg.whenBody),
          alg.elseWhenAlgorithmBranch,
        ))
        SCode.ALG_WHEN_A(branches, comment, info)
      end

      Absyn.ALG_NORETCALL(
        functionCall = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| nil(), argNames = nil()),
      ) => begin
        SCode.ALG_ASSERT(e1, e2, ASSERTION_LEVEL_ERROR, comment, info)
      end

      Absyn.ALG_NORETCALL(
        functionCall = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| e3 <| nil(), argNames = nil()),
      ) => begin
        SCode.ALG_ASSERT(e1, e2, e3, comment, info)
      end

      Absyn.ALG_NORETCALL(
        functionCall = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(
          args = e1 <| e2 <| nil(),
          argNames = Absyn.NAMEDARG("level", e3) <| nil(),
        ),
      ) => begin
        SCode.ALG_ASSERT(e1, e2, e3, comment, info)
      end

      Absyn.ALG_NORETCALL(
        functionCall = Absyn.CREF_IDENT(name = "terminate"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| nil(), argNames = nil()),
      ) => begin
        SCode.ALG_TERMINATE(e1, comment, info)
      end

      Absyn.ALG_NORETCALL(
        functionCall = Absyn.CREF_IDENT(name = "reinit"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| nil(), argNames = nil()),
      ) => begin
        SCode.ALG_REINIT(e1, e2, comment, info)
      end

      Absyn.ALG_NORETCALL(__) => begin
        #=  assert(condition, message)
        =#
        #=  assert(condition, message, level)
        =#
        #=  assert(condition, message, level = arg)
        =#
         e1 = Absyn.CALL(alg.functionCall, alg.functionArgs, nil)
        SCode.ALG_NORETCALL(e1, comment, info)
      end

      Absyn.ALG_FAILURE(__) => begin
         body = translateClassdefAlgorithmitems(alg.equ)
        SCode.ALG_FAILURE(body, comment, info)
      end

      Absyn.ALG_TRY(__) => begin
         body = translateClassdefAlgorithmitems(alg.body)
         else_body = translateClassdefAlgorithmitems(alg.elseBody)
        SCode.ALG_TRY(body, else_body, comment, info)
      end

      Absyn.ALG_RETURN(__) => begin
        SCode.ALG_RETURN(comment, info)
      end

      Absyn.ALG_BREAK(__) => begin
        SCode.ALG_BREAK(comment, info)
      end

      Absyn.ALG_CONTINUE(__) => begin
        SCode.ALG_CONTINUE(comment, info)
      end
    end
  end
  return outStatement
end

"""Translates the elseif or elsewhen branches from Absyn to SCode form."""
function translateAlgBranches(
  inBranches::List{<:Tuple{<:Absyn.Exp, List{<:Absyn.AlgorithmItem}}},
)::List{Tuple{Absyn.Exp, List{SCode.Statement}}}
  local outBranches::List{Tuple{Absyn.Exp, List{SCode.Statement}}}

  local condition::Absyn.Exp
  local body::List{Absyn.AlgorithmItem}

   outBranches = list(
    begin
      @match branch begin
        (condition, body) => begin
          (condition, translateClassdefAlgorithmitems(body))
        end
      end
    end for branch in inBranches
  )
  return outBranches
end

"""
  Converts an Absyn.ClassPart list to an SCode.ExternalDecl option.
  The list should only contain one external declaration, so pick the first one.
"""
function translateClassdefExternaldecls(
  inAbsynClassPartLst::List{<:Absyn.ClassPart},
)::Option{SCode.ExternalDecl}
  local outAbsynExternalDeclOption::Option{SCode.ExternalDecl}

   outAbsynExternalDeclOption = begin
    local res::Option{SCode.ExternalDecl}
    local rest::List{Absyn.ClassPart}
    local fn_name::Option{SCode.Ident}
    local lang::Option{String}
    local output_::Option{Absyn.ComponentRef}
    local args::List{Absyn.Exp}
    local aann::Option{Absyn.Annotation}
    local sann::Option{SCode.Annotation}
    @match inAbsynClassPartLst begin
      Absyn.EXTERNAL(externalDecl = Absyn.EXTERNALDECL(fn_name, lang, output_, args, aann)) <| _ => begin
         sann = translateAnnotationOpt(aann)
        SOME(SCode.EXTERNALDECL(fn_name, lang, output_, args, sann))
      end

      _ <| rest => begin
         res = translateClassdefExternaldecls(rest)
        res
      end

      nil() => begin
        NONE()
      end
    end
  end
  return outAbsynExternalDeclOption
end

#=
  Minimum number of `Absyn.ElementItem`s in a single `translateEitemlist`
  call before the parallel branch is considered. Below this threshold the
  per-task spawn overhead dominates per-element work. Tuned empirically
  against the MSL on an 8-thread machine; raise for fewer cores, lower for
  heavier per-element work.
=#
const NF_PARALLEL_EITEM_THRESHOLD = 8

"""
  This function converts a list of Absyn.ElementItem to a list of SCode.Element.
  The boolean argument flags whether the elements are protected.
  Annotations are not translated, i.e. they are removed when converting to SCode.
"""
function translateEitemlist(
  inAbsynElementItemLst::List{<:Absyn.ElementItem},
  inVisibility::SCode.Visibility,
)::List{SCode.Element}
  # The AbsynToSCode parallel branch is proven race-free (each task produces a
  # self-contained `SCode.Element` and the only shared writes are idempotent
  # ratchet-to-true flags in `GLOBAL_MEMORY`). It is therefore unconditionally
  # enabled — gated only by thread count and the per-task threshold. The
  # `Flags.NF_PARALLEL` debug flag is reserved for opt-in parallelism in
  # later phases (instantiate, etc.) where correctness is not yet proven.
  if Threads.nthreads() >= 2
    local arr::Vector{Absyn.ElementItem} = listArray(inAbsynElementItemLst)
    if length(arr) >= NF_PARALLEL_EITEM_THRESHOLD
      return translateEitemlistParallel(arr, inVisibility)
    end
  end
  return translateEitemlistSerial(inAbsynElementItemLst, inVisibility)
end

function translateEitemlistSerial(
  inAbsynElementItemLst::List{<:Absyn.ElementItem},
  inVisibility::SCode.Visibility,
)::List{SCode.Element}
  local outElementLst::List{SCode.Element}

  local l::List{SCode.Element} = nil
  local es::List{Absyn.ElementItem} = inAbsynElementItemLst
  local ei::Absyn.ElementItem
  local e::Absyn.Element

  for ei in es
     _ = begin
      local e_1::List{SCode.Element}
      @match ei begin
        Absyn.ELEMENTITEM(element = e) => begin
           e_1 = translateElement(e, inVisibility)
           l = ListUtil.append_reverse(e_1, l)
          ()
        end

        _ => begin
          ()
        end
      end
    end
  end

   outElementLst = listReverse(l)
  return outElementLst
end

"""
  Parallel translation of a class element-item list. One task per item,
  results merged in input order.

  Each `translateElement` call produces a self-contained `List{SCode.Element}`
  with no read of shared mutable state. The only writes are the ratchet-to-true
  updates in `System.setHas*` (`Util/System.jl`), which are idempotent and safe
  under concurrent stores.

  Nested `translateEitemlist` calls (when an element is itself a class
  definition with its own element list) re-enter the same dispatcher and
  re-decide based on the threshold. Julia's task scheduler queues nested
  spawns and runs them as threads become available; the parallelism is bounded
  by `Threads.nthreads()`, not by the recursion depth.
"""
function translateEitemlistParallel(
  arr::Vector{<:Absyn.ElementItem},
  inVisibility::SCode.Visibility,
)::List{SCode.Element}
  local n::Int = length(arr)
  local results::Vector{List{SCode.Element}} = Vector{List{SCode.Element}}(undef, n)
  @sync begin
    for i in 1:n
      local ei = arr[i]
      Threads.@spawn results[i] = translateOneEitem(ei, inVisibility)
    end
  end
  # Concatenate in input order. listAppend is left-biased, so build right-to-left.
  local out::List{SCode.Element} = nil
  for i in n:-1:1
    out = listAppend(results[i], out)
  end
  return out
end

function translateOneEitem(
  ei::Absyn.ElementItem,
  inVisibility::SCode.Visibility,
)::List{SCode.Element}
  return @match ei begin
    Absyn.ELEMENTITEM(element = e) => translateElement(e, inVisibility)
    _ => nil
  end
end

#=  stefan
=#

"""translates an Absyn.Annotation into an SCode.Annotation"""
function translateAnnotation(inAnnotation::Absyn.Annotation)::Option{SCode.Annotation}
  local outAnnotation::Option{SCode.Annotation}

   outAnnotation = begin
    local args::List{Absyn.ElementArg}
    local m::SCode.Mod
    @match inAnnotation begin
      Absyn.ANNOTATION(elementArgs = nil()) => begin
        NONE()
      end

      Absyn.ANNOTATION(elementArgs = args) => begin
         m = translateMod(
          SOME(Absyn.CLASSMOD(args, Absyn.NOMOD())),
          SCode.NOT_FINAL(),
          SCode.NOT_EACH(),
          AbsynUtil.dummyInfo,
        )
        if SCodeUtil.isEmptyMod(m)
          NONE()
        else
          SOME(SCode.ANNOTATION(m))
        end
      end
    end
  end
  return outAnnotation
end

function translateAnnotationOpt(
  absynAnnotation::Option{<:Absyn.Annotation},
)::Option{SCode.Annotation}
  local scodeAnnotation::Option{SCode.Annotation}

   scodeAnnotation = begin
    local ann::Absyn.Annotation
    @match absynAnnotation begin
      SOME(ann) => begin
        translateAnnotation(ann)
      end

      _ => begin
        NONE()
      end
    end
  end
  return scodeAnnotation
end

"""
  This function converts an Absyn.Element to a list of SCode.Element.
  The original element may declare several components at once, and
  those are separated to several declarations in the result.
"""
function translateElement(
  inElement::Absyn.Element,
  inVisibility::SCode.Visibility,
)::List{SCode.Element}
  local outElementLst::List{SCode.Element}

   outElementLst = begin
    local es::List{SCode.Element}
    local f::Bool
    local repl::Option{Absyn.RedeclareKeywords}
    local s::Absyn.ElementSpec
    local io::Absyn.InnerOuter
    local info::SourceInfo
    local cc::Option{Absyn.ConstrainClass}
    local expOpt::Option{String}
    local weightOpt::Option{AbstractFloat}
    local args::List{Absyn.NamedArg}
    local name::String
    local vis::SCode.Visibility
    @match (inElement, inVisibility) begin
      (
        Absyn.ELEMENT(
          constrainClass = cc,
          finalPrefix = f,
          innerOuter = io,
          redeclareKeywords = repl,
          specification = s,
          info = info,
        ),
        vis,
      ) => begin
         es = translateElementspec(cc, f, io, repl, vis, s, info)
        es
      end

      (Absyn.DEFINEUNIT(name, args, info), vis) => begin
         expOpt = translateDefineunitParam(args, "exp")
         weightOpt = translateDefineunitParam2(args, "weight")
        list(SCode.DEFINEUNIT(name, vis, expOpt, weightOpt, info))
      end
      _ => fail()
    end
  end
  return outElementLst
end

"""help function to translateElement"""
function translateDefineunitParam(
  inArgs::List{<:Absyn.NamedArg},
  inArg::String,
)::Option{String}
  local expOpt::Option{String}

   expOpt = begin
    local str::String
    local name::String
    local arg::String
    local args::List{Absyn.NamedArg}
    @match (inArgs, inArg) begin
      (Absyn.NAMEDARG(name, Absyn.STRING(str)) <| _, arg) where {(name == arg)} => begin
        SOME(str)
      end

      (nil(), _) => begin
        NONE()
      end

      (_ <| args, arg) => begin
        translateDefineunitParam(args, arg)
      end
    end
  end
  return expOpt
end

"""help function to translateElement"""
function translateDefineunitParam2(
  inArgs::List{<:Absyn.NamedArg},
  inArg::String,
)::Option{AbstractFloat}
  local weightOpt::Option{AbstractFloat}

   weightOpt = begin
    local name::String
    local arg::String
    local s::String
    local r::AbstractFloat
    local args::List{Absyn.NamedArg}
    @match (inArgs, inArg) begin
      (Absyn.NAMEDARG(name, Absyn.REAL(s)) <| _, arg) where {(name == arg)} => begin
         r = System.stringReal(s)
        SOME(r)
      end

      (nil(), _) => begin
        NONE()
      end

      (_ <| args, arg) => begin
        translateDefineunitParam2(args, arg)
      end
    end
  end
  return weightOpt
end

"""
    This function turns an Absyn.ElementSpec to a list of SCode.Element.
    The boolean arguments say if the element is final and protected, respectively.
"""
function translateElementspec(
  cc::Option{<:Absyn.ConstrainClass},
  finalPrefix::Bool,
  io::Absyn.InnerOuter,
  inRedeclareKeywords::Option{<:Absyn.RedeclareKeywords},
  inVisibility::SCode.Visibility,
  inElementSpec4::Absyn.ElementSpec,
  inInfo::SourceInfo,
)::List{SCode.Element}
  local outElementLst::List{SCode.Element}

   outElementLst = begin
    local absann::Absyn.Annotation
    local ad::List{SCode.Subscript}
    local ann::Option{SCode.Annotation}
    local args::List{Absyn.ElementArg}
    local attr::Absyn.ElementAttributes
    local cl::Absyn.Class
    local cls::SCode.Element
    local cmt::SCode.Comment
    local comment::Option{Absyn.Comment}
    local cond::Option{Absyn.Exp}
    local ct::SCode.ConnectorType
    local d::List{SCode.Subscript}
    local de::Absyn.ClassDef
    local de_1::SCode.ClassDef
    local di::Absyn.Direction
    local e::Bool
    local fi::Bool
    local fl::Bool
    local i::SourceInfo
    local imp::Absyn.Import
    local info::SourceInfo
    local isf::Absyn.IsField
    local m::Option{Absyn.Modification}
    local mod::SCode.Mod
    local md::Bool
    local n::String
    local pa::Bool
    local parallelism::Absyn.Parallelism
    local path::Absyn.Path
    local prefixes::SCode.Prefixes
    local prl1::SCode.Parallelism
    local re::Absyn.Restriction
    local re_1::SCode.Restriction
    local redecl::Bool
    local repl::Option{Absyn.RedeclareKeywords}
    local repl_1::Bool
    local rp::Bool
    local sEnc::SCode.Encapsulated
    local sFin::SCode.Final
    local sPar::SCode.Partial
    local sRed::SCode.Redeclare
    local sRep::SCode.Replaceable
    local scc::Option{SCode.ConstrainClass}
    local st::Bool
    local t::Absyn.TypeSpec
    local tot_dim::List{SCode.Subscript}
    local var1::SCode.Variability
    local variability::Absyn.Variability
    local vis::SCode.Visibility
    local xs::List{Absyn.ComponentItem}
    local xs_1::List{SCode.Element}
    @match (cc, finalPrefix, io, inRedeclareKeywords, inVisibility, inElementSpec4, inInfo) begin
      (
        _,
        _,
        _,
        repl,
        vis,
        Absyn.CLASSDEF(
          replaceable_ = rp,
          class_ = Absyn.CLASS(
            name = n,
            partialPrefix = pa,
            encapsulatedPrefix = e,
            restriction = Absyn.R_OPERATOR(__),
            body = de,
            info = i,
          ),
        ),
        _,
      ) => begin
         (de_1, cmt) = translateOperatorDef(de, n, i)
         (_, redecl) = translateRedeclarekeywords(repl)
         sRed = SCodeUtil.boolRedeclare(redecl)
         sFin = SCodeUtil.boolFinal(finalPrefix)
         scc = translateConstrainClass(cc)
         sRep = if rp
          SCode.REPLACEABLE(scc)
        else
          SCode.NOT_REPLACEABLE()
        end
         sEnc = SCodeUtil.boolEncapsulated(e)
         sPar = SCodeUtil.boolPartial(pa)
         cls = SCode.CLASS(
          n,
          SCode.PREFIXES(vis, sRed, sFin, io, sRep),
          sEnc,
          sPar,
          SCode.R_OPERATOR(),
          de_1,
          cmt,
          i,
        )
        list(cls)
      end

      (
        _,
        _,
        _,
        repl,
        vis,
        Absyn.CLASSDEF(
          replaceable_ = rp,
          class_ = cl && Absyn.CLASS(
            name = n,
            partialPrefix = pa,
            encapsulatedPrefix = e,
            restriction = re,
            body = de,
            info = i,
          ),
        ),
        _,
      ) => begin
         re_1 = translateRestriction(cl, re)
         (de_1, cmt) = translateClassdef(de, i, re_1)
         (_, redecl) = translateRedeclarekeywords(repl)
         sRed = SCodeUtil.boolRedeclare(redecl)
         sFin = SCodeUtil.boolFinal(finalPrefix)
         scc = translateConstrainClass(cc)
         sRep = if rp
          SCode.REPLACEABLE(scc)
        else
          SCode.NOT_REPLACEABLE()
        end
         sEnc = SCodeUtil.boolEncapsulated(e)
         sPar = SCodeUtil.boolPartial(pa)
         cls = SCode.CLASS(
          n,
          SCode.PREFIXES(vis, sRed, sFin, io, sRep),
          sEnc,
          sPar,
          re_1,
          de_1,
          cmt,
          i,
        )
        list(cls)
      end

      (
        _,
        _,
        _,
        _,
        vis,
        Absyn.EXTENDS(path = path, elementArg = args, annotationOpt = NONE()),
        info,
      ) => begin
         mod = translateMod(
          SOME(Absyn.CLASSMOD(args, Absyn.NOMOD())),
          SCode.NOT_FINAL(),
          SCode.NOT_EACH(),
          AbsynUtil.dummyInfo,
        )
        list(SCode.EXTENDS(path, vis, mod, NONE(), info))
      end

      (
        _,
        _,
        _,
        _,
        vis,
        Absyn.EXTENDS(path = path, elementArg = args, annotationOpt = SOME(absann)),
        info,
      ) => begin
         mod = translateMod(
          SOME(Absyn.CLASSMOD(args, Absyn.NOMOD())),
          SCode.NOT_FINAL(),
          SCode.NOT_EACH(),
          AbsynUtil.dummyInfo,
        )
         ann = translateAnnotation(absann)
        list(SCode.EXTENDS(path, vis, mod, ann, info))
      end

      (_, _, _, _, _, Absyn.COMPONENTS(components = nil()), _) => begin
        nil
      end

      (
        _,
        _,
        _,
        repl,
        vis,
        Absyn.COMPONENTS(
          attributes = Absyn.ATTR(
            flowPrefix = fl,
            streamPrefix = st,
            parallelism = parallelism,
            variability = variability,
            direction = di,
            isField = isf,
            arrayDim = ad,
            isMode = md
          ),
          typeSpec = t,
        ),
        info,
      ) => begin
         xs_1 = nil
        for comp in inElementSpec4.components
          @match Absyn.COMPONENTITEM(
            component = Absyn.COMPONENT(name = n, arrayDim = d, modification = m),
            comment = comment,
            condition = cond,
          ) = comp
          checkTypeSpec(t, info)
          setHasInnerOuterDefinitionsHandler(io)
          setHasStreamConnectorsHandler(st)
           mod = translateMod(m, SCode.NOT_FINAL(), SCode.NOT_EACH(), info)
           prl1 = translateParallelism(parallelism)
           var1 = translateVariability(variability)
           tot_dim = listAppend(d, ad)
           (repl_1, redecl) = translateRedeclarekeywords(repl)
           (cmt, info) = translateCommentWithLineInfoChanges(comment, info)
           sFin = SCodeUtil.boolFinal(finalPrefix)
           sRed = SCodeUtil.boolRedeclare(redecl)
           scc = translateConstrainClass(cc)
           sRep = if repl_1
            SCode.REPLACEABLE(scc)
          else
            SCode.NOT_REPLACEABLE()
          end
           ct = translateConnectorType(fl, st)
           prefixes = SCode.PREFIXES(vis, sRed, sFin, io, sRep)
           xs_1 = begin
            #=  TODO: Improve performance by iterating over all elements at once instead of creating a new Absyn.COMPONENTS in each step...
            =#
            #=  fprintln(Flags.TRANSLATE, \"translating component: \" + n + \" final: \" + SCodeUtil.finalStr(SCodeUtil.boolFinal(finalPrefix)));
            =#
            #=  signal the external flag that we have inner/outer definitions
            =#
            #=  signal the external flag that we have stream connectors
            =#
            #=  PR. This adds the arraydimension that may be specified together with the type of the component.
            =#
            local attr1::SCode.Attributes
            local attr2::SCode.Attributes
            local mod2::SCode.Mod
            local inName::String
            @match di begin
              Absyn.INPUT_OUTPUT(__) => begin
                 inName = "in_" + n
                 attr1 = SCode.ATTR(tot_dim, ct, prl1, var1, Absyn.INPUT(), isf)
                 attr2 = SCode.ATTR(tot_dim, ct, prl1, var1, Absyn.OUTPUT(), isf)
                 mod2 = SCode.MOD(
                  SCode.FINAL(),
                  SCode.NOT_EACH(),
                  nil,
                  SOME(Absyn.CREF(Absyn.CREF_IDENT(inName, nil))),
                  info,
                )
                _cons(
                  SCode.COMPONENT(n, prefixes, attr2, t, mod2, cmt, cond, info),
                  _cons(
                    SCode.COMPONENT(inName, prefixes, attr1, t, mod, cmt, cond, info),
                    xs_1,
                  ),
                )
              end

              _ => begin
                _cons(
                  SCode.COMPONENT(
                    n,
                    prefixes,
                    SCode.ATTR(tot_dim, ct, prl1, var1, di, isf, md),
                    t,
                    mod,
                    cmt,
                    cond,
                    info,
                  ),
                  xs_1,
                )
              end
            end
          end
        end
         xs_1 = listReverse(xs_1)
        xs_1
      end

      (_, _, _, _, vis, Absyn.IMPORT(import_ = imp, info = info), _) => begin
         xs_1 = translateImports(imp, vis, info)
        xs_1
      end

      _ => begin
        fail()
      end
    end
  end
  return outElementLst
end

"""Used to handle group imports, i.e. A.B.C.{x=a,b}"""
function translateImports(
  imp::Absyn.Import,
  visibility::SCode.Visibility,
  info::SourceInfo,
)::List{SCode.Element}
  local elts::List{SCode.Element}

   elts = begin
    local name::String
    local p::Absyn.Path
    local groups::List{Absyn.GroupImport}
    #= /* Maybe these should give warnings? I don't know. See https:trac.modelica.org/Modelica/ticket/955 */ =#
    @match (imp, visibility, info) begin
      (Absyn.NAMED_IMPORT(name, Absyn.FULLYQUALIFIED(p)), _, _) => begin
        translateImports(Absyn.NAMED_IMPORT(name, p), visibility, info)
      end

      (Absyn.QUAL_IMPORT(Absyn.FULLYQUALIFIED(p)), _, _) => begin
        translateImports(Absyn.QUAL_IMPORT(p), visibility, info)
      end

      (Absyn.UNQUAL_IMPORT(Absyn.FULLYQUALIFIED(p)), _, _) => begin
        translateImports(Absyn.UNQUAL_IMPORT(p), visibility, info)
      end

      (Absyn.GROUP_IMPORT(prefix = p, groups = groups), _, _) => begin
        ListUtil.map3(groups, translateGroupImport, p, visibility, info)
      end

      _ => begin
        list(SCode.IMPORT(imp, visibility, info))
      end
    end
  end
  return elts
end

"""Used to handle group imports, i.e. A.B.C.{x=a,b}"""
function translateGroupImport(
  gimp::Absyn.GroupImport,
  prefix::Absyn.Path,
  visibility::SCode.Visibility,
  info::SourceInfo,
)::SCode.Element
  local elt::SCode.Element

   elt = begin
    local name::String
    local rename::String
    local path::Absyn.Path
    local vis::SCode.Visibility
    @match (gimp, prefix, visibility, info) begin
      (Absyn.GROUP_IMPORT_NAME(name = name), _, vis, _) => begin
         path = AbsynUtil.joinPaths(prefix, Absyn.IDENT(name))
        SCode.IMPORT(Absyn.QUAL_IMPORT(path), vis, info)
      end

      (Absyn.GROUP_IMPORT_RENAME(rename = rename, name = name), _, vis, _) => begin
         path = AbsynUtil.joinPaths(prefix, Absyn.IDENT(name))
        SCode.IMPORT(Absyn.NAMED_IMPORT(rename, path), vis, info)
      end
    end
  end
  return elt
end

"""
  @author: adrpo
  This function will set the external flag that signals
  that a model has inner/outer component definitions
"""
function setHasInnerOuterDefinitionsHandler(io::Absyn.InnerOuter)
   _ = begin
    @match io begin
      Absyn.NOT_INNER_OUTER(__) => begin
        ()
      end

      _ => begin
        System.setHasInnerOuterDefinitions(true)
        ()
      end
    end
  end
  #=  no inner outer!
  =#
  #=  has inner, outer or innerouter components
  =#
end

""" #= @author: adrpo
 This function will set the external flag that signals
 that a model has stream connectors =#
"""
function setHasStreamConnectorsHandler(streamPrefix::Bool)
   _ = begin
    @match streamPrefix begin
      false => begin
        ()
      end

      true => begin
        System.setHasStreamConnectors(true)
        ()
      end
    end
  end
  #=  no stream prefix
  =#
  #=  has stream prefix
  =#
end

"""
  author: PA
  For now, translate to bool, replaceable.
"""
function translateRedeclarekeywords(
  inRedeclKeywords::Option{<:Absyn.RedeclareKeywords},
)::Tuple{Bool, Bool}
  local outIsRedeclared::Bool
  local outIsReplaceable::Bool

   (outIsReplaceable, outIsRedeclared) = begin
    @match inRedeclKeywords begin
      SOME(Absyn.REDECLARE(__)) => begin
        (false, true)
      end

      SOME(Absyn.REPLACEABLE(__)) => begin
        (true, false)
      end

      SOME(Absyn.REDECLARE_REPLACEABLE(__)) => begin
        (true, true)
      end

      _ => begin
        (false, false)
      end
    end
  end
  return (outIsReplaceable, outIsRedeclared)
end

function translateConstrainClass(
  inConstrainClass::Option{<:Absyn.ConstrainClass},
)::Option{SCode.ConstrainClass}
  local outConstrainClass::Option{SCode.ConstrainClass}

   outConstrainClass = begin
    local cc_path::Absyn.Path
    local eltargs::List{Absyn.ElementArg}
    local cmt::Option{Absyn.Comment}
    local cc_cmt::SCode.Comment
    local mod::Absyn.Modification
    local cc_mod::SCode.Mod
    @match inConstrainClass begin
      SOME(Absyn.CONSTRAINCLASS(
        elementSpec = Absyn.EXTENDS(path = cc_path, elementArg = eltargs),
        comment = cmt,
      )) => begin
         mod = Absyn.CLASSMOD(eltargs, Absyn.NOMOD())
         cc_mod = translateMod(
          SOME(mod),
          SCode.NOT_FINAL(),
          SCode.NOT_EACH(),
          AbsynUtil.dummyInfo,
        )
         cc_cmt = translateComment(cmt)
        SOME(SCode.CONSTRAINCLASS(cc_path, cc_mod, cc_cmt))
      end

      _ => begin
        NONE()
      end
    end
  end
  return outConstrainClass
end

"""Converts an Absyn.Parallelism to SCode.Parallelism."""
function translateParallelism(inParallelism::Absyn.Parallelism)::SCode.Parallelism
  local outParallelism::SCode.Parallelism

   outParallelism = begin
    @match inParallelism begin
      Absyn.PARGLOBAL(__) => begin
        SCode.PARGLOBAL()
      end

      Absyn.PARLOCAL(__) => begin
        SCode.PARLOCAL()
      end

      Absyn.NON_PARALLEL(__) => begin
        SCode.NON_PARALLEL()
      end
    end
  end
  return outParallelism
end

"""Converts an Absyn.Variability to SCode.Variability."""
function translateVariability(inVariability::Absyn.Variability)::SCode.Variability
  local outVariability::SCode.Variability

   outVariability = begin
    @match inVariability begin
      Absyn.VAR(__) => begin
        SCode.VAR()
      end

      Absyn.DISCRETE(__) => begin
        SCode.DISCRETE()
      end

      Absyn.PARAM(__) => begin
        SCode.PARAM()
      end

      Absyn.CONST(__) => begin
        SCode.CONST()
      end
    end
  end
  return outVariability
end

"""
  This function transforms a list of Absyn.Equation to a list of
  SCode.Equation, by applying the translateEquation function to each
  equation.
"""
function translateEquations(
  inAbsynEquationItemLst::List{<:Absyn.EquationItem},
  inIsInitial::Bool,
)::List{SCode.Equation}
  local outEquationLst::List{SCode.Equation}

   outEquationLst = list(
    begin
      local com::SCode.Comment
      local info::SourceInfo
      @match eq begin
        Absyn.EQUATIONITEM(__) => begin
           (com, info) = translateCommentWithLineInfoChanges(eq.comment, eq.info)
          SCode.EQUATION(translateEquation(eq.equation_, com, info, inIsInitial))
        end
      end
    end for eq in inAbsynEquationItemLst if begin
      @match eq begin
        Absyn.EQUATIONITEM(__) => begin
          true
        end

        _ => begin
          false
        end
      end
    end
  )
  return outEquationLst
end

"""Helper function to translateEquations"""
function translateEEquations(
  inAbsynEquationItemLst::List{<:Absyn.EquationItem},
  inIsInitial::Bool,
)::List{SCode.EEquation}
  local outEEquationLst::List{SCode.EEquation}

   outEEquationLst = begin
    local e_1::SCode.EEquation
    local es_1::List{SCode.EEquation}
    local e::Absyn.Equation
    local es::List{Absyn.EquationItem}
    local acom::Option{Absyn.Comment}
    local com::SCode.Comment
    local info::SourceInfo
    @match (inAbsynEquationItemLst, inIsInitial) begin
      (nil(), _) => begin
        nil
      end

      (Absyn.EQUATIONITEM(equation_ = e, comment = acom, info = info) <| es, _) => begin
         (com, info) = translateCommentWithLineInfoChanges(acom, info)
         e_1 = translateEquation(e, com, info, inIsInitial)
         es_1 = translateEEquations(es, inIsInitial)
        _cons(e_1, es_1)
      end

      (Absyn.EQUATIONITEMCOMMENT(__) <| es, _) => begin
        translateEEquations(es, inIsInitial)
      end
    end
  end
  #=  fprintln(Flags.TRANSLATE, \"translating equation: \" + Dump.unparseEquationStr(0, e));
  =#
  return outEEquationLst
end

"""turns an Absyn.Comment into an SCode.Comment"""
function translateCommentWithLineInfoChanges(
  inComment::Option{<:Absyn.Comment},
  inInfo::SourceInfo,
)::Tuple{SCode.Comment, SourceInfo}
  local outInfo::SourceInfo
  local outComment::SCode.Comment

   outComment = translateComment(inComment)
   outInfo = getInfoAnnotationOrDefault(outComment, inInfo)
  return (outComment, outInfo)
end

"""Replaces the file info if there is an annotation __OpenModelica_FileInfo=(\\\"fileName\\\",line). Should be improved."""
function getInfoAnnotationOrDefault(comment::SCode.Comment, default::SourceInfo)::SourceInfo
  local info::SourceInfo

   info = begin
    local lst::List{SCode.SubMod}
    @match (comment, default) begin
      (
        SCode.COMMENT(
          annotation_ = SOME(SCode.ANNOTATION(modification = SCode.MOD(subModLst = lst))),
        ),
        _,
      ) => begin
        getInfoAnnotationOrDefault2(lst, default)
      end

      _ => begin
        default
      end
    end
  end
  return info
end

function getInfoAnnotationOrDefault2(
  lst::List{<:SCode.SubMod},
  default::SourceInfo,
)::SourceInfo
  local info::SourceInfo

   info = begin
    local rest::List{SCode.SubMod}
    local fileName::String
    local line::Int
    @match (lst, default) begin
      (nil(), _) => begin
        default
      end

      (
        SCode.NAMEMOD(
          ident = "__OpenModelica_FileInfo",
          mod = SCode.MOD(
            binding = SOME(Absyn.TUPLE(
              Absyn.STRING(fileName) <| Absyn.INTEGER(line) <| nil(),
            )),
          ),
        ) <| _,
        _,
      ) => begin
        SOURCEINFO(fileName, false, line, 0, line, 0, 0.0)
      end

      (_ <| rest, _) => begin
        getInfoAnnotationOrDefault2(rest, default)
      end
    end
  end
  return info
end

"""turns an Absyn.Comment into an SCode.Comment"""
function translateComment(inComment::Option{<:Absyn.Comment})::SCode.Comment
  local outComment::SCode.Comment

   outComment = begin
    local absann::Option{Absyn.Annotation}
    local ann::Option{SCode.Annotation}
    local ostr::Option{String}
    @match inComment begin
      NONE() => begin
        SCode.noComment
      end

      SOME(Absyn.COMMENT(absann, ostr)) => begin
         ann = translateAnnotationOpt(absann)
         ostr = Util.applyOption(ostr, System.unescapedString)
        SCode.COMMENT(ann, ostr)
      end
    end
  end
  return outComment
end

"""turns an Absyn.Comment into an SCode.Comment"""
function translateCommentList(
  inAnns::List{<:Absyn.Annotation},
  inString::Option{<:String},
)::SCode.Comment
  local outComment::SCode.Comment

   outComment = begin
    local absann::Absyn.Annotation
    local anns::List{Absyn.Annotation}
    local ann::Option{SCode.Annotation}
    local ostr::Option{String}
    @match (inAnns, inString) begin
      (nil(), _) => begin
        SCode.COMMENT(NONE(), inString)
      end

      (absann <| nil(), _) => begin
         ann = translateAnnotation(absann)
         ostr = Util.applyOption(inString, System.unescapedString)
        SCode.COMMENT(ann, ostr)
      end

      (absann <| anns, _) => begin
         absann = ListUtil.fold(anns, AbsynUtil.mergeAnnotations, absann)
         ann = translateAnnotation(absann)
         ostr = Util.applyOption(inString, System.unescapedString)
        SCode.COMMENT(ann, ostr)
      end
    end
  end
  return outComment
end

"""turns an Absyn.Comment into an SCode.Annotation + string"""
function translateCommentSeparate(
  inComment::Option{<:Absyn.Comment},
)::Tuple{Option{SCode.Annotation}, Option{String}}
  local outStr::Option{String}
  local outAnn::Option{SCode.Annotation}

   (outAnn, outStr) = begin
    local absann::Absyn.Annotation
    local ann::Option{SCode.Annotation}
    local str::String
    @match inComment begin
      NONE() => begin
        (NONE(), NONE())
      end

      SOME(Absyn.COMMENT(NONE(), NONE())) => begin
        (NONE(), NONE())
      end

      SOME(Absyn.COMMENT(NONE(), SOME(str))) => begin
        (NONE(), SOME(str))
      end

      SOME(Absyn.COMMENT(SOME(absann), NONE())) => begin
         ann = translateAnnotation(absann)
        (ann, NONE())
      end

      SOME(Absyn.COMMENT(SOME(absann), SOME(str))) => begin
         ann = translateAnnotation(absann)
        (ann, SOME(str))
      end
    end
  end
  return (outAnn, outStr)
end

function translateEquation(
  inEquation::Absyn.Equation,
  inComment::SCode.Comment,
  inInfo::SourceInfo,
  inIsInitial::Bool,
)::SCode.EEquation
  local outEEquation::SCode.EEquation

   outEEquation = begin
    local exp::Absyn.Exp
    local e1::Absyn.Exp
    local e2::Absyn.Exp
    local e3::Absyn.Exp
    local abody::List{Absyn.Equation}
    local else_branch::List{SCode.EEquation}
    local body::List{SCode.EEquation}
    local branches::List{Tuple{Absyn.Exp, List{SCode.EEquation}}}
    local iter_name::String
    local iter_range::Option{Absyn.Exp}
    local eq::SCode.EEquation
    local conditions::List{Absyn.Exp}
    local bodies::List{List{SCode.EEquation}}
    local cr::Absyn.ComponentRef
    @match inEquation begin
      Absyn.EQ_IF(__) => begin
         body = translateEEquations(inEquation.equationTrueItems, inIsInitial)
         (conditions, bodies) =
          ListUtil.map1_2(inEquation.elseIfBranches, translateEqBranch, inIsInitial)
         conditions = _cons(inEquation.ifExp, conditions)
         else_branch =
          translateEEquations(inEquation.equationElseItems, inIsInitial)
        SCode.EQ_IF(conditions, _cons(body, bodies), else_branch, inComment, inInfo)
      end

      Absyn.EQ_WHEN_E(__) => begin
        body = translateEEquations(inEquation.whenEquations, inIsInitial)
        (conditions, bodies) =
          ListUtil.map1_2(inEquation.elseWhenEquations, translateEqBranch, inIsInitial)
        branches = list(@do_threaded_for (c, b) (c, b) (conditions, bodies))
        SCode.EQ_WHEN(inEquation.whenExp, body, branches, inComment, inInfo)
      end

      Absyn.EQ_EQUALS(__) => begin
        SCode.EQ_EQUALS(inEquation.leftSide, inEquation.rightSide, inComment, inInfo)
      end

      Absyn.EQ_PDE(__) => begin
        SCode.EQ_PDE(
          inEquation.leftSide,
          inEquation.rightSide,
          inEquation.domain,
          inComment,
          inInfo,
        )
      end

      Absyn.EQ_CONNECT(__) => begin
        if inIsInitial
        end
        SCode.EQ_CONNECT(inEquation.connector1, inEquation.connector2, inComment, inInfo)
      end

      Absyn.EQ_FOR(__) => begin
         body = translateEEquations(inEquation.forEquations, inIsInitial)
        #=  Convert for-loops with multiple iterators into nested for-loops.
        =#
        for i in listReverse(inEquation.iterators)
           (iter_name, iter_range) = translateIterator(i, inInfo)
           body =
            list(SCode.EQ_FOR(iter_name, iter_range, body, inComment, inInfo))
        end
        listHead(body)
      end

      Absyn.EQ_NORETCALL(
        functionName = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| nil(), argNames = nil()),
      ) => begin
        SCode.EQ_ASSERT(e1, e2, ASSERTION_LEVEL_ERROR, inComment, inInfo)
      end

      Absyn.EQ_NORETCALL(
        functionName = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| e3 <| nil(), argNames = nil()),
      ) => begin
        SCode.EQ_ASSERT(e1, e2, e3, inComment, inInfo)
      end

      Absyn.EQ_NORETCALL(
        functionName = Absyn.CREF_IDENT(name = "assert"),
        functionArgs = Absyn.FUNCTIONARGS(
          args = e1 <| e2 <| nil(),
          argNames = Absyn.NAMEDARG("level", e3) <| nil(),
        ),
      ) => begin
        SCode.EQ_ASSERT(e1, e2, e3, inComment, inInfo)
      end

      Absyn.EQ_NORETCALL(
        functionName = Absyn.CREF_IDENT(name = "terminate"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| nil(), argNames = nil()),
      ) => begin
        SCode.EQ_TERMINATE(e1, inComment, inInfo)
      end

      Absyn.EQ_NORETCALL(
        functionName = Absyn.CREF_IDENT(name = "reinit"),
        functionArgs = Absyn.FUNCTIONARGS(args = e1 <| e2 <| nil(), argNames = nil()),
      ) => begin
        SCode.EQ_REINIT(e1, e2, inComment, inInfo)
      end

      Absyn.EQ_NORETCALL(__) => begin
        SCode.EQ_NORETCALL(
          Absyn.CALL(inEquation.functionName, inEquation.functionArgs, nil),
          inComment,
          inInfo,
        )
      end

      Absyn.EQ_RECONFIGURE(__) => begin
        SCode.EQ_RECONFIGURE(
          inEquation.variables,
          inEquation.whenClauses,
          inEquation.prompt,
          inEquation.initialEquations,
          inComment,
          inInfo,
        )
      end
    end
  end
  return outEEquation
end

function translateEqBranch(
  inBranch::Tuple{<:Absyn.Exp, List{<:Absyn.EquationItem}},
  inIsInitial::Bool,
)::Tuple{Absyn.Exp, List{SCode.EEquation}}
  local outBody::List{SCode.EEquation}
  local outCondition::Absyn.Exp

  local body::List{Absyn.EquationItem}

   (outCondition, body) = inBranch
   outBody = translateEEquations(body, inIsInitial)
  return (outCondition, outBody)
end

function translateIterator(
  inIterator::Absyn.ForIterator,
  inInfo::SourceInfo,
)::Tuple{String, Option{Absyn.Exp}}
  local outRange::Option{Absyn.Exp}
  local outName::String

  local guard_exp::Option{Absyn.Exp}

  @match Absyn.ITERATOR(name = outName, guardExp = guard_exp, range = outRange) = inIterator
  if isSome(guard_exp)
  end
  return (outName, outRange)
end

"""function: translateElementAddinfo"""
function translateElementAddinfo(elem::SCode.Element, nfo::SourceInfo)::SCode.Element
  local oelem::SCode.Element

   oelem = begin
    local a1::SCode.Ident
    local a2::Absyn.InnerOuter
    local a3::Bool
    local a4::Bool
    local a5::Bool
    local rd::Bool
    local a6::SCode.Attributes
    local a7::Absyn.TypeSpec
    local a8::SCode.Mod
    local a10::SCode.Comment
    local a11::Option{Absyn.Exp}
    local a13::Option{Absyn.ConstrainClass}
    local p::SCode.Prefixes
    @match (elem, nfo) begin
      (SCode.COMPONENT(a1, p, a6, a7, a8, a10, a11, _), _) => begin
        SCode.COMPONENT(a1, p, a6, a7, a8, a10, a11, nfo)
      end

      _ => begin
        elem
      end
    end
  end
  return oelem
end

#= /* Modification management */ =#

"""Builds an SCode.Mod from an Absyn.Modification."""
function translateMod(
  inMod::Option{<:Absyn.Modification},
  finalPrefix::SCode.Final,
  eachPrefix::SCode.Each,
  info::SourceInfo,
)::SCode.Mod
  local outMod::SCode.Mod

  local args::List{Absyn.ElementArg}
  local eqmod::Absyn.EqMod
  local subs::List{SCode.SubMod}
  local binding::Option{Absyn.Exp}

   (args, eqmod) = begin
    @match inMod begin
      SOME(Absyn.CLASSMOD(elementArgLst = args, eqMod = eqmod)) => begin
        (args, eqmod)
      end

      _ => begin
        (nil, Absyn.NOMOD())
      end
    end
  end
   subs = if listEmpty(args)
    nil
  else
    translateArgs(args)
  end
   binding = begin
    @match eqmod begin
      Absyn.EQMOD(__) => begin
        SOME(eqmod.exp)
      end

      _ => begin
        NONE()
      end
    end
  end
   outMod = begin
    @match (subs, binding, finalPrefix, eachPrefix) begin
      (nil(), NONE(), SCode.NOT_FINAL(__), SCode.NOT_EACH(__)) => begin
        SCode.NOMOD()
      end

      _ => begin
        SCode.MOD(finalPrefix, eachPrefix, subs, binding, info)
      end
    end
  end
  return outMod
end

function translateArgs(args::List{<:Absyn.ElementArg})::List{SCode.SubMod}
  local subMods::List{SCode.SubMod} = nil

  local smod::SCode.Mod
  local elem::SCode.Element
  local sub::SCode.SubMod

  for arg in args
     subMods = begin
      @match arg begin
        Absyn.MODIFICATION(__) => begin
           smod = translateMod(
            arg.modification,
            SCodeUtil.boolFinal(arg.finalPrefix),
            translateEach(arg.eachPrefix),
            arg.info,
          )
          if !SCodeUtil.isEmptyMod(smod)
             sub = translateSub(arg.path, smod, arg.info)
             subMods = _cons(sub, subMods)
          end
          subMods
        end

        Absyn.REDECLARATION(__) => begin
          @match _cons(elem, nil) = translateElementspec(
            arg.constrainClass,
            arg.finalPrefix,
            Absyn.NOT_INNER_OUTER(),
            SOME(arg.redeclareKeywords),
            SCode.PUBLIC(),
            arg.elementSpec,
            arg.info,
          )
           sub = SCode.NAMEMOD(
            AbsynUtil.elementSpecName(arg.elementSpec),
            SCode.REDECL(
              SCodeUtil.boolFinal(arg.finalPrefix),
              translateEach(arg.eachPrefix),
              elem,
            ),
          )
          _cons(sub, subMods)
        end

        #= Selective model extension (Modelica 3.6): `break x`, parsed as connect(break, x), and
           `break connect(a, b)` (omc translateArgs). =#
        Absyn.INHERITANCEBREAK(cnct = Absyn.EQ_CONNECT(connector1 = Absyn.CREF_IDENT(name = "break"),
                                                       connector2 = Absyn.CREF_IDENT(name = name))) => begin
          _cons(SCode.NAMEMOD(name, SCode.BREAK_COMPONENT(arg.info)), subMods)
        end

        Absyn.INHERITANCEBREAK(cnct = Absyn.EQ_CONNECT(connector1 = cr1, connector2 = cr2)) => begin
          _cons(SCode.NAMEMOD("", SCode.BREAK_CONNECT(cr1, cr2, arg.info)), subMods)
        end
      end
    end
  end
   subMods = listReverse(subMods)
  return subMods
end

"""
  This function converts a Absyn.ComponentRef plus a list
  of modifications into a number of nested SCode.SUBMOD.
"""
function translateSub(inPath::Absyn.Path, inMod::SCode.Mod, info::SourceInfo)::SCode.SubMod
  local outSubMod::SCode.SubMod

   outSubMod = begin
    local i::String
    local path::Absyn.Path
    local mod::SCode.Mod
    local sub::SCode.SubMod
    #=  Then the normal rules
    =#
    @match (inPath, inMod, info) begin
      (Absyn.IDENT(name = i), mod, _) => begin
        SCode.NAMEMOD(i, mod)
      end

      (Absyn.QUALIFIED(name = i, path = path), mod, _) => begin
         sub = translateSub(path, mod, info)
         mod =
          SCode.MOD(SCode.NOT_FINAL(), SCode.NOT_EACH(), list(sub), NONE(), info)
        SCode.NAMEMOD(i, mod)
      end
    end
  end
  return outSubMod
end

function makeTypeVarElement(str::String, info::SourceInfo)::SCode.Element
  local elt::SCode.Element

  local cd::SCode.ClassDef
  local ts::Absyn.TypeSpec

   ts = Absyn.TCOMPLEX(
    Absyn.IDENT("polymorphic"),
    list(Absyn.TPATH(Absyn.IDENT("Any"), NONE())),
    NONE(),
  )
   cd = SCode.DERIVED(
    ts,
    SCode.NOMOD(),
    SCode.ATTR(
      nil,
      SCode.POTENTIAL(),
      SCode.NON_PARALLEL(),
      SCode.VAR(),
      Absyn.BIDIR(),
      Absyn.NONFIELD(),
      false
    ),
  )
   elt = SCode.CLASS(
    str,
    SCode.PREFIXES(
      SCode.PUBLIC(),
      SCode.NOT_REDECLARE(),
      SCode.FINAL(),
      Absyn.NOT_INNER_OUTER(),
      SCode.NOT_REPLACEABLE(),
    ),
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    cd,
    SCode.noComment,
    info,
  )
  return elt
end

function translateEach(inAEach::Absyn.Each)::SCode.Each
  local outSEach::SCode.Each

   outSEach = begin
    @match inAEach begin
      Absyn.EACH(__) => begin
        SCode.EACH()
      end

      Absyn.NON_EACH(__) => begin
        SCode.NOT_EACH()
      end
    end
  end
  return outSEach
end

function checkTypeSpec(ts::Absyn.TypeSpec, info::SourceInfo)
   _ = begin
    local tss::List{Absyn.TypeSpec}
    local ts2::Absyn.TypeSpec
    local str::String
    @match (ts, info) begin
      (Absyn.TPATH(__), _) => begin
        ()
      end

      (Absyn.TCOMPLEX(path = Absyn.IDENT("tuple"), typeSpecs = ts2 <| nil()), _) => begin
         str = AbsynUtil.typeSpecString(ts)
        checkTypeSpec(ts2, info)
        ()
      end

      (Absyn.TCOMPLEX(path = Absyn.IDENT("tuple"), typeSpecs = tss && _ <| _ <| _), _) =>
        begin
          ListUtil.map1_0(tss, checkTypeSpec, info)
          ()
        end

      (Absyn.TCOMPLEX(typeSpecs = ts2 <| nil()), _) => begin
        checkTypeSpec(ts2, info)
        ()
      end

      (Absyn.TCOMPLEX(typeSpecs = tss), _) => begin
        if listMember(
          ts.path,
          list(
            Absyn.IDENT("list"),
            Absyn.IDENT("List"),
            Absyn.IDENT("array"),
            Absyn.IDENT("Array"),
            Absyn.IDENT("polymorphic"),
            Absyn.IDENT("Option"),
          ),
        )
           str = AbsynUtil.typeSpecString(ts)
          ListUtil.map1_0(tss, checkTypeSpec, info)
        end
        ()
      end
    end
  end
end

@exportAll()
end
