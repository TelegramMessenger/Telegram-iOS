import Foundation
import UIKit
import CoreText
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import PhotoResources
import MultilineTextComponent
import PlainButtonComponent
import ReactionButtonListComponent
import AnimatedAvatarSetNode
import ChatMessageItemView
import NewsFeedSupport

/// What an expanded post row needs beyond the compact one: the chat's presentation (the bubble follows it), the
/// account's reactions, and where the content's taps go. The closures are the screen's; only the values take part
/// in the component's equality.
public final class NewsFeedPostExpandedContent {
    public let presentationData: PresentationData
    public let availableReactions: AvailableReactions?
    public let accountPeer: EnginePeer?
    /// Show more was tapped: the whole text, with its formatting and links.
    public let isTextExpanded: Bool
    public let toggleTextExpanded: () -> Void
    public let openUrl: (String) -> Void
    /// A photo or video of the gallery, or media the bubble shows.
    public let openMedia: (EngineMessage, EngineMedia?) -> Bool
    public let openPeer: (EnginePeer) -> Void
    public let openInstantPage: (EngineMessage) -> Void
    public let openComments: () -> Void
    public let toggleReaction: (MessageReaction.Reaction) -> Void

    public init(presentationData: PresentationData, availableReactions: AvailableReactions?, accountPeer: EnginePeer?, isTextExpanded: Bool, toggleTextExpanded: @escaping () -> Void, openUrl: @escaping (String) -> Void, openMedia: @escaping (EngineMessage, EngineMedia?) -> Bool, openPeer: @escaping (EnginePeer) -> Void, openInstantPage: @escaping (EngineMessage) -> Void, openComments: @escaping () -> Void, toggleReaction: @escaping (MessageReaction.Reaction) -> Void) {
        self.presentationData = presentationData
        self.availableReactions = availableReactions
        self.accountPeer = accountPeer
        self.isTextExpanded = isTextExpanded
        self.toggleTextExpanded = toggleTextExpanded
        self.openUrl = openUrl
        self.openMedia = openMedia
        self.openPeer = openPeer
        self.openInstantPage = openInstantPage
        self.openComments = openComments
        self.toggleReaction = toggleReaction
    }

    static func isEqual(_ lhs: NewsFeedPostExpandedContent?, _ rhs: NewsFeedPostExpandedContent?) -> Bool {
        guard let lhs, let rhs else {
            return (lhs == nil) == (rhs == nil)
        }
        if lhs.presentationData.theme !== rhs.presentationData.theme {
            return false
        }
        if lhs.presentationData.chatFontSize != rhs.presentationData.chatFontSize || lhs.presentationData.chatBubbleCorners != rhs.presentationData.chatBubbleCorners || lhs.presentationData.chatWallpaper != rhs.presentationData.chatWallpaper {
            return false
        }
        if lhs.availableReactions != rhs.availableReactions {
            return false
        }
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.isTextExpanded != rhs.isTextExpanded {
            return false
        }
        return true
    }
}

/// A photo or video of the post, for the gallery.
private struct NewsGalleryMedia {
    let message: EngineMessage
    let media: EngineMedia
    let dimensions: CGSize
    let videoDuration: Double?

    var id: EngineMedia.Id? {
        switch self.media {
        case let .image(image):
            return image.imageId
        case let .file(file):
            return file.fileId
        default:
            return nil
        }
    }
}

