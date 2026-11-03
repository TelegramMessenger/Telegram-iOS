import XCTest
import Postbox
@testable import TelegramCore
@testable import TextFormat

/// Run-list primitives underneath `replacingFlatRange`. They are pure functions over `[ChatInputRun]`
/// with no block knowledge, so they are tested on their own before the block-level splice uses them.
final class ChatInputRunPrimitiveTests: XCTestCase {
    private var bold: ChatInputInlineAttributes {
        var a = ChatInputInlineAttributes(); a.bold = true; return a
    }

    private func runs(_ pairs: [(String, ChatInputInlineAttributes)]) -> [ChatInputRun] {
        return pairs.map { ChatInputRun(text: $0.0, attributes: $0.1) }
    }

    private func described(_ runs: [ChatInputRun]) -> [String] {
        return runs.map { "\($0.text)|\($0.attributes.bold ? "b" : "-")" }
    }

    func test_length_sumsUTF16NotCharacters() {
        // An emoji placeholder is 1 UTF-16 unit; a surrogate pair is 2. The flat axis counts UTF-16.
        XCTAssertEqual(chatInputRunsUTF16Length(self.runs([("ab", ChatInputInlineAttributes())])), 2)
        XCTAssertEqual(chatInputRunsUTF16Length(self.runs([("a", ChatInputInlineAttributes()), ("🙂", ChatInputInlineAttributes())])), 3)
        XCTAssertEqual(chatInputRunsUTF16Length([]), 0)
    }

    func test_slice_keepsPerRunAttributes_acrossRunBoundaries() {
        let source = self.runs([("abc", ChatInputInlineAttributes()), ("DEF", self.bold), ("ghi", ChatInputInlineAttributes())])
        // [2, 8) is "c" + "DEF" + "gh" — spans all three runs, partial at both ends.
        XCTAssertEqual(self.described(chatInputRunsSlice(source, fromUTF16: 2, toUTF16: 8)),
                       ["c|-", "DEF|b", "gh|-"])
    }

    func test_slice_withinASingleRun() {
        let source = self.runs([("abcdef", self.bold)])
        XCTAssertEqual(self.described(chatInputRunsSlice(source, fromUTF16: 1, toUTF16: 3)), ["bc|b"])
    }

    func test_slice_emptyAndOutOfOrderRangesYieldNothing() {
        let source = self.runs([("abc", ChatInputInlineAttributes())])
        XCTAssertEqual(chatInputRunsSlice(source, fromUTF16: 2, toUTF16: 2), [])
        XCTAssertEqual(chatInputRunsSlice(source, fromUTF16: 3, toUTF16: 1), [])
    }

    func test_splitOnNewlines_producesOneGroupPerLine_keepingAttributes() {
        let source = self.runs([("one\ntw", ChatInputInlineAttributes()), ("o", self.bold), ("\nthree", ChatInputInlineAttributes())])
        let groups = chatInputRunsSplitOnNewlines(source)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(self.described(groups[0]), ["one|-"])
        XCTAssertEqual(self.described(groups[1]), ["tw|-", "o|b"])
        XCTAssertEqual(self.described(groups[2]), ["three|-"])
    }

    /// An empty line between two newlines must survive as an empty group — it becomes an empty paragraph.
    func test_splitOnNewlines_keepsEmptyLines() {
        let source = self.runs([("a\n\nb", ChatInputInlineAttributes())])
        let groups = chatInputRunsSplitOnNewlines(source)
        XCTAssertEqual(groups.count, 3)
        XCTAssertTrue(groups[1].isEmpty)
    }

    func test_splitOnNewlines_withoutNewlines_isOneGroup() {
        XCTAssertEqual(chatInputRunsSplitOnNewlines(self.runs([("abc", ChatInputInlineAttributes())])).count, 1)
        XCTAssertEqual(chatInputRunsSplitOnNewlines([]).count, 1, "no runs is still one (empty) line")
    }
}

