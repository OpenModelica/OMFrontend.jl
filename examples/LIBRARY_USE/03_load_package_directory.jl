#=
  03_load_package_directory.jl

  Load a directory-style Modelica package via `loadPackageDirectory`.
  The directory must contain a top-level `package.mo` declaring the package
  name. Sub-files may declare `within <Pkg>;` and live either as flat `.mo`
  files or under nested directories with their own `package.mo`.

  `package.order` (one class name per line) controls the order in which
  child files are merged; entries not listed are appended in alphabetical
  order. See `MyPkg/package.order`.
=#

using OMFrontend

const HERE     = @__DIR__
const PKG_DIR  = joinpath(HERE, "MyPkg")
const USE_FILE = joinpath(HERE, "Models", "UseMyPkg.mo")

libKey = OMFrontend.loadPackageDirectory(PKG_DIR)
@info "Loaded directory package under cache key: $libKey"

(fm, _funcs) = OMFrontend.flattenModelWithLibraries(
  "UseMyPkg",
  USE_FILE;
  libraries = [libKey],
)

println("=== Flat model that consumes MyPkg ===")
println(OMFrontend.toString(fm))
