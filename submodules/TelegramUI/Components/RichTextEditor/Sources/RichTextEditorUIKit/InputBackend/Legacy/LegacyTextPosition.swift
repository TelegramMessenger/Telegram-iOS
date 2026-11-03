#if canImport(UIKit)
import UIKit

// MARK: - The legacy backend's UIKit identity objects
//
// TASK 44 moved this file here from `S/Input/DocumentTextPosition.swift` and renamed all three types
// (`DocumentTextPosition`/`DocumentTextRange`/`DocumentSelectionRect` → `Legacy…`). Both halves are
// load-bearing and neither is cosmetic:
//
//  * **The MOVE** is what makes the spec's "UIKit identity is backend-owned / opaque outside the
//    active backend" checkable by path. `test_noBackendPositionDowncastsOutsideBackend` (R6) asserts
//    that no file outside `S/InputBackend/` mints, unwraps or even NAMES one of these three types.
//    Before this task eight files did, including the public facade — which is the violation D19 and
//    the Task 44 brief both open with.
//  * **The RENAME** is what stops the next reader from treating them as document-model types. They
//    are not: they are UIKit protocol currency (`UITextPosition`/`UITextRange`/`UITextSelectionRect`
//    subclasses) belonging to ONE backend implementation, `LegacyRichTextInputBackend`. A second
//    backend (stage 2's InputDec port) will have its own, and nothing outside a backend should be
//    able to tell which one is active.
//
// The old names survive as PERMANENT test-target typealiases in
// `T/Support/LegacyIdentityTestAliases.swift` (deviation D22), so this task edits no UIKit test file
// and Phase 6 gate item 3's characterization diff stays empty. See that file's own comment.

/// A position = a UTF-16 offset within the active block (Phase 1 is single-block).
@available(iOS 13.0, *)
final class LegacyTextPosition: UITextPosition {
    let offset: Int
    init(_ offset: Int) { self.offset = offset }
}

@available(iOS 13.0, *)
final class LegacyTextRange: UITextRange {
    let from: LegacyTextPosition
    let to: LegacyTextPosition
    init(_ from: LegacyTextPosition, _ to: LegacyTextPosition) { self.from = from; self.to = to }
    override var start: UITextPosition { from }
    override var end: UITextPosition { to }
    override var isEmpty: Bool { from.offset == to.offset }
}

@available(iOS 13.0, *)
final class LegacySelectionRect: UITextSelectionRect {
    private let _rect: CGRect
    private let _containsStart: Bool
    private let _containsEnd: Bool
    init(rect: CGRect, containsStart: Bool, containsEnd: Bool) {
        _rect = rect; _containsStart = containsStart; _containsEnd = containsEnd
    }
    override var rect: CGRect { _rect }
    override var writingDirection: NSWritingDirection { .leftToRight }
    override var containsStart: Bool { _containsStart }
    override var containsEnd: Bool { _containsEnd }
    override var isVertical: Bool { false }
}

// MARK: - The identity surface the rest of the package is allowed to use

/// **The ONLY sanctioned way for code outside `S/InputBackend/` to obtain or interpret one of the
/// legacy backend's UIKit identity objects.**
///
/// R6 forbids the canvas layer from naming, minting or unwrapping `LegacyTextPosition` /
/// `LegacyTextRange` / `LegacySelectionRect`. It does NOT forbid the canvas from asking for a caret
/// rect or setting a selection — it forbids it from *knowing what shape the identity object is*. This
/// namespace is where that knowledge stays: every member takes and returns either a plain `Int` pair
/// or the neutral UIKit protocol type (`UITextPosition` / `UITextRange`) the canvas has to handle
/// anyway as a `UITextInput` conformer.
///
/// **Why a static namespace rather than members on `RichTextInputBackend`.** These four operations
/// are pure, stateless conversions between an `Int` offset and a value-like wrapper object — the
/// legacy identity types carry no backend state whatsoever (read their declarations above: one `Int`,
/// or two of them). Putting them on the backend protocol would add four requirements that
/// `SpyRichTextInputBackend` — a TEST file this task must not edit (D22) — would have to implement,
/// and would imply a per-instance dependence that does not exist. The name carries the `Legacy`
/// prefix precisely so a stage-2 backend's identity surface is a DIFFERENT namespace and the call
/// sites that must change are greppable.
///
/// **`LegacyTextIdentity` deliberately does not match R6's own pattern** (`Legacy` is followed by
/// `TextIdentity`, not `TextPosition`/`TextRange`/`SelectionRect`), and
/// `test_theIdentityLeakScanActuallyDetects_R6` pins that: if the rule is ever "simplified" to a bare
/// `Legacy` prefix, those `XCTAssertFalse` lines go red before the whole canvas layer does.
///
/// Every member below is EXACTLY the expression its former call sites spelled inline — the same
/// object minted, the same downcast with the same `nil` on failure — so Task 44's "zero behavior
/// change" claim reduces to inlining these four bodies.
@available(iOS 13.0, *)
enum LegacyTextIdentity {
    /// The identity object for a global UTF-16 offset. Was `DocumentTextPosition(offset)` at the call site.
    static func position(atGlobal offset: Int) -> UITextPosition { LegacyTextPosition(offset) }

    /// The global UTF-16 offset carried by a position, or `nil` when the position was not minted by
    /// this backend. Was `(position as? DocumentTextPosition)?.offset` at the call site — including
    /// the `nil`, which every caller still supplies its own fallback for rather than having one
    /// chosen here.
    static func globalOffset(of position: UITextPosition) -> Int? {
        (position as? LegacyTextPosition)?.offset
    }

    /// The identity object for a global UTF-16 range. UNORDERED by construction — `from`/`to` are
    /// stored verbatim, never `min`/`max`, because an unordered range is load-bearing for a reversed
    /// drag (see `RichTextCanonicalSelection.normalizedRange`).
    static func range(fromGlobal from: Int, toGlobal to: Int) -> UITextRange {
        LegacyTextRange(LegacyTextPosition(from), LegacyTextPosition(to))
    }

    /// The global UTF-16 endpoints carried by a range, unordered and verbatim, or `nil` when the
    /// range was not minted by this backend. Was `(range as? DocumentTextRange)` plus two `.offset`
    /// reads at the call site.
    static func globalRange(of range: UITextRange) -> (from: Int, to: Int)? {
        guard let r = range as? LegacyTextRange else { return nil }
        return (r.from.offset, r.to.offset)
    }
}
#endif
