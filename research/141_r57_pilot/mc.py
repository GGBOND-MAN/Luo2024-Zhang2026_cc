import numpy as np, time, sys, json, model as mo
from scipy.optimize import minimize_scalar
C=mo.C; N=mo.N; M=mo.M
scan=mo.prepare_scan()
CAR=np.arange(2047); K=len(CAR); KF=mo.freqs(CAR); KK=2*np.pi*KF/C
NY=N*K

def gen(theta,r,snr,rng):
    q=mo.q_response(scan,np.deg2rad(theta),r)
    var=np.mean(np.abs(q)**2)/10**(snr/10)
    beta=np.exp(1j*2*np.pi*rng.random())
    z=beta*q+np.sqrt(var/2)*(rng.standard_normal(M)+1j*rng.standard_normal(M))
    a=mo.a_array(np.deg2rad(theta),r,KK)          # unit-norm cols
    s=np.sqrt(N)*a                                 # |signal|=1 per element
    ns=10**(-snr/20)
    Y=s+ns/np.sqrt(2)*(rng.standard_normal((N,K))+1j*rng.standard_normal((N,K)))
    return z,Y

def scores(z,Y,Ez,EY,theta_deg,r):
    th=np.deg2rad(theta_deg)
    q=mo.q_response(scan,th,r)
    pz=abs(np.vdot(q,z))**2/np.real(np.vdot(q,q))
    a=mo.a_array(th,r,KK)
    ah=np.sum(np.conj(a)*Y,axis=0)                 # alpha-hat per carrier
    pf=np.sum(np.abs(ah)**2)                       # free-alpha explained
    pc=abs(np.sum(ah))**2/K                        # common-beta explained
    f=lambda E,p,n: -n*np.log(max(E-p,100*np.finfo(float).eps*max(E,1))/n)
    sz=f(Ez,pz,M); syf=f(EY,pf,NY); syc=f(EY,pc,NY)
    return dict(z=sz, Yf=syf, Yc=syc, falf=sz+syf, coh=sz+syc)

def maximize(fun,lo,hi,step,npk=3,tol=1e-5):
    g=np.arange(lo,hi+step/2,step); v=np.array([fun(x) for x in g])
    order=np.argsort(v)[::-1]; peaks=[]
    for i in order:
        if len(peaks)>=npk: break
        if all(abs(g[i]-g[j])>1.5*step for j in peaks): peaks.append(i)
    best=(g[order[0]],v[order[0]])
    for i in peaks:
        l=g[max(i-1,0)]; h=g[min(i+1,len(g)-1)]
        if h<=l: continue
        R=minimize_scalar(lambda x:-fun(x),bounds=(l,h),method='bounded',
                          options=dict(xatol=tol))
        if -R.fun>best[1]: best=(R.x,-R.fun)
    return best[0]

def pfa_angle(Y,EY,theta0,r0):
    def sc(t):
        a=mo.a_array(np.deg2rad(t),r0,KK)
        return np.sum(np.abs(np.sum(np.conj(a)*Y,axis=0))**2)
    return maximize(sc,theta0-0.2,theta0+0.2,0.4/40,npk=1,tol=1e-7)

def run(npos,snrs,seed,out):
    rng=np.random.default_rng(seed)
    pos=[(rng.uniform(-60,60),rng.uniform(15,50)) for _ in range(npos)]
    rows=[]
    for pi,(th,r) in enumerate(pos):
        for snr in snrs:
            t0=time.time()
            rg=np.random.default_rng(seed+1000*pi+int(snr)+50)
            z,Y=gen(th,r,snr,rg)
            Ez=float(np.real(np.vdot(z,z))); EY=float(np.sum(np.abs(Y)**2))
            # front-end range window: emulate a correct L06 window centred with 0.3 m error
            rF=r+rg.normal(0,0.3)
            that=pfa_angle(Y,EY,th,rF)
            cache={}
            def S(x):
                kx=round(x,9)
                if kx not in cache: cache[kx]=scores(z,Y,Ez,EY,that,x)
                return cache[kx]
            lo=max(15.0,rF-2); hi=min(50.0,rF+2)
            est={}
            for key,step in [('z',0.05),('falf',0.05),('Yf',0.05),
                             ('coh',0.025),('Yc',0.025)]:
                est[key]=maximize(lambda x,k=key:S(x)[k],lo,hi,step)
            rows.append(dict(pos=pi,snr=snr,theta=th,r=r,rF=rF,that=that,
                             **{k:float(v) for k,v in est.items()},
                             sec=time.time()-t0))
            print(json.dumps(rows[-1]),flush=True)
    with open(out,'w') as fh: json.dump(rows,fh)

if __name__=='__main__':
    run(int(sys.argv[1]),[float(x) for x in sys.argv[2].split(',')],
        int(sys.argv[3]),sys.argv[4])
