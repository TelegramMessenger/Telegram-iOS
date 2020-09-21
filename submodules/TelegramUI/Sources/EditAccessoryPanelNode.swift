import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import ActivityIndicator
import AccountContext
import RadialStatusNode
import PhotoResources
import TelegramStringFormatting

final class EditAccessoryPanelNode: AccessoryPanelNode {
    let messageId: MessageId
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNode
    let imageNode: TransformImageNode
    
    private let actionArea: AccessibilityAreaNode
    
    private let activityIndicator: ActivityIndicator
    private let statusNode: RadialStatusNode
    private let tapNode: ASDisplayNode
    
    private let messageDisposable = MetaDisposable()
    private let editingMessageDisposable = MetaDisposable()
    
    private var currentMessage: Message?
    private var currentEditMediaReference: AnyMediaReference?
    private var previousMediaReference: AnyMediaReference?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.editingMessageDisposable.set(statuses.editingMessage.start(next: { [weak self] value in
                    if let strongSelf = self {
                        if let value = value {
                            if value.isZero {
                                strongSelf.activityIndicator.isHidden = false
                                strongSelf.statusNode.transitionToState(.none, completion: {})
                            } else {
                                strongSelf.activityIndicator.isHidden = true
                            strongSelf.statusNode.transitionToState(.progress(color: strongSelf.theme.chat.inputPanel.panelControlAccentColor, lineWidth: nil, value: CGFloat(value), cancelEnabled: false), completion: {})
                            }
                        } else {
                            strongSelf.activityIndicator.isHidden = true
                            strongSelf.statusNode.transitionToState(.none, completion: {})
                        }
                    }
                }))
            }
        }
    }
    
    private let context: AccountContext
    var theme: PresentationTheme
    var strings: PresentationStrings
    var nameDisplayOrder: PresentationPersonNameOrder
    
    init(context: AccountContext, messageId: MessageId, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.messageId = messageId
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        
        self.closeButton = ASButtonNode()
        self.closeButton.accessibilityLabel = strings.VoiceOver_DiscardPreparedContent
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        self.imageNode.isUserInteractionEnabled = true
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.chat.inputPanel.panelControlAccentColor, 22.0, 2.0, false))
        self.activityIndicator.isHidden = true
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        self.tapNode = ASDisplayNode()
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.tapNode)
        self.addSubnode(self.actionArea)
        self.messageDisposable.set((context.account.postbox.messageAtId(messageId)
        |> deliverOnMainQueue).start(next: { [weak self] message in
            self?.updateMessage(message)
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
        self.editingMessageDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.tapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.contentTap(_:))))
    }
    
    private func updateMessage(_ message: Message?) {
        self.currentMessage = message
        
        var text = ""
        if let message = message {
            var effectiveMessage = message
            if let currentEditMediaReference = self.currentEditMediaReference {
                effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMediaReference.media])
            }
            (text, _) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: effectiveMessage, strings: self.strings, nameDisplayOrder: self.nameDisplayOrder, accountPeerId: self.context.account.peerId)
        }
        
        var updatedMediaReference: AnyMediaReference?
        var imageDimensions: CGSize?
        if let message = message, !message.containsSecretMedia {
            var candidateMediaReference: AnyMediaReference?
            if let currentEditMedia = self.currentEditMediaReference {
                candidateMediaReference = currentEditMedia
            } else {
                for media in message.media {
                    if media is TelegramMediaImage || media is TelegramMediaFile {
                        candidateMediaReference = .message(message: MessageReference(message), media: media)
                        break
                    }
                }
            }
            
            if let imageReference = candidateMediaReference?.concrete(TelegramMediaImage.self) {
                updatedMediaReference = imageReference.abstract
                if let representation = largestRepresentationForPhoto(imageReference.media) {
                    imageDimensions = representation.dimensions.cgSize
                }
            } else if let fileReference = candidateMediaReference?.concrete(TelegramMediaFile.self) {
                updatedMediaReference = fileReference.abstract
                if !fileReference.media.isInstantVideo, let representation = largestImageRepresentation(fileReference.media.previewRepresentations), !fileReference.media.isSticker {
                    imageDimensions = representation.dimensions.cgSize
                }
            }
        }
        
        let imageNodeLayout = self.imageNode.asyncLayout()
        var applyImage: (() -> Void)?
        if let imageDimensions = imageDimensions {
            let boundingSize = CGSize(width: 35.0, height: 35.0)
            applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
        }
        
        var mediaUpdated = false
        if let updatedMediaReference = updatedMediaReference, let previousMediaReference = self.previousMediaReference {
            mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
        } else if (updatedMediaReference != nil) != (self.previousMediaReference != nil) {
            mediaUpdated = true
        }
        self.previousMediaReference = updatedMediaReference
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        if mediaUpdated {
            if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                    updateImageSignal = chatMessagePhotoThumbnail(account: self.context.account, photoReference: imageReference)
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isVideo {
                        updateImageSignal = chatMessageVideoThumbnail(account: self.context.account, fileReference: fileReference)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: self.context.account, fileReference: fileReference, representation: iconImageRepresentation)
                    }
                }
            } else {
                updateImageSignal = .single({ _ in return nil })
            }
        }
        
        let isMedia: Bool
        if let message = message {
            var effectiveMessage = message
            if let currentEditMediaReference = self.currentEditMediaReference {
                effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMediaReference.media])
            }
            switch messageContentKind(contentSettings: self.context.currentContentSettings.with { $0 }, message: effectiveMessage, strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: self.context.account.peerId) {
                case .text:
                    isMedia = false
                default:
                    isMedia = true
            }
        } else {
            isMedia = false
        }
        
        let canEditMedia: Bool
        if let message = message, !messageMediaEditingOptions(message: message).isEmpty {
            canEditMedia = true
        } else {
            canEditMedia = false
        }
        
        let titleString = canEditMedia ? self.strings.Conversation_EditingCaptionPanelTitle : self.strings.Conversation_EditingMessagePanelTitle
        self.titleNode.attributedText = NSAttributedString(string: titleString, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: isMedia ? self.theme.chat.inputPanel.secondaryTextColor : self.theme.chat.inputPanel.primaryTextColor)
        
        let headerString: String = titleString
        self.actionArea.accessibilityLabel = "\(headerString).\n\(text)"
        
        if let applyImage = applyImage {
            applyImage()
            self.imageNode.isHidden = false
        } else {
            self.imageNode.isHidden = true
        }
        
        if let updateImageSignal = updateImageSignal {
            self.imageNode.setSignal(.single({ arguments in
                /*let context = DrawingContext(size: arguments.boundingSize)
                context.withContext { c in
                    c.setFillColor(UIColor.white.cgColor)
                    c.fill(CGRect(origin: CGPoint(), size: context.size))
                }
                return context*/
                return nil
            }) |> then(updateImageSignal))
        }
        
        self.setNeedsLayout()
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
    
    override func updateState(size: CGSize, interfaceState: ChatPresentationInterfaceState) {
        let editMediaReference = interfaceState.editMessageState?.mediaReference
        var updatedEditMedia = false
        if let currentEditMediaReference = self.currentEditMediaReference, let editMediaReference = editMediaReference {
            if !currentEditMediaReference.media.isEqual(to: editMediaReference.media) {
                updatedEditMedia = true
            }
        } else if (editMediaReference != nil) != (self.currentEditMediaReference != nil) {
            updatedEditMedia = true
        }
        if updatedEditMedia {
            if let editMediaReference = editMediaReference {
                self.currentEditMediaReference = editMediaReference
            } else {
                self.currentEditMediaReference = nil
            }
            self.updateMessage(self.currentMessage)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let leftInset: CGFloat = 55.0
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: 18.0, y: 15.0), size: indicatorSize)
        self.statusNode.frame = CGRect(origin: CGPoint(x: 18.0, y: 15.0), size: indicatorSize).insetBy(dx: -2.0, dy: -2.0)
        
        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        let closeButtonFrame = CGRect(origin: CGPoint(x: bounds.width - rightInset - closeButtonSize.width + 16.0, y: 2.0), size: closeButtonSize)
        self.closeButton.frame = closeButtonFrame
        
        self.actionArea.frame = CGRect(origin: CGPoint(x: leftInset, y: 2.0), size: CGSize(width: closeButtonFrame.minX - leftInset, height: bounds.height))
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
        var imageTextInset: CGFloat = 0.0
        if !self.imageNode.isHidden {
            imageTextInset = 9.0 + 35.0
        }
        self.imageNode.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 8.0), size: CGSize(width: 35.0, height: 35.0))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 7.0), size: titleSize)
        
        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 25.0), size: textSize)
        
        self.tapNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: bounds.width - leftInset - rightInset - closeButtonSize.width - 4.0, height: bounds.height))
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    @objc func contentTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, let message = self.currentMessage {
            self.interfaceInteraction?.navigateToMessage(message.id)
        }
    }
}
