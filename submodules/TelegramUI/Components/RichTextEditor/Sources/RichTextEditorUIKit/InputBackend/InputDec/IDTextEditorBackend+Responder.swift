#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task C10 — Family 7 (responder commands and clipboard). Two `RichTextInputResponderBackend`
/// witnesses: `canPerformCommand(_:sender:)`, `performCommand(_:sender:)`.
///
/// **Deliberate divergence from upstream InputDec (recorded in `DIVERGENCES.md`, entry 10).**
/// Upstream InputDec routes `cut:`/`copy:`/`paste:` straight into the real private
/// `UITextInputController` (`-cut:`/`-copy:`/`-paste:` on `IDUIKitInputControllerCapability
/// .activeController`), which would let the private controller mutate Telegram's document directly
/// — forbidden by this seam's own architecture (every mutation goes through
/// `RichTextInputDocumentClient.prepareMutation`/`commitPreparedMutation`, never a side channel).
/// So `performCommand(_:sender:)` below routes every command through `RichTextInputCommandClient
/// .prepare`/`.commit` instead of `kernelInput?.performCut(_:)`/`.performCopy(_:)`/`.performPaste(_:)`
/// — none of those three kernel witnesses is ever called, despite being named in the task's own
/// `Consumes (kernel)` interface list; see `DIVERGENCES.md` for the full reasoning. The ONE kernel
/// witness that IS consulted is `IDUIKitInputControllerCapability.shouldHandlePasteAction(_:sender:)`,
/// and only for the *availability* question that is genuinely UIKit's to answer (what pasteboard
/// representation types the system edit menu should offer) — never to perform anything.
///
/// **`.capabilityPaste` does not compile — `.paste` is correct**, the same `IDUIKitBehaviorCapability`
/// prefix-stripping shape as `.inputController`/`.typingAttributes`/`.incomingCallbacks`/`.prediction`
/// before it (C0, C9). `.paste` sits in `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames`
/// loop (alongside `.prediction`, `.checking`, `.typingAttributes`, `.dictation`) — confirmed by
/// reading the kernel source directly (`IDUIKitBehaviorKernel.m:260-299`): that loop never `[input
/// detach]`s or throws on a rejected contract, unlike the single `declarativeCapabilityNames =
/// @[@"incomingCallbacks"]` entry earlier in the same initializer. So requesting `.paste`
/// unconditionally cannot move the `incomingCallbacks` mismatch count or the attach failure text —
/// both re-measured unchanged in this task's report, exactly as C9 found for `.prediction`.
@available(iOS 17.0, *)
extension IDTextEditorBackend {

    // MARK: - `RichTextInputResponderBackend` — Family 7: responder commands and clipboard

