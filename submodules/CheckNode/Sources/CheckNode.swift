import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents
import TelegramPresentationData

public struct CheckNodeTheme {
    public let backgroundColor: UIColor
    public let strokeColor: UIColor
    public let borderColor: UIColor
    public let overlayBorder: Bool
    public let hasInset: Bool
    public let hasShadow: Bool
    public let filledBorder: Bool
    public let borderWidth: CGFloat?
    
    public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.borderColor = borderColor
        self.overlayBorder = overlayBorder
        self.hasInset = hasInset
        self.hasShadow = hasShadow
        self.filledBorder = filledBorder
        self.borderWidth = borderWidth
    }
}

public extension CheckNodeTheme {
    enum Style {
        case plain
        case overlay
    }
    
    init(theme: PresentationTheme, style: Style, hasInset: Bool = false) {
        let borderColor: UIColor
        var hasInset = hasInset
        let overlayBorder: Bool
        let hasShadow: Bool
        switch style {
            case .plain:
                borderColor = theme.list.itemCheckColors.strokeColor
                overlayBorder = false
                hasShadow = false
            case .overlay:
                borderColor = UIColor(rgb: 0xffffff)
                hasInset = true
                overlayBorder = true
                hasShadow = true
        }

        self.init(backgroundColor: theme.list.itemCheckColors.fillColor, strokeColor: theme.list.itemCheckColors.foregroundColor, borderColor: borderColor, overlayBorder: overlayBorder, hasInset: hasInset, hasShadow: hasShadow)
    }
}

public enum CheckNodeContent {
    case check
    case counter(Int)
}

private final class CheckNodeParameters: NSObject {
    let theme: CheckNodeTheme
    let content: CheckNodeContent
    let animationProgress: CGFloat
    let selected: Bool
    let animatingOut: Bool

    init(theme: CheckNodeTheme, content: CheckNodeContent, animationProgress: CGFloat, selected: Bool, animatingOut: Bool) {
        self.theme = theme
        self.content = content
        self.animationProgress = animationProgress
        self.selected = selected
        self.animatingOut = animatingOut
    }
}

