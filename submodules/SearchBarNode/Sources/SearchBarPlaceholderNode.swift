import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import ComponentFlow
import GlassBackgroundComponent
import ComponentDisplayAdapters

private let templateLoupeIcon = UIImage(bundleImageName: "Components/Search Bar/Loupe")

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: templateLoupeIcon, color: color)
}

private class SearchBarPlaceholderNodeLayer: CALayer {
}

private class SearchBarPlaceholderNodeView: UIView {
    override static var layerClass: AnyClass {
        return SearchBarPlaceholderNodeLayer.self
    }
}

public final class SearchBarPlaceholderContentView: UIView {
    private struct Params {
        var placeholderString: NSAttributedString?
        var compactPlaceholderString: NSAttributedString?
        var constrainedSize: CGSize
        var expansionProgress: CGFloat
        var iconColor: UIColor
        var foregroundColor: UIColor
        var backgroundColor: UIColor
        var controlColor: UIColor
        var isActive: Bool
        var additionalPlaceholderInset: CGFloat
        var preferClearGlass: Bool
        
        init(placeholderString: NSAttributedString?, compactPlaceholderString: NSAttributedString?, constrainedSize: CGSize, expansionProgress: CGFloat, iconColor: UIColor, foregroundColor: UIColor, backgroundColor: UIColor, controlColor: UIColor, isActive: Bool, additionalPlaceholderInset: CGFloat, preferClearGlass: Bool) {
            self.placeholderString = placeholderString
            self.compactPlaceholderString = compactPlaceholderString
            self.constrainedSize = constrainedSize
            self.expansionProgress = expansionProgress
            self.iconColor = iconColor
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
            self.controlColor = controlColor
            self.isActive = isActive
            self.additionalPlaceholderInset = additionalPlaceholderInset
            self.preferClearGlass = preferClearGlass
        }
    }
    
    let fieldStyle: SearchBarStyle
    let plainBackgroundView: UIImageView
    let glassBackgroundView: GlassBackgroundView?
    private var fillBackgroundColor: UIColor
    private var foregroundColor: UIColor
    private var iconColor: UIColor
    let iconNode: ASImageNode
    let labelNode: TextNode
    let plainIconNode: ASImageNode
    let plainLabelNode: TextNode
    
    private var close: (background: GlassBackgroundView, icon: UIImageView)?
    
    private(set) var placeholderString: NSAttributedString?
    
    private var params: Params?
    
    public var onCancel: (() -> Void)?
    
