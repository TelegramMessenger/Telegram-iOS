import Foundation
import TelegramCore

/// Chat input content → a SEMANTIC NSAttributedString (text + `ChatTextInputAttributes` only; NO display
/// decoration — no fonts/colors/spoiler-attachments/emoji views). Display-neutral on purpose; the node owns
/// decoration. Tree-shaped successor to `ChatTextInputStateText.attributedText()`.
/// List-item marker rendered as LITERAL TEXT for the legacy input, which cannot hold list structure. `counters`
/// tracks per-level ordered numbering across successive items (reset by the caller on a non-list paragraph).
private func listMarkerText(for list: ChatInputListMembership, counters: inout [Int32: Int]) -> String {
    let indent = String(repeating: "\t", count: max(0, Int(list.level)))
    switch list.marker {
    case .bullet:
        counters = counters.filter { $0.key < list.level }
        return indent + "\u{2022} "                          // "• "
    case .checklist:
        counters = counters.filter { $0.key < list.level }
        return indent + (list.checked == true ? "\u{2611} " : "\u{2610} ")   // "☑ " / "☐ "
    case .ordered:
        let n = (counters[list.level] ?? 0) + 1
        counters[list.level] = n
        counters = counters.filter { $0.key <= list.level }  // deeper levels restart under a new parent item
        return indent + "\(n). "
    }
}

