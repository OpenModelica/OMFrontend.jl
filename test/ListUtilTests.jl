#=
  The tests of the ListUtil package (formerly ListUtil.jl, now OMFrontend.ListUtil), run first in OMFrontend's tests.
  The module keeps the helpers of the tests out of the namespace of the other test files.
=#
module ListUtilTests

using Test
import OMFrontend.ListUtil
using MetaModelica

# Convert a MetaModelica List into a Vector so we can compare against a plain
# Julia array. Using listLength + listGet keeps the test independent of any
# Cons/Nil equality details.
function listToVec(lst)
    n = listLength(lst)
    v = Vector{Any}(undef, n)
    cur = lst
    for i in 1:n
        v[i] = listHead(cur)
        cur = listRest(cur)
    end
    return v
end

# Recursive variant for nested lists (List{List{T}}).
function nestedToVec(lst)
    n = listLength(lst)
    v = Vector{Any}(undef, n)
    cur = lst
    for i in 1:n
        h = listHead(cur)
        v[i] = h isa Nil || h isa Cons ? nestedToVec(h) : h
        cur = listRest(cur)
    end
    return v
end

# Strict ordering used by sort: returns true when b should come AFTER a in the
# result (matches the OpenModelica intGt convention used in the docstrings).
gt(a, b) = a > b
lt(a, b) = a < b

@testset "ListUtil smoke" begin
    @test isdefined(ListUtil, :map)
    @test isdefined(ListUtil, :fold)
    @test isdefined(ListUtil, :filterOnTrue)

    lst = list(1, 2, 3, 4)

    @test listToVec(ListUtil.map(lst, x -> x + 1)) == [2, 3, 4, 5]
    @test ListUtil.fold(lst, (x, acc) -> x + acc, 0) == 10
    @test listToVec(ListUtil.filterOnTrue(lst, iseven)) == [2, 4]

    empty = list()
    @test listLength(ListUtil.map(empty, x -> x + 1)) == 0
    @test ListUtil.fold(empty, (x, acc) -> x + acc, 0) == 0
end

@testset "Construction" begin
    @test listToVec(ListUtil.create(7)) == [7]
    @test listToVec(ListUtil.create2(7, 9)) == [7, 9]
    @test listToVec(ListUtil.fill("x", 3)) == ["x", "x", "x"]
    @test listLength(ListUtil.fill(0, 0)) == 0

    @test listToVec(ListUtil.intRange(0)) == Int[]
    @test listToVec(ListUtil.intRange(4)) == [1, 2, 3, 4]
    @test listToVec(ListUtil.intRange2(3, 5)) == [3, 4, 5]
    @test listToVec(ListUtil.intRange2(3, 3)) == [3]
    @test listToVec(ListUtil.intRange3(3, 2, 9)) == [3, 5, 7, 9]
    @test listToVec(ListUtil.intRange3(1, 1, 5)) == [1, 2, 3, 4, 5]

    @test ListUtil.toOption(list()) == NONE()
    @test ListUtil.toOption(list(42)) == SOME(42)
    @test listToVec(ListUtil.fromOption(SOME(42))) == [42]
end

@testset "Cons operations" begin
    @test listToVec(ListUtil.consr(list(2, 3), 1)) == [1, 2, 3]
    @test listToVec(ListUtil.consOnTrue(true, 1, list(2, 3))) == [1, 2, 3]
    @test listToVec(ListUtil.consOnTrue(false, 1, list(2, 3))) == [2, 3]
    @test listToVec(ListUtil.consOption(SOME(1), list(2, 3))) == [1, 2, 3]
    @test listToVec(ListUtil.consOption(NONE(), list(2, 3))) == [2, 3]
    @test listToVec(ListUtil.consN(3, 7, list(1, 2))) == [7, 7, 7, 1, 2]

    let (t, f) = ListUtil.consOnBool(true, 1, list(2), list(3))
        @test listToVec(t) == [1, 2]
        @test listToVec(f) == [3]
    end
    let (t, f) = ListUtil.consOnBool(false, 1, list(2), list(3))
        @test listToVec(t) == [2]
        @test listToVec(f) == [1, 3]
    end

    succPred(x) = x > 0 ? true : error("not positive")
    @test listToVec(ListUtil.consOnSuccess(5, list(1, 2), succPred)) == [5, 1, 2]
    @test listToVec(ListUtil.consOnSuccess(-1, list(1, 2), succPred)) == [1, 2]
end

