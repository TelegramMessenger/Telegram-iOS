import XCTest
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
@testable import InstantPageUI

final class InstantPageV2NestedButtonTests: XCTestCase {
    private let theme = instantPageThemeForType(.light, settings: InstantPagePresentationSettings(
        themeType: .light, fontSize: .standard, lineSpacingFactor: 1.0,
        forceSerif: false, autoNightMode: false, ignoreAutoNightModeUntil: 0
    ))
    private let button = InstantPageButton(text: .plain("Open"), action: .url("https://telegram.org"), color: nil)

    private func layout(_ items: [InstantPageV2LaidOutItem]) -> InstantPageV2Layout {
        return InstantPageV2Layout(contentSize: CGSize(width: 320.0, height: 300.0), items: items, detailsIndices: [])
    }

    private func buttonItem(_ button: InstantPageButton, inline: Bool = false) -> InstantPageV2LaidOutItem {
        let attachment = instantPageInlineButtonAttachment(
            button: button,
            labelString: NSAttributedString(string: "Open", attributes: [.font: UIFont.systemFont(ofSize: 15.0)])
        )
        let frame = CGRect(origin: .zero, size: attachment.size)
        if inline {
            return .inlineButton(InstantPageV2InlineButtonItem(frame: frame, attachment: attachment))
        }
        return .buttonRow(InstantPageV2ButtonRowItem(frame: frame, buttons: [(attachment: attachment, frame: frame)]))
    }

