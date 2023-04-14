import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public final class PeerMediaUploadingItem: Equatable {
    public enum ProgressValue {
        case progress(Float)
        case done(Api.Updates)
    }
    
    public enum Error {
        case generic
        case flood
    }
    
    public enum Content: Equatable  {
        case wallpaper(TelegramWallpaper)
    }

    public let content: Content
    public let messageId: EngineMessage.Id?
    public let progress: Float
    
    init(content: Content, messageId: EngineMessage.Id?, progress: Float) {
        self.content = content
        self.messageId = messageId
        self.progress = progress
    }
    
    public static func ==(lhs: PeerMediaUploadingItem, rhs: PeerMediaUploadingItem) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.progress != rhs.progress {
            return false
        }
        return true
    }
    
    func withMessageId(_ messageId: EngineMessage.Id) -> PeerMediaUploadingItem {
        return PeerMediaUploadingItem(content: self.content, messageId: messageId, progress: self.progress)
    }
    
    func withProgress(_ progress: Float) -> PeerMediaUploadingItem {
        return PeerMediaUploadingItem(content: self.content, messageId: self.messageId, progress: progress)
    }
}

private func uploadPeerMedia(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: EnginePeer.Id, content: PeerMediaUploadingItem.Content) -> Signal<PeerMediaUploadingItem.ProgressValue, PeerMediaUploadingItem.Error> {
    switch content {
    case let .wallpaper(wallpaper):
        if case let .image(representations, settings) = wallpaper, let resource = representations.last?.resource as? LocalFileMediaResource {
            return _internal_uploadWallpaper(postbox: postbox, network: network, resource: resource, settings: settings, forChat: true)
            |> mapError { error -> PeerMediaUploadingItem.Error in
                return .generic
            }
            |> mapToSignal { value -> Signal<PeerMediaUploadingItem.ProgressValue, PeerMediaUploadingItem.Error> in
                switch value {
                case let .progress(progress):
                    return .single(.progress(progress))
                case let .complete(result):
                    if case let .file(file) = result {
                        postbox.mediaBox.copyResourceData(from: resource.id, to: file.file.resource.id, synchronous: true)
                        for representation in file.file.previewRepresentations {
                            postbox.mediaBox.copyResourceData(from: resource.id, to: representation.resource.id, synchronous: true)
                        }
                    }
                    return _internal_setChatWallpaper(postbox: postbox, network: network, stateManager: stateManager, peerId: peerId, wallpaper: result, applyUpdates: false)
                    |> mapError { error -> PeerMediaUploadingItem.Error in
                        switch error {
                        case .generic:
                            return .generic
                        case .flood:
                            return .flood
                        }
                    }
                    |> map { updates -> PeerMediaUploadingItem.ProgressValue in
                        return .done(updates)
                    }
                }
                
            }
        } else {
            return _internal_setChatWallpaper(postbox: postbox, network: network, stateManager: stateManager, peerId: peerId, wallpaper: wallpaper, applyUpdates: false)
            |> mapError { error -> PeerMediaUploadingItem.Error in
                switch error {
                case .generic:
                    return .generic
                case .flood:
                    return .flood
                }
            }
            |> map { updates -> PeerMediaUploadingItem.ProgressValue in
                return .done(updates)
            }
        }
    }
}

private func generatePeerMediaMessage(network: Network, accountPeerId: EnginePeer.Id, transaction: Transaction, peerId: PeerId, content: PeerMediaUploadingItem.Content) -> StoreMessage {
    var randomId: Int64 = 0
    arc4random_buf(&randomId, 8)

    var timestamp = Int32(network.context.globalTime())
    switch peerId.namespace {
        case Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudUser:
            if let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                timestamp = max(timestamp, topIndex.timestamp)
            }
        default:
            break
    }
    
    var flags = StoreMessageFlags()
    flags.insert(.Unsent)
    flags.insert(.Sending)
    
    var attributes: [MessageAttribute] = []
    attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: [], acknowledged: false, correlationId: nil, bubbleUpEmojiOrStickersets: []))
    
    var media: [Media] = []
    switch content {
    case let .wallpaper(wallpaper):
        media.append(TelegramMediaAction(action: .setChatWallpaper(wallpaper: wallpaper)))
    }
    
    return StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: accountPeerId, text: "", attributes: attributes, media: media)
}

