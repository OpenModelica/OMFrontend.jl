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
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
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

module SCode

using MetaModelica
import OpenModelicaParser.Absyn: SourceInfo, SOURCEINFO, sourceInfo
#= ExportAll is not good practice but it makes it so that we do not have to write export after each function :( =#
using ExportAll
#= Necessary to write declarations for your uniontypes until Julia adds support for mutually recursive types =#

@UniontypeDecl Restriction
@UniontypeDecl FunctionRestriction
@UniontypeDecl Mod
@UniontypeDecl ClassDef
@UniontypeDecl EEquation
@UniontypeDecl Statement
@UniontypeDecl Visibility
@UniontypeDecl Redeclare
@UniontypeDecl Replaceable
@UniontypeDecl Final
@UniontypeDecl Each
@UniontypeDecl Encapsulated
@UniontypeDecl Partial
@UniontypeDecl ConnectorType
@UniontypeDecl Element
@UniontypeDecl Parallelism
@UniontypeDecl Variability
@UniontypeDecl Initial

import OpenModelicaParser.Absyn

#= Some definitions are aliased from Absyn =#

const Ident = Absyn.Ident
const Path = Absyn.Path
const Subscript = Absyn.Subscript

#= The single-variant types are plain structs. They come before the uniontypes whose records hold them;
   their own fields name only types declared above. =#

"""
    ANNOTATION(modification)

An `annotation(...)`: its contents as a modification.
"""
struct ANNOTATION
  modification::Mod
end

"""
    COMMENT(annotation_, comment)

The annotation and the description string of an element, equation or statement.
"""
struct COMMENT
  annotation_::Option{ANNOTATION}
  comment::Option{String}
end

"""
    NAMEMOD(ident, mod)

A modification of the named component `ident`. Modifications are more structured than in Absyn: one with a
qualified name (`x.y = z`) is normalized to `x(y = z)`.
"""
struct NAMEMOD
  ident::Ident
  mod::Mod
end

"""
    ENUM(literal, comment)

A literal of an enumeration and its comment.
"""
struct ENUM
  literal::Ident
  comment::COMMENT
end

"""
    EXTERNALDECL(funcName, lang, output_, args, annotation_)

The `external` declaration of a function: the external function's name, its language, the output parameter
returned as its value, its arguments (positional only, as expressions), and its annotation.
"""
struct EXTERNALDECL
  funcName::Option{Ident}
  lang::Option{String}
  output_::Option{Absyn.ComponentRef}
  args::List{Absyn.Exp}
  annotation_::Option{ANNOTATION}
end

"""
    EQUATION(eEquation)

An equation of an equation section.
"""
struct EQUATION
  eEquation::EEquation
end

"""
    ALGORITHM(statements)

A whole algorithm section: its statements. (Absyn follows the grammar, where an algorithm is a single
statement.)
"""
struct ALGORITHM
  statements::List{Statement}
end

"""
    CONSTRAINTS(constraints)

A constraint section (Optimica): its constraint expressions.
"""
struct CONSTRAINTS
  constraints::List{Absyn.Exp}
end

"""
    CONSTRAINCLASS(constrainingClass, modifier, comment)

The constraining clause of a replaceable element: `constrainedby constrainingClass(modifier)`.
"""
struct CONSTRAINCLASS
  constrainingClass::Absyn.Path
  modifier::Mod
  comment::COMMENT
end

@Uniontype Restriction begin
  @Record R_CLASS begin
  end

  @Record R_OPTIMIZATION begin
  end

  @Record R_MODEL begin
  end

  @Record R_RECORD begin
    isOperator::Bool
  end

  @Record R_BLOCK begin
  end

  @Record R_CONNECTOR begin
    isExpandable #= is expandable? =#::Bool
  end

  @Record R_OPERATOR begin
  end

  @Record R_TYPE begin
  end

  @Record R_PACKAGE begin
  end

  @Record R_FUNCTION begin
    functionRestriction::FunctionRestriction
  end

  @Record R_ENUMERATION begin
  end

  #= predefined internal types =#

  @Record R_PREDEFINED_INTEGER begin
  end

  @Record R_PREDEFINED_REAL begin
  end

  @Record R_PREDEFINED_STRING begin
  end

  @Record R_PREDEFINED_BOOLEAN begin
  end

  @Record R_PREDEFINED_ENUMERATION begin
  end

  #= BTH =#

  @Record R_PREDEFINED_CLOCK begin
  end

  #= MetaModelica extensions =#

  @Record R_METARECORD begin
    name::Absyn.Path
    #= Name of the uniontype =#
    index::ModelicaInteger
    #= Index in the uniontype =#
    singleton::Bool
    moved::Bool
    #= true if moved outside uniontype, otherwise false. =#
    typeVars::List{String}
  end

  #= /* added by x07simbj */ =#

  @Record R_UNIONTYPE begin
    typeVars::List{String}
  end

  #= /* added by simbj */ =#
