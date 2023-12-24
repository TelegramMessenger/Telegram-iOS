import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import ChatPresentationInterfaceState
import AccountContext
import ChatControllerInteraction
import OverlayStatusController
import TelegramPresentationData
import PresentationDataUtils

extension ChatControllerImpl {
    func navigateToMessage(
        fromId: MessageId,
        id: MessageId,
        params: NavigateToMessageParams
    ) {
        var id = id
        if case let .replyThread(message) = self.chatLocation {
            if let channelMessageId = message.channelMessageId, id == channelMessageId {
                id = message.messageId
            }
        }
        
        let continueNavigation: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            self.navigateToMessage(from: fromId, to: .id(id, params), forceInCurrentChat: fromId.peerId == id.peerId)
        }
        
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id.peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] toPeer in
            guard let self else {
                return
            }
            
            if params.quote != nil {
                if let toPeer {
                    switch toPeer {
                    case let .channel(channel):
                        if channel.username == nil && channel.usernames.isEmpty {
                            switch channel.participationStatus {
                            case .kicked, .left:
                                self.controllerInteraction?.attemptedNavigationToPrivateQuote(toPeer._asPeer())
                                return
                            case .member:
                                break
                            }
                        }
                    default:
                        break
                    }
                } else {
                    self.controllerInteraction?.attemptedNavigationToPrivateQuote(nil)
                    return
                }
            }
            
            continueNavigation()
        })
    }
    
    func navigateToMessage(
        from fromId: MessageId?,
        to messageLocation: NavigateToMessageLocation,
        scrollPosition: ListViewScrollPosition = .center(.bottom),
        rememberInStack: Bool = true,
        forceInCurrentChat: Bool = false,
        dropStack: Bool = false,
        animated: Bool = true,
        completion: (() -> Void)? = nil,
        customPresentProgress: ((ViewController, Any?) -> Void)? = nil,
        statusSubject: ChatLoadingMessageSubject = .generic
    ) {
        if !self.isNodeLoaded {
            completion?()
            return
        }
        var fromIndex: MessageIndex?
        
        if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
            fromIndex = message.index
        } else {
            if let message = self.chatDisplayNode.historyNode.anchorMessageInCurrentHistoryView() {
                fromIndex = message.index
            }
        }
        
        var isScheduledMessages = false
        var isPinnedMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        } else if case .pinnedMessages = self.presentationInterfaceState.subject {
            isPinnedMessages = true
        }
        
        var forceInCurrentChat = forceInCurrentChat
        if case let .peer(peerId) = self.chatLocation, messageLocation.peerId == peerId, !isPinnedMessages, !isScheduledMessages {
            forceInCurrentChat = true
        }
        
        if isPinnedMessages, let messageId = messageLocation.messageId {
            let _ = (combineLatest(
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)),
                self.context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .local)
                |> `catch` { _ in
                    return .single(.result([]))
                }
                |> mapToSignal { result -> Signal<[Message], NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result)
                }
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, messages in
                guard let self, let peer = peer else {
                    return
                }
                guard let navigationController = self.effectiveNavigationController else {
                    return
                }
                
                self.dismiss()
                
                let navigateToLocation: NavigateToChatControllerParams.Location
                if let message = messages.first, let threadId = message.threadId, let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.flags.contains(.isForum) {
                    navigateToLocation = .replyThread(ChatReplyThreadMessage(messageId: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
                } else {
                    navigateToLocation = .peer(peer)
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: navigateToLocation, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil), keepStack: .always))
            })
        } else if case let .peer(peerId) = self.chatLocation, let messageId = messageLocation.messageId, (messageId.peerId != peerId && !forceInCurrentChat) || (isScheduledMessages && messageId.id != 0 && !Namespaces.Message.allScheduled.contains(messageId.namespace)) {
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId),
                TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, message in
                guard let self, let peer = peer else {
                    return
                }
                if let navigationController = self.effectiveNavigationController {
                    var chatLocation: NavigateToChatControllerParams.Location = .peer(peer)
                    if case let .channel(channel) = peer, channel.flags.contains(.isForum), let message = message, let threadId = message.threadId {
                        chatLocation = .replyThread(ChatReplyThreadMessage(messageId: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
                    }
                    
                    var quote: ChatControllerSubject.MessageHighlight.Quote?
                    if case let .id(_, params) = messageLocation {
                        quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                    }
                    
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: chatLocation, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: quote), timecode: nil), keepStack: .always))
                }
            })
        } else if forceInCurrentChat {
            if let _ = fromId, let fromIndex = fromIndex, rememberInStack {
                self.historyNavigationStack.add(fromIndex)
            }
            
            let scrollFromIndex: MessageIndex?
            if let fromIndex = fromIndex {
                scrollFromIndex = fromIndex
            } else if let message = self.chatDisplayNode.historyNode.lastVisbleMesssage() {
                scrollFromIndex = message.index
            } else {
                scrollFromIndex = nil
            }
            
            if let scrollFromIndex = scrollFromIndex {
                if let messageId = messageLocation.messageId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    self.loadingMessage.set(.single(nil))
                    self.messageIndexDisposable.set(nil)
                    
                    var delayCompletion = true
                    if self.chatDisplayNode.historyNode.isMessageVisible(id: messageId) {
                        delayCompletion = false
                    }
                    
                    var quote: (string: String, offset: Int?)?
                    if case let .id(_, params) = messageLocation {
                        quote = params.quote.flatMap { quote in (string: quote.string, offset: quote.offset) }
                    }
                    self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: message.index, animated: animated, quote: quote, scrollPosition: scrollPosition)
                    
                    if delayCompletion {
                        Queue.mainQueue().after(0.25, {
                            completion?()
                        })
                    } else {
                        Queue.mainQueue().justDispatch({
                            completion?()
                        })
                    }
                    
                    if case let .id(_, params) = messageLocation, let timecode = params.timestamp {
                        let _ = self.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .timecode(timecode)))
                    }
                } else if case let .index(index) = messageLocation, index.id.id == 0, index.timestamp > 0, case .scheduledMessages = self.presentationInterfaceState.subject {
                    self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                } else {
                    var quote: (string: String, offset: Int?)?
                    if case let .id(messageId, params) = messageLocation {
                        if params.timestamp != nil {
                            self.scheduledScrollToMessageId = (messageId, params)
                        }
                        quote = params.quote.flatMap { ($0.string, $0.offset) }
                    }
                    var progress: Promise<Bool>?
                    if case let .id(_, params) = messageLocation {
                        progress = params.progress
                    }
                    self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                    
                    let searchLocation: ChatHistoryInitialSearchLocation
                    switch messageLocation {
                    case let .id(id, _):
                        if case let .replyThread(message) = self.chatLocation, id == message.messageId {
                            searchLocation = .index(.absoluteLowerBound())
                        } else {
                            searchLocation = .id(id)
                        }
                    case let .index(index):
                        searchLocation = .index(index)
                    case .upperBound:
                        if let peerId = self.chatLocation.peerId {
                            searchLocation = .index(MessageIndex.upperBound(peerId: peerId))
                        } else {
                            searchLocation = .index(.absoluteUpperBound())
                        }
                    }
                    var historyView: Signal<ChatHistoryViewUpdate, NoError>
                    historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: searchLocation, quote: nil), count: 50, highlight: true), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                    
                    var signal: Signal<(MessageIndex?, Bool), NoError>
                    signal = historyView
                    |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
                        switch historyView {
                            case .Loading:
                                return .single((nil, true))
                            case let .HistoryView(view, _, _, _, _, _, _):
                                for entry in view.entries {
                                    if entry.message.id == messageLocation.messageId {
                                        return .single((entry.message.index, false))
                                    }
                                }
                                if case let .index(index) = searchLocation {
                                    return .single((index, false))
                                }
                                return .single((nil, false))
                        }
                    }
                    |> take(until: { index in
                        return SignalTakeAction(passthrough: true, complete: !index.1)
                    })
                    
                    /*#if DEBUG
                    signal = .single((nil, true)) |> then(signal |> delay(2.0, queue: .mainQueue()))
                    #endif*/
                    
                    var cancelImpl: (() -> Void)?
                    let presentationData = self.presentationData
                    let displayTime = CACurrentMediaTime()
                    let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                        if let progress {
                            progress.set(.single(true))
                            return ActionDisposable {
                                Queue.mainQueue().async() {
                                    progress.set(.single(false))
                                }
                            }
                        } else if case .generic = statusSubject {
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                if CACurrentMediaTime() - displayTime > 1.5 {
                                    cancelImpl?()
                                }
                            }))
                            if let customPresentProgress = customPresentProgress {
                                customPresentProgress(controller, nil)
                            } else {
                                self?.present(controller, in: .window(.root))
                            }
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        } else {
                            return EmptyDisposable
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.05, queue: Queue.mainQueue())
                    let progressDisposable = MetaDisposable()
                    var progressStarted = false
                    self.messageIndexDisposable.set((signal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] index in
                        if let strongSelf = self, let index = index.0 {
                            strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, quote: quote, scrollPosition: scrollPosition)
                            completion?()
                        } else if index.1 {
                            if !progressStarted {
                                progressStarted = true
                                progressDisposable.set(progressSignal.start())
                            }
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                        }
                    }))
                    cancelImpl = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                            strongSelf.messageIndexDisposable.set(nil)
                        }
                    }
                }
            } else {
                completion?()
            }
        } else {
            if let fromIndex = fromIndex {
                let searchLocation: ChatHistoryInitialSearchLocation
                switch messageLocation {
                    case let .id(id, _):
                        searchLocation = .id(id)
                    case let .index(index):
                        searchLocation = .index(index)
                    case .upperBound:
                        return
                }
                if let _ = fromId, rememberInStack {
                    self.historyNavigationStack.add(fromIndex)
                }
                self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                
                var quote: ChatControllerSubject.MessageHighlight.Quote?
                if case let .id(_, params) = messageLocation {
                    quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                }
                
                let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: searchLocation, quote: quote.flatMap { quote in MessageHistoryInitialSearchSubject.Quote(string: quote.string, offset: quote.offset) }), count: 50, highlight: true), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                var signal: Signal<MessageIndex?, NoError>
                signal = historyView
                |> mapToSignal { historyView -> Signal<MessageIndex?, NoError> in
                    switch historyView {
                        case .Loading:
                            return .complete()
                        case let .HistoryView(view, _, _, _, _, _, _):
                            for entry in view.entries {
                                if entry.message.id == messageLocation.messageId {
                                    return .single(entry.message.index)
                                }
                            }
                            return .single(nil)
                    }
                }
                |> take(1)
                
                self.messageIndexDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { [weak self] index in
                    if let strongSelf = self {
                        if let index = index {
                            strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                            completion?()
                        } else {
                            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageLocation.peerId))
                            |> deliverOnMainQueue).startStandalone(next: { peer in
                                guard let strongSelf = self, let peer = peer else {
                                    return
                                }
                                
                                if let navigationController = strongSelf.effectiveNavigationController {
                                    var quote: ChatControllerSubject.MessageHighlight.Quote?
                                    if case let .id(_, params) = messageLocation {
                                        quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                                    }
                                    
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: quote), timecode: nil) }))
                                }
                            })
                            completion?()
                        }
                    }
                }, completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(.single(nil))
                    }
                }))
            } else {
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageLocation.peerId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                    guard let self, let peer = peer else {
                        return
                    }
                    if let navigationController = self.effectiveNavigationController {
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil) }))
                    }
                    completion?()
                })
            }
        }
    }
}
