#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

/// A cheap tripwire: if a gate class named in docs/input-backend-phase0-oracles.md is renamed or
/// deleted, this fails, instead of a Phase-4 task silently citing a gate that no longer exists.
final class OracleRegistryTests: XCTestCase {
    private func assertClassExists(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let bundleName = Bundle(for: OracleRegistryTests.self).bundleURL
            .deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: "_")
        XCTAssertNotNil(NSClassFromString("\(bundleName).\(name)"),
                        "gate class \(name) is missing — update docs/input-backend-phase0-oracles.md",
                        file: file, line: line)
    }

    func test_undoCoalescingGatesExist() {
        assertClassExists("UndoCoalescingTests"); assertClassExists("UndoBufferIsolationTests")
    }
    func test_structuralBoundaryGatesExist() {
        assertClassExists("DoubleReturnExitTests"); assertClassExists("BlockQuoteEditTests")
        assertClassExists("CanvasPullQuoteEditTests"); assertClassExists("CanvasStructuralTests")
    }
    func test_touchInteractionGatesExist() {
        assertClassExists("SelectionInteractionTests"); assertClassExists("TableControlsTests")
        assertClassExists("CanvasSelectionMenuTests")
    }
    func test_floatingCursorGatesExist() {
        assertClassExists("FloatingCursorTests"); assertClassExists("ScrollCaretOnEditTests")
    }
    func test_clipboardGatesExist() {
        assertClassExists("CanvasClipboardTests"); assertClassExists("RTFConversionTests")
        assertClassExists("CanvasReplaceRangeTests")
    }
    func test_spellingGatesExist() {
        assertClassExists("SpellCheckTapTests"); assertClassExists("SelectionDrivenSpellCheckTests")
        assertClassExists("NativeTextCheckingClientTests")
    }
}
#endif