    private func details(_ contents: InstantPageV2Layout, index: Int = 0, expanded: Bool = true) throws -> InstantPageV2LaidOutItem {
        let (textItem, _, size) = layoutTextItem(
            NSAttributedString(string: "Details", attributes: [.font: UIFont.systemFont(ofSize: 17.0)]),
            boundingWidth: 280.0, offset: .zero
        )
        return .details(InstantPageV2DetailsItem(
            frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: expanded ? 340.0 : 40.0),
            index: index, sideInset: 17.0, titleTextItem: try XCTUnwrap(textItem),
            titleFrame: CGRect(origin: .zero, size: size), separatorColor: .clear,
            isExpanded: expanded, innerLayout: expanded ? contents : nil,
            defaultExpanded: false, rtl: false
        ))
    }

    private func table(title: InstantPageV2Layout? = nil, cells: [InstantPageV2Layout]) -> InstantPageV2LaidOutItem {
        return .table(InstantPageV2TableItem(
            frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 300.0),
            titleSubLayout: title,
            titleFrame: title.map { CGRect(origin: .zero, size: $0.contentSize) },
            contentSize: CGSize(width: 320.0, height: CGFloat(cells.count) * 60.0),
            contentInset: 0.0,
            cells: cells.enumerated().map { index, contents in
                InstantPageV2TableCell(
                    frame: CGRect(x: 0.0, y: CGFloat(index) * 60.0, width: 320.0, height: 60.0),
                    isHeader: false, horizontalAlignment: .left, verticalAlignment: .top,
                    backgroundColor: nil, subLayout: contents
                )
            },
            horizontalLines: [], verticalLines: [], bordered: false, striped: false, borderColor: .clear
        ))
    }

    private func pill(in view: InstantPageV2View) throws -> InstantPageV2ButtonPillView {
        let item = try XCTUnwrap(view.itemViews.first)
        if let row = item as? InstantPageV2ButtonRowView {
            return try XCTUnwrap(row.pillViews.first)
        }
        return try XCTUnwrap(item as? InstantPageV2InlineButtonView).pillView
    }

    // Invoke the pill's dispatch callback: this checks the complete forwarding chain without
    // synthesizing UITouch. Hit testing and actual bot requests still need a client smoke test.
    private func tap(_ pill: InstantPageV2ButtonPillView, button: InstantPageButton, progress: Promise<Bool>) throws {
        let handler = try XCTUnwrap(pill.onButtonTapped)
        handler(button, progress)
    }

    func testDetailsButtonForwardsAfterExpansionReuseAndReexpansion() throws {
        let view = InstantPageV2View()
        let contents = self.layout([self.buttonItem(self.button)])
        let progress = Promise<Bool>()
        var received: [InstantPageButton] = []
        view.buttonTapped = { button, forwardedProgress in
            received.append(button)
            XCTAssertTrue(forwardedProgress === progress)
        }
        var toggledIndices: [Int] = []
        view.detailsTapped = { toggledIndices.append($0) }

        view.update(layout: self.layout([try self.details(contents, expanded: false)]), theme: self.theme, animation: .None)
        let details = try XCTUnwrap(view.itemViews.first as? InstantPageV2DetailsView)
        XCTAssertNil(details.bodyView)

        view.update(layout: self.layout([try self.details(contents)]), theme: self.theme, animation: .None)
        XCTAssertTrue(view.itemViews.first === details)
        let firstBody = try XCTUnwrap(details.bodyView)
        let firstPill = try self.pill(in: firstBody)
        try self.tap(firstPill, button: self.button, progress: progress)

        view.update(layout: self.layout([try self.details(contents)]), theme: self.theme, animation: .None)
        XCTAssertTrue(details.bodyView === firstBody)
        XCTAssertTrue(try self.pill(in: firstBody) === firstPill)
        try self.tap(firstPill, button: self.button, progress: progress)

        view.update(layout: self.layout([try self.details(contents, expanded: false)]), theme: self.theme, animation: .None)
        XCTAssertNil(details.bodyView)
        view.update(layout: self.layout([try self.details(contents)]), theme: self.theme, animation: .None)
        let newBody = try XCTUnwrap(details.bodyView)
        XCTAssertFalse(newBody === firstBody)
        try self.tap(try self.pill(in: newBody), button: self.button, progress: progress)
        details.onTitleTapped?(0)

        XCTAssertEqual(received, [self.button, self.button, self.button])
        XCTAssertEqual(toggledIndices, [0])
    }

    func testTableTitleAndCellsForwardToHandlerAssignedAfterLayout() throws {
        let view = InstantPageV2View()
        let contents = self.layout([self.buttonItem(self.button, inline: true)])
        view.update(layout: self.layout([self.table(title: contents, cells: [contents, contents])]), theme: self.theme, animation: .None)
        let table = try XCTUnwrap(view.itemViews.first as? InstantPageV2TableView)
        let title = try XCTUnwrap(table.titleSubView)
        XCTAssertEqual(table.cellSubViews.count, 2)

        let progress = Promise<Bool>()
        var received: [InstantPageButton] = []
        view.buttonTapped = { button, forwardedProgress in
            received.append(button)
            XCTAssertTrue(forwardedProgress === progress)
        }
        for child in [title] + table.cellSubViews {
            try self.tap(try self.pill(in: child), button: self.button, progress: progress)
        }
        XCTAssertEqual(received, [self.button, self.button, self.button])

        let replacement = InstantPageButton(text: .plain("Copy"), action: .copyText(payload: "replacement"), color: nil)
        let changedContents = self.layout([self.buttonItem(replacement, inline: true)])
        let firstCell = try XCTUnwrap(table.cellSubViews.first)
        view.update(layout: self.layout([self.table(title: changedContents, cells: [changedContents, changedContents])]), theme: self.theme, animation: .None)
        XCTAssertTrue(view.itemViews.first === table)
        XCTAssertTrue(table.cellSubViews.first === firstCell)
        let updatedPill = try self.pill(in: firstCell)
        XCTAssertEqual(updatedPill.attachment.button, replacement)
        try self.tap(updatedPill, button: updatedPill.attachment.button, progress: progress)
        XCTAssertEqual(received, [self.button, self.button, self.button, replacement])
    }

    func testMixedNestingForwardsToCurrentRootHandler() throws {
        let view = InstantPageV2View()
        let inner = try self.details(self.layout([self.buttonItem(self.button)]), index: 1)
        let table = self.table(cells: [self.layout([inner])])
        let outer = try self.details(self.layout([table]))
        view.update(layout: self.layout([outer]), theme: self.theme, animation: .None)

        let outerView = try XCTUnwrap(view.itemViews.first as? InstantPageV2DetailsView)
        let outerBody = try XCTUnwrap(outerView.bodyView)
        let tableView = try XCTUnwrap(outerBody.itemViews.first as? InstantPageV2TableView)
        let cell = try XCTUnwrap(tableView.cellSubViews.first)
        let innerView = try XCTUnwrap(cell.itemViews.first as? InstantPageV2DetailsView)
        let buttonView = try self.pill(in: XCTUnwrap(innerView.bodyView))
        let progress = Promise<Bool>()

        var firstCalls = 0
        view.buttonTapped = { _, _ in firstCalls += 1 }
        try self.tap(buttonView, button: self.button, progress: progress)
        var secondCalls = 0
        view.buttonTapped = { button, forwardedProgress in
            secondCalls += 1
            XCTAssertEqual(button, self.button)
            XCTAssertTrue(forwardedProgress === progress)
        }
        try self.tap(buttonView, button: self.button, progress: progress)
        view.buttonTapped = nil
        try self.tap(buttonView, button: self.button, progress: progress)

        XCTAssertEqual(firstCalls, 1)
        XCTAssertEqual(secondCalls, 1)
    }

    func testNestedButtonDoesNotRetainRootRenderer() throws {
        var view: InstantPageV2View? = InstantPageV2View()
        weak var weakView = view
        var calls = 0
        view?.buttonTapped = { _, _ in calls += 1 }
        view?.update(
            layout: self.layout([try self.details(self.layout([self.buttonItem(self.button)]))]),
            theme: self.theme, animation: .None
        )
        let details = try XCTUnwrap(view?.itemViews.first as? InstantPageV2DetailsView)
        let body = try XCTUnwrap(details.bodyView)
        let buttonView = try self.pill(in: body)
        let progress = Promise<Bool>()
        try self.tap(buttonView, button: self.button, progress: progress)
        view = nil

        XCTAssertNil(weakView)
        try self.tap(buttonView, button: self.button, progress: progress)
        XCTAssertEqual(calls, 1)
    }
}
