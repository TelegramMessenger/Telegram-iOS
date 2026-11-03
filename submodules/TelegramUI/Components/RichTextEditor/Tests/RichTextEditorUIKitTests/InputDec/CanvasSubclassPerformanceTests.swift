#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// The baseline Task B2's `final`-removal is judged against. Deliberately small and
/// deterministic: three `measure` blocks over the same fixture, no window hosting, no
/// animation. Absolute numbers are machine-dependent and are NOT asserted — the gate is the
/// BEFORE/AFTER ratio on one machine in one sitting, recorded in the Task B2 commit message.
@MainActor
@available(iOS 16.0, *)
final class CanvasSubclassPerformanceTests: XCTestCase {

    private func bigHarness() -> RichTextInputBackendHarness {
        makeBackendHarness(paragraphs: (0..<500).map { "Paragraph number \($0) with some text" },
                           width: 320)
    }

    func test_perf_selectionRectsWholeDocument() {
        let h = bigHarness()
        defer { h.tearDown() }
        h.select(0, h.canvas.documentSizeValue)
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                       to: h.canvas.endOfDocument)!
        measure { _ = h.canvas.selectionRects(for: whole) }
    }

    func test_perf_typing200Characters() {
        let h = makeBackendHarness(paragraphs: ["Alpha"], width: 320)
        defer { h.tearDown() }
        h.caret(5)
        // DEVIATION FROM THE BRIEF (recorded in the B1 report): the harness's undo manager has
        // `groupsByEvent = false` (deterministic testing), so a direct `canvas.insertText(_:)` call
        // — which goes through `DocumentCanvasView+Editing.swift`'s `registerUndo` with no group
        // auto-opened by the run loop — crashes with "must begin a group before registering undo"
        // unless a group is explicitly open. The brief's verbatim loop hit this on every run,
        // engine-independent. Fixed the same way `RichTextInputBackendHarnessTests.swift:80` already
        // does it: bracket the whole measured loop in one explicit undo group via `h.undoManager`.
        measure {
            h.undoManager.beginUndoGrouping()
            for _ in 0..<200 { h.canvas.insertText("a") }
            h.undoManager.endUndoGrouping()
        }
    }

    func test_perf_closestPosition200Points() {
        let h = bigHarness()
        defer { h.tearDown() }
        let points = (0..<200).map { CGPoint(x: 40, y: CGFloat($0) * 7) }
        measure { for p in points { _ = h.canvas.closestPosition(to: p) } }
    }
}
#endif
