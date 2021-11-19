import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle

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

private let reactionCountFont = Font.semibold(11.0)
private let reactionFont = Font.regular(12.0)

private final class StatusReactionNode: ASDisplayNode {
    let selectedImageNode: ASImageNode
    
    private var theme: PresentationTheme?
    private var value: String?
    private var isSelected: Bool?
    
    override init() {
        self.selectedImageNode = ASImageNode()
        self.selectedImageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.selectedImageNode)
    }
    
    func update(type: ChatMessageDateAndStatusType, value: String, isSelected: Bool, count: Int, theme: PresentationTheme, wallpaper: TelegramWallpaper, animated: Bool) {
        if self.value != value {
            self.value = value
            
            let selectedImage: UIImage? = generateImage(CGSize(width: 14.0, height: 14.0), rotatedContext: { size, context in
                UIGraphicsPushContext(context)
                
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.scaleBy(x: size.width / 20.0, y: size.width / 20.0)
                
                let string = NSAttributedString(string: value, font: reactionFont, textColor: .black)
                string.draw(at: CGPoint(x: 1.0, y: 2.0))
                
                UIGraphicsPopContext()
            })
            
            if let selectedImage = selectedImage {
                self.selectedImageNode.image = selectedImage
                self.selectedImageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: selectedImage.size)
            }
        }
        
        /*if self.isSelected != isSelected {
            let wasSelected = self.isSelected
            self.isSelected = isSelected
            
            self.emptyImageNode.isHidden = isSelected && count <= 1
            self.selectedImageNode.isHidden = !isSelected
            
            if let wasSelected = wasSelected, wasSelected, !isSelected {
                if let image = self.selectedImageNode.image {
                    let leftImage = generateImage(image.size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        UIGraphicsPushContext(context)
                        image.draw(in: CGRect(origin: CGPoint(), size: size))
                        UIGraphicsPopContext()
                        context.clear(CGRect(origin: CGPoint(x: size.width / 2.0, y: 0.0), size: CGSize(width: size.width / 2.0, height: size.height)))
                    })
                    let rightImage = generateImage(image.size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        UIGraphicsPushContext(context)
                        image.draw(in: CGRect(origin: CGPoint(), size: size))
                        UIGraphicsPopContext()
                        context.clear(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width / 2.0, height: size.height)))
                    })
                    if let leftImage = leftImage, let rightImage = rightImage {
                        let leftView = UIImageView()
                        leftView.image = leftImage
                        leftView.frame = self.selectedImageNode.frame
                        let rightView = UIImageView()
                        rightView.image = rightImage
                        rightView.frame = self.selectedImageNode.frame
                        self.view.addSubview(leftView)
                        self.view.addSubview(rightView)
                        
                        let duration: Double = 0.3
                        
                        leftView.layer.animateRotation(from: 0.0, to: -CGFloat.pi * 0.7, duration: duration, removeOnCompletion: false)
                        rightView.layer.animateRotation(from: 0.0, to: CGFloat.pi * 0.7, duration: duration, removeOnCompletion: false)
                        
                        leftView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -6.0, y: 8.0), duration: duration, removeOnCompletion: false, additive: true)
                        rightView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 6.0, y: 8.0), duration: duration, removeOnCompletion: false, additive: true)
                        
                        leftView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak leftView] _ in
                            leftView?.removeFromSuperview()
                        })
                        
                        rightView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak rightView] _ in
                            rightView?.removeFromSuperview()
                        })
                    }
                }
            }
        }*/
    }
}


class ChatMessageDateAndStatusNode: ASDisplayNode {
    private var backgroundNode: ASImageNode?
    private var blurredBackgroundNode: NavigationBackgroundNode?
    private var checkSentNode: ASImageNode?
    private var checkReadNode: ASImageNode?
    private var clockFrameNode: ASImageNode?
    private var clockMinNode: ASImageNode?
    private let dateNode: TextNode
    private var impressionIcon: ASImageNode?
    private var reactionNodes: [StatusReactionNode] = []
    private var reactionCountNode: TextNode?
    private var reactionButtonNode: HighlightTrackingButtonNode?
    private var repliesIcon: ASImageNode?
    private var selfExpiringIcon: ASImageNode?
    private var replyCountNode: TextNode?
    
    private var type: ChatMessageDateAndStatusType?
    private var theme: ChatPresentationThemeData?
    private var layoutSize: CGSize?
    
    private var tapGestureRecognizer: UITapGestureRecognizer?

