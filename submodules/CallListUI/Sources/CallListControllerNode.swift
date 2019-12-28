import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramNotices

private struct CallListNodeListViewTransition {
    let callListView: CallListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

private extension CallListViewEntry {
    var lowestIndex: MessageIndex {
        switch self {
            case let .hole(index):
                return index
            case let .message(_, messages):
                var lowest = messages[0].index
                for i in 1 ..< messages.count {
                    let index = messages[i].index
                    if index < lowest {
                        lowest = index
                    }
                }
                return lowest
        }
    }
    
    var highestIndex: MessageIndex {
        switch self {
        case let .hole(index):
            return index
        case let .message(_, messages):
            var highest = messages[0].index
            for i in 1 ..< messages.count {
                let index = messages[i].index
                if index > highest {
                    highest = index
                }
            }
            return highest
        }
    }
}

final class CallListNodeInteraction {
    let setMessageIdWithRevealedOptions: (MessageId?, MessageId?) -> Void
    let call: (PeerId) -> Void
    let openInfo: (PeerId, [Message]) -> Void
    let delete: ([MessageId]) -> Void
    let updateShowCallsTab: (Bool) -> Void
    
    init(setMessageIdWithRevealedOptions: @escaping (MessageId?, MessageId?) -> Void, call: @escaping (PeerId) -> Void, openInfo: @escaping (PeerId, [Message]) -> Void, delete: @escaping ([MessageId]) -> Void, updateShowCallsTab: @escaping (Bool) -> Void) {
        self.setMessageIdWithRevealedOptions = setMessageIdWithRevealedOptions
        self.call = call
        self.openInfo = openInfo
        self.delete = delete
        self.updateShowCallsTab = updateShowCallsTab
    }
}

struct CallListNodeState: Equatable {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let disableAnimations: Bool
    let editing: Bool
    let messageIdWithRevealedOptions: MessageId?
    
    func withUpdatedPresentationData(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, disableAnimations: Bool) -> CallListNodeState {
        return CallListNodeState(presentationData: presentationData, dateTimeFormat: dateTimeFormat, disableAnimations: disableAnimations, editing: self.editing, messageIdWithRevealedOptions: self.messageIdWithRevealedOptions)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> CallListNodeState {
        return CallListNodeState(presentationData: self.presentationData, dateTimeFormat: self.dateTimeFormat, disableAnimations: self.disableAnimations, editing: editing, messageIdWithRevealedOptions: self.messageIdWithRevealedOptions)
    }
    
    func withUpdatedMessageIdWithRevealedOptions(_ messageIdWithRevealedOptions: MessageId?) -> CallListNodeState {
        return CallListNodeState(presentationData: self.presentationData, dateTimeFormat: self.dateTimeFormat, disableAnimations: self.disableAnimations, editing: self.editing, messageIdWithRevealedOptions: messageIdWithRevealedOptions)
    }
    
    static func ==(lhs: CallListNodeState, rhs: CallListNodeState) -> Bool {
        if lhs.presentationData != rhs.presentationData {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.messageIdWithRevealedOptions != rhs.messageIdWithRevealedOptions {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(context: AccountContext, presentationData: ItemListPresentationData, showSettings: Bool, nodeInteraction: CallListNodeInteraction, entries: [CallListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .displayTab(theme, text, value):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: 0, style: .blocks, updated: { value in
                    nodeInteraction.updateShowCallsTab(value)
                }), directionHint: entry.directionHint)
            case let .displayTabInfo(theme, text):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: 0), directionHint: entry.directionHint)
            case let .messageEntry(topMessage, messages, theme, strings, dateTimeFormat, editing, hasActiveRevealControls):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item:  CallListCallItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, context: context, style: showSettings ? .blocks : .plain, topMessage: topMessage, messages: messages, editing: editing, revealed: hasActiveRevealControls, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .holeEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListHoleItem(theme: theme), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, presentationData: ItemListPresentationData, showSettings: Bool, nodeInteraction: CallListNodeInteraction, entries: [CallListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .displayTab(theme, text, value):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: 0, style: .blocks, updated: { value in
                    nodeInteraction.updateShowCallsTab(value)
                }), directionHint: entry.directionHint)
            case let .displayTabInfo(theme, text):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: 0), directionHint: entry.directionHint)
            case let .messageEntry(topMessage, messages, theme, strings, dateTimeFormat, editing, hasActiveRevealControls):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListCallItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, context: context, style: showSettings ? .blocks : .plain, topMessage: topMessage, messages: messages, editing: editing, revealed: hasActiveRevealControls, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .holeEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListHoleItem(theme: theme), directionHint: entry.directionHint)
        }
    }
}

