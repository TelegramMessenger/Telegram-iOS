import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox

private let titleFont: UIFont = Font.semibold(15.0)
private let textFont: UIFont = Font.regular(15.0)
private let textBoldFont: UIFont = Font.semibold(15.0)
private let textFixedFont: UIFont = Font.regular(15.0)
private let buttonFont: UIFont = Font.semibold(13.0)

struct ChatMessageAttachedContentNodeMediaFlags: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    static let preferMediaInline = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 0)
    static let preferMediaBeforeText = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 1)
}

private final class ChatMessageAttachedContentButtonNode: HighlightTrackingButtonNode {
    private let textNode: TextNode
    private let highlightedTextNode: TextNode
    private let backgroundNode: ASImageNode
    
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    
    var pressed: (() -> Void)?
    
    override init() {
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.highlightedTextNode = TextNode()
        self.highlightedTextNode.isLayerBacked = true
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.highlightedTextNode)
        self.highlightedTextNode.isHidden = true
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.image = strongSelf.highlightedImage
                    strongSelf.textNode.isHidden = true
                    strongSelf.highlightedTextNode.isHidden = false
                } else {
                    UIView.transition(with: strongSelf.view, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                        strongSelf.backgroundNode.image = strongSelf.regularImage
                        strongSelf.textNode.isHidden = false
                        strongSelf.highlightedTextNode.isHidden = true
                    }, completion: nil)
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
    
    static func asyncLayout(_ current: ChatMessageAttachedContentButtonNode?) -> (_ width: CGFloat, _ regularImage: UIImage, _ highlightedImage: UIImage, _ title: String, _ titleColor: UIColor, _ highlightedTitleColor: UIColor) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageAttachedContentButtonNode)) {
        let previousRegularImage = current?.regularImage
        let previousHighlightedImage = current?.highlightedImage
        
        let maybeMakeTextLayout = (current?.textNode).flatMap(TextNode.asyncLayout)
        let maybeMakeHighlightedTextLayout = (current?.highlightedTextNode).flatMap(TextNode.asyncLayout)
        
        return { width, regularImage, highlightedImage, title, titleColor, highlightedTitleColor in
            let targetNode: ChatMessageAttachedContentButtonNode
            if let current = current {
                targetNode = current
            } else {
                targetNode = ChatMessageAttachedContentButtonNode()
            }
            
            let makeTextLayout: (NSAttributedString?, UIColor?, Int, CTLineTruncationType, CGSize, NSTextAlignment, TextNodeCutout?, UIEdgeInsets) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeTextLayout = maybeMakeTextLayout {
                makeTextLayout = maybeMakeTextLayout
            } else {
                makeTextLayout = TextNode.asyncLayout(targetNode.textNode)
            }
            
            let makeHighlightedTextLayout: (NSAttributedString?, UIColor?, Int, CTLineTruncationType, CGSize, NSTextAlignment, TextNodeCutout?, UIEdgeInsets) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeHighlightedTextLayout = maybeMakeHighlightedTextLayout {
                makeHighlightedTextLayout = maybeMakeHighlightedTextLayout
            } else {
                makeHighlightedTextLayout = TextNode.asyncLayout(targetNode.highlightedTextNode)
            }
            
            var updatedRegularImage: UIImage?
            if regularImage !== previousRegularImage {
                updatedRegularImage = regularImage
            }
            
            var updatedHighlightedImage: UIImage?
            if highlightedImage !== previousHighlightedImage {
                updatedHighlightedImage = highlightedImage
            }
            
            let labelInset: CGFloat = 8.0
            
            let (textSize, textApply) = makeTextLayout(NSAttributedString(string: title, font: buttonFont, textColor: titleColor), nil, 1, .end, CGSize(width: max(1.0, width - labelInset * 2.0), height: CGFloat.greatestFiniteMagnitude), .left, nil, UIEdgeInsets())
            
            let (_, highlightedTextApply) = makeHighlightedTextLayout(NSAttributedString(string: title, font: buttonFont, textColor: highlightedTitleColor), nil, 1, .end, CGSize(width: max(1.0, width - labelInset * 2.0), height: CGFloat.greatestFiniteMagnitude), .left, nil, UIEdgeInsets())
            
            return (textSize.size.width + labelInset * 2.0, { refinedWidth in
                return (CGSize(width: refinedWidth, height: 33.0), {
                    if let updatedRegularImage = updatedRegularImage {
                        targetNode.regularImage = updatedRegularImage
                        if !targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedRegularImage
                        }
                    }
                    if let updatedHighlightedImage = updatedHighlightedImage {
                        targetNode.highlightedImage = updatedHighlightedImage
                        if targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedHighlightedImage
                        }
                    }
                    
                    let _ = textApply()
                    let _ = highlightedTextApply()
                    
                    targetNode.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: refinedWidth, height: 33.0))
                    targetNode.textNode.frame = CGRect(origin: CGPoint(x: floor((refinedWidth - textSize.size.width) / 2.0), y: floor((33.0 - textSize.size.height) / 2.0)), size: textSize.size)
                    targetNode.highlightedTextNode.frame = targetNode.textNode.frame
                    
                    return targetNode
                })
            })
        }
    }
}

