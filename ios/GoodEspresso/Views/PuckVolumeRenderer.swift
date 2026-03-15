//
//  PuckVolumeRenderer.swift
//  Good Espresso
//
//  Metal-based GPU volume renderer for puck CFD visualization.
//  Uses ray marching through the axisymmetric simulation field,
//  rendered as a compute shader writing to a drawable texture.
//
//  This replaces the SceneKit vertex-mesh approach with a "video game"
//  architecture: the GPU directly ray-marches through the field data,
//  producing smooth, continuous visualization without polygon artifacts.
//
//  The 2D (r,z) simulation field is uploaded as a Metal texture and
//  sampled with bilinear filtering during the ray march, exploiting
//  the rotational symmetry of the cylindrical puck.
//

import SwiftUI
import MetalKit
import simd

// MARK: - Uniforms (must match Metal struct VolumeUniforms)

struct VolumeUniforms {
    var invViewProj: simd_float4x4
    var cameraPos: SIMD4<Float>
    var lightDir: SIMD4<Float>
    var lightColor: SIMD4<Float>
    var ambientColor: SIMD4<Float>
    var resolution: SIMD2<Float>
    var puckRadius: Float
    var puckHeight: Float
    var taperRatio: Float
    var cutX: Float
    var cutZ: Float
    var stepSize: Float
    var opacity: Float
    var grainIntensity: Float
    var vizMode: UInt32
    var animProgress: Float
    var fieldRows: UInt32
    var fieldCols: UInt32
}

// MARK: - Metal Volume Renderer