    init(fieldStyle: SearchBarStyle) {
        self.fieldStyle = fieldStyle
        
        self.fillBackgroundColor = UIColor.white
        self.foregroundColor = UIColor(rgb: 0xededed)
        self.iconColor = UIColor(rgb: 0x000000, alpha: 0.0)
        
        self.plainBackgroundView = UIImageView()
        
        switch fieldStyle {
        case .legacy, .modern:
            self.glassBackgroundView = nil
        case .inlineNavigation, .glass:
            self.glassBackgroundView = GlassBackgroundView()
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isOpaque = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.plainIconNode = ASImageNode()
        self.plainIconNode.displaysAsynchronously = false
        self.plainIconNode.displayWithoutProcessing = true
        
        self.plainLabelNode = TextNode()
        self.plainLabelNode.isOpaque = false
        self.plainLabelNode.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.plainBackgroundView.isUserInteractionEnabled = true
        self.addSubview(self.plainBackgroundView)
        
        self.plainBackgroundView.addSubview(self.plainIconNode.view)
        self.plainBackgroundView.addSubview(self.plainLabelNode.view)
        
        if let glassBackgroundView = self.glassBackgroundView {
            self.addSubview(glassBackgroundView)
            
            glassBackgroundView.contentView.addSubview(self.iconNode.view)
            glassBackgroundView.contentView.addSubview(self.labelNode.view)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onCloseTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.onCancel?()
        }
    }
    
    func updateLayout(
        placeholderString: NSAttributedString?,
        compactPlaceholderString: NSAttributedString?,
        constrainedSize: CGSize,
        expansionProgress: CGFloat,
        iconColor: UIColor,
        foregroundColor: UIColor,
        backgroundColor: UIColor,
        controlColor: UIColor,
        preferClearGlass: Bool,
        transition: ContainedViewLayoutTransition
    ) -> CGFloat {
        let params = Params(
            placeholderString: placeholderString,
            compactPlaceholderString: compactPlaceholderString,
            constrainedSize: constrainedSize,
            expansionProgress: expansionProgress,
            iconColor: iconColor,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            controlColor: controlColor,
            isActive: false,
            additionalPlaceholderInset: 0.0,
            preferClearGlass: preferClearGlass
        )
        self.params = params
        return self.updateLayout(params: params, transition: transition)
    }
    
    public func update(size: CGSize, isActive: Bool, additionalPlaceholderInset: CGFloat, transition: ContainedViewLayoutTransition) {
        guard var params = self.params else {
            return
        }
        params.constrainedSize = size
        params.expansionProgress = 1.0
        params.isActive = isActive
        params.additionalPlaceholderInset = additionalPlaceholderInset
        let _ = self.updateLayout(params: params, transition: transition)
    }
    
    private func updateLayout(params: Params, transition: ContainedViewLayoutTransition) -> CGFloat {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let plainLabelLayout = TextNode.asyncLayout(self.plainLabelNode)
        let currentForegroundColor = self.foregroundColor
        let currentIconColor = self.iconColor
        
        let placeholderString: NSAttributedString?
        if params.constrainedSize.width < 350.0 {
            placeholderString = params.compactPlaceholderString
        } else {
            placeholderString = params.placeholderString
        }
        
        let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: placeholderString, backgroundColor: .clear, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: params.constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (_, plainLabelApply) = plainLabelLayout(TextNodeLayoutArguments(attributedString: placeholderString, backgroundColor: .clear, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: params.constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        var updatedColor: UIColor?
        var updatedIconImage: UIImage?
        if !currentForegroundColor.isEqual(params.foregroundColor) {
            updatedColor = params.foregroundColor
        }
        if !currentIconColor.isEqual(params.iconColor) {
            updatedIconImage = generateLoupeIcon(color: params.iconColor)
        }
        
        let height = params.constrainedSize.height * params.expansionProgress
        
        let _ = labelApply()
        let _ = plainLabelApply()
        
        self.fillBackgroundColor = params.backgroundColor
        self.foregroundColor = params.foregroundColor
        self.iconColor = params.iconColor
        self.plainBackgroundView.isUserInteractionEnabled = params.expansionProgress > 0.9999
        
        if let updatedColor {
            self.plainBackgroundView.backgroundColor = updatedColor
        }
        if let updatedIconImage {
            self.iconNode.image = updatedIconImage
            self.plainIconNode.image = updatedIconImage
        }
        
        self.placeholderString = placeholderString
        
        var iconSize = CGSize()
        var totalWidth = labelLayoutResult.size.width
        
        var spacing: CGFloat = 4.0
        if params.isActive {
            spacing = 2.0
        }
        
        let iconX: CGFloat
        if let iconImage = self.iconNode.image {
            iconSize = iconImage.size
            totalWidth += iconSize.width + spacing
            if params.isActive {
                iconX = 8.0
            } else {
                iconX = floor((params.constrainedSize.width - totalWidth) / 2.0)
            }
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: iconX, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
            transition.updateFrame(node: self.plainIconNode, frame: CGRect(origin: CGPoint(x: iconX, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
        } else {
            iconX = 12.0
        }
        var textOffset: CGFloat = 0.0
        if params.constrainedSize.height >= 36.0 {
            textOffset += 1.0
        }
        let labelX: CGFloat = iconX + iconSize.width + spacing + params.additionalPlaceholderInset
        let labelFrame = CGRect(origin: CGPoint(x: labelX, y: floorToScreenPixels((height - labelLayoutResult.size.height) / 2.0) + textOffset), size: labelLayoutResult.size)
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        transition.updateFrame(node: self.plainLabelNode, frame: labelFrame)
   
        var innerAlpha = max(0.0, params.expansionProgress - 0.77) / 0.23
        if innerAlpha > 0.9999 {
            innerAlpha = 1.0
        } else if innerAlpha < 0.0001 {
            innerAlpha = 0.0
        }
        if self.labelNode.alpha != innerAlpha {
            if !transition.isAnimated {
                self.labelNode.layer.removeAnimation(forKey: "opacity")
                self.iconNode.layer.removeAnimation(forKey: "opacity")
                self.plainLabelNode.layer.removeAnimation(forKey: "opacity")
                self.plainIconNode.layer.removeAnimation(forKey: "opacity")
            }
            
            transition.updateAlpha(node: self.labelNode, alpha: innerAlpha)
            transition.updateAlpha(node: self.iconNode, alpha: innerAlpha)
            
            transition.updateAlpha(node: self.plainLabelNode, alpha: innerAlpha)
            transition.updateAlpha(node: self.plainIconNode, alpha: innerAlpha)
        }
        
        let outerAlpha = min(0.3, params.expansionProgress) / 0.3
        let cornerRadius = height * 0.5
        
        if self.plainBackgroundView.layer.cornerRadius != cornerRadius {
            if !transition.isAnimated {
                self.plainBackgroundView.layer.removeAnimation(forKey: "cornerRadius")
            }
            transition.updateCornerRadius(layer: self.plainBackgroundView.layer, cornerRadius: cornerRadius)
        }
        
        var plainBackgroundAlpha = outerAlpha
        if params.isActive {
            plainBackgroundAlpha = 0.0
        }
        if self.plainBackgroundView.alpha != plainBackgroundAlpha {
            if !transition.isAnimated {
                self.plainBackgroundView.layer.removeAnimation(forKey: "opacity")
            }
            transition.updateAlpha(layer: self.plainBackgroundView.layer, alpha: plainBackgroundAlpha)
        }
        
        var backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: params.constrainedSize.width, height: height))
        if params.isActive {
            backgroundFrame.size.width -= 44.0 + 8.0
        }
        
        if self.plainBackgroundView.frame != backgroundFrame {
            if !transition.isAnimated {
                self.plainBackgroundView.layer.removeAnimation(forKey: "position")
                self.plainBackgroundView.layer.removeAnimation(forKey: "bounds")
            }
            transition.updateFrame(view: self.plainBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: params.constrainedSize.width, height: height)))
        }
        
        if let glassBackgroundView = self.glassBackgroundView {
            transition.updatePosition(layer: glassBackgroundView.layer, position: backgroundFrame.center)
            transition.updateBounds(layer: glassBackgroundView.layer, bounds: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            var backgroundAlpha: CGFloat = 1.0
            if backgroundFrame.height < 16.0 {
                backgroundAlpha = max(0.0, min(1.0, backgroundFrame.height / 16.0))
            }
            if !params.isActive {
                backgroundAlpha = 0.0
            }
            ComponentTransition(transition).setAlpha(view: glassBackgroundView, alpha: backgroundAlpha)
            let isDark = params.backgroundColor.hsb.b < 0.5
            if params.isActive {
                glassBackgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: isDark, tintColor: .init(kind: params.preferClearGlass ? .clear : .panel), isInteractive: true, transition: ComponentTransition(transition))
            }
            
            if params.isActive {
                let transition = ComponentTransition(transition)
                
                let closeFrame = CGRect(origin: CGPoint(x: params.constrainedSize.width - 44.0, y: 0.0), size: CGSize(width: 44.0, height: 44.0))
                
                let close: (background: GlassBackgroundView, icon: UIImageView)
                var closeTransition = transition
                if let current = self.close {
                    close = current
                } else {
                    closeTransition = closeTransition.withAnimation(.none)
                    close = (GlassBackgroundView(), UIImageView())
                    self.close = close
                    
                    close.icon.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        context.setLineWidth(2.0)
                        context.setLineCap(.round)
                        context.setStrokeColor(UIColor.white.cgColor)
                        
                        context.beginPath()
                        context.move(to: CGPoint(x: 12.0, y: 12.0))
                        context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
                        context.move(to: CGPoint(x: size.width - 12.0, y: 12.0))
                        context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
                        context.strokePath()
                    })?.withRenderingMode(.alwaysTemplate)
                    
                    close.background.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onCloseTapGesture(_:))))
                    
                    close.background.contentView.addSubview(close.icon)
                    self.insertSubview(close.background, at: 0)
                    
                    if let image = close.icon.image {
                        close.icon.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size))
                    }
                    
                    close.background.frame = closeFrame.offsetBy(dx: closeFrame.width + 40.0, dy: 0.0)
                    let isDark = params.backgroundColor.hsb.b < 0.5
                    close.background.update(size: close.background.bounds.size, cornerRadius: close.background.bounds.height * 0.5, isDark: isDark, tintColor: .init(kind: params.preferClearGlass ? .clear : .panel), isInteractive: true, transition: .immediate)
                    ComponentTransition.immediate.setScale(view: close.background, scale: 0.001)
                }
                
                close.icon.tintColor = params.controlColor
                
                transition.setPosition(view: close.background, position: closeFrame.center)
                transition.setBounds(view: close.background, bounds: CGRect(origin: CGPoint(), size: closeFrame.size))
                transition.setScale(view: close.background, scale: 1.0)
                
                if let image = close.icon.image {
                    transition.setFrame(view: close.icon, frame: image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size)))
                }
                
                let isDark = params.backgroundColor.hsb.b < 0.5
                close.background.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: isDark, tintColor: .init(kind: params.preferClearGlass ? .clear : .panel), isInteractive: true, transition: closeTransition)
            } else {
                let transition = ComponentTransition(transition)
                
                if let close = self.close {
                    self.close = nil
                    let closeBackground = close.background
                    let closeFrame = CGRect(origin: CGPoint(x: params.constrainedSize.width - 44.0, y: 0.0), size: CGSize(width: 44.0, height: 44.0)).offsetBy(dx: 44.0 + 40.0, dy: 0.0)
                    transition.setPosition(view: closeBackground, position: closeFrame.center)
                    transition.setBounds(view: closeBackground, bounds: CGRect(origin: CGPoint(), size: closeFrame.size))
                    let isDark = params.backgroundColor.hsb.b < 0.5
                    closeBackground.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: isDark, tintColor: .init(kind: params.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)
                    transition.setScale(view: closeBackground, scale: 0.001, completion: { [weak closeBackground] _ in
                        closeBackground?.removeFromSuperview()
                    })
                }
            }
        }
        
        /*if let accessoryComponentContainer = self.accessoryComponentContainer {
            accessoryComponentContainer.frame = CGRect(origin: CGPoint(x: constrainedSize.width - accessoryComponentContainer.bounds.width - 4.0, y: floor((constrainedSize.height * expansionProgress - accessoryComponentContainer.bounds.height) / 2.0)), size: accessoryComponentContainer.bounds.size)
            transition.updateAlpha(layer: accessoryComponentContainer.layer, alpha: innerAlpha)
        }*/
        
        return height
    }
    
    public func updatePlaceholderVisibility(isVisible: Bool) {
        self.labelNode.isHidden = !isVisible
        self.plainLabelNode.isHidden = !isVisible
    }
    
    public func updateSearchIconVisibility(isVisible: Bool) {
        self.iconNode.isHidden = !isVisible
        self.plainIconNode.isHidden = !isVisible
    }
}

