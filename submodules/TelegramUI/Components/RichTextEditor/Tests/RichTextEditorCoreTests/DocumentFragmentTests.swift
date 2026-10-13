// Tests/RichTextEditorCoreTests/DocumentFragmentTests.swift
import XCTest
@testable import RichTextEditorCore

final class DocumentFragmentTests: XCTestCase {
    func para(_ id: String, _ t: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, runs: [TextRun(text: t)]))
    }
    func doc(_ blocks: Block...) -> Document { Document(blocks: blocks) }

    func test_nearestTopLevelTextPosition_clampsOutOfRangeCaret_nilInsideRange() {
        // "ab" paragraph: text occupies globals 1...3 (textStart 1, len 2).
        let d = doc(para("p", "ab"))
        XCTAssertEqual(d.nearestTopLevelTextPosition(to: 0), 1, "caret 0 (below first text start) → 1")
        XCTAssertNil(d.nearestTopLevelTextPosition(to: 1), "caret already at a text locus → nil (no clamp)")
        XCTAssertNil(d.nearestTopLevelTextPosition(to: 2), "interior caret → nil")
        XCTAssertEqual(d.nearestTopLevelTextPosition(to: 99), 3, "caret past the last text end → clamps to it")

        // A lone table has no top-level text block: every caret → nil (caller flattens).
        let tableDoc = doc(.table(TableBlock(id: .generate(), columns: [ColumnSpec(width: 90)],
            rows: [Row(id: .generate(), cells: [Cell(id: .generate(),
                blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "x")]))])])])))
        XCTAssertNil(tableDoc.nearestTopLevelTextPosition(to: 0))
    }

    // Pasting a copied table must NOT reuse the source table's BlockIDs — block views are keyed by BlockID,
    // so a duplicate-ID paste steals the original's view and the original table disappears. `regeneratingIDs`
    // (used by every paste via `insertingFragment`) must therefore recurse into tables: table + rows + cells +
    // nested blocks all get fresh IDs. (It previously fell through `default` and passed tables through unchanged.)
    func test_regeneratingTopLevelIDs_regeneratesTableAndNestedIDs() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 90)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [Cell(id: BlockID("a"), blocks: [para("ap", "x")])])])
        let regen = Document(blocks: [.table(table)]).regeneratingTopLevelIDs()
        guard case .table(let t2) = regen.blocks[0] else { return XCTFail("still a table") }
        XCTAssertNotEqual(t2.id, BlockID("t"), "table id regenerated")
        XCTAssertNotEqual(t2.rows[0].id, BlockID("r0"), "row id regenerated")
        XCTAssertNotEqual(t2.rows[0].cells[0].id, BlockID("a"), "cell id regenerated")
        guard case .paragraph(let p) = t2.rows[0].cells[0].blocks[0] else { return XCTFail("cell keeps its paragraph") }
        XCTAssertNotEqual(p.id, BlockID("ap"), "nested paragraph id regenerated")
        // Structure/content preserved.
        XCTAssertTrue(t2.rows[0].isHeader)
        XCTAssertEqual(p.text, "x")
    }

    func test_regeneratingTopLevelIDs_regeneratesMediaBlockID_keepsContentKey() {
        let media = MediaBlock(id: BlockID("m"), mediaID: "content-key", naturalSize: Size2D(width: 100, height: 100))
        let regen = Document(blocks: [.media(media)]).regeneratingTopLevelIDs()
        guard case .media(let m2) = regen.blocks[0] else { return XCTFail("still media") }
        XCTAssertNotEqual(m2.id, BlockID("m"), "media block id regenerated")
        XCTAssertEqual(m2.mediaID, "content-key", "content key (mediaID) preserved — it is not a block id")
    }

    func test_tableFlattenedText_rowPerLine_cellsSpaceJoined() {
        let table = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
            rows: [
                Row(id: BlockID("r0"), cells: [
                    Cell(id: BlockID("a"), blocks: [para("ap", "a")]),
                    Cell(id: BlockID("b"), blocks: [para("bp", "b")]),
                ]),
                Row(id: BlockID("r1"), cells: [
                    Cell(id: BlockID("c"), blocks: [para("cp", "c")]),
                    Cell(id: BlockID("d"), blocks: [para("dp", "")]),   // empty cell contributes ""
                ]),
            ])
        XCTAssertEqual(tableFlattenedText(table), ["a b", "c "])
    }

    // Two paragraphs "Hello"(text 1..6) and "World"(text 8..13) on the axis:
    //   p0: open@0, text@1..6 ("Hello"), close@6   -> size 7
    //   p1: open@7, text@8..13 ("World"), close@13 -> size 7
    func twoParas() -> Document { doc(para("a", "Hello"), para("b", "World")) }

    func test_extract_withinOneParagraph_truncatesRuns() {
        let f = twoParas().extractFragment(globalFrom: 2, globalTo: 4)   // "el"
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "el")
    }

    func test_extract_spanningTwoParagraphs_keepsTwoBlocksTruncatedAtEnds() {
        // globalFrom:3 lands on the first 'l' (H@1,e@2,l@3,l@4,o@5); globalTo:10 lands on 'o'@10 in "World" (W@8,o@9,r@10...).
        // Extracting global [3,10) from "Hello" gives local [2,5) = "llo"; from "World" gives local [0,2) = "Wo".
        let f = twoParas().extractFragment(globalFrom: 3, globalTo: 10)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["llo", "Wo"])
    }

    func test_extract_preservesInlineAttributes() {
        let d = doc(.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "AB", attributes: CharacterAttributes(bold: true, link: "https://x")),
        ])))
        let f = d.extractFragment(globalFrom: 1, globalTo: 3)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertTrue(p.runs[0].attributes.bold)
        XCTAssertEqual(p.runs[0].attributes.link, "https://x")
    }

    func test_topLevelTextLocus_resolvesIndexAndLocal() {
        XCTAssertEqual(twoParas().topLevelTextLocus(globalCaret: 9).map { [$0.index, $0.local] }, [1, 1])
    }

    func test_globalTextStart_ofSecondBlock() {
        XCTAssertEqual(twoParas().globalTextStart(ofBlockAt: 1), 8)
    }

    // Axis for [AB][empty][CD]: p_a open@0,A@1,B@2,close@3; p_e open@4,(empty)@5,close@5; p_c open@6,C@7,D@8,close@9.
    func emptyMiddle() -> Document { doc(para("a", "AB"), para("e", ""), para("c", "CD")) }

    func test_extract_emptyParagraphAtExclusiveEnd_isNotCaptured() {
        // [1,5): covers "AB" but STOPS before the blank line's position (5) — half-open excludes it.
        let f = emptyMiddle().extractFragment(globalFrom: 1, globalTo: 5)
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "AB")
    }

    func test_extract_emptyParagraphStrictlyInside_isCaptured() {
        // [1,8): covers "AB", the blank line (pos 5 < 8), and into "CD".
        let f = emptyMiddle().extractFragment(globalFrom: 1, globalTo: 8)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["AB", "", "C"])
    }

    func test_extract_emptyRange_returnsEmptyDocument() {
        XCTAssertTrue(twoParas().extractFragment(globalFrom: 4, globalTo: 4).blocks.isEmpty)
    }

    // MARK: - Block-quote extraction (I3)

    /// A block quote containing one paragraph "hi".
    func blockQuoteDoc() -> Document {
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                            collapsed: false)
        return Document(blocks: [.blockQuote(bq)])
    }

    func test_extract_blockQuote_fullyCovered_capturesBlock() {
        // A document consisting of exactly one block quote. Selecting the whole document [0, size)
        // must extract a fragment containing that block quote.
        let d = blockQuoteDoc()
        let size = DocumentTree.documentSize(d)
        let f = d.extractFragment(globalFrom: 0, globalTo: size)
        XCTAssertEqual(f.blocks.count, 1, "one block quote should be captured")
        guard case .blockQuote(let bq) = f.blocks[0] else { return XCTFail("extracted block is not a block quote") }
        XCTAssertFalse(bq.collapsed)
        XCTAssertEqual(bq.children.count, 1)
    }

    func test_extract_blockQuote_partiallyCovered_isDropped() {
        // Place a paragraph before the block quote. Select only the paragraph — the block quote
        // is NOT fully covered and must be dropped (partial coverage stays dropped).
        let d = Document(blocks: [
            para("a", "AB"),
            .blockQuote(BlockQuote(id: BlockID("q"),
                                   children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                                   collapsed: false))
        ])
        // globalFrom: start of "AB", globalTo: just before the block quote
        let paraSize = DocumentTree.documentSize(Document(blocks: [para("a", "AB")]))
        let f = d.extractFragment(globalFrom: 1, globalTo: paraSize)
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph = f.blocks[0] else { return XCTFail("expected only the paragraph") }
    }

    func test_extract_skipsMediaBlock() {
        let d = Document(blocks: [
            para("a", "AB"),
            .media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10))),
            para("c", "CD"),
        ])
        let f = d.extractFragment(globalFrom: 0, globalTo: 9999)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["AB", "CD"])
    }

    func test_topLevelTextLocus_mediaBlock_returnsNil() {
        let d = Document(blocks: [.media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10)))])
        XCTAssertNil(d.topLevelTextLocus(globalCaret: 1))
    }

    // MARK: - Author forwarding (regeneratingIDs / extractFragment must not silently drop a quote's author)

    func test_regeneratingTopLevelIDs_preservesPullQuoteAuthor() {
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "Ada")])
        let regen = Document(blocks: [.pullQuote(pq)]).regeneratingTopLevelIDs()
        guard case .pullQuote(let r) = regen.blocks[0] else { return XCTFail() }
        XCTAssertNotEqual(r.id, pq.id)
        XCTAssertEqual(r.author.map(\.text).joined(), "Ada")
    }

    func test_regeneratingTopLevelIDs_preservesBlockQuoteAuthor() {
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                            collapsed: false,
                            author: [TextRun(text: "Grace")])
        let regen = Document(blocks: [.blockQuote(bq)]).regeneratingTopLevelIDs()
        guard case .blockQuote(let r) = regen.blocks[0] else { return XCTFail() }
        XCTAssertNotEqual(r.id, bq.id)
        XCTAssertEqual(r.author.map(\.text).joined(), "Grace")
    }

    func test_extract_blockQuote_fullyCovered_preservesAuthor() {
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                            collapsed: false,
                            author: [TextRun(text: "Grace")])
        let d = Document(blocks: [.blockQuote(bq)])
        let size = DocumentTree.documentSize(d)
        let f = d.extractFragment(globalFrom: 0, globalTo: size)
        guard case .blockQuote(let got) = f.blocks[0] else { return XCTFail("extracted block is not a block quote") }
        XCTAssertEqual(got.author.map(\.text).joined(), "Grace")
    }

    func test_extract_pullQuote_fullTextCapture_preservesAuthor() {
        // Whole pull TEXT captured (the author sits off the flat text axis) → author carries over.
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "Ada")])
        let d = Document(blocks: [.pullQuote(pq)])
        let f = d.extractFragment(globalFrom: 2, globalTo: 6)   // pull text is at global [2, 6) (container open 0, pullPara open 1)
        guard case .pullQuote(let got) = f.blocks[0] else { return XCTFail("no pull quote captured") }
        XCTAssertEqual(got.text, "abcd")
        XCTAssertEqual(got.author.map(\.text).joined(), "Ada")
    }

    func test_extract_pullQuote_partialTextCapture_dropsAuthor() {
        // A partial pull-text copy carries no author — it's off the flat text axis being sliced.
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "Ada")])
        let d = Document(blocks: [.pullQuote(pq)])
        let f = d.extractFragment(globalFrom: 3, globalTo: 5)   // partial: "bc" only (pull text at [2,6))
        guard case .pullQuote(let got) = f.blocks[0] else { return XCTFail("no pull quote captured") }
        XCTAssertEqual(got.text, "bc")
        XCTAssertEqual(got.author, [])
    }

    func test_extract_pullQuote_positionAxisIsCursorPlus2_forFullAndPartialCapture() {
        // Regression: after Task 2 a pull quote maps to a `.blockQuote` container [pullPara, authorPara],
        // so its pull text starts at cursor + 2 (container open + pullPara open), NOT the shared cursor + 1.
        // For a lone pull quote that global range is [2, 6): container open 0, pullPara open 1, text 2..6.
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "Ann")])
        let d = Document(blocks: [.pullQuote(pq)])
        // (1) full text captured ⇒ author carried.
        let full = d.extractFragment(globalFrom: 2, globalTo: 6)
        guard case .pullQuote(let gotFull) = full.blocks[0] else { return XCTFail("full: no pull quote captured") }
        XCTAssertEqual(gotFull.text, "abcd")
        XCTAssertEqual(gotFull.author.map(\.text).joined(), "Ann")
        // (2) partial text captured ⇒ no author.
        let partial = d.extractFragment(globalFrom: 3, globalTo: 5)
        guard case .pullQuote(let gotPartial) = partial.blocks[0] else { return XCTFail("partial: no pull quote captured") }
        XCTAssertEqual(gotPartial.text, "bc")
        XCTAssertEqual(gotPartial.author, [])
    }

    // MARK: - Task 3: insertingFragment tests

    func code(_ id: String, _ t: String) -> Block { .code(CodeBlock(id: BlockID(id), runs: [TextRun(text: t)])) }
    func listItem(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body,
                                  list: ListMembership(marker: .bullet),
                                  runs: t.isEmpty ? [] : [TextRun(text: t)]))
    }

    func test_insert_singleInlineParagraph_mergesAtCaret() {
        // host "Hello" caret after "He" (global 3). Fragment one body paragraph "XX".
        let host = doc(para("a", "Hello"))
        let frag = doc(para("f", "XX"))
        let r = host.insertingFragment(frag, atGlobal: 3)!
        guard case .paragraph(let p) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "HeXXllo")
        XCTAssertEqual(r.caret, 5)               // 3 + len("XX")
        XCTAssertEqual(r.document.blocks.count, 1)
    }

    func test_insert_multiBlock_splitsHostAndMergesEnds() {
        // host "Hello" caret after "He" (3). Fragment two body paragraphs "AA","BB".
        let r = doc(para("a", "Hello")).insertingFragment(doc(para("x", "AA"), para("y", "BB")), atGlobal: 3)!
        let texts = r.document.blocks.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }
        XCTAssertEqual(texts, ["HeAA", "BBllo"])  // first merges head, last merges tail
        // caret at the boundary between the pasted "BB" and the "llo" remainder:
        XCTAssertEqual(r.caret, r.document.globalTextStart(ofBlockAt: 1) + 2)
    }

    func test_insert_leadingListItem_insertsAsOwnBlock() {
        // Fragment [list-item "Q", body "B"] pasted into "Hello" at caret 3.
        // A list item is not inline-mergeable → inserts as its own block; "B" merges into tail "llo".
        let r = doc(para("a", "Hello")).insertingFragment(doc(listItem("q", "Q"), para("b", "B")), atGlobal: 3)!
        XCTAssertEqual(r.document.blocks.count, 3)
        guard case .paragraph(let h) = r.document.blocks[0] else { return XCTFail() }
        guard case .paragraph(let q) = r.document.blocks[1] else { return XCTFail() }
        XCTAssertEqual(h.text, "He")
        XCTAssertNotNil(q.list, "list item survives as its own block")
        XCTAssertEqual(q.text, "Q")
    }

    func test_insert_regeneratesIDs_noCollisionWithHost() {
        // global 6 = end of "Hello" (textStart=1, utf16Count=5, so textStart+utf16Count=6)
        let r = doc(para("a", "Hello")).insertingFragment(doc(para("a", "XX")), atGlobal: 6)!
        // single inline merge keeps host id "a"; ensure the merge didn't duplicate-id anything
        XCTAssertEqual(r.document.blocks.count, 1)
        guard case .paragraph(let p) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "HelloXX")
    }

    func test_insert_emptyFragment_isNoOp() {
        let r = doc(para("a", "Hello")).insertingFragment(Document(blocks: []), atGlobal: 2)!
        XCTAssertEqual(r.caret, 2)
        XCTAssertEqual(r.document, doc(para("a", "Hello")))
    }

    func test_insert_caretNotInTextRegion_returnsNil() {
        // A media-only doc has no top-level paragraph/code text region at caret 1.
        let media = Document(blocks: [.media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10)))])
        XCTAssertNil(media.insertingFragment(doc(para("f", "X")), atGlobal: 1))
    }

    func test_insert_intoCodeBlock_flattensFragmentToText() {
        // A code block is a container of [languagePara, codePara], so its code text starts past the whole
        // language child — derived here rather than hard-coded, since that offset moves with the language.
        let host = Document(blocks: [code("c", "let x")])
        let codeStart = host.globalTextStart(ofBlockAt: 0)
        let frag = doc(para("p", "AA"), para("q", "BB"))   // two paragraphs
        let r = host.insertingFragment(frag, atGlobal: codeStart + 4)!   // caret after "let "
        guard case .code(let c) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(c.text, "let AA\nBBx")   // paragraphs joined by "\n", inserted inline
        XCTAssertEqual(r.caret, codeStart + 4 + ("AA\nBB" as NSString).length)
    }

    func test_insert_intoCodeBlock_keepsCodeBlockIdentity() {
        let host = Document(blocks: [code("c", "ab")])
        let r = host.insertingFragment(doc(para("p", "X")), atGlobal: host.globalTextStart(ofBlockAt: 0) + 2)!
        XCTAssertEqual(r.document.blocks.count, 1)
        XCTAssertEqual(r.document.blocks[0].id, BlockID("c"))
    }

    // MARK: - Spurious-empty-split-half on fragment paste (trailing/leading empty paragraph bug)

    /// A bullet-list paragraph (NOT inline-mergeable → pastes as its own block).
    func bullet(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id),
                                  list: ListMembership(marker: .bullet, level: 0),
                                  runs: t.isEmpty ? [] : [TextRun(text: t)]))
    }

    /// The global caret at the END of the (single-block) document's only paragraph "abc".
    /// Axis: open@0, a@1,b@2,c@3, close@3 → end-of-text caret = 3 (= 1 + utf16Count("abc")).
    func endOfFirstParagraph(_ d: Document) -> Int {
        guard case .paragraph(let p) = d.blocks[0] else { return 0 }
        return d.globalTextStart(ofBlockAt: 0) + p.utf16Count
    }

    /// Helper: the plain texts + list markers of a result document's blocks. `empty` is text-emptiness
    /// (a blank-line paragraph may carry either no runs or one zero-length run — both read as empty).
    private func summarize(_ d: Document) -> [(text: String, isBullet: Bool, empty: Bool)] {
        d.blocks.compactMap { b in
            if case .paragraph(let p) = b {
                return (p.text, p.list?.marker == .bullet, p.text.isEmpty)
            }
            return nil
        }
    }

    // CASE 1 — paste a bullet list at the END of "abc" → ["abc", bullet-a, bullet-b] (3 blocks, no trailing empty).
    func test_insert_bulletListAtParagraphEnd_noTrailingEmpty() {
        let host = doc(para("h", "abc"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 3, "expected 3 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abc", "a", "b"])
        XCTAssertTrue(s[1].isBullet && s[2].isBullet)
        XCTAssertFalse(s.last!.empty, "the host's empty tail must not survive as a trailing empty paragraph")
    }

    // CASE 2 — paste a SINGLE bullet at the end of "abc" → ["abc", bullet-a] (2 blocks, no trailing empty).
    func test_insert_singleBulletAtParagraphEnd_noTrailingEmpty() {
        let host = doc(para("h", "abc"))
        let r = host.insertingFragment(doc(bullet("x", "a")), atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 2, "expected 2 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abc", "a"])
        XCTAssertTrue(s[1].isBullet)
    }

    // CASE 3 — paste a bullet list into an EMPTY doc (one empty body paragraph, caret 0) → [bullet-a, bullet-b]
    // (no leading and no trailing empty).
    func test_insert_bulletListIntoEmptyDoc_noLeadingOrTrailingEmpty() {
        let host = doc(para("h", ""))   // empty body paragraph, caret at global 1 (start of its text)
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: 1)!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 2, "expected 2 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["a", "b"])
        XCTAssertTrue(s[0].isBullet && s[1].isBullet)
    }

    // CASE 4 — plain-text-style fragment ["X", empty body] (a "X\n") at end of "abc" → ["abcX"] (the empty body must not survive).
    func test_insert_plainTextTrailingEmpty_dropsTheEmptyBody() {
        let host = doc(para("h", "abc"))
        let frag = doc(para("x", "X"), para("e", ""))   // "X\n"
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 1, "expected 1 block, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abcX"])
    }

    // CASE 5a — PRESERVE: paste a bullet list in the MIDDLE of "ab|cd" → ["ab", bullet-a, bullet-b, "cd"].
    func test_insert_bulletListMidParagraph_preservesNonEmptyTail() {
        // host "abcd" caret after "ab": axis open@0,a@1,b@2,c@3,d@4 → caret global = 3.
        let host = doc(para("h", "abcd"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: 3)!
        let s = summarize(r.document)
        XCTAssertEqual(s.map { $0.text }, ["ab", "a", "b", "cd"])
        XCTAssertTrue(s[1].isBullet && s[2].isBullet)
        XCTAssertFalse(s[3].isBullet)
    }

    // CASE 5b — PRESERVE: paste body ["A","B"] at end of "abc" → ["abcA", "B"] (2 blocks).
    func test_insert_bodyAtParagraphEnd_inlineMergesBothEnds() {
        let host = doc(para("h", "abc"))
        let r = host.insertingFragment(doc(para("x", "A"), para("y", "B")), atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(s.map { $0.text }, ["abcA", "B"])
    }

    // CASE 5c — PRESERVE: an INTERIOR empty body paragraph in a fragment ["A", empty, "B"] is preserved.
    func test_insert_interiorEmptyParagraph_isPreserved() {
        let host = doc(para("h", "abc"))
        let frag = doc(para("x", "A"), para("e", ""), para("y", "B"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        // "A" inline-merges into head "abc" → "abcA"; interior empty kept; "B" merges into empty tail → "B".
        XCTAssertEqual(s.map { $0.text }, ["abcA", "", "B"])
        XCTAssertTrue(s[1].empty, "the interior empty paragraph must be preserved")
    }

    // CASE 6 — CARET: after pasting the bullet list at the end of "abc", caret is at the END of bullet-b,
    // not inside a trailing empty paragraph.
    func test_insert_bulletListAtParagraphEnd_caretAtEndOfLastPastedBlock() {
        let host = doc(para("h", "abc"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        // bullet-b is the last block (index 2). Its end caret = globalTextStart(2) + utf16Count("b").
        let bulletBIndex = r.document.blocks.count - 1
        guard case .paragraph(let last) = r.document.blocks[bulletBIndex] else { return XCTFail() }
        XCTAssertEqual(last.text, "b")
        XCTAssertEqual(r.caret, r.document.globalTextStart(ofBlockAt: bulletBIndex) + last.utf16Count)
    }

    // MARK: - Pull-quote paste caret (a pull quote's first-text offset is cursor + 2, not + 1)

    // CASE 7 — paste a pull quote at the END of "abc" (the empty host tail is dropped, like the bullet-list
    // CASE 6 above) → the caret must land at the TRUE end of the pasted pull TEXT, not one UTF-16 unit short.
    // A pull quote is a `.blockQuote(children: [pullTextPara, authorPara])` container (`DocumentTree.node(for:)`),
    // so its pull text is nested one level deeper than a plain paragraph/code block's text.
    func test_insert_pullQuoteAtParagraphEnd_caretAtTrueEndOfPastedPullText() {
        let host = doc(para("h", "abc"))
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "wisdom")], author: [TextRun(text: "Ada")])
        let frag = Document(blocks: [.pullQuote(pq)])
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        XCTAssertEqual(r.document.blocks.count, 2, "the empty host tail must be dropped, leaving [abc, pullQuote]")
        guard case .pullQuote(let pasted) = r.document.blocks[1] else { return XCTFail("expected a pasted pull quote") }
        XCTAssertEqual(pasted.text, "wisdom")
        // The true end of the pull text = its globalTextStart (container-open + pullPara-open = +2) + its length.
        let expectedCaret = r.document.globalTextStart(ofBlockAt: 1) + pasted.utf16Count
        XCTAssertEqual(r.caret, expectedCaret)
        // Pin the absolute value too, so a regression in `globalTextStart` itself can't cancel out against
        // the relative assertion above: host "abc" is nodeSize 5 (open@0, text@1..4, close@4); the pull
        // quote's container opens @5, its pull-text paragraph opens @6, so the pull text itself starts @7;
        // "wisdom" is 6 UTF-16 units → true end-of-text caret is 13.
        XCTAssertEqual(r.caret, 13)
    }

    // Task 1: block-carrying extraction (AI-edit-on-selection).
    private func mediaBlock(_ id: String) -> Block {
        .media(MediaBlock(id: BlockID(id), mediaID: "content-\(id)", naturalSize: Size2D(width: 100, height: 100)))
    }
    private func table1(_ id: String, _ cellText: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 90)],
            rows: [Row(id: BlockID(id + "r"), cells: [Cell(id: BlockID(id + "c"),
                blocks: [para(id + "cp", cellText)])])]))
    }

    func test_extract_default_dropsMediaAndTable() {
        let d = doc(para("a", "A"), mediaBlock("m"), table1("t", "x"), para("b", "B"))
        let size = DocumentTree.documentSize(d)
        let f = d.extractFragment(globalFrom: 0, globalTo: size)   // default carryingNonTextBlocks == false
        XCTAssertEqual(f.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }, ["A", "B"])
        XCTAssertFalse(f.blocks.contains { if case .media = $0 { return true } else { return false } }, "media dropped by default")
        XCTAssertFalse(f.blocks.contains { if case .table = $0 { return true } else { return false } }, "table dropped by default")
    }

    func test_extract_carrying_capturesFullyCoveredMediaAndTable_freshIDs() {
        let d = doc(para("a", "A"), mediaBlock("m"), table1("t", "x"), para("b", "B"))
        let size = DocumentTree.documentSize(d)
        let f = d.extractFragment(globalFrom: 0, globalTo: size, carryingNonTextBlocks: true)
        XCTAssertEqual(f.blocks.count, 4, "A, media, table, B all carried")
        guard case .media(let m) = f.blocks[1] else { return XCTFail("media carried") }
        XCTAssertNotEqual(m.id, BlockID("m"), "carried media gets a fresh block id")
        XCTAssertEqual(m.mediaID, "content-m", "content key preserved")
        guard case .table(let t) = f.blocks[2] else { return XCTFail("table carried") }
        XCTAssertNotEqual(t.id, BlockID("t"), "carried table gets a fresh block id")
    }

    func test_extract_carrying_dropsPartiallyCoveredMedia() {
        // A range that starts in "A" and ends ONE position INTO the media's span (so the media is partially,
        // not fully, covered) must still drop the media — only a fully-covered media/table is carried.
        let d = doc(para("a", "A"), mediaBlock("m"), para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))     // media span starts at global aSize
        let mSize = DocumentTree.documentSize(doc(mediaBlock("m")))
        XCTAssertGreaterThan(mSize, 1, "precondition: media spans more than one position, so aSize+1 is strictly inside it")
        let f = d.extractFragment(globalFrom: 1, globalTo: aSize + 1, carryingNonTextBlocks: true)   // ends inside the media
        XCTAssertFalse(f.blocks.contains { if case .media = $0 { return true } else { return false } },
                       "a partially-covered media is not carried even with the flag")
    }

    // Task 2: expand a selection so a partial table/image becomes a whole-block selection, both directions.
    func test_expand_endpointInsideTable_snapsToWholeTable() {
        let d = doc(para("a", "A"), table1("t", "xyz"), para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let tStart = aSize, tEnd = aSize + tSize
        let (lo, hi) = d.expandingRangeOverNonTextBlocks(globalFrom: tStart + 2, globalTo: tEnd - 1)
        XCTAssertEqual(lo, tStart, "lo inside the table snaps down to the table's span start")
        XCTAssertEqual(hi, tEnd, "hi inside the table snaps up to the table's span end")
    }

    func test_expand_endpointInsideMedia_snapsToWholeMedia() {
        let d = doc(para("a", "A"), mediaBlock("m"), para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let mSize = DocumentTree.documentSize(doc(mediaBlock("m")))
        let mStart = aSize, mEnd = aSize + mSize
        let (lo, hi) = d.expandingRangeOverNonTextBlocks(globalFrom: mStart + 1, globalTo: mEnd - 1)
        XCTAssertEqual(lo, mStart)
        XCTAssertEqual(hi, mEnd)
    }

    func test_expand_paragraphEndpoints_untouched() {
        let d = twoParas()   // "Hello"(text 1..6), "World"(text 8..13)
        let (lo, hi) = d.expandingRangeOverNonTextBlocks(globalFrom: 3, globalTo: 10)
        XCTAssertEqual(lo, 3, "a text endpoint is never expanded")
        XCTAssertEqual(hi, 10, "a text endpoint is never expanded")
    }

    func test_expand_wholeBlockAlreadyCovered_isNoOp() {
        let d = doc(para("a", "A"), table1("t", "xyz"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let (lo, hi) = d.expandingRangeOverNonTextBlocks(globalFrom: aSize, globalTo: aSize + tSize)
        XCTAssertEqual(lo, aSize)
        XCTAssertEqual(hi, aSize + tSize)
    }

    func test_expand_mixedEndpoints_onlyTheInBlockEndpointSnaps() {
        // lo is in the first paragraph's text; hi is inside the table → only hi snaps (to the table end), lo stays.
        let d = doc(para("a", "AA"), table1("t", "xyz"))
        let aSize = DocumentTree.documentSize(doc(para("a", "AA")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let (lo, hi) = d.expandingRangeOverNonTextBlocks(globalFrom: 1, globalTo: aSize + 1)   // hi one into the table
        XCTAssertEqual(lo, 1, "text endpoint untouched")
        XCTAssertEqual(hi, aSize + tSize, "the in-table endpoint snaps to the table end")
    }

    // MARK: - replacingRange (AI-edit-on-selection)

    private func texts(_ d: Document) -> [String] {
        d.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }
    private func hasTable(_ d: Document) -> Bool {
        d.blocks.contains { if case .table = $0 { return true } else { return false } }
    }

    func test_replacingRange_withinParagraph_replacesText() {
        let d = doc(para("h", "Hello world"))   // text global [1,12)
        let (out, caret) = d.replacingRange(globalFrom: 7, globalTo: 12, with: doc(para("x", "there")))
        XCTAssertEqual(texts(out), ["Hello there"])
        XCTAssertEqual(caret, 12, "caret at end of the inserted text")
    }

    func test_replacingRange_withinParagraph_interiorReplace() {
        let d = doc(para("h", "Hello"))   // text [1,6)
        let (out, caret) = d.replacingRange(globalFrom: 3, globalTo: 5, with: doc(para("x", "X")))   // replace "ll"
        XCTAssertEqual(texts(out), ["HeXo"])
        XCTAssertEqual(caret, 4, "caret after the inserted X")
    }

    func test_replacingRange_emptyFragment_withinParagraph_deletes() {
        let d = doc(para("h", "Hello world"))
        let (out, _) = d.replacingRange(globalFrom: 6, globalTo: 12, with: Document(blocks: []))
        XCTAssertEqual(texts(out), ["Hello"])
    }

    func test_replacingRange_emptyFragment_crossParagraph_joins() {
        // "AB": open@0, text A@1 B@2, close@3 (size 4). "CD": open@4, text C@5 D@6, close@7.
        // Deleting global [2,6) removes "B", the paragraph break, and "C" → the two paragraphs join to "AD".
        let d = doc(para("a", "AB"), para("b", "CD"))
        let (out, caret) = d.replacingRange(globalFrom: 2, globalTo: 6, with: Document(blocks: []))
        XCTAssertEqual(texts(out), ["AD"], "the two paragraphs join across the deleted break")
        XCTAssertEqual(caret, 2)
    }

    func test_replacingRange_wholeTable_replacedWithParagraph_dropsTable_keepsNeighboursSeparate() {
        let d = doc(para("a", "A"), table1("t", "xyz"), para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let (out, _) = d.replacingRange(globalFrom: aSize, globalTo: aSize + tSize, with: doc(para("n", "N")))
        XCTAssertFalse(hasTable(out), "the whole table is dropped")
        XCTAssertEqual(texts(out), ["A", "N", "B"], "N replaces the table as its own block; A/B stay separate")
    }

    func test_replacingRange_wholeTable_replacedWithEmpty_deletesTable() {
        let d = doc(para("a", "A"), table1("t", "xyz"), para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let (out, _) = d.replacingRange(globalFrom: aSize, globalTo: aSize + tSize, with: Document(blocks: []))
        XCTAssertFalse(hasTable(out), "the whole table is deleted")
        XCTAssertEqual(texts(out), ["A", "B"])
    }

    func test_replacingRange_textThenWholeTable_dropsTable() {
        // Range: from mid-first-paragraph THROUGH the whole table (table at the TRAILING end).
        let d = doc(para("a", "AABB"), table1("t", "xyz"), para("b", "C"))
        let aSize = DocumentTree.documentSize(doc(para("a", "AABB")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let (out, _) = d.replacingRange(globalFrom: 3, globalTo: aSize + tSize, with: doc(para("n", "N")))
        XCTAssertFalse(hasTable(out), "trailing-edge table dropped")
        let joined = texts(out).joined(separator: "|")
        XCTAssertTrue(joined.contains("AA") && joined.contains("N") && joined.contains("C"), "got \(joined)")
        XCTAssertFalse(joined.contains("BB"), "covered tail of the first paragraph is gone: \(joined)")
    }

    func test_replacingRange_wholeTableThenText_dropsTable() {
        // MIRROR orientation (the previously-failing case): table at the LEADING end of a mixed range.
        let d = doc(para("a", "A"), table1("t", "xyz"), para("b", "CCDD"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(doc(table1("t", "xyz")))
        let cTextStart = aSize + tSize + 1   // "CCDD" text start; +2 is after "CC"
        let (out, _) = d.replacingRange(globalFrom: aSize, globalTo: cTextStart + 2, with: doc(para("n", "N")))
        XCTAssertFalse(hasTable(out), "leading-edge table dropped (the mirror orientation)")
        let joined = texts(out).joined(separator: "|")
        XCTAssertTrue(joined.contains("A") && joined.contains("N") && joined.contains("DD"), "got \(joined)")
        XCTAssertFalse(joined.contains("CC"), "covered head of the trailing paragraph is gone: \(joined)")
    }

    // Regression: a boundary at a NON-first paragraph's text start must not merge into the preceding block.
    func test_replacingRange_rewriteWholeSecondParagraph_keepsSeparate() {
        let d = doc(para("a", "A"), para("b", "Hello"))   // "A" [1,2); "Hello" text starts at global 4
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let bText = aSize + 1                              // "Hello" text start
        let (out, _) = d.replacingRange(globalFrom: bText, globalTo: bText + 5, with: doc(para("n", "N")))
        XCTAssertEqual(texts(out), ["A", "N"], "rewriting the 2nd paragraph must not corrupt into [\"AN\"]")
    }

    func test_replacingRange_partialFromSecondParagraphStart_mergesIntoTail() {
        let d = doc(para("a", "A"), para("b", "Hello"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let bText = aSize + 1
        let (out, _) = d.replacingRange(globalFrom: bText, globalTo: bText + 3, with: doc(para("x", "X")))   // replace "Hel"
        XCTAssertEqual(texts(out), ["A", "Xlo"], "fragment folds into the surviving tail of the 2nd paragraph")
    }

    func test_replacingRange_secondParagraphStartThroughFollowingTable_dropsTable() {
        let d = doc(para("a", "A"), para("b", "Hello"), table1("t", "xyz"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let bSize = DocumentTree.documentSize(doc(para("b", "Hello")))
        let bText = aSize + 1
        let (out, _) = d.replacingRange(globalFrom: bText, globalTo: aSize + bSize + DocumentTree.documentSize(doc(table1("t", "xyz"))), with: doc(para("n", "N")))
        XCTAssertFalse(hasTable(out), "the trailing table is dropped")
        XCTAssertEqual(texts(out), ["A", "N"], "2nd paragraph rewritten, table gone, 1st paragraph intact")
    }

    func test_replacingRange_rewriteWholeMiddleParagraph_keepsAllThreeSeparate() {
        // Select the ENTIRE text of the MIDDLE paragraph and replace it → the fragment must stay its own
        // paragraph; neither neighbour may absorb it (symmetric head/tail boundary check).
        let d = doc(para("a", "A"), para("b", "Hello"), para("c", "World"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let bText = aSize + 1                        // "Hello" text start
        let (out, _) = d.replacingRange(globalFrom: bText, globalTo: bText + 5, with: doc(para("n", "N")))
        XCTAssertEqual(texts(out), ["A", "N", "World"], "middle paragraph rewritten; neighbours stay separate")
    }

    // Standard multi-paragraph-delete semantics: the head of the lo-paragraph and the tail of the hi-paragraph
    // MERGE into one paragraph, even when whole blocks (a table) sat between them (all deleted).
    func test_replacingRange_deleteAcrossTable_joinsHeadAndTail() {
        let d = doc(para("a", "aa"), table1("t", "xyz"), para("c", "cc"))   // aa | table | cc
        let aText = 1                                        // "aa" text start
        let cSize = DocumentTree.documentSize(doc(para("c", "cc")))
        let size = DocumentTree.documentSize(d)
        let cTailFrom = size - cSize + 1 + 1                 // one into "cc" (after first "c")
        let (out, _) = d.replacingRange(globalFrom: aText + 1, globalTo: cTailFrom, with: Document(blocks: []))
        XCTAssertFalse(hasTable(out), "the table between the two paragraphs is deleted")
        XCTAssertEqual(texts(out), ["ac"], "head 'a' + tail 'c' merge into one paragraph")
    }

    func test_replacingRange_replaceAcrossTable_joinsWithFragmentBetween() {
        let d = doc(para("a", "aa"), table1("t", "xyz"), para("c", "cc"))
        let aText = 1
        let cSize = DocumentTree.documentSize(doc(para("c", "cc")))
        let size = DocumentTree.documentSize(d)
        let cTailFrom = size - cSize + 1 + 1
        let (out, _) = d.replacingRange(globalFrom: aText + 1, globalTo: cTailFrom, with: doc(para("n", "N")))
        XCTAssertFalse(hasTable(out), "table dropped")
        XCTAssertEqual(texts(out), ["aNc"], "head + fragment + tail collapse into one paragraph")
    }

    func test_replacingRange_deleteAcrossThreeParagraphs_joinsFirstAndLast() {
        let d = doc(para("a", "aa"), para("b", "bb"), para("c", "cc"))
        // Delete from after the first "a" through before the last "c": "a"+break+"bb"+break+"c" removed.
        let bSize = DocumentTree.documentSize(doc(para("b", "bb")))
        let size = DocumentTree.documentSize(d)
        let cTailFrom = size - DocumentTree.documentSize(doc(para("c", "cc"))) + 1 + 1
        let _ = bSize
        let (out, _) = d.replacingRange(globalFrom: 2, globalTo: cTailFrom, with: Document(blocks: []))
        XCTAssertEqual(texts(out), ["ac"], "middle paragraph fully removed; first head + last tail join")
    }

    func test_replacingRange_wholeDocument_replacedWithParagraph() {
        let d = doc(para("a", "A"), para("b", "B"))
        let size = DocumentTree.documentSize(d)
        let (out, _) = d.replacingRange(globalFrom: 0, globalTo: size, with: doc(para("n", "New")))
        XCTAssertEqual(texts(out), ["New"])
    }

    func test_regeneratingIDs_preservesPerCellHeaderAndAlignment() {
        var h = Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap")))],
                     horizontalAlignment: .right, verticalAlignment: .bottom)
        h.isHeader = true
        let body = Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp")))])
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                               rows: [Row(id: BlockID("r"), cells: [h, body])])
        let regen = Document(blocks: [.table(table)]).regeneratingTopLevelIDs()
        guard case .table(let out) = regen.blocks[0] else { return XCTFail() }
        XCTAssertTrue(out.rows[0].cells[0].isHeader)
        XCTAssertEqual(out.rows[0].cells[0].horizontalAlignment, .right)
        XCTAssertEqual(out.rows[0].cells[0].verticalAlignment, .bottom)
        XCTAssertFalse(out.rows[0].cells[1].isHeader)
    }
}
