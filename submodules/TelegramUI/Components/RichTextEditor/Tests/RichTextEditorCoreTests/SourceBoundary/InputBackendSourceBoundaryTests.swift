import XCTest

/// The eight rejections the spec's "Source-boundary tests" section requires. Rules R2…R5 and the
/// R6 ratchet are extended by later tasks; R1, R1b and R8 are clean from day 1.
///
/// R6 and R7 (deviation D19) could not be clean on day 1 — the legacy canvas owned writable
/// `anchor`/`head` and the UIKit identity types outright, until Phases 4-5 (Tasks 36a-40b, 44) moved
/// that authority into the backend. So both shipped as DECREASING-BASELINE ratchets: a regression
/// (the count going UP) fails immediately; the count is only allowed to go down. Their baselines
/// were measured fresh here rather than copied from the plan's D19 table, which was written against
/// an earlier state of the tree.
///
/// **TASK 40b RETIRED R7's RATCHET.** `test_selectionWriteSiteBaseline_R7_doesNotRegress` is gone,
/// replaced by the spec's actual rule, `test_exactlyOneWritableSelectionAuthority` — absolute zero
/// for the selection half, an exact shrinking allowance for the composition half that Task 41 must
/// empty.
///
/// **TASK 44 RETIRED R6's RATCHET, on the same schedule and for a sharper reason.**
/// `test_uiKitIdentityLeakBaseline_R6_doesNotRegress` is gone, replaced by
/// `test_noBackendPositionDowncastsOutsideBackend` — absolute zero for both minting/unwrapping AND
/// bare mentions of the identity types. It could not simply be left alongside: that task renames the
/// three types it scanned for, so it would have passed with 0 offenders forever while testing
/// nothing. Both halves of the schedule are now spent; neither R6 nor R7 has a baseline left.
final class InputBackendSourceBoundaryTests: XCTestCase {

    private func inputBackendSources() -> [URL] {
        RepoLayout.assertResolved()
        return RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
    }

    func test_thereAreInputBackendSourcesToCheck() {
        XCTAssertFalse(inputBackendSources().isEmpty,
                       "the boundary gate must not silently cover nothing")
    }

