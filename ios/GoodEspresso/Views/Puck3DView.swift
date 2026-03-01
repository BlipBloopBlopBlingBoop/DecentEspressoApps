//
//  Puck3DView.swift
//  Good Espresso
//
//  Interactive 3D puck visualization using SceneKit.
//  Renders CFD simulation as a cutaway cylinder with per-cell coloring,
//  accurate tapered basket geometry, metallic basket shell, grind particle
//  indicators, and orbit camera.
//
//  Cutaway uses two orthogonal Cartesian clip planes (X and Z).
//  The SCNScene is created once and persists across updates — only the
//  content node is swapped — so the camera controller's zoom/orbit state
//  is never lost during animation playback.
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
            result: result,
            mode: mode,
            basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons,
            cutX: cutX,
            cutZ: cutZ,
            animationProgress: animationProgress
        )
    }
}

// MARK: - Platform Representables
//
// The SCNScene is created once in makeUIView/makeNSView. On subsequent
// updates only the "puckContent" child node is removed and re-added,
// so the SCNView camera controller state (orbit, zoom) persists.

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
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        scnView.antialiasingMode = .multisampling4X

        let scene = PuckSceneBuilder.makeSceneShell()
        let content = PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        scene.rootNode.addChildNode(content)
        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let root = scnView.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        let content = PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        root.addChildNode(content)
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
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor
        scnView.antialiasingMode = .multisampling4X

        let scene = PuckSceneBuilder.makeSceneShell()
        let content = PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        scene.rootNode.addChildNode(content)
        scnView.scene = scene
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        guard let root = scnView.scene?.rootNode else { return }
        root.childNode(withName: PuckSceneBuilder.contentNodeName, recursively: false)?.removeFromParentNode()
        let content = PuckSceneBuilder.buildContentNode(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        root.addChildNode(content)
    }
}
#endif

// MARK: - Scene Builder

enum PuckSceneBuilder {

    static let contentNodeName = "puckContent"

    // MARK: Persistent scene shell (camera + lights — created once)

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

    // MARK: Content node (rebuilt each update)

