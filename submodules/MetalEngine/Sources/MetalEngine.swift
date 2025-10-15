import Foundation
import Metal

#if os(iOS)
import Display
import UIKit
#else
import AppKit
import TGUIKit
#endif


import IOSurface
import ShelfPack

public final class Placeholder<Resolved> {
    var contents: Resolved?
}

private let noInputPlaceholder: Placeholder<Void> = {
    let value = Placeholder<Void>()
    value.contents = Void()
    return value
}()

private struct PlaceholderResolveError: Error {
}

private func resolvePlaceholder<T>(_ value: Placeholder<T>) throws -> T {
    guard let contents = value.contents else {
        throw PlaceholderResolveError()
    }
    return contents
}

public struct TextureSpec: Equatable {
    public enum PixelFormat {
        case r8UnsignedNormalized
        case rgba8UnsignedNormalized
    }
    
    public var width: Int
    public var height: Int
    public var pixelFormat: PixelFormat
    
    public init(width: Int, height: Int, pixelFormat: PixelFormat) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
    }
}

extension TextureSpec.PixelFormat {
    var metalFormat: MTLPixelFormat {
        switch self {
        case .r8UnsignedNormalized:
            return .r8Unorm
        case .rgba8UnsignedNormalized:
            return .rgba8Unorm
        }
    }
}

public final class TexturePlaceholder {
    public let placeholer: Placeholder<MTLTexture?>
    public let spec: TextureSpec
    
    init(placeholer: Placeholder<MTLTexture?>, spec: TextureSpec) {
        self.placeholer = placeholer
        self.spec = spec
    }
}

public struct RenderSize: Equatable {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct RenderLayerSpec: Equatable {
    public var size: RenderSize
    public var edgeInset: Int
    
    public init(size: RenderSize, edgeInset: Int = 0) {
        self.size = size
        self.edgeInset = edgeInset
    }
}

private extension RenderLayerSpec {
    var allocationWidth: Int {
        return self.size.width + self.edgeInset * 2
    }
    
    var allocationHeight: Int {
        return self.size.height + self.edgeInset * 2
    }
}

public struct RenderLayerPlacement: Equatable {
    public var effectiveRect: CGRect
    
    public init(effectiveRect: CGRect) {
        self.effectiveRect = effectiveRect
    }
}

public protocol RenderToLayerState: AnyObject {
    var pipelineState: MTLRenderPipelineState { get }
    
    init?(device: MTLDevice)
}

public protocol ComputeState: AnyObject {
    init?(device: MTLDevice)
}

open class MetalEngineSubjectLayer: SimpleLayer {
    fileprivate var internalId: Int = -1
    fileprivate var surfaceAllocation: MetalEngine.SurfaceAllocation?
    
    #if DEBUG
    fileprivate var surfaceChangeFrameCount: Int = 0
    #endif
    
    public var cloneLayers: [CALayer] = []
    
    override open var contents: Any? {
        didSet {
            if !self.cloneLayers.isEmpty {
                for cloneLayer in self.cloneLayers {
                    cloneLayer.contents = self.contents
                }
            }
        }
    }
    
    override open var contentsRect: CGRect {
        didSet {
            if !self.cloneLayers.isEmpty {
                for cloneLayer in self.cloneLayers {
                    cloneLayer.contentsRect = self.contentsRect
                }
            }
        }
    }
    
    public override init() {
        super.init()
        
        self.setNeedsDisplay()
    }
    
    deinit {
        MetalEngine.shared.impl.removeLayerSurfaceAllocation(layer: self)
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func setNeedsDisplay() {
        if let subject = self as? MetalEngineSubject {
            subject.setNeedsUpdate()
        }
    }
}

protocol MetalEngineResource: AnyObject {
    func free()
}

public final class PooledTexture {
    final class Texture: MetalEngineResource {
        let value: MTLTexture
        var isInUse: Bool = false
        
        init(value: MTLTexture) {
            self.value = value
        }
        
        public func free() {
            self.isInUse = false
        }
    }
    
    public let spec: TextureSpec
    
    private let textures: [Texture]
    
    init(device: MTLDevice, spec: TextureSpec) {
        self.spec = spec
        
        self.textures = (0 ..< 3).compactMap { _ -> Texture? in
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: spec.pixelFormat.metalFormat, width: spec.width, height: spec.height, mipmapped: false)
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite]
            
