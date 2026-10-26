import Foundation
import XCTest

/// The router-BODY boundary rule (created by Task 24; each family task 25-34 extends
/// `enabledWitnesses` with its own names as it lands). For every witness enabled below, its
/// declaration — found under `Sources/RichTextEditorUIKit/Canvas/` by a literal, exact signature
/// string — must have a body that is EXACTLY one statement of the shape `inputBackend.…`. This is the
/// mechanical form of "the witness is a one-line router" the whole Phase-4 schedule depends on: a
/// witness that grew a second statement, or that silently reverted to doing its own work instead of
/// forwarding to `inputBackend`, fails here — not only via the (separately maintained) router-spy
/// tests, which pin the SAME fact per-witness from the opposite direction (the backend side).
///
/// A FIXED, ever-growing allow-list, not a decreasing-baseline ratchet like R6/R7 in
/// `InputBackendSourceBoundaryTests.swift`: each family task ADDS names to `enabledWitnesses` as it
/// routes them; Phase 4 never un-routes a witness, so no entry is ever removed.
///
/// **TASK 34 CLOSED PHASE 4 AND ADDED NOTHING HERE — measured, and the zero is the interesting part.**
/// This sentence used to point at "Task 34's own final gate
/// (`LegacyRichTextInputBackend.pendingRoutingInventory.isEmpty`)" as the DIFFERENT, absolute check
/// this per-witness SHAPE rule complements. That gate no longer exists: the Set was empty from Task 33
/// on, so `.isEmpty` was already true and could not fail, and Task 34 deleted both the Set and the
/// funnel it belonged to. **There is no "absolute check" any more, and that is the accurate statement
/// rather than a gap.** Rule R20 in `InputBackendSourceBoundaryTests.swift` asserts the ABSENCE of that
/// machinery in the SOURCE — residue only; its fix round retracted the completion claim its first name
/// made, because reverting a real routing call site leaves R20 green. Phase-4 completion is checked
/// where it always actually was: this rule, R17, and the per-family router suites in
/// `T/InputBackend/Routers/`, each of which reddens when a witness stops forwarding.
/// Task 34's own family (spellchecking and annotations) contributed no entry to the list below because
/// it has NO `UITextInput`/`UIResponder` witness at all — its members are canvas-internal lifecycle
/// calls — so the count below is unchanged by the task that ended the phase. This rule remains the
/// per-witness shape check that runs from the moment a witness is routed, not only at the very end.
///
/// **SCOPE LIMIT — accessor-pair witnesses cannot be expressed here, and are therefore NOT covered by
/// this ratchet (recorded by Task 26, review m6).** `test_everyEnabledWitnessBodyIsAOneLineInputBackendForward`
/// requires the matched body to be exactly ONE statement. A routed `{ get set }` witness is two by
/// construction —
///
///     var selectedTextRange: UITextRange? {
///         get { inputBackend.selectedTextRange }
///         set { inputBackend.selectedTextRange = newValue }
///     }
///
/// — so adding it to `enabledWitnesses` would fail the rule for CORRECT code. Task 26 routed two such
/// witnesses (`selectedTextRange` and `inputDelegate`, `DocumentCanvasView+UITextInput.swift`) and added
/// neither. **Task 29/41's `markedTextStyle` is the same shape and will hit the same wall**, as will any
/// future `{ get set }` witness. **TASK 29 CONFIRMED IT**: it routed `markedTextStyle` and did not add
/// it here, for exactly this reason; `MarkedTextRouterTests
/// .test_markedTextStyle_routesEachAccessorToTheBackendExactlyOnce` (routing, per accessor) and
/// `.test_markedTextStyleGetterIsNilAndSetterIsANoOp` (value) are its cover. It added its other three.
///
/// What covers them instead, so the gap is a scope limit and not a hole: the router-SPY tests
/// (`T/InputBackend/Routers/SelectionRouterTests.swift`) assert the same fact from the backend side,
/// per accessor — `XCTAssertRoutesOnly` proves exactly one backend call, the exact member
/// (`selectedTextRange.get` / `.set` / `inputDelegate.get` / `.set`), the exact arguments, exact return
/// propagation, AND that the canvas did no work of its own. That is strictly more than this rule checks;
/// what it lacks is this rule's mechanical, per-file, source-as-text guarantee that nobody quietly grew
/// a second statement without also writing a test.
///
/// Whoever needs that guarantee for an accessor pair should extend `routedBody(forSignature:in:)` with a
/// get/set-aware shape (match the accessor bodies separately and apply `nonForwardingReason` to each)
/// rather than relaxing the one-statement rule for everyone — deliberately NOT done by Task 26, which
/// had no mandate to change a rule's mechanism, and recorded here rather than in a task report because
/// this file is where the next reader of the rule looks.
///
/// Signature strings are literal, exact source text (case- and whitespace-sensitive, single spaces
/// only) — deliberately NOT a general Swift-signature parser (this project has twice paid for a
/// "reads as enforcement, enforces nothing" extraction bug trying that shortcut for R10/R11; the
/// precedent for staying COARSE rather than fragile-precise used to be cited here as "R13's own doc
/// comment", but TASK 34 DELETED R13 — the lesson survives as a standing note in
/// `InputBackendSourceBoundaryTests.swift`, quoted at several rules there, and is simply: a coarse rule
/// that is honest about its coarseness beats a precise-looking one whose extraction silently finds
/// nothing). A family task
/// that reformats a witness's declaration must update its signature string here too — the positive
/// self-check below (`test_everyEnabledWitnessSignatureWasFound`) fails loudly, not silently, when a
/// signature drifts out of sync with the real source.
final class RouterWitnessBodyTests: XCTestCase {
    private struct Witness {
        let name: String
        let signature: String
    }

