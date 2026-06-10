// Reproducer for replaceable package / partial package instantiation.
// Tests both a simple partial-extends pattern and the harder pattern with
// abstract functions referencing abstract types (the Buildings.Fluid failure mode).

package Types
  type AbsolutePressure = Real;
  type Temperature = Real;
end Types;

// -- Simple partial package (should pass before and after fix) --

partial package PartialMedium
  extends Types;
end PartialMedium;

package Water
  extends PartialMedium;
end Water;

block LumpedVolumeDeclarations
  replaceable package Medium = PartialMedium;
  parameter Medium.AbsolutePressure p_start = 0;
  parameter Medium.Temperature T_start = 0;
end LumpedVolumeDeclarations;

model ComparePower
  package Medium = Water;
  replaceable LumpedVolumeDeclarations mov1;
end ComparePower;

model ReplaceablePkgTest
  extends ComparePower(redeclare LumpedVolumeDeclarations mov1(
    redeclare final package Medium = Medium));
end ReplaceablePkgTest;

// -- Harder pattern: abstract function + abstract type (Buildings.Fluid failure mode) --

partial package AbstractMedium
  replaceable record ThermodynamicState
  end ThermodynamicState;

  replaceable function specificEnthalpy
    input ThermodynamicState state;
    output Real h;
  end specificEnthalpy;
end AbstractMedium;

package DryAir
  extends AbstractMedium;
  redeclare record ThermodynamicState
    Real T = 293.15;
  end ThermodynamicState;
  redeclare function specificEnthalpy
    input ThermodynamicState state;
    output Real h;
  algorithm
    h := 1005.0 * state.T;
  end specificEnthalpy;
end DryAir;

model HeaterBase
  replaceable package Medium = AbstractMedium constrainedby AbstractMedium;
  parameter Real h_start = 0;
end HeaterBase;

model HeaterDryAir
  extends HeaterBase(redeclare package Medium = DryAir);
end HeaterDryAir;

// -- Partial function called through its partial default (Buildings.Fluid failure mode) --

partial package AbstractFnPkg2
  replaceable partial function compute
    input Real x;
    output Real y;
  end compute;
end AbstractFnPkg2;

model UsePartialDefault
  replaceable package P = AbstractFnPkg2 constrainedby AbstractFnPkg2;
  Real r;
equation
  r = P.compute(time);
end UsePartialDefault;
