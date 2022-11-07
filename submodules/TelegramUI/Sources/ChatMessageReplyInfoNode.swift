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
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer

enum ChatMessageReplyInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageReplyInfoNode: ASDisplayNode {
    class Arguments {
        let presentationData: ChatPresentationData
        let strings: PresentationStrings
        let context: AccountContext
        let type: ChatMessageReplyInfoType
        let message: Message
        let parentMessage: Message
        let constrainedSize: CGSize
        let animationCache: AnimationCache?
        let animationRenderer: MultiAnimationRenderer?
        
        init(
            presentationData: ChatPresentationData,
            strings: PresentationStrings,
            context: AccountContext,
            type: ChatMessageReplyInfoType,
            message: Message,
            parentMessage: Message,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?
        ) {
            self.presentationData = presentationData
            self.strings = strings
            self.context = context
            self.type = type
            self.message = message
            self.parentMessage = parentMessage
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
            }
        }
    }
    
    private let contentNode: ASDisplayNode
    private let lineNode: ASImageNode
    private var titleNode: TextNode?
    private var textNode: TextNodeWithEntities?
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
    
    class func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (_ arguments: Arguments) -> (CGSize, (Bool) -> ChatMessageReplyInfoNode) {
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
        let imageNodeLayout = TransformImageNode.asyncLayout(maybeNode?.imageNode)
        let previousMediaReference = maybeNode?.previousMediaReference
        
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let titleFont = Font.medium(fontSize)
            let textFont = Font.regular(fontSize)
            
            let author = arguments.message.effectiveAuthor
            var titleString = author.flatMap(EnginePeer.init)?.displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder) ?? arguments.strings.User_DeletedAccount
            
            if let forwardInfo = arguments.message.forwardInfo, forwardInfo.flags.contains(.isImported) || arguments.parentMessage.forwardInfo != nil {
                if let author = forwardInfo.author {
                    titleString = EnginePeer(author).displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder)
                } else if let authorSignature = forwardInfo.authorSignature {
                    titleString = authorSignature
                }
            }
            
            var (textString, isMedia, isText) = descriptionStringForMessage(contentSettings: arguments.context.currentContentSettings.with { $0 }, message: EngineMessage(arguments.message), strings: arguments.strings, nameDisplayOrder: arguments.presentationData.nameDisplayOrder, dateTimeFormat: arguments.presentationData.dateTimeFormat, accountPeerId: arguments.context.account.peerId)
            
            if let threadId = arguments.parentMessage.threadId, Int64(arguments.message.id.id) == threadId, let channel = arguments.parentMessage.peers[arguments.parentMessage.id.peerId] as? TelegramChannel, channel.flags.contains(.isForum), let threadInfo = arguments.parentMessage.associatedThreadInfo {
                titleString = "\(threadInfo.title)"
                textString = NSAttributedString()
            }
            
            let placeholderColor: UIColor = arguments.message.effectivelyIncoming(arguments.context.account.peerId) ? arguments.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : arguments.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
            let titleColor: UIColor
            let lineImage: UIImage?
            let textColor: UIColor
            let dustColor: UIColor
            
            var authorNameColor: UIColor?
            
            if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(arguments.parentMessage.id.peerId.namespace) && author?.id.namespace == Namespaces.Peer.CloudUser {
                authorNameColor = author.flatMap { chatMessagePeerIdColors[Int(clamping: $0.id.id._internalGetInt64Value() % 7)] }
                if let rawAuthorNameColor = authorNameColor {
                    var dimColors = false
                    switch arguments.presentationData.theme.theme.name {
                        case .builtin(.nightAccent), .builtin(.night):
                            dimColors = true
                        default:
                            break
                    }
                    if dimColors {
                        var hue: CGFloat = 0.0
                        var saturation: CGFloat = 0.0
                        var brightness: CGFloat = 0.0
                        rawAuthorNameColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                        authorNameColor = UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(1.0, brightness * 1.2), alpha: 1.0)
                    }
                }
            }
            
            switch arguments.type {
                case let .bubble(incoming):
                    titleColor = incoming ? (authorNameColor ?? arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor) : arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    lineImage = incoming ? (authorNameColor.flatMap({ PresentationResourcesChat.chatBubbleVerticalLineImage(color: $0) }) ??  PresentationResourcesChat.chatBubbleVerticalLineIncomingImage(arguments.presentationData.theme.theme)) : PresentationResourcesChat.chatBubbleVerticalLineOutgoingImage(arguments.presentationData.theme.theme)
                    if isMedia {
                        textColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    } else {
                        textColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.primaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.primaryTextColor
                    }
                    dustColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                case .standalone:
                    let serviceColor = serviceMessageColorComponents(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper)
                    titleColor = serviceColor.primaryText
                    
                    let graphics = PresentationResourcesChat.additionalGraphics(arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper, bubbleCorners: arguments.presentationData.chatBubbleCorners)
                    lineImage = graphics.chatServiceVerticalLineImage
                    textColor = titleColor
                    dustColor = titleColor
            }
            
            
            let messageText: NSAttributedString
            if isText {
                let entities = (arguments.message.textEntitiesAttribute?.entities ?? []).filter { entity in
                    if case .Spoiler = entity.type {
                        return true
                    } else if case .CustomEmoji = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                if entities.count > 0 {
                    messageText = stringWithAppliedEntities(trimToLineCount(arguments.message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: arguments.message)
                } else {
                    messageText = NSAttributedString(string: textString.string, font: textFont, textColor: textColor)
                }
            } else {
                messageText = NSAttributedString(string: textString.string, font: textFont, textColor: textColor)
            }
            
            var leftInset: CGFloat = 11.0
            let spacing: CGFloat = 2.0
            
            var updatedMediaReference: AnyMediaReference?
            var imageDimensions: CGSize?
            var hasRoundImage = false
            if !arguments.message.containsSecretMedia {
                for media in arguments.message.media {
                    if let image = media as? TelegramMediaImage {
                        updatedMediaReference = .message(message: MessageReference(arguments.message), media: image)
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        break
                    } else if let file = media as? TelegramMediaFile, file.isVideo && !file.isVideoSticker {
                        updatedMediaReference = .message(message: MessageReference(arguments.message), media: file)
                        
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
                imageTextInset += floor(arguments.presentationData.fontSize.baseDisplaySize * 32.0 / 17.0)
            }
            
            let maximumTextWidth = max(0.0, arguments.constrainedSize.width - imageTextInset)
            
            let contrainedTextSize = CGSize(width: maximumTextWidth, height: arguments.constrainedSize.height)
            
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
                    updateImageSignal = chatMessagePhotoThumbnail(account: arguments.context.account, photoReference: imageReference)
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isVideo {
                        updateImageSignal = chatMessageVideoThumbnail(account: arguments.context.account, fileReference: fileReference)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: arguments.context.account, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                    }
                }
            }
            
            let size = CGSize(width: max(titleLayout.size.width - textInsets.left - textInsets.right, textLayout.size.width - textInsets.left - textInsets.right) + leftInset, height: titleLayout.size.height + textLayout.size.height - 2 * (textInsets.top + textInsets.bottom) + 2 * spacing)
            
            return (size, { attemptSynchronous in
                let node: ChatMessageReplyInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageReplyInfoNode()
                }
                
                node.previousMediaReference = updatedMediaReference
                
                node.titleNode?.displaysAsynchronously = !arguments.presentationData.isPreview
                node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                let titleNode = titleApply()
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: placeholderColor, attemptSynchronous: attemptSynchronous)
                }
                let textNode = textApply(textArguments)
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.titleNode == nil {
                    titleNode.isUserInteractionEnabled = false
                    node.titleNode = titleNode
                    node.contentNode.addSubnode(titleNode)
                }
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode.textNode)
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
                node.imageNode?.captureProtected = arguments.message.isCopyProtected()
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0, y: spacing - textInsets.top + 1.0), size: titleLayout.size)
                
                let textFrame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0, y: titleNode.frame.maxY - textInsets.bottom + spacing - textInsets.top - 2.0), size: textLayout.size)
                textNode.textNode.frame = textFrame
                
                if !textLayout.spoilers.isEmpty {
                    let dustNode: InvisibleInkDustNode
                    if let current = node.dustNode {
                        dustNode = current
                    } else {
                        dustNode = InvisibleInkDustNode(textNode: nil)
                        dustNode.isUserInteractionEnabled = false
                        node.dustNode = dustNode
                        node.contentNode.insertSubnode(dustNode, aboveSubnode: textNode.textNode)
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
                x: localRect.minX + sourceReplyPanel.textNode.frame.minX - textNode.textNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.textNode.frame.midY - textNode.textNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: textNode.textNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: textNode.textNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.textNode)

            textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

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