@testset "Equality and predicates" begin
    @test ListUtil.isEqual(list(1, 2, 3), list(1, 2, 3), true)
    @test !ListUtil.isEqual(list(1, 2, 3), list(1, 2, 4), true)
    @test !ListUtil.isEqual(list(1, 2, 3), list(1, 2), true)
    @test ListUtil.isEqual(list(1, 2, 3), list(1, 2), false)

    @test ListUtil.isEqualOnTrue(list(1, 2, 3), list(1.0, 2.0, 3.0), (a, b) -> a == b)
    @test !ListUtil.isEqualOnTrue(list(1, 2), list(1, 3), (a, b) -> a == b)

    @test ListUtil.isPrefixOnTrue(list(1, 2), list(1, 2, 3, 4), (a, b) -> a == b)
    @test !ListUtil.isPrefixOnTrue(list(1, 3), list(1, 2, 3, 4), (a, b) -> a == b)
    @test ListUtil.isPrefixOnTrue(list(), list(1, 2), (a, b) -> a == b)

    @test ListUtil.hasOneElement(list(1))
    @test !ListUtil.hasOneElement(list(1, 2))
    @test !ListUtil.hasOneElement(list())
    @test !ListUtil.hasSeveralElements(list())
    @test !ListUtil.hasSeveralElements(list(1))
    @test ListUtil.hasSeveralElements(list(1, 2))

    @test ListUtil.listIsLonger(list(1, 2, 3), list(1, 2))
    @test !ListUtil.listIsLonger(list(1, 2), list(1, 2, 3))

    @test ListUtil.all(list(2, 4, 6), iseven)
    @test !ListUtil.all(list(2, 3, 4), iseven)
    @test ListUtil.all(list(), iseven)

    @test ListUtil.exist(list(1, 2, 3), iseven)
    @test !ListUtil.exist(list(1, 3, 5), iseven)
    @test ListUtil.exist1(list(1, 2, 3), (e, k) -> e == k, 2)
    @test ListUtil.exist2(list(1, 2, 3), (e, a, b) -> a < e < b, 1, 3)

    @test ListUtil.notMember(0, list(1, 2, 3))
    @test !ListUtil.notMember(2, list(1, 2, 3))
    @test ListUtil.isMemberOnTrue(2, list(1, 2, 3), (a, b) -> a == b)
    @test !ListUtil.isMemberOnTrue(9, list(1, 2, 3), (a, b) -> a == b)

    let l::List{List{Int}} = list(list(1, 2), list(3), list(4, 5, 6))
        @test ListUtil.lengthListElements(l) == 6
    end
end

@testset "Append" begin
    @test listToVec(ListUtil.append_reverse(list(1, 2, 3), list(4, 5))) == [3, 2, 1, 4, 5]
    @test listToVec(ListUtil.append_reverser(list(1, 2), list(3, 4))) == [4, 3, 1, 2]
    @test listToVec(ListUtil.appendr(list(1, 2), list(3, 4))) == [3, 4, 1, 2]
    @test listToVec(ListUtil.appendElt(99, list(1, 2, 3))) == [1, 2, 3, 99]

    let l::List{List{Int}} = list(list(1, 2), list(3))
        @test nestedToVec(ListUtil.appendLastList(l, list(9, 10))) == [[1, 2], [3, 9, 10]]
    end
    let l::List{List{Int}} = list(list(1))
        @test nestedToVec(ListUtil.appendLastList(l, list(2, 3))) == [[1, 2, 3]]
    end
    @test nestedToVec(ListUtil.appendLastList(nil, list(1, 2))) == [[1, 2]]
end

@testset "Access" begin
    @test ListUtil.first(list(1, 2, 3)) == 1
    @test listToVec(ListUtil.firstOrEmpty(list(1, 2, 3))) == [1]
    @test listLength(ListUtil.firstOrEmpty(list())) == 0
    @test ListUtil.second(list(1, 2, 3)) == 2
    @test ListUtil.last(list(1, 2, 3)) == 3
    @test ListUtil.secondLast(list(1, 2, 3, 4)) == 3
    @test ListUtil.getIndexFirst(2, list(10, 20, 30)) == 20

    @test listToVec(ListUtil.firstN(list(1, 2, 3, 4, 5), 3)) == [1, 2, 3]
    @test listToVec(ListUtil.firstN(list(1, 2, 3), 0)) == Int[]
    @test listToVec(ListUtil.lastN(list(1, 2, 3, 4, 5), 2)) == [4, 5]
    @test listToVec(ListUtil.rest(list(1, 2, 3))) == [2, 3]
    @test listToVec(ListUtil.restCond(true, list(1, 2, 3))) == [2, 3]
    @test listToVec(ListUtil.restCond(false, list(1, 2, 3))) == [1, 2, 3]
    @test listToVec(ListUtil.restOrEmpty(list(1, 2, 3))) == [2, 3]
    @test listLength(ListUtil.restOrEmpty(list())) == 0
end

