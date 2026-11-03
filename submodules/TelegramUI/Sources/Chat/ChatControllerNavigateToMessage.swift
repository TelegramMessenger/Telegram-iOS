import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display
import ChatPresentationInterfaceState
import AccountContext
import ChatControllerInteraction
import OverlayStatusController
import TelegramPresentationData
import PresentationDataUtils
import UndoUI

// When navigating to a message in a forum/monoforum we must target the message's topic
// (a `.replyThread` location). Targeting the bare `.peer` makes navigateToChatController
// open the forum's topic list instead of the specific topic. Mirrors the inline resolution
// used by the `.peer`-chatLocation branches of navigateToMessage.
private func forumAwareNavigateLocation(peer: EnginePeer, threadId: Int64?) -> NavigateToChatControllerParams.Location {
    if case let .channel(channel) = peer, channel.isForumOrMonoForum, let threadId {
        return .replyThread(ChatReplyThreadMessage(peerId: peer.id, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
    } else {
        return .peer(peer)
    }
}

extension ChatControllerImpl {
    func navigateToMessage(
        fromId: EngineMessage.Id,
        id: EngineMessage.Id,
        params: NavigateToMessageParams
    ) {
        var id = id
        if case let .replyThread(message) = self.chatLocation, let effectiveMessageId = message.effectiveMessageId {
            if let channelMessageId = message.channelMessageId, id == channelMessageId {
                id = effectiveMessageId
            }
        }
        
        let continueNavigation: (EnginePeer?, EngineMessage?) -> Void = { [weak self] toPeer, toMessage in
            guard let self else {
                return
            }
            let forceInCurrentChat = fromId.peerId == id.peerId && !params.forceNew
            // A same-peer target is normally searched for in the current history, but a reply header can
            // point into a *different topic* of this forum (a "Reply in Another Chat" into a sibling topic).
            // Searching the current topic for it cannot succeed — it reports "Message doesn't exist" — and
            // the generic fallback would run that doomed search (possibly filling holes over the network)
            // before resolving the topic. The topic is already known here, so go straight to it, the same
            // way the fallback eventually does. Only when the target's topic is positively known to differ:
            // an unknown message keeps today's behaviour instead of landing on the forum's topic list.
            if forceInCurrentChat, case let .replyThread(currentThread) = self.chatLocation, currentThread.isForumPost, let toPeer, let toThreadId = toMessage?.threadId, toThreadId != currentThread.threadId, let navigationController = self.effectiveNavigationController {
                let quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: forumAwareNavigateLocation(peer: toPeer, threadId: toThreadId), subject: .message(id: .id(id), highlight: ChatControllerSubject.MessageHighlight(quote: quote), timecode: nil, setupReply: params.setupReply), keepStack: .always))
                return
            }
            self.navigateToMessage(from: fromId, to: .id(id, params), forceInCurrentChat: forceInCurrentChat, forceNew: params.forceNew, progress: params.progress)
        }
        
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id.peerId),
            TelegramEngine.EngineData.Item.Messages.Message(id: id)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] toPeer, toMessage in
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
            
            continueNavigation(toPeer, toMessage)
        })
    }
    
    func navigateToMessage(
        from fromId: EngineMessage.Id?,
        to messageLocation: NavigateToMessageLocation,
        scrollPosition: ListViewScrollPosition = .center(.bottom),
        rememberInStack: Bool = true,
        forceInCurrentChat: Bool = false,
        forceNew: Bool = false,
        dropStack: Bool = false,
        animated: Bool = true,
        completion: (() -> Void)? = nil,
        customPresentProgress: ((ViewController, Any?) -> Void)? = nil,
        progress: Promise<Bool>? = nil,
        statusSubject: ChatLoadingMessageSubject = .generic
    ) {
        if !self.isNodeLoaded {
            completion?()
            return
        }
        var fromIndex: EngineMessage.Index?
        
        var fromMessage: EngineMessage?
        if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
            fromIndex = message.index
            fromMessage = message
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
        if case .customChatContents = self.chatLocation, !forceNew {
            forceInCurrentChat = true
        }
        
        if isPinnedMessages || forceNew, let messageId = messageLocation.messageId {
            let peerSignal: Signal<EnginePeer?, NoError>
            if forceNew, let fromMessage, let peer = fromMessage.enginePeers[fromMessage.id.peerId] {
                peerSignal = .single(peer)
            } else {
                peerSignal = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
            }
            let _ = (combineLatest(
                peerSignal,
                self.context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: forceNew ? .cloud(skipLocal: false) : .local)
                |> `catch` { _ in
                    return .single(.result([]))
                }
                |> mapToSignal { result -> Signal<[EngineMessage], NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result.map(EngineMessage.init))
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
                if let message = messages.first, let threadId = message.threadId, case let .channel(channel) = message.enginePeers[message.id.peerId], channel.isForumOrMonoForum {
                    navigateToLocation = .replyThread(ChatReplyThreadMessage(peerId: peer.id, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: false,maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
                } else {
                    navigateToLocation = .peer(peer)
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: navigateToLocation, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always))
                
                completion?()
            })
        } else if case let .peer(peerId) = self.chatLocation, let messageId = messageLocation.messageId, (messageId.peerId != peerId && !forceInCurrentChat) || (isScheduledMessages && messageId.id != 0 && !Namespaces.Message.allNonRegular.contains(messageId.namespace)) {
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId),
                TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, message in
                guard let self, let peer = peer else {
                    return
                }
                
                var quote: ChatControllerSubject.MessageHighlight.Quote?
                if case let .id(_, params) = messageLocation {
                    quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                }
                var progressValue: Promise<Bool>?
                if let value = progress {
                    progressValue = value
                } else if case let .id(_, params) = messageLocation {
                    progressValue = params.progress
                }
                self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                
                var chatLocation: NavigateToChatControllerParams.Location = .peer(peer)
                var preloadChatLocation: ChatLocation = .peer(id: peer.id)
                var displayMessageNotFoundToast = false
                if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                    if let message = message, let threadId = message.threadId {
                        let replyThreadMessage = ChatReplyThreadMessage(peerId: peer.id, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)
                        chatLocation = .replyThread(replyThreadMessage)
                        preloadChatLocation = .replyThread(message: replyThreadMessage)
                    } else {
                        displayMessageNotFoundToast = true
                    }
                }
                
                let searchLocation: ChatHistoryInitialSearchLocation
                switch messageLocation {
                case let .id(id, _):
                    if case let .replyThread(message) = chatLocation, id == message.effectiveMessageId {
                        searchLocation = .index(.absoluteLowerBound())
                    } else {
                        searchLocation = .id(id)
                    }
                case let .index(index):
                    searchLocation = .index(index)
                case .upperBound:
                    searchLocation = .index(EngineMessage.Index.upperBound(peerId: chatLocation.peerId))
                }
                var historyView: Signal<ChatHistoryViewUpdate, NoError>
                
                let subject: ChatControllerSubject = .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: quote), timecode: nil, setupReply: false)
                
                historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: searchLocation), count: 50, highlight: true, setupReply: false), id: 0), context: self.context, chatLocation: preloadChatLocation, subject: subject, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), fixedCombinedReadStates: nil, tag: nil, additionalData: [])
                
                var signal: Signal<(EngineMessage.Index?, Bool), NoError>
                signal = historyView
                |> mapToSignal { historyView -> Signal<(EngineMessage.Index?, Bool), NoError> in
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
                    if let progressValue {
                        progressValue.set(.single(true))
                        return ActionDisposable {
                            Queue.mainQueue().async() {
                                progressValue.set(.single(false))
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
                |> delay(progressValue == nil ? 0.05 : 0.0, queue: Queue.mainQueue())
                let progressDisposable = MetaDisposable()
                var progressStarted = false
                self.messageIndexDisposable.set((signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                |> deliverOnMainQueue).startStrict(next: { [weak self] index in
                    guard let self else {
                        return
                    }
                    
                    if let index = index.0 {
                        let _ = index
                        //strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, quote: quote, scrollPosition: scrollPosition)
                    } else if index.1 {
                        if !progressStarted {
                            progressStarted = true
                            progressDisposable.set(progressSignal.start())
                        }
                        return
                    }
                    
                    if let navigationController = self.effectiveNavigationController {
                        let context = self.context
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: chatLocation, subject: subject, keepStack: .always, chatListCompletion: { chatListController in
                            if displayMessageNotFoundToast {
                                let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
                                chatListController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Conversation_MessageDoesntExist, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                                    return true
                                }), in: .current)
                            }
                        }))
                    }
                }, completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(.single(nil))
                    }
                    completion?()
                }))
                cancelImpl = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(.single(nil))
                        strongSelf.messageIndexDisposable.set(nil)
                    }
                }
                
                completion?()
            })
        } else if forceInCurrentChat {
            if let _ = fromId, let fromIndex = fromIndex, rememberInStack {
                self.contentData?.historyNavigationStack.add(fromIndex)
            }
            
            let scrollFromIndex: EngineMessage.Index?
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
                    var subject: EngineMessageReplyInnerSubject?
                    var setupReply = false
                    if case let .id(_, params) = messageLocation {
                        quote = params.quote.flatMap { quote in (string: quote.string, offset: quote.offset) }
                        setupReply = params.setupReply
                        subject = params.subject
                    }

                    self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: message.index, animated: animated, quote: quote, subject: subject, scrollPosition: scrollPosition, setupReply: setupReply)
                    
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
                        let _ = self.controllerInteraction?.openMessage(message._asMessage(), OpenMessageParams(mode: .timecode(timecode)))
                    }
                } else if case let .index(index) = messageLocation, index.id.id == 0, index.timestamp > 0, case .scheduledMessages = self.presentationInterfaceState.subject {
                    self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                } else {
                    var setupReply = false
                    var quote: (string: String, offset: Int?)?
                    if case let .id(messageId, params) = messageLocation {
                        if params.timestamp != nil {
                            self.scheduledScrollToMessageId = (messageId, params)
                        }
                        quote = params.quote.flatMap { ($0.string, $0.offset) }
                        setupReply = params.setupReply
                    }
                    var progress: Promise<Bool>?
                    if case let .id(_, params) = messageLocation {
                        progress = params.progress
                    }
                    self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                    
                    let searchLocation: ChatHistoryInitialSearchLocation
                    switch messageLocation {
                    case let .id(id, _):
                        if case let .replyThread(message) = self.chatLocation, id == message.effectiveMessageId {
                            searchLocation = .index(.absoluteLowerBound())
                        } else {
                            searchLocation = .id(id)
                        }
                    case let .index(index):
                        searchLocation = .index(index)
                    case .upperBound:
                        if let peerId = self.chatLocation.peerId {
                            searchLocation = .index(EngineMessage.Index.upperBound(peerId: peerId))
                        } else {
                            searchLocation = .index(.absoluteUpperBound())
                        }
                    }
                    var historyView: Signal<ChatHistoryViewUpdate, NoError>
                    historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: searchLocation), count: 50, highlight: true, setupReply: setupReply), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tag: nil, additionalData: [])
                    
                    var signal: Signal<(EngineMessage.Index?, Bool), NoError>
                    signal = historyView
                    |> mapToSignal { historyView -> Signal<(EngineMessage.Index?, Bool), NoError> in
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
                            strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, quote: quote, scrollPosition: scrollPosition, setupReply: setupReply)
                        } else if index.1 {
                            if !progressStarted {
                                progressStarted = true
                                progressDisposable.set(progressSignal.start())
                            }
                        } else if let strongSelf = self {
                            strongSelf.controllerInteraction?.displayUndo(.info(title: nil, text: strongSelf.presentationData.strings.Conversation_MessageDoesntExist, timeout: nil, customUndoText: nil))
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                        }
                        completion?()
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
                    self.contentData?.historyNavigationStack.add(fromIndex)
                }
                self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                
                var quote: ChatControllerSubject.MessageHighlight.Quote?
                var subject: EngineMessageReplyInnerSubject?
                var setupReply = false
                if case let .id(_, params) = messageLocation {
                    quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                    subject = params.subject
                    setupReply = params.setupReply
                }
                
                let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: searchLocation, quote: quote.flatMap { quote in MessageHistoryInitialSearchSubject.Quote(string: quote.string, offset: quote.offset) }, subject: subject), count: 50, highlight: true, setupReply: setupReply), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tag: nil, additionalData: [])
                var signal: Signal<EngineMessage.Index?, NoError>
                signal = historyView
                |> mapToSignal { historyView -> Signal<EngineMessage.Index?, NoError> in
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
                            let messageSignal: Signal<EngineMessage?, NoError>
                            if let messageId = messageLocation.messageId {
                                messageSignal = strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                            } else {
                                messageSignal = .single(nil)
                            }
                            let _ = (combineLatest(
                                strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageLocation.peerId)),
                                messageSignal
                            )
                            |> deliverOnMainQueue).startStandalone(next: { peer, message in
                                guard let strongSelf = self, let peer = peer else {
                                    return
                                }

                                if let navigationController = strongSelf.effectiveNavigationController {
                                    var quote: ChatControllerSubject.MessageHighlight.Quote?
                                    var setupReply = false
                                    if case let .id(_, params) = messageLocation {
                                        quote = params.quote.flatMap { quote in ChatControllerSubject.MessageHighlight.Quote(string: quote.string, offset: quote.offset) }
                                        setupReply = params.setupReply
                                    }

                                    let navigateToLocation = forumAwareNavigateLocation(peer: peer, threadId: message?.threadId)
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: navigateToLocation, subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: quote), timecode: nil, setupReply: setupReply) }, keepStack: .always))
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
                let messageSignal: Signal<EngineMessage?, NoError>
                if let messageId = messageLocation.messageId {
                    messageSignal = self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                } else {
                    messageSignal = .single(nil)
                }
                let _ = (combineLatest(
                    self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageLocation.peerId)),
                    messageSignal
                )
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, message in
                    guard let self, let peer = peer else {
                        return
                    }
                    if let navigationController = self.effectiveNavigationController {
                        let navigateToLocation = forumAwareNavigateLocation(peer: peer, threadId: message?.threadId)
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: navigateToLocation, subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false) }))
                    }
                    completion?()
                })
            }
        }
    }
}
