#if canImport(UIKit)
import UIKit
import RichTextInputDecObjC

/// The InputDec input backend. Availability is drawn ONCE here, in Swift: nothing in the
/// Objective-C module is annotated `API_AVAILABLE`, so the whole module compiles at the iOS 13
/// floor and only this type raises the bar.
///
/// EVERY member below except `isSupported()`, `attach(to:)`, and `detach()` (Task C0's real
/// routing) is a placeholder that fails LOUDLY rather than plausibly. This is deliberate: a
/// conformer stubbed to plausible values (a caret at 0, a silent no-op `attach`) type-checks,
/// runs, and makes an `.inputDec` test pass while testing nothing — the exact failure the
/// CoreList backend hit with its `0.0`/`false` stubs.
///
/// **Task B3 note on scope.** `RichTextInputBackend` composes five UIKit-witness protocols
/// (`RichTextInputTextBackend`, `RichTextKeyInputBackend`, `RichTextInputResponderBackend`,
/// `RichTextInputInteractionBackend`, `RichTextInputCheckingBackend`) plus 30 requirements of its
/// own — 86 requirements in total, not 30; "30" is only the count declared directly on the
/// composite `protocol RichTextInputBackend { ... }` body. A full conformance needs a body for
/// every one of the 86, so this file supplies all of them, not only the six the task brief's
/// illustrative Step-5 snippet spells out verbatim (`isSupported()`/`init()`/`state`/`isAttached`/
/// `attach(to:)`/`detach()`/`synchronizeAfterExternalChange(_:)`/`setSelection(_:reason:)`, kept
/// exactly as given). The stub rule for everything else, applied mechanically so the choice is
/// checkable at a glance rather than picked per member:
///
///   (a) A `Void` requirement with no closure parameter is a no-op (`{}`) — the same shape the
///       brief itself gives `detach()`/`synchronizeAfterExternalChange(_:)`/`setSelection(_:reason:)`,
///       and the one `RichTextInputCheckingBackend` explicitly sanctions in its own doc comment
///       ("a conformer with no checking of its own implements both as no-ops").
///   (b) A `Void` requirement that takes a `body: () -> Void` closure invokes it exactly once and
///       does nothing else — never dropping a caller's closure is a stronger obligation than a
///       no-op would honor, since a caller relies on `body` actually running.
///   (c) A `{ get set }` requirement is backed by a real stored property. There is nothing to
///       "fake" about a passive settable slot — storing exactly what is set and returning exactly
///       what was stored is a complete, correct implementation on its own terms.
///   (d) Everything else — a `{ get }` requirement not covered by (c), and any non-`Void`,
///       non-closure-taking function — answers with the member's own DOCUMENTED absent value where
///       the protocol states one (several do, explicitly: `undoManager`'s doc says "nil ... is what
///       a detached backend answers"; `floatingScrollVelocity`'s doc says "zero means not
///       auto-scrolling"; `isComposing`'s doc says it must equal `markedRange != nil`; `firstRect`/
///       `caretRect`'s doc names the `.zero` fallback shape). Composition/selection/floating-cursor
///       getters read through the already-given `state`/no-gesture facts for the same reason
///       `state` itself does (never composing, caret at 0, no gesture in flight — genuinely true of
///       an object that has never attached, not a fabricated value). UIKit-witness getters with an
///       Optional or empty-collection shape answer `nil`/`[]`, which is standard, unremarkable
///       UITextInput behavior ("no answer") rather than a claim about content that does not exist.
///       Where NO honest empty answer exists in the type itself — a concrete `UITextPosition`/
///       `UITextRange`/`UITextInputTokenizer` instance, or a `ComparisonResult`/offset `Int` that
///       would assert a spatial relationship between positions this backend cannot resolve —
///       `fatalError(...)` is the answer, because any other value would be exactly the "plausible
///       fake" this class's own doc comment (above) warns against.
@available(iOS 17.0, *)
final class IDTextEditorBackend: RichTextInputBackend {
    /// Pure and side-effect-free: constructs no object, installs no method, sends no private
    /// selector. Safe to call from the canvas factory before any canvas exists.
    static func isSupported() -> Bool {
        #if !TG_RICHTEXT_INPUTDEC_ENABLED
        return false
        #else
        guard let manifest = TGRichTextInputDecContractManifest() else { return false }
        return Self.runtimeMatches(manifest) && Self.mandatoryContractsAccepted(manifest)
        #endif
    }

    /// DECISION 2 (2026-08-17): the policy is a FLOOR of iOS 17.0, not an exact match against
    /// the manifest's `runtime` block.
    ///
    /// The consequence is deliberate and must not be "fixed" back: the kernel will run on OS
    /// builds it has never been certified against, so the manifest stops being the gate and
    /// becomes provenance. What keeps that safe is `mandatoryContractsAccepted` below — it
    /// evaluates the three mandatory contracts against the LIVE runtime on every call, so an
    /// ABI change on an uncertified OS is rejected there and the factory falls back to legacy.
    /// A matching type encoding still does not prove matching semantics; that residual risk is
    /// accepted, and Stage D's differential run against the pinned corpus is what would catch
    /// it. See "Honest constraints" section 1.
    private static let minimumMajorVersion = 17

    private static func runtimeMatches(_ manifest: IDUIKitRuntimeManifest) -> Bool {
        let running = ProcessInfo.processInfo.operatingSystemVersion
        return running.majorVersion >= minimumMajorVersion
    }