end

#= Same as Absyn.FunctionRestriction except this contains
FR_EXTERNAL_FUNCTION and FR_RECORD_CONSTRUCTOR. =#

@Uniontype FunctionRestriction begin
  @Record FR_NORMAL_FUNCTION begin
    isImpure #= true for impure functions, false otherwise =#::Bool
  end

  @Record FR_EXTERNAL_FUNCTION begin
    isImpure #= true for impure functions, false otherwise =#::Bool
  end

  @Record FR_OPERATOR_FUNCTION begin
  end

  @Record FR_RECORD_CONSTRUCTOR begin
  end

  @Record FR_PARALLEL_FUNCTION begin
  end

  @Record FR_KERNEL_FUNCTION begin
  end
end

#= - Modifications =#
@Uniontype Mod begin
  @Record MOD begin
    finalPrefix #= final prefix =#::Final
    eachPrefix #= each prefix =#::Each
    subModLst::List{NAMEMOD}
    binding::Option{Absyn.Exp}
    info::SourceInfo
  end

  @Record REDECL begin
    finalPrefix #= final prefix =#::Final
    eachPrefix #= each prefix =#::Each
    element #= The new element declaration. =#::Element
  end

  #= Selective model extension (Modelica 3.6): `extends A(break x)` removes component x. =#
  @Record BREAK_COMPONENT begin
    info::SourceInfo
  end

  #= `extends A(break connect(a, b))` removes that connect-equation of the base class. =#
  @Record BREAK_CONNECT begin
    lhs::Absyn.ComponentRef
    rhs::Absyn.ComponentRef
    info::SourceInfo
  end

  @Record NOMOD begin
  end
end

"""As in the AST, a program is a list of class definitions."""
const Program = List

"""
    PREFIXES(visibility, redeclarePrefix, finalPrefix, innerOuter, replaceablePrefix)

The prefixes common to classes and components: public/protected, redeclare, final (on the element or at the
top level), inner/outer, and replaceable (with its constraining class).
"""
struct PREFIXES
  visibility::Visibility
  redeclarePrefix::Redeclare
  finalPrefix::Final
  innerOuter::Absyn.InnerOuter
  replaceablePrefix::Replaceable
end

"""
    ATTR(arrayDims, connectorType, parallelism, variability, direction, isField, mode)

The attributes of a component: its array dimensions, connector type (flow, stream or potential), parallelism
(parglobal, parlocal, none), variability (constant, parameter, discrete, continuous), direction (input, output,
bidirectional), field or non-field, and `mode`.
"""
struct ATTR
  arrayDims::Absyn.ArrayDim
  connectorType::ConnectorType
  parallelism::Parallelism
  variability::Variability
  direction::Absyn.Direction
  isField::Absyn.IsField
  mode::Bool
end

#= The major difference between these types and their Absyn
counterparts is that the PARTS constructor contains separate
lists for elements, equations and algorithms.

SCode.PARTS contains elements of a class definition. For instance,
   model A
     extends B;
     C c;
   end A;
Here PARTS contains two elements ('extends B' and 'C c')
SCode.DERIVED is used for short class definitions, i.e:
 class A = B[ArrayDims](modifiers);
SCode.CLASS_EXTENDS is used for extended class definition, i.e:
 class extends A (modifier)
   new elements;
 end A; =#
@Uniontype ClassDef begin
  @Record PARTS begin
    elementLst #= the list of elements =#::List{Element}
    normalEquationLst #= the list of equations =#::List{EQUATION}
    initialEquationLst #= the list of initial equations =#::List{EQUATION}
    normalAlgorithmLst #= the list of algorithms =#::List{ALGORITHM}
    initialAlgorithmLst #= the list of initial algorithms =#::List{ALGORITHM}
    constraintLst #= the list of constraints =#::List{CONSTRAINTS}
    clsattrs #= the list of class attributes. Currently for Optimica extensions =#::List{Absyn.NamedArg}
    externalDecl #= used by external functions =#::Option{EXTERNALDECL}
  end

  @Record CLASS_EXTENDS begin
    modifications #= the modifications that need to be applied to the base class =#::Mod
    composition #= the new composition =#::ClassDef
  end

  @Record DERIVED begin
    typeSpec #= typeSpec: type specification =#::Absyn.TypeSpec
    modifications #= the modifications =#::Mod
    attributes #= the element attributes =#::ATTR
  end

  @Record ENUMERATION begin
    enumLst #= if the list is empty it means :, the supertype of all enumerations =#::List{ENUM}
  end

  @Record OVERLOAD begin
    pathLst #= the path lists =#::List{Absyn.Path}
  end

  @Record PDER begin
    functionPath #= function name =#::Absyn.Path
    derivedVariables #= derived variables =#::List{Ident}
  end
