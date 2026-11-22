import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, a numbered item inside a BLOCK QUOTE continues the numbering
/// of the list above the quote, while the list after the quote restarts:
///
///     1. alpha / 2. beta / 3. gamma / 4. delta, select "beta" → Format ▸ Quote
///       engine draws:  1. alpha | ▌2. beta | 1. gamma / 2. delta
///       legacy editor: 1. alpha | ▌1. beta | 1. gamma / 2. delta
///
/// The legacy rich editor numbers every expanded quote (and details) body as its own scope
/// (`DocumentCanvasView.listMarkerLabels`), and the engine's own comment on `listMarkerLabels()` says a
/// container "END[s] a numbered run rather than being counted through" — which is true only for the
/// quote's author line after the item, not for its opening.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam: ordered lists made by markdown paste
/// (`1. alpha …` and `1. one / 2. two / 3. three`), one item quoted with Format ▸ Quote, screenshots show
/// "2. beta" and "3. three" inside the quote. Seen 2×.
///
/// **Suspected cause.** `listMarkerLabels()` (`RichTextEngineEditorView+ListMarkers.swift`) feeds
/// `ListNumbering` the flat role list; a quote contributes no list-less entry BEFORE its first child, so
/// the child continues the preceding run.
///
/// **Tier 1**: the drawn markers are the engine's own `ListMarkerLabelView`s, read by position.
final class HarnessQuotedListNumberingTests: XCTestCase {
    private func item(_ text: String) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .ordered, level: 0),
                                             runs: [ChatInputRun(text: text)]))
    }

    /// The labels the engine currently draws, top to bottom.
    private func drawnLabels(in root: HarnessRootViewController) throws -> [String] {
        let textView = try HarnessEngine.textView(in: root)
        var markers: [(y: CGFloat, label: String)] = []
        func walk(_ view: UIView) {
            if NSStringFromClass(type(of: view)).contains("ListMarkerLabelView"), !view.isHidden, view.alpha > 0.0,
               let label = Mirror(reflecting: view).children.first(where: { $0.label == "label" })?.value as? String,
               !label.isEmpty {
                markers.append((view.convert(view.bounds, to: textView).midY, label))
            }
            view.subviews.forEach(walk)
        }
        walk(textView)
        return markers.sorted { $0.y < $1.y }.map(\.label)
    }

    private func labels(_ blocks: [ChatInputBlock]) throws -> [String] {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        _ = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root, seconds: 0.5)
        return try self.drawnLabels(in: root)
    }

    func testANumberedItemInAQuoteStartsItsOwnNumbering() throws {
        let labels = try self.labels([
            self.item("one"),
            self.item("two"),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [self.item("three")]), collapsed: false)),
        ])
        XCTAssertEqual(labels.count, 3, "precondition: expected three drawn markers, got \(labels)")
        XCTAssertEqual(labels, ["1.", "2.", "1."],
                       "the quoted item continued the numbering of the list above the quote")
    }

    /// Control: a quoted list with nothing numbered above it is numbered from 1.
    func testAQuotedListAfterAParagraphIsNumberedFromOne() throws {
        let labels = try self.labels([
            HarnessEngine.paragraph("intro"),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [self.item("a"), self.item("b")]), collapsed: false)),
        ])
        XCTAssertEqual(labels, ["1.", "2."])
    }
}
