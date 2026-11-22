#if canImport(UIKit)
import UIKit
import RichTextEditorDifferentialHarness
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Task D4b — **the InputDec half of the differential host.**
///
/// This is the InputDec sibling of `TelegramDifferentialInputFactory.swift` (stage 1, Task 9b),
/// built by the SAME differential corpus (68 scenarios / 612 transactions captured against stock
/// UIKit) for the first time against the `.inputDec` backend rather than legacy.
///
/// ## Why this is a SEPARATE factory file, not a change to Task 9b's
///
/// The brief that seeded this task described a FIFTH `IDTextInputHostKind` case
/// (`IDTextInputHostKindTelegramInputDec`) added to `IDTextInputScenario.h`. That header is
/// vendored byte-for-byte (`Tests/DifferentialSupport/PROVENANCE.md`: "DO NOT EDIT, DO NOT
/// REFORMAT, DO NOT FIX WARNINGS", md5-pinned) and the enum in the CURRENT tree has exactly three
/// cases (`Stock`, `Reference`, `Minimal`) — there never was a fourth `Telegram` case to append
/// after, and `IDTextInputTestHost.m`'s own `comparesAnnotations`/`observedTextStorage` machinery
/// (Task 9b/9c) is ALREADY fully generic over whatever `UIView<UITextInput>` the registered Swift
/// factory hands back — it does not branch on legacy vs. InputDec at all. So editing either vendored
/// or already-generic non-vendored ObjC would have bought nothing and would have violated the
/// "never edit a VENDOR/PROVENANCE-owned path" constraint for no benefit.
///
/// **The better answer, since `IDTextInputHostKindReference`/`Minimal` are already "a second,
/// independently constructed instance of the SAME editor, not a second implementation"
/// (`TelegramDifferentialInputFactory`'s own doc comment): install a DIFFERENT factory that builds
/// InputDec-backed instances for those same two slots.** `IDTextInputTestHost` stores exactly one
/// process-global `IDTelegramFactory`; `LegacyDifferentialTests` installs `TelegramDifferentialInputFactory`
/// in its `setUp()`/`tearDown()`, and `IDDifferentialTests` installs THIS ONE the same way — the two
/// suites never run concurrently (XCTest serializes test methods within a process), so there is no
/// shared-state hazard. No vendored file changes, `IDTextInputTestHost.m` is untouched, and the
/// `Reference, Minimal` slots become "two independently constructed InputDec editors" for exactly
/// the same determinism/execution-order reason stage 1 documented for legacy.
///
/// ## Why the raw canvas, not `RichTextEditorView`
///
/// `RichTextEditorView.init(frame:)` hardcodes `RichTextInputCanvasFactory.make(.legacy)` — there is
/// no public (or internal-but-reachable-from-here) way to make the façade build an InputDec-backed
/// canvas. Rather than widen production API surface for a test (the same call Task 9b's own header
/// comment rejected for `@objc`), this factory builds the canvas directly via
/// `RichTextInputCanvasFactory.make(.inputDecRequired)` and drives it exactly the way
/// `RichTextInputBackendHarness`'s own `makeBackendHarness(backend: .inputDec)` factory already does
/// elsewhere in this test target — a proven, already-exercised construction path, not a new one.
/// `.inputDecRequired`, never `.inputDecIfSupported`: a silent fallback to legacy here would make
/// this whole task re-test stage 1 under a name that claims otherwise.
///
/// ## The crash guard `.inputDecRequired` alone does not give you
///
/// `RichTextInputCanvasFactory.make(.inputDecRequired)` calls `preconditionFailure` — a hard,
/// un-catchable trap — when `IDTextEditorBackend.isSupported()` is false. Task D4b's own brief
/// requires running this corpus on an UNCERTIFIED OS band (decision 2's whole point), where
/// `isSupported()` may legitimately be false. So this factory checks `isSupported()` itself FIRST
/// and returns a declined `NSError` instead of ever reaching `.inputDecRequired` when it would trap
/// — an unsupported runtime must fail the SCENARIO (visible in the family report as an execution
/// failure), never crash the whole XCTest process.
///
/// ## The other crash guard: kernel-witness contract violations
///
/// Every `.inputDec` witness can call `IDTextEditorBackend.reportKernelFailure(_:witness:)` →
/// `RichTextInputContractViolation.report(...)`, which is `assertionFailure()` in DEBUG unless a
/// reporter is installed — the same guard `makeBackendHarness` installs for every OTHER `.inputDec`
/// suite in this target. `install()` below installs the identical reporter (log, don't trap) and
/// `uninstall()` clears it, matching that established convention exactly.
enum TelegramInputDecDifferentialInputFactory {

