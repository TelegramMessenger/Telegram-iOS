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
import ReactionImageComponent
import AnimationCache
import MultiAnimationRenderer

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
    let iconView: ReactionIconView
    
    private let iconImageDisposable = MetaDisposable()
    
    private var theme: PresentationTheme?
    private var value: MessageReaction.Reaction?
    private var isSelected: Bool?
    
    private var resolvedFile: TelegramMediaFile?
    private var fileDisposable: Disposable?
    
    override init() {
        self.iconView = ReactionIconView()
        
        super.init()
        
        self.view.addSubview(self.iconView)
    }
    
    deinit {
        self.iconImageDisposable.dispose()
        self.fileDisposable?.dispose()
    }
    
    func update(context: AccountContext, type: ChatMessageDateAndStatusType, value: MessageReaction.Reaction, file: TelegramMediaFile?, fileId: Int64?, isSelected: Bool, count: Int, theme: PresentationTheme, wallpaper: TelegramWallpaper, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, animated: Bool) {
        if self.value != value {
            self.value = value
            
            let boundingImageSize = CGSize(width: 14.0, height: 14.0)
            /*let defaultImageSize = CGSize(width: boundingImageSize.width + floor(boundingImageSize.width * 0.5 * 2.0), height: boundingImageSize.height + floor(boundingImageSize.height * 0.5 * 2.0))
            let imageSize: CGSize
            if let file = file {
                self.iconImageDisposable.set((reactionStaticImage(context: context, animation: file, pixelSize: CGSize(width: 72.0, height: 72.0), queue: sharedReactionStaticImage)
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if data.isComplete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                        if let image = UIImage(data: dataValue) {
                            strongSelf.iconView.imageView.image = image
                        }
                    }
                }))
                imageSize = file.dimensions?.cgSize.aspectFitted(defaultImageSize) ?? defaultImageSize
                
                self.fileDisposable?.dispose()
                self.fileDisposable = nil
            } else if let fileId = fileId {
                self.fileDisposable?.dispose()
                self.fileDisposable = nil
                
                imageSize = boundingImageSize
                
                if let resolvedFile = self.resolvedFile, resolvedFile.fileId.id == fileId {
                } else {
                    self.fileDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let strongSelf = self, let file = result[fileId] else {
                            return
                        }
                        
                        strongSelf.resolvedFile = file
                        
                        strongSelf.iconImageDisposable.set((reactionStaticImage(context: context, animation: file, pixelSize: CGSize(width: 72.0, height: 72.0), queue: sharedReactionStaticImage)
                        |> deliverOnMainQueue).start(next: { data in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if data.isComplete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                if let image = UIImage(data: dataValue) {
                                    strongSelf.iconView.imageView.image = image
                                }
                            }
                        }))
                    })
                }
            } else {
                imageSize = defaultImageSize
                
                self.fileDisposable?.dispose()
                self.fileDisposable = nil
            }*/
            
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingImageSize.width - boundingImageSize.width) / 2.0), y: floorToScreenPixels((boundingImageSize.height - boundingImageSize.height) / 2.0)), size: boundingImageSize)
            self.iconView.frame = iconFrame
            if let fileId = fileId ?? file?.fileId.id {
                let animateIdle: Bool
                if case .custom = value {
                    animateIdle = true
                } else {
                    animateIdle = false
                }
                
                let placeholderColor: UIColor
                switch type {
                case .BubbleIncoming:
                    placeholderColor = theme.chat.message.incoming.mediaPlaceholderColor
                case .BubbleOutgoing:
                    placeholderColor = theme.chat.message.incoming.mediaPlaceholderColor
                case .ImageIncoming:
                    placeholderColor = UIColor(white: 1.0, alpha: 0.1)
                case .ImageOutgoing:
                    placeholderColor = UIColor(white: 1.0, alpha: 0.1)
                case .FreeIncoming:
                    placeholderColor = UIColor(white: 0.0, alpha: 0.1)
                case .FreeOutgoing:
                    placeholderColor = UIColor(white: 0.0, alpha: 0.1)
                }
                
                self.iconView.update(
                    size: boundingImageSize,
                    context: context,
                    file: file,
                    fileId: fileId,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    placeholderColor: placeholderColor,
                    animateIdle: animateIdle,
                    reaction: value,
                    transition: .immediate
                )
            }
        }
    }
}

