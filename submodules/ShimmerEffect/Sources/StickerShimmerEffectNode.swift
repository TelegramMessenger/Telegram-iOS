import Foundation
import AsyncDisplayKit
import Display

private let decodingMap: [String] = ["A", "A", "C", "A", "A", "A", "A", "H", "A", "A", "A", "L", "M", "A", "A", "A", "Q", "A", "S", "T", "A", "V", "A", "A", "A", "Z", "a", "a", "c", "a", "a", "a", "a", "h", "a", "a", "a", "l", "m", "a", "a", "a", "q", "a", "s", "t", "a", "v", "a", ".", "a", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", ","]
private func decodeStickerThumbnailData(_ data: Data) -> String {
    var string = "M"
    data.forEach { byte in
        if byte >= 128 + 64 {
            string.append(decodingMap[Int(byte) - 128 - 64])
        } else {
            if byte >= 128 {
                string.append(",")
            } else if byte >= 64 {
                string.append("-")
            }
            string.append("\(byte & 63)")
        }
    }
    string.append("z")
    return string
}

public func generateStickerPlaceholderImage(data: Data?, size: CGSize, imageSize: CGSize, backgroundColor: UIColor?, foregroundColor: UIColor) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.setBlendMode(.copy)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.clear.cgColor)
        } else {
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(foregroundColor.cgColor)
        }
        
        if let data = data {
            var path = decodeStickerThumbnailData(data)
            if !path.hasSuffix("z") {
                path = "\(path)z"
            }
            let reader = PathDataReader(input: path)
            let segments = reader.read()

            let scale = max(size.width, size.height) / max(imageSize.width, imageSize.height)
            context.scaleBy(x: scale, y: scale)
            renderPath(segments, context: context)
        } else {
            let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight], cornerRadii: CGSize(width: 10.0, height: 10.0))
            UIGraphicsPushContext(context)
            path.fill()
            UIGraphicsPopContext()
        }
    })
}

public class StickerShimmerEffectNode: ASDisplayNode {
    private var backdropNode: ASDisplayNode?
    private let backgroundNode: ASDisplayNode
    private let effectNode: ShimmerEffectForegroundNode
    private let foregroundNode: ASImageNode
    
    private var maskView: UIImageView?
    
    private var currentData: Data?
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private var currentShimmeringColor: UIColor?
    private var currentSize = CGSize()
    
    public override init() {
        self.backgroundNode = ASDisplayNode()
        self.effectNode = ShimmerEffectForegroundNode()
        self.foregroundNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.foregroundNode)
    }
        
    public var isEmpty: Bool {
        return self.currentData == nil
    }
    
    public func addBackdropNode(_ backdropNode: ASDisplayNode) {
        if let current = self.backdropNode {
            current.removeFromSupernode()
        }
        self.backdropNode = backdropNode
        self.insertSubnode(backdropNode, at: 0)
        
        self.effectNode.layer.compositingFilter = "screenBlendMode"
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectNode.updateAbsoluteRect(rect, within: containerSize)
    }
    
    public func update(backgroundColor: UIColor?, foregroundColor: UIColor, shimmeringColor: UIColor, data: Data?, size: CGSize, imageSize: CGSize = CGSize(width: 512.0, height: 512.0)) {
        if data == nil {
            return
        }
        if self.currentData == data, let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor), self.currentSize == size {
            return
        }
        
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentShimmeringColor = shimmeringColor
        self.currentData = data
        self.currentSize = size
        
        self.backgroundNode.backgroundColor = foregroundColor
        
        self.effectNode.update(backgroundColor: backgroundColor == nil ? .clear : foregroundColor, foregroundColor: shimmeringColor, horizontal: true, effectSize: nil, globalTimeOffset: true, duration: nil)
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        let image = generateStickerPlaceholderImage(data: data, size: size, imageSize: imageSize, backgroundColor: backgroundColor, foregroundColor: .black)
                        
        if backgroundColor == nil {
            self.foregroundNode.image = nil
            
            let maskView: UIImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = UIImageView()
                maskView.frame = bounds
                self.maskView = maskView
                self.view.mask = maskView
            }
            
        } else {
            self.foregroundNode.image = image
            
            if let _ = self.maskView {
                self.view.mask = nil
                self.maskView = nil
            }
        }
        
        self.maskView?.image = image
        
        self.backdropNode?.frame = bounds
        self.backgroundNode.frame = bounds
        self.foregroundNode.frame = bounds
        self.effectNode.frame = bounds
    }
}

