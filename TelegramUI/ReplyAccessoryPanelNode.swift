import Foundation
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

final class ReplyAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageId: MessageId
    
    let closeButton: ASButtonNode
    let lineNode: ASDisplayNode
    let titleNode: ASTextNode
    let textNode: ASTextNode
    
    init(account: Account, messageId: MessageId) {
        self.messageId = messageId
        
        self.closeButton = ASButtonNode()
        self.closeButton.setImage(UIImage(bundleImageName: "Chat/Input/Acessory Panels/CloseButton")?.precomposed(), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASDisplayNode()
        self.lineNode.backgroundColor = UIColor(0x007ee5)
        
        self.titleNode = ASTextNode()
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ASTextNode()
        self.textNode.truncationMode = .byTruncatingTail
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.messageDisposable.set((account.postbox.messageAtId(messageId)
            |> deliverOnMainQueue).start(next: { [weak self] message in
            if let strongSelf = self {
                var authorName = ""
                var text = ""
                if let author = message?.author {
                    authorName = author.displayTitle
                }
                if let messageText = message?.text {
                    text = messageText
                }
                
                strongSelf.titleNode.attributedText = NSAttributedString(string: authorName, font: Font.regular(14.5), textColor: UIColor(0x007ee5))
                strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.5), textColor: UIColor.black)
                
                strongSelf.setNeedsLayout()
            }
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 40.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - self.insets.right - closeButtonSize.width, y: 12.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: self.insets.left, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 5.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 11.0 - insets.left - insets.right - 14.0, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: self.insets.left + 11.0, y: 7.0), size: titleSize)
        
        let textSize = self.textNode.measure(CGSize(width: bounds.size.width - 11.0 - insets.left - insets.right - 14.0, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: self.insets.left + 11.0, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
}
