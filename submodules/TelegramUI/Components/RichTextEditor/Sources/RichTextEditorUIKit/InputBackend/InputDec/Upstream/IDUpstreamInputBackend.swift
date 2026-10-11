#if canImport(UIKit)
import UIKit
import RichTextInputDecObjC
import RichTextInputDecUpstream

/// PHASE 2 OF THE PORT — the thin adapter that lets Telegram drive **upstream InputDec's real host**
/// (`IDBlockTextView`, `Sources/RichTextInputDecUpstream/`) through Telegram's own
/// `RichTextInputBackend` family.
///
/// # What this type is, and what it deliberately is not
///
/// It is a **translator**. Every answer it gives comes out of the engine; it computes none of them.
/// That is not a style preference — it is the diagnosis of the programme that preceded this port.
/// The reconstruction it replaces (`../IDTextEditorBackend.swift`, 2,594 lines) corresponded to only
/// 16 of upstream's 80 host obligations, and ten of its call sites compiled cleanly while doing
/// nothing or the wrong thing: an empty method body, an `@optional` ObjC member Swift never
/// implemented, a constant `false`/`nil` return, a cast that could never succeed. **If a member of
/// this type ever starts deriving an answer instead of forwarding one, that is the defect
/// reasserting itself.**
///
/// It implements a subset of the backend-side requirements and consumes **none** of the client-side
/// ones, because at this stage the InputDec host still owns its own drawing, selection chrome and
/// geometry. Everything not implemented lives in `IDUpstreamInputBackend+Unwitnessed.swift`, each
/// one reporting a contract violation rather than returning a plausible value.
///
///   * Phase 2's "instantiate and accept typing" subset (`task-PORT-PLAN.md` §3.2) lives in this
///     file.
///   * Phase 3's and phase 3b's live in `IDUpstreamInputBackend+Responder.swift`, because every one
///     of them turned out to depend on a single question the port had not answered: **which view
///     holds the first-responder role, Telegram's host or the engine?** That file's header is the
///     answer, the measurements behind it, and the three wirings that were built and found
///     defective. Read it before touching anything responder-shaped.
///
/// **THE COUNTS ARE DERIVED, IN ONE PLACE** (phase 3 review, Minor 7): they used to be restated in
/// this header, in `+Unwitnessed.swift`'s header and table, in the runtime message every
/// unimplemented member emits, and inside a test's NAME.
/// `InputDecUpstreamAdapterBoundaryTests.test_everyDeclaredRequirementIsEitherImplementedOrLoud`
/// parses the protocol declarations and both halves of this adapter and asserts the partition, so
/// the numbers live there and nowhere else.
///
/// # THE IDENTITY STORY — read this before touching any member that takes or returns a position
///
/// The single most recurring defect of the preceding programme — three separate user-visible
/// symptoms — was Telegram minting `LegacyTextPosition`/`LegacyTextRange` where the engine expects
/// its own family. The rule here is absolute and mechanical:
///
///   * **The engine owns the identity family.** `IDBlockTextView` vends `IDRichTextPosition` and
///     `IDRichTextRange`; each carries an `IDRichTextAnchor` (block `NSUUID` + local offset + bias)
///     and the `documentRevision` it was minted at.
///   * **This adapter mints neither.** Search this file: there is no `IDRichTextPosition(` and no
///     `LegacyTextPosition(`. Every `UITextPosition`/`UITextRange` that leaves this type came out of
///     the engine, and every one that enters it is handed straight back to the engine unchanged.
///   * **A wrong type is a LOUD failure, never a silent nil.** `requireEnginePosition(_:member:)` /
///     `requireEngineRange(_:member:)` check the concrete class before forwarding, and report the
///     class they actually received. That check is not this adapter's invention — it is
///     `IDRichTextLayoutController.id_positionWithValidIdentity:stage:`'s own
///     `isMemberOfClass:IDRichTextPosition.class` rule, mirrored on our side of the boundary so the
///     failure arrives as a named diagnostic instead of an `IDRichRaise` NSException that Swift
///     cannot catch.
///   * **The canonical UTF-16 axis is the ENGINE's axis.** `RichTextInputPosition.utf16Offset` on
///     `canonicalSelection` / `setSelection(_:reason:)` / `state` is an offset on
///     `IDCanonicalTextProjection` — the dense projection with exactly one `"\n"` per block
///     boundary — and it is obtained **only** by asking the engine
///     (`offset(from: beginningOfDocument, to:)` / `position(from: beginningOfDocument, offset:)`).
///     This adapter performs no offset arithmetic, holds no offset cache, and never consults a
///     Telegram `Document`. In this phase the engine's document is the only document, so the two
///     axes are the same axis; when Telegram's block layer is attached (phase 8) the mapping becomes
///     a real conversion and it will live at that seam, not here.
///
/// # Why every crossing goes through `TGRichTextInputDecPerform`
///
/// The engine raises `NSException` on a contract violation — `IDRichRaise` on a foreign position, a
/// stale anchor, an out-of-document offset — and the vendored kernel behind it raises on any call to
/// `activeController` after detach. Swift cannot catch an `NSException`, so an unwrapped call is a
/// process abort. `TGRichTextInputDecPerform` / `…ReturningObject` are this repo's only sanctioned
/// crossing point; they convert a raise into an `NSError`, which becomes a reported contract
/// violation here.
///
/// **The claim is "every call this adapter makes", and it is worth stating what it cannot cover.**
/// UIKit drives the engine directly and constantly — `layoutSubviews`, `didMoveToWindow`, responder
/// transitions, gesture recognisers, the keyboard's own `UITextInput` calls — and none of those
/// frames belongs to us, so none can be wrapped. What IS wrapped is every crossing originating here,
/// including the view-hierarchy calls in `attach(to:)`/`detach()`, which reach `didMoveToWindow`
/// (`IDBlockTextView.m:484`) and therefore engine code.
///
/// # Attachment shape
///
/// One `IDBlockTextView` per attachment, built in `attach(to:)` and destroyed in `detach()` — the
/// same per-attachment lifetime discipline the legacy conformer applies to its tokenizer. The engine
/// view is inserted into `host.hostInputView` and draws itself; nothing routes through
/// `DocumentCanvasView`, which is the explicit prohibition of §3.2 ("What phase 1 must NOT do").
///
/// # Availability
///
/// `@available(iOS 18.4, *)` matches the plan's decision 2 (the ID backend is selected on an iOS 17
/// floor) and the reconstruction it replaces. The engine itself compiles at this package's iOS 13
/// floor but uses iOS 17/18 API unguarded.
@MainActor
@available(iOS 18.4, *)
final class IDUpstreamInputBackend: RichTextInputBackend {

