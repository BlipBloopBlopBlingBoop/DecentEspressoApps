//
//  Puck3DView.swift
//  Good Espresso
//
//  Interactive 3D puck visualization using SceneKit.
//  Renders CFD simulation as a cutaway cylinder with per-cell coloring,
//  accurate tapered basket geometry, metallic basket shell, grind particle
//  indicators, and orbit camera.
//
//  Cutaway uses two orthogonal Cartesian clip planes (X and Z) for clean
//  cross-section views. Camera state (zoom, orbit) is preserved across
//  scene rebuilds via Coordinator.
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

// MARK: - UIViewRepresentable / NSViewRepresentable
//
// Uses a Coordinator to save/restore camera transform across scene rebuilds,
// so the user's zoom and orbit are preserved during animation playback.

#if canImport(UIKit)
struct PuckSceneRepresentable: UIViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let cutX: Double
    let cutZ: Double
    var animationProgress: Double = 1.0

    class Coordinator {
        var lastPOVTransform: SCNMatrix4?
        var lastFOV: CGFloat?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Save camera state
        if let pov = scnView.pointOfView {
            context.coordinator.lastPOVTransform = pov.transform
            context.coordinator.lastFOV = pov.camera?.fieldOfView
        }

        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )

        // Restore camera state so zoom/orbit persist
        if let saved = context.coordinator.lastPOVTransform,
           let pov = scnView.pointOfView {
            pov.transform = saved
            if let fov = context.coordinator.lastFOV {
                pov.camera?.fieldOfView = fov
            }
        }
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

    class Coordinator {
        var lastPOVTransform: SCNMatrix4?
        var lastFOV: CGFloat?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        if let pov = scnView.pointOfView {
            context.coordinator.lastPOVTransform = pov.transform
            context.coordinator.lastFOV = pov.camera?.fieldOfView
        }

        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )

        if let saved = context.coordinator.lastPOVTransform,
           let pov = scnView.pointOfView {
            pov.transform = saved
            if let fov = context.coordinator.lastFOV {
                pov.camera?.fieldOfView = fov
            }
        }
    }
}
#endif

// MARK: - Scene Builder

enum PuckSceneBuilder {

    static func buildScene(
        result: PuckSimulationResult,
        mode: PuckVizMode,
        basketSpec: BasketSpec,
        grindSizeMicrons: Double,
        cutX: Double,
        cutZ: Double,
        animationProgress: Double = 1.0
    ) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = pColor(0.04, 0.04, 0.07)

        let nz = result.gridRows
        let nr = result.gridCols
        let isAnimating = animationProgress < 1.0
        // High-res segments: 180 normal, 120 during animation
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

