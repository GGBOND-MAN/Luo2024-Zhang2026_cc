import numpy as np, model as mo
from crlb import rip, eff_info, y_block, z_eff, y_eff
C=mo.C; N=mo.N
CAR=np.arange(2047)
scan=mo.prepare_scan()

def legendre_basis(f,deg):
    """Gram-Schmidt orthonormal polynomial basis on the carrier grid, uniform weight."""
    t=(f-f.mean())/((f.max()-f.min())/2)
    Bs=[]
    for k in range(deg+1):
        v=t**k
        for u in Bs: v=v-np.dot(v,u)*u
        v=v/np.linalg.norm(v); Bs.append(v)
    return Bs   # Bs[1] is the delay (degree-1) direction

print("### A. orthogonalised dispersion basis: cost of including degrees >=2")
for (th,r) in [(20.0,25.0),(-35.0,40.0)]:
    Bk=y_block(th,r,-10.0,CAR); a=Bk['a']; f=Bk['f']; al=Bk['alpha']
    P=legendre_basis(f,6)
    coefR=np.real(np.sum(np.conj(a)*Bk['Dr'],axis=0)); Dp=Bk['Dr']-a*coefR[None,:]
    ref=eff_info([Dp],[1j*a],Bk['sig2'])[0,0]
    for degs in [[0],[0,2],[0,2,3],[0,2,3,4,5,6],[0,1,2,3]]:
        nz=[al*(1j*P[k][None,:])*a for k in degs]
        v=eff_info([Dp],nz,Bk['sig2'])[0,0]
        tag="degrees "+",".join(map(str,degs))+(" (incl. delay)" if 1 in degs else "")
        print(f"  th={th:6.1f} r={r:5.1f}  free rho_m + orthog. phase {tag:32s}"
              f" sqrt(CRLB)={1/np.sqrt(v):.4e}  loss x{np.sqrt(ref/v):.3f}")

print("\n### B. hybrid CRLB with a Gaussian timing prior tau ~ N(0, sigma_tau^2)")
for (th,r) in [(20.0,25.0)]:
    for snr in [-10.0,0.0,20.0]:
        Bk=y_block(th,r,snr,CAR); a=Bk['a']; f=Bk['f']; al=Bk['alpha']
        coefR=np.real(np.sum(np.conj(a)*Bk['Dr'],axis=0)); Dp=Bk['Dr']-a*coefR[None,:]
        Dtau=al*(-1j*2*np.pi*f[None,:])*a
        s2=Bk['sig2']
        nzb=[1j*a]
        # build 2x2 (r,tau) efficient info after removing common phase
        def proj(v,basis):
            G=np.array([[rip(u,w) for w in basis] for u in basis])
            c=np.array([rip(v,u) for u in basis])
            s=np.linalg.solve(G,c)
            out=v.copy()
            for ci,u in zip(s,basis): out=out-ci*u
            return out
        Dr2=proj(Dp,nzb); Dt2=proj(Dtau,nzb)
        I=(2/s2)*np.array([[rip(Dr2,Dr2),rip(Dr2,Dt2)],[rip(Dt2,Dr2),rip(Dt2,Dt2)]])
        row=[]
        for st in [0,1e-15,1e-14,1e-13,1e-12,1e-11,1e-9,np.inf]:
            J=I.copy()
            if st==0: sr=1/np.sqrt(J[0,0])
            else:
                J[1,1]+= (0.0 if np.isinf(st) else 1/st**2)
                sr=np.sqrt(np.linalg.inv(J)[0,0])
            row.append((st,sr))
        print(f"  SNR {snr:+5.0f} dB : "+"  ".join(
            [("tau known" if s==0 else ("tau free" if np.isinf(s) else f"s_tau={s:.0e}"))
             +f"->{v:.3e} m" for s,v in row]))

print("\n### C. maximum achievable gain of Direction B (cross-fitting / efficient score)")
print("    plug-in angle penalty  kappa^2 * sigma_theta^2  relative to range MSE")
for (th,r) in [(20.0,25.0),(-35.0,40.0),(5.0,18.0)]:
    for snr in [-10.0,0.0,20.0]:
        I2=y_eff(th,r,snr,CAR,'free_alpha',interest=('t','r'))
        Iz2,_,_=z_eff(th,r,snr,scan,'beta',interest=('t','r'))
        J=I2+Iz2; Cv=np.linalg.inv(J)
        kappa=-J[1,0]/J[1,1]                    # m per rad
        sth=np.sqrt(Cv[0,0]); sr=1/np.sqrt(J[1,1])
        print(f"  th={th:6.1f} r={r:5.1f} SNR{snr:+5.0f}: sigma_r={sr:.3e} m, "
              f"kappa={np.deg2rad(kappa):+.4f} m/deg, sigma_theta={np.rad2deg(sth):.3e} deg, "
              f"(kappa*sigma_theta)^2/sigma_r^2 = {(kappa*sth/sr)**2:.3e}")
