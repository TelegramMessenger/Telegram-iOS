import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import MergeLists
import SearchBarNode
import SearchUI
import ContactListUI
import ContactsPeerItem
import ItemListUI
import ChatListSearchItemHeader
import PresentationDataUtils

class ChannelParticipantsInteraction {
    let addMember: () -> Void
    let openPeer: (PeerId) -> Void
    
    init(addMember: @escaping () -> Void, openPeer: @escaping (PeerId) -> Void) {
        self.addMember = addMember
        self.openPeer = openPeer
    }
}

private struct ChannelParticipantsTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isLoading: Bool
    let isEmpty: Bool
    let crossFade: Bool
}

private enum ChannelParticipantsEntryId: Hashable {
    case action(Int)
    case peer(PeerId)
}

private enum ChannelParticipantsEntry: Comparable, Identifiable {
    case action(Int, PresentationTheme, ContactListAdditionalOption)
    case peer(Int, PresentationTheme, PresentationStrings, RenderedChannelParticipant, ListViewItemHeader?, Bool)
    
    var stableId: ChannelParticipantsEntryId {
        switch self {
            case let .action(index, _, _):
                return .action(index)
            case let .peer(_, _ , _, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelParticipantsEntry, rhs: ChannelParticipantsEntry) -> Bool {
        switch lhs {
            case let .action(lhsIndex, lhsTheme, lhsOption):
                if case let .action(rhsIndex, rhsTheme, rhsOption) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsOption == rhsOption {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsTheme, lhsStrings, lhsParticipant, lhsHeader, lhsExpanded):
                if case let .peer(rhsIndex, rhsTheme, rhsStrings, rhsParticipant, rhsHeader, rhsExpanded) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsParticipant == rhsParticipant, lhsHeader?.id == rhsHeader?.id, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelParticipantsEntry, rhs: ChannelParticipantsEntry) -> Bool {
        switch lhs {
            case let .action(lhsIndex, _, _):
                switch rhs {
                    case let .action(rhsIndex, _, _):
                        return lhsIndex < rhsIndex
                    case .peer:
                        return true
                }
            case let .peer(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .action:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: ChannelParticipantsInteraction?) -> ListViewItem {
        switch self {
            case let .action(_, _, option):
                return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: option.title, icon: option.icon, clearHighlightAutomatically: false, header: nil, action: option.action)
            case let .peer(_, theme, strings, participant, header, expanded):
                var status: String
                if case let .member(_, invitedAt, _, _, _) = participant.participant {
                    status = "joined \(stringForFullDate(timestamp: invitedAt, strings: strings, dateTimeFormat: presentationData.dateTimeFormat))"
                } else {
                    status = "owner"
                }
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: participant.peer, chatPeer: nil), status: .custom(string: status, multiline: false), enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction?.openPeer(participant.peer.id)
                }, itemHighlighting: ContactItemHighlighting(), contextAction: nil)
        }
    }
}

private func preparedTransaction(from fromEntries: [ChannelParticipantsEntry], to toEntries: [ChannelParticipantsEntry], isLoading: Bool, isEmpty: Bool, crossFade: Bool, context: AccountContext, presentationData: PresentationData, interaction: ChannelParticipantsInteraction?) -> ChannelParticipantsTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return ChannelParticipantsTransaction(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, isEmpty: isEmpty, crossFade: crossFade)
}

private struct ChannelParticipantsState {
    var editing: Bool
    
    init() {
        self.editing = false
    }
}


