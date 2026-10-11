import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// R9-buttons Task 1 — the public seam over the internal, V2-pinned row packer.
///
/// These numbers are DERIVED, not recorded: `RichTextButtonMetrics.default` ships
/// `blockRowHeight: 40`, `blockSpacing: 6` and `maximumButtonsPerRow: 8`, so one visual row is 40
/// and two are 40 + 6 + 40 = 86. If a metric changes, these change with it — that is the point.
@available(iOS 13.0, *)
final class EngineButtonRowSurfaceTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func button(_ label: String) -> ButtonRef {
        ButtonRef(label: [TextRun(text: label)], action: .url("https://example.com"))
    }

    func test_oneVisualRowIsTheFixedPillHeight() {
        let height = richTextButtonRowHeight(buttons: [button("A"), button("B")], alignment: .justify,
                                             width: 320, mapper: mapper, showsMenuAffordance: false)
        XCTAssertEqual(height, 40.0, accuracy: 0.001)
    }

    func test_nineJustifiedPillsWrapToTwoRows() {
        let buttons = (0 ..< 9).map { button("B\($0)") }
        let height = richTextButtonRowHeight(buttons: buttons, alignment: .justify,
                                             width: 320, mapper: mapper, showsMenuAffordance: false)
        XCTAssertEqual(height, 86.0, accuracy: 0.001, "maximumButtonsPerRow is 8, so the ninth wraps")
    }

    func test_anEmptyRowStillHasOnePillOfHeight() {
        XCTAssertEqual(richTextButtonRowHeight(buttons: [], alignment: .justify, width: 320,
                                               mapper: mapper, showsMenuAffordance: false),
                       40.0, accuracy: 0.001,
                       "an empty row must stay selectable and deletable, so it keeps a band")
    }

    func test_theMenuAffordanceNarrowsTheJustifiedPills() {
        let view = RichTextButtonRowView()
        view.update(buttons: [button("Only")], alignment: .justify, width: 320, mapper: mapper,
                    showsMenuAffordance: false, emojiProvider: nil)
        let wide = view.pillRect(0)?.width ?? 0
        view.update(buttons: [button("Only")], alignment: .justify, width: 320, mapper: mapper,
                    showsMenuAffordance: true, emojiProvider: nil)
        let narrow = view.pillRect(0)?.width ?? 0
        XCTAssertEqual(wide - narrow, 34.0, accuracy: 0.001,
                       "menuButtonSide 28 + menuButtonGap 6 — the reserve, so the control always fits")
    }

    func test_aPillIsFoundByPointAndTheMenuByItsOwnRect() {
        let view = RichTextButtonRowView()
        view.update(buttons: [button("A"), button("B")], alignment: .justify, width: 320,
                    mapper: mapper, showsMenuAffordance: true, emojiProvider: nil)
        guard let first = view.pillRect(0), let second = view.pillRect(1) else { return XCTFail("no frames") }
        XCTAssertEqual(view.pillIndex(at: CGPoint(x: first.midX, y: first.midY)), 0)
        XCTAssertEqual(view.pillIndex(at: CGPoint(x: second.midX, y: second.midY)), 1)
        XCTAssertFalse(view.menuButtonRect.isEmpty)
        XCTAssertNil(view.pillIndex(at: CGPoint(x: view.menuButtonRect.midX, y: view.menuButtonRect.midY)),
                     "the control is not a pill")
    }

    func test_eachPillGetsItsOwnHostedSubview() {
        let view = RichTextButtonRowView()
        view.update(buttons: [button("A"), button("B"), button("C")], alignment: .left, width: 320,
                    mapper: mapper, showsMenuAffordance: false, emojiProvider: nil)
        XCTAssertEqual(view.subviews.compactMap { $0 as? RichTextButtonPillView }.count, 3)
        view.update(buttons: [button("A")], alignment: .left, width: 320, mapper: mapper,
                    showsMenuAffordance: false, emojiProvider: nil)
        XCTAssertEqual(view.subviews.compactMap { $0 as? RichTextButtonPillView }.count, 1,
                       "pooled positionally, and the surplus is culled")
    }
}