            guard let texture = device.makeTexture(descriptor: descriptor) else {
                return nil
            }
            return Texture(value: texture)
        }
    }
    
    public func get(context: MetalEngineSubjectContext) -> TexturePlaceholder? {
        #if DEBUG
        if context.freeResourcesOnCompletion.contains(where: { $0 === self }) {
            assertionFailure("Trying to get PooledTexture more than once per update cycle")
        }
        #endif
        
        for texture in self.textures {
            if !texture.isInUse {
                texture.isInUse = true
                let placeholder = Placeholder<MTLTexture?>()
                placeholder.contents = texture.value
                context.freeResourcesOnCompletion.append(texture)
                return TexturePlaceholder(placeholer: placeholder, spec: self.spec)
            }
        }
        
        print("PooledTexture: all textures are in use")
        return nil
    }
}

public struct BufferSpec: Equatable {
    public var length: Int
    
    public init(length: Int) {
        self.length = length
    }
}

public final class BufferPlaceholder {
    public let placeholer: Placeholder<MTLBuffer?>
    public let spec: BufferSpec
    
    init(placeholer: Placeholder<MTLBuffer?>, spec: BufferSpec) {
        self.placeholer = placeholer
        self.spec = spec
    }
}

public final class PooledBuffer {
    final class Buffer: MetalEngineResource {
        let value: MTLBuffer
        var isInUse: Bool = false
        
        init(value: MTLBuffer) {
            self.value = value
        }
        
        public func free() {
            self.isInUse = false
        }
    }
    
    public let spec: BufferSpec
    
    private let buffers: [Buffer]
    
    init(device: MTLDevice, spec: BufferSpec) {
        self.spec = spec
        
        self.buffers = (0 ..< 3).compactMap { _ -> Buffer? in
            guard let texture = device.makeBuffer(length: spec.length, options: [.storageModePrivate]) else {
                return nil
            }
            return Buffer(value: texture)
        }
    }
    
    public func get(context: MetalEngineSubjectContext) -> BufferPlaceholder? {
        #if DEBUG
        if context.freeResourcesOnCompletion.contains(where: { $0 === self }) {
            assertionFailure("Trying to get PooledTexture more than once per update cycle")
        }
        #endif
        
        for buffer in self.buffers {
            if !buffer.isInUse {
                buffer.isInUse = true
                let placeholder = Placeholder<MTLBuffer?>()
                placeholder.contents = buffer.value
                context.freeResourcesOnCompletion.append(buffer)
                return BufferPlaceholder(placeholer: placeholder, spec: self.spec)
            }
        }
        
        print("PooledBuffer: all textures are in use")
        return nil
    }
}

public final class SharedBuffer {
    public let buffer: MTLBuffer
    
    init?(device: MTLDevice, spec: BufferSpec) {
        guard let buffer = device.makeBuffer(length: spec.length, options: [.storageModeShared]) else {
            return nil
        }
        self.buffer = buffer
    }
}

public final class MetalEngineSubjectContext {
    fileprivate final class ComputeOperation {
        let commands: (MTLCommandBuffer) -> Void
        
        init(commands: @escaping (MTLCommandBuffer) -> Void) {
            self.commands = commands
        }
    }
    
