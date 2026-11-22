import Foundation
import UIKit
import CoreText
import AsyncDisplayKit
import SwiftSignalKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import PhotoResources
import MultilineTextComponent
import PlainButtonComponent
import ChatMessageItemView
import NewsFeedSupport

/// What an expanded post row needs beyond the compact one: the chat's presentation (the bubble follows it) and where
/// the content's taps go. The closures are the screen's; only the values take part in the component's equality.
public final class NewsFeedPostExpandedContent {
    public let presentationData: PresentationData
    public let accountPeer: EnginePeer?
    /// Show more was tapped: the whole text rather than its first lines.
    public let isTextExpanded: Bool
    public let toggleTextExpanded: () -> Void
    public let openUrl: (String) -> Void
    /// A photo of the gallery, or media the bubble shows; `transitionNode` is the gallery's photo to zoom from.
    public let openMedia: (EngineMessage, EngineMedia?, NewsGalleryTransition?) -> Bool
    public let openPeer: (EnginePeer) -> Void
    public let openInstantPage: (EngineMessage) -> Void
    /// A tap on the bubble's reply header: the post it replies to.
    public let openMessage: (EngineMessage.Id) -> Void

    public init(presentationData: PresentationData, accountPeer: EnginePeer?, isTextExpanded: Bool, toggleTextExpanded: @escaping () -> Void, openUrl: @escaping (String) -> Void, openMedia: @escaping (EngineMessage, EngineMedia?, NewsGalleryTransition?) -> Bool, openPeer: @escaping (EnginePeer) -> Void, openInstantPage: @escaping (EngineMessage) -> Void, openMessage: @escaping (EngineMessage.Id) -> Void) {
        self.presentationData = presentationData
        self.accountPeer = accountPeer
        self.isTextExpanded = isTextExpanded
        self.toggleTextExpanded = toggleTextExpanded
        self.openUrl = openUrl
        self.openMedia = openMedia
        self.openPeer = openPeer
        self.openInstantPage = openInstantPage
        self.openMessage = openMessage
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
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.isTextExpanded != rhs.isTextExpanded {
            return false
        }
        return true
    }
}

/// A gallery photo's node and bounds, for the media viewer to zoom out of and back into (the chat's own
/// `transitionNode`); `snapshot` makes the copy the viewer animates.
public struct NewsGalleryTransition {
    public let node: ASDisplayNode
    public let bounds: CGRect
    public let snapshot: () -> (UIView?, UIView?)
}

/// A photo, or an album's video, for the gallery.
private struct NewsGalleryMedia {
    let message: EngineMessage
    let media: EngineMedia
    let dimensions: CGSize
    let videoDuration: Double?

    var id: EngineMedia.Id? {
        return self.media.id
    }
}

/// The post split for the expanded row: photos and videos go to the gallery, under the text, as the compact row's
/// thumbnail; everything else (text, link preview, round videos, files, polls) stays in the bubble, where the chat
/// draws it as in a chat. A message with nothing left for the bubble is left out of it.
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
            case let .file(file) where file.isVideo && !file.isInstantVideo:
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

/// The bubble shows the content only: reactions and the comments thread are left out of the feed row. `cutLength`: a
/// collapsed post's text, cut to its first `cutLength` UTF-16 units and …, with the entities over the kept text
/// (`newsCollapsedTextEntities`), so the cut is drawn exactly as the start of the whole text. The entities attribute
/// stays even when no entity is left: what the bubble detects on its own (phone numbers) depends on it, and the cut
/// must show what the whole text shows.
private func newsBubbleMessage(_ message: EngineMessage, cutLength: Int?) -> EngineMessage {
    var attributes = message.attributes.filter { attribute in
        if attribute is ReactionsMessageAttribute || attribute is ReplyThreadMessageAttribute {
            return false
        }
        return true
    }
    var result = message._asMessage()
    if let cutLength {
        let text = message.text as NSString
        if let index = attributes.firstIndex(where: { $0 is TextEntitiesMessageAttribute }), let entities = (attributes[index] as? TextEntitiesMessageAttribute)?.entities {
            attributes[index] = TextEntitiesMessageAttribute(entities: newsCollapsedTextEntities(entities, text: text, length: cutLength))
        }
        result = result.withUpdatedText(text.substring(to: min(cutLength, text.length)) + "…")
    }
    return EngineMessage(result.withUpdatedAttributes(attributes))
}

/// A collapsed message split around Show more: its cut text without the link preview, and the preview on its own,
/// so Show more stands between the text and the preview rather than under it. nil when the message has no preview.
private func newsCollapsedMessageParts(_ message: EngineMessage, cutLength: Int) -> (text: EngineMessage, preview: EngineMessage)? {
    let raw = message._asMessage()
    guard let webpage = raw.media.first(where: { $0 is TelegramMediaWebpage }) else {
        return nil
    }
    let text = newsBubbleMessage(EngineMessage(raw.withUpdatedMedia(raw.media.filter { !($0 is TelegramMediaWebpage) })), cutLength: cutLength)
    let preview = newsBubbleMessage(EngineMessage(raw.withUpdatedText("").withUpdatedMedia([webpage]).withUpdatedAttributes(raw.attributes.filter { !($0 is TextEntitiesMessageAttribute) })), cutLength: nil)
    return (text, preview)
}

