"""
The dynamic dispatch sites reachable from a call, by walking optimized typed code: from the root, every
`invoke`d method of the packages in `PACKAGES` is followed; a call that is neither an `invoke` nor a builtin
or intrinsic is a dynamic dispatch (the callee chosen at run time, compiled at run time for new argument types).
The walk also enters the methods a dynamic call can reach (at most `maxMatches` candidates per call).

    include("utilities/dynamicDispatch.jl")
    sites = DynamicDispatch.dynamicDispatchSites(OMFrontend.flattenModelWithLibraries, (String, String);
                                                 kw = (MSL = true, scalarize = false))
    DynamicDispatch.printSites(sites)

Each site: the method and source line of the call (the innermost inlined frame), the callee and argument types.
"""
module DynamicDispatch

import OMFrontend

const PACKAGES = Set{Symbol}([:OMFrontend, :ImmutableList, :MetaModelica])

"""The walk's result: each site (location and argument types) with its count, and the number of methods walked."""
const DispatchSites = NamedTuple{(:sites, :methods), Tuple{Vector{Pair{String, Int}}, Int}}

"""Whether a method belongs to one of `PACKAGES` (its module or a parent of it)."""
function inPackages(m::Method)::Bool
  local mod::Module = m.module
  while true
    nameof(mod) in PACKAGES && return true
    local p::Module = parentmodule(mod)
    p === mod && return false
    mod = p
  end
end

"""The type of a statement argument in optimized code (a lattice element widened to its type)."""
function argType(ci::Core.CodeInfo, @nospecialize(a), mi::Core.MethodInstance)::Type
  if a isa Core.SSAValue
    return Core.Compiler.widenconst(ci.ssavaluetypes[a.id])
  elseif a isa Core.Argument
    local sig::DataType = Base.unwrap_unionall(mi.specTypes)
    a.n <= length(sig.parameters) || return Any
    local p::Any = sig.parameters[a.n]
    return p isa Type ? p : Any
  elseif a isa GlobalRef
    return isdefined(a.mod, a.name) ? Core.Typeof(getglobal(a.mod, a.name)) : Any
  elseif a isa QuoteNode
    return Core.Typeof(a.value)
  else
    return Core.Typeof(a)
  end
end

"""The innermost source frame of statement `pc` (`file:line in function`), or the method's definition."""
function location(ci::Core.CodeInfo, mi::Core.MethodInstance, pc::Int)::String
  local frames::Vector{Any} = collect(Any, Base.IRShow.buildLineInfoNode(ci.debuginfo, mi, pc))
  if !isempty(frames)
    local f::Any = last(frames)
    local fn::Any = f.method isa Core.MethodInstance ? f.method.def.name : f.method
    return string(basename(string(f.file)), ":", f.line, " in ", fn)
  end
  local m::Method = mi.def
  return string(basename(string(m.file)), ":", m.line, " in ", m.name)
end

"""Whether a callee value is a builtin or intrinsic (no dispatch)."""
function isBuiltin(@nospecialize(f))::Bool
  return f isa Core.Builtin || f isa Core.IntrinsicFunction
end

"""Whether the first argument of an `invoke` statement names a method instance (a CodeInstance in Julia 1.12+)."""
function hasInvokedMI(@nospecialize(x))::Bool
  return x isa Core.MethodInstance || x isa Core.CodeInstance
end

"""The method instance an `invoke` statement calls (`hasInvokedMI` first)."""
function invokedMI(@nospecialize(x))::Core.MethodInstance
  x isa Core.MethodInstance && return x
  local d::Any = (x::Core.CodeInstance).def
  return d isa Core.MethodInstance ? d : d.def
end

"""The callee value of a `:call` statement's first argument; `nothing` (a value, not a Union return) when unbound."""
function calleeValue(@nospecialize(fa))::Any
  fa isa GlobalRef && return isdefined(fa.mod, fa.name) ? getglobal(fa.mod, fa.name) : nothing
  fa isa QuoteNode && return fa.value
  return fa
end

"""
The methods of `PACKAGES` a dynamic call with argument types `ats` (the callee's type first) can reach, at most
`maxMatches` (a call on `Any` arguments matches too many to follow), specialized to the declared signature.
"""
function pushMatches!(todo::Vector{Core.MethodInstance}, seen::Set{Core.MethodInstance}, ats::Vector{Type},
                      maxMatches::Int)::Nothing
  any(t -> t === Union{}, ats) && return nothing  # an argument that never returns: no call
  local matches::Any = Base._methods_by_ftype(Tuple{ats...}, maxMatches, Base.get_world_counter())
  matches isa Vector || return nothing  # false: more than maxMatches
  for m in matches
    local mm::Core.MethodMatch = m
    mm.method isa Method && inPackages(mm.method) || continue
    local mi::Core.MethodInstance = Core.Compiler.specialize_method(mm)
    mi in seen || push!(todo, mi)
  end
  return nothing
end

"""
    dynamicDispatchSites(f, types; kw, maxMethods, followDynamic, maxMatches) -> DispatchSites

From `f(types...; kw...)`, the dynamic call sites in the methods of `PACKAGES` it reaches. With `followDynamic` the
walk also enters the methods a dynamic call can reach (`pushMatches!`), not only `invoke`d ones.
"""
function dynamicDispatchSites(@nospecialize(f), @nospecialize(types::Tuple); kw::NamedTuple = NamedTuple(),
                              maxMethods::Int = 20000, followDynamic::Bool = true, maxMatches::Int = 8)::DispatchSites
  local tt::Type = isempty(kw) ? Tuple{Core.Typeof(f), types...} :
                                 Tuple{typeof(Core.kwcall), typeof(kw), Core.Typeof(f), types...}
  local todo::Vector{Core.MethodInstance} = Core.MethodInstance[]
  for m in Base._methods_by_ftype(tt, -1, Base.get_world_counter())
    push!(todo, Core.Compiler.specialize_method(m))
  end
  local seen::Set{Core.MethodInstance} = Set{Core.MethodInstance}()
  local sites::Dict{String, Int} = Dict{String, Int}()
  while !isempty(todo) && length(seen) < maxMethods
    local mi::Core.MethodInstance = pop!(todo)
    mi in seen && continue
    push!(seen, mi)
    mi.def isa Method || continue
    for (ci, _) in Base.code_typed_by_type(mi.specTypes; optimize = true)
      ci isa Core.CodeInfo || continue
      for (pc, st) in enumerate(ci.code)
        st isa Expr || continue
        if st.head === :invoke
          hasInvokedMI(st.args[1]) || continue
          local callee::Core.MethodInstance = invokedMI(st.args[1])
          if callee.def isa Method && inPackages(callee.def) && !(callee in seen)
            push!(todo, callee)
          end
        elseif st.head === :call
          local fa::Any = st.args[1]
          (fa isa Core.SSAValue || fa isa Core.Argument) || !isBuiltin(calleeValue(fa)) || continue
          local ats::Vector{Type} = Type[argType(ci, a, mi) for a in st.args]
          local key::String = string(location(ci, mi, pc), "  ", join(string.(ats), ", "))
          sites[key] = get(sites, key, 0) + 1
          followDynamic && pushMatches!(todo, seen, ats, maxMatches)
        end
      end
    end
  end
  return (sites = sort!(collect(sites); by = first), methods = length(seen))
end

"""The number of methods walked and sites, then one line per site (location, callee and argument types)."""
function printSites(r::DispatchSites; io::IO = stdout)::Nothing
  println(io, r.methods, " methods walked, ", length(r.sites), " dynamic call sites")
  for (k, _) in r.sites
    println(io, k)
  end
  return nothing
end

end
