import Foundation
import MetalKit
import simd
import LottieCpp
    
/*enum PathShading {
    final class Gradient {
        enum GradientType {
            case linear
            case radial
        }
        
        struct ColorStop {
            var color: LottieColor
            var location: Float
            
            init(color: LottieColor, location: Float) {
                self.color = color
                self.location = location
            }
        }
        
        let gradientType: GradientType
        let colorStops: [ColorStop]
        let start: SIMD2<Float>
        let end: SIMD2<Float>
        
        init(gradientType: GradientType, colorStops: [ColorStop], start: SIMD2<Float>, end: SIMD2<Float>) {
            self.gradientType = gradientType
            self.colorStops = colorStops
            self.start = start
            self.end = end
        }
    }
    
    case color(LottieColor)
    case gradient(Gradient)
}

final class PathRenderSubpathFillState {
    private let buffer: PathRenderBuffer
    private let bezierDataBuffer: PathRenderBuffer
    let bufferOffset: Int
    private(set) var vertexCount: Int = 0
    
    private var firstPosition: SIMD2<Float>
    private var lastPosition: SIMD2<Float>
    
    private(set) var minPosition: SIMD2<Float>
    private(set) var maxPosition: SIMD2<Float>
    
    private var isClosed: Bool = false
    
    init(buffer: PathRenderBuffer, bezierDataBuffer: PathRenderBuffer, point: SIMD2<Float>) {
        self.buffer = buffer
        self.bezierDataBuffer = bezierDataBuffer
        self.bufferOffset = buffer.length
        
        self.firstPosition = point
        self.lastPosition = point
        self.minPosition = point
        self.maxPosition = point
        
        self.add(point: point)
    }
    
    func add(point: SIMD2<Float>) {
        self.buffer.append(float2: point)
        
        self.minPosition.x = min(self.minPosition.x, point.x)
        self.minPosition.y = min(self.minPosition.y, point.y)
        self.maxPosition.x = max(self.maxPosition.x, point.x)
        self.maxPosition.y = max(self.maxPosition.y, point.y)
        
        self.lastPosition = point
        
        self.vertexCount += 1
    }
    
    func addCurve(to point: SIMD2<Float>, cp1: SIMD2<Float>, cp2: SIMD2<Float>) {
        let stepCount = 8
        self.bezierDataBuffer.appendBezierData(
            bufferOffset: self.buffer.length / 4,
            start: self.lastPosition,
            end: point,
            cp1: cp1,
            cp2: cp2,
            offset: 0.0
        )
        self.buffer.appendZero(count: 4 * 2 * stepCount)
        self.vertexCount += stepCount
        
        let (curveMin, curveMax) = bezierBounds(p0: self.lastPosition, p1: cp1, p2: cp2, p3: point)
        
        self.minPosition.x = min(self.minPosition.x, curveMin.x)
        self.minPosition.y = min(self.minPosition.y, curveMin.y)
        self.maxPosition.x = max(self.maxPosition.x, curveMax.x)
        self.maxPosition.y = max(self.maxPosition.y, curveMax.y)
        
        self.lastPosition = point
    }
    
    func close() {
        if self.isClosed {
            assert(false)
        } else {
            self.isClosed = true
            
            if self.lastPosition != self.firstPosition {
                self.add(point: self.firstPosition)
            }
        }
    }
}

final class PathRenderFillState {
    private let buffer: PathRenderBuffer
    private let bezierDataBuffer: PathRenderBuffer
    private let fillRule: LottieFillRule
    private let shading: PathShading
    private let transform: CATransform3D
    
    private var currentSubpath: PathRenderSubpathFillState?
    private(set) var subpaths: [PathRenderSubpathFillState] = []
    
    init(buffer: PathRenderBuffer, bezierDataBuffer: PathRenderBuffer, fillRule: LottieFillRule, shading: PathShading, transform: CATransform3D) {
        self.buffer = buffer
        self.bezierDataBuffer = bezierDataBuffer
        self.fillRule = fillRule
        self.shading = shading
        self.transform = transform
    }
    
    func begin(point: SIMD2<Float>) {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.close()
            self.subpaths.append(currentSubpath)
            self.currentSubpath = nil
        }
        
        self.currentSubpath = PathRenderSubpathFillState(buffer: self.buffer, bezierDataBuffer: self.bezierDataBuffer, point: point)
    }
    
    func addLine(to point: SIMD2<Float>) {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.add(point: point)
        }
    }
    
    func addCurve(to point: SIMD2<Float>, cp1: SIMD2<Float>, cp2: SIMD2<Float>) {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.addCurve(to: point, cp1: cp1, cp2: cp2)
        }
    }
    
    func close() {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.close()
            self.subpaths.append(currentSubpath)
            self.currentSubpath = nil
        }
    }
    
    func encode(context: PathRenderContext, encoder: MTLRenderCommandEncoder, buffer: MTLBuffer) {
        if self.subpaths.isEmpty {
            return
        }
        var minPosition: SIMD2<Float> = self.subpaths[0].minPosition
        var maxPosition: SIMD2<Float> = self.subpaths[0].maxPosition
        for subpath in self.subpaths {
            minPosition.x = min(minPosition.x, subpath.minPosition.x)
            minPosition.y = min(minPosition.y, subpath.minPosition.y)
            maxPosition.x = max(maxPosition.x, subpath.maxPosition.x)
            maxPosition.y = max(maxPosition.y, subpath.maxPosition.y)
        }
        
        let localBoundingBox = CGRect(x: CGFloat(minPosition.x), y: CGFloat(minPosition.y), width: CGFloat(maxPosition.x - minPosition.x), height: CGFloat(maxPosition.y - minPosition.y))
        if localBoundingBox.isEmpty {
            return
        }
        
        var transformMatrix = simd_float4x4(
            SIMD4<Float>(Float(transform.m11), Float(transform.m12), Float(transform.m13), Float(transform.m14)),
            SIMD4<Float>(Float(transform.m21), Float(transform.m22), Float(transform.m23), Float(transform.m24)),
            SIMD4<Float>(Float(transform.m31), Float(transform.m32), Float(transform.m33), Float(transform.m34)),
            SIMD4<Float>(Float(transform.m41), Float(transform.m42), Float(transform.m43), Float(transform.m44))
        )
        
        let identityTransform = CATransform3DIdentity
        var identityTransformMatrix = SIMD16<Float>(
            Float(identityTransform.m11), Float(identityTransform.m12), Float(identityTransform.m13), Float(identityTransform.m14),
            Float(identityTransform.m21), Float(identityTransform.m22), Float(identityTransform.m23), Float(identityTransform.m24),
            Float(identityTransform.m31), Float(identityTransform.m32), Float(identityTransform.m33), Float(identityTransform.m34),
            Float(identityTransform.m41), Float(identityTransform.m42), Float(identityTransform.m43), Float(identityTransform.m44)
        )
        
        let transform = CATransform3DGetAffineTransform(self.transform)
        let boundingBox = localBoundingBox.applying(transform)
        let baseVertex = boundingBox.origin.applying(transform.inverted())
        
        encoder.setRenderPipelineState(context.clearPipelineState)
        
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
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        
        encoder.setRenderPipelineState(context.shapePipelineState)
        encoder.setVertexBytes(&transformMatrix, length: 4 * 4 * 4, index: 1)
        var baseVertexData = SIMD2<Float>(Float(baseVertex.x), Float(baseVertex.y))
        encoder.setVertexBytes(&baseVertexData, length: 4 * 2, index: 2)
        
        var modeBytes: Int32 = self.fillRule == .winding ? 0 : 1
        encoder.setFragmentBytes(&modeBytes, length: 4, index: 1)
        
        for subpath in self.subpaths {
            encoder.setVertexBuffer(buffer, offset: subpath.bufferOffset, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: (subpath.vertexCount - 1) * 3)
        }
        
        encoder.setVertexBytes(&quadVertices, length: MemoryLayout<SIMD4<Float>>.size * quadVertices.count, index: 0)
        encoder.setVertexBytes(&identityTransformMatrix, length: 4 * 4 * 4, index: 1)
        
        switch self.shading {
        case let .color(color):
            encoder.setRenderPipelineState(context.mergeColorFillPipelineState)
            
            var colorVector = SIMD4(Float(color.r), Float(color.g), Float(color.b), Float(color.a))
            encoder.setFragmentBytes(&colorVector, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        case let .gradient(gradient):
            switch gradient.gradientType {
            case .linear:
                encoder.setRenderPipelineState(context.mergeLinearGradientFillPipelineState)
            case .radial:
                encoder.setRenderPipelineState(context.mergeRadialGradientFillPipelineState)
            }
            
            var modeBytes: Int32 = self.fillRule == .winding ? 0 : 1
            encoder.setFragmentBytes(&modeBytes, length: 4, index: 1)
            
            let colorStopSize = 4 * 4 + 4
            var colorStopsData = Data(count: colorStopSize * gradient.colorStops.count)
            colorStopsData.withUnsafeMutableBytes { buffer in
                let bytes = buffer.baseAddress!.assumingMemoryBound(to: Float.self)
                for i in 0 ..< gradient.colorStops.count {
                    let colorStop = gradient.colorStops[i]
                    bytes[i * 5 + 0] = Float(colorStop.color.r)
                    bytes[i * 5 + 1] = Float(colorStop.color.g)
                    bytes[i * 5 + 2] = Float(colorStop.color.b)
                    bytes[i * 5 + 3] = Float(colorStop.color.a)
                    bytes[i * 5 + 4] = colorStop.location
                }
                encoder.setFragmentBytes(buffer.baseAddress!, length: buffer.count, index: 0)
            }
            
            var numColorStops: UInt32 = UInt32(gradient.colorStops.count)
            encoder.setFragmentBytes(&numColorStops, length: 4, index: 2)
            
            var startPosition = transformMatrix * SIMD4<Float>(gradient.start.x, gradient.start.y, 0.0, 1.0)
            encoder.setFragmentBytes(&startPosition, length: 4 * 2, index: 3)
            var endPosition = transformMatrix * SIMD4<Float>(gradient.end.x, gradient.end.y, 0.0, 1.0)
            encoder.setFragmentBytes(&endPosition, length: 4 * 2, index: 4)
        }
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
    }
}
*/