private class ChannelParticipantsScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let peerId: PeerId
    private var presentationData: PresentationData
    private var presentationDataPromise: Promise<PresentationData>
    private let membersContext: PeerInfoMembersContext
    private var interaction: ChannelParticipantsInteraction?
    
    private let listNode: ListView
    
    var navigationBar: NavigationBar?
    private var searchDisplayController: SearchDisplayController?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestAddMember: (() -> Void)?
    var requestOpenPeer: ((PeerId) -> Void)?
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    
    private var disposable: Disposable?
    private var state: ChannelParticipantsState
    private let statePromise: Promise<ChannelParticipantsState>
    
    private var currentEntries: [ChannelParticipantsEntry] = []
    private var enqueuedTransactions: [ChannelParticipantsTransaction] = []
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(presentationData)
        self.membersContext = PeerInfoMembersContext(context: context, peerId: peerId)
                
        self.state = ChannelParticipantsState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
                
        super.init()
        
        self.interaction = ChannelParticipantsInteraction(addMember: { [weak self] in
            self?.requestAddMember?()
        }, openPeer: { [weak self] peerId in
            self?.requestOpenPeer?(peerId)
        })
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.listNode)
                
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), self.membersContext.state, context.account.postbox.combinedView(keys: [.basicPeer(peerId)]))
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, members, combinedView in
            guard let strongSelf = self, let basicPeerView = combinedView.views[.basicPeer(peerId)] as? BasicPeerView, let enclosingPeer = basicPeerView.peer else {
                return
            }
            
            strongSelf.updateState(enclosingPeer: enclosingPeer, members: members, presentationData: presentationData)
        })
    }
    
    private func updateState(enclosingPeer: Peer, members: PeerInfoMembersState, presentationData: PresentationData) {
        var entries: [ChannelParticipantsEntry] = []
        
        entries.append(.action(0, presentationData.theme, ContactListAdditionalOption(title: "Add Subscribers", icon: .generic(UIImage(bundleImageName: "Contact List/AddMemberIcon")!), action: { [weak self] in
//            self?.interaction?
        })))
        
        let contacts = ChatListSearchItemHeader(type: .contacts, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
        let otherSubscribers = ChatListSearchItemHeader(type: .otherSubscribers, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                    
        var known: [RenderedChannelParticipant] = []
        var other: [RenderedChannelParticipant] = []
        
//        Ilya Laktyushin 572439
//        Nikolay Kudashov 552564
//        Alexander Stepanov 215491
//        Michael Filimonov 438078
//        Peter Iakovlev 903523
//        Вася Бабич 763171
//        Denis Prokopov 949693
//        **Dmitrybot** 230212
//        Dmitry Moskovsky 659864346
//        Nick Kudashov jjrjrtest 76745538
//        В 102439374
//        Michael Filimonov 264037907
//        example 3735744
//        California Kai ☀️ 12549969
//        Pushtest 640083077
        
        let unknown: Set<Int64> = Set([102439374, 76745538, 264037907, 3735744, 12549969, 640083077])
        
        for member in members.members {
            if case let .channelMember(participant) = member {
                if case .member = participant.participant {
                    if unknown.contains(participant.peer.id.toInt64()) {
                        other.append(participant)
                    } else {
                        known.append(participant)
                    }
//                    entries.append(.peer(entries.count, presentationData.theme, presentationData.strings, participant, nil, false))
//                    print(participant.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) + " " + "\(participant.peer.id.toInt64())")
                }
            }
        }
        
        for participant in known.sorted(by: { lhs, rhs in
            if case let .member(_, lhsInvitedAt, _, _, _) = lhs.participant, case let .member(_, rhsInvitedAt, _, _, _) = rhs.participant {
                return lhsInvitedAt > rhsInvitedAt
            } else {
                return false
            }
        }) {
            entries.append(.peer(entries.count, presentationData.theme, presentationData.strings, participant, contacts, false))
        }
        
        for participant in other.sorted(by: { lhs, rhs in
            if case let .member(_, lhsInvitedAt, _, _, _) = lhs.participant, case let .member(_, rhsInvitedAt, _, _, _) = rhs.participant {
                return lhsInvitedAt > rhsInvitedAt
            } else {
                return false
            }
            
        }) {
            entries.append(.peer(entries.count, presentationData.theme, presentationData.strings, participant, otherSubscribers, false))
        }
        
        
        let transaction = preparedTransaction(from: self.currentEntries, to: entries, isLoading: false, isEmpty: false, crossFade: false, context: self.context, presentationData: presentationData, interaction: self.interaction)
//        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, enclosingPeer: enclosingPeer, action: { [weak self] member, action in
////            self?.action(member, action)
//        })
//        self.enclosingPeer = enclosingPeer
            self.currentEntries = entries
            self.enqueueTransaction(transaction)
       }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight, _) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
//        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChatListSearchContainerNode(context: self.context, filter: self.filter, groupId: .root, openPeer: { [weak self] peer, _ in
//            if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
//                requestOpenPeerFromSearch(peer)
//            }
//            }, openDisabledPeer: { [weak self] peer in
//                self?.requestOpenDisabledPeer?(peer)
//            }, openRecentPeerOptions: { _ in
//        }, openMessage: { [weak self] peer, messageId in
//            if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
//                requestOpenMessageFromSearch(peer, messageId)
//            }
//            }, addContact: nil, peerContextAction: nil, present: { _ in
//        }), cancel: { [weak self] in
//            if let requestDeactivateSearch = self?.requestDeactivateSearch {
//                requestDeactivateSearch()
//            }
//        })
//
//        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
//        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
//            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
//                if isSearchBar {
//                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
//                } else {
//                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
//                }
//            }
//        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    func scrollToTop() {
        
    }
    
    private func enqueueTransaction(_ transaction: ChannelParticipantsTransaction) {
        self.enqueuedTransactions.append(transaction)
        
        if let _ = self.containerLayout {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
    
    private func dequeueTransaction() {
        guard let layout = self.containerLayout, let transition = self.enqueuedTransactions.first else {
            return
        }
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transition.crossFade {
            options.insert(.AnimateCrossfade)
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                //                strongSelf.activityIndicator.isHidden = !transition.isLoading
                //                strongSelf.emptyResultsTextNode.isHidden = transition.isLoading || !transition.isEmpty
                //
                //                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.Map_NoPlacesNearby, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                //
                //                strongSelf.layoutActivityIndicator(transition: .immediate)
            }
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        if isFirstLayout {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
}

public class ChannelParticipantsScreen: ViewController {
    private let context: AccountContext
    private let peerId: PeerId
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var controllerNode: ChannelParticipantsScreenNode {
        return self.displayNode as! ChannelParticipantsScreenNode
    }
    
    let addMembersDisposable = MetaDisposable()
            
//    private let _ready = Promise<Bool>()
//    override public var ready: Promise<Bool> {
//        return self._ready
//    }
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    public init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
               
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = "Subscribers"
    
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.controllerNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
//                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.addMembersDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChannelParticipantsScreenNode(context: self.context, peerId: self.peerId)
        
        self.controllerNode.navigationBar = self.navigationBar
        
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.controllerNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.controllerNode.requestAddMember = { [weak self] in
            guard let strongSelf = self else {
                return
            }
//            let disabledIds = members?.compactMap({$0.peer.id}) ?? []
            
            let context = strongSelf.context
            let peerId = strongSelf.peerId
            let presentationData = strongSelf.presentationData
            
            let contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: [], filters: [.excludeSelf, .disable([])]))
            contactsController.navigationPresentation = .modal
            
            strongSelf.addMembersDisposable.set((contactsController.result
            |> deliverOnMainQueue
            |> castError(AddChannelMemberError.self)
            |> mapToSignal { [weak contactsController] result -> Signal<Never, AddChannelMemberError> in
                contactsController?.displayProgress = true
                
                var contacts: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    contacts = peerIdsValue
                }
                
                let signal = context.peerChannelMemberCategoriesContextsManager.addMembers(account: context.account, peerId: peerId, memberIds: contacts.compactMap({ contact -> PeerId? in
                    switch contact {
                        case let .peer(contactId):
                            return contactId
                        default:
                            return nil
                    }
                }))
                
                return signal
                |> ignoreValues
                |> deliverOnMainQueue
                |> afterCompleted {
                    contactsController?.dismiss()
                }
            }).start(error: { [weak self, weak contactsController] error in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Channel_ErrorAddTooMuch
                    case .tooMuchJoined:
                        text = presentationData.strings.Invite_ChannelsTooMuch
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                    case .restricted:
                        text = presentationData.strings.Channel_ErrorAddBlocked
                    case .notMutualContact:
                        text = presentationData.strings.GroupInfo_AddUserLeftError
                    case let .bot(memberId):
                        let _ = (context.account.postbox.transaction { transaction in
                            return transaction.getPeer(peerId)
                        }
                        |> deliverOnMainQueue).start(next: { peer in
                            guard let peer = peer as? TelegramChannel else {
                                self?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                contactsController?.dismiss()
                                
                                return
                            }
                            
                            if peer.hasPermission(.addAdmins) {
                                contactsController?.displayProgress = false
                                self?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Channel_AddBotAsAdmin, action: {
                                    contactsController?.dismiss()
                                    
//                                    pushControllerImpl?(channelAdminController(context: context, peerId: peerId, adminId: memberId, initialParticipant: nil, updated: { _ in
//                                    }, upgradedToSupergroup: { _, f in f () }, transferedOwnership: { _ in }))
                                })]), in: .window(.root))
                            } else {
                                self?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                            
                            contactsController?.dismiss()
                        })
                        return
                    case .botDoesntSupportGroups:
                        text = presentationData.strings.Channel_BotDoesntSupportGroups
                    case .tooMuchBots:
                        text = presentationData.strings.Channel_TooMuchBots
                }
                self?.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                contactsController?.dismiss()
            }))
            
            strongSelf.push(contactsController)
        }
        
        self.controllerNode.requestOpenPeer = { [weak self] peerId in
//            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
//                peerSelected(peerId)
//            }
        }
        
        var isProcessingContentOffsetChanged = false
        self.controllerNode.contentOffsetChanged = { [weak self] offset in
            if isProcessingContentOffsetChanged {
                return
            }
            isProcessingContentOffsetChanged = true
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
                isProcessingContentOffsetChanged = false
            }
        }
        
        self.controllerNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        self.displayNodeDidLoad()
        
//        self._ready.set(self.controllerNode.ready)
    }
    
    private func updatePresentationData() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, actualNavigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
}
