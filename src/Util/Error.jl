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

module Error

import ..ErrorExt

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

const prefixToStr = Function

import ..Gettext
using ..ErrorTypes


#=
import Frontend.ErrorExt
import Frontend.Flags
import Frontend.Global
import Frontend.System
import Frontend.Testsuite
import Frontend.Util
=#

const LOOKUP_ERROR =
  ErrorTypes.MESSAGE(
    3,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class %s not found in scope %s."),
  )::ErrorTypes.Message

const LOOKUP_ERROR_COMPNAME =
  ErrorTypes.MESSAGE(
    4,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class %s not found in scope %s while instantiating %s."),
  )::ErrorTypes.Message

const LOOKUP_VARIABLE_ERROR =
  ErrorTypes.MESSAGE(
    5,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable %s not found in scope %s."),
  )::ErrorTypes.Message

const ASSIGN_CONSTANT_ERROR =
  ErrorTypes.MESSAGE(
    6,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to assign to constant component in %s := %s"),
  )::ErrorTypes.Message

const ASSIGN_PARAM_ERROR =
  ErrorTypes.MESSAGE(
    7,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to assign to parameter component in %s := %s"),
  )::ErrorTypes.Message

const ASSIGN_READONLY_ERROR =
  ErrorTypes.MESSAGE(
    8,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to assign to %s component %s."),
  )::ErrorTypes.Message

const ASSIGN_TYPE_MISMATCH_ERROR =
  ErrorTypes.MESSAGE(
    9,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in assignment in %s := %s of %s := %s"),
  )::ErrorTypes.Message

const IF_CONDITION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    10,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type error in conditional '%s'. Expected Boolean, got %s."),
  )::ErrorTypes.Message

const FOR_EXPRESSION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    11,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type error in iteration range '%s'. Expected array got %s."),
  )::ErrorTypes.Message

const WHEN_CONDITION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    12,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type error in when conditional '%s'. Expected Boolean scalar or vector, got %s."),
  )::ErrorTypes.Message

const WHILE_CONDITION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    13,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type error in while conditional '%s'. Expected Boolean got %s."),
  )::ErrorTypes.Message

const END_ILLEGAL_USE_ERROR =
  ErrorTypes.MESSAGE(
    14,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("'end' can not be used outside array subscripts."),
  )::ErrorTypes.Message

const DIVISION_BY_ZERO =
  ErrorTypes.MESSAGE(
    15,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Division by zero in %s / %s"),
  )::ErrorTypes.Message

const MODULO_BY_ZERO =
  ErrorTypes.MESSAGE(
    16,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Modulo by zero in mod(%s,%s)."),
  )::ErrorTypes.Message

const REM_ARG_ZERO =
  ErrorTypes.MESSAGE(
    17,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Second argument in rem is zero in rem(%s,%s)."),
  )::ErrorTypes.Message

const SCRIPT_READ_SIM_RES_ERROR =
  ErrorTypes.MESSAGE(
    18,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Error reading simulation result."),
  )::ErrorTypes.Message

const EXTENDS_LOOP =
  ErrorTypes.MESSAGE(
    19,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("extends %s causes an instantiation loop."),
  )::ErrorTypes.Message

const LOAD_MODEL_ERROR =
  ErrorTypes.MESSAGE(
    20,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class %s not found."),
  )::ErrorTypes.Message

const WRITING_FILE_ERROR =
  ErrorTypes.MESSAGE(
    21,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Error writing to file %s."),
  )::ErrorTypes.Message

const SIMULATOR_BUILD_ERROR =
  ErrorTypes.MESSAGE(
    22,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Error building simulator. Build log: %s"),
  )::ErrorTypes.Message

const DIMENSION_NOT_KNOWN =
  ErrorTypes.MESSAGE(
    23,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Dimensions must be parameter or constant expression (in %s)."),
  )::ErrorTypes.Message

const UNBOUND_VALUE =
  ErrorTypes.MESSAGE(
    24,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable %s has no value."),
  )::ErrorTypes.Message

const NEGATIVE_SQRT =
  ErrorTypes.MESSAGE(
    25,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Negative value as argument to sqrt."),
  )::ErrorTypes.Message

const NO_CONSTANT_BINDING =
  ErrorTypes.MESSAGE(
    26,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("No constant value for variable %s in scope %s."),
  )::ErrorTypes.Message

const TYPE_NOT_FROM_PREDEFINED =
  ErrorTypes.MESSAGE(
    27,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In class %s, class specialization 'type' can only be derived from predefined types."),
  )::ErrorTypes.Message

const INCOMPATIBLE_CONNECTOR_VARIABILITY =
  ErrorTypes.MESSAGE(
    28,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot connect %s %s to non-constant/parameter %s."),
  )::ErrorTypes.Message

const INVALID_CONNECTOR_PREFIXES =
  ErrorTypes.MESSAGE(
    29,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Connector element %s may not be both %s and %s."),
  )::ErrorTypes.Message

const INVALID_COMPLEX_CONNECTOR_VARIABILITY =
  ErrorTypes.MESSAGE(
    30,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is a composite connector element, and may not be declared as %s."),
  )::ErrorTypes.Message

const DIFFERENT_NO_EQUATION_IF_BRANCHES =
  ErrorTypes.MESSAGE(
    31,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Different number of equations in the branches of the if equation: %s"),
  )::ErrorTypes.Message

const UNDERDET_EQN_SYSTEM =
  ErrorTypes.MESSAGE(
    32,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Too few equations, under-determined system. The model has %s equation(s) and %s variable(s)."),
  )::ErrorTypes.Message

const OVERDET_EQN_SYSTEM =
  ErrorTypes.MESSAGE(
    33,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Too many equations, over-determined system. The model has %s equation(s) and %s variable(s)."),
  )::ErrorTypes.Message

const STRUCT_SINGULAR_SYSTEM =
  ErrorTypes.MESSAGE(
    34,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Model is structurally singular, error found sorting equations\\n%s\\nfor variables\\n%s"),
  )::ErrorTypes.Message

const UNSUPPORTED_LANGUAGE_FEATURE =
  ErrorTypes.MESSAGE(
    35,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The language feature %s is not supported. Suggested workaround: %s"),
  )::ErrorTypes.Message

const NON_EXISTING_DERIVATIVE =
  ErrorTypes.MESSAGE(
    36,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Derivative of expression \\%s\\ w.r.t. \\%s\\ is non-existent."),
  )::ErrorTypes.Message

const NO_CLASSES_LOADED =
  ErrorTypes.MESSAGE(
    37,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("No classes are loaded."),
  )::ErrorTypes.Message

const INST_PARTIAL_CLASS =
  ErrorTypes.MESSAGE(
    38,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal to instantiate partial class %s."),
  )::ErrorTypes.Message

const LOOKUP_BASECLASS_ERROR =
  ErrorTypes.MESSAGE(
    39,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Base class %s not found in scope %s."),
  )::ErrorTypes.Message

const INVALID_REDECLARE_AS =
  ErrorTypes.MESSAGE(
    40,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid redeclaration of %s %s as %s."),
  )::ErrorTypes.Message

const REDECLARE_NON_REPLACEABLE =
  ErrorTypes.MESSAGE(
    41,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to redeclare %1 %2 but %1 not declared as replaceable."),
  )::ErrorTypes.Message

const COMPONENT_INPUT_OUTPUT_MISMATCH =
  ErrorTypes.MESSAGE(
    42,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Component declared as %s when having the variable %s declared as %s."),
  )::ErrorTypes.Message

const ARRAY_DIMENSION_MISMATCH =
  ErrorTypes.MESSAGE(
    43,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array dimension mismatch, expression %s has type %s, expected array dimensions [%s]."),
  )::ErrorTypes.Message

const ARRAY_DIMENSION_INTEGER =
  ErrorTypes.MESSAGE(
    44,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array dimension must be integer expression in %s which has type %s."),
  )::ErrorTypes.Message

const EQUATION_TYPE_MISMATCH_ERROR =
  ErrorTypes.MESSAGE(
    45,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in equation %s of type %s."),
  )::ErrorTypes.Message

const INST_ARRAY_EQ_UNKNOWN_SIZE =
  ErrorTypes.MESSAGE(
    46,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array equation has unknown size in %s."),
  )::ErrorTypes.Message

const TUPLE_ASSIGN_FUNCALL_ONLY =
  ErrorTypes.MESSAGE(
    47,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Tuple assignment only allowed when rhs is function call (in %s)."),
  )::ErrorTypes.Message

const INVALID_CONNECTOR_TYPE =
  ErrorTypes.MESSAGE(
    48,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is not a valid connector."),
  )::ErrorTypes.Message

const EXPANDABLE_NON_EXPANDABLE_CONNECTION =
  ErrorTypes.MESSAGE(
    49,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot connect expandable connector %s with non-expandable connector %s."),
  )::ErrorTypes.Message

const UNDECLARED_CONNECTION =
  ErrorTypes.MESSAGE(
    50,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot connect undeclared connectors %s with %s. At least one of them must be declared."),
  )::ErrorTypes.Message

const CONNECT_PREFIX_MISMATCH =
  ErrorTypes.MESSAGE(
    51,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot connect %1 component %2 to non-%1 component %3."),
  )::ErrorTypes.Message

const INVALID_CONNECTOR_VARIABLE =
  ErrorTypes.MESSAGE(
    52,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The type of variables %s and %s\n are inconsistent in connect equations."),
  )::ErrorTypes.Message

const TYPE_ERROR =
  ErrorTypes.MESSAGE(
    53,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong type on %s, expected %s."),
  )::ErrorTypes.Message

const MODIFY_PROTECTED =
  ErrorTypes.MESSAGE(
    54,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Modification or redeclaration of protected elements is not allowed.\\n\\tElement: %s, modification: %s."),
  )::ErrorTypes.Message

const INVALID_TUPLE_CONTENT =
  ErrorTypes.MESSAGE(
    55,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Tuple %s must contain component references only."),
  )::ErrorTypes.Message

const MISSING_REDECLARE_IN_CLASS_MOD =
  ErrorTypes.MESSAGE(
    56,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Missing redeclare keyword on attempted redeclaration of class %s."),
  )::ErrorTypes.Message

const IMPORT_SEVERAL_NAMES =
  ErrorTypes.MESSAGE(
    57,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s found in several unqualified import statements."),
  )::ErrorTypes.Message

const LOOKUP_TYPE_FOUND_COMP =
  ErrorTypes.MESSAGE(
    58,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found a component with same name when looking for type %s."),
  )::ErrorTypes.Message

const INHERITED_EXTENDS =
  ErrorTypes.MESSAGE(
    59,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The base class name %s was found in one or more base classes:"),
  )::ErrorTypes.Message

const EXTEND_THROUGH_COMPONENT =
  ErrorTypes.MESSAGE(
    60,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Part %s of base class name %s is not a class."),
  )::ErrorTypes.Message

const PROTECTED_ACCESS =
  ErrorTypes.MESSAGE(
    61,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal access of protected element %s."),
  )::ErrorTypes.Message

const ILLEGAL_MODIFICATION =
  ErrorTypes.MESSAGE(
    62,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal modification %s (of %s)."),
  )::ErrorTypes.Message

const INTERNAL_ERROR =
  ErrorTypes.MESSAGE(
    63,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Internal error %s"),
  )::ErrorTypes.Message

const TYPE_MISMATCH_ARRAY_EXP =
  ErrorTypes.MESSAGE(
    64,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in array expression in component %s. %s is of type %s while the elements %s are of type %s."),
  )::ErrorTypes.Message

const TYPE_MISMATCH_MATRIX_EXP =
  ErrorTypes.MESSAGE(
    65,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in matrix rows in component %s. %s is a row of %s, the rest of the matrix is of type %s."),
  )::ErrorTypes.Message

const MATRIX_EXP_ROW_SIZE =
  ErrorTypes.MESSAGE(
    66,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Incompatible row length in matrix expression in component %s. %s is a row of size %s, the rest of the matrix rows are of size %s."),
  )::ErrorTypes.Message

const OPERAND_BUILTIN_TYPE =
  ErrorTypes.MESSAGE(
    67,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operand of %s in component %s must be builtin-type in %s."),
  )::ErrorTypes.Message

const WRONG_TYPE_OR_NO_OF_ARGS =
  ErrorTypes.MESSAGE(
    68,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong type or wrong number of arguments to %s (in component %s)."),
  )::ErrorTypes.Message

const DIFFERENT_DIM_SIZE_IN_ARGUMENTS =
  ErrorTypes.MESSAGE(
    69,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Different dimension sizes in arguments to %s in component %s."),
  )::ErrorTypes.Message

const LOOKUP_IMPORT_ERROR =
  ErrorTypes.MESSAGE(
    70,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Import %s not found in scope %s."),
  )::ErrorTypes.Message

const LOOKUP_SHADOWING =
  ErrorTypes.MESSAGE(
    71,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Import %s is shadowed by a local element."),
  )::ErrorTypes.Message

const ARGUMENT_MUST_BE_INTEGER =
  ErrorTypes.MESSAGE(
    72,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s argument to %s in component %s must be Integer expression."),
  )::ErrorTypes.Message

const ARGUMENT_MUST_BE_DISCRETE_VAR =
  ErrorTypes.MESSAGE(
    73,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s argument to %s in component %s must be discrete variable."),
  )::ErrorTypes.Message

const TYPE_MUST_BE_SIMPLE =
  ErrorTypes.MESSAGE(
    74,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type in %s must be simple type in component %s."),
  )::ErrorTypes.Message

const ARGUMENT_MUST_BE_VARIABLE =
  ErrorTypes.MESSAGE(
    75,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s argument to %s in component %s must be a variable."),
  )::ErrorTypes.Message

const NO_MATCHING_FUNCTION_FOUND =
  ErrorTypes.MESSAGE(
    76,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("No matching function found for %s in component %s\\ncandidates are %s"),
  )::ErrorTypes.Message

const NO_MATCHING_FUNCTION_FOUND_NO_CANDIDATE =
  ErrorTypes.MESSAGE(
    77,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("No matching function found for %s."),
  )::ErrorTypes.Message

const FUNCTION_COMPS_MUST_HAVE_DIRECTION =
  ErrorTypes.MESSAGE(
    78,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Component %s in function is neither input nor output."),
  )::ErrorTypes.Message

const FUNCTION_SLOT_ALREADY_FILLED =
  ErrorTypes.MESSAGE(
    79,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Slot %s already filled in a function call in component %s."),
  )::ErrorTypes.Message

const NO_SUCH_PARAMETER =
  ErrorTypes.MESSAGE(
    80,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function %s has no parameter named %s."),
  )::ErrorTypes.Message

const CONSTANT_OR_PARAM_WITH_NONCONST_BINDING =
  ErrorTypes.MESSAGE(
    81,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is a constant or parameter with a non-constant initializer %s."),
  )::ErrorTypes.Message

const WRONG_DIMENSION_TYPE =
  ErrorTypes.MESSAGE(
    82,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Subscript %s of type %s is not a subtype of Integer, Boolean or enumeration."),
  )::ErrorTypes.Message

const TYPE_MISMATCH_IF_EXP =
  ErrorTypes.MESSAGE(
    83,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in if-expression in component %s. True branch: %s has type %s, false branch: %s has type %s."),
  )::ErrorTypes.Message

const UNRESOLVABLE_TYPE =
  ErrorTypes.MESSAGE(
    84,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot resolve type of expression %s. The operands have types %s in component %s."),
  )::ErrorTypes.Message

const INCOMPATIBLE_TYPES =
  ErrorTypes.MESSAGE(
    85,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Incompatible argument types to operation %s in component %s, left type: %s, right type: %s"),
  )::ErrorTypes.Message

