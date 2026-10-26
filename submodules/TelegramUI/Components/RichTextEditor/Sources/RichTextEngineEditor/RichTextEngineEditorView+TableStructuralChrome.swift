#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// ONE control of a table's structural chrome — a grip or a resize knob — as a real view.
///
/// It was a rect in an array until this rung, drawn by the chrome's `draw` and hit-tested by a
/// parallel loop over the same source. Two loops mean two rules, and the two disagreed: a knob is
/// SHOWN when its centre is inside the run's visible band, while its 44pt hit box reached 22pt
/// further, so a knob scrolled out of the run kept a strip of invisible hit area at the band's edge
/// — and the document's scroll pan yields to knobs, so a drag there resized a selection instead of
/// scrolling the table. As a view there is one geometry (`frame`), one visibility (`isHidden`), and
/// UIKit's own hit-testing; the disagreement has nowhere left to live.
///
/// A knob's frame is its 44pt BOX and its circle is drawn `knobRadius` wide at the centre of it: the
/// generous target is deliberate, and it is now visible in the view tree rather than implied by a
/// hit test that consulted different numbers than the drawing did.
///
/// What each one LOOKS like is legacy's `drawHandleDots` / `drawTableResizeKnobs`, carried over: a
/// grip is three dots — ⋮ in the left gutter for a row, ⋯ below the table for a column — in
/// `secondaryLabel`, and only while its row or column IS the structural selection do they sit on an
/// accent bar and turn `systemBackground`. The bar rounds the two corners on the side AWAY from the
/// table (the other two meet the table's border and stay square), at a radius of the bar's short
/// side, so it reads as a half-capsule hanging off the grid. Those two UIKit semantic colours are
/// legacy's own literals: the editor theme has no entry for either, and matching the look means
/// matching them.
@available(iOS 18.4, *)
internal final class TableStructuralControlView: UIView {
    internal enum Payload {
        /// `active` is the one thing a grip's look turns on: whether its own row or column is the
        /// committed structural selection, exactly legacy's `tableSelection?.kind == h.kind`. `side`
        /// is which gutter it hangs in — the two row grips are a mirrored pair, identical but for it.
        case grip(EngineTableStructuralSelection, active: Bool,
                  side: EngineTableStructuralChrome.HandleSide)
        case knob(end: TableRangeEnd?, corner: TableCellCorner?)

        /// What makes two controls the SAME control across passes — the shape, never the range. A
        /// knob drag changes the selection on every frame, and a view rebuilt under a live pan takes
        /// the gesture down with it, so the knob at a given end keeps its view while it moves.
        internal var key: String {
            switch self {
            case let .grip(_, _, side):
                return "grip.\(side)"
            case let .knob(end, corner):
                if let end { return "knob.end.\(end)" }
                if let corner { return "knob.corner.\(corner)" }
                return "knob"
            }
        }

        internal var isGrip: Bool { if case .grip = self { return true } else { return false } }
    }

    internal private(set) var payload: Payload
    private var accent: UIColor = .tintColor
    /// The accent bar under a SELECTED grip. A plain view with a corner radius on two of its four
    /// corners: it stretches with the selection without a single pixel being redrawn, which is the
    /// whole reason the chrome is a view tree and not a `draw(_:)`.
    private let bar = UIView()
    /// Three of them for a grip, one for a knob — fixed-size circles that do NOT stretch when the
    /// bar does, which is exactly what a stretched bitmap could not have given.
    private var dots: [UIView] = []

    internal init(payload: Payload) {
        self.payload = payload
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        bar.isUserInteractionEnabled = false
        addSubview(bar)
        apply()
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("not supported") }

    internal func update(payload: Payload, accent: UIColor) {
        self.payload = payload
        self.accent = accent
        apply()
        setNeedsLayout()
    }

    /// Test seam: the bar's rounded corners, and nil when there is no bar. Read from where they are
    /// DECLARED rather than from pixels, because `CALayer.render(in:)` — the only way to get a view
    /// tree into a buffer without a window — ignores `maskedCorners` and rounds all four.
    internal var shownBarCorners: CACornerMask? { bar.isHidden ? nil : bar.layer.maskedCorners }

