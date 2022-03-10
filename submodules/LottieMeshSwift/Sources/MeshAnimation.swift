import Foundation
import Metal
import MetalKit
import LottieMeshBinding
import Postbox
import ManagedFile

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

final class DataRange {
    let data: Data
    let range: Range<Int>
    
    init(data: Data, range: Range<Int>) {
        self.data = data
        self.range = range
    }
    
    var count: Int {
        return self.range.upperBound - self.range.lowerBound
    }
}

public final class MeshAnimation {
    final class Frame {
        final class Segment {
            let vertices: DataRange
            let triangles: DataRange
            let fill: TriangleFill
            let transform: CGAffineTransform

            init(vertices: DataRange, triangles: DataRange, fill: TriangleFill, transform: CGAffineTransform) {
                self.vertices = vertices
                self.triangles = triangles
                self.fill = fill
                self.transform = transform
            }

            static func read(buffer: MeshReadBuffer) -> Segment {
                let vertCount = Int(buffer.readInt32())
                let vertices = buffer.readDataRange(count: vertCount)

                let triCount = Int(buffer.readInt32())
                let triangles = buffer.readDataRange(count: triCount)

                return Segment(vertices: vertices, triangles: triangles, fill: TriangleFill.read(buffer: buffer), transform: CGAffineTransform(a: CGFloat(buffer.readFloat()), b: CGFloat(buffer.readFloat()), c: CGFloat(buffer.readFloat()), d: CGFloat(buffer.readFloat()), tx: CGFloat(buffer.readFloat()), ty: CGFloat(buffer.readFloat())))
            }

            func write(buffer: MeshWriteBuffer) {
                buffer.writeInt32(Int32(self.vertices.count))
                buffer.write(self.vertices)
                buffer.writeInt32(Int32(self.triangles.count))
                buffer.write(self.triangles)

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

        /*func write(buffer: MeshWriteBuffer) {
            buffer.writeInt32(Int32(self.segments.count))
            for segment in self.segments {
                segment.write(buffer: buffer)
            }
        }*/
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

    /*public func write(buffer: MeshWriteBuffer) {
        buffer.writeInt32(Int32(self.frames.count))
        for frame in self.frames {
            frame.write(buffer: buffer)
        }
    }*/
}

@available(iOS 13.0, *)
public final class MeshRenderer: MTKView {
    private final class RenderingMesh {
        let mesh: MeshAnimation
        let offset: CGPoint
        let loop: Bool
        var currentFrame: Int = 0
        let vertexBuffer: MTLBuffer
        let indexBuffer: MTLBuffer
        let transformBuffer: MTLBuffer
        let maxVertices: Int
        let maxTriangles: Int

        init(device: MTLDevice, mesh: MeshAnimation, offset: CGPoint, loop: Bool) {
            self.mesh = mesh
            self.offset = offset
            self.loop = loop

            var maxTriangles = 0
            var maxVertices = 0
            for i in 0 ..< mesh.frames.count {
                var frameTriangles = 0
                var frameVertices = 0
                for segment in mesh.frames[i].segments {
                    frameTriangles += segment.triangles.count / (4 * 3)
                    frameVertices += segment.vertices.count / (4 * 2)
                }
                maxTriangles = max(maxTriangles, frameTriangles)
                maxVertices = max(maxVertices, frameVertices)
            }

            self.maxVertices = maxVertices
            self.maxTriangles = maxTriangles

            let vertexBufferArray = Array<Float>(repeating: 0.0, count: self.maxVertices * 2)
            guard let vertexBuffer = device.makeBuffer(bytes: vertexBufferArray, length: vertexBufferArray.count * MemoryLayout.size(ofValue: vertexBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
                preconditionFailure()
            }
            self.vertexBuffer = vertexBuffer

            let indexBufferArray = Array<UInt32>(repeating: 0, count: self.maxTriangles * 3)
            guard let indexBuffer = device.makeBuffer(bytes: indexBufferArray, length: indexBufferArray.count * MemoryLayout.size(ofValue: indexBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
                preconditionFailure()
            }
            self.indexBuffer = indexBuffer

            let transformBufferArray = Array<Float>(repeating: 0.0, count: 2)
            guard let transformBuffer = device.makeBuffer(bytes: transformBufferArray, length: transformBufferArray.count * MemoryLayout.size(ofValue: transformBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
                preconditionFailure()
            }
            self.transformBuffer = transformBuffer
        }
    }

    private let wireframe: Bool
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
        self.wireframe = wireframe
        
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
        if #available(iOS 15.0, *) {
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 60.0, preferred: 60.0)
            //self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10.0, maximum: 60.0, preferred: 10.0)
        }
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

