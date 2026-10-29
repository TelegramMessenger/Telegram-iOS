import Foundation

public enum RTFImport {
    public static func document(fromRTF data: Data) -> Document? {
        // Cheap guard: must look like RTF.
        guard data.starts(with: Array("{\\rtf".utf8)) || String(decoding: data.prefix(16), as: UTF8.self).contains("{\\rtf") else { return nil }
        let blocks = RTFDocumentParser().parse(RTFTokenizer.tokenize(data))
        return blocks.isEmpty ? nil : Document(blocks: blocks)
    }
}

/// Per-group character formatting + destination context.
private struct RTFState {
    var bold = false
    var italic = false
    var underline = false
    var strike = false
    var fontIndex = 0
    var fontSizeHalfPoints = 24      // default 12pt
    var skipDestination = false      // inside fonttbl/colortbl/stylesheet/info/pict/ignorable
    var inFontTable = false
    var inFieldInst = false          // inside \*\fldinst — capture text to fldInstText
    var inFieldResult = false        // inside \fldrslt — emit text with link attr
    var inListText = false           // inside \listtext or \pntext — capture marker, suppress output
}

final class RTFDocumentParser {
    private var stack: [RTFState] = [RTFState()]
    private var state: RTFState {
        get { stack[stack.count - 1] }
        set { stack[stack.count - 1] = newValue }
    }
    private var monoFonts: Set<Int> = []     // \fN indices that are monospace
    private var fontTableName = ""           // accumulates the current \fN name while reading fonttbl
    private var fontTableIndex = 0
    private var fontTableModern = false

    // List state (per-paragraph, not group-scoped).
    private var curListLevel: Int? = nil     // set by \ilvlN or \lsN
    private var curListMarkerText = ""       // text captured inside \listtext / \pntext
    private var curSawListText = false       // a \listtext/\pntext marker group was seen this paragraph

    // Field handling state (parser-level, not group-scoped).
    private var fldInstText = ""             // accumulates \fldinst text
    private var fldInstDepth = 0            // stack.count when \fldinst was entered
    private var fldRsltDepth = 0            // stack.count when \fldrslt was entered
    private var pendingFieldURL: String?     // URL parsed from fldinst, used during fldrslt
    private var resultURL: String?           // active link URL while inside fldrslt

    // Custom emoji tg:// URL prefix (keep in sync with TextFormat/CustomEmojiMarkdownMarker.swift).
    private static let emojiPrefix = "tg://emoji?id="

    // Current paragraph being built.
    private var runs: [TextRun] = []
    private var curText = ""
    private var curAttrs = CharacterAttributes()
    var blocks: [Block] = []

    // Table state machine.
    // `inTable` latches true once any table structure is open and stays true until `flushTableIfAny()`.
    // `currentParagraphInTable` tracks whether the CURRENT paragraph is a table cell paragraph (set by
    // `\intbl`, cleared by `\pard` and after a cell/row flush). This lets `\par`/`\pard` distinguish
    // "still inside a cell" from "table ended, this is a following body paragraph".
    private var inTable = false
    private var currentParagraphInTable = false
    private var rowIsHeader = false
    private var cellEdges: [Int] = []
    private var curCellBlocks: [Block] = []
    private var curRowCells: [Cell] = []
    private var tableRows: [Row] = []
    private var tableColumns: [ColumnSpec] = []

    func parse(_ tokens: [RTFToken]) -> [Block] {
        for tok in tokens { handle(tok) }
        flushTableIfAny()
        flushParagraph()
        return blocks
    }

    private func attrsForState() -> CharacterAttributes {
        var a = CharacterAttributes()
        a.bold = state.bold
        a.italic = state.italic
        a.underline = state.underline
        a.strikethrough = state.strike
        a.inlineCode = monoFonts.contains(state.fontIndex)
        if state.inFieldResult, let url = resultURL {
            a.link = url
        }
        return a
    }

    private func flushRun() {
        if !curText.isEmpty {
            runs.append(TextRun(text: curText, attributes: curAttrs))
            curText = ""
        }
    }

    private func appendText(_ s: String) {
        let a = attrsForState()
        if a != curAttrs { flushRun(); curAttrs = a }
        curText += s
    }

