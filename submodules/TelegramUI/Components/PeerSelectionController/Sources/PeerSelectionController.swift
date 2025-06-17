import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import SearchUI
import ChatListUI
import CounterControllerTitleView

public final class PeerSelectionControllerImpl: ViewController, PeerSelectionController {
    private let context: AccountContext
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var customTitle: String?
    
    public var peerSelected: ((EnginePeer, Int64?) -> Void)?
    public var multiplePeersSelected: (([EnginePeer], [EnginePeer.Id: EnginePeer], NSAttributedString, AttachmentTextInputPanelSendMode, ChatInterfaceForwardOptionsState?, ChatSendMessageActionSheetController.SendParameters?) -> Void)?
    private let filter: ChatListNodePeersFilter
    private let forumPeerId: (id: EnginePeer.Id, isMonoforum: Bool)?
    private let selectForumThreads: Bool
    
    private let attemptSelection: ((EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void)?
    private let createNewGroup: (() -> Void)?
    
    public var inProgress: Bool = false {
        didSet {
            if self.inProgress != oldValue {
                if self.isNodeLoaded {
                    self.peerSelectionNode.inProgress = self.inProgress
                }
                
                if self.inProgress {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.controlColor))
                } else {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
        }
    }
    
    public var customDismiss: (() -> Void)?
    
    private var peerSelectionNode: PeerSelectionControllerNode {
        return super.displayNode as! PeerSelectionControllerNode
    }
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let hasChatListSelector: Bool
    private let hasContactSelector: Bool
    private let hasFilters: Bool
    private let hasGlobalSearch: Bool
    private let pretendPresentedInModal: Bool
    private let forwardedMessageIds: [EngineMessage.Id]
    private let hasTypeHeaders: Bool
    private let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    let multipleSelectionLimit: Int32?
    private let hasCreation: Bool
    let immediatelyActivateMultipleSelection: Bool
    
    override public var _presentedInModal: Bool {
        get {
            if self.pretendPresentedInModal {
                return true
            } else {
                return super._presentedInModal
            }
        } set(value) {
            if !self.pretendPresentedInModal {
                super._presentedInModal = value
            }
        }
    }
    
    private(set) var titleView: CounterControllerTitleView?
    private var searchContentNode: NavigationBarSearchContentNode?
    var tabContainerNode: ChatListFilterTabContainerNode?
    private var tabContainerData: ([ChatListFilterTabEntry], Bool, Int32?)?
    
    private let filterDisposable = MetaDisposable()
    
    private var validLayout: ContainerViewLayout?
    
    public init(_ params: PeerSelectionControllerParams) {
        self.context = params.context
        self.filter = params.filter
        self.forumPeerId = params.forumPeerId
        self.hasFilters = params.hasFilters
        self.hasChatListSelector = params.hasChatListSelector
        self.hasContactSelector = params.hasContactSelector
        self.hasGlobalSearch = params.hasGlobalSearch
        self.presentationData = params.updatedPresentationData?.initial ?? params.context.sharedContext.currentPresentationData.with { $0 }
        self.attemptSelection = params.attemptSelection
        self.createNewGroup = params.createNewGroup
        self.pretendPresentedInModal = params.pretendPresentedInModal
        self.forwardedMessageIds = params.forwardedMessageIds
        self.hasTypeHeaders = params.hasTypeHeaders
        self.selectForumThreads = params.selectForumThreads
        self.requestPeerType = params.requestPeerType
        self.hasCreation = params.hasCreation
        self.immediatelyActivateMultipleSelection = params.immediatelyActivateMultipleSelection
        self.multipleSelectionLimit = params.multipleSelectionLimit
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.customTitle = params.title
        
        if let peerTypes = params.requestPeerType {
            if peerTypes.count == 1, let peerType = peerTypes.first {
                switch peerType {
                case let .user(user):
                    if let isBot = user.isBot, isBot {
                        self.customTitle = self.presentationData.strings.RequestPeer_ChooseBotTitle
                    } else {
                        self.customTitle = self.presentationData.strings.RequestPeer_ChooseUserTitle
                    }
                case .group:
                    self.customTitle = self.presentationData.strings.RequestPeer_ChooseGroupTitle
                case .channel:
                    self.customTitle = self.presentationData.strings.RequestPeer_ChooseChannelTitle
                }
            } else {
                self.customTitle = self.presentationData.strings.ChatImport_Title
            }
        }
        
        if let maxCount = params.multipleSelectionLimit {
            self.titleView = CounterControllerTitleView(theme: self.presentationData.theme)
            self.titleView?.title = CounterControllerTitle(title: self.customTitle ?? self.presentationData.strings.Conversation_ForwardTitle, counter: "0/\(maxCount)")
            self.navigationItem.titleView = self.titleView
        } else {
            self.title = self.customTitle ?? self.presentationData.strings.Conversation_ForwardTitle
        }
        
        if params.forumPeerId == nil {
            self.navigationPresentation = .modal
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.peerSelectionNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = ((params.updatedPresentationData?.signal ?? self.context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
        
        if params.immediatelyActivateMultipleSelection {
            Queue.mainQueue().after(0.1) {
                self.beginSelection()
            }
        } else if params.multipleSelection {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Select, style: .plain, target: self, action: #selector(self.beginSelection))
        }
        
        if params.hasFilters {
            self._ready.set(.never())
            
            self.tabContainerNode = ChatListFilterTabContainerNode(context: self.context)
            self.reloadFilters()
            
            self.peerSelectionNode.mainContainerNode?.currentItemFilterUpdated = { [weak self] filter, fraction, transition, force in
                guard let strongSelf = self else {
                    return
                }
                guard let layout = strongSelf.validLayout else {
                    return
                }
                guard let tabContainerData = strongSelf.tabContainerData else {
                    return
                }
                if force {
                    strongSelf.tabContainerNode?.cancelAnimations()
                }
                strongSelf.tabContainerNode?.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: tabContainerData.0, selectedFilter: filter, isReordering: false, isEditing: false, canReorderAllChats: false, filtersLimit: tabContainerData.2, transitionFraction: fraction, presentationData: strongSelf.presentationData, transition: transition)
            }
            
            self.tabContainerNode?.tabSelected = { [weak self] id, isDisabled in
                guard let strongSelf = self else {
                    return
                }
                if isDisabled {
                    let context = strongSelf.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = context.sharedContext.makePremiumLimitController(context: context, subject: .folders, count: strongSelf.tabContainerNode?.filtersCount ?? 0, forceDark: false, cancel: {}, action: {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .folders, forceDark: false, dismissed: nil)
                        replaceImpl?(controller)
                        return true
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    strongSelf.push(controller)
                } else {
                    strongSelf.selectTab(id: id)
                }
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.filterDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = self.customTitle ?? self.presentationData.strings.Conversation_ForwardTitle
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.peerSelectionNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerSelectionControllerNode(context: self.context, controller: self, presentationData: self.presentationData, filter: self.filter, forumPeerId: self.forumPeerId, hasFilters: self.hasFilters, hasChatListSelector: self.hasChatListSelector, hasContactSelector: self.hasContactSelector, hasGlobalSearch: self.hasGlobalSearch, forwardedMessageIds: self.forwardedMessageIds, hasTypeHeaders: self.hasTypeHeaders, requestPeerType: self.requestPeerType, hasCreation: self.hasCreation, createNewGroup: self.createNewGroup, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, presentInGlobalOverlay: { [weak self] c, a in
            self?.presentInGlobalOverlay(c, with: a)
        }, dismiss: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        
        self.peerSelectionNode.navigationBar = self.navigationBar
        
        self.peerSelectionNode.requestSend = { [weak self] peers, peerMap, text, mode, forwardOptionsState, messageEffect in
            self?.multiplePeersSelected?(peers, peerMap, text, mode, forwardOptionsState, messageEffect)
        }
        
        self.peerSelectionNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.peerSelectionNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.peerSelectionNode.requestOpenPeer = { [weak self] peer, threadId in
            guard let self else {
                return
            }
            guard let peerSelected = self.peerSelected else {
                return
            }
            
            if case let .channel(peer) = peer, peer.isForumOrMonoForum, threadId == nil, self.selectForumThreads {
                let mainPeer: Signal<EnginePeer?, NoError>
                if peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId {
                    mainPeer = self.context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)
                    )
                } else {
                    mainPeer = .single(nil)
                }
                
                let _ = (mainPeer |> deliverOnMainQueue).startStandalone(next: { [weak self] mainPeer in
                    guard let self else {
                        return
                    }
                    guard case let .channel(mainChannel) = mainPeer else {
                        return
                    }
                    
                    if mainChannel.hasPermission(.manageDirect) {
                        let displayPeer = EnginePeer(mainChannel)
                        
                        let controller = PeerSelectionControllerImpl(
                            PeerSelectionControllerParams(
                                context: self.context,
                                updatedPresentationData: nil,
                                filter: self.filter,
                                forumPeerId: (peer.id, peer.isMonoForum),
                                hasFilters: false,
                                hasChatListSelector: false,
                                hasContactSelector: false,
                                hasGlobalSearch: false,
                                title: displayPeer.compactDisplayTitle,
                                attemptSelection: self.attemptSelection,
                                createNewGroup: nil,
                                pretendPresentedInModal: false,
                                multipleSelection: false,
                                forwardedMessageIds: [],
                                hasTypeHeaders: false,
                                selectForumThreads: false
                            )
                        )
                        controller.peerSelected = self.peerSelected
                        self.push(controller)
                    } else {
                        peerSelected(.channel(peer), threadId)
                    }
                })
            } else {
                peerSelected(peer, threadId)
            }
        }
        
        self.peerSelectionNode.requestOpenDisabledPeer = { [weak self] peer, threadId, reason in
            if let strongSelf = self {
                strongSelf.attemptSelection?(peer, threadId, reason)
            }
        }
        
        self.peerSelectionNode.requestOpenPeerFromSearch = { [weak self] peer, threadId in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((_internal_storedMessageFromSearchPeer(postbox: strongSelf.context.account.postbox, peer: peer._asPeer())
                |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf, let peerSelected = strongSelf.peerSelected {
                        if case let .channel(peer) = peer, peer.isForumOrMonoForum, threadId == nil, strongSelf.selectForumThreads {
                            let controller = PeerSelectionControllerImpl(
                                PeerSelectionControllerParams(
                                    context: strongSelf.context,
                                    updatedPresentationData: nil,
                                    filter: strongSelf.filter,
                                    forumPeerId: (peer.id, peer.isMonoForum),
                                    hasFilters: false,
                                    hasChatListSelector: false,
                                    hasContactSelector: false,
                                    hasGlobalSearch: false,
                                    title: EnginePeer(peer).compactDisplayTitle,
                                    attemptSelection: strongSelf.attemptSelection,
                                    createNewGroup: nil,
                                    pretendPresentedInModal: false,
                                    multipleSelection: false,
                                    forwardedMessageIds: [],
                                    hasTypeHeaders: false,
                                    selectForumThreads: false
                                )
                            )
                            controller.peerSelected = strongSelf.peerSelected
                            strongSelf.push(controller)
                        } else {
                            peerSelected(peer, threadId)
                        }
                    }
                }))
            }
        }
        
        var isProcessingContentOffsetChanged = false
        self.peerSelectionNode.contentOffsetChanged = { [weak self] offset in
            if isProcessingContentOffsetChanged {
                return
            }
            isProcessingContentOffsetChanged = true
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
                isProcessingContentOffsetChanged = false
            }
        }
        
        self.peerSelectionNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        self.displayNodeDidLoad()
        
        if !self.hasFilters {
            self._ready.set(self.peerSelectionNode.ready)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.peerSelectionNode.mainContainerNode?.updateEnableAdjacentFilterLoading(true)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.peerSelectionNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if let tabContainerNode = self.tabContainerNode, let mainContainerNode = self.peerSelectionNode.mainContainerNode {
            let tabContainerOffset: CGFloat = 0.0
            let navigationBarHeight = self.navigationBar?.frame.maxY ?? 0.0
            transition.updateFrame(node: tabContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight - self.additionalNavigationBarHeight - 46.0 + tabContainerOffset), size: CGSize(width: layout.size.width, height: 46.0)))
            tabContainerNode.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: self.tabContainerData?.0 ?? [], selectedFilter: mainContainerNode.currentItemFilter, isReordering: false, isEditing: false, canReorderAllChats: false, filtersLimit: self.tabContainerData?.2, transitionFraction: mainContainerNode.transitionFraction, presentationData: self.presentationData, transition: .animated(duration: 0.4, curve: .spring))
        }
    }
    
