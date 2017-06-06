import Foundation
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

final class EditAccessoryPanelNode: AccessoryPanelNode {
    let messageId: MessageId
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: ASTextNode
    let textNode: ASTextNode
    var activityIndicator: UIActivityIndicatorView?
    
    private let messageDisposable = MetaDisposable()
    private let editingMessageDisposable = MetaDisposable()
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.editingMessageDisposable.set(statuses.editingMessage.start(next: { [weak self] value in
                    if let strongSelf = self, let activityIndicator = strongSelf.activityIndicator {
                        if value {
                            activityIndicator.isHidden = false
                            activityIndicator.startAnimating()
                        } else {
                            activityIndicator.isHidden = true
                            activityIndicator.stopAnimating()
                        }
                    }
                }))
            }
        }
    }
    
    var theme: PresentationTheme
    
    init(account: Account, messageId: MessageId, theme: PresentationTheme, strings: PresentationStrings) {
        self.messageId = messageId
        self.theme = theme
        
        self.closeButton = ASButtonNode()
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
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
                    var text = ""
                    if let messageText = message?.text {
                        text = messageText
                    }
                    
                    strongSelf.titleNode.attributedText = NSAttributedString(string: "Edit Message", font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                    strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.primaryTextColor)
                    
                    strongSelf.setNeedsLayout()
                }
            }))
    }
    
    deinit {
        self.messageDisposable.dispose()
        self.editingMessageDisposable.dispose()
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme {
            self.theme = theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            
            if let text = self.titleNode.attributedText?.string {
                self.titleNode.attributedText = NSAttributedString(string: text, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            }
            
            if let text = self.textNode.attributedText?.string {
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
            }
            
            self.setNeedsLayout()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.activityIndicator = activityIndicator
        self.view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let leftInset: CGFloat = 55.0
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        if let activityIndicator = self.activityIndicator {
            let indicatorSize = activityIndicator.bounds.size
            activityIndicator.frame = CGRect(origin: CGPoint(x: 18.0, y: 15.0), size: indicatorSize)
        }
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 7.0), size: titleSize)
        
        let textSize = self.textNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
}