    static func buildContentNode(
        result: PuckSimulationResult,
        mode: PuckVizMode,
        basketSpec: BasketSpec,
        grindSizeMicrons: Double,
        cutX: Double,
        cutZ: Double,
        animationProgress: Double = 1.0
    ) -> SCNNode {
        let root = SCNNode()
        root.name = contentNodeName

        let nz = result.gridRows
        let nr = result.gridCols
        let isAnimating = animationProgress < 1.0
        let thetaSegments = isAnimating ? 120 : 180

        let rawField = selectField(result: result, mode: mode)
        let field = applyAnimationProgress(to: rawField, progress: animationProgress, mode: mode)

        // Basket geometry
        let topRadius: Float = 1.0
        let taperRatio: Float = basketSpec.hasBackPressureValve ? 0.96 : 0.93
        let bottomRadius: Float = topRadius * taperRatio
        let lipFlare: Float = 0.03

        let puckHeight: Float = Float(basketSpec.depth / basketSpec.diameter) * 2.0
        let dz = puckHeight / Float(nz)

        let xClip = Float(cutX) * topRadius
        let zClip = Float(cutZ) * topRadius

        // MARK: Build puck mesh

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var indices: [UInt32] = []

        func addQuad(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                     normal: SCNVector3, color: SIMD4<Float>) {
            let base = UInt32(vertices.count)
            vertices.append(contentsOf: [v0, v1, v2, v3])
            normals.append(contentsOf: [normal, normal, normal, normal])
            colors.append(contentsOf: [color, color, color, color])
            indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
        }

        func radiusAt(zIndex: Int) -> Float {
            let zFrac = Float(zIndex) / Float(nz)
            let lip: Float = zFrac < 0.15 ? lipFlare * (1.0 - zFrac / 0.15) : 0
            return topRadius + (bottomRadius - topRadius) * zFrac + lip
        }

        let dTheta = Float(2.0 * .pi) / Float(thetaSegments)

        // Outer surface
        for z in 0..<nz {
            let r = nr - 1
            let val = field[z][r]
            let col = colorSIMD(val, mode: mode)
            let yTop = puckHeight / 2 - Float(z) * dz
            let yBot = yTop - dz
            let rTop = radiusAt(zIndex: z)
            let rBot = radiusAt(zIndex: z + 1)

            for t in 0..<thetaSegments {
                let theta0 = Float(t) * dTheta
                let theta1 = theta0 + dTheta
                let midTheta = (theta0 + theta1) / 2
                let xMid = rTop * cos(midTheta)
                let zMid = rTop * sin(midTheta)
                guard xMid <= xClip || cutX >= 0.99 else { continue }
                guard zMid <= zClip || cutZ >= 0.99 else { continue }

                addQuad(
                    SCNVector3(rTop * cos(theta0), yTop, rTop * sin(theta0)),
                    SCNVector3(rTop * cos(theta1), yTop, rTop * sin(theta1)),
                    SCNVector3(rBot * cos(theta1), yBot, rBot * sin(theta1)),
                    SCNVector3(rBot * cos(theta0), yBot, rBot * sin(theta0)),
                    normal: SCNVector3(cos(midTheta), 0, sin(midTheta)),
                    color: col
                )
            }
        }

        // Top face
        let rTopOuter = radiusAt(zIndex: 0)
        for r in 0..<nr {
            let val = field[0][r]
            let col = colorSIMD(val, mode: mode)
            let rInner = Float(r) / Float(nr) * rTopOuter
            let rOuter = Float(r + 1) / Float(nr) * rTopOuter
            let y = puckHeight / 2
            for t in 0..<thetaSegments {
                let theta0 = Float(t) * dTheta
                let theta1 = theta0 + dTheta
                let midTheta = (theta0 + theta1) / 2
                let rMid = (rInner + rOuter) / 2
                let xMid = rMid * cos(midTheta)
                let zMid = rMid * sin(midTheta)
                guard xMid <= xClip || cutX >= 0.99 else { continue }
                guard zMid <= zClip || cutZ >= 0.99 else { continue }

                addQuad(
                    SCNVector3(rInner * cos(theta0), y, rInner * sin(theta0)),
                    SCNVector3(rOuter * cos(theta0), y, rOuter * sin(theta0)),
                    SCNVector3(rOuter * cos(theta1), y, rOuter * sin(theta1)),
                    SCNVector3(rInner * cos(theta1), y, rInner * sin(theta1)),
                    normal: SCNVector3(0, 1, 0),
                    color: col
                )
            }
        }

        // Bottom face
        let rBotOuter = radiusAt(zIndex: nz)
        for r in 0..<nr {
            let val = field[nz - 1][r]
            let col = colorSIMD(val, mode: mode)
            let rInner = Float(r) / Float(nr) * rBotOuter
            let rOuter = Float(r + 1) / Float(nr) * rBotOuter
            let y = -puckHeight / 2
            for t in 0..<thetaSegments {
                let theta0 = Float(t) * dTheta
                let theta1 = theta0 + dTheta
                let midTheta = (theta0 + theta1) / 2
                let rMid = (rInner + rOuter) / 2
                let xMid = rMid * cos(midTheta)
                let zMid = rMid * sin(midTheta)
                guard xMid <= xClip || cutX >= 0.99 else { continue }
                guard zMid <= zClip || cutZ >= 0.99 else { continue }

                addQuad(
                    SCNVector3(rInner * cos(theta1), y, rInner * sin(theta1)),
                    SCNVector3(rOuter * cos(theta1), y, rOuter * sin(theta1)),
                    SCNVector3(rOuter * cos(theta0), y, rOuter * sin(theta0)),
                    SCNVector3(rInner * cos(theta0), y, rInner * sin(theta0)),
                    normal: SCNVector3(0, -1, 0),
                    color: col
                )
            }
        }

        // Clip-plane cross-section faces
        if cutX < 0.99 {
            addClipFace(clipPos: xClip, axis: .x, otherClipPos: zClip, otherCutVal: cutZ,
                        nz: nz, nr: nr, field: field, mode: mode,
                        puckHeight: puckHeight, dz: dz, topRadius: topRadius, radiusAt: radiusAt,
                        vertices: &vertices, normals: &normals, colors: &colors, indices: &indices)
        }
        if cutZ < 0.99 {
            addClipFace(clipPos: zClip, axis: .z, otherClipPos: xClip, otherCutVal: cutX,
                        nz: nz, nr: nr, field: field, mode: mode,
                        puckHeight: puckHeight, dz: dz, topRadius: topRadius, radiusAt: radiusAt,
                        vertices: &vertices, normals: &normals, colors: &colors, indices: &indices)
        }

        // Puck geometry node
        let puckNode = SCNNode(geometry: buildGeometry(
            vertices: vertices, normals: normals, colors: colors, indices: indices
        ))
        root.addChildNode(puckNode)

        // Basket shell
        let shellExtraTop: Float = puckHeight * 0.25
        addBasketShell(to: root, nz: nz, puckHeight: puckHeight,
                       topRadius: topRadius, bottomRadius: bottomRadius,
                       shellExtraTop: shellExtraTop,
                       xClip: xClip, zClip: zClip,
                       cutX: cutX, cutZ: cutZ, thetaSegments: thetaSegments)

        // Basket rim torus at top of shell
        addBasketRim(to: root, radius: topRadius + 0.04,
                     y: puckHeight / 2 + shellExtraTop)

        // Grind particles & streamlines — skip during animation
        if (cutX < 0.99 || cutZ < 0.99) && !isAnimating {
            addGrindParticles(to: root, nz: nz, nr: nr,
                              puckHeight: puckHeight, radiusAt: radiusAt,
                              grindMicrons: grindSizeMicrons, field: field, mode: mode,
                              xClip: xClip, zClip: zClip, cutX: cutX, cutZ: cutZ)
            addFlowStreamlines(to: root, result: result,
                               puckHeight: puckHeight, radiusAt: radiusAt,
                               xClip: xClip, zClip: zClip, cutX: cutX, cutZ: cutZ)
        }

        // Labels
        addLabel(to: root, text: "Water In  \u{2193}",
                 position: SCNVector3(0, puckHeight / 2 + shellExtraTop + 0.1, 0.3))
        addLabel(to: root, text: "\u{2191}  Basket Exit",
                 position: SCNVector3(0, -puckHeight / 2 - 0.15, 0.3))

        return root
    }

