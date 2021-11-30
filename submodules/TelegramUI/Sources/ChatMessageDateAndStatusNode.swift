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
import ReactionButtonListComponent

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
    }
}


class ChatMessageDateAndStatusNode: ASDisplayNode {
    enum LayoutInput {
        case trailingContent(contentWidth: CGFloat, preferAdditionalInset: Bool)
        case standalone
    }
    
    struct Arguments {
        var context: AccountContext
        var presentationData: ChatPresentationData
        var edited: Bool
        var impressionCount: Int?
        var dateText: String
        var type: ChatMessageDateAndStatusType
        var layoutInput: LayoutInput
        var constrainedSize: CGSize
        var availableReactions: AvailableReactions?
        var reactions: [MessageReaction]
        var replyCount: Int
        var isPinned: Bool
        var hasAutoremove: Bool
        
        init(
            context: AccountContext,
            presentationData: ChatPresentationData,
            edited: Bool,
            impressionCount: Int?,
            dateText: String,
            type: ChatMessageDateAndStatusType,
            layoutInput: LayoutInput,
            constrainedSize: CGSize,
            availableReactions: AvailableReactions?,
            reactions: [MessageReaction],
            replyCount: Int,
            isPinned: Bool,
            hasAutoremove: Bool
        ) {
            self.context = context
            self.presentationData = presentationData
            self.edited = edited
            self.impressionCount = impressionCount
            self.dateText = dateText
            self.type = type
            self.layoutInput = layoutInput
            self.availableReactions = availableReactions
            self.constrainedSize = constrainedSize
            self.reactions = reactions
            self.replyCount = replyCount
            self.isPinned = isPinned
            self.hasAutoremove = hasAutoremove
        }
    }
    
    private var backgroundNode: ASImageNode?
    private var blurredBackgroundNode: NavigationBackgroundNode?
    private var checkSentNode: ASImageNode?
    private var checkReadNode: ASImageNode?
    private var clockFrameNode: ASImageNode?
    private var clockMinNode: ASImageNode?
    private let dateNode: TextNode
    private var impressionIcon: ASImageNode?
    private var reactionNodes: [StatusReactionNode] = []
    private let reactionButtonsContainer = ReactionButtonsLayoutContainer()
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
    var reactionSelected: ((String) -> Void)?
    
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
    
