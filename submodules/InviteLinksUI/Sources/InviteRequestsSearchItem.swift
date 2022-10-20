import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ItemListUI
import PresentationDataUtils
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import SearchBarNode
import MergeLists
import ChatListSearchItemHeader
import ItemListUI
import SearchUI
import ContextUI

private let searchBarFont = Font.regular(17.0)

final class SearchNavigationContentNode: NavigationBarContentNode, ItemListControllerSearchNavigationContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    var activity: Bool = false {
        didSet {
            searchBar.activity = activity
        }
    }
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void, updateActivity: @escaping(@escaping(Bool)->Void) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern, displayBackground: false)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        
        updateActivity({ [weak self] value in
            self?.activity = value
        })
        
        self.updatePlaceholder()
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: self.theme), strings: self.strings)
        self.updatePlaceholder()
    }
    
    func updatePlaceholder() {
        self.searchBar.placeholderString = NSAttributedString(string: self.strings.MemberRequests_SearchPlaceholder, font: searchBarFont, textColor: self.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
    }
    
    override var nominalHeight: CGFloat {
        return 56.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 56.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}


final class InviteRequestsSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let peerId: PeerId
    let cancel: () -> Void
    let openPeer: (EnginePeer) -> Void
    let approveRequest: (EnginePeer) -> Void
    let denyRequest: (EnginePeer) -> Void
    let navigateToChat: (EnginePeer) -> Void
    let pushController: (ViewController) -> Void
    let presentInGlobalOverlay: (ViewController) -> Void
    let dismissInput: () -> Void
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, peerId: PeerId, cancel: @escaping () -> Void, openPeer: @escaping (EnginePeer) -> Void, approveRequest: @escaping (EnginePeer) -> Void, denyRequest: @escaping (EnginePeer) -> Void, navigateToChat: @escaping (EnginePeer) -> Void, pushController: @escaping (ViewController) -> Void, dismissInput: @escaping () -> Void, presentInGlobalOverlay: @escaping (ViewController) -> Void) {
        self.context = context
        self.peerId = peerId
        self.cancel = cancel
        self.openPeer = openPeer
        self.approveRequest = approveRequest
        self.denyRequest = denyRequest
        self.navigateToChat = navigateToChat
        self.pushController = pushController
        self.dismissInput = dismissInput
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.activityDisposable.set((activity.get() |> mapToSignal { value -> Signal<Bool, NoError> in
            if value {
                return .single(value) |> delay(0.2, queue: Queue.mainQueue())
            } else {
                return .single(value)
            }
        }).start(next: { [weak self] value in
            self?.updateActivity?(value)
        }))
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? InviteRequestsSearchItem {
            if self.context !== to.context {
                return false
            }
            if self.peerId != to.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? SearchNavigationContentNode {
            current.updateTheme(presentationData.theme)
            return current
        } else {
            return SearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, cancel: self.cancel, updateActivity: { [weak self] value in
                self?.updateActivity = value
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return InviteRequestsSearchItemNode(context: self.context, peerId: self.peerId, openPeer: self.openPeer, approveRequest: self.approveRequest, denyRequest: self.denyRequest, navigateToChat: self.navigateToChat, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        }, pushController: { [weak self] c in
            self?.pushController(c)
        }, dismissInput: self.dismissInput, presentInGlobalOverlay: self.presentInGlobalOverlay)
    }
}

private final class InviteRequestsSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: InviteRequestsSearchContainerNode
    
    init(context: AccountContext, peerId: PeerId, openPeer: @escaping (EnginePeer) -> Void, approveRequest: @escaping (EnginePeer) -> Void, denyRequest: @escaping (EnginePeer) -> Void, navigateToChat: @escaping (EnginePeer) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, pushController: @escaping (ViewController) -> Void, dismissInput: @escaping () -> Void, presentInGlobalOverlay: @escaping (ViewController) -> Void) {
        self.containerNode = InviteRequestsSearchContainerNode(context: context, forceTheme: nil, peerId: peerId, openPeer: { peer in
            openPeer(peer)
        }, approveRequest: { peer in
            approveRequest(peer)
        }, denyRequest: { peer in
            denyRequest(peer)
        }, navigateToChat: { peer in
            navigateToChat(peer)
        }, updateActivity: updateActivity, pushController: pushController, presentInGlobalOverlay: presentInGlobalOverlay)
        self.containerNode.cancel = {
            cancel()
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.dismissInput = {
            dismissInput()
        }
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func scrollToTop() {
        self.containerNode.scrollToTop()
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout.withUpdatedSize(CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)), navigationBarHeight: 0.0, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}


private final class InviteRequestsSearchContainerInteraction {
    let openPeer: (EnginePeer) -> Void
    let approveRequest: (EnginePeer) -> Void
    let denyRequest: (EnginePeer) -> Void
    let peerContextAction: (EnginePeer, ASDisplayNode, ContextGesture?) -> Void
    
    init(openPeer: @escaping (EnginePeer) -> Void, approveRequest: @escaping (EnginePeer) -> Void, denyRequest: @escaping (EnginePeer) -> Void, peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void) {
        self.openPeer = openPeer
        self.approveRequest = approveRequest
        self.denyRequest = denyRequest
        self.peerContextAction = peerContextAction
    }
}

private enum InviteRequestsSearchEntryId: Hashable {
    case placeholder(Int)
    case request(EnginePeer.Id)
}

private final class InviteRequestsSearchEntry: Comparable, Identifiable {
    let index: Int
    let request: PeerInvitationImportersState.Importer?
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let isGroup: Bool
    
    init(index: Int, request: PeerInvitationImportersState.Importer?, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, isGroup: Bool) {
        self.index = index
        self.request = request
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.isGroup = isGroup
    }
    
    var stableId: InviteRequestsSearchEntryId {
        if let request = self.request {
            return .request(request.peer.peerId)
        } else {
            return .placeholder(self.index)
        }
    }
    
    static func ==(lhs: InviteRequestsSearchEntry, rhs: InviteRequestsSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.request == rhs.request && lhs.dateTimeFormat == rhs.dateTimeFormat && lhs.nameDisplayOrder == rhs.nameDisplayOrder && lhs.isGroup == rhs.isGroup
    }
    
    static func <(lhs: InviteRequestsSearchEntry, rhs: InviteRequestsSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: InviteRequestsSearchContainerInteraction) -> ListViewItem {
        return ItemListInviteRequestItem(context: context, presentationData: ItemListPresentationData(presentationData), dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, importer: self.request, isGroup: self.isGroup, sectionId: 0, style: .plain, tapAction: {
            if let peer = self.request?.peer.peer.flatMap({ EnginePeer($0) }) {
                interaction.openPeer(peer)
            }
        }, addAction: {
            if let peer = self.request?.peer.peer.flatMap({ EnginePeer($0) }) {
                interaction.approveRequest(peer)
            }
        }, dismissAction: {
            if let peer = self.request?.peer.peer.flatMap({ EnginePeer($0) }) {
                interaction.denyRequest(peer)
            }
        }, contextAction: { node, gesture in
            if let peer = self.request?.peer.peer.flatMap({ EnginePeer($0) }) {
                interaction.peerContextAction(peer, node, gesture)
            }
        })
    }
}

struct InviteRequestsSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmpty: Bool
    let query: String
}

private func inviteRequestsSearchContainerPreparedRecentTransition(from fromEntries: [InviteRequestsSearchEntry], to toEntries: [InviteRequestsSearchEntry], isSearching: Bool, isEmpty: Bool, query: String, context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: InviteRequestsSearchContainerInteraction) -> InviteRequestsSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return InviteRequestsSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmpty: isEmpty, query: query)
}


