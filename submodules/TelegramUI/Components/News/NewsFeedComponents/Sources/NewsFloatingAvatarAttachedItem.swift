import Foundation
import UIKit
import ComponentFlow
import CoreList
import AccountContext
import TelegramCore
import TelegramPresentationData
import AvatarComponent
import NewsFeedSupport

/// An expanded post's avatar as a CoreList run attachment: one avatar for a run of adjacent posts from the same
/// channel, floating at the top of the display area while the run is on screen and parking at the run's end, as a
/// group chat's gutter avatar does. Keyed by the channel, so adjacent rows of one channel make one run.
public final class NewsFloatingAvatarAttachedItem: CoreListAttachedItem {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let loading: NewsFeedRowLoading

    public init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer, loading: NewsFeedRowLoading) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.loading = loading
    }

    public var placement: CoreListAttachmentPlacement {
        return .overlay
    }

    public var edge: CoreListAttachmentEdge {
        return .top
    }

    public var isFloating: Bool {
        return true
    }

    public func view() -> UIView & CoreListAttachedItemView {
        return NewsFloatingAvatarView(item: self)
    }

    public func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? NewsFloatingAvatarAttachedItem else {
            return false
        }
        return other.peer == self.peer && other.theme === self.theme
    }

    public func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? NewsFloatingAvatarView)?.setItem(self)
    }
}

/// The floating avatar's view: the avatar at the row's avatar position, over a band as wide as the list. It takes no
/// touches (the row under it does). A gallery scrolled under the avatar's column moves it aside
/// (`newsExpandedAvatarOffset`): each row of the run tells this view where its gallery is (`setObstacle`). The row hides it
/// (`isHidden`) while its own avatar stands in for it: pressed or lifted into a context menu, or flying into this
/// one's place in a morph from compact. It shows in the frame that avatar hides.
public final class NewsFloatingAvatarView: UIView, CoreListAttachedItemView {
    private var item: NewsFloatingAvatarAttachedItem
    private let avatar = ComponentView<Empty>()
    private var restingFrame = CGRect()

    public var onContentDidChange: ((Bool) -> Void)?
    /// Every row of the run shares this view. Per row: its scrolled gallery, if any, in this view's coordinates (its
    /// frame and how far its content has moved from rest), asked on every stick update and whenever a row says it
    /// changed; and how far the row has slid for its swipe, nonzero only on the row the avatar sits on.
    private var obstacles: [ObjectIdentifier: () -> (frame: CGRect, scrolled: CGFloat)?] = [:]
    private var swipeOffsets: [ObjectIdentifier: CGFloat] = [:]

    func setObstacle(_ obstacle: (() -> (frame: CGRect, scrolled: CGFloat)?)?, for row: AnyObject) {
        self.obstacles[ObjectIdentifier(row)] = obstacle
    }

    /// The avatar slides with the row it sits on.
    func setSwipeOffset(_ offset: CGFloat, for row: AnyObject) {
        let key = ObjectIdentifier(row)
        if (self.swipeOffsets[key] ?? 0.0) != offset {
            self.swipeOffsets[key] = offset == 0.0 ? nil : offset
            self.applyObstacle()
        }
    }

    /// Where the avatar rests in this view, before the gallery and the swipe move it.
    var restingAvatarFrame: CGRect {
        return self.restingFrame
    }

    /// Where the avatar is in this view now.
    var avatarFrame: CGRect {
        return self.avatar.view?.frame ?? self.restingFrame
    }

    /// Where the avatar is on screen now, in `view`: through the presentation layers, since the list may be animating
    /// this view and `view` apart; the model geometry where either has none yet.
    func presentedAvatarFrame(in view: UIView) -> CGRect {
        guard let avatarView = self.avatar.view else {
            return self.convert(self.restingFrame, to: view)
        }
        if let from = avatarView.layer.presentation(), let to = view.layer.presentation() {
            return from.convert(from.bounds, to: to)
        }
        return avatarView.convert(avatarView.bounds, to: view)
    }

    /// The row's own avatar has just handed over to this one, drawn at `frame` (in this view, as on screen). Where the
    /// list has moved this avatar since the flight was aimed (a scroll during the morph moves a stuck or parked one
    /// against its row), it goes the rest of the way instead of jumping. Additive, so the stick and the swipe keep
    /// moving its frame meanwhile.
    func takeOver(from frame: CGRect) {
        guard let avatarView = self.avatar.view else {
            return
        }
        let offset = CGPoint(x: frame.midX - avatarView.frame.midX, y: frame.midY - avatarView.frame.midY)
        guard abs(offset.x) > 0.5 || abs(offset.y) > 0.5 else {
            return
        }
        ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)).animatePosition(view: avatarView, from: offset, to: CGPoint(), additive: true)
    }

    /// The avatar moved, or the list moved this view: whoever draws around it (the header's edge) follows.
    var frameChanged: (() -> Void)?

    /// The row whose own avatar is flying into this one in a morph from compact
    /// (`NewsFeedPostComponent.View.aimAvatarHandOff`). This one stays hidden until that flight lands, even if the list
    /// binds it to another row meanwhile (a scroll or a pinch during the morph).
    weak var landingRow: AnyObject?

    init(item: NewsFloatingAvatarAttachedItem) {
        self.item = item
        super.init(frame: CGRect())
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }

    func setItem(_ item: NewsFloatingAvatarAttachedItem) {
        self.item = item
        let _ = self.update(width: self.bounds.width, transition: .immediate)
    }

    public func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let metrics = NewsExpandedPostMetrics.self
        let frame = CGRect(x: metrics.avatarInset, y: metrics.avatarTop, width: metrics.avatarSize, height: metrics.avatarSize)
        self.restingFrame = frame
        let _ = self.avatar.update(
            transition: .immediate,
            component: AnyComponent(AvatarComponent(context: self.item.context, theme: self.item.theme, peer: self.item.peer, size: frame.size, synchronousLoad: self.item.loading.isSynchronous)),
            environment: {},
            containerSize: frame.size
        )
        if let avatarView = self.avatar.view {
            if avatarView.superview == nil {
                self.addSubview(avatarView)
            }
            avatarView.frame = frame
        }
        self.applyObstacle()
        return metrics.avatarTop + metrics.avatarSize + metrics.bottomInset
    }

    public func stickDistanceUpdated(_ distance: CGFloat) {
        self.applyObstacle()
    }

    /// The row's gallery moved, or this view did: re-place the avatar beside the scrolled content.
    func obstacleChanged() {
        self.applyObstacle()
    }

    private func applyObstacle() {
        guard let avatarView = self.avatar.view else {
            return
        }
        // Only a gallery beside the avatar moves it (the others give 0), and the avatar sits on one row only.
        var offset: CGFloat = 0.0
        for obstacle in self.obstacles.values {
            if let obstacle = obstacle() {
                offset = min(offset, newsExpandedAvatarOffset(galleryScrolled: obstacle.scrolled, galleryFrame: obstacle.frame, avatarFrame: self.restingFrame))
            }
        }
        let swipeOffset = self.swipeOffsets.values.max(by: { abs($0) < abs($1) }) ?? 0.0
        avatarView.frame = self.restingFrame.offsetBy(dx: offset + swipeOffset, dy: 0.0)
        self.frameChanged?()
    }
}
