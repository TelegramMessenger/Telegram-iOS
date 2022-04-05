import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import InvisibleInkDustNode

enum ChatMessageReplyInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageReplyInfoNode: ASDisplayNode {
    private let contentNode: ASDisplayNode
    private let lineNode: ASImageNode
    private var titleNode: TextNode?
    private var textNode: TextNode?
    private var dustNode: InvisibleInkDustNode?
    private var imageNode: TransformImageNode?
    private var previousMediaReference: AnyMediaReference?
    
    override init() {
        self.contentNode = ASDisplayNode()
        self.contentNode.isUserInteractionEnabled = false
        self.contentNode.displaysAsynchronously = false
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
    
    class func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (_ theme: ChatPresentationData, _ strings: PresentationStrings, _ context: AccountContext, _ type: ChatMessageReplyInfoType, _ message: Message, _ parentMessage: Message, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageReplyInfoNode) {
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        let imageNodeLayout = TransformImageNode.asyncLayout(maybeNode?.imageNode)
        let previousMediaReference = maybeNode?.previousMediaReference
        
        return { presentationData, strings, context, type, message, parentMessage, constrainedSize in
            let fontSize = floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let titleFont = Font.medium(fontSize)
            let textFont = Font.regular(fontSize)
            
            let author = message.effectiveAuthor
            var titleString = author.flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) ?? strings.User_DeletedAccount
            
            if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) || parentMessage.forwardInfo != nil {
                if let author = forwardInfo.author {
                    titleString = EnginePeer(author).displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
                } else if let authorSignature = forwardInfo.authorSignature {
                    titleString = authorSignature
                }
            }
            
            let (textString, isMedia, isText) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: context.account.peerId)
            
            let placeholderColor: UIColor =  message.effectivelyIncoming(context.account.peerId) ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
            let titleColor: UIColor
            let lineImage: UIImage?
            let textColor: UIColor
            let dustColor: UIColor
                
            switch type {
                case let .bubble(incoming):
                    titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.accentTextColor : presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    lineImage = incoming ? PresentationResourcesChat.chatBubbleVerticalLineIncomingImage(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleVerticalLineOutgoingImage(presentationData.theme.theme)
                    if isMedia {
                        textColor = incoming ? presentationData.theme.theme.chat.message.incoming.secondaryTextColor : presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    } else {
                        textColor = incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor
                    }
                    dustColor = incoming ? presentationData.theme.theme.chat.message.incoming.secondaryTextColor : presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                case .standalone:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    titleColor = serviceColor.primaryText
                    
                    let graphics = PresentationResourcesChat.additionalGraphics(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
                    lineImage = graphics.chatServiceVerticalLineImage
                    textColor = titleColor
                    dustColor = titleColor
            }
            
            
            let messageText: NSAttributedString
            if isText {
                let entities = (message.textEntitiesAttribute?.entities ?? []).filter { entity in
                    if case .Spoiler = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                if entities.count > 0 {
                    messageText = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false)
                } else {
                    messageText = NSAttributedString(string: textString, font: textFont, textColor: textColor)
                }
            } else {
                messageText = NSAttributedString(string: textString, font: textFont, textColor: textColor)
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
                    } else if let file = media as? TelegramMediaFile, file.isVideo && !file.isVideoSticker {
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
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: contrainedTextSize, alignment: .natural, cutout: nil, insets: textInsets))
            
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
                        updateImageSignal = chatWebpageSnippetFile(account: context.account, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
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
                node.imageNode?.captureProtected = message.isCopyProtected()
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0, y: spacing - textInsets.top + 1.0), size: titleLayout.size)
                
                let textFrame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0, y: titleNode.frame.maxY - textInsets.bottom + spacing - textInsets.top - 2.0), size: textLayout.size)
                textNode.frame = textFrame
                
                if !textLayout.spoilers.isEmpty {
                    let dustNode: InvisibleInkDustNode
                    if let current = node.dustNode {
                        dustNode = current
                    } else {
                        dustNode = InvisibleInkDustNode(textNode: nil)
                        dustNode.isUserInteractionEnabled = false
                        node.dustNode = dustNode
                        node.contentNode.insertSubnode(dustNode, aboveSubnode: textNode)
                    }
                    dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
                    dustNode.update(size: dustNode.frame.size, color: dustColor, textColor: dustColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                } else if let dustNode = node.dustNode {
                    dustNode.removeFromSupernode()
                    node.dustNode = nil
                }
                    
                node.lineNode.image = lineImage
                node.lineNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 3.0), size: CGSize(width: 2.0, height: max(0.0, size.height - 4.0)))
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }

    func animateFromInputPanel(sourceReplyPanel: ChatMessageTransitionNode.ReplyPanel, unclippedTransitionNode: ASDisplayNode? = nil, localRect: CGRect, transition: CombinedTransition) -> CGPoint {
        let sourceParentNode = ASDisplayNode()

        let sourceParentOffset: CGPoint

        if let unclippedTransitionNode = unclippedTransitionNode {
            unclippedTransitionNode.addSubnode(sourceParentNode)
            sourceParentNode.frame = sourceReplyPanel.relativeSourceRect
            sourceParentOffset = self.view.convert(CGPoint(), to: sourceParentNode.view)
            sourceParentNode.clipsToBounds = true

            let panelOffset = sourceReplyPanel.relativeTargetRect.minY - sourceReplyPanel.relativeSourceRect.minY

            sourceParentNode.frame = sourceParentNode.frame.offsetBy(dx: 0.0, dy: panelOffset)
            sourceParentNode.bounds = sourceParentNode.bounds.offsetBy(dx: 0.0, dy: panelOffset)
            transition.vertical.animatePositionAdditive(layer: sourceParentNode.layer, offset: CGPoint(x: 0.0, y: -panelOffset))
            transition.vertical.animateOffsetAdditive(layer: sourceParentNode.layer, offset: -panelOffset)
        } else {
            self.addSubnode(sourceParentNode)
            sourceParentOffset = CGPoint()
        }

        sourceParentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak sourceParentNode] _ in
            sourceParentNode?.removeFromSupernode()
        })

        if let titleNode = self.titleNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.titleNode.frame.minX - titleNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.titleNode.frame.midY - titleNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: titleNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: titleNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.titleNode)

            titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.titleNode.frame = sourceReplyPanel.titleNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.titleNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.titleNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        if let textNode = self.textNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.textNode.frame.minX - textNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.textNode.frame.midY - textNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: textNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: textNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.textNode)

            textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.textNode.frame = sourceReplyPanel.textNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.textNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.textNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        if let imageNode = self.imageNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.imageNode.frame.midX - imageNode.frame.midX,
                y: localRect.minY + sourceReplyPanel.imageNode.frame.midY - imageNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: imageNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: imageNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.imageNode)

            imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.imageNode.frame = sourceReplyPanel.imageNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.imageNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.imageNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        do {
            let lineNode = self.lineNode

            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.lineNode.frame.minX - lineNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.lineNode.frame.minY - lineNode.frame.minY
            )

            transition.horizontal.animatePositionAdditive(node: lineNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: lineNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.lineNode)

            lineNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.lineNode.frame = sourceReplyPanel.lineNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.lineNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.lineNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)

            return offset
        }
    }
}
