import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// A container must be DELETABLE. Reported from the device: a code block survives Select-All +
/// Backspace, and Backspace inside an empty one does nothing — an undeletable block.
///
/// These drive the real engine (first responder, `selectAll`, `deleteBackward`) rather than calling a
/// helper, because the whole point is what happens on the path UIKit actually takes: the engine owns
/// editing, and the host only sees the change notification afterwards.
@available(iOS 18.4, *)
final class EngineContainerDeletionTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private var containerCount: Int {
        editor.document.blocks.filter {
            if case .code = $0 { return true }
            if case .pullQuote = $0 { return true }
            return false
        }.count
    }

    func test_selectAllThenBackspaceClearsACodeBlock() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])

        editor.engine.selectAll(nil)
        editor.engine.deleteBackward()

        XCTAssertEqual(containerCount, 0,
                       "the code block survived Select-All + Backspace: \(editor.document.blocks)")
    }

    /// The same for a document that is ONLY a code block — the shape left behind after the case above
    /// used to half-work.
    func test_selectAllThenBackspaceClearsALoneCodeBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])

        editor.engine.selectAll(nil)
        editor.engine.deleteBackward()

        XCTAssertEqual(containerCount, 0,
                       "a lone code block survived Select-All + Backspace: \(editor.document.blocks)")
    }

    /// Deleting the last character must not leave an undeletable empty container behind.
    func test_deletingTheLastCharacterOfACodeBlockLeavesNoContainer() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
        ])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)

        editor.engine.deleteBackward()

        XCTAssertEqual(containerCount, 0,
                       "an empty code block is left behind: \(editor.document.blocks)")
    }

    /// CONTROL: a code block with text in it must NOT be dissolved by an ordinary edit, or the fix
    /// above would be "containers never survive typing".
    func test_anOrdinaryEditDoesNotDissolveACodeBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        // The END of the CODE, addressed through the container rather than as a literal offset: a
        // code block's language line occupies flat space ahead of its code, so 9 is no longer "just
        // past `let x = 1`".
        guard let codeStart = editor.flatOffsetOfPrimaryRegion(ofContainerWithID: BlockID("c0")) else {
            return XCTFail("could not locate the code region")
        }
        editor.engineSelectedRange = NSRange(location: codeStart + 9, length: 0)

        editor.engine.insertText("0")

        XCTAssertEqual(containerCount, 1, "the code block was dissolved by ordinary typing")
        guard case let .code(code) = editor.document.blocks[0] else {
            return XCTFail("not a code block any more: \(editor.document.blocks[0])")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x = 10")
    }

    /// The literal case from the device report: a code block that is ALREADY empty, then Backspace.
    ///
    /// This is not covered by "an emptied container reverts" — nothing emptied it, the command
    /// created it empty to type into (which is legacy's behaviour and worth keeping). So Backspace
    /// here has no text to delete, and if the engine reports no change the host never hears about it.
    func test_backspaceInsideAnAlreadyEmptyCodeBlockRemovesIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.makeCodeBlock()
        guard case .code = editor.document.blocks[0] else {
            return XCTFail("precondition: an empty code block should have been created, got "
                           + "\(editor.document.blocks[0])")
        }

        editor.engine.deleteBackward()

        XCTAssertEqual(containerCount, 0,
                       "an empty code block created by the command cannot be backspaced away: "
                       + "\(editor.document.blocks)")
    }

    /// Characterises the gap: the same empty container with a paragraph BEFORE it is removed fine,
    /// because Backspace merges it into that paragraph and the engine does report that change.
    func test_backspaceRemovesAnEmptyCodeBlockThatHasAParagraphBeforeIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "a")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [])),
        ])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.makeCodeBlock()
        guard case .code = editor.document.blocks[1] else {
            return XCTFail("precondition: expected an empty code block at index 1")
        }

        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.deleteBackward()

        XCTAssertEqual(containerCount, 0,
                       "even with a preceding paragraph the empty code block survives: "
                       + "\(editor.document.blocks)")
    }

    // MARK: Emptying a container does not DELETE it

    /// Deleting the last character of a code block leaves an EMPTY code block.
    ///
    /// The container is not a property of its text. Reverting it the moment it runs out of
    /// characters means a single backspace too many silently changes what you are editing — and the
    /// affordance for removing one deliberately already exists: backspace again, in the empty
    /// container, which un-codes it.
    func test_deletingTheLastCharacterKeepsTheCodeBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let codeStart = editor.flatOffsetOfPrimaryRegion(ofContainerWithID: BlockID("c0")),
              let end = editor.engine.position(from: editor.engine.beginningOfDocument,
                                               offset: codeStart + 1),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the code")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        guard case let .code(code)? = editor.document.blocks.first else {
            return XCTFail("the code block was deleted: \(editor.document.blocks)")
        }
        XCTAssertTrue(code.text.isEmpty, "and it is empty")
        XCTAssertEqual(editor.document.blocks.count, 1)
    }

    /// The same for a selection covering everything in it.
    func test_selectionBackspaceKeepsTheCodeBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let codeStart = editor.flatOffsetOfPrimaryRegion(ofContainerWithID: BlockID("c0")),
              let from = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                offset: codeStart),
              let to = editor.engine.position(from: editor.engine.beginningOfDocument,
                                              offset: codeStart + 9),
              let all = editor.engine.textRange(from: from, to: to) else {
            return XCTFail("could not address the code")
        }
        editor.engine.selectedTextRange = all
        editor.engine.deleteBackward()

        guard case let .code(code)? = editor.document.blocks.first else {
            return XCTFail("the code block was deleted: \(editor.document.blocks)")
        }
        XCTAssertTrue(code.text.isEmpty)
    }

    /// And for a block quote, whose emptiness belongs to the RUN rather than to one block.
    func test_deletingAQuotesContentKeepsTheQuote() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
            ])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 1),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the quote")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        guard case let .blockQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote was dissolved: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.children.map(\.flatUTF16Count), [0], "empty, but still a quote")
    }

    /// Backspace AGAIN, in the now-empty container, is what removes it — unchanged.
    func test_backspaceInTheEmptiedQuoteThenUnquotesIt() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
            ])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 1),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the quote")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()   // empties it
        editor.engine.deleteBackward()   // and this un-quotes it

        XCTAssertFalse(editor.document.blocks.contains {
            if case .blockQuote = $0 { return true }
            return false
        }, "a second backspace removes the emptied quote: \(editor.document.blocks)")
    }

    // MARK: Backspace at a container's far edge

    private func quoteThenParagraph(_ trailing: String) -> Document {
        Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "quoted")],
                                 author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      runs: trailing.isEmpty ? [] : [TextRun(text: trailing)])),
        ])
    }

    /// Backspace at the start of the paragraph after a quote must not merge into the AUTHOR.
    ///
    /// The engine sees a flat list and merges a block into the one before it. The block before this
    /// paragraph is the quote's author LINE, so the paragraph's text was pulled into the attribution
    /// — which is the "text mixed between body and author" that was reported. An empty paragraph is
    /// simply removed, which is the legacy rule for a paragraph after a non-text block.
    func test_backspaceAtTheStartOfAnEmptyParagraphAfterAQuoteRemovesIt() {
        editor.document = quoteThenParagraph("")
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // The empty trailing paragraph: past "quoted", its separator, "Ada" and its separator.
        let start = editor.engine.beginningOfDocument
        guard let at = editor.engine.position(from: start, offset: 11),
              let caret = editor.engine.textRange(from: at, to: at) else {
            return XCTFail("could not address the trailing paragraph")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        XCTAssertEqual(editor.document.blocks.count, 1,
                       "the empty paragraph goes: \(editor.document.blocks)")
        guard case let .pullQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote came apart: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "quoted")
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada", "the author is untouched")
    }

    /// A NON-empty one stays put, and nothing is pulled into the author either.
    func test_backspaceAtTheStartOfATextParagraphAfterAQuoteMergesNothing() {
        editor.document = quoteThenParagraph("after")
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let at = editor.engine.position(from: start, offset: 11),
              let caret = editor.engine.textRange(from: at, to: at) else {
            return XCTFail("could not address the trailing paragraph")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        XCTAssertEqual(editor.document.blocks.count, 2,
                       "both survive: \(editor.document.blocks)")
        guard case let .pullQuote(quote)? = editor.document.blocks.first,
              case let .paragraph(paragraph)? = editor.document.blocks.last else {
            return XCTFail("shape changed: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada", "the author is untouched")
        XCTAssertEqual(paragraph.text, "after", "and so is the paragraph")
    }

    // MARK: a container typed into after it was made empty

    /// Measured on device: a code block made empty and then typed into un-coded on any backspace,
    /// text and all. The dissolve rule read the code block's emptiness off the language line's role,
    /// which carries a snapshot of the block from when the role was built — empty — rather than the
    /// live roles.
    func test_backspaceInsideACodeBlockTypedIntoAfterItWasMadeEmptyDeletesOneCharacter() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "", runs: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // the empty body: "before\n" 7 + "" 0 + "\n"
        for character in ["l", "e", "t", " ", "x"] { editor.engine.insertText(character) }
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "", "let x"])
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // "let| x"
        editor.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "", "le x"], "one character, not the block")
        guard case .code = editor.document.blocks[1] else { return XCTFail("the code block un-coded: \(editor.document.blocks)") }
    }

    func test_backspaceInsideAPullQuoteTypedIntoAfterItWasMadeEmptyDeletesOneCharacter() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        for character in ["q", "u"] { editor.engine.insertText(character) }
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "qu", ""], "body and the author line it gained")
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // q|u
        editor.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "u", ""])
        guard case .pullQuote = editor.document.blocks[1] else { return XCTFail("the pull quote came apart: \(editor.document.blocks)") }
    }

    // MARK: an emptied code block

    /// Legacy's `startsEmptyContainer`: the code BODY empty is enough; the language line is a field.
    func test_backspaceInAnEmptiedCodeBodyUncodesWhateverTheLanguageLineHolds() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 14, length: 0)   // "before\n" 7 + "swift\n" 6 + "x" → after x
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "swift", ""], "the body emptied; the block stays")
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.document.blocks.count, 2)
        guard case let .paragraph(paragraph) = editor.document.blocks[1] else { return XCTFail("still a code block: \(editor.document.blocks)") }
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "", "un-coded, as legacy does")
    }

    func test_backspaceAtTheStartOfTheLanguageLineOfAnEmptyCodeBlockKeepsTheLanguageAsAParagraph() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)   // |swift
        editor.engine.deleteBackward()
        guard case let .paragraph(paragraph) = editor.document.blocks[1] else { return XCTFail("still a code block: \(editor.document.blocks)") }
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "swift", "the language text is not lost")
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [])),
        ])
        editor.engineSelectedRange = NSRange(location: 9, length: 0)   // sw|ift
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["before", "sift", ""], "inside the line, a character")
        guard case .code = editor.document.blocks[1] else { return XCTFail("un-coded from inside the language line") }
    }

    // MARK: select all, Backspace

    /// The engine keeps the FIRST block's identity — the language line's — and settle declares the
    /// survivor a body paragraph (legacy leaves one empty paragraph).
    func test_selectAllAndBackspaceOverACodeBlockLeavesOneEmptyBodyParagraph() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 7)   // "swift\nx"
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), [""])
        XCTAssertEqual(editor.currentRoles.map { $0.secondaryKind == nil }, [true], "no language line survives without its code")
        XCTAssertEqual(editor.document.blocks.count, 1)
        guard case .paragraph = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        editor.engine.insertText("y")
        XCTAssertEqual(editor.document.blocks.map(\.flatText), ["y"])
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), false, "typed in the body face, not the language line's")
        editor.engine.undoManager?.undo(); editor.engine.undoManager?.undo()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["swift", "x"], "undo brings the code block back")
        XCTAssertEqual(editor.currentRoles.map { $0.secondaryKind != nil }, [true, false])
    }

    func test_selectAllAndBackspaceOverACodeBlockFollowedByAParagraph() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 13)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), [""])
        guard case .paragraph = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
    }

    /// The survivor is the paragraph before the code block: no line is orphaned, nothing to declare.
    func test_selectAllAndBackspaceOverAParagraphAndACodeBlock() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 14)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p0")])
    }
}
