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

struct MatchTypeStruct{T0 <: Integer}
  FOUND::T0
  NOT_FOUND::T0
  PARTIAL::T0
end

const MatchType = MatchTypeStruct(1, 2, 3)
const MatchTypeTy = Int

#=
  Variant A of the `lookupClassName` cache. Key is
  `(objectid(name), objectid(scope), checkAccessViolations)` — no
  stringification, no allocation per call. Enabled by env var
  `OMFRONTEND_LOOKUP_CACHE=true`. Default off so behavior is unchanged.

  Hit rate depends on whether `Absyn.Path` objects are reused across calls:
  parser-built paths in the SCode tree are reused, runtime-constructed paths
  may not be. With `objectid` keys, two equivalent paths from different
  allocations miss the cache, but hits are nanosecond-cheap.

  Reset at translation entry via `resetLookupCache` from `resetInstDiagnostics`.
  Hit/miss counters surface in `dumpInstDiagnostics` when
  `OMFRONTEND_INST_PROFILE=true`.
=#
const LOOKUP_CLASS_CACHE = Dict{Tuple{UInt64, UInt64, Bool}, InstNode}()
const LOOKUP_CLASS_HITS  = Ref(0)
const LOOKUP_CLASS_MISSES = Ref(0)

function _lookupCacheEnabled()
  return get(ENV, "OMFRONTEND_LOOKUP_CACHE", "false") == "true"
end

function resetLookupCache()
  empty!(LOOKUP_CLASS_CACHE)
  LOOKUP_CLASS_HITS[] = 0
  LOOKUP_CLASS_MISSES[] = 0
  return nothing
end

function lookupClassName(name::Absyn.Path, scope::InstNode, info::SourceInfo, checkAccessViolations::Bool = true; isRedeclared::Bool = false)
  local node::InstNode
  local state::LookupState
  local LS_REF::Ref{LookupState}
  if _lookupCacheEnabled() && !isRedeclared
    local key = (objectid(name), objectid(scope), checkAccessViolations)
    local cached = get(LOOKUP_CLASS_CACHE, key, nothing)
    if cached !== nothing
      LOOKUP_CLASS_HITS[] += 1
      return cached::InstNode
    end
    LS_REF = Ref{LookupState}(LOOKUP_STATE_BEGIN())
    node = lookupNameWithError(name, scope, info, "error", LS_REF, checkAccessViolations; isRedeclared = isRedeclared)
    state = LS_REF.x
    assertClass(state, node, name, info)
    LOOKUP_CLASS_CACHE[key] = node
    LOOKUP_CLASS_MISSES[] += 1
    return node
  end
  LS_REF = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  node = lookupNameWithError(name, scope, info, "error", LS_REF, checkAccessViolations; isRedeclared = isRedeclared)
  state = LS_REF.x
  assertClass(state, node, name, info)
  return node
end

function lookupBaseClassName(name::Absyn.Path, scope::InstNode, info::SourceInfo)
  local nodes::List{InstNode}
  local state::LookupState
  local LS_REF = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  nodes = lookupNames(name, scope, LS_REF)
  state = LS_REF.x
  if state isa LOOKUP_STATE_ERROR
    Error.addSourceMessage(Error.LOOKUP_BASECLASS_ERROR, list(AbsynUtil.pathString(name), scopeName(scope)), info)
    throw(e)
  end
  assertClass(state, listHead(nodes), name, info)
  nodes
end

