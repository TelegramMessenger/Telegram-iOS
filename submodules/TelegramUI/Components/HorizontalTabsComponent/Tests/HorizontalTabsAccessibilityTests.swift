import Foundation
import UIKit
import XCTest
import ComponentFlow
import TelegramPresentationData
@testable import HorizontalTabsComponent

/// VoiceOver semantics of `HorizontalTabsComponent`, the chat list's folder tabs: one button per tab, titled exactly as
/// shown, the current one `.selected`, activating one runs the tap action.
final class HorizontalTabsAccessibilityTests: XCTestCase {
    private func makeView(titles: [String], selectedIndex: Int, actions: [() -> Void]? = nil) -> (ComponentView<Empty>, HorizontalTabsComponent.View) {
        let tabs = titles.enumerated().map { index, title in
            HorizontalTabsComponent.Tab(
                id: AnyHashable(index),
                content: .title(HorizontalTabsComponent.Tab.Title(text: title, entities: [], enableAnimations: false)),
                badge: index == 2 ? HorizontalTabsComponent.Tab.Badge(title: "267", isAccent: true) : nil,
                action: actions?[index] ?? {}
            )
        }
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(
            transition: .immediate,
            component: AnyComponent(HorizontalTabsComponent(context: nil, theme: defaultDarkPresentationTheme, tabs: tabs, selectedTab: AnyHashable(selectedIndex), isEditing: false)),
            environment: {},
            containerSize: CGSize(width: 370.0, height: 44.0)
        )
        let view = componentView.view as! HorizontalTabsComponent.View
        view.frame = CGRect(origin: .zero, size: CGSize(width: 370.0, height: 44.0))
        return (componentView, view)
    }
    
    func testTabsExposeSelectedTrait() {
        let (host, view) = self.makeView(titles: ["All", "Forums", "Unread"], selectedIndex: 0)
        withExtendedLifetime(host) {
            let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
            XCTAssertEqual(elements.map { $0.accessibilityLabel }, ["All", "Forums", "Unread"])
            XCTAssertEqual(elements.map { $0.accessibilityTraits.contains(.selected) }, [true, false, false])
            XCTAssertTrue(elements.allSatisfy { $0.accessibilityTraits.contains(.button) })
            XCTAssertTrue(view.accessibilityTraits.contains(.tabBar))
            XCTAssertFalse(view.isAccessibilityElement)
        }
    }
    
    func testTabsAreExposedOnceInOrder() {
        let (host, view) = self.makeView(titles: ["All", "Forums", "Unread"], selectedIndex: 1)
        withExtendedLifetime(host) {
            let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
            XCTAssertEqual(elements.count, 3)
            let xs = elements.map { $0.accessibilityFrameInContainerSpace.minX }
            XCTAssertEqual(xs, xs.sorted())
            XCTAssertTrue(elements.allSatisfy { $0.accessibilityFrameInContainerSpace.width > 0.0 })
        }
    }
    
    func testActivationRunsTheTabAction() {
        var activated: [Int] = []
        let (host, view) = self.makeView(titles: ["All", "Forums", "Unread"], selectedIndex: 0, actions: [{ activated.append(0) }, { activated.append(1) }, { activated.append(2) }])
        withExtendedLifetime(host) {
            let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
            XCTAssertTrue(elements[1].accessibilityActivate())
            XCTAssertEqual(activated, [1])
        }
    }
    
    func testBadgeIsTheValueUnlessTheCallSiteDescribesIt() {
        let (host, view) = self.makeView(titles: ["All", "Forums", "Unread"], selectedIndex: 0)
        withExtendedLifetime(host) {
            let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
            XCTAssertEqual(elements.map { $0.accessibilityValue }, [nil, nil, "267"])
        }
        
        let tab = HorizontalTabsComponent.Tab(
            id: AnyHashable(0),
            content: .title(HorizontalTabsComponent.Tab.Title(text: "Unread", entities: [], enableAnimations: false)),
            badge: HorizontalTabsComponent.Tab.Badge(title: "267", isAccent: true),
            action: {},
            accessibilityValue: "267 unread messages"
        )
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(transition: .immediate, component: AnyComponent(HorizontalTabsComponent(context: nil, theme: defaultDarkPresentationTheme, tabs: [tab], selectedTab: nil, isEditing: false)), environment: {}, containerSize: CGSize(width: 370.0, height: 44.0))
        let described = (componentView.view!.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
        XCTAssertEqual(described.map { $0.accessibilityValue }, ["267 unread messages"])
    }
    
    // In edit mode a folder's delete badge is a custom action on its tab that runs the same delete action.
    func testDeleteBadgeIsACustomAction() {
        var deleted = 0
        let tabs = [
            HorizontalTabsComponent.Tab(id: AnyHashable(0), content: .title(HorizontalTabsComponent.Tab.Title(text: "All", entities: [], enableAnimations: false)), badge: nil, action: {}),
            HorizontalTabsComponent.Tab(id: AnyHashable(1), content: .title(HorizontalTabsComponent.Tab.Title(text: "Forums", entities: [], enableAnimations: false)), badge: nil, action: {}, deleteAction: { deleted += 1 }, deleteAccessibilityLabel: "Delete")
        ]
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(transition: .immediate, component: AnyComponent(HorizontalTabsComponent(context: nil, theme: defaultDarkPresentationTheme, tabs: tabs, selectedTab: AnyHashable(0), isEditing: true)), environment: {}, containerSize: CGSize(width: 370.0, height: 44.0))
        let view = componentView.view as! HorizontalTabsComponent.View
        let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
        XCTAssertEqual(elements.count, 2)
        XCTAssertNil(elements[0].accessibilityCustomActions)
        let actions = elements[1].accessibilityCustomActions ?? []
        XCTAssertEqual(actions.map { $0.name }, ["Delete"])
        XCTAssertTrue(actions[0].actionHandler?(actions[0]) ?? false)
        XCTAssertEqual(deleted, 1)
    }
    
    // A tab's long-press menu is a custom action that opens the same menu, without a gesture.
    func testContextMenuIsACustomAction() {
        var openedWithGesture: [Bool] = []
        let tabs = [
            HorizontalTabsComponent.Tab(id: AnyHashable(0), content: .title(HorizontalTabsComponent.Tab.Title(text: "All", entities: [], enableAnimations: false)), badge: nil, action: {}, contextAction: { _, gesture in openedWithGesture.append(gesture != nil) }, contextAccessibilityLabel: "More"),
            HorizontalTabsComponent.Tab(id: AnyHashable(1), content: .title(HorizontalTabsComponent.Tab.Title(text: "Forums", entities: [], enableAnimations: false)), badge: nil, action: {})
        ]
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(transition: .immediate, component: AnyComponent(HorizontalTabsComponent(context: nil, theme: defaultDarkPresentationTheme, tabs: tabs, selectedTab: AnyHashable(0), isEditing: false)), environment: {}, containerSize: CGSize(width: 370.0, height: 44.0))
        let view = componentView.view as! HorizontalTabsComponent.View
        let elements = (view.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
        XCTAssertEqual(elements.count, 2)
        XCTAssertNil(elements[1].accessibilityCustomActions)
        let actions = elements[0].accessibilityCustomActions ?? []
        XCTAssertEqual(actions.map { $0.name }, ["More"])
        XCTAssertTrue(actions[0].actionHandler?(actions[0]) ?? false)
        XCTAssertEqual(openedWithGesture, [false])
    }
}
