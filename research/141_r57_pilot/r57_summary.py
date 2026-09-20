"""R57 summary + gate path. Mirrors what +r57/summarize.m must do."""
import json,sys,numpy as np
ROWS=[json.loads(l) for l in open(sys.argv[1]) if l.startswith('{')]
METHODS=["P_A_proxy","P_FALF","P_FACR","P_FACR_A","P_FACR_D","P_FACR_T","P_FACR_Yonly"]
SNRS=sorted({r['snrDb'] for r in ROWS}); POS=sorted({r['positionId'] for r in ROWS})
print(f"rows={len(ROWS)}  positions={len(POS)}  snr={SNRS}")
err={m:np.array([r[m]-r['truthRangeM'] for r in ROWS]) for m in METHODS}
snr=np.array([r['snrDb'] for r in ROWS]); pid=np.array([r['positionId'] for r in ROWS])

def mse(e,mask=None): return float(np.mean(e[mask]**2)) if mask is not None else float(np.mean(e**2))

print("\n=== per-SNR range MSE ratio ===")
hdr=f"{'method':>14}"+"".join(f"{s:>11.0f}" for s in SNRS)+f"{'aggregate':>12}"
print(hdr)
ratios={}
for m in METHODS:
    row=[]
    for s in SNRS:
        k=snr==s; row.append(mse(err[m],k)/mse(err['P_A_proxy'],k))
    agg=mse(err[m])/mse(err['P_A_proxy']); ratios[m]=(row,agg)
    print(f"{m:>14}"+"".join(f"{v:11.3e}" for v in row)+f"{agg:12.3e}")

print("\n=== per-SNR range RMSE [m] ===")
print(hdr)
for m in METHODS:
    row=[np.sqrt(mse(err[m],snr==s)) for s in SNRS]
    print(f"{m:>14}"+"".join(f"{v:11.3e}" for v in row)
          +f"{np.sqrt(mse(err[m])):12.3e}")

# ---- position-cluster bootstrap, shared indices across SNR (R55/R56 convention) ----
rng=np.random.default_rng(72200000); Bn=10000
def boot(num,den):
    out=np.empty(Bn)
    for b in range(Bn):
        pick=rng.choice(POS,size=len(POS),replace=True)
        sel=np.concatenate([np.where(pid==p)[0] for p in pick])
        out[b]=np.mean(num[sel]**2)/np.mean(den[sel]**2)
    return out
print("\n=== cluster bootstrap (10000 draws, shared across SNR) ===")
for m in ["P_FALF","P_FACR","P_FACR_A","P_FACR_D","P_FACR_T","P_FACR_Yonly"]:
    for base in ["P_A_proxy","P_FALF"]:
        if m==base: continue
        d=boot(err[m],err[base])
        print(f"  {m:>14} / {base:<12} ratio={ratios[m][1] if base=='P_A_proxy' else mse(err[m])/mse(err[base]):.4e}"
              f"  U95={np.quantile(d,0.95):.4e}")

# ---- simultaneous family across the 7 SNR points (max-log-ratio) ----
print("\n=== seven-SNR simultaneous family (max-log-ratio critical factor) ===")
for m in ["P_FALF","P_FACR"]:
    per=np.empty((Bn,len(SNRS)))
    rng2=np.random.default_rng(72200001)
    for b in range(Bn):
        pick=rng2.choice(POS,size=len(POS),replace=True)
        sel=np.concatenate([np.where(pid==p)[0] for p in pick])
        ss=snr[sel]
        for j,s in enumerate(SNRS):
            k=ss==s
            per[b,j]=np.mean(err[m][sel][k]**2)/np.mean(err['P_A_proxy'][sel][k]**2)
    pt=np.array(ratios[m][0])
    q=np.quantile(np.max(np.log(per)-np.log(pt),axis=1),0.975)
    print(f"  {m:>10} common critical factor exp(q)={np.exp(q):.4f}"
          f"   worst simultaneous U97.5={np.max(pt*np.exp(q)):.4e}")

# ---- gates ----
print("\n=== pre-declared gates ===")
agg=lambda m: mse(err[m])/mse(err['P_A_proxy'])
p95=lambda m: float(np.percentile(np.abs(err[m]),95))
miss=lambda m: float(np.mean(np.abs(err[m])>1.0))
d=boot(err['P_FACR'],err['P_A_proxy']); u95_pa=float(np.quantile(d,0.95))
d2=boot(err['P_FACR'],err['P_FALF']);   u95_pf=float(np.quantile(d2,0.95))
per=np.array(ratios['P_FACR'][0])
G=[("G1 angle identity", max(abs(r['angleDiff']) for r in ROWS), "==0", max(abs(r['angleDiff']) for r in ROWS)==0),
   ("G2 agg MSE/P_A", agg('P_FACR'), "<0.01", agg('P_FACR')<0.01),
   ("G3 agg MSE/P_A U95", u95_pa, "<0.02", u95_pa<0.02),
   ("G5 agg MSE/P_FALF U95", u95_pf, "<0.05", u95_pf<0.05),
   ("G6 P95 / P_FALF", p95('P_FACR')/p95('P_FALF'), "<0.10", p95('P_FACR')/p95('P_FALF')<0.10),
   ("G7 miss-rate delta", miss('P_FACR')-miss('P_FALF'), "<=0", miss('P_FACR')-miss('P_FALF')<=0),
   ("G8/P1 P_FACR_T / P_FALF", mse(err['P_FACR_T'])/mse(err['P_FALF']), "in[0.85,1.15]",
        0.85<=mse(err['P_FACR_T'])/mse(err['P_FALF'])<=1.15),
   ("G9/P3 per-SNR ratio spread", per.max()/per.min(), "<10", per.max()/per.min()<10),
   ("P2 P_FACR_A / P_FACR", mse(err['P_FACR_A'])/mse(err['P_FACR']), "in[0.9,1.3]",
        0.9<=mse(err['P_FACR_A'])/mse(err['P_FACR'])<=1.3),
   ("P2 P_FACR_D / P_FACR", mse(err['P_FACR_D'])/mse(err['P_FACR']), "in[0.9,1.3]",
        0.9<=mse(err['P_FACR_D'])/mse(err['P_FACR'])<=1.3)]
for name,val,thr,ok in G:
    print(f"  {'PASS' if ok else 'FAIL'}  {name:<28} = {val:12.5e}   need {thr}")
print(f"\n  mean seconds/row = {np.mean([r['sec'] for r in ROWS]):.2f}")