    /// The vendored host's own geometry, reproduced from `TelegramDifferentialInputFactory` so both
    /// factories build under identical conditions — the only planned difference between a legacy run
    /// and this one is the backend.
    static let editorFrame = CGRect(x: 35, y: 120, width: 320, height: 480)
    static let textInsets = UIEdgeInsets(top: 11, left: 9, bottom: 13, right: 9)

    static func install() {
        RichTextInputContractViolation.reporter = { message in
            NSLog("RichTextInput contract violation (recorded, not trapped, by the D4b differential "
                 + "factory): %@", message)
        }
        IDTextInputTestHost.id_setTelegramInputFactory { kind, scenario, errorOut in
            MainActor.assumeIsolated {
                build(kind: kind, scenario: scenario, errorOut: errorOut)
            }
        }
    }

    static func uninstall() {
        IDTextInputTestHost.id_setTelegramInputFactory(nil)
        RichTextInputContractViolation.reporter = nil
    }

    // MARK: - Construction

    /// `@MainActor`, mirroring `RichTextInputCanvasFactory`'s own requirement (its doc comment: "a
    /// NONISOLATED make(_:) fails to compile under this package's concurrency checking"). The
    /// enclosing closure crosses into this isolation via `MainActor.assumeIsolated` in `install()`
    /// above — every real caller (the vendored runner, driven from an `@MainActor` XCTestCase test
    /// method) already runs on the main thread, exactly the same bridge
    /// `DocumentCanvasView.deinit` uses for its own `@MainActor` `detach()` call.
    @MainActor
    private static func build(kind: IDTextInputHostKind,
                              scenario: IDTextInputScenario,
                              errorOut: NSErrorPointer) -> IDTelegramInputHandle? {
        guard kind != .stock else {
            errorOut?.pointee = error("the InputDec factory was asked for the stock host kind; "
                                      + "the host builds stock itself, verbatim from the original")
            return nil
        }

        guard #available(iOS 17.0, *) else {
            errorOut?.pointee = error(
                "IDTextEditorBackend requires iOS 17.0+ (decision 2's floor); the running OS is "
                + "older, so this scenario cannot be driven against the ID backend at all")
            return nil
        }
        guard IDTextEditorBackend.isSupported() else {
            errorOut?.pointee = error(
                "IDTextEditorBackend.isSupported() == false on this runtime. Declining rather than "
                + "calling .inputDecRequired, which would preconditionFailure (an un-catchable trap) "
                + "here — an unsupported OS band must fail the scenario, not crash the process.")
            return nil
        }

        let canvas = RichTextInputCanvasFactory.make(.inputDecRequired)
        canvas.frame = editorFrame
        canvas.contentMargins = textInsets

        // Same spelling as `TelegramDifferentialInputFactory`: the canvas's own trait setters are
        // no-ops by design, and `isSpellCheckingEnabled` is the one façade knob that actually
        // reaches the editor. `UITextSpellCheckingTypeYes == 2`, `No == 1`, default (0, absent) is
        // treated as ON, matching `UITextView`.
        let spellChecking = (scenario.initialTraits["spellCheckingType"] as? NSNumber)?.intValue ?? 0
        canvas.isSpellCheckingEnabled = (spellChecking != 1)

