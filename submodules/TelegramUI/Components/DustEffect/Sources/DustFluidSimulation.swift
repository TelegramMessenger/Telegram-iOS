import Foundation
import Metal

// The air the dust is blown into: a coarse 2D fluid simulation on the GPU whose velocity field carries the particles,
// so they drift off in soft, uneven currents instead of flying in straight lines. Positions are in layer points with the origin at the
// bottom left (the particle space of DustEffectLayer); time is the particles' simulation time.
//
// Kept free of UIKit and MetalEngine so it can be driven by a plain Metal command encoder.
final class DustFluidSimulation {
    struct Splat {
        var position: SIMD2<Float>
        var force: SIMD2<Float>
        var radius: Float
        var padding: Float = 0.0
        
        init(position: SIMD2<Float>, force: SIMD2<Float>, radius: Float) {
            self.position = position
            self.force = force
            self.radius = radius
        }
    }
    
    final class Pipelines {
        let clear: MTLComputePipelineState
        let splat: MTLComputePipelineState
        let curl: MTLComputePipelineState
        let divergence: MTLComputePipelineState
        let pressure: MTLComputePipelineState
        let gradientSubtract: MTLComputePipelineState
        let advect: MTLComputePipelineState
        let streamFunction: MTLComputePipelineState
        
        init?(library: MTLLibrary, makePipelineState: (MTLFunction) -> MTLComputePipelineState?) {
            func make(_ name: String) -> MTLComputePipelineState? {
                guard let function = library.makeFunction(name: name) else {
                    return nil
                }
                return makePipelineState(function)
            }
            
            guard let clear = make("dustFluidClear"), let splat = make("dustFluidSplat"), let curl = make("dustFluidCurl"), let divergence = make("dustFluidDivergence"), let pressure = make("dustFluidPressure"), let gradientSubtract = make("dustFluidGradientSubtract"), let advect = make("dustFluidAdvect"), let streamFunction = make("dustFluidStreamFunction") else {
                return nil
            }
            self.clear = clear
            self.splat = splat
            self.curl = curl
            self.divergence = divergence
            self.pressure = pressure
            self.gradientSubtract = gradientSubtract
            self.advect = advect
            self.streamFunction = streamFunction
        }
    }
    
    private struct Params {
        var timeStep: Float
        var velocityDissipation: Float
        var pressureScale: Float
    }
    
    private static let preferredCellSize: Float = 3.0
    private static let maxGridDimension: Float = 256.0
    private static let maxSplatCount = 128
    
    // Tuned for a grid of a few points per cell.
    private static let velocityDissipation: Float = 0.2
    private static let pressureDecay: Float = 0.8
    private static let pressureIterations = 20
    private static let maxStep: Float = 1.0 / 60.0
    private static let streamFunctionIterations = 30
    
    let size: SIMD2<Float>
    let cellSize: Float
    let gridWidth: Int
    let gridHeight: Int
    
    private var velocity: [MTLTexture]
    private var pressure: [MTLTexture]
    private let divergence: MTLTexture
    private let curl: MTLTexture
    private var streamFunction: [MTLTexture]
    private var isCleared: Bool = false
    
    // The stream function of the flow, one value per cell (centered at (i + 0.5, j + 0.5) * cellSize), in cells^2 per
    // second. The velocity of the air is (d/dy, -d/dx) of it.
    var streamFunctionTexture: MTLTexture {
        return self.streamFunction[0]
    }
    
