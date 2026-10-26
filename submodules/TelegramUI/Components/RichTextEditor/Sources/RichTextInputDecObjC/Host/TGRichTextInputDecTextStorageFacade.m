// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecTextStorageFacade.h"
#import "TGRichTextInputDecClientBridge.h"

/// Task R7 (cluster 4) — see `TGRichTextInputDecLayoutController.m`'s identical helper (on
/// `id_characterRangeForTextRange:`) for the full rationale; duplicated here rather than shared,
/// matching this module's established convention of small, file-local static C helpers (see e.g.
/// `TGRichTextInputDecLayoutController.m`'s own "Family N helpers" sections). Converts a STRUCTURAL
/// axis offset (this document model's own node-token addressing) to its PLAIN-TEXT axis equivalent
/// — the offset into `documentPlainTextInRange:`'s own dense projection, exactly what `mirror` is
/// built from. Read-only; independent of `mirror`'s own sync state.
static NSInteger TGPlainTextOffsetForStructuralOffset(
    id<TGRichTextInputDecClientBridging> bridge, NSInteger structuralOffset, NSInteger documentLength) {
    if (bridge == nil || ![bridge respondsToSelector:@selector(documentPlainTextInRange:)]) {
        return structuralOffset;
    }
    NSInteger clamped = MIN(MAX(structuralOffset, 0), MAX(documentLength, 0));
    NSString *prefix = [bridge documentPlainTextInRange:NSMakeRange(0, (NSUInteger)clamped)];
    // No fabricated 0 on a nil answer — the ORIGINAL structural offset is the least-wrong fallback.
    return prefix != nil ? (NSInteger)prefix.length : structuralOffset;
}

@implementation TGRichTextInputDecTextStorageFacade {
    NSMutableAttributedString *_mirror;
    // Task R7 (cluster 4) — PRIVATE, dedicated tracking for `synchronizeMirrorWithDocumentIfNeeded`'s
    // own fast-path gate. Deliberately NOT the public `revision` property: that property is ALSO
    // written from Swift (`IDTextEditorBackend.insertText(_:)` sets `bridge.storage.revision =
    // state.documentRevision` BEFORE calling into this facade, to feed `prepareAndCommitReplacementInRange:
    // …expectedRevision:`) for a wholly different purpose — the mutation transaction's staleness
    // check — and that write can make `self.revision` already equal the bridge's current revision
    // even when `mirror` itself was NEVER actually synced (exactly the "content set via `setBlocks`/
    // `setParagraphs` after attach" gap this task's cluster exists to close). Gating on the PUBLIC
    // property caused the gate to skip the real sync on a canvas's first-ever read, silently
    // reintroducing the empty-mirror bug this task fixed. This ivar is written ONLY here, so it can
    // never be pre-poisoned by an unrelated writer.
    BOOL _hasSyncedMirror;
    uint64_t _lastSyncedBridgeRevision;
    // Task R7 (cluster 4) — set around `replaceCharactersInRange:withString:`'s own
    // `beginEditing`/mutate/`edited:`/`endEditing` bracket. `edited:` posts
    // `NSTextStorageEditedCharacters`, and the REAL vendored kernel's
    // `TGRichTextInputDecLayoutController` is attached as an observer of THIS text storage even
    // under the fake-CLIENT test harness (only the Swift-side document/lifecycle/etc. clients are
    // fake — the kernel itself is real; R3's own header doc comment on the reverted third call site
    // documents the identical reactive-observer mechanism). That observer can react SYNCHRONOUSLY,
    // during `edited:`, by reading `-string` again — and since `-string` now syncs (this task's own
    // fix), a REENTRANT sync mid-mutation sees a revision the bridge has ALREADY bumped
    // (`commitPreparedMutation` runs BEFORE this bracket) but a `documentPlainTextInRange:` answer
    // that has NOT caught up for any document client that doesn't track mutations (the same
    // canned-fake class of staleness `_lastSyncedBridgeRevision` exists to dodge) — so the reentrant
    // sync CLOBBERS the mutation this bracket just applied, one line after it wrote it. Measured
    // directly: `IDBackendFamily4Tests.test_insertText_commitsExactlyOnce_andPublishesApplied`'s
    // mirror read back the PRE-edit "Alpha\nBeta" immediately after `replaceCharactersInRange:`
    // itself logged the correct post-edit `mirrorAfter` value moments earlier — the reentrant call
    // undid it inside `edited:`, between those two log lines. `-string` skips its sync while this
    // is set, matching the ordinary (non-reentrant) case where nothing has changed for it to miss:
    // the bracket's OWN code is what just made `mirror` correct, and no interleaved external change
    // can be observed from inside a synchronous ObjC call stack.
    BOOL _isApplyingMutation;
}

