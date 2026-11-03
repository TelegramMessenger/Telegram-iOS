#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// Paragraph-shaped reads over a `Block`, for the engine editor's block cache.
///
/// The cache holds `[Block]` rather than `[ParagraphBlock]` because containers flatten onto the same
/// engine axis (see `EngineDocumentBridge`), and its consumers index it by ENGINE BLOCK INDEX. A
/// compacted paragraphs-only array would silently misalign those indices the moment a document
/// contains a container — the same positional-aliasing failure the identity table exists to prevent,
/// one layer up. So the array stays parallel to the engine's blocks and the paragraph-only consumers
/// narrow through these accessors instead.
///
/// A container answering `nil`/`0` here is the CORRECT answer, not a degraded one: it carries no
/// paragraph style and no list membership, so it legitimately breaks a list run and reports no style.
extension Block {
    /// The paragraph this block carries, or `nil` for a container. Settable so a paragraph-only
    /// mutator can write back through optional chaining without unwrapping the case by hand.
    internal var asParagraph: ParagraphBlock? {
        get {
            guard case let .paragraph(paragraph) = self else { return nil }
            return paragraph
        }
        set {
            guard let newValue else { return }
            self = .paragraph(newValue)
        }
    }

    /// The block's list membership; `nil` for a container, which therefore ends a list run.
    internal var listMembership: ListMembership? { asParagraph?.list }

    /// UTF-16 length of the block's own MODEL text. Not the engine's axis: a formula run renders
    /// as one U+FFFC while its model text is the LaTeX source. Flat geometry over the engine's
    /// blocks reads the engine's lengths (`flatLength(ofRoleAt:)`); this is for model documents.
    internal var flatUTF16Count: Int {
        switch self {
        case let .paragraph(paragraph): return paragraph.utf16Count
        case let .code(code): return code.utf16Count
        case let .pullQuote(quote): return quote.utf16Count
        case .media, .table, .blockQuote, .details, .buttonRow: return 0
        }
    }

    /// The block's text as one line, model form.
    internal var flatText: String {
        switch self {
        case let .paragraph(paragraph): return paragraph.runs.map(\.text).joined()
        case let .code(code): return code.runs.map(\.text).joined()
        case let .pullQuote(quote): return quote.runs.map(\.text).joined()
        case .media, .table, .blockQuote, .details, .buttonRow: return ""
        }
    }
}
#endif
