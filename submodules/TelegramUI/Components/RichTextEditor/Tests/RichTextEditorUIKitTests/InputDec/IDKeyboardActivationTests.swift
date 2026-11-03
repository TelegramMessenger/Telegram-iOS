#if canImport(UIKit)
import RichTextEditorCore
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task F2 — the flag took first responder and drew a caret, and **no keyboard ever appeared**.
///
/// ## Why ~3000 green tests could coexist with a backend that cannot raise a keyboard
///
/// Two independent blind spots, both measured here rather than asserted:
///
/// 1. **Keyboard appearance itself is unobservable in this test host.** `test_calibration…` below
///    records it: an ordinary, plainly editable `UITextView`, first responder in a key window, posts
///    **no** `keyboardWillShowNotification` in the xctest process (measured — the process has no
///    foreground-active keyboard scene). So a test that watched for the notification would be
///    vacuous for BOTH backends, and no test in the suite watched for it.
/// 2. **Nothing anywhere read the member that decides it.** `-isEditable` — the canvas witness
///    `DocumentCanvasView.isEditable` routes to `RichTextInputBackend.isEditableForWritingTools` —
///    had exactly one pin in the whole package (`InputBackendSourceBoundaryTests`, `.literal("true")`),
///    and that rule is scoped to `LegacyRichTextInputBackend`'s source text. The differential corpus
///    could not see it either: `IDTextInputStateRecorder` records `firstResponder` but has no
///    `isEditable` field at all, so all 410 recorded differences were blind to it.
///
/// The *installation* path is NOT the gap, contrary to a stale comment at
/// `TGRichTextInputDecCanvasCallbacks.m:66` (and `DIVERGENCES.md` entry 6) claiming
/// `TGRichTextInputDecInstallCanvasCallbacks` "is never even called by any test in this stage" — it
/// is called by `CanvasCallbackInstallationTests`, `IDTextEditorBackendInteractionPreflightTests` and
/// `IDBackendFamily9Tests`, and both comments were written before Task C14 opened the
/// `incomingCallbacks` gate. `test_theAppReachableInstallationStateHasEveryThunkLive` below pins the
/// installed thunks in the state the *app* reaches (a real `RichTextEditorView`, attached, first
/// responder) anyway, because that state had no test and was the leading hypothesis for this bug.
///
/// ## The instrument
///
/// `-_requiresKeyboardWhenFirstResponder` is UIKit's own private question "does this responder need a
/// keyboard". It is used here only as a *reading*, never as something we implement, and
/// `test_calibration…` proves it is a faithful reading by taking it on two real `UITextView`s whose
/// editability we set ourselves. A read-only `UITextView` is exactly the reported symptom — first
/// responder, caret and selection, no keyboard — and before this task the InputDec canvas answered
/// identically to one.
@MainActor
final class IDKeyboardActivationTests: XCTestCase {

    // MARK: - Reading helpers

    /// All readings are CAPTURED into a value before anything is asserted (never re-derived inside an
    /// assertion), so a failure message reports the state the responder was actually in.
    private struct KeyboardReadiness: Equatable {
        var becameFirstResponder = false
        var isFirstResponder = false
        var respondsToIsEditable = false
        var isEditable = false
        var respondsToKeyboardRequirement = false
        var requiresKeyboard = false
        var sawKeyboardWillShow = false
    }

    private func boolReading(_ view: UIView, _ selectorName: String) -> (responds: Bool, value: Bool) {
        let selector = NSSelectorFromString(selectorName)
        guard view.responds(to: selector) else { return (false, false) }
        typealias BoolGetter = @convention(c) (AnyObject, Selector) -> Bool
        let getter = unsafeBitCast(view.method(for: selector), to: BoolGetter.self)
        return (true, getter(view, selector))
    }

    /// Hosts `hosted` in a real key window, makes it first responder, spins the run loop briefly so a
    /// keyboard notification would have a chance to land, and reads everything back from `reading`.
    ///
    /// The two are separate on purpose. `RichTextEditorView.becomeFirstResponder()` FORWARDS to its
    /// canvas (`RichTextEditorView.swift:805`), so the view that is hosted and activated is the editor
    /// while the responder UIKit ends up questioning is the canvas — reading the editor instead
    /// answers about a plain `UIView` that implements none of these selectors, which reads as
    /// "no keyboard wanted" for BOTH backends and would make every assertion here vacuous. (Measured:
    /// a first draft did exactly that and reported the *Legacy* arm as not wanting a keyboard.)
    private func readiness(of hosted: UIView, reading view: UIView? = nil,
                           window: UIWindow) -> KeyboardReadiness {
        let view = view ?? hosted
        var sawKeyboard = false
        let token = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil
        ) { _ in sawKeyboard = true }
        defer { NotificationCenter.default.removeObserver(token) }