    func asyncLayout() -> (_ arguments: Arguments) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> Void)) {
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
        
        let reactionButtonsContainer = self.reactionButtonsContainer
        
        return { [weak self] arguments in
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
            
            let themeUpdated = arguments.presentationData.theme != currentTheme || arguments.type != currentType
            
            let graphics = PresentationResourcesChat.principalGraphics(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper, bubbleCorners: arguments.presentationData.chatBubbleCorners)
            let isDefaultWallpaper = serviceMessageColorHasDefaultWallpaper(arguments.presentationData.theme.wallpaper)
            let offset: CGFloat = -UIScreenPixel
            
            let checkSize: CGFloat = floor(floor(arguments.presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
            
            let reactionColors: ReactionButtonComponent.Colors
            switch arguments.type {
            case .BubbleIncoming, .ImageIncoming, .FreeIncoming:
                reactionColors = ReactionButtonComponent.Colors(
                    background: arguments.presentationData.theme.theme.chat.message.incoming.accentControlColor.withMultipliedAlpha(0.1).argb,
                    foreground: arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor.argb,
                    stroke: arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor.argb
                )
            case .BubbleOutgoing, .ImageOutgoing, .FreeOutgoing:
                reactionColors = ReactionButtonComponent.Colors(
                    background: arguments.presentationData.theme.theme.chat.message.outgoing.accentControlColor.withMultipliedAlpha(0.1).argb,
                    foreground: arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor.argb,
                    stroke: arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor.argb
                )
            }
            
            switch arguments.type {
            case .BubbleIncoming:
                dateColor = arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor
                leftInset = 10.0
                loadedCheckFullImage = PresentationResourcesChat.chatOutgoingFullCheck(arguments.presentationData.theme.theme, size: checkSize)
                loadedCheckPartialImage = PresentationResourcesChat.chatOutgoingPartialCheck(arguments.presentationData.theme.theme, size: checkSize)
                clockFrameImage = graphics.clockBubbleIncomingFrameImage
                clockMinImage = graphics.clockBubbleIncomingMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.incomingDateAndStatusImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.incomingDateAndStatusRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.incomingDateAndStatusPinnedIcon
                }
            case let .BubbleOutgoing(status):
                dateColor = arguments.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                outgoingStatus = status
                leftInset = 10.0
                loadedCheckFullImage = PresentationResourcesChat.chatOutgoingFullCheck(arguments.presentationData.theme.theme, size: checkSize)
                loadedCheckPartialImage = PresentationResourcesChat.chatOutgoingPartialCheck(arguments.presentationData.theme.theme, size: checkSize)
                clockFrameImage = graphics.clockBubbleOutgoingFrameImage
                clockMinImage = graphics.clockBubbleOutgoingMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.outgoingDateAndStatusImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.outgoingDateAndStatusRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.outgoingDateAndStatusPinnedIcon
                }
            case .ImageIncoming:
                dateColor = arguments.presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                backgroundImage = graphics.dateAndStatusMediaBackground
                leftInset = 0.0
                loadedCheckFullImage = PresentationResourcesChat.chatMediaFullCheck(arguments.presentationData.theme.theme, size: checkSize)
                loadedCheckPartialImage = PresentationResourcesChat.chatMediaPartialCheck(arguments.presentationData.theme.theme, size: checkSize)
                clockFrameImage = graphics.clockMediaFrameImage
                clockMinImage = graphics.clockMediaMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.mediaImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.mediaRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.mediaPinnedIcon
                }
            case let .ImageOutgoing(status):
                dateColor = arguments.presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                outgoingStatus = status
                backgroundImage = graphics.dateAndStatusMediaBackground
                leftInset = 0.0
                loadedCheckFullImage = PresentationResourcesChat.chatMediaFullCheck(arguments.presentationData.theme.theme, size: checkSize)
                loadedCheckPartialImage = PresentationResourcesChat.chatMediaPartialCheck(arguments.presentationData.theme.theme, size: checkSize)
                clockFrameImage = graphics.clockMediaFrameImage
                clockMinImage = graphics.clockMediaMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.mediaImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.mediaRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.mediaPinnedIcon
                }
            case .FreeIncoming:
                let serviceColor = serviceMessageColorComponents(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper)
                dateColor = serviceColor.primaryText
                
                blurredBackgroundColor = (selectDateFillStaticColor(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper), dateFillNeedsBlur(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper))
                leftInset = 0.0
                loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(arguments.presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(arguments.presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                clockFrameImage = graphics.clockFreeFrameImage
                clockMinImage = graphics.clockFreeMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.freeImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.freeRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.freePinnedIcon
                }
            case let .FreeOutgoing(status):
                let serviceColor = serviceMessageColorComponents(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper)
                dateColor = serviceColor.primaryText
                outgoingStatus = status
                blurredBackgroundColor = (selectDateFillStaticColor(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper), dateFillNeedsBlur(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper))
                leftInset = 0.0
                loadedCheckFullImage = PresentationResourcesChat.chatFreeFullCheck(arguments.presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                loadedCheckPartialImage = PresentationResourcesChat.chatFreePartialCheck(arguments.presentationData.theme.theme, size: checkSize, isDefaultWallpaper: isDefaultWallpaper)
                clockFrameImage = graphics.clockFreeFrameImage
                clockMinImage = graphics.clockFreeMinImage
                if arguments.impressionCount != nil {
                    impressionImage = graphics.freeImpressionIcon
                }
                if arguments.replyCount != 0 {
                    repliesImage = graphics.freeRepliesIcon
                } else if arguments.isPinned {
                    repliesImage = graphics.freePinnedIcon
                }
            }
            
            var updatedDateText = arguments.dateText
            if arguments.edited {
                updatedDateText = "\(arguments.presentationData.strings.Conversation_MessageEditedLabel) \(updatedDateText)"
            }
            if let impressionCount = arguments.impressionCount {
                updatedDateText = compactNumericCountString(impressionCount, decimalSeparator: arguments.presentationData.dateTimeFormat.decimalSeparator) + " " + updatedDateText
            }
            
            let dateFont = Font.regular(floor(arguments.presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
            let (date, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: updatedDateText, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: arguments.constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let checkOffset = floor(arguments.presentationData.fontSize.baseDisplaySize * 6.0 / 17.0)
            
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
                    statusWidth = floor(floor(arguments.presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                    
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
                    switch arguments.type {
                        case .BubbleOutgoing, .FreeOutgoing, .ImageOutgoing:
                            hideStatus = false
                        default:
                        hideStatus = arguments.impressionCount != nil
                    }
                    
                    if hideStatus {
                        statusWidth = 0.0
                        
                        checkReadNode = nil
                        checkSentNode = nil
                        clockFrameNode = nil
                        clockMinNode = nil
                    } else {
                        statusWidth = floor(floor(arguments.presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                        
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
            if !"".isEmpty && !arguments.reactions.isEmpty {
                reactionInset = -1.0 + CGFloat(arguments.reactions.count) * reactionSize + CGFloat(arguments.reactions.count - 1) * reactionSpacing + reactionTrailingSpacing
                
                var count = 0
                for reaction in arguments.reactions {
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
            
            if arguments.replyCount > 0 {
                let countString: String
                if arguments.replyCount > 1000000 {
                    countString = "\(arguments.replyCount / 1000000)M"
                } else if arguments.replyCount > 1000 {
                    countString = "\(arguments.replyCount / 1000)K"
                } else {
                    countString = "\(arguments.replyCount)"
                }
                
                let layoutAndApply = makeReplyCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: countString, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
                reactionInset += 14.0 + layoutAndApply.0.size.width + 4.0
                replyCountLayoutAndApply = layoutAndApply
            } else if arguments.isPinned {
                reactionInset += 12.0
            }
            
            leftInset += reactionInset
            
            let layoutSize = CGSize(width: leftInset + impressionWidth + date.size.width + statusWidth + backgroundInsets.left + backgroundInsets.right, height: date.size.height + backgroundInsets.top + backgroundInsets.bottom)
            
            let verticalReactionsInset: CGFloat
            let verticalInset: CGFloat
            let resultingWidth: CGFloat
            let resultingHeight: CGFloat
            
            let reactionButtons: ReactionButtonsLayoutContainer.Result
            switch arguments.layoutInput {
            case .standalone:
                verticalReactionsInset = 0.0
                verticalInset = 0.0
                resultingWidth = layoutSize.width
                resultingHeight = layoutSize.height
                reactionButtons = reactionButtonsContainer.update(
                    context: arguments.context,
                    action: { value in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reactionSelected?(value)
                    },
                    reactions: [],
                    colors: reactionColors,
                    constrainedWidth: arguments.constrainedSize.width,
                    transition: .immediate
                )
            case let .trailingContent(contentWidth, preferAdditionalInset):
                reactionButtons = reactionButtonsContainer.update(
                    context: arguments.context,
                    action: { value in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reactionSelected?(value)
                    },
                    reactions: arguments.reactions.map { reaction in
                        var iconFile: TelegramMediaFile?
                        
                        if let availableReactions = arguments.availableReactions {
                            for availableReaction in availableReactions.reactions {
                                if availableReaction.value == reaction.value {
                                    iconFile = availableReaction.staticIcon
                                    break
                                }
                            }
                        }
                        
                        return ReactionButtonsLayoutContainer.Reaction(
                            reaction: ReactionButtonComponent.Reaction(
                                value: reaction.value,
                                iconFile: iconFile
                            ),
                            count: Int(reaction.count),
                            isSelected: reaction.isSelected
                        )
                    },
                    colors: reactionColors,
                    constrainedWidth: arguments.constrainedSize.width,
                    transition: .immediate
                )
                
                var reactionButtonsSize = CGSize()
                var currentRowWidth: CGFloat = 0.0
                for item in reactionButtons.items {
                    if currentRowWidth + item.size.width > arguments.constrainedSize.width {
                        reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
                        if !reactionButtonsSize.height.isZero {
                            reactionButtonsSize.height += 6.0
                        }
                        reactionButtonsSize.height += item.size.height
                        currentRowWidth = 0.0
                    }
                    
                    if !currentRowWidth.isZero {
                        currentRowWidth += 6.0
                    }
                    currentRowWidth += item.size.width
                }
                if !currentRowWidth.isZero && !reactionButtons.items.isEmpty {
                    reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
                    if !reactionButtonsSize.height.isZero {
                        reactionButtonsSize.height += 6.0
                    }
                    reactionButtonsSize.height += reactionButtons.items[0].size.height
                }
                
                if reactionButtonsSize.width.isZero {
                    verticalReactionsInset = 0.0
                    if contentWidth + layoutSize.width > arguments.constrainedSize.width {
                        resultingWidth = layoutSize.width
                        verticalInset = 0.0
                        resultingHeight = layoutSize.height + verticalInset
                    } else {
                        resultingWidth = contentWidth + layoutSize.width
                        verticalInset = -layoutSize.height
                        resultingHeight = 0.0
                    }
                } else {
                    if preferAdditionalInset {
                        verticalReactionsInset = 5.0
                    } else {
                        verticalReactionsInset = 2.0
                    }
                    if currentRowWidth + layoutSize.width > arguments.constrainedSize.width {
                        resultingWidth = max(layoutSize.width, reactionButtonsSize.width)
                        resultingHeight = verticalReactionsInset + reactionButtonsSize.height + layoutSize.height
                        verticalInset = verticalReactionsInset + reactionButtonsSize.height
                    } else {
                        resultingWidth = layoutSize.width + currentRowWidth
                        verticalInset = verticalReactionsInset + reactionButtonsSize.height - layoutSize.height
                        resultingHeight = verticalReactionsInset + reactionButtonsSize.height
                    }
                }
            }
            
            return (resultingWidth, { boundingWidth in
                return (CGSize(width: boundingWidth, height: resultingHeight), { animated in
                    if let strongSelf = self {
                        let leftOffset = boundingWidth - layoutSize.width
                        
                        strongSelf.theme = arguments.presentationData.theme
                        strongSelf.type = arguments.type
                        strongSelf.layoutSize = layoutSize
                        
                        var reactionButtonPosition = CGPoint(x: 0.0, y: verticalReactionsInset)
                        for item in reactionButtons.items {
                            if reactionButtonPosition.x + item.size.width > boundingWidth {
                                reactionButtonPosition.x = 0.0
                                reactionButtonPosition.y += item.size.height + 6.0
                            }
                                
                            if item.view.superview == nil {
                                strongSelf.view.addSubview(item.view)
                            }
                            item.view.frame = CGRect(origin: reactionButtonPosition, size: item.size)
                            reactionButtonPosition.x += item.size.width + 6.0
                        }
                        
                        for view in reactionButtons.removedViews {
                            view.removeFromSuperview()
                        }
                        
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
                        
                        strongSelf.dateNode.displaysAsynchronously = !arguments.presentationData.isPreview
                        let _ = dateApply()
                        
                        if let currentImpressionIcon = currentImpressionIcon {
                            currentImpressionIcon.displaysAsynchronously = !arguments.presentationData.isPreview
                            if currentImpressionIcon.image !== impressionImage {
                                currentImpressionIcon.image = impressionImage
                            }
                            if currentImpressionIcon.supernode == nil {
                                strongSelf.impressionIcon = currentImpressionIcon
                                strongSelf.addSubnode(currentImpressionIcon)
                            }
                            currentImpressionIcon.frame = CGRect(origin: CGPoint(x: leftOffset + leftInset + backgroundInsets.left, y: backgroundInsets.top + 1.0 + offset + verticalInset + floor((date.size.height - impressionSize.height) / 2.0)), size: impressionSize)
                        } else if let impressionIcon = strongSelf.impressionIcon {
                            impressionIcon.removeFromSupernode()
                            strongSelf.impressionIcon = nil
                        }
                        
                        strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: leftOffset + leftInset + backgroundInsets.left + impressionWidth, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: date.size)
                        
                        if let clockFrameNode = clockFrameNode {
                            if strongSelf.clockFrameNode == nil {
                                strongSelf.clockFrameNode = clockFrameNode
                                clockFrameNode.image = clockFrameImage
                                strongSelf.addSubnode(clockFrameNode)
                            } else if themeUpdated {
                                clockFrameNode.image = clockFrameImage
                            }
                            clockFrameNode.position = CGPoint(x: leftOffset + backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y + verticalInset)
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
                            clockMinNode.position = CGPoint(x: leftOffset + backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y + verticalInset)
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
                                checkSentNode.frame = checkSentFrame.offsetBy(dx: leftOffset + backgroundInsets.left + reactionInset, dy: backgroundInsets.top + verticalInset)
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
                                checkReadNode.frame = checkReadFrame.offsetBy(dx: leftOffset + backgroundInsets.left + reactionInset, dy: backgroundInsets.top + verticalInset)
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
                        
                        var reactionOffset: CGFloat = leftOffset + leftInset - reactionInset + backgroundInsets.left
                        if !"".isEmpty {
                            for i in 0 ..< arguments.reactions.count {
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
                                
                                node.update(type: arguments.type, value: arguments.reactions[i].value, isSelected: arguments.reactions[i].isSelected, count: Int(arguments.reactions[i].count), theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper, animated: false)
                                if node.supernode == nil {
                                    strongSelf.addSubnode(node)
                                    if animated {
                                        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                    }
                                }
                                node.frame = CGRect(origin: CGPoint(x: reactionOffset, y: backgroundInsets.top + offset + verticalInset + 1.0), size: CGSize(width: reactionSize, height: reactionSize))
                                reactionOffset += reactionSize + reactionSpacing
                            }
                            if !arguments.reactions.isEmpty {
                                reactionOffset += reactionTrailingSpacing
                            }
                        
                            for _ in arguments.reactions.count ..< strongSelf.reactionNodes.count {
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
                            node.frame = CGRect(origin: CGPoint(x: reactionOffset + 1.0, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: layout.size)
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
                            currentRepliesIcon.displaysAsynchronously = !arguments.presentationData.isPreview
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
                            currentRepliesIcon.frame = CGRect(origin: CGPoint(x: reactionOffset - 2.0, y: backgroundInsets.top + offset + verticalInset + floor((date.size.height - repliesIconSize.height) / 2.0)), size: repliesIconSize)
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
                            node.frame = CGRect(origin: CGPoint(x: reactionOffset + 4.0, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: layout.size)
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
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageDateAndStatusNode?) -> (_ arguments: Arguments) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> ChatMessageDateAndStatusNode)) {
        let currentLayout = node?.asyncLayout()
        return { arguments in
            let resultNode: ChatMessageDateAndStatusNode
            let resultSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (Bool) -> Void))
            if let node = node, let currentLayout = currentLayout {
                resultNode = node
                resultSuggestedWidthAndContinue = currentLayout(arguments)
            } else {
                resultNode = ChatMessageDateAndStatusNode()
                resultSuggestedWidthAndContinue = resultNode.asyncLayout()(arguments)
            }
            
            return (resultSuggestedWidthAndContinue.0, { boundingWidth in
                let (size, apply) = resultSuggestedWidthAndContinue.1(boundingWidth)
                return (size, { animated in
                    apply(animated)
                    
                    return resultNode
                })
            })
        }
    }
    
    func reactionView(value: String) -> UIView? {
        for (_, button) in self.reactionButtonsContainer.buttons {
            if let result = button.findTaggedView(tag: ReactionButtonComponent.ViewTag(value: value)) as? ReactionButtonComponent.View {
                return result.iconView
            }
        }
        return nil
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (_, button) in self.reactionButtonsContainer.buttons {
            if button.frame.contains(point) {
                if let result = button.hitTest(self.view.convert(point, to: button), with: event) {
                    return result
                }
            }
        }
        if self.pressed != nil {
            if self.bounds.contains(point) {
                return self.view
            }
        }
        return nil
    }
}