const NON_ENCAPSULATED_CLASS_ACCESS =
  ErrorTypes.MESSAGE(
    86,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class %s does not satisfy the requirements for a package. Lookup is therefore restricted to encapsulated elements, but %s is not encapsulated."),
  )::ErrorTypes.Message

const INHERIT_BASIC_WITH_COMPS =
  ErrorTypes.MESSAGE(
    87,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class %s inherits builtin type but has components."),
  )::ErrorTypes.Message

const MODIFIER_TYPE_MISMATCH_ERROR =
  ErrorTypes.MESSAGE(
    88,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in modifier of component %s, expected type %s, got modifier %s of type %s."),
  )::ErrorTypes.Message

const ERROR_FLATTENING =
  ErrorTypes.MESSAGE(
    89,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Error occurred while flattening model %s"),
  )::ErrorTypes.Message

const DUPLICATE_ELEMENTS_NOT_IDENTICAL =
  ErrorTypes.MESSAGE(
    90,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Duplicate elements (due to inherited elements) not identical:\\n  first element is:  %s\\n  second element is: %s"),
  )::ErrorTypes.Message

const PACKAGE_VARIABLE_NOT_CONSTANT =
  ErrorTypes.MESSAGE(
    91,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable %s in package %s is not constant."),
  )::ErrorTypes.Message

const RECURSIVE_DEFINITION =
  ErrorTypes.MESSAGE(
    92,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Declaration of element %s causes recursive definition of class %s."),
  )::ErrorTypes.Message

const NOT_ARRAY_TYPE_IN_FOR_STATEMENT =
  ErrorTypes.MESSAGE(
    93,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expression %s in for-statement must be an array type."),
  )::ErrorTypes.Message

const NON_CLASS_IN_COMP_FUNC_NAME =
  ErrorTypes.MESSAGE(
    94,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found non-class %s while looking for function via component. The only valid form is c.C1..CN.f where c is a scalar component and C1..CN are classes."),
  )::ErrorTypes.Message

const DIFFERENT_VARIABLES_SOLVED_IN_ELSEWHEN =
  ErrorTypes.MESSAGE(
    95,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The same variables must be solved in elsewhen clause as in the when clause."),
  )::ErrorTypes.Message

const CLASS_IN_COMPOSITE_COMP_NAME =
  ErrorTypes.MESSAGE(
    96,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found class %s during lookup of composite component name '%s', expected component."),
  )::ErrorTypes.Message

const MODIFIER_DECLARATION_TYPE_MISMATCH_ERROR =
  ErrorTypes.MESSAGE(
    97,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in modifier of component %s, declared type %s, got modifier %s of type %s."),
  )::ErrorTypes.Message

const ASSERT_CONSTANT_FALSE_ERROR =
  ErrorTypes.MESSAGE(
    98,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Assertion triggered during translation: %s."),
  )::ErrorTypes.Message

const ARRAY_INDEX_OUT_OF_BOUNDS =
  ErrorTypes.MESSAGE(
    99,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Subscript '%s' for dimension %s (size = %s) of %s is out of bounds."),
  )::ErrorTypes.Message

const COMPONENT_CONDITION_VARIABILITY =
  ErrorTypes.MESSAGE(
    100,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Component condition must be parameter or constant expression (in %s)."),
  )::ErrorTypes.Message

const FOUND_CLASS_NAME_VIA_COMPONENT =
  ErrorTypes.MESSAGE(
    101,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class name '%s' was found via a component (only component and function call names may be accessed in this way)."),
  )::ErrorTypes.Message

const FOUND_FUNC_NAME_VIA_COMP_NONCALL =
  ErrorTypes.MESSAGE(
    102,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found function %s by name lookup via component, but this is only valid when the name is used as a function call."),
  )::ErrorTypes.Message

const DUPLICATE_MODIFICATIONS =
  ErrorTypes.MESSAGE(
    103,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Duplicate modification of element %s on %s."),
  )::ErrorTypes.Message

const ILLEGAL_SUBSCRIPT =
  ErrorTypes.MESSAGE(
    104,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal subscript %s for dimensions %s in component %s."),
  )::ErrorTypes.Message

const ILLEGAL_EQUATION_TYPE =
  ErrorTypes.MESSAGE(
    105,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal type in equation %s, only builtin types (Real, String, Integer, Boolean or enumeration) or record type allowed in equation."),
  )::ErrorTypes.Message

const EVAL_LOOP_LIMIT_REACHED =
  ErrorTypes.MESSAGE(
    106,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The loop iteration limit (--evalLoopLimit=%s) was exceeded during evaluation."),
  )::ErrorTypes.Message

const LOOKUP_IN_PARTIAL_CLASS =
  ErrorTypes.MESSAGE(
    107,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is partial, name lookup is not allowed in partial classes."),
  )::ErrorTypes.Message

const MISSING_INNER_PREFIX =
  ErrorTypes.MESSAGE(
    108,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("No corresponding 'inner' declaration found for component %s declared as '%s'.\\n  The existing 'inner' components are:\\n    %s\\n  Check if you have not misspelled the 'outer' component name.\\n  Please declare an 'inner' component with the same name in the top scope.\\n  Continuing flattening by only considering the 'outer' component declaration."),
  )::ErrorTypes.Message

const NON_PARAMETER_ITERATOR_RANGE =
  ErrorTypes.MESSAGE(
    109,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The iteration range %s is not a constant or parameter expression."),
  )::ErrorTypes.Message

const IMPLICIT_ITERATOR_NOT_FOUND_IN_LOOP_BODY =
  ErrorTypes.MESSAGE(
    110,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Identifier %s of implicit for iterator must be present as array subscript in the loop body."),
  )::ErrorTypes.Message

const CONNECTOR_NON_PARAMETER_SUBSCRIPT =
  ErrorTypes.MESSAGE(
    111,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Connector ‘%s‘ has non-parameter subscript ‘%s‘."),
  )::ErrorTypes.Message

const LOOKUP_CLASS_VIA_COMP_COMP =
  ErrorTypes.MESSAGE(
    112,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal access of class '%s' via a component when looking for '%s'."),
  )::ErrorTypes.Message

const SUBSCRIPTED_FUNCTION_CALL =
  ErrorTypes.MESSAGE(
    113,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function call %s contains subscripts."),
  )::ErrorTypes.Message

const IF_EQUATION_UNBALANCED =
  ErrorTypes.MESSAGE(
    114,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In equation %s. If-equation with conditions that are not parameter expressions must have the same number of equations in each branch, equation count is %s for each respective branch."),
  )::ErrorTypes.Message

const IF_EQUATION_MISSING_ELSE =
  ErrorTypes.MESSAGE(
    115,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Missing else-clause in if-equation with non-parameter conditions."),
  )::ErrorTypes.Message

const CONNECT_IN_IF =
  ErrorTypes.MESSAGE(
    116,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("connect may not be used inside if-equations with non-parametric conditions (found connect(%s, %s))."),
  )::ErrorTypes.Message

const CONNECT_IN_WHEN =
  ErrorTypes.MESSAGE(
    117,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("connect may not be used inside when-equations (found connect(%s, %s))."),
  )::ErrorTypes.Message

const CONNECT_INCOMPATIBLE_TYPES =
  ErrorTypes.MESSAGE(
    118,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Incompatible components in connect statement: connect(%s, %s)\\n- %s has components %s\\n- %s has components %s"),
  )::ErrorTypes.Message

const CONNECT_OUTER_OUTER =
  ErrorTypes.MESSAGE(
    119,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal connecting two outer connectors in statement connect(%s, %s)."),
  )::ErrorTypes.Message

const CONNECTOR_ARRAY_NONCONSTANT =
  ErrorTypes.MESSAGE(
    120,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("in statement %s, subscript %s is not a parameter or constant."),
  )::ErrorTypes.Message

const CONNECTOR_ARRAY_DIFFERENT =
  ErrorTypes.MESSAGE(
    121,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unmatched dimension in equation connect(%s, %s), %s != %s."),
  )::ErrorTypes.Message

const MODIFIER_NON_ARRAY_TYPE_WARNING =
  ErrorTypes.MESSAGE(
    122,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Non-array modification '%s' for array component, possibly due to missing 'each'."),
  )::ErrorTypes.Message

const BUILTIN_VECTOR_INVALID_DIMENSIONS =
  ErrorTypes.MESSAGE(
    123,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In scope %s, in component %s: Invalid dimensions %s in %s, no more than one dimension may have size > 1."),
  )::ErrorTypes.Message

const UNROLL_LOOP_CONTAINING_WHEN =
  ErrorTypes.MESSAGE(
    124,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unable to unroll for loop containing when statements or equations: %s."),
  )::ErrorTypes.Message

const CIRCULAR_PARAM =
  ErrorTypes.MESSAGE(
    125,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable '%s' has a cyclic dependency and has variability %s."),
  )::ErrorTypes.Message

const NESTED_WHEN =
  ErrorTypes.MESSAGE(
    126,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Nested when statements are not allowed."),
  )::ErrorTypes.Message

const INVALID_ENUM_LITERAL =
  ErrorTypes.MESSAGE(
    127,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid use of reserved attribute name %s as enumeration literal."),
  )::ErrorTypes.Message

const UNEXPECTED_FUNCTION_INPUTS_WARNING =
  ErrorTypes.MESSAGE(
    128,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Function %s has not the expected inputs. Expected inputs are %s."),
  )::ErrorTypes.Message

const DUPLICATE_CLASSES_NOT_EQUIVALENT =
  ErrorTypes.MESSAGE(
    129,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Duplicate class definitions (due to inheritance) not equivalent, first definition is: %s, second definition is: %s."),
  )::ErrorTypes.Message

const HIGHER_VARIABILITY_BINDING =
  ErrorTypes.MESSAGE(
    130,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Component %s of variability %s has binding %s of higher variability %s."),
  )::ErrorTypes.Message

const IF_EQUATION_WARNING =
  ErrorTypes.MESSAGE(
    131,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("If-equations are only partially supported. Ignoring %s."),
  )::ErrorTypes.Message

const IF_EQUATION_UNBALANCED_2 =
  ErrorTypes.MESSAGE(
    132,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("If-equation with conditions that are not parameter expressions must have the same number of equations in each branch, equation count is %s for each respective branch:\\n%s"),
  )::ErrorTypes.Message

const EQUATION_GENERIC_FAILURE =
  ErrorTypes.MESSAGE(
    133,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to instantiate equation %s."),
  )::ErrorTypes.Message

const INST_PARTIAL_CLASS_CHECK_MODEL_WARNING =
  ErrorTypes.MESSAGE(
    134,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Forcing full instantiation of partial class %s during checkModel."),
  )::ErrorTypes.Message

const VARIABLE_BINDING_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    135,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in binding %s = %s, expected subtype of %s, got type %s."),
  )::ErrorTypes.Message

const COMPONENT_NAME_SAME_AS_TYPE_NAME =
  ErrorTypes.MESSAGE(
    136,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Component %s has the same name as its type %s.\\n\\tThis is forbidden by Modelica specification and may lead to lookup errors."),
  )::ErrorTypes.Message

const CONDITIONAL_EXP_WITHOUT_VALUE =
  ErrorTypes.MESSAGE(
    137,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The conditional expression %s could not be evaluated."),
  )::ErrorTypes.Message

const INCOMPATIBLE_IMPLICIT_RANGES =
  ErrorTypes.MESSAGE(
    138,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Dimension %s of %s and %s of %s differs when trying to deduce implicit iteration range."),
  )::ErrorTypes.Message

const INITIAL_WHEN =
  ErrorTypes.MESSAGE(
    139,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("when-clause is not allowed in initial section."),
  )::ErrorTypes.Message

const MODIFICATION_INDEX_NOT_FOUND =
  ErrorTypes.MESSAGE(
    140,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Instantiation of array component: %s failed because index modification: %s is invalid.\\n\\tArray component: %s has more dimensions than binding %s."),
  )::ErrorTypes.Message

const DUPLICATE_MODIFICATIONS_WARNING =
  ErrorTypes.MESSAGE(
    141,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Duplicate modifications for attribute: %s in modifier: %s.\\n\\tConsidering only the first modification: %s and ignoring the rest %s."),
  )::ErrorTypes.Message

const GENERATECODE_INVARS_HAS_FUNCTION_PTR =
  ErrorTypes.MESSAGE(
    142,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s has a function pointer as input. OpenModelica does not support this feature in the interactive environment. Suggested workaround: Call this function with the arguments you want from another function (that does not have function pointer input). Then call that function from the interactive environment instead."),
  )::ErrorTypes.Message

const LOOKUP_FOUND_WRONG_TYPE =
  ErrorTypes.MESSAGE(
    143,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expected %s to be a %s, but found %s instead."),
  )::ErrorTypes.Message

const DUPLICATE_ELEMENTS_NOT_SYNTACTICALLY_IDENTICAL =
  ErrorTypes.MESSAGE(
    144,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Duplicate elements (due to inherited elements) not syntactically identical but semantically identical:\\n\\tfirst element is:  %s\\tsecond element is: %s\\tModelica specification requires that elements are exactly identical."),
  )::ErrorTypes.Message

const GENERIC_INST_FUNCTION =
  ErrorTypes.MESSAGE(
    145,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to instantiate function %s in scope %s."),
  )::ErrorTypes.Message

const WRONG_NO_OF_ARGS =
  ErrorTypes.MESSAGE(
    146,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong number of arguments to %s."),
  )::ErrorTypes.Message

const TUPLE_ASSIGN_CREFS_ONLY =
  ErrorTypes.MESSAGE(
    147,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Tuple assignment only allowed for tuple of component references in lhs (in %s)."),
  )::ErrorTypes.Message

const LOOKUP_FUNCTION_GOT_CLASS =
  ErrorTypes.MESSAGE(
    148,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Looking for a function %s but found a %s."),
  )::ErrorTypes.Message

const NON_STREAM_OPERAND_IN_STREAM_OPERATOR =
  ErrorTypes.MESSAGE(
    149,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operand ‘%s‘ to operator ‘%s‘ is not a stream variable."),
  )::ErrorTypes.Message

const UNBALANCED_CONNECTOR =
  ErrorTypes.MESSAGE(
    150,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Connector %s is not balanced: %s"),
  )::ErrorTypes.Message

const RESTRICTION_VIOLATION =
  ErrorTypes.MESSAGE(
    151,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class specialization violation: %s is a %s, not a %s."),
  )::ErrorTypes.Message

const ZERO_STEP_IN_ARRAY_CONSTRUCTOR =
  ErrorTypes.MESSAGE(
    152,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Step equals 0 in array constructor %s."),
  )::ErrorTypes.Message

const RECURSIVE_SHORT_CLASS_DEFINITION =
  ErrorTypes.MESSAGE(
    153,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Recursive short class definition of %s in terms of %s."),
  )::ErrorTypes.Message

const WRONG_NUMBER_OF_SUBSCRIPTS =
  ErrorTypes.MESSAGE(
    154,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong number of subscripts in %s (%s subscripts for %s dimensions)."),
  )::ErrorTypes.Message

const FUNCTION_ELEMENT_WRONG_KIND =
  ErrorTypes.MESSAGE(
    155,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Element is not allowed in function context: %s"),
  )::ErrorTypes.Message

const MISSING_BINDING_PROTECTED_RECORD_VAR =
  ErrorTypes.MESSAGE(
    156,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Protected record member %s has no binding and is not modifiable by a record constructor."),
  )::ErrorTypes.Message

const DUPLICATE_CLASSES_TOP_LEVEL =
  ErrorTypes.MESSAGE(
    157,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Duplicate classes on top level is not allowed (got %s)."),
  )::ErrorTypes.Message

const WHEN_EQ_LHS =
  ErrorTypes.MESSAGE(
    158,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid left-hand side of when-equation: %s."),
  )::ErrorTypes.Message

const GENERIC_ELAB_EXPRESSION =
  ErrorTypes.MESSAGE(
    159,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to elaborate expression: %s."),
  )::ErrorTypes.Message