/// The post split for the expanded row: photos and videos go to the gallery, everything else (text, link preview,
/// files, polls) stays in the bubble. A message with nothing left for the bubble is left out of it.
private func newsExpandedPostParts(messages: [EngineMessage]) -> (bubble: [EngineMessage], gallery: [NewsGalleryMedia]) {
    var bubble: [EngineMessage] = []
    var gallery: [NewsGalleryMedia] = []
    for message in messages {
        var kept: [EngineMedia] = []
        for media in message.engineMedia {
            switch media {
            case let .image(image):
                let dimensions = largestImageRepresentation(image.representations)?.dimensions.cgSize ?? CGSize(width: 1.0, height: 1.0)
                gallery.append(NewsGalleryMedia(message: message, media: media, dimensions: dimensions, videoDuration: nil))
            case let .file(file) where file.isVideo:
                var duration: Double?
                if !file.isAnimated, let value = file.duration, value > 0.0 {
                    duration = value
                }
                gallery.append(NewsGalleryMedia(message: message, media: media, dimensions: file.dimensions?.cgSize ?? CGSize(width: 1.0, height: 1.0), videoDuration: duration))
            default:
                kept.append(media)
            }
        }
        if kept.count == message.engineMedia.count {
            bubble.append(message)
        } else if !message.text.isEmpty || !kept.isEmpty {
            bubble.append(EngineMessage(message._asMessage().withUpdatedMedia(kept.map { $0._asMedia() })))
        }
    }
    return (bubble, gallery)
}

/// The bubble shows the content only: the row draws the reactions and comments itself, in one line.
private func newsBubbleMessage(_ message: EngineMessage, collapsedText: String?) -> EngineMessage {
    var attributes = message.attributes.filter { attribute in
        if attribute is ReactionsMessageAttribute || attribute is ReplyThreadMessageAttribute {
            return false
        }
        return true
    }
    var result = message._asMessage()
    if let collapsedText {
        // The first lines only, as plain text: formatting and links come with Show more.
        attributes = attributes.filter { !($0 is TextEntitiesMessageAttribute) }
        result = result.withUpdatedText(collapsedText)
    }
    return EngineMessage(result.withUpdatedAttributes(attributes))
}

/// The text kept while the post is collapsed (its first lines, cut where the bubble would break them), or nil when
/// the whole text fits the limit.
private func newsCollapsedText(_ text: String, font: UIFont, width: CGFloat) -> String? {
    let (layout, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: font, textColor: .black), maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width, height: .greatestFiniteMagnitude)))
    guard layout.numberOfLines > NewsExpandedPostMetrics.collapsedLineLimit else {
        return nil
    }
    var ranges: [NSRange] = []
    layout.enumerateRenderedLines(in: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height + 10000.0))) { line, _ in
        let range = CTLineGetStringRange(line)
        ranges.append(NSRange(location: range.location, length: range.length))
    }
    guard let range = newsCollapsedTextRange(lineRanges: ranges) else {
        return nil
    }
    let nsText = text as NSString
    let prefix = nsText.substring(with: NSRange(location: 0, length: min(range.length, nsText.length))).trimmingCharacters(in: .whitespacesAndNewlines)
    return prefix + "…"
}

/// The reaction pills' colours: the incoming bubble's, as the chat draws them under a channel post.
private func newsReactionColors(theme: PresentationTheme) -> ReactionButtonComponent.Colors {
    let themeColors = bubbleColorComponents(theme: theme, incoming: true, wallpaper: false)
    return ReactionButtonComponent.Colors(
        deselectedBackground: themeColors.reactionInactiveBackground.argb,
        selectedBackground: themeColors.reactionActiveBackground.argb,
        deselectedForeground: themeColors.reactionInactiveForeground.argb,
        selectedForeground: themeColors.reactionActiveForeground.argb,
        selectedIconTintColor: 0,
        deselectedStarsBackground: themeColors.reactionStarsInactiveBackground.argb,
        selectedStarsBackground: themeColors.reactionStarsActiveBackground.argb,
        deselectedStarsForeground: themeColors.reactionStarsInactiveForeground.argb,
        selectedStarsForeground: themeColors.reactionStarsActiveForeground.argb,
        extractedBackground: theme.contextMenu.backgroundColor.argb,
        extractedForeground: theme.contextMenu.primaryColor.argb,
        extractedSelectedForeground: theme.overallDarkAppearance ? themeColors.reactionActiveForeground.argb : theme.list.itemCheckColors.foregroundColor.argb,
        deselectedMediaPlaceholder: themeColors.reactionInactiveMediaPlaceholder.argb,
        selectedMediaPlaceholder: themeColors.reactionActiveMediaPlaceholder.argb,
        isDark: theme.overallDarkAppearance
    )
}