/// Where a long post is cut (`newsCollapsedTextLength`) and how much taller the whole text is (from the last kept
/// line's baseline to the last line's), or nil when it fits the limit. The text is laid out at the bubble's text width
/// with its entities in the fonts the bubble draws it in (New York when picked), and without what would give a line a range that does not index
/// `message.text`: no strings, so a formatted date is not substituted, and no code block colours, so a code block gets
/// no title line.
private func newsCollapsedCut(_ message: EngineMessage, presentationData: PresentationData, width: CGFloat) -> (length: Int, hiddenHeight: CGFloat)? {
    let fonts = ChatPresentationData(presentationData: presentationData)
    let bodyFonts = fonts.messageBodyFonts
    let text = message.text as NSString
    let entities = message.attributes.compactMap({ $0 as? TextEntitiesMessageAttribute }).first?.entities ?? []
    var string = stringWithAppliedEntities(message.text, entities: entities, baseColor: .black, linkColor: .black, baseFont: bodyFonts.body.regular, linkFont: bodyFonts.body.regular, boldFont: bodyFonts.body.bold, italicFont: bodyFonts.body.italic, boldItalicFont: bodyFonts.body.boldItalic, fixedFont: fonts.messageFixedFont, blockQuoteFont: fonts.messageBlockQuoteFont, blockFonts: bodyFonts.blockFonts, message: message._asMessage(), adjustQuoteFontSize: true)
    if string.length != text.length {
        // Something is drawn as other text: the lines' ranges would not index the message's text.
        string = NSAttributedString(string: message.text, font: bodyFonts.body.regular, textColor: .black)
    }
    let (layout, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: string, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width, height: .greatestFiniteMagnitude)))
    let limit = NewsExpandedPostMetrics.collapsedLineLimit
    guard layout.numberOfLines > limit else {
        return nil
    }
    var ranges: [NSRange] = []
    var baselines: [CGFloat] = []
    layout.enumerateRenderedLines(in: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height + 10000.0))) { line, baseline in
        let range = CTLineGetStringRange(line)
        ranges.append(NSRange(location: range.location, length: range.length))
        baselines.append(baseline.y)
    }
    guard let length = newsCollapsedTextLength(text: text, lineRanges: ranges, lineLimit: limit) else {
        return nil
    }
    let hiddenHeight = baselines.count > limit ? max(0.0, baselines[baselines.count - 1] - baselines[limit - 1]) : 0.0
    return (length, hiddenHeight)
}

/// Whether the bubble ends with the message's text: Show more's reveal uncovers what follows the cut from the top down,
/// which is wrong for anything drawn under the text (media, an inline keyboard, a fact check) or above it.
private func newsBubbleEndsWithText(_ message: EngineMessage) -> Bool {
    if !message.engineMedia.isEmpty {
        return false
    }
    for attribute in message.attributes {
        if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
            return false
        }
        if let attribute = attribute as? FactCheckMessageAttribute, case .Loaded = attribute.content {
            return false
        }
        if attribute is InvertMediaMessageAttribute {
            return false
        }
    }
    return true
}

/// One gallery item: the photo (or an album video's thumbnail, with "▶ 0:12") with continuous corners. The image is
/// a node, so the media viewer can zoom out of it and back into it as it does from the chat's photos.
private final class NewsGalleryItemView: UIView {
    let imageNode = TransformImageNode()
    private let durationLabel = UILabel()
    private(set) var mediaId: EngineMedia.Id?
    var action: (() -> Void)?
    /// The photo this view shows, for the media viewer's hidden media: while the viewer shows it, the photo here is
    /// hidden, as the chat hides its own (the viewer zooms out of a copy).
    private var shownMedia: (accountId: AccountRecordId, messageId: EngineMessage.Id, media: EngineMedia)?
    private var hiddenMediaDisposable: Disposable?
    private var hiddenIds = Set<GalleryHiddenMediaId>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageNode.layer.cornerRadius = NewsExpandedPostMetrics.galleryCornerRadius
        self.imageNode.layer.cornerCurve = .continuous
        self.imageNode.clipsToBounds = true
        // At rest the drawing has the item's size. While a mode morph animates the photo's frame from the compact
        // thumbnail's, the drawing covers it (uncropping, as the thumbnail's does) instead of being stretched.
        self.imageNode.contentMode = .scaleAspectFill
        self.addSubview(self.imageNode.view)
        self.durationLabel.isHidden = true
        self.addSubview(self.durationLabel)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    deinit {
        self.hiddenMediaDisposable?.dispose()
    }

    @objc private func tapped() {
        self.action?()
    }

    private func updateHidden() {
        var isHidden = false
        if let shown = self.shownMedia {
            let media = shown.media._asMedia()
            isHidden = self.hiddenIds.contains(where: { id in
                if case let .chat(accountId, messageId, hiddenMedia) = id {
                    return accountId == shown.accountId && messageId == shown.messageId && hiddenMedia.isEqual(to: media)
                }
                return false
            })
        }
        self.imageNode.isHidden = isHidden
        self.durationLabel.alpha = isHidden ? 0.0 : 1.0
    }