public class SearchBarPlaceholderNode: ASDisplayNode {
    private struct Params {
        var placeholderString: NSAttributedString?
        var compactPlaceholderString: NSAttributedString?
        var constrainedSize: CGSize
        var expansionProgress: CGFloat
        var iconColor: UIColor
        var foregroundColor: UIColor
        var backgroundColor: UIColor
        var controlColor: UIColor
        var preferClearGlass: Bool
        
        init(placeholderString: NSAttributedString?, compactPlaceholderString: NSAttributedString?, constrainedSize: CGSize, expansionProgress: CGFloat, iconColor: UIColor, foregroundColor: UIColor, backgroundColor: UIColor, controlColor: UIColor, preferClearGlass: Bool) {
            self.placeholderString = placeholderString
            self.compactPlaceholderString = compactPlaceholderString
            self.constrainedSize = constrainedSize
            self.expansionProgress = expansionProgress
            self.iconColor = iconColor
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
            self.controlColor = controlColor
            self.preferClearGlass = preferClearGlass
        }
    }
    
    public var activate: (() -> Void)?
    
    private let containerView: UIView
    private let contentView: SearchBarPlaceholderContentView
    
    public var backgroundView: UIView {
        if let glassBackgroundView = self.contentView.glassBackgroundView {
            return glassBackgroundView
        } else {
            return self.contentView.plainBackgroundView
        }
    }
    
