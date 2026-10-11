import Foundation
import TelegramCore
import TextFormat
import AccountContext

/// The SEND-PATH ORACLE (p20, 2026-09-30): what the chat actually sends for a composer model, and what
/// the edit-message load path makes of the sent message again.
///
/// Every finding before p20 was judged on the composer MODEL. What reaches the wire is a conversion of
/// it, and the conversion has two routes, decided by `ChatInputContent.isEntityExpressible()`:
///
/// - **text + entities** (plain paragraphs, one level of quote, code, mentions, links, dates, custom
///   emoji): `ChatControllerNode.sendCurrentMessage` takes `composeInputState.inputText`
///   (`attributedString(from: content)`), expands collapsed blocks, converts typed markdown, trims,
///   splits at 4096 and builds entities per piece. EDIT loads it back with
///   `ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(text, entities:))`
///   (`ChatControllerLoadDisplayNode`).
/// - **rich** (headings, lists, tables, media, pull quotes, details, formulas, buttons, a quote with an
///   author or nested content): one `RichTextMessageAttribute(instantPage: instantPage(from: content))`,
///   stored in Postbox; EDIT loads `ChatTextInputState(content: chatInputContent(fromInstantPage:))`.
///
/// Every step below is a SHARED function the chat itself calls, in the chat's order. Since the p20 fix wave
/// the route decision and the text loop (markdown conversion, trim, the 4096 split, each piece's
/// entities) are TextFormat's `chatComposerSendRoute` / `chatComposerTextMessages`, which
/// `ChatControllerNode.sendCurrentMessage` calls too — nothing here is a mirror of chat code any more.
///
/// What is NOT modelled: the wire's own `Api` encoding of an `InstantPage` (input and output page-block
/// types differ, so no local round trip exists), the premium "send without formatting" fallback, dice
/// emoji, and a link preview.
enum HarnessSendPath {
    enum Route: String {
        case empty
        case textEntities
        case rich
    }

    struct Sent {
        var route: Route
        /// The text route's messages (one per 4096-character piece).
        var messages: [(text: String, entities: [MessageTextEntity])] = []
        /// The rich route's page, AFTER a Postbox encode / decode (the stored message is what an edit loads).
        var instantPage: InstantPage?
        /// Whether the chat's typed-markdown conversion changed the text (a documented chat feature; a
        /// round trip is then not expected).
        var markdownConverted = false
        /// What EDITING the sent message puts back in the composer. Nil when the message was split.
        var reloaded: ChatInputContent?
    }