        // Suppress the software keyboard exactly like the vendored host's own stock branch and
        // Task 9b's legacy factory: a 1x0 view goes in through the canvas's own `customInputView`.
        canvas.customInputView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0))

        // One top-level paragraph per line of `initialText` — identical to the legacy factory and
        // the vendored host's own `attributedBlocksFromCanonical:`.
        let lines = scenario.initialText.components(separatedBy: "\n")
        canvas.setBlocks(lines.map {
            .paragraph(ParagraphBlock(id: BlockID.generate(), runs: [TextRun(text: $0)]))
        }, width: editorFrame.width)
        canvas.layoutContent()

        guard let range = canvas.textRange(from: canvas.beginningOfDocument,
                                           to: canvas.endOfDocument),
              let projected = canvas.idAttributedText(in: range),
              projected.string == (canvas.text(in: range) ?? "") else {
            errorOut?.pointee = error(
                "the ID-backed canvas's attributed projection does not reproduce its own canonical "
                + "text for scenario \(scenario.identifier); a storage-derived comparison built on "
                + "it would be reading the wrong characters")
            return nil
        }

        return IDTelegramInputHandle(
            input: canvas,
            // `ownerView: nil` — the canvas is its own owner (mirrors `makeBackendHarness`'s
            // direct-canvas construction); there is no separate façade view to wrap it in, unlike
            // the legacy factory's `RichTextEditorView`.
            ownerView: nil,
            attributedTextProjection: { [weak canvas] range in canvas?.idAttributedText(in: range) },
            // `blockTexts` reuses Task 9c's `differentialTopLevelBlockTexts()` UNCHANGED — it walks
            // `boxes`/`leafRegions()` directly and never touches `inputBackend` or a `UITextRange`
            // at all, so it is already backend-neutral. `typingAttributes` needs the SAME
            // backend-neutral range conversion as the projection above — see `idAttributedText(in:)`'s
            // doc comment for why `differentialTypingAttributes(at:)` (Task 9c's original, built on
            // `LegacyTextIdentity`) cannot be reused verbatim here.
            blockTexts: { [weak canvas] in canvas?.differentialTopLevelBlockTexts() },
            typingAttributes: { [weak canvas] range in canvas?.idTypingAttributes(at: range) },
            inlineTraitToggle: { [weak canvas] name in
                guard let canvas else { return false }
                switch name {
                case "bold": canvas.toggleBold()
                case "italic": canvas.toggleItalic()
                case "underline": canvas.toggleUnderline()
                case "strikethrough": canvas.toggleStrikethrough()
                default: return false
                }
                return true
            })
    }

    private static func error(_ description: String) -> NSError {
        NSError(domain: IDTextInputTestHostErrorDomain, code: 1,
                userInfo: [NSLocalizedDescriptionKey: description])
    }
}

