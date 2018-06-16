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
    let imageNode: TransformImageNode
    
    private let activityIndicator: ActivityIndicator
    private let statusNode: RadialStatusNode
    
    private let messageDisposable = MetaDisposable()
    private let editingMessageDisposable = MetaDisposable()
    
    private var currentMessage: Message?
    private var currentEditMedia: Media?
    private var previousMedia: Media?
    
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
                            strongSelf.statusNode.transitionToState(.progress(color: strongSelf.theme.chat.inputPanel.panelControlAccentColor, value: CGFloat(value), cancelEnabled: false), completion: {})
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
    
    private let account: Account
    var theme: PresentationTheme
    var strings: PresentationStrings
    
    init(account: Account, messageId: MessageId, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.messageId = messageId
        self.theme = theme
        self.strings = strings
        
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
        self.textNode.isUserInteractionEnabled = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        self.imageNode.isUserInteractionEnabled = true
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.chat.inputPanel.panelControlAccentColor, 22.0, 2.0))
        self.activityIndicator.isHidden = true
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.statusNode)
        
        self.messageDisposable.set((account.postbox.messageAtId(messageId)
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
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:))))
        self.textNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:))))
    }
    
    
    
    private func updateMessage(_ message: Message?) {
        self.currentMessage = message
        
        var text = ""
        if let message = message {
            var effectiveMessage = message
            if let currentEditMedia = self.currentEditMedia {
                effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMedia])
            }
            (text, _) = descriptionStringForMessage(effectiveMessage, strings: self.strings, accountPeerId: self.account.peerId)
        }
        
        var updatedMedia: Media?
        var imageDimensions: CGSize?
        if let message = message, !message.containsSecretMedia {
            var candidateMedia: Media?
            if let currentEditMedia = self.currentEditMedia {
                candidateMedia = currentEditMedia
            } else {
                for media in message.media {
                    if media is TelegramMediaImage || media is TelegramMediaFile {
                        candidateMedia = media
                        break
                    }
                }
            }
            
            if let image = candidateMedia as? TelegramMediaImage {
                updatedMedia = image
                if let representation = largestRepresentationForPhoto(image) {
                    imageDimensions = representation.dimensions
                }
            } else if let file = candidateMedia as? TelegramMediaFile {
                updatedMedia = file
                if !file.isInstantVideo, let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                    imageDimensions = representation.dimensions
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
        if let updatedMedia = updatedMedia, let previousMedia = self.previousMedia {
            mediaUpdated = !updatedMedia.isEqual(previousMedia)
        } else if (updatedMedia != nil) != (self.previousMedia != nil) {
            mediaUpdated = true
        }
        self.previousMedia = updatedMedia
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        if mediaUpdated {
            if let updatedMedia = updatedMedia, imageDimensions != nil {
                if let image = updatedMedia as? TelegramMediaImage {
                    updateImageSignal = chatMessagePhotoThumbnail(account: self.account, photo: image)
                } else if let file = updatedMedia as? TelegramMediaFile {
                    if file.isVideo {
                        updateImageSignal = chatMessageVideoThumbnail(account: self.account, file: file)
                    } else if let iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
                        updateImageSignal = chatWebpageSnippetPhoto(account: self.account, photo: tmpImage)
                    }
                }
            } else {
                updateImageSignal = .single({ _ in return nil })
            }
        }
        
        let isMedia: Bool
        if let message = message {
            var effectiveMessage = message
            if let currentEditMedia = self.currentEditMedia {
                effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMedia])
            }
            switch messageContentKind(effectiveMessage, strings: strings, accountPeerId: self.account.peerId) {
                case .text:
                    isMedia = false
                default:
                    isMedia = true
            }
        } else {
            isMedia = false
        }
        
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Conversation_EditingMessagePanelTitle, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: isMedia ? self.theme.chat.inputPanel.secondaryTextColor : self.theme.chat.inputPanel.primaryTextColor)
        
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
        let editMedia = interfaceState.editMessageState?.media
        var updatedEditMedia = false
        if let currentEditMedia = self.currentEditMedia, let editMedia = editMedia {
            if !currentEditMedia.isEqual(editMedia) {
                updatedEditMedia = true
            }
        } else if (editMedia != nil) != (currentEditMedia != nil) {
            updatedEditMedia = true
        }
        if updatedEditMedia {
            self.currentEditMedia = editMedia
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
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
        var imageTextInset: CGFloat = 0.0
        if !self.imageNode.isHidden {
            imageTextInset = 9.0 + 35.0
        }
        self.imageNode.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 8.0), size: CGSize(width: 35.0, height: 35.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 7.0), size: titleSize)
        
        let textSize = self.textNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    @objc func imageTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.interfaceInteraction?.setupEditMessageMedia()
        }
    }
}
