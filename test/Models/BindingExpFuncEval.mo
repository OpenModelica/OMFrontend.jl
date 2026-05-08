// Tests for BINDING_EXP handling in function body constant evaluation.
// Exercises applyIndexExpArray and evalComponentBinding for package constants
// accessed inside function bodies via BINDING_EXP-wrapped subscript indices.

// -----------------------------------------------------------------------
// Test 1: Unqualified package constant used as array subscript index inside
// a function body. The index arrives as BINDING_EXP(INTEGER_EXPRESSION(1)).
// -----------------------------------------------------------------------
package PkgSubscriptIdx
  constant Integer Water = 1;
  constant Integer nX = 2;

  function useSubscript
    input Real X[nX];
    output Real y;
  algorithm
    y := X[Water];
  end useSubscript;

  constant Real X_ref[nX] = {0.5, 0.5};
  constant Real val = useSubscript(X_ref);
end PkgSubscriptIdx;

model TestPkgSubscriptIdx
  replaceable package Medium = PkgSubscriptIdx;
  parameter Real v = Medium.val;
  Real h;
equation
  der(h) = 0;
  h = v;
end TestPkgSubscriptIdx;


// -----------------------------------------------------------------------
// Test 2: Package constant derived from a record field (k_mair = s.MM/d.MM)
// and used as a multiplier inside a function body, together with an array
// subscript using a package-constant index.
// -----------------------------------------------------------------------
package PkgKmairAndIdx
  record DataRecord
    Real MM;
    Real R;
  end DataRecord;

  constant DataRecord steam(MM = 0.01801528, R = 461.52257);
  constant DataRecord dryair(MM = 0.0289651159, R = 287.102);
  constant Real k_mair = steam.MM / dryair.MM;
  constant Integer Water = 1;
  constant Integer nX = 2;

  function computeSomething
    input Real p;
    input Real T;
    input Real X[nX];
    output Real result;
  protected
    Real tmp;
  algorithm
    tmp := p * k_mair / (T * X[Water]);
    result := tmp;
  end computeSomething;

  constant Real p_ref = 1e5;
  constant Real T_ref = 300.0;
  constant Real X_ref[nX] = fill(1.0/nX, nX);
  constant Real val = computeSomething(p_ref, T_ref, X_ref);
end PkgKmairAndIdx;

model TestPkgKmairAndIdx
  replaceable package Medium = PkgKmairAndIdx;
  parameter Real v = Medium.val;
  Real h;
equation
  der(h) = 0;
  h = v;
end TestPkgKmairAndIdx;
