import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

final class EngineResponderTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha")]))])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    /// The dead-keyboard defect's shape: a member answering a plausible `false`.
    func test_theEditorCanBecomeFirstResponderAndTheEngineHoldsTheRole() {
        XCTAssertTrue(editor.canBecomeFirstResponder)
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertTrue(editor.isEditorFirstResponder, "the ENGINE does not hold the responder role")
    }

    func test_theKeyboardIsRequestedWhenFocused() {
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertNotNil(editor.engine.textInputMode,
                        "no input mode — UIKit did not treat the engine as a text client")
    }

    func test_resigningReleasesTheRole() {
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertTrue(editor.resignEditorFirstResponder())
        XCTAssertFalse(editor.isEditorFirstResponder)
    }

    /// FOCUS IS REPORTED WHEN THE ENGINE TAKES THE ROLE, not only when the wrapper is asked to take
    /// it. A tap is delivered to the engine by UIKit's text-interaction assistant, which calls
    /// `becomeFirstResponder` on the ENGINE — the wrapper's override is never entered, so a host
    /// listening for focus heard nothing about the one way users actually focus an editor. The
    /// article editor's sheet expands from this callback, so tapping into it left it in its small
    /// detent with its action bar under the keyboard (K3, 2026-09-11).
    func test_focusingTheENGINEDirectlyReportsToTheHost() {
        var became = 0, resigned = 0
        editor.onBecameFirstResponder = { became += 1 }
        editor.onResignedFirstResponder = { resigned += 1 }
        // Exactly what the tap does — bypassing the wrapper entirely.
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(became, 1, "focus arriving at the engine was never reported")
        XCTAssertTrue(editor.engine.resignFirstResponder())
        XCTAssertEqual(resigned, 1, "losing focus was never reported either")
    }

    /// …and it is reported ONCE per genuine transition, through either door. A programmatic focus
    /// goes through the wrapper, which forwards to the engine — reported by both, it would arrive
    /// twice; a second focus while already focused is not a transition at all.
    func test_focusIsReportedExactlyOncePerTransition() {
        var became = 0
        editor.onBecameFirstResponder = { became += 1 }
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertEqual(became, 1, "the wrapper and the engine both reported one focus")
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertEqual(became, 1, "refocusing an already-focused editor is not a transition")
    }

    func test_insertTextAndDeleteBackwardReachTheDocument() {
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.insertText("!")
        guard case let .paragraph(afterInsert) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(afterInsert.runs.map(\.text).joined(), "alpha!")
        editor.deleteBackward()
        guard case let .paragraph(afterDelete) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(afterDelete.runs.map(\.text).joined(), "alpha")
    }

    /// The `customInputView` setter's whole point is that UIKit consults the FIRST RESPONDER's
    /// `-inputView` when building the keyboard surface, and `engine` is the object that holds the
    /// role — so the view must land on `engine.inputView`, not merely in the wrapper's own storage.
    /// Asserting only the round-trip through `editor.customInputView` proves nothing about that:
    /// deleting `TGIDObservingBlockTextView`'s entire `-inputView` override (the one line that makes
    /// the stored view reach UIKit) leaves such a test green, because the getter reads the same
    /// `tgid_customInputView` the setter wrote. The `engine.inputView` assertion is the one that
    /// reddens.
    func test_aCustomInputViewIsAcceptedAndReported() {
        let custom = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        editor.customInputView = custom
        XCTAssertTrue(editor.customInputView === custom)
        XCTAssertTrue(editor.engine.inputView === custom,
                      "the custom input view never reached the engine's -inputView, so UIKit would "
                      + "never see it — the first responder is the engine, not the wrapper")
    }

    func test_theInputPrimaryLanguageIsReadableWhenFocused() {
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertNotNil(editor.inputPrimaryLanguage,
                        "nil primary language — the hosted environment is not being used (Global Constraint 8)")
    }
}