public func attributedString(from content: ChatInputContent, renderListMarkers: Bool = false) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let marker = true as NSNumber
    var isFirst = true
    var orderedCounters: [Int32: Int] = [:]

    func appendSeparatorIfNeeded() {
        if !isFirst { result.append(NSAttributedString(string: "\n")) }
        isFirst = false
    }

    /// Marks everything appended since `start` as a quote — except where a `.block` attribute is
    /// already set. The recursed content of a quote can carry its own block attributes (a code block,
    /// a nested quote); legacy cannot express the nesting either way, and the inner one is the more
    /// specific of the two, so it wins. Ranges are collected before being written so the enumeration
    /// is not mutating what it walks.
    func applyQuoteBlockAttribute(from start: Int) {
        let length = result.length - start
        guard length > 0 else {
            return
        }
        var unattributed: [NSRange] = []
        result.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: start, length: length), options: []) { value, range, _ in
            if value == nil {
                unattributed.append(range)
            }
        }
        let quoteAttribute = ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false)
        for range in unattributed {
            result.addAttribute(ChatTextInputAttributes.block, value: quoteAttribute, range: range)
        }
    }

    func appendRuns(_ runs: [ChatInputRun]) {
        for run in runs {
            let piece = NSMutableAttributedString(string: run.text)
            let r = NSRange(location: 0, length: piece.length)
            let a = run.attributes
            if a.bold { piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: r) }
            if a.italic { piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: r) }
            if a.monospace { piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: r) }
            if a.strikethrough { piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: r) }
            if a.underline { piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: r) }
            if a.spoiler { piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: r) }
            switch a.entity {
            case let .mention(peerId):
                piece.addAttribute(ChatTextInputAttributes.textMention,
                    value: ChatTextInputTextMentionAttribute(peerId: peerId), range: r)
            case let .url(url):
                piece.addAttribute(ChatTextInputAttributes.textUrl,
                    value: ChatTextInputTextUrlAttribute(url: url), range: r)
            case let .date(timestamp):
                piece.addAttribute(ChatTextInputAttributes.date,
                    value: ChatTextInputTextDateAttribute(date: timestamp), range: r)
            case let .customEmoji(fileId, file, enableAnimation):
                // `interactivelySelectedFromPackId`/`custom` are intentionally not modelled — the canonical
                // `ChatTextInputStateText` drops them too (a draft save/restore already loses them), so this
                // matches the persisted fidelity. Only the recently-used-pack bump side effect is affected.
                piece.addAttribute(ChatTextInputAttributes.customEmoji,
                    value: ChatTextInputTextCustomEmojiAttribute(
                        interactivelySelectedFromPackId: nil,
                        fileId: fileId,
                        file: file,
                        enableAnimation: enableAnimation), range: r)
            case nil:
                break
            case .button:
                // No chat text attribute: a pill has no entity form (see the fallback path's note).
                break
            }
            result.append(piece)
        }
    }

    var i = 0
    while i < content.blocks.count {
        let block = content.blocks[i]
        switch block {
        case let .code(code):
            appendSeparatorIfNeeded()
            let start = result.length
            result.append(NSAttributedString(string: code.text))
            let len = result.length - start
            if len > 0 {
                let attr = chatInputCodeBlockAttribute(language: code.language)
                result.addAttribute(attr.key, value: attr.value, range: NSRange(location: start, length: len))
            }
        case let .paragraph(paragraph):
            appendSeparatorIfNeeded()
            if renderListMarkers {
                if let list = paragraph.list {
                    result.append(NSAttributedString(string: listMarkerText(for: list, counters: &orderedCounters)))
                } else {
                    orderedCounters.removeAll()   // a non-list paragraph ends any ordered run
                }
            }
            appendRuns(paragraph.runs)
        case let .pullQuote(pq):
            // Legacy UITextView projection: render pull-quote text as a quote-attributed block, mirroring `.code`.
            // The native Document ↔ ChatInputContent bridge bypasses this path for pull-quote blocks entirely.
            appendSeparatorIfNeeded()
            let start = result.length
            appendRuns(pq.runs)
            applyQuoteBlockAttribute(from: start)
        case let .blockQuote(bq):
            // Legacy UITextView projection for the structured blockQuote. The native Document ↔ ChatInputContent
            // bridge bypasses this path entirely (like `.pullQuote`). For the flat view:
            // - collapsed → " " placeholder with `.collapsedBlock`
            // - expanded → inner content with `.block` / `.quote` attribute (mirrors quote paragraphs)
            appendSeparatorIfNeeded()
            if bq.collapsed {
                result.append(NSAttributedString(string: " ", attributes: [
                    ChatTextInputAttributes.collapsedBlock: attributedString(from: bq.content, renderListMarkers: renderListMarkers)
                ]))
            } else {
                let start = result.length
                // Recursed, NOT `bq.content.plainText`. A bare string throws away every inline attribute
                // inside the quote — custom emoji, bold, links, mentions, spoilers — and this projection
                // is what the send path serialises (`expandedInputStateAttributedString(inputText)`), so
                // the loss reached the wire: a custom emoji in a quote arrived as its `alt` text.
                // The recursion emits the same characters (`plainText` for a quote IS its content's
                // `plainText`, and the default `renderListMarkers: false` adds none of its own), so the
                // flat axis every selection offset is measured against does not move.
                result.append(attributedString(from: bq.content, renderListMarkers: renderListMarkers))
                applyQuoteBlockAttribute(from: start)
            }
        case .media, .table, .details, .buttonRow:
            // INTENTIONAL render-only filter (not deferred): the legacy `UITextView` composer cannot represent a
            // structural media/table/detail block, so this `NSAttributedString` projection drops them. Heading/list
            // paragraphs above similarly render as plain text (`appendRuns` ignores heading style + list membership).
            // `ChatInputContent` stays the sole authoritative storage; this flat view is lossy by design. The native
            // engine carries these blocks via the direct `Document ↔ ChatInputContent` bridge, never this path.
            break
        }
        i += 1
    }
    return result
}

