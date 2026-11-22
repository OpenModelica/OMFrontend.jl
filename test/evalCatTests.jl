#=
Ceval's evalCat (cat(dim, ...) of constant arrays) against Base.cat: the row-major elements at depth dim and the sizes,
for an argument of fewer dimensions (promoted), several 1x1 parts, cat along the third dimension, and arguments of more
dimensions than dim (the elements stay arrays).
=#

import ImmutableList

const EVALCAT_F = OMFrontend.Frontend

"""A nested array expression of the integers of `a` (the first index outermost, as Modelica's `{{...}}`)."""
function evalCatExp(a::AbstractArray{Int})::EVALCAT_F.Expression
  ndims(a) == 0 && return EVALCAT_F.INTEGER_EXPRESSION(a[])
  local elems::Vector{EVALCAT_F.Expression} = EVALCAT_F.Expression[]
  for i in axes(a, 1)
    push!(elems, ndims(a) == 1 ? EVALCAT_F.INTEGER_EXPRESSION(a[i]) : evalCatExp(selectdim(a, 1, i)))
  end
  local dims::ImmutableList.List{EVALCAT_F.Dimension} = ImmutableList.nil
  for n in reverse(size(a))
    dims = ImmutableList.Cons{EVALCAT_F.Dimension}(EVALCAT_F.fromInteger(n), dims)
  end
  return EVALCAT_F.ARRAY_EXPRESSION(EVALCAT_F.TYPE_ARRAY(EVALCAT_F.TYPE_INTEGER(), dims), elems, true)
end

"""The integers of an expression in row-major order."""
function evalCatInts(e::EVALCAT_F.Expression)::Vector{Int}
  e isa EVALCAT_F.INTEGER_EXPRESSION && return Int[e.value]
  local out::Vector{Int} = Int[]
  for x in (e::EVALCAT_F.ARRAY_EXPRESSION).elements
    append!(out, evalCatInts(x))
  end
  return out
end

"""Whether `evalCat(dim, args)` gives the depth-`dim` elements and sizes of `Base.cat(expected...; dims = dim)`."""
function evalCatMatches(dim::Int, args::Vector{<:AbstractArray{Int}}, expected::Vector{<:AbstractArray{Int}})::Bool
  local (elems::Vector{EVALCAT_F.Expression}, sizes::ImmutableList.List{Int}) = EVALCAT_F.evalCat(dim, EVALCAT_F.Expression[evalCatExp(a) for a in args])
  local c::Array{Int} = Base.cat(expected...; dims = dim)
  local flat::Vector{Int} = Int[]
  for e in elems
    append!(flat, evalCatInts(e))
  end
  return collect(sizes) == collect(size(c)[1:dim]) && length(elems) == prod(size(c)[1:dim]) &&
         flat == vec(permutedims(c, ndims(c):-1:1))
end

@testset "evalCat" begin
  local A::Matrix{Int} = [1 2; 3 4]
  local v::Vector{Int} = [5, 6]
  @test evalCatMatches(2, [A, v], [A, reshape(v, 2, 1)])
  @test evalCatMatches(2, [fill(1, 1, 1), fill(2, 1, 1), fill(3, 1, 1)], [fill(1, 1, 1), fill(2, 1, 1), fill(3, 1, 1)])
  local a3::Array{Int, 3} = reshape(collect(1:4), 2, 1, 2)
  local b3::Array{Int, 3} = reshape(collect(5:12), 2, 2, 2)
  local c3::Array{Int, 3} = reshape(collect(13:16), 2, 2, 1)
  @test evalCatMatches(3, [c3, b3], [c3, b3])
  @test evalCatMatches(2, [a3, b3], [a3, b3])
  @test evalCatMatches(1, [A, [7 8]], [A, [7 8]])
end
