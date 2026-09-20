import numpy as np, model as mo
C=mo.C;N=mo.N
K=2047; k=2*np.pi*mo.freqs(np.arange(K))/C
th=np.deg2rad(20.0); r=25.0
g=1-mo.X**2*np.cos(th)**2/(2*r**2); gBar=g.mean(); gVar=g.var()
centred=np.sum((k-k.mean())**2); total=np.sum(k**2)
# reference values from final.py section B (exact numerical FIM, theta=20 r=25)
ref={-10:{0:1.703e-04,1e-15:1.703e-04,1e-14:1.703e-04,1e-13:1.729e-04,
          1e-12:3.448e-04,1e-11:3.002e-03,1e-9:1.066e-01,None:1.140e-01},
     0:{0:5.384e-05,1e-13:6.163e-05,1e-12:3.046e-04,1e-11:2.988e-03,
        1e-9:3.581e-02,None:3.607e-02},
     20:{0:5.384e-06,1e-13:3.046e-05,1e-12:2.988e-04,1e-11:2.305e-03,
         1e-9:3.606e-03,None:3.607e-03}}
def closed(snr,st):
    scale=2*N/10**(-snr/10)
    Irr=scale*(gBar**2*centred+gVar*total)
    Irt=scale*C*gBar*centred
    Itt=scale*C**2*centred
    if st==0: return 1/np.sqrt(Irr)
    if st is None: prior=Itt
    else: prior=Itt+1/st**2
    return np.sqrt(prior/(Irr*prior-Irt**2))
print(f"{'SNR':>5}{'sigma_tau':>12}{'closed form':>14}{'exact FIM ref':>15}{'rel diff':>11}")
ok=True
for snr,tbl in ref.items():
    for st,val in tbl.items():
        c=closed(snr,st)
        d=abs(c-val)/val
        if d>2e-3: ok=False
        lab='free' if st is None else ('known' if st==0 else f"{st:.0e}")
        print(f"{snr:>5}{lab:>12}{c:14.4e}{val:15.4e}{d:11.2e}")
print("\nlimits: sigma_tau=0 -> coherent ; sigma_tau->inf -> free-alpha")
free=2*N/10**(10/10)*gVar*total
print(f"  free-alpha closed  = {1/np.sqrt(free):.6e}   hybrid(1e-3) = {closed(-10,1e-3):.6e}"
      f"   hybrid(inf) = {closed(-10,None):.6e}")
print("ALL WITHIN 0.2%%" if ok else "MISMATCH")
