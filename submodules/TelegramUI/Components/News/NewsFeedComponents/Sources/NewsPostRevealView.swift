import Foundation
import UIKit
import Display
import ItemListUI
import TelegramPresentationData
import NewsFeedSupport

/// A post row's swipe actions (spec §3). Rows built without it do not swipe (search results).
public struct NewsPostSwipe {
    /// The right side's Interesting / Not Interested: For you's rows. Every swiping row has Expand on the left.
    public let hasFeedbackActions: Bool
    /// The action picked for this row's post. The row has already started closing.
    public let action: (NewsPostSwipeAction) -> Void
    /// The row began opening: the list closes its other rows.
    public let opened: (NewsFeedPostComponent.View) -> Void
    /// The row's swipe separator alpha changed: the list fades the separator above it to match.
    public let separatorAlphaChanged: (NewsFeedPostComponent.View) -> Void

    public init(hasFeedbackActions: Bool, action: @escaping (NewsPostSwipeAction) -> Void, opened: @escaping (NewsFeedPostComponent.View) -> Void, separatorAlphaChanged: @escaping (NewsFeedPostComponent.View) -> Void) {
        self.hasFeedbackActions = hasFeedbackActions
        self.action = action
        self.opened = opened
        self.separatorAlphaChanged = separatorAlphaChanged
    }
}

private let newsPostSwipeIconConfiguration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .semibold)
// Created once: an option's image is compared by identity, and new images would reset the control on every update.
private let newsPostInterestingIcon = UIImage(systemName: "hand.thumbsup.fill", withConfiguration: newsPostSwipeIconConfiguration)
private let newsPostNotInterestedIcon = UIImage(systemName: "hand.thumbsdown.fill", withConfiguration: newsPostSwipeIconConfiguration)
private let newsPostExpandIcon = UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: newsPostSwipeIconConfiguration)
private let newsPostCollapseIcon = UIImage(systemName: "arrow.down.right.and.arrow.up.left", withConfiguration: newsPostSwipeIconConfiguration)

func newsPostSwipeTitle(_ action: NewsPostSwipeAction, strings: PresentationStrings) -> String {
    switch action {
    case .interesting:
        return strings.News_Swipe_Interesting
    case .notInterested:
        return strings.News_Swipe_NotInterested
    case .expand:
        return strings.News_Swipe_Expand
    case .collapse:
        return strings.News_Swipe_Collapse
    }
}

/// The left side's one button, drawn as the right side's: Expand on a compact row, Collapse on an expanded one. A
/// full swipe performs it (the control's primary option on the left is the first).
func newsPostLeftRevealOptions(isExpanded: Bool, theme: PresentationTheme, strings: PresentationStrings) -> [ItemListRevealOption] {
    let action: NewsPostSwipeAction = isExpanded ? .collapse : .expand
    let colors = theme.list.itemDisclosureActions.accent
    let image = isExpanded ? newsPostCollapseIcon : newsPostExpandIcon
    return [ItemListRevealOption(key: action.rawValue, title: newsPostSwipeTitle(action, strings: strings), icon: image.map { .image(image: $0) } ?? .none, color: colors.fillColor, iconColor: colors.foregroundColor, textColor: theme.list.itemSecondaryTextColor)]
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
        case .expand, .collapse:
            // The left side's (`newsPostLeftRevealOptions`); never in `newsPostSwipeActions`.
            colors = theme.list.itemDisclosureActions.accent
            image = action == .expand ? newsPostExpandIcon : newsPostCollapseIcon
        }
        return ItemListRevealOption(key: action.rawValue, title: newsPostSwipeTitle(action, strings: strings), icon: image.map { .image(image: $0) } ?? .none, color: colors.fillColor, iconColor: colors.foregroundColor, textColor: theme.list.itemSecondaryTextColor)
    }
}

/// The post row's swipe, hosted as the poll composer hosts it (`ComposeOptionRevealNode`): the row owns its layout,
/// ItemListUI owns the whole swipe (spec §1).
final class NewsPostRevealView: ItemListRevealOptionsItemView {
    /// The row's content: it slides with the swipe.
    let contentView = UIView()
    /// The press highlight and the swipe surface. The control sets its alpha, and while the row is open rounds it and
    /// moves it with the content.
    let highlightView = UIView()
    var opened: (() -> Void)?
    var separatorAlphaChanged: (() -> Void)?
    var selected: ((NewsPostSwipeAction) -> Void)?

    override init() {
        super.init()
        self.highlightView.isUserInteractionEnabled = false
        self.addSubview(self.contentView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// `size` is the frame the row gave this view. No options: the swipe is off (its recognizers are disabled).
    func update(size: CGSize, leftOptions: [ItemListRevealOption], rightOptions: [ItemListRevealOption], highlightColor: UIColor) {
        self.contentView.bounds = CGRect(origin: CGPoint(), size: size)
        self.contentView.center = CGPoint(x: size.width / 2.0 + self.revealOffset, y: size.height / 2.0)
        self.highlightView.backgroundColor = highlightColor
        self.updateRevealOptionsHighlightedBackgroundFrame(self.highlightView, frame: CGRect(origin: CGPoint(), size: size))
        self.updateLayout(size: size, leftInset: 0.0, rightInset: 0.0)
        self.setRevealOptions((left: leftOptions, right: rightOptions))
        self.keepPagerOverClosedRow()
    }

    /// With left options the control marks its view as having horizontal gestures of its own, which would leave the
    /// screen's pager only the screen's edges over every row (`InteractiveTransitionGestureRecognizer` drops the
    /// centre directions). The pager's own rule decides where a swipe is the row's (`newsPagerDefersToRowReveal`),
    /// and the control already blocks the pager outright while the row is open (its `…Now` closure), so the flag is
    /// cleared whenever the control sets it.
    private func keepPagerOverClosedRow() {
        self.disablesInteractiveTransitionGestureRecognizer = false
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        self.contentView.center = CGPoint(x: self.bounds.width / 2.0 + offset, y: self.bounds.height / 2.0)
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        // A tap on the shifted row closes it (the control's tap) and reaches nothing inside.
        self.contentView.isUserInteractionEnabled = !isActive
        self.keepPagerOverClosedRow()
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
        if !(gestureRecognizer is UITapGestureRecognizer), !(gestureRecognizer is UIPanGestureRecognizer), otherGestureRecognizer is UIPanGestureRecognizer, !(otherGestureRecognizer is InteractiveTransitionGestureRecognizer), let ancestor = otherGestureRecognizer.view, ancestor !== self, self.isDescendant(of: ancestor) {
            return true
        }
        return super.gestureRecognizer(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer)
    }
}
