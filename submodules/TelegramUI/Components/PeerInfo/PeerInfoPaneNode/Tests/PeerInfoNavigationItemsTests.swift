import XCTest
import UIKit
import AsyncDisplayKit
import Display
import UIKitRuntimeUtils
import PeerInfoPaneNode

final class PeerInfoNavigationItemsTests: XCTestCase {
    private let image = UIGraphicsImageRenderer(size: CGSize(width: 2.0, height: 2.0)).image { _ in }

    private func resources(edit: String = "Edit") -> PeerInfoNavigationItemResources {
        return PeerInfoNavigationItemResources(edit: edit, cancel: "Cancel", done: "Done", qrCodeImage: self.image, qrCodeLabel: "QR Code", postStoryImage: self.image, postStoryLabel: "Post Story", standaloneSearchImage: self.image, searchWithTagsImage: self.image, searchLabel: "Search", moreLabel: "More")
    }

    private func set(_ left: [PeerInfoHeaderNavigationButtonKey], _ right: [PeerInfoHeaderNavigationButtonKey]) -> PeerInfoNavigationButtonSet {
        return PeerInfoNavigationButtonSet(left: left, right: right)
    }

    func test_reapplyingASet_setsNothing() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        var calls = 0
        let _ = navigationItem.addSetMultipleRightBarButtonItemsListener { _, _ in calls += 1 }
        items.apply(self.set([], [.postStory, .edit]), resources: self.resources(), to: navigationItem, animated: false)
        let first = navigationItem.rightBarButtonItems ?? []
        items.apply(self.set([], [.postStory, .edit]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(zip(first, navigationItem.rightBarButtonItems ?? []).allSatisfy { $0 === $1 })
    }

    // Telegram's bar draws `rightBarButtonItems[0]` leftmost (`navigationBarContent` reverses them; ItemList's
    // [search, Edit] keeps Edit outermost): [post story][Edit] is listed as the profile lists it.
    func test_rightItems_leftmostFirst_asTheBarDrawsThem() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([], [.postStory, .edit]), resources: self.resources(), to: navigationItem, animated: false)
        let right = navigationItem.rightBarButtonItems ?? []
        XCTAssertEqual(right.count, 2)
        XCTAssertTrue(right.first === items.existingItem(for: .postStory))
        XCTAssertEqual(right.last?.title, "Edit")
    }

    // Editing: the bar's close (X) in the back slot (the bar maps a `___close` left item to it and runs the item's
    // action), named Cancel for VoiceOver, and the accent checkmark.
    func test_editing_closeAndTheAccentCheckmark() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([.cancel], [.done]), resources: self.resources(), to: navigationItem, animated: false)
        XCTAssertEqual(navigationItem.leftBarButtonItem?.title, "___close")
        XCTAssertEqual(navigationItem.leftBarButtonItem?.accessibilityLabel, "Cancel")
        XCTAssertEqual(navigationItem.rightBarButtonItems?.first?.title, "___done")
        XCTAssertEqual(navigationItem.rightBarButtonItems?.first?.style, .done)
        XCTAssertEqual(navigationItem.rightBarButtonItems?.first?.accessibilityLabel, "Done")
        items.apply(self.set([], [.edit]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertNil(navigationItem.leftBarButtonItem)
    }

    func test_imageItems_areTemplates_withLabels() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([.qrCode], [.searchWithTags, .postStory]), resources: self.resources(), to: navigationItem, animated: false)
        for (key, label) in [(PeerInfoHeaderNavigationButtonKey.qrCode, "QR Code"), (.searchWithTags, "Search"), (.postStory, "Post Story")] {
            let item = items.existingItem(for: key)
            XCTAssertEqual(item?.image?.renderingMode, .alwaysTemplate, "\(key)")
            XCTAssertEqual(item?.accessibilityLabel, label, "\(key)")
        }
    }

    // Saved Messages' Chats tab: search is a pill of its own beside the "…" (the bar would otherwise put the two icons in
    // one), so switching to Media leaves the "…" pill as it is and only the search pill comes and goes.
    func test_searchItems_haveTheirOwnPill_theSlotDoesNot() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([], [.searchWithTags, .more]), resources: self.resources(), to: navigationItem, animated: false)
        XCTAssertEqual(items.existingItem(for: .searchWithTags)?.requiresOwnSection, true)
        XCTAssertEqual(items.existingItem(for: .more)?.requiresOwnSection, false)
        items.apply(self.set([], [.standaloneSearch, .more]), resources: self.resources(), to: navigationItem, animated: false)
        XCTAssertEqual(items.existingItem(for: .standaloneSearch)?.requiresOwnSection, true)
    }

    // Switching panes while the pane set shows: the same item throughout, the slot's key and label following.
    func test_slotKeys_shareOneItem() {
        let slotNode = ASDisplayNode()
        let items = PeerInfoNavigationItems(slotNode: slotNode)
        let navigationItem = UINavigationItem()
        items.apply(self.set([], [.more]), resources: self.resources(), to: navigationItem, animated: false)
        let slotItem = navigationItem.rightBarButtonItems?.first
        XCTAssertTrue(slotItem?.customDisplayNode === slotNode)
        for key in [PeerInfoHeaderNavigationButtonKey.search, .sort, .more] {
            items.apply(self.set([], [key]), resources: self.resources(), to: navigationItem, animated: true)
            XCTAssertTrue(navigationItem.rightBarButtonItems?.first === slotItem, "\(key)")
            XCTAssertEqual(items.appliedSlotKey, key)
        }
        XCTAssertEqual(slotItem?.accessibilityLabel, "More")
        items.apply(self.set([], [.search]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertEqual(slotItem?.accessibilityLabel, "Search")
        items.apply(self.set([], [.edit]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertNil(items.appliedSlotKey)
    }

    // Late data: Edit was there, post story arrives; Edit keeps its item.
    func test_addingAnItem_keepsTheOthersIdentities() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([], [.edit]), resources: self.resources(), to: navigationItem, animated: false)
        let edit = navigationItem.rightBarButtonItems?.first
        items.apply(self.set([], [.postStory, .edit]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertTrue(navigationItem.rightBarButtonItems?.last === edit)
        XCTAssertEqual(navigationItem.rightBarButtonItems?.count, 2)
    }

    func test_animatedFlag_reachesTheItem() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        var flags: [Bool] = []
        let _ = navigationItem.addSetMultipleRightBarButtonItemsListener { _, animated in flags.append(animated) }
        items.apply(self.set([], [.edit]), resources: self.resources(), to: navigationItem, animated: false)
        items.apply(self.set([], [.more]), resources: self.resources(), to: navigationItem, animated: true)
        XCTAssertEqual(flags, [false, true])
    }

    // New strings or theme images make new items, applied without animation.
    func test_newResources_rebuildTheItems_withoutAnimation() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        var flags: [Bool] = []
        let _ = navigationItem.addSetMultipleRightBarButtonItemsListener { _, animated in flags.append(animated) }
        items.apply(self.set([], [.edit]), resources: self.resources(), to: navigationItem, animated: false)
        items.apply(self.set([], [.edit]), resources: self.resources(edit: "Modifier"), to: navigationItem, animated: true)
        XCTAssertEqual(navigationItem.rightBarButtonItems?.first?.title, "Modifier")
        XCTAssertEqual(flags, [false, false])
    }

    // The slot item hosts the same node whatever the strings or theme, so it outlives them: a new item would re-host the
    // node under a new button.
    func test_newResources_keepTheSlotItem() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        items.apply(self.set([], [.search]), resources: self.resources(), to: navigationItem, animated: false)
        let slotItem = navigationItem.rightBarButtonItems?.first
        var labels = self.resources(edit: "Modifier")
        labels.searchLabel = "Rechercher"
        items.apply(self.set([], [.search]), resources: labels, to: navigationItem, animated: true)
        XCTAssertTrue(navigationItem.rightBarButtonItems?.first === slotItem)
        XCTAssertEqual(slotItem?.accessibilityLabel, "Rechercher")
    }

    func test_itemTap_performsItsKey() {
        let items = PeerInfoNavigationItems(slotNode: ASDisplayNode())
        let navigationItem = UINavigationItem()
        var performed: [PeerInfoHeaderNavigationButtonKey] = []
        items.performAction = { performed.append($0) }
        items.apply(self.set([.cancel], [.done]), resources: self.resources(), to: navigationItem, animated: false)
        navigationItem.rightBarButtonItems?.first?.performActionOnTarget()
        navigationItem.leftBarButtonItem?.performActionOnTarget()
        XCTAssertEqual(performed, [.done, .cancel])
    }
}
