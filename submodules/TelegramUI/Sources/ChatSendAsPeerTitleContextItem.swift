import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ContextUI
import TelegramStringFormatting

public final class ChatSendAsPeerTitleContextItem: ContextMenuCustomItem {
    let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatSendAsPeerTitleContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class ChatSendAsPeerTitleContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: ChatSendAsPeerTitleContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    
    init(presentationData: PresentationData, item: ChatSendAsPeerTitleContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 12.0 / 17.0)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: item.text, font: textFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        self.textNode.maximumNumberOfLines = 1
                
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0

        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - sideInset, height: .greatestFiniteMagnitude))
        let height: CGFloat = 28.0
        
        return (CGSize(width: textSize.width + sideInset + sideInset, height: height), { size, transition in
            let verticalOrigin = floor((size.height - textSize.height) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 12.0 / 17.0)
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.secondaryColor)
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
}
