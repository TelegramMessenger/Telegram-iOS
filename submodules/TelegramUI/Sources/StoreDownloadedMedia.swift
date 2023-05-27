import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import Photos
import TelegramUIPreferences
import AccountContext

private func appSpecificAssetCollection() -> Signal<PHAssetCollection, NoError> {
    return Signal { subscriber in
        let fetchOption = PHFetchOptions()
        let albumName = "Telegram"
        fetchOption.predicate = NSPredicate(format: "title == '" + albumName + "'")
        
        let fetchResult = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOption)
        
        if let collection = fetchResult.firstObject {
            subscriber.putNext(collection)
            subscriber.putCompletion()
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            }, completionHandler: { success, error in
                if let error = error {
                    Logger.shared.log("appSpecificAssetCollection", "error: \(error)")
                }
                
                if success {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(
                        with: .album,
                        subtype: .albumRegular,
                        options: fetchOption)
                    if let collection = fetchResult.firstObject {
                        subscriber.putNext(collection)
                        subscriber.putCompletion()
                    }
                }
            })
        }
        
        return EmptyDisposable
    }
}

private final class DownloadedMediaStoreContext {
    private let queue: Queue
    private var disposable: Disposable?
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func start(postbox: Postbox, collection: Signal<PHAssetCollection, NoError>, peerId: EnginePeer.Id, timestamp: Int32, media: AnyMediaReference, completed: @escaping () -> Void) {
        var resource: TelegramMediaResource?
        if let image = media.media as? TelegramMediaImage {
            resource = largestImageRepresentation(image.representations)?.resource
        } else if let file = media.media as? TelegramMediaFile {
            resource = file.resource
        }
        if let resource = resource {
            self.disposable = (postbox.transaction { transaction -> (MediaAutoSaveSettings, EnginePeer?) in
                let peer = transaction.getPeer(peerId).flatMap(EnginePeer.init)
                guard let entry = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings)?.get(MediaAutoSaveSettings.self) else {
                    return (.default, peer)
                }
                return (entry, peer)
            }
            |> map { storeSettings, peer -> Bool in
                guard let peer = peer else {
                    return false
                }
                
                let configuration: MediaAutoSaveConfiguration
                if let exception = storeSettings.exceptions.first(where: { $0.id == peerId }) {
                    configuration = exception.configuration
                } else {
                    let peerTypeValue: MediaAutoSaveSettings.PeerType
                    switch peer {
                    case .user:
                        peerTypeValue = .users
                    case .secretChat:
                        return false
                    case .legacyGroup:
                        peerTypeValue = .groups
                    case let .channel(channel):
                        if channel.flags.contains(.copyProtectionEnabled) {
                            return false
                        }
                        
                        if case .broadcast = channel.info {
                            peerTypeValue = .channels
                        } else {
                            peerTypeValue = .groups
                        }
                    }
                    configuration = storeSettings.configurations[peerTypeValue] ?? .default
                }
                
                if let _ = media.media as? TelegramMediaImage {
                    if configuration.photo {
                        return true
                    } else {
                        return false
                    }
                } else if let file = media.media as? TelegramMediaFile {
                    if configuration.video, let fileSize = file.size, fileSize <= configuration.maximumVideoSize {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
            |> take(1)
            |> mapToSignal { store -> Signal<(PHAssetCollection, MediaResourceData), NoError> in
                if !store {
                    return .complete()
                } else {
                    return combineLatest(collection |> take(1), postbox.mediaBox.resourceData(resource))
                }
            }
            |> deliverOn(queue)).start(next: { collection, data in
                if !data.complete {
                    return
                }
                
                var filename: String?
                if let image = media.media as? TelegramMediaImage {
                    filename = "telegram-photo-\(image.imageId.namespace)-\(image.imageId.id).jpg"
                } else if let file = media.media as? TelegramMediaFile {
                    filename = "telegram-video-\(file.fileId.namespace)-\(file.fileId.id).mov"
                }
                let creationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                
                let storeAsset: () -> Void = {
                    if let _ = media.media as? TelegramMediaImage {
                        PHPhotoLibrary.shared().performChanges({
                            if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                let creationRequest = PHAssetCreationRequest.forAsset()
                                let options = PHAssetResourceCreationOptions()
                                if let filename = filename {
                                    options.originalFilename = filename
                                }
                                creationRequest.addResource(with: .photo, data: fileData, options: options)
                                creationRequest.creationDate = creationDate
                                let request = PHAssetCollectionChangeRequest(for: collection)
                                if let placeholderForCreatedAsset = creationRequest.placeholderForCreatedAsset {
                                    request?.addAssets([placeholderForCreatedAsset] as NSArray)
                                }
                            }
                        })
                    } else if let file = media.media as? TelegramMediaFile, file.isVideo {
                        let tempFile = TempBox.shared.tempFile(fileName: filename ?? "file.mov")
                        
                        PHPhotoLibrary.shared().performChanges({
                            if let _ = try? FileManager.default.copyItem(atPath: data.path, toPath: tempFile.path) {
                                let creationRequest = PHAssetCreationRequest.forAsset()
                                let options = PHAssetResourceCreationOptions()
                                if let filename = filename {
                                    options.originalFilename = filename
                                }
                                creationRequest.addResource(with: .video, fileURL: URL(fileURLWithPath: tempFile.path), options: options)
                                creationRequest.creationDate = creationDate
                                let request = PHAssetCollectionChangeRequest(for: collection)
                                if let placeholderForCreatedAsset = creationRequest.placeholderForCreatedAsset {
                                    request?.addAssets([placeholderForCreatedAsset] as NSArray)
                                }
                            }
                        }, completionHandler: { _, error in
                            if let error = error {
                                print("\(error)")
                            }
                            TempBox.shared.dispose(tempFile)
                        })
                    }
                }
                
                let options = PHFetchOptions()
                if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                    options.fetchLimit = 11
                }
                
                options.predicate = NSPredicate(format: "creationDate == %@", creationDate as CVarArg)
                var alreadyStored = false
                let assets = PHAsset.fetchAssets(in: collection, options: options)
                assets.enumerateObjects({ asset, _, done in
                    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                        if let assetResource = PHAssetResource.assetResources(for: asset).first {
                            if assetResource.originalFilename == filename {
                                alreadyStored = true
                                done.pointee = true
                            }
                        }
                    }
                })
                
                if !alreadyStored {
                    storeAsset()
                }
                
                completed()
            })
        } else {
            completed()
        }
    }
}

