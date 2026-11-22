import UIKit

final class DemoListItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let title: String
    let detail: String
    let accentColor: UIColor
    /// A height floor imposed by the item (item-derived content). The explicit init's default keeps the
    /// `minHeight` parameter optional, so the existing `DemoListItem(id:title:detail:accentColor:)`
    /// call sites still compile.
    let minHeight: CGFloat
    /// Which attachment run this row belongs to. Rows sharing a groupIndex form one run.
    let groupIndex: Int
    /// Whether this row renders a nested horizontally scrolling strip. The demo's stand-in for chat's
    /// in-bubble scrollers (the joined-channel carousel, a rich-message table) — the shape that
    /// exposed the scroll-pan arbitration bug. Off by default so existing fixtures are unchanged.
    let hasNestedScroller: Bool

    init(id: UUID,
         title: String,
         detail: String,
         accentColor: UIColor,
         minHeight: CGFloat = 0,
         groupIndex: Int = 0,
         hasNestedScroller: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.accentColor = accentColor
        self.minHeight = minHeight
        self.groupIndex = groupIndex
        self.hasNestedScroller = hasNestedScroller
    }

    /// The group index is part of the KEY, not merely the content: a run is identified by key, so two
    /// adjacent groups must publish different keys to be different runs. (`ChatMessageDateHeader`
    /// does the same, folding its rounded timestamp into its id.)
    var attachedItems: [AnyHashable: CoreListAttachedItem] {
        [
            "date\(groupIndex)": DemoDateHeader(title: "Group \(groupIndex)"),
            "avatar\(groupIndex)": DemoAvatar(color: accentColor, initial: "\(groupIndex % 10)"),
        ]
    }

    func view() -> (UIView & CoreListItemView) {
        DemoListItemView(title: title, detail: detail, accentColor: accentColor,
                         minHeight: minHeight, hasNestedScroller: hasNestedScroller)
    }

    // Content equality (design 2026-05-31 §4). The engine matches rows by `identity` (= id); this
    // `isEqual` compares `minHeight` — the demo's only mutable content (title/detail/accentColor are
    // fixed per id, so this is equivalent to comparing all content). A same-id row whose minHeight
    // changed is NOT equal, so it reconciles + animates its height.
    func isEqual(to other: CoreListItem) -> Bool {
        guard let o = other as? DemoListItem else { return false }
        // title/detail/accentColor are fixed per id in the demo; groupIndex is not — the Groups
        // control changes it, which is what makes runs split and merge.
        return o.id == id && o.minHeight == minHeight && o.groupIndex == groupIndex
            && o.hasNestedScroller == hasNestedScroller
    }

    // Hand the reused/recycled view this item's new external state (minHeight; title/detail/accent are
    // fixed per id). This view's mechanics happen to leave its internal state (isExpanded/extraHeight)
    // alone on a minHeight change — a VIEW choice, not an engine contract.
    /// NOTE the `transition:` parameter. Without it this does NOT satisfy
    /// `CoreListItem.apply(to:transition:)` — Swift silently binds the protocol extension's no-op
    /// default and this method becomes dead code, so content reconciliation never reaches the view
    /// and every size-changing demo action does nothing.
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? DemoListItemView)?.applyMinHeight(minHeight)
    }
}

