import Foundation
import UIKit
import AsyncDisplayKit
import Display

private func generateIndefiniteActivityIndicatorImage(color: UIColor, diameter: CGFloat = 22.0, lineWidth: CGFloat = 2.0) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        let cutoutAngle: CGFloat = CGFloat.pi * 30.0 / 180.0
        context.addArc(center: CGPoint(x: size.width / 2.0, y: size.height / 2.0), radius: size.width / 2.0 - lineWidth / 2.0, startAngle: 0.0, endAngle: CGFloat.pi * 2.0 - cutoutAngle, clockwise: false)
        context.strokePath()
    })
}

private func convertIndicatorColor(_ color: UIColor) -> UIColor {
    if color.isEqual(UIColor(rgb: 0x007aff)) {
        return .gray
    } else if color.isEqual(UIColor(rgb: 0x2ea6ff)) {
        return .white
    } else if color.isEqual(UIColor(rgb: 0x000000)) || color.isEqual(UIColor.black) {
        return .gray
    } else {
        return color
    }
}

public enum ActivityIndicatorType: Equatable {
    case navigationAccent(UIColor)
    case custom(UIColor, CGFloat, CGFloat, Bool)
    
    public static func ==(lhs: ActivityIndicatorType, rhs: ActivityIndicatorType) -> Bool {
        switch lhs {
        case let .navigationAccent(lhsColor):
            if case let .navigationAccent(rhsColor) = rhs, lhsColor.isEqual(rhsColor) {
                return true
            } else {
                return false
            }
        case let .custom(lhsColor, lhsDiameter, lhsWidth, lhsForceCustom):
            if case let .custom(rhsColor, rhsDiameter, rhsWidth, rhsForceCustom) = rhs, lhsColor.isEqual(rhsColor), lhsDiameter == rhsDiameter, lhsWidth == rhsWidth, lhsForceCustom == rhsForceCustom {
                return true
            } else {
                return false
            }
        }
    }
}

public enum ActivityIndicatorSpeed {
    case regular
    case slow
}

public final class ActivityIndicator: ASDisplayNode {
    public var type: ActivityIndicatorType {
        didSet {
            switch self.type {
            case let .navigationAccent(color):
                self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color)
            case let .custom(color, diameter, lineWidth, _):
                self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color, diameter: diameter, lineWidth: lineWidth)
            }
            
            switch self.type {
            case let .navigationAccent(color):
                self.indicatorView?.color = color
            case let .custom(color, _, _, _):
                self.indicatorView?.color = convertIndicatorColor(color)
            }
        }
    }
    
    private var currentInHierarchy = false
    
    override public var isHidden: Bool {
        didSet {
            self.updateAnimation()
        }
    }
    
    private let speed: ActivityIndicatorSpeed
    
    private let indicatorNode: ASImageNode
    private var indicatorView: UIActivityIndicatorView?
    
    public init(type: ActivityIndicatorType, speed: ActivityIndicatorSpeed = .regular) {
        self.type = type
        self.speed = speed
        
        self.indicatorNode = ASImageNode()
        self.indicatorNode.isLayerBacked = true
        self.indicatorNode.displaysAsynchronously = false
        
        super.init()
        
        if case let .custom(_, _, _, forceCustom) = self.type, forceCustom {
            self.isLayerBacked = true
        }
        
        switch type {
        case let .navigationAccent(color):
            self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color)
        case let .custom(color, diameter, lineWidth, forceCustom):
            self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color, diameter: diameter, lineWidth: lineWidth)
            if forceCustom {
                self.addSubnode(self.indicatorNode)
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let indicatorView: UIActivityIndicatorView
        switch self.type {
        case let .navigationAccent(color):
            indicatorView = UIActivityIndicatorView(style: .whiteLarge)
            indicatorView.color = color
        case let .custom(color, diameter, _, forceCustom):
            indicatorView = UIActivityIndicatorView(style: diameter < 15.0 ? .white : .whiteLarge)
            indicatorView.color = convertIndicatorColor(color)
            if !forceCustom {
                self.view.addSubview(indicatorView)
            }
        }
        self.indicatorView = indicatorView
        let size = self.bounds.size
        if !size.width.isZero {
            self.layoutContents(size: size)
        }
    }
    
    private var isAnimating = false {
        didSet {
            if self.isAnimating != oldValue {
                if self.isAnimating {
                    self.indicatorView?.startAnimating()
                    let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                    switch self.speed {
                    case .regular:
                        basicAnimation.duration = 0.5
                    case .slow:
                        basicAnimation.duration = 0.7
                    }
                    basicAnimation.fromValue = NSNumber(value: Float(0.0))
                    basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
                    basicAnimation.repeatCount = Float.infinity
                    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                    basicAnimation.beginTime = 1.0
                    
                    self.indicatorNode.layer.add(basicAnimation, forKey: "progressRotation")
                } else {
                    self.indicatorView?.stopAnimating()
                    self.indicatorNode.layer.removeAnimation(forKey: "progressRotation")
                }
            }
        }
    }
    
    private func updateAnimation() {
        self.isAnimating = !self.isHidden && self.currentInHierarchy
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.currentInHierarchy = true
        self.updateAnimation()
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.currentInHierarchy = false
        self.updateAnimation()
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        switch self.type {
        case .navigationAccent:
            return CGSize(width: 22.0, height: 22.0)
        case let .custom(_, diameter, _, _):
            return CGSize(width: diameter, height: diameter)
        }
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.layoutContents(size: size)
    }
    
    private func layoutContents(size: CGSize) {
        let indicatorSize: CGSize
        let shouldScale: Bool
        switch self.type {
        case .navigationAccent:
            indicatorSize = CGSize(width: 22.0, height: 22.0)
            shouldScale = false
        case let .custom(_, diameter, _, forceDefault):
            indicatorSize = CGSize(width: diameter, height: diameter)
            shouldScale = !forceDefault
        }
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: ((size.width - indicatorSize.width) / 2.0), y: ((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
        if shouldScale, let indicatorView = self.indicatorView {
            let intrinsicSize = indicatorView.bounds.size
            self.subnodeTransform = CATransform3DMakeScale(min(1.0, indicatorSize.width / intrinsicSize.width), min(1.0, indicatorSize.height / intrinsicSize.height), 1.0)
            indicatorView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        }
    }
}
