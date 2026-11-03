#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The hosted media view, in a wrapper the editor owns (spec §4).
///
/// The wrapper does two things the provided view cannot: it claims the poster area in `hitTest` so
/// a tap there selects the atom, while a control inside the provided view (the ••• button) still
/// wins; and it keeps the provider's contract — the same view is handed back on an items change so
/// surviving cells can be reused in place.
///
/// It draws NO selected state. It used to, on the premise that UIKit's highlight sat in a container
/// whose z-order against a hosted view was not the host's to control. Measured 2026-09-15, that is
/// false: the engine's selection container is brought to the FRONT of the text view on every
/// presentation update, so the wash is above this view. A tint here was a second coat of the same
/// colour over part of the same image — `accent @ 0.30` across the whole 342pt host, beneath UIKit's
/// own wash across the 310pt column — and rendered as a darker core inside a lighter frame.
@available(iOS 18.4, *)
internal final class MediaAtomHostView: UIView, UIGestureRecognizerDelegate {
    let blockID: BlockID
    private(set) var hosted: RichTextMediaItemView
    var itemsSignature: String
    var onPosterTapped: (() -> Void)?

    init(blockID: BlockID, hosted: RichTextMediaItemView, itemsSignature: String) {
        self.blockID = blockID
        self.hosted = hosted
        self.itemsSignature = itemsSignature
        super.init(frame: .zero)
        backgroundColor = .clear
        addSubview(hosted)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func replaceHosted(_ view: RichTextMediaItemView) {
        hosted.removeFromSuperview()
        hosted = view
        addSubview(view)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hosted.frame = bounds
        hosted.update(size: bounds.size)
    }

    /// A control inside the provided view wins; the poster is the host's own.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled, self.point(inside: point, with: event) else { return nil }
        if let control = hosted.hitTest(convert(point, to: hosted), with: event), control !== hosted {
            return control
        }
        return self
    }

