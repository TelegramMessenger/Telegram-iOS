#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// Public façade for serializing a `Document` into the editor's pasteboard representations, so a host
/// (e.g. a chat "Copy" action on a rich message) can put rich content on the clipboard in the SAME three
/// formats the editor itself writes — without reaching through the internal copy responder. The editor's
/// own `writeSelectionToPasteboard` is a thin caller of `pasteboardItem(for:)`, so the format can't drift.
public enum RichTextEditorClipboard {
    /// Private pasteboard UTI carrying a JSON-encoded `Document` (full within-app fidelity, incl. between
    /// composers). The richest of the three representations the editor reads on paste, ahead of RTF and plain.
    public static let fragmentUTI = "org.telegram.richtexteditor.fragment"

    /// Private pasteboard UTI carrying, as UTF-8, the EXACT text a one-line field (an author, a code
    /// language, a details title) takes from the editor's own copy: every character of the range the copy
    /// took — and a Cut deletes — on one line, atoms as their text. The fragment cannot say this: a partial
    /// copy of a code body carries the block's language as metadata, which the range never held (composer
    /// harness p22). Written by the editor's own Copy / Cut only; absent, a field falls back to the fragment.
    public static let oneLineFieldTextUTI = "org.telegram.richtexteditor.one-line-field-text"

    /// Private pasteboard UTI carrying a JSON-encoded `Document`: the editor's own copy as the TEXT the range
    /// covered (`Document.extractFragmentAsCoveredText`) — a code block's language as a line only when the
    /// range held its language line. What a destination that holds only RUNS (a table cell, a media caption,
    /// a pull quote's body) pastes: from the fragment it cannot tell a covered language from the metadata one
    /// a partial copy carries, and it dropped both, so Cut + Paste of a code block into a cell deleted the
    /// language (composer harness p23). Written by the editor's own Copy / Cut only.
    public static let coveredTextFragmentUTI = "org.telegram.richtexteditor.covered-text-fragment"

    /// The pasteboard item for a whole `Document`: the private fragment UTI (JSON, lossless), `public.rtf`
    /// (cross-app), and `public.utf8-plain-text`. Assign as a single pasteboard item, e.g.
    /// `UIPasteboard.general.items = [RichTextEditorClipboard.pasteboardItem(for: document)]`.
    /// `plain` defaults to `externalChecklistPlainText(document.blocks)` — top-level blocks joined by "\n",
    /// with an emoji checkbox prefix (⬜/✅) on checklist paragraphs for external share.
    public static func pasteboardItem(for document: Document, plain: String? = nil) -> [String: Any] {
        var item: [String: Any] = [:]
        if let data = try? DocumentCodec.encode(document) { item[fragmentUTI] = data }
        if let rtf = RTFConversion.rtfData(from: document) { item["public.rtf"] = rtf }
        item["public.utf8-plain-text"] = plain ?? externalChecklistPlainText(document.blocks)
        return item
    }
}
#endif
