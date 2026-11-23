#= Builtin functions with their own typing rules (BuiltinCall.jl): each one typed in a small model, and the errors
   for wrong arguments.
   Author: John Tinnerholm =#
import OpenModelicaParser: @Modelica_str

const BUILTINS = Modelica"""
package Builtins
  record R
    Real x;
    encapsulated operator 'String'
      function f input R r; output String s; algorithm s := "R(" + String(r.x) + ")"; end f;
    end 'String';
  end R;
  function scalarOf input Real a[:]; output Real y; algorithm y := scalar(a); end scalarOf;
  function fillOf input Integer n; output Real y[n]; algorithm y := fill(1.0, n); end fillOf;
  model Arrays
    Real v[3] = {1, 2, 3} * time;
    Real m[2, 3] = {{1, 2, 3}, {4, 5, 6}} * time;
    parameter Integer nd = ndims(m);
    Real d[3, 3] = diagonal(v);
    Real t[3, 2] = transpose(m);
    Real s[2, 2] = symmetric({{1, 2}, {3, 4}} * time);
    Real c[4, 3] = cat(1, m, m);
    Real vv[3] = vector({{1}, {2}, {3}} * time);
    Real mm[2, 3] = matrix(m);
    Real mv[3, 1] = matrix(v);
    Real z[2] = zeros(2);
    Integer o[2, 2] = ones(2, 2);
    Real f[2] = fill(time, 2);
    Real sc = scalar({{time}});
    Real sf = scalarOf({time});
    Real fo[2] = fillOf(2);
    Real su = sum(v);
    Real pr = product(v);
    Real mx = max(v);
    Real mn = min(time, 1);
    Real m1 = max({time});
  end Arrays;
  model Events
    Real x(start = 1, fixed = true);
    Boolean b = time > 0.5;
    Boolean e = edge(b);
    Boolean ch = change(b);
    Boolean p = pre(b);
    Integer i = if b then 1 else 0;
    Real sm = smooth(1, if time > 0.5 then time else 0.5);
    Real ne = noEvent(if time > 0.5 then 1.0 else 0.0);
    Boolean sa = sample(0, 0.1);
    Boolean sa2 = sample(0, 1);
    Boolean ini = initial();
    Boolean ter = terminal();
  equation
    der(x) = -x;
  end Events;
  model Misc
    parameter Integer k = 2;
    Real dk = der(k);
    parameter Real p = 2;
    parameter String s = String(R(p));
    parameter String sn = String(p);
    Real ds = DynamicSelect(1.0, time);
    String n = getInstanceName();
  end Misc;
end Builtins;
"""

const BUILTINS_SCODE = OMFrontend.translateToSCode(BUILTINS)

"""The flat Modelica of model `Builtins.<model>`, without its `/* ... */` comments."""
function _biFlat(model::String; scalarize::Bool = true)::String
  local flat::String = OMFrontend.toFlatModelica(
    OMFrontend.instantiateSCodeToFM("Builtins." * model, BUILTINS_SCODE; scalarize = scalarize))
  return replace(flat, r"/\*.*?\*/" => "")
end

"""Whether the model `src` (a package with model `M`) fails to instantiate."""
function _biFails(src::String)::Bool
  try
    OMFrontend.instantiate("M"; string = src)
    return false
  catch
    return true
  end
end

@testset "Builtin calls" begin
  @testset "array builtins" begin
    local flat::String = _biFlat("Arrays")
    for eq in ("parameter Integer nd = 2;", "'d[2,2]' = 'v[2]';", "'d[1,2]' = 0.0;", "'t[3,1]' = 'm[1,3]';",
               "'c[3,1]' = 'm[1,1]';", "'c[4,3]' = 'm[2,3]';", "'mm[2,3]' = 'm[2,3]';", "'mv[3,1]' = 'v[3]';",
               "'z[2]' = 0.0;", "'o[2,2]' = 1;", "'f[2]' = time;", "'fo[2]' = 1.0;", "Real sc = time;",
               "y := scalar(a);", "su = 'v[1]' + 'v[2]' + 'v[3]';", "pr = 'v[1]' * 'v[2]' * 'v[3]';",
               "mx = max({'v[1]', 'v[2]', 'v[3]'});", "mn = min(time, 1.0);", "Real m1 = time;",
               "symmetric({{time, 2.0 * time}, {3.0 * time, 4.0 * time}})",
               "vector({{time}, {2.0 * time}, {3.0 * time}})")
      @test occursin(eq, flat)
    end
  end
  @testset "event builtins" begin
    local flat::String = _biFlat("Events")
    for s in ("edge(", "change(", "pre(", "smooth(1", "noEvent(", "sample(", "initial()", "terminal()", "der(x)")
      @test occursin(s, flat)
    end
  end
  @testset "der of a parameter, String overload, DynamicSelect, getInstanceName" begin
    local flat::String = _biFlat("Misc")
    #= DynamicSelect is typed as a normal call (not special in ModelicaBuiltin), so the call is kept. =#
    @test occursin("ds = DynamicSelect(1.0, time);", flat)
    @test occursin("dk = der(k);", flat)
    @test occursin("parameter String s = ''String'.f'('Builtins.R'(p));", flat)
    @test occursin("\"Misc\"", flat)
  end
  @testset "errors" begin
    @test _biFails("model M Real x = ndims(); end M;")
    @test _biFails("model M Real x = diagonal(1.0); end M;")
    @test _biFails("model M Real x[2] = transpose({1.0, 2.0}); end M;")
    @test _biFails("model M Real x[2,2] = symmetric({{1.0, 2.0}}); end M;")
    @test _biFails("model M Real x = scalar({1.0, 2.0}); end M;")
    @test _biFails("model M Real x[2] = vector({{1.0, 2.0}, {3.0, 4.0}}); end M;")
    @test _biFails("model M Real x[2,2] = matrix({{{1.0, 2.0}}, {{3.0, 4.0}}}); end M;")
    @test _biFails("model M Real x = time; Real y = pre(time); end M;")
    @test _biFails("model M Real x = der(\"a\"); end M;")
    @test _biFails("model M Boolean b = time > 0.5; Real x = smooth(time, 1.0); end M;")
    @test _biFails("model M Real x = max(true, 1.0, 2.0); end M;")
    @test _biFails("model M Real x[2] = cat(3, {1.0}, {2.0}); end M;")
    @test _biFails("model M Real x[2] = cat(1, {1.0}, {{2.0}}); end M;")
    @test _biFails("model M Real x = sample(); end M;")
    @test _biFails("model M Real x = noEvent(1.0, 2.0); end M;")
    @test _biFails("model M Real x[2] = fill(1.0, time); end M;")
    @test _biFails("model M Integer x = cardinality(time); end M;")
  end
end
