import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let textFont: UIFont = Font.regular(16.0)

public final class SolidRoundedButtonTheme {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    
    public init(backgroundColor: UIColor, foregroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
}

public final class SolidRoundedButtonNode: ASDisplayNode {
    private var theme: SolidRoundedButtonTheme
    
    private let buttonBackgroundNode: ASImageNode
    private let buttonGlossNode: SolidRoundedButtonGlossNode
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    
    private let buttonHeight: CGFloat
    private let buttonCornerRadius: CGFloat
    
    public var pressed: (() -> Void)?
    public var validLayout: CGFloat?
    
    public var title: String? {
        didSet {
            if let width = self.validLayout {
                _ = self.updateLayout(width: width, transition: .immediate)
            }
        }
    }
    
    public var subtitle: String? {
        didSet {
            if let width = self.validLayout {
                _ = self.updateLayout(width: width, previousSubtitle: oldValue, transition: .immediate)
            }
        }
    }
    
    public init(title: String? = nil, icon: UIImage? = nil, theme: SolidRoundedButtonTheme, height: CGFloat = 48.0, cornerRadius: CGFloat = 24.0, gloss: Bool = false) {
        self.theme = theme
        self.buttonHeight = height
        self.buttonCornerRadius = cornerRadius
        self.title = title
        
        self.buttonBackgroundNode = ASImageNode()
        self.buttonBackgroundNode.isLayerBacked = true
        self.buttonBackgroundNode.displayWithoutProcessing = true
        self.buttonBackgroundNode.displaysAsynchronously = false
        self.buttonBackgroundNode.image = generateStretchableFilledCircleImage(radius: cornerRadius, color: theme.backgroundColor)
        
        self.buttonGlossNode = SolidRoundedButtonGlossNode(color: theme.foregroundColor, cornerRadius: cornerRadius)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = icon
        
        super.init()
        
        self.addSubnode(self.buttonBackgroundNode)
        if gloss {
            self.addSubnode(self.buttonGlossNode)
        }
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.iconNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackgroundNode.alpha = 0.55
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.55
                    strongSelf.subtitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.subtitleNode.alpha = 0.55
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.55
                } else {
                    strongSelf.buttonBackgroundNode.alpha = 1.0
                    strongSelf.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                    strongSelf.subtitleNode.alpha = 1.0
                    strongSelf.subtitleNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    public func updateTheme(_ theme: SolidRoundedButtonTheme) {
        guard theme !== self.theme else {
            return
        }
        self.theme = theme
        
        self.buttonBackgroundNode.image = generateStretchableFilledCircleImage(radius: self.buttonCornerRadius, color: theme.backgroundColor)
        self.buttonGlossNode.color = theme.foregroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.semibold(17.0), textColor: theme.foregroundColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.subtitle ?? "", font: Font.regular(14.0), textColor: theme.foregroundColor)
    }
    
    public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return self.updateLayout(width: width, previousSubtitle: nil, transition: transition)
    }
    
    private func updateLayout(width: CGFloat, previousSubtitle: String?, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let buttonSize = CGSize(width: width, height: self.buttonHeight)
        let buttonFrame = CGRect(origin: CGPoint(), size: buttonSize)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonGlossNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        if self.title != self.titleNode.attributedText?.string {
            self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.semibold(17.0), textColor: self.theme.foregroundColor)
        }
        
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let titleSize = self.titleNode.updateLayout(buttonSize)
        
        let iconSpacing: CGFloat = 8.0
        
        var contentWidth: CGFloat = titleSize.width
        if !iconSize.width.isZero {
            contentWidth += iconSize.width + iconSpacing
        }
        var nextContentOrigin = floor((buttonFrame.width - contentWidth) / 2.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: floor((buttonFrame.height - iconSize.height) / 2.0)), size: iconSize))
        if !iconSize.width.isZero {
            nextContentOrigin += iconSize.width + iconSpacing
        }
        
        let spacingOffset: CGFloat = 9.0
        var verticalInset: CGFloat = self.subtitle == nil ? floor((buttonFrame.height - titleSize.height) / 2.0) : floor((buttonFrame.height - titleSize.height) / 2.0) - spacingOffset
        
        let titleFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: buttonFrame.minY + verticalInset), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        if self.subtitle != self.subtitleNode.attributedText?.string {
            self.subtitleNode.attributedText = NSAttributedString(string: self.subtitle ?? "", font: Font.regular(14.0), textColor: self.theme.foregroundColor)
        }
        
        let subtitleSize = self.subtitleNode.updateLayout(buttonSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - subtitleSize.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - titleSize.height) / 2.0) + spacingOffset + 2.0), size: subtitleSize)
        transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        
        if previousSubtitle == nil && self.subtitle != nil {
            self.titleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: spacingOffset / 2.0), to: CGPoint(), duration: 0.3, additive: true)
            self.subtitleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -spacingOffset / 2.0), to: CGPoint(), duration: 0.3, additive: true)
            self.subtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        return buttonSize.height
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
}

private final class SolidRoundedButtonGlossNodeParameters: NSObject {
    let gradientColors: NSArray?
    let cornerRadius: CGFloat
    let progress: CGFloat
    
    init(gradientColors: NSArray?, cornerRadius: CGFloat, progress: CGFloat) {
        self.gradientColors = gradientColors
        self.cornerRadius = cornerRadius
        self.progress = progress
    }
}

public final class SolidRoundedButtonGlossNode: ASDisplayNode {
    public var color: UIColor {
        didSet {
            self.updateGradientColors()
            self.setNeedsDisplay()
        }
    }
    private var progress: CGFloat = 0.0
    private var animator: ConstantDisplayLinkAnimator?
    private let buttonCornerRadius: CGFloat
    private var gradientColors: NSArray?
    
    public init(color: UIColor, cornerRadius: CGFloat) {
        self.color = color
        self.buttonCornerRadius = cornerRadius
        
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
        
        var previousTime: CFAbsoluteTime?
        self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let currentTime = CFAbsoluteTimeGetCurrent()
            if let previousTime = previousTime {
                var delta: CGFloat
                if strongSelf.progress < 0.05 || strongSelf.progress > 0.95 {
                    delta = 0.001
                } else {
                    delta = 0.009
                }
                delta *= CGFloat(currentTime - previousTime) * 60.0
                var newProgress = strongSelf.progress + delta
                if newProgress > 1.0 {
                    newProgress = 0.0
                }
                strongSelf.progress = newProgress
                strongSelf.setNeedsDisplay()
            }
            previousTime = currentTime
        })
        
        self.updateGradientColors()
    }
    
    private func updateGradientColors() {
        let transparentColor = self.color.withAlphaComponent(0.0).cgColor
        self.gradientColors = [transparentColor, transparentColor, self.color.withAlphaComponent(0.12).cgColor, transparentColor, transparentColor]
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        self.animator?.isPaused = false
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        self.animator?.isPaused = true
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return SolidRoundedButtonGlossNodeParameters(gradientColors: self.gradientColors, cornerRadius: self.buttonCornerRadius, progress: self.progress)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? SolidRoundedButtonGlossNodeParameters, let gradientColors = parameters.gradientColors {
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: parameters.cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
            
            var locations: [CGFloat] = [0.0, 0.15, 0.5, 0.85, 1.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
            
            let x = -4.0 * bounds.size.width + 8.0 * bounds.size.width * parameters.progress
            context.drawLinearGradient(gradient, start: CGPoint(x: x, y: 0.0), end: CGPoint(x: x + bounds.size.width, y: 0.0), options: CGGradientDrawingOptions())
        }
    }
}