    // MARK: - Construction

    /// The document the engine is built with at `attach(to:)`.
    ///
    /// **This is an initializer parameter and not a read from the host, deliberately.** The initial
    /// document would come from `host.documentClient` — one of the 54 client-side requirements this
    /// phase consumes NONE of. Reading it would be inventing a capability the phase does not have;
    /// taking it from the caller states plainly that the caller supplies it.
    private let initialAttributedBlocks: [NSAttributedString]

    /// The edit policy the engine is configured with at `attach(to:)`.
    ///
    /// **An initializer parameter for the same reason `initialAttributedBlocks` is one.** A policy
    /// properly reaches a backend through `host.lifecycleClient.editPolicy` — one of the 54
    /// client-side requirements this phase consumes NONE of. An earlier draft simply wrote
    /// `isEditable = true` at attach, which is a Telegram-side answer to a question Telegram was not
    /// asked; taking it from the caller states plainly who decided. `IDBlockTextView` can honour
    /// `isEditable` and `isSelectable`; the other four fields have no counterpart on its public
    /// surface, so `attach(to:)` reports by name if a caller asks for one of them.
    private let initialEditPolicy: RichTextInputEditPolicy

    /// The engine host for the current attachment. `nil` exactly when detached.
    ///
    /// **This is the single source of attachment truth** — see `isAttached`.
    private var engine: IDBlockTextView?

    /// Retained WEAKLY, per the `RichTextInputHost` contract.
    private weak var attachedHost: (any RichTextInputHost)?

    /// DERIVED, never stored. An earlier draft kept a `Bool` alongside `engine` and `requireEngine`
    /// defensively checked both — which is precisely "a pair a backend can half-implement", the shape
    /// `+Unwitnessed.swift`'s own `selectionPairReason` warns about and that this repo has paid for
    /// twice already (`enableUnreadAlignment`, `settledContentOffsets`). Two facts that must agree
    /// cannot disagree if there is only one of them.
    var isAttached: Bool { engine != nil }

    /// Every contract violation this instance has reported, in order, for tests to assert on.
    ///
    /// **Captured, not derived.** `RichTextInputContractViolation.reporter` is the sanctioned
    /// observation channel and is still used (it is what makes an unwitnessed member a loud test
    /// failure), but a test that asserts on a live re-read of a derived property has produced false
    /// green in this package repeatedly. This array records what actually happened, at the moment it
    /// happened.
    private(set) var recordedViolations: [String] = []

    init(attributedBlocks: [NSAttributedString],
         editPolicy: RichTextInputEditPolicy = .legacyUnrestricted) {
        self.initialAttributedBlocks = attributedBlocks
        self.initialEditPolicy = editPolicy
    }