final class PuckVolumeRendererEngine: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private var fieldTexture: MTLTexture?
    private var fieldRows: Int = 0
    private var fieldCols: Int = 0
    /// Offscreen texture for compute shader output. Required because
    /// drawable textures may not support compute write access on macOS.
    private var offscreenTexture: MTLTexture?
    private var offscreenWidth: Int = 0
    private var offscreenHeight: Int = 0

    /// Weak reference so the renderer can request redraws
    weak var mtkView: MTKView?

    // Camera state (orbit camera)
    var cameraAngleX: Float = 0.4      // elevation
    var cameraAngleY: Float = 0.6      // azimuth
    var cameraDistance: Float = 3.5
    var cameraPanX: Float = 0
    var cameraPanY: Float = 0

    // Visualization parameters
    var hasFieldData: Bool { fieldTexture != nil }
    var lastFieldKey: String = ""
    var vizMode: UInt32 = 1            // flow by default
    var cutX: Float = 0.55
    var cutZ: Float = 0.55
    var animationProgress: Float = 1.0
    var puckHeight: Float = 0.5
    var taperRatio: Float = 0.93
    var grindSizeMicrons: Float = 400
    var tampPressureKg: Float = 15

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let fn = library.makeFunction(name: "puckVolumeRayMarch"),
              let pipe = try? device.makeComputePipelineState(function: fn)
        else { return nil }

        self.device = device
        self.commandQueue = queue
        self.pipeline = pipe
        super.init()
    }

    // MARK: - Upload field data as 2D texture

    func updateFieldTexture(field: [[Double]], rows: Int, cols: Int) {
        // Reuse existing texture if dimensions match
        if fieldRows == rows && fieldCols == cols, let existing = fieldTexture {
            // Just update the data in-place
            var data = [Float](repeating: 0, count: rows * cols)
            for z in 0..<rows {
                let row = field[z]
                for r in 0..<cols {
                    data[z * cols + r] = Float(row[r])
                }
            }
            existing.replace(
                region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                 size: MTLSize(width: cols, height: rows, depth: 1)),
                mipmapLevel: 0,
                withBytes: data,
                bytesPerRow: cols * MemoryLayout<Float>.size
            )
            setNeedsDisplay()
            return
        }

        fieldRows = rows
        fieldCols = cols

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: cols, height: rows,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared

        guard let tex = device.makeTexture(descriptor: desc) else { return }

        var data = [Float](repeating: 0, count: rows * cols)
        for z in 0..<rows {
            let row = field[z]
            for r in 0..<cols {
                data[z * cols + r] = Float(row[r])
            }
        }

        tex.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                             size: MTLSize(width: cols, height: rows, depth: 1)),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: cols * MemoryLayout<Float>.size
        )

        fieldTexture = tex
        setNeedsDisplay()
    }

    func setNeedsDisplay() {
        #if canImport(UIKit)
        mtkView?.setNeedsDisplay()
        #elseif canImport(AppKit)
        mtkView?.needsDisplay = true
        #endif
    }

    // MARK: - Camera matrices

    private func viewProjectionMatrix(viewportSize: SIMD2<Float>) -> (simd_float4x4, SIMD3<Float>) {
        let aspect = viewportSize.x / max(viewportSize.y, 1)

        // Orbit camera
        let camX = cameraDistance * cos(cameraAngleX) * sin(cameraAngleY)
        let camY = cameraDistance * sin(cameraAngleX)
        let camZ = cameraDistance * cos(cameraAngleX) * cos(cameraAngleY)
        let eye = SIMD3<Float>(camX + cameraPanX, camY + cameraPanY, camZ)
        let target = SIMD3<Float>(cameraPanX, cameraPanY, 0)
        let up = SIMD3<Float>(0, 1, 0)

        let view = lookAt(eye: eye, center: target, up: up)
        let proj = perspective(fov: Float.pi / 5.5, aspect: aspect, near: 0.01, far: 50)
        return (proj * view, eye)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setNeedsDisplay()
    }

    /// Ensure the offscreen compute target texture matches the drawable size.
    private func ensureOffscreenTexture(width: Int, height: Int) {
        guard width != offscreenWidth || height != offscreenHeight else { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width, height: height,
            mipmapped: false
        )
        desc.usage = [.shaderWrite, .shaderRead]
        desc.storageMode = .private
        offscreenTexture = device.makeTexture(descriptor: desc)
        offscreenWidth = width
        offscreenHeight = height
    }

    func draw(in view: MTKView) {
        guard let fieldTexture,
              let drawable = view.currentDrawable,
              let cmdBuf = commandQueue.makeCommandBuffer()
        else { return }

        let w = Int(view.drawableSize.width)
        let h = Int(view.drawableSize.height)
        guard w > 0, h > 0 else { return }

        // Ensure we have a writable offscreen texture for the compute shader.
        // Drawable textures may not support compute write on all platforms.
        ensureOffscreenTexture(width: w, height: h)
        guard let offscreen = offscreenTexture else { return }

        let viewportSize = SIMD2<Float>(Float(w), Float(h))
        let (viewProj, eye) = viewProjectionMatrix(viewportSize: viewportSize)
        let invViewProj = viewProj.inverse

        let grainIntensity: Float = 0.03 + 0.06 * min(1.0, grindSizeMicrons / 600.0)

        var uniforms = VolumeUniforms(
            invViewProj: invViewProj,
            cameraPos: SIMD4<Float>(eye.x, eye.y, eye.z, 1),
            lightDir: normalize(SIMD4<Float>(0.5, 0.8, 0.5, 0)),
            lightColor: SIMD4<Float>(1.0, 0.96, 0.90, 1.1),
            ambientColor: SIMD4<Float>(0.75, 0.73, 0.70, 0.35),
            resolution: viewportSize,
            puckRadius: 1.0,
            puckHeight: puckHeight,
            taperRatio: taperRatio,
            cutX: cutX,
            cutZ: cutZ,
            stepSize: 0.008,
            opacity: 0.85,
            grainIntensity: grainIntensity,
            vizMode: vizMode,
            animProgress: animationProgress,
            fieldRows: UInt32(fieldRows),
            fieldCols: UInt32(fieldCols)
        )

        // Compute pass: ray-march into offscreen texture
        guard let encoder = cmdBuf.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(offscreen, index: 0)
        encoder.setTexture(fieldTexture, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<VolumeUniforms>.stride, index: 0)

        let execWidth = max(1, pipeline.threadExecutionWidth)
        let maxThreads = max(1, pipeline.maxTotalThreadsPerThreadgroup)
        // Keep threadgroup width aligned to execution width and ensure
        // the total thread count stays within the pipeline limit.
        let tgW = min(execWidth, w, maxThreads)
        let tgH = max(1, min(maxThreads / tgW, h))
        let tgSize = MTLSize(width: tgW, height: tgH, depth: 1)

        let gridSize = MTLSize(width: w, height: h, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()

        // Blit offscreen texture to drawable
        guard let blit = cmdBuf.makeBlitCommandEncoder() else { return }
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: w, height: h, depth: 1)
        blit.copy(
            from: offscreen, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: origin, sourceSize: size,
            to: drawable.texture, destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: origin
        )
        blit.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - Matrix helpers

    private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = normalize(center - eye)
        let s = normalize(cross(f, up))
        let u = cross(s, f)
        var m = simd_float4x4(1)
        m[0][0] = s.x; m[1][0] = s.y; m[2][0] = s.z
        m[0][1] = u.x; m[1][1] = u.y; m[2][1] = u.z
        m[0][2] = -f.x; m[1][2] = -f.y; m[2][2] = -f.z
        m[3][0] = -dot(s, eye)
        m[3][1] = -dot(u, eye)
        m[3][2] = dot(f, eye)
        return m
    }

    private func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        var m = simd_float4x4(0)
        m[0][0] = x
        m[1][1] = y
        m[2][2] = z
        m[2][3] = -1
        m[3][2] = z * near
        return m
    }
}

