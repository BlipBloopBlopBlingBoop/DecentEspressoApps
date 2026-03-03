//
//  Puck3DView.swift
//  Good Espresso
//
//  Interactive 3D puck visualization using SceneKit.
//  Renders CFD simulation as a cutaway cylinder with per-vertex
//  interpolated heatmap coloring, accurate tapered basket geometry,
//  metallic basket shell (headspace only), and orbit camera.
//
//  Cutaway uses two orthogonal Cartesian clip planes (X and Z).
//  The SCNScene is created once and persists across updates — only the
//  content node is swapped — so the camera controller's zoom/orbit state
//  is never lost during animation playback.
//
//  Color computation uses direct Float arithmetic (no SwiftUI Color /
//  UIColor round-trip) for ~200K vertices per frame on M-series hardware.
//

import SwiftUI
import SceneKit

// MARK: - SwiftUI Wrapper

struct Puck3DSceneView: View {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    var animationProgress: Double = 1.0
    var cutX: Double = 0.55
    var cutZ: Double = 0.55

    var body: some View {
        PuckSceneRepresentable(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons,
            tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
    }
}

// MARK: - Platform Representables

#if canImport(UIKit)
struct PuckSceneRepresentable: UIViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    let cutX: Double
    let cutZ: Double
    var animationProgress: Double = 1.0

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        v.antialiasingMode = .multisampling4X
        let scene = PuckSceneBuilder.makeSceneShell()
        scene.rootNode.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
        v.scene = scene
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        guard let root = v.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        root.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
    }
}
#elseif canImport(AppKit)
struct PuckSceneRepresentable: NSViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    let cutX: Double
    let cutZ: Double
    var animationProgress: Double = 1.0

    func makeNSView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor
        v.antialiasingMode = .multisampling4X
        let scene = PuckSceneBuilder.makeSceneShell()
        scene.rootNode.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
        v.scene = scene
        return v
    }

    func updateNSView(_ v: SCNView, context: Context) {
        guard let root = v.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        root.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
    }
}
#endif

// MARK: - Scene Builder

enum PuckSceneBuilder {

    static let contentNodeName = "puckContent"

    // MARK: Persistent scene shell

    static func makeSceneShell() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = pColor(0.04, 0.04, 0.07)
        addLighting(to: scene.rootNode)