    func update(context: AccountContext, item: NewsGalleryMedia, size: CGSize) {
        if self.hiddenMediaDisposable == nil {
            self.hiddenMediaDisposable = (context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds()
            |> deliverOnMainQueue).start(next: { [weak self] ids in
                guard let self else {
                    return
                }
                self.hiddenIds = ids
                self.updateHidden()
            })
        }
        self.shownMedia = (context.account.id, item.message.id, item.media)
        self.updateHidden()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        if self.mediaId != item.id {
            self.mediaId = item.id
            switch item.media {
            case let .image(image):
                self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 600.0, height: 600.0)), attemptSynchronously: false)
            case let .file(file):
                self.imageNode.setSignal(chatMessageVideoThumbnail(account: context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message._asMessage()), media: file)), attemptSynchronously: false)
            default:
                break
            }
        }
        let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: item.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()
        if let duration = item.videoDuration {
            // A text shadow, not a layer shadow: no offscreen pass for every video while scrolling.
            self.durationLabel.attributedText = newsVideoDurationString(duration: duration)
            let labelSize = self.durationLabel.sizeThatFits(CGSize(width: size.width, height: 100.0))
            self.durationLabel.frame = newsVideoLabelFrame(pictureFrame: CGRect(origin: CGPoint(), size: size), labelSize: labelSize, inset: NewsExpandedPostMetrics.galleryLabelInset)
            self.durationLabel.isHidden = false
        } else {
            self.durationLabel.isHidden = true
        }
    }

    /// A mode morph: the photo travels into its place from `rect` (in this view) on `transition`, on the path the row's
    /// thumbnail takes above it. Its frame (the drawing covers it), its corners from `cornerRadius` to the gallery's,
    /// and "▶ 0:12" riding its bottom-left corner from `labelInset` in to its own.
    func travel(from rect: CGRect, cornerRadius: CGFloat, labelInset: CGFloat, transition: ComponentTransition) {
        let layer = self.imageNode.layer
        let frame = self.imageNode.frame
        transition.animatePosition(layer: layer, from: CGPoint(x: rect.midX, y: rect.midY), to: CGPoint(x: frame.midX, y: frame.midY))
        transition.animateBoundsSize(layer: layer, from: rect.size, to: frame.size)
        layer.cornerRadius = cornerRadius
        transition.setCornerRadius(layer: layer, cornerRadius: NewsExpandedPostMetrics.galleryCornerRadius)
        if !self.durationLabel.isHidden {
            let labelFrame = self.durationLabel.frame
            let start = newsVideoLabelFrame(pictureFrame: rect, labelSize: labelFrame.size, inset: labelInset)
            transition.animatePosition(view: self.durationLabel, from: CGPoint(x: start.midX, y: start.midY), to: CGPoint(x: labelFrame.midX, y: labelFrame.midY))
        }
    }

    var transition: NewsGalleryTransition {
        return NewsGalleryTransition(node: self.imageNode, bounds: self.imageNode.bounds, snapshot: { [weak self] in
            return (self?.imageNode.view.snapshotContentTree(unhide: true), nil)
        })
    }
}

/// A horizontal strip (the gallery) that starts at the content column and passes under the avatar's column when
/// scrolled. Its scrolling is its own: the list's vertical pan and the screen's page swipe yield to it.
private final class NewsHorizontalStripView: UIScrollView {
    var scrolled: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.alwaysBounceVertical = false
        self.contentInsetAdjustmentBehavior = .never
        self.delaysContentTouches = false
        self.canCancelContentTouches = true
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// How far the content has moved from its resting position.
    var scrolledDistance: CGFloat {
        return self.contentOffset.x + self.contentInset.left
    }

    // Runs on every offset change, the deceleration and the bounce back included (a pan target stops at the lift).
    override func layoutSubviews() {
        super.layoutSubviews()
        self.scrolled?()
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}

/// One of the chat's message items in the row: its container (never animated, see `place`) and the item node.
private final class NewsBubbleSlot {
    let containerNode = ASDisplayNode()
    private(set) var itemNode: ListViewItemNode?
    /// Where the item's content lies in it, from the last layout.
    private(set) var contentFrame = CGRect()
    private(set) var size = CGSize()
    /// The row is in a window (the News screen is on screen): media in the bubble play only then.
    var isInWindow = false {
        didSet {
            if self.isInWindow != oldValue {
                self.updateVisibility()
            }
        }
    }

    init() {
        // The bubble lays itself out for the chat's rotated list: turned back here.
        self.containerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }

    var isShown: Bool {
        return self.itemNode?.supernode != nil
    }

