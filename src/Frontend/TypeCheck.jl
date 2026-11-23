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

struct MatchKindStruct{T <: Number}
  EXACT::T #= Exact match =#
  CAST::T #= Matched by casting, e.g. Integer to Real =#
  UNKNOWN_EXPECTED::T #= The expected type was unknown =#
  UNKNOWN_ACTUAL::T #= The actual type was unknown =#
  GENERIC::T #= Matched with a generic type e.g. function F<T> input T i; end F; F(1) =#
  PLUG_COMPATIBLE::T  #= Component by component matching, e.g. class A R r; end A; is plug compatible with class B R r; end B; =#
  NOT_COMPATIBLE::T
end

const MatchKind::MatchKindStruct{Int} = MatchKindStruct(1,2,3,4,5,6,7)
const MatchKindType = Int

function isCompatibleMatch(kind::MatchKindType)::Bool
  local isCompatible::Bool = kind != MatchKind.NOT_COMPATIBLE
  return isCompatible
end

function isIncompatibleMatch(kind::MatchKindType)::Bool
  local isIncompatible::Bool = kind == MatchKind.NOT_COMPATIBLE
  return isIncompatible
end

function isCastMatch(kind::MatchKindType)::Bool
  local isCast::Bool = kind == MatchKind.CAST
  return isCast
end

function isGenericMatch(kind::MatchKindType)::Bool
  local isCast::Bool = kind == MatchKind.GENERIC
  return isCast
end

function isValidAssignmentMatch(kind::MatchKindType)::Bool
  local v::Bool =
    kind == MatchKind.EXACT || kind == MatchKind.CAST || kind == MatchKind.PLUG_COMPATIBLE
  return v
end

function isValidArgumentMatch(kind::MatchKindType)::Bool
  local v::Bool =
    kind == MatchKind.EXACT ||
    kind == MatchKind.CAST ||
    kind == MatchKind.GENERIC ||
    kind == MatchKind.PLUG_COMPATIBLE
  return v
end

function isValidPlugCompatibleMatch(kind::MatchKindType)::Bool
  local v::Bool = kind == MatchKind.EXACT || kind == MatchKind.PLUG_COMPATIBLE
  return v
end

