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
import ComponentFlow
import BalancedTextComponent

private struct TimezoneListEntry: Comparable, Identifiable {
    var id: String
    var offset: Int
    var title: String
    
    var stableId: String {
        return self.id
    }
    
    static func <(lhs: TimezoneListEntry, rhs: TimezoneListEntry) -> Bool {
        if lhs.offset != rhs.offset {
            return lhs.offset < rhs.offset
        }
        if lhs.title != rhs.title {
            return lhs.title < rhs.title
        }
        return lhs.id < rhs.id
    }
    
    func item(presentationData: PresentationData, searchMode: Bool, action: @escaping (String) -> Void) -> ListViewItem {
        let hours = abs(self.offset / (60 * 60))
        let minutes = abs(self.offset % (60 * 60)) / 60
        let offsetString: String
        if minutes == 0 {
            offsetString = "UTC \(self.offset >= 0 ? "+" : "-")\(hours)"
        } else {
            let minutesString: String
            if minutes < 10 {
                minutesString = "0\(minutes)"
            } else {
                minutesString = "\(minutes)"
            }
            offsetString = "UTC \(self.offset >= 0 ? "+" : "-")\(hours):\(minutesString)"
        }
        
        return ItemListDisclosureItem(presentationData: ItemListPresentationData(presentationData), title: self.title, label: offsetString, sectionId: 0, style: .plain, disclosureStyle: .none, action: {
            action(self.id)
        })
    }
}

private struct TimezoneListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmptyResult: Bool
}

private func preparedLanguageListSearchContainerTransition(presentationData: PresentationData, from fromEntries: [TimezoneListEntry], to toEntries: [TimezoneListEntry], action: @escaping (String) -> Void, isSearching: Bool, forceUpdate: Bool) -> TimezoneListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, action: action), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: true, action: action), directionHint: nil) }
    
    return TimezoneListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmptyResult: isSearching && toEntries.isEmpty)
}

private final class TimezoneListSearchContainerNode: SearchDisplayControllerContentNode {
    private let timeZoneList: TimeZoneList
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var notFoundText: ComponentView<Empty>?
    
    private var enqueuedTransitions: [TimezoneListSearchContainerTransition] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<PresentationData>
    
    private var isEmptyResult: Bool = false
    private var currentLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    
    public override var hasDim: Bool {
        return true
    }
    
    init(context: AccountContext, timeZoneList: TimeZoneList, action: @escaping (String) -> Void) {
        self.timeZoneList = timeZoneList
        
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
        
        let querySplitCharacterSet: CharacterSet = CharacterSet(charactersIn: " /.+")
        
        let foundItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<[TimeZoneList.Item]?, NoError> in
            if let query, !query.isEmpty {
                let query = query.lowercased()
                
                return .single(timeZoneList.items.filter { item in
                    if item.id.lowercased().hasPrefix(query) {
                        return true
                    }
                    if item.title.lowercased().components(separatedBy: querySplitCharacterSet).contains(where: { $0.hasPrefix(query) }) {
                        return true
                    }
                    
                    return false
                })
            } else {
                return .single(nil)
            }
        }
        
        let previousEntriesHolder = Atomic<([TimezoneListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), foundItems, self.presentationDataPromise.get()).start(next: { [weak self] items, presentationData in
            guard let strongSelf = self else {
                return
            }
            var entries: [TimezoneListEntry] = []
            if let items {
                for item in items {
                    entries.append(TimezoneListEntry(
                        id: item.id,
                        offset: Int(item.utcOffset),
                        title: item.title
                    ))
                }
            }
            entries.sort()
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedLanguageListSearchContainerTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, action: action, isSearching: items != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
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
    
    private func enqueueTransition(_ transition: TimezoneListSearchContainerTransition) {
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
            let isEmptyResult = transition.isEmptyResult
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.listNode.isHidden = !isSearching
                self.dimNode.isHidden = isSearching
                self.isEmptyResult = isEmptyResult
                
                if let currentLayout = self.currentLayout {
                    self.containerLayoutUpdated(currentLayout.layout, navigationBarHeight: currentLayout.navigationBarHeight, transition: .immediate)
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayout = (layout, navigationBarHeight)
        
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
        
        if self.isEmptyResult {
            let notFoundText: ComponentView<Empty>
            if let current = self.notFoundText {
                notFoundText = current
            } else {
                notFoundText = ComponentView()
                self.notFoundText = notFoundText
            }
            let notFoundTextSize = notFoundText.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: self.presentationData.strings.Conversation_SearchNoResults, font: Font.regular(17.0), textColor: self.presentationData.theme.list.freeTextColor, paragraphAlignment: .center)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width - 16.0 * 2.0, height: layout.size.height)
            )
            let notFoundTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - notFoundTextSize.width) * 0.5), y: navigationBarHeight + floor((layout.size.height - navigationBarHeight - notFoundTextSize.height) * 0.5)), size: notFoundTextSize)
            if let notFoundTextView = notFoundText.view {
                if notFoundTextView.superview == nil {
                    self.view.addSubview(notFoundTextView)
                }
                notFoundTextView.frame = notFoundTextFrame
            }
        } else if let notFoundText = self.notFoundText {
            self.notFoundText = nil
            notFoundText.view?.removeFromSuperview()
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}