@testset "Strip / split" begin
    @test listToVec(ListUtil.stripFirst(list(1, 2, 3))) == [2, 3]
    @test listLength(ListUtil.stripFirst(list())) == 0
    @test listToVec(ListUtil.stripLast(list(1, 2, 3))) == [1, 2]
    @test listLength(ListUtil.stripLast(list())) == 0
    @test listToVec(ListUtil.stripN(list(1, 2, 3, 4, 5), 2)) == [3, 4, 5]
    @test listToVec(ListUtil.stripN(list(1, 2, 3), 0)) == [1, 2, 3]

    @test listToVec(ListUtil.sublist(list(1, 2, 3, 4, 5), 2, 3)) == [2, 3, 4]

    let (a, b) = ListUtil.split(list(1, 2, 5, 7), 2)
        @test listToVec(a) == [1, 2]
        @test listToVec(b) == [5, 7]
    end
    let (a, b) = ListUtil.splitr(list(1, 2, 5, 7), 2)
        @test listToVec(a) == [2, 1]
        @test listToVec(b) == [5, 7]
    end
    let (t, f) = ListUtil.splitOnTrue(list(1, 2, 3, 4), iseven)
        @test listToVec(t) == [2, 4]
        @test listToVec(f) == [1, 3]
    end
    let (a, b) = ListUtil.splitOnFirstMatch(list(1, 2, 3, 4, 5), x -> x == 3)
        @test listToVec(a) == [1, 2]
        @test listToVec(b) == [3, 4, 5]
    end
    let (h, t) = ListUtil.splitFirst(list(10, 20, 30))
        @test h == 10
        @test listToVec(t) == [20, 30]
    end
    let (h, t) = ListUtil.splitFirstOption(list(10, 20))
        @test h == SOME(10)
        @test listToVec(t) == [20]
    end
    let (h, t) = ListUtil.splitFirstOption(list())
        @test h == NONE()
        @test listLength(t) == 0
    end
    let (l, rest) = ListUtil.splitLast(list(3, 5, 7, 11, 13))
        @test l == 13
        @test listToVec(rest) == [3, 5, 7, 11]
    end

    @test nestedToVec(ListUtil.splitEqualParts(list(1, 2, 3, 4, 5, 6, 7, 8), 4)) ==
          [[1, 2], [3, 4], [5, 6], [7, 8]]
    @test nestedToVec(ListUtil.partition(list(1, 2, 3, 4, 5), 2)) == [[1, 2], [3, 4], [5]]
    @test nestedToVec(ListUtil.partition(list(1, 2, 3, 4), 2)) == [[1, 2], [3, 4]]
    @test nestedToVec(ListUtil.balancedPartition(list(1, 2, 3, 4, 5), 3)) ==
          [[1, 2, 3], [4, 5]]
    @test listLength(ListUtil.balancedPartition(list(), 2)) == 0
end

@testset "Sort and unique" begin
    @test listToVec(ListUtil.sort(list(3, 1, 4, 1, 5, 9, 2, 6), gt)) == [1, 1, 2, 3, 4, 5, 6, 9]
    @test listToVec(ListUtil.sort(list(2, 1, 3), lt)) == [3, 2, 1]
    @test listLength(ListUtil.sort(list(), gt)) == 0

    @test listToVec(ListUtil.heapSortIntList(list(3, 1, 4, 1, 5))) == [1, 1, 3, 4, 5]
    @test listToVec(ListUtil.heapSortIntList(list())) == Int[]
    @test listToVec(ListUtil.heapSortIntList(list(7))) == [7]

    @test listToVec(ListUtil.mergeSorted(list(1, 3, 5), list(2, 4, 6), lt)) == [1, 2, 3, 4, 5, 6]
    @test listToVec(ListUtil.mergeSorted(list(), list(1, 2), lt)) == [1, 2]
    @test listToVec(ListUtil.mergeSorted(list(1, 2), list(), lt)) == [1, 2]

    @test listToVec(ListUtil.sortIntN(list(3, 1, 4, 1, 5, 2), 5)) == [1, 2, 3, 4, 5]
    @test listToVec(ListUtil.unique(list(1, 2, 1, 3, 2, 4))) == [1, 2, 3, 4]
    @test listToVec(ListUtil.uniqueIntN(list(1, 2, 1, 3, 2, 4), 5)) == [4, 3, 2, 1]
    @test listToVec(ListUtil.uniqueOnTrue(list(1, 2, 1, 3, 2), (a, b) -> a == b)) ==
          [1, 2, 3]

    @test listToVec(ListUtil.sortedDuplicates(list(1, 1, 2, 3, 3, 3, 4), (a, b) -> a == b)) ==
          [1, 3, 3]
    @test listToVec(ListUtil.sortedUnique(list(1, 1, 2, 3, 3), (a, b) -> a == b)) ==
          [1, 2, 3]
    let (uniq, dups) = ListUtil.sortedUniqueAndDuplicates(list(1, 1, 2, 3, 3),
                                                          (a, b) -> a == b)
        @test listToVec(uniq) == [1, 2, 3]
        @test listToVec(dups) == [1, 3]
    end
    @test listToVec(ListUtil.sortedUniqueOnlyDuplicates(list(1, 1, 2, 3, 3),
                                                        (a, b) -> a == b)) == [1, 3]
    @test ListUtil.sortedListAllUnique(list(1, 2, 3), (a, b) -> a == b)
    @test !ListUtil.sortedListAllUnique(list(1, 2, 2, 3), (a, b) -> a == b)

    @test ListUtil.isSorted(list(1, 2, 3, 4), (a, b) -> a <= b)
    @test !ListUtil.isSorted(list(1, 3, 2, 4), (a, b) -> a <= b)
    @test ListUtil.isSorted(list(), (a, b) -> a <= b)

    let l::List{List{Int}} = list(list(1, 2), list(3, 4, 5), list(6))
        @test nestedToVec(ListUtil.reverseList(l)) == [[6], [5, 4, 3], [2, 1]]
    end
