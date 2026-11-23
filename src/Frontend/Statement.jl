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

isMultiLine(stmt::Statement)::Bool = isvariant(stmt, ALG_FOR) || isvariant(stmt, ALG_IF) || isvariant(stmt, ALG_WHEN) || isvariant(stmt, ALG_WHILE)

function toFlatStreamList(stmtl::Vector{Statement}, indent::String, s; inFunction = false)
  local prev_multi_line::Bool = false
  local multi_line::Bool
  local first::Bool = true
  for stmt in stmtl
    multi_line = isMultiLine(stmt)
    if first
      first = false
    elseif prev_multi_line || multi_line
      s = IOStream_M.append(s, "\\n")
    end
    prev_multi_line = multi_line
    s = toFlatStream(stmt, indent, s; inFunction = inFunction)
    s = IOStream_M.append(s, ";\\n")
  end
  return s
end

function toFlatStream(stmt::Statement, indent::String, s; inFunction = false)
  local str::String
  s = IOStream_M.append(s, indent)
  s = begin
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        s = IOStream_M.append(s, toFlatString(stmt.lhs; inFunction = inFunction))
        s = IOStream_M.append(s, " := ")
        s = IOStream_M.append(s, toFlatString(stmt.rhs; inFunction = inFunction))
        s
      end

      ALG_FUNCTION_ARRAY_INIT(__) => begin
        s = IOStream_M.append(s, "array init")
        s = IOStream_M.append(s, stmt.name)
        s
      end

      ALG_FOR(__) => begin
        s = IOStream_M.append(s, "for ")
        s = IOStream_M.append(s, name(stmt.iterator))
        if isSome(stmt.range)
          s = IOStream_M.append(s, " in ")
          s = IOStream_M.append(
            s,
            toFlatString(Util.getOption(stmt.range); inFunction = true),
          )
        end
        s = IOStream_M.append(s, " loop\\n")
        s = toFlatStreamList(stmt.body, indent + "  ", s; inFunction = inFunction)
        s = IOStream_M.append(s, indent)
        s = IOStream_M.append(s, "end for")
        s
      end

      ALG_IF(__) => begin
        str = "if "
        for b in stmt.branches
          s = IOStream_M.append(s, str)
          s =
            IOStream_M.append(s, toFlatString(Util.tuple21(b); inFunction = inFunction))
          s = IOStream_M.append(s, " then\\n")
          s = toFlatStreamList(Util.tuple22(b), indent + "  ", s; inFunction = inFunction)
          s = IOStream_M.append(s, indent)
          str = "elseif "
        end
        s = IOStream_M.append(s, "end if")
        s
      end

      ALG_WHEN(__) => begin
        str = "when "
        for b in stmt.branches
          s = IOStream_M.append(s, str)
          s =
            IOStream_M.append(s, toFlatString(Util.tuple21(b); inFunction = inFunction))
          s = IOStream_M.append(s, " then\\n")
          s = toFlatStreamList(Util.tuple22(b), indent + "  ", s; inFunction = inFunction)
          s = IOStream_M.append(s, indent)
          str = "elsewhen "
        end
        s = IOStream_M.append(s, "end when")
        s
      end

      ALG_ASSERT(__) => begin
        s = IOStream_M.append(s, "assert(")
        s =
          IOStream_M.append(s, toFlatString(stmt.condition; inFunction = inFunction))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toFlatString(stmt.message; inFunction = inFunction))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toFlatString(stmt.level; inFunction = inFunction))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_TERMINATE(__) => begin
        s = IOStream_M.append(s, "terminate(")
        s = IOStream_M.append(s, toFlatString(stmt.message; inFunction = inFunction))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_REINIT(__) => begin
        s = IOStream_M.append(s, "reinit(")
        s = IOStream_M.append(s, toFlatString(stmt.cref; inFunction = inFunction))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toFlatString(stmt.reinitExp; inFunction = inFunction))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_NORETCALL(__) => begin
        IOStream_M.append(s, toFlatString(stmt.exp; inFunction = inFunction))
      end

      ALG_WHILE(__) => begin
        s = IOStream_M.append(s, "while ")
        s =
          IOStream_M.append(s, toFlatString(stmt.condition; inFunction = inFunction))
        s = IOStream_M.append(s, " loop\\n")
        s = toFlatStreamList(stmt.body, indent + "  ", s; inFunction = inFunction)
        s = IOStream_M.append(s, indent)
        s = IOStream_M.append(s, "end while")
        s
      end

      ALG_RETURN(__) => begin
        IOStream_M.append(s, "return")
      end

      ALG_BREAK(__) => begin
        IOStream_M.append(s, "break")
      end

      _ => begin
        IOStream_M.append(s, "#UNKNOWN STATEMENT#")
      end
    end
  end
  return s
