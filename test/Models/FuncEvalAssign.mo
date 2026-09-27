// Assignments in functions evaluated at compile time; see funcEvalAssignTests.jl.

package FuncEvalAssign
  // Non-square, so that a transposed unbound output shows.
  function fillRect
    input Integer m;
    input Integer n;
    output Real y[m, n];
  algorithm
    for i in 1:m loop
      for j in 1:n loop
        y[i, j] := 10 * i + j;
      end for;
    end for;
  end fillRect;

  function zerosRows
    input Integer m;
    output Real y[m, m];
  algorithm
    y := zeros(m, m);
    for i in 1:m loop
      for j in 1:m loop
        y[i, j] := 10 * i + j;
      end for;
    end for;
  end zerosRows;

  // Assigning v[1] after v := u leaves u, here a package constant, unchanged for
  // later uses (w2, c1).
  function writeCopy
    input Real u[2];
    output Real y;
  protected
    Real v[2];
  algorithm
    v := u;
    v[1] := 100;
    y := v[1] + u[1];
  end writeCopy;

  record R
    Real x;
  end R;

  // Assigning r1.x after r2 := r1 leaves r2 unchanged.
  function recordCopy
    input Real a;
    output Real y;
  protected
    R r1;
    R r2;
  algorithm
    r1.x := a;
    r2 := r1;
    r1.x := 7;
    y := r2.x;
  end recordCopy;

  // Assigning r1.x after rs := {r1, r2} leaves rs[1] unchanged.
  function arrayOfRecords
    input Real a;
    output Real y;
  protected
    R r1;
    R r2;
    R rs[2];
    R r3;
  algorithm
    r1.x := a;
    r2.x := 2 * a;
    rs := {r1, r2};
    r1.x := 7;
    r3 := rs[1];
    y := r3.x;
  end arrayOfRecords;

  function setX
    input R u;
    input Real v;
    output R y = u;
  algorithm
    y.x := v;
  end setX;

  // setX must not write the caller's r1. A field assignment to an output bound to
  // a record is not evaluated at compile time, so this stays a call.
  function callerSetX
    input Real a;
    output Real y;
  protected
    R r1;
    R r2;
  algorithm
    r1.x := a;
    r2 := setX(r1, 7);
    y := r1.x + 10 * r2.x;
  end callerSetX;

  constant Real C[2] = {1, 2};
  constant Real w1 = writeCopy(C);
  constant Real w2 = writeCopy(C);
  constant Real c1 = C[1];
end FuncEvalAssign;

model TestFuncEvalAssign
  parameter Real rect[2, 3] = FuncEvalAssign.fillRect(2, 3);
  parameter Real rows[2, 2] = FuncEvalAssign.zerosRows(2);
  parameter Real w[3] = {FuncEvalAssign.w1, FuncEvalAssign.w2, FuncEvalAssign.c1};
  parameter Real r[3] = {FuncEvalAssign.recordCopy(3), FuncEvalAssign.arrayOfRecords(3), FuncEvalAssign.callerSetX(3)};
  Real h;
equation
  der(h) = 0;
end TestFuncEvalAssign;
