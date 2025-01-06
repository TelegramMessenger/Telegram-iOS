import Display
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import AccountContext
import ContactListUI
import ChatListUI
import AnimationCache
import MultiAnimationRenderer
import EditableTokenListNode
import SolidRoundedButtonNode
import ContextUI

private struct SearchResultEntry: Identifiable {
    let index: Int
    let peer: Peer
    
    var stableId: Int64 {
        return self.peer.id.toInt64()
    }
    
    static func ==(lhs: SearchResultEntry, rhs: SearchResultEntry) -> Bool {
        return lhs.index == rhs.index && lhs.peer.isEqual(rhs.peer)
    }
    
    static func <(lhs: SearchResultEntry, rhs: SearchResultEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

enum ContactMultiselectionContentNode {
    case contacts(ContactListNode)
    case chats(ChatListNode)
    
    var node: ASDisplayNode {
        switch self {
        case let .contacts(contacts):
            return contacts
        case let .chats(chats):
            return chats
        }
    }
}

final class ContactMultiselectionControllerNode: ASDisplayNode {
    private let navigationBar: NavigationBar?
    let contentNode: ContactMultiselectionContentNode
    let tokenListNode: EditableTokenListNode
    var searchResultsNode: ContactListNode?
    
    private let context: AccountContext
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((ContactListPeerId) -> Void)?
    var openPeer: ((ContactListPeer) -> Void)?
    var openPeerMore: ((ContactListPeer, ASDisplayNode?, ContextGesture?) -> Void)?
    var openDisabledPeer: ((EnginePeer, ChatListDisabledPeerReason) -> Void)?
    var removeSelectedPeer: ((ContactListPeerId) -> Void)?
    var removeSelectedCategory: ((Int) -> Void)?
    var additionalCategorySelected: ((Int) -> Void)?
    var complete: (() -> Void)?
    
    var editableTokens: [EditableTokenListToken] = []
    
    private let searchResultsReadyDisposable = MetaDisposable()
    var dismiss: (() -> Void)?
    
    private var presentationData: PresentationData
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private let footerPanelNode: FooterPanelNode?
    
    private let isPeerEnabled: ((EnginePeer) -> Bool)?
    private let onlyWriteable: Bool
    private let isGroupInvitation: Bool
    
    init(navigationBar: NavigationBar?, context: AccountContext, presentationData: PresentationData, mode: ContactMultiselectionControllerMode, isPeerEnabled: ((EnginePeer) -> Bool)?, attemptDisabledItemSelection: ((EnginePeer, ChatListDisabledPeerReason) -> Void)?, options: Signal<[ContactListAdditionalOption], NoError>, filters: [ContactListFilter], onlyWriteable: Bool, isGroupInvitation: Bool, limit: Int32?, reachedSelectionLimit: ((Int32) -> Void)?, present: @escaping (ViewController, Any?) -> Void) {
        self.navigationBar = navigationBar
        
        self.context = context
        self.presentationData = presentationData
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        self.isPeerEnabled = isPeerEnabled
        self.onlyWriteable = onlyWriteable
        self.isGroupInvitation = isGroupInvitation
        
        var proceedImpl: (() -> Void)?
        
        var placeholder: String
        var shortPlaceholder: String?
        var includeChatList = false
        switch mode {
        case let .peerSelection(_, searchGroups, searchChannels):
            includeChatList = searchGroups || searchChannels
            if searchGroups {
                placeholder = self.presentationData.strings.Contacts_SearchUsersAndGroupsLabel
            } else {
                placeholder = self.presentationData.strings.Contacts_SearchLabel
            }
            self.footerPanelNode = nil
        case .premiumGifting:
            placeholder = self.presentationData.strings.Premium_Gift_ContactSelection_Placeholder
            shortPlaceholder = self.presentationData.strings.Common_Search
            self.footerPanelNode = FooterPanelNode(theme: self.presentationData.theme, strings: self.presentationData.strings, action: {
                proceedImpl?()
            })
        case .requestedUsersSelection:
            placeholder = self.presentationData.strings.RequestPeer_SelectUsers_SearchPlaceholder
            self.footerPanelNode = FooterPanelNode(theme: self.presentationData.theme, strings: self.presentationData.strings, action: {
                proceedImpl?()
            })
        default:
            placeholder = self.presentationData.strings.Compose_TokenListPlaceholder
            self.footerPanelNode = nil
        }
        
        if case let .chatSelection(chatSelection) = mode {
            let placeholderValue = chatSelection.searchPlaceholder
            let selectedChats = chatSelection.selectedChats
            let additionalCategories = chatSelection.additionalCategories
            let chatListFilters = chatSelection.chatListFilters
            
            var chatListFilter: ChatListFilter?
            if chatSelection.onlyUsers {
                chatListFilter = .filter(id: Int32.max, title: ChatFolderTitle(text: "", entities: [], enableAnimations: true), emoticon: nil, data: ChatListFilterData(
                    isShared: false,
                    hasSharedLinks: false,
                    categories: [.contacts, .nonContacts],
                    excludeMuted: false,
                    excludeRead: false,
                    excludeArchived: false,
                    includePeers: ChatListFilterIncludePeers(),
                    excludePeers: [],
                    color: nil
                ))
            } else if chatSelection.disableChannels || chatSelection.disableBots {
                var categories: ChatListFilterPeerCategories = [.contacts, .nonContacts, .groups, .bots, .channels]
                if chatSelection.disableChannels {
                    categories.remove(.channels)
                }
                if chatSelection.disableChannels {
                    categories.remove(.bots)
                }
                
                chatListFilter = .filter(id: Int32.max, title: ChatFolderTitle(text: "", entities: [], enableAnimations: true), emoticon: nil, data: ChatListFilterData(
                    isShared: false,
                    hasSharedLinks: false,
                    categories: categories,
                    excludeMuted: false,
                    excludeRead: false,
                    excludeArchived: false,
                    includePeers: ChatListFilterIncludePeers(),
                    excludePeers: [],
                    color: nil
                ))
            }
            
            placeholder = placeholderValue
            let chatListNode = ChatListNode(context: context, location: .chatList(groupId: .root), chatListFilter: chatListFilter, previewing: false, fillPreloadItems: false, mode: .peers(filter: [.excludeSecretChats], isSelecting: true, additionalCategories: additionalCategories?.categories ?? [], chatListFilters: chatListFilters, displayAutoremoveTimeout: chatSelection.displayAutoremoveTimeout, displayPresence: chatSelection.displayPresence), isPeerEnabled: isPeerEnabled, theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, animationCache: self.animationCache, animationRenderer: self.animationRenderer, disableAnimations: true, isInlineMode: false, autoSetReady: true, isMainTab: false)
            chatListNode.passthroughPeerSelection = true
            chatListNode.disabledPeerSelected = { peer, _, reason in
                attemptDisabledItemSelection?(peer, reason)
            }
            if let limit = limit {
                chatListNode.selectionLimit = limit
                chatListNode.reachedSelectionLimit = reachedSelectionLimit
            }
            chatListNode.accessibilityPageScrolledString = { row, count in
                return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
            }
            chatListNode.updateState { state in
                var state = state
                for peerId in selectedChats {
                    state.selectedPeerIds.insert(peerId)
                }
                if let additionalCategories = additionalCategories {
                    for id in additionalCategories.selectedCategories {
                        state.selectedAdditionalCategoryIds.insert(id)
                    }
                }
                return state
            }
            self.contentNode = .chats(chatListNode)
        } else {
            let displayTopPeers: ContactListPresentation.TopPeers
            var selectedPeers: [EnginePeer.Id] = []
            if case let .premiumGifting(birthdays, selectToday, hasActions) = mode {
                if let birthdays {
                    let today = Calendar(identifier: .gregorian).component(.day, from: Date())
                    var sections: [(String, [EnginePeer.Id], Bool)] = []
                    var todayPeers: [EnginePeer.Id] = []
                    var yesterdayPeers: [EnginePeer.Id] = []
                    var tomorrowPeers: [EnginePeer.Id] = []
                    
                    for (peerId, birthday) in birthdays {
                        if birthday.day == today {
                            todayPeers.append(peerId)
                            if selectToday {
                                selectedPeers.append(peerId)
                            }
                        } else if birthday.day == today - 1 || birthday.day > today + 5 {
                            yesterdayPeers.append(peerId)
                        } else if birthday.day == today + 1 || birthday.day < today + 5 {
                            tomorrowPeers.append(peerId)
                        }
                    }
                    
                    if !todayPeers.isEmpty {
                        sections.append((presentationData.strings.Premium_Gift_ContactSelection_BirthdayToday, todayPeers, hasActions))
                    }
                    if !yesterdayPeers.isEmpty {
                        sections.append((presentationData.strings.Premium_Gift_ContactSelection_BirthdayYesterday, yesterdayPeers, hasActions))
                    }
                    if !tomorrowPeers.isEmpty {
                        sections.append((presentationData.strings.Premium_Gift_ContactSelection_BirthdayTomorrow, tomorrowPeers, hasActions))
                    }
                    
                    displayTopPeers = .custom(showSelf: false, sections: sections)
                } else {
                    displayTopPeers = .recent
                }
            } else if case .requestedUsersSelection = mode {
                displayTopPeers = .recent
            } else {
                displayTopPeers = .none
            }
            
            let presentation: Signal<ContactListPresentation, NoError> = options
            |> map { options in
                return .natural(options: options, includeChatList: includeChatList, topPeers: displayTopPeers)
            }
            
            let contactListNode = ContactListNode(context: context, presentation: presentation, filters: filters, onlyWriteable: onlyWriteable, isGroupInvitation: isGroupInvitation, selectionState: ContactListNodeGroupSelectionState())
            self.contentNode = .contacts(contactListNode)
            
            if !selectedPeers.isEmpty {
                contactListNode.updateSelectionState { state in
                    var state = state ?? ContactListNodeGroupSelectionState()
                    for peerId in selectedPeers {
                        state = state.withToggledPeerId(.peer(peerId))
                    }
                    return state
                }
            }
        }
        
        self.tokenListNode = EditableTokenListNode(context: self.context, presentationTheme: self.presentationData.theme, theme: EditableTokenListNodeTheme(backgroundColor: .clear, separatorColor: self.presentationData.theme.rootController.navigationBar.separatorColor, placeholderTextColor: self.presentationData.theme.list.itemPlaceholderTextColor, primaryTextColor: self.presentationData.theme.list.itemPrimaryTextColor, tokenBackgroundColor: self.presentationData.theme.list.itemCheckColors.strokeColor.withAlphaComponent(0.25), selectedTextColor: self.presentationData.theme.list.itemCheckColors.foregroundColor, selectedBackgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, accentColor: self.presentationData.theme.list.itemAccentColor, keyboardColor: self.presentationData.theme.rootController.keyboardColor), placeholder: placeholder, shortPlaceholder: shortPlaceholder)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contentNode.node)
        self.navigationBar?.additionalContentNode.addSubnode(self.tokenListNode)
        
        switch self.contentNode {
        case let .contacts(contactsNode):
            contactsNode.openPeer = { [weak self] peer, action, sourceNode, gesture in
                if case .more = action {
                    self?.openPeerMore?(peer, sourceNode, gesture)
                } else {
                    self?.openPeer?(peer)
                }
            }
            contactsNode.openDisabledPeer = { [weak self] peer, reason in
                guard let self else {
                    return
                }
                self.openDisabledPeer?(peer, reason)
            }
            contactsNode.suppressPermissionWarning = { [weak self] in
                if let strongSelf = self {
                    strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                        present(c, a)
                    })
                }
            }
        case let .chats(chatsNode):
            chatsNode.peerSelected = { [weak self] peer, _, _, _, _ in
                self?.openPeer?(.peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil))
            }
            chatsNode.additionalCategorySelected = { [weak self] id in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.additionalCategorySelected?(id)
            }
        }
        
        let searchText = ValuePromise<String>()
        
        self.tokenListNode.deleteToken = { [weak self] id in
            if let id = id as? PeerId {
                self?.removeSelectedPeer?(ContactListPeerId.peer(id))
            } else if let id = id as? Int {
                self?.removeSelectedCategory?(id)
            }
        }
        
        self.tokenListNode.textUpdated = { [weak self] text in
            if let strongSelf = self {
                searchText.set(text)
                if text.isEmpty {
                    if let searchResultsNode = strongSelf.searchResultsNode {
                        searchResultsNode.removeFromSupernode()
                        strongSelf.searchResultsNode = nil
                    }
                } else {
                    if strongSelf.searchResultsNode == nil {
                        var selectionState: ContactListNodeGroupSelectionState?
                        switch strongSelf.contentNode {
                        case let .contacts(contactsNode):
                            contactsNode.updateSelectionState { state in
                                selectionState = state
                                return state
                            }
                        case let .chats(chatsNode):
                            selectionState = ContactListNodeGroupSelectionState()
                            for peerId in chatsNode.currentState.selectedPeerIds {
                                selectionState = selectionState?.withToggledPeerId(.peer(peerId))
                            }
                        }
                        var searchChatList = false
                        var searchGroups = false
                        var searchChannels = false
                        var globalSearch = false
                        var displaySavedMessages = true
                        var filters = filters
                        switch mode {
                        case .groupCreation, .channelCreation:
                            globalSearch = true
                        case let .peerSelection(searchChatListValue, searchGroupsValue, searchChannelsValue):
                            searchChatList = searchChatListValue
                            searchGroups = searchGroupsValue
                            searchChannels = searchChannelsValue
                            globalSearch = true
                        case let .chatSelection(chatSelection):
                            if chatSelection.onlyUsers {
                                searchChatList = true
                                searchGroups = false
                                searchChannels = false
                                displaySavedMessages = false
                                filters.append(.excludeSelf)
                            } else {
                                searchChatList = true
                                searchGroups = true
                                searchChannels = !chatSelection.disableChannels
                            }
                            globalSearch = false
                        case .premiumGifting, .requestedUsersSelection:
                            searchChatList = true
                        }
                        let searchResultsNode = ContactListNode(context: context, presentation: .single(.search(ContactListPresentation.Search(
                                signal: searchText.get(),
                                searchChatList: searchChatList,
                                searchDeviceContacts: false,
                                searchGroups: searchGroups,
                                searchChannels: searchChannels,
                                globalSearch: globalSearch,
                                displaySavedMessages: displaySavedMessages
                            ))), filters: filters, onlyWriteable: strongSelf.onlyWriteable, isGroupInvitation: strongSelf.isGroupInvitation, isPeerEnabled: strongSelf.isPeerEnabled, selectionState: selectionState, isSearch: true)
                        searchResultsNode.openPeer = { peer, _, _, _ in
                            self?.tokenListNode.setText("")
                            self?.openPeer?(peer)
                        }
                        searchResultsNode.openDisabledPeer = { peer, reason in
                            guard let self else {
                                return
                            }
                            self.openDisabledPeer?(peer, reason)
                        }
                        strongSelf.searchResultsNode = searchResultsNode
                        searchResultsNode.enableUpdates = true
                        searchResultsNode.backgroundColor = strongSelf.presentationData.theme.chatList.backgroundColor
                        if let (layout, navigationBarHeight, actualNavigationBarHeight) = strongSelf.containerLayout {
                            var insets = layout.insets(options: [.input])
                            insets.top += navigationBarHeight
                            insets.top += strongSelf.tokenListNode.bounds.size.height
                            
                            var headerInsets = layout.insets(options: [.input])
                            headerInsets.top += actualNavigationBarHeight
                            headerInsets.top += strongSelf.tokenListNode.bounds.size.height
                            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, storiesInset: 0.0, transition: .immediate)
                            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                        }
                        
                        strongSelf.searchResultsReadyDisposable.set((searchResultsNode.ready |> deliverOnMainQueue).startStrict(next: { _ in
                            if let strongSelf = self, let searchResultsNode = strongSelf.searchResultsNode {
                                strongSelf.insertSubnode(searchResultsNode, aboveSubnode: strongSelf.contentNode.node)
                            }
                        }))
                    }
                }
            }
        }
        self.tokenListNode.textReturned = { [weak self] in
            self?.complete?()
        }
        
        if let footerPanelNode = self.footerPanelNode {
            proceedImpl = { [weak self] in
                self?.complete?()
            }
            self.addSubnode(footerPanelNode)
        }
    }
    
    deinit {
        self.searchResultsReadyDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
    }
    
    func scrollToTop() {
        switch self.contentNode {
        case let .contacts(contactsNode):
            contactsNode.scrollToTop()
        case let .chats(chatsNode):
            chatsNode.scrollToPosition(.top(adjustForTempInset: false))
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
                
        let tokenListHeight = self.tokenListNode.updateLayout(tokens: self.editableTokens, width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
        
        transition.updateFrame(node: self.tokenListNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: tokenListHeight)))
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        
        insets.top += tokenListHeight
        headerInsets.top += tokenListHeight
        
        if let footerPanelNode = self.footerPanelNode {
            var count = 0
            if case let .contacts(contactListNode) = self.contentNode {
                count = contactListNode.selectionState?.selectedPeerIndices.count ?? 0
            }
            footerPanelNode.count = count
            let panelHeight = footerPanelNode.updateLayout(width: layout.size.width, sideInset: layout.safeInsets.left, bottomInset: headerInsets.bottom, transition: transition)
            if count == 0 {
                transition.updateFrame(node: footerPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: panelHeight)))
            } else {
                insets.bottom += panelHeight
                transition.updateFrame(node: footerPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
            }
        }
        
        switch self.contentNode {
        case let .contacts(contactsNode):
            contactsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, storiesInset: 0.0, transition: transition)
        case let .chats(chatsNode):
            var combinedInsets = insets
            combinedInsets.left += layout.safeInsets.left
            combinedInsets.right += layout.safeInsets.right
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: combinedInsets, headerInsets: headerInsets, duration: duration, curve: curve)
            chatsNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, visibleTopInset: updateSizeAndInsets.insets.top, originalTopInset: updateSizeAndInsets.insets.top, storiesInset: 0.0, inlineNavigationLocation: nil, inlineNavigationTransitionFraction: 0.0)
        }
        self.contentNode.node.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchResultsNode = self.searchResultsNode {
            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, storiesInset: 0.0, transition: transition)
            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        }

        return tokenListHeight
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)?) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
                completion?()
            }
        })
    }
}


