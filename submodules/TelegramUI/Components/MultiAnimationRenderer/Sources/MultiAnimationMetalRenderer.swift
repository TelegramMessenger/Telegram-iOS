import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import Accelerate
import simd

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

private extension Float {
    func remap(fromLow: Float, fromHigh: Float, toLow: Float, toHigh: Float) -> Float {
        guard (fromHigh - fromLow) != 0.0 else {
            return 0.0
        }
        return toLow + (self - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
    }
}

private func makePipelineState(device: MTLDevice, library: MTLLibrary, vertexProgram: String, fragmentProgram: String) -> MTLRenderPipelineState? {
    guard let loadedVertexProgram = library.makeFunction(name: vertexProgram) else {
        return nil
    }
    guard let loadedFragmentProgram = library.makeFunction(name: fragmentProgram) else {
        return nil
    }

    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = loadedVertexProgram
    pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) else {
        return nil
    }

    return pipelineState
}

@available(iOS 13.0, *)
public final class MultiAnimationMetalRendererImpl: MultiAnimationRenderer {
    private final class LoadFrameTask {
        let task: () -> () -> Void
        
        init(task: @escaping () -> () -> Void) {
            self.task = task
        }
    }
    
    private final class TargetReference {
        let id: Int64
        weak var value: MultiAnimationRenderTarget?
        
        init(_ value: MultiAnimationRenderTarget) {
            self.value = value
            self.id = value.id
        }
    }
    
    private final class TextureStoragePool {
        let width: Int
        let height: Int
        let format: TextureStorage.Content.Format
        
        private var items: [TextureStorage.Content] = []
        
        init(width: Int, height: Int, format: TextureStorage.Content.Format) {
            self.width = width
            self.height = height
            self.format = format
        }
        
        func recycle(content: TextureStorage.Content) {
            if self.items.count < 4 {
                self.items.append(content)
            } else {
                print("Warning: over-recycling texture storage")
            }
        }
        
        func take(device: MTLDevice) -> TextureStorage.Content? {
            if self.items.isEmpty {
                guard let content = TextureStorage.Content(device: device, width: self.width, height: self.height, format: format) else {
                    return nil
                }
                return content
            }
            return self.items.removeLast()
        }
    }
    
    private final class TextureStorage {
        final class Content {
            enum Format {
                case bgra
                case r
            }
            
            let buffer: MTLBuffer?
            
            let width: Int
            let height: Int
            let bytesPerRow: Int
            let texture: MTLTexture
            
            init?(device: MTLDevice, width: Int, height: Int, format: Format) {
                let bytesPerPixel: Int
                let pixelFormat: MTLPixelFormat
                switch format {
                case .bgra:
                    bytesPerPixel = 4
                    pixelFormat = .bgra8Unorm
                case .r:
                    bytesPerPixel = 1
                    pixelFormat = .r8Unorm
                }
                let pixelRowAlignment = device.minimumLinearTextureAlignment(for: pixelFormat)
                let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
                
                self.width = width
                self.height = height
                self.bytesPerRow = bytesPerRow
                
                #if targetEnvironment(simulator)
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.textureType = .type2D
                textureDescriptor.pixelFormat = pixelFormat
                textureDescriptor.width = width
                textureDescriptor.height = height
                textureDescriptor.usage = [.renderTarget]
                textureDescriptor.storageMode = .shared
                
                guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                    return nil
                }
                self.buffer = nil
                #else
                guard let buffer = device.makeBuffer(length: bytesPerRow * height, options: MTLResourceOptions.storageModeShared) else {
                    return nil
                }
                self.buffer = buffer
                
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.textureType = .type2D
                textureDescriptor.pixelFormat = pixelFormat
                textureDescriptor.width = width
                textureDescriptor.height = height
                textureDescriptor.usage = [.renderTarget]
                textureDescriptor.storageMode = buffer.storageMode
                
                guard let texture = buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow) else {
                    return nil
                }
                #endif
                
                self.texture = texture
            }
            