end

function toStreamList(
  stmtl::Union{List{<:Statement}, Vector{<:Statement}},
  indent::String,
  s,
)

  local prev_multi_line::Bool = false
  local multi_line::Bool
  local first::Bool = true

  for stmt in stmtl
    multi_line = isMultiLine(stmt)
    if first
      first = false
    elseif prev_multi_line || multi_line
      s = IOStream_M.append(s, "\\n")
    end
    prev_multi_line = multi_line
    s = toStream(stmt, indent, s)
    s = IOStream_M.append(s, ";\\n")
  end
  #= Improve human parsability by separating statements that spans multiple
     lines (like if-statements) with newlines. =#
  return s
end

function toStream(stmt::Statement, indent::String, s)

  local str::String

  s = IOStream_M.append(s, indent)
  s = begin
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        s = IOStream_M.append(s, toString(stmt.lhs))
        s = IOStream_M.append(s, " := ")
        s = IOStream_M.append(s, toString(stmt.rhs))
        s
      end

      ALG_FUNCTION_ARRAY_INIT(__) => begin
        s = IOStream_M.append(s, "array init")
        s = IOStream_M.append(s, stmt.name)
        s
      end

      ALG_FOR(__) => begin
        s = IOStream_M.append(s, "for ")
        s = IOStream_M.append(s, name(stmt.iterator))
        if isSome(stmt.range)
          s = IOStream_M.append(s, " in ")
          s = IOStream_M.append(
            s,
            toString(Util.getOption(stmt.range)),
          )
        end
        s = IOStream_M.append(s, " loop\\n")
        s = toStreamList(stmt.body, indent + "  ", s)
        s = IOStream_M.append(s, indent)
        s = IOStream_M.append(s, "end for")
        s
      end

      ALG_IF(__) => begin
        str = "if "
        for b in stmt.branches
          s = IOStream_M.append(s, str)
          s =
            IOStream_M.append(s, toString(Util.tuple21(b)))
          s = IOStream_M.append(s, " then\\n")
          s = toStreamList(Util.tuple22(b), indent + "  ", s)
          s = IOStream_M.append(s, indent)
          str = "elseif "
        end
        s = IOStream_M.append(s, "end if")
        s
      end

      ALG_WHEN(__) => begin
        str = "when "
        for b in stmt.branches
          s = IOStream_M.append(s, str)
          s = IOStream_M.append(s, toString(Util.tuple21(b)))
          s = IOStream_M.append(s, " then\\n")
          s = toStreamList(Util.tuple22(b), indent + "  ", s)
          s = IOStream_M.append(s, indent)
          str = "elsewhen "
        end
        s = IOStream_M.append(s, "end when")
        s
      end

      ALG_ASSERT(__) => begin
        s = IOStream_M.append(s, "assert(")
        s = IOStream_M.append(s, toString(stmt.condition))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toString(stmt.message))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toString(stmt.level))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_TERMINATE(__) => begin
        s = IOStream_M.append(s, "terminate(")
        s = IOStream_M.append(s, toString(stmt.message))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_REINIT(__) => begin
        s = IOStream_M.append(s, "reinit(")
        s = IOStream_M.append(s, toString(stmt.cref))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toString(stmt.reinitExp))
        s = IOStream_M.append(s, ")")
        s
      end

      ALG_NORETCALL(__) => begin
        IOStream_M.append(s, toString(stmt.exp))
      end

      ALG_WHILE(__) => begin
        s = IOStream_M.append(s, "while ")
        s = IOStream_M.append(s, toString(stmt.condition))
        s = IOStream_M.append(s, " then\\n")
        s = toStreamList(stmt.body, indent + "  ", s)
        s = IOStream_M.append(s, indent)
        s = IOStream_M.append(s, "end while")
        s
      end

      ALG_RETURN(__) => begin
        IOStream_M.append(s, "return")
      end

      ALG_BREAK(__) => begin
        IOStream_M.append(s, "break")
      end

      _ => begin
        IOStream_M.append(s, "#UNKNOWN STATEMENT#")
      end
    end
  end
  return s