const EXTENDS_EXTERNAL =
  ErrorTypes.MESSAGE(
    160,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Ignoring external declaration of the extended class: %s."),
  )::ErrorTypes.Message

const DOUBLE_DECLARATION_OF_ELEMENTS =
  ErrorTypes.MESSAGE(
    161,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("An element with name %s is already declared in this scope."),
  )::ErrorTypes.Message

const INVALID_REDECLARATION_OF_CLASS =
  ErrorTypes.MESSAGE(
    162,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid redeclaration of class %s, class extends only allowed on inherited classes."),
  )::ErrorTypes.Message

const MULTIPLE_QUALIFIED_IMPORTS_WITH_SAME_NAME =
  ErrorTypes.MESSAGE(
    163,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Qualified import name %s already exists in this scope."),
  )::ErrorTypes.Message

const EXTENDS_INHERITED_FROM_LOCAL_EXTENDS =
  ErrorTypes.MESSAGE(
    164,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s was found in base class %s."),
  )::ErrorTypes.Message

const LOOKUP_FUNCTION_ERROR =
  ErrorTypes.MESSAGE(
    165,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function %s not found in scope %s."),
  )::ErrorTypes.Message

const ELAB_CODE_EXP_FAILED =
  ErrorTypes.MESSAGE(
    166,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to elaborate %s as a code expression of type %s."),
  )::ErrorTypes.Message

const EQUATION_TRANSITION_FAILURE =
  ErrorTypes.MESSAGE(
    167,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Equations are not allowed in %s."),
  )::ErrorTypes.Message

const METARECORD_CONTAINS_METARECORD_MEMBER =
  ErrorTypes.MESSAGE(
    168,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The called uniontype record (%s) contains a member (%s) that has a uniontype record as its type instead of a uniontype."),
  )::ErrorTypes.Message

const INVALID_EXTERNAL_OBJECT =
  ErrorTypes.MESSAGE(
    169,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid external object %s, %s."),
  )::ErrorTypes.Message

const CIRCULAR_COMPONENTS =
  ErrorTypes.MESSAGE(
    170,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cyclically dependent constants or parameters found in scope %s: %s (ignore with -d=ignoreCycles)."),
  )::ErrorTypes.Message

const FAILURE_TO_DEDUCE_DIMS_FROM_MOD =
  ErrorTypes.MESSAGE(
    171,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Failed to deduce dimensions of %s due to unknown dimensions of modifier %s."),
  )::ErrorTypes.Message

const REPLACEABLE_BASE_CLASS =
  ErrorTypes.MESSAGE(
    172,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class '%s' in 'extends %s' is replaceable, the base class name must be transitively non-replaceable."),
  )::ErrorTypes.Message

const NON_REPLACEABLE_CLASS_EXTENDS =
  ErrorTypes.MESSAGE(
    173,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Non-replaceable base class %s in class extends."),
  )::ErrorTypes.Message

const ERROR_FROM_HERE =
  ErrorTypes.MESSAGE(
    174,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("From here:"),
  )::ErrorTypes.Message

const EXTERNAL_FUNCTION_RESULT_NOT_CREF =
  ErrorTypes.MESSAGE(
    175,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The lhs (result) of the external function declaration is not a component reference: %s."),
  )::ErrorTypes.Message

const EXTERNAL_FUNCTION_RESULT_NOT_VAR =
  ErrorTypes.MESSAGE(
    176,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The lhs (result) of the external function declaration is not a variable."),
  )::ErrorTypes.Message

const EXTERNAL_FUNCTION_RESULT_ARRAY_TYPE =
  ErrorTypes.MESSAGE(
    177,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The lhs (result) of the external function declaration has array type (%s), but this is not allowed in the specification. You need to pass it as an input to the function (preferably also with a size()-expression to avoid out-of-bounds errors in the external call)."),
  )::ErrorTypes.Message

const INVALID_REDECLARE =
  ErrorTypes.MESSAGE(
    178,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Redeclaration of %s %s %s is not allowed."),
  )::ErrorTypes.Message

const INVALID_TYPE_PREFIX =
  ErrorTypes.MESSAGE(
    179,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid type prefix '%s' on %s %s, due to existing type prefix '%s'."),
  )::ErrorTypes.Message

const LINEAR_SYSTEM_INVALID =
  ErrorTypes.MESSAGE(
    180,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Linear solver (%s) returned invalid input for linear system %s."),
  )::ErrorTypes.Message

const LINEAR_SYSTEM_SINGULAR =
  ErrorTypes.MESSAGE(
    181,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The linear system: %1\\n might be structurally or numerically singular for variable %3 since U(%2,%2) = 0.0. It might be hard to solve. Compilation continues anyway."),
  )::ErrorTypes.Message

const EMPTY_ARRAY =
  ErrorTypes.MESSAGE(
    182,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array constructor may not be empty."),
  )::ErrorTypes.Message

const LOAD_MODEL_DIFFERENT_VERSIONS =
  ErrorTypes.MESSAGE(
    183,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Requested package %s of version %s, but this package was already loaded with version %s. You might experience problems if these versions are incompatible."),
  )::ErrorTypes.Message

const LOAD_MODEL =
  ErrorTypes.MESSAGE(
    184,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to load package %s (%s) using MODELICAPATH %s."),
  )::ErrorTypes.Message

const REPLACEABLE_BASE_CLASS_SIMPLE =
  ErrorTypes.MESSAGE(
    185,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Base class %s is replaceable."),
  )::ErrorTypes.Message

const INVALID_SIZE_INDEX =
  ErrorTypes.MESSAGE(
    186,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid index %s in call to size of %s, valid index interval is [1,%s]."),
  )::ErrorTypes.Message

const ALGORITHM_TRANSITION_FAILURE =
  ErrorTypes.MESSAGE(
    187,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Algorithm section is not allowed in %s."),
  )::ErrorTypes.Message

const FAILURE_TO_DEDUCE_DIMS_NO_MOD =
  ErrorTypes.MESSAGE(
    188,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to deduce dimension %s of %s due to missing binding equation."),
  )::ErrorTypes.Message

const FUNCTION_MULTIPLE_ALGORITHM =
  ErrorTypes.MESSAGE(
    189,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The behavior of multiple algorithm sections in function %s is not standard Modelica. OpenModelica will execute the sections in the order in which they were declared or inherited (same ordering as inherited input/output arguments, which also are not standardized)."),
  )::ErrorTypes.Message

const STATEMENT_GENERIC_FAILURE =
  ErrorTypes.MESSAGE(
    190,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to instantiate statement:\\n%s"),
  )::ErrorTypes.Message

const EXTERNAL_NOT_SINGLE_RESULT =
  ErrorTypes.MESSAGE(
    191,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is an unbound output in external function %s. Either add it to the external declaration or add a default binding."),
  )::ErrorTypes.Message

const FUNCTION_UNUSED_INPUT =
  ErrorTypes.MESSAGE(
    192,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Unused input variable %s in function %s."),
  )::ErrorTypes.Message

const ARRAY_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    193,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array types mismatch: %s and %s."),
  )::ErrorTypes.Message

const VECTORIZE_TWO_UNKNOWN =
  ErrorTypes.MESSAGE(
    194,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Could not vectorize call with unknown dimensions due to finding two for-iterators: %s and %s."),
  )::ErrorTypes.Message

const FUNCTION_SLOT_VARIABILITY =
  ErrorTypes.MESSAGE(
    195,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function argument %s=%s in call to %s has variability %s which is not a %s expression."),
  )::ErrorTypes.Message

const INVALID_ARRAY_DIM_IN_CONVERSION_OP =
  ErrorTypes.MESSAGE(
    196,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid dimension %s of argument to %s, expected dimension size %s but got %s."),
  )::ErrorTypes.Message

const DUPLICATE_REDECLARATION =
  ErrorTypes.MESSAGE(
    197,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is already redeclared in this scope."),
  )::ErrorTypes.Message

const INVALID_FUNCTION_VAR_TYPE =
  ErrorTypes.MESSAGE(
    198,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid type %s for function component %s."),
  )::ErrorTypes.Message

const IMBALANCED_EQUATIONS =
  ErrorTypes.MESSAGE(
    199,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("An independent subset of the model has imbalanced number of equations (%s) and variables (%s).\\nvariables:\\n%s\\nequations:\\n%s"),
  )::ErrorTypes.Message

const EQUATIONS_VAR_NOT_DEFINED =
  ErrorTypes.MESSAGE(
    200,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable %s is not referenced in any equation (possibly after symbolic manipulations)."),
  )::ErrorTypes.Message

const NON_FORMAL_PUBLIC_FUNCTION_VAR =
  ErrorTypes.MESSAGE(
    201,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Invalid public variable %s, function variables that are not input/output must be protected."),
  )::ErrorTypes.Message

const PROTECTED_FORMAL_FUNCTION_VAR =
  ErrorTypes.MESSAGE(
    202,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid protected variable %s, function variables that are input/output must be public."),
  )::ErrorTypes.Message

const UNFILLED_SLOT =
  ErrorTypes.MESSAGE(
    203,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function parameter %s was not given by the function call, and does not have a default value."),
  )::ErrorTypes.Message

const SAME_CONNECT_INSTANCE =
  ErrorTypes.MESSAGE(
    204,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("connect(%s, %s) connects the same connector instance! The connect equation will be ignored."),
  )::ErrorTypes.Message

const STACK_OVERFLOW =
  ErrorTypes.MESSAGE(
    205,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Stack overflow occurred while evaluating %s."),
  )::ErrorTypes.Message

const UNKNOWN_DEBUG_FLAG =
  ErrorTypes.MESSAGE(
    206,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unknown debug flag %s."),
  )::ErrorTypes.Message

const INVALID_FLAG_TYPE =
  ErrorTypes.MESSAGE(
    207,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid type of flag %s, expected %s but got %s."),
  )::ErrorTypes.Message

const CHANGED_STD_VERSION =
  ErrorTypes.MESSAGE(
    208,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Modelica language version set to %s due to loading of MSL %s."),
  )::ErrorTypes.Message

const SIMPLIFY_FIXPOINT_MAXIMUM =
  ErrorTypes.MESSAGE(
    209,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Expression simplification iterated to the fix-point maximum, which may be a performance bottleneck. The last two iterations were: %s, and %s."),
  )::ErrorTypes.Message

const UNKNOWN_OPTION =
  ErrorTypes.MESSAGE(
    210,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unknown option %s."),
  )::ErrorTypes.Message

const SUBSCRIPTED_MODIFIER =
  ErrorTypes.MESSAGE(
    211,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Subscripted modifier is illegal."),
  )::ErrorTypes.Message

const TRANS_VIOLATION =
  ErrorTypes.MESSAGE(
    212,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Class specialization violation: %s is a %s, which may not contain an %s."),
  )::ErrorTypes.Message

const INSERT_CLASS =
  ErrorTypes.MESSAGE(
    213,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to insert class %s %s the available classes were:%s"),
  )::ErrorTypes.Message

const MISSING_MODIFIED_ELEMENT =
  ErrorTypes.MESSAGE(
    214,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Modified element %s not found in class %s."),
  )::ErrorTypes.Message

const INVALID_REDECLARE_IN_BASIC_TYPE =
  ErrorTypes.MESSAGE(
    215,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid redeclaration of %s, attributes of basic types may not be redeclared."),
  )::ErrorTypes.Message

const INVALID_STREAM_CONNECTOR =
  ErrorTypes.MESSAGE(
    216,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid stream connector %s: %s"),
  )::ErrorTypes.Message

const CONDITION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    217,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in condition '%s' of component %s. Expected a Boolean expression, but got an expression of type %s."),
  )::ErrorTypes.Message

const SIMPLIFY_CONSTANT_ERROR =
  ErrorTypes.MESSAGE(
    218,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The compiler failed to perform constant folding on expression %s. Please report this bug to the developers and we will fix it as soon as possible (using the +t compiler option if possible)."),
  )::ErrorTypes.Message

const SUM_EXPECTED_ARRAY =
  ErrorTypes.MESSAGE(
    219,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In sum(%s), the expression is of type %s, but is required to be of builtin array type (of any number of dimensions)."),
  )::ErrorTypes.Message

const INVALID_CLASS_RESTRICTION =
  ErrorTypes.MESSAGE(
    220,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid specialized class type '%s' for component %s."),
  )::ErrorTypes.Message

const CONNECT_IN_INITIAL_EQUATION =
  ErrorTypes.MESSAGE(
    221,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Connect equations are not allowed in initial equation sections."),
  )::ErrorTypes.Message

const FINAL_COMPONENT_OVERRIDE =
  ErrorTypes.MESSAGE(
    222,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to override final element %s with modifier '%s'."),
  )::ErrorTypes.Message

const NOTIFY_NOT_LOADED =
  ErrorTypes.MESSAGE(
    223,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Automatically loaded package %s %s due to uses annotation."),
  )::ErrorTypes.Message

const REINIT_MUST_BE_REAL =
  ErrorTypes.MESSAGE(
    224,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument to reinit must be a subtype of Real, but %s has type %s."),
  )::ErrorTypes.Message

const REINIT_MUST_BE_VAR =
  ErrorTypes.MESSAGE(
    225,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument to reinit must be a continuous time variable, but %s is %s."),
  )::ErrorTypes.Message

const CONNECT_TWO_SOURCES =
  ErrorTypes.MESSAGE(
    226,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Connecting two signal sources while connecting %s to %s."),
  )::ErrorTypes.Message

const INNER_OUTER_FORMAL_PARAMETER =
  ErrorTypes.MESSAGE(
    227,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid prefix %s on formal parameter %s."),
  )::ErrorTypes.Message