end

@testset "Insert / set / replace / delete" begin
    @test listToVec(ListUtil.insert(list(2, 1, 4, 2), 2, 3)) == [2, 3, 1, 4, 2]
    @test listToVec(ListUtil.set(list(2, 1, 4, 2), 2, 3)) == [2, 3, 4, 2]

    @test listToVec(ListUtil.replaceAt('A', 2, list('a', 'b', 'c'))) == ['a', 'A', 'c']
    @test listToVec(ListUtil.replaceAtIndexFirst(2, 'A', list('a', 'b', 'c'))) == ['a', 'A', 'c']
    @test listToVec(ListUtil.replaceAtWithList(list('A', 'B'), 1, list('a', 'b', 'c'))) ==
          ['a', 'A', 'B', 'c']
    @test listToVec(ListUtil.replaceAtWithFill("A", 5, list("a", "b", "c"), "x")) ==
          ["a", "b", "c", "x", "A"]
    @test listToVec(ListUtil.replaceAtWithFill("A", 2, list("a", "b", "c"), "x")) ==
          ["a", "A", "c"]

    let (out, replaced) = ListUtil.replaceOnTrue(99, list(1, 2, 3), x -> x == 2)
        @test listToVec(out) == [1, 99, 3]
        @test replaced
    end
    let (out, replaced) = ListUtil.replaceOnTrue(99, list(1, 2, 3), x -> x == 7)
        @test listToVec(out) == [1, 2, 3]
        @test !replaced
    end

    @test listToVec(ListUtil.deleteMember(list(1, 2, 3, 2), 2)) == [1, 3, 2]
    @test listToVec(ListUtil.deleteMember(list(1, 2, 3), 9)) == [1, 2, 3]
    @test listToVec(ListUtil.deleteMemberF(list(1, 2, 3), 2)) == [1, 3]
    @test_throws Exception ListUtil.deleteMemberF(list(1, 2, 3), 9)

    let (out, opt) = ListUtil.deleteMemberOnTrue(2, list(1, 2, 3, 2), (v, e) -> v == e)
        @test listToVec(out) == [1, 3, 2]
        @test opt == SOME(2)
    end
    let (out, opt) = ListUtil.deleteMemberOnTrue(9, list(1, 2, 3), (v, e) -> v == e)
        @test listToVec(out) == [1, 2, 3]
        @test opt == NONE()
    end

    @test listToVec(ListUtil.deletePositions(list(1, 2, 3, 4, 5), list(2, 0, 3))) == [2, 5]
    @test listToVec(ListUtil.deletePositionsSorted(list(1, 2, 3, 4, 5), list(0, 2, 3))) == [2, 5]
    @test listToVec(ListUtil.removeMatchesFirst(list(1, 1, 2, 1, 3), 1)) == [2, 1, 3]
    @test listToVec(ListUtil.removeMatchesFirst(list(2, 1, 3), 1)) == [2, 1, 3]

    @test listToVec(ListUtil.removeOnTrue(2, (v, e) -> v == e, list(1, 2, 3, 2))) == [1, 3]
end

@testset "Set operations" begin
    @test listToVec(ListUtil.intersectionOnTrue(list(1, 4, 2), list(5, 2, 4, 6),
                                                (a, b) -> a == b)) == [4, 2]
    @test listToVec(ListUtil.intersectionIntN(list(1, 2), list(2, 3), 5)) == [2]
    @test listToVec(ListUtil.intersectionIntSorted(list(1, 3, 5, 7), list(2, 3, 5, 8))) == [3, 5]

    @test listToVec(ListUtil.setDifference(list(1, 2, 3), list(1, 3))) == [2]
    @test listToVec(ListUtil.setDifferenceOnTrue(list(1, 2, 3), list(1, 3),
                                                 (a, b) -> a == b)) == [2]
    @test listToVec(ListUtil.setDifferenceIntN(list(1, 2, 3), list(1, 3), 5)) == [2]

    @test ListUtil.setEqualOnTrue(list(1, 2, 3), list(3, 2, 1), (a, b) -> a == b)
    @test !ListUtil.setEqualOnTrue(list(1, 2, 3), list(1, 2), (a, b) -> a == b)

    @test listToVec(ListUtil.union(list(0, 1), list(2, 1))) == [0, 1, 2]
    @test listLength(ListUtil.union(nil, nil)) == 0
    @test listToVec(ListUtil.union(list(1, 2), nil)) == [1, 2]
    @test listToVec(ListUtil.union(nil, list(1, 2))) == [1, 2]

    @test listToVec(ListUtil.unionElt(0, list(1, 2))) == [0, 1, 2]
    @test listToVec(ListUtil.unionElt(1, list(1, 2))) == [1, 2]
    @test listToVec(ListUtil.unionEltOnTrue(0, list(1, 2), (a, b) -> a == b)) == [0, 1, 2]

    let l::List{List{Int}} = list(list(1), list(1, 2), list(3, 4), list(5))
        @test listToVec(ListUtil.unionList(l)) == [1, 2, 3, 4, 5]
    end
    @test listToVec(ListUtil.unionOnTrue(list(1, 2), list(2, 3), (a, b) -> a == b)) ==
          [1, 2, 3]
    @test listToVec(ListUtil.unionIntN(list(1, 2), list(2, 3), 5)) == [1, 2, 3]
