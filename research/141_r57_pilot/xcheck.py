"""Cross-check: re-implement +r57/gainModels.m literally and compare with the
formulas used by the validated 21-row smoke."""
import numpy as np, model as mo
from scipy.optimize import minimize_scalar, minimize
rng=np.random.default_rng(7)
K=2047; N=256
f=mo.freqs(np.arange(K)); C=mo.C; HALF=2.0

def legendre(fv,deg):
    t=(fv-fv.mean())/((fv.max()-fv.min())/2); Bs=[]
    for k in range(deg+1):
        v=t**k
        for u in Bs: v=v-np.dot(v,u)*u
        Bs.append(v/np.linalg.norm(v))
    return Bs
PSI=legendre(f,3); DISP=np.column_stack([PSI[2],PSI[3]])

# --- MATLAB +r57/gainModels.m transcription ---
def matlab_gain(c,aEnergy):
    energySum=np.sum(aEnergy)
    normalized=c/np.sqrt(aEnergy)
    free=np.sum(np.abs(c)**2/aEnergy)
    coherent=abs(np.sum(c))**2/energySum
    amplitude=0.5*(np.sum(np.abs(normalized)**2)+abs(np.sum(normalized**2)))
    obj=lambda v: -abs(np.sum(np.exp(-1j*(DISP@np.asarray(v)))*c))**2/energySum
    r=minimize(obj,np.zeros(2),method='Nelder-Mead',
               options=dict(maxiter=200,xatol=1e-4,fatol=1e-6))
    dispersion=max(-r.fun,coherent)
    tg=np.linspace(-HALF/C,HALF/C,201)
    ge=np.abs(np.exp(-1j*2*np.pi*np.outer(tg,f))@c)**2/energySum
    i=int(np.argmax(ge)); lo,hi=tg[max(i-1,0)],tg[min(i+1,200)]
    tau=float(ge[i])
    if hi>lo:
        R=minimize_scalar(lambda t:-abs(np.sum(np.exp(-1j*2*np.pi*t*f)*c))**2/energySum,
                          bounds=(lo,hi),method='bounded',options=dict(xatol=1e-18))
        tau=max(tau,float(-R.fun))
    return dict(free=free,coherent=coherent,amplitude=amplitude,
                dispersion=dispersion,tau=tau)

# --- smoke branch_scores formulas (aEnergy == 1) ---
def smoke_gain(c):
    return dict(free=float(np.sum(np.abs(c)**2)),
                coherent=float(abs(np.sum(c))**2/K),
                amplitude=float(0.5*(np.sum(np.abs(c)**2)+abs(np.sum(c**2)))))

th=np.deg2rad(20.); r=25.
k=2*np.pi*f/C
a=mo.a_array(th,r,k)
aEnergy=np.real(np.sum(np.abs(a)**2,axis=0))
print(f"aEnergy: min={aEnergy.min():.15f} max={aEnergy.max():.15f} (must be 1)")
Y=np.sqrt(N)*a+(rng.standard_normal((N,K))+1j*rng.standard_normal((N,K)))/np.sqrt(2)
c=np.sum(np.conj(a)*Y,axis=0)
m=matlab_gain(c,aEnergy); s=smoke_gain(c)
for key in s:
    rel=abs(m[key]-s[key])/abs(s[key])
    print(f"  {key:11s} matlab={m[key]:.10e}  smoke={s[key]:.10e}  rel diff={rel:.2e}")
print(f"  dispersion  ={m['dispersion']:.10e}  (>= coherent: {m['dispersion']>=m['coherent']})")
print(f"  tau         ={m['tau']:.10e}")
print(f"  tau/free    ={m['tau']/m['free']:.6f}  (Theorem 1: tau branch must sit near free)")
print(f"  coherent/free={m['coherent']/m['free']:.6f}")
