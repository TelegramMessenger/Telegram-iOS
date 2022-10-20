import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import TemporaryCachedPeerDataManager
import SearchUI
import ItemListPeerItem
import ContactsPeerItem
import ChatListSearchItemHeader
import ItemListUI

enum ParticipantRevealActionType {
    case promote
    case restrict
    case remove
}

struct ParticipantRevealAction: Equatable {
    let type: ItemListPeerItemRevealOptionType
    let title: String
    let action: ParticipantRevealActionType
}

public enum ChannelMembersSearchMode {
    case searchMembers
    case searchAdmins
    case searchBanned
    case searchKicked
    case banAndPromoteActions
    case inviteActions
}

private enum ChannelMembersSearchSection {
    case none
    case members
    case banned
    case contacts
    case bots
    case admins
    case global
    
    var chatListHeaderType: ChatListSearchItemHeaderType? {
        switch self {
            case .none:
                return nil
            case .members:
                return .members
            case .banned:
                return .exceptions
            case .contacts:
                return .contacts
            case .bots:
                return .bots
            case .admins:
                return .admins
            case .global:
                return .globalPeers
        }
    }
}

private enum ChannelMembersSearchContent: Equatable {
    case peer(Peer)
    case participant(participant: RenderedChannelParticipant, label: String?, revealActions: [ParticipantRevealAction], revealed: Bool, enabled: Bool)
    
    static func ==(lhs: ChannelMembersSearchContent, rhs: ChannelMembersSearchContent) -> Bool {
        switch lhs {
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.isEqual(rhsPeer)
                } else {
                    return false
                }
            case let .participant(participant, label, revealActions, revealed, enabled):
                if case .participant(participant, label, revealActions, revealed, enabled) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .peer(peer):
                return peer.id
            case let .participant(participant, _, _, _, _):
                return participant.peer.id
        }
    }
}

private struct RevealedPeerId: Equatable {
    let peerId: PeerId
    let section: ChannelMembersSearchSection
}

private final class ChannelMembersSearchContainerInteraction {
    let peerSelected: (Peer, RenderedChannelParticipant?) -> Void
    let setPeerIdWithRevealedOptions: (RevealedPeerId?, RevealedPeerId?) -> Void
    let promotePeer: (RenderedChannelParticipant) -> Void
    let restrictPeer: (RenderedChannelParticipant) -> Void
    let removePeer: (PeerId) -> Void
    
    init(peerSelected: @escaping (Peer, RenderedChannelParticipant?) -> Void, setPeerIdWithRevealedOptions: @escaping (RevealedPeerId?, RevealedPeerId?) -> Void, promotePeer: @escaping (RenderedChannelParticipant) -> Void, restrictPeer: @escaping (RenderedChannelParticipant) -> Void, removePeer: @escaping (PeerId) -> Void) {
        self.peerSelected = peerSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.promotePeer = promotePeer
        self.restrictPeer = restrictPeer
        self.removePeer = removePeer
    }
}

private struct ChannelMembersSearchEntryId: Hashable {
    let peerId: PeerId
    let section: ChannelMembersSearchSection
}

private final class ChannelMembersSearchEntry: Comparable, Identifiable {
    let index: Int
    let content: ChannelMembersSearchContent
    let section: ChannelMembersSearchSection
    let dateTimeFormat: PresentationDateTimeFormat
    let addIcon: Bool
    
    init(index: Int, content: ChannelMembersSearchContent, section: ChannelMembersSearchSection, dateTimeFormat: PresentationDateTimeFormat, addIcon: Bool = false) {
        self.index = index
        self.content = content
        self.section = section
        self.dateTimeFormat = dateTimeFormat
        self.addIcon = addIcon
    }
    
