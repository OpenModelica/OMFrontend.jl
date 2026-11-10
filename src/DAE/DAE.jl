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

module DAE

using MetaModelica
using ExportAll

include("DAE_Interface.jl")
include("Values.jl")
include("ClassInf.jl")

import .ClassInf
import .Values
import OMParser.Absyn
import ..SCode

const UNIQUEIO = "uniqueouter"::String

#= pinned-OMC prefixes; the C templates match the $-forms literally =#
const derivativeNamePrefix = "\$DER"::String

const partialDerivativeNamePrefix = "\$pDER"::String

const preNamePrefix = "\$PRE"::String

const previousNamePrefix = "\$CLKPRE"::String

const startNamePrefix = "\$START"::String

const auxNamePrefix = "\$AUX"::String

@Uniontype VarKind begin
  @Record VARIABLE begin
  end

  @Record DISCRETE begin
  end

  @Record PARAM begin
  end

  @Record CONST begin
  end
end

#= The type of a connector element. =#
@Uniontype ConnectorType begin
  @Record POTENTIAL begin
  end

  @Record FLOW begin
  end

  @Record STREAM begin
    associatedFlow::Option{ComponentRef}
  end

  @Record NON_CONNECTOR begin
  end
end

@Uniontype VarDirection begin
  @Record INPUT begin
  end

  @Record OUTPUT begin
  end

  @Record BIDIR begin
  end
end

@Uniontype VarParallelism begin
  @Record PARGLOBAL begin
  end

  @Record PARLOCAL begin
  end

  @Record NON_PARALLEL begin
  end
end

@Uniontype VarVisibility begin
  @Record PUBLIC begin
  end

  @Record PROTECTED begin
  end
end

@Uniontype VarInnerOuter begin
  @Record INNER begin
  end

  @Record OUTER begin
  end

  @Record INNER_OUTER begin
  end

  @Record NOT_INNER_OUTER begin
  end
end

#= gives information about the origin of the element =#
@Uniontype ElementSource begin
  @Record SOURCE begin
    info #= the line and column numbers of the equations and algorithms this element came from =#::SourceInfo
    partOfLst #= the model(s) this element came from =#::List{Absyn.Within}
    instance #= the instance(s) this element is part of =# # TODO ::Prefix.ComponentPrefix
    connectEquationOptLst #= this element came from this connect(s) =#::List{Tuple{ComponentRef, ComponentRef}}
    typeLst #= the classes where the type(s) of the element is defined =#::List{Absyn.Path}
    operations #= the symbolic operations used to end up with the final state of the element =#::List{SymbolicOperation}
    comment::List{SCode.Comment}
  end
end