/// The comments pill: the latest commenters, a bubble, the count and a chevron, in the reaction pills' colours.
private final class NewsCommentsPillView: UIView {
    private let avatarsContext = AnimatedAvatarSetContext()
    private let avatarsNode = AnimatedAvatarSetNode()
    private let iconView = UIImageView()
    private let countLabel = UILabel()
    private let chevronView = UIImageView()
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = NewsExpandedPostMetrics.reactionsHeight * 0.5
        self.clipsToBounds = true
        self.avatarsNode.isUserInteractionEnabled = false
        self.addSubview(self.avatarsNode.view)
        self.iconView.contentMode = .center
        self.addSubview(self.iconView)
        self.countLabel.font = Font.medium(11.0)
        self.addSubview(self.countLabel)
        self.chevronView.contentMode = .center
        self.addSubview(self.chevronView)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func tapped() {
        self.action?()
    }

    func update(context: AccountContext, peers: [EnginePeer], count: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, backgroundColor: UIColor, foregroundColor: UIColor, synchronousLoad: Bool) -> CGSize {
        self.backgroundColor = backgroundColor
        let height = NewsExpandedPostMetrics.reactionsHeight
        var x: CGFloat = 5.0
        let avatarsSize = self.avatarsNode.update(context: context, content: self.avatarsContext.update(peers: Array(peers.prefix(3)), animated: false), itemSize: CGSize(width: 20.0, height: 20.0), animated: false, synchronousLoad: synchronousLoad)
        if avatarsSize.width > 0.0 {
            self.avatarsNode.frame = CGRect(origin: CGPoint(x: x, y: floor((height - avatarsSize.height) * 0.5)), size: avatarsSize)
            self.avatarsNode.isHidden = false
            x += avatarsSize.width + 2.0
        } else {
            self.avatarsNode.isHidden = true
            x = 9.0
        }
        self.iconView.image = UIImage(systemName: "bubble.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14.0, weight: .medium))?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal)
        let iconSize = self.iconView.image?.size ?? CGSize(width: 18.0, height: 18.0)
        self.iconView.frame = CGRect(origin: CGPoint(x: x, y: floor((height - iconSize.height) * 0.5)), size: iconSize)
        x += iconSize.width + 3.0
        self.countLabel.textColor = foregroundColor
        self.countLabel.text = count > 0 ? compactNumericCountString(Int(count), decimalSeparator: dateTimeFormat.decimalSeparator) : strings.News_Comments
        let countSize = self.countLabel.sizeThatFits(CGSize(width: 200.0, height: height))
        self.countLabel.frame = CGRect(origin: CGPoint(x: x, y: floor((height - countSize.height) * 0.5)), size: countSize)
        x += countSize.width + 3.0
        self.chevronView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 9.0, weight: .semibold))?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal)
        let chevronSize = self.chevronView.image?.size ?? CGSize(width: 7.0, height: 11.0)
        self.chevronView.frame = CGRect(origin: CGPoint(x: x, y: floor((height - chevronSize.height) * 0.5)), size: chevronSize)
        x += chevronSize.width + 9.0
        return CGSize(width: x, height: height)
    }
}

/// One gallery item: the photo or video's thumbnail with continuous corners, and "▶ 0:12" on a video.
private final class NewsGalleryItemView: UIView {
    let imageView = TransformImageView()
    private let durationLabel = UILabel()
    private(set) var mediaId: EngineMedia.Id?
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageView.layer.cornerRadius = NewsExpandedPostMetrics.galleryCornerRadius
        self.imageView.layer.cornerCurve = .continuous
        self.imageView.clipsToBounds = true
        self.addSubview(self.imageView)
        self.durationLabel.isHidden = true
        self.addSubview(self.durationLabel)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func tapped() {
        self.action?()
    }

