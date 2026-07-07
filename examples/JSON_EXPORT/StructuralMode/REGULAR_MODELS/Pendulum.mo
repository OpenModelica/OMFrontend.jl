model Pendulum
  inner Modelica.Mechanics.MultiBody.World world(
    gravityType = Modelica.Mechanics.MultiBody.Types.GravityTypes.UniformGravity);
  Modelica.Mechanics.MultiBody.Joints.Revolute rev(
    n = {0, 0, 1},
    useAxisFlange = true,
    phi(fixed = true),
    w(fixed = true));
  Modelica.Mechanics.Rotational.Components.Damper damper(d = 0.1);
  Modelica.Mechanics.MultiBody.Parts.Body body(m = 1.0, r_CM = {0.5, 0, 0});
equation
  connect(world.frame_b, rev.frame_a);
  connect(damper.flange_b, rev.axis);
  connect(rev.support, damper.flange_a);
  connect(body.frame_a, rev.frame_b);
end Pendulum;
