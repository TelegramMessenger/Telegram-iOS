import Foundation
import UIKit
import QuartzCore
import MetalKit
import Display
import SwiftSignalKit
import AppBundle

final class DrawingMetalView: MTKView {
    let size: CGSize
    
    private let commandQueue: MTLCommandQueue
    fileprivate let library: MTLLibrary
    private var pipelineState: MTLRenderPipelineState!
    
    fileprivate var drawable: Drawable?
        
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private var markerBrush: Brush?
    
    init?(size: CGSize) {
        let mainBundle = Bundle(for: DrawingView.self)
        guard let path = mainBundle.path(forResource: "DrawingUIBundle", ofType: "bundle") else {
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
        self.library = defaultLibrary
        
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        self.size = size
    
        super.init(frame: CGRect(origin: .zero, size: size), device: device)
        
        self.drawableSize = self.size
        self.autoResizeDrawable = false
        self.isOpaque = false
        self.contentScaleFactor = 1.0
        self.isPaused = true
        self.preferredFramesPerSecond = 60
        self.presentsWithTransaction = true
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        self.setup()
    }
    
    override var isHidden: Bool {
        didSet {
            if self.isHidden {
                Queue.mainQueue().after(0.2) {
                    self.isPaused = true
                }
            } else {
                self.isPaused = self.isHidden
            }
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeTexture(with data: Data) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device!)
        return try? textureLoader.newTexture(data: data, options: [.SRGB : false])
    }
    
    func makeTexture(with image: UIImage) -> MTLTexture? {
        if let data = image.pngData() {
            return makeTexture(with: data)
        } else {
            return nil
        }
    }
    
    func drawInContext(_ cgContext: CGContext) {
        guard let texture = self.drawable?.texture, let image = texture.createCGImage() else {
            return
        }
        let rect = CGRect(origin: .zero, size: CGSize(width: image.width, height: image.height))
        cgContext.saveGState()
        cgContext.translateBy(x: rect.midX, y: rect.midY)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        cgContext.translateBy(x: -rect.midX, y: -rect.midY)
        cgContext.draw(image, in: rect)
        cgContext.restoreGState()
    }
    
    private func setup() {
        self.drawable = Drawable(size: self.size, pixelFormat: self.colorPixelFormat, device: device)

        let size = self.size
        let w = size.width, h = size.height
        let vertices = [
            Vertex(position: CGPoint(x: 0 , y: 0), texCoord: CGPoint(x: 0, y: 0)),
            Vertex(position: CGPoint(x: w , y: 0), texCoord: CGPoint(x: 1, y: 0)),
            Vertex(position: CGPoint(x: 0 , y: h), texCoord: CGPoint(x: 0, y: 1)),
            Vertex(position: CGPoint(x: w , y: h), texCoord: CGPoint(x: 1, y: 1)),
        ]
        self.render_target_vertex = self.device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .cpuCacheModeWriteCombined)

        let matrix = Matrix.identity
        matrix.scaling(x: 2.0 / Float(size.width), y: -2.0 / Float(size.height), z: 1)
        matrix.translation(x: -1, y: 1, z: 0)
        self.render_target_uniform = self.device?.makeBuffer(bytes: matrix.m, length: MemoryLayout<Float>.size * 16, options: [])

        let vertexFunction = self.library.makeFunction(name: "vertex_render_target")
        let fragmentFunction = self.library.makeFunction(name: "fragment_render_target")
        let pipelineDescription = MTLRenderPipelineDescriptor()
        pipelineDescription.vertexFunction = vertexFunction
        pipelineDescription.fragmentFunction = fragmentFunction
        pipelineDescription.colorAttachments[0].pixelFormat = colorPixelFormat

        do {
            self.pipelineState = try self.device?.makeRenderPipelineState(descriptor: pipelineDescription)
        } catch {
            fatalError(error.localizedDescription)
        }

        if let url = getAppBundle().url(forResource: "marker", withExtension: "png"), let data = try? Data(contentsOf: url) {
            self.markerBrush = Brush(texture: self.makeTexture(with: data), target: self, rotation: .fixed(-0.55))
        }
        
        self.drawable?.clear()
        
        Queue.mainQueue().after(0.1) {
            self.markerBrush?.pushPoint(CGPoint(x: 100.0, y: 100.0), color: DrawingColor.clear, size: 0.0, isEnd: true)
            Queue.mainQueue().after(0.1) {
                self.clear()
            }
        }
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        } set {
            super.frame = newValue
            self.drawableSize = self.size
        }
    }
        
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let drawable = self.drawable, let texture = drawable.texture?.texture else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = self.clearColor
        attachment?.texture = self.currentDrawable?.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store

        guard let _ = attachment?.texture else {
            return
        }

        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        commandEncoder?.setRenderPipelineState(self.pipelineState)

        commandEncoder?.setVertexBuffer(self.render_target_vertex, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(self.render_target_uniform, offset: 0, index: 1)
        commandEncoder?.setFragmentTexture(texture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilScheduled()
        self.currentDrawable?.present()
    }
    
    func reset() {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = self.clearColor
        attachment?.texture = self.currentDrawable?.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store

        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilScheduled()
        self.currentDrawable?.present()
    }
        
    func clear() {
        guard let drawable = self.drawable else {
            return
        }
        
        drawable.updateBuffer(with: self.size)
        drawable.clear()
        self.reset()
    }
        
    enum BrushType {
        case marker
    }
    
    func updated(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, brush: BrushType, color: DrawingColor, size: CGFloat) {
        switch brush {
        case .marker:
            self.markerBrush?.updated(point, color: color, state: state, size: size)
        }
    }
}

