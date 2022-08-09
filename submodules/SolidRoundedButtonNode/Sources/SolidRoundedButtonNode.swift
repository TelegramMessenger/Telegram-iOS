import Foundation
import UIKit
import AsyncDisplayKit
import Display
import HierarchyTrackingLayer

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

public final class SolidRoundedButtonTheme: Equatable {
    public let backgroundColor: UIColor
    public let gradientBackgroundColor: UIColor?
    public let foregroundColor: UIColor
    
    public init(backgroundColor: UIColor, gradientBackgroundColor: UIColor? = nil, foregroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.gradientBackgroundColor = gradientBackgroundColor
        self.foregroundColor = foregroundColor
    }
    
    public static func ==(lhs: SolidRoundedButtonTheme, rhs: SolidRoundedButtonTheme) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.gradientBackgroundColor != rhs.gradientBackgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        return true
    }
}

public enum SolidRoundedButtonFont {
    case bold
    case regular
}

public final class SolidRoundedButtonNode: ASDisplayNode {
    private var theme: SolidRoundedButtonTheme
    private var font: SolidRoundedButtonFont
    private var fontSize: CGFloat
    
    private let buttonBackgroundNode: ASDisplayNode
    private let buttonGlossView: SolidRoundedButtonGlossView?
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private var progressNode: ASImageNode?
    
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
    
    public var icon: UIImage? {
        didSet {
            self.iconNode.image = generateTintedImage(image: self.icon, color: self.theme.foregroundColor)
        }
    }
    
    public var iconSpacing: CGFloat = 8.0 {
        didSet {
            if let width = self.validLayout {
                _ = self.updateLayout(width: width, transition: .immediate)
            }
        }
    }
    
    public init(title: String? = nil, icon: UIImage? = nil, theme: SolidRoundedButtonTheme, font: SolidRoundedButtonFont = .bold, fontSize: CGFloat = 17.0, height: CGFloat = 48.0, cornerRadius: CGFloat = 24.0, gloss: Bool = false) {
        self.theme = theme
        self.font = font
        self.fontSize = fontSize
        self.buttonHeight = height
        self.buttonCornerRadius = cornerRadius
        self.title = title
        
        self.buttonBackgroundNode = ASDisplayNode()
        self.buttonBackgroundNode.clipsToBounds = true
        self.buttonBackgroundNode.backgroundColor = theme.backgroundColor
        self.buttonBackgroundNode.cornerRadius = cornerRadius
        
        if gloss {
            self.buttonGlossView = SolidRoundedButtonGlossView(color: theme.foregroundColor, cornerRadius: cornerRadius)
        } else {
            self.buttonGlossView = nil
        }
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: icon, color: self.theme.foregroundColor)
        
        super.init()
        
        self.addSubnode(self.buttonBackgroundNode)
        if let buttonGlossView = self.buttonGlossView {
            self.view.addSubview(buttonGlossView)
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
                    if strongSelf.buttonBackgroundNode.alpha > 0.0 {
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
    }
    
    public func transitionToProgress() {
        guard self.progressNode == nil else {
            return
        }
        
        self.isUserInteractionEnabled = false
        
        let buttonOffset = self.buttonBackgroundNode.frame.minX
        let buttonWidth = self.buttonBackgroundNode.frame.width
        
        let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(buttonOffset + (buttonWidth - self.buttonHeight) / 2.0), y: 0.0), size: CGSize(width: self.buttonHeight, height: self.buttonHeight))
        let progressNode = ASImageNode()
        progressNode.displaysAsynchronously = false
        progressNode.frame = progressFrame
        progressNode.image = generateIndefiniteActivityIndicatorImage(color: self.buttonBackgroundNode.backgroundColor ?? .clear, diameter: self.buttonHeight, lineWidth: 2.0 + UIScreenPixel)
        self.insertSubnode(progressNode, at: 0)
        self.progressNode = progressNode
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        basicAnimation.duration = 0.5
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        basicAnimation.beginTime = 1.0
        progressNode.layer.add(basicAnimation, forKey: "progressRotation")
        
