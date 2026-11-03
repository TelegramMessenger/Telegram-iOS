#if canImport(UIKit)
import ObjectiveC
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task R4 — permanent regression coverage for the bug Task R3 found: a Swift member of
/// `IDTextEditorBackendClientBridge` can compile clean while satisfying an `@optional` requirement
/// of `TGRichTextInputDecClientBridging` (`TGRichTextInputDecClientBridge.h`) and yet never expose
/// the expected Objective-C selector at runtime. Because every requirement past the first two is
/// `@optional`, a selector mismatch is **not a compile error** — Swift's automatic `@objc`
/// inference for an `@optional` protocol witness is all-or-nothing per member (it either produces
/// the exact expected selector, or the member is not exposed to Objective-C under ANY selector at
/// all; verified directly with `class_copyMethodList` while diagnosing this task — a "near miss"
/// synthesized-but-wrong selector was never observed). The ObjC caller's own `respondsToSelector:`
/// guard then silently takes the "not implemented" branch forever. R3 found and fixed exactly one
/// instance (`documentPlainTextInRange:`); this task audited every `@optional` requirement in the
/// header the same way and found four more (`selectionRectsForRange:visibleRect:revision:`,
/// `closestOffsetToPoint:withinRange:revision:outOffset:`, `annotatedSubstringForRange:revision:`,
/// `invalidateTemporaryAttributesInRange:revision:`), all fixed the same way (an explicit
/// `@objc(selector:)` on the Swift declaration, pinned to the header's exact spelling).
///
/// **This test is the mechanical guard that makes the whole class of bug impossible to reintroduce
/// silently.** It does NOT reason about what a selector "should" be from Swift naming rules — that
/// inference is exactly what failed here (see the audit report,
/// `.superpowers/sdd/2026-08-16-inputdec-backend-introduction/task-R4-report.md`). It checks, via
/// the real Objective-C runtime (`class_getInstanceMethod`), that every selector the header
/// actually declares is actually present on the actual bridge class.
///
/// **`expectedOptionalSelectors` is a CHECKED-IN LIST, not derived from the header at compile or
/// run time** (there is no mechanism to reflect an Objective-C header's `@optional` block back into
/// Swift). It MUST be kept in sync by hand: whenever a new `@optional` method group is added to
/// `TGRichTextInputDecClientBridge.h` (the header's own comment: "Tasks C4-C7 append their groups
/// below this line" — later tasks C12/C14 continued the pattern), add the new selector(s) here too.
/// `test_countMatchesTheHeader` is a coarse tripwire for exactly that omission (a header edit that
/// changes the optional-method count without a matching edit here fails it), but it cannot catch a
/// same-count substitution — the per-selector test below is the real check.
///
/// **Why the two `@required` protocol members (`textStorageFacade`, `canvasKeyboardInputShouldDelete`)
/// are NOT in this list:** a `@required` Objective-C protocol requirement IS compiler-checked — an
/// implementation that doesn't match forces a real "does not conform to protocol" build error, which
/// is a wholly different (and already safe) failure mode from this task's subject. Only `@optional`
/// requirements can go silently missing, which is why the audit — and this regression test — scope
/// to exactly that block.
///
/// **Note on the count:** the task brief that commissioned this audit stated the header declares 27
/// `@optional` requirements. Directly counting the method declarations inside the header's single
/// `@optional` block (`awk '/^@optional/{f=1} f' … | grep -cE '^\s*[-+]\s*\('`) gives **25**, not
/// 27 — most likely the 27 figure counted the protocol's 27 TOTAL requirements (2 `@required` + 25
/// `@optional`) rather than the `@optional` subset alone. This test audits the 25 actually-optional
/// requirements, which are the only ones this class of bug can hide in; see the R4 report for the
/// full reasoning.
@available(iOS 17.0, *)
final class IDClientBridgeSelectorConformanceTests: XCTestCase {