function lookupComponent(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#, scopeRef::Ref{InstNode}, info::SourceInfo)
  local foundCref::ComponentRef
  local nodeVar::InstNode
  local stateRef = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  foundCref = lookupCref(cref, scope, scopeRef, stateRef)
  local foundScope = scopeRef.x
  local state = stateRef.x
  if state isa LOOKUP_STATE_ERROR
    @error "Failed to lookup" toString(scope)
  end
  nodeVar = node(foundCref)
  local isNameRes = isName(nodeVar)
  if isNameRes != false
    #@error "Failed with $e"
    Error.addSourceMessageAndFail(Error.LOOKUP_VARIABLE_ERROR, list(toString(cref), scopeName(scope)), info)
    fail()
  end
  state = fixTypenameState(nodeVar, state)
  assertComponent(state, nodeVar, cref, info)
  foundCref
end

function lookupConnector(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#, info::SourceInfo)
  local foundScope::InstNode #= The scope the cref was found in. =#
  local foundCref::ComponentRef
  local state::LookupState
  local nodeVar::InstNode
  stateRef::Ref{LookupState} = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  scopeRef::Ref{InstNode} = Ref{InstNode}(EMPTY_NODE())
  foundCref = lookupCref(cref, scope, scopeRef, stateRef)
  foundScope = scopeRef.x
  state = stateRef.x
  if state isa LOOKUP_STATE_ERROR
    Error.addSourceMessageAndFail(Error.LOOKUP_VARIABLE_ERROR, list(Dump.printComponentRefStr(cref), scopeName(scope)), info)
  end
  nodeVar = node(foundCref)
  state = fixTypenameState(nodeVar, state)
  assertComponent(state, nodeVar, cref, info)
  (foundCref, foundScope #= The scope the cref was found in. =#)
end

function fixTypenameState(n::InstNode, state::LookupState)
  local ty::NFType
  if isClass(n)
    ty = getType(expand(n))
    state = begin
      @match ty begin
        TYPE_ENUMERATION(__)  => begin
          LOOKUP_STATE_COMP()
        end
        TYPE_BOOLEAN(__)  => begin
          LOOKUP_STATE_COMP()
        end
        _  => begin
          state
        end
      end
    end
  end
  state
end

"""
  Looks up a component in the local scope, without searching in any enclosing
  scopes. The found scope is returned since it can be different from the given
  scope in the case where the cref refers to an outer component.
"""
function lookupLocalComponent(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#, info::SourceInfo)
  local foundScope::InstNode #= The scope the cref was found in. =#
  local foundCref::ComponentRef
  local state::LookupState
   (foundCref, foundScope, state) = lookupLocalCref(cref, scope, info)
  assertComponent(state, node(foundCref), cref, info)
  (foundCref, foundScope #= The scope the cref was found in. =#)
end

function lookupFunctionName(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#, info::SourceInfo)
  local foundScope::InstNode
  local foundCref::ComponentRef
  local state::LookupState
  local nodeVar::InstNode
  #= To avoid returning tuples =#
  local scopeRef = Ref{InstNode}(EMPTY_NODE())
  local stateRef = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  foundCref = lookupCref(cref, scope, scopeRef, stateRef)
  foundScope = scopeRef.x
  state = stateRef.x
  nodeVar = node(foundCref)
  @match false = isName(nodeVar)
  (foundCref, state) = fixExternalObjectCall(nodeVar, foundCref, state)
  assertFunction(state, nodeVar, cref, info)
  (foundCref, foundScope)
end

function lookupFunctionNameSilent(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#)
  local foundScope::InstNode
  local foundCref::ComponentRef
  local state::LookupState
  local nodeVar::InstNode
  local scopeRef = Ref{InstNode}(EMPTY_NODE())
  local stateRef = Ref{LookupState}(LOOKUP_STATE_BEGIN())
  foundCref = lookupCref(cref, scope, scopeRef, stateRef)
  foundScope = scopeRef.x
  state = stateRef.x
  nodeVar = node(foundCref)
  (foundCref, state) = fixExternalObjectCall(nodeVar, foundCref, state)
  @match true = isFunction(state, nodeVar)
  (foundCref, foundScope)
end

"""
  Changes calls to external objects so that the constructor is called instead,
                 i.e. a call such as
                   'ExtObj eo = ExtObj(...)'
                 is changed to
                   'ExtObj eo = ExtObj.constructor(...)'
"""
function fixExternalObjectCall(node::InstNode, cref::ComponentRef, state::LookupState)
  local cls::Class
  local constructor::InstNode
  #=  If it's not a class it can't be an external object.
  =#
  if ! isClass(state)
    return (cref, state)
  end
  expand(node)
  cls = getClass(node)
  () = begin
    @match cls begin
      PARTIAL_BUILTIN(ty = TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(constructor = constructor)))  => begin
        cref = prefixCref(constructor, TYPE_UNKNOWN(), nil, cref)
        state = LOOKUP_STATE_FUNC()
        ()
      end
      _  => begin
        ()
      end
    end
  end
  (cref, state)
end

function lookupImport(name::Absyn.Path, scope::InstNode, info::SourceInfo)
  local element::InstNode
  local state::LookupState
  local LS_REF::Ref{LookupState} = LOOKUP_STATE_BEGIN()
  element = lookupNameWithError(name, topScope(scope), info, Error.LOOKUP_IMPORT_ERROR, LS_REF)
  state = LS_REF.x
  assertImport(state, element, name, info)
  element
end

function lookupCrefWithError(cref::Absyn.ComponentRef, scope::InstNode, info::SourceInfo, errMsg) ::Tuple{ComponentRef, InstNode, LookupState}
  local state::LookupState
  local foundScope::InstNode
  local foundCref::ComponentRef
  try
     (foundCref, foundScope, state) = lookupCref(cref, scope)
  catch
    Error.addSourceMessage(errMsg, list(Dump.printComponentRefStr(cref), scopeName(scope)), info)
  end
  (foundCref, foundScope, state)
end

"""
  This function will look up an Absyn.ComponentRef in the given scope, and
  construct a ComponentRef from the found nodes. The scope where the first part
  of the cref was found will be available in the scopeRef structure.
"""
function lookupCref(cref::Absyn.ComponentRef,
                    scope::InstNode,
                    scopeRef::Ref{InstNode},
                    stateRef::Ref{LookupState})
  local state::LookupState
  local foundScope::InstNode #= The scope where the first part of the cref was found. =#
  local foundCref::ComponentRef

  local nodeVar::InstNode

  foundCref = begin
    @match cref begin
      Absyn.CREF_IDENT(__)  => begin
        (_, foundCref) = lookupSimpleCref(cref.name, cref.subscripts, scope, scopeRef, stateRef)
        foundScope = scopeRef.x
        state = stateRef.x
        foundCref
        #(foundCref, foundScope, state)
      end

      Absyn.CREF_QUAL(__)  => begin
        (nodeVar, foundCref) = lookupSimpleCref(cref.name, cref.subscripts, scope, scopeRef, stateRef)
        foundScope = scopeRef.x
        state = stateRef.x
        foundCref = lookupCrefInNode(cref.componentRef, nodeVar, foundCref, foundScope, state, scopeRef, stateRef)
        foundScope = scopeRef.x
        state = stateRef.x
        foundCref
      end

      Absyn.CREF_FULLYQUALIFIED(__)  => begin
        foundCref = lookupCref(cref.componentRef, topScope(scope), scopeRef, stateRef)
        foundScope = scopeRef.x
        state = stateRef.x
        foundCref
      end

      Absyn.WILD(__)  => begin
        foundScope = scope
        state = LOOKUP_STATE_PREDEF_COMP()
        WILD()
      end

      Absyn.ALLWILD(__)  => begin
        foundScope = scope
        state = LOOKUP_STATE_PREDEF_COMP()
        WILD()
      end
      _ => begin
        foundScope = scope
        state = LOOKUP_STATE_ERROR(state)
        WILD()
     end
    end
  end
  scopeRef.x = foundScope
  stateRef.x = state
  return foundCref
end

"""Looks up a cref in the local scope without going into any enclosing scopes."""
function lookupLocalCref(cref::Absyn.ComponentRef, scope::InstNode #= The scope to look in. =#, info::SourceInfo)
  local state::LookupState
  local foundScope::InstNode #= The scope where the first part of the cref was found. =#
  local foundCref::ComponentRef
  local match_ty::MatchTypeTy
  local node::InstNode
   (foundCref, foundScope, state) = begin
    local found_scope::InstNode
    @matchcontinue cref begin
      Absyn.CREF_IDENT(__)  => begin
         (node, foundScope) = lookupLocalSimpleCref(cref.name, scope)
        @assign state = nodeState(node)
        (fromAbsyn(node, cref.subscripts), foundScope, state)
      end

      Absyn.CREF_QUAL(__)  => begin
         (node, foundScope) = lookupLocalSimpleCref(cref.name, scope)
        state = nodeState(node)
        foundCref = fromAbsyn(node, cref.subscripts)
        (foundCref, foundScope, state) = lookupCrefInNode(cref.componentRef, node, foundCref, foundScope, state)
        (foundCref, foundScope, state)
      end

      _  => begin
        #Error.addSourceMessage(Error.LOOKUP_VARIABLE_ERROR, list(Dump.printComponentRefStr(cref), scopeName(scope)), info)
        @error "Lookup error $cref"
        fail()
      end
    end
  end
  (foundCref, foundScope #= The scope where the first part of the cref was found. =#, state)
end

"""Looks up the corresponding inner node given an outer node."""
function lookupInner(outerNode::InstNode, scope::InstNode)
  local innerNode::InstNode

  local nameVar::String = name(outerNode)
  local cur_scope::InstNode = scope
  local prev_scope::InstNode = scope

  while ! isEmpty(cur_scope)
    try
      @match ENTRY_INFO(node, isImport) = lookupElement(nameVar, getClass(cur_scope))
      @match false = isImport
      innerNode = resolveOuter(node)
      @match true = isInner(innerNode)
      return innerNode
    catch e
      prev_scope = cur_scope
      cur_scope = derivedParent(cur_scope)
    end
  end
  innerNode = generateInner(outerNode, prev_scope)
  innerNode
end

"""
  Attempts to lookup a simple name in some module.
"""
function lookupSimpleName(nameStr::String, scope::InstNode)
  local node::InstNode
  local cur_scope::InstNode = scope
  for i in 1:Global.recursionDepthLimit
    @match ENTRY_INFO(node, _) = lookupLocalSimpleName(nameStr, cur_scope)
    if node !== EMPTY_NODE()
      return node
    end
    if nameStr == name(cur_scope) && isClass(cur_scope)
      node = cur_scope
      return node
    end
    cur_scope = parentScope(cur_scope)
  end
  #@error "Failed to lookup simple name for $nameStr in scope:$scope"
  Error.addSourceMessage(Error.LOOKUP_VARIABLE_ERROR, list(nameStr, scopeName(scope)), info)
  return EMPTY_NODE
end


"""
    Looks up a name in the given scope, without continuing the search in any
  enclosing scopes if the name isn't found.
"""
function lookupLocalSimpleName(n::String, scope::InstNode)
  local isImport::Bool = false
  local node::InstNode
  if scope isa EMPTY_NODE
    throw("Lookup Error: Attempted to lookup '$n'. However, it was not found in the given scope.")
  end
  entryInfo = @match ENTRY_INFO(node, isImport) = lookupElement(n, getClass(scope))
  node = resolveInner(node)
  return entryInfo#(node, isImport)
end


function lookupNameWithError(name::Absyn.Path, scope::InstNode, info::SourceInfo, errorType, lookupStateRef::Ref{LookupState}, checkAccessViolations::Bool = true; isRedeclared::Bool = false)
  local state::LookupState
  local node::InstNode
  node = lookupName(name, scope, lookupStateRef, checkAccessViolations; isRedeclared = isRedeclared)
  state = lookupStateRef.x
  if node isa EMPTY_NODE
    Error.addSourceMessage(Error.LOOKUP_ERROR, list(AbsynUtil.pathString(name), scopeName(scope)), info)
    #@error "Lookup error for path: $(AbsynUtil.pathString(name)) in the scope $(scopeName(scope))"
    fail()
  end
  node
end

function lookupName(name::Absyn.Path, scope::InstNode, lookupStateRef::Ref{LookupState}, checkAccessViolations::Bool; isRedeclared::Bool = false)
  local state::LookupState
  local node::InstNode
  node = begin
    @match name begin
      Absyn.IDENT(__)  => begin
        lookupFirstIdent(name.name, scope, lookupStateRef)
      end
      Absyn.QUALIFIED(__)  => begin
        node = lookupFirstIdent(name.name, scope, lookupStateRef)
        state = lookupStateRef.x
        lookupLocalName(name.path, node, state, lookupStateRef, checkAccessViolations, refEqual(node, scope); isRedeclared = isRedeclared)
      end
      Absyn.FULLYQUALIFIED(__)  => begin
        lookupName(name.path, topScope(scope), lookupStateRef, checkAccessViolations; isRedeclared = isRedeclared)
      end
    end
  end
  state = lookupStateRef.x
  node
end

function lookupNames(name::Absyn.Path, scope::InstNode, lookupStateRef::Ref{LookupState})::List{InstNode}
  #@info "Calling lookupNames with path: $name"
  local state::LookupState
  local nodes::List{InstNode}
  nodes = begin
    local node::InstNode
    #=  Simple name, look it up in the given scope. =#
    @match name begin
      Absyn.IDENT(__)  => begin
        node = lookupFirstIdent(name.name, scope, lookupStateRef)
        state = lookupStateRef.x
        return Cons{InstNode}(node, nil)
      end
      Absyn.QUALIFIED(__)  => begin
        node = lookupFirstIdent(name.name, scope, lookupStateRef)
        state = lookupStateRef.x
        return lookupLocalNames(name.path, node, Cons{InstNode}(node, nil), state, lookupStateRef, refEqual(node, scope))
      end

      Absyn.FULLYQUALIFIED(__)  => begin
        return lookupNames(name.path, topScope(scope), lookupStateRef)
      end
    end
  end
  #=  Fully qualified path, start from top scope. =#
  #@info "Done looking up names"
  nodes
end

""" Looks up the first part of a name. """
function lookupFirstIdent(name::String, scope::InstNode, lookupStateRef::Ref{LookupState})::InstNode
  local state::LookupState
  local node::Union{InstNode,Nothing}
  node = lookupSimpleBuiltinName(name)
  if node !== nothing
    state = LOOKUP_STATE_PREDEF_CLASS()
  else
    node = lookupSimpleName(name, scope)
    state = nodeState(node)
  end
  lookupStateRef.x = state
  node
end

"""
 Looks up a path in the given scope, without continuing the search in any
 enclosing scopes if the path isn't found.
"""
function lookupLocalName(name::Absyn.Path, node::InstNode, state::LookupState, lookupStateRef::Ref{LookupState}, checkAccessViolations::Bool = true, selfReference::Bool = false; isRedeclared::Bool = false)
  local is_import::Bool
  if ! isClass(node)
    state =  LOOKUP_STATE_COMP_CLASS()
    lookupStateRef.x = state
    return node
  end
  if ! selfReference
    node = instPackage(node; isRedeclared = isRedeclared)
  end
  #=  Look up the path in the scope.
  =#
  @match name begin
    Absyn.IDENT(__)  => begin
      @match ENTRY_INFO(node, is_import) = lookupLocalSimpleName(name.name, node)
      #@debug "HERE WE ARE!"
      if is_import
        state = LOOKUP_STATE_ERROR(LOOKUP_STATE_IMPORT())
        lookupStateRef.x = state
      else
        state = next(node, state, checkAccessViolations)
        lookupStateRef.x = state
      end
    end

    Absyn.QUALIFIED(__)  => begin
      @match ENTRY_INFO(node, is_import) = lookupLocalSimpleName(name.name, node)
      if is_import
        state = LOOKUP_STATE_ERROR(LOOKUP_STATE_IMPORT())
        lookupStateRef.x = state
      else
        state = next(node, state, checkAccessViolations)
        lookupStateRef.x = state
        node = lookupLocalName(name.path, node, state, lookupStateRef, checkAccessViolations; isRedeclared = isRedeclared)
      end
    end
    _  => begin
      #Error.assertion(false, getInstanceName() + " was called with an invalid path.", sourceInfo())
      node = EMPTY_NODE()
      state = LOOKUP_STATE_ERROR(state)
      lookupStateRef.x = state
    end
  end
  node
end

"""
  Looks up a path in the given scope, without continuing the search in any
  enclosing scopes if the path isn't found.
"""
function lookupLocalNames(name::Absyn.Path, scope::InstNode, nodes::List{InstNode}, state::LookupState, lookupStateRef::Ref{LookupState}, selfReference::Bool = false; isRedeclared::Bool = false)
  local node::InstNode = scope
  if ! isClass(scope)
    state = LOOKUP_STATE_COMP_CLASS()
    lookupStateRef.x = state
    return nodes
  end
  if ! selfReference
    node = instPackage(node; isRedeclared = isRedeclared)
  end
  nodes = begin
    @match name begin
      Absyn.IDENT(__)  => begin
        @match ENTRY_INFO(node, _) = lookupLocalSimpleName(name.name, node)
        #@debug "Here we are!"
        state = next(node, state)
        lookupStateRef.x = state
        Cons{InstNode}(node, nodes)
      end

      Absyn.QUALIFIED(__)  => begin
        @match ENTRY_INFO(node, _) = lookupLocalSimpleName(name.name, node)
        state = next(node, state)
        lookupStateRef.x = state
        lookupLocalNames(name.path, node, Cons{InstNode}(node, nodes), state, lookupStateRef)
      end
      _  => begin
        #                           Error.assertion(false, getInstanceName() + " was called with an invalid path.", sourceInfo())
        fail()
      end
    end
   end
  lookupStateRef.x = state
  nodes
end

@noinline function lookupSimpleBuiltinName(name::String)
  local builtin::InstNode
  if  name in keys(NFBuiltin.BUILTIN_DICT)
    return builtin = NFBuiltin.BUILTIN_DICT[name]
  else
    return nothing
  end
end

function lookupSimpleBuiltinCref(name::String, subs::List{T}) where {T}
  local state::LookupState
  local cref::ComponentRef
  local node::InstNode
  #@info "Looking up $name in lookupSimpleBuiltinCref"
  if name in keys(NFBuiltin.BUILTIN_CREF_DICT)
    (node, cref, state) = NFBuiltin.BUILTIN_CREF_DICT[name]
  else
    return nothing
  end
  if ! listEmpty(subs)
    cref = setSubscripts(list(SUBSCRIPT_RAW_SUBSCRIPT(s) for s in subs), cref)
  end
  (node, cref, state)
end

"""This function look up a simple name as a cref in a given component."""
function lookupSimpleCref(crefName::String,
                          subs::List{<:Absyn.Subscript},
                          scope::InstNode,
                          scopeRef::Ref{InstNode},
                          stateRef::Ref{LookupState})
  local state::LookupState
  local foundScope::InstNode = scope
  local cref::ComponentRef
  local node::InstNode
  local is_import::Bool
  #= First try the normal scope chain. Local declarations shadow builtins. =#
  for i in 1:Global.recursionDepthLimit
    try
      @match foundScope begin
        IMPLICIT_SCOPE(__)  => begin
          node = lookupIteratorNoFail(crefName, foundScope.locals)
          if node isa EMPTY_NODE
            foundScope = parentScope(foundScope)
            continue
          end
          is_import = false
        end
        CLASS_NODE(__)  => begin
          c = getClass(foundScope)
          @match ENTRY_INFO(node, is_import) = lookupElement(crefName, c)
        end
        COMPONENT_NODE(__)  => begin
          @match ENTRY_INFO(node, is_import) = lookupElement(crefName, getClass(foundScope))
        end
        INNER_OUTER_NODE(__)  => begin
          @match ENTRY_INFO(node, is_import) = lookupElement(crefName, getClass(foundScope.innerNode))
        end
        #= In this case we did not find the scope! =#
        EMPTY_NODE(__) => begin
          #= Scope chain exhausted. Try builtins as fallback. =#
          res = lookupSimpleBuiltinCref(crefName, subs)
          if res !== nothing
            (node, cref, state) = res
            stateRef.x = state
            scopeRef.x = topScope(scope)
            return (node, cref)
          end
          msg = ErrorTypes.MESSAGE(
            555,
            ErrorTypes.SCRIPTING(),
            ErrorTypes.WARNING(),
            Gettext.gettext("LookupSimpleCref: Reached empty node while looking for $crefName\n"),
          )::ErrorTypes.Message
          Error.addSourceMessageAndFail(msg, list(crefName),sourceInfo())
        end
      end
      if is_import
        foundScope = parent(node)
      elseif isInnerOuterNode(node)
        node = resolveInner(node)
        foundScope = parent(node)
      end
      state = nodeState(node)
      if state isa LOOKUP_STATE_ERROR
        foundScope = parentScope(foundScope)
        continue
      end
      cref = fromAbsyn(node, subs)
      stateRef.x = state
      scopeRef.x = foundScope
      return (node, cref)
    catch e
      foundScope = parentScope(foundScope)
      scopeRef.x = foundScope
    end
  end
  #= Recursion depth reached. Try builtins as last resort. =#
  res = lookupSimpleBuiltinCref(crefName, subs)
  if res !== nothing
    (node, cref, state) = res
    stateRef.x = state
    scopeRef.x = topScope(scope)
    return (node, cref)
  end
  Error.addMessage(Error.RECURSION_DEPTH_REACHED, list(String(Global.recursionDepthLimit), scopeName(foundScope)))
  fail()
end

"""
  This function look up a simple name as a cref in a given component, without
  searching in any enclosing scope.
"""
function lookupLocalSimpleCref(name::String, scope::InstNode)
  local foundScope::InstNode = scope
  local node::InstNode
  local is_import::Bool
  @match foundScope begin
    IMPLICIT_SCOPE(__)  => begin
      node = lookupIterator(name, foundScope.locals)
      is_import = false
    end

    CLASS_NODE(__)  => begin
      @match ENTRY_INFO(node, is_import) = lookupElement(name, getClass(foundScope))
    end

    COMPONENT_NODE(__)  => begin
      @match ENTRY_INFO(node, is_import) = lookupElement(name, getClass(foundScope))
    end

    INNER_OUTER_NODE(__)  => begin
      @match ENTRY_INFO(node, is_import) = lookupElement(name, getClass(foundScope.innerNode))
    end
  end
  if is_import
    foundScope = parent(node)
  elseif isInnerOuterNode(node)
    node = resolveInner(node)
    foundScope = parent(node)
  end
  #=  If the node is an outer node, return the inner instead.
  =#
  node, foundScope
end

function lookupIterator(iteratorName::String, iterators::Vector{<:InstNode})
  local it::InstNode
  for i in iterators
    if iteratorName == name(i)
#      #@info "Iterator located"
      it = i
      return it
    end
  end
  fail()
#  throw("Iterator lookup error") #Addition by me, John May 2021
end

function lookupIteratorNoFail(iteratorName::String, iterators::Vector{<:InstNode})
  local it::InstNode
  for i in iterators
    if iteratorName == name(i)
      it = i
      return it
    end
  end
  return EMPTY_NODE()
end

"""5-arg convenience overload: wraps Ref pattern and returns tuple"""
function lookupCrefInNode(cref::Absyn.ComponentRef,
                          node::InstNode,
                          foundCref::ComponentRef,
                          foundScope::InstNode,
                          state::LookupState)::Tuple{ComponentRef, InstNode, LookupState}
  local scopeRef = Ref{InstNode}(foundScope)
  local stateRef = Ref{LookupState}(state)
  foundCref = lookupCrefInNode(cref, node, foundCref, foundScope, state, scopeRef, stateRef)
  return (foundCref, scopeRef.x, stateRef.x)
end

function lookupCrefInNode(cref::Absyn.ComponentRef #=modification-040321=#,
                          node::InstNode,
                          foundCref::ComponentRef,
                          foundScope::InstNode,
                          state::LookupState,
                          scopeRef::Ref{InstNode},
                          stateRef::Ref{LookupState})::ComponentRef
  local scope::InstNode
  local n::InstNode
  local name::String
  local cls::Class
  local is_import::Bool
  if isError(state)
    scopeRef.x = foundScope
    stateRef.x = state
    return foundCref
  end
  scope = begin
    @match node begin
      CLASS_NODE(__)  => begin
        instPackage(node; isRedeclared = false)
      end
      _  => begin
        node
      end
    end
  end
  #= Reject name lookup inside a still-partial class/package (OMC parity:
     "%s is partial, name lookup is not allowed in partial classes"). A
     redeclared package resolves to its concrete target here, so this only
     fires for a genuinely-unredeclared partial default. =#
  if node isa CLASS_NODE && isPartial(scope)
    Error.addSourceMessageAndFail(
      Error.LOOKUP_IN_PARTIAL_CLASS, list(scopeName(scope)), sourceInfo())
  end
  name = AbsynUtil.crefFirstIdent(cref)
  cls = getClass(scope)
  @match ENTRY_INFO(n, is_import) = lookupElement(name, cls)
  if n isa EMPTY_NODE
    local wasComponent = isComponent(node)
    if !wasComponent
      fail()
    end
    local wasExpandableConnectorClass = isExpandableConnectorClass(cls)
    if !wasExpandableConnectorClass
      println(stderr, "[lookupCrefInNode FAIL] name='$name', cref=$(AbsynUtil.printComponentRefStr(cref)), node_name=$(node.name)")
      fail()
    end
    foundCref = fromAbsynCref(cref, foundCref)
    scopeRef.x = foundScope
    stateRef.x = state
    return foundCref
  end
  if is_import
    state = LOOKUP_STATE_ERROR(LOOKUP_STATE_IMPORT())
    foundCref = fromAbsyn(n, nil, foundCref)
    scopeRef.x = foundScope
    stateRef.x = state
    return foundCref
  end
  local wasInnerOuter = isInnerOuterNode(n)
   (n, foundCref, foundScope) = resolveInnerCref(n, foundCref, foundScope)
  #= Inner/outer access bypasses protection checks. A protected outer
     declaration resolves to its matching inner, which may also be
     protected, but the access is always legal through the outer link. =#
  state = next(n, state, !wasInnerOuter)
  (foundCref, foundScope, state) = begin
    @match cref begin
      Absyn.CREF_IDENT(__)  => begin
        (fromAbsyn(n, cref.subscripts, foundCref), foundScope, state)
      end

      Absyn.CREF_QUAL(__)  => begin
        foundCref = fromAbsyn(n, cref.subscripts, foundCref)
        foundCref = lookupCrefInNode(cref.componentRef, n, foundCref, foundScope, state, scopeRef, stateRef)
        (foundCref, scopeRef.x, stateRef.x)
      end
    end
  end
  scopeRef.x = foundScope
  stateRef.x = state
  return foundCref
end

"""
  If given an outer node, resolves it to the corresponding inner node and
  collapses the given cref so that it refers to the correct node. The scope a
  cref is found in may also change if the inner is outside the scope found by
  lookupCref.
"""
function resolveInnerCref(nodeVar::InstNode, cref::ComponentRef, foundScope::InstNode)
  local prev_node::InstNode
  local scope::InstNode
  if isInnerOuterNode(nodeVar)
    nodeVar = resolveInner(nodeVar)
    scope = parent(nodeVar)
    while ! isEmpty(cref)
      if referenceEq(node(cref), scope)
        break
      else
        cref = rest(cref)
      end
    end
    if isEmpty(cref)
      foundScope = scope
    end
  end
  (nodeVar, cref, foundScope)
end

"""
  Generates an inner element given an outer one, or returns the already
  generated inner element if one has already been generated.
"""
function generateInner(outerNode::InstNode, topScope::InstNode)
  local innerNode::InstNode
  local cache::CachedData
  local nameStr::String
  local inner_node::InstNode
  cache = getInnerOuterCache(topScope)
   () = begin
    @match cache begin
      C_TOP_SCOPE(__)  => begin
        nameStr = name(outerNode)
        local v = NodeTree.tryGet(cache.addedInner, nameStr)
        if v !== nothing
          innerNode = v
        else
          innerNode = makeInnerNode(outerNode)
          #= Fully qualify the typespec path before reparenting.
             The outer node's type path (e.g. Interfaces.CompositeStepState) is
             relative to the outer's original scope (e.g. Modelica.StateGraph).
             After setParent moves the node to the top-level model, this relative
             path would be looked up in the wrong scope. =#
          try
            local origScope = parent(outerNode)
            local comp = component(innerNode)
            if comp isa COMPONENT_DEF
              local def = comp.definition
              if def isa SCode.COMPONENT && def.typeSpec isa Absyn.TPATH
                local resolvedNode = lookupClassName(def.typeSpec.path, origScope, def.info, false)
                local qualPath = scopePath(resolvedNode)
                def = SCode.COMPONENT(def.name, def.prefixes, def.attributes,
                  Absyn.TPATH(qualPath, def.typeSpec.arrayDim),
                  def.modifications, def.comment, def.condition, def.info)
                #= Use updateComponent! (mutates pointer in place) instead of
                   replaceComponent (creates new node, does not mutate). =#
                updateComponent!(COMPONENT_DEF(def, comp.modifier), innerNode)
              end
            end
          catch e
            #= If lookup fails, proceed with the original relative path.
               The error will surface later during instComponent. =#
          end
          innerNode = setParent(cache.rootClass, innerNode)
          local addedInner = NodeTree.add(cache.addedInner, nameStr, innerNode)
          cache = C_TOP_SCOPE(addedInner, cache.rootClass)
          setInnerOuterCache(topScope, cache)
        end
        ()
      end
      _  => begin
        # Error.assertion(false, getInstanceName() + " got top node with missing cache", sourceInfo())
        @error " got top node with missing cache. Cache was:" * string(typeof(cache))
        fail()
      end
    end
  end
  innerNode
end

"""
  Returns a copy of the given node where the element definition has been
  changed to have the inner prefix.
"""
function makeInnerNode(nodeArg::InstNode)
  node = begin
    local def::SCode.Element
    local prefs::SCode.Prefixes
    local comp::Component
    @match nodeArg begin
      CLASS_NODE(definition = def && SCode.CLASS(prefixes = prefs))  => begin
        @assign prefs.innerOuter = Absyn.INNER()
        @assign def.prefixes = prefs
        nodeArg.definition = def
        nodeArg
      end
      COMPONENT_NODE(__)  => begin
        comp = component(nodeArg)
        comp = begin
          @match comp begin
            COMPONENT_DEF(definition = def && SCode.COMPONENT(prefixes = prefs))  => begin
              @assign prefs.innerOuter = Absyn.INNER()
              @assign def.prefixes = prefs
              COMPONENT_DEF(def, comp.modifier)
            end
            _  => begin
              #             Error.assertion(false, getInstanceName() + " got unknown component", sourceInfo())
              @error "Unknown component in makeInnerNode"
              fail()
            end
          end
        end
        replaceComponent(comp, nodeArg)
      end
      _  => begin
        #        Error.assertion(false, getInstanceName() + " got unknown node", sourceInfo())
        @error "Unknown node in makeInnerNode"
        fail()
      end
    end
  end
  node
end
