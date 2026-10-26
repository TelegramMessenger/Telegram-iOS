import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import PresentationDataUtils
import Markdown
import UndoUI
import PremiumUI
import ButtonComponent
import ContextUI
import QrCodeUI
import InviteLinksUI
import PlainButtonComponent
import AnimatedCounterComponent
import BundleIconComponent
import GlassBarButtonComponent
import ResizableSheetComponent

private struct ChatFolderLinkPreviewResolvedData: Equatable {
    let title: String
    let topBadge: String?
    let descriptionText: NSAttributedString
    let listHeaderTitle: String
    let listHeaderActionItems: [AnimatedCounterComponent.Item]
    let showsListHeaderAction: Bool
    let actionButtonTitle: String?
    let actionButtonBadge: Int
    let actionButtonEnabled: Bool
    let allChatsAdded: Bool
    let canAddChatCount: Int
    let isLinkList: Bool

    static func ==(lhs: ChatFolderLinkPreviewResolvedData, rhs: ChatFolderLinkPreviewResolvedData) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.topBadge != rhs.topBadge {
            return false
        }
        if !lhs.descriptionText.isEqual(to: rhs.descriptionText) {
            return false
        }
        if lhs.listHeaderTitle != rhs.listHeaderTitle {
            return false
        }
        if lhs.listHeaderActionItems != rhs.listHeaderActionItems {
            return false
        }
        if lhs.showsListHeaderAction != rhs.showsListHeaderAction {
            return false
        }
        if lhs.actionButtonTitle != rhs.actionButtonTitle {
            return false
        }
        if lhs.actionButtonBadge != rhs.actionButtonBadge {
            return false
        }
        if lhs.actionButtonEnabled != rhs.actionButtonEnabled {
            return false
        }
        if lhs.allChatsAdded != rhs.allChatsAdded {
            return false
        }
        if lhs.canAddChatCount != rhs.canAddChatCount {
            return false
        }
        if lhs.isLinkList != rhs.isLinkList {
            return false
        }
        return true
    }
}