    func update(item: ListViewItem, width: CGFloat, synchronousLoad: Bool) {
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
        let neighbors = ListViewItemNeighbors(previous: nil, next: nil)
        if let itemNode = self.itemNode {
            item.updateNode(async: { $0() }, node: {
                return itemNode
            }, params: params, neighbors: neighbors, animation: .None, completion: { [weak self] layout, apply in
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                itemNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                self?.size = layout.size
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
                self.size = createdNode.frame.size
                self.containerNode.addSubnode(createdNode)
                self.itemNode = createdNode
            }
        }
        if let itemNode = self.itemNode {
            // Where the bubble's content lies in its item: the text starts a fixed distance into it.
            self.contentFrame = (itemNode as? ChatMessageItemView)?.contentFrame() ?? CGRect(origin: CGPoint(x: 3.0, y: itemNode.insets.top), size: self.size)
            self.updateVisibility()
        }
    }

    /// In a window, the whole bubble counts as on screen for the chat's media: a video plays as it would in the
    /// chat. Out of one (another tab, a pushed chat) nothing plays.
    private func updateVisibility() {
        guard let itemNode = self.itemNode, itemNode.supernode != nil else {
            return
        }
        itemNode.visibility = self.isInWindow ? .visible(1.0, CGRect(origin: CGPoint(), size: self.size)) : .none
    }

    /// Places the container so the content's text starts at `textOrigin`, and returns the content's bottom. Never
    /// animated: the item inside is turned by π about the container's centre, so a height that animates shows the
    /// item above its place by the growth at first (Show more pushed the text up). The origin never changes between
    /// layouts, so the content stays put and the rows below move.
    func place(textOrigin: CGPoint) -> CGFloat {
        let metrics = NewsExpandedPostMetrics.self
        let textLeading = self.contentFrame.minX + metrics.bubbleTextLeadingInset - 3.0
        let containerFrame = CGRect(origin: CGPoint(x: textOrigin.x - textLeading, y: textOrigin.y - metrics.bubbleTextTopInset - self.contentFrame.minY), size: self.size)
        self.containerNode.view.frame = containerFrame
        self.containerNode.view.isHidden = false
        return containerFrame.minY + self.contentFrame.maxY - metrics.bubbleTextTopInset
    }

    func hide() {
        if let itemNode = self.itemNode {
            itemNode.visibility = .none
            itemNode.removeFromSupernode()
            self.itemNode = nil
        }
        self.containerNode.view.isHidden = true
    }

    /// Draws the item now: the chat's text draws asynchronously, a frame after its layout.
    func displaySynchronously() {
        self.itemNode?.recursivelyEnsureDisplaySynchronously(true)
    }

    func transitionNode(id: EngineMessage.Id, media: EngineMedia) -> NewsGalleryTransition? {
        guard let itemNode = self.itemNode as? ChatMessageItemView, let (node, bounds, snapshot) = itemNode.transitionNode(id: id, media: media._asMedia(), adjustRect: false) else {
            return nil
        }
        return NewsGalleryTransition(node: node, bounds: bounds, snapshot: snapshot)
    }

    /// Whether `gesture` at `point` (in `view`) is the bubble's own (a link, its media): the row leaves it alone.
    func ownsGesture(_ gesture: TapLongTapOrDoubleTapGesture, at point: CGPoint, in view: UIView) -> Bool {
        guard self.isShown, let itemNode = self.itemNode as? ChatMessageItemView, self.containerNode.frame.contains(view.convert(point, to: self.containerNode.view.superview)) else {
            return false
        }
        return itemNode.ownsGesture(gesture, at: itemNode.view.convert(point, from: view))
    }
}

/// The expanded row's content under the channel line: the views and time, the bubble's content, Show more, a link
/// preview after Show more, and the gallery. The row owns the avatar, the channel name, its badge and the time view,
/// and places them where this view says.
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
    private let bubble = NewsBubbleSlot()
    /// Holds the text's bubble and clips it while Show more reveals the rest (`reveal`); the bubble container itself
    /// never animates its height. Unclipped and covering the whole bubble at rest, so its links stay hittable.
    private let bubbleClipView = UIView()
    /// The text bubble's content bottom from the last layout: where a reveal starts.
    private var bubbleBottom: CGFloat = 0.0
    /// Whether the last layout showed the whole text, and at which width: Show more reveals only a toggle of the text
    /// at the same width.
    private var appliedIsTextExpanded = false
    private var appliedWidth: CGFloat?
    /// Bumped by every reveal: only the latest one's end lifts the clip, and while one runs, other layouts leave the
    /// clip alone.
    private var revealGeneration = 0
    private var isRevealing = false
    /// A collapsed post's link preview, after Show more.
    private let previewBubble = NewsBubbleSlot()
    private let showMoreView = ComponentView<Empty>()
    private let galleryView = NewsHorizontalStripView()
    private var galleryItemViews: [NewsGalleryItemView] = []
    /// The first layout places the subviews without animating them from their empty frames: a row morphing from
    /// compact makes this view during the morph's own animated pass, and the gallery (a scroll view, which clips)
    /// would show its photos growing out of a corner.
    private var hasLaidOut = false
    /// The last cut's inputs and result: a cut is a layout of the whole text, and every time tick updates the row.
    private var cutCache: (id: EngineMessage.Id, text: String, entities: [MessageTextEntity], width: CGFloat, fontSize: CGFloat, serif: Bool, cut: (length: Int, hiddenHeight: CGFloat)?)?

