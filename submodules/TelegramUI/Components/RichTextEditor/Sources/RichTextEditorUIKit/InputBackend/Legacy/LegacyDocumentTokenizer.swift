#if canImport(UIKit)
import UIKit
import RichTextEditorCore

// TASK 44 MOVED THIS FILE FROM `S/Canvas/DocumentTokenizer.swift` INTO THE BACKEND, and the file name
// carries a `Legacy` prefix the TYPE name deliberately does not. Both halves need saying:
//
//  * **The move is where this type already belonged.** Task 43 moved the tokenizer's CONSTRUCTION and
//    OWNERSHIP onto `LegacyRichTextInputBackend` (`attach(to:)` mints it, `tokenizerStorage` caches
//    it, `detach()` clears it, and the canvas kept nothing); the backend vends it as
//    `var tokenizer: UITextInputTokenizer`. What was left in `S/Canvas/` was a `UITextInputTokenizer`
//    implementation — UIKit input-protocol currency, the seam's own subject — that reads the canvas as
//    a DATA SOURCE, exactly the shape of the `Telegram*InputClient` files already living under
//    `S/InputBackend/Clients/`. It is also the file that mints the most UIKit identity objects in the
//    package (twelve sites), and R6 asks the honest question of them: is this the backend, or is it a
//    leak out of it? It is the backend.
//  * **The file name, not the type name, carries the prefix.** `DocumentTokenizer` is named ~20 times
//    across four UIKit test files, and Task 44 edits NO UIKit test file (deviation D22 — see
//    `T/Support/LegacyIdentityTestAliases.swift`). Renaming the type would have edited all four.
//    Renaming only the file costs one dictionary key in
//    `test_theTokenizerHasExactlyOneConstructionSite` (which keys on `lastPathComponent`) and buys the
//    PRE-EXISTING `hasPrefix("Legacy")` exclusion in
//    `test_sharedContracts_referenceNoTelegramImplementationTypes` — the rule that (correctly) forbids
//    a shared contract file from naming `DocumentCanvasView`, which this implementation file must. No
//    boundary rule was widened or excluded for this move.
//
// **WHAT THE MOVE DID COST, recorded at the fix round (review Minor 6): this file left the
// `!inBackend` half of `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` — six scans at
// once (the D33 pair, the two composition doors, the publishing composition door, the three
// floating-cursor doors, the concrete-backend cap, and the named-store downcast list) — as well as
// R6.** No practical effect today: this file writes no input state, names no backend store, and
// never mentions `LegacyRichTextInputBackend`. But "move the file under `S/InputBackend/`" is now a
// demonstrated way to exempt canvas-adjacent code from that whole family in one commit, so a future
// move of a canvas file into this directory is a decision to argue, not a tidy-up. The R6 fix round
// makes the same point from the other side: being inside the backend directory is what made this
// file's `-> LegacyTextRange?` return types INVISIBLE to R6 while their three callers, outside it,
// unwrapped the result — see R6's KNOWN LIMITS.

/// A custom text tokenizer that computes text-unit boundaries from each leaf region's OWN string (a real
/// character stream), NOT from the global position axis (which interleaves text with structural token
/// slots). Word: macOS semantics — forward → the next word END, backward → the previous word START,
/// scanned per region with Foundation `.byWords`; crossing a region boundary uses the canvas's
/// `nextTextPosition`/`prevTextPosition` so blocks/cells/captions never glue into one word. Paragraph/
/// line == one leaf region. Every returned position is renderable by construction.
@available(iOS 13.0, *)
final class DocumentTokenizer: NSObject, UITextInputTokenizer {
    private unowned let canvas: DocumentCanvasView
    init(canvas: DocumentCanvasView) { self.canvas = canvas; super.init() }

    private func off(_ p: UITextPosition) -> Int { (p as? LegacyTextPosition)?.offset ?? 0 }

