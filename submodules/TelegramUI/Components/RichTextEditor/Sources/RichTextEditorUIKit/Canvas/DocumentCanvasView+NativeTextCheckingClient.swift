#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The canvas as the native checking controller's CLIENT. It already implements the public `UITextInput`
/// read surface the controller drives itself with (`textInRange:`, position algebra, `selectedTextRange`);
/// this file adds the controller-facing annotation-delivery methods (messaged via the ObjC runtime by
/// `NativeTextChecker`, so they must keep their exact `@objc` selector names) plus the translation core that
/// turns a delivered annotation range into the existing `spellResults` store the overlay already renders.
/// Display-only: nothing here ever touches `Document` / `RichTextEditorCore`.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Lazily starts the native driver once checking is enabled and the class resolved (no fallback — see
    /// `NativeTextChecking.swift`). Safe to call repeatedly; a no-op once installed (or permanently unavailable).
    func installNativeCheckingIfNeeded() {
        guard isSpellCheckingEnabled, nativeChecker == nil else { return }
        nativeChecker = NativeTextChecker(client: self)   // canvas IS the client (already a UITextInput)
        nativeChecker?.preheat()
    }

    /// Native-parity check targets for a caret move from `fromCaret` to `toCaret` (global positions).
    /// Mirrors `-[UITextCheckingController checkSpellingForSelectionChangeFromRange:]`: the word ENCLOSING
    /// the caret you LEFT is re-checked; the word ENCLOSING the caret you're now IN has its flag cleared (so
    /// it isn't underlined mid-edit). Same word (still typing in it) ⇒ (nil, nil). Ranges are GLOBAL, the
    /// axis `spellResults` uses; nil where the position is at a gap / has no enclosing word.
    func spellCheckTargets(fromCaret: Int, toCaret: Int) -> (check: NSRange?, clear: NSRange?) {
        let tok = tokenizer as? DocumentTokenizer
        func wordNS(_ pos: Int) -> NSRange? {
            guard let r = tok?.wordRange(at: pos) else { return nil }
            return NSRange(location: r.from, length: r.to - r.from)
        }
        let left = wordNS(fromCaret), entered = wordNS(toCaret)
        if let l = left, l == entered { return (nil, nil) }   // caret stayed within one word
        return (left, entered)
    }

    /// Native-parity selection-driven checking: on a COLLAPSED-caret move, re-check the word just LEFT and
    /// clear the flag on the word now under the caret (both from `spellCheckTargets`). This replaces the old
    /// debounced full-document scan — a word flags the instant you leave it (space/punctuation), and text the
    /// caret never traverses (a loaded draft, a paste) is never flagged. Skipped while coalescing (loupe /
    /// selection-handle drag) to mirror the suppressed `inputDelegate` selection bracket; `endCoalescedSelectionDrag`
    /// runs it once at the final caret. A range selection is not a typing boundary — record the head and skip.
    func nativeCheckOnSelectionChange() {
        // TASK 43: reads the backend's D33 flag directly — `coalescingSelectionNotifications` was the
        // canvas forwarder onto exactly this, and is deleted.
        guard isSpellCheckingEnabled, let checker = nativeChecker,
              !inputBackend.suppressesSelectionNotifications else { return }
        let now = head
        defer { lastCheckedCaret = now }
        // An active `.correction` (autocorrect underline) clears once the caret moves to a DIFFERENT region than
        // the corrected word's — matching iOS clearing the revert affordance when you move on to another line.
        // Runs on every selection change (before the word-check guard below, which may early-return).
        if let (nowRegion, _) = leafRegion(containingGlobal: now), let nowId = spellCheckableRef(nowRegion.ref) {
            let correctionIsElsewhere = spellResults.contains { id, entry in
                id != nowId && entry.ranges.contains { $0.style == .correction }
            }
            if correctionIsElsewhere { clearAllCorrectionFlags() }
        }
        guard selFrom == selTo, let prev = lastCheckedCaret, prev != now else { return }
        let targets = spellCheckTargets(fromCaret: prev, toCaret: now)
        // Style-isolated: a word-level move only ever touches `.spelling` flags, so it can't clear a `.grammar`
        // flag covering the same text (grammar operates at sentence granularity, below).
        if let clear = targets.clear { clearNativeAnnotations(global: clear, onlyStyle: .spelling) }   // word now under the caret
        if let check = targets.check {
            clearNativeAnnotations(global: check, onlyStyle: .spelling)   // drop any stale flag before re-checking…
            driveNativeCheck(style: .spelling) { checker.checkSpellingForWord(inGlobal: check) }   // …then re-flag if it's still misspelled
        }

        // Grammar parity: when the caret crosses a SENTENCE boundary, re-check the sentence just left and clear
        // grammar markers on the sentence now under the caret (mirrors the grammar half of the native driver).
        if let prevS = sentenceGlobalRange(atGlobal: prev), let nowS = sentenceGlobalRange(atGlobal: now), prevS != nowS {
            clearNativeAnnotations(global: nowS, onlyStyle: .grammar)    // sentence now under the caret
            clearNativeAnnotations(global: prevS, onlyStyle: .grammar)   // drop stale before re-check
            driveNativeCheck(style: .grammar) { checker.checkGrammarForSentence(inGlobal: prevS) }
        }
    }

    /// Runs a `checkSpellingForWord`/`checkGrammarForSentence` call with `inFlightCheckStyle` set to `style`,
    /// so a `nativeRemoveAnnotation` callback fired SYNCHRONOUSLY from inside `body` (verified live — the
    /// controller calls back to clear a checked word/sentence found clean) clears only that style instead of
    /// wiping an unrelated overlapping flag (see `inFlightCheckStyle`'s doc on `DocumentCanvasView`).
    func driveNativeCheck(style: SpellStyle, _ body: () -> Void) {
        inFlightCheckStyle = style
        body()
        inFlightCheckStyle = nil
    }

    // MARK: client annotation surface (messaged by the controller via the ObjC runtime)
    /// Build a `UITextRange` from a RAW global position range (the axis `spellResults` uses). The driver
    /// calls this instead of `positionFromPosition:offset:`, which is relative to `beginningOfDocument` (itself
    /// at global 1 on this 1-based axis) and would double-count the offset. The backend's identity
    /// position wraps a global offset directly, so this is exact.
    ///
    /// TASK 44: was `DocumentTextRange(DocumentTextPosition(loc), DocumentTextPosition(loc + length))`
    /// inline. Same object, minted on the backend side; this file no longer names the type.
    @objc(nativeTextRangeForGlobalLocation:length:)
    func nativeTextRange(forGlobalLocation loc: Int, length: Int) -> UITextRange? {
        LegacyTextIdentity.range(fromGlobal: loc, toGlobal: loc + length)
    }

    @objc(annotatedSubstringForRange:)
    func annotatedSubstring(for range: UITextRange) -> NSAttributedString? {
        guard LegacyTextIdentity.globalRange(of: range) != nil else { return nil }
        return NSAttributedString(string: text(in: range) ?? "")
    }
    @objc(replaceRange:withAnnotatedString:relativeReplacementRange:)
    func nativeReplace(_ range: UITextRange, withAnnotatedString s: NSAttributedString, relativeReplacementRange rr: NSRange) {
        guard let r = LegacyTextIdentity.globalRange(of: range) else { return }
        let base = min(r.from, r.to)
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { attrs, sub, _ in
            guard !attrs.isEmpty else { return }
            let global = NSRange(location: base + sub.location, length: sub.length)
            let style = Self.style(from: attrs)
            applyNativeAnnotations(global: global, style: style)
            // Only `.correction` carries delivered candidates (see `style(from:)`); best-effort — not
            // observed firing in the test host, so this is infrastructure, not a verified-live path.
            if style == .correction, let alt = attrs[Self.alternativesKey] {
                stashSpellingAlternatives(global: global, alternatives: alt)
            }
        }
    }
    @objc(removeAnnotation:forRange:)
    func nativeRemoveAnnotation(_ annotation: Any, forRange range: UITextRange) {
        guard let r = LegacyTextIdentity.globalRange(of: range) else { return }
        let global = NSRange(location: min(r.from, r.to), length: abs(r.to - r.from))
        // Scoped to the in-flight check's style when this fires synchronously from `driveNativeCheck` (the
        // common case — see that method's doc); otherwise style-agnostic (e.g. a controller-driven removal
        // outside our own check calls, if any).
        if let style = inFlightCheckStyle { clearNativeAnnotations(global: global, onlyStyle: style) }
        else { clearNativeAnnotations(global: global) }
    }
    @objc var validAnnotations: [Any] { [] }
    // `UITextInputTraits` optional requirements ({ get set } in Objective-C) — matches the existing
    // trait-property convention in `+MarkedText.swift` (no explicit `@objc`; a no-op setter). An explicit
    // `@objc` here duplicates the compiler-synthesized protocol-witness thunk and fails to build
    // ("conflicts with optional requirement getter in protocol 'UITextInputTraits'").
    var smartDashesType: UITextSmartDashesType { get { .no } set { } }
    var smartQuotesType: UITextSmartQuotesType { get { .no } set { } }
    var smartInsertDeleteType: UITextSmartInsertDeleteType { get { .no } set { } }

    /// Classify a delivered annotation. The controller marks the flagged range with `NSTextAlternativesDisplayStyle`
    /// (a private display-style int) and, for a correction, an `NSTextAlternatives` object (the candidates + the
    /// original). Observed live: a spelling flag is displayStyle 2 with NO alternatives. So: alternatives present
    /// ⇒ `.correction`; displayStyle 2 ⇒ `.spelling`; any other display style (no alternatives) ⇒ `.grammar`.
    static let displayStyleKey = NSAttributedString.Key(ObfuscatedStrings.decode(ObfuscatedStrings.attrDisplayStyle))
    static let alternativesKey = NSAttributedString.Key(ObfuscatedStrings.decode(ObfuscatedStrings.attrAlternatives))
    static func style(from attrs: [NSAttributedString.Key: Any]) -> SpellStyle {
        if attrs[alternativesKey] != nil { return .correction }
        return (attrs[displayStyleKey] as? Int) == 2 ? .spelling : .grammar
    }

    // MARK: translation core (unit-tested) — GLOBAL range in, REGION-LOCAL range stored (mirrors the old pass)

    /// Resolve `global` to its region, owning block id, and CLAMPED region-local range, applying the exclusion
    /// filter (link / inline-code / spoiler / marked-range / in-progress caret word). Shared by
    /// `applyNativeAnnotations` and `stashSpellingAlternatives` so both honor the exact same region-boundary
    /// clamp — a controller-delivered range can (for grammar/sentence checks) span a region boundary, and an
    /// unclamped local range would overrun `region.layout.attributedString` and crash `enumerateAttributes(in:)`
    /// in `isExcludedSpellRange`.
    func clampedSpellRegionLocal(global: NSRange) -> (region: LeafTextRegion, id: BlockID, local: NSRange)? {
        guard global.length > 0, let (region, _) = leafRegion(containingGlobal: global.location),
              let id = spellCheckableRef(region.ref) else { return nil }
        let localLoc = global.location - region.globalStart
        let localLen = min(global.length, region.length - localLoc)
        guard localLoc >= 0, localLen > 0 else { return nil }
        let local = NSRange(location: localLoc, length: localLen)
        guard !isExcludedSpellRange(local, in: region) else { return nil }
        return (region, id, local)
    }

    func applyNativeAnnotations(global: NSRange, style: SpellStyle) {
        guard let (_, id, local) = clampedSpellRegionLocal(global: global) else { return }
        var entry = spellResults[id] ?? (0, [])
        entry.ranges.removeAll { $0.range == local }
        entry.ranges.append((local, style))
        spellResults[id] = entry
        setNeedsSpellUnderlineDisplay()
    }

    /// Stash a delivered `.correction` flag's candidate replacements, region-local (via `clampedSpellRegionLocal`,
    /// the same translation + clamp `applyNativeAnnotations` uses). `NSTextAlternatives` is not publicly
    /// constructible on iOS, but the DELIVERED instance responds to KVC for `alternativeStrings`/`primaryString`
    /// — every read is guarded (`responds(to:)` before `value(forKey:)`), so an unexpected shape is a no-op,
    /// never a crash.
    func stashSpellingAlternatives(global: NSRange, alternatives: Any) {
        guard let (_, id, local) = clampedSpellRegionLocal(global: global), let obj = alternatives as? NSObject,
              let candidates = kvcStringArray(obj, ObfuscatedStrings.decode(ObfuscatedStrings.kvcAlternativeStrings)),
              !candidates.isEmpty else { return }
        let primary = kvcString(obj, ObfuscatedStrings.decode(ObfuscatedStrings.kvcPrimaryString))
        var entry = spellingAlternatives[id] ?? []
        entry.removeAll { $0.range == local }
        entry.append((local, candidates, primary))
        spellingAlternatives[id] = entry
    }
    private func kvcStringArray(_ obj: NSObject, _ key: String) -> [String]? {
        guard obj.responds(to: NSSelectorFromString(key)) else { return nil }
        return obj.value(forKey: key) as? [String]
    }
    private func kvcString(_ obj: NSObject, _ key: String) -> String? {
        guard obj.responds(to: NSSelectorFromString(key)) else { return nil }
        return obj.value(forKey: key) as? String
    }

    func clearNativeAnnotations(global: NSRange) {
        guard let (region, _) = leafRegion(containingGlobal: global.location),
              let id = spellCheckableRef(region.ref), var entry = spellResults[id] else { return }
        let local = NSRange(location: global.location - region.globalStart, length: global.length)
        entry.ranges.removeAll { NSIntersectionRange($0.range, local).length > 0 || $0.range == local }
        spellResults[id] = entry
        setNeedsSpellUnderlineDisplay()
    }

    /// The GLOBAL range of the sentence enclosing `pos`, within its (checkable) region, else nil. Sentence
    /// granularity via `NSString.enumerateSubstrings(.bySentences)` — the axis the grammar checker expects
    /// (matches native's per-sentence `checkGrammarForSentenceInRange:`).
    func sentenceGlobalRange(atGlobal pos: Int) -> NSRange? {
        guard let (region, _) = leafRegion(containingGlobal: pos), spellCheckableRef(region.ref) != nil else { return nil }
        let local = pos - region.globalStart
        let ns = region.layout.attributedString.string as NSString
        var found: NSRange?
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                               options: [.bySentences, .substringNotRequired]) { _, r, _, stop in
            if local >= r.location && local <= r.location + r.length { found = r; stop.pointee = true }
        }
        return found.map { NSRange(location: region.globalStart + $0.location, length: $0.length) }
    }

    /// Clear only flags of `onlyStyle` intersecting `global` (so a grammar re-check doesn't wipe spelling
    /// flags in the same sentence, and vice versa). Region-local, same translation as `clearNativeAnnotations`.
    func clearNativeAnnotations(global: NSRange, onlyStyle: SpellStyle) {
        guard let (region, _) = leafRegion(containingGlobal: global.location),
              let id = spellCheckableRef(region.ref), var entry = spellResults[id] else { return }
        let local = NSRange(location: global.location - region.globalStart, length: global.length)
        entry.ranges.removeAll { $0.style == onlyStyle && NSIntersectionRange($0.range, local).length > 0 }
        spellResults[id] = entry
        setNeedsSpellUnderlineDisplay()
    }
}
#endif
