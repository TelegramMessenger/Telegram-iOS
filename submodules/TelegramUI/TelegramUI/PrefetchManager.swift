import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

private final class PrefetchMediaContext {
    let fetchDisposable = MetaDisposable()
    
    init() {
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
                    return.cellular
                case .wifi:
                    return .wifi
            }
        }
        |> distinctUntilChanged
        
        self.listDisposable = (combineLatest(account.viewTracker.orderedPreloadMedia, sharedContext.automaticMediaDownloadSettings, networkType)
        |> deliverOn(self.queue)).start(next: { [weak self] orderedPreloadMedia, automaticDownloadSettings, networkType in
            self?.updateOrderedPreloadMedia(orderedPreloadMedia, automaticDownloadSettings: automaticDownloadSettings, networkType: networkType)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.listDisposable?.dispose()
    }
    
    private func updateOrderedPreloadMedia(_ orderedPreloadMedia: [ChatHistoryPreloadMediaItem], automaticDownloadSettings: MediaAutoDownloadSettings, networkType: MediaAutoDownloadNetworkType) {
        var validIds = Set<MediaId>()
        for mediaItem in orderedPreloadMedia {
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
