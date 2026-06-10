#=
  02_load_single_file_library.jl

  Load a user library that lives in a single `.mo` file via `loadLibrary`,
  then flatten a model that depends on it.

  `loadLibrary` returns the cache key under which the library is stored in
  `OMFrontend.LIBRARY_CACHE`. By default the key is the top-level class name
  inside the loaded file; override with the `name = ...` keyword if needed.
=#

using OMFrontend

const HERE     = @__DIR__
const LIB_FILE = joinpath(HERE, "MyLib.mo")
const USE_FILE = joinpath(HERE, "Models", "UseMyLib.mo")

libKey = OMFrontend.loadLibrary(LIB_FILE)
@info "Loaded library under cache key: $libKey"

(fm, _funcs) = OMFrontend.flattenModelWithLibraries(
  "UseMyLib",
  USE_FILE;
  libraries = [libKey],
)

println("=== Flat model that consumes MyLib ===")
println(OMFrontend.toString(fm))