    func update(context: AccountContext, item: NewsGalleryMedia, size: CGSize) {
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        if self.mediaId != item.id {
            self.mediaId = item.id
            switch item.media {
            case let .image(image):
                self.imageView.setSignal(mediaGridMessagePhoto(account: context.account, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 600.0, height: 600.0)), attemptSynchronously: false)
            case let .file(file):
                self.imageView.setSignal(chatMessageVideoThumbnail(account: context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message._asMessage()), media: file)), attemptSynchronously: false)
            default:
                break
            }
        }
        let apply = self.imageView.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: item.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()
        if let duration = item.videoDuration {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor(white: 0.0, alpha: 0.35)
            shadow.shadowBlurRadius = 3.0
            shadow.shadowOffset = CGSize()
            let string = NSMutableAttributedString()
            if let playImage = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(font: Font.semibold(11.0)))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let attachment = NSTextAttachment()
                attachment.image = playImage
                string.append(NSAttributedString(attachment: attachment))
                string.append(NSAttributedString(string: " "))
            }
            string.append(NSAttributedString(string: stringForDuration(Int32(duration)), font: Font.semibold(11.0), textColor: .white))
            string.addAttribute(.shadow, value: shadow, range: NSRange(location: 0, length: string.length))
            self.durationLabel.attributedText = string
            let labelSize = self.durationLabel.sizeThatFits(CGSize(width: size.width, height: 100.0))
            self.durationLabel.frame = CGRect(x: 8.0, y: size.height - 8.0 - labelSize.height, width: labelSize.width, height: labelSize.height)
            self.durationLabel.isHidden = false
        } else {
            self.durationLabel.isHidden = true
        }
    }
}

