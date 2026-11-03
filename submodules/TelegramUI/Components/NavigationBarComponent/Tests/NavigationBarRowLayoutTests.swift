import XCTest
import UIKit
import Display
import ComponentFlow
import AsyncDisplayKit
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

    // Chats: new message is accent, beside story and proxy. It takes a pill of its own; the rest share one.
    func test_accentButtonWithOthers_takesTheRowCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("compose"), self.button("story", .icon(imageName: "S")), self.button("proxy", .icon(imageName: "P"))], hasBack: false, columnLength: nil)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["compose"], ["story", "proxy"]])
    }

    // A disabled accent button takes the circle as well (its glass is the disabled accent).
    func test_disabledAccentButtonWithOthers_takesTheRowCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("done", tint: .accentDisabled), self.button("a", .icon(imageName: "A"))], hasBack: false, columnLength: nil)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["done"], ["a"]])
    }

    // Alone, the accent button stays the capsule's only item: that capsule is its circle.
    func test_loneAccentButton_staysTheCapsule() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("done")], hasBack: true, columnLength: nil)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["done"]])
    }

    // UIKit gives every prominent item a section of its own: a second accent button gets its own pill too (this
    // supersedes the accent-circle spec's ruling 1, by the user's choice of UIKit's rule, 2026-10-15).
    func test_secondAccentButton_getsItsOwnPill() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("a"), self.button("x", .icon(imageName: "X")), self.accent("b")], hasBack: false, columnLength: nil)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["a"], ["x"], ["b"]])
    }

    // iPhone Duo: the accent button goes into the column's trailing circle, as before; the row has no circle.
    func test_column_keepsTheAccentButtonInItsTrailingCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.accent("compose"), self.button("story", .icon(imageName: "S"))], hasBack: false, columnLength: 400.0)
        XCTAssertTrue(placement.rowRightSections.isEmpty)
        XCTAssertEqual(placement.trailingCircleItem?.id, AnyHashable("compose"))
    }

    // The Done of an Edit/Done toggle stays in the row, where the text Edit it replaces is, rather than taking the
    // column's trailing circle; on the left (Calls) it stays the row's left button.
    func test_column_staysInRowDone_staysInTheRow() {
        let done = NavigationBarComponent.Button(id: "done", content: .icon(imageName: "Navigation/Done"), tint: .accent, staysInRow: true, action: { _ in })
        let right = navigationBarButtonPlacement(leftButton: nil, rightButtons: [done], hasBack: true, columnLength: 400.0)
        XCTAssertNil(right.trailingCircleItem)
        XCTAssertEqual(self.sectionIds(right.rowRightSections), [["done"]])
        let left = navigationBarButtonPlacement(leftButton: done, rightButtons: [], hasBack: false, columnLength: 400.0)
        XCTAssertFalse(left.leftButtonInColumn)
        XCTAssertEqual(left.rowLeftButton?.id, AnyHashable("done"))
    }

    func test_noColumn_everyButtonStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("left", .icon(imageName: "L")), rightButtons: [self.button("a", .icon(imageName: "A")), self.button("b", .text(title: "Edit", isBold: false))], hasBack: true, columnLength: nil)
        XCTAssertNil(placement.columnLayout)
        XCTAssertFalse(placement.leftButtonInColumn)
        XCTAssertEqual(placement.rowLeftButton?.id, AnyHashable("left"))
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["a"], ["b"]])
    }

    func test_column_iconButtonsMove_textStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("left", .icon(imageName: "L")), rightButtons: [self.button("a", .icon(imageName: "A")), self.button("b", .text(title: "Edit", isBold: false))], hasBack: true, columnLength: 400.0)
        XCTAssertNotNil(placement.columnLayout)
        XCTAssertTrue(placement.leftButtonInColumn)
        XCTAssertNil(placement.rowLeftButton)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["b"]])
        XCTAssertEqual(self.ids(placement.columnItems), ["left", "a"])
        XCTAssertEqual(placement.columnLayout?.visibleItems, [0, 1])
    }

    func test_column_textLeftButtonStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: self.button("done", .text(title: "Done", isBold: true)), rightButtons: [self.button("a", .icon(imageName: "A"))], hasBack: false, columnLength: 400.0)
        XCTAssertFalse(placement.leftButtonInColumn)
        XCTAssertEqual(placement.rowLeftButton?.id, AnyHashable("done"))
        XCTAssertEqual(self.ids(placement.columnItems), ["a"])
        XCTAssertTrue(placement.rowRightSections.isEmpty)
    }

    func test_column_customButtonGoesToTheColumn() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("proxy", .custom(AnyComponent(TestButtonContentComponent())))], hasBack: false, columnLength: 400.0)
        XCTAssertEqual(self.ids(placement.columnItems), ["proxy"])
        XCTAssertTrue(placement.rowRightSections.isEmpty)
    }

    func test_columnTooShort_keepsEverythingInTheRow() {
        // 80pt cannot hold the back circle (48) + spacing (12) + one 48pt cell.
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("a", .icon(imageName: "A"))], hasBack: true, columnLength: 80.0)
        XCTAssertNil(placement.columnLayout)
        XCTAssertEqual(self.sectionIds(placement.rowRightSections), [["a"]])
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

    // The story list's band clears both sides' capsules by the same 4 pt (the title and the stories used to be allowed
    // 12 pt under the left one, a margin from the text-button bar).
    func test_centerContentInsets_clearBothSidesCapsules() {
        let insets = navigationBarCenterContentInsets(leftExtent: 60.0, rightExtent: 104.0)
        XCTAssertEqual(insets.left, 64.0)
        XCTAssertEqual(insets.right, 108.0)
    }

    private func sectionIds(_ sections: [[NavigationBarComponent.Button]]) -> [[AnyHashable]] {
        return sections.map { $0.map(\.id) }
    }

    // UIKit's sections (`_requiresOwnSection`, asked of UIKit on iOS 27, spec): a text button gets a pill of its own, so
    // Channel Administrators' Edit and search are two pills, Edit outermost.
    func test_rightSections_textBesideIcon_areTwoPills() {
        let sections = navigationBarRightSections([self.button("edit", .text(title: "Edit", isBold: false)), self.button("search", .icon(imageName: "S"))])
        XCTAssertEqual(self.sectionIds(sections), [["edit"], ["search"]])
    }

    // Neighbouring icon buttons share one pill.
    func test_rightSections_icons_shareOnePill() {
        let sections = navigationBarRightSections([self.button("search", .icon(imageName: "S")), self.button("add", .image(UIImage()))])
        XCTAssertEqual(self.sectionIds(sections), [["search", "add"]])
    }

    // Chats: the accent compose button alone, story and proxy together, as today.
    func test_rightSections_chats_areTheCircleAndTheCapsule() {
        let sections = navigationBarRightSections([self.accent("compose"), self.button("story", .icon(imageName: "S")), self.button("proxy", .icon(imageName: "P"))])
        XCTAssertEqual(self.sectionIds(sections), [["compose"], ["story", "proxy"]])
    }

    // Every prominent item gets a pill of its own (UIKit), a disabled Done included; a second one too.
    func test_rightSections_everyAccentButton_isAlone() {
        let sections = navigationBarRightSections([self.accent("a"), self.button("x", .icon(imageName: "X")), self.accent("b", tint: .accentDisabled)])
        XCTAssertEqual(self.sectionIds(sections), [["a"], ["x"], ["b"]])
    }

    func test_rightSections_twoTexts_areTwoPills() {
        let sections = navigationBarRightSections([self.button("select", .text(title: "Select", isBold: false)), self.button("edit", .text(title: "Edit", isBold: true))])
        XCTAssertEqual(self.sectionIds(sections), [["select"], ["edit"]])
    }

    // Node, custom and more buttons join their neighbours like icons; a text button in the middle splits them.
    func test_rightSections_nodeAndCustomJoin_textSplits() {
        let node = self.button("node", .node(ASDisplayNode()))
        let custom = NavigationBarComponent.Button(id: "custom", content: .custom(AnyComponent(TestButtonContentComponent())), action: { _ in })
        let sections = navigationBarRightSections([node, custom, self.button("t", .text(title: "T", isBold: false)), self.button("more", .more)])
        XCTAssertEqual(self.sectionIds(sections), [["node", "custom"], ["t"], ["more"]])
    }

    // A button asking for a pill of its own (the profile's search beside its "…") splits its icon neighbours, on both
    // sides.
    func test_rightSections_ownSectionIcon_splitsItsNeighbours() {
        let search = NavigationBarComponent.Button(id: "search", content: .icon(imageName: "S"), requiresOwnSection: true, action: { _ in })
        let sections = navigationBarRightSections([self.button("more", .node(ASDisplayNode())), search, self.button("add", .icon(imageName: "A"))])
        XCTAssertEqual(self.sectionIds(sections), [["more"], ["search"], ["add"]])
    }

    func test_rightSections_none() {
        XCTAssertTrue(navigationBarRightSections([]).isEmpty)
    }
}
