#= Two modifiers of one element in the same scope, `x(y(...), y(...))`, merge (NFModifier.mergeLocal, ModTable.join
   with a scope and a prefix). The submodifiers of the second modifier are added to the first's one by one; a name in
   both is merged again (`a(q = 2)` and `a(p = 1)`). The merge failed with no message when `a` was not the root of
   the second modifier's table (LargeFirst): `join` added the subtrees of that table with the default conflict
   function, which fails. omc flattens both orders to the same model. =#
import OpenModelicaParser: @Modelica_str

const MODIFIER_MERGE = Modelica"""
package ModifierMerge
  model Sub
    Real p;
    Real q;
  end Sub;
  model Y
    Sub a;
    Real b;
    Real c;
  end Y;
  model X
    Y y;
  end X;
  model SmallFirst
    X x(y(a(p = 1)), y(a(q = 2), b = 3, c = 4));
  end SmallFirst;
  model LargeFirst
    X x(y(a(q = 2), b = 3, c = 4), y(a(p = 1)));
  end LargeFirst;
end ModifierMerge;
"""

const MODIFIER_MERGE_SCODE = OMFrontend.translateToSCode(MODIFIER_MERGE)

"""The flat Modelica of model `ModifierMerge.<model>`, without its `/* ... */` comments."""
function _mmFlat(model::String)::String
  local flat::String = OMFrontend.toFlatModelica(
    OMFrontend.instantiateSCodeToFM("ModifierMerge." * model, MODIFIER_MERGE_SCODE; scalarize = true))
  return replace(flat, r"/\*.*?\*/" => "")
end

@testset "Merged modifiers of one element" begin
  for model in ("SmallFirst", "LargeFirst")
    local flat::String = _mmFlat(model)
    @test occursin("Real 'x.y.a.p' = 1.0;", flat)
    @test occursin("Real 'x.y.a.q' = 2.0;", flat)
    @test occursin("Real 'x.y.b' = 3.0;", flat)
    @test occursin("Real 'x.y.c' = 4.0;", flat)
  end
end
