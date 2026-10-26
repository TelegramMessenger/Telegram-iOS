#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// `Document` fragment ↔ RTF for cross-app copy/paste. Export carries only SEMANTIC inline formatting
/// (no theme colors); import reads back the supported inline flag set (bold/italic/underline/strike/link).
enum RTFConversion {
    // The custom-emoji marker URL. A custom emoji has no cross-app glyph, so RTF carries it as its altText
    // hyperlinked to this marker (the file id survives; import reconstructs the emoji) — symmetric with how
    // mentions/dates already round-trip as links. Replicated locally because the RichTextEditor package is
    // standalone (no TextFormat dependency); keep the format in sync with the canonical
    // submodules/TextFormat/Sources/CustomEmojiMarkdownMarker.swift — `tg://emoji?id=<fileId>`.
    private static let emojiMarkerPrefix = "tg://emoji?id="
    /// `tg://emoji?id=<id>&n=<seq>`. The `&n=` suffix is a per-export sequence number that makes EVERY
    /// emoji's URL unique, so NSAttributedString/RTF can't coalesce two adjacent identical emoji
    /// (same id + altText) into one run and lose the second on import. The canonical id is everything
    /// between `id=` and the first `&`.
    private static func emojiMarkerURL(id: String, dedup: Int) -> String { "\(emojiMarkerPrefix)\(id)&n=\(dedup)" }
    private static func emojiID(fromMarkerURL url: String) -> String? {
        guard url.hasPrefix(emojiMarkerPrefix) else { return nil }
        var id = String(url.dropFirst(emojiMarkerPrefix.count))
        if let amp = id.firstIndex(of: "&") { id = String(id[..<amp]) }   // drop the &n= de-dup suffix
        return id.isEmpty ? nil : id
    }

    /// RTF-escapes a string: backslash/brace specials, tab, printable ASCII verbatim, and every other
    /// UTF-16 code unit as `\u<signed-16>?` (so a >U+FFFF scalar emits its two surrogate \u words).
    static func escapeRTFText(_ s: String) -> String {
        var out = ""
        for unit in s.utf16 {
            switch unit {
            case 0x5C: out += "\\\\"
            case 0x7B: out += "\\{"
            case 0x7D: out += "\\}"
            case 0x09: out += "\\tab "
            case 0x20..<0x7F: out.unicodeScalars.append(Unicode.Scalar(unit)!)
            default:
                let signed = unit >= 0x8000 ? Int(unit) - 0x10000 : Int(unit)
                out += "\\u\(signed)?"
            }
        }
        return out
    }

    /// Encodes inline runs to RTF. Each run is wrapped in a `{ … }` group so its formatting auto-resets.
    /// `baseMono` is the block's base monospace (a code block); a run's own `inlineCode` also forces mono.
    static func inlineRTF(_ runs: [TextRun], mono baseMono: Bool, emojiSeq: inout Int) -> String {
        var out = ""
        for run in runs {
            let ca = run.attributes
            out += "{"
            out += (baseMono || ca.inlineCode) ? "\\f1 " : "\\f0 "
            if ca.bold { out += "\\b " }
            if ca.italic { out += "\\i " }
            if ca.underline { out += "\\ul " }
            if ca.strikethrough { out += "\\strike " }
            if let emoji = ca.emoji {
                let alt = emoji.altText ?? ""
                let text = alt.isEmpty ? " " : alt
                out += "{\\field{\\*\\fldinst HYPERLINK \"\(escapeRTFText(emojiMarkerURL(id: emoji.id, dedup: emojiSeq)))\"}{\\fldrslt \(escapeRTFText(text))}}"
                emojiSeq += 1
            } else if let link = ca.link, !link.isEmpty {
                out += "{\\field{\\*\\fldinst HYPERLINK \"\(escapeRTFText(link))\"}{\\fldrslt \(escapeRTFText(run.text))}}"
            } else {
                out += escapeRTFText(run.text)
            }
            out += "}"
        }
        return out
    }