    /// Pure runtime introspection: NSClassFromString, class_getInstanceMethod,
    /// method_copyReturnType. No instance is constructed, no method is installed, and no
    /// private selector is sent.
    private static func mandatoryContractsAccepted(_ manifest: IDUIKitRuntimeManifest) -> Bool {
        let resolver = IDUIKitCapabilityResolver.system()
        for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
            guard let contract = manifest.capabilities[name],
                  resolver.evaluateContract(contract).isAccepted else { return false }
        }
        return true
    }

    init() {}

    /// Constructed MEMBERWISE. `RichTextInputStateSnapshot` (spec lines 221-226) is
    /// `{ documentRevision, selection, markedRange, isComposing }` and has **no `static let
    /// empty`** — the seam plan only ever builds it memberwise. `.caret(at:)` and
    /// `.downstream(_:)` are the seam's own spellings (`RichTextInputTypesTests`, seam Task 10
    /// Step 3).
    private(set) var state = RichTextInputStateSnapshot(
        documentRevision: 0,
        selection: .caret(at: .downstream(0)),
        markedRange: nil,
        isComposing: false)
    private(set) var isAttached = false
    private(set) var report: IDUIKitBehaviorReport?

    /// ACCESS LEVEL IS LOAD-BEARING (Task C10, the identical file-scoping reason `kernelInput` below
    /// already documents): `+Responder.swift`'s `canPerformCommand(_:sender:)`/`performCommand(_:sender:)`
    /// need `host.lifecycleClient`/`host.commandClient`, and Swift's `private` is file-scoped. Plain
    /// `internal`; confinement still comes from `final` + the `InputBackend/InputDec/` source-boundary
    /// exemption, not from `private`.
    weak var host: (any RichTextInputHost)?
    private var bridge: IDTextEditorBackendClientBridge?
    /// Task D4d — the `selectedRange` of the `setMarkedText(_:selectedRange:)` call currently in
    /// flight, latched beside the `.markedText` intent. See
    /// `latchMarkedTextIntent(selectedRange:)` for the full account of why this value cannot reach
    /// the mutation any other way, and `takePendingMarkedTextSelectedRange()` for why reading it is
    /// destructive. `private` is enough: the only reader is
    /// `IDTextEditorBackendClientBridge.prepareAndCommitReplacement`, which goes through the two
    /// `internal` methods in this file rather than the storage directly.
    private var pendingMarkedTextSelectedRange: NSRange?
    private var layoutController: TGRichTextInputDecLayoutController?
    private var kernel: IDUIKitBehaviorKernel?
    /// ACCESS LEVEL IS LOAD-BEARING (Task C8, mirroring `LegacyRichTextInputBackend`'s own
    /// documented reasoning for the same situation): this class is now split across
    /// `IDTextEditorBackend.swift` and `+KeyInput.swift` (Family 5), and Swift's `private` is
    /// FILE-scoped — a `private var` here would make `+KeyInput.swift`'s
    /// `self.kernelInput?.deleteBackward()` a compile error. Plain `internal` (module-scoped, the
    /// package default); confinement comes from `final` + internal + the `InputBackend/InputDec/`
    /// source-boundary exemption (`InputBackendSourceBoundaryTests`'s `inputDecExemptPaths`), not
    /// from `private`.
    ///
    /// `kernelInteraction` WIDENED THE SAME WAY, at Task C11 (Family 8): `+Responder.swift`'s
    /// `hostDidResignFirstResponder()` calls `self.kernelInteraction?.resignedFirstResponder()`.
    /// Previously `private` because nothing outside this file read it — still true of every OTHER
    /// reader (`detach()`'s own `kernelInteraction?.detach()` call, three lines below, is IN this
    /// file), so the widening is solely for the new second file.
    ///
    /// **Task C12 (Family 9) adds a THIRD and FOURTH reader**, both already reachable through the
    /// SAME `internal` access level (no further widening needed): `+Interaction.swift`'s seven
    /// kernel witnesses, and `IDTextEditorBackendClientBridge.interactionAssistant()` — a
    /// DIFFERENT file, `IDTextEditorBackendClientBridge.swift`, which needs `backend.kernelInteraction`
    /// to back the `-interactionAssistant` canvas thunk. `internal` already covers a cross-file
    /// reader anywhere in this module, so no access-level change was needed for this addition —
    /// recorded here anyway, matching this property's own established practice of listing every
    /// reader as it gains one.
    var kernelInput: IDUIKitInputControllerCapability?
    var kernelInteraction: IDUIKitInteractionCapability?
    private weak var attachedCanvas: IDDocumentCanvasView?

    /// Task R12 (cluster 12) — backs the real `tokenizer` witness below, mirroring
    /// `LegacyRichTextInputBackend.tokenizerStorage` (`LegacyRichTextInputBackend.swift`)'s lifetime
    /// discipline exactly: built once `attach(to:)` is guaranteed to succeed (see that method's own
    /// comment at the construction site — everything after it is plain field assignment, so there
    /// is no throw path left to leak a stale cache into), cleared in `detach()`. Holds an
    /// `IDDocumentTokenizer` (`IDTextEditorBackend+Tokenizer.swift`), NOT a bare `DocumentTokenizer`
    /// — see that type's own header for why a raw `LegacyTextPosition`/`LegacyTextRange` result
    /// cannot be handed back to this backend's OTHER witnesses (`compare(_:to:)`, `textRange(from:to:)`,
    /// …), which is exactly what the vendored kernel's own `selectWord()` does with a tokenizer's
    /// output. `DocumentTokenizer` (`LegacyDocumentTokenizer.swift`) holds its canvas `unowned`, so —
    /// exactly like Legacy's copy — "who mints it" and "who clears it" must be the same body; the
    /// same discipline applies one level up, to this property.
    private var tokenizerStorage: UITextInputTokenizer?

    #if DEBUG
    /// test-only: the façade is backend-private, and nothing in production reads it. Task C7
    /// retypes this from `NSTextStorage?` (C0/C1's substitution, recorded on
    /// `IDTextEditorBackendClientBridge.storage`'s own DEVIATION comment) to the real façade type
    /// now that it exists — one of exactly three sites this task retypes; see this task's report.
    var storageFacadeForTesting: TGRichTextInputDecTextStorageFacade? { bridge?.storage }

    /// test-only, added by Task C14 for the SAME reason `storageFacadeForTesting` above exists:
    /// the seven Family-11 annotation callbacks (and the two spellchecking thunks) are backed by
    /// UNDECLARED, kernel/OS-driven-only private selectors on `TGRichTextInputDecLayoutController`
    /// — genuinely untestable by simulating a private-controller call (no Swift-visible entry
    /// point exists to trigger them, and the real native-checking machinery that WOULD drive them
    /// is async and OS-scheduled — see the package CLAUDE.md's own admission that grammar checking
    /// "did NOT fire in the unit-test host"). `IDBackendFamily4Tests` set this same precedent for
    /// C7's multi-arg thunks: it drives `storageFacadeForTesting` directly rather than the private
    /// selector that sets its latch. This hook lets `IDBackendFamily11Tests` drive the BRIDGE's own
    /// forwarding logic — the layer this task actually writes new behavior in — directly and
    /// deterministically.
    var bridgeForTesting: IDTextEditorBackendClientBridge? { bridge }
    #endif

    /// Every kernel witness failure recorded by `reportKernelFailure(_:witness:)`, oldest first.
    /// DISTINCT from `report` above (`IDUIKitBehaviorReport?`, the kernel's own one-shot
    /// capability-acceptance snapshot from construction) — this is a running diagnostic log of
    /// POST-construction witness failures (a post-detach call, or a raised `NSException` the
    /// exception guard converted into a value), added by Task C4. `private(set)` so tests can
    /// observe it without a production write path.
    private(set) var witnessFailures: [String] = []

    /// Task C4 Step 9. Called by every witness added in Step 8 when
    /// `TGRichTextInputDecPerform`/`TGRichTextInputDecPerformReturningObject` reports a caught
    /// `NSError` — either the kernel raised, or (the common case once `incomingCallbacks` is
    /// fully accepted and attach succeeds) `activeController` rejected a post-`detach()` call.
    /// Both are DOCUMENTED, correct outcomes for a witness to answer its "absent" value for —
    /// never a crash — so this method only RECORDS; it must never throw or trap a second time.
    ///
    /// `internal`, not `private`, as of Task C8 — for the identical file-scoping reason
    /// `kernelInput` above is now `internal`: `+KeyInput.swift`'s `deleteBackward()` calls this on
    /// its own two guarded witnesses.
    ///
    /// **TASK F1 — a kernel failure is RECORDED AND LOGGED, NEVER TRAPPED.** The body used to end in
    /// `#if DEBUG RichTextInputContractViolation.report(…) #endif`, which — with no reporter
    /// installed, i.e. in the actual app rather than a test host — is `assertionFailure()`. That made
    /// EVERY kernel witness failure fatal in a debug build, so the very first `caretRect(for:)` a
    /// user's tap produced killed the process (`Telegram-2026-08-26-171558.ips`). Fatal-on-first-gap
    /// is a hostile design for a flag a human is meant to switch on and try: the kernel is vendored,
    /// certified against exactly ONE OS build, raises `NSException` on any contract mismatch, and
    /// this method's OWN doc comment above already says both of its causes are "DOCUMENTED, correct
    /// outcomes for a witness to answer its 'absent' value for — never a crash". The trap contradicted
    /// the paragraph it sat under.
    ///
    /// Nothing is silenced. `witnessFailures` still records every failure (the tests read it), and the
    /// diagnostic is still emitted on every call — through `RichTextInputContractViolation.reporter`
    /// when one is installed, so every suite that observes kernel failures through that hook
    /// (`BackendSemanticContractCases`, `IDFakeClientHarness`, `makeBackendHarness`, …) keeps working
    /// unchanged, and through `NSLog` otherwise, which is exactly what
    /// `RichTextInputContractViolation.report` itself does in a RELEASE build. The reporter is read
    /// directly rather than calling `report(_:)` because `report(_:)`'s no-reporter DEBUG branch is
    /// the `assertionFailure` this method must no longer reach; the shared type's own policy for
    /// genuine PROGRAMMER violations (spec failure class 1 — a detached-backend mutation, a
    /// double-attach) is deliberately left alone, because those are ours to get right, whereas a
    /// kernel witness failure is the vendored kernel declining to answer.
    func reportKernelFailure(_ error: NSError, witness: String) {
        witnessFailures.append("\(witness): \(error.localizedDescription)")
        let message = "InputDec kernel witness '\(witness)' failed: \(error.localizedDescription)"
        if let reporter = RichTextInputContractViolation.reporter {
            reporter(message)
        } else {
            NSLog("RichTextInput contract violation (recorded, not trapped): %@", message)
        }
    }

    // MARK: - Task R2 — `insertText(_:)`'s transaction-boundary state
    //
    // `insertText(_:)` is now the ONE genuine `RichTextInputBackend` mutation entry point this
    // conformer owns as a first-party obligation (unlike `LegacyRichTextInputBackend`'s own
    // `insertText`, which is a plain `legacyCanvas` forward under D35 — the eight stage-1 contract
    // suites drive `IDTextEditorBackend` directly, with no test-only substitute standing in). These
    // three fields are the minimal state its transaction bracket needs: whether a mutation is
    // currently in flight, and what a reentrant `detach()`/`synchronizeAfterExternalChange(_:)`
    // fired from inside that bracket's own notification/publish callbacks left pending for the
    // bracket to drain once it returns.
    //
    // Task R9 (cluster 6, Step 3) CORRECTION: the paragraph above used to end here, claiming "a
    // single boolean is the complete, correct answer for the one bracket that exists" and that this
    // backend deliberately lacked Legacy's `activeTransactionDepth` nesting counter because
    // `setSelection`/`clearCompositionState` never opened a bracket of their own. That was true THEN
    // (`isMutating` alone was enough because `endTransaction()`'s deferred-change drain was itself
    // unconditional and unbounded) and is FALSE now that the drain is bounded (see
    // `endTransaction()`'s own doc comment) — bounding it needs to know whether the CURRENT call is
    // the outermost one, which `isMutating` alone cannot answer once `synchronizeAfterExternalChange`
    // can recurse into itself via that same drain. `activeTransactionDepth` below is that counter,
    // mirroring `LegacyRichTextInputBackend.activeTransactionDepth` at the granularity this backend
    // has reached: EVERY bracket this backend owns — `insertText(_:)`, `synchronizeAfterExternalChange(_:)`'s
    // real branch, and `setSelection(_:reason:)`'s final publish (plus its coalescing-flush `didSet`) —
    // routes through the shared `withTransaction(_:)` chokepoint (declared alongside
    // `endTransaction()`), exactly like Legacy's own six call sites funnel through ITS
    // `withTransaction`. `insertText(_:)`/`synchronizeAfterExternalChange(_:)` wrap their whole
    // `isMutating = true … isMutating = false` span (their own `isMutating = true` sits just OUTSIDE
    // the closure, `isMutating = false` as its last statement); `setSelection` never touches
    // `isMutating` at all, so it only wraps its own final publish. See `withTransaction(_:)`'s own
    // doc comment for why routing through it — rather than a bare `activeTransactionDepth += 1` at
    // each call site — is required, not merely tidier.
    private var isMutating = false
    private var activeTransactionDepth: Int = 0
    /// Task R11 (cluster 17) — mirrors `activeTransactionDepth > 0` (equivalently, Legacy's
    /// `transactionPhase != .idle`) without reading `activeTransactionDepth` directly outside its two
    /// sanctioned mutation sites (Core rule R12,
    /// `InputBackendSourceBoundaryTests.test_activeTransactionDepthMutatedOnlyInSanctionedFunctions_R12`).
    /// Set `true` alongside `activeTransactionDepth += 1` in `withTransaction(_:)` and `false` exactly
    /// when `endTransaction()` observes the counter reaching 0 — the same two chokepoints, so the two
    /// fields cannot drift out of step. `setSelection(_:reason:)`'s member-level reentrancy guard
    /// reads this to detect ANY open bracket (its own, `insertText(_:)`'s, or
    /// `synchronizeAfterExternalChange(_:)`'s) — see that guard's own doc comment for why a
    /// setSelection-scoped flag (this task's first, wrong draft) is not equivalent.
    private var isInsideAnyTransaction = false
    private var detachRequested = false
    private var deferredExternalChange: RichTextInputExternalChange?

    /// Stage C starts with the three mandatory capabilities only. `interaction` and
    /// `floatingCursor` are added by later tasks; autoscroll is never requested — InputDec's
    /// autoscroll assumes the first responder IS the UIScrollView, and Telegram's canvas is a
    /// UIView inside a separate `GripYieldingScrollView`. See DIVERGENCES.md.
    ///
    /// SPELLING — CORRECTED BY THIS TASK, empirically, against an `xcodebuild` simulator build
    /// (`swift build` cannot check this: `IDTextEditorBackend.swift` is entirely
    /// `#if canImport(UIKit)`-gated, so the macOS SwiftPM host build never type-checks this file
    /// at all — the exact trap the package `CLAUDE.md` documents). The brief's own Step 5 prose
    /// claimed Swift stops stripping at `IDUIKitBehavior`, keeping the word "Capability" on each
    /// case (`.capabilityInputController`, …) because "Capabilities" (the type name) ≠
    /// "Capability" (the shared enumerator prefix). That is WRONG — a real build rejects every
    /// `.capabilityXxx` spelling with "has no member". Swift's NS_OPTIONS importer DOES singularize
    /// the type name for this comparison (the same well-known behavior that turns
    /// `UIViewAnimationOptionCurveEaseInOut` into `.curveEaseInOut`), so the FULL
    /// `IDUIKitBehaviorCapability` prefix strips, leaving plain `.inputController`,
    /// `.typingAttributes`, `.incomingCallbacks` (and `.interaction`, `.floatingCursor`,
    /// `.prediction`, `.paste`, `.checking`, `.dictation`, `.autoscroll`) — confirmed by
    /// deliberately trying both spellings against the real simulator build.
    ///
    /// **`.prediction` added by Task C9 (Family 6, marked text and prediction).** The task-C9
    /// supplement's §1 already flagged the brief's `.capabilityPrediction` spelling as the same
    /// class of error this comment's own header describes for `.capabilityInputController` — the
    /// correct spelling is `.prediction`, consistent with the rest of this list. Requesting it is
    /// SAFE to add unconditionally: `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames`
    /// loop (which `prediction` is one of, alongside `checking`/`typingAttributes`/`paste`/
    /// `dictation`) never gates construction on the result — unlike the single
    /// `declarativeCapabilityNames = @[@"incomingCallbacks"]` entry a few lines above it in that
    /// same initializer, which DOES `[input detach]` + throw when its contract is rejected. A
    /// rejected `.prediction` contract simply leaves `IDUIKitInputControllerCapability
    /// .hasValidatedCapability(.prediction)` false, and `-setAttributedMarkedText:selectedRange:`
    /// (`IDUIKitInputControllerCapability.m:274-288`) falls back to the plain
    /// `-setMarkedText:selectedRange:` this backend already routes through `kernelInput` in
    /// `+TextBackend.swift`. So adding this bit cannot move the `incomingCallbacks` mismatch count
    /// (a SEPARATE, single-contract gate) or the attach failure text — both re-measured unchanged
    /// in this task's report.
    ///
    /// **`.interaction` added by Task C12 (Family 9, touch interaction and selection).** The
    /// task-C12 supplement's §2 flagged the brief's `.capabilityInteraction` spelling as the SAME
    /// class of error (the ninth wrong Swift/ObjC name in this plan's prose, the fourth of exactly
    /// this shape) — correct spelling `.interaction`, consistent with the rest of this list.
    /// **Confirmed safe by reading the kernel source, not inferred from `nullable`:** `.interaction`
    /// is NOT one of `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames` (that array is
    /// `checking`/`typingAttributes`/`prediction`/`paste`/`dictation` only) — it is validated by its
    /// OWN dedicated `wantsInteraction` block a few lines above that array, whose FAILURE PATH reads
    /// as fatal at first glance (`interactionContract == nil` or `IDUIKitInteractionCapability`
    /// construction failing both `[input detach]` + throw, exactly like the single mandatory
    /// `incomingCallbacks` gate). It is safe anyway, for a DIFFERENT reason than `.prediction`'s:
    /// `IDUIKitInteractionCapability.initWithContract:resolver:view:error:` (`IDUIKitInteractionCapability.m`)
    /// has NO code path that returns nil — every failure branch (contract rejected, the host-preflight
    /// ABI check throwing, the private assistant class missing, or the assistant's own `initWithView:`
    /// raising) still runs `self = [super init]; …; return self`, populating only `report`/
    /// `floatingCursorReport` and leaving `privateAssistant` nil. So the kernel's own `if (interaction
    /// == nil) { … return nil; }` check is DEAD CODE in practice (unreachable unless `manifest
    /// .capabilities[@"interaction"]` itself were absent, which every other row in this file already
    /// establishes it is not) — a rejected `.interaction` contract simply leaves `_interaction` unset
    /// on the kernel (since `_interaction = interaction` is itself gated on `interaction
    /// .privateAssistant != nil`), i.e. `kernel.interaction` stays nil, exactly the pre-C12 state.
    /// So adding `.interaction` cannot move the `incomingCallbacks` mismatch count or the attach
    /// failure text either — both re-measured unchanged in this task's report — via a mechanism this
    /// task verified is genuinely different from C9/C10's, not merely assumed to match.
    ///
    /// **`.floatingCursor` added by Task C13 (Family 10, floating cursor; autoscroll deliberately
    /// deferred — see DIVERGENCES.md entry 1 and entry 13).** The brief's own Step 3 spells this
    /// `.capabilityFloatingCursor`, WRONG in the same way as every entry this file's own list above
    /// already names — the enum is `IDUIKitBehaviorCapabilityFloatingCursor`
    /// (`include/Kernel/IDUIKitBehaviorCapabilities.h`) and Swift strips the shared
    /// `IDUIKitBehaviorCapability` prefix, leaving `.floatingCursor`.
    ///
    /// **Confirmed safe by reading the kernel source — and it does NOT pattern-match C9/C10/C12.**
    /// `.floatingCursor` is NOT one of `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames`
    /// (`checking`/`typingAttributes`/`prediction`/`paste`/`dictation` only), and unlike
    /// `.interaction` it has NO dedicated gate of its own either: `IDUIKitBehaviorCapabilityFloatingCursor`
    /// is read in exactly two places in `IDUIKitBehaviorKernel.m` — computing `wantsFloating`, and a
    /// single `if (wantsFloating) { [reports addObject: interaction.floatingCursorReport]; }` inside
    /// the `wantsInteraction` branch — appending an ALREADY-COMPUTED diagnostic report to the
    /// construction-time `IDUIKitBehaviorReport`. It never gates construction and can never throw on
    /// its own account.
    ///
    /// **The floating-cursor contract is evaluated UNCONDITIONALLY inside `IDUIKitInteractionCapability`
    /// .initWithContract:resolver:view:error:` — triggered purely by `.interaction` (requested since
    /// Task C12), independent of whether `.floatingCursor` is requested at all.** That init calls
    /// `IDUIKitFloatingCursorRuntimeContract()` (`IDUIKitInteractionCapability.m:132`, one of the
    /// kernel's seven surviving `@throw` sites — raises `NSInternalInconsistencyException` when
    /// `manifest.capabilities[@"floatingCursor"]` is nil) on EVERY successful `.interaction`
    /// construction, before checking `requested` at all, and sets `_floatingCursorAvailable =
    /// floatingResult.isAccepted` the same way — so `beginFloatingCursorAtPoint:`/
    /// `updateFloatingCursorAtPoint:animated:`/`endFloatingCursor` (each gated on
    /// `self.floatingCursorAvailable`, `IDUIKitInteractionCapability.m`) were ALREADY live-or-inert
    /// purely from `.interaction`, before this task ever ran. **Consequence: requesting
    /// `.floatingCursor` here changes NOTHING about whether those three witnesses fire — it changes
    /// only whether `interaction.floatingCursorReport` is folded into the construction-time
    /// diagnostic `IDUIKitBehaviorReport`.** Requested anyway, for bookkeeping parity with the rest
    /// of this list and because the brief's Step 3 asks for it, not because runtime behavior depends
    /// on it.
    ///
    /// **The reachable-throw hazard this task's supplement flagged is real but PRE-EXISTING, not
    /// newly introduced.** `IDUIKitFloatingCursorRuntimeContract()`'s `@throw` fires only if
    /// `manifest.capabilities[@"floatingCursor"]` is nil — live-verified NON-nil (3 members) on this
    /// runtime by `IDTextEditorBackendFloatingCursorSuppressionTests
    /// .test_floatingCursorCapabilityIsPresentInTheManifest`, a non-skip-gated test that needs no
    /// attach and no live kernel (manifest loading alone). The whole call chain that could reach it
    /// — `attach(to:)`'s `TGRichTextInputDecPerformReturningObject { try IDUIKitBehaviorKernel(...) }`
    /// block (Step 7 above) → `IDUIKitBehaviorKernel`'s init → `IDUIKitInteractionCapability`'s init
    /// — sits entirely INSIDE that block, so IF it ever fired it would be caught there and surfaced
    /// as `RichTextInputBackendAttachmentError.privateRuntimeFailure(...)`, never crash. This task
    /// could not force the manifest to omit the key without editing vendored/generated data
    /// (off-limits), so — like Task C0's own note on A8 — this is static-proof-plus-one-live-check
    /// that the precondition does not hold today, not a genuine exercise of the catch.
    ///
    /// So adding `.floatingCursor` cannot move the `incomingCallbacks` mismatch count or the attach
    /// failure text (both re-measured unchanged in this task's report) — for the same "this
    /// contract is not one of the two mismatch-tracked arrays" reason `.prediction`/`.interaction`
    /// established, verified independently rather than assumed to match by analogy.
    ///
    /// **`.checking` added by Task C14 (Family 11, spellchecking and annotations) — the brief's
    /// `.capabilityChecking` is WRONG, the eleventh instance of exactly this shape.** The enum is
    /// `IDUIKitBehaviorCapabilityChecking` (`include/Kernel/IDUIKitBehaviorCapabilities.h`), Swift
    /// strips the shared prefix, leaving `.checking` — confirmed against the real simulator build,
    /// not assumed from the pattern (the supplement itself flagged that C12/C13's own "confirm,
    /// don't assume" lesson applies here too).
    ///
    /// **Confirmed safe by reading the kernel source: `.checking` IS one of
    /// `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames`**
    /// (`checking`/`typingAttributes`/`prediction`/`paste`/`dictation`, `:260-266`) — the SAME
    /// purely-declarative loop `.prediction` already established is safe: a rejected contract only
    /// leaves `IDUIKitInputControllerCapability.hasValidatedCapability(.checking)` false (so
    /// `kernelInput?.setContinuousSpellCheckingEnabled`/`.isContinuousSpellCheckingEnabled` — see
    /// `IDTextEditorBackendClientBridge`'s new pair — silently no-op/answer NO), never `[input
    /// detach]` + throw the way the single mandatory `incomingCallbacks` gate does. So adding
    /// `.checking` cannot move the `incomingCallbacks` mismatch count or the attach failure text —
    /// this task's own 7 `incomingCallbacks` rows (Family 11's real gate-opening work, wired in
    /// `TGRichTextInputDecLayoutController.m`) are what does that; see DIVERGENCES.md entry 14.
    private static var requestedCapabilities: IDUIKitBehaviorCapabilities {
        [.inputController, .typingAttributes, .incomingCallbacks, .prediction, .interaction,
         .floatingCursor, .checking]
    }

    func attach(to host: any RichTextInputHost) throws {
        guard !isAttached else { throw RichTextInputBackendAttachmentError.alreadyAttached }
        guard let canvas = host.hostInputView as? IDDocumentCanvasView else {
            throw RichTextInputBackendAttachmentError.incompatibleHost(
                "IDTextEditorBackend requires IDDocumentCanvasView, got \(type(of: host.hostInputView))")
        }
        guard let manifest = TGRichTextInputDecContractManifest() else {
            throw RichTextInputBackendAttachmentError.missingCapability("contract manifest")
        }
        var installError: NSError?
        guard TGRichTextInputDecInstallCanvasCallbacks(
                IDDocumentCanvasView.self, DocumentCanvasView.self, &installError) else {
            throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                installError?.localizedDescription ?? "canvas callback install")
        }
        let bridge = IDTextEditorBackendClientBridge(host: host, backend: self)
        // Task R3 — the explicit push half of the seed/resync mechanism (the facade's own lazy
        // call, at the top of `replaceCharactersInRange:withString:`, is the half that a document
        // set via `setBlocks`/`setParagraphs` after this returns still needs — see the facade
        // header's own doc comment for the full two-call-site rationale, including the third call
        // site that was tried here and reverted). At THIS instant `host.documentClient` is usually
        // still empty (attach happens
        // synchronously inside `DocumentCanvasView.init`, before any content-seeding call can
        // run), so this is a no-op in that common case — but the fake-client test harness
        // (`makeIDFakeClientHarness`) constructs its host WITH real content before calling
        // `attach(to:)`, and a real re-attach after a mode switch could too. `bridge.storage` is
        // safe to touch here: `IDTextEditorBackendClientBridge.init` already wired
        // `storage.bridge = self` before returning.
        bridge.storage.synchronizeMirrorWithDocumentIfNeeded()
        let layoutController = TGRichTextInputDecLayoutController(bridge: bridge)
        layoutController.textStorageFacade = bridge.storage

        // STEP 7 — the exception guard, and a collision the brief's prose does not mention.
        // `IDUIKitBehaviorKernel(manifest:…)` is declared `nullable` AND takes an `NSError **`,
        // so Swift does NOT import it as an optional initializer (the brief's "returns nil on
        // rejection" is the Objective-C truth only) — Swift's Cocoa error-convention importer
        // drops the `nullable`/`error:` pair entirely and synthesizes ONLY a THROWING
        // initializer (`try IDUIKitBehaviorKernel(manifest:…)`, no `error:` argument, no
        // Optional). There is no parallel non-throwing entry point to call instead — the raw
        // `error:`-taking selector is not reachable from ordinary Swift call syntax.
        //
        // That collides with wrapping construction in A8's block-based guard, because a thrown
        // Swift error cannot propagate out of the `@convention(block)` closure
        // `TGRichTextInputDecPerformReturningObject` requires (the block's inferred type is a
        // plain, non-throwing `() -> Any?`, matching the ObjC `id _Nullable (^)(void)`).
        //
        // RESOLUTION: `do`/`catch` INSIDE the block. `try` runs there and on failure the `catch`
        // captures the thrown error into `kernelError` (a local the closure closes over) and
        // returns `nil` in its place — no `throw` ever crosses the block boundary, so the block
        // stays non-throwing. Outside the block, `guardError` (set when the trampoline itself
        // caught a raised NSException — the kernel's construction path can genuinely raise, not
        // just reject: see `IDUIKitInputControllerCapability.m`'s `@try/@catch` around the real
        // private controller's own initializer) and `kernelError` (set on an ordinary rejection)
        // are both read back to build ONE thrown `RichTextInputBackendAttachmentError`. Neither
        // failure mode is swallowed — this is the "capture the result and any thrown error into
        // locals inside the block, then re-raise outside" shape the supplement describes.
        var kernelError: NSError?
        var guardError: NSError?
        // TASK H1 — `delegate:` IS THE HOST VIEW, NOT THE BRIDGE. The kernel passes this argument
        // straight to `-[UITextInputController setDelegate:]`
        // (`Kernel/IDUIKitInputControllerCapability.m`), and the upstream host makes ITSELF the
        // delegate on every construction path (`IDBlockTextView.m`'s `delegate:self`, the reference
        // path, and both private factories) — which is why upstream's
        // `IDBlockTextView+PrivateInputDelegate.m` is a category ON THE VIEW.
        //
        // This used to pass `bridge`, and that was not a harmless renaming of the receiver: it made
        // three installed canvas thunks UNREACHABLE. MEASURED, not inferred (see task-H1-report.md):
        // `-setDelegate:` caches a responds-to bitmask at assignment time, querying the incoming
        // delegate about 17 selectors — `textInputDidChange:`, `textInputDidChangeSelection:` and
        // `textInput:shouldChangeCharactersInRanges:replacementText:` among them. The bridge answers
        // NO to all three (its own spellings are `delegateTextInputDidChange` &c.), so the controller
        // never sent them; with a delegate that answers YES, one kernel-driven `deleteBackward()`
        // delivers `textInputDidChangeSelection:` twice and `textInputDidChange:` once. The canvas
        // answers YES to exactly those three of the 17 and to none of the other fourteen, so this
        // re-point enables the three installed thunks and nothing else.
        //
        // Safe for lifetime: the property is `T@"<UITextInputControllerDelegate>",W,N` — **weak** —
        // confirmed by measurement as well as by the attribute string (dropping the last strong
        // reference to a probe delegate nils it out), so the canvas → backend → kernel → controller
        // → canvas edge is not a retain cycle. This is also why the bridge could be handed over as
        // an `OBJC_ASSOCIATION_ASSIGN` associated object elsewhere without a matching hazard.
        let constructed = TGRichTextInputDecPerformReturningObject({
            do {
                return try IDUIKitBehaviorKernel(manifest: manifest,
                                                  resolver: .system(),
                                                  layoutController: layoutController,
                                                  delegate: canvas,
                                                  view: canvas,
                                                  requestedCapabilities: Self.requestedCapabilities)
            } catch {
                kernelError = error as NSError
                return nil
            }
        }, &guardError)
        guard let kernel = constructed as? IDUIKitBehaviorKernel else {
            // Atomicity: everything above is a local; nothing has been published and the
            // associated object is not set until the last line below. Either failure mode — a
            // nil return (`kernelError`) or a raised NSException (`guardError`) — lands here as
            // one thrown Swift error.
            throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                guardError?.localizedDescription
                ?? kernelError?.localizedDescription
                ?? "kernel construction")
        }
        self.host = host
        self.bridge = bridge
        self.layoutController = layoutController
        self.kernel = kernel
        self.kernelInput = kernel.inputController
        // Task C11 (Family 8) completed a wiring `detach()` already anticipated —
        // `kernelInteraction?.detach()` has called this property since Task C0's illustrative
        // nine-step snippet, but nothing ever ASSIGNED it, so it was permanently nil.
        // **Task C12 (Family 9) is what makes this assignment LIVE**: `.interaction` is now in
        // `requestedCapabilities` above (see that property's own doc comment for why requesting it
        // is safe), so once C14 clears the `incomingCallbacks` gate this can resolve to a real,
        // non-nil `IDUIKitInteractionCapability` whose `privateAssistant` is also non-nil (both
        // conditions the kernel's own construction requires before setting `_interaction` — see
        // `requestedCapabilities`'s doc comment). DIVERGENCES.md entry 1 (autoscroll/interaction
        // stay Telegram-owned) is narrowed, not reversed, by DIVERGENCES.md entry 12: autoscroll
        // is still never requested, but `.interaction` now is — the entry is left in place per this
        // log's own "narrowing gets a new entry" convention.
        //
        // **Step 4 verification (this task's own, not new code): the interaction container's
        // identity is ALREADY stable by the time this line runs, with NO help needed from this
        // file.** `DocumentCanvasView.init` constructs `presentationInputClient =
        // TelegramPresentationInputClient(canvas: self, facade: nil)` UNCONDITIONALLY, immediately
        // BEFORE `self.inputBackend.attach(to: self)` — and that client's own `init` calls
        // `canvas.prepareInteractionContainer()` (forcing the `lazy` `selectionChromeContainer`
        // into existence) before `attach(to:)` can run at all. This ordering is backend-agnostic —
        // it happens for EVERY canvas construction, `IDDocumentCanvasView` included (a plain
        // subclass with no `init` override), and the ID backend's `attach(to:)` never even reads
        // `host.presentationClient` — so there is no gap on this side of the seam to close. The
        // FAKE test harness's `FakeInputPresentationClient.interactionContainerView` is a plain,
        // eagerly-constructed (non-`lazy`) stored `UIView`, so it satisfies the identity invariant
        // too, trivially — it does not exercise the real forcing mechanism, which is why this is
        // recorded here rather than left to a test alone.
        self.kernelInteraction = kernel.interaction
        self.report = kernel.report
        self.attachedCanvas = canvas
        // Task R12 (cluster 12) — real tokenizer, mirroring `LegacyRichTextInputBackend
        // +Attachment.swift`'s own construction site exactly, but wrapped in `IDDocumentTokenizer`
        // (`IDTextEditorBackend+Tokenizer.swift`), which adapts `DocumentTokenizer`'s canvas-level
        // (backend-agnostic) boundary logic to mint THIS backend's own `TGRichTextInputDecPosition`/
        // `TGRichTextInputDecRange` identity objects rather than Legacy's — required because the
        // kernel's `selectWord()` hands a tokenizer's own output straight back into this backend's
        // OTHER witnesses (`compare(_:to:)`, `textRange(from:to:)`, …), which reject anything that
        // is not a `TGRichTextInputDecPosition`. `[weak self]` for the live-revision closure avoids
        // a retain cycle (this instance is stored ON `self`) — safe because a detached/deallocating
        // backend has nothing left reading `tokenizer` anyway (this property is cleared in
        // `detach()`, and this whole file's convention is "post-detach fallback answers", not
        // "read whatever the weak capture returns"). Safe to construct here rather than earlier:
        // everything from this line down is plain field assignment, so there is no remaining throw
        // path that would need a matching `tokenizerStorage = nil` cleanup the way Legacy's `catch`
        // block needs one.
        self.tokenizerStorage = IDDocumentTokenizer(
            canvas: canvas, currentRevision: { [weak self] in self?.state.documentRevision ?? 0 })
        self.isAttached = true
        TGRichTextInputDecSetAttachedBridge(canvas, bridge)
        // TASK F4 — the upstream host runs its trait synchronisation at exactly this point in its
        // own construction (`IDBlockTextView.m`'s `[self id_syncTextInputTraits]`, immediately after
        // the kernel is built and before the view is wired up). Without it the private input
        // controller keeps `+[UITextInputTraits defaultTextInputTraits]` forever and the keyboard
        // never learns the host wants autocorrection or spell checking. Placed after `isAttached`
        // so the member's own `guard`-free contract holds, and before `publishState` so a host
        // observing the attach already sees synchronised traits.
        synchronizeTextInputTraits()
        // Task R2 — seed `state.documentRevision`/`.selection` from `host.documentClient`, exactly
        // like `LegacyRichTextInputBackend.installInitialState(from:)`
        // (`documentRevision = client.revision; canonicalSelectionStorage = .caret(at:
        // client.clamp(.downstream(0)))`) does for its own conformer. Without this, `insertText(_:)`'s
        // rebase-or-reject contract (below) would see EVERY first mutation as "stale" against any
        // host whose document client does not already report revision 0 at this exact instant
        // (`FakeInputDocumentClient.revision` defaults to `1`) — not a corner case, but the common
        // case, since this line runs before this task's own `ensureCanonicalSelectionIsCurrent(host:)`
        // has anything else to compare against. `state.markedRange`/`.isComposing` stay at their
        // already-correct construction-time defaults (nil/false) — nothing composes across an attach.
        state = RichTextInputStateSnapshot(
            documentRevision: host.documentClient.revision,
            selection: .caret(at: host.documentClient.clamp(.downstream(0))),
            markedRange: nil, isComposing: false)
        // No `.attachment` case exists on `RichTextInputStateChangeReason` (spec lines 484-491:
        // `.selection/.content/.markedText/.interaction/.externalSynchronization/.policy`) and
        // this task's Files list does not include `RichTextInputTypes.swift` — adding a case
        // there would also break every exhaustive `switch` over the enum elsewhere in the
        // package (e.g. `TelegramLifecycleInputClient.backendDidPublishState`). `.externalSynchronization`
        // is the closest honest fit: the just-attached document/selection state was established
        // from OUTSIDE this publish call, exactly like a real external-synchronization event,
        // and it maps to the same `notifyContentSizeChanged()` handling `.content`/`.markedText`
        // already get from the real lifecycle client.
        publishState(reason: .externalSynchronization)
        host.lifecycleClient.backendDidAttach()
    }

    func detach() {
        guard isAttached, let host else { return }
        // Task R2 — "Detach requested during mutation runs at the transaction boundary" (mirrors
        // `LegacyRichTextInputBackend.detach()`'s own `transactionPhase == .idle` guard, and the
        // spec language its doc comment quotes). A `detach()` fired reentrantly from inside
        // `insertText(_:)`'s own notification/publish callbacks (the realistic case: a lifecycle- or
        // presentation-client callout, exactly like Legacy's) must not tear down mid-transaction —
        // it LATCHES here and `endTransaction()` runs the real teardown (this same method, called
        // again with `isMutating == false`) once the outer bracket returns.
        guard !isMutating else {
            detachRequested = true
            return
        }
        // Every kernel-witness call below is wrapped in `TGRichTextInputDecPerform`, per
        // `IDBackendCallGuardTests`: the brief's own illustrative nine-step snippet writes these
        // as bare `kernelInteraction?.detach()` / `kernelInput?.detach()`, but that is exactly
        // the unguarded-call shape Step 8's boundary test exists to reject — a kernel witness
        // access, not a declaration. Both `-detach` methods are documented idempotent and
        // neither is one of the kernel's seven surviving `@throw` sites, but the guard is a
        // blanket rule ("every reachable entry point"), not a per-call risk judgment, so both
        // are wrapped regardless. The error is intentionally discarded: `detach()` is terminal
        // and must remain best-effort even if a witness call fails.
        // Task C12 (Family 9): cancel gestures FIRST, via the guarded witness `+Interaction.swift`
        // defines — not a raw `kernelInteraction` touch here — so it gets the SAME
        // `TGRichTextInputDecPerform` protection as every other reachable entry point, and so this
        // step is real, reusable code rather than logic duplicated inline. `.detach()` immediately
        // below ALSO tears gestures/loupe/floating-cursor down via its own `-detach:YES` forward,
        // so this is a belt-and-suspenders explicit cancel using the SPECIFIC kernel witness this
        // file's own Consumes-list names — both calls run, in this order, before
        // `host.presentationClient.tearDownPresentation()` seven lines down.
        // `test_detachCancelsGesturesBeforeTearingDownPresentation` (`IDBackendFamily9Tests`) is
        // what this ordering exists to make observable.
        clearGestureRecognizersForced(true)                     // 1 explicit gesture cancel
        var interactionGuardError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.detach()                    // 2 gestures/loupe/floating cursor
        }, &interactionGuardError)
        commitOrDiscardMarkedText()                             // 3
        var inputGuardError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.detach()                          // 4-5 `_detachFromLayoutManager`
        }, &inputGuardError)
        if let canvas = attachedCanvas {
            TGRichTextInputDecSetAttachedBridge(canvas, nil)    // 6 thunks go inert
        }
        host.presentationClient.tearDownPresentation()          // 7
        kernel?.detach()                                        // 8
        // TASK F4 — the native checking driver this backend now installs
        // (`installCheckingIfNeeded()`) must not outlive the attachment. The private checking
        // controller keeps driving its client asynchronously, and every witness it reaches on the
        // canvas answers through THIS backend — so a callback landing after `isAttached = false`
        // reads a detached backend and trips `RichTextInputContractViolation`. Placed before the
        // flag flips so the teardown itself still runs against an attached backend.
        //
        // Scoped to this backend deliberately: Legacy's own teardown stays exactly where D11 put it
        // (the canvas's `deinit` and the `isSpellCheckingEnabled` `didSet`), because Legacy's canvas
        // is never left alive with a detached backend in practice — this backend's harness and
        // `RichTextEditorView`'s backend switch both reach that state.
        (host.hostInputView as? DocumentCanvasView)?.tearDownNativeChecking()
        isAttached = false
        // Task R9 (cluster 6, Step 1) — D18: teardown also drains the coalescing latch and its
        // bookkeeping, mirroring `LegacyRichTextInputBackend.performDetachSteps()`'s own hygiene
        // resets (`+Attachment.swift`) in spirit. `isAttached` is already `false` above, so
        // `suppressesSelectionNotifications`'s own `didSet` guard drops any pending flush silently
        // instead of publishing to a host mid-detach. `deferredExternalChange` is reset for the
        // same reason: nothing reads it again once detached. Pinned (the coalescing half) by
        // `IDBackendPublicationContractTests.test_detachWithAPendingCoalescedLatch_publishesNothing` /
        // `.test_aPendingCoalescedLatchBeforeDetach_doesNotSurviveIntoTheNextAttach`.
        //
        // **`activeTransactionDepth` is deliberately NOT reset here, unlike Legacy's copy.** Legacy
        // needs that reset because its six bracket-entry sites were, historically, HAND-PAIRED
        // (`activeTransactionDepth += 1` written directly before each bracket body, `endTransaction()`
        // written directly after — see `activeTransactionDepth`'s own doc comment, Fix Round 2), so an
        // early `return` inside one of those six bodies could leak a bump past its matching
        // decrement. This backend has no such history: every mutation of `activeTransactionDepth`
        // goes through the `withTransaction(_:)` chokepoint from its very first commit — `insertText(_:)`
        // and `synchronizeAfterExternalChange(_:)` call it around their own bodies (see their own
        // sites), so `body()` always runs and `endTransaction()` always follows in the SAME stack
        // frame, with no bare `activeTransactionDepth` mutation anywhere else to leak. A reset here
        // would be inert defense-in-depth, not a real gap being closed — and adding one would need a
        // THIRD sanctioned mutation site for
        // `InputBackendSourceBoundaryTests.test_activeTransactionDepthMutatedOnlyInSanctionedFunctions_R12`
        // (a Core rule scoped to Legacy's exact three-function list: `withTransaction(`/
        // `endTransaction()`/`performDetachSteps()` — this backend's teardown is one `detach()`
        // method, not a separate `performDetachSteps()`, so a bare mutation here is flagged as
        // unsanctioned regardless of correctness). Left out on both grounds: unnecessary, and it
        // would regress a Core suite outside this task's assigned clusters.
        detachRequested = false
        suppressesSelectionNotifications = false
        deferredExternalChange = nil
        // Task D4d — same hygiene reset, same reason: a `setMarkedText(_:selectedRange:)` whose
        // kernel call never reached the façade would otherwise leave its latched caret behind for
        // the NEXT attach to inherit. (`takePendingMarkedTextSelectedRange()` already consumes it
        // on every transaction that does reach the façade; this covers the one that does not.)
        pendingMarkedTextSelectedRange = nil
        // Task D4f — the composition-start snapshot is a whole-document copy; a detach that leaves
        // one behind both retains it and offers the NEXT attach an undo baseline from a document
        // that no longer exists. `LegacyRichTextInputBackend.finalizeMarkedTextForDetach()` clears
        // the same store for the same reason.
        compositionSnapshotStorage = nil
        kernel = nil; kernelInput = nil; kernelInteraction = nil
        layoutController = nil; bridge = nil; attachedCanvas = nil; tokenizerStorage = nil
        host.lifecycleClient.backendWillDetach()                // 9 — last
        self.host = nil
    }

    /// No composition/marked-text state exists yet in Task C0 — `markedRange` (below) is a stub
    /// that always answers nil, because no real marked-text machinery routes until a later task.
    /// A genuine no-op is therefore the CORRECT behavior today, not a placeholder standing in
    /// for something real: there is nothing to commit or discard.
    private func commitOrDiscardMarkedText() {}

    /// The one publication path (mirrors `LegacyRichTextInputBackend.publishState`'s shape,
    /// which is the package's own precedent for assembling a `RichTextInputPresentationSnapshot`
    /// from `state`). No caret/selection-segment/interaction geometry routes yet in Task C0
    /// (`.inactive`/`nil`/`[]`, same placeholders Task 20 used before geometry witnesses
    /// existed), so this only carries what a fresh attach can honestly report.
    private func publishState(reason: RichTextInputStateChangeReason) {
        guard let host else { return }
        let presentationClient = host.presentationClient
        let snapshot = state
        let presentationSnapshot = RichTextInputPresentationSnapshot(
            state: snapshot,
            caret: nil,
            visibleSelectionSegments: [],
            visibleBounds: presentationClient.visibleBounds,
            isFirstResponder: host.hostInputView.isFirstResponder,
            selectionDisplayVisible: false,
            interaction: .inactive)
        presentationClient.apply(presentationSnapshot)
        host.lifecycleClient.backendDidPublishState(state, reason: reason)
    }

    /// Task C9 (Family 6, marked text and prediction), Step 4. Kept in THIS file, in place — it is
    /// one of the eight members the class's own top doc comment records as "kept exactly as given"
    /// from the brief's illustrative Step-5 snippet (alongside `setSelection(_:reason:)`, which got
    /// its real Family-3 body the same way, in place, at Task C6) — unlike `deleteBackward()`
    /// (Family 5) and this task's own four `RichTextInputTextBackend` witnesses (`+TextBackend.swift`),
    /// which are genuinely NEW surface split into their own files.
    ///
    /// **Hard invariant (this task's brief, verbatim): never synthesize a counterfeit keyboard
    /// mutation for an external change.** This method touches `state` and `publishState` directly
    /// and NEVER calls `documentClient.prepareMutation`/`commitPreparedMutation` or `inputDelegate` —
    /// an external change is host-driven (undo/redo/remote update/a formatting command/…), and
    /// routing it through the two-phase mutation chokepoint (`IDTextEditorBackendClientBridge
    /// .prepareAndCommitReplacement`, Family 4) would fire delegate notifications and a document
    /// client round-trip for something the host already applied — laundering a host-originated
    /// change through the keyboard path, which is the whole reason `RichTextMarkedTextPolicy` exists
    /// as its own enum rather than being folded into `RichTextInputMutationOrigin`.
    ///
    /// **Task R2 gave this method the deferral + continuity halves its own doc comment used to say
    /// this backend altogether lacked.** The REMAINING gap is real and disclosed above the
    /// reentrancy/detach-latch machinery this task added to `insertText(_:)`: no
    /// `transactionPhase` enum, no `withTransaction(_:)` nesting counter — because `setSelection`/
    /// `clearCompositionState` never touch the new `isMutating` flag (Family 3/Task C6 built them as
    /// plain, ungated brackets and this task leaves that alone), there is no NESTED bracket of
    /// this kind for this method to be depth-aware about, unlike
    /// `LegacyRichTextInputBackend.synchronizeAfterExternalChange`'s `withTransaction(_:)`.
    ///
    /// Both new guards below mirror `LegacyRichTextInputBackend.synchronizeAfterExternalChange`'s
    /// own (its FIX ROUND 1/TASK 22g doc comments, `LegacyRichTextInputBackend.swift`) exactly,
    /// because both are genuine, previously-missing production behavior, not test-only scaffolding:
    ///   - **Deferral.** "No callback between preparation and commit may publish an external
    ///     document change. Such a request is deferred until the transaction returns to `.idle`."
    ///     A `synchronizeAfterExternalChange(_:)` fired reentrantly from inside `insertText(_:)`'s
    ///     own notification/publish callbacks (`isMutating == true`) is stashed in
    ///     `deferredExternalChange` and drained by `endTransaction()` — see that method. NOT a
    ///     rejection (no violation reported): a remote update landing mid-keystroke is an expected,
    ///     ordinary occurrence, not caller misuse.
    ///   - **Continuity.** "Validate revision continuity" is a property of the PAIR
    ///     `(oldRevision, newRevision)`, not just the new endpoint — `change.oldRevision` must equal
    ///     what THIS backend has actually adopted, and `change.newRevision` must not regress it.
    ///     Without this, `IDBackendRevisionContractTests.test_stalePosition_isRebasedOnce_…` and
    ///     `IDBackendReentrancyTests.test_deferredExternalChangeThatBecomesStaleByDrainTime_…`
    ///     cannot pass (a change requested against a baseline this backend never held, or one that
    ///     went stale by the time the deferred drain below applies it, would be silently adopted
    ///     instead of rejected) — and, as a byproduct, this same guard is what
    ///     `IDBackendRevisionContractTests.test_decreasingRevisionFromExternalChange_…` (a DIFFERENT
    ///     cluster in R1's triage, not this task's own 29) needed too; it was simply never built.
    ///
    /// `.layoutOnly` is still honored for the revision (mirrors
    /// `RichTextInputExternalChangeReason.preservesTextOffsets`'s own claim that a layout-only change
    /// moves nothing): the document revision does not advance, or a later real content change could
    /// be mistaken for a no-op against a revision that silently moved.
    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {
        guard isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard !isMutating else {
            deferredExternalChange = change
            return
        }
        guard change.oldRevision == state.documentRevision,
              change.newRevision >= state.documentRevision else {
            RichTextInputContractViolation.report(
                "synchronizeAfterExternalChange: revision continuity violated — change describes " +
                "oldRevision \(change.oldRevision) \u{2192} newRevision \(change.newRevision), but " +
                "this backend has adopted \(state.documentRevision) — not adopted")
            return
        }
        // Task R5 (Family 6, cluster 2, `IDBackendReentrancyTests
        // .test_detachFromInsideAPreserveIfRebasableRebaseCallout_stillLatchesToTheBoundary`) — this
        // method previously had NO transaction bracket of its own (unlike `insertText(_:)`'s
        // `isMutating = true … isMutating = false; endTransaction()` around its own body), so a
        // `detach()` fired reentrantly from INSIDE the `rebase` closure two lines down (a realistic
        // case: the document client's own `rebase` callout is exactly where a host could tear the
        // editor down) ran IMMEDIATELY rather than latching to this transaction's boundary — nil'ing
        // `self.host` before `publishState(reason: .externalSynchronization)` below could reach it,
        // silently dropping the publish this method's own contract requires (this method's top-level
        // doc comment: "the REMAINING gap is real and disclosed... no `transactionPhase` enum, no
        // `withTransaction(_:)` nesting"). Bracketing it the SAME way `insertText(_:)` does — verified
        // empirically, not merely by symmetry: removing this bracket reproduces exactly the test's
        // OWN failure message ("an IMMEDIATE (non-latching) detach here drops the publish silently").
        // `detach()`'s own guard (`guard !isMutating else { detachRequested = true; return }`) is what
        // does the actual latching; this method only needs to hold `isMutating` open across the span
        // that can re-enter it, then let `endTransaction()` drain the latch once `publishState` below
        // has run.
        //
        // Task R9 (cluster 6, Step 3) — the whole body below now runs inside `withTransaction(_:)`,
        // which bumps `activeTransactionDepth` around it and calls `endTransaction()` on return
        // (that method's own doc comment has the full depth-gate reasoning: bounding a re-stashed
        // deferred change to "drained at most once per OUTER call", mirroring
        // `LegacyRichTextInputBackend`'s own `activeTransactionDepth`, `+Attachment.swift`).
        // `isMutating = true` stays OUTSIDE the closure and `isMutating = false` is the closure's
        // OWN last statement — preserving the exact pre-R9 order (`isMutating` must read `false`
        // before `endTransaction()`'s drain can re-enter `synchronizeAfterExternalChange`
        // successfully; see `withTransaction(_:)`'s own doc comment).
        isMutating = true
        withTransaction {
            let oldMarkedRange = state.markedRange
            let newMarkedRange = Self.reconciledMarkedRange(
                currentMarkedRange: state.markedRange,
                change: change,
                rebase: { [weak self] position, revision in
                    self?.host?.documentClient.rebase(position, fromRevision: revision)
                })
            let newDocumentRevision = change.reason == .layoutOnly ? state.documentRevision : change.newRevision
            state = RichTextInputStateSnapshot(documentRevision: newDocumentRevision,
                                                selection: change.selection,
                                                markedRange: newMarkedRange,
                                                isComposing: newMarkedRange != nil)
            // Task R5 (Family 6, cluster 2 root cause) — retire the KERNEL's OWN live composing state
            // when `.discard`/`.commitBeforeChange` retire `state.markedRange`. Both cases only ever
            // wrote the LOCAL Swift-side `state` — but the externally-observable `markedTextRange`
            // witness (`+TextBackend.swift`) reads `kernelInput` DIRECTLY, not `state` (deliberately: it
            // "mirrors every other `UITextPosition`/`UITextRange`-returning witness" in this file, all of
            // which must answer for the REAL kernel UIKit itself is driving — diverting `markedTextRange`
            // alone to read `state` would make it lie about the real composing/underline state during
            // ordinary typing). So `state.markedRange` going to nil was a dead write with no observable
            // effect: R1's sub-group (b) `XCTAssertNil failed: "<TGRichTextInputDecRange …>"` failures
            // are exactly this — the kernel's own tracked composition survives untouched.
            // `kernelInput?.unmarkText()` is the one bookkeeping-only kernel primitive that retires a
            // composition WITHOUT inserting or removing a character (see `unmarkText()`'s own witness in
            // `+TextBackend.swift`, which needs this identical explicit retirement for the identical
            // reason: no facade round-trip ever reaches this backend on its own to do it). It therefore
            // does not call `documentClient.prepareMutation`/`commitPreparedMutation` or `inputDelegate`
            // — this method's own hard invariant, stated just above, stays intact.
            //
            // **Scoped to `.discard`/`.commitBeforeChange` ONLY — NOT every nil-resolving outcome —
            // measured, not assumed.** A `.preserveIfRebasable` outcome that resolves to nil (a failed
            // rebase, or a rebased range that collapses to zero-length) ALSO retires `state.markedRange`,
            // but by the time it does, `reconciledMarkedRange` has already made 1-2 real
            // `documentClient.rebase` calls of its own. Calling `kernelInput?.unmarkText()` there measurably
            // triggers `TGRichTextInputDecLayoutController` to react by re-validating the marked range
            // against the current content, itself calling back into `documentClient.rebase` an
            // UNCONTROLLED number of EXTRA times (observed: 13, not 1) — `performWhileSuppressingDelegateNotifications`
            // measurably does NOT gate this reaction (tried, no change). This is the exact reactive-storm
            // shape Task R3 already found and reverted from a different call site (this method's own
            // comment below) — the extra calls corrupt `rebaseCallCount`/`onRebase`-sampled state THIS
            // SAME reconciliation pass's own test cares about
            // (`test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil`,
            // `test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection` — confirmed by disabling
            // this call entirely: both flip from failing-on-the-storm to passing/failing-on-something-else).
            // `.discard`/`.commitBeforeChange` never call `rebase` at all (a bare early return), so they
            // cannot suffer this interference — restricting the call to those two policies gets the fix
            // where it is safe and leaves `.preserveIfRebasable`'s nil-resolving outcomes as a disclosed,
            // remaining gap (see this task's report) rather than trading one regression for another.
            if oldMarkedRange != nil, newMarkedRange == nil,
               change.markedTextPolicy == .discard || change.markedTextPolicy == .commitBeforeChange {
                var error: NSError?
                _ = TGRichTextInputDecPerform({ self.kernelInput?.unmarkText() }, &error)
                if let error { reportKernelFailure(error, witness: #function) }
            }
            // Task R3 — MEASURED AND REVERTED. A proactive `bridge?.storage
            // .synchronizeMirrorWithDocumentIfNeeded()` call used to sit here (mirroring `attach(to:)`'s
            // seed, for exactly the reason its own comment gave: a pure read witness could otherwise see
            // stale content even though nothing it does would ever throw). It caused a measured
            // regression: `IDBackendFamily6Tests.test_preserveIfRebasablePolicy_keepsTheMarkedRangeWhenRebaseSucceeds`
            // went from `rebaseCallCount == 2` (correct — one rebase per marked-range endpoint) to `6`,
            // because a FULL mirror-content replace here (not just a length compare — the fetched text
            // never matched `documentUTF16Length` in that fixture, so the "already in sync" fast path
            // never took) posts `NSTextStorageEditedCharacters` over the whole prior range, and the REAL
            // kernel's `TGRichTextInputDecLayoutController` (attached as this facade's observer, even in
            // the FAKE-CLIENT harness — only the Swift-side clients are fake, the kernel is real) reacts
            // by re-validating the marked range against the new content, itself calling back into
            // `documentClient.rebase` — extra rebases this method's own caller (`reconciledMarkedRange`,
            // immediately above) does not control or expect. `replaceCharactersInRange:withString:`'s own
            // lazy call (the facade header's own doc comment) already keeps `mirror` correct
            // at the one call site every `NSMutableRLEArray … Out of bounds` failure in R1's cluster 5
            // actually threw from — this second push was redundant for THAT goal and cost a real,
            // previously-passing test. Not reinstated.
            publishState(reason: .externalSynchronization)
            isMutating = false
        }
    }

    /// The three `RichTextMarkedTextPolicy` branches, extracted as a `static`, self-contained pure
    /// function — deliberately decoupled from `self`/`host`/`kernelInput`: it takes the CURRENT
    /// marked range and a `rebase` callback as plain values rather than reading `state`/`host`
    /// directly, so it is reachable and testable with NO attached kernel, NO host, and NO canvas at
    /// all (`IDTextEditorBackendMarkedTextPolicyTests`, non-skip-gated — see this task's report for
    /// why this is the strongest non-skip-gated coverage this task can give the most intricate logic
    /// in it, per the task-C9 supplement §3).
    ///
    /// `.discard` and `.commitBeforeChange` are OBSERVABLY IDENTICAL here, for the same reason
    /// `LegacyRichTextInputBackend.reconcileMarkedTextForExternalChange`'s own doc comment discloses
    /// for its two matching branches: there is no separately-tracked provisional-vs-committed delta
    /// at this backend's single-`state` level, and (per that same doc comment) `.commitBeforeChange`
    /// has never had a production call site in this package at all — a genuine "commit the
    /// composition, don't just drop it" forward would need its own storage-façade write, which no
    /// external-change site has ever asked for, here or in Legacy.
    static func reconciledMarkedRange(
        currentMarkedRange: NSRange?,
        change: RichTextInputExternalChange,
        rebase: (RichTextInputPosition, UInt64) -> RichTextInputPosition?
    ) -> NSRange? {
        guard let range = currentMarkedRange else { return nil }
        switch change.markedTextPolicy {
        case .discard, .commitBeforeChange:
            return nil
        case .preserveIfRebasable:
            // Mirrors `LegacyRichTextInputBackend`'s own fast path: nothing moved under the range,
            // so keep it verbatim — no rebase callout, no document-client dependency at all.
            if change.reason.preservesTextOffsets { return range }
            // D32 (the real `TelegramDocumentInputClient`'s documented contract, per
            // `RichTextInputDocumentClient.rebase`'s own doc comment): a stale endpoint is rebased or
            // rejected, never remapped — AT MOST ONE rebase attempt per endpoint, short-circuiting on
            // the FIRST failure rather than trying the second endpoint of a doomed range.
            guard let rebasedStart = rebase(.downstream(range.location), change.oldRevision) else {
                return nil
            }
            guard let rebasedEnd = rebase(.downstream(range.location + range.length), change.oldRevision) else {
                return nil
            }
            let lo = min(rebasedStart.utf16Offset, rebasedEnd.utf16Offset)
            let hi = max(rebasedStart.utf16Offset, rebasedEnd.utf16Offset)
            // A zero-length rebased result collapses to nil, mirroring Legacy's own convention:
            // `isComposing` must never read `true` while composing nothing.
            return hi > lo ? NSRange(location: lo, length: hi - lo) : nil
        }
    }

    /// Clears the marked-text portion of `state` and publishes exactly once, with reason
    /// `.markedText`, but ONLY when a composition was genuinely open. Used by `unmarkText()`
    /// (`+TextBackend.swift`, Family 6, Task C9): unlike `setMarkedText(_:selectedRange:)`, whose
    /// provisional edit already reaches `adoptAndEmitDidChange(_:RichTextInputMutationResult)`
    /// (Family 4, Task C7) — through the storage façade's two-phase transaction — and so gets its
    /// `state` update and publish for free, a COMMIT (`unmarkText`) mutates no character (the
    /// provisional text is already sitting in storage, per `IDUIKitInputControllerCapability
    /// .unmarkText`'s own one-line forward to the real private controller), so no
    /// `prepareAndCommitReplacement` round-trip ever reaches this backend to retire
    /// `state.markedRange` on its own — this method is that retirement, called explicitly.
    ///
    /// ACCESS LEVEL IS LOAD-BEARING for the same file-split reason `kernelInput` above already is:
    /// `state`/`publishState` stay `private` (nothing else outside this file needs raw access to
    /// either), and this is the one narrow, purpose-built crossing point `+TextBackend.swift` uses
    /// instead of a blanket widening of either.
    ///
    /// **Task D4f — this is now the FALLBACK, not the primary path.** `unmarkText()` first drives a
    /// real `.unmarkText` mutation through the document client (see `commitComposedTextInDocument()`
    /// just below), which reaches `DocumentCanvasView.commitMarkedText()` — the ONE place a
    /// composition's undo step is registered — and that body retires `markedRange` itself through
    /// `setCompositionMarkedRange(nil, isPrediction:)`. This method then finds nothing to do. It is
    /// kept, unchanged in behaviour, for every path where the document commit cannot run at all: a
    /// detached backend, a rejected preparation, a composition the canvas never established.
    func commitMarkedTextStateIfComposing() {
        guard state.markedRange != nil else { return }
        state = RichTextInputStateSnapshot(documentRevision: state.documentRevision,
                                            selection: state.selection,
                                            markedRange: nil,
                                            isComposing: false)
        // Task D4f — the snapshot is half of one composition; retiring the range without it would
        // leave a stale whole-document baseline for the NEXT composition's `commitMarkedText()` to
        // register an undo from. `LegacyRichTextInputBackend.clearCompositionStorage()`'s own
        // comment makes the same point ("each used to clear `markedRangeStorage` alone, which ...
        // would leave a prediction flag and a whole-document undo snapshot behind").
        compositionSnapshotStorage = nil
        publishState(reason: .markedText)
    }

    /// Task D4f — **commits an open composition THROUGH the document client**, which is what
    /// registers its single undo step.
    ///
    /// The gap this closes: `unmarkText()` used to call `commitMarkedTextStateIfComposing()` and
    /// nothing else, on the (correct) reasoning that a commit mutates no character and therefore
    /// never reaches the storage façade. But `state` is not the only thing a commit retires.
    /// `DocumentCanvasView.commitMarkedText()` (`+MarkedText.swift`) is where a composition's
    /// `registerUndo(snapshot:anchor:head:)` happens — one undo step for the whole composed word,
    /// from the snapshot taken at composition start — and it is reached ONLY via
    /// `legacyApplyMutation`'s `.unmarkText` case. Skipping it left every composition on this
    /// backend UN-UNDOABLE: the differential corpus's four `*-return-commit-then-undo` scenarios
    /// undid nothing (`blocks` still held the composed text at `terminal`, and `canRedo` read 0
    /// against stock's 1, i.e. the undo had popped an empty group).
    ///
    /// `.unmarkText` is the one mutation case that carries neither a range nor text, so it cannot
    /// ride the façade's `replaceCharactersInRange:withString:` crossing point the way every other
    /// intent does — hence this direct, deliberately narrow prepare/commit pair. It mirrors
    /// `insertText(_:)`'s own preflight (attachment, edit policy, `ensureCanonicalSelectionIsCurrent`)
    /// and its own rejection reporting, minus the façade hop and minus `isMutating`/`withTransaction`
    /// (this changes no character, so there is no re-entrancy window to guard and no transaction
    /// boundary to open — `commitPreparedMutation` brackets its own undo group).
    ///
    /// The `state.markedRange != nil` guard keeps a bare `unmarkText()` on a non-composing backend
    /// exactly as silent as it was before this task.
    func commitComposedTextInDocument() {
        guard state.markedRange != nil else { return }
        guard isAttached, let host else { return }
        guard host.lifecycleClient.editPolicy.isEditable else {
            host.lifecycleClient.backendDidRejectMutation(.unmarkText, reason: .notEditable)
            return
        }
        guard ensureCanonicalSelectionIsCurrent(host: host) else {
            host.lifecycleClient.backendDidRejectMutation(.unmarkText, reason: .revisionMismatch)
            return
        }
        switch host.documentClient.prepareMutation(.unmarkText,
                                                   expectedRevision: state.documentRevision) {
        case .terminal(let result):
            if case .rejected(let reason) = result.disposition {
                host.lifecycleClient.backendDidRejectMutation(.unmarkText, reason: reason)
            }
        case .ready(let prepared):
            emitWillChange(prepared)
            let result = host.documentClient.commitPreparedMutation(prepared)
            adoptAndEmitDidChange(result, intent: .markedText)
        }
    }

    /// Task C6 (Family 3) — the spec's ONE whole-selection write. Mirrors
    /// `LegacyRichTextInputBackend.setSelection`'s shape at the granularity this backend has
    /// reached: `state` is the single canonical store (there is no second, canvas-side copy to
    /// keep in step — unlike Legacy, which only converged onto one authority at Phase 5).
    ///
    /// **Task R9 (cluster 6) built the reentrancy/suppression/edit-policy machinery this doc
    /// comment used to say did not exist ("none of that exists on this backend yet ... and
    /// inventing it unasked would be the same 'plausible fake' this file's own header warns
    /// against").** That was the right call THEN; the three gaps are now real, each mirroring
    /// Legacy's own implementation of the same member (`LegacyRichTextInputBackend.swift`):
    ///   1. **Edit-policy gate** — `guard host?.lifecycleClient.editPolicy.isSelectable ?? true`,
    ///      placed BEFORE any write or notification, matching Legacy's placement and its `?? true`
    ///      fail-open default (a nil `host` while `isAttached` is a state this class treats as
    ///      impossible, not as "policy forbids" — same reasoning Legacy's own comment gives).
    ///      Pinned by `IDBackendEditPolicyTests.test_notSelectable_rejectsSetSelection_andPublishesNothing`.
    ///   2. **Coalescing** — `suppressesSelectionNotifications`'s `didSet` (declared below) now
    ///      flushes a deferred publish when the flag clears; this method defers its OWN publish
    ///      the same way Legacy's does, storing the write but skipping `withTransaction` while the
    ///      flag is set. Pinned by three `IDBackendPublicationContractTests` cases.
    ///   3. **Depth-gate participation** — the final publish now runs through `withTransaction(_:)`
    ///      (declared alongside `endTransaction()`), so a `deferredExternalChange` left pending by
    ///      an earlier `synchronizeAfterExternalChange(_:)` chain is drained here too, exactly like
    ///      Legacy's shared `withTransaction` funnels EVERY top-level bracket (including its own
    ///      `setSelection`) through the same `activeTransactionDepth` counter. See
    ///      `endTransaction()`'s own doc comment for the depth-gate mechanics.
    ///
    /// **Task R11 (cluster 10) FIX: this method is now delegate-SILENT, matching Legacy exactly —
    /// it used to call `emitWillChange(.selection)`/`adoptAndEmitDidChange(.selection)`
    /// unconditionally for every `reason`, which was never a Legacy behavior to begin with.**
    /// `LegacyRichTextInputBackend.setSelection` (`LegacyRichTextInputBackend.swift`) sends ZERO
    /// `UITextInputDelegate` notifications from its own body — verified directly from its source: the
    /// method writes `canonicalSelectionStorage`, checks `suppressesSelectionNotifications`, checks
    /// `transactionPhase == .idle`, then opens `withTransaction { publishState(reason: .selection) }`
    /// with no `notify*` call anywhere in between. Real, user-visible selection notifications for
    /// canvas-originated changes route through OTHER call sites (`notifyingSelectionChange`, used by
    /// the canvas's own `setCaret`/`setSelectionHead`/`setSelectionAnchor` funnels) or, for this
    /// backend specifically, through `relaySelectionDidChangeFromKernel()` when the REAL kernel
    /// reports a change it made on its own — `setSelection` itself is the raw, policy-gated,
    /// possibly-coalesced whole-selection WRITE, not a notification source.
    /// `IDBackendSelectionContractTests.test_programmaticSelection_producesTheSameDelegateOrderAsAKeyboardSelection`/
    /// `.test_selectionChangeReason_reachesPublicationUnchanged` (both inherited, unmodified, from the
    /// SHARED `BackendSelectionContractTests` — confirmed green against `ReferenceMutationBackend`,
    /// i.e. real Legacy code, both before and after this fix) pin exactly this: `log.kinds ==
    /// ["presentationApply", "lifecyclePublish"]` for EVERY `RichTextSelectionChangeReason`, no
    /// `delegateSelectionWillChange`/`delegateSelectionDidChange` entries. One ID-specific test,
    /// `IDBackendFamily3Tests.test_publicationFollowsDidChangeNotifications`, had pinned the OLD
    /// (buggy) unconditional-emission behavior instead — corrected in the same commit as this fix
    /// (see task-R11-report.md for the full before/after).
    ///
    /// **DECISION, recorded here because it diverges from a straight Legacy mirror.** Task R7
    /// (cluster 4) made this method unconditionally OVERWRITE `state.documentRevision` from
    /// `host?.documentClient.revision` on every call — necessary there (a cached revision that never
    /// moved after `setBlocks`/`setParagraphs` seeded fresh content post-attach wrongly rejected
    /// every subsequent insert as `.revisionMismatch`), but it directly conflicts with gap 3 above:
    /// a `setSelection` racing a JUST-DRAINED external change would stomp the freshly-advanced
    /// `state.documentRevision` back down to the host's (in the fake-client harness, static)
    /// `documentClient.revision`, discarding the drain's own result before `IDBackendReentrancyTests
    /// .test_aChangeReStashedDuringTheOneDrainThisTransactionPerforms_isLeftPendingNotChainedHere`'s
    /// final assertion ever reads it — measured directly: with the drain fixed but this read left as
    /// a blind overwrite, `documentRevision` reads back as the host's stale value instead of
    /// `old + 206`. Legacy has no equivalent tension because Legacy's `setSelection` never touches
    /// `documentRevision` at all — there is no Legacy behavior to mirror here. The fix takes the
    /// MORE ADVANCED of the two readings (`max`) rather than reverting R7 or inventing a new
    /// mechanism: a document revision counter is monotonic by construction (a real
    /// `TelegramDocumentInputClient` only advances it), so `max` preserves R7's intent exactly (a
    /// stale cached revision still adopts the host's fresher one) while no longer regressing a
    /// revision this backend has already advanced past the host's own (static, in the fake harness)
    /// reading — e.g. via the very drain gap 3 introduces.
    func setSelection(_ selection: RichTextCanonicalSelection,
                      reason: RichTextSelectionChangeReason) {
        guard isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard host?.lifecycleClient.editPolicy.isSelectable ?? true else { return }
        let hostRevision = host?.documentClient.revision ?? state.documentRevision
        state = RichTextInputStateSnapshot(documentRevision: max(hostRevision, state.documentRevision),
                                            selection: selection,
                                            markedRange: state.markedRange,
                                            isComposing: state.isComposing)
        guard !suppressesSelectionNotifications else {
            pendingCoalescedSelectionPublish = true
            return
        }
        // Task R11 (cluster 17) — member-level reentrancy for THIS method, mirroring Legacy's own
        // `guard transactionPhase == .idle else { return }`. Reads `isInsideAnyTransaction`, a
        // dedicated flag kept in lockstep with `activeTransactionDepth` at its own two sanctioned
        // mutation sites (`withTransaction(_:)`/`endTransaction()`) — not a direct read of
        // `activeTransactionDepth` itself: Core rule R12
        // (`InputBackendSourceBoundaryTests.test_activeTransactionDepthMutatedOnlyInSanctionedFunctions_R12`)
        // forbids mentioning that identifier anywhere outside those two bodies, so a bare
        // `guard activeTransactionDepth == 0` here — the literal Legacy mirror — is off the table
        // (confirmed: R9's own report records exactly this trap for a bare `+= 1`).
        //
        // **FIRST DRAFT WAS WRONG, measured wrong, and corrected in this same task.** A first attempt
        // used a flag scoped to setSelection's OWN bracket alone (set true only around this method's
        // own `withTransaction` call) — it fixed
        // `test_nestedSetSelection_writesItsStorageButOpensNoBracketOfItsOwn` (a setSelection nested
        // inside ANOTHER setSelection's bracket) but left
        // `test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot` red ("2" is not equal to
        // "1"): that test nests a setSelection call inside `insertText(_:)`'s OWN bracket (from
        // `presentationClient.apply`'s callback), which a setSelection-scoped flag cannot see at all —
        // `insertText` never touches it. Legacy's real mechanism is NOT setSelection-specific either:
        // `transactionPhase` is shared by every bracket-opening member (`insertText`,
        // `synchronizeAfterExternalChange`/`clearCompositionState`/`setMarkedText`, and `setSelection`
        // itself), so ANY of them being mid-bracket must suppress a nested `setSelection`'s own
        // publish. `isInsideAnyTransaction` fixes this the same way: it is `true` for the full
        // lifetime of the OUTERMOST `withTransaction(_:)` call, whichever member opened it, and a
        // nested `setSelection` reached while it is `true` still performs its STORAGE WRITE (above)
        // but skips opening its OWN bracket — the OUTER transaction's own `publishState` re-reads
        // `state` fresh immediately before the lifecycle-client delivery (that method's own `state`,
        // not a captured snapshot), so the outer publish picks up the nested write for free. Pinned by
        // both `IDBackendReentrancyTests.test_nestedSetSelection_writesItsStorageButOpensNoBracketOfItsOwn`
        // (setSelection nested in setSelection) and
        // `.test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot` (setSelection nested in
        // insertText) — re-measured GREEN together only after this correction, not before.
        guard !isInsideAnyTransaction else { return }
        withTransaction {
            publishState(reason: .selection)
        }
    }

    /// Task C6 Step 4 — **hard invariant 10: only the backend sends `UITextInputDelegate`
    /// notifications.** `emitWillChange`/`adoptAndEmitDidChange` are the ONE pair of sites in this
    /// file (and, per `InputBackendSourceBoundaryTests`' R16 rule, one of exactly TWO files in the
    /// whole package — the other being `LegacyRichTextInputBackend+Notifications.swift`) that may
    /// call `inputDelegate?.textWillChange`/`selectionWillChange`/`selectionDidChange`/
    /// `textDidChange`. The layout controller and the client bridge must never touch `inputDelegate`
    /// directly. **Task H1 narrowed what is relayed at all**: `relayTextDidChangeFromKernel()` is
    /// gone and its sibling now serves only `keyboardInputChangedSelection:` — the two
    /// `UITextInputControllerDelegate` notifications route to `reconcileAfterControllerTextChange()`/
    /// `reconcileAfterControllerSelectionChange()` below, which send NOTHING to `inputDelegate`
    /// because they are incoming reports, not outgoing ones. See those two members for the
    /// measurement.
    private enum NotificationKind { case selection, content, contentAndSelection }

    private func emitWillChange(_ kind: NotificationKind) {
        let receiver = host?.hostInputView as? UITextInput
        if kind == .content || kind == .contentAndSelection {
            inputDelegate?.textWillChange(receiver)
        }
        if kind == .selection || kind == .contentAndSelection {
            inputDelegate?.selectionWillChange(receiver)
        }
    }

    private func adoptAndEmitDidChange(_ kind: NotificationKind) {
        let receiver = host?.hostInputView as? UITextInput
        if kind == .selection || kind == .contentAndSelection {
            inputDelegate?.selectionDidChange(receiver)
        }
        if kind == .content || kind == .contentAndSelection {
            inputDelegate?.textDidChange(receiver)
        }
    }

    /// `keyboardInputChangedSelection:` — a **`UIKeyboardInput`** member, which UIKit sends to the
    /// VIEW rather than to the controller's delegate.
    ///
    /// **H1 planned to leave this row alone and could not.** It was the one of the four that F4 had
    /// recorded as a direction error without H1's finding applying to it, so the intent was to split
    /// it off the shared relay and correct it in its own task. Then a receipt showed it firing once
    /// per kernel-driven selection change *as a consequence of the delegate re-point* — before it,
    /// nothing delivered it either (measured: an observing delegate installed on the pre-fix wiring
    /// recorded exactly one question, `_textSelectingContainer`, which the bridge answers nil to and
    /// a `UIView` answers for real; with the canvas in the delegate slot that question is answered
    /// and this callback follows). So shipping the wiring fix while leaving the old body would have
    /// activated a second wrong-direction relay in the same change, which is the precise shape of
    /// defect this whole redo exists to stop.
    ///
    /// Upstream's body forwards the same private selector to the host's **app-level** delegate and
    /// only when that delegate is not the host itself (`IDBlockTextView+PrivateInputDelegate.m`); it
    /// touches `inputDelegate` nowhere. This port has no app-level delegate object at this seam — the
    /// canvas reports selection to its host through its own `onSelectionChange` path — so the honest
    /// correspondence is "notify UIKit of nothing", which is also what removes the regression.
    /// Whether the canvas should additionally report an externally-driven selection move onward to
    /// its host stays open (`task-G2-report.md` C29): it needs the app-side call, not this one.
    func reconcileAfterKeyboardSelectionChange() {
        guard isAttached else { return }
        controllerNotificationReceipts.keyboardInputChangedSelection += 1
    }

    // MARK: - Task H1 — the private controller's own delegate notifications

    /// Receipts for the two `UITextInputControllerDelegate` notifications the private controller
    /// sends the host view. A diagnostic seam in the same spirit as `witnessFailures`, and it exists
    /// for a specific reason: these two callbacks were installed on the canvas but delivered
    /// nowhere for the whole of Stage C (the delegate was the bridge, which answers none of the
    /// selectors), and **nothing in the tree could tell**. A counter makes "did this mechanism run"
    /// a measurable question rather than an argument from source reading.
    struct ControllerNotificationReceipts: Equatable {
        /// `textInputDidChange:` deliveries.
        var textDidChange = 0
        /// `textInputDidChangeSelection:` deliveries.
        var selectionDidChange = 0
        /// Deliveries that reached `notifySelectionChangedToKernel()` — i.e. that were forwarded on
        /// to the kernel's interaction assistant rather than dropped by the `isAttached` guard.
        var forwardedSelectionChangedToKernel = 0
        /// `keyboardInputChangedSelection:` deliveries. NOT a `UITextInputControllerDelegate` member
        /// — it is `UIKeyboardInput`, sent to the VIEW — and it is counted separately precisely so
        /// the two can never again be confused for one mechanism (they shared a relay until H1).
        var keyboardInputChangedSelection = 0
    }
    private(set) var controllerNotificationReceipts = ControllerNotificationReceipts()

    /// `textInputDidChange:` — the private controller telling the host "I changed the document."
    ///
    /// **THIS MUST NOT NOTIFY `inputDelegate`, and it used to.** It is an INCOMING report, not an
    /// outgoing one: `inputDelegate?.textDidChange(_:)` is UIKit's "an external agent changed the
    /// document behind your back" signal, whose documented effect is to make the keyboard discard
    /// its in-flight typing and autocorrection session — so relaying it from inside the controller's
    /// own change notification tells the keyboard to tear down the very edit it just made. Task F4
    /// read that direction error off the upstream source and left it unfixed because it could not
    /// measure whether the callback ever ran; task H1 measured that it never did, and fixing the
    /// wiring is what makes the direction error live. Both halves therefore land together.
    ///
    /// Upstream's body is `id_reconcileDerivedState` + `id_scrollCaretToVisibleIfNeeded`
    /// (`IDBlockTextView+PrivateInputDelegate.m`). Neither half maps onto work this host still owes:
    /// upstream reconciles because ITS document engine is the private storage and its block stack
    /// must be re-laid-out from it, whereas here the mutation that produced this notification has
    /// already run through the storage façade's two-phase transaction into Telegram's own document
    /// client, which re-lays-out and re-scrolls the canvas on its own (`task-G2-report.md` E11/E12,
    /// N/A-by-design). Measured 1:1 in the fake-client harness: one `deleteBackward()` produces one
    /// façade transaction and one `textInputDidChange:`.
    ///
    /// What upstream does here that this port genuinely does NOT is size its interaction text
    /// container to the document (`id_updateInteractionContainerGeometry`); our `syntheticContainer`
    /// is never resized. That is a real open row, recorded in `task-G1-report.md`'s own honourable
    /// mentions and left to the geometry theme rather than guessed at here.
    func reconcileAfterControllerTextChange() {
        guard isAttached else { return }
        controllerNotificationReceipts.textDidChange += 1
    }

    /// `textInputDidChangeSelection:` — the private controller telling the host "my selection moved."
    ///
    /// Same direction correction as `reconcileAfterControllerTextChange()` above: this must not send
    /// `inputDelegate?.selectionDidChange(_:)`, which it used to.
    ///
    /// Upstream's body is `id_selectionStateDidChange`, and the one step of it that is the KERNEL's
    /// business rather than the host's own chrome is `[self.id_interactionCapability selectionChanged]`
    /// — so that is what this forwards. That call had no caller anywhere in this port
    /// (`task-G2-report.md` E3, MISSING: "`+Interaction.swift:90-98` exists, no caller"), and this is
    /// the caller upstream has for it. Everything else `id_selectionStateDidChange` does — autoscroll
    /// bookkeeping, inline-formatting state, layout, caret scrolling, selection presentation — is
    /// owned by `DocumentCanvasView` here, not by the backend.
    func reconcileAfterControllerSelectionChange() {
        guard isAttached else { return }
        controllerNotificationReceipts.selectionDidChange += 1
        controllerNotificationReceipts.forwardedSelectionChangedToKernel += 1
        notifySelectionChangedToKernel()
    }

    /// Task C7 (Family 4) — the two-phase mutation transaction's WILL/DID brackets, overloading
    /// `emitWillChange`/`adoptAndEmitDidChange` above by parameter TYPE rather than reusing their
    /// `NotificationKind` signature. This is a deliberate resolution of a brief-vs-reality gap: the
    /// task brief's illustrative snippet calls `backend.emitWillChange(prepared)` /
    /// `backend.adoptAndEmitDidChange(result)` POSITIONALLY, as if those names already took a
    /// `RichTextInputPreparedMutation`/`RichTextInputMutationResult` — they do not (Task C6 built
    /// them to take the `NotificationKind` enum above, and both are `private`, unreachable from
    /// `IDTextEditorBackendClientBridge.swift` in a different file regardless). Overloading makes
    /// the brief's call syntax literally correct rather than inventing differently-named methods,
    /// while keeping hard invariant 10 intact: `internal` (not `private`) so the bridge — the ONE
    /// crossing point UIKit's raw `replaceCharactersInRange:` reaches — can call it without ITSELF
    /// touching `inputDelegate`, and both overloads still route through the private,
    /// `NotificationKind`-taking originals above, the sole `inputDelegate` senders in this file.
    ///
    /// **Task R2 CORRECTION: UNCONDITIONAL, not gated on `prepared`'s flags.** This doc comment
    /// used to argue the opposite ("driven by the PREPARATION's own flags... only the document
    /// client that prepared the mutation knows what it is about to touch") — that was never
    /// exercised until this task wired `insertText(_:)` to actually call it, and it directly
    /// contradicts deviation D10 (the plan's own deviations table):
    /// `LegacyRichTextInputBackend+Mutation.swift`'s `runMutation` calls
    /// `notifyTextWillChange()`/`notifySelectionWillChange()` with NO conditional at all — "the four
    /// notifications below are UNCONDITIONAL — they do not consult
    /// `RichTextInputPreparedMutation.contentWillChange`/`.selectionWillChange`... to decide whether
    /// to fire," mirroring `editing(coalescing:_:)`'s real shape (both will-notifications
    /// unconditionally before the body). `IDBackendMutationContractTests
    /// .test_preparationFlags_gateTheWillNotificationsIndependently` pins this directly — driving
    /// EACH flag `false` independently and asserting BOTH notifications still fire either way.
    func emitWillChange(_ prepared: RichTextInputPreparedMutation) {
        guard isAttached else { return }
        emitWillChange(.contentAndSelection)
    }

    /// The DID half. Adopts the committed result into `state` FIRST — so a re-entrant read from
    /// inside `textDidChange`/`selectionDidChange` (UIKit sometimes re-queries `selectedTextRange`
    /// synchronously from its own delegate callback) sees the NEW selection, not the stale
    /// pre-commit one — then relays did-notifications gated on what the RESULT reports actually
    /// changed (`contentChanged`/`selectionChanged`, deliberately NOT the preparation's flags again:
    /// see `RichTextInputMutationResult.legacyConservativePreparation`'s own doc comment on why the
    /// two can disagree), then publishes.
    /// Task R5 (Family 6, cluster 2) `intent` ADDITION — its sole caller,
    /// `IDTextEditorBackendClientBridge.prepareAndCommitReplacement`, already has the
    /// `TGRichTextInputDecIntent` this mutation was built from; threading it through fixes a real,
    /// disclosed-but-unimplemented contract: `RichTextInputTextBackend.setMarkedText(_:selectedRange:)`'s
    /// own doc comment (`RichTextInputBackend.swift`) says a conformer "MUST publish... exactly once,
    /// with reason `.markedText`" for the state this call mutates — this backend's composing edit
    /// reaches this method (per `+TextBackend.swift`'s own header, "adopts `result.markedRange` into
    /// `state` and publishes — for free") but always published `.content` regardless of intent, never
    /// `.markedText`. Defaults to `.programmatic` (a value never checked below except by exclusion) so
    /// nothing about any OTHER intent's publish reason changes.
    ///
    /// **The reason gate is `intent == .markedText || result.markedRange != nil`, not `intent` alone
    /// — measured, not assumed.** `intent` is latched by `TGThunk_keyboardInputShouldInsertTextIsMarkedText`
    /// (`TGRichTextInputDecCanvasCallbacks.m`), itself a DOCUMENTED "best-effort reconstruction" of an
    /// uncertified private ABI callback (that file's own header) that this backend's own comments
    /// elsewhere note fires from a REAL keyboard-input session — a fake-client test driving
    /// `kernelInput.setMarkedText(...)` directly (no live keyboard session) never triggers it, so
    /// `intent` reads whatever the latch last held (`.programmatic` here), even though the mutation IS
    /// genuinely a composing edit. `result.markedRange` has no such dependency: it is the exact same
    /// field this method already uses to compute `isComposing` two lines above, so gating the REASON on
    /// it too is not a new signal, just reusing the one this method already trusts — "the state this
    /// call mutates," per the protocol's own wording. Kept `intent` as well (not replaced) so real,
    /// keyboard-driven production usage is doubly covered if the reconstructed thunk IS correct there.
    func adoptAndEmitDidChange(_ result: RichTextInputMutationResult,
                               intent: TGRichTextInputDecIntent = .programmatic) {
        guard isAttached else { return }
        state = RichTextInputStateSnapshot(documentRevision: result.revision,
                                            selection: result.selection,
                                            markedRange: result.markedRange,
                                            isComposing: result.markedRange != nil)
        if let kind = notificationKind(content: result.contentChanged, selection: result.selectionChanged) {
            adoptAndEmitDidChange(kind)
        }
        let isMarkedTextEdit = intent == .markedText || result.markedRange != nil
        publishState(reason: isMarkedTextEdit ? .markedText : .content)
    }

    /// `nil` means "neither the preparation nor the result claims a change" — the WILL/DID call is
    /// skipped entirely rather than sending an empty-but-truthy notification kind.
    private func notificationKind(content: Bool, selection: Bool) -> NotificationKind? {
        switch (content, selection) {
        case (true, true): return .contentAndSelection
        case (true, false): return .content
        case (false, true): return .selection
        case (false, false): return nil
        }
    }

    // MARK: - `RichTextInputTextBackend` (`UITextInput` routing)

    var inputDelegate: UITextInputDelegate?

    /// R1: was `fatalError("IDTextEditorBackend has no UITextInput witness implementation yet …")` —
    /// reached for the first time now that `attach(to:)` genuinely succeeds (Task C14 opened the
    /// capability gate). R1 converted the crash to the package's documented "absent witness" shape
    /// (a recorded contract violation plus a safe no-op fallback) and left the real routing for
    /// Family 1/Task C4, per that task's "convert, do not implement" mandate.
    ///
    /// **Task R12 (cluster 12) implements it for real, by REUSING `DocumentTokenizer`'s own
    /// boundary logic (`LegacyDocumentTokenizer.swift`) through the `IDDocumentTokenizer` adapter
    /// (`IDTextEditorBackend+Tokenizer.swift`), rather than inventing a parallel implementation.**
    /// `DocumentTokenizer` is canvas-level, not Legacy-backend-specific, but mints Legacy's OWN
    /// `LegacyTextPosition`/`LegacyTextRange` identity objects, which this backend's other witnesses
    /// cannot consume — see the adapter's own header for exactly why a bare `DocumentTokenizer`
    /// cannot be vended here directly. `IDBackendFamily9Tests
    /// .test_selectWordRoutesThroughTheInteractionCapability` is what surfaced the gap: the kernel's
    /// own `IDUIKitInteractionCapability.selectWord()` calls back through this exact witness (five
    /// times, observed) to resolve word boundaries — it is not merely UIKit's OWN word-select
    /// gesture that needs a working tokenizer, the vendored kernel's interaction assistant does too.
    ///
    /// The fallback below now covers only the genuinely narrow "no canvas attached" window (never
    /// reached in production — `tokenizerStorage` is built the moment `attach(to:)` is guaranteed to
    /// succeed and cleared in `detach()`), mirroring `LegacyRichTextInputBackend.tokenizer`'s own
    /// split (`+TextReads.swift`) exactly: report via `RichTextInputContractViolation`, no
    /// `witnessFailures` entry (that log is reserved for a genuine KERNEL-call failure caught by
    /// `reportKernelFailure(_:witness:)`; a detached read here is a member-not-attached case, the
    /// same shape every other detached fallback on this backend already takes).
    var tokenizer: UITextInputTokenizer {
        guard let existing = tokenizerStorage else {
            // TASK F4 — this fallback used `RichTextInputContractViolation.report`, whose
            // no-reporter DEBUG branch is an `assertionFailure`, i.e. a HARD TRAP. It is reachable,
            // it is not a programmer violation, and it kills a debug build.
            //
            // **Measured, on the tree as it stood BEFORE this task's changes** (a `git stash`
            // control run, so this is not something F4 introduced): `IDBackendFamily8Tests` reports
            // `Executed 5 tests, 0 failures` and THEN kills the xctest process. A
            // `Thread.callStackSymbols` probe named the caller —
            // `-[TIDocumentState(UITextInputAdditions) initWithDocument:contextBoundary:]`
            // → `_contextBeforePosition:inDocument:toBoundary:` → `DocumentCanvasView.tokenizer`.
            // That is UIKit's own KEYBOARD document-state snapshot: it is scheduled asynchronously
            // and lands whenever it lands, including after the backend has detached but while the
            // canvas is still alive (`RichTextEditorView`'s backend switch, `deinit`'s
            // `detach()`-then-teardown window, and every ID harness `tearDown()`).
            //
            // So it is degraded the way task F1 degraded `reportKernelFailure` for exactly the same
            // reason, and the way that task's own ruling already treats the eight per-frame geometry
            // witnesses: an OS-driven read arriving after detach is a normal race, and the member's
            // documented fallback IS its answer. Still observable — through an installed reporter
            // when there is one, and through `NSLog` otherwise, which is precisely what
            // `RichTextInputContractViolation.report` itself does in a RELEASE build. `report(_:)`
            // is deliberately not called: its no-reporter DEBUG branch is the trap being removed.
            if let reporter = RichTextInputContractViolation.reporter {
                reporter("tokenizer read while no canvas is attached — returning a no-op fallback: \(#function)")
            } else {
                NSLog("RichTextInput contract violation (recorded, not trapped): %@",
                      "tokenizer read while no canvas is attached — returning a no-op fallback")
            }
            return IDTextEditorBackend.detachedFallbackTokenizer
        }
        return existing
    }

    /// The stateless fallback `tokenizer` vends for the "not attached" window only. A `static let`
    /// is legal in a class body (only instance stored properties are forbidden); one shared instance
    /// is enough since the type carries no state — mirrors
    /// `LegacyRichTextInputBackend+TextReads.swift`'s own `detachedFallbackTokenizer`, including the
    /// name.
    private static let detachedFallbackTokenizer: UITextInputTokenizer = IDNoOpTextInputTokenizer()

    /// Task R10 (cluster 8) EXTRACTION. Mints the SAME revision-stamped `TGRichTextInputDecRange`
    /// identity the `selectedTextRange` getter below vends to UIKit, from this backend's own
    /// canonical `state.selection` — factored out so `+KeyInput.swift`'s `deleteBackward()` can
    /// build the identical object to PRE-WARM the kernel's own cached selection with (see that
    /// method's doc comment for why this is necessary: `setSelection(_:reason:)` only ever writes
    /// `state`, never `kernelInput`, so a selection set any way other than a live keyboard session
    /// is invisible to a kernel witness that reads its OWN cached copy). `RichTextInputAffinity`
    /// (`.upstream`/`.downstream`) → `UITextStorageDirection` (`.backward`/`.forward`) is written
    /// out explicitly, matching this package's own established convention for the two
    /// independently-declared enums (e.g. `IDTextEditorBackendClientBridge.caretGeometry`'s
    /// identical mapping in the other direction) — nothing pins their case order to agree forever.
    func mintKernelSelectedTextRange() -> TGRichTextInputDecRange {
        let revision = state.documentRevision
        let anchor = TGRichTextInputDecPosition(
            offset: canonicalSelectionAnchorOffset,
            affinity: state.selection.anchor.affinity == .upstream ? .backward : .forward,
            revision: revision)
        let head = TGRichTextInputDecPosition(
            offset: canonicalSelectionHeadOffset,
            affinity: state.selection.head.affinity == .upstream ? .backward : .forward,
            revision: revision)
        return TGRichTextInputDecRange(from: anchor, to: head)
    }

    /// Task C6 (Family 3). Mirrors `LegacyRichTextInputBackend.selectedTextRange`'s own contract —
    /// see that member's doc comment, and `DocumentCanvasView+UITextInput.swift`'s matching note —
    /// verbatim: **UNORDERED by construction.** `.start`/`.end` report `state.selection`'s
    /// anchor/head exactly as stored, never `min`/`max`; `RichTextCanonicalSelection.normalizedRange`'s
    /// own doc comment: "the canvas hands UIKit an unordered range for a reversed drag and that is
    /// load-bearing." Built directly from `state` (never through `kernelInput`/the exception guard):
    /// unlike the Family 1/2 UIKit witnesses, which have no honest answer without a live kernel, this
    /// backend's OWN canonical selection is always available in `state`, attached or not.
    ///
    /// Task R8 (cluster 3) FIX: the getter previously stamped BOTH endpoints `.forward`
    /// unconditionally, and the setter previously discarded `newValue`'s affinity entirely
    /// (`.downstream(_:)`, deviation D6's OWN default) — a genuine data-loss bug, not an
    /// application of D6. D6 says the seam must carry a position's affinity "through unchanged";
    /// it does NOT say this witness may fabricate a constant one. `RichTextInputPosition.affinity`
    /// already round-trips through `state.selection` (`setSelection(_:reason:)` stores whatever
    /// `RichTextCanonicalSelection` it is given verbatim) — only this getter/setter pair was
    /// throwing the field away. Confirmed the true root cause via instrumentation, not the R1
    /// axis-mismatch hypothesis: `closestPosition(to:)` resolves through the REAL private kernel
    /// (bypassing this file's own Family 2 bridge for point hit-testing entirely — traced live,
    /// zero `id_cursorPositionAtPoint:`/`id_nearestPositionAtPoint:` calls), which legitimately
    /// stamps `.backward` for a mid-document offset; a FRESH `textRange(from:to:)` call over that
    /// SAME position echoes it faithfully (`id_textRangeFromPosition:toPosition:`'s
    /// `TGResolvePosition` preserves affinity when the revision already matches), so the two sides
    /// of the assertion diverged only because this witness clobbered what it was handed.
    var selectedTextRange: UITextRange? {
        get {
            return mintKernelSelectedTextRange()
        }
        set {
            // The load-bearing floating-cursor invariant (mirrors Legacy's own setter, and
            // `FloatingCursorTests`'s pinned reasoning there): a hold-spacebar gesture owns the
            // caret while it is active, and iOS ALSO pushes selection RANGES (anchored at the
            // gesture-start position) through this very setter during that gesture — applying them
            // would turn a cursor MOVE into a text SELECTION. Sits FIRST, exactly like Legacy's.
            guard !floatingCursorActive else { return }
            // A `nil` or foreign (non-`TGRichTextInputDecPosition`) endpoint collapses to offset 0
            // at `.downstream` — the same nil-collapse Legacy's own setter documents for a
            // non-`LegacyTextRange` write; a foreign position carries no affinity of its own to
            // preserve, so the seam's own default is the honest fallback.
            let anchorPosition = newValue?.start as? TGRichTextInputDecPosition
            let headPosition = newValue?.end as? TGRichTextInputDecPosition
            let anchorOffset = anchorPosition?.utf16Offset ?? 0
            let headOffset = headPosition?.utf16Offset ?? 0
            let anchorAffinity: RichTextInputAffinity = anchorPosition?.affinity == .backward ? .upstream : .downstream
            let headAffinity: RichTextInputAffinity = headPosition?.affinity == .backward ? .upstream : .downstream
            // A `UITextRange`-shaped write reaching this witness is UIKit driving the selection
            // (keyboard cursor-drag / autocorrect) — the same `.keyboard` reason Legacy's own
            // setter uses for the identical origin, routed through the ONE whole-selection write.
            setSelection(RichTextCanonicalSelection(
                            anchor: RichTextInputPosition(utf16Offset: anchorOffset, affinity: anchorAffinity),
                            head: RichTextInputPosition(utf16Offset: headOffset, affinity: headAffinity)),
                        reason: .keyboard)
        }
    }
    // `markedTextRange` / `markedTextStyle` / `setMarkedText(_:selectedRange:)` / `unmarkText()` —
    // Task C9 (Family 6, marked text and prediction) — moved OUT of this file into
    // `+TextBackend.swift`, mirroring Task C8's move of `deleteBackward()` into `+KeyInput.swift`:
    // real enough now to need their own file, and `state`/`kernelInput`/`publishState` all needed
    // from a second file (see that file's own doc comment on the resulting access-level changes).

    /// Task C4 Step 8/9: routed into `kernelInput`, guarded per `IDBackendCallGuardTests`. Both
    /// `beginningOfDocument`/`endOfDocument` are non-Optional `UITextInput` requirements — unlike
    /// every other witness below, there is no `nil` to fall back to on a caught failure, so a
    /// fresh, obviously-synthetic position at offset 0 (this file's established "zero means
    /// absent" convention — see `floatingScrollVelocity`) is the least-wrong answer.
    var beginningOfDocument: UITextPosition {
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.beginningOfDocument
        }, &error) as? UITextPosition
        if let error { reportKernelFailure(error, witness: #function) }
        return value ?? TGRichTextInputDecPosition(offset: 0, affinity: .forward, revision: 0)
    }
    var endOfDocument: UITextPosition {
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.endOfDocument
        }, &error) as? UITextPosition
        if let error { reportKernelFailure(error, witness: #function) }
        return value ?? TGRichTextInputDecPosition(offset: 0, affinity: .forward, revision: 0)
    }

    /// TASK F4 — the range is now NORMALISED before it reaches the kernel.
    ///
    /// The kernel casts every incoming range to its own `TGRichTextInputDecRange` unchecked, so a
    /// CANVAS-minted range (`LegacyTextIdentity.range(fromGlobal:toGlobal:)`) made this witness
    /// raise `-[LegacyTextPosition documentRevision]: unrecognized selector`, which the exception
    /// guard turned into a **nil** answer — silently, since F1 made `reportKernelFailure` non-fatal.
    /// That is F1's deferred identity-seam residual, and it has a live consumer: the native
    /// checking controller converts its ranges through
    /// `DocumentCanvasView.nativeTextRange(forGlobalLocation:length:)`, which mints the canvas shape
    /// under EVERY backend, then reads them back through this witness. Measured on an attached
    /// `.inputDec` canvas: `text(in: nativeTextRange(forGlobalLocation: 6, length: 5))` returned
    /// `nil` (legacy: `" wrol"`), and `annotatedSubstring(for:)` degraded to `""` — so even with the
    /// checking driver installed the controller would be handed empty text and flag nothing.
    ///
    /// Same shape as F1's fix for the eight geometry witnesses: resolve BOTH identity types through
    /// the sanctioned accessors (`resolvedGlobalRange(of:)`, `+Geometry.swift`) and re-mint the
    /// kernel's own type, rather than teaching the kernel a second identity. A genuinely foreign
    /// `UITextRange` still resolves to `nil` and is forwarded unchanged, so it degrades exactly as
    /// before instead of being fabricated into a range over the document.
    func text(in range: UITextRange) -> String? {
        let kernelRange = normalizedKernelRange(for: range) ?? range
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.text(in: kernelRange) as NSString?
        }, &error) as? String
        if let error { reportKernelFailure(error, witness: #function) }
        return value
    }
    /// Task D3b — was a literal empty-body stub (D3's `cut-collapses-the-selection` root cause):
    /// `legacyCut(_:)`/`legacyPaste`-adjacent callers, and — per this witness's own `UITextInput`
    /// contract — autocorrect acceptance, all reach this member with a caller-supplied range and
    /// replacement text, and it silently did nothing.
    ///
    /// **Narrowing (Legacy's own shape).** `LegacyRichTextInputBackend+Insertion.swift`'s
    /// `replace(_:withText:)` narrows `range as? LegacyTextRange` and returns on mismatch; this
    /// backend's identity type is `TGRichTextInputDecRange` (`start`/`end` are always
    /// `TGRichTextInputDecPosition` — enforced at construction by `+rangeFrom:to:`'s ObjC signature
    /// — so the nested downcasts below cannot fail for a genuine instance, but stay defensive,
    /// matching every other foreign-range guard in this file). Do NOT reuse `LegacyTextRange` here —
    /// R8/R11/R12 each hit the wall that Legacy's opaque identity types cannot cross into this
    /// backend; `TGRichTextInputDecRange` is the one that can.
    ///
    /// **Route: (b), through the storage façade — NOT `kernelInput?.replace(_:withText:)` — mirroring
    /// `insertText(_:)`'s own Task R2 decision, not `deleteBackward()`'s.** Unlike `deleteBackward`/
    /// `setMarkedText`, which MUST consult the kernel (it alone knows the backward-delete span, or
    /// composes against its own live session), this witness is handed a COMPLETE, already-resolved
    /// range and replacement text — there is nothing left for the kernel to resolve. Going through
    /// `kernelInput` would forward into the REAL system input controller's own `replaceRange:
    /// withText:` (verified in `IDUIKitInputControllerCapability.m:241`: `[[self activeController]
    /// replaceRange:range withText:text]`), a private object with no obligation to route back through
    /// Telegram's document client — exactly the side channel `+Responder.swift`'s own header forbids
    /// for `cut`/`copy`/`paste`. The façade's `replaceCharactersInRange:withString:` is R2's
    /// established single crossing point (two-phase transaction, keeps `mirror`/`revision` current,
    /// posts `edited:`) — reused verbatim, not re-derived.
    ///
    /// **No pre-warm.** R10 (`deleteBackward`) and D2 (`setMarkedText`) both pre-warm
    /// `kernelInput?.selectedTextRange` because THEIR kernel call resolves an operation against the
    /// kernel's own cached selection. This witness never calls `kernelInput` at all — the range to
    /// mutate is the CALLER-SUPPLIED `range` parameter, not "the caret" — so there is nothing for a
    /// pre-warm to correct. Adding one here would be inventing a dependency this call shape does not
    /// have (R6's own `unmarkText` measurement — a pre-warm that isn't load-bearing still costs a
    /// reactive-storm regression — is exactly the caution against doing this reflexively).
    ///
    /// **Intent: `.programmatic`, deliberately, not `.insertText`/`.paste`/`.dictation`.** This
    /// witness is reached by cut (empty replacement text), autocorrect (a word substitution — Legacy's
    /// own `legacyReplace(globalFrom:globalTo:text:)` names this explicitly: "A keyboard
    /// autocorrection arrives here as `replace(word, correction)`"), and, per the `UITextInput`
    /// contract generally, Find & Replace — none of which is recoverable from this call's own
    /// arguments. `.programmatic` is not merely the safe fallback here: `IDTextEditorBackendIntent
    /// .mutation(for: .programmatic, range:...)` maps to `.replaceText(range: range, text:...,
    /// origin: .programmatic)` — the ONE `RichTextInputMutation` case that carries an explicit range
    /// rather than "the selection", i.e. the exact shape this witness needs. Mistagging as
    /// `.insertText`/`.deleteBackward` would both build the wrong mutation case (they read
    /// `state.selection`, ignoring the caller's `range` entirely) AND corrupt the latch's real
    /// purpose (recovering "pressed Return" vs "typed a newline") for an operation that is neither.
    /// `.dictation` was considered and rejected: the vendored kernel's own capability manifest
    /// (`UIKitBehaviorContracts-iOS26.5.json`, `"dictation"` capability) lists exactly one member,
    /// `insertDictationResult:`, whose OWN documented fallback is "Concatenate phrase text and call
    /// insertText:" — never `replace(_:withText:)` — so tagging this witness `.dictation` would claim
    /// a caller identity the kernel's own contract says does not reach here.
    func replace(_ range: UITextRange, withText text: String) {
        guard let r = range as? TGRichTextInputDecRange,
              let startPosition = r.start as? TGRichTextInputDecPosition,
              let endPosition = r.end as? TGRichTextInputDecPosition else { return }
        guard isAttached, let host else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard !isMutating else {
            RichTextInputContractViolation.report(
                "mutating reentry rejected: replace(_:withText:) called while a mutation is already in flight")
            return
        }
        // Normalized min/max, exactly like Legacy's own `legacyReplace(globalFrom:globalTo:text:)`
        // (`lo = min(...); hi = max(...)`) and `RichTextCanonicalSelection.normalizedRange` — the
        // RANGE OBJECT's own start/end stay unordered by construction (`TGRichTextInputDecRange.h`'s
        // own doc comment), but the concrete edit this witness performs is on an ordered span.
        let lowerOffset = min(startPosition.utf16Offset, endPosition.utf16Offset)
        let upperOffset = max(startPosition.utf16Offset, endPosition.utf16Offset)
        let mutationRange = NSRange(location: lowerOffset, length: upperOffset - lowerOffset)
        guard host.lifecycleClient.editPolicy.isEditable else {
            host.lifecycleClient.backendDidRejectMutation(
                buildReplaceMutation(host: host, range: mutationRange, text: text), reason: .notEditable)
            return
        }
        guard ensureCanonicalSelectionIsCurrent(host: host) else {
            host.lifecycleClient.backendDidRejectMutation(
                buildReplaceMutation(host: host, range: mutationRange, text: text), reason: .revisionMismatch)
            return
        }
        guard let bridge else { return }
        isMutating = true
        withTransaction {
            bridge.storage.currentIntent = .programmatic
            bridge.storage.revision = state.documentRevision
            bridge.storage.replaceCharacters(in: mutationRange, with: text)
            isMutating = false
        }
    }
    // `setMarkedText(_:selectedRange:)` / `unmarkText()` — see `+TextBackend.swift`.

    /// TASK H2 — the four position-taking Family-1 witnesses below (this one, `position(from:offset:)`,
    /// `position(from:in:offset:)`, `compare(_:to:)` and `offset(from:to:)`) NORMALISE their incoming
    /// positions before the kernel sees them, exactly as `text(in:)` above normalises its range.
    ///
    /// Same asymmetry, same fix shape, and the same live consumer: the canvas mints
    /// `LegacyTextIdentity` under every backend, and the private checking controller hands those
    /// objects straight back into this algebra. Unnormalised, the kernel raised `unrecognized
    /// selector`, the guard swallowed it, and each witness answered its "no reply" fallback — which
    /// for `compare(_:to:)` is `.orderedSame` and for `offset(from:to:)` is `0`, i.e. **"the two
    /// positions are the same place"**, a confidently wrong answer rather than an absent one.
    /// Measured: `compare(L1,k11)` answered `0` where `compare(k1,k11)` answered `-1`, and the
    /// checking controller stopped there having decided the word was empty. See
    /// `normalizedKernelPosition(for:)` (`+Geometry.swift`) for the full reading.
    ///
    /// A genuinely foreign `UITextPosition` still normalises to `nil` and is forwarded unchanged, so
    /// it degrades exactly as before instead of being fabricated into an offset in the document.
    func textRange(from: UITextPosition, to: UITextPosition) -> UITextRange? {
        let kernelFrom = normalizedKernelPosition(for: from) ?? from
        let kernelTo = normalizedKernelPosition(for: to) ?? to
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.textRange(from: kernelFrom, to: kernelTo)
        }, &error) as? UITextRange
        if let error { reportKernelFailure(error, witness: #function) }
        return value
    }
    func position(from: UITextPosition, offset: Int) -> UITextPosition? {
        let kernelFrom = normalizedKernelPosition(for: from) ?? from
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.position(from: kernelFrom, offset: offset)
        }, &error) as? UITextPosition
        if let error { reportKernelFailure(error, witness: #function) }
        return value
    }
    /// Task D3c — was a literal `{ nil }` stub (the Task-B3/C4-Step-8 placeholder, deliberately
    /// left unrouted "since UIKit never drives vertical/horizontal nav through this witness in the
    /// stage-1 contract corpus"). That assumption doesn't hold: `DocumentCanvasView`'s OWN
    /// `position(from:in:direction:offset:)` (the real `UITextInput` conformance, in
    /// `+Navigation.swift`) forwards EVERY hardware-arrow-driven caret move here verbatim — the
    /// package `CLAUDE.md`'s own "OS-facing vertical-nav witness ... driven by the OS through this
    /// method + the `selectedTextRange` setter, not `keyCommands`" invariant, which applies to
    /// BOTH backends identically. A `nil` return here isn't merely incomplete: `caretByNavigating`
    /// (and, in production, the OS's own `position(from:in:offset:)` probe on every arrow key) reads
    /// nil as "no progress" and leaves the caret exactly where it started — so a caret PARKED
    /// immediately before a two-slot paragraph-boundary gap and stepped `.right` never reaches the
    /// next paragraph at all, one step short every time (the differential's own
    /// `caret-across-paragraph-boundary` divergence: two real `.right` steps from Legacy's own
    /// structural axis land at the next paragraph's start; the stub left the ID caret exactly where
    /// it began). `kernelInput` conforms to `UITextInput` directly (see
    /// `IDUIKitInputControllerCapability`'s own `<UITextInput, UIKeyInput>` conformance), so this is
    /// the same one-line kernel forward as `position(from:offset:)` just above it — no new axis
    /// concept, since the kernel already resolves this on its own structural position axis exactly
    /// like every OTHER member this file routes.
    func position(from: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        let kernelFrom = normalizedKernelPosition(for: from) ?? from
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.position(from: kernelFrom, in: direction, offset: offset)
        }, &error) as? UITextPosition
        if let error { reportKernelFailure(error, witness: #function) }
        return value
    }
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let kernelPosition = normalizedKernelPosition(for: position) ?? position
        let kernelOther = normalizedKernelPosition(for: other) ?? other
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            (self.kernelInput?.compare(kernelPosition, to: kernelOther)).map { NSNumber(value: $0.rawValue) }
        }, &error) as? NSNumber
        if let error { reportKernelFailure(error, witness: #function) }
        // `ComparisonResult` has no "unknown" case; `.orderedSame` asserts no relative order
        // rather than an arbitrary direction — the closest available answer to "no reply".
        // TASK H2: this fallback is REACHED far less often now, and that is the point — see
        // `textRange(from:to:)`'s own comment. It still reads as "the same place", so it must stay
        // the answer of last resort for a genuinely foreign position and never the answer for a
        // canvas-minted one.
        return value.flatMap { ComparisonResult(rawValue: $0.intValue) } ?? .orderedSame
    }
    func offset(from: UITextPosition, to other: UITextPosition) -> Int {
        let kernelFrom = normalizedKernelPosition(for: from) ?? from
        let kernelOther = normalizedKernelPosition(for: other) ?? other
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            (self.kernelInput?.offset(from: kernelFrom, to: kernelOther)).map { NSNumber(value: $0) }
        }, &error) as? NSNumber
        if let error { reportKernelFailure(error, witness: #function) }
        return value?.intValue ?? 0
    }
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? { nil }
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? { nil }
    // MARK: - `RichTextInputTextBackend` — Family 2 (geometry)
    //
    // TASK F1 moved all EIGHT geometry witnesses — `caretRect(for:)`, `firstRect(for:)`,
    // `selectionRects(for:)`, both `closestPosition(to:…)` arities, `characterRange(at:)`,
    // `baseWritingDirection(for:in:)` and `setBaseWritingDirection(_:for:)` — into
    // `IDTextEditorBackend+Geometry.swift`, and OFF `kernelInput` entirely.
    //
    // Task C5 had routed each of them into the kernel as a one-line forward. Two independent defects,
    // the second of which crashed the app on the user's first tap with the flag enabled: the kernel
    // is not the geometry authority (it lays out through its own synthetic, unstyled `NSTextContainer`
    // and knows nothing of this editor's blocks, fonts or viewport — `RichTextInputGeometryClient` is
    // the sole authority, per the spec and per `LegacyRichTextInputBackend+Geometry.swift`), and it
    // cannot even be ASKED with the canvas-minted position the production caller supplies
    // (`caretRect(atGlobal:)` mints `LegacyTextIdentity.position(atGlobal:)` whatever backend is
    // installed; the kernel casts it to `TGRichTextInputDecPosition` unchecked and sends
    // `-utf16Offset` → `unrecognized selector`). That file's header carries the full account.

    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? { nil }

    /// Task R12 (cluster 14) — mirrors `LegacyRichTextInputBackend.insertDictationResult(_:)`
    /// (`+Unwitnessed.swift`) byte-for-byte, including D15: this member NEVER reaches the document
    /// client, allowed or not — there is no kernel insertion entry point to route a real dictation
    /// commit through (see `insertText(_:)`'s own header: no `kernelInput` witness exists for a
    /// general insert), so a permissive policy stays the pre-existing silent no-op, unchanged. When
    /// the CURRENT policy disallows dictation, this reports a rejection through the same
    /// `backendDidRejectMutation` channel a real mutation rejection uses — built (the joined phrase
    /// text, `.dictation` origin) but never run through `prepareAndCommitReplacement`, exactly
    /// mirroring how `insertText(_:)`'s own rejection branches report an attempted mutation without
    /// touching the document client. `.unsupportedOperation` is the same disclosed, non-dedicated
    /// reason Legacy's copy uses (no `RichTextInputMutationRejection` case exists for "dictation
    /// disallowed by policy"). Detached: reports a contract violation, matching every other
    /// content/selection-mutating member on this backend (`insertText`, `deleteBackward`,
    /// `setSelection`, …) — not the silent-when-detached direction `editPolicyDidChange()` two
    /// members up takes, which preserves THAT member's own pre-existing (never-reporting) shape.
    /// `BackendEditPolicyTests.test_allowsDictationFalse_rejectsInsertDictationResult` is the shared
    /// pin (both backends).
    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        guard isAttached, let host else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard host.lifecycleClient.editPolicy.allowsDictation else {
            let joinedText = dictationResult.map { $0.text }.joined()
            let mutation = RichTextInputMutation.insertText(
                text: NSAttributedString(string: joinedText),
                replacing: canonicalSelection,
                origin: .dictation)
            host.lifecycleClient.backendDidRejectMutation(mutation, reason: .unsupportedOperation)
            return
        }
    }

    // MARK: - `RichTextKeyInputBackend` (`UIKeyInput` routing)

    /// **TASK F2 — this answered `false` unconditionally**, the same silent-stub shape as
    /// `isEditableForWritingTools` above and found in the same sweep. It is not the keyboard defect,
    /// but it is a live one: besides UIKit's own per-keystroke polling (which uses it for the
    /// keyboard's delete affordance), `TelegramCommandInputClient` gates BOTH `.selectWord` and
    /// `.selectAll` on `canvas.hasText` (`Clients/TelegramCommandInputClient.swift:201,206`), so a
    /// constant `false` made Select and Select All permanently unavailable in the ID edit menu, with
    /// nothing failing anywhere.
    ///
    /// Mirrors `LegacyRichTextInputBackend.hasText` (`+Insertion.swift:174-177`) exactly, including
    /// its two disclosed decisions: the detached answer is `false` (`host` is nil'd in `detach()`, so
    /// the `guard` is the same window Legacy's `self.document` nil-check covers), and NO
    /// `RichTextInputContractViolation` is reported — UIKit polls this on the keyboard's
    /// per-keystroke path, where an unthrottled report would flood.
    var hasText: Bool {
        guard let host else { return false }
        return host.documentClient.utf16Length > 0
    }
    /// Task C11 (Family 8) — the ONE piece of `RichTextInputLifecycleClient.editPolicy` gating this
    /// backend does today: `RichTextInputLifecycleClient`'s own doc comment states the general
    /// contract ("edit policy is read at operation time and may change without replacing the
    /// backend") for every operation, not only the responder-lifecycle ones — see
    /// `+Responder.swift`'s header for why this member, not `+KeyInput.swift`, is where that
    /// contract's `insertText` half is honored.
    ///
    /// **Task R2 — wired to the storage façade, not to `kernelInput`.** There is NO kernel insertion
    /// entry point: `IDUIKitInputControllerCapability`'s surface has
    /// `preflightBackwardDeleteRanges`/`backwardDeleteRange`, cut/copy/paste, spell-checking,
    /// `insertDictationResultIfSupported:` and `detach` — no general insert — so this is not a
    /// `kernelInput`-routing witness like `deleteBackward()` (`+KeyInput.swift`). Task C7 built the
    /// whole two-phase transaction (`IDTextEditorBackendClientBridge.prepareAndCommitReplacement`)
    /// and the intent latch; this witness is what finally calls into it.
    ///
    /// **Route (b), not (a) — go through the façade's `replaceCharactersInRange:withString:`, not a
    /// direct `bridge.prepareAndCommitReplacement` call. Evidence:**
    /// `TGRichTextInputDecTextStorageFacade` is not a bare pass-through — its own doc comment states
    /// its purpose plainly: "UIKit calls `string` and `attributesAtIndex:effectiveRange:` constantly
    /// during layout and selection, so `mirror` [a real `NSMutableAttributedString`] answers those
    /// reads; Telegram's document (behind `bridge`) remains the WRITE authority." Its
    /// `replaceCharactersInRange:withString:` override does FOUR things, not one: (1) run the
    /// two-phase transaction via `bridge`, then, only if applied, (2) `beginEditing`/`endEditing`
    /// around a real `[self.mirror replaceCharactersInRange:...]` write, (3) post `edited:` (which
    /// notifies whatever `NSLayoutManager`/text-storage observers the private kernel controller has
    /// installed), and (4) advance `self.revision` from the transaction's own outcome. A direct
    /// `bridge.prepareAndCommitReplacement` call (route a) would perform (1) alone: the document
    /// client would be correct, but the façade's `mirror`/`revision` — what the private input
    /// controller's OWN read path (`string`/`attributesAtIndex:effectiveRange:`) and every OTHER
    /// façade-routed witness (`setMarkedText`, which drives through the SAME kernel-owned path onto
    /// this SAME façade — see `+TextBackend.swift`) depend on — would silently go stale. These 29
    /// tests would not catch that divergence (none of them exercises a live kernel read of `mirror`
    /// after a programmatic `insertText`), but a real keyboard driving BOTH paths on the SAME canvas
    /// would. See `DIVERGENCES.md` for the same reasoning recorded against the vendored kernel.
    ///
    /// **The transaction bracket.** `insertText(_:)` is now a genuine, first-party mutation entry
    /// point (unlike `LegacyRichTextInputBackend`'s own `insertText`, a plain `legacyCanvas` forward
    /// under D35 with no test-only substitute standing in for `.inputDec`), so it owns the SAME
    /// contract `LegacyRichTextInputBackend+Mutation.swift`'s `prepareAndRun`/
    /// `ensureCanonicalSelectionIsCurrent` machinery describes, reachable there only through the
    /// test-only `ReferenceMutationBackend` — mirrored here as first-party production behavior:
    /// reentrancy rejection (`isMutating`), the edit-policy gate (moved from a bare early-return to
    /// a REPORTED rejection — see below), and D32's "rebase or reject, never loop"
    /// (`ensureCanonicalSelectionIsCurrent(host:)`). `editPolicy` is read fresh on every call, never
    /// cached at attach — `test_editPolicyIsReadAtOperationTime_notCachedAtAttach` pins this.
    ///
    /// **Reporting a rejection now reports via `backendDidRejectMutation`, not silently.**
    /// `test_notEditable_rejectsInsertText_withNotEditable_andNoDelegateNotifications` requires a
    /// `.notEditable` rejection to actually reach the lifecycle client (mirroring
    /// `LegacyRichTextInputBackend+Mutation.swift`'s own `prepareAndRun`: "`build` is called EXACTLY
    /// ONCE ... to report the rejection ... with the STALE, un-rebased selection" — the SAME
    /// attributed-text construction the success path uses, via `buildInsertTextMutation(host:text:)`,
    /// so a rejected `insertText` reports the same mutation a successful one would have built).
    func insertText(_ text: String) {
        guard isAttached, let host else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard !isMutating else {
            RichTextInputContractViolation.report(
                "mutating reentry rejected: insertText called while a mutation is already in flight")
            return
        }
        guard host.lifecycleClient.editPolicy.isEditable else {
            host.lifecycleClient.backendDidRejectMutation(
                buildInsertTextMutation(host: host, text: text), reason: .notEditable)
            return
        }
        guard ensureCanonicalSelectionIsCurrent(host: host) else {
            host.lifecycleClient.backendDidRejectMutation(
                buildInsertTextMutation(host: host, text: text), reason: .revisionMismatch)
            return
        }
        guard let bridge else { return }
        // Task R9 (cluster 6, Step 3) — routed through `withTransaction(_:)`, same shape and same
        // reasoning as `synchronizeAfterExternalChange`'s matching change (see that method's own
        // updated comment, and `withTransaction(_:)`'s own doc comment for why this routing —
        // rather than a bare `activeTransactionDepth += 1` here — is required).
        isMutating = true
        withTransaction {
            let range = state.selection.normalizedRange
            bridge.storage.currentIntent = .insertText
            // Kept fresh from `state.documentRevision` right here, rather than trusted to have been kept
            // in step by earlier calls: `ensureCanonicalSelectionIsCurrent(host:)` above may just have
            // rebased `state.documentRevision` forward, and the façade's own `expectedRevision` (what it
            // hands `prepareMutation`, `TGRichTextInputDecTextStorageFacade.m`) must reflect that, not a
            // value only the façade itself last wrote back after some earlier, unrelated commit.
            bridge.storage.revision = state.documentRevision
            // Task R3 — REMOVED the range clamp that used to sit here. It clamped `range` down to
            // `bridge.storage.mirror.length` to dodge exactly the `NSMutableRLEArray … Out of bounds`
            // exception `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:withString:`
            // (called via `replaceCharacters(in:with:)` just below) used to throw when the mirror was
            // still empty. That was a narrow, call-site-local workaround for a general problem: the
            // mirror was never seeded/kept in sync anywhere in the package. `replaceCharactersInRange:
            // withString:` now self-heals via `synchronizeMirrorWithDocumentIfNeeded` (called at its
            // own top, before it ever reads `range` against `self.mirror`), so clamping here is both
            // unnecessary AND actively wrong: a legitimate `range` could silently be truncated instead
            // of failing loudly (or, now, simply succeeding against a correctly-sized mirror).
            // `IDBackendMutationContractTests`/`IDBackendRevisionContractTests` (the four tests R2's
            // own clamp was written to keep from throwing) are the check that removing it does not
            // reintroduce the exception — see this task's report.
            bridge.storage.replaceCharacters(in: range, with: text)
            isMutating = false
        }
    }

    /// Task R10 (cluster 9) — Swift-side intent latch for `deleteBackward()` (`+KeyInput.swift`).
    /// Mirrors `insertText(_:)`'s own direct `bridge.storage.currentIntent = .insertText` write
    /// above, rather than trusting the ABI-witnessed `keyboardInputShouldDelete:` canvas thunk
    /// (`TGRichTextInputDecCanvasABIWitness.m`) — which every earlier task's doc comments assumed
    /// would latch it — to have already run.
    ///
    /// **Measured, not assumed: that thunk never fires on this path.** Instrumented directly (a
    /// temporary `NSLog` in the thunk, `keyboardInputShouldDelete:`, and the facade's own
    /// `replaceCharactersInRange:withString:`, reverted before commit): driving
    /// `IDBackendFamily5Tests.test_deleteBackwardUsesTheControllerProposedRange` end to end logs
    /// exactly ONE line — the facade's replace, with `currentIntent == 0` (`.programmatic`, the
    /// value every transaction unconditionally resets to on exit) — and NONE of the three
    /// intent-latching thunks (`keyboardInputShouldDelete:`, `keyboardInput:shouldInsertText:
    /// isMarkedText:`, `textInput:shouldChangeCharactersInRanges:replacementText:`) ever logs.
    /// Consistent with the manifest's own `"direction": "incoming"` on that row: the kernel
    /// RECEIVES the call from somewhere, but that somewhere is a genuine system software-keyboard
    /// dispatch layer sitting ABOVE `UIKeyInput.deleteBackward()` — and `+KeyInput.swift`'s
    /// `deleteBackward()` (which calls straight into `kernelInput?.deleteBackward()`) IS that
    /// top-level entry point, both in this test harness and in production (nothing in this seam
    /// sits above it to have made that preflight call first). So the intent this backend's own
    /// `deleteBackward()` KNOWS it is performing must be latched directly, exactly as
    /// `insertText(_:)` above already does for its own intent — not left to a callback this kernel
    /// does not invoke from this call shape. `bridge` is `private` to this file; this narrow,
    /// purpose-built crossing point is what `+KeyInput.swift` calls instead of widening that access
    /// (mirrors `mintKernelSelectedTextRange()`'s own reasoning for its own narrow crossing point).
    func latchDeleteBackwardIntent() {
        bridge?.storage.currentIntent = .deleteBackward
    }

    /// Task D2 — a THIRD instance of the same class of gap R10 found for `deleteBackward()` above
    /// (which was itself the SECOND: R7 got this class of mistake once already). R10's OWN
    /// instrumentation (see `latchDeleteBackwardIntent()`'s doc comment immediately above) already
    /// measured that `keyboardInput:shouldInsertText:isMarkedText:` — the exact thunk
    /// `+TextBackend.swift`'s `setMarkedText(_:selectedRange:)` header comment claims latches
    /// `.markedText` before the façade's `replaceCharactersInRange:withString:` runs — NEVER FIRES,
    /// alongside the other two. That measurement's own scope (Family 5 / `deleteBackward`) never
    /// propagated the fix to `setMarkedText`, leaving the header comment stale and the façade seeing
    /// `currentIntent == .programmatic` for a live IME composition.
    ///
    /// **Confirmed independently here, not merely inferred from R10's old measurement**: the
    /// `IDBackendDifferentialTraceTests` `cjk-compose-commit` scenario (`setMarkedText("にほ", ...)`)
    /// recorded `documentPrepare(replaceText)`, never `documentPrepare(setMarkedText)`, before this
    /// fix — the exact tell the task brief's Step 4 describes for `deleteBackward`/
    /// `insertParagraphBreak`, just on a third mutation kind the brief's own five scenarios happened
    /// to also exercise. Latched directly, mirroring `insertText(_:)`/`latchDeleteBackwardIntent()`.
    ///
    /// **Task D4d — the latch now carries a VALUE, not just a tag.** `UITextInput`'s
    /// `setMarkedText(_:selectedRange:)` supplies a caret expressed relative to the marked text
    /// (`{0, 0}` = the START of the offer, which is what a system inline prediction sends;
    /// `{count, 0}` = its END, which is what a CJK composition sends), and the façade's raw
    /// `replaceCharactersInRange:withString:` crossing point destroys it exactly the way it
    /// destroys the intent — it is a range replace with no marked-text-relative anything. Before
    /// this, `IDTextEditorBackendIntent.mutation(for:…)` FABRICATED it as end-of-marked-text
    /// unconditionally, which the differential corpus measured as a uniform `+2` selection offset
    /// in all nine `inline-prediction-ios26.5-v1` scenarios. Carrying it beside the intent is the
    /// smallest change consistent with how the intent itself already travels; the value is
    /// CONSUMED by `IDTextEditorBackendClientBridge.prepareAndCommitReplacement` (read-and-clear,
    /// mirroring the façade's own unconditional `currentIntent` reset) so a `.markedText`
    /// transaction that arrives from anywhere else — e.g. the
    /// `keyboardInput:shouldInsertText:isMarkedText:YES` canvas thunk in
    /// `TGRichTextInputDecCanvasCallbacks.m:140`, which R10 measured never fires but which is still
    /// the only other writer of this intent — can never inherit a stale caret.
    func latchMarkedTextIntent(selectedRange: NSRange? = nil) {
        bridge?.storage.currentIntent = .markedText
        pendingMarkedTextSelectedRange = selectedRange
    }

    /// The marked-text-relative caret latched by `latchMarkedTextIntent(selectedRange:)`, read AND
    /// cleared in one step. Deliberately consuming: it belongs to exactly ONE transaction, the same
    /// way `TGRichTextInputDecTextStorageFacade.currentIntent` is reset unconditionally at the end
    /// of every transaction whether that transaction applied or was rejected.
    func takePendingMarkedTextSelectedRange() -> NSRange? {
        defer { pendingMarkedTextSelectedRange = nil }
        return pendingMarkedTextSelectedRange
    }

    /// The same `IDTextEditorBackendIntent.mutation(for:...)` construction the façade's own
    /// `prepareAndCommitReplacement` call performs for a real `.insertText` intent (see that
    /// method), reused here so a REJECTED call (edit-policy / revision-mismatch, both above) reports
    /// the identical attributed mutation a successful one would have built — never a
    /// cheaper-but-different stand-in.
    private func buildInsertTextMutation(host: any RichTextInputHost, text: String) -> RichTextInputMutation {
        IDTextEditorBackendIntent.mutation(
            for: .insertText, range: state.selection.normalizedRange, text: text, selection: state.selection,
            typingAttributes: { host.documentClient.typingAttributes(at: state.selection.head) })
    }

    /// Task D3b — `replace(_:withText:)`'s own counterpart to `buildInsertTextMutation(host:text:)`
    /// immediately above: the identical `IDTextEditorBackendIntent.mutation(for:...)` construction a
    /// successful `.programmatic` replace would build, reused so a rejected call reports the same
    /// attributed mutation rather than a cheaper stand-in. `typingAttributes` is passed for shape
    /// parity with every other `build*Mutation` helper; `.programmatic`'s own mapping never invokes it
    /// (see `IDTextEditorBackendIntent.mutation(for:...)`'s doc comment — the closure is read only by
    /// the `.insertText` non-newline branch).
    private func buildReplaceMutation(host: any RichTextInputHost, range: NSRange, text: String) -> RichTextInputMutation {
        IDTextEditorBackendIntent.mutation(
            for: .programmatic, range: range, text: text, selection: state.selection,
            typingAttributes: { host.documentClient.typingAttributes(at: state.selection.head) })
    }

    /// D32 ("a stale object is explicitly rebased or rejected; its integer offset is not silently
    /// reinterpreted against a new document"), ported from
    /// `LegacyRichTextInputBackend+Mutation.swift`'s `ensureCanonicalSelectionIsCurrent(document:)` —
    /// same algorithm, same "at most one rebase per distinct offset, never a loop" shape: a collapsed
    /// selection (anchor == head) needs only one `document.rebase` call, its result reused for both
    /// endpoints; a non-collapsed one rebases each endpoint independently and refuses the whole
    /// operation if EITHER fails. `targetRevision` is captured ONCE, before any rebase call, and is
    /// what a caller may go on to use as the mutation's `expectedRevision` — never a live re-read
    /// afterward (a client that keeps moving its own `revision` DURING the rebase call, the
    /// `revisionAfterRebase` test knob, must not make this method attempt a second rebase within the
    /// same call — `IDBackendRevisionContractTests.test_rebaseIsAttemptedAtMostOncePerOperation_andCannotLoop`).
    ///
    /// Returns `true` immediately when nothing is stale (the common case). On success, ADOPTS
    /// `targetRevision`/the rebased selection into `state` directly — no notification, no publish;
    /// this is a quiet internal correction, not a change for `inputDelegate`/the presentation client
    /// to see (mirrors Legacy's own plain assignment). A mutation that goes on to commit normally
    /// overwrites this `state.documentRevision` again with the commit's own result — this method's
    /// adoption is only what makes THAT commit's `expectedRevision` honest.
    private func ensureCanonicalSelectionIsCurrent(host: any RichTextInputHost) -> Bool {
        let targetRevision = host.documentClient.revision
        guard targetRevision != state.documentRevision else { return true }
        let fromRevision = state.documentRevision
        let currentAnchor = state.selection.anchor
        let currentHead = state.selection.head
        guard let rebasedAnchor = host.documentClient.rebase(currentAnchor, fromRevision: fromRevision) else {
            return false
        }
        let rebasedHead: RichTextInputPosition
        if currentHead == currentAnchor {
            rebasedHead = rebasedAnchor
        } else if let rebasedOther = host.documentClient.rebase(currentHead, fromRevision: fromRevision) {
            rebasedHead = rebasedOther
        } else {
            return false
        }
        state = RichTextInputStateSnapshot(
            documentRevision: targetRevision,
            selection: RichTextCanonicalSelection(anchor: rebasedAnchor, head: rebasedHead),
            markedRange: state.markedRange, isComposing: state.isComposing)
        return true
    }

    /// The transaction boundary `insertText(_:)` returns to once its own bracket
    /// (prepare/notify/commit/notify/publish, all inside the façade call above) has fully completed.
    /// Drains a deferred external change FIRST — "the friendlier choice" (mirrors
    /// `LegacyRichTextInputBackend+Attachment.swift`'s `endTransaction()`'s own reasoning: applying a
    /// change the caller was told would eventually land, rather than silently dropping it because a
    /// detach raced it) — THEN a latched detach. Reusing the public `synchronizeAfterExternalChange(_:)`/
    /// `detach()` bodies directly is safe and correct here specifically because `isMutating` is
    /// already `false` by the time this runs: neither call re-defers/re-latches against ITSELF, and
    /// `synchronizeAfterExternalChange(_:)`'s own continuity guard is exactly what makes a change that
    /// went stale BETWEEN being deferred and being drained here a REPORTED rejection, not a silent
    /// drop or a silent stale apply (`IDBackendReentrancyTests
    /// .test_deferredExternalChangeThatBecomesStaleByDrainTime_isRejectedWithAContinuityViolation`).
    ///
    /// Task R9 (cluster 6, Step 3) — **bounded to AT MOST ONE drain per OUTER call**, mirroring
    /// `LegacyRichTextInputBackend+Attachment.swift`'s `endTransaction()` exactly (both the depth gate
    /// and the manual-bump drain below; see that method's own doc comment for the full reasoning, not
    /// restated here). Before this task the drain below was unconditional: it called
    /// `synchronizeAfterExternalChange(change)` directly, and THAT call's own trailing
    /// `endTransaction()` would call it again if a client re-stashes a new `deferredExternalChange`
    /// from inside the drained call's own publish (the realistic case: a lifecycle client that reacts
    /// to every `.externalSynchronization` publish by requesting a fresh sync) — an unbounded chain,
    /// measured (`IDBackendReentrancyTests
    /// .test_aChangeReStashedDuringTheOneDrainThisTransactionPerforms_isLeftPendingNotChainedHere`)
    /// to hang the real (non-`.legacy`) backend rather than the merely-off-by-one divergence the
    /// original characterization anticipated — that test's `stashCap` safety cap (added by Task R1 to
    /// convert the hang into a bounded, reportable failure) is NOT removed by this fix; the fixed
    /// behavior simply never approaches it.
    ///
    /// `activeTransactionDepth` (bumped alongside `isMutating` at `insertText(_:)`'s and this method's
    /// own top) answers "is this the OUTERMOST bracket returning". Decrementing it FIRST and gating
    /// the rest of this method on `== 0` means a call reached while some bracket is still nested
    /// (this method invoked from inside another still-open bracket further up the call stack) is a
    /// no-op beyond the decrement — there is no such caller today (both real entry points call this
    /// only at their own tail, after their own `isMutating = false`), but the guard is what makes the
    /// manual bump immediately below actually work, not merely coincidentally safe.
    ///
    /// The drain itself: capture-and-clear the ONE pending change, then run it with the depth counter
    /// manually held above 0 across the call (bump BEFORE, restore the captured pre-drain value AFTER
    /// — not `+= 1`/`-= 1`, so this is correct regardless of what the drained call itself does to the
    /// counter). The drained `synchronizeAfterExternalChange(change)` bumps the counter itself at ITS
    /// OWN top (to depthBeforeDrain + 2) and decrements it at ITS OWN `endTransaction()` call (back to
    /// depthBeforeDrain + 1) — never reaching 0 — so THAT invocation's own drain-gate never fires, and
    /// whatever it re-stashes into `deferredExternalChange` is left pending rather than chained here.
    /// It becomes reachable again only from a LATER, independent top-level bracket.
    private func endTransaction() {
        activeTransactionDepth -= 1
        // Task R11 (cluster 17) — keep `isInsideAnyTransaction` synced to the counter's CURRENT value
        // at every point it changes in this method, not just when it reaches 0. FIX ROUND 1 (measured
        // wrong, corrected in this same task): an earlier draft set the flag `false` only once, right
        // here, on the theory that this is always the "outermost bracket closing" — true for the
        // decrement above, but NOT for the drain's own manual `activeTransactionDepth` restore three
        // lines down, which is a THIRD mutation site this flag must track (the drain bumps the
        // counter back to a NON-ZERO in-progress reading via `depthBeforeDrain`/manual `+= 1` — not
        // through `withTransaction`/`endTransaction` — so nothing else would reset the flag once the
        // NESTED `synchronizeAfterExternalChange(change)` call's own `endTransaction()` sets it `true`
        // at depth 1 and returns without reaching this line again, per that call's own doc comment
        // below). A stuck `true` here silently disabled EVERY later, independent `setSelection` call
        // (its own reentrancy guard reads this flag) — measured directly:
        // `IDBackendReentrancyTests.test_aChangeReStashedDuringTheOneDrainThisTransactionPerforms_isLeftPendingNotChainedHere`'s
        // final assertion read `old + 106` (the drain of the third, still-pending change never ran)
        // instead of `old + 206`, because the LATER `setSelection` call's `guard !isInsideAnyTransaction
        // else { return }` bailed before ever reaching `withTransaction` — which is also where
        // `endTransaction()`'s own drain lives. Fixed by re-deriving the flag from the counter at
        // EVERY line that changes it, including both drain-block lines below.
        isInsideAnyTransaction = activeTransactionDepth > 0
        guard activeTransactionDepth == 0 else { return }
        if let change = deferredExternalChange {
            deferredExternalChange = nil
            let depthBeforeDrain = activeTransactionDepth
            activeTransactionDepth += 1
            isInsideAnyTransaction = activeTransactionDepth > 0
            synchronizeAfterExternalChange(change)
            activeTransactionDepth = depthBeforeDrain
            isInsideAnyTransaction = activeTransactionDepth > 0
        }
        if detachRequested {
            detachRequested = false
            detach()
        }
    }

    /// Task R9 (cluster 6, Step 3) — the ONE chokepoint every bracket this backend owns goes
    /// through, mirroring `LegacyRichTextInputBackend+Attachment.swift`'s `withTransaction(_:)`
    /// exactly: bump `activeTransactionDepth` BEFORE running `body`, call `endTransaction()` AFTER —
    /// both in the SAME stack frame, so a caller cannot bump the counter without this method also
    /// decrementing it (a `return` inside `body` only exits the closure, never skips the trailing
    /// `endTransaction()` call). `insertText(_:)` and `synchronizeAfterExternalChange(_:)`'s real
    /// branch wrap their whole `isMutating = true … isMutating = false` span in a call to this
    /// method (their own `isMutating = true` sits just OUTSIDE the closure, `isMutating = false` as
    /// the closure's own last statement, preserving the exact pre-R9 ordering: `isMutating` must be
    /// `false` before `endTransaction()`'s drain can re-enter `synchronizeAfterExternalChange`
    /// successfully); `setSelection(_:reason:)`'s coalescing-flush `didSet` and its own final
    /// publish route through it too, wrapping only the publish (it never touches `isMutating`).
    /// **This routing is not merely tidiness — it is what
    /// `InputBackendSourceBoundaryTests.test_activeTransactionDepthMutatedOnlyInSanctionedFunctions_R12`
    /// (Core) requires:** that rule scans every file under `InputBackend/` and fails if
    /// `activeTransactionDepth` is mentioned anywhere outside this method's/`endTransaction()`'s own
    /// body (plus the field's declaration line) — a bare `activeTransactionDepth += 1` written
    /// directly in `insertText(_:)`, as an earlier draft of this fix did, is flagged as an
    /// unsanctioned mutation site even though it is correct, because the rule's sanctioned-signature
    /// list is fixed and does not know about a fourth call site.
    private func withTransaction(_ body: () -> Void) {
        activeTransactionDepth += 1
        isInsideAnyTransaction = true
        body()
        endTransaction()
    }
    // `deleteBackward()` (Family 5, Task C8) now lives in `+KeyInput.swift`, the one member of
    // this MARK group real enough to need its own file — see that file's doc comment.

    // MARK: - `RichTextInputResponderBackend`
    //
    // `canBecomeFirstResponder`/`canResignFirstResponder`/`hostWillBecomeFirstResponder()`/
    // `hostDidBecomeFirstResponder()`/`hostDidFailToBecomeFirstResponder()`/
    // `hostWillResignFirstResponder()`/`hostDidResignFirstResponder()`/
    // `hostDidFailToResignFirstResponder()`/`hostWillMove(toWindow:)` — Task C11 (Family 8,
    // responder lifecycle) — moved OUT of this file into `+Responder.swift`, alongside Family 7's
    // members from the same file (Task C10): real enough now to need their own file.
    /// Task R12 (cluster 13) — mirrors `LegacyRichTextInputBackend.editPolicyDidChange()`
    /// (`+Responder.swift`) byte-for-byte: dismiss any open edit menu when this is called while the
    /// CURRENT policy is not editable, without detaching or otherwise disturbing the backend. The
    /// Legacy header's own reasoning applies unchanged here — this is a genuinely NEW call path (the
    /// canvas's `editPolicy` `didSet` calls `inputBackend.editPolicyDidChange()` unconditionally for
    /// BOTH backends), silent when detached (matching this backend's own convention for a
    /// responder-lifecycle entry point arriving with no host, e.g. `hostWillBecomeFirstResponder()`
    /// two members up), and — since nothing production-side ever sets `canvas.editPolicy` off its
    /// default `.legacyUnrestricted` — dormant in production today exactly like the Legacy copy.
    /// `BackendEditPolicyTests.test_editPolicyDidChangeToNotEditable_dismissesTheEditMenu_andKeepsTheBackendAttached`
    /// is the shared pin (both backends).
    func editPolicyDidChange() {
        guard isAttached, let host else { return }
        guard !host.lifecycleClient.editPolicy.isEditable else { return }
        host.presentationClient.dismissEditMenu(reason: .policyChanged)
    }
    /// TASK F4 — was an empty body, mirroring Legacy's own deliberately-empty one. For Legacy that
    /// is correct (the canvas IS the object UIKit reads traits from, and its `didSet` already calls
    /// `reloadInputViews()`); for THIS backend it silently dropped the only notification that could
    /// keep the private input controller's traits in step with the host's. See
    /// `synchronizeTextInputTraits()` for the full account.
    func textInputTraitsDidChange() {
        guard isAttached else { return }
        synchronizeTextInputTraits()
    }

    /// Pushes the host canvas's `UITextInputTraits` onto the PRIVATE input controller's own traits
    /// object — the mechanism this port was missing outright.
    ///
    /// **This is not a reconstruction.** The upstream host does exactly this and has always done it:
    /// `IDBlockTextView.id_syncTextInputTraits` → `IDPrivateSynchronizeTextInputTraits(inputController,
    /// self)`, called once at construction and again from every single trait setter
    /// (`~/Documents/InputDec/TextView/IDBlockTextView.m`,
    /// `~/Documents/InputDec/PrivateUIKit/IDPrivateUIKit.m`). The carve that produced this repo's
    /// vendored snapshot kept the kernel and dropped the host, and this call went with it.
    ///
    /// **The measurement that makes it load-bearing** (recorded so nobody re-derives it): on an
    /// attached `.inputDec` canvas, `kernelInput.textInputTraits` — i.e.
    /// `-[UITextInputController _textInputTraits]`, the vendored manifest's own
    /// `typingAttributes.controllerTraits` row — answered `autocorrectionType = 0`,
    /// `spellCheckingType = 0`, `inlinePredictionType = 0`, identical to
    /// `+[UITextInputTraits defaultTextInputTraits]`, while the canvas itself answered `.yes`/`.yes`.
    /// Under `.legacy` there is no second traits object at all, which is why the flag is the only
    /// arm that loses autocorrection.
    ///
    /// Guarded by `TGRichTextInputDecPerform` because `kernelInput.textInputTraits` reaches
    /// `activeController`, which raises on any call after `detach()` (`IDBackendCallGuardTests`
    /// enforces the guard on every `kernelInput.` access regardless). A nil traits object — the
    /// kernel's own answer when the `typingAttributes` capability was not validated — is a silent
    /// no-op on the ObjC side, not a failure: the fallback is exactly today's behaviour.
    func synchronizeTextInputTraits() {
        guard let source = host?.hostInputView as? UITextInputTraits else { return }
        var error: NSError?
        TGRichTextInputDecPerform({
            TGRichTextInputDecSynchronizeTextInputTraits(self.kernelInput?.id_textInputTraits, source)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// **TASK F2 — this answered `false`, and that single word is why the keyboard never appeared.**
    ///
    /// The name reads as a Writing-Tools-only hint, and the stub rule (d) in this class's own header
    /// ("answer the member's documented absent value") made `false` look like the conservative
    /// choice for a capability this backend does not implement. It is not a hint. The canvas routes
    /// it to the UIKit witness `DocumentCanvasView.isEditable` (`+UITextInput.swift`, the D3 rename),
    /// and `-isEditable` is what UIKit asks a `UITextInput`-conforming first responder to decide
    /// whether that responder needs a keyboard at all.
    ///
    /// Measured, not inferred (`IDKeyboardActivationTests`, which calibrates the reading against two
    /// real `UITextView`s in the same process):
    ///
    /// | responder                      | `isEditable` | `_requiresKeyboardWhenFirstResponder` |
    /// | ---                            | ---          | ---                                   |
    /// | `UITextView`, `isEditable=true`| `true`       | `true`                                |
    /// | `UITextView`, `isEditable=false`| `false`     | `false`                               |
    /// | Legacy canvas                  | `true`       | `true`                                |
    /// | InputDec canvas (before F2)    | `false`      | `false`                               |
    ///
    /// A read-only `UITextView` is EXACTLY the user's symptom: it takes first responder, it shows a
    /// caret and selection, and no keyboard is raised. The ID canvas reproduced that state precisely.
    ///
    /// `true`, unconditionally, is not a choice — it is Legacy parity.
    /// `LegacyRichTextInputBackend.isEditableForWritingTools` (`+Responder.swift:236`) is the literal
    /// `true`, itself a byte-for-byte port of the pre-seam canvas witness, and
    /// `InputBackendSourceBoundaryTests` pins that shape as `.literal("true")`. Deliberately NOT
    /// gated on `isAttached`/`host` (every other Bool getter on this backend has a detached fallback):
    /// a detached Legacy backend still answers `true`, a `guard` here would answer `false`, and
    /// `false` is the value that removes the keyboard. Deliberately NOT gated on
    /// `RichTextInputEditPolicy.allowsWritingTools`/`.isEditable` either — Legacy's own doc comment
    /// records that gate as an open decision belonging to whoever makes the policy live, and adding
    /// it here would make the two backends diverge on the very member that just cost a keyboard.
    var isEditableForWritingTools: Bool { true }
    // `canPerformCommand(_:sender:)` / `performCommand(_:sender:)` — Task C10 (Family 7, responder
    // commands and clipboard) — moved OUT of this file into `+Responder.swift`, mirroring Task C8's
    // move of `deleteBackward()` into `+KeyInput.swift`: real enough now to need their own file.
    /// Task D4b — found unwired: this was a bare `{ nil }`, unconditionally, regardless of
    /// attachment. That is a DIFFERENT thing from the "nil is the safe direction" convention
    /// `canBecomeFirstResponder`/`canResignFirstResponder` (`+Responder.swift`) use — those answer a
    /// real value while attached and only fall back to the safe direction once detached; this
    /// witness fell back to the safe direction UNCONDITIONALLY and so never answered the real value
    /// at all. `DocumentCanvasView.undoManager` (`override final var undoManager: UndoManager? {
    /// inputBackend.undoManager }`, this file's sibling) routes straight through this property, so
    /// EVERY ID-backed canvas answered "no undo manager" to `UIResponder`'s own undo affordances
    /// (hardware ⌘Z/⌘⇧Z, shake-to-undo, the Edit-menu Undo/Redo) and to any external reader of
    /// `host.input.undoManager` — including a genuinely registered step on `effectiveUndoManager`
    /// (confirmed directly: `applyCharacterToggle`'s `editing { }` call unconditionally registers one
    /// for a `.none`-coalescing edit, `DocumentCanvasView+Editing.swift`, and it does — `canUndo` on
    /// `canvas.effectiveUndoManager` is `true` right after a range-format toggle — while this
    /// witness's caller (`canvas.undoManager`) answered `nil`, so `canUndo` there read `false`).
    /// `performCommand(.undo/.redo, sender:)` two members below already reaches the CORRECT manager
    /// this way (`host.commandClient.undoManager`, i.e. `TelegramCommandInputClient.undoManager` →
    /// `canvas.effectiveUndoManager`) — this witness had simply never been wired to the same client,
    /// despite the manager it needed already being one hop away. One-line fix, precedented twice
    /// over: the value already exists and is already reached this way from the sibling command path.
    var undoManager: UndoManager? {
        guard isAttached, let host else { return nil }
        return host.commandClient.undoManager
    }

    // MARK: - `RichTextInputInteractionBackend`

    func installInteractions() {}
    func removeInteractions() {}
    func viewportDidChange() {}
    func layoutDidChange(generation: UInt64) {}
    // `beginFloatingCursor(at:)`/`updateFloatingCursor(at:)`/`endFloatingCursor()` — Task C13
    // (Family 10, floating cursor) — moved OUT of this file into `+Interaction.swift`, alongside
    // Family 9's members from the same file (Task C12): real enough now to need their own file.
    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {}

    // MARK: - `RichTextInputCheckingBackend`
    //
    // TASK F4 — BOTH WERE EMPTY BODIES, and that is the whole reason the flag showed no spelling
    // underlines. Measured, not argued: with `.legacy` a `becomeFirstResponder()` leaves
    // `DocumentCanvasView.nativeChecker` NON-nil; with `.inputDec` it was nil, every time. The
    // canvas's only two install sites are `legacyFinishBecomingFirstResponder()` and the
    // `isSpellCheckingEnabled` `didSet`'s enable branch, and BOTH go through
    // `inputBackend.installCheckingIfNeeded()` — so an empty body here means the
    // `NativeTextChecker` (the private checking controller that delivers every `.spelling`/
    // `.grammar`/`.correction` flag `spellResults` renders) is never constructed at all, and
    // `nativeCheckOnSelectionChange()`'s own `let checker = nativeChecker` guard then fails on
    // every selection change forever.
    //
    // The class's stub rule (a) — "a `Void` requirement with no closure parameter is a no-op" —
    // cited `RichTextInputCheckingBackend`'s own sanction for a conformer "with no checking of its
    // own". That sanction does not apply here: this backend's canvas IS a `DocumentCanvasView`,
    // it owns a real `NativeTextChecker`, and Telegram — not the kernel — renders the underlines.
    // So the honest answer is Legacy's, verbatim.
    //
    // Reached through `host.hostInputView as? DocumentCanvasView` rather than Legacy's
    // `legacyCanvas`: that accessor is confined to `LegacyRichTextInputBackend` by source-boundary
    // rule R9, and this exact cast is the established ID-side spelling for the same reach — see
    // `IDTextEditorBackendClientBridge.setNativeContinuousSpellCheckingEnabled(_:)`, which already
    // writes `canvas.isSpellCheckingEnabled` this way.
    //
    // Idempotence stays the callee's, exactly as Legacy documents: `installNativeCheckingIfNeeded()`
    // guards on `nativeChecker == nil`, and `nativeCheckOnSelectionChange()` owns the
    // `isSpellCheckingEnabled` / `nativeChecker != nil` / coalescing guards. Adding a second copy
    // of any of them here would be a second, independently-drifting condition across the seam.
    func installCheckingIfNeeded() {
        guard isAttached else { return }
        (host?.hostInputView as? DocumentCanvasView)?.installNativeCheckingIfNeeded()
    }

    func checkOnSelectionChange() {
        guard isAttached else { return }
        (host?.hostInputView as? DocumentCanvasView)?.nativeCheckOnSelectionChange()
    }

    /// TASK H2 — THE DELIVERY DEFECT. The canvas's three `@objc` checking-client selectors resolved
    /// their incoming `UITextRange` through `LegacyTextIdentity` unconditionally, and under this
    /// backend the private checking controller mints its ranges through the canvas's `UITextInput`
    /// witnesses — which route here and answer `TGRichTextInputDecRange`. So the downcast ALWAYS
    /// failed, `annotatedSubstringForRange:` answered nil, the controller stopped before it ever
    /// reached `replaceRange:withAnnotatedString:`, and nothing was ever flagged. Measured with a
    /// swizzle over the three selectors while typing `"mispelled "`:
    ///
    /// ```
    /// INPUTDEC  annotatedSubstring range<TGRichTextInputDecRange> legacy=nil kernel(1,11) -> nil
    ///           FLAGGED=false
    /// LEGACY    annotatedSubstring range<LegacyTextRange> legacy(1,11) -> "mispelled "
    ///           replaceRange legacy(1,10) attrs=[{0,9} NSTextAlternativesDisplayStyle=2]
    ///           FLAGGED=true
    /// ```
    ///
    /// `resolvedGlobalRange(of:)` (`+Geometry.swift`) is reused rather than a second resolver being
    /// written: it already accepts BOTH identity shapes — this backend's `TGRichTextInputDecPosition`
    /// and the canvas's `LegacyTextIdentity` — which is required here and not optional, because
    /// `nativeTextRange(forGlobalLocation:length:)` still mints the canvas shape under every backend
    /// (F4's finding), so a single checking session hands us both. A genuinely foreign `UITextRange`
    /// still answers `nil` and the delivery still degrades, exactly as before.
    ///
    /// No `isAttached` guard and no `TGRichTextInputDecPerform` wrapper, deliberately: this member
    /// touches neither the kernel nor the host — it is two downcasts over the argument.
    func globalRange(ofCheckingRange range: UITextRange) -> (from: Int, to: Int)? {
        resolvedGlobalRange(of: range)
    }

    // MARK: - `RichTextInputBackend`'s own remaining requirements (24 of its 30; the other 6 —
    // `state`/`isAttached`/`attach(to:)`/`detach()`/`synchronizeAfterExternalChange(_:)`/
    // `setSelection(_:reason:)` — are given above, verbatim from the task brief).

    var canonicalSelection: RichTextCanonicalSelection { state.selection }
    var canonicalSelectionAnchorOffset: Int { state.selection.anchor.utf16Offset }
    var canonicalSelectionHeadOffset: Int { state.selection.head.utf16Offset }

    /// Task R9 (cluster 7) — promoted from the two empty no-op stubs to real RAW, NON-PUBLISHING
    /// single-endpoint writes, mirroring `LegacyRichTextInputBackend.setCanonicalAnchor`/
    /// `setCanonicalHead` (`LegacyRichTextInputBackend.swift`) at the granularity this backend has
    /// reached: Legacy writes its own second store, `canonicalSelectionStorage`, directly; this
    /// backend has no second store — `state` is the ONE canonical store (`canonicalSelection`
    /// above reads it directly) — so the write lands there instead. Same contract as Legacy's pair
    /// in every other respect: no `isAttached` guard, no edit-policy gate, no publish — these are
    /// the raw seats `DocumentCanvasView.setSelectionForTesting(anchor:head:)` calls (that method's
    /// own doc comment: "the same two members the anchor/head forwarder SETTERS call"), the shared,
    /// non-publishing test-only selection seam backing ~480 converted test call sites
    /// package-wide. Being no-ops here made every one of those call sites silently see whatever
    /// selection `attach(to:)` last seeded, for BOTH backends sharing a suite — this is the fix.
    /// `.downstream` always, exactly like Legacy's pair — this seam carries no affinity concept on
    /// either backend (D6: `.upstream` is constructed nowhere outside a comment).
    func setCanonicalAnchor(_ utf16Offset: Int) {
        state = RichTextInputStateSnapshot(
            documentRevision: state.documentRevision,
            selection: RichTextCanonicalSelection(anchor: .downstream(utf16Offset), head: state.selection.head),
            markedRange: state.markedRange,
            isComposing: state.isComposing)
    }

    func setCanonicalHead(_ utf16Offset: Int) {
        state = RichTextInputStateSnapshot(
            documentRevision: state.documentRevision,
            selection: RichTextCanonicalSelection(anchor: state.selection.anchor, head: .downstream(utf16Offset)),
            markedRange: state.markedRange,
            isComposing: state.isComposing)
    }

    /// Task C9 (Family 6) — promoted from the always-nil stub to a real read of `state.markedRange`,
    /// the single canonical store `adoptAndEmitDidChange(_:RichTextInputMutationResult)` (Family 4,
    /// Task C7) already adopts a composing-mutation's `markedRange` into and
    /// `commitMarkedTextStateIfComposing()`/`synchronizeAfterExternalChange(_:)` (both this task)
    /// clear. Left as a stub, `isComposing` immediately below (spelled from THIS member, per the
    /// protocol's own documented rule) could never read `true` — exactly the "plausible fake" this
    /// file's own header warns against, and the specific gap `test_setMarkedTextPublishesIsComposing`
    /// exists to catch.
    var markedRange: NSRange? { state.markedRange }
    var isComposingPrediction: Bool { false }
    /// "The published snapshot's `isComposing` field must agree with this" — spelled from
    /// `markedRange`, per the protocol's own documented rule, rather than a second independent
    /// constant that could drift from it.
    var isComposing: Bool { markedRange != nil }
    /// Task D4f — REAL storage, promoted from the hardcoded `nil` getter its writer's own doc
    /// comment below used to justify ("a no-op writer paired with an always-nil reader is
    /// self-consistent"). That was true only while nothing on this backend ever reached
    /// `DocumentCanvasView.commitMarkedText()`, which is the sole reader — and the sole registrar of
    /// a composition's undo step. `unmarkText()` (`+TextBackend.swift`) now routes a real
    /// `.unmarkText` mutation through the document client, so this store has a consumer and an
    /// always-nil getter would silently mean "a committed composition registers no undo".
    private var compositionSnapshotStorage: RichTextCompositionSnapshot?
    var compositionSnapshot: RichTextCompositionSnapshot? { compositionSnapshotStorage }
    /// Task D3e — promoted from the always-no-op stub to a real, RAW, NON-PUBLISHING write into
    /// `state.markedRange`/`.isComposing`, mirroring `setCanonicalAnchor`/`setCanonicalHead` just
    /// above (Task R9's identical promotion, same file) and `LegacyRichTextInputBackend`'s own
    /// implementation (`+MarkedText` section) — the protocol's own doc comment names this member
    /// "the marked-text analogue of the D33 `setCanonicalAnchor`/`setCanonicalHead` pair," so a
    /// no-op here was the same "plausible fake" shape Task R9 already fixed for its two siblings.
    ///
    /// **Why this stayed a no-op and looked harmless: `markedRange`'s own doc comment (just above)
    /// claims `adoptAndEmitDidChange(_:RichTextInputMutationResult)` "already adopts a
    /// composing-mutation's markedRange into state, for free" — true for the FINAL adoption, but
    /// that claim skipped one hop.** `adoptAndEmitDidChange` adopts whatever
    /// `RichTextInputMutationResult.markedRange` it is handed, and for a `.setMarkedText` mutation
    /// that value is computed by `DocumentCanvasView.legacyApplyMutation`'s own `.setMarkedText`
    /// case — which calls `legacySetMarkedText(...)` (the SAME canvas body Legacy's witness also
    /// uses) and THEN reads `canvas.markedRange` back out as the mutation's `affectedRange`/
    /// `markedRange`. `legacySetMarkedText` updates that value by calling exactly this door,
    /// `inputBackend.setCompositionMarkedRange(...)` — which, left as a no-op, meant the read-back
    /// saw whatever `state.markedRange` already was BEFORE this call (nil, for a first
    /// composition), and `adoptAndEmitDidChange` then adopted that same stale nil right back into
    /// `state` — a closed loop that never once wrote the real value. Confirmed by direct
    /// instrumentation (temporary `print` in `adoptAndEmitDidChange`, reverted before commit):
    /// `result.markedRange == nil` even though `result.disposition == .applied` and
    /// `result.contentChanged == true` — the composing text WAS inserted, only the marked-range
    /// bookkeeping never took. This is what `test_unmarkTextClearsTheMarkedRange`'s
    /// `XCTAssertNotNil(h.markedRange, "composition established before the commit")` measured.
    /// Collapsing an empty/nil range to `nil` mirrors Legacy's own convention (`isComposing` must
    /// never read `true` while composing nothing) — see `LegacyRichTextInputBackend
    /// .setCompositionMarkedRange`'s identical guard.
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        let normalized: NSRange? = (range?.length ?? 0) > 0 ? range : nil
        state = RichTextInputStateSnapshot(
            documentRevision: state.documentRevision,
            selection: state.selection,
            markedRange: normalized,
            isComposing: normalized != nil)
    }
    /// Task D4f — a REAL write, matching `LegacyRichTextInputBackend.setCompositionSnapshot(_:)`
    /// exactly (a bare store; RAW and NON-PUBLISHING, per the protocol contract). Task D3e left this
    /// a no-op and said so honestly: "adding a store here without a documented consumer would be
    /// unmandated scope creep. Left for whichever task wires undo coalescing for this backend."
    /// This is that task — see `compositionSnapshot` above and `unmarkText()`
    /// (`+TextBackend.swift`) for the consumer that now exists.
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        compositionSnapshotStorage = snapshot
    }
    func clearCompositionState() {}

    /// Task C6: promoted from the "always false" stub to a REAL stored property.
    /// `selectedTextRange`'s setter (above) now consults it, so an always-false getter would make
    /// that guard permanently inert — the exact "plausible fake" this file's header warns against.
    /// `private(set)`: `setFloatingCursorActive(_:)` below is the ONE writer, matching the
    /// protocol's "RAW, NON-PUBLISHING floating-cursor write" contract (`RichTextInputBackend.swift`).
    private(set) var floatingCursorActive: Bool = false
    var floatingCursorPoint: CGPoint { .zero }
    /// "Zero means 'not auto-scrolling' ... whenever the canvas holds no display link" — the
    /// protocol's own documented absent value, not a guess.
    var floatingScrollVelocity: CGFloat { 0 }
    /// Raw seat, no publish, no gate — same contract as the D33 `setCanonicalAnchor`/
    /// `setCanonicalHead` pair (`RichTextInputBackend.swift`'s own doc comment on this member).
    func setFloatingCursorActive(_ active: Bool) { floatingCursorActive = active }
    func setFloatingCursorPoint(_ point: CGPoint) {}
    func setFloatingScrollVelocity(_ velocity: CGFloat) {}

    /// Task R9 (cluster 6, Step 1) — promoted from a plain, unguarded stored `Bool` (setting it
    /// `true` did nothing) to a real coalescing latch, mirroring
    /// `LegacyRichTextInputBackend.suppressesSelectionNotifications`'s own `didSet` exactly: while
    /// `true`, `setSelection(_:reason:)` still writes `state` but defers its publish
    /// (`pendingCoalescedSelectionPublish = true`, below); flipping this back to `false` flushes
    /// exactly ONE settled snapshot, reflecting the LAST selection set during the suppressed run.
    /// Guarded on `isAttached` for the same reason Legacy's is: a latch still outstanding at
    /// `detach()` time (below) must be dropped silently, not flushed to a host this backend has
    /// just declared closed to new operations.
    var suppressesSelectionNotifications: Bool = false {
        didSet {
            guard oldValue != suppressesSelectionNotifications else { return }
            guard !suppressesSelectionNotifications, pendingCoalescedSelectionPublish else { return }
            guard isAttached else {
                pendingCoalescedSelectionPublish = false
                return
            }
            pendingCoalescedSelectionPublish = false
            withTransaction {
                publishState(reason: .selection)
            }
        }
    }

    /// Set by `setSelection(_:reason:)` when a publish was deferred because
    /// `suppressesSelectionNotifications` was `true` at the time; consumed (and cleared) by the
    /// `didSet` above once the flag clears. Mirrors
    /// `LegacyRichTextInputBackend.pendingCoalescedSelectionPublish`.
    var pendingCoalescedSelectionPublish: Bool = false

    func notifyingContentAndSelectionChange(_ body: () -> Void) { body() }
    func notifyingSelectionChange(_ body: () -> Void) { body() }
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) { body() }
    func notifyingContentChange(_ body: () -> Void) { body() }
    func notifyCoalescedSelectionResync() {}
}

/// R1 — the stateless fallback `IDTextEditorBackend.tokenizer` vends for the narrow "no canvas
/// attached" window only, now that Task R12 (cluster 12) wires the real, attached-window tokenizer
/// via `DocumentTokenizer` (see `tokenizer`'s own doc comment). Mirrors
/// `LegacyRichTextInputBackend+TextReads.swift`'s private `NoOpTextInputTokenizer` verbatim — not
/// reused directly, since that type is `private` to a different file — every member answers with
/// the "nothing to report" value UIKit already tolerates from any tokenizer.
private final class IDNoOpTextInputTokenizer: NSObject, UITextInputTokenizer {
    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextRange? { nil }
    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextPosition? { nil }
    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
}
#endif