const REDECLARE_NONEXISTING_ELEMENT =
  ErrorTypes.MESSAGE(
    228,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal redeclare of element %s, no inherited element with that name exists."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_TYPE_FIRST_ARRAY =
  ErrorTypes.MESSAGE(
    229,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument of %s must be an array expression."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_TYPE_BRANCH_FIRST =
  ErrorTypes.MESSAGE(
    230,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument '%s' of %s must have the form A.R, where A is a connector and R an over-determined type/record."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_TYPE_BRANCH_SECOND =
  ErrorTypes.MESSAGE(
    231,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The second argument '%s' of %s must have the form A.R, where A is a connector and R an over-determined type/record."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_TYPE_OVERDET_FIRST =
  ErrorTypes.MESSAGE(
    232,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument of %s must be an over-determined type or record."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_TYPE_OVERDET_SECOND =
  ErrorTypes.MESSAGE(
    233,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The second argument of %s must be an over-determined type or record."),
  )::ErrorTypes.Message

const LIBRARY_ONE_PACKAGE_PER_FILE =
  ErrorTypes.MESSAGE(
    234,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Modelica library files should contain exactly one package, but found the following classes: %s."),
  )::ErrorTypes.Message

const LIBRARY_UNEXPECTED_WITHIN =
  ErrorTypes.MESSAGE(
    235,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expected the package to have %s but got %s."),
  )::ErrorTypes.Message

const LIBRARY_UNEXPECTED_NAME =
  ErrorTypes.MESSAGE(
    236,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expected the package to have name %s, but got %s."),
  )::ErrorTypes.Message

const PACKAGE_MO_NOT_IN_ORDER =
  ErrorTypes.MESSAGE(
    237,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Elements in the package.mo-file need to be in the same relative order as the package.order file. Got element named %s but it was already added because it was not the next element in the list at that time."),
  )::ErrorTypes.Message

const LIBRARY_EXPECTED_PARTS =
  ErrorTypes.MESSAGE(
    238,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is a package.mo-file and needs to be based on class parts (i.e. not class extends, derived class, or enumeration)."),
  )::ErrorTypes.Message

const PACKAGE_ORDER_FILE_NOT_FOUND =
  ErrorTypes.MESSAGE(
    239,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.WARNING(),
    Gettext.gettext("%1 was referenced in the package.order file, but was not found in package.mo, %1/package.mo or %1.mo."),
  )::ErrorTypes.Message

const FOUND_ELEMENT_NOT_IN_ORDER_FILE =
  ErrorTypes.MESSAGE(
    240,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Got element %1 that was not referenced in the package.order file."),
  )::ErrorTypes.Message

const ORDER_FILE_COMPONENTS =
  ErrorTypes.MESSAGE(
    241,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Components referenced in the package.order file must be moved in full chunks. Either split the constants to different lines or make them subsequent in the package.order file."),
  )::ErrorTypes.Message

const GUARD_EXPRESSION_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    242,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Guard expressions need to be Boolean, got expression of type %s."),
  )::ErrorTypes.Message

const FUNCTION_RETURNS_META_ARRAY =
  ErrorTypes.MESSAGE(
    243,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("User-defined function calls that return Array<...> are not supported: %s."),
  )::ErrorTypes.Message

const ASSIGN_UNKNOWN_ERROR =
  ErrorTypes.MESSAGE(
    244,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed elaborate assignment for some unknown reason: %1 := %2. File a bug report and we will make sure this error gets a better message in the future."),
  )::ErrorTypes.Message

const WARNING_DEF_USE =
  ErrorTypes.MESSAGE(
    245,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("%s was used before it was defined (given a value). Additional such uses may exist for the variable, but some messages were suppressed."),
  )::ErrorTypes.Message

const EXP_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    246,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expression '%1' has type %3, expected type %2."),
  )::ErrorTypes.Message

const PACKAGE_ORDER_DUPLICATES =
  ErrorTypes.MESSAGE(
    247,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Found duplicate names in package.order file: %s."),
  )::ErrorTypes.Message

const ERRONEOUS_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    248,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Got type mismatch error, but matching types %s.\\nThis is a ***COMPILER BUG***, please report it to https://trac.openmodelica.org/OpenModelica."),
  )::ErrorTypes.Message

const REINIT_MUST_BE_VAR_OR_ARRAY =
  ErrorTypes.MESSAGE(
    249,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument to reinit must be a variable of type Real or an array of such variables."),
  )::ErrorTypes.Message

const SLICE_ASSIGN_NON_ARRAY =
  ErrorTypes.MESSAGE(
    250,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot assign slice to non-initialized array %s."),
  )::ErrorTypes.Message

const EXTERNAL_ARG_WRONG_EXP =
  ErrorTypes.MESSAGE(
    251,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expression %s cannot be an external argument. Only identifiers, scalar constants, and size-expressions are allowed."),
  )::ErrorTypes.Message

const OPERATOR_FUNCTION_NOT_EXPECTED =
  ErrorTypes.MESSAGE(
    252,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Only classes of type 'operator record' may contain elements of type 'operator function'; %s was found in a class that has restriction '%s'."),
  )::ErrorTypes.Message

const OPERATOR_FUNCTION_EXPECTED =
  ErrorTypes.MESSAGE(
    253,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("'operator record' classes may only contain elements of type 'operator function'; %s has restriction '%s'."),
  )::ErrorTypes.Message

const STRUCTURAL_SINGULAR_INITIAL_SYSTEM =
  ErrorTypes.MESSAGE(
    254,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Initialization problem is structurally singular, error found sorting equations \\n %s for variables \\n %s"),
  )::ErrorTypes.Message

const UNFIXED_PARAMETER_WITH_BINDING =
  ErrorTypes.MESSAGE(
    255,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The parameter %s has fixed = false and a binding equation %s = %s, which is probably redundant.\\nSetting fixed = false usually means there is an additional initial equation to determine the parameter value. The binding was ignored by old Modelica tools, but this is not according to the Modelica specification. Please remove the parameter binding, or bind the parameter to another parameter with fixed = false and no binding."),
  )::ErrorTypes.Message

const UNFIXED_PARAMETER_WITH_BINDING_31 =
  ErrorTypes.MESSAGE(
    256,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The parameter %s has fixed = false and a binding equation %s = %s, which is probably redundant. The binding equation will be ignored, as it is expected for Modelica 3.1."),
  )::ErrorTypes.Message

const UNFIXED_PARAMETER_WITH_BINDING_AND_START_VALUE_31 =
  ErrorTypes.MESSAGE(
    257,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The parameter %s has fixed = false, a start value, start = %s and a binding equation %s = %s, which is probably redundant. The binding equation will be ignored, as it is expected for Modelica 3.1."),
  )::ErrorTypes.Message

const BACKENDDAEINFO_LOWER =
  ErrorTypes.MESSAGE(
    258,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Model statistics after passing the front-end and creating the data structures used by the back-end:\\n * Number of equations: %s\\n * Number of variables: %s"),
  )::ErrorTypes.Message

const BACKENDDAEINFO_STATISTICS =
  ErrorTypes.MESSAGE(
    259,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Model statistics after passing the back-end for %s:\\n * Number of independent subsystems: %s\\n * Number of states: %s\\n * Number of discrete variables: %s\\n * Number of discrete states: %s\\n * Top-level inputs: %s"),
  )::ErrorTypes.Message

const BACKENDDAEINFO_MIXED =
  ErrorTypes.MESSAGE(
    260,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Mixed equation statistics:\\n * Mixed systems with single equation: %s\\n * Mixed systems with array equation: %s\\n * Mixed systems with algorithm: %s\\n * Mixed systems with complex equation: %s\\n * Mixed systems with constant Jacobian: %s\\n * Mixed systems with linear Jacobian: %s\\n * Mixed systems with non-linear Jacobian: %s\\n * Mixed systems with analytic Jacobian: %s\\n * Mixed systems with linear tearing system: %s\\n * Mixed systems with nonlinear tearing system: %s"),
  )::ErrorTypes.Message

const BACKENDDAEINFO_STRONGCOMPONENT_STATISTICS =
  ErrorTypes.MESSAGE(
    261,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Strong component statistics for %s (%s):\\n * Single equations (assignments): %s\\n * Array equations: %s\\n * Algorithm blocks: %s\\n * Record equations: %s\\n * When equations: %s\\n * If-equations: %s\\n * Equation systems (linear and non-linear blocks): %s\\n * Torn equation systems: %s\\n * Mixed (continuous/discrete) equation systems: %s"),
  )::ErrorTypes.Message

const BACKENDDAEINFO_SYSTEMS =
  ErrorTypes.MESSAGE(
    262,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Equation system details:\\n * Constant Jacobian: %s\\n * Linear Jacobian (size,density): %s\\n * Non-linear Jacobian: %s\\n * Without analytic Jacobian: %s"),
  )::ErrorTypes.Message

const BACKENDDAEINFO_TORN =
  ErrorTypes.MESSAGE(
    263,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Torn system details for %s tearing set:\\n * Linear torn systems: %s\\n * Non-linear torn systems: %s"),
  )::ErrorTypes.Message

const BACKEND_DAE_TO_MODELICA =
  ErrorTypes.MESSAGE(
    264,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The following Modelica-like model represents the back-end DAE for the '%s' stage:\\n%s"),
  )::ErrorTypes.Message

const NEGATIVE_DIMENSION_INDEX =
  ErrorTypes.MESSAGE(
    265,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Negative dimension index (%s) for component %s."),
  )::ErrorTypes.Message

const GENERATE_SEPARATE_CODE_DEPENDENCIES_FAILED =
  ErrorTypes.MESSAGE(
    266,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to get dependencies for package %s. Perhaps there is an import to a non-existing package."),
  )::ErrorTypes.Message

const CYCLIC_DEFAULT_VALUE =
  ErrorTypes.MESSAGE(
    267,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The default value of %s causes a cyclic dependency."),
  )::ErrorTypes.Message

const NAMED_ARG_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    268,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch for named argument in %s(%s=%s). The argument has type:\\n  %s\\nexpected type:\\n  %s"),
  )::ErrorTypes.Message

const ARG_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    269,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch for positional argument %s in %s(%s=%s). The argument has type:\\n  %s\\nexpected type:\\n  %s"),
  )::ErrorTypes.Message

const OP_OVERLOAD_MULTIPLE_VALID =
  ErrorTypes.MESSAGE(
    270,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator overloading requires exactly one matching expression, but found %s expressions: %s"),
  )::ErrorTypes.Message

const OP_OVERLOAD_OPERATOR_NOT_INPUT =
  ErrorTypes.MESSAGE(
    271,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator %s is not an input to the overloaded function: %s"),
  )::ErrorTypes.Message

const NOTIFY_FRONTEND_STRUCTURAL_PARAMETERS =
  ErrorTypes.MESSAGE(
    272,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The following structural parameters were evaluated in the front-end: %s\\nStructural parameters are parameters used to calculate array dimensions or branch selection in certain if-equations or if-expressions among other things."),
  )::ErrorTypes.Message

const SIMPLIFICATION_TYPE =
  ErrorTypes.MESSAGE(
    273,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Expression simplification '%s' → '%s' changed the type from %s to %s."),
  )::ErrorTypes.Message

const VECTORIZE_CALL_DIM_MISMATCH =
  ErrorTypes.MESSAGE(
    274,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to vectorize function call because arguments %s=%s and %s=%s have mismatched dimensions %s and %s."),
  )::ErrorTypes.Message

const TCOMPLEX_MULTIPLE_NAMES =
  ErrorTypes.MESSAGE(
    275,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Non-tuple complex type specifiers need to have exactly one type name: %s."),
  )::ErrorTypes.Message

const TCOMPLEX_TUPLE_ONE_NAME =
  ErrorTypes.MESSAGE(
    276,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Tuple complex type specifiers need to have more than one type name: %s."),
  )::ErrorTypes.Message

const ENUM_DUPLICATES =
  ErrorTypes.MESSAGE(
    277,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Enumeration has duplicate names: %s in list of names %s."),
  )::ErrorTypes.Message

const RESERVED_IDENTIFIER =
  ErrorTypes.MESSAGE(
    278,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Identifier %s is reserved for the built-in element with the same name."),
  )::ErrorTypes.Message

const NOTIFY_PKG_FOUND =
  ErrorTypes.MESSAGE(
    279,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("You can install the requested package using one of the commands:\\n%s."),
  )::ErrorTypes.Message

const DERIVATIVE_FUNCTION_CONTEXT =
  ErrorTypes.MESSAGE(
    280,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The der() operator is not allowed in function context (possible solutions: pass the derivative as an explicit input; use a block instead of function)."),
  )::ErrorTypes.Message

const RETURN_OUTSIDE_FUNCTION =
  ErrorTypes.MESSAGE(
    281,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("'return' may not be used outside function."),
  )::ErrorTypes.Message

const EXT_LIBRARY_NOT_FOUND =
  ErrorTypes.MESSAGE(
    282,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Could not find library %s in either of:%s"),
  )::ErrorTypes.Message

const EXT_LIBRARY_NOT_FOUND_DESPITE_COMPILATION_SUCCESS =
  ErrorTypes.MESSAGE(
    283,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Could not find library %s despite compilation command %s in directory %s returning success."),
  )::ErrorTypes.Message

const GENERATE_SEPARATE_CODE_DEPENDENCIES_FAILED_UNKNOWN_PACKAGE =
  ErrorTypes.MESSAGE(
    284,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to get dependencies for package %s. %s contains an import to non-existing package %s."),
  )::ErrorTypes.Message

const USE_OF_PARTIAL_CLASS =
  ErrorTypes.MESSAGE(
    285,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("component %s contains the definition of a partial class %s.\\nPlease redeclare it to any package compatible with %s."),
  )::ErrorTypes.Message

const SCANNER_ERROR =
  ErrorTypes.MESSAGE(
    286,
    ErrorTypes.SYNTAX(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Syntax error, unrecognized input: %s."),
  )::ErrorTypes.Message

const SCANNER_ERROR_LIMIT =
  ErrorTypes.MESSAGE(
    287,
    ErrorTypes.SYNTAX(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Additional syntax errors were suppressed."),
  )::ErrorTypes.Message

const INVALID_TIME_SCOPE =
  ErrorTypes.MESSAGE(
    288,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Built-in variable 'time' may only be used in a model or block."),
  )::ErrorTypes.Message

const NO_JACONIAN_TORNLINEAR_SYSTEM =
  ErrorTypes.MESSAGE(
    289,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("A torn linear system has no symbolic jacobian and currently there are no means to solve that numerically. Please compile with the module \\calculateStrongComponentJacobians\\ to provide symbolic jacobians for torn linear systems."),
  )::ErrorTypes.Message

const EXT_FN_SINGLE_RETURN_ARRAY =
  ErrorTypes.MESSAGE(
    290,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("An external declaration with a single output without explicit mapping is defined as having the output as the lhs, but language %s does not support this for array variables. OpenModelica will put the output as an input (as is done when there is more than 1 output), but this is not according to the Modelica Specification. Use an explicit mapping instead of the implicit one to suppress this warning."),
  )::ErrorTypes.Message

const RHS_TUPLE_EXPRESSION =
  ErrorTypes.MESSAGE(
    291,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Tuple expressions may only occur on the left side of an assignment or equation with a single function call on the right side. Got the following expression: %s."),
  )::ErrorTypes.Message

const EACH_ON_NON_ARRAY =
  ErrorTypes.MESSAGE(
    292,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("'each' used when modifying non-array element %s."),
  )::ErrorTypes.Message

const BUILTIN_EXTENDS_INVALID_ELEMENTS =
  ErrorTypes.MESSAGE(
    293,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("A class extending from builtin type %s may not have other elements."),
  )::ErrorTypes.Message

const INITIAL_CALL_WARNING =
  ErrorTypes.MESSAGE(
    294,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The standard says that initial() may only be used as a when condition (when initial() or when {..., initial(), ...}), but got condition %s."),
  )::ErrorTypes.Message

const RANGE_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    295,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in range: '%s' of type\\n  %s\\nis not type compatible with '%s' of type\\n  %s"),
  )::ErrorTypes.Message

const RANGE_TOO_SMALL_STEP =
  ErrorTypes.MESSAGE(
    296,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Step size %s in range is too small."),
  )::ErrorTypes.Message

const RANGE_INVALID_STEP =
  ErrorTypes.MESSAGE(
    297,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Range of type %s may not specify a step size."),
  )::ErrorTypes.Message

const RANGE_INVALID_TYPE =
  ErrorTypes.MESSAGE(
    298,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Range has invalid type %s."),
  )::ErrorTypes.Message

const CLASS_EXTENDS_MISSING_REDECLARE =
  ErrorTypes.MESSAGE(
    299,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Missing redeclare prefix on class extends %s, treating like redeclare anyway."),
  )::ErrorTypes.Message

const CYCLIC_DIMENSIONS =
  ErrorTypes.MESSAGE(
    300,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Dimension %s of %s, '%s', could not be evaluated due to a cyclic dependency."),
  )::ErrorTypes.Message

const INVALID_DIMENSION_TYPE =
  ErrorTypes.MESSAGE(
    301,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Dimension '%s' of type %s is not an integer expression or an enumeration or Boolean type name."),
  )::ErrorTypes.Message

const RAGGED_DIMENSION =
  ErrorTypes.MESSAGE(
    302,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Ragged dimensions are not yet supported (from dimension '%s')"),
  )::ErrorTypes.Message

const INVALID_TYPENAME_USE =
  ErrorTypes.MESSAGE(
    303,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type name '%s' is not allowed in this context."),
  )::ErrorTypes.Message

const FOUND_WRONG_INNER_ELEMENT =
  ErrorTypes.MESSAGE(
    305,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found inner %s %s instead of expected %s."),
  )::ErrorTypes.Message

const FOUND_OTHER_BASECLASS =
  ErrorTypes.MESSAGE(
    306,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found other base class for extends %s after instantiating extends."),
  )::ErrorTypes.Message

const OUTER_ELEMENT_MOD =
  ErrorTypes.MESSAGE(
    307,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Modifier '%s' found on outer element %s."),
  )::ErrorTypes.Message

const OUTER_LONG_CLASS =
  ErrorTypes.MESSAGE(
    308,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Illegal outer class %s, outer classes may only be declared using short-class definitions."),
  )::ErrorTypes.Message

const MISSING_INNER_ADDED =
  ErrorTypes.MESSAGE(
    309,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("An inner declaration for outer %s %s could not be found and was automatically generated."),
  )::ErrorTypes.Message

const MISSING_INNER_MESSAGE =
  ErrorTypes.MESSAGE(
    310,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The diagnostics message for the missing inner is: %s"),
  )::ErrorTypes.Message

const INVALID_CONNECTOR_FORM =
  ErrorTypes.MESSAGE(
    311,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is not a valid form for a connector, connectors must be either c1.c2...cn or m.c (where c is a connector and m is a non-connector)."),
  )::ErrorTypes.Message

const CONNECTOR_PREFIX_OUTSIDE_CONNECTOR =
  ErrorTypes.MESSAGE(
    312,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Prefix '%s' used outside connector declaration."),
  )::ErrorTypes.Message

const EXTERNAL_OBJECT_INVALID_ELEMENT =
  ErrorTypes.MESSAGE(
    313,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("External object %s contains invalid element '%s'."),
  )::ErrorTypes.Message

const EXTERNAL_OBJECT_MISSING_STRUCTOR =
  ErrorTypes.MESSAGE(
    314,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("External object %s is missing a %s."),
  )::ErrorTypes.Message

const MULTIPLE_SECTIONS_IN_FUNCTION =
  ErrorTypes.MESSAGE(
    315,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function %s has more than one algorithm section or external declaration."),
  )::ErrorTypes.Message

const INVALID_EXTERNAL_LANGUAGE =
  ErrorTypes.MESSAGE(
    316,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("'%s' is not a valid language for an external function."),
  )::ErrorTypes.Message

const SUBSCRIPT_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    317,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Subscript '%s' has type %s, expected type %s."),
  )::ErrorTypes.Message