end

@testset "Map family" begin
    @test listToVec(ListUtil.map(list(1, 2, 3), x -> x * 2)) == [2, 4, 6]
    @test listToVec(ListUtil.mapReverse(list(1, 2, 3), x -> x * 2)) == [6, 4, 2]
    @test listToVec(ListUtil.map1(list(1, 2, 3), (x, k) -> x + k, 10)) == [11, 12, 13]
    @test listToVec(ListUtil.map1Reverse(list(1, 2, 3), (x, k) -> x + k, 10)) == [13, 12, 11]
    @test listToVec(ListUtil.map1r(list(1, 2, 3), (k, x) -> k - x, 100)) == [99, 98, 97]
    @test listToVec(ListUtil.map2(list(1, 2), (x, a, b) -> x + a + b, 10, 100)) == [111, 112]
    @test listToVec(ListUtil.map3(list(1, 2), (x, a, b, c) -> x + a + b + c, 10, 100, 1000)) ==
          [1111, 1112]

    let (a, b) = ListUtil.map_2(list(1, 2, 3), x -> (x, x * 2))
        @test listToVec(a) == [1, 2, 3]
        @test listToVec(b) == [2, 4, 6]
    end

    let l::List{Option{Int}} = list(SOME(1), NONE(), SOME(3))
        @test listToVec(ListUtil.mapOption(l, x -> x * 10)) == [10, 30]
    end
    # OMC's List.mapFlat is listReverse(mapFlatReverse(...)), so each mapped
    # sublist comes out reversed: {1, 2, 3} -> {-1, 1, -2, 2, -3, 3}.
    @test listToVec(ListUtil.mapFlat(list(1, 2, 3), x -> list(x, -x))) == [-1, 1, -2, 2, -3, 3]
    @test listToVec(ListUtil.mapFlatReverse(list(1, 2, 3), x -> list(x, -x))) ==
          [3, -3, 2, -2, 1, -1]

    @test ListUtil.mapBoolOr(list(1, 2, 3), iseven)
    @test !ListUtil.mapBoolOr(list(1, 3, 5), iseven)
    @test ListUtil.mapBoolAnd(list(2, 4, 6), iseven)
    @test !ListUtil.mapBoolAnd(list(2, 4, 5), iseven)

    @test ListUtil.mapAllValueBool(list(2, 4, 6), x -> x * 0, 0)
    @test !ListUtil.mapAllValueBool(list(2, 4, 6), x -> x, 0)

    let l::List{List{Int}} = list(list(1, 2), list(3, 4))
        @test nestedToVec(ListUtil.mapList(l, x -> x * 10)) == [[10, 20], [30, 40]]
    end

    @test listToVec(ListUtil.mapMap(list(1, 2, 3), x -> x + 1, x -> x * 10)) == [20, 30, 40]
end

@testset "Fold family" begin
    @test ListUtil.fold(list(1, 2, 3), +, 2) == 8
    @test ListUtil.foldr(list(1, 2, 3), (acc, e) -> acc - e, 100) == 94
    @test ListUtil.fold1(list(1, 2, 3), (e, k, acc) -> acc + e * k, 10, 0) == 60
    @test ListUtil.fold2(list(1, 2, 3), (e, a, b, acc) -> acc + e + a + b, 10, 100, 0) == 336
    @test ListUtil.fold3(list(1, 2), (e, a, b, c, acc) -> acc + e + a + b + c, 1, 2, 3, 0) == 15
    let l::List{List{Int}} = list(list(1, 2), list(3, 4))
        @test ListUtil.foldList(l, +, 0) == 10
    end
    let l::List{List{Int}} = list(list(1, 2), list(3))
        @test ListUtil.foldList1(l, (e, k, acc) -> acc + e + k, 100, 0) == 306
    end

    let (a, b) = ListUtil.fold20(list(1, 2, 3), (e, x, y) -> (x + e, y * e), 0, 1)
        @test a == 6
        @test b == 6
    end
    let (a, b, c) = ListUtil.fold30(list(1, 2),
                                    (e, x, y, z) -> (x + e, y * e, z - e),
                                    0, 1, 100)
        @test a == 3
        @test b == 2
        @test c == 97
    end

    @test ListUtil.reduce(list(1, 2, 3), +) == 6
    @test ListUtil.reduce1(list(1, 2, 3), (a, b, k) -> a + b + k, 100) == 206

    let (out, acc) = ListUtil.mapFold(list(1, 2, 3), (e, a) -> (e * 10, a + e), 0)
        @test listToVec(out) == [10, 20, 30]
        @test acc == 6
    end
    let (out, a1, a2) = ListUtil.mapFold2(list(1, 2),
                                          (e, a, b) -> (e * 10, a + e, b * e),
                                          0, 1)
        @test listToVec(out) == [10, 20]
        @test a1 == 3
        @test a2 == 2
    end
    @test listToVec(ListUtil.mapFoldSO(list(1, 2, 3),
                                       (e, a) -> e * a,
                                       10)) == [10, 20, 30]

    @test ListUtil.foldcallN(3, x -> x * 2, 1) == 8