/// Chat input content -> a sendable attributed string that keeps message-entity formatting, but flattens
/// rich-only layout so it can be sent on the normal text/entities path.
public func entityPreservingFallbackAttributedString(
    from content: ChatInputContent,
    preserveCustomEmoji: (Int64, TelegramMediaFile?) -> Bool
) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let marker = true as NSNumber
    var isFirst = true

    func appendSeparatorIfNeeded() {
        if !isFirst {
            result.append(NSAttributedString(string: "\n"))
        }
        isFirst = false
    }

    func attributedRuns(_ runs: [ChatInputRun], preserveInlineAttributes: Bool = true) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in runs {
            let piece = NSMutableAttributedString(string: run.attributes.formula ?? run.text)
            let range = NSRange(location: 0, length: piece.length)
            if range.length == 0 {
                continue
            }

            if preserveInlineAttributes {
                let attributes = run.attributes
                if attributes.bold {
                    piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: range)
                }
                if attributes.italic {
                    piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: range)
                }
                if attributes.monospace {
                    piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: range)
                }
                if attributes.strikethrough {
                    piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: range)
                }
                if attributes.underline {
                    piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: range)
                }
                if attributes.spoiler {
                    piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: range)
                }
                switch attributes.entity {
                case let .mention(peerId):
                    piece.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: peerId), range: range)
                case let .url(url):
                    piece.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: range)
                case let .date(timestamp):
                    piece.addAttribute(ChatTextInputAttributes.date, value: ChatTextInputTextDateAttribute(date: timestamp), range: range)
                case let .customEmoji(fileId, file, enableAnimation):
                    if preserveCustomEmoji(fileId, file) {
                        piece.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: file, enableAnimation: enableAnimation), range: range)
                    }
                case .button:
                    // No chat text attribute: a pill has no entity form. Deliberately NOT a textUrl for a
                    // `.url` action — that would silently demote the pill to a plain link.
                    break
                case nil:
                    break
                }
            }

            result.append(piece)
        }

        return result
    }

    func appendParagraph(_ paragraph: NSAttributedString, blockAttribute: ChatTextInputTextQuoteAttribute?) {
        if paragraph.length == 0 {
            return
        }
        appendSeparatorIfNeeded()
        let start = result.length
        result.append(paragraph)
        if let blockAttribute {
            result.addAttribute(ChatTextInputAttributes.block, value: blockAttribute, range: NSRange(location: start, length: paragraph.length))
        }
    }

    func appendRuns(_ runs: [ChatInputRun], blockAttribute: ChatTextInputTextQuoteAttribute? = nil) {
        appendParagraph(attributedRuns(runs), blockAttribute: blockAttribute)
    }

    func appendContent(_ content: ChatInputContent, inheritedBlockAttribute: ChatTextInputTextQuoteAttribute?) {
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph):
                appendRuns(paragraph.runs, blockAttribute: inheritedBlockAttribute)
            case let .code(code):
                let blockAttribute = inheritedBlockAttribute ?? ChatTextInputTextQuoteAttribute(kind: .code(language: code.language), isCollapsed: false)
                appendParagraph(attributedRuns(code.runs, preserveInlineAttributes: inheritedBlockAttribute != nil), blockAttribute: blockAttribute)
            case let .pullQuote(pullQuote):
                let quoteAttribute = inheritedBlockAttribute ?? ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false)
                appendRuns(pullQuote.runs, blockAttribute: quoteAttribute)
                appendRuns(pullQuote.author, blockAttribute: inheritedBlockAttribute)
            case let .blockQuote(blockQuote):
                let quoteAttribute = inheritedBlockAttribute ?? ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: blockQuote.collapsed)
                appendContent(blockQuote.content, inheritedBlockAttribute: quoteAttribute)
                appendRuns(blockQuote.author, blockAttribute: inheritedBlockAttribute)
            case let .details(details):
                // Defensive entity-path fallback (details normally forces the rich path): flatten the title
                // then the nested content as plain text, so nothing is lost if it ever reaches this path.
                appendRuns(details.title, blockAttribute: inheritedBlockAttribute)
                appendContent(details.content, inheritedBlockAttribute: inheritedBlockAttribute)
            case let .media(media):
                appendRuns(media.caption, blockAttribute: inheritedBlockAttribute)
            case let .table(table):
                for row in table.rows {
                    let rowText = NSMutableAttributedString()
                    for i in 0 ..< row.cells.count {
                        if i != 0 {
                            rowText.append(NSAttributedString(string: "\t"))
                        }
                        rowText.append(attributedRuns(row.cells[i].runs))
                    }
                    appendParagraph(rowText, blockAttribute: inheritedBlockAttribute)
                }
            case .buttonRow:
                // Defensive entity-path fallback (a button always forces the rich path). A pill has no
                // flat-text form and its label is not document text, so it contributes nothing — matching
                // `attributedString(from:)` and `ChatInputContent.plainText`.
                break
            }
        }
    }

    appendContent(content, inheritedBlockAttribute: nil)
    return result
}

