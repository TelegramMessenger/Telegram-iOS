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
import AccountContext
import ShareController
import SearchBarNode
import SearchUI

private enum LanguageListSection: ItemListSectionId {
    case official
    case unofficial
}

private enum LanguageListEntryId: Hashable {
    case search
    case localization(String)
}

private enum LanguageListEntryType {
    case official
    case unofficial
}

private enum LanguageListEntry: Comparable, Identifiable {
    case localization(index: Int, info: LocalizationInfo, type: LanguageListEntryType, selected: Bool, activity: Bool, revealed: Bool, editing: Bool)
    
    var stableId: LanguageListEntryId {
        switch self {
            case let .localization(_, info, _, _, _, _, _):
                return .localization(info.languageCode)
        }
    }
    
    private func index() -> Int {
        switch self {
            case let .localization(index, _, _, _, _, _, _):
                return index
        }
    }
    
    static func <(lhs: LanguageListEntry, rhs: LanguageListEntry) -> Bool {
       return lhs.index() < rhs.index()
    }
    
    func item(theme: PresentationTheme, strings: PresentationStrings, searchMode: Bool, openSearch: @escaping () -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void) -> ListViewItem {
        switch self {
            case let .localization(_, info, type, selected, activity, revealed, editing):
                return LocalizationListItem(theme: theme, strings: strings, id: info.languageCode, title: info.title, subtitle: info.localizedTitle, checked: selected, activity: activity, editing: LocalizationListItemEditing(editable: !selected && !searchMode && !info.isOfficial, editing: editing, revealed: !selected && revealed, reorderable: false), sectionId: type == .official ? LanguageListSection.official.rawValue : LanguageListSection.unofficial.rawValue, alwaysPlain: searchMode, action: {
                    selectLocalization(info)
                }, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem)
        }
    }
}

private struct LocalizationListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedLanguageListSearchContainerTransition(theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [LanguageListEntry], to toEntries: [LanguageListEntry], selectLocalization: @escaping (LocalizationInfo) -> Void, isSearching: Bool, forceUpdate: Bool) -> LocalizationListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, searchMode: true, openSearch: {}, selectLocalization: selectLocalization, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in }), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, searchMode: true, openSearch: {}, selectLocalization: selectLocalization, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in }), directionHint: nil) }
    
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
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(context: AccountContext, listState: LocalizationListState, selectLocalization: @escaping (LocalizationInfo) -> Void, applyingCode: Signal<String?, NoError>) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.listNode = ListView()
        
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
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), foundItems, self.themeAndStringsPromise.get(), applyingCode).start(next: { [weak self] items, themeAndStrings, applyingCode in
            guard let strongSelf = self else {
                return
            }
            var entries: [LanguageListEntry] = []
            if let items = items {
                for item in items {
                    entries.append(.localization(index: entries.count, info: item, type: .official, selected: themeAndStrings.1.primaryComponent.languageCode == item.languageCode, activity: applyingCode == item.languageCode, revealed: false, editing: false))
                }
            }
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, themeAndStrings.0, themeAndStrings.1))
            let transition = preparedLanguageListSearchContainerTransition(theme: themeAndStrings.0, strings: themeAndStrings.1, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, selectLocalization: selectLocalization, isSearching: items != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== themeAndStrings.0 || previousEntriesAndPresentationData?.2 !== themeAndStrings.1)
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
                        strongSelf.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings)))
                    }
                }
            })
        
        self.listNode.beganInteractiveDragging = { [weak self] in
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
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut, .custom:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: nil)
        }
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
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
    let animated: Bool
}

private func preparedLanguageListNodeTransition(theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [LanguageListEntry], to toEntries: [LanguageListEntry], openSearch: @escaping () -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void, firstTime: Bool, forceUpdate: Bool, animated: Bool) -> LanguageListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, searchMode: false, openSearch: openSearch, selectLocalization: selectLocalization, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, searchMode: false, openSearch: openSearch, selectLocalization: selectLocalization, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem), directionHint: nil) }
    
    return LanguageListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, animated: animated)
}

