import UIKit
@testable import CoreListDemo

final class FixedHeightItemView: UIView, CoreListItemView {
    let fixedHeight: CGFloat
    var onContentDidChange: ((Bool) -> Void)?

    init(height: CGFloat) {
        self.fixedHeight = height
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        fixedHeight
    }
}

final class FixedHeightItem: CoreListItem {
    let height: CGFloat
    var identity: AnyHashable { height }   // value identity (matches isEqual)

    init(height: CGFloat) {
        self.height = height
    }

    func view() -> UIView & CoreListItemView {
        FixedHeightItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? FixedHeightItem else { return false }
        return height == other.height
    }
}

final class WidthDependentItemView: UIView, CoreListItemView {
    let baseHeight: CGFloat
    let baseWidth: CGFloat
    var onContentDidChange: ((Bool) -> Void)?

    init(baseHeight: CGFloat, baseWidth: CGFloat) {
        self.baseHeight = baseHeight
        self.baseWidth = baseWidth
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        ceil(baseHeight * baseWidth / width)
    }
}

final class WidthDependentItem: CoreListItem {
    let baseHeight: CGFloat
    let baseWidth: CGFloat
    var identity: AnyHashable { [baseHeight, baseWidth] }   // value identity (matches isEqual)

    init(baseHeight: CGFloat, baseWidth: CGFloat) {
        self.baseHeight = baseHeight
        self.baseWidth = baseWidth
    }

    func view() -> UIView & CoreListItemView {
        WidthDependentItemView(baseHeight: baseHeight, baseWidth: baseWidth)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? WidthDependentItem else { return false }
        return baseHeight == other.baseHeight && baseWidth == other.baseWidth
    }
}

final class WidthDependentItemViewWithSubview: UIView, CoreListItemView {
    let baseHeight: CGFloat
    let baseWidth: CGFloat
    let label = UIView()
    var onContentDidChange: ((Bool) -> Void)?

    init(baseHeight: CGFloat, baseWidth: CGFloat) {
        self.baseHeight = baseHeight
        self.baseWidth = baseWidth
        super.init(frame: .zero)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let h = ceil(baseHeight * baseWidth / width)
        label.frame = CGRect(x: 0, y: 0, width: width, height: h)
        return h
    }
}

final class WidthDependentItemWithSubview: CoreListItem {
    let baseHeight: CGFloat
    let baseWidth: CGFloat
    var identity: AnyHashable { [baseHeight, baseWidth] }   // value identity (matches isEqual)

    init(baseHeight: CGFloat, baseWidth: CGFloat) {
        self.baseHeight = baseHeight
        self.baseWidth = baseWidth
    }

    func view() -> UIView & CoreListItemView {
        WidthDependentItemViewWithSubview(baseHeight: baseHeight, baseWidth: baseWidth)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? WidthDependentItemWithSubview else { return false }
        return baseHeight == other.baseHeight && baseWidth == other.baseWidth
    }
}

// MARK: - Identifiable items (for diff tests)

final class IdentifiableFixedHeightItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let height: CGFloat

    init(id: UUID, height: CGFloat) {
        self.id = id
        self.height = height
    }

    func view() -> UIView & CoreListItemView {
        FixedHeightItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? IdentifiableFixedHeightItem else { return false }
        return id == other.id
    }
}

final class IdentifiableWidthDependentItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let baseHeight: CGFloat
    let baseWidth: CGFloat

    init(id: UUID, baseHeight: CGFloat, baseWidth: CGFloat) {
        self.id = id
        self.baseHeight = baseHeight
        self.baseWidth = baseWidth
    }

    func view() -> UIView & CoreListItemView {
        WidthDependentItemView(baseHeight: baseHeight, baseWidth: baseWidth)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? IdentifiableWidthDependentItem else { return false }
        return id == other.id
    }
}

// MARK: - Self-updating item

final class SelfUpdatingItemView: UIView, CoreListItemView {
    private var currentHeight: CGFloat
    var onContentDidChange: ((Bool) -> Void)?

    init(initialHeight: CGFloat) {
        self.currentHeight = initialHeight
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat { currentHeight }

    /// Test seam: change the height the view will report next, then signal the list.
    func simulateContentChange(newHeight: CGFloat, animated: Bool) {
        currentHeight = newHeight
        onContentDidChange?(animated)
    }
}

final class SelfUpdatingItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let initialHeight: CGFloat

