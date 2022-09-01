import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalizedPeerData
import AlertUI
import PresentationDataUtils
import TextFormat
import Markdown
import TelegramNotices
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer

func textStringForForwardedMessage(_ message: Message, strings: PresentationStrings) -> (text: String, entities: [MessageTextEntity], isMedia: Bool) {
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            return (strings.Message_Photo, [], true)
        case let file as TelegramMediaFile:
            if file.isVideoSticker || file.isAnimatedSticker {
                return (strings.Message_Sticker, [], true)
            }
            var fileName: String = strings.Message_File
            for attribute in file.attributes {
                switch attribute {
                case .Sticker:
                    return (strings.Message_Sticker, [], true)
                case let .FileName(name):
                    fileName = name
                case let .Audio(isVoice, _, title, performer, _):
                    if isVoice {
                        return (strings.Message_Audio, [], true)
                    } else {
                        if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                            return (title + " — " + performer, [], true)
                        } else if let title = title, !title.isEmpty {
                            return (title, [], true)
                        } else if let performer = performer, !performer.isEmpty {
                            return (performer, [], true)
                        } else {
                            return (strings.Message_Audio, [], true)
                        }
                    }
                case .Video:
                    if file.isAnimated {
                        return (strings.Message_Animation, [], true)
                    } else {
                        return (strings.Message_Video, [], true)
                    }
                default:
                    break
                }
            }
            return (fileName, [], true)
        case _ as TelegramMediaContact:
            return (strings.Message_Contact, [], true)
        case let game as TelegramMediaGame:
            return (game.title, [], true)
        case _ as TelegramMediaMap:
            return (strings.Message_Location, [], true)
        case _ as TelegramMediaAction:
            return ("", [], true)
        case _ as TelegramMediaPoll:
            return (strings.ForwardedPolls(1), [], true)
        case let dice as TelegramMediaDice:
            return (dice.emoji, [], true)
        case let invoice as TelegramMediaInvoice:
            return (invoice.title, [], true)
        default:
            break
        }
    }
    return (message.text, message.textEntitiesAttribute?.entities ?? [], false)
}