        let cam = SCNNode()
        cam.name = "camera"
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 34
        cam.camera?.zNear = 0.01
        cam.camera?.zFar = 50
        cam.position = SCNVector3(1.4, 1.1, 1.8)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)
        return scene
    }

    // MARK: Content node

    static func buildContentNode(
        result: PuckSimulationResult,
        mode: PuckVizMode,
        basketSpec: BasketSpec,
        grindSizeMicrons: Double,
        tampPressureKg: Double,
        cutX: Double, cutZ: Double,
        animationProgress: Double = 1.0
    ) -> SCNNode {
        let root = SCNNode()
        root.name = contentNodeName

        let nz = result.gridRows
        let nr = result.gridCols
        let isAnim = animationProgress < 1.0
        let thetaSeg = isAnim ? 200 : 300

        let rawField = selectField(result: result, mode: mode)
        let field = applyAnimationProgress(to: rawField, progress: animationProgress, mode: mode)

        let topR: Float = 1.0
        let taper: Float = basketSpec.hasBackPressureValve ? 0.96 : 0.93
        let botR: Float = topR * taper
        let lipF: Float = 0.03
        let pH: Float = Float(basketSpec.depth / basketSpec.diameter) * 2.0
        let dz = pH / Float(nz)
        let xC = Float(cutX) * topR
        let zC = Float(cutZ) * topR

        // Outer surface sampling: blend outer ~5% cells for richer color
        let outerSpan = max(2, nr / 20)
        func outerVal(_ z: Int) -> Double {
            var sum = 0.0
            for r in (nr - outerSpan)..<nr {
                sum += field[min(z, nz - 1)][r]
            }
            return sum / Double(outerSpan)
        }

        // MARK: Mesh buffers

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var cols: [SIMD4<Float>] = []
        var idxs: [UInt32] = []

        // Flat-shaded quad (same color all 4 verts)
        func addQ(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                  n: SCNVector3, c: SIMD4<Float>) {
            let b = UInt32(verts.count)
            verts += [v0, v1, v2, v3]; norms += [n, n, n, n]; cols += [c, c, c, c]
            idxs += [b, b+1, b+2, b, b+2, b+3]
        }

        // Per-vertex colored quad (smooth interpolation)
        func addQI(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                   n: SCNVector3, c0: SIMD4<Float>, c1: SIMD4<Float>, c2: SIMD4<Float>, c3: SIMD4<Float>) {
            let b = UInt32(verts.count)
            verts += [v0, v1, v2, v3]; norms += [n, n, n, n]; cols += [c0, c1, c2, c3]
            idxs += [b, b+1, b+2, b, b+2, b+3]
        }

        func rAt(_ zi: Int) -> Float {
            let f = Float(zi) / Float(nz)
            let lip: Float = f < 0.15 ? lipF * (1.0 - f / 0.15) : 0
            return topR + (botR - topR) * f + lip
        }

        let dT = Float(2.0 * .pi) / Float(thetaSeg)

        // MARK: Outer surface — per-vertex z-interpolated colors
        // Uses blend of outer radial cells for richer color gradient

        for z in 0..<nz {
            let valT = outerVal(z)
            let valB = outerVal(z + 1)
            let cT = colorSIMD(valT, mode: mode)
            let cB = colorSIMD(valB, mode: mode)
            let yT = pH / 2 - Float(z) * dz
            let yB = yT - dz
            let rT = rAt(z), rB = rAt(z + 1)

            for t in 0..<thetaSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                guard rT * cos(mid) <= xC || cutX >= 0.99 else { continue }
                guard rT * sin(mid) <= zC || cutZ >= 0.99 else { continue }

                addQI(
                    SCNVector3(rT*cos(t0), yT, rT*sin(t0)),
                    SCNVector3(rT*cos(t1), yT, rT*sin(t1)),
                    SCNVector3(rB*cos(t1), yB, rB*sin(t1)),
                    SCNVector3(rB*cos(t0), yB, rB*sin(t0)),
                    n: SCNVector3(cos(mid), 0, sin(mid)),
                    c0: cT, c1: cT, c2: cB, c3: cB
                )
            }
        }

        // MARK: Top face — per-vertex radial interpolation

        let rTO = rAt(0)
        for r in 0..<nr {
            let valI = field[0][r]
            let valO = field[0][min(r + 1, nr - 1)]
            let cI = colorSIMD(valI, mode: mode)
            let cO = colorSIMD(valO, mode: mode)
            let ri = Float(r) / Float(nr) * rTO
            let ro = Float(r + 1) / Float(nr) * rTO
            let y = pH / 2
            for t in 0..<thetaSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                let rm = (ri + ro) / 2
                guard rm * cos(mid) <= xC || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC || cutZ >= 0.99 else { continue }
                addQI(SCNVector3(ri*cos(t0), y, ri*sin(t0)),
                      SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                      SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                      SCNVector3(ri*cos(t1), y, ri*sin(t1)),
                      n: SCNVector3(0, 1, 0),
                      c0: cI, c1: cO, c2: cO, c3: cI)
            }
        }

        // MARK: Bottom face — per-vertex radial interpolation

        let rBO = rAt(nz)
        for r in 0..<nr {
            let valI = field[nz - 1][r]
            let valO = field[nz - 1][min(r + 1, nr - 1)]
            let cI = colorSIMD(valI, mode: mode)
            let cO = colorSIMD(valO, mode: mode)
            let ri = Float(r) / Float(nr) * rBO
            let ro = Float(r + 1) / Float(nr) * rBO
            let y = -pH / 2
            for t in 0..<thetaSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                let rm = (ri + ro) / 2
                guard rm * cos(mid) <= xC || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC || cutZ >= 0.99 else { continue }
                addQI(SCNVector3(ri*cos(t1), y, ri*sin(t1)),
                      SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                      SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                      SCNVector3(ri*cos(t0), y, ri*sin(t0)),
                      n: SCNVector3(0, -1, 0),
                      c0: cI, c1: cO, c2: cO, c3: cI)
            }
        }

        // MARK: Clip faces — bilinear interpolated colors + grain noise

        // Grain noise intensity scales with grind size (coarser = more texture)
        let grainIntensity = 0.03 + 0.06 * min(1.0, grindSizeMicrons / 600.0)

        if cutX < 0.99 {
            addClipFace(clipPos: xC, axis: .x, otherClipPos: zC, otherCut: cutZ,
                        nz: nz, nr: nr, field: field, mode: mode,
                        pH: pH, dz: dz, topR: topR, rAt: rAt,
                        grainIntensity: grainIntensity,
                        verts: &verts, norms: &norms, cols: &cols, idxs: &idxs)
        }
        if cutZ < 0.99 {
            addClipFace(clipPos: zC, axis: .z, otherClipPos: xC, otherCut: cutX,
                        nz: nz, nr: nr, field: field, mode: mode,
                        pH: pH, dz: dz, topR: topR, rAt: rAt,
                        grainIntensity: grainIntensity,
                        verts: &verts, norms: &norms, cols: &cols, idxs: &idxs)
        }

        // Build puck node with grind/tamp-responsive material
        let puckGeo = buildGeometry(vertices: verts, normals: norms, colors: cols, indices: idxs)
        let puckMat = SCNMaterial()
        puckMat.lightingModel = .physicallyBased
        puckMat.isDoubleSided = true  // ensures top face visible from all angles
        // Roughness: coarser grind = rougher, finer = smoother
        // Heavy tamp = slightly smoother (compacted surface)
        let grindNorm = min(1.0, grindSizeMicrons / 800.0)
        let tampNorm = min(1.0, tampPressureKg / 30.0)
        let roughness = 0.75 + grindNorm * 0.20 - tampNorm * 0.08
        puckMat.roughness.contents = CGFloat(roughness)
        puckMat.metalness.contents = CGFloat(0.02)
        puckGeo.materials = [puckMat]
        root.addChildNode(SCNNode(geometry: puckGeo))

        // MARK: Basket shell — headspace wall only (stops at puck top exactly)
        let shellExtra: Float = pH * 0.25
        addBasketShell(to: root, puckHeight: pH, topR: topR, botR: botR,
                       shellExtra: shellExtra, rAt: rAt, nz: nz,
                       xC: xC, zC: zC, cutX: cutX, cutZ: cutZ, tSeg: thetaSeg)
        addBasketRim(to: root, radius: topR + 0.04, y: pH / 2 + shellExtra)

        // MARK: Showerhead screen (group head dispersion screen above puck)
        let showerY = pH / 2 + shellExtra - 0.01
        addScreenDisc(to: root, y: showerY, radius: topR - 0.01,
                      holeRings: 8, holesPerRing: 16, holeRadius: 0.012,
                      xC: xC, zC: zC, cutX: cutX, cutZ: cutZ, tSeg: thetaSeg,
                      color: (r: 0.68, g: 0.68, b: 0.72))

        // MARK: Basket bottom screen (filter screen under puck)
        let screenY = -pH / 2 - 0.005
        let rBot = rAt(nz) + 0.002
        addScreenDisc(to: root, y: screenY, radius: rBot,
                      holeRings: 10, holesPerRing: Int(sqrt(Double(basketSpec.holeCount))),
                      holeRadius: Float(basketSpec.holeDiameter) / Float(basketSpec.diameter) * 2.0,
                      xC: xC, zC: zC, cutX: cutX, cutZ: cutZ, tSeg: min(thetaSeg, 120),
                      color: (r: 0.72, g: 0.72, b: 0.75))

        addLabel(to: root, text: "Water In  \u{2193}",
                 position: SCNVector3(0, pH / 2 + shellExtra + 0.1, 0.3))
        addLabel(to: root, text: "\u{2191}  Basket Exit",
                 position: SCNVector3(0, -pH / 2 - 0.15, 0.3))

        return root
    }

    // MARK: - Clip Face (bilinear interpolated + grain texture)

    enum ClipAxis { case x, z }

    private static func addClipFace(
        clipPos: Float, axis: ClipAxis,
        otherClipPos: Float, otherCut: Double,
        nz: Int, nr: Int, field: [[Double]], mode: PuckVizMode,
        pH: Float, dz: Float, topR: Float, rAt: (Int) -> Float,
        grainIntensity: Double,
        verts: inout [SCNVector3], norms: inout [SCNVector3],
        cols: inout [SIMD4<Float>], idxs: inout [UInt32]
    ) {
        let norm: SCNVector3 = axis == .x ? SCNVector3(1, 0, 0) : SCNVector3(0, 0, 1)
        let perpSteps = max(nr, 160)
        let perpMax = otherCut >= 0.99 ? topR : otherClipPos
        let perpMin: Float = -topR
        let perpD = (perpMax - perpMin) / Float(perpSteps)

        srand48(axis == .x ? 777 : 888)

        // Field sample with linear r-interpolation
        func sample(_ z: Int, _ perpPos: Float, _ localR: Float) -> Double {
            let dist = sqrt(clipPos * clipPos + perpPos * perpPos)
            let rN = min(1.0, dist / max(0.001, localR))
            let rF = rN * Float(nr - 1)
            let r0 = min(nr - 2, max(0, Int(rF)))
            let frac = Double(rF) - Double(r0)
            return field[z][r0] * (1 - frac) + field[z][min(r0 + 1, nr - 1)] * frac
        }

        // Sub-cell z interpolation for smoother gradients
        let zSubSteps = max(1, 2)  // 2 subdivisions per grid cell
        let subDz = dz / Float(zSubSteps)

        for z in 0..<nz {
            for zSub in 0..<zSubSteps {
                let zFrac0 = Float(zSub) / Float(zSubSteps)
                let zFrac1 = Float(zSub + 1) / Float(zSubSteps)
                let zIdx0 = z
                let zIdx1 = min(z + 1, nz - 1)
                let yT = pH / 2 - Float(z) * dz - zFrac0 * dz
                let yB = pH / 2 - Float(z) * dz - zFrac1 * dz
                let rT = rAt(z) + (rAt(z + 1) - rAt(z)) * zFrac0
                let rB = rAt(z) + (rAt(z + 1) - rAt(z)) * zFrac1

                for p in 0..<perpSteps {
                    let p0 = perpMin + Float(p) * perpD
                    let p1 = p0 + perpD
                    let pM = (p0 + p1) / 2
                    let distM = sqrt(clipPos * clipPos + pM * pM)
                    guard distM <= max(rT, rB) else { continue }

                    // Per-vertex field samples (bilinear + z interpolation)
                    let s00 = sample(zIdx0, p0, rAt(zIdx0))
                    let s01 = sample(zIdx0, p1, rAt(zIdx0))
                    let s10 = sample(zIdx1, p0, rAt(zIdx1))
                    let s11 = sample(zIdx1, p1, rAt(zIdx1))
                    let v_tl = s00 * Double(1 - zFrac0) + s10 * Double(zFrac0)
                    let v_tr = s01 * Double(1 - zFrac0) + s11 * Double(zFrac0)
                    let v_bl = s00 * Double(1 - zFrac1) + s10 * Double(zFrac1)
                    let v_br = s01 * Double(1 - zFrac1) + s11 * Double(zFrac1)

                    // Per-vertex grain noise (simulates coffee ground texture)
                    let g0 = (drand48() - 0.5) * grainIntensity
                    let g1 = (drand48() - 0.5) * grainIntensity
                    let g2 = (drand48() - 0.5) * grainIntensity
                    let g3 = (drand48() - 0.5) * grainIntensity
                    let c_tl = colorSIMD(v_tl + g0, mode: mode)
                    let c_tr = colorSIMD(v_tr + g1, mode: mode)
                    let c_bl = colorSIMD(v_bl + g2, mode: mode)
                    let c_br = colorSIMD(v_br + g3, mode: mode)

                    let b = UInt32(verts.count)
                    switch axis {
                    case .x:
                        verts += [SCNVector3(clipPos, yT, p0), SCNVector3(clipPos, yT, p1),
                                  SCNVector3(clipPos, yB, p1), SCNVector3(clipPos, yB, p0)]
                    case .z:
                        verts += [SCNVector3(p0, yT, clipPos), SCNVector3(p1, yT, clipPos),
                                  SCNVector3(p1, yB, clipPos), SCNVector3(p0, yB, clipPos)]
                    }
                    norms += [norm, norm, norm, norm]
                    cols += [c_tl, c_tr, c_br, c_bl]
                    idxs += [b, b+1, b+2, b, b+2, b+3]
                }
            }
        }
    }

    // MARK: - Basket Shell (headspace only — stops at puck top)

    private static func addBasketShell(
        to parent: SCNNode, puckHeight pH: Float,
        topR: Float, botR: Float, shellExtra: Float,
        rAt: (Int) -> Float, nz: Int,
        xC: Float, zC: Float, cutX: Double, cutZ: Double,
        tSeg: Int
    ) {
        let wall: Float = 0.018
        let shellTop = pH / 2 + shellExtra
        // Wall ONLY above the puck — no overlap with puck surface
        let wallH = shellExtra
        let nzW = max(4, Int(wallH / 0.01))
        let dzW = wallH / Float(nzW)
        let dT = Float(2.0 * .pi) / Float(tSeg)

        var vs: [SCNVector3] = [], ns: [SCNVector3] = [], ix: [UInt32] = []

        func addSQ(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3, n: SCNVector3) {
            let b = UInt32(vs.count)
            vs += [v0, v1, v2, v3]; ns += [n, n, n, n]
            ix += [b, b+1, b+2, b, b+2, b+3]
        }

        let rShell = topR + 0.002
        let rOut = rShell + wall

        // Headspace wall (from shellTop down to puckTop)
        for z in 0..<nzW {
            let yT = shellTop - Float(z) * dzW
            let yB = yT - dzW
            for t in 0..<tSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT, mid = (t0 + t1) / 2
                guard rOut * cos(mid) <= xC + wall || cutX >= 0.99 else { continue }
                guard rOut * sin(mid) <= zC + wall || cutZ >= 0.99 else { continue }
                // Outer face
                addSQ(SCNVector3(rOut*cos(t0), yT, rOut*sin(t0)),
                      SCNVector3(rOut*cos(t1), yT, rOut*sin(t1)),
                      SCNVector3(rOut*cos(t1), yB, rOut*sin(t1)),
                      SCNVector3(rOut*cos(t0), yB, rOut*sin(t0)),
                      n: SCNVector3(cos(mid), 0, sin(mid)))
                // Inner face
                addSQ(SCNVector3(rShell*cos(t1), yT, rShell*sin(t1)),
                      SCNVector3(rShell*cos(t0), yT, rShell*sin(t0)),
                      SCNVector3(rShell*cos(t0), yB, rShell*sin(t0)),
                      SCNVector3(rShell*cos(t1), yB, rShell*sin(t1)),
                      n: SCNVector3(-cos(mid), 0, -sin(mid)))
            }
        }

        // (Bottom screen now rendered by shared addScreenDisc helper)

        // Top annulus
        for t in 0..<tSeg {
            let t0 = Float(t) * dT, t1 = t0 + dT, mid = (t0 + t1) / 2
            guard rOut * cos(mid) <= xC + wall || cutX >= 0.99 else { continue }
            guard rOut * sin(mid) <= zC + wall || cutZ >= 0.99 else { continue }
            addSQ(SCNVector3(rShell*cos(t0), shellTop, rShell*sin(t0)),
                  SCNVector3(rOut*cos(t0), shellTop, rOut*sin(t0)),
                  SCNVector3(rOut*cos(t1), shellTop, rOut*sin(t1)),
                  SCNVector3(rShell*cos(t1), shellTop, rShell*sin(t1)),
                  n: SCNVector3(0, 1, 0))
        }

        let vSrc = SCNGeometrySource(vertices: vs)
        let nSrc = SCNGeometrySource(normals: ns)
        let el = SCNGeometryElement(indices: ix, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vSrc, nSrc], elements: [el])
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = pColor(0.72, 0.72, 0.75)
        mat.metalness.contents = 0.92
        mat.roughness.contents = 0.30
        geo.materials = [mat]
        parent.addChildNode(SCNNode(geometry: geo))
    }

    // MARK: - Geometry Assembly

    private static func buildGeometry(
        vertices: [SCNVector3], normals: [SCNVector3],
        colors: [SIMD4<Float>], indices: [UInt32]
    ) -> SCNGeometry {
        let vSrc = SCNGeometrySource(vertices: vertices)
        let nSrc = SCNGeometrySource(normals: normals)
        let cData = colors.withUnsafeBytes { Data($0) }
        let cSrc = SCNGeometrySource(
            data: cData, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let el = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [vSrc, nSrc, cSrc], elements: [el])
    }

    // MARK: - Screen Disc (shared: showerhead + basket screen)
    // Renders a metallic disc with concentric hole rings at the given y position.

    private static func addScreenDisc(
        to parent: SCNNode, y: Float, radius: Float,
        holeRings: Int, holesPerRing: Int, holeRadius: Float,
        xC: Float, zC: Float, cutX: Double, cutZ: Double,
        tSeg: Int, color: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) {
        var vs: [SCNVector3] = [], ns: [SCNVector3] = [], ix: [UInt32] = []
        let norm = SCNVector3(0, y > 0 ? 1 : -1, 0)

        func addSQ(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3) {
            let b = UInt32(vs.count)
            vs += [v0, v1, v2, v3]; ns += [norm, norm, norm, norm]
            ix += [b, b+1, b+2, b, b+2, b+3]
        }

        // Build set of hole center positions (ring, angle)
        var holeCenters: [(r: Float, theta: Float)] = []
        for ring in 1...holeRings {
            let ringR = Float(ring) / Float(holeRings + 1) * radius
            let nHoles = holesPerRing * ring / holeRings + max(4, holesPerRing / 3)
            for h in 0..<nHoles {
                let theta = Float(h) / Float(nHoles) * 2.0 * .pi
                holeCenters.append((r: ringR, theta: theta))
            }
        }

        let screenSeg = min(tSeg, 120)
        let rings = max(12, holeRings * 2)
        let dT = Float(2.0 * .pi) / Float(screenSeg)
        let dr = radius / Float(rings)
        let effHoleR = min(holeRadius, dr * 0.8)

        for ring in 0..<rings {
            let ri = Float(ring) * dr, ro = ri + dr
            let rm = (ri + ro) / 2
            for t in 0..<screenSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                guard rm * cos(mid) <= xC + 0.02 || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC + 0.02 || cutZ >= 0.99 else { continue }

                // Check if this cell overlaps any hole center
                let cellR = rm
                let cellTheta = mid
                var isHole = false
                for hc in holeCenters {
                    let dx = cellR * cos(cellTheta) - hc.r * cos(hc.theta)
                    let dz = cellR * sin(cellTheta) - hc.r * sin(hc.theta)
                    if sqrt(dx*dx + dz*dz) < effHoleR {
                        isHole = true
                        break
                    }
                }
                guard !isHole else { continue }

                if y > 0 {
                    // Top-facing (showerhead)
                    addSQ(SCNVector3(ri*cos(t0), y, ri*sin(t0)),
                          SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                          SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                          SCNVector3(ri*cos(t1), y, ri*sin(t1)))
                } else {
                    // Bottom-facing (basket screen)
                    addSQ(SCNVector3(ri*cos(t1), y, ri*sin(t1)),
                          SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                          SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                          SCNVector3(ri*cos(t0), y, ri*sin(t0)))
                }
            }
        }

        guard !vs.isEmpty else { return }
        let vSrc = SCNGeometrySource(vertices: vs)
        let nSrc = SCNGeometrySource(normals: ns)
        let el = SCNGeometryElement(indices: ix, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vSrc, nSrc], elements: [el])
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = pColor(color.r, color.g, color.b)
        mat.metalness.contents = 0.90
        mat.roughness.contents = 0.25
        mat.isDoubleSided = true
        geo.materials = [mat]
        parent.addChildNode(SCNNode(geometry: geo))
    }

    // MARK: - Basket Rim

    private static func addBasketRim(to parent: SCNNode, radius: Float, y: Float) {
        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.022)
        let m = SCNMaterial()
        m.diffuse.contents = pColor(0.75, 0.75, 0.78)
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.20; m.metalness.contents = 0.95
        torus.materials = [m]
        let n = SCNNode(geometry: torus); n.position = SCNVector3(0, y, 0)
        parent.addChildNode(n)
    }

    // MARK: - Lighting

    private static func addLighting(to root: SCNNode) {
        func light(_ type: SCNLight.LightType, _ intensity: CGFloat,
                    _ r: CGFloat, _ g: CGFloat, _ b: CGFloat,
                    pos: SCNVector3, shadow: Bool = false) {
            let n = SCNNode(); n.light = SCNLight()
            n.light?.type = type; n.light?.intensity = intensity
            n.light?.color = pColor(r, g, b)
            if shadow { n.light?.castsShadow = true; n.light?.shadowRadius = 4 }
            n.position = pos; n.look(at: SCNVector3(0, 0, 0))
            root.addChildNode(n)
        }
        let a = SCNNode(); a.light = SCNLight()
        a.light?.type = .ambient; a.light?.intensity = 400
        a.light?.color = pColor(0.80, 0.78, 0.75)
        root.addChildNode(a)

        light(.directional, 1000, 1.0, 0.97, 0.92, pos: SCNVector3(2, 3, 2))
        light(.directional, 350, 0.6, 0.7, 1.0, pos: SCNVector3(-2, 0.5, 1))
        light(.directional, 250, 0.5, 0.6, 1.0, pos: SCNVector3(0, -2, -1))
    }

    // MARK: - Labels

    private static func addLabel(to parent: SCNNode, text: String, position: SCNVector3) {
        let g = SCNText(string: text, extrusionDepth: 0)
        g.font = .systemFont(ofSize: 0.06, weight: .semibold); g.flatness = 0.05
        let m = SCNMaterial()
        m.diffuse.contents = pColor(1, 1, 1); m.transparency = 0.6
        m.lightingModel = .constant; g.materials = [m]
        let n = SCNNode(geometry: g)
        let (mn, mx) = n.boundingBox
        n.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2, 0, 0)
        n.position = position
        let b = SCNBillboardConstraint(); b.freeAxes = .all; n.constraints = [b]
        parent.addChildNode(n)
    }

    // MARK: - Animation Progress

    static func applyAnimationProgress(to field: [[Double]], progress: Double, mode: PuckVizMode) -> [[Double]] {
        guard progress < 1.0 else { return field }
        if mode == .permeability { return field }
        let nz = field.count; guard nz > 0 else { return field }
        let base: Double = 0.05
        let front = progress * Double(nz) / 0.65
        return field.enumerated().map { (z, row) in
            let zD = Double(z)
            if zD > front + 2.0 { return [Double](repeating: base, count: row.count) }
            let ts = max(0, front - zD) / Double(nz)
            let edge = zD <= front ? 1.0 : max(0, 1.0 - (zD - front) / 2.0)
            let ramp: Double
            switch mode {
            case .extraction: ramp = min(1.0, ts * 4.0)
            case .pressure:   ramp = min(1.0, ts * 6.0)
            default:          ramp = min(1.0, ts * 3.5)
            }
            return row.map { max(base, $0 * ramp * edge) }
        }
    }

    static func selectField(result: PuckSimulationResult, mode: PuckVizMode) -> [[Double]] {
        switch mode {
        case .pressure:     return result.pressureField
        case .flow:         return result.velocityField
        case .extraction:   return result.extractionField
        case .time:         return result.residenceTimeField
        case .permeability: return result.permeabilityField
        }
    }

    // MARK: - Fast Color (direct Float arithmetic, no UIColor/NSColor)

    static func colorSIMD(_ value: Double, mode: PuckVizMode) -> SIMD4<Float> {
        let t = Float(max(0, min(1, value)))
        let r: Float, g: Float, b: Float

        switch mode {
        case .pressure:
            if t < 0.25 {
                let f = t / 0.25
                r = 0; g = f * 0.5; b = 0.6 + f * 0.4
            } else if t < 0.5 {
                let f = (t - 0.25) / 0.25
                r = 0; g = 0.5 + f * 0.5; b = 1.0 - f * 0.5
            } else if t < 0.75 {
                let f = (t - 0.5) / 0.25
                r = f; g = 1.0; b = 0.5 - f * 0.5
            } else {
                let f = (t - 0.75) / 0.25
                r = 1.0; g = 1.0 - f * 0.7; b = 0
            }

        case .flow:
            if t < 0.2 {
                let f = t / 0.2
                r = 0.02; g = 0.02 + f * 0.15; b = 0.15 + f * 0.4
            } else if t < 0.4 {
                let f = (t - 0.2) / 0.2
                r = 0; g = 0.17 + f * 0.63; b = 0.55 + f * 0.45
            } else if t < 0.6 {
                let f = (t - 0.4) / 0.2
                r = f * 0.9; g = 0.8 + f * 0.2; b = 1.0 - f * 0.2
            } else if t < 0.8 {
                let f = (t - 0.6) / 0.2
                r = 0.9 + f * 0.1; g = 1.0 - f * 0.3; b = 0.8 - f * 0.8
            } else {
                let f = (t - 0.8) / 0.2
                r = 1.0; g = 0.7 - f * 0.5; b = 0
            }

        case .extraction:
            if t < 0.3 {
                let f = t / 0.3
                r = 0.05; g = 0.08 + f * 0.3; b = 0.05 + f * 0.1
            } else if t < 0.55 {
                let f = (t - 0.3) / 0.25
                r = 0.05 + f * 0.1; g = 0.38 + f * 0.52; b = 0.15 - f * 0.05
            } else if t < 0.75 {
                let f = (t - 0.55) / 0.2
                r = 0.15 + f * 0.85; g = 0.9 - f * 0.2; b = 0.1
            } else {
                let f = (t - 0.75) / 0.25
                r = 1.0; g = 0.7 - f * 0.55; b = 0.1 - f * 0.1
            }

        case .time:
            if t < 0.25 {
                let f = t / 0.25
                r = 0.05; g = 0.15 + f * 0.35; b = 0.5 + f * 0.3
            } else if t < 0.5 {
                let f = (t - 0.25) / 0.25
                r = 0.05 + f * 0.2; g = 0.5 + f * 0.3; b = 0.8 - f * 0.3
            } else if t < 0.75 {
                let f = (t - 0.5) / 0.25
                r = 0.25 + f * 0.65; g = 0.8 - f * 0.15; b = 0.5 - f * 0.35
            } else {
                let f = (t - 0.75) / 0.25
                r = 0.9 + f * 0.1; g = 0.65 - f * 0.45; b = 0.15 - f * 0.1
            }

        case .permeability:
            if t < 0.33 {
                let f = t / 0.33
                r = 0.15 + f * 0.05; g = 0.05 + f * 0.15; b = 0.25 + f * 0.35
            } else if t < 0.66 {
                let f = (t - 0.33) / 0.33
                r = 0.2 - f * 0.1; g = 0.2 + f * 0.45; b = 0.6 - f * 0.1
            } else {
                let f = (t - 0.66) / 0.34
                r = 0.1 + f * 0.3; g = 0.65 + f * 0.25; b = 0.5 - f * 0.25
            }
        }

        return SIMD4<Float>(r, g, b, 1.0)
    }

    static func pColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Any {
        #if canImport(UIKit)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
        #elseif canImport(AppKit)
        return NSColor(red: r, green: g, blue: b, alpha: 1)
        #endif
    }
}