    init?(device: MTLDevice, size: SIMD2<Float>) {
        if size.x <= 0.0 || size.y <= 0.0 {
            return nil
        }
        
        let cellSize = max(DustFluidSimulation.preferredCellSize, max(size.x, size.y) / DustFluidSimulation.maxGridDimension)
        let gridWidth = max(1, Int((size.x / cellSize).rounded(.up)))
        let gridHeight = max(1, Int((size.y / cellSize).rounded(.up)))
        self.size = size
        self.cellSize = cellSize
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        
        func makeTexture(_ pixelFormat: MTLPixelFormat, _ label: String) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: gridWidth, height: gridHeight, mipmapped: false)
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite]
            let texture = device.makeTexture(descriptor: descriptor)
            texture?.label = label
            return texture
        }
        
        guard let velocity0 = makeTexture(.rg16Float, "DustFluid.velocity0"), let velocity1 = makeTexture(.rg16Float, "DustFluid.velocity1"), let pressure0 = makeTexture(.r16Float, "DustFluid.pressure0"), let pressure1 = makeTexture(.r16Float, "DustFluid.pressure1"), let divergence = makeTexture(.r16Float, "DustFluid.divergence"), let curl = makeTexture(.r16Float, "DustFluid.curl"), let streamFunction0 = makeTexture(.r32Float, "DustFluid.streamFunction0"), let streamFunction1 = makeTexture(.r32Float, "DustFluid.streamFunction1") else {
            return nil
        }
        self.velocity = [velocity0, velocity1]
        self.pressure = [pressure0, pressure1]
        self.divergence = divergence
        self.curl = curl
        self.streamFunction = [streamFunction0, streamFunction1]
    }
    
    func encode(encoder: MTLComputeCommandEncoder, pipelines: Pipelines, timeStep: Float, splats: [Splat]) {
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupCount = MTLSize(width: (self.gridWidth + threadgroupSize.width - 1) / threadgroupSize.width, height: (self.gridHeight + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
        
        func dispatch(_ pipeline: MTLComputePipelineState, _ textures: [MTLTexture]) {
            encoder.setComputePipelineState(pipeline)
            for i in 0 ..< textures.count {
                encoder.setTexture(textures[i], index: i)
            }
            encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        }
        
        if !self.isCleared {
            self.isCleared = true
            for texture in self.velocity + self.pressure + self.streamFunction + [self.divergence, self.curl] {
                dispatch(pipelines.clear, [texture])
            }
        }
        
        if !splats.isEmpty {
            var gridSplats = splats.suffix(DustFluidSimulation.maxSplatCount).map { splat -> Splat in
                return Splat(position: splat.position / self.cellSize, force: splat.force / self.cellSize, radius: splat.radius / self.cellSize)
            }
            var splatCount = UInt32(gridSplats.count)
            encoder.setBytes(&gridSplats, length: MemoryLayout<Splat>.stride * gridSplats.count, index: 0)
            encoder.setBytes(&splatCount, length: 4, index: 1)
            dispatch(pipelines.splat, [self.velocity[0], self.velocity[1]])
            self.velocity.swapAt(0, 1)
        }
        
        if timeStep <= 0.0 {
            return
        }
        
        let stepCount = min(4, Int((timeStep / DustFluidSimulation.maxStep).rounded(.up)))
        var params = Params(timeStep: timeStep / Float(stepCount), velocityDissipation: DustFluidSimulation.velocityDissipation, pressureScale: DustFluidSimulation.pressureDecay)
        
        for _ in 0 ..< stepCount {
            dispatch(pipelines.divergence, [self.velocity[0], self.divergence])
            
            for i in 0 ..< DustFluidSimulation.pressureIterations {
                params.pressureScale = i == 0 ? DustFluidSimulation.pressureDecay : 1.0
                encoder.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)
                dispatch(pipelines.pressure, [self.pressure[0], self.divergence, self.pressure[1]])
                self.pressure.swapAt(0, 1)
            }
            
            dispatch(pipelines.gradientSubtract, [self.pressure[0], self.velocity[0], self.velocity[1]])
            self.velocity.swapAt(0, 1)
            
            encoder.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)
            dispatch(pipelines.advect, [self.velocity[0], self.velocity[1]])
            self.velocity.swapAt(0, 1)
        }
        
        // Starts from the previous frame's solution, which is close: the flow changes little in a frame.
        dispatch(pipelines.curl, [self.velocity[0], self.curl])
        for _ in 0 ..< DustFluidSimulation.streamFunctionIterations {
            dispatch(pipelines.streamFunction, [self.streamFunction[0], self.curl, self.streamFunction[1]])
            self.streamFunction.swapAt(0, 1)
        }
    }
}

extension DustFluidSimulation {
    // Follows the sweep in dustEffectUpdateParticle: a band of `releaseWindow` (in fractions of the item width) moves
    // from left to right while the phase goes from 0 to `sweepDuration`, setting the pixels under it in motion. (The
    // shader also mixes some noise into where each grain comes loose; the pushes only need to land roughly there.)
    static let sweepDuration: Float = 0.8
    static let releaseWindow: Float = 0.8
    
    private static let areaPerSplat: Float = 700.0
    private static let initialSplatCount: Int = 3
    
    static func sweepProgress(phase: Float) -> Float {
        return max(0.0, min(1.0, phase / DustFluidSimulation.sweepDuration))
    }
    
    // The pushes that stir the air where an item is coming apart. `itemOrigin` and `itemSize` are in layer points
    // (origin at the bottom left); the sweep has advanced from `previousPhase` to `phase`.
    static func dissolveSplats<Generator: RandomNumberGenerator>(itemOrigin: SIMD2<Float>, itemSize: SIMD2<Float>, previousPhase: Float, phase: Float, verticalDirection: Float, generator: inout Generator) -> [Splat] {
        let previousProgress = DustFluidSimulation.sweepProgress(phase: previousPhase)
        let progress = DustFluidSimulation.sweepProgress(phase: phase)
        if progress <= previousProgress && previousPhase > 0.0 {
            return []
        }
        
        var result: [Splat] = []
        
        func makeSplat(xFraction: Float, magnitude: ClosedRange<Float>, spread: Float) -> Splat {
            let position = itemOrigin + SIMD2<Float>(xFraction * itemSize.x, Float.random(in: 0.0 ... 1.0, using: &generator) * itemSize.y)
            let angle = Float.pi * 0.5 + Float.random(in: -spread ... spread, using: &generator)
            let force = SIMD2<Float>(cos(angle), sin(angle) * verticalDirection) * Float.random(in: magnitude, using: &generator)
            return Splat(position: position, force: force, radius: Float.random(in: 10.0 ... 18.0, using: &generator))
        }
        
        if previousPhase <= 0.0 {
            for _ in 0 ..< DustFluidSimulation.initialSplatCount {
                result.append(makeSplat(xFraction: Float.random(in: 0.0 ... 1.0, using: &generator), magnitude: 9.0 ... 22.0, spread: Float.pi))
            }
        }
        
        let totalCount = max(4.0, itemSize.x * itemSize.y / DustFluidSimulation.areaPerSplat)
        let count = Int(totalCount * progress) - Int(totalCount * previousProgress)
        if count > 0 {
            let windowPosition = -DustFluidSimulation.releaseWindow + (1.0 + DustFluidSimulation.releaseWindow) * progress
            let lowerBound = max(0.0, windowPosition)
            let upperBound = min(1.0, windowPosition + DustFluidSimulation.releaseWindow)
            for _ in 0 ..< count {
                let xFraction = lowerBound < upperBound ? Float.random(in: lowerBound ... upperBound, using: &generator) : lowerBound
                result.append(makeSplat(xFraction: xFraction, magnitude: 22.0 ... 56.0, spread: Float.pi * 0.3))
            }
        }
        
        return result
    }
}
