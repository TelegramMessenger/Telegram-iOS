import Foundation
import Display
import AsyncDisplayKit
import LegacyComponents
import SwiftSignalKit

final class RadialDownloadContentNode: RadialStatusContentNode {
    var color: UIColor {
        didSet {
            self.leftLine.fillColor = UIColor.clear.cgColor
            self.leftLine.strokeColor = self.color.cgColor
            self.rightLine.fillColor = UIColor.clear.cgColor
            self.rightLine.strokeColor = self.color.cgColor
            self.arrowBody.fillColor = UIColor.clear.cgColor
            self.arrowBody.strokeColor = self.color.cgColor
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var animationCompletionTimer: SwiftSignalKit.Timer?
    
    private var isAnimatingProgress: Bool {
        return self.pop_animation(forKey: "progress") != nil || self.animationCompletionTimer != nil
    }
    
    private var enqueuedReadyForTransition: (() -> Void)?
    
    private let leftLine = CAShapeLayer()
    private let rightLine = CAShapeLayer()
    private let arrowBody = CAShapeLayer()
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.leftLine.fillColor = UIColor.clear.cgColor
        self.leftLine.strokeColor = self.color.cgColor
        self.leftLine.lineCap = kCALineCapRound
        self.leftLine.lineJoin = kCALineCapRound
        self.rightLine.fillColor = UIColor.clear.cgColor
        self.rightLine.strokeColor = self.color.cgColor
        self.rightLine.lineCap = kCALineCapRound
        self.rightLine.lineJoin = kCALineCapRound
        self.arrowBody.fillColor = UIColor.clear.cgColor
        self.arrowBody.strokeColor = self.color.cgColor
        self.arrowBody.lineCap = kCALineCapRound
        self.arrowBody.lineJoin = kCALineCapRound
        
        self.isLayerBacked = true
        self.isOpaque = false
        
        self.layer.addSublayer(self.arrowBody)
        self.layer.addSublayer(self.leftLine)
        self.layer.addSublayer(self.rightLine)
    }
    
    override func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        if self.isAnimatingProgress {
            self.enqueuedReadyForTransition = f
        } else {
            f()
        }
    }
    
    private func svgPath(_ path: StaticString, scale: CGFloat = 1.0, offset: CGPoint = CGPoint()) throws -> UIBezierPath {
        var index: UnsafePointer<UInt8> = path.utf8Start
        let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
        let path = UIBezierPath()
        while index < end {
            let c = index.pointee
            index = index.successor()
            
            if c == 77 { // M
                let x = try readCGFloat(&index, end: end, separator: 44) * scale + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale + offset.y
                
                path.move(to: CGPoint(x: x, y: y))
            } else if c == 76 { // L
                let x = try readCGFloat(&index, end: end, separator: 44) * scale + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale + offset.y
                
                path.addLine(to: CGPoint(x: x, y: y))
            } else if c == 67 { // C
                let x1 = try readCGFloat(&index, end: end, separator: 44) * scale + offset.x
                let y1 = try readCGFloat(&index, end: end, separator: 32) * scale + offset.y
                let x2 = try readCGFloat(&index, end: end, separator: 44) * scale + offset.x
                let y2 = try readCGFloat(&index, end: end, separator: 32) * scale + offset.y
                let x = try readCGFloat(&index, end: end, separator: 44) * scale + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale + offset.y
                path.addCurve(to: CGPoint(x: x, y: y), controlPoint1: CGPoint(x: x1, y: y1), controlPoint2: CGPoint(x: x2, y: y2))
            } else if c == 32 { // space
                continue
            }
        }
        return path
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let diameter = min(bounds.size.width, bounds.size.height)
        
        var lineWidth: CGFloat = 2.0
        if diameter < 24.0 {
            lineWidth = 1.3
        }
        
        self.leftLine.lineWidth = lineWidth
        self.rightLine.lineWidth = lineWidth
        self.arrowBody.lineWidth = lineWidth
        
        let factor = diameter / 50.0

        let arrowHeadSize: CGFloat = 15.0 * factor
        let arrowLength: CGFloat = 18.0 * factor
        let arrowHeadOffset: CGFloat = 1.0 * factor

        var bodyPath = UIBezierPath()
        if let path = try? svgPath("M1.20125335,62.2095675 C1.78718228,62.9863141 2.3877868,63.7395876 3.00158591,64.4690754 C22.1087455,87.1775489 54.0019347,86.8368674 54.0066002,54.0178571 L54.0066002,0.625 ", scale: 0.333333 * factor, offset: CGPoint(x: 7.0 * factor, y: (17.0 - UIScreenPixel) * factor)) {
            bodyPath = path
        }
        
        self.arrowBody.path = bodyPath.cgPath
        self.arrowBody.strokeStart = 0.62
        
        let leftPath = UIBezierPath()
        leftPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
        leftPath.addLine(to: CGPoint(x: diameter / 2.0 - arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
        self.leftLine.path = leftPath.cgPath
        
        let rightPath = UIBezierPath()
        rightPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
        rightPath.addLine(to: CGPoint(x: diameter / 2.0 + arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
        self.rightLine.path = rightPath.cgPath
    }
    
    private let duration: Double = 0.2
    
    override func prepareAnimateOut(completion: @escaping () -> Void) {
        self.leftLine.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.rightLine.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        self.leftLine.animateAlpha(from: 1.0, to: 0.0, duration: 0.23, delay: 0.07, removeOnCompletion: false) { finished in
            completion()
        }
        self.rightLine.animateAlpha(from: 1.0, to: 0.0, duration: 0.23, delay: 0.07, removeOnCompletion: false)
    }
    
    override func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        self.arrowBody.animateStrokeStart(from: 0.62, to: 0.0, duration: 0.5, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.arrowBody.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.5, removeOnCompletion: false, completion: nil)
        self.arrowBody.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, delay: 0.4, removeOnCompletion: false)
    }
    
    override func animateIn(from: RadialStatusNodeState) {
        if case .progress = from {
            var transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            transform = CATransform3DTranslate(transform, -50.0, 0.0, 0.0)
            self.arrowBody.transform = transform
            self.arrowBody.animateStrokeStart(from: 0.0, to: 0.62, duration: 0.5, removeOnCompletion: false, completion: { [weak self] _ in
                UIView.performWithoutAnimation {
                    self?.arrowBody.transform = CATransform3DIdentity
                }
            })
            self.arrowBody.animateStrokeEnd(from: 0.0, to: 1.0, duration: 0.5, removeOnCompletion: false, completion: nil)
            
            self.leftLine.animateStrokeEnd(from: 0.0, to: 1.0, duration: 0.2, delay: 0.3, removeOnCompletion: false)
            self.rightLine.animateStrokeEnd(from: 0.0, to: 1.0, duration: 0.2, delay: 0.3, removeOnCompletion: false)
            
            self.leftLine.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1, removeOnCompletion: false)
            self.rightLine.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1, removeOnCompletion: false)
        } else {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            self.layer.animateScale(from: 0.7, to: 1.0, duration: duration)
        }
    }
}

private extension CAShapeLayer {
    func animateStrokeStart(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeStart", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateStrokeEnd(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeEnd", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
}
