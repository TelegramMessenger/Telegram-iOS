#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
@MainActor
final class RichTextInputBackendHarnessTests: XCTestCase {

    // MARK: - Seeding + layout

    /// Red if: the factory seeds the wrong default paragraph count/width, or forgets the initial
    /// `layoutIfNeeded()` (box frames would still be `.zero`).
    func test_defaultHarnessSeedsTwoParagraphsAndLaysOut() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertEqual(h.canvas.boxes.count, 2)
        XCTAssertNil(h.facade, "facade: false (the default) must not build a facade")
        XCTAssertGreaterThan(h.canvas.boxes[0].frame.height, 0,
                             "layoutIfNeeded() must have laid out real box frames, not left them at .zero")
    }

    /// Red if: `(box as! BlockBox).currentParagraph().text` ever stopped matching the seeded string —
    /// this IS the ~1600-test assertion surface the harness exists to keep reachable.
    func test_harnessExposesTheBoxesAssertionSurface() throws {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertEqual((h.canvas.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
        XCTAssertEqual((h.canvas.boxes[1] as! BlockBox).currentParagraph().text, "Beta")
    }

    // MARK: - Selection surface

    /// Red if: the harness's `anchor`/`head` ever became a separate shadow value instead of a plain
    /// pass-through to `canvas.anchor`/`canvas.head` — the two would then be able to disagree.
    func test_anchorAndHeadAreReadableAndWritable() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertEqual(h.anchor, 0)
        XCTAssertEqual(h.head, 0)

        h.anchor = 3
        h.head = 5

        XCTAssertEqual(h.canvas.anchor, 3)
        XCTAssertEqual(h.canvas.head, 5)
        XCTAssertEqual(h.anchor, 3)
        XCTAssertEqual(h.head, 5)
    }

    /// Red if: `caret(_:)`/`select(_:_:)` ever stopped routing through `setSelectionForTesting`, or
    /// mixed up anchor/head order.
    func test_caretAndSelectHelpersMoveTheSelection() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        h.caret(4)
        XCTAssertEqual(h.anchor, 4)
        XCTAssertEqual(h.head, 4)

        h.select(1, 6)
        XCTAssertEqual(h.anchor, 1)
        XCTAssertEqual(h.head, 6)
    }

    // MARK: - Revision / layout generation

    /// Red if: `revision`/`layoutGeneration` ever cached a snapshot instead of reading live through to
    /// `canvas.documentRevision`/`canvas.layoutGeneration`.
    func test_revisionAndLayoutGenerationTrackTheCanvas() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        let revisionBefore = h.revision
        h.caret(0)
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("X"); h.undoManager.endUndoGrouping()

        XCTAssertGreaterThan(h.revision, revisionBefore, "a real content mutation must move the revision")
        XCTAssertEqual(h.revision, h.canvas.documentRevision)
        XCTAssertEqual(h.layoutGeneration, h.canvas.layoutGeneration)
    }

    // MARK: - Undo isolation

    /// Red if: the factory ever stopped installing an isolated `UndoManager` (or left the default
    /// `groupsByEvent == true`, which would silently coalesce every bracketed test mutation into one
    /// group).
    func test_undoManagerIsAnIsolatedOverride() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertTrue(h.undoManager === h.canvas.undoManagerOverride)
        XCTAssertFalse(h.undoManager.groupsByEvent,
                       "the factory must configure groupsByEvent = false so every mutation needs its own bracket")
    }

    // MARK: - Recorder wiring

    /// Red if: the factory forgot the trailing `recorder.reset()` (attach-time noise would leak into a
    /// caller's first assertion), or forgot `recorder.attach(canvas:)` entirely (no event would ever
    /// appear).
    func test_recorderIsAttachedAndRecordsFromTheFirstEdit() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertTrue(h.recorder.events.isEmpty,
                      "the factory's trailing reset() must have cleared attach-time noise")

        h.caret(0)
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("X"); h.undoManager.endUndoGrouping()

        XCTAssertFalse(h.recorder.events.isEmpty, "the recorder must be live-attached from construction")
    }

    /// The load-bearing chaining test. Red if `simulateParentLayout()` ever OVERWROTE
    /// `canvas.onContentSizeChange` (like the plain `DocumentCanvasView.simulateParentLayout()` test
    /// helper does) instead of chaining through it: the first assertion catches a dropped recorder
    /// event, the second catches a dropped relayout — `bumpDocumentRevision()` (inside the edit) and
    /// `layoutContent()`'s own `bumpLayoutGeneration()` (triggered by the chained-through notify) are
    /// two INDEPENDENT bumps, so `+2` only happens when both actually ran.
    func test_simulateParentLayoutChainsThroughTheRecorder() {
        let h = makeBackendHarness()
        defer { h.tearDown() }
        h.simulateParentLayout()

        let generationBefore = h.layoutGeneration
        h.caret(0)
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("Z"); h.undoManager.endUndoGrouping()

        XCTAssertTrue(h.recorder.kinds.contains(.canvasContentSizeChanged),
                      "the recorder must still observe the content-size event")
        XCTAssertEqual(h.layoutGeneration, generationBefore + 2,
                       "+1 from the edit's own bumpDocumentRevision, +1 more from layoutContent() " +
                       "running via the chained-through onContentSizeChange")
    }

    // MARK: - Facade flavor

    /// Red if: `facade: true` ever failed to build a facade, or `recorder.attach(facade:)` ever failed
    /// to wire the three facade hooks (calling a never-wired `nil` closure would leave `recorder.kinds`
    /// empty).
    func test_facadeFlavorWiresTheFacadeHooks() throws {
        let h = makeBackendHarness(facade: true)
        defer { h.tearDown() }

        let facade = try XCTUnwrap(h.facade, "facade: true must construct a RichTextEditorView")

        facade.onChange?()
        facade.onBecameFirstResponder?()
        facade.onResignedFirstResponder?()

        XCTAssertEqual(h.recorder.kinds, [.facadeOnChange, .facadeBecameFirstResponder, .facadeResignedFirstResponder])
    }

    // MARK: - Hosting / first responder

    /// Red if: `hostInWindow()` ever failed to add the canvas to a real window (a view outside any
    /// window cannot become first responder), or if it — wrongly — made the canvas first responder
    /// itself instead of leaving that to the explicit `makeFirstResponder()` call.
    func test_hostInWindowEnablesFirstResponder() {
        let h = makeBackendHarness()
        defer { h.tearDown() }

        XCTAssertFalse(h.makeFirstResponder(),
                       "first-responder activation must not be possible before hostInWindow()")

        h.hostInWindow()

        XCTAssertTrue(h.makeFirstResponder())
        XCTAssertTrue(h.canvas.isFirstResponder)
    }

    // MARK: - Layout engine flavor

    /// Genuine engine-selection proof (not just "the flag reads true"): the box's own `layout` must be
    /// the concrete TK1 engine type. Red if `engine: .textKit1` ever flipped the flag AFTER `setBlocks`/
    /// `setParagraphs` ran (the flag is read at block-CONSTRUCTION time, so a late flip is a no-op and
    /// this would still observe a TK2 layout).
    func test_textKit1FlavorBuildsTextKit1Layouts() throws {
        let h = makeBackendHarness(engine: .textKit1)
        defer { h.tearDown() }

        XCTAssertTrue(BlockLayoutBackend.forceTextKit1,
                     "the flag must still read true here — it is restored only by tearDown()")
        let box = try XCTUnwrap(h.canvas.boxes[0] as? BlockBox)
        XCTAssertTrue(box.layout is BlockLayoutTK1,
                     "engine: .textKit1 must have built a TextKit-1 layout, not TextKit-2")
    }

    /// THE critical test. A leaked `true` silently converts every later suite in the bundle into a
    /// TextKit-1 run — a failure that looks like an unrelated layout regression hundreds of tests away.
    /// Deliberately flips the flag to a NON-default value (`true`) before construction so this
    /// discriminates "restore to the captured previous value" from a bug that just hardcodes `tearDown`
    /// back to `false` (which would pass unnoticed under this bundle's normal, already-`false` ambient
    /// default). Red if `tearDown()` ever hardcoded `false` instead of restoring `previousEngine`.
    func test_tearDownRestoresTheGlobalEngineFlag() {
        BlockLayoutBackend.forceTextKit1 = true   // simulate an ambient TK1 bundle run
        let h = makeBackendHarness(engine: .textKit2)

        XCTAssertFalse(BlockLayoutBackend.forceTextKit1,
                       "the .textKit2 flavor must force the flag false while seeding")

        h.tearDown()

        XCTAssertTrue(BlockLayoutBackend.forceTextKit1,
                      "tearDown() must restore the flag to what it was BEFORE construction (true), " +
                      "not hardcode false")
        BlockLayoutBackend.forceTextKit1 = false   // restore the ambient default for the rest of the bundle
    }

    // MARK: - Source-boundary proof

    /// Mechanical proof for decision 10's constraint: the concrete legacy backend type must be named in
    /// exactly ONE place in the harness's own production file. Counts raw substring occurrences (not
    /// comment-stripped) — deliberately, because this file's own header comments describe the
    /// constraint in prose WITHOUT using the literal identifier, precisely so this count stays exact. A
    /// second occurrence anywhere in that file — a stray mention in a new doc comment, a second
    /// construction site, a cast — fails this red, which is what stage 2 needs: it must be able to add
    /// `case .inputDec` and a second switch arm without editing anything the `.legacy` arm depends on.
    func test_legacyBackendIsNamedExactlyOnceInTheHarnessSourceFile() throws {
        let harnessFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Support
            .appendingPathComponent("RichTextInputBackendHarness.swift")
        let text = try String(contentsOf: harnessFile)
        let occurrences = text.components(separatedBy: "LegacyRichTextInputBackend").count - 1
        XCTAssertEqual(occurrences, 1,
                       "expected the concrete legacy backend type to be named exactly once (the " +
                       ".legacy switch arm); found \(occurrences) in \(harnessFile.path)")
    }
}
#endif
