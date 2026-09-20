import numpy as np

C = 299792458.0
FC = 60e9
B  = 3e9
M  = 2048
N  = 256
D  = C/FC/2
ELEM = np.arange(N) - (N-1)/2.0
X = ELEM*D
THETA_LIM = (-60.0, 60.0)
RANGE_LIM = (15.0, 50.0)

def freqs(idx=None):
    if idx is None: idx = np.arange(M)
    idx = np.asarray(idx, dtype=float)
    return (FC - B/2) + idx*B/M

def trajectory(idx=None):
    """jad.trajectory: controllable beam-squint focus path."""
    if idx is None: idx = np.arange(M)
    idx = np.asarray(idx, dtype=float)
    fLow = FC - B/2
    off  = idx*B/M
    f    = fLow + off
    sw = (B - off)*fLow/(B*f)
    ew = (B + fLow)*off/(B*f)
    t0 = np.deg2rad(THETA_LIM[0]); t1 = np.deg2rad(THETA_LIM[1])
    st = np.clip(sw*np.sin(t0) + ew*np.sin(t1), -1, 1)
    th = np.arcsin(st)
    inv = sw/RANGE_LIM[0]*np.cos(t0)**2/np.cos(th)**2 + \
          ew/RANGE_LIM[1]*np.cos(t1)**2/np.cos(th)**2
    return np.rad2deg(th), 1.0/inv, f

def prepare_scan():
    thF, rF, f = trajectory()
    k = 2*np.pi*f/C
    # focusDistance[n,m]
    fd = np.sqrt(rF[None,:]**2 + X[:,None]**2 - 2*X[:,None]*rF[None,:]*np.sin(np.deg2rad(thF))[None,:])
    W  = np.exp(-1j*fd*k[None,:])/np.sqrt(N)
    return dict(x=X, k=k, f=f, W=W, thF=thF, rF=rF)

def exact_dist(theta_rad, r):
    return np.sqrt(r**2 + X**2 - 2*r*X*np.sin(theta_rad))

def q_response(scan, theta_rad, r, deriv=False):
    """fsjad.exactSpectralResponse: q_m and d q/d(theta,r)."""
    dist = exact_dist(theta_rad, r)
    A = np.exp(-1j*np.outer(dist, scan['k']))/np.sqrt(N)
    q = np.sum(np.conj(scan['W'])*A, axis=0)
    if not deriv: return q
    dth = -r*X*np.cos(theta_rad)/dist
    dr  = (r - X*np.sin(theta_rad))/dist
    dA_th = -1j*dth[:,None]*scan['k'][None,:]*A
    dA_r  = -1j*dr[:,None]*scan['k'][None,:]*A
    qth = np.sum(np.conj(scan['W'])*dA_th, axis=0)
    qr  = np.sum(np.conj(scan['W'])*dA_r,  axis=0)
    return q, qth, qr

def fresnel_u(theta_rad, r):
    """per-element effective distance used by the array (Y) model."""
    return r - X*np.sin(theta_rad) + X**2*np.cos(theta_rad)**2/(2*r)

def a_array(theta_rad, r, k):
    """N x K unit-norm-per-carrier Fresnel steering (matches jad.steeringVector)."""
    u = fresnel_u(theta_rad, r)
    return np.exp(-1j*np.outer(u, k))/np.sqrt(N)

def du_dr(theta_rad, r):
    return 1.0 - X**2*np.cos(theta_rad)**2/(2*r**2)

def du_dth(theta_rad, r):
    return -X*np.cos(theta_rad) - X**2*np.cos(theta_rad)*np.sin(theta_rad)/r
