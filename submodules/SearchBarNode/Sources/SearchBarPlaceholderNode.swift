import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import ComponentFlow

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

public class SearchBarPlaceholderNode: ASDisplayNode {
    public var activate: (() -> Void)?
    
    private let fieldStyle: SearchBarStyle
    public let backgroundNode: ASDisplayNode
    private var fillBackgroundColor: UIColor
    private var foregroundColor: UIColor
    private var iconColor: UIColor
    public let iconNode: ASImageNode
    public let labelNode: TextNode
    
    var pointerInteraction: PointerInteraction?
    
    public private(set) var placeholderString: NSAttributedString?
    
    private(set) var accessoryComponentContainer: UIView?
    private(set) var accessoryComponentView: ComponentHostView<Empty>?
    
    convenience public override init() {
        self.init(fieldStyle: .legacy)
    }
    
    public init(fieldStyle: SearchBarStyle = .legacy) {
        self.fieldStyle = fieldStyle
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = false
        self.backgroundNode.displaysAsynchronously = false
        
        self.fillBackgroundColor = UIColor.white
        self.foregroundColor = UIColor(rgb: 0xededed)
        self.iconColor = UIColor(rgb: 0x000000, alpha: 0.0)
        
        self.backgroundNode.backgroundColor = self.foregroundColor
        self.backgroundNode.cornerRadius = self.fieldStyle.cornerDiameter / 2.0
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isOpaque = false
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.labelNode)
        
        self.backgroundNode.isUserInteractionEnabled = true
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.backgroundTap(_:)))
        gestureRecognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            if let _ = point {
                strongSelf.backgroundNode.layer.animate(from: (strongSelf.backgroundNode.backgroundColor ?? strongSelf.foregroundColor).cgColor, to: strongSelf.foregroundColor.withMultipliedBrightnessBy(0.9).cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                strongSelf.backgroundNode.backgroundColor = strongSelf.foregroundColor.withMultipliedBrightnessBy(0.9)
            } else {
                strongSelf.backgroundNode.layer.animate(from: (strongSelf.backgroundNode.backgroundColor ?? strongSelf.foregroundColor).cgColor, to: strongSelf.foregroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.4)
                strongSelf.backgroundNode.backgroundColor = strongSelf.foregroundColor
            }
        }
        gestureRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.backgroundNode.view.addGestureRecognizer(gestureRecognizer)
        
        self.pointerInteraction = PointerInteraction(node: self, style: .caret, willEnter: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.backgroundNode.backgroundColor = strongSelf.foregroundColor.withMultipliedBrightnessBy(0.95)
        }, willExit: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.backgroundNode.backgroundColor = strongSelf.foregroundColor
        })
    }
    
    public func setAccessoryComponent(component: AnyComponent<Empty>?) {
        if let component = component {
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
        }
    }
    
    public func asyncLayout() -> (_ placeholderString: NSAttributedString?, _ compactPlaceholderString: NSAttributedString?, _ constrainedSize: CGSize, _ expansionProgress: CGFloat, _ iconColor: UIColor, _ foregroundColor: UIColor, _ backgroundColor: UIColor, _ transition: ContainedViewLayoutTransition) -> (CGFloat, () -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let currentForegroundColor = self.foregroundColor
        let currentIconColor = self.iconColor
        
        return { fullPlaceholderString, compactPlaceholderString, constrainedSize, expansionProgress, iconColor, foregroundColor, backgroundColor, transition in
            let placeholderString: NSAttributedString?
            if constrainedSize.width < 350.0 {
                placeholderString = compactPlaceholderString
            } else {
                placeholderString = fullPlaceholderString
            }
            
            let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: placeholderString, backgroundColor: .clear, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var updatedColor: UIColor?
            var updatedIconImage: UIImage?
            if !currentForegroundColor.isEqual(foregroundColor) {
                updatedColor = foregroundColor
            }
            if !currentIconColor.isEqual(iconColor) {
                updatedIconImage = generateLoupeIcon(color: iconColor)
            }
            
            let height = constrainedSize.height * expansionProgress
            return (height, { [weak self] in
                if let strongSelf = self {
                    let _ = labelApply()
                    
                    strongSelf.fillBackgroundColor = backgroundColor
                    strongSelf.foregroundColor = foregroundColor
                    strongSelf.iconColor = iconColor
                    strongSelf.backgroundNode.isUserInteractionEnabled = expansionProgress > 0.9999
                    
                    if let updatedColor = updatedColor {
                        strongSelf.backgroundNode.backgroundColor = updatedColor
                    }
                    if let updatedIconImage = updatedIconImage {
                        strongSelf.iconNode.image = updatedIconImage
                    }
                    
                    strongSelf.placeholderString = placeholderString
                    
                    var iconSize = CGSize()
                    var totalWidth = labelLayoutResult.size.width
                    let spacing: CGFloat = 6.0
                    
                    if let iconImage = strongSelf.iconNode.image {
                        iconSize = iconImage.size
                        totalWidth += iconSize.width + spacing
                        transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: floor((constrainedSize.width - totalWidth) / 2.0), y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
                    }
                    var textOffset: CGFloat = 0.0
                    if constrainedSize.height >= 36.0 {
                        textOffset += 1.0
                    }
                    let labelFrame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - totalWidth) / 2.0) + iconSize.width + spacing, y: floorToScreenPixels((height - labelLayoutResult.size.height) / 2.0) + textOffset), size: labelLayoutResult.size)
                    transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
               
                    var innerAlpha = max(0.0, expansionProgress - 0.77) / 0.23
                    if innerAlpha > 0.9999 {
                        innerAlpha = 1.0
                    } else if innerAlpha < 0.0001 {
                        innerAlpha = 0.0
                    }
                    if !transition.isAnimated {
                        strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    }
                    if strongSelf.labelNode.alpha != innerAlpha {
                        transition.updateAlpha(node: strongSelf.labelNode, alpha: innerAlpha)
                        transition.updateAlpha(node: strongSelf.iconNode, alpha: innerAlpha)
                    }
                    
                    let outerAlpha = min(0.3, expansionProgress) / 0.3
                    let cornerRadius = min(strongSelf.fieldStyle.cornerDiameter / 2.0, height / 2.0)
                    if !transition.isAnimated {
                        strongSelf.backgroundNode.layer.removeAnimation(forKey: "cornerRadius")
                        strongSelf.backgroundNode.layer.removeAnimation(forKey: "position")
                        strongSelf.backgroundNode.layer.removeAnimation(forKey: "bounds")
                        strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    }
                    transition.updateCornerRadius(node: strongSelf.backgroundNode, cornerRadius: cornerRadius)
                    transition.updateAlpha(node: strongSelf.backgroundNode, alpha: outerAlpha)
                    transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: height)))
                    
                    if let accessoryComponentContainer = strongSelf.accessoryComponentContainer {
                        accessoryComponentContainer.frame = CGRect(origin: CGPoint(x: constrainedSize.width - accessoryComponentContainer.bounds.width - 4.0, y: floor((constrainedSize.height - accessoryComponentContainer.bounds.height) / 2.0)), size: accessoryComponentContainer.bounds.size)
                    }
                }
            })
        }
    }
    
    @objc private func backgroundTap(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.activate?()
        }
    }
}
