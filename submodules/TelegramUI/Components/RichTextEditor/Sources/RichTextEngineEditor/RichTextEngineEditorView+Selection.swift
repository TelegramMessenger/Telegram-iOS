#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecHost

/// Selection and geometry reads (R4).
///
/// `composerSelectedRange` is documented as the chat composer's own flat UTF-16 coordinate space —
/// the document's paragraphs joined by "\n" (`RichTextEditorView+ComposerHost.swift:20-23`) — and
/// that IS `IDBlockDocument`'s canonical axis (`tgid_setAttributedBlocks` joins blocks with "\n" the
/// same way). So every member below talks to the engine's own `UITextInput` conformance directly —
/// `position(from:offset:)`, `textRange(from:to:)`, `caretRect(for:)`, `selectionRects(for:)` — with
/// no intermediate coordinate space. No conversion code exists here because none is needed; inventing
/// one (e.g. Telegram's OTHER axis, where a paragraph's structural-token size is `textLength + 2`)
/// would be the bug this task exists to avoid.
///
/// Only `selectedBlockRelativeRange()` produces a genuinely different address — Telegram's
/// block-relative address (spec §5.2) — and even there the only arithmetic is accumulating each
/// block's `utf16Count`, plus one more for the "\n" that joins it to the next block: the very
/// separator the engine's own canonical axis already counts.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// The selection in the engine's own canonical flat UTF-16 axis — every engine block, separators
    /// included — read and written directly through `UITextInput`. This is the axis the editor's own
    /// code works in (the resolver, the table editing, the container commands). Reads as an empty
    /// range at the start of the document when the engine currently has no selection (e.g. not first
    /// responder), mirroring `UITextView.selectedRange`'s own behaviour when unset. A write that
    /// cannot be resolved to a valid `UITextRange` (an out-of-bounds offset) is silently a no-op,
    /// matching `UITextInput`'s own optional-returning position/range API.
    internal var engineSelectedRange: NSRange {
        get {
            guard let range = engine.selectedTextRange else { return NSRange(location: 0, length: 0) }
            let location = engine.offset(from: engine.beginningOfDocument, to: range.start)
            let length = engine.offset(from: range.start, to: range.end)
            return NSRange(location: location, length: length)
        }
        set {
            guard let start = engine.position(from: engine.beginningOfDocument, offset: newValue.location),
                  let end = engine.position(from: start, offset: newValue.length),
                  let range = engine.textRange(from: start, to: end) else {
                return
            }
            engine.selectedTextRange = range
        }
    }

    /// The selection in the chat composer's flat UTF-16 axis — the protocol's axis, the one the
    /// legacy editor answers and `ChatInputContent.plainText` counts: paragraphs, code bodies,
    /// pull-quote bodies and quote children joined by "\n"; tables, media, language and author
    /// lines contribute nothing, not even a separator. The engine's own axis counts every one of
    /// those, so the two diverge as soon as a container is in the document — and the chat state
    /// echo, which compares the two on every update, then re-set the caret to the wrong place
    /// (measured on device: a caret in a table's last cell jumped to an earlier cell). A caret
    /// inside an off-axis block reads as the end of the flat text, as the legacy editor's does.
    public var composerSelectedRange: NSRange {
        get { composerFlatRange(fromEngineRange: engineSelectedRange) }
        set { engineSelectedRange = engineRange(fromComposerFlatRange: newValue) }
    }

    // MARK: - The composer's flat axis

    /// Whether an engine block's text is on the chat composer's flat axis.
    ///
    /// Mirrors `ChatInputContent.blockFlatLength` block for block: media, tables, DETAILS and button
    /// rows are 0 there, with no separator. A details' body is ordinary paragraphs on the engine's
    /// axis, so asking the role's own shape alone counted the whole body (and a `.secondary` title
    /// was already off): with a details present every later position was wrong in both directions —
    /// a caret after it read past the model's end, and setting the model's end put the caret inside
    /// the details body (composer harness, 2026-09-23, fuzz seeds 8, 14, 20, 21, 23,
    /// `HarnessDetailsSelectionAxisTests`). So anything with a details ANCESTOR is off the axis,
    /// at any depth; a block quote's children stay on it, as the model's recursion keeps them.
    private static func isOnComposerAxis(_ role: EngineBlockRole) -> Bool {
        if role.ancestry.contains(where: { if case .details = $0 { return true } else { return false } }) {
            return false
        }
        switch role.position {
        case .secondary, .tableCell: return false
        case let .standalone(shape):
            switch shape {
            // The chat currency keeps the whole media block off its flat axis, caption included,
            // and a button row with it (`blockFlatLength` gives both 0).
            case .media, .buttonRow: return false
            case .paragraph, .code, .pullQuote, .collapsedQuote: return true
            }
        }
    }

    /// One on-axis block: its engine start offset and length, its composer start offset and length,
    /// and every ATOM in it whose model length is not its engine length of one.
    private struct ComposerAxisSegment {
        var engineStart: Int
        var engineLength: Int
        var flatStart: Int
        var flatLength: Int
        /// (offset of the atom's `U+FFFC` within the block on the engine axis, the atom's length on
        /// the model axis), in order.
        var atoms: [(engineOffset: Int, flatLength: Int)]
    }

    /// The model length of an engine attachment character, or nil when it is one on both axes.
    ///
    /// The engine draws an inline FORMULA and a CUSTOM EMOJI as ONE `U+FFFC`, while the chat currency
    /// (`DocumentChatInputContentBridge.chatInputRuns`) carries the formula's LaTeX source and the
    /// emoji's alt text as the run's text (`docs/richtext-composer.md` §2: a custom emoji occupies its
    /// alt string's UTF-16 length on the flat axis). An inline button is a `U+FFFC` on both axes.
    /// Measuring blocks by engine length alone put every offset after such an atom short by the
    /// difference, so the chat's `replacingFlatRange` at the reported selection landed early and could
    /// split an emoji's surrogate pair (`HarnessAtomComposerAxisTests`).
    private static func composerAxisAtomLength(_ attachment: Any?) -> Int? {
        if let formula = attachment as? FormulaTextAttachment {
            let length = (formula.latex as NSString).length
            return length == 1 ? nil : length
        }
        if let emoji = attachment as? EmojiTextAttachment, let alt = emoji.ref.altText, !alt.isEmpty {
            let length = (alt as NSString).length
            return length == 1 ? nil : length
        }
        return nil
    }

    /// The on-axis blocks, in order.
    private func composerAxisSegments() -> [ComposerAxisSegment] {
        var segments: [ComposerAxisSegment] = []
        let blocks = engine.attributedBlocks
        var engineStart = 0
        var flat = 0
        for (index, role) in currentRoles.enumerated() where index < blocks.count {
            let block = blocks[index]
            let length = block.length
            if Self.isOnComposerAxis(role) {
                if !segments.isEmpty { flat += 1 }   // the "\n" joining this block to the previous on-axis one
                var atoms: [(engineOffset: Int, flatLength: Int)] = []
                var flatLength = length
                if length > 0 {
                    block.enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
                        guard value != nil else { return }
                        for offset in range.location ..< NSMaxRange(range) {
                            if let atomLength = Self.composerAxisAtomLength(value) {
                                atoms.append((offset, atomLength))
                                flatLength += atomLength - 1
                            }
                        }
                    }
                }
                segments.append(ComposerAxisSegment(engineStart: engineStart, engineLength: length, flatStart: flat, flatLength: flatLength, atoms: atoms))
                flat += flatLength
            }
            engineStart += length + 1
        }
        return segments
    }

    internal func composerFlatOffset(fromEngineOffset offset: Int) -> Int {
        let segments = composerAxisSegments()
        for segment in segments where offset >= segment.engineStart && offset <= segment.engineStart + segment.engineLength {
            let local = offset - segment.engineStart
            var flat = segment.flatStart + local
            for atom in segment.atoms where atom.engineOffset < local {
                flat += atom.flatLength - 1
            }
            return flat
        }
        // Inside an off-axis block (or past the end): the end of the flat text, as legacy answers
        // (`EngineComposerAxisTests`, `EngineMediaRoundTripTests` pin it).
        guard let last = segments.last else { return 0 }
        return last.flatStart + last.flatLength
    }

    /// `rounding` decides where an offset INSIDE an atom's model span lands: an atom is one
    /// character on the engine axis, so an offset into its LaTeX / alt text snaps to its start
    /// (`.down`), its end (`.up`) or whichever is nearer (`.nearest`, ties to the end).
    internal enum ComposerAxisRounding { case down, up, nearest }

    internal func engineOffset(fromComposerFlatOffset offset: Int, rounding: ComposerAxisRounding = .nearest) -> Int {
        let segments = composerAxisSegments()
        for segment in segments where offset >= segment.flatStart && offset <= segment.flatStart + segment.flatLength {
            var flat = segment.flatStart
            var engineLocal = 0
            for atom in segment.atoms {
                let atomFlatStart = flat + (atom.engineOffset - engineLocal)
                if offset <= atomFlatStart {
                    break
                }
                let atomFlatEnd = atomFlatStart + atom.flatLength
                if offset < atomFlatEnd {
                    let snapUp: Bool
                    switch rounding {
                    case .down: snapUp = false
                    case .up: snapUp = true
                    case .nearest: snapUp = (offset - atomFlatStart) * 2 >= atom.flatLength
                    }
                    return segment.engineStart + atom.engineOffset + (snapUp ? 1 : 0)
                }
                flat = atomFlatEnd
                engineLocal = atom.engineOffset + 1
            }
            return segment.engineStart + engineLocal + (offset - flat)
        }
        guard let last = segments.last else { return 0 }
        return last.engineStart + last.engineLength
    }

    internal func composerFlatRange(fromEngineRange range: NSRange) -> NSRange {
        let start = composerFlatOffset(fromEngineOffset: range.location)
        let end = composerFlatOffset(fromEngineOffset: NSMaxRange(range))
        return NSRange(location: start, length: max(0, end - start))
    }

    internal func engineRange(fromComposerFlatRange range: NSRange) -> NSRange {
        // A collapsed caret inside an atom's span snaps to the nearer boundary; a range widens to
        // cover every atom it touches, so it never selects half a formula or emoji.
        guard range.length > 0 else {
            let caret = engineOffset(fromComposerFlatOffset: range.location, rounding: .nearest)
            return NSRange(location: caret, length: 0)
        }
        let start = engineOffset(fromComposerFlatOffset: range.location, rounding: .down)
        let end = engineOffset(fromComposerFlatOffset: NSMaxRange(range), rounding: .up)
        return NSRange(location: start, length: max(0, end - start))
    }

    /// The caret rect at the current selection's end, straight from the engine. `nil` only when
    /// there is no selection at all (e.g. the engine is not first responder) — never a computed
    /// guess (Global Constraint 5).
    public func composerCaretRect() -> CGRect? {
        guard let position = engine.selectedTextRange?.end else { return nil }
        return engine.caretRect(for: position)
    }

    /// The first selection rect for an arbitrary flat range — not necessarily the live selection —
    /// so a caller (e.g. a formatting popover anchor) can ask "where would THIS span render" without
    /// moving the caret. `nil` when the range cannot be resolved to a valid `UITextRange` or the
    /// engine reports no rects for it.
    public func composerFirstSelectionRect(forFlatRange range: NSRange) -> CGRect? {
        let range = engineRange(fromComposerFlatRange: range)   // the protocol's axis in, the engine's inside
        guard let start = engine.position(from: engine.beginningOfDocument, offset: range.location),
              let end = engine.position(from: start, offset: range.length),
              let textRange = engine.textRange(from: start, to: end) else {
            return nil
        }
        return engine.selectionRects(for: textRange).first?.rect
    }

    /// The union of every selection rect for the CURRENT selection — taller than a single caret when
    /// the selection spans more than one line/block, since `selectionRects(for:)` returns one rect
    /// per visual line. `.zero` when there is no selection or the engine reports no rects for it.
    public var composerSelectionBoundingRect: CGRect {
        guard let range = engine.selectedTextRange else { return .zero }
        let bounding = engine.selectionRects(for: range).reduce(CGRect.null) { $0.union($1.rect) }
        return bounding.isNull ? .zero : bounding
    }

    /// The current selection's text, straight from the engine.
    public func selectedText() -> String {
        guard let range = engine.selectedTextRange else { return "" }
        return engine.text(in: range) ?? ""
    }

    /// Spec §5.2's reshape of the structural-axis pair: a block-relative address (which block, and
    /// the UTF-16 offset within it) rather than a whole-document offset, so it keeps naming the same
    /// spot after an edit to an unrelated, earlier block. `nil` for a collapsed selection (there is
    /// no RANGE to name) or when the flat selection cannot be resolved against `currentBlocks`.
    public func selectedBlockRelativeRange() -> (from: (BlockID, Int), to: (BlockID, Int))? {
        let flat = composerSelectedRange
        guard flat.length > 0 else { return nil }
        guard let from = blockRelativeLocation(forFlatOffset: flat.location),
              let to = blockRelativeLocation(forFlatOffset: flat.location + flat.length) else {
            return nil
        }
        return (from: from, to: to)
    }

    /// Which block a flat offset falls in, walking `currentBlocks` for IDENTITY and the
    /// ENGINE's `attributedBlocks` for EXTENT — accumulating each block's rendered UTF-16 length
    /// plus one more for the "\n" that joins it to the next.
    ///
    /// **The extent must be the engine's, not the model's.** `composerSelectedRange` is the engine's
    /// canonical axis, and `ParagraphBlock.utf16Count` sums each run's `text` — the two agree only
    /// while every run renders at its own text length, which `AttributedStringMapper` already breaks:
    /// a formula run emits a single `U+FFFC` while its `TextRun.text` holds the whole LaTeX source.
    /// One such run and every later block's offset is wrong by the difference. The block's rendered
    /// length is the engine's own fact and reading it costs nothing, so there is no reason to
    /// re-derive an approximation of it here.
    ///
    /// `currentBlocks` still supplies identity (the engine names blocks with `NSUUID`s; the
    /// caller wants a `BlockID`), and the two arrays are refreshed from the same pass in
    /// `engineDidChangeDocument()`, so `zip` pairs each block with its own length. A tail either
    /// array does not have is simply not walked — `nil` ("no block holds this offset") is the honest
    /// answer there, and the same answer an over-long offset already gets.
    ///
    /// INTERNAL, not private (R6/Task 8 fix round 2): `RichTextEngineEditorView+Paragraph.swift`'s
    /// `paragraphIndex(forFlatOffset:)` used to carry its OWN copy of this exact accumulation —
    /// same module, so widening this one access level lets both files share the single
    /// implementation instead of maintaining two copies of the boundary rule (where a block ends
    /// and the "\n" separator begins) that this project has already been bitten by drifting.
    internal func blockRelativeLocation(forFlatOffset offset: Int) -> (BlockID, Int)? {
        var blockStart = 0
        for (role, attributed) in zip(currentRoles, engine.attributedBlocks) {
            let blockLength = attributed.length
            if offset <= blockStart + blockLength {
                return (role.blockID, offset - blockStart)
            }
            blockStart += blockLength + 1
        }
        return nil
    }
}
#endif
