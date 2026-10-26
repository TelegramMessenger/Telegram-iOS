#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// The ObjC ↔ Swift geometry-purpose mapping (Task C5). Written out explicitly — never
/// `RichTextInputGeometryPurpose(rawValue:)` — for the same reason
/// `caretGeometry(atOffset:...)` maps `RichTextInputWritingDirection` explicitly below: the two
/// enums are declared independently (one `NS_ENUM` in ObjC, one Swift `enum`) and nothing pins
/// their case order to agree forever.
@available(iOS 13.0, *)
private extension TGRichTextInputDecGeometryPurpose {
    var asSwift: RichTextInputGeometryPurpose {
        switch self {
        case .keyboard: return .keyboard
        case .caret: return .caret
        case .selectionEndpoint: return .selectionEndpoint
        case .selectionPresentation: return .selectionPresentation
        case .loupe: return .loupe
        case .floatingCursor: return .floatingCursor
        case .editMenu: return .editMenu
        case .accessibility: return .accessibility
        @unknown default: return .keyboard
        }
    }
}

/// The ObjC ↔ Swift selection-reason mapping (Task C6), written out explicitly for the same
/// reason `TGRichTextInputDecGeometryPurpose.asSwift` above is: the two enums are declared
/// independently and nothing pins their case order to agree forever.
@available(iOS 13.0, *)
private extension TGRichTextInputDecSelectionReason {
    var asSwift: RichTextSelectionChangeReason {
        switch self {
        case .keyboard: return .keyboard
        case .touch: return .touch
        case .floatingCursor: return .floatingCursor
        case .command: return .command
        case .programmatic: return .programmatic
        case .externalSynchronization: return .externalSynchronization
        @unknown default: return .keyboard
        }
    }
}