        window.addSubview(hosted)
        window.makeKeyAndVisible()
        hosted.layoutIfNeeded()

        var reading = KeyboardReadiness()
        reading.becameFirstResponder = hosted.becomeFirstResponder()
        reading.isFirstResponder = view.isFirstResponder

        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline && !sawKeyboard {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        reading.sawKeyboardWillShow = sawKeyboard

        let editable = boolReading(view, "isEditable")
        reading.respondsToIsEditable = editable.responds
        reading.isEditable = editable.value
        let requirement = boolReading(view, "_requiresKeyboardWhenFirstResponder")
        reading.respondsToKeyboardRequirement = requirement.responds
        reading.requiresKeyboard = requirement.value
        return reading
    }

    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    // MARK: - Calibration: the instrument, and the instrument that does NOT work

    /// Establishes both halves of this file's premise on responders whose editability this test sets
    /// itself, so neither backend is involved:
    ///
    /// * `-_requiresKeyboardWhenFirstResponder` tracks `-isEditable` exactly. That is what makes it a
    ///   usable reading of "will a keyboard be raised" in a process where the keyboard cannot appear.
    /// * `keyboardWillShowNotification` does **not** fire even for the editable text view, so it is
    ///   NOT a usable instrument here. Asserted, not merely observed, so that if a future OS/test host
    ///   makes it fire, this test goes red and whoever sees it can promote the notification to the
    ///   real end-to-end assertion the whole file would rather be making.
    func test_calibrationTheKeyboardRequirementReadingTracksEditability() {
        let editableView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        editableView.isEditable = true
        let readOnlyView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        readOnlyView.isEditable = false

        let editable = readiness(of: editableView, window: makeWindow())
        let readOnly = readiness(of: readOnlyView, window: makeWindow())

        XCTAssertTrue(editable.respondsToKeyboardRequirement,
                      "the private keyboard-requirement reading this whole file depends on is gone; "
                      + "every assertion below is now unanchored")
        XCTAssertTrue(editable.isEditable)
        XCTAssertTrue(editable.requiresKeyboard, "an editable UITextView must want a keyboard")

        XCTAssertTrue(readOnly.becameFirstResponder,
                      "a read-only UITextView still takes first responder — that is the whole point "
                      + "of it as the control for 'caret yes, keyboard no'")
        XCTAssertFalse(readOnly.isEditable)
        XCTAssertFalse(readOnly.requiresKeyboard, "a read-only UITextView must not want a keyboard")

        XCTAssertFalse(editable.sawKeyboardWillShow,
                       "keyboardWillShowNotification now fires in the test host — the reason this "
                       + "file uses a private reading instead has expired; promote it")
    }

    // MARK: - The regression

