import Foundation
import UIKit
import CoreText
import Display
import ComponentFlow
import SwiftSignalKit
import HierarchyTrackingLayer
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TextFormat
import PhotoResources
import AvatarComponent
import EmojiStatusComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import AsyncDisplayKit
import ItemListUI
import CoreList
import CoreListComponentHost
import NewsFeedSupport

private enum NewsPostThumbnail {
    case image(TelegramMediaImage)
    case video(TelegramMediaFile)

    var mediaId: EngineMedia.Id? {
        switch self {
        case let .image(image):
            return image.imageId
        case let .video(file):
            return file.fileId
        }
    }
}

/// The first photo or video of the post (an album's first item).
private func newsPostThumbnail(_ messages: [EngineMessage]) -> (EngineMessage, NewsPostThumbnail)? {
    for message in messages {
        for media in message.engineMedia {
            switch media {
            case let .image(image):
                return (message, .image(image))
            case let .file(file):
                if file.isVideo {
                    return (message, .video(file))
                }
            default:
                break
            }
        }
    }
    return nil
}

private func newsPostText(component: NewsFeedPostComponent, maxLength: Int) -> NSAttributedString {
    let theme = component.theme
    let font = Font.regular(15.0)
    if let message = component.messages.first(where: { !$0.text.isEmpty }) {
        // The chat list's preview rule (which also keeps quotes and code blocks out, whose block layout breaks the
        // line limit), with italic drawn upright too.
        var entities: [MessageTextEntity] = []
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = chatListPreviewTextEntities(attribute.entities)
            }
        }
        let prefix = newsPreviewTextPrefix(message.text, entities: entities, maxLength: maxLength)
        // One character for one, so the entity ranges stay valid.
        let text = prefix.text.replacingOccurrences(of: "\n", with: " ")
        // Secondary: a compact row's text is a preview, read in full once the post is expanded.
        return chatListPreviewAttributedString(text, entities: prefix.entities, strings: component.strings, dateTimeFormat: component.dateTimeFormat, font: font, italicFont: font, textColor: theme.list.itemSecondaryTextColor, message: message._asMessage())
    }
    guard let message = component.messages.first else {
        return NSAttributedString()
    }
    // A rich message keeps its text in the attribute, so it arrives here as a preview: text, not a label.
    let (summary, _, _) = descriptionStringForMessage(contentSettings: component.context.currentContentSettings.with { $0 }, message: message, strings: component.strings, nameDisplayOrder: component.nameDisplayOrder, dateTimeFormat: component.dateTimeFormat, accountPeerId: component.context.account.peerId)
    return NSAttributedString(string: summary.string, font: font, textColor: theme.list.itemSecondaryTextColor)
}

/// The time a post row shows now.
private func newsPostTimeText(component: NewsFeedPostComponent) -> String {
    return newsTimeText(newsCompactTime(timestamp: component.timestamp, now: Int32(Date().timeIntervalSince1970)), strings: component.strings, dateTimeFormat: component.dateTimeFormat)
}

