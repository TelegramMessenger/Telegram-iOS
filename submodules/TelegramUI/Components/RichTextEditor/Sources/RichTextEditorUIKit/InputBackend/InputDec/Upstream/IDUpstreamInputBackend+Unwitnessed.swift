#if canImport(UIKit)
import UIKit

/// **EVERY BACKEND REQUIREMENT THIS STAGE OF THE PORT DOES NOT IMPLEMENT — every one of them loud.**
///
/// `task-PORT-PLAN.md` §3.2 scoped phase 2 to the "instantiate and accept typing" subset; phase 3
/// added the responder requirements the settled responder model makes forwardable, and phase 3b the
/// responder hand-off pair (both in `+Responder.swift`). This file is everything else.
///
/// **THE COUNTS ARE DERIVED, IN ONE PLACE, AND ARE DELIBERATELY NOT RESTATED HERE** (phase 3 review,
/// Minor 7). They used to appear as a per-protocol table in this header, again in
/// `IDUpstreamInputBackend.swift`'s header, again in the runtime message below, and again inside a
/// TEST'S NAME — against this repo's own rule-15 warning that "a count restated in three places is
/// how four consecutive tasks on this branch each lost a fix round". The single source is
/// `InputDecUpstreamAdapterBoundaryTests.test_everyDeclaredRequirementIsEitherImplementedOrLoud`,
/// which parses the protocol declarations and both halves of the adapter and asserts the partition
/// — so the numbers cannot go stale silently, and anything that needs one should cite that rule.
///
/// **THE FIVE `MARK:` HEADINGS BELOW CARRY NO NUMBER, and that is this promise being KEPT rather than
/// merely stated** (phase 3b review, findings 2 and 3). The deleted table's per-protocol column
/// survived the first pass verbatim as five MARKs — `16`, `8 of 15`, `8`, `3`, `23`, summing to the
/// very total the paragraph above refuses to state — and one of them went STALE IN THE COMMIT THAT
/// WAS FIXING STALE COUNTS: `RichTextInputResponderBackend` went from 15 declared members to 17 when
/// the responder hand-off pair landed, and the MARK still read 15. **Deleting them is the fix, not
/// correcting them**: a number no rule derives is a number that goes stale, and the rule that derives
/// these is one `swift test --filter` away.
///
/// # Why every one of them reports instead of returning something reasonable
///
/// §9.9 of the port plan names this programme's signature failure: "plausible stubs". Ten sites in
/// the reconstruction this port replaces compiled cleanly and either did nothing or did the wrong
/// thing — an empty method body, a constant `false`, a constant `nil`, a cast that could never
/// succeed — and each was found only by a human typing into a running build, one defect per round,
/// five rounds. **A member here that returned `.zero` or `false` quietly would be indistinguishable
/// from a member that works**, which is precisely how those ten survived review.
///
/// So each member below calls `reportContractViolation(_:)`, which appends to the backend's own
/// `recordedViolations` AND goes through `RichTextInputContractViolation.report` — an
/// `assertionFailure` in DEBUG, an observable callback under an armed test reporter. The value each
/// then returns is the most inert one its type admits, and it is reached ONLY after the report.
///
/// # Several of these are one line away from working, and are still not implemented
///
/// `caretRect(for:)` could forward to `caretRect(for:)`; `markedRange`/`isComposing` are the same two
/// engine reads that `state` already performs. **They are deliberately left here.** A forward that no
/// test drives is a forward nobody has measured — this package's history is a list of members that
/// looked forwarded and were not. Each such near-miss is named in its own doc comment below so a
/// later phase can pick them up as a list rather than rediscovering them.
///
/// Phase 3 did exactly that for the responder family: `canBecomeFirstResponder` WAS on this list and
/// is now a real forward, together with six others. What made that possible was not effort — it was
/// settling which view holds the first-responder role, which is what every one of the seven turned
/// out to depend on. Phase 3b added the two hand-off members that settlement needed, and they are
/// implemented rather than listed here — but the six `host…FirstResponder` members below did NOT
/// move, because a contract member that lets the host stop having a transition does not give this
/// backend anything honest to say about one it should not be having.
///
/// # The four `notifying…` brackets are the one shape that does NOT no-op
///
/// They take the caller's mutation as a closure. Reporting and then DISCARDING that closure would
/// silently destroy the caller's work — a strictly worse failure than the missing notification
/// bracket. They therefore report and then run the body unbracketed, which is stated in each one.
@available(iOS 18.4, *)
extension IDUpstreamInputBackend {