public class CheckNode: ASDisplayNode {
    private var animatingOut = false
    private var animationProgress: CGFloat = 0.0
    public var theme: CheckNodeTheme {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public init(theme: CheckNodeTheme, content: CheckNodeContent = .check) {
        self.theme = theme
        self.content = content
    
        super.init()
        
        self.isOpaque = false
    }
    
    public var content: CheckNodeContent {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public var selected = false
    public func setSelected(_ selected: Bool, animated: Bool = false) {
        guard self.selected != selected else {
            return
        }
        self.selected = selected
        
        if animated {
            self.animatingOut = !selected
            
            let animation = POPBasicAnimation()
            animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
                property?.readBlock = { node, values in
                    values?.pointee = (node as! CheckNode).animationProgress
                }
                property?.writeBlock = { node, values in
                    (node as! CheckNode).animationProgress = values!.pointee
                    (node as! CheckNode).setNeedsDisplay()
                }
                property?.threshold = 0.01
            }) as! POPAnimatableProperty)
            animation.fromValue = (selected ? 0.0 : 1.0) as NSNumber
            animation.toValue = (selected ? 1.0 : 0.0) as NSNumber
            animation.timingFunction = CAMediaTimingFunction(name: selected ? CAMediaTimingFunctionName.easeOut : CAMediaTimingFunctionName.easeIn)
            animation.duration = selected ? 0.21 : 0.15
            self.pop_add(animation, forKey: "progress")
        } else {
            self.pop_removeAllAnimations()
            self.animatingOut = false
            self.animationProgress = selected ? 1.0 : 0.0
            self.setNeedsDisplay()
        }
    }
    
    public func setHighlighted(_ highlighted: Bool, animated: Bool = false) {
    }

    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return CheckNodeParameters(theme: self.theme, content: self.content, animationProgress: self.animationProgress, selected: self.selected, animatingOut: self.animatingOut)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? CheckNodeParameters {
            let center = CGPoint(x: bounds.width / 2.0, y: bounds.width / 2.0)
            
            var borderWidth: CGFloat = 1.0 + UIScreenPixel
            if parameters.theme.hasInset {
                borderWidth = 1.5
            }
            if let customBorderWidth = parameters.theme.borderWidth {
                borderWidth = customBorderWidth
            }
            
            let checkWidth: CGFloat = 1.5
            
            let inset: CGFloat = parameters.theme.hasInset ? 2.0 - UIScreenPixel : 0.0
          
            let checkProgress = parameters.animatingOut ? 1.0 : parameters.animationProgress
            let fillProgress = parameters.animatingOut ? 1.0 : min(1.0, parameters.animationProgress * 1.35)
            
            context.setStrokeColor(parameters.theme.borderColor.cgColor)
            context.setLineWidth(borderWidth)
            
            let maybeScaleOut = {
                let animate: Bool
                if case .counter = parameters.content {
                    animate = true
                } else if parameters.animatingOut {
                    animate = true
                } else {
                    animate = false
                }
                if animate {
                    context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
                    context.scaleBy(x: parameters.animationProgress, y: parameters.animationProgress)
                    context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
                    
                    context.setAlpha(parameters.animationProgress)
                }
            }
                    
            let borderInset = borderWidth / 2.0 + inset
            let borderProgress: CGFloat = parameters.theme.filledBorder ? fillProgress : 1.0
            let borderFrame = bounds.insetBy(dx: borderInset, dy: borderInset)
            
            if parameters.theme.filledBorder {
                maybeScaleOut()
            }
            
            context.saveGState()
            if parameters.theme.hasShadow {
                context.setShadow(offset: CGSize(), blur: 2.5, color: UIColor(rgb: 0x000000, alpha: 0.22).cgColor)
            }
            
            context.strokeEllipse(in: borderFrame.insetBy(dx: borderFrame.width * (1.0 - borderProgress), dy: borderFrame.height * (1.0 - borderProgress)))
            context.restoreGState()

            if !parameters.theme.filledBorder {
                maybeScaleOut()
            }

            context.setFillColor(parameters.theme.backgroundColor.cgColor)

            let fillInset = parameters.theme.overlayBorder ? borderWidth + inset : inset
            let fillFrame = bounds.insetBy(dx: fillInset, dy: fillInset)
            context.fillEllipse(in: fillFrame.insetBy(dx: fillFrame.width * (1.0 - fillProgress), dy: fillFrame.height * (1.0 - fillProgress)))
            
            switch parameters.content {
                case .check:
                    let scale = (bounds.width - inset) / 18.0
                    let firstSegment: CGFloat = max(0.0, min(1.0, checkProgress * 3.0))
                    let s = CGPoint(x: center.x - (4.0 - 0.3333) * scale, y: center.y + 0.5 * scale)
                    let p1 = CGPoint(x: 2.5 * scale, y: 3.0 * scale)
                    let p2 = CGPoint(x: 4.6667 * scale, y: -6.0 * scale)
                    
                    if !firstSegment.isZero {
                        if firstSegment < 1.0 {
                            context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                            context.addLine(to: s)
                        } else {
                            let secondSegment = (checkProgress - 0.33) * 1.5
                            context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                            context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                            context.addLine(to: s)
                        }
                    }
                    
                    context.setStrokeColor(parameters.theme.strokeColor.cgColor)
                    if parameters.theme.strokeColor == .clear {
                        context.setBlendMode(.clear)
                    }
                    context.setLineWidth(checkWidth)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.setMiterLimit(10.0)
                    
                    context.strokePath()
                case let .counter(number):
                    let string = NSAttributedString(string: "\(number)", font: Font.with(size: 16.0, design: .round, weight: .semibold), textColor: parameters.theme.strokeColor)
                    let stringSize = string.boundingRect(with: bounds.size, options: .usesLineFragmentOrigin, context: nil).size
                    string.draw(at: CGPoint(x: floorToScreenPixels((bounds.width - stringSize.width) / 2.0), y: floorToScreenPixels((bounds.height - stringSize.height) / 2.0)))
            }
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
}

public class InteractiveCheckNode: CheckNode {
    private let buttonNode: HighlightTrackingButtonNode
    
    public var valueChanged: ((Bool) -> Void)?
    
    override public init(theme: CheckNodeTheme, content: CheckNodeContent = .check) {
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init(theme: theme, content: content)
        
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.layer.animateScale(from: 1.0, to: 0.85, duration: 0.15, removeOnCompletion: false)
            } else if let presentationLayer = strongSelf.layer.presentation() {
                strongSelf.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.setSelected(!self.selected, animated: true)
        self.valueChanged?(self.selected)
    }
    
    public override func layout() {
        super.layout()
        
        self.buttonNode.frame = self.bounds
    }
}

public class CheckLayer: CALayer {
    private var animatingOut = false
    private var animationProgress: CGFloat = 0.0
    public var theme: CheckNodeTheme {
        didSet {
            self.setNeedsDisplay()
        }
    }

