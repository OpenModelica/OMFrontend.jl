#=
  The tests of OMFrontend.ListUtil, run first in OMFrontend's tests: each function on small lists, the values of
  OpenModelica's List package, and the cell types of the results (a list built with element type TO has Cons{TO}
  cells, so it is stored in a List{TO} without a copy).
  The module keeps the helpers of the tests out of the namespace of the other test files.
=#
module ListUtilTests

using Test
import OMFrontend.ListUtil
using MetaModelica

"""The elements of a list (nested lists too) in a Vector, to compare with a Julia array."""
toVec(x) = x
toVec(l::Union{Nil, Cons}) = Any[toVec(e) for e in l]
toVec(t::Tuple) = Any[toVec(e) for e in t]

"""True if every cell of `l` is a `Cons{TO}`."""
cellsOf(l::Nil, ::Type{TO}) where {TO} = true
cellsOf(l::Cons, ::Type{TO}) where {TO} = l isa Cons{TO} && cellsOf(l.tail, TO)

const L5 = list(1, 2, 3, 4, 5)
const LN = Cons{Number}(1, Cons{Number}(2.5, Cons{Number}(3, nil)))
gt(a, b) = a > b

@testset "Creating and taking apart" begin
  @test toVec(ListUtil.fill(2, 3, Int)) == [2, 2, 2]
  @test ListUtil.fill(2, 0, Int) === nil
  @test toVec(ListUtil.consOnTrue(true, 0, L5, Int)) == [0, 1, 2, 3, 4, 5]
  @test ListUtil.consOnTrue(false, 0, L5, Int) === L5
  @test toVec(ListUtil.append_reverse(list(1, 2), list(3), Int)) == [2, 1, 3]
  @test ListUtil.append_reverse(nil, L5, Int) === L5
  @test toVec(ListUtil.set(list(2, 1, 4, 2), 2, 3, Int)) == [2, 3, 4, 2]
  @test toVec(ListUtil.rest(L5)) == [2, 3, 4, 5]
  @test ListUtil.last(L5) == 5
  @test toVec(ListUtil.firstN(L5, 2, Int)) == [1, 2]
  @test toVec(ListUtil.lastN(L5, 2)) == [4, 5]
  @test toVec(ListUtil.stripN(L5, 3)) == [4, 5]
  @test ListUtil.stripFirst(nil) === nil
  @test toVec(ListUtil.split(list(1, 2, 5, 7), 2, Int)) == [[1, 2], [5, 7]]
  @test toVec(ListUtil.splitr(list(1, 2, 5, 7), 2, Int)) == [[2, 1], [5, 7]]
  @test toVec(ListUtil.splitOnTrue(L5, iseven, Int)) == [[2, 4], [1, 3, 5]]
  @test toVec(ListUtil.splitLast(list(3, 5, 7), Int)) == [7, [3, 5]]
  @test toVec(ListUtil.partition(L5, 2, Int)) == [[1, 2], [3, 4], [5]]
  @test toVec(ListUtil.trim(list(2, 4, 3, 6), iseven)) == [3, 6]
  @test toVec(ListUtil.filterOnTrue(list(1, 2, 3, 4), iseven, Int)) == [2, 4]
  @test ListUtil.hasOneElement(list(1)) && !ListUtil.hasOneElement(L5) && !ListUtil.hasOneElement(nil)
  @test_throws Exception ListUtil.firstN(L5, 6, Int)
  @test_throws Exception ListUtil.last(nil)
end

@testset "Sorting, unique elements and unions" begin
  @test toVec(ListUtil.sort(list(2, 1, 3), gt, Int)) == [1, 2, 3]
  @test toVec(ListUtil.sort(list(2, 1, 3), (a, b) -> a < b, Int)) == [3, 2, 1]
  @test toVec(ListUtil.sortedUnique(list(1, 1, 2, 3, 3), ==, Int)) == [1, 2, 3]
  @test toVec(ListUtil.uniqueOnTrue(list(3, 1, 2, 3, 1), ==, Int)) == [3, 1, 2]
  @test toVec(ListUtil.unionEltOnTrue(2, list(1, 2), ==, Int)) == [1, 2]
  @test toVec(ListUtil.unionEltOnTrue(0, list(1, 2), ==, Int)) == [0, 1, 2]
  @test toVec(ListUtil.union(list(0, 1), list(2, 1), Int)) == [0, 1, 2]
  @test toVec(ListUtil.unionOnTrue(list(1, 2), list(2, 3), ==, Int)) == [1, 2, 3]