private class Drawable {
    public private(set) var texture: Texture?
    
    internal var pixelFormat: MTLPixelFormat = .bgra8Unorm
    internal var size: CGSize
    internal var uniform_buffer: MTLBuffer!
    internal var renderPassDescriptor: MTLRenderPassDescriptor?
    internal var commandBuffer: MTLCommandBuffer?
    internal var commandQueue: MTLCommandQueue?
    internal var device: MTLDevice?
        
    public init(size: CGSize, pixelFormat: MTLPixelFormat, device: MTLDevice?) {
        self.size = size
        self.pixelFormat = pixelFormat
        self.device = device
        self.texture = self.makeTexture()
        self.commandQueue = device?.makeCommandQueue()
        
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = self.renderPassDescriptor?.colorAttachments[0]
        attachment?.texture = self.texture?.texture
        attachment?.loadAction = .load
        attachment?.storeAction = .store
        
        self.updateBuffer(with: size)
    }
    
    func clear() {
        self.texture?.clear()
    }
    
    func reset() {
        self.prepareForDraw()
        
        if let commandEncoder = self.makeCommandEncoder() {
            commandEncoder.endEncoding()
        }
        
        self.commit(wait: true)
    }
    
    internal func updateBuffer(with size: CGSize) {
        self.size = size
      
        let matrix = Matrix.identity
        self.uniform_buffer = device?.makeBuffer(bytes: matrix.m, length: MemoryLayout<Float>.size * 16, options: [])
    }
    
    internal func prepareForDraw() {
        if self.commandBuffer == nil {
            self.commandBuffer = self.commandQueue?.makeCommandBuffer()
        }
    }
    
    internal func makeCommandEncoder() -> MTLRenderCommandEncoder? {
        guard let commandBuffer = self.commandBuffer, let renderPassDescriptor = self.renderPassDescriptor else {
            return nil
        }
        return commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    }
    
    
    internal func commit(wait: Bool = false) {
        self.commandBuffer?.commit()
        if wait {
            self.commandBuffer?.waitUntilCompleted()
        }
        self.commandBuffer = nil
    }
    
    internal func makeTexture() -> Texture? {
        guard self.size.width * self.size.height > 0, let device = self.device else {
            return nil
        }
        return Texture(device: device, width: Int(self.size.width), height: Int(self.size.height))
    }
}

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

private class Brush {
    private(set) var texture: MTLTexture?
    private(set) var pipelineState: MTLRenderPipelineState!
    
    weak var target: DrawingMetalView?
        
    public enum Rotation {
        case fixed(CGFloat)
        case random
        case ahead
    }
    
    var rotation: Rotation
    
    required public init(texture: MTLTexture?, target: DrawingMetalView, rotation: Rotation) {
        self.texture = texture
        self.target = target
        self.rotation = rotation

        self.setupPipeline()
    }

    private func setupPipeline() {
        guard let target = self.target, let device = target.device else {
            return
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        if let vertex_func = target.library.makeFunction(name: "vertex_point_func") {
            renderPipelineDescriptor.vertexFunction = vertex_func
        }
        if let _ = self.texture {
            if let fragment_func = target.library.makeFunction(name: "fragment_point_func") {
                renderPipelineDescriptor.fragmentFunction = fragment_func
            }
        } else {
            if let fragment_func = target.library.makeFunction(name: "fragment_point_func_without_texture") {
                renderPipelineDescriptor.fragmentFunction = fragment_func
            }
        }
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = target.colorPixelFormat
        
        let attachment = renderPipelineDescriptor.colorAttachments[0]
        attachment?.isBlendingEnabled = true

        attachment?.rgbBlendOperation = .add
        attachment?.sourceRGBBlendFactor = .sourceAlpha
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        attachment?.alphaBlendOperation = .add
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }

    func render(stroke: Stroke, in drawable: Drawable? = nil) {
        let drawable = drawable ?? target?.drawable
        
        guard stroke.lines.count > 0, let target = drawable else {
            return
        }
        
        target.prepareForDraw()
        
        let commandEncoder = target.makeCommandEncoder()
        commandEncoder?.setRenderPipelineState(self.pipelineState)
        
        if let vertex_buffer = stroke.preparedBuffer(rotation: self.rotation) {
            commandEncoder?.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
            commandEncoder?.setVertexBuffer(target.uniform_buffer, offset: 0, index: 1)
            if let texture = texture {
                commandEncoder?.setFragmentTexture(texture, index: 0)
            }
            commandEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: stroke.vertexCount)
        }
        
        commandEncoder?.endEncoding()
    }
                