    /// Only a touch that landed on the POSTER selects: a control's touch must not also fire this,
    /// or the ••• button's own action would be cancelled under it.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view === self
    }

    @objc private func handleTap() { onPosterTapped?() }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// Legacy's items signature: a change re-provides the view.
    ///
    /// A non-finite or out-of-range natural size reads as 0 rather than being converted: `Int(_:)`
    /// on a NaN or an infinity TRAPS, and a natural size arrives from a host, so it is not this
    /// view's to assume well-formed.
    internal static func mediaItemsSignature(for shape: MediaShape) -> String {
        func rounded(_ value: Double) -> Int {
            let value = value.rounded()
            guard value.isFinite, value >= Double(Int.min), value <= Double(Int.max) else { return 0 }
            return Int(value)
        }
        return shape.displayMode.rawValue + "|" + shape.items.map {
            "\($0.mediaID)#\($0.kind.rawValue)#\(rounded($0.naturalSize.width))x\(rounded($0.naturalSize.height))#s\($0.isSpoiler ? 1 : 0)"
        }.joined(separator: "|")
    }

    /// Legacy's `mediaCullMargin`.
    private static let mediaCullMargin: CGFloat = 50

    /// The role index of the atom whose media block is `blockID` — the identity door, where
    /// `mediaAtomIndex(forRoleAt:)` is the position door.
    internal func mediaAtomIndex(ofBlock blockID: BlockID) -> Int? {
        currentRoles.firstIndex { role in
            if case let .standalone(.media(shape)) = role.position { return shape.id == blockID }
            return false
        }
    }

    /// Reconciles hosted media views against the atoms in the current document. Idempotent; driven
    /// from `layoutSubviews` once the engine has laid out, like every other hosted overlay.
    internal func syncMediaViews() {
        guard !currentRoles.isEmpty || !mediaAtomViews.isEmpty else { return }
        var live: Set<BlockID> = []
        let provider = deferredConfiguration.mediaViewProvider
        let lineWidth = availableTableWidth
        let visible = CGRect(origin: engine.contentOffset, size: engine.bounds.size)
            .insetBy(dx: -Self.mediaCullMargin, dy: -Self.mediaCullMargin)

        for (index, role) in currentRoles.enumerated() {
            guard case let .standalone(.media(shape)) = role.position, let provider else { continue }
            let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(flatOffset(ofRoleAt: index)))
            // CGRectNull is the engine's answer for an unknown offset — never treated as a rect.
            // Not-ready is not-ready whichever side reports it: a transient null/zero frame here and
            // a nil answer from the provider below are the SAME "ask again next pass" case, so both
            // keep a pooled host alive (hidden) rather than reaping it — reaping would drop the
            // existing view and the next pass would re-provide with `existing = nil`, losing the
            // cell-reuse contract for one bad frame.
            guard !frame.isNull, frame.width > 0, frame.height > 0 else {
                if let existing = mediaAtomViews[shape.id] {
                    existing.isHidden = true
                    live.insert(shape.id)
                }
                continue
            }
            let signature = Self.mediaItemsSignature(for: shape)
            let host: MediaAtomHostView
            if let existing = mediaAtomViews[shape.id], existing.itemsSignature == signature {
                host = existing
            } else {
                let existingView = mediaAtomViews[shape.id]?.hosted
                let items = shape.items.map {
                    MediaProviderItem(mediaID: $0.mediaID, kind: $0.kind,
                                      naturalSize: CGSize(width: $0.naturalSize.width, height: $0.naturalSize.height),
                                      isSpoiler: $0.isSpoiler)
                }
                // nil = not ready: keep whatever is there and retry next pass, as legacy does.
                guard let provided = provider(items, shape.id, shape.displayMode, existingView) else {
                    if mediaAtomViews[shape.id] != nil { live.insert(shape.id) }
                    continue
                }
                provided.isUserInteractionEnabled = true
                if let existing = mediaAtomViews[shape.id] {
                    existing.itemsSignature = signature
                    if existing.hosted !== provided { existing.replaceHosted(provided) }
                    host = existing
                } else {
                    let fresh = MediaAtomHostView(blockID: shape.id, hosted: provided, itemsSignature: signature)
                    // Into the ENGINE, which is a scroll view, because `id_attachmentFrame` answers
                    // in its CONTENT space — above the block stack, like an emoji view.
                    engine.addSubview(fresh)
                    mediaAtomViews[shape.id] = fresh
                    host = fresh
                }
                let id = shape.id
                host.onPosterTapped = { [weak self] in
                    guard let self, let atom = self.mediaAtomIndex(ofBlock: id) else { return }
                    self.selectAtomUnit(at: atom)
                }
                bindMediaControls(of: host, shape: shape)
            }
            live.insert(shape.id)
            // The attachment can only be as wide as the line it is on — the line NARROWED by its
            // quote indent, since P1 found the attachment does that subtraction itself. The bleed is
            // the VIEW's to add, only when the slot spans that line (a narrower single image keeps
            // its own width), and only at top level: inside a quote a medium is flush with the band
            // (nesting design §5.4). The two terms were once coupled — `bleed` 0 wherever `indent`
            // was not — and R7-details broke that: a details contributes NO indent and still suppresses
            // the bleed, so inside one a medium is flush with text that is itself flush. That is
            // deliberate and matches the sibling decision for the code band, which a details' interior
            // also gets none of. `fills` therefore has to be a true statement about the line in its own
            // right, which is why the indent is subtracted here rather than left to the bleed gate.
            let indent = role.contentIndent(styleSheet: bridge.styleSheet)
            // ANY container, spelled as one: `containerDepth == 0` is the same value and reads as a count
            // of quotes, which is exactly the confusion this rung had to unpick everywhere else.
            let bleed = role.ancestry.isEmpty ? bridge.mediaBlockStyle.horizontalBleed : 0.0
            let fills = frame.width >= (lineWidth - indent) - 0.5
            host.frame = fills ? frame.insetBy(dx: -bleed, dy: 0) : frame
            // What the reader sees, bleed included — the same rect the line above just assigned, so
            // the wash cannot end up 16pt narrower on each side than the photo it is washing.
            pendingSelectionBoxes[shape.id] = host.frame
            host.isHidden = !visible.intersects(host.frame)
        }

        for (id, view) in mediaAtomViews where !live.contains(id) {
            view.removeFromSuperview()
            mediaAtomViews.removeValue(forKey: id)
        }
    }

    /// Selects the atom's one character — the first step of the two-step deletion, and what a tap
    /// on the poster does. Takes focus first: a selection is only readable from a first responder,
    /// and a tapped photo is meant to be acted on.
    /// Selects an atom unit's atom — the first step of the two-step deletion, for EITHER kind.
    internal func selectAtomUnit(at index: Int) {
        guard index < currentRoles.count else { return }
        switch currentRoles[index].position {
        case .standalone(.media), .standalone(.buttonRow), .standalone(.collapsedQuote): break
        default: return
        }
        if !engine.isFirstResponder { _ = engine.becomeFirstResponder() }
        engineSelectedRange = flatRange(ofRoleAt: index)
    }

    /// Whether UIKit's text interaction may begin for a touch at `pointInEngine` (engine content
    /// space). Refused over a media host so a tap on a photo is the host's and not also the
    /// engine's caret placement. Probe P2 verifies on device that the hook is consulted at all.
    internal func textInteractionMayBegin(at pointInEngine: CGPoint, isTap: Bool = false) -> Bool {
        appendTrailingParagraphIfTouchIsBelowTheContent(pointInEngine)
        if mediaAtomViews.values.contains(where: { !$0.isHidden && $0.frame.contains(pointInEngine) }) { return false }
        // A table grip is the same case as a media host and a details chevron: the touch belongs to
        // the control, so the engine must not also place a caret under it. A resize KNOB refuses only
        // a drag — a tap over a knob places the caret, or the cells around the focused one would be
        // unreachable by tap (`TableStructuralChromeView.claimsTouch(at:for:)`).
        if isTap ? tableStructuralGripContains(pointInEngine: pointInEngine)
                 : tableStructuralControlContains(pointInEngine: pointInEngine) { return false }
        // A details' chevron is the same case: the tap is the fold's, so the engine must not also
        // place a caret under it. Measured against the chevron's OWN box, deliberately, and not the
        // inflated target the view accepts: the arrow sits at `chevronLeadingInset` 3 and is 18 wide,
        // so inflated by 12 its right edge reached 33 against the title's `titleGlyphIndent` of 26 —
        // SEVEN points past the title's first glyph, so a tap on the title's first character placed
        // no caret and folded the block instead — and 21pt above the title's centre, into a block the
        // details does not even contain. Inside the slop but outside the box a tap both folds and places a caret,
        // which is the harmless direction.
        // A row's pills are the host's tap, exactly as a media poster and a details chevron are: the
        // row view has its own recogniser, and the engine must not ALSO place a caret under it.
        if buttonRowViews.values.contains(where: { !$0.isHidden && $0.frame.contains(pointInEngine) }) {
            return false
        }
        // A quote's collapse glyph and a folded quote's expand glyph are the details chevron's case
        // exactly: the tap is the fold's, so the engine must not also place a caret under it.
        // Measured against each glyph's OWN box, never its inflated target — see the note above.
        if quoteCollapseGlyphContains(pointInEngine) { return false }
        if collapsedQuoteViews.values.contains(where: {
            !$0.isHidden && $0.hitTest(engine.convert(pointInEngine, to: $0), with: nil) != nil
        }) { return false }
        return !detailsChevronViews.values.contains { $0.frame.contains(pointInEngine) }
    }

    /// The ••• menu's request: a control tap builds a `MediaControlRequest` bound to THIS block's
    /// identity and hands it to the host.
    internal func bindMediaControls(of host: MediaAtomHostView, shape: MediaShape) {
        let blockID = shape.id
        host.hosted.onControlTapped = { [weak self] kind, itemIndex, anchorView, rect in
            self?.handleMediaControlTapped(blockID: blockID, kind: kind, itemIndex: itemIndex, anchorView: anchorView, sourceRect: rect)
        }
    }
}

