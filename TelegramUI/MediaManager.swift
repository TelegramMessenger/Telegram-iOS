import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore

private final class ManagedAudioPlaylistPlayerStatusesContext {
    let subscribers
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
    private let playlistPlayerStateValue = Promise<AudioPlaylistState?>(nil)
    var playlistPlayerState: Signal<AudioPlaylistState?, NoError> {
        return self.playlistPlayerStateValue.get()
    }
    private var playlistPlayerStateValueDisposable: Disposable?
    
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
                self.playlistPlayerStateValue.set(player.state)
            } else {
                self.playlistPlayerStateValue.set(.single(nil))
            }
        }
    }
    
    func playlistPlayerState(playlistId: AudioPlaylistId, itemId: AudioPlaylistItemId) -> Signal<AudioPlaylistState?, NoError> {
        return Signal { subscriber in
            
            
            return ActionDisposable {
                
            }
        }
    }
}