private final class FooterPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let separatorNode: ASDisplayNode
    private let button: SolidRoundedButtonView
    
    private var validLayout: (CGFloat, CGFloat, CGFloat)?
    
    var count: Int = 0 {
        didSet {
            if self.count != oldValue && self.count > 0 {
                self.button.title = self.strings.Premium_Gift_ContactSelection_Proceed
                self.button.badge = "\(self.count)"
                
                if let (width, sideInset, bottomInset) = self.validLayout {
                    let _ = self.updateLayout(width: width, sideInset: sideInset, bottomInset: bottomInset, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.button = SolidRoundedButtonView(theme: SolidRoundedButtonTheme(theme: theme), height: 48.0, cornerRadius: 10.0)
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.separatorNode)
        
        self.button.pressed = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.addSubview(self.button)
    }
    
    func updateLayout(width: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, sideInset, bottomInset)
        let topInset: CGFloat = 9.0
        var bottomInset = bottomInset
        bottomInset += topInset - (bottomInset.isZero ? 0.0 : 4.0)
        
        let buttonInset: CGFloat = 16.0 + sideInset
        let buttonWidth = width - buttonInset * 2.0
        let buttonHeight = self.button.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(view: self.button, frame: CGRect(x: buttonInset, y: topInset, width: buttonWidth, height: buttonHeight))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return topInset + buttonHeight + bottomInset
    }
}
