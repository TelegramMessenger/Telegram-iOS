import Foundation
import UIKit
import QuartzCore
import MetalKit
import AppBundle

public final class DrawingMetalView: MTKView {
    private let size: CGSize
    
    private let commandQueue: MTLCommandQueue
    fileprivate let library: MTLLibrary
    private var pipelineState: MTLRenderPipelineState!
    
    fileprivate var drawable: Drawable?
        
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private var penBrush: Brush?
    private var markerBrush: Brush?
    private var pencilBrush: Brush?
    
    public init?(size: CGSize) {
        var size = size
        if Int(size.width) % 16 != 0 {
            size.width = round(size.width / 16.0) * 16.0
        }
        
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
        
        self.isOpaque = false
        self.drawableSize = self.size
        
        self.setup()
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
        guard let texture = self.drawable?.texture, let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])?.oriented(forExifOrientation: 1) else {
            return
        }
        let context = CIContext(cgContext: cgContext)
        let rect = CGRect(origin: .zero, size: ciImage.extent.size)
        context.draw(ciImage, in: rect, from: rect)
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
        
        self.penBrush = Brush(texture: nil, target: self, rotation: .ahead)
        
        if let url = getAppBundle().url(forResource: "marker", withExtension: "png"), let data = try? Data(contentsOf: url) {
            self.markerBrush = Brush(texture: self.makeTexture(with: data), target: self, rotation: .fixed(0.0))
        }
        
        if let url = getAppBundle().url(forResource: "pencil", withExtension: "png"), let data = try? Data(contentsOf: url) {
            self.pencilBrush = Brush(texture: self.makeTexture(with: data), target: self, rotation: .random)
        }
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let drawable = self.drawable, let texture = drawable.texture else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = clearColor
        attachment?.texture = self.currentDrawable?.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store
        
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        commandEncoder?.setRenderPipelineState(self.pipelineState)
        
        commandEncoder?.setVertexBuffer(self.render_target_vertex, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(self.render_target_uniform, offset: 0, index: 1)
        commandEncoder?.setFragmentTexture(texture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        commandEncoder?.endEncoding()
        if let drawable = self.currentDrawable {
            commandBuffer?.present(drawable)
        }
        commandBuffer?.commit()
    }
    
    func clear() {
        guard let drawable = self.drawable else {
            return
        }
        
        drawable.updateBuffer(with: self.size)
        drawable.clear()
        
        drawable.commit()
    }
        
    enum BrushType {
        case pen
        case marker
        case pencil
    }
    
    func updated(_ point: Polyline.Point, state: DrawingGesturePipeline.DrawingGestureState, brush: BrushType, color: DrawingColor, size: CGFloat) {
        switch brush {
        case .pen:
            self.penBrush?.updated(point, color: color, state: state, size: size)
        case .marker:
            self.markerBrush?.updated(point, color: color, state: state, size: size)
        case .pencil:
            self.pencilBrush?.updated(point, color: color, state: state, size: size)
        }
    }
}

private class Drawable {
    public private(set) var texture: MTLTexture?
    
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
        self.texture = self.makeColorTexture(DrawingColor.clear)
        self.commandQueue = device?.makeCommandQueue()
        
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = self.renderPassDescriptor?.colorAttachments[0]
        attachment?.texture = self.texture
        attachment?.loadAction = .load
        attachment?.storeAction = .store
        
        self.updateBuffer(with: size)
    }
    
    func clear() {
        self.texture = self.makeColorTexture(DrawingColor.clear)
        self.renderPassDescriptor?.colorAttachments[0].texture = self.texture
        self.commit()
    }
    
    internal func updateBuffer(with size: CGSize) {
        self.size = size
      
        let matrix = Matrix.identity
        self.uniform_buffer = device?.makeBuffer(bytes: matrix.m, length: MemoryLayout<Float>.size * 16, options: [])
    }
    
    internal func prepareForDraw() {
        if self.commandBuffer == nil {
            self.commandBuffer = commandQueue?.makeCommandBuffer()
        }
    }
    
    internal func makeCommandEncoder() -> MTLRenderCommandEncoder? {
        guard let commandBuffer = self.commandBuffer, let rpd = renderPassDescriptor else {
            return nil
        }
        return commandBuffer.makeRenderCommandEncoder(descriptor: rpd)
    }
    
    internal func commit() {
        self.commandBuffer?.commit()
        self.commandBuffer = nil
    }
    
    internal func makeColorTexture(_ color: DrawingColor) -> MTLTexture? {
        guard self.size.width * self.size.height > 0 else {
            return nil
        }
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: self.pixelFormat,
            width: Int(self.size.width),
            height: Int(self.size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device?.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: texture.width, height: texture.height, depth: 1)
        )
        let bytesPerRow = 4 * texture.width
        let data = Data(capacity: Int(bytesPerRow * texture.height))
        if let bytes = data.withUnsafeBytes({ $0.baseAddress }) {
            texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: bytesPerRow)
        }
        return texture
    }
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
    func updated(_ point: Polyline.Point, color: DrawingColor, state: DrawingGesturePipeline.DrawingGestureState, size: CGFloat) {
        let point = point.location
        switch state {
        case .began:
            self.bezier.begin(with: point)
            self.pushPoint(point, color: color, size: size, isEnd: false)
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
            renderingColor.alpha = renderingColor.alpha / overlapping * 2.5
            
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
        begin(with: beginPoint)
    }
    
    func begin(with point: CGPoint) {
        step = 0
        points.removeAll()
        points.append(point)
    }
    
    func pushPoint(_ point: CGPoint) -> [CGPoint] {
        if point == points.last {
            return []
        }
        points.append(point)
        if points.count < 3 {
            return []
        }
        step += 1
        let result = genericPathPoints()
        return result
    }
    
    func finish() {
        step = 0
        points.removeAll()
    }
    
    var points: [CGPoint] = []
    
    private var step = 0
    private func genericPathPoints() -> [CGPoint] {
        var begin: CGPoint
        var control: CGPoint
        let end = CGPoint.middle(p1: points[step], p2: points[step + 1])

        var vertices: [CGPoint] = []
        if step == 1 {
            begin = points[0]
            let middle1 = CGPoint.middle(p1: points[0], p2: points[1])
            control = CGPoint.middle(p1: middle1, p2: points[1])
        } else {
            begin = CGPoint.middle(p1: points[step - 1], p2: points[step])
            control = points[step]
        }
        
        let distance = begin.distance(to: end)
        let segements = max(Int(distance / 5), 2)

        for i in 0 ..< segements {
            let t = CGFloat(i) / CGFloat(segements)
            let x = pow(1 - t, 2) * begin.x + 2.0 * (1 - t) * t * control.x + t * t * end.x
            let y = pow(1 - t, 2) * begin.y + 2.0 * (1 - t) * t * control.y + t * t * end.y
            vertices.append(CGPoint(x: x, y: y))
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
