import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramBaseController
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import UndoUI
import TelegramNotices
import SearchUI
import DeleteChatPeerActionSheetItem
import LanguageSuggestionUI
import ContextUI
import AppBundle
import LocalizedPeerData
import TelegramIntents
import TooltipUI
import TelegramCallsUI
import StickerResources
import PasswordSetupUI
import FetchManagerImpl
import ComponentFlow
import LottieAnimationComponent
import ProgressIndicatorComponent
import PremiumUI
import ConfettiEffect
import AnimationCache
import MultiAnimationRenderer
import EmojiStatusSelectionComponent
import EntityKeyboard
import TelegramStringFormatting
import ForumCreateTopicScreen
import AnimationUI
import ChatTitleView
import PeerInfoUI
import ComponentDisplayAdapters
import ChatListHeaderComponent
import ChatListTitleView

private func fixListNodeScrolling(_ listNode: ListView, searchNode: NavigationBarSearchContentNode) -> Bool {
    if listNode.scroller.isDragging {
        return false
    }
    if searchNode.expansionProgress > 0.0 && searchNode.expansionProgress < 1.0 {
        let offset: CGFloat
        if searchNode.expansionProgress < 0.6 {
            offset = navigationBarSearchContentHeight
        } else {
            offset = 0.0
        }
        let _ = listNode.scrollToOffsetFromTop(offset, animated: true)
        return true
    } else if searchNode.expansionProgress == 1.0 {
        var sortItemNode: ListViewItemNode?
        var nextItemNode: ListViewItemNode?
        
        listNode.forEachItemNode({ itemNode in
            if sortItemNode == nil, let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item, case .groupReference = item.content {
                sortItemNode = itemNode
            } else if sortItemNode != nil && nextItemNode == nil {
                nextItemNode = itemNode as? ListViewItemNode
            }
        })
        
        if false, let sortItemNode = sortItemNode {
            let itemFrame = sortItemNode.apparentFrame
            if itemFrame.contains(CGPoint(x: 0.0, y: listNode.insets.top)) {
                var scrollToItem: ListViewScrollToItem?
                if itemFrame.minY + itemFrame.height * 0.6 < listNode.insets.top {
                    scrollToItem = ListViewScrollToItem(index: 0, position: .top(-76.0), animated: true, curve: .Default(duration: 0.3), directionHint: .Up)
                } else {
                    scrollToItem = ListViewScrollToItem(index: 0, position: .top(0), animated: true, curve: .Default(duration: 0.3), directionHint: .Up)
                }
                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions(), scrollToItem: scrollToItem, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                return true
            }
        }
    }
    return false
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController?
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, navigationController: NavigationController?) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.navigationController = navigationController
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

public class ChatListControllerImpl: TelegramBaseController, ChatListController {
    private var validLayout: ContainerViewLayout?
    
    public let context: AccountContext
    private let controlsHistoryPreload: Bool
    private let hideNetworkActivityStatus: Bool
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    public let location: ChatListControllerLocation
    public let previewing: Bool
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let headerContentView = ComponentView<Empty>()
    
    fileprivate private(set) var primaryContext: ChatListLocationContext?
    private let primaryInfoReady = Promise<Bool>()
    
    private var pendingSecondaryContext: ChatListLocationContext?
    fileprivate private(set) var secondaryContext: ChatListLocationContext?
    
    fileprivate var effectiveContext: ChatListLocationContext? {
        return self.secondaryContext ?? self.primaryContext
    }
    
    public var effectiveLocation: ChatListControllerLocation {
        return self.secondaryContext?.location ?? self.location
    }
    
    private var badgeDisposable: Disposable?
    private var badgeIconDisposable: Disposable?
    
    private var didAppear = false
    private var dismissSearchOnDisappear = false
        
    private var passcodeLockTooltipDisposable = MetaDisposable()
    private var didShowPasscodeLockTooltipController = false
    
    private var suggestLocalizationDisposable = MetaDisposable()
    private var didSuggestLocalization = false
    
    private let suggestAutoarchiveDisposable = MetaDisposable()
    private let dismissAutoarchiveDisposable = MetaDisposable()
    private var didSuggestAutoarchive = false
    
    private var presentationData: PresentationData
    private let presentationDataValue = Promise<PresentationData>()
    private var presentationDataDisposable: Disposable?
    
    private let stateDisposable = MetaDisposable()
    private let filterDisposable = MetaDisposable()
    private let featuredFiltersDisposable = MetaDisposable()
    private var processedFeaturedFilters = false
    
    private let isReorderingTabsValue = ValuePromise<Bool>(false)
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private let tabContainerNode: ChatListFilterTabContainerNode
    private var tabContainerData: ([ChatListFilterTabEntry], Bool, Int32?)?
    
    private var hasDownloads: Bool = false
    private var activeDownloadsDisposable: Disposable?
    private var clearUnseenDownloadsTimer: SwiftSignalKit.Timer?
    
    private var isPremium: Bool = false
    
    private var didSetupTabs = false
    
    private weak var emojiStatusSelectionController: ViewController?
    
    private var forumChannelTracker: ForumChannelTopics?
    
    private let selectAddMemberDisposable = MetaDisposable()
    private let addMemberDisposable = MetaDisposable()
    private let joinForumDisposable = MetaDisposable()
    private let actionDisposables = DisposableSet()
    
    private var plainTitle: String = ""
    
