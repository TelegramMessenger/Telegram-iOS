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

/// What the control is laid out for: the row's size and its two sides' buttons.
private struct NewsPostRevealLayout {
    let size: CGSize
    let leftOptions: [ItemListRevealOption]
    let rightOptions: [ItemListRevealOption]

    /// Whether the control resets a swipe in one frame going from `other` to this: another size (`updateLayout`) or
    /// other buttons on either side (`setRevealOptions`' structural change compares the swiped side's keys; News marks
    /// none destructive). No tolerance: whatever this lets through reaches an active control at once, and
    /// `updateLayout` resets a swipe for any change of size. New titles and colours the control takes in place.
    func resetsSwipe(from other: NewsPostRevealLayout) -> Bool {
        return self.size != other.size || self.leftOptions.map(\.key) != other.leftOptions.map(\.key) || self.rightOptions.map(\.key) != other.rightOptions.map(\.key)
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
    /// Whether a point (in this view) is on content that scrolls sideways itself (an expanded post's gallery): no
    /// swipe starts there, so the content scrolls. An open row still closes from anywhere.
    var hasHorizontalScrollingContent: ((CGPoint) -> Bool)?
    /// The content's offset changed (the swipe moves it): the row moves what follows the content along.
    var offsetChanged: ((CGFloat) -> Void)?
    /// The content's spring back after an Expand / Collapse commit: an additive offset over the closed position.
    private static let contentReturnKey = "newsSwipeContentReturn"
    /// The row is landing a mode morph (`NewsFeedPostComponent.View`): no swipe starts and the content takes no
    /// touches until then.
    var suspendsInteraction = false {
        didSet {
            if self.suspendsInteraction != oldValue {
                self.contentView.isUserInteractionEnabled = !self.suspendsInteraction && !self.isRevealOptionsActive
            }
        }
    }

    /// What the control was last given (`updateLayout`, `setRevealOptions`).
    private var appliedLayout: NewsPostRevealLayout?
    /// What the control gets once the row is back in place. The control resets a swipe in one frame on a change of its
    /// size or its buttons, and an open row can get both (an edited post, an expanded row measured again; its own
    /// Expand / Collapse closes the control first, `closeForMorph`). While one is pending the row is sliding closed
    /// and nothing opens it: a swipe would show the old buttons, laid out for the old height, and an open control
    /// never reports closed, so the row would stay open on them.
    private var pendingLayout: NewsPostRevealLayout?
    private var isPendingLayoutScheduled = false

    override init() {
        super.init()
        self.highlightView.isUserInteractionEnabled = false
        self.addSubview(self.contentView)
        // The screen's pager waits while the row is active, as the control has it, unless the row only slides closed
        // for a pending layout: it takes no swipe of its own then, so the pager is free over it.
        self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let self else {
                return false
            }
            return self.isRevealOptionsActive && self.pendingLayout == nil
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// `size` is the frame the row gave this view. No options: the swipe is off (its recognizers are disabled).
    func update(size: CGSize, leftOptions: [ItemListRevealOption], rightOptions: [ItemListRevealOption], highlightColor: UIColor) {
        // A destructive option fills the row on a full swipe, and a fill never settles: a pending layout would never
        // be taken, and the row would refuse every swipe from then on.
        assert(!(leftOptions + rightOptions).contains(where: { $0.isDestructive }))
        self.contentView.bounds = CGRect(origin: CGPoint(), size: size)
        self.contentView.center = CGPoint(x: size.width / 2.0 + self.revealOffset, y: size.height / 2.0)
        self.highlightView.backgroundColor = highlightColor
        self.updateRevealOptionsHighlightedBackgroundFrame(self.highlightView, frame: CGRect(origin: CGPoint(), size: size))
        let layout = NewsPostRevealLayout(size: size, leftOptions: leftOptions, rightOptions: rightOptions)
        if self.isRevealOptionsActive, let appliedLayout = self.appliedLayout, layout.resetsSwipe(from: appliedLayout) {
            // The content follows the swipe where it is. An open or dragged row slides closed for the change; one
            // already closing (an action's own update) keeps sliding, and this does nothing.
            self.pendingLayout = layout
            self.setRevealOptionsOpened(false, animated: true)
        } else {
            // Closed, or only titles and colours changed, which the control takes while open.
            self.pendingLayout = nil
            self.apply(layout)
        }
    }

    private func apply(_ layout: NewsPostRevealLayout) {
        self.appliedLayout = layout
        self.updateLayout(size: layout.size, leftInset: 0.0, rightInset: 0.0)
        self.setRevealOptions((left: layout.leftOptions, right: layout.rightOptions))
    }

    /// The row looks closed: the content is back in place and the surface has faded (the separators are back), so the
    /// reset that comes with the pending layout cannot be seen. From a full swipe that is about 0.7 s in, where the
    /// control reports closed only once its last spring rests, at about 1.24 s.
    private var isPendingLayoutDue: Bool {
        return self.pendingLayout != nil && abs(self.revealOffset) < 0.5 && self.revealOptionsSeparatorAlpha > 0.98
    }

    /// The control takes the pending layout on the next main-queue turn, if it is still due then: never inside the
    /// control's render or a gesture callback, where the reset that comes with it would cancel the recognizer
    /// delivering the event.
    private func schedulePendingLayout() {
        guard !self.isPendingLayoutScheduled else {
            return
        }
        self.isPendingLayoutScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.isPendingLayoutScheduled = false
            guard self.isPendingLayoutDue, let layout = self.pendingLayout else {
                return
            }
            // Cleared first: the reset re-enters `revealOptionsActiveStateUpdated`.
            self.pendingLayout = nil
            self.apply(layout)
        }
    }

    /// The control sets `disablesInteractiveTransitionGestureRecognizer` on every render, true with left options,
    /// which would leave the screen's pager only the screen's edges over every row
    /// (`InteractiveTransitionGestureRecognizer` drops the centre directions). The pager's own rule decides where a
    /// swipe is the row's (`newsPagerDefersToRowReveal`), and `disablesInteractiveTransitionGestureRecognizerNow`
    /// blocks it outright over an active row, so the flag stays cleared.
    override func revealRecognizerAvailabilityUpdated() {
        super.revealRecognizerAvailabilityUpdated()
        self.disablesInteractiveTransitionGestureRecognizer = false
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        self.contentView.center = CGPoint(x: self.bounds.width / 2.0 + offset, y: self.bounds.height / 2.0)
        self.offsetChanged?(offset)
        if self.isPendingLayoutDue {
            self.schedulePendingLayout()
        }
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        // A tap on the shifted row closes it (the control's tap) and reaches nothing inside, nor does one on a row
        // landing a morph.
        self.contentView.isUserInteractionEnabled = !isActive && !self.suspendsInteraction
        // A fallback: the control reports closed with a layout still pending.
        if !isActive, self.pendingLayout != nil {
            self.schedulePendingLayout()
        }
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
        // The old buttons of a row sliding closed for a pending layout do nothing: theirs is the previous action
        // (Collapse on a row already compact would expand it again).
        guard self.pendingLayout == nil, let action = NewsPostSwipeAction(rawValue: option.key) else {
            return
        }
        switch action {
        case .expand, .collapse:
            // The control's close and the row's morph pass reach the screen in one commit: the control renders in
            // explicit transactions of its own, and one of them alone could show the closed row before the morph.
            CATransaction.begin()
            self.closeForMorph()
            self.selected?(action)
            CATransaction.commit()
        case .interesting, .notInterested:
            // A commit settles open first; the host decides. Nothing to remove or fill: the row closes and reports.
            self.setRevealOptionsOpened(false, animated: true)
            self.selected?(action)
        }
    }

    /// Expand / Collapse morph the row in this same turn (`selected` runs the host's pass), and so does a switch of the
    /// feed's mode with the row open, so the control closes at once. Its surface and button leave with the commit
    /// instead of fading over the growing or shrinking row, and it takes the row's new size and options in that pass,
    /// so nothing waits in `pendingLayout` (one already waiting is the pass's to replace: the control is closed by
    /// then). The content springs back from where the swipe left it on the morph's own spring (`NewsMorphMotion`), as
    /// an additive offset over the closed position, so it lands with the row. The control's own close would run on its
    /// slower body spring from 75 % of the width, with the surface and the button over the morphing row, and the row
    /// would take its new layout only about 0.7 s in.
    func closeForMorph() {
        let offset = self.revealOffset
        self.setRevealOptionsOpened(false, animated: false)
        if self.isRevealOptionsActive {
            // Already closing (its button tapped mid-close, a pinch's close): `setRevealOptionsOpened` declines once
            // the control no longer wants to be open.
            self.updateRevealOffsetInternal(offset: 0.0, transition: .immediate)
        }
        guard abs(offset) > 0.5 else {
            return
        }
        self.contentView.layer.removeAnimation(forKey: NewsPostRevealView.contentReturnKey)
        if !UIAccessibility.isReduceMotionEnabled {
            self.contentView.layer.animate(from: NSValue(cgPoint: CGPoint(x: offset, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: NewsMorphMotion.duration, additive: true, key: NewsPostRevealView.contentReturnKey)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only the control's own recognizers are the row's to refuse. This view is asked about the list's pan and the
        // pager too whenever a touch lands on it rather than on the content, which takes no touches while the row is
        // open, sliding closed or landing a morph, and a scroll or a page swipe may start there.
        guard gestureRecognizer.view === self else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        // Nothing of the control's begins on a row sliding closed for a pending layout (a swipe would open the old
        // buttons at the old height) or landing a morph (its content may still be springing back from the swipe).
        if self.pendingLayout != nil || self.suspendsInteraction {
            return false
        }
        if !(gestureRecognizer is UITapGestureRecognizer), !self.isRevealOptionsActive {
            let location = gestureRecognizer.location(in: self)
            // The chat list's rule: a swipe is the row's own from its edge zones, the pager's from the middle.
            if !newsRowRevealAllowed(touchX: location.x, width: self.bounds.width) {
                return false
            }
            if self.hasHorizontalScrollingContent?(location) == true {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // A strip inside the row that scrolls sideways (the gallery) takes its pan at once: the control would make it
        // wait 25 pt for the swipe's own decision.
        if otherGestureRecognizer is UIPanGestureRecognizer, let view = otherGestureRecognizer.view, view !== self, view.isDescendant(of: self) {
            return false
        }
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
