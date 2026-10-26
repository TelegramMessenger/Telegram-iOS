#if canImport(UIKit)
import UIKit
import RichTextInputDecHost

/// The responder role and the composer-host surface (R5).
///
/// The wrapper (`RichTextEngineEditorView`, a plain `UIView`) never becomes first responder
/// itself — `engine`, its `IDBlockTextView` child, is the real `UITextInput`/`UIKeyInput` client
/// and is the object that actually holds the role. Every member below forwards to `engine` and
/// answers with the engine's own truth. None of them decides anything.
///
/// This is the sharp rung named in the task brief: the prior programme's dead-keyboard defect was
/// exactly `canBecomeFirstResponder` answering a plausible constant instead of the engine's real
/// state. `EngineResponderTests.test_theEditorCanBecomeFirstResponderAndTheEngineHoldsTheRole` pins
/// this by construction — flipping the override below to a literal `false` reddens that test.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// The wrapper hands off rather than deciding: this is the engine's own
    /// `-canBecomeFirstResponder` (`userInteractionEnabled && (isEditable || isSelectable)`,
    /// `IDBlockTextView.m`), not a constant. A literal `true` here is indistinguishable from a
    /// correct answer to every caller EXCEPT the one time the engine's own precondition is false —
    /// which is exactly the shape of the prior programme's dead-keyboard defect.
    public override var canBecomeFirstResponder: Bool { engine.canBecomeFirstResponder }

    /// Delegates the responder transition to the engine outright — the wrapper does not also call
    /// `super.becomeFirstResponder()`, because the wrapper is not the text client and must never
    /// itself hold the role UIKit's keyboard/text-input machinery is targeting.
    /// The host callbacks are NOT fired from here. They belong to the ENGINE's transition
    /// (`engineDidBecomeFirstResponder`), because this override runs only for a PROGRAMMATIC focus:
    /// a tap is delivered to the engine by UIKit's text-interaction assistant, which calls
    /// `becomeFirstResponder` on the engine directly and never enters this method. Fired here as
    /// well, a programmatic focus would report twice.
    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        engine.becomeFirstResponder()
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        engine.resignFirstResponder()
    }

    /// Reports the ENGINE's first-responder state, not whatever the wrapper's own (unused)
    /// UIResponder bookkeeping would say. Since the wrapper's `becomeFirstResponder()` above never
    /// calls `super`, the wrapper is never actually registered as first responder by UIKit — so
    /// leaving this un-overridden would make it silently, plausibly, always answer `false`.
    public override var isFirstResponder: Bool { engine.isFirstResponder }

    /// The composer-host name for the same fact as `isFirstResponder` above — kept as a distinct
    /// member because `UIView.isFirstResponder` (unoverridden, on some OTHER view holding a
    /// reference to this one) would answer about the wrong object entirely.
    public var isEditorFirstResponder: Bool { engine.isFirstResponder }

    @discardableResult
    public func resignEditorFirstResponder() -> Bool {
        engine.resignFirstResponder()
    }

    /// Commit any pending marked/predictive text before send. Wrapped in
    /// `deliveringChangeNotification` for the same reason as `insertText(_:)` below: committing
    /// marked text is a document mutation, and its `onChange` must reach the consumer from this
    /// stack rather than waiting for a runloop turn.
    public func finalizeComposerMarkedText() {
        deliveringChangeNotification { engine.unmarkText() }
    }

    /// Reload the engine's input views (after changing `customInputView`).
    public func reloadComposerInputViews() { engine.reloadInputViews() }

    /// The engine's `inputView` is `UIResponder`'s plain `readonly` property — `IDBlockTextView`
    /// (upstream) never overrides it, so nothing backs a direct `engine.inputView = …` assignment
    /// (it does not even compile: "'inputView' is a get-only property"). `TGIDObservingBlockTextView`
    /// (`RichTextInputDecHost`, telegram-authored, NOT the vendored engine — Global Constraint 1
    /// only forbids `RichTextInputDecUpstream`/`RichTextInputDecObjC/Vendor`/
    /// `RichTextEditorUIKit/Mapping`) adds `tgid_customInputView` plus a one-line `-inputView`
    /// override forwarding to it, mirroring the `tgid_setAttributedBlocks` seam already used for
    /// R2's whole-content replacement. UIKit consults the FIRST RESPONDER's `inputView` when
    /// building the keyboard surface — since `engine` is the one that actually holds the role (see
    /// `isEditorFirstResponder` above), routing this through the wrapper instead would be a silent
    /// no-op: UIKit would never look at it.
    public var customInputView: UIView? {
        get { engine.tgid_customInputView }
        set {
            engine.tgid_customInputView = newValue
            engine.reloadInputViews()
        }
    }

    /// The active keyboard's primary language while the engine is first responder, or nil when
    /// unfocused (`UIResponder.textInputMode` is nil unless first responder). Read straight off
    /// `engine.textInputMode` — the upstream engine has no override of its own here, so this is
    /// UIKit's real, hosted answer, not a derived guess.
    public var inputPrimaryLanguage: String? { engine.textInputMode?.primaryLanguage }

    /// `UIKeyInput.insertText(_:)`, forwarded verbatim. Global Constraint 4: no veto, no
    /// redirection — whatever the engine does with this text is final.
    ///
    /// `deliveringChangeNotification` wraps the forward but does not touch it: it runs AFTER the
    /// engine call has fully returned, and only delivers the `onChange` the engine's own change
    /// funnel already marked as owed (see `RichTextEngineEditorView.isChangeNotificationPending`).
    /// That is what keeps a host-driven mutation's notification observable in the caller's own turn
    /// while still never running consumer code inside the engine's `-processEditing`.
    public func insertText(_ text: String) {
        deliveringChangeNotification { engine.insertText(text) }
    }

    /// `UIKeyInput.deleteBackward()`, forwarded verbatim.
    public func deleteBackward() {
        deliveringChangeNotification { engine.deleteBackward() }
    }

    /// `UIResponderStandardEditActions.paste(_:)`, forwarded verbatim — the engine reads
    /// `UIPasteboard.generalPasteboard` itself (`IDBlockTextView+TextInput.m`'s `-paste:`).
    public func pasteFromPasteboard() {
        deliveringChangeNotification { engine.paste(nil) }
    }
}
#endif
