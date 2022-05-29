import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import SearchBarNode
import SearchUI
import ChatListSearchItemHeader

extension SettingsSearchableItemIcon {
    func image() -> UIImage? {
        switch self {
            case .profile:
                return PresentationResourcesSettings.editProfile
            case .proxy:
                return PresentationResourcesSettings.proxy
            case .savedMessages:
                return PresentationResourcesSettings.savedMessages
            case .calls:
                return PresentationResourcesSettings.recentCalls
            case .stickers:
                return PresentationResourcesSettings.stickers
            case .notifications:
                return PresentationResourcesSettings.notifications
            case .privacy:
                return PresentationResourcesSettings.security
            case .data:
                return PresentationResourcesSettings.dataAndStorage
            case .appearance:
                return PresentationResourcesSettings.appearance
            case .language:
                return PresentationResourcesSettings.language
            case .watch:
                return PresentationResourcesSettings.watch
            case .passport:
                return PresentationResourcesSettings.passport
            case .wallet:
                return PresentationResourcesSettings.wallet
            case .support:
                return PresentationResourcesSettings.support
            case .faq:
                return PresentationResourcesSettings.faq
            case .chatFolders:
                return PresentationResourcesSettings.chatFolders
        }
    }
}

final class SettingsSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let theme: PresentationTheme
    let placeholder: String
    let activated: Bool
    let updateActivated: (Bool) -> Void
    let presentController: (ViewController, Any?) -> Void
    let pushController: (ViewController) -> Void
    let getNavigationController: (() -> NavigationController?)?
    let resolvedFaqUrl: Signal<ResolvedUrl?, NoError>
    let exceptionsList: Signal<NotificationExceptionsList?, NoError>
    let archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>
    let privacySettings: Signal<AccountPrivacySettings?, NoError>
    let hasTwoStepAuth: Signal<Bool?, NoError>
    let activeSessionsContext: Signal<ActiveSessionsContext?, NoError>
    let webSessionsContext: Signal<WebSessionsContext?, NoError>
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, theme: PresentationTheme, placeholder: String, activated: Bool, updateActivated: @escaping (Bool) -> Void, presentController: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, getNavigationController: (() -> NavigationController?)?, resolvedFaqUrl: Signal<ResolvedUrl?, NoError>, exceptionsList: Signal<NotificationExceptionsList?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, hasTwoStepAuth: Signal<Bool?, NoError>, activeSessionsContext: Signal<ActiveSessionsContext?, NoError>, webSessionsContext: Signal<WebSessionsContext?, NoError>) {
        self.context = context
        self.theme = theme
        self.placeholder = placeholder
        self.activated = activated
        self.updateActivated = updateActivated
        self.presentController = presentController
        self.pushController = pushController
        self.getNavigationController = getNavigationController
        self.resolvedFaqUrl = resolvedFaqUrl
        self.exceptionsList = exceptionsList
        self.archivedStickerPacks = archivedStickerPacks
        self.privacySettings = privacySettings
        self.hasTwoStepAuth = hasTwoStepAuth
        self.activeSessionsContext = activeSessionsContext
        self.webSessionsContext = webSessionsContext
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
        if let to = to as? SettingsSearchItem {
            if self.context !== to.context || self.theme !== to.theme || self.placeholder != to.placeholder || self.activated != to.activated {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        if let current = current as? NavigationBarSearchContentNode {
            current.updateThemeAndPlaceholder(theme: self.theme, placeholder: self.placeholder)
            return current
        } else {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            return NavigationBarSearchContentNode(theme: presentationData.theme, placeholder: presentationData.strings.Settings_Search, activate: {
                updateActivated(true)
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        let presentController: (ViewController, Any?) -> Void = self.presentController
        let pushController: (ViewController) -> Void = self.pushController
        
        if let current = current as? SettingsSearchItemNode, let titleContentNode = titleContentNode as? NavigationBarSearchContentNode {
            current.updatePresentationData(self.context.sharedContext.currentPresentationData.with { $0 })
            if current.isSearching != self.activated {
                if self.activated {
                    current.activateSearch(placeholderNode: titleContentNode.placeholderNode)
                } else {
                    current.deactivateSearch(placeholderNode: titleContentNode.placeholderNode)
                }
            }
            return current
        } else {
            return SettingsSearchItemNode(context: self.context, cancel: {
                updateActivated(false)
            }, updateActivity: { [weak self] value in
                self?.activity.set(value)
            }, pushController: { c in
                pushController(c)
            }, presentController: { c, a in
                presentController(c, a)
            }, getNavigationController: self.getNavigationController, resolvedFaqUrl: self.resolvedFaqUrl, exceptionsList: self.exceptionsList, archivedStickerPacks: self.archivedStickerPacks, privacySettings: self.privacySettings, hasTwoStepAuth: self.hasTwoStepAuth, activeSessionsContext: self.activeSessionsContext, webSessionsContext: self.webSessionsContext)
        }
    }
}

final class SettingsSearchInteraction {
    let openItem: (SettingsSearchableItem) -> Void
    let deleteRecentItem: (SettingsSearchableItemId) -> Void
    
    init(openItem: @escaping (SettingsSearchableItem) -> Void, deleteRecentItem: @escaping (SettingsSearchableItemId) -> Void) {
        self.openItem = openItem
        self.deleteRecentItem = deleteRecentItem
    }
}

private enum SettingsSearchEntryStableId: Hashable {
    case result(SettingsSearchableItemId)
}

private enum SettingsSearchEntry: Comparable, Identifiable {
    case result(index: Int, item: SettingsSearchableItem, icon: UIImage?)
    
    var stableId: SettingsSearchEntryStableId {
        switch self {
            case let .result(_, item, _):
                return .result(item.id)
        }
    }
    
    private func index() -> Int {
        switch self {
            case let .result(index, _, _):
                return index
        }
    }
    
    static func <(lhs: SettingsSearchEntry, rhs: SettingsSearchEntry) -> Bool {
        return lhs.index() < rhs.index()
    }
    
    static func == (lhs: SettingsSearchEntry, rhs: SettingsSearchEntry) -> Bool {
        if case let .result(lhsIndex, lhsItem, _) = lhs {
            if case let .result(rhsIndex, rhsItem, _) = rhs, lhsIndex == rhsIndex, lhsItem.id == rhsItem.id {
                return true
            }
        }
        return false
    }
    
    func item(theme: PresentationTheme, strings: PresentationStrings, interaction: SettingsSearchInteraction)  -> ListViewItem {
        switch self {
            case let .result(_, item, icon):
                return SettingsSearchResultItem(theme: theme, strings: strings, item: item, icon: icon, interaction: interaction, sectionId: 0)
        }
    }
}

private struct SettingsSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedSettingsSearchContainerTransition(theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [SettingsSearchEntry], to toEntries: [SettingsSearchEntry], interaction: SettingsSearchInteraction, isSearching: Bool, forceUpdate: Bool) -> SettingsSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    
    return SettingsSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private enum SettingsSearchRecentEntryStableId: Hashable {
    case recent(SettingsSearchableItemId)
}

private enum SettingsSearchRecentEntry: Comparable, Identifiable {
    case recent(Int, SettingsSearchableItem, ChatListSearchItemHeader)
    case faq(Int, SettingsSearchableItem, ChatListSearchItemHeader)
    
    var stableId: SettingsSearchRecentEntryStableId {
        switch self {
            case let .recent(_, item, _), let .faq(_, item, _):
                return .recent(item.id)
        }
    }
    
    var header: ChatListSearchItemHeader {
        switch self {
            case let .recent(_, _, header), let .faq(_, _, header):
                return header
        }
    }
    
    static func ==(lhs: SettingsSearchRecentEntry, rhs: SettingsSearchRecentEntry) -> Bool {
        switch lhs {
            case let .recent(lhsIndex, lhsItem, lhsHeader):
                if case let .recent(rhsIndex, rhsItem, rhsHeader) = rhs, lhsIndex == rhsIndex, lhsItem.id == rhsItem.id, lhsHeader.id == rhsHeader.id {
                    return true
                } else {
                    return false
                }
            case let .faq(lhsIndex, lhsItem, lhsHeader):
                if case let .faq(rhsIndex, rhsItem, rhsHeader) = rhs, lhsIndex == rhsIndex, lhsItem.id == rhsItem.id, lhsHeader.id == rhsHeader.id {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: SettingsSearchRecentEntry, rhs: SettingsSearchRecentEntry) -> Bool {
        switch lhs {
            case let .recent(lhsIndex, _, _):
                switch rhs {
                    case let .recent(rhsIndex, _, _):
                        return lhsIndex <= rhsIndex
                    case .faq:
                        return false
                }
            case let .faq(lhsIndex, _, _):
                switch rhs {
                    case .recent:
                        return true
                    case let .faq(rhsIndex, _, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: SettingsSearchInteraction) -> ListViewItem {
        switch self {
            case let .recent(_, item, header):
                return SettingsSearchRecentItem(account: account, theme: theme, strings: strings, title: item.title, breadcrumbs: item.breadcrumbs, isFaq: false, action: {
                    interaction.openItem(item)
                }, deleted: {
                    interaction.deleteRecentItem(item.id)
                }, header: header)
            case let .faq(_, item, header):
                return SettingsSearchRecentItem(account: account, theme: theme, strings: strings, title: item.title, breadcrumbs: item.breadcrumbs, isFaq: true, action: {
                    interaction.openItem(item)
                }, deleted: {
                    interaction.deleteRecentItem(item.id)
                }, header: header)
        }
    }
}

private struct SettingsSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isEmpty: Bool
}

private func preparedSettingsSearchContainerRecentTransition(from fromEntries: [SettingsSearchRecentEntry], to toEntries: [SettingsSearchRecentEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: SettingsSearchInteraction) -> SettingsSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    
    return SettingsSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates, isEmpty: toEntries.isEmpty)
}


public final class SettingsSearchContainerNode: SearchDisplayControllerContentNode {
    private let listNode: ListView
    private let recentListNode: ListView
    
    private var enqueuedTransitions: [SettingsSearchContainerTransition] = []
    private var enqueuedRecentTransitions: [(SettingsSearchContainerRecentTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var recentDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    public init(context: AccountContext, openResult: @escaping (SettingsSearchableItem) -> Void, resolvedFaqUrl: Signal<ResolvedUrl?, NoError>, exceptionsList: Signal<NotificationExceptionsList?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, hasTwoStepAuth: Signal<Bool?, NoError>, activeSessionsContext: Signal<ActiveSessionsContext?, NoError>, webSessionsContext: Signal<WebSessionsContext?, NoError>) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.recentListNode = ListView()
        self.recentListNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.recentListNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        
        let interaction = SettingsSearchInteraction(openItem: { result in
            addRecentSettingsSearchItem(engine: context.engine, item: result.id)
            openResult(result)
        }, deleteRecentItem: { id in
            removeRecentSettingsSearchItem(engine: context.engine, item: id)
        })
        
        let searchableItems = Promise<[SettingsSearchableItem]>()
        searchableItems.set(settingsSearchableItems(context: context, notificationExceptionsList: exceptionsList, archivedStickerPacks: archivedStickerPacks, privacySettings: privacySettings, hasTwoStepAuth: hasTwoStepAuth, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext))
        
        let faqItems = Promise<[SettingsSearchableItem]>()
        faqItems.set(faqSearchableItems(context: context, resolvedUrl: resolvedFaqUrl, suggestAccountDeletion: false))
        
        let queryAndFoundItems = combineLatest(searchableItems.get(), faqSearchableItems(context: context, resolvedUrl: resolvedFaqUrl, suggestAccountDeletion: true))
        |> mapToSignal { searchableItems, faqSearchableItems -> Signal<(String, [SettingsSearchableItem])?, NoError> in
            return self.searchQuery.get()
            |> mapToSignal { query -> Signal<(String, [SettingsSearchableItem])?, NoError> in
                if let query = query, !query.isEmpty {
                    let results = searchSettingsItems(items: searchableItems, query: query)
                    let faqResults = searchSettingsItems(items: faqSearchableItems, query: query)
                    let finalResults: [SettingsSearchableItem]
                    if faqResults.first?.id == .faq(1) {
                        finalResults = faqResults + results
                    } else {
                        finalResults = results + faqResults
                    }
                    return .single((query, finalResults))
                } else {
                    return .single(nil)
                }
            }
        }
        
        self.recentListNode.isHidden = false
        
        let previousRecentlySearchedItemOrder = Atomic<[SettingsSearchableItemId]>(value: [])
        let fixedRecentlySearchedItems = settingsSearchRecentItems(engine: context.engine)
        |> map { recentIds -> [SettingsSearchableItemId] in
            var result: [SettingsSearchableItemId] = []
            let _ = previousRecentlySearchedItemOrder.modify { current in
                var updated: [SettingsSearchableItemId] = []
                for id in current {
                    inner: for recentId in recentIds {
                        if recentId == id {
                            updated.append(id)
                            result.append(recentId)
                            break inner
                        }
                    }
                }
                for recentId in recentIds.reversed() {
                    if !updated.contains(recentId) {
                        updated.insert(recentId, at: 0)
                        result.insert(recentId, at: 0)
                    }
                }
                return updated
            }
            return result
        }
        
        let recentSearchItems = combineLatest(searchableItems.get(), fixedRecentlySearchedItems)
        |> map { searchableItems, recentItems -> [SettingsSearchableItem] in
            let searchableItemsMap = searchableItems.reduce([SettingsSearchableItemId : SettingsSearchableItem]()) { (map, item) -> [SettingsSearchableItemId: SettingsSearchableItem] in
                var map = map
                map[item.id] = item
                return map
            }
            var result: [SettingsSearchableItem] = []
            for itemId in recentItems {
                if let searchItem = searchableItemsMap[itemId] {
                    if case let .language(id) = searchItem.id, id > 0 {
                    } else {
                        result.append(searchItem)
                    }
                }
            }
            return result
        }
        
        let previousRecentItems = Atomic<[SettingsSearchRecentEntry]?>(value: nil)
        self.recentDisposable = (combineLatest(recentSearchItems, faqItems.get(), self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] recentSearchItems, faqItems, presentationData in
            if let strongSelf = self {
                let recentHeader = ChatListSearchItemHeader(type: .recentPeers, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.WebSearch_RecentSectionClear, action: {
                    clearRecentSettingsSearchItems(engine: context.engine)
                })
                let faqHeader = ChatListSearchItemHeader(type: .faq, theme: presentationData.theme, strings: presentationData.strings)
                
                var entries: [SettingsSearchRecentEntry] = []
                for i in 0 ..< recentSearchItems.count {
                    entries.append(.recent(i, recentSearchItems[i], recentHeader))
                }
                
                for i in 0 ..< faqItems.count {
                    entries.append(.faq(i, faqItems[i], faqHeader))
                }
                
                
                let previousEntries = previousRecentItems.swap(entries)
                let transition = preparedSettingsSearchContainerRecentTransition(from: previousEntries ?? [], to: entries, account: context.account, theme: presentationData.theme, strings: presentationData.strings, interaction: interaction)
                strongSelf.enqueueRecentTransition(transition, firstTime: previousEntries == nil)
            }
        })
        
        let previousEntriesHolder = Atomic<([SettingsSearchEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), queryAndFoundItems, self.presentationDataPromise.get()).start(next: { [weak self] queryAndFoundItems, presentationData in
            guard let strongSelf = self else {
                return
            }
            var currentQuery: String?
            var entries: [SettingsSearchEntry] = []
            if let (query, items) = queryAndFoundItems {
                currentQuery = query
                var previousIcon: SettingsSearchableItemIcon?
                for item in items {
                    var image: UIImage?
                    if previousIcon != item.icon {
                        image = item.icon.image()
                    }
                    entries.append(.result(index: entries.count, item: item, icon: image))
                    previousIcon = item.icon
                }
            }
            
            if !entries.isEmpty || currentQuery == nil {
                let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
                let transition = preparedSettingsSearchContainerTransition(theme: presentationData.theme, strings: presentationData.strings, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, interaction: interaction, isSearching: queryAndFoundItems != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
                strongSelf.enqueueTransition(transition)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                        strongSelf.presentationDataPromise.set(.single(presentationData))
                    }
                }
            })
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        
        self.recentListNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.recentDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
        self.recentListNode.backgroundColor = theme.chatList.backgroundColor
        self.recentListNode.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
    }
    
    public override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: SettingsSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
            })
        }
    }
    
    private func enqueueRecentTransition(_ transition: SettingsSearchContainerRecentTransition, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.recentListNode.backgroundColor = transition.isEmpty ? .clear : self?.presentationData.theme.chatList.backgroundColor
            })
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    public override func scrollToTop() {
        let listNodeToScroll: ListView
        if !self.listNode.isHidden {
            listNodeToScroll = self.listNode
        } else {
            listNodeToScroll = self.recentListNode
        }
        listNodeToScroll.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}

private final class SettingsSearchItemNode: ItemListControllerSearchNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var searchDisplayController: SearchDisplayController?
    
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, Any?) -> Void
    let getNavigationController: (() -> NavigationController?)?
    let resolvedFaqUrl: Signal<ResolvedUrl?, NoError>
    let exceptionsList: Signal<NotificationExceptionsList?, NoError>
    let archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>
    let privacySettings: Signal<AccountPrivacySettings?, NoError>
    let hasTwoStepAuth: Signal<Bool?, NoError>
    let activeSessionsContext: Signal<ActiveSessionsContext?, NoError>
    let webSessionsContext: Signal<WebSessionsContext?, NoError>
    
    var cancel: () -> Void
    
    init(context: AccountContext, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, Any?) -> Void, getNavigationController: (() -> NavigationController?)?, resolvedFaqUrl: Signal<ResolvedUrl?, NoError>, exceptionsList: Signal<NotificationExceptionsList?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, hasTwoStepAuth: Signal<Bool?, NoError>, activeSessionsContext: Signal<ActiveSessionsContext?, NoError>, webSessionsContext: Signal<WebSessionsContext?, NoError>) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.cancel = cancel
        self.pushController = pushController
        self.presentController = presentController
        self.getNavigationController = getNavigationController
        self.resolvedFaqUrl = resolvedFaqUrl
        self.exceptionsList = exceptionsList
        self.archivedStickerPacks = archivedStickerPacks
        self.privacySettings = privacySettings
        self.hasTwoStepAuth = hasTwoStepAuth
        self.activeSessionsContext = activeSessionsContext
        self.webSessionsContext = webSessionsContext
        
        super.init()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: SettingsSearchContainerNode(context: self.context, openResult: { [weak self] result in
            if let strongSelf = self {
                result.present(strongSelf.context, strongSelf.getNavigationController?(), { [weak self] mode, controller in
                    if let strongSelf = self {
                        switch mode {
                            case .push:
                                if let controller = controller {
                                    strongSelf.pushController(controller)
                                }
                            case .modal:
                                if let controller = controller {
                                    strongSelf.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet, completion: { [weak self] in
                                        self?.cancel()
                                    }))
                                }
                            case .immediate:
                                if let controller = controller {
                                    strongSelf.presentController(controller, nil)
                                }
                            case .dismiss:
                                strongSelf.cancel()
                        }
                    }
                })
            }
        }, resolvedFaqUrl: self.resolvedFaqUrl, exceptionsList: self.exceptionsList, archivedStickerPacks: self.archivedStickerPacks, privacySettings: self.privacySettings, hasTwoStepAuth: self.hasTwoStepAuth, activeSessionsContext: self.activeSessionsContext, webSessionsContext: self.webSessionsContext), cancel: { [weak self] in
            self?.cancel()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.addSubnode(subnode)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    var isSearching: Bool {
        return self.searchDisplayController != nil
    }
    
    override func scrollToTop() {
        self.searchDisplayController?.contentNode.scrollToTop()
    }
    
    override func queryUpdated(_ query: String) {
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchDisplayController = self.searchDisplayController, let result = searchDisplayController.contentNode.hitTest(self.view.convert(point, to: searchDisplayController.contentNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}