/// The backend-neutral twins of `TelegramDifferentialInputFactory`'s Task 9c range-projection
/// helpers, found necessary while wiring this factory up (Task D4b) — NOT a divergence of the
/// production `.inputDec` backend, a gap in the LEGACY-only test-harness plumbing stage 1 wrote.
///
/// `TelegramDifferentialInputFactory.legacyAttributedText(in:)` / `differentialTypingAttributes(at:)`
/// both open a `UITextRange` via `LegacyTextIdentity.globalRange(of:)`, which — BY DESIGN (R6: "no
/// file outside `S/InputBackend/` may name or downcast a backend's identity type") — downcasts to
/// the LEGACY backend's own opaque `LegacyTextRange` class and returns `nil` for anything else. Under
/// `.inputDec` the canvas's ranges are minted by the vendored kernel (`TGRichTextInputDecRange`), so
/// that downcast fails on EVERY call, `legacyAttributedText(in:)` returns `nil` for the whole
/// document, and this factory's own sanity guard would reject every scenario before a single
/// transaction ran — the anti-vacuity trap this task was warned about, just one layer earlier than
/// expected (in construction, not in the corpus itself).
///
/// ## Why NOT a plain `offset(from: beginningOfDocument, to:)` shift
///
/// The first cut computed `offset(from: beginningOfDocument, to: X)` (backend-neutral by
/// construction — every backend must answer the real `UITextInput.offset(from:to:)` witness
/// correctly) and fed it straight to `legacyAttributedText(globalFrom:globalTo:)` as an absolute
/// structural offset. MEASURED to be WRONG, directly: for a single paragraph "Hello world" (11
/// chars), `offset(from: beginningOfDocument, to: endOfDocument)` returned `11`, but the box model's
/// own `documentSize` is `13` and the paragraph's real leaf region is `globalStart: 1, length: 11` —
/// i.e. the CORRECT absolute structural span is `[1, 12]`, and the kernel's relative offset is the
/// TRUE structural offset MINUS the kernel's own idea of `beginningOfDocument`, which — unlike
/// Legacy's `beginningOfDocument` (`legacySnapToRenderable(0, forward: true)`, snapped explicitly
/// onto the structural axis's renderable position `1`) — is `kernelInput.beginningOfDocument`
/// UNTOUCHED, i.e. the kernel's own axis, zero-based in ITS OWN terms. This is exactly the
/// axis-conversion class `DIVERGENCES.md` already names ("the private controller hands us a
/// PLAIN-TEXT-axis range while our bridge assumed STRUCTURAL") — found here for the FIRST time in
/// this task's own test-construction code, not the production backend. The shift is not even a flat
/// constant: it is Telegram's own 2-slot-per-paragraph-boundary convention (`CLAUDE.md`'s
/// "Verification traps": "a top-level paragraph boundary occupies TWO position slots where the text
/// projection emits one '\n'") compounding by one MORE unit per boundary crossed — a flat `+1` is
/// only correct for a single-paragraph document, and 58 of the corpus's 68 scenarios cross a
/// boundary, so a flat shift would have been silently wrong for the majority of the corpus.
///
/// ## The fix: calibrate through PLAIN TEXT, which both axes already agree on
///
/// Both `canvas.text(in:)` (kernel-driven, confirmed correct — Task D4b measured it returning the
/// exact seeded text) and the canvas-level `legacyPlainText(globalFrom:globalTo:)` (structural-axis,
/// backend-agnostic) apply the IDENTICAL "\n"-at-a-crossed-top-level-paragraph-boundary rule
/// (`DocumentCanvasView+UITextInput.swift`'s own doc comment on `legacyPlainText` states it
/// verbatim). So a PLAIN-TEXT LENGTH from document start is a value both axes compute identically —
/// it is the one currency this conversion does not have to guess at. `idStructuralOffset(forPlainTextLength:)`
/// finds the smallest structural offset whose `legacyPlainText` from 0 reaches that length (a linear
/// scan over `documentSizeValue`, which is small — a handful to a few dozen structural slots for this
/// corpus's scenarios — run once per checkpoint capture, not per field comparison). This needs no
/// knowledge of the kernel's internal axis at all, so it cannot be fooled by a boundary-dependent
/// shift the way the `offset(from:to:)` shortcut was.
///
/// **`blockTexts` needed NO such fix.** `differentialTopLevelBlockTexts()` (Task 9c) walks `boxes`/
/// `leafRegions()` directly via `region.globalStart`/`.length` and never touches `inputBackend` or a
/// `UITextRange` at all — it was already backend-neutral.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The smallest structural offset `S` (in `0...documentSizeValue`) such that
    /// `legacyPlainText(globalFrom: 0, globalTo: S)` has reached `target` UTF-16 units — i.e. the
    /// structural-axis position that starts the SAME plain-text length the kernel's own axis would
    /// report for the equivalent position. Monotonic non-decreasing in `S` (each additional
    /// structural slot contributes zero or more plain-text characters), so a linear scan suffices
    /// and always terminates with a valid answer for any `target` in range.
    func idStructuralOffset(forPlainTextLength target: Int) -> Int {
        guard target > 0 else { return 0 }
        let hi = documentSizeValue
        guard hi > 0 else { return 0 }
        for candidate in 0...hi {
            let length = (legacyPlainText(globalFrom: 0, globalTo: candidate) ?? "").utf16.count
            if length >= target { return candidate }
        }
        return hi
    }

    /// Converts an opaque `UITextRange` (minted by WHATEVER backend is active) to a structural
    /// `(from, to)` pair by round-tripping through plain-text length — see the file-level doc
    /// comment above for why this, and not a raw `offset(from:to:)` shift, is correct.
    func idNeutralGlobalRange(of range: UITextRange) -> (from: Int, to: Int)? {
        guard let startRange = textRange(from: beginningOfDocument, to: range.start),
              let endRange = textRange(from: beginningOfDocument, to: range.end) else { return nil }
        let startLength = (text(in: startRange) ?? "").utf16.count
        let endLength = (text(in: endRange) ?? "").utf16.count
        let a = idStructuralOffset(forPlainTextLength: min(startLength, endLength))
        let b = idStructuralOffset(forPlainTextLength: max(startLength, endLength))
        return (a, b)
    }

    /// The ID-backend twin of `legacyAttributedText(in:)`.
    func idAttributedText(in range: UITextRange) -> NSAttributedString? {
        guard let global = idNeutralGlobalRange(of: range) else { return nil }
        return legacyAttributedText(globalFrom: global.from, globalTo: global.to)
    }

    /// The ID-backend twin of `differentialTypingAttributes(at:)`.
    func idTypingAttributes(at range: UITextRange) -> [NSAttributedString.Key: Any]? {
        guard let global = idNeutralGlobalRange(of: range) else { return nil }
        return typingAttributesAtGlobal(global.from)
    }
}
#endif
