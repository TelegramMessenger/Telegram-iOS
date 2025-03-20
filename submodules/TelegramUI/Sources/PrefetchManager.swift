import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext
import PhotoResources
import StickerResources
import Emoji
import UniversalMediaPlayer
import ChatMessageInteractiveMediaNode
import ChatMessageAnimatedStickerItemNode

private final class PrefetchMediaContext {
    let fetchDisposable = MetaDisposable()
    
    init() {
    }
}

public enum PrefetchMediaItem {
    case chatHistory(ChatHistoryPreloadMediaItem)
    case animatedEmojiSticker(TelegramMediaFile)
}

private final class PrefetchManagerInnerImpl {
    private let queue: Queue
    private let account: Account
    private let engine: TelegramEngine
    private let fetchManager: FetchManager
    
    private var listDisposable: Disposable?
    
    private var contexts: [EngineMedia.Id: PrefetchMediaContext] = [:]

    private let preloadGreetingStickerDisposable = MetaDisposable()
    fileprivate let preloadedGreetingStickerPromise = Promise<TelegramMediaFile?>(nil)

    init(queue: Queue, sharedContext: SharedAccountContext, account: Account, engine: TelegramEngine, fetchManager: FetchManager) {
        self.queue = queue
        self.account = account
        self.engine = engine
        self.fetchManager = fetchManager
        
        let networkType = account.networkType
        |> map { networkType -> MediaAutoDownloadNetworkType in
            switch networkType {
                case .none, .cellular:
                    return .cellular
                case .wifi:
                    return .wifi
            }
        }
        |> distinctUntilChanged
        
        let appConfiguration = account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> take(1)
        |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        }
        