private final class PendingPeerMediaUploadContext {
    var value: PeerMediaUploadingItem
    let disposable = MetaDisposable()
    
    init(value: PeerMediaUploadingItem) {
        self.value = value
    }
}

private final class PendingPeerMediaUploadManagerImpl {
    let queue: Queue
    let postbox: Postbox
    let network: Network
    let stateManager: AccountStateManager
    let accountPeerId: EnginePeer.Id
    
    let sentMessageEventPipe: ValuePipe<EnginePeer.Id>
    
    private var uploadingPeerMediaValue: [EnginePeer.Id: PeerMediaUploadingItem] = [:] {
        didSet {
            if self.uploadingPeerMediaValue != oldValue {
                self.uploadingPeerMediaPromise.set(.single(self.uploadingPeerMediaValue))
            }
        }
    }
    private let uploadingPeerMediaPromise = Promise<[EnginePeer.Id: PeerMediaUploadingItem]>()
    fileprivate var uploadingPeerMedia: Signal<[EnginePeer.Id: PeerMediaUploadingItem], NoError> {
        return self.uploadingPeerMediaPromise.get()
    }
    
    private var contexts: [PeerId: PendingPeerMediaUploadContext] = [:]
    
    init(queue: Queue, postbox: Postbox, network: Network, stateManager: AccountStateManager, accountPeerId: EnginePeer.Id) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.stateManager = stateManager
        self.accountPeerId = accountPeerId
        
        self.sentMessageEventPipe = ValuePipe()
        
