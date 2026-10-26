#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class CanvasHostMenuProviderTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func region(_ v: DocumentCanvasView) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID("h")) }!
    }
    private func select(_ v: DocumentCanvasView, length: Int) {
        let r = region(v); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + length)
    }
    private func menu(_ v: DocumentCanvasView, suggested: [UIMenuElement] = []) -> UIMenu? {
        let interaction = UIEditMenuInteraction(delegate: nil)
        let cfg = UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero)
        return v.editMenuInteraction(interaction, menuFor: cfg, suggestedActions: suggested)
    }
    private func titles(_ elements: [UIMenuElement]) -> [String] {
        elements.map { ($0 as? UIMenu)?.title ?? ($0 as? UIAction)?.title ?? "" }
    }

    func testProviderTransformAppliedForRangedSelection() {
        let v = canvas()
        select(v, length: 5)
        var receivedDefaults: [UIMenuElement]? = nil
        v.hostContextMenuItemsProvider = { defaults in
            receivedDefaults = defaults
            let kept = defaults.filter { ($0 as? UIMenu)?.title != "Format" }
            return [UIMenu(title: "HostFormat", children: [UIAction(title: "Quote") { _ in }])] + kept
        }
        let result = titles(menu(v)?.children ?? [])
        XCTAssertNotNil(receivedDefaults)
        XCTAssertTrue(titles(receivedDefaults ?? []).contains("Format"))
        XCTAssertTrue(titles(receivedDefaults ?? []).contains("Look Up"))
        XCTAssertTrue(result.contains("HostFormat"))
        XCTAssertFalse(result.contains("Format"))
        XCTAssertTrue(result.contains("Look Up"))
        XCTAssertTrue(result.contains("Share"))
    }

    func testProviderNotConsultedForCollapsedCaret() {
        let v = canvas()
        let r = region(v); v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)
        var invoked = false
        v.hostContextMenuItemsProvider = { invoked = true; return $0 }
        _ = menu(v)
        XCTAssertFalse(invoked)
    }

    func testNilProviderLeavesDefaultMenuUnchanged() {
        let v = canvas()
        select(v, length: 5)
        v.hostContextMenuItemsProvider = nil
        let result = titles(menu(v, suggested: [UIAction(title: "SysA") { _ in }])?.children ?? [])
        XCTAssertEqual(result.first, "SysA")
        XCTAssertTrue(result.contains("Format"))
        XCTAssertTrue(result.contains("Look Up"))
    }

    func testSelectedTextReturnsSelectedSubstring() {
        let view = RichTextEditorView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        let c = view.canvasForTesting
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600); c.layoutIfNeeded()
        let r = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h")) }!
        c.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello"
        XCTAssertEqual(view.selectedText(), "Hello")
    }

    func testSelectedTextEmptyWhenCollapsed() {
        let view = RichTextEditorView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        let c = view.canvasForTesting
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hi")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600); c.layoutIfNeeded()
        XCTAssertEqual(view.selectedText(), "")
    }
}
#endif
