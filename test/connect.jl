#= Different tests for connect =#
module ConnectTests

const Connect1="class Connect1
  flow Real c1.f;
  Real c1.e;
  flow Real c2.f;
  Real c2.e;
equation
  c1.e = c2.e;
  (-c1.f) - c2.f = 0.0;
  c1.f = 0.0;
  c2.f = 0.0;
  c1.e = 1.0;
  c2.f = time;
end Connect1;
"
const Connect2="class Connect2
  flow Real c1.f;
  Real c1.e;
  flow Real c2.f;
  Real c2.e;
  flow Real c3.f;
  Real c3.e;
equation
  c1.e = c2.e;
  c1.e = c3.e;
  (-c1.f) - c3.f - c2.f = 0.0;
  c1.f = 0.0;
  c2.f = 0.0;
  c3.f = 0.0;
  c1.e = 1.0;
  c2.f = time;
  c3.f = 1.0;
end Connect2;
"

const Connect3 = ""
const Connect4 ="class Connect4
  Integer c1.i;
  flow Real c1.f;
  Integer c2.i;
  flow Real c2.f;
equation
  c1.i = c2.i;
  (-c1.f) - c2.f = 0.0;
  c1.f = 0.0;
  c2.f = 0.0;
  c1.i = integer(time * 10.0);
end Connect4;
"

const Connect5="class Connect5
  Boolean c1.b;
  flow Real c1.f;
  Boolean c2.b;
  flow Real c2.f;
equation
  c1.b = c2.b;
  (-c1.f) - c2.f = 0.0;
  c1.f = 0.0;
  c2.f = 0.0;
  c1.b = time < 0.5;
end Connect5;
"

const Connect6="class Connect6
  String c1.s;
  flow Real c1.f;
  String c2.s;
  flow Real c2.f;
  Boolean b;
equation
  c1.s = c2.s;
  (-c1.f) - c2.f = 0.0;
  c1.f = 0.0;
  c2.f = 0.0;
  c1.s = \"h\";
  b = c2.s == \"h\";
end Connect6;
"

const Connect7 ="class Connect7
  parameter Integer N = 1;
  Real c[1].r;
  flow Real c[1].x;
  Real c[2].r;
  flow Real c[2].x;
  Real cx.r;
  flow Real cx.x = 2.0;
  Real cy.r;
  flow Real cy.x = time;
equation
  cx.r = c[1].r;
  (-c[1].x) - cx.x = 0.0;
  cy.r = c[2].r;
  (-cy.x) - c[2].x = 0.0;
  c[1].x = 0.0;
  c[2].x = 0.0;
  cx.x = 0.0;
  cy.x = 0.0;
end Connect7;
"

const Connect8 = "class Connect8
  parameter Integer N = 2;
  Real c[1].r;
  flow Real c[1].x;
  Real c[2].r;
  flow Real c[2].x;
  Real cx.r;
  flow Real cx.x = 1.0;
  Real cy.r;
  flow Real cy.x = time;
equation
  c[2].r = cx.r;
  c[2].r = cy.r;
  (-c[2].x) - cx.x - cy.x = 0.0;
  c[1].x = 0.0;
  c[2].x = 0.0;
  cx.x = 0.0;
  cy.x = 0.0;
  c[1].x = time;
end Connect8;
"
const Connect9 = "class Connect9
  input Real c1.x;
  output Real c2.x;
equation
  c2.x = c1.x;
end Connect9;
"
const Connect10 = "class Connect10\n  input Real c1_x;\n  input Real c2_x;\nequation\n  c2_x = c1_x;\nend Connect10;\n"
const Connect11 = "class Connect11\n  output Real c1_x;\n  output Real c2_x;\nequation\n  c2_x = c1_x;\nend Connect11;\n"
const Connect12 = ""
const Connect13 = ""
const Connect14 = ""
const Connect15 = "class Connect15
  flow Real t1.p[1].i;
  Real t1.p[1].v;
  flow Real t1.p[2].i;
  Real t1.p[2].v;
  flow Real t2.p[1].i;
  Real t2.p[1].v;
  flow Real t2.p[2].i;
  Real t2.p[2].v;
equation
  t2.p[2].v = t1.p[1].v;
  t1.p[1].i + t2.p[2].i = 0.0;
  t1.p[2].i = 0.0;
  t2.p[1].i = 0.0;
end Connect15;
"
const Connect16 = ""
const Connect17 = "class Connect17
  parameter Integer p = 3;
  input Real x[1];
  input Real x[2];
  input Real x[3];
  output Real y[1];
  output Real y[2];
  output Real y[3];
  output Real y[4];
equation
  x[1] = y[2];
  y[3] = x[2];
  y[4] = x[3];
