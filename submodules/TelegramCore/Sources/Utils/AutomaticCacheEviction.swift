import Foundation
import SwiftSignalKit
import Postbox

final class AutomaticCacheEvictionContext {
    private final class Impl {
        private struct CombinedSettings: Equatable {
            var categoryStorageTimeout: [CacheStorageSettings.PeerStorageCategory: Int32]
            var exceptions: [AccountSpecificCacheStorageSettings.Value]
        }
        
        let queue: Queue
        let processingQueue: Queue
        let accountManager: AccountManager<TelegramAccountManagerTypes>
        let postbox: Postbox
        
        var settingsDisposable: Disposable?
        var processDisposable: Disposable?
        
        init(queue: Queue, accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox) {
            self.queue = queue
            self.processingQueue = Queue(name: "AutomaticCacheEviction-Processing", qos: .background)
            self.accountManager = accountManager
            self.postbox = postbox
            
            self.start()
        }
        
        deinit {
            self.settingsDisposable?.dispose()
            self.processDisposable?.dispose()
        }
        
        func start() {
            self.settingsDisposable?.dispose()
            self.processDisposable?.dispose()
            
            let cacheSettings = self.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
            |> map { sharedData -> CacheStorageSettings in
                let cacheSettings: CacheStorageSettings
                if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
                    cacheSettings = value
                } else {
                    cacheSettings = CacheStorageSettings.defaultSettings
                }
                
                return cacheSettings
            }
            
            let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
            let accountSpecificSettings = self.postbox.combinedView(keys: [viewKey])
            |> map { views -> AccountSpecificCacheStorageSettings in
                let cacheSettings: AccountSpecificCacheStorageSettings
                if let view = views.views[viewKey] as? PreferencesView, let value = view.values[PreferencesKeys.accountSpecificCacheStorageSettings]?.get(AccountSpecificCacheStorageSettings.self) {
                    cacheSettings = value
                } else {
                    cacheSettings = AccountSpecificCacheStorageSettings.defaultSettings
                }

                return cacheSettings
            }
            
            self.settingsDisposable = (combineLatest(queue: self.queue,
                cacheSettings,
                accountSpecificSettings
            )
            |> map { cacheSettings, accountSpecificSettings -> CombinedSettings in
                return CombinedSettings(
                    categoryStorageTimeout: cacheSettings.categoryStorageTimeout,
                    exceptions: accountSpecificSettings.peerStorageTimeoutExceptions
                )
            }
            |> distinctUntilChanged
            |> deliverOn(self.queue)).start(next: { [weak self] combinedSettings in
                self?.restart(settings: combinedSettings)
            })
        }
        
        private func restart(settings: CombinedSettings) {
            self.processDisposable?.dispose()
            
            let processingQueue = self.processingQueue
            let postbox = self.postbox
            let mediaBox = self.postbox.mediaBox
            
            let _ = processingQueue
            let _ = mediaBox
            
            self.processDisposable = (self.postbox.mediaBox.storageBox.allPeerIds()
            |> mapToSignal { peerIds -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> [PeerId: CacheStorageSettings.PeerStorageCategory] in
                    var channelCategoryMapping: [PeerId: CacheStorageSettings.PeerStorageCategory] = [:]
                    for peerId in peerIds {
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            var category: CacheStorageSettings.PeerStorageCategory = .channels
                            if let peer = transaction.getPeer(peerId) as? TelegramChannel, case .group = peer.info {
                                category = .groups
                            }
                            channelCategoryMapping[peerId] = category
                        }
                    }
                    
                    return channelCategoryMapping
                }
                |> mapToSignal { channelCategoryMapping -> Signal<Never, NoError> in
                    var signals: Signal<Never, NoError> = .complete()
                    
                    var matchingPeers = 0
                    
                    for peerId in peerIds {
                        let timeout: Int32
                        if let value = settings.exceptions.first(where: { $0.key == peerId }) {
                            timeout = value.value
                        } else {
                            switch peerId.namespace {
                            case Namespaces.Peer.CloudUser, Namespaces.Peer.SecretChat:
                                timeout = settings.categoryStorageTimeout[.privateChats] ?? Int32.max
                            case Namespaces.Peer.CloudGroup:
                                timeout = settings.categoryStorageTimeout[.groups] ?? Int32.max
                            default:
                                if let category = channelCategoryMapping[peerId], case .groups = category {
                                    timeout = settings.categoryStorageTimeout[.groups] ?? Int32.max
                                } else {
                                    timeout = settings.categoryStorageTimeout[.channels] ?? Int32.max
                                }
                            }
                        }
                        
                        if timeout == Int32.max {
                            continue
                        }
                        
                        matchingPeers += 1
                        
                        let minPeerTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) - timeout
                        //let minPeerTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                        
                        signals = signals |> then(mediaBox.storageBox.all(peerId: peerId)
                        |> mapToSignal { peerResourceIds -> Signal<Never, NoError> in
                            return Signal { subscriber in
                                var isCancelled = false
                                
                                processingQueue.justDispatch {
                                    var removeIds: [MediaResourceId] = []
                                    var removeRawIds: [Data] = []
                                    var localCounter = 0
                                    for resourceId in peerResourceIds {
                                        localCounter += 1
                                        if localCounter % 100 == 0 {
                                            if isCancelled {
                                                subscriber.putCompletion()
                                                return
                                            }
                                        }
                                        
                                        removeRawIds.append(resourceId)
                                        let id = MediaResourceId(String(data: resourceId, encoding: .utf8)!)
                                        let resourceTimestamp = mediaBox.resourceUsageWithInfo(id: id)
                                        if resourceTimestamp != 0 && resourceTimestamp < minPeerTimestamp {
                                            removeIds.append(id)
                                        }
                                    }
                                    
                                    if !removeIds.isEmpty {
                                        Logger.shared.log("AutomaticCacheEviction", "peer \(peerId): cleaning \(removeIds.count) resources")
                                        
                                        let _ = mediaBox.removeCachedResources(removeIds).start(completed: {
                                            mediaBox.storageBox.remove(ids: removeRawIds)
                                            
                                            subscriber.putCompletion()
                                        })
                                    } else {
                                        subscriber.putCompletion()
                                    }
                                }
                                
                                return ActionDisposable {
                                    isCancelled = true
                                }
                            }
                        })
                    }
                    
                    Logger.shared.log("AutomaticCacheEviction", "have \(matchingPeers) peers with data")
                    
                    return signals
                }
            }).start()
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(postbox: Postbox, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let queue = Queue(name: "AutomaticCacheEviction")
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, accountManager: accountManager, postbox: postbox)
        })
    }
}