const EXP_INVALID_IN_FUNCTION =
  ErrorTypes.MESSAGE(
    318,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is not allowed in a function."),
  )::ErrorTypes.Message

const NO_MATCHING_FUNCTION_FOUND_NFINST =
  ErrorTypes.MESSAGE(
    319,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("No matching function found for %s.\\nCandidates are:\\n  %s"),
  )::ErrorTypes.Message

const ARGUMENT_OUT_OF_RANGE =
  ErrorTypes.MESSAGE(
    320,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Argument %s of %s is out of range (%s)"),
  )::ErrorTypes.Message

const UNBOUND_CONSTANT =
  ErrorTypes.MESSAGE(
    321,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Constant %s is used without having been given a value."),
  )::ErrorTypes.Message

const INVALID_ARGUMENT_VARIABILITY =
  ErrorTypes.MESSAGE(
    322,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Argument %s of %s must be a %s expression, but %s is %s."),
  )::ErrorTypes.Message

const AMBIGUOUS_MATCHING_FUNCTIONS_NFINST =
  ErrorTypes.MESSAGE(
    323,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Ambiguous matching functions found for %s.\\nCandidates are:\\n  %s"),
  )::ErrorTypes.Message

const AMBIGUOUS_MATCHING_OPERATOR_FUNCTIONS_NFINST =
  ErrorTypes.MESSAGE(
    324,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Ambiguous matching overloaded operator functions found for %s.\\nCandidates are:\\n  %s"),
  )::ErrorTypes.Message

const REDECLARE_CONDITION =
  ErrorTypes.MESSAGE(
    325,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid redeclaration of %s, a redeclare may not have a condition attribute."),
  )::ErrorTypes.Message

const REDECLARE_OF_CONSTANT =
  ErrorTypes.MESSAGE(
    326,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is constant and may not be redeclared."),
  )::ErrorTypes.Message

const REDECLARE_MISMATCHED_PREFIX =
  ErrorTypes.MESSAGE(
    327,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid redeclaration '%s %s', original element is declared '%s'."),
  )::ErrorTypes.Message

const EXTERNAL_ARG_NONCONSTANT_SIZE_INDEX =
  ErrorTypes.MESSAGE(
    328,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid external argument '%s', the dimension index must be a constant expression."),
  )::ErrorTypes.Message

const FAILURE_TO_DEDUCE_DIMS_EACH =
  ErrorTypes.MESSAGE(
    329,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to deduce dimension %s of ‘%s‘ due to ‘each‘ prefix on binding equation."),
  )::ErrorTypes.Message

const MISSING_TYPE_BASETYPE =
  ErrorTypes.MESSAGE(
    330,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type ‘%s‘ does not extend a basic type."),
  )::ErrorTypes.Message

const ASSERT_TRIGGERED_WARNING =
  ErrorTypes.MESSAGE(
    331,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("assert triggered: %s"),
  )::ErrorTypes.Message

const ASSERT_TRIGGERED_ERROR =
  ErrorTypes.MESSAGE(
    332,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("assert triggered: %s"),
  )::ErrorTypes.Message

const TERMINATE_TRIGGERED =
  ErrorTypes.MESSAGE(
    333,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("terminate triggered: %s"),
  )::ErrorTypes.Message

const EVAL_RECURSION_LIMIT_REACHED =
  ErrorTypes.MESSAGE(
    334,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The recursion limit (--evalRecursionLimit=%s) was exceeded during evaluation of %s."),
  )::ErrorTypes.Message

const UNASSIGNED_FUNCTION_OUTPUT =
  ErrorTypes.MESSAGE(
    335,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Output parameter %s was not assigned a value"),
  )::ErrorTypes.Message

const INVALID_WHEN_STATEMENT_CONTEXT =
  ErrorTypes.MESSAGE(
    336,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("A when-statement may not be used inside a function or a while, if, or for-clause."),
  )::ErrorTypes.Message

const MISSING_FUNCTION_DERIVATIVE_NAME =
  ErrorTypes.MESSAGE(
    337,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Derivative annotation for function ‘%s‘ does not specify a derivative function."),
  )::ErrorTypes.Message

const INVALID_FUNCTION_DERIVATIVE_ATTR =
  ErrorTypes.MESSAGE(
    338,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("‘%s‘ is not a valid function derivative attribute."),
  )::ErrorTypes.Message

const INVALID_FUNCTION_DERIVATIVE_INPUT =
  ErrorTypes.MESSAGE(
    339,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("‘%s‘ is not an input of function ‘%s‘."),
  )::ErrorTypes.Message

const OPERATOR_OVERLOADING_ONE_OUTPUT_ERROR =
  ErrorTypes.MESSAGE(
    340,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator %s must have exactly one output."),
  )::ErrorTypes.Message

const OPERATOR_OVERLOADING_INVALID_OUTPUT_TYPE =
  ErrorTypes.MESSAGE(
    341,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Output ‘%s‘ in operator %s must be of type %s, got type %s."),
  )::ErrorTypes.Message

const OPERATOR_NOT_ENCAPSULATED =
  ErrorTypes.MESSAGE(
    342,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator %s is not encapsulated."),
  )::ErrorTypes.Message

const NO_SUCH_INPUT_PARAMETER =
  ErrorTypes.MESSAGE(
    343,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function %s has no input parameter named %s."),
  )::ErrorTypes.Message

const INVALID_REDUCTION_TYPE =
  ErrorTypes.MESSAGE(
    344,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid expression ‘%s‘ of type %s in %s reduction, expected %s."),
  )::ErrorTypes.Message

const INVALID_COMPONENT_PREFIX =
  ErrorTypes.MESSAGE(
    345,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Prefix ‘%s‘ on component ‘%s‘ not allowed in class specialization ‘%s‘."),
  )::ErrorTypes.Message

const INVALID_CARDINALITY_CONTEXT =
  ErrorTypes.MESSAGE(
    346,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("cardinality may only be used in the condition of an if-statement/equation or an assert."),
  )::ErrorTypes.Message

const VARIABLE_BINDING_DIMS_MISMATCH =
  ErrorTypes.MESSAGE(
    347,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in binding ‘%s = %s‘, expected array dimensions %s, got %s."),
  )::ErrorTypes.Message

const MODIFIER_NON_ARRAY_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    348,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Non-array modification ‘%s‘ for array component ‘%s‘, possibly due to missing ‘each‘."),
  )::ErrorTypes.Message

const INST_RECURSION_LIMIT_REACHED =
  ErrorTypes.MESSAGE(
    349,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Recursion limit reached while instantiating ‘%s‘."),
  )::ErrorTypes.Message

const WHEN_IF_VARIABLE_MISMATCH =
  ErrorTypes.MESSAGE(
    350,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The branches of an if-equation inside a when-equation must have the same set of component references on the left-hand side."),
  )::ErrorTypes.Message

const DIMENSION_DEDUCTION_FROM_BINDING_FAILURE =
  ErrorTypes.MESSAGE(
    351,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Dimension %s of ‘%s‘ could not be deduced from the component's binding equation ‘%s‘."),
  )::ErrorTypes.Message

const NON_REAL_FLOW_OR_STREAM =
  ErrorTypes.MESSAGE(
    352,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid prefix ‘%s‘ on non-Real component ‘%s‘."),
  )::ErrorTypes.Message

const LIBRARY_UNEXPECTED_NAME_CASE_SENSITIVE =
  ErrorTypes.MESSAGE(
    353,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Expected the package to have name %s, but got %s. Proceeding since only the case of the names are different."),
  )::ErrorTypes.Message

const PACKAGE_ORDER_CASE_SENSITIVE =
  ErrorTypes.MESSAGE(
    354,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The package.order file contains a class %s, which is expected to be stored in file %s, but seems to be named %s. Proceeding since only the case of the names are different."),
  )::ErrorTypes.Message

const REDECLARE_CLASS_NON_SUBTYPE =
  ErrorTypes.MESSAGE(
    355,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Redeclaration of %s ‘%s‘ is not a subtype of the redeclared element."),
  )::ErrorTypes.Message

const REDECLARE_ENUM_NON_SUBTYPE =
  ErrorTypes.MESSAGE(
    356,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Redeclaration of enumeration ‘%s‘ is not a subtype of the redeclared element (use enumeration(:) for a generic replaceable enumeration)."),
  )::ErrorTypes.Message

const CONDITIONAL_COMPONENT_INVALID_CONTEXT =
  ErrorTypes.MESSAGE(
    357,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Conditional component ‘%s‘ is used in a non-connect context."),
  )::ErrorTypes.Message

const OPERATOR_RECORD_MISSING_OPERATOR =
  ErrorTypes.MESSAGE(
    358,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type ‘%s‘ of expression ‘%s‘ in ‘%s‘ does not implement the required operator ‘%s‘"),
  )::ErrorTypes.Message

const IMPORT_IN_COMPOSITE_NAME =
  ErrorTypes.MESSAGE(
    359,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found imported name ‘%s‘ while looking up composite name ‘%s‘."),
  )::ErrorTypes.Message

const SHADOWED_ITERATOR =
  ErrorTypes.MESSAGE(
    360,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("An iterator named ‘%s‘ is already declared in this scope."),
  )::ErrorTypes.Message

const W_INVALID_ARGUMENT_TYPE_BRANCH_FIRST =
  ErrorTypes.MESSAGE(
    361,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The first argument '%s' of %s must have the form A.R, where A is a connector and R an over-determined type/record."),
  )::ErrorTypes.Message

const W_INVALID_ARGUMENT_TYPE_BRANCH_SECOND =
  ErrorTypes.MESSAGE(
    362,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The second argument '%s' of %s must have the form A.R, where A is a connector and R an over-determined type/record."),
  )::ErrorTypes.Message

const INITIALIZATION_NOT_FULLY_SPECIFIED =
  ErrorTypes.MESSAGE(
    496,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The initial conditions are not fully specified. %s."),
  )::ErrorTypes.Message

const INITIALIZATION_OVER_SPECIFIED =
  ErrorTypes.MESSAGE(
    497,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The initial conditions are over specified. %s."),
  )::ErrorTypes.Message

const INITIALIZATION_ITERATION_VARIABLES =
  ErrorTypes.MESSAGE(
    498,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("There are nonlinear iteration variables with default zero start attribute found in %s. %s."),
  )::ErrorTypes.Message

const UNBOUND_PARAMETER_WITH_START_VALUE_WARNING =
  ErrorTypes.MESSAGE(
    499,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Parameter %s has no value, and is fixed during initialization (fixed=true), using available start value (start=%s) as default value."),
  )::ErrorTypes.Message

const UNBOUND_PARAMETER_WARNING =
  ErrorTypes.MESSAGE(
    500,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Parameter %s has neither value nor start value, and is fixed during initialization (fixed=true)."),
  )::ErrorTypes.Message

const BUILTIN_FUNCTION_PRODUCT_HAS_SCALAR_PARAMETER =
  ErrorTypes.MESSAGE(
    502,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Function \\product\\ has scalar as argument in %s in component %s."),
  )::ErrorTypes.Message

const SETTING_FIXED_ATTRIBUTE =
  ErrorTypes.MESSAGE(
    503,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Using over-determined solver for initialization. Setting fixed=false to the following variables: %s."),
  )::ErrorTypes.Message

const FAILED_TO_EVALUATE_FUNCTION =
  ErrorTypes.MESSAGE(
    506,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to evaluate function: %s."),
  )::ErrorTypes.Message

const WARNING_RELATION_ON_REAL =
  ErrorTypes.MESSAGE(
    509,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("In relation %s, %s on Real numbers is only allowed inside functions."),
  )::ErrorTypes.Message

const OUTER_MODIFICATION =
  ErrorTypes.MESSAGE(
    512,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Ignoring the modification on outer element: %s."),
  )::ErrorTypes.Message

const DERIVATIVE_NON_REAL =
  ErrorTypes.MESSAGE(
    514,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Argument '%s' to der has illegal type %s, must be a subtype of Real."),
  )::ErrorTypes.Message

const UNUSED_MODIFIER =
  ErrorTypes.MESSAGE(
    515,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In modifier %s."),
  )::ErrorTypes.Message

const MULTIPLE_MODIFIER =
  ErrorTypes.MESSAGE(
    516,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Multiple modifiers in same scope for element %s."),
  )::ErrorTypes.Message

const INCONSISTENT_UNITS =
  ErrorTypes.MESSAGE(
    517,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The system of units is inconsistent in term %s with the units %s and %s respectively."),
  )::ErrorTypes.Message

const CONSISTENT_UNITS =
  ErrorTypes.MESSAGE(
    518,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The system of units is consistent."),
  )::ErrorTypes.Message

const INCOMPLETE_UNITS =
  ErrorTypes.MESSAGE(
    519,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("The system of units is incomplete. Please provide unit information to the model by e.g. using types from the SIunits package."),
  )::ErrorTypes.Message

const ASSIGN_RHS_ELABORATION =
  ErrorTypes.MESSAGE(
    521,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to elaborate rhs of %s."),
  )::ErrorTypes.Message

const FAILED_TO_EVALUATE_EXPRESSION =
  ErrorTypes.MESSAGE(
    522,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Could not evaluate expression: %s"),
  )::ErrorTypes.Message

const WARNING_JACOBIAN_EQUATION_SOLVE =
  ErrorTypes.MESSAGE(
    523,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Jacobian equation %s could not solve proper for %s. Assume %s=0."),
  )::ErrorTypes.Message

const SIMPLIFICATION_COMPLEXITY =
  ErrorTypes.MESSAGE(
    523,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Simplification produced a higher complexity (%s) than the original (%s). The simplification was: %s => %s."),
  )::ErrorTypes.Message

