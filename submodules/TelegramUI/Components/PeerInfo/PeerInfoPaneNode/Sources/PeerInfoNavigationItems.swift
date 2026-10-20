import Foundation
import UIKit
import AsyncDisplayKit
import Display
import UIKitRuntimeUtils

/// What the profile's bar items show: strings and theme images.
public struct PeerInfoNavigationItemResources: Equatable {
    public var edit: String
    public var cancel: String
    public var done: String
    public var qrCodeImage: UIImage?
    public var qrCodeLabel: String
    public var postStoryImage: UIImage?
    public var postStoryLabel: String
    public var standaloneSearchImage: UIImage?
    public var searchWithTagsImage: UIImage?
    public var searchLabel: String
    public var moreLabel: String

    public init(edit: String, cancel: String, done: String, qrCodeImage: UIImage?, qrCodeLabel: String, postStoryImage: UIImage?, postStoryLabel: String, standaloneSearchImage: UIImage?, searchWithTagsImage: UIImage?, searchLabel: String, moreLabel: String) {
        self.edit = edit
        self.cancel = cancel
        self.done = done
        self.qrCodeImage = qrCodeImage
        self.qrCodeLabel = qrCodeLabel
        self.postStoryImage = postStoryImage
        self.postStoryLabel = postStoryLabel
        self.standaloneSearchImage = standaloneSearchImage
        self.searchWithTagsImage = searchWithTagsImage
        self.searchLabel = searchLabel
        self.moreLabel = moreLabel
    }
}

/// The profile's bar items (spec 2026-10-16-peer-info-navigation-bar-design.md): one `UIBarButtonItem` per button,
/// made once, so re-applying a set changes no identity and the bar animates only real changes. More, search and sort
/// are one item hosting `slotNode`, whose icon animates between them; that node reports its own taps, with the source a
/// context menu is extracted from.
public final class PeerInfoNavigationItems {
    public var performAction: ((PeerInfoHeaderNavigationButtonKey) -> Void)?

    private let slotNode: ASDisplayNode
    private var resources: PeerInfoNavigationItemResources?
    private var items: [PeerInfoHeaderNavigationButtonKey: UIBarButtonItem] = [:]
    private var appliedSet: PeerInfoNavigationButtonSet?

    public init(slotNode: ASDisplayNode) {
        self.slotNode = slotNode
    }

    /// The key the slot shows in the applied set, nil when the set has none.
    public var appliedSlotKey: PeerInfoHeaderNavigationButtonKey? {
        return self.appliedSet?.right.first(where: peerInfoNavigationKeyUsesSlot)
    }

    public func existingItem(for key: PeerInfoHeaderNavigationButtonKey) -> UIBarButtonItem? {
        return self.items[peerInfoNavigationKeyUsesSlot(key) ? .moreSearchSort : key]
    }

    public func apply(_ set: PeerInfoNavigationButtonSet, resources: PeerInfoNavigationItemResources, to navigationItem: UINavigationItem, animated: Bool) {
        var animated = animated
        if self.resources != resources {
            // New strings or theme images: new items, without animation. The slot item stays: it hosts the same node,
            // and its label is set below.
            self.resources = resources
            self.items = self.items.filter { $0.key == .moreSearchSort }
            animated = false
        }
        self.appliedSet = set

        let left = set.left.first.flatMap { self.item(for: $0, resources: resources) }
        if navigationItem.leftBarButtonItem !== left {
            navigationItem.setLeftBarButton(left, animated: animated)
        }

        // Telegram's bar draws `rightBarButtonItems[0]` leftmost, the order the profile lists its buttons in.
        let right = set.right.compactMap { self.item(for: $0, resources: resources) }
        let current = navigationItem.rightBarButtonItems ?? []
        if current.count != right.count || zip(current, right).contains(where: { $0 !== $1 }) {
            navigationItem.setRightBarButtonItems(right, animated: animated)
        }

        if let slotKey = self.appliedSlotKey, let slotItem = self.items[.moreSearchSort] {
            slotItem.accessibilityLabel = slotKey == .search ? resources.searchLabel : resources.moreLabel
        }
    }

    private func item(for key: PeerInfoHeaderNavigationButtonKey, resources: PeerInfoNavigationItemResources) -> UIBarButtonItem? {
        let itemKey: PeerInfoHeaderNavigationButtonKey = peerInfoNavigationKeyUsesSlot(key) ? .moreSearchSort : key
        if let current = self.items[itemKey] {
            return current
        }
        let item: UIBarButtonItem
        switch itemKey {
        case .moreSearchSort:
            guard let slotItem = UIBarButtonItem(customDisplayNode: self.slotNode) else {
                return nil
            }
            item = slotItem
        case .edit:
            item = UIBarButtonItem(title: resources.edit, style: .plain, target: nil, action: nil)
        case .cancel:
            // The bar's close (X) in the back slot, which runs the item's action (`navigationBarContent`).
            item = UIBarButtonItem(title: "___close", style: .plain, target: nil, action: nil)
            item.accessibilityLabel = resources.cancel
        case .done, .selectionDone:
            item = UIBarButtonItem(title: "___done", style: .done, target: nil, action: nil)
            item.accessibilityLabel = resources.done
            // iPhone Duo: in the row, where the Edit it replaces is (a text button, `peerInfoNavigationButtonIsIcon`).
            item.staysInRow = true
        case .qrCode:
            item = self.imageItem(resources.qrCodeImage, label: resources.qrCodeLabel)
        case .postStory:
            item = self.imageItem(resources.postStoryImage, label: resources.postStoryLabel)
        case .standaloneSearch, .searchWithTags:
            item = self.imageItem(itemKey == .searchWithTags ? resources.searchWithTagsImage : resources.standaloneSearchImage, label: resources.searchLabel)
            // A pill of its own beside the "…": a pane without search (Media) keeps the "…" pill as it is, and only
            // the search pill comes and goes.
            item.requiresOwnSection = true
        case .back, .select, .editPhoto, .editVideo, .more, .search, .sort:
            // Back is the bar's own; the others are produced by no set (more/search/sort map to the slot above).
            return nil
        }
        if itemKey != .moreSearchSort {
            item.setCustomAction({ [weak self] in
                self?.performAction?(key)
            })
        }
        self.items[itemKey] = item
        return item
    }

    private func imageItem(_ image: UIImage?, label: String) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: image?.withRenderingMode(.alwaysTemplate), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = label
        return item
    }
}
