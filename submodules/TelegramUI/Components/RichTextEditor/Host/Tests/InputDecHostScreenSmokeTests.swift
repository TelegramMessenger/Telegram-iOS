import UIKit
import XCTest
@testable import InputDecHost
@testable import RichTextEditorUIKit
@testable import RichTextEngineEditor
import RichTextInputDecUpstream

/// **Does the host application actually work?**
///
/// It runs INSIDE the host app, so it answers that question without anyone launching the app by
/// hand — which matters because "it compiled" has been a false signal ten times in this programme,
/// and because handing the user a host app that dies on launch would waste the one channel left for
/// hands-on defects.
///
/// Deliberately narrow. It does not certify the engine's behaviour; the parity and differential
/// suites do that. It certifies that **each arm of the screen stands up, holds the backend it
/// claims to hold, and accepts a keystroke that reaches the document.**
@available(iOS 17.0, *)
@MainActor
final class InputDecHostScreenSmokeTests: XCTestCase {

    private func makeScreen() -> HostRootViewController {
        let screen = HostRootViewController()
        // Real window, real size — the engine reads live geometry, and a zero-sized host is how a
        // caret rect becomes a plausible `.zero` instead of an honest nil.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = screen
        window.makeKeyAndVisible()
        screen.loadViewIfNeeded()
        screen.view.layoutIfNeeded()
        addTeardownBlock {
            MainActor.assumeIsolated {
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        return screen
    }

    private func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    /// The default arm is InputDec, and it must be the REAL InputDec canvas.
    ///
    /// `.inputDecIfSupported` falls back to legacy silently. A host that showed a legacy canvas
    /// while the segmented control read "InputDec" would send the user hunting for engine defects
    /// in code the engine never ran — the exact shape of mistake the parity harness guards against
    /// with the same assertion.
    func test_theDefaultArmIsTheRealInputDecCanvasAndNotASilentLegacyFallback() throws {
        let screen = makeScreen()
        XCTAssertTrue(IDTextEditorBackend.isSupported(),
                      "the InputDec backend reports unsupported on this runtime, so the host's "
                      + "primary arm cannot exist. Everything below is moot.")
        let editor = try XCTUnwrap(screen.currentEditor as? RichTextEditorView,
                                   "the default arm is not a RichTextEditorView")
        _ = try XCTUnwrap(editor.canvasForTesting as? IDDocumentCanvasView,
                          "the host FELL BACK TO LEGACY while presenting itself as the InputDec "
                          + "arm. live canvas = \(screen.liveCanvasDescription())")
    }

    /// The phase-1 exit criterion, re-asked of the SCREEN rather than of a bare view: focus it, type,
    /// and the character must reach the document.
    func test_theInputDecArmTakesFocusAndAcceptsTypedText() throws {
        let screen = makeScreen()
        let editor = try XCTUnwrap(screen.currentEditor as? RichTextEditorView)
        let canvas = editor.canvasForTesting

        XCTAssertTrue(canvas.becomeFirstResponder(),
                      "the InputDec canvas refused first responder — this is the 'dead keyboard' "
                      + "defect shape, found by hand once already")
        spin(0.3)
        canvas.selectedTextRange = canvas.textRange(from: canvas.endOfDocument,
                                                    to: canvas.endOfDocument)
        canvas.insertText("Z")

        let all = canvas.text(in: canvas.textRange(from: canvas.beginningOfDocument,
                                                  to: canvas.endOfDocument)!) ?? ""
        XCTAssertTrue(all.hasSuffix("Z"),
                      "the typed character did not reach the document. text=\(all.debugDescription)")
    }

    /// Every arm stands up and takes a keystroke. The point is the *raw engine* and *legacy* arms:
    /// they are what makes a defect attributable, and an arm that quietly fails to build would make
    /// the comparison read as agreement.
    func test_everyArmBuildsHoldsItsOwnBackendAndAcceptsAKeystroke() throws {
        let screen = makeScreen()
        for arm in HostRootViewController.Arm.allCases {
            screen.select(arm: arm)
            screen.view.layoutIfNeeded()
            let editor = try XCTUnwrap(screen.currentEditor, "arm \(arm.title) built no editor")

            switch arm {
            case .inputDec:
                let canvas = try XCTUnwrap((editor as? RichTextEditorView)?.canvasForTesting)
                XCTAssertTrue(canvas is IDDocumentCanvasView, "InputDec arm is not InputDec")
            case .legacy:
                let canvas = try XCTUnwrap((editor as? RichTextEditorView)?.canvasForTesting)
                XCTAssertFalse(canvas is IDDocumentCanvasView,
                               "the LEGACY control arm was handed an InputDec canvas — it would "
                               + "then agree with the InputDec arm for the wrong reason")
            case .rawEngine:
                XCTAssertTrue(editor is IDBlockTextView,
                              "the raw-engine arm is \(type(of: editor)), not IDBlockTextView")
            case .stock:
                XCTAssertTrue(editor is UITextView, "the stock arm is \(type(of: editor))")
            case .engineEditor:
                XCTAssertTrue(editor is RichTextEngineEditorView,
                              "the engine-editor arm is \(type(of: editor)), not RichTextEngineEditorView")
            }

            // `RichTextEngineEditorView` wraps the engine rather than conforming to `UITextInput`
            // itself (like `RichTextEditorView` wraps its canvas) — same reason the RichTextEditorView
            // branch above reaches through `.canvasForTesting`.
            let input = try XCTUnwrap(
                editor as? UITextInput
                    ?? (editor as? RichTextEditorView)?.canvasForTesting
                    ?? (editor as? RichTextEngineEditorView)?.engine,
                "arm \(arm.title) exposes no UITextInput")
            let responder = (editor as? RichTextEditorView)?.canvasForTesting
                ?? (editor as? RichTextEngineEditorView)?.engine
                ?? editor
            XCTAssertTrue(responder.becomeFirstResponder(),
                          "arm \(arm.title) refused first responder")
            spin(0.2)
            input.selectedTextRange = input.textRange(from: input.endOfDocument,
                                                      to: input.endOfDocument)
            let before = input.text(in: input.textRange(from: input.beginningOfDocument,
                                                       to: input.endOfDocument)!) ?? ""
            input.insertText("Q")
            let after = input.text(in: input.textRange(from: input.beginningOfDocument,
                                                      to: input.endOfDocument)!) ?? ""
            XCTAssertEqual(after.count, before.count + 1,
                           "arm \(arm.title) accepted a keystroke and DROPPED it — "
                           + "before=\(before.debugDescription) after=\(after.debugDescription)")
            responder.resignFirstResponder()
        }
    }

    /// The violation channel is armed, and it does not trap.
    ///
    /// With NO reporter installed, `RichTextInputContractViolation.report` is an `assertionFailure`
    /// in DEBUG — so an unimplemented adapter requirement would kill the app on the user's first
    /// tap. The screen installs a reporter in `viewDidLoad`; this proves it took, by driving a
    /// report through the real seam rather than by reading a variable.
    func test_contractViolationsLandInTheOnScreenLogInsteadOfTrapping() {
        let screen = makeScreen()
        let before = screen.violations.count
        RichTextInputContractViolation.report("PH4 smoke: synthetic violation")
        XCTAssertEqual(screen.violations.count, before + 1,
                       "the host's contract-violation reporter is NOT installed. In a DEBUG build "
                       + "that means the next unimplemented adapter requirement traps the app in "
                       + "the user's hands instead of printing a line.")
        XCTAssertTrue(screen.violations.last?.contains("PH4 smoke: synthetic violation") == true,
                      "the violation text was lost: \(screen.violations.last ?? "<none>")")
    }
}
