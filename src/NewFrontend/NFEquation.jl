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

@UniontypeDecl Equation_Branch
abstract type Equation_Branch end
abstract type NFEquation end

struct EQUATION_NORETCALL{T0 <: Expression, T1 <: DAE.ElementSource} <: NFEquation
  exp::T0
  source::T1
end

struct EQUATION_REINIT{T0 <: Expression, T1 <: Expression, T2 <: DAE.ElementSource} <: NFEquation
  cref::T0 #= The variable to reinitialize. =#
  reinitExp::T1 #= The new value of the variable. =#
  source::T2
end

struct EQUATION_TERMINATE{T0 <: Expression, T1 <: DAE.ElementSource} <: NFEquation
  message::T0 #= The message to display if the terminate triggers. =#
  source::T1
end

struct EQUATION_ASSERT{T0 <: Expression,
                       T1 <: Expression,
                       T2 <: Expression,
                       T3 <: DAE.ElementSource} <: NFEquation
  condition::T0 #= The assert condition. =#
  message::T1 #= The message to display if the assert fails. =#
  level::T2 #= Error or warning =#
  source::T3
end

struct EQUATION_WHEN{T0 <: DAE.ElementSource} <: NFEquation
  branches::Vector{Equation_Branch}
  source::T0
end

struct EQUATION_RECONFIGURE{T0 <: DAE.ElementSource} <: NFEquation
  variables        ::MetaModelica.List{Absyn.ElementItem}
  whenConditions   ::Vector   #= Instantiated trigger conditions (NFExpression.Expression) =#
  whenConstraints  ::Vector   #= Optional post-conditions, one per whenCondition (Option{Expression}) =#
  prompt           ::Option   #= Instantiated natural-language prompt (Option{Expression}) =#
  initialEquations ::Option   #= Raw Absyn constraint equations checked at recompilation =#
  source           ::T0
end

struct EQUATION_IF{T1 <: DAE.ElementSource} <: NFEquation
  branches::Vector{Equation_Branch}
  source::T1
end

struct EQUATION_FOR{T0 <: InstNode, T1 <:Expression, T2 <: DAE.ElementSource} <: NFEquation
  iterator::T0
  range::Option{T1}
  body::Vector{Equation} #= The body of the for loop. =#
  source::T2
end

struct EQUATION_CONNECT{T0 <: Expression, T1 <: Expression, T2 <: DAE.ElementSource} <: NFEquation
  lhs::T0
  rhs::T1
  source::T2
end

struct EQUATION_ARRAY_EQUALITY{T0 <: Expression,
                               T1 <: Expression,
                               T2 <: NFType,
                               T3 <: DAE.ElementSource} <: NFEquation
  lhs::T0
  rhs::T1
  ty::T2
  source::T3
end

struct EQUATION_CREF_EQUALITY <: NFEquation
  lhs::ComponentRef
  rhs::ComponentRef
  source::DAE.ElementSource
end

struct EQUATION_EQUALITY <: NFEquation
  lhs::Expression #= The left hand side expression. =#
  rhs::Expression #= The right hand side expression. =#
  ty::NFType
  source::DAE.ElementSource
end

struct EQUATION_INVALID_BRANCH <: Equation_Branch
  branch::Equation_Branch
  errors::Vector
end

struct EQUATION_BRANCH <: Equation_Branch
  condition::Expression
  conditionVar::Int
  body::Vector{Equation}
end


