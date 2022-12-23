import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedPendingPeerNotificationSettingsHelper {
    var operationDisposables: [PeerId: (PeerNotificationSettings, Disposable)] = [:]
    
    func update(entries: [PeerId: PeerNotificationSettings]) -> (disposeOperations: [Disposable], beginOperations: [(PeerId, PeerNotificationSettings, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerId, PeerNotificationSettings, MetaDisposable)] = []
        
        var validIds = Set<PeerId>()
        for (peerId, settings) in entries {
            validIds.insert(peerId)
            
            if let (currentSettings, currentDisposable) = self.operationDisposables[peerId] {
                if !currentSettings.isEqual(to: settings) {
                    disposeOperations.append(currentDisposable)
                    
                    let disposable = MetaDisposable()
                    beginOperations.append((peerId, settings, disposable))
                    self.operationDisposables[peerId] = (settings, disposable)
                }
            } else {
                let disposable = MetaDisposable()
                beginOperations.append((peerId, settings, disposable))
                self.operationDisposables[peerId] = (settings, disposable)
            }
        }
        
        var removeIds: [PeerId] = []
        for (id, settingsAndDisposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeIds.append(id)
                disposeOperations.append(settingsAndDisposable.1)
            }
        }
        
        for id in removeIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values).map { $0.1 }
        self.operationDisposables.removeAll()
        return disposables
    }
}

func managedPendingPeerNotificationSettings(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedPendingPeerNotificationSettingsHelper>(value: ManagedPendingPeerNotificationSettingsHelper())
        
        let disposable = postbox.combinedView(keys: [.pendingPeerNotificationSettings]).start(next: { view in
            var entries: [PeerId: PeerNotificationSettings] = [:]
            if let v = view.views[.pendingPeerNotificationSettings] as? PendingPeerNotificationSettingsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerId, PeerNotificationSettings, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (peerId, settings, disposable) in beginOperations {
                let signal = pushPeerNotificationSettings(postbox: postbox, network: network, peerId: peerId, threadId: nil, settings: settings)
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

func pushPeerNotificationSettings(postbox: Postbox, network: Network, peerId: PeerId, threadId: Int64?, settings: PeerNotificationSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            if let threadId = threadId {
                if let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    let settings = data.notificationSettings
                    
                    let showPreviews: Api.Bool?
                    switch settings.displayPreviews {
                    case .default:
                        showPreviews = nil
                    case .show:
                        showPreviews = .boolTrue
                    case .hide:
                        showPreviews = .boolFalse
                    }
                    let muteUntil: Int32?
                    switch settings.muteState {
                    case let .muted(until):
                        muteUntil = until
                    case .unmuted:
                        muteUntil = 0
                    case .default:
                        muteUntil = nil
                    }
                    let sound: Api.NotificationSound? = settings.messageSound.apiSound
                    var flags: Int32 = 0
                    if showPreviews != nil {
                        flags |= (1 << 0)
                    }
                    if muteUntil != nil {
                        flags |= (1 << 2)
                    }
                    if sound != nil {
                        flags |= (1 << 3)
                    }
                    let inputSettings = Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: flags, showPreviews: showPreviews, silent: nil, muteUntil: muteUntil, sound: sound)
                    return network.request(Api.functions.account.updateNotifySettings(peer: .inputNotifyForumTopic(peer: inputPeer, topMsgId: Int32(clamping: threadId)), settings: inputSettings))
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .single(.boolFalse)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.transaction { transaction -> Void in
                        }
                    }
                } else {
                    return .complete()
                }
            } else {
                if let notificationPeer = transaction.getPeer(notificationPeerId), let inputPeer = apiInputPeer(notificationPeer), let settings = settings as? TelegramPeerNotificationSettings {
                    let showPreviews: Api.Bool?
                    switch settings.displayPreviews {
                    case .default:
                        showPreviews = nil
                    case .show:
                        showPreviews = .boolTrue
                    case .hide:
                        showPreviews = .boolFalse
                    }
                    let muteUntil: Int32?
                    switch settings.muteState {
                    case let .muted(until):
                        muteUntil = until
                    case .unmuted:
                        muteUntil = 0
                    case .default:
                        muteUntil = nil
                    }
                    let sound: Api.NotificationSound? = settings.messageSound.apiSound
                    var flags: Int32 = 0
                    if showPreviews != nil {
                        flags |= (1 << 0)
                    }
                    if muteUntil != nil {
                        flags |= (1 << 2)
                    }
                    if sound != nil {
                        flags |= (1 << 3)
                    }
                    let inputSettings = Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: flags, showPreviews: showPreviews, silent: nil, muteUntil: muteUntil, sound: sound)
                    return network.request(Api.functions.account.updateNotifySettings(peer: .inputNotifyPeer(peer: inputPeer), settings: inputSettings))
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .single(.boolFalse)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.transaction { transaction -> Void in
                            transaction.updateCurrentPeerNotificationSettings([notificationPeerId: settings])
                            if let pending = transaction.getPendingPeerNotificationSettings(peerId), pending.isEqual(to: settings) {
                                transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: nil)
                            }
                        }
                    }
                } else {
                    if let pending = transaction.getPendingPeerNotificationSettings(peerId), pending.isEqual(to: settings) {
                        transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: nil)
                    }
                    return .complete()
                }
            }
        } else {
            if let pending = transaction.getPendingPeerNotificationSettings(peerId), pending.isEqual(to: settings) {
                transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: nil)
            }
            return .complete()
        }
    } |> switchToLatest
}