    fileprivate final class RenderToLayerOperation {
        let spec: RenderLayerSpec
        let state: RenderToLayerState
        weak var layer: MetalEngineSubjectLayer?
        let commands: (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
        
        init(
            spec: RenderLayerSpec,
            state: RenderToLayerState,
            layer: MetalEngineSubjectLayer,
            commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
        ) {
            self.spec = spec
            self.state = state
            self.layer = layer
            self.commands = commands
        }
    }
    
    private let device: MTLDevice
    private let impl: MetalEngine.Impl
    
    fileprivate var computeOperations: [ComputeOperation] = []
    fileprivate var renderToLayerOperationsGroupedByState: [ObjectIdentifier: [RenderToLayerOperation]] = [:]
    fileprivate var freeResourcesOnCompletion: [MetalEngineResource] = []
    fileprivate var customCompletions: [() -> Void] = []
    
    fileprivate init(device: MTLDevice, impl: MetalEngine.Impl) {
        self.device = device
        self.impl = impl
    }
    
    public func renderToLayer<RenderToLayerStateType: RenderToLayerState, each Resolved>(
        spec: RenderLayerSpec,
        state: RenderToLayerStateType.Type,
        layer: MetalEngineSubjectLayer,
        inputs: repeat Placeholder<each Resolved>,
        commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement, repeat each Resolved) -> Void
    ) {
        let stateTypeId = ObjectIdentifier(state)
        let resolvedState: RenderToLayerStateType
        if let current = self.impl.renderStates[stateTypeId] as? RenderToLayerStateType {
            resolvedState = current
        } else {
            guard let value = RenderToLayerStateType(device: self.device) else {
                assertionFailure("Could not initialize render state \(state)")
                return
            }
            resolvedState = value
            self.impl.renderStates[stateTypeId] = resolvedState
        }
        
        let operation = RenderToLayerOperation(
            spec: spec,
            state: resolvedState,
            layer: layer,
            commands: { encoder, placement in
                let resolvedInputs: (repeat each Resolved)
                do {
                    resolvedInputs = (repeat try resolvePlaceholder(each inputs))
                } catch {
                    print("Could not resolve renderToLayer inputs")
                    return
                }
                commands(encoder, placement, repeat each resolvedInputs)
            }
        )
        if self.renderToLayerOperationsGroupedByState[stateTypeId] == nil {
            self.renderToLayerOperationsGroupedByState[stateTypeId] = [operation]
        } else {
            self.renderToLayerOperationsGroupedByState[stateTypeId]?.append(operation)
        }
    }
    
    public func renderToLayer<RenderToLayerStateType: RenderToLayerState>(
        spec: RenderLayerSpec,
        state: RenderToLayerStateType.Type,
        layer: MetalEngineSubjectLayer,
        commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
    ) {
        self.renderToLayer(spec: spec, state: state, layer: layer, inputs: noInputPlaceholder, commands: { encoder, placement, _ in
            commands(encoder, placement)
        })
    }
    
    public func compute<ComputeStateType: ComputeState, each Resolved, Output>(
        state: ComputeStateType.Type,
        inputs: repeat Placeholder<each Resolved>,
        commands: @escaping (MTLCommandBuffer, ComputeStateType, repeat each Resolved) -> Output
    ) -> Placeholder<Output> {
        let stateTypeId = ObjectIdentifier(state)
        let resolvedState: ComputeStateType
        if let current = self.impl.computeStates[stateTypeId] as? ComputeStateType {
            resolvedState = current
        } else {
            guard let value = ComputeStateType(device: self.device) else {
                assertionFailure("Could not initialize compute state \(state)")
                return Placeholder()
            }
            resolvedState = value
            self.impl.computeStates[stateTypeId] = resolvedState
        }
        
        let resultPlaceholder = Placeholder<Output>()
        self.computeOperations.append(ComputeOperation(commands: { commandBuffer in
            let resolvedInputs: (repeat each Resolved)
            do {
                resolvedInputs = (repeat try resolvePlaceholder(each inputs))
            } catch {
                print("Could not resolve renderToLayer inputs")
                return
            }
            resultPlaceholder.contents = commands(commandBuffer, resolvedState, repeat each resolvedInputs)
        }))
        return resultPlaceholder
    }
    
    public func compute<ComputeStateType: ComputeState, Output>(
        state: ComputeStateType.Type,
        commands: @escaping (MTLCommandBuffer, ComputeStateType) -> Output
    ) -> Placeholder<Output> {
        return self.compute(state: state, inputs: noInputPlaceholder, commands: { commandBuffer, state, _ in
            return commands(commandBuffer, state)
        })
    }
    
    public func addCustomCompletion(_ customCompletion: @escaping () -> Void) {
        self.customCompletions.append(customCompletion)
    }
}

public final class MetalEngineSubjectInternalData {
    var internalId: Int = -1
    var renderSurfaceAllocation: MetalEngine.SurfaceAllocation?
    
    init() {
    }
}

public protocol MetalEngineSubject: AnyObject {
    var internalData: MetalEngineSubjectInternalData? { get set }
    
    func setNeedsUpdate()
    func update(context: MetalEngineSubjectContext)
}

public extension MetalEngineSubject {
    func setNeedsUpdate() {
        MetalEngine.shared.impl.addSubjectNeedsUpdate(subject: self)
    }
}

#if targetEnvironment(simulator)
@available(iOS 13.0, *)
#endif
private final class MetalEventLayer: CAMetalLayer {
    var onDisplay: (() -> Void)?
    
    override func display() {
        self.onDisplay?()
    }
}

