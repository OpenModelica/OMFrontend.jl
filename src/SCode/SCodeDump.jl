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

module SCodeDump

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl SCodeDumpOptions

import OpenModelicaParser.Absyn
import ..SCode
import ..ListUtil

import ..Frontend.AbsynUtil
import ..SCodeUtil

@Uniontype SCodeDumpOptions begin
  @Record OPTIONS begin

    stripAlgorithmSections::Bool
    stripProtectedImports::Bool
    stripProtectedClasses::Bool
    stripProtectedComponents::Bool
    stripMetaRecords::Bool #= The automatically generated records that change scope from uniontype to the package =#
    stripGraphicalAnnotations::Bool
    stripStringComments::Bool
    stripExternalDecl::Bool
    stripOutputBindings::Bool
  end
end

const defaultOptions =
  OPTIONS(false, false, false, false, true, true, false, false, false)::SCodeDumpOptions

"""A modifier as Modelica: `(a = 1, each b(c = 2)) = value`; empty for none. A submodifier's prefixes
(`each`, `final`) come before its name."""
function printModStr(inMod::SCode.Mod, options::SCodeDumpOptions = defaultOptions)::String
  return dumpModifier(inMod, options)
end

"""The annotation of an SCode comment as Modelica, `annotation(...)`; empty for none."""
function printAnnotationStr(inComment::SCode.COMMENT, options::SCodeDumpOptions = defaultOptions)::String
  local ann::Option{SCode.ANNOTATION} = inComment.annotation_
  return isSome(ann) ? dumpAnnotation(ann.value, options) : ""
end

"""The annotations a tool draws, left out with the option `stripGraphicalAnnotations`."""
const GRAPHICAL_ANNOTATIONS = ("Icon", "Diagram", "Placement", "Line", "IconMap", "DiagramMap")

"""An annotation as Modelica, `annotation(...)`; empty when nothing is left after the options."""
function dumpAnnotation(annotation::SCode.ANNOTATION, options::SCodeDumpOptions)::String
  local mod::SCode.Mod = annotation.modification
  mod isa SCode.MOD || return ""
  local subs::Vector{String} = String[subModStr(sm, options) for sm in mod.subModLst
                                      if !(options.stripGraphicalAnnotations && sm.ident in GRAPHICAL_ANNOTATIONS)]
  return isempty(subs) ? "" : "annotation(" * join(subs, ", ") * ")"
end

"""A modifier as Modelica (`printModStr`)."""
function dumpModifier(mod::SCode.Mod, options::SCodeDumpOptions)::String
  if mod isa SCode.MOD
    local subs::Vector{String} = String[subModStr(sm, options) for sm in mod.subModLst]
    local binding::Option{Absyn.Exp} = mod.binding
    return (isempty(subs) ? "" : "(" * join(subs, ", ") * ")") *
           (isSome(binding) ? " = " * AbsynUtil.printExp(binding.value) : "")
  elseif mod isa SCode.REDECL
    return "redeclare " * unparseElementStr(mod.element, options)
  end
  return ""
end

"""A submodifier as Modelica: its prefixes, name and modifier."""
function subModStr(sm::SCode.NAMEMOD, options::SCodeDumpOptions)::String
  local mod::SCode.Mod = sm.mod
  mod isa SCode.REDECL && return dumpModifier(mod, options)
  local prefixes::String = mod isa SCode.MOD ?
    (SCodeUtil.eachBool(mod.eachPrefix) ? "each " : "") * (SCodeUtil.finalBool(mod.finalPrefix) ? "final " : "") : ""
  return prefixes * sm.ident * dumpModifier(mod, options)
end

