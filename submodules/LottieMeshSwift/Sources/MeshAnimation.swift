import Foundation
import Metal
import MetalKit
import LottieMeshBinding

struct Triangle {
    var points: [Int]

    static func read(buffer: MeshReadBuffer) -> Triangle {
        var points: [Int] = []

        for _ in 0 ..< 3 {
            points.append(Int(buffer.readInt32()))
        }

        return Triangle(points: points)
    }

    func write(buffer: MeshWriteBuffer) {
        for i in 0 ..< 3 {
            buffer.writeInt32(Int32(self.points[i]))
        }
    }
}

enum TriangleFill {
    struct Color {
        var r: Float
        var g: Float
        var b: Float
        var a: Float
    }

    struct Gradient {
        var colors: [Color]
        var colorLocations: [Float]
        var start: CGPoint
        var end: CGPoint
        var isRadial: Bool

        static func read(buffer: MeshReadBuffer) -> Gradient {
            var colors: [Color] = []
            var colorLocations: [Float] = []

            let numColors = buffer.readInt8()
            for _ in 0 ..< numColors {
                colors.append(Color(argb: UInt32(bitPattern: buffer.readInt32())))
            }
            for _ in 0 ..< numColors {
                colorLocations.append(buffer.readFloat())
            }

            return Gradient(
                colors: colors,
                colorLocations: colorLocations,
                start: CGPoint(x: CGFloat(buffer.readFloat()), y: CGFloat(buffer.readFloat())),
                end: CGPoint(x: CGFloat(buffer.readFloat()), y: CGFloat(buffer.readFloat())),
                isRadial: buffer.readInt8() != 0
            )
        }

        func write(buffer: MeshWriteBuffer) {
            buffer.writeInt8(Int8(self.colors.count))
            for color in self.colors {
                buffer.writeInt32(Int32(bitPattern: color.argb))
            }
            for location in self.colorLocations {
                buffer.writeFloat(location)
            }
            buffer.writeFloat(Float(self.start.x))
            buffer.writeFloat(Float(self.start.y))
            buffer.writeFloat(Float(self.end.x))
            buffer.writeFloat(Float(self.end.y))
            buffer.writeInt8(self.isRadial ? 1 : 0)
        }
    }

    case color(Color)
    case gradient(Gradient)

    static func read(buffer: MeshReadBuffer) -> TriangleFill {
        let key = buffer.readInt8()
        if key == 0 {
            return .color(Color(argb: UInt32(bitPattern: buffer.readInt32())))
        } else {
            return .gradient(Gradient.read(buffer: buffer))
        }
    }

    func write(buffer: MeshWriteBuffer) {
        switch self {
        case let .color(color):
            buffer.writeInt8(0)
            buffer.writeInt32(Int32(bitPattern: color.argb))
        case let .gradient(gradient):
            buffer.writeInt8(1)
            gradient.write(buffer: buffer)
        }
    }
}

extension TriangleFill.Color {
    init(_ color: UIColor) {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
    }

    init(argb: UInt32) {
        self.init(r: Float((argb >> 16) & 0xff) / 255.0, g: Float((argb >> 8) & 0xff) / 255.0, b: Float(argb & 0xff) / 255.0, a: Float((argb >> 24) & 0xff) / 255.0)
    }

    var argb: UInt32 {
        return (UInt32(self.a * 255.0) << 24) | (UInt32(max(0.0, self.r) * 255.0) << 16) | (UInt32(max(0.0, self.g) * 255.0) << 8) | (UInt32(max(0.0, self.b) * 255.0))
    }

    func multiplied(alpha: Float) -> TriangleFill.Color {
        var color = self
        color.a *= alpha
        return color
    }
}

enum MeshOption {
    case fill(rule: CGPathFillRule)
    case stroke(lineWidth: CGFloat, miterLimit: CGFloat, lineJoin: CGLineJoin, lineCap: CGLineCap)
}

public final class MeshAnimation {
    final class Frame {
        final class Segment {
            let vertices: [CGPoint]
            let triangles: [Triangle]
            let fill: TriangleFill
            let transform: CGAffineTransform