end Connect17;
"
const Connect18 = "class Connect18
  constant Integer n = 5;
  Real a[1].e;
  flow Real a[1].f;
  Real a[2].e;
  flow Real a[2].f;
  Real a[3].e;
  flow Real a[3].f;
  Real a[4].e;
  flow Real a[4].f;
  Real a[5].e;
  flow Real a[5].f;
equation
  a[3].e = a[5].e;
  a[3].e = a[2].e;
  a[3].e = a[1].e;
  a[3].e = a[4].e;
  (-a[3].f) - a[1].f - a[5].f - a[4].f - a[2].f = 0.0;
  a[1].f = 0.0;
  a[2].f = 0.0;
  a[3].f = 0.0;
  a[4].f = 0.0;
  a[5].f = 0.0;
  a[1].e = 1.0;
end Connect18;
"
const Tank = "class Tank
  parameter Real area = 1.0;
  Real inlet.pressure;
  flow Real inlet.volumeFlowRate;
  Real outlet.pressure;
  flow Real outlet.volumeFlowRate;
  Real level(start = 2.0);
equation
  inlet.volumeFlowRate = 0.0;
  outlet.volumeFlowRate = 0.0;
  inlet.volumeFlowRate = 1.0;
  inlet.pressure = 1.0;
  area * der(level) = inlet.volumeFlowRate + outlet.volumeFlowRate;
  outlet.pressure = inlet.pressure;
  outlet.volumeFlowRate = 2.0;
end Tank;
"

const HeatTank = "class HeatTank
  parameter Real area = 1.0;
  Real inlet.pressure;
  flow Real inlet.volumeFlowRate;
  Real inlet.temp;
  Real outlet.pressure;
  flow Real outlet.volumeFlowRate;
  Real outlet.temp;
  Real level(start = 2.0);
  Real temp;
equation
  inlet.volumeFlowRate = 0.0;
  outlet.volumeFlowRate = 0.0;
  inlet.temp = 25.0;
  area * level * der(temp) = inlet.volumeFlowRate * inlet.temp + outlet.volumeFlowRate * outlet.temp;
  outlet.temp = temp;
  inlet.volumeFlowRate = 1.0;
  inlet.pressure = 1.0;
  area * der(level) = inlet.volumeFlowRate + outlet.volumeFlowRate;
  outlet.pressure = inlet.pressure;
  outlet.volumeFlowRate = 2.0;
end HeatTank;
"

const HeatTankExpanded="class HeatTankExpanded
  parameter Real Area = 1.0;
  Real inlet.pressure;
  flow Real inlet.volumeFlowRate;
  Real inlet.temp;
  Real outlet.pressure;
  flow Real outlet.volumeFlowRate;
  Real outlet.temp;
  Real level(start = 2.0);
  Real temp;
equation
  inlet.volumeFlowRate = 0.0;
  outlet.volumeFlowRate = 0.0;
  inlet.volumeFlowRate = 1.0;
  inlet.pressure = 1.0;
  inlet.temp = 25.0;
  Area * der(level) = inlet.volumeFlowRate + outlet.volumeFlowRate;
  outlet.pressure = inlet.pressure;
  Area * level * der(temp) = inlet.volumeFlowRate * inlet.temp + outlet.volumeFlowRate * outlet.temp;
  outlet.temp = temp;
  outlet.volumeFlowRate = 2.0;
end HeatTankExpanded;
"

#Tests that multiple inheritance is handled correctly with regards to connect_
const MultipleInheritanceConnect="class MultipleInheritanceConnect
  Real e.port.p;
  flow Real e.port.f;
  Real e.d.port.p;
  flow Real e.d.port.f;
equation
  e.port.p = e.d.port.p;
  e.port.f = 0.0;
  e.d.port.f - e.port.f = 0.0;
  e.d.port.f = e.d.port.p;
end MultipleInheritanceConnect;
"

const ResistorCircuit0 = "class ElectricalComponentTest_ResistorCircuit0
  Real R1.v;
  Real R1.i;
  Real R1.p.v;
  flow Real R1.p.i;
  Real R1.n.v;
  flow Real R1.n.i;
  parameter Real R1.R = 100.0;
  Real R2.v;
  Real R2.i;
  Real R2.p.v;
  flow Real R2.p.i;
  Real R2.n.v;
  flow Real R2.n.i;
  parameter Real R2.R = 200.0;
equation
  R2.p.v = R1.p.v;
  R2.p.i + R1.p.i = 0.0;
  R1.n.i = 0.0;
  R2.n.i = 0.0;
  R2.R * R2.i = R2.v;
  R2.v = R2.p.v - R2.n.v;
  0.0 = R2.p.i + R2.n.i;
  R2.i = R2.p.i;
  R1.R * R1.i = R1.v;
  R1.v = R1.p.v - R1.n.v;
  0.0 = R1.p.i + R1.n.i;
  R1.i = R1.p.i;
