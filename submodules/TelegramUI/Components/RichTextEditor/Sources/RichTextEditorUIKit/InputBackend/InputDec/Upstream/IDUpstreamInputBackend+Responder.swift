#if canImport(UIKit)
import UIKit
import RichTextInputDecObjC
import RichTextInputDecUpstream

/// PHASE 3 OF THE PORT — **who is the first responder, the engine or Telegram's host?**
///
/// Phase 2 left all 15 `RichTextInputResponderBackend` requirements reporting a named contract
/// violation, because answering any of them means settling that question first. This file settles
/// it, and implements the **seven** of the fifteen that the answer makes forwardable. The other
/// eight stay in `+Unwitnessed.swift`, with messages that now name the model rather than deferring
/// to a later phase.
///
/// # THE MODEL: the ENGINE holds the first-responder role; the host forwards, it does not take
///
/// This is not a preference. It was measured, and the alternative is dead on the evidence.
/// `IDUpstreamResponderModelTests` is the instrument; every number below is one of its assertions.
///
/// | reading | engine holds the role | a plain host view holds it |
/// | --- | --- | --- |
/// | `-_requiresKeyboardWhenFirstResponder` | **true** | **false** |
/// | `IDBlockTextView.inputDelegate` | `_UIKeyboardStateManager` | **nil** |
///
/// Both readings are the whole story:
///
///   * `-_requiresKeyboardWhenFirstResponder` is UIKit's own question "does this responder need a
///     keyboard". A host view answering `false` is exactly the shape of a read-only `UITextView` —
///     first responder, caret drawn, **no keyboard** — which is the user-visible defect this
///     programme already shipped once and fixed as task F2 (`../DIVERGENCES.md`, entry 20). The
///     instrument is the same one `IDKeyboardActivationTests` calibrates against two real
///     `UITextView`s, because keyboard appearance itself is not observable in a SwiftPM test bundle.
///   * `inputDelegate` is assigned **by UIKit, to the responder that holds the role**, and cleared
///     when it resigns. It is the channel carrying `textWillChange` / `selectionDidChange` between
///     the keyboard and the text object: marked text, autocorrect, shift state, prediction. With the
///     host holding the role the engine's is nil, so none of that exists — and typing still works
///     programmatically, so the failure is **silent**, which is this programme's signature.
///
/// The third reason is structural rather than measured: everything `IDBlockTextView` does when it
/// gains or loses the role — `[self.id_interactionCapability setSelectionActive:visible:]`,
/// `id_updateSelectionPresentation`, `id_cancelVerticalAutoscrollSession`
/// (`IDBlockTextView.m:460-482`) — sits behind `IDBlockTextViewInternal.h` and private categories.
/// A "Telegram-as-responder, engine driven" model would have to reproduce all of it on our side,
/// which is precisely the reconstruction (16 of 80 obligations) this port exists to delete.
///
/// # What the model COSTS, measured — and why six members still report
///
/// The six `host{Will,Did,DidFailTo}{Become,Resign}FirstResponder` members describe a transition of
/// the HOST. Under this model the host must not have one, and there is no member on
/// `RichTextInputBackend` by which a host can hand the role to the backend instead of taking it.
/// Four wirings were built and measured; three of them are defective and the fourth needs that
/// missing member:
///
/// | wiring | end state | cost |
/// | --- | --- | --- |
/// | W1 redirect in `hostWillBecomeFirstResponder()`, host still claims the role | host FR, engine **not** FR, `inputDelegate` nil | the host's own `super.becomeFirstResponder()` takes the role straight back. **Dead keyboard, and `becomeFirstResponder()` returns `true`.** |
/// | W2 redirect in the same place, host's `canBecomeFirstResponder` answers `false` | engine FR, `inputDelegate` live | `becomeFirstResponder()` returns **`false`** to a caller whose focus in fact succeeded, and `hostDidFailToBecomeFirstResponder()` fires on every success |
/// | W3 hand-off from `hostDidBecomeFirstResponder()` | engine FR, `inputDelegate` live | a **full resign cycle nested inside the become cycle, on every focus** — measured. Against a real `DocumentCanvasView` that is `backendDidEndEditing()` inside `backendDidBeginEditing()`, on every composer touch-down |
/// | W4 host forwards `becomeFirstResponder()` to the engine and never calls `super` | engine FR, `inputDelegate` live, idempotent on a repeat focus | **needed a contract member that did not exist — PHASE 3b added it** |
///
/// W4 is the model, and it is the shape this package already uses one level up:
/// `RichTextEditorView.becomeFirstResponder()` returns `canvas.becomeFirstResponder()` and the outer
/// view never holds the role.
///
/// # PHASE 3b — the contract member W4 needed now exists, and this file answers it
///
/// `RichTextInputBackend` gained `acquireFirstResponder()` / `relinquishFirstResponder()`, answering
/// `RichTextInputResponderTransition`. This adapter answers `.performedByBackend(succeeded:)` and
/// sends the transition to the engine; `LegacyRichTextInputBackend` and the old reconstruction
/// answer `.hostOwnsTheRole` and touch nothing — which removes any REASON for a host's override to
/// recurse through the member (a rule the contract states and `ResponderHandOffTests` enforces, not
/// something the type system makes impossible), and makes phase 3b a zero-behaviour-change addition
/// to the shipping backend. The contract's own
/// declaration carries the per-case obligations and the host-side shape.
///
/// **The six lifecycle members still report, and phase 3b did not change that — it changed what
/// they say.** Under `.performedByBackend` the host has no responder transition of its own, so a
/// host that has adopted `acquireFirstResponder()` never calls the six against this backend. A host
/// that calls one anyway has ignored the answer it was given, and there is nothing honest to
/// translate the call into: W1, W2 and W3 are the three ways to answer it anyway and each was built
/// and measured defective. So the report now names the member the caller should have used, instead
/// of deferring to a contract decision that has since been taken. A recorded gap is fine; a
/// plausible-looking answer is the failure mode.
@available(iOS 18.4, *)
extension IDUpstreamInputBackend {