            init(vertices: [CGPoint], triangles: [Triangle], fill: TriangleFill, transform: CGAffineTransform) {
                self.vertices = vertices
                self.triangles = triangles
                self.fill = fill
                self.transform = transform
            }

            static func read(buffer: MeshReadBuffer) -> Segment {
                var vertices: [CGPoint] = []
                let vertCount = buffer.readInt32()
                for _ in 0 ..< vertCount {
                    vertices.append(CGPoint(x: CGFloat(buffer.readFloat()), y: CGFloat(buffer.readFloat())))
                }

                let triCount = buffer.readInt32()
                var triangles: [Triangle] = []
                for _ in 0 ..< triCount {
                    triangles.append(Triangle.read(buffer: buffer))
                }
                return Segment(vertices: vertices, triangles: triangles, fill: TriangleFill.read(buffer: buffer), transform: CGAffineTransform(a: CGFloat(buffer.readFloat()), b: CGFloat(buffer.readFloat()), c: CGFloat(buffer.readFloat()), d: CGFloat(buffer.readFloat()), tx: CGFloat(buffer.readFloat()), ty: CGFloat(buffer.readFloat())))
            }

            func write(buffer: MeshWriteBuffer) {
                buffer.writeInt32(Int32(self.vertices.count))
                for vertex in self.vertices {
                    buffer.writeFloat(Float(vertex.x))
                    buffer.writeFloat(Float(vertex.y))
                }
                buffer.writeInt32(Int32(self.triangles.count))
                for triangle in self.triangles {
                    triangle.write(buffer: buffer)
                }
                self.fill.write(buffer: buffer)
                buffer.writeFloat(Float(self.transform.a))
                buffer.writeFloat(Float(self.transform.b))
                buffer.writeFloat(Float(self.transform.c))
                buffer.writeFloat(Float(self.transform.d))
                buffer.writeFloat(Float(self.transform.tx))
                buffer.writeFloat(Float(self.transform.ty))
            }
        }

        let segments: [Segment]

        init(segments: [Segment]) {
            self.segments = segments
        }

        static func read(buffer: MeshReadBuffer) -> Frame {
            var segments: [Segment] = []
            let count = buffer.readInt32()
            for _ in 0 ..< count {
                segments.append(Segment.read(buffer: buffer))
            }
            return Frame(segments: segments)
        }

        func write(buffer: MeshWriteBuffer) {
            buffer.writeInt32(Int32(self.segments.count))
            for segment in self.segments {
                segment.write(buffer: buffer)
            }
        }
    }

    let frames: [Frame]

    init(frames: [Frame]) {
        self.frames = frames
    }

    public static func read(buffer: MeshReadBuffer) -> MeshAnimation {
        var frames: [Frame] = []
        let count = buffer.readInt32()
        for _ in 0 ..< count {
            frames.append(Frame.read(buffer: buffer))
        }
        return MeshAnimation(frames: frames)
    }

    public func write(buffer: MeshWriteBuffer) {
        buffer.writeInt32(Int32(self.frames.count))
        for frame in self.frames {
            frame.write(buffer: buffer)
        }
    }
}

@available(iOS 13.0, *)
public final class MeshRenderer: MTKView {
    private final class RenderingMesh {
        let mesh: MeshAnimation
        let offset: CGPoint
        var currentFrame: Int = 0
        let vertexBuffer: MTLBuffer
        let transformBuffer: MTLBuffer
        let maxVertices: Int