public final class InviteRequestsSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let openPeer: (EnginePeer) -> Void
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedTransitions: [(InviteRequestsSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let searchQuery = Promise<String?>()
    private let emptyQueryDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private let forceTheme: PresentationTheme?
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    private let presentationDataPromise: Promise<PresentationData>
    
    private var _hasDim: Bool = false
    override public var hasDim: Bool {
        return _hasDim
    }
    
    private var processedPeerIdsPromise = ValuePromise<Set<PeerId>>(Set())
    private var processedPeerIds = Set<PeerId>() {
        didSet {
            self.processedPeerIdsPromise.set(self.processedPeerIds)
        }
    }
    
    public init(context: AccountContext, forceTheme: PresentationTheme?, peerId: PeerId, openPeer: @escaping (EnginePeer) -> Void, approveRequest: @escaping (EnginePeer) -> Void, denyRequest: @escaping (EnginePeer) -> Void, navigateToChat: @escaping (EnginePeer) -> Void, updateActivity: @escaping (Bool) -> Void, pushController: @escaping (ViewController) -> Void, presentInGlobalOverlay: @escaping (ViewController) -> Void) {
        self.context = context
        self.openPeer = openPeer
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.forceTheme = forceTheme
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
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
                
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self._hasDim = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
    
        let interaction = InviteRequestsSearchContainerInteraction(openPeer: { [weak self] peer in
            openPeer(peer)
            self?.listNode.clearHighlightAnimated(true)
        }, approveRequest: { [weak self] peer in
            approveRequest(peer)
            self?.processedPeerIds.insert(peer.id)
        }, denyRequest: { [weak self] peer in
            denyRequest(peer)
            self?.processedPeerIds.insert(peer.id)
        }, peerContextAction: { [weak self] peer, node, gesture in
            guard let node = node as? ContextExtractedContentContainingNode else {
                return
            }
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let peer = peer else {
                    return
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let addString: String
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    addString = presentationData.strings.MemberRequests_AddToChannel
                } else {
                    addString = presentationData.strings.MemberRequests_AddToGroup
                }
                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: addString, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    approveRequest(peer)
                    self?.processedPeerIds.insert(peer.id)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.ContactList_Context_SendMessage, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    navigateToChat(peer)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.MemberRequests_Dismiss, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    denyRequest(peer)
                    self?.processedPeerIds.insert(peer.id)
                })))
                
                let dismissPromise = ValuePromise<Bool>(false)
                let source = InviteRequestsContextExtractedContentSource(sourceNode: node, keepInPlace: false, blurBackground: true, centerVertically: true, shouldBeDismissed: dismissPromise.get())
        //        sourceNode.requestDismiss = {
        //            dismissPromise.set(true)
        //        }
                
                let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(source), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                presentInGlobalOverlay(contextController)
            })
        })
        
        let presentationDataPromise = self.presentationDataPromise
        
        let previousRequestsContext = Atomic<PeerInvitationImportersContext?>(value: nil)
        
        let processedPeerIds = self.processedPeerIdsPromise
        let searchQuery = self.searchQuery.get()
        |> mapToSignal { query -> Signal<String?, NoError> in
            if let query = query, !query.isEmpty {
                if query.count == 1 {
                    return .single(" ")
                } else {
                    return (.complete() |> delay(0.6, queue: Queue.mainQueue()))
                    |> then(.single(query))
                }
            } else {
                return .single(query)
            }
        }
        
        let foundItems = combineLatest(searchQuery, context.account.postbox.peerView(id: peerId) |> take(1))
        |> mapToSignal { query, peerView -> Signal<[InviteRequestsSearchEntry]?, NoError> in
            guard let query = query, !query.isEmpty, let peer = peerViewMainPeer(peerView) else {
                return .single(nil)
            }
            
            let signal: Signal<PeerInvitationImportersState, NoError>
            if query == " " {
                signal = .single(PeerInvitationImportersState.Loading)
            } else {
                updateActivity(true)
                let requestsContext = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: query))
                let _ = previousRequestsContext.swap(requestsContext)
                signal = requestsContext.state
            }
                                    
            return combineLatest(signal, presentationDataPromise.get(), processedPeerIds.get())
            |> mapToSignal { state, presentationData, processedPeerIds -> Signal<[InviteRequestsSearchEntry]?, NoError> in
                let isGroup: Bool
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    isGroup = false
                } else {
                    isGroup = true
                }
                
                var entries: [InviteRequestsSearchEntry] = []
                var index = 0
                if !state.hasLoadedOnce {
                    for _ in 0 ..< 2 {
                        entries.append(InviteRequestsSearchEntry(index: index, request: nil, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, isGroup: isGroup))
                        index += 1
                    }
                    return .single(entries)
                }
                
                for importer in state.importers {
                    if processedPeerIds.contains(importer.peer.peerId) {
                        continue
                    }
                    entries.append(InviteRequestsSearchEntry(index: index, request: importer, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, isGroup: isGroup))
                    index += 1
                }
                return .single(entries)
            }
        }
        
        let previousSearchItems = Atomic<[InviteRequestsSearchEntry]?>(value: nil)
    
        self.searchDisposable.set((combineLatest(searchQuery, foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] query, entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                updateActivity(false)
                let firstTime = previousEntries == nil
                let transition = inviteRequestsSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: query ?? "", context: context, presentationData: presentationData, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, interaction: interaction)
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
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override public func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: InviteRequestsSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.listNode.isHidden = !isSearching
                strongSelf.dimNode.isHidden = transition.isSearching
                
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
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
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
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
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