/// NSAttributedString → ChatInputContent (two-pass: carve non-paragraph block regions — code, EXPANDED quotes,
/// collapsed blockQuotes — via `enumerateAttribute`, fill gaps with paragraphs, consuming one separator "\n"
/// per boundary — mirrors `ComposerDocumentBridge.document(from:)`).
///
/// A quote is carved as a **contiguous `.block`/.quote run** (exactly like a code block), NOT split per line.
/// This is load-bearing: the legacy UITextView represents a multi-line quote as ONE `.block` object spanning
/// the interior "\n"s, so carving by run keeps it a single multi-paragraph `.blockQuote`. Two genuinely
/// separate quotes are separated by a "\n" that carries NO block attribute, so `enumerateAttribute` yields two
/// runs → two `.blockQuote` blocks. (Parsing per-"\n" instead discarded that run boundary and fragmented every
/// multi-line quote into one block per line, so a save/restore of the persisted `content` split one quote into
/// several.)
/// The inline runs for a range of an `NSAttributedString`, reading the chat attribute vocabulary.
///
/// Extracted from `chatInputContent(from:)` (which calls it per paragraph) so the vocabulary is
/// defined in exactly one place: `ChatTextInputState.replacingFlatRange` needs the same conversion for
/// the small replacement fragments the composer splices in.
///
/// Block-level attributes are deliberately NOT read here — the block kind is decided by the caller
/// that owns the range. A `"\n"` is carried inside a run; splitting it into blocks belongs to the
/// splice, which is the only thing that knows whether the host paragraph splits or not.
///
/// Named `fromAttributedString:` rather than `from:` because TelegramCore already vends a
/// `chatInputRuns(fromRichText:)`; a bare `from:` beside it reads as the same conversion.
public func chatInputRuns(fromAttributedString attributedText: NSAttributedString, in range: NSRange) -> [ChatInputRun] {
    var runs: [ChatInputRun] = []
    guard range.length > 0 else {
        return runs
    }
    let full = attributedText.string as NSString
    attributedText.enumerateAttributes(in: range, options: []) { dict, r, _ in
        var a = ChatInputInlineAttributes()
        if dict[ChatTextInputAttributes.bold] != nil { a.bold = true }
        if dict[ChatTextInputAttributes.italic] != nil { a.italic = true }
        if dict[ChatTextInputAttributes.monospace] != nil { a.monospace = true }
        if dict[ChatTextInputAttributes.strikethrough] != nil { a.strikethrough = true }
        if dict[ChatTextInputAttributes.underline] != nil { a.underline = true }
        if dict[ChatTextInputAttributes.spoiler] != nil { a.spoiler = true }
        if let m = dict[ChatTextInputAttributes.textMention] as? ChatTextInputTextMentionAttribute {
            a.entity = .mention(m.peerId)
        } else if let d = dict[ChatTextInputAttributes.date] as? ChatTextInputTextDateAttribute {
            a.entity = .date(d.date)
        } else if let e = dict[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
            a.entity = .customEmoji(fileId: e.fileId, file: e.file, enableAnimation: e.enableAnimation)
        } else if let u = dict[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
            a.entity = .url(u.url)
        }
        runs.append(ChatInputRun(text: full.substring(with: r), attributes: a))
    }
    return runs
}

/// Whole-string convenience over `chatInputRuns(fromAttributedString:in:)`.
public func chatInputRuns(fromAttributedString attributedText: NSAttributedString) -> [ChatInputRun] {
    return chatInputRuns(fromAttributedString: attributedText,
                         in: NSRange(location: 0, length: attributedText.length))
}