end

@testset "Filter family" begin
    @test listToVec(ListUtil.filterOnTrue(list(1, 2, 3, 4, 5), iseven)) == [2, 4]
    @test listToVec(ListUtil.filterOnFalse(list(1, 2, 3, 4, 5), iseven)) == [1, 3, 5]
    @test listToVec(ListUtil.filter1OnTrue(list(1, 2, 3, 4), (e, k) -> e > k, 2)) == [3, 4]
    @test listToVec(ListUtil.filter2OnTrue(list(1, 2, 3, 4),
                                           (e, lo, hi) -> lo <= e <= hi, 2, 3)) == [2, 3]
    @test listToVec(ListUtil.filterOnTrueReverse(list(1, 2, 3, 4, 5), iseven)) == [4, 2]

    let throwIfOdd = x -> isodd(x) ? error("odd") : x
        @test listToVec(ListUtil.filter(list(1, 2, 3, 4), throwIfOdd)) == [2, 4]
    end

    let mapOddFails = x -> isodd(x) ? error("odd") : x * 10
        @test listToVec(ListUtil.filterMap(list(1, 2, 3, 4), mapOddFails)) == [20, 40]
    end

    let (extracted, remaining) = ListUtil.extractOnTrue(list(1, 2, 3, 4, 5), iseven)
        @test listToVec(extracted) == [2, 4]
        @test listToVec(remaining) == [1, 3, 5]
    end
    let (extracted, remaining) = ListUtil.extract1OnTrue(list(1, 2, 3, 4),
                                                         (e, k) -> e > k, 2)
        @test listToVec(extracted) == [3, 4]
        @test listToVec(remaining) == [1, 2]
    end

    let (t, f) = ListUtil.separateOnTrue(list(1, 2, 3, 4), iseven)
        @test sort(listToVec(t)) == [2, 4]
        @test sort(listToVec(f)) == [1, 3]
    end
end

@testset "Find / position / member" begin
    @test ListUtil.position(2, list(0, 1, 2, 3)) == 3
    @test ListUtil.positionOnTrue(list(1, 2, 3), iseven) == 2
    @test ListUtil.positionOnTrue(list(1, 3, 5), iseven) == -1
    @test ListUtil.position1OnTrue(list(1, 2, 3), (e, k) -> e == k, 3) == 3

    let l::List{List{Int}} = list(list(4, 2), list(6, 4, 3, 1)),
        (li, p) = ListUtil.positionList(3, l)
        @test li == 2
        @test p == 3
    end

    @test ListUtil.getMember(2, list(1, 2, 3)) == 2
    @test ListUtil.getMemberOnTrue("a", list("bb", "b", "ccc"), (v, e) -> length(e) == length(v)) == "b"

    @test ListUtil.find(list(1, 2, 3), iseven) == 2
    @test ListUtil.find1(list(1, 2, 3), (e, k) -> e == k, 3) == 3

    let (out, found) = ListUtil.findMap(list(1, 2, 3, 4),
                                        e -> e == 3 ? (99, true) : (e, false))
        @test listToVec(out) == [1, 2, 99, 4]
        @test found
    end
    let (out, found) = ListUtil.findMap1(list(1, 2, 3),
                                         (e, k) -> e == k ? (99, true) : (e, false), 2)
        @test listToVec(out) == [1, 99, 3]
        @test found
    end

    @test ListUtil.findSome(list(1, 2, 3, 4),
                            e -> iseven(e) ? SOME(e * 10) : NONE()) == 20
    @test ListUtil.findSome1(list(1, 2, 3, 4),
                             (e, k) -> e == k ? SOME(e * 100) : NONE(), 3) == 300

    @test ListUtil.findOption(list(1, 2, 3), iseven) == SOME(2)
    @test ListUtil.findOption(list(1, 3, 5), iseven) == NONE()

    let (e, rest) = ListUtil.findAndRemove(list(1, 2, 3, 4), iseven)
        @test e == 2
        @test listToVec(rest) == [1, 3, 4]
    end
    let (e, rest) = ListUtil.findAndRemove1(list(1, 2, 3, 4), (x, k) -> x == k, 3)
        @test e == 3
        @test listToVec(rest) == [1, 2, 4]
    end

    @test ListUtil.findBoolList(list(false, false, true, false), list(1, 2, 3, 4), -1) == 3
    @test ListUtil.findBoolList(list(false, false, false), list(1, 2, 3), -1) == -1
