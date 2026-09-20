import numpy as np, model as mo

C=mo.C; N=mo.N; M=mo.M

def rip(a,b):
    """real inner product Re{<a,b>} over flattened complex arrays"""
    return float(np.real(np.vdot(a,b)))

def eff_info(D, nuis, sigma2):
    """D: list of interest directions; nuis: list of nuisance directions.
       Returns efficient FIM for the interest block."""
    p=len(D)
    if nuis:
        G=np.array([[rip(u,v) for v in nuis] for u in nuis])
        Cx=np.array([[rip(u,v) for v in nuis] for u in D])
    I=np.array([[rip(u,v) for v in D] for u in D])
    if nuis:
        I=I-Cx@np.linalg.solve(G,Cx.T)
    return (2.0/sigma2)*I

def y_block(theta_deg, r, snr_db, carriers):
    th=np.deg2rad(theta_deg); k=2*np.pi*mo.freqs(carriers)/C; f=mo.freqs(carriers)
    a=mo.a_array(th,r,k)                 # N x K, unit norm columns
    alpha=np.sqrt(N)                     # true per-carrier gain (simulator: |signal|=1)
    dur=mo.du_dr(th,r)[:,None]; dut=mo.du_dth(th,r)[:,None]
    Dr = alpha*(-1j*k[None,:]*dur)*a
    Dt = alpha*(-1j*k[None,:]*dut)*a
    sig2=10**(-snr_db/10)
    return dict(a=a,f=f,k=k,alpha=alpha,Dr=Dr,Dt=Dt,sig2=sig2)

def y_eff(theta_deg,r,snr_db,carriers,model,interest=('r',)):
    B=y_block(theta_deg,r,snr_db,carriers)
    a=B['a']; K=a.shape[1]
    D=[B['Dr']] if interest==('r',) else [B['Dt'],B['Dr']]
    if model=='free_alpha':
        # per-carrier complex projection: remove component along a_m in each carrier
        Dp=[]
        for d in D:
            coef=np.sum(np.conj(a)*d,axis=0)       # a unit norm per column
            Dp.append(d-a*coef[None,:])
        I=np.array([[rip(u,v) for v in Dp] for u in Dp])
        return (2.0/B['sig2'])*I
    if model=='beta_tau':
        nz=[a, 1j*a, B['alpha']*(-1j*2*np.pi*B['f'][None,:])*a]
    elif model=='beta':
        nz=[a, 1j*a]
    elif model=='known':
        nz=[]
    else: raise ValueError(model)
    return eff_info(D,nz,B['sig2'])

def z_eff(theta_deg,r,snr_db,scan,model,interest=('r',)):
    th=np.deg2rad(theta_deg)
    q,qth,qr=mo.q_response(scan,th,r,deriv=True)
    sig2=np.mean(np.abs(q)**2)/10**(snr_db/10)
    beta=1.0
    D=[beta*qr] if interest==('r',) else [beta*qth,beta*qr]
    f=scan['f']
    if model=='beta_tau':
        nz=[q,1j*q,beta*(-1j*2*np.pi*f)*q]
    elif model=='beta':
        nz=[q,1j*q]
    elif model=='free_alpha':
        return np.zeros((len(D),len(D)))   # per-carrier free gain kills a scalar obs entirely
    else: raise ValueError(model)
    return eff_info(D,nz,sig2), sig2, q

scan=mo.prepare_scan()
cases=[(20.0,25.0),(-35.0,40.0),(5.0,18.0)]
carriers=np.arange(2047)   # K = 2047 as in protocol.pfa.carrierCount
print("K =",len(carriers))
for (th,r) in cases:
    print(f"\n=== truth theta={th} deg, r={r} m ===")
    q=mo.q_response(scan,np.deg2rad(th),r)
    p=np.abs(q)**2; p/=p.sum()
    f=scan['f']; fbar=(p*f).sum(); brms=np.sqrt((p*(f-fbar)**2).sum())
    print(f"  |q|^2 concentration: eff. #carriers (1/sum p^2) = {1/np.sum(p**2):.1f} / {M}")
    print(f"  z weighted RMS bandwidth = {brms/1e9:.4f} GHz  (full B_rms = {np.std(mo.freqs())/1e9:.4f} GHz)")
    print(f"  delay mainlobe c/B_eff ~ {C/(brms*np.sqrt(12))/1:.4f} m")
    for snr in [-10.0,0.0,20.0]:
        Iz_b,sz,_=z_eff(th,r,snr,scan,'beta'); Iz_bt,_,_=z_eff(th,r,snr,scan,'beta_tau')
        Iy_f=y_eff(th,r,snr,carriers,'free_alpha')
        Iy_b=y_eff(th,r,snr,carriers,'beta')
        Iy_bt=y_eff(th,r,snr,carriers,'beta_tau')
        def s(I): 
            return np.sqrt(1.0/I[0,0]) if I[0,0]>0 else np.inf
        print(f"  SNR {snr:+5.0f} dB | sqrt(CRLB_r) [m]: "
              f"z(beta)={s(Iz_b):.3e}  z(beta,tau)={s(Iz_bt):.3e}  "
              f"Y(free a)={s(Iy_f):.3e}  Y(beta)={s(Iy_b):.3e}  Y(beta,tau)={s(Iy_bt):.3e}")
        Ij_f=Iz_b+Iy_f; Ij_b=Iz_b+Iy_b
        print(f"            | joint z+Y: P_FALF-style={s(Ij_f):.3e}   coherent-Y={s(Ij_b):.3e}"
              f"   ratio Y(free)/Y(beta)={np.sqrt(Iy_b[0,0]/Iy_f[0,0]):.1f}x")