end

@testset "Mapping" begin
  @test toVec(ListUtil.map(L5, string, String)) == ["1", "2", "3", "4", "5"]
  @test toVec(ListUtil.map1(list(1, 2), +, 10, Int)) == [11, 12]
  @test toVec(ListUtil.map2(list(1, 2), (x, a, b) -> x + a + b, 1, 2, Int)) == [4, 5]
  @test toVec(ListUtil.map3(list(1), (x, a, b, c) -> x + a + b + c, 1, 2, 3, Int)) == [7]
  @test toVec(ListUtil.mapMap(list(1, 22), string, length, Int)) == [1, 2]
  local seen = Int[]
  ListUtil.map1_0(list(1, 2), (x, a) -> push!(seen, x + a), 1)
  @test seen == [2, 3]
  @test toVec(ListUtil.map1_2(list(1, 2), (x, a) -> (x, x + a), 1, Int, Int)) == [[1, 2], [2, 3]]
  @test toVec(ListUtil.map2Option(Cons{Option{Int}}(SOME(1), Cons{Option{Int}}(NONE(), nil)), (x, a, b) -> x + a + b, 1, 2, Int)) == [4]
  #= OpenModelica's mapFlat: the reverse of listAppend(f(2), listAppend(f(1), {})) = reverse({2, 0, 1, 0}). =#
  @test toVec(ListUtil.mapFlat(list(1, 2), x -> list(x, 0), Int)) == [0, 1, 0, 2]
  @test toVec(ListUtil.mapList(list(list(1, 2), list(3)), string, String)) == [["1", "2"], ["3"]]
  @test toVec(ListUtil.map2List(list(list(1), list(2)), (x, a, b) -> x + a + b, 1, 2, Int)) == [[4], [5]]
  @test ListUtil.mapAllValueBool(L5, x -> x > 0, true)
  @test !ListUtil.mapAllValueBool(L5, x -> x > 2 ? error("x") : true, true)
end

@testset "Folding" begin
  @test ListUtil.fold(list(1, 2, 3), +, 2, Int) == 8
  @test ListUtil.foldr(list("a", "b"), *, "", String) == "ab"
  @test ListUtil.fold1(list(1, 2), (e, x, a) -> a + e * x, 10, 0, Int) == 30
  @test ListUtil.foldList1(list(list(1, 2), list(3)), (e, x, a) -> a + e * x, 2, 0, Int) == 12
  @test ListUtil.applyAndFold(list("a", "bb"), +, length, 0, Int) == 3
  @test ListUtil.reduce(list(1, 2, 3), +, Int) == 6
  @test toVec(ListUtil.mapFold(list(1, 2), (e, a) -> (e + a, a + 1), 0, Int, Int)) == [[1, 3], 2]
  @test toVec(ListUtil.mapFoldSO(list(1, 2), +, 10, Int)) == [11, 12]
  @test toVec(ListUtil.map1Fold(list(1, 2), (e, c, a) -> (e * c, a + 1), 3, 0, Int, Int)) == [[3, 6], 2]
  #= map2FoldCheckReferenceEq returns its input when no element changes, a new list when one does. =#
  local lst = Cons{Number}(1, Cons{Number}(2, nil))
  @test first(ListUtil.map2FoldCheckReferenceEq(lst, (e, c, d, a) -> (e, a + 1), 0, 0, 0, Number, Int)) === lst
  @test toVec(ListUtil.map2FoldCheckReferenceEq(lst, (e, c, d, a) -> (a == 1 ? e + 10 : e, a + 1), 0, 0, 0, Number, Int)) == [[1, 12], 2]
  @test_throws Exception ListUtil.reduce(nil, +, Int)
