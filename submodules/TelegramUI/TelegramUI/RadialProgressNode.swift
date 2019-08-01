import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import LegacyComponents

private class RadialProgressParameters: NSObject {
    let theme: RadialProgressTheme
    let diameter: CGFloat
    let state: RadialProgressState
    
    init(theme: RadialProgressTheme, diameter: CGFloat, state: RadialProgressState) {
        self.theme = theme
        self.diameter = diameter
        self.state = state
        
        super.init()
    }
}

private class RadialProgressOverlayParameters: NSObject {
    let theme: RadialProgressTheme
    let diameter: CGFloat
    let state: RadialProgressState
    
    init(theme: RadialProgressTheme, diameter: CGFloat, state: RadialProgressState) {
        self.theme = theme
        self.diameter = diameter
        self.state = state
        
        super.init()
    }
}

private class RadialProgressOverlayNode: ASDisplayNode {
    var theme: RadialProgressTheme
    
    var previousProgress: Float?
    var effectiveProgress: Float = 0.0 {
        didSet {
            if oldValue != self.effectiveProgress {
                self.setNeedsDisplay()
            }
        }
    }
    
    var progressAnimationCompleted: (() -> Void)?
    
    var state: RadialProgressState = .None {
        didSet {
            if case let .Fetching(progress) = oldValue {
                let animation = POPBasicAnimation()
                animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = CGFloat((node as! RadialProgressOverlayNode).effectiveProgress)
                    }
                    property?.writeBlock = { node, values in
                        (node as! RadialProgressOverlayNode).effectiveProgress = Float(values!.pointee)
                    }
                    property?.threshold = 0.01
                }) as! POPAnimatableProperty)
                animation.fromValue = CGFloat(effectiveProgress) as NSNumber
                animation.toValue = CGFloat(progress) as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.duration = 0.2
                animation.completionBlock = { [weak self] _, _ in
                    self?.progressAnimationCompleted?()
                }
                self.pop_removeAnimation(forKey: "progress")
                self.pop_add(animation, forKey: "progress")
            }
            self.setNeedsDisplay()
        }
    }
    
    init(theme: RadialProgressTheme) {
        self.theme = theme
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
    }
    
    func updateTheme(_ theme: RadialProgressTheme) {
        self.theme = theme
        self.setNeedsDisplay()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        var updatedState = self.state
        if case .Fetching = updatedState {
            updatedState = .Fetching(progress: self.effectiveProgress)
        }
        return RadialProgressOverlayParameters(theme: self.theme, diameter: self.frame.size.width, state: updatedState)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialProgressOverlayParameters {
            context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
            //CGContextSetLineWidth(context, 2.5)
            //CGContextSetLineCap(context, .Round)
            
            switch parameters.state {
                case .None, .Remote, .Play, .Pause, .Icon, .Image:
                    break
                case let .Fetching(progress):
                    let startAngle = -CGFloat.pi / 2.0
                    let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
                    
                    let pathDiameter = parameters.diameter - 2.25 - 2.5 * 2.0
                    
                    let path = UIBezierPath(arcCenter: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle:endAngle, clockwise:true)
                    path.lineWidth = 2.25;
                    path.lineCapStyle = .round;
                    path.stroke()
            }
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        basicAnimation.duration = 2.0
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        
        self.layer.add(basicAnimation, forKey: "progressRotation")
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.layer.removeAnimation(forKey: "progressRotation")
    }
}

public enum RadialProgressState {
    case None
    case Remote
    case Fetching(progress: Float)
    case Play
    case Pause
    case Icon
    case Image(UIImage)
}

public struct RadialProgressTheme {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let icon: UIImage?
}

class RadialProgressNode: ASControlNode {
    private var theme: RadialProgressTheme
    private let overlay: RadialProgressOverlayNode
    
