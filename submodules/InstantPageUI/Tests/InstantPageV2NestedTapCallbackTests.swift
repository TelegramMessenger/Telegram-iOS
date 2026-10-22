import XCTest
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import UnsupportedContentPill
@testable import InstantPageUI

private func makeInlineButtonItem(_ button: InstantPageButton) -> InstantPageV2LaidOutItem {
    let attachment = instantPageInlineButtonAttachment(button: button, labelString: makePlainLabelPiece("123"))
    return .inlineButton(InstantPageV2InlineButtonItem(
        frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: attachment.size),
        attachment: attachment
    ))
}

private func makeButtonRowItem(_ button: InstantPageButton) -> InstantPageV2LaidOutItem {
    let attachment = instantPageInlineButtonAttachment(button: button, labelString: makePlainLabelPiece("Website"))
    return .buttonRow(InstantPageV2ButtonRowItem(
        frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 40.0),
        buttons: [(attachment: attachment, frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 40.0))]
    ))
}

private func makeUnsupportedItem() -> InstantPageV2LaidOutItem {
    let strings = UnsupportedContentPillStrings(title: "Unsupported message", text: "Please update Telegram to view this message.", action: "Update")
    let colors = UnsupportedContentPillColors(fill: UIColor(white: 0.0, alpha: 0.1), primaryText: .white, isDark: true)
    return layoutUnsupportedBlock(boundingWidth: 300.0, horizontalInset: 0.0, strings: strings, colors: colors, isTopLevel: false)[0]
}

private func makeLayout(_ items: [InstantPageV2LaidOutItem]) -> InstantPageV2Layout {
    return InstantPageV2Layout(contentSize: CGSize(width: 320.0, height: 200.0), items: items, detailsIndices: [])
}

/// A one-cell table holding `items`, the shape of a rich message's "1 | 2 | [button]" row.
private func makeTableItem(_ items: [InstantPageV2LaidOutItem]) -> InstantPageV2LaidOutItem {
    return .table(InstantPageV2TableItem(
        frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 120.0),
        titleSubLayout: nil,
        titleFrame: nil,
        contentSize: CGSize(width: 320.0, height: 120.0),
        contentInset: 17.0,
        cells: [InstantPageV2TableCell(
            frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 120.0),
            isHeader: false,
            horizontalAlignment: .natural,
            verticalAlignment: .top,
            backgroundColor: nil,
            subLayout: makeLayout(items)
        )],
        horizontalLines: [],
        verticalLines: [],
        bordered: false,
        striped: false,
        borderColor: .clear
    ))
}

/// A `<details>` whose body holds `items`, expanded unless asked otherwise.
private func makeDetailsItem(_ items: [InstantPageV2LaidOutItem], isExpanded: Bool = true) -> InstantPageV2LaidOutItem {
    let (titleItem, _, _) = layoutTextItemWithString(makePlainLabelPiece("More"), boundingWidth: 300.0, offset: CGPoint())
    return .details(InstantPageV2DetailsItem(
        frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 160.0),
        index: 0,
        sideInset: 17.0,
        titleTextItem: titleItem!,
        titleFrame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 40.0),
        separatorColor: .clear,
        isExpanded: isExpanded,
        innerLayout: isExpanded ? makeLayout(items) : nil,
        defaultExpanded: true,
        rtl: false
    ))
}

private func descendants<T: UIView>(of view: UIView, ofType type: T.Type) -> [T] {
    var result: [T] = []
    for subview in view.subviews {
        if let match = subview as? T {
            result.append(match)
        }
        result.append(contentsOf: descendants(of: subview, ofType: type))
    }
    return result
}

/// A table cell and a `<details>` body are `InstantPageV2View`s of their own, but the host sets its
/// tap callbacks on the root page view only. A button, document or Update button inside one must
/// still reach them; before, a URL pill in a table cell did nothing at all when tapped. (A document
/// row is not covered: without a render context the renderer draws a placeholder in its place.)
final class InstantPageV2NestedTapCallbackTests: XCTestCase {
    private let theme = InstantPageTheme.chatMessageGeometryTheme()

    private func render(_ items: [InstantPageV2LaidOutItem], configure: (InstantPageV2View) -> Void) -> InstantPageV2View {
        let pageView = InstantPageV2View(renderContext: nil)
        configure(pageView)
        pageView.update(layout: makeLayout(items), theme: self.theme, animation: .None)
        return pageView
    }

