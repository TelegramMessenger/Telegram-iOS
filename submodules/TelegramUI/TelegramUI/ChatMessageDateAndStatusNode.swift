import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle

private let reactionCountFont = Font.semibold(11.0)

private func maybeAddRotationAnimation(_ layer: CALayer, duration: Double) {
    if let _ = layer.animation(forKey: "clockFrameAnimation") {
        return
    }
    
    let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    basicAnimation.duration = duration
    basicAnimation.fromValue = NSNumber(value: Float(0.0))
    basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
    basicAnimation.repeatCount = Float.infinity
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    basicAnimation.beginTime = 1.0
    layer.add(basicAnimation, forKey: "clockFrameAnimation")
}

enum ChatMessageDateAndStatusOutgoingType: Equatable {
    case Sent(read: Bool)
    case Sending
    case Failed
}

enum ChatMessageDateAndStatusType: Equatable {
    case BubbleIncoming
    case BubbleOutgoing(ChatMessageDateAndStatusOutgoingType)
    case ImageIncoming
    case ImageOutgoing(ChatMessageDateAndStatusOutgoingType)
    case FreeIncoming
    case FreeOutgoing(ChatMessageDateAndStatusOutgoingType)
}

private let reactionSize: CGFloat = 20.0
private let reactionFont = Font.regular(12.0)

private final class StatusReactionNodeParameters: NSObject {
    let value: String
    let previousValue: String?
    
    init(value: String, previousValue: String?) {
        self.value = value
        self.previousValue = previousValue
    }
}

private func drawReaction(context: CGContext, value: String, in rect: CGRect) {
    var fileId: Int?
    switch value {
    case "😔":
        fileId = 8
    case "😳":
        fileId = 19
    case "😂":
        fileId = 17
    case "👍":
        fileId = 6
    case "❤":
        fileId = 13
    default:
        break
    }
    if let fileId = fileId, let path = getAppBundle().path(forResource: "simplereaction_\(fileId)@2x", ofType: "png"), let image = UIImage(contentsOfFile: path) {
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -rect.midX, y: -rect.midY)
        context.draw(image.cgImage!, in: rect)
        context.restoreGState()
    } else {
        let string = NSAttributedString(string: value, font: reactionFont, textColor: .black)
        string.draw(at: CGPoint(x: rect.minX + 1.0, y: rect.minY + 3.0))
    }
}

private final class StatusReactionNode: ASDisplayNode {
    let value: String
    var count: Int
    var previousValue: String? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(value: String, count: Int, previousValue: String?) {
        self.value = value
        self.count = count
        self.previousValue = previousValue
        
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = nil
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return StatusReactionNodeParameters(value: self.value, previousValue: self.previousValue)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? StatusReactionNodeParameters else {
            return
        }
        drawReaction(context: context, value: parameters.value, in: bounds)
        if let previousValue = parameters.previousValue {
            let previousRect = bounds.offsetBy(dx: -14.0, dy: 0)
            context.setBlendMode(.destinationOut)
            drawReaction(context: context, value: previousValue, in: previousRect)
        }
    }
}

class ChatMessageDateAndStatusNode: ASDisplayNode {
    private var backgroundNode: ASImageNode?
    private var checkSentNode: ASImageNode?
    private var checkReadNode: ASImageNode?
    private var clockFrameNode: ASImageNode?
    private var clockMinNode: ASImageNode?
    private let dateNode: TextNode
    private var impressionIcon: ASImageNode?
    private var reactionNodes: [StatusReactionNode] = []
    private var reactionCountNode: TextNode?
    private var reactionButtonNode: HighlightTrackingButtonNode?
    
    private var type: ChatMessageDateAndStatusType?
    private var theme: ChatPresentationThemeData?
    
    var openReactions: (() -> Void)?
    
