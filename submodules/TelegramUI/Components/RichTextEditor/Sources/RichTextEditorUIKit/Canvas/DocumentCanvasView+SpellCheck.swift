#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The block key for a CHECKABLE region, else nil. Prose is checked (`paragraph`/`caption`/`pullQuote`);
    /// code, code-LANGUAGE and quote-author regions are skipped (a language name is an identifier, not
    /// prose — iOS would underline `kotlin`; author is metadata).
    func spellCheckableRef(_ ref: TextNodeRef) -> BlockID? {
        switch ref {
        case .paragraph(let id), .caption(let id), .pullQuote(let id), .detailsTitle(let id): return id
        case .code, .quoteAuthor, .codeLanguage: return nil
        }
    }

    /// True when a misspelled range overlaps a non-checkable inline: a link run, an inline-code run
    /// (`.rtInlineCode`, an `NSAttributedString.Key` defined in `AttributedStringMapper.swift`), or an inline
    /// spoiler run (`.rtSpoiler` — its text is hidden behind the dust overlay, so flagging it would leak the
    /// word's length/position through the underline), the active IME marked range, or the word currently
    /// under the caret (don't flag a half-typed word). `range` and the storage attributes share the
    /// region-local axis. (Emoji atoms are a single `U+FFFC` — a word boundary to the checker — so they are
    /// never inside a flagged word and need no explicit exclusion.)
    func isExcludedSpellRange(_ range: NSRange, in region: LeafTextRegion) -> Bool {
        let storage = region.layout.attributedString
        var excluded = false
        storage.enumerateAttributes(in: range, options: []) { attrs, _, stop in
            if attrs[.link] != nil || attrs[.rtInlineCode] != nil || attrs[.rtSpoiler] != nil {
                excluded = true; stop.pointee = true
            }
        }
        if excluded { return true }
        // The composing (marked) range, in region-local coords. Clamp to the region before constructing the
        // `NSRange` — when the composing region precedes (or follows) the region being scanned, `lo`/`hi` go
        // negative or past `region.length`, and a negative `NSRange.location` is fragile.
        if let m = markedRange {
            let lo = m.from - region.globalStart, hi = m.to - region.globalStart
            let lo2 = max(0, lo), hi2 = min(region.length, hi)
            if NSIntersectionRange(range, NSRange(location: lo2, length: max(0, hi2 - lo2))).length > 0 { return true }
        }
        // The word under a collapsed caret (in this region) — don't flag the in-progress word.
        if selFrom == selTo, head >= region.globalStart, head <= region.globalStart + region.length {
            let caretLocal = head - region.globalStart
            if caretLocal >= range.location && caretLocal <= range.location + range.length { return true }
        }
        return false
    }

    /// Redraw hook — the overlays that composite the underline: the body/caption wash, plus every realized
    /// table's cell overlay (which rides that table's own horizontal scroll and so draws separately).
    func setNeedsSpellUnderlineDisplay() {
        selectionHighlight.setNeedsDisplay()
        for case let t as TableBlockBox in boxes {
            (blockViews[t.id] as? TableBackingView)?.setNeedsDisplay()
        }
    }

    /// Flagged words as GLOBAL ranges paired with their region (region-local range + `globalStart`).
    func spellingWordRanges() -> [(region: LeafTextRegion, global: NSRange, style: SpellStyle)] {
        guard isSpellCheckingEnabled, !spellResults.isEmpty else { return [] }
        var out: [(LeafTextRegion, NSRange, SpellStyle)] = []
        for region in allLeafRegions() {
            guard let id = spellCheckableRef(region.ref), let entry = spellResults[id] else { continue }
            for (r, style) in entry.ranges {
                out.append((region, NSRange(location: region.globalStart + r.location, length: r.length), style))
            }
        }
        return out
    }

    /// The themed underline color for a native flag style.
    func spellingUnderlineColor(_ style: SpellStyle) -> UIColor {
        switch style {
        case .spelling: return mapper.theme.misspellingUnderline
        case .grammar: return mapper.theme.grammarUnderline
        case .correction: return mapper.theme.correctionUnderline
        }
    }

    /// Canvas-space dash baselines for the flagged words in NON-table regions (table cells draw separately
    /// in `TableBackingView.drawCellSpelling`). `isInsideTable` is the existing container test.
    func spellingUnderlineRects() -> [(rect: CGRect, style: SpellStyle)] {
        var lines: [(CGRect, SpellStyle)] = []
        for (region, global, style) in spellingWordRanges() where !isInsideTable(region.globalStart) {
            for seg in selectionRects(globalFrom: global.location,
                                      globalTo: global.location + global.length,
                                      regionFilter: { $0.globalStart == region.globalStart }) {
                lines.append((CGRect(x: seg.minX, y: seg.maxY - 1, width: seg.width, height: 1), style))
            }
        }
        return lines
    }

    /// The flagged word whose rendered rects contain `point` (canvas coords), with its guesses. `selectionRects`
    /// already folds table horizontal-scroll offset, so one canvas-space test covers body and cells alike.
    /// Guesses are sourced by the flagged range's style — see `spellingGuesses(forGlobal:style:region:)`.
    func misspelledWord(atCanvasPoint point: CGPoint) -> (range: NSRange, guesses: [String])? {
        guard isSpellCheckingEnabled else { return nil }
        for (region, global, style) in spellingWordRanges() {
            let rects = selectionRects(globalFrom: global.location, globalTo: global.location + global.length,
                                       regionFilter: { $0.globalStart == region.globalStart })
            guard rects.contains(where: { $0.insetBy(dx: -2, dy: -2).contains(point) }) else { continue }
            return (global, spellingGuesses(forGlobal: global, style: style, region: region))
        }
        return nil
    }

    /// Candidate replacements for a flagged word, sourced by its `SpellStyle`: `.correction` prefers its
    /// stashed delivered `NSTextAlternatives` (best-effort — see `spellingAlternatives`'s doc); everything else
    /// (`.spelling`/`.grammar`, and a `.correction` with no stashed entry) asks the public `UITextChecker`
    /// directly via `nativeSpellingGuesses`.
    private func spellingGuesses(forGlobal global: NSRange, style: SpellStyle, region: LeafTextRegion) -> [String] {
        if style == .correction, let id = spellCheckableRef(region.ref) {
            let local = NSRange(location: global.location - region.globalStart, length: global.length)
            if let stashed = spellingAlternatives[id]?.first(where: { $0.range == local }) {
                return stashed.candidates
            }
        }
        return nativeSpellingGuesses(forGlobal: global)
    }

    /// `.spelling`/`.grammar` guesses: the flagged range carries no delivered alternatives (live discovery —
    /// see the N4 corrected brief), so this reads the tapped word via `text(in:)` and asks the PUBLIC
    /// `UITextChecker` for candidates — a guesses-ONLY lookup; the checking PASS itself stays native
    /// (`NativeTextChecker`). Language: the keyboard's current primary language mapped to
    /// `UITextChecker.availableLanguages`, else the first available language, else `"en_US"`.
    func nativeSpellingGuesses(forGlobal range: NSRange) -> [String] {
        guard let textRange = nativeTextRange(forGlobalLocation: range.location, length: range.length),
              let word = text(in: textRange), !word.isEmpty else { return [] }
        let available = UITextChecker.availableLanguages
        let primary = textInputMode?.primaryLanguage
        let lang = (primary.flatMap { available.contains($0) ? $0 : nil }) ?? available.first ?? "en_US"
        let ns = word as NSString
        return UITextChecker().guesses(forWordRange: NSRange(location: 0, length: ns.length), in: word, language: lang) ?? []
    }

    /// Handle a tap that may land on a spelling-flagged word by TOGGLING its correction menu. Returns false
    /// when `point` isn't on a flagged word (the caller then falls through to normal caret handling).
    ///
    /// Toggle semantics mirror `menuToggleAction`, so a repeated tap on the SAME word doesn't flicker
    /// (close-then-reopen): when that word's menu is already showing (`editMenuVisible`) OR was just
    /// auto-dismissed by this tap's own touch-down (within `menuToggleSuppressWindow`), the tap CLOSES the menu
    /// instead of re-presenting it; otherwise it selects the word and presents the guesses. It fires regardless
    /// of a prior focused tap — a tap directly on a red word means "correct it", so the caller no longer gates
    /// this behind `wasFirstResponder` (the field is already made first responder before this runs). Clears any
    /// active table structural (row/column) selection first — otherwise it would survive the tap and the next
    /// hardware Backspace would delete the selected rows/columns instead of correcting the word.
    @discardableResult
    func beginSpellingCorrection(at point: CGPoint) -> Bool {
        guard let hit = misspelledWord(atCanvasPoint: point) else { return false }
        clearStructuralSelections()
        let justDismissed = Date().timeIntervalSinceReferenceDate - lastMenuDismissTime < Self.menuToggleSuppressWindow
        if editMenuVisible || justDismissed, pendingSpellingMenu?.range == hit.range {
            pendingSpellingMenu = nil          // same word's menu is up / was just closed by this tap → toggle OFF, don't re-present
            dismissEditMenu()
            return true
        }
        applySelection(from: hit.range.location, to: hit.range.location + hit.range.length)
        pendingSpellingMenu = (hit.range, hit.guesses, revertTarget(forGlobal: hit.range))
        presentEditMenu()
        return true
    }

    /// The pre-correction original word for a `.correction` flag at `global`, else nil — a `.spelling`/
    /// `.grammar` flag (no stashed alternatives) or a `.correction` flag with no stashed entry (best-effort;
    /// see `spellingAlternatives`'s doc) both yield nil, so the N5 "Revert to …" menu action is simply absent.
    private func revertTarget(forGlobal global: NSRange) -> String? {
        guard let (region, _, style) = spellingWordRanges().first(where: { $0.global == global }),
              style == .correction, let id = spellCheckableRef(region.ref) else { return nil }
        let local = NSRange(location: global.location - region.globalStart, length: global.length)
        return spellingAlternatives[id]?.first(where: { $0.range == local })?.primary
    }

    /// Replace the pending word with `guess` as ONE undo step; clear the menu context. The replacement can land
    /// the caret back inside the replaced word (a same-length correction, or any same-word landing), so the
    /// selection-driven driver's `prev != now` / same-word guards may not re-check it — clear the old flag and
    /// re-check the new word explicitly, so a correction drops its squiggle and a revert re-flags a word that
    /// is still misspelled.
    func applySpellingReplacement(_ guess: String) {
        guard let pending = pendingSpellingMenu else { return }
        pendingSpellingMenu = nil
        editing { applySelectionReplaceOutcome(globalFrom: pending.range.location,
                                        globalTo: pending.range.location + pending.range.length, text: guess) }
        clearNativeAnnotations(global: pending.range, onlyStyle: .spelling)   // the corrected word's spelling flag only — don't wipe an overlapping grammar flag
        let newRange = NSRange(location: pending.range.location, length: (guess as NSString).length)
        clearNativeAnnotations(global: newRange, onlyStyle: .spelling)
        clearNativeAnnotations(global: pending.range, onlyStyle: .correction)
        clearNativeAnnotations(global: newRange, onlyStyle: .correction)
        driveNativeCheck(style: .spelling) { nativeChecker?.checkSpellingForWord(inGlobal: newRange) }   // scope the synchronous clean-word callback too
    }

    /// The guesses menu children: an optional leading "Revert to …" (N5, `.correction` flags only), then one
    /// replace action per guess, or a disabled "No Replacements Found" when there are no guesses.
    func spellingGuessMenuElements() -> [UIMenuElement] {
        guard let pending = pendingSpellingMenu else { return [] }
        var elements: [UIMenuElement] = []
        if let revertTo = pending.revertTo {
            elements.append(UIAction(title: "Revert to \u{201C}\(revertTo)\u{201D}") { [weak self] _ in
                self?.applySpellingReplacement(revertTo)
            })
        }
        if pending.guesses.isEmpty {
            if elements.isEmpty {   // no revert action either → show the disabled placeholder
                let none = UIAction(title: "No Replacements Found") { _ in }
                none.attributes = .disabled
                elements.append(none)
            }
            return elements
        }
        elements.append(contentsOf: pending.guesses.prefix(4).map { guess in
            UIAction(title: guess) { [weak self] _ in self?.applySpellingReplacement(guess) }
        })
        return elements
    }

    /// Dash pattern per flag style: `.correction` (applied autocorrection) is a SOLID stroke like native iOS;
    /// `.spelling`/`.grammar` are dotted (the OS squiggle). Empty array = solid.
    func underlineDash(for style: SpellStyle) -> [CGFloat] {
        style == .correction ? [] : [1.5, 2.5]
    }
    /// Stroke width per style: the correction underline is ~2 pt (measured from iOS 26); the squiggle is 1 pt.
    func underlineWidth(for style: SpellStyle) -> CGFloat {
        style == .correction ? 2 : 1
    }

    /// Composited by `SelectionHighlightView.draw`. Own-drawn underlines, grouped by style so each style's
    /// color, dash, and width apply together (dotted red/green spelling/grammar; solid periwinkle correction).
    func drawSpellingUnderlines(in ctx: CGContext) {
        let lines = spellingUnderlineRects()
        guard !lines.isEmpty else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        for (style, group) in Dictionary(grouping: lines, by: { $0.style }) {
            ctx.setStrokeColor(spellingUnderlineColor(style).cgColor)
            ctx.setLineWidth(underlineWidth(for: style))
            ctx.setLineDash(phase: 0, lengths: underlineDash(for: style))
            for (r, _) in group {
                ctx.move(to: CGPoint(x: r.minX, y: r.midY))
                ctx.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            }
            ctx.strokePath()   // stroke per style group
        }
        ctx.restoreGState()
    }
}
#endif
