//
//  Puck3DView.swift
//  Good Espresso
//
//  Interactive 3D puck visualization using SceneKit.
//  Uses UIViewRepresentable for reactive updates. Renders the CFD
//  simulation as a cutaway cylinder with per-cell coloring, accurate
//  tapered basket geometry, grind particle indicators, and orbit camera.
//

import SwiftUI
import SceneKit

// MARK: - SwiftUI Wrapper

struct Puck3DSceneView: View {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let isComputing: Bool

    @State private var cutawayFraction: Double = 0.75

    var body: some View {
        ZStack {
            PuckSceneRepresentable(
                result: result,
                mode: mode,
                basketSpec: basketSpec,
                grindSizeMicrons: grindSizeMicrons,
                cutawayFraction: cutawayFraction
            )
            .background(Color.black)

            // Computing overlay
            if isComputing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.cyan)
                    Text("Simulating...")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Cutaway slider overlay
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.strikethrough")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $cutawayFraction, in: 0.15...1.0)
                        .tint(.cyan.opacity(0.8))
                    Text("\(Int(cutawayFraction * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 30)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - UIViewRepresentable / NSViewRepresentable

#if canImport(UIKit)
struct PuckSceneRepresentable: UIViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let cutawayFraction: Double

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutawayFraction: cutawayFraction
        )
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutawayFraction: cutawayFraction
        )
    }
}
#elseif canImport(AppKit)
struct PuckSceneRepresentable: NSViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let cutawayFraction: Double

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutawayFraction: cutawayFraction
        )
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        scnView.scene = PuckSceneBuilder.buildScene(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, cutawayFraction: cutawayFraction
        )
    }
}
#endif

// MARK: - Scene Builder (shared logic)

enum PuckSceneBuilder {

    static func buildScene(
        result: PuckSimulationResult,
        mode: PuckVizMode,
        basketSpec: BasketSpec,
        grindSizeMicrons: Double,
        cutawayFraction: Double
    ) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = pColor(0.04, 0.04, 0.07)

        let nz = result.gridRows
        let nr = result.gridCols
        let thetaSegments = 72
        let cutAngle = Float(cutawayFraction * 2.0 * .pi)

        let field = selectField(result: result, mode: mode)

        // Basket geometry: real Decent baskets taper ~2mm narrower at bottom
        let topRadius: Float = 1.0
        let taperRatio: Float = basketSpec.hasBackPressureValve ? 0.96 : 0.93
        let bottomRadius: Float = topRadius * taperRatio
        // Curved lip at top: baskets flare slightly outward in the top ~15%
        let lipFlare: Float = 0.03

        let puckHeight: Float = Float(basketSpec.depth / basketSpec.diameter) * 2.0
        let dz = puckHeight / Float(nz)

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

        // Radius at a given z-level with taper and lip
        func radiusAt(zIndex: Int) -> Float {
            let zFrac = Float(zIndex) / Float(nz)
            // Lip flare in top 15%
            let lip: Float = zFrac < 0.15 ? lipFlare * (1.0 - zFrac / 0.15) : 0
            let baseR = topRadius + (bottomRadius - topRadius) * zFrac
            return baseR + lip
        }

        let dTheta = cutAngle / Float(thetaSegments)

        // Outer surface with taper
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

        // Top face (z=0)
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

        // Bottom face (z=nz-1)
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

        // Cutaway cross-section faces (both slicing planes)
        if cutawayFraction < 0.98 {
            // Face 1: theta = 0 plane
            addCutawayFace(
                theta: 0, normalSign: Float(-1),
                nz: nz, nr: nr, field: field, mode: mode,
                puckHeight: puckHeight, dz: dz,
                radiusAt: radiusAt,
                vertices: &vertices, normals: &normals, colors: &colors, indices: &indices
            )

            // Face 2: theta = cutAngle plane
            addCutawayFace(
                theta: cutAngle, normalSign: Float(1),
                nz: nz, nr: nr, field: field, mode: mode,
                puckHeight: puckHeight, dz: dz,
                radiusAt: radiusAt,
                vertices: &vertices, normals: &normals, colors: &colors, indices: &indices
            )
        }

        // Build geometry
        let puckNode = SCNNode(geometry: buildGeometry(
            vertices: vertices, normals: normals, colors: colors, indices: indices
        ))
        scene.rootNode.addChildNode(puckNode)