    /// R1 — no InputDec or private UIKit names in the shared contract files.
    func test_sharedContracts_containNoPrivateOrInputDecNames() {
        let banned = ["NSSelectorFromString", "NSClassFromString", "NSProtocolFromString",
                      "objc_msgSend", "class_addMethod", "class_addProtocol",
                      "objc_setAssociatedObject", "UITextInputController",
                      "UITextInteractionAssistant", "UITextAutoscrolling", "_UITextLayoutCanvasView"]
        for url in inputBackendSources() {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            for name in banned {
                XCTAssertFalse(text.contains(name), "\(url.lastPathComponent) references \(name)")
            }
            XCTAssertNil(text.range(of: #"\bID[A-Z]\w+"#, options: .regularExpression),
                         "\(url.lastPathComponent) references an InputDec-style ID-prefixed name")
        }
    }

    /// R1 (continued) — no Telegram implementation types in the shared contract files.
    ///
    /// **TASK 44 REPOINTED THE LAST THREE NAMES, and that was NOT bookkeeping.** This list ended with
    /// `DocumentTextPosition`/`DocumentTextRange`/`DocumentSelectionRect`; Task 44 renamed those types
    /// to `LegacyTextPosition`/`LegacyTextRange`/`LegacySelectionRect`. Left as they were, those three
    /// entries would have banned identifiers **that no longer exist anywhere in the package** — a rule
    /// that cannot fail is a rule that is not testing anything, and this file has already lost one
    /// instrument that way (the R6 ratchet, retired below, whose whole subject was renamed out from
    /// under it in this same commit). The identity types are still exactly as forbidden in a shared
    /// contract file as they were; only their spelling moved.
    func test_sharedContracts_referenceNoTelegramImplementationTypes() {
        let banned = ["BlockLayoutEngine", "LeafTextRegion", "CanvasBlock", "BlockBox", "BlockStack",
                      "TableBlockBox", "MediaBlockBox", "TableBackingView", "DocumentCanvasView",
                      "NSTextStorage", "NSLayoutManager", "NSTextContainer", "NSTextLayoutManager",
                      "LegacyTextPosition", "LegacyTextRange", "LegacySelectionRect"]
        for url in inputBackendSources() where !url.path.contains("/Clients/")
            && !url.lastPathComponent.hasPrefix("Legacy") {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            for name in banned {
                XCTAssertFalse(text.contains(name),
                               "\(url.lastPathComponent) passes \(name) through the shared boundary")
            }
        }
    }

    /// Existential-friendly invariant protocols (hard invariant / patch-rejection criterion).
    func test_sharedContracts_declareNoAssociatedTypesOrSelfRequirements() {
        for url in inputBackendSources() where !url.path.contains("/Clients/") {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            XCTAssertFalse(text.contains("associatedtype"), "\(url.lastPathComponent)")
            XCTAssertNil(text.range(of: #"->\s*Self\b"#, options: .regularExpression),
                         "\(url.lastPathComponent) has a Self requirement")
        }
    }

    /// R1b — the private-API machinery inventory. Deviation D11 names exactly two pre-existing
    /// offenders (the native-text-checking pair). Re-measuring against the CURRENT tree
    /// (2026-08-17) found a THIRD, unrelated pre-existing offender the plan's D11 text does not
    /// mention: `SpoilerDustView.swift`'s `CAEmitterBehavior` lookup
    /// (`NSClassFromString(["CA","Emitter","Behavior"].joined())` +
    /// `NSSelectorFromString(selector)`), which the package's own CLAUDE.md already documents as a
    /// known, accepted App-Store-review risk ("guarded by a live canary test") predating this seam
    /// entirely — it is Telegram's own private-API integration for the spoiler twinkle effect, not
    /// InputDec's, exactly like the text-checking pair. Flagged here for reviewer sign-off: this
    /// widens D11's allowlist from two files to three. The count stays NON-GROWING (fixed
    /// inventory, not a pattern) — a fourth file tripping this rule is a real new regression.
    ///
    /// **RULE 15 — THIS IS THE ONE PLACE THE COUNT IS STATED, and it is stated here because the
    /// `allowed` Set below is right underneath it.** Task 34's review escalated the reason: D11's plan
    /// row and every task brief generated from it say "the identical two-file allow-list", and this
    /// rule's own failure message used to repeat it — three copies of a number that has been THREE
    /// since the rule shipped. The message now points here instead of restating, D11's plan row records
    /// that the third file is pre-existing and unrelated to the input seam, and any prose that needs the
    /// count should cite this rule rather than name a number. **A count restated in three places is how
    /// four consecutive tasks on this branch each lost a fix round.** Nothing about the third file is
    /// drift: `SpoilerDustView.swift` predates the seam and no seam task has touched it.
    func test_privateRuntimeLookups_areConfinedToTheInventoriedFiles() {
        let allowed: Set<String> = ["NativeTextChecking.swift",
                                    "DocumentCanvasView+NativeTextCheckingClient.swift",
                                    "SpoilerDustView.swift"]
        var offenders: [String] = []
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            let dynamic = text.contains("NSSelectorFromString") || text.contains("NSClassFromString")
                || text.contains("objc_msgSend")
            if dynamic && !allowed.contains(url.lastPathComponent) {
                offenders.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(offenders, [],
                       "new private-runtime lookup outside the inventoried files — the `allowed` Set " +
                       "above is the authority and this rule's doc comment says how many there are " +
                       "and why (this message used to restate the count as \"two\", which has been " +
                       "wrong since the rule shipped with three): \(offenders)")
    }

    /// R8 — no InputDec production sources, and no ObjC under Sources/RichTextEditorUIKit.
    /// The last clause is load-bearing: BUILD:43-45 globs only **/*.swift, so a .m placed there
    /// compiles under SwiftPM and vanishes from the app with NO error.
    ///
    /// SCOPE (decision 5). This rule scans Sources/ ONLY, and that is deliberate, not an
    /// oversight. Phase 0b vendors five InputDec ObjC pairs into
    /// Tests/RichTextEditorUIKitTests/Differential/ObjC/ as a test-only SwiftPM target. Those
    /// are test-support sources: they never link into the app, never enter the Bazel build
    /// (which has no test target for this package), and contain no private selector, no
    /// runtime lookup and no kernel code. The spec's gate forbids InputDec **production**
    /// code, which remains stage 2's Task A4. Do not widen this rule to Tests/ — doing so
    /// would fail the gate on the very instrument that proves the port.
    func test_noInputDecSourcesAndNoObjectiveCUnderTheSwiftTarget() {
        RepoLayout.assertResolved()
        guard let e = FileManager.default.enumerator(at: RepoLayout.uiKitSources,
                                                     includingPropertiesForKeys: nil) else {
            return XCTFail("cannot enumerate Sources/RichTextEditorUIKit")
        }
        for case let url as URL in e {
            XCTAssertFalse(["m", "mm", "h", "c"].contains(url.pathExtension),
                           "non-Swift source under the Swift target: \(url.lastPathComponent)")
            XCTAssertNil(url.deletingPathExtension().lastPathComponent
                .range(of: #"^ID[A-Z]"#, options: .regularExpression),
                "InputDec-style source present before the Phase 6 gate: \(url.lastPathComponent)")
        }
    }

    /// R6 (ABSOLUTE, since TASK 44) — **no UIKit identity object is TEXTUALLY minted, TEXTUALLY
    /// unwrapped, or NAMED outside the backend.**
    ///
    /// **READ THE WORD "TEXTUALLY". IT IS NOT HEDGING; IT IS THE RULE'S ACTUAL REACH, and the first
    /// version of this header did not have it.** This is a source-text scan. It sees the spelling
    /// `LegacyTextRange(…)`, the spelling `x as? LegacyTextPosition`, and the bare identifier. **It
    /// cannot see a type bound by INFERENCE**, and that is not a hole a regex can close — see KNOWN
    /// LIMITS below, where the exact shape that shipped green against this rule is recorded, along
    /// with the second limit (typealias laundering) and what was done about each.
    ///
    /// **This REPLACES `test_uiKitIdentityLeakBaseline_R6_doesNotRegress`, and replacing it was not
    /// optional.** That ratchet scanned for the names `DocumentTextPosition` / `DocumentTextRange` /
    /// `DocumentSelectionRect`. This task RENAMES those types to `LegacyTextPosition` /
    /// `LegacyTextRange` / `LegacySelectionRect` and moves them under `S/InputBackend/Legacy/`, so
    /// from the rename forward **zero `Sources/` files contain the old names and the old ratchet
    /// would have passed with 0 offenders forever, while testing nothing** — its subject renamed out
    /// from under it. That is the vacuity class this branch has been bitten by five times; the two
    /// rules were not left side by side, and this one carries the R6 name alone.
    ///
    /// Its final honest reading, taken by temporarily setting its own `baseline` to 0 and reading the
    /// count out of the assertion message rather than re-deriving it with a grep: **8 files**, not the
    /// 10 its constant claimed — the ratchet had two files of slack, and had had them since Task 40a.
    /// The eight were `RichTextEditorView.swift` (the public facade — the D19 "including two in the
    /// public facade" leak), `Input/DocumentTextPosition.swift` itself, `DocumentTokenizer.swift`, and
    /// `DocumentCanvasView+{EditMenu,Interaction,NativeTextCheckingClient,SelectionActions,UITextInput}.swift`.
    /// All eight are cleared by this task.
    ///
    /// **TWO ASSERTIONS, on the codebase's existing two-rule shape** (a precise named rule for the
    /// actionable message, a blunt mention cap for completeness — see
    /// `test_theTokenizerHasExactlyOneConstructionSite`, which uses it for the same reason):
    ///
    ///  1. **CONSTRUCTIONS AND DOWNCASTS.** `LegacyTextRange(…)` and `x as? LegacyTextPosition` are
    ///     the two operations that CONSTITUTE ownership of a UIKit identity object — minting one and
    ///     interpreting one. Zero, outside `S/InputBackend/`.
    ///  2. **BARE MENTIONS.** A `-> LegacyTextRange?` return type or a `let p: LegacyTextPosition`
    ///     matches neither pattern above and is still the type escaping the backend. Also zero — this
    ///     is STRICTER than the brief's regex-only rule, and strictly stricter than the retired
    ///     ratchet, which allowed ten files of mentions.
    ///
    /// **WHAT THE CANVAS USES INSTEAD.** Nothing about this rule says canvas code may not ask for a
    /// caret rect or set a selection. It says the canvas may not name, mint or unwrap the objects.
    /// The three routes it uses instead are all identity-free at the call site:
    ///  * `LegacyTextIdentity` (`S/InputBackend/Legacy/LegacyTextPosition.swift`) — the backend-side
    ///    factory/reader. `LegacyTextIdentity.position(atGlobal:)` hands back a `UITextPosition`;
    ///    `LegacyTextIdentity.globalRange(of:)` takes a `UITextRange` and hands back `(Int, Int)?`.
    ///    The canvas then holds only the neutral UIKit protocol types it has to handle anyway as a
    ///    `UITextInput`, plus plain `Int`s. **The name `LegacyTextIdentity` deliberately does not
    ///    match either pattern above** (`Legacy` is followed by `TextIdentity`, not
    ///    `TextPosition`/`TextRange`).
    ///  * `DocumentCanvasView.caretRect(atGlobal:)` — the identity-free spelling of
    ///    `caretRect(for:)`, which is what the six former `caretRect(for: DocumentTextPosition(n))`
    ///    sites now call. It preserves the path exactly: it mints the same object through the factory
    ///    and calls the same routed member.
    ///  * `DocumentCanvasView.setSelectedGlobalRange(from:to:)` / `.canonicalSelection` /
    ///    `.documentEndOffset` — the canonical-offset selection surface the public facade uses.
    ///
    /// **`S/InputBackend/Legacy/` is the backend, by path, exactly as `/Clients/` already is.** The
    /// two files under it (`LegacyTextPosition.swift`, `LegacyDocumentTokenizer.swift`) are excluded
    /// from this rule by the same `/InputBackend/` path test every other backend file is, and from
    /// `test_sharedContracts_referenceNoTelegramImplementationTypes` by that rule's PRE-EXISTING
    /// `hasPrefix("Legacy")` filename exclusion — no exclusion was added or widened for this task.
    ///
    /// ## KNOWN LIMITS — two, both demonstrated, neither closable by this scan
    ///
    /// **LIMIT 1 — TYPE INFERENCE. A backend member whose RETURN TYPE is an identity type hands one
    /// across the boundary with nothing for this rule to see.** This is not hypothetical: it is what
    /// Task 44 SHIPPED, and its own fix round removed. `DocumentTokenizer.wordRange(at:)` /
    /// `.paragraphRange(at:)` returned `LegacyTextRange?`, and three canvas sites
    /// (`+SelectionActions.swift`'s word and paragraph select, `+NativeTextCheckingClient.swift`'s
    /// spell-check word targeting) bound it as `let r = t.wordRange(at: pos)` and read
    /// `r.from.offset` straight through — a canvas-layer site unwrapping a backend identity object
    /// while BOTH assertions below reported zero, because no type name, construction or downcast
    /// appears at any of the three. **Fixed by removing the leak** (both methods now return
    /// `(from: Int, to: Int)?`), **not by widening the regex**, which could not have caught it at
    /// any width. The durable defence is the same one the rest of this file uses for what a scan
    /// cannot reach: a REVIEWER reading the boundary members' signatures. If you add a member on a
    /// backend type that returns or takes one of the three identity types, this rule will not stop
    /// you and the seam will still be broken.
    ///
    /// **LIMIT 2 — TYPEALIAS LAUNDERING.** A `typealias CanvasCaretPosition = LegacyTextPosition`
    /// declared *inside* `S/InputBackend/` (where the scan does not look) lets a canvas file write
    /// both `CanvasCaretPosition(3)` and `(p as? CanvasCaretPosition)?.offset` with this rule green;
    /// demonstrated and restored at the fix round. It is the residual hole every name-based scan
    /// has, it takes two deliberate edits in two files, and the `LegacyTextIdentity` note above
    /// effectively documents the technique — so it is written down here rather than left for someone
    /// to discover as a trick. (The four Task-43 evasion FORMS — `Name.init(`, `.map(Name.init)`,
    /// typealias-in-the-same-file, metatype — are all closed: the pattern matches `.init(` and the
    /// bare-mention half sees the rest. Limit 2 is specifically about a typealias declared where the
    /// scan cannot reach.)
    ///
    /// Non-vacuity: the file walk is asserted non-empty here, and the two patterns are armed against
    /// synthetic sources in `test_theIdentityLeakScanActuallyDetects_R6` below (Rule 19 — a guard is
    /// proven only by constructing the thing it forbids).
    func test_noBackendPositionDowncastsOutsideBackend() {
        RepoLayout.assertResolved()
        var offenders: [String] = []
        var mentions: [String: Int] = [:]
        var scanned = 0
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources)
        where !url.path.contains("/InputBackend/") {
            scanned += 1
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            if text.range(of: Self.legacyIdentityUsePattern, options: .regularExpression) != nil {
                offenders.append(url.lastPathComponent)
            }
            let m = SwiftSourceScan.identifierMentionCount(in: text, to: Self.legacyIdentityNames)
            if m > 0 { mentions[url.lastPathComponent] = m }
        }

        XCTAssertGreaterThan(scanned, 0,
                             "R6 scanned NO non-backend sources — an expected-zero rule that measured "
                             + "nothing and reported zero is the exact failure this branch keeps hitting")

        XCTAssertEqual(offenders, [],
                       "backend UIKit identity leaks outside the backend: \(offenders). "
                       + "`LegacyTextPosition`/`LegacyTextRange`/`LegacySelectionRect` are the legacy "
                       + "backend's private UIKit identity objects; minting or unwrapping one outside "
                       + "`S/InputBackend/` re-opens the leak Task 44 closed. Use "
                       + "`LegacyTextIdentity.position(atGlobal:)` / `.globalOffset(of:)` / "
                       + "`.range(fromGlobal:toGlobal:)` / `.globalRange(of:)`, or the canvas's "
                       + "`caretRect(atGlobal:)` / `setSelectedGlobalRange(from:to:)`.")

        XCTAssertEqual(mentions, [:],
                       "backend UIKit identity type NAMED outside the backend: "
                       + "\(mentions.sorted(by: { $0.key < $1.key })). This is the BLUNT half of the "
                       + "rule: a `-> LegacyTextRange?` return type or a `LegacyTextPosition` "
                       + "parameter matches neither the construction nor the downcast pattern and is "
                       + "still the type escaping the backend.")
    }

    /// The three identity type names, in one place so the two R6 assertions and the detection test
    /// below cannot drift apart.
    private static let legacyIdentityNames = ["LegacyTextPosition", "LegacyTextRange", "LegacySelectionRect"]

    /// Constructions (`Name(`, `Name.init(`) and downcasts (`as?`/`as!` Name) of the three identity
    /// types. Kept next to the names above for the same reason.
    private static let legacyIdentityUsePattern =
        #"as[?!]\s*Legacy(TextPosition|TextRange|SelectionRect)"#
        + #"|(?<![\w.])Legacy(TextPosition|TextRange|SelectionRect)(?:\s*\.\s*init)?\s*\("#

    /// Rule 19 for R6 — the two patterns armed against synthetic sources, because R6's real assertions
    /// both expect ZERO and an expected-zero scrape has failed four distinct ways on this branch,
    /// always by measuring nothing and reporting zero. The DOES-NOT-DETECT half is as load-bearing as
    /// the detects half: `LegacyTextIdentity.position(atGlobal:)` is the replacement every canvas call
    /// site now spells, and if someone later "simplifies" the pattern to a bare `Legacy` prefix these
    /// lines go red and they find out why before the whole canvas layer starts failing R6.
    ///
    /// Fixtures spell `example()`, never `func test_…` (R14's fix-round lesson: a synthetic fixture
    /// that spells `func test_…` inflates any per-file count taken over the real tree).
    func test_theIdentityLeakScanActuallyDetects_R6() {
        func uses(_ line: String) -> Bool {
            line.range(of: Self.legacyIdentityUsePattern, options: .regularExpression) != nil
        }
        func mentions(_ line: String) -> Int {
            SwiftSourceScan.identifierMentionCount(in: line + "\n", to: Self.legacyIdentityNames)
        }

        // DETECTS — construction, `.init` construction, and both downcast spellings.
        XCTAssertTrue(uses("        return LegacyTextRange(LegacyTextPosition(0), LegacyTextPosition(1))"))
        XCTAssertTrue(uses("        let p = LegacyTextPosition.init(3)"))
        XCTAssertTrue(uses("        let r = newValue as? LegacyTextRange"))
        XCTAssertTrue(uses("        let r = newValue as! LegacyTextRange"))
        XCTAssertTrue(uses("        let s = LegacySelectionRect(rect: .zero, containsStart: true, containsEnd: true)"))

        // DOES NOT DETECT — the sanctioned identity-free replacements. `LegacyTextIdentity` shares the
        // `Legacy` prefix on purpose (it IS the backend's identity surface) and must never match.
        XCTAssertFalse(uses("        return LegacyTextIdentity.position(atGlobal: 3)"))
        XCTAssertFalse(uses("        return LegacyTextIdentity.range(fromGlobal: 0, toGlobal: 1)"))
        XCTAssertFalse(uses("        return caretRect(atGlobal: head)"))
        XCTAssertFalse(uses("        canvas.setSelectedGlobalRange(from: 0, to: end)"))
        // A member named `.legacyTextRange` on some other type is not the identity type being minted.
        XCTAssertFalse(uses("        return backend.legacyTextRange(from: 0, to: 1)"))

        // The blunt half sees every spelling, INCLUDING the ones the pattern above cannot.
        // **The first fixture is not a hypothetical: it is verbatim the signature
        // `DocumentTokenizer.wordRange(at:)` shipped with, and the reason the blunt half exists.**
        // The bare-mention scan catches it — but only where the scan LOOKS, and that declaration sat
        // inside `S/InputBackend/` while its three callers, outside, bound the type by inference.
        // See R6's KNOWN LIMITS: this line proves the mention half works, not that the seam is tight.
        XCTAssertEqual(mentions("    func wordRange(at pos: Int) -> LegacyTextRange? { nil }"), 1)
        XCTAssertEqual(mentions("    typealias T = LegacyTextPosition"), 1)
        XCTAssertEqual(mentions("        let m: LegacyTextPosition.Type = LegacyTextPosition.self"), 2)
        XCTAssertEqual(mentions("        return LegacyTextIdentity.position(atGlobal: 3)"), 0)
    }

    /// R7 (ABSOLUTE, since Task 40b) — **exactly one writable selection or composition authority.**
    /// This replaces `test_selectionWriteSiteBaseline_R7_doesNotRegress`, the decreasing-baseline
    /// ratchet that carried the rule from D19 through Phase 5. Its lineage, kept because the numbers
    /// are the only record of how the phase actually went: 111/17 (the plan's D19 figure) → 113/17
    /// (measured 2026-08-17) → 117/17 (Task 14's four `legacyApplyMutation` seat lines) → 115/17
    /// (Task 35, bookkeeping: the two `var anchor = 0` / `var head = 0` DECLARATIONS became computed
    /// forwarders) → 69/14 (Task 37) → 33/8 (Task 38) → 7/3 (Task 39) → **the constant it carried
    /// when this task deleted it was 7/3, and the tree underneath it measured 1 site / 1 file —
    /// `DocumentCanvasView+Tables.swift`'s `guard let anchor = a.box.tableMap().anchor(…)`, a FALSE
    /// POSITIVE.** So the genuine canvas-layer selection-write count was already ZERO before this
    /// task changed a line; Task 40a's compile gate is what drove it there. (Measured the way that
    /// test's own note prescribed — both baselines temporarily set to `0`, the test run, the figures
    /// read out of the assertion messages — not re-derived with a grep that might agree by luck.)
    ///
    /// **The rule has two halves and they FAIL SEPARATELY, on purpose.** A single merged assertion
    /// would let a newly added selection writer hide inside the composition allowance below, which
    /// is the failure mode this phase's history is largely made of.
    ///
    ///  - **Selection half (`anchor`, `head`): absolute zero, asserted, and verified by running it.**
    ///  - **Composition half (`markedRange`, `markedTextIsPrediction`, `compositionUndoSnapshot`,
    ///    `compositionAnchorHead`): absolute zero as of TASK 41.** It carried an exact, shrinking
    ///    allowance of `["DocumentCanvasView+MarkedText.swift": 16]` until that task, because those
    ///    sixteen writes were stage-1 canvas composition state and moving them was Task 41's entire
    ///    subject. They are moved; the allowance is gone.
    ///
    /// **What this scan does NOT cover.** The complete, measured inventory — four gaps, two shapes
    /// that only look like gaps, and one residual false positive — lives at
    /// `SwiftSourceScan.inputStateWriteCount(in:to:)` and is deliberately not restated here. The two
    /// that change how you read a FAILURE of this test:
    ///  1. **Re-introduced canvas STORAGE.** `var anchor = 0` is a DECLARATION and the pattern skips
    ///     declarations. Covered exactly, at runtime, by
    ///     `SelectionAuthorityTests.test_theCanvasHasNoWritableSelectionSurface` /
    ///     `test_thereIsExactlyOneStoredCopyOfTheSelection`, which reflect over a live
    ///     `DocumentCanvasView` — a stronger check than any regex, and the reason this one need not
    ///     try.
    ///  2. **A reassigned local `var`** (`var anchor = 0` … later `anchor = 5`) is reported as an
    ///     offender. Erring that way is correct for a boundary gate, but it means a red here is not
    ///     yet proof of a second authority — open the file first. The fix is to rename the local
    ///     (precedent: `LegacyRichTextInputBackend+Mutation.swift`'s `currentAnchor`/`currentHead`).
    ///
    /// Nothing in `Sources/RichTextEditorUIKit/InputBackend/` is scanned — that IS the authority.
    ///
    /// For the SELECTION half every gap is academic as of this task: `DocumentCanvasView`'s
    /// `anchor`/`head` are get-only computed projections of the backend, so any write, qualified or
    /// not, in `Sources/` or `Tests/`, **fails to build**. The composition half has no such compiler
    /// backing until Task 41, which is what makes this scan load-bearing rather than ceremonial.
    ///
    /// **AND THIS TEST IS NOT THE WHOLE RULE.** It sees writes to the canvas's OWN names. The other
    /// half of "one writable authority" — the enumerated set of callers that reach the backend's
    /// selection through its own API, and the concrete-downcast door into its stores — is
    /// `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` immediately below. Task 40b's reviewer
    /// found that door by planting it and watching THIS test stay green; do not treat a green here
    /// as "nothing can write the selection".
    ///
    /// **THE PATTERN IS TIGHTENED, NOT WEAKENED — and no filename exclusion was added.** D19's raw
    /// grep produces 10 false positives on this tree (8 in `TableBlockBox.swift`, 1 in
    /// `DocumentCanvasView+Tables.swift` — all `let anchor = …` table-span locals — and 1 in
    /// `DocumentCanvasView.swift`, the `var markedTextIsPrediction = false` declaration). The old
    /// ratchet bought two of those files off with a filename exclusion list and its own note called
    /// that debt; the durable fix it deferred was "excluding `let`/`var` declarations from the
    /// pattern", and that is what `SwiftSourceScan.inputStateWriteCount(in:to:)` does. It is
    /// strictly NARROWER than a filename exclusion: a real `anchor = …` write inside
    /// `TableBlockBox.swift` is now caught, where the old ratchet could never have seen it.
    /// `test_theWritableAuthorityScanActuallyDetects` arms both halves against synthetic sources,
    /// per Rule 19 — a guard is proven only by constructing the thing it forbids.
    ///
    /// **NEITHER HALF'S GREEN IS VACUOUS, and TASK 41 had to re-earn that.** An expected-zero scrape
    /// has failed four distinct ways on this branch, always by measuring nothing and reporting zero.
    /// Until Task 41 the control was free: the composition half asserted an EXACT non-zero figure
    /// (16 sites in a named file) over the SAME loop, so a `swiftFiles(under:)` that returned
    /// nothing, a stripper that blanked everything, or a regex that stopped compiling reddened it in
    /// the very same run. Emptying the allowance took that away — the debt Task 40b recorded at this
    /// site — and it is replaced IN THE SAME LOOP by a per-file PLANTED PROBE: every file is scanned
    /// a second time with the probe appended to its RAW text and the concatenation re-stripped, and
    /// exactly two of the probe's four planted writes (two live, two commented) must be counted, for
    /// every file. It cannot rot into a stale constant, because the expected value is derived from the
    /// same walk.
    ///
    /// **TASK 41 FIX ROUND 1 (review M3) — this paragraph claimed "strictly stronger than what it
    /// replaces", and that was FALSE as first shipped.** The probe was appended to the already-stripped
    /// text, so a stripper returning `""` left this test GREEN where the allowance would have reddened:
    /// stronger in breadth, weaker on the stripper. Corrected above and in the body, where the exact
    /// per-stage arming is tabulated. Read the table, not an adjective.
    func test_exactlyOneWritableSelectionAuthority() {
        RepoLayout.assertResolved()
        let selectionNames = ["anchor", "head"]
        let compositionNames = ["markedRange", "markedTextIsPrediction",
                                "compositionUndoSnapshot", "compositionAnchorHead"]
        // TASK 42 — the THIRD half, absolute zero from the commit that created it (no shrinking
        // allowance stage: unlike composition, this state moved in one step). `floatingScrollLink` is
        // deliberately ABSENT — a `CADisplayLink` retains its target and `willMove(toWindow:)` is its
        // only teardown, so it STAYS canvas storage and `+FloatingCursor.swift` still writes it twice.
        let floatingNames = ["floatingCursorActive", "floatingCursorPoint", "floatingScrollVelocity"]

        var selectionOffenders: [String] = []
        var compositionCounts: [String: Int] = [:]
        var floatingCounts: [String: Int] = [:]
        // TASK 41 — THE REPLACEMENT NON-VACUITY CONTROL. See this test's doc comment: the composition
        // allowance used to be an exact NON-ZERO figure over this same walk, which is what proved the
        // walk, the stripper and the regex were all alive on the REAL corpus. Emptying it (this task's
        // whole subject) takes that proof away and leaves two expected-zero scrapes with nothing
        // behind them — the shape that has failed four distinct ways on this branch by measuring
        // nothing and reporting zero.
        //
        // So each file is scanned TWICE: once as it is, and once with the probe below appended to its
        // RAW text and the WHOLE THING re-stripped (in memory — nothing is written to disk). The probe
        // carries FOUR planted writes, two of them inside comments, and exactly TWO must be counted —
        // for EVERY file. The expected value is derived from the file count in the same loop, so it
        // cannot decay into a constant somebody edits.
        //
        // **WHICH STAGES THAT ARMS, as a table rather than an adjective** (TASK 41 FIX ROUND 1,
        // review M3, DEMONSTRATED). The first version appended the probe to the ALREADY-STRIPPED text
        // and planted only live-code writes, so it armed the walk and the regex but NOT the stripper:
        // the reviewer mutated `stripCommentsAndStringLiterals` to `return ""` and this test still
        // PASSED, where the allowance it replaced would have gone red. Re-stripping the concatenation,
        // with commented decoys inside it, closes that:
        //
        //   | stage | how a regression is caught |
        //   | --- | --- |
        //   | `RepoLayout.swiftFiles(under:)` | `probedFiles` drops; the count assertion is derived from it |
        //   | stripper — OVER-strips (incl. `return ""`) | the two LIVE writes stop counting → 0 per file |
        //   | stripper — UNDER-strips | the two COMMENTED writes start counting → 4 per file |
        //   | `inputStateWriteCount`'s regex | detections drop to 0 |
        //   | a real file writing these names | that file exceeds 2, and the two assertions below name it |
        //
        // **"Strictly stronger than the allowance it replaced" — claimed here in round 1 and blessed by
        // the coordinator's §4 — was FALSE, and is withdrawn.** It was stronger in BREADTH (93 files
        // rather than 1) and weaker on the STRIPPER axis. It is now stronger on both, and the honest
        // way to say so is the table.
        //
        // It is NOT a duplicate of `test_theWritableAuthorityScanActuallyDetects`: that arms the
        // REGEX against string literals and never opens a file, so a `swiftFiles(under:)` that
        // returned nothing would leave it green.
        // Two live writes (MUST count) and two commented ones (MUST NOT). The commented pair is what
        // makes an UNDER-stripping regression visible; without it, a stripper that stopped removing
        // comments would leave every count at exactly 2 and pass.
        let plantedProbe = """

        markedRange = nil
        anchor = 0
        // markedTextIsPrediction = false
        /* head = 1 */

        """
        let plantedProbeLiveWrites = 2
        var probedFiles = 0
        var probeDetections = 0
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources)
        where !url.path.contains("/InputBackend/") {
            let raw = try! String(contentsOf: url)
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(raw)
            let name = url.lastPathComponent
            if SwiftSourceScan.inputStateWriteCount(in: text, to: selectionNames) > 0 {
                selectionOffenders.append(name)
            }
            let compositionCount = SwiftSourceScan.inputStateWriteCount(in: text, to: compositionNames)
            if compositionCount > 0 { compositionCounts[name] = compositionCount }
            let floatingCount = SwiftSourceScan.inputStateWriteCount(in: text, to: floatingNames)
            if floatingCount > 0 { floatingCounts[name] = floatingCount }

            probedFiles += 1
            // RAW + probe, then STRIPPED — so the stripper sits inside the probed path rather than
            // upstream of it. Appending to the already-stripped `text` is what left the stripper
            // unarmed; see the table above.
            probeDetections += SwiftSourceScan.inputStateWriteCount(
                in: SwiftSourceScan.stripCommentsAndStringLiterals(raw + plantedProbe),
                to: selectionNames + compositionNames + floatingNames)
        }

        XCTAssertGreaterThan(probedFiles, 40,
                             "NON-VACUITY: the canvas-side file walk found only \(probedFiles) files. "
                             + "Both assertions below would be a vacuous green.")
        XCTAssertEqual(probeDetections, probedFiles * plantedProbeLiveWrites,
                       "NON-VACUITY: the probe plants \(plantedProbeLiveWrites) live writes (plus two "
                       + "inside comments, which must NOT count) into each of \(probedFiles) files, so "
                       + "\(probedFiles * plantedProbeLiveWrites) detections are expected; the scan "
                       + "reported \(probeDetections). BELOW expected: the walk, the stripper "
                       + "(over-stripping, including a total break) or the regex has regressed, and both "
                       + "assertions below are vacuous. ABOVE expected: the stripper has stopped removing "
                       + "comments, or some real file contributes a write of its own — which the "
                       + "assertions below name.")

        XCTAssertEqual(selectionOffenders.sorted(), [],
                       "canonical SELECTION state is written outside the backend: "
                       + "\(selectionOffenders.sorted()). The backend is the single writable selection "
                       + "authority (Phase 5); the canvas's `anchor`/`head` are read-only projections.")

        // **TASK 41 EMPTIED IT.** It read `["DocumentCanvasView+MarkedText.swift": 16]` — 16 write
        // SITES, not 13 lines, because three lines carried two writes each
        // (`compositionUndoSnapshot = nil; compositionAnchorHead = nil`). At BASE those sixteen were
        // `+MarkedText.swift:98, 99, 116, 117, 118×2, 120, 123, 175, 176, 177×2, 197, 198, 199×2`, and
        // **all sixteen are now the raw non-publishing pair** — 8 calls to
        // `setCompositionMarkedRange(_:isPrediction:)` / `setCompositionSnapshot(_:)`, since each call
        // subsumes the write pair its line used to carry.
        //
        // (TASK 41 FIX ROUND 1, review m2 — this said "fourteen through the raw pair, and the two in
        // `+Editing.swift`'s undo-restore closure through the publishing `clearCompositionState()`".
        // Wrong on both halves: `+Editing.swift`'s two writes were `target.`-QUALIFIED, and
        // `inputStateWriteCount`'s pattern excludes `.`-qualified forms, so they were never in the
        // allowance to begin with. `clearCompositionState()` replaces 2 sites this scan never saw.
        // Worth carrying forward: that blindness to `target.x = …` is a PRE-EXISTING hole in the scan,
        // closed for these four names only because the canvas projections are now get-only and a
        // qualified write does not compile.)
        //
        // The composition half is absolute zero from here, on the same terms as the selection half,
        // and a later file that re-introduces a writable composition copy fails this same rule.
        XCTAssertEqual(compositionCounts, [:],
                       "canonical COMPOSITION state is written outside the backend: "
                       + "\(compositionCounts.sorted(by: { $0.key < $1.key })). The backend is the "
                       + "single writable composition authority (Task 41); the canvas's `markedRange` "
                       + "and `markedTextIsPrediction` are read-only projections and "
                       + "`compositionUndoSnapshot`/`compositionAnchorHead` no longer exist there at "
                       + "all. Write through `setCompositionMarkedRange(_:isPrediction:)`, "
                       + "`setCompositionSnapshot(_:)` or `clearCompositionState()`.")

        // **TASK 42 ADDED THE THIRD HALF, and it never had an allowance.** The canvas held four
        // floating fields; three moved to the backend and the fourth (`floatingScrollLink`) stays
        // canvas-owned by design, so only three names are scanned.
        //
        // At BASE the three carried **7** write sites VISIBLE TO THIS SCAN, all in
        // `DocumentCanvasView+FloatingCursor.swift`: `:60`, `:61`, `:85`, `:102`, `:160`, `:171`,
        // `:186`. All seven now go through the three doors, which this scan CANNOT see;
        // `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` holds their exact per-file call count.
        //
        // **TASK 42 FIX ROUND 1 (review Minor 1) — this comment said "10 write sites" and then listed
        // 8, and it credited the scan with seeing a shape it cannot see.** The eighth entry was
        // `:207`'s `floatingCursorPoint.y += delta`, described as "a compound assignment, which the
        // scan's compound-assignment support does see". It does not: the pattern is
        // `(?:^|[^.\w])(self\.)?(NAME)\??<assign>`, and in `name.y += delta` the `.y` sits between
        // the name and the operator, so nothing matches. Compound-assignment support covers
        // `name += x` and `name? += x`, **not** `name.member += x`. The site was migrated correctly —
        // that was never in question — but a wrong rationale in a boundary rule is how the next
        // reviewer comes to credit the rule with more than it does, so the shape is now listed in
        // `SwiftSourceScan.inputStateWriteCount`'s own "WHAT THIS CANNOT SEE" inventory (gap 5) and
        // the count here is the measured one. A re-introduced canvas store mutated only as
        // `store.member += x` is caught by the `Mirror` in
        // `FloatingCursorStateAuthorityTests.test_floatingCursorActiveIsStoredOnlyInTheBackend`
        // (the declaration), not by this scan.
        XCTAssertEqual(floatingCounts, [:],
                       "canonical FLOATING-CURSOR state is written outside the backend: "
                       + "\(floatingCounts.sorted(by: { $0.key < $1.key })). The backend is the "
                       + "single writable floating-cursor authority (Task 42); the canvas's "
                       + "`floatingCursorActive`/`floatingCursorPoint`/`floatingScrollVelocity` are "
                       + "read-only projections. Write through `setFloatingCursorActive(_:)`, "
                       + "`setFloatingCursorPoint(_:)` or `setFloatingScrollVelocity(_:)`. "
                       + "(`floatingScrollLink` is deliberately NOT in this rule — the display link "
                       + "stays canvas storage so `willMove(toWindow:)` keeps invalidating it.)")
    }

    /// R7b — **every write door into BACKEND-OWNED INPUT STATE is ENUMERATED.** Task 40b's fix round, and it
    /// exists because the reviewer of that task did the thing a doc comment cannot: planted
    /// `(inputBackend as? LegacyRichTextInputBackend)?.canonicalSelectionStorage = …` in a canvas
    /// file, and found that it **compiles and leaves `test_exactlyOneWritableSelectionAuthority`
    /// green**. The canvas `anchor`/`head` properties are read-only, and that is a real invariant —
    /// but "there is no canvas-side way to write a selection" was never true, and this rule is what
    /// makes the true statement checkable.
    ///
    /// `DocumentCanvasView.swift`'s `anchor` doc names three doors. Door 1 (`setSelection(_:reason:)`)
    /// and door 3 (the D33 pair) each carry a sentence of the form "a second one is a decision, not a
    /// detail" / "read their contract before adding an eighth". Those sentences had **no mechanism**.
    /// Here they do: each door is an EXACT per-file allowance, so an eighth caller costs an edit to a
    /// constant and a reviewer's attention — which is what a decision is supposed to cost. Door 2
    /// (returning a `RichTextInputCaretOutcome`) is the encouraged route and is deliberately
    /// unlimited.
    ///
    /// **UNITS. Read this before touching a number** — the site-vs-line-vs-pair distinction has now
    /// misled this branch four times, twice in this task alone. Every figure below counts CALL SITES:
    /// one per call expression. The D33 contract's own caller inventory says **SEVEN**, and both are
    /// right about different things: there are seven call LOCATIONS, each of which writes both
    /// endpoints, so `7 locations = 14 calls`. `DocumentCanvasView.swift` has 1 location / 2 calls
    /// (`setSelectionForTesting`); `+Editing.swift` has 6 locations / 12 calls (`applyCaretOutcome`,
    /// `registerUndo`'s restore, and `legacyApplyMutation`'s four seat-before-dispatch sites). A fix
    /// round's instruction to this test said "`DocumentCanvasView.swift` 2, `+Editing.swift` 5"; the
    /// first is right in calls, the second in neither unit, and the numbers below were read out of
    /// these assertions rather than taken from it.
    ///
    /// **WHAT THIS TEST HOSTS — read the list before greping.** (TASK 42 FIX ROUND 1, review Minor 5;
    /// **TASK 43 did the rename that review prescribed and deferred.**) In order of appearance:
    /// door 1 (`setSelection(_:reason:)`), door 3 (the D33 `setCanonicalAnchor`/`setCanonicalHead`
    /// pair), the two COMPOSITION doors (Task 41), the three FLOATING-CURSOR doors (Task 42), the
    /// SUPPRESSION flag (Task 43), the CONCRETE-TYPE cap (Task 42) that closes the downcast route for
    /// every backend store at once, and the named-store downcast list. That is **EIGHT assertions**
    /// (counted `grep -c 'XCTAssertEqual(' ` over this body — the first draft of this very sentence
    /// said SEVEN, in the paragraph directly above the one about miscounting) — and the old name,
    /// `test_theRemainingSelectionWriteDoorsAreEnumerated`, named exactly one of them, so an engineer
    /// tripped by the floating-cursor rule and greping for "selection" found nothing about the thing
    /// they had just been told about.
    ///
    /// **UNITS, AGAIN — the rename's own inherited figure was wrong.** Task 42's report, and the plan
    /// obligation copied from it, both said the rename must update "the FIVE citing doc comments in
    /// `Sources/`". Five is the number of RULES this test hosted, not the number of places that cite
    /// it. Measured at Task 43 (`grep -ro <name> Sources | wc -l`): **EIGHT citations in `Sources/`,
    /// across THREE files** — `DocumentCanvasView.swift` ×4, `RichTextInputBackend.swift` ×3,
    /// `LegacyRichTextInputBackend+FloatingCursor.swift` ×1 — **plus FOUR more in `Tests/`**
    /// (`InputBackendSourceBoundaryTests.swift` ×2, `SwiftSourceScan.swift` ×1,
    /// `DelegateOwnershipTests.swift` ×1), which neither document mentioned at all. All twelve, and
    /// the declaration, moved in the one commit.
    ///
    /// **NON-VACUITY.** Doors 1 and 3 assert exact NON-ZERO dictionaries over the same file walk, so
    /// a scan that measured nothing — `callSiteCount` builds its regex with `try?` and answers 0 on
    /// failure — reddens them rather than passing. The downcast assertion expects `[:]` and therefore
    /// has no such in-test control; `identifierMentionCount` is armed against the exact planted line
    /// in `test_theWritableAuthorityScanActuallyDetects`, which is where a change to it must stay
    /// honest. Verified by construction at the fix round: all three assertions were reddened by
    /// planting their forbidden shape in a real source file, and each mutation was restored.
    func test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated() {
        RepoLayout.assertResolved()

        // DOOR 1 — the publishing entry point. One call, in the backend itself.
        var setSelectionCalls: [String: Int] = [:]
        // DOOR 3 — the raw, non-publishing D33 pair, OUTSIDE the backend (inside it they are the
        // implementation, not a caller).
        var d33Calls: [String: Int] = [:]
        // THE UNDOCUMENTED DOOR the reviewer found: reaching the backend's private-by-convention
        // stores through a concrete downcast. Zero, forever, with no allowance — unlike the two
        // above, this one has no legitimate use outside `/InputBackend/` at all.
        var storageMentions: [String: Int] = [:]
        // TASK 41 FIX ROUND 1 (review M4) — **THE TWO COMPOSITION DOORS THIS RULE WAS MISSING.**
        // Task 41 created `setCompositionMarkedRange(_:isPrediction:)` / `setCompositionSnapshot(_:)`
        // and described them in-tree as "the marked-text analogue of the D33 pair", then did not
        // enumerate them here — the exact defect Task 40b's reviewer found one layer over, where
        // `canonicalSelectionStorage` was reachable and unlisted. They are invisible to the write scan
        // above for a mechanical reason: `inputStateWriteCount`'s pattern is
        // `(?:^|[^.\w])(self\.)?<name>` with no `.`-qualified form, so a
        // `inputBackend.setCompositionMarkedRange(…)` is not a "write" it can see, and
        // `test_exactlyOneWritableSelectionAuthority` keeps reporting `[:]` while a new writer exists.
        var compositionRawCalls: [String: Int] = [:]
        // The PUBLISHING composition door, separated from the raw pair for the same reason door 1 is
        // separated from door 3: it reports to the host, so a second call site is a decision about
        // host-visible behaviour, not a detail.
        var compositionPublishingCalls: [String: Int] = [:]
        // TASK 42 — **THE THREE FLOATING-CURSOR DOORS, ENUMERATED IN THE SAME COMMIT THAT CREATED
        // THEM.** Task 40b's review found `canonicalSelectionStorage`'s downcast door unenumerated and
        // Task 41's found `setCompositionMarkedRange`/`setCompositionSnapshot` unenumerated; two for
        // two, so this task's coordinator made it an explicit requirement rather than a hope. Same
        // mechanical blindness as the composition pair: `inputStateWriteCount` has no `.`-qualified
        // form, so an `inputBackend.setFloatingCursorActive(…)` is not a "write" the scan above sees.
        var floatingCalls: [String: Int] = [:]
        // TASK 42 — **THE GENERAL FORM OF THE DOWNCAST DOOR, which the `storageMentions` list below
        // can only express one store at a time.** This task's three backend stores are named
        // `floatingCursorActive`/`floatingCursorPoint`/`floatingScrollVelocity` — the SAME names as the
        // canvas's read-only projections, because a stored `var` satisfies the protocol's `{ get }`
        // requirement directly and no `…Storage` alias was introduced. So they CANNOT be added to
        // `storageMentions`: `identifierMentionCount` is deliberately blunt and would count every
        // projection declaration and every canvas read as an offence.
        //
        // The door those three leave open is `(inputBackend as? LegacyRichTextInputBackend)?.
        // floatingCursorActive = true` in a canvas file — which compiles, and which the R7 write scan
        // cannot see (it is `.`-qualified). Rather than rename three stores to make one blunt scan fit,
        // close the door at its throat: **the CONCRETE backend type may be named exactly once outside
        // `S/InputBackend/`, in `DocumentCanvasView.init`'s default construction.** No downcast to it
        // is possible anywhere else, so no store of its — these three, `canonicalSelectionStorage`,
        // `markedRangeStorage`, or one a later task adds and forgets to list — is reachable that way.
        // This is strictly stronger than `storageMentions`, which is kept anyway: it names the specific
        // stores in its failure message, which is what makes that failure actionable.
        var concreteBackendMentions: [String: Int] = [:]
        // TASK 43 — **THE SUPPRESSION FLAG, enumerated in the commit that deleted its forwarder.**
        // `DocumentCanvasView.coalescingSelectionNotifications` was a Task-26 computed forwarder onto
        // `inputBackend.suppressesSelectionNotifications` (D33). Task 43 deleted the forwarder, so the
        // canvas's four use sites now name the backend member directly — TWO writes and TWO reads,
        // across two files. `identifierMentionCount`, not `callSiteCount`: this is a stored `Bool`, so a
        // write is `inputBackend.suppressesSelectionNotifications = true`, which has no `(` for
        // `callSiteCount` to find and a `.` prefix that `inputStateWriteCount` skips by construction.
        // Being blunt (reads count too) is correct here: the flag has TWO backend consumers that must
        // stay in step, so a canvas-side READ of it is as much a coupling to enumerate as a write.
        var suppressionMentions: [String: Int] = [:]
        // TASK 43 FIX ROUND 1 (review Minor 2) — **THE DELETED FORWARDER MUST STAY DELETED, and this
        // is a rule about the TEST TARGET's safety, not the canvas's.**
        // `Tests/…/Support/CanvasCoalescingTestAccess.swift` re-vends
        // `DocumentCanvasView.coalescingSelectionNotifications` to the UIKit test target so the D18
        // characterization pin stays byte-identical (Phase 6 gate item 3). If `Sources/` ever
        // re-declares that member, the test target sees TWO candidates — the `@testable`-visible one
        // and this same-module extension — and Swift may pick the extension with NO diagnostic. The
        // D18 test would then characterise the SHIM instead of the canvas, silently, which is the
        // exact failure the gate exists to prevent. Scanned over ALL files (not just `!inBackend`):
        // the name is deleted, so zero forever, anywhere.
        var deletedForwarderMentions: [String: Int] = [:]

        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            let name = url.lastPathComponent
            let inBackend = url.path.contains("/InputBackend/")

            let revived = SwiftSourceScan.identifierMentionCount(
                in: text, to: ["coalescingSelectionNotifications"])
            if revived > 0 { deletedForwarderMentions[name] = revived }

            let publishing = SwiftSourceScan.callSiteCount(in: text, to: ["setSelection"])
            if publishing > 0 { setSelectionCalls[name] = publishing }

            if !inBackend {
                let raw = SwiftSourceScan.callSiteCount(
                    in: text, to: ["setCanonicalAnchor", "setCanonicalHead"])
                if raw > 0 { d33Calls[name] = raw }

                // TASK 41 added the two new composition stores. `markedTextIsPredictionStorage`
                // and `compositionSnapshotStorage` are exactly as reachable by downcast as
                // `markedRangeStorage`, and exactly as illegitimate to reach.
                let compositionRaw = SwiftSourceScan.callSiteCount(
                    in: text, to: ["setCompositionMarkedRange", "setCompositionSnapshot"])
                if compositionRaw > 0 { compositionRawCalls[name] = compositionRaw }

                let compositionPublishing = SwiftSourceScan.callSiteCount(
                    in: text, to: ["clearCompositionState"])
                if compositionPublishing > 0 { compositionPublishingCalls[name] = compositionPublishing }

                let floating = SwiftSourceScan.callSiteCount(
                    in: text, to: ["setFloatingCursorActive", "setFloatingCursorPoint",
                                   "setFloatingScrollVelocity"])
                if floating > 0 { floatingCalls[name] = floating }

                let concrete = SwiftSourceScan.identifierMentionCount(
                    in: text, to: ["LegacyRichTextInputBackend"])
                if concrete > 0 { concreteBackendMentions[name] = concrete }

                let suppression = SwiftSourceScan.identifierMentionCount(
                    in: text, to: ["suppressesSelectionNotifications"])
                if suppression > 0 { suppressionMentions[name] = suppression }

                let stores = SwiftSourceScan.identifierMentionCount(
                    in: text, to: ["canonicalSelectionStorage", "markedRangeStorage",
                                   "markedTextIsPredictionStorage", "compositionSnapshotStorage"])
                if stores > 0 { storageMentions[name] = stores }
            }
        }

        XCTAssertEqual(setSelectionCalls, ["LegacyRichTextInputBackend.swift": 1],
                       "DOOR 1 moved: \(setSelectionCalls.sorted(by: { $0.key < $1.key })). "
                       + "`setSelection(_:reason:)` is the package's ONLY publication path for a "
                       + "selection; a second call site is a decision about host-visible behaviour, "
                       + "not a detail. Add it here in the same commit, with the reasoning.")

        XCTAssertEqual(d33Calls,
                       ["DocumentCanvasView.swift": 2,
                        "DocumentCanvasView+Editing.swift": 12],
                       "DOOR 3 moved: \(d33Calls.sorted(by: { $0.key < $1.key })). The D33 pair is the "
                       + "raw, non-publishing, unguarded endpoint write; its caller set is enumerated "
                       + "at its declaration in `RichTextInputBackend.swift` and Task 40b decided to "
                       + "KEEP it on the strength of exactly these callers. Read that contract before "
                       + "changing this number.")

        // **UNITS: CALL SITES — one per call expression, exactly as doors 1 and 3 above.** Eight raw
        // calls, all in `DocumentCanvasView+MarkedText.swift`: `legacySetMarkedText` makes four
        // (`:102` snapshot capture, `:120`/`:121` the cancel pair, `:125` the set), `commitMarkedText`
        // two (`:183`/`:184`) and `dismissPrediction` two (`:204`/`:205`). That is 3 LOCATIONS in the
        // "which body" sense and 8 CALLS; this counts calls, and the distinction has misled this
        // branch five times now, so it is spelled out rather than left to the reader.
        XCTAssertEqual(compositionRawCalls, ["DocumentCanvasView+MarkedText.swift": 8],
                       "THE RAW COMPOSITION DOOR MOVED: "
                       + "\(compositionRawCalls.sorted(by: { $0.key < $1.key })). "
                       + "`setCompositionMarkedRange(_:isPrediction:)`/`setCompositionSnapshot(_:)` are "
                       + "the raw, NON-PUBLISHING composition writes — the marked-text analogue of the "
                       + "D33 pair, and bounded on exactly the same terms. Task 41 gave them THREE "
                       + "callers, all composition-lifecycle bodies that emit their own delegate "
                       + "brackets; a fourth is a decision, not a detail, because a caller that is not "
                       + "one of those bodies gets no bracket at all and the host never learns the "
                       + "composition changed. The write scan above CANNOT see these (they are "
                       + "`.`-qualified), so this dictionary is the only mechanism.")

        XCTAssertEqual(compositionPublishingCalls, ["DocumentCanvasView+Editing.swift": 1],
                       "THE PUBLISHING COMPOSITION DOOR MOVED: "
                       + "\(compositionPublishingCalls.sorted(by: { $0.key < $1.key })). "
                       + "`clearCompositionState()` ends in `publishState(reason: .markedText)`, which "
                       + "reaches the host through `notifyContentSizeChanged()` — so a second call "
                       + "site is a new host callback, the regression class "
                       + "`ExternalSynchronizationTests.test_noSiteAddsAHostContentSizeNotification` "
                       + "exists to catch. Its one caller is `registerUndo`'s restore closure, which "
                       + "holds `suppressHostChangeNotification` across the call for that reason.")

        // **UNITS: CALL SITES — one per call expression, exactly as every door above.** Eight calls, all
        // in `DocumentCanvasView+FloatingCursor.swift`: `setFloatingCursorActive` 3
        // (`legacyBeginFloatingCursor`, `legacyEndFloatingCursor`, `cancelFloatingCursor()`),
        // `setFloatingCursorPoint` 3 (`legacyBeginFloatingCursor`, `legacyUpdateFloatingCursor`,
        // `floatingAutoScrollTick`) and `setFloatingScrollVelocity` 2
        // (`updateFloatingAutoScroll(viewportY:)`, `stopFloatingAutoScroll()`). That is 5 LOCATIONS in
        // the "which body" sense and 8 CALLS; this counts calls, and the site-vs-location distinction
        // has misled this branch six times now, so it is spelled out rather than left to the reader.
        XCTAssertEqual(floatingCalls, ["DocumentCanvasView+FloatingCursor.swift": 8],
                       "THE FLOATING-CURSOR DOORS MOVED: "
                       + "\(floatingCalls.sorted(by: { $0.key < $1.key })). "
                       + "`setFloatingCursorActive(_:)`/`setFloatingCursorPoint(_:)`/"
                       + "`setFloatingScrollVelocity(_:)` are the raw, NON-PUBLISHING floating-cursor "
                       + "writes — the third analogue of the D33 pair, bounded on the same terms. Two "
                       + "of the eight carry an ORDER requirement their own call sites document (the "
                       + "flag must be set before `legacyBeginFloatingCursor`'s `updateCaretView()` and "
                       + "cleared before `legacyEndFloatingCursor`'s, or the wrong caret is painted), "
                       + "and `setFloatingScrollVelocity`'s two calls are what keep 'no link implies no "
                       + "velocity' inside one canvas body now that the link and the velocity live on "
                       + "opposite sides of the seam. A ninth call site is a decision, not a detail. "
                       + "The write scan above CANNOT see these (they are `.`-qualified), so this "
                       + "dictionary is the only mechanism.")

        // **UNITS: MENTIONS — reads and writes alike, one per occurrence, unlike every door above
        // which counts CALL SITES.** Four mentions in two files. `DocumentCanvasView.swift` 3:
        // `beginCoalescedSelectionDrag()` sets it true, `endCoalescedSelectionDrag()`'s `guard` reads
        // it, and that same body clears it. `DocumentCanvasView+NativeTextCheckingClient.swift` 1:
        // `nativeCheckOnSelectionChange()`'s `guard` skips native spell-checking while a loupe or
        // handle drag coalesces, mirroring the suppressed `inputDelegate` bracket.
        //
        // **A FIFTH IS A DECISION, NOT A DETAIL, and the reason is the flag's `didSet`**
        // (`LegacyRichTextInputBackend.swift`): clearing it FLUSHES a deferred selection publish. So a
        // new canvas-side write is not "setting a Bool" — it is a new host-visible publication moment,
        // in a body that was not written to expect one. The four coalescing tests in
        // `DelegateTraceCharacterizationTests` are what pin the current timing.
        XCTAssertEqual(suppressionMentions,
                       ["DocumentCanvasView.swift": 3,
                        "DocumentCanvasView+NativeTextCheckingClient.swift": 1],
                       "THE SUPPRESSION FLAG MOVED: "
                       + "\(suppressionMentions.sorted(by: { $0.key < $1.key })). "
                       + "`suppressesSelectionNotifications` is the backend's D33 coalescing flag, and "
                       + "since Task 43 the canvas names it directly (the "
                       + "`coalescingSelectionNotifications` forwarder is deleted). Its `didSet` fires "
                       + "a DEFERRED SELECTION PUBLISH on the clearing edge, so a fifth mention is a "
                       + "new publication moment, not a detail. Neither scan above can see these — a "
                       + "`.`-qualified assignment to a stored property has no `(` for `callSiteCount` "
                       + "and a `.` prefix `inputStateWriteCount` excludes — so this dictionary is the "
                       + "only mechanism.")

        // NON-VACUITY: this one expects `[:]`, so it has no in-test control of its own — it rides on
        // the same walk and the same `identifierMentionCount` as `suppressionMentions` directly above,
        // whose exact non-zero dictionary reddens if either breaks.
        XCTAssertEqual(deletedForwarderMentions, [:],
                       "THE DELETED COALESCING FORWARDER IS BACK IN `Sources/`: "
                       + "\(deletedForwarderMentions.sorted(by: { $0.key < $1.key })). "
                       + "`coalescingSelectionNotifications` was deleted by Task 43 and the UIKit TEST "
                       + "TARGET now vends that exact name as an extension "
                       + "(`Support/CanvasCoalescingTestAccess.swift`) so the D18 characterization pin "
                       + "stays byte-identical. Re-declaring it in `Sources/` gives the test target two "
                       + "candidates for one name, which Swift may resolve to the extension WITHOUT A "
                       + "DIAGNOSTIC — and `ResponderLifecycleCharacterizationTests"
                       + ".test_resignFirstResponder_leavesTheCoalescingFlagSet` would then be "
                       + "characterising the shim rather than the canvas, silently. If you genuinely "
                       + "need a canvas-side coalescing member again, DELETE THE SHIM in the same "
                       + "commit and re-point that characterization suite deliberately.")

        // The exact non-zero figure is also this assertion's own non-vacuity control: a walk or a scan
        // that measured nothing reports `[:]` and reddens here rather than passing.
        XCTAssertEqual(concreteBackendMentions, ["DocumentCanvasView.swift": 1],
                       "THE CONCRETE BACKEND TYPE IS NAMED IN CODE OUTSIDE `S/InputBackend/`: "
                       + "\(concreteBackendMentions.sorted(by: { $0.key < $1.key })). The allowance is "
                       + "one mention, `DocumentCanvasView.init`'s "
                       + "`inputBackend ?? LegacyRichTextInputBackend()`. THE RULE: naming this type "
                       + "in canvas-side CODE is capped, not banned — comments and string literals are "
                       + "stripped before this scan and may name it freely. WHY: "
                       + "`DocumentCanvasView.inputBackend` is typed `any RichTextInputBackend` so "
                       + "canvas code reaches only contract members, and any mention of the concrete "
                       + "type re-opens `(inputBackend as? LegacyRichTextInputBackend)?.<store> = …`, "
                       + "which compiles, is invisible to the `.`-blind write scan above, and is a "
                       + "second writable authority for whichever store it names — the one door the "
                       + "read-only projections cannot close by themselves. WHAT TO DO: if you are "
                       + "WRITING backend state, route through a door (`setCanonicalAnchor(_:)`, "
                       + "`setCompositionMarkedRange(_:isPrediction:)`, `setFloatingCursorActive(_:)`, "
                       + "…) and this mention disappears. If the mention is legitimate — a second "
                       + "construction site, a `type(of:)`/`is` diagnostic, a `typealias` — add it to "
                       + "the dictionary above with a comment saying which and why: a second one is a "
                       + "DECISION, not a detail, and this constant is what makes it cost a reviewer's "
                       + "attention.")

        XCTAssertEqual(storageMentions, [:],
                       "THE DOWNCAST DOOR IS OPEN: \(storageMentions.sorted(by: { $0.key < $1.key })). "
                       + "`canonicalSelectionStorage`/`markedRangeStorage`/"
                       + "`markedTextIsPredictionStorage`/`compositionSnapshotStorage` are the "
                       + "backend's own stores. Naming either outside `Sources/RichTextEditorUIKit/InputBackend/` — "
                       + "typically as `(inputBackend as? LegacyRichTextInputBackend)?.…` — is a "
                       + "second writable authority that the read-only projections cannot prevent and "
                       + "the write scan cannot see (it is `.`-qualified). There is no legitimate use; "
                       + "route through door 1, 2 or 3.")
    }

    /// TASK 43 — **`DocumentTokenizer` has exactly ONE construction site, and it is the backend's.**
    ///
    /// The brief for this task says the tokenizer "is constructed and owned by the backend". Ownership
    /// of the CACHE moved at Task 24 (`LegacyRichTextInputBackend.tokenizerStorage`), but the minting
    /// stayed on the canvas behind a D24 clause-(a) hook, `legacyMakeTokenizer()`. Task 43 deleted that
    /// hook and moved `DocumentTokenizer(canvas:)` into `attach(to:)`.
    ///
    /// **This rule exists because the obvious runtime assertion is VACUOUS, and was written and run
    /// before that was noticed.** `DelegateOwnershipTests` first pinned the hook's absence with
    /// `XCTAssertFalse(v.responds(to: Selector(("legacyMakeTokenizer"))))` — which passes whether or
    /// not the method exists, because a plain Swift method is not `@objc` and `responds(to:)` cannot
    /// see it. It passed on the UNMODIFIED tree, which is how it was caught. A source scan is the only
    /// mechanism that can state "one construction site" at all.
    ///
    /// # FIX ROUND 1 (review Major 1) — THE REPLACEMENT WAS ITSELF EVADABLE, BY THE SPELLING THIS TASK RECOMMENDED
    ///
    /// The first version used `callSiteCount`, whose regex is `Name\s*\(`. The reviewer planted a
    /// live second construction site spelled `DocumentTokenizer.init(canvas: self)` in
    /// `DocumentCanvasView+UITextInput.swift` and **this test stayed GREEN** (reproduced independently
    /// at the fix round). That was worse than a plain gap on two counts: this rule is cited by name in
    /// four `Sources/` doc comments as *the* mechanism that replaced a vacuous assertion, and the same
    /// commit wrote the evading spelling into `BackendAttachmentTests`' doc comment as the RECOMMENDED
    /// mutation — pointing the next reader at the one form the rule could not see.
    ///
    /// **Two assertions now, because one cannot be complete.** All five spellings below COMPILE
    /// (planted in a canvas file and built for the simulator at the fix round — not reasoned about):
    /// `Name(…)`, `Name.init(…)`, `[x].map(Name.init)`, a `typealias`, and a
    /// `let m: Name.Type = Name.self; m.init(…)` metatype binding. `constructionSiteCount` catches the
    /// first two; the last three name the type somewhere without ever putting a `(` after it, so only
    /// an exact `identifierMentionCount` allowance sees them. The construction assertion carries the
    /// actionable message; the mention allowance is the net. Same two-rule shape as
    /// `concreteBackendMentions` + `storageMentions` in R7b, and for the same reason.
    ///
    /// NON-VACUITY: both expectations are exact NON-ZERO dictionaries, so a broken walk or a
    /// `try?`-nil regex reports `[:]` and reddens rather than passing.
    func test_theTokenizerHasExactlyOneConstructionSite() {
        RepoLayout.assertResolved()

        var construction: [String: Int] = [:]
        var mentions: [String: Int] = [:]
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            // **NO EXEMPTION FOR `DocumentTokenizer.swift` ITSELF, and the first draft had one.** It
            // was DEAD (the declaration is `final class DocumentTokenizer: NSObject` and the init is
            // `init(canvas:)` — neither is a construction) and it was also pointed the wrong way: a
            // `convenience init` or a `copy()` added there would be a SECOND construction site, which
            // is precisely what this rule is for. Rule 36 — deleted rather than kept. The declaration
            // does contribute ONE identifier mention, which is why it appears in the second
            // dictionary below and not in the first.
            let n = SwiftSourceScan.constructionSiteCount(in: text, to: ["DocumentTokenizer"])
            if n > 0 { construction[url.lastPathComponent] = n }

            let m = SwiftSourceScan.identifierMentionCount(in: text, to: ["DocumentTokenizer"])
            if m > 0 { mentions[url.lastPathComponent] = m }
        }

        XCTAssertEqual(construction, ["LegacyRichTextInputBackend+Attachment.swift": 1],
                       "THE TOKENIZER IS MINTED SOMEWHERE ELSE: "
                       + "\(construction.sorted(by: { $0.key < $1.key })). `DocumentTokenizer` holds "
                       + "its canvas `unowned` and the backend clears `tokenizerStorage` on detach, so "
                       + "a second construction site is a second lifetime — the exact shape of Task "
                       + "24's Major 1 (a cached tokenizer outliving the canvas it was bound to). The "
                       + "one allowed site is `attach(to:)`, where `legacyHost` is non-nil by "
                       + "construction. If you need one elsewhere, say why here. NOTE: this scan sees "
                       + "`Name(` and `Name.init(` only — if you are hunting a construction it did "
                       + "not catch, the mention allowance below is the rule that will have caught it.")

        // **THE NET.** Every spelling that evades `constructionSiteCount` still NAMES the type
        // somewhere: `[x].map(DocumentTokenizer.init)` mentions it with no paren, a
        // `typealias T = DocumentTokenizer` mentions it at the alias, and
        // `let m: DocumentTokenizer.Type = DocumentTokenizer.self` mentions it twice at the binding.
        // So an EXACT mention allowance is what makes "exactly one construction site" a true
        // statement rather than a statement about one regex.
        //
        // UNITS: MENTIONS, one per occurrence, reads/casts/declarations alike. The five today:
        //   * `LegacyDocumentTokenizer.swift` 1 — `final class DocumentTokenizer: NSObject, …`, the
        //     declaration. **TASK 44 renamed the FILE, not the type** (`S/Canvas/DocumentTokenizer.swift`
        //     → `S/InputBackend/Legacy/LegacyDocumentTokenizer.swift`): the tokenizer has been
        //     backend-owned since Task 43 and is the package's densest source of UIKit identity
        //     construction, so R6 relocates it rather than granting it an allowance. The type name is
        //     unchanged because ~20 UIKit-test mentions would otherwise be edited, which D22 forbids.
        //   * `DocumentCanvasView+SelectionActions.swift` 2 — `tokenizer as? DocumentTokenizer` in the
        //     word- and paragraph-select actions.
        //   * `DocumentCanvasView+NativeTextCheckingClient.swift` 1 — the same downcast in
        //     `spellCheckTargets`, which returns `(nil, nil)` when it fails (i.e. when detached).
        //   * `LegacyRichTextInputBackend+Attachment.swift` 1 — THE construction.
        // A sixth is a decision: the three non-construction mentions are all `as?` narrowing of the
        // backend's vended tokenizer, which is safe precisely because it does NOT mint one.
        XCTAssertEqual(mentions,
                       ["LegacyDocumentTokenizer.swift": 1,
                        "DocumentCanvasView+SelectionActions.swift": 2,
                        "DocumentCanvasView+NativeTextCheckingClient.swift": 1,
                        "LegacyRichTextInputBackend+Attachment.swift": 1],
                       "`DocumentTokenizer` IS NAMED SOMEWHERE NEW: "
                       + "\(mentions.sorted(by: { $0.key < $1.key })). This is the BLUNT half of the "
                       + "one-construction-site rule and it is blunt on purpose — the assertion above "
                       + "sees `Name(` and `Name.init(`, but `[x].map(DocumentTokenizer.init)`, a "
                       + "`typealias`, and a `DocumentTokenizer.Type` metatype binding are all valid "
                       + "Swift that constructs one while matching no `(` after the name. Each still "
                       + "MENTIONS the type, so this dictionary catches them. If your new mention is a "
                       + "downcast of the backend's own tokenizer (the three existing non-construction "
                       + "mentions all are), add it here with that note; if it MINTS one, it is a "
                       + "second lifetime and the assertion above explains why that is the Task-24 "
                       + "Major-1 shape.")
    }