    // MARK: - Clip Axis

    enum ClipAxis { case x, z }

    // MARK: - Clip Face

    private static func addClipFace(
        clipPos: Float, axis: ClipAxis,
        otherClipPos: Float, otherCutVal: Double,
        nz: Int, nr: Int, field: [[Double]], mode: PuckVizMode,
        puckHeight: Float, dz: Float, topRadius: Float,
        radiusAt: (Int) -> Float,
        vertices: inout [SCNVector3], normals: inout [SCNVector3],
        colors: inout [SIMD4<Float>], indices: inout [UInt32]
    ) {
        let normal: SCNVector3
        switch axis {
        case .x: normal = SCNVector3(1, 0, 0)
        case .z: normal = SCNVector3(0, 0, 1)
        }

        let perpSteps = nr
        let rMax = topRadius
        let perpMax = otherCutVal >= 0.99 ? rMax : otherClipPos
        let perpMin: Float = -rMax
        let perpD = (perpMax - perpMin) / Float(perpSteps)

        for z in 0..<nz {
            let yTop = puckHeight / 2 - Float(z) * dz
            let yBot = yTop - dz
            let localR = radiusAt(z)

            for p in 0..<perpSteps {
                let perp0 = perpMin + Float(p) * perpD
                let perp1 = perp0 + perpD
                let perpMid = (perp0 + perp1) / 2

                let distFromCenter = sqrt(clipPos * clipPos + perpMid * perpMid)
                guard distFromCenter <= localR else { continue }

                let rNorm = distFromCenter / localR
                let rIdx = min(nr - 1, max(0, Int(rNorm * Float(nr))))
                let val = field[z][rIdx]
                let col = colorSIMD(val, mode: mode)

                let base = UInt32(vertices.count)
                switch axis {
                case .x:
                    vertices.append(contentsOf: [
                        SCNVector3(clipPos, yTop, perp0),
                        SCNVector3(clipPos, yTop, perp1),
                        SCNVector3(clipPos, yBot, perp1),
                        SCNVector3(clipPos, yBot, perp0),
                    ])
                case .z:
                    vertices.append(contentsOf: [
                        SCNVector3(perp0, yTop, clipPos),
                        SCNVector3(perp1, yTop, clipPos),
                        SCNVector3(perp1, yBot, clipPos),
                        SCNVector3(perp0, yBot, clipPos),
                    ])
                }
                normals.append(contentsOf: [normal, normal, normal, normal])
                colors.append(contentsOf: [col, col, col, col])
                indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
            }
        }
    }

    // MARK: - Basket Shell

