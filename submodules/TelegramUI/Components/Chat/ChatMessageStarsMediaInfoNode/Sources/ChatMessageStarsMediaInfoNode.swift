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
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import ChatControllerInteraction

private func generateRectsImage(color: UIColor, rects: [CGRect], inset: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat) -> (CGPoint, UIImage?) {
    enum CornerType {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    func drawFullCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
        if radius.isZero {
            return
        }
        context.setFillColor(color.cgColor)
        switch type {
        case .topLeft:
            context.clear(CGRect(origin: point, size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: point, size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .topRight:
            context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomLeft:
            context.clear(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomRight:
            context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        }
    }

    func drawConnectingCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
        context.setFillColor(color.cgColor)
        switch type {
        case .topLeft:
            context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .topRight:
            context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomLeft:
            context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomRight:
            context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        }
    }
    
    if rects.isEmpty {
        return (CGPoint(), nil)
    }
    
    var topLeft = rects[0].origin
    var bottomRight = CGPoint(x: rects[0].maxX, y: rects[0].maxY)
    for i in 1 ..< rects.count {
        topLeft.x = min(topLeft.x, rects[i].origin.x)
        topLeft.y = min(topLeft.y, rects[i].origin.y)
        bottomRight.x = max(bottomRight.x, rects[i].maxX)
        bottomRight.y = max(bottomRight.y, rects[i].maxY)
    }
    
    topLeft.x -= inset
    topLeft.y -= inset
    bottomRight.x += inset * 2.0
    bottomRight.y += inset * 2.0
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        
        context.setBlendMode(.copy)
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset)
            context.fill(rect.offsetBy(dx: -topLeft.x, dy: -topLeft.y))
        }
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            
            var previous: CGRect?
            if i != 0 {
                previous = rects[i - 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            var next: CGRect?
            if i != rects.count - 1 {
                next = rects[i + 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            if let previous = previous {
                if previous.contains(rect.topLeft) {
                    if abs(rect.topLeft.x - previous.minX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topLeft.x, y: previous.maxY), type: .topLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                }
                if previous.contains(rect.topRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.topRight.x - previous.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topRight.x, y: previous.maxY), type: .topRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
            }
            
            if let next = next {
                if next.contains(rect.bottomLeft) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomLeft.x, y: next.minY), type: .bottomLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                }
                if next.contains(rect.bottomRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomRight.x, y: next.minY), type: .bottomRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
            }
        }
    }))
}

public enum ChatMessageThreadInfoType {
    case bubble(incoming: Bool)
    case standalone
}

public class ChatMessageStarsMediaInfoNode: ASDisplayNode {
    public class Arguments {
        public let presentationData: ChatPresentationData
        public let context: AccountContext
        public let message: Message
        public let media: TelegramMediaPaidContent
        public let constrainedSize: CGSize
        public let animationCache: AnimationCache?
        public let animationRenderer: MultiAnimationRenderer?
        
        public init(
            presentationData: ChatPresentationData,
            context: AccountContext,
            message: Message,
            media: TelegramMediaPaidContent,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?
        ) {
            self.presentationData = presentationData
            self.context = context
            self.message = message
            self.media = media
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    public var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
            }
        }
    }
        
    private let contentBackgroundNode: ASImageNode
    private var textNode: TextNodeWithEntities?
                    
    override public init() {
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.isLayerBacked = true
        self.contentBackgroundNode.isUserInteractionEnabled = false
        
        super.init()
                
        self.addSubnode(self.contentBackgroundNode)
    }

    public class func asyncLayout(_ maybeNode: ChatMessageStarsMediaInfoNode?) -> (_ arguments: Arguments) -> (CGSize, (Bool) -> ChatMessageStarsMediaInfoNode) {
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
    
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 11.0 / 17.0)
            let textFont = Font.regular(fontSize)
                        
            let text: NSMutableAttributedString
            if let peer = arguments.message.peers[arguments.message.id.peerId] as? TelegramChannel, peer.flags.contains(.isCreator) || peer.adminRights != nil, arguments.message.forwardInfo == nil {
                let amountString = presentationStringsFormattedNumber(Int32(arguments.media.amount), arguments.presentationData.dateTimeFormat.groupingSeparator)
                text = NSMutableAttributedString(string: "⭐️\(amountString)", font: textFont, textColor: .white)
            } else {
                text = NSMutableAttributedString(string: arguments.presentationData.strings.Chat_PaidMedia_Purchased, font: textFont, textColor: .white)
            }
            
            var offset: CGFloat = 0.0
            if let range = text.string.range(of: "⭐️") {
                text.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: NSRange(range, in: text.string))
                text.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: text.string))
                offset -= 1.0
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: arguments.constrainedSize.width, height: arguments.constrainedSize.height), alignment: .natural, cutout: nil, insets: .zero))
            
            let padding: CGFloat = 6.0
            let size = CGSize(width: textLayout.size.width + padding * 2.0, height: 18.0)
            
            return (size, { attemptSynchronous in
                let node: ChatMessageStarsMediaInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageStarsMediaInfoNode()
                }
                
                if node.contentBackgroundNode.image == nil {
                    node.contentBackgroundNode.image = generateStretchableFilledCircleImage(radius: 9.0, color: UIColor(rgb: 0x000000, alpha: 0.3))
                }
                                
                node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: .clear, attemptSynchronous: attemptSynchronous)
                }
                let textNode = textApply(textArguments)
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.addSubnode(textNode.textNode)
                }
                
                node.contentBackgroundNode.frame = CGRect(origin: .zero, size: size)
                
                let textFrame = CGRect(origin: CGPoint(x: padding + offset, y: floorToScreenPixels((size.height - textLayout.size.height) / 2.0) + UIScreenPixel), size: textLayout.size)
                textNode.textNode.frame = textFrame
                                 
                return node
            })
        }
    }
}
