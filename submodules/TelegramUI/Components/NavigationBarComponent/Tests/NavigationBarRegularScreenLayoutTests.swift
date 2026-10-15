import XCTest
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
@testable import NavigationBarComponent

/// A screen's node of a given size (`measure` of a plain node returns whatever it is offered).
private final class SizedNode: ASDisplayNode {
    private let size: CGSize

    init(size: CGSize) {
        self.size = size
        super.init()
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return self.size
    }
}

final class NavigationBarRegularScreenLayoutTests: XCTestCase {
    private func makeTheme() -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white)
    }

    private func button(_ id: String, _ content: NavigationBarComponent.Button.Content, tint: NavigationBarComponent.Button.Tint = .generic) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: content, tint: tint, overflow: NavigationBarComponent.OverflowInfo(title: id, iconName: nil, priority: 0), action: { _ in })
    }

    func test_nodeButton_goesIntoTheColumn() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("node", .node(SizedNode(size: CGSize(width: 44.0, height: 44.0))))], hasBack: true, columnLength: 400.0)
        XCTAssertEqual(placement.columnItems.map(\.id), [AnyHashable("node")])
        XCTAssertTrue(placement.rowRightSections.isEmpty)
    }

    // A node that draws text (Calls' "Delete All", a mini app's "Close") would be cut by the 48pt column: it stays in the row.
    func test_wideNodeButton_staysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("deleteAll", .node(SizedNode(size: CGSize(width: 95.0, height: 44.0))))], hasBack: true, columnLength: 400.0)
        XCTAssertTrue(placement.columnItems.isEmpty)
        XCTAssertEqual(placement.rowRightSections.flatMap { $0 }.map(\.id), [AnyHashable("deleteAll")])
    }

    func test_imageButton_goesToTheColumn() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("image", .image(UIImage()))], hasBack: true, columnLength: 400.0)
        XCTAssertEqual(placement.columnItems.map(\.id), [AnyHashable("image")])
    }

    func test_column_accentButtonTakesTheTrailingCircle() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("a", .icon(imageName: "A")), self.button("done", .icon(imageName: "Navigation/Done"), tint: .accent)], hasBack: true, columnLength: 400.0)
        XCTAssertEqual(placement.trailingCircleItem?.id, AnyHashable("done"))
        XCTAssertEqual(placement.columnItems.map(\.id), [AnyHashable("a")])
        XCTAssertNotNil(placement.columnLayout?.trailingFrame)
        XCTAssertTrue(placement.rowRightSections.isEmpty)
    }

    // Without a column the accent button stays in the row, in the row's own circle beside the capsule (spec
    // 2026-10-15-accent-right-button-circle-design.md), not in a column circle.
    func test_noColumn_accentButtonStaysInTheRow() {
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: [self.button("a", .icon(imageName: "A")), self.button("done", .icon(imageName: "Navigation/Done"), tint: .accent)], hasBack: true, columnLength: nil)
        XCTAssertNil(placement.trailingCircleItem)
        XCTAssertEqual(placement.rowRightSections.map { $0.map(\.id) }, [[AnyHashable("a")], [AnyHashable("done")]])
    }

    func test_capsuleTint_isSharedOrGeneric() {
        XCTAssertEqual(navigationBarCapsuleTint([]), .generic)
        XCTAssertEqual(navigationBarCapsuleTint([self.button("d", .icon(imageName: "D"), tint: .accent)]), .accent)
        XCTAssertEqual(navigationBarCapsuleTint([self.button("d", .icon(imageName: "D"), tint: .accent), self.button("a", .icon(imageName: "A"))]), .generic)
    }

    func test_contentColor_followsTintAndEnabledState() {
        let theme = self.makeTheme()
        XCTAssertTrue(navigationButtonContentColor(theme: theme, tint: .generic, isEnabled: true, isText: true) === theme.buttonColor)
        XCTAssertTrue(navigationButtonContentColor(theme: theme, tint: .generic, isEnabled: false, isText: true) === theme.disabledButtonColor)
        // The old bar tinted images with the button color whatever the enabled state.
        XCTAssertTrue(navigationButtonContentColor(theme: theme, tint: .generic, isEnabled: false, isText: false) === theme.buttonColor)
        XCTAssertTrue(navigationButtonContentColor(theme: theme, tint: .accent, isEnabled: true, isText: false) === theme.accentForegroundColor)
    }

    func test_overflowItem_carriesTheButtonImage() {
        let image = UIImage()
        let rightButtons = (0 ..< 3).map { index in
            NavigationBarComponent.Button(id: "b\(index)", content: .image(image), overflow: NavigationBarComponent.OverflowInfo(title: "B\(index)", iconName: nil, priority: 0, image: image), action: { _ in })
        }
        let placement = navigationBarButtonPlacement(leftButton: nil, rightButtons: rightButtons, hasBack: false, columnLength: 100.0)
        let items = navigationBarOverflowItems(placement: placement)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.image === image })
    }

    func test_buttonEquality_includesEnabledAndTint() {
        let base = NavigationBarComponent.Button(id: "a", content: .more, action: { _ in })
        XCTAssertNotEqual(base, NavigationBarComponent.Button(id: "a", content: .more, isEnabled: false, action: { _ in }))
        XCTAssertNotEqual(base, NavigationBarComponent.Button(id: "a", content: .more, tint: .accent, action: { _ in }))
    }

    func test_contentEquality_includesBadgeAndBackContextAction() {
        let plain = NavigationBarComponent.Content(title: .text("T"), back: .back, leftButton: nil, rightButtons: [], backPressed: {})
        XCTAssertNotEqual(plain, NavigationBarComponent.Content(title: .text("T"), back: .back, leftButton: nil, rightButtons: [], backPressed: {}, badge: "3"))
        XCTAssertNotEqual(plain, NavigationBarComponent.Content(title: .text("T"), back: .back, leftButton: nil, rightButtons: [], backPressed: {}, backContextAction: { _, _ in }))
        XCTAssertNotEqual(plain, NavigationBarComponent.Content(title: .text("T"), back: .close, leftButton: nil, rightButtons: [], backPressed: {}))
    }
}