    /// Sends `content` the way the chat does and loads the result back the way message editing does.
    static func send(_ content: ChatInputContent) -> Sent {
        if content.isEmpty {
            return Sent(route: .empty, reloaded: ChatInputContent())
        }
        if chatComposerSendRoute(content: content, isNewMessage: true, sendWithoutFormatting: false) == .rich {
            // `ChatControllerNode.sendCurrentMessage`, `sendAsRichMessage`.
            let page = instantPage(from: content)
            let attribute = RichTextMessageAttribute(instantPage: page, fullInstantPage: nil)
            let stored = self.storedRoundTrip(attribute)
            return Sent(route: .rich, instantPage: stored.instantPage, reloaded: chatInputContent(fromInstantPage: stored.instantPage))
        }
        // `ChatControllerNode.sendCurrentMessage`, the text loop: `composeInputState.inputText` is
        // `attributedString(from: content)` (`ChatTextInputState.inputText`).
        let effectiveInputText = expandedInputStateAttributedString(ChatTextInputState(content: content, selectionRange: 0 ..< 0).inputText)
        let textMessages = chatComposerTextMessages(effectiveInputText: effectiveInputText)
        var sent = Sent(route: .textEntities)
        sent.markdownConverted = !textMessages.inputText.isEqual(to: effectiveInputText)
        sent.messages = textMessages.pieces.map { ($0.text.string, $0.entities) }
        if sent.messages.isEmpty {
            sent.reloaded = ChatInputContent()
        } else if sent.messages.count == 1 {
            // `ChatControllerLoadDisplayNode`, the edit load of a text message.
            let message = sent.messages[0]
            sent.reloaded = ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(message.text, entities: message.entities)).content
        }
        return sent
    }

    /// The message attribute as a message stores it (`PostboxEncoder`) and reads it back.
    static func storedRoundTrip(_ attribute: RichTextMessageAttribute) -> RichTextMessageAttribute {
        let encoder = EnginePostboxEncoder()
        attribute.encode(encoder)
        let decoder = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: encoder.makeData()))
        return RichTextMessageAttribute(decoder: decoder)
    }

    // MARK: - Canonical form

    /// The model and the reloaded content, each reduced to what the sent message can carry by DOCUMENTED
    /// rule, so any remaining difference is a loss:
    /// - both routes: equal adjacent runs merged, empty runs dropped; a custom emoji's file and animation flag
    ///   (the wire has neither, `docs/richtext-composer.md` §8);
    /// - text route: a newline inside a paragraph is a paragraph break (plain text has only one kind of
    ///   break), the ends are trimmed as `trimChatInputText` trims them (space, tab, newline, ZWNJ), and an
    ///   EMPTY code block or a quote holding one empty line is an empty line (no character carries its
    ///   entity — not filed: nothing the user wrote is lost);
    /// - rich route: a list item's level (the InstantPage list is flat — accepted limitation, §7), a quote
    ///   author's ambient bold / italic, a table's column widths, a cell's `justified` (→ left), background
    ///   and row height, and media geometry (natural size, display width, alignment), none of which
    ///   InstantPage carries.
    static func canonical(_ content: ChatInputContent, route: Route) -> ChatInputContent {
        var result = ChatInputContent(blocks: content.blocks.flatMap { self.canonical($0, route: route) })
        if route == .textEntities {
            result = self.trimmed(result)
        }
        return result
    }

    static func canonicalRuns(_ runs: [ChatInputRun]) -> [ChatInputRun] {
        return FuzzModel.merged(runs.map { run in
            var run = run
            if case let .customEmoji(fileId, _, _)? = run.attributes.entity {
                run.attributes.entity = .customEmoji(fileId: fileId, file: nil, enableAnimation: true)
            }
            return run
        })
    }

    static func canonical(_ block: ChatInputBlock, route: Route) -> [ChatInputBlock] {
        switch block {
        case var .paragraph(paragraph):
            paragraph.runs = self.canonicalRuns(paragraph.runs)
            if route == .rich, let list = paragraph.list {
                paragraph.list = ChatInputListMembership(marker: list.marker, level: 0, checked: list.checked)
            }
            if route == .textEntities && paragraph.text.contains("\n") {
                return self.splitLines(paragraph.runs).map { runs in
                    var line = paragraph
                    line.runs = runs
                    return .paragraph(line)
                }
            }
            return [.paragraph(paragraph)]
        case var .code(code):
            code.runs = self.canonicalRuns(code.runs)
            // p24 fix wave: the composer holds a language line as typed; what is sent is the trimmed token
            // (`chatInputCodeLanguageForSending`), nil when nothing is left.
            code.language = chatInputCodeLanguageForSending(code.language)
            if route == .textEntities && code.text.isEmpty {
                // An empty code block has no characters to carry a `Pre`: it is sent as an empty line.
                return [.paragraph(ChatInputParagraph())]
            }
            return [.code(code)]
        case var .pullQuote(quote):
            quote.runs = self.canonicalRuns(quote.runs)
            quote.author = self.canonicalRuns(quote.author.map { var run = $0; run.attributes.bold = false; run.attributes.italic = false; return run })
            return [.pullQuote(quote)]
        case var .blockQuote(quote):
            if route == .textEntities, quote.content.blocks.count == 1, case let .paragraph(only) = quote.content.blocks[0], only.text.isEmpty {
                // A quote holding one empty line has no characters to carry a `BlockQuote`: an empty line.
                return [.paragraph(ChatInputParagraph())]
            }
            quote.content = ChatInputContent(blocks: quote.content.blocks.flatMap { self.canonical($0, route: route) })
            quote.author = self.canonicalRuns(quote.author.map { var run = $0; run.attributes.bold = false; return run })
            return [.blockQuote(quote)]
        case var .details(details):
            details.content = ChatInputContent(blocks: details.content.blocks.flatMap { self.canonical($0, route: route) })
            details.title = self.canonicalRuns(details.title)
            return [.details(details)]
        case var .table(table):
            table.columns = table.columns.map { _ in ChatInputColumnSpec(width: 0.0) }
            table.rows = table.rows.map { row in
                var row = row
                row.height = nil
                row.cells = row.cells.map { cell in
                    var cell = cell
                    cell.runs = self.canonicalRuns(cell.runs)
                    cell.background = nil
                    if cell.horizontalAlignment == .justified {
                        cell.horizontalAlignment = .left
                    }
                    return cell
                }
                return row
            }
            return [.table(table)]
        case var .media(media):
            media.caption = self.canonicalRuns(media.caption)
            media.displayWidth = nil
            media.alignment = .center
            media.items = media.items.map { item in
                var item = item
                item.naturalSize = ChatInputSize(width: 0.0, height: 0.0)
                return item
            }
            return [.media(media)]
        case var .buttonRow(row):
            row.buttons = row.buttons.map { button in
                var button = button
                button.label = self.canonicalRuns(button.label)
                return button
            }
            return [.buttonRow(row)]
        }
    }

    /// Runs split at every `"\n"`, one array per line.
    static func splitLines(_ runs: [ChatInputRun]) -> [[ChatInputRun]] {
        var lines: [[ChatInputRun]] = [[]]
        for run in runs {
            let parts = run.text.components(separatedBy: "\n")
            for (index, part) in parts.enumerated() {
                if index > 0 {
                    lines.append([])
                }
                if !part.isEmpty {
                    lines[lines.count - 1].append(ChatInputRun(text: part, attributes: run.attributes))
                }
            }
        }
        return lines
    }

    static let trimmedScalars: Set<Unicode.Scalar> = [" ", "\t", "\n", "\u{200C}"]

    /// `trimChatInputText` applied to the structure: leading / trailing trimmed characters dropped across
    /// block boundaries, and a top-level paragraph left empty by it dropped.
    static func trimmed(_ content: ChatInputContent) -> ChatInputContent {
        var blocks = content.blocks
        func trimRuns(_ runs: inout [ChatInputRun], leading: Bool) -> Bool {
            // Returns true when the trim stopped inside these runs (a kept character was met).
            var indices = Array(runs.indices)
            if !leading { indices.reverse() }
            for index in indices {
                var scalars = Array(runs[index].text.unicodeScalars)
                if leading {
                    while let first = scalars.first, self.trimmedScalars.contains(first) { scalars.removeFirst() }
                } else {
                    while let last = scalars.last, self.trimmedScalars.contains(last) { scalars.removeLast() }
                }
                var view = String.UnicodeScalarView()
                view.append(contentsOf: scalars)
                runs[index].text = String(view)
                if !runs[index].text.isEmpty {
                    runs = runs.filter { !$0.text.isEmpty }
                    return true
                }
            }
            runs = runs.filter { !$0.text.isEmpty }
            return false
        }
        func trimBlock(_ block: inout ChatInputBlock, leading: Bool) -> Bool {
            switch block {
            case var .paragraph(paragraph):
                let stopped = trimRuns(&paragraph.runs, leading: leading)
                block = .paragraph(paragraph)
                return stopped
            case var .code(code):
                let stopped = trimRuns(&code.runs, leading: leading)
                block = .code(code)
                return stopped
            case var .blockQuote(quote):
                // The quote's children from the trimmed end: a child the trim empties goes with its
                // separator; the quote itself goes when none is left.
                var inner = quote.content.blocks
                var stopped = false
                while !inner.isEmpty {
                    let index = leading ? 0 : inner.count - 1
                    if trimBlock(&inner[index], leading: leading) { stopped = true; break }
                    inner.remove(at: index)
                }
                quote.content = ChatInputContent(blocks: inner)
                block = .blockQuote(quote)
                return stopped
            default:
                return true
            }
        }
        for leading in [true, false] {
            while !blocks.isEmpty {
                let index = leading ? 0 : blocks.count - 1
                let stopped = trimBlock(&blocks[index], leading: leading)
                if stopped {
                    break
                }
                // Wholly trimmed: the chat's trim removes the block's characters AND the separator after
                // (before) it. A paragraph goes; a container left empty is gone from the text too.
                blocks.remove(at: index)
            }
        }
        return ChatInputContent(blocks: blocks)
    }

    // MARK: - The oracle

    struct Divergence {
        var route: Route
        var model: ChatInputContent
        var reloaded: ChatInputContent?
        var sent: Sent
        var description: String {
            let messages = self.sent.messages.map { message in
                "\(fuzzEscaped(message.text)) " + message.entities.map { "\($0.type)@\($0.range.lowerBound)..<\($0.range.upperBound)" }.joined(separator: ",")
            }.joined(separator: " | ")
            return "send path (\(self.route.rawValue)) is not a round trip:\n  model    \(HarnessEdited.describe(self.model))\n  reloaded \(self.reloaded.map { HarnessEdited.describe($0) } ?? "(split, not reloadable)")" + (messages.isEmpty ? "" : "\n  sent     \(messages)")
        }
    }

    /// Nil when sending `model` and loading the message back for editing gives `model` again (modulo the
    /// documented canonical form, and not judged when typed markdown converted or the message split).
    static func divergence(_ model: ChatInputContent) -> Divergence? {
        let sent = self.send(model)
        if sent.markdownConverted || sent.route == .empty {
            return nil
        }
        guard let reloaded = sent.reloaded else {
            return nil
        }
        let expected = self.canonical(model, route: sent.route)
        let actual = self.canonical(reloaded, route: sent.route)
        if expected == actual {
            return nil
        }
        return Divergence(route: sent.route, model: model, reloaded: reloaded, sent: sent)
    }
}
