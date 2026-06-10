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

#= Tunable thresholds for the `INLINE_FUNCTIONS_COMPLEXITY_GATE` heuristic.
   Mutable Refs so the user can override at runtime without rebuilding. =#
const INLINE_BODY_MAX_NODES = Ref{Int}(2)
const INLINE_POST_SUB_MAX_NODES = Ref{Int}(2)

#= Per-function body info cache. Body-only stats (hasCall, node count) are
   independent of call-site arguments, so we compute them once per
   `M_FUNCTION` and reuse across every call site. The previous unconditional
   per-call walk dominated flatten time on MultiBody (hundreds of call sites
   to a small pool of distinct helpers). =#
#= (hasCall, nodeCount) tuple cache keyed by the function's InstNode
   objectid. Plain Tuple to dodge world-age issues on Revise-driven struct
   shape changes; UInt key to avoid String allocation per lookup. =#
const _INLINE_BODY_INFO_CACHE = Dict{UInt, Tuple{Bool, Int}}()
const _INLINE_BODY_TOOMANY = (true, typemax(Int))

@nospecialized function _bodyInfo(fn)::Tuple{Bool, Int}
  local key = objectid(fn.node)
  local cached = get(_INLINE_BODY_INFO_CACHE, key, nothing)
  cached !== nothing && return cached
  local body = getBody(fn)
  if length(body) != 1
    _INLINE_BODY_INFO_CACHE[key] = _INLINE_BODY_TOOMANY
    return _INLINE_BODY_TOOMANY
  end
  local stmt = body[1]
  local info = (_stmtHasCall(stmt), _countStmtNodes(stmt))
  _INLINE_BODY_INFO_CACHE[key] = info
  return info
end

"""Mostly written manualy (John) to adjust certain things in N."""
function inlineCallExp(callExp::Expression)::Expression
  local result::Expression
  @assign result = begin
    local call::Call
    local shouldInline::Bool
    @match callExp begin
      CALL_EXPRESSION(call = call && TYPED_CALL(__)) => begin
        @assign shouldInline = begin
          @match inlineType(call) begin
            DAE.BUILTIN_EARLY_INLINE(__) => begin
              true
            end
            DAE.EARLY_INLINE(__) where {(Flags.isSet(Flags.INLINE_FUNCTIONS))} => begin
              if Flags.INLINE_FUNCTIONS_COMPLEXITY_GATE[]
                _passesInlineComplexityGate(call)
              else
                true
              end
            end
            _ => begin
              false
            end
          end
        end
        if shouldInline
          inlineCall(call)
        else
          callExp
        end
      end
      _ => begin
        callExp
      end
    end
  end
  return result
end

#= Cheap node counter for a Statement. =#
@nospecialized function _countStmtNodes(stmt::Statement)::Int
  local n = 0
  mapExp(stmt, e -> begin
    map(e, x -> begin n += 1; x end)
    e
  end)
  return n
end

#= Cheap node counter for an Expression subtree. =#
@nospecialized function _countExpNodes(e::Expression)::Int
  local n = 0
  map(e, x -> begin n += 1; x end)
  return n
end

#= Returns true when the statement body contains any CALL_EXPRESSION. We use
   this as a coarse "do not inline" signal because each nested call would
   recursively trigger inlining on substitute, and on dense MultiBody
   `Frames.*` chains the recursion blows up flatten time by orders of
   magnitude. =#
@nospecialized function _stmtHasCall(stmt::Statement)::Bool
  local hasCall = false
  mapExp(stmt, e -> begin
    map(e, x -> begin
      x isa CALL_EXPRESSION && (hasCall = true)
      x
    end)
    e
  end)
  return hasCall
end

#= Composite gate: small bodies pass unconditionally. Larger bodies pass only
   if the worst-case post-substitution growth stays under the budget. Bodies
   containing further function calls are rejected outright to avoid
   recursive inline blow-up on `Frames.*` / `Vectors.*` chains. =#
function _passesInlineComplexityGate(call::Call)::Bool
  @match call begin
    TYPED_CALL(fn = fn, arguments = args) => begin
      local info = _bodyInfo(fn)
      info[1] && return false
      local b = info[2]
      b <= INLINE_BODY_MAX_NODES[] && return true
      local maxArgSize = 0
      for a in args
        local s = _countExpNodes(a)
        s > maxArgSize && (maxArgSize = s)
      end
      maxArgSize <= 1 && return true
      local nInputs = listLength(fn.inputs)
      nInputs <= 1 && (b + maxArgSize <= INLINE_POST_SUB_MAX_NODES[]) && return true
      b + (nInputs - 1) * maxArgSize <= INLINE_POST_SUB_MAX_NODES[]
    end
    _ => false
  end
end


"""
  Inline function for nonbuiltin callexps
  @author johti17
"""
function inlineSimpleCall(callExp::Expression)::Expression
  local result::Expression
  local call::Call
  local shouldInline = @match callExp begin
    CALL_EXPRESSION(c && TYPED_CALL(fn, ty, var, arguments, attributes)) => begin
      call = c
      shouldInline = true && !(attributes.builtin || isExternal(c)) && isSimpleType(ty)
