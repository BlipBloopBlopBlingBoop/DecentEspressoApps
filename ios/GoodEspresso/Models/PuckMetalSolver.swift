//
//  PuckMetalSolver.swift
//  Good Espresso
//
//  GPU-accelerated puck CFD solver using Metal compute shaders.
//  Red-Black SOR for pressure, parallel Darcy velocity computation.
//  Falls back to CPU solver if Metal is unavailable.
//
//  Uses dispatchThreadgroups (not dispatchThreads) for compatibility
//  with all iOS devices including A10 and earlier.
//

import Foundation
import Metal

// MARK: - Metal Solver Parameters (must match Metal struct layout)

struct MetalSolverParams {
    var nz: UInt32
    var nr: UInt32
    var dr: Float
    var dz: Float
    var omega: Float
    var topPressure: Float
    var botPressure: Float
    var color: UInt32
    var mu: Float
}

struct MetalPermParams {
    var nz: UInt32
    var nr: UInt32
    var dr: Float
    var radiusM: Float
    var baseK: Float
    var variationScale: Float
    var moistureContent: Float
    var holeCount: Float
    var holeDiameter: Float
    var basketDiameter: Float
    var seed: UInt32
}

// MARK: - Metal Solver

final class PuckMetalSolver {

    static let shared = PuckMetalSolver()

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let sorPipeline: MTLComputePipelineState?
    private let velocityPipeline: MTLComputePipelineState?
    private let permPipeline: MTLComputePipelineState?

    var isAvailable: Bool { device != nil && sorPipeline != nil }

    private init() {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue(),
              let library = dev.makeDefaultLibrary()
        else {
            device = nil; commandQueue = nil
            sorPipeline = nil; velocityPipeline = nil; permPipeline = nil
            return
        }

        device = dev
        commandQueue = queue

        func makePipeline(_ name: String) -> MTLComputePipelineState? {
            guard let fn = library.makeFunction(name: name) else { return nil }
            return try? dev.makeComputePipelineState(function: fn)
        }

        sorPipeline = makePipeline("redBlackSOR")
        velocityPipeline = makePipeline("computeVelocity")
        permPipeline = makePipeline("buildPermField")
    }

    /// Compute a safe threadgroup size for a given pipeline and grid dimensions.
    /// Respects the pipeline's maxTotalThreadsPerThreadgroup limit.
    private func safeThreadgroupSize(
        pipeline: MTLComputePipelineState,
        gridWidth: Int,
        gridHeight: Int
    ) -> MTLSize {
        let maxThreads = pipeline.maxTotalThreadsPerThreadgroup
        let threadWidth = pipeline.threadExecutionWidth
        // Start with threadExecutionWidth for x, then fill y
        let w = min(threadWidth, gridWidth)
        let h = min(maxThreads / w, gridHeight)
        return MTLSize(width: max(1, w), height: max(1, h), depth: 1)
    }

    /// Compute the number of threadgroups needed to cover the grid.
    private func threadgroupCount(gridWidth: Int, gridHeight: Int, tgSize: MTLSize) -> MTLSize {
        MTLSize(
            width: (gridWidth + tgSize.width - 1) / tgSize.width,
            height: (gridHeight + tgSize.height - 1) / tgSize.height,
            depth: 1
        )
    }

    // MARK: - GPU Pressure Solve

    /// Solve the pressure field on GPU using Red-Black SOR.
    /// Returns the solved pressure as a flat [Float] array (nz × nr).
    func solvePressure(
        permField: [Float],     // flat nz×nr permeability field
        nz: Int, nr: Int,
        dr: Double, dz: Double,
        topPressure: Double,
        botPressure: Double,
        mu: Double,
        omega: Double = 1.55,
        iterations: Int = 400
    ) -> [Float]? {
        guard let device, let queue = commandQueue, let pipeline = sorPipeline else { return nil }

        let count = nz * nr

        // Initial pressure: linear gradient
        var pressure = [Float](repeating: 0, count: count)
        for z in 0..<nz {
            let frac = Float(z) / Float(nz - 1)
            let p = Float(topPressure) * (1.0 - frac) + Float(botPressure) * frac
            for r in 0..<nr {
                pressure[z * nr + r] = p
            }
        }
        // Enforce boundary rows
        for r in 0..<nr {
            pressure[r] = Float(topPressure)
            pressure[(nz - 1) * nr + r] = Float(botPressure)
        }

        guard let pBuffer = device.makeBuffer(bytes: &pressure,
                    length: count * MemoryLayout<Float>.size,
                    options: .storageModeShared),
              let kBuffer = device.makeBuffer(bytes: permField,
                    length: count * MemoryLayout<Float>.size,
                    options: .storageModeShared)
        else { return nil }

        var params = MetalSolverParams(
            nz: UInt32(nz), nr: UInt32(nr),
            dr: Float(dr), dz: Float(dz),
            omega: Float(omega),
            topPressure: Float(topPressure),
            botPressure: Float(botPressure),
            color: 0,
            mu: Float(mu)
        )

        // Grid size for dispatching: nr threads in x, (nz-2) threads in y (interior rows)
        let interiorRows = nz - 2
        let tgSize = safeThreadgroupSize(pipeline: pipeline, gridWidth: nr, gridHeight: interiorRows)
        let tgCount = threadgroupCount(gridWidth: nr, gridHeight: interiorRows, tgSize: tgSize)

        // Batch iterations into multiple command buffers to avoid GPU timeout.
        // Each command buffer handles up to 50 iterations (100 encoder passes).
        let batchSize = 50
        var remaining = iterations

        while remaining > 0 {
            let batch = min(batchSize, remaining)
            guard let cmdBuf = queue.makeCommandBuffer() else { return nil }

            for _ in 0..<batch {
                // Red phase (color = 0)
                if let encoder = cmdBuf.makeComputeCommandEncoder() {
                    params.color = 0
                    encoder.setComputePipelineState(pipeline)
                    encoder.setBuffer(pBuffer, offset: 0, index: 0)
                    encoder.setBuffer(kBuffer, offset: 0, index: 1)
                    encoder.setBytes(&params, length: MemoryLayout<MetalSolverParams>.size, index: 2)
                    encoder.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tgSize)
                    encoder.endEncoding()
                }
                // Black phase (color = 1)
                if let encoder = cmdBuf.makeComputeCommandEncoder() {
                    params.color = 1
                    encoder.setComputePipelineState(pipeline)
                    encoder.setBuffer(pBuffer, offset: 0, index: 0)
                    encoder.setBuffer(kBuffer, offset: 0, index: 1)
                    encoder.setBytes(&params, length: MemoryLayout<MetalSolverParams>.size, index: 2)
                    encoder.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tgSize)
                    encoder.endEncoding()
                }
            }