    @objc private func beginSelection() {
        self.navigationItem.rightBarButtonItem = nil
        self.peerSelectionNode.beginSelection()
    }
    
    @objc func cancelPressed() {
        if let customDismiss = self.customDismiss {
            customDismiss()
        } else {
            self.dismiss()
        }
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.peerSelectionNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            if let searchContentNode = self.searchContentNode {
                self.peerSelectionNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
    
    private var initializedFilters = false
    private func reloadFilters(firstUpdate: (() -> Void)? = nil) {
        let filterItems = chatListFilterItems(context: self.context)
        var notifiedFirstUpdate = false
        self.filterDisposable.set((combineLatest(queue: .mainQueue(),
            filterItems,
            self.context.account.postbox.peerView(id: self.context.account.peerId),
            self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false))
        )
        |> deliverOnMainQueue).start(next: { [weak self] countAndFilterItems, peerView, limits in
            guard let strongSelf = self else {
                return
            }
            
            let isPremium = peerView.peers[peerView.peerId]?.isPremium
            
            let (_, items) = countAndFilterItems
            var filterItems: [ChatListFilterTabEntry] = []
            
            for (filter, unreadCount, hasUnmutedUnread) in items {
                switch filter {
                    case .allChats:
                        if let isPremium = isPremium, !isPremium && filterItems.count > 0 {
                            filterItems.insert(.all(unreadCount: 0), at: 0)
                        } else {
                            filterItems.append(.all(unreadCount: 0))
                        }
                    case let .filter(id, title, _, _):
                        filterItems.append(.filter(id: id, text: title, unread: ChatListFilterTabEntryUnreadCount(value: unreadCount, hasUnmuted: hasUnmutedUnread)))
                }
            }
            
            let resolvedItems = filterItems
        
            var wasEmpty = false
            if let tabContainerData = strongSelf.tabContainerData {
                wasEmpty = tabContainerData.0.count <= 1 || tabContainerData.1
            } else {
                wasEmpty = true
            }
   
            var selectedEntryId = !strongSelf.initializedFilters ? .all : (strongSelf.peerSelectionNode.mainContainerNode?.currentItemFilter ?? .all)
            var resetCurrentEntry = false
            if !resolvedItems.contains(where: { $0.id == selectedEntryId }) {
                resetCurrentEntry = true
                if let tabContainerData = strongSelf.tabContainerData {
                    var found = false
                    if let index = tabContainerData.0.firstIndex(where: { $0.id == selectedEntryId }) {
                        for i in (0 ..< index - 1).reversed() {
                            if resolvedItems.contains(where: { $0.id == tabContainerData.0[i].id }) {
                                selectedEntryId = tabContainerData.0[i].id
                                found = true
                                break
                            }
                        }
                    }
                    if !found {
                        selectedEntryId = .all
                    }
                } else {
                    selectedEntryId = .all
                }
            }
            let filtersLimit = isPremium == false ? limits.maxFoldersCount : nil
            strongSelf.tabContainerData = (resolvedItems, false, filtersLimit)
            var availableFilters: [ChatListContainerNodeFilter] = []
            var hasAllChats = false
            for item in items {
                switch item.0 {
                    case .allChats:
                        hasAllChats = true
                        if let isPremium = isPremium, !isPremium && availableFilters.count > 0 {
                            availableFilters.insert(.all, at: 0)
                        } else {
                            availableFilters.append(.all)
                        }
                    case .filter:
                        availableFilters.append(.filter(item.0))
                }
            }
            if !hasAllChats {
                availableFilters.insert(.all, at: 0)
            }
            strongSelf.peerSelectionNode.mainContainerNode?.updateAvailableFilters(availableFilters, limit: filtersLimit)
            
            if let mainContainerNode = strongSelf.peerSelectionNode.mainContainerNode {
                if isPremium == nil && items.isEmpty {
                    strongSelf.ready.set(mainContainerNode.currentItemNode.ready)
                } else if !strongSelf.initializedFilters {
                    if selectedEntryId != mainContainerNode.currentItemFilter {
                        mainContainerNode.switchToFilter(id: selectedEntryId, animated: false, completion: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.ready.set(mainContainerNode.currentItemNode.ready)
                            }
                        })
                    } else {
                        strongSelf.ready.set(mainContainerNode.currentItemNode.ready)
                    }
                    strongSelf.initializedFilters = true
                }
            }
            
            let isEmpty = resolvedItems.count <= 1
            
            if wasEmpty != isEmpty, strongSelf.displayNavigationBar {
                strongSelf.navigationBar?.setSecondaryContentNode(isEmpty ? nil : strongSelf.tabContainerNode, animated: false)
            }
            
            if let layout = strongSelf.validLayout {
                if wasEmpty != isEmpty {
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                } else {
                    strongSelf.tabContainerNode?.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: resolvedItems, selectedFilter: selectedEntryId, isReordering: false, isEditing: false, canReorderAllChats: false, filtersLimit: filtersLimit, transitionFraction: 0.0, presentationData: strongSelf.presentationData, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            if !notifiedFirstUpdate {
                notifiedFirstUpdate = true
                firstUpdate?()
            }
            
            if resetCurrentEntry {
                //strongSelf.selectTab(id: selectedEntryId)
            }
        }))
    }
    
    private func selectTab(id: ChatListFilterTabEntryId) {
        let _ = (self.context.engine.peers.currentChatListFilters()
        |> deliverOnMainQueue).start(next: { [weak self] filters in
            guard let strongSelf = self else {
                return
            }
            let updatedFilter: ChatListFilter?
            switch id {
            case .all:
                updatedFilter = nil
            case let .filter(id):
                var found = false
                var foundValue: ChatListFilter?
                for filter in filters {
                    if filter.id == id {
                        foundValue = filter
                        found = true
                        break
                    }
                }
                if found {
                    updatedFilter = foundValue
                } else {
                    updatedFilter = nil
                }
            }
            if strongSelf.peerSelectionNode.mainContainerNode?.currentItemNode.chatListFilter?.id == updatedFilter?.id {
                strongSelf.scrollToTop?()
            } else {
                strongSelf.peerSelectionNode.mainContainerNode?.switchToFilter(id: updatedFilter.flatMap { .filter($0.id) } ?? .all)
            }
        })
    }
}
