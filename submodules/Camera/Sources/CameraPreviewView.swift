import Foundation
import UIKit
import Display
import AVFoundation
import SwiftSignalKit
import Metal
import MetalKit
import CoreMedia

public class CameraPreviewView: MTKView {
    private let queue = DispatchQueue(label: "CameraPreview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    private var sampler: MTLSamplerState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexCoordBuffer: MTLBuffer!
    private var texCoordBuffer: MTLBuffer!
    
    private var textureWidth: Int = 0
    private var textureHeight: Int = 0
    private var textureMirroring = false
    private var textureRotation: Rotation = .rotate0Degrees
    
    private var textureTranform: CGAffineTransform?
    private var _bounds = CGRectNull
    
    public enum Rotation: Int {
        case rotate0Degrees
        case rotate90Degrees
        case rotate180Degrees
        case rotate270Degrees
    }
    
    private var _mirroring: Bool?
    private var _scheduledMirroring: Bool?
    public var mirroring = false {
        didSet {
            self.queue.sync {
                if self._mirroring != nil {
                    self._scheduledMirroring = self.mirroring
                } else {
                    self._mirroring = self.mirroring
                }
            }
        }
    }
    
    private var _rotation: Rotation = .rotate0Degrees
    public var rotation: Rotation = .rotate0Degrees {
        didSet {
            self.queue.sync {
                self._rotation = rotation
            }
        }
    }
    
    private var _pixelBuffer: CVPixelBuffer?
    var pixelBuffer: CVPixelBuffer? {
        didSet {
            self.queue.sync {
                if let scheduledMirroring = self._scheduledMirroring {
                    self._scheduledMirroring = nil
                    self._mirroring = scheduledMirroring
                }
                self._pixelBuffer = pixelBuffer
            }
        }
    }
    
    public init?(test: Bool) {
        let mainBundle = Bundle(for: CameraPreviewView.self)
        
        guard let path = mainBundle.path(forResource: "CameraBundle", ofType: "bundle") else {
            return nil
        }
        
        guard let bundle = Bundle(path: path) else {
            return nil
        }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
            return nil
        }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        super.init(frame: .zero, device: device)
    
        self.colorPixelFormat = .bgra8Unorm
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexPassThrough")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentPassThrough")
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        self.sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("\(error)")
        }
        
        self.setupTextureCache()
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTextureCache() {
        var newTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &newTextureCache) == kCVReturnSuccess {
            self.textureCache = newTextureCache
        } else {
            assertionFailure("Unable to allocate texture cache")
        }
    }
    
    private func setupTransform(width: Int, height: Int, rotation: Rotation, mirroring: Bool) {
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        var resizeAspect: Float = 1.0
        
        self._bounds = self.bounds
        self.textureWidth = width
        self.textureHeight = height
        self.textureMirroring = mirroring
        self.textureRotation = rotation
        
        if self.textureWidth > 0 && self.textureHeight > 0 {
            switch self.textureRotation {
            case .rotate0Degrees, .rotate180Degrees:
                scaleX = Float(self._bounds.width / CGFloat(self.textureWidth))
                scaleY = Float(self._bounds.height / CGFloat(self.textureHeight))
                
            case .rotate90Degrees, .rotate270Degrees:
                scaleX = Float(self._bounds.width / CGFloat(self.textureHeight))
                scaleY = Float(self._bounds.height / CGFloat(self.textureWidth))
            }
        }
        resizeAspect = min(scaleX, scaleY)
        if scaleX < scaleY {
            scaleY = scaleX / scaleY
            scaleX = 1.0
        } else {
            scaleX = scaleY / scaleX
            scaleY = 1.0
        }
        
        if self.textureMirroring {
            scaleX *= -1.0
        }
        
        let vertexData: [Float] = [
            -scaleX, -scaleY, 0.0, 1.0,
            scaleX, -scaleY, 0.0, 1.0,
            -scaleX, scaleY, 0.0, 1.0,
            scaleX, scaleY, 0.0, 1.0
        ]
        self.vertexCoordBuffer = device!.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])
        
        var texCoordBufferData: [Float]
        switch self.textureRotation {
        case .rotate0Degrees:
            texCoordBufferData = [
                0.0, 1.0,
                1.0, 1.0,
                0.0, 0.0,
                1.0, 0.0
            ]
        case .rotate180Degrees:
            texCoordBufferData = [
                1.0, 0.0,
                0.0, 0.0,
                1.0, 1.0,
                0.0, 1.0
            ]
        case .rotate90Degrees:
            texCoordBufferData = [
                1.0, 1.0,
                1.0, 0.0,
                0.0, 1.0,
                0.0, 0.0
            ]
        case .rotate270Degrees:
            texCoordBufferData = [
                0.0, 0.0,
                0.0, 1.0,
                1.0, 0.0,
                1.0, 1.0
            ]
        }
        self.texCoordBuffer = device?.makeBuffer(bytes: texCoordBufferData, length: texCoordBufferData.count * MemoryLayout<Float>.size, options: [])
        
        var transform = CGAffineTransform.identity
        if self.textureMirroring {
            transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureWidth), y: 0))
        }
        
        switch self.textureRotation {
        case .rotate0Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(0)))
        case .rotate180Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi)))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureWidth), y: CGFloat(self.textureHeight)))
        case .rotate90Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureHeight), y: 0))
        case .rotate270Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: 3 * CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: CGFloat(self.textureWidth)))
        }
        transform = transform.concatenating(CGAffineTransform(scaleX: CGFloat(resizeAspect), y: CGFloat(resizeAspect)))
        
        let tranformRect = CGRect(origin: .zero, size: CGSize(width: self.textureWidth, height: self.textureHeight)).applying(transform)
        let xShift = (self._bounds.size.width - tranformRect.size.width) / 2
        let yShift = (self._bounds.size.height - tranformRect.size.height) / 2
        transform = transform.concatenating(CGAffineTransform(translationX: xShift, y: yShift))
        
        self.textureTranform = transform.inverted()
    }
    
    public override func draw(_ rect: CGRect) {
        var pixelBuffer: CVPixelBuffer?
        var mirroring = false
        var rotation: Rotation = .rotate0Degrees
        
        self.queue.sync {
            pixelBuffer = self._pixelBuffer
            if let mirroringValue = self._mirroring {
                mirroring = mirroringValue
            }
            rotation = self._rotation
        }
        
        guard let drawable = currentDrawable, let currentRenderPassDescriptor = currentRenderPassDescriptor, let previewPixelBuffer = pixelBuffer else {
            return
        }
        
        let width = CVPixelBufferGetWidth(previewPixelBuffer)
        let height = CVPixelBufferGetHeight(previewPixelBuffer)
        
        if self.textureCache == nil {
            self.setupTextureCache()
        }
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache!,
            previewPixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        if texture.width != self.textureWidth ||
            texture.height != self.textureHeight ||
            self.bounds != self._bounds ||
            rotation != self.textureRotation ||
            mirroring != self.textureMirroring {
            self.setupTransform(width: texture.width, height: texture.height, rotation: rotation, mirroring: mirroring)
        }
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        commandEncoder.setRenderPipelineState(self.renderPipelineState!)
        commandEncoder.setVertexBuffer(self.vertexCoordBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(self.texCoordBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentTexture(texture, index: 0)
        commandEncoder.setFragmentSamplerState(self.sampler, index: 0)
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