        self.uploadingPeerMediaPromise.set(.single(self.uploadingPeerMediaValue))
    }
    
    deinit {
        for (_, context) in self.contexts {
            context.disposable.dispose()
        }
    }
    
    private func updateValues() {
        self.uploadingPeerMediaValue = self.contexts.mapValues { context in
            return context.value
        }
    }
    
    func add(peerId: EnginePeer.Id, content: PeerMediaUploadingItem.Content) {
        if let context = self.contexts[peerId] {
            self.contexts.removeValue(forKey: peerId)
            context.disposable.dispose()
        }
        
        let postbox = self.postbox
        let network = self.network
        let stateManager = self.stateManager
        let accountPeerId = self.accountPeerId
        
        let queue = self.queue
        let context = PendingPeerMediaUploadContext(value: PeerMediaUploadingItem(content: content, messageId: nil, progress: 0.0))
        self.contexts[peerId] = context
        
        context.disposable.set(
            (self.postbox.transaction({ transaction -> EngineMessage.Id? in
                let storeMessage = generatePeerMediaMessage(network: network, accountPeerId: accountPeerId, transaction: transaction, peerId: peerId, content: content)
                let globallyUniqueIdToMessageId = transaction.addMessages([storeMessage], location: .Random)
                guard let globallyUniqueId = storeMessage.globallyUniqueId, let messageId = globallyUniqueIdToMessageId[globallyUniqueId] else {
                    return nil
                }
                return messageId
            })
            |> deliverOn(queue)).start(next: { [weak self, weak context] messageId in
                guard let strongSelf = self, let initialContext = context else {
                    return
                }
                if let context = strongSelf.contexts[peerId], context === initialContext {
                    guard let messageId = messageId else {
                        strongSelf.contexts.removeValue(forKey: peerId)
                        context.disposable.dispose()
                        strongSelf.updateValues()
                        return
                    }
                    context.value = context.value.withMessageId(messageId)
                    strongSelf.updateValues()
                    
                    strongSelf.sentMessageEventPipe.putNext(peerId)
                    
                    context.disposable.set((uploadPeerMedia(postbox: postbox, network: network, stateManager: stateManager, peerId: peerId, content: content)
                    |> deliverOn(queue)).start(next: { [weak self, weak context] value in
                        guard let strongSelf = self, let initialContext = context else {
                            return
                        }
                        if let context = strongSelf.contexts[peerId], context === initialContext {
                            switch value {
                            case let .done(result):
                                context.disposable.set(
                                    (postbox.transaction({ transaction -> Message? in
                                        return transaction.getMessage(messageId)
                                    })
                                    |> deliverOn(queue)
                                    ).start(next: { [weak self, weak context] message in
                                        guard let strongSelf = self, let initialContext = context else {
                                            return
                                        }
                                        if let context = strongSelf.contexts[peerId], context === initialContext {
                                            guard let message = message else {
                                                strongSelf.contexts.removeValue(forKey: peerId)
                                                context.disposable.dispose()
                                                strongSelf.updateValues()
                                                return
                                            }
                                            context.disposable.set(
                                                (applyUpdateMessage(
                                                    postbox: postbox,
                                                    stateManager: stateManager,
                                                    message: message,
                                                    cacheReferenceKey: nil,
                                                    result: result,
                                                    accountPeerId: accountPeerId
                                                )
                                                |> deliverOn(queue)).start(completed: { [weak self, weak context] in
                                                    guard let strongSelf = self, let initialContext = context else {
                                                        return
                                                    }
                                                    if let context = strongSelf.contexts[peerId], context === initialContext {
                                                        strongSelf.contexts.removeValue(forKey: peerId)
                                                        context.disposable.dispose()
                                                        strongSelf.updateValues()
                                                    }
                                                })
                                            )
                                        }
                                    })
                                )
                                strongSelf.updateValues()
                            case let .progress(progress):
                                context.value = context.value.withProgress(progress)
                                strongSelf.updateValues()
                            }
                        }
                    }, error: { [weak self, weak context] error in
                        guard let strongSelf = self, let initialContext = context else {
                            return
                        }
                        if let context = strongSelf.contexts[peerId], context === initialContext {
                            strongSelf.contexts.removeValue(forKey: peerId)
                            
                            if let messageId = context.value.messageId {
                                context.disposable.set(strongSelf.postbox.transaction({ transaction in
                                    transaction.deleteMessages([messageId], forEachMedia: nil)
                                }).start())
                            } else {
                                context.disposable.dispose()
                            }
                            
                            strongSelf.updateValues()
                        }
                    }))
                }
            })
        )
    }
    
    func cancel(peerId: EnginePeer.Id) {
        if let context = self.contexts[peerId] {
            self.contexts.removeValue(forKey: peerId)
            
            if let messageId = context.value.messageId {
                context.disposable.set(self.postbox.transaction({ transaction in
                    transaction.deleteMessages([messageId], forEachMedia: nil)
                }).start())
            } else {
                context.disposable.dispose()
            }

            self.updateValues()
        }
    }
    
    func uploadProgress(messageId: EngineMessage.Id) -> Signal<Float?, NoError> {
        return self.uploadingPeerMedia
        |> map { uploadingPeerMedia in
            if let item = uploadingPeerMedia[messageId.peerId], item.messageId == messageId {
                return item.progress
            } else {
                return nil
            }
        }
        |> distinctUntilChanged
    }
    
    public func sentMessageEvents(peerId: EnginePeer.Id) -> Signal<Void, NoError> {
        return self.sentMessageEventPipe.signal()
        |> mapToSignal { eventPeerId -> Signal<Void, NoError> in
            if eventPeerId == peerId {
                return .single(Void())
            } else {
                return .complete()
            }
        }
    }
}

public final class PendingPeerMediaUploadManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<PendingPeerMediaUploadManagerImpl>
    
    public var uploadingPeerMedia: Signal<[EnginePeer.Id: PeerMediaUploadingItem], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.uploadingPeerMedia.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    init(postbox: Postbox, network: Network, stateManager: AccountStateManager, accountPeerId: EnginePeer.Id) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PendingPeerMediaUploadManagerImpl(queue: queue, postbox: postbox, network: network, stateManager: stateManager, accountPeerId: accountPeerId)
        })
    }
    
    public func add(peerId: EnginePeer.Id, content: PeerMediaUploadingItem.Content) {
        self.impl.with { impl in
            impl.add(peerId: peerId, content: content)
        }
    }
    
    public func cancel(peerId: EnginePeer.Id) {
        self.impl.with { impl in
            impl.cancel(peerId: peerId)
        }
    }
    
    public func uploadProgress(messageId: EngineMessage.Id) -> Signal<Float?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.uploadProgress(messageId: messageId).start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public func sentMessageEvents(peerId: EnginePeer.Id) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.sentMessageEvents(peerId: peerId).start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