    /// The witness `DocumentCanvasView.canPerformAction(_:withSender:)` (shared by both backends)
    /// routes into after mapping a `Selector` to a `RichTextInputCommand` via `richTextInputCommand(for:)`.
    ///
    /// Detached: `false` for every command — the safe, non-offering direction (a menu item greys out
    /// rather than being offered by a responder that cannot perform it), matching every other
    /// detached-Bool-getter answer in this file.
    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        guard isAttached, let host else { return false }
        return Self.canPerformCommandDecision(
            command,
            editPolicyAllowsPaste: host.lifecycleClient.editPolicy.allowsPaste,
            commandClientAllows: host.commandClient.canPerform(command, sender: sender),
            kernelPasteAvailability: { [weak self] in self?.pasteAvailabilityFromKernel(sender: sender) })
    }

    /// The pure decision function `canPerformCommand(_:sender:)` above delegates to — decoupled from
    /// `self`/`host`/`kernelInput` exactly like `reconciledMarkedRange(currentMarkedRange:change:rebase:)`
    /// (Task C9, Family 6) is, and for the identical reason: it is reachable and testable with NO
    /// attached kernel, NO host, and NO canvas at all
    /// (`IDTextEditorBackendCommandRoutingTests`, non-skip-gated).
    ///
    /// `.paste` alone consults THREE gates, each short-circuiting the ones after it — in this exact
    /// order:
    /// 1. `editPolicyAllowsPaste` — `RichTextInputEditPolicy.allowsPaste`, mirroring the identical gate
    ///    `LegacyRichTextInputBackend.canPerformCommand(_:sender:)` already applies for the same field
    ///    (`BackendEditPolicyTests.test_allowsPasteFalse_makesCanPerformPasteFalse`'s ID-backend
    ///    counterpart is this task's own `test_allowsPasteFalse_makesCanPerformPasteFalse`).
    /// 2. `commandClientAllows` — `RichTextInputCommandClient.canPerform(_:sender:)`, the policy OF
    ///    RECORD for every command (clipboard availability, selection bounds, undo/redo stack state —
    ///    whatever the real Telegram client decides).
    /// 3. `kernelPasteAvailability()` — the kernel's OWN opinion, consulted ONLY for `.paste` and ONLY
    ///    once the first two already said yes. The closure shape (not a plain `Bool?` parameter) is
    ///    what makes the "never asked when the client already said no" guarantee OBSERVABLE rather than
    ///    merely true by luck: a caller can pass a closure that records whether it fired, and this
    ///    function's own control flow proves it does not, for a command the earlier gates already
    ///    rejected. `test_canPerformPaste_consultsTheCommandClient_notThePrivateController` is exactly
    ///    that caller.
    ///
    /// `?? true` on a `nil` kernel answer (detached / no `kernelInput` / a caught kernel failure)
    /// mirrors this backend's own "absent means fall back to the higher-level policy that already said
    /// yes" convention — the kernel's opinion is an additional, narrower refinement UIKit is the only
    /// one positioned to make; its absence is not itself a reason to hide Paste from the edit menu.
    static func canPerformCommandDecision(
        _ command: RichTextInputCommand,
        editPolicyAllowsPaste: Bool,
        commandClientAllows: Bool,
        kernelPasteAvailability: () -> Bool?
    ) -> Bool {
        if command == .paste, !editPolicyAllowsPaste { return false }
        guard commandClientAllows else { return false }
        guard command == .paste else { return true }
        return kernelPasteAvailability() ?? true
    }

    /// The ONE call site `IDUIKitInputControllerCapability.shouldHandlePasteAction(_:sender:)` is
    /// consulted from — see this file's own header on why `.performPaste(_:)` is never called at all.
    /// `NSNumber`-boxed through the exception guard for the same reason `compare(_:to:)`/
    /// `offset(from:to:)` box their non-object results in `IDTextEditorBackend.swift`.
    private func pasteAvailabilityFromKernel(sender: Any?) -> Bool? {
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput.map {
                NSNumber(value: $0.shouldHandlePasteAction(
                    #selector(UIResponderStandardEditActions.paste(_:)), sender: sender))
            }
        }, &error) as? NSNumber
        if let error { reportKernelFailure(error, witness: #function) }
        return value?.boolValue
    }

    /// Routed from FIVE canvas witnesses that all share the base `DocumentCanvasView`
    /// (`copy(_:)`/`cut(_:)`/`paste(_:)`/`select(_:)`/`selectAll(_:)`) plus this backend's own
    /// `.undo`/`.redo`/`.delete` callers — every `RichTextInputCommand` case, uniformly, through the
    /// command client's prepare/commit transaction. Unlike `LegacyRichTextInputBackend
    /// .performCommand(_:sender:)`, which forwards FIVE of the eight cases straight to renamed canvas
    /// bodies (`legacyCut`/`legacyCopy`/…) because those bodies pre-date the command-client
    /// abstraction and are wider than its model of them (see that file's own header) — this backend has
    /// no such legacy bodies to preserve, so every command goes through the client uniformly, which is
    /// also what keeps this witness's OWN mutation forbidden per this file's header.
    ///
    /// Detached: silently drops the command — the same direction `insertText(_:)`/`deleteBackward()`
    /// already take for a `UIResponder` entry point arriving with no host.
    func performCommand(_ command: RichTextInputCommand, sender: Any?) {
        guard isAttached, let host else { return }
        Self.performCommandViaClient(command, sender: sender, client: host.commandClient)
    }

    /// The prepare/commit half of `performCommand(_:sender:)`, extracted as a `static` function
    /// taking the client DIRECTLY (an existential `any RichTextInputCommandClient`, not `host`/`self`)
    /// — reachable and testable with a bare `FakeInputCommandClient(log:)`, no canvas, no host, no
    /// attach at all (`IDTextEditorBackendCommandRoutingTests`).
    ///
    /// A `.ready` preparation is single-use and MUST be committed before returning to the run loop
    /// (`RichTextInputCommandClient`'s own documented contract); a `.terminal` one is already finished
    /// — `prepare` performed whatever there was to perform (this is `.copy`'s own shape in every real
    /// conformer: it writes the pasteboard inline and returns `.terminal`, never `.ready`).
    static func performCommandViaClient(
        _ command: RichTextInputCommand,
        sender: Any?,
        client: any RichTextInputCommandClient
    ) {
        switch client.prepare(command, sender: sender) {
        case .terminal:
            return
        case .ready(let prepared):
            _ = client.commit(prepared)
        }
    }

    // MARK: - `RichTextInputResponderBackend` — Family 8: responder lifecycle
    //
    // Task C11. Nine members: two `Bool` gates UIKit consults BEFORE
    // `super.become/resignFirstResponder()` even runs (`canBecomeFirstResponder`/
    // `canResignFirstResponder` — the ONLY place `RichTextInputLifecycleClient
    // .backendWillBeginEditing()`/`.backendShouldEndEditing()` are consulted anywhere in this
    // package; grepped, both are DECLARED on the protocol and DEFINED on `TelegramLifecycleInputClient`
    // — unconditionally `true`, "no veto hook exists today" — but never CALLED before this task, by
    // either backend), the six `hostWill…`/`hostDid…`/`hostDidFail…` brackets `DocumentCanvasView`'s
    // shared `becomeFirstResponder()`/`resignFirstResponder()` overrides already call around `super`
    // (`DocumentCanvasView.swift`'s own "Responder lifecycle (TASK 31, Family 8)" section — SHARED by
    // both backends; only Legacy has ever given it a real body), and `hostWillMove(toWindow:)`.
    //
    // **This is architecturally SIMPLER than `LegacyRichTextInputBackend+Responder.swift`'s own
    // Family 8, and deliberately so — not an oversight of that file's five-axis divergence audit.**
    // Legacy needs `wasFirstResponderAtWill`/`wasFirstResponderAtWillResign` (backend-stored,
    // captured BEFORE `super`) because ITS `hostDid…` hooks must distinguish a genuine
    // not-focused→focused transition from a harmless repeat call — `didJustBecomeFirstResponder`
    // (an edit-menu heuristic) must NOT be set on a repeat. This backend has no such heuristic and no
    // `didJustBecomeFirstResponder`-shaped state at all, so `hostWillBecomeFirstResponder()`/
    // `hostWillResignFirstResponder()`/`hostDidFailToBecomeFirstResponder()`/
    // `hostDidFailToResignFirstResponder()` are genuine no-ops — the "will" veto already lives in
    // `canBecomeFirstResponder`/`canResignFirstResponder` (UIKit consults them automatically before
    // `super` succeeds), so there is nothing left for the "will" hooks to do, and the two "did-fail"
    // hooks have no captured flag to clear. `hostDidBecomeFirstResponder()`/`hostDidResignFirstResponder()`
    // fire `backendDidBeginEditing()`/`backendDidEndEditing()` on EVERY successful transition
    // `super` reports — including a repeat `becomeFirstResponder()` that "still succeeds" (the same
    // observed UIKit behavior `ResponderRouterTests.test_aRepeatBecomeFirstResponderDoesNotSetTheFocusingTapFlag`
    // documents for Legacy) — a deliberate, disclosed simplification: nothing in this task's brief or
    // Consumes/Produces list asks for transition-tracking, and inventing it unasked would be the
    // "plausible fake" this file's own class header warns against.
    var canBecomeFirstResponder: Bool {
        guard isAttached, let host else { return false }
        return host.lifecycleClient.backendWillBeginEditing()
    }

    /// Detached: `true`, NOT `false` — the opposite safe direction from `canBecomeFirstResponder`
    /// above. A torn-down backend must never BLOCK the responder chain from giving up focus (the
    /// asymmetry mirrors `undoManager`'s own "nil is the safe direction" reasoning in
    /// `IDTextEditorBackend.swift`, one member up: each detached answer is chosen so a detached
    /// backend can never trap the host in a state it cannot recover from).
    var canResignFirstResponder: Bool {
        guard isAttached, let host else { return true }
        return host.lifecycleClient.backendShouldEndEditing()
    }

    func hostWillBecomeFirstResponder() {}

    /// `DocumentCanvasView.becomeFirstResponder()` calls this ONLY when `super.becomeFirstResponder()`
    /// returned `true` — see this file's header on why that already excludes the transition-tracking
    /// this backend does not do.
    /// TASK F4 — the post-become native-checking segment was MISSING here, and that is one of the
    /// two reasons the flag showed no spelling underlines.
    ///
    /// Legacy's own `hostDidBecomeFirstResponder()` runs three canvas segments; the third,
    /// `legacyFinishBecomingFirstResponder()`, is `installCheckingIfNeeded(); nativeChecker?.preheat();
    /// lastCheckedCaret = head`. Focusing the field is the PRIMARY install site (the
    /// `isSpellCheckingEnabled` `didSet` only fires on a genuine toggle, and the composer never
    /// toggles it), so without this the driver was constructed only if someone flipped the switch.
    /// Measured: `.legacy` leaves `canvas.nativeChecker` non-nil after `becomeFirstResponder()`,
    /// `.inputDec` left it nil.
    ///
    /// **Order is Legacy's, and Legacy documents it as observable**: the host callback
    /// (`backendDidBeginEditing()`) runs FIRST, the checking segment after — see
    /// `DocumentCanvasView.legacyFinishBecomingFirstResponder()`'s own note and
    /// `ResponderRouterTests.test_becomeFirstResponder_runsTheNativeCheckingInstallAfterTheHostCallback`.
    ///
    /// **Deliberately NOT routed through `canvas.legacyFinishBecomingFirstResponder()`**, mirroring
    /// `hostWillMove(toWindow:)` below: that method's name ties it to the Legacy backend's call site,
    /// and this file's established practice is to call the narrow canvas members directly instead.
    /// `installCheckingIfNeeded()` is this backend's OWN member (`IDTextEditorBackend.swift`), so the
    /// install itself still crosses the seam exactly once.
    ///
    /// **`legacyDidBecomeFirstResponder()` — Legacy's FIRST segment (caret/handles/writing
    /// directions) — is still not mirrored here, and that is left alone rather than fixed blind.**
    /// It is a separate, presentation-level question with its own test surface, nothing in the
    /// reported defect points at it, and this task's evidence says nothing about it either way.
    func hostDidBecomeFirstResponder() {
        guard isAttached, let host else { return }
        host.lifecycleClient.backendDidBeginEditing()
        installCheckingIfNeeded()
        if let canvas = host.hostInputView as? DocumentCanvasView {
            canvas.nativeChecker?.preheat()
            canvas.lastCheckedCaret = canvas.head
        }
    }

    func hostDidFailToBecomeFirstResponder() {}

    func hostWillResignFirstResponder() {}

    /// The ONE call site `IDUIKitInteractionCapability.resignedFirstResponder()` is consulted from
    /// (this file's own Family-8 Consumes-list kernel member) — told the kernel focus was lost,
    /// guarded like every other kernel-witness call in this package. **`kernelInteraction` was nil
    /// unconditionally when this comment was first written (`.interaction` was not requested), but
    /// Task C12 (Family 9) now requests it** — see `IDTextEditorBackend.swift`'s `requestedCapabilities`
    /// doc comment, so this call becomes genuinely live once C14 clears the `incomingCallbacks` gate.
    /// The forward-looking wiring this comment originally described has paid off exactly as intended:
    /// this call site needed NO edit when C12 landed.
    func hostDidResignFirstResponder() {
        guard isAttached, let host else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.id_resignedFirstResponder()
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
        host.lifecycleClient.backendDidEndEditing()
    }

    func hostDidFailToResignFirstResponder() {}

    // MARK: - The responder hand-off (PHASE 3b)

    /// **`.hostOwnsTheRole`** — this backend edits `IDDocumentCanvasView`, a `DocumentCanvasView`
    /// subclass, so its editing surface IS the host and the first-responder role stays there. Same
    /// answer as `LegacyRichTextInputBackend`, for the same reason, and with the same prohibition:
    /// the body must not touch the responder chain, or a host routing its own override through this
    /// member would recurse into itself.
    ///
    /// The member exists for `IDUpstreamInputBackend`, the adapter over the REAL ported engine,
    /// whose editing surface is a separate `IDBlockTextView` inside the host — see the contract's own
    /// note at `RichTextInputBackend.acquireFirstResponder()`. **This reconstruction is not that**:
    /// it drives the vendored behavior kernel from Telegram's own canvas, which is precisely the 16
    /// of 80 host obligations the port exists to stop reconstructing.
    func acquireFirstResponder() -> RichTextInputResponderTransition { .hostOwnsTheRole }

    /// The mirror of `acquireFirstResponder()`, and required by the contract to answer the same case.
    func relinquishFirstResponder() -> RichTextInputResponderTransition { .hostOwnsTheRole }

    /// Closes a REAL, live gap — not a documented no-op. Before this task, `hostWillMove(toWindow:)`
    /// was an empty stub, so removing an `IDDocumentCanvasView` from its window NEVER invalidated the
    /// two `CADisplayLink`s the SHARED `DocumentCanvasView` drag/floating-cursor machinery can leave
    /// running (`dragAutoScrollLink`/`floatingScrollLink` — both retain `self`, i.e. the canvas, per
    /// `DocumentCanvasView.swift`'s own "THE ONE THAT DOES NOT MOVE, AND MUST NOT" note on
    /// `floatingScrollLink`). Both mechanisms are canvas-level and backend-agnostic — the SAME gesture
    /// recognizers/pan handlers Legacy relies on are installed on an `IDDocumentCanvasView` too — so
    /// this was a genuine ID-backend-specific LEAK, not a hypothetical: `legacyWillMove(toWindow:)`
    /// (`DocumentCanvasView.swift`) has done the equivalent teardown for Legacy since Task 31; nothing
    /// mirrored it here until now. `test_removeFromWindowWhileDragging_stopsEveryDisplayLink`
    /// (`IDBackendFamily8Tests`) is the one test in this family with no legacy counterpart at all —
    /// see this task's report for how its ability to fail was verified.
    ///
    /// Calls `stopDragAutoScroll()`/`cancelFloatingCursor()` DIRECTLY rather than routing through
    /// `canvas.legacyWillMove(toWindow:)` — that method's own name ties it to the Legacy backend's
    /// call site, and reusing it here would read as this backend borrowing Legacy machinery rather
    /// than sharing genuinely backend-agnostic canvas methods (both are declared with no access
    /// modifier — `internal`, module-scoped — on `DocumentCanvasView`/`DocumentCanvasView+FloatingCursor.swift`).
    func hostWillMove(toWindow window: UIWindow?) {
        guard isAttached, let host, let canvas = host.hostInputView as? IDDocumentCanvasView else { return }
        Self.stopDisplayLinksForWindowRemoval(canvas, newWindow: window)
    }

    /// The pure(ish) TEARDOWN DECISION `hostWillMove(toWindow:)` above delegates to — extracted as a
    /// `static` function taking the canvas DIRECTLY, exactly like Family 7's
    /// `canPerformCommandDecision(...)`/`performCommandViaClient(...)` extractions, and for the
    /// SAME reason: an `IDDocumentCanvasView` is constructible (under the reporter guard
    /// `IDBackendContractSubclasses.swift`'s `makeIDContractHost` already establishes) with no
    /// SUCCESSFUL backend attach at all — `stopDragAutoScroll()`/`cancelFloatingCursor()` are
    /// canvas-level mechanisms with no dependency on `isAttached`/`host`/the kernel — so this is
    /// reachable and testable with NO live kernel
    /// (`IDTextEditorBackendWindowRemovalTests`, non-skip-gated), unlike
    /// `IDBackendFamily8Tests.test_removeFromWindowWhileDragging_stopsEveryDisplayLink`, which stays
    /// skip-gated until Task C14 (see this task's report for how the LATTER test's ability to fail
    /// was verified despite never being able to run in this environment).
    static func stopDisplayLinksForWindowRemoval(_ canvas: IDDocumentCanvasView, newWindow: UIWindow?) {
        guard newWindow == nil else { return }
        canvas.stopDragAutoScroll()
        canvas.cancelFloatingCursor()
    }
}
#endif
