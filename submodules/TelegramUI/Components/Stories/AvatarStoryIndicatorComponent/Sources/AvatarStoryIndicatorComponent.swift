import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer
import TelegramPresentationData

private extension CGFloat {
    func remap(fromLow: CGFloat, fromHigh: CGFloat, toLow: CGFloat, toHigh: CGFloat) -> CGFloat {
        guard (fromHigh - fromLow) != 0 else {
            // Would produce NAN
            return 0
        }
        return toLow + (self - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
    }
}

private extension CGPoint {
    /// Returns the length between the receiver and *CGPoint.zero*
    var vectorLength: CGFloat {
        distanceTo(.zero)
    }
    
    var isZero: Bool {
        x == 0 && y == 0
    }
    
    /// Operator convenience to divide points with /
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / CGFloat(rhs), y: lhs.y / CGFloat(rhs))
    }
    
    /// Operator convenience to multiply points with *
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * CGFloat(rhs), y: lhs.y * CGFloat(rhs))
    }
    
    /// Operator convenience to add points with +
    static func +(left: CGPoint, right: CGPoint) -> CGPoint {
        left.add(right)
    }
    
    /// Operator convenience to subtract points with -
    static func -(left: CGPoint, right: CGPoint) -> CGPoint {
        left.subtract(right)
    }
    
    /// Returns the distance between the receiver and the given point.
    func distanceTo(_ a: CGPoint) -> CGFloat {
        let xDist = a.x - x
        let yDist = a.y - y
        return CGFloat(sqrt((xDist * xDist) + (yDist * yDist)))
    }
    
    func rounded(decimal: CGFloat) -> CGPoint {
        CGPoint(x: round(decimal * x) / decimal, y: round(decimal * y) / decimal)
    }
    
    func interpolate(to: CGPoint, amount: CGFloat) -> CGPoint {
        return self + ((to - self) * amount)
    }
    
    func interpolate(
        _ to: CGPoint,
        outTangent: CGPoint,
        inTangent: CGPoint,
        amount: CGFloat,
        maxIterations: Int = 3,
        samples: Int = 20,
        accuracy: CGFloat = 1)
    -> CGPoint
    {
        if amount == 0 {
            return self
        }
        if amount == 1 {
            return to
        }
        
        if
            colinear(outTangent, inTangent) == true,
            outTangent.colinear(inTangent, to) == true
        {
            return interpolate(to: to, amount: amount)
        }
        
        let step = 1 / CGFloat(samples)
        
        var points: [(point: CGPoint, distance: CGFloat)] = [(point: self, distance: 0)]
        var totalLength: CGFloat = 0
        
        var previousPoint = self
        var previousAmount = CGFloat(0)
        
        var closestPoint = 0
        
        while previousAmount < 1 {
            
            previousAmount = previousAmount + step
            
            if previousAmount < amount {
                closestPoint = closestPoint + 1
            }
            
            let newPoint = pointOnPath(to, outTangent: outTangent, inTangent: inTangent, amount: previousAmount)
            let distance = previousPoint.distanceTo(newPoint)
            totalLength = totalLength + distance
            points.append((point: newPoint, distance: totalLength))
            previousPoint = newPoint
        }
        
        let accurateDistance = amount * totalLength
        var point = points[closestPoint]
        
        var foundPoint = false
        
        var pointAmount = CGFloat(closestPoint) * step
        var nextPointAmount: CGFloat = pointAmount + step
        
        var refineIterations = 0
        while foundPoint == false {
            refineIterations = refineIterations + 1
            /// First see if the next point is still less than the projected length.
            let nextPoint = points[min(closestPoint + 1, points.indices.last!)]
            if nextPoint.distance < accurateDistance {
                point = nextPoint
                closestPoint = closestPoint + 1
                pointAmount = CGFloat(closestPoint) * step
                nextPointAmount = pointAmount + step
                if closestPoint == points.count {
                    foundPoint = true
                }
                continue
            }
            if accurateDistance < point.distance {
                closestPoint = closestPoint - 1
                if closestPoint < 0 {
                    foundPoint = true
                    continue
                }
                point = points[closestPoint]
                pointAmount = CGFloat(closestPoint) * step
                nextPointAmount = pointAmount + step
                continue
            }
            
            /// Now we are certain the point is the closest point under the distance
            let pointDiff = nextPoint.distance - point.distance
            let proposedPointAmount = ((accurateDistance - point.distance) / pointDiff)
                .remap(fromLow: 0, fromHigh: 1, toLow: pointAmount, toHigh: nextPointAmount)
            
            let newPoint = pointOnPath(to, outTangent: outTangent, inTangent: inTangent, amount: proposedPointAmount)
            let newDistance = point.distance + point.point.distanceTo(newPoint)
            pointAmount = proposedPointAmount
            point = (point: newPoint, distance: newDistance)
            if
                accurateDistance - newDistance <= accuracy ||
                    newDistance - accurateDistance <= accuracy
            {
                foundPoint = true
            }
            
            if refineIterations == maxIterations {
                foundPoint = true
            }
        }
        return point.point
    }
    
    func pointOnPath(_ to: CGPoint, outTangent: CGPoint, inTangent: CGPoint, amount: CGFloat) -> CGPoint {
        let a = interpolate(to: outTangent, amount: amount)
        let b = outTangent.interpolate(to: inTangent, amount: amount)
        let c = inTangent.interpolate(to: to, amount: amount)
        let d = a.interpolate(to: b, amount: amount)
        let e = b.interpolate(to: c, amount: amount)
        let f = d.interpolate(to: e, amount: amount)
        return f
    }
    
    func colinear(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let area = x * (a.y - b.y) + a.x * (b.y - y) + b.x * (y - a.y);
        let accuracy: CGFloat = 0.05
        if area < accuracy && area > -accuracy {
            return true
        }
        return false
    }
    
    /// Subtracts the given point from the receiving point.
    func subtract(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: x - point.x,
            y: y - point.y)
    }
    
    /// Adds the given point from the receiving point.
    func add(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: x + point.x,
            y: y + point.y)
    }
}