open class PathSegment: Equatable {
    public enum SegmentType {
        case M
        case L
        case C
        case Q
        case A
        case z
        case H
        case V
        case S
        case T
        case m
        case l
        case c
        case q
        case a
        case h
        case v
        case s
        case t
        case E
        case e
    }
    
    public let type: SegmentType
    public let data: [Double]

    public init(type: PathSegment.SegmentType = .M, data: [Double] = []) {
        self.type = type
        self.data = data
    }

    open func isAbsolute() -> Bool {
        switch type {
        case .M, .L, .H, .V, .C, .S, .Q, .T, .A, .E:
            return true
        default:
            return false
        }
    }

    public static func == (lhs: PathSegment, rhs: PathSegment) -> Bool {
        return lhs.type == rhs.type && lhs.data == rhs.data
    }
}

private func renderPath(_ segments: [PathSegment], context: CGContext) {
    var currentPoint: CGPoint?
    var cubicPoint: CGPoint?
    var quadrPoint: CGPoint?
    var initialPoint: CGPoint?
    
    func M(_ x: Double, y: Double) {
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        context.move(to: point)
        setInitPoint(point)
    }
    
    func m(_ x: Double, y: Double) {
        if let cur = currentPoint {
            let next = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            context.move(to: next)
            setInitPoint(next)
        } else {
            M(x, y: y)
        }
    }
    
    func L(_ x: Double, y: Double) {
        lineTo(CGPoint(x: CGFloat(x), y: CGFloat(y)))
    }
    
    func l(_ x: Double, y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y))
        } else {
            L(x, y: y)
        }
    }
    
    func H(_ x: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x), y: CGFloat(cur.y)))
        }
    }
    
    func h(_ x: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(cur.y)))
        }
    }
    
    func V(_ y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(cur.x), y: CGFloat(y)))
        }
    }
    
    func v(_ y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(cur.x), y: CGFloat(y) + cur.y))
        }
    }

    func lineTo(_ p: CGPoint) {
        context.addLine(to: p)
        setPoint(p)
    }
    
    func c(_ x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let endPoint = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            let controlPoint1 = CGPoint(x: CGFloat(x1) + cur.x, y: CGFloat(y1) + cur.y)
            let controlPoint2 = CGPoint(x: CGFloat(x2) + cur.x, y: CGFloat(y2) + cur.y)
            context.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
            setCubicPoint(endPoint, cubic: controlPoint2)
        }
    }
    
    func C(_ x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
        let endPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let controlPoint1 = CGPoint(x: CGFloat(x1), y: CGFloat(y1))
        let controlPoint2 = CGPoint(x: CGFloat(x2), y: CGFloat(y2))
        context.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        setCubicPoint(endPoint, cubic: controlPoint2)
    }
    
    func s(_ x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let nextCubic = CGPoint(x: CGFloat(x2) + cur.x, y: CGFloat(y2) + cur.y)
            let next = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            
            let xy1: CGPoint
            if let curCubicVal = cubicPoint {
                xy1 = CGPoint(x: CGFloat(2 * cur.x) - curCubicVal.x, y: CGFloat(2 * cur.y) - curCubicVal.y)
            } else {
                xy1 = cur
            }
            context.addCurve(to: next, control1: xy1, control2: nextCubic)
            setCubicPoint(next, cubic: nextCubic)
        }
    }
    
    func S(_ x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let nextCubic = CGPoint(x: CGFloat(x2), y: CGFloat(y2))
            let next = CGPoint(x: CGFloat(x), y: CGFloat(y))
            let xy1: CGPoint
            if let curCubicVal = cubicPoint {
                xy1 = CGPoint(x: CGFloat(2 * cur.x) - curCubicVal.x, y: CGFloat(2 * cur.y) - curCubicVal.y)
            } else {
                xy1 = cur
            }
            context.addCurve(to: next, control1: xy1, control2: nextCubic)
            setCubicPoint(next, cubic: nextCubic)
        }
    }
    
    func z() {
        context.fillPath()
    }
    
    func setQuadrPoint(_ p: CGPoint, quadr: CGPoint) {
        currentPoint = p
        quadrPoint = quadr
        cubicPoint = nil
    }

    func setCubicPoint(_ p: CGPoint, cubic: CGPoint) {
        currentPoint = p
        cubicPoint = cubic
        quadrPoint = nil
    }

    func setInitPoint(_ p: CGPoint) {
        setPoint(p)
        initialPoint = p
    }

    func setPoint(_ p: CGPoint) {
        currentPoint = p
        cubicPoint = nil
        quadrPoint = nil
    }

    let _ = initialPoint
    let _ = quadrPoint
    
    for segment in segments {
        var data = segment.data
        switch segment.type {
            case .M:
                M(data[0], y: data[1])
                data.removeSubrange(Range(uncheckedBounds: (lower: 0, upper: 2)))
                while data.count >= 2 {
                    L(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .m:
                m(data[0], y: data[1])
                data.removeSubrange((0 ..< 2))
                while data.count >= 2 {
                    l(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .L:
                while data.count >= 2 {
                    L(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .l:
                while data.count >= 2 {
                    l(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .H:
                H(data[0])
            case .h:
                h(data[0])
            case .V:
                V(data[0])
            case .v:
                v(data[0])
            case .C:
                while data.count >= 6 {
                    C(data[0], y1: data[1], x2: data[2], y2: data[3], x: data[4], y: data[5])
                    data.removeSubrange((0 ..< 6))
                }
            case .c:
                while data.count >= 6 {
                    c(data[0], y1: data[1], x2: data[2], y2: data[3], x: data[4], y: data[5])
                    data.removeSubrange((0 ..< 6))
                }
            case .S:
                while data.count >= 4 {
                    S(data[0], y2: data[1], x: data[2], y: data[3])
                    data.removeSubrange((0 ..< 4))
                }
            case .s:
                while data.count >= 4 {
                    s(data[0], y2: data[1], x: data[2], y: data[3])
                    data.removeSubrange((0 ..< 4))
                }
            case .z:
                z()
            default:
                print("unknown")
                break
        }
    }
}

private class PathDataReader {
    private let input: String
    private var current: UnicodeScalar?
    private var previous: UnicodeScalar?
    private var iterator: String.UnicodeScalarView.Iterator

    private static let spaces: Set<UnicodeScalar> = Set("\n\r\t ,".unicodeScalars)

    init(input: String) {
        self.input = input
        self.iterator = input.unicodeScalars.makeIterator()
    }

    public func read() -> [PathSegment] {
        readNext()
        var segments = [PathSegment]()
        while let array = readSegments() {
            segments.append(contentsOf: array)
        }
        return segments
    }

    private func readSegments() -> [PathSegment]? {
        if let type = readSegmentType() {
            let argCount = getArgCount(segment: type)
            if argCount == 0 {
                return [PathSegment(type: type)]
            }
            var result = [PathSegment]()
            let data: [Double]
            if type == .a || type == .A {
                data = readDataOfASegment()
            } else {
                data = readData()
            }
            var index = 0
            var isFirstSegment = true
            while index < data.count {
                let end = index + argCount
                if end > data.count {
                    break
                }
                var currentType = type
                if type == .M && !isFirstSegment {
                    currentType = .L
                }
                if type == .m && !isFirstSegment {
                    currentType = .l
                }
                result.append(PathSegment(type: currentType, data: Array(data[index..<end])))
                isFirstSegment = false
                index = end
            }
            return result
        }
        return nil
    }

    private func readData() -> [Double] {
        var data = [Double]()
        while true {
            skipSpaces()
            if let value = readNum() {
                data.append(value)
            } else {
                return data
            }
        }
    }

    private func readDataOfASegment() -> [Double] {
        let argCount = getArgCount(segment: .A)
        var data: [Double] = []
        var index = 0
        while true {
            skipSpaces()
            let value: Double?
            let indexMod = index % argCount
            if indexMod == 3 || indexMod == 4 {
                value = readFlag()
            } else {
                value = readNum()
            }
            guard let doubleValue = value else {
                return data
            }
            data.append(doubleValue)
            index += 1
        }
        return data
    }

    private func skipSpaces() {
        var currentCharacter = current
        while let character = currentCharacter, Self.spaces.contains(character) {
            currentCharacter = readNext()
        }
    }

    private func readFlag() -> Double? {
        guard let ch = current else {
            return .none
        }
        readNext()
        switch ch {
        case "0":
            return 0
        case "1":
            return 1
        default:
            return .none
        }
    }

    fileprivate func readNum() -> Double? {
        guard let ch = current else {
            return .none
        }

        guard ch >= "0" && ch <= "9" || ch == "." || ch == "-" else {
            return .none
        }

        var chars = [ch]
        var hasDot = ch == "."
        while let ch = readDigit(&hasDot) {
            chars.append(ch)
        }

        var buf = ""
        buf.unicodeScalars.append(contentsOf: chars)
        guard let value = Double(buf) else {
            return .none
        }
        return value
    }

    fileprivate func readDigit(_ hasDot: inout Bool) -> UnicodeScalar? {
        if let ch = readNext() {
            if (ch >= "0" && ch <= "9") || ch == "e" || (previous == "e" && ch == "-") {
                return ch
            } else if ch == "." && !hasDot {
                hasDot = true
                return ch
            }
        }
        return nil
    }

    fileprivate func isNum(ch: UnicodeScalar, hasDot: inout Bool) -> Bool {
        switch ch {
        case "0"..."9":
            return true
        case ".":
            if hasDot {
                return false
            }
            hasDot = true
        default:
            return true
        }
        return false
    }

    @discardableResult
    private func readNext() -> UnicodeScalar? {
        previous = current
        current = iterator.next()
        return current
    }

    private func isAcceptableSeparator(_ ch: UnicodeScalar?) -> Bool {
        if let ch = ch {
            return "\n\r\t ,".contains(String(ch))
        }
        return false
    }

    private func readSegmentType() -> PathSegment.SegmentType? {
        while true {
            if let type = getPathSegmentType() {
                readNext()
                return type
            }
            if readNext() == nil {
                return nil
            }
        }
    }

    fileprivate func getPathSegmentType() -> PathSegment.SegmentType? {
        if let ch = current {
            switch ch {
            case "M":
                return .M
            case "m":
                return .m
            case "L":
                return .L
            case "l":
                return .l
            case "C":
                return .C
            case "c":
                return .c
            case "Q":
                return .Q
            case "q":
                return .q
            case "A":
                return .A
            case "a":
                return .a
            case "z", "Z":
                return .z
            case "H":
                return .H
            case "h":
                return .h
            case "V":
                return .V
            case "v":
                return .v
            case "S":
                return .S
            case "s":
                return .s
            case "T":
                return .T
            case "t":
                return .t
            default:
                break
            }
        }
        return nil
    }

    fileprivate func getArgCount(segment: PathSegment.SegmentType) -> Int {
        switch segment {
        case .H, .h, .V, .v:
            return 1
        case .M, .m, .L, .l, .T, .t:
            return 2
        case .S, .s, .Q, .q:
            return 4
        case .C, .c:
            return 6
        case .A, .a:
            return 7
        default:
            return 0
        }
    }
}