#      println("Inline = $(shouldInline) for: " * toString(c))
      #= We might want to inline more things, so check arguments anyway =#
      if !shouldInline
        local newArgs = Expression[map(arg, inlineSimpleCall) for arg in arguments]
        callArguments = newArgs
        TYPED_CALL(c.fn, c.ty, c.var, callArguments, c.attributes)
        return CALL_EXPRESSION(call)
      end
      shouldInline
    end
    _ => false
  end
  result = if shouldInline
    inlineCall(call)
  else
    callExp
  end
  return result
end

"""
  Function to inline calls
@author johti17
"""
function inlineCall(call::Call)::Expression
  local exp::Expression
  exp = begin
    local fn::M_Function
    local arg::Expression
    local args::Vector{Expression}
    local inputs::List{InstNode}
    local outputs::List{InstNode}
    local locals::List{InstNode}
    local body::Vector{Statement}
    local stmt::Statement
    @match call begin
      TYPED_CALL(
        fn = fn && M_FUNCTION(inputs = inputs, outputs = outputs, locals = locals),
        arguments = args,
      ) => begin
        #= External functions can't be inlined =#
        if isExternal(call)
          exp = CALL_EXPRESSION(call)
          return exp
        end
        body = getBody(fn)
        #=  This function can so far only handle functions with at most one =#
        #=  statement and output and no local variables. =#
        if length(body) > 1 || listLength(outputs) != 1 || listLength(locals) > 0
          exp = CALL_EXPRESSION(call)
          return exp
        end
        Error.assertion(
          length(inputs) == length(args),
          getInstanceName() +
          " got wrong number of arguments for " +
          AbsynUtil.pathString(name(fn)),
          sourceInfo(),
        )
        #=
        If we have no body there is nothing to inline.
        This might occur for instance for complex operators that are registered as calls in the frontend
        -johti17 2023-03-26
        =#
        if isempty(body)
          exp = CALL_EXPRESSION(call)
          return exp
        end
        stmt = body[1]
        #=
        TODO: Instead of repeating this for each input we should probably
          just build a lookup tree or hash table and go through the
          statement once.
        =#
        for i in inputs
          @match [arg, args...] = args
          stmt = mapExp(stmt,
                        (exp) -> map(exp, (exp) -> replaceCrefNode(exp, i, arg)))
        end
        getOutputExp(stmt, listHead(outputs), call)
      end

      _ => begin
        CALL_EXPRESSION(call)
      end
    end
  end
  return exp
end

function replaceCrefNode(exp::Expression, node::InstNode, value::Expression)::Expression
  local ty::M_Type
  local repl_ty::M_Type
  if exp isa CREF_EXPRESSION && exp.cref isa COMPONENT_REF_CREF
    local cr = exp.cref
    local basePart = cr
    while basePart.restCref isa COMPONENT_REF_CREF
      basePart = basePart.restCref
    end
    if refEqual(node, basePart.node)
      local cref_parts = toListReverse(cr)
      local result = applySubscripts(basePart.subscripts, value)
      local fieldParts = listRest(cref_parts)
      for fieldCr in fieldParts
        result = makeImmutable(result)
        result = recordElement(name(fieldCr.node), result)
        result = applySubscripts(fieldCr.subscripts, result)
      end
      exp = result
    end
  end
  ty = typeOf(exp)
  if ty isa TYPE_ARRAY || ty isa TYPE_TUPLE || ty isa TYPE_FUNCTION || ty isa TYPE_METABOXED
    repl_ty = mapDims(ty, (dimArg) -> replaceDimExp(dimArg, node, value))
    if !referenceEq(ty, repl_ty)
      exp = setType(repl_ty, exp)
    end
  end
  return exp
end

function replaceDimExp(dim::Dimension, node::InstNode, value::Expression)::Dimension
  dim = begin
    local exp::Expression
    @match dim begin
      DIMENSION_EXP(__) => begin
        exp = map(
          dim.exp,
          (x) -> replaceCrefNode(x, node, value),
        )
        fromExp(exp, dim.var)
      end
      _ => begin
        dim
      end
    end
  end
  return dim
end

function getOutputExp(stmt::Statement, outputNode::InstNode, call::Call)::Expression
  local exp::Expression
  exp = begin
    local cr_node::InstNode
    local rest_cr::ComponentRef
    @match stmt begin
      ALG_ASSIGNMENT(
        lhs = CREF_EXPRESSION(
          cref = COMPONENT_REF_CREF(
            node = cr_node,
            subscripts = nil(),
            restCref = rest_cr,
          ),
        ),
      ) where {(
        refEqual(outputNode, cr_node) &&
        !isFromCref(rest_cr)
      )} => begin
        stmt.rhs
      end
      _ => begin
        CALL_EXPRESSION(call)
      end
    end
  end
  return exp
end

function isSimpleType(ty)
  return ty isa TYPE_INTEGER || ty isa TYPE_REAL || ty isa TYPE_STRING || ty isa TYPE_REAL
end