    /// **F11 — the "no `detach()` at all" case.** A backend released while still attached would leave
    /// the engine alive inside `hostInputView.subviews` with its kernel still attached, because
    /// kernel teardown is deallocation-driven (see `detach()`). Nothing in this phase forgets to
    /// detach — there is no production caller at all — but "nothing forgets" is a property of today's
    /// callers, not of this type, and the failure is silent: every member would go on correctly
    /// reporting "detached" while the kernel stayed live.
    ///
    /// `deinit` is nonisolated, so it cannot call the `@MainActor` `detach()`. It performs the one
    /// step that actually matters — dropping the engine out of the host's view hierarchy, which
    /// releases the last strong reference the adapter is responsible for — and hops to the main
    /// actor to do it, because that reference may be released on any thread.
    deinit {
        guard let view = engine else { return }
        engine = nil
        Task { @MainActor in
            view.removeFromSuperview()
        }
    }

    /// A single empty block carrying the attributes `IDBlockTextView` seeds its typing attributes
    /// from. Upstream's own tests construct hosts exactly this way
    /// (`InputDec/Tests/IDBlockTextViewTests.m:325-342`): a font and a colour on every block, because
    /// the host reads the document's default attributes at construction.
    static func emptyDocumentBlocks(
        font: UIFont = UIFont.systemFont(ofSize: 17.0),
        color: UIColor = .label
    ) -> [NSAttributedString] {
        [NSAttributedString(string: "", attributes: [.font: font, .foregroundColor: color])]
    }

    // MARK: - Reporting

    /// Records and reports. Both halves matter: the report is what fails a DEBUG build or an armed
    /// test reporter; the record is what a test can assert on afterwards.
    func reportContractViolation(_ message: String) {
        recordedViolations.append(message)
        RichTextInputContractViolation.report(message)
    }

    private func reportEngineFailure(_ error: NSError, member: String) {
        reportContractViolation(
            "IDUpstreamInputBackend.\(member): the ported engine raised — \(error.localizedDescription)")
    }

    private func reportDetached(_ member: String) {
        reportContractViolation(
            "IDUpstreamInputBackend.\(member) called while detached — there is no engine to forward to")
    }

    // MARK: - The crossing

    /// The engine for the current attachment, or `nil` (reported) when detached.
    ///
    /// **Internal, not `private`, since phase 3**: `+Responder.swift` is a sibling FILE and Swift's
    /// `private` is file-scoped, so the responder forwards could not otherwise go through the one
    /// sanctioned crossing. Widened rather than duplicated — a second copy of the detached-report
    /// prelude is a second place for the two to disagree. Nothing outside this directory can name
    /// `IDUpstreamInputBackend` at all (`InputDecUpstreamAdapterBoundaryTests` rule 4b), so the
    /// widening is invisible to the rest of the package.
    func requireEngine(_ member: String) -> IDBlockTextView? {
        guard let engine else {
            reportDetached(member)
            return nil
        }
        return engine
    }

    /// What the engine did when asked for an optional value. `perform`'s single return cannot
    /// distinguish "the engine answered nil" from "the engine raised", and one caller
    /// (`canonicalSelection`) must: it emits a second, DIFFERENT report for a genuine nil, and that
    /// report — "the engine has no selection" — is simply false on the raise path.
    ///
    /// An enum rather than a `(value:raised:)` tuple so the two facts cannot be read apart.
    private enum EngineAnswer<T> {
        case answered(T?)
        case raised
    }

    /// `perform`, for a caller that must tell a nil answer from a raise. The raise is still reported
    /// here; the caller decides only what to say ON TOP of that.
    private func performAnswering<T>(
        _ member: String,
        on view: IDBlockTextView,
        _ body: (IDBlockTextView) -> T?
    ) -> EngineAnswer<T> {
        var result: T?
        var error: NSError?
        _ = TGRichTextInputDecPerform({ result = body(view) }, &error)
        if let error {
            reportEngineFailure(error, member: member)
            return .raised
        }
        return .answered(result)
    }

    /// Runs `body` against the engine inside the NSException trampoline.
    ///
    /// Returns `fallback` if the engine raised — after reporting. It never returns `fallback`
    /// silently: the only two paths to it both report first.
    ///
    /// Internal rather than `private` for the same reason as `requireEngine(_:)` above.
    func perform<T>(
        _ member: String,
        on view: IDBlockTextView,
        default fallback: T,
        _ body: (IDBlockTextView) -> T
    ) -> T {
        var result = fallback
        var error: NSError?
        _ = TGRichTextInputDecPerform({ result = body(view) }, &error)
        if let error {
            reportEngineFailure(error, member: member)
            return fallback
        }
        return result
    }

    // MARK: - Identity checks (the engine's own rule, mirrored)

