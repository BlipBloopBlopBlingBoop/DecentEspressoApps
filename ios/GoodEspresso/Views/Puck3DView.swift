//
//  Puck3DView.swift
//  Good Espresso
//
//  Interactive 3D puck visualization using SceneKit.
//  Renders the axisymmetric CFD simulation as a cutaway cylinder
//  with per-cell coloring, camera orbit, and mode switching.
//

import SwiftUI
import SceneKit

// MARK: - SceneKit Wrapper

struct Puck3DSceneView: View {
    let result: PuckSimulationResult
    let mode: PuckVizMode

    @State private var scene: SCNScene?
    @State private var cutawayFraction: Double = 0.75

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SceneView(
                scene: scene ?? SCNScene(),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .background(Color.black.opacity(0.9))
            .onAppear { buildScene() }
            .onChangeCompat(of: mode) { buildScene() }
            .onChangeCompat(of: result.totalFlowRate) { buildScene() }

            // Cutaway slider
            VStack(spacing: 2) {
                Image(systemName: "scissors")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: $cutawayFraction, in: 0.25...1.0, step: 0.05)
                    .frame(width: 80)
                    .tint(.cyan)
                    .onChangeCompat(of: cutawayFraction) { buildScene() }
            }
            .padding(8)
        }
    }

    // MARK: - Scene Construction

    private func buildScene() {
        let newScene = SCNScene()
        newScene.background.contents = platformColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        let puckNode = buildPuckGeometry()
        newScene.rootNode.addChildNode(puckNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 1.2, 2.5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        newScene.rootNode.addChildNode(cameraNode)

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        ambient.light?.color = platformColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1)
        newScene.rootNode.addChildNode(ambient)

        // Key light
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.color = platformColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1)
        keyLight.position = SCNVector3(2, 3, 2)
        keyLight.look(at: SCNVector3(0, 0, 0))
        newScene.rootNode.addChildNode(keyLight)

        // Subtle rim light from below
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 200
        rimLight.light?.color = platformColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1)
        rimLight.position = SCNVector3(-1, -1, 1)
        rimLight.look(at: SCNVector3(0, 0, 0))
        newScene.rootNode.addChildNode(rimLight)

        // Labels
        addLabel(to: newScene.rootNode, text: "Water In", position: SCNVector3(0, 0.65, 0))
        addLabel(to: newScene.rootNode, text: "Exit", position: SCNVector3(0, -0.65, 0))

        scene = newScene
    }

    // MARK: - Puck Geometry Builder

    private func buildPuckGeometry() -> SCNNode {
        let parentNode = SCNNode()

        let nz = result.gridRows
        let nr = result.gridCols
        let thetaSegments = 36  // angular resolution
        let cutawayAngle = cutawayFraction * 2.0 * .pi

        let field: [[Double]]
        switch mode {
        case .pressure:     field = result.pressureField
        case .flow:         field = result.velocityField
        case .extraction:   field = result.extractionField
        case .permeability: field = result.permeabilityField
        }

        // Normalized puck dimensions: radius=1, height based on aspect
        let puckRadius: Float = 1.0
        let puckHeight: Float = Float(Double(nz) / Double(nr)) * 0.5  // scale to look good

        let dz = puckHeight / Float(nz)
        let dr = puckRadius / Float(nr)
        let dTheta = Float(cutawayAngle) / Float(thetaSegments)

        // Build custom geometry from triangulated quads
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var indices: [UInt32] = []

        // Helper to add a colored quad (two triangles)
        func addQuad(_ v0: SCNVector3, _ v1: SCNVector3, _ v2: SCNVector3, _ v3: SCNVector3,
                     normal: SCNVector3, color: SCNVector3) {
            let base = UInt32(vertices.count)
            vertices.append(contentsOf: [v0, v1, v2, v3])
            normals.append(contentsOf: [normal, normal, normal, normal])
            colors.append(contentsOf: [color, color, color, color])
            indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
        }

        // Outer surface: sweep each z-layer as curved quads
        for z in 0..<nz {
            let r = nr - 1  // outermost ring
            let val = field[z][r]
            let col = colorVector(val)
            let yTop = puckHeight / 2 - Float(z) * dz
            let yBot = yTop - dz
            let radius = puckRadius

            for t in 0..<thetaSegments {
                let theta0 = Float(t) * dTheta
                let theta1 = theta0 + dTheta

                let x0 = radius * cos(theta0), z0 = radius * sin(theta0)
                let x1 = radius * cos(theta1), z1 = radius * sin(theta1)

                let nx = cos((theta0 + theta1) / 2)
                let nz_val = sin((theta0 + theta1) / 2)

                addQuad(
                    SCNVector3(x0, yTop, z0), SCNVector3(x1, yTop, z1),
                    SCNVector3(x1, yBot, z1), SCNVector3(x0, yBot, z0),
                    normal: SCNVector3(nx, 0, nz_val),
                    color: col
                )
            }
        }

        // Top face (z=0): concentric rings
        for r in 0..<nr {
            let val = field[0][r]
            let col = colorVector(val)
            let rInner = Float(r) * dr
            let rOuter = rInner + dr
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

        // Bottom face (z=nz-1): concentric rings
        for r in 0..<nr {
            let val = field[nz - 1][r]
            let col = colorVector(val)
            let rInner = Float(r) * dr
            let rOuter = rInner + dr
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

        // Cutaway face 1 (theta = 0): vertical cross-section showing interior
        if cutawayFraction < 1.0 {
            for z in 0..<nz {
                for r in 0..<nr {
                    let val = field[z][r]
                    let col = colorVector(val)
                    let yTop = puckHeight / 2 - Float(z) * dz
                    let yBot = yTop - dz
                    let rInner = Float(r) * dr
                    let rOuter = rInner + dr

                    addQuad(
                        SCNVector3(rInner, yTop, 0), SCNVector3(rOuter, yTop, 0),
                        SCNVector3(rOuter, yBot, 0), SCNVector3(rInner, yBot, 0),
                        normal: SCNVector3(0, 0, -1),
                        color: col
                    )
                }
            }

            // Cutaway face 2 (theta = cutawayAngle)
            let cutTheta = Float(cutawayAngle)
            let cutNx = -sin(cutTheta)
            let cutNz = cos(cutTheta)
            for z in 0..<nz {
                for r in 0..<nr {
                    let val = field[z][r]
                    let col = colorVector(val)
                    let yTop = puckHeight / 2 - Float(z) * dz
                    let yBot = yTop - dz
                    let rInner = Float(r) * dr
                    let rOuter = rInner + dr

                    let xi = rInner * cos(cutTheta), zi = rInner * sin(cutTheta)
                    let xo = rOuter * cos(cutTheta), zo = rOuter * sin(cutTheta)

                    addQuad(
                        SCNVector3(xo, yTop, zo), SCNVector3(xi, yTop, zi),
                        SCNVector3(xi, yBot, zi), SCNVector3(xo, yBot, zo),
                        normal: SCNVector3(cutNx, 0, cutNz),
                        color: col
                    )
                }
            }
        }

        // Build SCNGeometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)

        // Color source from float3 vectors
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.stride)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.stride
        )

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.7
        material.metalness.contents = 0.1
        geometry.materials = [material]

        let geoNode = SCNNode(geometry: geometry)
        parentNode.addChildNode(geoNode)

        // Add flow arrows as thin cylinder indicators (in flow mode)
        if mode == .flow {
            addFlowIndicators(to: parentNode, puckRadius: puckRadius, puckHeight: puckHeight)
        }

        return parentNode
    }

    // MARK: - Flow Indicators

    private func addFlowIndicators(to parent: SCNNode, puckRadius: Float, puckHeight: Float) {
        let nz = result.gridRows
        let nr = result.gridCols
        let maxVel = result.velocityField.flatMap { $0 }.max() ?? 1
        let dr = puckRadius / Float(nr)
        let dz = puckHeight / Float(nz)

        let stepZ = max(1, nz / 6)
        let stepR = max(1, nr / 4)

        for z in stride(from: stepZ / 2, to: nz, by: stepZ) {
            for r in stride(from: stepR / 2, to: nr, by: stepR) {
                let cell = result.grid[z][r]
                let vel = cell.flowMagnitude
                guard vel > maxVel * 0.1 else { continue }

                let rPos = (Float(r) + 0.5) * dr
                let yPos = puckHeight / 2 - (Float(z) + 0.5) * dz
                let arrowLen = Float(vel / maxVel) * dz * 2

                let arrow = SCNCylinder(radius: 0.005, height: CGFloat(arrowLen))
                let arrowMat = SCNMaterial()
                arrowMat.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.6)
                arrowMat.lightingModel = .constant
                arrow.materials = [arrowMat]

                let node = SCNNode(geometry: arrow)
                // Place on the cutaway face (theta=0)
                node.position = SCNVector3(rPos, yPos, 0)

                // Orient along flow direction
                let angle = atan2(cell.velocityZ, cell.velocityR)
                node.eulerAngles.z = Float(angle) - .pi / 2

                parent.addChildNode(node)
            }
        }
    }

    // MARK: - Labels

    private func addLabel(to parent: SCNNode, text: String, position: SCNVector3) {
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.font = .systemFont(ofSize: 0.08, weight: .medium)
        textGeo.flatness = 0.1
        let mat = SCNMaterial()
        mat.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        mat.lightingModel = .constant
        textGeo.materials = [mat]

        let textNode = SCNNode(geometry: textGeo)
        // Center the text
        let (min, max) = textNode.boundingBox
        let dx = (max.x - min.x) / 2
        textNode.pivot = SCNMatrix4MakeTranslation(dx, 0, 0)
        textNode.position = position

        // Billboard constraint so text always faces camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        parent.addChildNode(textNode)
    }

    // MARK: - Color Helpers

    private func colorVector(_ value: Double) -> SCNVector3 {
        let c = heatmapColor(value, mode: mode)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        NSColor(c).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return SCNVector3(Float(r), Float(g), Float(b))
    }

    private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> Any {
        #if canImport(UIKit)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(AppKit)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #else
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
}