/// Legacy's tap-below affordance (`tapBelowAddsTrailingParagraph`), which the engine editor stored and
/// never read.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// A touch below every block starts a trailing body paragraph at TOP LEVEL, so the caret has
    /// somewhere outside the last container to land.
    ///
    /// Without it the engine placed the caret at the nearest position, which for a trailing DETAILS is
    /// its body — so a tap in the empty space under the block, below the hairline that marks where the
    /// block ends, put the caret INSIDE it. Everything typed or inserted next went into the block: on
    /// device this read as "the add-table button did nothing", because the table landed in the block
    /// rather than after it (K3, 2026-09-08). The same held for a trailing quote, code block or table.
    ///
    /// Idempotent by the same rule legacy uses: nothing is appended when the last top-level block is
    /// already an empty paragraph. That is what makes it safe here, at a predicate UIKit may call for
    /// interactions other than a tap — at most one paragraph can ever exist to append.
    internal func appendTrailingParagraphIfTouchIsBelowTheContent(_ pointInEngine: CGPoint) {
        guard composerHostState.tapBelowAddsTrailingParagraph, !currentRoles.isEmpty,
              !isDecidingAtGate else { return }
        let last = currentRoles.count - 1
        // Already outside every container and already empty: legacy's one exception.
        if currentRoles[last].ancestry.isEmpty, currentRoles[last].secondaryKind == nil,
           currentRoles[last].owningTable == nil, flatLength(ofRoleAt: last) == 0 { return }
        let bottom = engine.id_frameForBlock(at: UInt(last))
        guard !bottom.isNull, pointInEngine.y > bottom.maxY else { return }
        let end = flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last)
        var plan = currentRoles
        plan.append(freshBodyRole(within: []))
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
                engineSelectedRange = NSRange(location: end + 1, length: 0)
            }
        }
    }
}
#endif
