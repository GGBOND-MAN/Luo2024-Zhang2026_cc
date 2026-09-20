import json,sys,numpy as np
rows=[json.loads(l) for l in open('mc.log') if l.startswith('{')]
print("rows:",len(rows))
keys=['z','falf','Yf','coh','Yc']
lab={'z':'z-only (frozen P_A/P_FA backend)','falf':'z+Y free-alpha (P_FALF)',
     'Yf':'Y free-alpha only','coh':'z+Y coherent-beta (R57)','Yc':'Y coherent-beta only'}
for snr in sorted(set(r['snr'] for r in rows)):
    S=[r for r in rows if r['snr']==snr]
    print(f"\n--- SNR {snr:+.0f} dB, n={len(S)} ---")
    base=np.mean([(r['z']-r['r'])**2 for r in S])
    for k in keys:
        e=np.array([r[k]-r['r'] for r in S])
        print(f"  {lab[k]:34s} RMSE={np.sqrt(np.mean(e**2)):.6e} m  "
              f"MSE/z={np.mean(e**2)/base:.4e}  P95|e|={np.percentile(abs(e),95):.4e}  "
              f"max|e|={abs(e).max():.4e}")
print("\n--- all SNR pooled ---")
base=np.mean([(r['z']-r['r'])**2 for r in rows])
for k in keys:
    e=np.array([r[k]-r['r'] for r in rows])
    print(f"  {lab[k]:34s} RMSE={np.sqrt(np.mean(e**2)):.6e}  MSE/z={np.mean(e**2)/base:.4e}")
ang=np.array([r['that']-r['theta'] for r in rows])
print(f"\n  P_FA-style angle RMSE = {np.sqrt(np.mean(ang**2)):.3e} deg")
