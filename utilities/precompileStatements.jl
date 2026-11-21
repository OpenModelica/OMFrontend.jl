using OMFrontend
"""The modules a statement may name: those loaded with OMFrontend, as when it precompiles."""
const ROOTS = Set{Symbol}([nameof(m) for m in values(Base.loaded_modules)]) ∪ Set([:Base, :Core])

"""The modules loaded with OMFrontend under their names, as `src/precompilation.jl` binds them."""
module PrecompileNames
  import OMFrontend
  for m in values(Base.loaded_modules)
    isdefined(@__MODULE__, nameof(m)) || Core.eval(@__MODULE__, :(const $(nameof(m)) = $m))
  end
end

"""Whether a statement resolves and compiles, as `runPrecompileStatements` runs it."""
function runs(stmt::String)::Bool
  try
    return Core.eval(PrecompileNames, Meta.parse(stmt))::Bool
  catch
    return false
  end
end

"""The leftmost names of the qualified names (`A.B.c` gives `A`) in a statement."""
function rootNames!(roots::Set{Symbol}, @nospecialize(ex))::Set{Symbol}
  if ex isa Expr
    if ex.head === :. && length(ex.args) == 2 && ex.args[2] isa QuoteNode
      local r = ex.args[1]
      while r isa Expr && r.head === :.
        r = r.args[1]
      end
      r isa Symbol && push!(roots, r)
      r isa Expr && rootNames!(roots, r)
    else
      for a in ex.args
        rootNames!(roots, a)
      end
    end
  end
  return roots
end

"""
Turns `--trace-compile --trace-compile-timing` output of cold flattens (`utilities/coldFlatten.jl`) into
`src/precompileStatements.txt`, the statements `src/precompilation.jl` runs while OMFrontend precompiles.

    julia --project=<env> utilities/precompileStatements.jl <out.txt> <trace.jl>...

Kept: statements whose names all come from modules loaded with OMFrontend (its dependencies, as when it
precompiles), deduplicated, the most expensive first. Dropped: `Main` (the driver script), other packages, and
statements that no longer resolve or compile (names changed since the trace).
"""
function main(args::Vector{String})::Nothing
  local best::Dict{String, Float64} = Dict{String, Float64}()
  local dropped::Int = 0
  for file in args[2:end], line in eachline(file)
    local m = match(r"^#=\s*([\d.]+)\s*ms\s*=#\s*(precompile\(.*\))(\s*#.*)?$", line)
    m === nothing && continue
    #= The trace prints a Char by its bits (`Char(0x67000000)` for 'g'), which Char(::UInt32) reads as a code point. =#
    local stmt::String = replace(m.captures[2], r"Char\((0x[0-9a-f]{8})\)" => s"reinterpret(Char, \1)")
    local ex = Meta.parse(stmt; raise = false)
    local roots::Set{Symbol} = rootNames!(Set{Symbol}(), ex)
    if !(:Main in roots) && issubset(roots, ROOTS) && (haskey(best, stmt) || runs(stmt))
      best[stmt] = max(get(best, stmt, 0.0), parse(Float64, m.captures[1]))
    else
      dropped += 1
    end
  end
  local stmts::Vector{Pair{String, Float64}} = sort!(collect(best); by = last, rev = true)
  open(args[1], "w") do io
    for (s, _) in stmts
      println(io, s)
    end
  end
  println(length(stmts), " statements (", round(sum(last, stmts; init = 0.0); digits = 0), " ms traced), ", dropped,
          " dropped")
  return nothing
end

main(ARGS)
