#if canImport(UIKit)
@testable import RichTextEditorUIKit

/// PERMANENT test-facing names for the backend's UIKit identity types.
///
/// The production types are `LegacyTextPosition` / `LegacyTextRange` / `LegacySelectionRect`, owned
/// by the backend (`S/InputBackend/Legacy/LegacyTextPosition.swift`) and opaque outside it — the spec's
/// "UIKit identity is backend-owned", enforced by
/// `InputBackendSourceBoundaryTests.test_noBackendPositionDowncastsOutsideBackend` (R6).
///
/// **These aliases exist so Task 44 edits ZERO UIKit test files (deviation D22), and that is not
/// cosmetic.** Phase 6 gate item 3 asserts that
/// `git diff <baseline>..HEAD -- Tests/RichTextEditorUIKitTests/Characterization/` shows no change to
/// an expectation after its creating commit, and the Task 3/4/5 characterization suites build
/// `DocumentTextRange(DocumentTextPosition(…))` throughout. A mechanical rename there would make the
/// gate report changes and force manual reasoning to clear them — on the one instrument the whole plan
/// has protected since Task 1. Measured before the rename: **398 mentions across `Tests/`**
/// (`grep -rn 'DocumentTextPosition\|DocumentTextRange\|DocumentSelectionRect' Tests | wc -l`), against
/// 88 in `Sources/`. Do not "clean these up".
///
/// All THREE are load-bearing today:
///   * `DocumentTextPosition` / `DocumentTextRange` — the characterization and router suites, throughout.
///   * `DocumentSelectionRect` — `T/TextPositionTests.swift`, `T/Support/SpyRichTextInputBackend.swift`'s
///     `sentinelSelectionRect`, and referenced by `T/Characterization/GeometryWitnessMatrixTests`.
///
/// They are TEST-TARGET-ONLY, so R6 (which scans `Sources/` only) is unaffected: no production file may
/// name either the alias or the underlying type outside `S/InputBackend/`.
typealias DocumentTextPosition = LegacyTextPosition
typealias DocumentTextRange = LegacyTextRange
typealias DocumentSelectionRect = LegacySelectionRect
#endif