    public var iconNode: ASImageNode {
        return self.contentView.iconNode
    }
    
    public var labelNode: TextNode {
        return self.contentView.labelNode
    }
    
    public var fieldStyle: SearchBarStyle {
        return self.contentView.fieldStyle
    }
    
    var pointerInteraction: PointerInteraction?
    
    public var placeholderString: NSAttributedString? {
        return self.contentView.placeholderString
    }
    
    private(set) var accessoryComponentContainer: UIView?
    private(set) var accessoryComponentView: ComponentHostView<Empty>?
    
    private var params: Params?
    private var currentLayoutHeight: CGFloat?
    private var isTakenOut: Bool = false
    
    public init(fieldStyle: SearchBarStyle = .legacy) {
        self.containerView = UIView()
        self.contentView = SearchBarPlaceholderContentView(fieldStyle: fieldStyle)
        
        super.init()
        
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.contentView)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.backgroundTap(_:)))
        /*gestureRecognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            if let backgroundNode = strongSelf.contentView.backgroundNode {
                if let _ = point {
                    backgroundNode.layer.animate(from: (backgroundNode.backgroundColor ?? strongSelf.foregroundColor).cgColor, to: strongSelf.foregroundColor.withMultipliedBrightnessBy(0.9).cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                    backgroundNode.backgroundColor = strongSelf.foregroundColor.withMultipliedBrightnessBy(0.9)
                } else {
                    backgroundNode.layer.animate(from: (backgroundNode.backgroundColor ?? strongSelf.foregroundColor).cgColor, to: strongSelf.foregroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.4)
                    backgroundNode.backgroundColor = strongSelf.foregroundColor
                }
            }
        }*/
        gestureRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.containerView.addGestureRecognizer(gestureRecognizer)
        
        /*self.pointerInteraction = PointerInteraction(node: self, style: .caret, willEnter: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let backgroundNode = strongSelf.contentView.backgroundNode {
                backgroundNode.backgroundColor = strongSelf.foregroundColor.withMultipliedBrightnessBy(0.95)
            }
        }, willExit: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let backgroundNode = strongSelf.contentView.backgroundNode {
                backgroundNode.backgroundColor = strongSelf.foregroundColor
            }
        })*/
    }
    
    public func setAccessoryComponent(component: AnyComponent<Empty>?) {
        /*if let component = component {
            let accessoryComponentContainer: UIView
            if let current = self.accessoryComponentContainer {
                accessoryComponentContainer = current
            } else {
                accessoryComponentContainer = UIView()
                self.accessoryComponentContainer = accessoryComponentContainer
                self.view.addSubview(accessoryComponentContainer)
            }
            
            let accessoryComponentView: ComponentHostView<Empty>
            if let current = self.accessoryComponentView {
                accessoryComponentView = current
            } else {
                accessoryComponentView = ComponentHostView()
                self.accessoryComponentView = accessoryComponentView
                accessoryComponentContainer.addSubview(accessoryComponentView)
            }
            let accessorySize = accessoryComponentView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
            accessoryComponentContainer.frame = CGRect(origin: CGPoint(x: self.bounds.width - accessorySize.width - 4.0, y: floor((self.bounds.height - accessorySize.height) / 2.0)), size: accessorySize)
            accessoryComponentView.frame = CGRect(origin: CGPoint(), size: accessorySize)
        } else if let accessoryComponentView = self.accessoryComponentView {
            self.accessoryComponentView = nil
            accessoryComponentView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            accessoryComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak accessoryComponentView] _ in
                accessoryComponentView?.removeFromSuperview()
            })
        }*/
    }
    
    public func takeContents() -> SearchBarPlaceholderContentView {
        self.isTakenOut = true
        return self.contentView
    }
    
    public func putBackContents() {
        self.isTakenOut = false
        self.containerView.addSubview(self.contentView)
        if let params = self.params {
            let _ = self.update(params: params, transition: .immediate)
        }
    }
    
    public func updateLayout(placeholderString: NSAttributedString?, compactPlaceholderString: NSAttributedString?, constrainedSize: CGSize, expansionProgress: CGFloat, iconColor: UIColor, foregroundColor: UIColor, backgroundColor: UIColor, controlColor: UIColor, preferClearGlass: Bool = false, transition: ContainedViewLayoutTransition) -> CGFloat {
        let params = Params(placeholderString: placeholderString, compactPlaceholderString: compactPlaceholderString, constrainedSize: constrainedSize, expansionProgress: expansionProgress, iconColor: iconColor, foregroundColor: foregroundColor, backgroundColor: backgroundColor, controlColor: controlColor, preferClearGlass: preferClearGlass)
        self.params = params
        
        if self.isTakenOut {
            return self.currentLayoutHeight ?? 44.0
        } else {
            let height = self.update(params: params, transition: transition)
            self.currentLayoutHeight = height
            return height
        }
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) -> CGFloat {
        let height = self.contentView.updateLayout(placeholderString: params.placeholderString, compactPlaceholderString: params.compactPlaceholderString, constrainedSize: params.constrainedSize, expansionProgress: params.expansionProgress, iconColor: params.iconColor, foregroundColor: params.foregroundColor, backgroundColor: params.backgroundColor, controlColor: params.controlColor, preferClearGlass: params.preferClearGlass, transition: transition)
        let size = CGSize(width: params.constrainedSize.width, height: height)
        transition.updateFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
        return height
    }
    
    @objc private func backgroundTap(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.activate?()
        }
    }
}
