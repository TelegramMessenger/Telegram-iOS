#if canImport(UIKit)
import XCTest
import UIKit
import RichTextInputDecUpstream
@testable import RichTextEditorUIKit

/// PHASE 3'S INSTRUMENT — **who holds the first-responder role, Telegram's host or the engine?**
///
/// Phase 2 left all 15 `RichTextInputResponderBackend` requirements reporting a named contract
/// violation, because none of them can be answered until that is settled. This file is where it was
/// settled, and it is deliberately three suites in one:
///
///  1. **The evidence for the model** — two private-UIKit readings, each calibrated against a
///     control so it cannot be a false reading, plus the anti-vacuity fact that makes the wrong
///     answer SILENT.
///  2. **The three wirings that were built and rejected**, kept as passing tests rather than
///     deleted. This programme's convention (`IDKeyboardActivationTests
///     .test_theAppReachableInstallationStateHasEveryThunkLive`) is to record a disproof so nobody
///     re-derives it; four controller hypotheses have already been killed by evidence here.
///  3. **What each of the seven implemented requirements actually forwards**, asserted against the
///     engine's own live answer rather than against a constant.
///
/// # The two instruments, and the one that does NOT work
///
/// `-_requiresKeyboardWhenFirstResponder` is UIKit's own private question "does this responder need
/// a keyboard". It is used only as a *reading*, never implemented, and it is calibrated below
/// against two real `UITextView`s whose editability the test sets itself — the same calibration
/// `IDKeyboardActivationTests` performs for the legacy arm.
///
/// `keyboardWillShowNotification` does **not** fire in a SwiftPM test bundle, even for a plainly
/// editable `UITextView` that is first responder in a key window. That was measured before this
/// phase and is re-asserted here, so nothing gets built on it and so a future host that DOES fire it
/// turns this red and gets promoted to the real end-to-end assertion everyone would rather have.
@MainActor
@available(iOS 18.4, *)  // IDBlockTextView and its collaborators are gated at 18.4 for the host's iOS 15 floor.
final class IDUpstreamResponderModelTests: XCTestCase {

