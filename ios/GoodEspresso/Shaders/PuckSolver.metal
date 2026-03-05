//
//  PuckSolver.metal
//  Good Espresso
//
//  Metal compute kernels for GPU-accelerated puck CFD simulation.
//  Red-Black SOR pressure solver + Darcy velocity computation
//  in axisymmetric cylindrical coordinates (r, z).
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Solver Parameters (shared with Swift via matching struct layout)

struct SolverParams {
    uint  nz;          // axial grid rows
    uint  nr;          // radial grid cols
    float dr;          // radial cell size (m)
    float dz;          // axial cell size (m)
    float omega;       // SOR relaxation factor
    float topPressure; // top boundary pressure (Pa)
    float botPressure; // bottom boundary pressure (Pa)
    uint  color;       // 0 = red cells, 1 = black cells
    float mu;          // dynamic viscosity (Pa·s)
};

// MARK: - Red-Black SOR Pressure Solver
//
// Solves: (1/r) d/dr(r·k·dP/dr) + d/dz(k·dP/dz) = 0
//
// Red-black coloring: cells where (r+z)%2 == color are updated.
// Each color phase is fully parallel — no data races.

kernel void redBlackSOR(
    device float*       P    [[buffer(0)]],   // pressure field (nz × nr), read/write
    device const float* K    [[buffer(1)]],   // permeability field (nz × nr)
    constant SolverParams& params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint r = gid.x;
    uint z = gid.y + 1;  // skip top boundary row (z=0 is Dirichlet)

    if (z >= params.nz - 1 || r >= params.nr) return;

    // Red-black check
    if ((r + z) % 2 != params.color) return;

    uint nr = params.nr;
    uint idx = z * nr + r;

    float kC = K[idx];

    // Neighbor indices with boundary clamping
    uint up    = (z - 1) * nr + r;
    uint down  = (z + 1) * nr + r;
    uint left  = z * nr + (r > 0 ? r - 1 : 0);       // symmetry BC at r=0
    uint right = z * nr + (r < nr - 1 ? r + 1 : nr - 1); // no-flow at wall

    // Harmonic mean permeabilities at interfaces
    float kUp    = K[up];
    float kDown  = K[down];
    float kLeft  = K[left];
    float kRight = K[right];

    float kZPlus  = 2.0f * kC * kDown  / (kC + kDown  + 1e-30f);
    float kZMinus = 2.0f * kC * kUp    / (kC + kUp    + 1e-30f);
    float kRPlus  = 2.0f * kC * kRight / (kC + kRight + 1e-30f);
    float kRMinus = 2.0f * kC * kLeft  / (kC + kLeft  + 1e-30f);

    // Cylindrical coordinate correction
    float rPos      = (float(r) + 0.5f) * params.dr;
    float rPlusHalf = rPos + params.dr * 0.5f;
    float rMinusHalf = max(rPos - params.dr * 0.5f, params.dr * 0.01f);

    float dz2 = params.dz * params.dz;
    float dr2 = params.dr * params.dr;

    float aZ     = (kZPlus + kZMinus) / dz2;
    float aRPlus = kRPlus  * rPlusHalf  / (rPos * dr2);
    float aRMinus= kRMinus * rMinusHalf / (rPos * dr2);
    float sumCoeff = aZ + aRPlus + aRMinus;

    if (sumCoeff <= 0.0f) return;

    float newP = (kZPlus  * P[down]  / dz2
                + kZMinus * P[up]    / dz2
                + aRPlus  * P[right]
                + aRMinus * P[left]) / sumCoeff;

    // SOR update
    P[idx] = P[idx] + params.omega * (newP - P[idx]);
}

// MARK: - Darcy Velocity Computation
//
// v = -(k/mu) * grad(P)
// Central differences for interior, forward/backward at boundaries.

struct VelocityOut {
    float vr;     // radial velocity
    float vz;     // axial velocity (positive = downward)
    float vmag;   // velocity magnitude
};