"""Prints SCode.Restriction to a string."""
function restrString(inRestriction::SCode.Restriction)::String
  local outString::String

  @assign outString = begin
    @match inRestriction begin
      SCode.R_CLASS(__) => begin
        "class"
      end

      SCode.R_OPTIMIZATION(__) => begin
        "optimization"
      end

      SCode.R_MODEL(__) => begin
        "model"
      end

      SCode.R_RECORD(false) => begin
        "record"
      end

      SCode.R_RECORD(true) => begin
        "operator record"
      end

      SCode.R_BLOCK(__) => begin
        "block"
      end

      SCode.R_CONNECTOR(false) => begin
        "connector"
      end

      SCode.R_CONNECTOR(true) => begin
        "expandable connector"
      end

      SCode.R_OPERATOR(__) => begin
        "operator"
      end

      SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(false)) => begin
        "pure function"
      end

      SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(true)) => begin
        "impure function"
      end

      SCode.R_FUNCTION(SCode.FR_OPERATOR_FUNCTION(__)) => begin
        "operator function"
      end

      SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(false)) => begin
        "pure external function"
      end

      SCode.R_FUNCTION(SCode.FR_EXTERNAL_FUNCTION(true)) => begin
        "impure external function"
      end

      SCode.R_FUNCTION(SCode.FR_RECORD_CONSTRUCTOR(__)) => begin
        "record constructor"
      end

      SCode.R_FUNCTION(SCode.FR_PARALLEL_FUNCTION(__)) => begin
        "parallel function"
      end

      SCode.R_FUNCTION(SCode.FR_KERNEL_FUNCTION(__)) => begin
        "kernel function"
      end

      SCode.R_TYPE(__) => begin
        "type"
      end

      SCode.R_PACKAGE(__) => begin
        "package"
      end

      SCode.R_ENUMERATION(__) => begin
        "enumeration"
      end

      SCode.R_METARECORD(__) => begin
        "metarecord " + AbsynUtil.pathString(inRestriction.name)
      end

      SCode.R_UNIONTYPE(__) => begin
        "uniontype"
      end

      SCode.R_PREDEFINED_INTEGER(__) => begin
        "Integer"
      end

      SCode.R_PREDEFINED_REAL(__) => begin
        "Real"
      end

      SCode.R_PREDEFINED_STRING(__) => begin
        "String"
      end

      SCode.R_PREDEFINED_BOOLEAN(__) => begin
        "Boolean"
      end

      SCode.R_PREDEFINED_CLOCK(__) => begin
        "Clock"
      end

      SCode.R_PREDEFINED_ENUMERATION(__) => begin
        "enumeration"
      end
    end
  end
  #= predefined types
     BTH =#
  return outString
end

"""An element as Modelica, short (for messages): `Real x(start = 1)`, `model M`, `extends A(b = 1)`, `import A.B`."""
function unparseElementStr(inElement::SCode.Element, options::SCodeDumpOptions = defaultOptions)::String
  if inElement isa SCode.COMPONENT
    return AbsynUtil.typeSpecString(inElement.typeSpec) * " " * inElement.name * printModStr(inElement.modifications, options)
  elseif inElement isa SCode.CLASS
    return restrString(inElement.restriction) * " " * inElement.name
  elseif inElement isa SCode.EXTENDS
    return "extends " * AbsynUtil.pathString(inElement.baseClassPath) * printModStr(inElement.modifications, options)
  elseif inElement isa SCode.IMPORT
    return "import " * AbsynUtil.importString(inElement.imp)
  elseif inElement isa SCode.DEFINEUNIT
    return "defineunit " * inElement.name
  end
  return string(typeof(inElement))
end

"""Print Variability to a string."""
function variabilityString(inVariability::SCode.Variability)::String

  @match inVariability begin
    SCode.VAR(__) => begin
      "VAR"
    end

    SCode.DISCRETE(__) => begin
      "DISCRETE"
    end

    SCode.PARAM(__) => begin
      "PARAM"
    end

    SCode.CONST(__) => begin
      "CONST"
    end
  end
end

"""Print parallelism to a string."""
function parallelismString(inParallelism::SCode.Parallelism)::String

  @match inParallelism begin
    SCode.PARGLOBAL(__) => begin
      "PARGLOBAL"
    end

    SCode.PARLOCAL(__) => begin
      "PARLOCAL"
    end

    SCode.NON_PARALLEL(__) => begin
      "NON_PARALLEL"
    end
  end
end

"""Print Variability to a string."""
function unparseVariability(inVariability::SCode.Variability)::String

  @match inVariability begin
    SCode.VAR(__) => begin
      ""
    end

    SCode.DISCRETE(__) => begin
      "discrete"
    end

    SCode.PARAM(__) => begin
      "parameter"
    end

    SCode.CONST(__) => begin
      "constant"
    end
  end
end

@exportAll()
end