    /// `IDRichTextLayoutController.id_positionWithValidIdentity:stage:` (`IDRichTextLayoutController.m:540`)
    /// rejects anything that is not `isMemberOfClass:IDRichTextPosition.class` by raising. Checking
    /// here first turns that uncatchable raise into a named report.
    ///
    /// **`type(of:) == …self`, not `is`, and the difference is the whole point of mirroring.** Swift's
    /// `is` is `isKindOfClass:` — it accepts a subclass. The engine's own gate does not. An earlier
    /// draft used `is` while this comment claimed to mirror `isMemberOfClass:`, so a subclass would
    /// have passed OUR gate and then raised inside the engine's: the code and its claim disagreed,
    /// on the one axis (identity) whose defect surfaced three times wearing three symptoms. No such
    /// subclass exists in the port today; the point is that the check now says what it does.
    private func requireEnginePosition(_ position: UITextPosition, member: String) -> Bool {
        if type(of: position) == IDRichTextPosition.self { return true }
        reportContractViolation(
            "IDUpstreamInputBackend.\(member): a \(type(of: position)) was passed where the ported "
            + "engine mints IDRichTextPosition. Telegram must never mint identity for the engine.")
        return false
    }

    /// See `requireEnginePosition(_:member:)` for why this is `type(of:)` and not `is`.
    private func requireEngineRange(_ range: UITextRange, member: String) -> Bool {
        if type(of: range) == IDRichTextRange.self { return true }
        reportContractViolation(
            "IDUpstreamInputBackend.\(member): a \(type(of: range)) was passed where the ported "
            + "engine mints IDRichTextRange. Telegram must never mint identity for the engine.")
        return false
    }

    // MARK: - `RichTextInputBackend` — attachment

    /// Builds the engine and parents it into the host's view.
    ///
    /// The runtime-compatibility question is asked of the engine, not answered here:
    /// `IDPrivateUIKit.isCompatible` walks the 140 preflighted contracts of upstream's own manifest.
    /// Asking it BEFORE construction matters — `IDBlockTextView`'s reference construction path calls
    /// `requireCompatibleRuntime`, which raises, and a raise inside a Swift frame is a process abort
    /// even though the construction below is trampolined (the trampoline catches, but a failed
    /// construction is better reported as a thrown Swift error than as a caught exception).
    ///
    /// **The edit policy comes from the CALLER, not from a default written here.** An earlier draft
    /// wrote `isEditable = true` / `isSelectable = true` inline — a Telegram-side answer to a question
    /// Telegram was not asked, disclosed in prose but not loud. The policy is now `init`'s
    /// `editPolicy:` parameter, exactly like `initialAttributedBlocks`, because its proper source
    /// (`host.lifecycleClient.editPolicy`) is one of the 54 client-side requirements this phase
    /// consumes NONE of. `editPolicyDidChange()` stays unwitnessed (`+Unwitnessed.swift`), so a policy
    /// that CHANGES after attach is still reported.
    ///
    /// `IDBlockTextView` can honour two of the policy's six fields. The other four —
    /// `allowsRichText`, `allowsPaste`, `allowsDictation`, `allowsWritingTools` — have no counterpart
    /// on its public surface, so a caller asking for any of them is reported BY NAME, the same
    /// pattern `synchronizeAfterExternalChange(_:)` uses for the half it cannot adopt. Nothing fires
    /// under `.legacyUnrestricted`, because under it nothing was refused.
    func attach(to host: any RichTextInputHost) throws {
        guard !isAttached else { throw RichTextInputBackendAttachmentError.alreadyAttached }
        guard IDPrivateUIKit.isCompatible else {
            throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                IDPrivateUIKit.compatibilityReport)
        }

        reportEditPolicyFieldsTheEngineCannotHonour()