final class LocalizationListControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let navigationBar: NavigationBar
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: () -> Void
    private let present: (ViewController, Any?) -> Void
    
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    let listNode: ListView
    private var queuedTransitions: [LanguageListNodeTransition] = []
    
    private var searchDisplayController: SearchDisplayController?
    
    private let presentationDataValue = Promise<(PresentationTheme, PresentationStrings)>()
    private var updatedDisposable: Disposable?
    private var listDisposable: Disposable?
    private let applyDisposable = MetaDisposable()
    
    private var currentListState: LocalizationListState?
    private let applyingCode = Promise<String?>(nil)
    private let isEditing = ValuePromise<Bool>(false)
    private var isEditingValue: Bool = false {
        didSet {
            self.isEditing.set(self.isEditingValue)
        }
    }
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping () -> Void, updateCanStartEditing: @escaping (Bool?) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single((presentationData.theme, presentationData.strings)))
        self.navigationBar = navigationBar
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present

        self.listNode = ListView()
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.listNode)
        
        let openSearch: () -> Void = {
            requestActivateSearch()
        }
        
        let revealedCode = Promise<String?>(nil)
        var revealedCodeValue: String?
        let setItemWithRevealedOptions: (String?, String?) -> Void = { id, fromId in
            if (id == nil && fromId == revealedCodeValue) || (id != nil && fromId == nil) {
                revealedCodeValue = id
                revealedCode.set(.single(id))
            }
        }
        
        let removeItem: (String) -> Void = { id in
            let _ = (context.account.postbox.transaction { transaction -> Signal<LocalizationInfo?, NoError> in
                removeSavedLocalization(transaction: transaction, languageCode: id)
                let state = transaction.getPreferencesEntry(key: PreferencesKeys.localizationListState) as? LocalizationListState
                return context.sharedContext.accountManager.transaction { transaction -> LocalizationInfo? in
                    if let settings = transaction.getSharedData(SharedDataKeys.localizationSettings) as? LocalizationSettings, let state = state {
                        if settings.primaryComponent.languageCode == id {
                            for item in state.availableOfficialLocalizations {
                                if item.languageCode == "en" {
                                    return item
                                }
                            }
                        }
                    }
                    return nil
                }
            }
            |> switchToLatest
            |> deliverOnMainQueue).start(next: { [weak self] info in
                if revealedCodeValue == id {
                    revealedCodeValue = nil
                    revealedCode.set(.single(nil))
                }
                if let info = info {
                    self?.selectLocalization(info)
                }
            })
        }
        
        let preferencesKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.localizationListState]))
        let previousEntriesHolder = Atomic<([LanguageListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = combineLatest(queue: .mainQueue(), context.account.postbox.combinedView(keys: [preferencesKey]), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]), self.presentationDataValue.get(), self.applyingCode.get(), revealedCode.get(), self.isEditing.get()).start(next: { [weak self] view, sharedData, presentationData, applyingCode, revealedCode, isEditing in
            guard let strongSelf = self else {
                return
            }
            
            var entries: [LanguageListEntry] = []
            var activeLanguageCode: String?
            if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings] as? LocalizationSettings {
                activeLanguageCode = localizationSettings.primaryComponent.languageCode
            }
            var existingIds = Set<String>()
            if let localizationListState = (view.views[preferencesKey] as? PreferencesView)?.values[PreferencesKeys.localizationListState] as? LocalizationListState, !localizationListState.availableOfficialLocalizations.isEmpty {
                strongSelf.currentListState = localizationListState
                
                let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
                if availableSavedLocalizations.isEmpty {
                    updateCanStartEditing(nil)
                } else {
                    updateCanStartEditing(isEditing)
                }
                if !availableSavedLocalizations.isEmpty {
                    for info in availableSavedLocalizations {
                        if existingIds.contains(info.languageCode) {
                            continue
                        }
                        existingIds.insert(info.languageCode)
                        entries.append(.localization(index: entries.count, info: info, type: .unofficial, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: isEditing))
                    }
                }
                for info in localizationListState.availableOfficialLocalizations {
                    if existingIds.contains(info.languageCode) {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    entries.append(.localization(index: entries.count, info: info, type: .official, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: false))
                }
            }
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.0, presentationData.1))
            let transition = preparedLanguageListNodeTransition(theme: presentationData.0, strings: presentationData.1, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, openSearch: openSearch, selectLocalization: { [weak self] info in self?.selectLocalization(info) }, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem, firstTime: previousEntriesAndPresentationData == nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.0 || previousEntriesAndPresentationData?.2 !== presentationData.1, animated: (previousEntriesAndPresentationData?.0.count ?? 0) >= entries.count)
            strongSelf.enqueueTransition(transition)
        })
        self.updatedDisposable = synchronizedLocalizationListState(postbox: context.account.postbox, network: context.account.network).start()
    }
    
    deinit {
        self.listDisposable?.dispose()
        self.updatedDisposable?.dispose()
        self.applyDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataValue.set(.single((presentationData.theme, presentationData.strings)))
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        listInsets.left += layout.safeInsets.left
        listInsets.right += layout.safeInsets.right
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
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
                    case .easeInOut, .custom:
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
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: listViewCurve)
        
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
        if self.containerLayout != nil {
            while !self.queuedTransitions.isEmpty {
                let transition = self.queuedTransitions.removeFirst()
                
                var options = ListViewDeleteAndInsertOptions()
                if transition.firstTime {
                    options.insert(.Synchronous)
                    options.insert(.LowLatency)
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
    }
    
    private func selectLocalization(_ info: LocalizationInfo) -> Void {
        let applyImpl: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.applyingCode.set(.single(info.languageCode))
            strongSelf.applyDisposable.set((downloadAndApplyLocalization(accountManager: strongSelf.context.sharedContext.accountManager, postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, languageCode: info.languageCode)
                |> deliverOnMainQueue).start(completed: {
                    self?.applyingCode.set(.single(nil))
                }))
        }
        if info.isOfficial {
            applyImpl()
            return
        }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: info.localizedTitle))
        if self.presentationData.strings.primaryComponent.languageCode != info.languageCode {
            items.append(ActionSheetButtonItem(title: presentationData.strings.ApplyLanguage_ChangeLanguageAction, action: {
                dismissAction()
                applyImpl()
            }))
        }
        items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_ContextMenuShare, action: { [weak self] in
            dismissAction()
            guard let strongSelf = self else {
                return
            }
            let shareController = ShareController(context: strongSelf.context, subject: .url("https://t.me/setlanguage/\(info.languageCode)"))
            strongSelf.present(shareController, nil)
        }))
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.view.window?.endEditing(true)
        self.present(controller, nil)
    }
    
    func toggleEditing() {
        self.isEditingValue = !self.isEditingValue
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: LocalizationListSearchContainerNode(context: self.context, listState: self.currentListState ?? LocalizationListState.defaultSettings, selectLocalization: { [weak self] info in self?.selectLocalization(info) }, applyingCode: self.applyingCode.get()), cancel: { [weak self] in
            self?.requestDeactivateSearch()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: strongSelf.navigationBar)
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
