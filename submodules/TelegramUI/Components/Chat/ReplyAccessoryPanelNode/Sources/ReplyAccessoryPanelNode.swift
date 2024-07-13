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
import PhotoResources
import TelegramStringFormatting
import TextFormat
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import AccessoryPanelNode
import TelegramNotices
import AppBundle
import CompositeTextNode

public final class ReplyAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    public let chatPeerId: EnginePeer.Id
    public let messageId: MessageId
    public let quote: EngineMessageReplyQuote?
    
    private var previousMediaReference: AnyMediaReference?
    
    public let closeButton: HighlightableButtonNode
    public let lineNode: ASImageNode
    public let iconView: UIImageView
    public let titleNode: CompositeTextNode
    public let textNode: ImmediateTextNodeWithEntities
    public let imageNode: TransformImageNode
    
    private let actionArea: AccessibilityAreaNode
    
    private let context: AccountContext
    public var theme: PresentationTheme
    public var strings: PresentationStrings
    
    private var textIsOptions: Bool = false
    
    private var validLayout: (size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState)?
    
    public init(context: AccountContext, chatPeerId: EnginePeer.Id, messageId: MessageId, quote: EngineMessageReplyQuote?, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?) {
        self.chatPeerId = chatPeerId
        self.messageId = messageId
        self.quote = quote
        
        self.context = context
        self.theme = theme
        self.strings = strings
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.accessibilityLabel = strings.VoiceOver_DiscardPreparedContent
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.iconView = UIImageView()
        if quote != nil {
            self.iconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/ReplyQuoteIcon")?.withRenderingMode(.alwaysTemplate)
        } else {
            self.iconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/ReplySettingsIcon")?.withRenderingMode(.alwaysTemplate)
        }
        self.iconView.tintColor = theme.chat.inputPanel.panelControlAccentColor
        
        self.titleNode = CompositeTextNode()
        
        self.textNode = ImmediateTextNodeWithEntities()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        self.textNode.insets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
        self.textNode.visibility = true
        self.textNode.spoilerColor = self.theme.chat.inputPanel.secondaryTextColor
        
        if let animationCache = animationCache, let animationRenderer = animationRenderer {
            self.textNode.arguments = TextNodeWithEntities.Arguments(
                context: context,
                cache: animationCache,
                renderer: animationRenderer,
                placeholderColor: theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            )
        }
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.view.addSubview(self.iconView)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.actionArea)
        
        self.messageDisposable.set((context.account.postbox.messageView(messageId)
        |> deliverOnMainQueue).startStrict(next: { [weak self] messageView in
            if let strongSelf = self {
                if messageView.message == nil {
                    Queue.mainQueue().justDispatch {
                        strongSelf.interfaceInteraction?.setupReplyMessage(nil, { _, _ in })
                    }
                    return
                }

                let message = messageView.message

                var authorName = ""
                var text = ""
                var isText = true
                if let forwardInfo = message?.forwardInfo, forwardInfo.flags.contains(.isImported) {
                    if let author = forwardInfo.author {
                        authorName = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                    } else if let authorSignature = forwardInfo.authorSignature {
                        authorName = authorSignature
                    }
                } else if let author = message?.effectiveAuthor {
                    authorName = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
                
                let isMedia: Bool
                if let message = message {
                    switch messageContentKind(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: context.account.peerId) {
                        case .text:
                            isMedia = false
                        default:
                            isMedia = true
                    }
                    let (attributedText, _, isTextValue) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: context.account.peerId)
                    text = attributedText.string
                    isText = isTextValue
                } else {
                    isMedia = false
                }

                let textFont = Font.regular(15.0)
                let messageText: NSAttributedString
                if isText, let message = message {
                    let entities = (message.textEntitiesAttribute?.entities ?? []).filter { entity in
                        switch entity.type {
                        case .Spoiler, .CustomEmoji:
                            return true
                        case .Strikethrough:
                            return true
                        default:
                            return false
                        }
                    }
                    let textColor = strongSelf.theme.chat.inputPanel.primaryTextColor
                    if entities.count > 0 {
                        messageText = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message)
                    } else {
                        messageText = NSAttributedString(string: text, font: textFont, textColor: isMedia ? strongSelf.theme.chat.inputPanel.secondaryTextColor : strongSelf.theme.chat.inputPanel.primaryTextColor)
                    }
                } else {
                    messageText = NSAttributedString(string: text, font: textFont, textColor: isMedia ? strongSelf.theme.chat.inputPanel.secondaryTextColor : strongSelf.theme.chat.inputPanel.primaryTextColor)
                }
                
                var updatedMediaReference: AnyMediaReference?
                var imageDimensions: CGSize?
                var isRoundImage = false
                if let message = message, !message.containsSecretMedia {
                    for media in message.media {
                        if let image = media as? TelegramMediaImage {
                            updatedMediaReference = .message(message: MessageReference(message), media: image)
                            if let representation = largestRepresentationForPhoto(image) {
                                imageDimensions = representation.dimensions.cgSize
                            }
                            break
                        } else if let file = media as? TelegramMediaFile {
                            updatedMediaReference = .message(message: MessageReference(message), media: file)
                            isRoundImage = file.isInstantVideo
                            if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker && !file.isAnimatedSticker {
                                imageDimensions = representation.dimensions.cgSize
                            }
                            break
                        }
                    }
                }
                
                let imageNodeLayout = strongSelf.imageNode.asyncLayout()
                var applyImage: (() -> Void)?
                if let imageDimensions = imageDimensions {
                    let boundingSize = CGSize(width: 35.0, height: 35.0)
                    var radius: CGFloat = 2.0
                    var imageSize = imageDimensions.aspectFilled(boundingSize)
                    if isRoundImage {
                        radius = floor(boundingSize.width / 2.0)
                        imageSize.width += 2.0
                        imageSize.height += 2.0
                    }
                    applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                }
                
                var mediaUpdated = false
                if let updatedMediaReference = updatedMediaReference, let previousMediaReference = strongSelf.previousMediaReference {
                    mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
                } else if (updatedMediaReference != nil) != (strongSelf.previousMediaReference != nil) {
                    mediaUpdated = true
                }
                strongSelf.previousMediaReference = updatedMediaReference
                
                let hasSpoiler = message?.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) ?? false
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                if mediaUpdated {
                    if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                        if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                            updateImageSignal = chatMessagePhotoThumbnail(account: context.account, userLocation: (message?.id.peerId).flatMap(MediaResourceUserLocation.peer) ?? .other, photoReference: imageReference, blurred: hasSpoiler)
                        } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                            if fileReference.media.isVideo {
                                updateImageSignal = chatMessageVideoThumbnail(account: context.account, userLocation: (message?.id.peerId).flatMap(MediaResourceUserLocation.peer) ?? .other, fileReference: fileReference, blurred: hasSpoiler)
                            } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                                updateImageSignal = chatWebpageSnippetFile(account: context.account, userLocation: (message?.id.peerId).flatMap(MediaResourceUserLocation.peer) ?? .other, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                            }
                        }
                    } else {
                        updateImageSignal = .single({ _ in return nil })
                    }
                }
                
                var titleText: [CompositeTextNode.Component] = []
                if let peer = message?.peers[strongSelf.messageId.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    let icon: UIImage?
                    icon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextChannelIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
                    
                    if let icon {
                        let rawString: PresentationStrings.FormattedString
                        if strongSelf.quote != nil {
                            rawString = strongSelf.strings.Chat_ReplyPanel_ReplyToQuoteBy(peer.debugDisplayTitle)
                        } else {
                            rawString = strongSelf.strings.Chat_ReplyPanel_ReplyTo(peer.debugDisplayTitle)
                        }
                        if let nameRange = rawString.ranges.first {
                            titleText = []
                            
                            let rawNsString = rawString.string as NSString
                            if nameRange.range.lowerBound != 0 {
                                titleText.append(.text(NSAttributedString(string: rawNsString.substring(with: NSRange(location: 0, length: nameRange.range.lowerBound)), font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)))
                            }
                            titleText.append(.icon(icon))
                            titleText.append(.text(NSAttributedString(string: peer.debugDisplayTitle, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)))
                            
                            if nameRange.range.upperBound != rawNsString.length {
                                titleText.append(.text(NSAttributedString(string: rawNsString.substring(with: NSRange(location: nameRange.range.upperBound, length: rawNsString.length - nameRange.range.upperBound)), font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)))
                            }
                        } else {
                            titleText.append(.text(NSAttributedString(string: rawString.string, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)))
                        }
                    }
                } else {
                    if let _ = strongSelf.quote {
                        let string = strongSelf.strings.Chat_ReplyPanel_ReplyToQuoteBy(authorName).string
                        titleText = [.text(NSAttributedString(string: string, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor))]
                    } else {
                        let string = strongSelf.strings.Conversation_ReplyMessagePanelTitle(authorName).string
                        titleText = [.text(NSAttributedString(string: string, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor))]
                    }
                    
                    if strongSelf.messageId.peerId != strongSelf.chatPeerId {
                        if let peer = message?.peers[strongSelf.messageId.peerId], (peer is TelegramChannel || peer is TelegramGroup) {
                            let icon: UIImage?
                            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                icon = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextChannelIcon")
                            } else {
                                icon = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextGroupIcon")
                            }
                            if let iconImage = generateTintedImage(image: icon, color: strongSelf.theme.chat.inputPanel.panelControlAccentColor) {
                                titleText.append(.icon(iconImage))
                                titleText.append(.text(NSAttributedString(string: peer.debugDisplayTitle, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
                            }
                        }
                    }
                }
                
                strongSelf.textNode.attributedText = messageText
                
                if let quote = strongSelf.quote {
                    let textColor = strongSelf.theme.chat.inputPanel.primaryTextColor
                    let quoteText = stringWithAppliedEntities(trimToLineCount(quote.text, lineCount: 1), entities: quote.entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message)
                    
                    strongSelf.textNode.attributedText = quoteText
                }
                
                strongSelf.titleNode.components = titleText
                                
                let headerString: String
                if let message = message, message.flags.contains(.Incoming), let author = message.author {
                    headerString = strongSelf.strings.Chat_ReplyPanel_AccessibilityReplyToMessageFrom(EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)).string
                } else if let message = message, !message.flags.contains(.Incoming) {
                    headerString = strongSelf.strings.Chat_ReplyPanel_AccessibilityReplyToYourMessage
                } else {
                    headerString = strongSelf.strings.Chat_ReplyPanel_AccessibilityReplyToMessage
                }
                strongSelf.actionArea.accessibilityLabel = "\(headerString).\n\(text)"
                
                if let applyImage = applyImage {
                    applyImage()
                    strongSelf.imageNode.isHidden = false
                } else {
                    strongSelf.imageNode.isHidden = true
                }
                
                if let updateImageSignal = updateImageSignal {
                    strongSelf.imageNode.setSignal(updateImageSignal)
                }
                
                if let (size, inset, interfaceState) = strongSelf.validLayout {
                    strongSelf.updateState(size: size, inset: inset, interfaceState: interfaceState)
                }
                
                let _ = (ApplicationSpecificNotice.getChatReplyOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager)
                |> deliverOnMainQueue).start(next: { [weak self] count in
                    if let strongSelf = self, count < 3 {
                        Queue.mainQueue().after(3.0) {
                            if let snapshotView = strongSelf.textNode.view.snapshotContentTree() {
                                let text: String
                                if let (size, _, _) = strongSelf.validLayout, size.width > 320.0 {
                                    text = strongSelf.strings.Chat_ReplyPanel_HintReplyOptions
                                } else {
                                    text = strongSelf.strings.Chat_ReplyPanel_HintReplyOptionsShort
                                }
                                strongSelf.textIsOptions = true
                                
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
                            
                            let _ = ApplicationSpecificNotice.incrementChatReplyOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager).start()
                        }
                    }
                })
            }
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        self.view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
    }
    
    override public func animateIn() {
        self.iconView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
    }
    
    override public func animateOut() {
        self.iconView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.updateThemeAndStrings(theme: theme, strings: strings, force: false)
    }
        
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, force: Bool) {
        if self.theme !== theme || force {
            self.theme = theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            self.iconView.tintColor = theme.chat.inputPanel.panelControlAccentColor
            
            self.titleNode.components = self.titleNode.components.map { item in
                switch item {
                case let .text(text):
                    let updatedText = NSMutableAttributedString(attributedString: text)
                    updatedText.addAttribute(.foregroundColor, value: theme.chat.inputPanel.panelControlAccentColor, range: NSRange(location: 0, length: updatedText.length))
                    return .text(updatedText)
                case let .icon(icon):
                    if let iconImage = generateTintedImage(image: icon, color: theme.chat.inputPanel.panelControlAccentColor) {
                        return .icon(iconImage)
                    } else {
                        return .icon(icon)
                    }
                }
            }
            
            if let text = self.textNode.attributedText {
                let updatedText = NSMutableAttributedString(attributedString: text)
                updatedText.addAttribute(.foregroundColor, value: self.textIsOptions ? self.theme.chat.inputPanel.secondaryTextColor : self.theme.chat.inputPanel.primaryTextColor, range: NSRange(location: 0, length: updatedText.length))
                self.textNode.attributedText = updatedText
            }
            self.textNode.spoilerColor = self.theme.chat.inputPanel.secondaryTextColor
            
            if let (size, inset, interfaceState) = self.validLayout {
                self.updateState(size: size, inset: inset, interfaceState: interfaceState)
            }
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override public func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, inset, interfaceState)
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 45.0))
        let leftInset: CGFloat = 55.0 + inset
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        let closeButtonFrame = CGRect(origin: CGPoint(x: bounds.width - closeButtonSize.width - inset, y: 2.0), size: closeButtonSize)
        self.closeButton.frame = closeButtonFrame
        
        self.actionArea.frame = CGRect(origin: CGPoint(x: leftInset, y: 2.0), size: CGSize(width: closeButtonFrame.minX - leftInset, height: bounds.height))

        if self.lineNode.supernode == self {
            self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        }
        
        if let icon = self.iconView.image {
            self.iconView.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
        }
        
        var imageTextInset: CGFloat = 0.0
        if !self.imageNode.isHidden {
            imageTextInset = 9.0 + 35.0
        }
        if self.imageNode.supernode == self {
            self.imageNode.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 8.0), size: CGSize(width: 35.0, height: 35.0))
        }
        
        let titleSize = self.titleNode.update(constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        if self.titleNode.supernode == self {
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 7.0), size: titleSize)
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        let textFrame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset - self.textNode.insets.left, y: 25.0 - self.textNode.insets.top), size: textSize)
        if self.textNode.supernode == self {
            self.textNode.frame = textFrame
        }
    }
    
    @objc private func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    private var previousTapTimestamp: Double?
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CFAbsoluteTimeGetCurrent()
            if let previousTapTimestamp = self.previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                return
            }
            self.previousTapTimestamp = CFAbsoluteTimeGetCurrent()
            self.interfaceInteraction?.presentReplyOptions(self)
            Queue.mainQueue().after(1.5) {
                self.updateThemeAndStrings(theme: self.theme, strings: self.strings, force: true)
            }
            
            let _ = ApplicationSpecificNotice.incrementChatReplyOptionsTip(accountManager: self.context.sharedContext.accountManager, count: 3).start()
        }
    }
    
    @objc func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        if case .began = recognizer.state {
            self.interfaceInteraction?.navigateToMessage(self.messageId, false, true, ChatLoadingMessageSubject.generic)
        }
    }
}