    private static func addBasketShell(
        to parent: SCNNode, nz: Int, puckHeight: Float,
        topRadius: Float, bottomRadius: Float,
        shellExtraTop: Float,
        xClip: Float, zClip: Float,
        cutX: Double, cutZ: Double,
        thetaSegments: Int
    ) {
        let wallThickness: Float = 0.018
        let shellBottom: Float = -puckHeight / 2 - 0.005
        let shellTop: Float = puckHeight / 2 + shellExtraTop
        let totalShellH = shellTop - shellBottom
        let nzShell = 20
        let dzShell = totalShellH / Float(nzShell)
        let dTheta = Float(2.0 * .pi) / Float(thetaSegments)

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var idxs: [UInt32] = []

        func addQ(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                  n: SCNVector3) {
            let base = UInt32(verts.count)
            verts.append(contentsOf: [v0, v1, v2, v3])
            norms.append(contentsOf: [n, n, n, n])
            idxs.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
        }

        func shellR(y: Float) -> Float {
            if y >= puckHeight / 2 { return topRadius + 0.002 }
            if y <= -puckHeight / 2 { return bottomRadius + 0.002 }
            let zFrac = (puckHeight / 2 - y) / puckHeight
            let lip: Float = zFrac < 0.15 ? 0.03 * (1.0 - zFrac / 0.15) : 0
            return topRadius + (bottomRadius - topRadius) * zFrac + lip + 0.002
        }

        // Wall
        for z in 0..<nzShell {
            let yT = shellTop - Float(z) * dzShell
            let yB = yT - dzShell
            let rI0 = shellR(y: yT); let rO0 = rI0 + wallThickness
            let rI1 = shellR(y: yB); let rO1 = rI1 + wallThickness

            for t in 0..<thetaSegments {
                let t0 = Float(t) * dTheta
                let t1 = t0 + dTheta
                let mid = (t0 + t1) / 2
                let xM = rO0 * cos(mid), zM = rO0 * sin(mid)
                guard xM <= xClip + wallThickness || cutX >= 0.99 else { continue }
                guard zM <= zClip + wallThickness || cutZ >= 0.99 else { continue }

                // Outer
                addQ(SCNVector3(rO0*cos(t0), yT, rO0*sin(t0)),
                     SCNVector3(rO0*cos(t1), yT, rO0*sin(t1)),
                     SCNVector3(rO1*cos(t1), yB, rO1*sin(t1)),
                     SCNVector3(rO1*cos(t0), yB, rO1*sin(t0)),
                     n: SCNVector3(cos(mid), 0, sin(mid)))
                // Inner
                addQ(SCNVector3(rI0*cos(t1), yT, rI0*sin(t1)),
                     SCNVector3(rI0*cos(t0), yT, rI0*sin(t0)),
                     SCNVector3(rI1*cos(t0), yB, rI1*sin(t0)),
                     SCNVector3(rI1*cos(t1), yB, rI1*sin(t1)),
                     n: SCNVector3(-cos(mid), 0, -sin(mid)))
            }
        }

        // Bottom screen
        let rBot = shellR(y: -puckHeight / 2)
        let sSegs = min(thetaSegments, 80)
        let sDT = Float(2.0 * .pi) / Float(sSegs)
        let rings = 12
        let sDr = rBot / Float(rings)

        for ring in 0..<rings {
            let rIn = Float(ring) * sDr, rOut = rIn + sDr
            for t in 0..<sSegs {
                let t0 = Float(t) * sDT, t1 = t0 + sDT
                let mid = (t0 + t1) / 2, rM = (rIn + rOut) / 2
                guard rM * cos(mid) <= xClip + wallThickness || cutX >= 0.99 else { continue }
                guard rM * sin(mid) <= zClip + wallThickness || cutZ >= 0.99 else { continue }
                addQ(SCNVector3(rIn*cos(t0), shellBottom, rIn*sin(t0)),
                     SCNVector3(rOut*cos(t0), shellBottom, rOut*sin(t0)),
                     SCNVector3(rOut*cos(t1), shellBottom, rOut*sin(t1)),
                     SCNVector3(rIn*cos(t1), shellBottom, rIn*sin(t1)),
                     n: SCNVector3(0, -1, 0))
            }
        }

        // Top annulus
        let rRI = shellR(y: shellTop), rRO = rRI + wallThickness
        for t in 0..<thetaSegments {
            let t0 = Float(t) * dTheta, t1 = t0 + dTheta
            let mid = (t0 + t1) / 2
            guard rRO * cos(mid) <= xClip + wallThickness || cutX >= 0.99 else { continue }
            guard rRO * sin(mid) <= zClip + wallThickness || cutZ >= 0.99 else { continue }
            addQ(SCNVector3(rRI*cos(t0), shellTop, rRI*sin(t0)),
                 SCNVector3(rRO*cos(t0), shellTop, rRO*sin(t0)),
                 SCNVector3(rRO*cos(t1), shellTop, rRO*sin(t1)),
                 SCNVector3(rRI*cos(t1), shellTop, rRI*sin(t1)),
                 n: SCNVector3(0, 1, 0))
        }

        let vertexSource = SCNGeometrySource(vertices: verts)
        let normalSource = SCNGeometrySource(normals: norms)
        let element = SCNGeometryElement(indices: idxs, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

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
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let colorData = colors.withUnsafeBytes { Data($0) }
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 0.65
        mat.metalness.contents = 0.05
        geo.materials = [mat]
        return geo
    }

    // MARK: - Basket Rim

    private static func addBasketRim(to parent: SCNNode, radius: Float, y: Float) {
        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.022)
        let mat = SCNMaterial()
        mat.diffuse.contents = pColor(0.75, 0.75, 0.78)
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 0.20
        mat.metalness.contents = 0.95
        torus.materials = [mat]
        let node = SCNNode(geometry: torus)
        node.position = SCNVector3(0, y, 0)
        parent.addChildNode(node)
    }

