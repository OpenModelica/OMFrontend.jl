model CoupledPenduli
  model Table
    parameter Real m = 100.;
    public Real x(start=0.,fixed=true);
    protected Real u(start=0.,fixed=true);
    public Real f;
  equation
    m*der(u) - f = 0;
    der(x) = u;
  end Table;
  model Pendulum
    parameter Real m = 1.;
    parameter Real l = 1.;
    parameter Real g = 9.81;
    parameter Real theta0 = 0;
    public Real x;
    public Real f;
    protected Real a(start=l*sin(theta0),fixed=true);
    protected Real b(start=-l*cos(theta0),fixed=false);
    protected Real u(start=0.,fixed=true);
    protected Real v(start=0.,fixed=true);
    protected Real lambda;
  equation
    m*der(u) - lambda*(a-x) = 0;
    m*der(v) - lambda*b + m*g = 0;
    der(a) = u;
    der(b) = v;
    (a-x)^2 + b^2 - l^2 = 0;
    f - lambda*(a-x)/l = 0;
  end Pendulum;
  structuralmode Table tb;
  structuralmode Pendulum p1(theta0 = 0.1);
  structuralmode Pendulum p2(theta0 = 0.0);
equation
  p1.x = tb.x;
  p2.x = tb.x;
  tb.f + p1.f + p2.f = 0;
end CoupledPenduli;