    /// Task 24 — Family 1 (document reads & position/range conversion), the eleven witnesses. Keyed by
    /// the SAME name strings the Phase-4 inventory Set used for these entries before Task 24 removed
    /// them, so the two lists read as the same eleven items from two independent angles — the inventory
    /// tracked "still stubbed", this tracks "now a one-line router". (That Set is GONE as of Task 34;
    /// its historical ledger is `+Unwitnessed.swift`. The keying convention below is unaffected — it
    /// only ever needed the names to be stable, not the Set to exist.)
    private static let enabledWitnesses: [Witness] = [
        Witness(name: "text(in:)",
                signature: "func text(in range: UITextRange) -> String?"),
        Witness(name: "beginningOfDocument",
                signature: "var beginningOfDocument: UITextPosition"),
        Witness(name: "endOfDocument",
                signature: "var endOfDocument: UITextPosition"),
        Witness(name: "tokenizer",
                signature: "var tokenizer: UITextInputTokenizer"),
        Witness(name: "textRange(from:to:)",
                signature: "func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange?"),
        Witness(name: "position(from:offset:)",
                signature: "func position(from position: UITextPosition, offset: Int) -> UITextPosition?"),
        Witness(name: "compare(_:to:)",
                signature: "func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult"),
        Witness(name: "offset(from:to:)",
                signature: "func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int"),
        Witness(name: "position(within:farthestIn:)",
                signature: "func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition?"),
        Witness(name: "characterRange(byExtending:in:)",
                signature: "func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange?"),
        Witness(name: "position(from:in:offset:)",
                signature: "func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition?"),
        // Task 25 — Family 2 (geometry), the eight witnesses. `closestPosition(to:)` and
        // `closestPosition(to:within:)` are exactly the collision-prone pair the Task-24 review's
        // Focal Point 4 named by name (one signature a literal PREFIX of the other) — safe here
        // because `routedBody`'s `range(of:)` match is over the FULL literal signature text, including
        // the parameter list, so "CGPoint) -> UITextPosition?" never appears as a substring of the
        // two-argument overload's "CGPoint, within range: UITextRange) -> UITextPosition?" text. The
        // NEW uniqueness assertion below (`test_everyEnabledWitnessSignatureWasFound`) is what actually
        // guards against a signature appearing more than once across the 67 `Canvas/*.swift` files,
        // which full-signature matching alone does not rule out.
        Witness(name: "baseWritingDirection(for:in:)",
                signature: "func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection"),
        Witness(name: "setBaseWritingDirection(_:for:)",
                signature: "func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange)"),
        Witness(name: "firstRect(for:)",
                signature: "func firstRect(for range: UITextRange) -> CGRect"),
        Witness(name: "caretRect(for:)",
                signature: "func caretRect(for position: UITextPosition) -> CGRect"),
        Witness(name: "selectionRects(for:)",
                signature: "func selectionRects(for range: UITextRange) -> [UITextSelectionRect]"),
        Witness(name: "closestPosition(to:)",
                signature: "func closestPosition(to point: CGPoint) -> UITextPosition?"),
        Witness(name: "closestPosition(to:within:)",
                signature: "func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition?"),
        Witness(name: "characterRange(at:)",
                signature: "func characterRange(at point: CGPoint) -> UITextRange?"),
        // Task 27a — Family 4's ROUTABLE half.
        //
        // **STALE CLAIM CORRECTED AT TASK 30's stale-reference sweep.** This note used to continue:
        // "The family's third witness, `insertText(_:)`, is deliberately absent: it is not routed
        // (deviation D35), and adding a name here for an unrouted witness would fail
        // `test_everyEnabledWitnessBodyIsAOneLineInputBackendForward` for correct code." That was true
        // when Task 27a wrote it and FALSE eight lines later once Task 27b landed — D35's ruling was
        // Option A, which routes `insertText(_:)` as a plain `legacyCanvas` forward, and its entry is
        // right below `replace(_:withText:)`. The reasoning it stated is sound and still applies to
        // genuinely unrouted witnesses (Task 30's `canPerformAction(_:withSender:)` is the current
        // example, noted at its own entry); only the member it named had moved on.
        //
        // `hasText` is a computed property with a single-expression body, so —
        // unlike Task 26's `selectedTextRange`/`inputDelegate` accessor PAIRS, which the scope limit
        // documented above excludes — it is expressible here, and it is the first property witness
        // in this list that is not one of Family 1's bare document-bounds reads.
        Witness(name: "hasText",
                signature: "var hasText: Bool"),
        Witness(name: "replace(_:withText:)",
                signature: "func replace(_ range: UITextRange, withText text: String)"),
        // Task 27b — Family 4's third witness. The signature `func insertText(_ text: String)` is NOT
        // a substring of the renamed body's `func legacyInsertText(_ text: String)` (the literal match
        // includes `func `), so the uniqueness self-check below distinguishes the two — which is
        // exactly what it is for: the router and the body it forwards to now live in the same file,
        // eight lines apart.
        Witness(name: "insertText(_:)",
                signature: "func insertText(_ text: String)"),
        // Task 28 — Family 5's single witness. Same shape and same near-collision as `insertText(_:)`
        // above: `func deleteBackward()` is NOT a substring of the renamed body's
        // `func legacyDeleteBackward()` (the literal match includes `func `), and the two live nine
        // lines apart in the same file, so the uniqueness self-check below is what distinguishes them.
        Witness(name: "deleteBackward()",
                signature: "func deleteBackward()"),
        // Task 29 — Family 6, THREE of its four witnesses. `markedTextStyle` is deliberately absent:
        // it is a `{ get set }` accessor pair, which the SCOPE LIMIT above already predicted would hit
        // this wall by name, and `MarkedTextRouterTests` covers it per-accessor from the backend side
        // instead. `markedTextRange` IS expressible — it is `{ get }`-only, so its routed body is a
        // single `inputBackend.markedTextRange` statement, and it is the second property witness here
        // after `hasText`. The same near-collision as `insertText(_:)`/`deleteBackward()` applies to
        // the two functions (`func setMarkedText(` is not a substring of `func legacySetMarkedText(`,
        // and `func unmarkText()` is not one of `func legacyUnmarkText()`), and each pair now lives a
        // few lines apart in the same file, so the uniqueness self-check below is what distinguishes
        // them.
        Witness(name: "markedTextRange",
                signature: "var markedTextRange: UITextRange?"),
        Witness(name: "setMarkedText(_:selectedRange:)",
                signature: "func setMarkedText(_ markedText: String?, selectedRange: NSRange)"),
        Witness(name: "unmarkText()",
                signature: "func unmarkText()"),
        // Task 30 — Family 7, SIX of its seven witnesses. `canPerformAction(_:withSender:)` is
        // deliberately absent, and its absence is by CONSTRUCTION rather than by oversight: it maps the
        // `Selector` to a `RichTextInputCommand` before asking the backend (the single permitted
        // representation translation, spelled out in the task brief), so it is not a one-line router and
        // adding it here would fail `test_everyEnabledWitnessBodyIsAOneLineInputBackendForward` for
        // CORRECT code — the same shape the SCOPE LIMIT above records for accessor pairs. Its cover is
        // `CommandRouterTests.test_canPerformAction_mapsAKnownSelectorAndAsksTheBackend` /
        // `…_mapsEveryOneOfTheSixEditActionSelectors` / `…_passesTheLegacyMenuItemAndSpellingSelectorsToSuper`,
        // which pin the mapping entry by entry from the backend side.
        //
        // Each of the five actions has the same near-collision as `insertText(_:)`/`deleteBackward()`:
        // its renamed body lives a few lines below it in the SAME file (`legacyCopy`/`legacyCut`/
        // `legacyPaste` in `+Clipboard.swift`, `legacySelect`/`legacySelectAll` in `+EditMenu.swift`),
        // and the literal match includes `func `, so `func copy(` is not a substring of
        // `func legacyCopy(`. `func select(_ sender: Any?)` is likewise not a substring of
        // `func selectAll(_ sender: Any?)` — the full parameter list is part of the literal. The
        // uniqueness self-check below is what distinguishes all of them; each was measured at exactly 1.
        //
        // `undoManager` is the THIRD property witness here (after `hasText` and `markedTextRange`) and
        // the first `override` of a `UIResponder` property. Its near-collisions are
        // `var undoManagerOverride: UndoManager?` and `var effectiveUndoManager: UndoManager?`, and
        // neither contains the literal `var undoManager: UndoManager?`.
        Witness(name: "copy(_:)",
                signature: "func copy(_ sender: Any?)"),
        Witness(name: "cut(_:)",
                signature: "func cut(_ sender: Any?)"),
        Witness(name: "paste(_:)",
                signature: "func paste(_ sender: Any?)"),
        Witness(name: "select(_:)",
                signature: "func select(_ sender: Any?)"),
        Witness(name: "selectAll(_:)",
                signature: "func selectAll(_ sender: Any?)"),
        Witness(name: "undoManager",
                signature: "var undoManager: UndoManager?"),
        // Task 31 — Family 8, THREE of its six witnesses. All three are get-only computed vars whose
        // routed body is a single `inputBackend.…` statement, so they are expressible here;
        // `canBecomeFirstResponder` and `isEditable` are the fourth and fifth property witnesses in this
        // list, and `canResignFirstResponder` is the first witness added that did not exist at all
        // before its family task (`UIResponder`'s inherited `true` was the pre-seam behaviour, which is
        // why adding an override returning `true` is behaviour-preserving).
        //
        // **THE OTHER THREE CANNOT BE ADDED, and this is a THIRD KIND of scope limit** — distinct from
        // the accessor-pair one at the top of this file (Task 26) and from Task 30's
        // `canPerformAction(_:withSender:)` (a representation translation). Here **the witness
        // legitimately keeps `super`**:
        //   * `becomeFirstResponder()` and `resignFirstResponder()` — the canvas still calls
        //     `super.become/resignFirstResponder()`; the backend owns only the ordering AROUND it. So
        //     each body is `super`, the success/failure branch, and TWO backend calls, not one.
        //   * `willMove(toWindow:)` — two statements, `super.willMove(toWindow:)` plus the router call.
        // Adding any of the three would fail
        // `test_everyEnabledWitnessBodyIsAOneLineInputBackendForward` for CORRECT code. Their cover is
        // `ResponderRouterTests`, which asserts the hook sequence per transition from the backend side —
        // including `test_becomeFirstResponder_stillCallsSuperOnTheCanvas`, which pins the very fact
        // that makes them inexpressible here.
        //
        // Near-collisions, checked the way every entry above is: `var canBecomeFirstResponder: Bool` and
        // `var canResignFirstResponder: Bool` each occur once under `Canvas/` (the `override ` prefix is
        // not part of the literal, and no other declaration shares the text); `var isEditable: Bool` is
        // NOT a substring of `RichTextInputEditPolicy`'s `let isEditable: Bool`, which lives under
        // `InputBackend/` and outside this scan anyway.
        Witness(name: "canBecomeFirstResponder",
                signature: "var canBecomeFirstResponder: Bool"),
        Witness(name: "canResignFirstResponder",
                signature: "var canResignFirstResponder: Bool"),
        Witness(name: "isEditable",
                signature: "var isEditable: Bool"),
        // Task 32 — Family 9 (touch interaction and selection). **EXACTLY ONE witness**, which is worth
        // stating because the family routes FIVE backend members. The other four have no canvas witness
        // at all: `installInteractions()` is called from `attach(to:)`, `removeInteractions()` and
        // `cancelActiveInteraction(reason:)` from `performDetachSteps()` (D18 — never from
        // `resignFirstResponder`), and `layoutDidChange(generation:)` is a notification raised from
        // inside `layoutContent()`, which is a large body and not a router.
        //
        // The task brief also named four MORE canvas members for this family
        // (`gestureRecognizerShouldBegin(_:)`, `gestureRecognizer(_:shouldReceive:)`,
        // `selectionContainerViewBelowText(for:)`, the `UIEditMenuInteractionDelegate` conformance) as
        // "canvas witnesses that forward one line into the backend". **None of them routes** — see
        // deviation D36 — so none appears here. A future reader looking for them finds this note rather
        // than an unexplained absence.
        Witness(name: "viewportDidChange()",
                signature: "func viewportDidChange()"),
        // Task 33 — Family 10 (floating cursor and autoscroll). **ALL THREE of the family's witnesses**,
        // the first family since Task 24/25 where the witness count and the routed-member count are the
        // same number. Each is a `UITextInput` requirement UIKit dispatches to the first responder, and
        // each routed body is a single `inputBackend.…` statement, so all three are expressible here.
        //
        // Near-collisions, checked the way every entry above is: each router now lives a few lines above
        // its own renamed body in `DocumentCanvasView+FloatingCursor.swift`, and the literal match
        // includes `func `, so `func beginFloatingCursor(at point: CGPoint)` is not a substring of
        // `func legacyBeginFloatingCursor(at point: CGPoint)` — the same construction Tasks 27b/28/29/30
        // relied on. The contract's own declarations
        // (`RichTextInputBackend.swift`) live under `InputBackend/` and are outside this scan.
        //
        // **DEVIATION D2 is visible in the signature string** — `updateFloatingCursor(at:)`, not
        // `(at:animated:)`. UIKit's real requirement has no `animated:`; the plan's spelling is the
        // deviation. `FloatingCursorRouterTests.test_updateFloatingCursorHasNoAnimatedParameter` pins
        // that at compile time, and this entry would fail
        // `test_everyEnabledWitnessSignatureWasFound` if the witness ever grew the parameter.
        Witness(name: "beginFloatingCursor(at:)",
                signature: "func beginFloatingCursor(at point: CGPoint)"),
        Witness(name: "updateFloatingCursor(at:)",
                signature: "func updateFloatingCursor(at point: CGPoint)"),
        Witness(name: "endFloatingCursor()",
                signature: "func endFloatingCursor()"),
    ]