    /// **The pin for this task.** Before the fix this asserted `requiresKeyboard == true` and got
    /// `false`, with `isEditable == false` alongside it — the read-only-`UITextView` shape from the
    /// calibration above, which is the user's exact symptom.
    @available(iOS 17.0, *)
    func test_theInputDecEditorAsksForAKeyboardWhenItTakesFirstResponder() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                                        inputBackend: .inputDecIfSupported)
        let canvas = editor.canvasForTesting
        XCTAssertTrue(canvas is IDDocumentCanvasView, "not actually on the ID canvas")

        let reading = readiness(of: editor, reading: canvas, window: makeWindow())

        XCTAssertTrue(reading.becameFirstResponder)
        XCTAssertTrue(reading.isFirstResponder)
        XCTAssertTrue(reading.respondsToIsEditable)
        XCTAssertTrue(reading.isEditable,
                      "DocumentCanvasView.isEditable is UIKit's -isEditable witness, not a Writing "
                      + "Tools hint: false here means no keyboard")
        XCTAssertTrue(reading.requiresKeyboard,
                      "first responder is held and a caret renders, but UIKit was told this responder "
                      + "needs no keyboard")
    }

    /// The differential half: whatever the answer is, the two backends must agree, because the ONLY
    /// reason the ID backend's answer was ever `false` is that it was written independently of
    /// Legacy's. Legacy is the reference implementation and is what production ships.
    func test_bothBackendsGiveTheSameKeyboardAnswer() throws {
        let legacyEditor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                                              inputBackend: .legacy)
        let legacy = readiness(of: legacyEditor, reading: legacyEditor.canvasForTesting,
                               window: makeWindow())

        guard #available(iOS 17.0, *), IDTextEditorBackend.isSupported() else {
            throw XCTSkip("InputDec backend unsupported on this runtime")
        }
        let idEditor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                                          inputBackend: .inputDecIfSupported)
        let inputDec = readiness(of: idEditor, reading: idEditor.canvasForTesting,
                                 window: makeWindow())

        XCTAssertEqual(legacy.isEditable, inputDec.isEditable, "-isEditable diverges between backends")
        XCTAssertEqual(legacy.requiresKeyboard, inputDec.requiresKeyboard,
                       "the two backends disagree about whether the editor needs a keyboard")
        XCTAssertTrue(legacy.requiresKeyboard, "the Legacy reference itself stopped asking for a keyboard")
    }

    /// `hasText` was the sibling silent stub found in the same sweep — a constant `false` on the ID
    /// backend where Legacy reads the document. Its two in-tree readers gate `.selectWord`/`.selectAll`
    /// (`TelegramCommandInputClient`), so a constant `false` silently removed Select / Select All.
    @available(iOS 17.0, *)
    func test_theInputDecBackendReportsHasTextFromTheDocument() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                                        inputBackend: .inputDecIfSupported)
        let canvas = editor.canvasForTesting

        let whenEmpty = canvas.hasText
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "hello")])],
                             width: 320)
        let whenNotEmpty = canvas.hasText

        XCTAssertFalse(whenEmpty, "an empty document must not claim to have text")
        XCTAssertTrue(whenNotEmpty, "hasText is a constant `false` — Select / Select All are dead")
    }

    /// The state the *app* reaches, which had no test: a real `RichTextEditorView` built for the ID
    /// backend, attached, hosted, first responder. Every `class_addMethod`-installed thunk that can
    /// return nil when no bridge is attached is read here and required to be live.
    ///
    /// This was the leading hypothesis for this bug and it is **wrong** — recorded as a passing test
    /// rather than deleted, so the next person does not have to re-derive that it is wrong. The bridge
    /// is published at the end of `IDTextEditorBackend.attach(to:)` and a failed attach would have
    /// tripped `RichTextInputContractViolation.report`'s DEBUG `assertionFailure` inside
    /// `DocumentCanvasView.init` long before any tap.
    @available(iOS 17.0, *)
    func test_theAppReachableInstallationStateHasEveryThunkLive() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                                        inputBackend: .inputDecIfSupported)
        let canvas = try XCTUnwrap(editor.canvasForTesting as? IDDocumentCanvasView)
        let window = makeWindow()
        window.addSubview(editor)
        window.makeKeyAndVisible()
        editor.layoutIfNeeded()
        XCTAssertTrue(canvas.becomeFirstResponder())

        func installedObject(_ selectorName: String) -> AnyObject? {
            let selector = NSSelectorFromString(selectorName)
            guard canvas.responds(to: selector) else { return nil }
            return canvas.perform(selector)?.takeUnretainedValue()
        }

        let bridge = TGRichTextInputDecAttachedBridge(canvas)
        let textInputView = installedObject("textInputView")
        let textStorage = installedObject("textStorage")
        let assistant = installedObject("interactionAssistant")
        let gestureHost = installedObject("_textInputViewForAddingGestureRecognizers")
        let selectionContainer = installedObject("selectionContainerView")

        XCTAssertNotNil(bridge, "attach published no bridge — every conditional thunk is inert")
        XCTAssertTrue(textInputView === canvas, "textInputView must be the canvas itself, not nil")
        XCTAssertTrue(textStorage is TGRichTextInputDecTextStorageFacade,
                      "textStorage must vend the façade, not nil")
        XCTAssertNotNil(assistant, "interactionAssistant is nil — the kernel published no assistant")
        XCTAssertTrue(gestureHost === canvas)
        XCTAssertNotNil(selectionContainer)
    }
}
#endif
