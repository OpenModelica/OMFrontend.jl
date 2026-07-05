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

module NFBuiltin

using MetaModelica
using MetaModelica.Dangerous
using ExportAll

import ..SCode
import Absyn
import ..AbsynUtil

module Elements
using MetaModelica
using ExportAll
import Absyn
import ..SCode
import ..AbsynUtil
#=  Default parts of the declarations for builtin elements and types:
=#

const ENUMTYPE_SPEC = Absyn.TPATH(Absyn.IDENT("EnumType"), NONE())::Absyn.TypeSpec
#=  StateSelect-specific elements: =#
const REAL =
  SCode.CLASS(
    "Real",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const INTEGER_EXPRESSION =
  SCode.CLASS(
    "Integer",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const BOOLEAN =
  SCode.CLASS(
    "Boolean",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const STRING =
  SCode.CLASS(
    "String",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const ENUMERATION =
  SCode.CLASS(
    "enumeration",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const ANY =
  SCode.CLASS(
    "polymorphic",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_TYPE(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element
const CLOCK =
  SCode.CLASS(
    "Clock",
    SCode.defaultPrefixes,
    SCode.NOT_ENCAPSULATED(),
    SCode.NOT_PARTIAL(),
    SCode.R_PREDEFINED_CLOCK(),
    SCode.PARTS(nil, nil, nil, nil, nil, nil, nil, NONE()),
    SCode.noComment,
    AbsynUtil.dummyInfo,
  )::SCode.Element #= the Clock type =#

@exportAll()
end

import ..Frontend.C_FUNCTION
import ..Frontend.M_FUNCTION
import ..Frontend.Visibility
import ..Frontend.VisibilityType
import ..P_Pointer
import ..Frontend.DEFAULT_PREFIXES
import ..Frontend.TYPE_POLYMORPHIC
import ..Frontend.CLASS_TREE_EMPTY_TREE
import ..Frontend.MODIFIER_NOMOD
import ..Frontend.RESTRICTION_TYPE
#import ..Frontend.EMPTY_NODE_CACHE
import ..Frontend.EMPTY_NODE
import ..Frontend.BUILTIN_CLASS
import ..Frontend.PARTIAL_BUILTIN
import ..Frontend.CLASS_NODE
import ..Frontend.RESTRICTION_TYPE

#= Types =#
import ..Frontend.TYPE_STRING
import ..Frontend.TYPE_ATTRIBUTE
import ..Frontend.TYPE_ENUMERATION
import ..Frontend.TYPE_INTEGER
import ..Frontend.TYPE_REAL
import ..Frontend.TYPE_BOOLEAN
import ..Frontend.CachedData
import ..Frontend.InstNode

#= Modules =#
import ..LookupTree

import ..Frontend.NORMAL_COMP
import ..Frontend.COMPONENT_NODE
#import ..Frontend.STATESELECT_TYPE

import ..DuplicateTree

import ..Frontend.CLASS_TREE_FLAT_TREE
import ..Frontend.ClassTree

import ..Frontend.Origin
import ..Frontend.COMPONENT_REF_EMPTY
import ..Frontend.COMPONENT_REF_CREF
import ..Frontend.ComponentRef
import ..Frontend.TYPE_ENUMERATION_ANY
import ..Frontend.RESTRICTION_ENUMERATION
import ..Frontend.ENUM_LITERAL_EXPRESSION
import ..Frontend.Expression
import ..Frontend.TYPE_CLOCK
import ..Frontend.RESTRICTION_CLOCK
import ..Frontend.TYPED_COMPONENT
import ..Frontend.EMPTY_BINDING
import ..Frontend.INPUT_ATTR

const EMPTY_NODE_CACHE::Vector{CachedData} = CachedData[C_FUNCTION(M_FUNCTION[], true, true)]
#=  InstNodes for the builtin types. These have empty class trees to prevent
=#
#=  access to the attributes via dot notation (which is not needed for
=#
#=  modifiers and illegal in other cases).
=#
const POLYMORPHIC_NODE =
  CLASS_NODE(
    "polymorphic",
    Elements.ANY,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_POLYMORPHIC(""),
      CLASS_TREE_EMPTY_TREE(),
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
#=  Lookup tree for Real. Generated by makeBuiltinLookupTree.
=#
const REAL_LOOKUP_TREE =
  LookupTree.NODE(
    "quantity",
     LookupTree.COMPONENT(1),
     4,
    LookupTree.NODE(
      "max",
       LookupTree.COMPONENT(5),
       3,
      LookupTree.NODE(
        "displayUnit",
         LookupTree.COMPONENT(3),
         2,
        LookupTree.EMPTY(),
         LookupTree.LEAF(
          "fixed",
           LookupTree.COMPONENT(7),
        ),
      ),
       LookupTree.NODE(
        "min",
         LookupTree.COMPONENT(4),
         2,
        LookupTree.EMPTY(),
         LookupTree.LEAF(
          "nominal",
           LookupTree.COMPONENT(8),
        ),
      ),
    ),
     LookupTree.NODE(
      "unbounded",
       LookupTree.COMPONENT(9),
       3,
      LookupTree.NODE(
        "start",
         LookupTree.COMPONENT(6),
         2,
        LookupTree.EMPTY(),
         LookupTree.LEAF(
          "stateSelect",
           LookupTree.COMPONENT(10),
        ),
      ),
       LookupTree.LEAF(
        "unit",
         LookupTree.COMPONENT(2),
      ),
    ),
  )::LookupTree.Tree



const STATESELECT_TYPE =
  TYPE_ENUMERATION(
    Absyn.IDENT("StateSelect"),
    list("never", "avoid", "default", "prefer", "always"),
  )

const REAL_CLASS_TREE =
  CLASS_TREE_FLAT_TREE(
    REAL_LOOKUP_TREE,
    listArrayLiteral(nil),
    listArrayLiteral(list(
      COMPONENT_NODE(
        "quantity",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "unit",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "displayUnit",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "min",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_REAL(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "max",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_REAL(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "start",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_REAL(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "fixed",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "nominal",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_REAL(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "unbounded",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "stateSelect",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          STATESELECT_TYPE,
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
    )),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )::ClassTree
#=  TODO: #4895: This should be listArrayLiteral too, but causes compilation issues. =#
const REAL_NODE =
  CLASS_NODE(
    "Real",
    Elements.REAL,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_REAL(),
      REAL_CLASS_TREE,
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
#=  Lookup tree for Integer. Generated by makeBuiltinLookupTree.
=#
const INTEGER_LOOKUP_TREE =
  LookupTree.NODE(
    "min",
     LookupTree.COMPONENT(2),
     3,
    LookupTree.NODE(
      "max",
       LookupTree.COMPONENT(3),
       2,
      LookupTree.LEAF(
        "fixed",
         LookupTree.COMPONENT(5),
      ),
       LookupTree.EMPTY(),
    ),
     LookupTree.NODE(
      "quantity",
       LookupTree.COMPONENT(1),
       2,
      LookupTree.EMPTY(),
       LookupTree.LEAF(
        "start",
         LookupTree.COMPONENT(4),
      ),
    ),
  )::LookupTree.Tree
const INTEGER_CLASS_TREE =
  CLASS_TREE_FLAT_TREE(
    INTEGER_LOOKUP_TREE,
    listArrayLiteral(nil),
    listArrayLiteral(list(
      COMPONENT_NODE(
        "quantity",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "min",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_INTEGER(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "max",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_INTEGER(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "start",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_INTEGER(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "fixed",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
    )),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )::ClassTree
#=  TODO: #4895: This should be listArrayLiteral too, but causes compilation issues.
=#
const INTEGER_NODE =
  CLASS_NODE(
    "Integer",
    Elements.INTEGER_EXPRESSION,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_INTEGER(),
      INTEGER_CLASS_TREE,
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
#=  Lookup tree for Boolean. Generated by makeBuiltinLookupTree. =#
const BOOLEAN_LOOKUP_TREE =
  LookupTree.NODE(
    "quantity",
     LookupTree.COMPONENT(1),
     2,
    LookupTree.LEAF(
      "fixed",
       LookupTree.COMPONENT(3),
    ),
     LookupTree.LEAF(
      "start",
       LookupTree.COMPONENT(2),
    ),
  )::LookupTree.Tree
const BOOLEAN_CLASS_TREE =
  CLASS_TREE_FLAT_TREE(
    BOOLEAN_LOOKUP_TREE,
    listArrayLiteral(nil),
    listArrayLiteral(list(
      COMPONENT_NODE(
        "quantity",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "start",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "fixed",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
    )),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )::ClassTree


#=  TODO: #4895: This should be listArrayLiteral too, but causes compilation issues.
=#
const BOOLEAN_NODE =
  CLASS_NODE(
    "Boolean",
    Elements.BOOLEAN,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_BOOLEAN(),
      BOOLEAN_CLASS_TREE,
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode

const BOOLEAN_CREF =
  COMPONENT_REF_CREF(
    BOOLEAN_NODE,
    nil,
    TYPE_INTEGER(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef
#=  Lookup tree for String. Generated by makeBuiltinLookupTree.
=#
const STRING_LOOKUP_TREE =
  LookupTree.NODE(
    "quantity",
     LookupTree.COMPONENT(1),
     2,
    LookupTree.LEAF(
      "fixed",
       LookupTree.COMPONENT(3),
    ),
     LookupTree.LEAF(
      "start",
       LookupTree.COMPONENT(2),
    ),
  )::LookupTree.Tree
const STRING_CLASS_TREE =
  CLASS_TREE_FLAT_TREE(
    STRING_LOOKUP_TREE,
    listArrayLiteral(nil),
    listArrayLiteral(list(
      COMPONENT_NODE(
        "quantity",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "start",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "fixed",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_BOOLEAN(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
    )),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )::ClassTree
#=  TODO: #4895: This should be listArrayLiteral too, but causes compilation issues. =#
const STRING_NODE =
  CLASS_NODE(
    "String",
    Elements.STRING,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_STRING(),
      STRING_CLASS_TREE,
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_TYPE(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
#=  Lookup tree for enumerations. Generated by makeBuiltinLookupTree.
=#
#=  NOTE: The enumeration attributes themselves are created by ClassTree.fromEnumeration,
=#
#=        so any changes to this lookup tree requires fromEnumeration to be updated too.
=#
const ENUM_LOOKUP_TREE =
  LookupTree.NODE(
    "min",
     LookupTree.COMPONENT(2),
     3,
    LookupTree.NODE(
      "max",
       LookupTree.COMPONENT(3),
       2,
      LookupTree.LEAF(
        "fixed",
         LookupTree.COMPONENT(5),
      ),
       LookupTree.EMPTY(),
    ),
     LookupTree.NODE(
      "quantity",
       LookupTree.COMPONENT(1),
       2,
      LookupTree.EMPTY(),
       LookupTree.LEAF(
        "start",
         LookupTree.COMPONENT(4),
      ),
    ),
  )::LookupTree.Tree

function GET_ENUM_LOOKUP_TREE()
    LookupTree.NODE(
    "min",
     LookupTree.COMPONENT(2),
     3,
    LookupTree.NODE(
      "max",
       LookupTree.COMPONENT(3),
       2,
      LookupTree.LEAF(
        "fixed",
         LookupTree.COMPONENT(5),
      ),
       LookupTree.EMPTY(),
    ),
      LookupTree.NODE(
      "quantity",
       LookupTree.COMPONENT(1),
       2,
      LookupTree.EMPTY(),
       LookupTree.LEAF(
        "start",
         LookupTree.COMPONENT(4),
      ),
    ),
  )::LookupTree.Tree
end

const ENUM_NODE =
  CLASS_NODE(
    "enumeration",
    Elements.ENUMERATION,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_ENUMERATION_ANY(),
      CLASS_TREE_EMPTY_TREE(),
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_ENUMERATION(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode

const ASSERTIONLEVEL_TYPE =
  TYPE_ENUMERATION(Absyn.IDENT("AssertionLevel"),
                   list("warning", "error"))

const ASSERTIONLEVEL_WARNING =
  ENUM_LITERAL_EXPRESSION(ASSERTIONLEVEL_TYPE
                                                         ,"warning"
                                                         ,1)
const ASSERTIONLEVEL_ERROR =
  ENUM_LITERAL_EXPRESSION(ASSERTIONLEVEL_TYPE
                                                         , "error"
                                                         , 2)

const CLOCK_LOOKUP_TREE =
  LookupTree.NODE(
    "quantity",
     LookupTree.COMPONENT(1),
     2,
    LookupTree.LEAF(
      "fixed",
       LookupTree.COMPONENT(3),
    ),
     LookupTree.LEAF(
      "start",
       LookupTree.COMPONENT(2),
    ),
  )::LookupTree.Tree
const CLOCK_CLASS_TREE =
  CLASS_TREE_FLAT_TREE(
    CLOCK_LOOKUP_TREE,
    listArrayLiteral(nil),
    listArrayLiteral(list(
      COMPONENT_NODE(
        "quantity",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_STRING(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "start",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_CLOCK(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
      COMPONENT_NODE(
        "fixed",
        Visibility.PUBLIC,
        P_Pointer.createImmutable(TYPE_ATTRIBUTE(
          TYPE_CLOCK(),
          MODIFIER_NOMOD(),
        )),
        EMPTY_NODE(),
        NORMAL_COMP(),
      ),
    )),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )::ClassTree
#=  TODO: #4895: This should be listArrayLiteral too, but causes compilation issues. =#
const CLOCK_NODE =
  CLASS_NODE(
    "Clock",
    Elements.CLOCK,
    Visibility.PUBLIC,
    P_Pointer.createImmutable(PARTIAL_BUILTIN(
      TYPE_CLOCK(),
      CLOCK_CLASS_TREE,
      MODIFIER_NOMOD(),
      DEFAULT_PREFIXES,
      RESTRICTION_CLOCK(),
    )),
    EMPTY_NODE_CACHE,
    EMPTY_NODE(),
    BUILTIN_CLASS(),
  )::InstNode
const CLOCK_CREF =
  COMPONENT_REF_CREF(
    CLOCK_NODE,
    nil,
    TYPE_CLOCK(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef
const TIME =
  COMPONENT_NODE(
    "time",
    Visibility.PUBLIC,
    P_Pointer.createImmutable(TYPED_COMPONENT(
      REAL_NODE,
      TYPE_REAL(),
      EMPTY_BINDING,
      EMPTY_BINDING,
      INPUT_ATTR,
      NONE(),
      NONE(),
      AbsynUtil.dummyInfo,
    )),
    EMPTY_NODE(),
    NORMAL_COMP(),
  )::InstNode

const TIME_CREF =
  COMPONENT_REF_CREF(
    TIME,
    nil,
    TYPE_REAL(),
    Origin.CREF,
    COMPONENT_REF_EMPTY(),
  )::ComponentRef

"""
  This function takes lists of component and class names and prints out a lookup tree.
  Useful in case any attributes needs to be added to any of the builtin type.
"""
function makeBuiltinLookupTree(
  name::String,
  components::List{<:String},
  classes::List{<:String} = nil,
) #= Not used in the tree, only to identify the printout. =#
  local ltree::LookupTree.= LookupTree.new()
  local i::Int
  i = 1
  for comp in components
    ltree = LookupTree.add(ltree, comp, LookupTree.COMPONENT(i))
    i = i + 1
  end
  for cls in classes
    ltree = LookupTree.add(ltree, cls, LookupTree.COMPONENT(i))
    i = i + 1
  end
  print("Lookup tree for " + name + ":\\n")
  print(anyString(ltree))
  return print("\\n")
end

"""
Contains the builtin class nodes of the compiler.
"""
const BUILTIN_DICT = Dict{String, InstNode}(
  "Real" => NFBuiltin.REAL_NODE,
  "Integer" => NFBuiltin.INTEGER_NODE,
  "Boolean" => NFBuiltin.BOOLEAN_NODE,
  "String" => NFBuiltin.STRING_NODE,
  "Clock" => NFBuiltin.CLOCK_NODE,
  "polymorphic" => NFBuiltin.POLYMORPHIC_NODE)

import ..LOOKUP_STATE_PREDEF_CLASS
import ..LOOKUP_STATE_PREDEF_COMP
import ..LOOKUP_STATE_FUNC

import ..NFBuiltinFuncs

const BUILTIN_CREF_DICT = Dict{String, Tuple}(
  "time"  =>
    (NFBuiltin.TIME, NFBuiltin.TIME_CREF, LOOKUP_STATE_PREDEF_COMP())
  ,
  "Boolean"  =>
    (NFBuiltin.BOOLEAN_NODE, NFBuiltin.BOOLEAN_CREF, LOOKUP_STATE_PREDEF_CLASS())
  ,
  "Integer"  =>
    (NFBuiltinFuncs.INTEGER_NODE, NFBuiltinFuncs.INTEGER_CREF, LOOKUP_STATE_FUNC())
  ,
  "String"  =>
    (NFBuiltinFuncs.STRING_NODE, NFBuiltinFuncs.STRING_CREF, LOOKUP_STATE_FUNC())
  ,
  #=Shoulld have a check to see if synchronos features are to be available or not. =#
  "Clock"   =>
    (NFBuiltinFuncs.CLOCK_NODE, NFBuiltinFuncs.CLOCK_CREF, LOOKUP_STATE_FUNC()))

@exportAll()
end
