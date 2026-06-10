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

"""
```
struct FLAT_MODEL <: FlatModel
  name::String
  variables::Vector{Variable}
  equations::Vector{Equation}
  initialEquations::Vector{Equation}
  algorithms::Vector{Algorithm}
  initialAlgorithms::Vector{Algorithm}
  #= VSS Modelica extension =#
  structuralSubmodels::List{FlatModel}
  scodeProgram::Option{SCode.CLASS}
  #= Dynamically Overconstrained connectors =#
  DOCC_equations::List{Equation}
  #= Contains the set of unresolved connect equations =#
  unresolvedConnectEquations::List{Equation}
  active_DOCC_Equations::Vector{Bool}
  #= End VSS Modelica extension =#
  comment::Option{SCode.Comment}
end
```

  The flat representation of a Modelica Model.
"""
struct FLAT_MODEL <: FlatModel
  name::String
  variables::Vector{Variable}
  equations::Vector{Equation}
  initialEquations::Vector{Equation}
  algorithms::Vector{Algorithm}
  initialAlgorithms::Vector{Algorithm}
  #= VSS Modelica extension =#
  structuralSubmodels::List{FlatModel}
  scodeProgram::Option{SCode.CLASS}
  #= Dynamically Overconstrained connectors =#
  DOCC_equations::List{Equation}
  #= Contains the set of unresolved connect equations =#
  unresolvedConnectEquations::List{Equation}
  active_DOCC_Equations::Vector{Bool}
  #= End VSS Modelica extension =#
  comment::Option{SCode.Comment}
end

module TypeTreeImpl
using MetaModelica
using ExportAll
import ..Absyn.Path
import ..AbsynUtil
import ..BaseAvlTree
import ..Frontend.M_Type
import ..Type
import Absyn
import ..toString

const Key = Absyn.Path
const Value = M_Type

include("../Util/baseAvlTreeCode.jl")

function keyStr(k)
  return AbsynUtil.pathString(k)
end

valueStr = (vs) -> begin
  return toString(vs)
end

addConflictDefault = addConflictReplace
#= John 2023-04-03:
  Default(Julia) string compare does not give the right result.
  MetaModelica string comp is used instead.
=#
keyCompare = (inKey1::Key, inKey2::Key) -> begin
  return AbsynUtil.pathCompareNoQual(inKey1, inKey2)
end

@exportAll()
end

const TypeTree = TypeTreeImpl.Tree

"""
Not currently in use.
Added by me to treat parameters in a slightly other way
"""
function reconstructRecordInstanceForParameterRecord(
  recordName::ComponentRef,
  variables::List{<:Variable},
  fieldCount::Int
  )
  local recordVar::Variable
  local record_node::InstNode
  local record_comp::Component
  local record_ty::M_Type
  record_node = node(recordName)
  record_comp = component(record_node)
  record_ty = nodeType(recordName)
  record_binding = EMPTY_BINDING
  recordVar = VARIABLE(
    recordName,
    record_ty,
    record_binding,
    visibility(record_node),
    getAttributes(record_comp),
    Tuple{String, Binding}[],
    comment(record_comp),
    InstNode_info(record_node),
  )
  return recordVar
end

function reconstructRecordInstance(
  recordName::ComponentRef,
  variables::List{<:Variable},
  )
  local recordVar::Variable
  local record_node::InstNode
  local record_comp::Component
  local record_ty::M_Type
  local field_exps::List{Expression}
  local record_exp::Expression
  local record_binding::Binding
  record_node = node(recordName)
  record_comp = component(record_node)
  record_ty = nodeType(recordName)
  #= For array-of-record elements, use element type. =#
  if isArray(record_ty)
    record_ty = arrayElementType(record_ty)
  end
  field_exps = nil
  for v in variables
    #= Handling regular variables =#
    if hasExp(v.binding)
      field_exps = _cons(getExp(v.binding), field_exps)
    else
      field_exps = nil
      break
    end
  end
  if listEmpty(field_exps)
    record_binding = EMPTY_BINDING
  else
    field_exps = listReverseInPlace(field_exps)
    record_exp = makeRecord(
      scopePath(classScope(record_node)),
      record_ty,
      listArray(field_exps),
    )
    record_binding =
      FLAT_BINDING(record_exp, variability(record_comp))
  end
  recordVar = VARIABLE(
    recordName,
    record_ty,
    record_binding,
    visibility(record_node),
    getAttributes(record_comp),
    Tuple{String, Binding}[],
    comment(record_comp),
    InstNode_info(record_node),
  )
  return recordVar