        // Clip plane positions: 0..1 mapped to 0..topRadius
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
            let baseR = topRadius + (bottomRadius - topRadius) * zFrac
            return baseR + lip
        }

        let dTheta = Float(2.0 * .pi) / Float(thetaSegments)

        // Outer surface — full 360° with Cartesian clipping
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

        // MARK: Clip-plane cross-section faces

        let needXFace = cutX < 0.99
        let needZFace = cutZ < 0.99

        if needXFace {
            addClipFace(
                clipPos: xClip, axis: .x, otherClipPos: zClip, otherCutVal: cutZ,
                nz: nz, nr: nr, field: field, mode: mode,
                puckHeight: puckHeight, dz: dz, topRadius: topRadius,
                radiusAt: radiusAt,
                vertices: &vertices, normals: &normals, colors: &colors, indices: &indices
            )
        }

        if needZFace {
            addClipFace(
                clipPos: zClip, axis: .z, otherClipPos: xClip, otherCutVal: cutX,
                nz: nz, nr: nr, field: field, mode: mode,
                puckHeight: puckHeight, dz: dz, topRadius: topRadius,
                radiusAt: radiusAt,
                vertices: &vertices, normals: &normals, colors: &colors, indices: &indices
            )
        }

        // Build puck geometry node
        let puckNode = SCNNode(geometry: buildGeometry(
            vertices: vertices, normals: normals, colors: colors, indices: indices
        ))
        scene.rootNode.addChildNode(puckNode)

        // MARK: Basket shell (metallic enclosure extending above the puck)
        addBasketShell(to: scene.rootNode, nz: nz, puckHeight: puckHeight,
                       topRadius: topRadius, bottomRadius: bottomRadius,
                       radiusAt: radiusAt, xClip: xClip, zClip: zClip,
                       cutX: cutX, cutZ: cutZ, thetaSegments: thetaSegments)

        // Basket rim torus
        let shellExtraTop: Float = puckHeight * 0.25
        let rimY = puckHeight / 2 + shellExtraTop
        addBasketRim(to: scene.rootNode, radius: topRadius + 0.04, y: rimY)

        // Grind particles & streamlines — skip during animation for perf
        if (needXFace || needZFace) && !isAnimating {
            addGrindParticles(to: scene.rootNode, nz: nz, nr: nr,
                              puckHeight: puckHeight, radiusAt: radiusAt,
                              grindMicrons: grindSizeMicrons, field: field, mode: mode,
                              xClip: xClip, zClip: zClip, cutX: cutX, cutZ: cutZ)
            addFlowStreamlines(to: scene.rootNode, result: result,
                               puckHeight: puckHeight, radiusAt: radiusAt,
                               xClip: xClip, zClip: zClip, cutX: cutX, cutZ: cutZ)
        }

        // Lighting
        addLighting(to: scene.rootNode)

        // Camera — positioned to see into the cut
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 34
        cam.camera?.zNear = 0.01
        cam.camera?.zFar = 50
        cam.position = SCNVector3(1.4, 1.1, 1.8)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        // Labels
        addLabel(to: scene.rootNode, text: "Water In  \u{2193}",
                 position: SCNVector3(0, rimY + 0.1, 0.3))
        addLabel(to: scene.rootNode, text: "\u{2191}  Basket Exit",
                 position: SCNVector3(0, -puckHeight / 2 - 0.15, 0.3))

        return scene
    }

    // MARK: - Clip Axis

    enum ClipAxis { case x, z }

    // MARK: - Clip Face

    /// Draws a flat cross-section face at a clip plane.
    /// Samples the axisymmetric field via r = sqrt(clipPos² + perpPos²).
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

        // High-res sampling across the face
        let perpSteps = nr  // Match radial grid resolution
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

    /// Metallic basket shell — cylindrical wall extending above the puck for realism,
    /// plus a perforated bottom screen below.
    private static func addBasketShell(
        to parent: SCNNode, nz: Int, puckHeight: Float,
        topRadius: Float, bottomRadius: Float,
        radiusAt: (Int) -> Float,
        xClip: Float, zClip: Float,
        cutX: Double, cutZ: Double,
        thetaSegments: Int
    ) {
        let wallThickness: Float = 0.018
        let shellExtraTop: Float = puckHeight * 0.25  // headspace above puck
        let shellSegments = thetaSegments
        let dTheta = Float(2.0 * .pi) / Float(shellSegments)

        // Shell extends from below the puck to above it
        let shellBottom: Float = -puckHeight / 2 - 0.005
        let shellTop: Float = puckHeight / 2 + shellExtraTop
        let totalShellH = shellTop - shellBottom
        let nzShell = 20
        let dzShell = totalShellH / Float(nzShell)

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var idxs: [UInt32] = []

        func addShellQuad(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                          normal: SCNVector3) {
            let base = UInt32(verts.count)
            verts.append(contentsOf: [v0, v1, v2, v3])
            norms.append(contentsOf: [normal, normal, normal, normal])
            idxs.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
        }

        // Shell wall radius interpolation (follows basket taper)
        func shellRadiusInner(y: Float) -> Float {
            // Map y to puck z-fraction: top of puck = 0, bottom = 1
            // Above puck: use top radius; below puck: use bottom radius
            if y >= puckHeight / 2 {
                return topRadius + 0.002  // tiny gap above puck
            } else if y <= -puckHeight / 2 {
                return bottomRadius + 0.002
            } else {
                let zFrac = (puckHeight / 2 - y) / puckHeight
                let lip: Float = zFrac < 0.15 ? 0.03 * (1.0 - zFrac / 0.15) : 0
                return topRadius + (bottomRadius - topRadius) * zFrac + lip + 0.002
            }
        }

        // Outer wall
        for z in 0..<nzShell {
            let yTop = shellTop - Float(z) * dzShell
            let yBot = yTop - dzShell
            let rInner0 = shellRadiusInner(y: yTop)
            let rInner1 = shellRadiusInner(y: yBot)
            let rOuter0 = rInner0 + wallThickness
            let rOuter1 = rInner1 + wallThickness

            for t in 0..<shellSegments {
                let theta0 = Float(t) * dTheta
                let theta1 = theta0 + dTheta
                let midTheta = (theta0 + theta1) / 2

                let xMid = rOuter0 * cos(midTheta)
                let zMid = rOuter0 * sin(midTheta)
                guard xMid <= xClip + wallThickness || cutX >= 0.99 else { continue }
                guard zMid <= zClip + wallThickness || cutZ >= 0.99 else { continue }

                // Outer surface
                addShellQuad(
                    SCNVector3(rOuter0 * cos(theta0), yTop, rOuter0 * sin(theta0)),
                    SCNVector3(rOuter0 * cos(theta1), yTop, rOuter0 * sin(theta1)),
                    SCNVector3(rOuter1 * cos(theta1), yBot, rOuter1 * sin(theta1)),
                    SCNVector3(rOuter1 * cos(theta0), yBot, rOuter1 * sin(theta0)),
                    normal: SCNVector3(cos(midTheta), 0, sin(midTheta))
                )

                // Inner surface
                addShellQuad(
                    SCNVector3(rInner0 * cos(theta1), yTop, rInner0 * sin(theta1)),
                    SCNVector3(rInner0 * cos(theta0), yTop, rInner0 * sin(theta0)),
                    SCNVector3(rInner1 * cos(theta0), yBot, rInner1 * sin(theta0)),
                    SCNVector3(rInner1 * cos(theta1), yBot, rInner1 * sin(theta1)),
                    normal: SCNVector3(-cos(midTheta), 0, -sin(midTheta))
                )
            }
        }

        // Bottom screen
        let rBottom = shellRadiusInner(y: -puckHeight / 2)
        let yBottom = shellBottom
        let screenSegments = min(shellSegments, 80)
        let screenDTheta = Float(2.0 * .pi) / Float(screenSegments)
        let screenRings = 12
        let screenDr = rBottom / Float(screenRings)

        for ring in 0..<screenRings {
            let rIn = Float(ring) * screenDr
            let rOut = rIn + screenDr
            for t in 0..<screenSegments {
                let theta0 = Float(t) * screenDTheta
                let theta1 = theta0 + screenDTheta
                let midTheta = (theta0 + theta1) / 2
                let rMid = (rIn + rOut) / 2

                let xMid = rMid * cos(midTheta)
                let zMid = rMid * sin(midTheta)
                guard xMid <= xClip + wallThickness || cutX >= 0.99 else { continue }
                guard zMid <= zClip + wallThickness || cutZ >= 0.99 else { continue }

                addShellQuad(
                    SCNVector3(rIn * cos(theta0), yBottom, rIn * sin(theta0)),
                    SCNVector3(rOut * cos(theta0), yBottom, rOut * sin(theta0)),
                    SCNVector3(rOut * cos(theta1), yBottom, rOut * sin(theta1)),
                    SCNVector3(rIn * cos(theta1), yBottom, rIn * sin(theta1)),
                    normal: SCNVector3(0, -1, 0)
                )
            }
        }

        // Top rim ring (annulus at shell top)
        let rRimInner = shellRadiusInner(y: shellTop)
        let rRimOuter = rRimInner + wallThickness
        for t in 0..<shellSegments {
            let theta0 = Float(t) * dTheta
            let theta1 = theta0 + dTheta
            let midTheta = (theta0 + theta1) / 2

            let xMid = rRimOuter * cos(midTheta)
            let zMid = rRimOuter * sin(midTheta)
            guard xMid <= xClip + wallThickness || cutX >= 0.99 else { continue }
            guard zMid <= zClip + wallThickness || cutZ >= 0.99 else { continue }

            addShellQuad(
                SCNVector3(rRimInner * cos(theta0), shellTop, rRimInner * sin(theta0)),
                SCNVector3(rRimOuter * cos(theta0), shellTop, rRimOuter * sin(theta0)),
                SCNVector3(rRimOuter * cos(theta1), shellTop, rRimOuter * sin(theta1)),
                SCNVector3(rRimInner * cos(theta1), shellTop, rRimInner * sin(theta1)),
                normal: SCNVector3(0, 1, 0)
            )
        }

        // Assemble shell geometry
        let vertexSource = SCNGeometrySource(vertices: verts)
        let normalSource = SCNGeometrySource(normals: norms)
        let element = SCNGeometryElement(indices: idxs, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = pColor(0.72, 0.72, 0.75)
        mat.metalness.contents = 0.92
        mat.roughness.contents = 0.30
        mat.isDoubleSided = false
        geo.materials = [mat]

        let shellNode = SCNNode(geometry: geo)
        parent.addChildNode(shellNode)
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
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
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
        let particleRadius = CGFloat(max(0.005, grindMicrons / 400.0 * 0.010))
        let sphere = SCNSphere(radius: particleRadius)
        sphere.segmentCount = 8

        let dzP = puckHeight / Float(nz)
        let stepZ = max(1, nz / 14)
        let stepR = max(1, nr / 10)

        srand48(123)

        // Particles on X clip face
        if cutX < 0.99 {
            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let val = field[z][r]
                    let col = colorSIMD(val, mode: mode)
                    let rPos = (Float(r) + Float(drand48()) * 0.5) / Float(nr) * rMax
                    let yPos = puckHeight / 2 - (Float(z) + Float(drand48()) * 0.5) * dzP

                    let dist = sqrt(xClip * xClip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= zClip || cutZ >= 0.99 else { continue }

                    let mat = SCNMaterial()
                    mat.diffuse.contents = pColor(CGFloat(col.x) * 0.7, CGFloat(col.y) * 0.7, CGFloat(col.z) * 0.7)
                    mat.lightingModel = .physicallyBased
                    mat.roughness.contents = 0.9
                    sphere.materials = [mat]

                    let node = SCNNode(geometry: sphere.copy() as? SCNGeometry ?? sphere)
                    node.position = SCNVector3(xClip + Float(drand48() - 0.5) * 0.008, yPos, rPos)
                    parent.addChildNode(node)
                }
            }
        }

        // Particles on Z clip face
        if cutZ < 0.99 {
            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let val = field[z][r]
                    let col = colorSIMD(val, mode: mode)
                    let rPos = (Float(r) + Float(drand48()) * 0.5) / Float(nr) * rMax
                    let yPos = puckHeight / 2 - (Float(z) + Float(drand48()) * 0.5) * dzP

                    let dist = sqrt(zClip * zClip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= xClip || cutX >= 0.99 else { continue }

                    let mat = SCNMaterial()
                    mat.diffuse.contents = pColor(CGFloat(col.x) * 0.7, CGFloat(col.y) * 0.7, CGFloat(col.z) * 0.7)
                    mat.lightingModel = .physicallyBased
                    mat.roughness.contents = 0.9
                    sphere.materials = [mat]

                    let node = SCNNode(geometry: sphere.copy() as? SCNGeometry ?? sphere)
                    node.position = SCNVector3(rPos, yPos, zClip + Float(drand48() - 0.5) * 0.008)
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
        let nz = result.gridRows
        let nr = result.gridCols
        let dzF = puckHeight / Float(nz)
        let velField = result.velocityField
        let physMaxVel = result.grid.flatMap { $0 }.map { $0.flowMagnitude }.max() ?? 1e-10
        let maxArrowLen = dzF * 2.5
        let stepZ = max(1, nz / 10)
        let stepR = max(1, nr / 6)

        // Arrows on X clip face
        if cutX < 0.99 {
            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let normVel = Float(velField[z][r])
                    guard normVel > 0.05 else { continue }

                    let rPos = (Float(r) + 0.5) / Float(nr) * rMax
                    let dist = sqrt(xClip * xClip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= zClip || cutZ >= 0.99 else { continue }

                    let cell = result.grid[z][r]
                    let yPos = puckHeight / 2 - (Float(z) + 0.5) * dzF
                    let arrowLen = max(0.005, normVel * maxArrowLen)

                    let vr = Float(cell.velocityR / physMaxVel)
                    let vz = Float(-cell.velocityZ / physMaxVel)
                    let dirLen = sqrt(vr * vr + vz * vz)
                    guard dirLen > 1e-6 else { continue }

                    // Arrow points in (z-scene, y) plane at x=xClip
                    let sceneAngle = atan2(vz, vr)

                    let cyl = SCNCylinder(radius: 0.0015, height: CGFloat(arrowLen))
                    let mat = SCNMaterial()
                    let alpha = 0.25 + normVel * 0.5
                    mat.diffuse.contents = pColor(1, 1, 1)
                    mat.transparency = CGFloat(alpha)
                    mat.lightingModel = .constant
                    cyl.materials = [mat]

                    let shaftNode = SCNNode(geometry: cyl)
                    let midZ = rPos + cos(sceneAngle) * arrowLen * 0.5
                    let midY = yPos + sin(sceneAngle) * arrowLen * 0.5
                    shaftNode.position = SCNVector3(xClip, midY, midZ)
                    // Rotate from default Y-axis to the flow direction in the YZ plane
                    shaftNode.eulerAngles.x = sceneAngle - .pi / 2
                    parent.addChildNode(shaftNode)
                }
            }
        }

        // Arrows on Z clip face
        if cutZ < 0.99 {
            for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
                let rMax = radiusAt(z)
                for r in stride(from: stepR / 2, to: nr, by: stepR) {
                    let normVel = Float(velField[z][r])
                    guard normVel > 0.05 else { continue }

                    let rPos = (Float(r) + 0.5) / Float(nr) * rMax
                    let dist = sqrt(zClip * zClip + rPos * rPos)
                    guard dist <= rMax else { continue }
                    guard rPos <= xClip || cutX >= 0.99 else { continue }

                    let cell = result.grid[z][r]
                    let yPos = puckHeight / 2 - (Float(z) + 0.5) * dzF
                    let arrowLen = max(0.005, normVel * maxArrowLen)

                    let vr = Float(cell.velocityR / physMaxVel)
                    let vz = Float(-cell.velocityZ / physMaxVel)
                    let dirLen = sqrt(vr * vr + vz * vz)
                    guard dirLen > 1e-6 else { continue }

                    let sceneAngle = atan2(vz, vr)

                    let cyl = SCNCylinder(radius: 0.0015, height: CGFloat(arrowLen))
                    let mat = SCNMaterial()
                    let alpha = 0.25 + normVel * 0.5
                    mat.diffuse.contents = pColor(1, 1, 1)
                    mat.transparency = CGFloat(alpha)
                    mat.lightingModel = .constant
                    cyl.materials = [mat]

                    let shaftNode = SCNNode(geometry: cyl)
                    let midX = rPos + cos(sceneAngle) * arrowLen * 0.5
                    let midY = yPos + sin(sceneAngle) * arrowLen * 0.5
                    shaftNode.position = SCNVector3(midX, midY, zClip)
                    shaftNode.eulerAngles.z = sceneAngle - .pi / 2
                    parent.addChildNode(shaftNode)
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

    /// Water front sweeps top-to-bottom; values ramp up behind the front.
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
                let timeSinceArrival = max(0, frontRow - zD) / Double(nz)
                let frontEdge = zD <= frontRow ? 1.0 : max(0, 1.0 - (zD - frontRow) / 2.0)
                let rampUp: Double
                switch mode {
                case .extraction:
                    // Faster ramp so extraction change is clearly visible
                    rampUp = min(1.0, timeSinceArrival * 4.0)
                case .pressure:
                    rampUp = min(1.0, timeSinceArrival * 6.0)
                default:
                    rampUp = min(1.0, timeSinceArrival * 3.5)
                }
                let factor = rampUp * frontEdge
                return row.map { max(baseValue, $0 * factor) }
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