public final class MetalEngine {
    struct SurfaceAllocation {
        struct Phase {
            let subRect: CGRect
            let renderingRect: CGRect
            let contentsRect: CGRect
        }
        
        let surfaceId: Int
        let allocationId0: Int32
        let allocationId1: Int32
        let renderingParameters: RenderLayerSpec
        let phase0: Phase
        let phase1: Phase
        var currentPhase: Int = 0
        
        var effectivePhase: Phase {
            if self.currentPhase == 0 {
                return self.phase0
            } else {
                return self.phase1
            }
        }
        
        init(surfaceId: Int, allocationId0: Int32, allocationId1: Int32, renderingParameters: RenderLayerSpec, phase0: Phase, phase1: Phase) {
            self.surfaceId = surfaceId
            self.allocationId0 = allocationId0
            self.allocationId1 = allocationId1
            self.renderingParameters = renderingParameters
            self.phase0 = phase0
            self.phase1 = phase1
        }
    }
    
    fileprivate final class Surface {
        let id: Int
        let width: Int
        let height: Int
        
        let ioSurface: IOSurface
        let texture: MTLTexture
        let packContext: ShelfPackContext
        
        var isEmpty: Bool {
            return self.packContext.isEmpty
        }
        
        init?(id: Int, device: MTLDevice, width: Int, height: Int) {
            self.id = id
            self.width = width
            self.height = height
            
            self.packContext = ShelfPackContext(width: Int32(width), height: Int32(height))
            
            let ioSurfaceProperties: [String: Any] = [
                kIOSurfaceWidth as String: width,
                kIOSurfaceHeight as String: height,
                kIOSurfaceBytesPerElement as String: 4,
                kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA
            ]
            guard let ioSurface = IOSurfaceCreate(ioSurfaceProperties as CFDictionary) else {
                return nil
            }
            self.ioSurface = ioSurface
            
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.width = Int(width)
            textureDescriptor.height = Int(height)
            textureDescriptor.storageMode = .shared
            textureDescriptor.usage = .renderTarget
            
            guard let texture = device.makeTexture(descriptor: textureDescriptor, iosurface: ioSurface, plane: 0) else {
                return nil
            }
            self.texture = texture
        }
        
        private struct AllocationLayout {
            let subRect: CGRect
            let renderingRect: CGRect
            let contentsRect: CGRect
            
            init(baseRect: CGRect, edgeSize: CGFloat, surfaceWidth: Int, surfaceHeight: Int) {
                self.subRect = CGRect(origin: CGPoint(x: baseRect.minX, y: baseRect.minY), size: CGSize(width: baseRect.width, height: baseRect.height))
                self.renderingRect = CGRect(origin: CGPoint(x: self.subRect.minX / CGFloat(surfaceWidth), y: self.subRect.minY / CGFloat(surfaceHeight)), size: CGSize(width: self.subRect.width / CGFloat(surfaceWidth), height: self.subRect.height / CGFloat(surfaceHeight)))
                
                let subRectWithInset = self.subRect.insetBy(dx: edgeSize, dy: edgeSize)
                
                self.contentsRect = CGRect(origin: CGPoint(x: subRectWithInset.minX / CGFloat(surfaceWidth), y: 1.0 - subRectWithInset.minY / CGFloat(surfaceHeight) - subRectWithInset.height / CGFloat(surfaceHeight)), size: CGSize(width: subRectWithInset.width / CGFloat(surfaceWidth), height: subRectWithInset.height / CGFloat(surfaceHeight)))
            }
        }
        
        func allocateIfPossible(renderingParameters: RenderLayerSpec) -> SurfaceAllocation? {
            let width = renderingParameters.allocationWidth
            let height = renderingParameters.allocationHeight
            
            let item0 = self.packContext.addItem(withWidth: Int32(width), height: Int32(height))
            let item1 = self.packContext.addItem(withWidth: Int32(width), height: Int32(height))
            
            if item0.itemId != -1 && item1.itemId != -1 {
                let layout0 = AllocationLayout(
                    baseRect: CGRect(origin: CGPoint(x: CGFloat(item0.x), y: CGFloat(item0.y)), size: CGSize(width: CGFloat(item0.width), height: CGFloat(item0.height))),
                    edgeSize: CGFloat(renderingParameters.edgeInset),
                    surfaceWidth: self.width,
                    surfaceHeight: self.height
                )
                let layout1 = AllocationLayout(
                    baseRect: CGRect(origin: CGPoint(x: CGFloat(item1.x), y: CGFloat(item1.y)), size: CGSize(width: CGFloat(item1.width), height: CGFloat(item1.height))),
                    edgeSize: CGFloat(renderingParameters.edgeInset),
                    surfaceWidth: self.width,
                    surfaceHeight: self.height
                )
                
                return SurfaceAllocation(
                    surfaceId: self.id,
                    allocationId0: item0.itemId,
                    allocationId1: item1.itemId,
                    renderingParameters: renderingParameters,
                    phase0: SurfaceAllocation.Phase(
                        subRect: layout0.subRect,
                        renderingRect: layout0.renderingRect,
                        contentsRect: layout0.contentsRect
                    ),
                    phase1: SurfaceAllocation.Phase(
                        subRect: layout1.subRect,
                        renderingRect: layout1.renderingRect,
                        contentsRect: layout1.contentsRect
                    )
                )
            } else {
                if item0.itemId != -1 {
                    self.packContext.removeItem(item0.itemId)
                }
                if item1.itemId != -1 {
                    self.packContext.removeItem(item1.itemId)
                }
                
                return nil
            }
        }
        
        func removeAllocation(id: Int32) {
            self.packContext.removeItem(id)
        }
    }
    
