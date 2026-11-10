#=
  The tests of the ArrayUtil package (formerly ArrayUtil.jl, now OMFrontend.ArrayUtil), run first in OMFrontend's tests.
  The module keeps the helpers of the tests out of the namespace of the other test files.
=#
module ArrayUtilTests

using Test
import OMFrontend.ArrayUtil
using MetaModelica

listToVec(xs) = collect(xs)

@testset "ArrayUtil maps" begin
    src = [1, 2, 3]
    out = ArrayUtil.mapNoCopy(src, x -> x + 1)
    @test out === src
    @test src == [2, 3, 4]

    src = [1, 2, 3]
    out, acc = ArrayUtil.mapNoCopy_1(src, pair -> begin
        x, running = pair
        (x + running, running + x)
    end, 10)
    @test out === src
    @test src == [11, 13, 16]
    @test acc == 16

    src = [10, 20, 30]
    out = ArrayUtil.map(src, x -> string(x))
    @test out == ["10", "20", "30"]
    @test src == [10, 20, 30]
    @test ArrayUtil.map(Int[], x -> x + 1) == Any[]

    @test ArrayUtil.map1([1, 2, 3], (x, arg) -> x + arg, 5) == [6, 7, 8]
    @test ArrayUtil.map1(Int[], (x, arg) -> x + arg, 5) == Any[]

    seen = Int[]
    @test ArrayUtil.map0([1, 2, 3], x -> push!(seen, 2x)) === nothing
    @test seen == [2, 4, 6]

    @test ArrayUtil.mapList(list(1, 2, 3), x -> 3x) == [3, 6, 9]

    out, acc = ArrayUtil.mapFold([1, 2, 3], (x, running) -> (2x, running + x), 0)
    @test out == [2, 4, 6]
    @test acc == 6

    @test ArrayUtil.mapFoldSO([1, 2, 3], (x, scale) -> x * scale, 10) == [10, 20, 30]

    ref = Ref(0)
    @test ArrayUtil.mapFoldRef([1, 2, 3], (x, r) -> begin
        r[] += x
        r[]
    end, 0, ref) == [1, 3, 6]
    @test ref[] == 6

    out, acc = ArrayUtil.map1Fold([1, 2, 3], (x, scale, running) -> (x * scale, running + x), 10, 0)
    @test out == [10, 20, 30]
    @test acc == 6

    typed_out, typed_acc = ArrayUtil.map1Fold([1, 2], (x, scale, running) -> (x * scale, running + x), 10, 0, Int)
    @test typed_out == [10, 20]
    @test eltype(typed_out) == Int
    @test typed_acc == 3

    src = [1, 2, 3, 4]
    @test ArrayUtil.mapIndices(src, [2, 4], x -> 10x) == [1, 20, 3, 40]
    @test src == [1, 2, 3, 4]
    @test ArrayUtil.mapIndices(src, Int[], x -> 10x) == src

    src = [1, 2, 3, 4]
    @test ArrayUtil.mapIndices!(src, [1, 3], x -> 10x) === src
    @test src == [10, 2, 30, 4]
end

@testset "ArrayUtil folds and reductions" begin
    @test ArrayUtil.fold([1, 2, 3, 4], (x, acc) -> acc + x, 0) == 10
    @test ArrayUtil.fold1([1, 2], (x, a, acc) -> acc + x * a, 10, 0) == 30
    @test ArrayUtil.fold2([1, 2], (x, a, b, acc) -> acc + x + a + b, 10, 100, 0) == 223
    @test ArrayUtil.fold3([1, 2], (x, a, b, c, acc) -> acc + x + a + b + c, 1, 2, 3, 0) == 15
    @test ArrayUtil.fold4([1, 2], (x, a, b, c, d, acc) -> acc + x + a + b + c + d, 1, 2, 3, 4, 0) == 23
    @test ArrayUtil.fold5([1, 2], (x, a, b, c, d, e, acc) -> acc + x + a + b + c + d + e, 1, 2, 3, 4, 5, 0) == 33
    @test ArrayUtil.fold6([1, 2], (x, a, b, c, d, e, f, acc) -> acc + x + a + b + c + d + e + f, 1, 2, 3, 4, 5, 6, 0) == 45
    @test ArrayUtil.foldIndex([2, 3, 4], (x, i, acc) -> acc + x * i, 0) == 20
    @test ArrayUtil.reduce([1, 2, 3, 4], +) == 10
end

@testset "ArrayUtil sorting and selection" begin
    heap = [1, 3, 2]
    @test ArrayUtil.downheap(heap, 3, 0) === heap
    @test heap == [3, 1, 2]

    values = [4, 1, 3, 2]
    @test ArrayUtil.heapSort(values) === values
    @test values == [1, 2, 3, 4]

    @test ArrayUtil.findFirstOnTrue([1, 2, 3, 4], iseven) == SOME(2)
    @test ArrayUtil.findFirstOnTrue([1, 3, 5], iseven) == NONE()
    @test ArrayUtil.findFirstOnTrueWithIdx([1, 3, 4, 6], iseven) == (SOME(4), 3)
    @test ArrayUtil.findFirstOnTrueWithIdx([1, 3, 5], iseven) == (NONE(), -1)
    @test ArrayUtil.select(["a", "b", "c"], list(3, 1)) == ["c", "a"]