        self.buttonBackgroundNode.cornerRadius = self.buttonHeight / 2.0
        self.buttonBackgroundNode.layer.animate(from: self.buttonCornerRadius as NSNumber, to: self.buttonHeight / 2.0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
        self.buttonBackgroundNode.layer.animateFrame(from: self.buttonBackgroundNode.frame, to: progressFrame, duration: 0.2)
        
        self.buttonBackgroundNode.alpha = 0.0
        self.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        progressNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
        
        self.titleNode.alpha = 0.0
        self.titleNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2)
        
        self.subtitleNode.alpha = 0.0
        self.subtitleNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.buttonBackgroundNode.layer.cornerCurve = .continuous
        }
    }
    
    public func updateTheme(_ theme: SolidRoundedButtonTheme) {
        guard theme !== self.theme else {
            return
        }
        self.theme = theme
        
        self.buttonBackgroundNode.backgroundColor = theme.backgroundColor
        self.buttonGlossView?.color = theme.foregroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: self.font == .bold ? Font.semibold(self.fontSize) : Font.regular(self.fontSize), textColor: theme.foregroundColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.subtitle ?? "", font: Font.regular(14.0), textColor: theme.foregroundColor)
        
        self.iconNode.image = generateTintedImage(image: self.iconNode.image, color: theme.foregroundColor)
        
        if let width = self.validLayout {
            _ = self.updateLayout(width: width, transition: .immediate)
        }
    }
    
    public func sizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.updateLayout(constrainedSize)
        return CGSize(width: titleSize.width + 20.0, height: self.buttonHeight)
    }
    
    public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return self.updateLayout(width: width, previousSubtitle: self.subtitle, transition: transition)
    }
    
    private func updateLayout(width: CGFloat, previousSubtitle: String?, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let buttonSize = CGSize(width: width, height: self.buttonHeight)
        let buttonFrame = CGRect(origin: CGPoint(), size: buttonSize)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        if let buttonGlossView = self.buttonGlossView {
            transition.updateFrame(view: buttonGlossView, frame: buttonFrame)
        }
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        if self.title != self.titleNode.attributedText?.string {
            self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: self.font == .bold ? Font.semibold(self.fontSize) : Font.regular(self.fontSize), textColor: self.theme.foregroundColor)
        }
        
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let titleSize = self.titleNode.updateLayout(buttonSize)
        
        let iconSpacing: CGFloat = self.iconSpacing
        
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
        let verticalInset: CGFloat = self.subtitle == nil ? floor((buttonFrame.height - titleSize.height) / 2.0) : floor((buttonFrame.height - titleSize.height) / 2.0) - spacingOffset
        
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

public final class SolidRoundedButtonView: UIView {
    private var theme: SolidRoundedButtonTheme
    private var font: SolidRoundedButtonFont
    private var fontSize: CGFloat
    
    private let buttonBackgroundNode: UIView
    private let buttonGlossView: SolidRoundedButtonGlossView?
    private let buttonNode: HighlightTrackingButton
    private let titleNode: ImmediateTextView
    private let subtitleNode: ImmediateTextView
    private let iconNode: UIImageView
    private var progressNode: UIImageView?
    
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
    
    public var icon: UIImage? {
        didSet {
            self.iconNode.image = generateTintedImage(image: self.icon, color: self.theme.foregroundColor)
        }
    }
    
    public var iconSpacing: CGFloat = 8.0 {
        didSet {
            if let width = self.validLayout {
                _ = self.updateLayout(width: width, transition: .immediate)
            }
        }
    }
    