end ElectricalComponentTest_ResistorCircuit0;
"

const ResistorCircuit1 = "class ElectricalComponentTest_ResistorCircuit1
  Real R1.v;
  Real R1.i;
  Real R1.p.v;
  flow Real R1.p.i;
  Real R1.n.v;
  flow Real R1.n.i;
  parameter Real R1.R = 100.0;
  Real R2.v;
  Real R2.i;
  Real R2.p.v;
  flow Real R2.p.i;
  Real R2.n.v;
  flow Real R2.n.i;
  parameter Real R2.R = 200.0;
  Real R3.v;
  Real R3.i;
  Real R3.p.v;
  flow Real R3.p.i;
  Real R3.n.v;
  flow Real R3.n.i;
  parameter Real R3.R = 300.0;
equation
  R2.p.v = R3.p.v;
  R2.p.v = R1.p.v;
  R1.n.i = 0.0;
  R2.p.i + R3.p.i + R1.p.i = 0.0;
  R2.n.i = 0.0;
  R3.n.i = 0.0;
  R3.R * R3.i = R3.v;
  R3.v = R3.p.v - R3.n.v;
  0.0 = R3.p.i + R3.n.i;
  R3.i = R3.p.i;
  R2.R * R2.i = R2.v;
  R2.v = R2.p.v - R2.n.v;
  0.0 = R2.p.i + R2.n.i;
  R2.i = R2.p.i;
  R1.R * R1.i = R1.v;
  R1.v = R1.p.v - R1.n.v;
  0.0 = R1.p.i + R1.n.i;
  R1.i = R1.p.i;
end ElectricalComponentTest_ResistorCircuit1;
"

const SimpleCircuit = "class ElectricalComponentTest_SimpleCircuit
  Real R1.v;
  Real R1.i;
  Real R1.p.v;
  flow Real R1.p.i;
  Real R1.n.v;
  flow Real R1.n.i;
  parameter Real R1.R = 10.0;
  Real C.v;
  Real C.i;
  Real C.p.v;
  flow Real C.p.i;
  Real C.n.v;
  flow Real C.n.i;
  parameter Real C.C = 0.01;
  Real R2.v;
  Real R2.i;
  Real R2.p.v;
  flow Real R2.p.i;
  Real R2.n.v;
  flow Real R2.n.i;
  parameter Real R2.R = 100.0;
  Real L.v;
  Real L.i;
  Real L.p.v;
  flow Real L.p.i;
  Real L.n.v;
  flow Real L.n.i;
  parameter Real L.L = 0.1;
  Real AC.v;
  Real AC.i;
  Real AC.p.v;
  flow Real AC.p.i;
  Real AC.n.v;
  flow Real AC.n.i;
  parameter Real AC.A = 1.0;
  parameter Real AC.w = 1.0;
  Real G.p.v;
  flow Real G.p.i;
equation
  R2.p.v = AC.p.v;
  R2.p.v = R1.p.v;
  C.p.v = R1.n.v;
  R2.n.v = L.p.v;
  AC.n.v = C.n.v;
  AC.n.v = L.n.v;
  AC.n.v = G.p.v;
  R1.n.i + C.p.i = 0.0;
  L.p.i + R2.n.i = 0.0;
  G.p.i + C.n.i + L.n.i + AC.n.i = 0.0;
  R1.p.i + R2.p.i + AC.p.i = 0.0;
  G.p.v = 0.0;
  AC.v = AC.A * sin(AC.w * time);
  AC.v = AC.p.v - AC.n.v;
  0.0 = AC.p.i + AC.n.i;
  AC.i = AC.p.i;
  L.L * der(L.i) = L.v;
  L.v = L.p.v - L.n.v;
  0.0 = L.p.i + L.n.i;
  L.i = L.p.i;
  R2.R * R2.i = R2.v;
  R2.v = R2.p.v - R2.n.v;
  0.0 = R2.p.i + R2.n.i;
  R2.i = R2.p.i;
  C.i = C.C * der(C.v);
  C.v = C.p.v - C.n.v;
  0.0 = C.p.i + C.n.i;
  C.i = C.p.i;
  R1.R * R1.i = R1.v;
  R1.v = R1.p.v - R1.n.v;
  0.0 = R1.p.i + R1.n.i;
  R1.i = R1.p.i;
end ElectricalComponentTest_SimpleCircuit;
"

#= Expandable connector with a virtual element (bus.x). Regression test for the
   flat-tree self-append hang and the identity-set dedupe hang. =#
const ExpandableBus="class ExpandableBus
  Real bus.x;
  output Real src.y;
  input Real sink.u;
equation
  sink.u = src.y;
  sink.u = bus.x;
  src.y = time;
end ExpandableBus;
"

end