final class ForwardAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageIds: [MessageId]
    private var messages: [Message] = []
    private var authors: String?
    private var sourcePeer: (isPersonal: Bool, displayTitle: String)?
    
    let closeButton: HighlightableButtonNode
    let lineNode: ASImageNode
    let iconNode: ASImageNode
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNodeWithEntities
    private var originalText: NSAttributedString?
    
    private let actionArea: AccessibilityAreaNode
    
    let context: AccountContext
    var theme: PresentationTheme
    var strings: PresentationStrings
    var fontSize: PresentationFontSize
    var nameDisplayOrder: PresentationPersonNameOrder
    var forwardOptionsState: ChatInterfaceForwardOptionsState?
    
    private var validLayout: (size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState)?
    
    init(context: AccountContext, messageIds: [MessageId], theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, nameDisplayOrder: PresentationPersonNameOrder, forwardOptionsState: ChatInterfaceForwardOptionsState?, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?) {
        self.context = context
        self.messageIds = messageIds
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.nameDisplayOrder = nameDisplayOrder
        self.forwardOptionsState = forwardOptionsState
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.accessibilityLabel = strings.VoiceOver_DiscardPreparedContent
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = false
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = PresentationResourcesChat.chatInputPanelForwardIconImage(theme)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNodeWithEntities()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionArea)
        
        if let animationCache = animationCache, let animationRenderer = animationRenderer {
            self.textNode.arguments = TextNodeWithEntities.Arguments(
                context: context,
                cache: animationCache,
                renderer: animationRenderer,
                placeholderColor: theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            )
        }
        
        self.messageDisposable.set((context.account.postbox.messagesAtIds(messageIds)
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            if let strongSelf = self {
                if messages.isEmpty {
                    strongSelf.dismiss?()
                } else {
                    var authors = ""
                    var uniquePeerIds = Set<PeerId>()
                    var title = ""
                    var text = NSMutableAttributedString(string: "")
                    var sourcePeer: (Bool, String)?
                    for message in messages {
                        if let author = message.forwardInfo?.author ?? message.effectiveAuthor, !uniquePeerIds.contains(author.id) {
                            uniquePeerIds.insert(author.id)
                            if !authors.isEmpty {
                                authors.append(", ")
                            }
                            if author.id == context.account.peerId {
                                authors.append(strongSelf.strings.DialogList_You)
                            } else {
                                authors.append(EnginePeer(author).compactDisplayTitle)
                            }
                        }
                        if let peer = message.peers[message.id.peerId] {
                            sourcePeer = (peer.id.namespace == Namespaces.Peer.CloudUser, EnginePeer(peer).displayTitle(strings: strongSelf.strings, displayOrder: strongSelf.nameDisplayOrder))
                        }
                    }
                    
                    if messages.count == 1 {
                        title = strongSelf.strings.Conversation_ForwardOptions_ForwardTitleSingle
                        let (string, entities, _) = textStringForForwardedMessage(messages[0], strings: strings)
                        
                        text = NSMutableAttributedString(attributedString: NSAttributedString(string: "\(authors): ", font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor))
                        
                        let additionalText = NSMutableAttributedString(attributedString: NSAttributedString(string: string, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor))
                        for entity in entities {
                            switch entity.type {
                            case let .CustomEmoji(_, fileId):
                                let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                if range.lowerBound >= 0 && range.upperBound <= additionalText.length {
                                    additionalText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: messages[0].associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile), range: range)
                                }
                            default:
                                break
                            }
                        }
                        
                        text.append(additionalText)
                    } else {
                        title = strongSelf.strings.Conversation_ForwardOptions_ForwardTitle(Int32(messages.count))
                        text = NSMutableAttributedString(attributedString: NSAttributedString(string: strongSelf.strings.Conversation_ForwardFrom(authors).string, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor))
                    }
                    
                    strongSelf.messages = messages
                    strongSelf.sourcePeer = sourcePeer
                    strongSelf.authors = authors
                    
                    strongSelf.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                    strongSelf.textNode.attributedText = text
                    strongSelf.originalText = text
                    strongSelf.textNode.visibility = true
                    
                    let headerString: String
                    if messages.count == 1 {
                        headerString = "Forward message"
                    } else {
                        headerString = "Forward messages"
                    }
                    strongSelf.actionArea.accessibilityLabel = "\(headerString). From: \(authors).\n\(text)"

                    if let (size, inset, interfaceState) = strongSelf.validLayout {
                        strongSelf.updateState(size: size, inset: inset, interfaceState: interfaceState)
                    }
                    
                    let _ = (ApplicationSpecificNotice.getChatForwardOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager)
                    |> deliverOnMainQueue).start(next: { [weak self] count in
                        if let strongSelf = self, count < 3 {
                            Queue.mainQueue().after(3.0) {
                                if let snapshotView = strongSelf.textNode.view.snapshotContentTree() {
                                    let text: String
                                    if let (size, _, _) = strongSelf.validLayout, size.width > 320.0 {
                                        text = strongSelf.strings.Conversation_ForwardOptions_TapForOptions
                                    } else {
                                        text = strongSelf.strings.Conversation_ForwardOptions_TapForOptionsShort
                                    }
                                    
                                    strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor)
                                    
                                    strongSelf.view.addSubview(snapshotView)
                                    
                                    if let (size, inset, interfaceState) = strongSelf.validLayout {
                                        strongSelf.updateState(size: size, inset: inset, interfaceState: interfaceState)
                                    }
                                    
                                    strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                        snapshotView?.removeFromSuperview()
                                    })
                                }
                                
                                let _ = ApplicationSpecificNotice.incrementChatForwardOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager).start()
                            }
                        }
                    })
                }
            }
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    override func animateIn() {
        self.iconNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
    }
    
    override func animateOut() {
        self.iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.updateThemeAndStrings(theme: theme, strings: strings, forwardOptionsState: self.forwardOptionsState)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, forwardOptionsState: ChatInterfaceForwardOptionsState?, force: Bool = false) {
        if force || self.theme !== theme || self.strings !== strings || self.forwardOptionsState != forwardOptionsState {
            self.theme = theme
            self.strings = strings
            self.forwardOptionsState = forwardOptionsState
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            self.iconNode.image = PresentationResourcesChat.chatInputPanelForwardIconImage(theme)
            
            let filteredMessages = self.messages
            
            var title = ""
            if filteredMessages.count == 1 {
                title = self.strings.Conversation_ForwardOptions_ForwardTitleSingle
            } else {
                title = self.strings.Conversation_ForwardOptions_ForwardTitle(Int32(filteredMessages.count))
            }
            
            self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            
            if let attributedText = self.textNode.attributedText {
                let updatedText = NSMutableAttributedString(attributedString: attributedText)
                updatedText.addAttribute(.foregroundColor, value: self.theme.chat.inputPanel.secondaryTextColor, range: NSRange(location: 0, length: updatedText.length))
                self.textNode.attributedText = updatedText
                self.originalText = updatedText
            }
            
            if let (size, inset, interfaceState) = self.validLayout {
                self.updateState(size: size, inset: inset, interfaceState: interfaceState)
            }
        }
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }

    override func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, inset, interfaceState)

        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 45.0))
        let leftInset: CGFloat = 55.0 + inset
        let rightInset: CGFloat = 55.0 + inset
        let textLineInset: CGFloat = 10.0
        let textRightInset: CGFloat = 20.0

        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        let closeButtonFrame = CGRect(origin: CGPoint(x: bounds.width - closeButtonSize.width - inset, y: 2.0), size: closeButtonSize)
        self.closeButton.frame = closeButtonFrame
        self.closeButton.isHidden = interfaceState.renderedPeer == nil

        self.actionArea.frame = CGRect(origin: CGPoint(x: leftInset, y: 2.0), size: CGSize(width: closeButtonFrame.minX - leftInset, height: bounds.height))

        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))

        if let icon = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 7.0), size: titleSize)

        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        guard let (isPersonal, peerDisplayTitle) = self.sourcePeer else {
            return
        }
        let messageCount = Int32(self.messageIds.count)
        let messages = self.strings.Conversation_ForwardOptions_Messages(messageCount)
        let string = isPersonal ? self.strings.Conversation_ForwardOptions_TextPersonal(messages, peerDisplayTitle) : self.strings.Conversation_ForwardOptions_Text(messages, peerDisplayTitle)
        
        let font = Font.regular(floor(self.fontSize.baseDisplaySize * 15.0 / 17.0))
        let boldFont = Font.semibold(floor(self.fontSize.baseDisplaySize * 15.0 / 17.0))
        let body = MarkdownAttributeSet(font: font, textColor: self.theme.actionSheet.secondaryTextColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: self.theme.actionSheet.secondaryTextColor)
        
        let title = NSAttributedString(string: self.strings.Conversation_ForwardOptions_Title(messageCount), font: Font.semibold(floor(self.fontSize.baseDisplaySize)), textColor: self.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        let text = addAttributesToStringWithRanges(string._tuple, body: body, argumentAttributes: [0: bold, 1: bold], textAlignment: .center)
        
        let alertController = richTextAlertController(context: self.context, title: title, text: text, actions: [TextAlertAction(type: .genericAction, title: self.strings.Conversation_ForwardOptions_ShowOptions, action: { [weak self] in
            if let strongSelf = self {
                strongSelf.interfaceInteraction?.presentForwardOptions(strongSelf)
                Queue.mainQueue().after(0.5) {
                    strongSelf.updateThemeAndStrings(theme: strongSelf.theme, strings: strongSelf.strings, forwardOptionsState: strongSelf.forwardOptionsState, force: true)
                }
                
                let _ = ApplicationSpecificNotice.incrementChatForwardOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager, count: 3).start()
            }
        }), TextAlertAction(type: .destructiveAction, title: self.strings.Conversation_ForwardOptions_CancelForwarding, action: { [weak self] in
            self?.dismiss?()
        })], actionLayout: .vertical)
        self.interfaceInteraction?.presentController(alertController, nil)
    }
    
    private var previousTapTimestamp: Double?
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CFAbsoluteTimeGetCurrent()
            if let previousTapTimestamp = self.previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                return
            }
            self.previousTapTimestamp = CFAbsoluteTimeGetCurrent()
            self.interfaceInteraction?.presentForwardOptions(self)
            Queue.mainQueue().after(1.5) {
                self.updateThemeAndStrings(theme: self.theme, strings: self.strings, forwardOptionsState: self.forwardOptionsState, force: true)
            }
            
            let _ = ApplicationSpecificNotice.incrementChatForwardOptionsTip(accountManager: self.context.sharedContext.accountManager, count: 3).start()
        }
    }
}
