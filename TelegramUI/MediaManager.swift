import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore

private struct WrappedAudioPlaylistItemId: Hashable, Equatable {
    let playlistId: AudioPlaylistId
    let itemId: AudioPlaylistItemId
    
    static func ==(lhs: WrappedAudioPlaylistItemId, rhs: WrappedAudioPlaylistItemId) -> Bool {
        return lhs.itemId.isEqual(to: rhs.itemId) && lhs.playlistId.isEqual(to: rhs.playlistId)
    }
    
    var hashValue: Int {
        return self.itemId.hashValue
    }
}

private final class ManagedAudioPlaylistPlayerStatusesContext {
    private var subscribers: [WrappedAudioPlaylistItemId: Bag<(AudioPlaylistState?) -> Void>] = [:]
    
    func addSubscriber(id: WrappedAudioPlaylistItemId, _ f: @escaping (AudioPlaylistState?) -> Void) -> Int {
        let bag: Bag<(AudioPlaylistState?) -> Void>
        if let currentBag = self.subscribers[id] {
            bag = currentBag
        } else {
            bag = Bag()
            self.subscribers[id] = bag
        }
        return bag.add(f)
    }
    
    func removeSubscriber(id: WrappedAudioPlaylistItemId, index: Int) {
        if let bag = subscribers[id] {
            bag.remove(index)
            if bag.isEmpty {
                self.subscribers.removeValue(forKey: id)
            }
        }
    }
    
    func subscribersForId(_ id: WrappedAudioPlaylistItemId) -> [(AudioPlaylistState) -> Void]? {
        return self.subscribers[id]?.copyItems()
    }
}

private struct WrappedManagedMediaId: Hashable {
    let id: ManagedMediaId
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    static func ==(lhs: WrappedManagedMediaId, rhs: WrappedManagedMediaId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
}

final class ManagedVideoContext {
    let mediaPlayer: MediaPlayer
    let playerNode: MediaPlayerNode
    
    init(mediaPlayer: MediaPlayer, playerNode: MediaPlayerNode) {
        self.mediaPlayer = mediaPlayer
        self.playerNode = playerNode
    }
}

private final class ActiveManagedVideoContext {
    let context: ManagedVideoContext
    let contextSubscribers = Bag<(ManagedVideoContext?) -> Void>()
    
    init(context: ManagedVideoContext) {
        self.context = context
    }
}

final class MediaManager {
    private let queue = Queue.mainQueue()
    
    let audioSession = ManagedAudioSession()
    
    private let playlistPlayer = Atomic<ManagedAudioPlaylistPlayer?>(value: nil)
    private let playlistPlayerStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>(nil)
    var playlistPlayerStateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.playlistPlayerStateAndStatusValue.get()
    }
    private var playlistPlayerStateValueDisposable: Disposable?
    private let playlistPlayerStatusesContext = Atomic(value: ManagedAudioPlaylistPlayerStatusesContext())
    
    private var managedVideoContexts: [WrappedManagedMediaId: ActiveManagedVideoContext] = [:]
    
    init() {
    }
    
    deinit {
        self.playlistPlayerStateValueDisposable?.dispose()
    }
    
    func videoContext(account: Account, id: ManagedMediaId, resource: MediaResource) -> Signal<ManagedVideoContext?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let wrappedId = WrappedManagedMediaId(id: id)
                let activeContext: ActiveManagedVideoContext
                if let currentActiveContext = self.managedVideoContexts[wrappedId] {
                    activeContext = currentActiveContext
                } else {
                    let mediaPlayer = MediaPlayer(postbox: account.postbox, resource: resource)
                    let playerNode = MediaPlayerNode()
                    mediaPlayer.attachPlayerNode(playerNode)
                    activeContext = ActiveManagedVideoContext(context: ManagedVideoContext(mediaPlayer: mediaPlayer, playerNode: playerNode))
                    self.managedVideoContexts[wrappedId] = activeContext
                }
                
                let index = activeContext.contextSubscribers.add({ context in
                    subscriber.putNext(context)
                })
                
                for (subscriberIndex, subscriberSink) in activeContext.contextSubscribers.copyItemsWithIndices() {
                    if subscriberIndex == index {
                        subscriberSink(activeContext.context)
                    } else {
                        subscriberSink(nil)
                    }
                }
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let activeContext = self.managedVideoContexts[wrappedId] {
                            activeContext.contextSubscribers.remove(index)
                            
                            if activeContext.contextSubscribers.isEmpty {
                                self.managedVideoContexts.removeValue(forKey: wrappedId)
                            } else {
                                let lastSubscriber = activeContext.contextSubscribers.copyItemsWithIndices().last!.1
                                lastSubscriber(activeContext.context)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    func audioRecorder() -> Signal<ManagedAudioRecorder?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let audioRecorder = ManagedAudioRecorder(mediaManager: self)
                subscriber.putNext(audioRecorder)
                
                disposable.set(ActionDisposable {
                })
            }
            
            return disposable
        }
    }
    
    func setPlaylistPlayer(_ player: ManagedAudioPlaylistPlayer?) {
        var disposePlayer: ManagedAudioPlaylistPlayer?
        var updatedPlayer = false
        self.playlistPlayer.modify { currentPlayer in
            if currentPlayer !== player {
                disposePlayer = currentPlayer
                updatedPlayer = true
                return player
            } else {
                return currentPlayer
            }
        }
        
        if let disposePlayer = disposePlayer {
        }
        
        if updatedPlayer {
            if let player = player {
                self.playlistPlayerStateAndStatusValue.set(player.stateAndStatus)
            } else {
                self.playlistPlayerStateAndStatusValue.set(.single(nil))
            }
        }
    }
    
    func playlistPlayerControl(_ control: AudioPlaylistControl) {
        var player: ManagedAudioPlaylistPlayer?
        self.playlistPlayer.with { currentPlayer -> Void in
            player = currentPlayer
        }
        
        if let player = player {
            player.control(control)
        }
    }
    
    func filteredPlaylistPlayerStateAndStatus(playlistId: AudioPlaylistId, itemId: AudioPlaylistItemId) -> Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.playlistPlayerStateAndStatusValue.get()
            |> map { state -> AudioPlaylistStateAndStatus? in
                if let state = state, let item = state.state.item, state.state.playlistId.isEqual(to: playlistId), item.id.isEqual(to: itemId) {
                    return state
                }
                return nil
            }
        /*return Signal { subscriber in
            let id = WrappedAudioPlaylistItemId(playlistId: playlistId, itemId: itemId)
            let index = self.playlistPlayerStatusesContext.with { context -> Int in
                context.addSubscriber(id: id, { state in
                    subscriber.putNext(state)
                })
            }
            
            
            
            return ActionDisposable { [weak self] in
                if let strongSelf = self {
                    strongSelf.playlistPlayerStatusesContext.with { context -> Void in
                        context.removeSubscriber(id: id, index: index)
                    }
                }
            }
        }*/
    }
}