    // MARK: - The two gates — forwarded, because only the engine can answer them

    /// `IDBlockTextView.canBecomeFirstResponder` is
    /// `self.userInteractionEnabled && (self.isEditable || self.isSelectable)`
    /// (`IDBlockTextView.m:412`) — a live, state-dependent answer, not a constant. Measured across
    /// all four editable/selectable POLICIES plus `isUserInteractionEnabled = false`:
    /// `(editable, selectable)` = `(t,t) -> true`, `(f,t) -> true`, `(t,f) -> false`,
    /// `(f,f) -> false`.
    ///
    /// **THE `(t,f)` ROW IS NOT WHAT THE FORMULA ABOVE PREDICTS, AND THE DIFFERENCE IS AN ORDERING
    /// DEPENDENCY IN `attach(to:)`** (phase 3 review, Minor 2). Apply the quoted gate to
    /// `editable = true, selectable = false` and you get `true`. It measures `false` because
    /// `-[IDBlockTextView setSelectable:NO]` FORCE-CLEARS `_editable` (`IDBlockTextView.m:446-450`),
    /// so the engine's state in that row is `(f,f)`, not `(t,f)` — and it is `(f,f)` only because
    /// `attach(to:)` assigns `isEditable` BEFORE `isSelectable` (`IDUpstreamInputBackend.swift`, the
    /// two lines inside the construction trampoline). Reverse those two assignments and the same
    /// policy yields `true`, which
    /// `IDUpstreamResponderModelTests.test_theEditableSelectableOrderingInAttachIsWhatMakesTheTFRowFalse`
    /// measures directly rather than leaving to be rediscovered. **So the headline "differs from
    /// Legacy's constant in three of five configurations" is two of five on ENGINE STATE alone**;
    /// `(f,f)` and `isUserInteractionEnabled = false` carry the conclusion on their own.
    ///
    /// **Legacy's identical member is the literal `true`** (`../../LegacyRichTextInputBackend
    /// +Responder.swift`), and that is correct FOR LEGACY — its canvas consults nothing, and this
    /// measurement is EVIDENCE ABOUT `IDBlockTextView`, not evidence that `DocumentCanvasView`'s
    /// pre-seam behaviour was wrong. Reaching for it to change the shipping backend would be
    /// misusing it. Copying the constant HERE, though, would have been a Telegram-side answer to a
    /// question the engine already answers, i.e. the exact defect shape this port removes. It is
    /// forwarded instead, and it genuinely differs from `true`.
    var canBecomeFirstResponder: Bool {
        let member = "canBecomeFirstResponder"
        guard let view = requireEngine(member) else { return false }
        return perform(member, on: view, default: false) { $0.canBecomeFirstResponder }
    }

