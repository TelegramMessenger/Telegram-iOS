#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-inline Task 4 — inline code.
///
/// Like links, presentation is written into the document and stripped on read-back — the mapper
/// explicitly suppresses a code run's font and background so "the mono font + code background don't
/// leak into the model".
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// `.rtInlineCode`, which the shared mapper already round-trips to `CharacterAttributes.inlineCode`.
    internal static let inlineCodeAttributeKey = NSAttributedString.Key.rtInlineCode

    /// True when the whole selection is inline code. A MIXED selection reads false and so toggles ON,
    /// matching what the engine's own tri-state traits do at the `.mixed` boundary.
    public func isInlineCodeActive() -> Bool {
        (engine.hostAttributeValue(forKey: Self.inlineCodeAttributeKey) as? Bool) == true
    }

    public func toggleInlineCode() {
        // Inline code over a mention, a date or a link is refused, as legacy refuses it — whole or in part
        // (`inlineCodeReachesSelection`, composer harness p23). Toggling code OFF is always allowed.
        guard inlineCodeReachesSelection else { return }
        // Across a table's structural selection the value is decided ONCE and applied to each covered
        // cell — `transformInlineAttributes` is a SET, so the result is uniform by construction.
        if acrossStructuralSelection(deciding: { self.isInlineCodeActive() },
                                     apply: { self.applyInlineCode(enabling: $0) }) { return }
        applyInlineCodeAsAToggle()
    }

    /// Whether Monospace would do anything over the selection: false where an inline format reaches no
    /// text (code, `inlineFormatsReachSelection`), and false where it would turn code ON over a range that
    /// holds a LINK anywhere — a mention, a date and a URL are links here, and the platform's nesting rule
    /// lets no `Code` entity overlap one (`EngineDocumentBridge.withoutInlineCodeOverLinks`). Turning it OFF
    /// is always allowed. The composer's Format menu shows Monospace disabled where this is false.
    public var inlineCodeReachesSelection: Bool {
        guard inlineFormatsReachSelection else { return false }
        if isInlineCodeActive() { return true }
        return !inlineTargetsHold(Self.linkAttributeKey)
    }

    /// Whether the text an inline command reaches (`inlineFormatTargetRanges`, a structural selection's
    /// cells included) holds `key` anywhere. At a collapsed caret: whether the caret is INSIDE such a run
    /// (both neighbours carry it), where a typed character would join it.
    internal func inlineTargetsHold(_ key: NSAttributedString.Key) -> Bool {
        let selection = engineSelectedRange
        let ranges = inlineFormatTargetRanges() ?? [composedCharacterRange(selection)]
        let blocks = engine.attributedBlocks
        func holds(_ value: Any?) -> Bool {
            guard let value else { return false }
            if let flag = value as? Bool { return flag }
            return true
        }
        var start = 0
        for block in blocks {
            let blockRange = NSRange(location: start, length: block.length)
            for range in ranges {
                if range.length == 0 {
                    let local = range.location - start
                    if local > 0, local < block.length,
                       holds(block.attribute(key, at: local - 1, effectiveRange: nil)),
                       holds(block.attribute(key, at: local, effectiveRange: nil)) { return true }
                    continue
                }
                let clip = NSIntersectionRange(range, blockRange)
                guard clip.length > 0 else { continue }
                var found = false
                block.enumerateAttribute(key, in: NSRange(location: clip.location - start, length: clip.length), options: []) { value, _, stop in
                    if holds(value) { found = true; stop.pointee = true }
                }
                if found { return true }
            }
            start += block.length + 1
        }
        return false
    }

    private func applyInlineCodeAsAToggle() {
        let enabling = !isInlineCodeActive()
        deliveringChangeNotification { recordingInlineFormatStep { self.applyInlineCode(enabling: enabling) } }
    }

    internal func applyInlineCode(enabling: Bool) {
        applyInlineCodeAttributes(enabling: enabling)
        // The attributes above are the command's; the presentation is the role's rendering of the
        // model it produced (`normalisePresentation(ofBlocksTouching:)`). Toggling code OFF cannot
        // know the face to go back to — a pull quote's is italic, a quote's is 15pt — and removing
        // the base-font key left the engine nothing to derive the next trait toggle from.
        normalisePresentation(ofBlocksTouching: engineSelectedRange)
    }

    private func applyInlineCodeAttributes(enabling: Bool) {
        let background = composerHostState.theme.inlineCodeBackground
        engine.transformInlineAttributes { attributes in
            var result = attributes
            let size = (attributes[.font] as? UIFont)?.pointSize
                ?? UIFont.preferredFont(forTextStyle: .body).pointSize
            if enabling {
                result[Self.inlineCodeAttributeKey] = true
                // THE LOAD-BEARING LINE. The base font is the face the engine's trait pass derives
                // bold and italic FROM (`baseFontForAttributes:` reads it first). Setting it to a
                // monospace face is what makes the run stay monospaced when the user then bolds it
                // — writing only `.font` would be undone by the very next trait toggle, which
                // recomputes the font from the base.
                let mono = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
                result[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] = mono
                result[.font] = Self.font(mono, carryingUserTraitsOf: attributes)
                result[.backgroundColor] = background
            } else {
                result.removeValue(forKey: Self.inlineCodeAttributeKey)
                result.removeValue(forKey: NSAttributedString.Key.IDInlineTextBaseFontAttributeName)
                let body = UIFont.systemFont(ofSize: size)
                result[.font] = Self.font(body, carryingUserTraitsOf: attributes)
                result.removeValue(forKey: .backgroundColor)
            }
            return result
        }
    }

    /// `face` carrying the USER's bold/italic — the engine's trait markers, which is what its own
    /// trait pass derives from — never the rendered face's: a pull quote's face is italic by role,
    /// and reading it from the face drew its code run monospaced ITALIC where the role derives
    /// upright (`HarnessPullQuoteInlineFormatDriftTests`). Falls back to the plain face when the
    /// family has no such variant — losing a slant is cosmetic, losing the monospacing is the feature.
    private static func font(_ face: UIFont, carryingUserTraitsOf attributes: [NSAttributedString.Key: Any]) -> UIFont {
        var wanted: UIFontDescriptor.SymbolicTraits = []
        if (attributes[NSAttributedString.Key.IDInlineTextBoldAttributeName] as? Bool) == true { wanted.insert(.traitBold) }
        if (attributes[NSAttributedString.Key.IDInlineTextItalicAttributeName] as? Bool) == true { wanted.insert(.traitItalic) }
        guard !wanted.isEmpty,
              let descriptor = face.fontDescriptor.withSymbolicTraits(
                  face.fontDescriptor.symbolicTraits.union(wanted)) else { return face }
        return UIFont(descriptor: descriptor, size: face.pointSize)
    }
}
#endif
