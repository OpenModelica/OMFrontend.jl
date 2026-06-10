package MyLib
  model Gain
    parameter Real k = 2.0;
    input  Real u;
    output Real y;
  equation
    y = k * u;
  end Gain;

  model Source
    output Real y;
  equation
    y = time;
  end Source;
end MyLib;
