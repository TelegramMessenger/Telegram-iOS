import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// **CERTIFICATION: typing undo matches a stock `UITextView`, scenario by scenario.**
///
/// The editor owns its undo stack (`+UndoStack.swift`) rather than taking UIKit's grouping, because
/// UIKit's grouping depends on which entry point delivered the text — one step for a hardware key
/// press, one step PER CHARACTER for the keyboard's correction path. Owning it means the granularity
/// is now ours to get right, and "right" was defined as "what iOS does for text".
///
/// So this suite does not assert numbers of its own. It drives a stock `UITextView` and the editor
/// through the SAME scenario, in the same process and the same run loop, and requires the undo
/// traces to be equal. A number written here by hand would be a guess that outlives whatever it was
/// guessed from; a comparison cannot.
///
/// **What the oracle is, and what it is not.** It is a stock text view driven through `insertText:`,
/// which is the canonical typing path. It runs in a test host with no live keyboard, so
/// `-[UITextInputController shouldStartNewUndoGroup:textGranularity:operationType:]` never sees
/// `nextInputWouldStartSentence` — a device may therefore end a run at a sentence boundary where
/// neither side here does. That is a limit of the oracle rather than a disagreement between the two
/// sides of it: both are measured in the same place, so they cannot drift apart silently.
@available(iOS 18.4, *)
final class EngineTypingUndoParityTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    /// One step of a scenario, spelled so both surfaces can perform it.
    private enum Action {
        case type(String)
        case caret(Int)
        case select(NSRange)
        case backspace
    }

    // MARK: - The two drivers

    private func stockTrace(_ actions: [Action]) -> [String] {
        let tv = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.addSubview(tv)
        defer { tv.resignFirstResponder(); tv.removeFromSuperview() }
        XCTAssertTrue(tv.becomeFirstResponder())
        tv.text = ""
        turn()
        for action in actions {
            switch action {
            case .type(let s): for ch in s { tv.insertText(String(ch)); turn() }
            case .caret(let at): tv.selectedRange = NSRange(location: at, length: 0); turn()
            case .select(let r): tv.selectedRange = r; turn()
            case .backspace: tv.deleteBackward(); turn()
            }
        }
        var trace = [tv.text ?? ""]
        var guardCount = 0
        while tv.undoManager?.canUndo == true, guardCount < 40 {
            tv.undoManager?.undo(); turn(); guardCount += 1
            trace.append(tv.text ?? "")
        }
        return trace
    }

    private func editorTrace(_ actions: [Action]) -> [String] {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: []))])
        window.addSubview(editor)
        defer { _ = editor.resignEditorFirstResponder(); editor.removeFromSuperview() }
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        turn()
        // The editor's blocks joined the way the engine's own flat axis joins them, so the two
        // surfaces are compared on the same string. A newline splits a block here and is one
        // character there; joining with "\n" is what makes those the same text.
        func text() -> String { editor.engine.attributedBlocks.map { $0.string }.joined(separator: "\n") }
        for action in actions {
            switch action {
            case .type(let s): for ch in s { editor.engine.insertText(String(ch)); turn() }
            case .caret(let at): editor.engineSelectedRange = NSRange(location: at, length: 0); turn()
            case .select(let r): editor.engineSelectedRange = r; turn()
            case .backspace: editor.engine.deleteBackward(); turn()
            }
        }
        var trace = [text()]
        var guardCount = 0
        while editor.currentState().canUndo, guardCount < 40 {
            editor.undo(); turn(); guardCount += 1
            trace.append(text())
        }
        return trace
    }

    private func certify(_ name: String, _ actions: [Action],
                         file: StaticString = #filePath, line: UInt = #line) {
        let stock = stockTrace(actions)
        let engine = editorTrace(actions)
        XCTAssertGreaterThan(stock.count, 1,
                             "\(name): the oracle recorded no undo at all, so this certifies nothing",
                             file: file, line: line)
        XCTAssertEqual(engine, stock,
                       "\(name): the editor's undo trace is \(engine) where a stock text view gives \(stock)",
                       file: file, line: line)
    }

    // MARK: - The scenarios

    func test_aSentenceWithSpaces() { certify("spaces", [.type("hello world")]) }

    func test_sentenceBoundaries() { certify("sentence ends", [.type("Hi there. Next one. Third")]) }

    func test_aNewlineMidRun() { certify("newline", [.type("alpha\nbeta")]) }

    func test_oneLongWord() { certify("long word", [.type("supercalifragilistic")]) }

    func test_consecutiveSpaces() { certify("consecutive spaces", [.type("a   b")]) }

    func test_punctuationWithoutASentenceEnd() { certify("punctuation", [.type("a, b; c")]) }

    func test_aRunThenBackspaces() {
        certify("backspaces", [.type("hello world"), .backspace, .backspace, .backspace,
                               .backspace, .backspace])
    }

    func test_typeBackspaceType() { certify("type, delete, type", [.type("hello"), .backspace, .type("Y")]) }

    /// The first of the two that DO break a run: the caret moved, so the next character is not
    /// contiguous with what came before it.
    func test_aCaretMoveBetweenRuns() {
        certify("caret move", [.type("hello"), .caret(0), .type("X")])
    }

    /// The second: a replacement is not an insertion, whatever it lands on.
    func test_aSelectionReplacement() {
        certify("selection replace", [.type("hello world"), .select(NSRange(location: 0, length: 5)),
                                      .type("HI")])
    }
}