    /// `IDBlockTextView` declares no `canResignFirstResponder`, so this reads whatever `UIScrollView`
    /// / `UIResponder` answer for it — measured `true`. That is still the ENGINE's answer, read off
    /// the engine, and it will keep tracking the engine if a future version starts overriding it.
    var canResignFirstResponder: Bool {
        let member = "canResignFirstResponder"
        guard let view = requireEngine(member) else { return false }
        return perform(member, on: view, default: false) { $0.canResignFirstResponder }
    }

    // MARK: - The responder hand-off (PHASE 3b) — the engine takes the role, the host hands it over

    /// **THE MEMBER W4 NEEDED.** The host calls this instead of `super.becomeFirstResponder()`; the
    /// engine takes the role; the host returns what came back. Everything the model rests on follows
    /// from the engine holding the role and nothing else does:
    /// `-_requiresKeyboardWhenFirstResponder` answers `true` (so UIKit raises a keyboard), UIKit
    /// binds `inputDelegate` to it (so marked text, autocorrect, prediction and shift state have a
    /// channel), and `IDBlockTextView.becomeFirstResponder` runs its own transition work —
    /// `setSelectionActive:visible:` + `id_updateSelectionPresentation` — which sits behind
    /// `IDBlockTextViewInternal.h` and cannot be driven from this side at all.
    ///
    /// **A bare forward, and deliberately so.** It does not check `isFirstResponder` first, does not
    /// consult `canBecomeFirstResponder`, and does not short-circuit a repeat call: UIKit already
    /// answers `true` for a responder that holds the role, and `IDBlockTextView.becomeFirstResponder`
    /// gates its own transition work on `became && !wasFirstResponder` (`IDBlockTextView.m:460`).
    /// Adding a gate here would be this adapter deciding something the engine already decides — the
    /// defect shape this file's header names — and it is what makes the member idempotent on the
    /// composer's touch-DOWN focus, which fires on every tap including on an already-focused editor.
    ///
    /// **`.performedByBackend(succeeded:)` reports UIKit's answer honestly, including `false`.** The
    /// case carries the outcome rather than collapsing a failure into "the host should take the
    /// role", because that collapse IS measured wiring W2: it makes `becomeFirstResponder()` answer
    /// `false` to a caller whose focus in fact succeeded.
    func acquireFirstResponder() -> RichTextInputResponderTransition {
        let member = "acquireFirstResponder()"
        guard let view = requireEngine(member) else { return .performedByBackend(succeeded: false) }
        return .performedByBackend(
            succeeded: perform(member, on: view, default: false) { $0.becomeFirstResponder() })
    }

    /// The mirror, and required by the contract to answer the same case as `acquireFirstResponder()`.
    ///
    /// Also a bare forward: `IDBlockTextView.resignFirstResponder` cancels its vertical-autoscroll
    /// session BEFORE `super` and clears its selection presentation after a genuine loss
    /// (`IDBlockTextView.m:471`), all of it behind the internal header. Note that `false` here is
    /// routine rather than exceptional — `UIResponder.resignFirstResponder()` answers `false`
    /// whenever the receiver did not hold the role — which is another reason the outcome travels
    /// inside `.performedByBackend` instead of being read as "declined".
    ///
    /// **`detach()` resigns the engine itself** and does not route through this member, deliberately:
    /// teardown is not a hand-off, and by the time it runs the host may already be gone.
    func relinquishFirstResponder() -> RichTextInputResponderTransition {
        let member = "relinquishFirstResponder()"
        guard let view = requireEngine(member) else { return .performedByBackend(succeeded: false) }
        return .performedByBackend(
            succeeded: perform(member, on: view, default: false) { $0.resignFirstResponder() })
    }

    // MARK: - `-isEditable`, the member the dead-keyboard defect was

