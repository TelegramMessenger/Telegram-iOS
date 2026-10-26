import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a THEME change while the composer has content — auto-night at
/// sunset, the user switching appearance, anything that hands the panel a new `PresentationTheme` —
/// throws the caret to the END of the document, drops any selection, and breaks an IME composition in
/// progress:
///
///     [p [sp]"First"], caret at 3, theme → dark, type W      engine: "FirstW"   legacy: caret kept
///     "The quick brown fox." select "quick" (4..<9), theme    engine: 20..<20    legacy: 3..<7 kept (control)
///     caret in a table cell, theme, type Q                   engine: Q lands after the paragraph below
///     composing か→かん after "Fi", theme                     engine: the composition is no longer marked,
///                                                            the caret is at the end, and the IME's next
///                                                            candidate is inserted THERE: "Fiかんrst漢字"
///
/// The model is otherwise unchanged and the colours are right; undo still works.
///
/// **How it was seen.** p12 roam, 2026-09-24 ("live environment changes"): a hosted probe drove the
/// panel's own theme path through `HarnessPanelHost.updatePresentationInterfaceState` (added for this),
/// which is what `ChatTextInputPanelNode.updateLayout` reacts to (`applyRichTextTheme`).
///
/// **Suspected cause.** `RichTextEngineEditorView.theme`'s setter always calls
/// `rebuildMapper(withTheme:)`, which re-applies the document (`document = current`). Every block's
/// rendered colours differ, so the whole document is replaced — and nothing saves and restores the
/// selection around it, nor defers it while text is marked. The legacy backend re-colours in place.
///
/// **Tier 1**: the panel's theme path is driven exactly as the chat drives it; the selection and marked
/// range are read off the engine's `UITextInput`.
@available(iOS 18.4, *)
final class HarnessThemeChangeSelectionTests: XCTestCase {
    private func switchTheme(_ driver: EngineFuzzDriver, dark: Bool) {
        driver.host.updatePresentationInterfaceState { $0.updatedTheme(dark ? defaultDarkPresentationTheme : defaultPresentationTheme) }
        driver.root.view.setNeedsLayout()
        driver.settle(0.3)
    }