// MARK: - SwiftUI Wrapper

struct PuckVolumeView: View {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    var animationProgress: Double = 1.0
    var cutX: Double = 0.55
    var cutZ: Double = 0.55

    var body: some View {
        PuckMetalViewRepresentable(
            result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons,
            tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ,
            animationProgress: animationProgress
        )
    }
}

// MARK: - Shared helpers

private func selectField(result: PuckSimulationResult, mode: PuckVizMode) -> [[Double]] {
    switch mode {
    case .pressure:     return result.pressureField
    case .flow:         return result.velocityField
    case .extraction:   return result.extractionField
    case .time:         return result.residenceTimeField
    case .permeability: return result.permeabilityField
    }
}

private func vizModeIndex(_ mode: PuckVizMode) -> UInt32 {
    switch mode {
    case .pressure:     return 0
    case .flow:         return 1
    case .extraction:   return 2
    case .time:         return 3
    case .permeability: return 4
    }
}

private func configureRenderer(
    _ renderer: PuckVolumeRendererEngine,
    result: PuckSimulationResult,
    mode: PuckVizMode,
    basketSpec: BasketSpec,
    grindSizeMicrons: Double,
    tampPressureKg: Double,
    cutX: Double, cutZ: Double,
    animationProgress: Double
) {
    // Only re-upload the field texture when the data or mode actually changed.
    // This is the expensive path (Double→Float conversion + GPU upload).
    let newMode = vizModeIndex(mode)
    let fieldKey = "\(result.gridRows)x\(result.gridCols)|\(result.totalFlowRate)|\(result.channelingRisk)"
    if renderer.vizMode != newMode || renderer.lastFieldKey != fieldKey || !renderer.hasFieldData {
        let field = selectField(result: result, mode: mode)
        renderer.updateFieldTexture(field: field, rows: result.gridRows, cols: result.gridCols)
        renderer.vizMode = newMode
        renderer.lastFieldKey = fieldKey
    }

    // Cheap uniform updates — these just set floats and request a redraw
    renderer.cutX = Float(cutX)
    renderer.cutZ = Float(cutZ)
    renderer.animationProgress = Float(animationProgress)
    renderer.puckHeight = Float(basketSpec.depth / basketSpec.diameter) * 2.0
    renderer.taperRatio = basketSpec.hasBackPressureValve ? 0.96 : 0.93
    renderer.grindSizeMicrons = Float(grindSizeMicrons)
    renderer.tampPressureKg = Float(tampPressureKg)
    renderer.setNeedsDisplay()
}

