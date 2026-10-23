#=
sin, cos and tan evaluated at compile time (NFCeval roundingZero, Models/TrigRounding.mo):
a value within its argument's rounding of zero is exactly zero. sin(2π) gave -2.4e-16, and
MSL's symmetrical-component matrices folded such values into equation coefficients (QuasiStatic
IMC_DOL's zero-sequence current, `-1.6e-16 * i[3].im`) that tearing then divided by. sin(1e-20)
and sin(π/6) keep their values.
=#

trigRoundingReference = "class TrigRounding_TestTrigRounding
  final parameter Real s[1] = 0.0;
  final parameter Real s[2] = 0.0;
  final parameter Real s[3] = 0.0;
  final parameter Real s[4] = 0.0;
  final parameter Real y[1] = 0.0;
  final parameter Real y[2] = 0.0;
  final parameter Real y[3] = 0.0;
  final parameter Real y[4] = 1.0e-20;
  final parameter Real y[5] = 0.49999999999999994;
  Real h;
equation
  der(h) = 0.0;
end TrigRounding_TestTrigRounding;
"

trigRounding = (trigRoundingReference, "TrigRounding.TestTrigRounding", "./Models/TrigRounding.mo")

trigRoundingTests = [trigRounding]
