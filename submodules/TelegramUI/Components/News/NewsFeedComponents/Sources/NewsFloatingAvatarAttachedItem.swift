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
/// (`newsExpandedAvatarOffset`): the row tells this view where its gallery is through `obstacle`.
public final class NewsFloatingAvatarView: UIView, CoreListAttachedItemView {
    private var item: NewsFloatingAvatarAttachedItem
    private let avatar = ComponentView<Empty>()
    private var restingFrame = CGRect()

    public var onContentDidChange: ((Bool) -> Void)?
    /// The scrolled gallery under this avatar's column, if any, in this view's coordinates: its frame and how far
    /// its content has moved from rest. Asked on every stick update and whenever the row says it changed.
    var obstacle: (() -> (frame: CGRect, scrolled: CGFloat)?)?

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
        var offset: CGFloat = 0.0
        if let obstacle = self.obstacle?() {
            offset = newsExpandedAvatarOffset(galleryScrolled: obstacle.scrolled, galleryFrame: obstacle.frame, avatarFrame: self.restingFrame)
        }
        avatarView.frame = self.restingFrame.offsetBy(dx: offset, dy: 0.0)
    }
}
