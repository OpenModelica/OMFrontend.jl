#=
This file defines the test cases for the equation tests.
Tests here are typicaly small tests that are easy to debug, but tests semi advance features of the compiler.
To add a test add a reference string, a model to the ./Equation folder and the name of the model.
=#
circleReference = "class Circle
  Real x_out;
  Real y_out;
  Real x(start = 0.1);
  Real y(start = 0.1);
equation
  der(x) = -y;
  der(y) = x;
  x_out = x;
  y_out = y;
end Circle;
"

arrayfancyReference="class ArrayFancy
  parameter Integer N = 10;
  Real x[1](start = 1.0);
  Real x[2](start = 2.0);
  Real x[3](start = 3.0);
  Real x[4](start = 4.0);
  Real x[5](start = 5.0);
  Real x[6](start = 6.0);
  Real x[7](start = 7.0);
  Real x[8](start = 8.0);
  Real x[9](start = 9.0);
  Real x[10](start = 10.0);
equation
  x[1] = der(x[1]);
  x[2] = der(x[2]);
  x[3] = der(x[3]);
  x[4] = der(x[4]);
  x[5] = der(x[5]);
  x[6] = der(x[6]);
  x[7] = der(x[7]);
  x[8] = der(x[8]);
  x[9] = der(x[9]);
  x[10] = der(x[10]);
end ArrayFancy;
"

ifEquationDerReference = "class IfEquationDer
  parameter Real u = 4.0;
  parameter Real uMax = 10.0;
  parameter Real uMin = 2.0;
  Real y;
equation
  if uMax < time then
    der(y) = uMax;
  elseif uMin < time then
    der(y) = uMin;
  elseif true then
    der(y) = u;
  end if;
end IfEquationDer;
"

testArrayEqReference ="class TestArrayEq
  parameter Real 'B1.ex_a'[1] = 1.0;
  parameter Real 'B1.ex_a'[2] = 2.0;
  parameter Real 'B1.ex_a'[3] = 3.0;
  Real 'B1.f_c'[1](quantity = \"Force\", unit = \"N\");
  Real 'B1.f_c'[2](quantity = \"Force\", unit = \"N\");
  Real 'B1.frame_a.f'[1](quantity = \"Force\", unit = \"N\");
  Real 'B1.frame_a.f'[2](quantity = \"Force\", unit = \"N\");
  Real 'B1.frame_a.f'[3](quantity = \"Force\", unit = \"N\");
  parameter Real 'B1.ey_a'[1](unit = \"1\") = 1.0;
  parameter Real 'B1.ey_a'[2](unit = \"1\") = 2.0;
  parameter Real 'B1.ey_a'[3](unit = \"1\") = 3.0;
equation
  'B1.frame_a.f'[1] = 0.0;
  'B1.frame_a.f'[2] = 'B1.f_c'[1];
  'B1.frame_a.f'[3] = 'B1.f_c'[2];
end TestArrayEq;
"

testEvalCat1Reference = "class TestEvalCat_TestEvalCat1
  Real OUT[1];
  Real OUT[2];
  Real OUT[3];
  Real 'der_Q'[1];
  Real 'der_Q'[2];
  Real 'der_Q'[3];
  Real 'der_Q'[4];
equation
  OUT[1] = 'der_Q'[1] + 2.0 * 'der_Q'[2] + 3.0 * 'der_Q'[3] + 4.0 * 'der_Q'[4];
  OUT[2] = 5.0 * 'der_Q'[1] + 6.0 * 'der_Q'[2] + 7.0 * 'der_Q'[3] + 8.0 * 'der_Q'[4];
  OUT[3] = 9.0 * 'der_Q'[1] + 10.0 * 'der_Q'[2] + 11.0 * 'der_Q'[3] + 12.0 * 'der_Q'[4];
  'der_Q'[1] = 0.0;
  'der_Q'[2] = 0.0;
  'der_Q'[3] = 0.0;
  'der_Q'[4] = 0.0;
end TestEvalCat_TestEvalCat1;
"

#=
More tests can be added like this.
That is a tuple of the reference string, the model name and the path to the model to translate.
=#
simpleAgenticTestReference = "class SimpleAgenticTest
  parameter Real y = 1.0;
  Real x(start = 0.0);
equation
  der(x) = y;

  when x > 5.0 then
    agentic_recompilation(y);
  end when;
end SimpleAgenticTest;
"

arrayfancy = (arrayfancyReference, "ArrayFancy", "./Equations/ArrayFancy.mo")
circle = (circleReference, "Circle", "./Equations/Circle.mo")
ifEquationDer = (ifEquationDerReference, "IfEquationDer", "./Equations/IfEquationDer.mo")
testArrayEq = (testArrayEqReference, "TestArrayEq", "./Equations/TestArrayEq.mo")
testEvalCat1 = (testEvalCat1Reference, "TestEvalCat.TestEvalCat1", "./Equations/TestEvalCat.mo")
simpleAgenticTest = (simpleAgenticTestReference, "SimpleAgenticTest", "./Equations/SimpleAgenticTest.mo")
#= If you make a new test add it to this array. =#
#= pre of an array is pre of each element, as omc: pre, edge and change were declared
   impure in the builtin library, so ExpandExp did not expand them element-wise and gave
   pre({reset[1], reset[2]})[1] (MSL StateGraph's MultiSwitch: pre(reset) = fill(false, nReset)). =#
preArrayReference = "class PreArray
  Boolean reset[1];
  Boolean reset[2];
  Boolean y;
initial equation
  pre(reset[1]) = false;
  pre(reset[2]) = false;
equation
  y = edge(reset[1]) or change(reset[2]);
  reset[1] = time > 0.5;
  reset[2] = time > 0.7;
end PreArray;
"
preArray = (preArrayReference, "PreArray", "./Equations/PreArray.mo")

equationTests = [circle, arrayfancy, ifEquationDer, testArrayEq, testEvalCat1, simpleAgenticTest, preArray]