final class DemoListItemView: UIView, CoreListItemView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let pillView = UIView()

    private let titleText: String
    private let detailText: String
    private let accentColor: UIColor
    private var isExpanded = false
    /// Programmatic height growth (via `grow(by:)`) — orthogonal to the tap-driven `isExpanded`.
    /// Used by the demo's "Grow center" test button to trigger a self-update without going through
    /// the tap recognizer (taps are absorbed by `PhysicsScrollEngine` mid-deceleration; this
    /// affordance is the only way to trigger a mid-flight self-update for 4c manual testing).
    private var extraHeight: CGFloat = 0
    /// Item-derived height floor (set from `DemoListItem.minHeight`, reconfigured via `applyMinHeight`).
    /// Orthogonal to the view-only `isExpanded`/`extraHeight`; the natural/expanded/grown height still
    /// wins when larger.
    private var minHeight: CGFloat
    /// The nested horizontally scrolling strip, or nil. Deliberately a plain `UIScrollView` with a
    /// default delegate: the point is that its own `shouldRecognizeSimultaneouslyWith` denies
    /// simultaneity (the UIKit default), exactly like chat's in-bubble scrollers.
    private let nestedScroller: UIScrollView?
    private static let nestedScrollerHeight: CGFloat = 44
    var onContentDidChange: ((Bool) -> Void)?

    init(title: String, detail: String, accentColor: UIColor, minHeight: CGFloat = 0,
         hasNestedScroller: Bool = false) {
        self.titleText = title
        self.detailText = detail
        self.accentColor = accentColor
        self.minHeight = minHeight
        self.nestedScroller = hasNestedScroller ? UIScrollView() : nil
        super.init(frame: .zero)

        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 1.0
        backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : .secondarySystemBackground
        }

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .label
        titleLabel.text = titleText

        detailLabel.font = .systemFont(ofSize: 14, weight: .regular)
        detailLabel.numberOfLines = 0
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = detailText
        detailLabel.isHidden = true

        pillView.layer.cornerRadius = 6
        pillView.layer.cornerCurve = .continuous
        pillView.backgroundColor = accentColor

        addSubview(pillView)
        addSubview(titleLabel)
        addSubview(detailLabel)

        if let nestedScroller {
            nestedScroller.alwaysBounceHorizontal = true
            nestedScroller.alwaysBounceVertical = false
            nestedScroller.showsHorizontalScrollIndicator = false
            nestedScroller.showsVerticalScrollIndicator = false
            nestedScroller.contentInsetAdjustmentBehavior = .never
            nestedScroller.clipsToBounds = true
            nestedScroller.layer.cornerRadius = 10
            nestedScroller.layer.cornerCurve = .continuous
            for chipIndex in 0..<12 {
                let chip = UILabel(frame: CGRect(x: CGFloat(chipIndex) * 84 + 8, y: 6,
                                                 width: 76, height: 32))
                chip.text = "Chip \(chipIndex)"
                chip.textAlignment = .center
                chip.textColor = .white
                chip.font = .systemFont(ofSize: 13, weight: .semibold)
                chip.backgroundColor = accentColor.withAlphaComponent(0.85)
                chip.layer.cornerRadius = 8
                chip.clipsToBounds = true
                nestedScroller.addSubview(chip)
            }
            nestedScroller.contentSize = CGSize(width: 12 * 84 + 16, height: Self.nestedScrollerHeight)
            addSubview(nestedScroller)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        detailLabel.isHidden = !isExpanded
        onContentDidChange?(true)
    }

    /// Programmatic height growth (for the demo's "Grow center" test button). Adds `additional`
    /// points to the row's `update(width:)` return value and signals the list to re-measure +
    /// animate via the same dirty-flush path that `toggleExpanded` uses.
    func grow(by additional: CGFloat) {
        extraHeight += additional
        onContentDidChange?(true)
    }

    /// Adopt the new item-derived height floor (content reconcile). This view's mechanic leaves its
    /// internal `isExpanded`/`extraHeight` state untouched on a minHeight change (a VIEW choice, not an
    /// engine contract). The next `update(width:)` reflects the new floor.
    func applyMinHeight(_ h: CGFloat) {
        minHeight = h
    }

    /// Lays out through the transition, which is what exercises the executor end-to-end in the demo.
    /// `setFrame` writes the settled value synchronously before animating, so `titleLabel.frame.maxY`
    /// below still reads the NEW layout, exactly as the old direct assignment did.
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let contentInsets = UIEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        let pillSize = CGSize(width: 12, height: 12)
        let labelWidth = max(0, width - contentInsets.left - contentInsets.right)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height

        transition.setFrame(view: pillView, frame: CGRect(x: contentInsets.left, y: contentInsets.top + 2, width: pillSize.width, height: pillSize.height))
        transition.setFrame(view: titleLabel, frame: CGRect(x: contentInsets.left, y: contentInsets.top + pillSize.height + 10, width: labelWidth, height: titleHeight))

        var totalHeight = contentInsets.top + pillSize.height + 10 + titleHeight + contentInsets.bottom
        if let nestedScroller {
            transition.setFrame(view: nestedScroller,
                                frame: CGRect(x: contentInsets.left,
                                              y: titleLabel.frame.maxY + 8,
                                              width: labelWidth,
                                              height: Self.nestedScrollerHeight))
            totalHeight += 8 + Self.nestedScrollerHeight
        }
        if isExpanded {
            let detailHeight = detailLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height
            let detailY = (nestedScroller?.frame.maxY ?? titleLabel.frame.maxY) + 8
            transition.setFrame(view: detailLabel, frame: CGRect(x: contentInsets.left, y: detailY, width: labelWidth, height: detailHeight))
            totalHeight += 8 + detailHeight
        }

        return max(ceil(totalHeight + extraHeight), minHeight)
    }
}

