import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public func updateGlobalNotificationSettingsInteractively(postbox: Postbox, _ f: @escaping (GlobalNotificationSettingsSet) -> GlobalNotificationSettingsSet) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
            if let current = current?.get(GlobalNotificationSettings.self) {
                return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: f(current.effective), remote: current.remote))
            } else {
                let settings = f(GlobalNotificationSettingsSet.defaultSettings)
                return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: settings, remote: settings))
            }
        })
        transaction.globalNotificationSettingsUpdated()
    }
}

public func resetPeerNotificationSettings(network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.account.resetNotifySettings())
        |> retryRequest
        |> mapToSignal { _ in return Signal<Void, NoError>.complete() }
}

private enum SynchronizeGlobalSettingsData: Equatable {
    case none
    case fetch
    case push(GlobalNotificationSettingsSet)
    
    static func ==(lhs: SynchronizeGlobalSettingsData, rhs: SynchronizeGlobalSettingsData) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case .fetch:
                if case .fetch = rhs {
                    return true
                } else {
                    return false
                }
            case let .push(settings):
                if case .push(settings) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

func managedGlobalNotificationSettings(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let data = postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    |> map { view -> SynchronizeGlobalSettingsData in
        if let preferences = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            if let settings = preferences.toBeSynchronized {
                return .push(settings)
            } else {
                return .none
            }
        } else {
            return .fetch
        }
    }
    let action = data
    |> distinctUntilChanged
    |> mapToSignal { data -> Signal<Void, NoError> in
        switch data {
            case .none:
                return .complete()
            case .fetch:
                return fetchedNotificationSettings(network: network)
                |> mapToSignal { settings -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            if let current = current?.get(GlobalNotificationSettings.self) {
                                return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: current.toBeSynchronized, remote: settings))
                            } else {
                                return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: nil, remote: settings))
                            }
                        })
                        transaction.globalNotificationSettingsUpdated()
                    }
                }
            case let .push(settings):
                return pushedNotificationSettings(network: network, settings: settings)
                    |> then(postbox.transaction { transaction -> Void in
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            if let current = current?.get(GlobalNotificationSettings.self), current.toBeSynchronized == settings {
                                return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: nil, remote: settings))
                            } else {
                                return current
                            }
                        })
                        transaction.globalNotificationSettingsUpdated()
                    })
        }
    }
    
    return action
}

private func fetchedNotificationSettings(network: Network) -> Signal<GlobalNotificationSettingsSet, NoError> {
    let chats = network.request(Api.functions.account.getNotifySettings(peer: Api.InputNotifyPeer.inputNotifyChats))
    let users = network.request(Api.functions.account.getNotifySettings(peer: Api.InputNotifyPeer.inputNotifyUsers))
    let channels = network.request(Api.functions.account.getNotifySettings(peer: Api.InputNotifyPeer.inputNotifyBroadcasts))
    let contactsJoinedMuted = network.request(Api.functions.account.getContactSignUpNotification())
    
    return combineLatest(chats, users, channels, contactsJoinedMuted)
    |> retryRequest
    |> map { chats, users, channels, contactsJoinedMuted in
        let chatsSettings: MessageNotificationSettings
        switch chats {
        case let .peerNotifySettings(_, showPreviews, _, muteUntil, iosSound, _, desktopSound):
            let sound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            #elseif os(macOS)
            sound = desktopSound
            #endif
            
            let enabled: Bool
            if muteUntil != nil && muteUntil != 0 {
                enabled = false
            } else {
                enabled = true
            }
            let displayPreviews: Bool
            if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                displayPreviews = false
            } else {
                displayPreviews = true
            }
            chatsSettings = MessageNotificationSettings(enabled: enabled, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault))
        }
        
        let userSettings: MessageNotificationSettings
        switch users {
        case let .peerNotifySettings(_, showPreviews, _, muteUntil, iosSound, _, desktopSound):
            let sound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            #elseif os(macOS)
            sound = desktopSound
            #endif
            
            let enabled: Bool
            if muteUntil != nil && muteUntil != 0 {
                enabled = false
            } else {
                enabled = true
            }
            let displayPreviews: Bool
            if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                displayPreviews = false
            } else {
                displayPreviews = true
            }
            userSettings = MessageNotificationSettings(enabled: enabled, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault))
        }
        
        let channelSettings: MessageNotificationSettings
        switch channels {
        case let .peerNotifySettings(_, showPreviews, _, muteUntil, iosSound, _, desktopSound):
            let sound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            #elseif os(macOS)
            sound = desktopSound
            #endif
            
            let enabled: Bool
            if muteUntil != nil && muteUntil != 0 {
                enabled = false
            } else {
                enabled = true
            }
            let displayPreviews: Bool
            if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                displayPreviews = false
            } else {
                displayPreviews = true
            }
            channelSettings = MessageNotificationSettings(enabled: enabled, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault))
        }
        
        return GlobalNotificationSettingsSet(privateChats: userSettings, groupChats: chatsSettings, channels: channelSettings, contactsJoined: contactsJoinedMuted == .boolFalse)
    }
}

private func apiInputPeerNotifySettings(_ settings: MessageNotificationSettings) -> Api.InputPeerNotifySettings {
    let muteUntil: Int32?
    if settings.enabled {
        muteUntil = 0
    } else {
        muteUntil = Int32.max
    }
    let sound: Api.NotificationSound? = settings.sound.apiSound
    var flags: Int32 = 0
    flags |= (1 << 0)
    if muteUntil != nil {
        flags |= (1 << 2)
    }
    if sound != nil {
        flags |= (1 << 3)
    }
    return .inputPeerNotifySettings(flags: flags, showPreviews: settings.displayPreviews ? .boolTrue : .boolFalse, silent: nil, muteUntil: muteUntil, sound: sound)
}

private func pushedNotificationSettings(network: Network, settings: GlobalNotificationSettingsSet) -> Signal<Void, NoError> {
    let pushedChats = network.request(Api.functions.account.updateNotifySettings(peer: Api.InputNotifyPeer.inputNotifyChats, settings: apiInputPeerNotifySettings(settings.groupChats)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    
    let pushedUsers = network.request(Api.functions.account.updateNotifySettings(peer: Api.InputNotifyPeer.inputNotifyUsers, settings: apiInputPeerNotifySettings(settings.privateChats)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    
    let pushedChannels = network.request(Api.functions.account.updateNotifySettings(peer: Api.InputNotifyPeer.inputNotifyBroadcasts, settings: apiInputPeerNotifySettings(settings.channels)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    
    let pushedContactsJoined = network.request(Api.functions.account.setContactSignUpNotification(silent: settings.contactsJoined ? .boolFalse : .boolTrue))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    
    return combineLatest(pushedChats, pushedUsers, pushedChannels, pushedContactsJoined)
    |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
}
