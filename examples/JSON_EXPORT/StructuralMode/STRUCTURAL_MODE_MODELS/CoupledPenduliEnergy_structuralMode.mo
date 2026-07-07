model CoupledPenduli
  model Table
    parameter Real m = 100.;
    public Real x(start=0.,fixed=true);
    protected Real u(start=0.,fixed=true);
    public Real f;
    public Real e;
  equation
    m*der(u) - f = 0;
    der(x) = u;
    e = 0.5 * m * u^2;
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
    public Real e;
  equation
    m*der(u) - lambda*(a-x) = 0;
    m*der(v) - lambda*b + m*g = 0;
    der(a) = u;
    der(b) = v;
    (a-x)^2 + b^2 - l^2 = 0;
    f - lambda*(a-x)/l = 0;
    e = 0.5*m*(u^2 + v^2) + m*g*b;
  end Pendulum;
  structuralmode Table tb;
  structuralmode Pendulum p1(theta0 = 0.5);
  structuralmode Pendulum p2(theta0 = 0.0);
  Real e;
equation
  p1.x = tb.x;
  p2.x = tb.x;
  tb.f + p1.f + p2.f = 0;
  e = tb.e + p1.e + p2.e;
end CoupledPenduli;
