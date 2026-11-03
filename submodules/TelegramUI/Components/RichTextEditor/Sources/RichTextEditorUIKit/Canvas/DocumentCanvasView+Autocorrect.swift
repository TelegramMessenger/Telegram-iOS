#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Classify a `replace(_:withText:)` call as a keyboard autocorrection. The keyboard delivers an applied
    /// autocorrection as a single-token replace of the just-typed word with a different single token (spike-proven:
    /// `replace(old='Wrl', new='Well')`). Returns the ORIGINAL word (for revert) when this looks like an
    /// autocorrection — both sides non-empty, whitespace-free, and differing — else nil (multi-word dictation, an
    /// identity replace, or a non-word replacement is not flagged).
    func detectAutocorrection(oldText: String?, newText: String) -> String? {
        guard let old = oldText, !old.isEmpty, !newText.isEmpty, old != newText,
              !old.contains(where: { $0.isWhitespace }), !newText.contains(where: { $0.isWhitespace }) else { return nil }
        return old
    }

    /// Flag the corrected word `.correction` (blue solid underline) and stash the original for "Revert to …".
    /// Unlike the spelling path this MUST bypass the caret-word/marked-range suppression (native shows the
    /// autocorrect underline adjacent to the caret) — but it still skips a link / inline-code / spoiler run.
    /// Only ONE `.correction` is kept active (a later autocorrection supersedes the earlier), matching iOS.
    func applyCorrectionFlag(global: NSRange, original: String) {
        guard global.length > 0, let (region, _) = leafRegion(containingGlobal: global.location),
              let id = spellCheckableRef(region.ref) else { return }
        let localLoc = global.location - region.globalStart
        let localLen = min(global.length, region.length - localLoc)
        guard localLoc >= 0, localLen > 0 else { return }
        let local = NSRange(location: localLoc, length: localLen)
        // Inline exclusion only (NOT the caret-word/marked exclusion): skip a link / inline-code / spoiler run.
        var inlineExcluded = false
        region.layout.attributedString.enumerateAttributes(in: local, options: []) { attrs, _, stop in
            if attrs[.link] != nil || attrs[.rtInlineCode] != nil || attrs[.rtSpoiler] != nil {
                inlineExcluded = true; stop.pointee = true
            }
        }
        guard !inlineExcluded else { return }
        clearAllCorrectionFlags()   // at most one active correction
        var entry = spellResults[id] ?? (0, [])
        entry.ranges.append((local, .correction))
        spellResults[id] = entry
        var alts = spellingAlternatives[id] ?? []
        alts.removeAll { $0.range == local }
        alts.append((local, [], original))
        spellingAlternatives[id] = alts
        setNeedsSpellUnderlineDisplay()
    }

    /// Remove every active `.correction` flag (and its stashed alternative) across all regions. Snapshots the
    /// keys before mutating (never mutate a dictionary while iterating it).
    func clearAllCorrectionFlags() {
        var changed = false
        for id in Array(spellResults.keys) {
            guard var entry = spellResults[id] else { continue }
            let kept = entry.ranges.filter { $0.style != .correction }
            if kept.count != entry.ranges.count { entry.ranges = kept; spellResults[id] = entry; changed = true }
        }
        // Drop stashed alternatives that no longer back a `.correction` range.
        for id in Array(spellingAlternatives.keys) {
            let correctionRanges = Set((spellResults[id]?.ranges ?? []).filter { $0.style == .correction }.map { $0.range })
            if let alts = spellingAlternatives[id] {
                let kept = alts.filter { correctionRanges.contains($0.range) }
                if kept.count != alts.count { spellingAlternatives[id] = kept }
            }
        }
        if changed { setNeedsSpellUnderlineDisplay() }
    }
}
#endif
