#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-inline Task 5 — custom emoji hosting; R9-emoji-insertion — `insertEmoji`.
///
/// Both halves live here, the way `+Formulas.swift` holds a formula's authoring and its hosting:
/// what the mapper bakes into the attachment is the one fact they must agree on.
///
/// Hosted the way the legacy canvas hosts them: the attachment reserves the box, and this walks the
/// laid-out text, asks the host for a view per `EmojiRef`, and positions it over the glyph rect.
/// Pooled by `instanceID`, culled when the emoji goes.
///
/// NOT through `NSTextAttachmentViewProvider`. This is a custom text view that already does its own
/// drawing — spoiler dust is placed the same way, from the same geometry accessor. An earlier design
/// went via TextKit's view providers on the strength of the engine having an "attachment lifecycle";
/// that lifecycle forwards to a canvas host implementing nothing, and the provider path could not be
/// made to fire at all, including in a stock `UITextView`. Both were dead ends from assuming a
/// mechanism rather than reading what legacy does.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - Authoring

    /// Writes ONE custom emoji at the caret — the emoji panel's verb for a CUSTOM emoji (a standard
    /// one arrives as characters through `insertText`).
    ///
    /// R9-inline gave the engine the ability to HOST an emoji it was handed; this is the other half,
    /// writing one into the document, and until this rung it trapped. Shaped like
    /// `insertInlineFormula`, which it matches exactly: one attachment character, inline, no block of
    /// its own and no trailing paragraph — an emoji is a character in a paragraph that already exists.
    ///
    /// **Derived through the mapper, not stamped as an `EmojiTextAttachment` here.** The mapper bakes
    /// in `emojiScale` AND `emojiRenderBoost(for:)`; the legacy canvas has to apply the boost by hand
    /// and records what happens when it does not — "a freshly-inserted body emoji would render at its
    /// bare glyph box until the next full document reload". Deriving the run the way a LOAD derives it
    /// puts that divergence out of reach instead of duplicating the repair.
    ///
    /// An ATOM block — a media block or a button row — refuses: it owns one attachment character and
    /// no text region, so there is no inline place for an emoji. That is `insertInlineFormula`'s
    /// refusal, for its reason.
    public func insertEmoji(id: String, altText: String?) {
        insertEmoji(id: id, altText: altText, spoiler: false)
    }

    /// `spoiler`: the emoji is written inside a spoiler — the one inline mark that is model state on
    /// an inline atom (bold, italic, underline and strikethrough are not, see
    /// `rederiveAtomPresentation`). A host inserting at a caret inside a spoiler passes it, or the
    /// emoji splits the spoiler and shows in the gap (`insertInlineRunsOnUsersBehalf`).
    internal func insertEmoji(id: String, altText: String?, spoiler: Bool) {
        guard !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        if selection.length > 0 { replaceFlat(selection, with: "") }
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location) else { return }
        guard atomUnitIndex(forRoleAt: index) != index else { return }
        let role = currentRoles[index]
        if case .code = role.shape { insertEmojiAltTextIntoCode(altText); return }
        // A code block's LANGUAGE line is a `.secondary` paragraph, not a `.code` shape, so the test
        // above never saw it and the attachment landed as a bare `U+FFFC` in the language string
        // (composer harness p21, `HarnessCustomEmojiIntoCodeLanguageTests`). The language is a plain
        // string: it takes the alt text, as the code body does.
        if role.secondaryKind == .codeLanguage { insertEmojiAltTextIntoCode(altText); return }
        var attributes = CharacterAttributes()
        attributes.spoiler = spoiler
        // A fresh `instanceID` per occurrence — it is the view-pooling key, so the same sticker
        // inserted twice is two views. Sharing one would make a second copy vend no view at all.
        attributes.emoji = EmojiRef(id: id, instanceID: BlockID.generate().rawValue, altText: altText)
        let rendering = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: "\u{FFFC}", attributes: attributes)]))
        let inserted = EngineDocumentBridge.engineText(rendering.string)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                replaceFlat(NSRange(location: caret, length: 0), with: inserted)
                // The attachment cannot travel through a text edit, so the rendering's attributes are
                // restored over the inserted character — the two-step `insertInlineFormula` uses, and
                // `insertMedia` before it for a caption.
                restoreStyleFlat(NSRange(location: caret, length: rendering.length), from: rendering)
                engineSelectedRange = NSRange(location: caret + rendering.length, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// A CODE block takes the emoji's `altText` as PLAIN TEXT, which is `insertInlineFormula`'s rule
    /// for the same block and for the same reason: code is plain by definition, and a rendered atom
    /// there would misrepresent what is sent (a code block leaves as preformatted text, where a custom
    /// emoji has no representation at all). `EmojiRef.altText` is defined in Core as exactly this —
    /// "the optional plain-text / Markdown form" — and the panel always supplies one. With none there
    /// is nothing to write, so the insert is refused.
    ///
    /// This diverges from the legacy canvas, which writes the real atom into a code block. Deliberate:
    /// that atom is dropped on send, and rendering it would need the bridge's own code path (a second
    /// mapper, the monospace base-font stamp and the horizontal padding), which cannot be reproduced
    /// from one paragraph rendering out here.
    ///
    /// A code block's LANGUAGE line lands here for the same reason — it is a one-line plain label, so
    /// plain text is all it can hold — but it is NOT a `.code` shape (its role is a `.secondary`
    /// paragraph), so the caller asks `secondaryKind == .codeLanguage` for it separately.
    private func insertEmojiAltTextIntoCode(_ altText: String?) {
        guard let altText, !altText.isEmpty else { return }
        let text = EngineDocumentBridge.engineText(altText)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                replaceFlat(NSRange(location: caret, length: 0), with: text)
                engineSelectedRange = NSRange(location: caret + (text as NSString).length, length: 0)
            }
        }
        setNeedsLayout()
    }

    // MARK: - Hosting

    /// Reconciles hosted emoji views against the laid-out document. Idempotent; runs after layout.
    internal func syncCustomEmojiViews() {
        let occurrences = emojiOccurrences()
        guard !occurrences.isEmpty || !customEmojiViews.isEmpty else { return }
        guard let provider = deferredConfiguration.emojiViewProvider else { return }

        var live: Set<String> = []
        for occurrence in occurrences {
            // The ATTACHMENT's own frame, not a selection rect. A selection rect is the LINE's
            // height, so placing the view from one stretched the emoji vertically — 20.29 wide by
            // 22.0 tall for a 17pt run, which is what "displayed non-rectangular" was.
            //
            // Read through `attachmentOverlayPlacement` ONCE, before the view is vended: it carries
            // the `renderBoost` an emoji is drawn larger by, so the provider must be asked for the
            // VISIBLE size rather than the layout's reservation — vended at the reservation and then
            // framed at the visible box, the sticker is rendered at one size and stretched to
            // another.
            guard let placement = attachmentOverlayPlacement(
                canonicalOffset: occurrence.range.location,
                roleIndex: roleIndex(atFlatOffset: occurrence.range.location)) else { continue }
            live.insert(occurrence.ref.instanceID)

            let view: UIView & RichTextEmojiView
            if let existing = customEmojiViews[occurrence.ref.instanceID] {
                view = existing
            } else {
                // Pooled by instanceID, not by emoji id: the same sticker twice in one message is two
                // views, and re-vending on every keystroke would restart every animation in the field.
                guard let fresh = provider(occurrence.ref.id, placement.frame.size) else { continue }
                fresh.isUserInteractionEnabled = false
                // Into the ENGINE, which is a scroll view, because `id_attachmentFrame` answers in
                // its CONTENT space. Parented to the editor instead, the view is correct only while
                // `contentOffset` is zero and then stays pinned to the screen as its text scrolls
                // away. ABOVE the block stack — unlike a container decoration, which goes below it —
                // since the emoji stands in for a glyph rather than sitting behind one.
                engine.addSubview(fresh)
                customEmojiViews[occurrence.ref.instanceID] = fresh
                view = fresh
            }
            // A cell's emoji rides the run's scrolling content, like the chrome: parented there,
            // in that view's coordinates, so it scrolls and clips with the cell. `placement` came
            // from `attachmentOverlayPlacement`, which the pills and the formula targets read too —
            // and which the placement check re-reads to say whether this pass ran.
            if view.superview !== placement.host { view.removeFromSuperview(); placement.host.addSubview(view) }
            view.frame = placement.frame
            // A spoiler hides TEXT with a foreground colour, which does nothing to a hosted view — the
            // emoji would sit fully visible behind the dust, leaking exactly what the spoiler exists to
            // conceal. Legacy has this bug today. Uses the same reveal rule as the text hide and the
            // dust, so all three can never disagree about which run is open.
            let hiddenBySpoiler = isInsideHiddenSpoiler(occurrence.range)
            view.isHidden = hiddenBySpoiler
            // Re-pushed every pass: cheap (the host setter no-ops on an unchanged value) and
            // self-healing across theme changes. Non-template emoji ignore it.
            view.dynamicColor = composerHostState.theme.primaryText
        }

        for (instanceID, view) in customEmojiViews where !live.contains(instanceID) {
            view.removeFromSuperview()
            customEmojiViews[instanceID] = nil
        }
    }

    /// Whether a range sits in a spoiler run that is currently hidden.
    /// INTERNAL, not private: `syncInlineButtonPills` asks the same question, and a second copy
    /// would be a second thing to keep in step with the text hide and the dust.
    internal func isInsideHiddenSpoiler(_ range: NSRange) -> Bool {
        var blockStart = 0
        for block in engine.attributedBlocks {
            let whole = NSRange(location: 0, length: block.length)
            var hidden = false
            block.enumerateAttribute(Self.spoilerAttributeKey, in: whole, options: []) { value, runRange, stop in
                guard (value as? Bool) == true else { return }
                let canonical = NSRange(location: blockStart + runRange.location, length: runRange.length)
                if NSIntersectionRange(canonical, range).length > 0,
                   !selectionRevealsCanonicalRange(canonical) {
                    hidden = true
                    stop.pointee = true
                }
            }
            if hidden { return true }
            blockStart += block.length + 1
        }
        return false
    }

    internal struct EmojiOccurrence { let ref: EmojiRef; let range: NSRange }

    /// Every emoji atom in the document, with its canonical range.
    internal func emojiOccurrences() -> [EmojiOccurrence] {
        var result: [EmojiOccurrence] = []
        var blockStart = 0
        for block in engine.attributedBlocks {
            let whole = NSRange(location: 0, length: block.length)
            block.enumerateAttribute(.attachment, in: whole, options: []) { value, range, _ in
                guard let attachment = value as? EmojiTextAttachment else { return }
                result.append(EmojiOccurrence(
                    ref: attachment.ref,
                    range: NSRange(location: blockStart + range.location, length: range.length)))
            }
            blockStart += block.length + 1
        }
        return result
    }
}
#endif