    func testAnInlineButtonInATableCellReachesTheHost() throws {
        let button = InstantPageButton(text: .plain("123"), action: .url("https://telegram.org"), color: nil)
        var tapped: [InstantPageButton] = []
        let pageView = self.render([makeTableItem([makeInlineButtonItem(button)])]) { pageView in
            pageView.buttonTapped = { button, _ in
                tapped.append(button)
            }
        }

        let buttonView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2InlineButtonView.self).first)
        XCTAssertNotNil(buttonView.superview as? InstantPageV2View)
        XCTAssertFalse(buttonView.superview === pageView, "the pill must be inside the cell's own page view")
        buttonView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }

    /// The host may set its callbacks after the page has been laid out: the bubble assigns them
    /// before every `update`, but nothing must depend on that order.
    func testACallbackSetAfterLayoutIsStillReached() throws {
        let button = InstantPageButton(text: .plain("123"), action: .url("https://telegram.org"), color: nil)
        let pageView = self.render([makeTableItem([makeInlineButtonItem(button)])]) { _ in }
        var tapped: [InstantPageButton] = []
        pageView.buttonTapped = { button, _ in
            tapped.append(button)
        }

        let buttonView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2InlineButtonView.self).first)
        buttonView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }

    func testAButtonRowInADetailsBodyReachesTheHost() throws {
        let button = InstantPageButton(text: .plain("Website"), action: .url("https://core.telegram.org"), color: nil)
        var tapped: [InstantPageButton] = []
        let pageView = self.render([makeDetailsItem([makeButtonRowItem(button)])]) { pageView in
            pageView.buttonTapped = { button, _ in
                tapped.append(button)
            }
        }

        let rowView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2ButtonRowView.self).first)
        XCTAssertFalse(rowView.superview === pageView, "the row must be inside the details body's own page view")
        rowView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }

    /// The body of a `<details>` that was laid out collapsed is built only when it expands, inside
    /// the reused details view's own update, and every view on the way is a reused one.
    func testAButtonInADetailsBodyBuiltOnExpandReachesTheHost() throws {
        let button = InstantPageButton(text: .plain("Website"), action: .url("https://core.telegram.org"), color: nil)
        var tapped: [InstantPageButton] = []
        let pageView = self.render([makeDetailsItem([makeButtonRowItem(button)], isExpanded: false)]) { pageView in
            pageView.buttonTapped = { button, _ in
                tapped.append(button)
            }
        }
        XCTAssertTrue(descendants(of: pageView, ofType: InstantPageV2ButtonRowView.self).isEmpty)
        let detailsView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2DetailsView.self).first)

        pageView.update(layout: makeLayout([makeDetailsItem([makeButtonRowItem(button)])]), theme: self.theme, animation: .None)

        XCTAssertTrue(descendants(of: pageView, ofType: InstantPageV2DetailsView.self).first === detailsView, "the details view must be reused")
        let rowView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2ButtonRowView.self).first)
        rowView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }

    func testAButtonInATableInsideADetailsBodyReachesTheHost() throws {
        let button = InstantPageButton(text: .plain("123"), action: .url("https://telegram.org"), color: nil)
        var tapped: [InstantPageButton] = []
        let pageView = self.render([makeDetailsItem([makeTableItem([makeInlineButtonItem(button)])])]) { pageView in
            pageView.buttonTapped = { button, _ in
                tapped.append(button)
            }
        }

        let buttonView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2InlineButtonView.self).first)
        buttonView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }

    func testAnUnsupportedPillInATableCellReachesTheHost() throws {
        var tapCount = 0
        let pageView = self.render([makeTableItem([makeUnsupportedItem()])]) { pageView in
            pageView.unsupportedActionTapped = {
                tapCount += 1
            }
        }

        let pillView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2UnsupportedView.self).first)
        pillView.onActionTapped?()

        XCTAssertEqual(tapCount, 1)
    }

    func testATopLevelButtonStillReachesTheHost() throws {
        let button = InstantPageButton(text: .plain("Website"), action: .url("https://core.telegram.org"), color: nil)
        var tapped: [InstantPageButton] = []
        let pageView = self.render([makeButtonRowItem(button)]) { pageView in
            pageView.buttonTapped = { button, _ in
                tapped.append(button)
            }
        }

        let rowView = try XCTUnwrap(descendants(of: pageView, ofType: InstantPageV2ButtonRowView.self).first)
        rowView.onButtonTapped?(button, Promise<Bool>())

        XCTAssertEqual(tapped, [button])
    }
}