        // Basket wireframe ring (metallic rim at top)
        addBasketRim(to: scene.rootNode, radius: rTopOuter + 0.02, y: puckHeight / 2,
                     cutAngle: cutAngle, segments: thetaSegments)

        // Grind particles (scattered spheres on cutaway face)
        if cutawayFraction < 0.98 {
            addGrindParticles(to: scene.rootNode, nz: nz, nr: nr,
                              puckHeight: puckHeight, radiusAt: radiusAt,
                              grindMicrons: grindSizeMicrons, field: field, mode: mode)
        }

        // Flow streamlines
        if mode == .flow, cutawayFraction < 0.98 {
            addFlowStreamlines(to: scene.rootNode, result: result,
                               puckHeight: puckHeight, radiusAt: radiusAt)
        }

        // Lighting
        addLighting(to: scene.rootNode)

        // Camera
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 36
        cam.camera?.zNear = 0.01
        cam.camera?.zFar = 50
        cam.position = SCNVector3(0.3, 1.0, 2.4)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        // Labels
        addLabel(to: scene.rootNode, text: "Water In",
                 position: SCNVector3(0, puckHeight / 2 + 0.12, 0))
        addLabel(to: scene.rootNode, text: "Basket Exit",
                 position: SCNVector3(0, -puckHeight / 2 - 0.12, 0))

