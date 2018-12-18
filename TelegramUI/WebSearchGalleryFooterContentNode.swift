import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents

final class WebSearchGalleryFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let cancelButton: HighlightableButtonNode
    private let sendButton: HighlightableButtonNode
    
    var cancel: (() -> Void)?
    var send: (() -> Void)?
    
    init(account: Account, presentationData: PresentationData) {
        self.account = account
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setImage(TGComponentsImageNamed("PhotoPickerBackIcon"), for: [.normal])
        self.sendButton = HighlightableButtonNode()
        self.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(self.theme), for: [.normal])
        
        super.init()
        
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.sendButton)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.sendButton.addTarget(self, action: #selector(self.sendButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func setCaption(_ caption: String) {
        
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let panelSize: CGFloat = 49.0
        var panelHeight: CGFloat = panelSize + bottomInset
        panelHeight += contentInset
        var textFrame = CGRect()
//        if !self.textNode.isHidden {
//            let sideInset: CGFloat = 8.0 + leftInset
//            let topInset: CGFloat = 8.0
//            let textBottomInset: CGFloat = 8.0
//            let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
//            panelHeight += textSize.height + topInset + textBottomInset
//            textFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: textSize)
//        }

        //self.textNode.frame = textFrame
        
        self.cancelButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - panelSize), size: CGSize(width: panelSize, height: panelSize))
        self.sendButton.frame = CGRect(origin: CGPoint(x: width - panelSize - rightInset, y: panelHeight - bottomInset - panelSize), size: CGSize(width: panelSize, height: panelSize))
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        self.cancelButton.alpha = 1.0
        self.sendButton.alpha = 1.0
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.cancelButton.alpha = 0.0
        self.sendButton.alpha = 0.0
        completion()
    }
    
    @objc func cancelButtonPressed() {
       self.cancel?()
    }
    
    @objc func sendButtonPressed() {
        self.send?()
    }
}