    /// TASK 43 FIX ROUND 1 — Rule 19 for `constructionSiteCount`, which exists only because its
    /// predecessor was evaded. A scan added to close a blind spot is exactly the kind that must be
    /// armed against synthetic sources: if its widening regex silently failed to compile (`try?` →
    /// `nil` → 0), `test_theTokenizerHasExactlyOneConstructionSite` would report `[:]` and its
    /// non-zero expectation would redden — but the DIRECTION of the widening would be untested, and
    /// the whole point is which spellings it now catches.
    ///
    /// The DOES-NOT-DETECT half is as load-bearing as the detects half here: it is the written record
    /// of what the paired `identifierMentionCount` allowance is for. If someone later "simplifies"
    /// this scan to also match a bare `Name.init`, these three lines go red and they will find out why
    /// the second dictionary exists before deleting it.
    func test_theConstructionScanCatchesBothParenthesisedSpellings() {
        func count(_ line: String) -> Int {
            SwiftSourceScan.constructionSiteCount(in: line + "\n", to: ["DocumentTokenizer"])
        }

        // DETECTS — the two spellings that put a `(` after the type name.
        XCTAssertEqual(count("        tokenizerStorage = DocumentTokenizer(canvas: c)"), 1)
        XCTAssertEqual(count("        return DocumentTokenizer.init(canvas: self)"), 1,
                       "the `.init` spelling is the whole reason this scan replaced `callSiteCount` — "
                       + "a live site spelled this way left the rule GREEN (review Major 1)")
        XCTAssertEqual(count("        [self].map(DocumentTokenizer.init(canvas:))[0]"), 1,
                       "the reviewer's exact planted mutation")
        XCTAssertEqual(count("        a = DocumentTokenizer(canvas: x); b = DocumentTokenizer.init(canvas: y)"), 2,
                       "SITES, one per construction — two on one line is two")

        // DOES NOT DETECT — the three valid spellings only the mention allowance can see. All three
        // COMPILE (built for the simulator at the fix round, not reasoned about).
        XCTAssertEqual(count("        [self].map(DocumentTokenizer.init)[0]"), 0,
                       "bare metatype member reference: no `(` follows the name at all")
        XCTAssertEqual(count("        private typealias Tok = DocumentTokenizer"), 0,
                       "a typealias moves the construction to a name this scan cannot know")
        XCTAssertEqual(count("        let m: DocumentTokenizer.Type = DocumentTokenizer.self"), 0,
                       "the metatype binding; the construction is later, as `m.init(…)`")

        // DOES NOT DETECT — a declaration is not a construction.
        XCTAssertEqual(count("final class DocumentTokenizer: NSObject, UITextInputTokenizer {"), 0)
        XCTAssertEqual(count("        func makeDocumentTokenizer(canvas: c) -> X"), 0,
                       "a longer identifier ENDING in the name must not match (the `(?<![\\w])` lookbehind)")
        XCTAssertEqual(count("        guard let t = tokenizer as? DocumentTokenizer else { return }"), 0,
                       "a downcast is not a construction — this is the shape of all three existing "
                       + "non-construction mentions")
    }

    /// Rule 19 for the scan above: both halves are armed against synthetic sources, so a green
    /// `test_exactlyOneWritableSelectionAuthority` cannot be the vacuous green of a pattern that
    /// matches nothing. Fixtures are string literals here rather than files, and spell no
    /// `func test_…` (R14's fix-round lesson).
    func test_theWritableAuthorityScanActuallyDetects() {
        let selection = ["anchor", "head"]
        let composition = ["markedRange", "markedTextIsPrediction",
                           "compositionUndoSnapshot", "compositionAnchorHead"]
        func count(_ line: String, _ names: [String]) -> Int {
            SwiftSourceScan.inputStateWriteCount(in: line + "\n", to: names)
        }

        // DETECTS — bare, `self.`-qualified, after a `;`, inside a brace, after a `case` label.
        XCTAssertEqual(count("        anchor = 0", selection), 1)
        XCTAssertEqual(count("        self.head = 3", selection), 1)
        XCTAssertEqual(count("        anchor = 1; head = 2", selection), 2)
        XCTAssertEqual(count("        if x { anchor = 1 }", selection), 1)
        XCTAssertEqual(count("        case .a: head = 1", selection), 1)
        XCTAssertEqual(count("        markedRange = nil", composition), 1)
        XCTAssertEqual(count("        compositionUndoSnapshot = nil; compositionAnchorHead = nil", composition), 2)

        // DETECTS — the three shapes Task 40b's REVIEWER measured as silent gaps and the fix round
        // closed. The wrapped one is the one that mattered: this codebase wraps at ~100 columns, and
        // in a NEW file a missed write leaves no dictionary key at all, i.e. a silent green.
        XCTAssertEqual(count("        anchor =", selection), 1, "wrapped RHS: the `=` ends the line")
        XCTAssertEqual(count("        self.markedRange =", composition), 1, "wrapped RHS, qualified")
        XCTAssertEqual(count("        anchor += 1", selection), 1, "compound assignment")
        XCTAssertEqual(count("        compositionUndoSnapshot? += [b]", composition), 1,
                       "compound assignment through an Optional")
        XCTAssertEqual(count("        (anchor, head) = (1, 2)", selection), 2,
                       "tuple destructuring is TWO sites, one per endpoint")
        XCTAssertEqual(count("        (markedRange, markedTextIsPrediction) = (nil, false)", composition), 2)

        // DOES NOT DETECT — the 10 real false positives' shapes, plus `.`-qualification, equality and
        // plain argument use. Each of these is a line that exists in the tree today.
        XCTAssertEqual(count("        let anchor = map.anchor(atRow: r)", selection), 0)
        XCTAssertEqual(count("              guard let anchor = m.anchor(x) else { return }", selection), 0)
        XCTAssertEqual(count("        if let anchor = byID[id] {", selection), 0)
        XCTAssertEqual(count("    var markedTextIsPrediction = false", composition), 0)
        XCTAssertEqual(count("        target.anchor = 4", selection), 0)
        XCTAssertEqual(count("        if anchor == head { return }", selection), 0)
        XCTAssertEqual(count("        f(anchor, head)", selection), 0)

        // DOES NOT DETECT — **gap 5**, added TASK 42 FIX ROUND 1 (review Minor 1) and ARMED here
        // rather than only described in `SwiftSourceScan`'s inventory, because a documented gap that
        // no fixture exercises is how a future reader comes to believe it was closed. A write to a
        // MEMBER of a guarded name really does mutate the guarded value, and this scan cannot see it:
        // the assignment operator must follow the NAME, and `.y` sits in between. This is the exact
        // shape Task 42's own boundary comment wrongly claimed was covered — the real
        // `floatingCursorPoint.y += delta` at BASE.
        XCTAssertEqual(count("        anchor.y += 1", selection), 0,
                       "gap 5: a write to a MEMBER of a guarded name is invisible to this scan; the "
                       + "DECLARATION it needs is caught by the suites' `Mirror` checks instead")
        XCTAssertEqual(count("        markedRange?.location = 0", composition), 0, "gap 5, optional form")

        // DOES NOT DETECT — the neighbours of the widened assignment operator. Each of these would be
        // a false positive if the compound-operator set or the `(?!=)` lookahead were sloppy, and
        // each is a shape that occurs constantly in real code.
        XCTAssertEqual(count("        if anchor != head { return }", selection), 0)
        XCTAssertEqual(count("        if anchor <= head, head >= 0 { return }", selection), 0)
        XCTAssertEqual(count("        let x = anchor + 1", selection), 0, "name as an OPERAND")
        XCTAssertEqual(count("        let x = head ?? 0", selection), 0)
        XCTAssertEqual(count("        let (a, b) = (anchor, head)", selection), 0,
                       "the tuple holding the names is on the RIGHT of the `=`")
        XCTAssertEqual(count("        let (anchor, head) = pair", selection), 0, "a tuple DECLARATION")
        XCTAssertEqual(count("        map[(anchor, head)] = value", selection), 0,
                       "a subscript key, not a destructuring target")

        // The two helpers Task 40b's fix round added, armed here for the same reason: both build
        // their regex with `try?` and answer 0 on failure, so an unarmed rule using them would be
        // green because it measured nothing.
        XCTAssertEqual(SwiftSourceScan.callSiteCount(in: "        inputBackend.setCanonicalAnchor(3)\n",
                                                     to: ["setCanonicalAnchor", "setCanonicalHead"]), 1)
        XCTAssertEqual(SwiftSourceScan.callSiteCount(in: "        t.inputBackend.setCanonicalHead(1)\n",
                                                     to: ["setCanonicalHead"]), 1,
                       "a `.`-qualified receiver is still a caller — the subject is the callee")
        XCTAssertEqual(SwiftSourceScan.callSiteCount(in: "    func setCanonicalAnchor(_ o: Int)\n",
                                                     to: ["setCanonicalAnchor"]), 0,
                       "a declaration is not a call site")
        XCTAssertEqual(SwiftSourceScan.identifierMentionCount(
            in: "        (inputBackend as? LegacyRichTextInputBackend)?.canonicalSelectionStorage = x\n",
            to: ["canonicalSelectionStorage"]), 1,
            "THE DOWNCAST DOOR — a `.`-qualified mention MUST be seen here, unlike in the write scan")
        XCTAssertEqual(SwiftSourceScan.identifierMentionCount(in: "        let x = canonicalSelectionStorageThing\n",
                                                              to: ["canonicalSelectionStorage"]), 0,
                       "a longer identifier with the same prefix is not a mention")
    }

