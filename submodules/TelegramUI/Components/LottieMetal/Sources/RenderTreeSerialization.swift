import Foundation
import LottieCpp

final class WriteBuffer {
    private(set) var data: Data
    private var capacity: Int
    var length: Int
    
    init() {
        self.capacity = 1024
        self.data = Data(count: self.capacity)
        self.length = 0
    }
    
    func trim() {
        self.data.count = self.length
        self.capacity = self.data.count
    }
    
    func write(bytes: UnsafeRawBufferPointer) {
        if self.data.count < self.length + bytes.count {
            self.data.count = self.data.count * 2
        }
        self.data.withUnsafeMutableBytes { buffer -> Void in
            memcpy(buffer.baseAddress!.advanced(by: self.length), bytes.baseAddress!, bytes.count)
        }
        self.length += bytes.count
    }
    
    func write(uInt32 value: UInt32) {
        var value = value
        withUnsafeBytes(of: &value, { bytes in
            self.write(bytes: bytes)
        })
    }
    
    func write(uInt16 value: UInt16) {
        var value = value
        withUnsafeBytes(of: &value, { bytes in
            self.write(bytes: bytes)
        })
    }
    
    func write(uInt8 value: UInt8) {
        var value = value
        withUnsafeBytes(of: &value, { bytes in
            self.write(bytes: bytes)
        })
    }
    
    func write(float value: Float) {
        var value = value
        withUnsafeBytes(of: &value, { bytes in
            self.write(bytes: bytes)
        })
    }
    
    func write(point: CGPoint) {
        self.write(float: Float(point.x))
        self.write(float: Float(point.y))
    }
    
    func write(size: CGSize) {
        self.write(float: Float(size.width))
        self.write(float: Float(size.height))
    }
    
    func write(rect: CGRect) {
        self.write(point: rect.origin)
        self.write(size: rect.size)
    }
    
    func write(transform: CATransform3D) {
        self.write(float: Float(transform.m11))
        self.write(float: Float(transform.m12))
        self.write(float: Float(transform.m13))
        self.write(float: Float(transform.m14))
        self.write(float: Float(transform.m21))
        self.write(float: Float(transform.m22))
        self.write(float: Float(transform.m23))
        self.write(float: Float(transform.m24))
        self.write(float: Float(transform.m31))
        self.write(float: Float(transform.m32))
        self.write(float: Float(transform.m33))
        self.write(float: Float(transform.m34))
        self.write(float: Float(transform.m41))
        self.write(float: Float(transform.m42))
        self.write(float: Float(transform.m43))
        self.write(float: Float(transform.m44))
    }
}

final class ReadBuffer {
    private let data: Data
    private var offset: Int
    
    init(data: Data) {
        self.data = data
        self.offset = 0
    }
    
    func read(bytes: UnsafeMutableRawBufferPointer) {
        if self.offset + bytes.count <= self.data.count {
            self.data.withUnsafeBytes { buffer -> Void in
                memcpy(bytes.baseAddress!, buffer.baseAddress!.advanced(by: self.offset), bytes.count)
            }
            self.offset += bytes.count
        } else {
            preconditionFailure()
        }
    }
    
    func readUInt32() -> UInt32 {
        var value: UInt32 = 0
        withUnsafeMutableBytes(of: &value, { bytes in
            self.read(bytes: bytes)
        })
        return value
    }
    
    func readUInt16() -> UInt16 {
        var value: UInt16 = 0
        withUnsafeMutableBytes(of: &value, { bytes in
            self.read(bytes: bytes)
        })
        return value
    }
    
    func readUInt8() -> UInt8 {
        var value: UInt8 = 0
        withUnsafeMutableBytes(of: &value, { bytes in
            self.read(bytes: bytes)
        })
        return value
    }
    
    func readFloat() -> Float {
        var value: Float = 0
        withUnsafeMutableBytes(of: &value, { bytes in
            self.read(bytes: bytes)
        })
        return value
    }
    
    func readPoint() -> CGPoint {
        return CGPoint(x: CGFloat(self.readFloat()), y: CGFloat(self.readFloat()))
    }
    
    func readSize() -> CGSize {
        return CGSize(width: CGFloat(self.readFloat()), height: CGFloat(self.readFloat()))
    }
    
    func readRect() -> CGRect {
        return CGRect(origin: self.readPoint(), size: self.readSize())
    }
    
