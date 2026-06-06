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

@UniontypeDecl NFStatement
@Uniontype NFStatement begin
  @Record ALG_FAILURE begin
    body::Vector{Statement}
    source::DAE.ElementSource
  end

  @Record ALG_BREAK begin
    source::DAE.ElementSource
  end

  @Record ALG_RETURN begin
    source::DAE.ElementSource
  end

  @Record ALG_WHILE begin
    condition::Expression
    body::Vector{Statement}
    source::DAE.ElementSource
  end

  @Record ALG_NORETCALL begin
    exp::Expression
    source::DAE.ElementSource
  end

  @Record ALG_TERMINATE begin
    message::Expression #= The message to display if the terminate triggers. =#
    source::DAE.ElementSource
  end

  @Record ALG_ASSERT begin
    condition::Expression #= The assert condition. =#
    message::Expression #= The message to display if the assert fails. =#
    level::Expression
    source::DAE.ElementSource
  end

  @Record ALG_WHEN begin
    branches::Vector{Tuple{Expression, Vector{Statement}}} #= List of branches, where each branch is a tuple of a condition and a body. =#
    source::DAE.ElementSource
  end

  @Record ALG_IF begin
    branches::Vector{Tuple{Expression, Vector{Statement}}} #= List of branches, where each branch is a tuple of a condition and a body. =#
    source::DAE.ElementSource
  end

  @Record ALG_FOR begin
    iterator::InstNode
    range::Option{Expression}
    body::Vector{Statement} #= The body of the for loop. =#
    source::DAE.ElementSource
  end

  @Record ALG_FUNCTION_ARRAY_INIT begin
    name::String
    ty::M_Type
    source::DAE.ElementSource
  end

  @Record ALG_ASSIGNMENT begin
    lhs::Expression #= The asignee =#
    rhs::Expression #= The expression =#
    ty::NFType
    source::DAE.ElementSource
  end
end