    /// Emits the pending paragraph. `allowEmpty` is set by an explicit `\par` (a paragraph terminator),
    /// so a blank line survives as an empty body paragraph; the implicit end-of-document flush leaves it
    /// false so a document with no trailing `\par` gains no spurious empty final paragraph.
    func flushParagraph(allowEmpty: Bool = false) {
        flushRun()
        // While inside a table, content belongs to cells — do not emit a top-level block.
        if inTable { runs = []; return }
        guard !runs.isEmpty else {
            if allowEmpty {
                blocks.append(.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: [])))
            }
            runs = []
            curListLevel = nil
            curListMarkerText = ""
            curSawListText = false
            return
        }
        // Code: every run mono → merge into a trailing code block.
        if runs.allSatisfy({ $0.attributes.inlineCode }) {
            let stripped = runs.map { TextRun(text: $0.text, attributes: CharacterAttributes()) }
            if case .code(var last)? = blocks.last {
                last.runs.append(TextRun(text: "\n")); last.runs.append(contentsOf: stripped)
                blocks[blocks.count - 1] = .code(last)
            } else {
                blocks.append(.code(CodeBlock(id: .generate(), runs: stripped)))
            }
            runs = []; return
        }
        let pt = state.fontSizeHalfPoints / 2
        let style: ParagraphStyleName = pt >= 23 ? .heading1 : pt >= 20 ? .heading2 : pt >= 18 ? .heading3 : .body
        var list: ListMembership? = nil
        if curListLevel != nil || curSawListText {
            let lvl = curListLevel ?? 0
            let m = curListMarkerText.trimmingCharacters(in: .whitespaces)
            let marker: ListMarker = m.first.map { "0123456789".contains($0) } == true ? .ordered : .bullet
            list = ListMembership(marker: marker, level: lvl)
        }
        // Emoji checkbox → checklist. Prefer a checkbox in the \listtext marker; else detect at the start of the
        // paragraph text (the editor's own export emits the emoji as paragraph text, with no \listtext).
        if let det = ChecklistEmojiMarker.strippingMarker(curListMarkerText) {
            list = ListMembership(marker: .checklist, level: curListLevel ?? 0, checked: det.checked)
        } else if let first = runs.first, let det = ChecklistEmojiMarker.strippingMarker(first.text) {
            list = ListMembership(marker: .checklist, level: curListLevel ?? 0, checked: det.checked)
            if det.remainder.isEmpty {
                runs.removeFirst()
            } else {
                runs[0] = TextRun(text: det.remainder, attributes: first.attributes)
            }
        }
        blocks.append(.paragraph(ParagraphBlock(id: .generate(), style: style, list: list, runs: runs)))
        runs = []
        curListLevel = nil
        curListMarkerText = ""
        curSawListText = false
    }

    private func handle(_ tok: RTFToken) {
        switch tok {
        case .groupStart:
            stack.append(state)
        case .groupEnd:
            // Finish reading a fonttbl entry if we were in one.
            if state.inFontTable { commitFontEntry() }

            // Check if we're closing the \fldinst group.
            if state.inFieldInst && stack.count == fldInstDepth {
                // Parse the URL from accumulated fldinst text.
                pendingFieldURL = parseHyperlinkURL(from: fldInstText)
                fldInstText = ""
            }

            // Check if we're closing the \fldrslt group.
            if state.inFieldResult && stack.count == fldRsltDepth {
                // If the resultURL is a tg://emoji marker, convert the accumulated
                // link run to an emoji run.
                let closingURL = resultURL
                resultURL = nil
                if let url = closingURL, let eid = emojiID(from: url) {
                    convertLastRunsToEmojiRun(linkURL: url, emojiID: eid)
                }
            }

            if stack.count > 1 { stack.removeLast() }
        case .controlSymbol(let c):
            if c == "*" { state.skipDestination = true }     // ignorable destination
        case .controlWord(let name, let param):
            handleControl(name, param)
        case .text(let s):
            if state.inFontTable { fontTableName += s; return }
            if state.inFieldInst { fldInstText += s; return }
            if state.inListText { curListMarkerText += s; return }
            if state.skipDestination { return }
            appendText(s)
        }
    }

    private func handleControl(_ name: String, _ param: Int?) {
        switch name {
        case "fonttbl":
            state.inFontTable = true
            state.skipDestination = true
            fontTableName = ""
            fontTableModern = false
        case "colortbl", "stylesheet", "info", "pict", "themedata", "datastore",
             "listtable", "listoverridetable", "generator":
            state.skipDestination = true
        case "listtext", "pntext":
            // Destination whose TEXT is the list marker glyph (e.g. "•" or "1.").
            // Capture its text into curListMarkerText; do NOT skip or emit it normally.
            state.inListText = true
            state.skipDestination = false
            curListMarkerText = ""
            curSawListText = true
        case "ilvl":
            curListLevel = param ?? 0
        case "ls":
            if curListLevel == nil { curListLevel = 0 }
        case "field":
            break        // container; child groups carry the work
        case "fldinst":
            // Cancel the ignorable-destination flag set by the preceding \*.
            state.skipDestination = false
            state.inFieldInst = true
            fldInstDepth = stack.count
            fldInstText = ""
        case "fldrslt":
            flushRun()
            resultURL = pendingFieldURL
            pendingFieldURL = nil
            state.inFieldResult = true
            fldRsltDepth = stack.count
        case "f":
            if state.inFontTable {
                commitFontEntry()
                fontTableIndex = param ?? 0
                fontTableName = ""
                fontTableModern = false
            } else {
                state.fontIndex = param ?? 0
                flushRunBoundary()
            }
        case "fmodern":
            if state.inFontTable { fontTableModern = true }
        case "fs":
            state.fontSizeHalfPoints = param ?? 24
            flushRunBoundary()
        case "b":
            setFlag(\.bold, param)
        case "i":
            setFlag(\.italic, param)
        case "ul":
            setFlag(\.underline, param)
        case "ulnone":
            state.underline = false
            flushRunBoundary()
        case "strike":
            setFlag(\.strike, param)
        case "plain":
            state.bold = false
            state.italic = false
            state.underline = false
            state.strike = false
            flushRunBoundary()
        case "trowd":
            // A pre-table paragraph (Cocoa/TextEdit emits NO \par before \trowd) must be flushed as its own
            // top-level block BEFORE the table starts, else its pending runs leak into the first cell.
            // Guard on `!inTable` so this fires only on the FIRST \trowd of a table, not per-row.
            if !inTable { flushParagraph() }
            inTable = true; cellEdges = []; rowIsHeader = false
            // \trowd starts a new row descriptor but does NOT mark the current paragraph as in-cell;
            // that happens on \intbl.
        case "trhdr":
            rowIsHeader = true
        case "cellx":
            if let e = param { cellEdges.append(e) }
        case "intbl":
            inTable = true
            currentParagraphInTable = true
        case "cell":
            flushCellInTable()
            currentParagraphInTable = false
        case "row":
            flushRowInTable()
            currentParagraphInTable = false
        case "par":
            if currentParagraphInTable {
                // This \par is a paragraph break INSIDE a table cell.
                flushRun()
                if !runs.isEmpty { curCellBlocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: runs))); runs = [] }
                curListLevel = nil; curListMarkerText = ""
            } else {
                // Not in a cell paragraph — the table (if any) has ended; flush it first, then
                // emit this as a top-level paragraph. An explicit `\par` preserves a blank line.
                flushTableIfAny()
                flushParagraph(allowEmpty: true)   // resets curListLevel/curListMarkerText
            }
        case "pard":
            // \pard resets paragraph formatting. Clear the per-paragraph in-cell flag.
            let wasInCellParagraph = currentParagraphInTable
            currentParagraphInTable = false
            if wasInCellParagraph {
                // \pard inside a cell: flush any accumulated in-cell runs but remain in the table.
                // The next \intbl will re-establish the cell context.
                flushRun()
                if !runs.isEmpty { curCellBlocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: runs))); runs = [] }
                curListLevel = nil; curListMarkerText = ""
            } else if !inTable {
                // Outside a table: flush any pending table (safety) and any pending paragraph.
                // Handles RTF that uses \pard as a paragraph separator without a preceding \par.
                flushTableIfAny()
                flushParagraph()   // resets curListLevel/curListMarkerText
            }
            // else: inTable is true but currentParagraphInTable was already false — this is a \pard
            // at the start of a new cell (Word's \pard\intbl pattern). The next \intbl will restore
            // currentParagraphInTable. Do NOT flush the table here; let \par handle it.
        case "tab":
            // \tab inside a \listtext / \pntext group is a marker separator — suppress it.
            if !state.inListText { appendText("\t") }
        case "line":
            appendText("\n")
        default:
            break        // unknown control word → no-op
        }
    }

    private func setFlag(_ kp: WritableKeyPath<RTFState, Bool>, _ param: Int?) {
        stack[stack.count - 1][keyPath: kp] = (param != 0)
        flushRunBoundary()
    }

    private func flushRunBoundary() {
        let a = attrsForState()
        if a != curAttrs { flushRun(); curAttrs = a }
    }

    private func commitFontEntry() {
        let n = fontTableName.replacingOccurrences(of: ";", with: "")
        let lower = n.lowercased()
        let mono = fontTableModern || ["courier", "menlo", "consolas", "monaco", "mono"].contains { lower.contains($0) }
        if mono { monoFonts.insert(fontTableIndex) }
        fontTableName = ""
    }

    // MARK: - Field / hyperlink helpers

    /// Extracts the URL from an RTF HYPERLINK instruction string, e.g.:
    ///   `HYPERLINK "https://example.com"` → `"https://example.com"`
    /// Tolerant of leading whitespace and uses first/last `"` as delimiters.
    private func parseHyperlinkURL(from text: String) -> String? {
        guard let first = text.firstIndex(of: "\""),
              let last = text.lastIndex(of: "\""),
              first < last else { return nil }
        let url = String(text[text.index(after: first)..<last])
        return url.isEmpty ? nil : url
    }

    /// If `url` is a `tg://emoji?id=<id>` marker, returns the id (up to first `&`).
    private func emojiID(from url: String) -> String? {
        guard url.hasPrefix(Self.emojiPrefix) else { return nil }
        var id = String(url.dropFirst(Self.emojiPrefix.count))
        if let amp = id.firstIndex(of: "&") { id = String(id[..<amp]) }
        return id.isEmpty ? nil : id
    }

    // MARK: - Table flush helpers

    private func flushCellInTable() {
        flushRun()
        if !runs.isEmpty {
            curCellBlocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: runs)))
            runs = []
        }
        let cellBlocks: [Block] = curCellBlocks.isEmpty
            ? [.paragraph(ParagraphBlock(id: .generate(), runs: []))]
            : curCellBlocks
        curRowCells.append(Cell(id: .generate(), blocks: cellBlocks))
        curCellBlocks = []
    }

    private func flushRowInTable() {
        if tableColumns.isEmpty && !cellEdges.isEmpty {
            var prev = 0
            for e in cellEdges {
                tableColumns.append(ColumnSpec(width: Double(e - prev) / 20.0))
                prev = e
            }
        }
        if !curRowCells.isEmpty {
            tableRows.append(Row(id: .generate(), isHeader: rowIsHeader, cells: curRowCells))
        }
        curRowCells = []
    }

    private func flushTableIfAny() {
        guard !tableRows.isEmpty else {
            // Even if no rows, make sure table state is fully cleared if `inTable` was latched.
            if inTable {
                inTable = false
                currentParagraphInTable = false
                cellEdges = []
                curCellBlocks = []
                curRowCells = []
                rowIsHeader = false
            }
            return
        }
        blocks.append(.table(TableBlock(id: .generate(), columns: tableColumns, rows: tableRows)))
        // Reset ALL table accumulators so a following \trowd starts clean.
        tableRows = []
        tableColumns = []
        cellEdges = []
        curCellBlocks = []
        curRowCells = []
        rowIsHeader = false
        inTable = false
        currentParagraphInTable = false
    }

    /// After a `\fldrslt` group closes with an emoji marker URL, replace any link
    /// runs that were accumulated during the fldrslt with a single U+FFFC emoji run.
    private func convertLastRunsToEmojiRun(linkURL: String, emojiID: String) {
        // Flush whatever text was buffered at closing time.
        flushRun()

        // Collect text from the link runs produced during fldrslt (altText).
        let altText = runs
            .filter { $0.attributes.link == linkURL }
            .map(\.text).joined()

        // Remove those link runs from the paragraph.
        runs.removeAll { $0.attributes.link == linkURL }

        // Emit a single U+FFFC emoji run.
        var emojiAttrs = CharacterAttributes()
        emojiAttrs.emoji = EmojiRef(
            id: emojiID,
            instanceID: BlockID.generate().rawValue,
            altText: altText.isEmpty ? nil : altText
        )
        runs.append(TextRun(text: "\u{FFFC}", attributes: emojiAttrs))
        curText = ""
        curAttrs = attrsForState()
    }
}
