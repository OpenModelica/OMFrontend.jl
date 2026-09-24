#=
Unit tests for mapExp on bindings (BindingExpression.jl): the mapped binding
keeps its variant and its other fields, and an unchanged expression returns
the same binding.
=#
let FE = OMFrontend.Frontend,
    info = MetaModelica.SOURCEINFO("mapExp.mo", false, 1, 1, 1, 1, 0.0),
    one = FE.INTEGER_EXPRESSION(1),
    toTwo = e -> (e isa FE.INTEGER_EXPRESSION && e.value == 1) ? FE.INTEGER_EXPRESSION(2) : e

  untyped = FE.UNTYPED_BINDING(one, false, FE.EMPTY_NODE(), true, info)
  mapped = FE.mapExp(untyped, toTwo)
  @test isvariant(mapped, FE.UNTYPED_BINDING)
  @test mapped.bindingExp.value == 2
  @test mapped.isEach && mapped.scope === untyped.scope && mapped.info === info
  @test FE.mapExp(untyped, identity) === untyped

  flat = FE.FLAT_BINDING(one, Int8(2))
  mapped = FE.mapExp(flat, toTwo)
  @test isvariant(mapped, FE.FLAT_BINDING)
  @test mapped.bindingExp.value == 2 && mapped.variability == 2
end
