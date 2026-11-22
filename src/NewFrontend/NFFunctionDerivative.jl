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

#= FUNCTION_DER is defined in FrontendInterfaces/NFInterfaces.jl, before MODELICA_FUNCTION. =#

#import ..SCodeUtil
#import ..SCodeDump

function typeDerivative(fnDer::FUNCTION_DER)
  local mk::MatchKindType
  local order::Expression
  local order_ty::ModelicaType
  local var::VariabilityType
  local infoVar::SourceInfo

  typeNodeCache(fnDer.derivativeFn)
  infoVar = InstNode_info(fnDer.derivedFn)
  (order, order_ty, var) = typeExp(fnDer.order, ORIGIN_FUNCTION, infoVar)
  (order, _, mk) = matchTypes(order_ty, TYPE_INTEGER(), order)
  if isIncompatibleMatch(mk)
    Error.addSourceMessage(
      Error.VARIABLE_BINDING_TYPE_MISMATCH,
      list(
        "order",
        toString(order),
        "Int",
        toString(order_ty),
      ),
      infoVar,
    )
    fail()
  end
  if var > Variability.CONSTANT
    Error.addSourceMessage(
      Error.HIGHER_VARIABILITY_BINDING,
      list(
        "order",
        variabilityString(Variability.CONSTANT),
        toString(order),
        variabilityString(var),
      ),
      infoVar,
    )
    fail()
  end
  order = evalExp(order, EVALTARGET_GENERIC(infoVar))
  return order
end

function instDerivatives(fnNode::InstNode, fn::MODELICA_FUNCTION)::List{FUNCTION_DER}
  local ders::List{FUNCTION_DER} = nil
  local der_mods::List{SCode.Mod}
  local scope::InstNode
  der_mods = getDerivativeAnnotations(definition(fnNode))
  scope = parent(fnNode)
  for m in der_mods
    ders = instDerivativeMod(m, fnNode, fn, scope, ders)
  end
  return ders
end

function addLowerOrderDerivative2(fn::MODELICA_FUNCTION, lowerDerNode::InstNode)
  fnDerivatives = list(
    begin
      if fn_der isa FUNCTION_DER
        fn_derLowerOrderDerivatives = _cons(lowerDerNode, fn_der.lowerOrderDerivatives)
        FUNCTION_DER(fn_der.derivativeFn,
                     fn_der.derivedFn,
                     fn_der.order,
                     fn_der.conditions,
                     fn_derLowerOrderDerivatives)
      end
    end
    for fn_der in fn.derivatives)
  local f = MODELICA_FUNCTION(fn.path,
                       fn.node,
                       fn.inputs,
                       fn.outputs,
                       fn.locals,
                       fn.slots,
                       fn.returnType,
                       fn.attributes,
                       fnDerivatives,
                       fn.status,
                       fn.callCounter)
  return f
end

function addLowerOrderDerivative(fnNode::InstNode, lowerDerNode::InstNode)
  return mapCachedFuncs(
    fnNode,
    (fn) -> addLowerOrderDerivative2(fn, lowerDerNode),
  )
end

function getInputIndex(nameArg::String, fn::MODELICA_FUNCTION, info::SourceInfo)::Int
  local index::Int = 1

  for i in fn.inputs
    if name(i) == nameArg
      return index
    end
    @assign index = index + 1
  end
  Error.addSourceMessage(
    Error.INVALID_FUNCTION_DERIVATIVE_INPUT,
    list(name, AbsynUtil.pathString(name(fn))),
    info,
  )
  fail()
  return index
end

function getDerivativeAttributes(
  attrs::List{<:SCode.NAMEMOD},
  fn::MODELICA_FUNCTION,
  scope::InstNode,
  info::SourceInfo,
)::Tuple{Expression, List{Tuple{Int, String, DerivativeCondition}}}
  local conditions::List{Tuple{Int, String, DerivativeCondition}} = nil
  local order::Expression = EMPTY_EXPRESSION(TYPE_UNKNOWN())

  local id::String
  local mod::SCode.Mod
  local aexp::Absyn.Exp
  local index::Int

  for attr in attrs
    @match SCode.NAMEMOD(id, mod) = attr
     @match (id, mod) begin
       ("order", SCode.MOD(binding = SOME(aexp))) => begin
         if !isEmpty(order)
           Error.addSourceMessage(
             Error.DUPLICATE_MODIFICATIONS,
             list(id, "derivative"),
             info,
           )
         end
         order = instExp(aexp, scope, info)
         ()
       end

       (
         "noDerivative",
         SCode.MOD(
           binding = SOME(Absyn.CREF(componentRef = Absyn.CREF_IDENT(name = id))),
         ),
       ) => begin
         @assign index = getInputIndex(id, fn, info)
         @assign conditions = _cons((index, id, DERIVATIVE_CONDITION_NO_DERIVATIVE), conditions)
         ()
       end

       (
         "zeroDerivative",
         SCode.MOD(
           binding = SOME(Absyn.CREF(componentRef = Absyn.CREF_IDENT(name = id))),
         ),
       ) => begin
         @assign index = getInputIndex(id, fn, info)
         @assign conditions = _cons((index, id, DERIVATIVE_CONDITION_ZERO_DERIVATIVE), conditions)
         ()
       end

       _ => begin
         Error.addStrictMessage(
           Error.INVALID_FUNCTION_DERIVATIVE_ATTR,
           list(id + (
             if SCodeUtil.isEmptyMod(mod)
               ""
             else
               " = " + SCodeDump.printModStr(mod)
             end
           )),
           info,
         )
         ()
       end
     end
  end
  if isEmpty(order)
    @assign order = INTEGER_EXPRESSION(1)
  end
  return (order, conditions)