private func mappedCallListNodeViewListTransition(context: AccountContext, presentationData: ItemListPresentationData, showSettings: Bool, nodeInteraction: CallListNodeInteraction, transition: CallListNodeViewTransition) -> CallListNodeListViewTransition {
    return CallListNodeListViewTransition(callListView: transition.callListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, presentationData: presentationData, showSettings: showSettings, nodeInteraction: nodeInteraction, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, presentationData: presentationData, showSettings: showSettings, nodeInteraction: nodeInteraction, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

private final class CallListOpaqueTransactionState {
    let callListView: CallListNodeView
    
    init(callListView: CallListNodeView) {
        self.callListView = callListView
    }
}

final class CallListControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let mode: CallListControllerMode
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    var peerSelected: ((PeerId) -> Void)?
    var activateSearch: (() -> Void)?
    var deletePeerChat: ((PeerId) -> Void)?
    
    private let viewProcessingQueue = Queue()
    private var callListView: CallListNodeView?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (CallListNodeListViewTransition, () -> Void)?
    
    private var currentState: CallListNodeState
    private let statePromise: ValuePromise<CallListNodeState>
    
    private var currentLocationAndType = CallListNodeLocationAndType(location: .initial(count: 50), type: .all)
    private let callListLocationAndType = ValuePromise<CallListNodeLocationAndType>()
    private let callListDisposable = MetaDisposable()
    
    private let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    private let emptyTextNode: ASTextNode
    
    private let call: (PeerId) -> Void
    private let openInfo: (PeerId, [Message]) -> Void
    private let emptyStateUpdated: (Bool) -> Void
    
    private let emptyStatePromise = Promise<Bool>()
    private let emptyStateDisposable = MetaDisposable()
    
    init(context: AccountContext, mode: CallListControllerMode, presentationData: PresentationData, call: @escaping (PeerId) -> Void, openInfo: @escaping (PeerId, [Message]) -> Void, emptyStateUpdated: @escaping (Bool) -> Void) {
        self.context = context
        self.mode = mode
        self.presentationData = presentationData
        self.call = call
        self.openInfo = openInfo
        self.emptyStateUpdated = emptyStateUpdated
        
        self.currentState = CallListNodeState(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, disableAnimations: presentationData.disableAnimations, editing: false, messageIdWithRevealedOptions: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.emptyTextNode = ASTextNode()
        self.emptyTextNode.alpha = 0.0
        self.emptyTextNode.isUserInteractionEnabled = false
        self.emptyTextNode.displaysAsynchronously = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.emptyTextNode)
        
        switch self.mode {
            case .tab:
                self.backgroundColor = presentationData.theme.chatList.backgroundColor
                self.listNode.backgroundColor = presentationData.theme.chatList.backgroundColor
            case .navigation:
                self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
                self.listNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        }
        
        let nodeInteraction = CallListNodeInteraction(setMessageIdWithRevealedOptions: { [weak self] messageId, fromMessageId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (messageId == nil && fromMessageId == state.messageIdWithRevealedOptions) || (messageId != nil && fromMessageId == nil) {
                        return state.withUpdatedMessageIdWithRevealedOptions(messageId)
                    } else {
                        return state
                    }
                }
            }
        }, call: { [weak self] peerId in
            self?.call(peerId)
        }, openInfo: { [weak self] peerId, messages in
            self?.openInfo(peerId, messages)
        }, delete: { [weak self] messageIds in
            if let strongSelf = self {
                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: messageIds, type: .forLocalPeer).start()
            }
        }, updateShowCallsTab: { [weak self] value in
            if let strongSelf = self {
                let _ = updateCallListSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, {
                    $0.withUpdatedShowTab(value)
                }).start()
                
                if value {
                    let _ = ApplicationSpecificNotice.incrementCallsTabTips(accountManager: strongSelf.context.sharedContext.accountManager, count: 4).start()
                }
            }
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let callListViewUpdate = self.callListLocationAndType.get()
        |> distinctUntilChanged
        |> mapToSignal { locationAndType in
            return callListViewForLocationAndType(locationAndType: locationAndType, account: context.account)
        }
        
        let previousView = Atomic<CallListNodeView?>(value: nil)
        
        let showSettings: Bool
        switch mode {
            case .tab:
                showSettings = false
            case .navigation:
                showSettings = true
        }
        
        let showCallsTab = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
        |> map { sharedData -> Bool in
            var value = true
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings] as? CallListSettings {
                value = settings.showTab
            }
            return value
        }
        
        let callListNodeViewTransition = combineLatest(callListViewUpdate, self.statePromise.get(), showCallsTab)
        |> mapToQueue { (update, state, showCallsTab) -> Signal<CallListNodeListViewTransition, NoError> in
            let processedView = CallListNodeView(originalView: update.view, filteredEntries: callListNodeEntriesForView(update.view, state: state, showSettings: showSettings, showCallsTab: showCallsTab), presentationData: state.presentationData)
            let previous = previousView.swap(processedView)
            
            let reason: CallListNodeViewTransitionReason
            var prepareOnMainQueue = false
            
            var previousWasEmptyOrSingleHole = false
            if let previous = previous {
                if previous.filteredEntries.count == 1 {
                    if case .holeEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    }
                }
            } else {
                previousWasEmptyOrSingleHole = true
            }
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previous == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previous?.originalView === update.view {
                    reason = .interactiveChanges
                } else {
                    switch update.type {
                        case .Initial:
                            reason = .initial
                            prepareOnMainQueue = true
                        case .Generic:
                            reason = .interactiveChanges
                        case .UpdateVisible:
                            reason = .reload
                        case .Reload:
                            reason = .reload
                        case .ReloadAnimated:
                            reason = .reloadAnimated
                    }
                }
            }
            
            return preparedCallListNodeViewTransition(from: previous, to: processedView, reason: reason, disableAnimations: false, account: context.account, scrollPosition: update.scrollPosition)
            |> map({ mappedCallListNodeViewListTransition(context: context, presentationData: state.presentationData, showSettings: showSettings, nodeInteraction: nodeInteraction, transition: $0) })
            |> runOn(prepareOnMainQueue ? Queue.mainQueue() : viewProcessingQueue)
        }
        
        let appliedTransition = callListNodeViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueTransition(transition)
            }
            return .complete()
        }
        
        self.listNode.displayedItemRangeChanged = { [weak self] range, transactionOpaqueState in
            if let strongSelf = self, let range = range.loadedRange, let view = (transactionOpaqueState as? CallListOpaqueTransactionState)?.callListView.originalView {
                var location: CallListNodeLocation?
                if range.firstIndex < 5 && view.later != nil {
                    location = .navigation(index: view.entries[view.entries.count - 1].highestIndex)
                } else if range.firstIndex >= 5 && range.lastIndex >= view.entries.count - 5 && view.earlier != nil {
                    location = .navigation(index: view.entries[0].lowestIndex)
                }
                
                if let location = location, location != strongSelf.currentLocationAndType.location {
                    strongSelf.currentLocationAndType = CallListNodeLocationAndType(location: location, type: strongSelf.currentLocationAndType.type)
                    strongSelf.callListLocationAndType.set(strongSelf.currentLocationAndType)
                }
            }
        }
        
        self.callListDisposable.set(appliedTransition.start())
        
        self.callListLocationAndType.set(self.currentLocationAndType)

        let emptySignal = self.emptyStatePromise.get() |> distinctUntilChanged
        let typeSignal = self.callListLocationAndType.get() |> map { locationAndType -> CallListViewType in
            return locationAndType.type
        } |> distinctUntilChanged
        
        self.emptyStateDisposable.set((combineLatest(emptySignal, typeSignal, self.statePromise.get()) |> deliverOnMainQueue).start(next: { [weak self] isEmpty, type, state in
            if let strongSelf = self {
                strongSelf.updateEmptyPlaceholder(theme: state.presentationData.theme, strings: state.presentationData.strings, type: type, hidden: !isEmpty)
            }
        }))
    }
    
    deinit {
        self.callListDisposable.dispose()
        self.emptyStateDisposable.dispose()
    }
    
    func updateThemeAndStrings(presentationData: PresentationData) {
        if presentationData.theme !== self.currentState.presentationData.theme || presentationData.strings !== self.currentState.presentationData.strings || presentationData.disableAnimations != self.currentState.disableAnimations {
            self.presentationData = presentationData
            
            self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            switch self.mode {
                case .tab:
                    self.backgroundColor = presentationData.theme.chatList.backgroundColor
                    self.listNode.backgroundColor = presentationData.theme.chatList.backgroundColor
                case .navigation:
                    self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
                    self.listNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            }
            
            self.updateEmptyPlaceholder(theme: presentationData.theme, strings: presentationData.strings, type: self.currentLocationAndType.type, hidden: self.emptyTextNode.isHidden)
            
            self.updateState {
                return $0.withUpdatedPresentationData(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, disableAnimations: presentationData.disableAnimations)
            }
        }
    }
    
    private let textFont = Font.regular(16.0)
    
    func updateEmptyPlaceholder(theme: PresentationTheme, strings: PresentationStrings, type: CallListViewType, hidden: Bool) {
        let alpha: CGFloat = hidden ? 0.0 : 1.0
        let previousAlpha = self.emptyTextNode.alpha
        self.emptyTextNode.alpha = alpha
        self.emptyTextNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.2)
        
        if !hidden {
            let type = self.currentLocationAndType.type
            let string: String
            if type == .missed {
                string = strings.Calls_NoMissedCallsPlacehoder
            } else {
                string = strings.Calls_NoCallsPlaceholder
            }
            let color: UIColor
            
            switch self.mode {
            case .tab:
                self.backgroundColor = theme.chatList.backgroundColor
                self.listNode.backgroundColor = theme.chatList.backgroundColor
                color = theme.list.freeTextColor
            case .navigation:
                self.backgroundColor = theme.list.blocksBackgroundColor
                self.listNode.backgroundColor = theme.list.blocksBackgroundColor
                color = theme.list.freeTextColor
            }
            
            self.emptyTextNode.attributedText = NSAttributedString(string: string, font: textFont, textColor: color, paragraphAlignment: .center)
            if let layout = self.containerLayout {
                self.updateLayout(layout.0, navigationBarHeight: layout.1, transition: .immediate)
            }
        }
    }
    
    func updateState(_ f: (CallListNodeState) -> CallListNodeState) {
        let state = f(self.currentState)
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
    }
    
    func updateType(_ type: CallListViewType) {
        if type != self.currentLocationAndType.type {
            if let view = self.callListView?.originalView {
                var index: MessageIndex
                if !view.entries.isEmpty {
                    index = view.entries[view.entries.count - 1].highestIndex
                } else {
                    index = MessageIndex.absoluteUpperBound()
                }
                self.currentLocationAndType = CallListNodeLocationAndType(location: .changeType(index: index), type: type)
                self.emptyStatePromise.set(.single(false))
                self.callListLocationAndType.set(self.currentLocationAndType)
            }
        }
    }
    
    private func enqueueTransition(_ transition: CallListNodeListViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded {
                    strongSelf.dequeueTransition()
                } else {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func dequeueTransition() {
        if let (transition, completion) = self.enqueuedTransition {
            self.enqueuedTransition = nil
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.callListView = transition.callListView
                    
                    let empty = countMeaningfulCallListEntries(transition.callListView.filteredEntries) == 0
                    strongSelf.emptyStateUpdated(empty)
                    strongSelf.emptyStatePromise.set(.single(empty))
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    
                    completion()
                }
            }
            
            self.listNode.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: CallListOpaqueTransactionState(callListView: transition.callListView), completion: completion)
        }
    }
    
    func scrollToLatest() {
        if let view = self.callListView?.originalView, view.later == nil {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        } else {
            let location: CallListNodeLocation = .scroll(index: MessageIndex.absoluteUpperBound(), sourceIndex: MessageIndex.absoluteLowerBound(), scrollPosition: .top(0.0), animated: true)
            self.currentLocationAndType = CallListNodeLocationAndType(location: location, type: self.currentLocationAndType.type)
            self.callListLocationAndType.set(self.currentLocationAndType)
        }
    }
    
    func updateLayout(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        if self.mode == .navigation {
            insets.top += 64.0
        }
        
        let size = layout.size
        let contentRect = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))

        let textSize = self.emptyTextNode.measure(CGSize(width: size.width - 20.0, height: size.height))
        transition.updateFrame(node: self.emptyTextNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: contentRect.minY + floor((contentRect.height - textSize.height) / 2.0)), size: textSize))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        self.updateLayout(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueTransition()
        }
    }
}
