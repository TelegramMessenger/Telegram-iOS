#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// A detail block's fold chevron: a pooled host view in the gutter, positioned from the title's frame.
///
/// A gutter VIEW for the same reason a list marker is one — the engine's text is the one copy of the
/// characters, so a chevron drawn into the text would shift every canonical offset after it and move
/// selection, the flat geometry and every surface-gate rule with it (see `+ListMarkers.swift`).
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// One chevron per details in `currentRoles`, keyed by the details' own id — NOT its title line's,
    /// which is a separate view-pool identity (`DetailsShape.titleLineID`).
    internal func syncDetailsChrome() {
        guard !currentRoles.isEmpty || !detailsChevronViews.isEmpty else { return }
        var live: Set<BlockID> = []

        for (index, role) in currentRoles.enumerated() {
            // The TITLE carries the chevron: it is the details' first role, and the one role a folded
            // details still has. Keyed on the role being the title of the ancestor that owns it, so a
            // details' body children do not each mint one.
            guard role.secondaryKind == .detailsTitle,
                  let details = role.innermostAncestor?.details,
                  details.titleLineID == role.blockID else { continue }
            let frame = engine.id_frameForBlock(at: UInt(index))
            // CGRectNull is the engine's answer for an unknown index — never treated as a rect.
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }

            // The chevron sits OUTSIDE the title's glyph indent, at the container indent — which for
            // the details itself is 0, so this is whatever encloses it. `contentIndent` already
            // excludes the details' own contribution (§3.4).
            let enclosing = role.ancestry.dropLast()
                .contentIndent(styleSheet: bridge.styleSheet)
            let leading = engine.textContainerInset.left + enclosing + DetailsShape.chevronLeadingInset
            live.insert(details.id)
            syncChevron(id: details.id, expanded: details.expanded, leading: leading,
                        centredOn: frame.midY)
        }

        for (id, view) in detailsChevronViews where !live.contains(id) {
            view.removeFromSuperview()
            detailsChevronViews.removeValue(forKey: id)
        }
    }

    private func syncChevron(id: BlockID, expanded: Bool, leading: CGFloat, centredOn midY: CGFloat) {
        let view: DetailsChevronView
        if let existing = detailsChevronViews[id] {
            view = existing
        } else {
            let fresh = DetailsChevronView()
            fresh.contentMode = .scaleAspectFit
            // The chevron IS the interaction (§8.2), so it carries its own tap — the same shape the
            // list checkbox uses. This said the opposite and set `isUserInteractionEnabled = false`,
            // claiming a canvas gesture consulted `detailsChevron(at:)`; there was no such gesture,
            // and folding was unreachable outside XCTest for the whole rung.
            fresh.isUserInteractionEnabled = true
            fresh.addGestureRecognizer(gatedTapRecognizer(action: #selector(handleDetailsChevronTap(_:))))
            engine.addSubview(fresh)
            detailsChevronViews[id] = fresh
            view = fresh
        }
        view.image = deferredConfiguration.detailsChevronImage ?? Self.drawnChevron
        view.tintColor = composerHostState.theme.secondaryText
        let side = DetailsShape.chevronSize
        // The transform is set BEFORE the frame, and the frame is set on the untransformed view:
        // assigning `frame` while a rotation is applied re-derives `bounds`/`center` from the
        // transformed rect, so a 180° chevron would drift by any rounding in the round trip.
        view.transform = .identity
        view.frame = CGRect(x: leading, y: midY - side / 2.0, width: side, height: side)
        // Legacy draws the arrow pointing DOWN when collapsed and rotates it 180° when expanded.
        view.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
    }

    /// The details whose chevron contains `point` (canvas space), with legacy's ±12pt touch inset and
    /// DEEPEST first, so a nested details' chevron is reachable rather than shadowed by its ancestor's.
    internal func detailsChevron(at point: CGPoint) -> BlockID? {
        let hits = detailsChevronViews.filter {
            $0.value.frame.insetBy(dx: -Self.chevronTouchInset, dy: -Self.chevronTouchInset).contains(point)
        }
        guard !hits.isEmpty else { return nil }
        // Depth is the chevron's own nesting: the title role that owns it carries the ancestry.
        func depth(of id: BlockID) -> Int {
            currentRoles.first { $0.innermostAncestor?.details?.id == id }?.containerDepth ?? 0
        }
        return hits.keys.max { depth(of: $0) < depth(of: $1) }
    }

    @objc private func handleDetailsChevronTap(_ recognizer: UITapGestureRecognizer) {
        // Resolved in the ENGINE's space rather than the tapped view's: `detailsChevron(at:)` is the
        // arbiter, and it compares frames that live there.
        toggleDetails(atChevronPoint: recognizer.location(in: engine))
    }

    /// A tap at `point` (engine content space) on whichever chevron owns it. The arbitration stays
    /// `detailsChevron(at:)`'s — deepest-first — rather than the view hierarchy's z-order, which is
    /// the pool's insertion order and says nothing about nesting.
    @discardableResult
    internal func toggleDetails(atChevronPoint point: CGPoint) -> Bool {
        guard let id = detailsChevron(at: point) else { return false }
        toggleDetailsExpanded(id: id)
        return true
    }

    internal static let chevronTouchInset: CGFloat = 12.0

    /// The fallback when the host supplies no image, mirroring `DetailsBox`'s drawn-arrow fallback.
    private static let drawnChevron: UIImage = {
        let side = DetailsShape.chevronSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: side * 0.28, y: side * 0.40))
            path.addLine(to: CGPoint(x: side * 0.50, y: side * 0.62))
            path.addLine(to: CGPoint(x: side * 0.72, y: side * 0.40))
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.label.setStroke()
            path.stroke()
            _ = context
        }.withRenderingMode(.alwaysTemplate)
    }()
}

/// A pooled glyph view, existing ONLY for its touch target: legacy hit-tests an 18pt arrow's rect
/// inflated by 12pt, and an 18pt image view is too small to hit reliably otherwise — the same reason
/// `ListCheckboxHostView` exists.
///
/// The name is the OVERRIDE, not the position: the details chevron sits in the gutter and a folded
/// quote's expand glyph in the trailing-top corner, so calling this a "gutter" view would be false
/// of half its uses. `DetailsChevronView` remains as a typealias so no details site moves.
@available(iOS 18.4, *)
internal final class InflatedTouchGlyphView: UIImageView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inset = RichTextEngineEditorView.chevronTouchInset
        return bounds.insetBy(dx: -inset, dy: -inset).contains(point)
    }
}

/// The details chevron's old spelling, kept so this rung moves no details site. Both names are the
/// same class; the rename is about what the type IS (an inflated touch target) rather than where any
/// one instance sits.
@available(iOS 18.4, *)
internal typealias DetailsChevronView = InflatedTouchGlyphView
#endif