    private let bezier = BezierGenerator()
    func updated(_ point: DrawingPoint, color: DrawingColor, state: DrawingGesturePipeline.DrawingGestureState, size: CGFloat) {
        let point = point.location
        switch state {
        case .began:
            self.bezier.begin(with: point)
            let _ = self.pushPoint(point, color: color, size: size, isEnd: false)
        case .changed:
            if self.bezier.points.count > 0 && point != lastRenderedPoint {
                self.pushPoint(point, color: color, size: size, isEnd: false)
            }
        case .ended, .cancelled:
            if self.bezier.points.count >= 3 {
                self.pushPoint(point, color: color, size: size, isEnd: true)
            }
            self.bezier.finish()
            self.lastRenderedPoint = nil
        }
    }
    
    func setup(_ inputPoints: [CGPoint], color: DrawingColor, size: CGFloat) {
        guard inputPoints.count >= 2 else {
            return
        }
        var pointStep: CGFloat
        if case .random = self.rotation {
            pointStep = size * 0.1
        } else {
            pointStep = 2.0
        }
        
        var lines: [Line] = []
        
        var previousPoint = inputPoints[0]
        
        var points: [CGPoint] = []
        self.bezier.begin(with: inputPoints.first!)
        for point in inputPoints {
            let smoothPoints = self.bezier.pushPoint(point)
            points.append(contentsOf: smoothPoints)
        }
        self.bezier.finish()
        
        guard points.count >= 2 else {
            return
        }
        for i in 1 ..< points.count {
            let p = points[i]
            if (i == points.count - 1) || pointStep <= 1 || (pointStep > 1 && previousPoint.distance(to: p) >= pointStep) {
                let line = Line(start: previousPoint, end: p, pointSize: size, pointStep: pointStep)
                lines.append(line)
                previousPoint = p
            }
        }
        
        if let drawable = self.target?.drawable {
            let stroke = Stroke(color: color, lines: lines, target: drawable)
            self.render(stroke: stroke, in: drawable)
            drawable.commit(wait: true)
        }
    }
    
    private var lastRenderedPoint: CGPoint?
    func pushPoint(_ point: CGPoint, color: DrawingColor, size: CGFloat, isEnd: Bool) {
        var pointStep: CGFloat
        if case .random = self.rotation {
            pointStep = size * 0.1
        } else {
            pointStep = 2.0
        }
        
        var lines: [Line] = []
        let points = self.bezier.pushPoint(point)
        guard points.count >= 2 else {
            return
        }
        var previousPoint = self.lastRenderedPoint ?? points[0]
        for i in 1 ..< points.count {
            let p = points[i]
            if (isEnd && i == points.count - 1) || pointStep <= 1 || (pointStep > 1 && previousPoint.distance(to: p) >= pointStep) {
                let line = Line(start: previousPoint, end: p, pointSize: size, pointStep: pointStep)
                lines.append(line)
                previousPoint = p
            }
        }
        
        if let drawable = self.target?.drawable {
            let stroke = Stroke(color: color, lines: lines, target: drawable)
            self.render(stroke: stroke, in: drawable)
            drawable.commit()
        }
    }
}

private class Stroke {
    private weak var target: Drawable?
    
    let color: DrawingColor
    var lines: [Line] = []
    
    private(set) var vertexCount: Int = 0
    private var vertex_buffer: MTLBuffer?
    
    init(color: DrawingColor, lines: [Line] = [], target: Drawable) {
        self.color = color
        self.lines = lines
        self.target = target
        
        let _ = self.preparedBuffer(rotation: .fixed(0))
    }
    
    func append(_ lines: [Line]) {
        self.lines.append(contentsOf: lines)
        self.vertex_buffer = nil
    }
    
