#= A component class's icon as Modelica text (componentGraphics), and the SCode and Absyn printers it is written
   with (SCodeDump, AbsynUtil: they called the template modules of omc that were never ported). =#
@testset "componentGraphics: icon and connector placements" begin
  local (fm, _) = OMFrontend.flattenModelWithMSL("Modelica.Mechanics.Rotational.Examples.First"; MSL_Version = "MSL:4.1.0")
  local g = OMFrontend.componentGraphics(fm, "spring")
  @test g.coordinateSystem == "coordinateSystem(preserveAspectRatio = true, extent = {{-100, -100}, {100, 100}})"
  @test "Text(extent = {{-150, 80}, {150, 40}}, textString = \"%name\", textColor = {0, 0, 255})" in g.items
  @test any(startswith("Line(points = {{-100, 0}, {-58, 0}"), g.items)
  #= the flanges are declared in the base class PartialCompliant =#
  @test g.placements == Dict("flange_a" => "Placement(transformation(extent = {{-110, -10}, {-90, 10}}))",
                             "flange_b" => "Placement(transformation(extent = {{90, -10}, {110, 10}}))")
  local (pfm, _) = OMFrontend.flattenModelWithMSL("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:4.1.0")
  local pid = OMFrontend.componentGraphics(pfm, "PI")
  @test pid.placements["u_m"] == "Placement(transformation(origin = {0, -120}, extent = {{20, -20}, {-20, 20}}, rotation = 270))"
  @test startswith(first(pid.items), "Rectangle(extent = {{-100, -100}, {100, 100}}")
  @test_throws ArgumentError OMFrontend.componentGraphics(fm, "nope")
end

@testset "SCodeDump and AbsynUtil printers" begin
  local file = joinpath(mktempdir(), "Probe.mo")
  write(file, """
  model Probe "probe"
    import SI = Modelica.Units.SI;
    import Modelica.Math.{sin, cos};
    parameter Real k(start = 1, each fixed = true) = 2 * x "gain"
      annotation(Dialog(group = "A"), Placement(transformation(extent = {{-10, -10}, {10, 10}})));
    Real x;
  equation
    x = k;
    annotation(Icon(graphics = {Line(points = {{-100, 0}, {100, 0}})}), Documentation(info = "<html>x</html>"));
  end Probe;
  """)
  local cls = first(OMFrontend.translateToSCode(OMFrontend.parseFile(file)))
  local els = collect(cls.classDef.elementLst)
  local D = OMFrontend.Frontend.SCodeDump
  local k = only(e for e in els if e isa SCode.COMPONENT && e.name == "k")
  @test D.unparseElementStr(k) == "Real k(start = 1, each fixed = true) = 2*x"
  @test D.unparseElementStr(cls) == "model Probe"
  @test "import SI = Modelica.Units.SI" in [D.unparseElementStr(e) for e in els]
  @test "import Modelica.Math.cos" in [D.unparseElementStr(e) for e in els]
  #= graphical annotations are left out by default (stripGraphicalAnnotations), kept on request =#
  @test D.printAnnotationStr(k.comment) == "annotation(Dialog(group = \"A\"))"
  local keep = D.OPTIONS(false, false, false, false, true, false, false, false, false)
  @test D.printAnnotationStr(k.comment, keep) ==
    "annotation(Dialog(group = \"A\"), Placement(transformation(extent = {{-10, -10}, {10, 10}})))"
  @test D.printAnnotationStr(cls.cmt) == "annotation(Documentation(info = \"<html>x</html>\"))"
  @test D.printAnnotationStr(SCode.COMMENT(NONE(), NONE())) == ""
  local AU = OMFrontend.Frontend.AbsynUtil
  @test AU.crefString(Absyn.CREF_QUAL("a", nil, Absyn.CREF_IDENT("b", list(Absyn.SUBSCRIPT(Absyn.INTEGER(1)))))) == "a.b[1]"
  @test AU.importString(Absyn.UNQUAL_IMPORT(Absyn.QUALIFIED("Modelica", Absyn.IDENT("Math")))) == "Modelica.Math.*"
  @test AU.typeSpecString(Absyn.TPATH(Absyn.IDENT("Real"), NONE())) == "Real"
end
