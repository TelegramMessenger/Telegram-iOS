import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

func _internal_togglePeerMuted(account: Account, peerId: PeerId, threadId: Int64?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        guard let peer = transaction.getPeer(peerId) else {
            return
        }
        
        var notificationPeerId = peerId
        if let associatedPeerId = peer.associatedPeerId {
            notificationPeerId = associatedPeerId
        }
        
        if let threadId = threadId {
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                var updatedSettings: TelegramPeerNotificationSettings
                switch data.notificationSettings.muteState {
                case .default:
                    updatedSettings = data.notificationSettings.withUpdatedMuteState(.muted(until: Int32.max))
                case .unmuted:
                    updatedSettings = data.notificationSettings.withUpdatedMuteState(.muted(until: Int32.max))
                case .muted:
                    updatedSettings = data.notificationSettings.withUpdatedMuteState(.unmuted)
                }
                data.notificationSettings = updatedSettings
                
                if let entry = StoredMessageHistoryThreadInfo(data) {
                    transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                    
                    //TODO:loc
                    let _ = pushPeerNotificationSettings(postbox: account.postbox, network: account.network, peerId: peerId, threadId: threadId, settings: TelegramPeerNotificationSettings.defaultSettings).start()
                }
            }
        } else {
            let currentSettings = transaction.getPeerNotificationSettings(id: notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let updatedSettings: TelegramPeerNotificationSettings
            switch previousSettings.muteState {
            case .default:
                let globalNotificationSettings = transaction.getGlobalNotificationSettings()
                if resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettings, peer: peer, peerSettings: previousSettings) {
                    updatedSettings = previousSettings.withUpdatedMuteState(.unmuted)
                } else {
                    updatedSettings = previousSettings.withUpdatedMuteState(.muted(until: Int32.max))
                }
            case .unmuted:
                updatedSettings = previousSettings.withUpdatedMuteState(.muted(until: Int32.max))
            case .muted:
                updatedSettings = previousSettings.withUpdatedMuteState(.unmuted)
            }
            transaction.updatePendingPeerNotificationSettings(peerId: notificationPeerId, settings: updatedSettings)
        }
    }
}

func _internal_updatePeerMuteSetting(account: Account, peerId: PeerId, threadId: Int64?, muteInterval: Int32?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        _internal_updatePeerMuteSetting(account: account, transaction: transaction, peerId: peerId, threadId: threadId, muteInterval: muteInterval)
    }
}

func _internal_updatePeerMuteSetting(account: Account, transaction: Transaction, peerId: PeerId, threadId: Int64?, muteInterval: Int32?) {
    if let peer = transaction.getPeer(peerId) {
        if let threadId = threadId {
            let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(id: peerId) as? TelegramPeerNotificationSettings) ?? .defaultSettings
            
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                let previousSettings: TelegramPeerNotificationSettings = data.notificationSettings
                
                var muteState: PeerMuteState
                if let muteInterval = muteInterval {
                    if muteInterval == 0 {
                        muteState = .unmuted
                    } else {
                        let absoluteUntil: Int32
                        if muteInterval == Int32.max {
                            absoluteUntil = Int32.max
                        } else {
                            absoluteUntil = Int32(Date().timeIntervalSince1970) + muteInterval
                        }
                        muteState = .muted(until: absoluteUntil)
                    }
                } else {
                    muteState = .unmuted
                }
                if peerSettings.muteState == muteState {
                    muteState = .default
                }
                
                data.notificationSettings = previousSettings.withUpdatedMuteState(muteState)
                
                if let entry = StoredMessageHistoryThreadInfo(data) {
                    transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                }
                
                //TODO:loc
                let _ = pushPeerNotificationSettings(postbox: account.postbox, network: account.network, peerId: peerId, threadId: threadId, settings: TelegramPeerNotificationSettings.defaultSettings).start()
            }
        } else {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = transaction.getPeerNotificationSettings(id: notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let muteState: PeerMuteState
            if let muteInterval = muteInterval {
                if muteInterval == 0 {
                    muteState = .unmuted
                } else {
                    let absoluteUntil: Int32
                    if muteInterval == Int32.max {
                        absoluteUntil = Int32.max
                    } else {
                        absoluteUntil = Int32(Date().timeIntervalSince1970) + muteInterval
                    }
                    muteState = .muted(until: absoluteUntil)
                }
            } else {
                muteState = .default
            }
            
            let updatedSettings = previousSettings.withUpdatedMuteState(muteState)
            transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}

func _internal_updatePeerDisplayPreviewsSetting(account: Account, peerId: PeerId, threadId: Int64?, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        _internal_updatePeerDisplayPreviewsSetting(account: account, transaction: transaction, peerId: peerId, threadId: threadId, displayPreviews: displayPreviews)
    }
}

func _internal_updatePeerDisplayPreviewsSetting(account: Account, transaction: Transaction, peerId: PeerId, threadId: Int64?, displayPreviews: PeerNotificationDisplayPreviews) {
    if let peer = transaction.getPeer(peerId) {
        if let threadId = threadId {
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                let previousSettings: TelegramPeerNotificationSettings = data.notificationSettings
                
                data.notificationSettings = previousSettings.withUpdatedDisplayPreviews(displayPreviews)
                
                if let entry = StoredMessageHistoryThreadInfo(data) {
                    transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                }
                
                //TODO:loc
                let _ = pushPeerNotificationSettings(postbox: account.postbox, network: account.network, peerId: peerId, threadId: threadId, settings: TelegramPeerNotificationSettings.defaultSettings).start()
            }
        } else {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = transaction.getPeerNotificationSettings(id: notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let updatedSettings = previousSettings.withUpdatedDisplayPreviews(displayPreviews)
            transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}

func _internal_updatePeerNotificationSoundInteractive(account: Account, peerId: PeerId, threadId: Int64?, sound: PeerMessageSound) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        _internal_updatePeerNotificationSoundInteractive(account: account, transaction: transaction, peerId: peerId, threadId: threadId, sound: sound)
    }
}

func _internal_updatePeerNotificationSoundInteractive(account: Account, transaction: Transaction, peerId: PeerId, threadId: Int64?, sound: PeerMessageSound) {
    if let peer = transaction.getPeer(peerId) {
        if let threadId = threadId {
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                let previousSettings: TelegramPeerNotificationSettings = data.notificationSettings
                
                data.notificationSettings = previousSettings.withUpdatedMessageSound(sound)
                
                if let entry = StoredMessageHistoryThreadInfo(data) {
                    transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                }
                
                //TODO:loc
                let _ = pushPeerNotificationSettings(postbox: account.postbox, network: account.network, peerId: peerId, threadId: threadId, settings: TelegramPeerNotificationSettings.defaultSettings).start()
            }
        } else {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = transaction.getPeerNotificationSettings(id: notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let updatedSettings = previousSettings.withUpdatedMessageSound(sound)
            transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}