/// `replacingFlatRange` when both ends land in one block. This is the case every autocomplete panel
/// hits, and the one the old flat rebuild destroyed: the range covers a word, and everything else in
/// the composer — headings, lists, quotes, tables — has to come out untouched.
final class ChatInputContentSameBlockReplaceTests: XCTestCase {
    private func para(_ text: String, style: ChatInputParagraphStyle = .body,
                      list: ChatInputListMembership? = nil) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, list: list,
                                             runs: text.isEmpty ? [] : [ChatInputRun(text: text)]))
    }

    private func plainRuns(_ text: String) -> [ChatInputRun] {
        return [ChatInputRun(text: text)]
    }

    private func styles(_ content: ChatInputContent) -> [ChatInputParagraphStyle?] {
        return content.blocks.map { if case let .paragraph(p) = $0 { return p.style } else { return nil } }
    }

    /// THE reported scenario: a heading above, replace a word in the body paragraph below.
    func test_replacingAWord_leavesEveryOtherBlockUntouched() {
        let content = ChatInputContent(blocks: [
            self.para("Title", style: .heading1),
            self.para("hello @ali there")
        ])
        // "Title\nhello @ali there" — "@ali" occupies flat [12, 16).
        let result = content.replacingFlatRange(NSRange(location: 12, length: 4), with: self.plainRuns("@alice "))

        XCTAssertEqual(self.styles(result.content), [.heading1, .body], "the heading must survive")
        XCTAssertEqual(result.content.plainText, "Title\nhello @alice  there")
        XCTAssertEqual(result.caret, 19, "caret sits just past the inserted text")
    }

    /// A list paragraph keeps its membership; only the runs change.
    func test_replacingInsideAListItem_keepsTheListMembership() {
        let content = ChatInputContent(blocks: [
            self.para("abc", list: ChatInputListMembership(marker: .bullet, level: 0))
        ])
        let result = content.replacingFlatRange(NSRange(location: 1, length: 1), with: self.plainRuns("X"))

        guard case let .paragraph(p) = result.content.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "aXc")
        XCTAssertEqual(p.list?.marker, .bullet)
    }

    /// An expanded quote's interior is its own flat axis — the primitive recurses into it.
    func test_replacingInsideAnExpandedQuote_staysInsideTheQuote() {
        let content = ChatInputContent(blocks: [
            self.para("Title", style: .heading1),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [self.para("quoted abc")]),
                                            collapsed: false))
        ])
        // "Title\nquoted abc" — "abc" is at flat [13, 16).
        let result = content.replacingFlatRange(NSRange(location: 13, length: 3), with: self.plainRuns("xyz"))

        guard case let .blockQuote(quote) = result.content.blocks[1],
              case let .paragraph(inner) = quote.content.blocks[0] else {
            return XCTFail("the quote must survive as a quote")
        }
        XCTAssertEqual(inner.text, "quoted xyz")
        XCTAssertEqual(self.styles(result.content).first, .heading1)
    }

    /// A collapsed quote's " " placeholder stands for off-string content; splicing into it would
    /// corrupt the quote, so the primitive refuses.
    func test_rangeInsideACollapsedQuotePlaceholder_isANoOp() {
        let inner = ChatInputContent(blocks: [self.para("folded")])
        let content = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: inner, collapsed: true))])
        let result = content.replacingFlatRange(NSRange(location: 0, length: 1), with: self.plainRuns("X"))
        XCTAssertEqual(result.content, content)
    }

    /// Empty runs is a deletion — the clear button's path, no separate API.
    func test_emptyRuns_deletes() {
        let content = ChatInputContent(blocks: [self.para("abcdef")])
        let result = content.replacingFlatRange(NSRange(location: 2, length: 2), with: [])
        XCTAssertEqual(result.content.plainText, "abef")
        XCTAssertEqual(result.caret, 2)
    }

    /// A "\n" in the replacement splits a PARAGRAPH host into siblings, each keeping its style.
    func test_newlineInReplacement_splitsAParagraphHost() {
        let content = ChatInputContent(blocks: [self.para("ad", style: .heading2)])
        let result = content.replacingFlatRange(NSRange(location: 1, length: 0), with: self.plainRuns("b\nc"))

        XCTAssertEqual(self.styles(result.content), [.heading2, .heading2])
        XCTAssertEqual(result.content.plainText, "ab\ncd")
        XCTAssertEqual(result.caret, 4, "the flat axis counts the separator, so caret == lo + inserted length")
    }

    /// A code block carries interior newlines as ordinary characters, so it must NOT split.
    func test_newlineInReplacement_staysInlineInACodeBlock() {
        let content = ChatInputContent(blocks: [.code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "ad")]))])
        let result = content.replacingFlatRange(NSRange(location: 1, length: 0), with: self.plainRuns("b\nc"))

        XCTAssertEqual(result.content.blocks.count, 1, "the code block must not shatter")
        guard case let .code(code) = result.content.blocks[0] else { return XCTFail() }
        XCTAssertEqual(code.text, "ab\ncd")
        XCTAssertEqual(code.language, "swift")
    }

    func test_outOfRangeIsClamped() {
        let content = ChatInputContent(blocks: [self.para("abc")])
        let result = content.replacingFlatRange(NSRange(location: 99, length: 99), with: self.plainRuns("X"))
        XCTAssertEqual(result.content.plainText, "abcX")
        XCTAssertEqual(result.caret, 4)
    }

    func test_emptyContent_isANoOp() {
        let content = ChatInputContent()
        let result = content.replacingFlatRange(NSRange(location: 0, length: 0), with: self.plainRuns("X"))
        XCTAssertEqual(result.content, content)
    }
}