    public func add(mesh: MeshAnimation, offset: CGPoint, loop: Bool = false) {
        self.meshes.append(RenderingMesh(device: self.device!, mesh: mesh, offset: offset, loop: loop))
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
        if self.wireframe {
            renderEncoder.setTriangleFillMode(.lines)
        }

        func addTriangle(vertexData: UnsafeMutablePointer<Float>, maxVertices: Int, nextVertexIndex: inout Int, vertices: Data, triangles: Data, triangleIndex: Int) {
            assert(nextVertexIndex + 3 <= maxVertices)
            vertices.withUnsafeBytes { vertices in
                let verticesPointer = vertices.baseAddress!.assumingMemoryBound(to: Float.self)

                triangles.withUnsafeBytes { triangles in
                    let trianglesPointer = triangles.baseAddress!.assumingMemoryBound(to: Int32.self)

                    for i in 0 ..< 3 {
                        let vertexBase = vertexData.advanced(by: nextVertexIndex * 2)

                        let vertexIndex = Int(trianglesPointer.advanced(by: triangleIndex * 3 + i).pointee)
                        let vertex = verticesPointer.advanced(by: vertexIndex * 2)

                        vertexBase.advanced(by: 0).pointee = vertex.advanced(by: 0).pointee
                        vertexBase.advanced(by: 1).pointee = vertex.advanced(by: 1).pointee

                        nextVertexIndex += 1
                    }
                }
            }
        }

        for i in 0 ..< self.meshes.count {
            let mesh = self.meshes[i]

            let transformData = mesh.transformBuffer.contents().assumingMemoryBound(to: Float.self)
            transformData.advanced(by: 0).pointee = Float(mesh.offset.x)
            transformData.advanced(by: 1).pointee = Float(mesh.offset.y)

            renderEncoder.setVertexBuffer(mesh.transformBuffer, offset: 0, index: 1)

            var colorBytes: [Float] = [1.0, 0.0, 1.0, 1.0]

            var segmentVertexData: [Int: (vStart: Int, vCount: Int, iStart: Int, iCount: Int)] = [:]

            let vertexData = mesh.vertexBuffer.contents().assumingMemoryBound(to: Float.self)
            let indexData = mesh.indexBuffer.contents().assumingMemoryBound(to: Int32.self)
            var nextVertexIndex = 0
            var nextIndexIndex = 0

            for i in 0 ..< mesh.mesh.frames[mesh.currentFrame].segments.count {
                let segment = mesh.mesh.frames[mesh.currentFrame].segments[i]
                let startVertexIndex = nextVertexIndex
                let startIndexIndex = nextIndexIndex

                segment.vertices.data.withUnsafeBytes { vertices in
                    let _ = memcpy(vertexData.advanced(by: nextVertexIndex * 2), vertices.baseAddress!.advanced(by: segment.vertices.range.lowerBound), segment.vertices.count)
                }
                nextVertexIndex += segment.vertices.count / (4 * 2)

                let baseVertexIndex = Int32(startVertexIndex)

                segment.triangles.data.withUnsafeBytes { triangles in
                    let _ = memcpy(indexData.advanced(by: nextIndexIndex), triangles.baseAddress!.advanced(by: segment.triangles.range.lowerBound), segment.triangles.count)
                }
                nextIndexIndex += segment.triangles.count / 4

                segmentVertexData[i] = (startVertexIndex, nextVertexIndex - startVertexIndex, startIndexIndex, nextIndexIndex - startIndexIndex)

                let (_, _, iStart, iCount) = segmentVertexData[i]!

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

                var transformBytes = Array<Float>(repeating: 0.0, count: 4 * 4)
                let transform = CATransform3DMakeAffineTransform(segment.transform)
                transformBytes[0] = Float(transform.m11)
                transformBytes[1] = Float(transform.m12)
                transformBytes[2] = Float(transform.m13)
                transformBytes[3] = Float(transform.m14)
                transformBytes[4] = Float(transform.m21)
                transformBytes[5] = Float(transform.m22)
                transformBytes[6] = Float(transform.m23)
                transformBytes[7] = Float(transform.m24)
                transformBytes[8] = Float(transform.m31)
                transformBytes[9] = Float(transform.m32)
                transformBytes[10] = Float(transform.m33)
                transformBytes[11] = Float(transform.m34)
                transformBytes[12] = Float(transform.m41)
                transformBytes[13] = Float(transform.m42)
                transformBytes[14] = Float(transform.m43)
                transformBytes[15] = Float(transform.m44)

                renderEncoder.setVertexBytes(&transformBytes, length: transformBytes.count * 4, index: 2)
                var baseVertexIndexBytes: Int32 = Int32(baseVertexIndex)
                renderEncoder.setVertexBytes(&baseVertexIndexBytes, length: 4, index: 3)

                renderEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: iCount, indexType: .uint32, indexBuffer: mesh.indexBuffer, indexBufferOffset: iStart * 4)
            }

            let nextFrame = mesh.currentFrame + 1
            if nextFrame >= mesh.mesh.frames.count {
                if mesh.loop {
                    mesh.currentFrame = 0
                } else {
                    removeMeshes.append(i)
                }
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

private func generateSegments(writeBuffer: MeshWriteBuffer, segmentCount: inout Int, geometry: CapturedGeometryNode, superAlpha: CGFloat, superTransform: CGAffineTransform) {
    if geometry.isHidden || geometry.alpha.isZero {
        return
    }

    for i in 0 ..< geometry.subnodes.count {
        generateSegments(writeBuffer: writeBuffer, segmentCount: &segmentCount, geometry: geometry.subnodes[i], superAlpha: superAlpha * geometry.alpha, superTransform: CATransform3DGetAffineTransform(geometry.transform).concatenating(superTransform))
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
                triangleFill = .gradient(TriangleFill.Gradient(colors: colors.map { TriangleFill.Color($0).multiplied(alpha: Float(geometry.alpha * superAlpha)) }, colorLocations: positions.map(Float.init), start: start, end: end, isRadial: type == .radial))
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
            let mappedVertices = WriteBuffer()
            for i in 0 ..< meshData.vertexCount() {
                var x: Float = 0.0
                var y: Float = 0.0
                meshData.getVertexAt(i, x: &x, y: &y)
                mappedVertices.writeFloat(x)
                mappedVertices.writeFloat(y)
            }
            
            let trianglesData = Data(bytes: meshData.getTriangles(), count: meshData.triangleCount() * 3 * 4)

            let verticesData = mappedVertices.makeData()
            
            let segment = MeshAnimation.Frame.Segment(vertices: DataRange(data: verticesData, range: 0 ..< verticesData.count), triangles: DataRange(data: trianglesData, range: 0 ..< trianglesData.count), fill: triangleFill, transform: CATransform3DGetAffineTransform(geometry.transform).concatenating(superTransform))
            
            segment.write(buffer: writeBuffer)
            segmentCount += 1
        }
    }
}

public func generateMeshAnimation(data: Data) -> TempBoxFile? {
    guard let animation = try? JSONDecoder().decode(Animation.self, from: data) else {
        return nil
    }
    let container = MyAnimationContainer(animation: animation)
    
    let tempFile = TempBox.shared.tempFile(fileName: "data")
    guard let file = ManagedFile(queue: nil, path: tempFile.path, mode: .readwrite) else {
        return nil
    }
    let writeBuffer = MeshWriteBuffer(file: file)
    
    let frameCountOffset = writeBuffer.offset
    writeBuffer.writeInt32(0)
    
    var frameCount: Int = 0

    for i in 0 ..< Int(animation.endFrame) {
        container.setFrame(frame: CGFloat(i))
        //#if DEBUG
        print("Frame \(i) / \(Int(animation.endFrame))")
        //#endif
        
        let segmentCountOffset = writeBuffer.offset
        writeBuffer.writeInt32(0)
        var segmentCount: Int = 0

        let geometry = container.captureGeometry()
        geometry.transform = CATransform3DMakeTranslation(256.0, 256.0, 0.0)
        
        generateSegments(writeBuffer: writeBuffer, segmentCount: &segmentCount, geometry: geometry, superAlpha: 1.0, superTransform: .identity)
        
        let currentOffset = writeBuffer.offset
        writeBuffer.seek(offset: segmentCountOffset)
        writeBuffer.writeInt32(Int32(segmentCount))
        
        writeBuffer.seek(offset: currentOffset)
        
        frameCount += 1
    }
    
    let currentOffset = writeBuffer.offset
    writeBuffer.seek(offset: frameCountOffset)
    writeBuffer.writeInt32(Int32(frameCount))
    writeBuffer.seek(offset: currentOffset)

    return tempFile
}

public final class MeshRenderingContext {
    
}
