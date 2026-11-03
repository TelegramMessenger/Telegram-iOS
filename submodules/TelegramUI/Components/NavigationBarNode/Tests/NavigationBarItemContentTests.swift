import XCTest
import UIKit
import AsyncDisplayKit
import Display
import NavigationBarComponent
@testable import NavigationBarNode

private final class ActionTarget: NSObject {
    var count = 0

    @objc func fire() {
        self.count += 1
    }
}

/// The spec's mapping table (section "`NavigationBarNode`"), one case per row.
final class NavigationBarItemContentTests: XCTestCase {
    private func content(_ item: UINavigationItem?, previous: NavigationPreviousAction? = nil, hidesBackButton: Bool = false, backPressed: @escaping () -> Void = {}) -> NavigationBarComponent.Content {
        return navigationBarContent(item: item, previousItem: previous, hidesBackButton: hidesBackButton, backPressed: backPressed, backContextAction: nil)
    }

    func test_title_isText() {
        XCTAssertEqual(self.content(UINavigationItem(title: "Settings")).title, .text("Settings"))
    }

    func test_titleView_leavesTheTextTitleEmpty() {
        let item = UINavigationItem(title: "Settings")
        item.titleView = UIView()
        XCTAssertEqual(self.content(item).title, .text(""))
    }

    func test_previousItem_showsBackWithTheBadge() {
        let item = UINavigationItem(title: "Chat")
        item.badge = "5"
        var pressed = 0
        let content = self.content(item, previous: .item(UINavigationItem(title: "Chats")), backPressed: { pressed += 1 })
        XCTAssertEqual(content.back, .back)
        XCTAssertEqual(content.badge, "5")
        content.backPressed()
        XCTAssertEqual(pressed, 1)
    }

    func test_previousClose_showsClose() {
        XCTAssertEqual(self.content(UINavigationItem(title: "Sheet"), previous: .close).back, .close)
    }

    func test_backAppearanceLeftItem_isBackRunningItsAction() {
        let target = ActionTarget()
        let item = UINavigationItem(title: "Media")
        item.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: "Back", target: target, action: #selector(ActionTarget.fire))
        var pressed = 0
        let content = self.content(item, previous: .item(UINavigationItem()), backPressed: { pressed += 1 })
        XCTAssertEqual(content.back, .back)
        XCTAssertNil(content.leftButton)
        content.backPressed()
        XCTAssertEqual(target.count, 1)
        XCTAssertEqual(pressed, 0)
    }

    func test_closeLeftItem_isCloseRunningItsAction() {
        let target = ActionTarget()
        let item = UINavigationItem(title: "Sheet")
        item.leftBarButtonItem = UIBarButtonItem(title: "___close", style: .plain, target: target, action: #selector(ActionTarget.fire))
        let content = self.content(item)
        XCTAssertEqual(content.back, .close)
        content.backPressed()
        XCTAssertEqual(target.count, 1)
    }

    func test_leftItem_isTheLeftButton_andHidesBack() {
        let item = UINavigationItem(title: "Edit")
        item.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
        let content = self.content(item, previous: .item(UINavigationItem()))
        XCTAssertNil(content.back)
        XCTAssertEqual(content.leftButton?.content, .text(title: "Cancel", isBold: false))
    }

    func test_hidesBackButton_withoutLeftItem_showsNothing() {
        let content = self.content(UINavigationItem(title: "Chat"), previous: .item(UINavigationItem()), hidesBackButton: true)
        XCTAssertNil(content.back)
        XCTAssertNil(content.leftButton)
    }

    func test_hidesBackButton_keepsALeftItem() {
        let item = UINavigationItem(title: "Edit")
        item.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
        XCTAssertNotNil(self.content(item, hidesBackButton: true).leftButton)
    }

    func test_emptyLeftItem_hidesTheBackButton() {
        let item = UINavigationItem(title: "Wallet")
        item.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        let content = self.content(item, previous: .item(UINavigationItem()))
        XCTAssertNil(content.back)
        XCTAssertNil(content.leftButton)
    }

    func test_emptyRightItem_isDropped() {
        let item = UINavigationItem(title: "Form")
        item.rightBarButtonItems = [UIBarButtonItem(title: "", style: .plain, target: nil, action: nil), UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil)]
        XCTAssertEqual(self.content(item).rightButtons.map(\.content), [.text(title: "Done", isBold: true)])
    }