    private final class SubjectReference {
        weak var subject: MetalEngineSubject?
        
        init(subject: MetalEngineSubject) {
            self.subject = subject
        }
    }
    
    fileprivate final class Impl {
        let device: MTLDevice
        let library: MTLLibrary
        let commandQueue: MTLCommandQueue
        let clearPipelineState: MTLRenderPipelineState
        
        #if targetEnvironment(simulator)
        let _layer: CALayer
        @available(iOS 13.0, *)
        var layer: MetalEventLayer {
            return self._layer as! MetalEventLayer
        }
        #else
        let layer: MetalEventLayer
        #endif
        
        var nextSurfaceId: Int = 0
        var surfaces: [Int: Surface] = [:]
        
        private var nextLayerId: Int = 0
        
        private var nextSubjectId: Int = 0
        private var updatedSubjectIds: [Int] = []
        private var updatedSubjects: [SubjectReference] = []
        
        private var scheduledClearAllocations: [SurfaceAllocation] = []
        
        fileprivate var renderStates: [ObjectIdentifier: RenderToLayerState] = [:]
        fileprivate var computeStates: [ObjectIdentifier: ComputeState] = [:]
        
        init?(device: MTLDevice) {
            
            self.device = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                return nil
            }
            self.commandQueue = commandQueue
            
            let library: MTLLibrary?
            
            #if os(iOS)
            let mainBundle = Bundle(for: Impl.self)
            guard let path = mainBundle.path(forResource: "MetalEngineMetalSourcesBundle", ofType: "bundle") else {
                return nil
            }
            guard let bundle = Bundle(path: path) else {
                return nil
            }
            library = try? device.makeDefaultLibrary(bundle: bundle)
            #else
            library = try? device.makeDefaultLibrary(bundle: Bundle.module)
            #endif
            
            
            
            guard let lib = library else {
                return nil
            }
            self.library = lib
            
            guard let vertexFunction = lib.makeFunction(name: "clearVertex") else {
                return nil
            }
            guard let fragmentFunction = lib.makeFunction(name: "clearFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let clearPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.clearPipelineState = clearPipelineState
            
            #if targetEnvironment(simulator)
            if #available(iOS 13.0, *) {
                self._layer = MetalEventLayer()
            } else {
                self._layer = CALayer()
            }
            #else
            self.layer = MetalEventLayer()
            #endif
            
            #if targetEnvironment(simulator)
            @available(iOS 13.0, *)
            #endif
            func configureLayer(layer: MetalEventLayer, device: MTLDevice, impl: Impl) {
                layer.drawableSize = CGSize(width: 32, height: 32)
                layer.contentsScale = 1.0
                layer.device = device
                layer.presentsWithTransaction = true
                layer.framebufferOnly = false
                layer.onDisplay = { [unowned impl] in
                    impl.display()
                }
            }
            
            #if targetEnvironment(simulator)
            if #available(iOS 13.0, *) {
                configureLayer(layer: self.layer, device: self.device, impl: self)
            }
            #else
            configureLayer(layer: self.layer, device: self.device, impl: self)
            #endif
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func addSurface(width: Int, height: Int) -> Surface? {
            let surfaceId = self.nextSurfaceId
            self.nextSurfaceId += 1
            
            let surface = Surface(id: surfaceId, device: self.device, width: width, height: height)
            self.surfaces[surfaceId] = surface
            
            return surface
        }
        