private extension CurveVertex {
    func interpolate(to: CurveVertex, amount: CGFloat) -> CurveVertex {
        CurveVertex(
            point: point.interpolate(to: to.point, amount: amount),
            inTangent: inTangent.interpolate(to: to.inTangent, amount: amount),
            outTangent: outTangent.interpolate(to: to.outTangent, amount: amount))
    }
}

private struct CurveVertex {
    init(_ inTangent: CGPoint, _ point: CGPoint, _ outTangent: CGPoint) {
        self.point = point
        self.inTangent = inTangent
        self.outTangent = outTangent
    }
    
    init(point: CGPoint, inTangentRelative: CGPoint, outTangentRelative: CGPoint) {
        self.point = point
        inTangent = CGPoint(x: point.x + inTangentRelative.x, y: point.y + inTangentRelative.y)
        outTangent = CGPoint(x: point.x + outTangentRelative.x, y: point.y + outTangentRelative.y)
    }
    
    init(point: CGPoint, inTangent: CGPoint, outTangent: CGPoint) {
        self.point = point
        self.inTangent = inTangent
        self.outTangent = outTangent
    }
    
    // MARK: Internal
    
    let point: CGPoint
    
    var inTangent: CGPoint
    var outTangent: CGPoint
    
    var inTangentRelative: CGPoint {
        return CGPoint(x: inTangent.x - point.x, y: inTangent.y - point.y)
    }
    
    var outTangentRelative: CGPoint {
        return CGPoint(x: outTangent.x - point.x, y: outTangent.y - point.y)
    }
    
    func reversed() -> CurveVertex {
        return CurveVertex(point: point, inTangent: outTangent, outTangent: inTangent)
    }
    