end

@testset "ArrayUtil indexed updates and ranges" begin
    dest = [1, 2, 3]
    @test ArrayUtil.updateIndexFirst(2, 9, dest) === dest
    @test dest == [1, 9, 3]

    @test ArrayUtil.getIndexFirst(2, ["a", "b", "c"]) == "b"

    src = [10, 20, 30]
    dest = [0, 0, 0]
    @test ArrayUtil.updatewithArrayIndexFirst(2, src, dest) === dest
    @test dest == [0, 20, 0]

    dest = [0, 0, 0, 0]
    @test ArrayUtil.updatewithListIndexFirst(list(99, 100), 2, [10, 20, 30, 40], dest) === nothing
    @test dest == [0, 20, 30, 0]

    lists = List{Int}[list(1), list(4)]
    @test ArrayUtil.updateElementListAppend(1, list(2, 3), lists) === lists
    @test listToVec(lists[1]) == [1, 2, 3]

    arr = [1, 2, 3, 4]
    @test ArrayUtil.setRange(2, 3, arr, 9) === arr
    @test arr == [1, 9, 9, 4]
    @test listToVec(ArrayUtil.getRange(2, 4, [10, 20, 30, 40])) == [40, 30, 20]

    src = [1, 2, 3]
    dest = [0, 0, 0, 0]
    @test ArrayUtil.copy(src, dest) === dest
    @test dest == [1, 2, 3, 0]

    dest = [0, 0, 0]
    @test ArrayUtil.copyN([4, 5, 6], dest, 2) === dest
    @test dest == [4, 5, 0]

    dest = [0, 0, 0, 0, 0]
    @test ArrayUtil.copyRange([10, 20, 30, 40], dest, 2, 3, 4) === nothing
    @test dest == [0, 0, 0, 20, 30]

    @test ArrayUtil.createIntRange(4) == [1, 2, 3, 4]
end

@testset "ArrayUtil expansion and list append" begin
    arr = ['a', 'b', 'c']
    @test ArrayUtil.replaceAtWithFill(5, 'A', '_', arr) == ['a', 'b', 'c', '_', 'A']
    @test arr == ['a', 'b', 'c']

    arr = [1, 2]
    @test ArrayUtil.expandToSize(2, arr, 0) === arr
    @test ArrayUtil.expandToSize(4, arr, 0) == [1, 2, 0, 0]

    arr = [1, 2]
    @test ArrayUtil.expand(0, arr, 0) === arr
    @test ArrayUtil.expand(2, arr, 0) == [1, 2, 0, 0]

    arr = [1, 2]
    @test ArrayUtil.expandOnDemand(2, arr, 2.0, 0) === arr
    @test ArrayUtil.expandOnDemand(4, arr, 2.0, 0) == [1, 2, 0, 0]

    lists = List{Int}[list(2), list(4)]
    @test ArrayUtil.consToElement(1, 1, lists) === lists
    @test listToVec(lists[1]) == [1, 2]
    @test ArrayUtil.appendToElement(2, list(5, 6), lists) === lists
    @test listToVec(lists[2]) == [4, 5, 6]

    @test ArrayUtil.appendList([1, 2], list(3, 4)) == [1, 2, 3, 4]
    arr = [1, 2]
    @test ArrayUtil.appendList(arr, nil) === arr

    arr = [1, 2]
    @test ArrayUtil.appendList!(arr, list(3, 4)) === arr
    @test arr == [1, 2, 3, 4]
    @test ArrayUtil.appendList!(arr, nil) === arr
    @test arr == [1, 2, 3, 4]
end

@testset "ArrayUtil predicates and membership" begin
    @test ArrayUtil.all([2, 4, 6], iseven)
    @test !ArrayUtil.all([2, 3, 6], iseven)

    @test ArrayUtil.position(["a", "b", "c"], "b") == 2
    @test ArrayUtil.position(["a", "b", "c"], "c", 2) == 0

    member, index = ArrayUtil.getMemberOnTrue(4, [1, 3, 5], (target, item) -> item > target)
    @test member == 5
    @test index == 3

    arr = [1, 2, 3, 4]
    @test ArrayUtil.reverse(arr) === arr
    @test arr == [4, 3, 2, 1]

    @test ArrayUtil.arrayListsEmpty(List{Int}[nil, nil])
    @test !ArrayUtil.arrayListsEmpty(List{Int}[nil, list(1)])
    @test ArrayUtil.arrayListsEmpty1(nil, true)
    @test !ArrayUtil.arrayListsEmpty1(list(1), true)

    @test ArrayUtil.isEqual([1, 2, 3], [1, 2, 3])
    @test !ArrayUtil.isEqual([1, 2, 3], [1, 2, 4])

    @test ArrayUtil.exist([1, 3, 4], iseven)
    @test !ArrayUtil.exist([1, 3, 5], iseven)

    @test ArrayUtil.removeOnTrue(2, ==, [1, 2, 3, 2]) == [1, 3]
