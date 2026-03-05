#!/usr/bin/env python3
"""
Fast Espresso Puck CFD Simulation — Vectorized NumPy Implementation
===================================================================
Implements all equations from the paper with optimized NumPy solver.
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.interpolate import interp1d
import json, os, warnings, time
warnings.filterwarnings('ignore')

# ============================================================================
# PHYSICAL CONSTANTS
# ============================================================================
VISCOSITY_T = np.array([20,25,30,40,50,60,70,80,90,95,100], dtype=float)
VISCOSITY_MU = np.array([1.002,0.890,0.798,0.653,0.547,0.467,0.404,0.354,0.315,0.298,0.282]) * 1e-3
_visc_interp = interp1d(VISCOSITY_T, VISCOSITY_MU, kind='linear', fill_value='extrapolate')

RHO_WATER = 1000.0
C_PACK = 2.5e-5
BLAKE_KOZENY = 180.0

DEFAULT_PARAMS = dict(
    basket_diameter_mm=58.0, grind_size_um=400.0, dose_g=18.0,
    brew_pressure_bar=9.0, temperature_C=93.0, tamp_force_kg=15.0,
    moisture_fraction=0.10, distribution_quality=0.85,
    exit_pressure_bar=0.0, n_basket_holes=350,
)

# Use smaller grid for sweeps, full grid for reference
NZ_FULL, NR_FULL = 96, 50
NZ_FAST, NR_FAST = 48, 30

def water_viscosity(T):
    return float(_visc_interp(np.clip(T, 20, 100)))

def effective_porosity(tamp=15.0, moisture=0.10):
    return np.clip(0.42 - 0.004*tamp - 0.15*moisture, 0.20, 0.50)

def kozeny_carman(eps, d):
    return (eps**3 * d**2) / (BLAKE_KOZENY * (1-eps)**2)

def puck_height_m(dose_g, eps, R_m):
    vol = dose_g / (1.15 * (1-eps))  # cm³
    area = np.pi * (R_m*100)**2      # cm²
    return vol / area / 100           # m

def ergun_dp(v, eps, d, mu, L):
    viscous = 150*mu*(1-eps)**2*v/(d**2*eps**3)
    inertial = 1.75*RHO_WATER*(1-eps)*v**2/(d*eps**3)
    return (viscous+inertial)*L

# ============================================================================
# PERMEABILITY FIELD (vectorized)
# ============================================================================
def build_permeability(params, NZ, NR, seed=42):
    rng = np.random.RandomState(seed)
    R = params['basket_diameter_mm']/2000.0
    d = params['grind_size_um']*1e-6
    eps = effective_porosity(params['tamp_force_kg'], params['moisture_fraction'])
    H = puck_height_m(params['dose_g'], eps, R)
    Q = params['distribution_quality']

    dr, dz = R/NR, H/NZ
    r = (np.arange(NR)+0.5)*dr
    z = (np.arange(NZ)+0.5)*dz

    k_base = kozeny_carman(eps, d) * C_PACK
    k = np.full((NZ, NR), k_base)

    # Vectorized corrections
    r_ratio = r/R
    z_ratio = z/H
    RR, ZZ = np.meshgrid(r_ratio, z_ratio)

    # f_wall
    wall_mask = RR > 0.78
    k[wall_mask] *= 1.0 + 0.55*((RR[wall_mask]-0.78)/0.22)**0.7

    # f_center
    center_mask = RR < 0.08
    k[center_mask] *= 1.0 + 0.12*(1.0 - RR[center_mask]/0.08)

    # f_fines
    fines_mask = ZZ > 0.65
    k[fines_mask] *= 1.0 - 0.30*((ZZ[fines_mask]-0.65)/0.35)**1.3

    # f_surface
    surf_mask = ZZ < 0.06
    k[surf_mask] *= 1.0 + 0.18*(1.0 - ZZ[surf_mask]/0.06)

    # f_screen
    lam = R/(np.sqrt(params['n_basket_holes'])/(2*np.pi))
    RR_m = np.meshgrid(r, z_ratio)[0]  # r in meters
    screen_mask = ZZ > 0.88
    s = (ZZ[screen_mask]-0.88)/0.12
    f_scr = np.maximum(0.55, 1.0 + s*0.45*np.sin(RR_m[screen_mask]/lam*6*np.pi))
    k[screen_mask] *= f_scr

    # f_noise
    sigma = 1.0 - Q
    k *= np.exp(0.8*sigma*rng.uniform(-1,1,(NZ,NR)))

    # f_moisture
    k *= 1.0 - 0.3*params['moisture_fraction']*rng.uniform(0,1,(NZ,NR))

    # Channels
    N_ch = int(np.floor((1-Q)*10))
    for _ in range(N_ch):
        r_idx = rng.randint(int(0.1*NR), int(0.9*NR))
        w = rng.randint(2, 5)
        A = 2 + (1-Q)*6*rng.uniform()
        cur = r_idx
        for i in range(NZ):
            j_arr = np.arange(NR)
            dist = np.abs(j_arr - cur)
            mask = dist < w*3
            k[i, mask] *= 1 + (A-1)*np.exp(-dist[mask]**2/max(1, w/2))
            if rng.random() < 0.15:
                cur = int(np.clip(cur + rng.choice([-1,1]), 2, NR-3))

    return k, r, z, dr, dz, R, H, eps, k_base


# ============================================================================
# PRESSURE SOLVER (Jacobi with NumPy — fully vectorized)
# ============================================================================
def solve_pressure_fast(k, dr, dz, R, H, P_top, P_bot, NZ, NR, max_iter=400, tol=1.0):
    r = (np.arange(NR)+0.5)*dr
    P = np.linspace(P_top, P_bot, NZ)[:,None] * np.ones((1,NR))
    P[0,:] = P_top
    P[-1,:] = P_bot

    r_half_plus = r + dr/2
    r_half_minus = np.maximum(r - dr/2, 0.01*dr)

    for it in range(max_iter):
        P_old = P.copy()

        # Harmonic means for z-direction (interior rows 1..NZ-2)
        k_zp = 2*k[1:-1]*k[2:]/(k[1:-1]+k[2:]+1e-30)
        k_zm = 2*k[1:-1]*k[:-2]/(k[1:-1]+k[:-2]+1e-30)
        a_z = (k_zp+k_zm)/dz**2
        num = k_zp/dz**2*P[2:] + k_zm/dz**2*P[:-2]

        # Radial direction
        # j > 0 (not leftmost)
        k_rp = np.zeros_like(k[1:-1])
        k_rm = np.zeros_like(k[1:-1])
        a_rp = np.zeros_like(k[1:-1])
        a_rm = np.zeros_like(k[1:-1])

        # right neighbor (j < NR-1)
        k_rp[:,:-1] = 2*k[1:-1,:-1]*k[1:-1,1:]/(k[1:-1,:-1]+k[1:-1,1:]+1e-30)
        a_rp[:,:-1] = k_rp[:,:-1]*r_half_plus[:-1]/(r[:-1]*dr**2)
        num[:,:-1] += a_rp[:,:-1]*P[1:-1,1:]

        # left neighbor (j > 0)
        k_rm[:,1:] = 2*k[1:-1,1:]*k[1:-1,:-1]/(k[1:-1,1:]+k[1:-1,:-1]+1e-30)
        a_rm[:,1:] = k_rm[:,1:]*r_half_minus[1:]/(r[1:]*dr**2)
        num[:,1:] += a_rm[:,1:]*P[1:-1,:-1]

        # j=0 symmetry: ghost cell P[-1]=P[0]
        a_rm_0 = k[1:-1,0]*r_half_minus[0]/(r[0]*dr**2)
        a_rm[:,0] = a_rm_0
        num[:,0] += a_rm_0*P[1:-1,0]

        denom = a_z + a_rp + a_rm
        P[1:-1] = num / (denom + 1e-30)
        P[0,:] = P_top
        P[-1,:] = P_bot

        change = np.max(np.abs(P - P_old))
        if change < tol:
            break

    return P, it+1


def compute_velocity_fast(P, k, mu, dr, dz, NZ, NR):
    vz = np.zeros((NZ, NR))
    vr = np.zeros((NZ, NR))

    vz[1:-1] = -(k[1:-1]/mu)*(P[2:]-P[:-2])/(2*dz)
    vz[0] = -(k[0]/mu)*(P[1]-P[0])/dz
    vz[-1] = -(k[-1]/mu)*(P[-1]-P[-2])/dz

    vr[:,1:-1] = -(k[:,1:-1]/mu)*(P[:,2:]-P[:,:-2])/(2*dr)
    vr[:,0] = 0
    vr[:,-1] = 0

    return vz, vr, np.sqrt(vz**2+vr**2)


def compute_extraction_fast(vz, k, k_base, R, H, dr, dz, NZ, NR):
    r = (np.arange(NR)+0.5)*dr
    v_mean = np.mean(np.abs(vz))+1e-15
    E = np.zeros((NZ, NR))

    for j in range(NR):
        cum = 0.0
        r_ratio = r[j]/R
        if r_ratio > 0.82:
            fw = 1-2.8*(r_ratio-0.82)
        elif r_ratio < 0.06:
            fw = 0.92+(r_ratio/0.06)*0.08
        else:
            fw = 1.0

        for i in range(NZ):
            vl = max(abs(vz[i,j]), 1e-15)
            kr = max(k[i,j]/k_base, 0.01)
            dE = min(0.08, (v_mean/vl)*0.03/kr)
            cum += dE

            z_ratio = (i+0.5)*dz/H
            if z_ratio > 0.90:
                s = (z_ratio-0.90)/0.10
                vr_local = vl/v_mean
                fb = (1-s*0.3*min(2, vr_local-1)) if vr_local > 1.3 else (1+s*0.15)
            else:
                fb = 1.0
            E[i,j] = min(1.0, cum*max(0.1, fw)*fb)
    return E


def compute_stats(vz, r, dr, H, dose_g, eps, NR):
    exit_vz = np.abs(vz[-1])
    Q_m3s = np.sum(exit_vz * 2*np.pi*r*dr)
    Q_mLs = Q_m3s*1e6
    shot_time = (dose_g*2)/Q_mLs if Q_mLs > 0 else 999
    CV = np.std(exit_vz)/np.mean(exit_vz) if np.mean(exit_vz) > 0 else 0
    risk = min(1.0, CV/0.5)
    return dict(flow_rate_mLs=Q_mLs, shot_time_s=shot_time, CV=CV,
                channeling_risk=risk, uniformity=1-risk)


# ============================================================================
# FULL SIMULATION
# ============================================================================
def run_sim(params=None, fast=True, verbose=False):
    if params is None:
        params = DEFAULT_PARAMS.copy()

    NZ = NZ_FAST if fast else NZ_FULL
    NR = NR_FAST if fast else NR_FULL
    mu = water_viscosity(params['temperature_C'])
    P_top = (params['brew_pressure_bar'] - params['exit_pressure_bar'])*1e5

    k, r, z, dr, dz, R, H, eps, k_base = build_permeability(params, NZ, NR)
    P, n_iter = solve_pressure_fast(k, dr, dz, R, H, P_top, 0.0, NZ, NR)
    vz, vr, v_mag = compute_velocity_fast(P, k, mu, dr, dz, NZ, NR)
    E = compute_extraction_fast(vz, k, k_base, R, H, dr, dz, NZ, NR)
    stats = compute_stats(vz, r, dr, H, params['dose_g'], eps, NR)

    # Ergun validation
    v_mean = stats['flow_rate_mLs']*1e-6/(np.pi*R**2)
    d = params['grind_size_um']*1e-6
    stats['ergun_dp_bar'] = ergun_dp(v_mean, eps, d, mu, H)/1e5
    stats['porosity'] = eps
    stats['puck_height_mm'] = H*1000
    stats['viscosity_mPas'] = mu*1e3

    if verbose:
        print(f"  eps={eps:.3f}, H={H*1000:.1f}mm, Q={stats['flow_rate_mLs']:.2f}mL/s, "
              f"t={stats['shot_time_s']:.1f}s, CV={stats['CV']:.3f}, iter={n_iter}")

    return dict(params=params.copy(), P=P, k=k, vz=vz, vr=vr, v_mag=v_mag, E=E,
                r=r, z=z, dr=dr, dz=dz, R=R, H=H, eps=eps, k_base=k_base, stats=stats)


# ============================================================================
# PARAMETRIC SWEEPS
# ============================================================================
def sweep(param, values, base=None):
    if base is None: base = DEFAULT_PARAMS.copy()
    results = []
    for v in values:
        p = base.copy()
        p[param] = v
        res = run_sim(p, fast=True, verbose=True)
        res['sweep_value'] = v
        results.append(res)
    return results

def run_all_sweeps():
    sw = {}
    for name, param, vals in [
        ('grind_size', 'grind_size_um', np.arange(200, 850, 50)),
        ('pressure', 'brew_pressure_bar', np.arange(1, 13, 1)),
        ('temperature', 'temperature_C', np.arange(70, 101, 3)),
        ('dose', 'dose_g', np.arange(12, 24, 1)),
        ('quality', 'distribution_quality', np.arange(0.30, 1.01, 0.05)),
        ('tamp', 'tamp_force_kg', np.arange(5, 31, 2)),
    ]:
        print(f"\n=== Sweep: {name} ===")
        sw[name] = sweep(param, vals)
    return sw


# ============================================================================
# LITERATURE DATA
# ============================================================================
LITERATURE = {
    'Corrochano_2015': dict(desc='Steady-state permeability', flow=(1.0,3.0), grind=(200,600)),
    'Cameron_2020': dict(desc='Mathematical modeling', flow=(1.5,2.5), grind=(350,500), time=(24,32)),
    'Kuhn_2017': dict(desc='Time-resolved extraction', flow=(1.0,3.5), time=(20,40)),
    'Industry': dict(desc='Standard espresso', time=(25,35)),
    'PIV': dict(desc='PIV experiments', CV=(0.1, 0.6)),
}


# ============================================================================
# PLOTTING
# ============================================================================
def setup_style():
    plt.rcParams.update({
        'font.family': 'sans-serif', 'font.size': 10, 'axes.labelsize': 11,
        'axes.titlesize': 12, 'figure.dpi': 200, 'savefig.dpi': 300,
        'savefig.bbox': 'tight', 'axes.grid': True, 'grid.alpha': 0.3,
        'axes.spines.top': False, 'axes.spines.right': False,
    })


def plot_fields(res, out):
    """Fig 1: Field maps"""
    fig, axes = plt.subplots(2, 3, figsize=(14, 8))
    fig.suptitle('Espresso Puck CFD — Spatial Field Maps\n'
                 f'(d={res["params"]["grind_size_um"]:.0f}μm, P={res["params"]["brew_pressure_bar"]:.0f}bar, '
                 f'T={res["params"]["temperature_C"]:.0f}°C, dose={res["params"]["dose_g"]:.0f}g)',
                 fontsize=12, fontweight='bold')
    rm, zm = res['r']*1000, res['z']*1000
    for idx, (key, label, cmap) in enumerate([
        ('P','Pressure [Pa]','viridis'), ('k','Permeability [m²]','magma'),
        ('v_mag','|Velocity| [m/s]','plasma'), ('E','Extraction','RdYlGn_r'),
        ('vz','Axial velocity [m/s]','coolwarm'), ('vr','Radial velocity [m/s]','RdBu_r')]):
        ax = axes[idx//3, idx%3]
        im = ax.pcolormesh(rm, zm, res[key], cmap=cmap, shading='auto')
        ax.set_xlabel('r [mm]'); ax.set_ylabel('z [mm]'); ax.set_title(label)
        ax.invert_yaxis(); plt.colorbar(im, ax=ax, shrink=0.8)
    plt.tight_layout()
    p = os.path.join(out, 'fig01_field_maps.png'); plt.savefig(p); plt.close(); return p


def plot_grind(sw, out):
    """Fig 2: Grind size sweep"""
    d = sw['grind_size']
    gs = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]
    cv = [r['stats']['CV'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Effect of Grind Size on Espresso Extraction', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(gs, fr, 'o-', color='#2196F3', lw=2, ms=5, label='Simulation')
    ax.axhspan(1.0,3.0, alpha=0.15, color='green', label='Corrochano 2015')
    ax.axhspan(1.5,2.5, alpha=0.15, color='orange', label='Cameron 2020')
    mid = len(gs)//2
    theory = [fr[mid]*(g/gs[mid])**2 for g in gs]
    ax.plot(gs, theory, '--', color='red', alpha=0.5, lw=1.5, label='Q ∝ d² (theory)')
    ax.set_xlabel('Grind size [μm]'); ax.set_ylabel('Flow rate [mL/s]')
    ax.set_title('Flow Rate'); ax.legend(fontsize=7)

    ax = axes[1]
    ax.plot(gs, st, 's-', color='#E91E63', lw=2, ms=5)
    ax.axhspan(25,35, alpha=0.15, color='green', label='Industry (25-35s)')
    ax.set_xlabel('Grind size [μm]'); ax.set_ylabel('Shot time [s]')
    ax.set_title('Shot Time'); ax.legend(fontsize=7); ax.set_ylim(0, min(max(st)*1.1, 150))

    ax = axes[2]
    ax.plot(gs, cv, 'd-', color='#FF9800', lw=2, ms=5)
    ax.axhspan(0.1,0.6, alpha=0.15, color='green', label='PIV (0.1-0.6)')
    ax.set_xlabel('Grind size [μm]'); ax.set_ylabel('CV')
    ax.set_title('Channeling CV'); ax.legend(fontsize=7)

    plt.tight_layout()
    p = os.path.join(out, 'fig02_grind_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_pressure(sw, out):
    """Fig 3: Pressure sweep"""
    d = sw['pressure']
    ps = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]
    eg = [r['stats']['ergun_dp_bar'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Effect of Brew Pressure on Extraction', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(ps, fr, 'o-', color='#2196F3', lw=2, ms=5, label='Simulation')
    mid = len(ps)//2
    lin = [fr[mid]*p/ps[mid] for p in ps]
    ax.plot(ps, lin, '--', color='red', alpha=0.5, lw=1.5, label='Q ∝ P (Darcy)')
    ax.set_xlabel('Pressure [bar]'); ax.set_ylabel('Flow rate [mL/s]')
    ax.set_title('Flow Rate'); ax.legend(fontsize=8)

    ax = axes[1]
    ax.plot(ps, st, 's-', color='#E91E63', lw=2, ms=5)
    ax.axhspan(25,35, alpha=0.15, color='green', label='Standard')
    ax.set_xlabel('Pressure [bar]'); ax.set_ylabel('Shot time [s]')
    ax.set_title('Shot Time'); ax.legend(fontsize=7)

    ax = axes[2]
    ax.plot(ps, eg, 'd-', color='#9C27B0', lw=2, ms=5, label='Ergun ΔP')
    ax.plot(ps, ps, '--', color='gray', alpha=0.5, label='ΔP = P_brew')
    ax.set_xlabel('Pressure [bar]'); ax.set_ylabel('ΔP [bar]')
    ax.set_title('Ergun Validation'); ax.legend(fontsize=8)

    plt.tight_layout()
    p = os.path.join(out, 'fig03_pressure_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_temperature(sw, out):
    """Fig 4: Temperature sweep"""
    d = sw['temperature']
    ts = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    mu = [r['stats']['viscosity_mPas'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Effect of Brew Temperature', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(ts, mu, 'o-', color='#009688', lw=2, ms=5)
    ax.axvline(93, color='red', ls='--', alpha=0.5, label='93°C')
    ax.set_xlabel('T [°C]'); ax.set_ylabel('μ [mPa·s]'); ax.set_title('Viscosity'); ax.legend(fontsize=8)

    ax = axes[1]
    ax.plot(ts, fr, 's-', color='#2196F3', lw=2, ms=5, label='Simulation')
    mid = len(ts)//2
    theory = [fr[mid]*mu[mid]/m for m in mu]
    ax.plot(ts, theory, '--', color='red', alpha=0.5, lw=1.5, label='Q ∝ 1/μ')
    ax.set_xlabel('T [°C]'); ax.set_ylabel('Flow [mL/s]'); ax.set_title('Flow Rate'); ax.legend(fontsize=8)

    ax = axes[2]
    ax.plot(ts, st, 'd-', color='#E91E63', lw=2, ms=5)
    ax.axhspan(25,35, alpha=0.15, color='green', label='Standard')
    ax.set_xlabel('T [°C]'); ax.set_ylabel('Shot time [s]'); ax.set_title('Shot Time'); ax.legend(fontsize=7)

    plt.tight_layout()
    p = os.path.join(out, 'fig04_temperature_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_dose(sw, out):
    """Fig 5: Dose sweep"""
    d = sw['dose']
    ds = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]
    ph = [r['stats']['puck_height_mm'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Effect of Dose', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(ds, ph, 'o-', color='#795548', lw=2, ms=5)
    ax.set_xlabel('Dose [g]'); ax.set_ylabel('Puck height [mm]'); ax.set_title('Puck Height')

    ax = axes[1]
    ax.plot(ds, fr, 's-', color='#2196F3', lw=2, ms=5, label='Simulation')
    mid = len(ds)//2
    theory = [fr[mid]*ds[mid]/dd for dd in ds]
    ax.plot(ds, theory, '--', color='red', alpha=0.5, lw=1.5, label='Q ∝ 1/dose')
    ax.set_xlabel('Dose [g]'); ax.set_ylabel('Flow [mL/s]'); ax.set_title('Flow Rate'); ax.legend(fontsize=8)

    ax = axes[2]
    ax.plot(ds, st, 'd-', color='#E91E63', lw=2, ms=5)
    ax.axhspan(25,35, alpha=0.15, color='green', label='Standard')
    ax.set_xlabel('Dose [g]'); ax.set_ylabel('Shot time [s]'); ax.set_title('Shot Time'); ax.legend(fontsize=7)

    plt.tight_layout()
    p = os.path.join(out, 'fig05_dose_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_quality(sw, out):
    """Fig 6: Distribution quality sweep"""
    d = sw['quality']
    qs = [r['sweep_value'] for r in d]
    cv = [r['stats']['CV'] for r in d]
    uni = [r['stats']['uniformity'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Distribution Quality and Channeling', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(qs, cv, 'o-', color='#F44336', lw=2, ms=5)
    ax.axhspan(0.1,0.6, alpha=0.15, color='green', label='PIV (0.1-0.6)')
    ax.set_xlabel('Quality Q'); ax.set_ylabel('CV'); ax.set_title('Channeling CV'); ax.legend(fontsize=8)

    ax = axes[1]
    ax.plot(qs, uni, 's-', color='#4CAF50', lw=2, ms=5)
    ax.set_xlabel('Quality Q'); ax.set_ylabel('Uniformity'); ax.set_title('Flow Uniformity'); ax.set_ylim(0,1.05)

    ax = axes[2]
    ax.plot(qs, fr, 'd-', color='#2196F3', lw=2, ms=5)
    ax.set_xlabel('Quality Q'); ax.set_ylabel('Flow [mL/s]'); ax.set_title('Flow Rate')

    plt.tight_layout()
    p = os.path.join(out, 'fig06_quality_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_tamp(sw, out):
    """Fig 7: Tamp force sweep"""
    d = sw['tamp']
    ts = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    eps = [r['stats']['porosity'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Effect of Tamp Force', fontsize=13, fontweight='bold')

    ax = axes[0]
    ax.plot(ts, eps, 'o-', color='#795548', lw=2, ms=5)
    ax.set_xlabel('Tamp [kg]'); ax.set_ylabel('Porosity'); ax.set_title('Porosity')

    ax = axes[1]
    ax.plot(ts, fr, 's-', color='#2196F3', lw=2, ms=5)
    ax.set_xlabel('Tamp [kg]'); ax.set_ylabel('Flow [mL/s]'); ax.set_title('Flow Rate')

    ax = axes[2]
    ax.plot(ts, st, 'd-', color='#E91E63', lw=2, ms=5)
    ax.axhspan(25,35, alpha=0.15, color='green', label='Standard')
    ax.set_xlabel('Tamp [kg]'); ax.set_ylabel('Shot time [s]'); ax.set_title('Shot Time'); ax.legend(fontsize=7)

    plt.tight_layout()
    p = os.path.join(out, 'fig07_tamp_sweep.png'); plt.savefig(p); plt.close(); return p


def plot_heatmap(out):
    """Fig 8: Grind × Pressure interaction"""
    print("  Generating interaction heatmap...")
    gs = [250,300,350,400,450,500,600]
    ps = [3,5,6,7,8,9,10,12]
    fm = np.zeros((len(gs), len(ps)))
    tm = np.zeros_like(fm)
    for i,g in enumerate(gs):
        for j,p in enumerate(ps):
            par = DEFAULT_PARAMS.copy()
            par['grind_size_um'] = g; par['brew_pressure_bar'] = p
            res = run_sim(par, fast=True)
            fm[i,j] = res['stats']['flow_rate_mLs']
            tm[i,j] = min(res['stats']['shot_time_s'], 120)

    fig, axes = plt.subplots(1, 2, figsize=(13, 5))
    fig.suptitle('Grind Size × Pressure Interaction', fontsize=13, fontweight='bold')

    for idx, (data, title, cmap, vmin, vmax) in enumerate([
        (fm, 'Flow Rate [mL/s]', 'viridis', None, None),
        (tm, 'Shot Time [s]', 'RdYlGn_r', 10, 80)]):
        ax = axes[idx]
        kwargs = dict(aspect='auto', origin='lower', cmap=cmap,
                     extent=[ps[0]-0.5,ps[-1]+0.5, gs[0]-25,gs[-1]+25])
        if vmin is not None: kwargs.update(vmin=vmin, vmax=vmax)
        im = ax.imshow(data, **kwargs)
        ax.set_xlabel('Pressure [bar]'); ax.set_ylabel('Grind [μm]'); ax.set_title(title)
        plt.colorbar(im, ax=ax, shrink=0.8)
        X,Y = np.meshgrid(ps, gs)
        lvls = [1.5,2.0,2.5] if idx==0 else [25,30,35]
        try:
            ax.contour(X, Y, data, levels=lvls, colors='white', linewidths=1.5, linestyles='--')
        except: pass

    plt.tight_layout()
    p = os.path.join(out, 'fig08_interaction_heatmap.png'); plt.savefig(p); plt.close(); return p


def plot_sensitivity(sw, out):
    """Fig 9: Sensitivity analysis"""
    sens = {}
    for name, label in [('grind_size','Grind size'), ('pressure','Pressure'),
                         ('temperature','Temperature'), ('dose','Dose'),
                         ('quality','Distribution Q'), ('tamp','Tamp force')]:
        d = sw[name]
        vals = [r['sweep_value'] for r in d]
        flows = [r['stats']['flow_rate_mLs'] for r in d]
        times = [r['stats']['shot_time_s'] for r in d]
        mid = len(vals)//2
        if mid > 0 and mid < len(vals)-1 and vals[mid] != 0:
            elast = abs((flows[mid+1]-flows[mid-1])/flows[mid] / ((vals[mid+1]-vals[mid-1])/vals[mid]))
        else: elast = 0
        sens[label] = dict(elasticity=elast, flow_range=max(flows)-min(flows),
                          time_range=max(times)-min(times))

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    fig.suptitle('Parameter Sensitivity Analysis', fontsize=13, fontweight='bold')

    labels = list(sens.keys())
    elasts = [sens[l]['elasticity'] for l in labels]
    colors = ['#2196F3','#E91E63','#009688','#FF9800','#9C27B0','#795548']

    ax = axes[0]
    bars = ax.barh(labels, elasts, color=colors, alpha=0.8)
    ax.set_xlabel('|Elasticity|'); ax.set_title('Flow Rate Sensitivity')
    for b,v in zip(bars, elasts):
        ax.text(b.get_width()+0.02, b.get_y()+b.get_height()/2, f'{v:.2f}', va='center', fontsize=9)

    ax = axes[1]
    x = np.arange(len(labels)); w = 0.35
    ax.bar(x-w/2, [sens[l]['flow_range'] for l in labels], w, label='Flow range [mL/s]', color='#2196F3', alpha=0.8)
    ax.bar(x+w/2, [sens[l]['time_range']/10 for l in labels], w, label='Time range [s]/10', color='#E91E63', alpha=0.8)
    ax.set_xticks(x); ax.set_xticklabels(labels, rotation=30, ha='right')
    ax.set_title('Parameter Effect Ranges'); ax.legend(fontsize=8)

    plt.tight_layout()
    p = os.path.join(out, 'fig09_sensitivity.png'); plt.savefig(p); plt.close(); return p, sens


def plot_literature(sw, out):
    """Fig 10: Literature comparison"""
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Simulation vs Published Literature', fontsize=13, fontweight='bold')

    d = sw['grind_size']
    gs = [r['sweep_value'] for r in d]
    fr = [r['stats']['flow_rate_mLs'] for r in d]
    st = [r['stats']['shot_time_s'] for r in d]

    ax = axes[0]
    ax.plot(gs, fr, 'o-', color='#2196F3', lw=2, ms=5, label='This work', zorder=5)
    ax.fill_between([200,600], 1.0, 3.0, alpha=0.2, color='green', label='Corrochano (2015)')
    ax.fill_between([350,500], 1.5, 2.5, alpha=0.2, color='orange', label='Cameron (2020)')
    ax.set_xlabel('Grind [μm]'); ax.set_ylabel('Flow [mL/s]'); ax.set_title('Flow Rate')
    ax.legend(fontsize=7); ax.set_xlim(150,850)

    ax = axes[1]
    ax.plot(gs, st, 's-', color='#E91E63', lw=2, ms=5, label='This work', zorder=5)
    ax.axhspan(25,35, alpha=0.2, color='green', label='Industry (25-35s)')
    ax.axhspan(24,32, alpha=0.2, color='orange', label='Cameron (24-32s)')
    ax.set_xlabel('Grind [μm]'); ax.set_ylabel('Shot time [s]'); ax.set_title('Shot Time')
    ax.legend(fontsize=7); ax.set_ylim(0, min(max(st)*1.1, 150))

    d = sw['quality']
    qs = [r['sweep_value'] for r in d]
    cvs = [r['stats']['CV'] for r in d]
    ax = axes[2]
    ax.plot(qs, cvs, 'd-', color='#FF9800', lw=2, ms=5, label='This work', zorder=5)
    ax.axhspan(0.1,0.6, alpha=0.2, color='green', label='PIV experiments')
    ax.set_xlabel('Quality Q'); ax.set_ylabel('CV'); ax.set_title('Channeling CV'); ax.legend(fontsize=7)

    plt.tight_layout()
    p = os.path.join(out, 'fig10_literature.png'); plt.savefig(p); plt.close(); return p


def plot_extraction_comparison(out):
    """Fig 11: Extraction at different quality levels"""
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    fig.suptitle('Extraction Uniformity at Different Distribution Qualities', fontsize=13, fontweight='bold')

    for idx, (Q, label) in enumerate([(0.4,'Poor Q=0.4'), (0.7,'Good Q=0.7'), (0.95,'Excellent Q=0.95')]):
        par = DEFAULT_PARAMS.copy(); par['distribution_quality'] = Q
        res = run_sim(par, fast=False, verbose=False)
        ax = axes[idx]
        im = ax.pcolormesh(res['r']*1000, res['z']*1000, res['E'],
                          cmap='RdYlGn_r', shading='auto', vmin=0, vmax=1)
        ax.invert_yaxis(); ax.set_xlabel('r [mm]'); ax.set_ylabel('z [mm]')
        ax.set_title(f'{label}\nCV={res["stats"]["CV"]:.2f}, Q={res["stats"]["flow_rate_mLs"]:.1f}mL/s')
        plt.colorbar(im, ax=ax, shrink=0.8, label='Extraction')

    plt.tight_layout()
    p = os.path.join(out, 'fig11_extraction_comparison.png'); plt.savefig(p); plt.close(); return p


# ============================================================================
# MAIN
# ============================================================================
def main():
    setup_style()
    out = '/sessions/amazing-eager-keller/output'
    os.makedirs(out, exist_ok=True)

    t0 = time.time()
    print("="*60)
    print("ESPRESSO PUCK CFD — PARAMETRIC STUDY")
    print("="*60)

    print("\n>>> Reference simulation...")
    ref = run_sim(fast=False, verbose=True)

    print("\n>>> Field maps...")
    f1 = plot_fields(ref, out)

    print("\n>>> Parametric sweeps...")
    sw = run_all_sweeps()

    print("\n>>> Generating figures...")
    f2 = plot_grind(sw, out)
    f3 = plot_pressure(sw, out)
    f4 = plot_temperature(sw, out)
    f5 = plot_dose(sw, out)
    f6 = plot_quality(sw, out)
    f7 = plot_tamp(sw, out)
    f8 = plot_heatmap(out)
    f9, sens = plot_sensitivity(sw, out)
    f10 = plot_literature(sw, out)
    f11 = plot_extraction_comparison(out)

    # Save JSON results
    print("\n>>> Saving results...")
    summary = {}
    for name in sw:
        summary[name] = [dict(value=float(r['sweep_value']),
                              flow=float(r['stats']['flow_rate_mLs']),
                              time=float(r['stats']['shot_time_s']),
                              CV=float(r['stats']['CV']),
                              risk=float(r['stats']['channeling_risk']),
                              porosity=float(r['stats']['porosity']),
                              puck_mm=float(r['stats']['puck_height_mm']))
                         for r in sw[name]]

    results = dict(
        reference={k: float(v) for k,v in ref['stats'].items()},
        sensitivities={k: {kk: float(vv) for kk,vv in v.items()} for k,v in sens.items()},
        sweeps=summary,
    )
    with open(os.path.join(out, 'results.json'), 'w') as f:
        json.dump(results, f, indent=2)

    elapsed = time.time() - t0
    print(f"\n>>> Done in {elapsed:.1f}s")
    print("Figures:", out)
    for p in [f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11]:
        print(f"  {p}")

    return results, sw, ref


if __name__ == '__main__':
    results, sweeps, ref = main()
