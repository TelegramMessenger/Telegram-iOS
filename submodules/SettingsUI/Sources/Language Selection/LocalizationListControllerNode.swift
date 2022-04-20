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
import ShareController
import SearchBarNode
import SearchUI
import UndoUI
import TelegramUIPreferences
import TranslateUI

private enum LanguageListSection: ItemListSectionId {
    case translate
    case official
    case unofficial
}

private enum LanguageListEntryId: Hashable {
    case search
    case translate(Int)
    case localizationTitle
    case localization(String)
}

private enum LanguageListEntryType {
    case official
    case unofficial
}

private enum LanguageListEntry: Comparable, Identifiable {
    case translateTitle(text: String)
    case translate(text: String, value: Bool)
    case doNotTranslate(text: String, value: String)
    case translateInfo(text: String)
    
    case localizationTitle(text: String, section: ItemListSectionId)
    case localization(index: Int, info: LocalizationInfo?, type: LanguageListEntryType, selected: Bool, activity: Bool, revealed: Bool, editing: Bool)
    
    var stableId: LanguageListEntryId {
        switch self {
            case .translateTitle:
                return .translate(0)
            case .translate:
                return .translate(1)
            case .doNotTranslate:
                return .translate(2)
            case .translateInfo:
                return .translate(3)
            case .localizationTitle:
                return .localizationTitle
            case let .localization(index, info, _, _, _, _, _):
                return .localization(info?.languageCode ?? "\(index)")
        }
    }
    
    private func index() -> Int {
        switch self {
            case .translateTitle:
                return 0
            case .translate:
                return 1
            case .doNotTranslate:
                return 2
            case .translateInfo:
                return 3
            case .localizationTitle:
                return 1000
            case let .localization(index, _, _, _, _, _, _):
                return 1001 + index
        }
    }
    
    static func <(lhs: LanguageListEntry, rhs: LanguageListEntry) -> Bool {
       return lhs.index() < rhs.index()
    }
    
    func item(presentationData: PresentationData, searchMode: Bool, openSearch: @escaping () -> Void, toggleShowTranslate: @escaping (Bool) -> Void, openDoNotTranslate: @escaping () -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void) -> ListViewItem {
        switch self {
            case let .translateTitle(text):
                return ItemListSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), text: text, sectionId: LanguageListSection.translate.rawValue)
            case let .translate(text, value):
                return ItemListSwitchItem(presentationData: ItemListPresentationData(presentationData), title: text, value: value, sectionId: LanguageListSection.translate.rawValue, style: .blocks, updated: { value in
                    toggleShowTranslate(value)
                })
            case let .doNotTranslate(text, value):
                return ItemListDisclosureItem(presentationData: ItemListPresentationData(presentationData), title: text, label: value, sectionId: LanguageListSection.translate.rawValue, style: .blocks, action: {
                    openDoNotTranslate()
                })
            case let .translateInfo(text):
                return ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(text), sectionId: LanguageListSection.translate.rawValue)
            case let .localizationTitle(text, section):
                return ItemListSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), text: text, sectionId: section)
            case let .localization(_, info, type, selected, activity, revealed, editing):
                return LocalizationListItem(presentationData: ItemListPresentationData(presentationData), id: info?.languageCode ?? "", title: info?.title ?? " ", subtitle: info?.localizedTitle ?? " ", checked: selected, activity: activity, loading: info == nil, editing: LocalizationListItemEditing(editable: !selected && !searchMode && !(info?.isOfficial ?? true), editing: editing, revealed: !selected && revealed, reorderable: false), sectionId: type == .official ? LanguageListSection.official.rawValue : LanguageListSection.unofficial.rawValue, alwaysPlain: searchMode, action: {
                    if let info = info {
                        selectLocalization(info)
                    }
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

private func preparedLanguageListSearchContainerTransition(presentationData: PresentationData, from fromEntries: [LanguageListEntry], to toEntries: [LanguageListEntry], selectLocalization: @escaping (LocalizationInfo) -> Void, isSearching: Bool, forceUpdate: Bool) -> LocalizationListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, openSearch: {}, toggleShowTranslate: { _ in }, openDoNotTranslate: {}, selectLocalization: selectLocalization, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in }), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, openSearch: {}, toggleShowTranslate: { _ in }, openDoNotTranslate: {}, selectLocalization: selectLocalization, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in }), directionHint: nil) }
    
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
    
    init(context: AccountContext, listState: LocalizationListState, selectLocalization: @escaping (LocalizationInfo) -> Void, applyingCode: Signal<String?, NoError>) {
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
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), foundItems, self.presentationDataPromise.get(), applyingCode).start(next: { [weak self] items, presentationData, applyingCode in
            guard let strongSelf = self else {
                return
            }
            var entries: [LanguageListEntry] = []
            if let items = items {
                for item in items {
                    entries.append(.localization(index: entries.count, info: item, type: .official, selected: presentationData.strings.primaryComponent.languageCode == item.languageCode, activity: applyingCode == item.languageCode, revealed: false, editing: false))
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

private func preparedLanguageListNodeTransition(presentationData: PresentationData, from fromEntries: [LanguageListEntry], to toEntries: [LanguageListEntry], openSearch: @escaping () -> Void, toggleShowTranslate: @escaping (Bool) -> Void, openDoNotTranslate: @escaping () -> Void, selectLocalization: @escaping (LocalizationInfo) -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void, firstTime: Bool, isLoading: Bool, forceUpdate: Bool, animated: Bool, crossfade: Bool) -> LanguageListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, openSearch: openSearch, toggleShowTranslate: toggleShowTranslate, openDoNotTranslate: openDoNotTranslate, selectLocalization: selectLocalization, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, openSearch: openSearch, toggleShowTranslate: toggleShowTranslate, openDoNotTranslate: openDoNotTranslate, selectLocalization: selectLocalization, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem), directionHint: nil) }
    
    return LanguageListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, isLoading: isLoading, animated: animated, crossfade: crossfade)
}