            func replace(rgbaData: Data, width: Int, height: Int, bytesPerRow: Int) {
                if width != self.width || height != self.height {
                    assert(false, "Image size does not match")
                    return
                }
                let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
                
                if let buffer = self.buffer, self.bytesPerRow == bytesPerRow {
                    rgbaData.withUnsafeBytes { bytes in
                        let _ = memcpy(buffer.contents(), bytes.baseAddress!, bytesPerRow * height)
                    }
                } else {
                    rgbaData.withUnsafeBytes { bytes in
                        self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: bytesPerRow)
                    }
                }
            }
        }
        
        private weak var pool: TextureStoragePool?
        let content: Content
        private var isInvalidated: Bool = false
        
        init(pool: TextureStoragePool, content: Content) {
            self.pool = pool
            self.content = content
        }
        
        deinit {
            if !self.isInvalidated {
                self.pool?.recycle(content: self.content)
            }
        }
        
        /*func createCGImage() -> CGImage? {
            if self.isInvalidated {
                return nil
            }
            self.isInvalidated = true
            
            #if targetEnvironment(simulator)
            guard let data = NSMutableData(capacity: self.content.bytesPerRow * self.content.height) else {
                return nil
            }
            data.length = self.content.bytesPerRow * self.content.height
            self.content.texture.getBytes(data.mutableBytes, bytesPerRow: self.content.bytesPerRow, bytesPerImage: self.content.bytesPerRow * self.content.height, from: MTLRegion(origin: MTLOrigin(), size: MTLSize(width: self.content.width, height: self.content.height, depth: 1)), mipmapLevel: 0, slice: 0)
            
            guard let dataProvider = CGDataProvider(data: data as CFData) else {
                return nil
            }
            #else
            let content = self.content
            let pool = self.pool
            guard let dataProvider = CGDataProvider(data: Data(bytesNoCopy: self.content.buffer.contents(), count: self.content.buffer.length, deallocator: .custom { [weak pool] _, _ in
                guard let pool = pool else {
                    return
                }
                pool.recycle(content: content)
            }) as CFData) else {
                return nil
            }
            #endif

            guard let image = CGImage(
                width: Int(self.content.width),
                height: Int(self.content.height),
                bitsPerComponent: 8,
                bitsPerPixel: 8 * 4,
                bytesPerRow: self.content.bytesPerRow,
                space: DeviceGraphicsContextSettings.shared.colorSpace,
                bitmapInfo: DeviceGraphicsContextSettings.shared.transparentBitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) else {
                return nil
            }
            
            return image
        }*/
    }
    
    private final class Frame {
        let timestamp: Double
        let textureY: TextureStorage.Content
        let textureU: TextureStorage.Content
        let textureV: TextureStorage.Content
        let textureA: TextureStorage.Content
        
        init?(device: MTLDevice, textureY: TextureStorage.Content, textureU: TextureStorage.Content, textureV: TextureStorage.Content, textureA: TextureStorage.Content, data: AnimationCacheItemFrame, timestamp: Double) {
            self.timestamp = timestamp
            self.textureY = textureY
            self.textureU = textureU
            self.textureV = textureV
            self.textureA = textureA
            
            switch data.format {
            case .rgba:
                return nil
            case let .yuva(y, u, v, a):
                self.textureY.replace(rgbaData: y.data, width: y.width, height: y.height, bytesPerRow: y.bytesPerRow)
                self.textureU.replace(rgbaData: u.data, width: u.width, height: u.height, bytesPerRow: u.bytesPerRow)
                self.textureV.replace(rgbaData: v.data, width: v.width, height: v.height, bytesPerRow: v.bytesPerRow)
                self.textureA.replace(rgbaData: a.data, width: a.width, height: a.height, bytesPerRow: a.bytesPerRow)
            }
        }
    }
    
    private final class ItemContext {
        static let queue = Queue(name: "MultiAnimationMetalRendererImpl", qos: .default)
        
        private let cache: AnimationCache
        private let stateUpdated: () -> Void
        
        private var disposable: Disposable?
        private var timestamp: Double = 0.0
        private var item: AnimationCacheItem?
        
        private(set) var currentFrame: Frame?
        private var isLoadingFrame: Bool = false
        
        private(set) var isPlaying: Bool = false {
            didSet {
                if self.isPlaying != oldValue {
                    self.stateUpdated()
                }
            }
        }
        
        var targets: [TargetReference] = []
        var slotIndex: Int
        
        init(slotIndex: Int, cache: AnimationCache, itemId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable, stateUpdated: @escaping () -> Void) {
            self.slotIndex = slotIndex
            self.cache = cache
            self.stateUpdated = stateUpdated
            
            self.disposable = cache.get(sourceId: itemId, size: size, fetch: fetch).start(next: { [weak self] result in
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.item = result.item
                    strongSelf.updateIsPlaying()
                    
                    if result.item == nil {
                        for target in strongSelf.targets {
                            if let target = target.value {
                                target.updateDisplayPlaceholder(displayPlaceholder: true)
                            }
                        }
                    }
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func updateIsPlaying() {
            var isPlaying = true
            if self.item == nil {
                isPlaying = false
            }
            
            var shouldBeAnimating = false
            for target in self.targets {
                if let target = target.value {
                    if target.shouldBeAnimating {
                        shouldBeAnimating = true
                        break
                    }
                }
            }
            if !shouldBeAnimating {
                isPlaying = false
            }
            
            self.isPlaying = isPlaying
        }
        
        func animationTick(device: MTLDevice, texturePoolFullPlane: TextureStoragePool, texturePoolHalfPlane: TextureStoragePool, advanceTimestamp: Double) -> LoadFrameTask? {
            return self.update(device: device, texturePoolFullPlane: texturePoolFullPlane, texturePoolHalfPlane: texturePoolHalfPlane, advanceTimestamp: advanceTimestamp)
        }
        
        private func update(device: MTLDevice, texturePoolFullPlane: TextureStoragePool, texturePoolHalfPlane: TextureStoragePool, advanceTimestamp: Double?) -> LoadFrameTask? {
            guard let item = self.item else {
                return nil
            }
            
            let timestamp = self.timestamp
            if let advanceTimestamp = advanceTimestamp {
                self.timestamp += advanceTimestamp
            }
            
            if let currentFrame = self.currentFrame, currentFrame.timestamp == self.timestamp {
            } else if !self.isLoadingFrame {
                self.isLoadingFrame = true
                
                return LoadFrameTask(task: { [weak self] in
                    let frame = item.getFrame(at: timestamp, requestedFormat: .rgba)
                    
                    return {
                        guard let strongSelf = self else {
                            return
                        }
                        
                        var currentFrame: Frame?
                        let textureY = texturePoolFullPlane.take(device: device)
                        let textureU = texturePoolHalfPlane.take(device: device)
                        let textureV = texturePoolHalfPlane.take(device: device)
                        let textureA = texturePoolFullPlane.take(device: device)
                        if let frame = frame, let textureY = textureY, let textureU = textureU, let textureV = textureV, let textureA = textureA {
                            currentFrame = Frame(device: device, textureY: textureY, textureU: textureU, textureV: textureV, textureA: textureA, data: frame, timestamp: timestamp)
                        }
                        
                        strongSelf.isLoadingFrame = false
                        
                        if let currentFrame = currentFrame {
                            strongSelf.currentFrame = currentFrame
                        }
                    }
                })
            }
            
            return nil
        }
    }
    
    private final class SurfaceLayer: CAMetalLayer {
        private let cellSize: CGSize
        private let stateUpdated: () -> Void
        
        private let metalDevice: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let renderPipelineState: MTLRenderPipelineState
        
        private let texturePoolFullPlane: TextureStoragePool
        private let texturePoolHalfPlane: TextureStoragePool
        
        private let slotCount: Int
        private let slotsX: Int
        private let slotsY: Int
        private var itemContexts: [String: ItemContext] = [:]
        private var slotToItemId: [String?]
        
        private(set) var isPlaying: Bool = false {
            didSet {
                if self.isPlaying != oldValue {
                    self.stateUpdated()
                }
            }
        }
        
        public init(cellSize: CGSize, stateUpdated: @escaping () -> Void) {
            self.cellSize = cellSize
            self.stateUpdated = stateUpdated
            
            let resolutionX = max(1, (1024 / Int(cellSize.width))) * Int(cellSize.width)
            let resolutionY = max(1, (1024 / Int(cellSize.height))) * Int(cellSize.height)
            self.slotsX = resolutionX / Int(cellSize.width)
            self.slotsY = resolutionY / Int(cellSize.height)
            let drawableSize = CGSize(width: cellSize.width * CGFloat(self.slotsX), height: cellSize.height * CGFloat(self.slotsY))
            
            self.slotCount = (Int(drawableSize.width) / Int(cellSize.width)) * (Int(drawableSize.height) / Int(cellSize.height))
            self.slotToItemId = (0 ..< self.slotCount).map { _ in nil }
            
            self.metalDevice = MTLCreateSystemDefaultDevice()!
            self.commandQueue = self.metalDevice.makeCommandQueue()!
            
            let mainBundle = Bundle(for: MultiAnimationMetalRendererImpl.self)
            
            guard let path = mainBundle.path(forResource: "MultiAnimationRendererBundle", ofType: "bundle") else {
                preconditionFailure()
            }
            guard let bundle = Bundle(path: path) else {
                preconditionFailure()
            }
            guard let defaultLibrary = try? self.metalDevice.makeDefaultLibrary(bundle: bundle) else {
                preconditionFailure()
            }
            
            self.renderPipelineState = makePipelineState(device: self.metalDevice, library: defaultLibrary, vertexProgram: "multiAnimationVertex", fragmentProgram: "multiAnimationFragment")!
            
            self.texturePoolFullPlane = TextureStoragePool(width: Int(self.cellSize.width), height: Int(self.cellSize.height), format: .r)
            self.texturePoolHalfPlane = TextureStoragePool(width: Int(self.cellSize.width) / 2, height: Int(self.cellSize.height) / 2, format: .r)
            
            super.init()
            
            self.device = self.metalDevice
            self.maximumDrawableCount = 2
            //self.metalLayer.presentsWithTransaction = true
            self.contentsScale = 1.0
            
            self.drawableSize = drawableSize
            
            self.pixelFormat = .bgra8Unorm
            self.framebufferOnly = true
            self.allowsNextDrawableTimeout = true
            self.isOpaque = false
        }
        
        override public init(layer: Any) {
            preconditionFailure()
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func action(forKey event: String) -> CAAction? {
            return nullAction
        }
        
        func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Disposable? {
            if size != self.cellSize {
                return nil
            }
            
            let targetId = target.id
            
            if self.itemContexts[itemId] == nil {
                for i in 0 ..< self.slotCount {
                    if self.slotToItemId[i] == nil {
                        self.slotToItemId[i] = itemId
                        self.itemContexts[itemId] = ItemContext(slotIndex: i, cache: cache, itemId: itemId, size: size, fetch: fetch, stateUpdated: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.updateIsPlaying()
                        })
                        break
                    }
                }
            }
            
            if let itemContext = self.itemContexts[itemId] {
                itemContext.targets.append(TargetReference(target))
                
                let deinitIndex = target.deinitCallbacks.add { [weak self, weak itemContext] in
                    Queue.mainQueue().async {
                        guard let strongSelf = self, let currentItemContext = strongSelf.itemContexts[itemId], currentItemContext === itemContext else {
                            return
                        }
                        strongSelf.removeTargetFromItemContext(itemId: itemId, itemContext: currentItemContext, targetId: targetId)
                    }
                }
                
                let updateStateIndex = target.updateStateCallbacks.add { [weak itemContext] in
                    guard let itemContext = itemContext else {
                        return
                    }
                    itemContext.updateIsPlaying()
                }
                
                target.contents = self.contents
                
                let slotX = itemContext.slotIndex % self.slotsX
                let slotY = itemContext.slotIndex / self.slotsX
                let totalX = CGFloat(self.slotsX) * self.cellSize.width
                let totalY = CGFloat(self.slotsY) * self.cellSize.height
                let contentsRect = CGRect(origin: CGPoint(x: (CGFloat(slotX) * self.cellSize.width) / totalX, y: (CGFloat(slotY) * self.cellSize.height) / totalY), size: CGSize(width: self.cellSize.width / totalX, height: self.cellSize.height / totalY))
                target.contentsRect = contentsRect
                
                self.isPlaying = true
                
                return ActionDisposable { [weak self, weak target, weak itemContext] in
                    Queue.mainQueue().async {
                        guard let strongSelf = self, let currentItemContext = strongSelf.itemContexts[itemId], currentItemContext === itemContext else {
                            return
                        }
                        
                        if let target = target {
                            target.deinitCallbacks.remove(deinitIndex)
                            target.updateStateCallbacks.remove(updateStateIndex)
                        }
                        
                        strongSelf.removeTargetFromItemContext(itemId: itemId, itemContext: currentItemContext, targetId: targetId)
                    }
                }
            } else {
                return nil
            }
        }
        
        private func removeTargetFromItemContext(itemId: String, itemContext: ItemContext, targetId: Int64) {
            if let index = itemContext.targets.firstIndex(where: { $0.id == targetId }) {
                itemContext.targets.remove(at: index)
                
                if itemContext.targets.isEmpty {
                    self.slotToItemId[itemContext.slotIndex] = nil
                    self.itemContexts.removeValue(forKey: itemId)
                    
                    if self.itemContexts.isEmpty {
                        self.isPlaying = false
                    }
                }
            }
        }
        
        private func updateIsPlaying() {
            var isPlaying = false
            for (_, itemContext) in self.itemContexts {
                if itemContext.isPlaying {
                    isPlaying = true
                    break
                }
            }
            
            self.isPlaying = isPlaying
        }
        
        func animationTick(advanceTimestamp: Double) -> [LoadFrameTask] {
            var tasks: [LoadFrameTask] = []
            for (_, itemContext) in self.itemContexts {
                if itemContext.isPlaying {
                    if let task = itemContext.animationTick(device: self.metalDevice, texturePoolFullPlane: self.texturePoolFullPlane, texturePoolHalfPlane: self.texturePoolHalfPlane, advanceTimestamp: advanceTimestamp) {
                        tasks.append(task)
                    }
                }
            }
            
            return tasks
        }
        
        func redraw() {
            guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                return
            }
            guard let drawable = self.nextDrawable() else {
                return
            }
            
            /*let drawTime = CACurrentMediaTime() - timestamp
            if drawTime > 9.0 / 1000.0 {
                print("get time \(drawTime * 1000.0)")
            }*/
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.0,
                green: 0.0,
                blue: 0.0,
                alpha: 0.0
            )

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            var usedTextures: [MultiAnimationMetalRendererImpl.TextureStorage.Content] = []
            
            var vertices: [Float] = [
                -1.0, -1.0, 0.0, 0.0,
                1.0, -1.0, 1.0, 0.0,
                -1.0, 1.0, 0.0, 1.0,
                1.0, 1.0, 1.0, 1.0
            ]
            
            renderEncoder.setRenderPipelineState(self.renderPipelineState)
            
            var resolution = simd_uint2(UInt32(drawable.texture.width), UInt32(drawable.texture.height))
            renderEncoder.setVertexBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 1)
            
            var slotSize = simd_uint2(UInt32(self.cellSize.width), UInt32(self.cellSize.height))
            renderEncoder.setVertexBytes(&slotSize, length: MemoryLayout<simd_uint2>.size * 2, index: 2)
            
            for (_, itemContext) in self.itemContexts {
                guard let frame = itemContext.currentFrame else {
                    continue
                }
                
                let slotX = itemContext.slotIndex % self.slotsX
                let slotY = self.slotsY - 1 - itemContext.slotIndex / self.slotsY
                let totalX = CGFloat(self.slotsX) * self.cellSize.width
                let totalY = CGFloat(self.slotsY) * self.cellSize.height
                
                let contentsRect = CGRect(origin: CGPoint(x: (CGFloat(slotX) * self.cellSize.width) / totalX, y: (CGFloat(slotY) * self.cellSize.height) / totalY), size: CGSize(width: self.cellSize.width / totalX, height: self.cellSize.height / totalY))
                
                vertices[4 * 2 + 0] = Float(contentsRect.minX).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                vertices[4 * 2 + 1] = Float(contentsRect.minY).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                
                vertices[4 * 3 + 0] = Float(contentsRect.maxX).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                vertices[4 * 3 + 1] = Float(contentsRect.minY).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                
                vertices[4 * 0 + 0] = Float(contentsRect.minX).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                vertices[4 * 0 + 1] = Float(contentsRect.maxY).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                
                vertices[4 * 1 + 0] = Float(contentsRect.maxX).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                vertices[4 * 1 + 1] = Float(contentsRect.maxY).remap(fromLow: 0.0, fromHigh: 1.0, toLow: -1.0, toHigh: 1.0)
                
                renderEncoder.setVertexBytes(&vertices, length: 4 * vertices.count, index: 0)
                
                var slotPosition = simd_uint2(UInt32(itemContext.slotIndex % self.slotsX), UInt32(itemContext.slotIndex % self.slotsY))
                renderEncoder.setVertexBytes(&slotPosition, length: MemoryLayout<simd_uint2>.size * 2, index: 3)
                
                usedTextures.append(frame.textureY)
                usedTextures.append(frame.textureU)
                usedTextures.append(frame.textureV)
                usedTextures.append(frame.textureA)
                renderEncoder.setFragmentTexture(frame.textureY.texture, index: 0)
                renderEncoder.setFragmentTexture(frame.textureU.texture, index: 1)
                renderEncoder.setFragmentTexture(frame.textureV.texture, index: 2)
                renderEncoder.setFragmentTexture(frame.textureA.texture, index: 3)

                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
            }
            
            renderEncoder.endEncoding()
            
            if self.presentsWithTransaction {
                if Thread.isMainThread {
                    commandBuffer.commit()
                    commandBuffer.waitUntilScheduled()
                    drawable.present()
                } else {
                    CATransaction.begin()
                    commandBuffer.commit()
                    commandBuffer.waitUntilScheduled()
                    drawable.present()
                    CATransaction.commit()
                }
            } else {
                commandBuffer.addScheduledHandler { _ in
                    drawable.present()
                }
                commandBuffer.addCompletedHandler { _ in
                    DispatchQueue.main.async {
                        for _ in usedTextures {
                        }
                    }
                }
                commandBuffer.commit()
            }
        }
    }
    
    private var nextSurfaceLayerIndex: Int = 1
    private var surfaceLayers: [Int: SurfaceLayer] = [:]
    
    private var frameSkip: Int
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                if self.isPlaying {
                    if self.displayLink == nil {
                        self.displayLink = ConstantDisplayLinkAnimator { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.animationTick()
                        }
                        self.displayLink?.frameInterval = self.frameSkip
                        self.displayLink?.isPaused = false
                    }
                } else {
                    if let displayLink = self.displayLink {
                        self.displayLink = nil
                        displayLink.invalidate()
                    }
                }
            }
        }
    }
    
    public init() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled && ProcessInfo.processInfo.activeProcessorCount > 2 {
            self.frameSkip = 1
        } else {
            self.frameSkip = 2
        }
    }
    
    private func updateIsPlaying() {
        var isPlaying = false
        for (_, surfaceLayer) in self.surfaceLayers {
            if surfaceLayer.isPlaying {
                isPlaying = true
                break
            }
        }
        
        self.isPlaying = isPlaying
    }
    
    public func add(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Disposable {
        assert(Thread.isMainThread)
        
        let alignedSize = CGSize(width: CGFloat(alignUp(size: Int(size.width), align: 16)), height: CGFloat(alignUp(size: Int(size.height), align: 16)))
        
        for (_, surfaceLayer) in self.surfaceLayers {
            if let disposable = surfaceLayer.add(target: target, cache: cache, itemId: itemId, size: alignedSize, fetch: fetch) {
                return disposable
            }
        }
        
        let index = self.nextSurfaceLayerIndex
        self.nextSurfaceLayerIndex += 1
        let surfaceLayer = SurfaceLayer(cellSize: alignedSize, stateUpdated: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateIsPlaying()
        })
        self.surfaceLayers[index] = surfaceLayer
        if let disposable = surfaceLayer.add(target: target, cache: cache, itemId: itemId, size: alignedSize, fetch: fetch) {
            return disposable
        } else {
            return EmptyDisposable
        }
    }
    
    public func loadFirstFrameSynchronously(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
        return false
    }
    
    public func loadFirstFrame(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, completion: @escaping (Bool) -> Void) -> Disposable {
        completion(false)
        
        return EmptyDisposable
    }
    
    private func animationTick() {
        let secondsPerFrame = Double(self.frameSkip) / 60.0
        
        var tasks: [LoadFrameTask] = []
        var surfaceLayersWithTasks: [Int] = []
        for (index, surfaceLayer) in self.surfaceLayers {
            var hasTasks = false
            if surfaceLayer.isPlaying {
                let surfaceLayerTasks = surfaceLayer.animationTick(advanceTimestamp: secondsPerFrame)
                if !surfaceLayerTasks.isEmpty {
                    tasks.append(contentsOf: surfaceLayerTasks)
                    hasTasks = true
                }
            }
            if hasTasks {
                surfaceLayersWithTasks.append(index)
            }
        }
        
        if !tasks.isEmpty {
            ItemContext.queue.async { [weak self] in
                var completions: [() -> Void] = []
                for task in tasks {
                    let complete = task.task()
                    completions.append(complete)
                }
                
                if !completions.isEmpty {
                    Queue.mainQueue().async {
                        for completion in completions {
                            completion()
                        }
                    }
                }
                
                if let strongSelf = self {
                    for index in surfaceLayersWithTasks {
                        if let surfaceLayer = strongSelf.surfaceLayers[index] {
                            surfaceLayer.redraw()
                        }
                    }
                }
            }
        }
    }
}
