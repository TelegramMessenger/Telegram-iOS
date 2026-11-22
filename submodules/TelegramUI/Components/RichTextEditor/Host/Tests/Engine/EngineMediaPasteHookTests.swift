import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The two paste-media hooks (spec §7.4), consulted where legacy consults them: `canPasteMedia`
/// makes Paste available for a pasteboard holding only media; `onPasteMedia` is called when the
/// pasteboard has no text representation, and the chat routes the media to its send flow. Nothing
/// lands in the editor.
@available(iOS 18.4, *)
final class EngineMediaPasteHookTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "text")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        UIPasteboard.general.items = []
    }
    override func tearDown() { UIPasteboard.general.items = []; window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private var paste: Selector { #selector(UIResponderStandardEditActions.paste(_:)) }
    /// The engine's own system paste (the `[super paste:sender]` fallthrough) resolves the
    /// pasteboard's text representation through UIKit's async item-provider combine path
    /// (`textPasteConfigurationSupporting:combineItemAttributedStrings:forRange:`) even when
    /// `paste:` is invoked directly rather than by a system gesture — confirmed by tracing
    /// `TGIDObservingBlockTextView.paste:` (NSLog before/after `[super paste:sender]`): the text
    /// lands in `attributedBlocks` one run-loop turn after `paste(nil)` returns, never inside the
    /// call itself. Same idiom as `EngineContainerPasteTests.turn()`.
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

    func test_pasteIsOfferedForAMediaOnlyPasteboardWhenTheHostSaysSo() {
        XCTAssertFalse(editor.engine.canPerformAction(paste, withSender: nil), "precondition: an empty pasteboard offers nothing")
        editor.canPasteMedia = { true }
        XCTAssertTrue(editor.engine.canPerformAction(paste, withSender: nil))
        editor.canPasteMedia = { false }
        XCTAssertFalse(editor.engine.canPerformAction(paste, withSender: nil))
    }

    func test_pasteWithNoTextRepresentationGoesToTheHost() {
        var calls = 0
        editor.onPasteMedia = { calls += 1; return true }
        editor.engine.paste(nil)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["text"], "nothing lands in the editor")
    }

    func test_pasteWithTextGoesToTheEngineNotTheHost() {
        var calls = 0
        editor.onPasteMedia = { calls += 1; return true }
        UIPasteboard.general.string = "pasted"
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.engine.paste(nil)
        turn()
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["textpasted"])
    }

    func test_aHostThatDeclinesLetsTheEnginePaste() {
        editor.onPasteMedia = { false }
        editor.engine.paste(nil)   // an empty pasteboard: the engine pastes nothing, and nothing crashes
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["text"])
    }

    func test_theHooksAreReadLazily() {
        XCTAssertNotNil(editor.engine.tgid_canPasteMediaHandler)
        XCTAssertNotNil(editor.engine.tgid_pasteMediaHandler)
        var seen = false
        editor.canPasteMedia = { seen = true; return true }   // set AFTER construction, as the composer does
        _ = editor.engine.canPerformAction(paste, withSender: nil)
        XCTAssertTrue(seen)
    }
}