end

function reconstructRecordInstances(variables::Vector{Variable})
  local outVariables::Vector{Variable} = Variable[]
  local bindingEquations::Vector{Equation} = Equation[]
  local rest_vars::List{Variable} = arrayList(variables)
  local record_vars::List{Variable}
  local var::Variable
  local parent_cr::ComponentRef
  local parent_ty::M_Type
  while !listEmpty(rest_vars)
    @match _cons(var, rest_vars) = rest_vars
    parent_cr = rest(var.name)
    if !isEmpty(parent_cr)
      parent_ty = nodeType(parent_cr)
      #= For array-of-record elements (e.g. states[1]), the node type is the
         array type. Check the element type for records. =#
      local _rec_ty = isArray(parent_ty) ? arrayElementType(parent_ty) : parent_ty
      if isRecord(_rec_ty)
        #= `reconstructRecordInstance` requires `parent_cr.node` to be a
           `COMPONENT_NODE`. Some record references resolve via the class
           lookup table (e.g. record constants referenced through a class
           path), where `node(parent_cr)` yields a `CLASS_NODE`. Skip
           reconstruction in that case and fall through to per-field emission;
           the dump remains correct, just unbatched. =#
        local _parentNode = node(parent_cr)
        if !(_parentNode isa COMPONENT_NODE)
          outVariables = push!(outVariables, var)
          continue
        end
        #= Count consecutive siblings sharing the same parent CREF.
           After scalarization, array record fields expand to more variables
           than the raw field count from the record type definition. =#
        local sibling_count = 0
        local scan = rest_vars
        while !listEmpty(scan)
          local next_var = listHead(scan)
          local next_parent = rest(next_var.name)
          if isEmpty(next_parent) || !isEqual(next_parent, parent_cr)
            break
          end
          sibling_count += 1
          scan = listRest(scan)
        end
        (record_vars, rest_vars) = ListUtil.split(rest_vars, sibling_count)
        record_vars = _cons(var, record_vars)
        var = reconstructRecordInstance(parent_cr, record_vars)
        #= When not all fields have bindings, the record gets EMPTY_BINDING,
           losing existing field bindings. Convert those to explicit equations. =#
        if !isBound(var.binding)
          for fv in record_vars
            if hasExp(fv.binding)
              local _lhs = CREF_EXPRESSION(fv.ty, fv.name)
              local _rhs = getExp(fv.binding)
              push!(bindingEquations, EQUATION_EQUALITY(_lhs, _rhs, fv.ty, DAE.emptyElementSource))
            end
          end
        end
      end
    end
    outVariables = push!(outVariables, var)
  end
  return (outVariables, bindingEquations)
end

function collectSubscriptedFlatType(
  exp::Expression,
  subs::List{<:Subscript},
  subscriptedTy::M_Type,
  types::TypeTree,
)::TypeTree
  local exp_ty::M_Type
  local sub_tyl::List{M_Type}
  local dims::List{Dimension}
  local strl::List{String}
  local name::String
  exp_ty = typeOf(exp)
  dims = ListUtil.firstN(arrayDims(exp_ty), listLength(subs))
  sub_tyl = list(subscriptType(d) for d in dims)
  name = subscriptedTypeName(exp_ty, sub_tyl)
  types = TypeTreeImpl.add(
    types,
    Absyn.IDENT(name),
    TYPE_SUBSCRIPTED(name, exp_ty, sub_tyl, subscriptedTy),
  )
  return types
end

function collectComponentFlatTypes(componentArg::InstNode, types::TypeTree)::TypeTree
  local comp::Component
  comp = component(componentArg)
  types = collectFlatType(getType(comp), types)
  types = collectBindingFlatTypes(getBinding(comp), types)
  return types