    public override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isNodeLoaded {
            self.chatListDisplayNode.effectiveContainerNode.updateSelectedChatLocation(data: data as? ChatLocation, progress: progress, transition: transition)
        }
    }
    
    public init(context: AccountContext, location: ChatListControllerLocation, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool = false, previewing: Bool = false, enableDebugActions: Bool) {
        self.context = context
        self.controlsHistoryPreload = controlsHistoryPreload
        self.hideNetworkActivityStatus = hideNetworkActivityStatus
        
        self.location = location
        self.previewing = previewing
        
        self.presentationData = (context.sharedContext.currentPresentationData.with { $0 })
        self.presentationDataValue.set(.single(self.presentationData))
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        let groupCallPanelSource: GroupCallPanelSource
        switch self.location {
        case .chatList:
            groupCallPanelSource = .all
        case let .forum(peerId):
            groupCallPanelSource = .peer(peerId)
        }
        
        self.tabContainerNode = ChatListFilterTabContainerNode()
                
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .always, locationBroadcastPanelSource: .summary, groupCallPanelSource: groupCallPanelSource)
        
        self.tabBarItemContextActionType = .always
        self.automaticallyControlPresentationContextLayout = false
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let title: String
        switch self.location {
        case let .chatList(groupId):
            if groupId == .root {
                title = self.presentationData.strings.DialogList_Title
            } else {
                title = self.presentationData.strings.ChatList_ArchivedChatsTitle
            }
            self.plainTitle = title
        case let .forum(peerId):
            title = ""
            self.forumChannelTracker = ForumChannelTopics(account: self.context.account, peerId: peerId)
        }
        
        let primaryContext = ChatListLocationContext(
            context: context,
            location: self.location,
            parentController: self,
            hideNetworkActivityStatus: self.hideNetworkActivityStatus,
            containerNode: self.chatListDisplayNode.mainContainerNode,
            isReorderingTabs: self.isReorderingTabsValue.get()
        )
        self.primaryContext = primaryContext
        self.primaryInfoReady.set(primaryContext.ready.get())
        
        if !previewing {
            switch self.location {
            case let .chatList(groupId):
                if groupId == .root {
                    self.tabBarItem.title = self.presentationData.strings.DialogList_Title
                    
                    let icon: UIImage?
                    if useSpecialTabBarIcons() {
                        icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconChats")
                    } else {
                        icon = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
                    }
                    
                    self.tabBarItem.image = icon
                    self.tabBarItem.selectedImage = icon
                    if !self.presentationData.reduceMotion {
                        self.tabBarItem.animationName = "TabChats"
                        self.tabBarItem.animationOffset = CGPoint(x: 0.0, y: UIScreenPixel)
                    }
                    
                    self.primaryContext?.leftButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                        content: .text(title: self.presentationData.strings.Common_Edit, isBold: false),
                        pressed: { [weak self] _ in
                            self?.editPressed()
                        }
                    )))
                    
                    self.primaryContext?.rightButton = AnyComponentWithIdentity(id: "compose", component: AnyComponent(NavigationButtonComponent(
                        content: .icon(imageName: "Chat List/ComposeIcon"),
                        pressed: { [weak self] _ in
                            self?.composePressed()
                        }
                    )))
                    
                    //let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
                    //backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
                    //self.navigationItem.backBarButtonItem = backBarButtonItem
                } else {
                    switch self.location {
                    case .chatList:
                        self.primaryContext?.rightButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                            content: .text(title: self.presentationData.strings.Common_Edit, isBold: false),
                            pressed: { [weak self] _ in
                                self?.editPressed()
                            }
                        )))
                    case .forum:
                        break
                    }
                    
                    let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
                    backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
                    self.navigationItem.backBarButtonItem = backBarButtonItem
                }
            case .forum:
                break
            }
        }
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.chatListDisplayNode.scrollToTop()
            }
        }
        self.scrollToTopWithTabBar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListDisplayNode.searchDisplayController != nil {
                strongSelf.deactivateSearch(animated: true)
            } else {
                switch strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.visibleContentOffset() {
                case .none, .unknown:
                    if let searchContentNode = strongSelf.searchContentNode {
                        searchContentNode.updateExpansionProgress(1.0, animated: true)
                    }
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.scrollToPosition(.top)
                case let .known(offset):
                    let isFirstFilter = strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.chatListFilter == strongSelf.chatListDisplayNode.mainContainerNode.availableFilters.first?.filter
                    
                    if offset <= navigationBarSearchContentHeight + 1.0 && strongSelf.chatListDisplayNode.inlineStackContainerNode != nil {
                        strongSelf.setInlineChatList(location: nil)
                    } else if offset <= navigationBarSearchContentHeight + 1.0 && !isFirstFilter {
                        let firstFilter = strongSelf.chatListDisplayNode.effectiveContainerNode.availableFilters.first ?? .all
                        let targetTab: ChatListFilterTabEntryId
                        switch firstFilter {
                            case .all:
                                targetTab = .all
                            case let .filter(filter):
                                targetTab = .filter(filter.id)
                        }
                        strongSelf.selectTab(id: targetTab)
                    } else {
                        if let searchContentNode = strongSelf.searchContentNode {
                            searchContentNode.updateExpansionProgress(1.0, animated: true)
                        }
                        if let inlineStackContainerNode = strongSelf.chatListDisplayNode.inlineStackContainerNode {
                            inlineStackContainerNode.currentItemNode.scrollToPosition(.top)
                        } else {
                            strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.scrollToPosition(.top)
                        }
                    }
                }
            }
        }
        
        self.badgeDisposable = (combineLatest(renderedTotalUnreadCount(accountManager: context.sharedContext.accountManager, engine: context.engine), self.presentationDataValue.get()) |> deliverOnMainQueue).start(next: { [weak self] count, presentationData in
            if let strongSelf = self {
                if count.0 == 0 {
                    strongSelf.tabBarItem.badgeValue = ""
                } else {
                    strongSelf.tabBarItem.badgeValue = compactNumericCountString(Int(count.0), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                }
            }
        })
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataValue.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        if !previewing {
            let placeholder: String
            let compactPlaceholder: String
            
            var isForum = false
            if case .forum = location {
                isForum = true
                placeholder = self.presentationData.strings.Common_Search
                compactPlaceholder = self.presentationData.strings.Common_Search
            } else {
                placeholder = self.presentationData.strings.DialogList_SearchLabel
                compactPlaceholder = self.presentationData.strings.DialogList_SearchLabelCompact
            }
            
            self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: placeholder, compactPlaceholder: compactPlaceholder, activate: { [weak self] in
                self?.activateSearch(filter: isForum ? .topics : .chats)
            })
            self.searchContentNode?.updateExpansionProgress(0.0)
            self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
            
            enum State: Equatable {
                case empty(hasDownloads: Bool)
                case downloading(progress: Double)
                case hasUnseen
            }
            
            let entriesWithFetchStatuses = Signal<[(entry: FetchManagerEntrySummary, progress: Double)], NoError> { subscriber in
                let queue = Queue()
                final class StateHolder {
                    final class EntryContext {
                        var entry: FetchManagerEntrySummary
                        var isRemoved: Bool = false
                        var statusDisposable: Disposable?
                        var status: MediaResourceStatus?
                        
                        init(entry: FetchManagerEntrySummary) {
                            self.entry = entry
                        }
                        
                        deinit {
                            self.statusDisposable?.dispose()
                        }
                    }
                    
                    let queue: Queue
                    
                    var entryContexts: [FetchManagerLocationEntryId: EntryContext] = [:]
                    
                    let state = Promise<[(entry: FetchManagerEntrySummary, progress: Double)]>()
                    
                    init(queue: Queue) {
                        self.queue = queue
                    }
                    
                    func update(engine: TelegramEngine, entries: [FetchManagerEntrySummary]) {
                        if entries.isEmpty {
                            self.entryContexts.removeAll()
                        } else {
                            for entry in entries {
                                let context: EntryContext
                                if let current = self.entryContexts[entry.id] {
                                    context = current
                                } else {
                                    context = EntryContext(entry: entry)
                                    self.entryContexts[entry.id] = context
                                }
                                
                                context.entry = entry
                                
                                if context.isRemoved {
                                    context.isRemoved = false
                                    context.status = nil
                                    context.statusDisposable?.dispose()
                                    context.statusDisposable = nil
                                }
                            }
                            
                            for (_, context) in self.entryContexts {
                                if !entries.contains(where: { $0.id == context.entry.id }) {
                                    context.isRemoved = true
                                }
                                
                                if context.statusDisposable == nil {
                                    context.statusDisposable = (engine.account.postbox.mediaBox.resourceStatus(context.entry.resourceReference.resource)
                                    |> deliverOn(self.queue)).start(next: { [weak self, weak context] status in
                                        guard let strongSelf = self, let context = context else {
                                            return
                                        }
                                        if context.status != status {
                                            context.status = status
                                            strongSelf.notifyUpdatedIfReady()
                                        }
                                    })
                                }
                            }
                        }
                        
                        self.notifyUpdatedIfReady()
                    }
                    
                    func notifyUpdatedIfReady() {
                        var result: [(entry: FetchManagerEntrySummary, progress: Double)] = []
                        loop: for (_, context) in self.entryContexts {
                            guard let status = context.status else {
                                return
                            }
                            let progress: Double
                            switch status {
                            case .Local:
                                progress = 1.0
                            case .Remote:
                                if context.isRemoved {
                                    continue loop
                                }
                                progress = 0.0
                            case let .Paused(value):
                                progress = Double(value)
                            case let .Fetching(_, value):
                                progress = Double(value)
                            }
                            result.append((context.entry, progress))
                        }
                        self.state.set(.single(result))
                    }
                }
                let holder = QueueLocalObject<StateHolder>(queue: queue, generate: {
                    return StateHolder(queue: queue)
                })
                let entriesDisposable = ((context.fetchManager as! FetchManagerImpl).entriesSummary).start(next: { entries in
                    holder.with { holder in
                        holder.update(engine: context.engine, entries: entries)
                    }
                })
                let holderStateDisposable = MetaDisposable()
                holder.with { holder in
                    holderStateDisposable.set(holder.state.get().start(next: { state in
                        subscriber.putNext(state)
                    }))
                }
                
                return ActionDisposable {
                    entriesDisposable.dispose()
                    holderStateDisposable.dispose()
                }
            }
            
            let displayRecentDownloads = context.account.postbox.tailChatListView(groupId: .root, filterPredicate: nil, count: 11, summaryComponents: ChatListEntrySummaryComponents(components: [:]))
            |> map { view -> Bool in
                return view.0.entries.count >= 10
            }
            |> distinctUntilChanged
            
            let stateSignal: Signal<State, NoError> = (combineLatest(queue: .mainQueue(), entriesWithFetchStatuses, recentDownloadItems(postbox: context.account.postbox), displayRecentDownloads)
            |> map { entries, recentDownloadItems, displayRecentDownloads -> State in
                if !entries.isEmpty && displayRecentDownloads {
                    var totalBytes = 0.0
                    var totalProgressInBytes = 0.0
                    for (entry, progress) in entries {
                        var size: Int64 = 1024 * 1024 * 1024
                        if let sizeValue = entry.resourceReference.resource.size {
                            size = sizeValue
                        }
                        totalBytes += Double(size)
                        totalProgressInBytes += Double(size) * progress
                    }
                    let totalProgress: Double
                    if totalBytes.isZero {
                        totalProgress = 0.0
                    } else {
                        totalProgress = totalProgressInBytes / totalBytes
                    }
                    return .downloading(progress: totalProgress)
                } else {
                    for item in recentDownloadItems {
                        if !item.isSeen {
                            return .hasUnseen
                        }
                    }
                    return .empty(hasDownloads: !recentDownloadItems.isEmpty)
                }
            }
            |> mapToSignal { value -> Signal<State, NoError> in
                return .single(value) |> delay(0.1, queue: .mainQueue())
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue)
            
            self.activeDownloadsDisposable = stateSignal.start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                let animation: LottieAnimationComponent.AnimationItem?
                let colors: [String: UIColor]
                let progressValue: Double?
                switch state {
                case let .downloading(progress):
                    strongSelf.hasDownloads = true
                    
                    animation = LottieAnimationComponent.AnimationItem(
                        name: "anim_search_downloading",
                        mode: .animating(loop: true)
                    )
                    colors = [
                        "Oval.Ellipse 1.Stroke 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Arrow1.Union.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Arrow2.Union.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                    ]
                    progressValue = progress
                    
                    strongSelf.clearUnseenDownloadsTimer?.invalidate()
                    strongSelf.clearUnseenDownloadsTimer = nil
                case .hasUnseen:
                    strongSelf.hasDownloads = true
                    
                    animation = LottieAnimationComponent.AnimationItem(
                        name: "anim_search_downloaded",
                        mode: .animating(loop: false)
                    )
                    colors = [
                        "Fill 2.Ellipse 1.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Mask1.Ellipse 1.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Mask2.Ellipse 1.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Arrow3.Union.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Fill.Ellipse 1.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Oval.Ellipse 1.Stroke 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Arrow1.Union.Fill 1": strongSelf.presentationData.theme.list.itemAccentColor,
                        "Arrow2.Union.Fill 1": strongSelf.presentationData.theme.rootController.navigationSearchBar.inputFillColor.blitOver(strongSelf.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor, alpha: 1.0),
                    ]
                    progressValue = 1.0
                    
                    if strongSelf.clearUnseenDownloadsTimer == nil {
                        let timeout: Double
                        #if DEBUG
                        timeout = 10.0
                        #else
                        timeout = 1.0 * 60.0
                        #endif
                        strongSelf.clearUnseenDownloadsTimer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.clearUnseenDownloadsTimer = nil
                            let _ = markAllRecentDownloadItemsAsSeen(postbox: strongSelf.context.account.postbox).start()
                        }, queue: .mainQueue())
                        strongSelf.clearUnseenDownloadsTimer?.start()
                    }
                case let .empty(hasDownloadsValue):
                    strongSelf.hasDownloads = hasDownloadsValue
                    
                    animation = nil
                    colors = [:]
                    progressValue = nil
                    
                    strongSelf.clearUnseenDownloadsTimer?.invalidate()
                    strongSelf.clearUnseenDownloadsTimer = nil
                }
                
                if let animation = animation, let progressValue = progressValue {
                    let contentComponent = AnyComponent(ZStack<Empty>([
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieAnimationComponent(
                            animation: animation,
                            colors: colors,
                            size: CGSize(width: 24.0, height: 24.0)
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ProgressIndicatorComponent(
                            diameter: 16.0,
                            backgroundColor: .clear,
                            foregroundColor: strongSelf.presentationData.theme.list.itemAccentColor,
                            value: progressValue
                        )))
                    ]))
                    
                    strongSelf.searchContentNode?.placeholderNode.setAccessoryComponent(component: AnyComponent(Button(
                        content: contentComponent,
                        action: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.activateSearch(filter: .downloads, query: nil)
                        }
                    )))
                } else {
                    strongSelf.searchContentNode?.placeholderNode.setAccessoryComponent(component: nil)
                }
            })
        }
        
        if enableDebugActions {
            self.tabBarItemDebugTapAction = {
                preconditionFailure("debug tap")
            }
        }
        
        if case .chatList(.root) = self.location {
            self.chatListDisplayNode.mainContainerNode.currentItemFilterUpdated = { [weak self] filter, fraction, transition, force in
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
                    strongSelf.tabContainerNode.cancelAnimations()
                }
                strongSelf.tabContainerNode.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: tabContainerData.0, selectedFilter: filter, isReordering: strongSelf.chatListDisplayNode.isReorderingFilters || (strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.currentState.editing && !strongSelf.chatListDisplayNode.didBeginSelectingChatsWhileEditing), isEditing: strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.currentState.editing, canReorderAllChats: strongSelf.isPremium, filtersLimit: tabContainerData.2, transitionFraction: fraction, presentationData: strongSelf.presentationData, transition: transition)
            }
            self.reloadFilters()
        }
        
        self.updateNavigationMetadata()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
        self.badgeDisposable?.dispose()
        self.badgeIconDisposable?.dispose()
        self.passcodeLockTooltipDisposable.dispose()
        self.suggestLocalizationDisposable.dispose()
        self.suggestAutoarchiveDisposable.dispose()
        self.dismissAutoarchiveDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.stateDisposable.dispose()
        self.filterDisposable.dispose()
        self.featuredFiltersDisposable.dispose()
        self.activeDownloadsDisposable?.dispose()
        self.selectAddMemberDisposable.dispose()
        self.addMemberDisposable.dispose()
        self.joinForumDisposable.dispose()
        self.actionDisposables.dispose()
    }
    
    private func updateNavigationMetadata() {
        guard let currentContext = self.secondaryContext ?? self.primaryContext else {
            return
        }
        
        switch currentContext.location {
        case .chatList:
            self.navigationBar?.userInfo = nil
            self.navigationBar?.allowsCustomTransition = {
                return false
            }
        case let .forum(peerId):
            self.navigationBar?.userInfo = PeerInfoNavigationSourceTag(peerId: peerId)
            self.navigationBar?.allowsCustomTransition = { [weak self] in
                guard let strongSelf = self else {
                    return false
                }
                if strongSelf.navigationBar?.userInfo == nil {
                    return false
                }
                return true
            }
        }
    }
    
    func findTitleView() -> ChatListTitleView? {
        guard let componentView = self.headerContentView.view as? ChatListHeaderComponent.View else {
            return nil
        }
        return componentView.findTitleView()
    }
    
    private func openStatusSetup(sourceView: UIView) {
        self.emojiStatusSelectionController?.dismiss()
        var selectedItems = Set<MediaId>()
        var topStatusTitle = self.presentationData.strings.PeerStatusSetup_NoTimerTitle
        var currentSelection: Int64?
        if let peerStatus = self.findTitleView()?.title.peerStatus, case let .emoji(emojiStatus) = peerStatus {
            selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: emojiStatus.fileId))
            currentSelection = emojiStatus.fileId
            
            if let timestamp = emojiStatus.expirationDate {
                topStatusTitle = peerStatusExpirationString(statusTimestamp: timestamp, relativeTo: Int32(Date().timeIntervalSince1970), strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat)
            }
        }
        let controller = EmojiStatusSelectionController(
            context: self.context,
            mode: .statusSelection,
            sourceView: sourceView,
            emojiContent: EmojiPagerContentComponent.emojiInputData(
                context: self.context,
                animationCache: self.animationCache,
                animationRenderer: self.animationRenderer,
                isStandalone: false,
                isStatusSelection: true,
                isReactionSelection: false,
                isEmojiSelection: false,
                hasTrending: false,
                topReactionItems: [],
                areUnicodeEmojiEnabled: false,
                areCustomEmojiEnabled: true,
                chatPeerId: self.context.account.peerId,
                selectedItems: selectedItems,
                topStatusTitle: topStatusTitle
            ),
            currentSelection: currentSelection,
            destinationItemView: { [weak sourceView] in
                return sourceView
            }
        )
        self.emojiStatusSelectionController = controller
        self.present(controller, in: .window(.root))
    }
    
    private func updateThemeAndStrings() {
        if case .chatList(.root) = self.location {
            self.tabBarItem.title = self.presentationData.strings.DialogList_Title
            let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
            backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
            self.navigationItem.backBarButtonItem = backBarButtonItem
            
            if !self.presentationData.reduceMotion {
                self.tabBarItem.animationName = "TabChats"
            } else {
                self.tabBarItem.animationName = nil
            }
        } else {
            let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
            backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
            self.navigationItem.backBarButtonItem = backBarButtonItem
        }
        
        let placeholder: String
        let compactPlaceholder: String
        if case .forum = location {
            placeholder = self.presentationData.strings.Common_Search
            compactPlaceholder = self.presentationData.strings.Common_Search
        } else {
            placeholder = self.presentationData.strings.DialogList_SearchLabel
            compactPlaceholder = self.presentationData.strings.DialogList_SearchLabelCompact
        }
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: placeholder, compactPlaceholder: compactPlaceholder)
        
        /*let editing = self.chatListDisplayNode.containerNode.currentItemNode.currentState.editing
        if case .chatList(.root) = self.location {
            self.primaryContext?.leftButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                content: .text(title: self.presentationData.strings.Common_Edit, isBold: false),
                pressed: { [weak self] in
                    self?.editPressed()
                }
            )))
            self.primaryContext?.rightButton = AnyComponentWithIdentity(id: "compose", component: AnyComponent(NavigationButtonComponent(
                content: .icon(imageName: "Chat List/Compose Icon"),
                pressed: { [weak self] in
                    self?.composePressed()
                }
            )))
        } else {
            self.primaryContext?.rightButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                content: .text(title: self.presentationData.strings.Common_Edit, isBold: false),
                pressed: { [weak self] in
                    self?.editPressed()
                }
            )))
        }*/
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if let layout = self.validLayout {
            self.tabContainerNode.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: self.tabContainerData?.0 ?? [], selectedFilter: self.chatListDisplayNode.effectiveContainerNode.currentItemFilter, isReordering: self.chatListDisplayNode.isReorderingFilters || (self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing && !self.chatListDisplayNode.didBeginSelectingChatsWhileEditing), isEditing: self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing, canReorderAllChats: self.isPremium, filtersLimit: self.tabContainerData?.2, transitionFraction: self.chatListDisplayNode.effectiveContainerNode.transitionFraction, presentationData: self.presentationData, transition: .immediate)
        }
        
        if self.isNodeLoaded {
            self.chatListDisplayNode.updatePresentationData(self.presentationData)
        }
        
        self.requestUpdateHeaderContent(transition: .immediate)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(context: self.context, location: self.location, previewing: self.previewing, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, controller: self)
        
        self.chatListDisplayNode.navigationBar = self.navigationBar
        
        self.chatListDisplayNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.chatListDisplayNode.mainContainerNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.chatListDisplayNode.mainContainerNode.presentAlert = { [weak self] text in
            if let strongSelf = self {
                self?.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.present = { [weak self] c in
            if let strongSelf = self {
                strongSelf.present(c, in: .window(.root))
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.push = { [weak self] c in
            if let strongSelf = self {
                strongSelf.push(c)
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.toggleArchivedFolderHiddenByDefault = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.toggleArchivedFolderHiddenByDefault()
        }
        
        self.chatListDisplayNode.mainContainerNode.hidePsa = { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.hidePsa(peerId)
        }
        
        self.chatListDisplayNode.mainContainerNode.deletePeerChat = { [weak self] peerId, joined in
            guard let strongSelf = self else {
                return
            }
            strongSelf.deletePeerChat(peerId: peerId, joined: joined)
        }
        self.chatListDisplayNode.mainContainerNode.deletePeerThread = { [weak self] peerId, threadId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.deletePeerThread(peerId: peerId, threadId: threadId)
        }
        self.chatListDisplayNode.mainContainerNode.setPeerThreadStopped = { [weak self] peerId, threadId, isStopped in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setPeerThreadStopped(peerId: peerId, threadId: threadId, isStopped: isStopped)
        }
        self.chatListDisplayNode.mainContainerNode.setPeerThreadPinned = { [weak self] peerId, threadId, isPinned in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setPeerThreadPinned(peerId: peerId, threadId: threadId, isPinned: isPinned)
        }
        self.chatListDisplayNode.mainContainerNode.setPeerThreadHidden = { [weak self] peerId, threadId, isHidden in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setPeerThreadHidden(peerId: peerId, threadId: threadId, isHidden: isHidden)
        }
        
        self.chatListDisplayNode.mainContainerNode.peerSelected = { [weak self] peer, threadId, animated, activateInput, promoInfo in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var scrollToEndIfExists = false
                    if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                        scrollToEndIfExists = true
                    }
                    
                    if case let .channel(channel) = peer, channel.flags.contains(.isForum), threadId == nil {
                        strongSelf.chatListDisplayNode.clearHighlightAnimated(true)
                        
                        if strongSelf.chatListDisplayNode.inlineStackContainerNode?.location == .forum(peerId: channel.id) {
                            strongSelf.setInlineChatList(location: nil)
                        } else {
                            strongSelf.setInlineChatList(location: .forum(peerId: channel.id))
                        }
                    } else {
                        if let threadId = threadId {
                            let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: peer.id, threadId: threadId, messageId: nil, navigationController: navigationController, activateInput: nil, keepStack: .never).start()
                            strongSelf.chatListDisplayNode.clearHighlightAnimated(true)
                        } else {
                            var navigationAnimationOptions: NavigationAnimationOptions = []
                            var groupId: EngineChatList.Group = .root
                            if case let .chatList(groupIdValue) = strongSelf.location {
                                groupId = groupIdValue
                                if case .root = groupIdValue {
                                    navigationAnimationOptions = .removeOnMasterDetails
                                }
                            }
                            
                            let chatLocation: NavigateToChatControllerParams.Location
                            chatLocation = .peer(peer)
                            
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: chatLocation, activateInput: (activateInput && !peer.isDeleted) ? .text : nil, scrollToEndIfExists: scrollToEndIfExists, animated: !scrollToEndIfExists, options: navigationAnimationOptions, parentGroupId: groupId._asGroup(), chatListFilter: strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter?.id, completion: { [weak self] controller in
                                self?.chatListDisplayNode.mainContainerNode.currentItemNode.clearHighlightAnimated(true)
                                if let promoInfo = promoInfo {
                                    switch promoInfo {
                                    case .proxy:
                                        let _ = (ApplicationSpecificNotice.getProxyAdsAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager)
                                                 |> deliverOnMainQueue).start(next: { value in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            if !value {
                                                controller.displayPromoAnnouncement(text: strongSelf.presentationData.strings.DialogList_AdNoticeAlert)
                                                let _ = ApplicationSpecificNotice.setProxyAdsAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                            }
                                        })
                                    case let .psa(type, _):
                                        let _ = (ApplicationSpecificNotice.getPsaAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peer.id)
                                                 |> deliverOnMainQueue).start(next: { value in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            if !value {
                                                var text = strongSelf.presentationData.strings.ChatList_GenericPsaAlert
                                                let key = "ChatList.PsaAlert.\(type)"
                                                if let string = strongSelf.presentationData.strings.primaryComponent.dict[key] {
                                                    text = string
                                                } else if let string = strongSelf.presentationData.strings.secondaryComponent?.dict[key] {
                                                    text = string
                                                }
                                                
                                                controller.displayPromoAnnouncement(text: text)
                                                let _ = ApplicationSpecificNotice.setPsaAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peer.id).start()
                                            }
                                        })
                                    }
                                }
                            }))
                        }
                    }
                }
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.groupSelected = { [weak self] groupId in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    let chatListController = ChatListControllerImpl(context: strongSelf.context, location: .chatList(groupId: groupId), controlsHistoryPreload: false, enableDebugActions: false)
                    chatListController.navigationPresentation = .master
                    navigationController.pushViewController(chatListController)
                    strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.clearHighlightAnimated(true)
                }
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.updatePeerGrouping = { [weak self] peerId, group in
            guard let strongSelf = self else {
                return
            }
            if group {
                strongSelf.archiveChats(peerIds: [peerId])
            } else {
                strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
                let _ = strongSelf.context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: group ? .archive : .root).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                })
            }
        }
        
        self.chatListDisplayNode.requestOpenMessageFromSearch = { [weak self] peer, threadId, messageId, deactivateOnAction in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((strongSelf.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer)
                |> deliverOnMainQueue).start(next: { [weak strongSelf] actualPeer in
                    if let strongSelf = strongSelf {
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            var scrollToEndIfExists = false
                            if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                                scrollToEndIfExists = true
                            }
                            var navigationAnimationOptions: NavigationAnimationOptions = []
                            if case .chatList(.root) = strongSelf.location {
                                navigationAnimationOptions = .removeOnMasterDetails
                            }
                            if let threadId = threadId  {
                                let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: peer.id, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: nil, keepStack: .never).start()
                            } else {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(actualPeer), subject: .message(id: .id(messageId), highlight: true, timecode: nil), purposefulAction: {
                                    if deactivateOnAction {
                                        self?.deactivateSearch(animated: false)
                                    }
                                }, scrollToEndIfExists: scrollToEndIfExists, options: navigationAnimationOptions))
                            }
                            strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.clearHighlightAnimated(true)
                        }
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenPeerFromSearch = { [weak self] peer, threadId, dismissSearch in
            if let strongSelf = self {
                let storedPeer = strongSelf.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer) |> map { _ -> Void in return Void() }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if dismissSearch {
                            strongSelf.deactivateSearch(animated: true)
                        }
                        var scrollToEndIfExists = false
                        if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                            scrollToEndIfExists = true
                        }
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            var navigationAnimationOptions: NavigationAnimationOptions = []
                            if case .chatList(.root) = strongSelf.location {
                                navigationAnimationOptions = .removeOnMasterDetails
                            }
                            if let threadId = threadId  {
                                let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: peer.id, threadId: threadId, messageId: nil, navigationController: navigationController, activateInput: nil, keepStack: .never).start()
                            } else {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), purposefulAction: { [weak self] in
                                    self?.deactivateSearch(animated: false)
                                }, scrollToEndIfExists: scrollToEndIfExists, options: navigationAnimationOptions))
                            }
                            strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.clearHighlightAnimated(true)
                        }
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenRecentPeerOptions = { [weak self] peer in
            if let strongSelf = self {
                strongSelf.view.window?.endEditing(true)
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            if let strongSelf = self {
                                let _ = strongSelf.context.engine.peers.removeRecentPeer(peerId: peer.id).start()
                            }
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }
        
        self.chatListDisplayNode.requestAddContact = { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    (self?.navigationController as? NavigationController)?.pushViewController(controller)
                }, completed: {
                    self?.deactivateSearch(animated: false)
                })
            }
        }
        
        self.chatListDisplayNode.dismissSelfIfCompletedPresentation = { [weak self] in
            guard let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController else {
                return
            }
            if !strongSelf.didAppear {
                return
            }
            navigationController.filterController(strongSelf, animated: true)
        }
        
        self.chatListDisplayNode.contentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode, let validLayout = strongSelf.validLayout {
                var offset = offset
                if validLayout.inVoiceOver {
                    offset = .known(0.0)
                }
                searchContentNode.updateListVisibleContentOffset(offset, transition: strongSelf.chatListDisplayNode.temporaryContentOffsetChangeTransition ?? .immediate)
            }
        }
        
        self.chatListDisplayNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        self.chatListDisplayNode.emptyListAction = { [weak self] _ in
            guard let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController else {
                return
            }
            if let filter = strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.chatListFilter {
                strongSelf.push(chatListFilterPresetController(context: strongSelf.context, currentPreset: filter, updated: { _ in }))
            } else {
                if case let .forum(peerId) = strongSelf.chatListDisplayNode.effectiveContainerNode.location {
                    let context = strongSelf.context
                    let controller = ForumCreateTopicScreen(context: context, peerId: peerId, mode: .create)
                    controller.navigationPresentation = .modal
                    
                    controller.completion = { [weak controller] title, fileId, _ in
                        controller?.isInProgress = true
                        
                        let _ = (context.engine.peers.createForumChannelTopic(id: peerId, title: title, iconColor: ForumCreateTopicScreen.iconColors.randomElement()!, iconFileId: fileId)
                        |> deliverOnMainQueue).start(next: { topicId in
                            let _ = context.sharedContext.navigateToForumThread(context: context, peerId: peerId, threadId: topicId, messageId: nil, navigationController: navigationController, activateInput: .text, keepStack: .never).start()
                        }, error: { _ in
                            controller?.isInProgress = false
                        })
                    }
                    strongSelf.push(controller)
                } else {
                    strongSelf.composePressed()
                }
            }
        }
        
        self.chatListDisplayNode.cancelEditing = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reorderingDonePressed()
        }
        
        self.chatListDisplayNode.toolbarActionSelected = { [weak self] action in
            self?.toolbarActionSelected(action: action)
        }
        
        self.chatListDisplayNode.mainContainerNode.activateChatPreview = { [weak self] item, threadId, node, gesture, location in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            var joined = false
            if case let .peer(peerData) = item.content, let message = peerData.messages.first {
                for media in message.media {
                    if let action = media as? TelegramMediaAction, action.action == .peerJoined {
                        joined = true
                    }
                }
            }
            
            switch item.content {
            case let .groupReference(groupId, _, _, _, _):
                let chatListController = ChatListControllerImpl(context: strongSelf.context, location: .chatList(groupId: groupId), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                chatListController.navigationPresentation = .master
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController)), items: archiveContextMenuItems(context: strongSelf.context, groupId: groupId._asGroup(), chatListController: strongSelf) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            case let .peer(peerData):
                let peer = peerData.peer
                let threadInfo = peerData.threadInfo
                let promoInfo = peerData.promoInfo
                
                switch item.index {
                case .chatList:
                    if case let .channel(channel) = peer.peer, channel.flags.contains(.isForum) {
                        if let threadId = threadId {
                            let source: ContextContentSource
                            let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .replyThread(message: ChatReplyThreadMessage(
                                messageId: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false
                            )), subject: nil, botStart: nil, mode: .standard(previewing: true))
                            chatController.canReadHistory.set(false)
                            source = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController))
                            
                            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: source, items: chatForumTopicMenuItems(context: strongSelf.context, peerId: peer.peerId, threadId: threadId, isPinned: nil, isClosed: nil, chatListController: strongSelf, joined: joined, canSelect: false) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                            strongSelf.presentInGlobalOverlay(contextController)
                        } else {
                            let chatListController = ChatListControllerImpl(context: strongSelf.context, location: .forum(peerId: channel.id), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                            chatListController.navigationPresentation = .master
                            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController)), items: chatContextMenuItems(context: strongSelf.context, peerId: peer.peerId, promoInfo: promoInfo, source: .chatList(filter: strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter), chatListController: strongSelf, joined: joined) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                            strongSelf.presentInGlobalOverlay(contextController)
                        }
                    } else {
                        let source: ContextContentSource
                        if let location = location {
                            source = .location(ChatListContextLocationContentSource(controller: strongSelf, location: location))
                        } else {
                            let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peer.peerId), subject: nil, botStart: nil, mode: .standard(previewing: true))
                            chatController.canReadHistory.set(false)
                            source = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController))
                        }
                        
                        let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: source, items: chatContextMenuItems(context: strongSelf.context, peerId: peer.peerId, promoInfo: promoInfo, source: .chatList(filter: strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter), chatListController: strongSelf, joined: joined) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                        strongSelf.presentInGlobalOverlay(contextController)
                    }
                case let .forum(pinnedIndex, _, threadId, _, _):
                    let isPinned: Bool
                    switch pinnedIndex {
                    case .index:
                        isPinned = true
                    case .none:
                        isPinned = false
                    }
                    let source: ContextContentSource
                    let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .replyThread(message: ChatReplyThreadMessage(
                        messageId: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false
                    )), subject: nil, botStart: nil, mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    source = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController))
                    
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: source, items: chatForumTopicMenuItems(context: strongSelf.context, peerId: peer.peerId, threadId: threadId, isPinned: isPinned, isClosed: threadInfo?.isClosed, chatListController: strongSelf, joined: joined, canSelect: true) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                    strongSelf.presentInGlobalOverlay(contextController)
                }
            }
        }
        
        self.chatListDisplayNode.peerContextAction = { [weak self] peer, source, node, gesture, location in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                let chatListController = ChatListControllerImpl(context: strongSelf.context, location: .forum(peerId: channel.id), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                chatListController.navigationPresentation = .master
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController)), items: chatContextMenuItems(context: strongSelf.context, peerId: peer.id, promoInfo: nil, source: .search(source), chatListController: strongSelf, joined: false) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            } else {
                let contextContentSource: ContextContentSource
                if peer.id.namespace == Namespaces.Peer.SecretChat, let node = node.subnodes?.first as? ContextExtractedContentContainingNode {
                    contextContentSource = .extracted(ChatListHeaderBarContextExtractedContentSource(controller: strongSelf, sourceNode: node, keepInPlace: false))
                } else {
                    var subject: ChatControllerSubject?
                    if case let .search(messageId) = source, let id = messageId {
                        subject = .message(id: .id(id), highlight: false, timecode: nil)
                    }
                    let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peer.id), subject: subject, botStart: nil, mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    contextContentSource = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: strongSelf.navigationController as? NavigationController))
                }
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: contextContentSource, items: chatContextMenuItems(context: strongSelf.context, peerId: peer.id, promoInfo: nil, source: .search(source), chatListController: strongSelf, joined: false) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            }
        }
        
        self.tabContainerNode.tabSelected = { [weak self] id, isDisabled in
            guard let strongSelf = self else {
                return
            }
            if isDisabled {
                let context = strongSelf.context
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: strongSelf.tabContainerNode.filtersCount, action: {
                    let controller = PremiumIntroScreen(context: context, source: .folders)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                strongSelf.push(controller)
            } else {
                strongSelf.selectTab(id: id)
            }
        }
        
        self.tabContainerNode.tabRequestedDeletion = { [weak self] id in
            if case let .filter(id) = id {
                self?.askForFilterRemoval(id: id)
            }
        }
        self.tabContainerNode.presentPremiumTip = { [weak self] in
            if let strongSelf = self {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_reorder", scale: 0.05, colors: [:], title: nil, text: strongSelf.presentationData.strings.ChatListFolderSettings_SubscribeToMoveAll, customUndoText: strongSelf.presentationData.strings.ChatListFolderSettings_SubscribeToMoveAllAction), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { action in
                    if case .undo = action {
                        let context = strongSelf.context
                        var replaceImpl: ((ViewController) -> Void)?
                        let controller = PremiumDemoScreen(context: context, subject: .advancedChatManagement, action: {
                            let controller = PremiumIntroScreen(context: context, source: .folders)
                            replaceImpl?(controller)
                        })
                        replaceImpl = { [weak controller] c in
                            controller?.replace(with: c)
                        }
                        strongSelf.push(controller)
                    }
                    return false }), in: .current)
            }
        }
        
        let tabContextGesture: (Int32?, ContextExtractedContentContainingNode, ContextGesture, Bool, Bool) -> Void = { [weak self] id, sourceNode, gesture, keepInPlace, isDisabled in
            guard let strongSelf = self else {
                return
            }
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                strongSelf.context.engine.peers.currentChatListFilters(),
                strongSelf.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
                )
            ).start(next: { [weak self] filters, premiumLimits in
                guard let strongSelf = self else {
                    return
                }
                var items: [ContextMenuItem] = []
                if let id = id {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_EditFolder, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                    }, action: { c, f in
                        c.dismiss(completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            if isDisabled {
                                let context = strongSelf.context
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = PremiumLimitScreen(context: context, subject: .folders, count: strongSelf.tabContainerNode.filtersCount, action: {
                                    let controller = PremiumIntroScreen(context: context, source: .folders)
                                    replaceImpl?(controller)
                                })
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                strongSelf.push(controller)
                            } else {
                                let _ = (strongSelf.context.engine.peers.currentChatListFilters()
                                |> deliverOnMainQueue).start(next: { presetList in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    var found = false
                                    for filter in presetList {
                                        if filter.id == id {
                                            strongSelf.push(chatListFilterPresetController(context: strongSelf.context, currentPreset: filter, updated: { _ in }))
                                            f(.dismissWithoutContent)
                                            found = true
                                            break
                                        }
                                    }
                                    if !found {
                                        f(.default)
                                    }
                                })
                            }
                        })
                    })))
                    
                    if let _ = filters.first(where: { $0.id == id }) {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_AddChatsToFolder, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                        }, action: { c, f in
                            c.dismiss(completion: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                if isDisabled {
                                    let context = strongSelf.context
                                    var replaceImpl: ((ViewController) -> Void)?
                                    let controller = PremiumLimitScreen(context: context, subject: .folders, count: strongSelf.tabContainerNode.filtersCount, action: {
                                        let controller = PremiumIntroScreen(context: context, source: .folders)
                                        replaceImpl?(controller)
                                    })
                                    replaceImpl = { [weak controller] c in
                                        controller?.replace(with: c)
                                    }
                                    strongSelf.push(controller)
                                } else {
                                    let _ = combineLatest(
                                        queue: Queue.mainQueue(),
                                        strongSelf.context.engine.data.get(
                                            TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.context.account.peerId),
                                            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                                            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
                                        ),
                                        strongSelf.context.engine.peers.currentChatListFilters()
                                    ).start(next: { result, presetList in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        var found = false
                                        for filter in presetList {
                                            if filter.id == id, case let .filter(_, _, _, data) = filter {
                                                let (accountPeer, limits, premiumLimits) = result
                                                let isPremium = accountPeer?.isPremium ?? false
                                                
                                                let limit = limits.maxFolderChatsCount
                                                let premiumLimit = premiumLimits.maxFolderChatsCount
                                                
                                                if data.includePeers.peers.count >= premiumLimit {
                                                    let controller = PremiumLimitScreen(context: strongSelf.context, subject: .chatsPerFolder, count: Int32(data.includePeers.peers.count), action: {})
                                                    strongSelf.push(controller)
                                                    f(.dismissWithoutContent)
                                                    return
                                                } else if data.includePeers.peers.count >= limit && !isPremium {
                                                    var replaceImpl: ((ViewController) -> Void)?
                                                    let controller = PremiumLimitScreen(context: strongSelf.context, subject: .chatsPerFolder, count: Int32(data.includePeers.peers.count), action: {
                                                        let controller = PremiumIntroScreen(context: strongSelf.context, source: .chatsPerFolder)
                                                        replaceImpl?(controller)
                                                    })
                                                    replaceImpl = { [weak controller] c in
                                                        controller?.replace(with: c)
                                                    }
                                                    strongSelf.push(controller)
                                                    f(.dismissWithoutContent)
                                                    return
                                                }
                                                
                                                let _ = (strongSelf.context.engine.peers.currentChatListFilters()
                                                |> deliverOnMainQueue).start(next: { filters in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.push(chatListFilterAddChatsController(context: strongSelf.context, filter: filter, allFilters: filters, limit: limits.maxFolderChatsCount, premiumLimit: premiumLimits.maxFolderChatsCount, isPremium: isPremium))
                                                    f(.dismissWithoutContent)
                                                })
                                                found = true
                                                break
                                            }
                                        }
                                        if !found {
                                            f(.default)
                                        }
                                    })
                                }
                            })
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_RemoveFolder, textColor: .destructive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                        }, action: { c, f in
                            c.dismiss(completion: {
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.askForFilterRemoval(id: id)
                            })
                        })))
                    }
                } else {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_EditFolders, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                    }, action: { c, f in
                        c.dismiss(completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.openFilterSettings()
                        })
                    })))
                }
                
                if filters.count > 1 {
                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_ReorderTabs, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                    }, action: { c, f in
                        c.dismiss(completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.chatListDisplayNode.isReorderingFilters = true
                            strongSelf.isReorderingTabsValue.set(true)
                            strongSelf.searchContentNode?.setIsEnabled(false, animated: true)
                            (strongSelf.parent as? TabBarController)?.updateIsTabBarEnabled(false, transition: .animated(duration: 0.2, curve: .easeInOut))
                            if let layout = strongSelf.validLayout {
                                strongSelf.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
                            }
                        })
                    })))
                }
                
                let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatListHeaderBarContextExtractedContentSource(controller: strongSelf, sourceNode: sourceNode, keepInPlace: keepInPlace)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
                strongSelf.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
            })
        }
        self.tabContainerNode.contextGesture = { id, sourceNode, gesture, isDisabled in
            tabContextGesture(id, sourceNode, gesture, false, isDisabled)
        }
        
        if case .chatList(.root) = self.location {
            self.ready.set(.never())
        } else {
            self.ready.set(combineLatest([
                self.chatListDisplayNode.mainContainerNode.ready,
                self.primaryInfoReady.get()
            ])
            |> map { values -> Bool in
                return !values.contains(where: { !$0 })
            }
            |> filter { $0 })
        }
        
        self.displayNodeDidLoad()
    }
    
    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        
        Queue.mainQueue().after(1.0) {
            self.context.prefetchManager?.prepareNextGreetingSticker()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
                
        self.didAppear = true
        
        self.chatListDisplayNode.mainContainerNode.updateEnableAdjacentFilterLoading(true)
        
        self.chatListDisplayNode.mainContainerNode.didBeginSelectingChats = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.chatListDisplayNode.didBeginSelectingChatsWhileEditing {
                var isEditing = false
                strongSelf.chatListDisplayNode.effectiveContainerNode.updateState { state in
                    isEditing = state.editing
                    return state
                }
                if !isEditing {
                    strongSelf.editPressed()
                }
                strongSelf.chatListDisplayNode.didBeginSelectingChatsWhileEditing = true
                if let layout = strongSelf.validLayout {
                    strongSelf.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
                }
            }
        }
        
        self.chatListDisplayNode.mainContainerNode.displayFilterLimit = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let context = strongSelf.context
            var replaceImpl: ((ViewController) -> Void)?
            let controller = PremiumLimitScreen(context: context, subject: .folders, count: strongSelf.tabContainerNode.filtersCount, action: {
                let controller = PremiumIntroScreen(context: context, source: .folders)
                replaceImpl?(controller)
            })
            replaceImpl = { [weak controller] c in
                controller?.replace(with: c)
            }
            strongSelf.push(controller)
        }
        
        guard case .chatList(.root) = self.location else {
            return
        }
        
        #if true && DEBUG
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let count = ChatControllerCount.with({ $0 })
            if count > 1 {
                strongSelf.present(textAlertController(context: strongSelf.context, title: "", text: "ChatControllerCount \(count)", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window(.root))
            }
        })
        #endif

        if let lockViewFrame = self.findTitleView()?.lockViewFrame, !self.didShowPasscodeLockTooltipController {
            self.passcodeLockTooltipDisposable.set(combineLatest(queue: .mainQueue(), ApplicationSpecificNotice.getPasscodeLockTips(accountManager: self.context.sharedContext.accountManager), self.context.sharedContext.accountManager.accessChallengeData() |> take(1)).start(next: { [weak self] tooltipValue, passcodeView in
                    if let strongSelf = self {
                        if !tooltipValue {
                            let hasPasscode = passcodeView.data.isLockable
                            if hasPasscode {
                                let _ = ApplicationSpecificNotice.setPasscodeLockTips(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                
                                let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.DialogList_PasscodeLockHelp), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true)
                                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                                    if let strongSelf = self, let titleView = strongSelf.findTitleView() {
                                        return (titleView, lockViewFrame.offsetBy(dx: 4.0, dy: 14.0))
                                    }
                                    return nil
                                }))
                                strongSelf.didShowPasscodeLockTooltipController = true
                            }
                        } else {
                            strongSelf.didShowPasscodeLockTooltipController = true
                        }
                    }
                }))
        }
        
        if !self.didSuggestLocalization {
            self.didSuggestLocalization = true
            
            let context = self.context
            
            let suggestedLocalization = self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SuggestedLocalization())
            
            let signal = combineLatest(
                self.context.sharedContext.accountManager.transaction { transaction -> String in
                    let languageCode: String
                    if let current = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) {
                        let code = current.primaryComponent.languageCode
                        let rawSuffix = "-raw"
                        if code.hasSuffix(rawSuffix) {
                            languageCode = String(code.dropLast(rawSuffix.count))
                        } else {
                            languageCode = code
                        }
                    } else {
                        languageCode = "en"
                    }
                    return languageCode
                },
                suggestedLocalization
            )
            |> mapToSignal({ value -> Signal<(String, SuggestedLocalizationInfo)?, NoError> in
                guard let suggestedLocalization = value.1, !suggestedLocalization.isSeen && suggestedLocalization.languageCode != "en" && suggestedLocalization.languageCode != value.0 else {
                    return .single(nil)
                }
                return context.engine.localization.suggestedLocalizationInfo(languageCode: suggestedLocalization.languageCode, extractKeys: LanguageSuggestionControllerStrings.keys)
                |> map({ suggestedLocalization -> (String, SuggestedLocalizationInfo)? in
                    return (value.0, suggestedLocalization)
                })
            })
        
            self.suggestLocalizationDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] suggestedLocalization in
                guard let strongSelf = self, let (currentLanguageCode, suggestedLocalization) = suggestedLocalization else {
                    return
                }
                if let controller = languageSuggestionController(context: strongSelf.context, suggestedLocalization: suggestedLocalization, currentLanguageCode: currentLanguageCode, openSelection: { [weak self] in
                    if let strongSelf = self {
                        let controller = strongSelf.context.sharedContext.makeLocalizationListController(context: strongSelf.context)
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                    }
                }) {
                    strongSelf.present(controller, in: .window(.root))
                    _ = strongSelf.context.engine.localization.markSuggestedLocalizationAsSeenInteractively(languageCode: suggestedLocalization.languageCode).start()
                }
            }))
            
            self.suggestAutoarchiveDisposable.set((getServerProvidedSuggestions(account: self.context.account)
            |> deliverOnMainQueue).start(next: { [weak self] values in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.didSuggestAutoarchive {
                    return
                }
                if !values.contains(.autoarchivePopular) {
                    return
                }
                strongSelf.didSuggestAutoarchive = true
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_AutoarchiveSuggestion_Title, text: strongSelf.presentationData.strings.ChatList_AutoarchiveSuggestion_Text, actions: [
                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.dismissAutoarchiveDisposable.set(dismissServerProvidedSuggestion(account: strongSelf.context.account, suggestion: .autoarchivePopular).start())
                    }),
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.ChatList_AutoarchiveSuggestion_OpenSettings, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.dismissAutoarchiveDisposable.set(dismissServerProvidedSuggestion(account: strongSelf.context.account, suggestion: .autoarchivePopular).start())
                        strongSelf.push(strongSelf.context.sharedContext.makePrivacyAndSecurityController(context: strongSelf.context))
                    })
                ], actionLayout: .vertical, parseMarkdown: true), in: .window(.root))
            }))
            
            Queue.mainQueue().after(1.0, {
                let _ = (
                    self.context.engine.data.get(TelegramEngine.EngineData.Item.Notices.Notice(key: ApplicationSpecificNotice.forcedPasswordSetupKey()))
                    |> map { entry -> Int32? in
                        return entry?.get(ApplicationSpecificCounterNotice.self)?.value
                    }
                    |> deliverOnMainQueue
                ).start(next: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    guard let value = value else {
                        return
                    }
                    
                    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(strongSelf.context.engine), mode: .intro(.init(
                        title: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_Title,
                        text: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_Text,
                        actionText: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_Action,
                        doneText: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_DoneAction
                    )))
                    controller.dismissConfirmation = { [weak controller] f in
                        guard let strongSelf = self, let controller = controller else {
                            return true
                        }
                        
                        controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_DismissTitle, text: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_DismissText(value), actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_DismissActionCancel, action: {
                            }),
                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ForcedPasswordSetup_Intro_DismissActionOK, action: { [weak controller] in
                                if let strongSelf = self {
                                    let _ = ApplicationSpecificNotice.setForcedPasswordSetup(engine: strongSelf.context.engine, reloginDaysTimeout: nil).start()
                                }
                                controller?.dismiss()
                            })
                        ], parseMarkdown: true), in: .window(.root))
                        
                        return false
                    }
                    strongSelf.push(controller)
                    
                    let _ = value
                })
            })
        }
        
        self.chatListDisplayNode.mainContainerNode.addedVisibleChatsWithPeerIds = { [weak self] peerIds in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    switch controller.content {
                        case let .archivedChat(peerId, _, _, _):
                            if peerIds.contains(PeerId(peerId)) {
                                controller.dismiss()
                            }
                        default:
                            break
                    }
                }
                return true
            })
        }
                
        if !self.processedFeaturedFilters {
            let initializedFeatured = self.context.account.postbox.preferencesView(keys: [
                PreferencesKeys.chatListFiltersFeaturedState
            ])
            |> mapToSignal { view -> Signal<Bool, NoError> in
                if let entry = view.values[PreferencesKeys.chatListFiltersFeaturedState]?.get(ChatListFiltersFeaturedState.self) {
                    return .single(!entry.filters.isEmpty && !entry.isSeen)
                } else {
                    return .complete()
                }
            }
            |> take(1)
            
            let initializedFilters = self.context.engine.peers.updatedChatListFiltersInfo()
            |> mapToSignal { (filters, isInitialized) -> Signal<Bool, NoError> in
                if isInitialized {
                    return .single(!filters.isEmpty)
                } else {
                    return .complete()
                }
            }
            |> take(1)
            
            self.featuredFiltersDisposable.set((
                combineLatest(initializedFeatured, initializedFilters)
                |> take(1)
                |> delay(1.0, queue: .mainQueue())
                |> deliverOnMainQueue
            ).start(next: { [weak self] hasFeatured, hasFilters in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.processedFeaturedFilters = true
                if hasFeatured {
                    if let _ = strongSelf.validLayout, let _ = strongSelf.parent as? TabBarController {
                        let _ = (ApplicationSpecificNotice.incrementChatFolderTips(accountManager: strongSelf.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { count in
                            guard let strongSelf = self, let _ = strongSelf.validLayout, let parentController = strongSelf.parent as? TabBarController, let sourceFrame = parentController.frameForControllerTab(controller: strongSelf) else {
                                return
                            }
                            if count >= 2 {
                                return
                            }
                            
                            let absoluteFrame = sourceFrame
                            let text: String
                            if hasFilters {
                                text = strongSelf.presentationData.strings.ChatList_TabIconFoldersTooltipNonEmptyFolders
                                let _ = strongSelf.context.engine.peers.markChatListFeaturedFiltersAsSeen().start()
                                return
                            } else {
                                text = strongSelf.presentationData.strings.ChatList_TabIconFoldersTooltipEmptyFolders
                            }
                            
                            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 8.0), size: CGSize())
                            
                            parentController.present(TooltipScreen(account: strongSelf.context.account,  text: text, icon: .chatListPress, location: .point(location, .bottom), shouldDismissOnTouch: { point in
                                guard let strongSelf = self, let parentController = strongSelf.parent as? TabBarController else {
                                    return .dismiss(consume: false)
                                }
                                if parentController.isPointInsideContentArea(point: point) {
                                    return .ignore
                                }
                                return .dismiss(consume: false)
                            }), in: .current)
                        })
                    }
                }
            }))
        }
    }
    
    func dismissAllUndoControllers() {
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
        
        if let emojiStatusSelectionController = self.emojiStatusSelectionController {
            self.emojiStatusSelectionController = nil
            emojiStatusSelectionController.dismiss()
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.chatListDisplayNode.mainContainerNode.updateEnableAdjacentFilterLoading(false)
        
        self.dismissAllUndoControllers()
        
        self.featuredFiltersDisposable.set(nil)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.dismissSearchOnDisappear {
            self.dismissSearchOnDisappear = false
            self.deactivateSearch(animated: false)
        }
        
        self.chatListDisplayNode.clearHighlightAnimated(true)
    }
    
    func requestUpdateHeaderContent(transition: ContainedViewLayoutTransition) {
        if let validLayout = self.validLayout {
            self.updateHeaderContent(layout: validLayout, transition: transition)
        }
    }
    
    private func updateHeaderContent(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var primaryContent: ChatListHeaderComponent.Content?
        if let primaryContext = self.primaryContext {
            var backTitle: String?
            if let previousItem = self.navigationBar?.previousItem {
                switch previousItem {
                case let .item(item):
                    backTitle = item.title ?? self.presentationData.strings.Common_Back
                case .close:
                    backTitle = self.presentationData.strings.Common_Close
                }
            }
            var navigationBackTitle: String?
            if case .chatList(.archive) = self.location {
                navigationBackTitle = self.presentationData.strings.Common_Back
            }
            primaryContent = ChatListHeaderComponent.Content(
                title: self.plainTitle,
                navigationBackTitle: navigationBackTitle,
                titleComponent: primaryContext.chatTitleComponent.flatMap { AnyComponent<Empty>($0) },
                chatListTitle: primaryContext.chatListTitle,
                leftButton: primaryContext.leftButton,
                rightButtons: primaryContext.rightButtons,
                backTitle: backTitle,
                backPressed: backTitle != nil ? { [weak self] in
                    guard let self else {
                        return
                    }
                    self.navigationBackPressed()
                } : nil
            )
        }
        var secondaryContent: ChatListHeaderComponent.Content?
        if let secondaryContext = self.secondaryContext {
            secondaryContent = ChatListHeaderComponent.Content(
                title: self.plainTitle,
                navigationBackTitle: nil,
                titleComponent: secondaryContext.chatTitleComponent.flatMap { AnyComponent<Empty>($0) },
                chatListTitle: secondaryContext.chatListTitle,
                leftButton: secondaryContext.leftButton,
                rightButtons: secondaryContext.rightButtons,
                backTitle: nil,
                backPressed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.setInlineChatList(location: nil)
                }
            )
        }
        
        let _ = self.headerContentView.update(
            transition: Transition(transition),
            component: AnyComponent(ChatListHeaderComponent(
                sideInset: layout.safeInsets.left + 16.0,
                primaryContent: primaryContent,
                secondaryContent: secondaryContent,
                secondaryTransition: self.chatListDisplayNode.inlineStackContainerTransitionFraction,
                networkStatus: nil,
                context: self.context,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                openStatusSetup: { [weak self] sourceView in
                    guard let self else {
                        return
                    }
                    self.openStatusSetup(sourceView: sourceView)
                },
                toggleIsLocked: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.context.sharedContext.appLockContext.lock()
                }
            )),
            environment: {},
            containerSize: CGSize(width: layout.size.width, height: 44.0)
        )
        if let componentView = self.headerContentView.view as? NavigationBarHeaderView {
            if self.navigationBar?.customHeaderContentView !== componentView {
                self.navigationBar?.customHeaderContentView = componentView
            }
        }
    }
    
    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        /*if self.chatListDisplayNode.searchDisplayController?.contentNode != nil {
            self.navigationBar?.secondaryContentNodeDisplayFraction = 1.0
        } else {
            self.navigationBar?.secondaryContentNodeDisplayFraction = 1.0 - self.chatListDisplayNode.inlineStackContainerTransitionFraction
        }*/
        
        self.updateHeaderContent(layout: layout, transition: transition)
        
        super.updateNavigationBarLayout(layout, transition: transition)
        
        if let inlineStackContainerNode = self.chatListDisplayNode.inlineStackContainerNode {
            let _ = inlineStackContainerNode
        } else {
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let wasInVoiceOver = self.validLayout?.inVoiceOver ?? false
        
        self.validLayout = layout
        
        self.updateLayout(layout: layout, transition: transition)
        
        if let searchContentNode = self.searchContentNode, layout.inVoiceOver != wasInVoiceOver {
            searchContentNode.updateListVisibleContentOffset(.known(0.0))
            self.chatListDisplayNode.scrollToTop()
        }
    }
    
    private func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var tabContainerOffset: CGFloat = 0.0
        if !self.displayNavigationBar {
            tabContainerOffset += layout.statusBarHeight ?? 0.0
            tabContainerOffset += 44.0 + 20.0
        }
        //tabContainerOffset += self.chatListDisplayNode.inlineStackContainerTransitionFraction * NavigationBar.defaultSecondaryContentHeight

        let navigationBarHeight = self.navigationBar?.frame.maxY ?? 0.0
        
        //transition.updateAlpha(node: self.tabContainerNode, alpha: self.chatListDisplayNode.inlineStackContainerTransitionFraction * 0.5 + (1.0 - self.chatListDisplayNode.inlineStackContainerTransitionFraction) * 1.0)
        //self.tabContainerNode.isUserInteractionEnabled = self.chatListDisplayNode.inlineStackContainerNode == nil
        
        transition.updateFrame(node: self.tabContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight - self.additionalNavigationBarHeight - 46.0 + tabContainerOffset), size: CGSize(width: layout.size.width, height: 46.0)))
        self.tabContainerNode.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: self.tabContainerData?.0 ?? [], selectedFilter: self.chatListDisplayNode.mainContainerNode.currentItemFilter, isReordering: self.chatListDisplayNode.isReorderingFilters || (self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing && !self.chatListDisplayNode.didBeginSelectingChatsWhileEditing), isEditing: self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing, canReorderAllChats: self.isPremium, filtersLimit: self.tabContainerData?.2, transitionFraction: self.chatListDisplayNode.effectiveContainerNode.transitionFraction, presentationData: self.presentationData, transition: .animated(duration: 0.4, curve: .spring))
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, visualNavigationHeight: navigationBarHeight, cleanNavigationBarHeight: self.cleanNavigationHeight, transition: transition)
    }
    
    override public func navigationStackConfigurationUpdated(next: [ViewController]) {
        super.navigationStackConfigurationUpdated(next: next)
    }
    
    @objc fileprivate func editPressed() {
        if self.secondaryContext == nil {
            if case .chatList(.root) = self.chatListDisplayNode.effectiveContainerNode.location {
                self.effectiveContext?.leftButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: self.presentationData.strings.Common_Done, isBold: true),
                    pressed: { [weak self] _ in
                        self?.donePressed()
                    }
                )))
                (self.navigationController as? NavigationController)?.updateMasterDetailsBlackout(.details, transition: .animated(duration: 0.5, curve: .spring))
            } else {
                self.effectiveContext?.rightButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: self.presentationData.strings.Common_Done, isBold: true),
                    pressed: { [weak self] _ in
                        self?.donePressed()
                    }
                )))
                (self.navigationController as? NavigationController)?.updateMasterDetailsBlackout(.master, transition: .animated(duration: 0.5, curve: .spring))
            }
        }
        
        self.requestUpdateHeaderContent(transition: .animated(duration: 0.3, curve: .spring))
        
        self.searchContentNode?.setIsEnabled(false, animated: true)
        
        self.chatListDisplayNode.didBeginSelectingChatsWhileEditing = false
        self.chatListDisplayNode.effectiveContainerNode.updateState { state in
            var state = state
            state.editing = true
            state.peerIdWithRevealedOptions = nil
            return state
        }
        self.chatListDisplayNode.isEditing = true
        if let layout = self.validLayout {
            self.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    @objc fileprivate func donePressed() {
        self.reorderingDonePressed()
        
        (self.navigationController as? NavigationController)?.updateMasterDetailsBlackout(nil, transition: .animated(duration: 0.4, curve: .spring))
        self.searchContentNode?.setIsEnabled(true, animated: true)
        self.chatListDisplayNode.didBeginSelectingChatsWhileEditing = false
        self.chatListDisplayNode.effectiveContainerNode.updateState { state in
            var state = state
            state.editing = false
            state.peerIdWithRevealedOptions = nil
            state.selectedPeerIds.removeAll()
            state.selectedThreadIds.removeAll()
            return state
        }
        self.chatListDisplayNode.isEditing = false
        if let layout = self.validLayout {
            self.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    @objc fileprivate func reorderingDonePressed() {
        guard let defaultFilters = self.tabContainerData else {
            return
        }
        let defaultFilterIds = defaultFilters.0.compactMap { entry -> Int32? in
            switch entry {
            case .all:
                return 0
            case let .filter(id, _, _):
                return id
            }
        }
        
        var reorderedFilterIdsValue: [Int32]?
        if let reorderedFilterIds = self.tabContainerNode.reorderedFilterIds, reorderedFilterIds != defaultFilterIds {
            reorderedFilterIdsValue = reorderedFilterIds
        }
        
        if let reorderedFilterIds = reorderedFilterIdsValue {
            let _ = (self.context.engine.peers.updateChatListFiltersInteractively { stateFilters in
                var updatedFilters: [ChatListFilter] = []
                for id in reorderedFilterIds {
                    if let index = stateFilters.firstIndex(where: { $0.id == id }) {
                        updatedFilters.append(stateFilters[index])
                    }
                }
                updatedFilters.append(contentsOf: stateFilters.compactMap { filter -> ChatListFilter? in
                    if !updatedFilters.contains(where: { $0.id == filter.id }) {
                        return filter
                    } else {
                        return nil
                    }
                })
                return updatedFilters
            }
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reloadFilters(firstUpdate: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatListDisplayNode.isReorderingFilters = false
                    strongSelf.isReorderingTabsValue.set(false)
                    (strongSelf.parent as? TabBarController)?.updateIsTabBarEnabled(true, transition: .animated(duration: 0.2, curve: .easeInOut))
                    strongSelf.searchContentNode?.setIsEnabled(true, animated: true)
                    if let layout = strongSelf.validLayout {
                        strongSelf.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
                    }
                })
            })
        }
    }
    
    public func setInlineChatList(location: ChatListControllerLocation?) {
        if let location {
            let inlineNode = self.chatListDisplayNode.makeInlineChatList(location: location)
            let pendingSecondaryContext = ChatListLocationContext(
                context: self.context,
                location: location,
                parentController: self,
                hideNetworkActivityStatus: false,
                containerNode: inlineNode,
                isReorderingTabs: .single(false)
            )
            self.pendingSecondaryContext = pendingSecondaryContext
            let _ = (pendingSecondaryContext.ready.get()
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self, weak pendingSecondaryContext] _ in
                guard let self, let pendingSecondaryContext = pendingSecondaryContext, self.pendingSecondaryContext === pendingSecondaryContext else {
                    return
                }
                
                if self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing {
                    self.donePressed()
                }
                
                self.secondaryContext = pendingSecondaryContext
                self.setToolbar(pendingSecondaryContext.toolbar, transition: .animated(duration: 0.5, curve: .spring))
                self.chatListDisplayNode.setInlineChatList(inlineStackContainerNode: inlineNode)
                self.updateNavigationMetadata()
            })
        } else {
            if self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.editing {
                self.donePressed()
            }
            
            self.secondaryContext = nil
            self.setToolbar(self.primaryContext?.toolbar, transition: .animated(duration: 0.5, curve: .spring))
            self.chatListDisplayNode.setInlineChatList(inlineStackContainerNode: nil)
            self.updateNavigationMetadata()
        }
    }
    
    private func navigationBackPressed() {
        self.dismiss()
    }
    
    public static func openMoreMenu(context: AccountContext, peerId: EnginePeer.Id, sourceController: ViewController, isViewingAsTopics: Bool, sourceView: UIView, gesture: ContextGesture?) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard case let .channel(channel) = peer else {
                return
            }
            
            let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: strings.Chat_ContextViewAsTopics, icon: { theme in
                if !isViewingAsTopics {
                    return nil
                }
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
            }, action: { [weak sourceController] _, a in
                a(.default)
                
                guard let sourceController = sourceController, let navigationController = sourceController.navigationController as? NavigationController else {
                    return
                }
                
                if let targetController = navigationController.viewControllers.first(where: { controller in
                    var checkController = controller
                    if let tabBarController = checkController as? TabBarController {
                        if let currentController = tabBarController.currentController {
                            checkController = currentController
                        } else {
                            return false
                        }
                    }
                    if let controller = checkController as? ChatListControllerImpl {
                        if controller.chatListDisplayNode.inlineStackContainerNode?.location == .forum(peerId: peerId) {
                            return true
                        }
                    }
                    return false
                }) {
                    let _ = navigationController.popToViewController(targetController, animated: true)
                } else {
                    let chatController = context.sharedContext.makeChatListController(context: context, location: .forum(peerId: peerId), controlsHistoryPreload: false, hideNetworkActivityStatus: false, previewing: false, enableDebugActions: false)
                    navigationController.replaceController(sourceController, with: chatController, animated: false)
                }
            })))
            items.append(.action(ContextMenuActionItem(text: strings.Chat_ContextViewAsMessages, icon: { theme in
                if isViewingAsTopics {
                    return nil
                }
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
            }, action: { [weak sourceController] _, a in
                a(.default)

                guard let sourceController = sourceController, let navigationController = sourceController.navigationController as? NavigationController else {
                    return
                }
                
                let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
                
                if let sourceController = sourceController as? ChatListControllerImpl, case .forum(peerId) = sourceController.location {
                    navigationController.replaceController(sourceController, with: chatController, animated: false)
                } else {
                    navigationController.pushViewController(chatController)
                }
            })))
            items.append(.separator)
            
            items.append(.action(ContextMenuActionItem(text: strings.GroupInfo_Title, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Groups"), color: theme.contextMenu.primaryColor)
            }, action: { [weak sourceController] _, f in
                f(.default)
                
                let _ = (context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> deliverOnMainQueue).start(next: { peer in
                    guard let sourceController = sourceController, let peer = peer, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                        return
                    }
                    (sourceController.navigationController as? NavigationController)?.pushViewController(controller)
                })
            })))
            
            if channel.hasPermission(.inviteMembers) {
                items.append(.action(ContextMenuActionItem(text: strings.GroupInfo_AddParticipant, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
                }, action: { [weak sourceController] _, f in
                    f(.default)
                    
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                             |> deliverOnMainQueue).start(next: { peer in
                        guard let sourceController = sourceController, let peer = peer else {
                            return
                        }
                        let selectAddMemberDisposable = MetaDisposable()
                        let addMemberDisposable = MetaDisposable()
                        context.sharedContext.openAddPeerMembers(context: context, updatedPresentationData: nil, parentController: sourceController, groupPeer: peer._asPeer(), selectAddMemberDisposable: selectAddMemberDisposable, addMemberDisposable: addMemberDisposable)
                    })
                })))
            }
            
            if let sourceController = sourceController as? ChatController {
                items.append(.separator)
                items.append(.action(ContextMenuActionItem(text: strings.Conversation_Search, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.contextMenu.primaryColor)
                }, action: { [weak sourceController] action in
                    action.dismissWithResult(.default)
                    
                    sourceController?.beginMessageSearch("")
                })))
            } else if channel.hasPermission(.createTopics) {
                items.append(.separator)
                
                items.append(.action(ContextMenuActionItem(text: strings.Chat_CreateTopic, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                }, action: { action in
                    action.dismissWithResult(.default)
                    
                    let controller = ForumCreateTopicScreen(context: context, peerId: peerId, mode: .create)
                    controller.navigationPresentation = .modal
                    
                    controller.completion = { [weak controller] title, fileId, _ in
                        controller?.isInProgress = true
                        
                        let _ = (context.engine.peers.createForumChannelTopic(id: peerId, title: title, iconColor: ForumCreateTopicScreen.iconColors.randomElement()!, iconFileId: fileId)
                        |> deliverOnMainQueue).start(next: { topicId in
                            if let navigationController = (sourceController.navigationController as? NavigationController) {
                                let _ = context.sharedContext.navigateToForumThread(context: context, peerId: peerId, threadId: topicId, messageId: nil, navigationController: navigationController, activateInput: .text, keepStack: .never).start()
                            }
                        }, error: { _ in
                            controller?.isInProgress = false
                        })
                    }
                    sourceController.push(controller)
                })))
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: sourceController, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            sourceController.presentInGlobalOverlay(contextController)
        })
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
            strongSelf.isPremium = isPremium ?? false
            
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
            
            var resolvedItems = filterItems
            if case .chatList(.root) = strongSelf.location {
            } else {
                resolvedItems = []
            }
            
            var wasEmpty = false
            if let tabContainerData = strongSelf.tabContainerData {
                wasEmpty = tabContainerData.0.count <= 1 || tabContainerData.1
            } else {
                wasEmpty = true
            }
            
            let firstItem = countAndFilterItems.1.first?.0 ?? .allChats
            let firstItemEntryId: ChatListFilterTabEntryId
            switch firstItem {
                case .allChats:
                    firstItemEntryId = .all
                case let .filter(id, _, _, _):
                    firstItemEntryId = .filter(id)
            }
            
            var selectedEntryId = !strongSelf.initializedFilters ? firstItemEntryId : strongSelf.chatListDisplayNode.mainContainerNode.currentItemFilter
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
            strongSelf.chatListDisplayNode.mainContainerNode.updateAvailableFilters(availableFilters, limit: filtersLimit)
            
            if isPremium == nil && items.isEmpty {
                strongSelf.ready.set(strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.ready)
            } else if !strongSelf.initializedFilters {
                if selectedEntryId != strongSelf.chatListDisplayNode.mainContainerNode.currentItemFilter {
                    strongSelf.chatListDisplayNode.mainContainerNode.switchToFilter(id: selectedEntryId, animated: false, completion: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.ready.set(strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.ready)
                        }
                    })
                } else {
                    strongSelf.ready.set(strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.ready)
                }
                strongSelf.initializedFilters = true
            }
            
            let isEmpty = resolvedItems.count <= 1
            
            let animated = strongSelf.didSetupTabs
            strongSelf.didSetupTabs = true

            if wasEmpty != isEmpty, strongSelf.displayNavigationBar {
                strongSelf.navigationBar?.setSecondaryContentNode(isEmpty ? nil : strongSelf.tabContainerNode, animated: false)
                if let parentController = strongSelf.parent as? TabBarController {
                    parentController.navigationBar?.setSecondaryContentNode(isEmpty ? nil : strongSelf.tabContainerNode, animated: animated)
                }
            }
            
            if let layout = strongSelf.validLayout {
                if wasEmpty != isEmpty {
                    let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
                    strongSelf.containerLayoutUpdated(layout, transition: transition)
                    (strongSelf.parent as? TabBarController)?.updateLayout(transition: transition)
                } else {
                    strongSelf.tabContainerNode.update(size: CGSize(width: layout.size.width, height: 46.0), sideInset: layout.safeInsets.left, filters: resolvedItems, selectedFilter: selectedEntryId, isReordering: strongSelf.chatListDisplayNode.isReorderingFilters || (strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.currentState.editing && !strongSelf.chatListDisplayNode.didBeginSelectingChatsWhileEditing), isEditing: strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.currentState.editing, canReorderAllChats: strongSelf.isPremium, filtersLimit: filtersLimit, transitionFraction: strongSelf.chatListDisplayNode.mainContainerNode.transitionFraction, presentationData: strongSelf.presentationData, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            if !notifiedFirstUpdate {
                notifiedFirstUpdate = true
                firstUpdate?()
            }
            
            if resetCurrentEntry {
                strongSelf.selectTab(id: selectedEntryId)
            }
        }))
    }
    
    private func selectTab(id: ChatListFilterTabEntryId) {
        if self.parent == nil {
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                for controller in navigationController.viewControllers {
                    if let controller = controller as? TabBarController {
                        if let index = controller.controllers.firstIndex(of: self) {
                            controller.selectedIndex = index
                            break
                        }
                    }
                }
            }
        }
        
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
            if strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter?.id == updatedFilter?.id {
                strongSelf.scrollToTop?()
            } else {
                if strongSelf.chatListDisplayNode.inlineStackContainerNode != nil {
                    strongSelf.setInlineChatList(location: nil)
                }
                strongSelf.chatListDisplayNode.mainContainerNode.switchToFilter(id: updatedFilter.flatMap { .filter($0.id) } ?? .all)
            }
        })
    }
    
    private func askForFilterRemoval(id: Int32) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: self.presentationData.strings.ChatList_RemoveFolderConfirmation),
                ActionSheetButtonItem(title: self.presentationData.strings.ChatList_RemoveFolderAction, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let commit: () -> Void = {
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter?.id == id {
                            if strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.currentState.editing {
                                    strongSelf.donePressed()
                            }
                        }
                        
                        let _ = (strongSelf.context.engine.peers.updateChatListFiltersInteractively { filters in
                            return filters.filter({ $0.id != id })
                        }).start()
                    }
                    
                    if strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.chatListFilter?.id == id {
                        strongSelf.chatListDisplayNode.mainContainerNode.switchToFilter(id: .all, completion: {
                            commit()
                        })
                    } else {
                        commit()
                    }
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.present(actionSheet, in: .window(.root))
    }
    
    public private(set) var isSearchActive: Bool = false
    public func activateSearch(filter: ChatListSearchFilter = .chats, query: String? = nil) {
        self.activateSearch(filter: filter, query: query, skipScrolling: false)
    }
        
    private func activateSearch(filter: ChatListSearchFilter = .chats, query: String? = nil, skipScrolling: Bool = false) {
        var filter = filter
        if case .forum = self.chatListDisplayNode.effectiveContainerNode.location {
            filter = .topics
        }
        
        if self.displayNavigationBar {
            if !skipScrolling, let searchContentNode = self.searchContentNode, searchContentNode.expansionProgress != 1.0 {
                self.scrollToTop?()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
                    self?.activateSearch(filter: filter, query: query, skipScrolling: true)
                })
                return
            }
            
            let _ = (combineLatest(self.chatListDisplayNode.mainContainerNode.currentItemNode.contentsReady |> take(1), self.context.account.postbox.tailChatListView(groupId: .root, count: 16, summaryComponents: ChatListEntrySummaryComponents(components: [:])) |> take(1))
            |> deliverOnMainQueue).start(next: { [weak self] _, chatListView in
                guard let strongSelf = self else {
                    return
                }
                
                if let scrollToTop = strongSelf.scrollToTop {
                    scrollToTop()
                }
                
                let tabsIsEmpty: Bool
                if let (resolvedItems, displayTabsAtBottom, _) = strongSelf.tabContainerData {
                    tabsIsEmpty = resolvedItems.count <= 1 || displayTabsAtBottom
                } else {
                    tabsIsEmpty = true
                }
                
                var displaySearchFilters = true
                if chatListView.0.entries.count < 10 {
                    displaySearchFilters = false
                }
                
                if !tabsIsEmpty, let snapshotView = strongSelf.tabContainerNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = strongSelf.tabContainerNode.frame
                    strongSelf.tabContainerNode.view.superview?.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
                
                if let searchContentNode = strongSelf.searchContentNode {                    
                    if let filterContainerNodeAndActivate = strongSelf.chatListDisplayNode.activateSearch(placeholderNode: searchContentNode.placeholderNode, displaySearchFilters: displaySearchFilters, hasDownloads: strongSelf.hasDownloads, initialFilter: filter, navigationController: strongSelf.navigationController as? NavigationController) {
                        let (filterContainerNode, activate) = filterContainerNodeAndActivate
                        if displaySearchFilters {
                            strongSelf.navigationBar?.setSecondaryContentNode(filterContainerNode, animated: false)
                            if let parentController = strongSelf.parent as? TabBarController {
                                parentController.navigationBar?.setSecondaryContentNode(filterContainerNode, animated: true)
                            }
                        }
                        
                        activate(filter != .downloads)
                        
                        if let searchContentNode = strongSelf.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode {
                            searchContentNode.search(filter: filter, query: query)
                        }
                        
                        Queue.mainQueue().justDispatch {
                            filterContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 30.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            filterContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    }
                }
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                strongSelf.setDisplayNavigationBar(false, transition: transition)
                
                (strongSelf.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.4, curve: .spring))
            })
            
            self.isSearchActive = true
            if let navigationController = self.navigationController as? NavigationController {
                for controller in navigationController.globalOverlayControllers {
                    if let controller = controller as? VoiceChatOverlayController {
                        controller.updateVisibility()
                        break
                    }
                }
            }
        } else if self.isSearchActive {
            if let searchContentNode = self.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode {
                searchContentNode.search(filter: filter, query: query)
            }
        }
    }
    
    public func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            var completion: (() -> Void)?
            
            let tabsIsEmpty: Bool
            if let (resolvedItems, displayTabsAtBottom, _) = self.tabContainerData {
                tabsIsEmpty = resolvedItems.count <= 1 || displayTabsAtBottom
            } else {
                tabsIsEmpty = true
            }
            
            
            var filterContainerNode: ASDisplayNode?
            if animated, let searchContentNode = self.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode {
                filterContainerNode = searchContentNode.filterContainerNode
                
                if let filterContainerNode = filterContainerNode, let snapshotView = filterContainerNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = filterContainerNode.frame
                    filterContainerNode.view.superview?.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    
                    if !tabsIsEmpty {
                        Queue.mainQueue().after(0.01) {
                            self.tabContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                            self.tabContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -74.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        }
                    }
                }
            }
            
            if let searchContentNode = self.searchContentNode {
                completion = self.chatListDisplayNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            }
            

            self.navigationBar?.setSecondaryContentNode(tabsIsEmpty ? nil : self.tabContainerNode, animated: false)
            if let parentController = self.parent as? TabBarController {
                parentController.navigationBar?.setSecondaryContentNode(tabsIsEmpty ? nil : self.tabContainerNode, animated: animated)
            }
            
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
            self.setDisplayNavigationBar(true, transition: transition)
            
            completion?()
            
            (self.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.4, curve: .spring))
            
            self.isSearchActive = false
            if let navigationController = self.navigationController as? NavigationController {
                for controller in navigationController.globalOverlayControllers {
                    if let controller = controller as? VoiceChatOverlayController {
                        controller.updateVisibility()
                        break
                    }
                }
            }
        }
    }
    
    public func activateCompose() {
        self.composePressed()
    }
    
    @objc fileprivate func composePressed() {
        guard let navigationController = self.navigationController as? NavigationController else {
            return
        }
        var hasComposeController = false
        navigationController.viewControllers.forEach { controller in
            if controller is ComposeController {
                hasComposeController = true
            }
        }
        
        if !hasComposeController {
            let controller = self.context.sharedContext.makeComposeController(context: self.context)
            navigationController.pushViewController(controller)
        }
    }
    
    public override var keyShortcuts: [KeyShortcut] {
        let strings = self.presentationData.strings
        
        let toggleSearch: () -> Void = { [weak self] in
            if let strongSelf = self {
                if strongSelf.displayNavigationBar {
                    strongSelf.activateSearch()
                } else {
                    strongSelf.deactivateSearch(animated: true)
                }
            }
        }
        
        let inputShortcuts: [KeyShortcut] = [
            KeyShortcut(title: strings.KeyCommand_JumpToPreviousChat, input: UIKeyCommand.inputUpArrow, modifiers: [.alternate], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.previous(unread: false))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToNextChat, input: UIKeyCommand.inputDownArrow, modifiers: [.alternate], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.next(unread: false))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToPreviousUnreadChat, input: UIKeyCommand.inputUpArrow, modifiers: [.alternate, .shift], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.previous(unread: true))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToNextUnreadChat, input: UIKeyCommand.inputDownArrow, modifiers: [.alternate, .shift], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.next(unread: true))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_NewMessage, input: "N", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.composePressed()
                }
            }),
            KeyShortcut(title: strings.KeyCommand_LockWithPasscode, input: "L", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.context.sharedContext.appLockContext.lock()
                }
            }),
            KeyShortcut(title: strings.KeyCommand_Find, input: "\t", modifiers: [], action: toggleSearch),
            KeyShortcut(input: UIKeyCommand.inputEscape, modifiers: [], action: toggleSearch)
        ]
        
        let openTab: (Int) -> Void = { [weak self] index in
            if let strongSelf = self {
                let filters = strongSelf.chatListDisplayNode.mainContainerNode.availableFilters
                if index > filters.count - 1 {
                    return
                }
                switch filters[index] {
                    case .all:
                        strongSelf.selectTab(id: .all)
                    case let .filter(filter):
                        strongSelf.selectTab(id: .filter(filter.id))
                }
            }
        }
        
        let openChat: (Int) -> Void = { [weak self] index in
            if let strongSelf = self {
                if index == 0 {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.peerId(strongSelf.context.account.peerId))
                } else {
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.selectChat(.index(index - 1))
                }
            }
        }
        
        let folderShortcuts: [KeyShortcut] = (0 ... 9).map { index in
            return KeyShortcut(input: "\(index)", modifiers: [.command], action: {
                if index == 0 {
                    openChat(0)
                } else {
                    openTab(index - 1)
                }
            })
        }
        
        let chatShortcuts: [KeyShortcut] = (0 ... 9).map { index in
            return KeyShortcut(input: "\(index)", modifiers: [.command, .alternate], action: {
                openChat(index)
            })
        }
        
        return inputShortcuts + folderShortcuts + chatShortcuts
    }
    
    override public func toolbarActionSelected(action: ToolbarActionOption) {
        let peerIds = self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.selectedPeerIds
        let threadIds = self.chatListDisplayNode.effectiveContainerNode.currentItemNode.currentState.selectedThreadIds
        if case .left = action {
            let signal: Signal<Never, NoError>
            var completion: (() -> Void)?
            if !threadIds.isEmpty, case let .forum(peerId) = self.chatListDisplayNode.effectiveContainerNode.location {
                self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadIds.first!))
                completion = { [weak self] in
                    self?.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                }
                signal = self.context.engine.messages.markForumThreadsAsRead(peerId: peerId, threadIds: Array(threadIds))
            } else if !peerIds.isEmpty {
                self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds.first!, threadId: nil))
                completion = { [weak self] in
                    self?.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                }
                signal = self.context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: Array(peerIds), setToValue: false)
            } else if case let .chatList(groupId) = self.chatListDisplayNode.effectiveContainerNode.location {
                let filterPredicate: ChatListFilterPredicate?
                if let filter = self.chatListDisplayNode.effectiveContainerNode.currentItemNode.chatListFilter, case let .filter(_, _, _, data) = filter {
                    filterPredicate = chatListFilterPredicate(filter: data)
                } else {
                    filterPredicate = nil
                }
                var markItems: [(groupId: EngineChatList.Group, filterPredicate: ChatListFilterPredicate?)] = []
                markItems.append((groupId, filterPredicate))
                if let filterPredicate = filterPredicate {
                    for additionalGroupId in filterPredicate.includeAdditionalPeerGroupIds {
                        markItems.append((EngineChatList.Group(additionalGroupId), filterPredicate))
                    }
                }
                signal = self.context.engine.messages.markAllChatsAsReadInteractively(items: markItems)
            } else {
                signal = .complete()
            }
            let _ = (signal
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?.donePressed()
                completion?()
            })
        } else if case .right = action {
            if !threadIds.isEmpty, case let .forum(peerId) = self.chatListDisplayNode.effectiveContainerNode.location {
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteThreadsConfirmation(Int32(threadIds.count)), color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadIds.first))
                    strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                        var state = state
                        for threadId in threadIds {
                            state.pendingRemovalItemIds.insert(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                        }
                        return state
                    })
                    
                    let text = strongSelf.presentationData.strings.ChatList_DeletedThreads(Int32(threadIds.count))
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: text), elevatedLayout: false, animateInAsReplacement: true, action: { value in
                        guard let strongSelf = self else {
                            return false
                        }
                        if value == .commit {
                            let presentationData = strongSelf.presentationData
                            let progressSignal = Signal<Never, NoError> { subscriber in
                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                                self?.present(controller, in: .window(.root))
                                return ActionDisposable { [weak controller] in
                                    Queue.mainQueue().async() {
                                        controller?.dismiss()
                                    }
                                }
                            }
                            |> runOn(Queue.mainQueue())
                            |> delay(0.8, queue: Queue.mainQueue())
                            let progressDisposable = progressSignal.start()
                            
                            let signal: Signal<Never, NoError> = strongSelf.context.engine.peers.removeForumChannelThreads(id: peerId, threadIds: Array(threadIds))
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    progressDisposable.dispose()
                                }
                            }
                            let _ = (signal
                            |> deliverOnMainQueue).start()
                            
                            strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                                var state = state
                                for threadId in threadIds {
                                    state.selectedThreadIds.remove(threadId)
                                }
                                return state
                            })
                            
                            return true
                        } else if value == .undo {
                            strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadIds.first))
                            strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                                var state = state
                                for threadId in threadIds {
                                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                                }
                                return state
                            })
                            self?.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadIds.first))
                            return true
                        }
                        return false
                    }), in: .current)
                    
                    strongSelf.donePressed()
                }))
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                self.present(actionSheet, in: .window(.root))
            } else if !peerIds.isEmpty {
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteConfirmation(Int32(peerIds.count)), color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                        var state = state
                        for peerId in peerIds {
                            state.pendingRemovalItemIds.insert(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
                        }
                        return state
                    })
                    
                    let text = strongSelf.presentationData.strings.ChatList_DeletedChats(Int32(peerIds.count))
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: text), elevatedLayout: false, animateInAsReplacement: true, action: { value in
                        guard let strongSelf = self else {
                            return false
                        }
                        if value == .commit {
                            let presentationData = strongSelf.presentationData
                            let progressSignal = Signal<Never, NoError> { subscriber in
                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                                self?.present(controller, in: .window(.root))
                                return ActionDisposable { [weak controller] in
                                    Queue.mainQueue().async() {
                                        controller?.dismiss()
                                    }
                                }
                            }
                            |> runOn(Queue.mainQueue())
                            |> delay(0.8, queue: Queue.mainQueue())
                            let progressDisposable = progressSignal.start()
                            
                            let signal: Signal<Never, NoError> = strongSelf.context.engine.peers.removePeerChats(peerIds: Array(peerIds))
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    progressDisposable.dispose()
                                }
                            }
                            let _ = (signal
                            |> deliverOnMainQueue).start()
                            
                            strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                                var state = state
                                for peerId in peerIds {
                                    state.selectedPeerIds.remove(peerId)
                                }
                                return state
                            })
                            
                            return true
                        } else if value == .undo {
                            strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds.first!, threadId: nil))
                            strongSelf.chatListDisplayNode.effectiveContainerNode.updateState(onlyCurrent: false, { state in
                                var state = state
                                for peerId in peerIds {
                                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
                                }
                                return state
                            })
                            self?.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds.first!, threadId: nil))
                            return true
                        }
                        return false
                    }), in: .current)
                    
                    strongSelf.donePressed()
                }))
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                self.present(actionSheet, in: .window(.root))
            }
        } else if case .middle = action {
            switch self.chatListDisplayNode.effectiveContainerNode.location {
            case let .chatList(groupId):
                if !peerIds.isEmpty {
                    if groupId == .root {
                        self.donePressed()
                        self.archiveChats(peerIds: Array(peerIds))
                    } else {
                        if !peerIds.isEmpty {
                            self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds.first!, threadId: nil))
                            let _ = (self.context.engine.peers.updatePeersGroupIdInteractively(peerIds: Array(peerIds), groupId: .root)
                                     |> deliverOnMainQueue).start(completed: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                                strongSelf.donePressed()
                            })
                        }
                    }
                }
            case let .forum(peerId):
                self.joinForumDisposable.set((self.context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peerId, hash: nil)
                |> afterDisposed { [weak self] in
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            let _ = strongSelf
                            /*strongSelf.activityIndicator.isHidden = true
                            strongSelf.activityIndicator.stopAnimating()
                            strongSelf.isJoining = false*/
                        }
                    }
                }).start(error: { [weak self] error in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let strongSelf = self, let peer = peer else {
                            return
                        }
                        
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        
                        let text: String
                        switch error {
                        case .inviteRequestSent:
                            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.Group_RequestToJoinSent, text: presentationData.strings.Group_RequestToJoinSentDescriptionGroup ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            return
                        case .tooMuchJoined:
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(oldChannelsController(context: strongSelf.context, intent: .join, completed: { value in
                                if value {
                                    self?.toolbarActionSelected(action: .middle)
                                }
                            }))
                            return
                        case .tooMuchUsers:
                            text = presentationData.strings.Conversation_UsersTooMuchError
                        case .generic:
                            if case let .channel(channel) = peer, case .broadcast = channel.info {
                                text = presentationData.strings.Channel_ErrorAccessDenied
                            } else {
                                text = presentationData.strings.Group_ErrorAccessDenied
                            }
                        }
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    })
                }))
            }
        }
    }
    
    func toggleArchivedFolderHiddenByDefault() {
        var updatedValue = false
        let _ = (updateChatArchiveSettings(engine: self.context.engine, { settings in
            var settings = settings
            settings.isHiddenByDefault = !settings.isHiddenByDefault
            updatedValue = settings.isHiddenByDefault
            return settings
        })
        |> deliverOnMainQueue).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatListDisplayNode.mainContainerNode.updateState { state in
                var state = state
                if updatedValue {
                    state.hiddenItemShouldBeTemporaryRevealed = false
                }
                state.peerIdWithRevealedOptions = nil
                return state
            }
            strongSelf.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitActionAndReplacementAnimation()
                }
                return true
            })
            
            if updatedValue {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .hidArchive(title: strongSelf.presentationData.strings.ChatList_UndoArchiveHiddenTitle, text: strongSelf.presentationData.strings.ChatList_UndoArchiveHiddenText, undo: false), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                    guard let strongSelf = self else {
                        return false
                    }
                    if value == .undo {
                        let _ = updateChatArchiveSettings(engine: strongSelf.context.engine, { settings in
                            var settings = settings
                            settings.isHiddenByDefault = false
                            return settings
                        }).start()
                        
                        return true
                    }
                    return false
                }), in: .current)
            } else {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .revealedArchive(title: strongSelf.presentationData.strings.ChatList_UndoArchiveRevealedTitle, text: strongSelf.presentationData.strings.ChatList_UndoArchiveRevealedText, undo: false), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false
                }), in: .current)
            }
        })
    }
    
    func hidePsa(_ id: PeerId) {
        self.chatListDisplayNode.mainContainerNode.updateState { state in
            var state = state
            state.hiddenPsaPeerId = id
            state.peerIdWithRevealedOptions = nil
            return state
        }
        
        let _ = hideAccountPromoInfoChat(account: self.context.account, peerId: id).start()
    }
    
    func deletePeerChat(peerId: PeerId, joined: Bool) {
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: peerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer, let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
                return
            }
            strongSelf.view.window?.endEditing(true)
            
            var canRemoveGlobally = false
            let limitsConfiguration = strongSelf.context.currentLimitsConfiguration.with { $0 }
            if peer.peerId.namespace == Namespaces.Peer.CloudUser && peer.peerId != strongSelf.context.account.peerId {
                if limitsConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                    canRemoveGlobally = true
                }
            } else if peer.peerId.namespace == Namespaces.Peer.SecretChat {
                canRemoveGlobally = true
            }
            
            if case let .user(user) = chatPeer, user.botInfo == nil, canRemoveGlobally {
                strongSelf.maybeAskForPeerChatRemoval(peer: peer, joined: joined, completion: { _ in }, removed: {})
            } else {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []
                var canClear = true
                var canStop = false
                var canRemoveGlobally = false
                
                var deleteTitle = strongSelf.presentationData.strings.Common_Delete
                if case let .channel(channel) = chatPeer {
                    if case .broadcast = channel.info {
                        canClear = false
                        deleteTitle = strongSelf.presentationData.strings.Channel_LeaveChannel
                        if channel.flags.contains(.isCreator) {
                            canRemoveGlobally = true
                        }
                    } else {
                        deleteTitle = strongSelf.presentationData.strings.Group_DeleteGroup
                        if channel.flags.contains(.isCreator) {
                            canRemoveGlobally = true
                        }
                    }
                    if let addressName = channel.addressName, !addressName.isEmpty {
                        canClear = false
                    }
                } else if case let .legacyGroup(group) = chatPeer {
                    if case .creator = group.role {
                        canRemoveGlobally = true
                    }
                } else if case let .user(user) = chatPeer, user.botInfo != nil {
                    canStop = !user.flags.contains(.isSupport)
                    canClear = user.botInfo == nil
                    deleteTitle = strongSelf.presentationData.strings.ChatList_DeleteChat
                } else if case .secretChat = chatPeer {
                    canClear = true
                    deleteTitle = strongSelf.presentationData.strings.ChatList_DeleteChat
                }
                
                let limitsConfiguration = strongSelf.context.currentLimitsConfiguration.with { $0 }
                if case .user = chatPeer, chatPeer.id != strongSelf.context.account.peerId {
                    if limitsConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                        canRemoveGlobally = true
                    }
                } else if case .secretChat = chatPeer {
                    canRemoveGlobally = true
                }
                
                var isGroupOrChannel = false
                switch mainPeer {
                case .legacyGroup, .channel:
                    isGroupOrChannel = true
                default:
                    break
                }
                
                if canRemoveGlobally && isGroupOrChannel {
                    items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: mainPeer, chatPeer: chatPeer, action: .deleteAndLeave, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.schedulePeerChatRemoval(peer: peer, type: .forLocalPeer, deleteGloballyIfPossible: false, completion: {
                        })
                    }))
                    
                    let deleteForAllText: String
                    if case let .channel(channel) = mainPeer, case .broadcast = channel.info {
                        deleteForAllText = strongSelf.presentationData.strings.ChatList_DeleteForAllSubscribers
                    } else {
                        deleteForAllText = strongSelf.presentationData.strings.ChatList_DeleteForAllMembers
                    }
                    
                    items.append(ActionSheetButtonItem(title: deleteForAllText, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let deleteForAllConfirmation: String
                        if case let .channel(channel) = mainPeer, case .broadcast = channel.info {
                            deleteForAllConfirmation = strongSelf.presentationData.strings.ChannelInfo_DeleteChannelConfirmation
                        } else {
                            deleteForAllConfirmation = strongSelf.presentationData.strings.ChannelInfo_DeleteGroupConfirmation
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: deleteForAllConfirmation, actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                            }),
                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                self?.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: true, completion: {
                                })
                            })
                        ], parseMarkdown: true), in: .window(.root))
                    }))
                } else {
                    items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: mainPeer, chatPeer: chatPeer, action: .delete, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                    
                    if canClear {
                        let beginClear: (InteractiveHistoryClearingType) -> Void = { type in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                                var state = state
                                state.pendingClearHistoryPeerIds.insert(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
                                return state
                            })
                            strongSelf.forEachController({ controller in
                                if let controller = controller as? UndoOverlayController {
                                    controller.dismissWithCommitActionAndReplacementAnimation()
                                }
                                return true
                            })
                            
                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: strongSelf.presentationData.strings.Undo_ChatCleared), elevatedLayout: false, animateInAsReplacement: true, action: { value in
                                guard let strongSelf = self else {
                                    return false
                                }
                                if value == .commit {
                                    let _ = strongSelf.context.engine.messages.clearHistoryInteractively(peerId: peerId, threadId: nil, type: type).start(completed: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                                            var state = state
                                            state.pendingClearHistoryPeerIds.remove(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
                                            return state
                                        })
                                    })
                                    return true
                                } else if value == .undo {
                                    strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                                        var state = state
                                        state.pendingClearHistoryPeerIds.remove(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
                                        return state
                                    })
                                    return true
                                }
                                return false
                            }), in: .current)
                        }
                        
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_ClearHistoryConfirmation, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if case .secretChat = chatPeer {
                                beginClear(.forEveryone)
                            } else {
                                if canRemoveGlobally {
                                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                                    var items: [ActionSheetItem] = []
                                                                
                                    items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: mainPeer, chatPeer: chatPeer, action: .clearHistory(canClearCache: false), strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                                    
                                    if joined || mainPeer.isDeleted {
                                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                                            beginClear(.forEveryone)
                                            actionSheet?.dismissAnimated()
                                        }))
                                    } else {
                                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser, color: .destructive, action: { [weak actionSheet] in
                                            beginClear(.forLocalPeer)
                                            actionSheet?.dismissAnimated()
                                        }))
                                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ChatList_DeleteForEveryone(mainPeer.compactDisplayTitle).string, color: .destructive, action: { [weak actionSheet] in
                                            beginClear(.forEveryone)
                                            actionSheet?.dismissAnimated()
                                        }))
                                    }
                                    
                                    actionSheet.setItemGroups([
                                        ActionSheetItemGroup(items: items),
                                        ActionSheetItemGroup(items: [
                                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                                actionSheet?.dismissAnimated()
                                            })
                                        ])
                                    ])
                                    strongSelf.present(actionSheet, in: .window(.root))
                                } else {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                        }),
                                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                            beginClear(.forLocalPeer)
                                        })
                                    ], parseMarkdown: true), in: .window(.root))
                                }
                            }
                        }))
                    }
                    
                    if case .secretChat = chatPeer {
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ChatList_DeleteForEveryone(mainPeer.compactDisplayTitle).string, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: true, completion: {
                            })
                        }))
                    } else {
                        items.append(ActionSheetButtonItem(title: deleteTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let strongSelf = self else {
                                return
                            }
                            
                            var isGroupOrChannel = false
                            switch mainPeer {
                            case .legacyGroup, .channel:
                                isGroupOrChannel = true
                            default:
                                break
                            }
                            
                            if canRemoveGlobally && isGroupOrChannel {
                                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                                var items: [ActionSheetItem] = []
                                
                                items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: mainPeer, chatPeer: chatPeer, action: .deleteAndLeave, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                                
                                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    self?.schedulePeerChatRemoval(peer: peer, type: .forLocalPeer, deleteGloballyIfPossible: false, completion: {
                                    })
                                }))
                                
                                let deleteForAllText: String
                                if case let .channel(channel) = mainPeer, case .broadcast = channel.info {
                                    deleteForAllText = strongSelf.presentationData.strings.ChatList_DeleteForAllSubscribers
                                } else {
                                    deleteForAllText = strongSelf.presentationData.strings.ChatList_DeleteForAllMembers
                                }
                                
                                items.append(ActionSheetButtonItem(title: deleteForAllText, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let deleteForAllConfirmation: String
                                    if case let .channel(channel) = mainPeer, case .broadcast = channel.info {
                                        deleteForAllConfirmation = strongSelf.presentationData.strings.ChatList_DeleteForAllSubscribersConfirmationText
                                    } else {
                                        deleteForAllConfirmation = strongSelf.presentationData.strings.ChatList_DeleteForAllMembersConfirmationText
                                    }
                                    
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: deleteForAllConfirmation, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                        }),
                                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                            self?.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: true, completion: {
                                            })
                                        })
                                    ], parseMarkdown: true), in: .window(.root))
                                }))
                                    
                                actionSheet.setItemGroups([
                                    ActionSheetItemGroup(items: items),
                                    ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                        })
                                    ])
                                ])
                                strongSelf.present(actionSheet, in: .window(.root))
                            } else {
                                strongSelf.maybeAskForPeerChatRemoval(peer: peer, completion: { _ in }, removed: {})
                            }
                        }))
                    }
                }
                
                if canStop {
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_DeleteBotConversationConfirmation, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        if let strongSelf = self {
                            strongSelf.maybeAskForPeerChatRemoval(peer: peer, completion: { _ in
                            }, removed: {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.peerId, isBlocked: true).start()
                            })
                        }
                    }))
                }
                
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        })
    }
    
    func deletePeerThread(peerId: EnginePeer.Id, threadId: Int64) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        items.append(ActionSheetTextItem(title: self.presentationData.strings.ChatList_DeleteTopicConfirmationText, parseMarkdown: true))
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteTopicConfirmationAction, color: .destructive, action: { [weak self, weak actionSheet] in
            actionSheet?.dismissAnimated()
            self?.commitDeletePeerThread(peerId: peerId, threadId: threadId, completion: {})
        }))
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.present(actionSheet, in: .window(.root))
    }
    
    func selectPeerThread(peerId: EnginePeer.Id, threadId: Int64) {
        self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
            var state = state
            state.selectedThreadIds.insert(threadId)
            return state
        })
        self.chatListDisplayNode.effectiveContainerNode.didBeginSelectingChats?()
    }
    
    private func commitDeletePeerThread(peerId: EnginePeer.Id, threadId: Int64, completion: @escaping () -> Void) {
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitActionAndReplacementAnimation()
            }
            return true
        })
        
        self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
        self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
            var state = state
            state.pendingRemovalItemIds.insert(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
            return state
        })
        
        let statusText = self.presentationData.strings.Undo_DeletedTopic
        
        self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: statusText), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
            guard let self else {
                return false
            }
            if value == .commit {
                self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                
                let _ = self.context.engine.peers.removeForumChannelThread(id: peerId, threadId: threadId).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                        var state = state
                        state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                        return state
                    })
                    self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                })
                
                self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                    var state = state
                    state.selectedThreadIds.remove(threadId)
                    return state
                })
                
                completion()
                return true
            } else if value == .undo {
                self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                    var state = state
                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
                    return state
                })
                self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                return true
            }
            return false
        }), in: .current)
    }
    
    private func setPeerThreadStopped(peerId: EnginePeer.Id, threadId: Int64, isStopped: Bool) {
        self.actionDisposables.add(self.context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: isStopped).start())
    }
    
    private func setPeerThreadPinned(peerId: EnginePeer.Id, threadId: Int64, isPinned: Bool) {
        self.actionDisposables.add(self.context.engine.peers.toggleForumChannelTopicPinned(id: peerId, threadId: threadId).start())
    }
    
    private func setPeerThreadHidden(peerId: EnginePeer.Id, threadId: Int64, isHidden: Bool) {
        self.actionDisposables.add((self.context.engine.peers.setForumChannelTopicHidden(id: peerId, threadId: threadId, isHidden: isHidden)
        |> deliverOnMainQueue).start(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.chatListDisplayNode.effectiveContainerNode.updateState { state in
                    var state = state
                    state.hiddenItemShouldBeTemporaryRevealed = false
                    return state
                }
                
                if isHidden {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .hidArchive(title: strongSelf.presentationData.strings.ChatList_GeneralHidden, text: strongSelf.presentationData.strings.ChatList_GeneralHiddenInfo, undo: false), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                        guard let strongSelf = self else {
                            return false
                        }
                        if value == .undo {
                            strongSelf.setPeerThreadHidden(peerId: peerId, threadId: threadId, isHidden: false)
                            return true
                        }
                        return false
                    }), in: .current)
                } else {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .revealedArchive(title: strongSelf.presentationData.strings.ChatList_GeneralUnhidden, text: strongSelf.presentationData.strings.ChatList_GeneralUnhiddenInfo, undo: false), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false
                    }), in: .current)
                }
            }
        }))
    }
    
    public func maybeAskForPeerChatRemoval(peer: EngineRenderedPeer, joined: Bool = false, deleteGloballyIfPossible: Bool = false, completion: @escaping (Bool) -> Void, removed: @escaping () -> Void) {
        guard let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
            completion(false)
            return
        }
        var canRemoveGlobally = false
        let limitsConfiguration = self.context.currentLimitsConfiguration.with { $0 }
        if peer.peerId.namespace == Namespaces.Peer.CloudUser && peer.peerId != self.context.account.peerId {
            if limitsConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                canRemoveGlobally = true
            }
        }
        if case let .user(user) = chatPeer, user.botInfo != nil {
            canRemoveGlobally = false
        }
        if case .secretChat = chatPeer {
            canRemoveGlobally = true
        }
        
        if canRemoveGlobally {
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            var items: [ActionSheetItem] = []
            
            items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: mainPeer, chatPeer: chatPeer, action: .delete, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder))
            
            if joined || mainPeer.isDeleted {
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.Common_Delete, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: {
                        removed()
                    })
                    completion(true)
                }))
            } else {
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteForCurrentUser, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.schedulePeerChatRemoval(peer: peer, type: .forLocalPeer, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: {
                        removed()
                    })
                    completion(true)
                }))
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteForEveryone(mainPeer.compactDisplayTitle).string, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationText, actions: [
                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                            completion(false)
                        }),
                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                            self?.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: {
                                removed()
                            })
                            completion(true)
                        })
                    ], parseMarkdown: true), in: .window(.root))
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        completion(false)
                    })
                ])
            ])
            self.present(actionSheet, in: .window(.root))
        } else if peer.peerId == self.context.account.peerId {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: self.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: self.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                    completion(false)
                }),
                TextAlertAction(type: .destructiveAction, title: self.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: { [weak self] in
                    self?.schedulePeerChatRemoval(peer: peer, type: .forEveryone, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: {
                        removed()
                    })
                    completion(true)
                })
            ], parseMarkdown: true), in: .window(.root))
        } else {
            completion(true)
            self.schedulePeerChatRemoval(peer: peer, type: .forLocalPeer, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: {
                removed()
            })
        }
    }
    
    func archiveChats(peerIds: [PeerId]) {
        guard !peerIds.isEmpty else {
            return
        }
        let engine = self.context.engine
        self.chatListDisplayNode.mainContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds[0], threadId: nil))
        let _ = (ApplicationSpecificNotice.incrementArchiveChatTips(accountManager: self.context.sharedContext.accountManager, count: 1)
        |> deliverOnMainQueue).start(next: { [weak self] previousHintCount in
            let _ = (engine.peers.updatePeersGroupIdInteractively(peerIds: peerIds, groupId: .archive)
            |> deliverOnMainQueue).start(completed: {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatListDisplayNode.mainContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
        
                for peerId in peerIds {
                    deleteSendMessageIntents(peerId: peerId)
                }
                
                let action: (UndoOverlayAction) -> Bool = { value in
                    guard let strongSelf = self else {
                        return false
                    }
                    if value == .undo {
                        strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerIds[0], threadId: nil))
                        let _ = (engine.peers.updatePeersGroupIdInteractively(peerIds: peerIds, groupId: .root)
                        |> deliverOnMainQueue).start(completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                        })
                        return true
                    } else {
                        return false
                    }
                }
        
                strongSelf.forEachController({ controller in
                    if let controller = controller as? UndoOverlayController {
                        controller.dismissWithCommitActionAndReplacementAnimation()
                    }
                    return true
                })
        
                var title = peerIds.count == 1 ? strongSelf.presentationData.strings.ChatList_UndoArchiveTitle : strongSelf.presentationData.strings.ChatList_UndoArchiveMultipleTitle
                let text: String
                let undo: Bool
                switch previousHintCount {
                    case 0:
                        text = strongSelf.presentationData.strings.ChatList_UndoArchiveText1
                        undo = false
                    default:
                        text = title
                        title = ""
                        undo = true
                }
                let controller = UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .archivedChat(peerId: peerIds[0].toInt64(), title: title, text: text, undo: undo), elevatedLayout: false, animateInAsReplacement: true, action: action)
                strongSelf.present(controller, in: .current)
                
                strongSelf.chatListDisplayNode.playArchiveAnimation()
            })
        })
    }
    
    private func schedulePeerChatRemoval(peer: EngineRenderedPeer, type: InteractiveMessagesDeletionType, deleteGloballyIfPossible: Bool, completion: @escaping () -> Void) {
        guard let chatPeer = peer.peers[peer.peerId] else {
            return
        }
        
        var deleteGloballyIfPossible = deleteGloballyIfPossible
        if case .forEveryone = type {
            deleteGloballyIfPossible = true
        }
        
        let peerId = peer.peerId
        self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
        self.chatListDisplayNode.effectiveContainerNode.updateState({ state in
            var state = state
            state.pendingRemovalItemIds.insert(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
            return state
        })
        self.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
        let statusText: String
        if case let .channel(channel) = chatPeer {
            if deleteGloballyIfPossible {
                if case .broadcast = channel.info {
                    statusText = self.presentationData.strings.Undo_DeletedChannel
                } else {
                    statusText = self.presentationData.strings.Undo_DeletedGroup
                }
            } else {
                if case .broadcast = channel.info {
                    statusText = self.presentationData.strings.Undo_LeftChannel
                } else {
                    statusText = self.presentationData.strings.Undo_LeftGroup
                }
            }
        } else if case .legacyGroup = chatPeer {
            if deleteGloballyIfPossible {
                statusText = self.presentationData.strings.Undo_DeletedGroup
            } else {
                statusText = self.presentationData.strings.Undo_LeftGroup
            }
        } else if case .secretChat = chatPeer {
            statusText = self.presentationData.strings.Undo_SecretChatDeleted
        } else {
            if case .forEveryone = type {
                statusText = self.presentationData.strings.Undo_ChatDeletedForBothSides
            } else {
                statusText = self.presentationData.strings.Undo_ChatDeleted
            }
        }
        
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitActionAndReplacementAnimation()
            }
            return true
        })
        
        self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: statusText), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
            guard let strongSelf = self else {
                return false
            }
            if value == .commit {
                strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
                if case let .channel(channel) = chatPeer {
                    strongSelf.context.peerChannelMemberCategoriesContextsManager.externallyRemoved(peerId: channel.id, memberId: strongSelf.context.account.peerId)
                }
                let _ = strongSelf.context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: deleteGloballyIfPossible).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                        var state = state
                        state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
                        return state
                    })
                    strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                    
                    deleteSendMessageIntents(peerId: peerId)
                })
                
                strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                    var state = state
                    state.selectedPeerIds.remove(peerId)
                    return state
                })
                
                completion()
                return true
            } else if value == .undo {
                strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
                strongSelf.chatListDisplayNode.effectiveContainerNode.updateState({ state in
                    var state = state
                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peer.peerId, threadId: nil))
                    return state
                })
                strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.setCurrentRemovingItemId(nil)
                return true
            }
            return false
        }), in: .current)
    }
    
    override public func setToolbar(_ toolbar: Toolbar?, transition: ContainedViewLayoutTransition) {
        if case .chatList(.root) = self.chatListDisplayNode.mainContainerNode.location {
            super.setToolbar(toolbar, transition: transition)
        } else {
            self.chatListDisplayNode.toolbar = toolbar
            self.requestLayout(transition: transition)
        }
    }
    
    public var lockViewFrame: CGRect? {
        if let titleView = self.findTitleView(), let lockViewFrame = titleView.lockViewFrame {
            return titleView.convert(lockViewFrame, to: self.view)
        } else {
            return nil
        }
    }
    
    private func openFilterSettings() {
        self.chatListDisplayNode.mainContainerNode.updateEnableAdjacentFilterLoading(false)
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(chatListFilterPresetListController(context: self.context, mode: .modal, dismissed: { [weak self] in
                self?.chatListDisplayNode.mainContainerNode.updateEnableAdjacentFilterLoading(true)
            }))
        }
    }
    
    override public func tabBarDisabledAction() {
        self.donePressed()
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        let _ = (combineLatest(queue: .mainQueue(),
            self.context.engine.peers.currentChatListFilters(),
            chatListFilterItems(context: self.context)
            |> take(1),
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            )
        )
        |> deliverOnMainQueue).start(next: { [weak self] presetList, filterItemsAndTotalCount, result in
            guard let strongSelf = self else {
                return
            }
            
            let (accountPeer, limits, _) = result
            let isPremium = accountPeer?.isPremium ?? false
            
            
            let _ = strongSelf.context.engine.peers.markChatListFeaturedFiltersAsSeen().start()
            let (_, filterItems) = filterItemsAndTotalCount
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presetList.isEmpty ? strongSelf.presentationData.strings.ChatList_AddFolder : strongSelf.presentationData.strings.ChatList_EditFolders, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: presetList.isEmpty ? "Chat/Context Menu/Add" : "Chat/Context Menu/ItemList"), color: theme.contextMenu.primaryColor)
            }, action: { c, f in
                c.dismiss(completion: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.openFilterSettings()
                })
            })))
            
            if strongSelf.chatListDisplayNode.effectiveContainerNode.currentItemNode.chatListFilter != nil {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChatList_FolderAllChats, icon: { theme in
                    return nil
                }, action: { c, f in
                    f(.dismissWithoutContent)
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.selectTab(id: .all)
                })))
            }
            
            if !presetList.isEmpty {
                if presetList.count > 1 {
                    items.append(.separator)
                }
                var filterCount = 0
                for case let .filter(id, title, _, data) in presetList {
                    let filterType = chatListFilterType(data)
                    var badge: ContextMenuActionBadge?
                    var isDisabled = false
                    if !isPremium && filterCount >= limits.maxFoldersCount {
                        isDisabled = true
                    }
                    
                    for item in filterItems {
                        if item.0.id == id && item.1 != 0 {
                            badge = ContextMenuActionBadge(value: "\(item.1)", color: item.2 ? .accent : .inactive)
                        }
                    }
                    items.append(.action(ContextMenuActionItem(text: title, badge: badge, icon: { theme in
                        let imageName: String
                        if isDisabled {
                            imageName = "Chat/Context Menu/Lock"
                        } else {
                            switch filterType {
                            case .generic:
                                imageName = "Chat/Context Menu/List"
                            case .unmuted:
                                imageName = "Chat/Context Menu/Unmute"
                            case .unread:
                                imageName = "Chat/Context Menu/MarkAsUnread"
                            case .channels:
                                imageName = "Chat/Context Menu/Channels"
                            case .groups:
                                imageName = "Chat/Context Menu/Groups"
                            case .bots:
                                imageName = "Chat/Context Menu/Bots"
                            case .contacts:
                                imageName = "Chat/Context Menu/User"
                            case .nonContacts:
                                imageName = "Chat/Context Menu/UnknownUser"
                            }
                        }
                        return generateTintedImage(image: UIImage(bundleImageName: imageName), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        guard let strongSelf = self else {
                            return
                        }
                        if isDisabled {
                            let context = strongSelf.context
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumLimitScreen(context: context, subject: .folders, count: strongSelf.tabContainerNode.filtersCount, action: {
                                let controller = PremiumIntroScreen(context: context, source: .folders)
                                replaceImpl?(controller)
                            })
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                navigationController.pushViewController(controller)
                            }
                        } else {
                            strongSelf.selectTab(id: .filter(id))
                        }
                    })))
                    
                    filterCount += 1
                }
            }
            
            let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatListTabBarContextExtractedContentSource(controller: strongSelf, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
            strongSelf.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
        })
    }
    
    private var playedSignUpCompletedAnimation = false
    public func playSignUpCompletedAnimation() {
        guard !self.playedSignUpCompletedAnimation else {
            return
        }
        self.playedSignUpCompletedAnimation = true
        Queue.mainQueue().after(0.3) {
            self.view.addSubview(ConfettiView(frame: self.view.bounds))
        }
    }
}