/// Space-reserving floating date-style header: the classic sticky section header.
final class DemoDateHeader: CoreListAttachedItem {
    let title: String

    init(title: String) { self.title = title }

    var placement: CoreListAttachmentPlacement { .reservesSpace }
    var edge: CoreListAttachmentEdge { .top }
    var isFloating: Bool { true }

    func view() -> UIView & CoreListAttachedItemView { DemoDateHeaderView(title: title) }

    func isEqual(to other: CoreListAttachedItem) -> Bool {
        (other as? DemoDateHeader)?.title == title
    }

    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? DemoDateHeaderView)?.setTitle(title)
    }
}

final class DemoDateHeaderView: UIView, CoreListAttachedItemView {
    private let pill = UILabel()
    var onContentDidChange: ((Bool) -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        pill.font = .systemFont(ofSize: 13, weight: .semibold)
        pill.textAlignment = .center
        pill.textColor = .white
        pill.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        pill.layer.cornerRadius = 11
        pill.layer.cornerCurve = .continuous
        pill.clipsToBounds = true
        pill.text = title
        addSubview(pill)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ title: String) { pill.text = title }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let size = pill.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let pillWidth = min(width - 32, size.width + 24)
        transition.setFrame(view: pill,
                            frame: CGRect(x: (width - pillWidth) / 2, y: 6,
                                          width: pillWidth, height: 22))
        return 34
    }
}

/// In-run overlay floating avatar: sits at the run's last row and rides the display bottom.
final class DemoAvatar: CoreListAttachedItem {
    let color: UIColor
    let initial: String

    init(color: UIColor, initial: String) {
        self.color = color
        self.initial = initial
    }

    var placement: CoreListAttachmentPlacement { .overlay }
    var edge: CoreListAttachmentEdge { .bottom }
    var isFloating: Bool { true }

    func view() -> UIView & CoreListAttachedItemView {
        DemoAvatarView(color: color, initial: initial)
    }

    func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? DemoAvatar else { return false }
        return other.initial == initial && other.color == color
    }
}

final class DemoAvatarView: UIView, CoreListAttachedItemView {
    private let bubble = UILabel()
    var onContentDidChange: ((Bool) -> Void)?

    init(color: UIColor, initial: String) {
        super.init(frame: .zero)
        bubble.backgroundColor = color
        bubble.textColor = .white
        bubble.textAlignment = .center
        bubble.font = .systemFont(ofSize: 15, weight: .bold)
        bubble.text = initial
        bubble.layer.cornerRadius = 16
        bubble.clipsToBounds = true
        addSubview(bubble)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        transition.setFrame(view: bubble, frame: CGRect(x: 6, y: 0, width: 32, height: 32))
        return 32
    }
}

extension DemoListItem {
    static func makeItems(count: Int = 180, groupSize: Int = 6, nestedScrollerEvery: Int = 0) -> [DemoListItem] {
        let accents: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemRed, .systemTeal, .systemIndigo]

        return (0..<count).map { index in
            let detail: String
            switch index % 4 {
            case 0: detail = "Only visible items are instantiated and measured."
            case 1: detail = "The list keeps a large scroll range and rebuilds the live window as needed."
            case 2: detail = "Nearby targets scroll through shared rows; distant targets use a one-window carousel."
            default: detail = "Overlapping windows reuse the same view instances for shared rows."
            }

            return DemoListItem(
                id: UUID(),
                title: "Row \(index)",
                detail: detail,
                accentColor: accents[index % accents.count],
                groupIndex: index / max(1, groupSize),
                hasNestedScroller: nestedScrollerEvery > 0 && index % nestedScrollerEvery == 0
            )
        }
    }
}