end

@testset "Threading and unzipping" begin
    @test listToVec(ListUtil.thread(list(1, 2, 3), list(4, 5, 6))) == [4, 1, 5, 2, 6, 3]
    @test listToVec(ListUtil.thread3(list(1, 2, 3), list(4, 5, 6), list(7, 8, 9))) ==
          [7, 4, 1, 8, 5, 2, 9, 6, 3]

    let tup = ListUtil.threadTuple(list(1, 2, 3), list(true, false, true))
        @test listToVec(tup) == [(1, true), (2, false), (3, true)]
    end

    @test listToVec(ListUtil.threadMap(list(1, 2), list(10, 20), +)) == [11, 22]
    @test listToVec(ListUtil.threadMapReverse(list(1, 2), list(10, 20), +)) == [22, 11]
    @test listToVec(ListUtil.threadMap1(list(1, 2), list(10, 20),
                                        (a, b, k) -> a + b + k, 100)) == [111, 122]
    @test listToVec(ListUtil.threadMap2(list(1, 2), list(10, 20),
                                        (a, b, p, q) -> a + b + p + q, 100, 1000)) ==
          [1111, 1122]

    let (a, b) = ListUtil.threadMap_2(list(1, 2), list(10, 20),
                                      (x, y) -> (x + y, x * y))
        @test listToVec(a) == [11, 22]
        @test listToVec(b) == [10, 40]
    end

    let (a, b) = ListUtil.unzip(list((1, 'a'), (2, 'b'), (3, 'c')))
        @test listToVec(a) == [1, 2, 3]
        @test listToVec(b) == ['a', 'b', 'c']
    end
    let (a, b) = ListUtil.unzipReverse(list((1, 'a'), (2, 'b')))
        @test listToVec(a) == [2, 1]
        @test listToVec(b) == ['b', 'a']
    end
    @test listToVec(ListUtil.unzipFirst(list((1, 'a'), (2, 'b')))) == [1, 2]
    @test listToVec(ListUtil.unzipSecond(list((1, 'a'), (2, 'b')))) == ['a', 'b']

    @test ListUtil.threadFold(list(1, 2, 3), list(10, 20, 30),
                              (a, b, acc) -> acc + a + b, 0) == 66
    @test ListUtil.threadFold1(list(1, 2), list(10, 20),
                               (a, b, k, acc) -> acc + a + b + k, 5, 0) == 43
end

@testset "Misc" begin
    # OMC: flatten keeps sub-list order; flattenReverse puts later sub-lists first.
    let l::List{List{Int}} = list(list(1, 2), list(3, 4), list(5))
        @test listToVec(ListUtil.flatten(l)) == [1, 2, 3, 4, 5]
        @test listToVec(ListUtil.flattenReverse(l)) == [5, 3, 4, 1, 2]
    end
    let l::List{List{Int}} = list(list(), list(7, 8), list())
        @test listToVec(ListUtil.flattenReverse(l)) == [7, 8]
    end
    @test listToVec(ListUtil.flattenReverse(list(list(1), list("a")))) == ["a", 1]
    @test listEmpty(ListUtil.flattenReverse(nil))

    let l::List{List{Int}} = list(list(1, 2, 3), list(4, 5, 6))
        @test nestedToVec(ListUtil.transposeList(l)) == [[1, 4], [2, 5], [3, 6]]
    end

    @test listToVec(ListUtil.productMap(list(1, 2), list(3, 4), *)) == [3, 4, 6, 8]
    let l1::List{List{Int}} = list(list(1), list(2)),
        l2::List{List{Int}} = list(list(1), list(3), list(4))
        @test nestedToVec(ListUtil.product(l1, l2)) ==
              [[1, 1], [1, 3], [1, 4], [2, 1], [2, 3], [2, 4]]
    end

    let pairs = ListUtil.toListWithPositions(list("a", "b", "c"))
        @test listToVec(pairs) == [("a", 1), ("b", 2), ("c", 3)]
    end

    @test ListUtil.mkOption(list()) === nothing
    let opt = ListUtil.mkOption(list(1, 2))
        @test opt isa SOME
        @test listToVec(opt.data) == [1, 2]
    end

    @test listToVec(ListUtil.first2FromTuple3((1, 2, 3))) == [1, 2]

    @test ListUtil.compare(list(1, 2), list(1, 3),
                           (a, b) -> a < b ? -1 : (a > b ? 1 : 0)) == -1
    @test ListUtil.compare(list(1, 2, 3), list(1, 2),
                           (a, b) -> a < b ? -1 : (a > b ? 1 : 0)) == 1
    @test ListUtil.compare(list(1, 2), list(1, 2),
                           (a, b) -> a < b ? -1 : (a > b ? 1 : 0)) == 0

    @test listToVec(ListUtil.getAtIndexLst(list(10, 20, 30, 40), list(1, 3))) == [10, 30]
    @test listToVec(ListUtil.getAtIndexLst(list(10, 20), list(1, 5), true)) == [10]
    @test_throws Exception ListUtil.getAtIndexLst(list(10, 20), list(1, 5))

    @test listToVec(ListUtil.keepPositions(list(10, 20, 30, 40), list(2, 4))) == [20, 40]

    @test ListUtil.maxElement(list(3, 1, 4, 1, 5), (a, b) -> a < b) == 5
    @test ListUtil.minElement(list(3, 1, 4, 1, 5), (a, b) -> a < b) == 1

    @test listToVec(ListUtil.trim(list(2, 4, 3, 6), iseven)) == [3, 6]
    @test listToVec(ListUtil.trimToLength(list(1, 2, 3, 4, 5), 3)) == [3, 4, 5]

    let (pre, rest) = ListUtil.splitEqualPrefix(list(1, 2, 3, 4), list(1, 2),
                                                (a, b) -> a == b)
        @test listToVec(pre) == [1, 2]
        @test listToVec(rest) == [3, 4]
    end
    let (a, b) = ListUtil.removeEqualPrefix(list(1, 2, 3, 4), list(1, 2, 9),
                                            (x, y) -> x == y)
        @test listToVec(a) == [3, 4]
        @test listToVec(b) == [9]
    end

    let l::List{List{Int}} = list(list(1, 2), list(3), list(4, 5))
        @test nestedToVec(ListUtil.combination(l)) ==
              [[1, 3, 4], [1, 3, 5], [2, 3, 4], [2, 3, 5]]
    end

    let result = ListUtil.mapIndices(list(10, 20, 30, 40, 50), list(2, 4), x -> x * 100)
        @test listToVec(result) == [10, 2000, 30, 4000, 50]
    end
