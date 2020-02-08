import Foundation
import UIKit
import Postbox
import SyncCore
import TelegramCore
import SwiftSignalKit
import AccountContext
import PeerPresenceStatusManager
import TelegramStringFormatting
import TelegramPresentationData

final class PeerInfoState {
    let isEditing: Bool
    let isSearching: Bool
    let selectedMessageIds: Set<MessageId>?
    
    init(
        isEditing: Bool,
        isSearching: Bool,
        selectedMessageIds: Set<MessageId>?
    ) {
        self.isEditing = isEditing
        self.isSearching = isSearching
        self.selectedMessageIds = selectedMessageIds
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            isSearching: self.isSearching,
            selectedMessageIds: self.selectedMessageIds
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            isSearching: self.isSearching,
            selectedMessageIds: selectedMessageIds
        )
    }
}

final class PeerInfoScreenData {
    let peer: Peer?
    let cachedData: CachedPeerData?
    let status: PeerInfoStatusData?
    let notificationSettings: TelegramPeerNotificationSettings?
    let globalNotificationSettings: GlobalNotificationSettings?
    let isContact: Bool
    let availablePanes: [PeerInfoPaneKey]
    let groupsInCommon: [Peer]?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        status: PeerInfoStatusData?,
        notificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: GlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: [Peer]?
    ) {
        self.peer = peer
        self.cachedData = cachedData
        self.status = status
        self.notificationSettings = notificationSettings
        self.globalNotificationSettings = globalNotificationSettings
        self.isContact = isContact
        self.availablePanes = availablePanes
        self.groupsInCommon = groupsInCommon
    }
}

enum PeerInfoScreenInputData: Equatable {
    case none
    case user(userId: PeerId, secretChatId: PeerId?, isBot: Bool)
}

func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<[PeerInfoPaneKey], NoError> {
    let tags: [(MessageTags, PeerInfoPaneKey)] = [
        (.photoOrVideo, .media),
        (.file, .files),
        (.music, .music),
        (.voiceOrInstantVideo, .voice),
        (.webPage, .links)
    ]
    return combineLatest(tags.map { tagAndKey -> Signal<PeerInfoPaneKey?, NoError> in
        let (tag, key) = tagAndKey
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 20, clipHoles: false, fixedCombinedReadStates: nil, tagMask: tag)
        |> map { (view, _, _) -> PeerInfoPaneKey? in
            if view.entries.isEmpty {
                return nil
            } else {
                return key
            }
        }
    })
    |> map { keys -> [PeerInfoPaneKey] in
        return keys.compactMap { $0 }
    }
    |> distinctUntilChanged
    /*return context.account.postbox.combinedView(keys: tags.map { (tag, _) -> PostboxViewKey in
        return .historyTagInfo(peerId: peerId, tag: tag)
    })
    |> map { view -> [PeerInfoPaneKey] in
        return tags.compactMap { (tag, key) -> PeerInfoPaneKey? in
            if let info = view.views[.historyTagInfo(peerId: peerId, tag: tag)] as? HistoryTagInfoView, !info.isEmpty {
                return key
            } else {
                return nil
            }
        }
    }
    |> distinctUntilChanged*/
}

struct PeerInfoStatusData: Equatable {
    var text: String
    var isActivity: Bool
}

