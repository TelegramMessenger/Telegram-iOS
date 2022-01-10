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
    var removeSelectedPeer: ((ContactListPeerId) -> Void)?
    var removeSelectedCategory: ((Int) -> Void)?
    var additionalCategorySelected: ((Int) -> Void)?
    var complete: (() -> Void)?
    
    var editableTokens: [EditableTokenListToken] = []
    
    private let searchResultsReadyDisposable = MetaDisposable()
    var dismiss: (() -> Void)?
    
    private var presentationData: PresentationData
    
    init(navigationBar: NavigationBar?, context: AccountContext, presentationData: PresentationData, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter]) {
        self.navigationBar = navigationBar
        
        self.context = context
        self.presentationData = presentationData
        
        var placeholder: String
        var includeChatList = false
        switch mode {
            case let .peerSelection(_, searchGroups, searchChannels):
                includeChatList = searchGroups || searchChannels
                if searchGroups {
                    placeholder = self.presentationData.strings.Contacts_SearchUsersAndGroupsLabel
                } else {
                    placeholder = self.presentationData.strings.Contacts_SearchLabel
                }
            default:
                placeholder = self.presentationData.strings.Compose_TokenListPlaceholder
        }
        
        if case let .chatSelection(_, selectedChats, additionalCategories, chatListFilters) = mode {
            placeholder = self.presentationData.strings.ChatListFilter_AddChatsTitle
            let chatListNode = ChatListNode(context: context, groupId: .root, previewing: false, fillPreloadItems: false, mode: .peers(filter: [.excludeSecretChats], isSelecting: true, additionalCategories: additionalCategories?.categories ?? [], chatListFilters: chatListFilters), theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
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
            self.contentNode = .contacts(ContactListNode(context: context, presentation: .single(.natural(options: options, includeChatList: includeChatList)), filters: filters, selectionState: ContactListNodeGroupSelectionState()))
        }
        
        self.tokenListNode = EditableTokenListNode(theme: EditableTokenListNodeTheme(backgroundColor: .clear, separatorColor: self.presentationData.theme.rootController.navigationBar.separatorColor, placeholderTextColor: self.presentationData.theme.list.itemPlaceholderTextColor, primaryTextColor: self.presentationData.theme.list.itemPrimaryTextColor, selectedTextColor: self.presentationData.theme.list.itemCheckColors.foregroundColor, selectedBackgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, accentColor: self.presentationData.theme.list.itemAccentColor, keyboardColor: self.presentationData.theme.rootController.keyboardColor), placeholder: placeholder)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contentNode.node)
        self.navigationBar?.additionalContentNode.addSubnode(self.tokenListNode)
        
        switch self.contentNode {
        case let .contacts(contactsNode):
            contactsNode.openPeer = { [weak self] peer, _ in
                self?.openPeer?(peer)
            }
        case let .chats(chatsNode):
            chatsNode.peerSelected = { [weak self] peer, _, _, _ in
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
                        switch mode {
                        case .groupCreation, .channelCreation:
                            globalSearch = true
                        case let .peerSelection(searchChatListValue, searchGroupsValue, searchChannelsValue):
                            searchChatList = searchChatListValue
                            searchGroups = searchGroupsValue
                            searchChannels = searchChannelsValue
                            globalSearch = true
                        case .chatSelection:
                            searchChatList = true
                            searchGroups = true
                            searchChannels = true
                            globalSearch = false
                        }
                        let searchResultsNode = ContactListNode(context: context, presentation: .single(.search(signal: searchText.get(), searchChatList: searchChatList, searchDeviceContacts: false, searchGroups: searchGroups, searchChannels: searchChannels, globalSearch: globalSearch)), filters: filters, selectionState: selectionState, isSearch: true)
                        searchResultsNode.openPeer = { peer, _ in
                            self?.tokenListNode.setText("")
                            self?.openPeer?(peer)
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
                            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: .immediate)
                            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                        }
                        
                        strongSelf.searchResultsReadyDisposable.set((searchResultsNode.ready |> deliverOnMainQueue).start(next: { _ in
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
            chatsNode.scrollToPosition(.top)
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
        
        switch self.contentNode {
        case let .contacts(contactsNode):
            contactsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
        case let .chats(chatsNode):
            var combinedInsets = insets
            combinedInsets.left += layout.safeInsets.left
            combinedInsets.right += layout.safeInsets.right
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: combinedInsets, headerInsets: headerInsets, duration: duration, curve: curve)
            chatsNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        }
        self.contentNode.node.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchResultsNode = self.searchResultsNode {
            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
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