    func translated(_ translation: CGPoint) -> CurveVertex {
        return CurveVertex(point: CGPoint(x: point.x + translation.x, y: point.y + translation.y), inTangent: CGPoint(x: inTangent.x + translation.x, y: inTangent.y + translation.y), outTangent: CGPoint(x: outTangent.x + translation.x, y: outTangent.y + translation.y))
    }
    
    /// Trims a path defined by two Vertices at a specific position, from 0 to 1
    ///
    /// The path can be visualized below.
    ///
    /// F is fromVertex.
    /// V is the vertex of the receiver.
    /// P is the position from 0-1.
    /// O is the outTangent of fromVertex.
    /// F====O=========P=======I====V
    ///
    /// After trimming the curve can be visualized below.
    ///
    /// S is the returned Start vertex.
    /// E is the returned End vertex.
    /// T is the trim point.
    /// TI and TO are the new tangents for the trimPoint
    /// NO and NI are the new tangents for the startPoint and endPoints
    /// S==NO=========TI==T==TO=======NI==E
    func splitCurve(toVertex: CurveVertex, position: CGFloat) ->
    (start: CurveVertex, trimPoint: CurveVertex, end: CurveVertex)
    {
        
        /// If position is less than or equal to 0, trim at start.
        if position <= 0 {
            return (
                start: CurveVertex(point: point, inTangentRelative: inTangentRelative, outTangentRelative: .zero),
                trimPoint: CurveVertex(point: point, inTangentRelative: .zero, outTangentRelative: outTangentRelative),
                end: toVertex)
        }
        
        /// If position is greater than or equal to 1, trim at end.
        if position >= 1 {
            return (
                start: self,
                trimPoint: CurveVertex(
                    point: toVertex.point,
                    inTangentRelative: toVertex.inTangentRelative,
                    outTangentRelative: .zero),
                end: CurveVertex(
                    point: toVertex.point,
                    inTangentRelative: .zero,
                    outTangentRelative: toVertex.outTangentRelative))
        }
        
        if outTangentRelative == CGPoint() && toVertex.inTangentRelative == CGPoint() {
            /// If both tangents are zero, then span to be trimmed is a straight line.
            let trimPoint = point.interpolate(to: toVertex.point, amount: position)
            return (
                start: self,
                trimPoint: CurveVertex(point: trimPoint, inTangentRelative: .zero, outTangentRelative: .zero),
                end: toVertex)
        }
        /// Cutting by amount gives incorrect length....
        /// One option is to cut by a stride until it gets close then edge it down.
        /// Measuring a percentage of the spans does not equal the same as measuring a percentage of length.
        /// This is where the historical trim path bugs come from.
        let a = point.interpolate(to: outTangent, amount: position)
        let b = outTangent.interpolate(to: toVertex.inTangent, amount: position)
        let c = toVertex.inTangent.interpolate(to: toVertex.point, amount: position)
        let d = a.interpolate(to: b, amount: position)
        let e = b.interpolate(to: c, amount: position)
        let f = d.interpolate(to: e, amount: position)
        return (
            start: CurveVertex(point: point, inTangent: inTangent, outTangent: a),
            trimPoint: CurveVertex(point: f, inTangent: d, outTangent: e),
            end: CurveVertex(point: toVertex.point, inTangent: c, outTangent: toVertex.outTangent))
    }
    