    func preparedBuffer(rotation: Brush.Rotation) -> MTLBuffer? {
        guard !self.lines.isEmpty else {
            return nil
        }
        
        var vertexes: [Point] = []
        
        self.lines.forEach { (line) in
            let count = max(line.length / line.pointStep, 1)
            
            let overlapping = max(1, line.pointSize / line.pointStep)
            var renderingColor = self.color
            renderingColor.alpha = renderingColor.alpha / overlapping * 5.5
            
            for i in 0 ..< Int(count) {
                let index = CGFloat(i)
                let x = line.start.x + (line.end.x - line.start.x) * (index / count)
                let y = line.start.y + (line.end.y - line.start.y) * (index / count)
                
                var angle: CGFloat = 0
                switch rotation {
                    case let .fixed(a):
                        angle = a
                    case .random:
                        angle = CGFloat.random(in: -CGFloat.pi ... CGFloat.pi)
                    case .ahead:
                        angle = line.angle
                }
                
                vertexes.append(Point(x: x, y: y, color: renderingColor, size: line.pointSize, angle: angle))
            }
        }

        self.vertexCount = vertexes.count
        self.vertex_buffer = self.target?.device?.makeBuffer(bytes: vertexes, length: MemoryLayout<Point>.stride * vertexCount, options: .cpuCacheModeWriteCombined)
        
        return self.vertex_buffer
    }
}

class BezierGenerator {
    init() {
    }
    
    init(beginPoint: CGPoint) {
        self.begin(with: beginPoint)
    }
    
    func begin(with point: CGPoint) {
        self.step = 0
        self.points.removeAll()
        self.points.append(point)
    }
    
    func pushPoint(_ point: CGPoint) -> [CGPoint] {
        if point == self.points.last {
            return []
        }
        self.points.append(point)
        if self.points.count < 3 {
            return []
        }
        self.step += 1
        return self.generateSmoothPathPoints()
    }
    
    func finish() {
        self.step = 0
        self.points.removeAll()
    }
    
    var points: [CGPoint] = []
    
    private var step = 0
    private func generateSmoothPathPoints() -> [CGPoint] {
        var begin: CGPoint
        var control: CGPoint
        let end = CGPoint.middle(p1: self.points[step], p2: self.points[self.step + 1])

        var vertices: [CGPoint] = []
        if self.step == 1 {
            begin = self.points[0]
            let middle1 = CGPoint.middle(p1: self.points[0], p2: self.points[1])
            control = CGPoint.middle(p1: middle1, p2: self.points[1])
        } else {
            begin = CGPoint.middle(p1: self.points[self.step - 1], p2: self.points[self.step])
            control = self.points[self.step]
        }
        
        let distance = begin.distance(to: end)
        let segements = max(Int(distance / 5), 2)

        for i in 0 ..< segements {
            let t = CGFloat(i) / CGFloat(segements)
            vertices.append(begin.quadBezierPoint(to: end, controlPoint: control, t: t))
        }
        vertices.append(end)
        return vertices
    }
}

private struct Line {
    var start: CGPoint
    var end: CGPoint
    
    var pointSize: CGFloat
    var pointStep: CGFloat
            
    init(start: CGPoint, end: CGPoint, pointSize: CGFloat, pointStep: CGFloat) {
        self.start = start
        self.end = end
        self.pointSize = pointSize
        self.pointStep = pointStep
    }
    
    var length: CGFloat {
        return self.start.distance(to: self.end)
    }
    
    var angle: CGFloat {
        return self.end.angle(to: self.start)
    }
}

final class Texture {
    let buffer: MTLBuffer?
    
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let texture: MTLTexture
    
    init?(device: MTLDevice, width: Int, height: Int) {
        let bytesPerPixel = 4
        let pixelRowAlignment = device.minimumLinearTextureAlignment(for: .bgra8Unorm)
        let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
        
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
    
        self.buffer = nil
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .shared
    
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        self.texture = texture

        self.clear()
    }
    
    func clear() {
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: self.width, height: self.height, depth: 1)
        )
        let data = Data(capacity: Int(self.bytesPerRow * self.height))
        if let bytes = data.withUnsafeBytes({ $0.baseAddress }) {
            self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: self.bytesPerRow)
        }
    }
    
    func createCGImage() -> CGImage? {
        let dataProvider: CGDataProvider

        guard let data = NSMutableData(capacity: self.bytesPerRow * self.height) else {
            return nil
        }
        data.length = self.bytesPerRow * self.height
        self.texture.getBytes(data.mutableBytes, bytesPerRow: self.bytesPerRow, bytesPerImage: self.bytesPerRow * self.height, from: MTLRegion(origin: MTLOrigin(), size: MTLSize(width: self.width, height: self.height, depth: 1)), mipmapLevel: 0, slice: 0)
        
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        dataProvider = provider

        guard let image = CGImage(
            width: Int(self.width),
            height: Int(self.height),
            bitsPerComponent: 8,
            bitsPerPixel: 8 * 4,
            bytesPerRow: self.bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: DeviceGraphicsContextSettings.shared.transparentBitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return image
    }
}