end

function collectFunctionFlatTypes(fn::M_Function, types::TypeTree)::TypeTree
  local body::Vector{Statement}
  types = foldComponents(
    classTree(getClass(fn.node)),
    collectComponentFlatTypes,
    types,
  )
  #= External functions does not have a function body. =#
  body = if ! isExternal(fn)
    getBody(fn)
  else
    nil
  end
  types = ArrayUtil.fold(body, collectStatementFlatTypes, types)
  return types
end

function collectExpFlatTypes_traverse(exp::Expression, types::TypeTree)::TypeTree
  @assign types = begin
    @match exp begin
      SUBSCRIPTED_EXP_EXPRESSION(__) => begin
        @assign types = collectSubscriptedFlatType(exp.exp, exp.subscripts, exp.ty, types)
        types
      end

      _ => begin
        collectFlatType(typeOf(exp), types)
      end
    end
  end
  return types
end

function collectExpFlatTypes(exp::Expression, types::TypeTree)::TypeTree

  @assign types = fold(exp, collectExpFlatTypes_traverse, types)
  return types
end

function collectStmtBranchFlatTypes(branch::Tuple{<:Expression, Vector{<:Statement}},
                                    types::TypeTree)
  types = collectExpFlatTypes(Util.tuple21(branch), types)
  types = ArrayUtil.fold(Util.tuple22(branch), collectStatementFlatTypes, types)
  return types
end

function collectStatementFlatTypes(stmt::Statement, types::TypeTree)::TypeTree
   () = begin
    @match stmt begin
      ALG_ASSIGNMENT(__) => begin
         types = collectExpFlatTypes(stmt.lhs, types)
         types = collectExpFlatTypes(stmt.rhs, types)
         types = collectFlatType(stmt.ty, types)
        ()
      end
      ALG_FOR(__) => begin
         types = ArrayUtil.fold(stmt.body, collectStatementFlatTypes, types)
         types = collectExpFlatTypes(Util.getOption(stmt.range), types)
        ()
      end

      ALG_IF(__) => begin
         types = ArrayUtil.fold(stmt.branches, collectStmtBranchFlatTypes, types)
        ()
      end

      ALG_WHEN(__) => begin
         types = ArrayUtil.fold(stmt.branches, collectStmtBranchFlatTypes, types)
        ()
      end

      ALG_ASSERT(__) => begin
         types = collectExpFlatTypes(stmt.condition, types)
         types = collectExpFlatTypes(stmt.message, types)
         types = collectExpFlatTypes(stmt.level, types)
        ()
      end

      ALG_TERMINATE(__) => begin
         types = collectExpFlatTypes(stmt.message, types)
        ()
      end

      ALG_NORETCALL(__) => begin
         types = collectExpFlatTypes(stmt.exp, types)
        ()
      end

      ALG_WHILE(__) => begin
         types = collectExpFlatTypes(stmt.condition, types)
         types = ArrayUtil.fold(stmt.body, collectStatementFlatTypes, types)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return types
end

function collectAlgorithmFlatTypes(alg::Algorithm, types::TypeTree)::TypeTree

  @assign types = ArrayUtil.fold(alg.statements, collectStatementFlatTypes, types)
  return types
end

function collectEqBranchFlatTypes(
  branch::Equation_Branch,
  types::TypeTree,
)::TypeTree
  () = begin
    @match branch begin
      EQUATION_BRANCH(__) => begin
        types = collectExpFlatTypes(branch.condition, types)
        types = ArrayUtil.fold(branch.body, collectEquationFlatTypes, types)
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return types
end