    /// The gallery's frame in this view, when the post has one, and how far its content has moved from rest: the
    /// floating avatar keeps out of a gallery scrolled under its column (`newsExpandedAvatarOffset`).
    private(set) var galleryFrame: CGRect?
    var galleryScrolledDistance: CGFloat {
        return self.galleryView.scrolledDistance
    }
    var galleryScrolled: (() -> Void)?
    /// The post is cut and offers Show more.
    private(set) var hasShowMore = false
    /// How much taller a cut post grows with Show more (its hidden lines): the list keeps that much more loaded under it
    /// for the pass (`NewsFeedListView.prepareHeightChange`). 0 when it is not cut.
    private(set) var textExpansionGrowth: CGFloat = 0.0
    /// Where the bubble's text starts, in this view, while the post has a bubble: a row morphing its compact text
    /// into the bubble's aims here.
    private(set) var bubbleTextOrigin: CGPoint?
    /// The first gallery item's frame in this view, as shown now (the gallery's scrolling included): the compact
    /// row's thumbnail morphs into it and out of it.
    var firstGalleryItemFrame: CGRect? {
        guard let galleryFrame = self.galleryFrame, !self.galleryView.isHidden, let first = self.galleryItemViews.first else {
            return nil
        }
        return CGRect(origin: CGPoint(x: galleryFrame.minX + first.frame.minX - self.galleryView.contentOffset.x, y: galleryFrame.minY + first.frame.minY), size: first.frame.size)
    }

    /// The first gallery item's media: the row's thumbnail morphs into it and out of it only when it is that picture.
    var firstGalleryMediaId: EngineMedia.Id? {
        return self.galleryView.isHidden ? nil : self.galleryItemViews.first?.mediaId
    }

    /// The first gallery photo as drawn now, for the row's thumbnail to stand in its place with.
    var firstGalleryItemContents: Any? {
        return self.galleryView.isHidden ? nil : self.galleryItemViews.first?.imageNode.contents
    }

    /// A mode morph from compact: the first gallery photo travels into place from `rect` (in `view`) on the path the
    /// row's thumbnail takes above it, so the two are one picture. The strip keeps clipping; what of the photo it cuts
    /// lies under the thumbnail. Unclipped, a wide gallery's other photos would draw into the neighbouring page.
    func morphFirstGalleryItem(from rect: CGRect, in view: UIView, cornerRadius: CGFloat, labelInset: CGFloat, transition: ComponentTransition) {
        guard !self.galleryView.isHidden, let itemView = self.galleryItemViews.first else {
            return
        }
        itemView.travel(from: view.convert(rect, to: itemView), cornerRadius: cornerRadius, labelInset: labelInset, transition: transition)
    }

    /// A mode morph to compact: the first gallery photo goes at once, the row's thumbnail standing over it with the
    /// same picture. A leaving content view is never reused.
    func hideFirstGalleryItem() {
        self.galleryItemViews.first?.isHidden = true
    }