end

const noComment = COMMENT(NONE(), NONE())::COMMENT

#= These represent equations and are almost identical to their Absyn versions.
In EQ_IF the elseif branches are represented as normal else branches with
a single if statement in them. =#
@Uniontype EEquation begin
  @Record EQ_IF begin
    condition #= conditional =#::List{Absyn.Exp}
    thenBranch #= the true (then) branch =#::List{List{EEquation}}
    elseBranch #= the false (else) branch =#::List{EEquation}
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_EQUALS begin
    expLeft #= the expression on the left side of the operator =#::Absyn.Exp
    expRight #= the expression on the right side of the operator =#::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_PDE begin
    expLeft #= the expression on the left side of the operator =#::Absyn.Exp
    expRight #= the expression on the right side of the operator =#::Absyn.Exp
    domain #= domain for PDEs =#::Absyn.ComponentRef
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_CONNECT begin
    crefLeft #= the connector/component reference on the left side =#::Absyn.ComponentRef
    crefRight #= the connector/component reference on the right side =#::Absyn.ComponentRef
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_FOR begin
    index #= the index name =#::Ident
    range #= the range of the index =#::Option{Absyn.Exp}
    eEquationLst #= the equation list =#::List{EEquation}
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_WHEN begin
    condition #= the when condition =#::Absyn.Exp
    eEquationLst #= the equation list =#::List{EEquation}
    elseBranches #= the elsewhen expression and equation list =#::List{Tuple{Absyn.Exp, List{EEquation}}}
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_RECONFIGURE begin
    variables        #= Parameters exposed to the agent =#::List{Absyn.ElementItem}
    whenClauses      #= Trigger condition and optional invariant =#::List{Absyn.WhenClause}
    prompt           #= Natural-language prompt for the agent =#::Option{Absyn.Exp}
    initialEquations #= Constraints checked at recompilation time =#::Option{List{Absyn.EquationItem}}
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_ASSERT begin
    condition #= the assert condition =#::Absyn.Exp
    message #= the assert message =#::Absyn.Exp
    level::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_TERMINATE begin
    message #= the terminate message =#::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_REINIT begin
    cref #= the variable to initialize =#::Absyn.Exp
    expReinit #= the new value =#::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record EQ_NORETCALL begin
    exp::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end
end

#= The Statement type describes one algorithm statement in an algorithm section. =#
@Uniontype Statement begin
  @Record ALG_ASSIGN begin
    assignComponent #= assignComponent =#::Absyn.Exp
    value #= value =#::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_IF begin
    boolExpr::Absyn.Exp
    trueBranch::List{Statement}
    elseIfBranch::List{Tuple{Absyn.Exp, List{Statement}}}
    elseBranch::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_FOR begin
    index #= the index name =#::Ident
    range #= the range of the index =#::Option{Absyn.Exp}
    forBody #= forBody =#::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_PARFOR begin
    index #= the index name =#::Ident
    range #= the range of the index =#::Option{Absyn.Exp}
    parforBody #= parallel for loop body =#::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_WHILE begin
    boolExpr #= boolExpr =#::Absyn.Exp
    whileBody #= whileBody =#::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_WHEN_A begin
    branches::List{Tuple{Absyn.Exp, List{Statement}}}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_ASSERT begin
    condition::Absyn.Exp
    message::Absyn.Exp
    level::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_TERMINATE begin
    message::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_REINIT begin
    cref::Absyn.Exp
    newValue::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_NORETCALL begin
    exp::Absyn.Exp
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_RETURN begin
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_BREAK begin
    comment::COMMENT
    info::SourceInfo
  end

  #= MetaModelica extensions =#

  @Record ALG_FAILURE begin
    stmts::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_TRY begin
    body::List{Statement}
    elseBody::List{Statement}
    comment::COMMENT
    info::SourceInfo
  end

  @Record ALG_CONTINUE begin
    comment::COMMENT
    info::SourceInfo
  end
end

#= common prefixes to elements =#

#= the visibility prefix =#
@Uniontype Visibility begin
  @Record PUBLIC begin
  end

  @Record PROTECTED begin
  end
end

#= the redeclare prefix =#
@Uniontype Redeclare begin
  @Record REDECLARE begin
  end

  @Record NOT_REDECLARE begin
  end
end