    var stableId: ChannelMembersSearchEntryId {
        return ChannelMembersSearchEntryId(peerId: self.content.peerId, section: self.section)
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.content == rhs.content && lhs.section == rhs.section && lhs.addIcon == rhs.addIcon
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchContainerInteraction) -> ListViewItem {
        switch self.content {
            case let .peer(peer):
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer), chatPeer: EnginePeer(peer)), status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil) }), action: { _ in
                    interaction.peerSelected(peer, nil)
                })
            case let .participant(participant, label, revealActions, revealed, enabled):
                let status: ContactsPeerItemStatus
                if let label = label {
                    status = .custom(string: label, multiline: false)
                } else if let presence = participant.presences[participant.peer.id], self.addIcon {
                    status = .presence(EnginePeer.Presence(presence), dateTimeFormat)
                } else {
                    status = .none
                }
                
                var options: [ItemListPeerItemRevealOption] = []
                for action in revealActions {
                    options.append(ItemListPeerItemRevealOption(type: action.type, title: action.title, action: {
                        switch action.action {
                            case .promote:
                                interaction.promotePeer(participant)
                                break
                            case .restrict:
                                interaction.restrictPeer(participant)
                                break
                            case .remove:
                                interaction.removePeer(participant.peer.id)
                                break
                        }
                    }))
                }
                var actionIcon: ContactsPeerItemActionIcon = .none
                if self.addIcon {
                    actionIcon = .add
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(participant.peer), chatPeer: EnginePeer(participant.peer)), status: status, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: revealed), options: options, actionIcon: actionIcon, index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil) }), action: { _ in
                    interaction.peerSelected(participant.peer, participant)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    interaction.setPeerIdWithRevealedOptions(RevealedPeerId(peerId: participant.peer.id, section: self.section), fromPeerId.flatMap({ RevealedPeerId(peerId: $0, section: self.section) }))
                })
        }
    }
}

struct ChannelMembersSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmpty: Bool
    let query: String
}

private enum GroupMemberCategory {
    case contacts
    case admins
    case bots
    case members
}

private func categorySignal(context: AccountContext, peerId: PeerId, category: GroupMemberCategory) -> Signal<[RenderedChannelParticipant], NoError> {
    return Signal<[RenderedChannelParticipant], NoError> { subscriber in
        let disposableAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
        func processListState(_ listState: ChannelMemberListState) {
            assert(Queue.mainQueue().isCurrent())
            
            var process = false
            if case .ready = listState.loadingState {
                process = true
            } else if !listState.list.isEmpty {
                process = true
            }
            if process {
                subscriber.putNext(listState.list)
            }
        }
        switch category {
            case .admins:
                disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, updated: processListState)
            case .contacts:
                disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.contacts(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, updated: processListState)
            case .bots:
                disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.bots(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, updated: processListState)
            case .members:
                disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, updated: processListState)
        }
        
        let (disposable, _) = disposableAndLoadMoreControl
        return disposable
    }
    |> runOn(.mainQueue())
}

private struct GroupMembersSearchContextState {
    var contacts: [RenderedChannelParticipant] = []
    var admins: [RenderedChannelParticipant] = []
    var bots: [RenderedChannelParticipant] = []
    var members: [RenderedChannelParticipant] = []
}

public final class GroupMembersSearchContext {
    fileprivate let state = Promise<GroupMembersSearchContextState>()
    
    public init(context: AccountContext, peerId: PeerId) {
        assert(Queue.mainQueue().isCurrent())
        
        let combinedSignal = combineLatest(queue: .mainQueue(), categorySignal(context: context, peerId: peerId, category: .contacts), categorySignal(context: context, peerId: peerId, category: .bots), categorySignal(context: context, peerId: peerId, category: .admins), categorySignal(context: context, peerId: peerId, category: .members))
        |> map { contacts, bots, admins, members -> GroupMembersSearchContextState in
            let contactPeerIds = Set(contacts.map({ $0.peer.id }))
            let adminPeerIds = Set(admins.map({ $0.peer.id }))
            let botPeerIds = Set(bots.map({ $0.peer.id }))
            var excludeMemberPeerIds = contactPeerIds
            excludeMemberPeerIds.formUnion(adminPeerIds)
            excludeMemberPeerIds.formUnion(botPeerIds)
            let filteredMembers = members.filter({ !excludeMemberPeerIds.contains($0.peer.id) })
            return GroupMembersSearchContextState(contacts: contacts, admins: admins, bots: bots, members: filteredMembers)
        }
        self.state.set(combinedSignal)
    }
}

private func channelMembersSearchContainerPreparedRecentTransition(from fromEntries: [ChannelMembersSearchEntry], to toEntries: [ChannelMembersSearchEntry], isSearching: Bool, isEmpty: Bool, query: String, context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchContainerInteraction) -> ChannelMembersSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return ChannelMembersSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmpty: isEmpty, query: query)
}

