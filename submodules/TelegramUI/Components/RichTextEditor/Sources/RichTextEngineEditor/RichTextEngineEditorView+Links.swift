#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-inline Task 3 — links.
///
/// Presentation is written INTO the document alongside the URL, and stripped on read-back by
/// `AttributedStringMapper.characterAttributes(from:)`. That is this codebase's established pattern,
/// not a shortcut: the legacy canvas does exactly the same, and it is why both backends can produce
/// identical attributed strings for the same document — which matters because the composer's
/// dual-field switch moves content between them.
///
/// An earlier design put this in a host "style contributor" that decorated attributes on the way to
/// being drawn. Three placements of that hook all failed, because this engine renders each block from
/// `block.attributedText` and has no render-time attribute hook to hang presentation on. See
/// upstream e9c3b74f.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// UIKit's own `.link`, which the SHARED mapper already round-trips to `CharacterAttributes.link`
    /// and the legacy canvas already stores. A private key would make the two backends describe the
    /// same document differently.
    internal static let linkAttributeKey = NSAttributedString.Key.link

    /// The URL over the current selection, or nil when it carries none — or spans more than one
    /// distinct link, which has no single answer.
    public func currentLink() -> String? {
        engine.hostAttributeValue(forKey: Self.linkAttributeKey) as? String
    }

    public func setLink(_ url: String) {
        // A link over INLINE CODE is refused, whole or in part, as Monospace over a link is: the platform lets
        // no `Code` entity overlap a `TextUrl` (`linkReachesSelection`, composer harness p23).
        guard linkReachesSelection else { return }
        let accent = composerHostState.theme.accent
        forEachInlineFormatRange {
            engine.transformInlineAttributes { attributes in
                var result = attributes
                result[Self.linkAttributeKey] = url
                // Accent only. NO underline — the legacy mapper renders links as accent-coloured text
                // and says so explicitly, citing the reference design. It also matters for the model:
                // the mapper strips a linked run's FOREGROUND on read-back but does NOT strip
                // underline, so an underline written here would round-trip into the sent message.
                result[.foregroundColor] = accent
                // NO underline attribute. TextKit underlines `.link` itself and `.underlineStyle = 0`
                // does not suppress it — the fix is to keep `.link` out of the RENDERED text entirely
                // (see `withoutRenderedLinkAttribute`), which is why nothing is written here.
                return result
            }
            normalisePresentation(ofBlocksTouching: engineSelectedRange)
        }
    }

    /// Whether Link would do anything over the selection: false where an inline format reaches no text
    /// (code, `inlineFormatsReachSelection`) or where the range holds INLINE CODE anywhere
    /// (`EngineDocumentBridge.withoutInlineCodeOverLinks`). Removing a link is always allowed.
    public var linkReachesSelection: Bool {
        guard inlineFormatsReachSelection else { return false }
        return !inlineTargetsHold(Self.inlineCodeAttributeKey)
    }

    /// Runs a link command over the ranges an inline format reaches — the selection widened to whole
    /// composed characters, with code (body and language line) taken out
    /// (`inlineFormatTargetRanges`, composer harness p20) — as ONE step and one change notification.
    /// A table's structural selection is not walked (a link has never applied across cells). The
    /// selection is parked on each range and put back.
    private func forEachInlineFormatRange(_ body: () -> Void) {
        guard let ranges = inlineFormatTargetRanges(includingTableCells: false) else {
            deliveringChangeNotification { recordingInlineFormatStep { body() } }
            return
        }
        guard !ranges.isEmpty else { return }
        let restore = engineSelectedRange
        let structural = tableStructuralSelection
        isParkingCaretForStructuralSelection = true
        defer {
            engineSelectedRange = restore
            isParkingCaretForStructuralSelection = false
            tableStructuralSelection = structural
        }
        deliveringOneChangeNotification { recordingInlineFormatStep(selection: restore) {
            for range in ranges {
                engineSelectedRange = range
                body()
            }
        } }
    }

    public func removeLink() {
        let primary = composerHostState.theme.primaryText
        forEachInlineFormatRange {
            engine.transformInlineAttributes { attributes in
                var result = attributes
                result.removeValue(forKey: Self.linkAttributeKey)
                // Restore the body colour rather than removing the key: with no foreground the run
                // would fall back to whatever the layout defaults to, which is not necessarily the
                // theme's text colour.
                result[.foregroundColor] = primary
                return result
            }
            // The command decides the model; the colour is the ROLE's. The body colour written above
            // is wrong for a line whose style is not body — a pull quote's author is drawn in the
            // caption colour, and a link removed across it left it primary-coloured, which the
            // verifier reported as NSColor drift (composer harness, 2026-09-23, fuzz seed 18,
            // `HarnessLinkRemovalColourTests`). Linking re-derives the same way, which also keeps a
            // link off a code block's language line, whose model is a plain string.
            normalisePresentation(ofBlocksTouching: engineSelectedRange)
        }
    }
}
#endif