    static func fontSize(for style: ParagraphStyleName) -> CGFloat {
        switch style {
        case .heading1: return 24; case .heading2: return 21; case .heading3: return 19; case .heading4: return 17; case .heading5: return 17; case .heading6: return 17
        case .body, .pullQuote: return 17; case .caption: return 15
        }
    }

    static func rtfData(from fragment: Document) -> Data? {
        var emojiSeq = 0
        var paragraphs: [String] = []
        for block in fragment.blocks {
            switch block {
            case .paragraph(let p):
                let pt = fontSize(for: p.style)
                let inline = inlineRTF(p.runs, mono: false, emojiSeq: &emojiSeq)
                let prefix = p.list?.marker == .checklist
                    ? escapeRTFText(ChecklistEmojiMarker.prefix(checked: p.list?.checked ?? false))
                    : ""
                paragraphs.append("\\pard\(alignmentRTF(p.paragraph.alignment))\\fs\(Int(pt * 2)) \(prefix)\(inline)")
            case .code(let c):
                // Interior "\n" → \line so the whole code block stays one paragraph.
                let runs = c.runs.map { TextRun(text: $0.text.replacingOccurrences(of: "\n", with: "\u{2028}"), attributes: $0.attributes) }
                let inline = inlineRTF(runs, mono: true, emojiSeq: &emojiSeq).replacingOccurrences(of: "\\u8232?", with: "\\line ")
                paragraphs.append("\\pard\\fs34 \(inline)")
            case .table(let t):
                paragraphs.append(tableRTF(t, emojiSeq: &emojiSeq))
            case let .pullQuote(pq):
                let pt = fontSize(for: .pullQuote)
                let inline = inlineRTF(pq.runs, mono: false, emojiSeq: &emojiSeq)
                // Centered (\qc) + italic (\i … \i0) — the pull quote's render-only italic isn't in the
                // runs, so emit it here. Best-effort degradation: recipients see a centered italic paragraph.
                paragraphs.append("\\pard\(alignmentRTF(.center))\\fs\(Int(pt * 2))\\i \(inline)\\i0")
            default:
                break   // media has no RTF text rep
            }
        }
        guard !paragraphs.isEmpty else { return nil }
        // Join with \par (paragraph break) between blocks but NO trailing \par — the import splits on "\n"
        // in the NSAttributedString result and a trailing \par would produce a spurious empty final paragraph.
        let body = paragraphs.joined(separator: "\\par\n")
        let rtf = "{\\rtf1\\ansi\\ansicpg1252\\deff0{\\fonttbl{\\f0\\fnil Helvetica;}{\\f1\\fmodern Courier;}}\n\(body)}"
        return rtf.data(using: .utf8)
    }

    /// RTF paragraph alignment control word.
    static func alignmentRTF(_ a: TextAlignment) -> String {
        switch a { case .natural: return ""; case .left: return "\\ql"; case .center: return "\\qc"; case .right: return "\\qr"; case .justified: return "\\qj" }
    }

    /// Emits real RTF table rows. Column right edges are cumulative twips (ColumnSpec.width pt × 20).
    /// Header rows are marked \trhdr and their cells bolded. A cell's paragraphs are flattened (joined by
    /// \line); media in a cell is dropped (no RTF text representation).
    static func tableRTF(_ table: TableBlock, emojiSeq: inout Int) -> String {
        var edges: [Int] = []
        var acc = 0.0
        for col in table.columns { acc += col.width; edges.append(Int(acc * 20)) }
        var out = ""
        for row in table.rows {
            out += "\\trowd"
            if row.isHeader { out += "\\trhdr" }
            for edge in edges { out += "\\cellx\(edge)" }
            out += " "
            for cell in row.cells {
                let align = alignmentRTF(cell.horizontalAlignment)
                // Flatten the cell's paragraph runs (join paragraphs with \line); header cells force bold.
                var cellRuns: [TextRun] = []
                var wroteParagraph = false
                for block in cell.blocks {
                    guard case .paragraph(let p) = block else { continue }   // media-in-cell dropped
                    if wroteParagraph { cellRuns.append(TextRun(text: "\u{2028}")) }
                    for run in p.runs {
                        var attrs = run.attributes
                        if row.isHeader { attrs.bold = true }
                        cellRuns.append(TextRun(text: run.text, attributes: attrs))
                    }
                    wroteParagraph = true
                }
                out += "\\intbl\(align) "
                out += inlineRTF(cellRuns, mono: false, emojiSeq: &emojiSeq).replacingOccurrences(of: "\\u8232?", with: "\\line ")
                out += "\\cell "
            }
            out += "\\row\n"
        }
        return out
    }