        let orderedPreloadMedia = combineLatest(account.viewTracker.orderedPreloadMedia, TelegramEngine(account: account).stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false), appConfiguration)
        |> map { orderedPreloadMedia, stickerPack, appConfiguration -> [PrefetchMediaItem] in
            let emojiSounds = AnimatedEmojiSoundsConfiguration.with(appConfiguration: appConfiguration, account: account)
            let chatHistoryMediaItems = orderedPreloadMedia.map { PrefetchMediaItem.chatHistory($0) }
            var stickerItems: [PrefetchMediaItem] = []
            switch stickerPack {
                case let .result(_, items, _):
                    var animatedEmojiStickers: [String: StickerPackItem] = [:]
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = item
                        }
                    }
                    
                    let popularEmoji = ["\u{2764}", "👍", "👎", "😳", "😒", "🥳", "😡", "😮", "😂", "😘", "😍", "🙄", "😎"]
                    for emoji in popularEmoji {
                        if let sticker = animatedEmojiStickers[emoji] {
                            let stickerFile = sticker.file._parse()
                            if let _ = account.postbox.mediaBox.completedResourcePath(stickerFile.resource) {
                            } else {
                                stickerItems.append(.animatedEmojiSticker(stickerFile))
                            }
                        }
                    }
                default:
                    break
            }
            
            var prefetchItems: [PrefetchMediaItem] = []
            prefetchItems.append(contentsOf: chatHistoryMediaItems)
            prefetchItems.append(contentsOf: stickerItems)
            prefetchItems.append(contentsOf: emojiSounds.sounds.values.map { .animatedEmojiSticker($0) })
            
            return prefetchItems
        }
        
        self.listDisposable = (combineLatest(orderedPreloadMedia, sharedContext.automaticMediaDownloadSettings, networkType)
        |> deliverOn(self.queue)).startStrict(next: { [weak self] orderedPreloadMedia, automaticDownloadSettings, networkType in
            self?.updateOrderedPreloadMedia(orderedPreloadMedia, automaticDownloadSettings: automaticDownloadSettings, networkType: networkType)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.listDisposable?.dispose()
    }
    
    private func updateOrderedPreloadMedia(_ items: [PrefetchMediaItem], automaticDownloadSettings: MediaAutoDownloadSettings, networkType: MediaAutoDownloadNetworkType) {
        #if DEBUG
        if "".isEmpty {
            return
        }
        #endif
        var validIds = Set<EngineMedia.Id>()
        var order: Int32 = 0
        for mediaItem in items {
            switch mediaItem {
                case let .chatHistory(mediaItem):
                    guard let id = mediaItem.media.media.id else {
                        continue
                    }
                    if validIds.contains(id) {
                        continue
                    }
                    
                    var automaticDownload: InteractiveMediaNodeAutodownloadMode = .none
                    let peerType: MediaAutoDownloadPeerType
                    if mediaItem.media.authorIsContact {
                        peerType = .contact
                    } else if let channel = mediaItem.media.peer as? TelegramChannel {
                        if case .group = channel.info {
                            peerType = .group
                        } else {
                            peerType = .channel
                        }
                    } else if mediaItem.media.peer is TelegramGroup {
                        peerType = .group
                    } else {
                        peerType = .otherPrivate
                    }
                    var mediaResource: EngineMediaResource?
                    
                    if let telegramImage = mediaItem.media.media as? TelegramMediaImage {
                        mediaResource = (largestRepresentationForPhoto(telegramImage)?.resource).flatMap(EngineMediaResource.init)
                        if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: peerType, networkType: networkType, authorPeerId: nil, contactsPeerIds: [], media: telegramImage) {
                            automaticDownload = .full
                        }
                    } else if let telegramFile = mediaItem.media.media as? TelegramMediaFile {
                        mediaResource = EngineMediaResource(telegramFile.resource)
                        if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: peerType, networkType: networkType, authorPeerId: nil, contactsPeerIds: [], media: telegramFile) {
                            automaticDownload = .full
                        } else if shouldPredownloadMedia(settings: automaticDownloadSettings, peerType: peerType, networkType: networkType, media: telegramFile) {
                            automaticDownload = .prefetch
                        }
                    }
                    
                    if case .none = automaticDownload {
                        continue
                    }
                    guard let resource = mediaResource else {
                        continue
                    }
                    
                    validIds.insert(id)
                    let context: PrefetchMediaContext
                    if let current = self.contexts[id] {
                        context = current
                    } else {
                        context = PrefetchMediaContext()
                        self.contexts[id] = context
                        
                        let media = mediaItem.media.media
                        
                        let priority: FetchManagerPriority = .backgroundPrefetch(locationOrder: mediaItem.preloadIndex, localOrder: mediaItem.media.index)
                        
                        if case .full = automaticDownload {
                            if let image = media as? TelegramMediaImage {
                                context.fetchDisposable.set(messageMediaImageInteractiveFetched(fetchManager: self.fetchManager, messageId: mediaItem.media.index.id, messageReference: MessageReference(peer: mediaItem.media.peer, author: nil, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false, threadId: nil), image: image, resource: resource._asResource(), userInitiated: false, priority: priority, storeToDownloadsPeerId: nil).startStrict())
                            } else if let _ = media as? TelegramMediaWebFile {
                                //strongSelf.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: context.account, image: image).startStrict())
                            } else if let file = media as? TelegramMediaFile {
                                let fetchSignal = messageMediaFileInteractiveFetched(fetchManager: self.fetchManager, messageId: mediaItem.media.index.id, messageReference: MessageReference(peer: mediaItem.media.peer, author: nil, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false, threadId: nil), file: file, userInitiated: false, priority: priority)
                                context.fetchDisposable.set(fetchSignal.startStrict())
                            }
                        } else if case .prefetch = automaticDownload, mediaItem.media.peer.id.namespace != Namespaces.Peer.SecretChat {
                            if let file = media as? TelegramMediaFile, let _ = file.size {
                                context.fetchDisposable.set(preloadVideoResource(postbox: self.account.postbox, userLocation: .peer(mediaItem.media.index.id.peerId), userContentType: MediaResourceUserContentType(file: file), resourceReference: FileMediaReference.message(message: MessageReference(peer: mediaItem.media.peer, author: nil, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false, threadId: nil), media: file).resourceReference(file.resource), duration: 4.0).startStrict())
                            }
                        }
                    }
                case let .animatedEmojiSticker(media):
                    guard let id = media.id else {
                        continue
                    }
                    if validIds.contains(id) {
                        continue
                    }

                    var automaticDownload: InteractiveMediaNodeAutodownloadMode = .none
                    let peerType = MediaAutoDownloadPeerType.contact
                    
                    if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: peerType, networkType: networkType, authorPeerId: nil, contactsPeerIds: [], media: media) {
                        automaticDownload = .full
                    }
                
                    if case .none = automaticDownload {
                        continue
                    }
   
                    validIds.insert(id)
                    let context: PrefetchMediaContext
                    if let current = self.contexts[id] {
                        context = current
                    } else {
                        context = PrefetchMediaContext()
                        self.contexts[id] = context
                        
                        let priority: FetchManagerPriority = .backgroundPrefetch(locationOrder: HistoryPreloadIndex(index: nil, threadId: nil, hasUnread: false, isMuted: false, isPriority: true), localOrder: EngineMessage.Index(id: EngineMessage.Id(peerId: EnginePeer.Id(0), namespace: 0, id: order), timestamp: 0))
                        
                        if case .full = automaticDownload {
                            let fetchSignal = freeMediaFileInteractiveFetched(fetchManager: self.fetchManager, fileReference: .standalone(media: media), priority: priority)
                            context.fetchDisposable.set(fetchSignal.startStrict())
                        }
                        
                        order += 1
                }
            }
        }
        var removeIds: [EngineMedia.Id] = []
        for key in self.contexts.keys {
            if !validIds.contains(key) {
                removeIds.append(key)
            }
        }
        for id in removeIds {
            if let context = self.contexts.removeValue(forKey: id) {
                context.fetchDisposable.dispose()
            }
        }
    }
    
    fileprivate func prepareNextGreetingSticker() {
        let account = self.account
        let engine = self.engine
        self.preloadedGreetingStickerPromise.set(.single(nil)
        |> then(engine.stickers.randomGreetingSticker()
        |> map { item in
            return item?.file
        }))
        
        self.preloadGreetingStickerDisposable.set((self.preloadedGreetingStickerPromise.get()
        |> mapToSignal { sticker -> Signal<Void, NoError> in
            if let sticker = sticker {
                return freeMediaFileInteractiveFetched(account: account, userLocation: .other, fileReference: .standalone(media: sticker))
                |> map { _ -> Void in
                    return Void()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else {
                return .complete()
            }
        }).startStrict())
    }
}

final class PrefetchManagerImpl: PrefetchManager {
    private let queue: Queue
    
    private let impl: QueueLocalObject<PrefetchManagerInnerImpl>
    private let uuid = Atomic<UUID>(value: UUID())
    
    init(sharedContext: SharedAccountContext, account: Account, engine: TelegramEngine, fetchManager: FetchManager) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PrefetchManagerInnerImpl(queue: queue, sharedContext: sharedContext, account: account, engine: engine, fetchManager: fetchManager)
        })
    }
    
    var preloadedGreetingSticker: ChatGreetingData {
        let signal: Signal<TelegramMediaFile?, NoError> = Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set((impl.preloadedGreetingStickerPromise.get() |> take(1)).start(next: { file in
                    subscriber.putNext(file)
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
        return ChatGreetingData(uuid: uuid.with { $0 }, sticker: signal)
    }
    
    func prepareNextGreetingSticker() {
        let _ = uuid.swap(UUID())
        self.impl.with { impl in
            impl.prepareNextGreetingSticker()
        }
    }
}
