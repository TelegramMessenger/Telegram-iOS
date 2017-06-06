import Foundation
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

func textStringForForwardedMessage(_ message: Message) -> (String, Bool) {
    if !message.text.isEmpty {
        return (message.text, false)
    } else {
        for media in message.media {
            switch media {
            case _ as TelegramMediaImage:
                return ("Forwarded photo", true)
            case let file as TelegramMediaFile:
                var fileName: String = "Forwarded file"
                for attribute in file.attributes {
                    switch attribute {
                    case .Sticker:
                        return ("Forwarded sticker", true)
                    case let .FileName(name):
                        fileName = name
                    case let .Audio(isVoice, _, title, performer, _):
                        if isVoice {
                            return ("Forwarded voice Message", true)
                        } else {
                            if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                return (title + " — " + performer, true)
                            } else if let title = title, !title.isEmpty {
                                return (title, true)
                            } else if let performer = performer, !performer.isEmpty {
                                return (performer, true)
                            } else {
                                return ("Forwarded audio", true)
                            }
                        }
                    case .Video:
                        if file.isAnimated {
                            return ("Forwarded gIF", true)
                        } else {
                            return ("Forwarded video", true)
                        }
                    default:
                        break
                    }
                }
                return (fileName, true)
            case _ as TelegramMediaContact:
                return ("Forwarded contact", true)
            case let game as TelegramMediaGame:
                return (game.title, true)
            case _ as TelegramMediaMap:
                return ("Forwarded map", true)
            case let action as TelegramMediaAction:
                return ("", true)
            default:
                break
            }
        }
        return ("", false)
    }
}

final class ForwardAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageIds: [MessageId]
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: ASTextNode
    let textNode: ASTextNode
    
    var theme: PresentationTheme
    
    init(account: Account, messageIds: [MessageId], theme: PresentationTheme, strings: PresentationStrings) {
        self.messageIds = messageIds
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
        
        self.messageDisposable.set((account.postbox.messagesAtIds(messageIds)
            |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self {
                    var authors = ""
                    var uniquePeerIds = Set<PeerId>()
                    var text = ""
                    for message in messages {
                        if let author = message.author, !uniquePeerIds.contains(author.id) {
                            uniquePeerIds.insert(author.id)
                            if !authors.isEmpty {
                                authors.append(", ")
                            }
                            authors.append(author.compactDisplayTitle)
                        }
                    }
                    if messages.count == 1 {
                        let (string, _) = textStringForForwardedMessage(messages[0])
                        text = string
                    } else {
                        text = "\(messages.count) messages"
                    }
                    
                    strongSelf.titleNode.attributedText = NSAttributedString(string: authors, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                    strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.primaryTextColor)
                    
                    strongSelf.setNeedsLayout()
                }
            }))
    }
    
    deinit {
        self.messageDisposable.dispose()
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