    func readTransform() -> CATransform3D {
        return CATransform3D(
            m11: CGFloat(self.readFloat()),
            m12: CGFloat(self.readFloat()),
            m13: CGFloat(self.readFloat()),
            m14: CGFloat(self.readFloat()),
            m21: CGFloat(self.readFloat()),
            m22: CGFloat(self.readFloat()),
            m23: CGFloat(self.readFloat()),
            m24: CGFloat(self.readFloat()),
            m31: CGFloat(self.readFloat()),
            m32: CGFloat(self.readFloat()),
            m33: CGFloat(self.readFloat()),
            m34: CGFloat(self.readFloat()),
            m41: CGFloat(self.readFloat()),
            m42: CGFloat(self.readFloat()),
            m43: CGFloat(self.readFloat()),
            m44: CGFloat(self.readFloat())
        )
    }
}

private extension LottieColor {
    init(argb: UInt32) {
        self.init(r: CGFloat((argb >> 16) & 0xff) / 255.0, g: CGFloat((argb >> 8) & 0xff) / 255.0, b: CGFloat(argb & 0xff) / 255.0, a: CGFloat((argb >> 24) & 0xff) / 255.0)
    }
    
    var argb: UInt32 {
        return (UInt32(self.a * 255.0) << 24) | (UInt32(max(0.0, self.r) * 255.0) << 16) | (UInt32(max(0.0, self.g) * 255.0) << 8) | (UInt32(max(0.0, self.b) * 255.0))
    }
}
    
private struct NodeFlags: OptionSet {
    var rawValue: UInt8
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static let masksToBounds = NodeFlags(rawValue: 1 << 0)
    static let isHidden = NodeFlags(rawValue: 1 << 1)
    static let hasSimpleContents = NodeFlags(rawValue: 1 << 2)
    static let isInvertedMatte = NodeFlags(rawValue: 1 << 3)
    
    static let hasRenderContent = NodeFlags(rawValue: 1 << 4)
    static let hasSubnodes = NodeFlags(rawValue: 1 << 5)
    static let hasMask = NodeFlags(rawValue: 1 << 6)
}
    
private struct LottieContentFlags: OptionSet {
    var rawValue: UInt8
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static let hasStroke = LottieContentFlags(rawValue: 1 << 0)
    static let hasFill = LottieContentFlags(rawValue: 1 << 1)
}
    
func serializePath(buffer: WriteBuffer, path: LottiePath) {
    let lengthOffset = buffer.length
    buffer.write(uInt32: 0)
        
    path.enumerateItems { pathItem in
        switch pathItem.pointee.type {
        case .moveTo:
            let point = pathItem.pointee.points.0
            buffer.write(uInt8: 0)
            buffer.write(point: point)
        case .lineTo:
            let point = pathItem.pointee.points.0
            buffer.write(uInt8: 1)
            buffer.write(point: point)
        case .curveTo:
            let cp1 = pathItem.pointee.points.0
            let cp2 = pathItem.pointee.points.1
            let point = pathItem.pointee.points.2
            
            buffer.write(uInt8: 2)
            buffer.write(point: cp1)
            buffer.write(point: cp2)
            buffer.write(point: point)
        case .close:
            buffer.write(uInt8: 3)
        @unknown default:
            break
        }
    }
    
    let dataLength = buffer.length - lengthOffset - 4
    
    let previousLength = buffer.length
    buffer.length = lengthOffset
    buffer.write(uInt32: UInt32(dataLength))
    buffer.length = previousLength
}
    
func deserializePath(buffer: ReadBuffer) -> LottiePath {
    let itemDataLength = Int(buffer.readUInt32())
    var itemData = Data(count: itemDataLength)
    itemData.withUnsafeMutableBytes { bytes in
        buffer.read(bytes: bytes)
    }
    
    return LottiePath(customData: itemData)
}
    
func serializeContentShading(buffer: WriteBuffer, shading: LottieRenderContentShading) {
    if let shading = shading as? LottieRenderContentSolidShading {
        buffer.write(uInt8: 0)
        buffer.write(uInt32: shading.color.argb)
        buffer.write(uInt8: UInt8(clamping: Int(shading.opacity * 255.0)))
    } else if let shading = shading as? LottieRenderContentGradientShading {
        buffer.write(uInt8: 1)
        buffer.write(uInt8: UInt8(clamping: Int(shading.opacity * 255.0)))
        buffer.write(uInt8: UInt8(shading.gradientType.rawValue))
        let colorStopCount = min(shading.colorStops.count, 255)
        buffer.write(uInt8: UInt8(colorStopCount))
        for i in 0 ..< colorStopCount {
            buffer.write(uInt32: shading.colorStops[i].color.argb)
            buffer.write(float: Float(shading.colorStops[i].location))
        }
        buffer.write(point: shading.start)
        buffer.write(point: shading.end)
    } else {
        buffer.write(uInt8: 0)
        buffer.write(uInt8: UInt8(clamping: Int(1.0 * 255.0)))
    }
}
    