#= the replaceable prefix =#
@Uniontype Replaceable begin
  @Record REPLACEABLE begin
    cc #= the constraint class =#::Option{CONSTRAINCLASS}
  end

  @Record NOT_REPLACEABLE begin
  end
end

#= the final prefix =#
@Uniontype Final begin
  @Record FINAL begin
  end

  @Record NOT_FINAL begin
  end
end

#= the each prefix =#
@Uniontype Each begin
  @Record EACH begin
  end

  @Record NOT_EACH begin
  end
end

#= the encapsulated prefix =#
@Uniontype Encapsulated begin
  @Record ENCAPSULATED begin
  end

  @Record NOT_ENCAPSULATED begin
  end
end

#= the partial prefix =#
@Uniontype Partial begin
  @Record PARTIAL begin
  end

  @Record NOT_PARTIAL begin
  end
end

@Uniontype ConnectorType begin
  @Record POTENTIAL begin
  end

  @Record FLOW begin
  end

  @Record STREAM begin
  end
end

#= - Elements
 There are four types of elements in a declaration, represented by the constructors:
 IMPORT     (for import clauses)
 EXTENDS    (for extends clauses),
 CLASS      (for top/local class definitions)
 COMPONENT  (for local variables)
 DEFINEUNIT (for units) =#
@Uniontype Element begin
  @Record IMPORT begin
    imp #= the import definition =#::Absyn.Import
    visibility #= the protected/public prefix =#::Visibility
    info #= the import information =#::SourceInfo
  end

  @Record EXTENDS begin
    baseClassPath #= the extends path =#::Path
    visibility #= the protected/public prefix =#::Visibility
    modifications #= the modifications applied to the base class =#::Mod
    ann #= the extends annotation =#::Option{ANNOTATION}
    info #= the extends info =#::SourceInfo
  end

  @Record CLASS begin
    name #= the name of the class =#::Ident
    prefixes #= the common class or component prefixes =#::PREFIXES
    encapsulatedPrefix #= the encapsulated prefix =#::Encapsulated
    partialPrefix #= the partial prefix =#::Partial
    restriction #= the restriction of the class =#::Restriction
    classDef #= the class specification =#::ClassDef
    cmt #= the class annotation and string-comment =#::COMMENT
    info #= the class information =#::SourceInfo
  end

  @Record COMPONENT begin
    name #= the component name =#::Ident
    prefixes #= the common class or component prefixes =#::PREFIXES
    attributes #= the component attributes =#::ATTR
    typeSpec #= the type specification =#::Absyn.TypeSpec
    modifications #= the modifications to be applied to the component =#::Mod
    comment #= this if for extraction of comments and annotations from Absyn =#::COMMENT
    condition #= the conditional declaration of a component =#::Option{Absyn.Exp}
    info #= this is for line and column numbers, also file name. =#::SourceInfo
  end

  @Record DEFINEUNIT begin
    name::Ident
    visibility #= the protected/public prefix =#::Visibility
    exp #= the unit expression =#::Option{String}
    weight #= the weight =#::Option{ModelicaReal}
  end
end

#= Parallelism =#
@Uniontype Parallelism begin
  @Record PARGLOBAL begin
  end

  @Record PARLOCAL begin
  end

  @Record NON_PARALLEL begin
  end
end

#= the variability of a component =#
@Uniontype Variability begin
  @Record VAR begin
  end

  @Record DISCRETE begin
  end

  @Record PARAM begin
  end

  @Record CONST begin
  end
end

#= /* adrpo: previously present in Inst.mo */ =#

#= the initial attribute of an algorithm or equation
Intial is used as argument to instantiation-function for
specifying if equations or algorithms are initial or not. =#
@Uniontype Initial begin
  @Record INITIAL begin
  end

  @Record NON_INITIAL begin
  end
end

const defaultPrefixes = PREFIXES(PUBLIC(), NOT_REDECLARE(), NOT_FINAL(), Absyn.NOT_INNER_OUTER(), NOT_REPLACEABLE())::PREFIXES

const defaultVarAttr = ATTR(list(), POTENTIAL(), NON_PARALLEL(), VAR(), Absyn.BIDIR(), Absyn.NONFIELD(), false)::ATTR

const defaultInputAttr = ATTR(list(), POTENTIAL(), NON_PARALLEL(), VAR(), Absyn.INPUT(), Absyn.NONFIELD(), false)::ATTR

const defaultOutputAttr = ATTR(list(), POTENTIAL(), NON_PARALLEL(), VAR(), Absyn.OUTPUT(), Absyn.NONFIELD(), false)::ATTR

#= So that we can use wildcard imports and named imports when they do occur. Not good Julia practice =#
@exportAll()
end