/// `replacingFlatRange` when the range spans a block boundary — translate, paste-over-selection, and
/// the clear button. The head and tail merge into one block carrying the HEAD's style, everything
/// flat-participating between them drops, and off-axis blocks (which a flat range provably never
/// addressed) survive.
final class ChatInputContentCrossBlockReplaceTests: XCTestCase {
    private func para(_ text: String, style: ChatInputParagraphStyle = .body) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, runs: text.isEmpty ? [] : [ChatInputRun(text: text)]))
    }

    private func plainRuns(_ text: String) -> [ChatInputRun] {
        return [ChatInputRun(text: text)]
    }

    private func styles(_ content: ChatInputContent) -> [ChatInputParagraphStyle?] {
        return content.blocks.map { if case let .paragraph(p) = $0 { return p.style } else { return nil } }
    }

    private func table() -> ChatInputBlock {
        return .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 90)],
                                     rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [ChatInputRun(text: "cell")])])]))
    }

    /// The head's style wins — the documented, visible rule.
    func test_spanningTwoParagraphs_mergesIntoTheHeadsStyle() {
        let content = ChatInputContent(blocks: [self.para("abc", style: .heading1), self.para("def")])
        // "abc\ndef" — from inside the heading to inside the body.
        let result = content.replacingFlatRange(NSRange(location: 2, length: 3), with: self.plainRuns("X"))

        XCTAssertEqual(self.styles(result.content), [.heading1])
        XCTAssertEqual(result.content.plainText, "abXef")
        XCTAssertEqual(result.caret, 3)
    }

    /// Blocks entirely inside the range disappear; blocks outside it do not.
    func test_fullyCoveredBlocksDrop_outerBlocksSurvive() {
        let content = ChatInputContent(blocks: [
            self.para("keep", style: .heading2),
            self.para("aaa"),
            self.para("bbb"),
            self.para("ccc"),
            self.para("tail", style: .heading3)
        ])
        // "keep\naaa\nbbb\nccc\ntail" — from inside "aaa" (6) to inside "ccc" (15).
        let result = content.replacingFlatRange(NSRange(location: 6, length: 9), with: self.plainRuns("-"))

        XCTAssertEqual(self.styles(result.content), [.heading2, .body, .heading3])
        XCTAssertEqual(result.content.plainText, "keep\na-c\ntail")
    }

    /// A table contributes no flat length, so a flat range provably never addressed it. Deleting
    /// content the range could not name would be the worse failure.
    func test_offAxisBlocksBetweenTheEndsSurvive() {
        let content = ChatInputContent(blocks: [self.para("abc"), self.table(), self.para("def")])
        let result = content.replacingFlatRange(NSRange(location: 2, length: 3), with: self.plainRuns("X"))

        XCTAssertEqual(result.content.blocks.count, 2)
        XCTAssertEqual(result.content.plainText, "abXef")
        guard case .table = result.content.blocks[1] else {
            return XCTFail("the table must survive, following the merged block")
        }
    }

    /// Translate's case: a two-paragraph selection replaced by two paragraphs of translation.
    func test_newlineInReplacement_splitsTheMergedParagraph() {
        let content = ChatInputContent(blocks: [self.para("abc"), self.para("def")])
        let result = content.replacingFlatRange(NSRange(location: 1, length: 5), with: self.plainRuns("X\nY"))

        XCTAssertEqual(result.content.blocks.count, 2)
        XCTAssertEqual(result.content.plainText, "aX\nYf")
        XCTAssertEqual(result.caret, 4)
    }

    /// The clear button: a spanning deletion joins the two halves.
    func test_emptyRunsAcrossABreak_joinsTheParagraphs() {
        let content = ChatInputContent(blocks: [self.para("abc"), self.para("def")])
        let result = content.replacingFlatRange(NSRange(location: 1, length: 5), with: [])

        XCTAssertEqual(result.content.blocks.count, 1)
        XCTAssertEqual(result.content.plainText, "af")
        XCTAssertEqual(result.caret, 1)
    }

    /// Accepted limitation: a quote endpoint is refused, not corrupted. Silently doing nothing is
    /// reportable; silently flattening the document is what this whole change exists to stop.
    func test_quoteAtEitherEnd_isANoOp() {
        let quote = ChatInputBlock.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [self.para("quoted")]), collapsed: false))

        let headIsQuote = ChatInputContent(blocks: [quote, self.para("def")])
        XCTAssertEqual(headIsQuote.replacingFlatRange(NSRange(location: 2, length: 6), with: self.plainRuns("X")).content,
                       headIsQuote)

        let tailIsQuote = ChatInputContent(blocks: [self.para("abc"), quote])
        XCTAssertEqual(tailIsQuote.replacingFlatRange(NSRange(location: 1, length: 5), with: self.plainRuns("X")).content,
                       tailIsQuote)
    }
}

