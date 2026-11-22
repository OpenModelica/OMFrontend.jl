#= Elementwise operators on arrays in simplification and expansion: `or` and `and` of two array literals (NFSimplifyExp;
   `or` used to apply `and` to the elements: `{x, false} or {true, y}` gave `{x, false}`, omc gives `{true, y}`), the
   scalar product of a literal vector and an array variable, and elementwise operators on matrices (the nested case of
   NFExpandExp.expandBinaryElementWise2). Scalarized and with arrays kept. An operator on two arrays is typed
   element-wise (Op.MUL_EW: `p .* p`, not the matrix product `p * p`; also Op.DIV_EW and Op.POW_EW for `./` and `.^`,
   where omc 1.27 types Op.DIV and Op.POW, prints `p / q` and `p ^ q`, and fails when it types them again:
   RetypedEW), and two array literals are combined element by element (omc's simplifyBinaryEW). Array-scalar
   operators get omc's priorities (no parentheses around a plain right operand). =#
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
    Real r[2, 2] = p ./ q;
    Real s[2, 2] = p .^ q;
    Boolean u[2, 2] = {{time > 0.1, time > 0.2}, {time > 0.3, time > 0.4}};
    Boolean w[2, 2] = u and {{true, false}, {false, true}};
  end MatrixOps;
  model EwLiterals
    Real x = time;
    Real y = 2 * time;
    Real e[2] = {x, 1} .* {2, y};
    Real f[2] = {x, y} ./ {1, 2};
    Real g[2] = {x, y} .+ {0, 1};
    constant Real d[2] = {1, 2} ./ {4, 8};
    constant Real pw[2] = {2, 3} .^ {2, 2};
    Real m[2, 2] = {{x, 1}, {2, y}} .* {{2, y}, {x, 1}};
  end EwLiterals;
  model ArrayScalarParens
    Real p[2, 2] = {{1, 2}, {3, 4}} * time;
    Real a[2] = {1, 2} * (time + 1);
    Real d[2] = {1, 2} * time ^ 2;
    Real e[2] = {time, 1} .- (time - 1);
    Real f[2] = {{1, 2}, {3, 4}} * {time, 1};
  end ArrayScalarParens;
  function sizesEW
    input Real a[:];
    input Real b[size(a, 1)];
    output Integer n[2];
  algorithm
    n := cat(1, size(a ./ b), size(a .^ b));
  end sizesEW;
  model RetypedEW
    constant Integer n[2] = sizesEW({1, 2, 3}, {4, 5, 6});
  end RetypedEW;
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
  @test occursin("'r[1,2]' = 'p[1,2]' / 'q[1,2]';", matS)
  @test occursin("'s[2,1]' = 'p[2,1]' ^ 'q[2,1]';", matS)
  local matA::String = _laFlat("MatrixOps", false)
  @test occursin("'q' = 'p' .* 'p';", matA)
  @test occursin("'r' = 'p' ./ 'q';", matA)
  @test occursin("'s' = 'p' .^ 'q';", matA)
  local ewA::String = _laFlat("EwLiterals", false)
  @test occursin("'e' = {'x' * 2.0, 'y'};", ewA)
  @test occursin("'f' = {'x', 'y' / 2.0};", ewA)
  @test occursin("'g' = {'x', 'y' + 1.0};", ewA)
  @test occursin("constant Real 'd'[2] = {0.25, 0.25};", ewA)
  @test occursin("constant Real 'pw'[2] = {4.0, 9.0};", ewA)
  @test occursin("'m' = {{'x' * 2.0, 'y'}, {2.0 * 'x', 'y'}};", ewA)
  local ewS::String = _laFlat("EwLiterals", true)
  @test occursin("'e[1]' = x * 2.0;", ewS)
  @test occursin("'f[2]' = y / 2.0;", ewS)
  @test occursin("'g[2]' = y + 1.0;", ewS)
  # Parentheses as omc's flat output (-f): only where the operator priorities need them.
  local parA::String = _laFlat("ArrayScalarParens", false)
  @test occursin("'p' = {{1.0, 2.0}, {3.0, 4.0}} .* time;", parA)
  @test occursin("'a' = {1.0, 2.0} .* (time + 1.0);", parA)
  @test occursin("'d' = {1.0, 2.0} .* time ^ 2.0;", parA)
  @test occursin("'e' = {time, 1.0} .- (time - 1.0);", parA)
  @test occursin("'f' = {{1.0, 2.0}, {3.0, 4.0}} * {time, 1.0};", parA)
  # size() in a function evaluation types `a ./ b` and `a .^ b` again (NFCeval.evalSize).
  @test occursin("constant Integer 'n'[2] = {3, 3};", _laFlat("RetypedEW", false))
end