end

@testset "ArrayUtil shapes and conversion" begin
    arr = [0, 0, 0, 0]
    @test ArrayUtil.insertList(arr, list(7, 8), 2) === arr
    @test arr == [0, 7, 8, 0]

    left, right = ArrayUtil.split([1, 2, 3, 4], 2)
    @test left == [1, 2]
    @test right == [3, 4]

    @test ArrayUtil.partition([1, 2, 3, 4, 5], 2) == [[1, 2], [3, 4], [5]]
    @test ArrayUtil.fill(:x, 3) == [:x, :x, :x]
    @test ArrayUtil.transposeArray([[1, 2, 3], [4, 5, 6]]) == [[1, 4], [2, 5], [3, 6]]

    @test ArrayUtil.toString([1, 2, 3], string, "p", "(", ",", ")", true) == "p(1,2,3)"
    @test ArrayUtil.toString(Int[], string, "p", "(", ",", ")", true) == "p()"
    @test ArrayUtil.toString(Int[], string, "p", "(", ",", ")", false) == "p"

    @test ArrayUtil.allEqual([2, 4, 6], (a, b) -> iseven(a + b))
    @test !ArrayUtil.allEqual([1, 2], (a, b) -> iseven(a + b))

    cmp(a, b) = a < b ? -1 : (a > b ? 1 : 0)
    @test ArrayUtil.compare([1, 3], [1, 2], cmp) == 1
    @test ArrayUtil.compare([1], [1, 2], cmp) == -1
    @test ArrayUtil.compare([1, 2], [1, 2], cmp) == 0

    @test ArrayUtil.generate(4, i -> i^2) == [1, 4, 9, 16]
    @test ArrayUtil.isEqualOnTrue([1, 2, 3], [2, 4, 6], (a, b) -> 2a == b)
    @test !ArrayUtil.isEqualOnTrue([1, 2], [2], (a, b) -> 2a == b)
    @test ArrayUtil.mapBoolAnd([2, 4, 6], iseven)
    @test !ArrayUtil.mapBoolAnd([2, 3, 6], iseven)
    @test ArrayUtil.threadMap([1, 2, 3], [10, 20, 30], +) == [11, 22, 33]
    @test ArrayUtil.transpose([[1, 2], [3, 4], [5, 6]]) == [[1, 3, 5], [2, 4, 6]]
    @test ArrayUtil.transpose(Vector{Vector{Int}}()) == Vector{Vector{Int}}()
end

@testset "ArrayUtil folds keep the declared fold type" begin
    # A nil start value is narrower than the list the callback returns.
    marked(e, i, acc) = e == 1 ? cons(i, acc) : acc
    @test collect(ArrayUtil.foldIndex([1, 0, 1], marked, list())) == [3, 1]
    @test isempty(collect(ArrayUtil.foldIndex(Int[], marked, list())))
    @test collect(ArrayUtil.fold1([1, 2], (e, a, acc) -> cons(e + a, acc), 10, list())) == [12, 11]
    @test collect(ArrayUtil.fold2([1, 2], (e, a, b, acc) -> cons(e + a + b, acc), 10, 100, list())) == [112, 111]
    @test collect(ArrayUtil.fold3([1], (e, a, b, c, acc) -> cons(e + a + b + c, acc), 1, 2, 3, list())) == [7]
    out, acc = ArrayUtil.mapFold([1, 2], (e, acc) -> (2e, cons(e, acc)), list())
    @test out == [2, 4]
    @test collect(acc) == [2, 1]
    @test collect(ArrayUtil.fold4([1], (e, a, b, c, d, acc) -> cons(e + a + b + c + d, acc), 1, 2, 3, 4, list())) == [11]
    @test collect(ArrayUtil.fold5([1], (e, a, b, c, d, f, acc) -> cons(e + a + b + c + d + f, acc), 1, 2, 3, 4, 5, list())) == [16]
    @test collect(ArrayUtil.fold6([1], (e, a, b, c, d, f, g, acc) -> cons(e + a + b + c + d + f + g, acc), 1, 2, 3, 4, 5, 6, list())) == [22]
    src = [1, 2]
    out, acc = ArrayUtil.mapNoCopy_1(src, pair -> (pair[1] + 1, cons(pair[1], pair[2])), list())
    @test out === src
    @test src == [2, 3]
    @test collect(acc) == [2, 1]
end

end # module ArrayUtilTests
