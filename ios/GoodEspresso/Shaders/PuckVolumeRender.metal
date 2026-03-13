//
//  PuckVolumeRender.metal
//  Good Espresso
//
//  GPU ray-marching volume renderer for puck CFD visualization.
//  Renders the 2D axisymmetric simulation data as a full 3D volume
//  by exploiting rotational symmetry — the 2D (r,z) field is sampled
//  at each ray step by converting the 3D hit point to cylindrical coords.
//
//  Supports dual clip planes, PBR-style directional lighting,
//  smooth heatmap colormaps, and optional grain noise texture.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

struct VolumeUniforms {
    float4x4 invViewProj;     // inverse view-projection matrix
    float4   cameraPos;       // world-space camera position
    float4   lightDir;        // normalized directional light (world space)
    float4   lightColor;      // light RGB + intensity in .w
    float4   ambientColor;    // ambient RGB + intensity in .w
    float2   resolution;      // viewport width, height
    float    puckRadius;      // normalized (1.0 = full radius)
    float    puckHeight;      // height/diameter ratio
    float    taperRatio;      // bottom radius / top radius
    float    cutX;            // clip plane X (0 = center, 1 = no cut)
    float    cutZ;            // clip plane Z (0 = center, 1 = no cut)
    float    stepSize;        // ray march step size
    float    opacity;         // volume opacity multiplier
    float    grainIntensity;  // coffee grain noise strength
    uint     vizMode;         // 0=pressure 1=flow 2=extraction 3=time 4=perm
    float    animProgress;    // 0-1 animation front
    uint     fieldRows;       // nz
    uint     fieldCols;       // nr
};

// MARK: - Colormap Functions

// Pressure: Blue -> Cyan -> Green -> Yellow -> Red
float3 colormapPressure(float t) {
    if (t < 0.25) {
        float f = t / 0.25;
        return float3(0, f * 0.5, 0.6 + f * 0.4);
    } else if (t < 0.5) {
        float f = (t - 0.25) / 0.25;
        return float3(0, 0.5 + f * 0.5, 1.0 - f * 0.5);
    } else if (t < 0.75) {
        float f = (t - 0.5) / 0.25;
        return float3(f, 1.0, 0.5 - f * 0.5);
    }
    float f = (t - 0.75) / 0.25;
    return float3(1.0, 1.0 - f * 0.7, 0);
}

// Flow: Dark Blue -> Cyan -> White -> Yellow -> Red
float3 colormapFlow(float t) {
    if (t < 0.2) {
        float f = t / 0.2;
        return float3(0.02, 0.02 + f * 0.15, 0.15 + f * 0.4);
    } else if (t < 0.4) {
        float f = (t - 0.2) / 0.2;
        return float3(0, 0.17 + f * 0.63, 0.55 + f * 0.45);
    } else if (t < 0.6) {
        float f = (t - 0.4) / 0.2;
        return float3(f * 0.9, 0.8 + f * 0.2, 1.0 - f * 0.2);
    } else if (t < 0.8) {
        float f = (t - 0.6) / 0.2;
        return float3(0.9 + f * 0.1, 1.0 - f * 0.3, 0.8 - f * 0.8);
    }
    float f = (t - 0.8) / 0.2;
    return float3(1.0, 0.7 - f * 0.5, 0);
}

// Extraction: Dark Green -> Light Green -> Orange -> Red
float3 colormapExtraction(float t) {
    if (t < 0.3) {
        float f = t / 0.3;
        return float3(0.05, 0.08 + f * 0.3, 0.05 + f * 0.1);
    } else if (t < 0.55) {
        float f = (t - 0.3) / 0.25;
        return float3(0.05 + f * 0.1, 0.38 + f * 0.52, 0.15 - f * 0.05);
    } else if (t < 0.75) {
        float f = (t - 0.55) / 0.2;
        return float3(0.15 + f * 0.85, 0.9 - f * 0.2, 0.1);
    }
    float f = (t - 0.75) / 0.25;
    return float3(1.0, 0.7 - f * 0.55, 0.1 - f * 0.1);
}

// Residence time: Cool Blue -> Teal -> Amber -> Red
float3 colormapTime(float t) {
    if (t < 0.25) {
        float f = t / 0.25;
        return float3(0.05, 0.15 + f * 0.35, 0.5 + f * 0.3);
    } else if (t < 0.5) {
        float f = (t - 0.25) / 0.25;
        return float3(0.05 + f * 0.2, 0.5 + f * 0.3, 0.8 - f * 0.3);
    } else if (t < 0.75) {
        float f = (t - 0.5) / 0.25;
        return float3(0.25 + f * 0.65, 0.8 - f * 0.15, 0.5 - f * 0.35);
    }
    float f = (t - 0.75) / 0.25;
    return float3(0.9 + f * 0.1, 0.65 - f * 0.45, 0.15 - f * 0.1);
}