    /// What a mode morph blurs: everything the content shows but the gallery's first photo, the picture that travels
    /// under the row's thumbnail (blurred, it would ring the thumbnail with a halo).
    var morphBlurLayers: [CALayer] {
        var layers: [CALayer] = []
        for view in [self.viewsIconView, self.viewsLabel, self.chevronView] as [UIView] where !view.isHidden {
            layers.append(view.layer)
        }
        for slot in [self.bubble, self.previewBubble] where slot.isShown {
            layers.append(slot.containerNode.layer)
        }
        if let view = self.showMoreView.view, view.superview != nil {
            layers.append(view.layer)
        }
        if !self.galleryView.isHidden {
            for itemView in self.galleryItemViews.dropFirst() {
                layers.append(itemView.layer)
            }
        }
        return layers
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.viewsIconView.contentMode = .center
        self.addSubview(self.viewsIconView)
        self.viewsLabel.font = Font.medium(11.0)
        self.addSubview(self.viewsLabel)
        self.chevronView.contentMode = .center
        self.addSubview(self.chevronView)
        self.addSubview(self.bubbleClipView)
        self.bubbleClipView.addSubview(self.bubble.containerNode.view)
        self.addSubview(self.previewBubble.containerNode.view)
        self.addSubview(self.galleryView)
        self.galleryView.scrolled = { [weak self] in
            self?.galleryScrolled?()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        for slot in [self.bubble, self.previewBubble] {
            slot.isInWindow = self.window != nil
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// Whether `gesture` at `point` (in this view) belongs to the content: a bubble's link or media (the bubble's
    /// plain text is the row's, as the space beside it), a gallery item or Show more. The row's tap, highlight and
    /// long press leave those alone.
    func ownsGesture(_ gesture: TapLongTapOrDoubleTapGesture, at point: CGPoint) -> Bool {
        for slot in [self.bubble, self.previewBubble] where slot.ownsGesture(gesture, at: point, in: self) {
            return true
        }
        if !self.galleryView.isHidden, self.galleryView.frame.contains(point) {
            // The strip is full-width; only its items are its own, the space beside them is the row's.
            let galleryPoint = self.convert(point, to: self.galleryView)
            if self.galleryItemViews.contains(where: { $0.frame.contains(galleryPoint) }) {
                return true
            }
        }
        if let showMoreView = self.showMoreView.view, showMoreView.superview != nil, showMoreView.frame.contains(point) {
            return true
        }
        return false
    }

    /// Whether `point` (in this view) is on a strip that scrolls sideways.
    func hasHorizontalScrolling(at point: CGPoint) -> Bool {
        let strip = self.galleryView
        guard !strip.isHidden, strip.frame.contains(point) else {
            return false
        }
        return strip.contentSize.width + strip.contentInset.left + strip.contentInset.right > strip.bounds.width + 0.5
    }

    /// What `view` shows now, fading out in its place over the view's new content.
    private func fadeOutSnapshot(of view: UIView, transition: ComponentTransition) {
        guard view.superview === self, !view.isHidden, let snapshot = view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        snapshot.frame = view.frame
        self.insertSubview(snapshot, aboveSubview: view)
        transition.setAlpha(view: snapshot, alpha: 0.0, completion: { [weak snapshot] _ in
            snapshot?.removeFromSuperview()
        })
    }

    /// What `view` shows now within `band` (in this view), fading out in its place over the view's new content. With
    /// `backing`, the snapshot lies on that colour, so what is the same underneath does not show through twice.
    private func fadeOutSnapshot(of view: UIView, within band: CGRect, backing: UIColor?, transition: ComponentTransition) {
        guard view.superview === self, !view.isHidden, band.height > 0.0, let snapshot = view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        let clip = UIView(frame: band)
        clip.clipsToBounds = true
        clip.isUserInteractionEnabled = false
        clip.backgroundColor = backing
        snapshot.frame = view.frame.offsetBy(dx: -band.minX, dy: -band.minY)
        clip.addSubview(snapshot)
        self.insertSubview(clip, aboveSubview: view)
        transition.setAlpha(view: clip, alpha: 0.0, completion: { [weak clip] _ in
            clip?.removeFromSuperview()
        })
    }

    /// The gallery's photo or video (or the bubble's media) to zoom the media viewer out of.
    func transitionNode(id: EngineMessage.Id, media: EngineMedia) -> NewsGalleryTransition? {
        if let item = self.galleryItemViews.first(where: { $0.mediaId == media.id }) {
            return item.transition
        }
        for slot in [self.bubble, self.previewBubble] {
            if let transition = slot.transitionNode(id: id, media: media) {
                return transition
            }
        }
        return nil
    }

    /// `newsCollapsedCut` for `message`, measured again only when its text, its entities, the width, the font size or
    /// the face (New York) change.
    private func collapsedCut(of message: EngineMessage, presentationData: PresentationData, width: CGFloat) -> (length: Int, hiddenHeight: CGFloat)? {
        let entities = message.attributes.compactMap({ $0 as? TextEntitiesMessageAttribute }).first?.entities ?? []
        let fontSize = presentationData.chatFontSize.baseDisplaySize
        let serif = presentationData.chatBubbleCorners.serifMessageText
        if let cache = self.cutCache, cache.id == message.id, cache.text == message.text, cache.entities == entities, cache.width == width, cache.fontSize == fontSize, cache.serif == serif {
            return cache.cut
        }
        let cut = newsCollapsedCut(message, presentationData: presentationData, width: width)
        self.cutCache = (message.id, message.text, entities, width, fontSize, serif, cut)
        return cut
    }

    /// Lays the content out at `width`. `revealBacking` is the colour under the row, on which Show more's reveal
    /// crossfades the cut's last lines; nil where the row is tinted or highlighted.
    func update(component: NewsFeedPostComponent, content: NewsFeedPostExpandedContent, width: CGFloat, timeSize: CGSize, synchronousLoad: Bool, revealBacking: UIColor?, transition: ComponentTransition) -> Layout {
        let metrics = NewsExpandedPostMetrics.self
        let theme = component.theme
        let context = component.context
        let contentX = metrics.contentX(leftInset: 0.0)
        let contentWidth = metrics.contentWidth(width: width, leftInset: 0.0, rightInset: 0.0)
        let contentMaxX = contentX + contentWidth
        let isRelayout = self.hasLaidOut
        let frameTransition: ComponentTransition = isRelayout ? transition : .immediate
        self.hasLaidOut = true
        let wasShowMore = self.hasShowMore

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
        frameTransition.setFrame(view: self.chevronView, frame: centred(maxX: metaMaxX, size: chevronSize))
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
            frameTransition.setFrame(view: self.viewsLabel, frame: centred(maxX: metaMaxX, size: viewsSize))
            metaMaxX -= viewsSize.width + 2.0
            // The chat's own view-count icon (the one its status line shows), in the channel line now.
            let eyeImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ImpressionCount"), color: secondaryColor)
            self.viewsIconView.image = eyeImage
            let eyeSize = eyeImage?.size ?? CGSize(width: 14.0, height: 10.0)
            frameTransition.setFrame(view: self.viewsIconView, frame: centred(maxX: metaMaxX, size: eyeSize))
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

        // The bubble: the text (its first lines while collapsed), the link preview and the other content. A
        // collapsed post's link preview moves to its own bubble after Show more.
        let textIndex = parts.bubble.firstIndex(where: { !$0.text.isEmpty })
        var cutLength: Int?
        var textExpansionGrowth: CGFloat = 0.0
        if !content.isTextExpanded, let textIndex, let cut = self.collapsedCut(of: parts.bubble[textIndex], presentationData: content.presentationData, width: contentWidth) {
            cutLength = cut.length
            textExpansionGrowth = cut.hiddenHeight
        }
        self.hasShowMore = cutLength != nil
        self.textExpansionGrowth = textExpansionGrowth
        var bubbleMessages: [EngineMessage] = []
        var previewMessages: [EngineMessage] = []
        for (index, message) in parts.bubble.enumerated() {
            if let cutLength, index == textIndex {
                if let split = newsCollapsedMessageParts(message, cutLength: cutLength) {
                    bubbleMessages.append(split.text)
                    previewMessages.append(split.preview)
                } else {
                    bubbleMessages.append(newsBubbleMessage(message, cutLength: cutLength))
                }
            } else {
                bubbleMessages.append(newsBubbleMessage(message, cutLength: nil))
            }
        }
        let actions = ChatMessageFeedItemActions(openUrl: { url in
            content.openUrl(url)
        }, openMessage: { message in
            return content.openMedia(message, nil, nil)
        }, openPeer: { peer in
            content.openPeer(peer)
        }, openInstantPage: { message in
            content.openInstantPage(message)
        }, navigateToMessage: { id in
            content.openMessage(id)
        })
        let bubbleWidth = contentWidth + metrics.bubbleWidthOverhead
        // Show more toggled: the rows and the gallery below ride the pass's spring, and the rest of the text is
        // revealed. The cut is drawn as the start of the whole text, so the text stays put while a clip around it grows
        // on the spring and what is under it moves down with the rows below. Only when the text alone makes the bubble
        // and nothing else changed: the same width, on screen, and no preview bubble that would have to join the
        // text's. Anything else crossfades in place: the bubble is laid out at once (its container never animates), so
        // what was there fades out as a snapshot over what is there now.
        let toggled = isRelayout && !transition.animation.isImmediate && wasShowMore != self.hasShowMore
        let reveals = toggled && wasShowMore && content.isTextExpanded && !self.appliedIsTextExpanded && self.appliedWidth == width && self.window != nil && !self.previewBubble.isShown && bubbleMessages.count == 1 && bubbleMessages.allSatisfy(newsBubbleEndsWithText)
        let crossfades = toggled && !reveals
        let oldHeight = self.bounds.height
        let oldBubbleBottom = self.bubbleBottom
        var showMoreSnapshot: (view: UIView, frame: CGRect)?
        if reveals {
            // Only the cut's last lines (the …, a word it pushed down) differ from the whole text: their old drawing
            // fades out on top, on the row's colour, so identical glyphs underneath stay exact. The band is three lines
            // at the bubble's pitch, rounded up, and a quote's or code block's padding.
            let pitch = ceil(Font.regular(content.presentationData.chatFontSize.baseDisplaySize).lineHeight * 1.2)
            let bandHeight = pitch * 3.0 + 8.0
            self.fadeOutSnapshot(of: self.bubbleClipView, within: CGRect(x: contentX - 8.0, y: oldBubbleBottom - bandHeight, width: contentWidth + 16.0, height: bandHeight + metrics.showMoreTopSpacing), backing: revealBacking, transition: .easeInOut(duration: 0.2))
            if let view = self.showMoreView.view, view.superview === self, let snapshot = view.snapshotView(afterScreenUpdates: false) {
                showMoreSnapshot = (snapshot, view.frame)
            }
        } else if crossfades {
            self.fadeOutSnapshot(of: self.bubbleClipView, transition: transition)
            self.fadeOutSnapshot(of: self.previewBubble.containerNode.view, transition: transition)
            if let view = self.showMoreView.view {
                self.fadeOutSnapshot(of: view, transition: transition)
            }
        }
        if !bubbleMessages.isEmpty {
            self.bubble.update(item: context.sharedContext.makeChatMessageFeedItem(context: context, messages: bubbleMessages, presentationData: content.presentationData, accountPeer: content.accountPeer, actions: actions), width: bubbleWidth, synchronousLoad: synchronousLoad)
            self.bubbleTextOrigin = CGPoint(x: contentX, y: nextY)
            nextY = self.bubble.place(textOrigin: CGPoint(x: contentX, y: nextY))
            if reveals {
                // The revealed lines are drawn now, not a frame late.
                self.bubble.displaySynchronously()
            } else if crossfades {
                transition.animateAlpha(view: self.bubble.containerNode.view, from: 0.0, to: 1.0)
            }
        } else {
            self.bubble.hide()
            self.bubbleTextOrigin = nil
        }
        self.bubbleBottom = nextY

        if self.hasShowMore {
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
                nextY += metrics.showMoreTopSpacing
                let showMoreFrame = CGRect(origin: CGPoint(x: contentX, y: nextY), size: showMoreSize)
                if view.superview == nil {
                    self.addSubview(view)
                    view.frame = showMoreFrame
                    if crossfades {
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    }
                }
                transition.setFrame(view: view, frame: showMoreFrame)
                nextY += showMoreSize.height
            }
        } else if let view = self.showMoreView.view {
            view.removeFromSuperview()
        }

        if !previewMessages.isEmpty {
            self.previewBubble.update(item: context.sharedContext.makeChatMessageFeedItem(context: context, messages: previewMessages, presentationData: content.presentationData, accountPeer: content.accountPeer, actions: actions), width: bubbleWidth, synchronousLoad: synchronousLoad)
            nextY += metrics.showMoreTopSpacing
            nextY = self.previewBubble.place(textOrigin: CGPoint(x: contentX, y: nextY))
            if crossfades {
                transition.animateAlpha(view: self.previewBubble.containerNode.view, from: 0.0, to: 1.0)
            }
        } else {
            self.previewBubble.hide()
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
            frameTransition.setFrame(view: self.galleryView, frame: frame)
            self.galleryView.contentInset = UIEdgeInsets(top: 0.0, left: contentX, bottom: 0.0, right: metrics.rightInset)
            self.galleryView.contentSize = layout.contentSize
            while self.galleryItemViews.count > parts.gallery.count {
                self.galleryItemViews.removeLast().removeFromSuperview()
            }
            while self.galleryItemViews.count < parts.gallery.count {
                let view = NewsGalleryItemView(frame: layout.items[self.galleryItemViews.count])
                self.galleryView.addSubview(view)
                self.galleryItemViews.append(view)
            }
            for (index, media) in parts.gallery.enumerated() {
                let view = self.galleryItemViews[index]
                frameTransition.setFrame(view: view, frame: layout.items[index])
                view.update(context: context, item: media, size: layout.items[index].size)
                view.action = { [weak view] in
                    let _ = content.openMedia(media.message, media.media, view?.transition)
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

        let height = nextY + metrics.bottomInset
        if reveals {
            self.reveal(fromBubbleBottom: oldBubbleBottom, oldHeight: oldHeight, height: height, width: width, showMoreSnapshot: showMoreSnapshot, transition: transition)
        } else if !self.isRevealing {
            // Unclipped at rest, covering the whole bubble so its links stay hittable.
            self.bubbleClipView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: max(height, self.bubble.containerNode.view.frame.maxY))
        }
        self.appliedIsTextExpanded = content.isTextExpanded
        self.appliedWidth = width
        return Layout(height: height, timeFrame: timeFrame, metaWidth: metaWidth)
    }

    /// Show more's reveal, on the pass's spring: the clip around the text grows from the cut's bottom to the whole
    /// text's (the edge) while what is under the text (the gallery, the row's separator, the rows below) moves down by
    /// the row's growth, Show more's slot less. Show more rides with that content in a clip whose top is the edge, so
    /// the revealed text covers it as it fades.
    private func reveal(fromBubbleBottom oldBubbleBottom: CGFloat, oldHeight: CGFloat, height: CGFloat, width: CGFloat, showMoreSnapshot: (view: UIView, frame: CGRect)?, transition: ComponentTransition) {
        let spacing = NewsExpandedPostMetrics.showMoreTopSpacing
        let edgeTravel = self.bubbleBottom - oldBubbleBottom
        let tailTravel = height - oldHeight
        self.revealGeneration += 1
        let generation = self.revealGeneration
        self.isRevealing = true
        self.bubbleClipView.clipsToBounds = true
        self.bubbleClipView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: oldBubbleBottom + spacing)
        transition.setFrame(view: self.bubbleClipView, frame: CGRect(x: 0.0, y: 0.0, width: width, height: self.bubbleBottom + spacing), completion: { [weak self] _ in
            guard let self, self.revealGeneration == generation else {
                return
            }
            self.isRevealing = false
            self.bubbleClipView.clipsToBounds = false
            self.bubbleClipView.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: max(self.bounds.height, self.bubble.containerNode.view.frame.maxY))
        })
        guard let (snapshot, frame) = showMoreSnapshot else {
            return
        }
        // Show more's height and its 2 pt spacing: how much faster the edge travels than the tail.
        let lead = edgeTravel - tailTravel
        let clip = UIView(frame: CGRect(x: 0.0, y: self.bubbleBottom + spacing, width: width, height: max(0.0, frame.maxY - oldBubbleBottom - spacing)))
        clip.clipsToBounds = true
        clip.isUserInteractionEnabled = false
        snapshot.frame = frame.offsetBy(dx: 0.0, dy: -(oldBubbleBottom + spacing) - lead)
        clip.addSubview(snapshot)
        self.addSubview(clip)
        transition.animatePosition(view: clip, from: CGPoint(x: 0.0, y: -edgeTravel), to: CGPoint(), additive: true)
        transition.animatePosition(view: snapshot, from: CGPoint(x: 0.0, y: lead), to: CGPoint(), additive: true)
        transition.setAlpha(view: clip, alpha: 0.0, completion: { [weak clip] _ in
            clip?.removeFromSuperview()
        })
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
