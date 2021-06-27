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
import ChatListSearchItemHeader
import AnimatedStickerNode
import AppBundle

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
    let call: (PeerId, Bool) -> Void
    let openInfo: (PeerId, [Message]) -> Void
    let delete: ([MessageId]) -> Void
    let updateShowCallsTab: (Bool) -> Void
    let openGroupCall: (PeerId) -> Void
    
    init(setMessageIdWithRevealedOptions: @escaping (MessageId?, MessageId?) -> Void, call: @escaping (PeerId, Bool) -> Void, openInfo: @escaping (PeerId, [Message]) -> Void, delete: @escaping ([MessageId]) -> Void, updateShowCallsTab: @escaping (Bool) -> Void, openGroupCall: @escaping (PeerId) -> Void) {
        self.setMessageIdWithRevealedOptions = setMessageIdWithRevealedOptions
        self.call = call
        self.openInfo = openInfo
        self.delete = delete
        self.updateShowCallsTab = updateShowCallsTab
        self.openGroupCall = openGroupCall
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
            case let .displayTab(_, text, value):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, noCorners: true, sectionId: 0, style: .blocks, updated: { value in
                    nodeInteraction.updateShowCallsTab(value)
                }), directionHint: entry.directionHint)
            case let .displayTabInfo(_, text):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: 0), directionHint: entry.directionHint)
            case let .groupCall(peer, _, isActive):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListGroupCallItem(presentationData: presentationData, context: context, style: showSettings ? .blocks : .plain, peer: peer, isActive: isActive, editing: false, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .messageEntry(topMessage, messages, _, _, dateTimeFormat, editing, hasActiveRevealControls, displayHeader, _):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item:  CallListCallItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, context: context, style: showSettings ? .blocks : .plain, topMessage: topMessage, messages: messages, editing: editing, revealed: hasActiveRevealControls, displayHeader: displayHeader, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .holeEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListHoleItem(theme: theme), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, presentationData: ItemListPresentationData, showSettings: Bool, nodeInteraction: CallListNodeInteraction, entries: [CallListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .displayTab(_, text, value):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, noCorners: true, sectionId: 0, style: .blocks, updated: { value in
                    nodeInteraction.updateShowCallsTab(value)
                }), directionHint: entry.directionHint)
            case let .displayTabInfo(_, text):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: 0), directionHint: entry.directionHint)
            case let .groupCall(peer, _, isActive):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListGroupCallItem(presentationData: presentationData, context: context, style: showSettings ? .blocks : .plain, peer: peer, isActive: isActive, editing: false, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .messageEntry(topMessage, messages, _, _, dateTimeFormat, editing, hasActiveRevealControls, displayHeader, _):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: CallListCallItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, context: context, style: showSettings ? .blocks : .plain, topMessage: topMessage, messages: messages, editing: editing, revealed: hasActiveRevealControls, displayHeader: displayHeader, interaction: nodeInteraction), directionHint: entry.directionHint)
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
    private weak var controller: CallListController?
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
    var startNewCall: (() -> Void)?
    
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
    private let emptyTextNode: ImmediateTextNode
    private let emptyAnimationNode: AnimatedStickerNode
    private var emptyAnimationSize = CGSize()
    private let emptyButtonNode: HighlightTrackingButtonNode
    private let emptyButtonIconNode: ASImageNode
    private let emptyButtonTextNode: ImmediateTextNode
    
    private let call: (PeerId, Bool) -> Void
    private let joinGroupCall: (PeerId, CachedChannelData.ActiveCall) -> Void
    private let openInfo: (PeerId, [Message]) -> Void
    private let emptyStateUpdated: (Bool) -> Void
    
    private let emptyStatePromise = Promise<Bool>()
    private let emptyStateDisposable = MetaDisposable()
    
    private let openGroupCallDisposable = MetaDisposable()
    
    init(controller: CallListController, context: AccountContext, mode: CallListControllerMode, presentationData: PresentationData, call: @escaping (PeerId, Bool) -> Void, joinGroupCall: @escaping (PeerId, CachedChannelData.ActiveCall) -> Void, openInfo: @escaping (PeerId, [Message]) -> Void, emptyStateUpdated: @escaping (Bool) -> Void) {
        self.controller = controller
        self.context = context
        self.mode = mode
        self.presentationData = presentationData
        self.call = call
        self.joinGroupCall = joinGroupCall
        self.openInfo = openInfo
        self.emptyStateUpdated = emptyStateUpdated
        
        self.currentState = CallListNodeState(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, disableAnimations: true, editing: false, messageIdWithRevealedOptions: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).0
        }
        
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.emptyTextNode = ImmediateTextNode()
        self.emptyTextNode.alpha = 0.0
        self.emptyTextNode.isUserInteractionEnabled = false
        self.emptyTextNode.displaysAsynchronously = false
        self.emptyTextNode.textAlignment = .center
        self.emptyTextNode.maximumNumberOfLines = 3
        
        self.emptyAnimationNode = AnimatedStickerNode()
        self.emptyAnimationNode.alpha = 0.0
        self.emptyAnimationNode.isUserInteractionEnabled = false
        
        self.emptyButtonNode = HighlightTrackingButtonNode()
        self.emptyButtonNode.isUserInteractionEnabled = false
        
        self.emptyButtonTextNode = ImmediateTextNode()
        self.emptyButtonTextNode.isUserInteractionEnabled = false
        
        self.emptyButtonIconNode = ASImageNode()
        self.emptyButtonIconNode.displaysAsynchronously = false
        self.emptyButtonIconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.emptyTextNode)
        self.addSubnode(self.emptyAnimationNode)
        self.addSubnode(self.emptyButtonTextNode)
        self.addSubnode(self.emptyButtonIconNode)
        self.addSubnode(self.emptyButtonNode)
        
        switch self.mode {
            case .tab:
                self.backgroundColor = presentationData.theme.chatList.backgroundColor
                self.listNode.backgroundColor = presentationData.theme.chatList.backgroundColor
            case .navigation:
                self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
                self.listNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        }
        
        
        if let path = getAppBundle().path(forResource: "CallsPlaceholder", ofType: "tgs") {
            self.emptyAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.emptyAnimationSize = CGSize(width: 148.0, height: 148.0)
        }
        
        self.emptyButtonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call List/CallIcon"), color: presentationData.theme.list.itemAccentColor)
        
        self.emptyButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.emptyButtonIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.emptyButtonIconNode.alpha = 0.4
                    strongSelf.emptyButtonTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.emptyButtonTextNode.alpha = 0.4
                } else {
                    strongSelf.emptyButtonIconNode.alpha = 1.0
                    strongSelf.emptyButtonIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.emptyButtonTextNode.alpha = 1.0
                    strongSelf.emptyButtonTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.emptyButtonNode.addTarget(self, action: #selector(self.emptyButtonPressed), forControlEvents: .touchUpInside)
        
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
        }, call: { [weak self] peerId, isVideo in
            self?.call(peerId, isVideo)
        }, openInfo: { [weak self] peerId, messages in
            self?.openInfo(peerId, messages)
        }, delete: { [weak self] messageIds in
            guard let strongSelf = self, let peerId = messageIds.first?.peerId else {
                return
            }
            
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self, let peer = peer else {
                    return
                }
                
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []
                
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forEveryone).start()
                }))
                
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forLocalPeer).start()
                }))
                    
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.controller?.present(actionSheet, in: .window(.root))
            })
        }, updateShowCallsTab: { [weak self] value in
            if let strongSelf = self {
                let _ = updateCallListSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, {
                    $0.withUpdatedShowTab(value)
                }).start()
                
                if value {
                    let _ = ApplicationSpecificNotice.incrementCallsTabTips(accountManager: strongSelf.context.sharedContext.accountManager, count: 4).start()
                }
            }
        }, openGroupCall: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            
            let disposable = strongSelf.openGroupCallDisposable
            
            let account = strongSelf.context.account
            var signal: Signal<CachedChannelData.ActiveCall?, NoError> = strongSelf.context.account.postbox.transaction { transaction -> CachedChannelData.ActiveCall? in
                let cachedData = transaction.getPeerCachedData(peerId: peerId)
                if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.activeCall
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.activeCall
                }
                return nil
            }
            |> mapToSignal { activeCall -> Signal<CachedChannelData.ActiveCall?, NoError> in
                if let activeCall = activeCall {
                    return .single(activeCall)
                } else {
                    return updatedCurrentPeerGroupCall(account: account, peerId: peerId)
                }
            }
            
            var cancelImpl: (() -> Void)?
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                if let strongSelf = self {
                    strongSelf.controller?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            signal = signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            cancelImpl = {
                disposable.set(nil)
            }
            disposable.set((signal
            |> deliverOnMainQueue).start(next: { activeCall in
                guard let strongSelf = self else {
                    return
                }
                
                if let activeCall = activeCall {
                    strongSelf.joinGroupCall(peerId, activeCall)
                }
            }))
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
            var value = CallListSettings.defaultSettings.showTab
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings] as? CallListSettings {
                value = settings.showTab
            }
            return value
        }
        
        let currentGroupCallPeerId: Signal<PeerId?, NoError>
        if let callManager = context.sharedContext.callManager {
            currentGroupCallPeerId = callManager.currentGroupCallSignal
            |> map { call -> PeerId? in
                call?.peerId
            }
            |> distinctUntilChanged
        } else {
            currentGroupCallPeerId = .single(nil)
        }
        
        let groupCalls = context.account.postbox.tailChatListView(groupId: .root, count: 100, summaryComponents: ChatListEntrySummaryComponents())
        |> map { view -> [Peer] in
            var result: [Peer] = []
            for entry in view.0.entries {
                switch entry {
                case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                    if let channel = renderedPeer.peer as? TelegramChannel, channel.flags.contains(.hasActiveVoiceChat) {
                        result.append(channel)
                    } else if let group = renderedPeer.peer as? TelegramGroup, group.flags.contains(.hasActiveVoiceChat) {
                        result.append(group)
                    }
                default:
                    break
                }
            }
            return result.sorted(by: { lhs, rhs in
                let lhsTitle = lhs.compactDisplayTitle
                let rhsTitle = rhs.compactDisplayTitle
                if lhsTitle != rhsTitle {
                    return lhsTitle < rhsTitle
                }
                return lhs.id < rhs.id
            })
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.count != rhs.count {
                return false
            }
            for i in 0 ..< lhs.count {
                if !lhs[i].isEqual(rhs[i]) {
                    return false
                }
            }
            return true
        })
        
        let callListNodeViewTransition = combineLatest(callListViewUpdate, self.statePromise.get(), groupCalls, showCallsTab, currentGroupCallPeerId)
        |> mapToQueue { (updateAndType, state, groupCalls, showCallsTab, currentGroupCallPeerId) -> Signal<CallListNodeListViewTransition, NoError> in
            let (update, type) = updateAndType
            
            let processedView = CallListNodeView(originalView: update.view, filteredEntries: callListNodeEntriesForView(view: update.view, groupCalls: groupCalls, state: state, showSettings: showSettings, showCallsTab: showCallsTab, isRecentCalls: type == .all, currentGroupCallPeerId: currentGroupCallPeerId), presentationData: state.presentationData)
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

            var disableAnimations = false
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previous == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previous?.originalView === update.view {
                    let previousCalls = previous?.filteredEntries.compactMap { item -> PeerId? in
                        switch item {
                        case let .groupCall(peer, _, _):
                            return peer.id
                        default:
                            return nil
                        }
                    }
                    let updatedCalls = processedView.filteredEntries.compactMap { item -> PeerId? in
                        switch item {
                        case let .groupCall(peer, _, _):
                            return peer.id
                        default:
                            return nil
                        }
                    }
                    reason = .interactiveChanges
                    if previousCalls != updatedCalls {
                        disableAnimations = true
                    }
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
            
            return preparedCallListNodeViewTransition(from: previous, to: processedView, reason: reason, disableAnimations: disableAnimations, account: context.account, scrollPosition: update.scrollPosition)
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
                strongSelf.updateEmptyPlaceholder(theme: state.presentationData.theme, strings: state.presentationData.strings, type: type, isHidden: !isEmpty)
            }
        }))
    }
    
    deinit {
        self.callListDisposable.dispose()
        self.emptyStateDisposable.dispose()
        self.openGroupCallDisposable.dispose()
    }
    
    func updateThemeAndStrings(presentationData: PresentationData) {
        if presentationData.theme !== self.currentState.presentationData.theme || presentationData.strings !== self.currentState.presentationData.strings {
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
            
            self.emptyButtonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call List/CallIcon"), color: presentationData.theme.list.itemAccentColor)
            
            self.updateEmptyPlaceholder(theme: presentationData.theme, strings: presentationData.strings, type: self.currentLocationAndType.type, isHidden: self.emptyTextNode.alpha.isZero)
            
            self.updateState {
                return $0.withUpdatedPresentationData(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, disableAnimations: true)
            }
            
            self.listNode.forEachItemHeaderNode({ itemHeaderNode in
                if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                    itemHeaderNode.updateTheme(theme: presentationData.theme)
                }
            })
        }
    }
    
    private let textFont = Font.regular(16.0)
    private let buttonFont = Font.regular(17.0)
    
    func updateEmptyPlaceholder(theme: PresentationTheme, strings: PresentationStrings, type: CallListViewType, isHidden: Bool) {
        let alpha: CGFloat = isHidden ? 0.0 : 1.0
        let previousAlpha = self.emptyTextNode.alpha
        self.emptyTextNode.alpha = alpha
        self.emptyTextNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.2)
        
        if previousAlpha.isZero && !alpha.isZero {
            self.emptyAnimationNode.visibility = true
        }
        self.emptyAnimationNode.alpha = alpha
        self.emptyAnimationNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.2, completion: { [weak self] _ in
            if let strongSelf = self {
                if !previousAlpha.isZero && strongSelf.emptyAnimationNode.alpha.isZero {
                    strongSelf.emptyAnimationNode.visibility = false
                }
            }
        })
        
        self.emptyButtonIconNode.alpha = alpha
        self.emptyButtonIconNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.2)
        self.emptyButtonTextNode.alpha = alpha
        self.emptyButtonTextNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.2)
        self.emptyButtonNode.isUserInteractionEnabled = !isHidden
        
        if !isHidden {
            let type = self.currentLocationAndType.type
            let emptyText: String
            let buttonText = strings.Calls_StartNewCall
            if type == .missed {
                emptyText = strings.Calls_NoMissedCallsPlacehoder
            } else {
                emptyText = strings.Calls_NoVoiceAndVideoCallsPlaceholder
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
            
            self.emptyTextNode.attributedText = NSAttributedString(string: emptyText, font: textFont, textColor: color, paragraphAlignment: .center)
            
            self.emptyButtonTextNode.attributedText = NSAttributedString(string: buttonText, font: buttonFont, textColor: theme.list.itemAccentColor, paragraphAlignment: .center)
            
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
    
    @objc private func emptyButtonPressed() {
        self.startNewCall?()
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

        let sideInset: CGFloat = 64.0
        
        let emptyAnimationHeight = self.emptyAnimationSize.height
        let emptyAnimationSpacing: CGFloat = 13.0
        let emptyTextSpacing: CGFloat = 23.0
        let emptyTextSize = self.emptyTextNode.updateLayout(CGSize(width: contentRect.width - sideInset * 2.0, height: size.height))
        let emptyButtonSize = self.emptyButtonTextNode.updateLayout(CGSize(width: contentRect.width - sideInset * 2.0, height: size.height))
        let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTextSize.height + emptyTextSpacing + emptyButtonSize.height
        let emptyAnimationY = contentRect.minY + floorToScreenPixels((contentRect.height - emptyTotalHeight) / 2.0)
        
        let textTransition = ContainedViewLayoutTransition.immediate
        textTransition.updateFrame(node: self.emptyAnimationNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + (contentRect.width - self.emptyAnimationSize.width) / 2.0, y: emptyAnimationY), size: self.emptyAnimationSize))
        textTransition.updateFrame(node: self.emptyTextNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + (contentRect.width - emptyTextSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTextSize))
        
        let emptyButtonSpacing: CGFloat = 14.0
        let emptyButtonIconSize = (self.emptyButtonIconNode.image?.size ?? CGSize())
        let emptyButtonWidth = emptyButtonIconSize.width + emptyButtonSpacing + emptyButtonSize.width
        let emptyButtonX = floor(contentRect.width - emptyButtonWidth) / 2.0
        textTransition.updateFrame(node: self.emptyButtonIconNode, frame: CGRect(origin: CGPoint(x: emptyButtonX, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTextSize.height + emptyTextSpacing), size: emptyButtonIconSize))
        textTransition.updateFrame(node: self.emptyButtonTextNode, frame: CGRect(origin: CGPoint(x: emptyButtonX + emptyButtonIconSize.width + emptyButtonSpacing, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTextSize.height + emptyTextSpacing + 4.0), size: emptyButtonSize))
        
        textTransition.updateFrame(node: self.emptyButtonNode, frame: CGRect(origin: CGPoint(x: emptyButtonX, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTextSize.height + emptyTextSpacing), size: CGSize(width: emptyButtonWidth, height: 44.0)))
        
        self.emptyAnimationNode.updateLayout(size: self.emptyAnimationSize)
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
