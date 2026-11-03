import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents
import SwiftSignalKit

private extension CAShapeLayer {
    func animateStrokeStart(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeStart", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateStrokeEnd(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeEnd", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
}

final class RadialDownloadContentNode: RadialStatusContentNode {
    var color: UIColor {
        didSet {
            self.leftLine.strokeColor = self.color.cgColor
            self.rightLine.strokeColor = self.color.cgColor
            self.arrowBody.strokeColor = self.color.cgColor
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var enqueuedReadyForTransition: (() -> Void)?
    private var isAnimatingTransition = false
    
    private let leftLine = CAShapeLayer()
    private let rightLine = CAShapeLayer()
    private let arrowBody = CAShapeLayer()
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.leftLine.fillColor = UIColor.clear.cgColor
        self.leftLine.strokeColor = self.color.cgColor
        self.leftLine.lineCap = .round
        self.leftLine.lineJoin = .round
        self.rightLine.fillColor = UIColor.clear.cgColor
        self.rightLine.strokeColor = self.color.cgColor
        self.rightLine.lineCap = .round
        self.rightLine.lineJoin = .round
        self.arrowBody.fillColor = UIColor.clear.cgColor
        self.arrowBody.strokeColor = self.color.cgColor
        self.arrowBody.lineCap = .round
        self.arrowBody.lineJoin = .round
        
        self.isLayerBacked = true
        self.isOpaque = false
        
        self.layer.addSublayer(self.arrowBody)
        self.layer.addSublayer(self.leftLine)
        self.layer.addSublayer(self.rightLine)
    }
    
    override func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        if self.isAnimatingTransition {
            self.enqueuedReadyForTransition = f
        } else {
            f()
        }
    }
    
    private func svgPath(_ path: StaticString, scale: CGPoint = CGPoint(x: 1.0, y: 1.0), offset: CGPoint = CGPoint()) throws -> UIBezierPath {
        var index: UnsafePointer<UInt8> = path.utf8Start
        let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
        let path = UIBezierPath()
        while index < end {
            let c = index.pointee
            index = index.successor()
            
            if c == 77 { // M
                let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                
                path.move(to: CGPoint(x: x, y: y))
            } else if c == 76 { // L
                let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                
                path.addLine(to: CGPoint(x: x, y: y))
            } else if c == 67 { // C
                let x1 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                let y1 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                let x2 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                let y2 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
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
        let factor = diameter / 50.0
        
        let lineWidth: CGFloat = max(1.6, 2.25 * factor)

        self.leftLine.lineWidth = lineWidth
        self.rightLine.lineWidth = lineWidth
        self.arrowBody.lineWidth = lineWidth
        
        let arrowHeadSize: CGFloat = 15.0 * factor
        let arrowLength: CGFloat = 18.0 * factor
        let arrowHeadOffset: CGFloat = 1.0 * factor

        let leftPath = UIBezierPath()
        leftPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
        leftPath.addLine(to: CGPoint(x: diameter / 2.0 - arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
        self.leftLine.path = leftPath.cgPath
        
        let rightPath = UIBezierPath()
        rightPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
        rightPath.addLine(to: CGPoint(x: diameter / 2.0 + arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
        self.rightLine.path = rightPath.cgPath
        
        if self.delayPrepareAnimateIn {
            self.delayPrepareAnimateIn = false
            self.prepareAnimateIn(from: nil)
        }
    }
    
    private let duration: Double = 0.2
    
    override func prepareAnimateOut(completion: @escaping (Double) -> Void) {
        let bounds = self.bounds
        let diameter = min(bounds.size.width, bounds.size.height)
        let factor = diameter / 50.0
        
        var bodyPath = UIBezierPath()
        
        if let path = try? svgPath("M1.10890748,47.3077093 C2.74202161,51.7201715 4.79761832,55.7299828 7.15775768,59.3122505 C25.4413606,87.0634763 62.001605,89.1563513 62.0066002,54.0178571 L62.0066002,0.625 ", scale: CGPoint(x: 0.333333 * factor, y: 0.333333 * factor), offset: CGPoint(x: (4.0 + UIScreenPixel) * factor, y: (17.0 - UIScreenPixel) * factor)) {
            bodyPath = path
        }
        
        self.arrowBody.path = bodyPath.cgPath
        self.arrowBody.strokeStart = 0.65
        
        self.leftLine.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.rightLine.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        self.leftLine.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.07, removeOnCompletion: false) { finished in
            completion(0.0)
        }
        self.rightLine.animateAlpha(from: 1.0, to: 0.0, duration: 0.02, delay: 0.15, removeOnCompletion: false)  { finished in
            self.leftLine.strokeColor = UIColor.clear.cgColor
            self.rightLine.strokeColor = UIColor.clear.cgColor
        }
    }
    
    override func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        if self.bounds.width < 21.0 {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.layer.animateScale(from: 1.0, to: 0.2, duration: duration, removeOnCompletion: false)
        } else {
            self.isAnimatingTransition = true
            self.arrowBody.animateStrokeStart(from: 0.65, to: 0.0, duration: 0.5, removeOnCompletion: false, completion: { [weak self] _ in
                completion()
                if let strongSelf = self, strongSelf.isAnimatingTransition, let f = strongSelf.enqueuedReadyForTransition {
                    strongSelf.isAnimatingTransition = false
                    f()
                }
            })
            self.arrowBody.animateStrokeEnd(from: 1.0, to: 0.0, duration: 0.5, removeOnCompletion: false, completion: nil)
            self.arrowBody.animateAlpha(from: 1.0, to: 0.0, duration: 0.01, delay: 0.4, removeOnCompletion: false)
        }
    }
    
    private var delayPrepareAnimateIn = false
    override func prepareAnimateIn(from: RadialStatusNodeState?) {
        let bounds = self.bounds
        let diameter = min(bounds.size.width, bounds.size.height)
        guard !diameter.isZero else {
            self.delayPrepareAnimateIn = true
            return
        }
        let factor = diameter / 50.0
        
        var bodyPath = UIBezierPath()
        if let path = try? svgPath("M1.10890748,47.3077093 C2.74202161,51.7201715 4.79761832,55.7299828 7.15775768,59.3122505 C25.4413606,87.0634763 62.001605,89.1563513 62.0066002,54.0178571 L62.0066002,0.625 ", scale: CGPoint(x: -0.333333 * factor, y: 0.333333 * factor), offset: CGPoint(x: (46.0 - UIScreenPixel) * factor, y: (17.0 - UIScreenPixel) * factor)) {
            bodyPath = path
        }
        
        self.arrowBody.path = bodyPath.cgPath
        self.arrowBody.strokeStart = 0.65
    }
    
    override func animateIn(from: RadialStatusNodeState, delay: Double) {
        if case .progress = from {
            self.arrowBody.animateStrokeStart(from: 0.65, to: 0.65, duration: 0.25, delay: delay, removeOnCompletion: false, completion: nil)
            self.arrowBody.animateStrokeEnd(from: 0.65, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false, completion: nil)
            
            self.leftLine.animateStrokeEnd(from: 0.0, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false)
            self.rightLine.animateStrokeEnd(from: 0.0, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false)
            
            self.arrowBody.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false)
            self.leftLine.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false)
            self.rightLine.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: delay, removeOnCompletion: false)
        } else {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, delay: delay)
            self.layer.animateScale(from: 0.7, to: 1.0, duration: duration, delay: delay)
        }
    }
}
