import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting

enum ChatMessageReplyInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageReplyInfoNode: ASDisplayNode {
    private let contentNode: ASDisplayNode
    private let lineNode: ASImageNode
    private var titleNode: TextNode?
    private var textNode: TextNode?
    private var imageNode: TransformImageNode?
    private var previousMediaReference: AnyMediaReference?
    
    override init() {
        self.contentNode = ASDisplayNode()
        self.contentNode.isUserInteractionEnabled = false
        self.contentNode.displaysAsynchronously = true
        self.contentNode.contentMode = .left
        self.contentNode.contentsScale = UIScreenScale
        
        self.lineNode = ASImageNode()
        self.lineNode.displaysAsynchronously = false
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.lineNode)
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (_ theme: ChatPresentationData, _ strings: PresentationStrings, _ context: AccountContext, _ type: ChatMessageReplyInfoType, _ message: Message, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageReplyInfoNode) {
        
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        let imageNodeLayout = TransformImageNode.asyncLayout(maybeNode?.imageNode)
        let previousMediaReference = maybeNode?.previousMediaReference
        
        return { presentationData, strings, context, type, message, constrainedSize in
            let fontSize = floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let titleFont = Font.medium(fontSize)
            let textFont = Font.regular(fontSize)
            
            let titleString = message.effectiveAuthor?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) ?? strings.User_DeletedAccount
            let (textString, isMedia) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: message, strings: strings, nameDisplayOrder: presentationData.nameDisplayOrder, accountPeerId: context.account.peerId)
            
            let placeholderColor: UIColor =  message.effectivelyIncoming(context.account.peerId) ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
            let titleColor: UIColor
            let lineImage: UIImage?
            let textColor: UIColor
                
            switch type {
                case let .bubble(incoming):
                    titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.accentTextColor : presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    lineImage = incoming ? PresentationResourcesChat.chatBubbleVerticalLineIncomingImage(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleVerticalLineOutgoingImage(presentationData.theme.theme)
                    if isMedia {
                        textColor = incoming ? presentationData.theme.theme.chat.message.incoming.secondaryTextColor : presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    } else {
                        textColor = incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor
                    }
                case .standalone:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    titleColor = serviceColor.primaryText
                    
                    let graphics = PresentationResourcesChat.additionalGraphics(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
                    lineImage = graphics.chatServiceVerticalLineImage
                    textColor = titleColor
            }
            
            var leftInset: CGFloat = 11.0
            let spacing: CGFloat = 2.0
            
            var updatedMediaReference: AnyMediaReference?
            var imageDimensions: CGSize?
            var hasRoundImage = false
            if !message.containsSecretMedia {
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        updatedMediaReference = .message(message: MessageReference(message), media: image)
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        break
                    } else if let file = media as? TelegramMediaFile, file.isVideo {
                        updatedMediaReference = .message(message: MessageReference(message), media: file)
                        
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions.cgSize
                        } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        if file.isInstantVideo {
                            hasRoundImage = true
                        }
                        break
                    }
                }
            }
            
            var imageTextInset: CGFloat = 0.0
            if let _ = imageDimensions {
                imageTextInset += floor(presentationData.fontSize.baseDisplaySize * 32.0 / 17.0)
            }
            
            let maximumTextWidth = max(0.0, constrainedSize.width - imageTextInset)
            
            let contrainedTextSize = CGSize(width: maximumTextWidth, height: constrainedSize.height)
            
            let textInsets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
            
            let (titleLayout, titleApply) = titleNodeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleString, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: contrainedTextSize, alignment: .natural, cutout: nil, insets: textInsets))
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: textString, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: contrainedTextSize, alignment: .natural, cutout: nil, insets: textInsets))
            
            let imageSide = titleLayout.size.height + textLayout.size.height - 16.0
            
            var applyImage: (() -> TransformImageNode)?
            if let imageDimensions = imageDimensions {
                let boundingSize = CGSize(width: imageSide, height: imageSide)
                leftInset += imageSide + 2.0
                var radius: CGFloat = 2.0
                var imageSize = imageDimensions.aspectFilled(boundingSize)
                if hasRoundImage {
                    radius = boundingSize.width / 2.0
                    imageSize.width += 2.0
                    imageSize.height += 2.0
                }
                applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: placeholderColor))
            }
            
            var mediaUpdated = false
            if let updatedMediaReference = updatedMediaReference, let previousMediaReference = previousMediaReference {
                mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
            } else if (updatedMediaReference != nil) != (previousMediaReference != nil) {
                mediaUpdated = true
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let updatedMediaReference = updatedMediaReference, mediaUpdated && imageDimensions != nil {
                if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                    updateImageSignal = chatMessagePhotoThumbnail(account: context.account, photoReference: imageReference)
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isVideo {
                        updateImageSignal = chatMessageVideoThumbnail(account: context.account, fileReference: fileReference)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: context.account, fileReference: fileReference, representation: iconImageRepresentation)
                    }
                }
            }
            
            let size = CGSize(width: max(titleLayout.size.width - textInsets.left - textInsets.right, textLayout.size.width - textInsets.left - textInsets.right) + leftInset, height: titleLayout.size.height + textLayout.size.height - 2 * (textInsets.top + textInsets.bottom) + 2 * spacing)
            
            return (size, {
                let node: ChatMessageReplyInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageReplyInfoNode()
                }
                
                node.previousMediaReference = updatedMediaReference
                
                node.titleNode?.displaysAsynchronously = !presentationData.isPreview
                node.textNode?.displaysAsynchronously = !presentationData.isPreview
                
                let titleNode = titleApply()
                let textNode = textApply()
                
                if node.titleNode == nil {
                    titleNode.isUserInteractionEnabled = false
                    node.titleNode = titleNode
                    node.contentNode.addSubnode(titleNode)
                }
                
                if node.textNode == nil {
                    textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode)
                }
                
                if let applyImage = applyImage {
                    let imageNode = applyImage()
                    if node.imageNode == nil {
                        imageNode.isLayerBacked = !smartInvertColorsEnabled()
                        node.addSubnode(imageNode)
                        node.imageNode = imageNode
                    }
                    imageNode.frame = CGRect(origin: CGPoint(x: 8.0, y: 4.0 + UIScreenPixel), size: CGSize(width: imageSide, height: imageSide))
                    
                    if let updateImageSignal = updateImageSignal {
                        imageNode.setSignal(updateImageSignal)
                    }
                } else if let imageNode = node.imageNode {
                    imageNode.removeFromSupernode()
                    node.imageNode = nil
                }
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset - textInsets.left, y: spacing - textInsets.top), size: titleLayout.size)
                textNode.frame = CGRect(origin: CGPoint(x: leftInset - textInsets.left, y: titleNode.frame.maxY - textInsets.bottom + spacing - textInsets.top), size: textLayout.size)
                
                node.lineNode.image = lineImage
                node.lineNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 3.0), size: CGSize(width: 2.0, height: max(0.0, size.height - 5.0)))
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
}