end

function instDerivativeMod(
  mod::SCode.Mod,
  fnNode::InstNode,
  fn::MODELICA_FUNCTION,
  scope::InstNode,
  fnDers::List{<:FUNCTION_DER},
)::List{FUNCTION_DER}

  @assign fnDers = begin
    local attrs::List{SCode.NAMEMOD}
    local acref::Absyn.ComponentRef
    local der_node::InstNode
    local order::Expression
    local conds::List{Tuple{Int, String, DerivativeCondition}}
    @match mod begin
      SCode.MOD(subModLst = attrs, binding = SOME(Absyn.CREF(acref))) => begin
         (_, der_node, _) = instFunction(acref, scope, mod.info)
        addLowerOrderDerivative(der_node, fnNode)
        (order, conds) = getDerivativeAttributes(attrs, fn, fnNode, mod.info)
        _cons(FUNCTION_DER(der_node, fnNode, order, conds, nil), fnDers)
      end

      SCode.MOD(__) => begin
        #= Give a warning if the derivative annotation doesn't specify a function name. =#
        Error.addStrictMessage(
          Error.MISSING_FUNCTION_DERIVATIVE_NAME,
          list(AbsynUtil.pathString(name(fn))),
          mod.info,
        )
        fnDers
      end

      _ => begin
        #= We shouldn't get any NOMODs here since they're filtered out when
           translating Absyn to SCode, and redeclare isn't allowed by the syntax. =#
        Error.assertion(false, getInstanceName() + " got invalid modifier", sourceInfo())
        fail()
      end
    end
  end
  return fnDers
end

function getDerivativeAnnotations(definition::SCode.Element)::List{SCode.Mod}
  local ann::SCode.ANNOTATION
  @match definition begin
    SCode.CLASS(
      classDef = SCode.PARTS(
        externalDecl = SOME(SCode.EXTERNALDECL(annotation_ = SOME(ann))),
      ),
    ) => begin
      SCodeUtil.lookupNamedAnnotations(ann, "derivative")
    end

    SCode.CLASS(cmt = SCode.COMMENT(annotation_ = SOME(ann))) => begin
      SCodeUtil.lookupNamedAnnotations(ann, "derivative")
    end

    _ => begin
      nil
    end
  end
end

function toSubMod(fnDer::FUNCTION_DER) ::SCode.NAMEMOD
  local subMod::SCode.NAMEMOD
  local tpl::Tuple{Integer, String, DerivativeCondition}
  local condition::DerivativeCondition
  local id::String
  local mod::SCode.Mod
  local orderMod::SCode.NAMEMOD
  local subMods::List{SCode.NAMEMOD}
  local order::Int
  local info::SourceInfo
  info = InstNode_info(fnDer.derivedFn)
  @match INTEGER_EXPRESSION(order) = fnDer.order
  orderMod = SCode.NAMEMOD("order", SCode.MOD(SCode.NOT_FINAL(),
                                              SCode.NOT_EACH(),
                                              nil,
                                              SOME(Absyn.INTEGER(order)), info))
  subMods = nil
  for tpl in fnDer.conditions
    (_, id, condition) = tpl
    subMods = _cons(SCode.NAMEMOD(conditionToString(condition),
                                  SCode.MOD(SCode.NOT_FINAL(), SCode.NOT_EACH(),
                                            nil, SOME(Absyn.CREF(Absyn.CREF_IDENT(id, nil))), info)), subMods)
  end
  mod = SCode.MOD(SCode.NOT_FINAL(), SCode.NOT_EACH(), _cons(orderMod, subMods),
                  SOME(Absyn.CREF(Absyn.CREF_IDENT(AbsynUtil.pathString(scopePath(fnDer.derivativeFn)), nil))), info)
  subMod = SCode.NAMEMOD("derivative", mod)
  subMod
end

"""The annotation name of a derivative condition: `noDerivative` or `zeroDerivative`."""
function conditionToString(condition::DerivativeCondition)::String
  if condition == DERIVATIVE_CONDITION_NO_DERIVATIVE
    return "noDerivative"
  elseif condition == DERIVATIVE_CONDITION_ZERO_DERIVATIVE
    return "zeroDerivative"
  end
  return string(condition)
end