    // MARK: - Grind Particles

    private static func addGrindParticles(
        to parent: SCNNode, nz: Int, nr: Int,
        puckHeight: Float, radiusAt: (Int) -> Float,
        grindMicrons: Double, field: [[Double]], mode: PuckVizMode,
        xClip: Float, zClip: Float, cutX: Double, cutZ: Double
    ) {
        let particleR = CGFloat(max(0.005, grindMicrons / 400.0 * 0.010))
        let sphere = SCNSphere(radius: particleR)
        sphere.segmentCount = 8
        let dzP = puckHeight / Float(nz)
        let stepZ = max(1, nz / 14), stepR = max(1, nr / 10)

        srand48(123)
        for face in 0..<2 {
            let isX = face == 0
            guard (isX ? cutX : cutZ) < 0.99 else { continue }
            let clip = isX ? xClip : zClip
            let otherClip = isX ? zClip : xClip
            let otherCut = isX ? cutZ : cutX

            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let rPos = (Float(r) + Float(drand48()) * 0.5) / Float(nr) * rMax
                    let dist = sqrt(clip * clip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= otherClip || otherCut >= 0.99 else { continue }

                    let val = field[z][r]
                    let col = colorSIMD(val, mode: mode)
                    let yPos = puckHeight / 2 - (Float(z) + Float(drand48()) * 0.5) * dzP
                    let jitter = Float(drand48() - 0.5) * 0.008

                    let mat = SCNMaterial()
                    mat.diffuse.contents = pColor(CGFloat(col.x) * 0.7, CGFloat(col.y) * 0.7, CGFloat(col.z) * 0.7)
                    mat.lightingModel = .physicallyBased
                    mat.roughness.contents = 0.9
                    sphere.materials = [mat]

                    let node = SCNNode(geometry: sphere.copy() as? SCNGeometry ?? sphere)
                    node.position = isX
                        ? SCNVector3(clip + jitter, yPos, rPos)
                        : SCNVector3(rPos, yPos, clip + jitter)
                    parent.addChildNode(node)
                }
            }
        }
    }

    // MARK: - Flow Streamlines

    private static func addFlowStreamlines(
        to parent: SCNNode, result: PuckSimulationResult,
        puckHeight: Float, radiusAt: (Int) -> Float,
        xClip: Float, zClip: Float, cutX: Double, cutZ: Double
    ) {
        let nz = result.gridRows, nr = result.gridCols
        let dzF = puckHeight / Float(nz)
        let velField = result.velocityField
        let physMax = result.grid.flatMap { $0 }.map { $0.flowMagnitude }.max() ?? 1e-10
        let maxLen = dzF * 2.5
        let stepZ = max(1, nz / 10), stepR = max(1, nr / 6)

        for face in 0..<2 {
            let isX = face == 0
            guard (isX ? cutX : cutZ) < 0.99 else { continue }
            let clip = isX ? xClip : zClip
            let otherClip = isX ? zClip : xClip
            let otherCut = isX ? cutZ : cutX

            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let nv = Float(velField[z][r])
                    guard nv > 0.05 else { continue }
                    let rPos = (Float(r) + 0.5) / Float(nr) * rMax
                    let dist = sqrt(clip * clip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= otherClip || otherCut >= 0.99 else { continue }

                    let cell = result.grid[z][r]
                    let yPos = puckHeight / 2 - (Float(z) + 0.5) * dzF
                    let aLen = max(0.005, nv * maxLen)
                    let vr = Float(cell.velocityR / physMax)
                    let vz = Float(-cell.velocityZ / physMax)
                    guard sqrt(vr * vr + vz * vz) > 1e-6 else { continue }
                    let angle = atan2(vz, vr)

                    let cyl = SCNCylinder(radius: 0.0015, height: CGFloat(aLen))
                    let mat = SCNMaterial()
                    mat.diffuse.contents = pColor(1, 1, 1)
                    mat.transparency = CGFloat(0.25 + nv * 0.5)
                    mat.lightingModel = .constant
                    cyl.materials = [mat]

                    let node = SCNNode(geometry: cyl)
                    if isX {
                        let mZ = rPos + cos(angle) * aLen * 0.5
                        let mY = yPos + sin(angle) * aLen * 0.5
                        node.position = SCNVector3(clip, mY, mZ)
                        node.eulerAngles.x = angle - .pi / 2
                    } else {
                        let mX = rPos + cos(angle) * aLen * 0.5
                        let mY = yPos + sin(angle) * aLen * 0.5
                        node.position = SCNVector3(mX, mY, clip)
                        node.eulerAngles.z = angle - .pi / 2
                    }
                    parent.addChildNode(node)
                }
            }
        }
    }

    // MARK: - Lighting

    private static func addLighting(to root: SCNNode) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        ambient.light?.color = pColor(0.78, 0.78, 0.88)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1000
        key.light?.color = pColor(1.0, 0.97, 0.92)
        key.light?.castsShadow = true
        key.light?.shadowRadius = 4
        key.position = SCNVector3(2, 3, 2)
        key.look(at: SCNVector3(0, 0, 0))
        root.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 350
        fill.light?.color = pColor(0.6, 0.7, 1.0)
        fill.position = SCNVector3(-2, 0.5, 1)
        fill.look(at: SCNVector3(0, 0, 0))
        root.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 250
        rim.light?.color = pColor(0.5, 0.6, 1.0)
        rim.position = SCNVector3(0, -2, -1)
        rim.look(at: SCNVector3(0, 0, 0))
        root.addChildNode(rim)
    }

    // MARK: - Labels

    private static func addLabel(to parent: SCNNode, text: String, position: SCNVector3) {
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.font = .systemFont(ofSize: 0.06, weight: .semibold)
        textGeo.flatness = 0.05
        let mat = SCNMaterial()
        mat.diffuse.contents = pColor(1, 1, 1)
        mat.transparency = 0.6
        mat.lightingModel = .constant
        textGeo.materials = [mat]
        let node = SCNNode(geometry: textGeo)
        let (mn, mx) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2, 0, 0)
        node.position = position
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]
        parent.addChildNode(node)
    }

    // MARK: - Animation Progress

    static func applyAnimationProgress(to field: [[Double]], progress: Double, mode: PuckVizMode) -> [[Double]] {
        guard progress < 1.0 else { return field }
        if mode == .permeability { return field }
        let nz = field.count
        guard nz > 0 else { return field }
        let baseValue: Double = 0.05
        let frontRow = progress * Double(nz) / 0.65

        return field.enumerated().map { (z, row) in
            let zD = Double(z)
            if zD > frontRow + 2.0 {
                return [Double](repeating: baseValue, count: row.count)
            } else {
                let timeSince = max(0, frontRow - zD) / Double(nz)
                let edge = zD <= frontRow ? 1.0 : max(0, 1.0 - (zD - frontRow) / 2.0)
                let ramp: Double
                switch mode {
                case .extraction: ramp = min(1.0, timeSince * 4.0)
                case .pressure:   ramp = min(1.0, timeSince * 6.0)
                default:          ramp = min(1.0, timeSince * 3.5)
                }
                return row.map { max(baseValue, $0 * ramp * edge) }
            }
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

    static func colorSIMD(_ value: Double, mode: PuckVizMode) -> SIMD4<Float> {
        let c = heatmapColor(value, mode: mode)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        (NSColor(c).usingColorSpace(.sRGB) ?? NSColor.white).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return SIMD4<Float>(Float(r), Float(g), Float(b), 1.0)
    }

    static func pColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Any {
        #if canImport(UIKit)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
        #elseif canImport(AppKit)
        return NSColor(red: r, green: g, blue: b, alpha: 1)
        #endif
    }
}