private func chatFolderLinkPreviewResolvedData(
    component: ChatFolderLinkPreviewScreenComponent,
    theme: PresentationTheme,
    strings: PresentationStrings,
    selectedItems: Set<EnginePeer.Id>
) -> ChatFolderLinkPreviewResolvedData {
    let isLinkList: Bool
    if case .linkList = component.subject {
        isLinkList = true
    } else {
        isLinkList = false
    }

    var allChatsAdded = false
    var canAddChatCount = 0

    let title: String
    if isLinkList {
        title = strings.FolderLinkPreview_TitleShare
    } else if let linkContents = component.linkContents {
        if case .remove = component.subject {
            title = strings.FolderLinkPreview_TitleRemove
        } else if linkContents.localFilterId != nil {
            if linkContents.alreadyMemberPeerIds == Set(linkContents.peers.map(\.id)) {
                allChatsAdded = true
            }
            canAddChatCount = linkContents.peers.count - linkContents.alreadyMemberPeerIds.count

            if allChatsAdded {
                title = strings.FolderLinkPreview_TitleAddFolder
            } else {
                title = strings.FolderLinkPreview_TitleAddChats(Int32(canAddChatCount))
            }
        } else {
            title = strings.FolderLinkPreview_TitleAddFolder
        }
    } else {
        title = " "
    }

    let topBadge: String?
    if isLinkList || allChatsAdded {
        topBadge = nil
    } else if case .remove = component.subject {
        topBadge = nil
    } else if let linkContents = component.linkContents, linkContents.localFilterId != nil, canAddChatCount != 0 {
        topBadge = "+\(canAddChatCount)"
    } else {
        topBadge = nil
    }

    let descriptionText: NSAttributedString
    if isLinkList {
        descriptionText = NSAttributedString(string: strings.FolderLinkPreview_TextLinkList)
    } else if let linkContents = component.linkContents {
        if case .remove = component.subject {
            descriptionText = NSAttributedString(string: strings.FolderLinkPreview_TextRemoveFolder, font: Font.regular(15.0), textColor: theme.list.freeTextColor)
        } else if allChatsAdded {
            descriptionText = NSAttributedString(string: strings.FolderLinkPreview_TextAllAdded, font: Font.regular(15.0), textColor: theme.list.freeTextColor)
        } else if linkContents.localFilterId == nil {
            descriptionText = NSAttributedString(string: strings.FolderLinkPreview_TextAddFolder, font: Font.regular(15.0), textColor: theme.list.freeTextColor)
        } else if let title = linkContents.title {
            let chatCountString = strings.FolderLinkPreview_TextAddChatsCount(Int32(canAddChatCount))

            let textValue = NSMutableAttributedString(string: strings.FolderLinkPreview_TextAddChatsV2)
            textValue.addAttributes([
                .font: Font.regular(15.0),
                .foregroundColor: theme.list.freeTextColor
            ], range: NSRange(location: 0, length: textValue.length))

            let folderRange = (textValue.string as NSString).range(of: "{folder}")
            if folderRange.location != NSNotFound {
                textValue.replaceCharacters(in: folderRange, with: "")
                textValue.insert(title.attributedString(font: Font.semibold(15.0), textColor: theme.list.freeTextColor), at: folderRange.location)
            }

            let chatsRange = (textValue.string as NSString).range(of: "{chats}")
            if chatsRange.location != NSNotFound {
                textValue.replaceCharacters(in: chatsRange, with: "")
                textValue.insert(NSAttributedString(string: chatCountString, font: Font.semibold(15.0), textColor: theme.list.freeTextColor), at: chatsRange.location)
            }

            descriptionText = textValue
        } else {
            descriptionText = NSAttributedString(string: " ", font: Font.regular(15.0), textColor: theme.list.freeTextColor)
        }
    } else {
        descriptionText = NSAttributedString(string: " ")
    }

    let listHeaderTitle: String
    if isLinkList {
        listHeaderTitle = strings.FolderLinkPreview_LinkSectionHeader
    } else if let linkContents = component.linkContents {
        if case .remove = component.subject {
            listHeaderTitle = strings.FolderLinkPreview_RemoveSectionSelectedHeader(Int32(linkContents.peers.count))
        } else if allChatsAdded {
            listHeaderTitle = strings.FolderLinkPreview_ChatSectionHeader(Int32(linkContents.peers.count))
        } else {
            listHeaderTitle = strings.FolderLinkPreview_ChatSectionJoinHeader(Int32(linkContents.peers.count))
        }
    } else {
        listHeaderTitle = " "
    }

    var listHeaderActionItems: [AnimatedCounterComponent.Item] = []
    if !isLinkList, let linkContents = component.linkContents {
        let dynamicIndex = strings.FolderLinkPreview_ListSelectionSelectAllFormat.range(of: "{dynamic}")
        let staticIndex = strings.FolderLinkPreview_ListSelectionSelectAllFormat.range(of: "{static}")
        var headerActionItemIndices: [Int: Int] = [:]
        if let dynamicIndex, let staticIndex {
            if dynamicIndex.lowerBound < staticIndex.lowerBound {
                headerActionItemIndices[0] = 0
                headerActionItemIndices[1] = 1
            } else {
                headerActionItemIndices[0] = 1
                headerActionItemIndices[1] = 0
            }
        } else if dynamicIndex != nil {
            headerActionItemIndices[0] = 0
        } else if staticIndex != nil {
            headerActionItemIndices[1] = 0
        }

        let dynamicItem: AnimatedCounterComponent.Item
        let staticItem: AnimatedCounterComponent.Item

        if selectedItems.count == linkContents.peers.count {
            dynamicItem = AnimatedCounterComponent.Item(id: AnyHashable(0), text: strings.FolderLinkPreview_ListSelectionSelectAllDynamicPartDeselect, numericValue: 0)
            staticItem = AnimatedCounterComponent.Item(id: AnyHashable(1), text: strings.FolderLinkPreview_ListSelectionSelectAllStaticPartDeselect, numericValue: 1)
        } else {
            dynamicItem = AnimatedCounterComponent.Item(id: AnyHashable(0), text: strings.FolderLinkPreview_ListSelectionSelectAllDynamicPartSelect, numericValue: 1)
            staticItem = AnimatedCounterComponent.Item(id: AnyHashable(1), text: strings.FolderLinkPreview_ListSelectionSelectAllStaticPartSelect, numericValue: 1)
        }

        if let dynamicIndex = headerActionItemIndices[0], let staticIndex = headerActionItemIndices[1] {
            if dynamicIndex < staticIndex {
                listHeaderActionItems = [dynamicItem, staticItem]
            } else {
                listHeaderActionItems = [staticItem, dynamicItem]
            }
        } else if headerActionItemIndices[0] != nil {
            listHeaderActionItems = [dynamicItem]
        } else if headerActionItemIndices[1] != nil {
            listHeaderActionItems = [staticItem]
        }
    }

    let showsListHeaderAction: Bool
    if isLinkList {
        showsListHeaderAction = false
    } else if let linkContents = component.linkContents {
        showsListHeaderAction = !allChatsAdded && linkContents.peers.count > 1
    } else {
        showsListHeaderAction = false
    }

    let actionButtonTitle: String?
    let actionButtonBadge: Int
    if isLinkList {
        actionButtonTitle = nil
        actionButtonBadge = 0
    } else if case .remove = component.subject {
        actionButtonBadge = selectedItems.count
        if selectedItems.isEmpty {
            actionButtonTitle = strings.FolderLinkPreview_ButtonRemoveFolder
        } else {
            actionButtonTitle = strings.FolderLinkPreview_ButtonRemoveFolderAndChats
        }
    } else if allChatsAdded {
        actionButtonBadge = 0
        actionButtonTitle = strings.Common_OK
    } else if let linkContents = component.linkContents {
        actionButtonBadge = max(0, selectedItems.count - (linkContents.peers.count - canAddChatCount))
        if linkContents.localFilterId != nil {
            if actionButtonBadge == 0 {
                actionButtonTitle = strings.FolderLinkPreview_ButtonDoNotJoinChats
            } else {
                actionButtonTitle = strings.FolderLinkPreview_ButtonJoinChats
            }
        } else {
            actionButtonTitle = strings.FolderLinkPreview_ButtonAddFolder
        }
    } else {
        actionButtonTitle = " "
        actionButtonBadge = 0
    }

    return ChatFolderLinkPreviewResolvedData(
        title: title,
        topBadge: topBadge,
        descriptionText: descriptionText,
        listHeaderTitle: listHeaderTitle,
        listHeaderActionItems: listHeaderActionItems,
        showsListHeaderAction: showsListHeaderAction,
        actionButtonTitle: actionButtonTitle,
        actionButtonBadge: actionButtonBadge,
        actionButtonEnabled: !selectedItems.isEmpty || component.linkContents?.localFilterId != nil,
        allChatsAdded: allChatsAdded,
        canAddChatCount: canAddChatCount,
        isLinkList: isLinkList
    )
}

private final class ChatFolderLinkPreviewContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: ChatFolderLinkPreviewScreen.Subject
    let linkContents: ChatFolderLinkContents?
    let theme: PresentationTheme
    let resolvedData: ChatFolderLinkPreviewResolvedData
    let selectedItems: Set<EnginePeer.Id>
    let linkListItems: [ExportedChatFolderLink]
    let peerAction: (EnginePeer) -> Void
    let toggleAllSelection: () -> Void
    let openCreateLink: () -> Void
    let openLink: (ExportedChatFolderLink) -> Void
    let openLinkContextAction: (ExportedChatFolderLink, ContextExtractedContentContainingView, ContextGesture?) -> Void

    init(
        context: AccountContext,
        subject: ChatFolderLinkPreviewScreen.Subject,
        linkContents: ChatFolderLinkContents?,
        theme: PresentationTheme,
        resolvedData: ChatFolderLinkPreviewResolvedData,
        selectedItems: Set<EnginePeer.Id>,
        linkListItems: [ExportedChatFolderLink],
        peerAction: @escaping (EnginePeer) -> Void,
        toggleAllSelection: @escaping () -> Void,
        openCreateLink: @escaping () -> Void,
        openLink: @escaping (ExportedChatFolderLink) -> Void,
        openLinkContextAction: @escaping (ExportedChatFolderLink, ContextExtractedContentContainingView, ContextGesture?) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.linkContents = linkContents
        self.theme = theme
        self.resolvedData = resolvedData
        self.selectedItems = selectedItems
        self.linkListItems = linkListItems
        self.peerAction = peerAction
        self.toggleAllSelection = toggleAllSelection
        self.openCreateLink = openCreateLink
        self.openLink = openLink
        self.openLinkContextAction = openLinkContextAction
    }

    static func ==(lhs: ChatFolderLinkPreviewContentComponent, rhs: ChatFolderLinkPreviewContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.linkContents !== rhs.linkContents {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.resolvedData != rhs.resolvedData {
            return false
        }
        if lhs.selectedItems != rhs.selectedItems {
            return false
        }
        if lhs.linkListItems != rhs.linkListItems {
            return false
        }
        return true
    }

    final class View: UIView {
        private let topIcon = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let listHeaderText = ComponentView<Empty>()
        private let listHeaderAction = ComponentView<Empty>()

        private let itemContainerView: UIView
        private var items: [AnyHashable: ComponentView<Empty>] = [:]

        private var component: ChatFolderLinkPreviewContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 26.0

            super.init(frame: frame)

            self.addSubview(self.itemContainerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ChatFolderLinkPreviewContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value

            self.component = component
            self.state = state
            self.environment = environment
            self.itemContainerView.backgroundColor = component.theme.list.itemBlocksBackgroundColor

            let sideInset: CGFloat = 16.0
            var contentHeight: CGFloat = 58.0

            let topIconSize = self.topIcon.update(
                transition: transition,
                component: AnyComponent(ChatFolderLinkHeaderComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: environment.strings,
                    title: component.linkContents?.title ?? ChatFolderTitle(text: "Folder", entities: [], enableAnimations: true),
                    badge: component.resolvedData.topBadge
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset, height: 1000.0)
            )
            let topIconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - topIconSize.width) * 0.5), y: contentHeight), size: topIconSize)
            if let topIconView = self.topIcon.view {
                if topIconView.superview == nil {
                    self.addSubview(topIconView)
                }
                transition.setFrame(view: topIconView, frame: topIconFrame)
                topIconView.isHidden = component.linkContents == nil
            }

            contentHeight += topIconSize.height
            contentHeight += 20.0

            let descriptionTextSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: component.theme.list.freeTextColor.withMultipliedAlpha(0.1),
                    text: .plain(component.resolvedData.descriptionText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
            }

            contentHeight += descriptionTextFrame.height
            contentHeight += 39.0

            var singleItemHeight: CGFloat = 0.0
            var itemsHeight: CGFloat = 0.0
            var validIds: [AnyHashable] = []

            if case .linkList = component.subject {
                do {
                    let id = AnyHashable("action")
                    validIds.append(id)

                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }

                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(ActionListItemComponent(
                            theme: component.theme,
                            sideInset: 0.0,
                            iconName: "Contact List/LinkActionIcon",
                            title: environment.strings.InviteLink_Create,
                            hasNext: !component.linkListItems.isEmpty,
                            action: { [weak component] in
                                component?.openCreateLink()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)

                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }

                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }

                for i in 0 ..< component.linkListItems.count {
                    let link = component.linkListItems[i]

                    let id = AnyHashable(link.link)
                    validIds.append(id)

                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }

                    let subtitle = environment.strings.ChatListFilter_LinkLabelChatCount(Int32(link.peerIds.count))
                    let itemComponent = LinkListItemComponent(
                        theme: component.theme,
                        sideInset: 0.0,
                        title: link.title.isEmpty ? link.link : link.title,
                        link: link,
                        label: subtitle,
                        selectionState: .none,
                        hasNext: i != component.linkListItems.count - 1,
                        action: { [weak component] link in
                            component?.openLink(link)
                        },
                        contextAction: { [weak component] link, sourceView, gesture in
                            component?.openLinkContextAction(link, sourceView, gesture)
                        }
                    )

                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(itemComponent),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)

                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }

                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
            } else if let linkContents = component.linkContents {
                for i in 0 ..< linkContents.peers.count {
                    let peer = linkContents.peers[i]

                    let id = AnyHashable(peer.id)
                    validIds.append(id)

                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }

                    var subtitle: String?
                    if case let .channel(channel) = peer, case .broadcast = channel.info {
                        if linkContents.alreadyMemberPeerIds.contains(peer.id) {
                            subtitle = environment.strings.FolderLinkPreview_LabelPeerSubscriber
                        } else if let memberCount = linkContents.memberCounts[peer.id] {
                            subtitle = environment.strings.FolderLinkPreview_LabelPeerSubscribers(Int32(memberCount))
                        }
                    } else {
                        if linkContents.alreadyMemberPeerIds.contains(peer.id) {
                            subtitle = environment.strings.FolderLinkPreview_LabelPeerMember
                        } else if let memberCount = linkContents.memberCounts[peer.id] {
                            subtitle = environment.strings.FolderLinkPreview_LabelPeerMembers(Int32(memberCount))
                        }
                    }

                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: environment.strings,
                            sideInset: 0.0,
                            title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                            peer: peer,
                            subtitle: subtitle,
                            selectionState: .editing(isSelected: component.selectedItems.contains(peer.id), isTinted: linkContents.alreadyMemberPeerIds.contains(peer.id)),
                            hasNext: i != linkContents.peers.count - 1,
                            action: { [weak component] peer in
                                component?.peerAction(peer)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)

                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }

                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
            }

            var removeIds: [AnyHashable] = []
            for (id, item) in self.items {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    item.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.items.removeValue(forKey: id)
            }

            let listHeaderBody = MarkdownAttributeSet(font: Font.with(size: 13.0, design: .regular, traits: [.monospacedNumbers]), textColor: component.theme.list.freeTextColor)
            let listHeaderTextSize = self.listHeaderText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: component.resolvedData.listHeaderTitle,
                        attributes: MarkdownAttributes(
                            body: listHeaderBody,
                            bold: listHeaderBody,
                            link: listHeaderBody,
                            linkAttribute: { _ in nil }
                        )
                    )
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0, height: 1000.0)
            )
            if let listHeaderTextView = self.listHeaderText.view {
                if listHeaderTextView.superview == nil {
                    self.addSubview(listHeaderTextView)
                }
                let listHeaderTextFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: listHeaderTextSize)
                transition.setFrame(view: listHeaderTextView, frame: listHeaderTextFrame)
                listHeaderTextView.isHidden = component.linkContents == nil
            }

            let listHeaderActionSize = self.listHeaderAction.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(AnimatedCounterComponent(
                        font: Font.regular(13.0),
                        color: component.theme.list.itemAccentColor,
                        alignment: .right,
                        items: component.resolvedData.listHeaderActionItems
                    )),
                    effectAlignment: .right,
                    action: { [weak component] in
                        component?.toggleAllSelection()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0, height: 1000.0)
            )
            if let listHeaderActionView = self.listHeaderAction.view {
                if listHeaderActionView.superview == nil {
                    self.addSubview(listHeaderActionView)
                }
                let listHeaderActionFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - 15.0 - listHeaderActionSize.width, y: contentHeight), size: listHeaderActionSize)
                transition.setFrame(view: listHeaderActionView, frame: listHeaderActionFrame)
                listHeaderActionView.isHidden = !component.resolvedData.showsListHeaderAction
            }

            contentHeight += listHeaderTextSize.height
            contentHeight += 6.0

            transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: itemsHeight)))

            contentHeight += itemsHeight
            contentHeight += component.resolvedData.isLinkList ? 54.0 : 24.0

            if itemsHeight == 0.0 && singleItemHeight == 0.0 {
                transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: 0.0)))
            }
            
            contentHeight += 52.0 + 3.0 + environment.safeInsets.bottom

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatFolderLinkPreviewScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: ChatFolderLinkPreviewScreen.Subject
    let linkContents: ChatFolderLinkContents?
    let completion: (() -> Void)?

    init(
        context: AccountContext,
        subject: ChatFolderLinkPreviewScreen.Subject,
        linkContents: ChatFolderLinkContents?,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.subject = subject
        self.linkContents = linkContents
        self.completion = completion
    }

    static func ==(lhs: ChatFolderLinkPreviewScreenComponent, rhs: ChatFolderLinkPreviewScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.linkContents !== rhs.linkContents {
            return false
        }
        return true
    }

    final class State: ComponentState {
        var selectedItems = Set<EnginePeer.Id>()
        var didInitializeSelection = false
        var linkListItems: [ExportedChatFolderLink] = []
        var didInitializeLinkList = false
        var inProgress = false
        var joinDisposable: Disposable?

        deinit {
            self.joinDisposable?.dispose()
        }
    }

    func makeState() -> State {
        return State()
    }

    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var isDismissing = false

        private var component: ChatFolderLinkPreviewScreenComponent?
        private weak var state: State?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func dismiss(controller: @escaping () -> ViewController?, animated: Bool) {
            guard !self.isDismissing else {
                return
            }
            self.isDismissing = true

            let performDismiss: () -> Void = {
                if let controller = controller() as? ChatFolderLinkPreviewScreen {
                    controller.completePendingDismiss()
                    controller.dismiss(animated: false)
                } else {
                    controller()?.dismiss(animated: false)
                }
            }

            if animated {
                self.animateOut.invoke(Action { _ in
                    performDismiss()
                })
            } else {
                performDismiss()
            }
        }

        private func ensureInitializedState(component: ChatFolderLinkPreviewScreenComponent, state: State) {
            if !state.didInitializeSelection, let linkContents = component.linkContents {
                state.didInitializeSelection = true
                if case let .remove(_, defaultSelectedPeerIds) = component.subject {
                    for peer in linkContents.peers {
                        if defaultSelectedPeerIds.contains(peer.id) {
                            state.selectedItems.insert(peer.id)
                        }
                    }
                } else {
                    for peer in linkContents.peers {
                        state.selectedItems.insert(peer.id)
                    }
                }
            }

            if !state.didInitializeLinkList, case let .linkList(_, initialLinks) = component.subject {
                state.didInitializeLinkList = true
                state.linkListItems = initialLinks
            }
        }

        private func toggleAllSelection() {
            guard let component = self.component, let state = self.state, let linkContents = component.linkContents else {
                return
            }
            if state.selectedItems.count != linkContents.peers.count {
                for peer in linkContents.peers {
                    state.selectedItems.insert(peer.id)
                }
            } else {
                state.selectedItems.removeAll()
                for peerId in linkContents.alreadyMemberPeerIds {
                    state.selectedItems.insert(peerId)
                }
            }
            state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
        }

        private func peerAction(peer: EnginePeer) {
            guard let component = self.component, let state = self.state, let linkContents = component.linkContents, let controller = self.environment?.controller() else {
                return
            }

            if case .remove = component.subject {
                if state.selectedItems.contains(peer.id) {
                    state.selectedItems.remove(peer.id)
                } else {
                    state.selectedItems.insert(peer.id)
                }
                state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
            } else if linkContents.alreadyMemberPeerIds.contains(peer.id) {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    text = presentationData.strings.FolderLinkPreview_ToastAlreadyMemberChannel
                } else {
                    text = presentationData.strings.FolderLinkPreview_ToastAlreadyMemberGroup
                }
                controller.present(UndoOverlayController(presentationData: presentationData, content: .peers(context: component.context, peers: [peer], title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in true }), in: .current)
            } else {
                if state.selectedItems.contains(peer.id) {
                    state.selectedItems.remove(peer.id)
                } else {
                    state.selectedItems.insert(peer.id)
                }
                state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
            }
        }

        private func presentLinkContextAction(link: ExportedChatFolderLink, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            guard case let .linkList(folderId, _) = component.subject else {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            var itemList: [ContextMenuItem] = []

            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)

                UIPasteboard.general.string = link.link

                if let self, let component = self.component, let controller = self.environment?.controller() {
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    controller.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in false }), in: .window(.root))
                }
            })))

            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                if let self, let component = self.component, let controller = self.environment?.controller() {
                    controller.present(QrCodeScreen(context: component.context, updatedPresentationData: nil, subject: .chatFolder(slug: link.slug)), in: .window(.root))
                }
            })))

            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                guard let self, let component = self.component, let state = self.state else {
                    return
                }

                state.linkListItems.removeAll(where: { $0.link == link.link })
                state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))

                let context = component.context
                let _ = (context.engine.peers.editChatFolderLink(filterId: folderId, link: link, title: nil, peerIds: nil, revoke: true)
                |> deliverOnMainQueue).start(completed: {
                    let _ = (context.engine.peers.deleteChatFolderLink(filterId: folderId, link: link)
                    |> deliverOnMainQueue).start(completed: {
                    })
                })
            })))

            let items = ContextController.Items(content: .list(itemList))
            let controller = makeContextController(
                presentationData: presentationData,
                source: .extracted(LinkListContextExtractedContentSource(contentView: sourceView)),
                items: .single(items),
                recognizer: nil,
                gesture: gesture
            )

            environment.controller()?.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismiss()
                }
                return true
            })
            environment.controller()?.presentInGlobalOverlay(controller)
        }

        private func performMainAction() {
            guard let component = self.component, let state = self.state, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            guard let linkContents = component.linkContents else {
                controller.dismiss()
                return
            }

            let resolvedData = chatFolderLinkPreviewResolvedData(
                component: component,
                theme: environment.theme.withModalBlocksBackground(),
                strings: environment.strings,
                selectedItems: state.selectedItems
            )

            if case let .remove(folderId, _) = component.subject {
                state.inProgress = true
                state.updated(transition: .immediate)

                component.completion?()

                let disposable = DisposableSet()
                disposable.add(component.context.account.postbox.addHiddenChatIds(peerIds: Array(state.selectedItems)))
                disposable.add(component.context.account.viewTracker.addHiddenChatListFilterIds([folderId]))

                let folderTitle: ChatFolderTitle
                if let title = linkContents.title {
                    folderTitle = title
                } else {
                    folderTitle = ChatFolderTitle(text: "", entities: [], enableAnimations: true)
                }

                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                let additionalText: String? = state.selectedItems.isEmpty ? nil : presentationData.strings.FolderLinkPreview_ToastLeftChatsText(Int32(state.selectedItems.count))

                var chatListController: ChatListController?
                if let navigationController = controller.navigationController as? NavigationController {
                    for viewController in navigationController.viewControllers.reversed() {
                        if viewController is ChatFolderLinkPreviewScreen {
                            continue
                        }

                        if let rootController = viewController as? TabBarController {
                            for controller in rootController.controllers {
                                if let controller = controller as? ChatListController {
                                    chatListController = controller
                                    break
                                }
                            }
                        } else if let controller = viewController as? ChatListController {
                            chatListController = controller
                        }

                        break
                    }
                }

                let undoText = NSMutableAttributedString(string: presentationData.strings.FolderLinkPreview_ToastLeftTitleV2)
                let folderRange = (undoText.string as NSString).range(of: "{folder}")
                if folderRange.location != NSNotFound {
                    undoText.replaceCharacters(in: folderRange, with: "")
                    undoText.insert(folderTitle.rawAttributedString, at: folderRange.location)
                }

                let context = component.context
                let selectedItems = state.selectedItems
                let undoOverlayController = UndoOverlayController(
                    presentationData: presentationData,
                    content: .removedChat(context: component.context, title: undoText, text: additionalText),
                    elevatedLayout: false,
                    action: { value in
                        if case .commit = value {
                            let _ = (context.engine.peers.leaveChatFolder(folderId: folderId, removePeerIds: Array(selectedItems))
                            |> deliverOnMainQueue).start(completed: {
                                Queue.mainQueue().after(1.0, {
                                    disposable.dispose()
                                })
                            })
                            return true
                        } else if case .undo = value {
                            disposable.dispose()
                            return true
                        }
                        return false
                    }
                )

                if let chatListController, chatListController.view.window != nil {
                    chatListController.present(undoOverlayController, in: .current)
                } else {
                    controller.present(undoOverlayController, in: .window(.root))
                }

                controller.dismiss()
                return
            }

            if resolvedData.allChatsAdded {
                controller.dismiss()
                return
            }

            guard state.joinDisposable == nil, !state.selectedItems.isEmpty else {
                controller.dismiss()
                return
            }

            let joinSignal: Signal<JoinChatFolderResult?, JoinChatFolderLinkError>
            switch component.subject {
            case .linkList, .remove:
                return
            case let .slug(slug):
                joinSignal = component.context.engine.peers.joinChatFolderLink(slug: slug, peerIds: Array(state.selectedItems))
                |> map(Optional.init)
            case let .updates(updates):
                var result: JoinChatFolderResult?
                if let localFilterId = updates.chatFolderLinkContents.localFilterId, let title = updates.chatFolderLinkContents.title {
                    result = JoinChatFolderResult(folderId: localFilterId, title: title, newChatCount: state.selectedItems.count)
                }
                joinSignal = component.context.engine.peers.joinAvailableChatsInFolder(updates: updates, peerIds: Array(state.selectedItems))
                |> map { _ -> JoinChatFolderResult? in
                }
                |> then(Signal<JoinChatFolderResult?, JoinChatFolderLinkError>.single(result))
            }

            state.inProgress = true
            state.updated(transition: .immediate)

            state.joinDisposable = (joinSignal
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self, let component = self.component, let controller = self.environment?.controller() else {
                    return
                }

                if let result, let navigationController = controller.navigationController as? NavigationController {
                    var chatListController: ChatListController?
                    for viewController in navigationController.viewControllers {
                        if let rootController = viewController as? TabBarController {
                            for controller in rootController.controllers {
                                if let controller = controller as? ChatListController {
                                    chatListController = controller
                                    break
                                }
                            }
                        } else if let controller = viewController as? ChatListController {
                            chatListController = controller
                            break
                        }
                    }

                    if let chatListController {
                        navigationController.popToRoot(animated: true)
                        let context = component.context
                        chatListController.navigateToFolder(folderId: result.folderId, completion: { [weak context, weak chatListController] in
                            guard let context, let chatListController else {
                                return
                            }

                            let presentationData = context.sharedContext.currentPresentationData.with({ $0 })

                            var isUpdates = false
                            if case .updates = component.subject {
                                isUpdates = true
                            } else if component.linkContents?.localFilterId != nil {
                                isUpdates = true
                            }

                            if isUpdates {
                                let titleString = NSMutableAttributedString(string: presentationData.strings.FolderLinkPreview_ToastChatsAddedTitleV2)
                                let folderRange = (titleString.string as NSString).range(of: "{folder}")
                                if folderRange.location != NSNotFound {
                                    titleString.replaceCharacters(in: folderRange, with: "")
                                    titleString.insert(result.title.rawAttributedString, at: folderRange.location)
                                }

                                chatListController.present(UndoOverlayController(presentationData: presentationData, content: .universalWithEntities(context: component.context, animation: "anim_add_to_folder", scale: 0.1, colors: ["__allcolors__": UIColor.white], title: titleString, text: NSAttributedString(string: presentationData.strings.FolderLinkPreview_ToastChatsAddedText(Int32(result.newChatCount))), animateEntities: true, customUndoText: nil, timeout: 5), elevatedLayout: false, action: { _ in true }), in: .current)
                            } else if result.newChatCount != 0 {
                                let animationBackgroundColor: UIColor
                                if presentationData.theme.overallDarkAppearance {
                                    animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
                                } else {
                                    animationBackgroundColor = UIColor(rgb: 0x474747)
                                }

                                let titleString = NSMutableAttributedString(string: presentationData.strings.FolderLinkPreview_ToastChatsAddedTitleV2)
                                let folderRange = (titleString.string as NSString).range(of: "{folder}")
                                if folderRange.location != NSNotFound {
                                    titleString.replaceCharacters(in: folderRange, with: "")
                                    titleString.insert(result.title.rawAttributedString, at: folderRange.location)
                                }

                                chatListController.present(UndoOverlayController(presentationData: presentationData, content: .universalWithEntities(context: component.context, animation: "anim_success", scale: 1.0, colors: ["info1.info1.stroke": animationBackgroundColor, "info2.info2.Fill": animationBackgroundColor], title: titleString, text: NSAttributedString(string: presentationData.strings.FolderLinkPreview_ToastFolderAddedText(Int32(result.newChatCount))), animateEntities: true, customUndoText: nil, timeout: 5), elevatedLayout: false, action: { _ in true }), in: .current)
                            } else {
                                let animationBackgroundColor: UIColor
                                if presentationData.theme.overallDarkAppearance {
                                    animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
                                } else {
                                    animationBackgroundColor = UIColor(rgb: 0x474747)
                                }

                                let titleString = NSMutableAttributedString(string: presentationData.strings.FolderLinkPreview_ToastFolderAddedTitleV2)
                                let folderRange = (titleString.string as NSString).range(of: "{folder}")
                                if folderRange.location != NSNotFound {
                                    titleString.replaceCharacters(in: folderRange, with: "")
                                    titleString.insert(result.title.rawAttributedString, at: folderRange.location)
                                }

                                chatListController.present(UndoOverlayController(presentationData: presentationData, content: .universalWithEntities(context: component.context, animation: "anim_success", scale: 1.0, colors: ["info1.info1.stroke": animationBackgroundColor, "info2.info2.Fill": animationBackgroundColor], title: titleString, text: NSAttributedString(string: ""), animateEntities: true, customUndoText: nil, timeout: 5), elevatedLayout: false, action: { _ in true }), in: .current)
                            }
                        })
                    }
                }

                controller.dismiss()
            }, error: { [weak self] error in
                guard let self, let component = self.component, let controller = self.environment?.controller() else {
                    return
                }

                let navigationController = controller.navigationController as? NavigationController

                switch error {
                case .generic:
                    controller.dismiss()
                case let .dialogFilterLimitExceeded(limit, _):
                    let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .folders, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                        guard let navigationController else {
                            return true
                        }
                        navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .folders))
                        return true
                    })
                    controller.push(limitController)
                    controller.dismiss()
                case let .sharedFolderLimitExceeded(limit, _):
                    let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .membershipInSharedFolders, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                        guard let navigationController else {
                            return true
                        }
                        navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .membershipInSharedFolders))
                        return true
                    })
                    controller.push(limitController)
                    controller.dismiss()
                case let .tooManyChannels(limit, _):
                    let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .chatsPerFolder, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                        guard let navigationController else {
                            return true
                        }
                        navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .chatsPerFolder))
                        return true
                    })
                    controller.push(limitController)
                    controller.dismiss()
                case let .tooManyChannelsInAccount(limit, _):
                    let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .channels, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                        guard let navigationController else {
                            return true
                        }
                        navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .groupsAndChannels))
                        return true
                    })
                    controller.push(limitController)
                    controller.dismiss()
                }
            })
        }

        private func openLink(link: ExportedChatFolderLink) {
            guard let component = self.component else {
                return
            }
            guard case let .linkList(folderId, _) = component.subject else {
                return
            }

            let _ = (component.context.engine.peers.currentChatListFilters()
            |> deliverOnMainQueue).start(next: { [weak self] filters in
                guard let self, let component = self.component else {
                    return
                }
                guard let filter = filters.first(where: { $0.id == folderId }) else {
                    return
                }
                guard case let .filter(_, title, _, data) = filter else {
                    return
                }

                let peerIds = data.includePeers.peers
                let _ = (component.context.engine.data.get(
                    EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                )
                |> deliverOnMainQueue).start(next: { [weak self] peers in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }

                    let peers = peers.compactMap({ peer -> EnginePeer? in
                        guard let peer else {
                            return nil
                        }
                        if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                            return nil
                        }
                        return peer
                    })

                    let navigationController = controller.navigationController
                    controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: link, linkUpdated: { _ in
                    }, presentController: { [weak navigationController] controller in
                        (navigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root))
                    }))
                    controller.dismiss()
                })
            })
        }

        private func openCreateLink() {
            guard let component = self.component else {
                return
            }
            guard case let .linkList(folderId, _) = component.subject else {
                return
            }

            let _ = (component.context.engine.peers.currentChatListFilters()
            |> deliverOnMainQueue).start(next: { [weak self] filters in
                guard let self, let component = self.component else {
                    return
                }
                guard let filter = filters.first(where: { $0.id == folderId }) else {
                    return
                }
                guard case let .filter(_, title, _, data) = filter else {
                    return
                }

                let peerIds = data.includePeers.peers
                let _ = (component.context.engine.data.get(
                    EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                )
                |> deliverOnMainQueue).start(next: { [weak self] peers in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }

                    let peers = peers.compactMap({ peer -> EnginePeer? in
                        guard let peer else {
                            return nil
                        }
                        if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                            return nil
                        }
                        return peer
                    })

                    if peers.allSatisfy({ !canShareLinkToPeer(peer: $0) }) {
                        let navigationController = controller.navigationController
                        controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: nil, linkUpdated: { _ in
                        }, presentController: { [weak navigationController] controller in
                            (navigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root))
                        }))
                    } else {
                        var enabledPeerIds: [EnginePeer.Id] = []
                        for peer in peers where canShareLinkToPeer(peer: peer) {
                            enabledPeerIds.append(peer.id)
                        }

                        let _ = (component.context.engine.peers.exportChatFolder(filterId: folderId, title: "", peerIds: enabledPeerIds)
                        |> deliverOnMainQueue).start(next: { [weak self] link in
                            guard let self, let component = self.component, let state = self.state, let controller = self.environment?.controller() else {
                                return
                            }

                            state.linkListItems.insert(link, at: 0)
                            state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))

                            let navigationController = controller.navigationController
                            controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: link, linkUpdated: { [weak self] updatedLink in
                                guard let self, let state = self.state else {
                                    return
                                }
                                if let index = state.linkListItems.firstIndex(where: { $0.link == link.link }) {
                                    if let updatedLink {
                                        state.linkListItems[index] = updatedLink
                                    } else {
                                        state.linkListItems.remove(at: index)
                                    }
                                } else if let updatedLink {
                                    state.linkListItems.insert(updatedLink, at: 0)
                                }
                                state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                            }, presentController: { [weak navigationController] controller in
                                (navigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root))
                            }))

                            controller.dismiss()
                        }, error: { [weak self] error in
                            guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                return
                            }

                            let context = component.context
                            let navigationController = controller.navigationController as? NavigationController
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

                            let text: String
                            switch error {
                            case .generic:
                                text = presentationData.strings.ChatListFilter_CreateLinkUnknownError
                            case let .sharedFolderLimitExceeded(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .membershipInSharedFolders, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                                    guard let navigationController else {
                                        return true
                                    }
                                    navigationController.pushViewController(PremiumIntroScreen(context: context, source: .membershipInSharedFolders))
                                    return true
                                })
                                controller.push(limitController)
                                return
                            case let .limitExceeded(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .linksPerSharedFolder, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                                    guard let navigationController else {
                                        return true
                                    }
                                    navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .linksPerSharedFolder))
                                    return true
                                })
                                controller.push(limitController)
                                return
                            case let .tooManyChannels(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .chatsPerFolder, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                                    guard let navigationController else {
                                        return true
                                    }
                                    navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .chatsPerFolder))
                                    return true
                                })
                                controller.push(limitController)
                                controller.dismiss()
                                return
                            case let .tooManyChannelsInAccount(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .channels, count: limit, forceDark: false, cancel: {}, action: { [weak navigationController] in
                                    guard let navigationController else {
                                        return true
                                    }
                                    navigationController.pushViewController(PremiumIntroScreen(context: component.context, source: .groupsAndChannels))
                                    return true
                                })
                                controller.push(limitController)
                                controller.dismiss()
                                return
                            case .someUserTooManyChannels:
                                text = presentationData.strings.ChatListFilter_CreateLinkErrorSomeoneHasChannelLimit
                            }

                            controller.present(textAlertController(context: component.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        })
                    }
                })
            })
        }

        func update(component: ChatFolderLinkPreviewScreenComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.ensureInitializedState(component: component, state: state)

            self.component = component
            self.state = state

            let environmentValue = environment[EnvironmentType.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme.withModalBlocksBackground()

            let dismiss: (Bool) -> Void = { [weak self] animated in
                self?.dismiss(controller: controller, animated: animated)
            }

            let resolvedData = chatFolderLinkPreviewResolvedData(
                component: component,
                theme: theme,
                strings: environmentValue.strings,
                selectedItems: state.selectedItems
            )

            let bottomItem: AnyComponent<Empty>?
            if let actionButtonTitle = resolvedData.actionButtonTitle {
                bottomItem = AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: actionButtonTitle,
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: resolvedData.actionButtonBadge,
                            textColor: theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: theme.list.itemCheckColors.fillColor,
                            combinedAlignment: true
                        ))
                    ),
                    isEnabled: resolvedData.actionButtonEnabled,
                    displaysProgress: state.inProgress,
                    action: { [weak self] in
                        self?.performMainAction()
                    }
                ))
            } else {
                bottomItem = nil
            }

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent(ChatFolderLinkPreviewContentComponent(
                        context: component.context,
                        subject: component.subject,
                        linkContents: component.linkContents,
                        theme: theme,
                        resolvedData: resolvedData,
                        selectedItems: state.selectedItems,
                        linkListItems: state.linkListItems,
                        peerAction: { [weak self] peer in
                            self?.peerAction(peer: peer)
                        },
                        toggleAllSelection: { [weak self] in
                            self?.toggleAllSelection()
                        },
                        openCreateLink: { [weak self] in
                            self?.openCreateLink()
                        },
                        openLink: { [weak self] link in
                            self?.openLink(link: link)
                        },
                        openLinkContextAction: { [weak self] link, sourceView, gesture in
                            self?.presentLinkContextAction(link: link, sourceView: sourceView, gesture: gesture)
                        }
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: resolvedData.title, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor))
                    )),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: nil,
                    hasTopEdgeEffect: false,
                    bottomItem: bottomItem,
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environmentValue
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environmentValue.statusBarHeight,
                        safeInsets: environmentValue.safeInsets,
                        inputHeight: 0.0,
                        metrics: environmentValue.metrics,
                        deviceMetrics: environmentValue.deviceMetrics,
                        isDisplaying: environmentValue.isVisible,
                        isCentered: environmentValue.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ChatFolderLinkPreviewScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case slug(String)
        case updates(ChatFolderUpdates)
        case remove(folderId: Int32, defaultSelectedPeerIds: [EnginePeer.Id])
        case linkList(folderId: Int32, initialLinks: [ExportedChatFolderLink])
    }

    private let context: AccountContext
    private var linkContentsDisposable: Disposable?

    private var isDismissed = false
    private var dismissCompletion: (() -> Void)?

    public init(context: AccountContext, subject: Subject, contents: ChatFolderLinkContents, completion: (() -> Void)? = nil) {
        self.context = context

        super.init(context: context, component: ChatFolderLinkPreviewScreenComponent(context: context, subject: subject, linkContents: contents, completion: completion), navigationBarAppearance: .none)

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.lockOrientation = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.linkContentsDisposable?.dispose()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.view.disablesInteractiveModalDismiss = true
    }

    func completePendingDismiss() {
        let dismissCompletion = self.dismissCompletion
        self.dismissCompletion = nil
        dismissCompletion?()
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.dismissCompletion = completion

            if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                view.dismissAnimated()
            } else {
                self.completePendingDismiss()
                self.dismiss(animated: false)
            }
        }
    }
}

private final class LinkListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true

    private let contentView: ContextExtractedContentContainingView

    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }

    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: mainWindowScreenBounds)
    }

    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}