    init(id: UUID, initialHeight: CGFloat) {
        self.id = id
        self.initialHeight = initialHeight
    }

    func view() -> UIView & CoreListItemView {
        SelfUpdatingItemView(initialHeight: initialHeight)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? SelfUpdatingItem else { return false }
        return id == other.id
    }
}

// MARK: - Visible-rect recording item

/// Records every `visibleRectUpdated(_:)` it receives, so tests can assert both the value and the
/// fact that a notification happened at all.
final class VisibleRectRecordingItemView: UIView, CoreListItemView {
    let fixedHeight: CGFloat
    var onContentDidChange: ((Bool) -> Void)?
    private(set) var visibleRects: [CGRect?] = []

    /// The most recent rect, flattening "never notified" and "notified nil" — use `wasNotifiedNil`
    /// when that distinction matters.
    var lastRect: CGRect? { visibleRects.last ?? nil }
    var wasNotifiedNil: Bool { visibleRects.last == .some(nil) }

    init(height: CGFloat) {
        self.fixedHeight = height
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat { fixedHeight }

    nonisolated func visibleRectUpdated(_ visibleRect: CGRect?) {
        visibleRects.append(visibleRect)
    }
}

final class VisibleRectRecordingItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let height: CGFloat

    init(id: UUID, height: CGFloat) {
        self.id = id
        self.height = height
    }

    func view() -> UIView & CoreListItemView {
        VisibleRectRecordingItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? VisibleRectRecordingItem else { return false }
        return id == other.id
    }
}

// MARK: - Content-reconcile item

/// A test item that OPTS INTO content-reconcile: same id ⇒ identity-equal (a survivor), but a changed
/// `contentHeight` ⇒ NOT content-equal ⇒ the engine reconfigures + re-measures it. The view counts
/// `apply(to:)` applications so tests can assert selectivity (unchanged survivors are never reconfigured).
final class ContentResizableItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let contentHeight: CGFloat

    init(id: UUID, contentHeight: CGFloat) {
        self.id = id
        self.contentHeight = contentHeight
    }

    func view() -> UIView & CoreListItemView {
        let v = ContentResizableItemView(); apply(to: v, transition: .immediate); return v
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let o = other as? ContentResizableItem else { return false }
        return o.id == id && o.contentHeight == contentHeight
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? ContentResizableItemView)?.applyContent(contentHeight)
    }
}

final class ContentResizableItemView: UIView, CoreListItemView {
    var onContentDidChange: ((Bool) -> Void)?
    private(set) var contentHeight: CGFloat = 50
    /// INTERNAL state of this view instance, NOT modeled by the item (the analogue of tap-expand/grow).
    /// This fixture's mechanic leaves it untouched on a `contentHeight` (external) change — so it
    /// demonstrates that the engine reconfigures the existing instance (via `apply(to:)`) rather than
    /// rebuilding it; internal-state fate is the VIEW's choice, not an engine contract (design §2.3).
    private(set) var bonusHeight: CGFloat = 0
    /// Counts `apply(to:)` applications (NOT raw height writes) so selectivity tests can assert an
    /// unchanged survivor is never reconfigured. Starts at 1: `view()` applies once at construction,
    /// so tests measure the DELTA across an applyChanges pass on an existing view.
    private(set) var applyCount = 0

    func applyContent(_ height: CGFloat) {
        contentHeight = height
        applyCount += 1
    }
    /// Simulate a view-only height change (the analogue of tap-expand). NOT applied via the item.
    func addBonus(_ extra: CGFloat) { bonusHeight += extra }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat { contentHeight + bonusHeight }
}

// MARK: - Bottom-edge-pinned items

/// A fixed-height row that pins to the viewport's bottom edge — the fixture analogue of a chat
/// message carrying `ListViewItem.pinToEdgeWithInset`.
final class PinnedFixedHeightItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let height: CGFloat
    var pinsToBottomEdge: Bool { true }

    init(id: UUID, height: CGFloat) {
        self.id = id
        self.height = height
    }

    func view() -> UIView & CoreListItemView {
        FixedHeightItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? PinnedFixedHeightItem else { return false }
        return id == other.id && height == other.height
    }
}
