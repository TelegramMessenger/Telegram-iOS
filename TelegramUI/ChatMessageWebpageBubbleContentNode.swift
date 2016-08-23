import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

private func generateLineImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 2.0, height: 3.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 1.0), size: CGSize(width: 2.0, height: 2.0)))
    })?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
}

private let incomingLineImage = generateLineImage(color: UIColor(0x3ca7fe))
private let outgoingLineImage = generateLineImage(color: UIColor(0x29cc10))

private let incomingAccentColor = UIColor(0x3ca7fe)
private let outgoingAccentColor = UIColor(0x00a700)

private let titleFont: UIFont = UIFont.boldSystemFont(ofSize: 15.0)
private let textFont: UIFont = UIFont.systemFont(ofSize: 15.0)

final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private let lineNode: ASImageNode
    private let textNode: TextNode
    private let inlineImageNode: TransformImageNode
    private var contentImageNode: ChatMessageInteractiveMediaNode?
    private var contentFileNode: ChatMessageInteractiveFileNode?
    
    private let statusNode: ChatMessageDateAndStatusNode
    
    private var image: TelegramMediaImage?
    
    required init() {
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let textAsyncLayout = TextNode.asyncLayout(self.textNode)
        let currentImage = self.image
        let imageLayout = self.inlineImageNode.asyncLayout()
        let statusLayout = self.statusNode.asyncLayout()
        let contentImageLayout = ChatMessageInteractiveMediaNode.asyncLayout(self.contentImageNode)
        let contentFileLayout = ChatMessageInteractiveFileNode.asyncLayout(self.contentFileNode)
        
        return { item, layoutConstants, _, constrainedSize in
            let insets = UIEdgeInsets(top: 0.0, left: 9.0 + 8.0, bottom: 5.0, right: 8.0)
            
            var webpage: TelegramMediaWebpageLoadedContent?
            for media in item.message.media {
                if let media = media as? TelegramMediaWebpage {
                    if case let .Loaded(content) = media.content {
                        webpage = content
                    }
                    break
                }
            }
            
            var textString: NSAttributedString?
            var inlineImageDimensions: CGSize?
            var inlineImageSize: CGSize?
            var updateInlineImageSignal: Signal<(TransformImageArguments) -> DrawingContext, NoError>?
            var textCutout: TextNodeCutout?
            var initialWidth: CGFloat = CGFloat.greatestFiniteMagnitude
            var refineContentImageLayout: ((CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveMediaNode)))?
            var refineContentFileLayout: ((CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode)))?
            
            if let webpage = webpage {
                let string = NSMutableAttributedString()
                var notEmpty = false
                
                if let websiteName = webpage.websiteName, !websiteName.isEmpty {
                    string.append(NSAttributedString(string: websiteName, font: titleFont, textColor: item.message.flags.contains(.Incoming) ? incomingAccentColor : outgoingAccentColor))
                    notEmpty = true
                }
                
                if let title = webpage.title, !title.isEmpty {
                    if notEmpty {
                        string.append(NSAttributedString(string: "\n", font: textFont, textColor: UIColor.black))
                    }
                    string.append(NSAttributedString(string: title, font: titleFont, textColor: UIColor.black))
                    notEmpty = true
                }
                
                if let text = webpage.text, !text.isEmpty {
                    if notEmpty {
                        string.append(NSAttributedString(string: "\n", font: textFont, textColor: UIColor.black))
                    }
                    string.append(NSAttributedString(string: text + "\n", font: textFont, textColor: UIColor.black))
                    notEmpty = true
                }
                
                textString = string
                
                if let file = webpage.file {
                    if file.isVideo {
                        let (initialImageWidth, refineLayout) = contentImageLayout(item.account, file, ImageCorners(radius: 4.0), true, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height))
                        initialWidth = initialImageWidth + insets.left + insets.right
                        refineContentImageLayout = refineLayout
                    } else {
                        let (_, refineLayout) = contentFileLayout(item.account, file, item.message.flags.contains(.Incoming), CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height))
                        refineContentFileLayout = refineLayout
                    }
                } else if let image = webpage.image {
                    if let type = webpage.type, ["photo"].contains(type) {
                        let (initialImageWidth, refineLayout) = contentImageLayout(item.account, image, ImageCorners(radius: 4.0), true, CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height))
                        initialWidth = initialImageWidth + insets.left + insets.right
                        refineContentImageLayout = refineLayout
                    } else if let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                        inlineImageDimensions = dimensions
                        
                        if image != currentImage {
                            updateInlineImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: image)
                        }
                    }
                }
            }
            
            if let _ = inlineImageDimensions {
                inlineImageSize = CGSize(width: 54.0, height: 54.0)
                
                if let inlineImageSize = inlineImageSize {
                    textCutout = TextNodeCutout(position: .TopRight, size: CGSize(width: inlineImageSize.width + 10.0, height: inlineImageSize.height + 10.0))
                }
            }
            
            return (initialWidth, { constrainedSize in
                var t = Int(item.message.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
                let dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                //let dateText = "\(message.id.id)"
                
                let statusType: ChatMessageDateAndStatusType
                if item.message.flags.contains(.Incoming) {
                    statusType = .BubbleIncoming
                } else {
                    if item.message.flags.contains(.Failed) {
                        statusType = .BubbleOutgoing(.Failed)
                    } else if item.message.flags.contains(.Unsent) {
                        statusType = .BubbleOutgoing(.Sending)
                    } else {
                        statusType = .BubbleOutgoing(.Sent(read: true))
                    }
                }
                
                let textConstrainedSize = CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height - insets.top - insets.bottom)
                
                var statusSizeAndApply: (CGSize, () -> Void)?
                
                if refineContentImageLayout == nil && refineContentFileLayout == nil {
                    statusSizeAndApply = statusLayout(dateText, statusType, textConstrainedSize)
                }
                
                let (textLayout, textApply) = textAsyncLayout(textString, nil, 12, .end, textConstrainedSize, textCutout)
                
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
                
                let lineImage = item.message.flags.contains(.Incoming) ? incomingLineImage : outgoingLineImage
                
                var boundingSize = textFrame.size
                if let statusFrame = statusFrame {
                    boundingSize = textFrame.union(statusFrame).size
                }
                var lineHeight = textFrame.size.height
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
                
                boundingSize.width += insets.left + insets.right
                boundingSize.height += insets.top + insets.bottom
                lineHeight += insets.top + insets.bottom
                
                var imageApply: (() -> Void)?
                if let inlineImageSize = inlineImageSize, let inlineImageDimensions = inlineImageDimensions {
                    let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                    let arguments = TransformImageArguments(corners: imageCorners, imageSize: inlineImageDimensions.aspectFilled(inlineImageSize), boundingSize: inlineImageSize, intrinsicInsets: UIEdgeInsets())
                    imageApply = imageLayout(arguments)
                }
                
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
                        if textFrame.size.height > CGFloat(FLT_EPSILON) {
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
                        if textFrame.size.height > CGFloat(FLT_EPSILON) {
                            imageHeigthAddition += 2.0
                        }
                        
                        adjustedBoundingSize.height += imageHeigthAddition + 5.0
                        adjustedLineHeight += imageHeigthAddition + 4.0
                    }
                    
                    var adjustedStatusFrame: CGRect?
                    if let statusFrame = statusFrame {
                        adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - insets.right, y: statusFrame.origin.y), size: statusFrame.size)
                    }
                    
                    return (adjustedBoundingSize, { [weak self] in
                        if let strongSelf = self {
                            strongSelf.lineNode.image = lineImage
                            strongSelf.lineNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 0.0), size: CGSize(width: 2.0, height: adjustedLineHeight - insets.top - insets.bottom - 2.0))
                            
                            let _ = textApply()
                            strongSelf.textNode.frame = textFrame
                            
                            if let (_, statusApply) = statusSizeAndApply, let adjustedStatusFrame = adjustedStatusFrame {
                                strongSelf.statusNode.frame = adjustedStatusFrame
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                }
                                statusApply()
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                            
                            strongSelf.image = webpage?.image
                            
                            if let imageFrame = imageFrame {
                                if let updateImageSignal = updateInlineImageSignal {
                                    strongSelf.inlineImageNode.setSignal(account: item.account, signal: updateImageSignal)
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
                            
                            if let (contentImageSize, contentImageApply) = contentImageSizeAndApply {
                                let contentImageNode = contentImageApply()
                                if strongSelf.contentImageNode !== contentImageNode {
                                    strongSelf.contentImageNode = contentImageNode
                                    strongSelf.addSubnode(contentImageNode)
                                    contentImageNode.activateLocalContent = { [weak strongSelf] in
                                        if let strongSelf = strongSelf {
                                            strongSelf.controllerInteraction?.openMessage(item.message.id)
                                        }
                                    }
                                }
                                let _ = contentImageApply()
                                contentImageNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat(FLT_EPSILON) ? 4.0 : 0.0)), size: contentImageSize)
                            } else if let contentImageNode = strongSelf.contentImageNode {
                                contentImageNode.removeFromSupernode()
                                strongSelf.contentImageNode = nil
                            }
                            
                            if let (contentFileSize, contentFileApply) = contentFileSizeAndApply {
                                let contentFileNode = contentFileApply()
                                if strongSelf.contentFileNode !== contentFileNode {
                                    strongSelf.contentFileNode = contentFileNode
                                    strongSelf.addSubnode(contentFileNode)
                                    contentFileNode.activateLocalContent = { [weak strongSelf] in
                                        if let strongSelf = strongSelf {
                                            strongSelf.controllerInteraction?.openMessage(item.message.id)
                                        }
                                    }
                                }
                                let _ = contentFileApply()
                                contentFileNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat(FLT_EPSILON) ? 4.0 : 0.0)), size: contentFileSize)
                            } else if let contentFileNode = strongSelf.contentFileNode {
                                contentFileNode.removeFromSupernode()
                                strongSelf.contentFileNode = nil
                            }
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.lineNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.lineNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.lineNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.inlineImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
}
