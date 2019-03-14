import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

extension NavigationBarSearchContentNode: ItemListControllerSearchNavigationContentNode {
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
    }
}

extension SettingsSearchableItemIcon {
    func image() -> UIImage? {
        switch self {
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
        case .support:
            return PresentationResourcesSettings.support
        case .faq:
            return PresentationResourcesSettings.faq
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
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, theme: PresentationTheme, placeholder: String, activated: Bool, updateActivated: @escaping (Bool) -> Void, presentController: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.context = context
        self.theme = theme
        self.placeholder = placeholder
        self.activated = activated
        self.updateActivated = updateActivated
        self.presentController = presentController
        self.pushController = pushController
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
            return NavigationBarSearchContentNode(theme: presentationData.theme, placeholder: presentationData.strings.Common_Search, activate: { [weak self] in
                updateActivated(true)
            })
//            return GroupInfoSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, mode: self.searchMode, cancel: self.cancel, updateActivity: { [weak self] value in
//                self?.updateActivity = value
//            })
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
            })
        }
    }
}

private enum SettingsSearchItemId: Hashable {
    case result(SettingsSearchableItemId)
    case faq(String)
}

private enum SettingsSearchEntry: Comparable, Identifiable {
    case result(index: Int, item: SettingsSearchableItem, title: String, breadcrumbs: [String], icon: UIImage?)
    
    var stableId: SettingsSearchItemId {
        switch self {
            case let .result(_, item, _, _, _):
                return .result(item.id)
        }
    }
    
    private func index() -> Int {
        switch self {
            case let .result(index, _, _, _, _):
                return index
        }
    }
    
    static func <(lhs: SettingsSearchEntry, rhs: SettingsSearchEntry) -> Bool {
        return lhs.index() < rhs.index()
    }
    
    static func == (lhs: SettingsSearchEntry, rhs: SettingsSearchEntry) -> Bool {
        if case let .result(lhsIndex, _, lhsTitle, lhsBreadcrumbs, _) = lhs {
            if case let .result(rhsIndex, _, rhsTitle, rhsBreadcrumbs, _) = rhs, lhsIndex == rhsIndex, lhsTitle == rhsTitle, lhsBreadcrumbs == rhsBreadcrumbs {
                return true
            }
        }
        return false
    }
    
    func item(theme: PresentationTheme, strings: PresentationStrings, openResult: @escaping (SettingsSearchableItem) -> Void)  -> ListViewItem {
        switch self {
            case let .result(_, item, title, breadcrumbs, icon):
                return SettingsSearchResultItem(theme: theme, strings: strings, title: title, breadcrumbs: breadcrumbs, icon: icon, action: {
                    openResult(item)
                }, sectionId: 0)
        }
    }
}

private struct SettingsSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedSettingsSearchContainerTransition(theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [SettingsSearchEntry], to toEntries: [SettingsSearchEntry], openResult: @escaping (SettingsSearchableItem) -> Void, isSearching: Bool, forceUpdate: Bool) -> SettingsSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, openResult: openResult), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: theme, strings: strings, openResult: openResult), directionHint: nil) }
    
    return SettingsSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private final class SettingsSearchContainerNode: SearchDisplayControllerContentNode {
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [SettingsSearchContainerTransition] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(context: AccountContext, listState: LocalizationListState, openResult: @escaping (SettingsSearchableItem) -> Void) {
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
        
        let foundItems = combineLatest(settingsSearchableItems(context: context), faqSearchableItems(context: context))
        |> mapToSignal { searchableItems, faqSearchableItems -> Signal<[SettingsSearchableItem]?, NoError> in
            return self.searchQuery.get()
            |> mapToSignal { query -> Signal<[SettingsSearchableItem]?, NoError> in
                if let query = query, !query.isEmpty {
                    let result = searchSettingsItems(items: searchableItems, query: query)
                    let faqResults = searchSettingsItems(items: faqSearchableItems, query: query)
                    return .single(result + faqResults)
                } else {
                    return .single(nil)
                }
            }
        }
        
        let previousEntriesHolder = Atomic<([SettingsSearchEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), foundItems, self.themeAndStringsPromise.get()).start(next: { [weak self] items, themeAndStrings in
            guard let strongSelf = self else {
                return
            }
            var entries: [SettingsSearchEntry] = []
            if let items = items {
                var previousIcon: SettingsSearchableItemIcon?
                for item in items {
                    var image: UIImage?
                    if previousIcon != item.icon {
                        image = item.icon.image()
                    }
                    entries.append(.result(index: entries.count, item: item, title: item.title, breadcrumbs: item.breadcrumbs, icon: image))
                    previousIcon = item.icon
                }
            }
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, themeAndStrings.0, themeAndStrings.1))
            let transition = preparedSettingsSearchContainerTransition(theme: themeAndStrings.0, strings: themeAndStrings.1, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, openResult: openResult, isSearching: items != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== themeAndStrings.0 || previousEntriesAndPresentationData?.2 !== themeAndStrings.1)
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

private final class SettingsSearchItemNode: ItemListControllerSearchNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var searchDisplayController: SearchDisplayController?
    
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, Any?) -> Void
    
    var cancel: () -> Void
    
    init(context: AccountContext, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.pushController = pushController
        self.presentController = presentController
    
        self.cancel = cancel
        
        super.init()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: SettingsSearchContainerNode(context: self.context, listState: LocalizationListState.defaultSettings, openResult: { [weak self] result in
            if let strongSelf = self {
                result.present(strongSelf.context, { [weak self] mode, controller in
                    if let strongSelf = self {
                        switch mode {
                            case .push:
                                strongSelf.pushController(controller)
                            case .modal:
                                strongSelf.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            case .immediate:
                                strongSelf.presentController(controller, nil)
                        }
                    }
                })
            }
        }), cancel: { [weak self] in
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
    
    override func queryUpdated(_ query: String) {
        //self.containerNode.searchTextUpdated(text: query)
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

