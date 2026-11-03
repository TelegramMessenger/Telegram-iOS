import Foundation
import Metal
import MetalEngine

private final class LiquidGlassShapesBundleMarker: NSObject {
}

private let metalLibraryLock = NSLock()
private var metalLibraryValue: (device: MTLDevice, library: MTLLibrary)?

/// The module's shaders, compiled at build time into LiquidGlassShapesMetalSourcesBundle's default.metallib.
/// Safe to call from any thread.
private func liquidGlassShapesMetalLibrary(device: MTLDevice) -> MTLLibrary? {
    metalLibraryLock.lock()
    defer {
        metalLibraryLock.unlock()
    }
    if let metalLibraryValue, metalLibraryValue.device === device {
        return metalLibraryValue.library
    }
    let mainBundle = Bundle(for: LiquidGlassShapesBundleMarker.self)
    guard let path = mainBundle.path(forResource: "LiquidGlassShapesMetalSourcesBundle", ofType: "bundle"), let bundle = Bundle(path: path) else {
        return nil
    }
    guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }
    metalLibraryValue = (device, library)
    return library
}

protocol LiquidGlassShapesPass {
    static var fragmentFunctionName: String { get }
}

enum LiquidGlassContentPass: LiquidGlassShapesPass {
    static let fragmentFunctionName = "liquidGlassShapesContentFragment"
}

enum LiquidGlassMultiplyPass: LiquidGlassShapesPass {
    static let fragmentFunctionName = "liquidGlassShapesMultiplyFragment"
}

enum LiquidGlassBackdropMaskPass: LiquidGlassShapesPass {
    static let fragmentFunctionName = "liquidGlassShapesMaskFragment"
}

enum LiquidGlassDisplacementPass: LiquidGlassShapesPass {
    static let fragmentFunctionName = "liquidGlassShapesDisplacementFragment"
}

/// One way of describing shapes: the kernel that samples them and the specialization of the render passes that
/// reads those samples.
protocol LiquidGlassShapesKind {
    static var shapeKind: LiquidGlassShapeKind { get }
    static var kernelFunctionName: String { get }
    static var sampleCount: Int { get }
}

enum LiquidGlassCrestKind: LiquidGlassShapesKind {
    static let shapeKind: LiquidGlassShapeKind = .crest
    static let kernelFunctionName = "liquidGlassCrestKernel"
    static let sampleCount = LiquidGlassShapesConstants.crestSampleCount
}

enum LiquidGlassRadialKind: LiquidGlassShapesKind {
    static let shapeKind: LiquidGlassShapeKind = .radial
    static let kernelFunctionName = "liquidGlassRadialKernel"
    static let sampleCount = LiquidGlassShapesConstants.radialSampleCount
}

/// The pipelines, made through MetalEngine's pipeline cache: compiled once per app version (in the background, see
/// `prewarmLiquidGlassShapes`) and loaded from the cache's archive afterwards, so the frame a layer first appears in
/// never compiles them.
final class LiquidGlassShapesPipelines {
    static let shared = LiquidGlassShapesPipelines()

