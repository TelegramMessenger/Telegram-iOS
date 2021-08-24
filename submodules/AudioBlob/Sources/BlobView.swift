import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents

public final class VoiceBlobNode: ASDisplayNode {
    public init(
        maxLevel: CGFloat,
        smallBlobRange: VoiceBlobView.BlobRange,
        mediumBlobRange: VoiceBlobView.BlobRange,
        bigBlobRange: VoiceBlobView.BlobRange
    ) {
        super.init()
        
        self.setViewBlock({
            return VoiceBlobView(frame: CGRect(), maxLevel: maxLevel, smallBlobRange: smallBlobRange, mediumBlobRange: mediumBlobRange, bigBlobRange: bigBlobRange)
        })
    }
    
    public func startAnimating(immediately: Bool = false) {
        (self.view as? VoiceBlobView)?.startAnimating(immediately: immediately)
    }
    
    public func stopAnimating(duration: Double = 0.15) {
        (self.view as? VoiceBlobView)?.stopAnimating(duration: duration)
    }
    
    public func setColor(_ color: UIColor, animated: Bool = false) {
        (self.view as? VoiceBlobView)?.setColor(color, animated: animated)
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool = false) {
        (self.view as? VoiceBlobView)?.updateLevel(level, immediately: immediately)
    }
}

public final class VoiceBlobView: UIView, TGModernConversationInputMicButtonDecoration {
    private let smallBlob: BlobNode
    private let mediumBlob: BlobNode
    private let bigBlob: BlobNode
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true

    public var isManuallyInHierarchy: Bool?
    
    private var audioLevel: CGFloat = 0
    public var presentationAudioLevel: CGFloat = 0
    
    private(set) var isAnimating = false
    
    public typealias BlobRange = (min: CGFloat, max: CGFloat)
    
    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallBlobRange: BlobRange,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        self.maxLevel = maxLevel
        
        self.smallBlob = BlobNode(
            pointsCount: 8,
            minRandomness: 0.1,
            maxRandomness: 0.5,
            minSpeed: 0.2,
            maxSpeed: 0.6,
            minScale: smallBlobRange.min,
            maxScale: smallBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: true
        )
        self.mediumBlob = BlobNode(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 0.9,
            maxSpeed: 4,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        self.bigBlob = BlobNode(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 0.9,
            maxSpeed: 4,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )

        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init(frame: frame)

        self.addSubnode(self.hierarchyTrackingNode)
        
        self.addSubnode(self.bigBlob)
        self.addSubnode(self.mediumBlob)
        self.addSubnode(self.smallBlob)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallBlob.level = strongSelf.presentationAudioLevel
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        self.setColor(color, animated: false)
    }
    
    public func setColor(_ color: UIColor, animated: Bool) {
        if let isManuallyInHierarchy = self.isManuallyInHierarchy, !isManuallyInHierarchy {
            return
        }
        smallBlob.setColor(color, animated: animated)
        mediumBlob.setColor(color.withAlphaComponent(0.3), animated: animated)
        bigBlob.setColor(color.withAlphaComponent(0.15), animated: animated)
    }
    
