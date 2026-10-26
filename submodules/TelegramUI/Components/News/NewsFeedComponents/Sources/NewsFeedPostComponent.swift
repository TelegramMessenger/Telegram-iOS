import Foundation
import UIKit
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
        return chatListPreviewAttributedString(text, entities: prefix.entities, strings: component.strings, dateTimeFormat: component.dateTimeFormat, font: font, italicFont: font, textColor: theme.list.itemPrimaryTextColor, message: message._asMessage())
    }
    guard let message = component.messages.first else {
        return NSAttributedString()
    }
    // A rich message keeps its text in the attribute, so it arrives here as a preview: text, not a label.
    let (summary, isMediaLabel, _) = descriptionStringForMessage(contentSettings: component.context.currentContentSettings.with { $0 }, message: message, strings: component.strings, nameDisplayOrder: component.nameDisplayOrder, dateTimeFormat: component.dateTimeFormat, accountPeerId: component.context.account.peerId)
    return NSAttributedString(string: summary.string, font: font, textColor: isMediaLabel ? theme.list.itemSecondaryTextColor : theme.list.itemPrimaryTextColor)
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
    public let action: () -> Void

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, peer: EnginePeer, messages: [EngineMessage], timestamp: Int32, loading: NewsFeedRowLoading, fresh: NewsFreshSegment? = nil, reduceMotion: Bool = false, fading: Bool = false, appearTime: Double? = nil, swipe: NewsPostSwipe? = nil, action: @escaping () -> Void) {
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
        // The closures are per post and the list's; only whether the row swipes changes how it looks.
        if (lhs.swipe == nil) != (rhs.swipe == nil) {
            return false
        }
        return true
    }

    public final class View: UIView {
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
        private let revealNode = NewsPostRevealNode()
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
        /// In a window and the app in the foreground: only then does the time need checking.
        private let hierarchyTrackingLayer = HierarchyTrackingLayer()

        private var component: NewsFeedPostComponent?
        private weak var state: EmptyComponentState?
        private var thumbnailMediaId: EngineMedia.Id?
        /// The time as last laid out.
        private var renderedTimeText: String?
        private var timeTimer: SwiftSignalKit.Timer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.revealNode.view)
            self.revealNode.contentNode.view.addSubview(self.contentView)
            self.contentView.addSubview(self.lensView)
            self.revealNode.opened = { [weak self] in
                guard let self else {
                    return
                }
                self.component?.swipe?.opened(self)
            }
            self.revealNode.separatorAlphaChanged = { [weak self] in
                guard let self else {
                    return
                }
                self.updateSeparatorAlpha()
                self.component?.swipe?.separatorAlphaChanged(self)
            }
            self.revealNode.selected = { [weak self] action in
                self?.component?.swipe?.action(action)
            }
            // One element, so VoiceOver offers the swipe's actions on it (spec §6).
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
            // Continuous corners (Feed2 FeedRow.swift:430-445): the layer clips, the image is drawn without corners.
            self.thumbnailView.layer.cornerRadius = NewsPostRowMetrics.thumbnailCornerRadius
            self.thumbnailView.layer.cornerCurve = .continuous
            self.thumbnailView.clipsToBounds = true
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
            self.addGestureRecognizer(tapRecognizer)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        deinit {
            self.timeTimer?.invalidate()
            self.highlightTimer?.invalidate()
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
            return layout.linesRects().map { textView.textNode.view.convert($0, to: self) }
        }

        @objc private func tapped() {
            // A tap on an open row only closes it. The control's own tap does that too; whichever of the two taps
            // wins, the row closes and nothing opens.
            guard !self.revealNode.isRevealOptionsActive else {
                self.closeSwipe(animated: true)
                return
            }
            self.component?.action()
        }

        // MARK: Swipe (spec §1, §5)

        public var hasSwipeActions: Bool {
            return self.component?.swipe != nil
        }

        /// 1 closed, 0 open: the row's own separator, and the separator of the row above, fade with it.
        public var swipeSeparatorAlpha: CGFloat {
            return self.revealNode.revealOptionsSeparatorAlpha
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
            self.revealNode.setRevealOptionsOpened(false, animated: animated)
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
            let layer = self.revealNode.layer
            if fading {
                self.revealNode.alpha = 0.0
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
                self.revealNode.alpha = 1.0
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
            self.revealNode.updateRevealOptionsHighlightedBackgroundNode(self.revealNode.highlightNode, isHighlighted: highlighted, transition: transition, aboveNodes: [])
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            // An open row shows its swipe surface; a tap only closes it.
            if self.revealNode.isRevealOptionsActive {
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
            if self.revealNode.isRevealOptionsActive {
                return
            }
            self.highlightTimer?.invalidate()
            self.highlightTimer = nil
            // A quick tap still flashes, as in the chat list.
            self.setHighlighted(true, animated: false)
            self.setHighlighted(false, animated: true)
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
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

        func update(component: NewsFeedPostComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            let isFirstUpdate = self.component == nil
            self.component = component
            self.state = state
            let theme = component.theme
            let timeText = newsPostTimeText(component: component)
            self.renderedTimeText = timeText
            defer {
                self.updateTimeTimer()
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
                transition.setFrame(view: avatarView, frame: layout.avatar)
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
                self.thumbnailView.isHidden = false
                transition.setFrame(view: self.thumbnailView, frame: thumbnailFrame)
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
                let makeLayout = self.thumbnailView.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(thumbnailFrame.size), boundingSize: thumbnailFrame.size, intrinsicInsets: UIEdgeInsets()))
                apply()

                if let videoDuration {
                    // A text shadow, not a layer shadow: no offscreen pass for every video row while scrolling.
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
                    string.append(NSAttributedString(string: stringForDuration(Int32(videoDuration)), font: Font.semibold(11.0), textColor: .white))
                    string.addAttribute(.shadow, value: shadow, range: NSRange(location: 0, length: string.length))
                    self.videoLabel.attributedText = string
                    let labelSize = self.videoLabel.sizeThatFits(CGSize(width: thumbnailFrame.width, height: 100.0))
                    self.videoLabel.frame = CGRect(x: thumbnailFrame.minX + 6.0, y: thumbnailFrame.maxY - 6.0 - labelSize.height, width: labelSize.width, height: labelSize.height)
                    self.videoLabel.isHidden = false
                } else {
                    self.videoLabel.isHidden = true
                }
            } else {
                self.thumbnailView.isHidden = true
                self.thumbnailMediaId = nil
                self.videoLabel.isHidden = true
            }

            self.separatorLayer.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
            transition.setFrame(layer: self.separatorLayer, frame: layout.separator)
            self.updateSeparatorAlpha()
            let rowSize = CGSize(width: availableSize.width, height: layout.height)
            // The row places the node; the node lays out inside it (a size change closes an open swipe).
            self.revealNode.frame = CGRect(origin: CGPoint(), size: rowSize)
            self.revealNode.update(size: rowSize, options: component.swipe != nil ? newsPostRevealOptions(theme: theme, strings: component.strings) : [], highlightColor: theme.list.itemHighlightedBackgroundColor)
            self.contentView.frame = CGRect(origin: CGPoint(), size: rowSize)
            self.lensView.frame = self.contentView.bounds

            self.accessibilityLabel = component.peer.compactDisplayTitle
            self.accessibilityValue = postText.string.isEmpty ? timeText : "\(timeText), \(postText.string)"
            if component.swipe != nil {
                self.accessibilityCustomActions = newsPostSwipeActions.map { action in
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
            return CGSize(width: availableSize.width, height: layout.height)
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
