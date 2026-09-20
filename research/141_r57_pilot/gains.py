import numpy as np, model as mo
from crlb import y_eff
C=mo.C;N=mo.N;X=mo.X;d=mo.D;B=mo.B;fc=mo.FC
x2=np.mean(X**2); sx2=np.std(X**2)
print(f"d={d*1e3:.6f} mm   <x^2>={x2:.7f} m^2   sigma_x2={sx2:.7f} m^2   x_max={X.max():.5f} m")
fm=mo.freqs(np.arange(2047)); varf=np.var(fm); mf2=np.mean(fm**2)
print(f"Var_m(f)={varf:.6e} (B^2/12={B**2/12:.6e})   <f^2>={mf2:.6e}")
def Gclosed(th,r):
    t=np.deg2rad(th); g=1-x2*np.cos(t)**2/(2*r**2)
    vg=(np.cos(t)**4/(4*r**4))*sx2**2
    return np.sqrt(1+g**2*varf/(mf2*vg))
def Gapprox(th,r):
    t=np.deg2rad(th); return B*r**2/(np.sqrt(3)*fc*np.cos(t)**2*sx2)
print("\n gain factor G = sigma_r(free alpha)/sigma_r(coherent)   [std ratio]")
print(f"{'theta':>7} " + "".join(f"{r:>12.0f} m" for r in [15,20,25,30,40,50]))
for th in [0,20,35,50,60]:
    print(f"{th:7.0f} " + "".join(f"{Gclosed(th,r):14.1f}" for r in [15,20,25,30,40,50]))
print("\n closed form vs exact numerical FIM (SNR=-10 dB):")
for (th,r) in [(20.,25.),(-35.,40.),(5.,18.),(60.,50.),(0.,15.)]:
    If=y_eff(th,r,-10.,np.arange(2047),'free_alpha')[0,0]
    Ib=y_eff(th,r,-10.,np.arange(2047),'beta')[0,0]
    print(f"  th={th:6.1f} r={r:5.1f}: numeric G={np.sqrt(Ib/If):9.1f}"
          f"   closed form={Gclosed(th,r):9.1f}   approx={Gapprox(th,r):9.1f}")
