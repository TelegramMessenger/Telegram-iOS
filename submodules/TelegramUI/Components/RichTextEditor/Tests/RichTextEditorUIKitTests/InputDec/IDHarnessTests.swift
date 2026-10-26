#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

@available(iOS 17.0, *)
@MainActor
final class IDHarnessTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "the kernel is certified against exactly one OS build")
    }

    func test_harnessBuildsTheIDCanvasAndAttachesTheIDBackend() {
        let h = makeBackendHarness(backend: .inputDec)
        defer { h.tearDown() }
        XCTAssertTrue(h.canvas is IDDocumentCanvasView)
        XCTAssertTrue(h.backend is IDTextEditorBackend)
        XCTAssertTrue(h.backend.isAttached)
        XCTAssertEqual(h.backendKind, .inputDec)
    }

    /// ~1600 legacy tests assert on `boxes`, `anchor`, `head`, `undoManagerOverride`. Those must
    /// stay reachable through the harness for BOTH backends or no suite can be shared.
    func test_harnessExposesTheLegacyAssertionSurface() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"])
        defer { h.tearDown() }
        XCTAssertEqual(h.canvas.boxes.count, 2)
        XCTAssertNotNil(h.canvas.undoManagerOverride)
        XCTAssertTrue(h.undoManager === h.canvas.undoManagerOverride)
        h.select(1, 4)
        XCTAssertEqual(h.anchor, 1)
        XCTAssertEqual(h.head, 4)
    }

    /// The storage facade is the ID backend's mutation entry point; family 4's tests drive it
    /// directly, so the harness must vend it — and must vend nil for the legacy backend.
    func test_storageFacadeIsVendedForInputDecAndNilForLegacy() {
        let id = makeBackendHarness(backend: .inputDec); defer { id.tearDown() }
        XCTAssertNotNil(id.storageFacade)
        let legacy = makeBackendHarness(backend: .legacy); defer { legacy.tearDown() }
        XCTAssertNil(legacy.storageFacade)
    }

    func test_harnessTearsDownWithoutLeavingAnAttachedBridge() {
        let h = makeBackendHarness(backend: .inputDec)
        let canvas = h.canvas
        h.tearDown()
        XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
    }

    /// The engine flag must still be restored — a leaked `true` silently converts the rest of
    /// the bundle into a TextKit-1 run, and the .inputDec branch adds a new early-return path.
    func test_tearDownRestoresTheGlobalEngineFlagOnTheInputDecPath() {
        let before = BlockLayoutBackend.forceTextKit1
        let h = makeBackendHarness(backend: .inputDec, engine: .textKit1)
        h.tearDown()
        XCTAssertEqual(BlockLayoutBackend.forceTextKit1, before)
    }
}
#endif