private final class ChatListTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private let controller: ChatListController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ChatListController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ChatListHeaderBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    private let controller: ChatListController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ChatListController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ChatListContextLocationContentSource: ContextLocationContentSource {    
    private let controller: ViewController
    private let location: CGPoint
    
    init(controller: ViewController, location: CGPoint) {
        self.controller = controller
        self.location = location
    }
    
    func transitionInfo() -> ContextControllerLocationViewInfo? {
        return ContextControllerLocationViewInfo(location: self.location, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ChatListLocationContext {
    let context: AccountContext
    let location: ChatListControllerLocation
    weak var parentController: ChatListControllerImpl?
    
    private var proxyUnavailableTooltipController: TooltipController?
    private var didShowProxyUnavailableTooltipController = false
    
    private var titleDisposable: Disposable?
    
    private(set) var title: String = ""
    private(set) var chatTitleComponent: ChatTitleComponent?
    private(set) var chatListTitle: NetworkStatusTitle?
    
    var leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
    var rightButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
    var proxyButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
    
    var rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] {
        var result: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
        if let rightButton = self.rightButton {
            result.append(rightButton)
        }
        if let proxyButton = self.proxyButton {
            result.append(proxyButton)
        }
        return result
    }
    
    private(set) var toolbar: Toolbar?
    
    private let previousEditingAndNetworkStateValue = Atomic<(Bool, AccountNetworkState)?>(value: nil)
    
    private var didSetReady: Bool = false
    let ready = Promise<Bool>()
    
    private var stateDisposable: Disposable?
    
    init(
        context: AccountContext,
        location: ChatListControllerLocation,
        parentController: ChatListControllerImpl,
        hideNetworkActivityStatus: Bool,
        containerNode: ChatListContainerNode,
        isReorderingTabs: Signal<Bool, NoError>
    ) {
        self.context = context
        self.location = location
        self.parentController = parentController
        
        let hasProxy = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> (Bool, Bool) in
            if let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                return (!settings.servers.isEmpty, settings.enabled)
            } else {
                return (false, false)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
        
        let passcode = context.sharedContext.accountManager.accessChallengeData()
        |> map { view -> (Bool, Bool) in
            let data = view.data
            return (data.isLockable, false)
        }
        
        let peerStatus: Signal<NetworkStatusTitle.Status?, NoError>
        switch self.location {
        case .chatList(.root):
            peerStatus = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> NetworkStatusTitle.Status? in
                guard case let .user(user) = peer else {
                    return nil
                }
                if let emojiStatus = user.emojiStatus {
                    return .emoji(emojiStatus)
                } else if user.isPremium {
                    return .premium
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
        default:
            peerStatus = .single(nil)
        }
        
        switch location {
        case .chatList:
            if !hideNetworkActivityStatus {
                self.titleDisposable = combineLatest(queue: .mainQueue(),
                    context.account.networkState,
                    hasProxy,
                    passcode,
                    containerNode.currentItemState,
                    isReorderingTabs,
                    peerStatus,
                    parentController.updatedPresentationData.1
                ).start(next: { [weak self] networkState, proxy, passcode, stateAndFilterId, isReorderingTabs, peerStatus, presentationData in
                    guard let self else {
                        return
                    }
                    self.updateChatList(
                        networkState: networkState,
                        proxy: proxy,
                        passcode: passcode,
                        stateAndFilterId: stateAndFilterId,
                        isReorderingTabs: isReorderingTabs,
                        peerStatus: peerStatus,
                        presentationData: presentationData
                    )
                })
            } else {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
        case let .forum(peerId):     
            let peerView = Promise<PeerView>()
            peerView.set(context.account.viewTracker.peerView(peerId))
            
            var onlineMemberCount: Signal<Int32?, NoError> = .single(nil)
            
            let recentOnlineSignal: Signal<Int32?, NoError> = peerView.get()
            |> map { view -> Bool? in
                if let cachedData = view.cachedData as? CachedChannelData, let peer = peerViewMainPeer(view) as? TelegramChannel {
                    if case .broadcast = peer.info {
                        return nil
                    } else if let memberCount = cachedData.participantsSummary.memberCount, memberCount > 50 {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
            |> distinctUntilChanged
            |> mapToSignal { isLarge -> Signal<Int32?, NoError> in
                if let isLarge = isLarge {
                    if isLarge {
                        return context.peerChannelMemberCategoriesContextsManager.recentOnline(account: context.account, accountPeerId: context.account.peerId, peerId: peerId)
                        |> map(Optional.init)
                    } else {
                        return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                        |> map(Optional.init)
                    }
                } else {
                    return .single(nil)
                }
            }
            onlineMemberCount = recentOnlineSignal
            
            self.titleDisposable = (combineLatest(queue: Queue.mainQueue(),
                peerView.get(),
                onlineMemberCount,
                containerNode.currentItemState,
                parentController.updatedPresentationData.1
            )
            |> deliverOnMainQueue).start(next: { [weak self] peerView, onlineMemberCount, stateAndFilterId, presentationData in
                guard let self else {
                    return
                }
                self.updateForum(
                    peerId: peerId,
                    peerView: peerView,
                    onlineMemberCount: onlineMemberCount,
                    stateAndFilterId: stateAndFilterId,
                    presentationData: presentationData
                )
            })
        }
        
        let context = self.context
        let location = self.location
        let peerIdsAndOptions: Signal<(ChatListSelectionOptions, Set<PeerId>, Set<Int64>)?, NoError> = containerNode.currentItemState
        |> map { state, filterId -> (Set<PeerId>, Set<Int64>, Int32?)? in
            if !state.editing {
                return nil
            }
            return (state.selectedPeerIds, state.selectedThreadIds, filterId)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs?.0 != rhs?.0 {
                return false
            }
            if lhs?.1 != rhs?.1 {
                return false
            }
            if lhs?.2 != rhs?.2 {
                return false
            }
            return true
        })
        |> mapToSignal { selectedPeerIdsAndFilterId -> Signal<(ChatListSelectionOptions, Set<PeerId>, Set<Int64>)?, NoError> in
            if let (selectedPeerIds, selectedThreadIds, filterId) = selectedPeerIdsAndFilterId {
                switch location {
                case .chatList:
                    return chatListSelectionOptions(context: context, peerIds: selectedPeerIds, filterId: filterId)
                    |> map { options -> (ChatListSelectionOptions, Set<PeerId>, Set<Int64>)? in
                        return (options, selectedPeerIds, selectedThreadIds)
                    }
                case let .forum(peerId):
                    return forumSelectionOptions(context: context, peerId: peerId, threadIds: selectedThreadIds)
                    |> map { options -> (ChatListSelectionOptions, Set<PeerId>, Set<Int64>)? in
                        return (options, selectedPeerIds, selectedThreadIds)
                    }
                }
                
            } else {
                return .single(nil)
            }
        }
        
        let peerView: Signal<PeerView?, NoError>
        if case let .forum(peerId) = location {
            peerView = context.account.viewTracker.peerView(peerId)
            |> map(Optional.init)
        } else {
            peerView = .single(nil)
        }
        
        let previousToolbarValue = Atomic<Toolbar?>(value: nil)
        self.stateDisposable = combineLatest(queue: .mainQueue(),
            parentController.updatedPresentationData.1,
            peerIdsAndOptions,
            peerView
        ).start(next: { [weak self, weak containerNode] presentationData, peerIdsAndOptions, peerView in
            guard let strongSelf = self, let containerNode = containerNode, let parentController = strongSelf.parentController else {
                return
            }
            var toolbar: Toolbar?
            if let (options, peerIds, _) = peerIdsAndOptions {
                if case .chatList(.root) = location {
                    let leftAction: ToolbarAction
                    switch options.read {
                    case let .all(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_ReadAll, isEnabled: enabled)
                    case let .selective(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: enabled)
                    }
                    var archiveEnabled = options.delete
                    var displayArchive = true
                    if let filter = containerNode.currentItemNode.chatListFilter, case let .filter(_, _, _, data) = filter {
                        if !data.excludeArchived {
                            displayArchive = false
                        }
                    }
                    if archiveEnabled {
                        for peerId in peerIds {
                            if peerId == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000)) {
                                archiveEnabled = false
                                break
                            } else if peerId == strongSelf.context.account.peerId {
                                archiveEnabled = false
                                break
                            }
                        }
                    }
                    toolbar = Toolbar(leftAction: leftAction, rightAction: ToolbarAction(title: presentationData.strings.Common_Delete, isEnabled: options.delete), middleAction: displayArchive ? ToolbarAction(title: presentationData.strings.ChatList_ArchiveAction, isEnabled: archiveEnabled) : nil)
                } else if case .forum = strongSelf.location {
                    let leftAction: ToolbarAction
                    switch options.read {
                    case .all:
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: false)
                    case let .selective(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: enabled)
                    }
                    toolbar = Toolbar(leftAction: leftAction, rightAction: ToolbarAction(title: presentationData.strings.Common_Delete, isEnabled: options.delete), middleAction: nil)
                } else {
                    let middleAction = ToolbarAction(title: presentationData.strings.ChatList_UnarchiveAction, isEnabled: !peerIds.isEmpty)
                    let leftAction: ToolbarAction
                    switch options.read {
                    case .all:
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: false)
                    case let .selective(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: enabled)
                    }
                    toolbar = Toolbar(leftAction: leftAction, rightAction: ToolbarAction(title: presentationData.strings.Common_Delete, isEnabled: options.delete), middleAction: middleAction)
                }
            } else if let peerView = peerView, let channel = peerView.peers[peerView.peerId] as? TelegramChannel {
                switch channel.participationStatus {
                case .member:
                    toolbar = nil
                default:
                    let actionTitle: String
                    if channel.flags.contains(.requestToJoin) {
                        actionTitle = presentationData.strings.Group_ApplyToJoin
                    } else {
                        actionTitle = presentationData.strings.Channel_JoinChannel
                    }
                    toolbar = Toolbar(leftAction: nil, rightAction: nil, middleAction: ToolbarAction(title: actionTitle, isEnabled: true))
                }
            }
            var transition: ContainedViewLayoutTransition = .immediate
            let previousToolbar = previousToolbarValue.swap(toolbar)
            if (previousToolbar == nil) != (toolbar == nil) {
                transition = .animated(duration: 0.4, curve: .spring)
            }
            if strongSelf.toolbar != toolbar {
                strongSelf.toolbar = toolbar
                if parentController.effectiveContext === strongSelf {
                    parentController.setToolbar(toolbar, transition: transition)
                }
            }
        })
    }
                                
    deinit {
        self.titleDisposable?.dispose()
        self.stateDisposable?.dispose()
    }
    
    private func updateChatList(
        networkState: AccountNetworkState,
        proxy: (Bool, Bool),
        passcode: (Bool, Bool),
        stateAndFilterId: (state: ChatListNodeState, filterId: Int32?),
        isReorderingTabs: Bool,
        peerStatus: NetworkStatusTitle.Status?,
        presentationData: PresentationData
    ) {
        let defaultTitle: String
        switch location {
        case let .chatList(groupId):
            if groupId == .root {
                defaultTitle = presentationData.strings.DialogList_Title
            } else {
                defaultTitle = presentationData.strings.ChatList_ArchivedChatsTitle
            }
        case .forum:
            defaultTitle = ""
        }
        let previousEditingAndNetworkState = self.previousEditingAndNetworkStateValue.swap((stateAndFilterId.state.editing, networkState))
        
        var titleContent: NetworkStatusTitle
        
        if stateAndFilterId.state.editing {
            if case .chatList(.root) = self.location {
                self.rightButton = nil
            }
            let title = !stateAndFilterId.state.selectedPeerIds.isEmpty ? presentationData.strings.ChatList_SelectedChats(Int32(stateAndFilterId.state.selectedPeerIds.count)) : defaultTitle
            
            var animated = false
            if let (previousEditing, previousNetworkState) = previousEditingAndNetworkState {
                if previousEditing != stateAndFilterId.state.editing, previousNetworkState == networkState, case .online = networkState {
                    animated = true
                }
            }
            titleContent = NetworkStatusTitle(text: title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus)
            let _ = animated
        } else if isReorderingTabs {
            if case .chatList(.root) = self.location {
                self.rightButton = nil
            }
            self.leftButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                content: .text(title: presentationData.strings.Common_Done, isBold: true),
                pressed: { [weak self] _ in
                    self?.parentController?.reorderingDonePressed()
                }
            )))
            
            let (_, connectsViaProxy) = proxy
            
            switch networkState {
            case .waitingForNetwork:
                titleContent = NetworkStatusTitle(text: presentationData.strings.State_WaitingForNetwork, activity: true, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus)
            case let .connecting(proxy):
                let text = presentationData.strings.State_Connecting
                let _ = proxy
                /*if let layout = strongSelf.validLayout, proxy != nil && layout.metrics.widthClass != .regular && layout.size.width > 320.0 {
                    text = self.presentationData.strings.State_ConnectingToProxy
                }*/
                titleContent = NetworkStatusTitle(text: text, activity: true, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus)
            case .updating:
                titleContent = NetworkStatusTitle(text: presentationData.strings.State_Updating, activity: true, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus)
            case .online:
                titleContent = NetworkStatusTitle(text: defaultTitle, activity: false, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus)
            }
        } else {
            var isRoot = false
            if case .chatList(.root) = self.location {
                isRoot = true
                
                if isReorderingTabs {
                    self.rightButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                        content: .text(title: presentationData.strings.Common_Done, isBold: true),
                        pressed: { [weak self] _ in
                            self?.parentController?.editPressed()
                        }
                    )))
                } else {
                    self.rightButton = AnyComponentWithIdentity(id: "compose", component: AnyComponent(NavigationButtonComponent(
                        content: .icon(imageName: "Chat List/ComposeIcon"),
                        pressed: { [weak self] _ in
                            self?.parentController?.composePressed()
                        }
                    )))
                }
                
                if isReorderingTabs {
                    self.leftButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                        content: .text(title: presentationData.strings.Common_Done, isBold: true),
                        pressed: { [weak self] _ in
                            self?.parentController?.reorderingDonePressed()
                        }
                    )))
                } else {
                    if stateAndFilterId.state.editing {
                        self.leftButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                            content: .text(title: presentationData.strings.Common_Done, isBold: true),
                            pressed: { [weak self] _ in
                                self?.parentController?.donePressed()
                            }
                        )))
                    } else {
                        self.leftButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                            content: .text(title: presentationData.strings.Common_Edit, isBold: false),
                            pressed: { [weak self] _ in
                                self?.parentController?.editPressed()
                            }
                        )))
                    }
                }
            } else {
                self.rightButton = AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: presentationData.strings.Common_Edit, isBold: false),
                    pressed: { [weak self] _ in
                        self?.parentController?.editPressed()
                    }
                )))
            }
            
            let (hasProxy, connectsViaProxy) = proxy
            let (isPasscodeSet, isManuallyLocked) = passcode
            var checkProxy = false
            switch networkState {
            case .waitingForNetwork:
                titleContent = NetworkStatusTitle(text: presentationData.strings.State_WaitingForNetwork, activity: true, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: isRoot && isPasscodeSet, isManuallyLocked: isRoot && isManuallyLocked, peerStatus: peerStatus)
            case let .connecting(proxy):
                let text = presentationData.strings.State_Connecting
                /*if let layout = strongSelf.validLayout, proxy != nil && layout.metrics.widthClass != .regular && layout.size.width > 320.0 {*/
                    //text = self.presentationData.strings.State_ConnectingToProxy
                //}
                if let proxy = proxy, proxy.hasConnectionIssues {
                    checkProxy = true
                }
                titleContent = NetworkStatusTitle(text: text, activity: true, hasProxy: isRoot && hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isRoot && isPasscodeSet, isManuallyLocked: isRoot && isManuallyLocked, peerStatus: peerStatus)
            case .updating:
                titleContent = NetworkStatusTitle(text: presentationData.strings.State_Updating, activity: true, hasProxy: isRoot && hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isRoot && isPasscodeSet, isManuallyLocked: isRoot && isManuallyLocked, peerStatus: peerStatus)
            case .online:
                titleContent = NetworkStatusTitle(text: defaultTitle, activity: false, hasProxy: isRoot && hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isRoot && isPasscodeSet, isManuallyLocked: isRoot && isManuallyLocked, peerStatus: peerStatus)
            }
            
            if titleContent.hasProxy {
                let proxyStatus: ChatTitleProxyStatus
                if titleContent.connectsViaProxy {
                    proxyStatus = titleContent.activity ? .connecting : .connected
                } else {
                    proxyStatus = .available
                }
                
                self.proxyButton = AnyComponentWithIdentity(id: "proxy", component: AnyComponent(NavigationButtonComponent(
                    content: .proxy(status: proxyStatus),
                    pressed: { [weak self] _ in
                        guard let self, let parentController = self.parentController else {
                            return
                        }
                        (parentController.navigationController as? NavigationController)?.pushViewController(self.context.sharedContext.makeProxySettingsController(context: self.context))
                    }
                )))
                
                titleContent.hasProxy = false
                titleContent.connectsViaProxy = false
            } else {
                self.proxyButton = nil
            }
            
            self.chatListTitle = titleContent
            
            if case .chatList(.root) = self.location, checkProxy {
                if self.proxyUnavailableTooltipController == nil, !self.didShowProxyUnavailableTooltipController, let parentController = self.parentController, parentController.isNodeLoaded, parentController.displayNode.view.window != nil, parentController.navigationController?.topViewController == nil {
                    self.didShowProxyUnavailableTooltipController = true
                    let tooltipController = TooltipController(content: .text(presentationData.strings.Proxy_TooltipUnavailable), baseFontSize: presentationData.listsFontSize.baseDisplaySize, timeout: 60.0, dismissByTapOutside: true)
                    self.proxyUnavailableTooltipController = tooltipController
                    tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.proxyUnavailableTooltipController === tooltipController {
                            strongSelf.proxyUnavailableTooltipController = nil
                        }
                    }
                    self.parentController?.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                        if let strongSelf = self, let titleView = strongSelf.parentController?.self.findTitleView(), let rect = titleView.proxyButtonFrame {
                            return (titleView, rect.insetBy(dx: 0.0, dy: -4.0))
                        }
                        return nil
                    }))
                }
            } else {
                self.didShowProxyUnavailableTooltipController = false
                if let proxyUnavailableTooltipController = self.proxyUnavailableTooltipController {
                    self.proxyUnavailableTooltipController = nil
                    proxyUnavailableTooltipController.dismiss()
                }
            }
        }
        
        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
        
        self.parentController?.requestUpdateHeaderContent(transition: .immediate)
    }
    
    private func updateForum(
        peerId: EnginePeer.Id,
        peerView: PeerView,
        onlineMemberCount: Int32?,
        stateAndFilterId: (state: ChatListNodeState, filterId: Int32?),
        presentationData: PresentationData
    ) {
        if stateAndFilterId.state.editing && stateAndFilterId.state.selectedThreadIds.count > 0 {
            self.chatTitleComponent = ChatTitleComponent(
                context: self.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                content: .custom(presentationData.strings.ChatList_SelectedTopics(Int32(stateAndFilterId.state.selectedThreadIds.count)), nil, false),
                tapped: {
                },
                longTapped: {
                }
            )
        } else {
            self.chatTitleComponent = ChatTitleComponent(
                context: self.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                content: .peer(peerView: peerView, customTitle: nil, onlineMemberCount: onlineMemberCount, isScheduledMessages: false, isMuted: nil, customMessageCount: nil),
                tapped: { [weak self] in
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let self, let peer = peer, let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                            return
                        }
                        (self.parentController?.navigationController as? NavigationController)?.pushViewController(controller)
                    })
                },
                longTapped: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.parentController?.activateSearch()
                }
            )
        }
        
        if stateAndFilterId.state.editing {
            self.rightButton = AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                content: .text(title: presentationData.strings.Common_Done, isBold: true),
                pressed: { [weak self] _ in
                    self?.parentController?.donePressed()
                }
            )))
        } else {
            let parentController = self.parentController
            self.rightButton = AnyComponentWithIdentity(id: "more", component: AnyComponent(NavigationButtonComponent(
                content: .more,
                pressed: { [weak parentController] sourceView in
                    if let secondaryContext = parentController?.secondaryContext {
                        secondaryContext.performMoreAction(sourceView: sourceView)
                    } else if let primaryContext = parentController?.primaryContext {
                        primaryContext.performMoreAction(sourceView: sourceView)
                    }
                },
                contextAction: { [weak self] sourceView, gesture in
                    guard let self, let parentController = self.parentController else {
                        return
                    }
                    ChatListControllerImpl.openMoreMenu(context: self.context, peerId: peerId, sourceController: parentController, isViewingAsTopics: true, sourceView: sourceView, gesture: gesture)
                }
            )))
        }
        
        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
        
        if let channel = peerView.peers[peerView.peerId] as? TelegramChannel, !channel.flags.contains(.isForum) {
            if let parentController = self.parentController, let navigationController = parentController.navigationController as? NavigationController {
                let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
                navigationController.replaceController(parentController, with: chatController, animated: true)
            }
        } else {
            self.parentController?.requestUpdateHeaderContent(transition: .immediate)
        }
    }
    
    private func performMoreAction(sourceView: UIView) {
        guard let parentController = self.parentController else {
            return
        }
        switch self.location {
        case .chatList:
            break
        case let .forum(peerId):
            ChatListControllerImpl.openMoreMenu(context: self.context, peerId: peerId, sourceController: parentController, isViewingAsTopics: true, sourceView: sourceView, gesture: nil)
        }
    }
}