/// A horizontal strip (the gallery, the reactions) that starts at the content column and passes under the avatar's
/// column when scrolled. Its scrolling is its own: the list's vertical pan and the screen's page swipe yield to it.
private final class NewsHorizontalStripView: UIScrollView {
    var scrolled: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.alwaysBounceVertical = false
        self.contentInsetAdjustmentBehavior = .never
        self.delaysContentTouches = false
        self.canCancelContentTouches = true
        self.panGestureRecognizer.addTarget(self, action: #selector(self.panned))
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// How far the content has moved from its resting position.
    var scrolledDistance: CGFloat {
        return self.contentOffset.x + self.contentInset.left
    }

    @objc private func panned() {
        self.scrolled?(self.scrolledDistance)
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}

/// The expanded row's content under the channel line: the views and time, the bubble's content, Show more, the
/// gallery and the reactions line. The row owns the avatar, the channel name, its badge and the time view, and places
/// them where this view says.
final class NewsExpandedPostContentView: UIView {
    struct Layout {
        let height: CGFloat
        /// The time's frame, in the row's coordinates.
        let timeFrame: CGRect
        /// How much of the channel line the views, time and chevron take, from the right edge.
        let metaWidth: CGFloat
    }

    private let viewsIconView = UIImageView()
    private let viewsLabel = UILabel()
    private let chevronView = UIImageView()
    private let bubbleContainerNode = ASDisplayNode()
    private var bubbleItemNode: ListViewItemNode?
    private let showMoreView = ComponentView<Empty>()
    private let galleryView = NewsHorizontalStripView()
    private var galleryItemViews: [NewsGalleryItemView] = []
    private let reactionsView = NewsHorizontalStripView()
    private let reactionsContainer = ReactionButtonsAsyncLayoutContainer()
    private var commentsPillView: NewsCommentsPillView?

    /// The avatar's horizontal offset for the gallery's scrolling (`newsExpandedAvatarOffset`).
    var avatarOffsetChanged: ((CGFloat) -> Void)?
    private var avatarFrame = CGRect()
    private var galleryFrame: CGRect?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.viewsIconView.contentMode = .center
        self.addSubview(self.viewsIconView)
        self.viewsLabel.font = Font.medium(11.0)
        self.addSubview(self.viewsLabel)
        self.chevronView.contentMode = .center
        self.addSubview(self.chevronView)
        // The bubble lays itself out for the chat's rotated list: turned back here.
        self.bubbleContainerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        self.addSubview(self.bubbleContainerNode.view)
        self.addSubview(self.galleryView)
        self.addSubview(self.reactionsView)
        self.galleryView.scrolled = { [weak self] distance in
            guard let self, let galleryFrame = self.galleryFrame else {
                return
            }
            self.avatarOffsetChanged?(newsExpandedAvatarOffset(galleryScrolled: distance, galleryFrame: galleryFrame, avatarFrame: self.avatarFrame))
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// Whether `point` (in this view) is on content with its own touches: the bubble, a gallery item, a pill or
    /// Show more. The row's tap and highlight leave those alone.
    func hasInteractiveContent(at point: CGPoint) -> Bool {
        if let bubbleItemNode = self.bubbleItemNode, bubbleItemNode.supernode != nil, self.bubbleContainerNode.frame.contains(point) {
            return true
        }
        if !self.galleryView.isHidden, self.galleryView.frame.contains(point) {
            return true
        }
        if !self.reactionsView.isHidden, self.reactionsView.frame.contains(point) {
            return true
        }
        if let showMoreView = self.showMoreView.view, showMoreView.superview != nil, showMoreView.frame.contains(point) {
            return true
        }
        return false
    }

    /// Whether `point` (in this view) is on a strip that scrolls sideways.
    func hasHorizontalScrolling(at point: CGPoint) -> Bool {
        for strip in [self.galleryView, self.reactionsView] where !strip.isHidden && strip.frame.contains(point) {
            if strip.contentSize.width + strip.contentInset.left + strip.contentInset.right > strip.bounds.width + 0.5 {
                return true
            }
        }
        return false
    }

    func update(component: NewsFeedPostComponent, content: NewsFeedPostExpandedContent, width: CGFloat, timeSize: CGSize, avatarFrame: CGRect, synchronousLoad: Bool, transition: ComponentTransition) -> Layout {
        let metrics = NewsExpandedPostMetrics.self
        let theme = component.theme
        let context = component.context
        self.avatarFrame = avatarFrame
        let contentX = metrics.contentX(leftInset: 0.0)
        let contentWidth = metrics.contentWidth(width: width, leftInset: 0.0, rightInset: 0.0)
        let contentMaxX = contentX + contentWidth

        // The channel line's right part: views, time, chevron.
        let secondaryColor = theme.list.itemSecondaryTextColor
        let chevronImage = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10.0, weight: .semibold))?.withTintColor(theme.list.disclosureArrowColor, renderingMode: .alwaysOriginal)
        self.chevronView.image = chevronImage
        let chevronSize = chevronImage?.size ?? CGSize(width: 8.0, height: 12.0)
        let headerMidY = metrics.headerTop + metrics.headerHeight * 0.5
        func centred(maxX: CGFloat, size: CGSize) -> CGRect {
            return CGRect(origin: CGPoint(x: maxX - size.width, y: floorToScreenPixels(headerMidY - size.height * 0.5)), size: size)
        }
        var metaMaxX = contentMaxX
        transition.setFrame(view: self.chevronView, frame: centred(maxX: metaMaxX, size: chevronSize))
        metaMaxX -= chevronSize.width + 6.0
        let timeFrame = centred(maxX: metaMaxX, size: timeSize)
        metaMaxX -= timeSize.width
        var viewCount: Int?
        for message in component.messages {
            for attribute in message.attributes {
                if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = max(viewCount ?? 0, attribute.count)
                }
            }
        }
        if let viewCount {
            metaMaxX -= 6.0
            self.viewsLabel.textColor = secondaryColor
            self.viewsLabel.text = compactNumericCountString(viewCount, decimalSeparator: component.dateTimeFormat.decimalSeparator)
            let viewsSize = self.viewsLabel.sizeThatFits(CGSize(width: 100.0, height: 100.0))
            transition.setFrame(view: self.viewsLabel, frame: centred(maxX: metaMaxX, size: viewsSize))
            metaMaxX -= viewsSize.width + 2.0
            let eyeImage = UIImage(systemName: "eye", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11.0, weight: .medium))?.withTintColor(secondaryColor, renderingMode: .alwaysOriginal)
            self.viewsIconView.image = eyeImage
            let eyeSize = eyeImage?.size ?? CGSize(width: 14.0, height: 10.0)
            transition.setFrame(view: self.viewsIconView, frame: centred(maxX: metaMaxX, size: eyeSize))
            metaMaxX -= eyeSize.width
            self.viewsLabel.isHidden = false
            self.viewsIconView.isHidden = false
        } else {
            self.viewsLabel.isHidden = true
            self.viewsIconView.isHidden = true
        }
        let metaWidth = contentMaxX - metaMaxX