        init(device: MTLDevice, mesh: MeshAnimation, offset: CGPoint) {
            self.mesh = mesh
            self.offset = offset

            var maxTriangles = 0
            for i in 0 ..< mesh.frames.count {
                var frameTriangles = 0
                for segment in mesh.frames[i].segments {
                    frameTriangles += segment.triangles.count
                }
                maxTriangles = max(maxTriangles, frameTriangles)
            }

            self.maxVertices = maxTriangles * 3

            let vertexBufferArray = Array<Float>(repeating: 0.0, count: self.maxVertices * (2 + 4))
            guard let vertexBuffer = device.makeBuffer(bytes: vertexBufferArray, length: vertexBufferArray.count * MemoryLayout.size(ofValue: vertexBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
                preconditionFailure()
            }
            self.vertexBuffer = vertexBuffer

            let transformBufferArray = Array<Float>(repeating: 0.0, count: 2)
            guard let transformBuffer = device.makeBuffer(bytes: transformBufferArray, length: transformBufferArray.count * MemoryLayout.size(ofValue: transformBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
                preconditionFailure()
            }
            self.transformBuffer = transformBuffer
        }
    }

    private let commandQueue: MTLCommandQueue
    private let drawPassthroughPipelineState: MTLRenderPipelineState
    private let drawRadialGradientPipelineStates: [Int: MTLRenderPipelineState]

    private var displayLink: CADisplayLink?

    private var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }

    private var meshes: [RenderingMesh] = []
    public var animationCount: Int {
        return self.meshes.count
    }

    public var allAnimationsCompleted: (() -> Void)?