func peerInfoScreenData(context: AccountContext, peerId: PeerId, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> Signal<PeerInfoScreenData, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> map { view -> PeerInfoScreenInputData in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return .none
        }
        if let user = peer as? TelegramUser {
            return .user(userId: user.id, secretChatId: nil, isBot: user.botInfo != nil)
        } else {
            preconditionFailure()
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        switch inputData {
        case .none:
            return .single(PeerInfoScreenData(
                peer: nil,
                cachedData: nil,
                status: nil,
                notificationSettings: nil,
                globalNotificationSettings: nil,
                isContact: false,
                availablePanes: [],
                groupsInCommon: nil
            ))
        case let .user(peerId, secretChatId, isBot):
            let groupsInCommonSignal: Signal<[Peer]?, NoError>
            if isBot {
                groupsInCommonSignal = .single([])
            } else {
                groupsInCommonSignal = .single(nil)
                |> then(
                    groupsInCommon(account: context.account, peerId: peerId)
                    |> map(Optional.init)
                )
            }
            enum StatusInputData: Equatable {
                case none
                case presence(TelegramUserPresence)
                case bot
            }
            let status = Signal<PeerInfoStatusData?, NoError> { subscriber in
                class Manager {
                    var currentValue: TelegramUserPresence? = nil
                    var updateManager: QueueLocalObject<PeerPresenceStatusManager>? = nil
                }
                let manager = Atomic<Manager>(value: Manager())
                let notify: () -> Void = {
                    let data = manager.with { manager -> PeerInfoStatusData? in
                        if let presence = manager.currentValue {
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (text, isActivity) = stringAndActivityForUserPresence(strings: strings, dateTimeFormat: dateTimeFormat, presence: presence, relativeTo: Int32(timestamp), expanded: true)
                            return PeerInfoStatusData(text: text, isActivity: isActivity)
                        } else {
                            return nil
                        }
                    }
                    subscriber.putNext(data)
                }
                let disposable = (context.account.viewTracker.peerView(peerId, updateData: false)
                |> map { view -> StatusInputData in
                    guard let user = view.peers[peerId] as? TelegramUser else {
                        return .none
                    }
                    if user.isDeleted {
                        return .none
                    }
                    if user.botInfo != nil {
                        return .bot
                    }
                    if user.flags.contains(.isSupport) {
                        return .none
                    }
                    guard let presence = view.peerPresences[peerId] as? TelegramUserPresence else {
                        return .none
                    }
                    return .presence(presence)
                }
                |> distinctUntilChanged).start(next: { inputData in
                    switch inputData {
                    case .bot:
                        subscriber.putNext(PeerInfoStatusData(text: strings.Bot_GenericBotStatus, isActivity: false))
                    default:
                        var presence: TelegramUserPresence?
                        if case let .presence(value) = inputData {
                            presence = value
                        }
                        let _ = manager.with { manager -> Void in
                            manager.currentValue = presence
                            if let presence = presence {
                                let updateManager: QueueLocalObject<PeerPresenceStatusManager>
                                if let current = manager.updateManager {
                                    updateManager = current
                                } else {
                                    updateManager = QueueLocalObject<PeerPresenceStatusManager>(queue: .mainQueue(), generate: {
                                        return PeerPresenceStatusManager(update: {
                                            notify()
                                        })
                                    })
                                }
                                updateManager.with { updateManager in
                                    updateManager.reset(presence: presence)
                                }
                            } else if let _ = manager.updateManager {
                                manager.updateManager = nil
                            }
                        }
                        notify()
                    }
                })
                return disposable
            }
            |> distinctUntilChanged
            let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
            var combinedKeys: [PostboxViewKey] = []
            combinedKeys.append(globalNotificationsKey)
            if let secretChatId = secretChatId {
                combinedKeys.append(.peerChatState(peerId: peerId))
            }
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId),
                context.account.postbox.combinedView(keys: combinedKeys),
                status,
                groupsInCommonSignal
            )
            |> map { peerView, availablePanes, combinedView, status, groupsInCommon -> PeerInfoScreenData in
                var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
                if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                    if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                        globalNotificationSettings = settings
                    }
                }
                
                var availablePanes = availablePanes
                if let groupsInCommon = groupsInCommon, !groupsInCommon.isEmpty {
                    availablePanes.append(.groupsInCommon)
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes,
                    groupsInCommon: groupsInCommon
                )
            }
        }
    }
}

func peerInfoHeaderButtons(peer: Peer?, cachedData: CachedPeerData?) -> [PeerInfoHeaderButtonKey] {
    var result: [PeerInfoHeaderButtonKey] = []
    if let user = peer as? TelegramUser {
        result.append(.message)
        var callsAvailable = false
        if !user.isDeleted, user.botInfo == nil, !user.flags.contains(.isSupport), let cachedUserData = cachedData as? CachedUserData {
            callsAvailable = cachedUserData.callsAvailable
        }
        if callsAvailable {
            result.append(.call)
        }
        result.append(.mute)
        
        if !user.isDeleted, user.botInfo == nil && !user.flags.contains(.isSupport) {
            result.append(.more)
        }
    }
    return result
}

func peerInfoCanEdit(peer: Peer?, cachedData: CachedPeerData?) -> Bool {
    if let user = peer as? TelegramUser {
        if user.isDeleted {
            return false
        }
        return true
    }
    return false
}
