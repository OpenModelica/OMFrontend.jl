#= Connection equations of arrays of components and of vector connectors. Not scalarizing (scalarize = false), the
   scalar connection sets' equations that differ only in affine subscripts are for-equations
   (Frontend.rerollConnectEquations); scalarizing, they stay scalar. Both forms are the same equations:
   Frontend.scalarizeKeptArrays of the kept model is the scalarizing flatten's model. =#
import OpenModelicaParser: @Modelica_str

const ARRAY_CONNECT = Modelica"""
package ArrayConnect
  connector Pin
    Real v;
    flow Real i;
  end Pin;
  model R
    Pin p, n;
    parameter Real r = 1;
  equation
    p.v - n.v = r * p.i;
    p.i + n.i = 0;
  end R;
  model Cap
    Pin p, n;
    parameter Real C = 1;
    Real v(start = 0, fixed = true);
  equation
    v = p.v - n.v;
    C * der(v) = p.i;
    p.i + n.i = 0;
  end Cap;
  model Ground
    Pin p;
  equation
    p.v = 0;
  end Ground;
  model Source
    Pin p, n;
  equation
    p.v - n.v = 1;
    p.i + n.i = 0;
  end Source;
  model Chain "N resistors in series, connected in a for-loop."
    parameter Integer N = 4;
    R r[N];
    Source s;
    Cap c;
    Ground g;
  equation
    for i in 1:N-1 loop
      connect(r[i].n, r[i+1].p);
    end for;
    connect(s.p, r[1].p);
    connect(r[N].n, c.p);
    connect(c.n, s.n);
    connect(s.n, g.p);
  end Chain;
  model Parallel "N resistors in parallel."
    parameter Integer N = 3;
    R r[N];
    Source s;
    Cap c;
    Ground g;
  equation
    for i in 1:N loop
      connect(s.p, r[i].p);
      connect(r[i].n, c.p);
    end for;
    connect(c.n, s.n);
    connect(s.n, g.p);
  end Parallel;
  model RVec "N lanes of one resistor each, vector connectors."
    parameter Integer N = 3;
    Pin p[N], n[N];
  equation
    for i in 1:N loop
      p[i].v - n[i].v = p[i].i;
      p[i].i + n[i].i = 0;
    end for;
  end RVec;
  model VecConnect "Vector connectors connected as whole arrays."
    parameter Integer N = 3;
    RVec a(N = N), b(N = N);
    Source s;
    Ground g;
    Cap c;
  equation
    connect(a.n, b.p);
    for i in 1:N loop
      connect(s.p, a.p[i]);
      connect(b.n[i], c.p);
    end for;
    connect(c.n, s.n);
    connect(s.n, g.p);
  end VecConnect;
end ArrayConnect;
"""

const ARRAY_CONNECT_SCODE = OMFrontend.translateToSCode(ARRAY_CONNECT)

_acFlatten(model::String, scalarize::Bool) =
  first(OMFrontend.instantiateSCodeToFM("ArrayConnect." * model, ARRAY_CONNECT_SCODE; scalarize = scalarize))


"""
The terms of a sum, split at its top-level signs (not those in subscripts: `r[\$i1 + 1].p.i`), each with its sign.
"""
function _acTerms(s::String)::Vector{String}
  local terms::Vector{String} = String[]
  local depth::Int = 0
  local sign::Char = '+'
  local buf::IOBuffer = IOBuffer()
  for c in s
    if depth == 0 && (c == '+' || c == '-')
      local term::String = String(take!(buf))
      isempty(term) || push!(terms, sign * term)
      sign = c
      continue
    end
    depth += (c == '[' || c == '(') - (c == ']' || c == ')')
    write(buf, c)
  end
  push!(terms, sign * String(take!(buf)))
  return terms
end

"""
An equation's text without spaces, with the terms of a sum and the sides of an equality sorted (the two forms order
them differently).
"""
function _acCanonical(eq::String)::String
  local s::String = replace(eq, " " => "")
  local m::Union{Nothing, RegexMatch} = match(r"^(.*)=0\.0$", s)
  if m !== nothing && length(_acTerms(String(m[1]))) > 1
    return join(sort(_acTerms(String(m[1])))) * "=0.0"
  end
  local sides::Vector{SubString{String}} = split(s, "=")
  return length(sides) == 2 ? join(sort(sides), "=") : s
end

"""
The for-equations of `fm` with one equation in their body, as `range: equation` (`_acCanonical`).
"""
function _acLoops(fm)::Vector{String}
  local F = OMFrontend.Frontend
  return String[F.toString(something(eq.range)) * ": " * _acCanonical(F.toString(eq.body[1]))
                for eq in fm.equations if F.isvariant(eq, F.EQUATION_FOR) && length(eq.body) == 1]
end

_acEquationSet(fm) = sort([_acCanonical(OMFrontend.Frontend.toString(eq)) for eq in fm.equations])
_acVariableSet(fm) = sort([OMFrontend.Frontend.toString(v.name) for v in fm.variables])

@testset "Array connects" begin
  @testset "Not scalarizing: connection equations as for-equations" begin
    local chain = _acFlatten("Chain", false)
    @test "1:3: r[\$i1+1].p.v=r[\$i1].n.v" in _acLoops(chain)
    @test "1:3: +r[\$i1+1].p.i+r[\$i1].n.i=0.0" in _acLoops(chain)
    @test length(chain.equations) == 17
    local par = _acFlatten("Parallel", false)
    @test "1:3: r[\$i1].p.v=s.p.v" in _acLoops(par)
    @test "1:2: r[\$i1].n.v=r[3].n.v" in _acLoops(par)
    local vec = _acFlatten("VecConnect", false)
    @test "1:3: a.n[\$i1].v=b.p[\$i1].v" in _acLoops(vec)
    @test "1:3: +a.n[\$i1].i+b.p[\$i1].i=0.0" in _acLoops(vec)
    @test "1:3: a.p[\$i1].v=s.p.v" in _acLoops(vec)
    @test length(vec.equations) == 18
  end

  @testset "Scalarizing: scalar connection equations" begin
    for (model, n) in (("Chain", 27), ("Parallel", 23), ("VecConnect", 35))
      local scal = _acFlatten(model, true)
      @test isempty(_acLoops(scal))
      @test length(scal.equations) == n
    end
  end

  @testset "$model: the kept model scalarized is the scalarized model" for model in ("Chain", "Parallel", "VecConnect")
    local conv = OMFrontend.Frontend.scalarizeKeptArrays(_acFlatten(model, false))
    local scal = _acFlatten(model, true)
    @test _acEquationSet(conv) == _acEquationSet(scal)
    @test _acVariableSet(conv) == _acVariableSet(scal)
  end
end