    /// **DEVIATION D3's member, and the one this file most wants a reader to look at.** Under the
    /// legacy backend it is routed from `DocumentCanvasView.isEditable`, which is UIKit's
    /// `-isEditable` witness on the first responder — the flag UIKit reads to decide whether that
    /// responder needs a keyboard at all. Task F2 shipped it as a constant `false` on the old
    /// reconstruction, and the editor took first responder, drew a caret and raised no keyboard.
    ///
    /// It forwards to `IDBlockTextView.isEditable`. Under this file's model UIKit never asks the
    /// HOST's `-isEditable`, because the host is not the responder — it asks the engine's, and the
    /// engine answers for itself. So this member is the editor's editability as the engine holds it,
    /// which is the only place it is true. Measured alongside the keyboard reading:
    /// `isEditable = false, isSelectable = true` gives `-isEditable false` **and**
    /// `-_requiresKeyboardWhenFirstResponder false` **and** a nil `inputDelegate` — the three move
    /// together, off the engine's own state.
    ///
    /// **It is deliberately NOT the literal `true` Legacy uses.** Legacy's own doc comment records
    /// that its `true` is a byte-for-byte port of a pre-seam witness that consulted nothing, and that
    /// gating it is a decision belonging to whoever makes the edit policy live. Here the policy IS
    /// live — `attach(to:)` takes it from the caller and pushes `isEditable`/`isSelectable` into the
    /// engine — so forwarding is not "adding a gate", it is reading the gate that already exists.
    var isEditableForWritingTools: Bool {
        let member = "isEditableForWritingTools"
        guard let view = requireEngine(member) else { return false }
        return perform(member, on: view, default: false) { $0.isEditable }
    }

    // MARK: - Undo

    /// `IDBlockTextView.undoManager` returns `self.id_behaviorInput.undoManager`
    /// (`IDBlockTextView+TextInput.m:298`) — measured to be a real `NSUndoManager`, not nil.
    ///
    /// **Phase 2 left this reporting on the grounds that "vending an undo stack nothing coordinates
    /// is worse than vending none". The model changes that reasoning, and it is worth stating why
    /// rather than silently reversing it.** `UIResponder.undoManager` is walked up from the FIRST
    /// RESPONDER, and under this model that is the engine, which vends its own manager without any
    /// help from us. So this member cannot be the thing that puts a foreign undo stack in front of
    /// the system affordances — it is not on the path UIKit walks at all. What it is instead is the
    /// answer to a host asking "which manager do this backend's edits register into", and the honest
    /// answer to that is the engine's, not `nil`. **`nil` would be the plausible-looking lie**: it
    /// says "this responder has no undo manager" about an editor that demonstrably has one.
    ///
    /// This does NOT move undo OWNERSHIP, exactly as the protocol's own doc comment says: reading and
    /// vending, never owning.
    var undoManager: UndoManager? {
        let member = "undoManager"
        guard let view = requireEngine(member) else { return nil }
        return perform(member, on: view, default: nil) { $0.undoManager }
    }

    // MARK: - Commands

    /// The selector each `RichTextInputCommand` names, or `nil` when this contract has none for it.
    ///
    /// **This is the inverse of a function the package already has**, `richTextInputCommand(for:)`
    /// (`../../Clients/TelegramCommandInputClient.swift`), which maps exactly six selectors —
    /// `copy:`/`cut:`/`paste:`/`select:`/`selectAll:`/`delete:`. Written out here rather than
    /// inverted at runtime so it is a `switch` the compiler makes exhaustive, and pinned against the
    /// forward function by `IDUpstreamResponderModelTests
    /// .test_theCommandSelectorMapIsTheInverseOfThePackagesOwn`, so the two cannot drift.
    ///
    /// # `.undo` / `.redo` answer `nil`, and that is a fact about UIKit rather than a shortcut
    ///
    /// `UIResponderStandardEditActions` declares fourteen-plus actions and **`undo:`/`redo:` are not
    /// among them** (`UIResponder.h`: `cut:`, `copy:`, `paste:`, …, `delete:`,
    /// `makeTextWritingDirection…`, `toggleBoldface:`, …). They are informal responder actions with
    /// no Swift spelling, so the only way to name one here is a runtime string lookup — which
    /// `InputBackendSourceBoundaryTests` R1 bans outright in `InputBackend/` and R1b confines to a
    /// deliberately NON-GROWING three-file inventory. That guard fired on the first draft of this
    /// file, which is exactly what it is for.
    ///
    /// The gap this leaves is real and is recorded rather than papered over: the engine's own
    /// `canPerformAction:withSender:` **does** answer for both
    /// (`IDBlockTextView+TextInput.m:330-334`, `isEditable && undoManager.canUndo/canRedo`), so a
    /// forward exists on the engine's side and only the spelling is missing on ours. Closing it means
    /// giving the two an `@objc` shim protocol or widening the R1 ban — neither of which is this
    /// phase's to decide. `undoManager` above already vends the manager those two act on.
    static func editActionSelector(for command: RichTextInputCommand) -> Selector? {
        switch command {
        case .cut: return #selector(UIResponderStandardEditActions.cut(_:))
        case .copy: return #selector(UIResponderStandardEditActions.copy(_:))
        case .paste: return #selector(UIResponderStandardEditActions.paste(_:))
        case .selectWord: return #selector(UIResponderStandardEditActions.select(_:))
        case .selectAll: return #selector(UIResponderStandardEditActions.selectAll(_:))
        case .delete: return #selector(UIResponderStandardEditActions.delete(_:))
        case .undo, .redo: return nil
        }
    }

