import numpy as np, model as mo
from crlb import rip, eff_info, y_block
C=mo.C; N=mo.N
CAR=np.arange(2047)

def variants(theta_deg,r,snr):
    Bk=y_block(theta_deg,r,snr,CAR); a=Bk['a']; f=Bk['f']; al=Bk['alpha']
    fb=(f-f.mean())/ (f.max()-f.min())    # normalised, centred
    D=[Bk['Dr']]
    res={}
    def eff(nz): return eff_info(D,nz,Bk['sig2'])[0,0]
    # per-carrier free complex gain (P_FALF today)
    coef=np.sum(np.conj(a)*Bk['Dr'],axis=0); Dp=Bk['Dr']-a*coef[None,:]
    res['free complex alpha_m (current)'] = (2/Bk['sig2'])*rip(Dp,Dp)
    # per-carrier free REAL amplitude, one common phase
    #   nuisance dirs: {a_m real-scaling}_m  plus j*a (global phase)
    coefR=np.real(np.sum(np.conj(a)*Bk['Dr'],axis=0))
    Dp2=Bk['Dr']-a*coefR[None,:]
    res['free real rho_m + common phase'] = eff_info([Dp2],[1j*a],Bk['sig2'])[0,0]
    # common complex beta
    res['common complex beta']=eff([a,1j*a])
    # polynomial phase families
    for p in [1,2,3,5]:
        nz=[a,1j*a]+[al*(-1j*fb**k)*a for k in range(1,p+1)]
        res[f'beta + phase poly incl. linear, order {p}']=eff(nz)
    for p in [2,3,5]:
        nz=[a,1j*a]+[al*(-1j*fb**k)*a for k in range(2,p+1)]
        res[f'beta + phase poly EXCLUDING linear, order {p}']=eff(nz)
    # free amplitude per carrier + phase poly excluding linear (order 3)
    nzp=[1j*a]+[al*(-1j*fb**k)*a for k in range(2,4)]
    res['free rho_m + phase poly excl. linear, order 3']=eff_info([Dp2],nzp,Bk['sig2'])[0,0]
    return res

for (th,r) in [(20.0,25.0),(-35.0,40.0)]:
    for snr in [-10.0]:
        print(f"\n=== theta={th} r={r} SNR={snr} dB :  sqrt(CRLB_r) [m] ===")
        R=variants(th,r,snr)
        base=R['common complex beta']
        for k,v in R.items():
            print(f"  {k:48s} {1/np.sqrt(v):.4e}   (x{np.sqrt(base/v):8.1f} vs coherent)")
