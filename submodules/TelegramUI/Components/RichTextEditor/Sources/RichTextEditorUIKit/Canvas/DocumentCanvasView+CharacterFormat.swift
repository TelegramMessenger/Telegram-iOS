#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Character-format toggles. Each works over EVERY leaf text region the selection touches — body
/// paragraphs, image captions, and table cells (via `allLeafRegions`) — so formatting is continuous
/// across cells like selection itself. Attribute-only (no span change), wrapped in `editing { }` so
/// undo is the existing whole-document `[Block]` snapshot. A collapsed caret is a no-op (collapsed
/// "typing attributes" are deferred).
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The (storage, range) pairs a character-format command applies to. When a table row/column is
    /// structurally selected, that's every cell's full text in the row/column (so toolbar formatting
    /// works on the whole row/column). Otherwise it's the text selection's intersection with each leaf
    /// region — body paragraphs, captions, and table cells alike. Empty when nothing applies (e.g. a
    /// bare collapsed caret).
    func characterFormatTargets() -> [(storage: NSTextStorage, range: NSRange, layout: BlockLayoutEngine)] {
        if let regions = tableStructuralSelectionRegions() {
            return regions.compactMap { r in
                guard r.length > 0, let storage = r.layout.backingStorage else { return nil }
                return (storage, NSRange(location: 0, length: r.length), r.layout)
            }
        }
        guard selFrom < selTo else { return [] }
        return allLeafRegions().compactMap { r in
            let a = max(selFrom, r.globalStart), b = min(selTo, r.globalStart + r.length)
            guard a < b, let storage = r.layout.backingStorage else { return nil }
            return (storage, NSRange(location: a - r.globalStart, length: b - a), r.layout)
        }
    }

    /// The toggle engine. `isSet` reports whether a storage range already fully carries the format;
    /// the direction is decided once globally (all covered ranges set → remove, else add) and passed
    /// to `setOn` as `allOn`.
    func applyCharacterToggle(isSet: (NSTextStorage, NSRange) -> Bool,
                              setOn: (NSTextStorage, NSRange, _ allOn: Bool) -> Void) {
        let covered = characterFormatTargets()
        guard !covered.isEmpty else { return }
        let allOn = covered.allSatisfy { isSet($0.storage, $0.range) }
        // TASK 39b: a host-originated ATTRIBUTE-ONLY mutation. `.formatting` / `.preserveIfRebasable`
        // — the text length does not change, so a marked range survives in principle.
        //
        // **TASK 41 CLOSED THE GAP THIS COMMENT USED TO DISCLOSE, AND THEN MEASURED THAT THIS SITE
        // CANNOT REACH IT ANYWAY.** The disclosure read: "against the real document client
        // `.preserveIfRebasable` degrades to `.discard` here, because `.formatting` still bumps the
        // revision and D32's rebase is identity-or-nil. The policy states the INTENT; closing that gap
        // is that method's business, not this call site's." Both halves are now false:
        //   * the gap is closed — `reconcileMarkedTextForExternalChange` keys its fast path on
        //     `change.reason.preservesTextOffsets`, and `.formatting` answers "offsets unmoved", so the
        //     rebase is never attempted and nothing degrades; "in principle" is now the mechanism.
        //   * and it was unreachable from here regardless: `performEditing` (`+Editing.swift`) opens
        //     with `finalizeMarkedText()`, so the `editing { }` below COMMITS any live composition
        //     BEFORE the mutation runs, and the policy is reached with no marked range at all.
        //     MEASURED at BASE and pinned by `MarkedStateAuthorityTests
        //     .test_aBoldToggleDuringACompositionCommitsIt_asItAlreadyDidAtBase`.
        // The policy declaration stays: it is the honest description of the change, and it is what a
        // future caller that does NOT go through `editing { }` would rely on.
        synchronizingExternalChange(reason: .formatting, markedTextPolicy: .preserveIfRebasable) {
            editing {
                for c in covered {
                    setOn(c.storage, c.range, allOn)
                    // Direct NSTextStorage mutation bypasses BlockLayout's renderVersion bump sites, so a
                    // view-backed paragraph wouldn't repaint (its renderSignature wouldn't change). Bump here.
                    c.layout.bumpRenderVersion()
                }
                return .unchanged
            }
        }
    }

    // MARK: - Format predicates (shared by toggle and state reader)

    func rangeIsBold(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        // Bold is the user-intent `.rtBold` marker, NOT the rendered `.traitBold` — the latter is forced onto
        // substituted scripts by the system "Bold Text" setting and would misreport ambient bold as user bold.
        var all = true
        storage.enumerateAttribute(.rtBold, in: range, options: []) { v, _, stop in
            if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsItalic(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.font, in: range, options: []) { v, _, stop in
            let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
            if !f.fontDescriptor.symbolicTraits.contains(.traitItalic) { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsUnderline(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { v, _, stop in
            if ((v as? Int) ?? 0) == 0 { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsStrikethrough(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { v, _, stop in
            if ((v as? Int) ?? 0) == 0 { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsInlineCode(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.rtInlineCode, in: range, options: []) { v, _, stop in
            if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsSpoiler(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.rtSpoiler, in: range, options: []) { v, _, stop in
            if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
        }
        return all
    }

    /// True when every character-format target lies in a `.quoteAuthor` region — a quote's author line,
    /// whose bold is always-on/ambient (forced at render, stripped on read-back). A bold toggle there would
    /// only un-bold the always-bold author (or dirty the model with an inert edit), so the toggle locks out.
    func selectionIsEntirelyInAuthorRegion() -> Bool {
        let targets = characterFormatTargets()
        guard !targets.isEmpty else {
            // Collapsed caret (no format targets): check the region under `head`.
            if let (region, _) = leafRegion(containingGlobal: head), case .quoteAuthor = region.ref { return true }
            return false
        }
        // `characterFormatTargets()` returns `(storage, range, layout)` triples drawn from `allLeafRegions()`;
        // map each back to its region by the (unique per region) layout object and require it be `.quoteAuthor`.
        let regions = allLeafRegions()
        return targets.allSatisfy { target in
            guard let region = regions.first(where: { $0.layout === target.layout }) else { return false }
            if case .quoteAuthor = region.ref { return true }
            return false
        }
    }

    /// True when every character-format target lies in a PULL quote's `.quoteAuthor` region specifically —
    /// unlike `selectionIsEntirelyInAuthorRegion` (bold, shared by both quote kinds), a pull-quote author is
    /// ALSO always-italic (ambient, forced at render / stripped on read-back), so an italic toggle there
    /// must lock out too. A block-quote author's italic stays toggleable (its ambient styling is bold-only).
    func selectionIsEntirelyInPullQuoteAuthorRegion() -> Bool {
        // Resolves the CanvasBlock owning a `.quoteAuthor(id)` region, recursing into nested block quotes —
        // mirrors the box-resolution search in `authorTypingAttributes(forRegion:)`.
        func owningBoxIsPullQuote(_ id: BlockID) -> Bool {
            func search(_ list: [CanvasBlock]) -> CanvasBlock? {
                for b in list {
                    if let pq = b as? PullQuoteBox, pq.id == id { return pq }
                    if let bq = b as? BlockQuoteBox {
                        if bq.id == id { return bq }
                        if let hit = search(bq.children.boxes) { return hit }
                    }
                }
                return nil
            }
            guard let owner = search(boxes) else { return false }
            return owner is PullQuoteBox
        }
        let targets = characterFormatTargets()
        guard !targets.isEmpty else {
            // Collapsed caret (no format targets): check the region under `head`.
            if let (region, _) = leafRegion(containingGlobal: head), case let .quoteAuthor(id) = region.ref {
                return owningBoxIsPullQuote(id)
            }
            return false
        }
        let regions = allLeafRegions()
        return targets.allSatisfy { target in
            guard let region = regions.first(where: { $0.layout === target.layout }),
                  case let .quoteAuthor(id) = region.ref else { return false }
            return owningBoxIsPullQuote(id)
        }
    }

    /// True when every character-format target lies in a `.codeLanguage` region. A code block's language is
    /// a PLAIN string on the wire (`.Pre` carries no nested entities), so every inline format there is
    /// either dropped on read-back — an inert edit that still dirties the model — or survives in the layout
    /// and corrupts what `currentCode()` reads back. Mirrors `selectionIsEntirelyInAuthorRegion`.
    func selectionIsEntirelyInCodeLanguageRegion() -> Bool {
        let targets = characterFormatTargets()
        guard !targets.isEmpty else {
            // Collapsed caret (no format targets): check the region under `head`.
            if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref { return true }
            return false
        }
        let regions = allLeafRegions()
        return targets.allSatisfy { target in
            guard let region = regions.first(where: { $0.layout === target.layout }) else { return false }
            if case .codeLanguage = region.ref { return true }
            return false
        }
    }

    func toggleBold() {
        // The author line is always-bold (ambient); a bold toggle there is inert — never un-bold it.
        if selectionIsEntirelyInAuthorRegion() { return }
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsBold(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                var t = f.fontDescriptor.symbolicTraits
                if allOn { t.remove(.traitBold) } else { t.insert(.traitBold) }
                if let d = f.fontDescriptor.withSymbolicTraits(t) {
                    storage.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                }
            }
            // Carry the user-intent marker alongside the render trait so model bold round-trips (read by
            // `characterAttributes`/`rangeIsBold`); absence == not bold.
            if allOn { storage.removeAttribute(.rtBold, range: range) }
            else { storage.addAttribute(.rtBold, value: true, range: range) }
        })
    }

    func toggleItalic() {
        // A pull-quote author line is always-italic (ambient), in addition to always-bold; an italic toggle
        // there is inert — never un-italicize it. (Block-quote authors are bold-only, so they stay toggleable.)
        if selectionIsEntirelyInPullQuoteAuthorRegion() { return }
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsItalic(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                var t = f.fontDescriptor.symbolicTraits
                if allOn { t.remove(.traitItalic) } else { t.insert(.traitItalic) }
                if let d = f.fontDescriptor.withSymbolicTraits(t) {
                    storage.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                }
            }
        })
    }

    func toggleStrikethrough() {
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsStrikethrough(s, r) }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.strikethroughStyle, range: range) }
            else { storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        })
    }

    func toggleUnderline() {
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsUnderline(s, r) }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.underlineStyle, range: range) }
            else { storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        })
    }

    /// Toggles the spoiler marker (`.rtSpoiler`) over the selection (cell/row/column-aware via
    /// `characterFormatTargets`). Additive — it touches no font/colour, so it composes with every other
    /// format. The display-only hide + dust overlay are driven separately by `syncSpoilers`.
    func toggleSpoiler() {
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsSpoiler(s, r) }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.rtSpoiler, range: range) }
            else { storage.addAttribute(.rtSpoiler, value: true, range: range) }
        })
    }

    /// The chat's ⇧⌘N: every inline mark the USER set — inline code, bold, italic, underline,
    /// strikethrough, spoiler — leaves the selection, and no block changes. One edit, so one undo
    /// step. A collapsed caret changes nothing, as the legacy composer's shortcut does not.
    ///
    /// It removes marks directly rather than pressing the toggles: a toggle's remove step is not the
    /// inverse of its set step. Inline code's writes a plain system font over its whole range, so a
    /// heading came back in the body face, and Italic reads the font trait, which a pull quote's
    /// body carries by its STYLE, so it drew the body roman (`ClearInlineFormattingTests`). Here bold
    /// is removed only where the user marker `.rtBold` says the user set it, italic is left alone
    /// where the style supplies it (a pull quote's body and any quote author), inline code gives its
    /// run back the paragraph style's own face, and a link keeps the underline it is drawn with.
    func clearInlineFormatting() {
        let targets = clearFormattingTargets()
        guard !targets.isEmpty else { return }
        synchronizingExternalChange(reason: .formatting, markedTextPolicy: .preserveIfRebasable) {
            editing {
                for (region, range) in targets {
                    guard let storage = region.layout.backingStorage else { continue }
                    let italicIsAmbient: Bool
                    switch region.ref {
                    case .code, .codeLanguage:
                        continue   // plain text by construction
                    case .pullQuote, .quoteAuthor:
                        italicIsAmbient = true
                    case .paragraph, .caption, .detailsTitle:
                        italicIsAmbient = false
                    }
                    let plainFace = plainFont(forRegion: region)
                    storage.beginEditing()
                    storage.enumerateAttribute(.rtInlineCode, in: range, options: []) { value, sub, _ in
                        guard value != nil else { return }
                        storage.removeAttribute(.rtInlineCode, range: sub)
                        storage.removeAttribute(.backgroundColor, range: sub)
                        storage.enumerateAttribute(.font, in: sub, options: []) { font, piece, _ in
                            let size = ((font as? UIFont) ?? plainFace).pointSize
                            storage.addAttribute(.font, value: plainFace.withSize(size), range: piece)
                        }
                    }
                    storage.enumerateAttribute(.rtBold, in: range, options: []) { value, sub, _ in
                        guard value != nil else { return }
                        storage.removeAttribute(.rtBold, range: sub)
                        Self.removeTrait(.traitBold, from: storage, in: sub)
                    }
                    if !italicIsAmbient {
                        Self.removeTrait(.traitItalic, from: storage, in: range)
                    }
                    storage.removeAttribute(.strikethroughStyle, range: range)
                    storage.removeAttribute(.rtSpoiler, range: range)
                    storage.enumerateAttribute(.link, in: range, options: []) { link, sub, _ in
                        if link == nil { storage.removeAttribute(.underlineStyle, range: sub) }
                    }
                    storage.endEditing()
                    region.layout.bumpRenderVersion()
                }
                return .unchanged
            }
        }
    }

    /// `characterFormatTargets`, keeping each target's region (clearing needs to know what kind of
    /// text it is in).
    private func clearFormattingTargets() -> [(region: LeafTextRegion, range: NSRange)] {
        if let regions = tableStructuralSelectionRegions() {
            return regions.compactMap { r in
                r.length > 0 ? (r, NSRange(location: 0, length: r.length)) : nil
            }
        }
        guard selFrom < selTo else { return [] }
        return allLeafRegions().compactMap { r in
            let a = max(selFrom, r.globalStart), b = min(selTo, r.globalStart + r.length)
            guard a < b else { return nil }
            return (r, NSRange(location: a - r.globalStart, length: b - a))
        }
    }

    /// The face a run of `region` has with no inline marks: its paragraph style's plain font, from the
    /// box's OWN mapper (a table cell renders body text smaller).
    private func plainFont(forRegion region: LeafTextRegion) -> UIFont {
        switch region.ref {
        case .paragraph:
            if let box = activeStack(at: region.globalStart)?.box as? BlockBox {
                return box.mapper.styleSheet.font(for: box.style, attributes: .plain)
            }
        case .caption:
            return mapper.styleSheet.font(for: .caption, attributes: .plain)
        case .pullQuote:
            return mapper.styleSheet.font(for: .pullQuote, attributes: .plain)
        case .code, .codeLanguage, .quoteAuthor, .detailsTitle:
            break
        }
        return mapper.styleSheet.font(for: .body, attributes: .plain)
    }

    private static func removeTrait(_ trait: UIFontDescriptor.SymbolicTraits, from storage: NSTextStorage, in range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, sub, _ in
            guard let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(trait) else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.remove(trait)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                storage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: sub)
            }
        }
    }

    /// Inline code swaps the run's font for a monospaced one (and marks it). GFM code spans can't
    /// carry emphasis, so toggling off restores a plain system font at the same size (any bold/italic
    /// inside is intentionally dropped); the named-style font returns on the next model round-trip.
    func toggleInlineCode() {
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
        applyCharacterToggle(isSet: { s, r in self.rangeIsInlineCode(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let size = ((v as? UIFont) ?? UIFont.systemFont(ofSize: 16)).pointSize
                if allOn {
                    storage.removeAttribute(.rtInlineCode, range: sub)
                    storage.removeAttribute(.backgroundColor, range: sub)
                    storage.addAttribute(.font, value: UIFont.systemFont(ofSize: size), range: sub)
                } else {
                    storage.addAttribute(.rtInlineCode, value: true, range: sub)
                    storage.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: sub)
                    storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: size, weight: .regular), range: sub)
                }
            }
        })
    }
}
#endif
