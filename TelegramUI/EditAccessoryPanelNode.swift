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
    
    let activityIndicator: ActivityIndicator
    
    private let messageDisposable = MetaDisposable()
    private let editingMessageDisposable = MetaDisposable()
    
    private var previousMedia: Media?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.editingMessageDisposable.set(statuses.editingMessage.start(next: { [weak self] value in
                    if let strongSelf = self {
                        if value {
                            if strongSelf.activityIndicator.supernode == nil {
                                strongSelf.addSubnode(strongSelf.activityIndicator)
                            }
                        } else if strongSelf.activityIndicator.supernode != nil {
                            strongSelf.activityIndicator.removeFromSupernode()
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
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.chat.inputPanel.panelControlAccentColor, 22.0, 2.0))
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        
        self.messageDisposable.set((account.postbox.messageAtId(messageId)
            |> deliverOnMainQueue).start(next: { [weak self] message in
                if let strongSelf = self {
                    var text = ""
                    if let message = message {
                        (text, _) = descriptionStringForMessage(message, strings: strings, accountPeerId: account.peerId)
                    }
                    
                    var updatedMedia: Media?
                    var imageDimensions: CGSize?
                    if let message = message, !message.containsSecretMedia {
                        for media in message.media {
                            if let image = media as? TelegramMediaImage {
                                updatedMedia = image
                                if let representation = largestRepresentationForPhoto(image) {
                                    imageDimensions = representation.dimensions
                                }
                                break
                            } else if let file = media as? TelegramMediaFile {
                                updatedMedia = file
                                if !file.isInstantVideo, let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                                    imageDimensions = representation.dimensions
                                }
                                break
                            }
                        }
                    }
                    
                    let imageNodeLayout = strongSelf.imageNode.asyncLayout()
                    var applyImage: (() -> Void)?
                    if let imageDimensions = imageDimensions {
                        let boundingSize = CGSize(width: 35.0, height: 35.0)
                        applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                    }
                    
                    var mediaUpdated = false
                    if let updatedMedia = updatedMedia, let previousMedia = strongSelf.previousMedia {
                        mediaUpdated = !updatedMedia.isEqual(previousMedia)
                    } else if (updatedMedia != nil) != (strongSelf.previousMedia != nil) {
                        mediaUpdated = true
                    }
                    strongSelf.previousMedia = updatedMedia
                    
                    var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                    if mediaUpdated {
                        if let updatedMedia = updatedMedia, imageDimensions != nil {
                            if let image = updatedMedia as? TelegramMediaImage {
                                updateImageSignal = chatMessagePhotoThumbnail(account: account, photo: image)
                            } else if let file = updatedMedia as? TelegramMediaFile {
                                if file.isVideo {
                                    updateImageSignal = chatMessageVideoThumbnail(account: account, file: file)
                                } else if let iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
                                    updateImageSignal = chatWebpageSnippetPhoto(account: account, photo: tmpImage)
                                }
                            }
                        } else {
                            updateImageSignal = .single({ _ in return nil })
                        }
                    }
                    
                    let isMedia: Bool
                    if let message = message {
                        switch messageContentKind(message, strings: strings, accountPeerId: account.peerId) {
                        case .text:
                            isMedia = false
                        default:
                            isMedia = true
                        }
                    } else {
                        isMedia = false
                    }
                    
                    strongSelf.titleNode.attributedText = NSAttributedString(string: strings.Conversation_EditingMessagePanelTitle, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                    strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: isMedia ? strongSelf.theme.chat.inputPanel.secondaryTextColor : strongSelf.theme.chat.inputPanel.primaryTextColor)
                    
                    if let applyImage = applyImage {
                        applyImage()
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.imageNode.isHidden = true
                    }
                    
                    if let updateImageSignal = updateImageSignal {
                        strongSelf.imageNode.setSignal(updateImageSignal)
                    }
                    
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
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        activityIndicator.frame = CGRect(origin: CGPoint(x: 18.0, y: 15.0), size: indicatorSize)
        
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
}