    /// Colours and the piece count — everything that is not a frame. Frames are `layoutSubviews`',
    /// so a control that only moved lays out and nothing else.
    private func apply() {
        let wanted: Int
        let dotColour: UIColor
        switch payload {
        case let .grip(_, active, _):
            wanted = 3
            dotColour = active ? .systemBackground : .secondaryLabel
            bar.isHidden = !active
            bar.backgroundColor = accent
        case .knob:
            wanted = 1
            dotColour = accent
            bar.isHidden = true
        }
        while dots.count > wanted { dots.removeLast().removeFromSuperview() }
        while dots.count < wanted {
            let dot = UIView()
            dot.isUserInteractionEnabled = false
            addSubview(dot)
            dots.append(dot)
        }
        for dot in dots { dot.backgroundColor = dotColour }
    }

    /// Legacy's `drawHandleDots` geometry, as frames.
    override func layoutSubviews() {
        super.layoutSubviews()
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        switch payload {
        case let .grip(_, _, side):
            let horizontal = side == .below
            bar.frame = bounds
            // The bar rounds only the two corners AWAY from the table; the two meeting its border
            // stay square. `min(width, height)` is legacy's radius, which both a bezier path and a
            // layer clamp to half the short side.
            bar.layer.cornerRadius = min(bounds.width, bounds.height) / 2
            switch side {
            case .below: bar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            case .leading: bar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            case .trailing: bar.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            }
            let diameter = EngineTableStructuralChrome.gripDotDiameter
            let gap = EngineTableStructuralChrome.gripDotGap
            for (index, dot) in dots.enumerated() {
                let offset = CGFloat(index - 1) * (diameter + gap)
                let x = horizontal ? centre.x + offset : centre.x
                let y = horizontal ? centre.y : centre.y + offset
                dot.frame = CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                   width: diameter, height: diameter)
                dot.layer.cornerRadius = diameter / 2
            }
        case .knob:
            let radius = EngineTableStructuralChrome.knobRadius
            for dot in dots {
                dot.frame = CGRect(x: centre.x - radius, y: centre.y - radius,
                                   width: radius * 2, height: radius * 2)
                dot.layer.cornerRadius = radius
            }
        }
    }
}

/// R7-tables rung B — the structural chrome: the selection outline, the two grips, the resize knobs.
///
/// A SECOND per-table view, not the existing `TableChromeView`, which is grid-sized, sits BEHIND the
/// cells and is non-interactive. The outline must draw over the text, and the grips sit outside the
/// grid — the row grip in the left gutter, the column grip below the table.
///
/// This view draws the OUTLINE and nothing else. Every control is a child view, which is what makes
/// the drawn chrome and the touchable chrome one object rather than two derivations that have to be
/// kept in step.
@available(iOS 18.4, *)
internal final class TableStructuralChromeView: UIView {
    /// Only for the pass that has no geometry to derive one from; every real pass supplies it.
    internal static let defaultTableOrigin = CGPoint(x: EngineTableStructuralChrome.gripWidth
                                                     - EngineTableStructuralChrome.gripTuck,
                                                     y: EngineTableStructuralChrome.knobOverhang)

    private var chrome: EngineTableStructuralChrome?
    private var contentOffsetX: CGFloat = 0
    private var accent: UIColor = .tintColor
    /// Where the table's own top-left sits inside this view. This view IS the table's clip window,
    /// so the table's position within it is a per-table number, not a constant: at the top level the
    /// window is the whole canvas and the table sits a text inset into it; nested, the window is the
    /// container's interior and the table sits at its very edge.
    private var tableOrigin = CGPoint(x: EngineTableStructuralChrome.gripWidth
                                      - EngineTableStructuralChrome.gripTuck,
                                      y: EngineTableStructuralChrome.knobOverhang)
    private var controls: [TableStructuralControlView] = []
    /// The selection outline: a view whose LAYER carries the stroke, as a border inside its own
    /// rounded edge. Resizing it — which a knob drag does on every frame — moves a layer and redraws
    /// nothing, where the stroked path had to be rasterised again for each pixel of the drag.
    private let outline = UIView()

    /// A grip was tapped. The chrome owns its recognisers because it owns the control views; the
    /// editor owns what a tap MEANS.
    internal var onGripTapped: ((EngineTableStructuralSelection) -> Void)?
    /// A knob is being dragged. The knob's identity travels with the gesture because it IS the view
    /// the gesture is attached to — the drag can no longer jump to another knob as the outline moves
    /// under the finger, which used to need a `began`-only lookup and a stored result.
    internal var onKnobDragged: ((UIPanGestureRecognizer, TableRangeEnd?, TableCellCorner?) -> Void)?