function collectEquationFlatTypes(eq::Equation, types::TypeTree)::TypeTree

  () = begin
    @match eq begin
      EQUATION_EQUALITY(__) => begin
        types = collectExpFlatTypes(eq.lhs, types)
        types = collectExpFlatTypes(eq.rhs, types)
        types = collectFlatType(eq.ty, types)
        ()
      end

      EQUATION_ARRAY_EQUALITY(__) => begin
        types = collectExpFlatTypes(eq.lhs, types)
        types = collectExpFlatTypes(eq.rhs, types)
        types = collectFlatType(eq.ty, types)
        ()
      end

      EQUATION_FOR(__) => begin
        types = ArrayUtil.fold(eq.body, collectEquationFlatTypes, types)
        ()
      end

      EQUATION_IF(__) => begin
        types = ArrayUtil.fold(eq.branches, collectEqBranchFlatTypes, types)
        ()
      end

      EQUATION_WHEN(__) => begin
        types = ArrayUtil.fold(eq.branches, collectEqBranchFlatTypes, types)
        ()
      end

      EQUATION_ASSERT(__) => begin
        types = collectExpFlatTypes(eq.condition, types)
        types = collectExpFlatTypes(eq.message, types)
        types = collectExpFlatTypes(eq.level, types)
        ()
      end

      EQUATION_TERMINATE(__) => begin
        types = collectExpFlatTypes(eq.message, types)
        ()
      end

      EQUATION_REINIT(__) => begin
        types = collectExpFlatTypes(eq.reinitExp, types)
        ()
      end

      EQUATION_NORETCALL(__) => begin
        types = collectExpFlatTypes(eq.exp, types)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return types
end

function collectBindingFlatTypes(binding::Binding, types::TypeTree)::TypeTree
  if isExplicitlyBound(binding)
    types = collectExpFlatTypes(getTypedExp(binding), types)
  end
  return types
end

function collectFlatType(ty::M_Type, types::TypeTree)::TypeTree
  () = begin
    @match ty begin
      TYPE_ENUMERATION(__) => begin
        types = TypeTreeImpl.add(types, ty.typePath, ty)
        ()
      end
      TYPE_ARRAY(__) => begin
        types = foldExpList(
          ty.dimensions,
          collectExpFlatTypes_traverse,
          types,
        )
        types = collectFlatType(ty.elementType, types)
        ()
      end
      TYPE_COMPLEX(complexTy = COMPLEX_RECORD(__)) => begin
        types = TypeTreeImpl.add(types, scopePath(ty.cls), ty)
        ()
      end
      TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(__)) =>  begin
        types = TypeTreeImpl.add(types, scopePath(ty.cls), ty)
      end
      _ => begin
        ()
      end
    end
  end
  return types
end

function collectVariableFlatTypes(var::Variable, types::TypeTree)
  types = collectFlatType(var.ty, types)
  types = collectBindingFlatTypes(var.binding, types)
  for attr in var.typeAttributes
    types = collectBindingFlatTypes(Util.tuple22(attr), types)
  end
  return types
end

function collectFlatTypes(flatModel::FlatModel, functions::List{<:M_Function})
  local types::TypeTree
  types = TypeTreeImpl.new()
  types = ArrayUtil.fold(flatModel.variables, collectVariableFlatTypes, types)
  types = ArrayUtil.fold(flatModel.equations, collectEquationFlatTypes, types)
  types = ArrayUtil.fold(flatModel.initialEquations, collectEquationFlatTypes, types)
  types = ArrayUtil.fold(flatModel.algorithms, collectAlgorithmFlatTypes, types)
  types = ArrayUtil.fold(flatModel.initialAlgorithms, collectAlgorithmFlatTypes, types)
  types = ListUtil.fold(functions, collectFunctionFlatTypes, types)
  #println(TypeTreeImpl.printTreeStr(types))
  local typeLst = TypeTreeImpl.listValues(types)
  return typeLst
end

