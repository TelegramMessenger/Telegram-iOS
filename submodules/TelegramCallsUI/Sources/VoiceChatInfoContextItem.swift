import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ContextUI
import TelegramStringFormatting

public final class VoiceChatInfoContextItem: ContextMenuCustomItem {
    let text: String
    let icon: (PresentationTheme) -> UIImage?
    
    public init(text: String, icon: @escaping (PresentationTheme) -> UIImage?) {
        self.text = text
        self.icon = icon
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return VoiceChatInfoContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class VoiceChatInfoContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: VoiceChatInfoContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let iconNode: ASImageNode
    
    init(presentationData: PresentationData, item: VoiceChatInfoContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: item.text, font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.textNode.maximumNumberOfLines = 0
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = item.icon(presentationData.theme)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconNode)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = self.iconNode.image.flatMap({ $0.size }) ?? CGSize()
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset - 12.0
        }
    
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        
        return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + textSize.height), { size, transition in
            let verticalOrigin = floor((size.height - textSize.height) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            if !iconSize.width.isZero {
                transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
}