/// Translates every Objective-C bridge call into the six Swift clients.
///
/// This is the ONLY place the two worlds meet. The shared Swift protocols stay Swift-only (spec:
/// "the shared protocols do not become `@objc` merely to bridge it"), and Swift-only concepts —
/// `AnyHashable` line ids, the mutation enum's associated values, the prepared-mutation token,
/// the invalidation OptionSet — are consumed here and never cross into Objective-C.
///
/// Task C7 (Family 4) landed the real `TGRichTextInputDecTextStorageFacade` this class's `storage`
/// property was always meant to hold — C0/C1 (and, mirroring them, `IDFakeClientHarness.swift` and
/// `RichTextInputBackendHarness.swift` on the test side) had to substitute a plain, empty
/// `NSTextStorage` because that type did not exist yet; those three test-side sites are retyped by
/// this same task (see its report). `storage`'s `bridge` is wired to `self` at the end of `init`
/// below, and its `revision` is kept in step with the transaction outcome inside
/// `prepareAndCommitReplacement(in:text:intent:expectedRevision:outOutcome:)`.
///
/// `@MainActor`: every Swift-side type it touches (`RichTextInputHost` and its six clients) is
/// `@MainActor`-isolated, but `TGRichTextInputDecClientBridging` is a plain Objective-C protocol
/// with no actor annotation, so a conforming class defaults to nonisolated — verified the hard
/// way (an `xcodebuild` simulator build, which SwiftPM's `swift build` does not reproduce, failed
/// with "main actor-isolated property 'lifecycleClient'/'editPolicy' can not be referenced from a
/// nonisolated context" on `canvasKeyboardInputShouldDelete()`). Matches the precedent already
/// established for other types touching this seam (`CanvasFactoryTests.swift`, `IsSupportedTests.swift`).
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendClientBridge: NSObject, TGRichTextInputDecClientBridging {
    private weak var host: (any RichTextInputHost)?
    private unowned let backend: IDTextEditorBackend
    let storage: TGRichTextInputDecTextStorageFacade

    init(host: any RichTextInputHost, backend: IDTextEditorBackend) {
        self.host = host
        self.backend = backend
        self.storage = TGRichTextInputDecTextStorageFacade()
        super.init()
        // Weak on the façade's side (see that class's own doc comment): this bridge owns the
        // façade strongly via `storage` above, matching the layout controller's `textStorageFacade`
        // back-pointer shape.
        self.storage.bridge = self
    }

    func textStorageFacade() -> NSTextStorage { storage }

    func canvasKeyboardInputShouldDelete() -> Bool {
        guard let host else { return false }
        return host.lifecycleClient.editPolicy.isEditable
    }

    // Tasks C4-C7 append their groups below this line, mirroring
    // TGRichTextInputDecClientBridge.h's `@optional` groups.

    // MARK: Task C4 — document reads and position/range conversion

    func documentUTF16Length() -> Int { host?.documentClient.utf16Length ?? 0 }

    func documentRevision() -> UInt64 { host?.documentClient.revision ?? 0 }

    /// Task R3 FIX: this member was compiling clean and silently NEVER answering
    /// `-[TGRichTextInputDecClientBridging documentPlainTextInRange:]` at runtime — a pre-existing
    /// latent bug dating to Task C4, discovered while building this task's mirror-resync path
    /// (`TGRichTextInputDecTextStorageFacade.synchronizeMirrorWithDocumentIfNeeded`), which calls
    /// exactly this selector and got `nil` back from every `respondsToSelector:`/
    /// `class_copyMethodList` check. Measured directly: `documentUTF16Length()`,
    /// `documentRevision()`, `documentClampedOffset(_:)`, `documentIsValidInsertionOffset(_:)`, and
    /// `documentRebaseOffset(_:fromRevision:outOffset:)` — every OTHER Task C4 member, including
    /// ones with the identical "differently-named external/internal label" shape
    /// (`fromRevision revision:`) — DID synthesize their expected selectors and DID appear in
    /// `class_copyMethodList`; only this one, with a single `NSRange` parameter under an explicit
    /// external label (`inRange range:`), silently failed Swift's implicit `@objc` inference for
    /// this `@optional` protocol requirement. The explicit `@objc(documentPlainTextInRange:)` below
    /// pins the selector and was verified (via the same runtime introspection) to restore it.
    /// Consequence before this fix: EVERY caller of `-documentPlainTextInRange:` — not just this
    /// task's own new call site, but the THREE pre-existing ones in
    /// `TGRichTextInputDecLayoutController.m` (manifest rows backing `id_string`/related reads) —
    /// silently fell through their own `respondsToSelector:` guards and got no text at all. Outside
    /// this task's cluster-5 scope to chase further, but worth knowing: this may be an existing,
    /// uninvestigated contributor to some of R1's other ~17 still-open failures.
    @objc(documentPlainTextInRange:)
    func documentPlainText(inRange range: NSRange) -> String? {
        host?.documentClient.plainText(in: range)
    }

    func documentClampedOffset(_ offset: Int) -> Int {
        guard let host else { return 0 }
        return host.documentClient.clamp(RichTextInputPosition(utf16Offset: offset,
                                                                 affinity: .downstream)).utf16Offset
    }

    func documentIsValidInsertionOffset(_ offset: Int) -> Bool {
        guard let host else { return false }
        return host.documentClient.isValidInsertionPosition(
            RichTextInputPosition(utf16Offset: offset, affinity: .downstream))
    }

    func documentRebaseOffset(_ offset: Int,
                              fromRevision revision: UInt64,
                              outOffset: UnsafeMutablePointer<Int>) -> Bool {
        guard let host,
              let rebased = host.documentClient.rebase(
                  RichTextInputPosition(utf16Offset: offset, affinity: .downstream),
                  fromRevision: revision) else { return false }
        outOffset.pointee = rebased.utf16Offset
        return true
    }

    // MARK: Task C5 — geometry

    func caretGeometry(atOffset utf16Offset: Int,
                       affinity: UITextStorageDirection,
                       revision: UInt64,
                       purpose: TGRichTextInputDecGeometryPurpose,
                       outRect: UnsafeMutablePointer<CGRect>,
                       outWritingDirection: UnsafeMutablePointer<NSWritingDirection>,
                       outLayoutGeneration: UnsafeMutablePointer<UInt64>) -> Bool {
        guard let host else { return false }
        let position = RichTextInputPosition(
            utf16Offset: utf16Offset,
            affinity: affinity == .backward ? .upstream : .downstream)
        guard let geometry = host.geometryClient.caretGeometry(
                at: position, revision: revision, purpose: purpose.asSwift) else { return false }
        outRect.pointee = geometry.rect
        // MAP EXPLICITLY. `geometry.writingDirection` is `RichTextInputWritingDirection`, a
        // Swift `enum … : Int` in the shared types; the out-param is UIKit's `NSWritingDirection`.
        // A direct assignment does not compile, and `NSWritingDirection(rawValue:)` would silently
        // couple the two enums' case order forever — so the mapping is written out.
        outWritingDirection.pointee = (geometry.writingDirection == .rightToLeft)
            ? .rightToLeft : .leftToRight
        outLayoutGeneration.pointee = geometry.layoutGeneration
        return true
    }

    /// `visibleRect`: the ObjC side has no `nullable CGRect *` (CGRect is a struct, not an
    /// object), so `CGRectNull` is the sentinel for "no bound" — mirroring how `CGRectNull`
    /// already means "no such rect" at the UIKit edge elsewhere in this package
    /// (`RichTextEditorView.swift`, `DocumentCanvasView+Interaction.swift`). A real, non-null
    /// rect maps straight through to `RichTextInputSelectionGeometryRequest.visibleRect`.
    /// Task R4 FIX: this member — like `documentPlainText(inRange:)` above — compiled clean but
    /// never exposed `-[TGRichTextInputDecClientBridging selectionRectsForRange:visibleRect:revision:]`
    /// at runtime. Found by Task R4's mechanical audit of all 25 `@optional` requirements (the
    /// header's own count of `@optional` method declarations, not the 27 the task brief quoted —
    /// see that task's report for the discrepancy): `class_getInstanceMethod`/`class_copyMethodList`
    /// against the live class showed this selector, and three siblings below, absent under ANY
    /// name — Swift's automatic-`@objc`-inference for `@optional` protocol witnesses did not fire
    /// at all for these four (not even under a differently-shaped guess), exactly like
    /// `documentPlainTextInRange:`. The explicit annotation below pins the selector; verified via
    /// the same runtime introspection.
    @objc(selectionRectsForRange:visibleRect:revision:)
    func selectionRects(forRange range: NSRange,
                        visibleRect: CGRect,
                        revision: UInt64) -> [TGRichTextInputDecSelectionRect] {
        guard let host else { return [] }
        let request = RichTextInputSelectionGeometryRequest(
            range: range,
            visibleRect: visibleRect.isNull ? nil : visibleRect,
            includeStartEndpoint: true,
            includeEndEndpoint: true,
            purpose: .selectionPresentation)
        guard let segments = host.geometryClient.selectionSegments(for: request, revision: revision) else {
            return []
        }
        return segments.map { segment in
            // Same explicit `RichTextInputWritingDirection` → `NSWritingDirection` mapping as
            // `caretGeometry(atOffset:...)` above, applied per segment, for the same reason.
            TGRichTextInputDecSelectionRect(
                rect: segment.rect,
                containsStart: segment.containsStart,
                containsEnd: segment.containsEnd,
                isVertical: segment.isVertical,
                writingDirection: (segment.writingDirection == .rightToLeft) ? .rightToLeft : .leftToRight)
        }
    }

    /// `range`: the ObjC callers that feed this (Family 2's `id_cursorPositionAtPoint:inContainer:`
    /// / `id_nearestPositionAtPoint:inContainer:`) receive no range from UIKit at all — neither
    /// private callback's own signature carries one — so they pass the `NSNotFound`-location
    /// sentinel for "unbounded", translated to `nil` here before reaching the client's own
    /// `within range: NSRange?`.
    /// Task R4 FIX — see `selectionRects(forRange:visibleRect:revision:)` above: same silent
    /// absence, same audit, same fix shape.
    @objc(closestOffsetToPoint:withinRange:revision:outOffset:)
    func closestOffset(toPoint point: CGPoint,
                       withinRange range: NSRange,
                       revision: UInt64,
                       outOffset: UnsafeMutablePointer<Int>) -> Bool {
        guard let host else { return false }
        let boundedRange: NSRange? = range.location == NSNotFound ? nil : range
        guard let position = host.geometryClient.closestPosition(
                to: point, within: boundedRange, revision: revision, purpose: .selectionEndpoint) else {
            return false
        }
        outOffset.pointee = position.utf16Offset
        return true
    }

    // MARK: Task C6 — selected range and input-delegate ownership
    //
    // Every method here forwards straight to `backend`; NONE of them touches `inputDelegate`
    // itself — hard invariant 10 confines every `UITextInputDelegate` send to `IDTextEditorBackend`
    // (see that file's `emitWillChange`/`adoptAndEmitDidChange`/`relay*FromKernel` methods).

    /// **TASK H1 — no longer a relay.** `textInputDidChange:` is a `UITextInputControllerDelegate`
    /// member: the private controller reporting IN that it changed the document. It used to route to
    /// `relayTextDidChangeFromKernel()`, which sent `inputDelegate?.textDidChange(_:)` straight back
    /// OUT to UIKit — the opposite direction. See `IDTextEditorBackend
    /// .reconcileAfterControllerTextChange()` for the correction and the measurement that showed
    /// this callback had never actually been delivered (the controller's delegate was this bridge,
    /// which answers none of the delegate selectors).
    func delegateTextInputDidChange() {
        backend.reconcileAfterControllerTextChange()
    }

    /// **TASK H1 — no longer a relay**, for the same reason as `delegateTextInputDidChange()` above.
    func delegateTextInputDidChangeSelection() {
        backend.reconcileAfterControllerSelectionChange()
    }

    /// **NOT the same thing as `delegateTextInputDidChangeSelection()` above** — the two used to
    /// share one relay, and task H1 separated them. `keyboardInputChangedSelection:` is declared in
    /// `UIKeyboardInput`, which UIKit sends to the VIEW; `textInputDidChangeSelection:` is declared
    /// in `UITextInputControllerDelegate`, which the private controller sends to its `delegate`
    /// (task F3 §2's protocol census, re-confirmed by H1's runtime measurement: the controller's
    /// `-setDelegate:` asks about the latter and never about the former). Their upstream bodies
    /// differ accordingly — this one forwards to the *app-level* delegate, the other reconciles
    /// locally — so they cannot share an implementation.
    ///
    /// H1 intended to change only the siblings and had to change this too: re-pointing the delegate
    /// made this callback start arriving as well, so its own recorded direction error would have
    /// gone live in the same commit. See `IDTextEditorBackend.reconcileAfterKeyboardSelectionChange()`
    /// for the measurement and for what is still open here.
    func delegateKeyboardInputChangedSelection() {
        backend.reconcileAfterKeyboardSelectionChange()
    }

    /// Adopts a whole canonical selection reported from the ObjC side, through the one
    /// whole-selection write (`setSelection(_:reason:)`) — the one Family-3 bridge method that
    /// changes state rather than merely relaying a notification.
    ///
    /// **TASK F3 — this method currently has NO production caller.** Its only one was C6's
    /// `_deleteBackwardAndNotify:` canvas thunk, written on the reading that the selector REPORTS a
    /// delete the private controller had already performed. Measured, it does not: UIKit is asking
    /// the responder to PERFORM the delete (`-[UIResponder _deleteBackwardAndNotify:]` calls
    /// `-deleteBackward`), and the thunk is gone — see the note in
    /// `TGRichTextInputDecCanvasCallbacks.m` where it used to be. The method is KEPT rather than
    /// deleted because the `TGRichTextInputDecClientBridging` protocol declares it and a future
    /// genuinely-reporting callback is the natural consumer; it is exercised by tests only. Do not
    /// read its presence as evidence that some kernel path seats selections through here.
    func setCanonicalSelectionAnchor(_ anchor: Int, head: Int, reason: TGRichTextInputDecSelectionReason) {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(anchor), head: .downstream(head)),
                             reason: reason.asSwift)
    }

    // MARK: Task C7 — insertion and replacement (Family 4)
    //
    // The façade's ONE crossing point: `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:
    // withString:` calls this, and only this, to run the two-phase (prepare/commit) transaction
    // against Telegram's real document client. This method itself never touches `inputDelegate` —
    // it forwards the WILL/DID brackets to `backend`'s Task C7 overloads (`emitWillChange(_
    // prepared:)`/`adoptAndEmitDidChange(_ result:)`), which route through the private,
    // `NotificationKind`-taking originals — the file's sole `inputDelegate` senders (hard
    // invariant 10).

    func prepareAndCommitReplacement(
        in range: NSRange,
        text: String,
        intent: TGRichTextInputDecIntent,
        expectedRevision: UInt64,
        outOutcome: UnsafeMutablePointer<TGRichTextInputDecMutationOutcome>) -> Bool {
        prepareAndCommitReplacement(in: range, text: text, intent: intent,
                                     expectedRevision: expectedRevision, beforeCommit: nil,
                                     outOutcome: outOutcome)
    }

    /// Task R7 (cluster 4) — see the header's own doc comment on this overload for the full
    /// rationale. `beforeCommit` fires exactly once, only on the `.ready` path, strictly BEFORE
    /// `commitPreparedMutation` — the one call in this method that actually mutates the document.
    func prepareAndCommitReplacement(
        in range: NSRange,
        text: String,
        intent: TGRichTextInputDecIntent,
        expectedRevision: UInt64,
        beforeCommit: (() -> Void)?,
        outOutcome: UnsafeMutablePointer<TGRichTextInputDecMutationOutcome>) -> Bool {
        // Task D4d — CONSUMED unconditionally, ahead of the `host` guard's own early return: this
        // value belongs to exactly ONE transaction, just like the façade's `currentIntent`, which
        // `replaceCharactersInRange:withString:` resets whether the transaction applied or was
        // rejected. `nil` for every non-composing intent, so
        // `IDTextEditorBackendIntent.mutation(for:…)` sees it only where `.markedText` reads it.
        let markedTextSelectedRange = backend.takePendingMarkedTextSelectedRange()
        guard let host else { return false }
        let mutation = IDTextEditorBackendIntent.mutation(
            for: intent, range: range, text: text, selection: backend.state.selection,
            typingAttributes: { host.documentClient.typingAttributes(at: backend.state.selection.head) },
            markedTextSelectedRange: markedTextSelectedRange)
        switch host.documentClient.prepareMutation(mutation, expectedRevision: expectedRevision) {
        case .terminal(let result):
            // A terminal preparation is a rejection or a no-change: stop here, with no
            // will/did-notification bracket and no mirror mutation — the façade's own caller
            // (`replaceCharactersInRange:withString:`) reads a `NO` return as "nothing happened."
            // `beforeCommit` deliberately does NOT fire here — that is the whole point of this
            // overload (see the header's doc comment).
            if case .rejected(let reason) = result.disposition {
                host.lifecycleClient.backendDidRejectMutation(mutation, reason: reason)
            }
            return false
        case .ready(let prepared):
            beforeCommit?()
            backend.emitWillChange(prepared)
            let result = host.documentClient.commitPreparedMutation(prepared)
            // Task R2 addition — `RichTextInputDocumentClient.commitPreparedMutation`'s own doc
            // comment: a commit "must agree with the preparation's contentWillChange/
            // selectionWillChange flags." Mirrors `LegacyRichTextInputBackend+Mutation.swift`
            // `runMutation`'s identical check verbatim (same two conditions, same message shape): a
            // client that changed content/selection it had preflighted as NOT changing is a
            // programmer contract violation, not a silent acceptance.
            // `IDBackendMutationContractTests.test_resultDisagreeingWithPreparationFlags_…` pins this.
            if result.contentChanged, !prepared.contentWillChange {
                RichTextInputContractViolation.report(
                    "commitPreparedMutation for \(mutation) reported contentChanged=true, but its " +
                    "own preparation's contentWillChange was false")
            }
            if result.selectionChanged, !prepared.selectionWillChange {
                RichTextInputContractViolation.report(
                    "commitPreparedMutation for \(mutation) reported a selection change, but its " +
                    "own preparation's selectionWillChange was false")
            }
            // Task R5 — thread `intent` through so a composing edit publishes with reason
            // `.markedText`, not `.content` (see `adoptAndEmitDidChange(_:intent:)`'s own doc comment).
            backend.adoptAndEmitDidChange(result, intent: intent)
            outOutcome.pointee = TGRichTextInputDecMutationOutcome(
                revision: result.revision,
                selectionAnchor: result.selection.anchor.utf16Offset,
                selectionHead: result.selection.head.utf16Offset)
            return result.disposition == .applied
        }
    }

    // MARK: Task C12 — interaction-host thunks (Family 9)
    //
    // Two methods (the third canvas thunk, `_textInputViewForAddingGestureRecognizers`, answers
    // the canvas itself and needs no bridge crossing — see `TGRichTextInputDecClientBridge.h`'s
    // own note on this group). Neither touches `inputDelegate` — hard invariant 10 stays
    // unaffected, since UIKit's private interaction assistant reads these ACCESSORS directly
    // (`methodSignatureForSelector:`/`objc_msgSend`), never through a `UITextInputDelegate` send.

    /// `backend.kernelInteraction` is `nil` until `IDUIKitBehaviorKernel`'s construction accepts
    /// the `.interaction` contract (this task's own `requestedCapabilities` addition) — so this
    /// answers nil for every attach that predates a live kernel, exactly like every other
    /// kernel-witness accessor in this file answers its "absent" value rather than fabricating one.
    ///
    /// GUARDED, like every kernel-facing crossing point in this package must be
    /// (`IDBackendCallGuardTests.test_everyKernelCallIsInsideTheExceptionGuard`, a MECHANICAL scan
    /// that flags any `kernelInteraction?.`/`kernelInput?.` access outside
    /// `TGRichTextInputDecPerform*` — caught real red the first draft of this method, which read
    /// `backend.kernelInteraction?.privateAssistant` bare: `XCTAssertEqual failed:
    /// ("["IDTextEditorBackendClientBridge.swift:286"]") is not equal to ("[]")`, quoted verbatim in
    /// this task's report). `privateAssistant` is a plain property read, not one of the kernel's
    /// seven surviving `@throw` sites — but the guard is a blanket rule ("every reachable entry
    /// point"), not a per-call risk judgment, matching every other property read on `kernelInput`/
    /// `kernelInteraction` elsewhere in this package.
    func canvasInteractionAssistant() -> Any? {
        var error: NSError?
        let assistant = TGRichTextInputDecPerformReturningObject({
            self.backend.kernelInteraction?.privateAssistant
        }, &error)
        if let error { backend.reportKernelFailure(error, witness: #function) }
        return assistant
    }

    /// `host?.presentationClient.interactionContainerView` — NOT `canvas.selectionChromeContainer`
    /// directly: this bridge has no canvas reference of its own, only `host`, and the two must
    /// agree regardless (`TelegramPresentationInputClient.interactionContainerView` forwards to
    /// exactly that canvas property). See `IDTextEditorBackend.swift`'s Step-4 doc comment for why
    /// this container's identity is already stable by the time ANY backend attaches.
    func interactionContainerView() -> UIView? {
        host?.presentationClient.interactionContainerView
    }

    // MARK: Task C14 — spellchecking and annotations (Family 11)
    //
    // The seven annotation methods forward straight to `host?.annotationClient`
    // (`TelegramAnnotationInputClient` for the real Telegram host) — the client the LEGACY backend
    // already calls through `LegacyRichTextInputBackend.annotation`; this bridge adds no new
    // business logic of its own, only the ObjC-primitive ↔ Swift-client reshaping every other
    // group in this file performs. `revision`/`range` arrive from the layout controller already
    // RAW (unresolved — see `TGRichTextInputDecLayoutController.m`'s Family-11 section and
    // DIVERGENCES.md entry 14), so nothing here re-derives or rebases them.

    /// Task R4 FIX — see `selectionRects(forRange:visibleRect:revision:)` above: same silent
    /// absence, same audit, same fix shape.
    @objc(annotatedSubstringForRange:revision:)
    func annotatedSubstring(forRange range: NSRange, revision: UInt64) -> NSAttributedString? {
        host?.annotationClient.annotatedSubstring(in: range, revision: revision)
    }

    func annotationValue(forKey key: Any, atPosition utf16Offset: Int, revision: UInt64) -> Any? {
        guard let host else { return nil }
        return host.annotationClient.annotationValue(
            for: Self.hashableAnnotationKey(key),
            at: RichTextInputPosition(utf16Offset: utf16Offset, affinity: .downstream),
            revision: revision)
    }

    func addAnnotationKey(_ key: Any, value: Any, range: NSRange, revision: UInt64) -> Bool {
        guard let host else { return false }
        return host.annotationClient.addAnnotation(
            key: Self.hashableAnnotationKey(key), value: value, range: range, revision: revision)
    }

    func removeAnnotationKey(_ key: Any, range: NSRange, revision: UInt64) -> Bool {
        guard let host else { return false }
        return host.annotationClient.removeAnnotation(
            key: Self.hashableAnnotationKey(key), range: range, revision: revision)
    }

    /// `key` crosses the bridge as plain `id`/`Any` (mirrors `RichTextInputAnnotationClient`'s own
    /// `AnyHashable` — see this header's opaque-annotation-key rule); `AnyHashable`'s dynamic-cast
    /// initializer handles every real ObjC key type sent today (`TelegramAnnotationInputClient`'s
    /// three consumers all ignore `key` outright — see its own doc comment — so this coercion is
    /// never on a load-bearing path, only a defensive "never crash on a foreign key type" fallback).
    private static func hashableAnnotationKey(_ key: Any) -> AnyHashable {
        (key as? AnyHashable) ?? AnyHashable(String(describing: key))
    }

    func addRenderingAttributes(_ attributes: [NSAttributedString.Key: Any],
                                range: NSRange, revision: UInt64) -> Bool {
        guard let host else { return false }
        return host.annotationClient.addRenderingAttributes(attributes, range: range, revision: revision)
    }

    func removeRenderingAttributes(_ keys: [NSAttributedString.Key],
                                   range: NSRange, revision: UInt64) -> Bool {
        guard let host else { return false }
        return host.annotationClient.removeRenderingAttributes(keys, range: range, revision: revision)
    }

    /// Task R4 FIX — see `selectionRects(forRange:visibleRect:revision:)` above: same silent
    /// absence, same audit, same fix shape.
    @objc(invalidateTemporaryAttributesInRange:revision:)
    func invalidateTemporaryAttributes(inRange range: NSRange, revision: UInt64) {
        host?.annotationClient.invalidateTemporaryAttributes(in: range, revision: revision)
    }

    // The two spellchecking canvas thunks (`TGRichTextInputDecCanvasCallbacks.m`). Design decision
    // recorded in DIVERGENCES.md entry 14: the setter does BOTH of two things, neither of which
    // alone matched the brief's own `Consumes (kernel)` / `Produces` split —
    //   (a) reaches the kernel's own OUTGOING `.checking` capability (`kernelInput
    //       .setContinuousSpellCheckingEnabled`), guarded like every other kernel call in this
    //       file, so the REAL system continuous-checking flag moves when the contract is accepted;
    //   (b) mirrors the value onto `(host?.hostInputView as? DocumentCanvasView)?
    //       .isSpellCheckingEnabled` — the SAME cast pattern `IDTextEditorBackend.swift`'s own
    //       `attach(to:)` and `+Responder.swift` already use — so Telegram's own model flag stays
    //       in step with whatever toggled continuous checking, matching what the manifest's
    //       `legacyCanvas` reference group documents the REAL system canvas class doing for this
    //       exact selector pair.
    // The getter reads (b) only: `isSpellCheckingEnabled` is Telegram's own single source of
    // truth for "is checking on" (the kernel's own flag is a mirror, not authoritative — the
    // native-checking driver `installCheckingIfNeeded()`/`checkOnSelectionChange()` this backend
    // implements as no-ops read (b) too, via the canvas's own `isSpellCheckingEnabled` `didSet` —
    // see `RichTextInputBackend.swift`'s D37 note for why this backend's checking LIFECYCLE stays
    // separate from the kernel's continuous-checking flag).

    func setNativeContinuousSpellCheckingEnabled(_ enabled: Bool) {
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.backend.kernelInput?.id_setContinuousSpellCheckingEnabled(enabled)
        }, &error)
        if let error { backend.reportKernelFailure(error, witness: #function) }
        (host?.hostInputView as? DocumentCanvasView)?.isSpellCheckingEnabled = enabled
    }

    func isNativeContinuousSpellCheckingEnabled() -> Bool {
        (host?.hostInputView as? DocumentCanvasView)?.isSpellCheckingEnabled ?? false
    }
}
#endif
