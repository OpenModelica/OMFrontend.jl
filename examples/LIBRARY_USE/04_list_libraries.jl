#=
  04_list_libraries.jl

  Discover the Modelica libraries that OMFrontend can load on this machine.

  `OMFrontend.libraries()` looks in two places:
    * `~/.openmodelica/libraries/`         (source = :installed)
    * the bundled `lib/Modelica/` folder    (source = :bundled)

  The return value is a `Dict{String, Vector{NamedTuple}}` keyed by library
  name; each entry lists the discovered versions and where they came from.
=#

using OMFrontend

avail = OMFrontend.libraries()

if isempty(avail)
  @info "No Modelica libraries discovered."
else
  println("Found $(length(avail)) library name(s):\n")
  for name in sort(collect(keys(avail)))
    println("  $name")
    for entry in avail[name]
      ver = isempty(entry.version) ? "(unversioned)" : entry.version
      println("    - $ver  [$(entry.source)]  $(entry.path)")
    end
  end
end
