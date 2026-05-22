model UseMyLib
  MyLib.Source src;
  MyLib.Gain   gain(k = 3.0);
  Real out;
equation
  gain.u = src.y;
  out    = gain.y;
end UseMyLib;