function toFlatStream(flatModel::FlatModel, functions::List, printBindingTypes::Bool = false, s = Nothing)
  local str::String
  local flat_model::FlatModel = flatModel
  s = IOStream_M.append(s, "model '" + flat_model.name + "'\\n")
  (vars, bindingEqs) = reconstructRecordInstances(flat_model.variables)
  #=
  Sometimes, we get duplicate elements when we collect record elements.
  Make sure that we do not get duplicated record instances.
  =#
  if Flags.isSet(Flags.NF_SCALARIZE)
    unique!((x) -> toString(x.name), vars)
  end
  @assign flat_model.variables = vars
  #= Append binding equations from absorbed record field variables.
     These bindings were lost when fields were merged into record-typed variables. =#
  if !isempty(bindingEqs)
    @assign flat_model.equations = vcat(flat_model.equations, bindingEqs)
  end
  for fn in functions
    if !isDefaultRecordConstructor(fn)
      s = toFlatStream(fn, s)
      s = IOStream_M.append(s, ";\\n\\n")
    end
  end
  # WIP
  # for fn in functions
  #   if isDefaultRecordConstructor(fn)
  #     println("!isDefaultRecordConstructor:" * AbsynUtil.pathString(fn.path))
  #     s = IOStream_M.append(s, "//Automatically Generated Generated Record Constructors \\n\\n")
  #     s = toFlatStream(fn, s)
  #     s = IOStream_M.append(s, ";\\n\\n")
  #     s = IOStream_M.append(s, "//End of Automatically Generated Record Constructors \\n\\n")
  #   end
  # end

  for ty in collectFlatTypes(flat_model, functions)
    s = toFlatDeclarationStream(ty, s)
    s = IOStream_M.append(s, ";\\n\\n")
  end

  for v in flat_model.variables
    s = toFlatStream(v, "  ", printBindingTypes, s)
    s = IOStream_M.append(s, ";\\n")
  end
  if !isempty(flat_model.initialEquations)
    s = IOStream_M.append(s, "initial equation\\n")
    s = toFlatStreamList(flat_model.initialEquations, "  ", s)
  end
  if !isempty(flat_model.equations)
    s = IOStream_M.append(s, "equation\\n")
    s = toFlatStreamList(flat_model.equations, "  ", s)
  end
  for alg in flat_model.initialAlgorithms
    if !isempty(alg.statements)
      s = IOStream_M.append(s, "initial algorithm\\n")
      s = toFlatStreamList(alg.statements, "  ", s)
    end
  end
  for alg in flat_model.algorithms
    if !isempty(alg.statements)
      s = IOStream_M.append(s, "algorithm\\n")
      s = toFlatStreamList(alg.statements, "  ", s)
    end
  end
  s = IOStream_M.append(s, "end '" + flat_model.name + "';\\n")
  str = IOStream_M.string(s)
  IOStream_M.delete(s)
  str = fixTupleElementAccess(str)
  return (s, str)
end

"""
Fix TUPLE_ELEMENT_EXPRESSION serialization in flat Modelica output.

The pattern `'FuncName'(args)[N]` is not valid Modelica syntax.
This function replaces such patterns with calls to auto-generated wrapper
functions that call the original function and return only element N.
"""
function fixTupleElementAccess(str::String)::String
  #= Find all )[N] patterns (unique to TUPLE_ELEMENT_EXPRESSION) =#
  replacements = Tuple{Int, Int, String, String, Int}[]
  i = 1
  while i <= lastindex(str)
    if str[i] == ')' && i < lastindex(str) && str[nextind(str, i)] == '['
      bracketStart = nextind(str, i)
      j = nextind(str, bracketStart)
      while j <= lastindex(str) && isdigit(str[j])
        j = nextind(str, j)
      end
      if j <= lastindex(str) && str[j] == ']' && j > nextind(str, bracketStart)
        elemIdx = parse(Int, str[nextind(str, bracketStart):prevind(str, j)])
        #= Find matching '(' by scanning backwards from ')' =#
        depth = 1
        k = prevind(str, i)
        while k >= 1 && depth > 0
          if str[k] == ')'
            depth += 1
          elseif str[k] == '('
            depth -= 1
          end
          if depth > 0
            k = prevind(str, k)
          end
        end
        #= k now points to matching '(' =#
        funcEnd = prevind(str, k)
        if funcEnd >= 1 && str[funcEnd] == '\''
          funcStart = findprev('\'', str, prevind(str, funcEnd))
          if funcStart !== nothing
            funcName = str[nextind(str, funcStart):prevind(str, funcEnd)]
            argsStr = str[k:i]
            wrapperName = "$(funcName)__tupleElem_$(elemIdx)"
            replacement = "'$(wrapperName)'$(argsStr)"
            push!(replacements, (funcStart, j, replacement, funcName, elemIdx))
            i = nextind(str, j)
            continue
          end
        end
      end
    end
    i = nextind(str, i)
  end

  if isempty(replacements)
    return str
  end

  #= Apply replacements in reverse order =#
  result = str
  for (s, e, rep, _, _) in sort(replacements, by = x -> x[1], rev = true)
    result = result[1:prevind(result, s)] * rep * result[nextind(result, e):end]
  end

  #= Generate wrapper functions and insert them =#
  wrapperDefs = generateTupleWrappers(replacements, str)
  if !isempty(wrapperDefs)
    #= Insert after first newline (after "model 'Name'") =#
    firstNL = findfirst('\n', result)
    if firstNL !== nothing
      result = result[1:firstNL] * wrapperDefs * result[nextind(result, firstNL):end]
    end
  end

  return result
