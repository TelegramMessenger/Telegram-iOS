import Foundation
import MetalKit
import LottieCpp

/*private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

final class PathFrameState {
    struct RenderItem {
        enum Content {
            case fill(PathRenderFillState)
            case stroke(PathRenderStrokeState)
            case offscreen(surface: Surface, rect: CGRect, transform: CATransform3D, opacity: Float, mask: MaskSurface?)
            
            func encode(context: PathRenderContext, encoder: MTLRenderCommandEncoder, buffer: MTLBuffer, canvasSize: CGSize) {
                switch self {
                case let .fill(fill):
                    fill.encode(context: context, encoder: encoder, buffer: buffer)
                case let .stroke(stroke):
                    stroke.encode(context: context, encoder: encoder, buffer: buffer)
                case let .offscreen(surface, rect, transform, opacity, mask):
                    surface.encode(context: context, encoder: encoder, canvasSize: canvasSize, rect: rect, transform: transform, opacity: opacity, mask: mask)
                }
            }
        }
        
        let content: Content
        
        init(content: Content) {
            self.content = content
        }
    }
    
    final class MaskSurface {
        enum Mode {
            case regular
            case inverse
        }
        
        let surface: Surface
        let mode: Mode
        
        init(surface: Surface, mode: Mode) {
            self.surface = surface
            self.mode = mode
        }
    }
    
    final class Surface {
        let width: Int
        let height: Int
        private let msaaSampleCount: Int
        
        private var texture: MTLTexture?
        
        private(set) var items: [RenderItem] = []
        
        init(width: Int, height: Int, msaaSampleCount: Int) {
            self.width = width
            self.height = height
            self.msaaSampleCount = msaaSampleCount
        }
        
        func add(fill: PathRenderFillState) {
            self.items.append(RenderItem(content: .fill(fill)))
        }
        
        func add(stroke: PathRenderStrokeState) {
            self.items.append(RenderItem(content: .stroke(stroke)))
        }
        
        func add(surface: Surface, rect: CGRect, transform: CATransform3D, opacity: Float, mask: MaskSurface?) {
            self.items.append(RenderItem(content: .offscreen(surface: surface, rect: rect, transform: transform, opacity: opacity, mask: mask)))
        }
        
        func encode(context: PathRenderContext, encoder: MTLRenderCommandEncoder, canvasSize: CGSize, rect: CGRect, transform: CATransform3D, opacity: Float, mask: MaskSurface?) {
            guard let texture = self.texture else {
                print("Trying to encode offscreen blit pass, but no texture is present")
                return
            }
            if mask != nil {
                encoder.setRenderPipelineState(context.drawOffscreenWithMaskPipelineState)
            } else {
                encoder.setRenderPipelineState(context.drawOffscreenPipelineState)
            }
            
            let identityTransform = CATransform3DIdentity
            var identityTransformMatrix = SIMD16<Float>(
                Float(identityTransform.m11), Float(identityTransform.m12), Float(identityTransform.m13), Float(identityTransform.m14),
                Float(identityTransform.m21), Float(identityTransform.m22), Float(identityTransform.m23), Float(identityTransform.m24),
                Float(identityTransform.m31), Float(identityTransform.m32), Float(identityTransform.m33), Float(identityTransform.m34),
                Float(identityTransform.m41), Float(identityTransform.m42), Float(identityTransform.m43), Float(identityTransform.m44)
            )
            
            let boundingBox = rect.applying(CATransform3DGetAffineTransform(transform))
            
            var quadVertices: [SIMD4<Float>] = [
                SIMD4<Float>(Float(boundingBox.minX), Float(boundingBox.minY), 0.0, 0.0),
                SIMD4<Float>(Float(boundingBox.maxX), Float(boundingBox.minY), 1.0, 0.0),
                SIMD4<Float>(Float(boundingBox.minX), Float(boundingBox.maxY), 0.0, 1.0),
                
                SIMD4<Float>(Float(boundingBox.maxX), Float(boundingBox.minY), 1.0, 0.0),
                SIMD4<Float>(Float(boundingBox.minX), Float(boundingBox.maxY), 0.0, 1.0),
                SIMD4<Float>(Float(boundingBox.maxX), Float(boundingBox.maxY), 1.0, 1.0)
            ]
            
            encoder.setVertexBytes(&quadVertices, length: MemoryLayout<SIMD4<Float>>.size * quadVertices.count, index: 0)
            encoder.setVertexBytes(&identityTransformMatrix, length: 4 * 4 * 4, index: 1)
            encoder.setFragmentTexture(texture, index: 0)
            if let mask {
                guard let maskTexture = mask.surface.texture else {
                    print("Trying to encode offscreen blit pass, but no mask texture is present")
                    return
                }
                encoder.setFragmentTexture(maskTexture, index: 1)
            }
            var opacity = opacity
            encoder.setFragmentBytes(&opacity, length: 4, index: 1)
            
            if let mask {
                var maskMode: UInt32 = mask.mode == .regular ? 0 : 1;
                encoder.setFragmentBytes(&maskMode, length: 4, index: 2)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        }
        
        func offscreenTextureDescriptor() -> MTLTextureDescriptor {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = self.width
            textureDescriptor.height = self.height
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            return textureDescriptor
        }
        
        func offscreenTempTextureDescriptor() -> MTLTextureDescriptor {
            let tempTextureDescriptor = MTLTextureDescriptor()
            tempTextureDescriptor.sampleCount = self.msaaSampleCount
            if self.msaaSampleCount == 1 {
                tempTextureDescriptor.textureType = .type2D
            } else {
                tempTextureDescriptor.textureType = .type2DMultisample
            }
            tempTextureDescriptor.width = self.width
            tempTextureDescriptor.height = self.height
            tempTextureDescriptor.pixelFormat = .bgra8Unorm
            tempTextureDescriptor.storageMode = .private
            tempTextureDescriptor.usage = [.renderTarget, .shaderRead]
            return tempTextureDescriptor
        }
        
        func calculateOffscreenHeapMemorySize(device: MTLDevice) -> Int {
            var result = 0
            
            var sizeAndAlign = device.heapTextureSizeAndAlign(descriptor: self.offscreenTextureDescriptor())
            result += sizeAndAlign.size
            
            sizeAndAlign = device.heapTextureSizeAndAlign(descriptor: self.offscreenTempTextureDescriptor())
            result += sizeAndAlign.size * 2
            
            for item in self.items {
                if case let .offscreen(surface, _, _, _, mask) = item.content {
                    result += surface.calculateOffscreenHeapMemorySize(device: device)
                    if let mask {
                        result += mask.surface.calculateOffscreenHeapMemorySize(device: device)
                    }
                }
            }
            return result
        }
        
        func encodeOffscreen(context: PathRenderContext, heap: MTLHeap, commandBuffer: MTLCommandBuffer, materializedBuffer: MTLBuffer, canvasSize: CGSize) {
            guard let resultTexture = heap.makeTexture(descriptor: self.offscreenTextureDescriptor()) else {
                return
            }
            
            for item in self.items {
                if case let .offscreen(surface, _, _, _, mask) = item.content {
                    if let mask {
                        mask.surface.encodeOffscreen(context: context, heap: heap, commandBuffer: commandBuffer, materializedBuffer: materializedBuffer, canvasSize: canvasSize)
                    }
                    surface.encodeOffscreen(context: context, heap: heap, commandBuffer: commandBuffer, materializedBuffer: materializedBuffer, canvasSize: canvasSize)
                }
            }
            
            self.texture = resultTexture
            
            guard let offscreenTexture = heap.makeTexture(descriptor: self.offscreenTempTextureDescriptor()) else {
                return
            }
            guard let tempTexture = heap.makeTexture(descriptor: self.offscreenTempTextureDescriptor()) else {
                return
            }
            
            let offscreenRenderPassDescriptor = MTLRenderPassDescriptor()
            if msaaSampleCount == 1 {
                offscreenRenderPassDescriptor.colorAttachments[0].texture = resultTexture
                offscreenRenderPassDescriptor.colorAttachments[0].storeAction = .store
            } else {
                offscreenRenderPassDescriptor.colorAttachments[0].texture = offscreenTexture
                offscreenRenderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
                offscreenRenderPassDescriptor.colorAttachments[0].resolveTexture = resultTexture
            }
            offscreenRenderPassDescriptor.colorAttachments[0].loadAction = .clear
            offscreenRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            
            offscreenRenderPassDescriptor.colorAttachments[1].texture = tempTexture
            offscreenRenderPassDescriptor.colorAttachments[1].loadAction = .clear
            offscreenRenderPassDescriptor.colorAttachments[1].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            offscreenRenderPassDescriptor.colorAttachments[1].storeAction = .dontCare
            
            if self.msaaSampleCount == 4 {
                offscreenRenderPassDescriptor.setSamplePositions([
                    MTLSamplePosition(x: 0.25, y: 0.25),
                    MTLSamplePosition(x: 0.75, y: 0.25),
                    MTLSamplePosition(x: 0.75, y: 0.75),
                    MTLSamplePosition(x: 0.25, y: 0.75)
                ])
            }
            
            guard let offscreenRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor) else {
                return
            }
            
            for item in self.items {
                item.content.encode(context: context, encoder: offscreenRenderEncoder, buffer: materializedBuffer, canvasSize: canvasSize)
            }
            
            offscreenRenderEncoder.endEncoding()
        }
    }
    
    let msaaSampleCount: Int
    let buffer: PathRenderBuffer
    let bezierDataBuffer: PathRenderBuffer
    
    private var surfaceStack: [Surface] = []
    
    private var materializedBuffer: MTLBuffer?
    private var materializedBezierIndexBuffer: MTLBuffer?
    
    init(width: Int, height: Int, msaaSampleCount: Int, buffer: PathRenderBuffer, bezierDataBuffer: PathRenderBuffer) {
        self.msaaSampleCount = msaaSampleCount
        self.buffer = buffer
        self.bezierDataBuffer = bezierDataBuffer
        self.surfaceStack.append(Surface(width: width, height: height, msaaSampleCount: msaaSampleCount))
    }
    
    func pushOffscreen(width: Int, height: Int) {
        self.surfaceStack.append(Surface(width: width, height: height, msaaSampleCount: self.msaaSampleCount))
    }
    
    func popOffscreen(rect: CGRect, transform: CATransform3D, opacity: Float, mask: MaskSurface? = nil) {
        self.surfaceStack[self.surfaceStack.count - 2].add(surface: self.surfaceStack[self.surfaceStack.count - 1], rect: rect, transform: transform, opacity: opacity, mask: mask)
        self.surfaceStack.removeLast()
    }
    
    func popOffscreenMask(mode: MaskSurface.Mode) -> MaskSurface {
        return MaskSurface(
            surface: self.surfaceStack.removeLast(),
            mode: mode
        )
    }
    
    func add(fill: PathRenderFillState) {
        self.surfaceStack.last!.add(fill: fill)
    }
    
    func add(stroke: PathRenderStrokeState) {
        self.surfaceStack.last!.add(stroke: stroke)
    }
    
    func prepare(heap: MTLHeap) {
        if self.buffer.length == 0 {
            return
        }
        
        var bufferOptions: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined]
        if #available(iOS 13.0, *) {
            bufferOptions.insert(.hazardTrackingModeTracked)
        }
        
        guard let materializedBuffer = heap.makeBuffer(length: self.buffer.length, options: bufferOptions) else {
            print("Could not create materialized buffer")
            return
        }
        materializedBuffer.label = "materializedBuffer"
        self.materializedBuffer = materializedBuffer
        
        memcpy(materializedBuffer.contents(), self.buffer.memory, self.buffer.length)
        
        if self.bezierDataBuffer.length != 0 {
            guard let materializedBezierIndexBuffer = heap.makeBuffer(length: self.bezierDataBuffer.length, options: bufferOptions) else {
                print("Could not create materialized bezier index buffer")
                return
            }
            self.materializedBezierIndexBuffer = materializedBezierIndexBuffer
            materializedBezierIndexBuffer.label = "materializedBezierIndexBuffer"
            
            memcpy(materializedBezierIndexBuffer.contents(), self.bezierDataBuffer.memory, self.bezierDataBuffer.length)
        }
    }
    
    func calculateOffscreenHeapMemorySize(device: MTLDevice) -> Int {
        var result = 0
        for item in self.surfaceStack[0].items {
            if case let .offscreen(surface, _, _, _, mask) = item.content {
                result += surface.calculateOffscreenHeapMemorySize(device: device)
                if let mask {
                    result += mask.surface.calculateOffscreenHeapMemorySize(device: device)
                }
            }
        }
        return result
    }
    
    func encodeOffscreen(context: PathRenderContext, heap: MTLHeap, commandBuffer: MTLCommandBuffer, canvasSize: CGSize) {
        guard let materializedBuffer = self.materializedBuffer else {
            return
        }
        
        assert(self.surfaceStack.count == 1)
        
        for item in self.surfaceStack[0].items {
            if case let .offscreen(surface, _, _, _, mask) = item.content {
                if let mask {
                    mask.surface.encodeOffscreen(context: context, heap: heap, commandBuffer: commandBuffer, materializedBuffer: materializedBuffer, canvasSize: canvasSize)
                }
                surface.encodeOffscreen(context: context, heap: heap, commandBuffer: commandBuffer, materializedBuffer: materializedBuffer, canvasSize: canvasSize)
            }
        }
    }
    
    func encodeRender(context: PathRenderContext, encoder: MTLRenderCommandEncoder, canvasSize: CGSize) {
        guard let materializedBuffer = self.materializedBuffer else {
            return
        }
        
        assert(self.surfaceStack.count == 1)
        
        for item in self.surfaceStack[0].items {
            item.content.encode(context: context, encoder: encoder, buffer: materializedBuffer, canvasSize: canvasSize)
        }
    }
    
    func encodeCompute(context: PathRenderContext, computeEncoder: MTLComputeCommandEncoder) {
        guard let materializedBuffer = self.materializedBuffer, let materializedBezierIndexBuffer = self.materializedBezierIndexBuffer else {
            return
        }
        
        let itemSize = 4 + 4 * 4 * 2 + 4
        let itemCount = self.bezierDataBuffer.length / itemSize
        
        computeEncoder.setComputePipelineState(context.prepareBezierPipelineState)
        
        let threadGroupWidth = 16
        let threadGroupHeight = 8
        
        computeEncoder.useResource(materializedBuffer, usage: .write)
        
        computeEncoder.setBuffer(materializedBezierIndexBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(materializedBuffer, offset: 0, index: 1)
        var itemCountSize: UInt32 = UInt32(itemCount)
        computeEncoder.setBytes(&itemCountSize, length: 4, index: 2)
        let dispatchSize = alignUp(size: itemCount, align: threadGroupWidth)
        computeEncoder.dispatchThreadgroups(MTLSize(width: dispatchSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: threadGroupHeight, depth: 1))
    }
}
*/
