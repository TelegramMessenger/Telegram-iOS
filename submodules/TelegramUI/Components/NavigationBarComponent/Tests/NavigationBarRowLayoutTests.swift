import XCTest
import UIKit
import Display
import ComponentFlow
@testable import NavigationBarComponent

private final class TestButtonContentComponent: Component {
    typealias EnvironmentType = NavigationButtonEnvironment

    static func ==(lhs: TestButtonContentComponent, rhs: TestButtonContentComponent) -> Bool {
        return true
    }

    final class View: UIView {
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
        return CGSize(width: 44.0, height: availableSize.height)
    }
}

/// Which buttons of one content go into iPhone Duo's side column, and the bar's title band.
final class NavigationBarRowLayoutTests: XCTestCase {
    private func button(_ id: String, _ content: NavigationBarComponent.Button.Content, priority: Int? = nil, action: @escaping (UIView) -> Void = { _ in }) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: content, overflow: NavigationBarComponent.OverflowInfo(title: id.uppercased(), iconName: nil, priority: priority), action: action)
    }

    private func ids(_ buttons: [NavigationBarComponent.Button]) -> [AnyHashable] {
        return buttons.map(\.id)
    }

    private func accent(_ id: String, tint: NavigationBarComponent.Button.Tint = .accent) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: .icon(imageName: id), tint: tint, action: { _ in })
    }

    // Chats: new message is accent, beside story and proxy. It takes a circle of its own; the rest keep the capsule.
    func test_accentButtonWithOthers_takesTheRowCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("compose"), self.button("story", .icon(imageName: "S")), self.button("proxy", .icon(imageName: "P"))], hasBack: false, columnLength: nil)
        XCTAssertEqual(placement.rowCircleItem?.id, AnyHashable("compose"))
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["story", "proxy"])
    }

    // A disabled accent button takes the circle as well (its glass is the disabled accent).
    func test_disabledAccentButtonWithOthers_takesTheRowCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("done", tint: .accentDisabled), self.button("a", .icon(imageName: "A"))], hasBack: false, columnLength: nil)
        XCTAssertEqual(placement.rowCircleItem?.id, AnyHashable("done"))
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["a"])
    }

    // Alone, the accent button stays the capsule's only item: that capsule is its circle.
    func test_loneAccentButton_staysTheCapsule() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("done")], hasBack: true, columnLength: nil)
        XCTAssertNil(placement.rowCircleItem)
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["done"])
    }

    // Only the first accent button takes the circle (spec ruling 1); a second one stays in the capsule.
    func test_secondAccentButton_staysInTheCapsule() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("a"), self.button("x", .icon(imageName: "X")), self.accent("b")], hasBack: false, columnLength: nil)
        XCTAssertEqual(placement.rowCircleItem?.id, AnyHashable("a"))
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["x", "b"])
    }

    // iPhone Duo: the accent button goes into the column's trailing circle, as before; the row has no circle.
    func test_column_keepsTheAccentButtonInItsTrailingCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("compose"), self.button("story", .icon(imageName: "S"))], hasBack: false, columnLength: 400.0)
        XCTAssertNil(placement.rowCircleItem)
        XCTAssertEqual(placement.trailingCircleItem?.id, AnyHashable("compose"))
    }

    func test_noColumn_everyButtonStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("left", .icon(imageName: "L")), rightButtons: [self.button("a", .icon(imageName: "A")), self.button("b", .text(title: "Edit", isBold: false))], hasBack: true, columnLength: nil)
        XCTAssertNil(placement.columnLayout)
        XCTAssertFalse(placement.leftButtonInColumn)
        XCTAssertEqual(placement.rowLeftButton?.id, AnyHashable("left"))
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["a", "b"])
    }

    func test_column_iconButtonsMove_textStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("left", .icon(imageName: "L")), rightButtons: [self.button("a", .icon(imageName: "A")), self.button("b", .text(title: "Edit", isBold: false))], hasBack: true, columnLength: 400.0)
        XCTAssertNotNil(placement.columnLayout)
        XCTAssertTrue(placement.leftButtonInColumn)
        XCTAssertNil(placement.rowLeftButton)
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["b"])
        XCTAssertEqual(self.ids(placement.columnItems), ["left", "a"])
        XCTAssertEqual(placement.columnLayout?.visibleItems, [0, 1])
    }

    func test_column_textLeftButtonStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("done", .text(title: "Done", isBold: true)), rightButtons: [self.button("a", .icon(imageName: "A"))], hasBack: false, columnLength: 400.0)
        XCTAssertFalse(placement.leftButtonInColumn)
        XCTAssertEqual(placement.rowLeftButton?.id, AnyHashable("done"))
        XCTAssertEqual(self.ids(placement.columnItems), ["a"])
        XCTAssertTrue(placement.rowRightButtons.isEmpty)
    }

    func test_column_customButtonGoesToTheColumn() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("proxy", .custom(AnyComponent(TestButtonContentComponent())))], hasBack: false, columnLength: 400.0)
        XCTAssertEqual(self.ids(placement.columnItems), ["proxy"])
        XCTAssertTrue(placement.rowRightButtons.isEmpty)
    }

    func test_columnTooShort_keepsEverythingInTheRow() {
        // 80pt cannot hold the back circle (48) + spacing (12) + one 48pt cell.
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("a", .icon(imageName: "A"))], hasBack: true, columnLength: 80.0)
        XCTAssertNil(placement.columnLayout)
        XCTAssertEqual(self.ids(placement.rowRightButtons), ["a"])
    }

    func test_overflowItems_runTheirButtonsOwnActions() {
        var pressed: [String] = []
        let rightButtons = [
            self.button("a", .icon(imageName: "A"), priority: 3, action: { _ in pressed.append("a") }),
            self.button("b", .icon(imageName: "B"), priority: 2, action: { _ in pressed.append("b") }),
            self.button("c", .icon(imageName: "C"), priority: 1, action: { _ in pressed.append("c") })
        ]
        // 100pt holds two 44pt cells: one item and the "…" cell; the higher priority stays.
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: rightButtons, hasBack: false, columnLength: 100.0)
        XCTAssertEqual(placement.columnLayout?.visibleItems, [0])
        let items = navigationBarOverflowItems(placement: placement)
        XCTAssertEqual(items.map(\.id), [AnyHashable("b"), AnyHashable("c")])
        XCTAssertEqual(items.map(\.title), ["B", "C"])
        for item in items {
            item.action(UIView())
        }
        XCTAssertEqual(pressed, ["b", "c"])
    }

    func test_buttonEquality_ignoresActions() {
        let lhs = NavigationBarComponent.Button(id: "a", content: .more, action: { _ in })
        let rhs = NavigationBarComponent.Button(id: "a", content: .more, action: { _ in print("other") })
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, NavigationBarComponent.Button(id: "a", content: .icon(imageName: "A"), action: { _ in }))
        XCTAssertNotEqual(lhs, lhs.withOverflow(NavigationBarComponent.OverflowInfo(title: "More", iconName: nil, priority: nil)))
    }

    func test_titleWidth_clearsTheWiderSide() {
        XCTAssertEqual(navigationBarTitleAvailableWidth(rowWidth: 390.0, leftExtent: 60.0, rightExtent: 104.0), 166.0)
    }

    func test_centeredFrame_isOnWholePoints() {
        XCTAssertEqual(navigationBarCenteredFrame(size: CGSize(width: 101.0, height: 21.0), rowSize: CGSize(width: 390.0, height: 44.0)), CGRect(x: 144.0, y: 11.0, width: 101.0, height: 21.0))
    }

    func test_centerContentInsets_matchTheStoryListBand() {
        let insets = navigationBarCenterContentInsets(leftExtent: 60.0, rightExtent: 104.0)
        XCTAssertEqual(insets.left, 48.0)
        XCTAssertEqual(insets.right, 108.0)
    }
}
