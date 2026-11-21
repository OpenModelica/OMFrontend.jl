"""
Cold flatten times of MSL models in a fresh process: the first and the second flatten of each model after
`using OMFrontend` and the MSL load (both timed apart, not counted in the flatten). The difference of the two
runs is the compilation a model still needs at run time.

    julia --project=<env> utilities/coldFlatten.jl <models.txt> <out.tsv> [scalarize|arrays|both]

With `--trace-compile=<file> --trace-compile-timing` the process also writes the precompile statements of
everything it compiles (`utilities/precompileStatements.jl` turns them into `src/precompileStatements.jl`).
Writes one line per model and mode: model, mode, first run s, second run s.
"""
const T_USING = @elapsed using OMFrontend

function flattenOnce(model::String, scalarize::Bool)::Float64
  return @elapsed redirect_stdio(stdout = devnull, stderr = devnull) do
    OMFrontend.flattenModelWithLibraries(model, ""; MSL = true, MSL_Version = "MSL:4.1.0", scalarize = scalarize)
  end
end

function main(args::Vector{String})::Nothing
  local models::Vector{String} = [String(strip(l)) for l in eachline(args[1]) if !isempty(strip(l))]
  local modes::Vector{Bool} = get(args, 3, "both") == "scalarize" ? [true] :
                              get(args, 3, "both") == "arrays" ? [false] : [true, false]
  local tLoad::Float64 = @elapsed redirect_stdio(stdout = devnull, stderr = devnull) do
    OMFrontend.loadBundledMSL(version = "MSL:4.1.0")
  end
  println("using OMFrontend ", round(T_USING; digits = 2), " s, MSL load ", round(tLoad; digits = 2), " s")
  open(args[2], "w") do io
    for m in models, s in modes
      local mode::String = s ? "scalarize" : "arrays"
      local t1::Float64 = NaN
      local t2::Float64 = NaN
      try
        t1 = flattenOnce(m, s)
        t2 = flattenOnce(m, s)
      catch e
        println("FAILED ", m, " ", mode, ": ", first(sprint(showerror, e), 200))
      end
      println(io, m, '\t', mode, '\t', t1, '\t', t2)
      println(rpad(split(m, '.')[end], 34), rpad(mode, 10), lpad(round(t1; digits = 3), 8), lpad(round(t2; digits = 3), 8))
    end
  end
  return nothing
end

main(ARGS)
