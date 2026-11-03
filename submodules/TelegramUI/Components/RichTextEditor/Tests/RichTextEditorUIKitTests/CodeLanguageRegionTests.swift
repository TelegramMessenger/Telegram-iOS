#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

/// The code block's language line as an editable leaf region: spans, geometry, regions, read-back.
@available(iOS 13.0, *)
final class CodeLanguageRegionTests: XCTestCase {
    private func makeMapper() -> AttributedStringMapper { AttributedStringMapper() }

    /// Same construction the existing `CodeBlockEditingTests` uses.
    func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }

    private func makeBox(language: String?, code: String, width: CGFloat = 300) -> CodeBlockBox {
        let box = CodeBlockBox(code: CodeBlock(id: BlockID("c"), language: language, runs: [TextRun(text: code)]),
                               mapper: makeMapper(), width: width)
        box.frame = CGRect(x: 0, y: 0, width: width, height: box.height)
        return box
    }

    // The box's token contribution must equal what DocumentTree computes for the same block, or the
    // canvas's span math and the model's position math disagree and every caret past this block is off.
    func test_nodeSize_matchesDocumentTree() {
        let block = CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])
        let box = CodeBlockBox(code: block, mapper: makeMapper(), width: 300)
        XCTAssertEqual(box.nodeSize, DocumentTree.documentSize(Document(blocks: [.code(block)])))
    }

    // Regions are in DOCUMENT order — navigation indexes allLeafRegions() positionally, so the language
    // line (which is drawn above the code) must be index 0.
    func test_leafRegions_areLanguageThenCodeInDocumentOrder() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].ref, .codeLanguage(BlockID("c")))
        XCTAssertEqual(regions[0].globalStart, box.nodeStart + 1)   // the container's first child's text
        XCTAssertEqual(regions[0].length, 5)
        XCTAssertEqual(regions[1].ref, .code(BlockID("c")))
        // language text (lang) + its close token + the code paragraph's open token → +3, mirroring
        // PullQuoteBox's author at `nodeStart + length + 3`.
        XCTAssertEqual(regions[1].globalStart, box.nodeStart + box.languageLength + 3)
        XCTAssertEqual(regions[1].globalStart, box.textStart)
    }

    // textStart/textLength/textRef stay the CODE region — the activeStack guard depends on it.
    func test_primaryRegionIsStillTheCode() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        XCTAssertEqual(box.textRef, .code(BlockID("c")))
        XCTAssertEqual(box.textLength, 2)
    }

    // The line is ALWAYS shown: an empty language still reserves its line, so the box is taller than the
    // code alone. (Consequence: a language-less block is ~1 line taller in the editor than the rendered
    // message, which draws no language line. Accepted — see the design doc.)
    func test_emptyLanguage_stillReservesItsLine() {
        let withLanguage = makeBox(language: "swift", code: "ab")
        let without = makeBox(language: nil, code: "ab")
        XCTAssertEqual(without.height, withLanguage.height, accuracy: 0.5)
        XCTAssertGreaterThan(without.languageLineExtent, 0)
        XCTAssertEqual(without.textOrigin.y - without.frame.minY,
                       without.topInset + without.languageLineExtent, accuracy: 0.01)
    }

    // A tap on the language line resolves into the language region, so the "Language" placeholder is
    // directly tappable; a tap on the code resolves into the code.
    func test_tapRoutesToTheRegionUnderTheFinger() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        let inLanguage = CGPoint(x: box.languageOrigin.x + 1, y: box.languageOrigin.y + 1)
        let inCode = CGPoint(x: box.textOrigin.x + 1, y: box.textOrigin.y + 1)
        XCTAssertLessThan(box.closestPosition(toCanvasPoint: inLanguage), box.textStart)
        XCTAssertGreaterThanOrEqual(box.closestPosition(toCanvasPoint: inCode), box.textStart)
    }

    // Read-back: as-typed casing survives, surrounding whitespace is trimmed, empty becomes nil.
    func test_currentCode_readsTheLanguageBackAsTyped() {
        let box = makeBox(language: "Swift", code: "ab")
        XCTAssertEqual(box.currentCode().language, "Swift")
    }

    func test_currentCode_trimsAndNilsAnEmptyLanguage() {
        let box = makeBox(language: "  ", code: "ab")
        XCTAssertNil(box.currentCode().language)
    }

    // THE SILENT-CORRUPTION GUARD. `activeStack` resolves a box by its PRIMARY region; a code box's
    // primary region is its CODE text. A caret in the LANGUAGE line must therefore resolve to nil, exactly
    // as a quote-author caret already does — otherwise every `box is CodeBlockBox` branch would run with a
    // language-relative offset against the code layout.
    func test_caretInLanguageRegion_doesNotResolveToAnActiveStack() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        let languageStart = canvas.boxes[0].nodeStart + 1
        XCTAssertNil(canvas.activeStack(at: languageStart + 1))
        // …while a caret in the CODE text still resolves.
        XCTAssertNotNil(canvas.activeStack(at: canvas.boxes[0].textStart + 1))
    }

    // The consequence that matters: the code-block newline primitive cannot touch the code text while the
    // caret is in the language line.
    func test_insertCodeBlockNewline_isInertInTheLanguageRegion() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 2)
        canvas.insertCodeBlockNewline()
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.text, "let x = 1")
        XCTAssertEqual(code.language, "swift")
    }

    // A container box must NOT start matching at its own nodeStart: the naive `pos >= textStart,
    // pos <= textStart + textLength` form would, because containers report a degenerate
    // `textStart == nodeStart, textLength == 0`, and that position must keep falling through.
    func test_blockQuoteContainer_stillDoesNotResolveAtItsNodeStart() {
        let canvas = makeCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")])),
            ])),
        ])
        XCTAssertNil(canvas.activeStack(at: canvas.boxes[0].nodeStart))
    }

    // The caret is still "in a code block" for menu purposes while it sits in the language line.
    func test_isCodeBlock_isTrueInTheLanguageRegion() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        XCTAssertTrue(canvas.currentState().isCodeBlock)
    }

    func test_typingIntoAnEmptyLanguageLine_landsInTheLanguageNotTheCode() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("s")
        canvas.insertText("h")
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "sh")
        XCTAssertEqual(code.text, "x")
    }

    // The first character typed into an EMPTY language line must inherit the language line's own
    // attributes (bold, body size), not the 17pt body default — otherwise the read-back writes a
    // differently-styled string back into the model.
    func test_firstCharacterInAnEmptyLanguageLine_usesLanguageAttributes() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("s")
        let box = canvas.boxes[0] as! CodeBlockBox
        let typed = box.languageLayout.attributedString.attributes(at: 0, effectiveRange: nil)
        let expected = CodeBlockBox.languageAttributes(mapper: box.mapper)
        XCTAssertEqual(typed[.font] as? UIFont, expected[.font] as? UIFont)
    }

    // A multi-line paste into the language line arrives flattened; interior newlines must not survive
    // into the model (`currentCode()` only trims the edges).
    func test_pastingMultipleLinesIntoTheLanguageKeepsItOneLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("obj\nc")
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "obj c")
        XCTAssertEqual(code.text, "x")
    }

    // Code is identifiers, not prose: iOS would capitalize "let" to "Let" and autocorrect identifiers into
    // English words, in the code text as much as in the language line. All four text-service traits are off
    // in BOTH regions of a code block. (Smart quotes / dashes / insert-delete are already `.no` editor-wide
    // — see `+NativeTextCheckingClient` — so they need no region gating.)
    func test_bothCodeRegionsReportNoTextServiceTraits() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "let x = 1")])),
        ])
        for (name, caret) in [("language line", canvas.boxes[0].nodeStart + 1),
                              ("code text", canvas.boxes[0].textStart + 1)] {
            canvas.setCaret(global: caret)
            XCTAssertEqual(canvas.autocorrectionType, .no, "autocorrect in the \(name)")
            XCTAssertEqual(canvas.autocapitalizationType, .none, "autocapitalization in the \(name)")
            XCTAssertEqual(canvas.spellCheckingType, .no, "spell checking in the \(name)")
            if #available(iOS 17.0, *) {
                XCTAssertEqual(canvas.inlinePredictionType, .no, "inline predictions in the \(name)")
            }
        }
    }

    // CONTROL: ordinary prose keeps every one of them, so the test above is measuring the region and not
    // a globally-disabled trait.
    func test_control_bodyParagraphKeepsItsTextServiceTraits() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hello")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].textStart + 1)
        XCTAssertEqual(canvas.autocorrectionType, .yes)
        XCTAssertEqual(canvas.autocapitalizationType, .sentences)
        XCTAssertEqual(canvas.spellCheckingType, .yes)
        if #available(iOS 17.0, *) {
            XCTAssertEqual(canvas.inlinePredictionType, .yes)
        }
    }

    // Return in the language line moves to the code text. A `.Pre` language has no second line, so it
    // must not insert a newline and must not split the block (this is where it diverges from the quote
    // author, which splits — the author is trailing, the language is leading).
    func test_returnInTheLanguageLineMovesToTheCodeStart() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 3)     // mid-"swift"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart)
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.text, "let x = 1")
        XCTAssertEqual(canvas.boxes.count, 1)
    }

    // Backspace at the START of the language line steps OUT of the block. It must never merge the
    // language into the previous block and never delete a block that still has content.
    func test_backspaceAtLanguageStartStepsOutWithoutDeleting() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[1].nodeStart + 1)
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case let .code(code) = canvas.boxes[1].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart + canvas.boxes[0].textLength)
    }

    // A wholly-empty code block (no language, no code) is still un-made by Backspace at its start —
    // today's empty-code rule, relocated to the block's new FIRST position.
    func test_backspaceAtLanguageStartOfAWhollyEmptyBlockUnmakesIt() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.deleteBackward()
        guard case .paragraph = canvas.boxes[0].currentBlock() else {
            return XCTFail("a wholly-empty code block should un-make to a body paragraph")
        }
    }

    // A code block that is the document's FIRST block has nowhere to step out to — a no-op, not a delete.
    func test_backspaceAtLanguageStartOfALeadingBlockIsANoOp() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.deleteBackward()
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.text, "x")
    }

    // Backspace with text before the caret deletes inside the language line, not in the code.
    func test_backspaceInsideTheLanguageDeletesThere() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1 + 5)   // end of "swift"
        canvas.deleteBackward()
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swif")
        XCTAssertEqual(code.text, "let x = 1")
    }

    func test_characterFormatsAreInertInTheLanguageLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        let box = canvas.boxes[0] as! CodeBlockBox
        canvas.setSelectionForTesting(anchor: box.nodeStart + 1, head: box.nodeStart + 1 + 5)   // all of "swift"
        // COPY: `attributedString` hands back the LIVE storage, so holding the reference and comparing it
        // after the toggle compares the object with itself and passes no matter what happened.
        let before = NSAttributedString(attributedString: box.languageLayout.attributedString)
        canvas.toggleBold()
        canvas.toggleItalic()
        canvas.toggleUnderline()
        canvas.toggleStrikethrough()
        canvas.toggleSpoiler()
        canvas.toggleInlineCode()
        XCTAssertEqual(box.languageLayout.attributedString, before)
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
    }

    func test_emojiInsertionIsInertInTheLanguageLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        let box = canvas.boxes[0] as! CodeBlockBox
        canvas.setCaret(global: box.nodeStart + 1 + 5)
        canvas.insertEmoji(id: "1", altText: "🙂")
        XCTAssertEqual(box.currentCode().language, "swift")
    }

    // CONTROL for the lock-out test above: the same gesture on a BODY paragraph must actually change the
    // layout. Without this, a lock-out test that passes proves nothing — the selection could simply not
    // be taking effect.
    func test_control_characterFormatDoesChangeABodyParagraph() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hello")])),
        ])
        let box = canvas.boxes[0]
        canvas.setSelectionForTesting(anchor: box.textStart, head: box.textStart + 5)
        let before = NSAttributedString(attributedString: box.textLayout.attributedString)
        canvas.toggleBold()
        XCTAssertNotEqual(box.textLayout.attributedString, before)
    }

    // Unlike an empty quote author (which `isEmptyAuthorRegion` makes arrow-unreachable), an EMPTY language
    // line stays navigable: it is always present and always visible, so skipping it would leave it
    // reachable only by tapping. Expected to pass unchanged — `isEmptyAuthorRegion` matches only
    // `.quoteAuthor`.
    func test_arrowKeysEnterAnEmptyLanguageLine() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "a")])),
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        let codeBox = canvas.boxes[1]
        // Stepping right from the end of the paragraph lands in the (empty) language line, not the code.
        let next = canvas.nextTextPosition(after: canvas.boxes[0].textStart + canvas.boxes[0].textLength)
        XCTAssertEqual(next, codeBox.nodeStart + 1)
        XCTAssertLessThan(next, codeBox.textStart)
    }

    // Select-All → Backspace over a lone code block resets the document to one empty body paragraph,
    // language included — the whole-document reset in `applySelectionReplaceOutcome`, which drops all block
    // formatting. Expected to pass unchanged; pinned because the language must not survive that reset.
    func test_selectAllThenDeleteDropsTheCodeBlockAndItsLanguage() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setSelectionForTesting(anchor: 0, head: canvas.documentSize)
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .paragraph(p) = canvas.boxes[0].currentBlock() else {
            return XCTFail("select-all + delete should leave one empty paragraph")
        }
        XCTAssertEqual(p.text, "")
    }

    // A selection covering a code block ENTIRELY, in a multi-block document, drops the whole block —
    // language included — on the cross-block path, where `coverableContentStart` is the box's `nodeStart`
    // and so already spans the LEADING language line. Expected to pass unchanged.
    func test_coveringSelectionDropsTheWholeCodeBlockIncludingItsLanguage() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), style: .body, runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), style: .body, runs: [TextRun(text: "after")])),
        ])
        let from = canvas.boxes[0].textStart + canvas.boxes[0].textLength   // end of "before"
        let to = canvas.boxes[2].textStart                                  // start of "after"
        canvas.setSelectionForTesting(anchor: from, head: to)
        canvas.deleteBackward()
        for box in canvas.boxes {
            if case .code = box.currentBlock() { return XCTFail("the covered code block should be gone") }
        }
    }

    // Typing OVER an entire code block — the selection covers its language line as well as its code —
    // must not leave the old language behind on the block. (The block itself survives, exactly as a
    // heading survives being typed over; it is the language, which the user's selection included, that
    // must go.)
    func test_typingOverAnEntireCodeBlockClearsItsLanguage() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setSelectionForTesting(anchor: 0, head: canvas.documentSize)
        canvas.insertText("z")
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.text, "z")
        XCTAssertNil(code.language, "the selection covered the language line, so it must not survive")
    }

    // A language name must not get spelling underlines — iOS would flag `kotlin` as a misspelling.
    // `spellCheckableRef` puts `.codeLanguage` in its nil arm, exactly where `.code` already sits.
    func test_languageRegionIsNotSpellChecked() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "kotln", runs: [TextRun(text: "x")])),
        ])
        let regions = canvas.allLeafRegions().filter {
            if case .codeLanguage = $0.ref { return true }
            return false
        }
        XCTAssertEqual(regions.count, 1)
        XCTAssertNil(canvas.spellCheckableRef(regions[0].ref))
    }

    // Toggling Code OFF drops the language: it is block metadata with no paragraph to live on. The
    // existing `makeCodeBlock` toggle-off path rebuilds paragraphs from `currentCode().text` alone, so
    // this should pass unchanged — the test exists to keep it that way.
    func test_toggleCodeOffDropsTheLanguage() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.makeCodeBlock()
        for box in canvas.boxes {
            if case .code = box.currentBlock() { return XCTFail("the code block should have become paragraphs") }
        }
    }

    // Toggling Code ON leaves the caret in the CODE text, not in the new (empty) language line — you
    // asked for a code block to type code in. `makeCodeBlock` parks the caret at
    // `codeBox.textStart + codeBox.textLength`, and `textStart` is the code region, so this holds.
    func test_toggleCodeOnLeavesTheCaretInTheCodeText() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.makeCodeBlock()
        let box = canvas.boxes[0]
        XCTAssertGreaterThanOrEqual(canvas.head, box.textStart)
        XCTAssertEqual(box.textRef, .code(box.id))
    }

    // iOS delivers a backspace inside the language line as a RANGE covering the character to remove, not
    // as a collapsed caret. That range resolves to no `activeStack` (the language is a second region on
    // its box, off that engine's radar, by design), so the top-level replace engine silently returned
    // `.unchanged` — nothing was deleted and the selection iOS had made stayed on screen. That is the
    // "backspace selects the last symbol instead of deleting it" report.
    func test_rangeBackspaceInsideTheLanguageDeletesTheCharacter() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        let languageStart = canvas.boxes[0].nodeStart + 1
        canvas.setSelectionForTesting(anchor: languageStart + 4, head: languageStart + 5)   // the trailing "t"
        canvas.deleteBackward()
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swif")
        XCTAssertEqual(code.text, "let x = 1", "the code text must be untouched")
        XCTAssertEqual(canvas.selFrom, canvas.selTo, "and the selection must collapse, not linger")
    }

    // The same routing gap for a selection REPLACE (type-over, autocorrect, dictation) inside the field.
    func test_typingOverASelectionInsideTheLanguageReplacesIt() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        let languageStart = canvas.boxes[0].nodeStart + 1
        canvas.setSelectionForTesting(anchor: languageStart, head: languageStart + 5)   // all of "swift"
        canvas.insertText("rb")
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "rb")
    }
}
#endif
