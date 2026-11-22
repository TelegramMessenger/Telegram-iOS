import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

/// The "Sort" bar button of a Display-bar screen (New Message): drawn as the glass bar draws its own text buttons
/// (17 pt medium, the bar's primary colour, 12 pt at each side); a long press opens the sort menu as a context gesture.
public final class ContactsSortButton: HighlightableButtonNode {
    private let referenceNode: ContextReferenceContentNode
    public let containerNode: ContextControllerSourceNode
    private let textNode: ImmediateTextNode

    public var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    public init(presentationData: PresentationData) {
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false

        super.init()

        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.textNode)
        self.addSubnode(self.containerNode)

        self.containerNode.shouldBegin = { [weak self] _ in
            guard let self, let _ = self.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let self else {
                return
            }
            self.contextAction?(self.containerNode, gesture)
        }

        self.update(theme: presentationData.theme, strings: presentationData.strings)
    }

    override public func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }

    private static let textInset: CGFloat = 12.0

    public func update(theme: PresentationTheme, strings: PresentationStrings) {
        self.textNode.attributedText = NSAttributedString(string: strings.Contacts_Sort, font: Font.medium(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        let size = self.textNode.updateLayout(CGSize(width: 100.0, height: 44.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: ContactsSortButton.textInset, y: floorToScreenPixels((44.0 - size.height) / 2.0)), size: size)

        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width + ContactsSortButton.textInset * 2.0, height: 44.0))
        self.referenceNode.frame = self.containerNode.bounds

        self.accessibilityLabel = strings.Contacts_Sort
    }

    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let size = self.textNode.updateLayout(CGSize(width: 100.0, height: 44.0))
        return CGSize(width: max(44.0, size.width + ContactsSortButton.textInset * 2.0), height: 44.0)
    }
}

/// The contact lists' sort order, as the settings hold it (`ContactSynchronizationSettings.sortOrder`), live.
public func contactsSortOrder(context: AccountContext) -> Signal<ContactsSortOrder, NoError> {
    return context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings])
    |> map { sharedData -> ContactsSortOrder in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
        return settings?.sortOrder ?? .presence
    }
    |> distinctUntilChanged
}

/// The sort menu's items: by last seen or by name, the current one checked. A choice is written to the settings
/// (and `chosen` told), so every contact list follows it.
public func contactsSortMenuItems(context: AccountContext, presentationData: PresentationData, chosen: ((ContactsSortOrder) -> Void)? = nil) -> Signal<[ContextMenuItem], NoError> {
    let updateSortOrder: (ContactsSortOrder) -> Void = { sortOrder in
        chosen?(sortOrder)
        let _ = updateContactSettingsInteractively(accountManager: context.sharedContext.accountManager, { current -> ContactSynchronizationSettings in
            var updated = current
            updated.sortOrder = sortOrder
            return updated
        }).start()
    }
    return context.sharedContext.accountManager.transaction { transaction in
        return transaction.getSharedData(ApplicationSpecificSharedDataKeys.contactSynchronizationSettings)
    }
    |> map { entry -> [ContextMenuItem] in
        let currentSettings = entry?.get(ContactSynchronizationSettings.self) ?? .defaultSettings
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Contacts_Sort_ByLastSeen, icon: { theme in return currentSettings.sortOrder == .presence ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage() }, action: { _, f in
            f(.default)
            updateSortOrder(.presence)
        }, accessibilityIsSelected: currentSettings.sortOrder == .presence)))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Contacts_Sort_ByName, icon: { theme in return currentSettings.sortOrder == .natural ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage() }, action: { _, f in
            f(.default)
            updateSortOrder(.natural)
        }, accessibilityIsSelected: currentSettings.sortOrder == .natural)))
        return items
    }
}
