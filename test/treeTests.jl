# Tests of the generic tree code the frontend includes in its tree modules: the AVL tree of
# src/Util/baseAvlTreeCode.jl (here TypeTreeImpl), the AVL tree of src/Frontend/avlTreeBody.jl (here
# DuplicateTree) and the Dict-backed tree of src/Util/baseDictTreeCode.jl (here ParameterTreeImpl).
# Author: John Tinnerholm

import OMFrontend.Frontend
import OpenModelicaParser.Absyn

@testset "Trees" begin
  @testset "AVL tree (baseAvlTreeCode.jl: TypeTreeImpl)" begin
    local T = Frontend.TypeTreeImpl
    local path(s::String)::Absyn.Path = Absyn.IDENT(s)
    local names::Vector{String} = ["d", "b", "f", "a", "c", "e", "g"]
    local real = Frontend.TYPE_REAL()
    local int = Frontend.TYPE_INTEGER()
    #= add, update, addList, map and mapFold may change the tree they get: every check builds its own =#
    local fresh() = T.fromVector(Tuple{T.Key, T.Value}[(path(n), real) for n in names])
    local tree = fresh()
    @test T.isEmpty(T.new())
    @test !T.isEmpty(tree)
    @test T.hasKey(tree, path("e")) && !T.hasKey(tree, path("z"))
    @test [k.name for k in T.listKeys(tree)] == sort(names)
    @test [k.name for k in T.listKeysReverse(tree)] == reverse(sort(names))
    @test T.get(tree, path("c")) === real
    @test isSome(T.getOpt(tree, path("c"))) && isNone(T.getOpt(tree, path("z")))
    @test T.tryGet(tree, path("z")) === nothing
    @test [p[1].name for p in T.toList(tree)] == sort(names)
    @test [p[1].name for p in T.toVector!(tree)] == sort(names)
    @test length(T.listValues(tree)) == 7
    @test length(T.vectorValues!(tree)) == 7
    @test T.fromList(list((path("x"), int), (path("y"), real))) |> T.listKeys |> length == 2
    local joined = T.join(T.fromList(list((path("a"), real))), T.fromVector(Tuple{T.Key, T.Value}[(path("a"), int), (path("z"), int)]),
                          T.addConflictKeep)
    @test T.get(joined, path("a")) === real && T.get(joined, path("z")) === int
    @test length(T.listKeys(T.addList(fresh(), list((path("h"), int), (path("i"), int))))) == 9
    @test T.get(T.update(fresh(), path("a"), int), path("a")) === int
    @test_throws Exception T.add(fresh(), path("a"), int, T.addConflictFail)
    @test T.get(T.add(fresh(), path("a"), int, T.addConflictReplace), path("a")) === int
    @test_throws Exception T.intersection()
    local seen::Vector{String} = String[]
    T.forEach(tree, (k, v) -> push!(seen, k.name))
    @test sort(seen) == sort(names)
    @test T.fold(tree, (k, v, n) -> n + 1, 0, Int) == 7
    @test T.fold_2(tree, (k, v, n, m) -> (n + 1, m + 2), 0, 0) == (7, 14)
    #= foldCond does not descend below a node where the function says false; the root is always visited =#
    @test 1 <= T.foldCond(tree, (k, v, n) -> (n + 1, false), 0) < 7
    @test T.foldCond(tree, (k, v, n) -> (n + 1, true), 0) == 7
    local printed::String = T.printTreeStr(tree)
    @test all(n -> occursin("($n, Real)", printed), names)
    @test count(==('\n'), printed) == 7
    @test T.printTreeStr(T.new()) == "EMPTY()"
    @test T.printTreeStr(T.LEAF(path("a"), real)) == "(a, Real)"
    @test all(v -> v === int, T.listValues(T.map(fresh(), (k, v) -> int)))
    local (mapped, visited) = T.mapFold(fresh(), (k, v, n) -> (int, n + 1), 0)
    @test visited == 7 && all(v -> v === int, T.listValues(mapped))
  end

  @testset "AVL tree (avlTreeBody.jl: DuplicateTree)" begin
    local T = Frontend.DuplicateTree
    local entry(i::Int) = T.newEntry(Frontend.LookupTree.COMPONENT(i))
    local names::Vector{String} = ["m", "f", "t", "b", "h", "p", "x"]
    local tree = T.fromVector(Tuple{T.Key, T.Value}[(n, entry(i)) for (i, n) in enumerate(names)])
    @test T.hasKey(tree, "h") && !T.hasKey(tree, "z")
    @test collect(T.listKeys(tree)) == sort(names)
    @test collect(T.listKeysReverse(tree)) == reverse(sort(names))
    @test T.get(tree, "h").entry == Frontend.LookupTree.COMPONENT(5)
    @test isNone(T.getOpt(tree, "z"))
    @test length(T.toList(tree)) == 7
    @test length(T.vectorValues!(tree)) == 7
    @test length(T.listKeys(T.fromList(list(("u", entry(1)), ("v", entry(2)))))) == 2
    @test length(T.listKeys(T.addList(tree, list(("y", entry(8)), ("z", entry(9)))))) == 9
    @test T.get(T.add(tree, "b", entry(99), T.addConflictKeep), "b").entry == Frontend.LookupTree.COMPONENT(4)
    @test_throws Exception T.add(tree, "b", entry(99), T.addConflictFail)
    @test_throws Exception T.intersection()
    local count::Ref{Int} = Ref(0)
    T.forEach(tree, (k, v) -> count[] += 1)
    @test count[] == 7
    @test T.foldCond(tree, (k, v, n) -> (n + 1, true), 0) == 7
    local (_, visited) = T.mapFold(tree, (k, v, n) -> (v, n + 1), 0)
    @test visited == 7
  end

  @testset "Dict-backed tree (baseDictTreeCode.jl: ParameterTreeImpl)" begin
    local T = Frontend.ParameterTreeImpl
    local one = Frontend.INTEGER_EXPRESSION(1)
    local two = Frontend.INTEGER_EXPRESSION(2)
    local tree = T.fromList(list(("b", one), ("a", one), ("c", one)))
    @test collect(T.listKeys(tree)) == ["a", "b", "c"]
    @test collect(T.listKeysReverse(tree)) == ["c", "b", "a"]
    @test length(T.listValues(tree)) == 3
    @test length(T.toList(tree)) == 3
    @test first.(T.toVector(tree)) == ["a", "b", "c"]
    @test T.get(tree, "a") == one
    @test_throws Exception T.get(tree, "z")
    @test T.printTreeStr(tree) == "a, b, c"
    local more = T.addList(T.fromList(list(("x", two))), list(("y", two)))
    @test collect(T.listKeys(more)) == ["x", "y"]
    @test collect(T.listKeys(T.join(T.fromList(list(("a", two))), more))) == ["a", "x", "y"]
    local seen::Vector{String} = String[]
    T.forEach(tree, (k, v) -> push!(seen, k))
    @test seen == ["a", "b", "c"]
    @test all(v -> v == two, T.listValues(T.map(tree, (k, v) -> two)))
    @test T.fold(tree, (k, v, n) -> n + 1, 0) == 3
    @test T.fold_2(tree, (k, v, n, m) -> (n + 1, m * 2), 0, 1) == (3, 8)
    #= unlike the AVL trees, every entry is visited: the Dict has no subtrees to skip =#
    @test T.foldCond(tree, (k, v, n) -> (n + 1, false), 0) == 3
    local (mapped, count) = T.mapFold(tree, (k, v, n) -> (two, n + 1), 0)
    @test count == 3 && T.get(mapped, "c") == two
  end
end