    public init(title: String? = nil, icon: UIImage? = nil, theme: SolidRoundedButtonTheme, font: SolidRoundedButtonFont = .bold, fontSize: CGFloat = 17.0, height: CGFloat = 48.0, cornerRadius: CGFloat = 24.0, gloss: Bool = false) {
        self.theme = theme
        self.font = font
        self.fontSize = fontSize
        self.buttonHeight = height
        self.buttonCornerRadius = cornerRadius
        self.title = title
        
        self.buttonBackgroundNode = UIView()
        self.buttonBackgroundNode.clipsToBounds = true
        self.buttonBackgroundNode.backgroundColor = theme.backgroundColor
        self.buttonBackgroundNode.layer.cornerRadius = cornerRadius
        
        if gloss {
            self.buttonGlossView = SolidRoundedButtonGlossView(color: theme.foregroundColor, cornerRadius: cornerRadius)
        } else {
            self.buttonGlossView = nil
        }
        
        self.buttonNode = HighlightTrackingButton()
        
        self.titleNode = ImmediateTextView()
        self.titleNode.isUserInteractionEnabled = false
        
        self.subtitleNode = ImmediateTextView()
        self.subtitleNode.isUserInteractionEnabled = false
        
        self.iconNode = UIImageView()
        self.iconNode.image = generateTintedImage(image: icon, color: self.theme.foregroundColor)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.buttonBackgroundNode)
        if let buttonGlossView = self.buttonGlossView {
            self.addSubview(buttonGlossView)
        }
        self.addSubview(self.buttonNode)
        self.addSubview(self.titleNode)
        self.addSubview(self.subtitleNode)
        self.addSubview(self.iconNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
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
                    if strongSelf.buttonBackgroundNode.alpha > 0.0 {
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
        
        if #available(iOS 13.0, *) {
            self.buttonBackgroundNode.layer.cornerCurve = .continuous
        }
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func transitionToProgress() {
        guard self.progressNode == nil else {
            return
        }
        
        self.isUserInteractionEnabled = false
        
        let buttonOffset = self.buttonBackgroundNode.frame.minX
        let buttonWidth = self.buttonBackgroundNode.frame.width
        
        let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(buttonOffset + (buttonWidth - self.buttonHeight) / 2.0), y: 0.0), size: CGSize(width: self.buttonHeight, height: self.buttonHeight))
        let progressNode = UIImageView()
        progressNode.frame = progressFrame
        progressNode.image = generateIndefiniteActivityIndicatorImage(color: self.buttonBackgroundNode.backgroundColor ?? .clear, diameter: self.buttonHeight, lineWidth: 2.0 + UIScreenPixel)
        self.insertSubview(progressNode, at: 0)
        self.progressNode = progressNode
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        basicAnimation.duration = 0.5
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        basicAnimation.beginTime = 1.0
        progressNode.layer.add(basicAnimation, forKey: "progressRotation")
        
        self.buttonBackgroundNode.layer.cornerRadius = self.buttonHeight / 2.0
        self.buttonBackgroundNode.layer.animate(from: self.buttonCornerRadius as NSNumber, to: self.buttonHeight / 2.0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
        self.buttonBackgroundNode.layer.animateFrame(from: self.buttonBackgroundNode.frame, to: progressFrame, duration: 0.2)
        
        self.buttonBackgroundNode.alpha = 0.0
        self.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        progressNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
        
        self.titleNode.alpha = 0.0
        self.titleNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2)
        