end

"""
Generate wrapper function definitions for tuple element access.
For each (funcName, elemIdx), finds the original function in the flat model,
parses its inputs/outputs, and generates a wrapper that returns only element N.
"""
function generateTupleWrappers(
  replacements::Vector{Tuple{Int, Int, String, String, Int}},
  originalStr::String,
)::String
  #= Collect unique (funcName, elemIdx) pairs =#
  seen = Set{Tuple{String, Int}}()
  wrappers = String[]
  for (_, _, _, funcName, elemIdx) in replacements
    key = (funcName, elemIdx)
    if key in seen
      continue
    end
    push!(seen, key)

    #= Find the function definition in the original string =#
    funcDef = extractFunctionDef(originalStr, funcName)
    if funcDef === nothing
      continue
    end

    #= Parse inputs and outputs =#
    inputs, outputs = parseFunctionIO(funcDef)
    if isempty(outputs) || elemIdx > length(outputs)
      continue
    end

    #= Generate wrapper =#
    wrapperName = "$(funcName)__tupleElem_$(elemIdx)"
    wrapper = generateSingleWrapper(wrapperName, funcName, inputs, outputs, elemIdx)
    push!(wrappers, wrapper)
  end

  return Base.join(wrappers, "\n")
end

"""
Extract a function definition block from the flat model string.
Returns the text from 'function ...' to 'end ...;'
"""
function extractFunctionDef(str::String, funcName::String)::Union{String, Nothing}
  target = "function '" * funcName * "'"
  startIdx = findfirst(target, str)
  if startIdx === nothing
    return nothing
  end
  endTarget = "end '" * funcName * "';"
  endIdx = findfirst(endTarget, str)
  if endIdx === nothing
    return nothing
  end
  return str[startIdx.start:endIdx.stop]
end

"""
Parse input and output declarations from a function definition string.
Returns (inputs, outputs) where each is a vector of (declaration_line, param_name).
"""
function parseFunctionIO(funcDef::String)
  inputs = Tuple{String, String}[]
  outputs = Tuple{String, String}[]
  for line in Base.split(funcDef, '\n')
    stripped = Base.lstrip(line)
    if Base.startswith(stripped, "input ")
      pname = extractParamName(String(stripped))
      if pname !== nothing
        push!(inputs, (String(stripped), pname))
      end
    elseif Base.startswith(stripped, "output ")
      pname = extractParamName(String(stripped))
      if pname !== nothing
        push!(outputs, (String(stripped), pname))
      end
    end
  end
  return inputs, outputs
end

"""
Extract the parameter name from an input/output declaration line.
Handles both quoted ('name') and unquoted (name) forms.
"""
function extractParamName(line::String)::Union{String, Nothing}
  #= Remove trailing semicolon and attributes =#
  #= Pattern: "input/output Type[dims] 'name'(...) = ...;" or "input/output Type name;" =#
  m = Base.match(r"(?:input|output)\s+\S+(?:\[.*?\])?\s+'([^']+)'", line)
  if m !== nothing
    return m.captures[1]
  end
  m = Base.match(r"(?:input|output)\s+\S+(?:\[.*?\])?\s+(\w+)", line)
  if m !== nothing
    return m.captures[1]
  end
  return nothing
