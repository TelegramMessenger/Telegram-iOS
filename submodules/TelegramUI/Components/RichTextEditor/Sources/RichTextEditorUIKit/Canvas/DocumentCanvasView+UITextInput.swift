#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView: UITextInput {
    private func clamp(_ n: Int) -> Int { clampGlobal(n) }

    // TASK 24 (Family 1): one-line router. The real body — still routed through `legacyPlainText`
    // below, NOT the document client's `plainText(in:)` (which REJECTS an out-of-bounds range instead
    // of clamping it, a real edge-case behavior change) — lives on `LegacyRichTextInputBackend`
    // (`+TextReads.swift`).
    func text(in range: UITextRange) -> String? { inputBackend.text(in: range) }

    /// The SOLE separator rule for every linear projection of the structured document (currently
    /// `legacyPlainText` and `legacyAttributedText`): "\n" at each crossed TOP-LEVEL paragraph boundary,
    /// table cells deliberately glued. Walks every leaf region in document order — not just the ones
    /// intersecting `[lo, hi)` — threading the topLevel/`prevTopLevelEnd` state exactly like the original
    /// single-purpose loop did, and reports, PER REGION, whether the shared rule requires a "\n" before
    /// it. That flag is independent of whether the region itself contributes any text: a range that lands
    /// entirely inside an inter-block gap still crosses the boundary. `body` decides what (if anything) to
    /// append for the region's own contribution — text or attributed content — so the two callers cannot
    /// independently reimplement (and redisagree on) where separators go. See Task 12 fix round 1: an
    /// early `legacyAttributedText` inserted "\n" between EVERY pair of included regions with no
    /// topLevel-vs-table-interior distinction, so it glued differently than `legacyPlainText` on any
    /// range spanning more than one leaf region inside a table.
    func forEachLeafRegionInRange(
        _ lo: Int, _ hi: Int, _ body: (_ region: LeafTextRegion, _ needsSeparatorBefore: Bool) -> Void
    ) {
        var prevTopLevelEnd: Int? = nil
        for region in allLeafRegions() {
            let rStart = region.globalStart, rEnd = region.globalStart + region.length
            let topLevel = !isInsideTable(rStart)
            let needsSeparator = topLevel && prevTopLevelEnd.map { lo < rStart && hi > $0 } ?? false
            body(region, needsSeparator)
            prevTopLevelEnd = topLevel ? rEnd : nil
        }
    }

    /// The one projection of the structured document into the keyboard's linear UTF-16 view: "\n" at
    /// each crossed TOP-LEVEL paragraph boundary (table cells are deliberately glued), EmojiTextAttachment
    /// → ref.altText, FormulaTextAttachment → att.latex. Load-bearing for the Hangul/CJK IME.
    ///
    /// The global position axis carries NO newline character between top-level blocks — only a
    /// structural token gap. A real UITextView returns "\n" there, and the system keyboard depends on
    /// it: the Hangul/CJK IME reads document context through `text(in:)` (it does NOT drive marked text
    /// on this view — it composes via insert + ranged delete/replace), and without the separator it
    /// sees two stacked paragraphs as one continuous line and recomposes a syllable ACROSS the invisible
    /// line break — the reported bug where a trailing consonant from the lower line migrates onto the
    /// line above. So emit "\n" for each top-level paragraph boundary the range crosses, including a
    /// range that lands entirely inside the inter-block gap (the read the keyboard makes immediately
    /// before a lower line's first character). Table-cell boundaries stay glued: a table is one editing
    /// surface, cells don't compose marked text, and cross-cell `text(in:)` is relied on un-separated.
    /// The separator decision itself lives in `forEachLeafRegionInRange`, shared with `legacyAttributedText`.
    func legacyPlainText(globalFrom: Int, globalTo: Int) -> String? {
        let lo = clamp(min(globalFrom, globalTo)), hi = clamp(max(globalFrom, globalTo))
        var result = ""
        forEachLeafRegionInRange(lo, hi) { region, needsSeparator in
            if needsSeparator { result += "\n" }
            let rStart = region.globalStart, rEnd = region.globalStart + region.length
            let a = max(lo, rStart), b = min(hi, rEnd)
            guard a < b else { return }
            let attr = region.layout.attributedString
            let ns = attr.string as NSString
            let slice = NSRange(location: a - rStart, length: b - a)
            // Replace inline atoms with their plain-text forms; copy every other span verbatim.
            attr.enumerateAttribute(.attachment, in: slice, options: []) { value, sub, _ in
                if let att = value as? EmojiTextAttachment {
                    result += att.ref.altText ?? ""
                } else if let att = value as? FormulaTextAttachment {
                    result += att.latex
                } else {
                    result += ns.substring(with: sub)
                }
            }
        }
        return result
    }

    // TASK 27a (Family 4, the routable half): one-line router. See `legacyReplace(globalFrom:globalTo:text:)`
    // just below for the body, which is byte-for-byte the body this witness used to carry.
    func replace(_ range: UITextRange, withText text: String) { inputBackend.replace(range, withText: text) }

    /// TASK 27a — was `replace(_:withText:)`'s whole body, moved here unchanged and reached from
    /// `LegacyRichTextInputBackend.replace(_:withText:)` through the D24 `legacyCanvas` accessor.
    ///
    /// TWO things about the split are load-bearing:
    ///
    /// 1. **The backend forwards to this hook with NO bracket of its own.** This body already runs an
    ///    `editing { }` (i.e. the backend's `notifyingContentAndSelectionChange`), so the observable
    ///    trace of one `replace(_:withText:)` is exactly six events — `textWillChange`,
    ///    `selectionWillChange`, `selectionDidChange`, `textDidChange`, `canvasContentSizeChanged`,
    ///    `canvasSelectionChanged`. `AutocorrectOriginCharacterizationTests` pins that array by exact
    ///    equality in three separate tests, and `InsertionRouterTests
    ///    .test_replaceWithText_emitsExactlyThePlainEditingBracket_theBackendAddsNoneOfItsOwn` pins it
    ///    again from the router side. A wrapping bracket on the backend member would make it eight.
    /// 2. **`oldText` must be re-derived through `legacyPlainText`, not through the document client.**
    ///    The pre-seam body called `self.text(in: range)`, which since Task 24 is
    ///    `LegacyRichTextInputBackend.text(in:)` → `legacyCanvas.legacyPlainText(globalFrom:globalTo:)`
    ///    (`+TextReads.swift`) — a CLAMPING projection. `TelegramDocumentInputClient.plainText(in:)`
    ///    REJECTS an out-of-bounds range instead, so re-deriving through the client would silently turn
    ///    a clamped autocorrect read into a `nil` one and drop the correction flag. Passing the range's
    ///    RAW `from`/`to` (not the `min`/`max` pair below) keeps the two spellings identical argument
    ///    for argument; `legacyPlainText` orders them itself.
    func legacyReplace(globalFrom: Int, globalTo: Int, text: String) {
        var lo = min(globalFrom, globalTo)
        var hi = max(globalFrom, globalTo)
        // PHASE 0b / TASK 9d — found by the differential oracle against stock UIKit, where all 9
        // inline-prediction scenarios produced a wrong document.
        //
        // `editing { }`'s prologue (`performEditing`) opens with `finalizeMarkedText()`. For a
        // COMPOSITION that is `commitMarkedText()`, which moves no text, so the caller's offsets stay
        // valid. For a PREDICTION (`markedTextIsPrediction`, i.e. the composition caret at `{0,0}`) it is
        // `dismissPrediction()`, which REMOVES the ghost — the document shrinks by the ghost's length and
        // `lo`/`hi`, captured above from the caller, are stale by exactly that much. The replace then ate
        // that many characters PAST the intended range: with ghost "untry" over "coBeta", replacing the
        // ghost yielded "country" instead of "countryBeta".
        //
        // So dismiss FIRST and rebase across the removal. Deliberately gated on `markedTextIsPrediction`
        // rather than finalizing unconditionally: the commit path is correct today and its
        // `finalizeMarkedText()` must keep happening inside `performEditing`, where its undo grouping is
        // established. This changes the broken path ONLY — for every other caller `finalizeMarkedText()`
        // returns nil and nothing here runs.
        if markedTextIsPrediction, let removed = finalizeMarkedText() {
            let removedLength = removed.to - removed.from
            func rebase(_ offset: Int) -> Int {
                if offset <= removed.from { return offset }
                if offset >= removed.to { return offset - removedLength }
                return removed.from   // an offset INSIDE the removed ghost collapses to its start
            }
            lo = rebase(lo)
            hi = rebase(hi)
        }
        // A keyboard autocorrection arrives here as `replace(word, correction)` — capture the original BEFORE the
        // edit so we can flag the corrected word (below) with a "Revert to …" affordance.
        let autocorrectOriginal = detectAutocorrection(
            oldText: legacyPlainText(globalFrom: globalFrom, globalTo: globalTo), newText: text)
        // Route through the 3-way selection logic, not applyReplaceOutcome directly: a system-initiated
        // replacement (autocorrect/dictation/marked-text) can span a table boundary, which the
        // same-stack-guarded applyReplaceOutcome would silently drop.
        // System-initiated replacement (autocorrect / dictation / marked-text spanning). Kept .none
        // (its own undo step) — coalescing is scoped to insertText/deleteBackward typing/deleting, so a
        // dictation utterance is one undo step. Intentional, not an oversight.
        editing { applySelectionReplaceOutcome(globalFrom: lo, globalTo: hi, text: text) }
        if let original = autocorrectOriginal, isSpellCheckingEnabled {
            applyCorrectionFlag(global: NSRange(location: lo, length: (text as NSString).length), original: original)
        }
    }

    func typingAttributeDict(region: LeafTextRegion, atLocal location: Int) -> [NSAttributedString.Key: Any] {
        let storage = region.layout.attributedString
        if storage.length == 0 {
            // An empty image caption is render-only centered (not in the model), so the next typed
            // character must carry that centered paragraph style explicitly or it would land left-aligned.
            if let img = boxes.compactMap({ $0 as? MediaBlockBox }).first(where: { region.ref == .caption($0.id) }) {
                return img.captionTypingAttributes()
            }
            // An empty code block types the monospace code attributes, not the body default — without this the
            // first character typed into a just-created (empty) code block lands non-monospace at body size.
            if case .code = region.ref { return CodeBlockBox.codeAttributes(textColor: self.mapper.theme.primaryText) }
            // An empty LANGUAGE line types the language attributes (bold, body size) — without this the
            // first character lands 17pt body-styled and read-back writes that string into the model.
            if case .codeLanguage = region.ref { return CodeBlockBox.languageAttributes(mapper: self.mapper) }
            // An empty pull quote types the italic/centered pull-quote attributes — without this the first
            // character typed into an empty pull quote lands body-upright-left instead of italic/centered.
            if case .pullQuote = region.ref { return PullQuoteBox.pullQuoteTypingAttributes(mapper) }
            // An empty quote author types the BOLD caption attributes — without this the first character typed
            // into an empty author lands body-styled (17pt, non-bold), which then pollutes the model on read-back.
            if case .quoteAuthor = region.ref, let attrs = authorTypingAttributes(forRegion: region.ref) {
                return attrs
            }
            // Recover the owning paragraph — top-level OR nested in a table cell (via the active stack)
            // — so an empty styled/listed/cell paragraph keeps its paragraph style AND its box's mapper
            // on the next typed character. A table cell's mapper renders body text at a smaller base
            // size, so reading the box's own mapper (not the canvas one) keeps the first char on size.
            let p = boxes.compactMap { $0 as? BlockBox }.first { region.ref == .paragraph($0.id) }
                ?? (activeStack(at: region.globalStart + location).flatMap { $0.box as? BlockBox })
            let m = p?.mapper ?? mapper
            let style = p?.style ?? .body
            let para = p?.paragraphAttributes ?? .default
            let list = p?.listMembership
            var attrs = m.attributes(for: CharacterAttributes(), style: style)
            attrs[.paragraphStyle] = m.styleSheet.paragraphStyle(for: style, attributes: para, list: list,
                                                                   baseWritingDirection: m.baseWritingDirection)
            return attrs
        }
        var attrs = storage.attributes(at: min(max(0, location - 1), storage.length - 1), effectiveRange: nil)
        // A formula is an atomic inline value, not a typing style. At either edge of the atom the normal
        // "inherit from the preceding character" rule picks up its semantic marker; NSTextStorage removes
        // an attachment from newly-inserted non-U+FFFC text, but leaves our custom rtFormula attribute in
        // place. That makes the text look plain while read-back/send serializes it as another formula.
        // Strip only the atom-specific metadata, preserving its ambient font/colour/paragraph attributes.
        attrs.removeValue(forKey: .rtFormula)
        if attrs[.attachment] is FormulaTextAttachment {
            attrs.removeValue(forKey: .attachment)
        }
        return attrs
    }

    /// Bold caption typing attributes for an empty quote author region: resolves the owning PullQuoteBox /
    /// BlockQuoteBox (recursing nested block quotes) by id and returns its `authorTypingAttributes()`.
    func authorTypingAttributes(forRegion ref: TextNodeRef) -> [NSAttributedString.Key: Any]? {
        guard case let .quoteAuthor(id) = ref else { return nil }
        func search(_ list: [CanvasBlock]) -> [NSAttributedString.Key: Any]? {
            for b in list {
                if let pq = b as? PullQuoteBox, pq.id == id { return pq.authorTypingAttributes() }
                if let bq = b as? BlockQuoteBox {
                    if bq.id == id { return bq.authorTypingAttributes() }
                    if let hit = search(bq.children.boxes) { return hit }
                }
            }
            return nil
        }
        return search(boxes)
    }

    /// Typing attributes for the caret at a global position: the leaf region's attributes, or body
    /// defaults at a structural boundary (no region). Used by the structural-edit engine.
    func typingAttributesAtGlobal(_ pos: Int) -> [NSAttributedString.Key: Any] {
        if let (region, local) = leafRegion(containingGlobal: clamp(pos)) {
            return typingAttributeDict(region: region, atLocal: local)
        }
        return mapper.attributes(for: CharacterAttributes(), style: .body)
    }

    // TASK 26 (Family 3): both halves are one-line routers. The real bodies live on
    // `LegacyRichTextInputBackend` (`LegacyRichTextInputBackend.swift`), reached through the
    // `legacyApplySelectedTextRange(_:)` hook just below for the setter's canvas half.
    var selectedTextRange: UITextRange? {
        get { inputBackend.selectedTextRange }
        set { inputBackend.selectedTextRange = newValue }
    }

    /// D24 legacy hook for the `selectedTextRange` SETTER routed above. Carries the pre-seam canvas
    /// body VERBATIM, in order, EXCEPT for its last two statements — `refreshSelectionUI()` and
    /// `onSelectionChange?()` — which the backend now delivers through `setSelection`'s publication:
    /// `presentationClient.apply` is `refreshSelectionUI()` and `lifecycleClient.backendDidPublishState(.selection)`
    /// is `onSelectionChange?()`, in that same order, immediately after this hook returns. Splitting
    /// them out is what keeps the seam from emitting each of those twice.
    ///
    /// The floating-cursor early return is deliberately NOT here: it is the backend's own
    /// `floatingCursorActive` guard (`LegacyRichTextInputBackend.swift`), which runs before this hook
    /// is called at all — that flag is backend state, and Task 33 makes the backend its writer.
    ///
    /// Returns the CLAMPED endpoints actually written, so the backend records the same pair the canvas
    /// did rather than re-deriving one (the canvas is the only party that knows `documentSize`).
    @discardableResult
    func legacyApplySelectedTextRange(_ newValue: UITextRange?) -> (anchor: Int, head: Int) {
        // iOS sets the object-replacement RANGE for a tap-selected media right before its Backspace.
        // `clearStructuralSelections()` below drops `imageSelection`; stash it so `deleteBackward` can
        // still recognise the structural-delete intent (its object geometry doesn't cover the media node).
        imageObjectDeletePending = imageSelection
        finalizeMarkedText()     // a deliberate selection move commits a composition / dismisses a prediction
        clearStructuralSelections()
        dismissEditMenuForSelectionOrTextChange()   // system-driven move (keyboard cursor-drag / autocorrect) closes the menu too
        // TASK 44: was `newValue as? DocumentTextRange`. Same downcast, same `nil` on a range this
        // backend did not mint — it just happens inside the backend now (`LegacyTextIdentity`), so
        // this hook reads a plain `(Int, Int)?` and names no identity type. The `?? 0` collapse and
        // both `clamp()`s below are untouched; they are this hook's documented raw behaviour.
        let r = newValue.flatMap(LegacyTextIdentity.globalRange(of:))
        // TASK 37, POPULATION B. The nil-collapse (`?? 0`) and the two `clamp()`s are this hook's
        // documented raw behaviour and are preserved exactly; only the WRITE moves off the deprecated
        // forwarders onto `applyCaretOutcome` (`+Editing.swift`), the same raw, non-publishing pair.
        // **NOT `setSelection(_:reason: .keyboard)`, and the reason is unique to this site:** this hook
        // is called BY `LegacyRichTextInputBackend`'s `selectedTextRange` setter, which calls
        // `setSelection(…, reason: .keyboard)` itself THREE STATEMENTS LATER, in the same call — after
        // binding `raw`, `anchorOffset` and `headOffset` from the pair this hook returns. **The
        // distance is not the point and stating it as "the very next statement" was wrong** (an earlier
        // draft of this note did); what matters is that the publish is in the SAME call, so a
        // `setSelection` here would not double a delegate bracket — it would double the CALLER's
        // publish, whatever sits between the two. Measured:
        // `SelectionRouterTests.test_selectedTextRangeSetter_runsTheWholeCanvasBodyThroughTheBackend`
        // reports 2 `onSelectionChange` where it requires 1 (recorded at `applyCaretOutcome`).
        // The DIRECTIONAL pair is preserved: `.range(_:_:)` does not normalize, and an unordered range
        // is load-bearing for a reversed drag (`RichTextCanonicalSelection.normalizedRange`).
        applyCaretOutcome(.range(clamp(r?.from ?? 0), clamp(r?.to ?? 0)))
        setNeedsDisplay()
        return (anchor, head)
    }

    // TASK 26 (Family 3): a one-line router each way. The delegate itself is stored on the backend,
    // which is now the only sender of `UITextInputDelegate` notifications in the package (rule R16).
    var inputDelegate: UITextInputDelegate? {
        get { inputBackend.inputDelegate }
        set { inputBackend.inputDelegate = newValue }
    }
    // TASK 24 (Family 1): `tokenizer` is a one-line router — the real body (still the canvas's own
    // custom `DocumentTokenizer`, NOT a stock `UITextInputStringTokenizer`) lives on
    // `LegacyRichTextInputBackend` (`+TextReads.swift`), and the cache with it (`tokenizerStorage`).
    //
    // TASK 43 DELETED THE D24 HOOK THIS USED TO REACH THROUGH, `legacyMakeTokenizer()`. The backend
    // now writes `DocumentTokenizer(canvas:)` itself, in `attach(to:)`, so the tokenizer is
    // constructed AND owned on one side of the seam instead of minted on the other and cached on this
    // one. The canvas kept nothing: `inputTokenizer` is gone from `DocumentCanvasView.swift` too.
    // `InputBackendSourceBoundaryTests.test_theTokenizerHasExactlyOneConstructionSite` is what makes
    // "one construction site" checkable — the obvious runtime spelling of that claim,
    // `responds(to: Selector(("legacyMakeTokenizer")))`, is VACUOUS on a non-`@objc` Swift method and
    // passed against the un-migrated tree. (FIX ROUND 1: that rule's FIRST version was itself evadable
    // by `DocumentTokenizer.init(canvas:)`; it is now two assertions — a construction scan that sees
    // both parenthesised spellings, plus an exact identifier-mention allowance for the three
    // unparenthesised ones. All five were planted and reddened.)
    var tokenizer: UITextInputTokenizer { inputBackend.tokenizer }

    // The first/last positions the caret can occupy must be RENDERABLE (a leaf region start/end or an
    // image gap), not the document's structural open/close token slots (0 / documentSize) — otherwise
    // "move to start/end of document" would hide the caret. TASK 24: both are now one-line routers;
    // the renderable-snapping itself is unchanged, reached through `legacySnapToRenderable(_:forward:)`
    // (`+Navigation.swift`).
    var beginningOfDocument: UITextPosition { inputBackend.beginningOfDocument }
    var endOfDocument: UITextPosition { inputBackend.endOfDocument }

    // MARK: - The identity-free selection/geometry surface (TASK 44)
    //
    // **Why these four members exist.** Until this task the PUBLIC FACADE itself downcast and
    // constructed the backend's UIKit identity objects — `RichTextEditorView` held five such sites,
    // which is the violation D19 and the Task 44 brief both open with ("UIKit identity is
    // backend-owned / opaque outside the active backend", broken by the facade before any work
    // started). These are what it calls instead. They are ALSO what the canvas layer's own former
    // identity sites call, so the whole package now has exactly one place that knows what a
    // `LegacyTextPosition` is: `S/InputBackend/Legacy/`.
    //
    // **Each one preserves its former path exactly** — it mints or unwraps the same object, through
    // `LegacyTextIdentity`, and then calls the same routed member the old inline expression called.
    // Task 44 is a zero-behavior-change task and this is where that claim is cashed.

    /// The selection as canonical offsets. A read-only projection of the backend's single store, the
    /// same one `anchor`/`head` project — this is the whole-value spelling, for a caller that wants
    /// the pair atomically rather than as two reads that could straddle a change.
    var canonicalSelection: RichTextCanonicalSelection { inputBackend.canonicalSelection }

    /// The last RENDERABLE caret slot (end of document), or `nil` when the active backend's
    /// `endOfDocument` is not one of the legacy backend's identity objects. Exactly `endOfDocument`'s
    /// offset: the same backend member, unwrapped here instead of at the caller.
    ///
    /// **OPTIONAL, and TASK 44 FIX ROUND 1 (review Minor 2) made it so.** It first shipped as
    /// `Int` with a `?? 0`, on a proof that read: `LegacyRichTextInputBackend.endOfDocument`
    /// (`+TextReads.swift`) returns a `LegacyTextPosition` on BOTH of its paths — the attached one
    /// and the detached one, which reports a contract violation and returns `LegacyTextPosition(0)`
    /// — so the downcast inside `globalOffset(of:)` cannot fail. **That proof is sound and its scope
    /// was not stated: it holds for the LEGACY backend only.** This member lives on
    /// `DocumentCanvasView`, whose `inputBackend` is a protocol EXISTENTIAL
    /// (`init(… inputBackend: RichTextInputBackend? = nil)`), while `LegacyTextIdentity` is by
    /// definition the *legacy* reader. Under any other backend the downcast fails, and `?? 0` turned
    /// the pre-task facade's silent no-op (`guard let end = canvas.endOfDocument as?
    /// DocumentTextPosition else { return }`) into a caret JUMP TO OFFSET 0 — the start of the
    /// document, from a method named `moveCaretToDocumentEnd`. Optional restores the original
    /// semantics exactly and pushes the decision to the caller, which is where it was.
    var documentEndOffset: Int? { LegacyTextIdentity.globalOffset(of: endOfDocument) }

    /// Set the selection to the global UTF-16 range `[from, to)` — UNORDERED, `from`/`to` verbatim.
    ///
    /// **This routes through `selectedTextRange`'s setter, which is the point.** That setter is the
    /// path the facade's `selectAll()`/`moveCaretToDocumentEnd()` already took (they assigned a
    /// hand-built `DocumentTextRange` to it), so behaviour — the `finalizeMarkedText()`, the
    /// structural-selection clear, the edit-menu dismissal, the clamp, and the single publish the
    /// backend's setter performs with `reason: .keyboard` — is preserved to the statement.
    ///
    /// **It deliberately does NOT call `inputBackend.setSelection(_:reason:)`.** Two independent
    /// reasons, both measured:
    ///  1. **Door 1.** `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` asserts that
    ///     `setSelection(` appears at exactly ONE call site in `Sources/`
    ///     (`LegacyRichTextInputBackend.swift`). `SwiftSourceScan.callSiteCount`'s pattern excludes a
    ///     `func setSelection(` DECLARATION but not an `inputBackend.setSelection(` CALL, so a
    ///     forwarder here would make that dictionary read two files. Verified by planting exactly that
    ///     forwarder and running the rule (Task 44 report).
    ///  2. **Reason, and therefore behaviour.** The backend's `selectedTextRange` setter publishes with
    ///     `reason: .keyboard`; a direct `setSelection(…, reason: .command)` would change the reason the
    ///     host observes. `DocumentCanvasView.swift`'s `anchor` doc records what happened the last time
    ///     a caller was "simplified" onto a publishing `setSelection` (measurement 1 there: exit 65, 2
    ///     red) — the shape is wrong, not merely differently spelled.
    func setSelectedGlobalRange(from: Int, to: Int) {
        selectedTextRange = LegacyTextIdentity.range(fromGlobal: from, toGlobal: to)
    }

    /// The identity-free spelling of `caretRect(for:)`. Replaces the six
    /// `caretRect(for: DocumentTextPosition(n))` sites (five canvas, one facade) with one member that
    /// mints the position on the backend side. Same routed member, same argument, same result — the
    /// `.zero` its callers branch on still comes from the backend's own D9 translation
    /// (`+Geometry.swift`), not from anything added here.
    func caretRect(atGlobal offset: Int) -> CGRect {
        caretRect(for: LegacyTextIdentity.position(atGlobal: offset))
    }

    // Optional iOS-18 UITextInput member: tells the system the view supports editing so Writing Tools
    // can apply results in place (vs treating content as read-only). Together with our `UIEditMenuInteraction`
    // (the non-UITextInteraction path, WWDC24 #10168), this surfaces the system Writing Tools item on
    // Apple-Intelligence hardware.
    //
    // TASK 31, DEVIATION D3: a one-line router, but the two sides are gated DIFFERENTLY on purpose.
    // The WITNESS keeps its `@available(iOS 18.0, *)` — that is UIKit's own gate on the member. The
    // BACKEND member is `isEditableForWritingTools`, declared with NO availability above the package's
    // iOS 13 floor (hard invariant 12), so `RichTextInputResponderBackend` stays a single existential
    // surface rather than one whose shape depends on the deployment target. The rename is the other
    // half of D3: `isEditable` is a UIKit witness name and would collide with the far broader meaning
    // `RichTextInputEditPolicy.isEditable` already carries on the contract side.
    @available(iOS 18.0, *)
    var isEditable: Bool { inputBackend.isEditableForWritingTools }

    // TASK 24 (Family 1): the six members below are all one-line routers now — their bodies (byte-for-
    // byte ports) live on `LegacyRichTextInputBackend` (`+TextReads.swift`). `textRange(from:to:)`
    // still ORDERS its two arguments (load-bearing — do not "fix"); `position(from:offset:)` still
    // snaps to a renderable slot.
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        inputBackend.textRange(from: fromPosition, to: toPosition)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        inputBackend.position(from: position, offset: offset)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        inputBackend.compare(position, to: other)
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        inputBackend.offset(from: from, to: toPosition)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        inputBackend.position(within: range, farthestIn: direction)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        inputBackend.characterRange(byExtending: position, in: direction)
    }

    // TASK 25 (Family 2): the eight members below (through `setBaseWritingDirection` further down) are
    // all one-line routers now — their bodies (byte-for-byte translations of the originals) live on
    // `LegacyRichTextInputBackend` (`+Geometry.swift`). The `?? .zero`/`?? []` translation (Deviation D9)
    // lives in the BACKEND's UIKit-facing member, NOT here — see that file's header comment.
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        inputBackend.baseWritingDirection(for: position, in: direction)
    }
    // No-op by design: the whole-document override (`layoutDirectionModel`) is the single manual control,
    // so we do not honor per-range UIKit writing-direction writes (which would imply per-paragraph control
    // we deliberately did not build). TASK 25: routed to a backend no-op stating the same rationale.
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        inputBackend.setBaseWritingDirection(writingDirection, for: range)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        inputBackend.firstRect(for: range)
    }

    /// Deviation D9: the CLIENT boundary (`TelegramGeometryInputClient.firstRect`) uses `nil` for a
    /// missing/empty selection rect; the backend's UIKit-facing `firstRect(for:)`
    /// (`+Geometry.swift`) keeps the `.zero` its callers already branch on. `nil` exactly where
    /// `selectionRects(globalFrom:globalTo:)` yields no rects — an empty range, or a range that
    /// resolves to no leaf region at all. Still called only from the geometry client (Task 25 did not
    /// touch this canvas-level helper itself).
    func legacyFirstRect(globalFrom: Int, globalTo: Int) -> CGRect? {
        selectionRects(globalFrom: globalFrom, globalTo: globalTo).first
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        inputBackend.caretRect(for: position)
    }

    /// Deviation D9: see `caretRect(for:)`'s backend body (`+Geometry.swift`) — this is the
    /// nil-returning helper the geometry client wraps. Still called only from the geometry client
    /// (Task 25 did not touch this canvas-level helper itself).
    func legacyCaretRect(globalOffset: Int) -> CGRect? {
        // A structural row/column selection hides the caret entirely (the outline is the indicator).
        // An image atom selection does NOT zero the caret here: `caretRect` must keep reporting the gap
        // geometry so the OS can run arrow-key navigation OUT of a tap-selected image — vertical arrows
        // read the caret's rect to step a line, so a `.zero` rect strands them (the reported "Up does
        // nothing / caret vanishes" bug). The VISIBLE caret is suppressed separately in `updateCaretView`
        // (the image tint is the selection indicator), so no blinking caret shows over a selected image.
        if tableSelection != nil { return nil }
        let pos = clamp(globalOffset)
        if let (r, local) = leafRegion(containingGlobal: pos) {
            // `emptyLineLeadingIndent`/`emptyLineHeight` only matter on an empty line, whose caret TextKit
            // would otherwise place at x=0 with a fixed 20pt height (no glyphs to carry the indent/metrics).
            return r.caretRect(atLocal: local)
                .offsetBy(dx: r.canvasOrigin.x + r.emptyLineLeadingIndent - tableContentOffsetX(forGlobal: pos),
                          dy: r.canvasOrigin.y)
        }
        // An image gap is a real caret slot but not a text leaf. Report a vertical bar at the image's
        // leading edge; `updateCaretView` renders the app's own caret there (and this geometry also feeds the
        // loupe / hit-test / edit menu). (This returned .zero before, which is why draw(_:) used to hand-draw
        // a custom GapCursor bar.)
        if let img = mediaBox(atGap: pos) {
            let rr = img.mediaRect()
            return CGRect(x: rr.minX, y: rr.minY, width: 2, height: rr.height)
        }
        // A collapsed quote's leading gap is a real caret slot (no text leaf) — a bar at the folded preview's
        // leading edge, so the caret focused on a collapsed quote is visible. Mirrors the media-gap branch.
        if let bq = collapsedBlockQuoteBox(atGap: pos) {
            return bq.collapsedCaretRect
        }
        return nil
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        inputBackend.selectionRects(for: range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        inputBackend.closestPosition(to: point)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        inputBackend.closestPosition(to: point, within: range)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        inputBackend.characterRange(at: point)
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView: UIKeyInput {
    // TASK 27a (Family 4): one-line router. The backend answers from
    // `RichTextInputDocumentClient.utf16Length`, which for the Telegram client IS this canvas's
    // `documentSize` (`TelegramDocumentInputClient.utf16Length` → `documentSizeValue` → `documentSize`),
    // so the value is identical by construction rather than by coincidence.
    var hasText: Bool { inputBackend.hasText }

    // TASK 27b (Family 4): one-line router. The body below moved to `legacyInsertText(_:)` and the
    // backend forwards straight back to it (`LegacyRichTextInputBackend+Insertion.swift`) — a PLAIN
    // D24 forward with no bracket of its own, because the body brackets itself per branch.
    func insertText(_ text: String) { inputBackend.insertText(text) }

    /// Was `DocumentCanvasView.insertText(_:)`, renamed by TASK 27b when the witness became a router;
    /// the body is untouched. `LegacyRichTextInputBackend.insertText(_:)` forwards here, and
    /// `legacyApplyMutation`'s `.insertText` case dispatches here directly (never to the witness — see
    /// that method's ⚠️ RECURSION HAZARD note).
    ///
    /// **Bracket ownership lives HERE, and that is why the backend's forward is bare.** This body runs
    /// its own `editing { }` / `notifyingContentChange` brackets PER BRANCH — a text-only bracket for
    /// the marked-commit branch (pinned by
    /// `DelegateTraceCharacterizationTests.test_insertTextWhileMarked_emitsATextOnlyBracket`), all four
    /// notifications for the normal and structural branches, and none at all for the quote-author
    /// `default:` early return. A bracket added at the backend would double every one of them
    /// (measured: six recorded events became ten for the sibling `replace` witness).
    func legacyInsertText(_ text: String) {
        imageObjectDeletePending = nil   // a non-delete edit cancels a pending structural-media delete
        // A committing keystroke while composing: replace the WHOLE marked range with `text`, then
        // finalize the composition as one undo step. (The system delivers a confirming char this way.)
        if let m = markedRange {
            // TASK 26: a TEXT-ONLY bracket (`notifyingContentChange`) even though the caret moves —
            // the marked-commit asymmetry, pinned by
            // `DelegateTraceCharacterizationTests.test_insertTextWhileMarked_emitsATextOnlyBracket`.
            inputBackend.notifyingContentChange {
                // THE CLAIM IS APPLIED HERE, ON THE NEXT INSTRUCTION. Outside any `editing { }`, and
                // `commitMarkedText()` three lines below reads the caret back through its
                // `inputBackend.compositionSnapshot ?? (anchor, head)` fallback (TASK 41 renamed it
                // from `compositionAnchorHead` when composition state moved to the backend; the
                // read-back is unchanged) — a read-back ACROSS A FUNCTION
                // BOUNDARY, which no grep of this body will show you. See `applyReplaceOutcome`'s doc in
                // `+Editing.swift`. Pinned by `CaretLandingCharacterizationTests
                // .test_markedCommitLandsTheCaretAtTheEndOfTheCommittedText`.
                applyCaretOutcome(applyReplaceOutcome(globalFrom: m.from, globalTo: m.to, text: text))   // in place; caret → end
                bumpDocumentRevision()   // marked-commit's applyReplaceOutcome is OUTSIDE `editing { }`
            }
            commitMarkedText()
            notifyContentSizeChanged(); setNeedsDisplay(); refreshSelectionUI()
            onSelectionChange?()   // committing a composition moves the caret — scroll it into view too
            return
        }
        clearStructuralSelections()
        // Caret on an image's gap cursor → open a new body paragraph immediately before the image
        // (Enter inserts an empty one), rather than letting the text fall into the caption. Symmetric
        // to deleteBackward's gap branch below.
        if selFrom == selTo, let img = mediaBox(atGap: head), let i = boxIndex(of: img) {
            editing { insertBodyParagraphOutcome(beforeBoxAt: i, text: text == "\n" ? "" : text) }
            return
        }
        // Caret focused on a COLLAPSED quote's gap → open a body paragraph immediately before the folded
        // quote (the atom holds no editable text), so a keystroke there isn't swallowed. Mirrors the media gap.
        if selFrom == selTo, let bq = collapsedBlockQuoteBox(atGap: head), let i = boxIndex(of: bq) {
            editing { insertBodyParagraphOutcome(beforeBoxAt: i, text: text == "\n" ? "" : text) }
            return
        }
        if text == "\n" {
            // Return in a code block's LANGUAGE line moves the caret to the start of the code text. It
            // inserts nothing and splits nothing: a `.Pre` language has no second line. (The quote author
            // splits instead, because it is a TRAILING region — the tail becomes a paragraph after the
            // quote. A leading region has no such tail.)
            if selFrom == selTo, let (region, _) = leafRegion(containingGlobal: head),
               case let .codeLanguage(id) = region.ref,
               let owner = stackContainingCodeBox(id: id) {
                setCaret(global: owner.box.textStart)
                return
            }
            // Return in a quote AUTHOR line splits the author at the caret (like a media caption): the head runs
            // stay as the author, the tail runs become a NEW body paragraph immediately after the quote (caret
            // there). Handled here, at the TOP of the "\n" dispatch, because a caret in the author resolves
            // through neither activeStack (off the child stack) nor resolveBox (outside the container's
            // degenerate/pull-text extent), so the code/pull-quote/block-quote branches below (and the general
            // insertParagraphBreak() fallback) would mis-route the break into the following sibling block.
            if selFrom == selTo, let (region, authorLocal) = leafRegion(containingGlobal: head),
               case .quoteAuthor = region.ref, let (quoteBox, parentStack, index) = enclosingQuote(at: head) {
                let authorRuns: [TextRun]
                let rebuildQuote: ([TextRun]) -> Block
                switch quoteBox.currentBlock() {
                case .pullQuote(let pq):
                    authorRuns = pq.author
                    rebuildQuote = { .pullQuote(PullQuote(id: pq.id, runs: pq.runs, author: $0)) }
                case .blockQuote(let bq):
                    authorRuns = bq.author
                    rebuildQuote = { .blockQuote(BlockQuote(id: bq.id, children: bq.children, collapsed: bq.collapsed, author: $0)) }
                default:
                    return
                }
                editing {
                    let tmp = ParagraphBlock(id: BlockID.generate(), style: .caption, runs: authorRuns)
                    let parts = tmp.split(at: authorLocal, newID: BlockID.generate())   // .0 = head (author), .1 = tail (new paragraph)
                    guard let newQuoteBox = makeBox(for: rebuildQuote(parts.0.runs), mapper: mapper, quoteStyle: quoteStyle,
                                                    pullQuoteStyle: pullQuoteStyle, expandImage: quoteCollapseIcons?.expand,
                                                    collapseImage: quoteCollapseIcons?.collapse, width: effectiveWidth) else { return .unchanged }
                    let bodyBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: parts.1.runs),
                                           mapper: mapper, width: effectiveWidth)
                    parentStack.boxes.replaceSubrange(index...index, with: [newQuoteBox, bodyBox])
                    recomputeSpans()
                    return .caret(at: bodyBox.textStart)
                }
                return
            }
            if let active = activeStack(at: head), active.box is CodeBlockBox {
                // Double-return (Enter on an empty line) EXITS the code block: trailing → after, first →
                // before, wholly-empty → un-code. A MIDDLE blank line and a non-empty line just insert a
                // literal newline (no paragraph split). A selection always replaces-with-newline — only a
                // collapsed caret can exit.
                if selFrom == selTo, let exit = codeBlockDoubleReturnExit(active) {
                    switch exit {
                    case .after:  exitCodeBlockToBodyParagraph(active)
                    case .before: exitCodeBlockToBodyParagraphBefore(active)
                    case .uncode: uncodeEmptyCodeBlock(active)
                    }
                } else {
                    insertCodeBlockNewline()
                }
            } else if let active = activeStack(at: head), active.box is PullQuoteBox {
                // Double-return EXITS the pull quote: trailing → after, first → before, wholly-empty → unmake.
                // A MIDDLE blank line and a non-empty line just insert an interior newline. A selection always
                // replaces-with-newline — only a collapsed caret can exit.
                if selFrom == selTo, let exit = pullQuoteDoubleReturnExit(active) {
                    switch exit {
                    case .after:  exitPullQuoteToBodyParagraph(active)
                    case .before: exitPullQuoteToBodyParagraphBefore(active)
                    case .unmake: unmakeEmptyPullQuote(active)
                    }
                } else {
                    insertPullQuoteNewline()
                }
            } else if selFrom == selTo, isInsideBlockQuote(head), blockQuoteEmptyTrailingChildExit() {
                // Double-return EXITS the block quote at the END: empty trailing child → body paragraph after
                // the quote; a wholly-empty quote (after \n\n) → one body paragraph in place. A SINGLE Return
                // in a wholly-empty quote just adds a line (the escape requires \n\n). Handled inside the
                // helper; execution falls through to the outer `return`.
                _ = ()
            } else if selFrom == selTo, isInsideBlockQuote(head), blockQuoteEmptyLeadingChildExit() {
                // Double-return at the BEGINNING → body paragraph BEFORE the quote (the leading blank line is
                // dropped). Checked after the trailing exit so a wholly-empty quote takes the un-quote path.
                _ = ()
            } else if selFrom == selTo, isInsideDetails(head), detailsEmptyTrailingBodyExit() {
                // Double-return on an empty trailing line of a detail block's BODY EXITS to a body paragraph
                // AFTER the details block (the title, children[0], is never the escape target). A single empty
                // body line adds a line on the first Return and escapes on the second (handled in the helper).
                _ = ()
            } else if selFrom == selTo, let active = activeStack(at: head),
                      headerCellDoubleReturnExitsAbove(active) {
                // Double-return on the START of a header cell's second block (empty first block) EXITS the
                // table to a body paragraph ABOVE it. Header rows only; body cells + trailing/non-leading
                // blanks fall through to the normal in-cell split.
                exitHeaderCellToBodyParagraphBefore(active)
            } else {
                insertParagraphBreak()
            }
            return
        }
        if selFrom != selTo {
            editing(coalescing: .typing) { applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        // A collapsed caret in a quote AUTHOR line: the author is a SECOND leaf region on the box (outside the
        // box's primary textStart/textLength extent and off the child stack), so applyReplaceOutcome/activeStack would
        // mis-route the insert to the following block. Route it through the region-aware applyLeafReplaceOutcome, exactly
        // as an in-cell edit does below.
        if let (region, _) = leafRegion(containingGlobal: head), case .quoteAuthor = region.ref {
            editing(coalescing: .typing) { applyLeafReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        // A collapsed caret in a code block's LANGUAGE line: like the quote author, it is a second leaf
        // region outside the box's primary `textStart`/`textLength` extent, so `activeStack` resolves nil
        // and `applyReplaceOutcome` would drop the keystroke. Route it through the region-aware path.
        // Newlines are stripped: a `.Pre` language is a single-line string, and a multi-line paste
        // (which reaches this path flattened — `insertingFragment` refuses a language locus, so the
        // clipboard falls back to plain text) would otherwise put interior "\n"s in the model, where
        // `currentCode()`'s edge-trim cannot reach them.
        if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref {
            let flat = text.replacingOccurrences(of: "\n", with: " ")
            editing(coalescing: .typing) { applyLeafReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: flat) }
            return
        }
        // A collapsed caret that resolves to a table or block-quote box (e.g. before a leading
        // container / after a trailing one) is a structural boundary — snap it into the nearest
        // in-container text start so the edit goes through that container's stack, never through
        // the container's degenerate textLayout (which would drop the keystroke).
        if !isInsideTable(head) && !isInsideBlockQuote(head),
           let r = resolveBox(at: head), r.box is TableBlockBox || r.box is BlockQuoteBox {
            let snapped = caretSnappedIntoContainer(head)
            // TASK 37, POPULATION B — a container SNAP, read back by `isInsideTable(head)` on the very
            // next line and by the `editing` transactions after it, so it cannot ride to the end of a
            // transaction. Same mechanism and same reason as the four normalization writes in
            // `legacyDeleteBackward` below.
            applyCaretOutcome(.caret(at: snapped))
        }
        if isInsideTable(head) {
            // collapsed caret in a cell: text is in-place.
            editing(coalescing: .typing) { applyLeafReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        editing(coalescing: .typing) { applyReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: text) }
    }

    /// The number of UTF-16 units the composed character sequence (grapheme cluster) immediately
    /// before the caret at global position `head` occupies. Backspace deletes this many units so a
    /// multi-unit emoji — a surrogate-pair scalar, a ZWJ sequence, a skin-tone / flag / variation-
    /// selector combo — is removed as ONE unit instead of one code unit (which would orphan the rest
    /// and render "part" of the emoji). Within a leaf region the global axis is 1:1 with UTF-16, and a
    /// grapheme never spans regions, so `head - n` stays in the same region. Returns 1 when the region
    /// can't be resolved (the safe single-unit fallback); a custom-emoji `U+FFFC` and any plain BMP
    /// character are single-unit clusters, so this is a no-op for them. Caller guarantees `local > 0`.
    func graphemeClusterLengthBeforeCaret(global head: Int) -> Int {
        guard let (region, local) = leafRegion(containingGlobal: head), local > 0 else { return 1 }
        let s = region.layout.attributedString.string as NSString
        guard local <= s.length else { return 1 }
        let r = s.rangeOfComposedCharacterSequence(at: local - 1)
        return max(1, local - r.location)
    }

    /// Expands a global range so neither endpoint SPLITS A UTF-16 SURROGATE PAIR (a single astral Unicode
    /// scalar whose two code units must stay together): `from` snaps DOWN to the pair start, `to` snaps UP
    /// to the pair end. The OS can request a delete/replace of a partial scalar — notably a backspace
    /// arriving as a 1-UTF-16-unit range covering only one half of a surrogate-pair emoji (`selFrom≠selTo`)
    /// — and deleting it verbatim leaves a stray code unit (a "service character").
    ///
    /// It deliberately does NOT expand across whole GRAPHEME CLUSTERS. A base + combining-mark sequence — a
    /// Tamil consonant + virama ("க்" = U+0B95 U+0BCD), and other Indic / Thai scripts — is two INDEPENDENT
    /// scalars that a composing IME (e.g. Tamil **Anjal**) edits individually: it selects the lone combining
    /// mark and deletes/replaces it to recompose the syllable (verified against the real iOS keyboard driving
    /// this view). Snapping that to the whole cluster would erase the base consonant, so the syllable could
    /// never be formed — the "can't type Tamil" bug. Matching a stock `UITextView`, only surrogate pairs are
    /// kept atomic here; grapheme atomicity is enforced for CARET stepping by the tokenizer, not for IME
    /// edits. A scalar never spans leaf regions, so each endpoint is snapped within its own region.
    func rangeExpandedToScalarBoundaries(globalFrom: Int, globalTo: Int) -> (from: Int, to: Int) {
        func snap(_ g: Int, up: Bool) -> Int {
            guard let (region, local) = leafRegion(containingGlobal: g), local > 0 else { return g }
            let s = region.layout.attributedString.string as NSString
            guard local < s.length else { return g }
            // A split point sits INSIDE a surrogate pair iff the unit before is a high surrogate and the
            // unit at `local` is a low surrogate. Every other boundary (incl. base↔combining-mark) is kept.
            let unit = s.character(at: local), prev = s.character(at: local - 1)
            let splitsSurrogatePair = prev >= 0xD800 && prev <= 0xDBFF && unit >= 0xDC00 && unit <= 0xDFFF
            guard splitsSurrogatePair else { return g }
            return region.globalStart + (up ? local + 1 : local - 1)
        }
        let lo = min(globalFrom, globalTo), hi = max(globalFrom, globalTo)
        return (snap(lo, up: false), snap(hi, up: true))
    }

    /// True when `pos` is the START (local 0) of an empty CONTAINER whose Backspace un-makes it to a body
    /// paragraph: an empty code block, an empty pull quote, or the lone empty child of a block quote. Used to
    /// recognise the OS-delivered object-replacement Backspace RANGE at an empty container so it can be collapsed
    /// to a caret and routed through the same un-quote / un-code / un-make branches as a direct tap.
    func startsEmptyContainer(at pos: Int) -> Bool {
        guard let active = activeStack(at: pos), active.local == 0, active.box.textLength == 0 else { return false }
        if active.box is CodeBlockBox || active.box is PullQuoteBox { return true }
        if active.box is BlockBox, active.stack.boxes.count == 1, isInsideBlockQuote(pos) { return true }
        return false
    }

    // TASK 28 (Family 5): one-line router. The body below moved to `legacyDeleteBackward()` and the
    // backend forwards straight back to it (`LegacyRichTextInputBackend+Deletion.swift`) — a PLAIN
    // D24 forward with no bracket of its own, because the body brackets itself per branch.
    func deleteBackward() { inputBackend.deleteBackward() }

    /// Was `DocumentCanvasView.deleteBackward()`, renamed by TASK 28 when the witness became a router;
    /// the body is untouched. `LegacyRichTextInputBackend.deleteBackward()` forwards here, and
    /// `legacyApplyMutation`'s `.deleteBackward` case dispatches here directly (never to the witness —
    /// see that method's ⚠️ RECURSION HAZARD note).
    ///
    /// **Bracket ownership lives HERE, and that is why the backend's forward is bare.** This body runs
    /// its own bracket PER BRANCH, across **24** `editing { … }` call sites (18 bare, 6
    /// `editing(coalescing: .deleting)`), and `editing` IS `notifyingContentAndSelectionChange` since
    /// Task 26. Several branches deliberately emit NOTHING (the media-gap no-ops, the caret-only
    /// `setCaret` arm, the `guard !boxes.isEmpty` early return); several emit through a nested helper
    /// that self-brackets (`unwrapBlockQuoteLevel()`, `deleteTableRow()`, `deleteTableColumn()`). A
    /// bracket added at the backend would double every one of them and add a `publishState` tail on top
    /// of `editing`'s own — measured for the sibling `replace` witness: six recorded events became ten.
    ///
    /// The count is worth stating because it has been miscounted three times: a naive
    /// `grep -c 'editing {'` over this body returns 19, one of which is the PROSE
    /// `// already wraps itself in editing { }` on the `unwrapBlockQuoteLevel()` line. Exclude trailing
    /// comments, not just comment-only lines.
    func legacyDeleteBackward() {
        if markedRange != nil { commitMarkedText() }   // delete acts on committed text, not the composition
        guard !boxes.isEmpty else { return }
        // A tap-selected media block's Backspace: iOS represents the deletion by OVERRIDING the selection
        // (via the `selectedTextRange` setter, which clears `imageSelection`) to a RANGE whose head lands at
        // the media's leading gap but whose object geometry is offset from our position model (it anchors in
        // the preceding block), so the normal selection-replace below would delete the preceding text and
        // KEEP the media. The setter stashes the just-cleared image into `imageObjectDeletePending`; honor it
        // here by replacing that media with an empty body paragraph in place.
        if let pendingId = imageObjectDeletePending,
           let (stack, i) = owningStack(ofBlockID: pendingId), let mb = stack.boxes[i] as? MediaBlockBox,
           head == mb.nodeStart || selFrom == mb.nodeStart || selTo == mb.nodeStart {
            imageObjectDeletePending = nil
            editing { replaceMediaWithEmptyParagraphOutcome(id: pendingId) }   // stack-aware: in place, even nested
            clearImageSelection()
            return
        }
        imageObjectDeletePending = nil
        // A button row is TEXT-FREE, so `prevTextPosition` skips back over an entire RUN of adjacent
        // rows and iOS's object-replacement range spans all of them — the generic selection-replace
        // below then drops every one at once. Delete exactly ONE pill (and the row with its last pill)
        // so repeated Backspaces walk through them one by one. Must run BEFORE the media/quote arms:
        // those collapse a range to a caret, which would strand this one mid-run.
        if deleteButtonPillIfNeeded() {
            return
        }
        // iOS may deliver Backspace at a NON-tap-selected media block's leading gap as an object-
        // replacement RANGE running from the previous block's text end to the gap ([prevEnd … gap]),
        // NOT a collapsed caret. Left as a range it falls to the generic selection-replace below, which
        // deletes only the structural break and strands the caret at the previous block's end without
        // deleting anything (the reported "jumps to the end of the previous block, nothing happens"
        // symptom). When the range only spans the structural slots before the gap (`selFrom >=
        // prevTextPosition(before: selTo)`, which excludes a genuine text selection ending at the gap),
        // COLLAPSE it to a caret at the gap so the gap branch below acts on the previous block. A
        // tap-selected image is excluded (`imageSelection != img.id`) — it already returned above via
        // `imageObjectDeletePending`.
        if selFrom != selTo, let img = mediaBox(atGap: selTo), imageSelection != img.id,
           selFrom >= prevTextPosition(before: selTo) {
            // TASK 37, POPULATION B — **the four collapse-to-`selTo` writes in this method
            // are NORMALIZATION, not a deliberate selection**, and this note covers all four (the
            // other three point here). Each collapses one of iOS's object-replacement RANGES to the
            // caret the branches below act on, and `selFrom`/`selTo` are READ BACK by the very next
            // `if`. The write moves off the deprecated forwarders onto `applyCaretOutcome`
            // (`+Editing.swift`) — the raw, NON-PUBLISHING endpoint pair — and deliberately NOT onto
            // `setSelection(_:reason:)`, which the brief specified: none of these sits in an open
            // bracket, so a `setSelection` would take the full publish path and report a selection
            // change to the host BEFORE the delete that motivates it. **No suite catches that** —
            // see the Rule-24 row in the Task-37 measurement at `applyCaretOutcome`.
            applyCaretOutcome(.caret(at: selTo))
        }
        if tableSelection != nil {
            // A structural row/column selection is active → Backspace deletes those rows/columns (or the
            // whole table when every row/column is selected). The caret is parked in a cell, so the normal
            // in-cell branch below would otherwise just delete a character.
            deleteTableStructuralSelection()
            return
        }
        // iOS delivers Backspace at the START (local 0) of a NON-FIRST block-quote CHILD as an object-replacement
        // RANGE anchored at the previous child's text end (the paragraph break INSIDE the quote), NOT a collapsed
        // caret — verified at runtime (Return at a quote line's end then Backspace arrives as e.g. `sel=3..5`, head
        // at the new empty 2nd child). This MUST run BEFORE the empty-container / empty-paragraph-after-atom handlers
        // below: `resolveBox(at: selTo)` mis-resolves this in-quote position to the FOLLOWING block, so the "empty
        // paragraph after a non-paragraph atom" handler (a BlockQuoteBox IS such an atom) would REMOVE that following
        // block (the device bug: "Backspace deletes the paragraph after the quote, not the quote's own line"). When
        // the range only spans the structural break before the child's start (`selFrom >= prevTextPosition(before:
        // selTo)`, excluding a genuine text selection), COLLAPSE it to a caret at the child start so the
        // collapsed-caret quote-child branch below merges it into its previous sibling.
        if selFrom != selTo, isInsideBlockQuote(selTo),
           let active = activeStack(at: selTo), active.box is BlockBox, active.local == 0, active.index > 0,
           selFrom >= prevTextPosition(before: selTo) {
            // TASK 37, POPULATION B — normalization; the note is on the first of these four, above.
            applyCaretOutcome(.caret(at: selTo))
        }
        // iOS delivers Backspace at the START of an empty CONTAINER (block quote / code block / pull quote) as an
        // object-replacement RANGE anchored at the previous block's text end — the same offset geometry as a
        // media atom, NOT a collapsed caret. Left as a range it falls to the generic selection-replace below and
        // MERGES the container's (empty) content into the previous block, stranding the empty container — the
        // device bug ("Backspace jumps the caret to the previous line and the quote stays"). When the range only
        // spans the structural slots before the container's start (`selFrom >= prevTextPosition(before: selTo)`,
        // which excludes a genuine text selection), COLLAPSE it to a caret at the container start so the
        // collapsed-caret un-quote / un-code / un-make branches below un-make it — exactly like a direct tap.
        if selFrom != selTo, startsEmptyContainer(at: selTo),
           selFrom >= prevTextPosition(before: selTo) {
            // TASK 37, POPULATION B — normalization; the note is on the first of these four, above.
            applyCaretOutcome(.caret(at: selTo))
        }
        // iOS delivers Backspace in an empty paragraph immediately AFTER a non-paragraph atom (image /
        // table / code / collapsed quote) as an object-replacement RANGE running from the atom's text end
        // to the empty paragraph's start (device-log: `setRange [8,10]` overriding the collapsed caret at
        // 10, then `deleteBackward selFrom=8 selTo=10`) — the same offset-geometry pattern for all atoms.
        // The generic selection-replace below would mangle the boundary and strand the empty paragraph.
        // Recognise it — selTo at the start of an EMPTY paragraph whose previous block is any non-paragraph
        // atom, with selFrom only covering the structural slots before (`selFrom >=
        // prevTextPosition(before: selTo)`, which excludes a genuine multi-char selection) — and remove the
        // empty paragraph, parking the caret at the atom's text end (matching the collapsed-caret path for
        // an empty paragraph after a non-text atom further below). `selTo` must be a genuine TOP-LEVEL position:
        // a position INSIDE a block quote OR a table cell has no degenerate-container-safe `resolveBox`, so
        // `resolveBox(selTo)` mis-resolves it to the FOLLOWING top-level block — and a mid-text Backspace inside
        // the container (delivered as the 1-char range [local0, local1]) satisfies `selFrom >=
        // prevTextPosition(before: selTo)`, so without the `!isInsideBlockQuote(selTo)` / `!isInsideTable(selTo)`
        // guards this would REMOVE the (empty) block after the container instead of deleting the char (the
        // "mid-quote / mid-cell delete misroutes into the following block" device bug).
        if selFrom != selTo, !isInsideBlockQuote(selTo), !isInsideTable(selTo), let posTo = resolveBox(at: selTo),
           posTo.local == 0, posTo.box.textLength == 0, posTo.index > 0,
           isNonParagraphAtom(boxes[posTo.index - 1]),
           selFrom >= prevTextPosition(before: selTo) {
            if selectPrecedingTableOnBackspace(paragraphIndex: posTo.index) { return }   // table → select whole table
            editing { removeBlockOutcome(at: posTo.index, parkingCaretAt: prevTextPosition(before: selTo)) }
            return
        }
        // Object-replacement RANGE at the START of a NON-EMPTY paragraph whose previous block is a table
        // (device-form parity with the empty-paragraph range above — iOS may deliver Backspace at this
        // boundary as `[tableLastCellEnd … paragraphStart]`). Route it to the whole-table select helper.
        // The `selFrom >= prevTextPosition(before: selTo)` gate admits ONLY the object-replacement range
        // (its head anchors at the table's last-cell end), NOT a genuine selection that merely ends at the
        // paragraph start (that must still delete-and-merge via the generic path below). `!isInsideBlockQuote`
        // / `!isInsideTable` avoid the resolveBox degenerate-container misroute.
        if selFrom != selTo, !isInsideBlockQuote(selTo), !isInsideTable(selTo), let posTo = resolveBox(at: selTo),
           posTo.local == 0, posTo.box.textLength > 0, posTo.index > 0,
           boxes[posTo.index - 1] is TableBlockBox,
           selFrom >= prevTextPosition(before: selTo) {
            if selectPrecedingTableOnBackspace(paragraphIndex: posTo.index) { return }
        }
        // iOS may deliver Backspace at the START (local 0) of a quote AUTHOR line as an object-replacement
        // RANGE anchored at the previous child's text end (the same offset geometry as an empty container /
        // atom), NOT a collapsed caret. When the range only spans the structural slots before the author's
        // start (`selFrom >= prevTextPosition(before: selTo)`, which excludes a genuine text selection),
        // COLLAPSE it to a caret at the author start so the collapsed-caret relocation branch below handles it.
        if selFrom != selTo, let (region, local) = leafRegion(containingGlobal: selTo),
           case .quoteAuthor = region.ref, local == 0,
           selFrom >= prevTextPosition(before: selTo) {
            // TASK 37, POPULATION B — normalization; the note is on the first of these four, above.
            applyCaretOutcome(.caret(at: selTo))
        }
        // Backspace with a collapsed caret at the START of a quote author line: relocate the caret to the end
        // of the quote's last child (recursive via `prevTextPosition`) — the author is always present, so you
        // simply step OUT of it into the body. Never merge the author into the body, never delete the quote.
        if selFrom == selTo, let (region, local) = leafRegion(containingGlobal: head),
           case .quoteAuthor = region.ref, local == 0 {
            setCaret(global: prevTextPosition(before: region.globalStart))
            return
        }
        // Backspace with a collapsed caret at the START of a code block's LANGUAGE line. The language is
        // the block's FIRST position, so there is nothing inside the block to merge into:
        //   • a WHOLLY empty block (no language, no code) is un-made to a body paragraph — today's
        //     empty-code rule, relocated to the block's new first position;
        //   • otherwise the caret steps OUT to the previous block's end, deleting nothing. When the code
        //     block is the document's first block there is nowhere to step, so it is a no-op.
        // Never merges the language into the previous block; never deletes a block that has content.
        if selFrom == selTo, let (region, local) = leafRegion(containingGlobal: head),
           case let .codeLanguage(id) = region.ref, local == 0,
           let owner = stackContainingCodeBox(id: id) {
            if region.length == 0, owner.box.textLength == 0 {
                editing {
                    let body = BlockBox(paragraph: ParagraphBlock(id: owner.box.id, style: .body, runs: []),
                                        mapper: mapper, width: effectiveWidth)
                    var newBoxes = owner.stack.boxes
                    newBoxes.replaceSubrange(owner.index...owner.index, with: [body])
                    owner.stack.boxes = newBoxes
                    recomputeSpans()
                    return .caret(at: body.textStart)
                }
                return
            }
            let prev = prevTextPosition(before: region.globalStart)
            if prev != head { setCaret(global: prev) }
            return
        }
        // Backspace INSIDE a code block's language line (text before the caret): delete that grapheme in
        // the language region. `activeStack` resolves nil there by design, so the generic paths below
        // would mis-route it. Mirrors the block-quote author/child branch.
        if selFrom == selTo, let (region, local) = leafRegion(containingGlobal: head),
           case .codeLanguage = region.ref, local > 0 {
            let n = graphemeClusterLengthBeforeCaret(global: head)
            editing(coalescing: .deleting) { applyLeafReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
            return
        }
        if selFrom != selTo {
            editing(coalescing: .deleting) { applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: "") }
            return
        }
        if isInsideTable(head) {
            guard let active = activeStack(at: head) else { return }
            if active.local > 0 {
                let n = graphemeClusterLengthBeforeCaret(global: head)
                editing(coalescing: .deleting) { applyLeafReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
            } else if active.index > 0 {
                editing { mergeParagraphsOutcome(in: active.stack, upperIndex: active.index - 1) }
            } else {
                // Caret at the cell's first-paragraph start: move WITHOUT deleting to the previous text
                // position — the previous cell's end (row-major), or, at the table's FIRST cell, the end
                // of the block before the table. No-op only when the table is the document's first block
                // (nothing before — like Backspace at the very start of a document).
                let prev = prevTextPosition(before: head)
                if prev != head { setCaret(global: prev) }
            }
            return
        }
        // (A) A TAP-SELECTED image (the tint highlight; `imageSelection` is still set because `selectImage`
        // doesn't go through the `selectedTextRange` setter) → replace the media with an empty body paragraph
        // in place, caret there. (The range-driven tap-select path returns earlier via `imageObjectDeletePending`.)
        // Stack-aware (by id, not a top-level index) so a NESTED tap-selected media is replaced in place too,
        // not removed — so this runs BEFORE the `boxIndex(of:)` gap branch, which resolves only at top level.
        if let img = mediaBox(atGap: head), imageSelection == img.id {
            editing { replaceMediaWithEmptyParagraphOutcome(id: img.id) }
            clearImageSelection()
            return
        }
        // Caret at a media block's leading gap (the slot to the LEFT of the image).
        if let img = mediaBox(atGap: head), let i = boxIndex(of: img) {
            // (B) A plain, non-selected caret at the gap → Backspace acts on the PREVIOUS block (delete
            // leftward, like a text caret sitting just before the image), NOT on the media.
            if i == 0 {
                return   // no previous block — no-op (Backspace at document start). Tap-select to delete a leading image.
            }
            if let prev = boxes[i - 1] as? BlockBox {
                if prev.textLength == 0 {
                    // Empty previous paragraph → delete it; the caret stays at the image's (now-shifted) gap.
                    editing {
                        var newBoxes = boxes
                        newBoxes.remove(at: i - 1)
                        boxes = newBoxes
                        recomputeSpans()
                        let gap = boxes[i - 1].nodeStart   // the image is now at i-1
                        return .caret(at: gap)
                    }
                } else {
                    // Non-empty → delete its last grapheme; the caret moves INTO it so subsequent
                    // Backspaces keep deleting there.
                    let prevEnd = prev.textStart + prev.textLength
                    let n = graphemeClusterLengthBeforeCaret(global: prevEnd)
                    editing(coalescing: .deleting) { applyReplaceOutcome(globalFrom: prevEnd - n, globalTo: prevEnd, text: "") }
                }
            } else {
                // Previous block is a non-text atom. Step the caret onto it WITHOUT deleting, but only to
                // a RENDERABLE position (a media block's caption slot / a code block's text end). A table or
                // block quote reports a non-renderable structural boundary (its own `nodeStart`,
                // since its `textLength` is 0) from `prevTextPosition`; moving the caret there would HIDE it
                // (and a follow-up Backspace could structurally delete the container). In that case leave the
                // caret at the gap — a safe, visible no-op.
                let dest = prevTextPosition(before: head)
                if dest != head, isRenderablePosition(dest) { setCaret(global: dest) }
            }
            return
        }
        // Collapsed caret with text before it inside a block quote (a child's body OR the author line) →
        // delete the grapheme in that leaf region. `resolveBox(at:)` below cannot resolve a position inside
        // the container (its `textLength == 0`), so without this it mis-resolves to the container (lone quote
        // → silent no-op) or to the following sibling (wrong block). Mirrors the `isInsideTable` branch above.
        if selFrom == selTo, isInsideBlockQuote(head),
           let (_, local) = leafRegion(containingGlobal: head), local > 0 {
            let n = graphemeClusterLengthBeforeCaret(global: head)
            editing(coalescing: .deleting) { applyLeafReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
            return
        }
        // Collapsed caret at the START (local 0) of a block quote CHILD. resolveBox below mis-resolves any
        // local-0 position inside the degenerate container to the FOLLOWING sibling block, so resolve it here
        // via activeStack and peel one structural level:
        //   • a quoted LIST item → outdent (nested) or break the list to a plain paragraph (top-level), in place;
        //   • a non-first NON-list child (index > 0) → merge into its previous sibling within the quote;
        //   • an EMPTY first NON-list child (a stray leading blank line) → removed, caret to the next child;
        //   • a NON-empty first NON-list child → un-quoted: extracted as a plain paragraph before the quote.
        // A lone NON-list child (count == 1) keeps the whole-quote un-quote branch below (line ~593).
        if selFrom == selTo, isInsideBlockQuote(head),
           let active = activeStack(at: head), let child = active.box as? BlockBox, active.local == 0 {
            if let list = child.listMembership {
                editing {
                    if list.level > 0 {
                        child.listMembership = ListMembership(marker: list.marker, level: list.level - 1, checked: list.checked)
                    } else {
                        child.listMembership = nil
                        child.style = .body
                    }
                    restyle(child)
                    recomputeSpans()
                    return .unchanged
                }
                return
            }
            if active.stack.boxes.count > 1 {
                if active.index > 0 {
                    editing { mergeParagraphsOutcome(in: active.stack, upperIndex: active.index - 1) }
                    return
                }
                if child.textLength == 0 {
                    editing {
                        active.stack.boxes.removeFirst()
                        recomputeSpans()
                        let caret = active.stack.boxes.first?.leafRegions().first?.globalStart ?? head
                        return .caret(at: caret)
                    }
                    return
                }
                // non-empty first child → un-quote it (extract as a plain paragraph before the quote)
                if let (quoteBox, parentStack, qIndex) = enclosingQuote(at: head),
                   case .blockQuote(let model) = quoteBox.currentBlock(), model.children.count > 1 {
                    editing {
                        let firstBox = makeBox(for: model.children[0], mapper: mapper, quoteStyle: quoteStyle,
                                               pullQuoteStyle: pullQuoteStyle, expandImage: quoteCollapseIcons?.expand,
                                               collapseImage: quoteCollapseIcons?.collapse, horizontalBleed: 0, width: effectiveWidth)
                        let restBox = makeBox(for: .blockQuote(BlockQuote(id: model.id, children: Array(model.children.dropFirst()),
                                                                          collapsed: model.collapsed, author: model.author)),
                                              mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                                              expandImage: quoteCollapseIcons?.expand, collapseImage: quoteCollapseIcons?.collapse,
                                              horizontalBleed: 0, width: effectiveWidth)
                        let replacement = [firstBox, restBox].compactMap { $0 }
                        parentStack.boxes.replaceSubrange(qIndex...qIndex, with: replacement)
                        recomputeSpans()
                        let caret = firstBox?.leafRegions().first?.globalStart ?? head
                        return .caret(at: caret)
                    }
                    return
                }
            } else {
                // A LONE non-list child at local 0 → un-quote the whole quote HERE, before the resolveBox path
                // below (which mis-resolves this in-quote position to a FOLLOWING block and could mis-fire the
                // list-item / merge branches, e.g. when the block after the quote is a list item). Reached via
                // activeStack so a mis-resolved following block can't pre-empt it. (The later count==1
                // un-quote branch is now redundant but harmless.)
                unwrapBlockQuoteLevel()
                return
            }
        }
        // Backspace inside a DETAILS body. `resolveBox` below mis-resolves a nested position (the details is a
        // degenerate container — `textLength == 0` — so a position inside it falls through to the following /
        // last top-level block), so resolve via `activeStack` here — mirrors the `isInsideTable` /
        // `isInsideBlockQuote` collapsed branches above. Without this, a caret at the start of a nested empty
        // paragraph whose previous sibling is an image cross-deletes into the image's caption instead of
        // removing the paragraph. (A nested block quote / table inside the details is handled by their own
        // branches above; this covers the details' own direct body paragraphs.)
        if selFrom == selTo, isInsideDetails(head), let active = activeStack(at: head), let child = active.box as? BlockBox {
            if active.local > 0 {
                let n = graphemeClusterLengthBeforeCaret(global: head)
                editing(coalescing: .deleting) { applyLeafReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
                return
            }
            // local == 0 → start of a nested paragraph. (A details body paragraph is always index >= 1;
            // `children[0]` is the title.)
            if let list = child.listMembership {
                if list.level > 0 { outdent() }
                else { editing { child.listMembership = nil; child.style = .body; restyle(child); recomputeSpans(); return .unchanged } }
                return
            }
            if active.index > 0 {
                let prev = active.stack.boxes[active.index - 1]
                // The title (`index 0`) and a non-paragraph atom (image / table / code / quote) can't absorb a
                // text merge: an EMPTY paragraph is removed (caret steps to the previous block's nearest text
                // slot); a non-empty one is kept (caret steps back).
                if active.index == 1 || isNonParagraphAtom(prev) {
                    let dest = prevTextPosition(before: head)
                    if child.textLength == 0 {
                        editing { active.stack.boxes.remove(at: active.index); recomputeSpans(); return .caret(at: dest) }
                    } else if dest != head, isRenderablePosition(dest) {
                        setCaret(global: dest)
                    }
                } else {
                    // Previous sibling is a text body paragraph → merge into it within the details stack.
                    editing { mergeParagraphsOutcome(in: active.stack, upperIndex: active.index - 1) }
                }
                return
            }
        }
        guard let pos = resolveBox(at: head) else { return }
        // Backspace at the START of a list item: cancel one indent level, or (at the top level) break the
        // list here — the item becomes a body paragraph keeping its contents, so items before it stay a
        // list and items after start a fresh one. Applies to ANY list item (empty or not) and takes
        // priority over the merge-into-previous / empty-quote branches below. Mirrors empty-list-item Return
        // (`insertParagraphBreak`), but fires for a non-empty item too and always exits to a body paragraph
        // (a quoted list item un-quotes, matching the one-step empty-quote Backspace).
        if pos.local == 0, let p = pos.box as? BlockBox, let list = p.listMembership {
            if list.level > 0 {
                outdent()
            } else {
                editing { p.listMembership = nil; p.style = .body; restyle(p); recomputeSpans(); return .unchanged }
            }
            return
        }
        // Backspace at the start of a LONE child of a block quote → un-quote one level (via unwrapBlockQuoteLevel).
        // "Lone" = the only child in its quote container (boxes.count == 1). Content is preserved; the quote
        // wrapper is removed and children are spliced to the parent. A non-lone child backspaces normally
        // (merges with the previous sibling). Mirrors the flat empty-quote branch above, adapted for the
        // `BlockQuoteBox` container structure.
        if selFrom == selTo, isInsideBlockQuote(head),
           let active = activeStack(at: head), let child = active.box as? BlockBox,
           active.local == 0,
           active.stack.boxes.count == 1 {
            unwrapBlockQuoteLevel()   // already wraps itself in editing { }
            return
        }
        if let codeBox = pos.box as? CodeBlockBox, codeBox.textLength == 0,
           let active = activeStack(at: head) {
            // Backspace in an EMPTY code block converts it to a body paragraph (a `CodeBlockBox` is a
            // distinct class, so it's REPLACED in its stack with a body `BlockBox`). Mirrors the empty-quote
            // branch above — without this an empty code block, especially the document's FIRST block, matches
            // no merge branch below and is undeletable.
            editing {
                let body = BlockBox(paragraph: ParagraphBlock(id: codeBox.id, style: .body, runs: []),
                                    mapper: mapper, width: effectiveWidth)
                var newBoxes = active.stack.boxes
                newBoxes.replaceSubrange(active.index...active.index, with: [body])
                active.stack.boxes = newBoxes
                recomputeSpans()
                return .caret(at: body.textStart)
            }
            return
        }
        if let pqBox = pos.box as? PullQuoteBox, pqBox.textLength == 0,
           let active = activeStack(at: head) {
            // Backspace in an EMPTY pull quote converts it to a body paragraph (`PullQuoteBox` is a distinct
            // class, so it's REPLACED in its stack with a body `BlockBox`). Mirrors the empty-code branch
            // above — without this an empty pull quote matches no merge branch below and is undeletable.
            editing {
                let body = BlockBox(paragraph: ParagraphBlock(id: pqBox.id, style: .body, runs: []),
                                    mapper: mapper, width: effectiveWidth)
                var newBoxes = active.stack.boxes
                newBoxes.replaceSubrange(active.index...active.index, with: [body])
                active.stack.boxes = newBoxes
                recomputeSpans()
                return .caret(at: body.textStart)
            }
            return
        }
        if pos.box is MediaBlockBox, pos.local == 0 {
            // Backspace at the start of a caption replaces the whole media block with an empty body paragraph
            // in place (caret there), discarding any caption text — consistent with the tap-selected and
            // object-replacement-selection paths (the gap branch above / applySelectionReplaceOutcome).
            editing { replaceMediaWithEmptyParagraphOutcome(at: pos.index) }
        } else if pos.local > 0 {
            let n = graphemeClusterLengthBeforeCaret(global: head)
            editing(coalescing: .deleting) { applyReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
        } else if pos.index > 0, isNonParagraphAtom(boxes[pos.index - 1]) {
            // A TABLE gets the select-then-delete treatment: first Backspace moves in + selects the whole
            // table, a second deletes it (deleteTableStructuralSelection at the top of deleteBackward).
            if selectPrecedingTableOnBackspace(paragraphIndex: pos.index) { return }
            // Start of a paragraph after a NON-TEXT block (image / code) that can't absorb a text
            // merge. Backspace must NOT delete that block. An EMPTY paragraph is removed — so "deleting the
            // last paragraph" is always possible; a non-empty one is kept. Either way the caret steps back
            // to that block's nearest text slot (an image's caption end, a code block's end) via
            // prevTextPosition — never the block's degenerate node-start boundary.
            let prev = prevTextPosition(before: head)
            if pos.box.textLength == 0 {
                editing { removeBlockOutcome(at: pos.index, parkingCaretAt: prev) }
            } else if prev != head {
                setCaret(global: prev)
            }
        } else if pos.index > 0 {
            let prev = boxes[pos.index - 1]
            let from = prev.textStart + prev.textLength
            // The cross-block merge runs through applyReplaceOutcome → ParagraphBlock.merging, which drops the merged-
            // in runs' pinned font size on a style mismatch (body→heading renders heading-sized).
            editing { applyReplaceOutcome(globalFrom: from, globalTo: head, text: "") }
        }
    }
}
#endif