    var state: RadialProgressState = .None {
        didSet {
            self.overlay.state = self.state
            if case .Fetching = self.state {
                if self.overlay.supernode == nil {
                    self.addSubnode(self.overlay)
                }
            } else {
                if self.overlay.supernode != nil {
                    /*if case let .Fetching(progress) = oldValue {
                        let overlay = self.overlay
                        overlay.state = .Fetching(progress: 1.0)
                        overlay.progressAnimationCompleted = { [weak overlay] in
                            overlay?.removeFromSupernode()
                        }
                    } else {*/
                        self.overlay.removeFromSupernode()
                    //}
                }
            }
            switch oldValue {
                case .Fetching:
                    switch self.state {
                        case .Fetching:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case .Remote:
                    switch self.state {
                        case .Remote:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case .None:
                    switch self.state {
                        case .None:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case .Play:
                    switch self.state {
                        case .Play:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case .Pause:
                    switch self.state {
                        case .Pause:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case .Icon:
                    switch self.state {
                        case .Icon:
                            break
                        default:
                            self.setNeedsDisplay()
                    }
                case let .Image(lhsImage):
                    if case let .Image(rhsImage) = self.state, lhsImage === rhsImage {
                        break
                    } else {
                        self.setNeedsDisplay()
                    }
            }
        }
    }
    
    init(theme: RadialProgressTheme) {
        self.theme = theme
        self.overlay = RadialProgressOverlayNode(theme: theme)
        
        super.init()
        
        self.isOpaque = false
    }
    
    func updateTheme(_ theme: RadialProgressTheme) {
        self.theme = theme
        self.setNeedsDisplay()
        self.overlay.updateTheme(theme)
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let redraw = value.size != self.frame.size
            super.frame = value
            
            if redraw {
                self.overlay.frame = CGRect(origin: CGPoint(), size: value.size)
                self.setNeedsDisplay()
                self.overlay.setNeedsDisplay()
            }
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialProgressParameters(theme: self.theme, diameter: self.frame.size.width, state: self.state)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialProgressParameters {
            context.setFillColor(parameters.theme.backgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: parameters.diameter, height: parameters.diameter)))
            
            switch parameters.state {
                case .None:
                    break
                case .Fetching:
                    context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    
                    let crossSize: CGFloat = 14.0
                    context.move(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
                    context.addLine(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
                    context.strokePath()
                    context.move(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
                    context.addLine(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
                    context.strokePath()
                case .Remote:
                    context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
            
                    let arrowHeadSize: CGFloat = 15.0
                    let arrowLength: CGFloat = 18.0
                    let arrowHeadOffset: CGFloat = 1.0
            
                    context.move(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 - arrowLength / 2.0 + arrowHeadOffset))
                    context.addLine(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - 1.0 + arrowHeadOffset))
                    context.strokePath()
            
                    context.move(to: CGPoint(x: parameters.diameter / 2.0 - arrowHeadSize / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                    context.addLine(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
                    context.addLine(to: CGPoint(x: parameters.diameter / 2.0 + arrowHeadSize / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                    context.strokePath()
                case .Icon:
                    if let icon = parameters.theme.icon {
                        icon.draw(at: CGPoint(x: floor((parameters.diameter - icon.size.width) / 2.0), y: floor((parameters.diameter - icon.size.height) / 2.0)))
                    }
                case .Play:
                    context.setFillColor(parameters.theme.foregroundColor.cgColor)
                    
                    let size = CGSize(width: 15.0, height: 18.0)
                    context.translateBy(x: (parameters.diameter - size.width) / 2.0 + 1.5, y: (parameters.diameter - size.height) / 2.0)
                    if (parameters.diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 0.8, y: 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                    context.fillPath()
                    if (parameters.diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    context.translateBy(x: -(parameters.diameter - size.width) / 2.0 - 1.5, y: -(parameters.diameter - size.height) / 2.0)
                case .Pause:
                    context.setFillColor(parameters.theme.foregroundColor.cgColor)
                    
                    let size = CGSize(width: 15.0, height: 16.0)
                    context.translateBy(x: (parameters.diameter - size.width) / 2.0, y: (parameters.diameter - size.height) / 2.0)
                    if (parameters.diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 0.8, y: 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
                    context.fillPath()
                    if (parameters.diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    context.translateBy(x: -(parameters.diameter - size.width) / 2.0, y: -(parameters.diameter - size.height) / 2.0)
                case let .Image(image):
                    image.draw(at: CGPoint(x: floor((parameters.diameter - image.size.width) / 2.0), y: floor((parameters.diameter - image.size.height) / 2.0)))
            }
        }
    }
}
