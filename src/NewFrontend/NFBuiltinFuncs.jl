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

module NFBuiltinFuncs

import ..AbsynUtil
import Absyn
import DAE
import SCode

using ..Frontend
using MetaModelica
using ExportAll
using MetaModelica.Dangerous


const DUMMY_ELEMENT =
  SCode.CLASS(
    "DummyFunction",
    SCode.defaultPrefixes,
    SCode.ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_FUNCTION(SCode.FR_NORMAL_FUNCTION(false)),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.COMMENT(NONE(), NONE()),
    AbsynUtil.dummyInfo,
  )::SCode.Element
#=  Default Integer parameter.
=#
const INT_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_INTEGER(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const INT_PARAM =
  COMPONENT_NODE(
    "i",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(INT_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
#=  Default Real parameter.
=#
const REAL_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_REAL(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const REAL_PARAM =
  COMPONENT_NODE(
    "r",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(REAL_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
#=  Default Boolean parameter.
=#
const BOOL_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_BOOLEAN(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const BOOL_PARAM =
  COMPONENT_NODE(
    "b",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(BOOL_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
#=  Default String parameter.
=#
const STRING_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_STRING(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const STRING_PARAM =
  COMPONENT_NODE(
    "s",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(STRING_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
#=  Default enumeration(:) parameter.
=#
const ENUM_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_ENUMERATION_ANY(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const ENUM_PARAM =
  COMPONENT_NODE(
    "e",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(ENUM_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
#=  Integer(e)
=#
const EMPTY_NODE_CACHE =
  listArrayLiteral(list(
    C_NO_CACHE(),
    C_NO_CACHE(),
    C_NO_CACHE(),
  ))::Vector
const INTEGER_DUMMY_NODE =
  CLASS_NODE(
    "Integer",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(NOT_INSTANTIATED()),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    NORMAL_CLASS(),
  )::InstNode

const INTEGER_FUNCTION =
  M_FUNCTION(
    Absyn.IDENT("Integer"),
    INTEGER_DUMMY_NODE,
    list(ENUM_PARAM),
    nil,
    nil,
    list(SLOT(
      "e",
      SlotType.POSITIONAL,
      NONE(),
      NONE(),
      1,
      SlotEvalStatus.NOT_EVALUATED,
    )),
    TYPE_INTEGER(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const INTEGER_NODE =
  CLASS_NODE(
    "IntegerFunc",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(INSTANCED_CLASS(
      TYPE_UNKNOWN(),
      CLASS_TREE_EMPTY_TREE(),
      SECTIONS_EMPTY(),
      RESTRICTION_FUNCTION(),
    )),
    listArrayLiteral(list(
      C_FUNCTION(M_FUNCTION[INTEGER_FUNCTION], true, false),
      C_NO_CACHE(),
      C_NO_CACHE(),
    )),
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
const INTEGER_CREF =
  COMPONENT_REF_CREF(
    INTEGER_NODE,
    nil,
    TYPE_INTEGER(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef
const STRING_DUMMY_NODE =
  CLASS_NODE(
    "String",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(NOT_INSTANTIATED()),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    NORMAL_CLASS(),
  )::InstNode
#=  String(r, significantDigits=d, minimumLength=0, leftJustified=true)
=#
const STRING_REAL =
  M_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(REAL_PARAM, INT_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "r",
        SlotType.POSITIONAL,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "significantDigits",
        SlotType.NAMED,
        SOME(INTEGER_EXPRESSION(6)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SlotType.NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        3,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SlotType.NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        4,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  String(r, format=\"-0.6g\")
=#
const STRING_REAL_FORMAT =
  M_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(REAL_PARAM, STRING_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "r",
        SlotType.POSITIONAL,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "format",
        SlotType.NAMED,
        NONE(),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  String(i, minimumLength=0, leftJustified=true)
=#
const STRING_INT =
  M_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(INT_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "i",
        SlotType.POSITIONAL,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SlotType.NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SlotType.NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  String(b, minimumLength=0, leftJustified=true)
=#
const STRING_BOOL =
  M_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(BOOL_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "b",
        SlotType.POSITIONAL,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SlotType.NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SlotType.NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  String(e, minimumLength=0, leftJustified=true)
=#
const STRING_ENUM =
  M_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(ENUM_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "e",
        SlotType.POSITIONAL,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SlotType.NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SlotType.NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const STRING_NODE =
  CLASS_NODE(
    "String",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_STRING(),
      CLASS_TREE_EMPTY_TREE(),
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    listArrayLiteral(list(
      C_FUNCTION(
        M_FUNCTION[STRING_ENUM, STRING_INT, STRING_BOOL, STRING_REAL, STRING_REAL_FORMAT],
        true,
        true,
      ),
      C_NO_CACHE(),
      C_NO_CACHE(),
    )),
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
const STRING_CREF =
  COMPONENT_REF_CREF(
    STRING_NODE,
    nil,
    TYPE_INTEGER(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef
const ABS_REAL =
  M_FUNCTION(
    Absyn.IDENT("abs"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const MAX_INT =
  M_FUNCTION(
    Absyn.IDENT("max"),
    EMPTY_NODE(),
    list(INT_PARAM, INT_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const MAX_REAL =
  M_FUNCTION(
    Absyn.IDENT("max"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const DIV_INT =
  M_FUNCTION(
    Absyn.IDENT("div"),
    EMPTY_NODE(),
    list(INT_PARAM, INT_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const FLOOR =
  M_FUNCTION(
    Absyn.IDENT("floor"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const INTEGER_REAL =
  M_FUNCTION(
    Absyn.IDENT("integer"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const INTEGER_ENUM =
  M_FUNCTION(
    Absyn.IDENT("Integer"),
    EMPTY_NODE(),
    list(ENUM_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const POSITIVE_MAX_REAL =
  M_FUNCTION(
    Absyn.IDENT("OMCPositiveMax"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const IN_STREAM =
  M_FUNCTION(
    Absyn.IDENT("inStream"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const PROMOTE =
  M_FUNCTION(
    Absyn.IDENT("promote"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const CAT =
  M_FUNCTION(
    Absyn.IDENT("cat"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const ARRAY_FUNC =
  M_FUNCTION(
    Absyn.IDENT("array"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function

const FILL_FUNC =
  M_FUNCTION(
    Absyn.IDENT("fill"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function

const INITIAL_STRUCTURAL_STATE_FUNC =
  M_FUNCTION(
    Absyn.IDENT("initialStructuralState"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function


const SMOOTH =
  M_FUNCTION(
    Absyn.IDENT("smooth"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const CLOCK_COMPONENT =
  TYPED_COMPONENT(
    EMPTY_NODE(),
    TYPE_CLOCK(),
    EMPTY_BINDING,
    EMPTY_BINDING,
    DEFAULT_ATTR,
    NONE(),
    NONE(),
    AbsynUtil.dummyInfo,
  )::Component
const CLOCK_PARAM =
  COMPONENT_NODE(
    "s",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(CLOCK_COMPONENT),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode
const CLOCK_DUMMY_NODE =
  CLASS_NODE(
    "Clock",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(NOT_INSTANTIATED()),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    NORMAL_CLASS(),
  )::InstNode
#=  Clock() - inferred clock
=#
const CLOCK_INFERED =
  M_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    nil,
    list(CLOCK_PARAM),
    nil,
    nil,
    TYPE_CLOCK(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  Clock(intervalCounter, resolution = 1) - clock with Integer interval
=#
const CLOCK_INT =
  M_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(INT_PARAM, INT_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT(
        "intervalCounter",
        SlotType.GENERIC,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "resolution",
        SlotType.GENERIC,
        SOME(INTEGER_EXPRESSION(1)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  Clock(interval) - clock with Real interval
=#
const CLOCK_REAL =
  M_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(REAL_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(SLOT(
      "interval",
      SlotType.GENERIC,
      NONE(),
      NONE(),
      1,
      SlotEvalStatus.NOT_EVALUATED,
    )),
    TYPE_CLOCK(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  Clock(condition, startInterval = 0.0) - Boolean clock, triggered by zero-crossing events
=#
const CLOCK_BOOL =
  M_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(BOOL_PARAM, REAL_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT(
        "condition",
        SlotType.GENERIC,
        NONE(),
        NONE(),
        1,
        SlotEvalStatus.NOT_EVALUATED,
      ),
      SLOT(
        "startInterval",
        SlotType.GENERIC,
        SOME(REAL_EXPRESSION(0.0)),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
#=  Clock(c, solverMethod) - Solver clock
=#
const CLOCK_SOLVER =
  M_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(CLOCK_PARAM, STRING_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT("c", SlotType.GENERIC, NONE(), NONE(), 1, SlotEvalStatus.NOT_EVALUATED),
      SLOT(
        "solverMethod",
        SlotType.GENERIC,
        NONE(),
        NONE(),
        2,
        SlotEvalStatus.NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    DAE.FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.createImmutable(FunctionStatus.BUILTIN),
    P_Pointer.createImmutable(0),
  )::M_Function
const CLOCK_NODE =
  CLASS_NODE(
    "Clock",
    DUMMY_ELEMENT,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_CLOCK(),
      CLASS_TREE_EMPTY_TREE(),
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    listArrayLiteral(list(
      C_FUNCTION(
        M_FUNCTION[CLOCK_INFERED, CLOCK_INT, CLOCK_REAL, CLOCK_BOOL, CLOCK_SOLVER],
        true,
        true,
      ),
      C_NO_CACHE(),
      C_NO_CACHE(),
    )),
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode

const CLOCK_CREF =
  COMPONENT_REF_CREF(
    CLOCK_NODE,
    nil,
    TYPE_INTEGER(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef

@exportAll()
end