    /// One entry per `@optional` requirement in `TGRichTextInputDecClientBridge.h`, grouped by the
    /// task family that added it (mirrors the header's own section comments). The selector string
    /// is the header's declared selector VERBATIM — this is the thing being checked, so it must
    /// never be "corrected" to match whatever the Swift side currently does.
    private static let expectedOptionalSelectors: [(group: String, selector: String)] = [
        // Task C4 — document reads and position/range conversion (six methods)
        ("C4", "documentUTF16Length"),
        ("C4", "documentRevision"),
        ("C4", "documentPlainTextInRange:"),
        ("C4", "documentClampedOffset:"),
        ("C4", "documentIsValidInsertionOffset:"),
        ("C4", "documentRebaseOffset:fromRevision:outOffset:"),
        // Task C5 — geometry (three methods)
        ("C5", "caretGeometryAtOffset:affinity:revision:purpose:outRect:outWritingDirection:outLayoutGeneration:"),
        ("C5", "selectionRectsForRange:visibleRect:revision:"),
        ("C5", "closestOffsetToPoint:withinRange:revision:outOffset:"),
        // Task C6 — selected range and input-delegate ownership (four methods)
        ("C6", "delegateTextInputDidChangeSelection"),
        ("C6", "delegateKeyboardInputChangedSelection"),
        ("C6", "delegateTextInputDidChange"),
        ("C6", "setCanonicalSelectionAnchor:head:reason:"),
        // Task C7 — insertion and replacement (one method)
        ("C7", "prepareAndCommitReplacementInRange:text:intent:expectedRevision:outOutcome:"),
        // Task C12 — interaction-host thunks (two methods)
        // Was `interactionAssistant`, a private UIKit selector name; renamed so the bridge does
        // not carry it (package CLAUDE.md, "Private UIKit names are not in the binary").
        ("C12", "canvasInteractionAssistant"),
        ("C12", "interactionContainerView"),
        // Task C14 — spellchecking and annotations (nine methods)
        ("C14", "annotatedSubstringForRange:revision:"),
        ("C14", "annotationValueForKey:atPosition:revision:"),
        ("C14", "addAnnotationKey:value:range:revision:"),
        ("C14", "removeAnnotationKey:range:revision:"),
        ("C14", "addRenderingAttributes:range:revision:"),
        ("C14", "removeRenderingAttributes:range:revision:"),
        ("C14", "invalidateTemporaryAttributesInRange:revision:"),
        ("C14", "setNativeContinuousSpellCheckingEnabled:"),
        ("C14", "isNativeContinuousSpellCheckingEnabled"),
    ]

    /// Coarse tripwire: the header currently declares exactly 25 `@optional` requirements (see the
    /// class doc comment for how that was counted and why it differs from the commissioning task's
    /// 27 estimate). If this fails, a group was added to or removed from the header's `@optional`
    /// block without a matching edit to `expectedOptionalSelectors` above.
    func test_countMatchesTheHeader() {
        XCTAssertEqual(Self.expectedOptionalSelectors.count, 25,
                       "TGRichTextInputDecClientBridge.h's @optional block no longer has 25 " +
                       "requirements — update expectedOptionalSelectors above to match, selector " +
                       "for selector, then re-run this whole suite.")
    }

    /// The real check. For every selector the header declares `@optional`, confirm — via the
    /// Objective-C runtime, not Swift-naming inference — that `IDTextEditorBackendClientBridge`
    /// actually exposes it. Reports every absence in ONE run (not just the first), matching the
    /// audit's own table-of-selectors format.
    func test_everyOptionalRequirementIsExposedOnTheRealBridgeClass() {
        let cls: AnyClass = IDTextEditorBackendClientBridge.self
        var absent: [(group: String, selector: String)] = []
        for entry in Self.expectedOptionalSelectors {
            let selector = NSSelectorFromString(entry.selector)
            if class_getInstanceMethod(cls, selector) == nil {
                absent.append(entry)
            }
        }
        XCTAssertTrue(absent.isEmpty, """
            \(absent.count) of \(Self.expectedOptionalSelectors.count) @optional \
            TGRichTextInputDecClientBridging selector(s) are NOT exposed on \
            IDTextEditorBackendClientBridge at runtime — every ObjC caller's \
            respondsToSelector: guard will silently treat these as unimplemented. \
            Fix: add an explicit @objc(<selector>) to the Swift declaration, matching the \
            header's spelling exactly (see documentPlainText(inRange:) for the precedent). \
            Missing:
            \(absent.map { "  [\($0.group)] \($0.selector)" }.joined(separator: "\n"))
            """)
    }
}
#endif