        self.subtitleNode.alpha = 0.0
        self.subtitleNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2)
    }
    
    public func updateTheme(_ theme: SolidRoundedButtonTheme) {
        guard theme !== self.theme else {
            return
        }
        self.theme = theme
        
        self.buttonBackgroundNode.backgroundColor = theme.backgroundColor
        self.buttonGlossView?.color = theme.foregroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: self.font == .bold ? Font.semibold(self.fontSize) : Font.regular(self.fontSize), textColor: theme.foregroundColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.subtitle ?? "", font: Font.regular(14.0), textColor: theme.foregroundColor)
        
        self.iconNode.image = generateTintedImage(image: self.iconNode.image, color: theme.foregroundColor)
        
        if let width = self.validLayout {
            _ = self.updateLayout(width: width, transition: .immediate)
        }
    }
    
    public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return self.updateLayout(width: width, previousSubtitle: self.subtitle, transition: transition)
    }
    
    private func updateLayout(width: CGFloat, previousSubtitle: String?, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let buttonSize = CGSize(width: width, height: self.buttonHeight)
        let buttonFrame = CGRect(origin: CGPoint(), size: buttonSize)
        transition.updateFrame(view: self.buttonBackgroundNode, frame: buttonFrame)
        if let buttonGlossView = self.buttonGlossView {
            transition.updateFrame(view: buttonGlossView, frame: buttonFrame)
        }
        transition.updateFrame(view: self.buttonNode, frame: buttonFrame)
        
        if self.title != self.titleNode.attributedText?.string {
            self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: self.font == .bold ? Font.semibold(self.fontSize) : Font.regular(self.fontSize), textColor: self.theme.foregroundColor)
        }
        
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let titleSize = self.titleNode.updateLayout(buttonSize)
        
        let iconSpacing: CGFloat = self.iconSpacing
        
        var contentWidth: CGFloat = titleSize.width
        if !iconSize.width.isZero {
            contentWidth += iconSize.width + iconSpacing
        }
        var nextContentOrigin = floor((buttonFrame.width - contentWidth) / 2.0)
        transition.updateFrame(view: self.iconNode, frame: CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: floor((buttonFrame.height - iconSize.height) / 2.0)), size: iconSize))
        if !iconSize.width.isZero {
            nextContentOrigin += iconSize.width + iconSpacing
        }
        
        let spacingOffset: CGFloat = 9.0
        let verticalInset: CGFloat = self.subtitle == nil ? floor((buttonFrame.height - titleSize.height) / 2.0) : floor((buttonFrame.height - titleSize.height) / 2.0) - spacingOffset
        
        let titleFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + nextContentOrigin, y: buttonFrame.minY + verticalInset), size: titleSize)
        transition.updateFrame(view: self.titleNode, frame: titleFrame)
        
        if self.subtitle != self.subtitleNode.attributedText?.string {
            self.subtitleNode.attributedText = NSAttributedString(string: self.subtitle ?? "", font: Font.regular(14.0), textColor: self.theme.foregroundColor)
        }
        
        let subtitleSize = self.subtitleNode.updateLayout(buttonSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - subtitleSize.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - titleSize.height) / 2.0) + spacingOffset + 2.0), size: subtitleSize)
        transition.updateFrame(view: self.subtitleNode, frame: subtitleFrame)
        
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

private final class SolidRoundedButtonGlossViewParameters: NSObject {
    let gradientColors: NSArray?
    let cornerRadius: CGFloat
    let progress: CGFloat
    
    init(gradientColors: NSArray?, cornerRadius: CGFloat, progress: CGFloat) {
        self.gradientColors = gradientColors
        self.cornerRadius = cornerRadius
        self.progress = progress
    }
}

public final class SolidRoundedButtonGlossView: UIView {
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
    
    private let trackingLayer: HierarchyTrackingLayer
    
    public init(color: UIColor, cornerRadius: CGFloat) {
        self.color = color
        self.buttonCornerRadius = cornerRadius
        
        self.trackingLayer = HierarchyTrackingLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.trackingLayer)
        
        self.isOpaque = false
        
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
        
        self.trackingLayer.didEnterHierarchy = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animator?.isPaused = false
        }
        
        self.trackingLayer.didExitHierarchy = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animator?.isPaused = true
        }
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateGradientColors() {
        let transparentColor = self.color.withAlphaComponent(0.0).cgColor
        self.gradientColors = [transparentColor, transparentColor, self.color.withAlphaComponent(0.12).cgColor, transparentColor, transparentColor]
    }

    override public func draw(_ rect: CGRect) {
        let parameters = SolidRoundedButtonGlossViewParameters(gradientColors: self.gradientColors, cornerRadius: self.buttonCornerRadius, progress: self.progress)
        guard let gradientColors = parameters.gradientColors else {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()!
        
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