end

"""
Generate a single wrapper function that calls the original and returns element N.
"""
function generateSingleWrapper(
  wrapperName::String,
  origFuncName::String,
  inputs::Vector{Tuple{String, String}},
  outputs::Vector{Tuple{String, String}},
  elemIdx::Int,
)::String
  buf = IOBuffer()
  println(buf, "function '", wrapperName, "'")
  #= Same inputs =#
  for (decl, _) in inputs
    println(buf, "  ", decl)
  end
  #= Only the selected output =#
  println(buf, "  ", outputs[elemIdx][1])
  #= Other outputs as protected locals =#
  otherOutputs = Tuple{String, String}[]
  for (oi, (decl, pname)) in enumerate(outputs)
    if oi != elemIdx
      #= Convert "output Type name" to just "Type name" =#
      localDecl = Base.replace(decl, r"^\s*output\s+" => "")
      push!(otherOutputs, (localDecl, pname))
    end
  end
  if !isempty(otherOutputs)
    println(buf, "protected")
    for (decl, _) in otherOutputs
      println(buf, "  ", decl)
    end
  end
  #= Algorithm: call original with tuple decomposition =#
  println(buf, "algorithm")
  outNames = ["'" * o[2] * "'" for o in outputs]
  inNames = ["'" * inp[2] * "'" for inp in inputs]
  tupleStr = "(" * Base.join(outNames, ", ") * ")"
  callStr = "'" * origFuncName * "'(" * Base.join(inNames, ", ") * ")"
  println(buf, "  ", tupleStr, " := ", callStr, ";")
  println(buf, "end '", wrapperName, "';")
  println(buf)
  return String(take!(buf))
end

function printFlatString(
  flatModel::FlatModel,
  functions::List{M_Function},
  printBindingTypes::Bool = false,
)
  local s
  s = IOStream_M.create(getInstanceName(), IOStream.IOStreamType.LIST())
  s = toFlatStream(flatModel, functions, printBindingTypes, s)
  return IOStream_M.print(s, IOStream_M.stdOutput)
end

function toFlatString(
  flatModel::FlatModel,
  functions::List,
  printBindingTypes::Bool = false,
  )
  local str::String
  local s::IOStream_M.IOSTREAM
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  (s, str) = toFlatStream(flatModel, functions, printBindingTypes, s)
  str = IOStream_M.string(s)
  #= Fix non-literal subscripts from inner CREF nodes that ended up inside quotes.
     toFlatString_impl embeds all subscripts in node names, but iterator variables
     must be outside quotes for valid flat Modelica.
     e.g. 'pipe4.mediums[i + 1].state'.'p' -> 'pipe4.mediums'[i + 1].'state'.'p'
     Match simple '...' pairs (no backtracking), fix contents if needed.
     Iterate for nested subscripts (e.g. 'a[i].b[j]' needs 2 passes). =#
  local _has_var_sub = r"\[[^\]]*[a-zA-Z_]"
  local _split_sub = r"^([^\[]*)\[([^\]]*[a-zA-Z_][^\]]*)\](.*)"
  local _prev_str = ""
  while _prev_str != str
    _prev_str = str
    str = replace(str, r"'([^']*)'" => function(_m)
      local _seg = _m[2:end-1]
      if !occursin(_has_var_sub, _seg)
        return _m
      end
      local _mt = Base.match(_split_sub, _seg)
      if _mt === nothing
        return _m
      end
      local _pre = _mt.captures[1]
      local _sub = _mt.captures[2]
      local _post = _mt.captures[3]
      if isempty(_post)
        return "'$(_pre)'[$(_sub)]"
      else
        local _cleanPost = lstrip(_post, ['.'])
        return "'$(_pre)'[$(_sub)].'$(_cleanPost)'"
      end
    end)
  end
  return str
end