final class ChatMessageAttachedContentNode: ASDisplayNode {
    private let lineNode: ASImageNode
    private let textNode: TextNode
    private let inlineImageNode: TransformImageNode
    private var contentImageNode: ChatMessageInteractiveMediaNode?
    private var contentFileNode: ChatMessageInteractiveFileNode?
    private var buttonBackgroundNode: ASImageNode?
    private var buttonNode: ChatMessageAttachedContentButtonNode?
    
    private let statusNode: ChatMessageDateAndStatusNode
    
    private var message: Message?
    private var media: Media?
    
    var openMedia: (() -> Void)?
    var activateAction: (() -> Void)?
    
    var visibility: ListViewItemNodeVisibility = .none {
        didSet {
            self.contentImageNode?.visibility = self.visibility
        }
    }
    
    override init() {
        self.lineNode = ASImageNode()
        self.lineNode.isLayerBacked = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = true
        self.textNode.contentsScale = UIScreenScale
        self.textNode.contentMode = .topLeft
        
        self.inlineImageNode = TransformImageNode()
        self.inlineImageNode.isLayerBacked = true
        self.inlineImageNode.displaysAsynchronously = false
        
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.statusNode)
    }
    
    func asyncLayout() -> (_ theme: PresentationTheme, _ strings: PresentationStrings, _ automaticDownloadSettings: AutomaticMediaDownloadSettings, _ account: Account, _ message: Message, _ messageRead: Bool, _ title: String?, _ subtitle: String?, _ text: String?, _ entities: [MessageTextEntity]?, _ media: (Media, ChatMessageAttachedContentNodeMediaFlags)?, _ actionTitle: String?, _ displayLine: Bool, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let textAsyncLayout = TextNode.asyncLayout(self.textNode)
        let currentImage = self.media as? TelegramMediaImage
        let imageLayout = self.inlineImageNode.asyncLayout()
        let statusLayout = self.statusNode.asyncLayout()
        let contentImageLayout = ChatMessageInteractiveMediaNode.asyncLayout(self.contentImageNode)
        let contentFileLayout = ChatMessageInteractiveFileNode.asyncLayout(self.contentFileNode)
        
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        return { theme, strings, automaticDownloadSettings, account, message, messageRead, title, subtitle, text, entities, mediaAndFlags, actionTitle, displayLine, layoutConstants, position, constrainedSize in
            let incoming = message.effectivelyIncoming
            
            var insets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 5.0, right: 8.0)
            switch position.top {
                case .None:
                    insets.top += 8.0
                default:
                    break
            }
            if displayLine {
                insets.left += 11.0
            }
            
            var preferMediaBeforeText = false
            if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                preferMediaBeforeText = true
            }
            
            var t = Int(message.timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo)
            
            var edited = false
            var sentViaBot = false
            var viewCount: Int?
            for attribute in message.attributes {
                if let _ = attribute as? EditedMessageAttribute {
                    edited = true
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                } else if let _ = attribute as? InlineBotMessageAttribute {
                    sentViaBot = true
                }
            }
            
            var dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
            
            if let author = message.author as? TelegramUser {
                if author.botInfo != nil {
                    sentViaBot = true
                }
                if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    dateText = "\(author.displayTitle), \(dateText)"
                }
            }
            
            var textString: NSAttributedString?
            var inlineImageDimensions: CGSize?
            var inlineImageSize: CGSize?
            var updateInlineImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var textCutout: TextNodeCutout?
            var initialWidth: CGFloat = CGFloat.greatestFiniteMagnitude
            var refineContentImageLayout: ((CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveMediaNode)))?
            var refineContentFileLayout: ((CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode)))?
            
            let string = NSMutableAttributedString()
            var notEmpty = false
            
            let bubbleTheme = theme.chat.bubble
            
            if let title = title, !title.isEmpty {
                string.append(NSAttributedString(string: title, font: titleFont, textColor: incoming ? bubbleTheme.incomingAccentColor : bubbleTheme.outgoingAccentColor))
                notEmpty = true
            }
            
            if let subtitle = subtitle, !subtitle.isEmpty {
                if notEmpty {
                    string.append(NSAttributedString(string: "\n", font: textFont, textColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor))
                }
                string.append(NSAttributedString(string: subtitle, font: titleFont, textColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor))
                notEmpty = true
            }
            
            if let text = text, !text.isEmpty {
                if notEmpty {
                    string.append(NSAttributedString(string: "\n", font: textFont, textColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor))
                }
                if let entities = entities {
                    string.append(stringWithAppliedEntities(text, entities: entities, baseColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor, linkColor: incoming ? bubbleTheme.incomingLinkTextColor : bubbleTheme.outgoingLinkTextColor, baseFont: textFont, boldFont: textBoldFont, fixedFont: textFixedFont))
                } else {
                    string.append(NSAttributedString(string: text + "\n", font: textFont, textColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor))
                }
                notEmpty = true
            }
            
            textString = string
            
            if let (media, flags) = mediaAndFlags {
                if let file = media as? TelegramMediaFile {
                    if file.isVideo {
                        var automaticDownload = false
                        if file.isAnimated {
                            automaticDownload = automaticDownloadSettings.categories.getGif(message.id.peerId)
                        } else if file.isInstantVideo {
                            automaticDownload = automaticDownloadSettings.categories.getInstantVideo(message.id.peerId)
                        }
                        let (initialImageWidth, _, refineLayout) = contentImageLayout(account, theme, strings, message, file, ImageCorners(radius: 4.0), automaticDownload, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height), layoutConstants)
                        initialWidth = initialImageWidth + insets.left + insets.right
                        refineContentImageLayout = refineLayout
                    } else {
                        var automaticDownload = false
                        if file.isVoice {
                            automaticDownload = automaticDownloadSettings.categories.getVoice(message.id.peerId)
                        }
                        let (_, refineLayout) = contentFileLayout(account, theme, strings, message, file, automaticDownload, message.effectivelyIncoming, nil, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height))
                        refineContentFileLayout = refineLayout
                    }
                } else if let image = media as? TelegramMediaImage {
                    if !flags.contains(.preferMediaInline) {
                        let automaticDownload = automaticDownloadSettings.categories.getPhoto(message.id.peerId)
                        let (initialImageWidth, _, refineLayout) = contentImageLayout(account, theme, strings, message, image, ImageCorners(radius: 4.0), automaticDownload, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height), layoutConstants)
                        initialWidth = initialImageWidth + insets.left + insets.right
                        refineContentImageLayout = refineLayout
                    } else if let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                        inlineImageDimensions = dimensions
                        
                        if image != currentImage {
                            updateInlineImageSignal = chatWebpageSnippetPhoto(account: account, photo: image)
                        }
                    }
                } else if let image = media as? TelegramMediaWebFile {
                    let automaticDownload = automaticDownloadSettings.categories.getPhoto(message.id.peerId)
                    let (initialImageWidth, _, refineLayout) = contentImageLayout(account, theme, strings, message, image, ImageCorners(radius: 4.0), automaticDownload, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height), layoutConstants)
                    initialWidth = initialImageWidth + insets.left + insets.right
                    refineContentImageLayout = refineLayout
                }
            }
            
            if let _ = inlineImageDimensions {
                inlineImageSize = CGSize(width: 54.0, height: 54.0)
                
                if let inlineImageSize = inlineImageSize {
                    textCutout = TextNodeCutout(position: .TopRight, size: CGSize(width: inlineImageSize.width + 10.0, height: inlineImageSize.height + 10.0))
                }
            }
            
            return (initialWidth, { constrainedSize in
                let statusType: ChatMessageDateAndStatusType
                if message.effectivelyIncoming {
                    statusType = .BubbleIncoming
                } else {
                    if message.flags.contains(.Failed) {
                        statusType = .BubbleOutgoing(.Failed)
                    } else if message.flags.isSending {
                        statusType = .BubbleOutgoing(.Sending)
                    } else {
                        statusType = .BubbleOutgoing(.Sent(read: messageRead))
                    }
                }
                
                let textConstrainedSize = CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height - insets.top - insets.bottom)
                
                var statusSizeAndApply: (CGSize, (Bool) -> Void)?
                
                if (refineContentImageLayout == nil && refineContentFileLayout == nil) || preferMediaBeforeText {
                    statusSizeAndApply = statusLayout(theme, edited && !sentViaBot, viewCount, dateText, statusType, textConstrainedSize)
                }
                
                let (textLayout, textApply) = textAsyncLayout(textString, nil, 12, .end, textConstrainedSize, .natural, textCutout, UIEdgeInsets())
                
                var textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
                
                var statusFrame: CGRect?
                
                if let (statusSize, _) = statusSizeAndApply {
                    var frame = CGRect(origin: CGPoint(), size: statusSize)
                    
                    let trailingLineWidth = textLayout.trailingLineWidth
                    if textLayout.size.width - trailingLineWidth >= statusSize.width {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY - statusSize.height)
                    } else if trailingLineWidth + statusSize.width < textConstrainedSize.width {
                        frame.origin = CGPoint(x: textFrame.minX + trailingLineWidth, y: textFrame.maxY - statusSize.height)
                    } else {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY)
                    }
                    
                    if let inlineImageSize = inlineImageSize {
                        if frame.origin.y < inlineImageSize.height + 4.0 {
                            frame.origin.y = inlineImageSize.height + 4.0
                        }
                    }
                    
                    frame = frame.offsetBy(dx: insets.left, dy: insets.top)
                    statusFrame = frame
                }
                
                textFrame = textFrame.offsetBy(dx: insets.left, dy: insets.top)
                
                let lineImage = incoming ? PresentationResourcesChat.chatBubbleVerticalLineIncomingImage(theme) : PresentationResourcesChat.chatBubbleVerticalLineOutgoingImage(theme)
                
                var boundingSize = textFrame.size
                var lineHeight = textFrame.size.height
                if let statusFrame = statusFrame {
                    boundingSize = textFrame.union(statusFrame).size
                    if let _ = actionTitle {
                        lineHeight = boundingSize.height
                    }
                }
                if let inlineImageSize = inlineImageSize {
                    if boundingSize.height < inlineImageSize.height {
                        boundingSize.height = inlineImageSize.height
                    }
                    if lineHeight < inlineImageSize.height {
                        lineHeight = inlineImageSize.height
                    }
                }
                
                var finalizeContentImageLayout: ((CGFloat) -> (CGSize, () -> ChatMessageInteractiveMediaNode))?
                if let refineContentImageLayout = refineContentImageLayout {
                    let (refinedWidth, finalizeImageLayout) = refineContentImageLayout(textConstrainedSize)
                    finalizeContentImageLayout = finalizeImageLayout
                    
                    boundingSize.width = max(boundingSize.width, refinedWidth)
                }
                var finalizeContentFileLayout: ((CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode))?
                if let refineContentFileLayout = refineContentFileLayout {
                    let (refinedWidth, finalizeFileLayout) = refineContentFileLayout(textConstrainedSize)
                    finalizeContentFileLayout = finalizeFileLayout
                    
                    boundingSize.width = max(boundingSize.width, refinedWidth)
                }
                
                lineHeight += insets.top + insets.bottom
                
                var imageApply: (() -> Void)?
                if let inlineImageSize = inlineImageSize, let inlineImageDimensions = inlineImageDimensions {
                    let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                    let arguments = TransformImageArguments(corners: imageCorners, imageSize: inlineImageDimensions.aspectFilled(inlineImageSize), boundingSize: inlineImageSize, intrinsicInsets: UIEdgeInsets())
                    imageApply = imageLayout(arguments)
                }
                
                var continueActionButtonLayout: ((CGFloat) -> (CGSize, () -> ChatMessageAttachedContentButtonNode))?
                if let actionTitle = actionTitle {
                    let buttonImage: UIImage
                    let buttonHighlightedImage: UIImage
                    let titleColor: UIColor
                    let titleHighlightedColor: UIColor
                    if incoming {
                        buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonIncoming(theme)!
                        buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIncoming(theme)!
                        titleColor = theme.chat.bubble.incomingAccentColor
                        titleHighlightedColor = theme.chat.bubble.incomingFillColor
                    } else {
                        buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonOutgoing(theme)!
                        buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonOutgoing(theme)!
                        titleColor = theme.chat.bubble.outgoingAccentColor
                        titleHighlightedColor = theme.chat.bubble.outgoingFillColor
                    }
                    let (buttonWidth, continueLayout) = makeButtonLayout(constrainedSize.width, buttonImage, buttonHighlightedImage, actionTitle, titleColor, titleHighlightedColor)
                    boundingSize.width = max(buttonWidth, boundingSize.width)
                    continueActionButtonLayout = continueLayout
                }
                
                boundingSize.width += insets.left + insets.right
                boundingSize.height += insets.top + insets.bottom
                
                return (boundingSize.width, { boundingWidth in
                    var adjustedBoundingSize = boundingSize
                    var adjustedLineHeight = lineHeight
                    
                    var imageFrame: CGRect?
                    if let inlineImageSize = inlineImageSize {
                        imageFrame = CGRect(origin: CGPoint(x: boundingWidth - inlineImageSize.width - insets.right, y: 0.0), size: inlineImageSize)
                    }
                    
                    var contentImageSizeAndApply: (CGSize, () -> ChatMessageInteractiveMediaNode)?
                    if let finalizeContentImageLayout = finalizeContentImageLayout {
                        let (size, apply) = finalizeContentImageLayout(boundingWidth - insets.left - insets.right)
                        contentImageSizeAndApply = (size, apply)
                        
                        var imageHeigthAddition = size.height
                        if textFrame.size.height > CGFloat.ulpOfOne {
                            imageHeigthAddition += 2.0
                        }
                        
                        adjustedBoundingSize.height += imageHeigthAddition + 5.0
                        adjustedLineHeight += imageHeigthAddition + 4.0
                    }
                    
                    var contentFileSizeAndApply: (CGSize, () -> ChatMessageInteractiveFileNode)?
                    if let finalizeContentFileLayout = finalizeContentFileLayout {
                        let (size, apply) = finalizeContentFileLayout(boundingWidth - insets.left - insets.right)
                        contentFileSizeAndApply = (size, apply)
                        
                        var imageHeigthAddition = size.height
                        if textFrame.size.height > CGFloat.ulpOfOne {
                            imageHeigthAddition += 2.0
                        }
                        
                        adjustedBoundingSize.height += imageHeigthAddition + 5.0
                        adjustedLineHeight += imageHeigthAddition + 4.0
                    }
                    
                    var actionButtonSizeAndApply: ((CGSize, () -> ChatMessageAttachedContentButtonNode))?
                    if let continueActionButtonLayout = continueActionButtonLayout {
                        let (size, apply) = continueActionButtonLayout(boundingWidth - 9.0 - insets.right)
                        actionButtonSizeAndApply = (size, apply)
                        adjustedBoundingSize.height += 7.0 + size.height
                    }
                    
                    var adjustedStatusFrame: CGRect?
                    if let statusFrame = statusFrame {
                        adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - insets.right, y: statusFrame.origin.y), size: statusFrame.size)
                    }
                    
                    return (adjustedBoundingSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.message = message
                            strongSelf.media = mediaAndFlags?.0
                            
                            var hasAnimation = true
                            if case .None = animation {
                                hasAnimation = false
                            }
                            
                            strongSelf.lineNode.image = lineImage
                            strongSelf.lineNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 0.0), size: CGSize(width: 2.0, height: adjustedLineHeight - insets.top - insets.bottom - 2.0))
                            strongSelf.lineNode.isHidden = !displayLine
                            
                            let _ = textApply()
                            
                            if let imageFrame = imageFrame {
                                if let updateImageSignal = updateInlineImageSignal {
                                    strongSelf.inlineImageNode.setSignal(account: account, signal: updateImageSignal)
                                }
                                
                                strongSelf.inlineImageNode.frame = imageFrame
                                if strongSelf.inlineImageNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.inlineImageNode)
                                }
                                
                                if let imageApply = imageApply {
                                    imageApply()
                                }
                            } else if strongSelf.inlineImageNode.supernode != nil {
                                strongSelf.inlineImageNode.removeFromSupernode()
                            }
                            
                            var contentMediaHeight: CGFloat?
                            
                            if let (contentImageSize, contentImageApply) = contentImageSizeAndApply {
                                contentMediaHeight = contentImageSize.height
                                
                                let contentImageNode = contentImageApply()
                                if strongSelf.contentImageNode !== contentImageNode {
                                    strongSelf.contentImageNode = contentImageNode
                                    strongSelf.addSubnode(contentImageNode)
                                    contentImageNode.activateLocalContent = { [weak strongSelf] in
                                        if let strongSelf = strongSelf {
                                            strongSelf.openMedia?()
                                        }
                                    }
                                    contentImageNode.visibility = strongSelf.visibility
                                }
                                let _ = contentImageApply()
                                if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                    contentImageNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: contentImageSize)
                                } else {
                                    contentImageNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat.ulpOfOne ? 4.0 : 0.0)), size: contentImageSize)
                                }
                            } else if let contentImageNode = strongSelf.contentImageNode {
                                contentImageNode.visibility = .none
                                contentImageNode.removeFromSupernode()
                                strongSelf.contentImageNode = nil
                            }
                            
                            if let (contentFileSize, contentFileApply) = contentFileSizeAndApply {
                                contentMediaHeight = contentFileSize.height
                                
                                let contentFileNode = contentFileApply()
                                if strongSelf.contentFileNode !== contentFileNode {
                                    strongSelf.contentFileNode = contentFileNode
                                    strongSelf.addSubnode(contentFileNode)
                                    contentFileNode.activateLocalContent = { [weak strongSelf] in
                                        if let strongSelf = strongSelf {
                                            strongSelf.openMedia?()
                                        }
                                    }
                                }
                                let _ = contentFileApply()
                                if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                    contentFileNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: contentFileSize)
                                } else {
                                    contentFileNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat.ulpOfOne ? 4.0 : 0.0)), size: contentFileSize)
                                }
                            } else if let contentFileNode = strongSelf.contentFileNode {
                                contentFileNode.removeFromSupernode()
                                strongSelf.contentFileNode = nil
                            }
                            
                            var textVerticalOffset: CGFloat = 0.0
                            if let contentMediaHeight = contentMediaHeight, let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                textVerticalOffset = contentMediaHeight + 7.0
                            }
                            
                            strongSelf.textNode.frame = textFrame.offsetBy(dx: 0.0, dy: textVerticalOffset)
                            
                            if let (size, apply) = actionButtonSizeAndApply {
                                let buttonNode = apply()
                                if buttonNode !== strongSelf.buttonNode {
                                    strongSelf.buttonNode?.removeFromSupernode()
                                    strongSelf.buttonNode = buttonNode
                                    strongSelf.addSubnode(buttonNode)
                                    buttonNode.pressed = {
                                        if let strongSelf = self {
                                            strongSelf.activateAction?()
                                        }
                                    }
                                }
                                buttonNode.frame = CGRect(origin: CGPoint(x: 9.0, y: adjustedLineHeight - insets.top - insets.bottom - 2.0 + 6.0), size: size)
                            } else if let buttonNode = strongSelf.buttonNode {
                                buttonNode.removeFromSupernode()
                                strongSelf.buttonNode = nil
                            }
                            
                            if let (_, statusApply) = statusSizeAndApply, let adjustedStatusFrame = adjustedStatusFrame {
                                strongSelf.statusNode.frame = adjustedStatusFrame.offsetBy(dx: 0.0, dy: textVerticalOffset)
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                }
                                statusApply(hasAnimation)
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                        }
                    })
                })
            })
        }
    }
    
    func updateHiddenMedia(_ media: [Media]?) {
        if let currentMedia = self.media {
            if let media = media {
                var found = false
                for m in media {
                    if currentMedia.isEqual(m) {
                        found = true
                        break
                    }
                }
                if let contentImageNode = self.contentImageNode {
                    contentImageNode.isHidden = found
                }
            } else if let contentImageNode = self.contentImageNode {
                contentImageNode.isHidden = false
            }
        }
    }
    
    func transitionNode(media: Media) -> ASDisplayNode? {
        if let image = self.media as? TelegramMediaImage, image.isEqual(media) {
            return self.contentImageNode
        } else if let file = self.media as? TelegramMediaFile, file.isEqual(media) {
            return self.contentImageNode
        }
        return nil
    }
}