func deserializeContentShading(buffer: ReadBuffer) -> LottieRenderContentShading {
    switch buffer.readUInt8() {
    case 0:
        return LottieRenderContentSolidShading(
            color: LottieColor(argb: buffer.readUInt32()),
            opacity: CGFloat(buffer.readUInt8()) / 255.0
        )
    case 1:
        let opacity = CGFloat(buffer.readUInt8()) / 255.0
        let gradientType = LottieGradientType(rawValue: UInt(buffer.readUInt8()))!
        
        var colorStops: [LottieColorStop] = []
        let colorStopCount = Int(buffer.readUInt8())
        for _ in 0 ..< colorStopCount {
            colorStops.append(LottieColorStop(
                color: LottieColor(argb: buffer.readUInt32()),
                location: CGFloat(buffer.readFloat())
            ))
        }
        
        let start = buffer.readPoint()
        let end = buffer.readPoint()
        
        return LottieRenderContentGradientShading(
            opacity: opacity,
            gradientType: gradientType,
            colorStops: colorStops,
            start: start,
            end: end
        )
    default:
        preconditionFailure()
    }
}
    
func serializeStroke(buffer: WriteBuffer, stroke: LottieRenderContentStroke) {
    serializeContentShading(buffer: buffer, shading: stroke.shading)
    buffer.write(float: Float(stroke.lineWidth))
    buffer.write(uInt8: UInt8(stroke.lineJoin.rawValue))
    buffer.write(uInt8: UInt8(stroke.lineCap.rawValue))
    buffer.write(float: Float(stroke.miterLimit))
}
    
func deserializeStroke(buffer: ReadBuffer) -> LottieRenderContentStroke {
    return LottieRenderContentStroke(
        shading: deserializeContentShading(buffer: buffer),
        lineWidth: CGFloat(buffer.readFloat()),
        lineJoin: CGLineJoin(rawValue: Int32(buffer.readUInt8()))!,
        lineCap: CGLineCap(rawValue: Int32(buffer.readUInt8()))!,
        miterLimit: CGFloat(buffer.readFloat()),
        dashPhase: 0.0,
        dashPattern: nil
    )
}
    
func serializeFill(buffer: WriteBuffer, fill: LottieRenderContentFill) {
    serializeContentShading(buffer: buffer, shading: fill.shading)
    buffer.write(uInt8: UInt8(fill.fillRule.rawValue))
}
    
func deserializeFill(buffer: ReadBuffer) -> LottieRenderContentFill {
    return LottieRenderContentFill(
        shading: deserializeContentShading(buffer: buffer),
        fillRule: LottieFillRule(rawValue: UInt(buffer.readUInt8()))!
    )
}
    
func serializeRenderContent(buffer: WriteBuffer, renderContent: LottieRenderContent) {
    var flags: LottieContentFlags = []
    if renderContent.stroke != nil {
        flags.insert(.hasStroke)
    }
    if renderContent.fill != nil {
        flags.insert(.hasFill)
    }
    buffer.write(uInt8: flags.rawValue)
    
    serializePath(buffer: buffer, path: renderContent.path)
    if let stroke = renderContent.stroke {
        serializeStroke(buffer: buffer, stroke: stroke)
    }
    if let fill = renderContent.fill {
        serializeFill(buffer: buffer, fill: fill)
    }
}
    
func deserializeRenderContent(buffer: ReadBuffer) -> LottieRenderContent {
    let flags = LottieContentFlags(rawValue: buffer.readUInt8())
    
    let path = deserializePath(buffer: buffer)
    
    var stroke: LottieRenderContentStroke?
    if flags.contains(.hasStroke) {
        stroke = deserializeStroke(buffer: buffer)
    }
    
    var fill: LottieRenderContentFill?
    if flags.contains(.hasFill) {
        fill = deserializeFill(buffer: buffer)
    }
    
    return LottieRenderContent(
        path: path,
        stroke: stroke,
        fill: fill
    )
}