end

@testset "toString" begin
    @test ListUtil.toString(list(1, 2, 3), string, "nums", "{", ";", "}", true) == "nums{1;2;3}"
    @test ListUtil.toString(list(), string, "nums", "{", ";", "}", true) == "nums{}"
    @test ListUtil.toString(list(), string, "nums", "{", ";", "}", false) == "nums"
end

@testset "Generate" begin
    countdown = function (n)
        if n <= 0
            (n, 0, false)
        else
            (n - 1, n, true)
        end
    end
    @test listToVec(ListUtil.generate(3, countdown)) == [3, 2, 1]
    @test listToVec(ListUtil.generateReverse(3, countdown)) == [1, 2, 3]
end

#= The functions that built their result with DoubleEnded: the unchanged list is returned as it is, a
   changed one keeps the order (map2FoldCheckReferenceEq threw for a changed element before). =#
@testset "Reference-preserving map, remove, replace" begin
    local l = list(1, 2, 3)
    @test ListUtil.mapCheckReferenceEq(l, identity) === l
    @test listToVec(ListUtil.mapCheckReferenceEq(l, x -> x == 2 ? 20 : x)) == [1, 20, 3]
    @test listToVec(ListUtil.mapCheckReferenceEq(l, x -> x == 1 ? 10 : x)) == [10, 2, 3]
    @test ListUtil.mapCheckReferenceEq(list(), identity) === list()
    local step = (e, a, b, s) -> (e == 3 ? e * a : e, s + e + b)
    local (r, acc) = ListUtil.map2FoldCheckReferenceEq(l, step, 10, 1, 0)
    @test listToVec(r) == [1, 2, 30] && acc == 9
    local (same, n) = ListUtil.map2FoldCheckReferenceEq(l, (e, a, b, s) -> (e, s + 1), 0, 0, 0)
    @test same === l && n == 3
    local (e, rest) = ListUtil.findAndRemove(list(1, 2, 3, 4), x -> x == 3)
    @test e == 3 && listToVec(rest) == [1, 2, 4]
    local (e1, rest1) = ListUtil.findAndRemove1(list(1, 2, 3), (x, a) -> x == a, 1)
    @test e1 == 1 && listToVec(rest1) == [2, 3]
    @test_throws Exception ListUtil.findAndRemove(list(1, 2), x -> x > 5)
    @test listToVec(ListUtil.replaceAt(9, 1, l)) == [9, 2, 3]
    @test listToVec(ListUtil.replaceAt(9, 2, l)) == [1, 9, 3]
    @test listToVec(ListUtil.replaceAt(9, 3, l)) == [1, 2, 9]
    @test_throws Exception ListUtil.replaceAt(9, 4, l)
    #= an abstract element type stays the list's =#
    local nums = Cons{Real}(1, Cons{Real}(2.5, nil))
    @test eltype(ListUtil.mapCheckReferenceEq(nums, x -> x == 1 ? 1.0 : x)) == Real
end

end # module ListUtilTests