    public func updateLevel(_ level: CGFloat) {
        self.updateLevel(level, immediately: false)
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool = false) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallBlob.updateSpeedLevel(to: normalizedLevel)
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
        if immediately {
            presentationAudioLevel = normalizedLevel
        }
    }
    
    public func startAnimating() {
        self.startAnimating(immediately: false)
    }
    
    public func startAnimating(immediately: Bool = false) {
        guard !isAnimating else { return }
        isAnimating = true
        
        if !immediately {
            mediumBlob.layer.animateScale(from: 0.75, to: 1, duration: 0.35, removeOnCompletion: false)
            bigBlob.layer.animateScale(from: 0.75, to: 1, duration: 0.35, removeOnCompletion: false)
        } else {
            mediumBlob.layer.removeAllAnimations()
            bigBlob.layer.removeAllAnimations()
        }
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false
        
        mediumBlob.layer.animateScale(from: 1.0, to: 0.75, duration: duration, removeOnCompletion: false)
        bigBlob.layer.animateScale(from: 1.0, to: 0.75, duration: duration, removeOnCompletion: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        if self.isAnimating {
            if self.smallBlob.frame.size != .zero {
                smallBlob.startAnimating()
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            smallBlob.stopAnimating()
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.smallBlob.frame = bounds
        self.mediumBlob.frame = bounds
        self.bigBlob.frame = bounds
        
        self.updateBlobsState()
    }
}

final class BlobNode: ASDisplayNode {
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minScale: CGFloat
    let maxScale: CGFloat
    let scaleSpeed: CGFloat
    
    let isCircle: Bool
    
    var level: CGFloat = 0 {
        didSet {
            if abs(self.level - oldValue) > 0.01 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let lv = self.minScale + (self.maxScale - self.minScale) * self.level
                self.shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
                CATransaction.commit()
            }
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var scaleLevel: CGFloat = 0
    
    private var lastSpeedLevel: CGFloat = 0
    private var lastScaleLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            
            shapeLayer.path = UIBezierPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness).cgPath
        }
    }
    
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat,
        scaleSpeed: CGFloat,
        isCircle: Bool
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        self.scaleSpeed = scaleSpeed
        self.isCircle = isCircle
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2

        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()

        self.addSubnode(self.hierarchyTrackingNode)
        self.layer.addSublayer(self.shapeLayer)
        
        self.shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor, animated: Bool) {
        let previousColor = self.shapeLayer.fillColor
        self.shapeLayer.fillColor = color.cgColor
        if animated, let previousColor = previousColor, self.isCurrentlyInHierarchy {
            self.shapeLayer.animate(from: previousColor, to: color.cgColor, keyPath: "fillColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        }
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        self.speedLevel = max(self.speedLevel, newSpeedLevel)
    }
    
    func startAnimating() {
        self.animateToNewShape()
    }
    
    func stopAnimating() {
        self.shapeLayer.removeAnimation(forKey: "path")
    }
    
    private func animateToNewShape() {
        guard !isCircle else { return }
        
        if self.shapeLayer.path == nil {
            let points = generateNextBlob(for: self.bounds.size)
            self.shapeLayer.path = UIBezierPath.smoothCurve(through: points, length: bounds.width, smoothness: smoothness).cgPath
        }
        
        let nextPoints = generateNextBlob(for: self.bounds.size)
        let nextPath = UIBezierPath.smoothCurve(through: nextPoints, length: bounds.width, smoothness: smoothness).cgPath
        
        let animation = CABasicAnimation(keyPath: "path")
        let previousPath = self.shapeLayer.path
        self.shapeLayer.path = nextPath
        animation.duration = CFTimeInterval(1 / (self.minSpeed + (self.maxSpeed - self.minSpeed) * self.speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = previousPath
        animation.toValue = nextPath
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.completion = { [weak self] finished in
            if finished {
                self?.animateToNewShape()
            }
        }

        self.shapeLayer.add(animation, forKey: "path")

        self.lastSpeedLevel = self.speedLevel
        self.speedLevel = 0
    }
    
    // MARK: Helpers
    
    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness)
            .map {
                return CGPoint(
                    x: $0.x * CGFloat(size.width),
                    y: $0.y * CGFloat(size.height)
                )
            }
    }
    
    func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        
        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1 / (1 + randomness / 10)
        
        let startAngle = angle * CGFloat(arc4random_uniform(100)) / CGFloat(100)
        
        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let angleRandomness: CGFloat = angle * 0.1
            let randAngle = angle + angle * ((angleRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - angleRandomness * 0.5)
            let pointX = sin(startAngle + CGFloat(i) * randAngle)
            let pointY = cos(startAngle + CGFloat(i) * randAngle)
            return CGPoint(
                x: pointX * randPointOffset,
                y: pointY * randPointOffset
            )
        }
        
        return points
    }
    
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        if self.isCircle {
            let halfWidth = self.bounds.width * 0.5
            self.shapeLayer.path = UIBezierPath(
                roundedRect: self.bounds.offsetBy(dx: -halfWidth, dy: -halfWidth),
                cornerRadius: halfWidth
            ).cgPath
        }
        CATransaction.commit()
    }
}

private extension UIBezierPath {
    static func smoothCurve(
        through points: [CGPoint],
        length: CGFloat,
        smoothness: CGFloat
    ) -> UIBezierPath {
        var smoothPoints = [SmoothPoint]()
        for index in (0 ..< points.count) {
            let prevIndex = index - 1
            let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
            let curr = points[index]
            let next = points[(index + 1) % points.count]
            
            let angle: CGFloat = {
                let dx = next.x - prev.x
                let dy = -next.y + prev.y
                let angle = atan2(dy, dx)
                if angle < 0 {
                    return abs(angle)
                } else {
                    return 2 * .pi - angle
                }
            }()
            
            smoothPoints.append(
                SmoothPoint(
                    point: curr,
                    inAngle: angle + .pi,
                    inLength: smoothness * distance(from: curr, to: prev),
                    outAngle: angle,
                    outLength: smoothness * distance(from: curr, to: next)
                )
            )
        }
        
        let resultPath = UIBezierPath()
        resultPath.move(to: smoothPoints[0].point)
        for index in (0 ..< smoothPoints.count) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
        }
        resultPath.close()
        return resultPath
    }
    
    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }
    
    struct SmoothPoint {
        let point: CGPoint
        
        let inAngle: CGFloat
        let inLength: CGFloat
        
        let outAngle: CGFloat
        let outLength: CGFloat
        
        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }
        
        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }
        
        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}
