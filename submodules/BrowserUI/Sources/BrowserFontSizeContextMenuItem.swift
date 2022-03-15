import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle
import ContextUI

final class BrowserFontSizeContextMenuItem: ContextMenuCustomItem {
    private let value: CGFloat
    private let decrease: () -> CGFloat
    private let increase: () -> CGFloat
    private let reset: () -> Void
    
    init(value: CGFloat, decrease: @escaping () -> CGFloat, increase: @escaping () -> CGFloat, reset: @escaping () -> Void) {
        self.value = value
        self.decrease = decrease
        self.increase = increase
        self.reset = reset
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return BrowserFontSizeContextMenuItemNode(presentationData: presentationData, getController: getController, value: self.value, decrease: self.decrease, increase: self.increase, reset: self.reset)
    }
}

private let textFont = Font.regular(17.0)

private final class BrowserFontSizeContextMenuItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    
    private let leftBackgroundNode: ASDisplayNode
    private let leftHighlightedBackgroundNode: ASDisplayNode
    private let leftIconNode: ASImageNode
    private let leftButtonNode: HighlightTrackingButtonNode
    
    private let rightBackgroundNode: ASDisplayNode
    private let rightHighlightedBackgroundNode: ASDisplayNode
    private let rightIconNode: ASImageNode
    private let rightButtonNode: HighlightTrackingButtonNode
    
    private let centerTextNode: ImmediateTextNode
    private let centerHighlightedBackgroundNode: ASDisplayNode
    private let centerButtonNode: HighlightTrackingButtonNode
    
    private let leftSeparatorNode: ASDisplayNode
    private let rightSeparatorNode: ASDisplayNode
    
    var value: CGFloat = 1.0 {
        didSet {
            self.updateValue()
        }
    }
    
    private let decrease: () -> CGFloat
    private let increase: () -> CGFloat
    private let reset: () -> Void
    
    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, value: CGFloat, decrease: @escaping () -> CGFloat, increase: @escaping () -> CGFloat, reset: @escaping () -> Void) {
        self.presentationData = presentationData
        self.value = value
        self.decrease = decrease
        self.increase = increase
        self.reset = reset
        
        self.leftBackgroundNode = ASDisplayNode()
        self.leftBackgroundNode.isAccessibilityElement = false
        self.leftBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.leftHighlightedBackgroundNode = ASDisplayNode()
        self.leftHighlightedBackgroundNode.isAccessibilityElement = false
        self.leftHighlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.leftHighlightedBackgroundNode.alpha = 0.0
        
        self.leftIconNode = ASImageNode()
        self.leftIconNode.isAccessibilityElement = false
        self.leftIconNode.displaysAsynchronously = false
        self.leftIconNode.displayWithoutProcessing = true
        self.leftIconNode.isUserInteractionEnabled = false
        self.leftIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/DecreaseFont"), color: presentationData.theme.contextMenu.primaryColor)
        
        self.leftButtonNode = HighlightTrackingButtonNode()
        self.leftButtonNode.isAccessibilityElement = true
        self.leftButtonNode.accessibilityLabel = presentationData.strings.InstantPage_VoiceOver_DecreaseFontSize
        
        self.rightBackgroundNode = ASDisplayNode()
        self.rightBackgroundNode.isAccessibilityElement = false
        self.rightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.rightHighlightedBackgroundNode = ASDisplayNode()
        self.rightHighlightedBackgroundNode.isAccessibilityElement = false
        self.rightHighlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.rightHighlightedBackgroundNode.alpha = 0.0
        
        self.rightIconNode = ASImageNode()
        self.rightIconNode.isAccessibilityElement = false
        self.rightIconNode.displaysAsynchronously = false
        self.rightIconNode.displayWithoutProcessing = true
        self.rightIconNode.isUserInteractionEnabled = false
        self.rightIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/IncreaseFont"), color: presentationData.theme.contextMenu.primaryColor)

        self.rightButtonNode = HighlightTrackingButtonNode()
        self.rightButtonNode.isAccessibilityElement = true
        self.rightButtonNode.accessibilityLabel = presentationData.strings.InstantPage_VoiceOver_IncreaseFontSize
        
        self.centerTextNode = ImmediateTextNode()
        self.centerTextNode.isAccessibilityElement = false
        self.centerTextNode.isUserInteractionEnabled = false
        self.centerTextNode.displaysAsynchronously = false
        self.centerTextNode.textAlignment = .center
        
        self.centerHighlightedBackgroundNode = ASDisplayNode()
        self.centerHighlightedBackgroundNode.isAccessibilityElement = false
        self.centerHighlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.centerHighlightedBackgroundNode.alpha = 0.0
        
        self.centerButtonNode = HighlightTrackingButtonNode()
        self.centerButtonNode.isAccessibilityElement = true
        self.centerButtonNode.accessibilityLabel = presentationData.strings.InstantPage_VoiceOver_ResetFontSize
        
        self.leftSeparatorNode = ASDisplayNode()
        self.leftSeparatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
        self.rightSeparatorNode = ASDisplayNode()
        self.rightSeparatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
        
        super.init()
        
        self.isUserInteractionEnabled = true
        
        self.addSubnode(self.leftBackgroundNode)
        self.addSubnode(self.leftHighlightedBackgroundNode)
        self.addSubnode(self.leftIconNode)
        self.addSubnode(self.leftButtonNode)
        self.addSubnode(self.rightBackgroundNode)
        self.addSubnode(self.rightHighlightedBackgroundNode)
        self.addSubnode(self.rightIconNode)
        self.addSubnode(self.rightButtonNode)
        self.addSubnode(self.centerHighlightedBackgroundNode)
        self.addSubnode(self.centerTextNode)
        self.addSubnode(self.centerButtonNode)
        self.addSubnode(self.leftSeparatorNode)
        self.addSubnode(self.rightSeparatorNode)
        
        self.leftButtonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.leftHighlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.leftHighlightedBackgroundNode.alpha = 0.0
                strongSelf.leftHighlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.leftButtonNode.addTarget(self, action: #selector(self.leftPressed), forControlEvents: .touchUpInside)
        
        self.rightButtonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.rightHighlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.rightHighlightedBackgroundNode.alpha = 0.0
                strongSelf.rightHighlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.rightButtonNode.addTarget(self, action: #selector(self.rightPressed), forControlEvents: .touchUpInside)
        
        self.centerButtonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.centerHighlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.centerHighlightedBackgroundNode.alpha = 0.0
                strongSelf.centerHighlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.centerButtonNode.addTarget(self, action: #selector(self.centerPressed), forControlEvents: .touchUpInside)
        
        self.updateValue()
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.leftBackgroundNode.backgroundColor = self.presentationData.theme.contextMenu.itemBackgroundColor
        self.leftHighlightedBackgroundNode.backgroundColor = self.presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.leftIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/DecreaseFont"), color: self.presentationData.theme.contextMenu.primaryColor)
        
        self.rightBackgroundNode.backgroundColor = self.presentationData.theme.contextMenu.itemBackgroundColor
        self.rightHighlightedBackgroundNode.backgroundColor = self.presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.rightIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/IncreaseFont"), color: self.presentationData.theme.contextMenu.primaryColor)
        
        self.updateValue()
        self.leftSeparatorNode.backgroundColor = self.presentationData.theme.contextMenu.itemSeparatorColor
        self.rightSeparatorNode.backgroundColor = self.presentationData.theme.contextMenu.itemSeparatorColor
    }
    
    private func updateValue() {
        self.centerTextNode.attributedText = NSAttributedString(string: "\(Int(self.value * 100.0))%", font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
        let _ = self.centerTextNode.updateLayout(CGSize(width: 70.0, height: .greatestFiniteMagnitude))
        
        self.leftButtonNode.isEnabled = self.value > 0.5
        self.leftIconNode.alpha = self.leftButtonNode.isEnabled ? 1.0 : 0.3
        self.rightButtonNode.isEnabled = self.value < 2.0
        self.rightIconNode.alpha = self.rightButtonNode.isEnabled ? 1.0 : 0.3
        self.centerButtonNode.isEnabled = self.value != 1.0
        self.centerTextNode.alpha = self.centerButtonNode.isEnabled ? 1.0 : 0.4
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let buttonWidth: CGFloat = 90.0
        let valueWidth: CGFloat = 70.0
        let height: CGFloat = 45.0
        
        var textSize = self.centerTextNode.updateLayout(CGSize(width: valueWidth, height: .greatestFiniteMagnitude))
        textSize.width = valueWidth
        
        return (CGSize(width: buttonWidth * 2.0 + valueWidth, height: height), { size, transition in
            let verticalOrigin = floor((size.height - textSize.height) / 2.0)
            transition.updateFrameAdditive(node: self.centerTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: verticalOrigin), size: textSize))
            
            transition.updateFrame(node: self.centerHighlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: buttonWidth, y: 0.0), size: CGSize(width: valueWidth, height: size.height)))
            transition.updateFrame(node: self.centerButtonNode, frame: CGRect(origin: CGPoint(x: buttonWidth, y: 0.0), size: CGSize(width: valueWidth, height: size.height)))
            
            let leftIconSize = self.leftIconNode.image!.size
            transition.updateFrameAdditive(node: self.leftIconNode, frame: CGRect(origin: CGPoint(x: floor((buttonWidth - leftIconSize.width) / 2.0), y: floor((size.height - leftIconSize.height) / 2.0)), size: leftIconSize))
            
            let rightIconSize = self.leftIconNode.image!.size
            transition.updateFrameAdditive(node: self.rightIconNode, frame: CGRect(origin: CGPoint(x: size.width - buttonWidth + floor((buttonWidth - rightIconSize.width) / 2.0), y: floor((size.height - rightIconSize.height) / 2.0)), size: rightIconSize))
            
            transition.updateFrame(node: self.leftBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            transition.updateFrame(node: self.leftHighlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            transition.updateFrame(node: self.leftButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            
            transition.updateFrame(node: self.rightBackgroundNode, frame: CGRect(origin: CGPoint(x: size.width - buttonWidth, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            transition.updateFrame(node: self.rightHighlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: size.width - buttonWidth, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            transition.updateFrame(node: self.rightButtonNode, frame: CGRect(origin: CGPoint(x: size.width - buttonWidth, y: 0.0), size: CGSize(width: buttonWidth, height: size.height)))
            
            transition.updateFrame(node: self.leftSeparatorNode, frame: CGRect(origin: CGPoint(x: buttonWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height)))
            transition.updateFrame(node: self.rightSeparatorNode, frame: CGRect(origin: CGPoint(x: size.width - buttonWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height)))
        })
    }
    
    @objc private func leftPressed() {
        let newValue = self.decrease()
        self.value = newValue
    }
    
    @objc private func rightPressed() {
        let newValue = self.increase()
        self.value = newValue
    }
    
    @objc private func centerPressed() {
        self.reset()
        self.value = 1.0
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        
    }
    
    func performAction() {
        
    }
}