end

@testset "Joining lists" begin
  @test toVec(ListUtil.flatten(list(list(1, 2), list(3, 4, 5), list(6), nil), Int)) == [1, 2, 3, 4, 5, 6]
  @test toVec(ListUtil.flattenReverse(list(list(1, 2), list(3)), Int)) == [3, 1, 2]
  @test collect(ListUtil.threadTuple(list(1, 2), list(true, false), Tuple{Int, Bool})) == [(1, true), (2, false)]
  @test ListUtil.threadMapAllValue(list(1, 2), list(1, 2), ==, true) === nothing
  @test_throws Exception ListUtil.threadMapAllValue(list(1, 2), list(1), ==, true)
  @test ListUtil.isEqualOnTrue(list(1, 2), list(1, 2), ==)
  @test !ListUtil.isEqualOnTrue(list(1, 2), list(1), ==)
end

@testset "Searching" begin
  @test ListUtil.all(L5, x -> x > 0) && !ListUtil.all(L5, iseven)
  @test ListUtil.exist(L5, iseven) && !ListUtil.exist(nil, iseven)
  @test ListUtil.exist1(L5, ==, 3)
  @test ListUtil.isMemberOnTrue(3, L5, ==) && !ListUtil.isMemberOnTrue(9, L5, ==)
  @test ListUtil.getMemberOnTrue(3, L5, ==) == 3
  @test ListUtil.find(L5, iseven) == 2
  @test ListUtil.find1(L5, ==, 4) == 4
  @test ListUtil.findOption(L5, x -> x > 3) == SOME(4)
  @test ListUtil.findOption(L5, x -> x > 9) === NONE()
  @test ListUtil.positionOnTrue(L5, x -> x == 3) == 3
  @test ListUtil.positionOnTrue(L5, x -> x == 9) == -1
  @test_throws Exception ListUtil.find(L5, x -> x > 9)
end

@testset "Removing, replacing, strings" begin
  local (rest, deleted) = ListUtil.deleteMemberOnTrue(2, list(1, 2, 3, 2), ==, Int)
  @test toVec(rest) == [1, 3, 2]
  @test deleted == SOME(2)
  @test last(ListUtil.deleteMemberOnTrue(9, L5, ==, Int)) === NONE()
  @test toVec(first(ListUtil.replaceOnTrue(4, list(1, 2, 3), x -> x == 2, Int))) == [1, 4, 3]
  @test !last(ListUtil.replaceOnTrue(4, list(1, 2, 3), x -> x == 9, Int))
  @test ListUtil.toString(list(1, 2, 3), string, "nums", "{", ";", "}", true) == "nums{1;2;3}"
  @test ListUtil.toString(nil, string, "nums", "{", ";", "}", true) == "nums{}"
  @test ListUtil.toString(nil, string, "nums", "{", ";", "}", false) == "nums"
end

@testset "Cell types: built lists have Cons{TO} cells" begin
  @test cellsOf(ListUtil.map(list(1, 2), x -> x, Number), Number)
  @test cellsOf(ListUtil.firstN(L5, 3, Integer), Integer)
  @test cellsOf(ListUtil.flatten(list(list(1), list(2, 3)), Number), Number)
  @test cellsOf(first(ListUtil.mapFold(list(1, 2), (e, a) -> (e, a), 0, Integer, Int)), Integer)
  @test cellsOf(ListUtil.sort(LN, gt, Number), Number)
  @test cellsOf(ListUtil.uniqueOnTrue(LN, ==, Number), Number)
  #= An input that already has Cons{TO} cells is shared, not copied. =#
  @test ListUtil.append_reverse(nil, LN, Number) === LN
  @test ListUtil.consOnTrue(true, 0, LN, Number).tail === LN
  @test first(ListUtil.map2FoldCheckReferenceEq(LN, (e, c, d, a) -> (e, a), 0, 0, 0, Number, Int)) === LN
end

end # module ListUtilTests
