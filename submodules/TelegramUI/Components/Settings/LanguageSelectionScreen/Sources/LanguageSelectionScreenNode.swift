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
import TelegramUIPreferences
import TranslateUI

private enum LanguageListSection: ItemListSectionId {
    case official
    case unofficial
}

private enum LanguageListEntryId: Hashable {
    case localizationTitle
    case localization(String)
}

private enum LanguageListEntryType {
    case official
    case unofficial
}

private enum LanguageListEntry: Comparable, Identifiable {
    case localizationTitle(text: String, section: ItemListSectionId)
    case localization(index: Int, info: LocalizationInfo?, type: LanguageListEntryType, isEnabled: Bool)
    
    var stableId: LanguageListEntryId {
        switch self {
        case .localizationTitle:
            return .localizationTitle
        case let .localization(index, info, _, _):
            return .localization(info?.languageCode ?? "\(index)")
        }
    }
    
    private func index() -> Int {
        switch self {
        case .localizationTitle:
            return 1000
        case let .localization(index, _, _, _):
            return 1001 + index
        }
    }
    
    static func <(lhs: LanguageListEntry, rhs: LanguageListEntry) -> Bool {
       return lhs.index() < rhs.index()
    }
    
    func item(presentationData: PresentationData, searchMode: Bool, openSearch: @escaping () -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void) -> ListViewItem {
        switch self {
        case let .localizationTitle(text, section):
            return ItemListSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), text: text, sectionId: section)
        case let .localization(_, info, type, isEnabled):
            return LocalizationListItem(presentationData: ItemListPresentationData(presentationData), id: info?.languageCode ?? "", title: info?.title ?? " ", subtitle: info?.localizedTitle ?? " ", checked: false, activity: false, loading: info == nil, editing: LocalizationListItemEditing(editable: false, editing: false, revealed: false, reorderable: false), enabled: isEnabled, sectionId: type == .official ? LanguageListSection.official.rawValue : LanguageListSection.unofficial.rawValue, alwaysPlain: searchMode, action: {
                if let info {
                    selectLocalization(info)
                }
            }, setItemWithRevealedOptions: nil, removeItem: nil)
        }
    }
}

private struct LocalizationListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedLanguageListSearchContainerTransition(presentationData: PresentationData, from fromEntries: [LanguageListEntry], to toEntries: [LanguageListEntry], selectLocalization: @escaping (LocalizationInfo) -> Void, isSearching: Bool, forceUpdate: Bool) -> LocalizationListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, openSearch: {}, selectLocalization: selectLocalization), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, openSearch: {}, selectLocalization: selectLocalization), directionHint: nil) }
    
    return LocalizationListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private final class LocalizationListSearchContainerNode: SearchDisplayControllerContentNode {
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [LocalizationListSearchContainerTransition] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<PresentationData>
    
    public override var hasDim: Bool {
        return true
    }
    
    init(context: AccountContext, listState: LocalizationListState, excludedIds: [String], selectLocalization: @escaping (LocalizationInfo) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        let foundItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<[LocalizationInfo]?, NoError> in
            if let query = query, !query.isEmpty {
                let normalizedQuery = query.lowercased()
                var result: [LocalizationInfo] = []
                var uniqueIds = Set<String>()
                for info in listState.availableSavedLocalizations + listState.availableOfficialLocalizations {
                    if info.title.lowercased().hasPrefix(normalizedQuery) || info.localizedTitle.lowercased().hasPrefix(normalizedQuery) {
                        if uniqueIds.contains(info.languageCode) {
                           continue
                        }
                        uniqueIds.insert(info.languageCode)
                        result.append(info)
                    }
                }
                return .single(result)
            } else {
                return .single(nil)
            }
        }
        
        let previousEntriesHolder = Atomic<([LanguageListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), foundItems, self.presentationDataPromise.get()).start(next: { [weak self] items, presentationData in
            guard let strongSelf = self else {
                return
            }
            var entries: [LanguageListEntry] = []
            if let items = items {
                for item in items {
                    entries.append(.localization(index: entries.count, info: item, type: .official, isEnabled: !excludedIds.contains(item.languageCode)))
                }
            }
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedLanguageListSearchContainerTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, selectLocalization: selectLocalization, isSearching: items != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
            strongSelf.enqueueTransition(transition)
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
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: LocalizationListSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransitions()
            }
        }
    }
    
    private func dequeueTransitions() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransitions()
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}

private struct LanguageListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let isLoading: Bool
    let animated: Bool
    let crossfade: Bool
}

private func preparedLanguageListNodeTransition(
    presentationData: PresentationData,
    from fromEntries: [LanguageListEntry],
    to toEntries: [LanguageListEntry],
    openSearch: @escaping () -> Void,
    selectLocalization: @escaping (LocalizationInfo) -> Void,
    firstTime: Bool,
    isLoading: Bool,
    forceUpdate: Bool,
    animated: Bool,
    crossfade: Bool
) -> LanguageListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, openSearch: openSearch, selectLocalization: selectLocalization), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, openSearch: openSearch, selectLocalization: selectLocalization), directionHint: nil) }
    
    return LanguageListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, isLoading: isLoading, animated: animated, crossfade: crossfade)
}