const dummyInfo = Absyn.SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::Absyn.Info
const emptyElementSource = SOURCE(dummyInfo, nil, nothing #= Prefix.NOCOMPPRE() =#, nil, nil, nil, nil)::ElementSource

function ElementSource_getInfo(source::ElementSource)::SourceInfo
  @match SOURCE(info = info) = source
  return info
end

@Uniontype SymbolicOperation begin
  @Record FLATTEN begin
    scode::SCode.EEquation
    dae::Option{Element}
  end

  @Record SIMPLIFY begin
    before::EquationExp
    after::EquationExp
  end

  @Record SUBSTITUTION begin
    substitutions::List{Exp}
    source::Exp
  end

  @Record OP_INLINE begin
    before::EquationExp
    after::EquationExp
  end

  @Record OP_SCALARIZE begin
    before::EquationExp
    index::ModelicaInteger
    after::EquationExp
  end

  @Record OP_DIFFERENTIATE begin
    cr::ComponentRef
    before::Exp
    after::Exp
  end

  @Record SOLVE begin
    cr::ComponentRef
    exp1::Exp
    exp2::Exp
    res::Exp
    assertConds::List{Exp}
  end

  @Record SOLVED begin
    cr::ComponentRef
    exp::Exp
  end

  @Record LINEAR_SOLVED begin
    vars::List{ComponentRef}
    jac::List{List{ModelicaReal}}
    rhs::List{ModelicaReal}
    result::List{ModelicaReal}
  end

  @Record NEW_DUMMY_DER begin
    chosen::ComponentRef
    candidates::List{ComponentRef}
  end

  @Record OP_RESIDUAL begin
    e1::Exp
    e2::Exp
    e::Exp
  end
end

#= An equation on residual or equality form has 1 or 2 expressions. For use with symbolic operation tracing. =#
@Uniontype EquationExp begin
  @Record PARTIAL_EQUATION begin
    exp::Exp
  end

  @Record RESIDUAL_EXP begin
    exp::Exp
  end

  @Record EQUALITY_EXPS begin
    lhs::Exp
    rhs::Exp
  end
end

@Uniontype Function begin
  @Record FUNCTION begin
    path::Absyn.Path
    functions #= contains the body and an optional function derivative mapping =#::List{FunctionDefinition}
    type_::Type
    visibility::SCode.Visibility
    partialPrefix #= MetaModelica extension =#::Bool
    isImpure #= Modelica 3.3 impure/pure, by default isImpure = false all the time only if prefix *impure* function is specified =#::Bool
    inlineType::InlineType
    source #= the origin of the component/equation/algorithm =#::ElementSource
    comment::Option{SCode.Comment}
  end

  @Record RECORD_CONSTRUCTOR begin
    path::Absyn.Path
    type_::Type
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end
end

@Uniontype InlineType begin
  @Record NORM_INLINE begin
  end

  @Record BUILTIN_EARLY_INLINE begin
  end

  @Record EARLY_INLINE begin
  end

  @Record DEFAULT_INLINE begin
  end

  @Record NO_INLINE begin
  end

  @Record AFTER_INDEX_RED_INLINE begin
  end
end

@Uniontype FunctionDefinition begin
  @Record FUNCTION_DEF begin
    body::List{Element}
  end

  @Record FUNCTION_EXT begin
    body::List{Element}
    externalDecl::ExternalDecl
  end

  @Record FUNCTION_DER_MAPPER begin
    derivedFunction #= Function that is derived =#::Absyn.Path
    derivativeFunction #= Path to derivative function =#::Absyn.Path
    derivativeOrder #= in case a function have multiple derivatives, include all =#::ModelicaInteger
    conditionRefs::List{Tuple{ModelicaInteger, derivativeCond}}
    defaultDerivative #= if conditions fails, use default derivative if exists =#::Option{Absyn.Path}
    lowerOrderDerivatives::List{Absyn.Path}
  end

  @Record FUNCTION_INVERSE begin
    inputParam #= The input parameter the inverse is for =#::ComponentRef
    inverseCall #= The inverse function call =#::Exp
  end

  @Record FUNCTION_PARTIAL_DERIVATIVE begin
    derivedFunction::Absyn.Path
    derivedVars::List{String}
  end
end

#= Different conditions on derivatives =#
@Uniontype derivativeCond begin
  @Record ZERO_DERIVATIVE begin
  end

  @Record NO_DERIVATIVE begin
    binding::Exp
  end
end

@Uniontype VariableAttributes begin
  @Record VAR_ATTR_REAL begin
    quantity #= quantity =#::Option{Exp}
    unit #= unit =#::Option{Exp}
    displayUnit #= displayUnit =#::Option{Exp}
    min::Option{Exp}
    max::Option{Exp}
    start #= start value =#::Option{Exp}
    fixed #= fixed - true: default for parameter/constant, false - default for other variables =#::Option{Exp}
    nominal #= nominal =#::Option{Exp}
    stateSelectOption::Option{StateSelect}
    uncertainOption::Option{Uncertainty}
    distributionOption::Option{Distribution}
    equationBound::Option{Exp}
    isProtected::Option{Bool}
    finalPrefix::Option{Bool}
    startOrigin #= where did start=X came from? NONE()|SOME(SCONST binding|type|undefined) =#::Option{Exp}
  end

  @Record VAR_ATTR_INT begin
    quantity #= quantity =#::Option{Exp}
    min::Option{Exp}
    max::Option{Exp}
    start #= start value =#::Option{Exp}
    fixed #= fixed - true: default for parameter/constant, false - default for other variables =#::Option{Exp}
    uncertainOption::Option{Uncertainty}
    distributionOption::Option{Distribution}
    equationBound::Option{Exp}
    isProtected::Option{Bool}
    #=  ,eb,ip
    =#
    finalPrefix::Option{Bool}
    startOrigin #= where did start=X came from? NONE()|SOME(SCONST binding|type|undefined) =#::Option{Exp}
  end

  @Record VAR_ATTR_BOOL begin
    quantity #= quantity =#::Option{Exp}
    start #= start value =#::Option{Exp}
    fixed #= fixed - true: default for parameter/constant, false - default for other variables =#::Option{Exp}
    equationBound::Option{Exp}
    isProtected::Option{Bool}
    finalPrefix::Option{Bool}
    startOrigin #= where did start=X came from? NONE()|SOME(SCONST binding|type|undefined) =#::Option{Exp}
  end

  @Record VAR_ATTR_CLOCK begin
    isProtected::Option{Bool}
    finalPrefix::Option{Bool}
  end

  @Record VAR_ATTR_STRING begin
    quantity #= quantity =#::Option{Exp}
    start #= start value =#::Option{Exp}
    fixed #= new in Modelica 3.4; fixed - true: default for parameter/constant, false - default for other variables =#::Option{Exp}
    equationBound::Option{Exp}
    isProtected::Option{Bool}
    finalPrefix::Option{Bool}
    startOrigin #= where did start=X came from? NONE()|SOME(SCONST binding|type|undefined) =#::Option{Exp}
  end

  @Record VAR_ATTR_ENUMERATION begin
    quantity #= quantity =#::Option{Exp}
    min::Option{Exp}
    max::Option{Exp}
    start #= start =#::Option{Exp}
    fixed #= fixed - true: default for parameter/constant, false - default for other variables =#::Option{Exp}
    equationBound::Option{Exp}
    isProtected::Option{Bool}
    finalPrefix::Option{Bool}
    startOrigin #= where did start=X came from? NONE()|SOME(SCONST binding|type|undefined) =#::Option{Exp}
  end
end

const emptyVarAttrReal = VAR_ATTR_REAL(NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE())::VariableAttributes

const emptyVarAttrBool = VAR_ATTR_BOOL(NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE())::VariableAttributes

const emptyVarAttrInt = VAR_ATTR_INT(NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE())::VariableAttributes

const emptyVarAttrClock = VAR_ATTR_CLOCK(NONE(), NONE())::VariableAttributes

const emptyVarAttrString = VAR_ATTR_STRING(NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE())::VariableAttributes

const emptyVarAttrEnum = VAR_ATTR_ENUMERATION(NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE(), NONE())::VariableAttributes

@Uniontype StateSelect begin
  @Record NEVER begin
  end

  @Record AVOID begin
  end

  @Record DEFAULT begin
  end

  @Record PREFER begin
  end

  @Record ALWAYS begin
  end
end

@Uniontype Uncertainty begin
  @Record GIVEN begin
  end

  @Record SOUGHT begin
  end

  @Record REFINE begin
  end

  @Record PROPAGATE begin
  end
end

@Uniontype Distribution begin
  @Record DISTRIBUTION begin
    name::Exp
    params::Exp
    paramNames::Exp
  end
end

@Uniontype ExtArg begin
  @Record EXTARG begin
    componentRef::ComponentRef
    direction::Absyn.Direction
    type_::Type
  end

  @Record EXTARGEXP begin
    exp::Exp
    type_::Type
  end

  @Record EXTARGSIZE begin
    componentRef::ComponentRef
    type_::Type
    exp::Exp
  end

  @Record NOEXTARG begin
  end
end

@Uniontype ExternalDecl begin
  @Record EXTERNALDECL begin
    name::String
    args::List{ExtArg}
    returnArg::ExtArg
    language::String
    ann::Option{SCode.Annotation}
  end
end

" A DAE_LIST is a list of Elements. Variables, equations, functions,
algorithms, etc. are all found in this list.
"
struct DAE_LIST <: DAElist
  elementLst::List{Element}
end

#= /* -- Algorithm.mo -- */ =#

#= The `Algorithm\\' type corresponds to a whole algorithm section.
It is simple a list of algorithm statements. =#
@Uniontype Algorithm begin
  @Record ALGORITHM_STMTS begin
    statementLst::List{Statement}
  end
end

#= Optimica extension: The `Constraints\\' type corresponds to a whole Constraint section.
It is simple a list of expressions. =#
@Uniontype Constraint begin
  @Record CONSTRAINT_EXPS begin
    constraintLst::List{Exp}
  end

  @Record CONSTRAINT_DT begin
    constraint::Exp
    localCon #= local or global constraint; local constraints depend on variables that are computed within the algebraic loop itself =#::Bool
  end
end

#= currently for Optimica extension: these are the objectives of optimization class =#
@Uniontype ClassAttributes begin
  @Record OPTIMIZATION_ATTRS begin
    objetiveE::Option{Exp}
    objectiveIntegrandE::Option{Exp}
    startTimeE::Option{Exp}
    finalTimeE::Option{Exp}
  end
end

#= /* TODO: create a backend and a simcode uniontype */ =#

#= There are four kinds of statements:
1. assignments ('a := b;')
2. if statements ('if A then B; elseif C; else D;')
3. for loops ('for i in 1:10 loop ...; end for;')
4. when statements ('when E do S; end when;') =#
@Uniontype Statement begin
  @Record STMT_ASSIGN begin
    type_::Type
    exp1::Exp
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_TUPLE_ASSIGN begin
    type_::Type
    expExpLst::List{Exp}
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_ASSIGN_ARR begin
    type_::Type
    lhs::Exp
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_IF begin
    exp::Exp
    statementLst::List{Statement}
    else_::Else
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_FOR begin
    type_ #= this is the type of the iterator =#::Type
    iterIsArray #= True if the iterator has an array type, otherwise false. =#::Bool
    iter #= the iterator variable =#::String
    index #= the index of the iterator variable, to make it unique; used by the new inst =#::ModelicaInteger
    range #= range for the loop =#::Exp
    statementLst::List{Statement}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_PARFOR begin
    type_ #= this is the type of the iterator =#::Type
    iterIsArray #= True if the iterator has an array type, otherwise false. =#::Bool
    iter #= the iterator variable =#::String
    index #= the index of the iterator variable, to make it unique; used by the new inst =#::ModelicaInteger
    range #= range for the loop =#::Exp
    statementLst::List{Statement}
    loopPrlVars #= list of parallel variables used/referenced in the parfor loop =#::List{Tuple{ComponentRef, SourceInfo}}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_WHILE begin
    exp::Exp
    statementLst::List{Statement}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_WHEN begin
    exp::Exp
    conditions::List{ComponentRef}
    #=  list of boolean variables as conditions  (this is simcode stuff)
    =#
    initialCall::Bool
    #=  true, if top-level branch with initial() (this is simcode stuff)
    =#
    statementLst::List{Statement}
    elseWhen::Option{Statement}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_ASSERT begin
    cond::Exp
    msg::Exp
    level::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_TERMINATE begin
    msg::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_REINIT begin
    var #= Variable =#::Exp
    value #= Value  =#::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_NORETCALL begin
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_RETURN begin
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_BREAK begin
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_CONTINUE begin
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record STMT_ARRAY_INIT begin
    name::String
    ty::Type
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  #=  MetaModelica extension. KS
  =#

  @Record STMT_FAILURE begin
    body::List{Statement}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end
end

#= An if statements can one or more `elseif\\' branches and an
optional `else\\' branch. =#
@Uniontype Else begin
  @Record NOELSE begin
  end

  @Record ELSEIF begin
    exp::Exp
    statementLst::List{Statement}
    else_::Else
  end

  @Record ELSE begin
    statementLst::List{Statement}
  end
end

#= /* -- End Algorithm.mo -- */ =#
#= /* -- Start Types.mo -- */ =#

#= - Variables =#
@Uniontype Var begin
  @Record TYPES_VAR begin
    name #= name =#::String
    attributes #= attributes =#::Attributes
    ty #= type =#::Type
    binding #= equation modification =#::Binding
    bind_from_outside #= binding came from out of scope (derived record classes) =#::Bool
    constOfForIteratorRange #= the constant-ness of the range if this is a for iterator, NONE() if is NOT a for iterator =#::Option{Const}
  end
end

# Compat: pre-bind_from_outside callers construct TYPES_VAR with 5 positional args.
TYPES_VAR(name, attributes, ty, binding, constOfForIteratorRange::Option) =
  TYPES_VAR(name, attributes, ty, binding, false, constOfForIteratorRange)

#= - Attributes =#
@Uniontype Attributes begin
  @Record ATTR begin
    connectorType #= flow, stream or unspecified =#::ConnectorType
    parallelism #= parallelism =#::SCode.Parallelism
    variability #= variability =#::SCode.Variability
    direction #= direction =#::Absyn.Direction
    innerOuter #= inner, outer,  inner outer or unspecified =#::Absyn.InnerOuter
    visibility #= public, protected =#::SCode.Visibility
  end
end

const dummyAttrVar = ATTR(NON_CONNECTOR(), SCode.NON_PARALLEL(), SCode.VAR(), Absyn.BIDIR(), Absyn.NOT_INNER_OUTER(), SCode.PUBLIC())::Attributes
const dummyAttrParam = ATTR(NON_CONNECTOR(), SCode.NON_PARALLEL(), SCode.PARAM(), Absyn.BIDIR(), Absyn.NOT_INNER_OUTER(), SCode.PUBLIC())::Attributes
const dummyAttrConst = ATTR(NON_CONNECTOR(), SCode.NON_PARALLEL(), SCode.CONST(), Absyn.BIDIR(), Absyn.NOT_INNER_OUTER(), SCode.PUBLIC())::Attributes
const dummyAttrInput = ATTR(NON_CONNECTOR(), SCode.NON_PARALLEL(), SCode.VAR(), Absyn.INPUT(), Absyn.NOT_INNER_OUTER(), SCode.PUBLIC())::Attributes

#= where this binding came from: either default binding or start value =#
@Uniontype BindingSource begin
  @Record BINDING_FROM_DEFAULT_VALUE begin
  end

  @Record BINDING_FROM_START_VALUE begin
  end

  @Record BINDING_FROM_RECORD_SUBMODS begin
  end

  @Record BINDING_FROM_DERIVED_RECORD_DECL begin
  end
end

#=We do not care..=#
@Uniontype Binding begin
  @Record UNBOUND begin
  end

  @Record EQBOUND begin
    exp::Exp
    evaluatedExp::Option{Values.Value}
    constant_::Const
    source::BindingSource
  end

  @Record VALBOUND begin
    valBound::Values.Value
    source::BindingSource
  end
end

EqualityConstraint = Option  #= contains the path to the equalityConstraint function,
the dimension of the output and the inline type of the function =#
#=  default constants that can be used
=#

#= models the different front-end and back-end types =#
@Uniontype Type begin
  @Record T_INTEGER begin
    varLst::List{Var}
  end

  @Record T_REAL begin
    varLst::List{Var}
  end

  @Record T_STRING begin
    varLst::List{Var}
  end

  @Record T_BOOL begin
    varLst::List{Var}
  end

  @Record T_CLOCK begin
    varLst::List{Var}
    #=  BTH Since Clock type has no attributes, this is not really needed, but at the moment kept for unified treatment of fundamental types
    =#
  end

  @Record T_ENUMERATION begin
    index #= the enumeration value index, SOME for element, NONE() for type =#::Option{ModelicaInteger}
    path #= enumeration path =#::Absyn.Path
    names #= names =#::List{String}
    literalVarLst::List{Var}
    attributeLst::List{Var}
  end

  @Record T_ARRAY begin
    ty #= Type =#::Type
    dims #= dims =#::Dimensions
  end

  @Record T_NORETCALL begin
  end

  @Record T_UNKNOWN begin
  end

  @Record T_COMPLEX begin
    complexClassType #= The type of a class =#::ClassInf.SMNode
    varLst #= The variables of a complex type =#::List{Var}
    equalityConstraint::EqualityConstraint
    usedExternally #= passed to an external function at some point =#::Bool
  end

  @Record T_SUBTYPE_BASIC begin
    complexClassType #= The type of a class =#::ClassInf.SMNode
    varLst #= complexVarLst; The variables of a complex type! Should be empty, kept here to verify! =#::List{Var}
    complexType #= complexType; A complex type can be a subtype of another (primitive) type (through extends) =#::Type
    equalityConstraint::EqualityConstraint
  end

  @Record T_FUNCTION begin
    funcArg #= funcArg =#::List{FuncArg}
    funcResultType #= Only single-result =#::Type
    functionAttributes::FunctionAttributes
    path::Absyn.Path
  end

  @Record T_FUNCTION_REFERENCE_VAR begin
    functionType #= the type of the function =#::Type
  end

  @Record T_FUNCTION_REFERENCE_FUNC begin
    builtin::Bool
    functionType #= type of the non-boxptr function =#::Type
  end

  @Record T_TUPLE begin
    types #= For functions returning multiple values. =#::List{Type}
    names #= For tuples elements that have names (function outputs) =#::Option{List{String}}
  end

  @Record T_CODE begin
    ty::CodeType
  end

  @Record T_ANYTYPE begin
    anyClassType #= anyClassType - used for generic types. When class state present the type is assumed to be a complex type which has that restriction. =#::Option{ClassInf.SMNode}
  end

  #=  MetaModelica extensions
  =#

  @Record T_METALIST begin
    ty #= listType =#::Type
  end

  @Record T_METATUPLE begin
    types::List{Type}
  end

  @Record T_METAOPTION begin
    ty::Type
  end

  @Record T_METAUNIONTYPE begin

    #=  TODO: You can't trust these fields as it seems MetaUtil.fixUniontype is sent empty elements when running dependency analysis
    =#
    paths::List{Absyn.Path}
    typeVars::List{Type}
    knownSingleton #= The runtime system (dynload), does not know if the value is a singleton. But optimizations are safe if this is true. =#::Bool
    singletonType::EvaluateSingletonType
    path::Absyn.Path
  end

  @Record T_METARECORD begin
    path #= the path to the record =#::Absyn.Path
    utPath #= the path to its uniontype; this is what we match the type against =#::Absyn.Path
    #=  If the metarecord constructor was added to the FunctionTree, this would
    =#
    #=  not be needed. They are used to create the datatype in the runtime...
    =#
    typeVars::List{Type}
    index::ModelicaInteger
    #= The index in the uniontype
    =#
    fields::List{Var}
    knownSingleton #= The runtime system (dynload), does not know if the value is a singleton. But optimizations are safe if this is true. =#::Bool
  end

  @Record T_METAARRAY begin
    ty::Type
  end

  @Record T_METABOXED begin
    ty::Type
  end

  @Record T_METAPOLYMORPHIC begin
    name::String
  end

  @Record T_METATYPE begin
    ty::Type
  end
end

@Uniontype CodeType begin
  @Record C_EXPRESSION begin
  end

  @Record C_EXPRESSION_OR_MODIFICATION begin
  end

  @Record C_MODIFICATION begin
  end

  @Record C_TYPENAME begin
  end

  @Record C_VARIABLENAME begin
  end

  @Record C_VARIABLENAMES begin
  end
end

#= Is here because constants are not allowed to contain function pointers for some reason =#
@Uniontype EvaluateSingletonType begin
  @Record EVAL_SINGLETON_TYPE_FUNCTION begin
    fun::EvaluateSingletonTypeFunction
  end

  @Record EVAL_SINGLETON_KNOWN_TYPE begin
    ty::Type
  end

  @Record NOT_SINGLETON begin
  end
end

@Uniontype FunctionAttributes begin
  @Record FUNCTION_ATTRIBUTES begin
    inline::InlineType
    generateEvents #= true if the function generates events =#::Bool
    purity #= Purity enumeration (PURE/IMPURE) =#::Int
    isFunctionPointer #= if the function is a local variable =#::Bool
    isBuiltin::FunctionBuiltin
    functionParallelism::FunctionParallelism
    noReturn #= NoReturn enumeration (RETURNS/NORETURN) =#::Int
  end
end

# Purity / NoReturn enumerations (pinned OMC), lowered to Ints (0-based).
const PURE = 0
const IMPURE = 1
const UNDEFINED = 2
const OM_IMPURE = 3
const Purity = Int
const RETURNS = 0
const NORETURN = 1
const NoReturn = Int

# Compat: pre-purity-enum callers construct with
# (inline, isOpenModelicaPure::Bool, isImpure::Bool, isFunctionPointer, isBuiltin, parallelism).
FUNCTION_ATTRIBUTES(inline, isOpenModelicaPure::Bool, isImpure::Bool,
                    isFunctionPointer::Bool, isBuiltin, functionParallelism) =
  FUNCTION_ATTRIBUTES(inline, false,
    isImpure ? IMPURE : (isOpenModelicaPure ? PURE : OM_IMPURE),
    isFunctionPointer, isBuiltin, functionParallelism, RETURNS)

# Compat: pre-noReturn callers with the purity enum (6 positional args).
FUNCTION_ATTRIBUTES(inline, generateEvents::Bool, purity::Int,
                    isFunctionPointer::Bool, isBuiltin, functionParallelism) =
  FUNCTION_ATTRIBUTES(inline, generateEvents, purity,
    isFunctionPointer, isBuiltin, functionParallelism, RETURNS)

# Compat: pre-usedExternally callers (3 positional args).
T_COMPLEX(complexClassType, varLst, equalityConstraint) =
  T_COMPLEX(complexClassType, varLst, equalityConstraint, false)

@Uniontype FunctionBuiltin begin
  @Record FUNCTION_NOT_BUILTIN begin
  end

  @Record FUNCTION_BUILTIN begin
    name::Option{String}
    unboxArgs::Bool
  end

  @Record FUNCTION_BUILTIN_PTR begin
  end
end

#= This was a function restriction in SCode and Absyn
=#
#= Now it is part of function attributes.
=#

@Uniontype FunctionParallelism begin
  @Record FP_NON_PARALLEL begin
  end

  @Record FP_PARALLEL_FUNCTION begin
  end

  @Record FP_KERNEL_FUNCTION begin
  end
end

const FUNCTION_ATTRIBUTES_BUILTIN = FUNCTION_ATTRIBUTES(NO_INLINE(), true, false, false, FUNCTION_BUILTIN(NONE(), false), FP_NON_PARALLEL())::FunctionAttributes

const FUNCTION_ATTRIBUTES_DEFAULT = FUNCTION_ATTRIBUTES(DEFAULT_INLINE(), true, false, false, FUNCTION_NOT_BUILTIN(), FP_NON_PARALLEL())::FunctionAttributes

const FUNCTION_ATTRIBUTES_IMPURE = FUNCTION_ATTRIBUTES(NO_INLINE(), false, true, false, FUNCTION_NOT_BUILTIN(), FP_NON_PARALLEL())::FunctionAttributes

const FUNCTION_ATTRIBUTES_BUILTIN_IMPURE = FUNCTION_ATTRIBUTES(NO_INLINE(), false, true, false, FUNCTION_BUILTIN(NONE(), false), FP_NON_PARALLEL())::FunctionAttributes


@Uniontype Dimension begin
  @Record DIM_INTEGER begin
    integer::ModelicaInteger
  end

  @Record DIM_BOOLEAN begin
  end

  @Record DIM_ENUM begin
    enumTypeName #= The enumeration type name. =#::Absyn.Path
    literals #= A list of the literals in the enumeration. =#::List{String}
    size #= The size of the enumeration. =#::ModelicaInteger
  end

  @Record DIM_EXP begin
    exp::Exp
  end

  @Record DIM_UNKNOWN begin
    #= DimensionBinding dimensionBinding \"unknown dimension can be bound or unbound\";
    =#
  end
end

#=  adrpo: this is used to bind unknown dimensions to an expression
=#
#=         and when we do subtyping we add constrains to this expression.
=#
#=         this should be used for typechecking with unknown dimensions
=#
#=         when running checkModel. the binding acts like a type variable.
=#

@Uniontype DimensionBinding begin
  @Record DIM_UNBOUND begin
  end

  @Record DIM_BOUND begin
    binding #= the dimension is bound to this expression =#::Exp
    constrains #= the bound has these constrains (collected when doing subtyping) =#::Dimensions
  end
end

@Uniontype FuncArg begin
  @Record FUNCARG begin
    name::String
    ty::Type
    constType::Const
    par::VarParallelism
    defaultBinding::Option{Exp}
  end
end

#= The degree of constantness of an expression is determined by the Const
datatype. Variables declared as \\'constant\\' will get C_CONST constantness.
Variables declared as \\'parameter\\' will get C_PARAM constantness and
all other variables are not constant and will get C_VAR constantness.

- Variable properties =#
@Uniontype Const begin
  @Record C_CONST begin
  end

  @Record C_PARAM begin
  end

  @Record C_VAR begin
  end

  @Record C_UNKNOWN begin
  end
end

#= A tuple is added to the Types. This is used by functions whom returns multiple arguments.
Used by split_props
- Tuple constants =#
@Uniontype TupleConst begin
  @Record SINGLE_CONST begin
    constType::Const
  end

  @Record TUPLE_CONST begin
    tupleConstLst::List{TupleConst}
  end
end

#= P.R 1.1 for multiple return arguments from functions,
one constant flag for each return argument.

The datatype `Properties\\' contain information about an
expression.  The properties are created by analyzing the
expressions.
- Expression properties =#
@Uniontype Properties begin
  @Record PROP begin
    type_ #= type =#::Type
    constFlag #= constFlag; if the type is a tuple, each element
    have a const flag. =#::Const
  end

  @Record PROP_TUPLE begin
    type_::Type
    tupleConst #= tupleConst; The elements might be
    tuple themselfs. =#::TupleConst
  end
end

const ReductionIterators = List  #= NOTE: OMC only handles one iterator for now =#
#= To generate the correct set of equations, the translator has to
differentiate between the primitive types `Real\\', `Integer\\',
`String\\', `Boolean\\' and types directly derived from then from
other, complex types.  For arrays and matrices the type
`T_ARRAY\\' is used, with the first argument being the number of
dimensions, and the second being the type of the objects in the
array.  The `Type\\' type is used to store
information about whether a class is derived from a primitive
type, and whether a variable is of one of these types.
- Modification datatype, was originally in Mod =#
@Uniontype EqMod begin
  @Record TYPED begin
    modifierAsExp #= modifier as expression =#::Exp
    modifierAsValue #= modifier as Value option =#::Option{Values.Value}
    properties #= properties =#::Properties
    modifierAsAbsynExp #= keep the untyped modifier as an absyn expression for modification comparison =#::Absyn.Exp
    info::SourceInfo
  end

  @Record UNTYPED begin
    exp::Absyn.Exp
  end
end

#= -Sub Modification =#
@Uniontype SubMod begin
  @Record NAMEMOD begin
    ident #= component name =#::String
    mod #= modification =#::Mod
  end
end

#= Modification =#
@Uniontype Mod begin
  @Record MOD begin
    finalPrefix #= final prefix =#::SCode.Final
    eachPrefix #= each prefix =#::SCode.Each
    subModLst::List{SubMod}
    binding::Option{EqMod}
    info::SourceInfo
  end

  @Record REDECL begin
    finalPrefix #= final prefix =#::SCode.Final
    eachPrefix #= each prefix =#::SCode.Each
    element::SCode.Element
    mod::Mod
  end

  @Record NOMOD begin
  end
end

@Uniontype ClockKind begin
  @Record INFERRED_CLOCK begin
  end

  @Record INTEGER_CLOCK begin
    intervalCounter::Exp
    resolution #=  integer type >= 1  =#::Exp
  end

  @Record REAL_CLOCK begin
    interval::Exp
  end

  @Record BOOLEAN_CLOCK begin
    condition::Exp
    startInterval #=  real type >= 0.0  =#::Exp
  end

  @Record SOLVER_CLOCK begin
    c::Exp
    solverMethod #=  string type  =#::Exp
  end
end

# Pinned-OMC ClockKind record names.
const RATIONAL_CLOCK = INTEGER_CLOCK
const EVENT_CLOCK = BOOLEAN_CLOCK

#= /* -- End Types.mo -- */ =#

#= Expressions
The 'Exp' datatype closely corresponds to the 'Absyn.Exp' datatype, but
is used for statically analyzed expressions. It includes explicit type
promotions and typed (non-overloaded) operators. It also contains expression
indexing with the 'ASUB' constructor. Indexing arbitrary array expressions
is currently not supported in Modelica, but it is needed here.

When making additions, update at least the following functions:
* Expression.traverseExp
* Expression.traverseExpTopDown
* Expression.traverseExpBiDir
* ExpressionDump.printExpStr =#
@Uniontype Exp begin
  @Record ICONST begin
    integer #= Integer constants =#::ModelicaInteger
  end

  @Record RCONST begin
    real #= Real constants =#::ModelicaReal
  end

  @Record SCONST begin
    string #= String constants =#::String
  end

  @Record BCONST begin
    bool #= Bool constants =#::Bool
  end

  @Record CLKCONST begin
    clk #= Clock kinds =#::ClockKind
  end

  @Record ENUM_LITERAL begin
    name::Absyn.Path
    index::ModelicaInteger
  end

  @Record CREF begin
    componentRef::ComponentRef
    ty::Type
  end

  @Record BINARY begin
    exp1::Exp
    operator::Operator
    exp2::Exp
  end

  @Record UNARY begin
    operator::Operator
    exp::Exp
  end

  @Record LBINARY begin
    exp1::Exp
    operator::Operator
    exp2::Exp
  end

  @Record LUNARY begin
    operator::Operator
    exp::Exp
  end

  @Record RELATION begin
    exp1::Exp
    operator::Operator
    exp2::Exp
    index #= Use -1 as a default; other indexes are used in the backend for some silly reasons =#::ModelicaInteger
    optionExpisASUB::Option{Tuple{Exp, ModelicaInteger, ModelicaInteger}}
  end

  @Record IFEXP begin
    expCond::Exp
    expThen::Exp
    expElse::Exp
  end

  @Record CALL begin
    path::Absyn.Path
    expLst::List{Exp}
    attr::CallAttributes
  end

  @Record RECORD begin
    path::Absyn.Path
    exps #= component values =#::List{Exp}
    comp #= component name =#::List{String}
    ty::Type
  end

  @Record PARTEVALFUNCTION begin
    path::Absyn.Path
    expList::List{Exp}
    ty::Type
    origType::Type
  end

  @Record ARRAY begin
    ty::Type
    scalar #= scalar for codegen =#::Bool
    array #= Array constructor, e.g. {1,3,4} =#::List{Exp}
  end

  @Record MATRIX begin
    ty::Type
    integer #= Size of the first dimension =#::ModelicaInteger
    matrix::List{List{Exp}}
  end

  @Record RANGE begin
    ty #= the (array) type of the expression =#::Type
    start #= start value =#::Exp
    step #= step value =#::Option{Exp}
    stop #= stop value =#::Exp
  end

  @Record TUPLE begin
    PR #= PR. Tuples, used in func calls returning several
    arguments =#::List{Exp}
  end

  @Record CAST begin
    ty #= This is the full type of this expression, i.e. ET_ARRAY(...) for arrays and matrices =#::Type
    exp::Exp
  end

  @Record ASUB begin
    exp::Exp
    sub::List{Subscript}
  end

  @Record TSUB begin
    exp::Exp
    ix::ModelicaInteger
    ty::Type
  end

  @Record RSUB begin
    exp::Exp
    ix::ModelicaInteger
    #=  Used when generating code for MetaModelica records
    =#
    fieldName::String
    ty::Type
  end

  @Record SIZE begin
    exp::Exp
    sz::Option{Exp}
  end

  @Record CODE begin
    code::Absyn.CodeNode
    ty::Type
  end

  @Record EMPTY begin
    scope #= the scope where we could not find the binding =#::String
    name #= the name of the variable =#::ComponentRef
    ty #= the type of the variable =#::Type
    tyStr::String
  end

  @Record REDUCTION begin
    reductionInfo::ReductionInfo
    expr #= expr, e.g i*i+1 =#::Exp
    iterators::ReductionIterators
  end

  #= /* Part of MetaModelica extension. KS */ =#

  @Record LIST begin
    valList::List{Exp}
  end

  @Record CONS begin
    car::Exp
    cdr::Exp
  end

  @Record META_TUPLE begin
    listExp::List{Exp}
  end

  @Record META_OPTION begin
    exp::Option{Exp}
  end

  #= /*
  Holds a metarecord call
  <metarecord>(<args>)
  */ =#

  @Record METARECORDCALL begin

    #= Metamodelica extension, simbj
    =#
    path::Absyn.Path
    args::List{Exp}
    fieldNames::List{String}
    index::ModelicaInteger
    #= Index in the uniontype
    =#
    typeVars::List{Type}
  end

  @Record MATCHEXPRESSION begin
    matchType::MatchType
    inputs::List{Exp}
    aliases #= input aliases (input as-bindings) =#::List{List{String}}
    localDecls::List{Element}
    cases::List{MatchCase}
    et::Type
  end

  @Record BOX begin
    exp::Exp
  end

  @Record UNBOX begin
    exp::Exp
    ty::Type
  end

  @Record SHARED_LITERAL begin
    index #= A unique indexing that can be used to point to a single shared literal in generated code =#::ModelicaInteger
    exp #= For printing strings, code generators that do not support this kind of literal, or for getting the type in case the code generator needs that =#::Exp
  end

  @Record PATTERN begin
    pattern::Pattern
  end

  #= /* --- */ =#
end

@Uniontype TailCall begin
  @Record NO_TAIL begin
  end

  @Record TAIL begin
    vars::List{String}
    outVars::List{String}
  end
end

@Uniontype CallAttributes begin
  @Record CALL_ATTR begin
    ty #= The type of the return value, if several return values this is undefined =#::Type
    tuple_ #= tuple =#::Bool
    builtin #= builtin Function call =#::Bool
    isImpure #= if the function has prefix *impure* is true, else false =#::Bool
    isFunctionPointerCall::Bool
    inlineType::InlineType
    tailCall #= Input variables of the function if the call is tail-recursive =#::TailCall
    noReturn #= NoReturn enumeration (RETURNS/NORETURN) =#::Int
  end
end

# Compat: pre-noReturn callers construct CALL_ATTR with 7 positional args.
CALL_ATTR(ty, tuple_::Bool, builtin::Bool, isImpure::Bool, isFunctionPointerCall::Bool,
          inlineType, tailCall) =
  CALL_ATTR(ty, tuple_, builtin, isImpure, isFunctionPointerCall, inlineType, tailCall, RETURNS)

@Uniontype ReductionInfo begin
  @Record REDUCTIONINFO begin
    path #= array, sum,.. =#::Absyn.Path
    iterType::Absyn.ReductionIterType
    exprType::Type
    defaultValue #= if there is no default value, the reduction is not defined for 0-length arrays/lists =#::Option{Values.Value}
    foldName::String
    resultName #= Unique identifier for the resulting expression =#::String
    foldExp #= For example, max(ident,$res) or ident+$res; array() does not use this feature; DO NOT TRAVERSE THIS EXPRESSION! =#::Option{Exp}
  end
end

@Uniontype ReductionIterator begin
  @Record REDUCTIONITER begin
    id::String
    exp::Exp
    guardExp::Option{Exp}
    ty::Type
  end
end


@Uniontype MatchCase begin
  @Record CASE begin
    patterns #= ELSE is handled by not doing pattern-matching =#::List{Pattern}
    patternGuard #= Guard-expression =#::Option{Exp}
    localDecls::List{Element}
    body::List{Statement}
    result::Option{Exp}
    resultInfo #= We need to keep the line info here so we can set a breakpoint at the last statement of a match-expression =#::SourceInfo
    jump #= the number of iterations we should skip if we succeed with pattern-matching, but don't succeed =#::ModelicaInteger
    info::SourceInfo
  end
end

@Uniontype MatchType begin
  @Record MATCHCONTINUE begin
  end

  @Record TRY_STACKOVERFLOW begin
  end

  @Record MATCH begin
    switch #= The index of the pattern to switch over, its type and the value to divide string hashes with =#::Option{Tuple{ModelicaInteger, Type, ModelicaInteger}}
  end
end

#= Patterns deconstruct expressions =#
@Uniontype Pattern begin
  @Record PAT_WILD begin
  end

  @Record PAT_CONSTANT begin
    ty #= so we can unbox if needed =#::Option{Type}
    exp::Exp
  end

  @Record PAT_AS begin
    id::String
    ty #= so we can unbox if needed =#::Option{Type}
    attr #= so we know if the ident is parameter or assignable =#::Attributes
    pat::Pattern
  end

  @Record PAT_AS_FUNC_PTR begin
    id::String
    pat::Pattern
  end

  @Record PAT_META_TUPLE begin
    patterns::List{Pattern}
  end

  @Record PAT_CALL_TUPLE begin
    patterns::List{Pattern}
  end

  @Record PAT_CONS begin
    head::Pattern
    tail::Pattern
  end

  @Record PAT_CALL begin
    name::Absyn.Path
    index::ModelicaInteger
    patterns::List{Pattern}
    fields::List{Var}
    #=  Needed to be able to bind a variable to the fields
    =#
    typeVars::List{Type}
    knownSingleton #= The runtime system (dynload), does not know if the value is a singleton. But optimizations are safe if this is true. =#::Bool
  end

  @Record PAT_CALL_NAMED begin
    name::Absyn.Path
    patterns::List{Tuple{Pattern, String, Type}}
  end

  @Record PAT_SOME begin
    pat::Pattern
  end
end

#= Operators which are overloaded in the abstract syntax are here
made type-specific.  The integer addition operator (`ADD(INT)\\')
and the real addition operator (`ADD(REAL)\\') are two distinct
operators. =#
@Uniontype Operator begin
  @Record ADD begin
    ty::Type
  end

  @Record SUB begin
    ty::Type
  end

  @Record MUL begin
    ty::Type
  end

  @Record DIV begin
    ty::Type
  end

  @Record POW begin
    ty::Type
  end

  @Record UMINUS begin
    ty::Type
  end

  @Record UMINUS_ARR begin
    ty::Type
  end

  @Record ADD_ARR begin
    ty::Type
  end

  @Record SUB_ARR begin
    ty::Type
  end

  @Record MUL_ARR begin
    ty::Type
  end

  @Record DIV_ARR begin
    ty::Type
  end

  @Record MUL_ARRAY_SCALAR begin
    ty #= type of the array =#::Type
  end

  @Record ADD_ARRAY_SCALAR begin
    ty #= type of the array =#::Type
  end

  @Record SUB_SCALAR_ARRAY begin
    ty #= type of the array =#::Type
  end

  @Record MUL_SCALAR_PRODUCT begin
    ty #= type of the array =#::Type
  end

  @Record MUL_MATRIX_PRODUCT begin
    ty #= {{..},..}  {{..},{..}} =#::Type
  end

  @Record DIV_ARRAY_SCALAR begin
    ty #= type of the array =#::Type
  end

  @Record DIV_SCALAR_ARRAY begin
    ty #= type of the array =#::Type
  end

  @Record POW_ARRAY_SCALAR begin
    ty #= type of the array =#::Type
  end

  @Record POW_SCALAR_ARRAY begin
    ty #= type of the array =#::Type
  end

  @Record POW_ARR begin
    ty #= type of the array =#::Type
  end

  @Record POW_ARR2 begin
    ty #= type of the array =#::Type
  end

  @Record AND begin
    ty::Type
  end

  @Record OR begin
    ty::Type
  end

  @Record NOT begin
    ty::Type
  end

  @Record LESS begin
    ty::Type
  end

  @Record LESSEQ begin
    ty::Type
  end

  @Record GREATER begin
    ty::Type
  end

  @Record GREATEREQ begin
    ty::Type
  end

  @Record EQUAL begin
    ty::Type
  end

  @Record NEQUAL begin
    ty::Type
  end

  @Record USERDEFINED begin
    fqName #= The FQ name of the overloaded operator function =#::Absyn.Path
  end
end

#= - Component references
CREF_QUAL(...) is used for qualified component names, e.g. a.b.c
CREF_IDENT(..) is used for non-qualifed component names, e.g. x =#
@Uniontype ComponentRef begin
  @Record CREF_QUAL begin
    ident::String
    identType #= type of the identifier, without considering the subscripts =#::Type
    subscriptLst::List{Subscript}
    componentRef::ComponentRef
  end

  @Record CREF_IDENT begin
    ident::String
    identType #= type of the identifier, without considering the subscripts =#::Type
    subscriptLst::List{Subscript}
  end

  @Record CREF_ITER begin
    ident::String
    index::ModelicaInteger
    identType #= type of the identifier, without considering the subscripts =#::Type
    subscriptLst::List{Subscript}
  end

  @Record OPTIMICA_ATTR_INST_CREF begin
    componentRef::ComponentRef
    instant::String
  end

  @Record WILD begin
  end
end


const NEW_SET = -1 #= The index used for new sets which have not
yet been assigned a set index. =#::ModelicaInteger

#= This type indicates whether a connector is an inside or an outside connector.
Note: this is not the same as inner and outer references.
A connector is inside if it connects from the outside into a component and it
is outside if it connects out from the component.  This is important when
generating equations for flow variables, where outside connectors are
multiplied with -1 (since flow is always into a component). =#
@Uniontype Face begin
  @Record INSIDE begin
  end

  @Record OUTSIDE begin
  end

  @Record NO_FACE begin
  end
end

#= The type of a connector element. =#
@Uniontype CConnectorType begin
  @Record CEQU begin
  end

  @Record CFLOW begin
  end

  @Record CSTREAM begin
    associatedFlow::Option{ComponentRef}
  end

  @Record CNO_TYPE begin
  end
end

@Uniontype ConnectorElement begin
  @Record CONNECTOR_ELEMENT begin
    name::ComponentRef
    face::Face
    ty::CConnectorType
    source::ElementSource
    set #= Which set this element belongs to. =#::ModelicaInteger
  end
end

@Uniontype SetTrieNode begin
  @Record SET_TRIE_NODE begin
    name::String
    cref::ComponentRef
    nodes::List{SetTrieNode}
    connectCount::ModelicaInteger
  end

  @Record SET_TRIE_LEAF begin
    name::String
    insideElement #= The inside element. =#::Option{ConnectorElement}
    outsideElement #= The outside element. =#::Option{ConnectorElement}
    flowAssociation #= The name of the associated flow
    variable, if the leaf represents a stream variable. =#::Option{ComponentRef}
    connectCount #= How many times this connector has been connected. =#::ModelicaInteger
  end
end

const SetTrie = SetTrieNode  #= A trie, a.k.a. prefix tree, that maps crefs to sets. =#

const SetConnection = Tuple  #= A connection between two sets. =#

@Uniontype OuterConnect begin
  @Record OUTERCONNECT begin
    scope #= the scope where this connect was created =# #TODO:::Prefix.PrefixType
    cr1 #= the lhs component reference =#::ComponentRef
    io1 #= inner/outer attribute for cr1 component =#::Absyn.InnerOuter
    f1 #= the face of the lhs component =#::Face
    cr2 #= the rhs component reference =#::ComponentRef
    io2 #= inner/outer attribute for cr2 component =#::Absyn.InnerOuter
    f2 #= the face of the rhs component =#::Face
    source #= the element origin =#::ElementSource
  end
end

@Uniontype Sets begin
  @Record SETS begin
    sets::SetTrie
    setCount #= How many sets the trie contains. =#::ModelicaInteger
    connections::List{SetConnection}
    outerConnects #= Connect statements to propagate upwards. =#::List{OuterConnect}
  end
end

#= A set of connection elements. =#
@Uniontype CSet begin
  @Record SET begin
    ty::CConnectorType
    elements::List{ConnectorElement}
  end

  @Record SET_POINTER begin
    index::ModelicaInteger
  end
end

const emptySet = SETS(SET_TRIE_NODE("", WILD(), nil, 0), 0, nil, nil)::Sets

const Ident = String

const StartValue = Option

@Uniontype Element begin
  @Record VAR begin
    componentRef #=  The variable name =#::ComponentRef
    kind #= varible kind: variable, constant, parameter, discrete etc. =#::VarKind
    direction #= input, output or bidir =#::VarDirection
    parallelism #= parglobal, parlocal, or non_parallel =#::VarParallelism
    protection #= if protected or public =#::VarVisibility
    ty #= Full type information required =#::Type
    binding #= Binding expression e.g. for parameters  value of start attribute =#::Option{Exp}
    dims #= dimensions =#::List
    connectorType #= The connector type: flow, stream, no prefix, or not a connector element. =#::ConnectorType
    source #= the origins of the component/equation/algorithm =#::ElementSource
    variableAttributesOption::Option{VariableAttributes}
    comment::Option{SCode.Comment}
    innerOuter #= inner/outer required to 'change' outer references =#::Absyn.InnerOuter
    encrypted #= true if the variable belongs to an encrypted class =#::Bool
  end

  @Record DEFINE begin
    componentRef::ComponentRef
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIALDEFINE begin
    componentRef::ComponentRef
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record EQUATION begin
    exp::Exp
    scalar::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record EQUEQUATION begin
    cr1::ComponentRef
    cr2::ComponentRef
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record ARRAY_EQUATION begin
    dimension #= dimension sizes =#::Dimensions
    exp::Exp
    array::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_ARRAY_EQUATION begin
    dimension #= dimension sizes =#::Dimensions
    exp::Exp
    array::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record CONNECT_EQUATION begin
    lhsElement::Element
    lhsFace::Face
    rhsElement::Element
    rhsFace::Face
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record COMPLEX_EQUATION begin
    lhs::Exp
    rhs::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_COMPLEX_EQUATION begin
    lhs::Exp
    rhs::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record WHEN_EQUATION begin
    condition #= Condition =#::Exp
    equations #= Equations =#::List{Element}
    elsewhen_ #= Elsewhen should be of type WHEN_EQUATION =#::Option{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  #= VSS extension: agentic reconfiguration equation.
     Represents a reconfigure block in the DAE. At runtime the when-clause
     condition fires, the agent is queried with the prompt and current state,
     and the model is recompiled with the new parameter values.
     whenClause is the mandatory head of the Cons list — structurally
     guaranteeing that at least one when clause is always present. =#
  @Record RECONFIGURE_EQUATION begin
    variables        #= Parameters exposed to the agent =#::List{Absyn.ElementItem}
    whenCondition    #= Primary trigger condition (DAE.Exp) =#::Exp
    whenConstraint   #= Optional post-condition invariant (Option{DAE.Exp}) =#::Option
    prompt           #= Natural-language prompt for the agent (Option{DAE.Exp}) =#::Option
    initialEquations #= Constraint equations checked at recompilation time =#::Option
    source           #= the origin of the element =#::ElementSource
  end

  @Record FOR_EQUATION begin
    type_ #= this is the type of the iterator =#::Type
    iterIsArray #= True if the iterator has an array type, otherwise false. =#::Bool
    iter #= the iterator variable =#::String
    index #= the index of the iterator variable, to make it unique; used by the new inst =#::ModelicaInteger
    range #= range for the loop =#::Exp
    equations #= Equations =#::List{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_FOR_EQUATION begin
    type_ #= this is the type of the iterator =#::Type
    iterIsArray #= True if the iterator has an array type, otherwise false. =#::Bool
    iter #= the iterator variable =#::String
    index #= the index of the iterator variable, to make it unique; used by the new inst =#::ModelicaInteger
    range #= range for the loop =#::Exp
    equations #= Equations =#::List{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record IF_EQUATION begin
    condition1 #= Condition =#::List{Exp}
    equations2 #= Equations of true branch =#::List{List{Element}}
    equations3 #= Equations of false branch =#::List{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_IF_EQUATION begin
    condition1 #= Condition =#::List{Exp}
    equations2 #= Equations of true branch =#::List{List{Element}}
    equations3 #= Equations of false branch =#::List{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIALEQUATION begin
    exp1::Exp
    exp2::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record ALGORITHM begin
    algorithm_::Algorithm
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIALALGORITHM begin
    algorithm_::Algorithm
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record COMP begin
    ident::String
    dAElist #= a component with subelements, normally only used at top level. =#::List{Element}
    source #= the origin of the component/equation/algorithm =#::ElementSource
    #=  we might not this here.
    =#
    comment::Option{SCode.Comment}
  end

  @Record EXTOBJECTCLASS begin
    path #= className of external object =#::Absyn.Path
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record ASSERT begin
    condition::Exp
    message::Exp
    level::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_ASSERT begin
    condition::Exp
    message::Exp
    level::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record TERMINATE begin
    message::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_TERMINATE begin
    message::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record REINIT begin
    componentRef::ComponentRef
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record NORETCALL begin
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record INITIAL_NORETCALL begin
    exp::Exp
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record CONSTRAINT begin
    constraints::Constraint
    source #= the origin of the component/equation/algorithm =#::ElementSource
  end

  @Record CLASS_ATTRIBUTES begin
    classAttrs::ClassAttributes
  end

  @Record FLAT_SM begin
    ident::String
    dAElist #= The states/modes transitions and variable
    merging equations within the the flat state machine =#::List{Element}
  end

  @Record SM_COMP begin
    componentRef::ComponentRef
    dAElist #= a component with subelements =#::List{Element}
  end

  @Record COMMENT begin
    cmt #= Functions store the inherited class annotations in the DAE =#::SCode.Comment
  end
end

#= The `Subscript\\' and `ComponentRef\\' datatypes are simple
translations of the corresponding types in the `Absyn\\' module. =#
@Uniontype Subscript begin
  @Record WHOLEDIM begin
  end

  @Record SLICE begin
    exp #= a{1:3,1}, a{1:2:10,2} =#::Exp
  end

  @Record INDEX begin
    exp #= a[i+1] =#::Exp
  end

  @Record WHOLE_NONEXP begin
    exp::Exp
  end
end

#= /* -- End Expression.mo -- */ =#

#= array cref expansion strategy =#
@Uniontype Expand begin
  @Record EXPAND begin
  end

  @Record NOT_EXPAND begin
  end
end

#= Prefix for classes is its variability =#
@Uniontype ClassPrefix begin
  @Record CLASSPRE begin
    variability #= VAR, DISCRETE, PARAM, or CONST =#::SCode.Variability
  end
end

#= Prefix for component name, e.g. a.b[2].c. Stored in inverse order c.b[2].a =#
@Uniontype ComponentPrefix begin
  @Record PRE begin
    prefix #= prefix name =#::String
    dimensions::List{Dimension}
    subscripts::List{Subscript}
    next #= next prefix =#::ComponentPrefix
    ci_state::ClassInf.State
    info::SourceInfo
  end

  @Record NOCOMPPRE begin
  end
end

#= A Prefix has a component prefix and a class prefix. =#
@Uniontype Prefix begin
  @Record NOPRE begin
  end

  @Record PREFIX begin
    compPre #= component prefixes are stored in inverse order c.b.a =#::ComponentPrefix
    classPre #= the class prefix, i.e. variability =#::ClassPrefix
  end
end

const InstDims = List

const emptyDae = DAE_LIST(nil)::DAE_LIST
const T_ASSERTIONLEVEL = T_ENUMERATION(NONE(), Absyn.FULLYQUALIFIED(Absyn.IDENT("AssertionLevel")), list("error", "warning"), nil, nil)::Type

const ASSERTIONLEVEL_ERROR = ENUM_LITERAL(Absyn.QUALIFIED("AssertionLevel", Absyn.IDENT("error")), 1)::Exp

const ASSERTIONLEVEL_WARNING = ENUM_LITERAL(Absyn.QUALIFIED("AssertionLevel", Absyn.IDENT("warning")), 2)::Exp

const T_UNKNOWN_DEFAULT = T_UNKNOWN()
const T_REAL_DEFAULT = T_REAL(nil)::Type
const T_INTEGER_DEFAULT = T_INTEGER(nil)::Type
const T_STRING_DEFAULT = T_STRING(nil)::Type
const T_BOOL_DEFAULT = T_BOOL(nil)::Type
const T_CLOCK_DEFAULT = T_CLOCK(nil)::Type
const T_ENUMERATION_DEFAULT = T_ENUMERATION(NONE(), Absyn.IDENT(""), nil, nil, nil)::Type
const T_REAL_BOXED = T_METABOXED(T_REAL_DEFAULT)::Type
const T_INTEGER_BOXED = T_METABOXED(T_INTEGER_DEFAULT)::Type
const T_STRING_BOXED = T_METABOXED(T_STRING_DEFAULT)::Type
const T_BOOL_BOXED = T_METABOXED(T_BOOL_DEFAULT)::Type
const T_METABOXED_DEFAULT = T_METABOXED(T_UNKNOWN_DEFAULT)::Type
const T_METALIST_DEFAULT = T_METALIST(T_UNKNOWN_DEFAULT)::Type
const T_NONE_DEFAULT = T_METAOPTION(T_UNKNOWN_DEFAULT)::Type
const T_ANYTYPE_DEFAULT = T_ANYTYPE(NONE())::Type
const T_UNKNOWN_DEFAULT = T_UNKNOWN()::Type
const T_NORETCALL_DEFAULT = T_NORETCALL()::Type
const T_METATYPE_DEFAULT = T_METATYPE(T_UNKNOWN_DEFAULT)::Type
const T_COMPLEX_DEFAULT = T_COMPLEX(ClassInf.UNKNOWN(Absyn.IDENT("")), nil, NONE()) #= default complex with unknown CiState =#::Type
const T_COMPLEX_DEFAULT_RECORD = T_COMPLEX(ClassInf.RECORD(Absyn.IDENT("")), nil, NONE()) #= default complex with record CiState =#::Type
const T_SOURCEINFO_DEFAULT_METARECORD = T_METARECORD(Absyn.QUALIFIED("SourceInfo", Absyn.IDENT("SOURCEINFO")), Absyn.IDENT("SourceInfo"), nil, 1, list(TYPES_VAR("fileName", dummyAttrVar, T_STRING_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("isReadOnly", dummyAttrVar, T_BOOL_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("lineNumberStart", dummyAttrVar, T_INTEGER_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("columnNumberStart", dummyAttrVar, T_INTEGER_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("lineNumberEnd", dummyAttrVar, T_INTEGER_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("columnNumberEnd", dummyAttrVar, T_INTEGER_DEFAULT, UNBOUND(), NONE()), TYPES_VAR("lastModification", dummyAttrVar, T_REAL_DEFAULT, UNBOUND(), NONE())), true)::Type
const T_SOURCEINFO_DEFAULT = T_METAUNIONTYPE(list(Absyn.QUALIFIED("SourceInfo", Absyn.IDENT("SOURCEINFO"))), nil, true, EVAL_SINGLETON_KNOWN_TYPE(T_SOURCEINFO_DEFAULT_METARECORD), Absyn.IDENT("SourceInfo"))::Type
#=  Arrays of unknown dimension, eg. Real[:] =#

const T_ARRAY_REAL_NODIM = T_ARRAY(T_REAL_DEFAULT, list(DIM_UNKNOWN()))::Type

const T_ARRAY_INT_NODIM = T_ARRAY(T_INTEGER_DEFAULT, list(DIM_UNKNOWN()))::Type

const T_ARRAY_BOOL_NODIM = T_ARRAY(T_BOOL_DEFAULT, list(DIM_UNKNOWN()))::Type

const T_ARRAY_STRING_NODIM = T_ARRAY(T_STRING_DEFAULT, list(DIM_UNKNOWN()))::Type


const callAttrBuiltinBool = CALL_ATTR(T_BOOL_DEFAULT, false, true, false, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinInteger = CALL_ATTR(T_INTEGER_DEFAULT, false, true, false, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinReal = CALL_ATTR(T_REAL_DEFAULT, false, true, false, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinString = CALL_ATTR(T_STRING_DEFAULT, false, true, false, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinOther = CALL_ATTR(T_UNKNOWN_DEFAULT, false, true, false, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinImpureBool = CALL_ATTR(T_BOOL_DEFAULT, false, true, true, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinImpureInteger = CALL_ATTR(T_INTEGER_DEFAULT, false, true, true, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrBuiltinImpureReal = CALL_ATTR(T_REAL_DEFAULT, false, true, true, false, NO_INLINE(), NO_TAIL())::CallAttributes

const callAttrOther = CALL_ATTR(T_UNKNOWN_DEFAULT, false, false, false, false, NO_INLINE(), NO_TAIL())::CallAttributes


const crefTime = CREF_IDENT("time", T_REAL_DEFAULT, nil)::ComponentRef
const crefTimeState = CREF_IDENT("time", T_REAL_DEFAULT, nil)::ComponentRef
const emptyCref = CREF_IDENT("", T_UNKNOWN_DEFAULT, nil)::ComponentRef

FunctionTree = Dict{Absyn.Path, Function}

function makeDummyCrefIdentOfTypeReal(name::String)
  CREF_IDENT(name, T_REAL_DEFAULT, nil)
end

"""
Function to simplify the creation of DAE attributes.
"""
function makeRealAttribute(;quantity #= quantity =#::Option{Exp} = NONE(),
                           unit #= unit =#::Option{Exp} = NONE(),
                           displayUnit #= displayUnit =#::Option{Exp} = NONE(),
                           min::Option{Exp} = NONE(),
                           max::Option{Exp} = NONE(),
                           start::Option{Float64} = NONE(),
                           fixed::Bool,
                           nominal #= nominal =#::Option{Exp} = NONE(),
                           stateSelectOption::Option{StateSelect} = NONE(),
                           uncertainOption::Option{Uncertainty} = NONE(),
                           distributionOption::Option{Distribution} = NONE(),
                           equationBound::Option{Exp} = NONE(),
                           isProtected::Bool = false,
                           finalPrefix::Bool = false,
                           startOrigin::Option{Exp} = NONE())
  startExp = @match start begin
    SOME(v) => SOME{DAE.Exp}(DAE.RCONST(v))
    _ => NONE()
  end
  VAR_ATTR_REAL(
    quantity,
    unit,
    displayUnit,
    min,
    max,
    startExp,
    SOME{DAE.Exp}(DAE.BCONST(fixed)),
    nominal,
    stateSelectOption,
    uncertainOption,
    distributionOption,
    equationBound,
    SOME{DAE.Exp}(DAE.BCONST(isProtected)),
    SOME{DAE.Exp}(DAE.BCONST(finalPrefix)),
    startOrigin,
  )
end


# Compat: pre-encrypted-field callers construct VAR with 13 positional args.
VAR(componentRef, kind, direction, parallelism, protection, ty, binding, dims,
    connectorType, source, variableAttributesOption, comment, innerOuter) =
  VAR(componentRef, kind, direction, parallelism, protection, ty, binding, dims,
      connectorType, source, variableAttributesOption, comment, innerOuter, false)

# DAE.Connect compatibility: this port flattens Connect's members into DAE with
# C-prefixed renames for collision-prone names; qualified `DAE.Connect.X` still works.
module Connect
const _P = Base.parentmodule(@__MODULE__)
const Face = _P.Face
const INSIDE = _P.INSIDE
const OUTSIDE = _P.OUTSIDE
const NO_FACE = _P.NO_FACE
const ConnectorType = _P.CConnectorType
const EQU = _P.CEQU
const FLOW = _P.CFLOW
const STREAM = _P.CSTREAM
const NO_TYPE = _P.CNO_TYPE
const ConnectorElement = _P.ConnectorElement
const CONNECTOR_ELEMENT = _P.CONNECTOR_ELEMENT
const SetTrieNode = _P.SetTrieNode
const SET_TRIE_NODE = _P.SET_TRIE_NODE
const SET_TRIE_LEAF = _P.SET_TRIE_LEAF
const SetTrie = _P.SetTrie
const SetConnection = _P.SetConnection
const OuterConnect = _P.OuterConnect
const OUTERCONNECT = _P.OUTERCONNECT
const Sets = _P.Sets
const SETS = _P.SETS
const Set = _P.CSet
const SET = _P.SET
const SET_POINTER = _P.SET_POINTER
const emptySet = _P.emptySet
end

@exportAll()

end