    override init() {
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.dateNode)
    }
    
    func asyncLayout() -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize, _ reactions: [MessageReaction]) -> (CGSize, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        
        var checkReadNode = self.checkReadNode
        var checkSentNode = self.checkSentNode
        var clockFrameNode = self.clockFrameNode
        var clockMinNode = self.clockMinNode
        
        var currentBackgroundNode = self.backgroundNode
        var currentImpressionIcon = self.impressionIcon
        
        let currentType = self.type
        let currentTheme = self.theme
        
        let makeReactionCountLayout = TextNode.asyncLayout(self.reactionCountNode)
        
        return { context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions in
            let dateColor: UIColor
            var backgroundImage: UIImage?
            var outgoingStatus: ChatMessageDateAndStatusOutgoingType?
            var leftInset: CGFloat
            
            let loadedCheckFullImage: UIImage?
            let loadedCheckPartialImage: UIImage?
            let clockFrameImage: UIImage?
            let clockMinImage: UIImage?
            var impressionImage: UIImage?
            
            let themeUpdated = presentationData.theme != currentTheme || type != currentType
            
            let graphics = PresentationResourcesChat.principalGraphics(mediaBox: context.account.postbox.mediaBox, knockoutWallpaper: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            let isDefaultWallpaper = serviceMessageColorHasDefaultWallpaper(presentationData.theme.wallpaper)
            let offset: CGFloat = -UIScreenPixel
            
            let checkSize: CGFloat = floor(floor(presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
            
            switch type {
                case .BubbleIncoming:
                    dateColor = presentationData.theme.theme.chat.message.incoming.secondaryTextColor
                    leftInset = 10.0
                    loadedCheckFullImage = PresentationResourcesChat.chatOutgoingFullCheck(presentationData.theme.theme, size: checkSize)
                    loadedCheckPartialImage = PresentationResourcesChat.chatOutgoingPartialCheck(presentationData.theme.theme, size: checkSize)
                    clockFrameImage = graphics.clockBubbleIncomingFrameImage
                    clockMinImage = graphics.clockBubbleIncomingMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.incomingDateAndStatusImpressionIcon
                    }
                case let .BubbleOutgoing(status):
                    dateColor = presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    outgoingStatus = status
                    leftInset = 10.0
                    loadedCheckFullImage = PresentationResourcesChat.chatOutgoingFullCheck(presentationData.theme.theme, size: checkSize)
                    loadedCheckPartialImage = PresentationResourcesChat.chatOutgoingPartialCheck(presentationData.theme.theme, size: checkSize)
                    clockFrameImage = graphics.clockBubbleOutgoingFrameImage
                    clockMinImage = graphics.clockBubbleOutgoingMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.outgoingDateAndStatusImpressionIcon
                    }
                case .ImageIncoming:
                    dateColor = presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                    backgroundImage = graphics.dateAndStatusMediaBackground
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatMediaFullCheck(presentationData.theme.theme, size: checkSize)
                    loadedCheckPartialImage = PresentationResourcesChat.chatMediaPartialCheck(presentationData.theme.theme, size: checkSize)
                    clockFrameImage = graphics.clockMediaFrameImage
                    clockMinImage = graphics.clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.mediaImpressionIcon
                    }
                case let .ImageOutgoing(status):
                    dateColor = presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                    outgoingStatus = status
                    backgroundImage = graphics.dateAndStatusMediaBackground
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatMediaFullCheck(presentationData.theme.theme, size: checkSize)
                    loadedCheckPartialImage = PresentationResourcesChat.chatMediaPartialCheck(presentationData.theme.theme, size: checkSize)
                    clockFrameImage = graphics.clockMediaFrameImage
                    clockMinImage = graphics.clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.mediaImpressionIcon
                    }
                case .FreeIncoming:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText
                    backgroundImage = graphics.dateAndStatusFreeBackground
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
                case let .FreeOutgoing(status):
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText
                    outgoingStatus = status
                    backgroundImage = graphics.dateAndStatusFreeBackground
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
            }
            
            var updatedDateText = dateText
            if edited {
                updatedDateText = "\(presentationData.strings.Conversation_MessageEditedLabel) \(updatedDateText)"
            }
            if let impressionCount = impressionCount {
                updatedDateText = compactNumericCountString(impressionCount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) + " " + updatedDateText
            }
            
            let dateFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
            let (date, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: updatedDateText, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let checkOffset = floor(presentationData.fontSize.baseDisplaySize * 6.0 / 17.0)
            
            let statusWidth: CGFloat
            
            var checkSentFrame: CGRect?
            var checkReadFrame: CGRect?
            
            var clockPosition = CGPoint()
            
            var impressionSize = CGSize()
            var impressionWidth: CGFloat = 0.0
            if let impressionImage = impressionImage {
                if currentImpressionIcon == nil {
                    let iconNode = ASImageNode()
                    iconNode.isLayerBacked = true
                    iconNode.displayWithoutProcessing = true
                    iconNode.displaysAsynchronously = false
                    currentImpressionIcon = iconNode
                }
                impressionSize = impressionImage.size
                impressionWidth = impressionSize.width + 3.0
            } else {
                currentImpressionIcon = nil
            }
            
            if let outgoingStatus = outgoingStatus {
                switch outgoingStatus {
                    case .Sending:
                        statusWidth = 13.0
                        
                        if checkReadNode == nil {
                            checkReadNode = ASImageNode()
                            checkReadNode?.isLayerBacked = true
                            checkReadNode?.displaysAsynchronously = false
                            checkReadNode?.displayWithoutProcessing = true
                        }
                        
                        if checkSentNode == nil {
                            checkSentNode = ASImageNode()
                            checkSentNode?.isLayerBacked = true
                            checkSentNode?.displaysAsynchronously = false
                            checkSentNode?.displayWithoutProcessing = true
                        }
                        
                        if clockFrameNode == nil {
                            clockFrameNode = ASImageNode()
                            clockFrameNode?.isLayerBacked = true
                            clockFrameNode?.displaysAsynchronously = false
                            clockFrameNode?.displayWithoutProcessing = true
                            clockFrameNode?.frame = CGRect(origin: CGPoint(), size: clockFrameImage?.size ?? CGSize())
                        }
                        
                        if clockMinNode == nil {
                            clockMinNode = ASImageNode()
                            clockMinNode?.isLayerBacked = true
                            clockMinNode?.displaysAsynchronously = false
                            clockMinNode?.displayWithoutProcessing = true
                            clockMinNode?.frame = CGRect(origin: CGPoint(), size: clockMinImage?.size ?? CGSize())
                        }
                        clockPosition = CGPoint(x: leftInset + date.size.width + 8.5, y: 7.5 + offset)
                    case let .Sent(read):
                        let hideStatus: Bool
                        switch type {
                            case .BubbleOutgoing, .FreeOutgoing, .ImageOutgoing:
                                hideStatus = false
                            default:
                                hideStatus = impressionCount != nil
                        }
                        
                        if hideStatus {
                            statusWidth = 0.0
                            
                            checkReadNode = nil
                            checkSentNode = nil
                            clockFrameNode = nil
                            clockMinNode = nil
                        } else {
                            statusWidth = floor(floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                            
                            if checkReadNode == nil {
                                checkReadNode = ASImageNode()
                                checkReadNode?.isLayerBacked = true
                                checkReadNode?.displaysAsynchronously = false
                                checkReadNode?.displayWithoutProcessing = true
                            }
                            
                            if checkSentNode == nil {
                                checkSentNode = ASImageNode()
                                checkSentNode?.isLayerBacked = true
                                checkSentNode?.displaysAsynchronously = false
                                checkSentNode?.displayWithoutProcessing = true
                            }
                            
                            clockFrameNode = nil
                            clockMinNode = nil
                            
                            let checkSize = loadedCheckFullImage!.size
                            
                            if read {
                                checkReadFrame = CGRect(origin: CGPoint(x: leftInset + impressionWidth + date.size.width + 5.0 + statusWidth - checkSize.width, y: 3.0 + offset), size: checkSize)
                            }
                            checkSentFrame = CGRect(origin: CGPoint(x: leftInset + impressionWidth + date.size.width + 5.0 + statusWidth - checkSize.width - checkOffset, y: 3.0 + offset), size: checkSize)
                        }
                    case .Failed:
                        statusWidth = 0.0
                        
                        checkReadNode = nil
                        checkSentNode = nil
                        clockFrameNode = nil
                        clockMinNode = nil
                }
            } else {
                statusWidth = 0.0
                
                checkReadNode = nil
                checkSentNode = nil
                clockFrameNode = nil
                clockMinNode = nil
            }
            
            var backgroundInsets = UIEdgeInsets()
            
            if let _ = backgroundImage {
                if currentBackgroundNode == nil {
                    let backgroundNode = ASImageNode()
                    backgroundNode.isLayerBacked = true
                    backgroundNode.displayWithoutProcessing = true
                    backgroundNode.displaysAsynchronously = false
                    currentBackgroundNode = backgroundNode
                }
                backgroundInsets = UIEdgeInsets(top: 2.0, left: 7.0, bottom: 2.0, right: 7.0)
            }
            
            var reactionCountLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            
            let reactionSpacing: CGFloat = -4.0
            let reactionTrailingSpacing: CGFloat = 4.0
            var reactionInset: CGFloat = 0.0
            if !reactions.isEmpty {
                reactionInset = 5.0 + CGFloat(reactions.count) * reactionSize + CGFloat(reactions.count - 1) * reactionSpacing + reactionTrailingSpacing
                
                var count = 0
                for reaction in reactions {
                    count += Int(reaction.count)
                }
                
                let layoutAndApply = makeReactionCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(count)", font: reactionCountFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
                reactionInset += layoutAndApply.0.size.width + 2.0
                reactionCountLayoutAndApply = layoutAndApply
            }
            leftInset += reactionInset
            
            let layoutSize = CGSize(width: leftInset + impressionWidth + date.size.width + statusWidth + backgroundInsets.left + backgroundInsets.right, height: date.size.height + backgroundInsets.top + backgroundInsets.bottom)
            
            return (layoutSize, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.theme = presentationData.theme
                    strongSelf.type = type
                    
                    if backgroundImage != nil {
                        if let currentBackgroundNode = currentBackgroundNode {
                            if currentBackgroundNode.supernode == nil {
                                strongSelf.backgroundNode = currentBackgroundNode
                                currentBackgroundNode.image = backgroundImage
                                strongSelf.insertSubnode(currentBackgroundNode, at: 0)
                            } else if themeUpdated {
                                currentBackgroundNode.image = backgroundImage
                            }
                        }
                        strongSelf.backgroundNode?.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    } else {
                        if let backgroundNode = strongSelf.backgroundNode {
                            backgroundNode.removeFromSupernode()
                            strongSelf.backgroundNode = nil
                        }
                    }
                    
                    strongSelf.dateNode.displaysAsynchronously = !presentationData.isPreview
                    let _ = dateApply()
                    
                    if let currentImpressionIcon = currentImpressionIcon {
                        if currentImpressionIcon.image !== impressionImage {
                            currentImpressionIcon.image = impressionImage
                        }
                        if currentImpressionIcon.supernode == nil {
                            strongSelf.impressionIcon = currentImpressionIcon
                            strongSelf.addSubnode(currentImpressionIcon)
                        }
                        currentImpressionIcon.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left, y: backgroundInsets.top + 1.0 + offset + floor((date.size.height - impressionSize.height) / 2.0)), size: impressionSize)
                    } else if let impressionIcon = strongSelf.impressionIcon {
                        impressionIcon.removeFromSupernode()
                        strongSelf.impressionIcon = nil
                    }
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left + impressionWidth, y: backgroundInsets.top + 1.0 + offset), size: date.size)
                    
                    if let clockFrameNode = clockFrameNode {
                        if strongSelf.clockFrameNode == nil {
                            strongSelf.clockFrameNode = clockFrameNode
                            clockFrameNode.image = clockFrameImage
                            strongSelf.addSubnode(clockFrameNode)
                        } else if themeUpdated {
                            clockFrameNode.image = clockFrameImage
                        }
                        clockFrameNode.position = CGPoint(x: backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y)
                        if let clockFrameNode = strongSelf.clockFrameNode {
                            maybeAddRotationAnimation(clockFrameNode.layer, duration: 6.0)
                        }
                    } else if let clockFrameNode = strongSelf.clockFrameNode {
                        clockFrameNode.removeFromSupernode()
                        strongSelf.clockFrameNode = nil
                    }
                    
                    if let clockMinNode = clockMinNode {
                        if strongSelf.clockMinNode == nil {
                            strongSelf.clockMinNode = clockMinNode
                            clockMinNode.image = clockMinImage
                            strongSelf.addSubnode(clockMinNode)
                        } else if themeUpdated {
                            clockMinNode.image = clockMinImage
                        }
                        clockMinNode.position = CGPoint(x: backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y)
                        if let clockMinNode = strongSelf.clockMinNode {
                            maybeAddRotationAnimation(clockMinNode.layer, duration: 1.0)
                        }
                    } else if let clockMinNode = strongSelf.clockMinNode {
                        clockMinNode.removeFromSupernode()
                        strongSelf.clockMinNode = nil
                    }
                    
                    if let checkSentNode = checkSentNode, let checkReadNode = checkReadNode {
                        var animateSentNode = false
                        if strongSelf.checkSentNode == nil {
                            checkSentNode.image = loadedCheckFullImage
                            strongSelf.checkSentNode = checkSentNode
                            strongSelf.addSubnode(checkSentNode)
                            animateSentNode = animated
                        } else if themeUpdated {
                            checkSentNode.image = loadedCheckFullImage
                        }
                        
                        if let checkSentFrame = checkSentFrame {
                            if checkSentNode.isHidden {
                                animateSentNode = animated
                            }
                            checkSentNode.isHidden = false
                            checkSentNode.frame = checkSentFrame.offsetBy(dx: backgroundInsets.left + reactionInset, dy: backgroundInsets.top)
                        } else {
                            checkSentNode.isHidden = true
                        }
                        
                        var animateReadNode = false
                        if strongSelf.checkReadNode == nil {
                            animateReadNode = animated
                            checkReadNode.image = loadedCheckPartialImage
                            strongSelf.checkReadNode = checkReadNode
                            strongSelf.addSubnode(checkReadNode)
                        } else if themeUpdated {
                            checkReadNode.image = loadedCheckPartialImage
                        }
                    
                        if let checkReadFrame = checkReadFrame {
                            if checkReadNode.isHidden {
                                animateReadNode = animated
                            }
                            checkReadNode.isHidden = false
                            checkReadNode.frame = checkReadFrame.offsetBy(dx: backgroundInsets.left + reactionInset, dy: backgroundInsets.top)
                        } else {
                            checkReadNode.isHidden = true
                        }
                        
                        if animateSentNode {
                            strongSelf.checkSentNode?.layer.animateScale(from: 1.3, to: 1.0, duration: 0.1)
                        }
                        if animateReadNode {
                            strongSelf.checkReadNode?.layer.animateScale(from: 1.3, to: 1.0, duration: 0.1)
                        }
                    } else if let checkSentNode = strongSelf.checkSentNode, let checkReadNode = strongSelf.checkReadNode {
                        checkSentNode.removeFromSupernode()
                        checkReadNode.removeFromSupernode()
                        strongSelf.checkSentNode = nil
                        strongSelf.checkReadNode = nil
                    }
                    
                    var reactionOffset: CGFloat = leftInset - reactionInset + backgroundInsets.left
                    for i in 0 ..< reactions.count {
                        let node: StatusReactionNode
                        if strongSelf.reactionNodes.count > i, strongSelf.reactionNodes[i].value == reactions[i].value {
                            node = strongSelf.reactionNodes[i]
                            node.count = Int(reactions[i].count)
                            node.previousValue = i == 0 ? nil : reactions[i - 1].value
                        } else {
                            node = StatusReactionNode(value: reactions[i].value, count: Int(reactions[i].count), previousValue: i == 0 ? nil : reactions[i - 1].value)
                            if strongSelf.reactionNodes.count > i {
                                let previousNode = strongSelf.reactionNodes[i]
                                if animated {
                                    previousNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousNode] _ in
                                        previousNode?.removeFromSupernode()
                                    })
                                } else {
                                    previousNode.removeFromSupernode()
                                }
                                strongSelf.reactionNodes[i] = node
                            } else {
                                strongSelf.reactionNodes.append(node)
                            }
                        }
                        if node.supernode == nil {
                            strongSelf.addSubnode(node)
                            if animated {
                                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            }
                        }
                        node.frame = CGRect(origin: CGPoint(x: reactionOffset, y: backgroundInsets.top + offset - 3.0), size: CGSize(width: reactionSize, height: reactionSize))
                        reactionOffset += reactionSize + reactionSpacing
                    }
                    if !reactions.isEmpty {
                        reactionOffset += reactionTrailingSpacing
                    }
                    for _ in reactions.count ..< strongSelf.reactionNodes.count {
                        let node = strongSelf.reactionNodes.removeLast()
                        if animated {
                            node.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                            node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak node] _ in
                                node?.removeFromSupernode()
                            })
                        } else {
                            node.removeFromSupernode()
                        }
                    }
                    
                    if let (layout, apply) = reactionCountLayoutAndApply {
                        let node = apply()
                        if strongSelf.reactionCountNode !== node {
                            strongSelf.reactionCountNode?.removeFromSupernode()
                            strongSelf.addSubnode(node)
                            strongSelf.reactionCountNode = node
                            if animated {
                                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            }
                        }
                        node.frame = CGRect(origin: CGPoint(x: reactionOffset + 1.0, y: backgroundInsets.top + 1.0 + offset), size: layout.size)
                        reactionOffset += 1.0 + layout.size.width
                    } else if let reactionCountNode = strongSelf.reactionCountNode {
                        strongSelf.reactionCountNode = nil
                        if animated {
                            reactionCountNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionCountNode] _ in
                                reactionCountNode?.removeFromSupernode()
                            })
                        } else {
                            reactionCountNode.removeFromSupernode()
                        }
                    }
                    
                    if false, !strongSelf.reactionNodes.isEmpty {
                        if strongSelf.reactionButtonNode == nil {
                            let reactionButtonNode = HighlightTrackingButtonNode()
                            strongSelf.reactionButtonNode = reactionButtonNode
                            strongSelf.addSubnode(reactionButtonNode)
                            reactionButtonNode.addTarget(strongSelf, action: #selector(strongSelf.reactionButtonPressed), forControlEvents: .touchUpInside)
                            reactionButtonNode.highligthedChanged = { [weak strongSelf] highlighted in
                                guard let strongSelf = strongSelf else {
                                    return
                                }
                                if highlighted {
                                    for itemNode in strongSelf.reactionNodes {
                                        itemNode.alpha = 0.4
                                    }
                                } else {
                                    for itemNode in strongSelf.reactionNodes {
                                        itemNode.alpha = 1.0
                                        itemNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.3)
                                    }
                                }
                            }
                        }
                        strongSelf.reactionButtonNode?.frame = CGRect(origin: CGPoint(x: leftInset - reactionInset + backgroundInsets.left - 5.0, y: backgroundInsets.top + 1.0 + offset - 5.0), size: CGSize(width: reactionOffset + 5.0 * 2.0, height: 20.0))
                    } else if let reactionButtonNode = strongSelf.reactionButtonNode {
                        strongSelf.reactionButtonNode = nil
                        reactionButtonNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageDateAndStatusNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize, _ reactions: [MessageReaction]) -> (CGSize, (Bool) -> ChatMessageDateAndStatusNode) {
        let currentLayout = node?.asyncLayout()
        return { context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions in
            let resultNode: ChatMessageDateAndStatusNode
            let resultSizeAndApply: (CGSize, (Bool) -> Void)
            if let node = node, let currentLayout = currentLayout {
                resultNode = node
                resultSizeAndApply = currentLayout(context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions)
            } else {
                resultNode = ChatMessageDateAndStatusNode()
                resultSizeAndApply = resultNode.asyncLayout()(context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions)
            }
            
            return (resultSizeAndApply.0, { animated in
                resultSizeAndApply.1(animated)
                return resultNode
            })
        }
    }
    
    func reactionNode(value: String) -> (ASDisplayNode, Int)? {
        for node in self.reactionNodes {
            if node.value == value {
                return (node, node.count)
            }
        }
        return nil
    }
    
    @objc private func reactionButtonPressed() {
        self.openReactions?()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let reactionButtonNode = self.reactionButtonNode {
            if reactionButtonNode.frame.contains(point) {
                return reactionButtonNode.view
            }
        }
        return nil
    }
}
