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
//  UIColor round-trip) for ~100K vertices per frame on M-series hardware.
//

import SwiftUI
import SceneKit

// MARK: - SwiftUI Wrapper

struct Puck3DSceneView: View {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    var animationProgress: Double = 1.0
    var cutX: Double = 0.55
    var cutZ: Double = 0.55

    var body: some View {
        PuckSceneRepresentable(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons,
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
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
        v.scene = scene
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        guard let root = v.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        root.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
    }
}
#elseif canImport(AppKit)
struct PuckSceneRepresentable: NSViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
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
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress))
        v.scene = scene
        return v
    }

    func updateNSView(_ v: SCNView, context: Context) {
        guard let root = v.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        root.addChildNode(PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
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
        cutX: Double, cutZ: Double,
        animationProgress: Double = 1.0
    ) -> SCNNode {
        let root = SCNNode()
        root.name = contentNodeName

        let nz = result.gridRows
        let nr = result.gridCols
        let isAnim = animationProgress < 1.0
        let thetaSeg = isAnim ? 120 : 180

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

        for z in 0..<nz {
            let valT = field[z][nr - 1]
            let valB = field[min(z + 1, nz - 1)][nr - 1]
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

        // MARK: Top face

        let rTO = rAt(0)
        for r in 0..<nr {
            let c = colorSIMD(field[0][r], mode: mode)
            let ri = Float(r) / Float(nr) * rTO
            let ro = Float(r + 1) / Float(nr) * rTO
            let y = pH / 2
            for t in 0..<thetaSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                let rm = (ri + ro) / 2
                guard rm * cos(mid) <= xC || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC || cutZ >= 0.99 else { continue }
                addQ(SCNVector3(ri*cos(t0), y, ri*sin(t0)),
                     SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                     SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                     SCNVector3(ri*cos(t1), y, ri*sin(t1)),
                     n: SCNVector3(0, 1, 0), c: c)
            }
        }

        // MARK: Bottom face

        let rBO = rAt(nz)
        for r in 0..<nr {
            let c = colorSIMD(field[nz - 1][r], mode: mode)
            let ri = Float(r) / Float(nr) * rBO
            let ro = Float(r + 1) / Float(nr) * rBO
            let y = -pH / 2
            for t in 0..<thetaSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT
                let mid = (t0 + t1) / 2
                let rm = (ri + ro) / 2
                guard rm * cos(mid) <= xC || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC || cutZ >= 0.99 else { continue }
                addQ(SCNVector3(ri*cos(t1), y, ri*sin(t1)),
                     SCNVector3(ro*cos(t1), y, ro*sin(t1)),
                     SCNVector3(ro*cos(t0), y, ro*sin(t0)),
                     SCNVector3(ri*cos(t0), y, ri*sin(t0)),
                     n: SCNVector3(0, -1, 0), c: c)
            }
        }

        // MARK: Clip faces — bilinear interpolated colors + subtle grain noise

        if cutX < 0.99 {
            addClipFace(clipPos: xC, axis: .x, otherClipPos: zC, otherCut: cutZ,
                        nz: nz, nr: nr, field: field, mode: mode,
                        pH: pH, dz: dz, topR: topR, rAt: rAt,
                        verts: &verts, norms: &norms, cols: &cols, idxs: &idxs)
        }
        if cutZ < 0.99 {
            addClipFace(clipPos: zC, axis: .z, otherClipPos: xC, otherCut: cutX,
                        nz: nz, nr: nr, field: field, mode: mode,
                        pH: pH, dz: dz, topR: topR, rAt: rAt,
                        verts: &verts, norms: &norms, cols: &cols, idxs: &idxs)
        }

        // Build puck node with coffee-like material
        let puckGeo = buildGeometry(vertices: verts, normals: norms, colors: cols, indices: idxs)
        let puckMat = SCNMaterial()
        puckMat.lightingModel = .physicallyBased
        puckMat.roughness.contents = 0.88   // matte like tamped coffee
        puckMat.metalness.contents = 0.02   // non-metallic organic surface
        puckGeo.materials = [puckMat]
        root.addChildNode(SCNNode(geometry: puckGeo))

        // MARK: Basket shell — headspace wall only (above puck)
        let shellExtra: Float = pH * 0.25
        addBasketShell(to: root, puckHeight: pH, topR: topR, botR: botR,
                       shellExtra: shellExtra, rAt: rAt,
                       xC: xC, zC: zC, cutX: cutX, cutZ: cutZ, tSeg: thetaSeg)
        addBasketRim(to: root, radius: topR + 0.04, y: pH / 2 + shellExtra)

        // Decorations (skip during animation)
        if (cutX < 0.99 || cutZ < 0.99) && !isAnim {
            addGrindParticles(to: root, nz: nz, nr: nr, pH: pH, rAt: rAt,
                              grind: grindSizeMicrons, field: field, mode: mode,
                              xC: xC, zC: zC, cutX: cutX, cutZ: cutZ)
            addFlowStreamlines(to: root, result: result, pH: pH, rAt: rAt,
                               xC: xC, zC: zC, cutX: cutX, cutZ: cutZ)
        }

        addLabel(to: root, text: "Water In  \u{2193}",
                 position: SCNVector3(0, pH / 2 + shellExtra + 0.1, 0.3))
        addLabel(to: root, text: "\u{2191}  Basket Exit",
                 position: SCNVector3(0, -pH / 2 - 0.15, 0.3))

        return root
    }

    // MARK: - Clip Face (bilinear interpolated)

    enum ClipAxis { case x, z }

    private static func addClipFace(
        clipPos: Float, axis: ClipAxis,
        otherClipPos: Float, otherCut: Double,
        nz: Int, nr: Int, field: [[Double]], mode: PuckVizMode,
        pH: Float, dz: Float, topR: Float, rAt: (Int) -> Float,
        verts: inout [SCNVector3], norms: inout [SCNVector3],
        cols: inout [SIMD4<Float>], idxs: inout [UInt32]
    ) {
        let norm: SCNVector3 = axis == .x ? SCNVector3(1, 0, 0) : SCNVector3(0, 0, 1)
        let perpSteps = max(nr, 120)
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

        for z in 0..<nz {
            let zB = min(z + 1, nz - 1)
            let yT = pH / 2 - Float(z) * dz
            let yB = yT - dz
            let rT = rAt(z), rB = rAt(z + 1)

            for p in 0..<perpSteps {
                let p0 = perpMin + Float(p) * perpD
                let p1 = p0 + perpD
                let pM = (p0 + p1) / 2
                let distM = sqrt(clipPos * clipPos + pM * pM)
                guard distM <= max(rT, rB) else { continue }

                // Per-vertex field samples (bilinear)
                let v_tl = sample(z,  p0, rT)
                let v_tr = sample(z,  p1, rT)
                let v_bl = sample(zB, p0, rB)
                let v_br = sample(zB, p1, rB)

                // Subtle grain noise for coffee texture
                let grain = (drand48() - 0.5) * 0.06
                let c_tl = colorSIMD(v_tl + grain, mode: mode)
                let c_tr = colorSIMD(v_tr + grain, mode: mode)
                let c_bl = colorSIMD(v_bl + grain, mode: mode)
                let c_br = colorSIMD(v_br + grain, mode: mode)

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

    // MARK: - Basket Shell (headspace only — not alongside puck)

    private static func addBasketShell(
        to parent: SCNNode, puckHeight pH: Float,
        topR: Float, botR: Float, shellExtra: Float,
        rAt: (Int) -> Float,
        xC: Float, zC: Float, cutX: Double, cutZ: Double,
        tSeg: Int
    ) {
        let wall: Float = 0.018
        let shellTop = pH / 2 + shellExtra
        let puckTop = pH / 2
        // Only render wall ABOVE the puck (headspace region)
        let wallH = shellExtra + 0.002
        let nzW = 6
        let dzW = wallH / Float(nzW)
        let dT = Float(2.0 * .pi) / Float(tSeg)

        var vs: [SCNVector3] = [], ns: [SCNVector3] = [], ix: [UInt32] = []

        func addSQ(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3, n: SCNVector3) {
            let b = UInt32(vs.count)
            vs += [v0, v1, v2, v3]; ns += [n, n, n, n]
            ix += [b, b+1, b+2, b, b+2, b+3]
        }

        // Shell radius follows top of basket (no taper in headspace)
        let rShell = topR + 0.002
        let rOut = rShell + wall

        // Headspace wall
        for z in 0..<nzW {
            let yT = shellTop - Float(z) * dzW
            let yB = yT - dzW
            for t in 0..<tSeg {
                let t0 = Float(t) * dT, t1 = t0 + dT, mid = (t0 + t1) / 2
                guard rOut * cos(mid) <= xC + wall || cutX >= 0.99 else { continue }
                guard rOut * sin(mid) <= zC + wall || cutZ >= 0.99 else { continue }
                addSQ(SCNVector3(rOut*cos(t0), yT, rOut*sin(t0)),
                      SCNVector3(rOut*cos(t1), yT, rOut*sin(t1)),
                      SCNVector3(rOut*cos(t1), yB, rOut*sin(t1)),
                      SCNVector3(rOut*cos(t0), yB, rOut*sin(t0)),
                      n: SCNVector3(cos(mid), 0, sin(mid)))
                addSQ(SCNVector3(rShell*cos(t1), yT, rShell*sin(t1)),
                      SCNVector3(rShell*cos(t0), yT, rShell*sin(t0)),
                      SCNVector3(rShell*cos(t0), yB, rShell*sin(t0)),
                      SCNVector3(rShell*cos(t1), yB, rShell*sin(t1)),
                      n: SCNVector3(-cos(mid), 0, -sin(mid)))
            }
        }

        // Bottom screen under the puck
        let rBot = rAt(Int(pH / (pH / Float(128)) + 0.5)) + 0.002  // approximate bottom radius
        let yScreen = -pH / 2 - 0.005
        let screenSeg = min(tSeg, 80)
        let sDT = Float(2.0 * .pi) / Float(screenSeg)
        let rings = 12
        let sDr = rBot / Float(rings)
        for ring in 0..<rings {
            let ri = Float(ring) * sDr, ro = ri + sDr
            for t in 0..<screenSeg {
                let t0 = Float(t) * sDT, t1 = t0 + sDT, mid = (t0 + t1) / 2
                let rm = (ri + ro) / 2
                guard rm * cos(mid) <= xC + wall || cutX >= 0.99 else { continue }
                guard rm * sin(mid) <= zC + wall || cutZ >= 0.99 else { continue }
                addSQ(SCNVector3(ri*cos(t0), yScreen, ri*sin(t0)),
                      SCNVector3(ro*cos(t0), yScreen, ro*sin(t0)),
                      SCNVector3(ro*cos(t1), yScreen, ro*sin(t1)),
                      SCNVector3(ri*cos(t1), yScreen, ri*sin(t1)),
                      n: SCNVector3(0, -1, 0))
            }
        }

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

    // MARK: - Grind Particles

    private static func addGrindParticles(
        to parent: SCNNode, nz: Int, nr: Int,
        pH: Float, rAt: (Int) -> Float,
        grind: Double, field: [[Double]], mode: PuckVizMode,
        xC: Float, zC: Float, cutX: Double, cutZ: Double
    ) {
        let pr = CGFloat(max(0.005, grind / 400.0 * 0.010))
        let sphere = SCNSphere(radius: pr); sphere.segmentCount = 8
        let dzP = pH / Float(nz)
        let sZ = max(1, nz / 14), sR = max(1, nr / 10)
        srand48(123)

        for face in 0..<2 {
            let isX = face == 0
            guard (isX ? cutX : cutZ) < 0.99 else { continue }
            let clip = isX ? xC : zC
            let oc = isX ? zC : xC, ocut = isX ? cutZ : cutX

            for z in stride(from: sZ / 2, to: nz, by: sZ) {
                let rM = rAt(z)
                for r in stride(from: sR / 2, to: nr, by: sR) {
                    let rP = (Float(r) + Float(drand48()) * 0.5) / Float(nr) * rM
                    let dist = sqrt(clip * clip + rP * rP)
                    guard dist <= rM, rP <= oc || ocut >= 0.99 else { continue }
                    let col = colorSIMD(field[z][r], mode: mode)
                    let yP = pH / 2 - (Float(z) + Float(drand48()) * 0.5) * dzP
                    let j = Float(drand48() - 0.5) * 0.008
                    let m = SCNMaterial()
                    m.diffuse.contents = pColor(CGFloat(col.x)*0.7, CGFloat(col.y)*0.7, CGFloat(col.z)*0.7)
                    m.lightingModel = .physicallyBased; m.roughness.contents = 0.92
                    sphere.materials = [m]
                    let n = SCNNode(geometry: sphere.copy() as? SCNGeometry ?? sphere)
                    n.position = isX ? SCNVector3(clip+j, yP, rP) : SCNVector3(rP, yP, clip+j)
                    parent.addChildNode(n)
                }
            }
        }
    }

    // MARK: - Flow Streamlines

    private static func addFlowStreamlines(
        to parent: SCNNode, result: PuckSimulationResult,
        pH: Float, rAt: (Int) -> Float,
        xC: Float, zC: Float, cutX: Double, cutZ: Double
    ) {
        let nz = result.gridRows, nr = result.gridCols
        let dzF = pH / Float(nz)
        let vF = result.velocityField
        let pMax = result.grid.flatMap { $0 }.map { $0.flowMagnitude }.max() ?? 1e-10
        let maxL = dzF * 2.5
        let sZ = max(1, nz / 10), sR = max(1, nr / 6)

        for face in 0..<2 {
            let isX = face == 0
            guard (isX ? cutX : cutZ) < 0.99 else { continue }
            let clip = isX ? xC : zC
            let oc = isX ? zC : xC, ocut = isX ? cutZ : cutX

            for z in stride(from: sZ / 2, to: nz, by: sZ) {
                let rM = rAt(z)
                for r in stride(from: sR / 2, to: nr, by: sR) {
                    let nv = Float(vF[z][r]); guard nv > 0.05 else { continue }
                    let rP = (Float(r) + 0.5) / Float(nr) * rM
                    let dist = sqrt(clip * clip + rP * rP)
                    guard dist <= rM, rP <= oc || ocut >= 0.99 else { continue }
                    let cell = result.grid[z][r]
                    let yP = pH / 2 - (Float(z) + 0.5) * dzF
                    let aL = max(0.005, nv * maxL)
                    let vr = Float(cell.velocityR / pMax)
                    let vz = Float(-cell.velocityZ / pMax)
                    guard sqrt(vr*vr + vz*vz) > 1e-6 else { continue }
                    let ang = atan2(vz, vr)
                    let cyl = SCNCylinder(radius: 0.0015, height: CGFloat(aL))
                    let m = SCNMaterial()
                    m.diffuse.contents = pColor(1, 1, 1)
                    m.transparency = CGFloat(0.25 + nv * 0.5)
                    m.lightingModel = .constant; cyl.materials = [m]
                    let nd = SCNNode(geometry: cyl)
                    if isX {
                        nd.position = SCNVector3(clip, yP + sin(ang)*aL*0.5, rP + cos(ang)*aL*0.5)
                        nd.eulerAngles.x = ang - .pi/2
                    } else {
                        nd.position = SCNVector3(rP + cos(ang)*aL*0.5, yP + sin(ang)*aL*0.5, clip)
                        nd.eulerAngles.z = ang - .pi/2
                    }
                    parent.addChildNode(nd)
                }
            }
        }
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
        a.light?.color = pColor(0.80, 0.78, 0.75) // warm ambient
        root.addChildNode(a)

        light(.directional, 1000, 1.0, 0.97, 0.92, pos: SCNVector3(2, 3, 2), shadow: true)
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