            cmdBuf.commit()
            cmdBuf.waitUntilCompleted()

            if cmdBuf.status == .error {
                // GPU failed — caller will fall back to CPU solver
                return nil
            }

            remaining -= batch
        }

        // Read back results
        let resultPtr = pBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: resultPtr, count: count))
    }

    // MARK: - GPU Velocity Computation

    func computeVelocity(
        pressure: [Float],
        permField: [Float],
        nz: Int, nr: Int,
        dr: Double, dz: Double,
        mu: Double
    ) -> (vr: [Float], vz: [Float], vmag: [Float])? {
        guard let device, let queue = commandQueue, let pipeline = velocityPipeline else { return nil }

        let count = nz * nr

        guard let pBuf = device.makeBuffer(bytes: pressure, length: count * MemoryLayout<Float>.size, options: .storageModeShared),
              let kBuf = device.makeBuffer(bytes: permField, length: count * MemoryLayout<Float>.size, options: .storageModeShared),
              let vrBuf = device.makeBuffer(length: count * MemoryLayout<Float>.size, options: .storageModeShared),
              let vzBuf = device.makeBuffer(length: count * MemoryLayout<Float>.size, options: .storageModeShared),
              let vmagBuf = device.makeBuffer(length: count * MemoryLayout<Float>.size, options: .storageModeShared)
        else { return nil }

        var params = MetalSolverParams(
            nz: UInt32(nz), nr: UInt32(nr),
            dr: Float(dr), dz: Float(dz),
            omega: 0, topPressure: 0, botPressure: 0, color: 0,
            mu: Float(mu)
        )

        let tgSize = safeThreadgroupSize(pipeline: pipeline, gridWidth: nr, gridHeight: nz)
        let tgCount = threadgroupCount(gridWidth: nr, gridHeight: nz, tgSize: tgSize)

        guard let cmdBuf = queue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return nil }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pBuf, offset: 0, index: 0)
        encoder.setBuffer(kBuf, offset: 0, index: 1)
        encoder.setBuffer(vrBuf, offset: 0, index: 2)
        encoder.setBuffer(vzBuf, offset: 0, index: 3)
        encoder.setBuffer(vmagBuf, offset: 0, index: 4)
        encoder.setBytes(&params, length: MemoryLayout<MetalSolverParams>.size, index: 5)
        encoder.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        if cmdBuf.status == .error { return nil }

        let vrPtr = vrBuf.contents().bindMemory(to: Float.self, capacity: count)
        let vzPtr = vzBuf.contents().bindMemory(to: Float.self, capacity: count)
        let vmPtr = vmagBuf.contents().bindMemory(to: Float.self, capacity: count)

        return (
            vr: Array(UnsafeBufferPointer(start: vrPtr, count: count)),
            vz: Array(UnsafeBufferPointer(start: vzPtr, count: count)),
            vmag: Array(UnsafeBufferPointer(start: vmPtr, count: count))
        )
    }

    // MARK: - GPU Permeability Field

    func buildPermField(
        nz: Int, nr: Int,
        dr: Double, radiusM: Double,
        baseK: Double,
        variationScale: Double,
        moistureContent: Double,
        holeCount: Int,
        holeDiameter: Double,
        basketDiameter: Double,
        seed: UInt32 = 42
    ) -> [Float]? {
        guard let device, let queue = commandQueue, let pipeline = permPipeline else { return nil }

        let count = nz * nr
        guard let kBuf = device.makeBuffer(length: count * MemoryLayout<Float>.size, options: .storageModeShared)
        else { return nil }

        var params = MetalPermParams(
            nz: UInt32(nz), nr: UInt32(nr),
            dr: Float(dr), radiusM: Float(radiusM),
            baseK: Float(baseK),
            variationScale: Float(variationScale),
            moistureContent: Float(moistureContent),
            holeCount: Float(holeCount),
            holeDiameter: Float(holeDiameter),
            basketDiameter: Float(basketDiameter),
            seed: seed
        )

        let tgSize = safeThreadgroupSize(pipeline: pipeline, gridWidth: nr, gridHeight: nz)
        let tgCount = threadgroupCount(gridWidth: nr, gridHeight: nz, tgSize: tgSize)

        guard let cmdBuf = queue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return nil }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(kBuf, offset: 0, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<MetalPermParams>.size, index: 1)
        encoder.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        if cmdBuf.status == .error { return nil }

        let ptr = kBuf.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    }
}