public func chatInputContent(from attributedText: NSAttributedString) -> ChatInputContent {
    let full = attributedText.string as NSString
    var blocks: [ChatInputBlock] = []

    // Block-level attributes (`.block`/`.collapsedBlock`) are NOT read by the run conversion — the block
    // kind is decided by the carve that owns the range, so gaps are always plain.
    func paragraphRuns(in pr: NSRange) -> [ChatInputRun] {
        return chatInputRuns(fromAttributedString: attributedText, in: pr)
    }

    // Split a range into plain `.paragraph` blocks by interior "\n" (one paragraph per line, empty lines kept).
    func paragraphBlocks(in range: NSRange) -> [ChatInputBlock] {
        guard range.length > 0 else { return [] }
        var result: [ChatInputBlock] = []
        var lineStart = range.location
        let end = range.location + range.length
        var i = range.location
        while i < end {
            if full.character(at: i) == 0x0A {
                result.append(.paragraph(ChatInputParagraph(style: .body, runs: paragraphRuns(in: NSRange(location: lineStart, length: i - lineStart)))))
                lineStart = i + 1
            }
            i += 1
        }
        result.append(.paragraph(ChatInputParagraph(style: .body, runs: paragraphRuns(in: NSRange(location: lineStart, length: end - lineStart)))))
        return result
    }

    // Carve out the non-paragraph block regions (code blocks + expanded quotes + collapsed blockQuotes), then
    // fill the gaps with paragraphs, consuming one separator "\n" per boundary — mirrors `ComposerDocumentBridge`.
    enum CarveKind {
        case code(language: String?)
        /// A contiguous `.block`/.quote run → an expanded `.blockQuote` whose interior "\n"s become inner paragraphs.
        case quote(collapsed: Bool)
        /// A `.collapsedBlock`-attributed character: maps to `.blockQuote(collapsed: true)` (Task 16b).
        case collapsedBlock(content: NSAttributedString)
    }
    var carves: [(range: NSRange, kind: CarveKind)] = []
    for region in codeBlockRanges(in: attributedText) {
        carves.append((range: region.range, kind: .code(language: region.language)))
    }
    // Each maximal `.block`/.quote run becomes one carve (adjacent equal-valued runs are already merged by
    // `enumerateAttribute`), so a multi-line quote stays one block and its interior "\n"s become inner paragraphs.
    attributedText.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: attributedText.length), options: []) { value, range, _ in
        if let q = value as? ChatTextInputTextQuoteAttribute, case .quote = q.kind {
            carves.append((range: range, kind: .quote(collapsed: q.isCollapsed)))
        }
    }
    attributedText.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: attributedText.length), options: []) { value, range, _ in
        if let nested = value as? NSAttributedString {
            carves.append((range: range, kind: .collapsedBlock(content: nested)))
        }
    }
    carves.sort { $0.range.location < $1.range.location }

    var cursor = 0
    for carve in carves {
        var gapEnd = carve.range.location
        if gapEnd > cursor && full.character(at: gapEnd - 1) == 0x0A { gapEnd -= 1 }
        if gapEnd > cursor { blocks.append(contentsOf: paragraphBlocks(in: NSRange(location: cursor, length: gapEnd - cursor))) }
        switch carve.kind {
        case let .code(language):
            blocks.append(.code(ChatInputCode(
                language: language,
                runs: [ChatInputRun(text: full.substring(with: carve.range))])))
        case let .quote(collapsed):
            blocks.append(.blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: paragraphBlocks(in: carve.range)),
                collapsed: collapsed)))
        case let .collapsedBlock(content):
            // `.collapsedBlock` attribute now maps to a collapsed `.blockQuote` (Task 16b).
            blocks.append(.blockQuote(ChatInputBlockQuote(
                content: chatInputContent(from: content),
                collapsed: true)))
        }
        cursor = carve.range.location + carve.range.length
        if cursor < full.length && full.character(at: cursor) == 0x0A { cursor += 1 }
    }
    if cursor < full.length { blocks.append(contentsOf: paragraphBlocks(in: NSRange(location: cursor, length: full.length - cursor))) }

    if blocks.isEmpty { blocks = [.paragraph(ChatInputParagraph())] }
    return ChatInputContent(blocks: blocks)
}