const ITERATOR_NON_ARRAY =
  ErrorTypes.MESSAGE(
    524,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Iterator %s, has type %s, but expected a 1D array expression."),
  )::ErrorTypes.Message

const INST_INVALID_RESTRICTION =
  ErrorTypes.MESSAGE(
    525,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot instantiate %s due to class specialization %s."),
  )::ErrorTypes.Message

const INST_NON_LOADED =
  ErrorTypes.MESSAGE(
    526,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Library %s was not loaded but is marked as used by model %s."),
  )::ErrorTypes.Message

const RECURSION_DEPTH_REACHED =
  ErrorTypes.MESSAGE(
    527,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The maximum recursion depth of %s was reached, probably due to mutual recursion. The current scope: %s."),
  )::ErrorTypes.Message

const DERIVATIVE_INPUT =
  ErrorTypes.MESSAGE(
    528,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The model requires derivatives of some inputs as listed below:\\n%s"),
  )::ErrorTypes.Message

const UTF8_COMMAND_LINE_ARGS =
  ErrorTypes.MESSAGE(
    529,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The compiler was sent command-line arguments that were not UTF-8 encoded and will abort the current execution."),
  )::ErrorTypes.Message

const PACKAGE_ORDER_FILE_NOT_COMPLETE =
  ErrorTypes.MESSAGE(
    530,
    ErrorTypes.GRAMMAR(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The package.order file does not list all .mo files and directories (containing package.mo) present in its directory.\\nMissing names are:\\n\\t%s"),
  )::ErrorTypes.Message

const REINIT_IN_WHEN_INITIAL =
  ErrorTypes.MESSAGE(
    531,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Using reinit in when with condition initial() is not allowed. Use assignment or equality equation instead."),
  )::ErrorTypes.Message

const MISSING_INNER_CLASS =
  ErrorTypes.MESSAGE(
    532,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("No corresponding 'inner' declaration found for class %s declared as '%s'.\\n Continuing flattening by only considering the 'outer' class declaration."),
  )::ErrorTypes.Message

const RECURSION_DEPTH_WARNING =
  ErrorTypes.MESSAGE(
    533,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The maximum recursion depth of %s was reached when evaluating expression %s in scope %s. Translation may still succeed but you are recommended to fix the problem."),
  )::ErrorTypes.Message

const RECURSION_DEPTH_DERIVED =
  ErrorTypes.MESSAGE(
    534,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The maximum recursion depth of was reached when instantiating a derived class. Current class %s in scope %s."),
  )::ErrorTypes.Message

const EVAL_EXTERNAL_OBJECT_CONSTRUCTOR =
  ErrorTypes.MESSAGE(
    535,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("OpenModelica requires that all external objects input arguments are possible to evaluate before initialization in order to avoid odd run-time failures, but %s is a variable."),
  )::ErrorTypes.Message

const CLASS_ANNOTATION_DOES_NOT_EXIST =
  ErrorTypes.MESSAGE(
    536,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Could not find class annotation %s in class %s."),
  )::ErrorTypes.Message

const SEPARATE_COMPILATION_PACKAGE_FAILED =
  ErrorTypes.MESSAGE(
    537,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to compile all functions in package %s."),
  )::ErrorTypes.Message

const INVALID_ARRAY_DIM_IN_SCALAR_OP =
  ErrorTypes.MESSAGE(
    538,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The operator scalar requires all dimension size to be 1, but the input has type %s."),
  )::ErrorTypes.Message

const NON_STANDARD_OPERATOR_CLASS_DIRECTORY =
  ErrorTypes.MESSAGE(
    539,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("classDirectory() is a non-standard operator that was replaced by Modelica.Utilities.Files.loadResource(uri) before it was added to the language specification."),
  )::ErrorTypes.Message

const PACKAGE_DUPLICATE_CHILDREN =
  ErrorTypes.MESSAGE(
    540,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The same class is defined in multiple files: %s."),
  )::ErrorTypes.Message

const INTEGER_ENUMERATION_CONVERSION_WARNING =
  ErrorTypes.MESSAGE(
    541,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Integer (%s) to enumeration (%s) conversion is not valid Modelica, please use enumeration constant (%s) instead."),
  )::ErrorTypes.Message

const INTEGER_ENUMERATION_OUT_OF_RANGE =
  ErrorTypes.MESSAGE(
    542,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The Integer to %s conversion failed, as the Integer %s is outside the range (1, ..., %s) of values corresponding to enumeration constants."),
  )::ErrorTypes.Message

const INTEGER_TO_UNKNOWN_ENUMERATION =
  ErrorTypes.MESSAGE(
    543,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.INTERNAL(),
    Gettext.gettext("The Integer (%s) to enumeration conversion failed because information about the the enumeration type is missing."),
  )::ErrorTypes.Message

const NORETCALL_INVALID_EXP =
  ErrorTypes.MESSAGE(
    544,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expression %s is not a valid statement - only function calls are allowed."),
  )::ErrorTypes.Message

const INVALID_FLAG_TYPE_STRINGS =
  ErrorTypes.MESSAGE(
    545,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid type of flag %s, expected one of %s but got %s."),
  )::ErrorTypes.Message

const FUNCTION_RETURN_EXT_OBJ =
  ErrorTypes.MESSAGE(
    546,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Function %s returns an external object, but the only function allowed to return this object is %s."),
  )::ErrorTypes.Message

const NON_STANDARD_OPERATOR =
  ErrorTypes.MESSAGE(
    547,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Usage of non-standard operator (not specified in the Modelica specification): %s. Functionality might be partially supported but is not guaranteed."),
  )::ErrorTypes.Message

const CONNECT_ARRAY_SIZE_ZERO =
  ErrorTypes.MESSAGE(
    548,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Ignoring connection of array components having size zero: %s and %s."),
  )::ErrorTypes.Message

const ILLEGAL_RECORD_COMPONENT =
  ErrorTypes.MESSAGE(
    549,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Ignoring record component:\\n%swhen building the record constructor. Records are allowed to contain only components of basic types, arrays of basic types or other records."),
  )::ErrorTypes.Message

const EQ_WITHOUT_TIME_DEP_VARS =
  ErrorTypes.MESSAGE(
    550,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Found equation without time-dependent variables: %s = %s"),
  )::ErrorTypes.Message

const OVERCONSTRAINED_OPERATOR_SIZE_ZERO =
  ErrorTypes.MESSAGE(
    551,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Ignoring overconstrained operator applied to array components having size zero: %s."),
  )::ErrorTypes.Message

const OVERCONSTRAINED_OPERATOR_SIZE_ZERO_RETURN_FALSE =
  ErrorTypes.MESSAGE(
    552,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Returning false from overconstrained operator applied to array components having size zero: %s."),
  )::ErrorTypes.Message

const MISMATCHING_INTERFACE_TYPE =
  ErrorTypes.MESSAGE(
    553,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("__OpenModelica_Interface types are incompatible. Got interface type '%s', expected something compatible with '%s'."),
  )::ErrorTypes.Message

const MISSING_INTERFACE_TYPE =
  ErrorTypes.MESSAGE(
    554,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Annotation __OpenModelica_Interface is missing or the string is not in the input list."),
  )::ErrorTypes.Message

const CLASS_NOT_FOUND =
  ErrorTypes.MESSAGE(
    555,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Class %s not found inside class %s."),
  )::ErrorTypes.Message

const NOTIFY_LOAD_MODEL_FAILED =
  ErrorTypes.MESSAGE(
    556,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Skipped loading package %s (%s) using MODELICAPATH %s (uses-annotation may be wrong)."),
  )::ErrorTypes.Message

const ROOT_USER_INTERACTIVE =
  ErrorTypes.MESSAGE(
    557,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("You are trying to run OpenModelica as a server using the root user.\\nThis is a very bad idea:\\n* The socket interface does not authenticate the user.\\n* OpenModelica allows execution of arbitrary commands."),
  )::ErrorTypes.Message

const USES_MISSING_VERSION =
  ErrorTypes.MESSAGE(
    558,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Uses-annotation is missing version for library %s. Assuming the tool-specific version=\\default\\."),
  )::ErrorTypes.Message

const CLOCK_PREFIX_ERROR =
  ErrorTypes.MESSAGE(
    559,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Clock variable can not be declared with prefixes flow, stream, discrete, parameter, or constant."),
  )::ErrorTypes.Message

const DEFAULT_CLOCK_USED =
  ErrorTypes.MESSAGE(
    560,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Default inferred clock is used."),
  )::ErrorTypes.Message

const CONT_CLOCKED_PARTITION_CONFLICT_VAR =
  ErrorTypes.MESSAGE(
    561,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Variable %s belongs to clocked and continuous partitions."),
  )::ErrorTypes.Message

const ELSE_WHEN_CLOCK =
  ErrorTypes.MESSAGE(
    562,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Clocked when equation can not contain elsewhen part."),
  )::ErrorTypes.Message

const REINIT_NOT_IN_WHEN =
  ErrorTypes.MESSAGE(
    563,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator reinit may only be used in the body of a when equation."),
  )::ErrorTypes.Message

const NESTED_CLOCKED_WHEN =
  ErrorTypes.MESSAGE(
    564,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Nested clocked when statements are not allowed."),
  )::ErrorTypes.Message

const CLOCKED_WHEN_BRANCH =
  ErrorTypes.MESSAGE(
    565,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Clocked when branch in when equation."),
  )::ErrorTypes.Message

const CLOCKED_WHEN_IN_WHEN_EQ =
  ErrorTypes.MESSAGE(
    566,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Clocked when equation inside the body of when equation."),
  )::ErrorTypes.Message

const CONT_CLOCKED_PARTITION_CONFLICT_EQ =
  ErrorTypes.MESSAGE(
    567,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Equation belongs to clocked and continuous partitions."),
  )::ErrorTypes.Message

const CLOCK_SOLVERMETHOD =
  ErrorTypes.MESSAGE(
    568,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Applying clock solverMethod %s instead of specified %s. Supported are: ImplicitEuler, SemiImplicitEuler, ExplicitEuler and ImplicitTrapezoid."),
  )::ErrorTypes.Message

const INVALID_CLOCK_EQUATION =
  ErrorTypes.MESSAGE(
    569,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid form of clock equation"),
  )::ErrorTypes.Message

const SUBCLOCK_CONFLICT =
  ErrorTypes.MESSAGE(
    570,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Partition has different sub-clock %ss (%s) and (%s)."),
  )::ErrorTypes.Message

const CLOCK_CONFLICT =
  ErrorTypes.MESSAGE(
    571,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Partitions have different base clocks."),
  )::ErrorTypes.Message

const EXEC_STAT =
  ErrorTypes.MESSAGE(
    572,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Performance of %s: time %s/%s, allocations: %s / %s, free: %s / %s"),
  )::ErrorTypes.Message

const EXEC_STAT_GC =
  ErrorTypes.MESSAGE(
    573,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Performance of %s: time %s/%s, GC stats:%s"),
  )::ErrorTypes.Message

const MAX_TEARING_SIZE =
  ErrorTypes.MESSAGE(
    574,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Tearing is skipped for strong component %s because system size of %s exceeds maximum system size for tearing of %s systems (%s).\\nTo adjust the maximum system size for tearing use --maxSizeLinearTearing=<size> and --maxSizeNonlinearTearing=<size>.\\n"),
  )::ErrorTypes.Message

const NO_TEARING_FOR_COMPONENT =
  ErrorTypes.MESSAGE(
    575,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Tearing is skipped for strong component %s because of activated compiler flag 'noTearingForComponent=%1'.\\n"),
  )::ErrorTypes.Message

const WRONG_VALUE_OF_ARG =
  ErrorTypes.MESSAGE(
    576,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong value of argument to %s: %s = %s %s."),
  )::ErrorTypes.Message

const USER_DEFINED_TEARING_ERROR =
  ErrorTypes.MESSAGE(
    577,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Wrong usage of user defined tearing: %s Make sure you use user defined tearing as stated in the flag description."),
  )::ErrorTypes.Message

const USER_TEARING_VARS =
  ErrorTypes.MESSAGE(
    578,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Following iteration variables are selected by the user for strong component %s (DAE kind: %s):\\n%s"),
  )::ErrorTypes.Message

const CLASS_EXTENDS_TARGET_NOT_FOUND =
  ErrorTypes.MESSAGE(
    579,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Base class targeted by class extends %s not found in the inherited classes."),
  )::ErrorTypes.Message

const ASSIGN_PARAM_FIXED_ERROR =
  ErrorTypes.MESSAGE(
    580,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Trying to assign to parameter component %s(fixed=true) in %s := %s"),
  )::ErrorTypes.Message

const EQN_NO_SPACE_TO_SOLVE =
  ErrorTypes.MESSAGE(
    581,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Equation %s (size: %s) %s is not big enough to solve for enough variables.\\n  Remaining unsolved variables are: %s\\n  Already solved: %s\\n  Equations used to solve those variables:%s"),
  )::ErrorTypes.Message

const VAR_NO_REMAINING_EQN =
  ErrorTypes.MESSAGE(
    582,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Variable %s does not have any remaining equation to be solved in.\\n  The original equations were:%s"),
  )::ErrorTypes.Message

const MOVING_PARAMETER_BINDING_TO_INITIAL_EQ_SECTION =
  ErrorTypes.MESSAGE(
    583,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Moving binding to initial equation section and setting fixed attribute of %s to false."),
  )::ErrorTypes.Message

const MIXED_DETERMINED =
  ErrorTypes.MESSAGE(
    584,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The initialization problem of given system is mixed-determined. It is under- as well as overdetermined and the mixed-determination-index is too high. [index > %s]\\nPlease checkout the option \\--maxMixedDeterminedIndex\\ to simulate with a higher threshold or consider changing some initial equations, fixed variables and start values."),
  )::ErrorTypes.Message

const STACK_OVERFLOW_DETAILED =
  ErrorTypes.MESSAGE(
    585,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Stack overflow occurred while evaluating %s:\\n%s"),
  )::ErrorTypes.Message

const NF_VECTOR_INVALID_DIMENSIONS =
  ErrorTypes.MESSAGE(
    586,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid dimensions %s in %s, no more than one dimension may have size > 1."),
  )::ErrorTypes.Message

const NF_ARRAY_TYPE_MISMATCH =
  ErrorTypes.MESSAGE(
    587,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Array types mismatch. Argument %s (%s) has type %s whereas previous arguments have type %s."),
  )::ErrorTypes.Message

const NF_DIFFERENT_NUM_DIM_IN_ARGUMENTS =
  ErrorTypes.MESSAGE(
    588,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Different number of dimensions (%s) in arguments to %s."),
  )::ErrorTypes.Message

const NF_CAT_WRONG_DIMENSION =
  ErrorTypes.MESSAGE(
    589,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument of cat characterizes an existing dimension in the other arguments (1..%s), but got dimension %s."),
  )::ErrorTypes.Message

const NF_CAT_FIRST_ARG_EVAL =
  ErrorTypes.MESSAGE(
    590,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The first argument of cat must be possible to evaluate during compile-time. Expression %s has variability %s."),
  )::ErrorTypes.Message

const COMMA_OPERATOR_DIFFERENT_SIZES =
  ErrorTypes.MESSAGE(
    591,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Arguments of concatenation comma operator have different sizes for the first dimension: %s has dimension %s and %s has dimension %s."),
  )::ErrorTypes.Message

const NON_STATE_STATESELECT_ALWAYS =
  ErrorTypes.MESSAGE(
    592,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Variable %s has attribute stateSelect=StateSelect.always, but was selected as a continuous variable."),
  )::ErrorTypes.Message

const STATE_STATESELECT_NEVER =
  ErrorTypes.MESSAGE(
    593,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Variable %s has attribute stateSelect=StateSelect.never, but was selected as a state"),
  )::ErrorTypes.Message

const FUNCTION_HIGHER_VARIABILITY_BINDING =
  ErrorTypes.MESSAGE(
    594,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Component ‘%s’ of variability %s has binding %s of higher variability %s."),
  )::ErrorTypes.Message

const OCG_MISSING_BRANCH =
  ErrorTypes.MESSAGE(
    595,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Connections.rooted(%s) needs exactly one statement Connections.branch(%s, B.R) involving %s but we found none in the graph. Run with -d=cgraphGraphVizFile to debug"),
  )::ErrorTypes.Message

const UNBOUND_PARAMETER_EVALUATE_TRUE =
  ErrorTypes.MESSAGE(
    596,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Parameter %s has annotation(Evaluate=true) and no binding."),
  )::ErrorTypes.Message

const FMI_URI_RESOLVE =
  ErrorTypes.MESSAGE(
    597,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Could not resolve URI (%s) at compile-time; copying all loaded packages into the FMU"),
  )::ErrorTypes.Message

const PATTERN_MIXED_POS_NAMED =
  ErrorTypes.MESSAGE(
    598,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Call to %s contains mixed positional and named arguments."),
  )::ErrorTypes.Message

const STATE_STATESELECT_NEVER_FORCED =
  ErrorTypes.MESSAGE(
    599,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Following variables have attribute stateSelect=StateSelect.never, but cant be statically chosen. %s"),
  )::ErrorTypes.Message

const STATE_STATESELECT_PREFER_REVERT =
  ErrorTypes.MESSAGE(
    600,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Some equations could not be differentiated for following variables having attribute stateSelect=StateSelect.prefer. %s"),
  )::ErrorTypes.Message

const ERROR_PKG_NOT_IDENT =
  ErrorTypes.MESSAGE(
    601,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The package manager only accepts simple identifiers (%s has a dot in it)."),
  )::ErrorTypes.Message

const ERROR_PKG_NOT_FOUND_VERSION =
  ErrorTypes.MESSAGE(
    602,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The package index did not contain an entry for package %s that provides version %s."),
  )::ErrorTypes.Message

const ERROR_PKG_NOT_EXACT_MATCH =
  ErrorTypes.MESSAGE(
    603,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The package index did not contain an entry for package %s of version %s. There are other versions that claim to be compatible: %s."),
  )::ErrorTypes.Message

const ERROR_PKG_INDEX_NOT_ON_PATH =
  ErrorTypes.MESSAGE(
    604,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The MODELICAPATH (%s) does not contain %s, so the package index cannot be used."),
  )::ErrorTypes.Message

const ERROR_PKG_INDEX_NOT_FOUND =
  ErrorTypes.MESSAGE(
    605,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The package index does not exist: %s."),
  )::ErrorTypes.Message

const ERROR_PKG_INDEX_NOT_PARSED =
  ErrorTypes.MESSAGE(
    606,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The package index %s could not be parsed."),
  )::ErrorTypes.Message

const ERROR_PKG_INDEX_FAILED_DOWNLOAD =
  ErrorTypes.MESSAGE(
    607,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to download package index %s to file %s."),
  )::ErrorTypes.Message

const NOTIFY_PKG_INDEX_DOWNLOAD =
  ErrorTypes.MESSAGE(
    608,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Downloaded package index from URL %s."),
  )::ErrorTypes.Message

const NOTIFY_PKG_INSTALL_DONE =
  ErrorTypes.MESSAGE(
    609,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Package installed successfully (SHA %s)."),
  )::ErrorTypes.Message

const NOTIFY_PKG_UPGRADE_DONE =
  ErrorTypes.MESSAGE(
    609,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Package upgraded successfully (SHA %s from %s)."),
  )::ErrorTypes.Message

const ERROR_PKG_INSTALL_NO_PACKAGE_MO =
  ErrorTypes.MESSAGE(
    611,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("After extracting %s, %s does not exist. Removing the failed installation."),
  )::ErrorTypes.Message

const WARNING_PKG_CONFLICTING_VERSIONS =
  ErrorTypes.MESSAGE(
    612,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Conflicting versions for loading package %s: %s is to be installed, but another package requires version %s which is not provided by this version."),
  )::ErrorTypes.Message

const MATCH_SHADOWING =
  ErrorTypes.MESSAGE(
    5001,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Local variable '%s' shadows another variable."),
  )::ErrorTypes.Message

const META_POLYMORPHIC =
  ErrorTypes.MESSAGE(
    5002,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s uses invalid subtypeof syntax. Only subtypeof Any is supported."),
  )::ErrorTypes.Message

const META_FUNCTION_TYPE_NO_PARTIAL_PREFIX =
  ErrorTypes.MESSAGE(
    5003,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("%s is used as a function reference, but doesn't specify the partial prefix."),
  )::ErrorTypes.Message

const META_MATCH_EQUATION_FORBIDDEN =
  ErrorTypes.MESSAGE(
    5004,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Match expression equation sections forbid the use of %s-equations."),
  )::ErrorTypes.Message

const META_UNIONTYPE_ALIAS_MODS =
  ErrorTypes.MESSAGE(
    5005,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Uniontype %s was not generated correctly. One possible cause is modifications, which are not allowed."),
  )::ErrorTypes.Message

const META_COMPLEX_TYPE_MOD =
  ErrorTypes.MESSAGE(
    5006,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("MetaModelica complex types may not have modifiers."),
  )::ErrorTypes.Message

const META_CEVAL_FUNCTION_REFERENCE =
  ErrorTypes.MESSAGE(
    5008,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot evaluate function pointers (got %s)."),
  )::ErrorTypes.Message

const NON_INSTANTIATED_FUNCTION =
  ErrorTypes.MESSAGE(
    5009,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Tried to use function %s, but it was not instantiated."),
  )::ErrorTypes.Message

const META_UNSOLVED_POLYMORPHIC_BINDINGS =
  ErrorTypes.MESSAGE(
    5010,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Could not solve the polymorphism in the function call to %s\\n  Input bindings:\\n%s\\n  Solved bindings:\\n%s\\n  Unsolved bindings:\\n%s"),
  )::ErrorTypes.Message

const META_RECORD_FOUND_FAILURE =
  ErrorTypes.MESSAGE(
    5011,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In record constructor %s: %s"),
  )::ErrorTypes.Message

const META_INVALID_PATTERN =
  ErrorTypes.MESSAGE(
    5012,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid pattern: %s"),
  )::ErrorTypes.Message

const META_MATCH_GENERAL_FAILURE =
  ErrorTypes.MESSAGE(
    5014,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to elaborate match expression %s"),
  )::ErrorTypes.Message

const META_CONS_TYPE_MATCH =
  ErrorTypes.MESSAGE(
    5015,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Failed to match types of cons expression %s. The head has type %s and the tail %s."),
  )::ErrorTypes.Message

const META_NONE_CREF =
  ErrorTypes.MESSAGE(
    5017,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("NONE is not acceptable syntax. Use NONE() instead."),
  )::ErrorTypes.Message

const META_INVALID_PATTERN_NAMED_FIELD =
  ErrorTypes.MESSAGE(
    5018,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid named fields: %s. Valid field names: %s."),
  )::ErrorTypes.Message

const META_INVALID_LOCAL_ELEMENT =
  ErrorTypes.MESSAGE(
    5019,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Only components without direction are allowed in local declarations, got: %s"),
  )::ErrorTypes.Message

const META_INVALID_COMPLEX_TYPE =
  ErrorTypes.MESSAGE(
    5020,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Invalid complex type name: %s"),
  )::ErrorTypes.Message

const META_CONSTRUCTOR_NOT_PART_OF_UNIONTYPE =
  ErrorTypes.MESSAGE(
    5021,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("In pattern %s: %s is not part of uniontype %s"),
  )::ErrorTypes.Message

const META_TYPE_MISMATCH_PATTERN =
  ErrorTypes.MESSAGE(
    5022,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Type mismatch in pattern %s\\nexpression type:\\n  %s\\npattern type:\\n  %s"),
  )::ErrorTypes.Message

const META_CONSTRUCTOR_NOT_RECORD =
  ErrorTypes.MESSAGE(
    5023,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Call pattern is not a record constructor %s"),
  )::ErrorTypes.Message

const META_MATCHEXP_RESULT_TYPES =
  ErrorTypes.MESSAGE(
    5024,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Match expression has mismatched result types:%s"),
  )::ErrorTypes.Message

const MATCHCONTINUE_TO_MATCH_OPTIMIZATION =
  ErrorTypes.MESSAGE(
    5025,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("This matchcontinue expression has no overlapping patterns and should be using match instead of matchcontinue."),
  )::ErrorTypes.Message

const META_DEAD_CODE =
  ErrorTypes.MESSAGE(
    5026,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Dead code elimination: %s."),
  )::ErrorTypes.Message

const META_UNUSED_DECL =
  ErrorTypes.MESSAGE(
    5027,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Unused local variable: %s."),
  )::ErrorTypes.Message

const META_UNUSED_AS_BINDING =
  ErrorTypes.MESSAGE(
    5028,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Removing unused as-binding: %s."),
  )::ErrorTypes.Message

const MATCH_TO_SWITCH_OPTIMIZATION =
  ErrorTypes.MESSAGE(
    5029,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Converted match expression to switch of type %s."),
  )::ErrorTypes.Message

const REDUCTION_TYPE_ERROR =
  ErrorTypes.MESSAGE(
    5030,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Reductions require the types of the %s and %s to be %s, but got: %s and %s."),
  )::ErrorTypes.Message

const UNSUPPORTED_REDUCTION_TYPE =
  ErrorTypes.MESSAGE(
    5031,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expected a reduction function with type signature ('A,'B) => 'B, but got %s."),
  )::ErrorTypes.Message

const FOUND_NON_NUMERIC_TYPES =
  ErrorTypes.MESSAGE(
    5032,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Operator %s expects numeric types as operands, but got '%s and %s'."),
  )::ErrorTypes.Message

const STRUCTURAL_PARAMETER_OR_CONSTANT_WITH_NO_BINDING =
  ErrorTypes.MESSAGE(
    5033,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Could not evaluate structural parameter (or constant): %s which gives dimensions of array: %s. Array dimensions must be known at compile time."),
  )::ErrorTypes.Message

const META_UNUSED_ASSIGNMENT =
  ErrorTypes.MESSAGE(
    5034,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Removing unused assignment to: %s."),
  )::ErrorTypes.Message

const META_EMPTY_CALL_PATTERN =
  ErrorTypes.MESSAGE(
    5035,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Removing empty call named pattern argument: %s."),
  )::ErrorTypes.Message

const META_ALL_EMPTY =
  ErrorTypes.MESSAGE(
    5036,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("All patterns in call were empty: %s."),
  )::ErrorTypes.Message

const DUPLICATE_DEFINITION =
  ErrorTypes.MESSAGE(
    5037,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("The same variable is being defined twice: %s."),
  )::ErrorTypes.Message

const PATTERN_VAR_NOT_VARIABLE =
  ErrorTypes.MESSAGE(
    5038,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Identifiers need to point to local or output variables. Variable %s is %s."),
  )::ErrorTypes.Message

const LIST_REVERSE_WRONG_ORDER =
  ErrorTypes.MESSAGE(
    5039,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("%1:=listAppend(%1, _) has the first argument in the \\wrong\\ order.\\n  It is very slow to keep appending a linked list (scales like O(N²)).\\n  Consider building the list in the reverse order in order to improve performance (scales like O(N) even if you need to reverse a lot of lists). Use annotation __OpenModelica_DisableListAppendWarning=true to disable this message for a certain assignment."),
  )::ErrorTypes.Message

const IS_PRESENT_WRONG_SCOPE =
  ErrorTypes.MESSAGE(
    5040,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("isPresent needs to be called from a function scope, got %s."),
  )::ErrorTypes.Message

const IS_PRESENT_WRONG_DIRECTION =
  ErrorTypes.MESSAGE(
    5041,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("isPresent needs to be called on an input or output formal parameter."),
  )::ErrorTypes.Message

const IS_PRESENT_INVALID_EXP =
  ErrorTypes.MESSAGE(
    5042,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("isPresent needs to be called on an input or output formal parameter, but got a non-identifier expression: %s."),
  )::ErrorTypes.Message

const METARECORD_WITH_TYPEVARS =
  ErrorTypes.MESSAGE(
    5043,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Records inside uniontypes must not contain type variables (got: %s). Put them on the uniontype instead."),
  )::ErrorTypes.Message

const UNIONTYPE_MISSING_TYPEVARS =
  ErrorTypes.MESSAGE(
    5044,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Uniontype %s has type variables, but they were not given in the declaration."),
  )::ErrorTypes.Message

const UNIONTYPE_WRONG_NUM_TYPEVARS =
  ErrorTypes.MESSAGE(
    5045,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Uniontype %s has %s type variables, but got %s."),
  )::ErrorTypes.Message

const SERIALIZED_SIZE =
  ErrorTypes.MESSAGE(
    5046,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("%s uses %s of memory (%s without GC overhead; %s is consumed by not performing String sharing)."),
  )::ErrorTypes.Message

const META_MATCH_CONSTANT =
  ErrorTypes.MESSAGE(
    5047,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.gettext("Match input %s is a constant value."),
  )::ErrorTypes.Message

const CONVERSION_MISSING_FROM_VERSION =
  ErrorTypes.MESSAGE(
    5048,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Conversion-annotation is missing version for from-conversion: %s."),
  )::ErrorTypes.Message

const CONVERSION_UNKNOWN_ANNOTATION =
  ErrorTypes.MESSAGE(
    5049,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Conversion-annotation contains unknown element: %s."),
  )::ErrorTypes.Message

const COMPILER_ERROR =
  ErrorTypes.MESSAGE(
    5999,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const COMPILER_WARNING =
  ErrorTypes.MESSAGE(
    6000,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const COMPILER_NOTIFICATION =
  ErrorTypes.MESSAGE(
    6001,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const COMPILER_NOTIFICATION_SCRIPTING =
  ErrorTypes.MESSAGE(
    6002,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.NOTIFICATION(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const SUSAN_ERROR =
  ErrorTypes.MESSAGE(
    7000,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const TEMPLATE_ERROR =
  ErrorTypes.MESSAGE(
    7001,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Template error: %s."),
  )::ErrorTypes.Message

const PARMODELICA_WARNING =
  ErrorTypes.MESSAGE(
    7004,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.WARNING(),
    Gettext.notrans("ParModelica: %s."),
  )::ErrorTypes.Message

const PARMODELICA_ERROR =
  ErrorTypes.MESSAGE(
    7005,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.notrans("ParModelica: %s."),
  )::ErrorTypes.Message

const OPTIMICA_ERROR =
  ErrorTypes.MESSAGE(
    7006,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.notrans("Optimica: %s."),
  )::ErrorTypes.Message

const FILE_NOT_FOUND_ERROR =
  ErrorTypes.MESSAGE(
    7007,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("File not Found: %s."),
  )::ErrorTypes.Message

const UNKNOWN_FMU_VERSION =
  ErrorTypes.MESSAGE(
    7008,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unknown FMU version %s. Only version 1.0 & 2.0 are supported."),
  )::ErrorTypes.Message

const UNKNOWN_FMU_TYPE =
  ErrorTypes.MESSAGE(
    7009,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unknown FMU type %s. Supported types are me (model exchange), cs (co-simulation) & me_cs (model exchange & co-simulation)."),
  )::ErrorTypes.Message

const FMU_EXPORT_NOT_SUPPORTED =
  ErrorTypes.MESSAGE(
    7010,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Export of FMU type %s for version %s is not supported. Supported combinations are me (model exchange) for versions 1.0 & 2.0, cs (co-simulation) & me_cs (model exchange & co-simulation) for version 2.0."),
  )::ErrorTypes.Message
#=  FIGARO_ERROR added by Alexander Carlqvist
=#

const FIGARO_ERROR =
  ErrorTypes.MESSAGE(
    7011,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.notrans("Figaro: %s."),
  )::ErrorTypes.Message

const SUSAN_NOTIFY =
  ErrorTypes.MESSAGE(
    7012,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.NOTIFICATION(),
    Gettext.notrans("%s"),
  )::ErrorTypes.Message

const PDEModelica_ERROR =
  ErrorTypes.MESSAGE(
    7013,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("PDEModelica: %s"),
  )::ErrorTypes.Message

const TEMPLATE_ERROR_FUNC =
  ErrorTypes.MESSAGE(
    7014,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Template error: A template call failed (%s). One possible reason could be that a template imported function call failed (which should not happen for functions called from within template code; templates assert pure 'match'/non-failing semantics)."),
  )::ErrorTypes.Message

const FMU_EXPORT_NOT_SUPPORTED_CPP =
  ErrorTypes.MESSAGE(
    7015,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("Export of FMU type %s is not supported with Cpp target. FMU will be for Model Exchange (me)."),
  )::ErrorTypes.Message

const DEPRECATED_API_CALL =
  ErrorTypes.MESSAGE(
    7016,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.WARNING(),
    Gettext.gettext("'%1' is deprecated. It is recommended to use '%2' instead."),
  )::ErrorTypes.Message

const CONFLICTING_ALIAS_SET =
  ErrorTypes.MESSAGE(
    7017,
    ErrorTypes.SYMBOLIC(),
    ErrorTypes.WARNING(),
    Gettext.gettext("The model contains alias variables with conflicting start and/or nominal values. It is recommended to resolve the conflicts, because otherwise the system could be hard to solve. To print the conflicting alias sets and the chosen candidates please use -d=aliasConflicts."),
  )::ErrorTypes.Message

const ENCRYPTION_NOT_SUPPORTED =
  ErrorTypes.MESSAGE(
    7018,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("File not Found: %s. Compile OpenModelica with Encryption support."),
  )::ErrorTypes.Message

const PACKAGE_FILE_NOT_FOUND_ERROR =
  ErrorTypes.MESSAGE(
    7019,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unable to find the package definition file. Looked for \\%s\\, \\%s\\, \\%s\\, \\%s\\, \\%s\\, \\%s\\, \\%s\\ and \\%s\\."),
  )::ErrorTypes.Message

const UNABLE_TO_UNZIP_FILE =
  ErrorTypes.MESSAGE(
    7020,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Unable to unzip the file: %s."),
  )::ErrorTypes.Message

const EXPECTED_ENCRYPTED_PACKAGE =
  ErrorTypes.MESSAGE(
    7021,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Expected encrypted package with .mol extension got: %s."),
  )::ErrorTypes.Message

const SAVE_ENCRYPTED_CLASS_ERROR =
  ErrorTypes.MESSAGE(
    7022,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot save the encrypted class. Encrypted classes are read-only."),
  )::ErrorTypes.Message

const ACCESS_ENCRYPTED_PROTECTED_CONTENTS =
  ErrorTypes.MESSAGE(
    7023,
    ErrorTypes.SCRIPTING(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Cannot access encrypted and protected class contents."),
  )::ErrorTypes.Message

const INVALID_NONLINEAR_JACOBIAN_COMPONENT =
  ErrorTypes.MESSAGE(
    7024,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Jacobian %s contains non-linear components. This indicates a singular system or internal generation errors."),
  )::ErrorTypes.Message

const DUPLICATE_VARIABLE_ERROR =
  ErrorTypes.MESSAGE(
    7025,
    ErrorTypes.TRANSLATION(),
    ErrorTypes.ERROR(),
    Gettext.gettext("Duplicate elements:\\n %s."),
  )::ErrorTypes.Message



const dummyInfo = SOURCEINFO("", false, 0, 0, 0, 0, 0.0)::SourceInfo

function clearCurrentComponent()
  function dummy(str::String, i::Integer)::String

    return str
  end

  return updateCurrentComponent(0, "", dummyInfo, dummy)
end

"""
  Function: updateCurrentComponent
  This function takes a String and set the global var to
  which the current variable the compiler is working with.
"""
function updateCurrentComponent(
  cpre::T,
  component::String,
  info::SourceInfo,
  func::prefixToStr,
) where {T}
  local tpl::Option{Tuple{Array{T}, Array{String}, Array{SourceInfo}, Array{prefixToStr}}}
  local apre::Array{T}
  local astr::Array{String}
  local ainfo::Array{SourceInfo}
  local afunc::Array{prefixToStr}
  @assign tpl = getGlobalRoot(Global.currentInstVar)
  @match tpl begin
    NONE() => begin
      setGlobalRoot(
        Global.currentInstVar,
        SOME((
          arrayCreate(1, cpre),
          arrayCreate(1, component),
          arrayCreate(1, info),
          arrayCreate(1, func),
        )),
      )
      ()
    end

    SOME((apre, astr, ainfo, afunc)) => begin
      arrayUpdate(apre, 1, cpre)
      arrayUpdate(astr, 1, component)
      arrayUpdate(ainfo, 1, info)
      arrayUpdate(afunc, 1, func)
      ()
    end
  end
end

"""Gets the current component as a string."""
function getCurrentComponent()
  local filename::String = ""
  local read_only::Bool = false
  local sline::Integer = 0
  local scol::Integer = 0
  local eline::Integer = 0
  local ecol::Integer = 0
  local str::String

  local tpl::Option{Tuple{Array{T}, Array{String}, Array{SourceInfo}, Array{prefixToStr}}}
  local apre::Array{T}
  local astr::Array{String}
  local ainfo::Array{SourceInfo}
  local afunc::Array{prefixToStr}
  local info::SourceInfo
  local func::prefixToStr

  @assign tpl = getGlobalRoot(Global.currentInstVar)
  @assign str = begin
    @match tpl begin
      NONE() => begin
        ""
      end

      SOME((apre, astr, ainfo, afunc)) => begin
        @assign str = arrayGet(astr, 1)
        if str != ""
          @assign func = arrayGet(afunc, 1)
          @assign str = "Variable " + func(str, arrayGet(apre, 1)) + ": "
          @assign info = arrayGet(ainfo, 1)
          @assign sline = info.lineNumberStart
          @assign scol = info.columnNumberStart
          @assign eline = info.lineNumberEnd
          @assign ecol = info.columnNumberEnd
          @assign read_only = info.isReadOnly
          @assign filename = info.fileName
        end
        str
      end
    end
  end
  return (str, sline, scol, eline, ecol, read_only, filename)
end

"""
 Implementation of Relations
  function: addMessage
  Adds a message given ID and tokens. The rest of the info
  is looked up in the message table. """
function addMessage(
  inErrorMsg::ErrorTypes.Message,
  inMessageTokens::ErrorTypes.MessageTokens,
  )
end

"""
  Adds a message given ID, tokens and source file info.
  The rest of the info is looked up in the message table.
"""
function addSourceMessage(
  inErrorMsg::ErrorTypes.Message,
  inMessageTokens::ErrorTypes.MessageTokens,
  inInfo::SourceInfo,
)
  ErrorExt.pushSourceMessage!([inErrorMsg, inMessageTokens, inInfo])
end

function addSourceMessageAsError(
  msg::ErrorTypes.Message,
  tokens::ErrorTypes.MessageTokens,
  info::SourceInfo,
)
end

function addStrictMessage(
  errorMsg::ErrorTypes.Message,
  tokens::ErrorTypes.MessageTokens,
  info::SourceInfo,
)
end

"""Same as addSourceMessage, but fails after adding the error."""
function addSourceMessageAndFail(
  inErrorMsg::ErrorTypes.Message,
  inMessageTokens::ErrorTypes.MessageTokens,
  inInfo::SourceInfo,
)
  addSourceMessage(inErrorMsg, inMessageTokens, inInfo)
  return fail()
end

"""
  Adds an error message given the message, token and a list of file info. The
  the last file info in the list is used for the message itself, the rest of the
  file infos are used to print a trace of where the error came from.
"""
function addMultiSourceMessage(inErrorMsg::ErrorTypes.Message,
                               inMessageTokens::ErrorTypes.MessageTokens,
                               inInfo::List{<:SourceInfo})
  _ = begin
    local info::SourceInfo
    local rest_info::List{SourceInfo}
    #=  Only one info left, print out the message. =#
    @match (inErrorMsg, inMessageTokens, inInfo) begin
      (_, _, info <| nil()) => begin
        addSourceMessage(inErrorMsg, inMessageTokens, info)
        ()
      end

      (_, _, info <| rest_info) => begin
        if !listMember(info, rest_info)
          addSourceMessage(ERROR_FROM_HERE, nil, info)
        end
        addMultiSourceMessage(inErrorMsg, inMessageTokens, rest_info)
        ()
      end

      (_, _, nil()) => begin
        addMessage(inErrorMsg, inMessageTokens)
        ()
      end
    end
  end
  #=  No infos given, print a sourceless error. =#
end

"""
  @author:adrpo
  Adds a message or a source message depending on the OPTIONAL source file info.
  If the source file info is not present a normal message is added.
  If the source file info is present a source message is added
"""
function addMessageOrSourceMessage(
  inErrorMsg::ErrorTypes.Message,
  inMessageTokens::ErrorTypes.MessageTokens,
  inInfoOpt::Option{<:SourceInfo},
)
  begin
    local info::SourceInfo
    #=  we DON'T have an info, add message
    =#
    @match (inErrorMsg, inMessageTokens, inInfoOpt) begin
      (_, _, NONE()) => begin
        addMessage(inErrorMsg, inMessageTokens)
        ()
      end

      (_, _, SOME(info)) => begin
        addSourceMessage(inErrorMsg, inMessageTokens, info)
        ()
      end
    end
  end
  #=  we have an info, add source message =#
end

function addTotalMessage(message::ErrorTypes.TotalMessage)
  local msg::ErrorTypes.Message
  local info::SourceInfo

  @match ErrorTypes.TOTALMESSAGE(msg = msg, info = info) = message
  return addSourceMessage(msg, nil, info)
end

function addTotalMessages(messages::List{<:ErrorTypes.TotalMessage})
  return for msg in messages
    addTotalMessage(msg)
  end
end

"""
Relations for pretty printing.
function: printMessagesStr
Prints messages to a string.
"""
function printMessagesStr(warningsAsErrors::Bool = false; printErrors = true)::String
  local res::String
  res = ErrorExt.printMessagesStr(warningsAsErrors = warningsAsErrors; printErrors = printErrors)
  return res
end

"""Prints errors only to a string."""
function printErrorsNoWarning()::String
  local res::String

  @assign res = ErrorExt.printErrorsNoWarning()
  return res
end

"""Returns all messages as a list of strings, one for each message."""
function printMessagesStrLst()::List{String}
  local outStringLst::List{String}

  @assign outStringLst = begin
    @match () begin
      () => begin
        list("Not impl. yet")
      end
    end
  end
  return outStringLst
end

"""
  Returns all messages as a list of strings, one for each message.
  Filters out messages of certain type.
"""
function printMessagesStrLstType(inMessageType::ErrorTypes.MessageType)::List{String}
  local outStringLst::List{String}

  @assign outStringLst = begin
    @match inMessageType begin
      _ => begin
        list("Not impl. yet")
      end
    end
  end
  return outStringLst
end

"""
  Returns all messages as a list of strings, one for each message.
  Filters out messages of certain severity
"""
function printMessagesStrLstSeverity(inSeverity::ErrorTypes.Severity)::List{String}
  local outStringLst::List{String}

  @assign outStringLst = begin
    @match inSeverity begin
      _ => begin
        list("Not impl. yet")
      end
    end
  end
  return outStringLst
end

"""clears the message buffer"""
function clearMessages()
  ErrorExt.clearMessages()
end

"""Returns the number of messages in the message queue"""
function getNumMessages()::Integer
  local num::Integer

  @assign num = ErrorExt.getNumMessages()
  return num
end

"""Returns the number of messages with severity 'Error' in the message queue"""
function getNumErrorMessages()::Integer
  local num::Integer
  num = ErrorExt.getNumErrorMessages()
  return num
end

"""
  Relations for interactive comm. These returns the messages as an array
  of strings, suitable for sending to clients like model editor, MDT, etc.

  Return all messages in a matrix format, vector of strings for each
  message, written out as a string.
"""
function getMessages()::List{ErrorTypes.TotalMessage}
  local res::List{ErrorTypes.TotalMessage}
  @assign res = ErrorExt.getMessages()
  return res
end

"""
  Return all messages in a matrix format, vector of strings for each
  message, written out as a string.
  Filtered by a specific MessageType.
"""
function getMessagesStrType(inMessageType::ErrorTypes.MessageType)::String
  local outString::String

  @assign outString = "not impl yet."
  return outString
end

"""
  Return all messages in a matrix format, vector of strings for each
  message, written out as a string.
  Filtered by a specific MessageType.
"""
function getMessagesStrSeverity(inSeverity::ErrorTypes.Severity)::String
  local outString::String
  @assign outString = "not impl yet."
  return outString
end


"""
  Used to make compiler-internal assertions. These messages are not meant
  to be shown to a user, but rather to show internal error messages.
"""
function assertion(b::Bool, message::String, info::SourceInfo)
  @match (b, message, info) begin
    (true, _, _) => begin
      ()
    end
    _ => begin
      addSourceMessage(INTERNAL_ERROR, list(message), info)
      fail()
    end
  end
end

"""
  Used to make assertions. These messages are meant to be shown to a user when
  the condition is true. If the Error-level of the message is Error, this function
  fails.
"""
function assertionOrAddSourceMessage(
  inCond::Bool,
  inErrorMsg::ErrorTypes.Message,
  inMessageTokens::ErrorTypes.MessageTokens,
  inInfo::SourceInfo,
  )
  @match (inCond, inErrorMsg, inMessageTokens, inInfo) begin
    (true, _, _, _) => begin
      ()
    end

    _ => begin
      addSourceMessage(inErrorMsg, inMessageTokens, inInfo)
      failOnErrorMsg(inErrorMsg)
      ()
    end
  end
end

function failOnErrorMsg(inMessage::ErrorTypes.Message)
  return @assign _ = begin
    @match inMessage begin
      ErrorTypes.MESSAGE(severity = ErrorTypes.ERROR(__)) => begin
        fail()
      end

      _ => begin
        ()
      end
    end
  end
end

"""Used to make a compiler warning"""
function addCompilerError(message::String)
  return addMessage(COMPILER_ERROR, list(message))
end

"""Used to make a compiler warning"""
function addCompilerWarning(message::String)
  return addMessage(COMPILER_WARNING, list(message))
end

"""Used to make a compiler notification"""
function addCompilerNotification(message::String)
  return addMessage(COMPILER_NOTIFICATION, list(message))
end

"""
  Used to make an internal error
"""
function addInternalError(message::String, info::SourceInfo)
  local filename::String

  # return if Testsuite.isRunning()
  #   @match SOURCEINFO(fileName = filename) = info
  #   addSourceMessage(
  #     INTERNAL_ERROR,
  #     list(message),
  #     SOURCEINFO(filename, false, 0, 0, 0, 0, 0),
  #   )
  # else
  addSourceMessage(INTERNAL_ERROR, list(message), info)
#  end
end


"""
Prints out a message and terminates the execution.
"""
function terminateError(message::String, info::SourceInfo)
  # ErrorExt.addSourceMessage(
  #   0,
  #   ErrorTypes.TRANSLATION(),
  #   ErrorTypes.INTERNAL(),
  #   info.lineNumberStart,
  #   info.columnNumberStart,
  #   info.lineNumberEnd,
  #   info.columnNumberEnd,
  #   info.isReadOnly,
  #   info.fileName,
  #   "%s",
  #   list(message),
  # )
  print(ErrorExt.printMessagesStr())
  return System.exit(-1)
end

@exportAll()
end
