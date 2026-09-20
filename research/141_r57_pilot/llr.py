import numpy as np, model as mo
C=mo.C;N=mo.N
CAR=np.arange(2047); f=mo.freqs(CAR); k=2*np.pi*f/C; K=len(CAR)
def sep(th,r,snr,dr):
    thr=np.deg2rad(th)
    a0=mo.a_array(thr,r,k); a1=mo.a_array(thr,r+dr,k)
    rho=10**(snr/10)
    # noncentrality of the LR between basin r and basin r+dr, signal at r
    cc=np.sum(np.conj(a1)*a0,axis=0)                 # per-carrier coherence
    free=2*N*K*rho*(1-np.mean(np.abs(cc)**2))        # free alpha_m
    coh =2*N*K*rho*(1-abs(np.mean(cc))**2)           # common beta
    return free,coh
print(" deflection (noncentrality) of the basin-vs-basin likelihood ratio, SNR=-10 dB")
print(f"{'dr [m]':>8} {'free alpha_m':>16} {'coherent beta':>16} {'ratio':>10}")
for dr in [0.02,0.05,0.1,0.2,0.5,1.0]:
    fr,co=sep(20.0,25.0,-10.0,dr)
    print(f"{dr:8.2f} {fr:16.3f} {co:16.3e} {co/max(fr,1e-12):10.1f}")

from math import erfc,sqrt
Q=lambda x:0.5*erfc(x/sqrt(2))
print("\n Bayes-optimal basin-decision error probability  Pe = Q(sqrt(lambda)/2)")
print(f"{'dr [m]':>8} {'SNR':>6} {'Pe free alpha_m':>18} {'Pe coherent':>14}")
for snr in [-10.0,-5.0,0.0]:
    for dr in [0.05,0.1,0.2,0.5]:
        fr,co=sep(20.0,25.0,snr,dr)
        print(f"{dr:8.2f} {snr:6.1f} {Q(np.sqrt(fr)/2):18.4f} {Q(np.sqrt(co)/2):14.2e}")
