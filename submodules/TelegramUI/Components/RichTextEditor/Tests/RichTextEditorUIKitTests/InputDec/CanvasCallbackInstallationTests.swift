#if canImport(UIKit)
import ObjectiveC
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// The proof that the legacy class can never acquire a private UIKit selector.
///
/// This file names all 22 private selectors in plaintext, deliberately. Global Constraint 3
/// scopes the "no private selector name in Swift" rule to `Sources/`, and the enforcing rule
/// (R1b, `test_privateRuntimeLookups_areConfinedToTheInventoriedFiles`) scans
/// `RepoLayout.uiKitSources` only — the test target is never shipped, and a negative assertion
/// about a selector cannot be written without naming it.
@available(iOS 17.0, *)
final class CanvasCallbackInstallationTests: XCTestCase {

    /// The 22-name CENSUS, not the installed set — it is deliberately WIDER than what
    /// `TGRichTextInputDecInstallCanvasCallbacks` adds (eight of these are names the plan reserved
    /// and nothing installs), because the claim below is a NEGATIVE one: the legacy class must never
    /// gain any of them. `_deleteBackwardAndNotify:` is one of the never-installed ones as of Task
    /// F3 — see `IDCanvasCallbackABITests`, which pins the ACTUAL installed table.
    private static let installedSelectors = [
        "textStorage", "textInputView", "textContainerOrigin", "textLayoutController",
        "_inputController", "_textInputTraits", "textInputTraits",
        "_implicitPasteConfigurationClasses",
        "_attributedStringForInsertionOfAttributedString:",
        "setContinuousSpellCheckingEnabled:", "isContinuousSpellCheckingEnabled",
        "textInput:shouldChangeCharactersInRanges:replacementText:",
        "keyboardInput:shouldReplaceTextInRange:replacementText:",
        "textInputDidChange:", "textInputDidChangeSelection:", "keyboardInputChangedSelection:",
        "keyboardInput:shouldInsertText:isMarkedText:", "keyboardInputShouldDelete:",
        "_deleteBackwardAndNotify:", "interactionAssistant",
        "_textInputViewForAddingGestureRecognizers", "selectionContainerView",
    ]

    func test_installRejectsTheForbiddenBaseClassItself() {
        var error: NSError?
        let ok = TGRichTextInputDecInstallCanvasCallbacks(
            DocumentCanvasView.self, DocumentCanvasView.self, &error)
        XCTAssertFalse(ok)
        XCTAssertNotNil(error)
    }

    func test_installRejectsANonDirectSubclass() {
        var error: NSError?
        let ok = TGRichTextInputDecInstallCanvasCallbacks(
            UIView.self, DocumentCanvasView.self, &error)
        XCTAssertFalse(ok)
        XCTAssertNotNil(error)
    }

    func test_installSucceedsOnTheIDSubclass_andIsIdempotent() {
        var error: NSError?
        XCTAssertTrue(TGRichTextInputDecInstallCanvasCallbacks(
            IDDocumentCanvasView.self, DocumentCanvasView.self, &error), "\(error as Any)")
        XCTAssertTrue(TGRichTextInputDecInstallCanvasCallbacks(
            IDDocumentCanvasView.self, DocumentCanvasView.self, &error), "\(error as Any)")
    }

    /// The load-bearing assertion of the whole isolation argument.
    ///
    /// DEVIATION FROM THE BRIEF'S LITERAL STEP-1 SNIPPET, recorded per task instructions ("decide
    /// it yourself... record the decision"): the brief's second half asserted a bare
    /// `legacy.responds(to:)` is false for all 22 names, unconditionally. On this UIKit build that
    /// is FALSE for 3 of the 22 — "textInputView", "_deleteBackwardAndNotify:",
    /// "interactionAssistant" — and NOT because of anything this task's installer does: a diagnostic
    /// probe (see the Task B5 report) showed a bare, freshly-allocated `UIView()` ALSO responds to
    /// all three, with `TGRichTextInputDecInstallCanvasCallbacks` never having been called at all.
    /// They are pre-existing UIResponder/UIView-level private surface on this OS, unrelated to the
    /// InputDec kernel or `DocumentCanvasView`'s `UITextInput` conformance.
    ///
    /// So "never responds at all" is not a meaningful claim on this OS — it would fail for reasons
    /// that have nothing to do with the isolation this task is supposed to prove. The claim that
    /// actually matters — "installing onto the ID subclass adds NOTHING to what the legacy class
    /// answers" — is a BEFORE/AFTER differential: snapshot which of the 22 a legacy instance answers
    /// before any install call runs, install, then assert the post-install set is IDENTICAL. This is
    /// strictly stronger evidence for the isolation claim than the brief's absolute check would have
    /// been (it isolates the installer's effect from OS baseline noise) and is not weakened for the
    /// 19 selectors the baseline genuinely lacks — those still assert false-after exactly as before.
    func test_theLegacyClassNeverGainsAnInstalledSelector() {
        let before = DocumentCanvasView()
        let baselineAnswered = Set(Self.installedSelectors.filter { before.responds(to: Selector($0)) })

        var error: NSError?
        _ = TGRichTextInputDecInstallCanvasCallbacks(
            IDDocumentCanvasView.self, DocumentCanvasView.self, &error)

        var count: UInt32 = 0
        let methods = class_copyMethodList(DocumentCanvasView.self, &count)
        defer { free(methods) }
        let names = Set((0..<Int(count)).map {
            String(cString: sel_getName(method_getName(methods![$0])))
        })
        for selector in Self.installedSelectors {
            XCTAssertFalse(names.contains(selector),
                           "DocumentCanvasView acquired the private selector \(selector)")
        }

        let legacy = DocumentCanvasView()
        let afterAnswered = Set(Self.installedSelectors.filter { legacy.responds(to: Selector($0)) })
        XCTAssertEqual(afterAnswered, baselineAnswered,
                       "installing onto the ID subclass changed what the legacy class answers: " +
                       "newly answered = \(afterAnswered.subtracting(baselineAnswered))")
    }

    /// A thunk that reaches a canvas with no attached backend must be inert.
    func test_thunksAreInertWithoutAnAttachedBridge() {
        var error: NSError?
        _ = TGRichTextInputDecInstallCanvasCallbacks(
            IDDocumentCanvasView.self, DocumentCanvasView.self, &error)
        let canvas = IDDocumentCanvasView()
        TGRichTextInputDecSetAttachedBridge(canvas, nil)
        XCTAssertNil(canvas.perform(Selector(("textStorage")))?.takeUnretainedValue())
        XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
    }

    func test_setAttachedBridgeRoundTripsAndClears() {
        let canvas = IDDocumentCanvasView()
        let bridge = StubBridge()
        TGRichTextInputDecSetAttachedBridge(canvas, bridge)
        XCTAssertTrue(TGRichTextInputDecAttachedBridge(canvas) === bridge)
        TGRichTextInputDecSetAttachedBridge(canvas, nil)
        XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
    }
}

/// Minimal conformer used only to prove the associated-object channel. It implements exactly
/// the protocol's two @required methods and is NEVER extended by Tasks C4-C7 — that is why
/// every group they add is declared `@optional` (see the protocol's own comment).
final class StubBridge: NSObject, TGRichTextInputDecClientBridging {
    func textStorageFacade() -> NSTextStorage { NSTextStorage() }
    func canvasKeyboardInputShouldDelete() -> Bool { true }
}
#endif
