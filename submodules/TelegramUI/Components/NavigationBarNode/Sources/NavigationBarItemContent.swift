import Foundation
import UIKit
import AsyncDisplayKit
import Display
import NavigationBarComponent

/// A bar button item's label for VoiceOver and the iPhone Duo "…" menu: its accessibility label, else its title.
/// The sentinel titles (`___close`, `___done`, …) are not labels.
func navigationBarItemLabel(_ item: UIBarButtonItem) -> String? {
    if let label = item.accessibilityLabel, !label.isEmpty {
        return label
    }
    if let title = item.title, !title.isEmpty, !title.hasPrefix("___") {
        return title
    }
    return nil
}

/// Whether a bar button item draws nothing. The old bar laid such an item out at zero width; screens set one
/// (`UIBarButtonItem(customView: UIView())`, `UIBarButtonItem(customDisplayNode: ASDisplayNode())`, an empty title)
/// to keep the back button away.
func navigationBarItemIsEmpty(_ item: UIBarButtonItem) -> Bool {
    if let node = item.customDisplayNode {
        return type(of: node) == ASDisplayNode.self && (node.subnodes?.isEmpty ?? true)
    }
    return item.image == nil && (item.title ?? "").isEmpty
}

func navigationBarButton(for item: UIBarButtonItem) -> NavigationBarComponent.Button {
    let content: NavigationBarComponent.Button.Content
    var tint: NavigationBarComponent.Button.Tint = .generic
    if let node = item.customDisplayNode {
        content = .node(node)
    } else if item.title == "___close" {
        content = .icon(imageName: "Navigation/Close")
    } else if item.title == "___clear" {
        content = .icon(imageName: "Chat/Context Menu/Delete")
    } else if item.title == "___done" {
        content = .icon(imageName: "Navigation/Done")
        tint = item.isEnabled ? .accent : .accentDisabled
    } else if let image = item.image {
        content = .image(image)
    } else {
        content = .text(title: item.title ?? "", isBold: item.style == .done)
    }
    let overflow = navigationBarItemLabel(item).map { label in
        return NavigationBarComponent.OverflowInfo(title: label, iconName: nil, priority: 0, image: item.image)
    }
    return NavigationBarComponent.Button(
        id: AnyHashable(ObjectIdentifier(item)),
        content: content,
        isEnabled: item.isEnabled,
        tint: tint,
        overflow: overflow,
        requiresOwnSection: item.requiresOwnSection,
        staysInRow: item.staysInRow,
        action: { _ in
            item.performActionOnTarget()
        }
    )
}

/// The bar's content for a screen's navigation item (the spec's mapping table). A title view leaves the text title
/// empty: `NavigationBarNode` hosts title views itself.
func navigationBarContent(item: UINavigationItem?, previousItem: NavigationPreviousAction?, hidesBackButton: Bool, backPressed: @escaping () -> Void, backContextAction: ((UIView, ContextGesture) -> Void)?) -> NavigationBarComponent.Content {
    guard let item else {
        return NavigationBarComponent.Content(title: .text(""), back: nil, leftButton: nil, rightButtons: [], backPressed: backPressed)
    }

    var back: NavigationBarComponent.Back?
    var backAction: () -> Void = backPressed
    var leftButton: NavigationBarComponent.Button?
    if let leftItem = item.leftBarButtonItem {
        if leftItem.backButtonAppearance {
            back = .back
            backAction = {
                leftItem.performActionOnTarget()
            }
        } else if leftItem.title == "___close" {
            back = .close
            backAction = {
                leftItem.performActionOnTarget()
            }
        } else if !navigationBarItemIsEmpty(leftItem) {
            leftButton = navigationBarButton(for: leftItem)
        }
    } else if !hidesBackButton, let previousItem {
        switch previousItem {
        case .item:
            back = .back
        case .close:
            back = .close
        }
    }

    var rightItems: [UIBarButtonItem] = []
    if let items = item.rightBarButtonItems, !items.isEmpty {
        rightItems = items
    } else if let rightItem = item.rightBarButtonItem {
        rightItems = [rightItem]
    }
    // rightButtons[0] is the rightmost; the old bar drew items[0] leftmost.
    let rightButtons = rightItems.filter({ !navigationBarItemIsEmpty($0) }).reversed().map(navigationBarButton(for:))

    var badge: String?
    if back == .back, let value = item.badge, !value.isEmpty {
        badge = value
    }

    return NavigationBarComponent.Content(
        title: .text(item.titleView == nil ? (item.title ?? "") : ""),
        back: back,
        leftButton: leftButton,
        rightButtons: rightButtons,
        backPressed: backAction,
        badge: badge,
        backContextAction: back != nil ? backContextAction : nil
    )
}
