import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class BlobView: UIView {
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minScale: CGFloat
    let maxScale: CGFloat
    
    var scaleUpdated: ((CGFloat) -> Void)?
    
    var level: CGFloat = 0 {
        didSet {
            if abs(self.level - oldValue) > 0.01 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let lv = self.minScale + (self.maxScale - self.minScale) * self.level
                self.shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
                self.scaleUpdated?(self.level)
                CATransaction.commit()
            }
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
        
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.shapeLayer)
        
        self.shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        self.shapeLayer.fillColor = color.cgColor
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
        if self.shapeLayer.path == nil {
            let points = generateNextBlob(for: self.bounds.size)
            self.shapeLayer.path = UIBezierPath.smoothCurve(through: points, length: bounds.width, smoothness: smoothness).cgPath
        }
        
        let nextPoints = generateNextBlob(for: self.bounds.size)
        let nextPath = UIBezierPath.smoothCurve(through: nextPoints, length: bounds.width, smoothness: smoothness).cgPath
        
        let animation = CABasicAnimation(keyPath: "path")
        let previousPath = self.shapeLayer.path
        self.shapeLayer.path = nextPath
        animation.duration = CFTimeInterval(1.0 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
}