    var openReplies: (() -> Void)?
    var pressed: (() -> Void)? {
        didSet {
            if self.pressed != nil {
                if self.tapGestureRecognizer == nil {
                    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                    self.tapGestureRecognizer = tapGestureRecognizer
                    self.view.addGestureRecognizer(tapGestureRecognizer)
                }
            } else if let tapGestureRecognizer = self.tapGestureRecognizer{
                self.tapGestureRecognizer = nil
                self.view.removeGestureRecognizer(tapGestureRecognizer)
            }
        }
    }
    
    override init() {
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.dateNode)
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.pressed?()
        }
    }
    
    func asyncLayout() -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize, _ reactions: [MessageReaction], _ replies: Int, _ isPinned: Bool, _ hasAutoremove: Bool) -> (CGSize, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        
        var checkReadNode = self.checkReadNode
        var checkSentNode = self.checkSentNode
        var clockFrameNode = self.clockFrameNode
        var clockMinNode = self.clockMinNode
        
        var currentBackgroundNode = self.backgroundNode
        var currentImpressionIcon = self.impressionIcon
        var currentRepliesIcon = self.repliesIcon
        
        let currentType = self.type
        let currentTheme = self.theme

        let makeReplyCountLayout = TextNode.asyncLayout(self.replyCountNode)
        let makeReactionCountLayout = TextNode.asyncLayout(self.reactionCountNode)
        
        let previousLayoutSize = self.layoutSize
        
        return { context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions, replyCount, isPinned, hasAutoremove in
            let dateColor: UIColor
            var backgroundImage: UIImage?
            var blurredBackgroundColor: (UIColor, Bool)?
            var outgoingStatus: ChatMessageDateAndStatusOutgoingType?
            var leftInset: CGFloat
            
            let loadedCheckFullImage: UIImage?
            let loadedCheckPartialImage: UIImage?
            let clockFrameImage: UIImage?
            let clockMinImage: UIImage?
            var impressionImage: UIImage?
            var repliesImage: UIImage?
            
            let themeUpdated = presentationData.theme != currentTheme || type != currentType
            
            let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
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
                    if replyCount != 0 {
                        repliesImage = graphics.incomingDateAndStatusRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.incomingDateAndStatusPinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.incomingDateAndStatusSelfExpiringIcon
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
                    if replyCount != 0 {
                        repliesImage = graphics.outgoingDateAndStatusRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.outgoingDateAndStatusPinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.outgoingDateAndStatusSelfExpiringIcon
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
                    if replyCount != 0 {
                        repliesImage = graphics.mediaRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.mediaPinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.mediaSelfExpiringIcon
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
                    if replyCount != 0 {
                        repliesImage = graphics.mediaRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.mediaPinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.mediaSelfExpiringIcon
                    }
                case .FreeIncoming:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText

                    blurredBackgroundColor = (selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper))
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
                    if replyCount != 0 {
                        repliesImage = graphics.freeRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.freePinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.freeSelfExpiringIcon
                    }
                case let .FreeOutgoing(status):
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText
                    outgoingStatus = status
                    //backgroundImage = graphics.dateAndStatusFreeBackground
                    blurredBackgroundColor = (selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper))
                    leftInset = 0.0
                    loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
                    if replyCount != 0 {
                        repliesImage = graphics.freeRepliesIcon
                    } else if isPinned {
                        repliesImage = graphics.freePinnedIcon
                    }
                    if hasAutoremove {
                        //selfExpiringImage = graphics.freeSelfExpiringIcon
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
            
            var repliesIconSize = CGSize()
            if let repliesImage = repliesImage {
                if currentRepliesIcon == nil {
                    let iconNode = ASImageNode()
                    iconNode.isLayerBacked = true
                    iconNode.displayWithoutProcessing = true
                    iconNode.displaysAsynchronously = false
                    currentRepliesIcon = iconNode
                }
                repliesIconSize = repliesImage.size
            } else {
                currentRepliesIcon = nil
            }
            
            if let outgoingStatus = outgoingStatus {
                switch outgoingStatus {
                    case .Sending:
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
            } else if blurredBackgroundColor != nil {
                backgroundInsets = UIEdgeInsets(top: 2.0, left: 7.0, bottom: 2.0, right: 7.0)
            }

            var replyCountLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            
            let reactionSize: CGFloat = 14.0
            var reactionCountLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let reactionSpacing: CGFloat = -4.0
            let reactionTrailingSpacing: CGFloat = 4.0

            var reactionInset: CGFloat = 0.0
            if !reactions.isEmpty {
                reactionInset = -1.0 + CGFloat(reactions.count) * reactionSize + CGFloat(reactions.count - 1) * reactionSpacing + reactionTrailingSpacing
                
                var count = 0
                for reaction in reactions {
                    count += Int(reaction.count)
                }
                
                let countString: String
                if count > 1000000 {
                    countString = "\(count / 1000000)M"
                } else if count > 1000 {
                    countString = "\(count / 1000)K"
                } else {
                    countString = "\(count)"
                }
                
                let layoutAndApply = makeReactionCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: countString, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
                reactionInset += max(10.0, layoutAndApply.0.size.width) + 2.0
                reactionCountLayoutAndApply = layoutAndApply
            }
            
            if replyCount > 0 {
                let countString: String
                if replyCount > 1000000 {
                    countString = "\(replyCount / 1000000)M"
                } else if replyCount > 1000 {
                    countString = "\(replyCount / 1000)K"
                } else {
                    countString = "\(replyCount)"
                }
                
                let layoutAndApply = makeReplyCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: countString, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
                reactionInset += 14.0 + layoutAndApply.0.size.width + 4.0
                replyCountLayoutAndApply = layoutAndApply
            } else if isPinned {
                reactionInset += 12.0
            }
            
            leftInset += reactionInset
            
            let layoutSize = CGSize(width: leftInset + impressionWidth + date.size.width + statusWidth + backgroundInsets.left + backgroundInsets.right, height: date.size.height + backgroundInsets.top + backgroundInsets.bottom)
            
            return (layoutSize, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.theme = presentationData.theme
                    strongSelf.type = type
                    strongSelf.layoutSize = layoutSize
                    
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
                        if let backgroundNode = strongSelf.backgroundNode {
                            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
                            if let previousLayoutSize = previousLayoutSize {
                                backgroundNode.frame = backgroundNode.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
                            transition.updateFrame(node: backgroundNode, frame: CGRect(origin: CGPoint(), size: layoutSize))
                        }
                    } else {
                        if let backgroundNode = strongSelf.backgroundNode {
                            backgroundNode.removeFromSupernode()
                            strongSelf.backgroundNode = nil
                        }
                    }

                    if let blurredBackgroundColor = blurredBackgroundColor {
                        if let blurredBackgroundNode = strongSelf.blurredBackgroundNode {
                            blurredBackgroundNode.updateColor(color: blurredBackgroundColor.0, enableBlur: blurredBackgroundColor.1, transition: .immediate)
                            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
                            if let previousLayoutSize = previousLayoutSize {
                                blurredBackgroundNode.frame = blurredBackgroundNode.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
                            transition.updateFrame(node: blurredBackgroundNode, frame: CGRect(origin: CGPoint(), size: layoutSize))
                            blurredBackgroundNode.update(size: blurredBackgroundNode.bounds.size, cornerRadius: blurredBackgroundNode.bounds.height / 2.0, transition: transition)
                        } else {
                            let blurredBackgroundNode = NavigationBackgroundNode(color: blurredBackgroundColor.0, enableBlur: blurredBackgroundColor.1)
                            strongSelf.blurredBackgroundNode = blurredBackgroundNode
                            strongSelf.insertSubnode(blurredBackgroundNode, at: 0)
                            blurredBackgroundNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                            blurredBackgroundNode.update(size: blurredBackgroundNode.bounds.size, cornerRadius: blurredBackgroundNode.bounds.height / 2.0, transition: .immediate)
                        }
                    } else if let blurredBackgroundNode = strongSelf.blurredBackgroundNode {
                        strongSelf.blurredBackgroundNode = nil
                        blurredBackgroundNode.removeFromSupernode()
                    }
                    
                    strongSelf.dateNode.displaysAsynchronously = !presentationData.isPreview
                    let _ = dateApply()
                    
                    if let currentImpressionIcon = currentImpressionIcon {
                        currentImpressionIcon.displaysAsynchronously = !presentationData.isPreview
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
                        if strongSelf.reactionNodes.count > i {
                            node = strongSelf.reactionNodes[i]
                        } else {
                            node = StatusReactionNode()
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
                        
                        node.update(type: type, value: reactions[i].value, isSelected: reactions[i].isSelected, count: Int(reactions[i].count), theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, animated: false)
                        if node.supernode == nil {
                            strongSelf.addSubnode(node)
                            if animated {
                                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        node.frame = CGRect(origin: CGPoint(x: reactionOffset, y: backgroundInsets.top + offset + 1.0), size: CGSize(width: reactionSize, height: reactionSize))
                        reactionOffset += reactionSize + reactionSpacing
                    }
                    if !reactions.isEmpty {
                        reactionOffset += reactionTrailingSpacing
                    }
                    for _ in reactions.count ..< strongSelf.reactionNodes.count {
                        let node = strongSelf.reactionNodes.removeLast()
                        if animated {
                            if let previousLayoutSize = previousLayoutSize {
                                node.frame = node.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
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
                        reactionOffset += 1.0 + layout.size.width + 4.0
                    } else if let reactionCountNode = strongSelf.reactionCountNode {
                        strongSelf.reactionCountNode = nil
                        if animated {
                            if let previousLayoutSize = previousLayoutSize {
                                reactionCountNode.frame = reactionCountNode.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
                            reactionCountNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionCountNode] _ in
                                reactionCountNode?.removeFromSupernode()
                            })
                        } else {
                            reactionCountNode.removeFromSupernode()
                        }
                    }
                    
                    if let currentRepliesIcon = currentRepliesIcon {
                        currentRepliesIcon.displaysAsynchronously = !presentationData.isPreview
                        if currentRepliesIcon.image !== repliesImage {
                            currentRepliesIcon.image = repliesImage
                        }
                        if currentRepliesIcon.supernode == nil {
                            strongSelf.repliesIcon = currentRepliesIcon
                            strongSelf.addSubnode(currentRepliesIcon)
                            if animated {
                                currentRepliesIcon.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            }
                        }
                        currentRepliesIcon.frame = CGRect(origin: CGPoint(x: reactionOffset - 2.0, y: backgroundInsets.top + offset + floor((date.size.height - repliesIconSize.height) / 2.0)), size: repliesIconSize)
                        reactionOffset += 9.0
                    } else if let repliesIcon = strongSelf.repliesIcon {
                        strongSelf.repliesIcon = nil
                        if animated {
                            if let previousLayoutSize = previousLayoutSize {
                                repliesIcon.frame = repliesIcon.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
                            repliesIcon.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak repliesIcon] _ in
                                repliesIcon?.removeFromSupernode()
                            })
                        } else {
                            repliesIcon.removeFromSupernode()
                        }
                    }
                    
                    if let (layout, apply) = replyCountLayoutAndApply {
                        let node = apply()
                        if strongSelf.replyCountNode !== node {
                            strongSelf.replyCountNode?.removeFromSupernode()
                            strongSelf.addSubnode(node)
                            strongSelf.replyCountNode = node
                            if animated {
                                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            }
                        }
                        node.frame = CGRect(origin: CGPoint(x: reactionOffset + 4.0, y: backgroundInsets.top + 1.0 + offset), size: layout.size)
                        reactionOffset += 4.0 + layout.size.width
                    } else if let replyCountNode = strongSelf.replyCountNode {
                        strongSelf.replyCountNode = nil
                        if animated {
                            if let previousLayoutSize = previousLayoutSize {
                                replyCountNode.frame = replyCountNode.frame.offsetBy(dx: layoutSize.width - previousLayoutSize.width, dy: 0.0)
                            }
                            replyCountNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak replyCountNode] _ in
                                replyCountNode?.removeFromSupernode()
                            })
                        } else {
                            replyCountNode.removeFromSupernode()
                        }
                    }
                }
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageDateAndStatusNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize, _ reactions: [MessageReaction], _ replies: Int, _ isPinned: Bool, _ hasAutoremove: Bool) -> (CGSize, (Bool) -> ChatMessageDateAndStatusNode) {
        let currentLayout = node?.asyncLayout()
        return { context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions, replies, isPinned, hasAutoremove in
            let resultNode: ChatMessageDateAndStatusNode
            let resultSizeAndApply: (CGSize, (Bool) -> Void)
            if let node = node, let currentLayout = currentLayout {
                resultNode = node
                resultSizeAndApply = currentLayout(context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions, replies, isPinned, hasAutoremove)
            } else {
                resultNode = ChatMessageDateAndStatusNode()
                resultSizeAndApply = resultNode.asyncLayout()(context, presentationData, edited, impressionCount, dateText, type, constrainedSize, reactions, replies, isPinned, hasAutoremove)
            }
            
            return (resultSizeAndApply.0, { animated in
                resultSizeAndApply.1(animated)
                return resultNode
            })
        }
    }
    
    func reactionNode(value: String) -> (ASDisplayNode, ASDisplayNode)? {
        for node in self.reactionNodes {
            return (node.selectedImageNode, node.selectedImageNode)
        }
        return nil
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.pressed != nil {
            if self.bounds.contains(point) {
                return self.view
            }
        }
        return nil
    }
}