    private static var canvasDir: URL {
        RepoLayout.uiKitSources.appendingPathComponent("Canvas")
    }

    /// Every `Canvas/*.swift` file, comment/string-stripped — kept as a PER-FILE list (not pre-joined)
    /// so a body's brace balance can never accidentally span a file boundary.
    private func canvasSources() -> [(url: URL, stripped: String)] {
        RepoLayout.swiftFiles(under: Self.canvasDir).map {
            (url: $0, stripped: SwiftSourceScan.stripCommentsAndStringLiterals((try? String(contentsOf: $0)) ?? ""))
        }
    }

    /// Finds `signature`'s first occurrence in `stripped`, then the balanced `{ … }` body immediately
    /// following it (skipping only whitespace/newlines between the signature and the opening brace —
    /// exactly the shape a routed computed member/function has). Returns the body's TRIMMED interior
    /// text, or `nil` if the signature was not found in this file (a different file, or a genuine
    /// absence).
    private func routedBody(forSignature signature: String, in stripped: String) -> String? {
        guard let sigRange = stripped.range(of: signature) else { return nil }
        var idx = sigRange.upperBound
        while idx < stripped.endIndex, stripped[idx].isWhitespace { idx = stripped.index(after: idx) }
        guard idx < stripped.endIndex, stripped[idx] == "{" else { return nil }
        var depth = 0
        var i = idx
        var close: String.Index?
        while i < stripped.endIndex {
            let ch = stripped[i]
            if ch == "{" { depth += 1 } else if ch == "}" {
                depth -= 1
                if depth == 0 { close = i; break }
            }
            i = stripped.index(after: i)
        }
        guard let close else { return nil }   // unbalanced braces — skip rather than loop forever
        let interior = stripped[stripped.index(after: idx)..<close]
        return interior.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The positive half: a rename or reformat of a witness's declaration must not make the main test
    /// below pass VACUOUSLY by simply finding nothing to check for that name.
    ///
    /// TASK 25 (Task-24 review Focal Point 4 / Minor 3, carried into this task's brief as a REQUIRED
    /// item) — widened from "found in at least one file" to "found in EXACTLY one file". The original
    /// shape took the FIRST match in `FileManager` enumeration order over all 67 `Canvas/*.swift`
    /// files and silently ignored every other match — the precise shape of R11's historical defect
    /// (one class's code attributed to its file-mate). All eleven Family-1 signatures, and all eight
    /// Family-2 ones added by this task, were verified to occur exactly once under `Canvas/` (no live
    /// defect today), but the risk was structural, not the count: an accidental duplicate declaration —
    /// a stale copy left after a refactor, or a second conformance in a different file — would have
    /// silently matched whichever file `FileManager` happened to enumerate first, attributing a PASS or
    /// FAIL to the wrong file entirely. Now a signature found in 0 or ≥2 files fails loudly, naming
    /// every matching file.
    ///
    /// TASK 25 FIX ROUND 1 (Minor, reviewer) — the first version of this widening counted matching
    /// FILES, not OCCURRENCES: two identical signatures declared inside the SAME file still collapsed
    /// to one "matching file" and `routedBody`'s `range(of:)` silently took the first of the two,
    /// unexercised by the original red-check (a temporary probe in a SEPARATE file). Counting total
    /// occurrences across all files (summed per file via `components(separatedBy:).count - 1`) catches
    /// both shapes — a duplicate in a different file (still reported, now with its per-file count too)
    /// and a duplicate within one file.
    func test_everyEnabledWitnessSignatureWasFound() {
        RepoLayout.assertResolved()
        let sources = canvasSources()
        XCTAssertFalse(sources.isEmpty, "no Canvas/*.swift sources found — this rule would pass VACUOUSLY")
        var offenders: [String] = []
        for witness in Self.enabledWitnesses {
            let perFileCounts: [(url: URL, count: Int)] = sources.map {
                ($0.url, $0.stripped.components(separatedBy: witness.signature).count - 1)
            }
            let totalCount = perFileCounts.reduce(0) { $0 + $1.count }
            switch totalCount {
            case 0:
                offenders.append("\(witness.name): signature not found anywhere under Canvas/ — a " +
                                 "rename/reformat would make the main test below pass VACUOUSLY for it")
            case 1:
                continue
            default:
                let breakdown = perFileCounts.filter { $0.count > 0 }
                    .map { "\($0.url.lastPathComponent)×\($0.count)" }.sorted()
                offenders.append("\(witness.name): signature found \(totalCount) times total " +
                                 "(\(breakdown)) — ambiguous, whether spread across files or " +
                                 "duplicated within one; the main test below would silently check " +
                                 "only the FIRST occurrence `range(of:)` finds")
            }
        }
        XCTAssertEqual(offenders, [], "signature-uniqueness violations: \(offenders)")
    }

    func test_everyEnabledWitnessBodyIsAOneLineInputBackendForward() {
        RepoLayout.assertResolved()
        let sources = canvasSources()
        var offenders: [String] = []
        for witness in Self.enabledWitnesses {
            guard let body = sources.compactMap({ routedBody(forSignature: witness.signature, in: $0.stripped) }).first else {
                offenders.append("\(witness.name): signature not found")
                continue
            }
            let lines = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard lines.count == 1, !body.contains(";") else {
                offenders.append("\(witness.name): body is not a single statement: \(body)")
                continue
            }
            guard let violation = nonForwardingReason(body) else { continue }
            offenders.append("\(witness.name): \(violation): \(body)")
        }
        XCTAssertEqual(offenders, [], "router-body violations: \(offenders)")
    }

    /// TASK 25 (Task-24 review Focal Point 4 / Minor 2, carried into this task's brief as a REQUIRED
    /// item) — tightens `hasPrefix("inputBackend.")` into a check that the body is NOTHING BUT a
    /// forward: either a bare `inputBackend.<property>` member access, or a single
    /// `inputBackend.<method>(…)` call whose OWN closing parenthesis is the very last character of the
    /// body. The original prefix-only check admitted a forward with a TRAILING TRANSFORMATION —
    /// `inputBackend.x() ?? ""`, `inputBackend.x() + 1`, a ternary over the forwarded value — because
    /// it only ever inspected the first 13 characters. That is not a theoretical shape: "preserve
    /// behavior by adjusting the forwarded value at the router" is exactly the temptation the D9
    /// `.zero`/`[]` translation in THIS family raises, and a family task that yielded to it (put the
    /// translation in the canvas router instead of the backend) would leave this gate green.
    ///
    /// TASK 25 FIX ROUND 1 (Minor, reviewer) — the trailing-transformation check left an ARGUMENT-side
    /// hole open: `inputBackend.caretRect(for: DocumentTextPosition(0))` satisfies "own close paren is
    /// last" just as well as a clean forward does, because the extra work happens INSIDE the argument
    /// list rather than after it. Closed by requiring the argument-list interior (between the call's
    /// own opening and closing paren) to contain NO further `(` at all — every genuine forward in this
    /// codebase passes bare parameter references and labels only (`for: range`, `from: position, in:
    /// direction, offset: offset`, …), never a nested call/initializer, so any `(` inside the argument
    /// list is itself the violation; no parameter-name matching is needed to detect it.
    ///
    /// Returns `nil` when the body is a clean forward, or a short reason string naming the violation.
    private func nonForwardingReason(_ body: String) -> String? {
        var content = Substring(body)
        if content.hasPrefix("return ") { content = content.dropFirst("return ".count) }
        guard content.hasPrefix("inputBackend.") else {
            return "body does not forward to inputBackend"
        }
        let afterPrefix = content.dropFirst("inputBackend.".count)
        guard let firstParen = afterPrefix.firstIndex(of: "(") else {
            // No call at all — must be a BARE member-access forward (e.g. `inputBackend.tokenizer`),
            // so every remaining character must be identifier-shaped. Anything else (an operator, a
            // space, a `?`) is a trailing transformation on a property forward.
            let isPlainIdentifier = !afterPrefix.isEmpty
                && afterPrefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            return isPlainIdentifier ? nil : "does not forward to inputBackend"
        }
        // A call: the method NAME (before the first paren) must itself be a plain identifier — no
        // trailing transformation could precede the very first `(` of a one-statement body starting
        // `inputBackend.`, but this also guards against a stray character sneaking in there.
        let methodName = afterPrefix[afterPrefix.startIndex..<firstParen]
        guard !methodName.isEmpty, methodName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            return "does not forward to inputBackend"
        }
        // Track paren depth from the first `(` to find where THIS call's own closing paren sits. If
        // that closing paren is not the LAST character of the body, something follows it — a trailing
        // `?? default`, a `+ 1`, a ternary, or a second chained call — none of which is a pure forward.
        var depth = 0
        var closeIndex: String.Index?
        var nestedParenCount = 0
        var i = firstParen
        while i < afterPrefix.endIndex {
            let ch = afterPrefix[i]
            if ch == "(" {
                if depth >= 1 { nestedParenCount += 1 }   // an ARGUMENT-side call/initializer
                depth += 1
            } else if ch == ")" {
                depth -= 1
                if depth == 0 { closeIndex = i; break }
            }
            i = afterPrefix.index(after: i)
        }
        guard let closeIndex, afterPrefix.index(after: closeIndex) == afterPrefix.endIndex else {
            return "does not forward to inputBackend"
        }
        guard nestedParenCount == 0 else {
            return "forwards a TRANSFORMED argument, not the witness's own parameter (a nested call " +
                   "inside the argument list)"
        }
        return nil
    }
}