private func configureMTKView(_ view: MTKView) {
    view.colorPixelFormat = .rgba8Unorm
    view.framebufferOnly = false
    // Use on-demand rendering: only redraw when setNeedsDisplay is called.
    // This avoids burning GPU at 60fps when nothing is changing.
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
}

// MARK: - Platform Representable

#if canImport(UIKit)
struct PuckMetalViewRepresentable: UIViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    let cutX: Double
    let cutZ: Double
    var animationProgress: Double = 1.0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MTKView()
        }
        let view = MTKView(frame: .zero, device: device)
        configureMTKView(view)

        if let renderer = PuckVolumeRendererEngine(device: device) {
            context.coordinator.renderer = renderer
            renderer.mtkView = view
            view.delegate = renderer

            // Upload initial field data so the first draw has something to show
            configureRenderer(
                renderer, result: result, mode: mode, basketSpec: basketSpec,
                grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
                cutX: cutX, cutZ: cutZ, animationProgress: animationProgress
            )

            // Add gesture recognizers
            let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
            view.addGestureRecognizer(pan)
            let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
            view.addGestureRecognizer(pinch)
        }

        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        configureRenderer(
            renderer, result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ, animationProgress: animationProgress
        )
    }

    class Coordinator: NSObject {
        var renderer: PuckVolumeRendererEngine?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let renderer else { return }
            let translation = gesture.translation(in: gesture.view)
            let sensitivity: Float = 0.005
            renderer.cameraAngleY -= Float(translation.x) * sensitivity
            renderer.cameraAngleX += Float(translation.y) * sensitivity
            renderer.cameraAngleX = max(-Float.pi/2 + 0.1, min(Float.pi/2 - 0.1, renderer.cameraAngleX))
            gesture.setTranslation(.zero, in: gesture.view)
            renderer.setNeedsDisplay()
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let renderer else { return }
            renderer.cameraDistance /= Float(gesture.scale)
            renderer.cameraDistance = max(1.5, min(8.0, renderer.cameraDistance))
            gesture.scale = 1
            renderer.setNeedsDisplay()
        }
    }
}
#elseif canImport(AppKit)
struct PuckMetalViewRepresentable: NSViewRepresentable {
    let result: PuckSimulationResult
    let mode: PuckVizMode
    let basketSpec: BasketSpec
    let grindSizeMicrons: Double
    let tampPressureKg: Double
    let cutX: Double
    let cutZ: Double
    var animationProgress: Double = 1.0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MTKView()
        }
        let view = MTKView(frame: .zero, device: device)
        configureMTKView(view)

        if let renderer = PuckVolumeRendererEngine(device: device) {
            context.coordinator.renderer = renderer
            renderer.mtkView = view
            view.delegate = renderer

            // Upload initial field data
            configureRenderer(
                renderer, result: result, mode: mode, basketSpec: basketSpec,
                grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
                cutX: cutX, cutZ: cutZ, animationProgress: animationProgress
            )
        }

        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        configureRenderer(
            renderer, result: result, mode: mode, basketSpec: basketSpec,
            grindSizeMicrons: grindSizeMicrons, tampPressureKg: tampPressureKg,
            cutX: cutX, cutZ: cutZ, animationProgress: animationProgress
        )
    }

    class Coordinator: NSObject {
        var renderer: PuckVolumeRendererEngine?
    }
}
#endif