final class LocalizationListControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var navigationBar: NavigationBar?
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: () -> Void
    private let present: (ViewController, Any?) -> Void
    private let push: (ViewController) -> Void
    
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
    private let applyDisposable = MetaDisposable()
    
    private var currentListState: LocalizationListState?
    private let applyingCode = Promise<String?>(nil)
    private let isEditing = ValuePromise<Bool>(false)
    private var isEditingValue: Bool = false {
        didSet {
            self.isEditing.set(self.isEditingValue)
        }
    }
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping () -> Void, updateCanStartEditing: @escaping (Bool?) -> Void, present: @escaping (ViewController, Any?) -> Void, push: @escaping (ViewController) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.navigationBar = navigationBar
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present
        self.push = push

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
                let state = transaction.getPreferencesEntry(key: PreferencesKeys.localizationListState)?.get(LocalizationListState.self)
                return context.sharedContext.accountManager.transaction { transaction -> LocalizationInfo? in
                    if let settings = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self), let state = state {
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
        let previousState = Atomic<LocalizationListState?>(value: nil)
        let previousEntriesHolder = Atomic<([LanguageListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = combineLatest(queue: .mainQueue(), context.account.postbox.combinedView(keys: [preferencesKey]), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings, ApplicationSpecificSharedDataKeys.translationSettings]), self.presentationDataValue.get(), self.applyingCode.get(), revealedCode.get(), self.isEditing.get()).start(next: { [weak self] view, sharedData, presentationData, applyingCode, revealedCode, isEditing in
            guard let strongSelf = self else {
                return
            }
                        
            var entries: [LanguageListEntry] = []
            var activeLanguageCode: String?
            if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self) {
                activeLanguageCode = localizationSettings.primaryComponent.languageCode
            }
            var existingIds = Set<String>()
            
            var showTranslate = true
            var ignoredLanguages: [String] = []
            if let translationSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                showTranslate = translationSettings.showTranslate
                if let languages = translationSettings.ignoredLanguages {
                    ignoredLanguages = languages
                } else {
                    if let activeLanguageCode = activeLanguageCode, supportedTranslationLanguages.contains(activeLanguageCode) {
                        ignoredLanguages = [activeLanguageCode]
                    }
                }
            } else {
                if let activeLanguageCode = activeLanguageCode, supportedTranslationLanguages.contains(activeLanguageCode) {
                    ignoredLanguages = [activeLanguageCode]
                }
            }
            
            let localizationListState = (view.views[preferencesKey] as? PreferencesView)?.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self)
            if let localizationListState = localizationListState, !localizationListState.availableOfficialLocalizations.isEmpty {
                strongSelf.currentListState = localizationListState
                
                if #available(iOS 12.0, *) {
                    entries.append(.translateTitle(text: presentationData.strings.Localization_TranslateMessages.uppercased()))
                    entries.append(.translate(text: presentationData.strings.Localization_ShowTranslate, value: showTranslate))
                    if showTranslate {
                        var value = ""
                        if ignoredLanguages.count > 1 {
                            value = ignoredLanguages.joined(separator: ", ")
                        } else if let code = ignoredLanguages.first {
                            let enLocale = Locale(identifier: "en")
                            if let title = enLocale.localizedString(forLanguageCode: code) {
                                value = title
                            }
                        }
                        
                        entries.append(.doNotTranslate(text: presentationData.strings.Localization_DoNotTranslate, value: value))
                        entries.append(.translateInfo(text: ignoredLanguages.count > 1 ? presentationData.strings.Localization_DoNotTranslateManyInfo : presentationData.strings.Localization_DoNotTranslateInfo))
                    } else {
                        entries.append(.translateInfo(text: presentationData.strings.Localization_ShowTranslateInfoExtended))
                    }
                }
                
                let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
                if availableSavedLocalizations.isEmpty {
                    updateCanStartEditing(nil)
                } else {
                    updateCanStartEditing(isEditing)
                }
                if !availableSavedLocalizations.isEmpty {
                    entries.append(.localizationTitle(text: presentationData.strings.Localization_InterfaceLanguage.uppercased(), section: LanguageListSection.unofficial.rawValue))
                    for info in availableSavedLocalizations {
                        if existingIds.contains(info.languageCode) {
                            continue
                        }
                        existingIds.insert(info.languageCode)
                        entries.append(.localization(index: entries.count, info: info, type: .unofficial, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: isEditing))
                    }
                } else {
                    entries.append(.localizationTitle(text: presentationData.strings.Localization_InterfaceLanguage.uppercased(), section: LanguageListSection.official.rawValue))
                }
                for info in localizationListState.availableOfficialLocalizations {
                    if existingIds.contains(info.languageCode) {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    entries.append(.localization(index: entries.count, info: info, type: .official, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: false))
                }
            } else {
                for _ in 0 ..< 15 {
                    entries.append(.localization(index: entries.count, info: nil, type: .official, selected: false, activity: false, revealed: false, editing: false))
                }
            }
            
            let previousState = previousState.swap(localizationListState)
            
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedLanguageListNodeTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, openSearch: openSearch, toggleShowTranslate: { value in
                let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    var updated = current.withUpdatedShowTranslate(value)
                    if !value {
                        updated = updated.withUpdatedIgnoredLanguages(nil)
                    }
                    return updated
                }).start()
            }, openDoNotTranslate: { [weak self] in
                if let strongSelf = self {
                    strongSelf.push(translationSettingsController(context: strongSelf.context))
                }
            }, selectLocalization: { [weak self] info in self?.selectLocalization(info) }, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem, firstTime: previousEntriesAndPresentationData == nil, isLoading: entries.isEmpty, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings, animated: (previousEntriesAndPresentationData?.0.count ?? 0) != entries.count, crossfade: (previousState == nil) != (localizationListState == nil))
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
        self.applyDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
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
    
    private func selectLocalization(_ info: LocalizationInfo) -> Void {
        let applyImpl: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.applyingCode.set(.single(info.languageCode))
            strongSelf.applyDisposable.set((strongSelf.context.engine.localization.downloadAndApplyLocalization(accountManager: strongSelf.context.sharedContext.accountManager, languageCode: info.languageCode)
                |> deliverOnMainQueue).start(completed: {
                    self?.applyingCode.set(.single(nil))
                }))
        }
        if info.isOfficial {
            applyImpl()
            return
        }
        let controller = ActionSheetController(presentationData: presentationData)
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
            shareController.actionCompleted = { [weak self] in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }
            }
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