    private var window: UIWindow!
    private var previousReporter: ((String) -> Void)?
    private var reportedViolations: [String] = []

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
        previousReporter = RichTextInputContractViolation.reporter
        reportedViolations = []
        RichTextInputContractViolation.reporter = { [weak self] message in
            self?.reportedViolations.append(message)
        }
    }

    override func tearDown() {
        RichTextInputContractViolation.reporter = previousReporter
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    // MARK: - Fixture

    /// The host is a bare `UIView`, as in `IDUpstreamInputBackendTests` — nothing routes through
    /// `DocumentCanvasView` (`task-PORT-PLAN.md` §3.2, "what phase 1 must NOT do").
    private final class ModelFakeHost: RichTextInputHost {
        let container: UIView
        let documentClient: any RichTextInputDocumentClient
        let geometryClient: any RichTextInputGeometryClient
        let annotationClient: any RichTextInputAnnotationClient
        let presentationClient: any RichTextInputPresentationClient
        let lifecycleClient: any RichTextInputLifecycleClient
        let commandClient: any RichTextInputCommandClient

        init(log: RichTextInputEventLog) {
            self.container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            self.documentClient = FakeInputDocumentClient(log: log)
            self.geometryClient = FakeInputGeometryClient(log: log)
            self.annotationClient = FakeInputAnnotationClient(log: log)
            self.presentationClient = FakeInputPresentationClient(log: log)
            self.lifecycleClient = FakeInputLifecycleClient(log: log)
            self.commandClient = FakeInputCommandClient(log: log)
        }

        var hostInputView: UIView { container }
    }

    /// A host that CLAIMS the first-responder role, which a bare `UIView` cannot do
    /// (`canBecomeFirstResponder` is `false` by default). Needed for the rejected wirings; `claims`
    /// is what wiring W2 flips.
    private final class ClaimingContainer: UIView {
        var claims = true
        var onWillBecome: (() -> Void)?
        var onDidBecome: (() -> Void)?
        var trace: [String] = []
        override var canBecomeFirstResponder: Bool { claims }
        override func becomeFirstResponder() -> Bool {
            trace.append("host.become ENTER")
            onWillBecome?()
            let became = super.becomeFirstResponder()
            trace.append("host.super.become=\(became)")
            if became { onDidBecome?() } else { trace.append("backend.hostDidFailToBecome") }
            trace.append("host.become EXIT \(became)")
            return became
        }
        override func resignFirstResponder() -> Bool {
            trace.append("host.resign ENTER")
            let resigned = super.resignFirstResponder()
            trace.append("host.super.resign=\(resigned)")
            trace.append("host.resign EXIT \(resigned)")
            return resigned
        }
    }

    private static let seedAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 17.0), .foregroundColor: UIColor.label,
    ]

    private func blocks(_ strings: [String] = ["Hello"]) -> [NSAttributedString] {
        strings.map { NSAttributedString(string: $0, attributes: Self.seedAttributes) }
    }

    private struct Fixture {
        let host: ModelFakeHost
        let backend: IDUpstreamInputBackend
    }

    private func makeAttached(
        _ strings: [String] = ["Hello"],
        policy: RichTextInputEditPolicy = .legacyUnrestricted
    ) throws -> Fixture {
        let host = ModelFakeHost(log: RichTextInputEventLog())
        window.addSubview(host.container)
        let backend = IDUpstreamInputBackend(attributedBlocks: blocks(strings), editPolicy: policy)
        try backend.attach(to: host)
        host.container.layoutIfNeeded()
        return Fixture(host: host, backend: backend)
    }

    private func engine(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line)
        throws -> IDBlockTextView
    {
        try XCTUnwrap(fixture.backend.engineHostForTesting, "no engine host", file: file, line: line)
    }

    /// A raw `IDBlockTextView` inside a container, without the adapter — used by the evidence and
    /// rejected-wiring suites, which are about UIKit's behaviour rather than the adapter's.
    private func makeRawEngine(container: UIView, editable: Bool = true, selectable: Bool = true)
        -> IDBlockTextView
    {
        window.addSubview(container)
        let view = IDBlockTextView(frame: container.bounds, attributedBlocks: blocks())
        view.isEditable = editable
        view.isSelectable = selectable
        container.addSubview(view)
        container.layoutIfNeeded()
        return view
    }

    // MARK: - Readings

    private func boolReading(_ view: UIView, _ selectorName: String) -> (responds: Bool, value: Bool) {
        let selector = NSSelectorFromString(selectorName)
        guard view.responds(to: selector) else { return (false, false) }
        typealias BoolGetter = @convention(c) (AnyObject, Selector) -> Bool
        let getter = unsafeBitCast(view.method(for: selector), to: BoolGetter.self)
        return (true, getter(view, selector))
    }

    /// Everything is CAPTURED into this before anything is asserted, so a failure reports the state
    /// the responder was actually in rather than a state re-derived after the fact.
    private struct Reading: Equatable {
        var isFirstResponder = false
        var respondsToKeyboardRequirement = false
        var requiresKeyboard = false
        var respondsToIsEditable = false
        var isEditable = false
        var hasInputDelegate = false
    }

    private func read(_ view: UIView, inputDelegateOf engine: IDBlockTextView? = nil) -> Reading {
        var reading = Reading()
        reading.isFirstResponder = view.isFirstResponder
        let requirement = boolReading(view, "_requiresKeyboardWhenFirstResponder")
        reading.respondsToKeyboardRequirement = requirement.responds
        reading.requiresKeyboard = requirement.value
        let editable = boolReading(view, "isEditable")
        reading.respondsToIsEditable = editable.responds
        reading.isEditable = editable.value
        reading.hasInputDelegate = (engine ?? (view as? IDBlockTextView))?.inputDelegate != nil
        return reading
    }

    /// The CLASS of whatever UIKit bound as `inputDelegate`, or `""` — review Minor 5: the model's
    /// second deciding reading was recorded in prose as "`_UIKeyboardStateManager` vs nil" and
    /// asserted only as non-nil/nil, so the half that gives the reading its MEANING (that the bound
    /// object is the KEYBOARD's state machine, not some unrelated observer) was untested.
    ///
    /// Asserted as a substring rather than as the exact private symbol: pinning `_UIKeyboardStateManager`
    /// would turn a private-class rename into a red test that says nothing about the model, while
    /// "UIKit bound something keyboard-shaped" is exactly the claim being made. Observed in full on
    /// iOS 26.5 (23F73): `_UIKeyboardStateManager`.
    private func inputDelegateClassName(_ engine: IDBlockTextView) -> String {
        guard let delegate = engine.inputDelegate else { return "" }
        return String(describing: type(of: delegate))
    }

    // MARK: - 1. The evidence for the model

    /// **THE READING, CALIBRATED.** `-_requiresKeyboardWhenFirstResponder` tracks `-isEditable`
    /// exactly on two real `UITextView`s, which is what makes it a usable stand-in for "a keyboard
    /// will be raised" in a process where the keyboard cannot appear. Re-calibrated here rather than
    /// inherited from `IDKeyboardActivationTests`, because a reading is only as good as the control
    /// taken in the same process on the same OS build.
    ///
    /// The last assertion pins the instrument that does NOT work, so nobody builds on it.
    func test_calibrationTheKeyboardReadingTracksEditabilityAndTheNotificationNeverFires() {
        let editableView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        editableView.isEditable = true
        let readOnlyView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        readOnlyView.isEditable = false
        window.addSubview(editableView)
        window.addSubview(readOnlyView)

        var sawKeyboard = false
        let token = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil
        ) { _ in sawKeyboard = true }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertTrue(editableView.becomeFirstResponder())
        let editable = read(editableView)
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline && !sawKeyboard {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        let sawKeyboardForEditable = sawKeyboard

        XCTAssertTrue(readOnlyView.becomeFirstResponder(),
                      "a read-only UITextView still takes first responder — that is the whole point "
                      + "of it as the control for 'caret yes, keyboard no'")
        let readOnly = read(readOnlyView)

        XCTAssertTrue(editable.respondsToKeyboardRequirement,
                      "the private keyboard-requirement reading this file depends on is gone; every "
                      + "assertion below is now unanchored")
        XCTAssertTrue(editable.isEditable)
        XCTAssertTrue(editable.requiresKeyboard, "an editable UITextView must want a keyboard")
        XCTAssertFalse(readOnly.isEditable)
        XCTAssertFalse(readOnly.requiresKeyboard, "a read-only UITextView must not want a keyboard")

        XCTAssertFalse(sawKeyboardForEditable,
                       "keyboardWillShowNotification now fires in this test host — the reason this "
                       + "file uses a private reading instead has expired; promote it to the real "
                       + "end-to-end assertion")
    }

    /// **THE FINDING.** With the ENGINE holding the role UIKit is told a keyboard is needed and binds
    /// `inputDelegate`; with a host view holding it instead, neither happens.
    ///
    /// The host reading is the read-only-`UITextView` shape from the calibration above, which is the
    /// user-visible defect this programme already shipped once (`../DIVERGENCES.md` entry 20, task
    /// F2: "the flag took first responder, drew a caret, and never raised a keyboard").
    func test_onlyTheEngineHoldingTheRoleAsksForAKeyboardAndGetsAnInputDelegate() {
        let container = ClaimingContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = makeRawEngine(container: container)

        XCTAssertTrue(engineView.becomeFirstResponder())
        let engineHolds = read(engineView)
        let engineDelegateClass = inputDelegateClassName(engineView)
        let containerWhileEngineHolds = read(container, inputDelegateOf: engineView)

        XCTAssertTrue(container.becomeFirstResponder(), "the host stole the role, as arranged")
        let hostHolds = read(container, inputDelegateOf: engineView)
        let engineWhileHostHolds = read(engineView)

        // Review Minor 5 — THE OTHER DIRECTION, which the phase-3 report claimed and the file did
        // not do: the engine steals the role BACK from a host that is holding it, and the bindings
        // move with it. Without this leg "measured in both directions" was an overstatement.
        XCTAssertTrue(engineView.becomeFirstResponder(), "the engine stole the role back")
        let engineHoldsAgain = read(engineView)
        let hostAfterLosingIt = read(container, inputDelegateOf: engineView)

        XCTAssertEqual(engineHolds, Reading(isFirstResponder: true,
                                            respondsToKeyboardRequirement: true,
                                            requiresKeyboard: true,
                                            respondsToIsEditable: true,
                                            isEditable: true,
                                            hasInputDelegate: true),
                       "the engine holding the first-responder role is the only configuration in "
                       + "which UIKit is told a keyboard is needed AND binds an input delegate")
        XCTAssertTrue(engineDelegateClass.contains("Keyboard"),
                      "the bound inputDelegate is what makes this reading MEAN 'the keyboard is "
                      + "talking to this object'; UIKit bound a \(engineDelegateClass) instead "
                      + "(iOS 26.5 binds _UIKeyboardStateManager)")
        XCTAssertFalse(containerWhileEngineHolds.isFirstResponder)

        XCTAssertTrue(hostHolds.isFirstResponder)
        // Review Minor 1 — WITHOUT THIS LINE the deciding contrast can go silently vacuous. The
        // reading collapses "does not respond to the selector" into `value == false`, so on an OS
        // where `-_requiresKeyboardWhenFirstResponder` left UIResponder this test would keep passing
        // on a reading that no longer exists. The engine leg is already protected by the full-struct
        // equality above; this is the host leg.
        XCTAssertTrue(hostHolds.respondsToKeyboardRequirement,
                      "the host view no longer answers -_requiresKeyboardWhenFirstResponder at all, "
                      + "so the false below is the ABSENCE of a reading rather than a reading of "
                      + "false, and this file's whole contrast is an artifact")
        XCTAssertFalse(hostHolds.requiresKeyboard,
                       "a host view holding the role is a read-only UITextView as far as UIKit is "
                       + "concerned: first responder, caret, NO KEYBOARD")
        XCTAssertFalse(engineWhileHostHolds.isFirstResponder)
        XCTAssertFalse(engineWhileHostHolds.hasInputDelegate,
                       "with the host holding the role the engine has no inputDelegate, so marked "
                       + "text, autocorrect, prediction and shift state have no channel at all")

        XCTAssertEqual(engineHoldsAgain, engineHolds,
                       "stealing the role back must restore the engine's reading exactly — the "
                       + "bindings follow the role in BOTH directions, not just on the way out")
        XCTAssertFalse(hostAfterLosingIt.isFirstResponder)
    }

    /// **ANTI-VACUITY FOR THE FINDING — the wrong answer is SILENT.** With the host holding the role
    /// the document still mutates on `insertText`, so nothing in the editor's own state distinguishes
    /// the working configuration from the dead one. That is why the two readings above had to be
    /// private-API readings rather than an observable behaviour.
    func test_typingStillMutatesTheDocumentWhileTheHostHoldsTheRole_soTheFailureIsSilent() {
        let container = ClaimingContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = makeRawEngine(container: container)
        XCTAssertTrue(container.becomeFirstResponder())

        engineView.insertText("Y")
        let blocks = engineView.attributedBlocks.map(\.string)
        let hadInputDelegate = engineView.inputDelegate != nil

        XCTAssertEqual(blocks, ["YHello"],
                       "if this ever stops mutating, the dead configuration became observable and "
                       + "this file's private readings could be replaced by an ordinary assertion")
        XCTAssertFalse(hadInputDelegate)
    }

    // MARK: - 2. The three wirings that were built and rejected

    /// **W1 — redirect from `hostWillBecomeFirstResponder()` while the host still claims the role.**
    /// The host's own `super.becomeFirstResponder()` runs afterwards and takes the role straight
    /// back. Dead keyboard, and `becomeFirstResponder()` answers `true`.
    func test_rejectedWiring1_redirectingBeforeSuperLetsTheHostTakeTheRoleBack() {
        let container = ClaimingContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = makeRawEngine(container: container)
        container.claims = true
        container.onWillBecome = { _ = engineView.becomeFirstResponder() }

        let became = container.becomeFirstResponder()
        let host = read(container, inputDelegateOf: engineView)
        let engineReading = read(engineView)

        XCTAssertTrue(became, "the caller is told focus succeeded")
        XCTAssertTrue(host.isFirstResponder)
        XCTAssertFalse(engineReading.isFirstResponder, "the engine lost the role it was just given")
        XCTAssertFalse(engineReading.hasInputDelegate)
        XCTAssertFalse(host.requiresKeyboard, "…and there is no keyboard, silently")
    }

    /// **W2 — the same redirect, with the host declining the role so `super` cannot take it.** The
    /// end state is right and the RETURN VALUE is a lie: focus succeeded and the caller is told it
    /// failed, and `hostDidFailToBecomeFirstResponder()` fires on every success.
    func test_rejectedWiring2_decliningTheRoleMakesBecomeFirstResponderAnswerFalse() {
        let container = ClaimingContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = makeRawEngine(container: container)
        container.claims = false
        container.onWillBecome = { _ = engineView.becomeFirstResponder() }
        container.trace = []

        let became = container.becomeFirstResponder()
        let trace = container.trace
        let engineReading = read(engineView)

        XCTAssertTrue(engineReading.isFirstResponder)
        XCTAssertTrue(engineReading.hasInputDelegate)
        XCTAssertFalse(became,
                       "focus in fact succeeded; a host wired this way reports failure to its caller")
        XCTAssertTrue(trace.contains("backend.hostDidFailToBecome"),
                      "the did-fail hook fires on every SUCCESSFUL focus: \(trace)")
    }

    /// **W3 — the hand-off: let the host take the role, then take it from it in
    /// `hostDidBecomeFirstResponder()`.** The end state is right; the cost is a complete RESIGN cycle
    /// nested inside the BECOME cycle, on every focus including a repeat one.
    ///
    /// Against a real `DocumentCanvasView` that nesting is `backendDidEndEditing()` inside
    /// `backendDidBeginEditing()` — and the chat composer focuses the editor on every touch-DOWN
    /// (`DocumentCanvasView.legacyMarkDidJustBecomeFirstResponder()`'s own note), so it is not a
    /// once-per-session cost.
    func test_rejectedWiring3_theHandOffNestsAFullResignCycleInsideEveryBecome() {
        let container = ClaimingContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = makeRawEngine(container: container)
        container.claims = true
        container.onDidBecome = { _ = engineView.becomeFirstResponder() }
        container.trace = []

        let became = container.becomeFirstResponder()
        let firstFocus = container.trace
        container.trace = []
        let again = container.becomeFirstResponder()
        let repeatFocus = container.trace
        let engineReading = read(engineView)

        XCTAssertTrue(became)
        XCTAssertTrue(again)
        XCTAssertTrue(engineReading.isFirstResponder, "the end state IS correct — that is the trap")
        XCTAssertTrue(engineReading.hasInputDelegate)

        XCTAssertEqual(firstFocus, ["host.become ENTER",
                                    "host.super.become=true",
                                    "host.resign ENTER",
                                    "host.super.resign=true",
                                    "host.resign EXIT true",
                                    "host.become EXIT true"],
                       "the resign cycle must appear NESTED inside the become cycle")
        XCTAssertEqual(repeatFocus, firstFocus,
                       "a repeat focus on an already-focused editor pays the same cost again")
    }

    // MARK: - 3. What the seven implemented requirements forward

    /// `canBecomeFirstResponder` is the engine's live gate
    /// (`userInteractionEnabled && (isEditable || isSelectable)`), not Legacy's literal `true`.
    /// Asserted across the whole matrix, so a constant cannot pass.
    func test_canBecomeFirstResponderIsTheEnginesLiveGateAndNotAConstant() throws {
        var answers: [String: Bool] = [:]
        for (editable, selectable) in [(true, true), (false, true), (true, false), (false, false)] {
            let fixture = try makeAttached(policy: RichTextInputEditPolicy(
                isEditable: editable, isSelectable: selectable, allowsRichText: true,
                allowsPaste: true, allowsDictation: true, allowsWritingTools: true))
            answers["e=\(editable) s=\(selectable)"] = fixture.backend.canBecomeFirstResponder
        }
        let userInteractionOff = try makeAttached()
        try engine(userInteractionOff).isUserInteractionEnabled = false
        answers["userInteractionEnabled=false"] = userInteractionOff.backend.canBecomeFirstResponder

        XCTAssertEqual(answers, ["e=true s=true": true,
                                 "e=false s=true": true,
                                 "e=true s=false": false,
                                 "e=false s=false": false,
                                 "userInteractionEnabled=false": false],
                       "this is the ENGINE's gate; a Telegram-side `true` (which is what Legacy's "
                       + "identical member is) would have answered true five times")
    }

    /// **REVIEW MINOR 2 — the `(t,f)` row of the matrix above is NOT what the gate's formula predicts,
    /// and the difference is an ordering dependency inside `attach(to:)`.**
    ///
    /// `canBecomeFirstResponder` is `userInteractionEnabled && (isEditable || isSelectable)`
    /// (`IDBlockTextView.m:412`), which for `editable = true, selectable = false` says `true`. It
    /// measures `false` because `-[IDBlockTextView setSelectable:NO]` FORCE-CLEARS `_editable`
    /// (`IDBlockTextView.m:446-450`) — so by the time the gate is asked, the engine's state is
    /// `(f,f)`, not `(t,f)`. And it is `(f,f)` only because `attach(to:)` assigns `isEditable` BEFORE
    /// `isSelectable`.
    ///
    /// This measures the dependency directly, by driving the SAME policy in both orders on a raw
    /// engine. The consequence for the record: the phase-3 headline "the engine's gate differs from
    /// Legacy's constant `true` in THREE of five configurations" is **two of five on engine state
    /// alone** — `(f,f)` and `isUserInteractionEnabled = false`. Those two carry the conclusion
    /// (the gate is live, not a constant) on their own, so nothing downstream moves.
    ///
    /// It is also a standing warning: a future reader who "tidies" the two assignment lines in
    /// `attach(to:)` into the other order turns the matrix test red, and without this test there is
    /// nothing anywhere that explains why.
    func test_theEditableSelectableOrderingInAttachIsWhatMakesTheTFRowFalse() {
        func gate(assigningEditableFirst editableFirst: Bool) -> [String: Bool] {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            window.addSubview(container)
            let view = IDBlockTextView(frame: container.bounds, attributedBlocks: blocks())
            if editableFirst {
                view.isEditable = true
                view.isSelectable = false
            } else {
                view.isSelectable = false
                view.isEditable = true
            }
            container.addSubview(view)
            return ["isEditable": view.isEditable,
                    "isSelectable": view.isSelectable,
                    "canBecomeFirstResponder": view.canBecomeFirstResponder]
        }

        let attachOrder = gate(assigningEditableFirst: true)
        let reversed = gate(assigningEditableFirst: false)

        XCTAssertEqual(attachOrder, ["isEditable": false, "isSelectable": false,
                                     "canBecomeFirstResponder": false],
                       "attach(to:)'s order: setSelectable(false) force-cleared the editable flag "
                       + "that was assigned a line earlier, so the engine never held (t,f) at all")
        XCTAssertEqual(reversed, ["isEditable": true, "isSelectable": false,
                                  "canBecomeFirstResponder": true],
                       "the SAME policy in the other order leaves a genuine (t,f) — and the gate "
                       + "answers TRUE for it, exactly as its formula says. The matrix row is about "
                       + "attach(to:)'s assignment order, not about the gate")
    }

    // MARK: - 4. PHASE 3b — the responder hand-off

    /// **W4, as a contract member.** `acquireFirstResponder()` puts the ENGINE in the role — which is
    /// the entire point of the model — and every reading that phase 3 measured moves with it: the
    /// engine wants a keyboard, UIKit binds its `inputDelegate`, and the HOST view does not hold the
    /// role at any point.
    ///
    /// Contrast this with the three rejected wirings above: no dead keyboard (W1), no `false` returned
    /// on a success (W2), and no resign cycle nested inside the become (W3).
    func test_acquireFirstResponderPutsTheEngineInTheRoleAndTheKeyboardReadingFollowsIt() throws {
        let fixture = try makeAttached()
        let engineView = try engine(fixture)

        let before = read(engineView)
        let outcome = fixture.backend.acquireFirstResponder()
        let after = read(engineView)
        let hostAfter = read(fixture.host.container, inputDelegateOf: engineView)
        let delegateClass = inputDelegateClassName(engineView)

        XCTAssertEqual(outcome, .performedByBackend(succeeded: true),
                       "the backend must report that IT performed the transition, and that it worked")
        XCTAssertFalse(before.isFirstResponder)
        XCTAssertEqual(after, Reading(isFirstResponder: true,
                                      respondsToKeyboardRequirement: true,
                                      requiresKeyboard: true,
                                      respondsToIsEditable: true,
                                      isEditable: true,
                                      hasInputDelegate: true),
                       "the engine must end in the ONE configuration UIKit raises a keyboard for")
        XCTAssertTrue(delegateClass.contains("Keyboard"), "bound \(delegateClass)")
        XCTAssertFalse(hostAfter.isFirstResponder,
                       "the HOST must never hold the role under this backend — that is the whole "
                       + "model, and it is the configuration measured to have no keyboard")
        XCTAssertEqual(fixture.backend.recordedViolations, [])
    }

    /// **Idempotent on a repeat focus, and that is why W4 was chosen over W3.** The chat composer
    /// focuses the editor on every touch-DOWN, so a tap on an already-focused editor re-enters this
    /// member. It must be a bare forward: no resign, no re-entry, no extra transition work.
    ///
    /// Measured from the ENGINE's own transition callbacks rather than from the return value, because
    /// W3's defect was invisible in the return value (it answered `true` both times) and showed up
    /// only in the trace.
    func test_acquireIsIdempotentOnARepeatFocusAndNestsNoResignCycle() {
        final class TracingEngine: IDBlockTextView {
            var trace: [String] = []
            override func becomeFirstResponder() -> Bool {
                trace.append("become ENTER")
                let became = super.becomeFirstResponder()
                trace.append("become EXIT \(became)")
                return became
            }
            override func resignFirstResponder() -> Bool {
                trace.append("resign ENTER")
                let resigned = super.resignFirstResponder()
                trace.append("resign EXIT \(resigned)")
                return resigned
            }
        }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window.addSubview(container)
        let engineView = TracingEngine(frame: container.bounds, attributedBlocks: blocks())
        engineView.isEditable = true
        engineView.isSelectable = true
        container.addSubview(engineView)

        // The member's body, verbatim — the adapter cannot be pointed at a subclassed engine, so the
        // forward it performs is reproduced here and the ENGINE's behaviour is what is measured.
        _ = engineView.becomeFirstResponder()
        engineView.trace = []
        let second = engineView.becomeFirstResponder()
        let repeatTrace = engineView.trace

        XCTAssertTrue(second, "a repeat become on the holder answers true")
        XCTAssertEqual(repeatTrace, ["become ENTER", "become EXIT true"],
                       "a repeat focus must cost exactly one become and NOTHING else — W3's hand-off "
                       + "produced a full resign cycle here, on every composer touch-down")
        XCTAssertTrue(engineView.isFirstResponder)
    }

    /// `relinquishFirstResponder()` gives the role back, and its `false` is ROUTINE rather than a
    /// decline — `UIResponder.resignFirstResponder()` answers `false` whenever the receiver did not
    /// hold the role. That is why the outcome travels INSIDE `.performedByBackend` instead of being a
    /// third case: a caller must not be able to read "it did not work" as "the host owns the role".
    func test_relinquishGivesTheRoleBackAndItsFalseIsRoutineNotADecline() throws {
        let fixture = try makeAttached()
        let engineView = try engine(fixture)

        XCTAssertEqual(fixture.backend.acquireFirstResponder(), .performedByBackend(succeeded: true))
        let whileHolding = read(engineView)
        let released = fixture.backend.relinquishFirstResponder()
        let afterRelease = read(engineView)
        let releasedAgain = fixture.backend.relinquishFirstResponder()

        XCTAssertTrue(whileHolding.isFirstResponder)
        XCTAssertEqual(released, .performedByBackend(succeeded: true))
        XCTAssertFalse(afterRelease.isFirstResponder)
        XCTAssertFalse(afterRelease.hasInputDelegate,
                       "UIKit unbinds the inputDelegate with the role")
        XCTAssertEqual(releasedAgain, .performedByBackend(succeeded: false),
                       "resigning twice answers false, and the CASE must stay .performedByBackend — "
                       + "collapsing that into .hostOwnsTheRole would tell the host to take the role "
                       + "under a backend that must never let it")
        XCTAssertEqual(fixture.backend.recordedViolations, [])
    }

    /// Both hand-off members obey the family invariant: with no engine there is nothing to hand the
    /// role to, so each reports by name rather than answering plausibly. (`false` inside
    /// `.performedByBackend` is the inert value its type admits, and it is reached ONLY after the
    /// report — never silently.)
    func test_bothHandOffMembersReportWhileDetached() throws {
        let fixture = try makeAttached()
        let backend = fixture.backend
        backend.detach()

        let baseline = backend.recordedViolations.count
        let acquired = backend.acquireFirstResponder()
        let relinquished = backend.relinquishFirstResponder()
        let reports = Array(backend.recordedViolations.suffix(from: baseline))

        XCTAssertEqual(acquired, .performedByBackend(succeeded: false))
        XCTAssertEqual(relinquished, .performedByBackend(succeeded: false))
        XCTAssertEqual(reports.count, 2, "\(reports)")
        XCTAssertTrue(reports[0].contains("acquireFirstResponder()"), reports[0])
        XCTAssertTrue(reports[1].contains("relinquishFirstResponder()"), reports[1])
    }

    /// `canResignFirstResponder` is read off the engine. `IDBlockTextView` does not override it, so
    /// the value is UIKit's — and it is still the engine's answer, which is the point.
    func test_canResignFirstResponderIsReadOffTheEngine() throws {
        let fixture = try makeAttached()
        let engineView = try engine(fixture)
        XCTAssertEqual(fixture.backend.canResignFirstResponder, engineView.canResignFirstResponder)
        XCTAssertTrue(fixture.backend.canResignFirstResponder)
    }

    /// **`isEditableForWritingTools` is the member the dead-keyboard defect was**, and it now comes
    /// from the engine. This asserts it moves together with the keyboard reading — the three facts
    /// (`-isEditable`, `-_requiresKeyboardWhenFirstResponder`, `inputDelegate`) are one state, held
    /// by the engine, and forwarding is what makes Telegram's answer agree with it.
    func test_isEditableForWritingToolsIsTheEnginesEditabilityAndMovesWithTheKeyboardReading() throws {
        let editableFixture = try makeAttached()
        let editableEngine = try engine(editableFixture)
        XCTAssertTrue(editableEngine.becomeFirstResponder())
        let editableAnswer = editableFixture.backend.isEditableForWritingTools
        let editableReading = read(editableEngine)

        let readOnlyFixture = try makeAttached(policy: RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true))
        let readOnlyEngine = try engine(readOnlyFixture)
        XCTAssertTrue(readOnlyEngine.becomeFirstResponder(),
                      "a selectable-but-not-editable engine still takes the role — the control")
        let readOnlyAnswer = readOnlyFixture.backend.isEditableForWritingTools
        let readOnlyReading = read(readOnlyEngine)

        XCTAssertTrue(editableAnswer)
        XCTAssertTrue(editableReading.requiresKeyboard)
        XCTAssertTrue(editableReading.hasInputDelegate)

        XCTAssertFalse(readOnlyAnswer,
                       "Legacy's identical member is the literal `true`; copying it here would have "
                       + "made this answer disagree with the engine's own state")
        XCTAssertFalse(readOnlyReading.requiresKeyboard)
        XCTAssertFalse(readOnlyReading.hasInputDelegate)
    }

    /// `undoManager` is the engine's own instance, by identity — not a manager minted here, and not
    /// the `nil` phase 2 answered.
    func test_undoManagerIsTheEnginesOwnInstance() throws {
        let fixture = try makeAttached()
        let engineView = try engine(fixture)
        let vended = try XCTUnwrap(fixture.backend.undoManager,
                                   "the engine has a real NSUndoManager; nil would be a lie about it")
        XCTAssertTrue(vended === engineView.undoManager)
    }

    /// `canPerformCommand` forwards the six commands that have a selector to
    /// `canPerformAction:withSender:`, and the answers move with the engine's state. Captured as a
    /// table before anything is asserted, and compared against the engine directly.
    func test_canPerformCommandForwardsEveryMappedCommandToTheEnginesOwnAnswer() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let engineView = try engine(fixture)
        XCTAssertTrue(engineView.becomeFirstResponder())

        let commands: [(String, RichTextInputCommand)] = [
            ("cut", .cut), ("copy", .copy), ("paste", .paste), ("selectWord", .selectWord),
            ("selectAll", .selectAll), ("delete", .delete),
        ]
        func snapshot() -> [String: Bool] {
            var out: [String: Bool] = [:]
            for (name, command) in commands { out[name] = backend.canPerformCommand(command, sender: nil) }
            return out
        }
        func engineSnapshot() throws -> [String: Bool] {
            var out: [String: Bool] = [:]
            for (name, command) in commands {
                let selector = try XCTUnwrap(IDUpstreamInputBackend.editActionSelector(for: command))
                out[name] = engineView.canPerformAction(selector, withSender: nil)
            }
            return out
        }

        let caret = snapshot()
        let caretOracle = try engineSnapshot()
        let start = engineView.beginningOfDocument
        let selectionEnd = try XCTUnwrap(engineView.position(from: start, offset: 3))
        engineView.selectedTextRange = engineView.textRange(from: start, to: selectionEnd)
        let selected = snapshot()
        let selectedOracle = try engineSnapshot()

        XCTAssertEqual(caret, caretOracle, "an answer diverged from the engine's own")
        XCTAssertEqual(selected, selectedOracle, "an answer diverged from the engine's own")
        // Anti-vacuity: the two snapshots must actually differ, or "tracks the engine" is untested,
        // and a constant would satisfy both equalities above.
        XCTAssertEqual(caret["copy"], false)
        XCTAssertEqual(caret["cut"], false)
        XCTAssertEqual(caret["selectAll"], true)
        XCTAssertEqual(selected["copy"], true)
        XCTAssertEqual(selected["cut"], true)
        XCTAssertEqual(selected["selectAll"], false)
    }

    /// `performCommand` sends the five the engine implements. `.selectAll` is the one with an
    /// observable effect that needs no global state (the pasteboard is shared across the process, so
    /// `.copy`/`.cut` are deliberately not driven here).
    func test_performCommandReachesTheEngineForACommandItImplements() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let engineView = try engine(fixture)
        XCTAssertTrue(engineView.becomeFirstResponder())
        let before = backend.recordedViolations.count

        backend.performCommand(.selectAll, sender: nil)

        let selection = backend.canonicalSelection
        XCTAssertEqual(backend.recordedViolations.count, before,
                       "a command the engine implements must not report: "
                       + "\(backend.recordedViolations.suffix(3))")
        XCTAssertEqual(selection.anchor.utf16Offset, 0)
        XCTAssertEqual(selection.head.utf16Offset, 5, "selectAll did not reach the engine")
    }

    /// **The two shapes of "no forward", each reported by name.**
    ///
    ///  * `.delete` HAS a selector and the engine does not implement it — measured
    ///    `responds(to:) == false`. Every `UIResponderStandardEditActions` member is `@optional`, so
    ///    calling it anyway would be a silent no-op rather than a crash, which is why the
    ///    `responds(to:)` guard is the load-bearing line and not defensive decoration.
    ///  * `.undo` / `.redo` have no selector on this contract at all
    ///    (`UIResponderStandardEditActions` declares neither), so BOTH members report — unlike
    ///    `.delete`, whose `canPerformCommand` still forwards.
    func test_theTwoShapesOfNoForwardAreEachReportedByName() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let engineView = try engine(fixture)
        XCTAssertTrue(engineView.becomeFirstResponder())

        let deleteSelector = try XCTUnwrap(IDUpstreamInputBackend.editActionSelector(for: .delete))
        let engineImplementsDelete = engineView.responds(to: deleteSelector)
        let undoSelector = IDUpstreamInputBackend.editActionSelector(for: .undo)
        let redoSelector = IDUpstreamInputBackend.editActionSelector(for: .redo)

        var reports: [String: [String]] = [:]
        func capture(_ label: String, _ body: () -> Void) {
            let before = backend.recordedViolations.count
            body()
            reports[label] = Array(backend.recordedViolations.suffix(from: before))
        }
        capture("perform.delete") { backend.performCommand(.delete, sender: nil) }
        capture("perform.undo") { backend.performCommand(.undo, sender: nil) }
        capture("perform.redo") { backend.performCommand(.redo, sender: nil) }
        capture("canPerform.delete") { _ = backend.canPerformCommand(.delete, sender: nil) }
        capture("canPerform.undo") { _ = backend.canPerformCommand(.undo, sender: nil) }

        XCTAssertFalse(engineImplementsDelete,
                       "the engine grew a delete: body — the guard now sends it and this test should "
                       + "become a positive one instead")
        XCTAssertNil(undoSelector)
        XCTAssertNil(redoSelector)

        XCTAssertEqual(reports["perform.delete"]?.count, 1)
        XCTAssertEqual(reports["perform.undo"]?.count, 1)
        XCTAssertEqual(reports["perform.redo"]?.count, 1)
        XCTAssertEqual(reports["canPerform.undo"]?.count, 1)
        XCTAssertEqual(reports["canPerform.delete"], [],
                       "canPerformCommand(.delete) HAS a forward and must stay silent — that "
                       + "asymmetry with performCommand(.delete) is the point of this test")
        XCTAssertTrue(reports["perform.delete"]?.first?.contains("delete:") == true,
                      "\(reports["perform.delete"] ?? [])")
        XCTAssertTrue(reports["canPerform.undo"]?.first?.contains("undo") == true,
                      "\(reports["canPerform.undo"] ?? [])")
    }

    /// The adapter's selector map is the inverse of the package's own `richTextInputCommand(for:)`,
    /// so the two cannot drift — including on the two commands NEITHER of them maps.
    func test_theCommandSelectorMapIsTheInverseOfThePackagesOwn() throws {
        for command in [RichTextInputCommand.cut, .copy, .paste, .selectWord, .selectAll, .delete] {
            let selector = try XCTUnwrap(IDUpstreamInputBackend.editActionSelector(for: command),
                                         "\(command) lost its selector")
            XCTAssertEqual(richTextInputCommand(for: selector), command,
                           "\(command) does not round-trip through \(NSStringFromSelector(selector))")
        }
        for command in [RichTextInputCommand.undo, .redo] {
            XCTAssertNil(IDUpstreamInputBackend.editActionSelector(for: command),
                         "\(command) grew a selector here; the package's forward map still does not "
                         + "have one, so the two have drifted")
        }
    }

    /// **The justification for `hostWillMove(toWindow:)` being a no-op.** UIKit delivers the window
    /// change to the engine even though the change was made to the HOST, so the engine's own
    /// `didMoveToWindow` (which cancels its vertical autoscroll session when the window is nil) runs
    /// without anything on this side forwarding it. Recorded from a subclass, so the callback itself
    /// is observed rather than inferred from `engine.window`.
    ///
    /// The responder half is measured in the same test: removing the host takes first responder and
    /// the `inputDelegate` away from the engine, again with nothing on this side asking.
    func test_theEngineLearnsAboutAWindowChangeMadeToTheHost() {
        final class TracingEngine: IDBlockTextView {
            var moves: [String] = []
            override func didMoveToWindow() {
                super.didMoveToWindow()
                moves.append(window == nil ? "nil" : "window")
            }
        }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let engineView = TracingEngine(frame: container.bounds, attributedBlocks: blocks())
        engineView.isEditable = true
        engineView.isSelectable = true
        container.addSubview(engineView)
        let beforeWindow = engineView.moves

        window.addSubview(container)
        container.layoutIfNeeded()
        XCTAssertTrue(engineView.becomeFirstResponder())
        let focused = read(engineView)

        container.removeFromSuperview()
        let afterRemoval = read(engineView)
        let moves = engineView.moves

        XCTAssertEqual(beforeWindow, [],
                       "parenting into a window-less container announces nothing, so the ['window'] "
                       + "entry below really is the host entering the window")
        XCTAssertEqual(moves, ["window", "nil"],
                       "the engine did NOT receive the host's window change — hostWillMove(toWindow:) "
                       + "being a no-op depends entirely on this")
        XCTAssertTrue(focused.isFirstResponder)
        XCTAssertTrue(focused.hasInputDelegate)
        XCTAssertFalse(afterRemoval.isFirstResponder)
        XCTAssertFalse(afterRemoval.hasInputDelegate)
    }

    /// …and the member itself therefore does nothing, loudly documented rather than quietly empty.
    func test_hostWillMoveIsSilentWhileAttachedAndReportsWhileDetached() throws {
        let fixture = try makeAttached()
        let backend = fixture.backend
        let attachedBaseline = backend.recordedViolations.count
        backend.hostWillMove(toWindow: nil)
        backend.hostWillMove(toWindow: window)
        let whileAttached = backend.recordedViolations.count - attachedBaseline

        backend.detach()
        let detachedBaseline = backend.recordedViolations.count
        backend.hostWillMove(toWindow: nil)
        let whileDetached = backend.recordedViolations.count - detachedBaseline

        XCTAssertEqual(whileAttached, 0,
                       "a contract violation on a routine UIView lifecycle event trains a reader to "
                       + "ignore the channel this whole phase rests on")
        XCTAssertEqual(whileDetached, 1,
                       "the family invariant is that every member reports when there is no engine")
    }
}
#endif