/// A post row: avatar, channel name, verified badge, compact time, up to three lines of text, and an
/// optional thumbnail on the right. Tapping opens the post. The time keeps itself current while on screen.
public final class NewsFeedPostComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let peer: EnginePeer
    /// Ascending ids; an album has several.
    public let messages: [EngineMessage]
    /// The newest message's: the post's age is shown from it.
    public let timestamp: Int32
    public let loading: NewsFeedRowLoading
    /// The post was just revealed by a pull to refresh: it sits on the new-posts block and lenses in (spec §4).
    public let fresh: NewsFreshSegment?
    public let reduceMotion: Bool
    /// Not Interested, or a hidden channel's post leaving: the content fades out in place (spec §3).
    public let fading: Bool
    /// When Undo brought the post back: a row created right after fades in and rises.
    public let appearTime: Double?
    /// The row's swipe actions; nil for rows that do not swipe (search results).
    public let swipe: NewsPostSwipe?
    /// Compact (the default) or the expanded post; `expanded` carries what the expanded row needs.
    public let displayMode: NewsFeedDisplayMode
    public let expanded: NewsFeedPostExpandedContent?
    /// A long press on the row (its context gesture): the post's context menu, lifting the row's content
    /// (`contextContentView`). nil for rows without one.
    public let contextMenu: ((View, ContextGesture) -> Void)?
    /// A floating avatar over this row moved (`floatingAvatarFrames`).
    public let floatingAvatarsChanged: (() -> Void)?
    public let action: () -> Void

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, peer: EnginePeer, messages: [EngineMessage], timestamp: Int32, loading: NewsFeedRowLoading, fresh: NewsFreshSegment? = nil, reduceMotion: Bool = false, fading: Bool = false, appearTime: Double? = nil, swipe: NewsPostSwipe? = nil, displayMode: NewsFeedDisplayMode = .compact, expanded: NewsFeedPostExpandedContent? = nil, contextMenu: ((View, ContextGesture) -> Void)? = nil, floatingAvatarsChanged: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.peer = peer
        self.messages = messages
        self.timestamp = timestamp
        self.loading = loading
        self.fresh = fresh
        self.reduceMotion = reduceMotion
        self.fading = fading
        self.appearTime = appearTime
        self.swipe = swipe
        self.displayMode = displayMode
        self.expanded = expanded
        self.contextMenu = contextMenu
        self.floatingAvatarsChanged = floatingAvatarsChanged
        self.action = action
    }

    public static func ==(lhs: NewsFeedPostComponent, rhs: NewsFeedPostComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.messages != rhs.messages {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.loading !== rhs.loading {
            return false
        }
        if lhs.fresh != rhs.fresh {
            return false
        }
        if lhs.reduceMotion != rhs.reduceMotion {
            return false
        }
        if lhs.fading != rhs.fading {
            return false
        }
        if lhs.appearTime != rhs.appearTime {
            return false
        }
        // The closures are per post and the list's; only whether and which way the row swipes changes how it looks.
        if (lhs.swipe == nil) != (rhs.swipe == nil) || lhs.swipe?.hasFeedbackActions != rhs.swipe?.hasFeedbackActions {
            return false
        }
        if lhs.displayMode != rhs.displayMode {
            return false
        }
        if !NewsFeedPostExpandedContent.isEqual(lhs.expanded, rhs.expanded) {
            return false
        }
        if (lhs.contextMenu == nil) != (rhs.contextMenu == nil) {
            return false
        }
        return true
    }

    public final class View: UIView, UIGestureRecognizerDelegate, CoreListComponentAttachmentsReceiver {
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let credibilityIcon = ComponentView<Empty>()
        private let time = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let thumbnailView = TransformImageView()
        private let videoLabel = UILabel()
        private let separatorLayer = SimpleLayer()
        /// The swipe (spec §1). It holds the content, which slides, and the full-width press highlight, which it turns
        /// into the swipe surface; the fresh block and the separator stay outside it.
        private let revealView = NewsPostRevealView()
        /// The long press: a context gesture (as the chat list's rows), which fails the row's tap and the swipe when
        /// it activates, so nothing opens under the menu.
        private let contextSourceView = ContextControllerSourceView()
        /// What the context menu lifts: `contentView` inside it.
        private let extractedContainerView = ContextExtractedContentContainingView()
        /// Lifted into the context menu: the content gets the list's background with rounded corners, the row's
        /// own avatar shows (the floating one stays with the list), and the swipe is closed.
        private var isExtracted = false
        /// The row's own avatar stands in for the floating one, at the floating one's place (in `lensView`), from
        /// the first frame of a press: the press scales it with the content, and the lift takes it along, with no
        /// jump of either. nil while the floating one shows. A row the floating avatar is not over shows none.
        private var handedOffAvatarFrame: CGRect?
        /// Where the expanded layout puts the row's own avatar, to go back to after a hand-off.
        private var layoutAvatarFrame: CGRect?
        /// The press became the menu: the hand-off stays until the put-back is over (`finishPutBack`).
        private var pressActivated = false
        /// The put-back's scale to 1 is running: the row keeps the card and its own avatar until it has landed and the
        /// menu has put the content back into the row, whichever comes last (`finishPutBack`).
        private var isScalingBack = false
        /// A press is under way (from its `.begin` until its `.ended`, or its release).
        private var isPressing = false
        /// Its own swipe fades the separator, and so does the swipe of the row below (`setRowBelowSeparatorAlpha`).
        private var rowBelowSeparatorAlpha: CGFloat = 1.0
        /// The content has faded out for the "Post hidden" panel (spec §3).
        private var isFadedOut = false
        /// Everything but the highlight, the block and the separator. It carries a fresh row's clip and is never
        /// transformed, so the clip stays the card while `lensView` inside it is magnified.
        private let contentView = UIView()
        /// What a fresh row lenses in.
        private let lensView = UIView()
        /// A row that existed before a reveal never lenses in when it turns fresh.
        private let createdAt = CACurrentMediaTime()
        private var freshBlockView: NewsFreshBlockView?
        private var lensRevealTime: Double?
        private var highlightTimer: SwiftSignalKit.Timer?
        private var isHighlighted = false
        /// The row's tap is running its action. UIKit delivers `touchesEnded`, where the tap's highlight flashes, only
        /// after the action, so a Show more pass the tap runs finds no highlight yet although one is about to show.
        private var isRunningTap = false
        /// In a window and the app in the foreground: only then does the time need checking.
        private let hierarchyTrackingLayer = HierarchyTrackingLayer()

        private var component: NewsFeedPostComponent?
        private weak var state: EmptyComponentState?
        private var thumbnailMediaId: EngineMedia.Id?
        /// The thumbnail draws its whole picture (`newsThumbnailDrawingSize`), so it can travel into the gallery's
        /// first photo.
        private var thumbnailDrawsWholePicture = false
        /// The last morph to Expanded took the thumbnail along the gallery's first photo's path. A morph back that
        /// finds it still in flight takes the picture from there; one that finds it fading where it was (no image yet
        /// when the morph out began) fades it back in.
        private var thumbnailTravelsWithPhoto = false
        /// The expanded post's content, made when the row first expands and kept while it is expanded.
        private var expandedContentView: NewsExpandedPostContentView?
        /// The floating avatars of the runs this row is in (`NewsFloatingAvatarAttachedItem`), told where the
        /// row's gallery is so they keep out of it.
        private var floatingAvatarViews: [NewsFloatingAvatarView] = []
        /// The update in progress switches the mode: the layouts animate their shared views and `morph` runs.
        private var isMorphing = false
        /// The own avatar's flight into the floating avatar in a morph from compact (`aimAvatarHandOff`).
        private var avatarHandOff: AvatarHandOff?
        /// Counts the own avatar's flights: only the last one's completion hands over (an aim replaces the animations
        /// of the one before, whose completions still report).
        private var avatarFlight = 0
        /// The row's height as last laid out: an animated change of it clips the row meanwhile
        /// (`clipWhileHeightAnimates`).
        private var laidOutHeight: CGFloat?
        /// Bumped by every animated height change: only the latest one's end lifts the clip.
        private var heightClipGeneration = 0
        /// A mode morph is landing (`suspendInteractionWhileMorphing`).
        private var isMorphInFlight = false
        private var morphInFlightGeneration = 0
        /// The time as last laid out.
        private var renderedTimeText: String?
        private var timeTimer: SwiftSignalKit.Timer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.revealView)
            self.revealView.contentView.addSubview(self.contextSourceView)
            self.contextSourceView.addSubview(self.extractedContainerView)
            self.extractedContainerView.contentView.addSubview(self.contentView)
            self.contentView.addSubview(self.lensView)
            // The press scales the content as the chat list's rows do, with the avatar handed over first.
            self.contextSourceView.customActivationProgress = { [weak self] progress, update in
                self?.applyPressScale(progress: progress, update: update)
            }
            // A pinch's second finger may land on another row: the source view must not block it (it is exclusive
            // by default), and this row sees both fingers, so a long press yields to a pinch at once.
            self.contextSourceView.isExclusiveTouch = false
            self.contextSourceView.isMultipleTouchEnabled = true
            self.isMultipleTouchEnabled = true
            self.contextSourceView.shouldBegin = { [weak self] point in
                guard let self, self.component?.contextMenu != nil, !self.revealView.isRevealOptionsActive, !self.isMorphInFlight else {
                    return false
                }
                // A link's own long press (the bubble's copy / open menu) stays the bubble's.
                return !self.contentOwnsGesture(.longTap, at: self.convert(point, from: self.contextSourceView))
            }
            self.contextSourceView.activated = { [weak self] gesture, _ in
                guard let self, let contextMenu = self.component?.contextMenu else {
                    gesture.cancel()
                    return
                }
                self.pressActivated = true
                contextMenu(self, gesture)
            }
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, transition in
                guard let self else {
                    return
                }
                self.isExtracted = value
                if value {
                    self.isScalingBack = false
                    self.closeSwipe(animated: false)
                    self.highlightTimer?.invalidate()
                    self.highlightTimer = nil
                    self.setHighlighted(false, animated: false)
                    // Lifted, the content is scaled down to leave 16 pt at each side: scaled, never laid out narrower.
                    transition.updateTransformScale(layer: self.contentView.layer, scale: View.extractedScale(width: self.bounds.width))
                    self.updateExtractedAppearance(transition: transition)
                } else {
                    // The menu carries the content back in 0.2 s, ease in-out, and fades its dim over the same 0.2 s
                    // (`ContextControllerExtractedPresentationNode`'s put-back of a `.default` dismissal,
                    // `ContextSourceContainer.animateOut`); the transition handed here is 0.35 s. The scale and the
                    // corners follow the travel, so the content lands at full size and square as the dim clears, as
                    // `BrowserAddressListItemComponent` and `BusinessLinkListItemComponent` time theirs. The card and
                    // the row's own avatar stay until the content is back in the row (`finishPutBack`). The floating
                    // avatar is the list's, under the dim: handed back here, it would show there, unscaled and offset.
                    let putBack: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                    self.isScalingBack = true
                    putBack.updateTransformScale(layer: self.contentView.layer, scale: 1.0, completion: { [weak self] _ in
                        guard let self, !self.isExtracted else {
                            return
                        }
                        self.isScalingBack = false
                        self.finishPutBack()
                    })
                    self.updateExtractedAppearance(transition: putBack)
                }
            }
            // `false` arrives once the menu's travel has ended and the content is back in the row.
            self.extractedContainerView.isExtractedToContextPreviewUpdated = { [weak self] value in
                if !value {
                    self?.finishPutBack()
                }
            }
            self.revealView.opened = { [weak self] in
                guard let self else {
                    return
                }
                self.component?.swipe?.opened(self)
            }
            self.revealView.separatorAlphaChanged = { [weak self] in
                guard let self else {
                    return
                }
                self.updateSeparatorAlpha()
                self.component?.swipe?.separatorAlphaChanged(self)
            }
            self.revealView.selected = { [weak self] action in
                self?.component?.swipe?.action(action)
            }
            self.revealView.hasHorizontalScrollingContent = { [weak self] point in
                guard let self else {
                    return false
                }
                return self.hasHorizontalScrollingContent(at: self.convert(point, from: self.revealView))
            }
            self.revealView.offsetChanged = { [weak self] offset in
                self?.updateFloatingAvatarSwipe(offset)
            }
            // One element, so VoiceOver offers the swipe's actions on it (spec §6).
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
            // Continuous corners (Feed2 FeedRow.swift:430-445): the layer clips, the image is drawn without corners.
            self.thumbnailView.layer.cornerRadius = NewsPostRowMetrics.thumbnailCornerRadius
            self.thumbnailView.layer.cornerCurve = .continuous
            self.thumbnailView.clipsToBounds = true
            // Its frame animates into the gallery's first photo and back: it draws the whole picture and shows the
            // part its frame covers.
            self.thumbnailView.layer.contentsGravity = .resizeAspectFill
            self.lensView.addSubview(self.thumbnailView)
            // "▶ 0:12" on a video's thumbnail: no background, a soft shadow (Feed2 FeedRow.swift:436-442).
            self.videoLabel.isHidden = true
            self.videoLabel.isUserInteractionEnabled = false
            self.lensView.addSubview(self.videoLabel)
            self.layer.addSublayer(self.separatorLayer)
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] _ in
                self?.updateTimeTimer()
            }
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
            // The row still gets `touchesEnded`, so a quick tap flashes its highlight.
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            self.addGestureRecognizer(tapRecognizer)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        deinit {
            self.timeTimer?.invalidate()
            self.highlightTimer?.invalidate()
            // The run's avatar outlives a row of it: it forgets the row's gallery and swipe.
            for view in self.floatingAvatarViews {
                view.setObstacle(nil, for: self)
                view.setSwipeOffset(0.0, for: self)
            }
        }

        /// The row's place in a new-posts block, as last laid out: the list draws the block's glow over its rows.
        public var freshSegment: NewsFreshSegment? {
            return self.component?.fresh
        }

        /// Where the last layout put the avatar, the channel name and each line of the text, in the row's own
        /// coordinates: the loading skeleton is measured from them.
        public var avatarFrame: CGRect {
            return self.avatar.view?.frame ?? CGRect()
        }

        public var titleFrame: CGRect {
            return self.title.view?.frame ?? CGRect()
        }

        public var textFrame: CGRect {
            return self.text.view?.frame ?? CGRect()
        }

        public var textLineFrames: [CGRect] {
            guard let textView = self.text.view as? MultilineTextWithEntitiesComponent.View, let layout = textView.textNode.cachedLayout else {
                return []
            }
            // Each line's ascent and descent around the baseline it is drawn at. `linesRects()` starts each line at
            // its baseline, most of a line lower.
            let textNodeView = textView.textNode.view
            var frames: [CGRect] = []
            layout.enumerateRenderedLines(in: textNodeView.bounds) { line, baseline in
                var ascent: CGFloat = 0.0
                var descent: CGFloat = 0.0
                let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
                frames.append(textNodeView.convert(CGRect(x: baseline.x, y: baseline.y - ascent, width: width, height: ascent + descent), to: self))
            }
            return frames
        }

        /// An expanded row's content takes its own taps (links, media, Show more): the row's tap leaves them. A tap
        /// on the bubble's plain text is the row's, as one beside it.
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            return !self.contentOwnsGesture(.tap, at: touch.location(in: self))
        }

        /// The row's tap neither blocks nor is blocked by the bubble's own recognisers; the list's pan still wins.
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return !(otherGestureRecognizer is UIPanGestureRecognizer)
        }

        /// Whether the expanded content takes `gesture` at `point` (in this row) as its own.
        private func contentOwnsGesture(_ gesture: TapLongTapOrDoubleTapGesture, at point: CGPoint) -> Bool {
            guard let expandedContentView = self.expandedContentView, expandedContentView.superview != nil, expandedContentView.alpha > 0.0 else {
                return false
            }
            return expandedContentView.ownsGesture(gesture, at: self.convert(point, to: expandedContentView))
        }

        /// The row's content as the context menu takes it: lifted with the list's background behind it.
        public var contextContentView: ContextExtractedContentContainingView {
            return self.extractedContainerView
        }

        /// A pinch took the touches: the long press in progress, if any, ends without a menu.
        public func cancelContextGesture() {
            self.contextSourceView.contextGesture?.cancel()
        }

        /// The scale of the lifted content: 16 pt clear at each side of the row's width.
        private static func extractedScale(width: CGFloat) -> CGFloat {
            return width > 32.0 ? (width - 32.0) / width : 1.0
        }

        /// The card the content is lifted on: the list's background, opaque from the lift (in its own slot it is the
        /// screen's own colour, so nothing changes there), with corners that round to 26 pt on screen with the lift and
        /// square off with the put-back. A fresh row's tint lies under the content, so there the colour fades in and
        /// out too. It clips until the put-back is over (`finishPutBack`).
        private func updateExtractedAppearance(transition: ContainedViewLayoutTransition) {
            defer {
                self.updateFloatingAvatarVisibility()
            }
            guard let component = self.component else {
                return
            }
            let layer = self.contentView.layer
            let color = component.theme.list.plainBackgroundColor
            let fadesColor = component.fresh != nil
            if self.isExtracted {
                self.contentView.clipsToBounds = true
                layer.cornerCurve = .continuous
                if fadesColor {
                    if layer.backgroundColor == nil {
                        // `updateBackgroundColor` does not animate from nil: start from the same colour, clear.
                        layer.backgroundColor = color.withAlphaComponent(0.0).cgColor
                    }
                    transition.updateBackgroundColor(layer: layer, color: color)
                } else {
                    layer.removeAnimation(forKey: "backgroundColor")
                    layer.backgroundColor = color.cgColor
                }
                // 26 pt on screen: the content is scaled.
                transition.updateCornerRadius(layer: layer, cornerRadius: 26.0 / View.extractedScale(width: self.bounds.width))
            } else {
                if fadesColor {
                    transition.updateBackgroundColor(layer: layer, color: color.withAlphaComponent(0.0))
                }
                transition.updateCornerRadius(layer: layer, cornerRadius: 0.0)
            }
        }

        /// The put-back is over once the menu has put the content back into the row and its scale has landed, whichever
        /// comes last. The card goes, the row takes the layout it left to the menu meanwhile, and the floating avatar
        /// takes over from the row's own, which is exactly where it is: the floating avatar's place, at scale 1, in the
        /// list. A press begun meanwhile keeps the hand-off.
        private func finishPutBack() {
            guard !self.isExtracted, !self.isScalingBack, !self.extractedContainerView.isExtractedToContextPreview else {
                return
            }
            self.pressActivated = false
            let layer = self.contentView.layer
            layer.removeAnimation(forKey: "backgroundColor")
            layer.removeAnimation(forKey: "cornerRadius")
            layer.backgroundColor = nil
            layer.cornerRadius = 0.0
            self.contentView.clipsToBounds = false
            // The same frames unless the row was laid out at another size while the content was away (`update`).
            let rowBounds = self.extractedContainerView.bounds
            self.extractedContainerView.contentView.frame = rowBounds
            self.contentView.frame = rowBounds
            self.lensView.frame = self.contentView.bounds
            if !self.isPressing {
                self.restoreAvatar()
            }
        }

        /// The press scale the chat list's rows get (`ContextControllerSourceView`'s default, about the content's
        /// centre), with the avatar handed over on its first frame so it scales along; released without a menu, it
        /// springs back and the floating avatar takes over again. An activation follows the `.ended` at once and
        /// keeps the hand-off (`pressActivated`).
        private func applyPressScale(progress: CGFloat, update: ContextGestureTransition) {
            let layer = self.extractedContainerView.contentView.layer
            let side = max(1.0, layer.bounds.width)
            let minScale: CGFloat = max(0.7, (side - 15.0) / side)
            let scale = 1.0 * (1.0 - progress) + minScale * progress
            let transform = CATransform3DMakeScale(scale, scale, 1.0)
            switch update {
            case .begin:
                self.isPressing = true
                self.handOffAvatar()
                layer.sublayerTransform = transform
            case .update:
                layer.sublayerTransform = transform
            case .ended:
                self.isPressing = false
                let previous = layer.sublayerTransform
                // The menu ends the pressed appearance a second time as it lifts the content (`ContextGesture`'s
                // `endPressedAppearance`, from `ContextControllerNode.animateIn`), after the activation's own `.ended`.
                // Re-animating identity to identity under the same key would cancel the release still running, and the
                // press would drop in one frame.
                if !CATransform3DEqualToTransform(previous, transform) {
                    layer.sublayerTransform = transform
                    layer.animate(from: NSValue(caTransform3D: previous), to: NSValue(caTransform3D: transform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.pressActivated, !self.isExtracted, !self.isPressing else {
                        return
                    }
                    self.restoreAvatar()
                }
            }
        }

        /// A press released before its gesture's first progress update gets no `.ended` (`ContextGesture` sends one
        /// only once there is progress), so the hand-off its `.begin` made would stay: undone on the next turn, as
        /// after an `.ended`, unless a menu is still putting the content back, whose end restores it. A press that
        /// became the menu had its `.ended` at activation, before its touches were cancelled.
        private func endPressIfReleasedEarly() {
            guard self.isPressing else {
                return
            }
            self.isPressing = false
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.pressActivated, !self.isExtracted, !self.isPressing else {
                    return
                }
                self.restoreAvatar()
            }
        }

        /// The row's own avatar takes the floating one's place, if the floating one is over this row.
        private func handOffAvatar() {
            guard self.handedOffAvatarFrame == nil, self.avatarHandOff == nil, self.component?.displayMode == .expanded, let avatarView = self.avatar.view else {
                return
            }
            guard let frame = self.floatingAvatarFrames(in: self.lensView).first(where: { $0.intersects(self.lensView.bounds) }) else {
                return
            }
            self.handedOffAvatarFrame = frame
            avatarView.frame = frame
            avatarView.isHidden = false
            self.updateFloatingAvatarVisibility()
        }

        private func restoreAvatar() {
            guard self.handedOffAvatarFrame != nil else {
                return
            }
            self.handedOffAvatarFrame = nil
            // In Compact the layout owns the avatar (a mode change while pressed or lifted); in Expanded it goes back
            // to its hidden slot, where the floating one takes over.
            if self.component?.displayMode == .expanded, let avatarView = self.avatar.view, let frame = self.layoutAvatarFrame {
                avatarView.frame = frame
                avatarView.isHidden = true
            }
            self.updateFloatingAvatarVisibility()
        }

        /// The floating avatar over this row is hidden while the row's own stands in for it: pressed or lifted into a
        /// context menu (`handedOffAvatarFrame`), or flying into its place in a morph from compact. Only a new floating
        /// avatar, which nothing has drawn yet, is hidden; one already on screen stays and the own one slides under it.
        /// It shows in the frame the own one hides. One that another row's flight is landing on stays hidden for that
        /// row.
        private func updateFloatingAvatarVisibility() {
            let landingView = self.avatarHandOff.flatMap { $0.hidesFloatingView ? $0.floatingView : nil }
            for view in self.floatingAvatarViews {
                let landedOnByAnotherRow = view.landingRow != nil && view.landingRow !== self
                view.isHidden = self.handedOffAvatarFrame != nil || view === landingView || landedOnByAnotherRow
            }
        }

        /// Whether `point` (in this row) is on a strip of the expanded post that scrolls sideways (the gallery): the
        /// screen's page swipe and the row's own swipe leave it alone.
        public func hasHorizontalScrollingContent(at point: CGPoint) -> Bool {
            guard let expandedContentView = self.expandedContentView, expandedContentView.superview != nil else {
                return false
            }
            return expandedContentView.hasHorizontalScrolling(at: self.convert(point, to: expandedContentView))
        }

        public func attachedItemsUpdated(_ attachments: [UIView & CoreListAttachedItemView]) {
            for view in self.floatingAvatarViews {
                view.setObstacle(nil, for: self)
                view.setSwipeOffset(0.0, for: self)
            }
            self.floatingAvatarViews = attachments.compactMap { $0 as? NewsFloatingAvatarView }
            for view in self.floatingAvatarViews {
                view.setObstacle({ [weak self, weak view] in
                    guard let self, let view, let contentView = self.expandedContentView, contentView.superview != nil, let galleryFrame = contentView.galleryFrame else {
                        return nil
                    }
                    return (contentView.convert(galleryFrame, to: view), contentView.galleryScrolledDistance)
                }, for: self)
                view.frameChanged = { [weak self] in
                    self?.component?.floatingAvatarsChanged?()
                }
                view.obstacleChanged()
            }
            self.updateFloatingAvatarSwipe(self.revealView.revealOffset)
            // The list places its attachments after the rows' updates: a morph from compact aims its avatar here.
            self.aimAvatarHandOff()
            self.updateFloatingAvatarVisibility()
        }

        /// The floating avatars over this row, in `view`'s coordinates.
        public func floatingAvatarFrames(in view: UIView) -> [CGRect] {
            return self.floatingAvatarViews.map { $0.convert($0.avatarFrame, to: view) }
        }

        /// The floating avatar sitting on this row slides with the row's swipe; one floating over another row stays.
        private func updateFloatingAvatarSwipe(_ offset: CGFloat) {
            for view in self.floatingAvatarViews {
                let avatarFrame = view.convert(view.restingAvatarFrame, to: self)
                view.setSwipeOffset(self.bounds.intersects(avatarFrame) ? offset : 0.0, for: self)
            }
        }

        @objc private func tapped() {
            // A row landing a morph opens nothing (`suspendInteractionWhileMorphing`).
            guard !self.isMorphInFlight else {
                return
            }
            // A tap on an open row only closes it. The control's own tap does that too; whichever of the two taps
            // wins, the row closes and nothing opens.
            guard !self.revealView.isRevealOptionsActive else {
                self.closeSwipe(animated: true)
                return
            }
            self.isRunningTap = true
            defer {
                self.isRunningTap = false
            }
            self.open()
        }

        /// The row was tapped, anywhere or on the bubble's plain text: a cut post shows the rest first; a whole one
        /// opens.
        private func open() {
            if let content = self.component?.expanded, let contentView = self.expandedContentView, contentView.superview != nil, contentView.hasShowMore {
                content.toggleTextExpanded()
                return
            }
            self.component?.action()
        }

        /// How much taller this post grows once Show more is tapped, for the list to keep the rows under it loaded while
        /// they slide down. nil when it is not cut.
        public var textExpansionGrowth: CGFloat? {
            guard let contentView = self.expandedContentView, contentView.superview != nil, contentView.hasShowMore else {
                return nil
            }
            return contentView.textExpansionGrowth
        }

        // MARK: Swipe (spec §1, §5)

        /// The right side's actions (For you's Interesting / Not Interested), for the pager's right-edge rule.
        public var hasSwipeActions: Bool {
            return self.component?.swipe?.hasFeedbackActions == true
        }

        /// The left side's Expand / Collapse, for the pager's left-edge rule in Added.
        public var hasLeftSwipeAction: Bool {
            return self.component?.swipe != nil
        }

        /// 1 closed, 0 open: the row's own separator, and the separator of the row above, fade with it.
        public var swipeSeparatorAlpha: CGFloat {
            return self.revealView.revealOptionsSeparatorAlpha
        }

        /// The swipe separator alpha of the post row directly below (1 when there is none).
        public func setRowBelowSeparatorAlpha(_ alpha: CGFloat) {
            guard self.rowBelowSeparatorAlpha != alpha else {
                return
            }
            self.rowBelowSeparatorAlpha = alpha
            self.updateSeparatorAlpha()
        }

        public func closeSwipe(animated: Bool) {
            self.revealView.setRevealOptionsOpened(false, animated: animated)
        }

        /// A switch of the feed's mode to `displayMode` with this row open: a row the switch morphs closes at once, its
        /// content springing back on the morph's spring (`NewsPostRevealView.closeForMorph`). One already in that mode
        /// (its own Expand / Collapse, which the switch clears) does not morph and slides closed as any row does, so a
        /// floating avatar on it, which follows the control's offset, slides back with it.
        public func closeSwipeForMorph(to displayMode: NewsFeedDisplayMode) {
            if self.component?.displayMode == displayMode {
                self.closeSwipe(animated: true)
            } else {
                self.revealView.closeForMorph()
            }
        }

        private func updateSeparatorAlpha() {
            self.separatorLayer.opacity = self.isFadedOut ? 0.0 : Float(min(self.swipeSeparatorAlpha, self.rowBelowSeparatorAlpha))
        }

        /// The content (and separator) fades out in place over 0.16 s with a 6 pt blur (Feed3 `fading`).
        /// The fresh block under the row goes with it. A row created already fading (scrolled in mid-fade) is just
        /// faded, without replaying the fade (`animated`).
        private func updateFading(_ fading: Bool, animated: Bool) {
            guard fading != self.isFadedOut else {
                return
            }
            self.isFadedOut = fading
            let layer = self.revealView.layer
            if fading {
                self.revealView.alpha = 0.0
                self.freshBlockView?.alpha = 0.0
                if animated {
                    let duration = NewsFeedbackTiming.fadeOut
                    let timing = CAMediaTimingFunctionName.easeOut.rawValue
                    self.separatorLayer.animateAlpha(from: CGFloat(self.separatorLayer.opacity), to: 0.0, duration: duration, timingFunction: timing)
                    layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: timing)
                    self.freshBlockView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: timing)
                    if let filter = CALayer.blur() {
                        filter.setValue(6.0 as NSNumber, forKey: "inputRadius")
                        layer.filters = [filter]
                        layer.animate(from: 0.0 as NSNumber, to: 6.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: timing, duration: duration)
                    }
                }
            } else {
                self.revealView.alpha = 1.0
                self.freshBlockView?.alpha = 1.0
                layer.filters = nil
            }
            self.updateSeparatorAlpha()
        }

        /// A post Undo brought back fades in and rises 12 pt after 0.08 s (`Motion.appear`); under Reduce Motion it
        /// only fades. Animations only, on the row's own layer: its frame stays CoreList's.
        private func playReturnAppear(appearTime: Double, rises: Bool) {
            let delay = max(0.0, appearTime + NewsFeedbackTiming.appearDelay - CACurrentMediaTime())
            let spring = NewsSpring.appear
            self.layer.add(spring.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber, delay: delay), forKey: "newsReturnAlpha")
            if rises {
                let rise = spring.makeAnimation(keyPath: "position.y", from: 12.0 as NSNumber, to: 0.0 as NSNumber, delay: delay)
                rise.isAdditive = true
                self.layer.add(rise, forKey: "newsReturnRise")
            }
        }

        /// As our lists highlight (`ListView`: shown 0.08 s after touch-down unless a scroll starts first;
        /// `ItemListDisclosureItem`: faded out over 0.4 s).
        private func setHighlighted(_ highlighted: Bool, animated: Bool) {
            guard self.isHighlighted != highlighted else {
                return
            }
            self.isHighlighted = highlighted
            // The control owns the highlight's alpha (pressed, and the swipe surface), as in the chat list.
            let transition: ContainedViewLayoutTransition = highlighted || !animated ? .immediate : .animated(duration: 0.4, curve: .easeInOut)
            self.revealView.updateRevealOptionsHighlightedBackgroundNode(self.revealView.highlightView, isHighlighted: highlighted, transition: transition, aboveNodes: [])
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            // Two fingers: a pinch, never a long press.
            if let event, (event.allTouches?.count ?? 0) > 1 {
                self.cancelContextGesture()
                return
            }
            // A row landing a morph shows no highlight.
            if self.isMorphInFlight {
                return
            }
            // An open row shows its swipe surface; a tap only closes it.
            if self.revealView.isRevealOptionsActive {
                return
            }
            if let touch = touches.first, self.contentOwnsGesture(.tap, at: touch.location(in: self)) {
                return
            }
            self.highlightTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: 0.08, repeat: false, completion: { [weak self] in
                self?.setHighlighted(true, animated: false)
            }, queue: Queue.mainQueue())
            self.highlightTimer = timer
            timer.start()
        }

        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            self.endPressIfReleasedEarly()
            if self.revealView.isRevealOptionsActive {
                return
            }
            self.highlightTimer?.invalidate()
            self.highlightTimer = nil
            // Nor a tap's flash, and a highlight from before the morph goes.
            if self.isMorphInFlight {
                self.setHighlighted(false, animated: true)
                return
            }
            if let touch = touches.first, self.contentOwnsGesture(.tap, at: touch.location(in: self)) {
                return
            }
            // A quick tap still flashes, as in the chat list.
            self.setHighlighted(true, animated: false)
            self.setHighlighted(false, animated: true)
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            self.endPressIfReleasedEarly()
            self.highlightTimer?.invalidate()
            self.highlightTimer = nil
            self.setHighlighted(false, animated: true)
        }

        /// While on screen, every 0.5 s: when the time reads differently now, the row asks to be updated.
        private func updateTimeTimer() {
            if self.hierarchyTrackingLayer.isInHierarchy && self.component != nil {
                if self.timeTimer == nil {
                    let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        if newsPostTimeText(component: component) != self.renderedTimeText {
                            self.state?.updated(transition: .immediate)
                        }
                    }, queue: Queue.mainQueue())
                    self.timeTimer = timer
                    timer.start()
                }
            } else {
                self.timeTimer?.invalidate()
                self.timeTimer = nil
            }
        }

        /// The compact row (Feed2's): the channel line, up to three lines of text and a thumbnail on the right.
        private func updateCompact(component: NewsFeedPostComponent, availableSize: CGSize, timeText: String, transition: ComponentTransition) -> (CGSize, CGRect, NSAttributedString) {
            let theme = component.theme
            if let expandedContentView = self.expandedContentView {
                // Back to compact: the expanded content fades out as the compact text and thumbnail come back.
                self.expandedContentView = nil
                transition.setAlpha(view: expandedContentView, alpha: 0.0, completion: { [weak expandedContentView] _ in
                    expandedContentView?.removeFromSuperview()
                })
            }
            // Back to compact: a flight into the floating avatar is over. A morph turns the avatar back from where it
            // is; an immediate switch drops the rest of it.
            if let handOff = self.avatarHandOff {
                self.avatarHandOff = nil
                self.avatarFlight += 1
                if let floatingView = handOff.floatingView, floatingView.landingRow === self {
                    floatingView.landingRow = nil
                    if !self.floatingAvatarViews.contains(where: { $0 === floatingView }) {
                        floatingView.isHidden = false
                    }
                }
                if !self.isMorphing {
                    self.avatar.view?.layer.removeAnimation(forKey: "transform.scale")
                    self.avatar.view?.layer.removeAnimation(forKey: "opacity")
                }
            }
            if let avatarView = self.avatar.view {
                avatarView.isHidden = false
                avatarView.alpha = 1.0
            }
            for view in [self.text.view, self.thumbnailView, self.videoLabel] {
                if let view {
                    transition.setAlpha(view: view, alpha: 1.0)
                }
            }
            let thumbnail = newsPostThumbnail(component.messages)
            let textWidth = newsPostTextWidth(width: availableSize.width, hasThumbnail: thumbnail != nil)

            let timeSize = self.time.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: timeText, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )

            var credibilitySize = CGSize()
            if component.peer.isVerified {
                credibilitySize = self.credibilityIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .verified(fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, sizeType: .compact),
                        isVisibleForAnimations: false,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 16.0, height: 16.0)
                )
            }

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: newsPostTitleMaxWidth(textWidth: textWidth, credibilityWidth: credibilitySize.width, timeWidth: timeSize.width), height: 100.0)
            )

            // Three lines hold under one character per point of width (the narrowest glyphs are 3.5 pt wide); twice
            // the width leaves room for characters of several UTF-16 units.
            let postText = newsPostText(component: component, maxLength: Int(textWidth * 2.0))
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: theme.list.mediaPlaceholderColor,
                    text: .plain(postText),
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.12,
                    displaysAsynchronously: false
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 1000.0)
            )

            // Feed2's geometry (FeedRow.swift:379-460) with our fonts.
            let layout = newsPostRowLayout(width: availableSize.width, titleSize: titleSize, credibilitySize: credibilitySize.width > 0.0 ? credibilitySize : nil, timeSize: timeSize, textSize: textSize, hasThumbnail: thumbnail != nil, screenScale: UIScreenScale)

            let _ = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(AvatarComponent(context: component.context, theme: theme, peer: component.peer, size: layout.avatar.size, synchronousLoad: component.loading.isSynchronous)),
                environment: {},
                containerSize: layout.avatar.size
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.lensView.addSubview(avatarView)
                }
                if self.isMorphing {
                    avatarView.frame = layout.avatar
                } else {
                    transition.setFrame(view: avatarView, frame: layout.avatar)
                }
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.lensView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: layout.title)
            }
            if let credibilityView = self.credibilityIcon.view {
                if let credibilityFrame = layout.credibility {
                    if credibilityView.superview == nil {
                        self.lensView.addSubview(credibilityView)
                    }
                    credibilityView.isHidden = false
                    transition.setFrame(view: credibilityView, frame: credibilityFrame)
                } else {
                    credibilityView.isHidden = true
                }
            }
            if let timeView = self.time.view {
                if timeView.superview == nil {
                    self.lensView.addSubview(timeView)
                }
                transition.setFrame(view: timeView, frame: layout.time)
            }
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.lensView.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: layout.text)
            }

            if let (message, media) = thumbnail, let thumbnailFrame = layout.thumbnail {
                // Coming back (hidden while expanded), or never laid out (a row made expanded has it at .zero), the
                // thumbnail is placed rather than moved, with its own corners. A morph back animates it from where the
                // picture is (`morph`).
                let appears = self.thumbnailView.isHidden || self.thumbnailView.bounds.isEmpty
                self.thumbnailView.isHidden = false
                if appears {
                    self.thumbnailView.layer.cornerRadius = NewsPostRowMetrics.thumbnailCornerRadius
                }
                (appears ? ComponentTransition.immediate : transition).setFrame(view: self.thumbnailView, frame: thumbnailFrame)
                var dimensions = thumbnailFrame.size
                var videoDuration: Double?
                switch media {
                case let .image(image):
                    if let largest = largestImageRepresentation(image.representations) {
                        dimensions = largest.dimensions.cgSize
                    }
                    if self.thumbnailMediaId != media.mediaId {
                        self.thumbnailMediaId = media.mediaId
                        self.thumbnailView.setSignal(mediaGridMessagePhoto(account: component.context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 188.0, height: 188.0)), attemptSynchronously: false)
                    }
                case let .video(file):
                    if let fileDimensions = file.dimensions {
                        dimensions = fileDimensions.cgSize
                    }
                    if !file.isAnimated, let duration = file.duration, duration > 0.0 {
                        videoDuration = duration
                    }
                    if self.thumbnailMediaId != media.mediaId {
                        self.thumbnailMediaId = media.mediaId
                        // Not `mediaGridMessageVideo(postbox:)`: `PostboxImportCheck` rejects `.postbox` access here.
                        self.thumbnailView.setSignal(chatMessageVideoThumbnail(account: component.context.account, userLocation: .peer(message.id.peerId), fileReference: .message(message: MessageReference(message._asMessage()), media: file)), attemptSynchronously: false)
                    }
                }
                // The whole picture, covering the square (`newsThumbnailDrawingSize`): the layer shows its centre at
                // rest, as the square drawing does, and a mode morph uncrops it into the gallery's photo. A panorama
                // keeps the square drawing, and its morph fades.
                let wholeDrawingSize = newsThumbnailDrawingSize(dimensions: dimensions, square: thumbnailFrame.size)
                self.thumbnailDrawsWholePicture = wholeDrawingSize != nil
                let drawingSize = wholeDrawingSize ?? thumbnailFrame.size
                let makeLayout = self.thumbnailView.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(drawingSize), boundingSize: drawingSize, intrinsicInsets: UIEdgeInsets()))
                apply()

                if let videoDuration {
                    // A text shadow, not a layer shadow: no offscreen pass for every video row while scrolling.
                    self.videoLabel.attributedText = newsVideoDurationString(duration: videoDuration)
                    let labelSize = self.videoLabel.sizeThatFits(CGSize(width: thumbnailFrame.width, height: 100.0))
                    self.videoLabel.frame = newsVideoLabelFrame(pictureFrame: thumbnailFrame, labelSize: labelSize, inset: NewsPostRowMetrics.videoLabelInset)
                    self.videoLabel.isHidden = false
                } else {
                    self.videoLabel.isHidden = true
                }
            } else {
                self.thumbnailView.isHidden = true
                self.thumbnailMediaId = nil
                self.thumbnailDrawsWholePicture = false
                self.videoLabel.isHidden = true
            }

            return (CGSize(width: availableSize.width, height: layout.height), layout.separator, postText)
        }

        /// The expanded post (Threads/X): the 36 pt avatar, the channel line with the views and time, the bubble's
        /// content and the gallery. The avatar, name, badge and time are the compact row's own views moved into
        /// place, so a switch between the modes morphs them.
        private func updateExpanded(component: NewsFeedPostComponent, content: NewsFeedPostExpandedContent, availableSize: CGSize, timeText: String, transition: ComponentTransition) -> (CGSize, CGRect, NSAttributedString) {
            let metrics = NewsExpandedPostMetrics.self
            let theme = component.theme
            let width = availableSize.width
            let contentX = metrics.contentX(leftInset: 0.0)
            let contentWidth = metrics.contentWidth(width: width, leftInset: 0.0, rightInset: 0.0)
            let avatarFrame = CGRect(x: metrics.avatarInset, y: metrics.avatarTop, width: metrics.avatarSize, height: metrics.avatarSize)

            let contentView: NewsExpandedPostContentView
            let contentFrameTransition: ComponentTransition
            if let current = self.expandedContentView {
                contentView = current
                contentFrameTransition = transition
            } else {
                contentFrameTransition = .immediate
                contentView = NewsExpandedPostContentView(frame: CGRect())
                contentView.alpha = 0.0
                self.lensView.insertSubview(contentView, at: 0)
                self.expandedContentView = contentView
                contentView.galleryScrolled = { [weak self] in
                    guard let self else {
                        return
                    }
                    for view in self.floatingAvatarViews {
                        view.obstacleChanged()
                    }
                }
            }
            transition.setAlpha(view: contentView, alpha: 1.0)
            for view in [self.text.view, self.thumbnailView, self.videoLabel] {
                if let view {
                    transition.setAlpha(view: view, alpha: 0.0)
                }
            }

            let timeSize = self.time.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: timeText, font: Font.medium(11.0), textColor: theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            // Show more's reveal crossfades the cut's last lines on the list's colour, which is what lies under the row
            // except on a fresh row's tint and under the row's highlight: shown, still fading, or about to flash for
            // the tap on the text that shows the rest (`isRunningTap`).
            let revealBacking = component.fresh == nil && !self.isRunningTap && self.revealView.highlightView.superview == nil ? theme.list.plainBackgroundColor : nil
            let layout = contentView.update(component: component, content: content, width: width, timeSize: timeSize, synchronousLoad: component.loading.isSynchronous, revealBacking: revealBacking, transition: transition)
            contentFrameTransition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: layout.height)))

            var credibilitySize = CGSize()
            if component.peer.isVerified {
                credibilitySize = self.credibilityIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .verified(fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, sizeType: .compact),
                        isVisibleForAnimations: false,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 16.0, height: 16.0)
                )
            }
            var titleMaxWidth = contentWidth - layout.metaWidth - metrics.headerSpacing * 2.0
            if credibilitySize.width > 0.0 {
                titleMaxWidth -= credibilitySize.width + metrics.headerSpacing
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.semibold(14.0), textColor: newsChannelNameColor(peer: component.peer, context: component.context, theme: theme))),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, titleMaxWidth), height: 100.0)
            )

            let lineMidY = metrics.headerTop + metrics.headerHeight * 0.5
            func centred(x: CGFloat, size: CGSize) -> CGRect {
                return CGRect(origin: CGPoint(x: x, y: floorToScreenPixels(lineMidY - size.height * 0.5)), size: size)
            }
            let _ = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(AvatarComponent(context: component.context, theme: theme, peer: component.peer, size: avatarFrame.size, synchronousLoad: component.loading.isSynchronous)),
                environment: {},
                containerSize: avatarFrame.size
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.lensView.addSubview(avatarView)
                }
                // The list draws an expanded row's avatar, floating over its channel's run (the row's attachment); the
                // row keeps its own in its slot, hidden, so a switch back to compact finds it there. In a morph from
                // compact it flies into the floating one first (`aimAvatarHandOff`).
                self.layoutAvatarFrame = avatarFrame
                if let handedOffAvatarFrame = self.handedOffAvatarFrame {
                    avatarView.isHidden = false
                    avatarView.frame = handedOffAvatarFrame
                } else if let handOff = self.avatarHandOff {
                    // In flight: it lands where the floating one is, not in the slot.
                    avatarView.isHidden = false
                    avatarView.frame = handOff.target ?? avatarFrame
                } else {
                    // Shown for the morph from compact, whose flight `morph` starts; hidden otherwise.
                    avatarView.isHidden = !self.isMorphing
                    avatarView.frame = avatarFrame
                }
            }
            let titleFrame = centred(x: contentX, size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.lensView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let credibilityView = self.credibilityIcon.view {
                if credibilitySize.width > 0.0 {
                    if credibilityView.superview == nil {
                        self.lensView.addSubview(credibilityView)
                    }
                    credibilityView.isHidden = false
                    transition.setFrame(view: credibilityView, frame: centred(x: titleFrame.maxX + metrics.headerSpacing, size: credibilitySize))
                } else {
                    credibilityView.isHidden = true
                }
            }
            if let timeView = self.time.view {
                if timeView.superview == nil {
                    self.lensView.addSubview(timeView)
                }
                transition.setFrame(view: timeView, frame: layout.timeFrame)
            }

            // The separator runs under the content column, from its left edge to the right inset.
            let pixel = 1.0 / UIScreenScale
            let separator = CGRect(x: contentX, y: layout.height - pixel, width: max(0.0, width - contentX - metrics.rightInset), height: pixel)
            let postText = newsPostText(component: component, maxLength: Int(contentWidth * 2.0))
            return (CGSize(width: width, height: layout.height), separator, postText)
        }

        /// What a mode morph starts from: the row's geometry as on screen before the new layout. A morph that
        /// interrupts the one before it starts where that one is, not where it was going.
        private struct MorphOrigin {
            /// The avatar as on screen: the row's own (frame, scale included, and alpha); on an expanded row, the
            /// floating one over it, with its presented opacity; or nothing there (a later post of a run: its slot,
            /// alpha 0).
            let avatar: (frame: CGRect, alpha: CGFloat)?
            /// The compact text while it shows or is still leaving: its frame (its scale included) and alpha.
            let text: (frame: CGRect, alpha: CGFloat)?
            /// The thumbnail while it shows or is still travelling: its frame, alpha and corner radius as on screen.
            let thumbnail: (frame: CGRect, alpha: CGFloat, cornerRadius: CGFloat)?
            /// "▶ 0:12" as on screen, while the thumbnail shows with it.
            let videoLabel: (frame: CGRect, alpha: CGFloat)?
            let bubbleTextOrigin: CGPoint?
            let galleryItemFrame: CGRect?
            /// The bubble's font size: the compact text scales to it.
            let bubbleFontSize: CGFloat?
            /// The expanded content on its way out (a morph to compact): blurred as it fades.
            weak var expandedContentView: NewsExpandedPostContentView?
        }

        /// A view's frame and alpha as on screen now: its presentation while an animation runs on it, else its own.
        private func presented(_ view: UIView) -> (frame: CGRect, alpha: CGFloat) {
            if let keys = view.layer.animationKeys(), !keys.isEmpty, let presentation = view.layer.presentation() {
                return (presentation.frame, CGFloat(presentation.opacity))
            }
            return (view.frame, view.alpha)
        }

        private func morphOrigin() -> MorphOrigin {
            var bubbleTextOrigin: CGPoint?
            var galleryItemFrame: CGRect?
            if let contentView = self.expandedContentView, contentView.superview != nil {
                bubbleTextOrigin = contentView.bubbleTextOrigin.map { contentView.convert($0, to: self.lensView) }
                galleryItemFrame = contentView.firstGalleryItemFrame.map { contentView.convert($0, to: self.lensView) }
            }
            var text: (frame: CGRect, alpha: CGFloat)?
            if let textView = self.text.view, textView.superview != nil, !textView.isHidden {
                let presented = self.presented(textView)
                if presented.alpha > 0.0 {
                    text = presented
                }
            }
            var thumbnail: (frame: CGRect, alpha: CGFloat, cornerRadius: CGFloat)?
            var videoLabel: (frame: CGRect, alpha: CGFloat)?
            if !self.thumbnailView.isHidden {
                let presented = self.presented(self.thumbnailView)
                if presented.alpha > 0.0 {
                    let layer = self.thumbnailView.layer
                    let cornerRadius = layer.animation(forKey: "cornerRadius") != nil ? (layer.presentation()?.cornerRadius ?? layer.cornerRadius) : layer.cornerRadius
                    thumbnail = (presented.frame, presented.alpha, cornerRadius)
                    if !self.videoLabel.isHidden {
                        videoLabel = self.presented(self.videoLabel)
                    }
                }
            }
            var avatar: (frame: CGRect, alpha: CGFloat)?
            if let avatarView = self.avatar.view {
                if !avatarView.isHidden {
                    avatar = self.presented(avatarView)
                } else if let floatingView = self.floatingAvatarViews.first(where: { !$0.isHidden }) {
                    avatar = (floatingView.presentedAvatarFrame(in: self.lensView), CGFloat(floatingView.layer.presentation()?.opacity ?? Float(floatingView.alpha)))
                } else {
                    avatar = (avatarView.frame, 0.0)
                }
            }
            return MorphOrigin(
                avatar: avatar,
                text: text,
                thumbnail: thumbnail,
                videoLabel: videoLabel,
                bubbleTextOrigin: bubbleTextOrigin,
                galleryItemFrame: galleryItemFrame,
                bubbleFontSize: self.component?.expanded?.presentationData.chatFontSize.baseDisplaySize,
                expandedContentView: self.expandedContentView
            )
        }

        /// Blurs a layer from one radius to another over the morph; a blur ending at 0 removes its filter afterwards.
        private func animateBlur(layer: CALayer, from: CGFloat, to: CGFloat, duration: Double) {
            guard let filter = CALayer.blur() else {
                return
            }
            filter.setValue(to as NSNumber, forKey: "inputRadius")
            layer.filters = [filter]
            let animation = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            animation.fromValue = from as NSNumber
            animation.toValue = to as NSNumber
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.isRemovedOnCompletion = true
            if to == 0.0 {
                animation.delegate = LensBlurCleanup(layer: layer)
            }
            layer.add(animation, forKey: "newsMorphBlur")
        }

        /// The morph to compact: the avatar is drawn at its new size already (the component re-rendered it), and it
        /// scales from the old size over the new drawing and travels from the old centre, so nothing is re-laid out
        /// mid-flight.
        private func morphAvatar(from oldFrame: CGRect, transition: ComponentTransition) {
            guard let avatarView = self.avatar.view, oldFrame.width > 0.0 else {
                return
            }
            let newFrame = avatarView.frame
            transition.animatePosition(view: avatarView, from: CGPoint(x: oldFrame.midX, y: oldFrame.midY), to: CGPoint(x: newFrame.midX, y: newFrame.midY))
            transition.animateScale(view: avatarView, from: oldFrame.width / max(1.0, newFrame.width), to: 1.0)
        }

        /// The own avatar's flight in a morph from compact (`aimAvatarHandOff`).
        private struct AvatarHandOff {
            /// Where the own avatar starts, in `lensView`, and how opaque it is.
            let origin: CGRect
            let originAlpha: CGFloat
            let transition: ComponentTransition
            /// The floating avatar it lands on and where (in `lensView`). Without one (a later post of a run, whose
            /// avatar floats over another row) it fades out in the layout's slot.
            weak var floatingView: NewsFloatingAvatarView?
            /// The floating avatar is new, so nothing has drawn it yet: it stays hidden until the landing. One already
            /// on screen (a run the row joins) stays, and the own avatar slides under it.
            var hidesFloatingView = false
            var target: CGRect?
        }

        /// Aims the own avatar's flight, in a morph from compact, at the floating avatar the list has just placed over
        /// this row (in the row's slot, stuck at the header's edge, or parked at its run's end), so the hand-over at
        /// the end is in place. CoreList makes and places attachments only after the row's update
        /// (`resolveAttachments` ends `buildWindow`). It places them again on every pass and display-area change of
        /// the turn (the header's fold) and tells the row each time. Nothing is committed in between, so each
        /// placement re-aims. Once the flight has been committed it is on screen and it stands, and once it is over it
        /// waits for its completion: a later move is caught up at the hand-over (`takeOver`). Invariant: during the
        /// flight nothing but this method moves the own avatar's model frame (an update keeps it at `target`), because
        /// the swap lands a couple of frames after the render server's end.
        private func aimAvatarHandOff() {
            guard var handOff = self.avatarHandOff, let avatarView = self.avatar.view, let layoutAvatarFrame = self.layoutAvatarFrame else {
                return
            }
            if handOff.target != nil {
                // Core Animation resolves an animation's begin time at the commit: an aimed flight with a resolved one
                // is on screen, and one with no animation left has landed.
                guard let scale = avatarView.layer.animation(forKey: "transform.scale"), scale.beginTime == 0.0 else {
                    return
                }
            }
            // Never committed: nothing has drawn it yet. A view already on screen (a run the row joins) is reused.
            let freshView = self.floatingAvatarViews.first(where: { $0.layer.presentation() == nil })
            let floatingView = freshView ?? self.floatingAvatarViews.first
            let target = floatingView.map { $0.convert($0.avatarFrame, to: self.lensView) } ?? layoutAvatarFrame
            let hidesFloatingView = freshView != nil
            if handOff.target == target && handOff.floatingView === floatingView && handOff.hidesFloatingView == hidesFloatingView {
                return
            }
            if let previous = handOff.floatingView, previous !== floatingView, previous.landingRow === self {
                previous.landingRow = nil
            }
            handOff.floatingView = floatingView
            handOff.hidesFloatingView = hidesFloatingView
            handOff.target = target
            self.avatarHandOff = handOff
            if hidesFloatingView {
                floatingView?.landingRow = self
            }
            self.avatarFlight += 1
            let flight = self.avatarFlight
            let transition = handOff.transition
            avatarView.isHidden = false
            avatarView.frame = target
            transition.animatePosition(view: avatarView, from: CGPoint(x: handOff.origin.midX, y: handOff.origin.midY), to: CGPoint(x: target.midX, y: target.midY))
            transition.animateScale(view: avatarView, from: handOff.origin.width / max(1.0, target.width), to: 1.0, completion: { [weak self] _ in
                guard let self, self.avatarFlight == flight else {
                    return
                }
                self.finishAvatarHandOff()
            })
            let alpha: CGFloat = floatingView != nil ? 1.0 : 0.0
            avatarView.alpha = alpha
            if handOff.originAlpha != alpha {
                transition.animateAlpha(view: avatarView, from: handOff.originAlpha, to: alpha)
            } else {
                avatarView.layer.removeAnimation(forKey: "opacity")
            }
        }

        /// The flight has landed: the floating avatar takes over in this frame (catching up if the list moved it since)
        /// and the row's own hides. Pressed or lifted into a context menu meanwhile, the own one stays as the stand-in,
        /// as a press's hand-off does.
        private func finishAvatarHandOff() {
            guard let handOff = self.avatarHandOff, let avatarView = self.avatar.view else {
                return
            }
            self.avatarHandOff = nil
            let floatingView = handOff.floatingView
            if let floatingView, floatingView.landingRow === self {
                floatingView.landingRow = nil
            }
            guard self.component?.displayMode == .expanded else {
                return
            }
            avatarView.alpha = 1.0
            if self.isExtracted || self.isPressing, floatingView != nil {
                self.handedOffAvatarFrame = avatarView.frame
            } else {
                if let floatingView {
                    if handOff.hidesFloatingView {
                        let landed: CGRect
                        if let own = avatarView.layer.presentation(), let target = floatingView.layer.presentation() {
                            landed = own.convert(own.bounds, to: target)
                        } else {
                            landed = avatarView.convert(avatarView.bounds, to: floatingView)
                        }
                        floatingView.takeOver(from: landed)
                    }
                    if !self.floatingAvatarViews.contains(where: { $0 === floatingView }) {
                        // Bound to another row since (a scroll during the flight), which kept it hidden for this
                        // landing.
                        floatingView.isHidden = false
                    }
                }
                avatarView.isHidden = true
                if let layoutAvatarFrame = self.layoutAvatarFrame {
                    avatarView.frame = layoutAvatarFrame
                }
            }
            self.updateFloatingAvatarVisibility()
        }

        /// The compact and expanded layouts morph into each other: the avatar, name, badge and time are shared
        /// views whose frames animate; the compact text scales (15 pt to the bubble's size) and travels to where the
        /// bubble's text starts while the bubble fades in over it, and the thumbnail and the gallery's first photo
        /// travel as one picture. The reverse plays the same paths backwards. `origin` is the row as on screen before
        /// the new layout was applied: a morph interrupting another continues from where it is.
        private func morph(from origin: MorphOrigin, to displayMode: NewsFeedDisplayMode, transition: ComponentTransition) {
            let bubbleFontSize = self.component?.expanded?.presentationData.chatFontSize.baseDisplaySize ?? origin.bubbleFontSize ?? 17.0
            let textScale = bubbleFontSize / 15.0
            let blurRadius: CGFloat = 8.0
            var duration = 0.4
            // The pass's own length: what must end with its spring (the thumbnail's dissolve) runs this long.
            var travelDuration = 0.5
            if case let .curve(value, _) = transition.animation {
                duration = min(value, 0.45)
                travelDuration = value
            }
            switch displayMode {
            case .expanded:
                guard let contentView = self.expandedContentView else {
                    return
                }
                if let oldAvatar = origin.avatar {
                    // The own avatar flies from where it is into the floating one, which the list makes and places only
                    // after this update: aimed at the slot for now, then at each placement of the turn.
                    self.avatarHandOff = AvatarHandOff(origin: oldAvatar.frame, originAlpha: oldAvatar.alpha, transition: transition)
                    self.aimAvatarHandOff()
                }
                self.updateFloatingAvatarVisibility()
                // The content blurs in, all but the gallery's first photo: the picture the thumbnail brings travels
                // beneath it (`morphBlurLayers`).
                for layer in contentView.morphBlurLayers {
                    self.animateBlur(layer: layer, from: blurRadius, to: 0.0, duration: duration)
                }
                if let textView = self.text.view {
                    self.animateBlur(layer: textView.layer, from: 0.0, to: blurRadius, duration: duration)
                }
                if let textView = self.text.view, let text = origin.text, let target = contentView.bubbleTextOrigin.map({ contentView.convert($0, to: self.lensView) }) {
                    // Top-left corners meet: the scale is about the centre, so the centre travels to where the
                    // scaled text's centre would be. The text keeps its compact layout (`bounds`); on screen it may
                    // still be scaled from an interrupted morph back.
                    let size = textView.bounds.size
                    let targetCenter = CGPoint(x: target.x + size.width * textScale * 0.5, y: target.y + size.height * textScale * 0.5)
                    textView.alpha = 0.0
                    transition.animatePosition(view: textView, from: CGPoint(x: text.frame.midX, y: text.frame.midY), to: targetCenter)
                    transition.animateScale(view: textView, from: text.frame.width / max(1.0, size.width), to: textScale)
                    transition.animateAlpha(view: textView, from: text.alpha, to: 0.0)
                } else if let textView = self.text.view {
                    textView.alpha = 0.0
                }
                let target = contentView.firstGalleryItemFrame.map { contentView.convert($0, to: self.lensView) }
                if let thumbnail = origin.thumbnail, let target, self.thumbnailDrawsWholePicture, self.thumbnailView.layer.contents != nil, let thumbnailMediaId = self.thumbnailMediaId, contentView.firstGalleryMediaId == thumbnailMediaId {
                    // One picture travels. The thumbnail (above) and the gallery's first photo (beneath) take one path
                    // on one spring, from its compact frame or from wherever an interrupted morph back has it
                    // (`setFrame` resumes a frame in flight), each drawing the whole picture covering its frame, so
                    // every frame shows one crop. The thumbnail holds over the first half, while the photo may still be
                    // loading, then dissolves into it. Its model alpha is 0 from here, so the end of the animations is
                    // the end state: the render server drops a pass's animations frames before their completions run.
                    self.thumbnailTravelsWithPhoto = true
                    self.thumbnailView.isHidden = false
                    self.thumbnailView.alpha = 0.0
                    self.thumbnailView.layer.animateKeyframes(values: [thumbnail.alpha as NSNumber, thumbnail.alpha as NSNumber, 0.0 as NSNumber], keyTimes: [0.0, 0.55, 1.0], duration: travelDuration, keyPath: "opacity")
                    transition.setFrame(view: self.thumbnailView, frame: target, completion: { [weak self] finished in
                        guard let self, finished, self.component?.displayMode == .expanded else {
                            return
                        }
                        // Already transparent: cleanup only.
                        self.thumbnailView.isHidden = true
                    })
                    transition.setCornerRadius(layer: self.thumbnailView.layer, cornerRadius: NewsExpandedPostMetrics.galleryCornerRadius)
                    contentView.morphFirstGalleryItem(from: thumbnail.frame, in: self.lensView, cornerRadius: thumbnail.cornerRadius, labelInset: NewsPostRowMetrics.videoLabelInset, transition: transition)
                    if let label = origin.videoLabel {
                        // "▶ 0:12" rides the picture's corner, 6 pt in at the thumbnail and 8 at the photo, whole to
                        // the end, where the photo's own label (travelling the same way beneath it) is.
                        let labelFrame = newsVideoLabelFrame(pictureFrame: target, labelSize: self.videoLabel.bounds.size, inset: NewsExpandedPostMetrics.galleryLabelInset)
                        self.videoLabel.frame = labelFrame
                        transition.animatePosition(view: self.videoLabel, from: CGPoint(x: label.frame.midX, y: label.frame.midY), to: CGPoint(x: labelFrame.midX, y: labelFrame.midY))
                        self.videoLabel.alpha = 0.0
                        self.videoLabel.layer.animateKeyframes(values: [label.alpha as NSNumber, label.alpha as NSNumber, 0.0 as NSNumber], keyTimes: [0.0, 0.97, 1.0], duration: travelDuration, keyPath: "opacity")
                    } else {
                        self.videoLabel.alpha = 0.0
                    }
                } else {
                    // No picture in common (no gallery, another first item), a panorama drawn square, or no image yet:
                    // the thumbnail and its label fade where they are (`updateExpanded`'s fade, model alpha 0).
                    self.thumbnailTravelsWithPhoto = false
                    self.videoLabel.alpha = 0.0
                }
                contentView.alpha = 1.0
                transition.animateAlpha(view: contentView, from: 0.0, to: 1.0)
            case .compact:
                // The floating avatar over this row becomes the row's own: hidden at once (the list fades it out with
                // its run, or the run's next post takes it over), with the own one starting where it was on screen.
                for view in self.floatingAvatarViews {
                    view.isHidden = true
                }
                if let oldAvatar = origin.avatar, let avatarView = self.avatar.view {
                    self.morphAvatar(from: oldAvatar.frame, transition: transition)
                    if oldAvatar.alpha < 1.0 {
                        // A later post of a run had no avatar on screen: it fades in as it shrinks into place.
                        transition.animateAlpha(view: avatarView, from: oldAvatar.alpha, to: 1.0)
                    } else {
                        avatarView.layer.removeAnimation(forKey: "opacity")
                    }
                }
                if let leaving = origin.expandedContentView {
                    for layer in leaving.morphBlurLayers {
                        self.animateBlur(layer: layer, from: 0.0, to: blurRadius, duration: duration)
                    }
                }
                if let textView = self.text.view {
                    self.animateBlur(layer: textView.layer, from: blurRadius, to: 0.0, duration: duration)
                }
                if let textView = self.text.view {
                    // From where the bubble's text starts, at the bubble's size; or from wherever an interrupted
                    // morph out has it.
                    let textFrame = textView.frame
                    var from: (center: CGPoint, scale: CGFloat, alpha: CGFloat) = (CGPoint(x: textFrame.midX, y: textFrame.midY), 1.0, 0.0)
                    if let text = origin.text {
                        from = (CGPoint(x: text.frame.midX, y: text.frame.midY), text.frame.width / max(1.0, textFrame.width), text.alpha)
                    } else if let origin = origin.bubbleTextOrigin {
                        from = (CGPoint(x: origin.x + textFrame.width * textScale * 0.5, y: origin.y + textFrame.height * textScale * 0.5), textScale, 0.0)
                    }
                    textView.alpha = 1.0
                    transition.animatePosition(view: textView, from: from.center, to: CGPoint(x: textFrame.midX, y: textFrame.midY))
                    transition.animateScale(view: textView, from: from.scale, to: 1.0)
                    transition.animateAlpha(view: textView, from: from.alpha, to: 1.0)
                }
                if !self.thumbnailView.isHidden {
                    let thumbnailFrame = self.thumbnailView.frame
                    let leaving = origin.expandedContentView
                    var sharesPicture = self.thumbnailDrawsWholePicture && self.thumbnailMediaId != nil && leaving?.firstGalleryMediaId == self.thumbnailMediaId
                    // Where the picture is: the thumbnail still in flight (a morph out turned around), else the
                    // gallery's first photo while it is this picture and in sight. A gallery scrolled away gets a fade
                    // at home, and so does a thumbnail the morph out left fading where it was, over no photo.
                    var from: (frame: CGRect, alpha: CGFloat, cornerRadius: CGFloat)?
                    if let thumbnail = origin.thumbnail {
                        from = thumbnail
                        sharesPicture = sharesPicture && self.thumbnailTravelsWithPhoto
                    } else if sharesPicture, let galleryItemFrame = origin.galleryItemFrame, galleryItemFrame.intersects(self.lensView.bounds) {
                        from = (galleryItemFrame, 1.0, NewsExpandedPostMetrics.galleryCornerRadius)
                    }
                    self.thumbnailView.layer.removeAnimation(forKey: "opacity")
                    self.thumbnailView.alpha = 1.0
                    if let from {
                        var landed: ((Bool) -> Void)?
                        if sharesPicture {
                            // In the photo's place, opaque from the first frame, showing the same crop with the photo's
                            // own pixels (sharper than its 82 pt drawing, and all a row that was never compact has
                            // yet). The photo goes at once, so nothing is left behind. Its own drawing comes back on
                            // landing.
                            if let photo = leaving?.firstGalleryItemContents {
                                let layer = self.thumbnailView.layer
                                layer.contents = photo
                                landed = { [weak self, weak layer] finished in
                                    guard let self, finished, let layer, (layer.contents as AnyObject?) === (photo as AnyObject), let own = self.thumbnailView.image?.cgImage else {
                                        return
                                    }
                                    layer.contents = own
                                }
                            }
                            leaving?.hideFirstGalleryItem()
                        } else {
                            transition.animateAlpha(view: self.thumbnailView, from: from.alpha, to: 1.0)
                        }
                        transition.animatePosition(view: self.thumbnailView, from: CGPoint(x: from.frame.midX, y: from.frame.midY), to: CGPoint(x: thumbnailFrame.midX, y: thumbnailFrame.midY), completion: landed)
                        transition.animateBoundsSize(view: self.thumbnailView, from: from.frame.size, to: thumbnailFrame.size)
                        self.thumbnailView.layer.cornerRadius = from.cornerRadius
                        transition.setCornerRadius(layer: self.thumbnailView.layer, cornerRadius: NewsPostRowMetrics.thumbnailCornerRadius)
                    } else {
                        transition.animateAlpha(view: self.thumbnailView, from: 0.0, to: 1.0)
                    }
                    if !self.videoLabel.isHidden {
                        // "▶ 0:12" rides the corner home, from where it is in flight or from the photo's label; with no
                        // picture in common it fades in with the thumbnail.
                        let labelFrame = self.videoLabel.frame
                        self.videoLabel.layer.removeAnimation(forKey: "opacity")
                        self.videoLabel.alpha = 1.0
                        if let from, sharesPicture {
                            let start = origin.videoLabel?.frame ?? newsVideoLabelFrame(pictureFrame: from.frame, labelSize: labelFrame.size, inset: NewsExpandedPostMetrics.galleryLabelInset)
                            transition.animatePosition(view: self.videoLabel, from: CGPoint(x: start.midX, y: start.midY), to: CGPoint(x: labelFrame.midX, y: labelFrame.midY))
                        } else {
                            transition.animateAlpha(view: self.videoLabel, from: origin.videoLabel?.alpha ?? 0.0, to: 1.0)
                        }
                    }
                }
            }
        }

        /// A pass that changes the row's height (a mode morph, Show more) lays everything in it out at the new height
        /// at once, while the host animates this view's frame on that pass's transition
        /// (`CoreListComponentItemView.update`). Clipped to its bounds until the transition ends, the row reveals a
        /// taller layout as it grows and cuts the old one as it shrinks. Unclipped, it would
        /// draw over the rows below, which ride the same spring and draw nothing behind themselves. Only while the
        /// height animates: at rest a handed-off avatar may stand partly outside the row (`handOffAvatar`).
        private func clipWhileHeightAnimates(transition: ComponentTransition) {
            self.heightClipGeneration += 1
            let generation = self.heightClipGeneration
            self.clipsToBounds = true
            transition.attachAnimation(view: self, id: "newsRowHeightClip", completion: { [weak self] _ in
                guard let self, self.heightClipGeneration == generation else {
                    return
                }
                self.clipsToBounds = false
            })
        }

        /// A mode morph is landing: the row takes no tap, highlight, long press or new swipe until it has. Its content may be drawn far from its model
        /// frame meanwhile (a swipe's slide back), and a press would hand the avatar over mid-flight. The list's scroll
        /// and the pager still begin on it (`NewsPostRevealView` refuses only its own recognizers). Whatever stops the
        /// animation lifts the gate, a newer morph excepted: a row taken off screen loses its animations at once and
        /// is never left untouchable.
        private func suspendInteractionWhileMorphing(transition: ComponentTransition) {
            self.morphInFlightGeneration += 1
            let generation = self.morphInFlightGeneration
            self.isMorphInFlight = true
            self.revealView.suspendsInteraction = true
            transition.attachAnimation(view: self, id: "newsRowMorphInFlight", completion: { [weak self] _ in
                guard let self, self.morphInFlightGeneration == generation else {
                    return
                }
                self.isMorphInFlight = false
                self.revealView.suspendsInteraction = false
            })
        }

        func update(component: NewsFeedPostComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            let isFirstUpdate = self.component == nil
            let morphs = !isFirstUpdate && self.component?.displayMode != component.displayMode && !transition.animation.isImmediate
            let origin = morphs ? self.morphOrigin() : nil
            self.isMorphing = morphs
            defer {
                self.isMorphing = false
            }
            self.component = component
            self.state = state
            let theme = component.theme
            let timeText = newsPostTimeText(component: component)
            self.renderedTimeText = timeText
            defer {
                self.updateTimeTimer()
            }

            let rowSize: CGSize
            let separatorFrame: CGRect
            let postText: NSAttributedString
            if component.displayMode == .expanded, let expanded = component.expanded {
                (rowSize, separatorFrame, postText) = self.updateExpanded(component: component, content: expanded, availableSize: availableSize, timeText: timeText, transition: transition)
            } else {
                (rowSize, separatorFrame, postText) = self.updateCompact(component: component, availableSize: availableSize, timeText: timeText, transition: transition)
            }
            if let origin {
                self.morph(from: origin, to: component.displayMode, transition: transition)
                self.suspendInteractionWhileMorphing(transition: transition)
            }
            if let laidOutHeight = self.laidOutHeight, abs(laidOutHeight - rowSize.height) > 0.5, !transition.animation.isImmediate {
                self.clipWhileHeightAnimates(transition: transition)
            }
            self.laidOutHeight = rowSize.height

            self.separatorLayer.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
            transition.setFrame(layer: self.separatorLayer, frame: separatorFrame)
            self.updateSeparatorAlpha()
            // The row places the view; the view lays out inside it (a swipe still closing keeps sliding: the control
            // takes the new size and options once the row is back in place, and the row takes no swipe meanwhile).
            self.revealView.frame = CGRect(origin: CGPoint(), size: rowSize)
            let leftOptions = component.swipe != nil ? newsPostLeftRevealOptions(isExpanded: component.displayMode == .expanded, theme: theme, strings: component.strings) : []
            let rightOptions = component.swipe?.hasFeedbackActions == true ? newsPostRevealOptions(theme: theme, strings: component.strings) : []
            self.revealView.update(size: rowSize, leftOptions: leftOptions, rightOptions: rightOptions, highlightColor: theme.list.itemHighlightedBackgroundColor)
            let rowBounds = CGRect(origin: CGPoint(), size: rowSize)
            self.contextSourceView.frame = rowBounds
            self.extractedContainerView.frame = rowBounds
            // Where the lifted, scaled content is: the menu lays itself out around it.
            let extractedScale = View.extractedScale(width: rowSize.width)
            self.extractedContainerView.contentRect = rowBounds.insetBy(dx: floor(rowSize.width * (1.0 - extractedScale) / 2.0), dy: floor(rowSize.height * (1.0 - extractedScale) / 2.0))
            // Lifted, or on its way back, the content is the menu's to place: `finishPutBack` lays it out once home.
            if !self.isExtracted && !self.extractedContainerView.isExtractedToContextPreview {
                self.extractedContainerView.contentView.frame = rowBounds
                self.contentView.frame = rowBounds
            }
            self.lensView.frame = self.contentView.bounds

            self.accessibilityLabel = component.peer.compactDisplayTitle
            self.accessibilityValue = postText.string.isEmpty ? timeText : "\(timeText), \(postText.string)"
            if let swipe = component.swipe {
                let actions: [NewsPostSwipeAction] = (swipe.hasFeedbackActions ? newsPostSwipeActions : []) + [component.displayMode == .expanded ? .collapse : .expand]
                self.accessibilityCustomActions = actions.map { action in
                    return UIAccessibilityCustomAction(name: newsPostSwipeTitle(action, strings: component.strings), actionHandler: { [weak self] _ in
                        self?.component?.swipe?.action(action)
                        return true
                    })
                }
            } else {
                self.accessibilityCustomActions = nil
            }

            if let fresh = component.fresh {
                let blockView: NewsFreshBlockView
                if let current = self.freshBlockView {
                    blockView = current
                } else {
                    blockView = NewsFreshBlockView(frame: CGRect())
                    self.insertSubview(blockView, at: 0)
                    self.freshBlockView = blockView
                }
                blockView.frame = CGRect(origin: CGPoint(), size: rowSize)
                blockView.update(size: rowSize, segment: fresh, accentColor: theme.list.itemAccentColor)

                let clip = NewsFreshBlock.clipRect(bounds: CGRect(origin: CGPoint(), size: rowSize), isFirst: fresh.isFirst, isLast: fresh.isLast)
                let mask = (self.contentView.layer.mask as? SimpleLayer) ?? SimpleLayer()
                mask.backgroundColor = UIColor.black.cgColor
                mask.frame = clip
                mask.cornerRadius = NewsRefreshMetrics.cardCorner
                mask.cornerCurve = .continuous
                var corners: CACornerMask = []
                if fresh.isFirst {
                    corners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner])
                }
                if fresh.isLast {
                    corners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
                }
                mask.maskedCorners = corners
                self.contentView.layer.mask = mask

                if self.lensRevealTime != fresh.revealTime {
                    self.lensRevealTime = fresh.revealTime
                    if NewsFreshBlock.runsLens(createdAt: self.createdAt, segment: fresh) {
                        self.playLens(segment: fresh, scales: !component.reduceMotion)
                    }
                }
            } else {
                self.freshBlockView?.removeFromSuperview()
                self.freshBlockView = nil
                self.contentView.layer.mask = nil
                self.lensRevealTime = nil
            }
            self.separatorLayer.isHidden = component.fresh?.isLast == true
            self.updateFading(component.fading, animated: !isFirstUpdate)
            if isFirstUpdate, let appearTime = component.appearTime, NewsFeedbackTiming.playsAppear(appearTime: appearTime, now: CACurrentMediaTime()) {
                self.playReturnAppear(appearTime: appearTime, rises: !component.reduceMotion)
            }
            return rowSize
        }

        /// Content seen through a lens: magnified, blurred and faded, settling on one critically damped spring
        /// (`LensAppear`, `Motion.appear`; spec §4.3). Under Reduce Motion it does not scale.
        private func playLens(segment: NewsFreshSegment, scales: Bool) {
            let delay = NewsFreshBlock.lensDelay(now: CACurrentMediaTime(), segment: segment)
            let steps = 42
            var scale: [NSNumber] = []
            var alpha: [NSNumber] = []
            var blur: [NSNumber] = []
            for i in 0 ... steps {
                let p = NewsFreshBlock.lensProgress(NewsFreshBlock.lensSettle * Double(i) / Double(steps))
                scale.append(NewsFreshBlock.lensScale(p) as NSNumber)
                alpha.append(NewsFreshBlock.lensAlpha(p) as NSNumber)
                blur.append(NewsFreshBlock.lensBlur(p) as NSNumber)
            }
            let layer = self.lensView.layer
            func animation(_ keyPath: String, _ values: [NSNumber]) -> CAKeyframeAnimation {
                let animation = CAKeyframeAnimation(keyPath: keyPath)
                animation.values = values
                animation.duration = NewsFreshBlock.lensSettle
                animation.calculationMode = .linear
                animation.beginTime = CACurrentMediaTime() + delay
                animation.fillMode = .backwards
                animation.isRemovedOnCompletion = true
                return animation
            }
            if let filter = CALayer.blur() {
                filter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                layer.filters = [filter]
            }
            if scales {
                layer.add(animation("transform.scale", scale), forKey: "newsLensScale")
            }
            layer.add(animation("opacity", alpha), forKey: "newsLensAlpha")
            let blurAnimation = animation("filters.gaussianBlur.inputRadius", blur)
            blurAnimation.delegate = LensBlurCleanup(layer: layer)
            layer.add(blurAnimation, forKey: "newsLensBlur")
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}

/// Removes the idle blur filter once the lens has settled, so the row stops rendering offscreen.
private final class LensBlurCleanup: NSObject, CAAnimationDelegate {
    private weak var layer: CALayer?

    init(layer: CALayer) {
        self.layer = layer
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        self.layer?.filters = nil
    }
}

/// "▶ 0:12": a video's duration over its picture, white with a soft shadow (the compact row's thumbnail and the
/// expanded post's gallery).
func newsVideoDurationString(duration: Double) -> NSAttributedString {
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
    return string
}
