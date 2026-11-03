#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextInputDecHost

/// Paragraph structure (R6, capability half): style, alignment and list membership.
///
/// Unlike R3's inline traits, none of this has an engine counterpart to forward to —
/// `IDBlockTextView` lays out attributed text in blocks and has no notion of a heading or a list.
/// So every mutator here is the SAME shape: read the current structure, capture
/// `engineSelectedRange` (a whole-document `document` re-application collapses the engine's
/// selection — see `RichTextEngineEditorView.document`'s setter), rebuild the touched
/// `ParagraphBlock`s, assign `document` (which routes through `tgid_setAttributedBlocks`, the
/// engine's own whole-content replacement idiom), then restore the captured selection. This is a
/// host-originated document change, not a counterfeit keyboard mutation (Global Constraint 4) —
/// nothing here runs inside the engine's own edit-processing.
///
/// **Task 9 fix round 2: `mutateTouchedParagraphs` fires `onChange?()` itself, once, at the end.**
/// All five mutators here are USER-INITIATED edits (a toolbar tap) that merely happen to be
/// *implemented* via the host-document-set idiom (`document = …`). That idiom's own
/// `isApplyingHostDocument` guard exists to stop a document a host LOADS wholesale (a draft
/// restore) from masquerading as a user edit, and it was silencing these five as collateral
/// damage — Task 9's terminal gate measured this directly (Legacy fired `onChange` for all five,
/// every time; the engine fired it for none, every time) and fix round 1 documented it as a
/// divergence. Fix round 2's ruling: it is a defect in the engine path, not a divergence to carry
/// forward, since Legacy has the correct behaviour — a composer's content-height/draft/send-button
/// state all key off `onChange`, so all three would go stale after e.g. a heading or bullet-list
/// toggle. So `mutateTouchedParagraphs` now fires the notification itself, AFTER the selection
/// restore (so a consumer reading `document`/`engineSelectedRange` from inside the callback sees
/// the final state of both), suppressed only while a list-continuation reconciliation is still
/// pending (mirrors `engineDidChangeDocument()`'s own suppression one section below, for the same
/// reason: so a consumer can never observe a not-yet-reconciled intermediate structure through
/// EITHER notification path — the pending reconciliation's own trailing `onChange?()`, which reads
/// the fully-settled state, covers that case once it lands). This does not touch, and must not
/// weaken, `RichTextEngineEditorView.document`'s own `isApplyingHostDocument` guard — a host
/// assigning `document` directly (not through one of these five mutators) is still silent
/// (`EngineEditorDocumentTests.test_settingTheDocumentDoesNotFireOnChange`).
///
/// `touchedParagraphIndices(for:)` resolves each endpoint via `+Selection.swift`'s
/// `blockRelativeLocation(forFlatOffset:)` — the SAME block-start accumulation (UTF-16 length + 1
/// for the "\n" join) `engineSelectedRange` itself is built on, widened to `internal` (R6/Task 8
/// fix round 2) so this file shares the one implementation instead of carrying its own copy of the
/// boundary rule.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    public func setParagraphStyle(_ name: ParagraphStyleName) {
        mutateTouchedParagraphs { $0.style = name }
    }

    public func setAlignment(_ alignment: TextAlignment) {
        mutateTouchedParagraphs { $0.paragraph.alignment = alignment }
    }

    /// `nil` removes list membership entirely. A non-nil marker on an already-listed paragraph
    /// keeps its current level (switching bullet <-> ordered <-> checklist in place rather than
    /// resetting nesting); a freshly-listed paragraph starts at level 0. Checked state only ever
    /// exists for `.checklist` — switching TO checklist starts unchecked, switching AWAY drops it.
    public func setList(_ marker: ListMarker?) {
        mutateTouchedParagraphs { paragraph in
            guard let marker else {
                paragraph.list = nil
                return
            }
            paragraph.list = ListMembership(marker: marker,
                                            level: paragraph.list?.level ?? 0,
                                            checked: marker == .checklist ? (paragraph.list?.checked ?? false) : nil)
        }
    }

    /// A no-op on a paragraph with no list membership — indenting only makes sense once a
    /// paragraph is already a list item (matching `setList`'s own "start at level 0" policy for
    /// newly-listed paragraphs). `ListNumbering.labels(for:)` floors a list's effective level at
    /// zero itself (`max(0, list.level)`); indent only ever grows the level, so there is nothing
    /// further to reuse from it here beyond that same floor-at-zero shape.
    public func indent() {
        mutateTouchedParagraphs { paragraph in
            guard let list = paragraph.list else { return }
            paragraph.list = ListMembership(marker: list.marker, level: list.level + 1, checked: list.checked)
        }
    }

    /// Clamps at level 0 — mirrors `ListNumbering.labels(for:)`'s own `max(0, list.level)` floor,
    /// reused rather than re-derived (outdenting past zero does not exit the list; see this file's
    /// sibling list-continuation reconciliation doc comment for the related, NOT implemented,
    /// "Return in an empty item exits the list" convention).
    public func outdent() {
        mutateTouchedParagraphs { paragraph in
            guard let list = paragraph.list else { return }
            paragraph.list = ListMembership(marker: list.marker,
                                            level: max(0, list.level - 1),
                                            checked: list.checked)
        }
    }

    /// The touched paragraphs' style, or `nil` when the selection touches none (an empty document,
    /// or a range `touchedParagraphIndices(for:)` cannot resolve) OR when it spans paragraphs with
    /// DIFFERENT styles. `ParagraphStyleName` has no "mixed" case to report (unlike R3's inline
    /// tri-state), so `nil` is the honest answer for a genuinely mixed selection rather than
    /// picking one side arbitrarily.
    public func currentParagraphStyle() -> ParagraphStyleName? {
        let indices = touchedParagraphIndices(for: engineSelectedRange)
        guard let first = indices.first else { return nil }
        // A container has no paragraph style, so a selection touching one reads as mixed — `nil`,
        // the same honest answer a genuinely mixed paragraph selection gets.
        guard let style = currentRoles[first].shape.paragraph?.style else { return nil }
        guard indices.allSatisfy({ currentRoles[$0].shape.paragraph?.style == style }) else { return nil }
        return style
    }

    /// Which paragraph index in `currentBlocks` a flat UTF-16 offset falls in, on the SAME
    /// axis `engineSelectedRange` already speaks (paragraphs joined by "\n" — see
    /// `+Selection.swift`'s header comment; no structural-axis conversion here either). Delegates
    /// to `blockRelativeLocation(forFlatOffset:)` (R6/Task 8 fix round 2 — that used to be a second,
    /// independently maintained copy of the identical accumulation) and maps its `BlockID` back to
    /// an index, since that is the currency this file's callers want. So a collapsed selection
    /// sitting exactly on a block boundary resolves to whichever block `blockRelativeLocation`
    /// resolves it to — the block it visually reads as being IN, not the one after it — by
    /// construction, from the ONE place that rule is now written down.
    private func paragraphIndex(forFlatOffset offset: Int) -> Int? {
        guard let (blockID, _) = blockRelativeLocation(forFlatOffset: offset) else { return nil }
        return currentRoles.firstIndex { $0.blockID == blockID }
    }

    /// A non-empty range's end is EXCLUSIVE (`touchedBlockIndices(for:)`'s rule): its last touched
    /// paragraph is the one holding its last character, so a range ending at a paragraph's start —
    /// "two⏎" — does not reach that paragraph, which Tab used to indent too (composer harness p16,
    /// `HarnessBlockCommandSelectionEndTests`). The last character's offset resolves to the paragraph
    /// it belongs to even when it is a break: a block's end offset is that block's.
    private func touchedParagraphIndices(for range: NSRange) -> [Int] {
        let lastOffset = range.length > 0 ? range.location + range.length - 1 : range.location
        guard let loIndex = paragraphIndex(forFlatOffset: range.location),
              let hiIndex = paragraphIndex(forFlatOffset: lastOffset) else {
            return []
        }
        return Array(loIndex...hiIndex)
    }

    /// The shared shape every mutator above follows. A no-op (no `document` re-application, no
    /// selection churn) when the selection touches no paragraph.
    private func mutateTouchedParagraphs(_ mutate: (inout ParagraphBlock) -> Void) {
        let indices = touchedParagraphIndices(for: engineSelectedRange)
        guard !indices.isEmpty else { return }
        let selection = engineSelectedRange
        let undoBefore = currentUndoSnapshot()
        let blocksBefore = currentBlocks
        var blocks = blocksBefore
        for index in indices {
            // A container in range is left alone: these mutators are paragraph commands, and
            // restyling a code block into a heading is not what any of them means.
            guard var paragraph = blocks[index].asParagraph else { continue }
            mutate(&paragraph)
            blocks[index] = .paragraph(paragraph)
        }
        // Fires LAST, after both the document re-application and the selection restore, so a
        // consumer reading `document`/`engineSelectedRange` from inside this callback sees the
        // final state of both — not the mid-mutation state the host-document-set idiom otherwise
        // leaves observable for exactly one property read. See this file's header comment (Task 9
        // fix round 2) for why this call exists.
        //
        // Routed through the one delivery point rather than calling `onChange?()` directly, and
        // that is load-bearing, not tidiness. This mutator's own `document =` set is swallowed by
        // `isApplyingHostDocument`, so it leaves `isChangeNotificationPending` untouched — and a
        // keyboard-direct edit (UIKit calls `insertText:` straight on `engine`, never through the
        // wrapper) may have marked that flag and enqueued a coalesced flush that has not run yet. A
        // direct call here would deliver, the stale flush would then deliver AGAIN for state
        // already reported, and `onChange`'s exactly-once property — three fix rounds' worth —
        // would be gone. Going through the one delivery point consumes the owed flush instead of
        // racing it. The reconciliation suppression that used to be spelled here now lives there
        // too, unchanged, so it cannot drift between the two sites.
        //
        // `deliveringOneChangeNotification` rather than `deliverChangeNotificationNow` because the
        // selection restore below is part of THIS mutation: marked owed from the start, it joins
        // this notification instead of scheduling a second one a turn later (see that function).
        //
        // **One undo step per command, restoring the selection it was applied to.** The `document`
        // set below is a host set, which the undo funnel never sees and which only re-seeds the
        // baseline — so these five commands registered NO step, and undo after a Tab reverted the
        // edit BEFORE it together with the indent (composer harness, 2026-09-23,
        // `HarnessListIndentUndoTests`). Registered inside the delivery so the host's `onChange`
        // already reads the new `canUndo`; nothing registered when the command changed nothing
        // (Tab on a paragraph that is not a list item).
        deliveringOneChangeNotification {
            applyEngineParallelBlocks(blocks)
            engineSelectedRange = selection
            if blocks != blocksBefore {
                recordUndoStepForCommand(restoring: undoBefore)
            }
        }
    }

    // MARK: - List continuation (additional scope, not in the R6 brief's interface list)

    /// Closes the gap Task 2's ruling F7 deliberately left open for R6: `EngineDocumentBridge`'s
    /// reverse mapping (`document(fromAttributedBlocks:engineIdentifiers:reusingStructureOf:)`)
    /// reuses paragraph structure by the ENGINE's block identity, and a block the engine minted
    /// inside this edit — exactly what the new half of a Return split is — has no identity to reuse
    /// and gets DEFAULT structure (no list). That is the bridge answering honestly: it has never
    /// seen that block. Left alone, though, pressing Return at the end of a bullet item silently
    /// drops the new paragraph out of the list, so the host continues it here.
    ///
    /// **Fix round 1 (deferred, not synchronous — see `RichTextEngineEditorView`'s
    /// `pendingListContinuationBlockIDs` doc comment for the full re-entrancy story).** The FIRST
    /// implementation applied the correction synchronously from `engineDidChangeDocument()`, which
    /// re-entered `tgid_setAttributedBlocks` from INSIDE the engine's own
    /// `-processEditing`/`documentChangeHandler` call — real `NSTextStorage` mutation during its own
    /// edit-processing notification. It happened to work under the test harness, but that is not
    /// "observe and reconcile AFTER the engine's change": it never left the engine's own
    /// edit-processing stack, which is exactly the hazard this design exists to avoid on the
    /// IME/marked-text and inline-prediction paths. So the fix now runs in three parts, split across
    /// `engineDidChangeDocument()` (detection + scheduling) and the two functions below (the
    /// deferred apply):
    ///
    /// 1. **Detection is synchronous and cheap** (`blockIDsNeedingListContinuation(from:in:)`,
    ///    below) — a pure scan with no mutation, so ordinary typing (no paragraph split) pays
    ///    nothing beyond a set-membership check. `engineDidChangeDocument()` calls it on every edit.
    /// 2. **Scheduling coalesces.** `scheduleListContinuationReconciliation(for:)` accumulates the
    ///    needed ids into `pendingListContinuationBlockIDs` and schedules AT MOST ONE
    ///    `DispatchQueue.main.async` callback (guarded by `isListContinuationReconciliationScheduled`)
    ///    regardless of how many edits arrive before it runs — so rapid edits don't stack multiple
    ///    deferred closures, and the eventual apply always reconciles against whatever the LATEST
    ///    `currentBlocks` is by then, never a stale snapshot captured at schedule time. This is
    ///    also the re-entrancy guard requirement: the apply step's own `document = …` set goes
    ///    through the SAME `isApplyingHostDocument` guard every host-driven set already uses, so the
    ///    nested `engineDidChangeDocument()` call it triggers returns at its very first line and
    ///    never re-examines `idsNeedingListContinuation` — reconciling cannot trigger another
    ///    reconciliation.
    /// 3. **`onChange` ordering is deliberate: suppressed for any edit while a correction is
    ///    pending, then fired exactly once after the deferred apply lands** (whether or not it found
    ///    anything left to actually correct by then). This is `engineDidChangeDocument()`'s decision,
    ///    not this file's, but the reasoning belongs here: firing `onChange` immediately after the
    ///    split — before the list membership is restored — would let a consumer read `document`,
    ///    see a list item that has just lost its bullet, and act on that (persist a draft, echo it
    ///    back into `document =` itself). Suppressing it means no consumer EVER observes that
    ///    intermediate state via the notification channel; the visible cost is that the corrected
    ///    structure lands one main-runloop turn later than the engine's own on-screen render of the
    ///    split (which is untouched — this only delays the HOST's `Document` notification, not what
    ///    the user sees typed). The gate is `isListContinuationReconciliationScheduled`, not "did
    ///    THIS edit create a new block" — an edit that types further into the still-uncorrected new
    ///    block (before the deferred turn fires) creates no new block itself, but must still be held
    ///    back, or its own `onChange` would leak the same intermediate state a beat later.
    ///
    /// Only list membership is inherited (marker + level), never style or alignment — the bridge's
    /// own default IS `.body`/`ParagraphAttributes.default` for a fresh block, and nothing in this
    /// task's scope says a heading should propagate onto whatever paragraph follows it on Return.
    /// A `.checklist` predecessor hands its marker and level forward but resets `checked` to
    /// `false`: a freshly created item has not been completed yet, matching `setList(_:)`'s own
    /// "switching TO checklist starts unchecked" policy above.
    ///
    /// NOT implemented here, and reported rather than attempted (see the task report): the
    /// conventional companion rule where Return in an EMPTY list item exits the list instead of
    /// continuing it. That is reachable through this same observe-and-reconcile shape in
    /// principle — the pre-edit paragraph cache already carries whether the split paragraph's text
    /// was empty before the edit — but it needs the reconciliation to REDUCE the block count (merge
    /// the two empty halves the engine's split produced back into one plain paragraph) rather than
    /// only patch a field on one block, plus a real product decision this task was not asked to make
    /// (exit immediately, or outdent one level first). Left out deliberately rather than guessed at.
    ///
    /// Pure detection: which blocks in `current` are NEW relative to `previous` (their `id` is not
    /// in `previous`, meaning the bridge minted them fresh this pass because the engine gave them an
    /// identifier it had never reported before — see `EngineDocumentBridge`'s own doc comment), have
    /// no list membership of their own, and — the point of the forward
    /// thread below — descend from a block that DOES have list membership, however many hops of
    /// fresh, list-less blocks lie in between. No mutation, no `document` access beyond the two
    /// arrays passed in.
    ///
    /// **R6/Task 8 fix round 2: this chains through a RUN of consecutive new blocks, not just one
    /// hop.** The naive version compared each new block only against its RAW predecessor
    /// (`current[index - 1].list`). That is correct for a single Return, but a single edit can
    /// create MORE than one new block at once — `insertText("\nsecond\nthird")` splits one
    /// paragraph into three in one call, and pasting multi-line text does too. For the SECOND new
    /// block in such a run, the raw predecessor is itself a fresh, still-list-less block at this
    /// point in the array, so the naive comparison excludes it — deterministically, not a race — and
    /// list continuation silently stops after the first new paragraph. The fix threads a
    /// `carriedList` value FORWARD through the single sweep: a block that already existed, or
    /// already carries its own list membership, resets the thread to ITS `list` (nil or not); a new,
    /// list-less block inherits whatever the thread currently holds and — critically — becomes part
    /// of the thread ITSELF for the next block, carrying that same membership forward rather than
    /// `current`'s still-nil `.list` for that block. That is what lets a run of N new blocks all
    /// inherit consistently in one pass. Only the set of ids escapes this function, so the thread's
    /// VALUE is never read by anything downstream — the apply step re-derives every field from the
    /// corrected array, `.checklist`'s `checked` reset included.
    internal func blockIDsNeedingListContinuation(previousIDs: Set<BlockID>,
                                                  in roles: [EngineBlockRole]) -> Set<BlockID> {
        var result: Set<BlockID> = []
        // The list membership the NEXT fresh, list-less block in the run would inherit — either a
        // pre-existing/already-listed block's OWN `.list`, or (the whole point of threading this
        // forward) the value THIS sweep just resolved a preceding fresh block to, so a run of N
        // fresh blocks all inherit consistently rather than only the first. Deliberately NOT
        // unwrapped via `if let carriedList` below — shadowing this outer `var` with an immutable
        // local of the same name would make the reassignment two lines down rebind only the
        // shadow, leaving the outer thread stuck at its very first value for every later hop. That
        // is the same one-hop bug this fix round exists to close, just relocated into the fix
        // itself, so the unwrapped value below is deliberately named differently (`upstream`).
        var carriedList: ListMembership?
        // The container the carried membership belongs to. A list continues among SIBLINGS: a block
        // in another container — or a container's own line (a quote's author, a details title, a
        // language line, a caption) or a cell, which is no paragraph of a list at all — never
        // inherits it. Without this a quote's author line minted by a cross-block deletion from a
        // quoted item was scheduled to inherit the item's membership, and the reconciliation's
        // document set landed between the candidates of the composition that deletion had started,
        // ending it with its FIRST candidate committed (composer harness p17, fuzz seed 77,
        // `HarnessCompositionAcrossQuoteEndTests`).
        var carriedAncestry: [BlockID] = []
        for role in roles {
            guard case .standalone = role.position else {
                carriedList = nil
                continue
            }
            let ancestry = role.ancestry.map(\.id)
            let isFreshBlock = !previousIDs.contains(role.blockID)
            let list = role.shape.paragraph?.list
            if isFreshBlock && list == nil {
                if carriedList != nil, carriedAncestry != ancestry {
                    carriedList = nil
                }
                if carriedList != nil {
                    result.insert(role.blockID)
                    // `carriedList` is deliberately left EXACTLY as it is, so this fresh block hands
                    // the same membership on to the next one and a run of N inherits consistently.
                    // Nothing is reconstructed here: only this function's set of ids escapes it, and
                    // the apply step re-derives every field — marker, level and the `.checklist`
                    // `checked` reset — from the predecessor in the corrected array
                    // (`performScheduledListContinuationReconciliation`, below). A rebuilt
                    // `ListMembership` here would be a value nothing can read.
                }
                // else: nothing upstream to continue, and `carriedList` is already nil.
            } else {
                // A container reports no membership, so it ENDS the run.
                carriedList = list
                carriedAncestry = ancestry
            }
        }
        return result
    }

    /// Accumulates `ids` into the pending set and schedules the deferred apply AT MOST ONCE — see
    /// this file's list-continuation header comment above for the full reasoning (coalescing +
    /// re-entrancy guard). `[weak self]`: this is a one-shot future callback, not a retained cycle,
    /// and the view may in principle be torn down before the next runloop turn.
    internal func scheduleListContinuationReconciliation(for ids: Set<BlockID>) {
        pendingListContinuationBlockIDs.formUnion(ids)
        guard !isListContinuationReconciliationScheduled else { return }
        isListContinuationReconciliationScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.performScheduledListContinuationReconciliation()
        }
    }

    /// Runs OUTSIDE the engine's edit-processing stack entirely (a separate, later main-runloop
    /// turn — not nested inside any `processEditing`/`documentChangeHandler` call), so this
    /// `document = …` set is a perfectly ordinary host-driven document push, the same shape as the
    /// four capability mutators above. Re-evaluates against the CURRENT `currentBlocks` (never a
    /// snapshot captured at schedule time), so edits that landed between scheduling and this turn
    /// running — e.g. the user typed further into the still-uncorrected new paragraph — are
    /// preserved: only the `.list` field is touched, never `.runs`. A pending id whose block no
    /// longer exists (deleted/merged away by now) or whose predecessor's list membership changed or
    /// disappeared in the interim is silently skipped, not force-corrected.
    ///
    /// This loop only needs to check the IMMEDIATE predecessor (`paragraphs[index - 1].list`), even
    /// for a multi-hop run — it does not need its own copy of `blockIDsNeedingListContinuation`'s
    /// forward-thread logic. It mutates `paragraphs[index].list` in place and then walks on to
    /// `index + 1` within the SAME array, so by the time it reaches the second block of a run its
    /// first block has already been corrected — the array read at `index - 1` sees the corrected
    /// value, not the original `nil`. That only works because `ids` now contains every block in the
    /// run (fix round 2) and `for index in paragraphs.indices` visits them in ascending order; it
    /// would NOT work if `ids` only had the first hop, which was exactly the round-2 bug.
    private func performScheduledListContinuationReconciliation() {
        isListContinuationReconciliationScheduled = false
        let ids = pendingListContinuationBlockIDs
        pendingListContinuationBlockIDs.removeAll()
        guard !ids.isEmpty else { return }

        var blocks = currentBlocks
        var didInheritList = false
        for index in blocks.indices {
            guard ids.contains(blocks[index].id) else { continue }
            guard blocks[index].asParagraph != nil else { continue }
            guard blocks[index].listMembership == nil else { continue }
            // A container predecessor reports no membership, so it ENDS the run rather than being
            // continued through — which is what a code block between two list items should do.
            guard index > 0, let precedingList = blocks[index - 1].listMembership else { continue }
            blocks[index].asParagraph?.list = ListMembership(
                marker: precedingList.marker,
                level: precedingList.level,
                checked: precedingList.marker == .checklist ? false : precedingList.checked)
            didInheritList = true
        }
        // Release the notification suppressed on every edit since this reconciliation was
        // scheduled — exactly once, whether or not anything was left to correct by the time this
        // ran (a pending id can resolve to nothing, e.g. its block was deleted in the interim, and
        // the consumer still needs to hear about whatever DID happen since the suppression began).
        //
        // Through the same single delivery point as everything else, so this release also CONSUMES
        // any coalesced flush still owed rather than leaving one to fire behind it. In practice the
        // flag is already clear here — `engineDidChangeDocument()` returns before marking it while
        // a reconciliation is pending — so this is not a behaviour change today; it is what keeps
        // the "one delivery point" invariant true by construction instead of by that argument.
        // `isListContinuationReconciliationScheduled` was set false at the top of this function, so
        // the flush's suppression guard passes and the release does fire.
        //
        // The correction and the release are ONE notification (`deliveringOneChangeNotification`):
        // the caret restore is part of the correction, and left to schedule its own it delivered a
        // second `onChange` a turn behind this one.
        deliveringOneChangeNotification {
            guard didInheritList else { return }
            let selection = engineSelectedRange
            // The correction is a consequence of the edit that minted the block, and it can land
            // INSIDE an IME composition: the run-loop turn it waits for comes between two candidates.
            // The document set ends the typing run (a host set is a new baseline), so the next
            // candidate opened a step of its own and one undo left the earlier candidates committed
            // (composer harness fuzz seed 58, 2026-09-24, `HarnessCompositionUndoResidualTests`).
            // Only list membership changes — no character, so the run's end offset still holds — and
            // the composition keeps the run it is in.
            let composingRun = engine.markedTextRange != nil ? openTypingRunEnd : nil
            let composingRunEndsInComposition = openRunEndsInComposition
            applyEngineParallelBlocks(blocks)
            engineSelectedRange = selection
            if let composingRun {
                openTypingRunEnd = composingRun
                openRunEndsInComposition = composingRunEndsInComposition
            }
        }
    }
}
#endif
