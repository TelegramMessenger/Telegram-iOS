import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import CoreLocation

public final class LiveLocationManager {
    private let queue = Queue.mainQueue()
    
    private let postbox: Postbox
    private let network: Network
    private let stateManager: AccountStateManager
    private let locationManager: DeviceLocationManager
    
    let summaryManager: LiveLocationSummaryManager
    
    private var requiredLocationTypeDisposable: Disposable?
    private let hasActiveMessagesToBroadcast = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    
    public var isPolling: Signal<Bool, NoError> {
        return self.pollingOnce.get()
    }
    private let pollingOnce = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var pollingOnceValue = false {
        didSet {
            self.pollingOnce.set(self.pollingOnceValue)
        }
    }
    
    private let deviceLocationDisposable = MetaDisposable()
    private var messagesDisposable: Disposable?
    
    private var broadcastToMessageIds = Set<MessageId>()
    private var stopMessageIds = Set<MessageId>()
    
    private let editMessageDisposables = DisposableDict<MessageId>()
    
    init(postbox: Postbox, network: Network, accountPeerId: PeerId, viewTracker: AccountViewTracker, stateManager: AccountStateManager, locationManager: DeviceLocationManager, inForeground: Signal<Bool, NoError>) {
        self.postbox = postbox
        self.network = network
        self.stateManager = stateManager
        self.locationManager = locationManager
        
        self.summaryManager = LiveLocationSummaryManager(queue: self.queue, postbox: postbox, accountPeerId: accountPeerId, viewTracker: viewTracker)
        
        let viewKey: PostboxViewKey = .localMessageTag(.OutgoingLiveLocation)
        self.messagesDisposable = (postbox.combinedView(keys: [viewKey])
        |> deliverOn(self.queue)).start(next: { [weak self] view in
            if let strongSelf = self {
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                var broadcastToMessageIds = Set<MessageId>()
                var stopMessageIds = Set<MessageId>()
                
                if let view = view.views[viewKey] as? LocalMessageTagsView {
                    for message in view.messages.values {
                        if !message.flags.contains(.Incoming) {
                            if message.flags.intersection([.Failed, .Unsent]).isEmpty {
                                var activeLiveBroadcastingTimeout: Int32?
                                for media in message.media {
                                    if let telegramMap = media as? TelegramMediaMap {
                                        if let liveBroadcastingTimeout = telegramMap.liveBroadcastingTimeout {
                                            if message.timestamp + liveBroadcastingTimeout > timestamp {
                                                activeLiveBroadcastingTimeout = liveBroadcastingTimeout
                                            }
                                        }
                                    }
                                }
                                if let _ = activeLiveBroadcastingTimeout {
                                    broadcastToMessageIds.insert(message.id)
                                } else {
                                    stopMessageIds.insert(message.id)
                                }
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                }
                
                strongSelf.update(broadcastToMessageIds: broadcastToMessageIds, stopMessageIds: stopMessageIds)
            }
        })
        
        self.requiredLocationTypeDisposable = (combineLatest(
            inForeground |> deliverOn(self.queue),
            self.hasActiveMessagesToBroadcast.get() |> deliverOn(self.queue),
            self.pollingOnce.get() |> deliverOn(self.queue)
        )
        |> map { inForeground, hasActiveMessagesToBroadcast, pollingOnce -> Bool in
            if (inForeground || pollingOnce) && hasActiveMessagesToBroadcast {
                return true
            } else {
                return false
            }
        }
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    let queue = strongSelf.queue
                    strongSelf.deviceLocationDisposable.set(strongSelf.locationManager.push(mode: .precise, updated: { coordinate in
                        queue.async {
                            self?.updateDeviceCoordinate(coordinate)
                        }
                    }))
                } else {
                    strongSelf.deviceLocationDisposable.set(nil)
                }
            }
        })
    }
    
    deinit {
        self.requiredLocationTypeDisposable?.dispose()
        self.deviceLocationDisposable.dispose()
        self.messagesDisposable?.dispose()
        self.editMessageDisposables.dispose()
    }
    
    private func update(broadcastToMessageIds: Set<MessageId>, stopMessageIds: Set<MessageId>) {
        assert(self.queue.isCurrent())
        
        if self.broadcastToMessageIds == broadcastToMessageIds && self.stopMessageIds == stopMessageIds {
            return
        }
        
        if self.broadcastToMessageIds != broadcastToMessageIds {
            self.summaryManager.update(messageIds: broadcastToMessageIds)
        }
        
        let wasEmpty = self.broadcastToMessageIds.isEmpty
        self.broadcastToMessageIds = broadcastToMessageIds
        
        let removedFromActions = self.broadcastToMessageIds.union(self.stopMessageIds).subtracting(broadcastToMessageIds.union(stopMessageIds))
        for id in removedFromActions {
            self.editMessageDisposables.set(nil, forKey: id)
        }
        
        if !broadcastToMessageIds.isEmpty {
            if wasEmpty {
               self.hasActiveMessagesToBroadcast.set(true)
            }
        } else if !wasEmpty {
            self.hasActiveMessagesToBroadcast.set(false)
        }
        
        let addedStopped = stopMessageIds.subtracting(self.stopMessageIds)
        self.stopMessageIds = stopMessageIds
        for id in addedStopped {
            self.editMessageDisposables.set((requestEditLiveLocation(postbox: self.postbox, network: self.network, stateManager: self.stateManager, messageId: id, coordinate: nil)
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.editMessageDisposables.set(nil, forKey: id)
                    }
                }), forKey: id)
        }
    }
    
    private func updateDeviceCoordinate(_ coordinate: CLLocationCoordinate2D) {
        assert(self.queue.isCurrent())
        
        let ids = self.broadcastToMessageIds
        let remainingIds = Atomic<Set<MessageId>>(value: ids)
        for id in ids {
            self.editMessageDisposables.set((requestEditLiveLocation(postbox: self.postbox, network: self.network, stateManager: self.stateManager, messageId: id, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude))
            |> deliverOn(self.queue)).start(completed: { [weak self] in
                if let strongSelf = self {
                    strongSelf.editMessageDisposables.set(nil, forKey: id)
                    
                    let result = remainingIds.modify { current in
                        var current = current
                        current.remove(id)
                        return current
                    }
                    if result.isEmpty {
                        strongSelf.pollingOnceValue = false
                    }
                }
            }), forKey: id)
        }
    }
    
    func cancelLiveLocation(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        let ids = self.broadcastToMessageIds.filter({ $0.peerId == peerId })
        if !ids.isEmpty {
            let _ = self.postbox.modify({ modifier -> Void in
                for id in ids {
                    modifier.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                        }
                        var updatedMedia = currentMessage.media
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        for i in 0 ..< updatedMedia.count {
                            if let media = updatedMedia[i] as? TelegramMediaMap, let _ = media.liveBroadcastingTimeout {
                                updatedMedia[i] = TelegramMediaMap(latitude: media.latitude, longitude: media.longitude, geoPlace: media.geoPlace, venue: media.venue, liveBroadcastingTimeout: max(0, timestamp - currentMessage.timestamp - 1))
                            }
                        }
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: updatedMedia))
                    })
                }
            }).start()
        }
    }
    
    public func pollOnce() {
        if !self.broadcastToMessageIds.isEmpty {
            self.pollingOnceValue = true
        }
    }
    
    func internalMessageForPeerId(_ peerId: PeerId) -> MessageId? {
        for id in self.broadcastToMessageIds {
            if id.peerId == peerId {
                return id
            }
        }
        return nil
    }
}