    public init?(wireframe: Bool = false) {
        let mainBundle = Bundle(for: MeshRenderer.self)

        guard let path = mainBundle.path(forResource: "LottieMeshSwiftBundle", ofType: "bundle") else {
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

        guard let loadedVertexProgram = defaultLibrary.makeFunction(name: "vertexPassthrough") else {
            return nil
        }

        func makeDescriptor(fragmentProgram: String) -> MTLRenderPipelineDescriptor {
            guard let loadedFragmentProgram = defaultLibrary.makeFunction(name: fragmentProgram) else {
                preconditionFailure()
            }

            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = loadedVertexProgram
            pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineStateDescriptor.sampleCount = 4
            return pipelineStateDescriptor
        }

        self.drawPassthroughPipelineState = try! device.makeRenderPipelineState(descriptor: makeDescriptor(fragmentProgram: "fragmentPassthrough"))
        var drawRadialGradientPipelineStates: [Int: MTLRenderPipelineState] = [:]

        for i in 2 ... 10 {
            drawRadialGradientPipelineStates[i] = try! device.makeRenderPipelineState(descriptor: makeDescriptor(fragmentProgram: "fragmentRadialGradient\(i)"))
        }

        self.drawRadialGradientPipelineStates = drawRadialGradientPipelineStates

        super.init(frame: CGRect(), device: device)

        self.sampleCount = 4

        self.isOpaque = false
        self.backgroundColor = .clear

        //self.metalLayer.device = self.device
        //self.pixelFormat = .bgra8Unorm
        self.framebufferOnly = true
        //self.metalLayer.framebufferOnly = true
        //if #available(iOS 11.0, *) {
            self.metalLayer.allowsNextDrawableTimeout = true
        //}
        //self.metalLayer.contentsScale = 2.0

        class DisplayLinkProxy: NSObject {
            weak var target: MeshRenderer?
            init(target: MeshRenderer) {
                self.target = target
            }

            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }

        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink?.add(to: .main, forMode: .common)
        self.displayLink?.isPaused = false

        self.isPaused = true
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    public func add(mesh: MeshAnimation, offset: CGPoint) {
        self.meshes.append(RenderingMesh(device: self.device!, mesh: mesh, offset: offset))
    }

    @objc private func displayLinkEvent() {
        self.draw()
    }

    override public func draw(_ rect: CGRect) {
        self.redraw(drawable: self.currentDrawable!)
    }

    private func redraw(drawable: MTLDrawable) {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }

        var removeMeshes: [Int] = []

        let renderPassDescriptor = self.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setCullMode(.none)
        /*if displayDebug {
            renderEncoder.setTriangleFillMode(.lines)
        }*/

        func addTriangle(vertexData: UnsafeMutablePointer<Float>, maxVertices: Int, nextVertexIndex: inout Int, vertices: [CGPoint], triangle: Triangle, transform: CGAffineTransform) {
            assert(nextVertexIndex + 3 <= maxVertices)
            for i in 0 ..< triangle.points.count {
                let vertexBase = vertexData.advanced(by: nextVertexIndex * (2 + 2))

                let point = vertices[triangle.points[i]].applying(transform)

                vertexBase.advanced(by: 0).pointee = Float(point.x)
                vertexBase.advanced(by: 1).pointee = Float(point.y)
                vertexBase.advanced(by: 2).pointee = Float(vertices[triangle.points[i]].x)
                vertexBase.advanced(by: 3).pointee = Float(vertices[triangle.points[i]].y)

                nextVertexIndex += 1
            }
        }

        for i in 0 ..< self.meshes.count {
            let mesh = self.meshes[i]

            var segmentVertexData: [Int: (start: Int, count: Int)] = [:]

            let vertexData = mesh.vertexBuffer.contents().assumingMemoryBound(to: Float.self)
            var nextVertexIndex = 0

            for i in 0 ..< mesh.mesh.frames[mesh.currentFrame].segments.count {
                let startIndex = nextVertexIndex
                let segment = mesh.mesh.frames[mesh.currentFrame].segments[i]
                for triangle in segment.triangles {
                    addTriangle(vertexData: vertexData, maxVertices: mesh.maxVertices, nextVertexIndex: &nextVertexIndex, vertices: segment.vertices, triangle: triangle, transform: segment.transform)
                }
                segmentVertexData[i] = (startIndex, nextVertexIndex - startIndex)
            }

            let transformData = mesh.transformBuffer.contents().assumingMemoryBound(to: Float.self)
            transformData.advanced(by: 0).pointee = Float(mesh.offset.x)
            transformData.advanced(by: 1).pointee = Float(mesh.offset.y)

            renderEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(mesh.transformBuffer, offset: 0, index: 1)

            var colorBytes: [Float] = [1.0, 0.0, 1.0, 1.0]

            loop: for i in 0 ..< mesh.mesh.frames[mesh.currentFrame].segments.count {
                let (startIndex, count) = segmentVertexData[i]!

                let segment = mesh.mesh.frames[mesh.currentFrame].segments[i]

                switch segment.fill {
                case let .color(color):
                    renderEncoder.setRenderPipelineState(self.drawPassthroughPipelineState)

                    colorBytes[0] = color.r
                    colorBytes[1] = color.g
                    colorBytes[2] = color.b
                    colorBytes[3] = color.a

                    renderEncoder.setFragmentBytes(&colorBytes, length: 4 * 4, index: 1)
                case let .gradient(gradient):
                    renderEncoder.setRenderPipelineState(self.drawRadialGradientPipelineStates[gradient.colors.count]!)

                    var startBytes: [Float] = [
                        Float(gradient.start.x),
                        Float(gradient.start.y)
                    ]
                    var endBytes: [Float] = [
                        Float(gradient.end.x),
                        Float(gradient.end.y)
                    ]
                    renderEncoder.setFragmentBytes(&startBytes, length: startBytes.count * 4, index: 1)
                    renderEncoder.setFragmentBytes(&endBytes, length: endBytes.count * 4, index: 2)

                    var colors: [Float] = []
                    for color in gradient.colors {
                        colors.append(color.r)
                        colors.append(color.g)
                        colors.append(color.b)
                        colors.append(color.a)
                    }
                    renderEncoder.setFragmentBytes(&colors, length: colors.count * 4, index: 3)

                    var steps: [Float] = gradient.colorLocations
                    renderEncoder.setFragmentBytes(&steps, length: colors.count * 4, index: 4)
                }

                renderEncoder.drawPrimitives(type: .triangle, vertexStart: startIndex, vertexCount: count, instanceCount: 1)
            }

            let nextFrame = mesh.currentFrame + 1
            if nextFrame >= mesh.mesh.frames.count {
                removeMeshes.append(i)
            } else {
                mesh.currentFrame = nextFrame
            }
        }

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        if !removeMeshes.isEmpty {
            for i in removeMeshes.reversed() {
                self.meshes.remove(at: i)
            }
            if self.meshes.isEmpty {
                self.allAnimationsCompleted?()
            }
        }
    }
}

private func generateSegments(geometry: CapturedGeometryNode, superAlpha: CGFloat = 1.0, path: [Int] = []) -> [MeshAnimation.Frame.Segment] {
    if geometry.isHidden || geometry.alpha.isZero {
        return []
    }

    var result: [MeshAnimation.Frame.Segment] = []

    for i in 0 ..< geometry.subnodes.count {
        let subResult = generateSegments(geometry: geometry.subnodes[i], superAlpha: superAlpha * geometry.alpha, path: path + [i]).map { segment in
            return MeshAnimation.Frame.Segment(vertices: segment.vertices, triangles: segment.triangles, fill: segment.fill, transform: segment.transform.concatenating(CATransform3DGetAffineTransform(geometry.transform)))
        }
        result.append(contentsOf: subResult)
    }

    if let displayItem = geometry.displayItem {
        var meshData: LottieMeshData?
        let triangleFill: TriangleFill

        switch displayItem.display {
        case let .fill(fill):
            switch fill.style {
            case let .color(color, alpha):
                triangleFill = .color(TriangleFill.Color(color).multiplied(alpha: Float(geometry.alpha * alpha * superAlpha)))
            case let .gradient(colors, positions, start, end, type):
                triangleFill = .gradient(TriangleFill.Gradient(colors: colors.map(TriangleFill.Color.init), colorLocations: positions.map(Float.init), start: start, end: end, isRadial: type == .radial))
            }

            let mappedFillRule: LottieMeshFillRule
            switch fill.fillRule {
            case .evenOdd:
                mappedFillRule = .evenOdd
            case .winding:
                mappedFillRule = .nonZero
            default:
                mappedFillRule = .evenOdd
            }

            meshData = LottieMeshData.generate(with: UIBezierPath(cgPath: displayItem.path), fill: LottieMeshFill(fillRule: mappedFillRule), stroke: nil)
        case let .stroke(stroke):
            switch stroke.style {
            case let .color(color, alpha):
                triangleFill = .color(TriangleFill.Color(color).multiplied(alpha: Float(geometry.alpha * alpha * superAlpha)))
            case let .gradient(colors, positions, start, end, type):
                triangleFill = .gradient(TriangleFill.Gradient(colors: colors.map(TriangleFill.Color.init), colorLocations: positions.map(Float.init), start: start, end: end, isRadial: type == .radial))
            }

            meshData = LottieMeshData.generate(with: UIBezierPath(cgPath: displayItem.path), fill: nil, stroke: LottieMeshStroke(lineWidth: stroke.lineWidth, lineJoin: stroke.lineJoin, lineCap: stroke.lineCap, miterLimit: stroke.miterLimit))
        }
        if let meshData = meshData, meshData.triangleCount() != 0 {
            var mappedTriangles: [Triangle] = []
            for i in 0 ..< meshData.triangleCount() {
                var v0: Int = 0
                var v1: Int = 0
                var v2: Int = 0
                meshData.getTriangleAt(i, v0: &v0, v1: &v1, v2: &v2)
                mappedTriangles.append(Triangle(points: [v0, v1, v2]))
            }

            var vertices: [CGPoint] = []
            for i in 0 ..< meshData.vertexCount() {
                var x: Float = 0.0
                var y: Float = 0.0
                meshData.getVertexAt(i, x: &x, y: &y)
                vertices.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
            }

            result.append(MeshAnimation.Frame.Segment(vertices: vertices, triangles: mappedTriangles, fill: triangleFill, transform: CATransform3DGetAffineTransform(geometry.transform)))
        }
    }

    return result
}

public func generateMeshAnimation(data: Data) -> MeshAnimation? {
    guard let animation = try? JSONDecoder().decode(Animation.self, from: data) else {
        return nil
    }
    let container = MyAnimationContainer(animation: animation)

    var frames: [MeshAnimation.Frame] = []

    for i in 0 ..< Int(animation.endFrame) {
        container.setFrame(frame: CGFloat(i))
        #if DEBUG
        print("Frame \(i) / \(Int(animation.endFrame))")
        #endif

        let geometry = container.captureGeometry()
        geometry.transform = CATransform3DMakeTranslation(256.0, 256.0, 0.0)
        let segments = generateSegments(geometry: geometry)
        frames.append(MeshAnimation.Frame(segments: segments))
    }

    return MeshAnimation(frames: frames)
}
