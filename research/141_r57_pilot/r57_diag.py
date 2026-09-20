import json,numpy as np,model as mo
C=mo.C;N=mo.N;X=mo.X
x2=np.mean(X**2); sx2=np.std(X**2)
fm=mo.freqs(np.arange(2047)); varf=np.var(fm); mf2=np.mean(fm**2)
rows=[json.loads(l) for l in open('r57_smoke.log') if l.startswith('{')]

def crlb_coh(th,r,snr):
    """coherent common-beta CRLB for r (theta known), closed form."""
    t=np.deg2rad(th); rho=10**(snr/10)
    g=1-x2*np.cos(t)**2/(2*r**2); vg=(np.cos(t)**4/(4*r**4))*sx2**2
    K=2047
    I=2*N*rho*( g**2*K*varf*(2*np.pi/C)**2 + vg*K*mf2*(2*np.pi/C)**2 )
    return 1/np.sqrt(I)

print("per-row: P_FACR error vs its own CRLB, and the baselines")
print(f"{'pos':>4}{'snr':>6}{'CRLB_coh':>12}{'|e|FACR':>12}{'e/CRLB':>9}"
      f"{'|e|P_A':>12}{'|e|FALF':>12}{'|e|FACR_T':>12}")
for r in rows:
    c=crlb_coh(r['truthThetaDeg'],r['truthRangeM'],r['snrDb'])
    e=abs(r['P_FACR']-r['truthRangeM'])
    print(f"{r['positionId']:>4}{r['snrDb']:>6.0f}{c:12.3e}{e:12.3e}{e/c:9.2f}"
          f"{abs(r['P_A_proxy']-r['truthRangeM']):12.3e}"
          f"{abs(r['P_FALF']-r['truthRangeM']):12.3e}"
          f"{abs(r['P_FACR_T']-r['truthRangeM']):12.3e}")

print("\n=== efficiency gate candidate: RMSE(P_FACR)/sqrt(mean CRLB^2) per SNR ===")
for s in sorted({r['snrDb'] for r in rows}):
    S=[r for r in rows if r['snrDb']==s]
    e=np.array([r['P_FACR']-r['truthRangeM'] for r in S])
    c=np.array([crlb_coh(r['truthThetaDeg'],r['truthRangeM'],r['snrDb']) for r in S])
    print(f"  SNR {s:+5.0f}: RMSE={np.sqrt(np.mean(e**2)):.4e}  "
          f"rms CRLB={np.sqrt(np.mean(c**2)):.4e}  efficiency ratio={np.sqrt(np.mean(e**2)/np.mean(c**2)):.3f}")

print("\n=== why G9 failed: the DENOMINATOR is heavy-tailed, not P_FACR ===")
for s in sorted({r['snrDb'] for r in rows}):
    S=[r for r in rows if r['snrDb']==s]
    pa=np.array([abs(r['P_A_proxy']-r['truthRangeM']) for r in S])
    print(f"  SNR {s:+5.0f}: P_A_proxy per-row |e| = "+", ".join(f"{v:.3e}" for v in pa))
