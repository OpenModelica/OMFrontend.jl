#= Elementwise operators on arrays in simplification and expansion: `or` and `and` of two array literals (NFSimplifyExp;
   `or` used to apply `and` to the elements: `{x, false} or {true, y}` gave `{x, false}`, omc gives `{true, y}`), the
   scalar product of a literal vector and an array variable, and elementwise operators on matrices (the nested case of
   NFExpandExp.expandBinaryElementWise2). Scalarized and with arrays kept. =#
import OpenModelicaParser: @Modelica_str

const LOGIC_ARRAYS = Modelica"""
package LogicArrays
  model OrArrays
    Boolean x = time > 0.5;
    Boolean y = time > 0.2;
    Boolean b[2] = {x, false} or {true, y};
  end OrArrays;
  model AndArrays
    Boolean x = time > 0.5;
    Boolean y = time > 0.2;
    Boolean b[2] = {x, false} and {true, y};
  end AndArrays;
  model ScalarProduct
    Real a[3] = {1, 2, 3} * time;
    Real s = {1, 2, 3} * a;
  end ScalarProduct;
  model MatrixOps
    Real p[2, 2] = {{1, 2}, {3, 4}} * time;
    Real q[2, 2] = p .* p;
    Boolean u[2, 2] = {{time > 0.1, time > 0.2}, {time > 0.3, time > 0.4}};
    Boolean w[2, 2] = u and {{true, false}, {false, true}};
  end MatrixOps;
end LogicArrays;
"""

const LOGIC_ARRAYS_SCODE = OMFrontend.translateToSCode(LOGIC_ARRAYS)

"""The flat Modelica of model `LogicArrays.<model>`, without its `/* ... */` comments."""
function _laFlat(model::String, scalarize::Bool)::String
  local flat::String = OMFrontend.toFlatModelica(
    OMFrontend.instantiateSCodeToFM("LogicArrays." * model, LOGIC_ARRAYS_SCODE; scalarize = scalarize))
  return replace(flat, r"/\*.*?\*/" => "")
end

@testset "Logical and elementwise array operators" begin
  local orS::String = _laFlat("OrArrays", true)
  @test occursin("'b[1]' = true;", orS)
  @test occursin("'b[2]' = y;", orS)
  @test occursin("'b' = {true, 'y'};", _laFlat("OrArrays", false))
  local andS::String = _laFlat("AndArrays", true)
  @test occursin("'b[1]' = x;", andS)
  @test occursin("'b[2]' = false;", andS)
  @test occursin("'b' = {'x', false};", _laFlat("AndArrays", false))
  @test occursin("Real s = 'a[1]' + 2.0 * 'a[2]' + 3.0 * 'a[3]';", _laFlat("ScalarProduct", true))
  local matS::String = _laFlat("MatrixOps", true)
  @test occursin("'q[1,2]' = 'p[1,2]' * 'p[1,2]';", matS)
  @test occursin("'q[2,1]' = 'p[2,1]' * 'p[2,1]';", matS)
  @test occursin("'w[1,2]' = 'u[1,2]' and false;", matS)
  @test occursin("'w[2,2]' = 'u[2,2]' and true;", matS)
end