end

"The statements `stmtl` (a list, or an algorithm's vector) as Modelica text."
function toStringList(stmtl::Union{List{<:Statement}, Vector{<:Statement}}, indent::String = "")::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toStreamList(stmtl, indent, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function toString(stmt::Statement, indent::String = "")::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toStream(stmt, indent, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function foldExp(stmt::Statement, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  @match stmt begin
    ALG_ASSIGNMENT(__) => begin
      arg = func(stmt.lhs, arg)::ArgT
      arg = func(stmt.rhs, arg)::ArgT
      ()
    end

    ALG_FOR(__) => begin
      arg = foldExpList(stmt.body, func, arg, ArgT)
      if isSome(stmt.range)
        arg = func(Util.getOption(stmt.range), arg)::ArgT
      end
      ()
    end

    ALG_IF(__) => begin
      for b in stmt.branches
        arg = func(Util.tuple21(b), arg)::ArgT
        arg = foldExpList(Util.tuple22(b), func, arg, ArgT)
      end
      ()
    end

    ALG_WHEN(__) => begin
      for b in stmt.branches
        arg = func(Util.tuple21(b), arg)::ArgT
        arg = foldExpList(Util.tuple22(b), func, arg, ArgT)
      end
      ()
    end

    ALG_ASSERT(__) => begin
      arg = func(stmt.condition, arg)::ArgT
      arg = func(stmt.message, arg)::ArgT
      arg = func(stmt.level, arg)::ArgT
      ()
    end

    ALG_TERMINATE(__) => begin
      arg = func(stmt.message, arg)::ArgT
      ()
    end

    ALG_REINIT(__) => begin
      arg = func(stmt.cref, arg)::ArgT
      arg = func(stmt.reinitExp, arg)::ArgT
      ()
    end

    ALG_NORETCALL(__) => begin
      arg = func(stmt.exp, arg)::ArgT
      ()
    end

    ALG_WHILE(__) => begin
      arg = func(stmt.condition, arg)::ArgT
      arg = foldExpList(stmt.body, func, arg, ArgT)
      ()
    end

    _ => begin
      ()
    end
  end
  return arg
end

function foldExpList(stmt::Vector{Statement}, func::FT, arg::ArgT, ::Type{ArgT})::ArgT where {FT<:Function, ArgT}
  for s in stmt
    arg = foldExp(s, func, arg, ArgT)
  end
  return arg
end

@nospecialized function mapExp(stmt::Statement, func::MapFunc)::Statement
  stmt = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        e1 = func(stmt.lhs)
        e2 = func(stmt.rhs)
        if referenceEq(e1, stmt.lhs) && referenceEq(e2, stmt.rhs)
          stmt
        else
          ALG_ASSIGNMENT(e1, e2, stmt.ty, stmt.source)
        end
      end

      ALG_FOR(__) => begin
        @assign stmt.body = mapExpList(stmt.body, func)
        @assign stmt.range = Util.applyOption(stmt.range, func)
        stmt
      end

      ALG_IF(__) => begin
        @assign stmt.branches = Tuple{Expression, Vector{Statement}}[
          (func(Util.tuple21(b)), mapExpList(Util.tuple22(b), func)) for b in stmt.branches
            ]
        stmt
      end

      ALG_WHEN(__) => begin
        @assign stmt.branches = Tuple{Expression, Vector{Statement}}[
          (func(Util.tuple21(b)), mapExpList(Util.tuple22(b), func)) for b in stmt.branches
        ]
        stmt
      end

      ALG_ASSERT(__) => begin
        e1 = func(stmt.condition)
        e2 = func(stmt.message)
        e3 = func(stmt.level)
        if referenceEq(e1, stmt.condition) &&
           referenceEq(e2, stmt.message) &&
           referenceEq(e3, stmt.level)
          stmt
        else
          ALG_ASSERT(e1, e2, e3, stmt.source)
        end
      end

      ALG_TERMINATE(__) => begin
        reuseIfRefEqual(stmt, stmt.message, func(stmt.message), m -> ALG_TERMINATE(m, stmt.source))
      end

      ALG_REINIT(__) => begin
        local c = func(stmt.cref)
        local e = func(stmt.reinitExp)
        (referenceEq(c, stmt.cref) && referenceEq(e, stmt.reinitExp)) ? stmt : ALG_REINIT(c, e, stmt.source)
      end

      ALG_NORETCALL(__) => begin
        reuseIfRefEqual(stmt, stmt.exp, func(stmt.exp), (@nospecialize(e::Expression),) -> ALG_NORETCALL(e, stmt.source))
      end

      ALG_WHILE(__) => begin
        ALG_WHILE(func(stmt.condition), mapExpList(stmt.body, func), stmt.source)
      end

      _ => begin
        stmt
      end
    end
  end
  return stmt
end

function mapExpList(stmtl::Vector{Statement}, func::MapFunc)
  stmtl = Statement[mapExp(s, func) for s in stmtl]
  return stmtl
end

@nospecialized function map(stmt::Statement, func::MapFn)::Statement
   @match stmt begin
     ALG_FOR(__) => begin
       for (i,s) in enumerate(stmt.body)
         @inbounds stmt.body[i] = map(s, func)
       end
       ()
     end
     ALG_IF(__) => begin
       @assign stmt.branches = Tuple{Expression, Vector{Statement}}[
         (Util.tuple21(b), Statement[map(s, func) for s in Util.tuple22(b)]) for b in stmt.branches ]
       ()
     end
     ALG_WHEN(__) => begin
       @assign stmt.branches = Tuple{Expression, Vector{Statement}}[
         (Util.tuple21(b), Statement[map(s, func) for s in Util.tuple22(b)])
         for b in stmt.branches
       ]
       ()
     end
     ALG_WHILE(__) => begin
       for (i, s) in enumerate(stmt.body)
         @inbounds stmt.body[i] = map(s, func)
       end
       ()
     end
     _ => begin
       ()
     end
   end
  stmt = func(stmt)
  return stmt
end

function apply(stmt::Statement, func::ApplyFn)
  @match stmt begin
    ALG_FOR(__) => begin
      for e in stmt.body
        apply(e, func)
      end
      ()
    end

    ALG_IF(__) => begin
      for b in stmt.branches
        for e in Util.tuple22(b)
          apply(e, func)
        end
      end
      ()
    end

    ALG_WHEN(__) => begin
      for b in stmt.branches
        for e in Util.tuple22(b)
          apply(e, func)
        end
      end
      ()
    end

    ALG_WHILE(__) => begin
      for e in stmt.body
        apply(e, func)
      end
      ()
    end

    ALG_FAILURE(__) => begin
      for e in stmt.body
        apply(e, func)
      end
      ()
    end

    _ => begin
      ()
    end
  end
  return func(stmt)
end

function makeIf(
  branches::Vector{<:Tuple{<:Expression, Vector{<:Statement}}},
  src::SourceInfo,
)::Statement
  local stmt::Statement
  stmt = ALG_IF(branches, src)
  return stmt
end

function makeAssignment(
  lhs::Expression,
  rhs::Expression,
  ty::ModelicaType,
  src::SourceInfo,
)::Statement
  local stmt::Statement

  stmt = ALG_ASSIGNMENT(lhs, rhs, ty, src)
  return stmt
end

function updateImplicitVariabilityAlg(alg::ALGORITHM)
  updateImplicitVariabilityStmts(alg.statements)
end

function updateImplicitVariabilityStmts(stmtl::Vector{Statement}, inWhen::Bool = false)
  for s in stmtl
    updateImplicitVariabilityStmt(s, inWhen)
  end
end

function updateImplicitVariabilityStmt(stmt::Statement, inWhen::Bool)
   @match stmt begin
    ALG_ASSIGNMENT(__)  => begin
       if inWhen
         markImplicitWhenExp(stmt.lhs)
       end
       ()
     end

    ALG_FOR(__)  => begin
       #= 'when' is not allowed in 'for', so we only need to keep going if
          we're already in a 'when'. =#
       if inWhen
         updateImplicitVariabilityStmts(stmt.body, true)
       end
       ()
     end
    ALG_IF(__)  => begin
       #= 'when' is not allowed in 'if', so we only need to keep going if
          we're already in a 'when. =#
       if inWhen
         for branch in stmt.branches
           updateImplicitVariabilityStmts(Util.tuple22(branch), true)
         end
       end
       ()
     end
     ALG_WHEN(__)  => begin
       for branch in stmt.branches
         updateImplicitVariabilityStmts(Util.tuple22(branch), true)
       end
       ()
     end
    ALG_WHILE(__)  => begin
       if inWhen
         updateImplicitVariabilityStmts(stmt.body, true)
       end
       ()
     end
     _  => begin
       ()
     end
   end
end

function replaceIteratorList(@nospecialize(stmtl::Vector{Statement}),
                             @nospecialize(iterator::InstNode),
                             @nospecialize(value::Expression))
  return mapExpList(stmtl, (@nospecialize(x::Expression),) -> replaceIterator(x, iterator, value))
end

function markStructuralParamsSubs(exp::Expression, dummy::Int) ::Int
  @match exp begin
    CREF_EXPRESSION(__)  => begin
      foldSubscripts(exp.cref, markStructuralParamsSub, 0)
      ()
    end
    _  => begin
      ()
    end
  end
  dummy
end

"""
omc NFInst.checkAssignmentRestriction: no assignment to an iterator, nor to a component
of a class that is not a clock, connector, enumeration, record or type.
"""
function checkAssignmentRestriction(@nospecialize(lhs::Expression), info::SourceInfo)
  @match lhs begin
    CREF_EXPRESSION(__) where {isIterator(lhs.cref)} => begin
      Error.addSourceMessage(Error.ASSIGN_ITERATOR_ERROR, list(toString(lhs.cref)), info)
      fail()
    end
    CREF_EXPRESSION(__) where {isvariant(lhs.cref, COMPONENT_REF_CREF) && isComponent(node(lhs.cref))} => begin
      local comp_node::InstNode = node(lhs.cref)
      local res::Restriction = restriction(getClass(comp_node))
      @match res begin
        RESTRICTION_CLOCK(__) || RESTRICTION_CONNECTOR(__) || RESTRICTION_ENUMERATION(__) ||
        RESTRICTION_RECORD(__) || RESTRICTION_TYPE(__) || RESTRICTION_UNKNOWN(__) => ()
        _ => begin
          Error.addSourceMessage(Error.INVALID_SPECIALIZATION_IN_ASSIGNMENT,
            list(name(comp_node), restrictionName(res, classScope(comp_node))), info)
          fail()
        end
      end
    end
    TUPLE_EXPRESSION(__) => begin
      for e in lhs.elements
        checkAssignmentRestriction(e, info)
      end
    end
    _ => ()
  end
  return nothing
end

function instStatement(scodeStmt::SCode.Statement, scope::InstNode, origin::ORIGIN_Type)::Statement
  local exp1::Expression
  local exp2::Expression
  local exp3::Expression
  local oexp::Option{Expression}
  local stmtl::Vector{Statement}
  local branches::Vector{Tuple{Expression, Vector{Statement}}}
  local info::SourceInfo
  local for_scope::InstNode
  local iter::InstNode
  local next_origin::ORIGIN_Type
  @match scodeStmt begin
    SCode.ALG_ASSIGN(info = info) => begin
      exp1 = instExp(scodeStmt.assignComponent, scope, info)
      checkAssignmentRestriction(exp1, info)
      exp2 = instExp(scodeStmt.value, scope, info)
      ALG_ASSIGNMENT(exp1, exp2, TYPE_UNKNOWN(), makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_FOR(info = info) => begin
      oexp = instExpOpt(scodeStmt.range, scope, info)
      (for_scope, iter) = addIteratorToScope(scodeStmt.index, scope, info)
      next_origin = setFlag(origin, ORIGIN_FOR)
      stmtl = instStatements(scodeStmt.forBody, for_scope, next_origin)
      ALG_FOR(iter, oexp, stmtl, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_IF(info = info) => begin
      branches = Tuple{Expression, Vector{Statement}}[]
      next_origin = setFlag(origin, ORIGIN_FOR)
      for branch in _cons((scodeStmt.boolExpr, scodeStmt.trueBranch), scodeStmt.elseIfBranch)
        exp1 = instExp(Util.tuple21(branch), scope, info)
        stmtl = instStatements(Util.tuple22(branch), scope, next_origin)
        push!(branches, (exp1, stmtl))
      end
      if ! isempty(scodeStmt.elseBranch)
        stmtl = instStatements(scodeStmt.elseBranch, scope, next_origin)
        branches = push!(branches, (BOOLEAN_EXPRESSION(true), stmtl))
      end
      ALG_IF(branches, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_WHEN_A(info = info) => begin
      if origin > 0
        if flagSet(origin, ORIGIN_WHEN)
          Error.addSourceMessageAndFail(Error.NESTED_WHEN, nil, info)
        elseif flagSet(origin, ORIGIN_INITIAL)
          Error.addSourceMessageAndFail(Error.INITIAL_WHEN, nil, info)
        else
          Error.addSourceMessageAndFail(Error.INVALID_WHEN_STATEMENT_CONTEXT, nil, info)
        end
      end
      #= Preallocate =#
      branches = Tuple{Expression, Vector{Statement}}[]
      for (i, branch) in enumerate(scodeStmt.branches)
        exp1 = instExp(Util.tuple21(branch), scope, info)
        next_origin = setFlag(origin, ORIGIN_WHEN)
        stmtl = instStatements(Util.tuple22(branch), scope, next_origin)
        push!(branches, (exp1, stmtl))
      end
      ALG_WHEN(branches, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_ASSERT(info = info) => begin
      exp1 = instExp(scodeStmt.condition, scope, info)
      exp2 = instExp(scodeStmt.message, scope, info)
      exp3 = instExp(scodeStmt.level, scope, info)
     ALG_ASSERT(exp1, exp2, exp3, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_TERMINATE(info = info)  => begin
      exp1 = instExp(scodeStmt.message, scope, info)
     ALG_TERMINATE(exp1, makeSource(scodeStmt.comment, info))
    end

    #= Only with --allowNonStandardModelica=reinitInAlgorithms; in a when-statement (typing). =#
    SCode.ALG_REINIT(info = info)  => begin
      if !Flags.isConfigFlagSet(Flags.ALLOW_NON_STANDARD_MODELICA, "reinitInAlgorithms")
        Error.addSourceMessage(Error.REINIT_IN_ALGORITHM, nil, info)
        fail()
      end
      exp1 = instExp(scodeStmt.cref, scope, info)
      exp2 = instExp(scodeStmt.newValue, scope, info)
      ALG_REINIT(exp1, exp2, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_NORETCALL(info = info)  => begin
      exp1 = instExp(scodeStmt.exp, scope, info)
     ALG_NORETCALL(exp1, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_WHILE(info = info)  => begin
      exp1 = instExp(scodeStmt.boolExpr, scope, info)
      next_origin = setFlag(origin, ORIGIN_WHILE)
      stmtl = instStatements(scodeStmt.whileBody, scope, next_origin)
      ALG_WHILE(exp1, stmtl, makeSource(scodeStmt.comment, info))
    end

    SCode.ALG_RETURN(__)  => begin
      if flagNotSet(origin, ORIGIN_FUNCTION)
        Error.addSourceMessage(Error.RETURN_OUTSIDE_FUNCTION, nil, scodeStmt.info)
        fail()
      end
      ALG_RETURN(makeSource(scodeStmt.comment, scodeStmt.info))
    end

    SCode.ALG_BREAK(__)  => begin
      if flagNotSet(origin, ORIGIN_FOR) && flagNotSet(origin, ORIGIN_WHILE)
        Error.addSourceMessage(Error.BREAK_OUTSIDE_LOOP, nil, scodeStmt.info)
        fail()
      end
      ALG_BREAK(makeSource(scodeStmt.comment, scodeStmt.info))
    end

    SCode.ALG_FAILURE(__)  => begin
      stmtl = instStatements(scodeStmt.stmts, scope, origin)
      ALG_FAILURE(stmtl, makeSource(scodeStmt.comment, scodeStmt.info))
    end

    _  => begin
      Error.assertion(false, getInstanceName() + " got unknown statement", sourceInfo())
      fail()
    end
  end
end

function instAlgorithmSections(algorithmSections::List{<:SCode.ALGORITHM}, scope::InstNode, origin::ORIGIN_Type)
  local algs::Vector{ALGORITHM}
  algs = ALGORITHM[instAlgorithmSection(alg, scope, origin) for alg in algorithmSections]
  algs
end

function instAlgorithmSection(algorithmSection::SCode.ALGORITHM, scope::InstNode, origin::ORIGIN_Type)::ALGORITHM
  local alg::ALGORITHM
  alg = ALGORITHM(instStatements(algorithmSection.statements, scope, origin), InstNode_info(scope))
  alg
end

function instStatements(scodeStmtl::List{<:SCode.Statement}, scope::InstNode, origin::ORIGIN_Type)
  local statements::Vector{Statement}
  statements = Statement[instStatement(stmt, scope, origin) for stmt in scodeStmtl]
  return statements
end