    /// The passes a layer can use on this OS: the multiply, mask and displacement passes are the iOS 26 glass style.
    static var usedFragmentFunctionNames: [String] {
        if #available(iOS 26.0, *) {
            return [
                LiquidGlassContentPass.fragmentFunctionName,
                LiquidGlassMultiplyPass.fragmentFunctionName,
                LiquidGlassBackdropMaskPass.fragmentFunctionName,
                LiquidGlassDisplacementPass.fragmentFunctionName
            ]
        } else {
            return [LiquidGlassContentPass.fragmentFunctionName]
        }
    }

    private struct RenderPipelineKey: Hashable {
        var fragmentFunctionName: String
        var shapeKind: LiquidGlassShapeKind
    }

    private let lock = NSLock()
    private var renderPipelineStates: [RenderPipelineKey: MTLRenderPipelineState] = [:]
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    private var prewarmedShapeKinds = Set<LiquidGlassShapeKind>()

    func prewarm(device: MTLDevice, shapeKinds: [LiquidGlassShapeKind], qos: DispatchQoS.QoSClass) {
        self.lock.lock()
        let kinds = shapeKinds.filter { !self.prewarmedShapeKinds.contains($0) }
        self.prewarmedShapeKinds.formUnion(kinds)
        self.lock.unlock()

        if kinds.isEmpty {
            return
        }
        DispatchQueue.global(qos: qos).async {
            for shapeKind in kinds {
                let kind: LiquidGlassShapesKind.Type
                switch shapeKind {
                case .crest:
                    kind = LiquidGlassCrestKind.self
                case .radial:
                    kind = LiquidGlassRadialKind.self
                }
                let _ = self.computePipelineState(device: device, functionName: kind.kernelFunctionName)
                for fragmentFunctionName in LiquidGlassShapesPipelines.usedFragmentFunctionNames {
                    let _ = self.renderPipelineState(device: device, fragmentFunctionName: fragmentFunctionName, shapeKind: shapeKind)
                }
            }
        }
    }

    /// Compiles on the calling thread if the pipeline is not ready yet.
    func renderPipelineState(device: MTLDevice, fragmentFunctionName: String, shapeKind: LiquidGlassShapeKind) -> MTLRenderPipelineState? {
        let key = RenderPipelineKey(fragmentFunctionName: fragmentFunctionName, shapeKind: shapeKind)
        self.lock.lock()
        let cached = self.renderPipelineStates[key]
        self.lock.unlock()
        if let cached {
            return cached
        }

        guard let library = liquidGlassShapesMetalLibrary(device: device) else {
            return nil
        }
        // The shape kind is function constant 0 of every fragment function.
        let constantValues = MTLFunctionConstantValues()
        var shapeKindValue = shapeKind.rawValue
        constantValues.setConstantValue(&shapeKindValue, type: .int, index: 0)
        guard let vertexFunction = library.makeFunction(name: "liquidGlassShapesVertex"), let fragmentFunction = try? library.makeFunction(name: fragmentFunctionName, constantValues: constantValues) else {
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        // Every pixel of the allocation is written, so no blending.
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.lock.lock()
        self.renderPipelineStates[key] = pipelineState
        self.lock.unlock()
        return pipelineState
    }

    /// Compiles on the calling thread if the pipeline is not ready yet.
    func computePipelineState(device: MTLDevice, functionName: String) -> MTLComputePipelineState? {
        self.lock.lock()
        let cached = self.computePipelineStates[functionName]
        self.lock.unlock()
        if let cached {
            return cached
        }

        guard let library = liquidGlassShapesMetalLibrary(device: device), let function = library.makeFunction(name: functionName) else {
            return nil
        }
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = function
        guard let pipelineState = MetalEngine.shared.pipelineCache.makeComputePipelineState(descriptor: descriptor) else {
            return nil
        }

        self.lock.lock()
        self.computePipelineStates[functionName] = pipelineState
        self.lock.unlock()
        return pipelineState
    }
}

/// Makes the pipelines for shapes of `shapeKinds` in the background, well before a layer can need them: crests for
/// the call status bar when a call starts (and at a lower priority on the first start after an update), radial shapes
/// for the recording blob when the chat input appears. Each kind is made once per process.
public func prewarmLiquidGlassShapes(_ shapeKinds: [LiquidGlassShapeKind], qos: DispatchQoS.QoSClass = .userInitiated) {
    LiquidGlassShapesPipelines.shared.prewarm(device: MetalEngine.shared.device, shapeKinds: shapeKinds, qos: qos)
}

/// MetalEngine keeps one render state per type, so each pass and shape kind is its own specialization.
final class LiquidGlassShapesRenderState<Pass: LiquidGlassShapesPass, Kind: LiquidGlassShapesKind>: RenderToLayerState {
    let pipelineState: MTLRenderPipelineState

    init?(device: MTLDevice) {
        guard let pipelineState = LiquidGlassShapesPipelines.shared.renderPipelineState(device: device, fragmentFunctionName: Pass.fragmentFunctionName, shapeKind: Kind.shapeKind) else {
            return nil
        }
        self.pipelineState = pipelineState
    }
}

final class LiquidGlassShapesComputeState<Kind: LiquidGlassShapesKind>: ComputeState {
    let pipelineState: MTLComputePipelineState

    init?(device: MTLDevice) {
        guard let pipelineState = LiquidGlassShapesPipelines.shared.computePipelineState(device: device, functionName: Kind.kernelFunctionName) else {
            return nil
        }
        self.pipelineState = pipelineState
    }
}