kernel void computeVelocity(
    device const float* P     [[buffer(0)]],
    device const float* K     [[buffer(1)]],
    device float*       Vr    [[buffer(2)]],  // radial velocity output
    device float*       Vz    [[buffer(3)]],  // axial velocity output
    device float*       Vmag  [[buffer(4)]],  // magnitude output
    constant SolverParams& params [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint r = gid.x;
    uint z = gid.y;
    uint nr = params.nr;
    uint nz = params.nz;

    if (z >= nz || r >= nr) return;

    uint idx = z * nr + r;
    float k = K[idx];
    float mu = params.mu;

    // Axial pressure gradient
    float dPdz;
    if (z == 0) {
        dPdz = (P[(z + 1) * nr + r] - P[z * nr + r]) / params.dz;
    } else if (z == nz - 1) {
        dPdz = (P[z * nr + r] - P[(z - 1) * nr + r]) / params.dz;
    } else {
        dPdz = (P[(z + 1) * nr + r] - P[(z - 1) * nr + r]) / (2.0f * params.dz);
    }

    // Radial pressure gradient
    float dPdr;
    if (r == 0 || r == nr - 1) {
        dPdr = 0.0f;  // symmetry / no-flow BC
    } else {
        dPdr = (P[z * nr + r + 1] - P[z * nr + r - 1]) / (2.0f * params.dr);
    }

    float vz_val = -(k / mu) * dPdz;
    float vr_val = -(k / mu) * dPdr;
    float mag = sqrt(vr_val * vr_val + vz_val * vz_val);

    Vr[idx]   = vr_val;
    Vz[idx]   = vz_val;
    Vmag[idx] = mag;
}

// MARK: - Permeability Field Builder
//
// Generates the spatially-varying permeability field on GPU.
// This parallelizes the per-cell computation that was previously a nested CPU loop.

struct PermParams {
    uint  nz;
    uint  nr;
    float dr;
    float radiusM;
    float baseK;
    float variationScale;     // 1 - distributionQuality
    float moistureContent;
    float holeCount;
    float holeDiameter;
    float basketDiameter;
    uint  seed;
};

// Simple GPU-compatible hash for deterministic pseudo-random
inline float gpuRand(uint seed, uint x, uint y) {
    uint h = seed ^ (x * 374761393u) ^ (y * 668265263u);
    h = (h ^ (h >> 13)) * 1274126177u;
    h = h ^ (h >> 16);
    return float(h & 0xFFFFu) / 65535.0f;
}

kernel void buildPermField(
    device float*         K       [[buffer(0)]],
    constant PermParams&  params  [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint r = gid.x;
    uint z = gid.y;
    uint nr = params.nr;
    uint nz = params.nz;

    if (z >= nz || r >= nr) return;

    float localK = params.baseK;
    float rNorm = float(r) / float(nr - 1);
    float zNorm = float(z) / float(nz - 1);
    float rPos = (float(r) + 0.5f) * params.dr;

    // Wall boundary layer
    if (rNorm > 0.78f) {
        float edgeFactor = 1.0f + 0.55f * pow((rNorm - 0.78f) / 0.22f, 0.7f);
        localK *= edgeFactor;
    }

    // Center axis packing irregularity
    if (rNorm < 0.08f) {
        localK *= 1.0f + 0.12f * (1.0f - rNorm / 0.08f);
    }

    // Bottom compaction (fines migration)
    if (zNorm > 0.65f) {
        float finesFactor = 1.0f - 0.30f * pow((zNorm - 0.65f) / 0.35f, 1.3f);
        localK *= finesFactor;
    }

    // Bottom filter screen mesh effect
    if (zNorm > 0.88f) {
        float screenProximity = (zNorm - 0.88f) / 0.12f;
        float holesPerRing = max(4.0f, sqrt(params.holeCount));
        float ringSpacing = params.radiusM / (holesPerRing / (2.0f * M_PI_F));
        float ringPhase = sin(rPos / max(1e-6f, ringSpacing) * 2.0f * M_PI_F * 3.0f);
        localK *= max(0.55f, 1.0f + screenProximity * 0.45f * ringPhase);
    }

    // Top entry loosening
    if (zNorm < 0.06f) {
        localK *= 1.0f + 0.18f * (1.0f - zNorm / 0.06f);
    }

    // Distribution quality noise (deterministic GPU random)
    float noise = (gpuRand(params.seed, r, z) - 0.5f) * 2.0f * params.variationScale;
    localK *= exp(noise * 0.8f);

    // Moisture variation
    float moistureNoise = 1.0f - params.moistureContent * 0.3f * gpuRand(params.seed + 7u, r, z);
    localK *= moistureNoise;

    K[z * nr + r] = max(localK * 0.1f, localK);
}