function isMultiLine(stmt::Statement)::Bool
  local multiLine::Bool
  multiLine = begin
    @match stmt begin
      ALG_FOR(__) => begin
        true
      end
      ALG_IF(__) => begin
        true
      end
      ALG_WHEN(__) => begin
        true
      end
      ALG_WHILE(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return multiLine
end

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
    @assign multi_line = isMultiLine(stmt)
    if first
      @assign first = false
    elseif prev_multi_line || multi_line
      @assign s = IOStream_M.append(s, "\\n")
    end
    @assign prev_multi_line = multi_line
    @assign s = toStream(stmt, indent, s)
    @assign s = IOStream_M.append(s, ";\\n")
  end
  #=  Improve human parsability by separating statements that spans multiple
  =#
  #=  lines (like if-statements) with newlines.
  =#
  return s
end

function toStream(stmt::Statement, indent::String, s)

  local str::String

  @assign s = IOStream_M.append(s, indent)
  @assign s = begin
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

function toStringList(stmtl::List{<:Statement}, indent::String = "")::String
  local str::String
  local s
  s = IOStream.create(getInstanceName(), IOStream.IOStreamType.LIST())
  s = toStreamList(stmtl, indent, s)
  str = IOStream.string(s)
  IOStream.delete(s)
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

function foldExp(stmt::Statement, func::FoldFunc, arg::ArgT) where {ArgT}
  () = begin
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
        arg = func(stmt.lhs, arg)
        arg = func(stmt.rhs, arg)
        ()
      end

      ALG_FOR(__) => begin
        arg = foldExpList(stmt.body, func, arg)
        if isSome(stmt.range)
          arg = func(Util.getOption(stmt.range), arg)
        end
        ()
      end

      ALG_IF(__) => begin
        for b in stmt.branches
          arg = func(Util.tuple21(b), arg)
          arg = foldExpList(Util.tuple22(b), func, arg)
        end
        ()
      end

      ALG_WHEN(__) => begin
        for b in stmt.branches
          arg = func(Util.tuple21(b), arg)
          arg = foldExpList(Util.tuple22(b), func, arg)
        end
        ()
      end

      ALG_ASSERT(__) => begin
        arg = func(stmt.condition, arg)
        arg = func(stmt.message, arg)
        arg = func(stmt.level, arg)
        ()
      end

      ALG_TERMINATE(__) => begin
        arg = func(stmt.message, arg)
        ()
      end

      ALG_NORETCALL(__) => begin
        arg = func(stmt.exp, arg)
        ()
      end

      ALG_WHILE(__) => begin
        arg = func(stmt.condition, arg)
        arg = foldExpList(stmt.body, func, arg)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return arg
end

function foldExpList(stmt::Vector{Statement}, func::FoldFunc, arg::ArgT) where {ArgT}
  for s in stmt
    arg = foldExp(s, func, arg)
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
        @assign stmt.branches = [
          (func(Util.tuple21(b)), mapExpList(Util.tuple22(b), func)) for b in stmt.branches
            ]
        stmt
      end

      ALG_WHEN(__) => begin
        @assign stmt.branches = [
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

      ALG_NORETCALL(__) => begin
        reuseIfRefEqual(stmt, stmt.exp, func(stmt.exp), e -> ALG_NORETCALL(e, stmt.source))
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
   () = begin
    @match stmt begin
      ALG_FOR(__) => begin
        for (i,s) in enumerate(stmt.body)
          @inbounds stmt.body[i] = map(s, func)
        end
        #@assign stmt.body = Statement[map(s, func) for s in stmt.body]
        ()
      end
      ALG_IF(__) => begin
        @assign stmt.branches = [
          (Util.tuple21(b), [map(s, func) for s in Util.tuple22(b)]) for b in stmt.branches ]
        ()
      end
      ALG_WHEN(__) => begin
        @assign stmt.branches = Statement[
          (Util.tuple21(b), [map(s, func) for s in Util.tuple22(b)])
          for b in stmt.branches
        ]
        ()
      end
      ALG_WHILE(__) => begin
        for (i, s) in enumerate(stmt.body)
          @inbounds stmt.body[i] = map(s, func)
        end
        #@assign stmt.body = Statement[map(s, func) for s in stmt.body]
        ()
      end
      _ => begin
        ()
      end
    end
  end
  stmt = func(stmt)
  return stmt
end

function apply(stmt::Statement, func::ApplyFn)
  () = begin
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
  end
  return func(stmt)
end

function Statement_info(stmt::Statement)::SourceInfo
  local info::SourceInfo = DAE.ElementSource_getInfo(Statement_source(stmt))
  return info
end

function Statement_source(stmt::Statement)::DAE.ElementSource
  local source::DAE.ElementSource
  return stmt.source
end

function makeIf(
  branches::Vector{<:Tuple{<:Expression, Vector{<:Statement}}},
  src::DAE.ElementSource,
)::Statement
  local stmt::Statement
  stmt = ALG_IF(branches, src)
  return stmt
end

function makeAssignment(
  lhs::Expression,
  rhs::Expression,
  ty::M_Type,
  src::DAE.ElementSource,
)::Statement
  local stmt::Statement

  @assign stmt = ALG_ASSIGNMENT(lhs, rhs, ty, src)
  return stmt
end

function updateImplicitVariabilityAlg(alg::Algorithm)
  updateImplicitVariabilityStmts(alg.statements)
end

function updateImplicitVariabilityStmts(stmtl::Vector{Statement}, inWhen::Bool = false)
  for s in stmtl
    updateImplicitVariabilityStmt(s, inWhen)
  end
end

function updateImplicitVariabilityStmt(stmt::Statement, inWhen::Bool)
   () = begin
    @match stmt begin
     ALG_ASSIGNMENT(__)  => begin
        if inWhen
          markImplicitWhenExp(stmt.lhs)
        end
        ()
      end

     ALG_FOR(__)  => begin
        #=  'when' is not allowed in 'for', so we only need to keep going if
        =#
        #=  we're already in a 'when'.
        =#
        if inWhen
          updateImplicitVariabilityStmts(stmt.body, true)
        end
        ()
      end
     ALG_IF(__)  => begin
        #=  'when' is not allowed in 'if', so we only need to keep going if
        =#
        #=  we're already in a 'when.
        =#
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
end

function replaceIteratorList(@nospecialize(stmtl::Vector{Statement}),
                             @nospecialize(iterator::InstNode),
                             @nospecialize(value::Expression))
  return mapExpList(stmtl, (x)->replaceIterator(x, iterator, value))
end

function markStructuralParamsSubs(exp::Expression, dummy::Int) ::Int
  () = begin
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        foldSubscripts(exp.cref, markStructuralParamsSub, 0)
        ()
      end
      _  => begin
        ()
      end
    end
  end
  dummy
end

function instStatement(scodeStmt::SCode.Statement, scope::InstNode, origin::ORIGIN_Type)::Statement
  local statement::Statement
  statement = begin
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
        branches = Tuple{NFExpression, Vector{Statement}}[]
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
        branches = Tuple{NFExpression, Vector{Statement}}[]
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

      SCode.ALG_REINIT(info = info)  => begin
        Error.addSourceMessage(Error.REINIT_NOT_IN_WHEN, nil, info)
        fail()
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
       ALG_RETURN(makeSource(scodeStmt.comment, scodeStmt.info))
      end

      SCode.ALG_BREAK(__)  => begin
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
statement
end

function instAlgorithmSections(algorithmSections::List{<:SCode.AlgorithmSection}, scope::InstNode, origin::ORIGIN_Type)
  local algs::Vector{Algorithm}
  algs = Algorithm[instAlgorithmSection(alg, scope, origin) for alg in algorithmSections]
  algs
end

function instAlgorithmSection(algorithmSection::SCode.AlgorithmSection, scope::InstNode, origin::ORIGIN_Type)::Algorithm
  local alg::Algorithm
  alg = ALGORITHM(instStatements(algorithmSection.statements, scope, origin), DAE.emptyElementSource)
  alg
end

function instStatements(scodeStmtl::List{<:SCode.Statement}, scope::InstNode, origin::ORIGIN_Type)
  local statements::Vector{Statement} = Statement[]
  statements = Statement[instStatement(stmt, scope, origin) for stmt in scodeStmtl]
  return statements
end