/// `mirror` is `[[NSMutableAttributedString alloc] init]` in the designated initializer — the ONLY
/// place it is EMPTY-ALLOCATED. It starts at length 0, deliberately: `bridge` is not wired yet at
/// `-init` time (`IDTextEditorBackendClientBridge.init` sets `storage.bridge = self` only after
/// constructing `storage`), so there is nothing to seed from here. `synchronizeMirrorWithDocumentIfNeeded`
/// (below) is what brings it to the real document's content, once a `bridge` exists to ask.
- (instancetype)init {
    self = [super init];
    if (self) {
        _mirror = [[NSMutableAttributedString alloc] init];
    }
    return self;
}

- (NSMutableAttributedString *)mirror {
    return _mirror;
}

/// Task R3 — see the header's own doc comment for the full rationale and the two call sites (plus
/// the third that was tried and reverted).
/// `respondsToSelector:` guards are load-bearing, not defensive over-caution: all three bridge
/// methods below are `@optional` (`TGRichTextInputDecClientBridge.h`), and `StubBridge`
/// (`CanvasCallbackInstallationTests.swift`) is a real, in-tree conformer that implements neither
/// — the same reason every other optional-group call site in this module already guards.
- (void)synchronizeMirrorWithDocumentIfNeeded {
    // Task R7 — reentrancy guard. See `_isApplyingMutation`'s own doc comment: a sync that fires
    // WHILE `replaceCharactersInRange:withString:`'s own mutation bracket is still open (a reentrant
    // call from an `edited:` observer) must be a no-op — `mirror` is, by construction, already
    // correct for what that bracket just wrote, and any bridge answer sampled mid-bracket can be
    // stale relative to it.
    if (_isApplyingMutation) {
        return;
    }
    id<TGRichTextInputDecClientBridging> bridge = self.bridge;
    if (bridge == nil ||
        ![bridge respondsToSelector:@selector(documentUTF16Length)] ||
        ![bridge respondsToSelector:@selector(documentPlainTextInRange:)]) {
        return;
    }
    // Task R7 (cluster 4) — REVISION-GATED fast path, checked BEFORE fetching `documentPlainTextInRange:`
    // at all, using the PRIVATE `_lastSyncedBridgeRevision`/`_hasSyncedMirror` pair (see the ivar's
    // own doc comment for why NOT the public `revision` property). A bridge reporting the SAME
    // revision this method itself last synced the mirror against is proof the mirror is already
    // correct — no re-derivation needed. This is not merely a performance guard: calling `-string`
    // from a witness this task ALSO now syncs from (`-string` itself, below) made this method run on
    // every read, and unconditionally re-deriving the projection CLOBBERED a mutation that had just
    // landed against any document client whose `documentPlainTextInRange:` does not itself track
    // mutations — a canned/static test double (`FakeInputDocumentClient`, whose `plainTextToReturn`
    // never updates on a fake "successful" commit). Measured directly: without this gate,
    // `IDBackendFamily4Tests.test_insertText_commitsExactlyOnce_andPublishesApplied`'s own closing
    // `.string` read re-fetched the STALE canned "Alpha\nBeta" and overwrote the mirror's freshly-
    // mutated "aAlpha\nBeta" back to the pre-edit value, one line after the mutation had correctly
    // written it. The REAL document client (`TelegramDocumentInputClient`) has no such staleness —
    // its `documentRevision`/`documentPlainTextInRange:` are live reads of the SAME canvas — so this
    // gate changes nothing there beyond skipping needless re-fetches once already in sync.
    if (_hasSyncedMirror &&
        [bridge respondsToSelector:@selector(documentRevision)] &&
        [bridge documentRevision] == _lastSyncedBridgeRevision) {
        return;
    }
    NSInteger documentLength = [bridge documentUTF16Length];
    if (documentLength < 0) {
        documentLength = 0;
    }
    // Task R7 (cluster 4) — `documentLength` above is the STRUCTURAL axis length (this document
    // model's own node-token addressing; see `TGRichTextInputDecLayoutController.m`'s
    // `id_characterRangeForTextRange:` doc comment for the full account), but `mirror` is built
    // from `documentPlainTextInRange:`'s DENSE plain-text projection — a SHORTER string on any
    // document with more than one top-level block (every paragraph's own open/close boundary
    // tokens, and each inter-paragraph gap, collapse to nothing or to one `"\n"`). Comparing
    // `mirror.length` against the structural `documentLength` therefore NEVER matched for such a
    // document — the "already the right length" fast path below was dead on exactly the documents
    // that exercise it, forcing a full mirror rebuild (and its `edited:` notification, the trigger
    // R3's own reverted third call site found reactive-storm-prone) on EVERY call, not only when
    // content genuinely changed. Fetching `text` first and comparing against ITS length (the actual
    // axis `mirror` lives on) restores a real fast path: a mirror already holding the current
    // projection is left untouched, exactly matching the ORIGINAL intent this method's own header
    // still describes.
    NSString *text = [bridge documentPlainTextInRange:NSMakeRange(0, (NSUInteger)documentLength)];
    if (text == nil) {
        // The bridge could not answer (e.g. mid-teardown) — leave the mirror as it is rather
        // than clobber it with an empty string; the next call gets another chance.
        return;
    }
    if ([self.mirror.string isEqualToString:text]) {
        // Already in sync — no mutation, no `edited:` notification, no reactive re-entry into the
        // real kernel's own observers. A same-length CONTENT swap (e.g. an undo that replaces one
        // paragraph with a different one of equal size) is covered too now (the full string
        // compares, not just its length) — R3's own narrower length-only check could not catch that
        // case, though it was never the `NSMutableRLEArray … Out of bounds` exception R3 fixed
        // (a strict location-past-length condition, unaffected either way).
        //
        // Task R7 — adopt the revision here too (the PRIVATE tracking pair, so the NEXT call
        // short-circuits on the gate above instead of re-fetching and re-comparing `text` again for
        // no reason).
        //
        // **Task D4c — `self.revision` MUST be adopted here as well, and R7 adopting only the
        // private pair is what made a backspace after a formatting toggle do NOTHING AT ALL.**
        // R7's ivar doc comment says "deliberately NOT the public `revision` property" — that
        // warning is about the GATE above (which must not be fooled by `insertText(_:)`'s own
        // unrelated write into `self.revision`), NOT about this adoption. The two mean different
        // things and the distinction is the whole bug: `_lastSyncedBridgeRevision` records "the
        // mirror's CONTENT is current as of revision N", while `revision` is the baseline every
        // kernel-driven mutation hands `prepareAndCommitReplacementInRange:…expectedRevision:`,
        // which `TelegramDocumentInputClient.prepareMutation` compares for exact equality
        // (`guard expectedRevision == revision else { return terminal(.revisionMismatch) }`). The
        // full-rebuild tail below has always set BOTH — this branch set only the first, so the two
        // exit paths of one method disagreed about what "synchronized" leaves behind.
        //
        // Reaching this branch with a MOVED revision is not a corner case, it is exactly what an
        // ATTRIBUTE-ONLY document change looks like: `DocumentCanvasView.applyCharacterToggle`
        // (bold/italic/underline/strikethrough/spoiler/inline-code) bumps `documentRevision`
        // (`+Editing.swift`, "one revision per editing transaction, even for a no-op body") while
        // leaving every character where it was, so `text` still equals `mirror.string`. The next
        // kernel-driven mutation — `deleteBackward()`, `setMarkedText(_:selectedRange:)`, anything
        // UIKit's private controller drives through this façade rather than through
        // `IDTextEditorBackend.insertText(_:)` (the ONE entry point that refreshes `revision`
        // itself) — then declared a baseline one revision behind and was rejected
        // `.revisionMismatch`. That rejection reports through
        // `lifecycleClient.backendDidRejectMutation`, whose Telegram implementation is an EMPTY
        // BODY, so it surfaced as a silent no-op with no exception, no contract violation and no
        // trace. Measured on the D4b corpus as 18 differing fields across `delete-run-boundary` and
        // `backspace-block-boundary`; pinned by
        // `IDBackendFormattingThenDeleteTests` (all four tests) and
        // `IDTextStorageFacadeTests.test_anAttributeOnlyRevisionBump_isAdoptedIntoTheMutationBaseline`.
        //
        // This also restores what R3's own comment on `replaceCharactersInRange:withString:`
        // already claims about this method — "a stale `self.revision` ... is corrected together
        // with the mirror's content" — which stopped being true for equal content the moment R7
        // added this fast path.
        _hasSyncedMirror = YES;
        if ([bridge respondsToSelector:@selector(documentRevision)]) {
            uint64_t currentRevision = [bridge documentRevision];
            _lastSyncedBridgeRevision = currentRevision;
            self.revision = currentRevision;
        }
        return;
    }
    NSRange oldRange = NSMakeRange(0, self.mirror.length);
    _isApplyingMutation = YES;
    [self beginEditing];
    [self.mirror replaceCharactersInRange:oldRange withString:text];
    [self edited:NSTextStorageEditedCharacters
            range:oldRange
   changeInLength:(NSInteger)text.length - (NSInteger)oldRange.length];
    [self endEditing];
    _isApplyingMutation = NO;
    _hasSyncedMirror = YES;
    if ([bridge respondsToSelector:@selector(documentRevision)]) {
        uint64_t currentRevision = [bridge documentRevision];
        _lastSyncedBridgeRevision = currentRevision;
        self.revision = currentRevision;
    }
}