        return scene
    }

    // MARK: - Cutaway Face

    private static func addCutawayFace(
        theta: Float, normalSign: Float,
        nz: Int, nr: Int, field: [[Double]], mode: PuckVizMode,
        puckHeight: Float, dz: Float,
        radiusAt: (Int) -> Float,
        vertices: inout [SCNVector3], normals: inout [SCNVector3],
        colors: inout [SIMD4<Float>], indices: inout [UInt32]
    ) {
        let nx = -sin(theta) * normalSign
        let nzDir = cos(theta) * normalSign
        let normal = SCNVector3(nx, 0, nzDir)

        for z in 0..<nz {
            let yTop = puckHeight / 2 - Float(z) * dz
            let yBot = yTop - dz
            let rMaxTop = radiusAt(z)
            let rMaxBot = radiusAt(z + 1)

            for r in 0..<nr {
                let val = field[z][r]
                let col = colorSIMD(val, mode: mode)
                let rInT = Float(r) / Float(nr) * rMaxTop
                let rOutT = Float(r + 1) / Float(nr) * rMaxTop
                let rInB = Float(r) / Float(nr) * rMaxBot
                let rOutB = Float(r + 1) / Float(nr) * rMaxBot

                let base = UInt32(vertices.count)
                vertices.append(contentsOf: [
                    SCNVector3(rInT * cos(theta), yTop, rInT * sin(theta)),
                    SCNVector3(rOutT * cos(theta), yTop, rOutT * sin(theta)),
                    SCNVector3(rOutB * cos(theta), yBot, rOutB * sin(theta)),
                    SCNVector3(rInB * cos(theta), yBot, rInB * sin(theta))
                ])
                normals.append(contentsOf: [normal, normal, normal, normal])
                colors.append(contentsOf: [col, col, col, col])

                if normalSign > 0 {
                    indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
                } else {
                    indices.append(contentsOf: [base, base+2, base+1, base, base+3, base+2])
                }
            }
        }
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

    private static func addBasketRim(to parent: SCNNode, radius: Float, y: Float,
                                     cutAngle: Float, segments: Int) {
        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.012)
        let mat = SCNMaterial()
        mat.diffuse.contents = pColor(0.65, 0.65, 0.7)
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 0.3
        mat.metalness.contents = 0.85
        torus.materials = [mat]
        let node = SCNNode(geometry: torus)
        node.position = SCNVector3(0, y, 0)
        parent.addChildNode(node)
    }

    // MARK: - Grind Particles

    private static func addGrindParticles(
        to parent: SCNNode, nz: Int, nr: Int,
        puckHeight: Float, radiusAt: (Int) -> Float,
        grindMicrons: Double, field: [[Double]], mode: PuckVizMode
    ) {
        // Particle scale: 400µm grind ~ 0.4mm real, scaled to scene units
        let particleRadius = CGFloat(max(0.006, grindMicrons / 400.0 * 0.012))
        let sphere = SCNSphere(radius: particleRadius)
        sphere.segmentCount = 8

        // Scatter particles on the theta=0 cutaway face
        let dz = puckHeight / Float(nz)
        let stepZ = max(1, nz / 12)
        let stepR = max(1, nr / 8)

        srand48(123)
        for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
            let rMax = radiusAt(z)
            for r in stride(from: stepR / 2, to: nr, by: stepR) {
                let val = field[z][r]
                let col = colorSIMD(val, mode: mode)

                let rPos = (Float(r) + Float(drand48()) * 0.5) / Float(nr) * rMax
                let yPos = puckHeight / 2 - (Float(z) + Float(drand48()) * 0.5) * dz

                let mat = SCNMaterial()
                mat.diffuse.contents = pColor(CGFloat(col.x) * 0.7, CGFloat(col.y) * 0.7, CGFloat(col.z) * 0.7)
                mat.lightingModel = .physicallyBased
                mat.roughness.contents = 0.9
                mat.metalness.contents = 0.0
                sphere.materials = [mat]

                let node = SCNNode(geometry: sphere.copy() as? SCNGeometry ?? sphere)
                node.position = SCNVector3(rPos, yPos, Float(drand48() - 0.5) * 0.01)
                parent.addChildNode(node)
            }
        }
    }

    // MARK: - Flow Streamlines

    private static func addFlowStreamlines(
        to parent: SCNNode, result: PuckSimulationResult,
        puckHeight: Float, radiusAt: (Int) -> Float
    ) {
        let nz = result.gridRows
        let nr = result.gridCols
        let maxVel = result.velocityField.flatMap { $0 }.max() ?? 1
        let dz = puckHeight / Float(nz)
        let stepZ = max(1, nz / 10)
        let stepR = max(1, nr / 6)

        for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
            let rMax = radiusAt(z)
            for r in stride(from: stepR / 2, to: nr, by: stepR) {
                let cell = result.grid[z][r]
                let vel = cell.flowMagnitude
                guard vel > maxVel * 0.08 else { continue }

                let rPos = (Float(r) + 0.5) / Float(nr) * rMax
                let yPos = puckHeight / 2 - (Float(z) + 0.5) * dz
                let strength = Float(vel / maxVel)
                let arrowLen = strength * dz * 2.5

                let cyl = SCNCylinder(radius: 0.003, height: CGFloat(arrowLen))
                let mat = SCNMaterial()
                mat.diffuse.contents = pColor(1, 1, 1)
                mat.transparency = CGFloat(0.3 + strength * 0.5)
                mat.lightingModel = .constant
                cyl.materials = [mat]

                let node = SCNNode(geometry: cyl)
                node.position = SCNVector3(rPos, yPos, 0)

                let angle = atan2(cell.velocityZ, cell.velocityR)
                node.eulerAngles.z = Float(angle) - .pi / 2
                parent.addChildNode(node)

                // Arrowhead cone
                let cone = SCNCone(topRadius: 0, bottomRadius: 0.008, height: CGFloat(arrowLen * 0.3))
                let coneMat = SCNMaterial()
                coneMat.diffuse.contents = pColor(1, 1, 1)
                coneMat.transparency = CGFloat(0.3 + strength * 0.5)
                coneMat.lightingModel = .constant
                cone.materials = [coneMat]

                let coneNode = SCNNode(geometry: cone)
                let tipOffset = arrowLen / 2
                coneNode.position = SCNVector3(
                    rPos + Float(cos(angle)) * tipOffset,
                    yPos + Float(sin(angle)) * tipOffset,
                    0
                )
                coneNode.eulerAngles.z = Float(angle) - .pi / 2
                parent.addChildNode(coneNode)
            }
        }
    }

    // MARK: - Lighting

    private static func addLighting(to root: SCNNode) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        ambient.light?.color = pColor(0.75, 0.75, 0.85)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.light?.color = pColor(1.0, 0.97, 0.92)
        key.light?.castsShadow = true
        key.light?.shadowRadius = 3
        key.position = SCNVector3(2, 3, 2)
        key.look(at: SCNVector3(0, 0, 0))
        root.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 300
        fill.light?.color = pColor(0.6, 0.7, 1.0)
        fill.position = SCNVector3(-2, 0, 1)
        fill.look(at: SCNVector3(0, 0, 0))
        root.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 200
        rim.light?.color = pColor(0.4, 0.6, 1.0)
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

    // MARK: - Color Helpers

    static func selectField(result: PuckSimulationResult, mode: PuckVizMode) -> [[Double]] {
        switch mode {
        case .pressure:     return result.pressureField
        case .flow:         return result.velocityField
        case .extraction:   return result.extractionField
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
