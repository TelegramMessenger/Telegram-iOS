import XCTest
import UIKit
import TelegramCore
import TelegramUIPreferences
@testable import InstantPageUI

final class InstantPageV2TableCaptionTests: XCTestCase {
    private let theme = InstantPageTheme.chatMessageGeometryTheme()

    private func text(_ name: String) throws -> (InstantPageV2Layout, InstantPageTextItem, CGPoint) {
        let stack = InstantPageTextStyleStack()
        stack.push(.fontSize(17.0))
        stack.push(.textColor(.black))
        stack.push(.linkColor(.blue))
        let attributed = attributedStringForRichText(
            .url(text: .plain(name), url: "https://example.com/\(name)", webpageId: nil), styleStack: stack)
        let (item, _, size) = layoutTextItem(attributed, boundingWidth: 180.0, offset: .zero)
        let text = try XCTUnwrap(item)
        let line = try XCTUnwrap(text.lines.first)
        let point = CGPoint(x: line.frame.midX, y: line.frame.midY)
        XCTAssertNotNil(text.urlAttribute(at: point))
        let frame = CGRect(origin: CGPoint(x: 8.0, y: 6.0), size: size)
        return (InstantPageV2Layout(contentSize: CGSize(width: 200.0, height: 40.0), items: [
            .anchor(InstantPageV2AnchorItem(frame: .zero, name: name)),
            .text(InstantPageV2TextItem(frame: frame, textItem: text))
        ], detailsIndices: []), text, CGPoint(x: frame.minX + point.x, y: frame.minY + point.y))
    }

    // Query at coordinates obtained from the actual rendered UIView hierarchy, rather than
    // duplicating the hit-test offset calculation. Heights model absent, short and tall captions.
    private func check(captionHeight: CGFloat, checkSelection: Bool = false) throws {
        let root = InstantPageV2View()
        let caption = try self.text("caption")
        let rows = try (0..<4).map { try self.text("row\($0)") }
        let table = InstantPageV2TableItem(
            frame: CGRect(x: 13.0, y: 29.0, width: 260.0, height: captionHeight + 160.0),
            titleSubLayout: captionHeight > 0 ? caption.0 : nil,
            titleFrame: captionHeight > 0 ? CGRect(x: 0.0, y: 0.0, width: 220.0, height: captionHeight) : nil,
            contentSize: CGSize(width: 220.0, height: captionHeight + 160.0), contentInset: 11.0,
            cells: rows.enumerated().map { index, row in
                InstantPageV2TableCell(frame: CGRect(x: 0.0, y: CGFloat(index) * 40.0, width: 220.0, height: 40.0),
                    isHeader: false, horizontalAlignment: .left, verticalAlignment: .top,
                    backgroundColor: nil, subLayout: row.0)
            }, horizontalLines: [], verticalLines: [], bordered: false, striped: false, borderColor: .clear)
        root.update(layout: InstantPageV2Layout(contentSize: CGSize(width: 320.0, height: 400.0),
            items: [.table(table)], detailsIndices: []), theme: self.theme, animation: .None)
        let rendered = try XCTUnwrap(root.itemViews.first as? InstantPageV2TableView)
        XCTAssertEqual(rendered.cellSubViews.count, rows.count)
        var children = Array(zip(rendered.cellSubViews, rows))
        if let title = rendered.titleSubView { children.append((title, caption)) }
        for (child, row) in children {
            let point = child.convert(row.2, to: root)
            let hit = root.urlItemAt(point: point)
            XCTAssertEqual(hit?.urlItem.url, row.1.urlAttribute(at: CGPoint(x: row.2.x - 8.0, y: row.2.y - 6.0))?.url,
                "caption height \(captionHeight), rendered point \(point)")
            XCTAssertTrue(hit?.item === row.1)
            if checkSelection {
                let selected = try XCTUnwrap(root.selectableTextItems().first { $0.item === row.1 })
                let origin = child.convert(CGPoint(x: 8.0, y: 6.0), to: root)
                XCTAssertEqual(selected.parentOffset.x, origin.x, accuracy: 0.01)
                XCTAssertEqual(selected.parentOffset.y, origin.y, accuracy: 0.01)
                let anchor = try XCTUnwrap(root.anchorFrame(name: row.1.attributedString.string))
                let anchorOrigin = child.convert(CGPoint.zero, to: root)
                XCTAssertEqual(anchor.minX, anchorOrigin.x, accuracy: 0.01)
                XCTAssertEqual(anchor.minY, anchorOrigin.y, accuracy: 0.01)
            }
        }
    }

    func testLinksWithoutCaption() throws { try self.check(captionHeight: 0.0) }
    func testLinksWithShortCaption() throws { try self.check(captionHeight: 40.0) }
    func testLinksWithTallCaption() throws { try self.check(captionHeight: 100.0) }
    func testSelectionAndAnchorsMatchRenderedText() throws { try self.check(captionHeight: 100.0, checkSelection: true) }
}
