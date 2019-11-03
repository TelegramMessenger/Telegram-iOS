import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

struct PeerInputActivityRecord: Equatable {
    let activity: PeerInputActivity
    let updateId: Int32
}

private final class ManagedLocalTypingActivitiesContext {
    private var disposables: [PeerId: (PeerInputActivityRecord, MetaDisposable)] = [:]
    
    func update(activities: [PeerId: [PeerId: PeerInputActivityRecord]]) -> (start: [(PeerId, PeerInputActivityRecord?, MetaDisposable)], dispose: [MetaDisposable]) {
        var start: [(PeerId, PeerInputActivityRecord?, MetaDisposable)] = []
        var dispose: [MetaDisposable] = []
        
        var validPeerIds = Set<PeerId>()
        for (peerId, record) in activities {
            if let activity = record.values.first {
                validPeerIds.insert(peerId)
                
                let currentRecord = self.disposables[peerId]
                if currentRecord == nil || currentRecord!.0 != activity {
                    if let disposable = currentRecord?.1 {
                        dispose.append(disposable)
                    }
                    
                    let disposable = MetaDisposable()
                    start.append((peerId, activity, disposable))
                    
                    self.disposables[peerId] = (activity, disposable)
                }
            }
        }
        
        var removePeerIds: [PeerId] = []
        for key in self.disposables.keys {
            if !validPeerIds.contains(key) {
                removePeerIds.append(key)
            }
        }
        
        for peerId in removePeerIds {
            dispose.append(self.disposables[peerId]!.1)
            self.disposables.removeValue(forKey: peerId)
        }
        
        return (start, dispose)
    }
    
    func dispose() {
        for (_, record) in self.disposables {
            record.1.dispose()
        }
        self.disposables.removeAll()
    }
}

func managedLocalTypingActivities(activities: Signal<[PeerId: [PeerId: PeerInputActivityRecord]], NoError>, postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let context = Atomic(value: ManagedLocalTypingActivitiesContext())
        let disposable = activities.start(next: { activities in
            let (start, dispose) = context.with { context in
                return context.update(activities: activities)
            }
            
            for disposable in dispose {
                disposable.dispose()
            }
            
            for (peerId, activity, disposable) in start {
                disposable.set(requestActivity(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, activity: activity?.activity).start())
            }
        })
        return ActionDisposable {
            disposable.dispose()
            
            context.with { context -> Void in
                context.dispose()
            }
        }
    }
}

private func actionFromActivity(_ activity: PeerInputActivity?) -> Api.SendMessageAction {
    if let activity = activity {
        switch activity {
            case .typingText:
                return .sendMessageTypingAction
            case .recordingVoice:
                return .sendMessageRecordAudioAction
            case .playingGame:
                return .sendMessageGamePlayAction
            case let .uploadingFile(progress):
                return .sendMessageUploadDocumentAction(progress: progress)
            case let .uploadingPhoto(progress):
                return .sendMessageUploadPhotoAction(progress: progress)
            case let .uploadingVideo(progress):
                return .sendMessageUploadVideoAction(progress: progress)
            case .recordingInstantVideo:
                return .sendMessageRecordRoundAction
            case let .uploadingInstantVideo(progress):
                return .sendMessageUploadRoundAction(progress: progress)
        }
    } else {
        return .sendMessageCancelAction
    }
}

private func requestActivity(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) {
            if peerId == accountPeerId {
                return .complete()
            }
            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                return .complete()
            }
            
            if let inputPeer = apiInputPeer(peer) {
                return network.request(Api.functions.messages.setTyping(peer: inputPeer, action: actionFromActivity(activity)))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else if let peer = peer as? TelegramSecretChat, activity == .typingText {
                return network.request(Api.functions.messages.setEncryptedTyping(peer: .inputEncryptedChat(chatId: peer.id.id, accessHash: peer.accessHash), typing: .boolTrue))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
