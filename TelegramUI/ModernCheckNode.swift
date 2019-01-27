import Foundation
import AsyncDisplayKit
import Display
import LegacyComponents

struct CheckNodeTheme {
    let backgroundColor: UIColor
    let strokeColor: UIColor
    let borderColor: UIColor
    let hasShadow: Bool
}

enum CheckNodeContent {
    case check
    case counter(Int)
}

private final class CheckNodeParameters: NSObject {
    let theme: CheckNodeTheme
    let content: CheckNodeContent
    let animationProgress: CGFloat
    let selected: Bool

    init(theme: CheckNodeTheme, content: CheckNodeContent, animationProgress: CGFloat, selected: Bool) {
        self.theme = theme
        self.content = content
        self.animationProgress = animationProgress
        self.selected = selected
    }
}

class ModernCheckNode: ASDisplayNode {
    private var animationProgress: CGFloat = 0.0
    var theme: CheckNodeTheme {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(theme: CheckNodeTheme, content: CheckNodeContent = .check) {
        self.theme = theme
        self.content = content
    
        super.init()
        
        self.isOpaque = false
    }
    
    var content: CheckNodeContent {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var selected = false
    func setSelected(_ selected: Bool, animated: Bool = false) {
        guard self.selected != selected else {
            return
        }
        self.selected = selected
        
        if selected && animated {
            let animation = POPBasicAnimation()
            animation.property = POPAnimatableProperty.property(withName: "progress", initializer: { property in
                property?.readBlock = { node, values in
                    values?.pointee = (node as! ModernCheckNode).animationProgress
                }
                property?.writeBlock = { node, values in
                    (node as! ModernCheckNode).animationProgress = values!.pointee
                    (node as! ModernCheckNode).setNeedsDisplay()
                }
                property?.threshold = 0.01
            }) as! POPAnimatableProperty
            animation.fromValue = 0.0 as NSNumber
            animation.toValue = 1.0 as NSNumber
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            animation.duration = 0.21
            self.pop_add(animation, forKey: "progress")
        } else {
            self.pop_removeAllAnimations()
            self.animationProgress = selected ? 1.0 : 0.0
            self.setNeedsDisplay()
        }
    }
    
    func setHighlighted(_ highlighted: Bool, animated: Bool = false) {
        
    }

    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return CheckNodeParameters(theme: self.theme, content: self.content, animationProgress: self.animationProgress, selected: self.selected)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? CheckNodeParameters {
            let progress = parameters.animationProgress
            let diameter = bounds.width
            let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
            
            var borderWidth: CGFloat = 1.5
            if UIScreenScale == 3.0 {
                borderWidth = 5.0 / 3.0
            }
            
            context.setStrokeColor(parameters.theme.borderColor.cgColor)
            context.setLineWidth(borderWidth)
            context.strokeEllipse(in: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0))
            
            context.setFillColor(parameters.theme.backgroundColor.cgColor)
            context.fillEllipse(in: bounds.insetBy(dx: (diameter - borderWidth) * (1.0 - parameters.animationProgress), dy: (diameter - borderWidth) * (1.0 - parameters.animationProgress)))
            
            let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
            let s = CGPoint(x: center.x - 4.0, y: center.y + UIScreenPixel)
            let p1 = CGPoint(x: 3.0, y: 3.0)
            let p2 = CGPoint(x: 5.0, y: -6.0)
            
            if !firstSegment.isZero {
                if firstSegment < 1.0 {
                    context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                    context.addLine(to: s)
                } else {
                    let secondSegment = (progress - 0.33) * 1.5
                    context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                    context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                    context.addLine(to: s)
                }
            }
            
            context.setStrokeColor(parameters.theme.strokeColor.cgColor)
            if parameters.theme.strokeColor == .clear {
                context.setBlendMode(.clear)
            }
            context.setLineWidth(borderWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setMiterLimit(10.0)
            
            switch parameters.content {
                case .check:
                    break
                case let .counter(number):
                    break
            }
            
            context.strokePath()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
}
