import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func updateGlobalNotificationSettingsInteractively(postbox: Postbox, _ f: @escaping (GlobalNotificationSettingsSet) -> GlobalNotificationSettingsSet) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
            if let current = current as? GlobalNotificationSettings {
                return GlobalNotificationSettings(toBeSynchronized: f(current.effective), remote: current.remote)
            } else {
                let settings = f(GlobalNotificationSettingsSet.defaultSettings)
                return GlobalNotificationSettings(toBeSynchronized: settings, remote: settings)
            }
        })
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
            if let preferences = view.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
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
                        return postbox.modify { modifier -> Void in
                            modifier.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                                if let current = current as? GlobalNotificationSettings {
                                    return GlobalNotificationSettings(toBeSynchronized: current.toBeSynchronized, remote: settings)
                                } else {
                                    return GlobalNotificationSettings(toBeSynchronized: nil, remote: settings)
                                }
                            })
                        }
                    }
                case let .push(settings):
                    return pushedNotificationSettings(network: network, settings: settings)
                        |> then(postbox.modify { modifier -> Void in
                            modifier.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                                if let current = current as? GlobalNotificationSettings, current.toBeSynchronized == settings {
                                    return GlobalNotificationSettings(toBeSynchronized: nil, remote: settings)
                                } else {
                                    return current
                                }
                            })
                        })
            }
        }
    
    return action
}

private func fetchedNotificationSettings(network: Network) -> Signal<GlobalNotificationSettingsSet, NoError> {
    let chats = network.request(Api.functions.account.getNotifySettings(peer: Api.InputNotifyPeer.inputNotifyChats))
    let users = network.request(Api.functions.account.getNotifySettings(peer: Api.InputNotifyPeer.inputNotifyUsers))
    
    return combineLatest(chats, users)
        |> retryRequest
        |> map { chats, users in
            let chatsSettings: MessageNotificationSettings
            switch chats {
                case .peerNotifySettingsEmpty:
                    chatsSettings = MessageNotificationSettings.defaultSettings
                case let .peerNotifySettings(flags, muteUntil, sound):
                    chatsSettings = MessageNotificationSettings(enabled: muteUntil == 0, displayPreviews: (flags & (1 << 0)) != 0, sound: PeerMessageSound(apiSound: sound))
            }
            
            let userSettings: MessageNotificationSettings
            switch users {
                case .peerNotifySettingsEmpty:
                    userSettings = MessageNotificationSettings.defaultSettings
                case let .peerNotifySettings(flags, muteUntil, sound):
                    userSettings = MessageNotificationSettings(enabled: muteUntil == 0, displayPreviews: (flags & (1 << 0)) != 0, sound: PeerMessageSound(apiSound: sound))
            }
            return GlobalNotificationSettingsSet(privateChats: userSettings, groupChats: chatsSettings)
    }
}

private func pushedNotificationSettings(network: Network, settings: GlobalNotificationSettingsSet) -> Signal<Void, NoError> {
    let pushedChats = network.request(Api.functions.account.updateNotifySettings(peer: Api.InputNotifyPeer.inputNotifyChats, settings: Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: settings.groupChats.displayPreviews ? (1 << 0) : 0, muteUntil: settings.groupChats.enabled ? 0 : Int32.max, sound: settings.groupChats.sound.apiSound)))
    let pushedUsers = network.request(Api.functions.account.updateNotifySettings(peer: Api.InputNotifyPeer.inputNotifyUsers, settings: Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: settings.privateChats.displayPreviews ? (1 << 0) : 0, muteUntil: settings.privateChats.enabled ? 0 : Int32.max, sound: settings.privateChats.sound.apiSound)))
    return combineLatest(pushedChats, pushedUsers)
        |> retryRequest
        |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
}
