#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore
import RichTextEngineEditor

/// The chat's ⇧⌘N on the CANVAS editor. The composer's native shortcut path sends `.clearFormatting`
/// to whichever editor it holds, through the `RichTextEditor` protocol, and reports the shortcut
/// handled — so an editor answering the protocol's empty default swallows the shortcut and the chat's
/// own clear-formatting path never runs. These go through the protocol for exactly that reason.
final class ClearInlineFormattingTests: XCTestCase {
    private func editor(with runs: [TextRun]) -> RichTextEditorView {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: runs))])
        editor.layoutIfNeeded()
        return editor
    }

    private func runs(_ editor: RichTextEditorView) -> [TextRun] {
        guard case .paragraph(let p) = editor.document.blocks.first else { return [] }
        return p.runs
    }

    private func carriesAnyInlineMark(_ run: TextRun) -> Bool {
        let a = run.attributes
        return a.bold || a.italic || a.underline || a.strikethrough || a.inlineCode || a.spoiler
    }

    func test_clearInlineFormattingRemovesEveryInlineMarkFromTheSelection() {
        let editor = editor(with: [
            TextRun(text: "bold ", attributes: CharacterAttributes(bold: true)),
            TextRun(text: "italic ", attributes: CharacterAttributes(italic: true)),
            TextRun(text: "under ", attributes: CharacterAttributes(underline: true)),
            TextRun(text: "strike ", attributes: CharacterAttributes(strikethrough: true)),
            TextRun(text: "code ", attributes: CharacterAttributes(inlineCode: true)),
            TextRun(text: "hidden", attributes: CharacterAttributes(spoiler: true)),
        ])
        editor.selectAll()
        let asTheComposerHoldsIt: any RichTextEditor = editor
        asTheComposerHoldsIt.clearInlineFormatting()

        XCTAssertEqual(runs(editor).map(\.text).joined(), "bold italic under strike code hidden")
        XCTAssertFalse(runs(editor).contains(where: carriesAnyInlineMark),
                       "every inline mark is cleared: \(runs(editor).map(\.attributes))")
    }

    /// A range only PART of which is bold must still come out with no bold: a toggle over a mixed
    /// range SETS the format, so clearing has to press it again.
    func test_aPartlyFormattedSelectionIsClearedToo() {
        let editor = editor(with: [
            TextRun(text: "plain "),
            TextRun(text: "bold", attributes: CharacterAttributes(bold: true)),
        ])
        editor.selectAll()
        (editor as any RichTextEditor).clearInlineFormatting()
        XCTAssertFalse(runs(editor).contains { $0.attributes.bold }, "\(runs(editor).map(\.attributes))")
        XCTAssertEqual(runs(editor).map(\.text).joined(), "plain bold")
    }

    /// One command, one undo step, which restores every mark it removed.
    func test_oneUndoRestoresEveryMark() {
        let original: [TextRun] = [
            TextRun(text: "plain "),
            TextRun(text: "bold", attributes: CharacterAttributes(bold: true)),
            TextRun(text: " italic", attributes: CharacterAttributes(italic: true)),
        ]
        let editor = editor(with: original)
        // Compared with the editor's OWN read-back: the canvas pins a run's rendered size on read-back
        // (the package CLAUDE.md's "font size is PINNED into runs"), so the constructed runs differ
        // from what any later read returns in `fontSize` alone.
        let before = runs(editor)
        editor.selectAll()
        (editor as any RichTextEditor).clearInlineFormatting()
        XCTAssertFalse(runs(editor).contains(where: carriesAnyInlineMark))

        editor.undo()
        XCTAssertEqual(runs(editor), before, "one undo puts back exactly the formatting the command removed")
    }

    /// A collapsed caret changes nothing, as the legacy composer's shortcut does not.
    func test_aCollapsedCaretChangesNothing() {
        let original: [TextRun] = [TextRun(text: "bold", attributes: CharacterAttributes(bold: true))]
        let editor = editor(with: original)
        let before = runs(editor)
        (editor as any RichTextEditor).clearInlineFormatting()
        XCTAssertEqual(runs(editor), before)
    }

    // MARK: Ambient styles are not the user's, and clearing must leave them alone

    private func storageFont(_ editor: RichTextEditorView, boxAt index: Int, offset: Int) -> UIFont? {
        let storage = editor.canvas.boxes[index].textLayout.attributedString
        return storage.attribute(.font, at: offset, effectiveRange: nil) as? UIFont
    }

    /// Removing INLINE CODE must give the run back its paragraph's own face, not a plain system font:
    /// a heading's text was drawn in the body font after ⇧⌘N until something re-rendered it.
    func test_clearingInlineCodeInAHeadingGivesBackTheHeadingFace() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [
            TextRun(text: "Title "),
            TextRun(text: "code", attributes: CharacterAttributes(inlineCode: true)),
        ]))])
        editor.layoutIfNeeded()
        let headingFace = storageFont(editor, boxAt: 0, offset: 0)
        editor.selectAll()
        (editor as any RichTextEditor).clearInlineFormatting()
        let cleared = storageFont(editor, boxAt: 0, offset: 7)
        XCTAssertEqual(cleared?.familyName, headingFace?.familyName, "the cleared run lost the heading's face: \(String(describing: cleared))")
        XCTAssertEqual(cleared?.pointSize ?? 0, headingFace?.pointSize ?? -1, accuracy: 0.01)
    }

    /// A pull quote's body is italic by its style, not by the user: ⇧⌘N drew it roman.
    func test_clearingAPullQuoteKeepsItsItalicFace() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        editor.document = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [
            TextRun(text: "quoted "),
            TextRun(text: "bold", attributes: CharacterAttributes(bold: true)),
        ], author: []))])
        editor.layoutIfNeeded()
        XCTAssertTrue(storageFont(editor, boxAt: 0, offset: 0)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false,
                      "precondition: a pull quote's body is drawn italic")
        editor.selectAll()
        (editor as any RichTextEditor).clearInlineFormatting()
        XCTAssertTrue(storageFont(editor, boxAt: 0, offset: 0)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false,
                      "⇧⌘N drew a pull quote's body roman")
    }
}
#endif
