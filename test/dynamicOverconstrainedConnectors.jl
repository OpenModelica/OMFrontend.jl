module OCC_ReferenceModels

ACPort = "model 'DynamicOverconstrainedConnectors.ACPort'
record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public 'Modelica.SIunits.ComplexPerUnit' v;
  public 'Modelica.SIunits.ComplexPerUnit' i;
  public Real omegaRef;
equation
  'i'.re = /*Equality*/0.0;
  'i'.im = /*Equality*/0.0;
end 'DynamicOverconstrainedConnectors.ACPort';
"

Load = "model 'DynamicOverconstrainedConnectors.Load'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public 'Modelica.SIunits.ComplexPerUnit' 'port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'port.i';
  public Real 'port.omegaRef';
  public Real P(unit = \"1\") = 0.0;
  public Real Q = 0.0;
equation
  'port.i'.re = /*Equality*/0.0;
  'port.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('port.v', 'Modelica.ComplexMath.conj'('port.i')) = /*Equality*/'Complex.'constructor'.fromReal'(P, Q);
end 'DynamicOverconstrainedConnectors.Load';
"

Generator = "model 'DynamicOverconstrainedConnectors.Generator'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real V(unit = \"1\") = 1.0;
  public parameter Real Ta(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real droop(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'port.i';
  public Real 'port.omegaRef';
  public Real Ps(unit = \"1\") = 1.0;
  public Real Pc(unit = \"1\");
  public Real Pe(unit = \"1\");
  public Real theta(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real omega(fixed = true, start = 1.0, unit = \"1\");
equation
  'port.i'.re = /*Equality*/0.0;
  'port.i'.im = /*Equality*/0.0;
  der(theta) = /*Equality*/(omega - 'port.omegaRef') * 314.1592653589793;
  Ta * omega * der(omega) = /*Equality*/Ps + Pc - Pe;
  'port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'(V, theta);
  Pe = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('port.v', 'Modelica.ComplexMath.conj'('port.i'))[field: re]);
  Pc = /*Equality*/(-(omega - 1.0) / droop);
  'port.omegaRef' = /*Equality*/omega;
end 'DynamicOverconstrainedConnectors.Generator';
"

TransmissionLine = "model 'DynamicOverconstrainedConnectors.TransmissionLine'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real B(unit = \"1\") = -5.0;
  public discrete Real B_act(unit = \"1\");
  public Boolean closed;
  public Boolean open = false;
  public Boolean close = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'port_a.i';
  public Real 'port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'port_b.i';
  public Real 'port_b.omegaRef';
initial equation
  closed = /*Equality*/true;
  B_act = /*Equality*/B;
equation
  'port_a.i'.re = /*Equality*/0.0;
  'port_a.i'.im = /*Equality*/0.0;
  'port_b.i'.re = /*Equality*/0.0;
  'port_b.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('port_a.i', 'port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, B_act), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('port_a.v', 'port_b.v'));

  when open then
    closed = /*Equality*/false;
    B_act = /*Equality*/0.0;
  elsewhen close then
    closed = /*Equality*/true;
    B_act = /*Equality*/B;
  end when;

  'port_a.omegaRef' = /*Equality*/'port_b.omegaRef';
end 'DynamicOverconstrainedConnectors.TransmissionLine';
"

System1 = "model 'DynamicOverconstrainedConnectors.System1'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real 'G1.V'(unit = \"1\") = 1.0;
  public parameter Real 'G1.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G1.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.i';
  public Real 'G1.port.omegaRef';
  public Real 'G1.Ps'(unit = \"1\") = 1.0;
  public Real 'G1.Pc'(unit = \"1\");
  public Real 'G1.Pe'(unit = \"1\");
  public Real 'G1.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G1.omega'(fixed = true, start = 1.0, unit = \"1\");
  public parameter Real 'G2.V'(unit = \"1\") = 1.0;
  public parameter Real 'G2.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G2.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.i';
  public Real 'G2.port.omegaRef';
  public Real 'G2.Ps'(unit = \"1\") = 1.0;
  public Real 'G2.Pc'(unit = \"1\");
  public Real 'G2.Pe'(unit = \"1\");
  public Real 'G2.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G2.omega'(fixed = true, start = 1.0, unit = \"1\");
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.i';
  public Real 'L1.port.omegaRef';
  public Real 'L1.P'(unit = \"1\") = 1.0;
  public Real 'L1.Q' = 0.0;
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.i';
  public Real 'L2.port.omegaRef';
  public Real 'L2.P'(unit = \"1\") = if time < 1.0 then 1.0 else 0.8;
  public Real 'L2.Q' = 0.0;
  public parameter Real 'T.B'(unit = \"1\") = -5.0;
  public discrete Real 'T.B_act'(unit = \"1\");
  public Boolean 'T.closed';
  public Boolean 'T.open' = false;
  public Boolean 'T.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T.port_a.i';
  public Real 'T.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T.port_b.i';
  public Real 'T.port_b.omegaRef';
initial equation
  'T.closed' = /*Equality*/true;
  'T.B_act' = /*Equality*/'T.B';
equation
  'L1.port.omegaRef' = /*Equality*/'G1.port.omegaRef';
  'L1.port.omegaRef' = /*Equality*/'T.port_a.omegaRef';
  'T.port_a.v'.re = /*Equality*/'G1.port.v'.re;
  'T.port_a.v'.re = /*Equality*/'L1.port.v'.re;
  'L1.port.v'.im = /*Equality*/'G1.port.v'.im;
  'L1.port.v'.im = /*Equality*/'T.port_a.v'.im;
  'L2.port.omegaRef' = /*Equality*/'G2.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'T.port_b.omegaRef';
  'L2.port.v'.re = /*Equality*/'G2.port.v'.re;
  'L2.port.v'.re = /*Equality*/'T.port_b.v'.re;
  'L2.port.v'.im = /*Equality*/'G2.port.v'.im;
  'L2.port.v'.im = /*Equality*/'T.port_b.v'.im;
  'T.port_a.i'.re + 'G1.port.i'.re + 'L1.port.i'.re = /*Equality*/0.0;
  'T.port_a.i'.im + 'L1.port.i'.im + 'G1.port.i'.im = /*Equality*/0.0;
  'G2.port.i'.re + 'T.port_b.i'.re + 'L2.port.i'.re = /*Equality*/0.0;
  'T.port_b.i'.im + 'L2.port.i'.im + 'G2.port.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('T.port_a.i', 'T.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T.port_a.v', 'T.port_b.v'));

  when 'T.open' then
    'T.closed' = /*Equality*/false;
    'T.B_act' = /*Equality*/0.0;
  elsewhen 'T.close' then
    'T.closed' = /*Equality*/true;
    'T.B_act' = /*Equality*/'T.B';
  end when;

  'T.port_a.omegaRef' = /*Equality*/'T.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  der('G2.theta') = /*Equality*/('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = /*Equality*/'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = /*Equality*/(-('G2.omega' - 1.0) / 'G2.droop');
  der('G1.theta') = /*Equality*/('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = /*Equality*/'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = /*Equality*/(-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = /*Equality*/'G1.omega';
end 'DynamicOverconstrainedConnectors.System1';
"

System2 = "model 'DynamicOverconstrainedConnectors.System2'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real 'G1.V'(unit = \"1\") = 1.0;
  public parameter Real 'G1.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G1.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.i';
  public Real 'G1.port.omegaRef';
  public Real 'G1.Ps'(unit = \"1\") = 1.0;
  public Real 'G1.Pc'(unit = \"1\");
  public Real 'G1.Pe'(unit = \"1\");
  public Real 'G1.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G1.omega'(fixed = true, start = 1.0, unit = \"1\");
  public parameter Real 'G2.V'(unit = \"1\") = 1.0;
  public parameter Real 'G2.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G2.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.i';
  public Real 'G2.port.omegaRef';
  public Real 'G2.Ps'(unit = \"1\") = 1.0;
  public Real 'G2.Pc'(unit = \"1\");
  public Real 'G2.Pe'(unit = \"1\");
  public Real 'G2.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G2.omega'(fixed = true, start = 1.0, unit = \"1\");
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.i';
  public Real 'L1.port.omegaRef';
  public Real 'L1.P'(unit = \"1\") = 1.0;
  public Real 'L1.Q' = 0.0;
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.i';
  public Real 'L2.port.omegaRef';
  public Real 'L2.P'(unit = \"1\") = if time < 1.0 then 1.0 else 0.8;
  public Real 'L2.Q' = 0.0;
  public parameter Real 'T1a.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1a.B_act'(unit = \"1\");
  public Boolean 'T1a.closed';
  public Boolean 'T1a.open' = false;
  public Boolean 'T1a.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.i';
  public Real 'T1a.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.i';
  public Real 'T1a.port_b.omegaRef';
  public parameter Real 'T1b.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1b.B_act'(unit = \"1\");
  public Boolean 'T1b.closed';
  public Boolean 'T1b.open' = false;
  public Boolean 'T1b.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.i';
  public Real 'T1b.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.i';
  public Real 'T1b.port_b.omegaRef';
  public parameter Real 'T2.B'(unit = \"1\") = -10.0;
  public discrete Real 'T2.B_act'(unit = \"1\");
  public Boolean 'T2.closed';
  public Boolean 'T2.open' = false;
  public Boolean 'T2.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.i';
  public Real 'T2.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.i';
  public Real 'T2.port_b.omegaRef';
initial equation
  'T2.closed' = /*Equality*/true;
  'T2.B_act' = /*Equality*/'T2.B';
  'T1b.closed' = /*Equality*/true;
  'T1b.B_act' = /*Equality*/'T1b.B';
  'T1a.closed' = /*Equality*/true;
  'T1a.B_act' = /*Equality*/'T1a.B';
equation
  'L1.port.omegaRef' = /*Equality*/'T1b.port_a.omegaRef';
  'L1.port.omegaRef' = /*Equality*/'G1.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'G2.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'T2.port_b.omegaRef';
  'G2.port.v'.re = /*Equality*/'L2.port.v'.re;
  'G2.port.v'.re = /*Equality*/'T2.port_b.v'.re;
  'G2.port.v'.im = /*Equality*/'T2.port_b.v'.im;
  'G2.port.v'.im = /*Equality*/'L2.port.v'.im;
  'L1.port.v'.re = /*Equality*/'T1b.port_a.v'.re;
  'L1.port.v'.re = /*Equality*/'G1.port.v'.re;
  'L1.port.v'.re = /*Equality*/'T1a.port_a.v'.re;
  'T1a.port_a.v'.im = /*Equality*/'T1b.port_a.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'G1.port.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'L1.port.v'.im;
  'T1a.port_b.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'T1a.port_b.omegaRef' = /*Equality*/'T2.port_a.omegaRef';
  'T1a.port_b.v'.re = /*Equality*/'T1b.port_b.v'.re;
  'T1a.port_b.v'.re = /*Equality*/'T2.port_a.v'.re;
  'T1a.port_b.v'.im = /*Equality*/'T1b.port_b.v'.im;
  'T1a.port_b.v'.im = /*Equality*/'T2.port_a.v'.im;
  'T2.port_b.i'.re + 'G2.port.i'.re + 'L2.port.i'.re = /*Equality*/0.0;
  'L2.port.i'.im + 'T2.port_b.i'.im + 'G2.port.i'.im = /*Equality*/0.0;
  'G1.port.i'.re + 'L1.port.i'.re + 'T1b.port_a.i'.re + 'T1a.port_a.i'.re = /*Equality*/0.0;
  'L1.port.i'.im + 'T1a.port_a.i'.im + 'G1.port.i'.im + 'T1b.port_a.i'.im = /*Equality*/0.0;
  'T2.port_a.i'.re + 'T1a.port_b.i'.re + 'T1b.port_b.i'.re = /*Equality*/0.0;
  'T1a.port_b.i'.im + 'T1b.port_b.i'.im + 'T2.port_a.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b.v'));

  when 'T2.open' then
    'T2.closed' = /*Equality*/false;
    'T2.B_act' = /*Equality*/0.0;
  elsewhen 'T2.close' then
    'T2.closed' = /*Equality*/true;
    'T2.B_act' = /*Equality*/'T2.B';
  end when;

  'T2.port_a.omegaRef' = /*Equality*/'T2.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = /*Equality*/false;
    'T1b.B_act' = /*Equality*/0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = /*Equality*/true;
    'T1b.B_act' = /*Equality*/'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = /*Equality*/false;
    'T1a.B_act' = /*Equality*/0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = /*Equality*/true;
    'T1a.B_act' = /*Equality*/'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = /*Equality*/'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  der('G2.theta') = /*Equality*/('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = /*Equality*/'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = /*Equality*/(-('G2.omega' - 1.0) / 'G2.droop');
  der('G1.theta') = /*Equality*/('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = /*Equality*/'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = /*Equality*/(-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = /*Equality*/'G1.omega';
end 'DynamicOverconstrainedConnectors.System2';
"

System3 = "model 'DynamicOverconstrainedConnectors.System3'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real 'G1.V'(unit = \"1\") = 1.0;
  public parameter Real 'G1.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G1.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.i';
  public Real 'G1.port.omegaRef';
  public Real 'G1.Ps'(unit = \"1\") = 1.0;
  public Real 'G1.Pc'(unit = \"1\");
  public Real 'G1.Pe'(unit = \"1\");
  public Real 'G1.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G1.omega'(fixed = true, start = 1.0, unit = \"1\");
  public parameter Real 'G2.V'(unit = \"1\") = 1.0;
  public parameter Real 'G2.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G2.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.i';
  public Real 'G2.port.omegaRef';
  public Real 'G2.Ps'(unit = \"1\") = 1.0;
  public Real 'G2.Pc'(unit = \"1\");
  public Real 'G2.Pe'(unit = \"1\");
  public Real 'G2.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G2.omega'(fixed = true, start = 1.0, unit = \"1\");
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.i';
  public Real 'L1.port.omegaRef';
  public Real 'L1.P'(unit = \"1\") = 1.0;
  public Real 'L1.Q' = 0.0;
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.i';
  public Real 'L2.port.omegaRef';
  public Real 'L2.P'(unit = \"1\") = if time < 1.0 then 1.0 else 0.8;
  public Real 'L2.Q' = 0.0;
  public parameter Real 'T1a.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1a.B_act'(unit = \"1\");
  public Boolean 'T1a.closed';
  public Boolean 'T1a.open' = false;
  public Boolean 'T1a.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.i';
  public Real 'T1a.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.i';
  public Real 'T1a.port_b.omegaRef';
  public parameter Real 'T1b.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1b.B_act'(unit = \"1\");
  public Boolean 'T1b.closed';
  public Boolean 'T1b.open' = false;
  public Boolean 'T1b.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.i';
  public Real 'T1b.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.i';
  public Real 'T1b.port_b.omegaRef';
  public parameter Real 'T2.B'(unit = \"1\") = -10.0;
  public discrete Real 'T2.B_act'(unit = \"1\");
  public Boolean 'T2.closed';
  public Boolean 'T2.open' = if time < 10.0 then false else true;
  public Boolean 'T2.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.i';
  public Real 'T2.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.i';
  public Real 'T2.port_b.omegaRef';
initial equation
  'T2.closed' = /*Equality*/true;
  'T2.B_act' = /*Equality*/'T2.B';
  'T1b.closed' = /*Equality*/true;
  'T1b.B_act' = /*Equality*/'T1b.B';
  'T1a.closed' = /*Equality*/true;
  'T1a.B_act' = /*Equality*/'T1a.B';
equation
  'L1.port.omegaRef' = /*Equality*/'T1b.port_a.omegaRef';
  'L1.port.omegaRef' = /*Equality*/'G1.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'G2.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'T2.port_b.omegaRef';
  'G2.port.v'.re = /*Equality*/'L2.port.v'.re;
  'G2.port.v'.re = /*Equality*/'T2.port_b.v'.re;
  'G2.port.v'.im = /*Equality*/'T2.port_b.v'.im;
  'G2.port.v'.im = /*Equality*/'L2.port.v'.im;
  'L1.port.v'.re = /*Equality*/'T1b.port_a.v'.re;
  'L1.port.v'.re = /*Equality*/'G1.port.v'.re;
  'L1.port.v'.re = /*Equality*/'T1a.port_a.v'.re;
  'T1a.port_a.v'.im = /*Equality*/'T1b.port_a.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'G1.port.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'L1.port.v'.im;
  'T1a.port_b.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'T1a.port_b.omegaRef' = /*Equality*/'T2.port_a.omegaRef';
  'T1a.port_b.v'.re = /*Equality*/'T1b.port_b.v'.re;
  'T1a.port_b.v'.re = /*Equality*/'T2.port_a.v'.re;
  'T1a.port_b.v'.im = /*Equality*/'T1b.port_b.v'.im;
  'T1a.port_b.v'.im = /*Equality*/'T2.port_a.v'.im;
  'T2.port_b.i'.re + 'G2.port.i'.re + 'L2.port.i'.re = /*Equality*/0.0;
  'L2.port.i'.im + 'T2.port_b.i'.im + 'G2.port.i'.im = /*Equality*/0.0;
  'G1.port.i'.re + 'L1.port.i'.re + 'T1b.port_a.i'.re + 'T1a.port_a.i'.re = /*Equality*/0.0;
  'L1.port.i'.im + 'T1a.port_a.i'.im + 'G1.port.i'.im + 'T1b.port_a.i'.im = /*Equality*/0.0;
  'T2.port_a.i'.re + 'T1a.port_b.i'.re + 'T1b.port_b.i'.re = /*Equality*/0.0;
  'T1a.port_b.i'.im + 'T1b.port_b.i'.im + 'T2.port_a.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b.v'));

  when 'T2.open' then
    'T2.closed' = /*Equality*/false;
    'T2.B_act' = /*Equality*/0.0;
  elsewhen 'T2.close' then
    'T2.closed' = /*Equality*/true;
    'T2.B_act' = /*Equality*/'T2.B';
  end when;

  'T2.port_a.omegaRef' = /*Equality*/'T2.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = /*Equality*/false;
    'T1b.B_act' = /*Equality*/0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = /*Equality*/true;
    'T1b.B_act' = /*Equality*/'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = /*Equality*/false;
    'T1a.B_act' = /*Equality*/0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = /*Equality*/true;
    'T1a.B_act' = /*Equality*/'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = /*Equality*/'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  der('G2.theta') = /*Equality*/('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = /*Equality*/'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = /*Equality*/(-('G2.omega' - 1.0) / 'G2.droop');
  der('G1.theta') = /*Equality*/('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = /*Equality*/'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = /*Equality*/(-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = /*Equality*/'G1.omega';
end 'DynamicOverconstrainedConnectors.System3';
"

System4 = "model 'DynamicOverconstrainedConnectors.System4'
record 'Complex'
  Real re;
  Real im;
end 'Complex';

record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public parameter Real 'G1.V'(unit = \"1\") = 1.0;
  public parameter Real 'G1.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G1.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G1.port.i';
  public Real 'G1.port.omegaRef';
  public Real 'G1.Ps'(unit = \"1\") = 1.0;
  public Real 'G1.Pc'(unit = \"1\");
  public Real 'G1.Pe'(unit = \"1\");
  public Real 'G1.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G1.omega'(fixed = true, start = 1.0, unit = \"1\");
  public parameter Real 'G2.V'(unit = \"1\") = 1.0;
  public parameter Real 'G2.Ta'(unit = \"s\", quantity = \"Time\") = 10.0;
  public parameter Real 'G2.droop'(unit = \"1\") = 0.05;
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'G2.port.i';
  public Real 'G2.port.omegaRef';
  public Real 'G2.Ps'(unit = \"1\") = 1.0;
  public Real 'G2.Pc'(unit = \"1\");
  public Real 'G2.Pe'(unit = \"1\");
  public Real 'G2.theta'(fixed = true, start = 0.0, displayUnit = \"deg\", unit = \"rad\", quantity = \"Angle\");
  public Real 'G2.omega'(fixed = true, start = 1.0, unit = \"1\");
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L1.port.i';
  public Real 'L1.port.omegaRef';
  public Real 'L1.P'(unit = \"1\") = 1.0;
  public Real 'L1.Q' = 0.0;
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'L2.port.i';
  public Real 'L2.port.omegaRef';
  public Real 'L2.P'(unit = \"1\") = if time < 1.0 then 1.0 else 0.8;
  public Real 'L2.Q' = 0.0;
  public parameter Real 'T1a.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1a.B_act'(unit = \"1\");
  public Boolean 'T1a.closed';
  public Boolean 'T1a.open' = false;
  public Boolean 'T1a.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_a.i';
  public Real 'T1a.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1a.port_b.i';
  public Real 'T1a.port_b.omegaRef';
  public parameter Real 'T1b.B'(unit = \"1\") = -5.0;
  public discrete Real 'T1b.B_act'(unit = \"1\");
  public Boolean 'T1b.closed';
  public Boolean 'T1b.open' = false;
  public Boolean 'T1b.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_a.i';
  public Real 'T1b.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T1b.port_b.i';
  public Real 'T1b.port_b.omegaRef';
  public parameter Real 'T2.B'(unit = \"1\") = -10.0;
  public discrete Real 'T2.B_act'(unit = \"1\");
  public Boolean 'T2.closed';
  public Boolean 'T2.open' = if time < 10.0 then false else true;
  public Boolean 'T2.close' = false;
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_a.i';
  public Real 'T2.port_a.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b.i';
  public Real 'T2.port_b.omegaRef';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b_int.v';
  public 'Modelica.SIunits.ComplexPerUnit' 'T2.port_b_int.i';
  protected Real 'T2.port_b_int.omegaRef';
initial equation
  'T2.closed' = /*Equality*/true;
  'T2.B_act' = /*Equality*/'T2.B';
  'T1b.closed' = /*Equality*/true;
  'T1b.B_act' = /*Equality*/'T1b.B';
  'T1a.closed' = /*Equality*/true;
  'T1a.B_act' = /*Equality*/'T1a.B';
equation
  'L1.port.omegaRef' = /*Equality*/'T1b.port_a.omegaRef';
  'L1.port.omegaRef' = /*Equality*/'G1.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'G2.port.omegaRef';
  'L2.port.omegaRef' = /*Equality*/'T2.port_b.omegaRef';
  'G2.port.v'.re = /*Equality*/'L2.port.v'.re;
  'G2.port.v'.re = /*Equality*/'T2.port_b.v'.re;
  'G2.port.v'.im = /*Equality*/'T2.port_b.v'.im;
  'G2.port.v'.im = /*Equality*/'L2.port.v'.im;
  'L1.port.v'.re = /*Equality*/'T1b.port_a.v'.re;
  'L1.port.v'.re = /*Equality*/'G1.port.v'.re;
  'L1.port.v'.re = /*Equality*/'T1a.port_a.v'.re;
  'T1a.port_a.v'.im = /*Equality*/'T1b.port_a.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'G1.port.v'.im;
  'T1a.port_a.v'.im = /*Equality*/'L1.port.v'.im;
  'T1a.port_b.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'T1a.port_b.omegaRef' = /*Equality*/'T2.port_a.omegaRef';
  'T1a.port_b.v'.re = /*Equality*/'T1b.port_b.v'.re;
  'T1a.port_b.v'.re = /*Equality*/'T2.port_a.v'.re;
  'T1a.port_b.v'.im = /*Equality*/'T1b.port_b.v'.im;
  'T1a.port_b.v'.im = /*Equality*/'T2.port_a.v'.im;
  'T2.port_b.i'.re + 'G2.port.i'.re + 'L2.port.i'.re = /*Equality*/0.0;
  'L2.port.i'.im + 'T2.port_b.i'.im + 'G2.port.i'.im = /*Equality*/0.0;
  'G1.port.i'.re + 'L1.port.i'.re + 'T1b.port_a.i'.re + 'T1a.port_a.i'.re = /*Equality*/0.0;
  'L1.port.i'.im + 'T1a.port_a.i'.im + 'G1.port.i'.im + 'T1b.port_a.i'.im = /*Equality*/0.0;
  'T2.port_a.i'.re + 'T1a.port_b.i'.re + 'T1b.port_b.i'.re = /*Equality*/0.0;
  'T1a.port_b.i'.im + 'T1b.port_b.i'.im + 'T2.port_a.i'.im = /*Equality*/0.0;
  'T2.port_b_int.i'.re = /*Equality*/0.0;
  'T2.port_b_int.i'.im = /*Equality*/0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b_int.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b_int.v'));

  when 'T2.open' then
    'T2.closed' = /*Equality*/false;
    'T2.B_act' = /*Equality*/0.0;
  elsewhen 'T2.close' then
    'T2.closed' = /*Equality*/true;
    'T2.B_act' = /*Equality*/'T2.B';
  end when;

  'T2.port_a.omegaRef' = /*Equality*/'T2.port_b_int.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = /*Equality*/false;
    'T1b.B_act' = /*Equality*/0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = /*Equality*/true;
    'T1b.B_act' = /*Equality*/'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = /*Equality*/'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = /*Equality*/'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = /*Equality*/'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = /*Equality*/false;
    'T1a.B_act' = /*Equality*/0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = /*Equality*/true;
    'T1a.B_act' = /*Equality*/'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = /*Equality*/'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = /*Equality*/'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  der('G2.theta') = /*Equality*/('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = /*Equality*/'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = /*Equality*/(-('G2.omega' - 1.0) / 'G2.droop');
  'G2.port.omegaRef' = /*Equality*/'G2.omega';
  der('G1.theta') = /*Equality*/('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = /*Equality*/'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = /*Equality*/'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = /*Equality*/(-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = /*Equality*/(-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = /*Equality*/'G1.omega';
end 'DynamicOverconstrainedConnectors.System4';
"

end
