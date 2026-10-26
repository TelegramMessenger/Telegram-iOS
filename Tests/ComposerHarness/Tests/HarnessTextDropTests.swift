import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor
import RichTextEditorCore
import RichTextEditorUIKit

/// **What this pins.** The engine composer's text drag and drop (`RichTextEngineEditorView+DragAndDrop.swift`),
/// driven below the `UIDragInteraction` / `UIDropInteraction` delegates, whose sessions a test cannot build:
///
/// - a LOCAL move (a drag lifted from this editor and dropped in it) within a paragraph, across blocks,
///   into a quote and into a code block is ONE undo step, and the caret lands after the moved text;
/// - a move whose source covers a table only in part is refused, as typing over it is;
/// - a drop from outside is a paste at the drop point: plain text, the editor's own fragment and markdown,
///   and into a one-line field (a quote's author) newlines become spaces;
/// - a drop never reads or writes the user's clipboard.
///
/// **How it was seen.** p12 roam, 2026-09-24: the engine composer had no drag and drop at all
/// (`HarnessTextDragAndDropTests`). These pin the behaviour the implementation promises.
///
/// **Tier 1**: the drop's own entry points (`performDrop(_:atFlatOffset:)`, `performLocalMove(_:toFlatOffset:)`)
/// and the lift's (`makeTextDragContext()`), with the source a test-built `EnginePasteSource`. The real
/// long-press lift and gesture arbitration are Tier 2 (`HarnessTextDragUITests`).
@available(iOS 18.4, *)
final class HarnessTextDropTests: XCTestCase {
    private func driver(_ content: ChatInputContent) throws -> (EngineFuzzDriver, FuzzEngineVerifier) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.settle(0.1)
        return (driver, verifier)
    }

    private func describe(_ driver: EngineFuzzDriver) -> String {
        return FuzzModel.describe(FuzzModel.normalized(driver.model()))
    }

    /// Selects `source`, lifts it, drops it at `target`; returns the model after the move.
    @discardableResult
    private func move(_ driver: EngineFuzzDriver, _ source: NSRange, to target: Int, file: StaticString = #filePath, line: UInt = #line) throws -> Bool {
        driver.setViewSelection(source)
        driver.settle(0.1)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext(), "nothing to lift at \(source)", file: file, line: line)
        let moved = driver.editor.performLocalMove(context, toFlatOffset: target)
        driver.settle(0.3)
        return moved
    }

    /// One undo restores `before`, and nothing is left to undo: the move was one step.
    private func assertOneUndoStep(_ driver: EngineFuzzDriver, restores before: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let undoManager = driver.undoManager else {
            return XCTFail("no undo manager", file: file, line: line)
        }
        XCTAssertTrue(undoManager.canUndo, "the move registered no undo step", file: file, line: line)
        undoManager.undo()
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), before, "one undo did not restore the document", file: file, line: line)
        XCTAssertFalse(undoManager.canUndo, "the move took more than one undo step", file: file, line: line)
    }

    // MARK: - Local moves

    func testAMoveWithinAParagraphIsOneUndoStep() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two three"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertTrue(try self.move(driver, NSRange(location: 4, length: 4), to: 13))
        XCTAssertEqual(self.describe(driver), "[p body \"one threetwo \"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 13, length: 0), "the caret is not after the moved text")
        XCTAssertNil(FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText()))
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMoveKeepsTheMovedTextsFormatting() throws {
        let bold = ChatInputInlineAttributes(bold: true)
        let (driver, verifier) = try self.driver(ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "plain "), ChatInputRun(text: "bold", attributes: bold), ChatInputRun(text: " end")]))
        ]))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        XCTAssertTrue(try self.move(driver, NSRange(location: 6, length: 4), to: 0))
        XCTAssertEqual(self.describe(driver), "[p body [b]\"bold\"+\"plain  end\"]")
    }

    func testAMoveAcrossBlocksIsOneUndoStep() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        // "First paragraph.\nSecond paragraph.": "First " (0..<6) to "Second |paragraph." (24).
        XCTAssertTrue(try self.move(driver, NSRange(location: 0, length: 6), to: 24))
        XCTAssertEqual(self.describe(driver), "[p body \"paragraph.\"] [p body \"Second First paragraph.\"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 24, length: 0), "the caret is not after the moved text")
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMoveBackwardsAcrossBlocksIsOneUndoStep() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        // "Second " (17..<24) to the document's start.
        XCTAssertTrue(try self.move(driver, NSRange(location: 17, length: 7), to: 0))
        XCTAssertEqual(self.describe(driver), "[p body \"Second First paragraph.\"] [p body \"paragraph.\"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 7, length: 0), "the caret is not after the moved text")
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMoveIntoAQuoteLandsInsideItAsOneUndoStep() throws {
        // "Quoted with author.\nAnn\nAfter.": move "After" (24..<29) to "Quoted |with" (7).
        let (driver, verifier) = try self.driver(HarnessComposerFuzzTests.extendedStartingContents()[1])
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertTrue(try self.move(driver, NSRange(location: 24, length: 5), to: 7))
        XCTAssertEqual(self.describe(driver), "[quote [p body \"Quoted Afterwith author.\"] author=\"Ann\"] [p body \".\"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 12, length: 0), "the caret is not after the moved text")
        XCTAssertNil(FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText()))
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMoveIntoACodeBlockLandsAsCodeTextInOneUndoStep() throws {
        // "Code below:\nswift\nlet x = 1": move "below" (5..<10) to the code's end (27).
        let (driver, verifier) = try self.driver(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Code below:"),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertTrue(try self.move(driver, NSRange(location: 5, length: 5), to: 27))
        XCTAssertEqual(self.describe(driver), "[p body \"Code :\"] [code lang=\"swift\" \"let x = 1below\"]")
        XCTAssertNil(FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText()))
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMoveIntoAnAuthorLineTakesTheFieldsRuleInOneUndoStep() throws {
        // "Attributed:\nWords to live by.\nSomeone": move "Attributed" (0..<10) to the author's end (37).
        let (driver, verifier) = try self.driver(HarnessComposerFuzzTests.extendedStartingContents()[0])
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertTrue(try self.move(driver, NSRange(location: 0, length: 10), to: 37))
        XCTAssertEqual(self.describe(driver), "[p body \":\"] [pull \"Words to live by.\" author=\"SomeoneAttributed\"]")
        self.assertOneUndoStep(driver, restores: before)
    }

    func testADropInsideItsOwnSourceIsRefused() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two three"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertFalse(try self.move(driver, NSRange(location: 4, length: 4), to: 6))
        XCTAssertEqual(self.describe(driver), before)
        XCTAssertFalse(driver.undoManager?.canUndo ?? true, "a refused move registered an undo step")
    }

    /// A move whose source covers a table only in part changes nothing, as typing over it changes nothing.
    func testAMoveOfASelectionCoveringATableInPartIsRefused() throws {
        // "Table below:\nName\nValue\nalpha\n1\nAfter the table.": from inside cell "alpha" (26) into "After" (36).
        let (driver, verifier) = try self.driver(HarnessComposerFuzzTests.extendedStartingContents()[3])
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        let source = NSRange(location: 26, length: 10)
        XCTAssertFalse(driver.editor.dropIsAcceptable(atFlatOffset: 0, movingFrom: source), "the drop proposal accepts the move")
        XCTAssertFalse(try self.move(driver, source, to: 0))
        XCTAssertEqual(self.describe(driver), before, "a move of a selection covering the table in part changed the document")
        // Control: typing over the same selection is refused too.
        driver.setViewSelection(source)
        driver.settle(0.1)
        driver.insert("X")
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), before, "control: typing over the selection changed the document")
    }

    // MARK: - Drops from outside

    func testAPlainTextDropIsInsertedAtTheDropPointAsOneUndoStep() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let before = self.describe(driver)
        XCTAssertTrue(driver.editor.performDrop(.loaded(fragmentData: nil, string: "X "), atFlatOffset: 4))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p body \"one X two\"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 6, length: 0))
        self.assertOneUndoStep(driver, restores: before)
    }

    func testAMultiLinePlainTextDropSplitsTheParagraph() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        XCTAssertTrue(driver.editor.performDrop(.loaded(fragmentData: nil, string: "a\nb "), atFlatOffset: 4))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p body \"one a\"] [p body \"b two\"]")
        XCTAssertNil(FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText()))
    }

    func testAFragmentDropKeepsItsStructure() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let fragment = Document(blocks: [
            .code(CodeBlock(id: .generate(), language: "swift", runs: [TextRun(text: "let y = 2")])),
        ])
        XCTAssertTrue(driver.editor.performDrop(.fragment(fragment), atFlatOffset: 7))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p body \"one two\"] [code lang=\"swift\" \"let y = 2\"] [p body ]")
        XCTAssertNil(FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText()))
    }

    func testAMarkdownDropIsParsedLikeAPaste() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText(""))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        XCTAssertTrue(driver.editor.performDrop(.loaded(fragmentData: nil, string: "# Title\nbody"), atFlatOffset: 0))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p heading1 \"Title\"] [p body \"body\"]")
    }

    func testADropIntoAnAuthorLineTurnsNewlinesIntoSpaces() throws {
        // "Attributed:\nWords to live by.\nSomeone": the author ends at 37.
        let (driver, verifier) = try self.driver(HarnessComposerFuzzTests.extendedStartingContents()[0])
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        XCTAssertTrue(driver.editor.performDrop(.loaded(fragmentData: nil, string: " Mr\nX"), atFlatOffset: 37))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p body \"Attributed:\"] [pull \"Words to live by.\" author=\"Someone Mr X\"]")
    }

    func testAFragmentDropIntoAnAuthorLineTakesItsPlainText() throws {
        let (driver, verifier) = try self.driver(HarnessComposerFuzzTests.extendedStartingContents()[0])
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let fragment = Document(blocks: [
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: " a")])),
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "b")])),
        ])
        XCTAssertTrue(driver.editor.performDrop(.fragment(fragment), atFlatOffset: 37))
        driver.settle(0.3)
        XCTAssertEqual(self.describe(driver), "[p body \"Attributed:\"] [pull \"Words to live by.\" author=\"Someone a b\"]")
    }

    func testADropOnAMediaAtomIsRefused() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // Control: a drop on text is accepted.
        XCTAssertTrue(driver.editor.dropIsAcceptable(atFlatOffset: 1, movingFrom: nil))
        XCTAssertFalse(driver.editor.dropIsAcceptable(atFlatOffset: 99, movingFrom: nil), "a drop past the end is accepted")
    }

    // MARK: - The clipboard

    /// A drop — local or from outside — neither reads nor writes the user's clipboard.
    func testADropLeavesTheClipboardUntouched() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // Written by this process first (never read the clipboard before writing it).
        UIPasteboard.general.string = "the user's clipboard"
        HarnessComposerFuzzTests.notePasteboardWritten()
        let changeCount = UIPasteboard.general.changeCount

        XCTAssertTrue(driver.editor.performDrop(.loaded(fragmentData: nil, string: "plain "), atFlatOffset: 0))
        driver.settle(0.2)
        let fragment = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "frag ")]))])
        XCTAssertTrue(driver.editor.performDrop(.fragment(fragment), atFlatOffset: 0))
        driver.settle(0.2)
        XCTAssertTrue(try self.move(driver, NSRange(location: 0, length: 5), to: 17))

        XCTAssertEqual(UIPasteboard.general.changeCount, changeCount, "a drop wrote the clipboard")
        XCTAssertEqual(UIPasteboard.general.string, "the user's clipboard")
        XCTAssertFalse(UIPasteboard.general.contains(pasteboardTypes: [RichTextEditorClipboard.fragmentUTI]))
    }

    // MARK: - The lift

    /// What a drag carries: the editor's fragment (formatting kept) and plain text for other apps.
    func testALiftCarriesTheFragmentAndPlainText() throws {
        let bold = ChatInputInlineAttributes(bold: true)
        let (driver, verifier) = try self.driver(ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "plain "), ChatInputRun(text: "bold", attributes: bold)])),
            HarnessEngine.paragraph("next"),
        ]))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.setViewSelection(NSRange(location: 6, length: 7))
        driver.settle(0.1)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext())
        XCTAssertEqual(context.plainText, "bold\nne")
        XCTAssertEqual(context.fragment.blocks.count, 2)
        guard case let .paragraph(first)? = context.fragment.blocks.first else {
            return XCTFail("the fragment does not start with a paragraph")
        }
        XCTAssertEqual(first.runs.first?.attributes.bold, true, "the fragment lost the formatting")
        // Nothing to lift from a collapsed caret.
        driver.setViewSelection(NSRange(location: 3, length: 0))
        driver.settle(0.1)
        XCTAssertNil(driver.editor.makeTextDragContext())
    }

    /// The arbitration hook's premise: the engine view carries the drag interaction's own long press
    /// (`_UIDrag…`, never refused) AND at least one other long-press recogniser — the text interaction's,
    /// which the hook refuses inside a selection. Prints every recogniser, as the evidence behind the rule.
    func testTheEngineViewHasTheLongPressesTheArbitrationSeparates() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two three"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let drag = try XCTUnwrap(driver.editor.textDragAndDrop.dragInteraction)
        // Nothing to lift: the drag is off, so without a selection the view's recognisers are the
        // ones it had before drag and drop existed.
        driver.setViewSelection(NSRange(location: 3, length: 0))
        driver.settle(0.1)
        XCTAssertFalse(drag.isEnabled, "the drag is enabled with no selection")
        driver.setViewSelection(NSRange(location: 4, length: 3))
        driver.settle(0.1)
        XCTAssertTrue(drag.isEnabled, "the drag is not enabled over a selection")
        let recognizers = driver.view.gestureRecognizers ?? []
        for recognizer in recognizers {
            var chain: [String] = []
            var type: AnyClass? = object_getClass(recognizer)
            while let current = type, chain.count < 4 {
                chain.append(NSStringFromClass(current))
                type = class_getSuperclass(current)
            }
            print("DND recognizer \(chain.joined(separator: " < ")) enabled=\(recognizer.isEnabled)")
        }
        let longPresses = recognizers.filter { $0 is UILongPressGestureRecognizer }
        XCTAssertTrue(longPresses.contains(where: { EngineTextDragAndDrop.isDragRecognizer($0) }), "no drag lift recogniser on the engine view")
        XCTAssertTrue(longPresses.contains(where: { !EngineTextDragAndDrop.isDragRecognizer($0) }), "no text-interaction long press to arbitrate against")
    }

    /// The lift's hit test: a point inside the selection's rects lifts; one outside does not (the loupe's).
    func testOnlyAPointInsideTheSelectionLifts() throws {
        let (driver, verifier) = try self.driver(HarnessContent.plainText("one two three four"))
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.setViewSelection(NSRange(location: 4, length: 3))
        driver.settle(0.2)
        let rects = driver.editor.selectionRectsForDrag(NSRange(location: 4, length: 3))
        let rect = try XCTUnwrap(rects.first, "the selection has no rects")
        XCTAssertTrue(driver.editor.pointLiftsSelection(CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertFalse(driver.editor.pointLiftsSelection(CGPoint(x: rect.maxX + 40.0, y: rect.midY)), "a point outside the selection lifts it")
        // A collapsed caret lifts nothing.
        driver.setViewSelection(NSRange(location: 5, length: 0))
        driver.settle(0.1)
        XCTAssertFalse(driver.editor.pointLiftsSelection(CGPoint(x: rect.midX, y: rect.midY)))
    }
}