        let container = host.hostInputView
        let policy = initialEditPolicy
        var built: IDBlockTextView?
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            let view = IDBlockTextView(frame: container.bounds,
                                       attributedBlocks: self.initialAttributedBlocks)
            view.isEditable = policy.isEditable
            view.isSelectable = policy.isSelectable
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            built = view
            // F2 — INSIDE the trampoline: `addSubview` runs the engine's `didMoveToWindow`
            // (`IDBlockTextView.m:484`), so it is an engine crossing exactly as `detach()`'s mirror
            // `removeFromSuperview()` is, and the file header claims every crossing is wrapped.
            container.addSubview(view)
        }, &error)

        guard error == nil, let view = built else {
            // Atomicity: a raise after `addSubview` would leave the engine parented to a host this
            // adapter is about to disown. Nothing here can be left attached on the throw path.
            built?.removeFromSuperview()
            throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                error?.localizedDescription
                    ?? "IDBlockTextView construction produced no host and raised nothing")
        }

        self.engine = view
        self.attachedHost = host
    }

    /// The four `RichTextInputEditPolicy` fields `IDBlockTextView` has no member for. Silent when the
    /// caller asked for none of them — a report on every attach would say only "this phase is phase
    /// 2", which the caller already knows.
    private func reportEditPolicyFieldsTheEngineCannotHonour() {
        var refused: [String] = []
        if !initialEditPolicy.allowsRichText { refused.append("allowsRichText") }
        if !initialEditPolicy.allowsPaste { refused.append("allowsPaste") }
        if !initialEditPolicy.allowsDictation { refused.append("allowsDictation") }
        if !initialEditPolicy.allowsWritingTools { refused.append("allowsWritingTools") }
        guard !refused.isEmpty else { return }
        reportContractViolation(
            "IDUpstreamInputBackend.attach(to:): the edit policy restricts "
            + "\(refused.joined(separator: ", ")), and IDBlockTextView exposes no member for "
            + "\(refused.count == 1 ? "it" : "them"). The restriction is NOT applied.")
    }

    /// Idempotent and terminal for the current attachment.
    ///
    /// The engine host is destroyed with the attachment. That also destroys the document it holds,
    /// which is correct for this phase and is NOT a defect to "fix" by caching: Telegram has no
    /// document sync with the engine yet (`synchronizeAfterExternalChange(_:)` below records exactly
    /// that gap), so a document that outlived its host would be state nothing owns.
    ///
    /// **Kernel teardown is DEALLOCATION-DRIVEN, and that is upstream's contract, not a shortcut.**
    /// `IDBlockTextView.dealloc` calls `id_tearDownEditorGraph`, which is what detaches the behavior
    /// kernel, the interaction capability and the layout controller (`IDBlockTextView.m:363-397`).
    /// That method is declared in `IDBlockTextViewInternal.h` and is therefore unreachable from here
    /// by construction — dropping the last reference is the only teardown this side can perform. The
    /// consequence to know: anything that RETAINS the engine host past `detach()` keeps the kernel
    /// attached. `IDUpstreamInputBackendTests.test_detachReleasesTheEngineSoTheKernelTearsDown` holds
    /// it weakly and asserts it goes nil.
    func detach() {
        let member = "detach()"
        guard let view = engine else { return }
        // Cleared FIRST, so `isAttached` (derived from it) is already false and a re-entrant
        // `detach()` fired from anything below is a no-op rather than a second teardown.
        engine = nil
        attachedHost = nil

        var refusedResignation = false
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            if view.isFirstResponder { refusedResignation = !view.resignFirstResponder() }
            view.removeFromSuperview()
        }, &error)
        if let error { reportEngineFailure(error, member: member) }
        // F3 — a refusal is a real answer and must not be discarded. It means the engine is leaving
        // the view hierarchy while still first responder, which is a state nothing downstream expects
        // and which no other member can observe after the reference is gone.
        if refusedResignation {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): the engine refused to resign first responder and "
                + "is being removed from the hierarchy anyway")
        }
    }

    // MARK: - `RichTextInputBackend` — published state

    /// Every field is forwarded; none is remembered.
    ///
    /// `markedRange` and `isComposing` come from ONE read of the engine's `markedTextRange`, not two:
    /// the engine's marked range is the only witness of composition it publishes, and reading it
    /// twice could describe two different moments of the same composition.
    var state: RichTextInputStateSnapshot {
        let marked = engineMarkedRange("state")
        return RichTextInputStateSnapshot(
            documentRevision: engineDocumentRevision("state"),
            selection: canonicalSelection,
            markedRange: marked,
            isComposing: marked != nil)
    }

    /// The engine stamps every position it mints with the document revision that was live at mint
    /// time (`IDRichTextPosition.m:29`), so a freshly-minted `beginningOfDocument` carries the
    /// current revision. That is a forward: the engine answers, this reads the answer off the object.
    private func engineDocumentRevision(_ member: String) -> UInt64 {
        guard let view = requireEngine(member) else { return 0 }
        let position = perform(member, on: view, default: nil as UITextPosition?) {
            $0.beginningOfDocument
        }
        guard let position else { return 0 }
        guard let enginePosition = position as? IDRichTextPosition else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): beginningOfDocument returned a "
                + "\(type(of: position)); the engine's document revision is unreadable")
            return 0
        }
        return UInt64(enginePosition.documentRevision)
    }

    private func engineMarkedRange(_ member: String) -> NSRange? {
        guard let view = requireEngine(member) else { return nil }
        guard let range = perform(member, on: view, default: nil as UITextRange?, { $0.markedTextRange })
        else { return nil }
        guard let start = canonicalOffset(of: range.start, member: member),
              let end = canonicalOffset(of: range.end, member: member)
        else { return nil }
        return NSRange(location: min(start, end), length: abs(end - start))
    }

    /// The offset of `position` on the ENGINE's canonical axis. The engine measures it; this does no
    /// arithmetic of its own.
    private func canonicalOffset(of position: UITextPosition, member: String) -> Int? {
        guard let view = requireEngine(member) else { return nil }
        guard requireEnginePosition(position, member: member) else { return nil }
        return perform(member, on: view, default: nil as Int?) { view in
            view.offset(from: view.beginningOfDocument, to: position)
        }
    }

    // MARK: - `RichTextInputBackend` — selection

    /// **What this can and cannot forward, precisely.**
    ///
    /// The engine publishes its selection as a `UITextRange`, which is ORDERED — `start` before
    /// `end`. Its public surface carries no anchor/head distinction and no selection direction, so a
    /// REVERSED selection (a backwards drag) is not representable through this adapter:
    /// `isReversed` is always `false` here. That is a recorded gap, not an answer this adapter is
    /// entitled to compute — guessing a direction from a stored "last anchor" is exactly the kind of
    /// Telegram-side bookkeeping this port exists to delete.
    ///
    /// A nil `selectedTextRange` (the engine legitimately has none before anything focuses it) has
    /// no representation in `RichTextCanonicalSelection`, which is non-optional. That is reported and
    /// answered with a caret at 0, and `IDUpstreamInputBackendTests` pins that behaviour so nobody
    /// mistakes the 0 for a measured position.
    var canonicalSelection: RichTextCanonicalSelection {
        let member = "canonicalSelection"
        guard let view = requireEngine(member) else {
            return .caret(at: RichTextInputPosition(utf16Offset: 0))
        }
        // F6 — `performAnswering` so a RAISE is not also reported as "the engine has no selection",
        // which is false on that path. The raise is already reported inside; the caret-0 answer below
        // is shared, but only the genuine nil earns the second, different report.
        let answer: EngineAnswer<UITextRange> = performAnswering(member, on: view) {
            $0.selectedTextRange
        }
        guard case .answered(let selected) = answer else {
            return .caret(at: RichTextInputPosition(utf16Offset: 0))
        }
        guard let range = selected else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): the engine has no selection; "
                + "RichTextCanonicalSelection cannot represent that, answering with a caret at 0")
            return .caret(at: RichTextInputPosition(utf16Offset: 0))
        }
        guard let start = canonicalOffset(of: range.start, member: member),
              let end = canonicalOffset(of: range.end, member: member)
        else {
            return .caret(at: RichTextInputPosition(utf16Offset: 0))
        }
        return RichTextCanonicalSelection(
            anchor: RichTextInputPosition(utf16Offset: start,
                                          affinity: affinity(of: range.start, member: member)),
            head: RichTextInputPosition(utf16Offset: end,
                                        affinity: affinity(of: range.end, member: member)))
    }

    /// Read off the engine's own position object. `UITextStorageDirection.forward` means the position
    /// is bound to the text AFTER it, which is what `.downstream` names.
    ///
    /// The WRITE direction has no counterpart — see `applySelection(_:member:)`, which reports it.
    ///
    /// **The fallback REPORTS, and that mattered enough to be a review finding.** An earlier draft
    /// returned `.downstream` for a non-`IDRichTextPosition` with no report: unreachable today (both
    /// call sites are downstream of `canonicalOffset`'s `requireEnginePosition`), and therefore the
    /// most dangerous kind of silent default — one that is correct until somebody moves a call site.
    /// It was the only unreported fallback inside the implemented 22.
    private func affinity(of position: UITextPosition, member: String) -> RichTextInputAffinity {
        guard let enginePosition = position as? IDRichTextPosition else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): affinity was read from a \(type(of: position)), "
                + "which carries none; the engine's own IDRichTextPosition is the only witness")
            return .downstream
        }
        return enginePosition.affinity == .backward ? .upstream : .downstream
    }

    func setSelection(
        _ selection: RichTextCanonicalSelection,
        reason: RichTextSelectionChangeReason
    ) {
        applySelection(selection, member: "setSelection(_:reason:)")
    }

    /// The one body that writes a selection into the engine.
    ///
    /// **Private on purpose.** `setSelection(_:reason:)` is the package's single publication path for
    /// a selection (`InputBackendSourceBoundaryTests`' "DOOR 1" enumerates its call sites across the
    /// whole `Sources/` tree), so `synchronizeAfterExternalChange(_:)` shares this body rather than
    /// calling that member and opening a second door.
    ///
    /// `reason` is accepted and not forwarded: the engine has no notion of why a selection moved.
    /// Recorded rather than smuggled into some Telegram-side store.
    private func applySelection(_ selection: RichTextCanonicalSelection, member: String) {
        guard let view = requireEngine(member) else { return }
        reportUnforwardableAffinity(in: selection, member: member)
        let range = perform(member, on: view, default: nil as UITextRange?) { view -> UITextRange? in
            guard let anchor = view.position(from: view.beginningOfDocument,
                                             offset: selection.anchor.utf16Offset),
                  let head = view.position(from: view.beginningOfDocument,
                                           offset: selection.head.utf16Offset)
            else { return nil }
            return view.textRange(from: anchor, to: head)
        }
        guard let range else {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): the engine minted no range for "
                + "[\(selection.anchor.utf16Offset), \(selection.head.utf16Offset)] on its canonical axis")
            return
        }
        perform(member, on: view, default: ()) { $0.selectedTextRange = range }
    }

    /// **F4 — the write-side affinity gap, reported by name instead of dropped.**
    ///
    /// `IDBlockTextView.position(from:offset:)` gives the caller no affinity control; the engine mints
    /// `UITextStorageDirectionForward`. The member that WOULD take one —
    /// `IDRichTextLayoutController.positionForCanonicalOffset:affinity:` — is not on the host's public
    /// surface, so there is no forward to make.
    ///
    /// **Only `.upstream` is reported, and that is the precise statement rather than a softer one.**
    /// `.downstream` is what the engine produces anyway, so a caller asking for it was not refused —
    /// reporting it would be noise on every selection write and would train a reader to ignore the
    /// channel. `.upstream` genuinely cannot be honoured, and under deviation D6 (the legacy backend
    /// emits only `.downstream`) nothing asks for it today. Same shape as
    /// `synchronizeAfterExternalChange(_:)`: apply what can be applied, name what cannot.
    private func reportUnforwardableAffinity(
        in selection: RichTextCanonicalSelection,
        member: String
    ) {
        var refused: [String] = []
        if selection.anchor.affinity == .upstream { refused.append("anchor") }
        if selection.head.affinity == .upstream { refused.append("head") }
        guard !refused.isEmpty else { return }
        reportContractViolation(
            "IDUpstreamInputBackend.\(member): .upstream affinity was requested for "
            + "\(refused.joined(separator: " and ")) and is NOT applied — IDBlockTextView mints "
            + "positions at UITextStorageDirectionForward and exposes no affinity-taking member")
    }

    /// **The half of this member that has an InputDec counterpart, and the half that does not.**
    ///
    /// FORWARDED: the selection. `change.selection`'s offsets are interpreted on the engine's
    /// canonical axis — in this phase there is no second axis for them to be on.
    ///
    /// NOT FORWARDED, because there is nothing to forward to: `oldRevision`/`newRevision` (the engine
    /// owns its revision counter and no external agent can advance it), `changedRangeBefore`/
    /// `changedRangeAfter` (there is no external mutation path to rebase against), and
    /// `markedTextPolicy` (`IDBlockTextView` decides marked-text survival itself). Any call whose
    /// reason claims a real document change is therefore reported: the premise — that something
    /// outside the engine changed the document — cannot be true in this phase, and silently
    /// swallowing it is how a stub reads as plausible.
    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {
        let member = "synchronizeAfterExternalChange(_:)"
        guard requireEngine(member) != nil else { return }
        if change.reason != .layoutOnly {
            reportContractViolation(
                "IDUpstreamInputBackend.\(member): reason .\(change.reason) claims the document "
                + "changed outside the engine, but the ported engine owns its document in this phase. "
                + "Revision \(change.oldRevision)->\(change.newRevision) and the changed ranges are "
                + "NOT adopted; only the selection is applied.")
        }
        applySelection(change.selection, member: member)
    }

    // MARK: - `RichTextInputTextBackend` — the 12 forwarded members

    var inputDelegate: UITextInputDelegate? {
        get {
            let member = "inputDelegate"
            guard let view = requireEngine(member) else { return nil }
            return perform(member, on: view, default: nil) { $0.inputDelegate }
        }
        set {
            let member = "inputDelegate"
            guard let view = requireEngine(member) else { return }
            perform(member, on: view, default: ()) { $0.inputDelegate = newValue }
        }
    }

    /// The engine CONSTRUCTS and OWNS its tokenizer; this vends the engine's, and mints none. There
    /// is no `IDUpstream…Tokenizer` in this package for exactly that reason — a Telegram-side
    /// tokenizer would hand Telegram-minted positions back into engine witnesses, which is the
    /// documented cause of a live `unrecognized selector` failure in the reconstruction
    /// (`../IDTextEditorBackend+Tokenizer.swift`'s own header records it).
    var tokenizer: UITextInputTokenizer {
        let member = "tokenizer"
        guard let view = requireEngine(member) else { return Self.detachedFallbackTokenizer }
        return perform(member, on: view, default: Self.detachedFallbackTokenizer) { $0.tokenizer }
    }

    private static let detachedFallbackTokenizer: UITextInputTokenizer =
        IDUpstreamDetachedTokenizer()

    var selectedTextRange: UITextRange? {
        get {
            let member = "selectedTextRange"
            guard let view = requireEngine(member) else { return nil }
            return perform(member, on: view, default: nil) { $0.selectedTextRange }
        }
        set {
            let member = "selectedTextRange"
            guard let view = requireEngine(member) else { return }
            if let newValue, !requireEngineRange(newValue, member: member) { return }
            perform(member, on: view, default: ()) { $0.selectedTextRange = newValue }
        }
    }

    var markedTextRange: UITextRange? {
        let member = "markedTextRange"
        guard let view = requireEngine(member) else { return nil }
        return perform(member, on: view, default: nil) { $0.markedTextRange }
    }

    var beginningOfDocument: UITextPosition {
        let member = "beginningOfDocument"
        guard let view = requireEngine(member) else { return UITextPosition() }
        guard let position = perform(member, on: view, default: nil as UITextPosition?, {
            $0.beginningOfDocument
        }) else { return UITextPosition() }
        return position
    }

    var endOfDocument: UITextPosition {
        let member = "endOfDocument"
        guard let view = requireEngine(member) else { return UITextPosition() }
        guard let position = perform(member, on: view, default: nil as UITextPosition?, {
            $0.endOfDocument
        }) else { return UITextPosition() }
        return position
    }

    func text(in range: UITextRange) -> String? {
        let member = "text(in:)"
        guard let view = requireEngine(member) else { return nil }
        guard requireEngineRange(range, member: member) else { return nil }
        return perform(member, on: view, default: nil) { $0.text(in: range) }
    }

    func replace(_ range: UITextRange, withText text: String) {
        let member = "replace(_:withText:)"
        guard let view = requireEngine(member) else { return }
        guard requireEngineRange(range, member: member) else { return }
        perform(member, on: view, default: ()) { $0.replace(range, withText: text) }
    }

    func position(from: UITextPosition, offset: Int) -> UITextPosition? {
        let member = "position(from:offset:)"
        guard let view = requireEngine(member) else { return nil }
        guard requireEnginePosition(from, member: member) else { return nil }
        return perform(member, on: view, default: nil) { $0.position(from: from, offset: offset) }
    }

    func textRange(from: UITextPosition, to: UITextPosition) -> UITextRange? {
        let member = "textRange(from:to:)"
        guard let view = requireEngine(member) else { return nil }
        guard requireEnginePosition(from, member: member),
              requireEnginePosition(to, member: member) else { return nil }
        return perform(member, on: view, default: nil) { $0.textRange(from: from, to: to) }
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let member = "compare(_:to:)"
        guard let view = requireEngine(member) else { return .orderedSame }
        guard requireEnginePosition(position, member: member),
              requireEnginePosition(other, member: member) else { return .orderedSame }
        return perform(member, on: view, default: .orderedSame) { $0.compare(position, to: other) }
    }

    func offset(from: UITextPosition, to other: UITextPosition) -> Int {
        let member = "offset(from:to:)"
        guard let view = requireEngine(member) else { return 0 }
        guard requireEnginePosition(from, member: member),
              requireEnginePosition(other, member: member) else { return 0 }
        return perform(member, on: view, default: 0) { $0.offset(from: from, to: other) }
    }

    // MARK: - `RichTextKeyInputBackend` — the 3 forwarded members

    var hasText: Bool {
        let member = "hasText"
        guard let view = requireEngine(member) else { return false }
        return perform(member, on: view, default: false) { $0.hasText }
    }

    func insertText(_ text: String) {
        let member = "insertText(_:)"
        guard let view = requireEngine(member) else { return }
        perform(member, on: view, default: ()) { $0.insertText(text) }
    }

    func deleteBackward() {
        let member = "deleteBackward()"
        guard let view = requireEngine(member) else { return }
        perform(member, on: view, default: ()) { $0.deleteBackward() }
    }

    // MARK: - Test access to the engine host
    //
    // A test must be able to drive the engine the way UIKit does — make it first responder, lay it
    // out — and to prove that the object this adapter forwards to is the ported host and not a
    // stand-in. Exposing the host read-only is strictly narrower than the alternative of duplicating
    // construction in the test, which is how a test ends up certifying a second graph.

    var engineHostForTesting: IDBlockTextView? { engine }
}

/// The answer for a `tokenizer` read outside the attached window. Mirrors the legacy conformer's own
/// `NoOpTextInputTokenizer`: the read is already reported as a contract violation, and this exists
/// only so the non-optional requirement has something inert to return instead of trapping.
@available(iOS 18.4, *)
private final class IDUpstreamDetachedTokenizer: NSObject, UITextInputTokenizer {
    func rangeEnclosingPosition(
        _ position: UITextPosition,
        with granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextRange? { nil }

    func isPosition(
        _ position: UITextPosition,
        atBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool { false }

    func position(
        from position: UITextPosition,
        toBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextPosition? { nil }

    func isPosition(
        _ position: UITextPosition,
        withinTextUnit granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool { false }
}
#endif