@nospecializeinfer function isMultiLine(@nospecialize(eq::Equation))::Bool
  local singleLine::Bool
   singleLine = begin
    @match eq begin
      EQUATION_FOR(__) => begin
        true
      end
      EQUATION_IF(__) => begin
        true
      end
      EQUATION_WHEN(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return singleLine
end

function toFlatString(eq::Equation; ident = "")
  local s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toFlatStream(eq, ident, s)
  return IOStream_M.string(s)
end

function toFlatStreamList(
  eql::Vector{<:Equation},
  indent::String,
  s)
  local prev_multi_line::Bool = false
  local multi_line::Bool
  local first::Bool = true
  for eq in eql
    #=
    Improve human parsability by separating statements that spans multiple
    lines (like if-equations) with newlines.
    =#
     multi_line = isMultiLine(eq)
    if first
       first = false
    elseif prev_multi_line || multi_line
       s = IOStream_M.append(s, "\\n")
    end
     prev_multi_line = multi_line
     s = toFlatStream(eq, indent, s)
     s = IOStream_M.append(s, ";\\n")
  end
  return s
end

@nospecializeinfer function toFlatStream(@nospecialize(eq::Equation), indent::String, s)
   s = IOStream_M.append(s, indent)
   s = begin
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        s = IOStream_M.append(s, toFlatString(eq.lhs))
        s = IOStream_M.append(s, " = /*Equality*/")
        s = IOStream_M.append(s, toFlatString(eq.rhs))
        s
      end

      EQUATION_CREF_EQUALITY(__) => begin
         s = IOStream_M.append(s, toFlatString(eq.lhs))
         s = IOStream_M.append(s, " = /* Cref Equality between $(typeof(eq.lhs.ty)) and $(typeof(eq.rhs.ty))*/")
         s = IOStream_M.append(s, toFlatString(eq.rhs))
        s
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
         s = IOStream_M.append(s, toFlatString(eq.lhs))
         s = IOStream_M.append(s, " = /* Array Equality */")
         s = IOStream_M.append(s, toFlatString(eq.rhs))
        s
      end

      EQUATION_CONNECT(__) => begin
         s = IOStream_M.append(s, "connect(")
         s = IOStream_M.append(s, toFlatString(eq.lhs))
         s = IOStream_M.append(s, " , ")
         s = IOStream_M.append(s, toFlatString(eq.rhs))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_FOR(__) => begin
         s = IOStream_M.append(s, "for ")
         s = IOStream_M.append(s, toFlatString(eq.iterator))
        if isSome(eq.range)
           s = IOStream_M.append(s, " in ")
           s = IOStream_M.append(
            s,
            toFlatString(Util.getOption(eq.range)),
          )
        end
         s = IOStream_M.append(s, " loop\\n")
         s = toFlatStreamList(eq.body, indent + "  ", s)
         s = IOStream_M.append(s, indent)
         s = IOStream_M.append(s, "end for")
        s
      end

      EQUATION_IF(__) => begin
        s = IOStream_M.append(s, "if ")
        s = toFlatStream(eq.branches[1], indent, s)
        for b in eq.branches[2:end]
          s = IOStream_M.append(s, indent)
          s = IOStream_M.append(s, "elseif ")
          s = toFlatStream(b, indent, s)
        end
        s = IOStream_M.append(s, indent)
        s = IOStream_M.append(s, "end if")
        s
      end

      EQUATION_WHEN(__) => begin
         s = IOStream_M.append(s, "when ")
         s = toFlatStream(eq.branches[1], indent, s)
        for b in eq.branches[2:end]
           s = IOStream_M.append(s, indent)
           s = IOStream_M.append(s, "elsewhen ")
           s = toFlatStream(b, indent, s)
        end
         s = IOStream_M.append(s, indent)
         s = IOStream_M.append(s, "end when")
        s
      end

      EQUATION_ASSERT(__) => begin
         s = IOStream_M.append(s, "assert(")
         s = IOStream_M.append(s, toFlatString(eq.condition))
         s = IOStream_M.append(s, ", ")
         s = IOStream_M.append(s, toFlatString(eq.message))
         s = IOStream_M.append(s, ", ")
         s = IOStream_M.append(s, toFlatString(eq.level))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_TERMINATE(__) => begin
        s = IOStream_M.append(s, "terminate(")
        s = IOStream_M.append(s, toFlatString(eq.message))
        s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_REINIT(__) => begin
        s = IOStream_M.append(s, "reinit(")
        s = IOStream_M.append(s, toFlatString(eq.cref))
        s = IOStream_M.append(s, ", ")
        s = IOStream_M.append(s, toFlatString(eq.reinitExp))
        s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_NORETCALL(__) => begin
        IOStream_M.append(s, toFlatString(eq.exp))
      end

      _ => begin
        IOStream_M.append(s, "#UNKNOWN EQUATION#")
      end
    end
  end
  return s
end

function toStreamList(
  eql::Vector{Equation},
  indent::String,
  s,
)
  local prev_multi_line::Bool = false
  local multi_line::Bool
  local first::Bool = true
  for eq in eql
    @assign multi_line = isMultiLine(eq)
    if first
      @assign first = false
    elseif prev_multi_line || multi_line
      @assign s = IOStream_M.append(s, "\\n")
    end
    @assign prev_multi_line = multi_line
    @assign s = toStream(eq, indent, s)
    @assign s = IOStream_M.append(s, ";\\n")
  end
  return s
end

@nospecializeinfer function toStream(@nospecialize(eq::Equation), indent::String, s)
   s = IOStream_M.append(s, indent)
   s = begin
    @match eq begin
      EQUATION_EQUALITY(__) => begin
         s = IOStream_M.append(s, toString(eq.lhs))
         s = IOStream_M.append(s, " = ")
         s = IOStream_M.append(s, toString(eq.rhs))
        s
      end

      EQUATION_CREF_EQUALITY(__) => begin
         s = IOStream_M.append(s, toString(eq.lhs))
         s = IOStream_M.append(s, " = ")
         s = IOStream_M.append(s, toString(eq.rhs))
        s
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
         s = IOStream_M.append(s, toString(eq.lhs))
         s = IOStream_M.append(s, " = ")
         s = IOStream_M.append(s, toString(eq.rhs))
        s
      end

      EQUATION_CONNECT(__) => begin
         s = IOStream_M.append(s, "connect(")
         s = IOStream_M.append(s, toString(eq.lhs))
         s = IOStream_M.append(s, " , ")
         s = IOStream_M.append(s, toString(eq.rhs))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_FOR(__) => begin
         s = IOStream_M.append(s, "for ")
         s = IOStream_M.append(s, name(eq.iterator))
        if isSome(eq.range)
           s = IOStream_M.append(s, " in ")
           s = IOStream_M.append(
            s,
            toString(Util.getOption(eq.range)),
          )
        end
         s = IOStream_M.append(s, " loop\\n")
         s = toStreamList(eq.body, indent + "  ", s)
         s = IOStream_M.append(s, indent)
         s = IOStream_M.append(s, "end for")
        s
      end

      EQUATION_IF(__) => begin
         s = IOStream_M.append(s, "if ")
         s = toStream(listHead(arrayList(eq.branches)), indent, s)
        for b in listRest(arrayList(eq.branches))
           s = IOStream_M.append(s, indent)
           s = IOStream_M.append(s, "elseif ")
           s = toStream(b, indent, s)
        end
         s = IOStream_M.append(s, indent)
         s = IOStream_M.append(s, "end if")
        s
      end

      EQUATION_WHEN(__) => begin
         s = IOStream_M.append(s, "when ")
         s = toStream(listHead(arrayList(eq.branches)), indent, s)
        for b in listRest(arrayList(eq.branches))
           s = IOStream_M.append(s, indent)
           s = IOStream_M.append(s, "elsewhen ")
           s = toStream(b, indent, s)
        end
         s = IOStream_M.append(s, indent)
         s = IOStream_M.append(s, "end when")
        s
      end

      EQUATION_RECONFIGURE(__) => begin
        s = IOStream_M.append(s, "reconfigure\n")
        for item in eq.variables
          @match Absyn.ELEMENTITEM(element = Absyn.ELEMENT(specification = Absyn.COMPONENTS(typeSpec = ts, components = comps))) = item
          typeName = AbsynUtil.typeSpecPathString(ts)
          @match Absyn.COMPONENTITEM(component = Absyn.COMPONENT(name = varName)) <| _ = comps
          s = IOStream_M.append(s, indent * "  " * typeName * " " * varName * ";\n")
        end
        for (cond, cons) in zip(eq.whenConditions, eq.whenConstraints)
          condStr = toString(cond)
          if isSome(cons)
            @match SOME(consExp) = cons
            s = IOStream_M.append(s, indent * "  when " * condStr * " => " * toString(consExp) * ";\n")
          else
            s = IOStream_M.append(s, indent * "  when " * condStr * ";\n")
          end
        end
        if isSome(eq.prompt)
          @match SOME(promptExp) = eq.prompt
          s = IOStream_M.append(s, indent * "  prompt(" * toString(promptExp) * ");\n")
        end
        s = IOStream_M.append(s, indent * "end reconfigure")
        s
      end

      EQUATION_ASSERT(__) => begin
         s = IOStream_M.append(s, "assert(")
         s = IOStream_M.append(s, toString(eq.condition))
         s = IOStream_M.append(s, ", ")
         s = IOStream_M.append(s, toString(eq.message))
         s = IOStream_M.append(s, ", ")
         s = IOStream_M.append(s, toString(eq.level))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_TERMINATE(__) => begin
         s = IOStream_M.append(s, "terminate(")
         s = IOStream_M.append(s, toString(eq.message))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_REINIT(__) => begin
         s = IOStream_M.append(s, "reinit(")
         s = IOStream_M.append(s, toString(eq.cref))
         s = IOStream_M.append(s, ", ")
         s = IOStream_M.append(s, toString(eq.reinitExp))
         s = IOStream_M.append(s, ")")
        s
      end

      EQUATION_NORETCALL(__) => begin
        IOStream_M.append(s, toString(eq.exp))
      end

      _ => begin
        IOStream_M.append(s, "#UNKNOWN EQUATION#")
      end
    end
  end
  return s
end

function toStringList(eql::List{<:Equation}, indent::String = "")::String
  local str::String
  local s
   s = IOStream_M.create(getInstanceName(), IOStream_M.IOStream_MType.LIST())
   s = toStreamList(eql, indent, s)
   str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

@nospecializeinfer function toString(@nospecialize(eq::Equation), indent::String = "")::String
  local str::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toStream(eq, indent, s)
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function replaceIteratorList(eql::Vector{Equation}, iterator::InstNode, @nospecialize(value::Expression))::Vector{Equation}
  mapExpList(eql, @closure (expArg) -> replaceIterator(expArg, iterator, value))
end

function isConnect(@nospecialize(eq::Equation))::Bool
  local isConnect::Bool
  isConnect = begin
    @match eq begin
      CONNECT(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isConnect
end

function containsList(eql::Vector{Equation}, func::PredFn)::Bool
  local res::Bool = false
  for eq in eql
    if contains(eq, func)
      res = true
      return res
    end
  end
  return res
end

@nospecializeinfer function contains(@nospecialize(eq::Equation), func::PredFn)::Bool
  local res::Bool
  if func(eq)
    res = true
    return res
  end
  res = begin
    @match eq begin
      EQUATION_FOR(__) => begin
        containsList(eq.body, func)
      end
      EQUATION_IF(__) => begin
        for b in eq.branches
          () = begin
            @match b begin
              EQUATION_BRANCH(__) => begin
                if containsList(b.body, func)
                  res = true
                  return res
                end
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        false
      end
      EQUATION_WHEN(__) => begin
        for b in eq.branches
          () = begin
            @match b begin
              EQUATION_BRANCH(__) => begin
                if containsList(b.body, func)
                  res = true
                  return res
                end
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        false
      end

      _ => begin
        false
      end
    end
  end
  return res
end

@nospecializeinfer function foldExp(@nospecialize(eq::Equation), func::FoldFunc, arg::ArgT) where {ArgT}
   () = begin
    @match eq begin
      EQUATION_EQUALITY(__) => begin
         arg = func(eq.lhs, arg)
         arg = func(eq.rhs, arg)
        ()
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
         arg = func(eq.lhs, arg)
         arg = func(eq.rhs, arg)
        ()
      end

      EQUATION_CONNECT(__) => begin
         arg = func(eq.lhs, arg)
         arg = func(eq.rhs, arg)
        ()
      end

      EQUATION_FOR(__) => begin
         arg = foldExpList(eq.body, func, arg)
        if isSome(eq.range)
           arg = func(Util.getOption(eq.range), arg)
        end
        ()
      end

      EQUATION_IF(__) => begin
        for b in eq.branches
           () = begin
            @match b begin
              EQUATION_BRANCH(__) => begin
                 arg = func(b.condition, arg)
                 arg = foldExpList(b.body, func, arg)
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        ()
      end

      EQUATION_WHEN(__) => begin
        for b in eq.branches
          () = begin
            @match b begin
              EQUATION_BRANCH(__) => begin
                arg = func(b.condition, arg)
                arg = foldExpList(b.body, func, arg)
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        ()
      end

      EQUATION_ASSERT(__) => begin
        arg = func(eq.condition, arg)
        arg = func(eq.message, arg)
        arg = func(eq.level, arg)
        ()
      end

      EQUATION_TERMINATE(__) => begin
        arg = func(eq.message, arg)
        ()
      end

      EQUATION_REINIT(__) => begin
        arg = func(eq.cref, arg)
        arg = func(eq.reinitExp, arg)
        ()
      end

      EQUATION_NORETCALL(__) => begin
        arg = func(eq.exp, arg)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return arg
end

function foldExpList(eq::Vector{Equation}, func::FoldFunc, arg::ArgT) where {ArgT}
  for e in eq
    arg = foldExp(e, func, arg)
  end
  return arg
end

function mapExpBranch(branch::Equation_Branch, func::MapExpFn)::Equation_Branch
  local cond::Expression
  local eql::Vector{Equation}
  branch = begin
    @match branch begin
      EQUATION_BRANCH(__) => begin
        cond = func(branch.condition)
        eql = Equation[mapExp(e, func) for e in branch.body]
        EQUATION_BRANCH(cond, branch.conditionVar, eql)
      end
      _ => begin
        branch
      end
    end
  end
  return branch
end

@nospecialized function mapExp(eq::Equation, func::MapExpFn)
  eq = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        e1 = func(eq.lhs)
        e2 = func(eq.rhs)
        res = if referenceEq(e1, eq.lhs) && referenceEq(e2, eq.rhs)
          eq
        else
          EQUATION_EQUALITY(e1, e2, eq.ty, eq.source)
        end
        res
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
        e1 = func(eq.lhs)
        e2 = func(eq.rhs)
        if referenceEq(e1, eq.lhs) && referenceEq(e2, eq.rhs)
          eq
        else
          EQUATION_ARRAY_EQUALITY(e1, e2, eq.ty, eq.source)
        end
      end

       EQUATION_CONNECT(__) => begin
         e1 = func(eq.lhs)
         e2 = func(eq.rhs)
        if referenceEq(e1, eq.lhs) && referenceEq(e2, eq.rhs)
          eq
        else
           EQUATION_CONNECT(e1, e2, eq.source)
        end
      end

      EQUATION_FOR(__) => begin
        #= NOTE needs to create a new element =#
         eqBody = Equation[mapExp(e, func) for e in eq.body]
         eqRange = Util.applyOption(eq.range, func)
         EQUATION_FOR(eq.iterator, eqRange, eqBody, eq.source)
      end

      EQUATION_IF(__) => begin
        #= We need to create a new instance here for the logic to work=#
        @assign eq.branches = Equation_Branch[mapExpBranch(b, func) for b in eq.branches]
        eq
      end

      EQUATION_WHEN(__) => begin
        @assign eq.branches = Equation_Branch[mapExpBranch(b, func) for b in eq.branches]
        eq
      end

      EQUATION_ASSERT(__) => begin
        e1 = func(eq.condition)
        e2 = func(eq.message)
        e3 = func(eq.level)
        if referenceEq(e1, eq.condition) &&
          referenceEq(e2, eq.message) &&
          referenceEq(e3, eq.level)
          eq
        else
          EQUATION_ASSERT(e1, e2, e3, eq.source)
        end
      end

      EQUATION_TERMINATE(__) => begin
        e1 = func(eq.message)
         if referenceEq(e1, eq.message)
           eq
        else
           EQUATION_TERMINATE(e1, eq.source)
         end
      end

       EQUATION_REINIT(__) => begin
          e1 = func(eq.cref)
          e2 = func(eq.reinitExp)
         if referenceEq(e1, eq.cref) && referenceEq(e2, eq.reinitExp)
           eq
         else
           EQUATION_REINIT(e1, e2, eq.source)
        end
      end

       EQUATION_NORETCALL(__) => begin
         e1 = func(eq.exp)
        if referenceEq(e1, eq.exp)
          eq
        else
          EQUATION_NORETCALL(e1, eq.source)
        end
      end

      _ => begin
        eq
      end
    end
  end
  return eq
end

"""
  mapExpList with atleast one element
"""
function mapExpList!(eql::Vector{Equation}, func::MapExpFn)
  #local eqV = Equation[mapExp(eq, func) for eq in eql]
  for (i, eq) in enumerate(eql)
    eql[i] = mapExp(eq, func)
  end
  return eql
end

function mapExpList(eql::Vector{Equation}, func::MapExpFn)
  local eqV = Equation[mapExp(eq, func) for eq in eql]
  return eqV
end


"""
  Map a list of equations with a least one element
"""
function mapList!(eql::Vector{Equation}, func::Function)
  #eqs = Equation[map(eq, func) for eq in eql]
  for (i, eq) in enumerate(eql)
    eql[i] = map(eq, func)
  end
  return eql
end


function mapList(eql::Vector{Equation}, func::Function)
  eqs = Equation[map(eq, func) for eq in eql]
end


"""
  An empty list results in nil
"""
function mapExpList(eql::Nil, func::MapExpFn)
  return nil
end

"""
```
map(@nospecialize(eq::Equation), func::MapFn)
```
Applies the function `func` to `eq`
"""
@nospecializeinfer function map(@nospecialize(eq::Equation), func::MapFn)
  function f(b::Equation_Branch)
    @match b begin
      EQUATION_BRANCH(__) => begin
        eqBody = Equation[map(e, func) for e in b.body]
        EQUATION_BRANCH(b.condition, b.conditionVar, eqBody)
        b
      end
      _ => b
    end
  end
  eq = @match eq begin
    EQUATION_FOR(__) => begin
      eqBody = Equation[map(e, func) for e in eq.body]
      EQUATION_FOR(eq.iterator, eq.range, eqBody, eq.source)
    end
    EQUATION_IF(__) => begin
      eqBranches = Equation_Branch[res =  f(b) for b in eq.branches]
      EQUATION_IF(eqBranches, eq.source)
    end
    EQUATION_WHEN(__) => begin
      eqBranches = Equation_Branch[
        if b isa EQUATION_BRANCH
          eqBody = Equation[map(e, func) for e in b.body];
          EQUATION_BRANCH(b.condition, b.conditionVar, eqBody)
        else
          b
        end for b in eq.branches]
      EQUATION_WHEN(eqBranches, eq.source)
    end
    _ => begin
      eq
    end
  end
  eq = func(eq)
  return eq
end


@nospecializeinfer function apply(@nospecialize(eq::Equation), func::ApplyFn)
   () = begin
    @match eq begin
      FOR(__) => begin
        for e in eq.body
          apply(e, func)
        end
        ()
      end

      IF(__) => begin
        for b in eq.branches
           () = begin
            @match b begin
              BRANCH(__) => begin
                for e in b.body
                  apply(e, func)
                end
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        ()
      end

      WHEN(__) => begin
        for b in eq.branches
           () = begin
            @match b begin
              BRANCH(__) => begin
                for e in b.body
                  apply(e, func)
                end
                ()
              end

              _ => begin
                ()
              end
            end
          end
        end
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return func(eq)
end

function applyList(eql::Vector{Equation}, func::ApplyFn)
  return for eq in eql
    apply(eq, func)
  end
end

@nospecializeinfer function Equation_info(@nospecialize(eq::Equation))::SourceInfo
  local info::SourceInfo = sourceInfo() #DAE.ElementSource_getInfo(source(eq))
  return info
end

@nospecializeinfer function source(@nospecialize(eq::Equation))::DAE.ElementSource
  local sourceVar::DAE.ElementSource
   sourceVar = begin
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        eq.source
      end
      EQUATION_CREF_EQUALITY(__) => begin
        eq.source
      end
      EQUATION_ARRAY_EQUALITY(__) => begin
        eq.source
      end
      EQUATION_CONNECT(__) => begin
        eq.source
      end
      EQUATION_FOR(__) => begin
        eq.source
      end
      EQUATION_IF(__) => begin
        eq.source
      end
      EQUATION_WHEN(__) => begin
        eq.source
      end
      EQUATION_ASSERT(__) => begin
        eq.source
      end
      EQUATION_TERMINATE(__) => begin
        eq.source
      end
      EQUATION_REINIT(__) => begin
        eq.source
      end
      EQUATION_NORETCALL(__) => begin
        eq.source
      end
    end
  end
  return sourceVar
end

function makeIf(branches::Vector{Equation_Branch}, src::DAE.ElementSource)
  local eq::Equation
   eq = EQUATION_IF(branches, src)
  return eq
end

function makeBranch(
  @nospecialize(condition::Expression),
  body::Vector{Equation},
  condVar = Variability.CONTINUOUS,
)::Equation_Branch
  local branch::Equation_Branch
   branch = EQUATION_BRANCH(condition, condVar, body)
  return branch
end

function makeEquality(
  lhs::Expression,
  rhs::Expression,
  ty::M_Type,
  src::DAE.SOURCE,
)::Equation
  local eq::Equation
   eq = EQUATION_EQUALITY(lhs, rhs, ty, src)
  return eq
end

function triggerErrors(branch::Equation_Branch)
  return  () = begin
    @match branch begin
      EQUATION_INVALID_BRANCH(__) => begin
        #Error.addTotalMessages(branch.errors) TODO
        @error "Invalid branch detected. Branch was: " * toString(branch)
        fail()
      end
      _ => begin
        ()
      end
    end
  end
end

function toFlatStream(branch::Equation_Branch,
  indent::String,
  s::IOStream_M.IOSTREAM,
)
  s = begin
    @match branch begin
      EQUATION_BRANCH(__) => begin
        s =
          IOStream_M.append(s, toFlatString(branch.condition))
        s = IOStream_M.append(s, " then\\n")
        s = toFlatStreamList(branch.body, indent + "  ", s)
        s
      end
      EQUATION_INVALID_BRANCH(__) => begin
        toFlatStream(branch.branch, indent, s)
      end
    end
  end
  return s
end

function toStream(branch::Equation_Branch, indent::String, s)
   s = begin
    @match branch begin
      EQUATION_BRANCH(__) => begin
        s = IOStream_M.append(s, toString(branch.condition))
        s = IOStream_M.append(s, " then\\n")
        s = toStreamList(branch.body, indent + "  ", s)
        s
      end
      EQUATION_INVALID_BRANCH(__) => begin
        toStream(branch.branch, indent, s)
      end
    end
  end
  return s
end

function toString(branch::Equation_Branch, indent::String = "")::String
  local s
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = toStream(branch, indent, s)
  local str = IOStream_M.string(s)
  IOStream_M.delete(s)
  return str
end

function makeCrefEquality(lhsCref::ComponentRef,
                          rhsCref::ComponentRef,
                          scope::InstNode,
                          src::DAE.SOURCE)
  local e1 = fromCref(lhsCref)
  local e2 = fromCref(rhsCref)
  return makeEquality(e1, e2, typeOf(e1), src)
end
