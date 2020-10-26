import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences
import AccountContext
import PhotoResources
import Emoji

private final class PrefetchMediaContext {
    let fetchDisposable = MetaDisposable()
    
    init() {
    }
}

public enum PrefetchMediaItem {
    case chatHistory(ChatHistoryPreloadMediaItem)
    case animatedEmojiSticker(TelegramMediaFile)
}

private struct AnimatedEmojiSoundsConfiguration {
    static var defaultValue: AnimatedEmojiSoundsConfiguration {
        return AnimatedEmojiSoundsConfiguration(sounds: [:])
    }
    
    public let sounds: [String: TelegramMediaFile]
    
    fileprivate init(sounds: [String: TelegramMediaFile]) {
        self.sounds = sounds
    }
    
    static func with(appConfiguration: AppConfiguration) -> AnimatedEmojiSoundsConfiguration {
        if let data = appConfiguration.data, let values = data["emojies_sounds"] as? [String: Any] {
            var sounds: [String: TelegramMediaFile] = [:]
            for (key, value) in values {
                if let dict = value as? [String: String], var fileReferenceString = dict["file_reference_base64"] {
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "-", with: "+")
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "_", with: "/")
                    while fileReferenceString.count % 4 != 0 {
                        fileReferenceString.append("=")
                    }
                    
                    if let idString = dict["id"], let id = Int64(idString), let accessHashString = dict["access_hash"], let accessHash = Int64(accessHashString), let fileReference = Data(base64Encoded: fileReferenceString) {
                        let resource = CloudDocumentMediaResource(datacenterId: 0, fileId: id, accessHash: accessHash, size: nil, fileReference: fileReference, fileName: nil)
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: [])
                        sounds[key] = file
                    }
                }
            }
            return AnimatedEmojiSoundsConfiguration(sounds: sounds)
        } else {
            return .defaultValue
        }
    }
}

private final class PrefetchManagerImpl {
    private let queue: Queue
    private let account: Account
    private let fetchManager: FetchManager
    
    private var listDisposable: Disposable?
    
    private var contexts: [MediaId: PrefetchMediaContext] = [:]
    
    init(queue: Queue, sharedContext: SharedAccountContext, account: Account, fetchManager: FetchManager) {
        self.queue = queue
        self.account = account
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
            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
        }
        
        let orderedPreloadMedia = combineLatest(account.viewTracker.orderedPreloadMedia, loadedStickerPack(postbox: account.postbox, network: account.network, reference: .animatedEmoji, forceActualized: false), appConfiguration)
        |> map { orderedPreloadMedia, stickerPack, appConfiguration -> [PrefetchMediaItem] in
            let emojiSounds = AnimatedEmojiSoundsConfiguration.with(appConfiguration: appConfiguration)
            let chatHistoryMediaItems = orderedPreloadMedia.map { PrefetchMediaItem.chatHistory($0) }
            var stickerItems: [PrefetchMediaItem] = []
            
            var prefetchItems: [PrefetchMediaItem] = []
            
            switch stickerPack {
                case let .result(_, items, _):
                    var animatedEmojiStickers: [String: StickerPackItem] = [:]
                    for case let item as StickerPackItem in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = item
                        }
                    }
                    
                    let popularEmoji = ["\u{2764}", "👍", "😳", "😒", "🥳"]
                    for emoji in popularEmoji {
                        if let sticker = animatedEmojiStickers[emoji] {
                            if let _ = account.postbox.mediaBox.completedResourcePath(sticker.file.resource) {
                            } else {
                                stickerItems.append(.animatedEmojiSticker(sticker.file))
                            }
                        }
                    }
                    return stickerItems
                default:
                    break
            }
            
            prefetchItems.append(contentsOf: chatHistoryMediaItems)
            prefetchItems.append(contentsOf: stickerItems)
            
            return prefetchItems
        }
        
        self.listDisposable = (combineLatest(orderedPreloadMedia, sharedContext.automaticMediaDownloadSettings, networkType)
        |> deliverOn(self.queue)).start(next: { [weak self] orderedPreloadMedia, automaticDownloadSettings, networkType in
            self?.updateOrderedPreloadMedia(orderedPreloadMedia, automaticDownloadSettings: automaticDownloadSettings, networkType: networkType)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.listDisposable?.dispose()
    }
    
    private func updateOrderedPreloadMedia(_ items: [PrefetchMediaItem], automaticDownloadSettings: MediaAutoDownloadSettings, networkType: MediaAutoDownloadNetworkType) {
        var validIds = Set<MediaId>()
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
                    var mediaResource: MediaResource?
                    
                    if let telegramImage = mediaItem.media.media as? TelegramMediaImage {
                        mediaResource = largestRepresentationForPhoto(telegramImage)?.resource
                        if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: peerType, networkType: networkType, authorPeerId: nil, contactsPeerIds: [], media: telegramImage) {
                            automaticDownload = .full
                        }
                    } else if let telegramFile = mediaItem.media.media as? TelegramMediaFile {
                        mediaResource = telegramFile.resource
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
                                context.fetchDisposable.set(messageMediaImageInteractiveFetched(fetchManager: self.fetchManager, messageId: mediaItem.media.index.id, messageReference: MessageReference(peer: mediaItem.media.peer, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false), image: image, resource: resource, userInitiated: false, priority: priority, storeToDownloadsPeerType: nil).start())
                            } else if let _ = media as? TelegramMediaWebFile {
                                //strongSelf.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: context.account, image: image).start())
                            } else if let file = media as? TelegramMediaFile {
                                let fetchSignal = messageMediaFileInteractiveFetched(fetchManager: self.fetchManager, messageId: mediaItem.media.index.id, messageReference: MessageReference(peer: mediaItem.media.peer, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false), file: file, userInitiated: false, priority: priority)
                                context.fetchDisposable.set(fetchSignal.start())
                            }
                        } else if case .prefetch = automaticDownload, mediaItem.media.peer.id.namespace != Namespaces.Peer.SecretChat {
                            if let file = media as? TelegramMediaFile, let _ = file.size {
                                context.fetchDisposable.set(preloadVideoResource(postbox: self.account.postbox, resourceReference: FileMediaReference.message(message: MessageReference(peer: mediaItem.media.peer, id: mediaItem.media.index.id, timestamp: mediaItem.media.index.timestamp, incoming: true, secret: false), media: file).resourceReference(file.resource), duration: 4.0).start())
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
                        
                        let priority: FetchManagerPriority = .backgroundPrefetch(locationOrder: HistoryPreloadIndex(index: nil, hasUnread: false, isMuted: false, isPriority: true), localOrder: MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: order), timestamp: 0))
                        
                        if case .full = automaticDownload {
                            let fetchSignal = freeMediaFileInteractiveFetched(fetchManager: self.fetchManager, fileReference: .standalone(media: media), priority: priority)
                            context.fetchDisposable.set(fetchSignal.start())
                        }
                        
                        order += 1
                }
            }
        }
        var removeIds: [MediaId] = []
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
}

final class PrefetchManager {
    private let queue: Queue
    
    private let impl: QueueLocalObject<PrefetchManagerImpl>
    
    init(sharedContext: SharedAccountContext, account: Account, fetchManager: FetchManager) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PrefetchManagerImpl(queue: queue, sharedContext: sharedContext, account: account, fetchManager: fetchManager)
        })
    }
}