private struct TimezoneListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let isLoading: Bool
    let animated: Bool
    let crossfade: Bool
}

private func preparedTimezoneListNodeTransition(presentationData: PresentationData, from fromEntries: [TimezoneListEntry], to toEntries: [TimezoneListEntry], action: @escaping (String) -> Void, firstTime: Bool, isLoading: Bool, forceUpdate: Bool, animated: Bool, crossfade: Bool) -> TimezoneListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, action: action), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, searchMode: false, action: action), directionHint: nil) }
    
    return TimezoneListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, isLoading: isLoading, animated: animated, crossfade: crossfade)
}

private final class TimezoneData {
    struct Item {
        var id: String
        var offset: Int
        var title: String
        
        init(id: String, offset: Int, title: String) {
            self.id = id
            self.offset = offset
            self.title = title
        }
    }
    
    let items: [Item]
    
    init() {
        let locale = Locale.current
        var items: [Item] = []
        for (key, value) in TimeZone.abbreviationDictionary {
            guard let timezone = TimeZone(abbreviation: key) else {
                continue
            }
            if items.contains(where: { $0.id == timezone.identifier }) {
                continue
            }
            items.append(Item(
                id: timezone.identifier,
                offset: timezone.secondsFromGMT(),
                title: timezone.localizedName(for: .standard, locale: locale) ?? value
            ))
        }
        self.items = items
    }
}

final class TimezoneSelectionScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let action: (String) -> Void
    private var presentationData: PresentationData
    private weak var navigationBar: NavigationBar?
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: () -> Void
    private let present: (ViewController, Any?) -> Void
    private let push: (ViewController) -> Void
    private var timeZoneList: TimeZoneList?
    
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    let listNode: ListView
    private var queuedTransitions: [TimezoneListNodeTransition] = []
    private var searchDisplayController: SearchDisplayController?
    
    private let presentationDataValue = Promise<PresentationData>()
    
    private var listDisposable: Disposable?
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping () -> Void, action: @escaping (String) -> Void, present: @escaping (ViewController, Any?) -> Void, push: @escaping (ViewController) -> Void) {
        self.context = context
        self.action = action
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.navigationBar = navigationBar
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present
        self.push = push

        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        self.addSubnode(self.listNode)
        
        let previousEntriesHolder = Atomic<([TimezoneListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = (combineLatest(queue: .mainQueue(),
            self.presentationDataValue.get(),
            context.engine.accountData.cachedTimeZoneList()
        )
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, timeZoneList in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.timeZoneList = timeZoneList
            
            var entries: [TimezoneListEntry] = []
            if let timeZoneList {
                for item in timeZoneList.items {
                    entries.append(TimezoneListEntry(
                        id: item.id,
                        offset: Int(item.utcOffset),
                        title: item.title
                    ))
                }
            }
            entries.sort()
            
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedTimezoneListNodeTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, action: action, firstTime: previousEntriesAndPresentationData == nil, isLoading: entries.isEmpty, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings, animated: false, crossfade: false)
            strongSelf.enqueueTransition(transition)
        })
    }
    
    deinit {
        self.listDisposable?.dispose()
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
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        
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
    
    private func enqueueTransition(_ transition: TimezoneListNodeTransition) {
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
        guard let timeZoneList = self.timeZoneList else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: TimezoneListSearchContainerNode(context: self.context, timeZoneList: timeZoneList, action: self.action), inline: true, cancel: { [weak self] in
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