    /// Trims a curve of a known length to a specific length and returns the points.
    ///
    /// There is not a performant yet accurate way to cut a curve to a specific length.
    /// This calls splitCurve(toVertex: position:) to split the curve and then measures
    /// the length of the new curve. The function then iterates through the samples,
    /// adjusting the position of the cut for a more precise cut.
    /// Usually a single iteration is enough to get within 0.5 points of the desired
    /// length.
    ///
    /// This function should probably live in PathElement, since it deals with curve
    /// lengths.
    func trimCurve(toVertex: CurveVertex, atLength: CGFloat, curveLength: CGFloat, maxSamples: Int, accuracy: CGFloat = 1) ->
    (start: CurveVertex, trimPoint: CurveVertex, end: CurveVertex)
    {
        var currentPosition = atLength / curveLength
        var results = splitCurve(toVertex: toVertex, position: currentPosition)
        
        if maxSamples == 0 {
            return results
        }
        
        for _ in 1...maxSamples {
            let length = results.start.distanceTo(results.trimPoint)
            let lengthDiff = atLength - length
            /// Check if length is correct.
            if lengthDiff < accuracy {
                return results
            }
            let diffPosition = max(min((currentPosition / length) * lengthDiff, currentPosition * 0.5), currentPosition * -0.5)
            currentPosition = diffPosition + currentPosition
            results = splitCurve(toVertex: toVertex, position: currentPosition)
        }
        return results
    }
    
    /// The distance from the receiver to the provided vertex.
    ///
    /// For lines (zeroed tangents) the distance between the two points is measured.
    /// For curves the curve is iterated over by sample count and the points are measured.
    /// This is ~99% accurate at a sample count of 30
    func distanceTo(_ toVertex: CurveVertex, sampleCount: Int = 25) -> CGFloat {
        
        if outTangentRelative.isZero && toVertex.inTangentRelative.isZero {
            /// Return a linear distance.
            return point.distanceTo(toVertex.point)
        }
        
        var distance: CGFloat = 0
        
        var previousPoint = point
        for i in 0..<sampleCount {
            let pointOnCurve = splitCurve(toVertex: toVertex, position: CGFloat(i) / CGFloat(sampleCount)).trimPoint
            distance = distance + previousPoint.distanceTo(pointOnCurve.point)
            previousPoint = pointOnCurve.point
        }
        distance = distance + previousPoint.distanceTo(toVertex.point)
        return distance
    }
}

public final class AvatarStoryIndicatorComponent: Component {
    public struct Colors: Equatable {
        public var unseenColors: [UIColor]
        public var unseenCloseFriendsColors: [UIColor]
        public var seenColors: [UIColor]
        
        public init(
            unseenColors: [UIColor],
            unseenCloseFriendsColors: [UIColor],
            seenColors: [UIColor]
        ) {
            self.unseenColors = unseenColors
            self.unseenCloseFriendsColors = unseenCloseFriendsColors
            self.seenColors = seenColors
        }
        
        public init(theme: PresentationTheme) {
            self.unseenColors = [theme.chatList.storyUnseenColors.topColor, theme.chatList.storyUnseenColors.bottomColor]
            self.unseenCloseFriendsColors = [theme.chatList.storyUnseenPrivateColors.topColor, theme.chatList.storyUnseenPrivateColors.bottomColor]
            self.seenColors = [theme.chatList.storySeenColors.topColor, theme.chatList.storySeenColors.bottomColor]
        }
    }
    
    public struct Counters: Equatable {
        public var totalCount: Int
        public var unseenCount: Int
        
        public init(totalCount: Int, unseenCount: Int) {
            self.totalCount = totalCount
            self.unseenCount = unseenCount
        }
    }
    
    public enum Progress: Equatable {
        case indefinite
        case definite(Float)
    }
    
    public let hasUnseen: Bool
    public let hasUnseenCloseFriendsItems: Bool
    public let colors: Colors
    public let activeLineWidth: CGFloat
    public let inactiveLineWidth: CGFloat
    public let counters: Counters?
    public let progress: Progress?
    public let isRoundedRect: Bool
    
    public init(
        hasUnseen: Bool,
        hasUnseenCloseFriendsItems: Bool,
        colors: Colors,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat,
        counters: Counters?,
        progress: Progress? = nil,
        isRoundedRect: Bool = false
    ) {
        self.hasUnseen = hasUnseen
        self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
        self.colors = colors
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
        self.counters = counters
        self.progress = progress
        self.isRoundedRect = isRoundedRect
    }
    
