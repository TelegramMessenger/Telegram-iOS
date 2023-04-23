import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents
import TelegramPresentationData

public struct CheckNodeTheme {
    public var backgroundColor: UIColor
    public var strokeColor: UIColor
    public var borderColor: UIColor
    public var overlayBorder: Bool
    public var hasInset: Bool
    public var hasShadow: Bool
    public var filledBorder: Bool
    public var borderWidth: CGFloat?
    public var isDottedBorder: Bool
    
    public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil, isDottedBorder: Bool = false) {
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.borderColor = borderColor
        self.overlayBorder = overlayBorder
        self.hasInset = hasInset
        self.hasShadow = hasShadow
        self.filledBorder = filledBorder
        self.borderWidth = borderWidth
        self.isDottedBorder = isDottedBorder
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
            
            if selected {
                self.layer.animateScale(from: 1.0, to: 0.9, duration: 0.08, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.layer.animateScale(from: 0.9, to: 1.1, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.layer.animateScale(from: 1.1, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                })
            } else {
                self.layer.animateScale(from: 1.0, to: 0.9, duration: 0.08, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.layer.animateScale(from: 0.9, to: 1.0, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                })
            }
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
            CheckLayer.drawContents(
                context: context,
                size: bounds.size,
                parameters: parameters
            )
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

    public override init() {
        self.theme = CheckNodeTheme(backgroundColor: .white, strokeColor: .blue, borderColor: .white, overlayBorder: false, hasInset: false, hasShadow: false)
        self.content = .check
        
        super.init()
        
        self.isOpaque = false
    }
    
    public override init(layer: Any) {
        guard let layer = layer as? CheckLayer else {
            preconditionFailure()
        }
        
        self.theme = layer.theme
        self.content = layer.content
        
        super.init(layer: layer)
        
        self.isOpaque = false
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
            
            if selected {
                self.animateScale(from: 1.0, to: 0.9, duration: 0.08, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.animateScale(from: 0.9, to: 1.1, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.animateScale(from: 1.1, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                })
            } else {
                self.animateScale(from: 1.0, to: 0.9, duration: 0.08, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.animateScale(from: 0.9, to: 1.0, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                })
            }
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
            CheckLayer.drawContents(
                context: context,
                size: size,
                parameters: CheckNodeParameters(theme: self.theme, content: self.content, animationProgress: self.animationProgress, selected: self.selected, animatingOut: self.animatingOut)
            )
        })?.cgImage
    }
    
    fileprivate static func drawContents(context: CGContext, size: CGSize, parameters: CheckNodeParameters) {
        context.clear(CGRect(origin: CGPoint(), size: size))

        let center = CGPoint(x: size.width / 2.0, y: size.width / 2.0)

        var borderWidth: CGFloat = 1.0 + UIScreenPixel
        if parameters.theme.hasInset {
            borderWidth = 1.5
        }
        if let customBorderWidth = parameters.theme.borderWidth {
            borderWidth = customBorderWidth
        }

        let checkWidth: CGFloat = 1.5

        let inset: CGFloat = parameters.theme.hasInset ? 2.0 - UIScreenPixel : 0.0

        let checkProgress: CGFloat

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

        if !parameters.theme.filledBorder && !parameters.theme.hasShadow && !parameters.theme.overlayBorder {
            if parameters.theme.isDottedBorder {
                checkProgress = 0.0
                let borderInset = borderWidth / 2.0 + inset
                let borderFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: borderInset, dy: borderInset)
                context.setLineDash(phase: -6.4, lengths: [4.0, 4.0])
                context.strokeEllipse(in: borderFrame)
            } else {
                checkProgress = parameters.animationProgress
                
                let fillProgress: CGFloat = parameters.animationProgress
                
                context.setFillColor(parameters.theme.backgroundColor.mixedWith(parameters.theme.borderColor, alpha: 1.0 - fillProgress).cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                let innerDiameter: CGFloat = (fillProgress * 0.0) + (1.0 - fillProgress) * (size.width - borderWidth * 2.0)
                
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: (size.width - innerDiameter) * 0.5, y: (size.height - innerDiameter) * 0.5), size: CGSize(width: innerDiameter, height: innerDiameter)))
                context.setBlendMode(.normal)
            }
        } else {
            checkProgress = parameters.animatingOut ? 1.0 : parameters.animationProgress
            
            let fillProgress = parameters.animatingOut ? 1.0 : min(1.0, parameters.animationProgress * 1.35)
            
            let borderInset = borderWidth / 2.0 + inset
            let borderProgress: CGFloat = parameters.theme.filledBorder ? fillProgress : 1.0
            let borderFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: borderInset, dy: borderInset)
            
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
            let fillFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: fillInset, dy: fillInset)
            context.fillEllipse(in: fillFrame.insetBy(dx: fillFrame.width * (1.0 - fillProgress), dy: fillFrame.height * (1.0 - fillProgress)))
        }

        switch parameters.content {
            case .check:
                let scale = (size.width - inset) / 18.0
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
                let fontSize: CGFloat
                let string = "\(number)"
                switch string.count {
                case 1:
                    fontSize = 16.0
                case 2:
                    fontSize = 15.0
                default:
                    fontSize = 13.0
                }
                let text = NSAttributedString(string: string, font: Font.with(size: fontSize, design: .round, weight: .medium, traits: []), textColor: parameters.theme.strokeColor.withMultipliedAlpha(parameters.animationProgress))
                let textRect = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                text.draw(at: CGPoint(x: textRect.minX + floorToScreenPixels((size.width - textRect.width) * 0.5), y: textRect.minY + floorToScreenPixels((size.height - textRect.height) * 0.5)))
        }
    }
}
