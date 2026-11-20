package RecordBindings "Record bindings and package constants of records (MSL Batteries, MSL Media)"
  package Redeclared "A redeclared record field, bound two levels above (MSL Batteries' stack.stackData)"
    record RC
      parameter Real R;
    end RC;
    record Cell0
      parameter Real Ri = 1;
    end Cell0;
    record Cell
      extends Cell0;
      parameter Integer nRC = 1 annotation(Evaluate = true);
      parameter RC rc[nRC] = {RC(R = 0)};
      parameter Real t[:, 2] = [0, 0; 1, 1];
    end Cell;
    record Example
      extends Cell(nRC = 2, rc = {RC(R = 1), RC(R = 2)}, t = [0, 0; 1, 1; 2, 4]);
    end Example;
    record BaseStack
      replaceable parameter Cell0 cell;
    end BaseStack;
    record Stack
      extends BaseStack(redeclare Cell cell);
    end Stack;
    model Holder
      parameter Stack st;
      Real w = sum(st.cell.rc.R) + size(st.cell.t, 1);
    end Holder;
    model M
      parameter Example ex;
      parameter Stack st(cell = ex);
      Holder h(st = st);
    end M;
  end Redeclared;

  package InlinedConstants "An inlined function's package constants (MSL Media's h_TX reading data and nX)"
    record Data
      Real MM;
      Real cp;
    end Data;
    package Gases
      constant Data N2(MM = 0.028, cp = 1040.0);
      constant Data O2(MM = 0.032, cp = 918.0);
    end Gases;
    function cp_T "two statements: not inlined"
      input Data data;
      input Real T;
      output Real cp;
    protected
      Real c;
    algorithm
      c := data.cp;
      cp := c + 0 * T;
    end cp_T;
    package Medium
      constant Integer nX = 2;
      constant Data data[nX] = {Gases.N2, Gases.O2};
      function cp_X "one statement: inlined"
        input Real T;
        input Real X[nX];
        output Real cp;
      algorithm
        cp := X * {cp_T(data[i], T) for i in 1:nX};
      end cp_X;
    end Medium;
    model M
      Real T = 300;
      Real X[2] = {0.7, 0.3};
      Real cp;
    equation
      cp = Medium.cp_X(T, X) "inlined in equations only";
    end M;
  end InlinedConstants;

  package ConstructorField "A field of a record set by a record constructor, read through a parent without a binding (Buildings' borefield conDat.mBorFie_flow_nominal)"
    record Bor
      parameter Real cooBor[:, 2];
      parameter Integer nBor = size(cooBor, 1);
      parameter Real mBor = 0.5;
      parameter Real mBorFie = mBor * nBor;
    end Bor;
    record Dat
      parameter Bor conDat;
    end Dat;
    model Use
      parameter Dat dat;
      parameter Integer n = integer(dat.conDat.mBorFie * 10);
      Real x[n];
    equation
      x = ones(n);
    end Use;
    model M
      parameter Dat dat(conDat = Bor(cooBor = [0, 0; 1, 1; 2, 2]));
      Use u(dat = dat);
    end M;
    model M2 "the parent bound to a constructor call"
      Use u(dat = Dat(conDat = Bor(cooBor = [0, 0; 1, 1; 2, 2])));
    end M2;
  end ConstructorField;

  package PartialRecord "A record constant bound in a partial application, passed to a function of one statement (MSL Media's solveOneNonlinearEquation(function f_nonlinear(data = data, ...), ...))"
    record Coeffs
      Real a;
      Real b;
    end Coeffs;
    constant Coeffs coeffs = Coeffs(a = 2, b = 3);
    partial function Base
      input Real u;
      output Real y;
    end Base;
    function lin
      extends Base;
      input Coeffs c;
    algorithm
      y := c.a * u + c.b;
    end lin;
    function apply "calls the function it is given"
      input Base f;
      input Real u;
      output Real y;
    algorithm
      y := f(u);
    end apply;
    model M
      Real x(start = 1, fixed = true);
      Real y;
    equation
      y = apply(function lin(c = coeffs), x);
      der(x) = y - 3 * x - 3;
    end M;
  end PartialRecord;
end RecordBindings;