class ChatMessageDateAndStatusNode: ASDisplayNode {
    struct TrailingReactionSettings {
        var displayInline: Bool
        var preferAdditionalInset: Bool
        
        init(displayInline: Bool, preferAdditionalInset: Bool) {
            self.displayInline = displayInline
            self.preferAdditionalInset = preferAdditionalInset
        }
    }
    
    struct StandaloneReactionSettings {
        init() {
        }
    }
    
    enum LayoutInput {
        case trailingContent(contentWidth: CGFloat, reactionSettings: TrailingReactionSettings?)
        case standalone(reactionSettings: StandaloneReactionSettings?)
        
        var displayInlineReactions: Bool {
            switch self {
            case let .trailingContent(_, reactionSettings):
                if let reactionSettings = reactionSettings {
                    return reactionSettings.displayInline
                } else {
                    return false
                }
            case let .standalone(reactionSettings):
                if let _ = reactionSettings {
                    return true
                } else {
                    return false
                }
            }
        }
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
        var reactionPeers: [(MessageReaction.Reaction, EnginePeer)]
        var displayAllReactionPeers: Bool
        var replyCount: Int
        var isPinned: Bool
        var hasAutoremove: Bool
        var canViewReactionList: Bool
        var animationCache: AnimationCache
        var animationRenderer: MultiAnimationRenderer
        
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
            reactionPeers: [(MessageReaction.Reaction, EnginePeer)],
            displayAllReactionPeers: Bool,
            replyCount: Int,
            isPinned: Bool,
            hasAutoremove: Bool,
            canViewReactionList: Bool,
            animationCache: AnimationCache,
            animationRenderer: MultiAnimationRenderer
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
            self.reactionPeers = reactionPeers
            self.displayAllReactionPeers = displayAllReactionPeers
            self.replyCount = replyCount
            self.isPinned = isPinned
            self.hasAutoremove = hasAutoremove
            self.canViewReactionList = canViewReactionList
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
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
    private var reactionNodes: [MessageReaction.Reaction: StatusReactionNode] = [:]
    private let reactionButtonsContainer = ReactionButtonsAsyncLayoutContainer()
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
    var reactionSelected: ((MessageReaction.Reaction) -> Void)?
    var openReactionPreview: ((ContextGesture?, ContextExtractedContentContainingView, MessageReaction.Reaction) -> Void)?
    
    override init() {
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        self.dateNode.contentsScale = UIScreenScale
        self.dateNode.contentMode = .topLeft
        
        super.init()
        
        self.addSubnode(self.dateNode)
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.pressed?()
        }
    }
    