    public init(theme: CheckNodeTheme, content: CheckNodeContent = .check) {
        self.theme = theme
        self.content = content

        super.init()

        self.isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    public var content: CheckNodeContent {
        didSet {
            self.setNeedsDisplay()
        }
    }

    public var selected = false
    public func setSelected(_ selected: Bool, animated: Bool = false) {
        guard self.selected != selected else {
            return
        }
        self.selected = selected

        if animated {
            self.animatingOut = !selected

            let animation = POPBasicAnimation()
            animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
                property?.readBlock = { node, values in
                    values?.pointee = (node as! CheckLayer).animationProgress
                }
                property?.writeBlock = { node, values in
                    (node as! CheckLayer).animationProgress = values!.pointee
                    (node as! CheckLayer).setNeedsDisplay()
                }
                property?.threshold = 0.01
            }) as! POPAnimatableProperty)
            animation.fromValue = (selected ? 0.0 : 1.0) as NSNumber
            animation.toValue = (selected ? 1.0 : 0.0) as NSNumber
            animation.timingFunction = CAMediaTimingFunction(name: selected ? CAMediaTimingFunctionName.easeOut : CAMediaTimingFunctionName.easeIn)
            animation.duration = selected ? 0.21 : 0.15
            self.pop_add(animation, forKey: "progress")
        } else {
            self.pop_removeAllAnimations()
            self.animatingOut = false
            self.animationProgress = selected ? 1.0 : 0.0
            self.setNeedsDisplay()
        }
    }

    public func setHighlighted(_ highlighted: Bool, animated: Bool = false) {
    }

    override public func display() {
        if self.bounds.isEmpty {
            return
        }
        self.contents = generateImage(self.bounds.size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            let parameters = CheckNodeParameters(theme: self.theme, content: self.content, animationProgress: self.animationProgress, selected: self.selected, animatingOut: self.animatingOut)

            let center = CGPoint(x: bounds.width / 2.0, y: bounds.width / 2.0)

            var borderWidth: CGFloat = 1.0 + UIScreenPixel
            if parameters.theme.hasInset {
                borderWidth = 1.5
            }
            if let customBorderWidth = parameters.theme.borderWidth {
                borderWidth = customBorderWidth
            }

            let checkWidth: CGFloat = 1.5

            let inset: CGFloat = parameters.theme.hasInset ? 2.0 - UIScreenPixel : 0.0

            let checkProgress = parameters.animatingOut ? 1.0 : parameters.animationProgress
            let fillProgress = parameters.animatingOut ? 1.0 : min(1.0, parameters.animationProgress * 1.35)

            context.setStrokeColor(parameters.theme.borderColor.cgColor)
            context.setLineWidth(borderWidth)

            let maybeScaleOut = {
                if parameters.animatingOut {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: parameters.animationProgress, y: parameters.animationProgress)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                    context.setAlpha(parameters.animationProgress)
                }
            }

            let borderInset = borderWidth / 2.0 + inset
            let borderProgress: CGFloat = parameters.theme.filledBorder ? fillProgress : 1.0
            let borderFrame = bounds.insetBy(dx: borderInset, dy: borderInset)

            if parameters.theme.filledBorder {
                maybeScaleOut()
            }

            context.saveGState()
            if parameters.theme.hasShadow {
                context.setShadow(offset: CGSize(), blur: 2.5, color: UIColor(rgb: 0x000000, alpha: 0.22).cgColor)
            }

            context.strokeEllipse(in: borderFrame.insetBy(dx: borderFrame.width * (1.0 - borderProgress), dy: borderFrame.height * (1.0 - borderProgress)))
            context.restoreGState()

            if !parameters.theme.filledBorder {
                maybeScaleOut()
            }

            context.setFillColor(parameters.theme.backgroundColor.cgColor)

            let fillInset = parameters.theme.overlayBorder ? borderWidth + inset : inset
            let fillFrame = bounds.insetBy(dx: fillInset, dy: fillInset)
            context.fillEllipse(in: fillFrame.insetBy(dx: fillFrame.width * (1.0 - fillProgress), dy: fillFrame.height * (1.0 - fillProgress)))

            switch parameters.content {
                case .check:
                    let scale = (bounds.width - inset) / 18.0
                    let firstSegment: CGFloat = max(0.0, min(1.0, checkProgress * 3.0))
                    let s = CGPoint(x: center.x - (4.0 - 0.3333) * scale, y: center.y + 0.5 * scale)
                    let p1 = CGPoint(x: 2.5 * scale, y: 3.0 * scale)
                    let p2 = CGPoint(x: 4.6667 * scale, y: -6.0 * scale)

                    if !firstSegment.isZero {
                        if firstSegment < 1.0 {
                            context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                            context.addLine(to: s)
                        } else {
                            let secondSegment = (checkProgress - 0.33) * 1.5
                            context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                            context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                            context.addLine(to: s)
                        }
                    }

                    context.setStrokeColor(parameters.theme.strokeColor.cgColor)
                    if parameters.theme.strokeColor == .clear {
                        context.setBlendMode(.clear)
                    }
                    context.setLineWidth(checkWidth)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.setMiterLimit(10.0)

                    context.strokePath()
                case let .counter(number):
                    let text = NSAttributedString(string: "\(number)", font: Font.with(size: 16.0, design: .round, weight: .regular, traits: []), textColor: parameters.theme.strokeColor)
                    text.draw(at: CGPoint())
            }
        })?.cgImage
    }
}