function toString(flatModel::FlatModel, printBindingTypes::Bool = false)::String
  local str::String
  local s::IOStream_M.IOSTREAM
  local modelName = replace(flatModel.name, "." => "_")
  s = IOStream_M.create(getInstanceName(), IOStream_M.LIST())
  s = IOStream_M.append(s, "class " + modelName + "\\n")
  for structuralMode in flatModel.structuralSubmodels
    structuralModelString = toString(structuralMode, printBindingTypes)
    s = IOStream_M.append(s, "structuralmode " * structuralModelString)
  end
  for v in flatModel.variables
    s = toStream(v, "  ", printBindingTypes, s)
    s = IOStream_M.append(s, ";\\n")
  end
  if !isempty(flatModel.initialEquations)
    s = IOStream_M.append(s, "initial equation\\n")
    s = toStreamList(flatModel.initialEquations, "  ", s)
  end
  if !isempty(flatModel.equations)
    s = IOStream_M.append(s, "equation\\n")
    s = toStreamList(flatModel.equations, "  ", s)
  end
  for alg in flatModel.initialAlgorithms
    if !isempty(alg.statements)
      s = IOStream_M.append(s, "initial algorithm\\n")
      s = toStreamList(alg.statements, "  ", s)
    end
  end
  for alg in flatModel.algorithms
    if !isempty(alg.statements)
      s = IOStream_M.append(s, "algorithm\\n")
      s = toStreamList(alg.statements, "  ", s)
    end
  end
  if !(flatModel.DOCC_equations isa Nil)
    doccs = flatModel.DOCC_equations
    for eq in doccs
      s = IOStream_M.append(s, "//dynamic overconstraint connector equation\\n")
      s = IOStream_M.append(s, toString(eq) * ";\\n")
    end
  end
  s = IOStream_M.append(s, "end " + modelName + ";\\n")
  str = IOStream_M.string(s)
  return str
end

"""
  This functions checks for a recompilation directive among all the equations.
  This function will also return true if the model contains another change that might
  lead to recompilation.
"""
function recompilationDirectiveExists(@nospecialize(eqs::Vector{Equation}))::Bool
  local hasCallDirective = containsList(eqs, (eq) -> containsCallNamed(eq, "recompilation") || containsCallNamed(eq, "agentic_recompilation"))
  local hasReconfigure = any(eq -> isa(eq, EQUATION_RECONFIGURE), eqs)
  return hasCallDirective || hasReconfigure
end


"""
  Returns true if the list of equations contains a branch directive.
"""
function branchDirectiveExists(@nospecialize(eqs::Vector{Equation}))::Bool
  local hasBranchDirective = containsList(eqs, (eq) -> containsCallNamed(eq, "Connections.branch"))
  return hasBranchDirective
end

"""
  Collect all DOCCS Equations.
"""
function collectDOCCS(@nospecialize(eqs::Vector{Equation}))
  Base.collect(Iterators.flatten([containsDOCC(eq) for eq in eqs]))
end

"""
  This function returns true if a EQUATION_NORETCALL is a func name.
"""
function containsCallNamed(@nospecialize(eq::Equation), funcName::String)::Bool
  local functionExistWithName = false
  @match eq begin
    EQUATION_NORETCALL(__) => begin
      @match eq.exp begin
        CALL_EXPRESSION(call = TYPED_CALL(fn, ty, var, arguments, attributes)) => begin
          local nameAsStr = AbsynUtil.pathString(name(fn))
          if funcName == nameAsStr
            functionExistWithName = true
          end
        end
      end
    end
    _ => begin
      functionExistWithName = false
    end
  end
  return functionExistWithName
end


"""
  Check if the model contains a Dynamically Overconstrained Connector (DOCC).
  returns a list with all if-equations containing DOCC.
"""
function containsDOCC(@nospecialize(eq::Equation))::Vector{Equation}
  local doccs = Equation[]
  @match eq begin
    EQUATION_IF(__) => begin
      for branch in eq.branches
        if branch isa EQUATION_BRANCH
          if branchDirectiveExists(branch.body)
            push!(doccs, eq)
          end
        end
      end
    end
    _ => Equation[]
  end
  return doccs
end
