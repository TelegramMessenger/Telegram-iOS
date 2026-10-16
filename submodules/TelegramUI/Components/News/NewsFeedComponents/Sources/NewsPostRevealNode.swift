import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import TelegramPresentationData
import NewsFeedSupport

/// A post row's swipe actions (spec §3). Rows built without it do not swipe (search results).
public struct NewsPostSwipe {
    /// The action picked for this row's post. The row has already started closing.
    public let action: (NewsPostSwipeAction) -> Void
    /// The row began opening: the list closes its other rows.
    public let opened: (NewsFeedPostComponent.View) -> Void
    /// The row's swipe separator alpha changed: the list fades the separator above it to match.
    public let separatorAlphaChanged: (NewsFeedPostComponent.View) -> Void

    public init(action: @escaping (NewsPostSwipeAction) -> Void, opened: @escaping (NewsFeedPostComponent.View) -> Void, separatorAlphaChanged: @escaping (NewsFeedPostComponent.View) -> Void) {
        self.action = action
        self.opened = opened
        self.separatorAlphaChanged = separatorAlphaChanged
    }
}

private let newsPostSwipeIconConfiguration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .semibold)
// Created once: an option's image is compared by identity, and new images would reset the control on every update.
private let newsPostInterestingIcon = UIImage(systemName: "hand.thumbsup.fill", withConfiguration: newsPostSwipeIconConfiguration)
private let newsPostNotInterestedIcon = UIImage(systemName: "hand.thumbsdown.fill", withConfiguration: newsPostSwipeIconConfiguration)

func newsPostSwipeTitle(_ action: NewsPostSwipeAction, strings: PresentationStrings) -> String {
    switch action {
    case .interesting:
        return strings.News_Swipe_Interesting
    case .notInterested:
        return strings.News_Swipe_NotInterested
    }
}

/// The chat list's buttons, in `newsPostSwipeActions` order. Not Interested is not `isDestructive`: that would make a
/// full swipe fill the row as a delete does, and the post stays (spec §2).
func newsPostRevealOptions(theme: PresentationTheme, strings: PresentationStrings) -> [ItemListRevealOption] {
    return newsPostSwipeActions.map { action in
        let colors: PresentationThemeFillForeground
        let image: UIImage?
        switch action {
        case .interesting:
            colors = theme.list.itemDisclosureActions.accent
            image = newsPostInterestingIcon
        case .notInterested:
            colors = theme.list.itemDisclosureActions.destructive
            image = newsPostNotInterestedIcon
        }
        return ItemListRevealOption(key: action.rawValue, title: newsPostSwipeTitle(action, strings: strings), icon: image.map { .image(image: $0) } ?? .none, color: colors.fillColor, iconColor: colors.foregroundColor, textColor: theme.list.itemSecondaryTextColor)
    }
}

/// The post row's swipe, hosted as the poll composer hosts it (`ComposeOptionRevealNode`): the row owns its layout,
/// ItemListUI owns the whole swipe (spec §1).
final class NewsPostRevealNode: ItemListRevealOptionsItemNode {
    /// The row's content: it slides with the swipe.
    let contentNode = ASDisplayNode()
    /// The press highlight and the swipe surface. The control sets its alpha, and while the row is open rounds it and
    /// moves it with the content.
    let highlightNode = ASDisplayNode()
    var opened: (() -> Void)?
    var separatorAlphaChanged: (() -> Void)?
    var selected: ((NewsPostSwipeAction) -> Void)?

    init() {
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        self.highlightNode.isUserInteractionEnabled = false
        self.addSubnode(self.contentNode)
    }

    /// `size` is the frame the row gave this node. No options: the swipe is off (its recognizers are disabled).
    func update(size: CGSize, options: [ItemListRevealOption], highlightColor: UIColor) {
        self.contentNode.bounds = CGRect(origin: CGPoint(), size: size)
        self.contentNode.position = CGPoint(x: size.width / 2.0 + self.revealOffset, y: size.height / 2.0)
        self.highlightNode.backgroundColor = highlightColor
        self.updateRevealOptionsHighlightedBackgroundFrame(self.highlightNode, frame: CGRect(origin: CGPoint(), size: size))
        self.updateLayout(size: size, leftInset: 0.0, rightInset: 0.0)
        self.setRevealOptions((left: [], right: options))
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        self.contentNode.position = CGPoint(x: self.bounds.width / 2.0 + offset, y: self.bounds.height / 2.0)
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        // A tap on the shifted row closes it (the control's tap) and reaches nothing inside.
        self.contentNode.isUserInteractionEnabled = !isActive
    }

    override func revealOptionsSeparatorAlphaUpdated() {
        super.revealOptionsSeparatorAlphaUpdated()
        self.separatorAlphaChanged?()
    }

    override func revealOptionsInteractivelyOpened() {
        super.revealOptionsInteractivelyOpened()
        self.opened?()
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        guard let action = NewsPostSwipeAction(rawValue: option.key) else {
            return
        }
        // A commit settles open first; the host decides. Nothing to remove or fill: the row closes and reports.
        self.setRevealOptionsOpened(false, animated: true)
        self.selected?(action)
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // CoreList scrolls with its own pan on a plain view, and the control only makes a UIScrollView's pan wait for
        // its horizontal check. Make the list's pan wait too, as the chat list's does (vertical movement fails the
        // row's recognizer at 10 pt). Only the touch recognizer, which is neither a tap nor a pan; the pager decides
        // before it (the control requires the pager's failure).
        if !(gestureRecognizer is UITapGestureRecognizer), !(gestureRecognizer is UIPanGestureRecognizer), otherGestureRecognizer is UIPanGestureRecognizer, !(otherGestureRecognizer is InteractiveTransitionGestureRecognizer), let ancestor = otherGestureRecognizer.view, ancestor !== self.view, self.view.isDescendant(of: ancestor) {
            return true
        }
        return super.gestureRecognizer(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer)
    }
}
