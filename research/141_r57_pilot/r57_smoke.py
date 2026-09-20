"""R57 21-row smoke in the Python replica: exercises every ablation branch and
the whole summary/gate path before the MATLAB +r57/ is written."""
import numpy as np, time, json, sys, model as mo
from scipy.optimize import minimize_scalar, minimize
C=mo.C; N=mo.N; M=mo.M
scan=mo.prepare_scan()
CAR=np.arange(2047); K=len(CAR); FK=mo.freqs(CAR); KK=2*np.pi*FK/C; NY=N*K

# ---- frozen R57 constants (protocol section 7.3) ----
HALF_W   = 2.0
COARSE   = C/(4*mo.B)          # 0.0249827 m, sampling-theorem derived
PEAKS    = 8
TOLX     = 1e-7
SNRS     = [-10.,-5.,0.,5.,10.,15.,20.]
EPS      = 100*np.finfo(float).eps

def legendre(f,deg):
    t=(f-f.mean())/((f.max()-f.min())/2); Bs=[]
    for k in range(deg+1):
        v=t**k
        for u in Bs: v=v-np.dot(v,u)*u
        Bs.append(v/np.linalg.norm(v))
    return Bs
PSI=legendre(FK,3)             # PSI[1] is the forbidden delay direction

def gen(theta,r,snr,rng):
    q=mo.q_response(scan,np.deg2rad(theta),r)
    var=np.mean(np.abs(q)**2)/10**(snr/10)
    beta=np.exp(1j*2*np.pi*rng.random())
    z=beta*q+np.sqrt(var/2)*(rng.standard_normal(M)+1j*rng.standard_normal(M))
    a=mo.a_array(np.deg2rad(theta),r,KK)
    Y=np.sqrt(N)*a+10**(-snr/20)/np.sqrt(2)*(
        rng.standard_normal((N,K))+1j*rng.standard_normal((N,K)))
    return z,Y

def logdet(E,p,n):
    return -n*np.log(max(E-p,EPS*max(E,1))/n)

def branch_scores(z,Y,Ez,EY,theta_deg,r):
    th=np.deg2rad(theta_deg)
    q=mo.q_response(scan,th,r)
    pz=abs(np.vdot(q,z))**2/np.real(np.vdot(q,q))
    sz=logdet(Ez,pz,M)
    a=mo.a_array(th,r,KK)
    c=np.sum(np.conj(a)*Y,axis=0)                       # per-carrier matched filter
    p_free=float(np.sum(np.abs(c)**2))                  # free complex alpha_m
    p_coh =float(abs(np.sum(c))**2/K)                   # common complex beta
    p_amp =float(0.5*(np.sum(np.abs(c)**2)+abs(np.sum(c**2))))   # rho_m free + common phase
    # common beta + orthogonalised dispersion phase, degrees {0,2,3} (degree 1 excluded)
    def negD(v):
        return -abs(np.sum(np.exp(-1j*(v[0]*PSI[2]+v[1]*PSI[3]))*c))**2/K
    p_disp=float(-minimize(negD,np.zeros(2),method='Nelder-Mead',
                           options=dict(xatol=1e-4,fatol=1e-6,maxiter=200)).fun)
    # common beta + FREE delay tau  (Theorem 1 falsification branch)
    tg=np.linspace(-HALF_W/C,HALF_W/C,201)
    v=np.abs(np.exp(-1j*2*np.pi*np.outer(tg,FK))@c)**2/K
    i=int(np.argmax(v))
    lo,hi=tg[max(i-1,0)],tg[min(i+1,len(tg)-1)]
    if hi>lo:
        R=minimize_scalar(lambda t:-abs(np.sum(np.exp(-1j*2*np.pi*t*FK)*c))**2/K,
                          bounds=(lo,hi),method='bounded',options=dict(xatol=1e-18))
        p_tau=max(float(v[i]),float(-R.fun))
    else: p_tau=float(v[i])
    return dict(P_A_proxy=sz,
                P_FALF  =sz+logdet(EY,p_free,NY),
                P_FACR  =sz+logdet(EY,p_coh ,NY),
                P_FACR_A=sz+logdet(EY,p_amp ,NY),
                P_FACR_D=sz+logdet(EY,p_disp,NY),
                P_FACR_T=sz+logdet(EY,p_tau ,NY),
                P_FACR_Yonly=logdet(EY,p_coh,NY))

METHODS=["P_A_proxy","P_FALF","P_FACR","P_FACR_A","P_FACR_D","P_FACR_T","P_FACR_Yonly"]

def maximize(fun,lo,hi,step,npk,tol):
    g=np.arange(lo,hi+step/2,step); v=np.array([fun(x) for x in g])
    order=np.argsort(v)[::-1]; peaks=[]
    for i in order:
        if len(peaks)>=npk: break
        if all(abs(g[i]-g[j])>1.5*step for j in peaks): peaks.append(i)
    best=(float(g[order[0]]),float(v[order[0]]))
    for i in peaks:
        lo2,hi2=g[max(i-1,0)],g[min(i+1,len(g)-1)]
        if hi2<=lo2: continue
        R=minimize_scalar(lambda x:-fun(x),bounds=(lo2,hi2),method='bounded',
                          options=dict(xatol=tol))
        if -R.fun>best[1]: best=(float(R.x),float(-R.fun))
    return best[0]

def pfa_angle(Y,theta0,r0):
    def sc(t):
        a=mo.a_array(np.deg2rad(t),r0,KK)
        return float(np.sum(np.abs(np.sum(np.conj(a)*Y,axis=0))**2))
    return maximize(sc,theta0-0.2,theta0+0.2,0.4/40,1,1e-7)

def run(npos,seed,out):
    rng=np.random.default_rng(seed)
    pos=[(rng.uniform(-60,60),rng.uniform(15,50)) for _ in range(npos)]
    rows=[]
    for pi,(th,r) in enumerate(pos):
        for snr in SNRS:
            t0=time.time()
            rg=np.random.default_rng(seed+1000*pi+int(snr)+97)
            z,Y=gen(th,r,snr,rg)
            Ez=float(np.real(np.vdot(z,z))); EY=float(np.sum(np.abs(Y)**2))
            rF=float(np.clip(r+rg.normal(0,0.3),15,50))
            that=pfa_angle(Y,th,rF)
            cache={}
            def S(x):
                kx=round(x,10)
                if kx not in cache: cache[kx]=branch_scores(z,Y,Ez,EY,that,x)
                return cache[kx]
            lo=max(15.,rF-HALF_W); hi=min(50.,rF+HALF_W)
            est={m:maximize(lambda x,k=m:S(x)[k],lo,hi,COARSE,PEAKS,TOLX)
                 for m in METHODS}
            rows.append(dict(positionId=pi,snrDb=snr,truthThetaDeg=th,truthRangeM=r,
                             frontRangeM=rF,thetaFA=that,angleDiff=0.0,
                             sec=time.time()-t0,**est))
            print(json.dumps(rows[-1]),flush=True)
    json.dump(rows,open(out,'w'))

if __name__=="__main__":
    run(int(sys.argv[1]),int(sys.argv[2]),sys.argv[3])