        let parts = newsExpandedPostParts(messages: component.messages)
        var nextY = metrics.textTop

        // The bubble: the text (its first lines while collapsed), the link preview and the other content.
        var collapsedText: String?
        var showsShowMore = false
        if !content.isTextExpanded, let textMessage = parts.bubble.first(where: { !$0.text.isEmpty }) {
            let font = Font.regular(content.presentationData.chatFontSize.baseDisplaySize)
            collapsedText = newsCollapsedText(textMessage.text, font: font, width: contentWidth)
            showsShowMore = collapsedText != nil
        }
        var bubbleMessages: [EngineMessage] = []
        var cutApplied = false
        for message in parts.bubble {
            if !cutApplied, let collapsedText, !message.text.isEmpty {
                bubbleMessages.append(newsBubbleMessage(message, collapsedText: collapsedText))
                cutApplied = true
            } else {
                bubbleMessages.append(newsBubbleMessage(message, collapsedText: nil))
            }
        }
        if !bubbleMessages.isEmpty {
            let actions = ChatMessageFeedItemActions(openUrl: { url in
                content.openUrl(url)
            }, openMessage: { message in
                return content.openMedia(message, nil)
            }, openPeer: { peer in
                content.openPeer(peer)
            }, openInstantPage: { message in
                content.openInstantPage(message)
            }, clickThrough: {
                component.action()
            })
            let item = context.sharedContext.makeChatMessageFeedItem(context: context, messages: bubbleMessages, presentationData: content.presentationData, availableReactions: content.availableReactions, accountPeer: content.accountPeer, actions: actions)
            let params = ListViewItemLayoutParams(width: contentWidth + metrics.bubbleWidthOverhead, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            let neighbors = ListViewItemNeighbors(previous: nil, next: nil)
            var nodeSize = CGSize()
            if let itemNode = self.bubbleItemNode {
                item.updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, neighbors: neighbors, animation: .None, completion: { layout, apply in
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                    nodeSize = layout.size
                    apply(ListViewItemApply())
                })
            } else {
                var createdNode: ListViewItemNode?
                item.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: synchronousLoad, neighbors: neighbors, completion: { node, apply in
                    createdNode = node
                    apply().1(ListViewItemApply())
                })
                if let createdNode {
                    createdNode.frame = CGRect(origin: CGPoint(), size: createdNode.frame.size)
                    nodeSize = createdNode.frame.size
                    self.bubbleContainerNode.addSubnode(createdNode)
                    self.bubbleItemNode = createdNode
                }
            }
            if let itemNode = self.bubbleItemNode {
                // Where the bubble's content lies in its item: the text starts a fixed distance into it.
                let contentFrame = (itemNode as? ChatMessageItemView)?.contentFrame() ?? CGRect(origin: CGPoint(x: 3.0, y: itemNode.insets.top), size: nodeSize)
                let textLeading = contentFrame.minX + metrics.bubbleTextLeadingInset - 3.0
                let containerFrame = CGRect(origin: CGPoint(x: contentX - textLeading, y: nextY - metrics.bubbleTextTopInset - contentFrame.minY), size: nodeSize)
                transition.setFrame(view: self.bubbleContainerNode.view, frame: containerFrame)
                self.bubbleContainerNode.view.isHidden = false
                nextY = containerFrame.minY + contentFrame.maxY - metrics.bubbleTextTopInset
            }
        } else if let itemNode = self.bubbleItemNode {
            itemNode.removeFromSupernode()
            self.bubbleItemNode = nil
            self.bubbleContainerNode.view.isHidden = true
        }

        if showsShowMore {
            let showMoreSize = self.showMoreView.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.News_ShowMore, font: Font.regular(content.presentationData.chatFontSize.baseDisplaySize), textColor: theme.list.itemAccentColor)))),
                    effectAlignment: .left,
                    action: {
                        content.toggleTextExpanded()
                    },
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 100.0)
            )
            if let view = self.showMoreView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                nextY += metrics.showMoreTopSpacing
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentX, y: nextY), size: showMoreSize))
                nextY += showMoreSize.height
            }
        } else if let view = self.showMoreView.view {
            view.removeFromSuperview()
        }

        // The gallery: full width, its content starting at the column.
        var galleryFrame: CGRect?
        if !parts.gallery.isEmpty {
            let layout = newsExpandedGalleryLayout(dimensions: parts.gallery.map(\.dimensions), columnWidth: contentWidth)
            if nextY > metrics.textTop {
                nextY += metrics.galleryTopSpacing
            }
            let frame = CGRect(x: 0.0, y: nextY, width: width, height: layout.contentSize.height)
            galleryFrame = frame
            transition.setFrame(view: self.galleryView, frame: frame)
            self.galleryView.contentInset = UIEdgeInsets(top: 0.0, left: contentX, bottom: 0.0, right: metrics.rightInset)
            self.galleryView.contentSize = layout.contentSize
            while self.galleryItemViews.count > parts.gallery.count {
                self.galleryItemViews.removeLast().removeFromSuperview()
            }
            while self.galleryItemViews.count < parts.gallery.count {
                let view = NewsGalleryItemView(frame: CGRect())
                self.galleryView.addSubview(view)
                self.galleryItemViews.append(view)
            }
            for (index, media) in parts.gallery.enumerated() {
                let view = self.galleryItemViews[index]
                transition.setFrame(view: view, frame: layout.items[index])
                view.update(context: context, item: media, size: layout.items[index].size)
                view.action = {
                    let _ = content.openMedia(media.message, media.media)
                }
            }
            self.galleryView.isHidden = false
            nextY = frame.maxY
        } else {
            self.galleryView.isHidden = true
            for view in self.galleryItemViews {
                view.removeFromSuperview()
            }
            self.galleryItemViews.removeAll()
        }
        self.galleryFrame = galleryFrame

        // The reactions line: comments first, then the reactions as the chat draws them, scrolling sideways.
        let reactionsFrame = self.updateReactions(component: component, content: content, width: width, contentX: contentX, y: nextY + metrics.reactionsTopSpacing, synchronousLoad: synchronousLoad, transition: transition)
        if let reactionsFrame {
            nextY = reactionsFrame.maxY
        }

        let height = nextY + metrics.bottomInset
        return Layout(height: height, timeFrame: timeFrame, metaWidth: metaWidth)
    }

    private func updateReactions(component: NewsFeedPostComponent, content: NewsFeedPostExpandedContent, width: CGFloat, contentX: CGFloat, y: CGFloat, synchronousLoad: Bool, transition: ComponentTransition) -> CGRect? {
        let metrics = NewsExpandedPostMetrics.self
        let theme = component.theme
        let context = component.context
        guard let message = component.messages.first else {
            return nil
        }
        var replyThread: ReplyThreadMessageAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? ReplyThreadMessageAttribute, attribute.commentsPeerId != nil {
                replyThread = attribute
            }
        }
        let reactionsAttribute = mergedMessageReactions(attributes: message.attributes, isTags: false)
        var mappedReactions: [ReactionButtonsAsyncLayoutContainer.Reaction] = []
        if let reactionsAttribute {
            for reaction in reactionsAttribute.reactions {
                var centerAnimation: TelegramMediaFile?
                var animationFileId: Int64?
                switch reaction.value {
                case .builtin, .stars:
                    if let availableReactions = content.availableReactions {
                        for availableReaction in availableReactions.reactions where availableReaction.value == reaction.value {
                            centerAnimation = availableReaction.centerAnimation?._parse()
                            break
                        }
                    }
                case let .custom(fileId):
                    animationFileId = fileId
                }
                mappedReactions.append(ReactionButtonsAsyncLayoutContainer.Reaction(
                    reaction: ReactionButtonComponent.Reaction(value: reaction.value, centerAnimation: centerAnimation, animationFileId: animationFileId, title: nil),
                    count: Int(reaction.count),
                    peers: [],
                    chosenOrder: reaction.chosenOrder
                ))
            }
        }
        guard replyThread != nil || !mappedReactions.isEmpty else {
            self.reactionsView.isHidden = true
            if let commentsPillView = self.commentsPillView {
                commentsPillView.removeFromSuperview()
                self.commentsPillView = nil
            }
            let _ = self.reactionsContainer.update(context: context, action: { _, _, _ in }, reactions: [], colors: newsReactionColors(theme: theme), isTag: false, constrainedWidth: .greatestFiniteMagnitude)
            return nil
        }
        let colors = newsReactionColors(theme: theme)
        let frame = CGRect(x: 0.0, y: y, width: width, height: metrics.reactionsHeight)
        transition.setFrame(view: self.reactionsView, frame: frame)
        self.reactionsView.contentInset = UIEdgeInsets(top: 0.0, left: contentX, bottom: 0.0, right: metrics.rightInset)
        self.reactionsView.isHidden = false
        var x: CGFloat = 0.0
        if let replyThread {
            let pill: NewsCommentsPillView
            if let current = self.commentsPillView {
                pill = current
            } else {
                pill = NewsCommentsPillView(frame: CGRect())
                self.reactionsView.addSubview(pill)
                self.commentsPillView = pill
            }
            var peers: [EnginePeer] = []
            for peerId in replyThread.latestUsers {
                if let peer = message.peers[peerId] {
                    peers.append(EnginePeer(peer))
                }
            }
            let size = pill.update(context: context, peers: peers, count: replyThread.count, strings: component.strings, dateTimeFormat: component.dateTimeFormat, backgroundColor: UIColor(argb: colors.deselectedBackground), foregroundColor: UIColor(argb: colors.deselectedForeground), synchronousLoad: synchronousLoad)
            pill.action = {
                content.openComments()
            }
            transition.setFrame(view: pill, frame: CGRect(origin: CGPoint(x: x, y: 0.0), size: size))
            x += size.width + metrics.reactionsSpacing
        } else if let commentsPillView = self.commentsPillView {
            commentsPillView.removeFromSuperview()
            self.commentsPillView = nil
        }
        let result = self.reactionsContainer.update(context: context, action: { _, value, _ in
            content.toggleReaction(value)
        }, reactions: mappedReactions, colors: colors, isTag: false, constrainedWidth: .greatestFiniteMagnitude)
        let applied = result.apply(.None, ReactionButtonsAsyncLayoutContainer.Arguments(animationCache: context.animationCache, animationRenderer: context.animationRenderer))
        for item in applied.items {
            let view = item.node.view
            if view.superview !== self.reactionsView {
                self.reactionsView.addSubview(view)
            }
            transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: x, y: 0.0), size: item.size))
            x += item.size.width + metrics.reactionsSpacing
        }
        for removed in applied.removedNodes {
            removed.view.removeFromSuperview()
        }
        self.reactionsView.contentSize = CGSize(width: max(0.0, x - metrics.reactionsSpacing), height: metrics.reactionsHeight)
        return frame
    }
}

/// The channel name's colour: the channel's own name colour (as the chat draws its name), the accent when it has none.
func newsChannelNameColor(peer: EnginePeer, context: AccountContext, theme: PresentationTheme) -> UIColor {
    switch peer._asPeer().nameColor {
    case let .preset(nameColor):
        return context.peerNameColors.get(nameColor, dark: theme.overallDarkAppearance).main
    case let .collectible(collectibleColor):
        return collectibleColor.peerNameColors(dark: theme.overallDarkAppearance).main
    default:
        return theme.list.itemAccentColor
    }
}