        private func refreshLayerAllocation(layer: MetalEngineSubjectLayer, renderSpec: RenderLayerSpec) {
            var previousSurfaceId: Int?
            var updatedSurfaceId: Int?
            
            if let allocation = layer.surfaceAllocation {
                previousSurfaceId = allocation.surfaceId
                
                if renderSpec != allocation.renderingParameters {
                    layer.surfaceAllocation = nil
                    self.scheduledClearAllocations.append(allocation)
                }
            }
            
            if layer.internalId != -1 {
                let renderingParameters = renderSpec
                
                if let currentAllocation = layer.surfaceAllocation {
                    var updatedAllocation = currentAllocation
                    updatedAllocation.currentPhase = updatedAllocation.currentPhase == 0 ? 1 : 0
                    layer.surfaceAllocation = updatedAllocation
                    updatedSurfaceId = updatedAllocation.surfaceId
                    layer.contentsRect = updatedAllocation.effectivePhase.contentsRect
                } else {
                    if renderingParameters.allocationWidth >= 1024 || renderingParameters.allocationHeight >= 1024 {
                        let surfaceWidth = max(1024, alignUp(renderingParameters.allocationWidth * 2, alignment: 64))
                        let surfaceHeight = max(512, alignUp(renderingParameters.allocationHeight, alignment: 64))
                        
                        if let surface = self.addSurface(width: surfaceWidth, height: surfaceHeight) {
                            if let allocation = surface.allocateIfPossible(renderingParameters: renderingParameters) {
                                layer.surfaceAllocation = allocation
                                layer.contentsRect = allocation.effectivePhase.contentsRect
                                updatedSurfaceId = allocation.surfaceId
                            }
                        }
                    } else {
                        for (_, surface) in self.surfaces {
                            if let allocation = surface.allocateIfPossible(renderingParameters: renderingParameters) {
                                layer.surfaceAllocation = allocation
                                layer.contentsRect = allocation.effectivePhase.contentsRect
                                updatedSurfaceId = allocation.surfaceId
                                break
                            }
                        }
                    }
                    if updatedSurfaceId == nil {
                        let surfaceWidth = alignUp(2048, alignment: 64)
                        let surfaceHeight = alignUp(2048, alignment: 64)
                        
                        if let surface = self.addSurface(width: surfaceWidth, height: surfaceHeight) {
                            if let allocation = surface.allocateIfPossible(renderingParameters: renderingParameters) {
                                layer.surfaceAllocation = allocation
                                layer.contentsRect = allocation.effectivePhase.contentsRect
                                updatedSurfaceId = allocation.surfaceId
                            }
                        }
                    }
                }
            } else {
                if let currentAllocation = layer.surfaceAllocation {
                    layer.surfaceAllocation = nil
                    self.scheduledClearAllocations.append(currentAllocation)
                }
            }
            
            if previousSurfaceId != updatedSurfaceId {
                if let updatedSurfaceId {
                    layer.contents = self.surfaces[updatedSurfaceId]?.ioSurface
                    
                    if previousSurfaceId != nil {
                        #if DEBUG
                        layer.surfaceChangeFrameCount += 1
                        if layer.surfaceChangeFrameCount > 100 {
                            print("Changing surface for layer \(layer) (\(renderSpec.allocationWidth)x\(renderSpec.allocationHeight))")
                        }
                        #endif
                    }
                } else {
                    layer.contents = nil
                    
                    if layer.internalId != -1 {
                        #if DEBUG
                        print("Unable to allocate rendering surface for layer \(layer) (\(renderSpec.allocationWidth)x\(renderSpec.allocationHeight)")
                        #endif
                    }
                }
            } else {
                #if DEBUG
                layer.surfaceChangeFrameCount = max(0, layer.surfaceChangeFrameCount - 1)
                #endif
            }
        }
        
        func removeLayerSurfaceAllocation(layer: MetalEngineSubjectLayer) {
            if let allocation = layer.surfaceAllocation {
                self.scheduledClearAllocations.append(allocation)
            }
        }
        