/// The `NSAttributedString` → `[ChatInputRun]` converter, lifted out of `chatInputContent(from:)` so
/// the chat-attribute vocabulary is defined once. The state-layer `replacingFlatRange` is its only
/// other caller today.
final class ChatInputRunsFromAttributedStringTests: XCTestCase {
    func test_convertsInlineAttributes() {
        let string = NSMutableAttributedString(string: "ab")
        string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 1))
        let runs = chatInputRuns(fromAttributedString: string)
        XCTAssertEqual(runs.count, 2)
        XCTAssertTrue(runs[0].attributes.bold)
        XCTAssertFalse(runs[1].attributes.bold)
    }

    func test_convertsCustomEmojiEntity() throws {
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 7, file: nil)
        let string = NSAttributedString(string: "\u{FFFC}", attributes: [ChatTextInputAttributes.customEmoji: attribute])
        let runs = chatInputRuns(fromAttributedString: string)
        guard case let .customEmoji(fileId, _, _) = try XCTUnwrap(runs.first).attributes.entity else {
            return XCTFail("expected a customEmoji entity")
        }
        XCTAssertEqual(fileId, 7)
    }

    func test_convertsMentionEntity() throws {
        let peerId = EnginePeer.Id(3)
        let string = NSAttributedString(string: "Name", attributes: [
            ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peerId)
        ])
        guard case let .mention(resolved) = try XCTUnwrap(chatInputRuns(fromAttributedString: string).first).attributes.entity else {
            return XCTFail("expected a mention entity")
        }
        XCTAssertEqual(resolved, peerId)
    }

    /// A "\n" is carried inside a run — splitting into blocks is `replacingFlatRange`'s job, and only
    /// it knows whether the host is a paragraph (splits) or a code block (does not).
    func test_newlineStaysInsideARun() {
        XCTAssertEqual(chatInputRuns(fromAttributedString: NSAttributedString(string: "a\nb")).map(\.text).joined(), "a\nb")
    }

    func test_rangeOverloadConvertsOnlyThatRange() {
        let runs = chatInputRuns(fromAttributedString: NSAttributedString(string: "abcdef"), in: NSRange(location: 2, length: 2))
        XCTAssertEqual(runs.map(\.text).joined(), "cd")
    }

    func test_emptyStringYieldsNoRuns() {
        XCTAssertEqual(chatInputRuns(fromAttributedString: NSAttributedString(string: "")).count, 0)
    }
}

/// `insertText` used to copy the `.block` quote attribute onto its replacement so inserted text
/// inherited the quote. Splicing into the quote's own content does that by construction — this is
/// the test that makes "the hack is now unnecessary" a checked claim rather than an assumption.
final class ChatInputContentInsertIntoQuoteTests: XCTestCase {
    private func para(_ text: String) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, runs: text.isEmpty ? [] : [ChatInputRun(text: text)]))
    }

    func test_insertingInsideAQuote_staysQuotedWithoutAnyAttributeCopying() {
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [self.para("quoted")]),
                                            collapsed: false))
        ])
        let result = content.replacingFlatRange(NSRange(location: 3, length: 0),
                                                with: [ChatInputRun(text: "XY")])

        guard case let .blockQuote(quote) = result.content.blocks[0],
              case let .paragraph(inner) = quote.content.blocks[0] else {
            return XCTFail("still one quote holding one paragraph")
        }
        XCTAssertEqual(inner.text, "quoXYted")
        XCTAssertEqual(result.content.blocks.count, 1)
    }
}