    func asyncLayout() -> (_ arguments: Arguments) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void)) {
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
                let themeColors = bubbleColorComponents(theme: arguments.presentationData.theme.theme, incoming: true, wallpaper: !arguments.presentationData.theme.wallpaper.isEmpty)
                
                reactionColors = ReactionButtonComponent.Colors(
                    deselectedBackground: themeColors.reactionInactiveBackground.argb,
                    selectedBackground: themeColors.reactionActiveBackground.argb,
                    deselectedForeground: themeColors.reactionInactiveForeground.argb,
                    selectedForeground: themeColors.reactionActiveForeground.argb,
                    extractedBackground: arguments.presentationData.theme.theme.contextMenu.backgroundColor.argb,
                    extractedForeground: arguments.presentationData.theme.theme.contextMenu.primaryColor.argb,
                    deselectedMediaPlaceholder: themeColors.reactionInactiveMediaPlaceholder.argb,
                    selectedMediaPlaceholder: themeColors.reactionActiveMediaPlaceholder.argb
                )
            case .BubbleOutgoing, .ImageOutgoing, .FreeOutgoing:
                let themeColors = bubbleColorComponents(theme: arguments.presentationData.theme.theme, incoming: false, wallpaper: !arguments.presentationData.theme.wallpaper.isEmpty)
                
                reactionColors = ReactionButtonComponent.Colors(
                    deselectedBackground: themeColors.reactionInactiveBackground.argb,
                    selectedBackground: themeColors.reactionActiveBackground.argb,
                    deselectedForeground: themeColors.reactionInactiveForeground.argb,
                    selectedForeground: themeColors.reactionActiveForeground.argb,
                    extractedBackground: arguments.presentationData.theme.theme.contextMenu.backgroundColor.argb,
                    extractedForeground:  arguments.presentationData.theme.theme.contextMenu.primaryColor.argb,
                    deselectedMediaPlaceholder: themeColors.reactionInactiveMediaPlaceholder.argb,
                    selectedMediaPlaceholder: themeColors.reactionActiveMediaPlaceholder.argb
                )
            }
            
            switch arguments.type {
            case .BubbleIncoming:
                dateColor = arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor
                leftInset = 5.0
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
                leftInset = 5.0
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
            
            let reactionSize: CGFloat = 17.0
            var reactionCountLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let reactionSpacing: CGFloat = 2.0
            let reactionTrailingSpacing: CGFloat = 6.0

            var reactionInset: CGFloat = 0.0
            if arguments.layoutInput.displayInlineReactions, !arguments.reactions.isEmpty {
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
                
                if count > arguments.reactions.count {
                    let layoutAndApply = makeReactionCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: countString, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
                    reactionInset += layoutAndApply.0.size.width + 4.0
                    reactionCountLayoutAndApply = layoutAndApply
                }
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
            
            let reactionButtonsResult: ReactionButtonsAsyncLayoutContainer.Result
            switch arguments.layoutInput {
            case .standalone:
                verticalReactionsInset = 0.0
                verticalInset = 0.0
                resultingWidth = layoutSize.width
                resultingHeight = layoutSize.height
                reactionButtonsResult = reactionButtonsContainer.update(
                    context: arguments.context,
                    action: { value in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reactionSelected?(value)
                    },
                    reactions: [],
                    colors: reactionColors,
                    constrainedWidth: arguments.constrainedSize.width
                )
            case let .trailingContent(contentWidth, reactionSettings):
                if let reactionSettings = reactionSettings, !reactionSettings.displayInline {
                    var totalReactionCount: Int = 0
                    for reaction in arguments.reactions {
                        totalReactionCount += Int(reaction.count)
                    }
                    
                    reactionButtonsResult = reactionButtonsContainer.update(
                        context: arguments.context,
                        action: { value in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.reactionSelected?(value)
                        },
                        reactions: arguments.reactions.map { reaction in
                            var centerAnimation: TelegramMediaFile?
                            var animationFileId: Int64?
                            
                            switch reaction.value {
                            case .builtin:
                                if let availableReactions = arguments.availableReactions {
                                    for availableReaction in availableReactions.reactions {
                                        if availableReaction.value == reaction.value {
                                            centerAnimation = availableReaction.centerAnimation
                                            break
                                        }
                                    }
                                }
                            case let .custom(fileId):
                                animationFileId = fileId
                            }
                            
                            var peers: [EnginePeer] = []
                            for (value, peer) in arguments.reactionPeers {
                                if value == reaction.value {
                                    if !peers.contains(where: { $0.id == peer.id }) {
                                        peers.append(peer)
                                    }
                                }
                            }
                            if !arguments.displayAllReactionPeers {
                                if peers.count != Int(reaction.count) || arguments.reactionPeers.count != totalReactionCount {
                                    peers.removeAll()
                                }
                            }
                            
                            return ReactionButtonsAsyncLayoutContainer.Reaction(
                                reaction: ReactionButtonComponent.Reaction(
                                    value: reaction.value,
                                    centerAnimation: centerAnimation,
                                    animationFileId: animationFileId
                                ),
                                count: Int(reaction.count),
                                peers: peers,
                                chosenOrder: reaction.chosenOrder
                            )
                        },
                        colors: reactionColors,
                        constrainedWidth: arguments.constrainedSize.width
                    )
                } else {
                    reactionButtonsResult = reactionButtonsContainer.update(
                        context: arguments.context,
                        action: { value in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.reactionSelected?(value)
                        },
                        reactions: [],
                        colors: reactionColors,
                        constrainedWidth: arguments.constrainedSize.width
                    )
                }
                
                var reactionButtonsSize = CGSize()
                var currentRowWidth: CGFloat = 0.0
                for item in reactionButtonsResult.items {
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
                if !currentRowWidth.isZero && !reactionButtonsResult.items.isEmpty {
                    reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
                    if !reactionButtonsSize.height.isZero {
                        reactionButtonsSize.height += 6.0
                    }
                    reactionButtonsSize.height += reactionButtonsResult.items[0].size.height
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
                    var additionalVerticalInset: CGFloat = 0.0
                    if let reactionSettings = reactionSettings {
                        if reactionSettings.preferAdditionalInset {
                            verticalReactionsInset = 8.0
                            additionalVerticalInset += 1.0
                        } else {
                            verticalReactionsInset = 3.0
                        }
                    } else {
                        verticalReactionsInset = 0.0
                    }
                    
                    if currentRowWidth + layoutSize.width > arguments.constrainedSize.width {
                        resultingWidth = max(layoutSize.width, reactionButtonsSize.width)
                        resultingHeight = verticalReactionsInset + reactionButtonsSize.height + 1.0 + layoutSize.height
                        verticalInset = verticalReactionsInset + reactionButtonsSize.height + 3.0
                    } else {
                        resultingWidth = max(layoutSize.width + currentRowWidth, reactionButtonsSize.width)
                        verticalInset = verticalReactionsInset + reactionButtonsSize.height - layoutSize.height + additionalVerticalInset
                        resultingHeight = verticalReactionsInset + reactionButtonsSize.height + 1.0
                    }
                }
            }
            
            return (resultingWidth, { boundingWidth in
                return (CGSize(width: boundingWidth, height: resultingHeight), { animation in
                    if let strongSelf = self {
                        let leftOffset = boundingWidth - layoutSize.width
                        
                        strongSelf.theme = arguments.presentationData.theme
                        strongSelf.type = arguments.type
                        strongSelf.layoutSize = layoutSize
                        
                        let reactionButtons = reactionButtonsResult.apply(
                            animation,
                            ReactionButtonsAsyncLayoutContainer.Arguments(
                                animationCache: arguments.animationCache,
                                animationRenderer: arguments.animationRenderer
                            )
                        )
                        
                        var reactionButtonPosition = CGPoint(x: -1.0, y: verticalReactionsInset)
                        for item in reactionButtons.items {
                            if reactionButtonPosition.x + item.size.width > boundingWidth {
                                reactionButtonPosition.x = -1.0
                                reactionButtonPosition.y += item.size.height + 6.0
                            }
                                
                            if item.node.view.superview != strongSelf.view {
                                assert(item.node.view.superview == nil)
                                strongSelf.view.addSubview(item.node.view)
                                item.node.view.frame = CGRect(origin: reactionButtonPosition, size: item.size)
                                
                                if animation.isAnimated {
                                    item.node.view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                                    item.node.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                }
                            } else {
                                animation.animator.updateFrame(layer: item.node.view.layer, frame: CGRect(origin: reactionButtonPosition, size: item.size), completion: nil)
                            }
                            
                            let itemValue = item.value
                            let itemNode = item.node
                            item.node.view.isGestureEnabled = true
                            let canViewReactionList = arguments.canViewReactionList
                            item.node.view.activateAfterCompletion = !canViewReactionList
                            item.node.view.activated = { [weak itemNode] gesture, _ in
                                guard let strongSelf = self, canViewReactionList else {
                                    return
                                }
                                guard let itemNode = itemNode else {
                                    return
                                }
                                
                                if let openReactionPreview = strongSelf.openReactionPreview {
                                    openReactionPreview(gesture, itemNode.view.containerView, itemValue)
                                } else {
                                    gesture.cancel()
                                }
                            }
                            
                            reactionButtonPosition.x += item.size.width + 6.0
                        }
                        
                        for node in reactionButtons.removedNodes {
                            if animation.isAnimated {
                                node.view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                                node.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                    node.view.removeFromSuperview()
                                })
                            } else {
                                node.view.removeFromSuperview()
                            }
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
                                animation.animator.updateFrame(layer: backgroundNode.layer, frame: CGRect(origin: CGPoint(), size: layoutSize), completion: nil)
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
                                animation.animator.updateFrame(layer: blurredBackgroundNode.layer, frame: CGRect(origin: CGPoint(), size: layoutSize), completion: nil)
                                blurredBackgroundNode.update(size: blurredBackgroundNode.bounds.size, cornerRadius: blurredBackgroundNode.bounds.height / 2.0, animator: animation.animator)
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
                        
                        let _ = dateApply()
                        
                        if let currentImpressionIcon = currentImpressionIcon {
                            let impressionIconFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset + backgroundInsets.left, y: backgroundInsets.top + 1.0 + offset + verticalInset + floor((date.size.height - impressionSize.height) / 2.0)), size: impressionSize)
                            currentImpressionIcon.displaysAsynchronously = false
                            if currentImpressionIcon.image !== impressionImage {
                                currentImpressionIcon.image = impressionImage
                            }
                            if currentImpressionIcon.supernode == nil {
                                strongSelf.impressionIcon = currentImpressionIcon
                                strongSelf.addSubnode(currentImpressionIcon)
                                currentImpressionIcon.frame = impressionIconFrame
                            } else {
                                animation.animator.updateFrame(layer: currentImpressionIcon.layer, frame: impressionIconFrame, completion: nil)
                            }
                        } else if let impressionIcon = strongSelf.impressionIcon {
                            impressionIcon.removeFromSupernode()
                            strongSelf.impressionIcon = nil
                        }
                        
                        animation.animator.updateFrame(layer: strongSelf.dateNode.layer, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset + backgroundInsets.left + impressionWidth, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: date.size), completion: nil)
                        
                        if let clockFrameNode = clockFrameNode {
                            let clockPosition = CGPoint(x: leftOffset + backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y + verticalInset)
                            if strongSelf.clockFrameNode == nil {
                                strongSelf.clockFrameNode = clockFrameNode
                                clockFrameNode.image = clockFrameImage
                                strongSelf.addSubnode(clockFrameNode)
                                
                                clockFrameNode.position = clockPosition
                            } else {
                                if themeUpdated {
                                    clockFrameNode.image = clockFrameImage
                                }
                                animation.animator.updatePosition(layer: clockFrameNode.layer, position: clockPosition, completion: nil)
                            }
                            if let clockFrameNode = strongSelf.clockFrameNode {
                                maybeAddRotationAnimation(clockFrameNode.layer, duration: 6.0)
                            }
                        } else if let clockFrameNode = strongSelf.clockFrameNode {
                            clockFrameNode.removeFromSupernode()
                            strongSelf.clockFrameNode = nil
                        }
                        
                        if let clockMinNode = clockMinNode {
                            let clockMinPosition = CGPoint(x: leftOffset + backgroundInsets.left + clockPosition.x + reactionInset, y: backgroundInsets.top + clockPosition.y + verticalInset)
                            if strongSelf.clockMinNode == nil {
                                strongSelf.clockMinNode = clockMinNode
                                clockMinNode.image = clockMinImage
                                strongSelf.addSubnode(clockMinNode)
                                
                                clockMinNode.position = clockMinPosition
                            } else {
                                if themeUpdated {
                                    clockMinNode.image = clockMinImage
                                }
                                animation.animator.updatePosition(layer: clockMinNode.layer, position: clockMinPosition, completion: nil)
                            }
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
                                animateSentNode = animation.isAnimated
                            } else if themeUpdated {
                                checkSentNode.image = loadedCheckFullImage
                            }
                            
                            if let checkSentFrame = checkSentFrame {
                                let actualCheckSentFrame = checkSentFrame.offsetBy(dx: leftOffset + backgroundInsets.left + reactionInset, dy: backgroundInsets.top + verticalInset)
                                
                                if checkSentNode.isHidden {
                                    animateSentNode = animation.isAnimated
                                    checkSentNode.isHidden = false
                                    checkSentNode.frame = actualCheckSentFrame
                                } else {
                                    animation.animator.updateFrame(layer: checkSentNode.layer, frame: actualCheckSentFrame, completion: nil)
                                }
                            } else {
                                checkSentNode.isHidden = true
                            }
                            
                            var animateReadNode = false
                            if strongSelf.checkReadNode == nil {
                                animateReadNode = animation.isAnimated
                                checkReadNode.image = loadedCheckPartialImage
                                strongSelf.checkReadNode = checkReadNode
                                strongSelf.addSubnode(checkReadNode)
                            } else if themeUpdated {
                                checkReadNode.image = loadedCheckPartialImage
                            }
                        
                            if let checkReadFrame = checkReadFrame {
                                if checkReadNode.isHidden {
                                    animateReadNode = animation.isAnimated
                                    checkReadNode.frame = checkReadFrame.offsetBy(dx: leftOffset + backgroundInsets.left + reactionInset, dy: backgroundInsets.top + verticalInset)
                                } else {
                                    animation.animator.updateFrame(layer: checkReadNode.layer, frame: checkReadFrame.offsetBy(dx: leftOffset + backgroundInsets.left + reactionInset, dy: backgroundInsets.top + verticalInset), completion: nil)
                                }
                                checkReadNode.isHidden = false
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
                        if arguments.layoutInput.displayInlineReactions {
                            var validReactions = Set<MessageReaction.Reaction>()
                            for reaction in arguments.reactions.sorted(by: { lhs, rhs in
                                if lhs.isSelected != rhs.isSelected {
                                    if lhs.isSelected {
                                        return true
                                    } else {
                                        return false
                                    }
                                } else {
                                    if let lhsIndex = lhs.chosenOrder, let rhsIndex = rhs.chosenOrder {
                                        return lhsIndex < rhsIndex
                                    } else {
                                        return lhs.count > rhs.count
                                    }
                                }
                            }) {
                                let node: StatusReactionNode
                                var animateNode = true
                                if let current = strongSelf.reactionNodes[reaction.value] {
                                    node = current
                                } else {
                                    animateNode = false
                                    node = StatusReactionNode()
                                    strongSelf.reactionNodes[reaction.value] = node
                                }
                                validReactions.insert(reaction.value)
                                
                                var centerAnimation: TelegramMediaFile?
                                var reactionFileId: Int64?
                                
                                switch reaction.value {
                                case .builtin:
                                    if let availableReactions = arguments.availableReactions {
                                        for availableReaction in availableReactions.reactions {
                                            if availableReaction.value == reaction.value {
                                                centerAnimation = availableReaction.centerAnimation
                                                break
                                            }
                                        }
                                    }
                                case let .custom(fileId):
                                    reactionFileId = fileId
                                }
                                
                                node.update(
                                    context: arguments.context,
                                    type: arguments.type,
                                    value: reaction.value,
                                    file: centerAnimation,
                                    fileId: reactionFileId,
                                    isSelected: reaction.isSelected,
                                    count: Int(reaction.count),
                                    theme: arguments.presentationData.theme.theme,
                                    wallpaper: arguments.presentationData.theme.wallpaper,
                                    animationCache: arguments.animationCache,
                                    animationRenderer: arguments.animationRenderer,
                                    animated: false
                                )
                                if node.supernode == nil {
                                    strongSelf.addSubnode(node)
                                    if animation.isAnimated {
                                        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                    }
                                }
                                let nodeFrame = CGRect(origin: CGPoint(x: reactionOffset, y: backgroundInsets.top + offset + verticalInset), size: CGSize(width: reactionSize, height: reactionSize))
                                if animateNode {
                                    animation.animator.updateFrame(layer: node.layer, frame: nodeFrame, completion: nil)
                                } else {
                                    node.frame = nodeFrame
                                }
                                reactionOffset += reactionSize + reactionSpacing
                            }
                            if !arguments.reactions.isEmpty {
                                reactionOffset += reactionTrailingSpacing
                            }
                            
                            var removeIds: [MessageReaction.Reaction] = []
                            for (id, node) in strongSelf.reactionNodes {
                                if !validReactions.contains(id) {
                                    removeIds.append(id)
                                    if animation.isAnimated {
                                        node.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                                        node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak node] _ in
                                            node?.layer.removeAllAnimations()
                                            node?.removeFromSupernode()
                                        })
                                    } else {
                                        node.removeFromSupernode()
                                    }
                                }
                            }
                            for id in removeIds {
                                strongSelf.reactionNodes.removeValue(forKey: id)
                            }
                        } else {
                            var removeIds: [MessageReaction.Reaction] = []
                            for (id, node) in strongSelf.reactionNodes {
                                removeIds.append(id)
                                if animation.isAnimated {
                                    node.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                                    node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak node] _ in
                                        node?.layer.removeAllAnimations()
                                        node?.removeFromSupernode()
                                    })
                                } else {
                                    node.removeFromSupernode()
                                }
                            }
                            for id in removeIds {
                                strongSelf.reactionNodes.removeValue(forKey: id)
                            }
                        }
                        
                        if let (layout, apply) = reactionCountLayoutAndApply {
                            let node = apply()
                            if strongSelf.reactionCountNode !== node {
                                strongSelf.reactionCountNode?.removeFromSupernode()
                                strongSelf.addSubnode(node)
                                strongSelf.reactionCountNode = node
                                if animation.isAnimated {
                                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                }
                            }
                            let nodeFrame = CGRect(origin: CGPoint(x: reactionOffset - 4.0, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: layout.size)
                            animation.animator.updateFrame(layer: node.layer, frame: nodeFrame, completion: nil)
                            reactionOffset += 1.0 + layout.size.width + 4.0
                        } else if let reactionCountNode = strongSelf.reactionCountNode {
                            strongSelf.reactionCountNode = nil
                            if animation.isAnimated {
                                reactionCountNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionCountNode] _ in
                                    reactionCountNode?.removeFromSupernode()
                                })
                            } else {
                                reactionCountNode.removeFromSupernode()
                            }
                        }
                        
                        if let currentRepliesIcon = currentRepliesIcon {
                            currentRepliesIcon.displaysAsynchronously = false
                            if currentRepliesIcon.image !== repliesImage {
                                currentRepliesIcon.image = repliesImage
                            }
                            if currentRepliesIcon.supernode == nil {
                                strongSelf.repliesIcon = currentRepliesIcon
                                strongSelf.addSubnode(currentRepliesIcon)
                                if animation.isAnimated {
                                    currentRepliesIcon.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                }
                            }
                            let repliesIconFrame = CGRect(origin: CGPoint(x: reactionOffset - 2.0, y: backgroundInsets.top + offset + verticalInset + floor((date.size.height - repliesIconSize.height) / 2.0)), size: repliesIconSize)
                            animation.animator.updateFrame(layer: currentRepliesIcon.layer, frame: repliesIconFrame, completion: nil)
                            reactionOffset += 9.0
                        } else if let repliesIcon = strongSelf.repliesIcon {
                            strongSelf.repliesIcon = nil
                            if animation.isAnimated {
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
                                if animation.isAnimated {
                                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                }
                            }
                            let replyCountFrame = CGRect(origin: CGPoint(x: reactionOffset + 4.0, y: backgroundInsets.top + 1.0 + offset + verticalInset), size: layout.size)
                            animation.animator.updateFrame(layer: node.layer, frame: replyCountFrame, completion: nil)
                            reactionOffset += 4.0 + layout.size.width
                        } else if let replyCountNode = strongSelf.replyCountNode {
                            strongSelf.replyCountNode = nil
                            if animation.isAnimated {
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
    
    static func asyncLayout(_ node: ChatMessageDateAndStatusNode?) -> (_ arguments: Arguments) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode)) {
        let currentLayout = node?.asyncLayout()
        return { arguments in
            let resultNode: ChatMessageDateAndStatusNode
            let resultSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))
            if let node = node, let currentLayout = currentLayout {
                resultNode = node
                resultSuggestedWidthAndContinue = currentLayout(arguments)
            } else {
                resultNode = ChatMessageDateAndStatusNode()
                resultSuggestedWidthAndContinue = resultNode.asyncLayout()(arguments)
            }
            
            return (resultSuggestedWidthAndContinue.0, { boundingWidth in
                let (size, apply) = resultSuggestedWidthAndContinue.1(boundingWidth)
                return (size, { animation in
                    apply(animation)
                    
                    return resultNode
                })
            })
        }
    }
    
    func reactionView(value: MessageReaction.Reaction) -> UIView? {
        for (id, node) in self.reactionNodes {
            if id == value {
                return node.iconView
            }
        }
        for (key, button) in self.reactionButtonsContainer.buttons {
            if key == value {
                return button.view.iconView
            }
        }
        return nil
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (_, button) in self.reactionButtonsContainer.buttons {
            if button.view.frame.contains(point) {
                if let result = button.view.hitTest(self.view.convert(point, to: button.view), with: event) {
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

func shouldDisplayInlineDateReactions(message: Message, isPremium: Bool, forceInline: Bool) -> Bool {
    if forceInline {
        return true
    }
    
    if message.id.peerId.namespace == Namespaces.Peer.CloudUser || message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        if let chatPeer = message.peers[message.id.peerId] as? TelegramUser, chatPeer.isPremium {
            return false
        }
        if let author = message.author as? TelegramUser, author.isPremium {
            return false
        }
        if isPremium {
            return false
        }
        
        if let effectiveReactions = message.effectiveReactions {
            if effectiveReactions.count > 1 {
                return false
            }
            for reaction in effectiveReactions {
                if case .custom = reaction.value {
                    return false
                }
            }
        }
        
        return true
    }
    return false
}
