#= The overconstrained connection graph (OCCGraph.jl): a ring of three nodes with two potential roots.
   The values are omc's (instantiateModel, OpenModelica 1.27): connect(n1.b, n2.a) breaks, s1 (priority 0)
   is the root, and Connections.rooted holds only at n1.a, the one node next to the root in the spanning
   tree. =#
import OpenModelicaParser: @Modelica_str

const OCC_GRAPH_MODELS = Modelica"""
package OCCGraph
  record Ref "An overconstrained reference angle"
    Real theta;
    function equalityConstraint
      input Ref r1;
      input Ref r2;
      output Real residue[0];
    algorithm
    end equalityConstraint;
  end Ref;
  connector Port
    Ref ref;
    Real v;
    flow Real i;
  end Port;
  model Node "Two ports joined by a branch"
    Port a;
    Port b;
    Boolean ra = Connections.rooted(a.ref) "a is closer to the root than b";
  equation
    Connections.branch(a.ref, b.ref);
    a.ref.theta = b.ref.theta;
    a.v = b.v;
    a.i + b.i = 0;
  end Node;
  model Source "A potential root"
    Port p;
    parameter Integer prio = 0;
    Boolean root = Connections.isRoot(p.ref);
  equation
    Connections.potentialRoot(p.ref, prio);
    if Connections.isRoot(p.ref) then
      p.ref.theta = 0;
    end if;
    p.v = 1;
  end Source;
  model Ring
    Node n1;
    Node n2;
    Node n3;
    Source s1(prio = 0);
    Source s2(prio = 1);
  equation
    connect(n1.b, n2.a);
    connect(n2.b, n3.a);
    connect(n3.b, n1.a);
    connect(s1.p, n1.a);
    connect(s2.p, n2.a);
  end Ring;
  model RingEq "Ring with the operators in equations instead of bindings"
    Ring r;
    Boolean ra1, ra2, ra3, root1, root2;
  equation
    ra1 = Connections.rooted(r.n1.a.ref);
    ra2 = Connections.rooted(r.n2.a.ref);
    ra3 = Connections.rooted(r.n3.a.ref);
    root1 = Connections.isRoot(r.s1.p.ref);
    root2 = Connections.isRoot(r.s2.p.ref);
  end RingEq;
  model Link "Two nodes in series inside a component"
    Port a;
    Port b;
    Node n1;
    Node n2;
  equation
    connect(a, n1.a);
    connect(n1.b, n2.a);
    connect(n2.b, b);
  end Link;
  model NestedRing "A ring closed through the connects inside l"
    Link l;
    Node n3;
    Source s;
  equation
    connect(l.b, n3.a);
    connect(n3.b, l.a);
    connect(s.p, l.a);
  end NestedRing;
end OCCGraph;
"""

const OCC_GRAPH_SCODE = OMFrontend.translateToSCode(OCC_GRAPH_MODELS)

"""The flat Modelica of `OCCGraph.<model>`."""
_occFlat(model::String)::String =
  OMFrontend.toFlatModelica(first(OMFrontend.instantiateSCodeToFM("OCCGraph." * model, OCC_GRAPH_SCODE)), nil)

"""`s` without spaces and quotes."""
_occNorm(s::AbstractString)::String = replace(s, " " => "", "'" => "")

"""True if `flat` has a line that contains `s`, both normalized by `_occNorm`."""
_occHas(flat::String, s::String)::Bool = any(l -> occursin(_occNorm(s), _occNorm(l)), split(flat, '\n'))

"""The number of equation lines of `flat` that contain `s` (normalized by `_occNorm`)."""
_occEquationCount(flat::String, s::String)::Int =
  count(l -> occursin(_occNorm(s), _occNorm(l)), split(last(split(flat, "\nequation\n")), '\n'))

@testset "OCCGraph" begin
  @testset "bindings" begin
    local flat::String = _occFlat("Ring")
    @test _occHas(flat, "Boolean n1.ra = true")
    @test _occHas(flat, "Boolean n2.ra = false")
    @test _occHas(flat, "Boolean n3.ra = false")
    @test _occHas(flat, "Boolean s1.root = true")
    @test _occHas(flat, "Boolean s2.root = false")
    @test !occursin("Connections.", flat)
    #= The broken connect(n1.b, n2.a) equates no references (n1.b.ref is only in the branch's equation);
       its other variables stay connected. =#
    @test _occEquationCount(flat, "n1.b.ref") == 1
    @test _occHas(flat, "n1.a.ref.theta = n1.b.ref.theta")
    @test _occHas(flat, "s2.p.v = n1.b.v")
    @test _occHas(flat, "n2.b.ref.theta = n3.a.ref.theta")
    #= Only the root fixes its angle. =#
    @test _occHas(flat, "s1.p.ref.theta = 0")
    @test !_occHas(flat, "s2.p.ref.theta = 0")
  end
  @testset "equations" begin
    local flat::String = _occFlat("RingEq")
    @test _occHas(flat, "ra1 = true")
    @test _occHas(flat, "ra2 = false")
    @test _occHas(flat, "ra3 = false")
    @test _occHas(flat, "root1 = true")
    @test _occHas(flat, "root2 = false")
  end
  @testset "connect order" begin
    #= The connects are taken in omc's order, the reverse of the flat equations (a component's equations
       before its parent's): the last one, inside l, breaks (omc: broken(l.a.ref, l.n1.a.ref)). =#
    local flat::String = _occFlat("NestedRing")
    @test !_occHas(flat, "l.n1.a.ref.theta = l.a.ref.theta")
    @test !_occHas(flat, "l.a.ref.theta = l.n1.a.ref.theta")
    @test _occHas(flat, "Boolean l.n1.ra = false")
    @test _occHas(flat, "Boolean l.n2.ra = false")
    @test _occHas(flat, "Boolean n3.ra = false")
    @test _occHas(flat, "Boolean s.root = true")
  end
end
