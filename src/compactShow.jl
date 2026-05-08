#= -----------------------------------------------------------------------------
   Compact REPL display for heavy NewFrontend abstract types.

   Inspecting an InstNode / NFExpression / NFType / Component / etc. at the
   REPL triggers Julia's default `show_default`, which recursively prints
   every field — producing thousands of lines for a typical instantiation
   tree. The big-hammer overrides below register a compact
   `Base.show(io, ::MIME"text/plain", x)` for every heavy abstract supertype
   in the `Frontend` module so the REPL prints `TypeName(<short-id>)` by
   default.

   Toggle with `OMFrontend.verboseShow!(true|false)` — default is verbose-OFF
   (compact). Per-call override via IOContext:

       show(IOContext(stdout, :verbose => true), MIME"text/plain"(), x)

   `dump(x)`, `print(x)`, and `println(x)` are intentionally untouched and
   always show the full structure, so explicit deep inspection still works.
   `FLAT_MODEL` retains its flat-Modelica string display, registered in
   OMFrontend.jl alongside the rest of the public API.

   This file is included from OMFrontend.jl AFTER main.jl, so the `Frontend`
   module and its abstract supertypes are already defined.
   ----------------------------------------------------------------------- =#

const COMPACT_SHOW = Ref(true)

"""
    OMFrontend.verboseShow!(b::Bool = true) -> Bool

Enable (`b = true`) or disable (`b = false`) verbose REPL display for
OMFrontend's heavy abstract types: `NFExpression`, `NFType`, `InstNode`,
`Component`, `Class`, `NFEquation`, `NFOperator`, `NFAlgorithm`,
`NFComponentRef`, `Call`, `CallAttributes`, `ClassTree`, `Modifier`,
`NFSections`, `Equation_Branch`, `Attributes`.

When verbose is OFF (the default), inspecting any of those types at the REPL
prints `TypeName(<name-or-ident>)` instead of recursively dumping every
field. `dump(x)`, `print(x)`, and `println(x)` are unaffected and always
show the full structure.

Returns the new verbose flag value (true = verbose, false = compact).

# Examples
```
julia> OMFrontend.verboseShow!()        # turn ON verbose display
julia> OMFrontend.verboseShow!(false)   # back to compact (default)
```
"""
verboseShow!(b::Bool = true) = (COMPACT_SHOW[] = !b; b)

"""
    OMFrontend.isVerboseShow() -> Bool

Return whether verbose REPL display is currently enabled.
"""
isVerboseShow() = !COMPACT_SHOW[]

_omfShouldBeVerbose(io::IO)::Bool = get(io, :verbose, !COMPACT_SHOW[])

function _omfCompactShow(io::IO, x)
  local T = typeof(x)
  print(io, nameof(T))
  if isstructtype(T) && fieldcount(T) > 0
    for fname in (:name, :ident, :identifier, :label)
      if hasfield(T, fname)
        local fv = getfield(x, fname)
        if fv isa Union{AbstractString, Symbol}
          print(io, "(", fv, ")")
          return nothing
        end
      end
    end
    print(io, "(<", fieldcount(T), " fields>)")
  end
  return nothing
end

function _omfShow(io::IO, mime::MIME"text/plain", x)
  if _omfShouldBeVerbose(io)
    invoke(show, Tuple{IO, MIME"text/plain", Any}, io, mime, x)
  else
    _omfCompactShow(io, x)
  end
end

#= Big hammer: register a compact MIME"text/plain" show for every heavy
   abstract supertype in the Frontend module. =#
for _omfHeavyType in (:NFExpression, :NFType, :InstNode, :Component, :Class,
                      :NFEquation, :NFOperator, :NFAlgorithm, :NFComponentRef,
                      :Call, :CallAttributes, :ClassTree, :Modifier,
                      :NFSections, :Equation_Branch, :Attributes)
  @eval Base.show(io::IO, mime::MIME"text/plain", x::Frontend.$_omfHeavyType) =
    _omfShow(io, mime, x)
end
