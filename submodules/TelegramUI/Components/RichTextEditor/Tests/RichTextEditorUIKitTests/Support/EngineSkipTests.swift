#if canImport(UIKit)
import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class EngineSkipTests: XCTestCase {
    func test_isForcedTextKit1_matchesTheProcessEnvironment() {
        let env = ProcessInfo.processInfo.environment["RTE_FORCE_TK1"] == "1"
        XCTAssertEqual(isForcedTextKit1, env)
        XCTAssertEqual(BlockLayoutBackend.forceTextKit1, env)
    }

    func test_skipOnTextKit1_throwsOnlyUnderTheForcedPass() throws {
        if isForcedTextKit1 {
            XCTAssertThrowsError(try skipOnTextKit1("no loupe on TextKit 1"))
        } else {
            XCTAssertNoThrow(try skipOnTextKit1("no loupe on TextKit 1"))
        }
    }

    /// Not from the Task-9 brief's verbatim template — added because the task's verification section
    /// separately requires proving `makeBlockLayout` actually dispatches on the override, not merely
    /// that `forceTextKit1` reads the environment correctly.
    ///
    /// NOTE (fix-round review): this test, like `test_isForcedTextKit1_matchesTheProcessEnvironment`
    /// above, is NOT proof that `TEST_RUNNER_RTE_FORCE_TK1` propagates from the xcodebuild invocation
    /// into this process. It only proves `makeBlockLayout`'s own if/else is self-consistent with
    /// `BlockLayoutBackend.forceTextKit1` — both read the identical flag, so this can never go red for
    /// a broken-forwarding failure (a broken forwarding path just makes every reader agree on `false`).
    /// See `test_theForcedEngineIsActuallyDispatched_provenByConcreteType` below for the real,
    /// independently-motivated proof, and its doc comment for why that one is different.
    func test_makeBlockLayout_dispatchesOnTheForcedOverride() {
        let engine = makeBlockLayout(attributedString: NSAttributedString(string: "x"), width: 100)
        if isForcedTextKit1 {
            XCTAssertTrue(engine is BlockLayoutTK1)
        } else if #available(iOS 16.0, *) {
            XCTAssertTrue(engine is BlockLayout)
        } else {
            XCTAssertTrue(engine is BlockLayoutTK1)
        }
    }

    /// This project's OWN end-to-end proof that `TEST_RUNNER_RTE_FORCE_TK1` actually propagates from the
    /// xcodebuild invocation into this test process and changes which layout engine gets built — through
    /// the REAL production construction path (`DocumentCanvasView.setBlocks` → `BlockBox.init` →
    /// `makeBlockLayout`), not a bare call to the factory function in isolation.
    ///
    /// Why this exists (fix-round review, Task 9): `test_isForcedTextKit1_matchesTheProcessEnvironment`
    /// and `test_makeBlockLayout_dispatchesOnTheForcedOverride` above both compare
    /// `isForcedTextKit1`/`BlockLayoutBackend.forceTextKit1` against something computed from the SAME
    /// in-process flag/environment read, so neither can discriminate a broken forwarding path (if the
    /// env var never reached this process, every reader of the flag agrees on `false`, and both those
    /// tests pass regardless). The pre-existing, Task-9-INDEPENDENT evidence that forwarding actually
    /// works today is `SpoilerReconcileTests.swift:36-38` — its
    /// `c.boxes[0].textLayout as? BlockLayout` cast fails only under a genuinely forced TK1 pass, which
    /// is why the project's skip count moves 5 → 6 only under `TK1=1`. But that test is unrelated
    /// pre-existing coverage that nobody owns for this purpose — if it's ever rewritten, deleted, or
    /// changed to construct a layout directly, the project silently loses its only proof this
    /// mechanism works, with `matrix.sh` still reporting green. This test gives that proof its own,
    /// named, permanent home.
    ///
    /// `isForcedTextKit1` is used ONLY to select which branch to assert, never as the thing asserted —
    /// the thing asserted is the CONCRETE TYPE of the engine instance the real construction path built.
    /// What would make this go red: (1) a regression in `BlockBox`/`DocumentCanvasView`'s construction
    /// path that stops it from honoring `BlockLayoutBackend.forceTextKit1` (e.g. a future refactor that
    /// hardcodes `BlockLayout()` or caches a stale engine) — this test catches that even when forwarding
    /// itself is fine, unlike the bare-factory test above, which only re-checks the factory's own
    /// condition and would not notice `BlockBox` stopped calling it correctly. (2) A single process
    /// cannot self-detect "the exported env var never reached me" purely from its own control flow,
    /// because production's dispatch reads the exact same flag any test would read — this is a
    /// fundamental limitation, not specific to this test. The actual proof of (2) is OPERATIONAL: run
    /// this test once via `Scripts/iostest.sh RichTextEditorUIKitTests/EngineSkipTests` (unforced) and
    /// once via `TK1=1 Scripts/iostest.sh RichTextEditorUIKitTests/EngineSkipTests` (forced), and
    /// confirm the two runs assert OPPOSITE concrete types. If they ever assert the SAME type, forwarding
    /// is broken and this test's branch selection is chasing the same broken flag as production.
    @available(iOS 16.0, *)
    func test_theForcedEngineIsActuallyDispatched_provenByConcreteType() {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "hello world")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        c.layoutIfNeeded()
        let engine = c.boxes[0].textLayout
        if isForcedTextKit1 {
            XCTAssertTrue(engine is BlockLayoutTK1, "TK1=1 must dispatch the TextKit-1 engine")
            XCTAssertFalse(engine is BlockLayout, "TK1=1 must NOT dispatch TextKit 2")
        } else {
            XCTAssertTrue(engine is BlockLayout, "the unforced pass on iOS 16+ must dispatch TextKit 2")
            XCTAssertFalse(engine is BlockLayoutTK1, "the unforced pass on iOS 16+ must NOT dispatch TextKit 1")
        }
    }
}
#endif