private struct ChannelMembersSearchContainerState: Equatable {
    var revealedPeerId: RevealedPeerId?
    var removingParticipantIds = Set<PeerId>()
}

public final class ChannelMembersSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    private let mode: ChannelMembersSearchMode
    
    private let emptyQueryListNode: ListView
    private let listNode: ListView
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedEmptyQueryTransitions: [(ChannelMembersSearchContainerTransition, Bool)] = []
    private var enqueuedTransitions: [(ChannelMembersSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let searchQuery = Promise<String?>()
    private let emptyQueryDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private let forceTheme: PresentationTheme?
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let removeMemberDisposable = MetaDisposable()
    
    private let presentationDataPromise: Promise<PresentationData>
    
    private var _hasDim: Bool = false
    override public var hasDim: Bool {
        return _hasDim
    }
    
    public init(context: AccountContext, forceTheme: PresentationTheme?, peerId: PeerId, mode: ChannelMembersSearchMode, filters: [ChannelMembersSearchFilter], searchContext: GroupMembersSearchContext?, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, updateActivity: @escaping (Bool) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.context = context
        self.openPeer = openPeer
        self.mode = mode
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.forceTheme = forceTheme
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.emptyQueryListNode = ListView()
        self.emptyQueryListNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.displaysAsynchronously = false
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.displaysAsynchronously = false
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
        
        self.emptyQueryListNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        if !filters.contains(where: { filter in
            if case .excludeBots = filter {
                return true
            } else {
                return false
            }
        }) {
            self.addSubnode(self.emptyQueryListNode)
        } else {
            self._hasDim = true
        }
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        let statePromise = ValuePromise(ChannelMembersSearchContainerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: ChannelMembersSearchContainerState())
        let updateState: ((ChannelMembersSearchContainerState) -> ChannelMembersSearchContainerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let removeMemberDisposable = self.removeMemberDisposable
        let interaction = ChannelMembersSearchContainerInteraction(peerSelected: { [weak self] peer, participant in
            openPeer(peer, participant)
            self?.listNode.clearHighlightAnimated(true)
        }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                var state = state
                if (peerId == nil && fromPeerId == state.revealedPeerId) || (peerId != nil && fromPeerId == nil) {
                    state.revealedPeerId = peerId
                }
                return state
            }
        }, promotePeer: { participant in
            updateState { state in
                var state = state
                state.revealedPeerId = nil
                return state
            }
            pushController(channelAdminController(context: context, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }, upgradedToSupergroup: { _, f in f() }, transferedOwnership: { _ in }))
        }, restrictPeer: { participant in
            updateState { state in
                var state = state
                state.revealedPeerId = nil
                return state
            }
            pushController(channelBannedMemberController(context: context, peerId: peerId, memberId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }, upgradedToSupergroup: { _, f in f() }))
        }, removePeer: { memberId in
            updateState { state in
                var state = state
                state.revealedPeerId = nil
                return state
            }
            let signal = context.account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                result.set(true)
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var state = state
                        state.removingParticipantIds.insert(memberId)
                        return state
                    }
                    
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if case .searchAdmins = mode {
                            return context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(engine: context.engine, peerId: peerId, memberId: memberId, adminRights: nil, rank: nil)
                            |> `catch` { _ -> Signal<Void, NoError> in
                                return .complete()
                            }
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    updateState { state in
                                        var state = state
                                        state.removingParticipantIds.remove(memberId)
                                        return state
                                    }
                                }
                            }
                        }
                        
                        return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                updateState { state in
                                    var state = state
                                    state.removingParticipantIds.remove(memberId)
                                    return state
                                }
                            }
                        }
                    }
                    
                    if case .searchAdmins = mode {
                        return context.engine.peers.removeGroupAdmin(peerId: peerId, adminId: memberId)
                        |> `catch` { _ -> Signal<Void, NoError> in
                            return .complete()
                        }
                        |> deliverOnMainQueue
                        |> afterDisposed {
                            updateState { state in
                                var state = state
                                state.removingParticipantIds.remove(memberId)
                                return state
                            }
                        }
                    }
                    
                    return context.engine.peers.removePeerMember(peerId: peerId, memberId: memberId)
                    |> deliverOnMainQueue
                    |> afterDisposed {
                        updateState { state in
                            var state = state
                            state.removingParticipantIds.remove(memberId)
                            return state
                        }
                    }
                } else {
                    return .complete()
                }
            }
            removeMemberDisposable.set(signal.start())
        })
        
        let presentationDataPromise = self.presentationDataPromise
        
        let emptyQueryItems: Signal<[ChannelMembersSearchEntry]?, NoError>
        if let searchContext = searchContext {
            emptyQueryItems = combineLatest(queue: .mainQueue(), statePromise.get(), searchContext.state.get(), context.account.postbox.peerView(id: peerId) |> take(1), presentationDataPromise.get())
            |> map { state, searchState, peerView, presentationData -> [ChannelMembersSearchEntry]? in
                if let channel = peerView.peers[peerId] as? TelegramChannel {
                    var entries: [ChannelMembersSearchEntry] = []
                    
                    var index = 0
                    
                    func processParticipant(participant: RenderedChannelParticipant, section: ChannelMembersSearchSection) {
                        var canPromote: Bool
                        var canRestrict: Bool
                        switch participant.participant {
                            case .creator:
                                canPromote = false
                                canRestrict = false
                            case let .member(_, _, adminRights, bannedRights, _):
                                if channel.hasPermission(.addAdmins) {
                                    canPromote = true
                                } else {
                                    canPromote = false
                                }
                                if channel.hasPermission(.banMembers) {
                                    canRestrict = true
                                } else {
                                    canRestrict = false
                                }
                                if canPromote {
                                    if let bannedRights = bannedRights {
                                        if bannedRights.restrictedBy != context.account.peerId && !channel.flags.contains(.isCreator) {
                                            canPromote = false
                                        }
                                    }
                                }
                                if canRestrict {
                                    if let adminRights = adminRights {
                                        if adminRights.promotedBy != context.account.peerId && !channel.flags.contains(.isCreator) {
                                            canRestrict = false
                                        }
                                    }
                                }
                        }
                        
                        var label: String?
                        var enabled = true
                        if case .searchMembers = mode {
                            switch participant.participant {
                                case .creator:
                                    label = presentationData.strings.Channel_Management_LabelOwner
                                default:
                                    break
                            }
                        }
                        
                        if state.removingParticipantIds.contains(participant.peer.id) {
                            enabled = false
                        }
                        
                        var peerActions: [ParticipantRevealAction] = []
                        if case .searchMembers = mode {
                            if canPromote {
                                peerActions.append(ParticipantRevealAction(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: .promote))
                            }
                            if canRestrict {
                                peerActions.append(ParticipantRevealAction(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: .restrict))
                                peerActions.append(ParticipantRevealAction(type: .destructive, title: presentationData.strings.Common_Delete, action: .remove))
                            }
                        }
                        
                        entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: peerActions, revealed: state.revealedPeerId == RevealedPeerId(peerId: participant.peer.id, section: section), enabled: enabled), section: section, dateTimeFormat: presentationData.dateTimeFormat))
                        index += 1
                    }
                    
                    for participant in searchState.contacts {
                        processParticipant(participant: participant, section: .contacts)
                    }
                    
                    for participant in searchState.bots {
                        processParticipant(participant: participant, section: .bots)
                    }
                    
                    for participant in searchState.admins {
                        processParticipant(participant: participant, section: .admins)
                    }
                    
                    for participant in searchState.members {
                        processParticipant(participant: participant, section: .members)
                    }
                    
                    return entries
                } else {
                    return nil
                }
            }
        } else {
            emptyQueryItems = .single(nil)
        }
        
        let foundItems = combineLatest(self.searchQuery.get(), context.account.postbox.peerView(id: peerId) |> take(1))
        |> mapToSignal { query, peerView -> Signal<[ChannelMembersSearchEntry]?, NoError> in
            guard let query = query, !query.isEmpty else {
                return .single(nil)
            }
            if let channel = peerView.peers[peerId] as? TelegramChannel {
                updateActivity(true)
                let foundGroupMembers: Signal<[RenderedChannelParticipant], NoError>
                let foundMembers: Signal<[RenderedChannelParticipant], NoError>
                
                switch mode {
                    case .searchMembers, .banAndPromoteActions:
                        foundGroupMembers = Signal { subscriber in
                            let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                                if case .ready = state.loadingState {
                                    subscriber.putNext(state.list)
                                }
                            })
                            return disposable
                        }
                        |> runOn(Queue.mainQueue())
                        foundMembers = .single([])
                    case .inviteActions:
                        foundGroupMembers = .single([])
                        foundMembers = context.engine.peers.channelMembers(peerId: peerId, category: .recent(.search(query)))
                        |> map { $0 ?? [] }
                case .searchAdmins:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                            }
                        })
                        return disposable
                    } |> runOn(Queue.mainQueue())
                    foundMembers = .single([])
                case .searchBanned:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.restricted(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                                subscriber.putCompletion()
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                    foundMembers = Signal { subscriber in
                        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list.filter({ participant in
                                    return participant.peer.id != context.account.peerId
                                }))
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                case .searchKicked:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.banned(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                                subscriber.putCompletion()
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                    foundMembers = .single([])
                }
                
                let foundContacts: Signal<([Peer], [PeerId: PeerPresence]), NoError>
                let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError>
                switch mode {
                    case .inviteActions, .banAndPromoteActions:
                        if filters.contains(where: { filter in
                            if case .excludeNonMembers = filter {
                                return true
                            } else {
                                return false
                            }
                        }) {
                            foundContacts = .single(([], [:]))
                            foundRemotePeers = .single(([], []))
                        } else {
                            foundContacts = context.account.postbox.searchContacts(query: query.lowercased())
                            foundRemotePeers = .single(([], [])) |> then(context.engine.contacts.searchRemotePeers(query: query)
                            |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                        }
                    case .searchMembers, .searchBanned, .searchKicked, .searchAdmins:
                        foundContacts = .single(([], [:]))
                        foundRemotePeers = .single(([], []))
                }
                
                return combineLatest(foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, presentationDataPromise.get(), statePromise.get())
                |> map { foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, presentationData, state -> [ChannelMembersSearchEntry]? in
                    var entries: [ChannelMembersSearchEntry] = []
                    
                    var existingPeerIds = Set<PeerId>()
                    var excludeBots = false
                    for filter in filters {
                        switch filter {
                            case let .exclude(ids):
                                existingPeerIds = existingPeerIds.union(ids)
                            case .disable, .excludeNonMembers:
                                break
                            case .excludeBots:
                                excludeBots = true
                        }
                    }
                    switch mode {
                        case .inviteActions, .banAndPromoteActions:
                            existingPeerIds.insert(context.account.peerId)
                        case .searchMembers, .searchAdmins, .searchBanned, .searchKicked:
                            break
                    }
                    
                    var index = 0
                    
                    for participant in foundGroupMembers {
                        if participant.peer.isDeleted {
                            continue
                        }
                        
                        if excludeBots, let user = participant.peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    section = .members
                                case .searchBanned:
                                    section = .banned
                                case .searchMembers, .searchKicked, .searchAdmins:
                                    section = .none
                            }
                            
                            var canPromote: Bool
                            var canRestrict: Bool
                            switch participant.participant {
                                case .creator:
                                    canPromote = false
                                    canRestrict = false
                                case let .member(_, _, adminRights, bannedRights, _):
                                    if channel.hasPermission(.addAdmins) {
                                        canPromote = true
                                    } else {
                                        canPromote = false
                                    }
                                    if channel.hasPermission(.banMembers) {
                                        canRestrict = true
                                    } else {
                                        canRestrict = false
                                    }
                                    if canPromote {
                                        if let bannedRights = bannedRights {
                                            if bannedRights.restrictedBy != context.account.peerId && !channel.flags.contains(.isCreator) {
                                                canPromote = false
                                            }
                                        }
                                    }
                                    if canRestrict {
                                        if let adminRights = adminRights {
                                            if adminRights.promotedBy != context.account.peerId && !channel.flags.contains(.isCreator) {
                                                canRestrict = false
                                            }
                                        }
                                    }
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = presentationData.strings.Channel_Management_LabelOwner
                                    enabled = false
                                }
                            } else if case .searchMembers = mode {
                                switch participant.participant {
                                    case .creator:
                                        label = presentationData.strings.Channel_Management_LabelOwner
                                    case let .member(_, _, adminInfo, _, _):
                                        if adminInfo != nil {
                                            label = presentationData.strings.Channel_Management_LabelEditor
                                        }
                                }
                            }
                            
                            if state.removingParticipantIds.contains(participant.peer.id) {
                                enabled = false
                            }
                            
                            var peerActions: [ParticipantRevealAction] = []
                            if case .searchMembers = mode {
                                if canPromote {
                                    peerActions.append(ParticipantRevealAction(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: .promote))
                                }
                                if canRestrict {
                                    peerActions.append(ParticipantRevealAction(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: .restrict))
                                    peerActions.append(ParticipantRevealAction(type: .destructive, title: presentationData.strings.Common_Delete, action: .remove))
                                }
                            } else if case .searchAdmins = mode {
                                if canRestrict {
                                    peerActions.append(ParticipantRevealAction(type: .destructive, title: presentationData.strings.Common_Delete, action: .remove))
                                }
                            }
                            
                            switch mode {
                                case .searchAdmins:
                                    switch participant.participant {
                                        case .creator:
                                            label = presentationData.strings.Channel_Management_LabelOwner
                                        case let .member(_, _, adminInfo, _, _):
                                            if let adminInfo = adminInfo {
                                                if let peer = participant.peers[adminInfo.promotedBy] {
                                                    if peer.id == participant.peer.id {
                                                        label = presentationData.strings.Channel_Management_LabelAdministrator
                                                    } else {
                                                        label = presentationData.strings.Channel_Management_PromotedBy(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                    }
                                                }
                                            }
                                    }
                                case .searchBanned:
                                    switch participant.participant {
                                        case let .member(_, _, _, banInfo, _):
                                            if let banInfo = banInfo {
                                                var exceptionsString = ""
                                                for (rights, _) in allGroupPermissionList {
                                                    if banInfo.rights.flags.contains(rights) {
                                                        if !exceptionsString.isEmpty {
                                                            exceptionsString.append(", ")
                                                        }
                                                        exceptionsString.append(compactStringForGroupPermission(strings: presentationData.strings, right: rights))
                                                    }
                                                }
                                                label = exceptionsString
                                            }
                                        default:
                                            break
                                    }
                                case .searchKicked:
                                    switch participant.participant {
                                        case let .member(_, _, _, banInfo, _):
                                            if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                                                label = presentationData.strings.Channel_Management_RemovedBy(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                            }
                                        default:
                                            break
                                    }
                                default:
                                    break
                            }
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: peerActions, revealed: state.revealedPeerId == RevealedPeerId(peerId: participant.peer.id, section: section), enabled: enabled), section: section, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    for participant in foundMembers {
                        if excludeBots, let user = participant.peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            var addIcon = false
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    section = .members
                                case .searchBanned:
                                    section = .members
                                    addIcon = true
                                case .searchMembers, .searchKicked, .searchAdmins:
                                    section = .none
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = presentationData.strings.Channel_Management_LabelOwner
                                    enabled = false
                                }
                            }
                            
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: [], revealed: false, enabled: enabled), section: section, dateTimeFormat: presentationData.dateTimeFormat, addIcon: addIcon))
                            index += 1
                        }
                    }
                    
                    for peer in foundContacts.0 {
                        if excludeBots, let user = peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .contacts, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.0 {
                        let peer = foundPeer.peer
                        
                        if excludeBots, let user = peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.1 {
                        let peer = foundPeer.peer
                        if excludeBots, let user = peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    return entries
                }
            } else if let _ = peerView.peers[peerId] as? TelegramGroup, let cachedData = peerView.cachedData as? CachedGroupData {
                updateActivity(true)
                let foundGroupMembers: Signal<[RenderedChannelParticipant], NoError>
                let foundMembers: Signal<[RenderedChannelParticipant], NoError>
                let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError>
                
                switch mode {
                    case .searchMembers, .banAndPromoteActions:
                        var matchingMembers: [RenderedChannelParticipant] = []
                        if let participants = cachedData.participants {
                            for participant in participants.participants {
                                guard let peer = peerView.peers[participant.peerId] else {
                                    continue
                                }
                                if !peer.indexName.matchesByTokens(query.lowercased()) {
                                    continue
                                }
                                var creatorPeer: Peer?
                                for participant in participants.participants {
                                    if let peer = peerView.peers[participant.peerId] {
                                        switch participant {
                                            case .creator:
                                                creatorPeer = peer
                                            default:
                                                break
                                        }
                                    }
                                }
                                
                                let renderedParticipant: RenderedChannelParticipant
                                switch participant {
                                    case .creator:
                                        renderedParticipant = RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer)
                                    case .admin:
                                        var peers: [PeerId: Peer] = [:]
                                        if let creator = creatorPeer {
                                            peers[creator.id] = creator
                                        }
                                        peers[peer.id] = peer
                                        renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .groupSpecific), promotedBy: creatorPeer?.id ?? context.account.peerId, canBeEditedByAccountPeer: creatorPeer?.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers)
                                    case .member:
                                        var peers: [PeerId: Peer] = [:]
                                        peers[peer.id] = peer
                                        renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), peer: peer, peers: peers)
                                }
                                matchingMembers.append(renderedParticipant)
                            }
                        }
                        foundGroupMembers = .single(matchingMembers)
                        foundMembers = .single([])
                    case .inviteActions:
                        foundGroupMembers = .single([])
                        foundMembers = .single([])
                    case .searchAdmins:
                        foundGroupMembers = .single([])
                        foundMembers = .single([])
                    case .searchBanned:
                        foundGroupMembers = .single([])
                        foundMembers = .single([])
                    case .searchKicked:
                        foundGroupMembers = .single([])
                        foundMembers = .single([])
                }
                
                if mode == .banAndPromoteActions || mode == .inviteActions {
                    foundRemotePeers = .single(([], [])) |> then(context.engine.contacts.searchRemotePeers(query: query)
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                } else {
                    foundRemotePeers = .single(([], []))
                }
                
                return combineLatest(foundGroupMembers, foundMembers, foundRemotePeers, presentationDataPromise.get(), statePromise.get())
                |> map { foundGroupMembers, foundMembers, foundRemotePeers, presentationData, state -> [ChannelMembersSearchEntry]? in
                    var entries: [ChannelMembersSearchEntry] = []
                    
                    var existingPeerIds = Set<PeerId>()
                    var excludeBots = false
                    for filter in filters {
                        switch filter {
                        case let .exclude(ids):
                            existingPeerIds = existingPeerIds.union(ids)
                        case .disable, .excludeNonMembers:
                            break
                        case .excludeBots:
                            excludeBots = true
                        }
                    }
                    switch mode {
                        case .inviteActions, .banAndPromoteActions:
                            existingPeerIds.insert(context.account.peerId)
                        case .searchMembers, .searchAdmins, .searchBanned, .searchKicked:
                            break
                    }
                    
                    var index = 0
                    
                    for participant in foundGroupMembers {
                        if excludeBots, let user = participant.peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            switch mode {
                            case .inviteActions, .banAndPromoteActions:
                                section = .members
                            case .searchBanned:
                                section = .banned
                            case .searchMembers, .searchKicked, .searchAdmins:
                                section = .none
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = presentationData.strings.Channel_Management_LabelOwner
                                    enabled = false
                                }
                            } else if case .searchMembers = mode {
                                switch participant.participant {
                                    case .creator:
                                        label = presentationData.strings.Channel_Management_LabelOwner
                                    case let .member(_, _, adminInfo, _, _):
                                        if adminInfo != nil {
                                            label = presentationData.strings.Channel_Management_LabelEditor
                                        }
                                }
                            }
                            
                            if state.removingParticipantIds.contains(participant.peer.id) {
                                enabled = false
                            }
                            
                            switch mode {
                                case .searchAdmins:
                                    switch participant.participant {
                                    case .creator:
                                        label = presentationData.strings.Channel_Management_LabelOwner
                                    case let .member(_, _, adminInfo, _, _):
                                        if let adminInfo = adminInfo {
                                            if let peer = participant.peers[adminInfo.promotedBy] {
                                                if peer.id == participant.peer.id {
                                                    label = presentationData.strings.Channel_Management_LabelAdministrator
                                                } else {
                                                    label = presentationData.strings.Channel_Management_PromotedBy(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                }
                                            }
                                        }
                                    }
                                case .searchBanned:
                                    switch participant.participant {
                                        case let .member(_, _, _, banInfo, _):
                                            if let banInfo = banInfo {
                                                var exceptionsString = ""
                                                for (rights, _) in allGroupPermissionList {
                                                    if banInfo.rights.flags.contains(rights) {
                                                        if !exceptionsString.isEmpty {
                                                            exceptionsString.append(", ")
                                                        }
                                                        exceptionsString.append(compactStringForGroupPermission(strings: presentationData.strings, right: rights))
                                                    }
                                                }
                                                label = exceptionsString
                                            }
                                        default:
                                            break
                                    }
                                case .searchKicked:
                                    switch participant.participant {
                                    case let .member(_, _, _, banInfo, _):
                                        if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                                            label = presentationData.strings.Channel_Management_RemovedBy(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                        }
                                    default:
                                        break
                                    }
                                default:
                                    break
                            }
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: [], revealed: state.revealedPeerId == RevealedPeerId(peerId: participant.peer.id, section: section), enabled: enabled), section: section, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    for participant in foundMembers {
                        if excludeBots, let user = participant.peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            var addIcon = false
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    section = .members
                                case .searchBanned:
                                    section = .members
                                    addIcon = true
                                case .searchMembers, .searchKicked, .searchAdmins:
                                    section = .none
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = presentationData.strings.Channel_Management_LabelOwner
                                    enabled = false
                                }
                            }
                            
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: [], revealed: false, enabled: enabled), section: section, dateTimeFormat: presentationData.dateTimeFormat, addIcon: addIcon))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.0 {
                        let peer = foundPeer.peer
                        
                        if excludeBots, let user = peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.1 {
                        let peer = foundPeer.peer
                        
                        if excludeBots, let user = peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: presentationData.dateTimeFormat))
                            index += 1
                        }
                    }
                    
                    return entries
                }
            } else {
                return .single(nil)
            }
        }
        
        let previousSearchItems = Atomic<[ChannelMembersSearchEntry]?>(value: nil)
        let previousEmptyQueryItems = Atomic<[ChannelMembersSearchEntry]?>(value: nil)
        
        self.emptyQueryDisposable.set((combineLatest(emptyQueryItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousEmptyQueryItems.swap(entries)
                let firstTime = previousEntries == nil
                let transition = channelMembersSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: "",  context: context, presentationData: presentationData, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, interaction: interaction)
                strongSelf.enqueueEmptyQueryTransition(transition, firstTime: firstTime)
                
                if entries == nil {
                    strongSelf.emptyQueryListNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                } else {
                    strongSelf.emptyQueryListNode.backgroundColor = presentationData.theme.chatList.backgroundColor
                }
            }
        }))

        self.searchDisposable.set((combineLatest(self.searchQuery.get(), foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] query, entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                updateActivity(false)
                let firstTime = previousEntries == nil
                let transition = channelMembersSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: query ?? "", context: context, presentationData: presentationData, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                var presentationData = presentationData
                
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                if let forceTheme = strongSelf.forceTheme {
                    presentationData = presentationData.withUpdated(theme: forceTheme)
                }
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                }
            }
        })
        
        self.emptyQueryListNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.removeMemberDisposable.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.emptyQueryListNode.backgroundColor = theme.chatList.backgroundColor
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override public func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueEmptyQueryTransition(_ transition: ChannelMembersSearchContainerTransition, firstTime: Bool) {
        enqueuedEmptyQueryTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedEmptyQueryTransitions.isEmpty {
                self.dequeueEmptyQueryTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.listNode.isHidden = !isSearching
                strongSelf.emptyQueryListNode.isHidden = isSearching
                                
                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                
                let emptyResults = transition.isSearching && transition.isEmpty
                strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            })
        }
    }
    
    private func dequeueEmptyQueryTransition() {
        if let (transition, firstTime) = self.enqueuedEmptyQueryTransitions.first {
            self.enqueuedEmptyQueryTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            self.emptyQueryListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.emptyQueryListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.emptyQueryListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyTitleY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyTitleY), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyTitleY + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override public func scrollToTop() {
        if self.listNode.isHidden {
            self.emptyQueryListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        } else {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = self.view.hitTest(point, with: event) else {
            return nil
        }
        if result === self.view {
            return nil
        }
        return result
    }
}