    func test_rightItems_keepTheirOnScreenOrder() {
        let first = UIBarButtonItem(title: "A", style: .plain, target: nil, action: nil)
        let second = UIBarButtonItem(title: "B", style: .plain, target: nil, action: nil)
        let item = UINavigationItem(title: "T")
        item.rightBarButtonItems = [first, second]
        // rightButtons[0] is the rightmost; the old bar drew items[0] leftmost.
        XCTAssertEqual(self.content(item).rightButtons.map(\.id), [AnyHashable(ObjectIdentifier(second)), AnyHashable(ObjectIdentifier(first))])
    }

    func test_sentinels_mapToTheirIcons() {
        XCTAssertEqual(navigationBarButton(for: UIBarButtonItem(title: "___close", style: .plain, target: nil, action: nil)).content, .icon(imageName: "Navigation/Close"))
        XCTAssertEqual(navigationBarButton(for: UIBarButtonItem(title: "___clear", style: .plain, target: nil, action: nil)).content, .icon(imageName: "Chat/Context Menu/Delete"))
        XCTAssertEqual(navigationBarButton(for: UIBarButtonItem(title: "___done", style: .plain, target: nil, action: nil)).content, .icon(imageName: "Navigation/Done"))
    }

    func test_done_isAccent_orAccentDisabled() {
        let done = UIBarButtonItem(title: "___done", style: .plain, target: nil, action: nil)
        XCTAssertEqual(navigationBarButton(for: done).tint, .accent)
        done.isEnabled = false
        XCTAssertEqual(navigationBarButton(for: done).tint, .accentDisabled)
        XCTAssertFalse(navigationBarButton(for: done).isEnabled)
    }

    func test_imageAndNodeItems() {
        let image = UIImage()
        XCTAssertEqual(navigationBarButton(for: UIBarButtonItem(image: image, style: .plain, target: nil, action: nil)).content, .image(image))
        let node = ASDisplayNode()
        XCTAssertEqual(navigationBarButton(for: UIBarButtonItem(customDisplayNode: node)).content, .node(node))
    }

    // An item that asks for its own pill says so to the bar; by default an item does not.
    func test_requiresOwnSection_reachesTheButton() {
        let item = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        XCTAssertFalse(navigationBarButton(for: item).requiresOwnSection)
        item.requiresOwnSection = true
        XCTAssertTrue(navigationBarButton(for: item).requiresOwnSection)
    }

    func test_label_isAccessibilityLabelElseTitle_neverASentinel() {
        let titled = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        XCTAssertEqual(navigationBarButton(for: titled).overflow?.title, "Edit")
        let labelled = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        labelled.accessibilityLabel = "Search"
        XCTAssertEqual(navigationBarButton(for: labelled).overflow?.title, "Search")
        XCTAssertNil(navigationBarButton(for: UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)).overflow)
        XCTAssertNil(navigationBarButton(for: UIBarButtonItem(title: "___close", style: .plain, target: nil, action: nil)).overflow)
    }

    func test_buttonAction_runsTheItem() {
        let target = ActionTarget()
        let button = navigationBarButton(for: UIBarButtonItem(title: "Edit", style: .plain, target: target, action: #selector(ActionTarget.fire)))
        button.action(UIView())
        XCTAssertEqual(target.count, 1)
    }

    // `UIBarButtonItem(customDisplayNode: ASDisplayNode())` draws nothing; screens set it to keep the back button away.
    func test_bareNodeLeftItem_hidesTheBackButton() {
        let item = UINavigationItem(title: "Two-Step Verification")
        item.leftBarButtonItem = UIBarButtonItem(customDisplayNode: ASDisplayNode())
        let content = self.content(item, previous: .item(UINavigationItem()))
        XCTAssertNil(content.back)
        XCTAssertNil(content.leftButton)
    }
}