    public static func ==(lhs: AvatarStoryIndicatorComponent, rhs: AvatarStoryIndicatorComponent) -> Bool {
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasUnseenCloseFriendsItems != rhs.hasUnseenCloseFriendsItems {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.activeLineWidth != rhs.activeLineWidth {
            return false
        }
        if lhs.inactiveLineWidth != rhs.inactiveLineWidth {
            return false
        }
        if lhs.counters != rhs.counters {
            return false
        }
        if lhs.progress != rhs.progress {
            return false
        }
        if lhs.isRoundedRect != rhs.isRoundedRect {
            return false
        }
        return true
    }
    
    private final class ProgressLayer: HierarchyTrackingLayer {
        enum Value: Equatable {
            case indefinite
            case progress(Float)
        }
        
        private struct Params: Equatable {
            var size: CGSize
            var lineWidth: CGFloat
            var value: Value
        }
        private var currentParams: Params?
        
        private let uploadProgressLayer = SimpleShapeLayer()
        
        private let indefiniteDashLayer = SimpleShapeLayer()
        private let indefiniteReplicatorLayer = CAReplicatorLayer()
        
        override init() {
            super.init()
            
            self.uploadProgressLayer.fillColor = nil
            self.uploadProgressLayer.strokeColor = UIColor.white.cgColor
            self.uploadProgressLayer.lineCap = .round
            
            self.indefiniteDashLayer.fillColor = nil
            self.indefiniteDashLayer.strokeColor = UIColor.white.cgColor
            self.indefiniteDashLayer.lineCap = .round
            self.indefiniteDashLayer.lineJoin = .round
            self.indefiniteDashLayer.strokeEnd = 0.0333
            
            let count = 1.0 / self.indefiniteDashLayer.strokeEnd
            let angle = (2.0 * Double.pi) / Double(count)
            self.indefiniteReplicatorLayer.addSublayer(self.indefiniteDashLayer)
            self.indefiniteReplicatorLayer.instanceCount = Int(count)
            self.indefiniteReplicatorLayer.instanceTransform = CATransform3DMakeRotation(CGFloat(angle), 0.0, 0.0, 1.0)
            self.indefiniteReplicatorLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
            self.indefiniteReplicatorLayer.instanceDelay = 0.025
            
            self.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.updateAnimations(transition: .immediate)
            }
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func reset() {
            self.currentParams = nil
            self.indefiniteDashLayer.path = nil
            self.uploadProgressLayer.path = nil
        }
        
        func updateAnimations(transition: ComponentTransition) {
            guard let params = self.currentParams else {
                return
            }
            
            switch params.value {
            case let .progress(progress):
                if self.indefiniteReplicatorLayer.superlayer != nil {
                    self.indefiniteReplicatorLayer.removeFromSuperlayer()
                }
                if self.uploadProgressLayer.superlayer == nil {
                    self.addSublayer(self.uploadProgressLayer)
                }
                transition.setShapeLayerStrokeEnd(layer: self.uploadProgressLayer, strokeEnd: CGFloat(progress))
                if self.uploadProgressLayer.animation(forKey: "rotation") == nil {
                    let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    rotationAnimation.duration = 2.0
                    rotationAnimation.fromValue = NSNumber(value: Float(0.0))
                    rotationAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                    rotationAnimation.repeatCount = Float.infinity
                    rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                    self.uploadProgressLayer.add(rotationAnimation, forKey: "rotation")
                }
            case .indefinite:
                if self.uploadProgressLayer.superlayer == nil {
                    self.uploadProgressLayer.removeFromSuperlayer()
                }
                if self.indefiniteReplicatorLayer.superlayer == nil {
                    self.addSublayer(self.indefiniteReplicatorLayer)
                }
                if self.indefiniteReplicatorLayer.animation(forKey: "rotation") == nil {
                    let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    rotationAnimation.duration = 4.0
                    rotationAnimation.fromValue = NSNumber(value: -.pi / 2.0)
                    rotationAnimation.toValue = NSNumber(value: -.pi / 2.0 + Double.pi * 2.0)
                    rotationAnimation.repeatCount = Float.infinity
                    rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                    self.indefiniteReplicatorLayer.add(rotationAnimation, forKey: "rotation")
                }
                if self.indefiniteDashLayer.animation(forKey: "dash") == nil {
                    let dashAnimation = CAKeyframeAnimation(keyPath: "strokeStart")
                    dashAnimation.keyTimes = [0.0, 0.45, 0.55, 1.0]
                    dashAnimation.values = [
                        self.indefiniteDashLayer.strokeStart,
                        self.indefiniteDashLayer.strokeEnd,
                        self.indefiniteDashLayer.strokeEnd,
                        self.indefiniteDashLayer.strokeStart,
                    ]
                    dashAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
                    dashAnimation.duration = 2.5
                    dashAnimation.repeatCount = .infinity
                    self.indefiniteDashLayer.add(dashAnimation, forKey: "dash")
                }
            }
        }
        
        func update(size: CGSize, radius: CGFloat, isRoundedRect: Bool, lineWidth: CGFloat, value: Value, transition: ComponentTransition) {
            let params = Params(
                size: size,
                lineWidth: lineWidth,
                value: value
            )
            if self.currentParams == params {
                return
            }
            self.currentParams = params
            
            self.indefiniteDashLayer.lineWidth = lineWidth
            self.uploadProgressLayer.lineWidth = lineWidth
            
            let bounds = CGRect(origin: .zero, size: size)
            if self.uploadProgressLayer.path == nil {
                let path = CGMutablePath()
                path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
                self.uploadProgressLayer.path = path
                self.uploadProgressLayer.frame = bounds
            }
            
            if self.indefiniteDashLayer.path == nil {
                let path = CGMutablePath()
                path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
                self.indefiniteDashLayer.path = path
                self.indefiniteReplicatorLayer.frame = bounds
                self.indefiniteDashLayer.frame = bounds
            }
            
            self.updateAnimations(transition: transition)
        }
    }
    
    public final class View: UIView {
        private let indicatorView: UIImageView
        private var progressLayer: ProgressLayer?
        private var colorLayer: SimpleGradientLayer?
        
        private var component: AvatarStoryIndicatorComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.indicatorView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.indicatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarStoryIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let diameter: CGFloat
            
            let maxOuterInset = component.activeLineWidth * 2.0
            diameter = availableSize.width + maxOuterInset * 2.0
            let imageDiameter = ceil(availableSize.width + maxOuterInset * 2.0)
            
            let activeColors: [CGColor]
            let inactiveColors: [CGColor]
            
            if component.hasUnseenCloseFriendsItems {
                activeColors = component.colors.unseenCloseFriendsColors.map(\.cgColor)
            } else {
                activeColors = component.colors.unseenColors.map(\.cgColor)
            }
            
            inactiveColors = component.colors.seenColors.map(\.cgColor)
            
            let radius = (diameter - component.activeLineWidth) * 0.5
            
            self.indicatorView.image = generateImage(CGSize(width: imageDiameter, height: imageDiameter), rotatedContext: { size, context in
                UIGraphicsPushContext(context)
                defer {
                    UIGraphicsPopContext()
                }
                
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setLineCap(.round)
                
                var locations: [CGFloat] = [0.0, 1.0]
                
                if let counters = component.counters, counters.totalCount > 1 {
                    if component.isRoundedRect {
                        let lineWidth: CGFloat = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                        context.setLineWidth(lineWidth)
                        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), cornerRadius: floor(diameter * 0.27))
                        
                        var startPoint: CGPoint?
                        var vertices: [CurveVertex] = []
                        path.cgPath.applyWithBlock({ element in
                            switch element.pointee.type {
                            case .moveToPoint:
                                startPoint = element.pointee.points[0]
                            case .addLineToPoint:
                                if let _ = vertices.last {
                                    vertices.append(CurveVertex(point: element.pointee.points[0], inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                } else if let startPoint {
                                    vertices.append(CurveVertex(point: startPoint, inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                    vertices.append(CurveVertex(point: element.pointee.points[0], inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                }
                            case .addQuadCurveToPoint:
                                break
                            case .addCurveToPoint:
                                if let _ = vertices.last {
                                    vertices.append(CurveVertex(point: element.pointee.points[2], inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                } else if let startPoint {
                                    vertices.append(CurveVertex(point: startPoint, inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                    vertices.append(CurveVertex(point: element.pointee.points[2], inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                }
                                
                                if vertices.count >= 2 {
                                    vertices[vertices.count - 2].outTangent = element.pointee.points[0]
                                    vertices[vertices.count - 1].inTangent = element.pointee.points[1]
                                }
                            case .closeSubpath:
                                if let startPointValue = startPoint {
                                    vertices.append(CurveVertex(point: startPointValue, inTangentRelative: CGPoint(), outTangentRelative: CGPoint()))
                                    startPoint = nil
                                }
                            @unknown default:
                                break
                            }
                        })
                        
                        var length: CGFloat = 0.0
                        var firstOffset: CGFloat = 0.0
                        for i in 0 ..< vertices.count - 1 {
                            let value = vertices[i].distanceTo(vertices[i + 1])
                            if firstOffset == 0.0 {
                                firstOffset = value * 0.5
                            }
                            length += value
                        }
                        
                        let spacing: CGFloat = component.activeLineWidth * 2.0
                        let useableLength = length - spacing * CGFloat(counters.totalCount)
                        let segmentLength = useableLength / CGFloat(counters.totalCount)
                        
                        context.setLineWidth(lineWidth)
                        
                        for index in 0 ..< counters.totalCount {
                            var dashWidths: [CGFloat] = []
                            dashWidths.append(segmentLength)
                            dashWidths.append(10000000.0)
                            
                            let colors: [CGColor]
                            if index >= counters.totalCount - counters.unseenCount {
                                colors = activeColors
                            } else {
                                colors = inactiveColors
                            }
                            let colorSpace = CGColorSpaceCreateDeviceRGB()
                            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                            
                            context.resetClip()
                            context.setLineDash(phase: -firstOffset - spacing * 0.5 - CGFloat(index) * (spacing + segmentLength), lengths: dashWidths)
                            context.addPath(path.cgPath)
                            
                            context.replacePathWithStrokedPath()
                            context.clip()
                            
                            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                            
                            if index == counters.totalCount - 1 {
                                context.resetClip()
                                let addPath = CGMutablePath()
                                addPath.move(to: CGPoint(x: vertices[0].interpolate(to: vertices[1], amount: 0.5).point.x - spacing * 0.5, y: vertices[0].point.y))
                                addPath.addLine(to: CGPoint(x: vertices[0].point.x, y: vertices[0].point.y))
                                context.setLineDash(phase: 0.0, lengths: [])
                                context.addPath(addPath)
                                context.replacePathWithStrokedPath()
                                context.clip()
                                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                            }
                        }
                    } else {
                        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                        let spacing: CGFloat = component.activeLineWidth * 2.0
                        let angularSpacing: CGFloat = spacing / radius
                        let circleLength = CGFloat.pi * 2.0 * radius
                        let segmentLength = (circleLength - spacing * CGFloat(counters.totalCount)) / CGFloat(counters.totalCount)
                        let segmentAngle = segmentLength / radius
                        
                        for pass in 0 ..< 2 {
                            context.resetClip()
                            
                            if pass == 0 {
                                context.setLineWidth(component.inactiveLineWidth)
                            } else {
                                context.setLineWidth(component.activeLineWidth)
                            }
                            
                            let startIndex: Int
                            let endIndex: Int
                            if pass == 0 {
                                startIndex = 0
                                endIndex = counters.totalCount - counters.unseenCount
                            } else {
                                startIndex = counters.totalCount - counters.unseenCount
                                endIndex = counters.totalCount
                            }
                            if startIndex < endIndex {
                                for i in startIndex ..< endIndex {
                                    let startAngle = CGFloat(i) * (angularSpacing + segmentAngle) - CGFloat.pi * 0.5 + angularSpacing * 0.5
                                    context.move(to: CGPoint(x: center.x + cos(startAngle) * radius, y: center.y + sin(startAngle) * radius))
                                    context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + segmentAngle, clockwise: false)
                                }
                                
                                context.replacePathWithStrokedPath()
                                context.clip()
                                
                                let colors: [CGColor]
                                if pass == 1 {
                                    colors = activeColors
                                } else {
                                    colors = inactiveColors
                                }
                                
                                let colorSpace = CGColorSpaceCreateDeviceRGB()
                                if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations) {
                                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                                }
                            }
                        }
                    }
                } else {
                    let lineWidth: CGFloat = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                    context.setLineWidth(lineWidth)
                    if component.isRoundedRect {
                        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), cornerRadius: floor(diameter * 0.27))
                        context.addPath(path.cgPath)
                    } else {
                        context.addEllipse(in: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                    }
                    
                    context.replacePathWithStrokedPath()
                    context.clip()
                    
                    let colors: [CGColor]
                    if component.hasUnseen {
                        colors = activeColors
                    } else {
                        colors = inactiveColors
                    }
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                }
            })
            let indicatorFrame = CGRect(origin: CGPoint(x: (availableSize.width - imageDiameter) * 0.5, y: (availableSize.height - imageDiameter) * 0.5), size: CGSize(width: imageDiameter, height: imageDiameter))
            transition.setFrame(view: self.indicatorView, frame: indicatorFrame)
            
            let progressTransition = ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut))
            if let progress = component.progress, !component.isRoundedRect {
                let colorLayer: SimpleGradientLayer
                if let current = self.colorLayer {
                    colorLayer = current
                } else {
                    colorLayer = SimpleGradientLayer()
                    self.colorLayer = colorLayer
                    self.layer.addSublayer(colorLayer)
                    colorLayer.opacity = 0.0
                }
                
                progressTransition.setAlpha(view: self.indicatorView, alpha: 0.0)
                progressTransition.setAlpha(layer: colorLayer, alpha: 1.0)
                
                let colors: [CGColor] = activeColors
                let lineWidth: CGFloat
                if case .definite = progress {
                    lineWidth = component.activeLineWidth
                } else {
                    lineWidth = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                }
                
                colorLayer.colors = colors
                colorLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                colorLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
                
                let progressLayer: ProgressLayer
                if let current = self.progressLayer {
                    progressLayer = current
                } else {
                    progressLayer = ProgressLayer()
                    self.progressLayer = progressLayer
                    colorLayer.mask = progressLayer
                }
                
                colorLayer.frame = indicatorFrame
                progressLayer.frame = CGRect(origin: CGPoint(), size: indicatorFrame.size)
                
                let mappedProgress: ProgressLayer.Value
                switch progress {
                case .indefinite:
                    mappedProgress = .indefinite
                case let .definite(value):
                    mappedProgress = .progress(value)
                }
                
                progressLayer.update(size: indicatorFrame.size, radius: radius, isRoundedRect: component.isRoundedRect, lineWidth: lineWidth, value: mappedProgress, transition: .immediate)
            } else {
                progressTransition.setAlpha(view: self.indicatorView, alpha: 1.0)
                
                self.progressLayer = nil
                if let colorLayer = self.colorLayer {
                    self.colorLayer = nil
                    
                    progressTransition.setAlpha(layer: colorLayer, alpha: 0.0, completion: { [weak colorLayer] _ in
                        colorLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
