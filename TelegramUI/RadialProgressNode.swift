import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display

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
    let theme: RadialProgressTheme
    
    var state: RadialProgressState = .None {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(theme: RadialProgressTheme) {
        self.theme = theme
        
        super.init()
        
        self.isOpaque = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialProgressOverlayParameters(theme: self.theme, diameter: self.frame.size.width, state: self.state)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: @escaping  asdisplaynode_iscancelled_block_t, isRasterizing: Bool) {
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
                case .None, .Remote, .Play:
                    break
                case let .Fetching(progress):
                    let startAngle = -CGFloat(M_PI_2)
                    let endAngle = 2.0 * (CGFloat(M_PI)) * CGFloat(progress) - CGFloat(M_PI_2)
                    
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
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        basicAnimation.duration = 2.0
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float(M_PI * 2.0))
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
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
}

public struct RadialProgressTheme {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let icon: UIImage?
}

class RadialProgressNode: ASControlNode {
    private let theme: RadialProgressTheme
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
                    self.overlay.removeFromSupernode()
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
            }
        }
    }
    
    convenience override init() {
        self.init(theme: RadialProgressTheme(backgroundColor: UIColor(white: 0.0, alpha: 0.6), foregroundColor: UIColor.white, icon: nil))
    }
    
    init(theme: RadialProgressTheme) {
        self.theme = theme
        self.overlay = RadialProgressOverlayNode(theme: theme)
        
        super.init()
        
        self.isOpaque = false
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
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: @escaping asdisplaynode_iscancelled_block_t, isRasterizing: Bool) {
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
                case .Play:
                    if let icon = parameters.theme.icon {
                        icon.draw(at: CGPoint(x: floor((parameters.diameter - icon.size.width) / 2.0), y: floor((parameters.diameter - icon.size.height) / 2.0)))
                    }
            }
        }
    }
}
