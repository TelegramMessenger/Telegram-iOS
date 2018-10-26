import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private final class ChannelMembersSearchInteraction {
    let activateSearch: () -> Void
    let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    
    init(activateSearch: @escaping () -> Void, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void) {
        self.activateSearch = activateSearch
        self.openPeer = openPeer
    }
}

private enum ChannelMembersSearchEntryId: Hashable {
    case search
    case peer(PeerId)
}

private enum ChannelMembersSearchEntry: Comparable, Identifiable {
    case search
    case peer(Int, RenderedChannelParticipant, ContactsPeerItemEditing, String?, Bool)
    
    var stableId: ChannelMembersSearchEntryId {
        switch self {
            case .search:
                return .search
            case let .peer(peer):
                return .peer(peer.1.peer.id)
        }
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
            case .search:
                if case .search = rhs {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled):
                if case .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
            case .search:
                if case .search = rhs {
                    return false
                } else {
                    return true
                }
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.0 < rhsPeer.0
                } else {
                    return false
                }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ListViewItem {
        switch self {
            case .search:
                return ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    interaction.activateSearch()
                })
            case let .peer(_, participant, editing, label, enabled):
                let status: ContactsPeerItemStatus
                if let label = label {
                    status = .custom(label)
                } else {
                    status = .none
                }
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: .peer(peer: participant.peer, chatPeer: nil), status: status, enabled: enabled, selection: .none, editing: editing, index: nil, header: nil, action: { _ in
                    interaction.openPeer(participant.peer, participant)
                })
        }
    }
}

private struct ChannelMembersSearchTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let initial: Bool
}

private func preparedTransition(from fromEntries: [ChannelMembersSearchEntry]?, to toEntries: [ChannelMembersSearchEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ChannelMembersSearchTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries ?? [], rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return ChannelMembersSearchTransition(deletions: deletions, insertions: insertions, updates: updates, initial: fromEntries == nil)
}

class ChannelMembersSearchControllerNode: ASDisplayNode {
    private let account: Account
    private let peerId: PeerId
    private let mode: ChannelMembersSearchControllerMode
    private let filters: [ChannelMembersSearchFilter]
    let listNode: ListView
    var navigationBar: NavigationBar?
    
    private var enqueuedTransitions: [ChannelMembersSearchTransition] = []
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer, RenderedChannelParticipant?) -> Void)?
    
    var themeAndStrings: (PresentationTheme, PresentationStrings)

    private var disposable: Disposable?
    private var listControl: PeerChannelMemberCategoryControl?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, peerId: PeerId, mode: ChannelMembersSearchControllerMode, filters: [ChannelMembersSearchFilter]) {
        self.account = account
        self.listNode = ListView()
        self.peerId = peerId
        self.mode = mode
        self.filters = filters
        self.themeAndStrings = (theme, strings)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
        
        let interaction = ChannelMembersSearchInteraction(activateSearch: { [weak self] in
            self?.requestActivateSearch?()
        }, openPeer: { [weak self] peer, participant in
            self?.requestOpenPeerFromSearch?(peer, participant)
        })
        
        let previousEntries = Atomic<[ChannelMembersSearchEntry]?>(value: nil)
        let (disposable, loadMoreControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, peerId: peerId, updated: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            var entries: [ChannelMembersSearchEntry] = []
            entries.append(.search)
            
            var index = 0
            for participant in state.list {
                var label: String?
                var enabled = true
                switch mode {
                    case .ban:
                        if participant.peer.id == account.peerId {
                            continue
                        }
                        for filter in filters {
                            switch filter {
                            case let .exclude(ids):
                                if ids.contains(participant.peer.id) {
                                    continue
                                }
                            case .disable:
                                break
                            }
                        }
                    case .promote:
                        if participant.peer.id == account.peerId {
                            continue
                        }
                        for filter in filters {
                            switch filter {
                            case let .exclude(ids):
                                if ids.contains(participant.peer.id) {
                                    continue
                                }
                            case .disable:
                                break
                            }
                        }
                        if case .creator = participant.participant {
                            label = strings.Channel_Management_LabelCreator
                            enabled = false
                        }
                }
                entries.append(.peer(index, participant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled))
                index += 1
            }
            
            let previous = previousEntries.swap(entries)
            
            strongSelf.enqueueTransition(preparedTransition(from: previous, to: entries, account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction))
        })
        self.disposable = disposable
        self.listControl = loadMoreControl
        
        self.listNode.visibleBottomContentOffsetChanged = { offset in
            if case let .known(value) = offset, value < 40.0 {
                account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
            }
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.themeAndStrings = (theme, strings)
        self.searchDisplayController?.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        self.listNode.forEachItemNode { node in
            if let node = node as? ChatListSearchItemNode {
                maybePlaceholderNode = node.searchBarNode
            }
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if let placeholderNode = maybePlaceholderNode {
            self.searchDisplayController = SearchDisplayController(theme: self.themeAndStrings.0, strings: self.themeAndStrings.1, contentNode: ChannelMembersSearchContainerNode(account: self.account, peerId: self.peerId, mode: .banAndPromoteActions, filters: self.filters, openPeer: { [weak self] peer, participant in
                self?.requestOpenPeerFromSearch?(peer, participant)
            }, updateActivity: { value in
                
            }), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { subnode in
                self.insertSubnode(subnode, belowSubnode: navigationBar)
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchTransition) {
        enqueuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let options = ListViewDeleteAndInsertOptions()
            if transition.initial {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                //options.insert(.AnimateTopItemPosition)
                //options.insert(.AnimateCrossfade)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