func serializeNode(buffer: WriteBuffer, node: LottieRenderNode) {
    var flags: NodeFlags = []
    if node.masksToBounds {
        flags.insert(.masksToBounds)
    }
    if node.isHidden {
        flags.insert(.isHidden)
    }
    if node.hasSimpleContents {
        flags.insert(.hasSimpleContents)
    }
    if node.isInvertedMatte {
        flags.insert(.isInvertedMatte)
    }
    if node.renderContent != nil {
        flags.insert(.hasRenderContent)
    }
    if !node.subnodes.isEmpty {
        flags.insert(.hasSubnodes)
    }
    if node.mask != nil {
        flags.insert(.hasMask)
    }
    
    buffer.write(uInt8: flags.rawValue)
    
    buffer.write(point: node.position)
    buffer.write(rect: node.bounds)
    buffer.write(transform: node.transform)
    buffer.write(uInt8: UInt8(clamping: Int(node.opacity * 255.0)))
    buffer.write(rect: node.globalRect)
    buffer.write(transform: node.globalTransform)
    
    if let renderContent = node.renderContent {
        serializeRenderContent(buffer: buffer, renderContent: renderContent)
    }
    if !node.subnodes.isEmpty {
        let count = min(node.subnodes.count, 4095)
        buffer.write(uInt16: UInt16(count))
        for i in 0 ..< count {
            serializeNode(buffer: buffer, node: node.subnodes[i])
        }
    }
    if let mask = node.mask {
        serializeNode(buffer: buffer, node: mask)
    }
}
    
func deserializeNode(buffer: ReadBuffer) -> LottieRenderNode {
    let flags = NodeFlags(rawValue: buffer.readUInt8())
    
    let position = buffer.readPoint()
    let bounds = buffer.readRect()
    let transform = buffer.readTransform()
    let opacity = CGFloat(buffer.readUInt8()) / 255.0
    let globalRect = buffer.readRect()
    let globalTransform = buffer.readTransform()
    
    var renderContent: LottieRenderContent?
    if flags.contains(.hasRenderContent) {
        renderContent = deserializeRenderContent(buffer: buffer)
    }
    var subnodes: [LottieRenderNode] = []
    if flags.contains(.hasSubnodes) {
        let count = Int(buffer.readUInt16())
        for _ in 0 ..< count {
            subnodes.append(deserializeNode(buffer: buffer))
        }
    }
    var mask: LottieRenderNode?
    if flags.contains(.hasMask) {
        mask = deserializeNode(buffer: buffer)
    }
    
    return LottieRenderNode(
        position: position,
        bounds: bounds,
        transform: transform,
        opacity: opacity,
        masksToBounds: flags.contains(.masksToBounds),
        isHidden: flags.contains(.isHidden),
        globalRect: globalRect,
        globalTransform: globalTransform,
        renderContent: renderContent,
        hasSimpleContents: flags.contains(.hasSimpleContents),
        isInvertedMatte: flags.contains(.isInvertedMatte),
        subnodes: subnodes,
        mask: mask
    )
}

public struct SerializedLottieMetalFrameMapping {
    var size: CGSize = CGSize()
    var frameCount: Int = 0
    var framesPerSecond: Int = 0
    var frameRanges: [Int: Range<Int>] = [:]
}

func serializeFrameMapping(buffer: WriteBuffer, frameMapping: SerializedLottieMetalFrameMapping) {
    buffer.write(size: frameMapping.size)
    buffer.write(uInt32: UInt32(frameMapping.frameCount))
    buffer.write(uInt32: UInt32(frameMapping.framesPerSecond))
    for (frame, range) in frameMapping.frameRanges.sorted(by: { $0.key < $1.key }) {
        buffer.write(uInt32: UInt32(frame))
        buffer.write(uInt32: UInt32(range.lowerBound))
        buffer.write(uInt32: UInt32(range.upperBound))
    }
}

func deserializeFrameMapping(buffer: ReadBuffer) -> SerializedLottieMetalFrameMapping {
    var frameMapping = SerializedLottieMetalFrameMapping()
    
    frameMapping.size = buffer.readSize()
    frameMapping.frameCount = Int(buffer.readUInt32())
    frameMapping.framesPerSecond = Int(buffer.readUInt32())
    for _ in 0 ..< frameMapping.frameCount {
        let frame = Int(buffer.readUInt32())
        let lowerBound = Int(buffer.readUInt32())
        let upperBound = Int(buffer.readUInt32())
        frameMapping.frameRanges[frame] = lowerBound ..< upperBound
    }
    
    return frameMapping
}