final class LanguageSelectionScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var navigationBar: NavigationBar?
    private let excludeIds: [String]
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: () -> Void
    private let present: (ViewController, Any?) -> Void
    private let push: (ViewController) -> Void
    private let selectLocalization: (LocalizationInfo) -> Void
    
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    private var queuedTransitions: [LanguageListNodeTransition] = []
    private var searchDisplayController: SearchDisplayController?
    
    private let presentationDataValue = Promise<PresentationData>()
    private var updatedDisposable: Disposable?
    private var listDisposable: Disposable?
    
    private var currentListState: LocalizationListState?
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, excludeIds: [String], requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping () -> Void, present: @escaping (ViewController, Any?) -> Void, push: @escaping (ViewController) -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.navigationBar = navigationBar
        self.excludeIds = excludeIds
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present
        self.push = push
        self.selectLocalization = selectLocalization

        self.listNode = ListView()
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.list.blocksBackgroundColor, direction: true)
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.listNode)
        
        let openSearch: () -> Void = {
            requestActivateSearch()
        }
                
        let previousState = Atomic<LocalizationListState?>(value: nil)
        let previousEntriesHolder = Atomic<([LanguageListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = combineLatest(
            queue: .mainQueue(),
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.LocalizationList()),
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
            context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings, ApplicationSpecificSharedDataKeys.translationSettings]),
            self.presentationDataValue.get()
        ).start(next: { [weak self] localizationListState, peer, sharedData, presentationData in
            guard let strongSelf = self else {
                return
            }
            
            var entries: [LanguageListEntry] = []
            var existingIds = Set<String>()
            
            if !localizationListState.availableOfficialLocalizations.isEmpty {
                strongSelf.currentListState = localizationListState
                
                let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
                if !availableSavedLocalizations.isEmpty {
                    for info in availableSavedLocalizations {
                        if existingIds.contains(info.languageCode) {
                            continue
                        }
                        existingIds.insert(info.languageCode)
                        entries.append(.localization(index: entries.count, info: info, type: .unofficial, isEnabled: !strongSelf.excludeIds.contains(info.languageCode)))
                    }
                }
                for info in localizationListState.availableOfficialLocalizations {
                    if existingIds.contains(info.languageCode) {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    entries.append(.localization(index: entries.count, info: info, type: .official, isEnabled: !strongSelf.excludeIds.contains(info.languageCode)))
                }
            } else {
                for _ in 0 ..< 15 {
                    entries.append(.localization(index: entries.count, info: nil, type: .official, isEnabled: true))
                }
            }
            
            let previousState = previousState.swap(localizationListState)
            
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedLanguageListNodeTransition(
                presentationData: presentationData,
                from: previousEntriesAndPresentationData?.0 ?? [],
                to: entries,
                openSearch: openSearch,
                selectLocalization: { [weak self] info in
                    self?.selectLocalization(info)
                },
                firstTime: previousEntriesAndPresentationData == nil,
                isLoading: entries.isEmpty,
                forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings,
                animated: (previousEntriesAndPresentationData?.0.count ?? 0) != entries.count,
                crossfade: (previousState == nil || previousState!.availableOfficialLocalizations.isEmpty) != localizationListState.availableOfficialLocalizations.isEmpty
            )
            strongSelf.enqueueTransition(transition)
        })
        self.updatedDisposable = context.engine.localization.synchronizedLocalizationListState().start()
        
        self.listNode.itemNodeHitTest = { [weak self] point in
            if let strongSelf = self {
                return point.x > strongSelf.leftOverlayNode.frame.maxX && point.x < strongSelf.rightOverlayNode.frame.minX
            } else {
                return true
            }
        }
    }
    
    deinit {
        self.listDisposable?.dispose()
        self.updatedDisposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        let stringsUpdated = self.presentationData.strings !== presentationData.strings
        self.presentationData = presentationData
    
        if stringsUpdated {
            if let snapshotView = self.view.snapshotView(afterScreenUpdates: false) {
                self.view.addSubview(snapshotView)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
        }
        
        self.presentationDataValue.set(.single(presentationData))
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.list.blocksBackgroundColor, direction: true)
        self.searchDisplayController?.updatePresentationData(presentationData)
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        if layout.size.width >= 375.0 {
            let inset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
            listInsets.left += inset
            listInsets.right += inset
        } else {
            listInsets.left += layout.safeInsets.left
            listInsets.right += layout.safeInsets.right
        }
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: listInsets.left, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - listInsets.right, y: 0.0, width: listInsets.right, height: layout.size.height)
        
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.listNode)
        }
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.listNode)
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: LanguageListNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        guard let _ = self.containerLayout else {
            return
        }
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            } else if transition.crossfade {
                options.insert(.AnimateCrossfade)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            })
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(
            presentationData: self.presentationData,
            contentNode: LocalizationListSearchContainerNode(
                context: self.context,
                listState: self.currentListState ?? LocalizationListState.defaultSettings,
                excludedIds: self.excludeIds,
                selectLocalization: { [weak self] info in
                    self?.selectLocalization(info)
                }),
            inline: true,
            cancel: { [weak self] in
                self?.requestDeactivateSearch()
            }
        )
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else if let navigationBar = strongSelf.navigationBar  {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
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
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
