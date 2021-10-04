import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import AccountContext
import GalleryUI

final class WebSearchGalleryFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let cancelButton: HighlightableButtonNode
    private let sendButton: HighlightableButtonNode
    
    var cancel: (() -> Void)?
    var send: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
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
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let width = size.width
        let panelSize: CGFloat = 49.0
        var panelHeight: CGFloat = panelSize + bottomInset
        panelHeight += contentInset
        
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