    private func run(_ content: ChatInputContent, select range: NSRange, _ body: (EngineFuzzDriver, UIView & UITextInput) throws -> Void) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            self.switchTheme(driver, dark: false)
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(content)
        driver.setViewSelection(range)
        driver.settle(0.1)
        XCTAssertEqual(driver.viewSelection(), range, "precondition: the selection did not land")
        try body(driver, try XCTUnwrap(driver.view as? (UIView & UITextInput)))
    }

    func testAThemeChangeKeepsTheCaret() throws {
        var spoiler = ChatInputInlineAttributes()
        spoiler.spoiler = true
        try self.run(ChatInputContent(blocks: [HarnessEngine.paragraph("First", spoiler)]), select: NSRange(location: 3, length: 0)) { driver, input in
            self.switchTheme(driver, dark: true)
            XCTAssertEqual(driver.viewSelection(), NSRange(location: 3, length: 0), "a theme change moved the caret")
            input.insertText("W")
            driver.settle(0.2)
            XCTAssertEqual(driver.model().plainText, "FirWst", "typing after a theme change did not land at the caret")
        }
    }

    func testAThemeChangeKeepsTheSelection() throws {
        try self.run(HarnessComposerFuzzTests.startingContents()[2], select: NSRange(location: 4, length: 5)) { driver, _ in
            self.switchTheme(driver, dark: true)
            XCTAssertEqual(driver.viewSelection(), NSRange(location: 4, length: 5), "a theme change dropped the selection")
        }
    }

    func testAThemeChangeKeepsTheCaretInATableCell() throws {
        // "Table below:\nName\nValue\nalpha\n1\nAfter the table.": 15 is inside "Name".
        try self.run(HarnessComposerFuzzTests.extendedStartingContents()[3], select: NSRange(location: 15, length: 0)) { driver, input in
            self.switchTheme(driver, dark: true)
            input.insertText("Q")
            driver.settle(0.2)
            XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(driver.model())),
                           "[p body \"Table below:\"] [table (\"NaQme\" | \"Value\") (\"alpha\" | \"1\")] [p body \"After the table.\"]",
                           "typing after a theme change did not land in the cell")
        }
    }

    /// A composition open when the theme changes stays open, where it was, and its next candidate
    /// replaces it.
    func testAThemeChangeDoesNotBreakAComposition() throws {
        try self.run(HarnessContent.plainText("First"), select: NSRange(location: 2, length: 0)) { driver, input in
            for step in ["k", "か", "かn", "かん"] {
                input.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                driver.settle(0.03)
            }
            XCTAssertNotNil(input.markedTextRange, "precondition: the composition is not open")
            self.switchTheme(driver, dark: true)
            XCTAssertNotNil(input.markedTextRange, "a theme change ended the composition")
            input.setMarkedText("漢字", selectedRange: NSRange(location: 2, length: 0))
            driver.settle(0.03)
            input.unmarkText()
            driver.settle(0.2)
            // Escaped: the Bazel log drops non-ASCII, so the raw strings would both print as "First".
            XCTAssertEqual(fuzzEscaped(driver.model().plainText), fuzzEscaped("Fi漢字rst"), "the composition's next candidate landed somewhere else")
        }
    }

    /// Text Size reaches the engine as a render-metrics push (`applyRenderMetrics`), which re-rendered
    /// the document through the same whole-document set as the theme: the selection went to the end.
    /// Driven on the editor directly — the panel forces the chat's 17pt base, so the harness cannot
    /// reach this through presentation data (p12 roam, "Harness gaps").
    func testATextSizeChangeKeepsTheSelection() throws {
        try self.run(HarnessComposerFuzzTests.startingContents()[2], select: NSRange(location: 4, length: 5)) { driver, _ in
            let original = driver.editor.renderMetrics
            defer {
                driver.editor.renderMetrics = original
                driver.settle(0.2)
            }
            var larger = original
            larger.body.size += 6
            driver.editor.renderMetrics = larger
            driver.settle(0.3)
            XCTAssertEqual(driver.viewSelection(), NSRange(location: 4, length: 5), "a Text Size change dropped the selection")
            let font = driver.editor.engine.attributedBlocks.first?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            XCTAssertEqual(font?.pointSize, larger.body.size, "the text did not take the new size")
        }
    }

    /// What is typed after a theme change is drawn in the NEW palette, like the text around it: the
    /// typing attributes follow the re-rendered text. Left in the old palette, the read-back would take
    /// the old colour for an explicit one (`withoutCarriedPresentation` forgives only the CURRENT
    /// theme's text colour).
    func testTypingAfterAThemeChangeTakesTheNewPalette() throws {
        try self.run(HarnessContent.plainText("First"), select: NSRange(location: 3, length: 0)) { driver, input in
            self.switchTheme(driver, dark: true)
            input.insertText("W")
            driver.settle(0.2)
            XCTAssertEqual(driver.model().plainText, "FirWst")
            let block = try XCTUnwrap(driver.editor.engine.attributedBlocks.first)
            let primary = driver.editor.theme.primaryText
            for index in 0..<block.length {
                let colour = block.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
                XCTAssertEqual(colour, primary, "character \(index) is not in the new theme's text colour")
            }
        }
    }

    /// The same for a composition open across the theme change: its commit is in the new palette.
    func testACompositionCommittedAfterAThemeChangeTakesTheNewPalette() throws {
        try self.run(HarnessContent.plainText("First"), select: NSRange(location: 2, length: 0)) { driver, input in
            for step in ["k", "か"] {
                input.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                driver.settle(0.03)
            }
            self.switchTheme(driver, dark: true)
            input.setMarkedText("漢字", selectedRange: NSRange(location: 2, length: 0))
            driver.settle(0.03)
            input.unmarkText()
            driver.settle(0.2)
            XCTAssertEqual(fuzzEscaped(driver.model().plainText), fuzzEscaped("Fi漢字rst"))
            let block = try XCTUnwrap(driver.editor.engine.attributedBlocks.first)
            let primary = driver.editor.theme.primaryText
            for index in 0..<block.length {
                let colour = block.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
                XCTAssertEqual(colour, primary, "character \(index) is not in the new theme's text colour")
            }
            XCTAssertTrue(driver.editor.presentationDrift(atBlock: 0).isEmpty, "presentation drift after the commit")
        }
    }

    /// Control: the legacy backend keeps the selection across the same theme change.
    func testControlLegacyKeepsTheSelection() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        HarnessEngine.settle(root)
        let host = try XCTUnwrap(root.panelHost)
        host.setInputContent(HarnessContent.plainText("First paragraph."))
        HarnessEngine.settle(root, seconds: 0.2)
        let node = try XCTUnwrap(host.panel.richTextInputNode)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root, seconds: 0.2)
        node.selectedRange = NSRange(location: 3, length: 4)
        HarnessEngine.settle(root, seconds: 0.2)
        host.updatePresentationInterfaceState { $0.updatedTheme(defaultDarkPresentationTheme) }
        root.view.setNeedsLayout()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 3, length: 4), "control: legacy lost the selection too")
        host.updatePresentationInterfaceState { $0.updatedTheme(defaultPresentationTheme) }
        root.view.setNeedsLayout()
        HarnessEngine.settle(root)
    }
}