private final class DownloadedMediaStoreManagerPrivateImpl {
    private let queue: Queue
    private let postbox: Postbox
    
    private var nextId: Int32 = 1
    private var storeContexts: [MediaId: DownloadedMediaStoreContext] = [:]
    
    private let appSpecificAssetCollectionValue: Promise<PHAssetCollection>
    private let storeSettings = Promise<MediaAutoDownloadSettings>()
    
    init(queue: Queue, postbox: Postbox, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.queue = queue
        self.postbox = postbox
        
        self.appSpecificAssetCollectionValue = Promise(initializeOnFirstAccess: appSpecificAssetCollection())
        self.storeSettings.set(accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
        |> map { sharedData -> MediaAutoDownloadSettings in
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                return settings
            } else {
                return .defaultSettings
            }
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    private func takeNextId() -> Int32 {
        let nextId = self.nextId
        self.nextId += 1
        return nextId
    }
    
    func store(_ media: AnyMediaReference, timestamp: Int32, peerId: EnginePeer.Id) {
        guard let id = media.media.id else {
            return
        }
        if self.storeContexts[id] == nil {
            let context = DownloadedMediaStoreContext(queue: self.queue)
            self.storeContexts[id] = context
            let appSpecificAssetCollectionValue = self.appSpecificAssetCollectionValue
            context.start(postbox: self.postbox, collection: deferred { appSpecificAssetCollectionValue.get() }, peerId: peerId, timestamp: timestamp, media: media, completed: { [weak self, weak context] in
                guard let strongSelf = self, let context = context else {
                    return
                }
                assert(strongSelf.queue.isCurrent())
                if strongSelf.storeContexts[id] === context {
                    strongSelf.storeContexts.removeValue(forKey: id)
                }
            })
        }
    }
}

final class DownloadedMediaStoreManagerImpl: DownloadedMediaStoreManager {
    private let queue = Queue()
    private let postbox: Postbox
    private let impl: QueueLocalObject<DownloadedMediaStoreManagerPrivateImpl>
    
    init(postbox: Postbox, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let queue = self.queue
        self.postbox = postbox
        self.impl = QueueLocalObject(queue: queue, generate: {
            return DownloadedMediaStoreManagerPrivateImpl(queue: queue, postbox: postbox, accountManager: accountManager)
        })
    }
    
    func store(_ media: AnyMediaReference, timestamp: Int32, peerId: EnginePeer.Id) {
        self.impl.with { impl in
            impl.store(media, timestamp: timestamp, peerId: peerId)
        }
    }
    
    func runTasks() {
        let _ = (self.postbox.transaction({ transaction -> [(index: Int32, message: Message, mediaId: MediaId)] in
            return _internal_getSynchronizeAutosaveItemOperations(transaction: transaction)
        })
        |> deliverOnMainQueue).start(next: { [weak self] items in
            guard let self else {
                return
            }
            for item in items {
                for media in item.message.media {
                    if let id = media.id, id == item.mediaId {
                        self.store(.standalone(media: media), timestamp: item.message.timestamp, peerId: item.message.id.peerId)
                        break
                    }
                }
            }
            
            let _ = self.postbox.transaction({ transaction -> Void in
                return _internal_removeSyncrhonizeAutosaveItemOperations(transaction: transaction, indices: items.map(\.index))
            }).start()
        })
    }
}
