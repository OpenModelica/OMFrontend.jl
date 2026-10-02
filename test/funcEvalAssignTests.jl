#=
Assignments in functions evaluated at compile time (NFEvalFunction.jl) must change
only their target (Models/FuncEvalAssign.mo):
- rect: a non-square unbound output filled element by element;
- rows: zeros() then element writes (fill repeats one row);
- w: writing a copy of a package-constant argument leaves the constant unchanged
  for later uses (w2, c1);
- r[1], r[2]: assigning a record's field after copying the record, or an array of
  records built from it, leaves the copy unchanged;
- r[3]: a callee's output bound to its input does not write the caller's record
  (73 at run time; a field assignment to a bound record output is not evaluated at
  compile time, so the call stays).
=#

funcEvalAssignReference = "class TestFuncEvalAssign
  parameter Real rect[1, 1] = 11.0;
  parameter Real rect[1, 2] = 12.0;
  parameter Real rect[1, 3] = 13.0;
  parameter Real rect[2, 1] = 21.0;
  parameter Real rect[2, 2] = 22.0;
  parameter Real rect[2, 3] = 23.0;
  parameter Real rows[1, 1] = 11.0;
  parameter Real rows[1, 2] = 12.0;
  parameter Real rows[2, 1] = 21.0;
  parameter Real rows[2, 2] = 22.0;
  parameter Real w[1] = 101.0;
  parameter Real w[2] = 101.0;
  parameter Real w[3] = 1.0;
  parameter Real r[1] = 3.0;
  parameter Real r[2] = 3.0;
  parameter Real r[3] = FuncEvalAssign.callerSetX(3.0);
  Real h;
equation
  der(h) = 0.0;
end TestFuncEvalAssign;
"

funcEvalAssign = (funcEvalAssignReference, "TestFuncEvalAssign", "./Models/FuncEvalAssign.mo")

funcEvalAssignTests = [funcEvalAssign]