#pragma mark - NSTextStorage primitives (all four; NSTextStorage is abstract in exactly these)

- (NSString *)string {
    // Task R7 (cluster 4, "`text(in:)` returns empty") — THE losing hop. UIKit's real private
    // input controller reads document content through this ONE `NSTextStorage` primitive (verified
    // by instrumentation: `-string` is called before `characterRangeForTextRange:` on every plain
    // `-textInRange:`), never through `attributedTextInRange:`/`documentPlainTextInRange:` directly.
    // `synchronizeMirrorWithDocumentIfNeeded` previously ran only at `attach(to:)` (when a freshly-
    // attached host's document is normally still empty — content is seeded moments later) and at the
    // top of `replaceCharactersInRange:withString:` (a MUTATION, which a pure read never reaches). So
    // any content set on the host AFTER attach through a channel that isn't itself a kernel-driven
    // mutation — `DocumentCanvasView.setBlocks`/`setParagraphs`, the production `document` setter's
    // `reload` included — left `mirror` at its `-init`-time empty length forever, and every witness
    // that resolves through the private controller's own text-storage read (not just `text(in:)`
    // itself, but its `characterRangeForTextRange:`/geometry/position witnesses that consult content
    // length) saw an empty document while `bridge` reported real content. Syncing HERE, at the read
    // primitive itself, closes that gap for every caller uniformly — cheap on the (overwhelmingly
    // common) already-in-sync path, which is a plain length compare with no bridge round-trip.
    [self synchronizeMirrorWithDocumentIfNeeded];
    return self.mirror.string;
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location
                                                 effectiveRange:(NSRangePointer)range {
    return [self.mirror attributesAtIndex:location effectiveRange:range];
}

/// THE crossing point: UIKit's private input controller drives every keystroke, paste, dictation
/// result, and marked-text edit through this ONE method — a raw range replace with no semantic
/// intent attached. The latch (`currentIntent`, set by the pre-mutation canvas thunks BEFORE UIKit
/// calls this) is what recovers "pressed Return" vs "typed a newline" vs "deleted backward". See
/// `IDTextEditorBackendIntent.mutation(for:range:text:selection:)` for the recovery itself.
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
    // Task R3 — the general fix, applied at the ONE call site every `NSMutableRLEArray … Out of
    // bounds` failure in R1's cluster 5 actually threw from. Runs BEFORE `expectedRevision:` is
    // read below, so a stale `self.revision` (never explicitly refreshed on this path before —
    // `setMarkedText`/`+TextBackend.swift` never wrote it, unlike `insertText(_:)`) is corrected
    // together with the mirror's content, not just its length.
    [self synchronizeMirrorWithDocumentIfNeeded];
    // Task R7 (cluster 4) — `range` (like every position/range this facade receives) is on the
    // STRUCTURAL axis, but `mirror` is built from the PLAIN-TEXT projection (see this method's own
    // `-string` sibling and `TGRichTextInputDecLayoutController.m`'s `id_characterRangeForTextRange:`
    // for the full account of the two axes). Writing `range` verbatim into `mirror` mis-locates and
    // mis-sizes the edit on any document with more than one top-level block — reproduced exactly: a
    // caret UIKit itself resolved to structural offset 5 ("end of Alpha") landed the inserted "!"
    // between 'h' and 'a' instead. Convert BOTH endpoints to the plain-text axis BEFORE the mutation
    // below runs (which changes what `documentPlainTextInRange:` would answer for THIS range), using
    // the document's CURRENT (pre-mutation) content — exactly like `-string`'s own resync, this reuses
    // the projection, not a new position concept.
    //
    // `respondsToSelector:` guard, load-bearing like every other optional-group call site in this
    // module: `documentUTF16Length` is `@optional`, and `IDTextStorageFacadeTests`' own
    // `FakeFacadeBridge` conforms to only the two `@required` members — an unguarded call here
    // crashed it with `unrecognized selector` (found by that suite going from 6/6 green to 5
    // crashes). No conversion is possible without it, so `range` is used verbatim — the pre-R7
    // behavior, correct for any bridge whose structural and plain-text axes coincide (every fake
    // that doesn't model the distinction, including this one).
    //
    // The actual conversion is computed inside `beforeCommit` below, NOT here — see that overload's
    // own doc comment (in the header) for why: computing it unconditionally, before the disposition
    // is known, cost two `documentRead`s even on a REJECTED/no-change transaction, which
    // `IDBackendMutationContractTests`' event-log contract (a different cluster's own invariant)
    // counts exactly. `__block` so the `beforeCommit` closure below can assign it.
    __block NSRange plainRange = range;
    BOOL bridgeHasConversionSupport = [self.bridge respondsToSelector:@selector(documentUTF16Length)];
    // Task D3c — `range` is NOT always structural, despite the comment above (kept for the callers
    // it IS true of). Two intents reach this method through the KERNEL'S OWN internal editing —
    // `TGRichTextInputDecIntentDeleteBackward` (backward delete: the kernel grapheme-cluster-scans
    // `-string`, this facade's plain-text-backed `NSTextStorage` surface, handed out verbatim as
    // `textStorageFacade()`) and `TGRichTextInputDecIntentMarkedText` (IME composition: the private
    // controller drives `setMarkedText`/commit directly against the same surface) — and BOTH hand
    // back a range ALREADY on `mirror`'s own plain-text axis, never having gone through our
    // structural position model at all, because in both cases the kernel treats `self` as an
    // ordinary `NSTextStorage` it owns outright. Confirmed by direct measurement for the delete
    // case: forcing `TGRichTextInputDecLayoutController.id_rangeOfCharacterClusterAtIndex:type:`
    // (Family 1's own grapheme-width helper, called separately by
    // `preflightBackwardDeleteRanges`/`backwardDeleteRange` for THEIR cached answer) to return a
    // different length left THIS method's own `range` argument byte-identical — the two are
    // independent, and the kernel's actual `replaceCharactersInRange:` call does not consult that
    // helper's result at all. For markedText, `cjk-compose-commit`'s own differential trace pins it
    // the same way: composing "にほ" at the caret landed a plain-text axis unit early ("Alphにほa"
    // instead of "Alphaにほ") — exactly what re-converting an ALREADY-plain range as structural
    // produces, the identical shape as the delete case. Every OTHER intent (`insertText`/
    // `programmatic`/`paste`/`dictation`) still arrives here via `IDTextEditorBackend
    // .replace(_:withText:)` (`mutationRange` built from two `TGRichTextInputDecPosition
    // .utf16Offset`s — structural by construction), proven structural by `type-one-char`/
    // `return-splits-paragraph`/`copy-then-paste`/`paste-over-a-selection` keeping their CONTENT
    // identical to legacy — so this is a narrow, intent-scoped exception, not a reversal of R7's
    // own finding.
    void (^computePlainRange)(void) = ^{
        if (self.currentIntent == TGRichTextInputDecIntentDeleteBackward ||
            self.currentIntent == TGRichTextInputDecIntentMarkedText) {
            plainRange = range;
            return;
        }
        NSInteger documentLengthBeforeMutation = [self.bridge documentUTF16Length];
        NSInteger plainLocation = TGPlainTextOffsetForStructuralOffset(
            self.bridge, (NSInteger)range.location, documentLengthBeforeMutation);
        NSInteger plainEnd = TGPlainTextOffsetForStructuralOffset(
            self.bridge, (NSInteger)(range.location + range.length), documentLengthBeforeMutation);
        plainRange = NSMakeRange((NSUInteger)plainLocation, (NSUInteger)MAX(plainEnd - plainLocation, 0));
    };

    TGRichTextInputDecMutationOutcome outcome = {0};
    BOOL applied;
    if (bridgeHasConversionSupport &&
        [self.bridge respondsToSelector:
            @selector(prepareAndCommitReplacementInRange:text:intent:expectedRevision:beforeCommit:outOutcome:)]) {
        // The common, optimized path: convert ONLY once we know the transaction reached `.ready` —
        // zero extra reads on a terminal (rejected/no-change) disposition.
        applied = [self.bridge prepareAndCommitReplacementInRange:range
                                                               text:string
                                                             intent:self.currentIntent
                                                   expectedRevision:self.revision
                                                       beforeCommit:computePlainRange
                                                         outOutcome:&outcome];
    } else {
        // Fallback for a bridge that only implements the plain (pre-R7) selector — a real conformer
        // (`IDTextEditorBackendClientBridge`) always implements both, so this is test-double-only.
        // Converting unconditionally here is the pre-optimization behavior: correct, just not free
        // on the terminal path.
        if (bridgeHasConversionSupport) {
            computePlainRange();
        }
        applied = [self.bridge prepareAndCommitReplacementInRange:range
                                                               text:string
                                                             intent:self.currentIntent
                                                   expectedRevision:self.revision
                                                         outOutcome:&outcome];
    }
    // Single-transaction latch: reset UNCONDITIONALLY, applied or not, so a rejected/no-change
    // transaction can never leave a stale intent for the NEXT, unrelated mutation to inherit.
    self.currentIntent = TGRichTextInputDecIntentProgrammatic;
    if (!applied) {
        // Rejected or no-change: no `edited:` post, no mirror mutation, no notifications — the
        // mirror (and therefore everything UIKit reads via `string`/`attributesAtIndex:...`) is
        // left exactly as it was before this call.
        return;
    }
    _isApplyingMutation = YES;
    [self beginEditing];
    [self.mirror replaceCharactersInRange:plainRange withString:string];
    [self edited:NSTextStorageEditedCharacters
            range:plainRange
   changeInLength:(NSInteger)string.length - (NSInteger)plainRange.length];
    [self endEditing];
    _isApplyingMutation = NO;
    self.revision = outcome.revision;
    // Task R7 — mark the mirror synced to THIS revision directly, not just via `self.revision`
    // above (see the ivar's own doc comment for why the two are tracked separately). Without this,
    // the VERY NEXT `synchronizeMirrorWithDocumentIfNeeded` call (from `-string`, immediately after
    // this method returns — exactly what `IDBackendFamily4Tests
    // .test_insertText_commitsExactlyOnce_andPublishesApplied`'s own closing assertion does) would
    // see `_lastSyncedBridgeRevision` still at its PRE-mutation value, re-attempt a resync, and — for
    // a document client whose `documentPlainTextInRange:` doesn't track mutations — clobber the
    // mirror content this method just correctly wrote with the client's stale canned answer.
    _hasSyncedMirror = YES;
    _lastSyncedBridgeRevision = outcome.revision;
}

/// Attribute-only edits carry no semantic intent Telegram's document model consumes — they are a
/// read-model concern, not a mutation the bridge's two-phase transaction needs to see. The document
/// learns about typing-attribute changes through the typing-attributes client, not through this path.
- (void)setAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                 range:(NSRange)range {
    [self.mirror setAttributes:attributes range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

@end

#endif
