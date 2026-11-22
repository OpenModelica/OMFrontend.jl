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
import OpenModelicaParser.Absyn
import ..SCode

using ..Frontend
using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
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
#= Default Integer parameter. =#
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
#= Default Real parameter. =#
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
#= Default Boolean parameter. =#
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
#= Default String parameter. =#
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
#= Default enumeration(:) parameter. =#
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
#= Integer(e) =#
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
  MODELICA_FUNCTION(
    Absyn.IDENT("Integer"),
    INTEGER_DUMMY_NODE,
    list(ENUM_PARAM),
    nil,
    nil,
    list(SLOT(
      "e",
      SLOT_TYPE_POSITIONAL,
      NONE(),
      NONE(),
      1,
      SLOT_NOT_EVALUATED,
    )),
    TYPE_INTEGER(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
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
      C_FUNCTION(MODELICA_FUNCTION[INTEGER_FUNCTION], true, false),
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
#= String(r, significantDigits=d, minimumLength=0, leftJustified=true) =#
const STRING_REAL =
  MODELICA_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(REAL_PARAM, INT_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "r",
        SLOT_TYPE_POSITIONAL,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "significantDigits",
        SLOT_TYPE_NAMED,
        SOME(INTEGER_EXPRESSION(6)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SLOT_TYPE_NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        3,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SLOT_TYPE_NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        4,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= String(r, format=\"-0.6g\") =#
const STRING_REAL_FORMAT =
  MODELICA_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(REAL_PARAM, STRING_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "r",
        SLOT_TYPE_POSITIONAL,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "format",
        SLOT_TYPE_NAMED,
        NONE(),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= String(i, minimumLength=0, leftJustified=true) =#
const STRING_INT =
  MODELICA_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(INT_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "i",
        SLOT_TYPE_POSITIONAL,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SLOT_TYPE_NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SLOT_TYPE_NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= String(b, minimumLength=0, leftJustified=true) =#
const STRING_BOOL =
  MODELICA_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(BOOL_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "b",
        SLOT_TYPE_POSITIONAL,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SLOT_TYPE_NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SLOT_TYPE_NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= String(e, minimumLength=0, leftJustified=true) =#
const STRING_ENUM =
  MODELICA_FUNCTION(
    Absyn.IDENT("String"),
    STRING_DUMMY_NODE,
    list(ENUM_PARAM, INT_PARAM, BOOL_PARAM),
    list(STRING_PARAM),
    nil,
    list(
      SLOT(
        "e",
        SLOT_TYPE_POSITIONAL,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "minimumLength",
        SLOT_TYPE_NAMED,
        SOME(INTEGER_EXPRESSION(0)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "leftJustified",
        SLOT_TYPE_NAMED,
        SOME(BOOLEAN_EXPRESSION(true)),
        NONE(),
        3,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_STRING(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
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
        MODELICA_FUNCTION[STRING_ENUM, STRING_INT, STRING_BOOL, STRING_REAL, STRING_REAL_FORMAT],
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
  MODELICA_FUNCTION(
    Absyn.IDENT("abs"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const MAX_INT =
  MODELICA_FUNCTION(
    Absyn.IDENT("max"),
    EMPTY_NODE(),
    list(INT_PARAM, INT_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const MAX_REAL =
  MODELICA_FUNCTION(
    Absyn.IDENT("max"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const DIV_INT =
  MODELICA_FUNCTION(
    Absyn.IDENT("div"),
    EMPTY_NODE(),
    list(INT_PARAM, INT_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const FLOOR =
  MODELICA_FUNCTION(
    Absyn.IDENT("floor"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const INTEGER_REAL =
  MODELICA_FUNCTION(
    Absyn.IDENT("integer"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const INTEGER_ENUM =
  MODELICA_FUNCTION(
    Absyn.IDENT("Integer"),
    EMPTY_NODE(),
    list(ENUM_PARAM),
    list(INT_PARAM),
    nil,
    nil,
    TYPE_INTEGER(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const POSITIVE_MAX_REAL =
  MODELICA_FUNCTION(
    Absyn.IDENT("OMCPositiveMax"),
    EMPTY_NODE(),
    list(REAL_PARAM, REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const IN_STREAM =
  MODELICA_FUNCTION(
    Absyn.IDENT("inStream"),
    EMPTY_NODE(),
    list(REAL_PARAM),
    list(REAL_PARAM),
    nil,
    nil,
    TYPE_REAL(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const PROMOTE =
  MODELICA_FUNCTION(
    Absyn.IDENT("promote"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const CAT =
  MODELICA_FUNCTION(
    Absyn.IDENT("cat"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
const ARRAY_FUNC =
  MODELICA_FUNCTION(
    Absyn.IDENT("array"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION

const FILL_FUNC =
  MODELICA_FUNCTION(
    Absyn.IDENT("fill"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION

const SMOOTH =
  MODELICA_FUNCTION(
    Absyn.IDENT("smooth"),
    EMPTY_NODE(),
    nil,
    nil,
    nil,
    nil,
    TYPE_UNKNOWN(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
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
#= Clock() - inferred clock =#
const CLOCK_INFERED =
  MODELICA_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    nil,
    list(CLOCK_PARAM),
    nil,
    nil,
    TYPE_CLOCK(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= Clock(intervalCounter, resolution = 1) - clock with Integer interval =#
const CLOCK_INT =
  MODELICA_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(INT_PARAM, INT_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT(
        "intervalCounter",
        SLOT_TYPE_GENERIC,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "resolution",
        SLOT_TYPE_GENERIC,
        SOME(INTEGER_EXPRESSION(1)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= Clock(interval) - clock with Real interval =#
const CLOCK_REAL =
  MODELICA_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(REAL_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(SLOT(
      "interval",
      SLOT_TYPE_GENERIC,
      NONE(),
      NONE(),
      1,
      SLOT_NOT_EVALUATED,
    )),
    TYPE_CLOCK(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= Clock(condition, startInterval = 0.0) - Boolean clock, triggered by zero-crossing events =#
const CLOCK_BOOL =
  MODELICA_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(BOOL_PARAM, REAL_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT(
        "condition",
        SLOT_TYPE_GENERIC,
        NONE(),
        NONE(),
        1,
        SLOT_NOT_EVALUATED,
      ),
      SLOT(
        "startInterval",
        SLOT_TYPE_GENERIC,
        SOME(REAL_EXPRESSION(0.0)),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
#= Clock(c, solverMethod) - Solver clock =#
const CLOCK_SOLVER =
  MODELICA_FUNCTION(
    Absyn.IDENT("Clock"),
    CLOCK_DUMMY_NODE,
    list(CLOCK_PARAM, STRING_PARAM),
    list(CLOCK_PARAM),
    nil,
    list(
      SLOT("c", SLOT_TYPE_GENERIC, NONE(), NONE(), 1, SLOT_NOT_EVALUATED),
      SLOT(
        "solverMethod",
        SLOT_TYPE_GENERIC,
        NONE(),
        NONE(),
        2,
        SLOT_NOT_EVALUATED,
      ),
    ),
    TYPE_CLOCK(),
    FUNCTION_ATTRIBUTES_BUILTIN,
    nil,
    P_Pointer.create(FUNCTION_STATUS_BUILTIN, FunctionStatus),
    P_Pointer.create(0, Int),
  )::MODELICA_FUNCTION
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
        MODELICA_FUNCTION[CLOCK_INFERED, CLOCK_INT, CLOCK_REAL, CLOCK_BOOL, CLOCK_SOLVER],
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
