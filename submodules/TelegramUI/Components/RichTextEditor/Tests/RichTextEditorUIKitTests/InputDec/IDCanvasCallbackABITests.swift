#if canImport(UIKit)
import ObjectiveC
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task F3 — the private canvas callbacks' PARAMETER SHAPES, measured instead of reconstructed.
///
/// Tasks C6/C7/C12/C14 installed sixteen private selectors onto `IDDocumentCanvasView` with
/// hand-written type encodings, documented as best-effort reconstructions because the vendored
/// manifest does not carry these rows. Five of C6/C7's six guesses were right. The sixth,
/// `_deleteBackwardAndNotify:`, was installed as `"v@:@"` — a trailing OBJECT — where the runtime's
/// own encoding is `"v@:B"`, a BOOL. UIKit passes `YES`; ARC retained address `0x1`; the app
/// segfaulted on the first Backspace after the first keystroke, with the thunk body never even
/// reading the argument. **An `id` parameter is the only shape that turns a wrong guess into a
/// crash, because ARC touches it whether or not the body reads it.**
///
/// This file is the standing instrument that keeps that from recurring:
///
/// 1. `test_deleteBackwardAndNotify_calledTheWayUIKitCallsIt_deletesInsteadOfCrashing` is the
///    reproduction — it calls the selector through a `BOOL`-shaped C function pointer, exactly as
///    `-[UIKBInputDelegateManager _deleteBackwardAndNotify:reinsertText:…]` does. Before the fix it
///    took the whole xctest process down.
/// 2. `test_everyEncodingTheInstallerAddsMatchesTheRuntimesOwn` is the guard: it censuses EVERY
///    class in the process for each selector the installer adds and compares. It is written against
///    the installer's live output rather than a restated list, so a NEW thunk is covered the day it
///    is added, without anyone remembering to come here.
/// 3. `test_theInstallersAdmissionTestRefusesTheEncodingThatCrashedTheApp` proves the runtime-side
///    guard (`TGAddThunk`, which refuses an encoding contradicting the superclass chain) is not
///    vacuous, by feeding it the exact encoding that crashed.
///
/// Measured identically on iOS 26.5 / 23F73 (the kernel's certified build) and iOS 27.0.
@available(iOS 17.0, *)
@MainActor
final class IDCanvasCallbackABITests: XCTestCase {

    /// The rows `TGRichTextInputDecInstallCanvasCallbacks` adds to `IDDocumentCanvasView`, and the
    /// encoding each is added with. Restated here ON PURPOSE, as the second half of a two-sided
    /// check: the test below asserts the installer's LIVE output equals this table (so the shipped
    /// set cannot drift silently) AND that the table matches the runtime's own encodings (so the OS
    /// cannot drift silently). One side alone would be satisfiable by editing the other.
    ///
    /// `_deleteBackwardAndNotify:` is deliberately ABSENT — see
    /// `test_deleteBackwardAndNotifyIsNotInstalled_andTheInheritedImplementationStillDeletes`.
    private static let expectedInstallation: [String: String] = [
        "textStorage": "@@:",
        "textInputView": "@@:",
        "textInputDidChange:": "v@:@",
        "textInputDidChangeSelection:": "v@:@",
        "keyboardInputChangedSelection:": "v@:@",
        "keyboardInput:shouldInsertText:isMarkedText:": "B@:@@B",
        "textInput:shouldChangeCharactersInRanges:replacementText:": "B@:@@@",
        "interactionAssistant": "@@:",
        "_textInputViewForAddingGestureRecognizers": "@@:",
        "selectionContainerView": "@@:",
        "setContinuousSpellCheckingEnabled:": "v@:B",
        "isContinuousSpellCheckingEnabled": "B@:",
        // The three ABI-witnessed rows: borrowed from `TGRichTextInputDecCanvasABIWitness`'s
        // compiled methods, so these encodings are what the compiler emitted, not literals.
        "keyboardInputShouldDelete:": "B@:@",
        "startAutoscroll:": "v@:{CGPoint=dd}",
        "cancelAutoscroll": "v@:",
    ]