    /// IMPORT of external RTF. A link whose anchor text is its own URL — the shape a copied web link takes —
    /// is stripped to plain text (`strippingSelfReferentialLinks`): it pins a destination the plain URL
    /// already carries, and the recipient's client detects the URL anyway. A genuine text link is kept.
    static func fragment(fromRTF data: Data) -> Document? {
        if let parsed = RTFImport.document(fromRTF: data) {                   // custom parser first
            return parsed.strippingSelfReferentialLinks()
        }
        guard let attr = try? NSAttributedString(data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        else { return nil }
        let full = attr.string as NSString
        var blocks: [Block] = []
        var location = 0
        for line in full.components(separatedBy: "\n") {
            let lineLength = (line as NSString).length
            let range = NSRange(location: location, length: lineLength)
            location += lineLength + 1   // +1 for the "\n" separator
            var lineRuns = runs(in: attr, range: range)
            if let first = lineRuns.first, let det = ChecklistEmojiMarker.strippingMarker(first.text) {
                if det.remainder.isEmpty { lineRuns.removeFirst() }
                else { lineRuns[0] = TextRun(text: det.remainder, attributes: first.attributes) }
                blocks.append(.paragraph(ParagraphBlock(id: .generate(),
                    list: ListMembership(marker: .checklist, level: 0, checked: det.checked), runs: lineRuns)))
            } else {
                blocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: lineRuns)))
            }
        }
        return Document(blocks: blocks).strippingSelfReferentialLinks()
    }

    /// Maps the attribute runs in `range` to clean TextRuns (supported inline flags + link only).
    private static func runs(in attr: NSAttributedString, range: NSRange) -> [TextRun] {
        guard range.length > 0 else { return [] }
        let full = attr.string as NSString
        var out: [TextRun] = []
        attr.enumerateAttributes(in: range, options: []) { dict, sub, _ in
            let text = full.substring(with: sub)
            var ca = CharacterAttributes()
            if let f = dict[.font] as? UIFont {
                let t = f.fontDescriptor.symbolicTraits
                ca.bold = t.contains(.traitBold)
                ca.italic = t.contains(.traitItalic)
            }
            if let u = dict[.underlineStyle] as? Int, u != 0 { ca.underline = true }
            if let s = dict[.strikethroughStyle] as? Int, s != 0 { ca.strikethrough = true }
            let linkString = (dict[.link] as? URL)?.absoluteString ?? (dict[.link] as? String)
            if let linkString, let emojiID = emojiID(fromMarkerURL: linkString) {
                // A tg://emoji?id= marker → reconstruct a single-U+FFFC custom emoji run (the model
                // invariant: one object-replacement char per emoji), altText = the display text. A fresh
                // instanceID matches the editor's own emoji-insert path (BlockID.generate()).
                ca.emoji = EmojiRef(id: emojiID, instanceID: BlockID.generate().rawValue, altText: text)
                out.append(TextRun(text: "\u{FFFC}", attributes: ca))
            } else {
                if let linkString { ca.link = linkString }
                out.append(TextRun(text: text, attributes: ca))
            }
        }
        return out
    }
}
#endif
