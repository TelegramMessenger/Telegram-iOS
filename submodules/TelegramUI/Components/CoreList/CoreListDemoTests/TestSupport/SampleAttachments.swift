import UIKit
@testable import CoreListDemo

/// Fixture attachment view: reports a fixed height and records how it was measured.
///
/// `fixedHeight` is mutable and pushed in by the descriptor's `apply`, because a reused view keeps
/// whatever it was constructed with — a descriptor that changes its height cannot express that
/// change without reconfiguring, exactly as a real attachment must.
final class FixedHeightAttachmentView: UIView, CoreListAttachedItemView {
    private(set) var fixedHeight: CGFloat
    private(set) var lastMeasuredWidth: CGFloat?
    private(set) var lastMeasureTransition: CoreListTransition?
    private(set) var measureCount = 0
    private(set) var lastStickDistance: CGFloat?
    var onContentDidChange: ((Bool) -> Void)?

    init(height: CGFloat) {
        self.fixedHeight = height
        super.init(frame: .zero)
    }

    func applyHeight(_ height: CGFloat) {
        fixedHeight = height
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        lastMeasuredWidth = width
        lastMeasureTransition = transition
        measureCount += 1
        return fixedHeight
    }

    func stickDistanceUpdated(_ distance: CGFloat) {
        lastStickDistance = distance
    }
}

/// Fixture attachment descriptor. `label` is the content; two descriptors with the same key but
/// different labels are NOT equal, which is what drives reconfiguration.
final class FixedHeightAttachment: CoreListAttachedItem {
    let label: String
    let height: CGFloat
    let placement: CoreListAttachmentPlacement
    let edge: CoreListAttachmentEdge
    let isFloating: Bool
    /// When false, `combines(with:)` returns false even against an identical key — the fixture's
    /// stand-in for ChatMessageAvatarHeader's 10-minute rule.
    let combinesWithNeighbours: Bool
    let stackingGroup: AnyHashable?
    let stackingYield: (group: AnyHashable, gap: CGFloat)?

    init(label: String,
         height: CGFloat = 30,
         placement: CoreListAttachmentPlacement = .overlay,
         edge: CoreListAttachmentEdge = .top,
         isFloating: Bool = true,
         combinesWithNeighbours: Bool = true,
         stackingGroup: AnyHashable? = nil,
         stackingYield: (group: AnyHashable, gap: CGFloat)? = nil) {
        self.stackingGroup = stackingGroup
        self.stackingYield = stackingYield
        self.label = label
        self.height = height
        self.placement = placement
        self.edge = edge
        self.isFloating = isFloating
        self.combinesWithNeighbours = combinesWithNeighbours
    }

    func view() -> UIView & CoreListAttachedItemView {
        FixedHeightAttachmentView(height: height)
    }

    func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? FixedHeightAttachment else { return false }
        return other.label == label && other.height == height
    }

    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? FixedHeightAttachmentView)?.applyHeight(height)
    }

    func combines(with other: CoreListAttachedItem) -> Bool {
        guard let other = other as? FixedHeightAttachment else { return false }
        return combinesWithNeighbours && other.combinesWithNeighbours
    }
}

/// A fixed-height row that publishes attachments.
final class AttachedItem: CoreListItem {
    let id: AnyHashable
    let height: CGFloat
    let attachedItems: [AnyHashable: CoreListAttachedItem]

    init(id: AnyHashable,
         height: CGFloat = 50,
         attachedItems: [AnyHashable: CoreListAttachedItem] = [:]) {
        self.id = id
        self.height = height
        self.attachedItems = attachedItems
    }

    var identity: AnyHashable { id }

    func view() -> UIView & CoreListItemView {
        FixedHeightItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? AttachedItem else { return false }
        return other.id == id && other.height == height
    }
}