    /// R9 — the D24 escape hatch is confined. `legacyCanvas` and `LegacyRichTextInputHost` may be
    /// named only by the canvas's own conformance and by files under `S/InputBackend/` whose name
    /// begins with `Legacy`. Without this, the refinement degenerates into "any file may reach the
    /// canvas through the backend", which is the ad-hoc downcast it exists to replace.
    func test_theLegacyCanvasAccessorIsConfinedToTheLegacyBackend() {
        RepoLayout.assertResolved()
        var offenders: [String] = []
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) {
            let name = url.lastPathComponent
            // FINAL BRANCH REVIEW: the path conjunct is load-bearing and was MISSING. The doc
            // comment above has always said "files under `S/InputBackend/` whose name begins with
            // `Legacy`", but this filtered on the BASENAME ALONE — so any `Legacy*.swift` anywhere in
            // the UIKit target, `Canvas/` included, exempted itself from the one rule confining the D24
            // escape hatch. Latent (no such file exists today), and one conjunct to close.
            let isLegacyBackendFile = name.hasPrefix("Legacy") && url.path.contains("/InputBackend/")
            if isLegacyBackendFile || name == "DocumentCanvasView.swift" { continue }
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            if text.contains("legacyCanvas") || text.contains("LegacyRichTextInputHost") {
                offenders.append(name)
            }
        }
        XCTAssertEqual(offenders, [],
                       "the D24 legacy-canvas escape hatch leaked outside the legacy backend: \(offenders)")
    }

    /// The positive half: the hatch must actually exist, so a rename cannot make R9 vacuous.
    func test_theLegacyCanvasAccessorExists() {
        let files = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
            .filter { $0.lastPathComponent.hasPrefix("Legacy") }
        XCTAssertTrue(files.contains {
            SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: $0))
                .contains("legacyCanvas")
        }, "no Legacy*.swift names legacyCanvas — R9 would pass vacuously")
    }

    /// R10 (added Task 22c, fix round 2; STRENGTHENED fix round 3) — a `BackendContractCases`
    /// subclass — at ANY DEPTH of inheritance, not just a direct subclass — may name a CONCRETE
    /// conformer of `RichTextInputBackend` OR `RichTextInputHost` ONLY inside its own `makeBackend()`
    /// override.
    ///
    /// Why this exists, and why the failure mode is SILENT rather than loud: `BackendContractCases`
    /// (Task 22a) is designed so stage 2 subclasses each of the eight 22b-22i suites and overrides
    /// ONLY `makeBackend()` — the whole point of typing `backend` as `any RichTextInputBackend`
    /// rather than the concrete type (that class's own doc comment: "a suite that finds itself
    /// needing a legacy-only member here has picked the wrong home for that test"). Nothing in the
    /// type system enforces this. A test can construct `LegacyRichTextInputBackend()` / a real
    /// `DocumentCanvasView()` directly, or force-cast to either, anywhere in its body — the file still
    /// compiles and the test still passes TODAY, because the legacy backend/canvas is what's under
    /// test in stage 1. The defect is dormant: the test is silently INHERITED by a stage-2 subclass
    /// (which changes nothing but `makeBackend()`), and it goes on reporting "contract coverage:
    /// passing" while, unbeknownst to anyone, still exercising the LEGACY backend/canvas regardless of
    /// what `makeBackend()` now returns. It becomes a real, LATE failure only once something the test
    /// reads no longer matches — potentially the Phase 6 gate, far downstream of the mistake. This is
    /// exactly the Task 22c review's Critical, caught by an ad-hoc `grep`, not by any mechanical check:
    /// `test_realDocumentClient_rebaseAlwaysRejectsAStaleSelection_byD32Construction` (relocated to
    /// `TelegramDocumentInputClientMutationTests` in fix round 2, precisely BECAUSE it could not be
    /// fixed in place — it needed the REAL `TelegramDocumentInputClient`/`DocumentCanvasView`, which a
    /// `BackendContractCases` subclass must never construct) never called `makeBackend()` at all — it
    /// built its own `DocumentCanvasView()`, whose `init` defaults `inputBackend` to
    /// `LegacyRichTextInputBackend()`. This rule fails NOW, at the point of the mistake.
    ///
    /// This is a FIXED rule, not a decreasing-baseline ratchet like R6/R7 above: the correct count is
    /// ZERO today and stays zero forever (unlike R6/R7, nothing about this rule is expected to regress
    /// as later tasks land) — so it is deliberately NOT wired into the ratchet machinery.
    ///
    /// FIX ROUND 3 widened this on three axes the re-review found narrower than the doc comment's own
    /// promise (round 2's version literally claimed to catch "a `DocumentCanvasView`-specific
    /// force-cast" while discovery covered only `RichTextInputBackend` conformers — a promise it did
    /// not keep):
    /// 1. **Host coupling is the same defect as backend coupling — discovery now covers BOTH protocol
    ///    families.** A contract suite has `fakeHost` for exactly this purpose, so a REAL
    ///    `DocumentCanvasView` (or any other concrete `RichTextInputHost` conformer) anywhere in one is
    ///    always the defect, with or without a backend force-cast alongside it. Without this, DELETING
    ///    the `as!` from the old (relocated) test 7 — which compiles fine, since `RichTextInputBackend`
    ///    already refines `RichTextKeyInputBackend` and `canvas.inputBackend` is already
    ///    protocol-typed — would have passed R10 while leaving exactly the inherited,
    ///    legacy-canvas-coupled test the rule exists to forbid.
    /// 2. **Retroactive conformance.** Discovery now matches `extension X: … Protocol …` as well as
    ///    `class X: … Protocol …` — this is not a hypothetical the repo might one day use (see
    ///    `extension ListViewImpl: ChatHistoryListViewBackend {}` in the chat layer): it is exactly how
    ///    `DocumentCanvasView`'s OWN host conformance is declared
    ///    (`extension DocumentCanvasView: LegacyRichTextInputHost {}`, `Canvas/DocumentCanvasView.swift`).
    ///    Without this, `DocumentCanvasView` would never enter the forbidden set at all, silently.
    /// 3. **Transitive scope.** The directory walk is now RECURSIVE (`RepoLayout.swiftFiles`, not a
    ///    non-recursive `contentsOfDirectory`), and "is this file in scope" is resolved by a TRANSITIVE
    ///    class-ancestry walk over every `class`/`extension` declaration found under
    ///    `Tests/RichTextEditorUIKitTests/InputBackend/` — not a literal `": BackendContractCases"`
    ///    substring match — so a stage-2 subclass shaped like `class
    ///    IDTextEditorBackendRevisionContractTests: BackendRevisionContractTests` (subclassing an
    ///    EXISTING suite, not `BackendContractCases` directly — precisely stage 2's shape) is scanned,
    ///    wherever in the tree it lands.
    ///
    /// TASK 23 — closes the gap Task 22c's own review flagged as speculative (and Task 22d hit for real,
    /// one layer over, as R11): discovery above scanned `Sources/` ONLY, so a TEST-SIDE concrete
    /// `RichTextInputBackend` conformer was invisible to it — specifically `SpyRichTextInputBackend`
    /// (`T/Support/SpyRichTextInputBackend.swift`), named by Task 22c's review as exactly this case.
    /// Had a `BackendContractCases` subclass constructed `SpyRichTextInputBackend()` directly instead of
    /// through `makeBackend()`, `concreteConformerNames` would never have contained that name at all —
    /// R10 would pass whether or not the offending file existed, the same silent, late-surfacing failure
    /// mode the rule exists to catch.
    ///
    /// Closed by widening discovery to ALSO scan `T/Support/` (`RepoLayout.uiKitTestsSupport`) for BOTH
    /// protocols, PLUS `T/InputBackend/` (`RepoLayout.uiKitTestsInputBackend` — recursive, so this also
    /// covers `T/InputBackend/Fakes/` and the `T/InputBackend/Routers/` directory Task 24 is about to
    /// create) for `RichTextInputBackend` ALONE, not `RichTextInputHost`.
    ///
    /// FIX ROUND 1 (review Major 2) — the ORIGINAL version of this widening reasoned that
    /// `T/InputBackend/Fakes/` could not be folded in at all, because `FakeInputHost`/
    /// `IncompatibleFakeHost` (both `RichTextInputHost` conformers living there) already have their own,
    /// differently-masked R11 mechanism, and scanning `Fakes/` for EITHER protocol would make R10 fail on
    /// `BackendContractCases.swift` ITSELF (its `makeHost(log:)` legitimately constructs
    /// `FakeInputHost(log: log)` outside `makeBackend()`, which R10 does not mask). That obstacle is
    /// REAL but was over-generalised: it is specific to the `RichTextInputHost` half of the protocol
    /// list — only a HOST conformer inside `Fakes/` risks the `makeHost(log:)` false positive. Scanning
    /// `T/InputBackend/` for `RichTextInputBackend` conformers ALONE closes the gap at ZERO risk, since
    /// R10 has never masked anything BUT `makeBackend()` bodies and no contract suite legitimately
    /// constructs a backend conformer inside `makeHost(log:)`.
    ///
    /// This also closes a gap the original widening missed entirely: `T/InputBackend/` itself already
    /// declares two concrete conformers TODAY — `private final class SpyBackend: RichTextInputBackend`
    /// and `private final class RecordingHost: LegacyRichTextInputHost`
    /// (`BackendAttachmentTests.swift:23,228`) — latent only because Swift's file-scoped `private` stops
    /// any OTHER file from referencing them; nothing stops a TEXT-based scanner from finding the
    /// declaration itself, `private` or not. Before this fix-round, neither was ever in
    /// `concreteConformerNames` (discovery never looked at `T/InputBackend/` at all), so a
    /// `BackendContractCases` subclass mentioning either name outside `makeBackend()` would have passed
    /// silently — the exact defect class this whole rule exists to catch, one layer removed from the
    /// spy.
    ///
    /// Proved red (then reverted) at THREE separate newly-covered locations in this fix round —
    /// `T/InputBackend/` itself (a reference to the existing, real `SpyBackend`), `T/InputBackend/Fakes/`
    /// (a fresh probe conformer), and `T/InputBackend/Routers/` (a fresh probe conformer in the
    /// not-yet-existing directory Task 24 creates) — each named as an offender in its own
    /// `BackendContractCases` subclass outside `makeBackend()`; all three reverted immediately after.
    /// See the task-23 report's fix-round-1 section for the exact commands and output.
    func test_noConcreteBackendOrHostNamedOutsideMakeBackend_R10() {
        RepoLayout.assertResolved()

        let concreteConformerNames = discoverConcreteConformers(
            ofAnyOf: ["RichTextInputBackend", "RichTextInputHost"], under: RepoLayout.uiKitSources)
        .union(discoverConcreteConformers(
            ofAnyOf: ["RichTextInputBackend", "RichTextInputHost"], under: RepoLayout.uiKitTestsSupport))
        .union(discoverConcreteConformers(
            ofAnyOf: ["RichTextInputBackend"], under: RepoLayout.uiKitTestsInputBackend))
        XCTAssertFalse(concreteConformerNames.isEmpty,
                       "discovery found no concrete RichTextInputBackend/RichTextInputHost conformer " +
                       "under Sources/, T/Support/ or T/InputBackend/ — this rule would pass VACUOUSLY " +
                       "(no name to look for)")
        XCTAssertTrue(concreteConformerNames.contains("LegacyRichTextInputBackend"),
                     "expected the one known concrete backend to be discovered")
        XCTAssertTrue(concreteConformerNames.contains("DocumentCanvasView"),
                     "DocumentCanvasView's host conformance is declared via a retroactive `extension … : " +
                     "LegacyRichTextInputHost` — if discovery ever stops finding it, R10 silently stops " +
                     "covering host coupling, which is the exact gap this fix-round closes")
        XCTAssertTrue(concreteConformerNames.contains("SpyRichTextInputBackend"),
                     "expected the Task-23 test-side spy to be discovered under T/Support/ — if this " +
                     "regresses, R10 silently stops covering test-side backend conformers again, exactly " +
                     "the gap Task 22c's review predicted and this fix-round closes")
        XCTAssertTrue(concreteConformerNames.contains("SpyBackend"),
                     "expected BackendAttachmentTests.swift's own (private, but textually visible) " +
                     "SpyBackend to be discovered under T/InputBackend/ — if this regresses, R10 " +
                     "silently stops covering backend conformers declared inside the InputBackend test " +
                     "tree itself, exactly the fix-round-1 review's Major 2 finding")

        let declarations = scanClassAndExtensionDeclarations(under: RepoLayout.uiKitTestsInputBackend)
        var parentsByName: [String: [String]] = [:]
        var namesByFile: [URL: [String]] = [:]
        for decl in declarations {
            parentsByName[decl.name, default: []].append(contentsOf: decl.parents)
            namesByFile[decl.file, default: []].append(decl.name)
        }

        var inScopeFiles: [URL] = []
        for (file, names) in namesByFile {
            let inScope = names.contains { name in
                var visited: Set<String> = []
                return typeAncestryReaches(name, "BackendContractCases",
                                           edges: parentsByName, visited: &visited)
            }
            if inScope { inScopeFiles.append(file) }
        }
        XCTAssertTrue(inScopeFiles.count >= 2,
                     "expected at least BackendContractCases.swift itself plus one real subclass file " +
                     "in scope — got \(inScopeFiles.map { $0.lastPathComponent }.sorted()); the " +
                     "transitive scan may be broken, which would make this rule pass VACUOUSLY")

        var offenders: [String] = []
        for url in inScopeFiles {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            let masked = maskingEveryOverride(ofSignaturePrefix: "func makeBackend()", in: text)
            for name in concreteConformerNames where masked.contains(name) {
                offenders.append("\(url.lastPathComponent) names \(name) outside makeBackend()")
            }
        }
        XCTAssertEqual(offenders, [],
                       "a BackendContractCases subclass (directly or transitively) named a concrete " +
                       "backend/host outside makeBackend(): \(offenders)")
    }

    /// R11 (added Task 22d, fix round 2) — companion to R10, closing a gap Task 22c's own review had
    /// flagged as speculative: R10's discovery scans `Sources/` only, so a TEST-SIDE concrete type
    /// escapes it entirely. Fix round 2's Major B is exactly that gap materializing — not as a
    /// backend, but as a HOST: `BackendPublicationContractTests.swift` constructed `FakeInputHost(log:
    /// log)` directly instead of calling the fixture's own `makeHost(log:)` factory
    /// (`BackendContractCases.swift`'s `makeHost`, whose own doc comment explicitly anticipates a
    /// subclass supplying a DIFFERENT host shape). A stage-2 subclass overriding `makeHost` would
    /// inherit that test unchanged and silently re-attach the WRONG (stage-1-only) host — the same
    /// silent, late-surfacing failure mode R10 exists to catch, one layer over (a host instead of a
    /// backend).
    ///
    /// SCOPE: `FakeInputHost(` and `IncompatibleFakeHost(` construction calls ONLY — those are the
    /// two fixture-provided types `BackendContractCases` offers an actual FACTORY for
    /// (`makeHost(log:)`; a subclass override can return either). Deliberately does NOT cover the
    /// per-client fakes (`FakeInputDocumentClient`, `FakeInputGeometryClient`,
    /// `FakeInputAnnotationClient`, `FakeInputPresentationClient`, `FakeInputLifecycleClient`,
    /// `FakeInputCommandClient`) or `RecordingInputDelegate` — no `makeX` factory exists for any of
    /// them individually (every contract suite reaches them only through `fakeHost!.fakeXClient`,
    /// never by constructing one directly), so there is no factory-bypass for this rule to detect; a
    /// future task that adds a per-fake factory should extend this rule's name set alongside it.
    /// `FakeClientSelfTests.swift` constructs several of them directly (`FakeInputDocumentClient(log:
    /// log)` etc.) — that file is a plain `XCTestCase`, NOT a `BackendContractCases` descendant (it
    /// tests the fakes' own self-consistency), so it is correctly out of this rule's scope by the same
    /// ancestry walk R10 uses, exactly as it is legitimately out of R10's scope today.
    ///
    /// Same rules as R10: a FIXED rule, not a decreasing-baseline ratchet — the correct count is ZERO
    /// today and stays zero forever, so it is deliberately NOT wired into the R6/R7 machinery.
    /// `makeHost(log:)`'s own body (`BackendContractCases.swift`, and any subclass override) is masked
    /// out before scanning, exactly like R10 masks `makeBackend()` bodies — that is the ONE legitimate
    /// place either name may appear as a construction call.
    func test_noFixtureHostConstructedOutsideItsFactory_R11() {
        RepoLayout.assertResolved()

        let factoryProvidedHostNames = ["FakeInputHost", "IncompatibleFakeHost"]

        let declarations = scanClassAndExtensionDeclarations(under: RepoLayout.uiKitTestsInputBackend)
        var parentsByName: [String: [String]] = [:]
        var namesByFile: [URL: [String]] = [:]
        for decl in declarations {
            parentsByName[decl.name, default: []].append(contentsOf: decl.parents)
            namesByFile[decl.file, default: []].append(decl.name)
        }

        var inScopeNamesByFile: [URL: Set<String>] = [:]
        for (file, names) in namesByFile {
            let inScopeNames = names.filter { name in
                var visited: Set<String> = []
                return typeAncestryReaches(name, "BackendContractCases",
                                           edges: parentsByName, visited: &visited)
            }
            if !inScopeNames.isEmpty { inScopeNamesByFile[file] = Set(inScopeNames) }
        }
        XCTAssertTrue(inScopeNamesByFile.count >= 2,
                     "expected at least BackendContractCases.swift itself plus one real subclass file " +
                     "in scope — got \(inScopeNamesByFile.keys.map { $0.lastPathComponent }.sorted()); " +
                     "the transitive scan may be broken, which would make this rule pass VACUOUSLY")

        // FIX ROUND 3 (review item 1) — the positive half of R10's own three-axis guard (`:327-335`),
        // applied here: prove `extractingDeclarationBodies` actually extracts something SCANNABLE
        // before trusting the (currently-empty) `offenders` list below. Without this, a regression
        // that made extraction always return "" would leave `masked` empty for every file, `offenders`
        // empty, and the rule PASSES — "reads as enforcement, enforces nothing", the exact failure
        // this task has now hit twice (R10's masking bug, R11's own file-level false positive).
        // `BackendContractCases.swift` is guaranteed to be among `inScopeNamesByFile` (its own name
        // trivially reaches itself via `typeAncestryReaches`), and its `makeHost(log:)` body is known,
        // by inspection, to construct `FakeInputHost(log: log)` — so requiring that literal substring
        // to survive EXTRACTION (before masking removes it) proves extraction reaches all the way
        // into a real factory body, not just past an opening brace into nothing.
        var sawNonEmptyExtraction = false
        var sawFakeInputHostBeforeMasking = false

        var offenders: [String] = []
        for (url, inScopeNames) in inScopeNamesByFile {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            // NARROWED to just the in-scope declaration(s)' OWN body (fix round 2 — a genuine false
            // positive found while red-checking this rule): a file can, and per
            // `FakeClientSelfTests.swift` DOES, also contain an UNRELATED class (a plain `XCTestCase`,
            // not a `BackendContractCases` descendant) that legitimately constructs these same
            // fixture types directly — testing the fakes' own self-consistency, not the contract (see
            // that file's `IncompatibleFakeHost(log: log)` at its `is any LegacyRichTextInputHost`
            // assertion). Scanning the WHOLE file would misattribute that legitimate construction to
            // whichever unrelated `BackendContractCases` subclass happens to share the file.
            let declarationBodies = extractingDeclarationBodies(named: inScopeNames, from: text)
            if !declarationBodies.isEmpty { sawNonEmptyExtraction = true }
            if declarationBodies.contains("FakeInputHost(") { sawFakeInputHostBeforeMasking = true }
            let masked = maskingEveryOverride(ofSignaturePrefix: "func makeHost(", in: declarationBodies)
            for name in factoryProvidedHostNames where masked.contains("\(name)(") {
                offenders.append("\(url.lastPathComponent) constructs \(name)( outside makeHost()")
            }
        }
        XCTAssertTrue(sawNonEmptyExtraction,
                     "extractingDeclarationBodies returned EMPTY text for EVERY in-scope declaration — " +
                     "this rule would pass VACUOUSLY (nothing to scan)")
        XCTAssertTrue(sawFakeInputHostBeforeMasking,
                     "no in-scope declaration's extracted (pre-mask) body contained \"FakeInputHost(\" " +
                     "anywhere, even though BackendContractCases.swift's own makeHost(log:) legitimately " +
                     "constructs FakeInputHost(log: log) — extraction is not reaching real declaration " +
                     "bodies, so this rule would pass VACUOUSLY regardless of what a subclass does")
        XCTAssertEqual(offenders, [],
                       "a BackendContractCases subclass constructed a fixture host directly instead " +
                       "of through makeHost(log:): \(offenders)")
    }

    /// R20 (added Task 34) — **no pending-routing RESIDUE anywhere under `S/InputBackend/`.** Successor
    /// to R13, which Task 34 deleted, and to its UIKit twin
    /// `BackendAttachmentTests.test_everyPendingRoutingStubNamesTheTaskThatDeletesIt`, deleted in the
    /// same commit.
    ///
    /// # FIX ROUND 1 — this rule used to be called `test_phase4IsOverAndNoPendingRoutingResidueRemains_R20`
    ///
    /// **It claimed more than it checks, and the review proved the gap the direct way rather than
    /// arguing it: the four mutations that REVERTED real routing call sites left this rule GREEN.** A
    /// tree in which family 11 does not route at all still passes it. That is Rule 14's shape — a claim
    /// that advertises more than it delivers — landing on Rule 13's subject, in the rule added to
    /// certify the phase. The name and this header now describe the check that runs.
    ///
    /// **What this rule checks:** that three source tokens are ABSENT. Nothing about routing.
    /// **What it does NOT check:** that any witness family routes, that any canvas call site reaches the
    /// backend, or that any backend member has a body. Residue absence is a necessary consequence of
    /// Phase 4 finishing, not evidence that it did.
    ///
    /// **Where the completion evidence actually lives**, so this header points somewhere rather than
    /// merely disclaiming: the per-family router suites (`T/InputBackend/Routers/`), one per family,
    /// which assert through `SpyRichTextInputBackend` that each canvas call site reaches exactly one
    /// backend member with exact arguments and that the canvas does no work of its own — plus
    /// `RouterWitnessBodyTests` (every routed witness body is a one-line `inputBackend.…` forward) and
    /// R17 below (every routed backend member has the shape its entry declares). Those are the rules a
    /// reverted routing call site reddens; **this one is not, and was never going to be.** Widening it
    /// to become a completion gate was considered and rejected at the same fix round: it would have to
    /// re-derive per-family routing from source text, duplicating three rules that already check it
    /// behaviourally. **A narrower rule with an accurate name beats a gate whose name is the strongest
    /// claim in the file.**
    ///
    /// # Why the rules it replaces had to die rather than pass
    ///
    /// Both anchored on the `pendingRouting(_:)` funnel DECLARATION — R13 subtracted it from a call-site
    /// count and asserted it present; the UIKit twin asserted it present as its own vacuity anchor. Task
    /// 34 deleted the funnel, so both would have failed on correct source. Their own doc comments said
    /// so in as many words, and the UIKit one carried the generalisation worth keeping here:
    ///
    /// > a vacuity guard anchored on a quantity a schedule is deliberately driving to zero will fire on
    /// > the correct source, one step before the thing it was protecting is gone — and if the count is
    /// > interesting enough to guard once, expect it to be guarded twice.
    ///
    /// It was guarded twice, in two different TEST TARGETS, and neither knew about the other. **R20 is
    /// deliberately ONE rule in ONE place.** It lives in the Core suite rather than the UIKit one so it
    /// runs under a bare `swift test` as well as under `Scripts/iostest.sh`; the UIKit twin only ever
    /// surfaced in a full simulator run, which is how it stayed unexamined.
    ///
    /// # Why it is still stronger than the assertion Task 34's brief asked for
    ///
    /// The brief asked for `LegacyRichTextInputBackend.pendingRoutingInventory.isEmpty`. That Set was
    /// empty from Task 33 on, so `isEmpty` was already true and could not fail — the exact shape of dead
    /// assertion this task had to repair in two other suites. An `.isEmpty` check is also a claim about
    /// a Set someone can repopulate, not about the source. This rule asserts absence across EVERY file
    /// under `S/InputBackend/`, so it survives the Set's deletion (which is what happened) and it covers
    /// files the Set never described.
    ///
    /// **The three tokens, and why each is scanned where it is:**
    ///   * `pendingRouting(` — the funnel call (and its declaration). Scanned in STRIPPED text, so the
    ///     many historical doc comments that still quote the literal in prose cannot trip it. Note it
    ///     deliberately does NOT match `pendingRoutingCalls`, which survives as a test-recording array
    ///     with no production writer (see `+Unwitnessed.swift`).
    ///   * `pendingRoutingInventory` — the deleted Set's identifier, likewise in stripped text.
    ///   * `// routed in Task` — the per-stub marker. This one is scanned in RAW text precisely because
    ///     it IS a comment: the stripper blanks it, so a stripped-text scan for it could never fire.
    ///
    /// **Vacuity anchors.** (1) There must be files to scan. (2) The stripper must be producing real
    /// code — anchored on `RichTextInputBackend`, the composite protocol's own name, which is declared
    /// under this directory and is not a quantity any schedule is driving to zero (the failure mode the
    /// rule this replaces died of). (3) `pendingRoutingResidue(stripped:raw:)` is exercised against
    /// synthetic fixtures by `test_thePendingRoutingResidueScanActuallyDetects_R20`, so a scan that
    /// regressed to finding nothing fails there rather than passing here — the `…ActuallyDetects`
    /// precedent R14-R17 set. That self-test also carries the case the deleted UIKit predicate's own
    /// self-test existed for (a doc comment merely MENTIONING the literal must not trip the scan), which
    /// the stripper handles more thoroughly than that predicate's `//`-prefix heuristic did: block
    /// comments too.
    func test_noPendingRoutingResidueRemains_R20() {
        RepoLayout.assertResolved()
        let files = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
        XCTAssertFalse(files.isEmpty, "no S/InputBackend sources found — R20 would pass VACUOUSLY")

        var offenders: [String] = []
        var sawRealCode = false
        for url in files {
            let raw = (try? String(contentsOf: url)) ?? ""
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals(raw)
            if stripped.contains("RichTextInputBackend") { sawRealCode = true }
            offenders += Self.pendingRoutingResidue(stripped: stripped, raw: raw)
                .map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertTrue(sawRealCode,
                      "the stripper produced no recognisable code across \(files.count) files — R20 " +
                      "would pass VACUOUSLY")
        XCTAssertEqual(offenders, [],
                       "pending-routing RESIDUE under S/InputBackend/ — no funnel call, inventory " +
                       "reference or `// routed in Task` stub marker may remain. This says nothing " +
                       "about whether a family ROUTES; the per-family suites in T/InputBackend/Routers/ " +
                       "own that (see this rule's doc comment). — \(offenders)")
    }

    /// R21 (added TASK 42 FIX ROUND 1, review Major 1) — **the three floating-cursor MIRROR CLEARS must
    /// be PRESENT.** A MUST-CONTAIN rule, and the first one in this file.
    ///
    /// **Why a source rule when this file's own standing generalisation says presence needs a
    /// BEHAVIOURAL pin.** That generalisation (recorded at `cancelActiveInteraction(reason:)` in
    /// `routedBackendMembers`: *"`.statements` is a rule about what a body MAY contain, never about
    /// what it MUST contain or in what sequence. A member whose correctness depends on presence or
    /// order needs a behavioural pin"*) is right, and it was followed as far as it can be followed
    /// here: `FloatingCursorStateAuthorityTests.test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend`
    /// is that behavioural pin, and it reaches TWO of the three. The third,
    /// `hostWillResignFirstResponder()`, is unreachable behaviourally **by construction**, not by
    /// omission: since Task 42 collapsed the two stores, `cancelFloatingCursor()` clears the same flag
    /// on every attached path (masking the mirror), and on a canvas-less backend that member's own
    /// `guard isAttached, let host, let canvas = legacyCanvas else { return }` returns BEFORE the
    /// clear. There is no configuration left in which deleting it changes an observable. So the choice
    /// is a source rule or no rule, and the measurement that makes that choice non-optional is Task
    /// 42's review: **all three clears were deleted and the entire suite stayed green** —
    /// `Executed 2303 tests, with 5 tests skipped and 0 failures` + `383` Core, exit 0.
    ///
    /// **What it forbids, concretely.** A future task reads the flag's WRITERS list, concludes the
    /// three members already cover every cancel path, and simplifies `DocumentCanvasView`'s
    /// `cancelFloatingCursor()` by dropping its own `setFloatingCursorActive(false)` — or does the
    /// reverse and drops the mirrors because "the cancel clears it now". Either way the
    /// `selectedTextRange` setter latches `true` after an interrupted gesture, permanently and
    /// silently, which is the exact defect Task 33 added these clears to prevent. The canvas half is
    /// pinned behaviourally (`TelegramPresentationInputClientTests
    /// .test_tearDownPresentationCancelsAnActiveFloatingCursor` reddens when it is dropped — measured
    /// in this fix round); this rule is the backend half.
    ///
    /// **Vacuity.** Each signature must occur EXACTLY ONCE across `S/InputBackend/Legacy*.swift`, the
    /// same construction R17's "vacuity half B" uses, so a rename cannot silently retire a row; and the
    /// required text must be found in the extracted BODY, so a body the extractor fails to reach is an
    /// offender rather than a pass. Comments are stripped before the search, so a doc comment merely
    /// quoting the statement cannot satisfy it.
    ///
    /// RED IF: any of the three clears is deleted. **Confirmed red for all three, one at a time**, each
    /// naming the member and printing the body it searched.
    func test_theFloatingCursorMirrorClearsArePresent_R21() {
        RepoLayout.assertResolved()
        // (signature, required statement). The statement is spelled EXACTLY as the source spells it,
        // including `hostWillMove`'s single-line `if` branch — that branch is load-bearing (an
        // unconditional clear drops the suppression mid-gesture on any announced window change) and a
        // prefix-only match would admit its removal.
        let required: [(member: String, signature: String, statement: String)] = [
            ("hostWillResignFirstResponder()",
             "func hostWillResignFirstResponder()",
             "floatingCursorActive = false"),
            ("hostWillMove(toWindow:)",
             "func hostWillMove(toWindow window: UIWindow?)",
             "if window == nil { floatingCursorActive = false }"),
            ("cancelActiveInteraction(reason:)",
             "func cancelActiveInteraction(reason: RichTextInteractionCancellationReason)",
             "floatingCursorActive = false"),
        ]

        let files = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
            .filter { $0.lastPathComponent.hasPrefix("Legacy") }
        XCTAssertFalse(files.isEmpty, "no Legacy*.swift sources found — R21 would pass VACUOUSLY")
        let sources: [(name: String, stripped: String)] = files.map {
            ($0.lastPathComponent,
             SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: $0)) ?? ""))
        }

        var offenders: [String] = []
        for row in required {
            let total = sources.reduce(0) {
                $0 + ($1.stripped.components(separatedBy: row.signature).count - 1)
            }
            guard total == 1 else {
                offenders.append("\(row.member): signature found \(total) times under "
                                 + "S/InputBackend/Legacy*.swift, expected exactly 1")
                continue
            }
            guard let body = sources.compactMap({
                Self.balancedBody(after: row.signature, in: $0.stripped)
            }).first else {
                offenders.append("\(row.member): could not extract a balanced body")
                continue
            }
            if !Self.normalizingWhitespace(body).contains(Self.normalizingWhitespace(row.statement)) {
                offenders.append("\(row.member): MISSING its mirror clear `\(row.statement)` — body: \(body)")
            }
        }
        XCTAssertEqual(offenders, [],
                       "R21 floating-cursor mirror-clear violations: \(offenders). Each of these three "
                       + "backend members reaches `DocumentCanvasView.cancelFloatingCursor()` and must "
                       + "clear `floatingCursorActive` itself, so the un-latching is a property of the "
                       + "MEMBER rather than of what its forward happens to do. Since Task 42 collapsed "
                       + "the two stores the cancel's own clear MASKS all three on every attached path "
                       + "— deleting them leaves the whole suite green — which is why presence is "
                       + "asserted here on the source instead. Two of the three also have a behavioural "
                       + "pin (`FloatingCursorStateAuthorityTests"
                       + ".test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend`); "
                       + "`hostWillResignFirstResponder()`'s cannot have one — its guard binds "
                       + "`let canvas = legacyCanvas` and returns before the clear. Read the per-path "
                       + "table at the flag's declaration before changing any of the three.")
    }

    /// The scan half of R20, factored out so `test_thePendingRoutingResidueScanActuallyDetects_R20`
    /// exercises THE SAME code against synthetic fixtures rather than a second, drifting copy.
    /// `stripped` must be `SwiftSourceScan.stripCommentsAndStringLiterals(raw)`; `raw` is passed
    /// because the marker token is itself a comment and is invisible in the stripped text.
    private static func pendingRoutingResidue(stripped: String, raw: String) -> [String] {
        var out: [String] = []
        if stripped.contains("pendingRouting(") {
            out.append("live `pendingRouting(` — the Task-34 funnel is deleted; nothing may call or " +
                       "redeclare it")
        }
        if stripped.contains("pendingRoutingInventory") {
            out.append("live `pendingRoutingInventory` — the Set is deleted; a reader of it cannot " +
                       "compile, so this is a re-added declaration")
        }
        if raw.contains("// routed in Task") {
            out.append("a `// routed in Task` stub marker — Phase 4 routed every family; a stub " +
                       "naming a future task has nothing left to name")
        }
        return out
    }

    /// The positive half of R20 (the `…ActuallyDetects` precedent R14-R17 set): the scan is pinned
    /// against synthetic input, so a regression to "finds nothing" fails HERE rather than silently
    /// certifying the real tree. Fixtures spell `example()`, never `func test_…`, per R14's fix-round
    /// lesson.
    func test_thePendingRoutingResidueScanActuallyDetects_R20() {
        func residue(_ source: String) -> [String] {
            Self.pendingRoutingResidue(
                stripped: SwiftSourceScan.stripCommentsAndStringLiterals(source), raw: source)
        }

        XCTAssertEqual(residue("func example() {\n    doWork()\n}\n"), [],
                       "clean source must produce no offenders")
        XCTAssertEqual(residue("func example() {\n    pendingRouting()\n}\n").count, 1,
                       "a re-added funnel call must be detected")
        XCTAssertEqual(residue("func example() {\n    pendingRouting(\"tokenizer\")\n}\n").count, 1,
                       "…including the explicit-argument spelling, which a bare `pendingRouting()` " +
                       "substring search undercounts (R13 found that the hard way)")
        XCTAssertEqual(residue("static let pendingRoutingInventory: Set<String> = []\n").count, 1,
                       "a re-added inventory declaration must be detected")
        XCTAssertEqual(residue("func example() {\n    stub()   // routed in Task 24\n}\n").count, 1,
                       "a stub marker must be detected — and it is scanned in RAW text, because the " +
                       "stripper blanks comments and a stripped scan could never see it")

        // The case the DELETED UIKit predicate's own self-test existed for, carried forward: a doc
        // comment merely MENTIONING the literal must not trip the scan. The stripper covers strictly
        // more than that predicate's `//`-prefix heuristic did — a BLOCK comment too, which the
        // heuristic explicitly did not understand.
        XCTAssertEqual(residue("/// mentions pendingRouting( in prose\nfunc example() {}\n"), [],
                       "a doc comment naming the funnel must not trip the scan")
        XCTAssertEqual(residue("/* pendingRouting() and pendingRoutingInventory */\nfunc example() {}\n"), [],
                       "a BLOCK comment naming both must not trip it either — the heuristic this " +
                       "replaces could not see block comments at all")
        XCTAssertEqual(residue("func example() {\n    Self.pendingRoutingCalls.append(\"x\")\n}\n"), [],
                       "`pendingRoutingCalls` SURVIVES as a test-recording array and must not be " +
                       "mistaken for the deleted funnel — it contains no open paren after the name")
    }

    /// R12 (added Task 22g fix round 3) — `activeTransactionDepth`
    /// (`LegacyRichTextInputBackend.swift`) is mutated in exactly THREE sanctioned functions:
    /// `withTransaction(_:)` and `endTransaction()` (both `LegacyRichTextInputBackend+Attachment.swift`)
    /// and `performDetachSteps()` (same file). The property's own doc comment states this as prose,
    /// and this project has repeatedly found that prose invariants over this tree go stale silently
    /// (the exact lesson R7's own doc comment records). This makes it mechanically checkable: mask
    /// away the three sanctioned functions' bodies (reusing `maskingEveryOverride`, the same helper
    /// R10/R11 use to mask `makeBackend()`/`makeHost(log:)`), then assert no OTHER reference to the
    /// identifier remains anywhere under `Sources/RichTextEditorUIKit/InputBackend` except the
    /// property's own declaration line.
    ///
    /// A FIXED rule, not a decreasing-baseline ratchet like R6/R7 — same reasoning as R10/R11: the
    /// correct count of "mutation sites outside the three sanctioned functions" is ZERO today and
    /// stays zero forever. Worth having now, not later: Tasks 27/28 will be working in exactly this
    /// file.
    ///
    /// Uses `SwiftSourceScan.stripCommentsAndStringLiterals`, exactly like every rule above, so a doc
    /// comment merely MENTIONING the identifier cannot trip this — that specific false-positive shape
    /// has already cost this project two tasks (the `pendingRouting(` scan, Task 22g's own referred
    /// item (a)).
    func test_activeTransactionDepthMutatedOnlyInSanctionedFunctions_R12() {
        RepoLayout.assertResolved()
        let sanctionedSignatures = [
            "func withTransaction(",
            "func endTransaction()",
            "private func performDetachSteps()",
        ]
        let identifier = "activeTransactionDepth"
        let declarationLine = "var \(identifier): Int = 0"

        var sawIdentifierBeforeMasking = false
        var sawMaskingRemoveAtLeastOneOccurrence = false
        var offenders: [String] = []

        for url in RepoLayout.swiftFiles(under: RepoLayout.inputBackend) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            guard text.contains(identifier) else { continue }
            sawIdentifierBeforeMasking = true

            let countBefore = text.components(separatedBy: identifier).count - 1

            var masked = text
            for signature in sanctionedSignatures {
                masked = maskingEveryOverride(ofSignaturePrefix: signature, in: masked)
            }
            let countAfterMasking = masked.components(separatedBy: identifier).count - 1
            if countAfterMasking < countBefore { sawMaskingRemoveAtLeastOneOccurrence = true }

            // The property's OWN declaration is the one bare mention allowed outside the three
            // sanctioned bodies.
            let expectedRemainder = masked.contains(declarationLine) ? 1 : 0
            if countAfterMasking > expectedRemainder {
                offenders.append("\(url.lastPathComponent) " +
                                 "(\(countAfterMasking - expectedRemainder) unsanctioned mention(s))")
            }
        }

        XCTAssertTrue(sawIdentifierBeforeMasking,
                     "the scan found no occurrence of \(identifier) anywhere under InputBackend/ — " +
                     "this rule would pass VACUOUSLY")
        XCTAssertTrue(sawMaskingRemoveAtLeastOneOccurrence,
                     "masking the three sanctioned function bodies removed NO occurrence of " +
                     "\(identifier) anywhere — extraction is not reaching the real bodies, so this " +
                     "rule would pass VACUOUSLY regardless of what a future site does")
        XCTAssertEqual(offenders, [],
                       "\(identifier) is referenced outside withTransaction(_:)/endTransaction()/" +
                       "performDetachSteps(): \(offenders)")
    }

    /// R14 (added Task 24) — no test file under `T/InputBackend/Routers/` may read `.inputBackend.`
    /// directly. Task 23's own settled fix is the exact defect this guards against:
    /// `test_beginningOfDocument_returnsTheBackendsExactObject` originally read through
    /// `canvas.inputBackend.beginningOfDocument`, which proves only that the SPY works, not that the
    /// CANVAS routes to it — a router test's whole point is the opposite direction. A rewrite of any
    /// future family task's router test that "simplifies" back to the spy's own backend reference (a
    /// plausible copy-paste slip once ten more of these files exist) is caught here, not by a reviewer's
    /// re-read of every worked example.
    ///
    /// A FIXED, zero-forever rule (like R10/R11/R12), NOT wired into the R6/R7 decreasing-baseline
    /// ratchet machinery — the correct count of `.inputBackend.` mentions in this directory is ZERO
    /// today and stays zero forever; there is no legitimate reason a router test ever needs the spy's
    /// own backend reference (`spy.calls`/`spy.stubbedX`/`spy.sentinelX` are always the right handle).
    ///
    /// Positive self-check (`test_theInputBackendDotDetectionActuallyDetects_R14`, below): unit-tests
    /// the SAME detection expression this rule uses against two synthetic strings — one with a real
    /// `.inputBackend.` mention in code (must be caught) and one where the identical substring appears
    /// ONLY inside a `//` comment (must be ignored, via `SwiftSourceScan.stripCommentsAndStringLiterals`,
    /// exactly like every other rule in this file) — so a rule that regressed to a no-op (e.g. an
    /// always-`true`/always-`false` predicate) fails HERE, not by silently covering nothing on the real
    /// directory. Proved red against the REAL `TextReadRouterTests.swift` (temporarily reintroducing
    /// `canvas.inputBackend.beginningOfDocument` into its first test), then reverted — see the task-24
    /// report for the exact command and output.
    func test_noInputBackendDotMentionInRouterTests_R14() {
        RepoLayout.assertResolved()
        let files = RepoLayout.swiftFiles(under: RepoLayout.uiKitTestsRouters)
        XCTAssertFalse(files.isEmpty,
                       "no files found under T/InputBackend/Routers/ — this rule would pass VACUOUSLY " +
                       "(Task 24 is expected to have created this directory)")
        var offenders: [String] = []
        for url in files {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            if stripped.contains(".inputBackend.") {
                offenders.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(offenders, [],
                       "a router test read `.inputBackend.` directly instead of routing through the " +
                       "CANVAS — this proves the spy works, not that the canvas routes to it: \(offenders)")
    }

    /// The positive half of R14 above — see that test's own doc comment.
    ///
    /// TASK 24 FIX ROUND 1 (Minor, reviewer) — the two synthetic fixtures below name their probe
    /// function `exampleWitness()`, deliberately NOT an XCTest-shaped name (a prior version used one,
    /// spelled identically in BOTH string literals, which inflated any indentation-insensitive
    /// grep-based test count by two — exactly the "18, not 16" reconciliation this project's own
    /// boundary count cost a review pass to track down). A synthetic fixture inside a test file must
    /// never spell an XCTest-shaped declaration, even inside a string literal nothing here treats as
    /// a real one.
    func test_theInputBackendDotDetectionActuallyDetects_R14() {
        let violatingSource = """
        func exampleWitness() {
            let x = canvas.inputBackend.beginningOfDocument
        }
        """
        let safeSource = """
        func exampleWitness() {
            // do not read canvas.inputBackend.beginningOfDocument here — use the canvas member instead
            let x = canvas.beginningOfDocument
        }
        """
        let strippedViolating = SwiftSourceScan.stripCommentsAndStringLiterals(violatingSource)
        let strippedSafe = SwiftSourceScan.stripCommentsAndStringLiterals(safeSource)
        XCTAssertTrue(strippedViolating.contains(".inputBackend."),
                     "the detection expression must catch a real, in-code `.inputBackend.` mention")
        XCTAssertFalse(strippedSafe.contains(".inputBackend."),
                      "the detection expression must NOT flag a mention that appears only inside a " +
                      "comment, once comments are stripped — otherwise this rule would forbid even " +
                      "documenting the trap it guards against")
    }

    /// R15 (added Task 25 — REQUIRED per this task's brief, not merely "recommended" as Task 24's
    /// review offered it) — bans a force-unwrap of ANY of the backend's weak-`host`-derived accessors
    /// anywhere under `Sources/RichTextEditorUIKit/InputBackend/`: `legacyCanvas`, `document`,
    /// `geometry`, `annotation`, `presentation`, `lifecycle`, `command` (all seven,
    /// `LegacyRichTextInputBackend.swift`'s "Six convenience accessors" section plus `legacyCanvas`
    /// itself), and `host` directly. Task 24's Critical was NINE force-unwraps of exactly THREE of
    /// these eight names (`+TextReads.swift`, all funnelling through the single weak `host`), reachable
    /// in five documented post-attach states (a swallowed `attach(to:)` throw; the contract-sanctioned
    /// "attached but host deallocated" state
    /// `BackendAttachDetachTests.test_backendRetainsHostWeakly` asserts directly; the detach→reattach
    /// window; `DocumentCanvasView.deinit`'s window, where Swift zeroes `weak host` before `deinit`'s
    /// body runs; and a `DocumentTokenizer` — which holds the canvas `unowned`, outliving the weak
    /// `host` — querying during interaction teardown) and reproduced an ACTUAL `Fatal error:
    /// Unexpectedly found nil` before being hand-fixed. Nothing but convention (the class's own
    /// established `guard let legacyCanvas = self.legacyCanvas else { … }` idiom) stops the same
    /// mistake from being reintroduced, and ten more families (Tasks 26-34) still have to write new
    /// members over this exact weak-`host` seam. This rule makes the shape mechanically unrepresentable
    /// instead of relying on a reviewer catching it family by family.
    ///
    /// TASK 25 FIX ROUND 1 (Major, reviewer) — the first version of this rule banned only
    /// `legacyCanvas!`/`document!`/`host!`, enumerating by INSTANCE (the three names Task 24's crash
    /// happened to use) rather than by SHAPE (any force-unwrap of any host-derived accessor). That left
    /// `geometry!` unguarded — in THIS family, whose every member reads `geometry` — and
    /// `presentation!`/`annotation!`/`lifecycle!`/`command!` unguarded for Task 26 onward. Widened to
    /// all seven accessor names (plus `host` itself) so the rule would have caught Task 24's Critical
    /// no matter which of the seven it had been written against.
    ///
    /// A FIXED rule, in the same style as R10-R14 above — the correct count is ZERO today and stays
    /// zero forever (every existing member already uses the guard-based idiom instead), so it is
    /// deliberately NOT wired into the R6/R7 decreasing-baseline machinery.
    ///
    /// Uses `SwiftSourceScan.stripCommentsAndStringLiterals`, exactly like every rule above, so a doc
    /// comment merely NAMING one of these patterns in prose (as this very comment does) cannot trip
    /// it — only a live force-unwrap in code can.
    ///
    /// Non-vacuity: asserts the scanned file list is non-empty first (TASK 25 FIX ROUND 1, reviewer
    /// Minor — every neighbouring rule in this file carries this guard; the original version of R15
    /// did not).
    ///
    /// Proved red (then reverted) twice: a temporary `legacyCanvas!` was added to
    /// `LegacyRichTextInputBackend+Geometry.swift`'s `caretRect(for:)` when this rule first landed
    /// (Task 25's original commit), and a temporary `geometry!` was added to the same function when
    /// this fix round widened the pattern list — both re-runs failed naming that file, then the
    /// temporary lines were removed. See the fix-round report for the second command and output.
    func test_noForceUnwrappedWeakHostAccessorsAnywhereUnderInputBackend_R15() {
        RepoLayout.assertResolved()
        let patterns = [
            "legacyCanvas!", "document!", "geometry!", "annotation!", "presentation!", "lifecycle!",
            "command!", "host!",
        ]

        let files = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
        XCTAssertFalse(files.isEmpty,
                       "no files found under InputBackend/ — this rule would pass VACUOUSLY")

        var offenders: [String] = []
        for url in files {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            for pattern in patterns where stripped.contains(pattern) {
                offenders.append("\(url.lastPathComponent) contains \(pattern)")
            }
        }
        XCTAssertEqual(offenders, [],
                       "a force-unwrap of one of the backend's weak-host-derived accessors was found " +
                       "— this is the exact Task-24 Critical shape (a real `Fatal error: Unexpectedly " +
                       "found nil`), reachable any time `host` is nil while `isAttached` may still read " +
                       "`true`: \(offenders)")
    }

    /// The positive half of R15 above — proves the scan actually detects EACH of the eight patterns
    /// (widened from three in this fix round, one synthetic fixture per name so no single name's
    /// detection is assumed from another's), and that a comment-only mention (stripped before the scan
    /// runs) is correctly ignored. Named `example()`, deliberately NOT an XCTest-shaped name (R14's own
    /// fix-round lesson: a synthetic fixture that spells `func test_…` inflates any
    /// indentation-insensitive grep-based test count).
    func test_theForceUnwrapDetectionActuallyDetects_R15() {
        let violatingFixtures: [(name: String, source: String)] = [
            ("legacyCanvas!", """
            func example() -> CGRect {
                return legacyCanvas!.legacyCaretRect(globalOffset: 0) ?? .zero
            }
            """),
            ("document!", """
            func example() -> Int {
                return document!.utf16Length
            }
            """),
            ("geometry!", """
            func example() -> UInt64 {
                return geometry!.layoutGeneration
            }
            """),
            ("annotation!", """
            func example() -> Bool {
                return annotation! is AnyObject
            }
            """),
            ("presentation!", """
            func example() -> Bool {
                return presentation! is AnyObject
            }
            """),
            ("lifecycle!", """
            func example() -> Bool {
                return lifecycle! is AnyObject
            }
            """),
            ("command!", """
            func example() -> Bool {
                return command! is AnyObject
            }
            """),
            ("host!", """
            func example() {
                host!.legacyCanvas.setNeedsDisplay()
            }
            """),
        ]
        let patterns = [
            "legacyCanvas!", "document!", "geometry!", "annotation!", "presentation!", "lifecycle!",
            "command!", "host!",
        ]
        for fixture in violatingFixtures {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals(fixture.source)
            XCTAssertTrue(
                patterns.contains { stripped.contains($0) },
                "the detection expression failed to catch a real force-unwrap of \(fixture.name) in a " +
                "synthetic fixture")
        }
        let commentOnly = """
        // never force-unwrap legacyCanvas!, document!, geometry!, annotation!, presentation!,
        // lifecycle!, command!, or host! in a witness body
        func example() -> CGRect { .zero }
        """
        let strippedComment = SwiftSourceScan.stripCommentsAndStringLiterals(commentOnly)
        XCTAssertFalse(
            patterns.contains { strippedComment.contains($0) },
            "a comment-only mention of the banned patterns must be stripped before the scan runs, or " +
            "this rule would forbid even documenting the trap it guards against")
    }

    /// Extracts just the braced BODY of each class/extension declaration in `text` whose name is in
    /// `names` — used to narrow R11's scan to the actual in-scope declaration(s) within a file that
    /// may also contain an unrelated class (e.g. `FakeClientSelfTests.swift`, which shares a file with
    /// the UNRELATED `FakeClientSelfTests: XCTestCase`). Reuses the same declaration regex as
    /// `scanClassAndExtensionDeclarations` for a CLAUSED declaration (`class/extension Name: … {`), and
    /// (FIX ROUND 3, review item 2) also matches a CLAUSE-LESS `extension Name { … }` — the repo's own
    /// idiom for adding members to an already-declared type (mirrors how `DocumentCanvasView`'s host
    /// conformance is declared via a SEPARATE, clause-bearing extension elsewhere; a bare extension
    /// with no clause at all is invisible to the clause pattern, which requires a `:` before the `{`).
    /// Both patterns brace-match from EACH MATCH'S OWN opening `{` (not the first `{` anywhere in the
    /// file), so a preceding unrelated declaration's body can't be mistaken for this one's. The two
    /// patterns are mutually exclusive by construction (the clause pattern requires a `:` before `{`;
    /// the bare pattern requires NONE), so a match can never be double-counted.
    private func extractingDeclarationBodies(named names: Set<String>, from text: String) -> String {
        let clausedPattern = try! NSRegularExpression(
            pattern: #"(?:final\s+)?(?:class|extension)\s+(\w+)\s*:\s*([^{]+)\{"#)
        let bareExtensionPattern = try! NSRegularExpression(pattern: #"extension\s+(\w+)\s*\{"#)
        let ns = text as NSString

        func bodyRange(afterMatchEndingAt matchEnd: Int) -> ClosedRange<String.Index>? {
            let openBraceLocation = matchEnd - 1
            guard let bodyStart = Range(NSRange(location: openBraceLocation, length: 1), in: text) else { return nil }
            var depth = 0
            var idx = bodyStart.lowerBound
            var closeIndex: String.Index?
            while idx < text.endIndex {
                let ch = text[idx]
                if ch == "{" { depth += 1 } else if ch == "}" {
                    depth -= 1
                    if depth == 0 { closeIndex = idx; break }
                }
                idx = text.index(after: idx)
            }
            guard let close = closeIndex else { return nil }   // unbalanced braces — skip rather than loop forever
            return bodyStart.lowerBound...close
        }

        var extracted = ""
        for match in clausedPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let name = ns.substring(with: match.range(at: 1))
            guard names.contains(name), let range = bodyRange(afterMatchEndingAt: match.range.location + match.range.length) else { continue }
            extracted += text[range]
            extracted += "\n"
        }
        for match in bareExtensionPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let name = ns.substring(with: match.range(at: 1))
            guard names.contains(name), let range = bodyRange(afterMatchEndingAt: match.range.location + match.range.length) else { continue }
            extracted += text[range]
            extracted += "\n"
        }
        return extracted
    }

    /// Discovers every concrete `class Foo: … Protocol … { … }` OR `extension Foo: … Protocol … { … }`
    /// conformer of any of `protocolNames`, under `dir` (comment-stripped first, so a mention inside a
    /// doc comment can't pollute the set). Deliberately requires the `class`/`extension` keyword
    /// (excludes a `protocol Foo: …` declaration itself) and searches the WHOLE inheritance/conformance
    /// clause up to the opening brace (not just an immediately-following name), so a conformer listing
    /// other protocols first — or conforming via a separate `extension` — is still found.
    private func discoverConcreteConformers(ofAnyOf protocolNames: [String], under dir: URL) -> Set<String> {
        let joined = RepoLayout.swiftFiles(under: dir).map {
            SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: $0)) ?? "")
        }.joined(separator: "\n")
        let pattern = try! NSRegularExpression(
            pattern: #"(?:final\s+)?(?:class|extension)\s+(\w+)\s*:\s*([^{]+)\{"#)
        let full = joined as NSString
        var names: Set<String> = []
        for match in pattern.matches(in: joined, range: NSRange(location: 0, length: full.length)) {
            let inheritance = full.substring(with: match.range(at: 2))
            if protocolNames.contains(where: { inheritance.contains($0) }) {
                names.insert(full.substring(with: match.range(at: 1)))
            }
        }
        return names
    }

    /// Every `class Foo: <comma-list> {` / `extension Foo: <comma-list> {` declaration found anywhere
    /// under `dir` (recursively — Fixed Minor 1: was a non-recursive `contentsOfDirectory`), with the
    /// comma-separated inheritance/conformance list split into individual raw identifiers. Used to
    /// build a name → declared-parents graph for the transitive ancestry walk below; deliberately does
    /// NOT try to distinguish "the superclass" from "a protocol also listed" — over-including a
    /// protocol name as a graph edge is harmless (it's a dead end with no outgoing edges of its own
    /// that could coincidentally lead to `BackendContractCases`), while under-including would silently
    /// narrow the scan back to the non-transitive shape this fix exists to widen.
    private func scanClassAndExtensionDeclarations(
        under dir: URL
    ) -> [(name: String, parents: [String], file: URL)] {
        var results: [(name: String, parents: [String], file: URL)] = []
        let pattern = try! NSRegularExpression(
            pattern: #"(?:final\s+)?(?:class|extension)\s+(\w+)\s*:\s*([^{]+)\{"#)
        for url in RepoLayout.swiftFiles(under: dir) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            let ns = text as NSString
            for match in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let name = ns.substring(with: match.range(at: 1))
                let parentsRaw = ns.substring(with: match.range(at: 2))
                let parents = parentsRaw.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
                results.append((name, parents, url))
            }
        }
        return results
    }

    /// Depth-first reachability over the `edges` graph (`scanClassAndExtensionDeclarations`'s output,
    /// keyed by name): does `name`'s declared ancestry chain reach `ancestor`, at any depth? `visited`
    /// guards against a cycle (none expected in a real Swift type graph, but a text-based scan cannot
    /// prove that, so this must not infinite-loop on a pathological input).
    private func typeAncestryReaches(
        _ name: String, _ ancestor: String, edges: [String: [String]], visited: inout Set<String>
    ) -> Bool {
        if name == ancestor { return true }
        guard !visited.contains(name) else { return false }
        visited.insert(name)
        for parent in edges[name] ?? [] {
            if typeAncestryReaches(parent, ancestor, edges: edges, visited: &visited) { return true }
        }
        return false
    }

    /// Brace-matches and removes EVERY override whose signature begins with `signaturePrefix` (there
    /// is normally exactly one per file, but `FakeClientSelfTests.swift` shows a second
    /// `BackendContractCases` subclass can share a file, so this loops rather than handling only the
    /// first) — leaving the surrounding text intact for the caller to scan for a stray mention.
    /// GENERALIZED (fix round 2, R11) from the R10-only `maskingEveryMakeBackendOverride`: R10 passes
    /// `"func makeBackend()"` (no parameters, so the literal signature is exact); R11 passes
    /// `"func makeHost("` (the factory takes a parameter, so only the prefix up to the open paren is
    /// literal — the brace search below still finds the SAME next `"{"`, since neither factory's
    /// return-type annotation contains a brace of its own).
    private func maskingEveryOverride(ofSignaturePrefix signaturePrefix: String, in text: String) -> String {
        var result = text
        while let declRange = result.range(of: signaturePrefix),
              let openBrace = result.range(of: "{", range: declRange.upperBound..<result.endIndex) {
            var depth = 0
            var idx = openBrace.lowerBound
            var closeIndex: String.Index?
            while idx < result.endIndex {
                let ch = result[idx]
                if ch == "{" { depth += 1 } else if ch == "}" {
                    depth -= 1
                    if depth == 0 { closeIndex = idx; break }
                }
                idx = result.index(after: idx)
            }
            guard let close = closeIndex else { break }   // unbalanced braces — bail rather than loop forever
            // Removes from the START OF THE SIGNATURE (`declRange.lowerBound`), not just the body
            // braces (`openBrace.lowerBound`) — leaving the signature text (`func makeBackend()`)
            // behind would make the NEXT loop iteration re-match the very same declaration, then
            // search for the next "{" in the file (since this body's own brace is already gone) and
            // brace-match an unrelated, much LATER function's body into the "removal" — silently
            // eating one or more genuine test methods along with it. Caught empirically: verified by
            // deliberately restoring the old (`openBrace.lowerBound`-only) version against a
            // 2-`makeBackend`-mention fixture and observing it swallow subsequent methods whole.
            result.replaceSubrange(declRange.lowerBound...close, with: "")
        }
        return result
    }

    // MARK: - R16 (Task 26) — the backend is the only sender of UITextInputDelegate notifications

    /// R16 — a FIXED, zero-forever rule (like R9/R10/R11/R12/R14/R15), not a decreasing-baseline
    /// ratchet. Before Task 26 there were 48 sends of the four `UITextInputDelegate` methods across
    /// nine files: 44 on `DocumentCanvasView` (each spelling its own
    /// `textInputDelegate?.selectionWillChange(self)` pair inline) and four on the backend. Task 26
    /// moved all 44 onto the backend's five brackets, so there is now exactly ONE sender, in ONE file.
    ///
    /// That single-sender property is the whole point of the family: `suppressesSelectionNotifications`
    /// has two consumers (a conformer's publish-deferral and the bracket suppression), and the three
    /// deliberate asymmetries (the unconditional four-notification `editing` bracket, the
    /// coalescing-suppressed funnels vs the UNsuppressed `moveFloatingCaret`, and the marked-commit's
    /// text-only bracket) are only reviewable while every emission goes through one file. A single new
    /// inline `inputDelegate?.selectionDidChange(…)` anywhere would silently reintroduce a second
    /// emitter with no test failing — which is exactly the pre-Task-26 state this rule closes.
    ///
    /// Scoped to `Sources/` only. `Tests/` legitimately RECEIVES these (it implements
    /// `UITextInputDelegate` in `RichTextInputEventRecorder`/`InputDelegateSpy`), and this scan cannot
    /// tell an implementation from a send — which is also why the patterns below deliberately do NOT
    /// try to match a receiver expression: any occurrence under `Sources/` outside the one allowed file
    /// is a violation regardless of shape.
    ///
    /// CASE SENSITIVITY IS LOAD-BEARING: the four patterns are lower-cased first letters
    /// (`textWillChange(`), so the backend's OWN emitter NAMES (`notifyTextWillChange()`,
    /// `notifySelectionWillChange()`, …) do not match them — those spell `TextWillChange(` /
    /// `SelectionWillChange(` with a capital. That is what lets the rule scan the allowed file's
    /// SIBLINGS without also having to allow every `notify…` call site in the canvas.
    ///
    /// Positive self-check: `test_theDelegateSendDetectionActuallyDetects_R16` below.
    func test_onlyTheBackendSendsInputDelegateNotifications() {
        RepoLayout.assertResolved()
        let allowedFile = "LegacyRichTextInputBackend+Notifications.swift"
        var offenders: [String] = []
        var sawTheAllowedFileSend = false
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try! String(contentsOf: url))
            let hits = Self.delegateSendPatterns.filter { text.contains($0) }
            if url.lastPathComponent == allowedFile {
                sawTheAllowedFileSend = !hits.isEmpty
                continue
            }
            if !hits.isEmpty {
                offenders.append("\(url.lastPathComponent): \(hits.sorted())")
            }
        }
        XCTAssertTrue(sawTheAllowedFileSend,
                      "\(allowedFile) contains none of \(Self.delegateSendPatterns) — either it was " +
                      "renamed or the emitters moved, and this rule would pass VACUOUSLY")
        XCTAssertEqual(offenders, [],
                       "a UITextInputDelegate notification is sent outside \(allowedFile): \(offenders)")
    }

    /// The four sends, lower-cased first letter (see R16's own note on why that matters).
    private static let delegateSendPatterns = [
        "textWillChange(", "textDidChange(", "selectionWillChange(", "selectionDidChange(",
    ]

    /// The positive half of R16: proves the SAME detection expression the rule uses catches a real
    /// inline send, ignores a comment-only mention (stripped first, exactly like every other rule
    /// here), and — the case-sensitivity claim R16 depends on — does NOT fire on the backend's own
    /// `notify…` emitter names. Fixtures spell `example()`, never `func test_…` (R14's fix-round
    /// lesson: a synthetic fixture with an XCTest-shaped name inflates grep-based test counts).
    func test_theDelegateSendDetectionActuallyDetects_R16() {
        func hits(_ source: String) -> [String] {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals(source)
            return Self.delegateSendPatterns.filter { stripped.contains($0) }
        }
        for pattern in Self.delegateSendPatterns {
            let member = String(pattern.dropLast())   // strip the "("
            let violating = """
            func example() {
                inputDelegate?.\(member)(self)
            }
            """
            XCTAssertEqual(hits(violating), [pattern],
                           "R16's scan missed a real inline send of \(member)")
        }
        let commentOnly = """
        // This prose names selectionWillChange( and textDidChange( in a comment.
        func example() { }
        """
        XCTAssertEqual(hits(commentOnly), [],
                       "R16's scan must ignore a comment-only mention, like every other rule here")
        let emitterNames = """
        func example() {
            notifyTextWillChange()
            notifySelectionWillChange()
            notifySelectionDidChange()
            notifyTextDidChange()
        }
        """
        XCTAssertEqual(hits(emitterNames), [],
                       "R16 must not fire on the backend's own notify… emitter NAMES — the whole rule " +
                       "depends on that case distinction")
    }

    // MARK: - R17 (Task 29; its shape half rebuilt by Task 31) — a routed backend member
    // adds no bracket of its own, and has exactly the shape its entry declares

    /// The members `LegacyRichTextInputBackend` reaches the canvas through, and the SHAPE each is
    /// allowed to have.
    ///
    /// **TASK 31 REPLACED `isCanvasForward: Bool` WITH `shape`, a six-case enum** (coordinator ruling
    /// at Task 30's review, Maj-1; the reason is recorded in the previous version of this comment and
    /// is repeated here because it is the whole justification for the mechanism). The Bool had become
    /// an opt-out that meant three different things, and for one of its three users the shape half of
    /// this rule was **provably inert**: `statementLines` reports only DEPTH-0 lines, so a `switch` of
    /// any size collapses to its one `switch command {` line and "a guard prelude plus exactly one
    /// statement" passed unconditionally, with the `legacyCanvas?.legacy` check never running.
    /// `performCommand(_:sender:)` carried `isCanvasForward: false` purely because `true` would have
    /// failed for correct code. Task 31 then had to add twelve members, two of which are
    /// multi-statement by construction, so the flag would have drifted a fourth time.
    ///
    /// **The six shapes, and what each one actually checks.**
    ///
    ///   * `.canvasForward` — a `guard` prelude plus EXACTLY ONE further statement, and that statement
    ///     must contain `legacyCanvas?.legacy…`. The Families 4-6 shape.
    ///   * `.client` — the same one-statement shape, but the statement answers from a CLIENT instead —
    ///     **and, since Task 31's fix round 1, the WHOLE BODY (guard prelude included) must not name
    ///     `legacyCanvas` at all.** That second half is the enforcement, not a description of intent:
    ///     without it the case counted statements and asserted nothing about what the one statement
    ///     reached, so re-pointing `undoManager` at `legacyCanvas?.effectiveUndoManager` — the exact
    ///     D24 clause-(b) drift Task 30 was commended for avoiding — left this rule GREEN. It is stated
    ///     HERE, under this heading, because this bullet is the file's designated answer to "what does
    ///     `.client` check"; a reader who finds the constraint only at the assertion 270 lines below
    ///     meets it as a build failure first. Four members are legitimately this: `hasText` (see its own
    ///     doc comment, `+Insertion.swift`, for why the deviation was accepted),
    ///     `canPerformCommand(_:sender:)` (it must NOT reach `legacyCanvas`, because that would mean
    ///     calling the very witness that routes into it), `undoManager` (reaching it through
    ///     `legacyCanvas` would have needed an ADDITIONAL D24 clause-(b) exception that could never
    ///     expire — D14 keeps undo ownership off the backend permanently; **the ordinal that used to
    ///     stand here was the copy Task 33's own de-ordinalisation missed**, because that sweep grepped
    ///     the directory it was editing rather than the whole package), and Task 31's `editPolicyDidChange()`,
    ///     whose one statement is `host.presentationClient.dismissEditMenu(reason:)`. None of the four
    ///     needs a canvas reach and none plausibly will: `isAttached` is a stored `Bool` on the class,
    ///     not a canvas probe, and every client already holds the canvas itself (`unowned let canvas`,
    ///     injected at init), so no client API takes a canvas a `.client` body would have to pass.
    ///   * `.switchArms(forwarding:nonForwarding:)` — a `switch`-bodied member whose arms are checked
    ///     INDIVIDUALLY: every arm named in `forwarding` must contain `legacyCanvas?.legacy…`, every arm
    ///     named in `nonForwarding` must not, **and the set of arms found in the source must equal the
    ///     union of the two named sets**, so a new `case` cannot be added silently. This is the case
    ///     that exists for `performCommand(_:sender:)`, and it matters rather than merely tidies:
    ///     `.copy` and `.cut` have **no other cover at all** against being re-pointed at the command
    ///     client, because for those two the client route is behaviour-equivalent, so no behavioural
    ///     test can distinguish them. (The other three forwarding arms do have red-checks:
    ///     `CommandRouterTests`' `…stillDelegatesToTheHostsMediaHook` (`.paste`),
    ///     `…stillPresentsTheEditMenu…` (`.selectWord`) and
    ///     `…andStillRunsWhenEverythingIsAlreadySelected` (`.selectAll`).)
    ///   * `.statements(allowed:)` — a multi-statement routed member. **Every statement line at ANY
    ///     brace depth**, minus pure control-flow scaffolding, must begin with one of the listed
    ///     prefixes. This is the case that does NOT degrade to vacuity the way `isCanvasForward: false`
    ///     did: `everyStatementLine` deliberately does not collapse nesting, so a statement smuggled
    ///     inside an `if` block is seen. Task 31's `hostDidBecomeFirstResponder()` is exactly that
    ///     shape (the transition-gated segment sits inside an `if`), which is why the mechanism had to
    ///     land before the members did. **Its BOUNDARY, disclosed on this file's own standard rather
    ///     than left for a reader to discover (FIX ROUND 1, review Min-4): it checks the SET of
    ///     statements, never their ORDER and never the `if` CONDITIONS around them.** Hoisting
    ///     `legacyMarkDidJustBecomeFirstResponder()` and `legacyFinishBecomingFirstResponder()` out of
    ///     the transition gate — the exact defect Task 31 exists to prevent — leaves this rule GREEN
    ///     (measured). That is correct for a SHAPE rule; `ResponderRouterTests` owns order and
    ///     conditions, and both of its pins go red under that mutation.
    ///   * `.literal(_:)` — the body is exactly the given text and nothing else. Task 31's three Bool
    ///     getters (`canBecomeFirstResponder`, `canResignFirstResponder`, `isEditableForWritingTools`)
    ///     answer a bare `true`, because that is what the witnesses they replaced answered — there is
    ///     no forward and no client to name, and `.statements` would not do, since it matches PREFIXES
    ///     and would admit `true && somethingNew`. If a policy gate is ever added to one of them, this
    ///     rule goes red and the author must reclassify deliberately.
    ///   * `.deliberatelyEmpty` — the body contains nothing but `guard` lines. Exactly one member is
    ///     this: `textInputTraitsDidChange()`, which under zero-behaviour-change is a notification the
    ///     backend does not yet act on (the canvas's `isSpellCheckingEnabled` `didSet` still does all
    ///     the work). Listing it here rather than omitting it from `routedBackendMembers` is the point:
    ///     an empty body that nothing names reads as an unfinished forward, and this project has twice
    ///     paid for "reads-as-enforcement, enforces-nothing".
    ///
    /// **The `guard` prelude is permitted rather than banned** because several members legitimately
    /// have one and each is a decision the pre-seam witness owned or an earlier task's gate: `replace`'s
    /// `as? DocumentTextRange` cast-drop, `hasText`'s nil-document fallback, `canPerformCommand`'s
    /// Task-22i `allowsPaste` edit-policy gate (an `if` block rewritten as a guard for exactly this
    /// reason), and Task 31's detached guards. **Coarseness disclosed, not hidden:** a `guard` line is
    /// skipped WHOLE, so `guard x else { doWork(); return }` would hide `doWork()` from every shape
    /// above. That is the same latitude the rule has had since Task 29 and is left alone on R13's
    /// lesson (stay coarse rather than fragile-precise); no member in this tree has such a guard.
    ///
    /// **ONE EXCEPTION to "permitted", and it is the case the Major was about: a `.client` prelude may
    /// not reach `legacyCanvas`.** `guard let canvas = legacyCanvas else { … }` is a legitimate-looking
    /// prelude that the general permission would admit and `.client` rejects, because that member's
    /// whole contract is "answers from a client". Named here rather than only at the assertion, so an
    /// author writing against this paragraph is not surprised by a failure it does not explain.
    ///
    /// A FIXED rule, not a decreasing-baseline ratchet like R6/R7 — the same style as R9-R16: each
    /// family task ADDS its routed members to `routedBackendMembers` as it lands, and Phase 4 never
    /// un-routes one.
    ///
    /// **Scope limit, stated rather than left implicit:** this covers the members that FORWARD. The
    /// `{ get set }` accessor pairs (`markedTextStyle`, `selectedTextRange`, `inputDelegate`) are not
    /// expressible as "one statement" any more than they are in `RouterWitnessBodyTests`, and
    /// `selectedTextRange`'s real body legitimately opens a transaction through `setSelection`. Their
    /// cover is the router-spy tests, exactly as that file's own SCOPE LIMIT note describes.
    private struct RoutedBackendMember {
        let name: String
        let signature: String
        let shape: ForwardShape
    }

    /// See `RoutedBackendMember`'s doc comment for what each case checks and why it exists.
    private enum ForwardShape {
        case canvasForward
        case client
        case switchArms(forwarding: [String], nonForwarding: [String])
        case statements(allowed: [String])
        case literal(String)
        case deliberatelyEmpty
    }

    private static let routedBackendMembers: [RoutedBackendMember] = [
        // Task 27a
        .init(name: "replace(_:withText:)",
              signature: "func replace(_ range: UITextRange, withText text: String)",
              shape: .canvasForward),
        .init(name: "hasText", signature: "var hasText: Bool", shape: .client),
        // Task 27b
        .init(name: "insertText(_:)", signature: "func insertText(_ text: String)", shape: .canvasForward),
        // Task 28
        .init(name: "deleteBackward()", signature: "func deleteBackward()", shape: .canvasForward),
        // Task 29
        .init(name: "setMarkedText(_:selectedRange:)",
              signature: "func setMarkedText(_ text: String?, selectedRange: NSRange)",
              shape: .canvasForward),
        .init(name: "unmarkText()", signature: "func unmarkText()", shape: .canvasForward),
        // Task 30 — see the per-shape notes above for why each is classified as it is.
        .init(name: "canPerformCommand(_:sender:)",
              signature: "func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool",
              shape: .client),
        .init(name: "performCommand(_:sender:)",
              signature: "func performCommand(_ command: RichTextInputCommand, sender: Any?)",
              shape: .switchArms(forwarding: [".copy", ".cut", ".paste", ".selectWord", ".selectAll"],
                                 nonForwarding: [".undo, .redo, .delete"])),
        .init(name: "undoManager", signature: "var undoManager: UndoManager?", shape: .client),
        // Task 31 — Family 8 (responder lifecycle, edit policy, traits notification). TWELVE members
        // across FIVE of the six shapes: `.literal` × 3, `.statements` × 6, `.canvasForward` × 1,
        // `.client` × 1, `.deliberatelyEmpty` × 1. Only `.switchArms` is untouched by this family.
        // (FIX ROUND 1, review Min-8: the routing commit's message says "four of its six shapes",
        // which is wrong and cannot be rewritten in place — the count is stated here, next to the
        // entries a reader can recount, rather than left only in an unfixable message.)
        //
        // The three Bool getters are `.literal("true")` rather than a forward or a client answer
        // because today's witnesses ARE literals: `override var canBecomeFirstResponder: Bool { true }`
        // on the canvas, no `canResignFirstResponder` override at all (so `UIResponder`'s own `true`),
        // and `var isEditable: Bool { true }`. A `guard isAttached else { return }` prelude would
        // silently answer `false` for a Bool getter, which is why these three deliberately have none.
        .init(name: "canBecomeFirstResponder",
              signature: "var canBecomeFirstResponder: Bool", shape: .literal("true")),
        .init(name: "canResignFirstResponder",
              signature: "var canResignFirstResponder: Bool", shape: .literal("true")),
        .init(name: "isEditableForWritingTools",
              signature: "var isEditableForWritingTools: Bool", shape: .literal("true")),
        // The become/resign pre/post hooks. The allowed prefixes are written as the WHOLE statement
        // wherever the statement is fixed text, so the rule is as tight as it can be without becoming a
        // second copy of the body.
        .init(name: "hostWillBecomeFirstResponder()",
              signature: "func hostWillBecomeFirstResponder()",
              shape: .statements(allowed: ["wasFirstResponderAtWill = host.hostInputView.isFirstResponder"])),
        .init(name: "hostDidBecomeFirstResponder()",
              signature: "func hostDidBecomeFirstResponder()",
              shape: .statements(allowed: ["canvas.legacy",
                                           "host.lifecycleClient.backendDidBeginEditing()"])),
        .init(name: "hostDidFailToBecomeFirstResponder()",
              signature: "func hostDidFailToBecomeFirstResponder()",
              shape: .statements(allowed: ["wasFirstResponderAtWill = false"])),
        // TASK 33 added the third statement: this member reaches `cancelFloatingCursor()` through its
        // canvas hook, which clears the CANVAS's `floatingCursorActive` only, so it mirrors the clear
        // onto the backend's — the flag the `selectedTextRange` setter now reads. Without it an
        // interrupted gesture latches that guard forever.
        .init(name: "hostWillResignFirstResponder()",
              signature: "func hostWillResignFirstResponder()",
              shape: .statements(allowed: ["canvas.legacyWillResignFirstResponder()",
                                           "floatingCursorActive = false",
                                           "wasFirstResponderAtWillResign = host.hostInputView.isFirstResponder"])),
        .init(name: "hostDidResignFirstResponder()",
              signature: "func hostDidResignFirstResponder()",
              shape: .statements(allowed: ["canvas.legacyDidResignFirstResponder()",
                                           "host.lifecycleClient.backendDidEndEditing()"])),
        .init(name: "hostDidFailToResignFirstResponder()",
              signature: "func hostDidFailToResignFirstResponder()",
              shape: .statements(allowed: ["wasFirstResponderAtWillResign = false"])),
        // TASK 33 RECLASSIFIED THIS FROM `.canvasForward`, which requires exactly one statement. The
        // second one mirrors the canvas hook's `cancelFloatingCursor()` onto the backend's flag — and it
        // is pinned WITH ITS BRANCH, as the whole line, because the branch is the load-bearing part: an
        // unconditional clear would drop the floating-cursor suppression on a re-parent that keeps the
        // canvas in a window, mid-gesture. `isControlFlowScaffolding` skips only an `if` line that ENDS
        // in `{`, so this single-line `if` is a statement the shape must admit by exact text rather than
        // a brace it waves through.
        .init(name: "hostWillMove(toWindow:)",
              signature: "func hostWillMove(toWindow window: UIWindow?)",
              shape: .statements(allowed: ["legacyCanvas?.legacyWillMove(toWindow: window)",
                                           "if window == nil { floatingCursorActive = false }"])),
        .init(name: "editPolicyDidChange()",
              signature: "func editPolicyDidChange()", shape: .client),
        .init(name: "textInputTraitsDidChange()",
              signature: "func textInputTraitsDidChange()", shape: .deliberatelyEmpty),
        // Task 32 — Family 9 (touch interaction and selection). FIVE members across TWO shapes:
        // `.canvasForward` × 2, `.statements` × 3. **Three of the five do not fit the shape a reader
        // would guess, and each mismatch is a fact about the code rather than a classification dodge.**
        //
        //   * `installInteractions()` LOOKS like `.canvasForward` — one statement, a `legacyCanvas`
        //     forward — but that case requires the literal `legacyCanvas?.legacy`, and the callee is
        //     `installSelectionInteractions()`, which is D24 clause (a) WITHOUT the prefix (already
        //     narrowly named, so it needs no rename and gets none — the Task-29 amendment, applied again
        //     by Tasks 30 and 34). `.statements` with the whole call as the allowed prefix is a TIGHTER
        //     pin than `.canvasForward` would have been, not a looser one: it pins the exact callee,
        //     where `.canvasForward` pins only the prefix.
        //   * `layoutDidChange(generation:)` assigns and forwards nowhere, so `.deliberatelyEmpty` (whose
        //     rule is "nothing but `guard` lines") is wrong for it, and `.canvasForward`/`.client` are
        //     wrong for a member that reaches neither. `.statements` with the exact assignment text is
        //     the honest case; **no seventh case is needed**, and this is the second family in a row to
        //     check that claim rather than assert it (Task 31's `+MarkedText.swift` note wrongly said a
        //     seventh was needed once).
        //   * `cancelActiveInteraction(reason:)` is two statements, so `.canvasForward`'s
        //     exactly-one-statement rule rejects it for correct code.
        //
        // Both `.statements` entries whose statements are FIXED TEXT spell the whole statement, per the
        // convention Task 31 set, so the rule is as tight as it can be without becoming a second copy of
        // the body.
        //
        // **The BOUNDARY of that tightness, MEASURED rather than assumed** (this file's own standard:
        // an enforcement claim is a testable claim). `.statements` matches by `hasPrefix`, so for
        // `layoutDidChange(generation:)`:
        //   * `legacyCanvas?.layoutContent()` in place of the assignment — the exact mutation that
        //     member's whole correctness argument forbids — is **RED** (measured).
        //   * `lastObservedLayoutGeneration = generation &+ 1`, a SUFFIX extension of the pinned text,
        //     is **GREEN** (measured). A prefix pin cannot see it, and no shape in this enum can
        //     without becoming an exact-body copy.
        // The suffix case is covered behaviourally instead:
        // `InteractionRouterTests.test_layoutDidChangeIsNotificationOnlyAndDoesNotRelayout` asserts the
        // stored value equals the announced one, so `&+ 1` reddens there. Recorded here so the next
        // reader does not have to re-derive which half of the pair covers what.
        //
        // **FIX ROUND 1 (review Minor 3) — the SIBLING boundary of the same shape, written beside it
        // because half a boundary is the more misleading half.** `.statements` filters the statements
        // that are PRESENT against the allowed prefixes; it never requires an allowed statement to be
        // present, and it never looks at order. So for `cancelActiveInteraction(reason:)`:
        //   * deleting ONE of its two forwards leaves this rule **GREEN** — one surviving statement,
        //     still an allowed prefix;
        //   * swapping the two leaves it **GREEN** too.
        // Both are covered behaviourally, deliberately and not by luck:
        // `InteractionRouterTests.test_cancelActiveInteraction_tearsDownTheFloatingCursorAndTheDragAutoScroll`
        // carries a PRECONDITION for each half (an active floating cursor, a live drag-auto-scroll link),
        // so deleting either forward reddens it, and `BackendAttachmentTests.test_detachRunsTheNineStepsInOrder`
        // re-checks the floating half through detach. Order is genuinely unpinned anywhere — which is
        // correct, and that member's own doc comment argues why the two orders are equivalent.
        // **The generalisation, since it now has two instances: `.statements` is a rule about what a
        // body MAY contain, never about what it MUST contain or in what sequence. A member whose
        // correctness depends on presence or order needs a behavioural pin, and this file should say so
        // where that member is listed.**
        //
        // Two more measurements behind the classifications above, so they read as facts rather than
        // preferences: declaring `installInteractions()` as `.canvasForward` is **RED** ("the one
        // statement is not a `legacyCanvas?.legacy…` forward"), and adding a `publishState(reason:)`
        // to `cancelActiveInteraction(reason:)` is **RED** on the bracket half.
        .init(name: "installInteractions()",
              signature: "func installInteractions()",
              shape: .statements(allowed: ["legacyCanvas?.installSelectionInteractions()"])),
        .init(name: "removeInteractions()",
              signature: "func removeInteractions()", shape: .canvasForward),
        .init(name: "viewportDidChange()",
              signature: "func viewportDidChange()", shape: .canvasForward),
        .init(name: "layoutDidChange(generation:)",
              signature: "func layoutDidChange(generation: UInt64)",
              shape: .statements(allowed: ["lastObservedLayoutGeneration = generation"])),
        .init(name: "cancelActiveInteraction(reason:)",
              signature: "func cancelActiveInteraction(reason: RichTextInteractionCancellationReason)",
              shape: .statements(allowed: ["legacyCanvas?.stopDragAutoScroll()",
                                           "legacyCanvas?.cancelFloatingCursor()",
                                           "floatingCursorActive = false"])),
        // Task 33 — Family 10 (floating cursor and autoscroll). THREE members across TWO shapes:
        // `.statements` × 2, `.canvasForward` × 1. The split is not a stylistic one — `begin` and `end`
        // each forward AND write the backend's `floatingCursorActive`, which is two statements, and
        // `.canvasForward`'s exactly-one-statement rule rejects two for CORRECT code. `update` writes no
        // flag and so is the plain forward.
        //
        // **What these three shapes do NOT pin, stated because half a boundary is the misleading half:
        // the statement ORDER.** `+FloatingCursor.swift`'s header makes forward-before-flag a hard
        // requirement (from Task 42 the canvas bodies' own guards read the backend's flag, so a
        // flag-first body becomes a silent permanent no-op) — and `.statements` checks the SET, never
        // the sequence, exactly as this file records for `cancelActiveInteraction(reason:)` above. Nor
        // is there a behavioural pin: today the canvas guards read the CANVAS's store, so reversing the
        // order changes nothing observable. That constraint is currently unfalsifiable, and saying so is
        // the only honest treatment of it.
        //
        // The third statement Task 33 added to `hostWillResignFirstResponder()`, `hostWillMove(toWindow:)`
        // and `cancelActiveInteraction(reason:)` above belongs to this family too: those are the backend
        // members that reach `DocumentCanvasView.cancelFloatingCursor()`, which clears the canvas's flag
        // only.
        .init(name: "beginFloatingCursor(at:)",
              signature: "func beginFloatingCursor(at point: CGPoint)",
              shape: .statements(allowed: ["legacyCanvas?.legacyBeginFloatingCursor(at: point)",
                                           "floatingCursorActive = true"])),
        .init(name: "updateFloatingCursor(at:)",
              signature: "func updateFloatingCursor(at point: CGPoint)", shape: .canvasForward),
        .init(name: "endFloatingCursor()",
              signature: "func endFloatingCursor()",
              shape: .statements(allowed: ["legacyCanvas?.legacyEndFloatingCursor()",
                                           "floatingCursorActive = false"])),
        // Task 34 — Family 11 (spellchecking and annotations), the LAST Phase-4 family. TWO members,
        // both `.statements`, and NEITHER is `.canvasForward` for the reason Task 32 recorded at
        // `installInteractions()`: that case requires the literal `legacyCanvas?.legacy`, and both
        // callees here are ALREADY narrowly named, so under the Task-29 D24 amendment they need no
        // rename and get none. `.statements` with the whole call as the allowed text is the TIGHTER
        // pin — it names the exact callee where `.canvasForward` names only the prefix.
        //
        // **These two are the first entries in this list whose canvas call sites are not UIKit
        // witnesses** (they are the `isSpellCheckingEnabled` `didSet`, `legacyFinishBecomingFirstResponder()`,
        // `refreshSelectionUI()` and `endCoalescedSelectionDrag()`), which is why deviation D37 had to
        // add `RichTextInputCheckingBackend` to the contract before they could exist at all — see
        // `RichTextInputBackend.swift`. It is also why `RouterWitnessBodyTests.enabledWitnesses` gains
        // NOTHING from this family: that rule requires a witness whose body is exactly one
        // `inputBackend.…` statement, and none of the four call sites is a one-line router.
        //
        // The brief's third member, `driveCheck(style:_:)`, is deliberately absent — it was not
        // written, so there is nothing to list. `+Checking.swift`'s header has the reasoning.
        .init(name: "installCheckingIfNeeded()",
              signature: "func installCheckingIfNeeded()",
              shape: .statements(allowed: ["legacyCanvas?.installNativeCheckingIfNeeded()"])),
        .init(name: "checkOnSelectionChange()",
              signature: "func checkOnSelectionChange()",
              shape: .statements(allowed: ["legacyCanvas?.nativeCheckOnSelectionChange()"])),
    ]

    /// Every name a backend member would have to write to open a delegate bracket, a publication, or a
    /// transaction of its own. Substring matching, so `notifyingSelectionChange` also covers
    /// `notifyingSelectionChangeIgnoringCoalescing`; both are listed anyway so a reader sees the whole
    /// vocabulary the rule claims to cover, and so the "each token is real" self-check below exercises
    /// each spelling independently.
    private static let backendBracketTokens = [
        "notifyingContentAndSelectionChange", "notifyingSelectionChangeIgnoringCoalescing",
        "notifyingSelectionChange", "notifyingContentChange", "notifyCoalescedSelectionResync",
        "publishState", "withTransaction", "endTransaction", "activeTransactionDepth",
        "transactionPhase", "prepareAndRun", "runMutation", "inputDelegate",
    ]

    /// R17 (added Task 29, commissioned by its coordinator supplement §6; its shape half rebuilt by
    /// Task 31) — the BACKEND-member forward rule, the mirror image of `RouterWitnessBodyTests`.
    ///
    /// **Why it exists, and why it is not redundant with that file.** `RouterWitnessBodyTests` constrains
    /// the CANVAS WITNESS body (exactly one `inputBackend.…` statement). Nothing constrained the BACKEND
    /// member body — which is exactly where a notification bracket would be re-added, and re-adding one
    /// is the defect deviation D35 measured: the task briefs for Families 4-6 all originally asked for
    /// `notifyingContentAndSelectionChange { legacyCanvas?.legacyX() }` plus a trailing `publishState`,
    /// and every one of those canvas bodies already brackets itself, PER BRANCH.
    ///
    /// **The motivation that survives measurement is COVERAGE UNEVENNESS, not "traces never catch it".**
    /// An earlier draft of this paragraph led with Family 5's finding — one guard
    /// (`DeletionRouterTests`' bracket test), with `EditingInputDelegateBracketTests` (monotone `> 0`)
    /// and every trace suite staying GREEN under a doubled bracket. **Task 29 measured its own family
    /// and got the opposite result**: under the identical mutation
    /// `MarkedTextTraceCharacterizationTests` goes red with **14** failures and
    /// `DelegateTraceCharacterizationTests` with **1**, because both pin marked-text traces by exact
    /// equality (see `MarkedTextRouterTests
    /// .test_setMarkedText_emitsExactlyTheWitnessesOwnTwoBrackets_theBackendAddsNoneOfItsOwn`, which
    /// records the run). So a reader must NOT come away believing traces never catch a doubled bracket.
    /// What is true across both families is that whether they catch it depends entirely on whether some
    /// suite happens to pin that member's trace by exact equality — Family 5's did not, Family 6's does
    /// — and that this rule does not depend on it at all: it fires on the SOURCE TEXT, on macOS, for
    /// every listed member including ones whose canvas body no test drives. That is the guarantee no
    /// trace suite can offer, and the reason to keep it.
    ///
    /// **What it asserts, per member.** (1) The signature occurs EXACTLY once across
    /// `S/InputBackend/Legacy*.swift` — the vacuity half, so a rename cannot silently drop a member from
    /// coverage. (2) The body contains none of `backendBracketTokens` — the D35 defect itself. (3) The
    /// body matches its declared `ForwardShape`, whose six cases are documented on
    /// `RoutedBackendMember` above. Both the count of members and the count of each shape are derived
    /// from `routedBackendMembers`, never restated in this prose — a self-contradicting sentence is
    /// worse than a silent one, which is the lesson of the "is now SIX" clause Task 30's fix round 1
    /// had to remove from here.
    ///
    /// **The new mechanism's own red-check is
    /// `test_theRoutedMemberShapeScansActuallyDetect_R17`**, below — R14/R15/R16's `…ActuallyDetects`
    /// precedent, extended to the two scans Task 31 added. A per-arm rule that silently finds zero arms
    /// is worse than the flag it replaced, so `switchArms(in:)` returning nil or an empty arm list is an
    /// OFFENDER here, not a skip.
    ///
    /// RED IF: any listed member's body gained `notifyingContentAndSelectionChange { … }` around its
    /// forward, or a trailing `publishState(reason:)`, or a statement its declared shape does not admit.
    /// **Confirmed red** against exactly `notifyingContentAndSelectionChange { legacyCanvas?.legacySetMarkedText(…) }`
    /// in `+MarkedText.swift`: the offender line named the member, the token, and printed the body.
    /// Note the mutation lives inside `#if canImport(UIKit)`, so a macOS `swift test` run compiles it
    /// out entirely — this rule fires on the SOURCE TEXT, which is exactly why it can guard a shape no
    /// macOS-hosted test could otherwise reach.
    func test_routedBackendMembersAreBareForwardsWithNoBracketOfTheirOwn_R17() {
        RepoLayout.assertResolved()
        let files = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
            .filter { $0.lastPathComponent.hasPrefix("Legacy") }
        XCTAssertFalse(files.isEmpty, "no Legacy*.swift sources found — R17 would pass VACUOUSLY")
        let sources: [(name: String, stripped: String)] = files.map {
            ($0.lastPathComponent,
             SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: $0)) ?? ""))
        }
        let allStripped = sources.map(\.stripped).joined(separator: "\n")

        // Vacuity half A: every token in the vocabulary must be REAL source somewhere in the scanned
        // set. A rename of `publishState` (say) would otherwise silently retire that half of the rule.
        for token in Self.backendBracketTokens {
            XCTAssertTrue(allStripped.contains(token),
                          "R17's bracket vocabulary names `\(token)`, which no longer appears in any " +
                          "Legacy*.swift source — the rule has silently stopped covering it")
        }

        var offenders: [String] = []
        for member in Self.routedBackendMembers {
            // Vacuity half B: exactly one declaration, so a rename/reformat cannot make the shape
            // checks below pass by finding nothing. Same construction as
            // `RouterWitnessBodyTests.test_everyEnabledWitnessSignatureWasFound`.
            let total = sources.reduce(0) { $0 + ($1.stripped.components(separatedBy: member.signature).count - 1) }
            guard total == 1 else {
                offenders.append("\(member.name): signature found \(total) times under " +
                                 "S/InputBackend/Legacy*.swift, expected exactly 1")
                continue
            }
            guard let body = sources.compactMap({ Self.balancedBody(after: member.signature, in: $0.stripped) }).first else {
                offenders.append("\(member.name): could not extract a balanced body")
                continue
            }
            if let token = Self.backendBracketTokens.first(where: { body.contains($0) }) {
                offenders.append("\(member.name): body opens a bracket/transaction of its own " +
                                 "(`\(token)`) — the canvas hook already brackets itself, per branch: \(body)")
                continue
            }
            offenders.append(contentsOf: Self.shapeViolations(of: member, body: body))
        }
        XCTAssertEqual(offenders, [], "R17 backend-forward violations: \(offenders)")
    }

    /// The shape half of R17, factored out so `test_theRoutedMemberShapeScansActuallyDetect_R17` can
    /// exercise THE SAME code against synthetic fixtures rather than a second, drifting copy of it.
    /// Returns one string per violation; an empty array means the body matches its declared shape.
    private static func shapeViolations(of member: RoutedBackendMember, body: String) -> [String] {
        switch member.shape {
        case .canvasForward, .client:
            // ┌─ A CONSTRAINT ON HOW TO WRITE A CHECK HERE, not a description of what this rule does
            // │  today. It applies to every present and future shape in this file that admits a prelude.
            // │
            // │  **A shape check applied to a FILTERED statement list is blind to everything the filter
            // │  removed.** The next line filters `guard` lines out so a prelude is permitted — so any
            // │  assertion written against `tail` is UNENFORCED inside that prelude, and a prelude is
            // │  executable code that reaches whatever a statement reaches. Assert against the filtered
            // │  list only for properties that are genuinely about the statements (how many there are,
            // │  what the single one forwards to). Assert against the UNFILTERED `body` for any property
            // │  the prelude could also violate — anything of the form "this member must not reach X".
            // │
            // │  Measured, not argued (Task 31 fix round 1 + its re-review). The `.client` no-canvas
            // │  rule below was first specified as `tail[0].contains("legacyCanvas")`. Against the
            // │  guard-shaped drift `guard let canvas = legacyCanvas, … else { return nil }` +
            // │  `return self.command?.undoManager`, that spelling on real source was **GREEN**; the
            // │  `body.contains` spelling shipped below is **RED**. Same mutation, same rule, opposite
            // │  results — the whole difference is which list was scanned.
            // │
            // │  Cost of scanning `body`, checked rather than feared: `body` is
            // │  `SwiftSourceScan.stripCommentsAndStringLiterals`'d, so a doc comment or a string
            // │  literal merely NAMING the forbidden thing cannot trip it. The project's historical
            // │  scan-tripping-on-a-comment failure does not recur here.
            // └────────────────────────────────────────────────────────────────────────────────────────
            let tail = statementLines(body).filter { !$0.hasPrefix("guard ") }
            guard tail.count == 1 else {
                return ["\(member.name): body is a guard-prelude plus \(tail.count) statements, " +
                        "expected exactly 1: \(body)"]
            }
            if case .canvasForward = member.shape, !tail[0].contains("legacyCanvas?.legacy") {
                return ["\(member.name): the one statement is not a " +
                        "`legacyCanvas?.legacy…` forward: \(tail[0])"]
            }
            // TASK 31 FIX ROUND 1 (review Maj-1) — the POSITIVE half of `.client`, which the case
            // shipped without: it counted statements and checked nothing about what the one statement
            // reached, so re-pointing `undoManager` at `legacyCanvas?.effectiveUndoManager` — the exact
            // D24 clause-(b) drift Task 30 was commended for NOT making — left this rule GREEN
            // (measured on real source, by the reviewer and again here). Two of the four `.client`
            // members have doc comments whose entire correctness argument is "this must NOT reach
            // `legacyCanvas`", so a case that admits one was claiming the thing it did not check — in
            // the very commit that fixed R17 for claiming more than it enforced.
            //
            // The WHOLE body is scanned, not just `tail[0]`: a `guard let canvas = legacyCanvas`
            // prelude reaches the canvas exactly as much as a statement does. No `.client` member has
            // one today (all four bodies were read before this assertion was added), so the stricter
            // form costs nothing and closes the guard-shaped hole in advance.
            if case .client = member.shape, body.contains("legacyCanvas") {
                return ["\(member.name): declared `.client` — it must answer from a CLIENT and must " +
                        "NOT reach `legacyCanvas` at all — but its body names it: \(body)"]
            }
            return []

        case .switchArms(let forwarding, let nonForwarding):
            guard let arms = switchArms(in: body), !arms.isEmpty else {
                return ["\(member.name): declared `.switchArms` but the arm scan found no `switch` " +
                        "it could parse — a per-arm rule that finds zero arms is worse than no rule: \(body)"]
            }
            var out: [String] = []
            let found = Set(arms.map(\.label))
            let named = Set(forwarding).union(Set(nonForwarding))
            if found != named {
                out.append("\(member.name): the arms in the source \(found.sorted()) are not the arms " +
                           "this rule names \(named.sorted()) — a `case` was added, removed or " +
                           "re-spelled without updating `routedBackendMembers`")
            }
            for arm in arms {
                let forwards = arm.body.contains("legacyCanvas?.legacy")
                if forwarding.contains(arm.label), !forwards {
                    out.append("\(member.name): arm `\(arm.label)` is named as a canvas forward but " +
                               "does not call `legacyCanvas?.legacy…`: \(arm.body)")
                }
                if nonForwarding.contains(arm.label), forwards {
                    out.append("\(member.name): arm `\(arm.label)` is named as NON-forwarding but " +
                               "calls `legacyCanvas?.legacy…`: \(arm.body)")
                }
            }
            return out

        case .statements(let allowed):
            let lines = everyStatementLine(body).filter { !isControlFlowScaffolding($0) }
            guard !lines.isEmpty else {
                return ["\(member.name): declared `.statements` but every line is control-flow " +
                        "scaffolding — this shape would check nothing: \(body)"]
            }
            return lines
                .filter { line in !allowed.contains(where: { line.hasPrefix($0) }) }
                .map { "\(member.name): statement `\($0)` is not one of the shape's allowed " +
                       "prefixes \(allowed)" }

        case .literal(let expected):
            return body == expected ? []
                : ["\(member.name): declared `.literal(\"\(expected)\")` but the body is: \(body)"]

        case .deliberatelyEmpty:
            let lines = everyStatementLine(body).filter { !$0.hasPrefix("guard ") }
            return lines.isEmpty ? []
                : ["\(member.name): declared `.deliberatelyEmpty` but the body has real statements " +
                   "\(lines) — if it grew a body, give it a real shape: \(body)"]
        }
    }

    /// One `case`/`default` arm of a `switch`-bodied routed member: its label (the text between the
    /// keyword and the arm's own `:`, whitespace-normalised) and the arm's body text up to the next arm.
    private struct SwitchArm {
        let label: String
        let body: String
    }

    /// Parses the arms of the FIRST `switch` in `body`. Returns `nil` when there is no `switch`, when
    /// its braces do not balance, or when an arm has no `:` at paren depth 0 — every one of which the
    /// CALLER reports as an offender rather than treating as "nothing to check". Coarse by design
    /// (R13's lesson): the only bodies this ever sees are one-statement-per-arm dispatch tables.
    private static func switchArms(in body: String) -> [SwitchArm]? {
        guard let switchRange = body.range(of: "switch ") else { return nil }
        guard let openIndex = body[switchRange.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var i = openIndex
        var close: String.Index?
        while i < body.endIndex {
            if body[i] == "{" { depth += 1 } else if body[i] == "}" {
                depth -= 1
                if depth == 0 { close = i; break }
            }
            i = body.index(after: i)
        }
        guard let close else { return nil }
        let interior = String(body[body.index(after: openIndex)..<close])

        var arms: [SwitchArm] = []
        var currentLabel: String?
        var currentBody = ""
        var armDepth = 0
        var failed = false
        for raw in interior.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let startsArm = armDepth == 0 && (line.hasPrefix("case ") || line.hasPrefix("default"))
            if startsArm {
                if let label = currentLabel { arms.append(SwitchArm(label: label, body: currentBody)) }
                let isDefault = line.hasPrefix("default")
                let afterKeyword = isDefault
                    ? String(line.dropFirst("default".count))
                    : String(line.dropFirst("case ".count))
                guard let colon = colonAtTopLevel(in: afterKeyword) else { failed = true; break }
                currentLabel = isDefault
                    ? "default"
                    : normalizingWhitespace(String(afterKeyword[..<colon]))
                currentBody = String(afterKeyword[afterKeyword.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
            } else if currentLabel != nil {
                if !currentBody.isEmpty { currentBody += "\n" }
                currentBody += line
            }
            armDepth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            if armDepth < 0 { armDepth = 0 }
        }
        if failed { return nil }
        if let label = currentLabel { arms.append(SwitchArm(label: label, body: currentBody)) }
        return arms
    }

    /// The index of the first `:` outside any `(` / `[` nesting — an arm label's own terminator, which a
    /// naive `firstIndex(of: ":")` would confuse with an argument label inside a pattern binding.
    private static func colonAtTopLevel(in text: String) -> String.Index? {
        var nesting = 0
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "(" || ch == "[" { nesting += 1 } else if ch == ")" || ch == "]" { nesting -= 1 } else if ch == ":", nesting == 0 { return i }
            i = text.index(after: i)
        }
        return nil
    }

    private static func normalizingWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The balanced `{ … }` interior immediately following `signature` in `stripped`, trimmed. Same
    /// mechanism as `RouterWitnessBodyTests.routedBody(forSignature:in:)` — deliberately duplicated
    /// rather than shared, because these two rules scan DIFFERENT trees for DIFFERENT shapes and a
    /// shared helper would couple their futures.
    private static func balancedBody(after signature: String, in stripped: String) -> String? {
        guard let sigRange = stripped.range(of: signature) else { return nil }
        var idx = sigRange.upperBound
        while idx < stripped.endIndex, stripped[idx].isWhitespace { idx = stripped.index(after: idx) }
        guard idx < stripped.endIndex, stripped[idx] == "{" else { return nil }
        var depth = 0
        var i = idx
        var close: String.Index?
        while i < stripped.endIndex {
            if stripped[i] == "{" { depth += 1 } else if stripped[i] == "}" {
                depth -= 1
                if depth == 0 { close = i; break }
            }
            i = stripped.index(after: i)
        }
        guard let close else { return nil }
        return String(stripped[stripped.index(after: idx)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A body's non-empty, trimmed lines AT BRACE DEPTH 0, with a `guard … else { … }` collapsed onto the
    /// `guard` line it starts on so a multi-line guard counts once. Coarse by design (R13's lesson).
    ///
    /// **This is the scan whose depth-0 restriction made `isCanvasForward`'s shape half inert for a
    /// `switch`.** It is kept, unchanged, for the two ONE-STATEMENT shapes, where depth-0 is exactly
    /// what "exactly one statement" means; `everyStatementLine` below is the nesting-aware companion the
    /// multi-statement shape needs.
    private static func statementLines(_ body: String) -> [String] {
        var out: [String] = []
        var depth = 0
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if depth == 0, !line.isEmpty { out.append(line) }
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            if depth < 0 { depth = 0 }
        }
        return out
    }

    /// Every non-empty trimmed line of `body`, AT ANY BRACE DEPTH — the companion to `statementLines`
    /// above, and the reason `.statements` cannot degrade to vacuity: a statement placed inside an `if`
    /// block is reported here, where `statementLines` would not see it at all.
    private static func everyStatementLine(_ body: String) -> [String] {
        body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Lines that carry no work of their own: closing braces, `else`/`if` openers, a bare `return`, and
    /// the permitted `guard` prelude. Everything else must match its member's allowed prefixes.
    private static func isControlFlowScaffolding(_ line: String) -> Bool {
        if line == "}" || line == "{" || line == "return" { return true }
        if line == "} else {" || line == "else {" || line == "} else" || line == "else" { return true }
        if line.hasPrefix("guard ") { return true }
        if line.hasSuffix("{"), line.hasPrefix("if ") || line.hasPrefix("} else if ") { return true }
        return false
    }

    /// The positive half of R17's TASK-31 mechanism (R14/R15/R16's `…ActuallyDetects` precedent, and
    /// §0's requirement 4): the two scans Task 31 added are unit-tested against synthetic fixtures, so a
    /// rule that regressed to finding nothing fails HERE rather than silently covering nothing on the
    /// real sources. Fixtures spell `example()`, never `func test_…` (R14's fix-round lesson: a
    /// synthetic fixture with an XCTest-shaped name inflates grep-based test counts).
    func test_theRoutedMemberShapeScansActuallyDetect_R17() {
        // --- the switch-arm scan ---
        let dispatch = """
        switch command {
        case .copy: legacyCanvas?.legacyCopy(sender)
        case .cut: legacyCanvas?.legacyCut(sender)
        case .undo, .redo: performThroughCommandClient(command, sender: sender)
        }
        """
        guard let arms = Self.switchArms(in: dispatch) else {
            return XCTFail("the arm scan failed to parse a well-formed dispatch switch")
        }
        XCTAssertEqual(arms.map(\.label), [".copy", ".cut", ".undo, .redo"],
                       "the arm scan must find every arm, with its label normalised — a scan that " +
                       "finds zero arms would make the per-arm rule vacuous")
        XCTAssertEqual(arms.map { $0.body.contains("legacyCanvas?.legacy") }, [true, true, false],
                       "the arm scan must attribute each arm's body to that arm")

        func armViolations(_ body: String,
                           forwarding: [String], nonForwarding: [String]) -> [String] {
            Self.shapeViolations(
                of: RoutedBackendMember(name: "example()", signature: "func example()",
                                        shape: .switchArms(forwarding: forwarding,
                                                           nonForwarding: nonForwarding)),
                body: body)
        }
        XCTAssertEqual(armViolations(dispatch, forwarding: [".copy", ".cut"],
                                     nonForwarding: [".undo, .redo"]), [],
                       "a correctly classified dispatch switch must produce no violation")

        let repointed = dispatch.replacingOccurrences(
            of: "case .cut: legacyCanvas?.legacyCut(sender)",
            with: "case .cut: performThroughCommandClient(command, sender: sender)")
        XCTAssertEqual(armViolations(repointed, forwarding: [".copy", ".cut"],
                                     nonForwarding: [".undo, .redo"]).count, 1,
                       "an arm re-pointed at the client must be caught — this is the mutation `.copy` " +
                       "and `.cut` have NO other cover against")

        let extraArm = dispatch.replacingOccurrences(
            of: "case .undo, .redo:",
            with: "case .brandNew: legacyCanvas?.legacyBrandNew(sender)\ncase .undo, .redo:")
        XCTAssertFalse(armViolations(extraArm, forwarding: [".copy", ".cut"],
                                     nonForwarding: [".undo, .redo"]).isEmpty,
                       "an arm present in the source but named in neither set must be caught, or a " +
                       "`case` could be added silently")

        // --- the nesting-aware statement scan ---
        let nested = """
        guard isAttached, let host, let canvas = legacyCanvas else { return }
        canvas.legacyDidSomething()
        if !someFlag {
            host.lifecycleClient.backendDidBeginEditing()
        }
        """
        XCTAssertEqual(Self.statementLines(nested).filter { !$0.hasPrefix("guard ") }.count, 2,
                       "precondition: the DEPTH-0 scan sees only two lines here and cannot see inside " +
                       "the `if` at all — the exact vacuity that made `isCanvasForward` inert")
        func statementViolations(_ body: String, allowed: [String]) -> [String] {
            Self.shapeViolations(
                of: RoutedBackendMember(name: "example()", signature: "func example()",
                                        shape: .statements(allowed: allowed)),
                body: body)
        }
        XCTAssertEqual(statementViolations(nested, allowed: ["canvas.legacy",
                                                            "host.lifecycleClient.backendDidBeginEditing()"]),
                       [],
                       "a body whose every non-scaffolding line matches an allowed prefix must pass")
        let smuggled = nested.replacingOccurrences(
            of: "    host.lifecycleClient.backendDidBeginEditing()",
            with: "    host.lifecycleClient.backendDidBeginEditing()\n    canvas.setNeedsDisplay()")
        XCTAssertEqual(statementViolations(smuggled, allowed: ["canvas.legacy",
                                                              "host.lifecycleClient.backendDidBeginEditing()"]).count, 1,
                       "a statement smuggled INSIDE the `if` must be caught — this is what the new " +
                       "scan buys over `statementLines`")
        XCTAssertFalse(statementViolations("guard isAttached else { return }", allowed: ["x"]).isEmpty,
                       "a `.statements` member whose body is nothing but scaffolding checks nothing " +
                       "and must be reported, not silently passed")

        // --- the two ONE-STATEMENT shapes (TASK 31 FIX ROUND 1, review Maj-1) ---
        //
        // These two were the cases this fixture did NOT exercise when it shipped, which is one of the
        // three reasons Maj-1 was filed: `.client`'s missing assertion and the missing fixture for it
        // were the same omission seen from two sides. Both directions are covered per case, so neither
        // the new `.client` assertion nor the pre-existing `.canvasForward` one can be unfalsifiable.
        func forwardViolations(_ body: String, _ shape: ForwardShape) -> [String] {
            Self.shapeViolations(
                of: RoutedBackendMember(name: "example()", signature: "func example()", shape: shape),
                body: body)
        }
        XCTAssertEqual(forwardViolations("legacyCanvas?.legacyDoWork()", .canvasForward), [],
                       "a plain `legacyCanvas?.legacy…` forward is what `.canvasForward` means")
        XCTAssertFalse(forwardViolations("self.command?.doWork()", .canvasForward).isEmpty,
                       "a `.canvasForward` member that answers from a client must be caught")
        XCTAssertEqual(forwardViolations("self.command?.undoManager", .client), [],
                       "a plain client answer is what `.client` means")
        XCTAssertFalse(forwardViolations("legacyCanvas?.effectiveUndoManager", .client).isEmpty,
                       "THE Maj-1 MUTATION: a `.client` member re-pointed at the canvas must be " +
                       "caught — this is the D24 clause-(b) drift that left the shipped rule green")
        XCTAssertFalse(forwardViolations(
            "guard let canvas = legacyCanvas else { return }\ncanvas.doWork()", .client).isEmpty,
                       "…and reaching the canvas from the GUARD prelude counts too, which is why the " +
                       "assertion scans the whole body rather than the one statement")
        XCTAssertFalse(forwardViolations("self.command?.a()\nself.command?.b()", .client).isEmpty,
                       "the statement-count half still applies to `.client`")

        // --- the two simple shapes, so every case of the enum is exercised here ---
        func literalViolations(_ body: String, expected: String) -> [String] {
            Self.shapeViolations(
                of: RoutedBackendMember(name: "example", signature: "var example: Bool",
                                        shape: .literal(expected)),
                body: body)
        }
        XCTAssertEqual(literalViolations("true", expected: "true"), [])
        XCTAssertFalse(literalViolations("editPolicy.isEditable", expected: "true").isEmpty,
                       "a literal that grew a gate must be caught")
        func emptyViolations(_ body: String) -> [String] {
            Self.shapeViolations(
                of: RoutedBackendMember(name: "example()", signature: "func example()",
                                        shape: .deliberatelyEmpty),
                body: body)
        }
        XCTAssertEqual(emptyViolations("guard isAttached else { return }"), [])
        XCTAssertFalse(emptyViolations("guard isAttached else { return }\ncanvas.legacyDoWork()").isEmpty,
                       "a `.deliberatelyEmpty` member that grew a body must be caught")
    }

    // MARK: - R18 (Task 29) — the reference conformer's forwards stay forwards

    /// The members of `ReferenceMutationBackend` that are NOT plain `inner.…` forwards, because each
    /// carries a body re-homed from `LegacyRichTextInputBackend` when the real member became a
    /// `legacyCanvas` forward. Grows as later family tasks re-home more; it must never grow by accident,
    /// which is what direction (2) of the rule below enforces.
    private static let referenceConformerNonForwards: Set<String> = [
        "insertText",        // Task 27b — the document-client mutation transaction
        "deleteBackward",    // Task 28  — ditto
        "setMarkedText",     // Task 29  — the Task-22f storage-only marked-text body
        "markedTextRange",   // Task 29  — its paired read over `inner.markedRangeStorage`
    ]

    /// R18 (added Task 29, commissioned by its coordinator supplement §6) — the CONFORMER rule.
    ///
    /// `ReferenceMutationBackend` (`T/Support/`) is the test-only conformer the eight contract suites run
    /// against, and its ~70 hand-written `inner.…` forwards are mechanically unguarded: a forward that
    /// quietly grew a body of its own would make a contract suite certify the FIXTURE rather than
    /// `LegacyRichTextInputBackend`, silently, in an artifact stage 2 inherits.
    ///
    /// **The construction is two-way, and that is load-bearing** (R13 is the precedent for building a
    /// rule that fails in both directions rather than one that only re-checks what it already knew):
    ///
    ///   1. an UNLISTED member whose body is not a plain `inner.…` forward → fail; and
    ///   2. a LISTED member whose body HAS become a plain forward → fail.
    ///
    /// Without (2) the allow-list would decay into documentation: a future task could re-point a re-homed
    /// body back at `inner` — losing the whole point of the conformer — and the rule would stay green.
    ///
    /// "Plain forward" is deliberately COARSE, but BOUNDED: every statement line, after dropping a
    /// leading `return `/`try `/`get { `/`set { ` and a trailing ` }`, must begin `inner.` — **and there
    /// must be exactly ONE such line for a `func`, or exactly TWO for a `{ get set }` accessor pair.**
    ///
    /// **The count is the half Task 29's own red-checks did not exercise, added at its review (m5).**
    /// Without it the "every line begins `inner.`" test alone classifies a body of
    ///
    ///     inner.clearCompositionState()
    ///     inner.unmarkText()
    ///
    /// as a plain forward — unlisted, no offender, green — which is precisely the "a forward that
    /// quietly grew a body of its own" case this rule exists to catch. RC5 mutated an unlisted member
    /// with two NON-`inner.` statements and saw red, which is the easy direction; the adversarial
    /// two-`inner.`-statement mutation was run in fix round 1 and now reddens (see the RED IF below).
    /// The accessor-pair allowance of two is exact, not a loosening: a `{ get set }` pair is two lines
    /// by construction, so a third line in one is as much a violation as a second in a `func`.
    ///
    /// **`init` bodies are skipped by construction** (they are neither `func` nor `var`). **Stored
    /// properties are NOT skipped by construction, and this claim used to say they were** (m6): a
    /// stored property IS a `var` at brace depth 1, and `balancedBodyOfDeclaration` would scan past its
    /// `= …` initialiser to the NEXT `{` and attribute the FOLLOWING member's body to it. The scan now
    /// skips a `var` whose declaration reaches a newline before any `{`, which is what a stored property
    /// looks like — so the claim is now true by mechanism rather than by the accident that this file's
    /// one stored property (`let inner`) happens to be a `let`.
    ///
    /// RED IF: a listed member were re-pointed at `inner` (direction 2), or an unlisted forward grew a
    /// second statement (direction 1). **Confirmed red against BOTH**, which is the whole point of the
    /// two-way construction: direction 2 by replacing `markedTextRange`'s re-homed body with
    /// `{ inner.markedTextRange }`, direction 1 by giving the unlisted `unmarkText()` two extra
    /// statements before its forward. Each produced exactly one offender naming the member.
    ///
    /// **RED IF (the adversarial direction-1 case, added in fix round 1):** an unlisted member grew a
    /// second statement that is ITSELF `inner.`-prefixed — `inner.clearCompositionState()` above
    /// `inner.unmarkText()`. Before the statement-count check this classified as a plain forward and
    /// stayed green; **confirmed red** afterwards, with the offender naming `unmarkText` and printing
    /// both lines. This is the mutation the original red-check pair missed, and it is the one a
    /// well-intentioned future edit would actually produce.
    func test_referenceConformerForwardsStayForwards_R18() {
        RepoLayout.assertResolved()
        let url = RepoLayout.uiKitTestsSupport.appendingPathComponent("ReferenceMutationBackend.swift")
        let raw = (try? String(contentsOf: url)) ?? ""
        XCTAssertFalse(raw.isEmpty, "could not read ReferenceMutationBackend.swift — R18 would pass VACUOUSLY")
        let stripped = SwiftSourceScan.stripCommentsAndStringLiterals(raw)

        // Walk the file tracking brace depth; a member declaration is a `func `/`var ` token at depth 1
        // (the class body). Anything nested inside a member body is at a deeper depth and ignored.
        var members: [(name: String, body: String)] = []
        var depth = 0
        var i = stripped.startIndex
        while i < stripped.endIndex {
            let ch = stripped[i]
            if ch == "{" { depth += 1; i = stripped.index(after: i); continue }
            if ch == "}" { depth -= 1; i = stripped.index(after: i); continue }
            if depth == 1, ch == "f" || ch == "v" {
                let isFunc = stripped[i...].hasPrefix("func ")
                let isVar = stripped[i...].hasPrefix("var ")
                if isFunc || isVar {
                    let afterKeyword = stripped.index(i, offsetBy: isFunc ? 5 : 4)
                    let name = String(stripped[afterKeyword...].prefix { $0.isLetter || $0.isNumber || $0 == "_" })
                    // m6 — STORED PROPERTIES ARE SKIPPED BY MECHANISM, not by accident. A stored
                    // property IS a `var` at depth 1; without this guard `balancedBodyOfDeclaration`
                    // would scan past its `= …` initialiser to the NEXT `{` and attribute the FOLLOWING
                    // member's body to it (a silent extra "forward", or a spurious offender). A
                    // COMPUTED member's `{` is on the declaration line or the one continuing it; a
                    // STORED one reaches a newline first. That is the distinction, and it is checked
                    // rather than assumed. (`let` declarations never reach here at all.)
                    if isVar, Self.declarationEndsBeforeItsBrace(startingAt: afterKeyword, in: stripped) {
                        i = afterKeyword
                        continue
                    }
                    // The declaration's own body starts at the next `{` that is not inside its
                    // parameter list; `balancedBody(after:in:)` needs a literal, so scan forward here.
                    if let body = Self.balancedBodyOfDeclaration(startingAt: afterKeyword, in: stripped) {
                        members.append((name, body))
                    }
                    i = afterKeyword
                    continue
                }
            }
            i = stripped.index(after: i)
        }

        // Vacuity half: a parse that stopped finding members would make both directions pass trivially.
        XCTAssertGreaterThan(members.count, 60,
                             "R18 discovered only \(members.count) members of ReferenceMutationBackend — " +
                             "the depth-aware scan has broken and the rule is vacuous")
        for listed in Self.referenceConformerNonForwards {
            XCTAssertTrue(members.contains { $0.name == listed },
                          "R18's allow-list names `\(listed)`, which the scan no longer finds as a " +
                          "member of ReferenceMutationBackend")
        }

        var offenders: [String] = []
        var forwardCount = 0
        for member in members {
            let isForward = Self.isPlainInnerForward(member.body)
            if isForward { forwardCount += 1 }
            let listed = Self.referenceConformerNonForwards.contains(member.name)
            if listed, isForward {
                offenders.append("\(member.name): listed as a re-homed body, but is now a plain " +
                                 "`inner.…` forward — the body a contract suite is supposed to exercise " +
                                 "has been given back to the legacy backend")
            }
            if !listed, !isForward {
                offenders.append("\(member.name): is not a plain `inner.…` forward and is not on " +
                                 "R18's allow-list — a contract suite driving it would certify the " +
                                 "FIXTURE, not LegacyRichTextInputBackend: \(member.body)")
            }
        }
        XCTAssertGreaterThan(forwardCount, 50,
                             "R18 classified only \(forwardCount) members as plain forwards — the " +
                             "classifier has broken and direction (1) is vacuous")
        XCTAssertEqual(offenders, [], "R18 reference-conformer violations: \(offenders)")
    }

    /// The balanced body of a declaration whose NAME starts at `start`: skips the parameter list (a
    /// paren-depth walk) and returns the interior of the first `{` at paren depth 0.
    private static func balancedBodyOfDeclaration(startingAt start: String.Index, in stripped: String) -> String? {
        var parens = 0
        var i = start
        var open: String.Index?
        while i < stripped.endIndex {
            let ch = stripped[i]
            if ch == "(" { parens += 1 } else if ch == ")" { parens -= 1 }
            else if ch == "{", parens == 0 { open = i; break }
            i = stripped.index(after: i)
        }
        guard let open else { return nil }
        var depth = 0
        var j = open
        var close: String.Index?
        while j < stripped.endIndex {
            if stripped[j] == "{" { depth += 1 } else if stripped[j] == "}" {
                depth -= 1
                if depth == 0 { close = j; break }
            }
            j = stripped.index(after: j)
        }
        guard let close else { return nil }
        return String(stripped[stripped.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when a `var` declaration beginning at `start` reaches a newline before any `{` at paren
    /// depth 0 — i.e. it is a STORED property (`var x: T = v`), not a computed one. See the call site
    /// for why this must be a mechanism rather than an assumption (m6).
    private static func declarationEndsBeforeItsBrace(startingAt start: String.Index, in stripped: String) -> Bool {
        var parens = 0
        var i = start
        while i < stripped.endIndex {
            let ch = stripped[i]
            if ch == "(" { parens += 1 } else if ch == ")" { parens -= 1 }
            else if ch == "{", parens == 0 { return false }
            else if ch == "\n", parens == 0 { return true }
            i = stripped.index(after: i)
        }
        return true
    }

    /// COARSE by design but BOUNDED (see R18's doc comment): every statement line, after dropping a
    /// leading `return `/`try `/`get { `/`set { ` and a trailing ` }`, must begin `inner.` — AND the
    /// line count must be exactly 1 (a `func` or a `{ get }`-only computed var) or exactly 2 (a
    /// `{ get set }` accessor pair). The count is what stops two chained `inner.` calls from passing as
    /// a "plain forward"; without it the rule cannot see the very shape it exists to catch (m5).
    private static func isPlainInnerForward(_ body: String) -> Bool {
        let lines = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count == 1 || (lines.count == 2 && lines[0].hasPrefix("get ") && lines[1].hasPrefix("set ")) else {
            return false
        }
        for line in lines {
            var t = Substring(line)
            for prefix in ["get { ", "set { ", "return ", "try "] where t.hasPrefix(prefix) {
                t = t.dropFirst(prefix.count)
            }
            if t.hasSuffix(" }") { t = t.dropLast(2) }
            if t.hasPrefix("return ") { t = t.dropFirst("return ".count) }
            guard t.hasPrefix("inner.") else { return false }
        }
        return true
    }

    // MARK: - R19 (Task 32) — D18: the detach-only teardown pair is wired into detach() and nowhere else

    /// **DEVIATION D18, made mechanical.** `removeInteractions()` and `cancelActiveInteraction(reason:)`
    /// tear down more than `DocumentCanvasView.resignFirstResponder()` does today — the recognizers, the
    /// two `CADisplayLink`s, the floating-cursor session. That is safe ONLY because `detach()` runs at
    /// `deinit`, where nothing can observe the difference. **Wiring either into `resignFirstResponder()`
    /// would FIX the teardown gaps `ResponderLifecycleCharacterizationTests` pins, which is a behaviour
    /// change, not an extraction** — and it is the single most inviting wrong edit in this family,
    /// because it looks like tidying up an obvious omission.
    ///
    /// Until Task 32 the constraint was prose in three places (`+Attachment.swift`'s `detach()` banner,
    /// `legacyTearDownPresentation()`'s own note, and the plan's D18 row) and checked nowhere. This rule
    /// is the check. It is a SOURCE rule rather than a behavioural one on purpose: the behavioural
    /// companion (`InteractionRouterTests
    /// .test_resignFirstResponder_doesNotRemoveTheCanvasInteractions`) proves the recognizers survive a
    /// resign, but it cannot see a call added on a path that resign does not take in a unit test, and it
    /// cannot see `cancelActiveInteraction(reason:)` being called from somewhere new at all.
    ///
    /// **What it asserts:** across **the whole of `Sources/RichTextEditorUIKit/**`** (recursively —
    /// `RepoLayout.uiKitSources`, so `InputBackend/`, `Canvas/`, the facade and everything else),
    /// comment- and string-stripped, every call site of each guarded member sits in that member's own
    /// sanctioned file. FIX ROUND 1 (review Minor 2): the doc used to say "`S/InputBackend/**` and
    /// `S/Canvas/**`", which understated the check the code actually runs — the safe direction, but a
    /// rule must describe itself accurately.
    ///
    /// **THREE members are guarded, not two — FIX ROUND 1 closed the shortest possible violation.** The
    /// original list named only the two BACKEND members, which left the most direct way to break D18
    /// uncovered: wiring the CANVAS hook `legacyRemoveSelectionInteractions()` straight into a resign
    /// path touches neither named member and was GREEN. (The doc's old "a call reached indirectly
    /// through a new helper" did not describe that case — the hook is not a helper, it is the thing
    /// being protected.) **A rule that mechanises a deviation must catch that deviation's shortest
    /// violation first.**
    ///
    ///   * `removeInteractions()` — 2 sanctioned sites in `LegacyRichTextInputBackend+Attachment.swift`
    ///     (`performDetachSteps()` step 4, and `attach(to:)`'s catch path, which calls it to keep attach
    ///     atomic).
    ///   * `cancelActiveInteraction(reason:` — 1 site in the same file (`performDetachSteps()` step 2).
    ///   * `legacyRemoveSelectionInteractions()` — 1 site in
    ///     `LegacyRichTextInputBackend+Interaction.swift` (the routed `removeInteractions()` body). Its
    ///     DECLARATION lives on the canvas and is excluded by the `func ` subtraction below, like the
    ///     other two.
    ///
    /// **Deliberately a FILE-level rule, not a function-level one**, on R13's standing lesson (stay
    /// coarse rather than fragile-precise). Locating the enclosing function of a match means parsing
    /// Swift; a file check needs none and still forbids the whole class of wrong edits, because
    /// `resignFirstResponder()` (canvas) and `hostWillResignFirstResponder()`/`hostDidResignFirstResponder()`
    /// (`+Responder.swift`) are all in other files. What it does NOT catch, stated so the claim is not
    /// wider than the check: a caller added to a member's OWN sanctioned file, and a call reached
    /// through a newly introduced third method that this list does not name. Both are visible in review
    /// of the two files this rule names.
    ///
    /// Positive self-check, and it is PER MEMBER rather than a single total: each guarded member
    /// declares its exact expected call-site count, so losing ANY one site (a rename, a refactor) fails
    /// rather than being absorbed by the others. The review measured the old single `>= 3` floor as
    /// tight; the per-member form keeps that property while the list grows.
    func test_detachOnlyTeardownIsNotWiredIntoResignFirstResponder_R19() {
        RepoLayout.assertResolved()
        let files = RepoLayout.swiftFiles(under: RepoLayout.uiKitSources)
        XCTAssertFalse(files.isEmpty, "no UIKit sources found — R19 would pass VACUOUSLY")

        // The DECLARATIONS (`func removeInteractions()`, the protocol requirement, the routed body, and
        // the canvas hook's own `func legacyRemoveSelectionInteractions()`) are not call sites; strip the
        // `func ` form out before counting so the rule measures what it claims.
        let attachment = "LegacyRichTextInputBackend+Attachment.swift"
        let interaction = "LegacyRichTextInputBackend+Interaction.swift"
        let guarded: [(call: String, sanctioned: String, expected: Int)] = [
            ("removeInteractions()", attachment, 2),                 // detach step 4 + attach's catch path
            ("cancelActiveInteraction(reason:", attachment, 1),      // detach step 2
            ("legacyRemoveSelectionInteractions()", interaction, 1), // the routed removeInteractions() body
        ]
        var offenders: [String] = []
        var found: [String: Int] = [:]
        for url in files {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: url)) ?? "")
            for member in guarded {
                var count = stripped.components(separatedBy: member.call).count - 1
                count -= stripped.components(separatedBy: "func " + member.call).count - 1
                guard count > 0 else { continue }
                if url.lastPathComponent == member.sanctioned {
                    found[member.call, default: 0] += count
                } else {
                    offenders.append("\(url.lastPathComponent) calls `\(member.call)` \(count)× — D18 " +
                                     "allows call sites in \(member.sanctioned) ONLY. Wiring interaction " +
                                     "teardown into resignFirstResponder — directly or through the canvas " +
                                     "hook — closes a teardown gap this phase must preserve.")
                }
            }
        }
        XCTAssertEqual(offenders, [], "R19 D18 violations: \(offenders)")
        for member in guarded {
            XCTAssertEqual(found[member.call, default: 0], member.expected,
                           "expected exactly \(member.expected) sanctioned call site(s) of " +
                           "`\(member.call)` in \(member.sanctioned); found " +
                           "\(found[member.call, default: 0]) — a rename or a refactor would otherwise " +
                           "make R19 pass VACUOUSLY for this member")
        }
    }

    // MARK: - R22 (Task 36a, fix round 1) — an outcome-returning primitive is never @discardableResult

    /// R22 — **no declaration returning `RichTextInputCaretOutcome` may be marked
    /// `@discardableResult`.** A FIXED, zero-forever rule (like R9-R12/R14-R16), not a
    /// decreasing-baseline ratchet.
    ///
    /// # The trap this exists for, measured rather than suspected
    ///
    /// Task 36a added an outcome-returning `editing` overload (then called
    /// `editingApplyingOutcome`) alongside the `Void`-returning `editing(coalescing:_:)`, Task 36b
    /// converted 26 mutation primitives to return `RichTextInputCaretOutcome`, and **Task 36c flipped
    /// every call site and DELETED the `Void` overload** — so `DocumentCanvasView.editing` is one
    /// entry point again, with the outcome-returning closure type.
    ///
    /// While both overloads existed, **calling a converted primitive from the `Void` form silently
    /// discarded its caret claim** — `editing { primitive() }` type-checked, because Swift lets a
    /// closure whose body produces a value satisfy `() -> Void`. That exact spelling is now a hard
    /// error, but the rule is NOT thereby obsolete: the discard it guards against survives one level
    /// down, at any multi-statement body (or any non-`editing` caller) that ignores a returned
    /// outcome. The consequence is the same — a caret that stays where the body left it instead of
    /// where the primitive claimed, a behaviour bug no type error and no existing suite catches.
    ///
    /// Today there IS a signal: `warning: result of call to 'primitive()' is unused`. Two measured
    /// facts make it insufficient, which is why this rule exists rather than a doc comment:
    ///
    ///   1. **`@discardableResult` erases it completely.** Verified with a standalone `swiftc` probe:
    ///      without the attribute the call warns; with it, the same call compiles with no diagnostic
    ///      at all. (`editing { return primitive() }` is a hard error either way, so only the
    ///      implicit-discard spelling is dangerous.)
    ///   2. **Even unattributed, the fallback warning is invisible.** The package builds with ~1025
    ///      distinct warnings (1084 at Task 36a), and the only warning gate any Phase-5 task checks is
    ///      the `setter for 'anchor'/'head'` deprecation count (1009 after Task 36c, 1069 at 36a) —
    ///      which an unused-result warning does not move. One more warning in a thousand is not a
    ///      guard.
    ///
    /// And `@discardableResult` is exactly the attribute a converter reaches for: 36b's whole
    /// constraint was keeping ~105 existing `editing { }` call sites compiling while it converted the
    /// primitives underneath them. The plan's answer was a thin `-> Void` wrapper that applied its own
    /// outcome (36c deleted the last of those); this rule is what made the shortcut fail loudly, and
    /// it stays a FIXED zero rule because the next converter faces the same temptation.
    ///
    /// # What this rule does NOT catch — read before trusting it wider than it is
    ///
    ///   * It does **not** detect a discarded outcome at a CALL site. An un-attributed primitive
    ///     called from a multi-statement `editing { }` body still compiles; the compiler's
    ///     unused-result warning is the only signal, and this rule's job is to keep that signal from
    ///     being silenced, not to replace it. (Task 36c's `_ =` in `CaretOutcomeTests` is a
    ///     deliberate, local discard of exactly that kind — in a test, which this scan does not read.)
    ///   * It keys on the literal type name. A `typealias`, or a primitive returning a tuple or an
    ///     `Optional<RichTextCanonicalSelection>` that carries the same meaning, passes.
    ///   * It scans `Sources/RichTextEditorUIKit` only. A test helper may still be
    ///     `@discardableResult`; that is deliberate — a discarded claim in a test is not a shipped bug.
    ///   * It is a SYNTACTIC scan of the text between the attribute and the next `{`, so it cannot see
    ///     an attribute applied through a macro or a protocol requirement's witness.
    ///
    /// Pinned against synthetic fixtures by `test_theDiscardableOutcomeScanActuallyDetects_R22`, so a
    /// scan that regressed to finding nothing fails there rather than passing here — the
    /// `…ActuallyDetects` precedent R14-R17/R20 set.
    func test_noOutcomeReturningDeclarationIsDiscardable_R22() {
        RepoLayout.assertResolved()
        let files = RepoLayout.swiftFiles(under: RepoLayout.uiKitSources)
        XCTAssertFalse(files.isEmpty, "no S/RichTextEditorUIKit sources found — R22 would pass VACUOUSLY")

        var offenders: [String] = []
        var sawTheType = false
        for url in files {
            let stripped = SwiftSourceScan.stripCommentsAndStringLiterals(
                (try? String(contentsOf: url)) ?? "")
            if stripped.contains("RichTextInputCaretOutcome") { sawTheType = true }
            offenders += Self.discardableOutcomeDeclarations(stripped: stripped)
                .map { "\(url.lastPathComponent): \($0)" }
        }
        // Vacuity guard with a REAL subject: if the type were renamed away, every scan below would
        // find nothing and this rule would certify a tree it no longer describes.
        XCTAssertTrue(sawTheType,
                      "no source file mentions `RichTextInputCaretOutcome` in CODE — either the type " +
                      "was renamed (update this rule with it) or the stripper broke; R22 would pass " +
                      "VACUOUSLY either way")
        XCTAssertEqual(offenders, [],
                       "a declaration returning RichTextInputCaretOutcome is marked " +
                       "@discardableResult. That attribute erases the ONLY signal that a converted " +
                       "primitive's caret claim was dropped by an `editing { }` call site (see this " +
                       "rule's doc comment for the measurement). Fix the call site — convert it to " +
                       "return or apply the outcome — rather than silencing it here. — \(offenders)")
    }

    /// The scan half of R22, factored out so `test_theDiscardableOutcomeScanActuallyDetects_R22`
    /// exercises THE SAME code against synthetic fixtures rather than a second, drifting copy.
    /// `stripped` must be `SwiftSourceScan.stripCommentsAndStringLiterals(raw)` — the attribute and
    /// the return type are both real code, so unlike R20 there is no raw-text half.
    ///
    /// The window is "from the attribute to the next `{`", which is the declaration's signature: a
    /// function body cannot start before its brace, so a `-> RichTextInputCaretOutcome` inside the
    /// window is this declaration's own return type and not some later one's.
    private static func discardableOutcomeDeclarations(stripped: String) -> [String] {
        let attribute = "@discardableResult"
        var out: [String] = []
        var search = stripped.startIndex
        while let hit = stripped.range(of: attribute, range: search..<stripped.endIndex) {
            search = hit.upperBound
            let brace = stripped.range(of: "{", range: hit.upperBound..<stripped.endIndex)?.lowerBound
                ?? stripped.endIndex
            let signature = stripped[hit.upperBound..<brace]
            if signature.contains("-> RichTextInputCaretOutcome")
                || signature.contains("->RichTextInputCaretOutcome") {
                out.append("@discardableResult on a declaration returning RichTextInputCaretOutcome")
            }
        }
        return out
    }

    /// The positive half of R22: the scan is pinned against synthetic input, so a regression to
    /// "finds nothing" fails HERE rather than silently certifying the real tree. Fixtures spell
    /// `example()`, never `func test_…`, per R14's fix-round lesson.
    func test_theDiscardableOutcomeScanActuallyDetects_R22() {
        func hits(_ source: String) -> [String] {
            Self.discardableOutcomeDeclarations(
                stripped: SwiftSourceScan.stripCommentsAndStringLiterals(source))
        }

        XCTAssertEqual(hits("func example() -> RichTextInputCaretOutcome { .unchanged }\n"), [],
                       "an outcome-returning declaration WITHOUT the attribute is the correct shape")
        XCTAssertEqual(
            hits("@discardableResult func example() -> RichTextInputCaretOutcome { .unchanged }\n").count, 1,
            "the violation this rule exists for must be detected")
        XCTAssertEqual(
            hits("@discardableResult\nfunc example() -> RichTextInputCaretOutcome {\n    .unchanged\n}\n").count, 1,
            "…including the attribute on its own line, which is how Swift declarations are usually " +
            "written and which a same-line substring search would miss")
        XCTAssertEqual(
            hits("@discardableResult func example(at o: Int)->RichTextInputCaretOutcome { .unchanged }\n").count, 1,
            "…and the un-spaced arrow spelling")

        // Must NOT fire.
        XCTAssertEqual(hits("@discardableResult func example() -> Int { 0 }\n"), [],
                       "@discardableResult on an unrelated return type is none of this rule's business")
        XCTAssertEqual(
            hits("@discardableResult func a() -> Int { 0 }\nfunc b() -> RichTextInputCaretOutcome { .unchanged }\n"),
            [],
            "the window must STOP at the attributed declaration's own brace — a later, unattributed " +
            "outcome-returning function must not be attributed to it. This is the case a naive " +
            "\"does the file contain both tokens\" scan gets wrong, and the reason the scan is " +
            "windowed at all")
        XCTAssertEqual(
            hits("/// prose naming @discardableResult and -> RichTextInputCaretOutcome\nfunc example() {}\n"),
            [],
            "a doc comment naming both must not trip the scan — `DocumentCanvasView+Editing.swift`'s " +
            "own warning about this trap does exactly that, so this case is live, not hypothetical")
        XCTAssertEqual(
            hits("/* @discardableResult func x() -> RichTextInputCaretOutcome */\nfunc example() {}\n"),
            [],
            "a BLOCK comment naming both must not trip it either")
    }
}
