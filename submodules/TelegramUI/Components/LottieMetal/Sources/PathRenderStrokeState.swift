import Foundation
import MetalKit
import LottieCpp
    
/*func evaluateBezier(p0: SIMD2<Float>, p1: SIMD2<Float>, p2: SIMD2<Float>, p3: SIMD2<Float>, t: Float) -> SIMD2<Float> {
    let t2 = t * t
    let t3 = t * t * t

    let A = (3 * t2 - 3 * t3)
    let B = (3 * t3 - 6 * t2 + 3 * t)
    let C = (3 * t2 - t3 - 3 * t + 1)

    let value = t3 * p3 + A * p2 + B * p1 + C * p0
    return value
}
    
func evaluateBezier(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
    let oneMinusT = 1.0 - t
    
    let value = oneMinusT * oneMinusT * oneMinusT * p0 + 3.0 * t * oneMinusT * oneMinusT * p1 + 3.0 * t * t * oneMinusT * p2 + t * t * t * p3
    return value
}
    
func solveQuadratic(p0: Float, p1: Float, p2: Float, p3: Float) -> (Float, Float) {
    let i = p1 - p0
    let j = p2 - p1
    let k = p3 - p2

    let a = (3 * i) - (6 * j) + (3 * k)
    let b = (6 * j) - (6 * i)
    let c = (3 * i)

    let sqrtPart = (b * b) - (4 * a * c)
    let hasSolution = sqrtPart >= 0
    if !hasSolution {
        return (.nan, .nan)
    }

    let t1 = (-b + sqrt(sqrtPart)) / (2 * a)
    let t2 = (-b - sqrt(sqrtPart)) / (2 * a)

    var s1: Float = .nan
    var s2: Float = .nan

    if t1 >= 0.0 && t1 <= 1.0 {
        s1 = evaluateBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t1)
    }

    if t2 >= 0.0 && t2 <= 1.0 {
        s2 = evaluateBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t2)
    }

    return (s1, s2)
}
    
func bezierBounds(p0: SIMD2<Float>, p1: SIMD2<Float>, p2: SIMD2<Float>, p3: SIMD2<Float>) -> (minPosition: SIMD2<Float>, maxPosition: SIMD2<Float>) {
    let (solX1, solX2) = solveQuadratic(p0: p0.x, p1: p1.x, p2: p2.x, p3: p3.x)
    let (solY1, solY2) = solveQuadratic(p0: p0.y, p1: p1.y, p2: p2.y, p3: p3.y)
    
    var minX = min(p0.x, p3.x)
    var maxX = max(p0.x, p3.x)
    
    if !solX1.isNaN {
        minX = min(minX, solX1)
        maxX = max(maxX, solX1)
    }
    
    if !solX2.isNaN {
        minX = min(minX, solX2)
        maxX = max(maxX, solX2)
    }
    
    var minY = min(p0.y, p3.y)
    var maxY = max(p0.y, p3.y)
    
    if !solY1.isNaN {
        minY = min(minY, solY1)
        maxY = max(maxY, solY1)
    }
    
    if !solY2.isNaN {
        minY = min(minY, solY2)
        maxY = max(maxY, solY2)
    }
    
    return (SIMD2<Float>(minX, minY), SIMD2<Float>(maxX, maxY))
}

final class PathRenderSubpathStrokeState {
    struct TerminalState {
        var bufferOffset: Int
        var segmentCount: Int
    }
    
    enum UnresolvedPosition {
        case position(SIMD2<Float>)
        case curve(p0: SIMD2<Float>, p1: SIMD2<Float>, p2: SIMD2<Float>, p3: SIMD2<Float>, t: Float)
        
        func resolve() -> SIMD2<Float> {
            switch self {
            case let .position(value):
                return value
            case let .curve(p0, p1, p2, p3, t):
                return evaluateBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            }
        }
    }
    
    private let buffer: PathRenderBuffer
    private let bezierDataBuffer: PathRenderBuffer
    let bufferOffset: Int
    private(set) var vertexCount: Int = 0
    
    private(set) var terminalState: TerminalState?
    
    private(set) var curveJoinVertexRanges: [Range<Int>] = []
    
    private var firstPosition: SIMD2<Float>
    private var secondPosition: UnresolvedPosition
    private var thirdPosition: UnresolvedPosition
    
    private var lastPosition: SIMD2<Float>
    private var lastMinus1Position: UnresolvedPosition
    private var lastMinus2Position: UnresolvedPosition
    
    private(set) var isClosed: Bool = false
    private(set) var isCompleted: Bool = false
    
    init(buffer: PathRenderBuffer, bezierDataBuffer: PathRenderBuffer, point: SIMD2<Float>) {
        self.buffer = buffer
        self.bezierDataBuffer = bezierDataBuffer
        self.bufferOffset = buffer.length
        
        self.firstPosition = point
        self.secondPosition = .position(point)
        self.thirdPosition = .position(point)
        self.lastPosition = point
        self.lastMinus1Position = .position(point)
        self.lastMinus2Position = .position(point)
        
        self.add(point: point)
    }
    
    func add(point: SIMD2<Float>) {
        self.buffer.append(float2: point)
        
        self.lastMinus2Position = self.lastMinus1Position
        self.lastMinus1Position = .position(self.lastPosition)
        self.lastPosition = point
        
        self.vertexCount += 1
        if self.vertexCount == 2 {
            self.secondPosition = .position(point)
        } else if self.vertexCount == 3 {
            self.thirdPosition = .position(point)
        }
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
        
        if self.vertexCount == 1 {
            self.secondPosition = .curve(p0: self.lastPosition, p1: cp1, p2: cp2, p3: point, t: Float(1) / Float(stepCount))
            self.thirdPosition = .curve(p0: self.lastPosition, p1: cp1, p2: cp2, p3: point, t: Float(2) / Float(stepCount))
        }
        
        self.vertexCount += stepCount
        
        self.lastMinus2Position = .curve(p0: self.lastPosition, p1: cp1, p2: cp2, p3: point, t: Float(stepCount - 2) / Float(stepCount))
        self.lastMinus1Position = .curve(p0: self.lastPosition, p1: cp1, p2: cp2, p3: point, t: Float(stepCount - 1) / Float(stepCount))
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
    
    func complete() {
        if self.isCompleted {
            assert(false)
        } else {
            if self.isClosed {
                if self.vertexCount >= 3 {
                    self.buffer.append(float2: self.secondPosition.resolve())
                    self.buffer.append(float2: self.thirdPosition.resolve())
                    self.vertexCount += 2
                }
            } else {
                if self.vertexCount == 2 {
                    let terminalBufferOffset = self.buffer.length
                    
                    let resolvedSecond = self.secondPosition.resolve()
                    self.buffer.append(float2: self.firstPosition)
                    self.buffer.append(float2: self.firstPosition * 0.5 + resolvedSecond * 0.5)
                    self.buffer.append(float2: resolvedSecond)
                    
                    self.buffer.append(float2: resolvedSecond)
                    self.buffer.append(float2: self.firstPosition * 0.5 + resolvedSecond * 0.5)
                    self.buffer.append(float2: self.firstPosition)
                    
                    self.terminalState = TerminalState(bufferOffset: terminalBufferOffset, segmentCount: 2)
                } else if self.vertexCount >= 3 {
                    let terminalBufferOffset = self.buffer.length
                    
                    self.buffer.append(float2: self.firstPosition)
                    self.buffer.append(float2: self.secondPosition.resolve())
                    self.buffer.append(float2: self.thirdPosition.resolve())
                    
                    self.buffer.append(float2: self.lastPosition)
                    self.buffer.append(float2: self.lastMinus1Position.resolve())
                    self.buffer.append(float2: self.lastMinus2Position.resolve())
                    
                    self.terminalState = TerminalState(bufferOffset: terminalBufferOffset, segmentCount: 2)
                }
            }
        }
    }
}

final class PathRenderStrokeState {
    private let buffer: PathRenderBuffer
    private let bezierDataBuffer: PathRenderBuffer
    private let lineWidth: Float
    private let lineJoin: CGLineJoin
    private let lineCap: CGLineCap
    private let miterLimit: Float
    private let color: LottieColor
    private let transform: CATransform3D
    
    private var currentSubpath: PathRenderSubpathStrokeState?
    private(set) var subpaths: [PathRenderSubpathStrokeState] = []
    
    init(buffer: PathRenderBuffer, bezierDataBuffer: PathRenderBuffer, lineWidth: Float, lineJoin: CGLineJoin, lineCap: CGLineCap, miterLimit: Float, color: LottieColor, transform: CATransform3D) {
        self.buffer = buffer
        self.bezierDataBuffer = bezierDataBuffer
        self.lineWidth = lineWidth
        self.lineJoin = lineJoin
        self.lineCap = lineCap
        self.miterLimit = miterLimit
        self.color = color
        self.transform = transform
    }
    
    func begin(point: SIMD2<Float>) {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.complete()
            self.subpaths.append(currentSubpath)
            self.currentSubpath = nil
        }
        
        self.currentSubpath = PathRenderSubpathStrokeState(buffer: self.buffer, bezierDataBuffer: self.bezierDataBuffer, point: point)
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
            currentSubpath.complete()
            self.subpaths.append(currentSubpath)
            self.currentSubpath = nil
        }
    }
    
    func complete() {
        if let currentSubpath = self.currentSubpath {
            currentSubpath.complete()
            self.subpaths.append(currentSubpath)
            self.currentSubpath = nil
        }
    }
    
    func encode(context: PathRenderContext, encoder: MTLRenderCommandEncoder, buffer: MTLBuffer) {
        if self.subpaths.isEmpty {
            return
        }
        
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        
        var colorVector = SIMD4(Float(color.r), Float(color.g), Float(color.b), Float(color.a))
        encoder.setFragmentBytes(&colorVector, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        var transformMatrix = SIMD16<Float>(
            Float(transform.m11), Float(transform.m12), Float(transform.m13), Float(transform.m14),
            Float(transform.m21), Float(transform.m22), Float(transform.m23), Float(transform.m24),
            Float(transform.m31), Float(transform.m32), Float(transform.m33), Float(transform.m34),
            Float(transform.m41), Float(transform.m42), Float(transform.m43), Float(transform.m44)
        )
        encoder.setVertexBytes(&transformMatrix, length: 4 * 4 * 4, index: 1)
        
        let capRes2: Float
        switch self.lineCap {
        case .butt:
            capRes2 = 2.0
        case .square:
            capRes2 = 6.0
        case .round:
            capRes2 = 24.0
        @unknown default:
            capRes2 = 2.0
        }
        let joinRes2: Float = self.lineJoin == .round ? 16.0 : 2.0
        
        func computeCount(isEndpoints: Bool, insertCaps: Bool) -> SIMD2<Float> {
            if insertCaps {
                if isEndpoints {
                    return SIMD2<Float>(capRes2, max(capRes2, joinRes2))
                } else {
                    return SIMD2<Float>(max(capRes2, joinRes2), max(capRes2, joinRes2))
                }
            } else {
                if isEndpoints {
                    return SIMD2<Float>(capRes2, joinRes2)
                } else {
                    return SIMD2<Float>(joinRes2, joinRes2)
                }
            }
        }
        
        var hasTerminalStates = false
        
        for subpath in self.subpaths {
            let segmentCount = subpath.vertexCount - 1
            if segmentCount <= 0 {
                continue
            }
            
            if subpath.vertexCount >= 4 {
                encoder.setRenderPipelineState(context.strokeInnerPipelineState)
                
                encoder.setVertexBufferOffset(subpath.bufferOffset, index: 0)
                
                var vertCnt2 = computeCount(isEndpoints: false, insertCaps: false)
                encoder.setVertexBytes(&vertCnt2, length: 4 * 2, index: 2)
                
                var capJoinRes2 = SIMD2<Float>(capRes2, joinRes2)
                encoder.setVertexBytes(&capJoinRes2, length: 4 * 2, index: 3)
                
                var isRoundJoinValue: UInt32 = self.lineJoin == .round ? 1 : 0
                encoder.setVertexBytes(&isRoundJoinValue, length: 4, index: 4)
                
                var isRoundCapValue: UInt32 = self.lineCap == .round ? 1 : 0
                encoder.setVertexBytes(&isRoundCapValue, length: 4, index: 5)
                
                var miterLimitValue: Float = self.lineJoin == .miter ? self.miterLimit : 1.0
                encoder.setVertexBytes(&miterLimitValue, length: 4, index: 6)
                
                var lineWidthValue: Float = self.lineWidth * 0.5
                encoder.setVertexBytes(&lineWidthValue, length: 4, index: 7)
                
                let vertexCount = 6 + Int(vertCnt2.x) + Int(vertCnt2.y) + 2
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount, instanceCount: subpath.vertexCount - 4 + 1, baseInstance: 0)
            }
            
            if subpath.terminalState != nil {
                hasTerminalStates = true
            }
        }
        
        if hasTerminalStates {
            encoder.setRenderPipelineState(context.strokeTerminalPipelineState)
            
            for subpath in self.subpaths {
                let segmentCount = subpath.vertexCount - 1
                if segmentCount <= 0 {
                    continue
                }
                
                if !subpath.isClosed {
                    if let terminalState = subpath.terminalState {
                        encoder.setVertexBufferOffset(terminalState.bufferOffset, index: 0)
                        
                        var vertCnt2 = computeCount(isEndpoints: true, insertCaps: false)
                        encoder.setVertexBytes(&vertCnt2, length: 4 * 2, index: 2)
                        
                        var capJoinRes2 = SIMD2<Float>(capRes2, joinRes2)
                        encoder.setVertexBytes(&capJoinRes2, length: 4 * 2, index: 3)
                        
                        var isRoundJoinValue: UInt32 = self.lineJoin == .round ? 1 : 0
                        encoder.setVertexBytes(&isRoundJoinValue, length: 4, index: 4)
                        
                        var isRoundCapValue: UInt32 = self.lineCap == .round ? 1 : 0
                        encoder.setVertexBytes(&isRoundCapValue, length: 4, index: 5)
                        
                        var miterLimitValue: Float = self.lineJoin == .miter ? self.miterLimit : 1.0
                        encoder.setVertexBytes(&miterLimitValue, length: 4, index: 6)
                        
                        var lineWidthValue: Float = self.lineWidth * 0.5
                        encoder.setVertexBytes(&lineWidthValue, length: 4, index: 7)
                        
                        let vertexCount = 6 + Int(vertCnt2.x) + Int(vertCnt2.y) + 2
                        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount, instanceCount: terminalState.segmentCount, baseInstance: 0)
                    }
                }
            }
        }
    }
}*/
