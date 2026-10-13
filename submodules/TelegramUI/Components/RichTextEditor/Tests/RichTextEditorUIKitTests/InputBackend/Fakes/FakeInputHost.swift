#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Two hosts, deliberately different shapes:
///
/// `FakeInputHost` conforms to `LegacyRichTextInputHost` (NOT plain `RichTextInputHost`) because
/// `LegacyRichTextInputBackend.attach(to:)` narrows its `any RichTextInputHost` parameter with
/// `host as? any LegacyRichTextInputHost` and throws `.incompatibleHost` when that narrowing fails
/// (`LegacyRichTextInputBackend+Attachment.swift`). A host conforming only to the base protocol would
/// make every contract test fail attachment before it could exercise anything. It vends a bare
/// `DocumentCanvasView()` as `legacyCanvas` — an inert canvas that exists only to satisfy the
/// refinement's stored-property requirement; nothing in the contract suites reads or writes through
/// it (D24's rule that `legacyCanvas` is not a licence to touch canonical selection/marked state).
///
/// TASK 26 CORRECTION to the sentence above: the "nothing reads or writes through it" claim is false,
/// and TASK 29 CORRECTED IT A SECOND TIME. **Stated as a LIST rather than a negation**, because a
/// negation about this fixture has now rotted on two consecutive routing tasks and would rot again:
/// every routing task moves members onto `legacyCanvas`, so "no other member" is a claim with a
/// built-in expiry. **Members of `LegacyRichTextInputBackend` that reach this canvas today:**
///
///   * `selectedTextRange` — **WRITE ONLY, since TASK 35** (was READ and WRITE at Task 26). The
///     getter no longer reaches this canvas at all: Task 35 moved `anchor`/`head` storage onto the
///     backend and repointed the getter at `canonicalSelectionStorage`, retiring the last two
///     `legacyCanvas.anchor`/`.head` reads in the tree. The setter still runs the
///     canvas body through `legacyApplySelectedTextRange(_:)`, which CLAMPS both endpoints against
///     `documentSize`. A zero-length canvas would clamp every contract suite's offsets to 0, which is
///     why this canvas is seeded with one long paragraph — `seededTextLength` characters, comfortably
///     past every offset any contract suite uses.
///   * `markedTextRange` — READ (Task 29): `legacyCanvas.markedRange`.
///   * `setMarkedText(_:selectedRange:)` / `unmarkText()` — WRITE (Task 29), through
///     `legacySetMarkedText` / `legacyUnmarkText`.
///   * `beginningOfDocument`/`endOfDocument`/`text(in:)`/the position-conversion family (Tasks 24-25)
///     and `baseWritingDirection` — READ, through `legacy…` hooks.
///   * `installInteractions()` / `removeInteractions()` / `viewportDidChange()` /
///     `cancelActiveInteraction(reason:)` — WRITE (Task 32), through
///     `installSelectionInteractions()` / `legacyRemoveSelectionInteractions()` /
///     `legacyViewportDidChange()` / `stopDragAutoScroll()` + `cancelFloatingCursor()`. **THREE of the
///     four are reached without a suite asking for anything**: `attach(to:)` calls
///     `installInteractions()`, and `performDetachSteps()` calls `cancelActiveInteraction(reason:)` and
///     `removeInteractions()`. (`viewportDidChange()` is reached only if a suite scrolls.) So every
///     suite that attaches a backend to this host installs the canvas's **three** gesture recognizers
///     plus a `UIEditMenuInteraction` — which brings three UIKit recognizers of its own, so the canvas
///     ends up holding **six**, and only three of them are ours — and every suite that detaches removes
///     our three again. Both are idempotent and neither touches document or selection state, so no contract
///     assertion is affected — but this canvas is no longer inert with respect to UIKit interaction
///     objects, which is exactly the kind of fact the list above exists to make findable.
///     (`layoutDidChange(generation:)` is the fifth member of that family and reaches nothing: it
///     stores a number on the backend.)
///
/// **Safe today, verified rather than assumed, and the reason is worth knowing before adding a suite.**
/// The two marked-text members a contract suite could drive are OVERRIDDEN on
/// `ReferenceMutationBackend` with storage-only bodies, so they never reach this canvas.
/// `unmarkText()` is a bare `inner.unmarkText()` forward and WOULD execute real `commitMarkedText()`
/// code on this seeded fixture — but no contract suite drives it (every `.unmarkText()` hit under
/// `Tests/` is on a real canvas). **A future suite that drives `backend.unmarkText()` begins running
/// real composition-commit code against this inert canvas**; that is the trap this list exists to
/// surface.
///
/// `IncompatibleFakeHost` conforms to plain `RichTextInputHost` ONLY, and exists solely so Task 22i can
/// drive `attach`'s `.incompatibleHost` failure path — the one case `FakeInputHost` cannot exercise by
/// construction.
///
/// Both wire the same six fakes into the six client properties; `IncompatibleFakeHost` builds its own
/// set (never attached to a real backend in practice, since attachment fails first) rather than sharing
/// `FakeInputHost`'s, so each host owns an independent, freshly constructed fixture.