    /// Is the run holding this table MOVING right now? While it is, this whole view declines every
    /// hit, so a finger landing on a grip or a knob reaches the run beneath and catches it.
    ///
    /// Asked of the owner rather than answered here: this view is parented to the ENGINE, not into
    /// the run (the row grip would ride the horizontal scroll out of the gutter), so walking up from
    /// a control finds no run to ask.
    internal var runIsInFlight: (() -> Bool)?

    /// The band the chrome shows through: THIS VIEW, which the host frames as the table's clip
    /// window — the same window the engine clips the cells to. Unbounded vertically, because a grip
    /// and the outline are cut horizontally and nowhere else. A grip whose column has scrolled out
    /// of the window is neither drawn floating beside the table nor hittable there, which is what
    /// legacy's `drawTableChrome` clip did.
    private var visibleBand: CGRect {
        CGRect(x: bounds.minX, y: -1e6, width: bounds.width, height: 2e6)
    }

    /// A control, or nothing. The view spans the whole table so its grips can hang outside the grid,
    /// but over the BODY it must not exist for touches: the run's horizontal pan is hosted by the
    /// stack canvas BENEATH this view, which is not inside it, and the engine's text tap is cancelled
    /// by a recogniser here that receives the touch even if it does nothing with it. Measured on
    /// device before this (K3, 2026-09-10): with the caret in a wide table, a swipe scrolled nothing
    /// and a tap on another cell moved no caret.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // TRANSPARENT WHILE THE TABLE IS MOVING, so the touch reaches the run and CATCHES it.
        //
        // Refusing the grip's own recogniser is not enough, and that is what shipped first: the
        // controls still swallowed the touch, and because this chrome is parented to the ENGINE
        // rather than into the run, the run's pan — hosted on the canvas below — was never offered
        // it. Nothing caught the table and nothing else happened either ("we don't catch the table
        // over handles, the touch just doesn't do anything", K3). Declining the hit hands the touch
        // to the canvas, where a catch is the ordinary path; the control cannot fire because it
        // never receives it.
        guard !(runIsInFlight?() ?? false) else { return false }
        // A KNOB CLAIMS A DRAG, NOT A TAP, so its box must not swallow one. Measured on a 4-column
        // table: the focused cell's four 44pt knob boxes cover **77%** of an 87x34 cell, and while
        // they were hit-testable every touch there died on a view with only a pan attached — no
        // caret, and no edit menu ("almost impossible to invoke the context menu by tapping in a
        // cell when focused", K3). 44pt is the right DRAG target and the wrong tap target, so the
        // knob's drag moved to a pan on the editor (`tableKnobPan`) which competes for the gesture
        // without taking the touch: the tap reaches the text interaction as it does in body text.
        // Grips keep their hit, because a grip IS a tap.
        return handle(at: point) != nil
    }

    /// Test seams — what the chrome actually shows. Derived from the views themselves, so they
    /// cannot describe anything but what is on screen and touchable.
    internal var drawnOutlineRect: CGRect? { outline.isHidden ? nil : outline.frame }
    internal var drawnHandleRects: [CGRect] {
        controls.filter { !$0.isHidden && $0.payload.isGrip }.map(\.frame)
    }
    internal var drawnKnobRects: [CGRect] {
        controls.filter { !$0.isHidden && !$0.payload.isGrip }.map(\.frame)
    }
    /// The control views themselves, for the checks that ask what carries which recogniser.
    internal var controlViews: [TableStructuralControlView] { controls }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = true
        // The visible band's only effective edge is the right one, and it sits exactly on this
        // view's own width (`visibleBand`), so the clip the drawn version installed per pass is
        // this flag. Hit-testing is unaffected — `point(inside:)` answers for the controls, and a
        // knob's 44pt box may legitimately reach past the top edge while only its 4pt circle shows.
        clipsToBounds = true
        outline.isUserInteractionEnabled = false
        outline.backgroundColor = .clear
        addSubview(outline)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("not supported") }

    /// The offset the last `update` supplied — the drag converts a view point back to table-local and
    /// must undo exactly the shift `viewRect` applied, and the placement check compares it against
    /// the run's offset NOW. The chrome's own frame does not move when the run scrolls (it is
    /// anchored at the table's unscrolled origin), so this value is the only thing that says whether
    /// the chrome has been told about a scroll: it is what went stale when the outline, the knobs
    /// and the column grip stayed put while the cells moved under them.
    internal var currentContentOffsetX: CGFloat { contentOffsetX }
    /// Likewise for where the table sits in the window: the origin the last `update` supplied.
    internal var currentTableOrigin: CGPoint { tableOrigin }

    internal func update(chrome: EngineTableStructuralChrome, contentOffsetX: CGFloat,
                         tableOrigin: CGPoint, accent: UIColor) {
        self.chrome = chrome
        self.contentOffsetX = contentOffsetX
        self.tableOrigin = tableOrigin
        self.accent = accent
        reconcileOutline()
        reconcileControls()
    }

    /// Table-local → view-local. EVERY piece of the chrome rides the table's horizontal scroll —
    /// the outline, the knobs, and both row grips, which hang off the table's own left and right
    /// edges rather than sitting in a gutter the viewport owns. (The row grip was the one exception
    /// until 2026-09-11, anchored to the table's unscrolled left edge.)
    internal func viewRect(_ tableLocal: CGRect) -> CGRect {
        tableLocal.offsetBy(dx: tableOrigin.x - contentOffsetX, dy: tableOrigin.y)
    }

    /// Every control the chrome wants, placed and with its visibility decided — the ONE derivation
    /// the views are built from. A grip that straddles the band's edge is shown clipped; a knob is
    /// shown when its CENTRE is inside, because a 44pt box hanging off the edge is a target with no
    /// visible control on it.
    private func desiredControls() -> [(payload: TableStructuralControlView.Payload,
                                        frame: CGRect, visible: Bool)] {
        guard let chrome else { return [] }
        let band = visibleBand
        var result: [(TableStructuralControlView.Payload, CGRect, Bool)] = []
        for knob in chrome.knobs() {
            let placed = viewRect(knob.rect)
            let centre = CGPoint(x: placed.midX, y: placed.midY)
            result.append((.knob(end: knob.end, corner: knob.corner), placed, band.contains(centre)))
        }
        // Grips AFTER the knobs, so they end up above them in the view tree: a knob's 44pt box on the
        // table's left edge reaches 22pt into the gutter, over the row grip of its own row, and a
        // touch there is the grip's — a tap selects the row and a drag is the document's scroll.
        for handle in chrome.handles() {
            // Every grip rides the scroll now, the row grips included: each hangs off an EDGE of the
            // table, and an edge that has scrolled out of the run takes its grip with it.
            let placed = viewRect(handle.rect)
            result.append((.grip(handle.kind, active: chrome.selection == handle.kind, side: handle.side),
                           placed, placed.intersects(band)))
        }
        return result
    }

    /// Reused by KEY, never rebuilt wholesale: a view replaced under a live pan takes the gesture
    /// down with it, and a knob drag updates the chrome on every frame.
    private func reconcileControls() {
        var existing: [String: TableStructuralControlView] = [:]
        for control in controls { existing[control.payload.key] = control }
        var live: [TableStructuralControlView] = []
        for desired in desiredControls() {
            let control: TableStructuralControlView
            if let reused = existing.removeValue(forKey: desired.payload.key) {
                control = reused
            } else {
                control = TableStructuralControlView(payload: desired.payload)
                if desired.payload.isGrip {
                    control.addGestureRecognizer(
                        UITapGestureRecognizer(target: self, action: #selector(handleGripTap(_:))))
                } else {
                    // Drawing only — see `point(inside:)`. The drag is the editor's `tableKnobPan`.
                    control.isUserInteractionEnabled = false
                }
                addSubview(control)
            }
            control.update(payload: desired.payload, accent: accent)
            if control.frame != desired.frame { control.frame = desired.frame }
            control.isHidden = !desired.visible
            bringSubviewToFront(control)
            live.append(control)
        }
        for orphan in existing.values { orphan.removeFromSuperview() }
        controls = live
    }

    /// The control under a point in THIS view's space, hidden ones excluded — the same answer UIKit's
    /// hit-testing gives, because the frames and the visibility are the same.
    private func control(at point: CGPoint) -> TableStructuralControlView? {
        controls.reversed().first { !$0.isHidden && $0.frame.contains(point) }
    }

    /// Is there a control — grip or knob — under this point?
    ///
    /// Deliberately NOT `point(inside:)`, which the two questions used to share. Hit-testing answers
    /// "does this view take the touch", and a knob does not: its 44pt box is a drag target that must
    /// leave the tap beneath it alone. This answers "is a control HERE", which is what the text
    /// interaction's veto needs — a DRAG starting on a knob is still the knob's.
    internal func containsControl(at point: CGPoint) -> Bool {
        control(at: point) != nil
    }

    /// The grip under a point, or nil.
    internal func handle(at point: CGPoint) -> EngineTableStructuralSelection? {
        guard let control = control(at: point), case let .grip(kind, _, _) = control.payload else { return nil }
        return kind
    }

    /// The knob under a point, or nil. A GRIP wins, which the view order already decides.
    internal func knob(at point: CGPoint) -> (end: TableRangeEnd?, corner: TableCellCorner?)? {
        guard let control = control(at: point), case let .knob(end, corner) = control.payload else { return nil }
        return (end, corner)
    }

    @objc private func handleGripTap(_ recognizer: UITapGestureRecognizer) {
        guard let control = recognizer.view as? TableStructuralControlView,
              case let .grip(kind, _, _) = control.payload else { return }
        onGripTapped?(kind)
    }

    /// The outline's frame, colour and corners. A stroked path inset by half its width is the same
    /// shape as a layer border on the UNINSET rect: the border is painted inside the layer's edge,
    /// so the outer edge lands where the stroke's did, and the radius carries the same half width.
    private func reconcileOutline() {
        guard let chrome, let rect = chrome.outlineRect() else {
            outline.isHidden = true
            return
        }
        let width = EngineTableStructuralChrome.outlineWidth
        outline.isHidden = false
        outline.frame = viewRect(rect)
        outline.layer.borderWidth = width
        outline.layer.borderColor = accent.cgColor
        outline.layer.cornerRadius = EngineTableGrid.outerCornerRadius + width / 2
        outline.layer.maskedCorners = Self.mask(chrome.outlineCorners())
        sendSubviewToBack(outline)
    }

    /// `UIRectCorner` (what the chrome model speaks, and legacy before it) → `CACornerMask`.
    private static func mask(_ corners: UIRectCorner) -> CACornerMask {
        if corners.contains(.allCorners) {
            return [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        var mask: CACornerMask = []
        if corners.contains(.topLeft) { mask.insert(.layerMinXMinYCorner) }
        if corners.contains(.topRight) { mask.insert(.layerMaxXMinYCorner) }
        if corners.contains(.bottomLeft) { mask.insert(.layerMinXMaxYCorner) }
        if corners.contains(.bottomRight) { mask.insert(.layerMaxXMaxYCorner) }
        return mask
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The table whose structural chrome is showing: the committed selection's, else the caret's.
    internal func structurallyChromedTable() -> (shape: TableShape, roles: Range<Int>)? {
        if let selection = tableStructuralSelection,
           let roles = roleRun(ofTableWithID: selection.table),
           let table = currentRoles[roles.lowerBound].owningTable {
            return (table, roles)
        }
        return tableAtCaret()
    }

    /// Reconciles the structural chrome against the laid-out document. Idempotent; runs after layout.
    internal func syncTableStructuralChrome() {
        var live: Set<BlockID> = []
        if let (table, roles) = structurallyChromedTable(),
           let grid = tableGrids[table.id],
           let frame = structuralChromeFrame(forTableAt: roles.lowerBound) {
            live.insert(table.id)
            let view: TableStructuralChromeView
            if let existing = tableStructuralChromeViews[table.id] {
                view = existing
            } else {
                let fresh = TableStructuralChromeView()
                fresh.onGripTapped = { [weak self] kind in self?.selectTableStructure(kind) }
                fresh.onKnobDragged = { [weak self] recognizer, end, corner in
                    self?.dragTableStructuralKnob(recognizer, end: end, corner: corner)
                }
                fresh.runIsInFlight = { [weak self] in
                    guard let self, let (_, roles) = self.structurallyChromedTable() else { return false }
                    return self.placedRunIsInFlight(forTableAt: roles.lowerBound)
                }
                tableStructuralChromeViews[table.id] = fresh
                view = fresh
            }
            // Into the ENGINE, not the run's content view: parented there the ROW grip would ride the
            // table's horizontal scroll and slide out of the gutter. The offset is applied per element
            // instead, which is what `viewRect(_:)` is for. Added late in the layout pass, so
            // it sits above the placed run that holds the cells and the outline draws over the text.
            if view.superview !== engine { view.removeFromSuperview(); engine.addSubview(view) }
            if view.frame != frame { view.frame = frame }
            let map = TableMap(table.emptyTable)
            view.update(chrome: EngineTableStructuralChrome(grid: grid,
                                                            rowCount: map.rows, columnCount: map.columns,
                                                            selection: tableStructuralSelection?.kind,
                                                            focusedCell: focusedOrSelectedCellRect()),
                        contentOffsetX: engine.id_placedRunContentOffsetForBlock(at: UInt(roles.lowerBound)),
                        tableOrigin: structuralChromeTableOrigin(forTableAt: roles.lowerBound)
                            ?? TableStructuralChromeView.defaultTableOrigin,
                        accent: composerHostState.theme.accent)
        }
        for (id, view) in tableStructuralChromeViews where !live.contains(id) {
            view.removeFromSuperview()
            tableStructuralChromeViews[id] = nil
        }
    }

    /// Selects the row or column whose grip was tapped. Legacy's gesture: the first tap on a grip
    /// SELECTS, a second on the same one opens the menu.
    internal func selectTableStructure(_ hit: EngineTableStructuralSelection) {
        if tableStructuralSelection?.kind == hit, let request = tableStructuralMenuRequest() {
            deferredConfiguration.onRequestTableStructuralMenu?(request)
            return
        }
        switch hit {
        case let .rows(range): selectTableRows(range)
        case let .columns(range): selectTableColumns(range)
        case .cells: break   // no grip produces a cell rect; the corner knobs do that.
        }
    }

    /// The same verb entered by a point rather than by a control — the route the tests drive, and the
    /// one `handle(at:)` resolves for them.
    internal func handleTableStructuralTap(atPointInChrome point: CGPoint) {
        guard let (table, _) = structurallyChromedTable(),
              let view = tableStructuralChromeViews[table.id],
              let hit = view.handle(at: point) else { return }
        selectTableStructure(hit)
    }

    /// A knob drag. WHICH knob is the gesture's own view, so it cannot change mid-drag — that used to
    /// be a `began`-only lookup into a stored property, for exactly this reason.
    internal func dragTableStructuralKnob(_ recognizer: UIPanGestureRecognizer,
                                          end: TableRangeEnd?, corner: TableCellCorner?) {
        guard let (table, _) = structurallyChromedTable(),
              let chrome = tableStructuralChromeViews[table.id] else { return }
        let point = recognizer.location(in: chrome)
        let tableLocal = CGPoint(x: point.x - chrome.currentTableOrigin.x + chrome.currentContentOffsetX,
                                 y: point.y - chrome.currentTableOrigin.y)
        guard recognizer.state == .changed else { return }
        if let end {
            extendTableSelection(end: end, towardTableLocal: tableLocal)
        } else if let corner {
            extendCellSelection(corner: corner, towardTableLocal: tableLocal)
        }
    }

    /// Whether a point in the ENGINE's space lands on one of the chrome's controls.
    ///
    /// Measured against the control's OWN box, never an inflated hit target: R7-details records what
    /// the other choice cost — 12pt of slop on the chevron reached 7pt past the title's first glyph,
    /// so tapping the first character folded the block instead of placing a caret.
    ///
    /// Asks `containsControl(at:)` and NOT `point(inside:)`: since a knob stopped claiming touches,
    /// hit-testing answers a narrower question than this one does. Derived from `point(inside:)` the
    /// veto silently lost the knobs, and a text DRAG began on top of a knob drag.
    internal func tableStructuralControlContains(pointInEngine point: CGPoint) -> Bool {
        guard let (table, _) = structurallyChromedTable(),
              let view = tableStructuralChromeViews[table.id] else { return false }
        return view.containsControl(at: engine.convert(point, to: view))
    }

    /// Whether a point in the ENGINE's space lands on a resize KNOB — the one control the document's
    /// own scroll pan yields to (`tgid_shouldBeginScrollPanHandler`). A grip is deliberately not
    /// included: it is a tap target, and a drag that starts on it is still the document's scroll, as
    /// it is in legacy (`GripYieldingScrollView` yields to `isSelectionDragTouch`, the knobs).
    internal func tableStructuralKnobContains(pointInEngine point: CGPoint) -> Bool {
        guard let (table, _) = structurallyChromedTable(),
              let view = tableStructuralChromeViews[table.id] else { return false }
        return view.knob(at: engine.convert(point, to: view)) != nil
    }

    /// Whether a point in the ENGINE's space lands on a GRIP — the one control a TAP belongs to. A tap
    /// over a knob is the text's (a knob view carries a pan and no tap, so it never cancels the text's
    /// tap), so the engine's text tap is refused over grips only; a drag is refused over both.
    internal func tableStructuralGripContains(pointInEngine point: CGPoint) -> Bool {
        guard let (table, _) = structurallyChromedTable(),
              let view = tableStructuralChromeViews[table.id] else { return false }
        return view.handle(at: engine.convert(point, to: view)) != nil
    }
}
#endif
