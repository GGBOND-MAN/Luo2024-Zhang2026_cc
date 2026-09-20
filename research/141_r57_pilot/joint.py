import numpy as np, model as mo
from crlb import y_eff, z_eff, rip, eff_info, y_block
C=mo.C; N=mo.N
scan=mo.prepare_scan()
carriers=np.arange(2047)
print("interest = (theta[rad], r[m]) jointly; kappa = -J_rt/J_rr [m per deg]")
for (th,r) in [(20.0,25.0),(-35.0,40.0),(5.0,18.0)]:
    print(f"\n=== theta={th} deg r={r} m ===")
    for snr in [-10.0,0.0,20.0]:
        out={}
        for name,mdl in [('Y_free','free_alpha'),('Y_beta','beta')]:
            I2=y_eff(th,r,snr,carriers,mdl,interest=('t','r'))
            Iz2,_,_=z_eff(th,r,snr,scan,'beta',interest=('t','r'))
            for tag,I in [(name,I2),(name+'+z',I2+Iz2)]:
                Cov=np.linalg.inv(I)
                sr_known=1/np.sqrt(I[1,1]); sr_joint=np.sqrt(Cov[1,1])
                st=np.sqrt(Cov[0,0])
                kappa=-I[1,0]/I[1,1]          # m per rad
                out[tag]=(sr_known,sr_joint,np.rad2deg(st),np.deg2rad(kappa))
        Izb,_,_=z_eff(th,r,snr,scan,'beta',interest=('t','r'))
        Cz=np.linalg.inv(Izb)
        print(f" SNR{snr:+5.0f}  z only : sig_r|t={1/np.sqrt(Izb[1,1]):.3e}  sig_r joint={np.sqrt(Cz[1,1]):.3e}"
              f"  sig_t={np.rad2deg(np.sqrt(Cz[0,0])):.3e} deg  kappa={np.deg2rad(-Izb[1,0]/Izb[1,1]):.4f} m/deg")
        for tag in ['Y_free','Y_free+z','Y_beta','Y_beta+z']:
            a,b,cc,k=out[tag]
            print(f"          {tag:9s}: sig_r|t={a:.3e}  sig_r joint={b:.3e}  sig_t={cc:.3e} deg  kappa={k:.5f} m/deg")