// Permeability: Dark Purple -> Blue -> Teal -> Light Green
float3 colormapPerm(float t) {
    if (t < 0.33) {
        float f = t / 0.33;
        return float3(0.15 + f * 0.05, 0.05 + f * 0.15, 0.25 + f * 0.35);
    } else if (t < 0.66) {
        float f = (t - 0.33) / 0.33;
        return float3(0.2 - f * 0.1, 0.2 + f * 0.45, 0.6 - f * 0.1);
    }
    float f = (t - 0.66) / 0.34;
    return float3(0.1 + f * 0.3, 0.65 + f * 0.25, 0.5 - f * 0.25);
}

float3 applyColormap(float t, uint mode) {
    t = clamp(t, 0.0f, 1.0f);
    switch (mode) {
        case 0: return colormapPressure(t);
        case 1: return colormapFlow(t);
        case 2: return colormapExtraction(t);
        case 3: return colormapTime(t);
        case 4: return colormapPerm(t);
        default: return colormapFlow(t);
    }
}

// MARK: - GPU-compatible hash for grain noise

float hash3D(float3 p) {
    float3 q = fract(p * float3(127.1, 311.7, 74.7));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// MARK: - Ray-Cylinder Intersection
// Intersects ray with a tapered cylinder (truncated cone) centered at origin,
// axis along Y, from y = -halfH to y = +halfH.
// Returns (tNear, tFar) or (-1, -1) if no hit.

float2 intersectTaperedCylinder(float3 ro, float3 rd,
                                 float topR, float botR, float halfH) {
    // Parametric radius: R(y) = topR + (botR - topR) * (halfH - y) / (2 * halfH)
    // which simplifies to R(y) = a + b*y where:
    float a = (topR + botR) * 0.5;
    float b = (topR - botR) / (2.0 * halfH);

    // Solve: (ox + t*dx)^2 + (oz + t*dz)^2 = (a + b*(oy + t*dy))^2
    float dx = rd.x, dy = rd.y, dz = rd.z;
    float ox = ro.x, oy = ro.y, oz = ro.z;

    float A = dx*dx + dz*dz - b*b*dy*dy;
    float aby = a + b*oy;
    float B = 2.0*(ox*dx + oz*dz - b*b*dy*aby + (-b)*dy*0.0);
    B = 2.0*(ox*dx + oz*dz - b*aby*dy);
    float C = ox*ox + oz*oz - aby*aby;

    float disc = B*B - 4.0*A*C;
    if (disc < 0.0) return float2(-1.0);

    float sq = sqrt(disc);
    float t0 = (-B - sq) / (2.0*A);
    float t1 = (-B + sq) / (2.0*A);

    // Clamp to y range
    float y0 = oy + t0 * dy;
    float y1 = oy + t1 * dy;

    float tNear = t0, tFar = t1;
    if (y0 < -halfH || y0 > halfH) {
        // Intersect with cap planes
        float tBot = (-halfH - oy) / dy;
        float tTop = (halfH - oy) / dy;
        if (dy < 0) { float tmp = tBot; tBot = tTop; tTop = tmp; }
        tNear = max(tNear, tBot);
    }
    if (y1 < -halfH || y1 > halfH) {
        float tBot = (-halfH - oy) / dy;
        float tTop = (halfH - oy) / dy;
        if (dy < 0) { float tmp = tBot; tBot = tTop; tTop = tmp; }
        tFar = min(tFar, tTop);
    }

    // Simple AABB-style clamp using caps
    float tCapNear = (-halfH - oy) / dy;
    float tCapFar  = ( halfH - oy) / dy;
    if (tCapNear > tCapFar) { float tmp = tCapNear; tCapNear = tCapFar; tCapFar = tmp; }
    tNear = max(tNear, tCapNear);
    tFar  = min(tFar,  tCapFar);

    if (tNear > tFar || tFar < 0.0) return float2(-1.0);
    return float2(max(0.0f, tNear), tFar);
}

// MARK: - Sample field with bilinear interpolation

float sampleField(texture2d<float, access::sample> field,
                   float rNorm, float zNorm,
                   uint nz, uint nr) {
    // The texture stores the 2D (z, r) field as a 2D texture
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    // Texture coords: x = r/nr, y = z/nz
    float2 uv = float2(rNorm, zNorm);
    return field.sample(s, uv).r;
}

// MARK: - Volume Ray March Kernel

kernel void puckVolumeRayMarch(
    texture2d<float, access::write>  output    [[texture(0)]],
    texture2d<float, access::sample> fieldTex  [[texture(1)]],
    constant VolumeUniforms&         u         [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uint(u.resolution.x) || gid.y >= uint(u.resolution.y)) return;

    // NDC coords
    float2 ndc = float2(gid) / u.resolution * 2.0 - 1.0;
    ndc.y = -ndc.y;  // flip Y for Metal convention

    // Ray origin and direction from inverse view-projection
    float4 nearClip = u.invViewProj * float4(ndc, 0.0, 1.0);
    float4 farClip  = u.invViewProj * float4(ndc, 1.0, 1.0);
    float3 nearW = nearClip.xyz / nearClip.w;
    float3 farW  = farClip.xyz / farClip.w;
    float3 ro = u.cameraPos.xyz;
    float3 rd = normalize(farW - nearW);

    float topR = u.puckRadius;
    float botR = topR * u.taperRatio;
    float halfH = u.puckHeight * 0.5;

    // Intersect ray with bounding cylinder
    float2 tRange = intersectTaperedCylinder(ro, rd, topR, botR, halfH);

    // Background color (dark)
    float3 bgColor = float3(0.04, 0.04, 0.07);

    if (tRange.x < 0.0) {
        output.write(float4(bgColor, 1.0), gid);
        return;
    }

    // Ray march through the volume
    float3 accumColor = float3(0.0);
    float accumAlpha = 0.0;
    float t = tRange.x;
    float step = u.stepSize;
    float3 firstHitNormal = float3(0.0);
    bool hitSurface = false;

    for (int i = 0; i < 256 && t < tRange.y && accumAlpha < 0.97; i++) {
        float3 p = ro + rd * t;

        // Clip planes
        if (u.cutX < 0.99 && p.x > u.cutX * topR) { t += step; continue; }
        if (u.cutZ < 0.99 && p.z > u.cutZ * topR) { t += step; continue; }

        // Convert to cylindrical coords
        float r = sqrt(p.x * p.x + p.z * p.z);
        float y = p.y;

        // Radius at this height (tapered cylinder)
        float yNorm = (halfH - y) / (2.0 * halfH);  // 0 at top, 1 at bottom
        float localR = topR + (botR - topR) * yNorm;

        // Check if inside the puck
        if (r > localR) { t += step; continue; }

        // Normalized coords for field sampling
        float rN = r / localR;     // 0 = center, 1 = wall
        float zN = yNorm;          // 0 = top, 1 = bottom

        // Animation: mask below the front
        if (u.animProgress < 1.0 && u.vizMode != 4) {
            float front = u.animProgress / 0.65;
            if (zN > front + 0.05) { t += step; continue; }
        }

        // Sample the field texture
        float val = sampleField(fieldTex, rN, zN, u.fieldRows, u.fieldCols);

        // Apply grain noise on clip faces
        float grain = 0.0;
        bool onClipFace = false;
        if (u.cutX < 0.99 && abs(p.x - u.cutX * topR) < step * 1.5) onClipFace = true;
        if (u.cutZ < 0.99 && abs(p.z - u.cutZ * topR) < step * 1.5) onClipFace = true;
        if (onClipFace) {
            grain = (hash3D(p * 80.0) - 0.5) * u.grainIntensity;
        }

        float3 color = applyColormap(val + grain, u.vizMode);

        // Surface detection: use higher opacity at the puck boundary
        // for a solid-looking exterior with volumetric interior on clip faces
        float edgeDist = localR - r;
        float topDist = abs(y - halfH);
        float botDist = abs(y + halfH);
        float surfaceDist = min(edgeDist, min(topDist, botDist));

        float alpha;
        if (onClipFace) {
            // Clip face: solid opaque rendering (like a cross-section)
            alpha = u.opacity * 2.0;
        } else if (surfaceDist < step * 2.0) {
            // Near surface: render as solid shell
            alpha = u.opacity * 1.5;
            if (!hitSurface) {
                // Compute surface normal for lighting
                if (edgeDist < topDist && edgeDist < botDist) {
                    firstHitNormal = normalize(float3(p.x, 0, p.z));
                } else if (topDist < botDist) {
                    firstHitNormal = float3(0, 1, 0);
                } else {
                    firstHitNormal = float3(0, -1, 0);
                }
                hitSurface = true;
            }
        } else {
            // Interior: only visible through clip planes, very transparent
            alpha = u.opacity * 0.15;
        }

        alpha = clamp(alpha, 0.0f, 1.0f);

        // Front-to-back compositing
        float w = alpha * (1.0 - accumAlpha);
        accumColor += color * w;
        accumAlpha += w;

        t += step;
    }

    // Apply lighting to accumulated color
    if (hitSurface && accumAlpha > 0.01) {
        float3 N = firstHitNormal;
        float3 L = normalize(u.lightDir.xyz);
        float NdotL = max(dot(N, L), 0.0);
        float3 lit = accumColor * (u.ambientColor.xyz * u.ambientColor.w +
                                    u.lightColor.xyz * u.lightColor.w * NdotL);
        // Rim light for edge definition
        float3 V = normalize(u.cameraPos.xyz - (ro + rd * tRange.x));
        float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0) * 0.15;
        accumColor = lit + float3(rim);
    }

    // Composite over background
    float3 finalColor = accumColor + bgColor * (1.0 - accumAlpha);
    output.write(float4(finalColor, 1.0), gid);
}

// MARK: - Fullscreen quad vertex shader (for non-compute path)

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fullscreenQuadVertex(uint vid [[vertex_id]]) {
    // Two-triangle fullscreen quad
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1,  1), float2(1, -1), float2( 1, 1)
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}
