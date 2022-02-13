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
import InvisibleInkDustNode
import TextFormat
import ChatPresentationInterfaceState

final class ReplyAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageId: MessageId
    
    private var previousMediaReference: AnyMediaReference?
    
    let closeButton: HighlightableButtonNode
    let lineNode: ASImageNode
    let iconNode: ASImageNode
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNode
    var dustNode: InvisibleInkDustNode?
    let imageNode: TransformImageNode
    
    private let actionArea: AccessibilityAreaNode
    
    var theme: PresentationTheme
    var strings: PresentationStrings
    
    private var validLayout: (size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState)?
    
    init(context: AccountContext, messageId: MessageId, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat) {
        self.messageId = messageId
        
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
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = PresentationResourcesChat.chatInputPanelReplyIconImage(theme)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        self.textNode.insets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.actionArea)
        
        self.messageDisposable.set((context.account.postbox.messageView(messageId)
        |> deliverOnMainQueue).start(next: { [weak self] messageView in
            if let strongSelf = self {
                if messageView.message == nil {
                    Queue.mainQueue().justDispatch {
                        strongSelf.interfaceInteraction?.setupReplyMessage(nil, { _ in })
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
                    (text, _, isText) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: context.account.peerId)
                } else {
                    isMedia = false
                }

                let textFont = Font.regular(14.0)
                let messageText: NSAttributedString
                if isText, let message = message {
                    let entities = (message.textEntitiesAttribute?.entities ?? []).filter { entity in
                        if case .Spoiler = entity.type {
                            return true
                        } else {
                            return false
                        }
                    }
                    let textColor = strongSelf.theme.chat.inputPanel.primaryTextColor
                    if entities.count > 0 {
                        messageText = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont,  underlineLinks: false)
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
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                if mediaUpdated {
                    if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                        if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                            updateImageSignal = chatMessagePhotoThumbnail(account: context.account, photoReference: imageReference)
                        } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                            if fileReference.media.isVideo {
                                updateImageSignal = chatMessageVideoThumbnail(account: context.account, fileReference: fileReference)
                            } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                                updateImageSignal = chatWebpageSnippetFile(account: context.account, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                            }
                        }
                    } else {
                        updateImageSignal = .single({ _ in return nil })
                    }
                }
                                
                strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.strings.Conversation_ReplyMessagePanelTitle(authorName).string, font: Font.medium(14.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                strongSelf.textNode.attributedText = messageText
                                
                let headerString: String
                if let message = message, message.flags.contains(.Incoming), let author = message.author {
                    headerString = "Reply to message. From: \(EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder))"
                } else if let message = message, !message.flags.contains(.Incoming) {
                    headerString = "Reply to your message"
                } else {
                    headerString = "Reply to message"
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
        if self.theme !== theme {
            self.theme = theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            self.iconNode.image = PresentationResourcesChat.chatInputPanelReplyIconImage(theme)
            
            if let text = self.titleNode.attributedText?.string {
                self.titleNode.attributedText = NSAttributedString(string: text, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            }
            
            if let text = self.textNode.attributedText?.string {
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
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
        let leftInset: CGFloat = 55.0
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
        
        if let icon = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
        }
        
        var imageTextInset: CGFloat = 0.0
        if !self.imageNode.isHidden {
            imageTextInset = 9.0 + 35.0
        }
        if self.imageNode.supernode == self {
            self.imageNode.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 8.0), size: CGSize(width: 35.0, height: 35.0))
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        if self.titleNode.supernode == self {
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset - self.titleNode.insets.left, y: 7.0 - self.titleNode.insets.top), size: titleSize)
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        let textFrame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset - self.textNode.insets.left, y: 25.0 - self.textNode.insets.top), size: textSize)
        if self.textNode.supernode == self {
            self.textNode.frame = textFrame
        }
        
        if let textLayout = self.textNode.cachedLayout, !textLayout.spoilers.isEmpty {
            if self.dustNode == nil {
                let dustNode = InvisibleInkDustNode(textNode: nil)
                self.dustNode = dustNode
                self.textNode.supernode?.insertSubnode(dustNode, aboveSubnode: self.textNode)
                
            }
            if let dustNode = self.dustNode {
                dustNode.update(size: textFrame.size, color: self.theme.chat.inputPanel.secondaryTextColor, textColor: self.theme.chat.inputPanel.primaryTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
            }
        } else if let dustNode = self.dustNode {
            self.dustNode = nil
            dustNode.removeFromSupernode()
        }
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.interfaceInteraction?.navigateToMessage(self.messageId, false, true, .generic)
        }
    }
}