        func addSubjectNeedsUpdate(subject: MetalEngineSubject) {
            let internalData: MetalEngineSubjectInternalData
            if let current = subject.internalData {
                internalData = current
            } else {
                internalData = MetalEngineSubjectInternalData()
                subject.internalData = internalData
            }
            
            let internalId: Int
            if internalData.internalId != -1 {
                internalId = internalData.internalId
            } else {
                internalId = self.nextSubjectId
                self.nextSubjectId += 1
                internalData.internalId = internalId
            }
            
            let isFirst = self.updatedSubjectIds.isEmpty
            
            if !self.updatedSubjectIds.contains(internalId) {
                self.updatedSubjectIds.append(internalId)
                self.updatedSubjects.append(SubjectReference(subject: subject))
            }
            
            if isFirst {
                #if targetEnvironment(simulator)
                if #available(iOS 13.0, *) {
                    self.layer.setNeedsDisplay()
                }
                #else
                self.layer.setNeedsDisplay()
                #endif
            }
        }
        
        func display() {
            if !self.scheduledClearAllocations.isEmpty {
                for allocation in self.scheduledClearAllocations {
                    if let surface = self.surfaces[allocation.surfaceId] {
                        surface.removeAllocation(id: allocation.allocationId0)
                        surface.removeAllocation(id: allocation.allocationId1)
                    }
                }
                self.scheduledClearAllocations.removeAll()
                
                //TODO:remove clear empty surfaces
            }
            if self.updatedSubjects.isEmpty {
                return
            }
            
            let wereActionsDisabled = CATransaction.disableActions()
            CATransaction.setDisableActions(true)
            defer {
                CATransaction.setDisableActions(wereActionsDisabled)
            }
            
            guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                return
            }
            
            let subjectContext = MetalEngineSubjectContext(device: device, impl: self)
            
            for subjectReference in self.updatedSubjects {
                guard let subject = subjectReference.subject else {
                    continue
                }
                subject.update(context: subjectContext)
            }
            self.updatedSubjects.removeAll()
            self.updatedSubjectIds.removeAll()
            
            if !subjectContext.computeOperations.isEmpty {
                for computeOperation in subjectContext.computeOperations {
                    computeOperation.commands(commandBuffer)
                }
            }
            
            if !subjectContext.renderToLayerOperationsGroupedByState.isEmpty {
                for (_, renderToLayerOperations) in subjectContext.renderToLayerOperationsGroupedByState {
                    for renderToLayerOperation in renderToLayerOperations {
                        guard let layer = renderToLayerOperation.layer else {
                            continue
                        }
                        if layer.internalId == -1 {
                            layer.internalId = self.nextLayerId
                            self.nextLayerId += 1
                        }
                        self.refreshLayerAllocation(layer: layer, renderSpec: renderToLayerOperation.spec)
                    }
                }
                
                var surfaceIds: [Int] = []
                
                for (id, surface) in self.surfaces {
                    surfaceIds.append(id)
                    
                    var clearQuads: [SIMD2<Float>] = []
                    
                    for (_, renderToLayerOperations) in subjectContext.renderToLayerOperationsGroupedByState {
                        for renderToLayerOperation in renderToLayerOperations {
                            guard let layer = renderToLayerOperation.layer else {
                                continue
                            }
                            guard let surfaceAllocation = layer.surfaceAllocation, surfaceAllocation.surfaceId == id else {
                                continue
                            }
                            
                            let layerRect = surfaceAllocation.effectivePhase.renderingRect
                            
                            //let edgeSize = surfaceAllocation.renderingParameters.edgeInset
                            //let renderSize = CGSize(width: surfaceAllocation.renderingParameters.size.width, height: surfaceAllocation.renderingParameters.size.height)
                            
                            //let kx = (CGFloat(edgeSize) * 2.0 + renderSize.width) / layerRect.width
                            //let ky = (CGFloat(edgeSize) * 2.0 + renderSize.height) / layerRect.height
                            //let insetX = CGFloat(edgeSize) / kx
                            //let insetY = CGFloat(edgeSize) / ky
                            
                            let quadVertices: [SIMD2<Float>] = [
                                SIMD2<Float>(Float(layerRect.minX), Float(layerRect.minY)),
                                SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.minY)),
                                SIMD2<Float>(Float(layerRect.minX), Float(layerRect.maxY)),
                                SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.minY)),
                                SIMD2<Float>(Float(layerRect.minX), Float(layerRect.maxY)),
                                SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.maxY))
                            ].map { v in
                                var v = v
                                v.y = -1.0 + v.y * 2.0
                                v.x = -1.0 + v.x * 2.0
                                return v
                            }
                            clearQuads.append(contentsOf: quadVertices)
                        }
                    }
                    
                    if !subjectContext.renderToLayerOperationsGroupedByState.isEmpty || !clearQuads.isEmpty {
                        let renderPass = MTLRenderPassDescriptor()
                        renderPass.colorAttachments[0].texture = surface.texture
                        renderPass.colorAttachments[0].loadAction = .load
                        renderPass.colorAttachments[0].storeAction = .store
                        
                        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                            return
                        }
                        
                        if !clearQuads.isEmpty {
                            renderEncoder.setRenderPipelineState(self.clearPipelineState)
                            
                            //TODO:use buffer if too many vertices
                            renderEncoder.setVertexBytes(clearQuads, length: 4 * clearQuads.count * 2, index: 0)
                            var renderingBackgroundColor = SIMD4<Float>(0.0, 0.0, 0.0, 0.0)
                            renderEncoder.setFragmentBytes(&renderingBackgroundColor, length: 4 * 4, index: 0)
                            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: clearQuads.count)
                        }
                        
                        for (stateId, renderToLayerOperations) in subjectContext.renderToLayerOperationsGroupedByState {
                            guard let state = self.renderStates[stateId] else {
                                continue
                            }
                            if !renderToLayerOperations.isEmpty {
                                renderEncoder.setRenderPipelineState(state.pipelineState)
                            }
                            for renderToLayerOperation in renderToLayerOperations {
                                guard let layer = renderToLayerOperation.layer else {
                                    continue
                                }
                                guard let surfaceAllocation = layer.surfaceAllocation, surfaceAllocation.surfaceId == id else {
                                    continue
                                }
                                
                                let subRect = surfaceAllocation.effectivePhase.subRect
                                renderEncoder.setScissorRect(MTLScissorRect(x: Int(subRect.minX), y: surface.height - Int(subRect.maxY), width: Int(subRect.width), height: Int(subRect.height)))
                                renderToLayerOperation.commands(renderEncoder, RenderLayerPlacement(effectiveRect: surfaceAllocation.effectivePhase.renderingRect))
                            }
                        }
                        
                        renderEncoder.endEncoding()
                    }
                }
            }
            
            if !subjectContext.freeResourcesOnCompletion.isEmpty || !subjectContext.customCompletions.isEmpty {
                let freeResourcesOnCompletion = subjectContext.freeResourcesOnCompletion
                let customCompletions = subjectContext.customCompletions
                commandBuffer.addCompletedHandler { _ in
                    DispatchQueue.main.async {
                        for resource in freeResourcesOnCompletion {
                            resource.free()
                        }
                        for customCompletion in customCompletions {
                            customCompletion()
                        }
                    }
                }
            }
            
            var removeSurfaceIds: [Int] = []
            for (id, surface) in self.surfaces {
                if surface.isEmpty {
                    removeSurfaceIds.append(id)
                }
            }
            for id in removeSurfaceIds {
                self.surfaces.removeValue(forKey: id)
            }
            
            #if DEBUG
            #if targetEnvironment(simulator)
            if #available(iOS 13.0, *) {
                if let drawable = self.layer.nextDrawable() {
                    commandBuffer.present(drawable)
                }
            }
            #else
            if let drawable = self.layer.nextDrawable() {
                commandBuffer.present(drawable)
            }
            #endif
            #endif
            
            commandBuffer.commit()
            commandBuffer.waitUntilScheduled()
        }
    }
    
    public static let shared = MetalEngine()
    
    fileprivate let impl: Impl
    
    public var rootLayer: CALayer {
        #if targetEnvironment(simulator)
        return self.impl._layer
        #else
        return self.impl.layer
        #endif
    }
    
    public var device: MTLDevice {
        return self.impl.device
    }
    
    private init() {
        self.impl = Impl(device: MTLCreateSystemDefaultDevice()!)!
    }
    
    public func pooledTexture(spec: TextureSpec) -> PooledTexture {
        return PooledTexture(device: self.device, spec: spec)
    }
    
    public func pooledBuffer(spec: BufferSpec) -> PooledBuffer {
        return PooledBuffer(device: self.device, spec: spec)
    }
    
    public func sharedBuffer(spec: BufferSpec) -> SharedBuffer? {
        return SharedBuffer(device: self.device, spec: spec)
    }
}
