#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class CanvasEditMenuActionsTests: XCTestCase {
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }
    func titles(_ elements: [UIMenuElement]) -> [String] {
        elements.map { ($0 as? UIMenu)?.title ?? ($0 as? UIAction)?.title ?? "" }
    }

    func test_customMenu_forSelection_hasFormatLookUpShare() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello"
        let t = titles(v.customEditMenuElements())
        XCTAssertTrue(t.contains("Format"))
        XCTAssertTrue(t.contains("Look Up"))
        XCTAssertTrue(t.contains("Share"))
    }
    func test_hook_appendsCustomAfterSuggestedActions() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)
        let suggested: [UIMenuElement] = [UIAction(title: "SysA") { _ in }, UIAction(title: "SysB") { _ in }]
        let interaction = UIEditMenuInteraction(delegate: nil)
        let cfg = UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero)
        let menu = v.editMenuInteraction(interaction, menuFor: cfg, suggestedActions: suggested)
        let t = titles(menu?.children ?? [])
        XCTAssertEqual(Array(t.prefix(2)), ["SysA", "SysB"], "system suggestedActions come first, in order")
        XCTAssertTrue(t.contains("Format"), "our Format submenu is appended")
        XCTAssertTrue(t.contains("Look Up"))
        XCTAssertTrue(t.contains("Share"))
    }
    func test_customMenu_collapsedCaret_isEmpty() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)
        XCTAssertTrue(v.customEditMenuElements().isEmpty)
    }
    func test_formatSubmenu_hasBoldItalicUnderline() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)
        let format = v.customEditMenuElements().compactMap { $0 as? UIMenu }.first { $0.title == "Format" }
        XCTAssertNotNil(format)
        let childTitles = Set((format?.children ?? []).compactMap { ($0 as? UIAction)?.title })
        XCTAssertEqual(childTitles, ["Bold", "Italic", "Underline"])
    }
    func test_owningViewController_walksResponderChain() {
        let v = canvas()
        let vc = UIViewController()
        vc.view.addSubview(v)
        XCTAssertTrue(v.owningViewController() === vc)
    }
    func test_owningViewController_nilWhenDetached() {
        XCTAssertNil(canvas().owningViewController())
    }
    func test_customMenu_forSelection_hasTranslate() {
        guard #available(iOS 17.4, *) else { return }   // Translate item is gated to 17.4+
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)
        XCTAssertTrue(titles(v.customEditMenuElements()).contains("Translate"))
    }
}
#endif
