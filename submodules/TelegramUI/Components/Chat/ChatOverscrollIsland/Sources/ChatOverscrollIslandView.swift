import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import AvatarNode
import GlassBackgroundComponent
import ChatOverscrollIslandLayout

/// What the island names: the next channel (or topic) and its unread count, or, without a peer, that there is none.
public struct ChatOverscrollIslandContent: Equatable {
    public var peer: EnginePeer?
    public var title: String
    public var unreadCount: Int

    public init(peer: EnginePeer?, title: String, unreadCount: Int) {
        self.peer = peer
        self.title = title
        self.unreadCount = unreadCount
    }
}

/// The island's glass and its avatar, title and count. Its frame is its host's (`ChatOverscrollIslandHost`); it lays
/// itself out against its bounds. The content is laid out at the island's full size, centred, and clipped to the
/// island's current shape, which is smaller until it has fully grown.
final class ChatOverscrollIslandView: UIView {
    private let glassView: GlassBackgroundView
    private let contentClippingView: UIView
    private let contentContainer: UIView
    private let avatarNode: AvatarNode
    private let titleLabel: UILabel
    private let countLabel: UILabel

    private var currentContent: (content: ChatOverscrollIslandContent, theme: PresentationTheme, maxWidth: CGFloat)?
    private var titleSize = CGSize()
    private var countSize = CGSize()
    private(set) var widths: (title: CGFloat, full: CGFloat) = (0.0, 0.0)

    override init(frame: CGRect) {
        self.glassView = GlassBackgroundView()
        self.contentClippingView = UIView()
        self.contentClippingView.isUserInteractionEnabled = false
        self.contentClippingView.clipsToBounds = true
        self.contentContainer = UIView()
        self.contentContainer.isUserInteractionEnabled = false
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 13.0))
        self.titleLabel = UILabel()
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.countLabel = UILabel()

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.addSubview(self.glassView)
        self.glassView.contentView.addSubview(self.contentClippingView)
        self.contentClippingView.addSubview(self.contentContainer)
        self.contentContainer.addSubview(self.avatarNode.view)
        self.contentContainer.addSubview(self.titleLabel)
        self.contentContainer.addSubview(self.countLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets what the island says and measures it; a pull calls this every frame, so it only does work when the
    /// content, theme or room changes. `widths` holds the result.
    func updateContent(context: AccountContext, content: ChatOverscrollIslandContent, theme: PresentationTheme, maxWidth: CGFloat) {
        if let current = self.currentContent, current.content == content, current.theme === theme, current.maxWidth == maxWidth {
            return
        }
        self.currentContent = (content, theme, maxWidth)

        self.titleLabel.attributedText = NSAttributedString(string: content.title, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)
        self.countLabel.attributedText = NSAttributedString(string: content.unreadCount > 0 ? "\(content.unreadCount)" : "", font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)
        let countSize = self.countLabel.sizeThatFits(CGSize(width: 80.0, height: 40.0))
        self.countSize = CGSize(width: content.unreadCount > 0 ? ceil(countSize.width) : 0.0, height: ceil(countSize.height))
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: maxWidth, height: 40.0))
        self.titleSize = CGSize(width: ceil(titleSize.width), height: ceil(titleSize.height))
        self.widths = chatOverscrollIslandTextWidths(titleWidth: self.titleSize.width, countWidth: self.countSize.width, hasAvatar: content.peer != nil, maxWidth: maxWidth)

        let metrics = ChatOverscrollIslandMetrics.self
        let leading = content.peer != nil ? metrics.leadingWithAvatar : metrics.leading
        self.avatarNode.view.isHidden = content.peer == nil
        if let peer = content.peer {
            self.avatarNode.frame = CGRect(x: metrics.avatarX, y: floor((metrics.height - metrics.avatarSize) * 0.5), width: metrics.avatarSize, height: metrics.avatarSize)
            self.avatarNode.setPeer(context: context, theme: theme, peer: peer, displayDimensions: CGSize(width: metrics.avatarSize, height: metrics.avatarSize))
        }
        self.titleLabel.frame = CGRect(x: leading, y: floor((metrics.height - self.titleSize.height) * 0.5), width: self.widths.title, height: self.titleSize.height)
        self.countLabel.frame = CGRect(x: leading + self.widths.title + metrics.countSpacing, y: floor((metrics.height - self.countSize.height) * 0.5), width: self.countSize.width, height: self.countSize.height)
    }

    /// `contentTransition` fades the avatar, title and count, which must go faster than the glass dissolves when the
    /// island sinks, or they float without it for a few frames.
    func update(size: CGSize, isDark: Bool, preferClearGlass: Bool, contentAlpha: CGFloat, isVisible: Bool, transition: ComponentTransition, contentTransition: ComponentTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.setFrame(view: self.glassView, frame: bounds)
        self.glassView.update(size: size, cornerRadius: size.height * 0.5, isDark: isDark, tintColor: .init(kind: preferClearGlass ? .clear : .panel), isInteractive: false, isVisible: isVisible, transition: transition)

        transition.setFrame(view: self.contentClippingView, frame: bounds)
        transition.setCornerRadius(layer: self.contentClippingView.layer, cornerRadius: size.height * 0.5)
        let contentSize = CGSize(width: self.widths.full, height: ChatOverscrollIslandMetrics.height)
        transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) * 0.5), y: floor((size.height - contentSize.height) * 0.5)), size: contentSize))
        contentTransition.setAlpha(view: self.contentContainer, alpha: contentAlpha)
    }
}
