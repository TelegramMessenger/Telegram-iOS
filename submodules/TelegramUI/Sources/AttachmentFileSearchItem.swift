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
import ListMessageItem

private let searchBarFont = Font.regular(17.0)

private final class AttachmentFileSearchNavigationContentNode: NavigationBarContentNode, ItemListControllerSearchNavigationContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let focus: () -> Void
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    var activity: Bool = false {
        didSet {
            self.searchBar.activity = activity
        }
    }
    init(theme: PresentationTheme, strings: PresentationStrings, focus: @escaping () -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(@escaping(Bool)->Void) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.focus = focus
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
        
        self.searchBar.focusUpdated = { [weak self] focus in
            if focus {
                self?.focus()
            }
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
        self.searchBar.placeholderString = NSAttributedString(string: self.strings.Attachment_FilesSearchPlaceholder, font: searchBarFont, textColor: self.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
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


final class AttachmentFileSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let presentationData: PresentationData
    let focus: () -> Void
    let cancel: () -> Void
    let send: (Message) -> Void
    let dismissInput: () -> Void
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData, focus: @escaping () -> Void, cancel: @escaping () -> Void, send: @escaping (Message) -> Void, dismissInput: @escaping () -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.focus = focus
        self.cancel = cancel
        self.send = send
        self.dismissInput = dismissInput
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
        if let to = to as? AttachmentFileSearchItem {
            if self.context !== to.context {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let presentationData = self.presentationData
        if let current = current as? AttachmentFileSearchNavigationContentNode {
            current.updateTheme(presentationData.theme)
            return current
        } else {
            return AttachmentFileSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, focus: self.focus, cancel: self.cancel, updateActivity: { [weak self] value in
                self?.updateActivity = value
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return AttachmentFileSearchItemNode(context: self.context, send: self.send, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        }, dismissInput: self.dismissInput)
    }
}

private final class AttachmentFileSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: AttachmentFileSearchContainerNode
    
    init(context: AccountContext, send: @escaping (Message) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, dismissInput: @escaping () -> Void) {
        self.containerNode = AttachmentFileSearchContainerNode(context: context, forceTheme: nil, send: { message in
            send(message)
        }, updateActivity: updateActivity)
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


private final class AttachmentFileSearchContainerInteraction {
    let context: AccountContext
    let send: (Message) -> Void
    
    init(context: AccountContext, send: @escaping (Message) -> Void) {
        self.context = context
        self.send = send
    }
}

private enum AttachmentFileSearchEntryId: Hashable {
    case placeholder(Int)
    case message(MessageId)
}

private func areMessagesEqual(_ lhsMessage: Message?, _ rhsMessage: Message?) -> Bool {
    guard let lhsMessage = lhsMessage, let rhsMessage = rhsMessage else {
        return lhsMessage == nil && rhsMessage == nil
    }
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private final class AttachmentFileSearchEntry: Comparable, Identifiable {
    let index: Int
    let message: Message?
    
    init(index: Int, message: Message?) {
        self.index = index
        self.message = message
    }
    
    var stableId: AttachmentFileSearchEntryId {
        if let message = self.message {
            return .message(message.id)
        } else {
            return .placeholder(self.index)
        }
    }
    
    static func ==(lhs: AttachmentFileSearchEntry, rhs: AttachmentFileSearchEntry) -> Bool {
        return lhs.index == rhs.index && areMessagesEqual(lhs.message, rhs.message)
    }
    
    static func <(lhs: AttachmentFileSearchEntry, rhs: AttachmentFileSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: AttachmentFileSearchContainerInteraction) -> ListViewItem {
        let itemInteraction = ListMessageItemInteraction(openMessage: { message, _ in
            interaction.send(message)
            return false
        }, openMessageContextMenu: { _, _, _, _, _ in }, toggleMessagesSelection: { _, _ in }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })
        return ListMessageItem(presentationData: ChatPresentationData(presentationData: interaction.context.sharedContext.currentPresentationData.with({$0})), context: interaction.context, chatLocation: .peer(id: PeerId(0)), interaction: itemInteraction, message: message, selection: .none, displayHeader: true, displayFileInfo: false, displayBackground: true, style: .plain)
    }
}

struct AttachmentFileSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmpty: Bool
    let query: String
}

private func attachmentFileSearchContainerPreparedRecentTransition(from fromEntries: [AttachmentFileSearchEntry], to toEntries: [AttachmentFileSearchEntry], isSearching: Bool, isEmpty: Bool, query: String, context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: AttachmentFileSearchContainerInteraction) -> AttachmentFileSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return AttachmentFileSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmpty: isEmpty, query: query)
}


public final class AttachmentFileSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let send: (Message) -> Void
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedTransitions: [(AttachmentFileSearchContainerTransition, Bool)] = []
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
        
    public init(context: AccountContext, forceTheme: PresentationTheme?, send: @escaping (Message) -> Void, updateActivity: @escaping (Bool) -> Void) {
        self.context = context
        self.send = send
        
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
        
    
        let interaction = AttachmentFileSearchContainerInteraction(context: context, send: { [weak self] message in
            send(message)
            self?.listNode.clearHighlightAnimated(true)
        })
        
        let presentationDataPromise = self.presentationDataPromise
                
        let searchQuery = self.searchQuery.get()
        |> mapToSignal { query -> Signal<String?, NoError> in
            if let query = query, !query.isEmpty {
                return (.complete() |> delay(0.6, queue: Queue.mainQueue()))
                |> then(.single(query))
            } else {
                return .single(query)
            }
        }
        
        let foundItems = searchQuery
        |> mapToSignal { query -> Signal<[AttachmentFileSearchEntry]?, NoError> in
            guard let query = query, !query.isEmpty else {
                return .single(nil)
            }
            
            let signal: Signal<[Message]?, NoError> = .single(nil)
            |> then(
                context.engine.messages.searchMessages(location: .sentMedia(tags: [.file]), query: query, state: nil)
                |> map { result -> [Message]? in
                    return result.0.messages
                }
            )
            updateActivity(true)

            return combineLatest(signal, presentationDataPromise.get())
            |> mapToSignal { messages, presentationData -> Signal<[AttachmentFileSearchEntry]?, NoError> in
                var entries: [AttachmentFileSearchEntry] = []
                var index = 0
                if let messages = messages {
                    for message in messages {
                        entries.append(AttachmentFileSearchEntry(index: index, message: message))
                        index += 1
                    }
                } else {
                    for _ in 0 ..< 2 {
                        entries.append(AttachmentFileSearchEntry(index: index, message: nil))
                        index += 1
                    }
                }
                return .single(entries)
            }
        }
        
        let previousSearchItems = Atomic<[AttachmentFileSearchEntry]?>(value: nil)
        self.searchDisposable.set((combineLatest(searchQuery, foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] query, entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                updateActivity(false)
                let firstTime = previousEntries == nil
                let transition = attachmentFileSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: query ?? "", context: context, presentationData: presentationData, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, interaction: interaction)
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
    
    private func enqueueTransition(_ transition: AttachmentFileSearchContainerTransition, firstTime: Bool) {
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
