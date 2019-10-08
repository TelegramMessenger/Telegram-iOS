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
    private let labelNode: ImmediateTextNode
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
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.isUserInteractionEnabled = false
        
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
        self.addSubnode(self.labelNode)
        self.addSubnode(self.iconNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackgroundNode.alpha = 0.55
                } else {
                    strongSelf.buttonBackgroundNode.alpha = 1.0
                    strongSelf.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
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
        self.labelNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.semibold(17.0), textColor: theme.foregroundColor)
    }
    
    public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let buttonSize = CGSize(width: width, height: self.buttonHeight)
        let buttonFrame = CGRect(origin: CGPoint(), size: buttonSize)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonGlossNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        if self.title != self.labelNode.attributedText?.string {
            self.labelNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.semibold(17.0), textColor: self.theme.foregroundColor)
        }
        
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let labelSize = self.labelNode.updateLayout(buttonSize)
        
        let iconSpacing: CGFloat = 8.0
        
        var contentWidth: CGFloat = labelSize.width
        if !iconSize.width.isZero {
            contentWidth += iconSize.width + iconSpacing
        }
        var nextContentOrigin = floor((buttonFrame.width - contentWidth) / 2.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: floor((buttonFrame.height - iconSize.height) / 2.0)), size: iconSize))
        if !iconSize.width.isZero {
            nextContentOrigin += iconSize.width + iconSpacing
        }
        
        let labelFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: buttonFrame.minY + floor((buttonFrame.height - labelSize.height) / 2.0)), size: labelSize)
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
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
    private var displayLink: CADisplayLink?
    private let buttonCornerRadius: CGFloat
    private var gradientColors: NSArray?
    
    public init(color: UIColor, cornerRadius: CGFloat) {
        self.color = color
        self.buttonCornerRadius = cornerRadius
        
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
        
        class DisplayLinkProxy: NSObject {
            weak var target: SolidRoundedButtonGlossNode?
            init(target: SolidRoundedButtonGlossNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink?.isPaused = true
        self.displayLink?.add(to: RunLoop.main, forMode: .common)
        
        self.updateGradientColors()
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    private func updateGradientColors() {
        let transparentColor = self.color.withAlphaComponent(0.0).cgColor
        self.gradientColors = [transparentColor, transparentColor, self.color.withAlphaComponent(0.12).cgColor, transparentColor, transparentColor]
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        self.displayLink?.isPaused = false
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        self.displayLink?.isPaused = true
    }
    
    private func displayLinkEvent() {
        let delta: CGFloat
        if self.progress < 0.05 || self.progress > 0.95 {
            delta = 0.001
        } else {
            delta = 0.009
        }
        var newProgress = self.progress + delta
        if newProgress > 1.0 {
            newProgress = 0.0
        }
        self.progress = newProgress
        self.setNeedsDisplay()
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