    // UITextDirection wraps a raw Int; forward = storage.forward (0) or layout.right (2) or layout.down (5).
    private func isForward(_ d: UITextDirection) -> Bool {
        d.rawValue == UITextStorageDirection.forward.rawValue
            || d.rawValue == UITextLayoutDirection.right.rawValue
            || d.rawValue == UITextLayoutDirection.down.rawValue
    }

    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity,
                  inDirection direction: UITextDirection) -> UITextPosition? {
        let pos = canvas.clampGlobal(off(position)); let fwd = isForward(direction)
        switch granularity {
        case .character:
            return LegacyTextPosition(fwd ? canvas.nextTextPosition(after: pos) : canvas.prevTextPosition(before: pos))
        case .word:
            return LegacyTextPosition(wordBoundary(from: pos, forward: fwd))
        case .sentence, .paragraph, .line:
            return LegacyTextPosition(regionBoundary(from: pos, forward: fwd))
        case .document:
            return fwd ? canvas.endOfDocument : canvas.beginningOfDocument
        @unknown default:
            return nil
        }
    }

    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity,
                    inDirection direction: UITextDirection) -> Bool {
        let pos = canvas.clampGlobal(off(position))
        switch granularity {
        case .character: return true
        case .word: return isWordBoundary(pos)
        case .sentence, .paragraph, .line: return isRegionBoundary(pos)
        case .document: return pos == off(canvas.beginningOfDocument) || pos == off(canvas.endOfDocument)
        @unknown default: return false
        }
    }

    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity,
                    inDirection direction: UITextDirection) -> Bool {
        // True iff `position` lies inside a unit of this granularity (used for extend/select). For our
        // model: inside a leaf region with a non-degenerate enclosing unit.
        guard let range = rangeEnclosingPosition(position, with: granularity, inDirection: direction),
              let lo = (range as? LegacyTextRange)?.from.offset,
              let hi = (range as? LegacyTextRange)?.to.offset else { return false }
        let p = canvas.clampGlobal(off(position))
        return p >= lo && p <= hi
    }

    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity,
                                inDirection direction: UITextDirection) -> UITextRange? {
        let pos = canvas.clampGlobal(off(position))
        guard canvas.leafRegion(containingGlobal: pos) != nil else { return nil }   // gaps have no unit
        switch granularity {
        case .word:
            guard let (lo, hi) = enclosingWord(at: pos) else { return nil }
            return LegacyTextRange(LegacyTextPosition(lo), LegacyTextPosition(hi))
        case .sentence, .paragraph, .line:
            guard let (lo, hi) = enclosingRegion(at: pos) else { return nil }
            return LegacyTextRange(LegacyTextPosition(lo), LegacyTextPosition(hi))
        default:
            return nil
        }
    }

    // MARK: - Select-menu ranges (direction-independent enclosing units)

    // TASK 44 FIX ROUND 1 (review Major 1) — **THESE TWO RETURN GLOBAL OFFSETS, NOT A
    // `LegacyTextRange`, AND THE CHANGE IS THE WHOLE POINT OF THE FINDING.**
    //
    // They used to return `LegacyTextRange?`. Their three callers all live OUTSIDE
    // `S/InputBackend/` (`+SelectionActions.swift`'s word/paragraph select, and
    // `+NativeTextCheckingClient.swift`'s spell-check word targeting), and each bound that concrete
    // backend identity type **by type inference** — `let r = t.wordRange(at: pos)` — and then read
    // `r.from.offset` straight through it. That is a canvas-layer site unwrapping a backend identity
    // object, which is exactly what R6 forbids, **while R6 reported zero**: no identity type name and
    // no construction or downcast appears textually at any of the three, and a source-text scan
    // cannot see an inferred type. The rule was green and the property it certifies was false.
    //
    // The shipped failure that would have caused: under a stage-2 backend vending its own
    // `UITextInputTokenizer`, all three `tokenizer as? DocumentTokenizer` casts go nil and
    // double-tap word select, triple-tap paragraph select and spell-check word targeting SILENTLY
    // no-op — three user-visible regressions, no compile error, and R6 still certifying zero.
    //
    // Fixed by removing the leak rather than by widening the regex to chase it (a regex cannot close
    // an inference hole). The tuple is what all three callers actually consumed — every one of them
    // immediately read `.from.offset`/`.to.offset` and threw the object away.

    /// The word range enclosing `pos` (direction-independent), for the Select menu action, as GLOBAL
    /// UTF-16 offsets. nil at a gap.
    func wordRange(at pos: Int) -> (from: Int, to: Int)? {
        guard let (lo, hi) = enclosingWord(at: canvas.clampGlobal(pos)) else { return nil }
        return (lo, hi)
    }
    /// The paragraph/region range enclosing `pos`, for triple-tap / paragraph select, as GLOBAL
    /// UTF-16 offsets. nil at a gap.
    func paragraphRange(at pos: Int) -> (from: Int, to: Int)? {
        guard let (lo, hi) = enclosingRegion(at: canvas.clampGlobal(pos)) else { return nil }
        return (lo, hi)
    }

    // MARK: - Word

    private func wordRanges(_ s: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        s.enumerateSubstrings(in: NSRange(location: 0, length: s.length), options: [.byWords, .substringNotRequired]) { _, r, _, _ in
            ranges.append(r)
        }
        return ranges
    }

    /// Forward → the next word END after `pos` within its region, else cross to the next region/gap.
    /// Backward → the previous word START before `pos`, else cross to the previous region/gap.
    private func wordBoundary(from pos: Int, forward fwd: Bool) -> Int {
        guard let (r, local) = canvas.leafRegion(containingGlobal: pos) else {
            // A structural-token slot (no owning region). Image gaps ARE renderable, so step off them;
            // a pure structural slot is not, so snap onto the nearest renderable slot in the travel
            // direction first, otherwise next/prevTextPosition would walk onto another structural slot.
            if canvas.isGapPosition(pos) {
                return fwd ? canvas.nextTextPosition(after: pos) : canvas.prevTextPosition(before: pos)
            }
            return canvas.snapToRenderable(pos, forward: fwd)
        }
        let s = r.layout.attributedString.string as NSString
        let ranges = wordRanges(s)
        if fwd {
            if let end = ranges.map({ $0.location + $0.length }).filter({ $0 > local }).min() {
                return r.globalStart + end
            }
            // No further word in this region → cross into the next region and continue to ITS first
            // word end, so one Option+Right reaches the next word's end (macOS). Stop at an image gap or
            // the document end. Terminates: each cross advances strictly to a later region.
            let regionEnd = r.globalStart + r.length
            let next = canvas.nextTextPosition(after: regionEnd)
            if next == regionEnd || canvas.isGapPosition(next) { return next }
            return wordBoundary(from: next, forward: true)
        } else {
            if let start = ranges.map({ $0.location }).filter({ $0 < local }).max() {
                return r.globalStart + start
            }
            let prev = canvas.prevTextPosition(before: r.globalStart)
            if prev == r.globalStart || canvas.isGapPosition(prev) { return prev }
            return wordBoundary(from: prev, forward: false)
        }
    }

    private func enclosingWord(at pos: Int) -> (Int, Int)? {
        guard let (r, local) = canvas.leafRegion(containingGlobal: pos) else { return nil }
        let s = r.layout.attributedString.string as NSString
        var result: (Int, Int)?
        s.enumerateSubstrings(in: NSRange(location: 0, length: s.length), options: [.byWords, .substringNotRequired]) { _, range, _, stop in
            if local >= range.location && local <= range.location + range.length {
                result = (r.globalStart + range.location, r.globalStart + range.location + range.length)
                stop.pointee = true
            }
        }
        return result
    }

    private func isWordBoundary(_ pos: Int) -> Bool {
        guard let (r, local) = canvas.leafRegion(containingGlobal: pos) else { return true }
        let s = r.layout.attributedString.string as NSString
        if local == 0 || local == s.length { return true }
        var atBoundary = false
        s.enumerateSubstrings(in: NSRange(location: 0, length: s.length), options: [.byWords, .substringNotRequired]) { _, range, _, stop in
            if local == range.location || local == range.location + range.length { atBoundary = true; stop.pointee = true }
        }
        return atBoundary
    }

    // MARK: - Region (paragraph / line / sentence v1)

    private func enclosingRegion(at pos: Int) -> (Int, Int)? {
        guard let (r, _) = canvas.leafRegion(containingGlobal: pos) else { return nil }
        return (r.globalStart, r.globalStart + r.length)
    }

    private func regionBoundary(from pos: Int, forward fwd: Bool) -> Int {
        guard let (lo, hi) = enclosingRegion(at: pos) else {
            if canvas.isGapPosition(pos) {
                return fwd ? canvas.nextTextPosition(after: pos) : canvas.prevTextPosition(before: pos)
            }
            return canvas.snapToRenderable(pos, forward: fwd)
        }
        if fwd { return pos < hi ? hi : canvas.nextTextPosition(after: hi) }
        return pos > lo ? lo : canvas.prevTextPosition(before: lo)
    }

    private func isRegionBoundary(_ pos: Int) -> Bool {
        guard let (lo, hi) = enclosingRegion(at: pos) else { return true }
        return pos == lo || pos == hi
    }
}
#endif