    /// **No count in the message** (phase 3 review, Minor 7): it was one of five places the
    /// implemented/unimplemented split was restated, and it moves every phase.
    private func unwitnessed(_ member: String, _ why: String) {
        reportContractViolation(
            "IDUpstreamInputBackend.\(member) is not implemented in this stage of the InputDec "
            + "port. \(why)")
    }

    // MARK: - `RichTextInputTextBackend`
    //
    // GEOMETRY (`firstRect`, `caretRect`, `selectionRects`, `closestPosition`×2, `characterRange(at:)`)
    // has a direct `IDBlockTextView` counterpart for every member, and every one of them answers in
    // the ENGINE VIEW's coordinate space. Phase 2 has no agreed coordinate contract with
    // `host.hostInputView` — the host owns geometry only from phase 8, when Telegram's canvas takes
    // drawing back and the 9 `RichTextInputGeometryClient` requirements come into play — so
    // forwarding a rect now would publish coordinates in a space the caller has not been told about.
    // That is a translation this adapter is not yet entitled to make.
    //
    // MARKED TEXT (`markedTextStyle`, `setMarkedText`, `unmarkText`) likewise forwards trivially, and
    // is excluded because composition is a behaviour with its own contract (`RichTextMarkedTextPolicy`,
    // `RichTextCompositionSnapshot`) that phase 2 neither drives nor tests.

    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get {
            unwitnessed("markedTextStyle",
                        "The engine vends its own composition styling; phase 2 does not drive marked text.")
            return nil
        }
        set {
            unwitnessed("markedTextStyle",
                        "The engine vends its own composition styling; phase 2 does not drive marked text.")
        }
    }

    func setMarkedText(_ text: String?, selectedRange: NSRange) {
        unwitnessed("setMarkedText(_:selectedRange:)",
                    "IDBlockTextView.setMarkedText(_:selectedRange:) is the forward; composition is "
                    + "out of this phase's subset.")
    }

    func unmarkText() {
        unwitnessed("unmarkText()",
                    "IDBlockTextView.unmarkText() is the forward; composition is out of this phase's subset.")
    }

    func position(
        from: UITextPosition,
        in direction: UITextLayoutDirection,
        offset: Int
    ) -> UITextPosition? {
        unwitnessed("position(from:in:offset:)",
                    "IDBlockTextView.position(from:in:offset:) is the forward; directional navigation "
                    + "is layout-dependent and this phase pins no layout.")
        return nil
    }

    func position(
        within range: UITextRange,
        farthestIn direction: UITextLayoutDirection
    ) -> UITextPosition? {
        unwitnessed("position(within:farthestIn:)",
                    "IDBlockTextView.position(within:farthestIn:) is the forward; directional "
                    + "navigation is layout-dependent and this phase pins no layout.")
        return nil
    }

    func characterRange(
        byExtending position: UITextPosition,
        in direction: UITextLayoutDirection
    ) -> UITextRange? {
        unwitnessed("characterRange(byExtending:in:)",
                    "IDBlockTextView.characterRange(byExtending:in:) is the forward; directional "
                    + "navigation is layout-dependent and this phase pins no layout.")
        return nil
    }

    func baseWritingDirection(
        for position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> NSWritingDirection {
        unwitnessed("baseWritingDirection(for:in:)",
                    "IDBlockTextView.baseWritingDirection(for:in:) is the forward; writing direction "
                    + "is out of this phase's subset.")
        return .natural
    }

    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {
        unwitnessed("setBaseWritingDirection(_:for:)",
                    "IDBlockTextView.setBaseWritingDirection(_:for:) is the forward; writing direction "
                    + "is out of this phase's subset.")
    }

    func firstRect(for range: UITextRange) -> CGRect {
        unwitnessed("firstRect(for:)", Self.geometryReason)
        return .zero
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        unwitnessed("caretRect(for:)", Self.geometryReason)
        return .zero
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        unwitnessed("selectionRects(for:)", Self.geometryReason)
        return []
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        unwitnessed("closestPosition(to:)", Self.geometryReason)
        return nil
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        unwitnessed("closestPosition(to:within:)", Self.geometryReason)
        return nil
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        unwitnessed("characterRange(at:)", Self.geometryReason)
        return nil
    }

    private static let geometryReason =
        "IDBlockTextView answers this directly, in ITS OWN view's coordinate space. Phase 2 has no "
        + "agreed coordinate contract with host.hostInputView — the 9 RichTextInputGeometryClient "
        + "requirements arrive at phase 8 — so a forwarded rect would be measured in a space the "
        + "caller was never told about."

    func textStyling(
        at position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> [NSAttributedString.Key: Any]? {
        unwitnessed("textStyling(at:in:)",
                    "Deviation D15 marks this PERMANENTLY unwitnessed for the legacy conformer too; "
                    + "the engine's typing-attribute channel (PORT-PLAN §5.3) has no owner yet.")
        return nil
    }

    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        unwitnessed("insertDictationResult(_:)",
                    "Deviation D15 marks this PERMANENTLY unwitnessed for the legacy conformer too.")
    }

    // MARK: - `RichTextInputResponderBackend`
    //
    // **PHASE 3 SETTLED THE MODEL: the ENGINE holds the first-responder role and the host forwards
    // rather than takes it.** Seven of the fifteen became honest forwards and moved to
    // `+Responder.swift`, whose header carries the measurements and the four wirings that were built
    // and rejected. These eight stay, and the reason is no longer "phase 8 will decide" — it is that
    // the model makes six of them describe a transition of a view that must NOT have one, and the
    // other two need a source this phase still does not consume.

    func hostWillBecomeFirstResponder() {
        unwitnessed("hostWillBecomeFirstResponder()", Self.responderLifecycleReason)
    }

    func hostDidBecomeFirstResponder() {
        unwitnessed("hostDidBecomeFirstResponder()", Self.responderLifecycleReason)
    }

    func hostDidFailToBecomeFirstResponder() {
        unwitnessed("hostDidFailToBecomeFirstResponder()", Self.responderLifecycleReason)
    }

    func hostWillResignFirstResponder() {
        unwitnessed("hostWillResignFirstResponder()", Self.responderLifecycleReason)
    }

    func hostDidResignFirstResponder() {
        unwitnessed("hostDidResignFirstResponder()", Self.responderLifecycleReason)
    }

    func hostDidFailToResignFirstResponder() {
        unwitnessed("hostDidFailToResignFirstResponder()", Self.responderLifecycleReason)
    }

    func editPolicyDidChange() {
        unwitnessed("editPolicyDidChange()",
                    "the new policy can only come from host.lifecycleClient.editPolicy — one of the "
                    + "54 client-side requirements this adapter still consumes NONE of, pinned from "
                    + "the source by InputDecUpstreamAdapterBoundaryTests. attach(to:) takes the "
                    + "policy from its caller instead, so a policy that CHANGES after attach is not "
                    + "applied and says so here.")
    }

    func textInputTraitsDidChange() {
        unwitnessed("textInputTraitsDidChange()",
                    "IDBlockTextView owns its UITextInputTraits and pushes them itself "
                    + "(id_syncTextInputTraits -> IDPrivateSynchronizeTextInputTraits' 19-row push, "
                    + "plus id_reloadInputViewsForChangedTrait which reloads only while it is first "
                    + "responder). Nothing on this side writes a trait into the engine, so there is "
                    + "no change for this to announce and nothing to re-push.")
    }

    /// **The measured reason the six lifecycle members are not implemented.** The full evidence table
    /// — four wirings built, three defective, the fourth blocked on a contract member that does not
    /// exist — is in `+Responder.swift`'s header, and `IDUpstreamResponderModelTests` is the
    /// instrument. This message is what a caller sees at runtime.
    private static let responderLifecycleReason =
        "Under this backend the ENGINE is the first responder, not the host: measured, "
        + "-_requiresKeyboardWhenFirstResponder is true on IDBlockTextView and false on a host view, "
        + "and UIKit binds inputDelegate only to whichever one holds the role. So a host that took "
        + "the role has already lost the keyboard, and these six describe a transition the host must "
        + "not have. THE CALLER SHOULD BE USING acquireFirstResponder()/relinquishFirstResponder() "
        + "(phase 3b): this backend answers .performedByBackend, which means it has taken the role "
        + "and the host must neither call super nor emit these six. Reaching one of them means that "
        + "answer was ignored, and there is nothing honest to translate the call into — all three "
        + "ways to answer it anyway were built and measured defective (W1 dead keyboard, W2 a false "
        + "return, W3 a resign cycle nested inside every become). See "
        + "IDUpstreamInputBackend+Responder.swift."

    // MARK: - `RichTextInputInteractionBackend`
    //
    // THE ENGINE OWNS ITS INTERACTIONS. `IDBlockTextView+Interaction.m` installs the private
    // interaction assistant, and `IDSelectionPresentation`/`IDNativeSelectionPresentationBackend`
    // own the selection chrome. Installing anything from this side would be a SECOND set of
    // interactions over the same pixels.

    func installInteractions() {
        unwitnessed("installInteractions()", Self.interactionReason)
    }

    func removeInteractions() {
        unwitnessed("removeInteractions()", Self.interactionReason)
    }

    func viewportDidChange() {
        unwitnessed("viewportDidChange()",
                    "IDBlockTextView is a UIScrollView and drives its own viewport and autoscroll "
                    + "(IDVerticalAutoscroll); this phase publishes no viewport to it.")
    }

    func layoutDidChange(generation: UInt64) {
        unwitnessed("layoutDidChange(generation:)",
                    "The engine owns layout in this phase (IDDocumentLayoutCoordinator); Telegram's "
                    + "layout generations describe a block layer that is not attached yet.")
    }

    func beginFloatingCursor(at point: CGPoint) {
        unwitnessed("beginFloatingCursor(at:)", Self.floatingCursorReason)
    }

    func updateFloatingCursor(at point: CGPoint) {
        unwitnessed("updateFloatingCursor(at:)", Self.floatingCursorReason)
    }

    func endFloatingCursor() {
        unwitnessed("endFloatingCursor()", Self.floatingCursorReason)
    }

    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {
        unwitnessed("cancelActiveInteraction(reason:)", Self.interactionReason)
    }

    private static let interactionReason =
        "IDBlockTextView installs and owns the private interaction assistant and its selection "
        + "presentation. A second installation from this side would be two sets of gestures over one "
        + "surface."

    private static let floatingCursorReason =
        "IDBlockTextView+Interaction.m:44-62 is the engine's own floating-cursor path and it is "
        + "driven by the private interaction assistant, not by a caller. Points arriving here are in "
        + "the host view's space, which phase 2 has no contract for (see geometry above)."

    // MARK: - `RichTextInputCheckingBackend`
    //
    // Upstream's text checking runs through the private checking controller and renders through
    // `IDRichTextAnnotationStore` + TextKit 2 temporary attributes — i.e. INTO THE ENGINE'S OWN
    // RENDERER. The reconstruction's defect here (task H2) was delivering an annotation into
    // Telegram's overlay instead. Nothing on this side should touch it until the renderer question
    // is settled.

    func installCheckingIfNeeded() {
        unwitnessed("installCheckingIfNeeded()", Self.checkingReason)
    }

    func checkOnSelectionChange() {
        unwitnessed("checkOnSelectionChange()", Self.checkingReason)
    }

    func globalRange(ofCheckingRange range: UITextRange) -> (from: Int, to: Int)? {
        unwitnessed("globalRange(ofCheckingRange:)", Self.checkingReason)
        return nil
    }

    private static let checkingReason =
        "Upstream renders spelling/grammar through IDRichTextAnnotationStore into its OWN renderer. "
        + "PORT-PLAN §8.3 is where that is settled; delivering an annotation anywhere else is the "
        + "exact defect task H2 found."

    // MARK: - `RichTextInputBackend`

    /// NEAR MISS for phase 3: `canonicalSelection.anchor.utf16Offset` already answers this, and
    /// `canonicalSelection` IS implemented. Left unwitnessed because the phase's subset is 22 and
    /// because these two decompose `canonicalSelection` into a PAIR — the shape this repo has been
    /// bitten by three times (`enableUnreadAlignment`, `itemNodeFrame`, `settledContentOffsets`):
    /// a pair of raw members is a pair a backend can half-implement or half-sample.
    var canonicalSelectionAnchorOffset: Int {
        unwitnessed("canonicalSelectionAnchorOffset", Self.selectionPairReason)
        return 0
    }

    /// See `canonicalSelectionAnchorOffset`.
    var canonicalSelectionHeadOffset: Int {
        unwitnessed("canonicalSelectionHeadOffset", Self.selectionPairReason)
        return 0
    }

    func setCanonicalAnchor(_ utf16Offset: Int) {
        unwitnessed("setCanonicalAnchor(_:)", Self.selectionPairReason)
    }

    func setCanonicalHead(_ utf16Offset: Int) {
        unwitnessed("setCanonicalHead(_:)", Self.selectionPairReason)
    }

    private static let selectionPairReason =
        "setSelection(_:reason:) / canonicalSelection are the whole-selection members this phase "
        + "implements. These four decompose that into endpoint halves, and the engine's "
        + "selectedTextRange cannot be half-written: writing one endpoint means reading the other "
        + "back and re-minting a range, i.e. holding selection state on the Telegram side."

    /// NEAR MISS for phase 3: `state.markedRange` already forwards this exact engine read.
    /// Unwitnessed here because the phase's subset is 22 and because a marked range that is readable
    /// while `setMarkedText`/`unmarkText` are not implies a composition contract this phase does not
    /// have.
    var markedRange: NSRange? {
        unwitnessed("markedRange", Self.compositionReason)
        return nil
    }

    var isComposingPrediction: Bool {
        unwitnessed("isComposingPrediction",
                    "IDBlockTextView publishes no prediction-vs-composition distinction on its public "
                    + "surface; the reconstruction derived one from a latched intent, which is exactly "
                    + "the Telegram-side bookkeeping this port removes.")
        return false
    }

    /// NEAR MISS for phase 3: `state.isComposing` already forwards this. See `markedRange`.
    var isComposing: Bool {
        unwitnessed("isComposing", Self.compositionReason)
        return false
    }

    var compositionSnapshot: RichTextCompositionSnapshot? {
        unwitnessed("compositionSnapshot", Self.compositionSnapshotReason)
        return nil
    }

    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        unwitnessed("setCompositionMarkedRange(_:isPrediction:)", Self.compositionReason)
    }

    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        unwitnessed("setCompositionSnapshot(_:)", Self.compositionSnapshotReason)
    }

    func clearCompositionState() {
        unwitnessed("clearCompositionState()", Self.compositionReason)
    }

    /// **The residual this leaves, named rather than left to be discovered (PH2 review, F12).**
    /// `state.markedRange` / `state.isComposing` ANSWER the same engine read that `markedRange` /
    /// `isComposing` trap on. So a report from this adapter does not reliably mean "this adapter
    /// cannot answer that" — it means "not through this member" — which is a small tax on the exact
    /// loudness signal the phase rests on. It is the cost of holding the subset to §3.2's 22 rather
    /// than forwarding members no test drives. **Close it in phase 3, in the same commit as
    /// `setMarkedText`/`unmarkText`**, so the readable half and the drivable half land together.
    private static let compositionReason =
        "state.markedRange / state.isComposing already forward the engine's markedTextRange, so this "
        + "is one line from working. It is left here because setMarkedText/unmarkText are NOT "
        + "implemented, and a readable composition with no way to drive it is a half-contract."

    private static let compositionSnapshotReason =
        "RichTextCompositionSnapshot carries Telegram `Block`s. The engine's document is "
        + "IDBlockDocument (NSAttributedString per block) and no converter exists in this phase — "
        + "PORT-PLAN §5.1 keeps Telegram's document model precisely because upstream has none."

    var floatingCursorActive: Bool {
        unwitnessed("floatingCursorActive", Self.floatingStateReason)
        return false
    }

    var floatingCursorPoint: CGPoint {
        unwitnessed("floatingCursorPoint", Self.floatingStateReason)
        return .zero
    }

    var floatingScrollVelocity: CGFloat {
        unwitnessed("floatingScrollVelocity", Self.floatingStateReason)
        return 0.0
    }

    func setFloatingCursorActive(_ active: Bool) {
        unwitnessed("setFloatingCursorActive(_:)", Self.floatingStateReason)
    }

    func setFloatingCursorPoint(_ point: CGPoint) {
        unwitnessed("setFloatingCursorPoint(_:)", Self.floatingStateReason)
    }

    func setFloatingScrollVelocity(_ velocity: CGFloat) {
        unwitnessed("setFloatingScrollVelocity(_:)", Self.floatingStateReason)
    }

    private static let floatingStateReason =
        "These three mirror floating-cursor state that the ENGINE holds internally and does not "
        + "publish. Storing a Telegram-side copy would make this adapter the authority on state it "
        + "does not own — the defect class the whole port exists to remove."

    var suppressesSelectionNotifications: Bool {
        get {
            unwitnessed("suppressesSelectionNotifications", Self.notificationReason)
            return false
        }
        set {
            unwitnessed("suppressesSelectionNotifications", Self.notificationReason)
        }
    }

    /// **RUNS THE BODY.** Reporting and discarding it would silently destroy the caller's mutation,
    /// which is strictly worse than the missing notification bracket. The body runs UNBRACKETED: no
    /// `textWillChange`/`textDidChange` pair is emitted by this adapter, because the engine emits its
    /// own through its `UITextInputDelegate` and a second pair would double-notify.
    func notifyingContentAndSelectionChange(_ body: () -> Void) {
        unwitnessed("notifyingContentAndSelectionChange(_:)", Self.notificationReason)
        body()
    }

    /// See `notifyingContentAndSelectionChange(_:)` — the body runs.
    func notifyingSelectionChange(_ body: () -> Void) {
        unwitnessed("notifyingSelectionChange(_:)", Self.notificationReason)
        body()
    }

    /// See `notifyingContentAndSelectionChange(_:)` — the body runs.
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) {
        unwitnessed("notifyingSelectionChangeIgnoringCoalescing(_:)", Self.notificationReason)
        body()
    }

    /// See `notifyingContentAndSelectionChange(_:)` — the body runs.
    func notifyingContentChange(_ body: () -> Void) {
        unwitnessed("notifyingContentChange(_:)", Self.notificationReason)
        body()
    }

    func notifyCoalescedSelectionResync() {
        unwitnessed("notifyCoalescedSelectionResync()", Self.notificationReason)
    }

    private static let notificationReason =
        "IDBlockTextView emits its own UITextInputDelegate notifications from inside the engine "
        + "(IDBlockTextView+PrivateInputDelegate.m). A bracket on this side would either double-notify "
        + "or suppress the engine's own, and coalescing policy is Telegram canvas state that phase 2 "
        + "has no canvas for."
}
#endif
