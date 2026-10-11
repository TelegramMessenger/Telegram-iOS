#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// What formatting a newly typed run inherits.
///
/// Continuation is a decision about an EDIT, not a property of an attribute, which is why this is a
/// policy and not a list of names. A link joins a word typed against it and stops at punctuation or a
/// space; a spoiler always continues, or typing inside one splits it in two; the inline-code marker
/// must continue or code loses its identity in the model while still LOOKING like code, because the
/// font continues on its own.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal func installTypedTextPolicy() {
        engine.typedTextAttributePolicy = { [weak self] current, preceding, following, insertedText in
            guard let self else { return current }
            return self.attributesForTypedText(current: current,
                                               preceding: preceding,
                                               following: following,
                                               insertedText: insertedText)
        }
        engine.tgid_replacementAttributesHandler = { [weak self] range, _ in
            self?.attributesForReplacement(of: range)
        }
    }

    /// What a keyboard REPLACEMENT — autocorrect, an accepted prediction, text replacement,
    /// dictation — is attributed with: the attributes of the start of the text it replaces, which is
    /// what a stock text view gives it. The controller attributes a replacement from its own typing
    /// attributes, which never carry a host marker, so a corrected word inside a spoiler or inline
    /// code came out revealed or plain (composer harness, 2026-09-23, `HarnessAutocorrectMarkerTests`
    /// — and through a programmatic replace, bold as well). Consistent with the typed-text policy:
    /// a marker that always continues into typed text is not lost to a correction of that text.
    ///
    /// nil — the controller's own attributes stand — for anything that is not a keystroke (the
    /// host's own edits reach the same surface), for a range crossing a block boundary (what a block
    /// separator's attributes would mean for the text is not a question a word correction asks), and
    /// for a replacement starting on an attachment, whose attributes would turn plain text into an
    /// atom.
    internal func attributesForReplacement(of range: NSRange) -> [NSAttributedString.Key: Any]? {
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit, range.length > 0 else { return nil }
        guard let index = roleIndex(atFlatOffset: range.location),
              roleIndex(atFlatOffset: NSMaxRange(range)) == index else { return nil }
        let blocks = engine.attributedBlocks
        guard index < blocks.count else { return nil }
        let local = range.location - flatOffset(ofRoleAt: index)
        let block = blocks[index]
        guard local >= 0, NSMaxRange(NSRange(location: local, length: range.length)) <= block.length else { return nil }
        let attributes = block.attributes(at: local, effectiveRange: nil)
        guard attributes[.attachment] == nil else { return nil }
        return attributes
    }

    /// Markers the engine's own typing attributes do not carry, so they must be copied forward
    /// explicitly or they stop at the first keystroke.
    ///
    /// `setAllowedTypingAttributeNames:` limits typing attributes to the font, the foreground and the
    /// four engine traits. Everything a host adds is outside that set — which is why typing inside a
    /// spoiler split it, and why an inline-code run silently lost `inlineCode` in the MODEL for typed
    /// text while continuing to look like code (its font is in the allowed set).
    private static let markersThatAlwaysContinue: [NSAttributedString.Key] = [
        .rtSpoiler,
        .rtInlineCode,
        NSAttributedString.Key.IDInlineTextBaseFontAttributeName,
    ]

    internal func attributesForTypedText(current: [NSAttributedString.Key: Any],
                                        preceding: [NSAttributedString.Key: Any],
                                        following: [NSAttributedString.Key: Any] = [:],
                                        insertedText: String) -> [NSAttributedString.Key: Any] {
        var result = current
        // Continuation is a decision WITHIN a block. At a block's start the preceding character
        // belongs to another block — the paragraph before a table, say — and nothing of it carries
        // over: not a spoiler, not inline code, and not the base font a trait toggle derives from,
        // which is what made the first character typed in a cell bold at the body size (measured).
        // Asked at the caret, which is where a caller measuring BEFORE the insert has it. The engine
        // calls this AFTER the insert (the caret is past the run), and for that reason it hands over
        // no `preceding` at all when the run starts a block — upstream
        // `id_applyTypedTextPolicyForInsertionAt:` — so a block's first character inherits nothing
        // through the separator either way.
        let location = engineSelectedRange.location
        let atBlockStart = roleIndex(atFlatOffset: location).map { flatOffset(ofRoleAt: $0) == location } ?? false
        if atBlockStart {
            result.removeValue(forKey: Self.linkAttributeKey)
            return result
        }
        for key in Self.markersThatAlwaysContinue where result[key] == nil {
            if let inherited = preceding[key] { result[key] = inherited }
        }
        // Inline code continues WHOLE: the marker, the monospaced base face and the pill's
        // background, whatever the controller's typing attributes already hold. Those carry a base
        // face of their own (the body face the controller derives), so "only where nil" kept it and
        // the typed character had the marker — the model said code — without the face or the
        // background: a gap in the pill (composer harness, 2026-09-23,
        // `HarnessMonospaceToggleOffBaseFontTests`). The background is a host key outside the
        // allowed typing attributes, so nothing else would carry it.
        if (preceding[.rtInlineCode] as? Bool) == true {
            result[.rtInlineCode] = true
            if let base = preceding[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] {
                result[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] = base
            }
            if let background = preceding[.backgroundColor] { result[.backgroundColor] = background }
        }

        // A link joins what is typed against it only when that is part of the same WORD. Punctuation
        // or a space ends it — otherwise a sentence typed after a URL is swallowed into it, which is
        // what was reported.
        //
        // That rule is about a link's END. With the SAME link on both sides of the caret there is
        // nothing after it to swallow, and stopping it there splits one link into two with an
        // unlinked gap (composer harness, 2026-09-23, `HarnessLinkInteriorTypingTests`): whatever is
        // typed inside a link continues it, as a stock text view and the legacy composer do.
        let joinsPrecedingLink = insertedText.first.map { first in
            !first.isWhitespace && !first.isPunctuation && !first.isSymbol
        } ?? false
        let isInsideLink = Self.sameLink(preceding[Self.linkAttributeKey], following[Self.linkAttributeKey])
        // Nothing draws a link underlined any more (`EngineDocumentBridge.withLinkUnderlines`), so an
        // underline on the character before the caret is the USER's, and it continues into typed text
        // like every other trait — inside a link as anywhere. Zeroing it here (a rule from when a
        // link's underline was render-derived) left a gap in the user's underline under every
        // character typed into an underlined link or mention (composer harness p15, fuzz seed 104,
        // `HarnessUnderlinedLinkTypingTests`).
        let precedingUnderline = ((preceding[.underlineStyle] as? Int) ?? 0) != 0
            || (preceding[.IDInlineTextUnderlineAttributeName] as? NSNumber)?.boolValue == true
        if preceding[Self.linkAttributeKey] != nil, joinsPrecedingLink || isInsideLink {
            result[Self.linkAttributeKey] = preceding[Self.linkAttributeKey]
            result[.foregroundColor] = preceding[.foregroundColor]
            if precedingUnderline {
                result[.underlineStyle] = preceding[.underlineStyle] ?? NSUnderlineStyle.single.rawValue
                result[.IDInlineTextUnderlineAttributeName] = true
            } else {
                result[.underlineStyle] = 0
            }
        } else {
            result.removeValue(forKey: Self.linkAttributeKey)
            // The accent goes with the link: keeping it would leave accent-coloured text that is not
            // a link, which reads as a rendering bug rather than as formatting.
            // The colour is the BLOCK's, not the theme's primary text: a media caption, an author
            // line, a quote's text each derive their own. The policy re-attributes the typed run after
            // settle has derived presentation, so a wrong colour here stays: an emoji typed after a
            // caption's mention or link kept a colour its role does not derive, which the verifier
            // traps on (composer harness p15, fuzz seed 104, `HarnessCaptionEntityEmojiDriftTests`).
            // Also when the run itself came in linked with nothing linked before it: typed at a block's
            // start before a link (a mention opening a quote child), the controller attributes the run
            // with the link's accent and the link (the engine hands no `preceding` there). The link went
            // above and its accent stayed on text the model holds plain — drawn, never sent (p20 fix wave
            // sweep, edited fuzz seeds 9 and 42, `HarnessTypedTextBeforeLinkColourTests`).
            if preceding[Self.linkAttributeKey] != nil || current[Self.linkAttributeKey] != nil {
                result[.foregroundColor] = roleIndex(atFlatOffset: location)
                    .flatMap { $0 < currentRoles.count ? cachedLineAttributes(for: currentRoles[$0])[.foregroundColor] : nil }
                    ?? composerHostState.theme.primaryText
                if !precedingUnderline {
                    result.removeValue(forKey: .underlineStyle)
                }
            }
        }
        return result
    }

    /// Whether two `.link` values name the same link. A link is stored as a `String` or a `URL`
    /// depending on who wrote it, so both are compared by their absolute string.
    private static func sameLink(_ lhs: Any?, _ rhs: Any?) -> Bool {
        func text(_ value: Any?) -> String? {
            guard let value else { return nil }
            if let url = value as? URL { return url.absoluteString }
            return value as? String
        }
        guard let l = text(lhs), let r = text(rhs) else { return false }
        return l == r
    }
}
#endif