function checkBinaryOperation(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  operator::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  if isComplex(arrayElementType(type1)) ||
     isComplex(arrayElementType(type2))
     (binaryExp, resultType) =
      checkOverloadedBinaryOperator(exp1, type1, var1, operator, exp2, type2, var2, info)
  elseif isBoxed(type1) && isBoxed(type2)
     (binaryExp, resultType) =
      checkBinaryOperationBoxed(exp1, type1, var1, operator, exp2, type2, var2, info)
  else
     (binaryExp, resultType) = begin
       @match operator.op begin
         Op.ADD => checkBinaryOperationAdd(exp1, type1, exp2, type2, info)
         Op.SUB => checkBinaryOperationSub(exp1, type1, exp2, type2, info)
         Op.MUL => checkBinaryOperationMul(exp1, type1, exp2, type2, info)
         Op.DIV => checkBinaryOperationDiv(exp1, type1, exp2, type2, info, false)
         Op.POW => checkBinaryOperationPow(exp1, type1, exp2, type2, info)
         Op.ADD_EW => checkBinaryOperationEW(exp1, type1, exp2, type2, Op.ADD, info)
         Op.SUB_EW => checkBinaryOperationEW(exp1, type1, exp2, type2, Op.SUB, info)
         Op.MUL_EW => checkBinaryOperationEW(exp1, type1, exp2, type2, Op.MUL, info)
         Op.DIV_EW => checkBinaryOperationDiv(exp1, type1, exp2, type2, info, true)
         Op.POW_EW => checkBinaryOperationPowEW(exp1, type1, exp2, type2, info)
         #= Typed operators: an already typed expression is typed again after its operands
            changed (size() of a function argument during evaluation; omc checkBinaryOperation). =#
         Op.ADD_SCALAR_ARRAY || Op.ADD_ARRAY_SCALAR => checkBinaryOperationEW(exp1, type1, exp2, type2, Op.ADD, info)
         Op.SUB_SCALAR_ARRAY || Op.SUB_ARRAY_SCALAR => checkBinaryOperationEW(exp1, type1, exp2, type2, Op.SUB, info)
         Op.MUL_SCALAR_ARRAY || Op.MUL_ARRAY_SCALAR || Op.MUL_VECTOR_MATRIX || Op.MUL_MATRIX_VECTOR ||
         Op.SCALAR_PRODUCT || Op.MATRIX_PRODUCT => checkBinaryOperationMul(exp1, type1, exp2, type2, info)
         Op.DIV_SCALAR_ARRAY || Op.DIV_ARRAY_SCALAR => checkBinaryOperationDiv(exp1, type1, exp2, type2, info, true)
         Op.POW_SCALAR_ARRAY || Op.POW_ARRAY_SCALAR => checkBinaryOperationPowEW(exp1, type1, exp2, type2, info)
         Op.POW_MATRIX => checkBinaryOperationPow(exp1, type1, exp2, type2, info)
         _ =>  begin
           Error.addInternalError("checkBinaryOperation got operator " + symbol(operator), info)
           fail()
         end
       end
     end
  end
  return (binaryExp, resultType)
end

function checkOverloadedBinaryOperator(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local op_str::String
  local candidates::Vector{MODELICA_FUNCTION}
  local ety1::ModelicaType
  local ety2::ModelicaType

  op_str = symbol(stripEW(op), "'")
  ety1 = arrayElementType(type1)
  ety2 = arrayElementType(type2)
  candidates = lookupOperatorFunctionsInType(op_str, ety1)
  #= Only collect operators from both types if they're not the same type. =#
  if !isEqual(ety1, ety2)
    candidates = Base.append!(
      lookupOperatorFunctionsInType(op_str, ety2),
      candidates,
    )
  end
  #=  Give up if no operator functions could be found. =#
  if isempty(candidates)
    printUnresolvableTypeError(
      BINARY_EXPRESSION(exp1, op, exp2),
      list(type1, type2),
      info,
    )
  end
  if isElementWise(op)
     (outExp, outType) = checkOverloadedBinaryArrayEW(
      exp1,
      type1,
      var1,
      stripEW(op),
      exp2,
      type2,
      var2,
      candidates,
      info,
    )
  else
     (outExp, outType) = matchOverloadedBinaryOperator(
      exp1,
      type1,
      var1,
      op,
      exp2,
      type2,
      var2,
      candidates,
      info,
    )
  end
  return (outExp, outType)
end

function matchOverloadedBinaryOperator(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
  showErrors::Bool = true,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local args::Vector{TypedArg}
  local matchedFunc::MatchedFunction
  local matchedFunctions::Vector{MatchedFunction}
  local exactMatches::Vector{MatchedFunction}
  local fn::MODELICA_FUNCTION

  args = TypedArg[(exp1, type1, var1), (exp2, type2, var2)]
  matchedFunctions = matchFunctionsSilent(candidates, args, TypedNamedArg[], info)
  #= We only allow exact matches for operator overloading. e.g. no casting or generic matches. =#
  exactMatches = getExactMatches(matchedFunctions)
  if isempty(exactMatches)
    ErrorExt.setCheckpoint("NFTypeCheck:implicitConstruction")
    try
       (outExp, outType) =
        implicitConstructAndMatch(candidates, exp1, type1, op, exp2, type2, info)
      if showErrors
        ErrorExt.delCheckpoint("NFTypeCheck:implicitConstruction")
      else
        ErrorExt.rollBack("NFTypeCheck:implicitConstruction")
      end
    catch
      ErrorExt.rollBack("NFTypeCheck:implicitConstruction")
      if isArray(type1) || isArray(type2)
         (outExp, outType) = begin
          @match op.op begin
            Op.ADD => begin
              checkOverloadedBinaryArrayAddSub(
                exp1,
                type1,
                var1,
                op,
                exp2,
                type2,
                var2,
                candidates,
                info,
              )
            end

            Op.SUB => begin
              checkOverloadedBinaryArrayAddSub(
                exp1,
                type1,
                var1,
                op,
                exp2,
                type2,
                var2,
                candidates,
                info,
              )
            end

            Op.MUL => begin
              checkOverloadedBinaryArrayMul(
                exp1,
                type1,
                var1,
                op,
                exp2,
                type2,
                var2,
                candidates,
                info,
              )
            end

            Op.DIV => begin
              checkOverloadedBinaryArrayDiv(
                exp1,
                type1,
                var1,
                op,
                exp2,
                type2,
                var2,
                candidates,
                info,
              )
            end

            _ => begin
              #= TODO: new error mentioning overloaded operators. =#
              printUnresolvableTypeError(
                BINARY_EXPRESSION(exp1, op, exp2),
                list(type1, type2),
                info,
                showErrors,
              )
              fail()
            end
          end
        end
      else
        printUnresolvableTypeError(
          BINARY_EXPRESSION(exp1, op, exp2),
          list(type1, type2),
          info,
          showErrors,
        )
      end
    end
  elseif length(exactMatches) == 1
    @match [matchedFunc, aux...] = exactMatches
    fn = matchedFunc.func
    outType = returnType(fn)
    outExp = CALL_EXPRESSION(makeTypedCall(
      matchedFunc.func,
      Expression[Util.tuple31(a) for a in matchedFunc.args],
      variabilityMax(var1, var2),
      outType,
    ))
  else
    if showErrors
      Error.addSourceMessage(
        Error.AMBIGUOUS_MATCHING_OPERATOR_FUNCTIONS_NFINST,
        list(
          toString(BINARY_EXPRESSION(exp1, op, exp2)),
          candidateFuncListString(list(mfn.func for mfn in matchedFunctions)),
        ),
        info,
      )
    end
    fail()
  end
  return (outExp, outType)
end

function checkBinaryOperationBoxed(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType

   (e1, ty1) = matchTypes(type1, unbox(type1), exp1)
   (e2, ty2) = matchTypes(type2, unbox(type2), exp2)
   (outExp, outType) = checkBinaryOperation(e1, ty1, var1, op, e2, ty2, var2, info)
  return (outExp, outType)
end

function checkOverloadedBinaryArrayAddSub(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType

  #= For addition or subtraction both sides must have the same type. =#
   (e1, e2, _, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  if !isCompatibleMatch(mk)
    printUnresolvableTypeError(
      BINARY_EXPRESSION(e1, op, e2),
      list(type1, type2),
      info,
    )
  end
  (e1, _) = expand(e1)
  (e2, _) = expand(e2)
   (outExp, outType) = checkOverloadedBinaryArrayAddSub2(
    e1,
    type1,
    var1,
    op,
    e2,
    type2,
    var2,
    candidates,
    info,
  )
  return (outExp, outType)
end

function checkOverloadedBinaryArrayAddSub2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

   (outExp, outType) = begin
    local ty::ModelicaType
    local ty1::ModelicaType
    local ty2::ModelicaType
    local e::Expression
    local e2::Expression
    local expl::Vector{Expression}
    local expl1::Vector{Expression}
    local expl2::Vector{Expression}
    @match (exp1, exp2) begin
      (
        ARRAY_EXPRESSION(elements = expl1),
        ARRAY_EXPRESSION(elements = expl2),
      ) => begin
        expl = Expression[]
        if isempty(expl1)
          ty1 = arrayElementType(type1)
          ty2 = arrayElementType(type2)
          try
             (_, ty) = matchOverloadedBinaryOperator(
              EMPTY_EXPRESSION(ty1),
              ty1,
              var1,
              op,
              EMPTY_EXPRESSION(ty2),
              ty2,
              var2,
              candidates,
              info,
              false, #= showErrors =#
            )
          catch
            printUnresolvableTypeError(
              BINARY_EXPRESSION(exp1, op, exp2),
              list(type1, type2),
              info,
            )
          end
        else
          ty1 = unliftArray(type1)
          ty2 = unliftArray(type2)
          for (idx, e1) in enumerate(expl1)
            e2 = expl2[idx]
             (e, ty) = checkOverloadedBinaryArrayAddSub2(
              e1,
              ty1,
              var1,
              op,
              e2,
              ty2,
              var2,
              candidates,
              info,
            )
            push!(expl, e)
          end
        end
        #= If the arrays are empty, match against the element types to get the expected return type. =#
        outType = setArrayElementType(type1, ty)
        outExp = makeArray(outType, expl)
        (outExp, outType)
      end

      _ => begin
        matchOverloadedBinaryOperator(
          exp1,
          type1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
      end
    end
  end
  return (outExp, outType)
end

function checkOverloadedBinaryArrayMul(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local valid::Bool
  local dims1::List{Dimension}
  local dims2::List{Dimension}
  local dim12::Dimension
  local dim21::Dimension

  dims1 = arrayDims(type1)
  dims2 = arrayDims(type2)
   (valid, outExp) = begin
    @match (dims1, dims2) begin
      (nil(), _ <| nil()) => begin
        #= scalar * array = array =#
        (outExp, _) = checkOverloadedBinaryScalarArray(
          exp1,
          type1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
        (true, outExp)
      end

      (_ <| nil(), nil()) => begin
        #= array * scalar = array =#
        (outExp, _) = checkOverloadedBinaryArrayScalar(
          exp1,
          type1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
        (true, outExp)
      end

      (dim11 <| dim12 <| nil(), dim21 <| nil()) => begin
        #= matrix[n, m] * vector[m] = vector[n] =#
        valid = isEqual(dim12, dim21)
        #= TODO: Implement me! =#
        outExp = BINARY_EXPRESSION(exp1, op, exp2)
        valid = false
        (valid, outExp)
      end

      (dim11 <| dim12 <| nil(), dim21 <| dim22 <| nil()) => begin
        #= matrix[n, m] * matrix[m, p] = vector[n, p] =#
        valid = isEqual(dim12, dim21)
        #= TODO: Implement me! =#
        outExp = BINARY_EXPRESSION(exp1, op, exp2)
        valid = false
        (valid, outExp)
      end

      _ => (false, BINARY_EXPRESSION(exp1, op, exp2))
    end
  end
  #= scalar * scalar should never get here.
     vector * vector and vector * matrix are undefined for overloaded operators. =#
  if !valid
    printUnresolvableTypeError(outExp, list(type1, type2), info)
  end
  outType = typeOf(outExp)
  return (outExp, outType)
end

function checkOverloadedBinaryScalarArray(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

   (exp2_expanded, _) = expand(exp2)
   (outExp, outType) = checkOverloadedBinaryScalarArray2(
    exp1,
    type1,
    var1,
    op,
    exp2_expanded,
    type2,
    var2,
    candidates,
    info,
  )
  return (outExp, outType)
end

function checkOverloadedBinaryScalarArray2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local expl::Vector{Expression}
  local ty::ModelicaType

   (outExp, outType) = begin
    @match exp2 begin
      ARRAY_EXPRESSION(elements = expl) where isempty(expl) => begin
        try
          ty = unliftArray(type2)
           (_, outType) = matchOverloadedBinaryOperator(
            exp1,
            type1,
            var1,
            op,
            EMPTY_EXPRESSION(type2),
            ty,
            var2,
            candidates,
            info,
            false, #= showErrors =#
          )
        catch
          printUnresolvableTypeError(
            BINARY_EXPRESSION(exp1, op, exp2),
            list(type1, exp2.ty),
            info,
          )
        end
        outType = setArrayElementType(exp2.ty, outType)
        (makeArray(outType, Expression[]), outType)
      end

      ARRAY_EXPRESSION(elements = expl) => begin
        ty = unliftArray(type2)
        expl = Expression[
          checkOverloadedBinaryScalarArray2(
            exp1,
            type1,
            var1,
            op,
            e,
            ty,
            var2,
            candidates,
            info,
          )[1] for e in expl
        ]
        outType = setArrayElementType(
          exp2.ty,
          typeOf(expl[1]),
        )
        (makeArray(outType, expl), outType)
      end

      _ => begin
        matchOverloadedBinaryOperator(
          exp1,
          type1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
      end
    end
  end
  return (outExp, outType)
end

function checkOverloadedBinaryArrayScalar(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

   (exp1_expanded, _) = expand(exp1)
   (outExp, outType) = checkOverloadedBinaryArrayScalar2(
    exp1_expanded,
    type1,
    var1,
    op,
    exp2,
    type2,
    var2,
    candidates,
    info,
  )
  return (outExp, outType)
end

function checkOverloadedBinaryArrayScalar2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local expl::Vector{Expression}
  local ty::ModelicaType

   (outExp, outType) = begin
    @match exp1 begin
      ARRAY_EXPRESSION(elements = expl) where isempty(expl) => begin
        try
          ty = unliftArray(type1)
           (_, outType) = matchOverloadedBinaryOperator(
            EMPTY_EXPRESSION(type1),
            ty,
            var1,
            op,
            exp2,
            type2,
            var2,
            candidates,
            info,
            false, #= showErrors =#
          )
        catch
          printUnresolvableTypeError(
            BINARY_EXPRESSION(exp1, op, exp2),
            list(type1, exp1.ty),
            info,
          )
        end
        outType = setArrayElementType(exp1.ty, outType)
        (makeArray(outType, Expression[]), outType)
      end

      ARRAY_EXPRESSION(elements = expl) => begin
        ty = unliftArray(type1)
        expl = Expression[
          checkOverloadedBinaryArrayScalar2(
            e,
            ty,
            var1,
            op,
            exp2,
            type2,
            var2,
            candidates,
            info,
          )[1] for e in expl
        ]
        outType = setArrayElementType(
          exp1.ty,
          typeOf(expl[1]),
        )
        (makeArray(outType, expl), outType)
      end

      _ => begin
        matchOverloadedBinaryOperator(
          exp1,
          type1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
      end
    end
  end
  return (outExp, outType)
end

function checkOverloadedBinaryArrayDiv(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  if isArray(type1) && isScalar(type2)
     (outExp, outType) = checkOverloadedBinaryArrayScalar(
      exp1,
      type1,
      var1,
      op,
      exp2,
      type2,
      var2,
      candidates,
      info,
    )
  else
    printUnresolvableTypeError(
      BINARY_EXPRESSION(exp1, op, exp2),
      list(type1, type2),
      info,
    )
  end
  return (outExp, outType)
end

function checkOverloadedBinaryArrayEW(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType

  if isArray(type1) && isArray(type2)
     (e1, e2, _, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  else
     (e1, e2, _, mk) = matchExpressions(
      exp1,
      arrayElementType(type1),
      exp2,
      arrayElementType(type2),
      true,
    )
  end
  if !isCompatibleMatch(mk)
    printUnresolvableTypeError(
      BINARY_EXPRESSION(e1, op, e2),
      list(type1, type2),
      info,
    )
  end
  (e1, _) = expand(exp1)
  (e2, _) = expand(exp2)
   (outExp, outType) =
    checkOverloadedBinaryArrayEW2(e1, type1, var1, op, e2, type2, var2, candidates, info)
  return (outExp, outType)
end

function checkOverloadedBinaryArrayEW2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  op::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  candidates::Vector{MODELICA_FUNCTION},
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local e2::Expression
  local expl::Vector{Expression}
  local expl1::Vector{Expression}
  local expl2::Vector{Expression}
  local ty::ModelicaType
  local ty1::ModelicaType
  local ty2::ModelicaType
  local is_array1::Bool
  local is_array2::Bool

  is_array1 = isArray(type1)
  is_array2 = isArray(type2)
  if is_array1 || is_array2
    expl = Expression[]
    if isEmptyArray(exp1) ||
       isEmptyArray(exp2)
      ty1 = arrayElementType(type1)
      ty2 = arrayElementType(type2)
      try
         (_, ty) = matchOverloadedBinaryOperator(
          EMPTY_EXPRESSION(ty1),
          ty1,
          var1,
          op,
          EMPTY_EXPRESSION(ty2),
          ty2,
          var2,
          candidates,
          info,
        )
      catch
        printUnresolvableTypeError(
          BINARY_EXPRESSION(exp1, op, exp2),
          list(type1, type2),
          info,
        )
      end
    elseif is_array1 && is_array2
      ty1 = unliftArray(type1)
      ty2 = unliftArray(type2)
      expl1 = arrayElements(exp1)
      expl2 = arrayElements(exp2)
      for (idx, e) in enumerate(expl1)
        e2 = expl2[idx]
         (e, ty) =
          checkOverloadedBinaryArrayEW2(e, ty1, var1, op, e2, ty2, var2, candidates, info)
        push!(expl, e)
      end
    elseif is_array1
      ty1 = unliftArray(type1)
      expl1 = arrayElements(exp1)
      for e in expl1
         (e, ty) = checkOverloadedBinaryArrayEW2(
          e,
          ty1,
          var1,
          op,
          exp2,
          type2,
          var2,
          candidates,
          info,
        )
        push!(expl, e)
      end
    elseif is_array2
      ty2 = unliftArray(type2)
      expl2 = arrayElements(exp2)
      for e in expl2
         (e, ty) = checkOverloadedBinaryArrayEW2(
          exp1,
          type1,
          var1,
          op,
          e,
          ty2,
          var2,
          candidates,
          info,
        )
        push!(expl, e)
      end
    end
    outType = setArrayElementType(type1, ty)
    outExp = makeArray(outType, expl)
  else
     (outExp, outType) = matchOverloadedBinaryOperator(
      exp1,
      type1,
      var1,
      op,
      exp2,
      type2,
      var2,
      candidates,
      info,
    )
  end
  return (outExp, outType)
end

function implicitConstructAndMatch(
  candidates::Vector{MODELICA_FUNCTION},
  @nospecialize(inExp1::Expression),
  inType1::ModelicaType,
  op::OPERATOR,
  @nospecialize(inExp2::Expression),
  inType2::ModelicaType,
  info::SourceInfo,
  )::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local in1::InstNode
  local in2::InstNode
  local operfn::MODELICA_FUNCTION
  local matchedfuncs::List{Tuple{MODELICA_FUNCTION, List{Expression}, VariabilityType}} = nil
  local exp1::Expression
  local exp2::Expression
  local arg1_ty::ModelicaType
  local arg2_ty::ModelicaType
  local var::VariabilityType
  local matched::Bool
  local arg1_info::SourceInfo
  local arg2_info::SourceInfo

  exp1 = inExp1
  exp2 = inExp2
  for fn in candidates
    if listLength(fn.inputs) != 2
      continue
    end
    @match _cons(in1, _cons(in2, _)) = fn.inputs
    arg1_ty = getType(in1)
    arg2_ty = getType(in2)
    arg1_info = InstNode_info(in1)
    arg2_info = InstNode_info(in2)
     (matchedfuncs, matched) = implicitConstructAndMatch2(
      inExp1,
      inType1,
      inExp2,
      arg1_ty,
      arg1_info,
      arg2_ty,
      arg2_info,
      classScope(in2),
      fn,
      false,
      matchedfuncs,
    )
    if matched
      continue
    end
     (matchedfuncs, _) = implicitConstructAndMatch2(
      inExp2,
      inType2,
      inExp1,
      arg2_ty,
      arg2_info,
      arg1_ty,
      arg1_info,
      classScope(in1),
      fn,
      true,
      matchedfuncs,
    )
  end
  #= Try to implicitly construct a matching record from the first argument.
     Try to implicitly construct a matching record from the second argument. =#
  if listLength(matchedfuncs) == 1
    @match (operfn, exp1 <| (exp2 <| _), var) <| _ = matchedfuncs
    outType = returnType(operfn)
    outExp = CALL_EXPRESSION(makeTypedCall(
      operfn,
      Expression[exp1, exp2],
      var,
      outType,
    ))
  else
    Error.addSourceMessage(
      Error.AMBIGUOUS_MATCHING_OPERATOR_FUNCTIONS_NFINST,
      list(
        toString(BINARY_EXPRESSION(exp1, op, exp2)),
        candidateFuncListString(list(Util.tuple31(fn) for fn in matchedfuncs)),
      ),
      info,
    )
    fail()
  end
  return (outExp, outType)
end

function implicitConstructAndMatch2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  paramType1::ModelicaType,
  paramInfo1::SourceInfo,
  paramType2::ModelicaType,
  paramInfo2::SourceInfo,
  scope::InstNode,
  fn::MODELICA_FUNCTION,
  reverseArgs::Bool,
  matchedFns::List{<:Tuple{MODELICA_FUNCTION, List{<:Expression}, VariabilityType}},
)::Tuple{List{Tuple{MODELICA_FUNCTION, List{Expression}, VariabilityType}}, Bool}
  local matched::Bool

  local fn_ref::ComponentRef
  local e1::Expression
  local e2::Expression
  local mk::MatchKindType
  local var::VariabilityType
  local ty::ModelicaType

   (e1, _, mk) = matchTypes(paramType1, type1, exp1, false)
  #= We only want overloaded constructors when trying to implicitly construct.
     Default constructors are not considered. =#
  if mk == MatchKind.EXACT
    (fn_ref, _, _) =
      instFunction(Absyn.CREF_IDENT("'constructor'", nil), scope, paramInfo2)
    e2 =
      CALL_EXPRESSION(UNTYPED_CALL(fn_ref, list(exp2), nil, scope))
     (e2, ty, var) = typeCall(e2, 0, paramInfo1)
     (_, _, mk) = matchTypes(paramType2, ty, e2, false)
    if mk == MatchKind.EXACT
      matchedFns = Cons{Tuple{MODELICA_FUNCTION, List{Expression}, VariabilityType}}(
        (fn,
         if reverseArgs
           list(e2, e1)
         else
           list(e1, e2)
         end,
         var),
        matchedFns)
      #= Set matched to true =#
      matched = true
    else
      matched = false
    end
  else
    matched = false
  end
  return (matchedFns, matched)
end

function checkBinaryOperationAdd(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType
  local valid::Bool

   (e1, e2, resultType, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  valid = isCompatibleMatch(mk)
  valid = begin
    @match arrayElementType(resultType) begin
      TYPE_INTEGER(__) => valid

      TYPE_REAL(__) => valid

      TYPE_STRING(__) => valid

      _ => false
    end
  end
  binaryExp =
    BINARY_EXPRESSION(e1, makeAdd(resultType), e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkBinaryOperationSub(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType
  local valid::Bool

   (e1, e2, resultType, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  valid = isCompatibleMatch(mk)
  valid = begin
    @match arrayElementType(resultType) begin
      TYPE_INTEGER(__) => valid

      TYPE_REAL(__) => valid

      _ => false
    end
  end
  binaryExp =
    BINARY_EXPRESSION(e1, makeSub(resultType), e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

@nospecializeinfer function checkBinaryOperationMul(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  local e1::Expression
  local e2::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType
  local dims1::List{Dimension}
  local dims2::List{Dimension}
  local dim11::Dimension
  local dim12::Dimension
  local dim21::Dimension
  local dim22::Dimension
  local mk::MatchKindType
  local op::OpType
  local valid::Bool

  ty1 = arrayElementType(type1)
  ty2 = arrayElementType(type2)
  (e1, e2, resultType, mk) = matchExpressions(exp1, ty1, exp2, ty2, true)
  valid = isCompatibleMatch(mk)
  valid = begin
    @match resultType begin
      TYPE_INTEGER(__) => valid

      TYPE_REAL(__) => valid

      _ => false
    end
  end
  dims1 = arrayDims(type1)
  dims2 = arrayDims(type2)
  (resultType, op) = begin
    @match (dims1, dims2) begin
      (nil(), nil()) => (resultType, Op.MUL)

      (nil(), _) => (TYPE_ARRAY(resultType, dims2), Op.MUL_SCALAR_ARRAY)

      (_, nil()) => (TYPE_ARRAY(resultType, dims1), Op.MUL_ARRAY_SCALAR)

      (dim11 <| nil(), dim21 <| nil()) => begin
        #= scalar * scalar = scalar
           scalar * array = array
           array * scalar = array
           vector[n] * vector[n] = scalar =#
        valid = isEqual(dim11, dim21)
        (resultType, Op.SCALAR_PRODUCT)
      end

      (dim11 <| nil(), dim21 <| dim22 <| nil()) => begin
        #= vector[n] * matrix[n, m] = vector[m] =#
        valid = isEqual(dim11, dim21)
        (TYPE_ARRAY(resultType, list(dim22)), Op.MUL_VECTOR_MATRIX)
      end

      (dim11 <| dim12 <| nil(), dim21 <| nil()) => begin
        #= matrix[n, m] * vector[m] = vector[n] =#
        valid = isEqual(dim12, dim21)
        (TYPE_ARRAY(resultType, list(dim11)), Op.MUL_MATRIX_VECTOR)
      end

      (dim11 <| dim12 <| nil(), dim21 <| dim22 <| nil()) => begin
        #= matrix[n, m] * matrix[m, p] = vector[n, p] =#
        valid = isEqual(dim12, dim21)
        (TYPE_ARRAY(resultType, list(dim11, dim22)), Op.MATRIX_PRODUCT)
      end

      _ => begin
        valid = false
        (resultType, Op.MUL)
      end
    end
  end
  binaryExp =
    BINARY_EXPRESSION(e1, OPERATOR(resultType, op), e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkBinaryOperationDiv(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
  isElementWise::Bool,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression
  local e1::Expression
  local e2::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType
  local mk::MatchKindType
  local valid::Bool
  local op::OPERATOR
  (e1, ty1, mk) =
    matchTypes(type1, setArrayElementType(type1, TYPE_REAL()), exp1, #=allowUnknown=# true)
  valid = isCompatibleMatch(mk)
   (e2, ty2, mk) =
    matchTypes(type2, setArrayElementType(type2, TYPE_REAL()), exp2, #=allowUnknown=# true)
  valid = valid && isCompatibleMatch(mk)
  #= Division is always element-wise, the only difference between / and ./ is
     which operands they accept. =#
   (resultType, op) = begin
    @match (isArray(ty1), isArray(ty2), isElementWise) begin
      (false, false, _) => (ty1, makeDiv(ty1))

      (_, false, _) => (ty1, OPERATOR(ty1, Op.DIV_ARRAY_SCALAR))

      (false, _, true) => (ty2, OPERATOR(ty2, Op.DIV_SCALAR_ARRAY))

      (true, _, true) => begin
        #= array ./ array: both dimensions must be compatible. Op.DIV_EW, not Op.DIV with an array type (omc): a
           second typing of a DIV takes it as `/`, which does not accept two arrays. =#
         (_, _, mk) = matchArrayTypes(ty1, ty2, e1, true)
        valid = valid && isCompatibleMatch(mk)
        (ty1, OPERATOR(ty1, Op.DIV_EW))
      end

      _ => begin
        #= Anything else is an error. =#
        valid = false
        (ty1, makeDiv(ty1))
      end
    end
  end
  binaryExp = BINARY_EXPRESSION(e1, op, e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkBinaryOperationPow(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType
  local valid::Bool
  local op::OPERATOR

  #=  The first operand of ^ should be Real. =#
  (e1, resultType, mk) =
    matchTypes(type1, setArrayElementType(type1, TYPE_REAL()), exp1, #=allowUnknown=# true)
  valid = isCompatibleMatch(mk)
  if isArray(resultType)
    valid = valid && isSquareMatrix(resultType)
    valid = valid && isInteger(type2)
    op = OPERATOR(resultType, Op.POW_MATRIX)
    e2 = exp2
  else
    (e2, _, mk) = matchTypes(type2, TYPE_REAL(), exp2, #=allowUnknown=# true)
    valid = valid && isCompatibleMatch(mk)
    op = OPERATOR(resultType, Op.POW)
  end
  #= Real[n, n] ^ Integer
     Real ^ Real =#
  binaryExp = BINARY_EXPRESSION(e1, op, e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkBinaryOperationPowEW(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression

  local e1::Expression
  local e2::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType
  local mk::MatchKindType
  local valid::Bool
  local op::OPERATOR

  #= Exponentiation always returns a Real value, so instead of checking if the types
     are compatible with ecah other we check if each type is compatible with Real. =#
   (e1, ty1, mk) =
    matchTypes(type1, setArrayElementType(type1, TYPE_REAL()), exp1, #=allowUnknown=# true)
  valid = isCompatibleMatch(mk)
   (e2, ty2, mk) =
    matchTypes(type2, setArrayElementType(type2, TYPE_REAL()), exp2, #=allowUnknown=# true)
  valid = valid && isCompatibleMatch(mk)
   (resultType, op) = begin
    @match (isArray(ty1), isArray(ty2)) begin
      (false, false) => (ty1, makePow(ty1))

      (_, false) => (ty1, OPERATOR(ty1, Op.POW_ARRAY_SCALAR))

      (false, _) => (ty2, OPERATOR(ty2, Op.POW_SCALAR_ARRAY))

      _ => begin
        #= array .^ array: both dimensions must be compatible. Op.POW_EW, not Op.POW with an array type (omc): a
           second typing of a POW takes it as the matrix power `^` (omc's new backend fails on `x .^ y` so). =#
         (_, _, mk) = matchArrayTypes(ty1, ty2, e1, true)
        valid = valid && isCompatibleMatch(mk)
        (ty1, OPERATOR(ty1, Op.POW_EW))
      end
    end
  end
  binaryExp = BINARY_EXPRESSION(e1, op, e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkBinaryOperationEW(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  elemOp::OpType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local binaryExp::Expression
  local e1::Expression
  local e2::Expression
  local ty1::ModelicaType
  local ty2::ModelicaType
  local mk::MatchKindType
  local valid::Bool
  local is_arr1::Bool
  local is_arr2::Bool
  local op::OPERATOR
  is_arr1 = isArray(type1)
  is_arr2 = isArray(type2)
  if is_arr1 && is_arr2
    (e1, e2, resultType, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  else
    ty1 = arrayElementType(type1)
    ty2 = arrayElementType(type2)
    (e1, e2, resultType, mk) = matchExpressions(exp1, ty1, exp2, ty2, true)
  end
  #= The expressions must be type compatible if they are both arrays.
     Otherwise it's enough if their element types are compatible. =#
  valid = isCompatibleMatch(mk)
  #= Check that the type is valid for the operation. =#
  valid = begin
    @match (arrayElementType(resultType), elemOp) begin
      (TYPE_INTEGER(__), _) => valid

      (TYPE_REAL(__), _) => valid

      (TYPE_STRING(__), Op.ADD) => valid

      _ => false
    end
  end
  (resultType, op) = begin
    @match (is_arr1, is_arr2) begin
      (true, false) => begin
        #= array * scalar => Op.{elemOp}_ARRAY_SCALAR. =#
        resultType = copyDims(type1, resultType)
        op = makeArrayScalar(resultType, elemOp)
        (resultType, op)
      end

      (false, true) => begin
        #= scalar * array => Op.{elemOp}_SCALAR_ARRAY; =#
        resultType = copyDims(type2, resultType)
        op = makeScalarArray(resultType, elemOp)
        (resultType, op)
      end

      #= array * array => Op.{elemOp}_EW (omc f3c163ba5b: the flat model keeps `.*`, not the matrix product `*`). =#
      (true, true) => (resultType, makeEW(OPERATOR(resultType, elemOp)))

      #= scalar * scalar => Op.{elemOp}. =#
      _ => (resultType, OPERATOR(resultType, elemOp))
    end
  end
  binaryExp = BINARY_EXPRESSION(e1, op, e2)
  if !valid
    printUnresolvableTypeError(binaryExp, list(type1, type2), info)
  end
  return (binaryExp, resultType)
end

function checkUnaryOperation(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  operator::OPERATOR,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local unaryType::ModelicaType
  local unaryExp::Expression

  local op::OPERATOR

  if isComplex(arrayElementType(type1))
     (unaryExp, unaryType) =
      checkOverloadedUnaryOperator(exp1, type1, var1, operator, info)
    return (unaryExp, unaryType)
  end
  unaryType = type1
  op = setType(unaryType, operator)
  unaryExp = begin
    @match operator.op begin
      Op.ADD => exp1

      _ => UNARY_EXPRESSION(op, exp1)
    end
  end
  #= + is a no-op for arithmetic unary operations. =#
  if !isNumeric(type1)
    printUnresolvableTypeError(unaryExp, list(type1), info)
  end
  return (unaryExp, unaryType)
end

function checkOverloadedUnaryOperator(
  @nospecialize(inExp1::Expression),
  inType1::ModelicaType,
  var::VariabilityType,
  inOp::OPERATOR,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local outType::ModelicaType
  local outExp::Expression

  local opstr::String
  local candidates::Vector{MODELICA_FUNCTION}
  local args::Vector{TypedArg}
  local matchedFunc::MatchedFunction
  local matchedFunctions::Vector{MatchedFunction}
  local exactMatches::Vector{MatchedFunction}

  opstr = symbol(inOp, "'")
  candidates = lookupOperatorFunctionsInType(opstr, inType1)
  #= for fn in candidates loop
     checkValidOperatorOverload(opstr, fn, node1);
     end for; =#
  args = TypedArg[(inExp1, inType1, var)]
  matchedFunctions =
    matchFunctionsSilent(candidates, args, TypedNamedArg[], info)
  #= We only allow exact matches for operator overloading. e.g. no casting or generic matches. =#
  exactMatches = getExactMatches(matchedFunctions)
  if isempty(exactMatches)
    printUnresolvableTypeError(
      UNARY_EXPRESSION(inOp, inExp1),
      list(inType1),
      info,
    )
    fail()
  end
  if length(exactMatches) == 1
    matchedFunc = exactMatches[1]
    outType = returnType(matchedFunc.func)
    outExp = CALL_EXPRESSION(makeTypedCall(
      matchedFunc.func,
      Expression[Util.tuple31(a) for a in matchedFunc.args],
      var,
      outType,
    ))
  else
    Error.addSourceMessage(
      Error.AMBIGUOUS_MATCHING_OPERATOR_FUNCTIONS_NFINST,
      list(
        toString(UNARY_EXPRESSION(inOp, inExp1)),
        candidateFuncListString(list(mfn.func for mfn in matchedFunctions)),
      ),
      info,
    )
    fail()
  end
  return (outExp, outType)
end

function checkLogicalBinaryOperation(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  operator::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local mk::MatchKindType

  if isComplex(arrayElementType(type1)) ||
     isComplex(arrayElementType(type2))
     (outExp, resultType) =
      checkOverloadedBinaryOperator(exp1, type1, var1, operator, exp2, type2, var2, info)
    return (outExp, resultType)
  end
   (e1, e2, resultType, mk) = matchExpressions(exp1, type1, exp2, type2, true)
  outExp = LBINARY_EXPRESSION(
    e1,
    setType(resultType, operator),
    e2,
  )
  if !isCompatibleMatch(mk) || !isBoolean(arrayElementType(resultType))
    printUnresolvableTypeError(outExp, list(type1, type2), info)
  end
  return (outExp, resultType)
end

function checkLogicalUnaryOperation(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  operator::OPERATOR,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType = type1
  local outExp::Expression

  if isComplex(arrayElementType(type1))
     (outExp, resultType) =
      checkOverloadedUnaryOperator(exp1, type1, var1, operator, info)
    return (outExp, resultType)
  end
  outExp =
    LUNARY_EXPRESSION(setType(type1, operator), exp1)
  if !isBoolean(arrayElementType(type1))
    printUnresolvableTypeError(outExp, list(type1), info)
  end
  return (outExp, resultType)
end

function checkRelationOperation(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  var1::VariabilityType,
  operator::OPERATOR,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  var2::VariabilityType,
  origin::ORIGIN_Type,
  info::SourceInfo,
)::Tuple{Expression, ModelicaType}
  local resultType::ModelicaType
  local outExp::Expression

  local e1::Expression
  local e2::Expression
  local ty::ModelicaType
  local mk::MatchKindType
  local valid::Bool
  local o::OpType

  if isComplex(arrayElementType(type1)) ||
     isComplex(arrayElementType(type2))
     (outExp, resultType) =
      checkOverloadedBinaryOperator(exp1, type1, var1, operator, exp2, type2, var2, info)
    return (outExp, resultType)
  end
   (e1, e2, ty, mk) = matchExpressions(exp1, type1, exp2, type2)
  valid = isCompatibleMatch(mk)
  resultType = TYPE_BOOLEAN()
  outExp =
    RELATION_EXPRESSION(e1, setType(ty, operator), e2)
  valid = begin
    @match ty begin
      TYPE_INTEGER(__) => valid

      TYPE_REAL(__) => begin
        #=  Print a warning for == or <> with Real operands in a model. =#
        o = operator.op
        if flagNotSet(origin, ORIGIN_FUNCTION) &&
           (o == Op.EQUAL || o == Op.NEQUAL)
          Error.addStrictMessage(
            Error.WARNING_RELATION_ON_REAL,
            list(
              toString(outExp),
              symbol(operator, ""),
            ),
            info,
          )
        end
        valid
      end

      TYPE_STRING(__) => valid

      TYPE_BOOLEAN(__) => valid

      TYPE_ENUMERATION(__) => valid

      _ => false
    end
  end
  if !valid
    printUnresolvableTypeError(outExp, list(type1, type2), info)
  end
  return (outExp, resultType)
end

function printUnresolvableTypeError(
  @nospecialize(exp::Expression),
  types::List{<:ModelicaType},
  ::SourceInfo,
  printError::Bool = true,
)
  local exp_str::String
  local ty_str::String
  if printError
    exp_str = toString(exp)
    ty_str = ListUtil.toString(types, toString, "", "", ", ", "", false)
    # Error.addSourceMessage(
    #   Error.UNRESOLVABLE_TYPE,
    #   list(exp_str, ty_str, "<NO_COMPONENT>"),
    #   info,
    # )
  end
  @error "Unresolvable type for: " * exp_str * "\n Type was: " * ty_str
  return fail()
end

@nospecializeinfer function matchExpressions(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  allowUnknown::Bool = false,
  )

  #= Return true if the references are the same. =#
  if referenceEq(type1, type2)
    compatibleType = type1
    matchKind = MatchKind.EXACT
    return (exp1, exp2, compatibleType, matchKind)
  end
  #= Check if the types are different kinds of types. =#
  if valueConstructor(type1) != valueConstructor(type2)
    @match (exp1, exp2, compatibleType, matchKind) =
      matchExpressions_cast(exp1, type1, exp2, type2, allowUnknown)
    return (exp1, exp2, compatibleType, matchKind)
  end

  matchExpressions2(
    exp1,
    type1,
    exp2,
    type2,
    allowUnknown)
end

function matchExpressions2(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  allowUnknown::Bool = false,
)::Tuple{Expression, Expression, ModelicaType, MatchKindType}
  local e1::Expression
  local e2::Expression
  local cty::ModelicaType
  local mk::MatchKindType

  #= If the types are not of the same kind we might need to type cast one of the expressions
     to make them compatible.
     The types are of the same kind, so we only need to match on one of them. =#
  mk = MatchKind.EXACT
  cty = begin
    @match type1 begin
      TYPE_INTEGER(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_REAL(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_STRING(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_BOOLEAN(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_CLOCK(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_ENUMERATION(__) => begin
        mk = matchEnumerationTypes(type1, type2)
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_ENUMERATION_ANY(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_ARRAY(__) => begin
        (e1, e2, cty, mk) = matchArrayExpressions(exp1, type1, exp2, type2, allowUnknown)
        cty
      end

      TYPE_TUPLE(__) => begin
        @match (e2, cty, mk) =
           matchTupleTypes(type2, type1, exp2, allowUnknown)
        e1 = exp1
        cty
      end

      TYPE_UNKNOWN(__) => begin
        mk = if allowUnknown
          MatchKind.EXACT
        else
          MatchKind.NOT_COMPATIBLE
        end
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_COMPLEX(__) => begin
        #= TODO: This needs more work to handle e.g. type casting of complex expressions. =#
        (e1, cty, mk) = matchComplexTypes(type1, type2, exp1, allowUnknown)
        e2 = exp2
        cty
      end

      TYPE_METABOXED(__) => begin
        (e1, e2, cty, mk) = matchBoxedExpressions(exp1, type1, exp2, type2, allowUnknown)
        cty
      end

      TYPE_FUNCTION(__) => begin
        (e1, cty, mk) = matchFunctionTypes(type1, type2, exp1, allowUnknown)
        e2 = exp2
        cty
      end

      TYPE_ANY(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      TYPE_NORETCALL(__) => begin
        @match (e1, e2) = (exp1, exp2)
        type1
      end

      _ => begin
        @match (e1, e2) = (exp1, exp2)
        Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        fail()
      end
    end
  end
  return (e1, e2, cty, mk)
end

@nospecializeinfer function matchTypes(
  @nospecialize(actualType::ModelicaType),
  @nospecialize(expectedType::ModelicaType),
  @nospecialize(expression::Expression),
  allowUnknown::Bool = false,
  )::Tuple{Expression, ModelicaType, Int}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType
  #=  Return true if the references are the same. =#
  if referenceEq(actualType, expectedType)
    compatibleType = actualType
    matchKind = MatchKind.EXACT
    return (expression, compatibleType, matchKind)
  end
  #=  Check if the types are different kinds of types. =#
  if valueConstructor(actualType) != valueConstructor(expectedType)
    (expression, compatibleType, matchKind) =
      matchTypes_cast(actualType, expectedType, expression, allowUnknown)
    return (expression, compatibleType, matchKind)
  end
  #= If the types are not of the same kind we might need to type cast the
     expression to make it compatible.
     The types are of the same kind, so we only need to match on one of them. =#
  matchKind = MatchKind.EXACT
  compatibleType = begin
    @match actualType begin
      TYPE_INTEGER(__) => actualType

      TYPE_REAL(__) => actualType

      TYPE_STRING(__) => actualType

      TYPE_BOOLEAN(__) => actualType

      TYPE_CLOCK(__) => actualType

      TYPE_ENUMERATION(__) => begin
        matchKind = matchEnumerationTypes(actualType, expectedType)
        actualType
      end

      TYPE_ENUMERATION_ANY(__) => actualType

      TYPE_ARRAY(__) => begin
         (expression, compatibleType, matchKind) =
           matchArrayTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_TUPLE(__) => begin
         (expression, compatibleType, matchKind) =
          matchTupleTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_UNKNOWN(__) => begin
        matchKind = if allowUnknown
          MatchKind.EXACT
        else
          MatchKind.NOT_COMPATIBLE
        end
        actualType
      end

      TYPE_COMPLEX(__) => begin
         (expression, compatibleType, matchKind) =
          matchComplexTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_FUNCTION(__) => begin
         (expression, compatibleType, matchKind) =
          matchFunctionTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_METABOXED(__) => begin
         (expression, compatibleType, matchKind) = matchTypes(
          actualType.ty,
          unbox(expectedType),
          unbox(expression),
          allowUnknown,
        )
        expression = box(expression)
        compatibleType = box(compatibleType)
        compatibleType
      end

      _ => begin
        #Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        @error "Got unknown type"
        fail()
      end
    end
  end
  return (expression, compatibleType, matchKind)
end

function matchTypesRef(
  actualType::T1,
  expectedType::T2,
  @nospecialize(expression::Expression),
  refTyExp::Ref{ModelicaType},
  refMatchKind::Ref{MatchKindType},
  allowUnknown::Bool = false,
  )::Expression where {T1 <: ModelicaType, T2 <: ModelicaType}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType
  #=  Return true if the references are the same. =#
  if referenceEq(actualType, expectedType)
    compatibleType = actualType
    matchKind = MatchKind.EXACT
    refTyExp.x = compatibleType
    refMatchKind.x = matchKind
    return expression
  end
  #=  Check if the types are different kinds of types. =#
  if valueConstructor(actualType) != valueConstructor(expectedType)
    expression = matchTypes_castRef(actualType, expectedType, expression, refTyExp, refMatchKind, allowUnknown)
    return expression
  end
  #= If the types are not of the same kind we might need to type cast the
     expression to make it compatible.
     The types are of the same kind, so we only need to match on one of them. =#
  matchKind = MatchKind.EXACT
  compatibleType = begin
    @match actualType begin
      TYPE_INTEGER(__) => actualType

      TYPE_REAL(__) => actualType

      TYPE_STRING(__) => actualType

      TYPE_BOOLEAN(__) => actualType

      TYPE_CLOCK(__) => actualType

      TYPE_ENUMERATION(__) => begin
        matchKind = matchEnumerationTypes(actualType, expectedType)
        actualType
      end

      TYPE_ENUMERATION_ANY(__) => actualType

      TYPE_ARRAY(__) => begin
        expression = matchArrayTypesRef(actualType, expectedType, expression, refTyExp, refMatchKind, allowUnknown)
        compatibleType = refTyExp.x
        matchKind = refMatchKind.x
        compatibleType
      end

      TYPE_TUPLE(__) => begin
         (expression, compatibleType, matchKind) =
          matchTupleTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_UNKNOWN(__) => begin
        matchKind = if allowUnknown
          MatchKind.EXACT
        else
          MatchKind.NOT_COMPATIBLE
        end
        actualType
      end

      TYPE_COMPLEX(__) => begin
         (expression, compatibleType, matchKind) =
          matchComplexTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_FUNCTION(__) => begin
         (expression, compatibleType, matchKind) =
          matchFunctionTypes(actualType, expectedType, expression, allowUnknown)
        compatibleType
      end

      TYPE_METABOXED(__) => begin
         (expression, compatibleType, matchKind) = matchTypes(
          actualType.ty,
          unbox(expectedType),
          unbox(expression),
          allowUnknown,
        )
        expression = box(expression)
        compatibleType = box(compatibleType)
        compatibleType
      end

      _ => begin
        #Error.assertion(false, getInstanceName() + " got unknown type.", sourceInfo())
        @error "Got unknown type"
        fail()
      end
    end
  end
  refTyExp.x = compatibleType
  refMatchKind.x = matchKind
  return expression
end

function matchTypes_castRef(
  actualType::ModelicaType,
  expectedType::ModelicaType,
  @nospecialize(expression::Expression),
  refTyExp::Ref{ModelicaType},
  refMatchKind::Ref{MatchKindType},
  allowUnknown::Bool = false,
  )::Expression
  local matchKind::MatchKindType
  local compatibleType::ModelicaType
  matchKind = begin
    @match (actualType, expectedType) begin
      (TYPE_INTEGER(__), TYPE_REAL(__)) => begin
        #= Integer can be cast to Real. =#
        expression = typeCast(expression, expectedType)
        refTyExp.x = expectedType
        MatchKind.CAST
      end

      #= An enumeration used as an Integer, --allowNonStandardModelica=nonStdEnumerationAsIntegers (omc). =#
      (TYPE_ENUMERATION(__), TYPE_INTEGER(__)) where {Flags.isConfigFlagSet(Flags.ALLOW_NON_STANDARD_MODELICA, "nonStdEnumerationAsIntegers")} => begin
        expression = typeCast(expression, expectedType)
        refTyExp.x = expectedType
        MatchKind.CAST
      end

      (TYPE_ENUMERATION(__), TYPE_ENUMERATION_ANY(__)) => begin
        refTyExp.x = actualType
        MatchKind.CAST
      end

      (TYPE_TUPLE(types = _ <| _), _) => begin
        (expression, compatibleType, matchKind) =
          matchTypes(listHead(actualType.types), expectedType, expression, allowUnknown)
        if isCompatibleMatch(matchKind)
          expression = begin
            @match expression begin
              TUPLE_EXPRESSION(__) => listHead(expression.elements)

              _ => begin
                TUPLE_ELEMENT_EXPRESSION(
                  expression,
                  1,
                  setArrayElementType(
                    typeOf(expression),
                    compatibleType,
                  ),
                )
              end
            end
          end
          matchKind = MatchKind.CAST
        end
        refTyExp.x = compatibleType
        matchKind
      end

      (TYPE_UNKNOWN(__), _) => begin
        refTyExp.x = expectedType
        if allowUnknown
          MatchKind.UNKNOWN_ACTUAL
        else
          MatchKind.NOT_COMPATIBLE
        end
      end

      (_, TYPE_UNKNOWN(__)) => begin
        refTyExp.x = actualType
        if allowUnknown
          MatchKind.UNKNOWN_EXPECTED
        else
           MatchKind.NOT_COMPATIBLE
        end
      end

      (TYPE_METABOXED(__), _) => begin
        #= Allow unknown types in some cases, e.g. () has type METALIST(UNKNOWN) =#
        expression = unbox(expression)
        (expression, compatibleType, matchKind) = matchTypes(actualType.ty, expectedType, expression, allowUnknown)
        refTyExp.x = compatibleType
        if isCompatibleMatch(matchKind)
           MatchKind.CAST
         else
           matchKind
         end
      end

      (_, TYPE_METABOXED(__)) => begin
        (expression, compatibleType, matchKind) =
          matchTypes(actualType, expectedType.ty, expression, allowUnknown)
        expression = box(expression)
        compatibleType = box(compatibleType)
        refTyExp.x = compatibleType
        if isCompatibleMatch(matchKind)
          MatchKind.CAST
         else
          matchKind
        end
      end

      (_, TYPE_POLYMORPHIC(__)) => begin
        expression = BOX_EXPRESSION(expression)
        refTyExp.x = TYPE_METABOXED(actualType)
        MatchKind.GENERIC
      end

      (TYPE_POLYMORPHIC(__), _) => begin
        refTyExp.x = expectedType
        MatchKind.GENERIC
      end

      (_, TYPE_ANY(__)) => begin
        refTyExp.x = expectedType
        MatchKind.EXACT
      end

      _ => begin
        refTyExp.x =TYPE_UNKNOWN()
        MatchKind.NOT_COMPATIBLE
      end
    end
  end
  #= Expected type is any, any actual type matches.
     Anything else is not compatible. =#
  refMatchKind.x = matchKind
  return expression
end

function matchExpressions_cast(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  allowUnknown::Bool,
)::Tuple{Expression, Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType

   (compatibleType, matchKind) = begin
    @match (type1, type2) begin
      (TYPE_INTEGER(__), TYPE_REAL(__)) => begin
        #= Integer can be cast to Real. =#
        exp1 = typeCast(exp1, type2)
        (type2, MatchKind.CAST)
      end

      (TYPE_REAL(__), TYPE_INTEGER(__)) => begin
        exp2 = typeCast(exp2, type1)
        (type1, MatchKind.CAST)
      end

      (TYPE_BOOLEAN(__), TYPE_REAL(__)) where {(Flags.isSet(Flags.NF_API))} => begin
        #= Boolean can be cast to Real (only if -d=nfAPI is on)
           as there are annotations having expressions such as Boolean x > 0.5 =#
        Error.addCompilerWarning(
          "Allowing casting of boolean expression: " +
          toString(exp1) +
          " to Real.",
        )
        exp1 = typeCast(exp1, type2)
        (type2, MatchKind.CAST)
      end

      (TYPE_REAL(__), TYPE_BOOLEAN(__)) where {(Flags.isSet(Flags.NF_API))} => begin
        Error.addCompilerWarning(
          "Allowing casting of boolean expression: " +
          toString(exp2) +
          " to Real.",
        )
        exp2 = typeCast(exp2, type1)
        (type1, MatchKind.CAST)
      end

      (_, TYPE_TUPLE(types = compatibleType <| _)) => begin
        #= This case takes care of equations where the lhs is a non-tuple and the rhs a
           function call returning a tuple, in which case only the first element of the
           tuple is used. exp1 should never be a tuple here, since any tuple expression
           not alone on the rhs of an equation is \"tuple subscripted\" by typeExp. =#
        exp2 = tupleElement(exp2, compatibleType, 1)
        (exp2, compatibleType, matchKind) =
          matchTypes(compatibleType, type1, exp2, allowUnknown)
        if isCompatibleMatch(matchKind)
          matchKind = MatchKind.CAST
        end
        (compatibleType, matchKind)
      end

      (TYPE_UNKNOWN(__), _) => begin
        (type2, if allowUnknown
          MatchKind.EXACT
        else
          MatchKind.NOT_COMPATIBLE
        end)
      end

      (_, TYPE_UNKNOWN(__)) => begin
        (type1, if allowUnknown
          MatchKind.EXACT
        else
          MatchKind.NOT_COMPATIBLE
        end)
      end

      (TYPE_METABOXED(__), _) => begin
         (exp1, exp2, compatibleType, matchKind) = matchExpressions(
          unbox(exp1),
          type1.ty,
          exp2,
          type2,
          allowUnknown,
        )
        (compatibleType, matchKind)
      end

      (_, TYPE_METABOXED(__)) => begin
        (exp1, exp2, compatibleType, matchKind) = matchExpressions(
          exp1,
          type1,
          unbox(exp2),
          type2.ty,
          allowUnknown,
         )
        (compatibleType, matchKind)
      end

      (_, TYPE_POLYMORPHIC(__)) => begin
        exp1 = box(exp1)
        (box(type1), MatchKind.GENERIC)
      end

      (TYPE_POLYMORPHIC(__), _) => begin
        exp2 = box(exp2)
        (box(type2), MatchKind.GENERIC)
      end

      _ => (TYPE_UNKNOWN(), MatchKind.NOT_COMPATIBLE)
    end
  end
  return (exp1, exp2, compatibleType, matchKind)
end

function matchComplexTypes(
  actualType::ModelicaType,
  expectedType::ModelicaType,
  @nospecialize(expression::Expression),
  allowUnknown::Bool,
)::Tuple{Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType = MatchKind.NOT_COMPATIBLE
  local compatibleType::ModelicaType = actualType

  local cls1::Class
  local cls2::Class
  local anode::InstNode
  local enode::InstNode
  local comps1::Vector{InstNode}
  local comps2::Vector{InstNode}
  local cty1::ComplexType
  local cty2::ComplexType
  local e::Expression
  local elementsV::Vector{Expression}
  local mk::MatchKindType
  local comp1::Component
  local comp2::Component

  @match TYPE_COMPLEX(cls = anode) = actualType
  @match TYPE_COMPLEX(cls = enode) = expectedType
  #= TODO: revise this. =#
  if isSame(anode, enode)
    matchKind = MatchKind.EXACT
    return (expression, compatibleType, matchKind)
  end
  cls1 = getClass(anode)
  cls2 = getClass(enode)
  #= Handle connector types directly from type args (works for both INSTANCED_CLASS and TYPED_DERIVED) =#
  if actualType.complexTy isa COMPLEX_CONNECTOR && expectedType.complexTy isa COMPLEX_CONNECTOR
    cty1 = actualType.complexTy
    cty2 = expectedType.complexTy
    matchKind = matchComponentList(cty1.potentials, cty2.potentials, allowUnknown)
    if matchKind != MatchKind.NOT_COMPATIBLE
      matchKind = matchComponentList(cty1.flows, cty2.flows, allowUnknown)
      if matchKind != MatchKind.NOT_COMPATIBLE
        matchKind = matchComponentList(cty1.streams, cty2.streams, allowUnknown)
      end
    end
    if matchKind != MatchKind.NOT_COMPATIBLE
      matchKind = MatchKind.PLUG_COMPATIBLE
    end
    return (expression, compatibleType, matchKind)
  end
  @match (cls1, cls2, expression) begin
    (
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps1)),
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps2)),
      RECORD_EXPRESSION(elements = elementsV),
    ) => begin
      matchKind = MatchKind.PLUG_COMPATIBLE
      if arrayLength(comps1) != arrayLength(comps2) ||
         arrayLength(comps1) != length(elementsV)
        matchKind = MatchKind.NOT_COMPATIBLE
      else
        local matched_elements = Expression[]
        for i = 1:arrayLength(comps1)
          e = elementsV[i]
           (e, _, mk) = matchTypes(
            getType(comps1[i]),
            getType(comps2[i]),
            e,
            allowUnknown,
          )
          push!(matched_elements, e)
          if mk == MatchKind.CAST
            matchKind = mk
          elseif !isValidPlugCompatibleMatch(mk)
            matchKind = MatchKind.NOT_COMPATIBLE
            break
          end
        end
        if matchKind == MatchKind.CAST
          expression.elements = matched_elements
        end
      end
      if matchKind != MatchKind.NOT_COMPATIBLE
        matchKind = MatchKind.PLUG_COMPATIBLE
      end
      ()
    end

    (
      INSTANCED_CLASS(
        ty = TYPE_COMPLEX(complexTy = cty1 && COMPLEX_CONNECTOR(__)),
      ),
      INSTANCED_CLASS(
        ty = TYPE_COMPLEX(complexTy = cty2 && COMPLEX_CONNECTOR(__)),
      ),
      _,
    ) => begin
      matchKind =
        matchComponentList(cty1.potentials, cty2.potentials, allowUnknown)
      if matchKind != MatchKind.NOT_COMPATIBLE
        matchKind = matchComponentList(cty1.flows, cty2.flows, allowUnknown)
        if matchKind != MatchKind.NOT_COMPATIBLE
          matchKind = matchComponentList(cty1.streams, cty2.streams, allowUnknown)
        end
      end
      if matchKind != MatchKind.NOT_COMPATIBLE
        matchKind = MatchKind.PLUG_COMPATIBLE
      end
      ()
    end

    (
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps1)),
      INSTANCED_CLASS(elements = CLASS_TREE_FLAT_TREE(components = comps2)),
      _,
    ) => begin
      matchKind = MatchKind.PLUG_COMPATIBLE
      if arrayLength(comps1) != arrayLength(comps2)
        matchKind = MatchKind.NOT_COMPATIBLE
      else
        for i = 1:arrayLength(comps1)
          comp1 = component(comps1[i])
          comp2 = component(comps2[i])
          #= Both typed: an untyped field's type is its element type (under parallel typing
             another task's record: sta of Stage[1] read as Stage, a binding type mismatch). =#
          if isTyped(comp1) && isTyped(comp2)
             (_, _, mk) = matchTypes(
              getType(comp1),
              getType(comp2),
              expression,
              allowUnknown,
            )
            if !isValidPlugCompatibleMatch(mk)
              matchKind = MatchKind.NOT_COMPATIBLE
              break
            end
          end
        end
      end
      ()
    end

    _ => begin
      matchKind = MatchKind.NOT_COMPATIBLE
      ()
    end
  end
  return (expression, compatibleType, matchKind)
end

function matchComponentList(
  comps1::List{<:InstNode},
  comps2::List{<:InstNode},
  allowUnknown::Bool,
)::MatchKindType
  local matchKind::MatchKindType

  local c2::InstNode
  local rest_c2::List{InstNode} = comps2
  local dummy::Expression = INTEGER_EXPRESSION(0)

  if listLength(comps1) != listLength(comps2)
    matchKind = MatchKind.NOT_COMPATIBLE
  else
    for c1 in comps1
      @match _cons(c2, rest_c2) = rest_c2
      if name(c1) != name(c2)
        matchKind = MatchKind.NOT_COMPATIBLE
        return matchKind
      end
      (_, _, matchKind) =
        matchTypes(getType(c1), getType(c2), dummy, #=allowUnknown=# allowUnknown)
      if matchKind == MatchKind.NOT_COMPATIBLE
        return matchKind
      end
    end
  end
  matchKind = MatchKind.PLUG_COMPATIBLE
  return matchKind
end

function matchFunctionTypes(
  actualType::ModelicaType,
  expectedType::ModelicaType,
  @nospecialize(expression::Expression),
  allowUnknown::Bool,
)::Tuple{Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType = MatchKind.EXACT
  local compatibleType::ModelicaType = actualType
  local inputs1::List{InstNode}
  local inputs2::List{InstNode}
  local outputs1::List{InstNode}
  local outputs2::List{InstNode}
  local slots1::List{SLOT}
  local slots2::List{SLOT}
  local slot1::SLOT
  local slot2::SLOT

  @match TYPE_FUNCTION(
    fn = MODELICA_FUNCTION(inputs = inputs1, outputs = outputs1, slots = slots1),
  ) = actualType
  @match TYPE_FUNCTION(
    fn = MODELICA_FUNCTION(inputs = inputs2, outputs = outputs2, slots = slots2),
  ) = expectedType
  #= The functions must have the same number of outputs. =#
  if listLength(outputs1) != listLength(outputs2)
    matchKind = MatchKind.NOT_COMPATIBLE
    return (expression, compatibleType, matchKind)
  end
  if !matchFunctionParameters(outputs1, outputs2, allowUnknown)
    matchKind = MatchKind.NOT_COMPATIBLE
    return (expression, compatibleType, matchKind)
  end
  if !matchFunctionParameters(inputs1, inputs2, allowUnknown)
    matchKind = MatchKind.NOT_COMPATIBLE
    return (expression, compatibleType, matchKind)
  end
  #= An input in the actual type must have a default argument if the
     corresponding input in the expected type has one. =#
  for _ in inputs2
    @match _cons(slot1, slots1) = slots1
    @match _cons(slot2, slots2) = slots2
    if isSome(slot2.default) && !isSome(slot1.default)
      matchKind = MatchKind.NOT_COMPATIBLE
      return (expression, compatibleType, matchKind)
    end
  end
  #= The actual type can have more inputs than expected if the extra inputs have
     default arguments. =#
  for slot in slots1
    if !isSome(slot.default)
      matchKind = MatchKind.NOT_COMPATIBLE
      return (expression, compatibleType, matchKind)
    end
  end
  return (expression, compatibleType, matchKind)
end

function matchFunctionParameters(
  params1::List{<:InstNode},
  params2::List{<:InstNode},
  allowUnknown::Bool,
)::Bool
  local matching::Bool = true

  local pl1::List{InstNode} = params1
  local pl2::List{InstNode} = params2
  local p1::InstNode
  local dummy::Expression = INTEGER_EXPRESSION(0)
  local mk::MatchKindType

  for p2 in pl2
    if listEmpty(pl1)
      matching = false
      break
    end
    @match _cons(p1, pl1) = pl1
    if name(p1) != name(p2)
      matching = false
      break
    end
     (_, _, mk) = matchTypes(
      unbox(getType(p1)),
      unbox(getType(p2)),
      dummy,
      allowUnknown,
    )
    if mk != MatchKind.EXACT
      matching = false
      break
    end
  end
  return matching
end

function matchEnumerationTypes(type1::ModelicaType, type2::ModelicaType)::MatchKindType
  local matchKind::MatchKindType
  local lits1::List{String}
  local lits2::List{String}
  @match TYPE_ENUMERATION(literals = lits1) = type1
  @match TYPE_ENUMERATION(literals = lits2) = type2
  matchKind = if ListUtil.isEqualOnTrue(lits1, lits2, stringEqual)
    MatchKind.EXACT
  else
    MatchKind.NOT_COMPATIBLE
  end
  return matchKind
end

function matchArrayExpressions(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  allowUnknown::Bool,
)::Tuple{Expression, Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType

  local ety1::ModelicaType
  local ety2::ModelicaType
  local dims1::List{Dimension}
  local dims2::List{Dimension}

  @match TYPE_ARRAY(elementType = ety1, dimensions = dims1) = type1
  @match TYPE_ARRAY(elementType = ety2, dimensions = dims2) = type2
  #= Check that the element types are compatible. =#
   (exp1, exp2, compatibleType, matchKind) =
    matchExpressions(exp1, ety1, exp2, ety2, allowUnknown)
  #= If the element types are compatible, check the dimensions too. =#
   (compatibleType, matchKind) =
    matchArrayDims(dims1, dims2, compatibleType, matchKind, allowUnknown)
  return (exp1, exp2, compatibleType, matchKind)
end

function matchArrayTypes(
  arrayType1::ModelicaType,
  arrayType2::ModelicaType,
  @nospecialize(expression::Expression),
  allowUnknown::Bool,
)::Tuple{Expression, ModelicaType, Int}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType

  local ety1::ModelicaType
  local ety2::ModelicaType
  local dims1::List{Dimension}
  local dims2::List{Dimension}

  @match TYPE_ARRAY(elementType = ety1, dimensions = dims1) = arrayType1
  @match TYPE_ARRAY(elementType = ety2, dimensions = dims2) = arrayType2
  #=  Check that the element types are compatible. =#
  (expression, compatibleType, matchKind) =
    matchTypes(ety1, ety2, expression, allowUnknown)
  #=  If the element types are compatible, check the dimensions too. =#
  (compatibleType, matchKind) =
    matchArrayDims(dims1, dims2, compatibleType, matchKind, allowUnknown)
  return (expression, compatibleType, matchKind)
end

function matchArrayTypesRef(
  arrayType1::ModelicaType,
  arrayType2::ModelicaType,
  @nospecialize(expression::Expression),
  refTyExp::Ref{ModelicaType},
  refMatchKind::Ref{MatchKindType},
  allowUnknown::Bool,
)::Expression
  local matchKind::MatchKindType
  local compatibleType::ModelicaType
  local ety1::ModelicaType
  local ety2::ModelicaType
  local dims1::List{Dimension}
  local dims2::List{Dimension}
  @match TYPE_ARRAY(elementType = ety1, dimensions = dims1) = arrayType1
  @match TYPE_ARRAY(elementType = ety2, dimensions = dims2) = arrayType2
  #=  Check that the element types are compatible. =#
  expression = matchTypesRef(ety1, ety2, expression, refTyExp, refMatchKind, allowUnknown)
  compatibleType = refTyExp.x
  matchKind = refMatchKind.x
  #=  If the element types are compatible, check the dimensions too. =#
  #(compatibleType, matchKind) =
  matchArrayDimsRef(dims1, dims2, compatibleType, matchKind, refTyExp, refMatchKind, allowUnknown)
  return expression
end

function matchArrayDimsRef(
  dims1::List{Dimension},
  dims2::List{Dimension},
  ty::ModelicaType,
  matchKind::MatchKindType,
  refTyExp,
  refMatchKind,
  allowUnknown::Bool,
  )::Nothing
  local rest_dims2::List{Dimension} = dims2
  local dim2::Dimension
  local compat::Bool
  if !isCompatibleMatch(matchKind)
    refTyExp.x = ty
    refMatchKind.x = matchKind
    return #(ty, matchKind)
  end
  #=  The array types must have the same number of dimensions. =#
  if length(dims1) != length(dims2)
    matchKind = MatchKind.NOT_COMPATIBLE
    refTyExp.x = ty
    refMatchKind.x = matchKind
    return #(ty, matchKind::Int)
  end
  local dims1V = dims1
  #= The dimensions of both array types must be compatible.
     We do not preallocate the array here since we might need to break before that. =#
  local cDims::List{Dimension} = nil
  for dim1 in dims1V
    @match Cons{Dimension}(dim2, rest_dims2) = rest_dims2
    (dim1, compat) = matchDimensions(dim1, dim2, allowUnknown)
    if !compat
      matchKind = MatchKind.NOT_COMPATIBLE
      break
    end
    cDims = Cons{Dimension}(dim1, cDims)
  end
  ty = TYPE_ARRAY(ty, listReverse(cDims))
  refTyExp.x = ty
  refMatchKind.x = matchKind
  return
end

function matchArrayDims(
  dims1::List{<:Dimension},
  dims2::List{<:Dimension},
  ty::ModelicaType,
  matchKind::MatchKindType,
  allowUnknown::Bool,
)::Tuple{ModelicaType, Int}
  local rest_dims2::List{Dimension} = dims2
  local compat::Bool
  if !isCompatibleMatch(matchKind)
    return (ty, matchKind)
  end
  #=  The array types must have the same number of dimensions. =#
  if length(dims1) != length(dims2)
    matchKind = MatchKind.NOT_COMPATIBLE
    return (ty, matchKind::Int)
  end
  local dims1V = listArray(dims1)
  local dims2V = listArray(dims2)
  #= The dimensions of both array types must be compatible.
     We do not preallocate the array here since we might need to break before that. =#
  local cDims = Dimension[]
  local refComp = Ref{Bool}(false)
  for (i, dim1) in enumerate(dims1V)
    dim1 = matchDimensionsRef(dim1, dims2V[i], refComp, allowUnknown)
    compat = refComp.x
    if !compat
      matchKind = MatchKind.NOT_COMPATIBLE
      break
    end
    push!(cDims, dim1)
  end
  ty = TYPE_ARRAY(ty, arrayList(cDims))
  return (ty, matchKind::Int)
end

function matchDimensions(
  dim1::Dimension,
  dim2::Dimension,
  ::Bool,
)::Tuple{Dimension, Bool}
  local compatible::Bool
  local compatibleDim::Dimension

  if isEqual(dim1, dim2)
    compatibleDim = dim1
    compatible = true
  else
    if !isKnown(dim1)
      compatibleDim = dim2
      compatible = true
    elseif !isKnown(dim2)
      compatibleDim = dim1
      compatible = true
    else
      compatibleDim = dim1
      compatible = false
    end
  end
  return (compatibleDim, compatible)
end

function matchDimensionsRef(
  dim1::Dimension,
  dim2::Dimension,
  isComp::Ref{Bool},
  ::Bool,
  )::Dimension
  local compatible::Bool
  local compatibleDim::Dimension

  if isEqual(dim1, dim2)
    compatibleDim = dim1
    compatible = true
  else
    if !isKnown(dim1)
      compatibleDim = dim2
      compatible = true
    elseif !isKnown(dim2)
      compatibleDim = dim1
      compatible = true
    else
      compatibleDim = dim1
      compatible = false
    end
  end
  isComp.x = compatible
  return compatibleDim
end

function matchTupleTypes(
  tupleType1::ModelicaType,
  tupleType2::ModelicaType,
  @nospecialize(expression::Expression),
  allowUnknown::Bool,
)::Tuple{Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType = MatchKind.EXACT
  local compatibleType::ModelicaType = tupleType1

  local tyl1::List{ModelicaType}
  local tyl2::List{ModelicaType}
  local ty1::ModelicaType

  @match TYPE_TUPLE(types = tyl1) = tupleType1
  @match TYPE_TUPLE(types = tyl2) = tupleType2
  if listLength(tyl1) < listLength(tyl2)
    matchKind = MatchKind.NOT_COMPATIBLE
    return (expression, compatibleType, matchKind)
  end
  for ty2 in tyl2
    @match _cons(ty1, tyl1) = tyl1
    if isUnknown(ty2)
      continue
    end
     (_, _, matchKind) = matchTypes(ty1, ty2, expression, allowUnknown)
    if matchKind != MatchKind.EXACT
      break
    end
  end
  #= Skip matching if the rhs is _. =#
  return (expression, compatibleType, matchKind)
end

function matchBoxedExpressions(
  @nospecialize(exp1::Expression),
  type1::ModelicaType,
  @nospecialize(exp2::Expression),
  type2::ModelicaType,
  allowUnknown::Bool,
)::Tuple{Expression, Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType

  local e1::Expression
  local e2::Expression

  e1 = unbox(exp1)
  e2 = unbox(exp2)
   (e1, e2, compatibleType, matchKind) =
    matchExpressions(e1, unbox(type1), e2, unbox(type2), allowUnknown)
  if isCastMatch(matchKind)
    exp1 = box(e1)
    exp2 = box(e2)
  end
  compatibleType = box(compatibleType)
  return (exp1, exp2, compatibleType, matchKind)
end

function matchTypes_cast(
  actualType::ModelicaType,
  expectedType::ModelicaType,
  @nospecialize(expression::Expression),
  allowUnknown::Bool = false,
)::Tuple{Expression, ModelicaType, MatchKindType}
  local matchKind::MatchKindType
  local compatibleType::ModelicaType

   (compatibleType, matchKind) = begin
    @match (actualType, expectedType) begin
      (TYPE_INTEGER(__), TYPE_REAL(__)) => begin
        #= Integer can be cast to Real. =#
        expression = typeCast(expression, expectedType)
        (expectedType, MatchKind.CAST)
      end

      #= An enumeration used as an Integer, --allowNonStandardModelica=nonStdEnumerationAsIntegers (omc). =#
      (TYPE_ENUMERATION(__), TYPE_INTEGER(__)) where {Flags.isConfigFlagSet(Flags.ALLOW_NON_STANDARD_MODELICA, "nonStdEnumerationAsIntegers")} => begin
        expression = typeCast(expression, expectedType)
        (expectedType, MatchKind.CAST)
      end

      (TYPE_ENUMERATION(__), TYPE_ENUMERATION_ANY(__)) => begin
        #= Any enumeration is compatible with enumeration(:).
           TODO: FIXME: Maybe this should be generic match =#
        (actualType, MatchKind.CAST)
      end

      (TYPE_TUPLE(types = _ <| _), _) => begin
        #= If the actual type is a tuple but the expected type isn't,
           try to use the first type in the tuple. =#
         (expression, compatibleType, matchKind) =
           matchTypes(listHead(actualType.types), expectedType, expression, allowUnknown)
        if isCompatibleMatch(matchKind)
          expression = begin
            @match expression begin
              TUPLE_EXPRESSION(__) => listHead(expression.elements)

              _ => begin
                TUPLE_ELEMENT_EXPRESSION(
                  expression,
                  1,
                  setArrayElementType(
                    typeOf(expression),
                    compatibleType,
                  ),
                )
              end
            end
          end
          matchKind = MatchKind.CAST
        end
        (compatibleType, matchKind)
      end

      (TYPE_UNKNOWN(__), _) => begin
        (expectedType, if allowUnknown
          MatchKind.UNKNOWN_ACTUAL
        else
          MatchKind.NOT_COMPATIBLE
        end)
      end

      (_, TYPE_UNKNOWN(__)) => begin
        (actualType, if allowUnknown
          MatchKind.UNKNOWN_EXPECTED
        else
          MatchKind.NOT_COMPATIBLE
        end)
      end

      (TYPE_METABOXED(__), _) => begin
        #= Allow unknown types in some cases, e.g. () has type METALIST(UNKNOWN) =#
        expression = unbox(expression)
         (expression, compatibleType, matchKind) =
          matchTypes(actualType.ty, expectedType, expression, allowUnknown)
        (compatibleType, if isCompatibleMatch(matchKind)
          MatchKind.CAST
        else
          matchKind
        end)
      end

      (_, TYPE_METABOXED(__)) => begin
         (expression, compatibleType, matchKind) =
          matchTypes(actualType, expectedType.ty, expression, allowUnknown)
        expression = box(expression)
        compatibleType = box(compatibleType)
        (compatibleType, if isCompatibleMatch(matchKind)
          MatchKind.CAST
        else
          matchKind
        end)
      end

      (_, TYPE_POLYMORPHIC(__)) => begin
        expression = BOX_EXPRESSION(expression)
        #= matchKind := MatchKind.GENERIC(expectedType.b,actualType); =#
        (TYPE_METABOXED(actualType), MatchKind.GENERIC)
      end

      (TYPE_POLYMORPHIC(__), _) => begin
        #= expression := Expression.UNBOX(expression, Expression.typeOf(expression));
           matchKind := MatchKind.GENERIC(expectedType.b,actualType); =#
        (expectedType, MatchKind.GENERIC)
      end

      (_, TYPE_ANY(__)) => (expectedType, MatchKind.EXACT)

      _ => (TYPE_UNKNOWN(), MatchKind.NOT_COMPATIBLE)
    end
  end
  #= Expected type is any, any actual type matches.
     Anything else is not compatible. =#
  return (expression, compatibleType, matchKind)
end

function getRangeType(
  @nospecialize(startExp::Expression),
  @nospecialize(stepExp::Option{<:Expression}),
  @nospecialize(stopExp::Expression),
  rangeElemType::ModelicaType,
  info::SourceInfo,
)::ModelicaType
  local rangeType::ModelicaType

  local dim::Dimension

  dim = begin
    @match rangeElemType begin
      TYPE_INTEGER(__) => getRangeTypeInt(startExp, stepExp, stopExp, info)

      TYPE_REAL(__) => getRangeTypeReal(startExp, stepExp, stopExp, info)

      TYPE_BOOLEAN(__) => begin
        if isSome(stepExp)
          Error.addSourceMessageAndFail(
            Error.RANGE_INVALID_STEP,
            list(toString(rangeElemType)),
            info,
          )
        end
        getRangeTypeBool(startExp, stopExp)
      end

      TYPE_ENUMERATION(__) => begin
        if isSome(stepExp)
          Error.addSourceMessageAndFail(
            Error.RANGE_INVALID_STEP,
            list(toString(rangeElemType)),
            info,
          )
        end
        getRangeTypeEnum(startExp, stopExp)
      end

      _ => begin
        Error.addSourceMessage(
          Error.RANGE_INVALID_TYPE,
          list(toString(rangeElemType)),
          info,
        )
        fail()
      end
    end
  end
  rangeType = TYPE_ARRAY(rangeElemType, list(dim))
  return rangeType
end

function getRangeTypeInt(
  @nospecialize(startExp::Expression),
  @nospecialize(stepExp::Option{<:Expression}),
  @nospecialize(stopExp::Expression),
  info::SourceInfo,
)::Dimension

  local step::Int
  local step_exp::Expression
  local dim_exp::Expression
  local var::VariabilityType
  @match (startExp, stepExp, stopExp) begin
    (INTEGER_EXPRESSION(__), NONE(), INTEGER_EXPRESSION(__)) => fromInteger(max(stopExp.value - startExp.value + 1, 0))

    (
      INTEGER_EXPRESSION(__),
      SOME(INTEGER_EXPRESSION(value = step)),
      INTEGER_EXPRESSION(__),
    ) => begin
      #= Don't allow infinite ranges. =#
      if step == 0
        Error.addSourceMessageAndFail(Error.RANGE_TOO_SMALL_STEP, list(string(step)), info)
      end
      fromInteger(max(
        intDiv(stopExp.value - startExp.value, step) + 1,
        0,
      ))
    end

    (INTEGER_EXPRESSION(1), NONE(), _) => begin
      #= Ranges like 1:n have size n. =#
      dim_exp = simplify(stopExp)
      fromExp(dim_exp, variability(dim_exp))
    end

    (_, NONE(), _) where {(isEqual(startExp, stopExp))} => fromInteger(1)

    _ => begin
      #= Ranges like n:n have size 1.
         For other ranges, create the appropriate expression as dimension.
         max(stop - start + 1, 0) or max(((stop - start) / step) + 1, 0) =#
      dim_exp = BINARY_EXPRESSION(
        stopExp,
        makeSub(TYPE_INTEGER()),
        startExp,
      )
      var = variabilityMax(
        variability(stopExp),
        variability(startExp),
      )
      if isSome(stepExp)
        @match SOME(step_exp) = stepExp
        var = variabilityMax(
          var,
          variability(step_exp),
        )
        dim_exp = CALL_EXPRESSION(makeTypedCall(
          BuiltinFuncs.DIV_INT,
          Expression[dim_exp, step_exp],
          var,
        ))
      end
      dim_exp = BINARY_EXPRESSION(
        dim_exp,
        makeAdd(TYPE_INTEGER()),
        INTEGER_EXPRESSION(1),
      )
      dim_exp = CALL_EXPRESSION(makeTypedCall(
        BuiltinFuncs.MAX_INT,
        Expression[dim_exp, INTEGER_EXPRESSION(0)],
        var,
      ))
      dim_exp = simplify(dim_exp)
      fromExp(dim_exp, var)
    end
  end
end

function getRangeTypeReal(
  @nospecialize(startExp::Expression),
  @nospecialize(stepExp::Option{<:Expression}),
  @nospecialize(stopExp::Expression),
  info::SourceInfo,
)::Dimension

  local start::AbstractFloat
  local step::AbstractFloat
  local dim_exp::Expression
  local step_exp::Expression
  local var::VariabilityType
  @match (startExp, stepExp, stopExp) begin
    (REAL_EXPRESSION(__), NONE(), REAL_EXPRESSION(__)) =>
      begin
        fromInteger(Util.realRangeSize(
          startExp.value,
          1.0,
          stopExp.value,
        ))
      end

    (
      REAL_EXPRESSION(value = start),
      SOME(REAL_EXPRESSION(value = step)),
      REAL_EXPRESSION(__),
    ) => begin
      #= Check that adding step to start actually produces a different value,
         otherwise the step size is too small. =#
      if start == start + step
        Error.addSourceMessageAndFail(Error.RANGE_TOO_SMALL_STEP, list(string(step)), info)
      end
      fromInteger(Util.realRangeSize(
        startExp.value,
        step,
        stopExp.value,
      ))
    end

    (_, NONE(), _) where {(isEqual(startExp, stopExp))} => fromInteger(1)

    _ => begin
      dim_exp = BINARY_EXPRESSION(
        stopExp,
        makeSub(TYPE_REAL()),
        startExp,
      )
      var = variabilityMax(
        variability(stopExp),
        variability(startExp),
      )
      if isSome(stepExp)
        @match SOME(step_exp) = stepExp
        var = variabilityMax(
          var,
          variability(step_exp),
        )
        dim_exp = BINARY_EXPRESSION(
          dim_exp,
          makeDiv(TYPE_REAL()),
          step_exp,
        )
        dim_exp = BINARY_EXPRESSION(
          dim_exp,
          makeAdd(TYPE_REAL()),
          REAL_EXPRESSION(5e-15),
        )
      end
      dim_exp = CALL_EXPRESSION(makeTypedCall(
        BuiltinFuncs.FLOOR,
        Expression[dim_exp],
        var,
      ))
      dim_exp = CALL_EXPRESSION(makeTypedCall(
        BuiltinFuncs.INTEGER_REAL,
        Expression[dim_exp],
        var,
      ))
      dim_exp = BINARY_EXPRESSION(
        dim_exp,
        makeAdd(TYPE_INTEGER()),
        INTEGER_EXPRESSION(1),
      )
      dim_exp = simplify(dim_exp)
      fromExp(dim_exp, var)
    end
  end
end

@nospecializeinfer function getRangeTypeBool(@nospecialize(startExp::Expression), @nospecialize(stopExp::Expression))::Dimension
  local dim::Dimension
  dim = begin
    local sz::Int
    local dim_exp::Expression
    local var::VariabilityType
    @match (startExp, stopExp) begin
      (BOOLEAN_EXPRESSION(__), BOOLEAN_EXPRESSION(__)) => begin
        sz = if startExp.value == stopExp.value
          1
        elseif (startExp.value < stopExp.value)
          2
        else
          0
        end
        fromInteger(sz)
      end

      _ => begin
        if isEqual(startExp, stopExp)
          dim = fromInteger(1)
        else
          var = variabilityMax(
            variability(startExp),
            variability(stopExp),
          )
          dim_exp = IF_EXPRESSION(
            RELATION_EXPRESSION(
              startExp,
              makeEqual(TYPE_BOOLEAN()),
              stopExp,
            ),
            INTEGER_EXPRESSION(1),
            IF_EXPRESSION(
              RELATION_EXPRESSION(
                startExp,
                makeLess(TYPE_BOOLEAN()),
                stopExp,
              ),
              INTEGER_EXPRESSION(2),
              INTEGER_EXPRESSION(0),
            ),
          )
          dim_exp = SimplifyExp.simplify(dim_exp)
          dim = fromExp(dim_exp, var)
        end
        dim
      end
    end
  end
  return dim
end

@nospecializeinfer function getRangeTypeEnum(@nospecialize(startExp::Expression), @nospecialize(stopExp::Expression))::Dimension
  local dim::Dimension

  dim = begin
    local dim_exp::Expression
    local var::VariabilityType
    @match (startExp, stopExp) begin
      (ENUM_LITERAL_EXPRESSION(__), ENUM_LITERAL_EXPRESSION(__)) => begin
        fromInteger(max(stopExp.index - startExp.index + 1, 0))
      end

      (ENUM_LITERAL_EXPRESSION(index = 1), _) => fromExp(stopExp, variability(stopExp))

      _ => begin
        if isEqual(startExp, stopExp)
          dim = fromInteger(1)
        else
          var = variabilityMax(
            variability(startExp),
            variability(stopExp),
          )
          dim_exp = BINARY_EXPRESSION(
            enumIndexExp(startExp),
            makeSub(TYPE_INTEGER()),
            enumIndexExp(stopExp),
          )
          dim_exp = BINARY_EXPRESSION(
            dim_exp,
            makeAdd(TYPE_INTEGER()),
            INTEGER_EXPRESSION(1),
          )
          dim_exp = SimplifyExp.simplify(dim_exp)
          dim = fromExp(dim_exp, var)
        end
        dim
      end
    end
  end
  return dim
end

function matchBinding(
  binding::Binding,
  componentType::ModelicaType,
  name::String,
  component::InstNode,
  )::Binding
  local ty_match::MatchKindType
  local exp::Expression
  local ty::ModelicaType
  local exp_ty::ModelicaType
  local comp_ty::ModelicaType
  local dims::List{List{Dimension}}
  @match binding begin
    TYPED_BINDING(bindingExp = exp) => begin
        @match exp begin
          BINDING_EXP(
            __,
          ) where {(binding.eachType == EachType.NOT_EACH)} => begin
            @match Cons(_, restDims) = exp.parents
            dims = nil
            while restDims !== nil
              @match Cons(p, restDims) = restDims
              dims = Cons{List{Dimension}}(arrayDims(getType(p)), dims)
            end
            dims = listReverse(dims)
            comp_ty = liftArrayLeftList(componentType, ListUtil.flattenReverse(dims, Dimension))
            exp_ty = exp.expType
          end

          _ => begin
            comp_ty = componentType
            exp_ty = binding.bindingType
          end
        end
      local tyRef = Ref{ModelicaType}(TYPE_UNKNOWN())
      local mkRef = Ref{MatchKindType}(MatchKind.NOT_COMPATIBLE)
      exp = matchTypesRef(exp_ty, comp_ty, exp, tyRef, mkRef, #=allowUnknown=# true)
      ty = tyRef.x
      ty_match = mkRef.x
      if !isValidAssignmentMatch(ty_match)
        printBindingTypeError(name, binding, comp_ty, exp_ty, component)
        fail()
      elseif isCastMatch(ty_match)
        binding = TYPED_BINDING(
          exp,
          ty,
          binding.variability,
          binding.eachType,
          binding.evaluated,
          binding.isFlattened,
          binding.info,
        )
      end
      ()
    end

    UNBOUND(__) => ()
    _ => begin
      binding = BINDING_ERROR()
    end
  end
  return binding
end

function printBindingTypeError(
  name::String,
  binding::Binding,
  componentType::ModelicaType,
  bindingType::ModelicaType,
  component::InstNode,
)
  local binding_info::SourceInfo
  local comp_info::SourceInfo
  local mk::MatchKindType

  binding_info = Binding_getInfo(binding)
  comp_info = InstNode_info(component)
  return if isScalar(bindingType) && isArray(componentType)
    Error.addMultiSourceMessage(
      Error.MODIFIER_NON_ARRAY_TYPE_ERROR,
      list(toString(binding), name),
      list(binding_info, comp_info),
    )
  else
     (_, _, mk) = matchTypes(
      arrayElementType(bindingType),
      arrayElementType(componentType),
      EMPTY_EXPRESSION(bindingType),
      true,
    )
    if true #= !Config.getGraphicsExpMode() - always true, graphics mode not supported =#
      if isValidAssignmentMatch(mk)
        Error.addMultiSourceMessage(
          Error.VARIABLE_BINDING_DIMS_MISMATCH,
          list(
            name,
            toString(binding),
            toStringList(arrayDims(componentType)),
            toStringList(arrayDims(bindingType)),
          ),
          list(binding_info, comp_info),
        )
      else
        Error.addMultiSourceMessage(
          Error.VARIABLE_BINDING_TYPE_MISMATCH,
          list(
            name,
            toString(binding),
            toString(componentType),
            toString(bindingType),
          ),
          list(binding_info, comp_info),
        )
      end
    end
  end
  #= forget errors when handling annotations =#
end

""" #= Checks that an expression used as a dimension has a valid type for a
   dimension, otherwise prints an error and fails. =#"""
@nospecializeinfer function checkDimensionType(@nospecialize(exp::Expression), ty::ModelicaType, info::SourceInfo)
  return if !isInteger(ty)
     @match exp begin
       TYPENAME_EXPRESSION(ty = TYPE_ARRAY(elementType = TYPE_BOOLEAN(__))) => ()

       TYPENAME_EXPRESSION(
         ty = TYPE_ARRAY(elementType = TYPE_ENUMERATION(__)),
       ) => ()

       _ => begin
         Error.addSourceMessage(
           Error.INVALID_DIMENSION_TYPE,
           list(toString(exp), toString(ty)),
           info,
         )
         fail()
       end
     end
  end
end

@nospecializeinfer function checkReductionType(ty::ModelicaType, name::Absyn.Path, @nospecialize(exp::Expression), info::SourceInfo)
  local err::String
  err = begin
    @match name begin
      Absyn.IDENT("sum") => begin
        begin
          @match arrayElementType(ty) begin
            TYPE_INTEGER(__) => ""

            TYPE_REAL(__) => ""

            TYPE_COMPLEX(__) where {(checkSumComplexType(ty, exp, info))} => ""

            _ => "Integer or Real, or operator record"
          end
        end
      end

      Absyn.IDENT("product") => begin
        begin
          @match ty begin
            TYPE_INTEGER(__) => ""

            TYPE_REAL(__) => ""

            _ => "scalar Integer or Real"
          end
        end
      end

      Absyn.IDENT("min") => begin
        begin
          @match ty begin
            TYPE_INTEGER(__) => ""

            TYPE_REAL(__) => ""

            TYPE_BOOLEAN(__) => ""

            TYPE_ENUMERATION(__) => ""

            _ => "scalar enumeration, Boolean, Integer, or Real"
          end
        end
      end

      Absyn.IDENT("max") => begin
        begin
          @match ty begin
            TYPE_INTEGER(__) => ""

            TYPE_REAL(__) => ""

            TYPE_BOOLEAN(__) => ""

            TYPE_ENUMERATION(__) => ""

            _ => "scalar enumeration, Boolean, Integer, or Real"
          end
        end
      end

      _ => ""
    end
  end
  return if !stringEmpty(err)
    Error.addSourceMessageAndFail(
      Error.INVALID_REDUCTION_TYPE,
      list(
        toString(exp),
        toString(ty),
        AbsynUtil.pathString(name),
        err,
      ),
      info,
    )
  end
end

@nospecializeinfer function checkSumComplexType(ty::ModelicaType, @nospecialize(exp::Expression), info::SourceInfo)::Bool
  local valid::Bool = true
  local cls_node::InstNode
  local cls::Class
  @match TYPE_COMPLEX(cls = cls_node) = ty
  cls = getClass(cls_node)
  for op in list("'+'", "'0'")
    if !hasOperator(op, cls)
      Error.addSourceMessage(
        Error.OPERATOR_RECORD_MISSING_OPERATOR,
        list(toString(ty), toString(exp), "sum", op),
        info,
      )
      valid = false
    end
  end
  return valid
end