    /// Forwarded verbatim to the engine's `canPerformAction:withSender:` for the six commands that
    /// have a selector; `.undo`/`.redo` report, per `editActionSelector(for:)`.
    ///
    /// Every answer is the engine's own, and every one of them is state-dependent rather than a
    /// constant — measured on a focused engine holding a five-character document: with an empty
    /// selection `copy:`/`cut:` are `false` and `select:`/`selectAll:` are `true`; with a three-
    /// character selection `copy:`/`cut:` flip to `true` and `select:`/`selectAll:` flip to `false`.
    /// `paste:` additionally requires `self.isFirstResponder && self.isEditable` and a pasteboard
    /// with strings, so a backend whose engine does not hold the role correctly answers `false`.
    ///
    /// `.delete` reaches `super.canPerformAction:` inside the engine (it has no `delete:` case),
    /// which asks the responder CHAIN — the same semantics the canvas witness documents for its own
    /// `delete:`. That is still the engine's answer, and we do not second-guess it.
    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        let member = "canPerformCommand(_:sender:)"
        guard let view = requireEngine(member) else { return false }
        guard let selector = Self.editActionSelector(for: command) else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): \(command) has no selector on this contract — "
                + "UIResponderStandardEditActions declares no undo:/redo:, and naming one would take "
                + "a runtime string lookup that InputBackendSourceBoundaryTests R1/R1b forbid here. "
                + "The engine's own canPerformAction:withSender: does answer for it, so this is a "
                + "spelling gap on OUR side, not a missing capability on the engine's.")
            return false
        }
        return perform(member, on: view, default: false) {
            $0.canPerformAction(selector, withSender: sender)
        }
    }

    /// Sends the command to the engine — but **only after asking the engine whether it implements
    /// the action**, because two of the six selectors it does not.
    ///
    /// Measured on a focused engine: `responds(to:)` is `true` for `cut:`, `copy:`, `paste:`,
    /// `select:` and `selectAll:` (each has a real body in `IDBlockTextView+TextInput.m:337-361`) and
    /// **`false` for `delete:`**. Every member of `UIResponderStandardEditActions` is `@optional`, so
    /// an unchecked call would be a silent no-op — the failure shape this whole port exists to stop
    /// producing — and the engine's own document would simply not change while everything looked
    /// fine. The check is `responds(to:)` **at the call site rather than a hardcoded list**: a list
    /// would be this file's opinion about the engine and would go stale the moment upstream adds a
    /// `delete:`; asking the engine is the engine's answer, and it starts working on its own.
    ///
    /// **THREE of the five it does send are guarded on the engine's side; TWO are not** (phase 3
    /// review, Minor 4 — this sentence used to claim five and then name three). Every line number
    /// below is a GUARD line, not a method declaration; the first draft of this correction mixed the
    /// two conventions in one sentence (phase 3b review, finding 7):
    ///
    /// | selector | declared | guard |
    /// | --- | ---: | --- |
    /// | `cut:` | `:337` | `:338-339` — `canPerformAction:` **and** `IDPrivateTextViewShouldDelete` |
    /// | `copy:` | `:344` | `:345` — `canPerformAction:` |
    /// | `select:` | `:354` | `:355` — `canPerformAction:` |
    /// | `paste:` | `:350` | **none** — straight to `id_behaviorInput performPaste:` at `:351` |
    /// | `selectAll:` | `:360` | **none** — straight to `id_interactionCapability selectAll:` at `:361` |
    ///
    /// So for the first three this forwards the request and lets the engine refuse it, exactly as a
    /// menu tap would — and `cut:` may refuse for a SECOND reason this sentence used to omit, the
    /// private delete-permission check. `paste:` and `selectAll:` act unconditionally. That is still
    /// a faithful forward (a menu tap reaches the same unguarded body), but a caller that wants
    /// menu-equivalent behaviour for those two must ask `canPerformCommand(_:sender:)` first; this
    /// member will not ask for it.
    func performCommand(_ command: RichTextInputCommand, sender: Any?) {
        let member = "performCommand(_:sender:)"
        guard let view = requireEngine(member) else { return }
        guard let selector = Self.editActionSelector(for: command) else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): \(command) has no selector on this contract — see "
                + "canPerformCommand(_:sender:) for why, and undoManager for what the caller can use "
                + "instead.")
            return
        }
        guard view.responds(to: selector) else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): the ported engine implements no "
                + "`\(NSStringFromSelector(selector))`, so \(command) has no forward. Every "
                + "UIResponderStandardEditActions member is @optional, so calling it anyway would be "
                + "a SILENT no-op. (canPerformCommand(\(command)) still forwards — the engine's "
                + "canPerformAction:withSender: has an answer for this selector even though it "
                + "implements no body for it.)")
            return
        }
        perform(member, on: view, default: ()) { engine in
            let responder: any UIResponderStandardEditActions = engine
            switch command {
            case .cut: responder.cut?(sender)
            case .copy: responder.copy?(sender)
            case .paste: responder.paste?(sender)
            case .selectWord: responder.select?(sender)
            case .selectAll: responder.selectAll?(sender)
            case .delete: responder.delete?(sender)
            // Unreachable: `editActionSelector(for:)` answers nil for both and the guard above
            // returned. Spelled out rather than `default:` so adding a command is a compile error.
            case .undo, .redo: break
            }
        }
    }

    // MARK: - Window movement — the one member that is a no-op rather than a forward

    /// **This does nothing when attached, and that is an answer rather than a stub — but it is the
    /// one member in this file a reviewer should push on, so it says so itself.**
    ///
    /// Legacy's counterpart tears down two `CADisplayLink`s when `window == nil`. The engine has the
    /// same obligation and discharges it itself: `IDBlockTextView.didMoveToWindow`
    /// (`IDBlockTextView.m:484` in the ported tree, `:481` upstream — this line read `:479`, which was
    /// neither) calls `id_cancelVerticalAutoscrollSession` when its window is nil.
    /// The only question is whether the engine actually RECEIVES that callback when the change
    /// happens to the HOST rather than to the engine, and that is measured rather than assumed:
    /// `IDUpstreamResponderModelTests.test_theEngineLearnsAboutAWindowChangeMadeToTheHost` subclasses
    /// the engine, records every `didMoveToWindow`, and observes `["window", "nil"]` across
    /// `window.addSubview(host)` then `host.removeFromSuperview()`. The same test observes the engine
    /// losing first responder and its `inputDelegate` on the way out, with nothing on this side
    /// asking for it.
    ///
    /// So there is nothing to forward, and a report here would be a contract violation raised on a
    /// routine `UIView` lifecycle event — which trains a reader to ignore the one channel this whole
    /// phase rests on (the reasoning phase 2 recorded at `affinity(of:)`'s `.downstream` case).
    ///
    /// The detached guard is kept so the family invariant "every member reports when there is no
    /// engine" has no exception. There is deliberately no `window == nil` branch: the decision is the
    /// engine's, made on its own edge (`didMove`, not `willMove`), and duplicating it here would be
    /// this side re-deciding something it does not own.
    func hostWillMove(toWindow window: UIWindow?) {
        _ = requireEngine("hostWillMove(toWindow:)")
    }
}
#endif
