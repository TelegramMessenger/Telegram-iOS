#if canImport(UIKit)
import UIKit

/// TASK 30 — Family 7 (responder commands and clipboard). Seven canvas witnesses
/// (`canPerformAction(_:withSender:)`, `select(_:)`, `selectAll(_:)`, `copy(_:)`, `cut(_:)`,
/// `paste(_:)`, and the `undoManager` override) land on the THREE backend members below.
///
/// # The task brief's Step 3 said this family "needs no `legacyCanvas` hook, because Task 19's
/// command client already owns the bodies". **It does not own them. It calls them — and where it does
/// own something, it owns strictly LESS.** The premise fails four separate ways, all measured:
///
///  1. **`cut`/`paste` — a cycle.** `TelegramCommandInputClient.commit` dispatched
///     `canvas.cut(sender)` / `canvas.paste(sender)`, and those are two of the witnesses this task
///     routes. `canvas.cut` -> `performCommand(.cut)` -> `client.commit` -> `canvas.cut` -> …, and
///     `commit` clears `outstanding`/`pending`/`pendingSender` BEFORE dispatching, so the token that
///     would otherwise break the loop is already gone.
///  2. **`copy` — a worse cycle, through a different method.** `prepare` resolves `.copy` as terminal
///     and calls `canvas.copy(sender)` inline, and it RETURNS from that branch before
///     `outstanding`/`pending` are ever assigned. No token exists on the copy path at all, so no token
///     discipline could ever have broken that loop.
///  3. **`select`/`selectAll` — not a cycle at all, a silent DELETION.** The client's `.selectWord` /
///     `.selectAll` commit cases are `canvas.selectWord(at: canvas.head)` / `canvas.selectAllText()`.
///     The witnesses are those PLUS `presentEditMenu()`. Routing them through the client drops the
///     menu re-presentation — compiler-invisible, and unobservable by any test in the package until
///     this task added `presentEditMenuCountForTesting`.
///  4. **`paste` — a second silent deletion, and this one an EXISTING TEST CATCHES.** `prepare` gates
///     on `canPerform(.paste)`, i.e. `clipboardCanPerformAction(paste:)`: pasteboard has a rich rep,
///     OR has strings, OR `canPasteMedia?() ?? false`. The witness body has an unconditional
///     `_ = onPasteMedia?()` fallback that runs when NONE of those hold. With an empty pasteboard and
///     no `canPasteMedia` hook, the client route performs nothing where the witness delegated the
///     paste to the host. `CanvasClipboardTests.test_paste_noTextRep_delegatesToOnPasteMedia_…` goes
///     red under the client route — measured, not predicted.
///
/// (1) and (2) are fixed the way Task 27a fixed `replace` -> `legacyReplace`: the three bodies are
/// renamed `legacyCopy`/`legacyCut`/`legacyPaste` and the client's three call sites now name those.
/// (3) and (4) are fixed by the SHAPE below.
///
/// # The shape, and the alternative that was measured and rejected
///
/// **`performCommand` forwards every command that HAS a canvas witness straight to that witness's
/// renamed body — a plain D24 forward, exactly Families 4-6 — and routes the three that have NO
/// witness through the command client.** The coordinator's pre-flight offered two shapes for (3):
/// (a) rename the bodies and forward there, or (b) keep the client route and re-add `presentEditMenu()`
/// on the backend side. **(a) was chosen, and finding (4) then generalised it from two members to
/// five**, because (b) does not actually restore the pre-seam behaviour:
///
///   * (b) leaves the client's `canPerform` GATE in front of a body that ran unconditionally. For
///     `.selectAll` the gate rejects exactly when the whole document is already selected, so a
///     programmatic `selectAll(nil)` — which four in-tree tests make — would stop doing anything at
///     all. For `.paste` the gate is finding (4), which no re-added side effect repairs.
///   * (b) would put a UI side effect (`presentEditMenu()`) on the backend, reached through
///     `legacyCanvas` as an unprefixed, broad canvas call — neither clause of D24 admits that.
///   * (a) is the family-standard shape. It cannot drop anything, because it moves the whole body.
///
/// **What (a) costs, disclosed rather than hidden:** the command client's `.copy`/`.cut`/`.paste`/
/// `.selectWord`/`.selectAll` `prepare`/`commit` paths have **no production caller** after this task.
/// They are still the client-level definition of those commands (what a keyboard toolbar, or stage 2,
/// would drive), still fully tested by `TelegramCommandInputClientTests`, and still what
/// `canPerformCommand` consults for AVAILABILITY. Only the "perform" leg bypasses them, and only
/// because bodies the seam has not moved yet are wider than the client's model of them. Whoever
/// finally moves those bodies behind the clients (the D26/D27 charter) owns closing this — and now has
/// the exact list of what the client's cases are missing: `presentEditMenu()` on two of them, the
/// `onPasteMedia` fallback on a third.
///
/// # Non-obvious consequences
///
///   * **`cut(_:)` makes TWO backend calls**, because its body calls the routed `replace(_:withText:)`
///     witness (`+Clipboard.swift`'s note). Left alone, on Task 29's `legacySetMarkedText` precedent.
///   * **`canPerformAction(_:withSender:)` does not appear here** as a backend member. It maps a
///     selector and asks `canPerformCommand`, and the mapping lives at the witness — the single
///     permitted representation translation.
///   * **`keyCommands` and the `UIResponder` `inputView` override (both `DocumentCanvasView.swift`) are
///     deliberately NOT routed** (deviation D5; `inputView` is additionally D23 — it is a different
///     member from the host protocol's `hostInputView` and keeps vending `customInputView`). Cited by
///     NAME, not by line: this comment shipped with `:825`/`:759`, measured against the parent tree and
///     already 26 lines stale in its own commit (FIX ROUND 1, Min-4; see `RichTextInputHost.swift`'s
///     D23 note for the full account).
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - `canPerformAction(_:withSender:)`'s backend half

    /// Routed from `DocumentCanvasView.canPerformAction(_:withSender:)` (`+EditMenu.swift`), after that
    /// witness maps the `Selector` to a command.
    ///
    /// The `guard` prelude is the Task-22i `allowsPaste` edit-policy gate, kept verbatim in behaviour
    /// and rewritten only in shape (an `if` block became a guard) so the member reads as the
    /// "guard-prelude plus one statement" forward that rule R17 checks for. It is NOT new: this member
    /// has had a real, policy-gated `.paste` branch since Task 22i, pinned by
    /// `BackendEditPolicyTests.test_allowsPasteFalse_makesCanPerformPasteFalse`. Everything else that
    /// was a `pendingRouting()` stub now asks the client.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A. No offsets, no ranges; the parameter is an enum case.
    /// 2. *nil / wrong-type input* — the `Selector`-shaped ill-formed input never reaches here: the
    ///    witness answers an unmapped selector from `super` and only calls this with a real command.
    ///    **The DETACHED path is a real axis-2 divergence**: with no host this answers `false` for
    ///    every command, where the pre-seam witness kept answering from live canvas state (`selFrom <
    ///    selTo`, the pasteboard, …). `false` is the safe direction — a menu item is greyed out rather
    ///    than offered by a responder that cannot perform it — and it is the same answer the
    ///    pre-Task-30 stub gave. **No `RichTextInputContractViolation` is reported**, following
    ///    `hasText`'s precedent for the same reason: UIKit polls `canPerformAction` on every menu
    ///    evaluation and on the responder chain's own capability walk, so a report would flood a
    ///    documented teardown window with DEBUG asserts.
    /// 3. *Which store is read* — the client's, which for `.copy`/`.cut`/`.paste` re-enters the canvas
    ///    (`clipboardCanPerformAction(_:)`, the pasteboard, `canPasteMedia`) and for
    ///    `.selectWord`/`.selectAll` reads `canvas.hasText`/`selFrom`/`selTo`/`leafRegion(…)`/the
    ///    document bounds. Same stores the witness read inline, one hop apart. `.undo`/`.redo` read
    ///    `canvas.effectiveUndoManager` — unreachable from this witness, since no selector maps to
    ///    them.
    /// 4. *Which object owns a consulted flag or decision* — **TWO divergences, both disclosed.**
    ///    (i) `.paste` now additionally consults `RichTextInputEditPolicy.allowsPaste`, which the
    ///    canvas witness never did. Unreachable today: `.legacyUnrestricted` (`allowsPaste == true`) is
    ///    the only policy anything in the package sets, and it is the canvas's own default.
    ///    (ii) `.delete` moves from `super`'s decision to the client's — see the witness's own note in
    ///    `+EditMenu.swift`; both answer `false`, for different reasons.
    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        guard command != .paste || (lifecycle?.editPolicy.allowsPaste ?? false) else { return false }
        return self.command?.canPerform(command, sender: sender) ?? false
    }

    // MARK: - `performCommand(_:sender:)`

    /// Routed from FIVE canvas witnesses — `copy(_:)`, `cut(_:)`, `paste(_:)`, `select(_:)`,
    /// `selectAll(_:)` — each of which is now a one-line `inputBackend.performCommand(.x, sender:)`
    /// forward. The five renamed bodies (`legacyCopy`/`legacyCut`/`legacyPaste`/`legacySelect`/
    /// `legacySelectAll`) are the SAME bodies those witnesses carried, moved unchanged.
    ///
    /// Forwarded **BARE** — no `notifyingContentAndSelectionChange`, no `publishState`, no transaction.
    /// Three of the five hooks bracket themselves (`legacyCut` through the routed
    /// `replace(_:withText:)`; `legacyPaste` through `editing { }` / `pasteMarkdownTwoStep`;
    /// `legacySelect`/`legacySelectAll` through `applySelection`), and two of them emit nothing at all
    /// (`legacyCopy` writes only the pasteboard; a gated-out `legacySelect` changes nothing). A bracket
    /// here would double the first three and invent one for the last two.
    ///
    /// `.undo`/`.redo`/`.delete` have NO canvas witness — `UIResponderStandardEditActions` declares no
    /// `undo:`/`redo:` selector at all (see `richTextInputCommand(for:)`'s note), and the canvas
    /// implements no `delete(_:)` — so nothing routes into them from UIKit today. They go through the
    /// command client, which is their only implementation: `performUndo()`/`performRedo()` prefer the
    /// facade's `undo()`/`redo()` and fall back to the canvas's own manager, and `.delete` is
    /// unconditionally unavailable so its `prepare` returns terminal and nothing runs. A future
    /// keyboard-toolbar Undo button that holds the command value directly reaches them here.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A for all five: none of the witnesses took an offset or a range. Every
    ///    body reads the live `selFrom`/`selTo`/`head` and still does, inside the moved bodies.
    /// 2. *nil / wrong-type input* — `sender` is `Any?` and is forwarded VERBATIM, unread, exactly as
    ///    the pre-seam witnesses received it (no body inspects it; `legacyPaste` and friends ignore the
    ///    parameter entirely). **The DETACHED path is a real axis-2 divergence, the same one
    ///    `insertText`/`deleteBackward` carry**: a Copy/Cut/Paste/Select arriving while `legacyCanvas`
    ///    is nil is now DROPPED, where the pre-seam witnesses ran entirely on canvas state with no host
    ///    dependency. Accepted rather than repaired — the alternative is a canvas-side fallback, i.e. a
    ///    second copy of the bodies this routing exists to move. **Deliberately SILENT**, on the
    ///    precedent Task 28 settled: these are UIKit responder entry points AND public-facade paths
    ///    (`RichTextEditorView.pasteFromPasteboard()` -> `canvas.paste(nil)`), the identical shape
    ///    `deleteBackward()` has, and a report is a DEBUG `assertionFailure` that would turn a
    ///    documented teardown window into a trap.
    /// 3. *Which store is read* — none here, which is the point. The moved bodies read the LIVE canvas
    ///    selection, the live pasteboard and the live `canPasteMedia`/`onPasteMedia` hooks, exactly as
    ///    before. The rejected client route read the client's model of those instead, and finding (4)
    ///    above is precisely where that model is narrower than the store.
    /// 4. *Which object owns a consulted flag or decision* — this is the axis the rejected shape got
    ///    wrong, and it is worth stating as a decision rather than a flag: under the client route,
    ///    `canPerform` would own "should this command run at all", where the pre-seam witnesses each
    ///    owned their own guard (`legacyCopy`/`legacyCut`'s `selFrom < selTo`, `legacyPaste`'s
    ///    representation cascade, `legacySelect`'s no-word no-op inside `selectWord(at:)`). For
    ///    `.copy`/`.cut` the two agree exactly; for `.paste`/`.selectWord`/`.selectAll` they do not.
    ///    A plain forward consults nothing and cannot disagree with anything. The edit-policy gate is
    ///    likewise NOT consulted here — `canPerformCommand(.paste, …)` gates on `allowsPaste`, this
    ///    member does not, and that asymmetry is pre-existing (Task 22i gated only the query) and
    ///    preserved deliberately: adding the gate here would be a new behaviour, not a routed one.
    func performCommand(_ command: RichTextInputCommand, sender: Any?) {
        switch command {
        case .copy: legacyCanvas?.legacyCopy(sender)
        case .cut: legacyCanvas?.legacyCut(sender)
        case .paste: legacyCanvas?.legacyPaste(sender)
        case .selectWord: legacyCanvas?.legacySelect(sender)
        case .selectAll: legacyCanvas?.legacySelectAll(sender)
        case .undo, .redo, .delete: performThroughCommandClient(command, sender: sender)
        }
    }

    /// The prepare/commit half of `performCommand`, for the three commands with no canvas witness.
    /// Kept out of the member above so that member stays a readable one-per-command dispatch, and so
    /// the transaction discipline lives in one place: a `.ready` preparation is single-use and MUST be
    /// committed before returning to the run loop (`RichTextInputCommandClient`'s contract), and a
    /// `.terminal` one is already finished — `prepare` performed whatever there was to perform.
    private func performThroughCommandClient(_ command: RichTextInputCommand, sender: Any?) {
        guard let client = self.command else { return }
        switch client.prepare(command, sender: sender) {
        case .terminal:
            return
        case .ready(let prepared):
            _ = client.commit(prepared)
        }
    }

    // MARK: - `undoManager`

    /// Was `DocumentCanvasView.undoManager`, whose whole body was `effectiveUndoManager`. (Spelled
    /// that way rather than quoting the old declaration verbatim: rules R17 and `RouterWitnessBodyTests`
    /// count SIGNATURE occurrences, and although both strip comments first, a doc comment that repeats
    /// a signature is one edit away from breaking a uniqueness check for no reason.) Routed through the
    /// COMMAND CLIENT, not `legacyCanvas` — the same
    /// deviation `hasText` carries and for the same reason: this is a pure value read whose client
    /// answer is provably identical to the canvas's own. Verified, not assumed:
    /// `TelegramCommandInputClient.undoManager` IS `canvas.effectiveUndoManager`
    /// (`Clients/TelegramCommandInputClient.swift`), the very expression the override evaluated.
    ///
    /// Routing it through `legacyCanvas` instead would have needed an ADDITIONAL clause-(b) exception on
    /// D24's exception list — and it would not have fitted, because every entry on that list is a
    /// store Phase 5 moves onto the backend, whereas D14 keeps undo ownership with the canvas /
    /// document client indefinitely. The client path needs no such exception.
    ///
    /// **FIX ROUND 2 — that sentence used to call the list "prose-enforced", and for THIS member it no
    /// longer is.** Task 31's fix round 1 gave R17's `.client` shape a rule that the body must not name
    /// `legacyCanvas` at all, and this member is `.client`. Measured by applying the exact drift the
    /// paragraph above describes (`legacyCanvas?.effectiveUndoManager`): **R17 goes RED**, naming this
    /// member. The whole BODY is scanned, not just the one statement, so the guard-shaped variant
    /// (`guard let canvas = legacyCanvas … else { return nil }`) reddens too — a spelling that checked
    /// only the statement was measured GREEN against it. The list is still prose-only for members R17
    /// does not name; see `LegacyRichTextInputHost.swift` for the scope in full.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A. A property read with no arguments and no bounds.
    /// 2. *nil / wrong-type input* — no input. **DIVERGENCE, disclosed: with no attached command
    ///    client this answers `nil`, where the pre-seam override kept answering `ownUndoManager` from
    ///    canvas state that is still alive during the documented "attached but host gone" /
    ///    detach-to-re-attach windows.** `nil` is the safe direction and does NOT reintroduce the
    ///    app-wide-manager pollution the override exists to prevent: an override returning `nil` does
    ///    not fall back to `super`, so the responder chain simply has no undo manager for that window
    ///    and the system affordances no-op. No `RichTextInputContractViolation`, on `hasText`'s
    ///    precedent — `undoManager` is a `UIResponder` property UIKit may read at arbitrary times.
    /// 3. *Which store is read* — `canvas.effectiveUndoManager`, i.e. `undoManagerOverride ??
    ///    ownUndoManager`: the SAME store, one hop apart. Notably NOT any backend-side store: the
    ///    backend has no undo state at all (D14), so there is no second store to drift from.
    /// 4. *Which object owns a consulted flag or decision* — the `undoManagerOverride ?? ownUndoManager`
    ///    choice stays entirely inside the canvas's own `effectiveUndoManager` accessor, exactly where
    ///    it was. Nothing about which manager wins moved.
    ///
    /// **Who reads it, so the divergence is not mistaken for hypothetical**: UIKit itself (hardware
    /// Cmd-Z / Cmd-Shift-Z, shake-to-undo, the system Edit menu's Undo/Redo items) — and nothing in
    /// `Sources/` (measured: `grep -rn "\.undoManager\b" Sources/` outside this seam is empty; every
    /// in-tree undo path uses `effectiveUndoManager` directly).
    var undoManager: UndoManager? {
        self.command?.undoManager
    }
}
#endif
