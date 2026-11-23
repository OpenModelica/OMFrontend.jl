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
  'i'.re = 0.0;
  'i'.im = 0.0;
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
  'port.i'.re = 0.0;
  'port.i'.im = 0.0;
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('port.v', 'Modelica.ComplexMath.conj'('port.i')) = 'Complex.'constructor'.fromReal'(P, Q);
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
  'port.i'.re = 0.0;
  'port.i'.im = 0.0;
  der(theta) = (omega - 'port.omegaRef') * 314.1592653589793;
  Ta * omega * der(omega) = Ps + Pc - Pe;
  'port.v' = 'Modelica.ComplexMath.fromPolar'(V, theta);
  Pe = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('port.v', 'Modelica.ComplexMath.conj'('port.i'))[field: re]);
  Pc = (-(omega - 1.0) / droop);
  'port.omegaRef' = omega;
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
  closed = true;
  B_act = B;
equation
  'port_a.i'.re = 0.0;
  'port_a.i'.im = 0.0;
  'port_b.i'.re = 0.0;
  'port_b.i'.im = 0.0;
  'Modelica.SIunits.ComplexPerUnit.'+''('port_a.i', 'port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, B_act), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('port_a.v', 'port_b.v'));

  when open then
    closed = false;
    B_act = 0.0;
  elsewhen close then
    closed = true;
    B_act = B;
  end when;

  'port_a.omegaRef' = 'port_b.omegaRef';
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
  'T.closed' = true;
  'T.B_act' = 'T.B';
equation
  'G1.port.omegaRef' = 'T.port_a.omegaRef';
  'G1.port.omegaRef' = 'L1.port.omegaRef';
  'G1.port.v'.re = 'T.port_a.v'.re;
  'G1.port.v'.re = 'L1.port.v'.re;
  'G1.port.v'.im = 'T.port_a.v'.im;
  'G1.port.v'.im = 'L1.port.v'.im;
  'G2.port.omegaRef' = 'T.port_b.omegaRef';
  'G2.port.omegaRef' = 'L2.port.omegaRef';
  'G2.port.v'.re = 'T.port_b.v'.re;
  'G2.port.v'.re = 'L2.port.v'.re;
  'G2.port.v'.im = 'T.port_b.v'.im;
  'G2.port.v'.im = 'L2.port.v'.im;
  'T.port_a.i'.re + 'L1.port.i'.re + 'G1.port.i'.re = 0.0;
  'T.port_a.i'.im + 'L1.port.i'.im + 'G1.port.i'.im = 0.0;
  'T.port_b.i'.re + 'L2.port.i'.re + 'G2.port.i'.re = 0.0;
  'T.port_b.i'.im + 'L2.port.i'.im + 'G2.port.i'.im = 0.0;
  der('G1.theta') = ('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = 'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = 'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = (-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = 'G1.omega';
  der('G2.theta') = ('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = 'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = 'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = (-('G2.omega' - 1.0) / 'G2.droop');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = 'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = 'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'+''('T.port_a.i', 'T.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T.port_a.v', 'T.port_b.v'));

  when 'T.open' then
    'T.closed' = false;
    'T.B_act' = 0.0;
  elsewhen 'T.close' then
    'T.closed' = true;
    'T.B_act' = 'T.B';
  end when;

  'T.port_a.omegaRef' = 'T.port_b.omegaRef';
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
  'T1a.closed' = true;
  'T1a.B_act' = 'T1a.B';
  'T1b.closed' = true;
  'T1b.B_act' = 'T1b.B';
  'T2.closed' = true;
  'T2.B_act' = 'T2.B';
equation
  'G1.port.omegaRef' = 'T1b.port_a.omegaRef';
  'G1.port.omegaRef' = 'L1.port.omegaRef';
  'G2.port.omegaRef' = 'T2.port_b.omegaRef';
  'G2.port.omegaRef' = 'L2.port.omegaRef';
  'G2.port.v'.re = 'T2.port_b.v'.re;
  'G2.port.v'.re = 'L2.port.v'.re;
  'G2.port.v'.im = 'T2.port_b.v'.im;
  'G2.port.v'.im = 'L2.port.v'.im;
  'G1.port.v'.re = 'T1b.port_a.v'.re;
  'G1.port.v'.re = 'T1a.port_a.v'.re;
  'G1.port.v'.re = 'L1.port.v'.re;
  'G1.port.v'.im = 'T1b.port_a.v'.im;
  'G1.port.v'.im = 'T1a.port_a.v'.im;
  'G1.port.v'.im = 'L1.port.v'.im;
  'T1b.port_b.omegaRef' = 'T2.port_a.omegaRef';
  'T1b.port_b.omegaRef' = 'T1a.port_b.omegaRef';
  'T1b.port_b.v'.re = 'T2.port_a.v'.re;
  'T1b.port_b.v'.re = 'T1a.port_b.v'.re;
  'T1b.port_b.v'.im = 'T2.port_a.v'.im;
  'T1b.port_b.v'.im = 'T1a.port_b.v'.im;
  'T2.port_b.i'.re + 'L2.port.i'.re + 'G2.port.i'.re = 0.0;
  'T2.port_b.i'.im + 'L2.port.i'.im + 'G2.port.i'.im = 0.0;
  'T1b.port_a.i'.re + 'T1a.port_a.i'.re + 'L1.port.i'.re + 'G1.port.i'.re = 0.0;
  'T1b.port_a.i'.im + 'T1a.port_a.i'.im + 'L1.port.i'.im + 'G1.port.i'.im = 0.0;
  'T2.port_a.i'.re + 'T1b.port_b.i'.re + 'T1a.port_b.i'.re = 0.0;
  'T2.port_a.i'.im + 'T1b.port_b.i'.im + 'T1a.port_b.i'.im = 0.0;
  der('G1.theta') = ('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = 'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = 'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = (-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = 'G1.omega';
  der('G2.theta') = ('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = 'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = 'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = (-('G2.omega' - 1.0) / 'G2.droop');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = 'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = 'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = false;
    'T1a.B_act' = 0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = true;
    'T1a.B_act' = 'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = 'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = false;
    'T1b.B_act' = 0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = true;
    'T1b.B_act' = 'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = 'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b.v'));

  when 'T2.open' then
    'T2.closed' = false;
    'T2.B_act' = 0.0;
  elsewhen 'T2.close' then
    'T2.closed' = true;
    'T2.B_act' = 'T2.B';
  end when;

  'T2.port_a.omegaRef' = 'T2.port_b.omegaRef';
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
  'T1a.closed' = true;
  'T1a.B_act' = 'T1a.B';
  'T1b.closed' = true;
  'T1b.B_act' = 'T1b.B';
  'T2.closed' = true;
  'T2.B_act' = 'T2.B';
equation
  'G1.port.omegaRef' = 'T1b.port_a.omegaRef';
  'G1.port.omegaRef' = 'L1.port.omegaRef';
  'G2.port.omegaRef' = 'T2.port_b.omegaRef';
  'G2.port.omegaRef' = 'L2.port.omegaRef';
  'G2.port.v'.re = 'T2.port_b.v'.re;
  'G2.port.v'.re = 'L2.port.v'.re;
  'G2.port.v'.im = 'T2.port_b.v'.im;
  'G2.port.v'.im = 'L2.port.v'.im;
  'G1.port.v'.re = 'T1b.port_a.v'.re;
  'G1.port.v'.re = 'T1a.port_a.v'.re;
  'G1.port.v'.re = 'L1.port.v'.re;
  'G1.port.v'.im = 'T1b.port_a.v'.im;
  'G1.port.v'.im = 'T1a.port_a.v'.im;
  'G1.port.v'.im = 'L1.port.v'.im;
  'T1b.port_b.omegaRef' = 'T2.port_a.omegaRef';
  'T1b.port_b.omegaRef' = 'T1a.port_b.omegaRef';
  'T1b.port_b.v'.re = 'T2.port_a.v'.re;
  'T1b.port_b.v'.re = 'T1a.port_b.v'.re;
  'T1b.port_b.v'.im = 'T2.port_a.v'.im;
  'T1b.port_b.v'.im = 'T1a.port_b.v'.im;
  'T2.port_b.i'.re + 'L2.port.i'.re + 'G2.port.i'.re = 0.0;
  'T2.port_b.i'.im + 'L2.port.i'.im + 'G2.port.i'.im = 0.0;
  'T1b.port_a.i'.re + 'T1a.port_a.i'.re + 'L1.port.i'.re + 'G1.port.i'.re = 0.0;
  'T1b.port_a.i'.im + 'T1a.port_a.i'.im + 'L1.port.i'.im + 'G1.port.i'.im = 0.0;
  'T2.port_a.i'.re + 'T1b.port_b.i'.re + 'T1a.port_b.i'.re = 0.0;
  'T2.port_a.i'.im + 'T1b.port_b.i'.im + 'T1a.port_b.i'.im = 0.0;
  der('G1.theta') = ('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = 'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = 'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = (-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = 'G1.omega';
  der('G2.theta') = ('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = 'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = 'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = (-('G2.omega' - 1.0) / 'G2.droop');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = 'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = 'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = false;
    'T1a.B_act' = 0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = true;
    'T1a.B_act' = 'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = 'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = false;
    'T1b.B_act' = 0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = true;
    'T1b.B_act' = 'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = 'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b.v'));

  when 'T2.open' then
    'T2.closed' = false;
    'T2.B_act' = 0.0;
  elsewhen 'T2.close' then
    'T2.closed' = true;
    'T2.B_act' = 'T2.B';
  end when;

  'T2.port_a.omegaRef' = 'T2.port_b.omegaRef';
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
  'T1a.closed' = true;
  'T1a.B_act' = 'T1a.B';
  'T1b.closed' = true;
  'T1b.B_act' = 'T1b.B';
  'T2.closed' = true;
  'T2.B_act' = 'T2.B';
equation
  'G1.port.omegaRef' = 'T1b.port_a.omegaRef';
  'G1.port.omegaRef' = 'L1.port.omegaRef';
  'G2.port.omegaRef' = 'T2.port_b.omegaRef';
  'G2.port.omegaRef' = 'L2.port.omegaRef';
  'G2.port.v'.re = 'T2.port_b.v'.re;
  'G2.port.v'.re = 'L2.port.v'.re;
  'G2.port.v'.im = 'T2.port_b.v'.im;
  'G2.port.v'.im = 'L2.port.v'.im;
  'G1.port.v'.re = 'T1b.port_a.v'.re;
  'G1.port.v'.re = 'T1a.port_a.v'.re;
  'G1.port.v'.re = 'L1.port.v'.re;
  'G1.port.v'.im = 'T1b.port_a.v'.im;
  'G1.port.v'.im = 'T1a.port_a.v'.im;
  'G1.port.v'.im = 'L1.port.v'.im;
  'T1b.port_b.omegaRef' = 'T2.port_a.omegaRef';
  'T1b.port_b.omegaRef' = 'T1a.port_b.omegaRef';
  'T1b.port_b.v'.re = 'T2.port_a.v'.re;
  'T1b.port_b.v'.re = 'T1a.port_b.v'.re;
  'T1b.port_b.v'.im = 'T2.port_a.v'.im;
  'T1b.port_b.v'.im = 'T1a.port_b.v'.im;
  'T2.port_b.i'.re + 'L2.port.i'.re + 'G2.port.i'.re = 0.0;
  'T2.port_b.i'.im + 'L2.port.i'.im + 'G2.port.i'.im = 0.0;
  'T1b.port_a.i'.re + 'T1a.port_a.i'.re + 'L1.port.i'.re + 'G1.port.i'.re = 0.0;
  'T1b.port_a.i'.im + 'T1a.port_a.i'.im + 'L1.port.i'.im + 'G1.port.i'.im = 0.0;
  'T2.port_a.i'.re + 'T1b.port_b.i'.re + 'T1a.port_b.i'.re = 0.0;
  'T2.port_a.i'.im + 'T1b.port_b.i'.im + 'T1a.port_b.i'.im = 0.0;
  'T2.port_b_int.i'.re = 0.0;
  'T2.port_b_int.i'.im = 0.0;
  der('G1.theta') = ('G1.omega' - 'G1.port.omegaRef') * 314.1592653589793;
  'G1.Ta' * 'G1.omega' * der('G1.omega') = 'G1.Ps' + 'G1.Pc' - 'G1.Pe';
  'G1.port.v' = 'Modelica.ComplexMath.fromPolar'('G1.V', 'G1.theta');
  'G1.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G1.port.v', 'Modelica.ComplexMath.conj'('G1.port.i'))[field: re]);
  'G1.Pc' = (-('G1.omega' - 1.0) / 'G1.droop');
  'G1.port.omegaRef' = 'G1.omega';
  der('G2.theta') = ('G2.omega' - 'G2.port.omegaRef') * 314.1592653589793;
  'G2.Ta' * 'G2.omega' * der('G2.omega') = 'G2.Ps' + 'G2.Pc' - 'G2.Pe';
  'G2.port.v' = 'Modelica.ComplexMath.fromPolar'('G2.V', 'G2.theta');
  'G2.Pe' = (-'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('G2.port.v', 'Modelica.ComplexMath.conj'('G2.port.i'))[field: re]);
  'G2.Pc' = (-('G2.omega' - 1.0) / 'G2.droop');
  'G2.port.omegaRef' = 'G2.omega';
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L1.port.v', 'Modelica.ComplexMath.conj'('L1.port.i')) = 'Complex.'constructor'.fromReal'('L1.P', 'L1.Q');
  'Modelica.SIunits.ComplexPerUnit.'*'.multiply'('L2.port.v', 'Modelica.ComplexMath.conj'('L2.port.i')) = 'Complex.'constructor'.fromReal'('L2.P', 'L2.Q');
  'Modelica.SIunits.ComplexPerUnit.'+''('T1a.port_a.i', 'T1a.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1a.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1a.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1a.port_a.v', 'T1a.port_b.v'));

  when 'T1a.open' then
    'T1a.closed' = false;
    'T1a.B_act' = 0.0;
  elsewhen 'T1a.close' then
    'T1a.closed' = true;
    'T1a.B_act' = 'T1a.B';
  end when;

  'T1a.port_a.omegaRef' = 'T1a.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T1b.port_a.i', 'T1b.port_b.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T1b.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T1b.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T1b.port_a.v', 'T1b.port_b.v'));

  when 'T1b.open' then
    'T1b.closed' = false;
    'T1b.B_act' = 0.0;
  elsewhen 'T1b.close' then
    'T1b.closed' = true;
    'T1b.B_act' = 'T1b.B';
  end when;

  'T1b.port_a.omegaRef' = 'T1b.port_b.omegaRef';
  'Modelica.SIunits.ComplexPerUnit.'+''('T2.port_a.i', 'T2.port_b_int.i') = 'Complex.'constructor'.fromReal'(0.0, 0.0);
  'T2.port_a.i' = 'Complex.'*'.multiply'('Complex.'constructor'.fromReal'(0.0, 'T2.B_act'), 'Modelica.SIunits.ComplexPerUnit.'-'.subtract'('T2.port_a.v', 'T2.port_b_int.v'));

  when 'T2.open' then
    'T2.closed' = false;
    'T2.B_act' = 0.0;
  elsewhen 'T2.close' then
    'T2.closed' = true;
    'T2.B_act' = 'T2.B';
  end when;

  'T2.port_a.omegaRef' = 'T2.port_b_int.omegaRef';
end 'DynamicOverconstrainedConnectors.System4';
"

end
