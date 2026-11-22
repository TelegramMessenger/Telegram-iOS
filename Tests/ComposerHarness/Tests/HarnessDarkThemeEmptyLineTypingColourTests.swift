import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** In the DARK theme, text typed over a selection that starts on an EMPTY line is drawn
/// black — not the theme's text colour — which the model cannot carry and the dark theme does not derive:
/// near-invisible text on the dark background. It does not matter whether the theme changed after the
/// content arrived or was dark before it:
///
///     [p "Top"] [p ""] [p "end"], light → dark theme, select from the empty line 3 characters on, type x
///       → [p "Top"] [p "xd"], storage: "x" foreground (0, 0, 0, 1)
///     the same for an empty heading, an empty block-quote author line, a pull quote's empty author line,
///     an empty table cell, an empty details title, an empty code language line, an empty code block
///     the same with the dark theme set BEFORE the content arrived
///     controls: a CARET on the same empty line types in the dark theme's colour; a selection starting in
///       TEXT does
///
/// **How it was seen.** p21 roam (2026-10-01): the new `environment` fuzz op (a theme change left in place
/// mid-sequence) at edited seed 4 step 40, caught by the model-unrepresentable check; greedy-reduced from 70
/// ops to 6 (dark theme, a quote pasted, typing over a selection from its empty author line), then to the
/// shapes above.
///
/// **Suspected cause.** Typing over a selection takes the attributes of the selection's FIRST character,
/// and on an empty line that is the line's SEPARATOR. Separators are not rendered from the role: a theme
/// change re-renders block TEXT only (`rerenderPresentation` → `applyPresentationEdits`: "the batch edits
/// block TEXT only: a range's separator part is ignored", p15 follow-up), and a set renders an empty
/// block's separator with no themed colour (the dark-before-content case), so the typed text arrives with
/// black or with no colour at all, and neither the typed-text policy nor settle re-derives the colour of
/// text typed over a selection. The same never-re-derived separators are behind
/// `HarnessUndoSeparatorTypingAttributesTests` (p21). In the light theme the wrong colour is black too and
/// so invisible to this check.
///
/// **Severity.** Visible (dark text on a dark background) and drawn-but-not-sent; not corruption.
///
/// **Tier 1**: the theme change goes through the panel's own path (`HarnessPanelHost.updatePresentationInterfaceState`),
/// the typing through `insertText` over a view selection.
@available(iOS 18.4, *)
final class HarnessDarkThemeEmptyLineTypingColourTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
        HarnessComposerFuzzTests.resetEnvironment(self.driver)
    }

    override func tearDown() {
        HarnessComposerFuzzTests.resetEnvironment(self.driver)
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private func unrepresentable() -> String {
        var out: [String] = []
        for index in self.driver.editor.currentRoles.indices {
            let fields = self.driver.editor.modelUnrepresentableFields(atBlock: index)
            if !fields.isEmpty {
                out.append("block \(index): \(fields.joined(separator: ","))")
            }
        }
        return out.joined(separator: "; ")
    }

    /// Arranges `content`, changes to the dark theme (before or after the content arrived), selects
    /// `range` and types `x`; answers what storage holds that the model cannot carry ("" when clean).
    private func typeX(_ content: ChatInputContent, over range: NSRange, darkBeforeContent: Bool = false) -> String {
        if darkBeforeContent {
            HarnessComposerFuzzTests.applyEnvironment(0, on: self.driver)
        }
        HarnessComposerFuzzTests.arrange(self.driver, content)
        if !darkBeforeContent {
            HarnessComposerFuzzTests.applyEnvironment(0, on: self.driver)
        }
        XCTAssertEqual(self.unrepresentable(), "", "precondition: storage is clean after the theme change")
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.2)
        return self.unrepresentable()
    }

    private static let emptyParagraph = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([]), E.paragraph([E.run("end")])])

    // MARK: - Red

    func testTypingOverASelectionFromAnEmptyParagraphTakesTheDarkThemeColour() {
        XCTAssertEqual(self.typeX(Self.emptyParagraph, over: NSRange(location: 4, length: 3)), "", "the typed text is black, not the dark theme's colour")
    }

    func testTypingOverASelectionFromAnEmptyHeadingTakesTheDarkThemeColour() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [])), E.paragraph([E.run("end")])])
        XCTAssertEqual(self.typeX(content, over: NSRange(location: 4, length: 3)), "", "the typed text is black, not the dark theme's colour")
    }

    func testTypingOverASelectionFromAnEmptyQuoteAuthorTakesTheDarkThemeColour() {
        let content = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("q")])]), collapsed: false, author: [])), E.paragraph([E.run("end")])])
        XCTAssertEqual(self.typeX(content, over: NSRange(location: 2, length: 3)), "", "the typed text is black, not the dark theme's colour")
    }

    func testTypingOverASelectionFromAnEmptyCellTakesTheDarkThemeColour() {
        let content = ChatInputContent(blocks: [.table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: []), ChatInputTableCell(runs: [E.run("c2")])])])), E.paragraph([E.run("end")])])
        XCTAssertEqual(self.typeX(content, over: NSRange(location: 0, length: 3)), "", "the typed text is black, not the dark theme's colour")
    }

    /// p21 fix wave (red before its fix, found probing this row's edges): the same from the END of a
    /// non-empty line, i.e. a selection starting at its separator. A non-empty block's separator kept the
    /// presentation it had before the theme change (the presentation pass restyled the text only), so the
    /// typed text was the light theme's black. Fixed in the engine's `id_restoreAttributedBlocks`: a
    /// non-empty block's separator follows its last character.
    func testTypingOverASelectionFromTheEndOfALineTakesTheDarkThemeColour() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([E.run("mid")]), E.paragraph([E.run("end")])])
        XCTAssertEqual(self.typeX(content, over: NSRange(location: 3, length: 2)), "", "the typed text is black, not the dark theme's colour")
        XCTAssertEqual(self.typeX(content, over: NSRange(location: 3, length: 4)), "", "the typed text is black, not the dark theme's colour")
    }

    // MARK: - Controls

    func testControlACaretOnTheEmptyLineTypesInTheDarkThemeColour() {
        XCTAssertEqual(self.typeX(Self.emptyParagraph, over: NSRange(location: 4, length: 0)), "")
    }

    func testControlASelectionStartingInTextTypesInTheDarkThemeColour() {
        XCTAssertEqual(self.typeX(Self.emptyParagraph, over: NSRange(location: 2, length: 4)), "")
    }

    func testTheDarkThemeBeforeTheContentArrivedToo() {
        XCTAssertEqual(self.typeX(Self.emptyParagraph, over: NSRange(location: 4, length: 3), darkBeforeContent: true), "", "red too: the typed text is black with the theme dark from the start")
    }
}