    /// Not a thunk: Swift emits an `initWithCoder:` override into EVERY `NSCoding`-inheriting
    /// subclass, `IDDocumentCanvasView` included, whether or not it declares one. It is the only
    /// non-thunk entry in this class's own method table and it is excluded by name rather than by a
    /// pattern, so a future thunk cannot slip past the check by being called `init…`.
    private static let swiftSynthesized: Set<String> = ["initWithCoder:"]

    private func install() {
        var error: NSError?
        XCTAssertTrue(
            TGRichTextInputDecInstallCanvasCallbacks(IDDocumentCanvasView.self,
                                                     DocumentCanvasView.self, &error),
            "the installer failed: \(error as Any)")
    }

    // MARK: - Step 1 — the reproduction

    /// Calls `_deleteBackwardAndNotify:` the way UIKit does — through a function pointer whose third
    /// parameter is a `BOOL`, which is what `-[UIKBInputDelegateManager
    /// _deleteBackwardAndNotify:reinsertText:overrideOriginalContextBefore:…]` sends (the crash
    /// report's own frame 3).
    ///
    /// **Before the fix this did not fail — it CRASHED**, taking the xctest process with it
    /// (`EXC_BAD_ACCESS at 0x1`, `objc_retain` ← `objc_storeStrong` ← `TGThunk_deleteBackwardAndNotify`),
    /// because the installed thunk declared that argument `id`. That is the whole reproduction:
    /// there is no assertion that can run after a segfault, so "the test completes at all" is the
    /// first half of the signal and the captured mutation below is the second.
    ///
    /// The assertion is on CAPTURED values: `receivedMutations` is read into a local before any
    /// `XCTAssert` looks at it.
    func test_deleteBackwardAndNotify_calledTheWayUIKitCallsIt_deletesInsteadOfCrashing() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"])
        defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
                               reason: .programmatic)

        let selector = Selector(("_deleteBackwardAndNotify:"))
        let implementation = h.canvas.method(for: selector)
        XCTAssertNotNil(implementation, "the canvas must answer the selector UIKit sends it")
        let call = unsafeBitCast(implementation,
                                 to: (@convention(c) (AnyObject, Selector, ObjCBool) -> Void).self)
        call(h.canvas, selector, ObjCBool(true))

        let mutations = h.document.receivedMutations
        let failures = h.idBackend.witnessFailures
        guard case .deleteBackward(let selection, let proposedRange)? = mutations.last else {
            return XCTFail("UIKit's own Backspace call reached no mutation; got \(mutations)")
        }
        XCTAssertEqual(selection,
                       RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
                       "the delete must carry the backend's live canonical selection")
        XCTAssertEqual(proposedRange.map { $0.location + $0.length }, 3,
                       "the controller's own proposed range must end at the caret")
        XCTAssertEqual(failures, [], "no kernel witness may fail on the Backspace path")
    }

    /// The design decision, pinned so it cannot be quietly reverted.
    ///
    /// `UIResponder` implements `_deleteBackwardAndNotify:` for every responder in the system, and
    /// its implementation calls `-deleteBackward` on self — measured, both flag values, iOS 26.5;
    /// `-[UITextView _deleteBackwardAndNotify:]` really removes a character. So the selector asks
    /// the responder to PERFORM the delete; it does not report one already performed, which is what
    /// Task C6's thunk assumed. Not installing therefore leaves the canvas on UIKit's own
    /// implementation → `-deleteBackward` → `inputBackend.deleteBackward()`, which is exactly the
    /// route the legacy canvas (which never installed this selector) takes today.
    func test_deleteBackwardAndNotifyIsNotInstalled_andTheInheritedImplementationStillDeletes() {
        install()
        let selector = Selector(("_deleteBackwardAndNotify:"))
        XCTAssertNil(Self.ownMethodTable(of: IDDocumentCanvasView.self)[NSStringFromSelector(selector)],
                     "the ID canvas must NOT define `_deleteBackwardAndNotify:` itself — its "
                     + "parameter is a BOOL and a wrong reconstruction of it segfaulted the app; the "
                     + "inherited UIResponder implementation is both correct and legacy-identical")

        let inherited = class_getInstanceMethod(IDDocumentCanvasView.self, selector)
        XCTAssertNotNil(inherited, "UIResponder implements this for every responder")
        let encoding = inherited.flatMap { method_getTypeEncoding($0) }.map { String(cString: $0) }
        XCTAssertEqual(encoding.map(Self.normalized), "v@:B",
                       "the inherited implementation's own encoding IS the real ABI: a BOOL")
    }

    // MARK: - Steps 2 & 4 — the probe, and the standing guard built on it

    /// **The deliverable.** For every row the installer adds, compare our encoding against the
    /// runtime's own — obtained by enumerating every class in the process that implements that
    /// selector directly and reading `method_getTypeEncoding`. No reference class is hard-coded, so
    /// the instrument cannot go stale by naming a class UIKit later removes; it goes BLIND only if
    /// UIKit stops implementing a selector anywhere, and that is itself a failure below.
    func test_everyEncodingTheInstallerAddsMatchesTheRuntimesOwn() {
        install()

        // Normalised on our side too: the three ABI-witnessed rows carry the encoding the COMPILER
        // emitted for `TGRichTextInputDecCanvasABIWitness`'s methods, offsets and all
        // (`"B24@0:8@16"`), while the twelve literal rows carry what this file's installer typed.
        let installed = Self.ownMethodTable(of: IDDocumentCanvasView.self)
            .filter { !Self.swiftSynthesized.contains($0.key) }
            .mapValues(Self.normalized)
        XCTAssertEqual(installed, Self.expectedInstallation,
                       "the set of private selectors installed onto the ID canvas moved. Every row "
                       + "here is a private ABI we do not own: add it to `expectedInstallation` in "
                       + "the same commit, with the encoding PROBED (this test does the probing) "
                       + "rather than inferred from the selector's colons.")

        let census = Self.systemEncodingCensus(of: Set(installed.keys))
        var problems: [String] = []
        for (name, ours) in installed.sorted(by: { $0.key < $1.key }) {
            guard let found = census[name], !found.isEmpty else {
                problems.append("\(name): NOTHING in the runtime implements this selector any more, "
                                + "so this guard is BLIND for it — it cannot tell you whether "
                                + "\"\(ours)\" is still right. Probe it another way before shipping.")
                continue
            }
            if found.count > 1 {
                let listed = found.map { "\($0.key) (e.g. \($0.value.prefix(3).joined(separator: ", ")))" }
                problems.append("\(name): the runtime carries \(found.count) DIFFERENT encodings for "
                                + "this selector — \(listed.sorted().joined(separator: " | ")). A "
                                + "human has to decide which one UIKit sends US.")
            }
            for (theirs, classes) in found where Self.normalized(theirs) != Self.normalized(ours) {
                problems.append("\(name): we install \"\(ours)\", the runtime says \"\(theirs)\" "
                                + "(e.g. \(classes.prefix(4).joined(separator: ", "))). If ours "
                                + "declares an object where theirs declares a scalar, this is a "
                                + "SEGFAULT, not a mismatch — ARC retains the argument whether or "
                                + "not the thunk reads it.")
            }
        }
        XCTAssertEqual(problems, [], "\n" + problems.joined(separator: "\n"))
    }

    /// The census is only worth what its normaliser is worth, so the normaliser is calibrated
    /// against the two real encodings this task turned on: the runtime's `_deleteBackwardAndNotify:`
    /// (`v20@0:8B16`) and its `textInputDidChange:` (`v24@0:8@16`).
    func test_theEncodingNormaliserIsCalibratedAgainstRealRuntimeEncodings() {
        XCTAssertEqual(Self.normalized("v20@0:8B16"), "v@:B")
        XCTAssertEqual(Self.normalized("v24@0:8@16"), "v@:@")
        XCTAssertEqual(Self.normalized("B36@0:8@16@24B32"), "B@:@@B")
        XCTAssertEqual(Self.normalized("v32@0:8{CGPoint=dd}16"), "v@:{CGPoint=dd}")
        XCTAssertNotEqual(Self.normalized("v20@0:8B16"), Self.normalized("v24@0:8@16"),
                          "a BOOL argument and an object argument must never normalise to the same "
                          + "thing — that difference IS the crash")
    }

    // MARK: - Step 4 — the runtime-side guard

    func test_theInstallerRefusedNoRowOnThisOS() {
        install()
        XCTAssertEqual(TGRichTextInputDecCanvasCallbackABIRejections(), [],
                       "the installer refused to install a row because our encoding contradicted "
                       + "the runtime's own. The canvas is running on the inherited implementation "
                       + "for that row — safe, but not what we intended.")
    }

    /// Proves the refusal path is real, using the exact pair from the crash. There is no other way
    /// to exercise it: every encoding the installer passes is a literal, so a test cannot inject a
    /// wrong one through the installer itself.
    func test_theInstallersAdmissionTestRefusesTheEncodingThatCrashedTheApp() {
        let selector = Selector(("_deleteBackwardAndNotify:"))
        XCTAssertTrue(
            TGRichTextInputDecCanvasCallbackABIWouldAccept(IDDocumentCanvasView.self, selector, "v@:B"),
            "the real ABI must be admissible")
        XCTAssertFalse(
            TGRichTextInputDecCanvasCallbackABIWouldAccept(IDDocumentCanvasView.self, selector, "v@:@"),
            "\"v@:@\" is the encoding that crashed the app; the installer must refuse it")
        XCTAssertTrue(
            TGRichTextInputDecCanvasCallbackABIWouldAccept(
                IDDocumentCanvasView.self, Selector(("selectionContainerView")), "@@:"),
            "a selector nothing on the superclass chain implements has nothing to contradict, so it "
            + "must still be admissible — otherwise the guard would block most of the table")
    }

    // MARK: - instrument

    /// The selectors a class defines ITSELF (never inherited), with the encoding each was
    /// installed with. `IDDocumentCanvasView` declares nothing in Swift, so for it this is exactly
    /// the installer's output.
    private static func ownMethodTable(of cls: AnyClass) -> [String: String] {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &count) else { return [:] }
        defer { free(methods) }
        var table: [String: String] = [:]
        for index in 0..<Int(count) {
            let method = methods[index]
            let name = NSStringFromSelector(method_getName(method))
            table[name] = method_getTypeEncoding(method).map { String(cString: $0) } ?? "(null)"
        }
        return table
    }

    /// selector name → encoding → the classes implementing it with that encoding.
    ///
    /// Enumerates EVERY class in the process (one pass, all selectors at once) and skips our own —
    /// the package's classes and the test bundle's — so the census answers "what does the system
    /// say", never "what did we just install".
    private static func systemEncodingCensus(of selectors: Set<String>)
        -> [String: [String: [String]]] {
        var result: [String: [String: [String]]] = [:]
        let classCount = objc_getClassList(nil, 0)
        guard classCount > 0 else { return result }
        let classes = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(classCount))
        defer { classes.deallocate() }
        _ = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(classes), classCount)
        for index in 0..<Int(classCount) {
            let cls: AnyClass = classes[index]
            guard let image = class_getImageName(cls) else { continue }
            let imagePath = String(cString: image)
            // Our own code is not evidence about UIKit's ABI.
            if imagePath.contains(".xctest") || imagePath.contains("RichTextEditor") { continue }
            var methodCount: UInt32 = 0
            guard let methods = class_copyMethodList(cls, &methodCount) else { continue }
            defer { free(methods) }
            for methodIndex in 0..<Int(methodCount) {
                let method = methods[methodIndex]
                let name = NSStringFromSelector(method_getName(method))
                guard selectors.contains(name) else { continue }
                let encoding = method_getTypeEncoding(method).map { String(cString: $0) } ?? "(null)"
                result[name, default: [:]][encoding, default: []].append(
                    "\(NSStringFromClass(cls))[\((imagePath as NSString).lastPathComponent)]")
            }
        }
        return result
    }

    /// Drops the frame-size and argument-offset digits the runtime bakes into its own encodings
    /// (`"v20@0:8B16"` → `"v@:B"`), so a hand-written encoding can be compared with a runtime one.
    ///
    /// Digit-stripping is safe for THIS table and no wider: the only structure types in it are
    /// `{CGPoint=dd}` and `{_NSRange=QQ}`, neither of which carries a digit in its own name. A row
    /// whose type name contains a digit would need a real parser — `test_theEncodingNormaliser…`
    /// above is where that would be caught.
    private static func normalized(_ encoding: String) -> String {
        encoding.filter { !$0.isNumber }
    }
}
#endif