@MainActor
@available(iOS 16.0, *)
final class FakeInputHost: LegacyRichTextInputHost {
    let log: RichTextInputEventLog

    let fakeDocumentClient: FakeInputDocumentClient
    let fakeGeometryClient: FakeInputGeometryClient
    let fakeAnnotationClient: FakeInputAnnotationClient
    let fakePresentationClient: FakeInputPresentationClient
    let fakeLifecycleClient: FakeInputLifecycleClient
    let fakeCommandClient: FakeInputCommandClient
    let legacyCanvas: DocumentCanvasView

    init(log: RichTextInputEventLog) {
        self.log = log
        self.fakeDocumentClient = FakeInputDocumentClient(log: log)
        self.fakeGeometryClient = FakeInputGeometryClient(log: log)
        self.fakeAnnotationClient = FakeInputAnnotationClient(log: log)
        self.fakePresentationClient = FakeInputPresentationClient(log: log)
        self.fakeLifecycleClient = FakeInputLifecycleClient(log: log)
        self.fakeCommandClient = FakeInputCommandClient(log: log)
        self.legacyCanvas = DocumentCanvasView()
        // See the type's own doc comment: `selectedTextRange` clamps against this canvas's
        // `documentSize`, so it must be long enough for every offset the contract suites use.
        self.legacyCanvas.setParagraphs(
            [ParagraphBlock(id: BlockID("fakeHostSeed"),
                            runs: [TextRun(text: String(repeating: "x", count: Self.seededTextLength))])],
            width: 300)
    }

    /// The seeded paragraph's character count. 64 is an order of magnitude past the largest offset any
    /// contract suite writes through `selectedTextRange` (9), so a future suite is unlikely to trip it;
    /// if one does, it fails LOUDLY (a clamped-to-64 selection), not silently.
    static let seededTextLength = 64

    var hostInputView: UIView { legacyCanvas }
    var documentClient: any RichTextInputDocumentClient { fakeDocumentClient }
    var geometryClient: any RichTextInputGeometryClient { fakeGeometryClient }
    var annotationClient: any RichTextInputAnnotationClient { fakeAnnotationClient }
    var presentationClient: any RichTextInputPresentationClient { fakePresentationClient }
    var lifecycleClient: any RichTextInputLifecycleClient { fakeLifecycleClient }
    var commandClient: any RichTextInputCommandClient { fakeCommandClient }
}

@MainActor
@available(iOS 16.0, *)
final class IncompatibleFakeHost: RichTextInputHost {
    let log: RichTextInputEventLog

    let fakeDocumentClient: FakeInputDocumentClient
    let fakeGeometryClient: FakeInputGeometryClient
    let fakeAnnotationClient: FakeInputAnnotationClient
    let fakePresentationClient: FakeInputPresentationClient
    let fakeLifecycleClient: FakeInputLifecycleClient
    let fakeCommandClient: FakeInputCommandClient
    private let bareInputView = UIView()

    init(log: RichTextInputEventLog) {
        self.log = log
        self.fakeDocumentClient = FakeInputDocumentClient(log: log)
        self.fakeGeometryClient = FakeInputGeometryClient(log: log)
        self.fakeAnnotationClient = FakeInputAnnotationClient(log: log)
        self.fakePresentationClient = FakeInputPresentationClient(log: log)
        self.fakeLifecycleClient = FakeInputLifecycleClient(log: log)
        self.fakeCommandClient = FakeInputCommandClient(log: log)
    }

    var hostInputView: UIView { bareInputView }
    var documentClient: any RichTextInputDocumentClient { fakeDocumentClient }
    var geometryClient: any RichTextInputGeometryClient { fakeGeometryClient }
    var annotationClient: any RichTextInputAnnotationClient { fakeAnnotationClient }
    var presentationClient: any RichTextInputPresentationClient { fakePresentationClient }
    var lifecycleClient: any RichTextInputLifecycleClient { fakeLifecycleClient }
    var commandClient: any RichTextInputCommandClient { fakeCommandClient }
}
#endif
