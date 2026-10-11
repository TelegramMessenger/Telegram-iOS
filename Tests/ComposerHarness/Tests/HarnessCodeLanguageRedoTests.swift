import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a code block's LANGUAGE is rewritten LOWERCASED whenever the
/// engine renders it from the model: opening an edited message whose code block says `Swift` reads
/// back `swift` with no keystroke, and undo / redo in the language line bring the user's typing back
/// lowercased and without a trailing space. The restored caret — an offset measured on the line as
/// typed — then lands one past the shortened line, in the code BODY, so the next keystroke types into
/// the code.
///
///     [code lang="Swift" "let"] set → get → lang "swift"
///
///     [code lang="swift" "let"]   engine "swift\nlet"
///     caret 5, type "Q"  → "swiftQ"; Undo → "swift"; Redo → "swiftq"  (the user's Q lowercased)
///     caret 5, type " "  → engine "swift " (model "swift", trimmed); Undo; Redo → caret 6, which is
///                          now the body's start; type "x" → body "xlet", language unchanged
///     control: typing "Q" with no undo keeps "swiftQ" (stored as typed, as the editor documents)
///
/// **How it was seen.** The p13 edited-content fuzz, seed 43 step 30 (a kana composition at the end
/// of a language line ending in a space: the composition's undo re-rendered the line, so the typing
/// oracle typed into the body). Reduced by probe.
///
/// **Suspected cause.** The editor's rule is "the value is stored AS TYPED, trimmed; only the renderer
/// lowercases" (RichTextEditor `CLAUDE.md`), but the bridge RENDERS the line lowercased
/// (`EngineDocumentBridge` `languageLine(text: (code.language ?? "").lowercased(), …)`) and reads the
/// line back as the stored value, so any re-render — the snapshot replay behind undo and redo — writes
/// the lowercased, trimmed text back as the language, and the replayed caret is not clamped to it.
///
/// **Tier 1**: `insertText(_:)` and the view's `undoManager`.
@available(iOS 18.4, *)
final class HarnessCodeLanguageRedoTests: XCTestCase {
    private static let code = ChatInputContent(blocks: [.code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let")]))])

    private func code(_ driver: EngineFuzzDriver) -> ChatInputCode? {
        if case let .code(code)? = driver.model().blocks.first {
            return code
        }
        return nil
    }

    private func undoAllRedoAll(_ driver: EngineFuzzDriver) {
        while driver.undoManager?.canUndo == true { driver.undoManager?.undo(); driver.settle(0.15) }
        while driver.undoManager?.canRedo == true { driver.undoManager?.redo(); driver.settle(0.15) }
    }

    func testRedoKeepsTheTypedLanguageAsTyped() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: Self.code, ops: [.select(5, 5), .insert("Q")])
        XCTAssertEqual(self.code(driver)?.language, "swiftQ", "precondition: the typed language")
        self.undoAllRedoAll(driver)
        XCTAssertEqual(self.code(driver)?.language, "swiftQ", "redo rewrote the language")
    }

    func testRedoKeepsTheCaretInTheLanguageLine() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: Self.code, ops: [.select(5, 5), .insert(" ")])
        self.undoAllRedoAll(driver)
        driver.insert("x")
        driver.settle(0.2)
        XCTAssertEqual(self.code(driver)?.text, "let", "the next keystroke after redo typed into the code body: \(fuzzEscaped(driver.viewText()))")
        XCTAssertTrue(self.code(driver)?.language?.hasPrefix("swift") == true && self.code(driver)?.language?.contains("x") == true,
                      "the keystroke did not reach the language: \(fuzzEscaped(driver.viewText()))")
    }

    /// Control: typing with no undo stores the language as typed.
    func testControlTypingKeepsTheLanguageAsTyped() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: Self.code, ops: [.select(5, 5), .insert("Q")])
        XCTAssertEqual(self.code(driver)?.language, "swiftQ")
    }

    /// An edited message whose language is capitalised: a plain SET lowercases it.
    func testASetLanguageKeepsItsCase() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: ChatInputContent(blocks: [.code(ChatInputCode(language: "Swift", runs: [ChatInputRun(text: "let")]))]), ops: [])
        XCTAssertEqual(self.code(driver)?.language, "Swift")
    }
}
