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

enum PeerInfoUpdatingAvatar {
    case none
    case image(TelegramMediaImageRepresentation)
}

final class PeerInfoState {
    let isEditing: Bool
    let selectedMessageIds: Set<MessageId>?
    let updatingAvatar: PeerInfoUpdatingAvatar?
    
    init(
        isEditing: Bool,
        selectedMessageIds: Set<MessageId>?,
        updatingAvatar: PeerInfoUpdatingAvatar?
    ) {
        self.isEditing = isEditing
        self.selectedMessageIds = selectedMessageIds
        self.updatingAvatar = updatingAvatar
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: selectedMessageIds,
            updatingAvatar: self.updatingAvatar
        )
    }
    
    func withUpdatingAvatar(_ updatingAvatar: PeerInfoUpdatingAvatar?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: updatingAvatar
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
    let linkedDiscussionPeer: Peer?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        status: PeerInfoStatusData?,
        notificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: GlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: [Peer]?,
        linkedDiscussionPeer: Peer?
    ) {
        self.peer = peer
        self.cachedData = cachedData
        self.status = status
        self.notificationSettings = notificationSettings
        self.globalNotificationSettings = globalNotificationSettings
        self.isContact = isContact
        self.availablePanes = availablePanes
        self.groupsInCommon = groupsInCommon
        self.linkedDiscussionPeer = linkedDiscussionPeer
    }
}

enum PeerInfoScreenInputUserKind {
    case user
    case bot
    case support
}

enum PeerInfoScreenInputData: Equatable {
    case none
    case user(userId: PeerId, secretChatId: PeerId?, kind: PeerInfoScreenInputUserKind)
    case channel
    case group(isSupergroup: Bool)
}

func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<[PeerInfoPaneKey], NoError> {
    let tags: [(MessageTags, PeerInfoPaneKey)] = [
        (.photoOrVideo, .media),
        (.file, .files),
        (.music, .music),
        //(.voiceOrInstantVideo, .voice),
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
            let kind: PeerInfoScreenInputUserKind
            if user.flags.contains(.isSupport) {
                kind = .support
            } else if user.botInfo != nil {
                kind = .bot
            } else {
                kind = .user
            }
            return .user(userId: user.id, secretChatId: nil, kind: kind)
        } else if let channel = peer as? TelegramChannel {
            if case .group = channel.info {
                return .group(isSupergroup: true)
            } else {
                return .channel
            }
        } else if let _ = peer as? TelegramGroup {
            return .group(isSupergroup: false)
        } else {
            return .none
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
                groupsInCommon: nil,
                linkedDiscussionPeer: nil
            ))
        case let .user(peerId, secretChatId, kind):
            let groupsInCommonSignal: Signal<[Peer]?, NoError>
            switch kind {
            case .user:
                groupsInCommonSignal = .single(nil)
                |> then(
                    groupsInCommon(account: context.account, peerId: peerId)
                    |> map(Optional.init)
                )
            default:
                groupsInCommonSignal = .single([])
            }
            enum StatusInputData: Equatable {
                case none
                case presence(TelegramUserPresence)
                case bot
                case support
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
                    if user.flags.contains(.isSupport) {
                        return .support
                    }
                    if user.botInfo != nil {
                        return .bot
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
                    case .support:
                        subscriber.putNext(PeerInfoStatusData(text: strings.Bot_GenericSupportStatus, isActivity: false))
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
                    groupsInCommon: groupsInCommon,
                    linkedDiscussionPeer: nil
                )
            }
        case .channel:
            let status = context.account.viewTracker.peerView(peerId, updateData: false)
            |> map { peerView -> PeerInfoStatusData? in
                guard let channel = peerView.peers[peerId] as? TelegramChannel else {
                    return PeerInfoStatusData(text: strings.Channel_Status, isActivity: false)
                }
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount != 0 {
                    return PeerInfoStatusData(text: strings.Conversation_StatusSubscribers(memberCount), isActivity: false)
                } else {
                    return PeerInfoStatusData(text: strings.Channel_Status, isActivity: false)
                }
            }
            |> distinctUntilChanged
            
            let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
            var combinedKeys: [PostboxViewKey] = []
            combinedKeys.append(globalNotificationsKey)
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId),
                context.account.postbox.combinedView(keys: combinedKeys),
                status
            )
            |> map { peerView, availablePanes, combinedView, status -> PeerInfoScreenData in
                var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
                if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                    if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                        globalNotificationSettings = settings
                    }
                }
                
                var discussionPeer: Peer?
                if let linkedDiscussionPeerId = (peerView.cachedData as? CachedChannelData)?.linkedDiscussionPeerId, let peer = peerView.peers[linkedDiscussionPeerId] {
                    discussionPeer = peer
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes,
                    groupsInCommon: [],
                    linkedDiscussionPeer: discussionPeer
                )
            }
        case .group:
            let status = context.account.viewTracker.peerView(peerId, updateData: false)
            |> map { peerView -> PeerInfoStatusData? in
                guard let channel = peerView.peers[peerId] as? TelegramChannel else {
                    return PeerInfoStatusData(text: strings.Channel_Status, isActivity: false)
                }
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount != 0 {
                    return PeerInfoStatusData(text: strings.Conversation_StatusMembers(memberCount), isActivity: false)
                } else {
                    return PeerInfoStatusData(text: strings.Group_Status, isActivity: false)
                }
            }
            |> distinctUntilChanged
            
            let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
            var combinedKeys: [PostboxViewKey] = []
            combinedKeys.append(globalNotificationsKey)
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId),
                context.account.postbox.combinedView(keys: combinedKeys),
                status
            )
            |> map { peerView, availablePanes, combinedView, status -> PeerInfoScreenData in
                var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
                if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                    if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                        globalNotificationSettings = settings
                    }
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes,
                    groupsInCommon: [],
                    linkedDiscussionPeer: nil
                )
            }
        }
    }
}

func canEditPeerInfo(peer: Peer?) -> Bool {
    if let channel = peer as? TelegramChannel {
        if channel.hasPermission(.changeInfo) {
            return true
        }
    } else if let group = peer as? TelegramGroup {
        switch group.role {
        case .admin, .creator:
            return true
        case .member:
            break
        }
        if !group.hasBannedPermission(.banChangeInfo) {
            return true
        }
    }
    return false
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
    } else if let channel = peer as? TelegramChannel {
        var canEditGroupInfo = false
        var canEditMembers = false
        var canAddMembers = false
        var isPublic = false
        var isCreator = false
        
        isPublic = channel.username != nil
        if !isPublic, let cachedChannelData = cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
            isPublic = true
        }
        
        isCreator = channel.flags.contains(.isCreator)
        if channel.hasPermission(.changeInfo) {
            canEditGroupInfo = true
        }
        if channel.hasPermission(.banMembers) {
            canEditMembers = true
        }
        if channel.hasPermission(.inviteMembers) {
            canAddMembers = true
        }
        
        result.append(.mute)
        result.append(.more)
    } else if let group = peer as? TelegramGroup {
        var canEditGroupInfo = false
        var canEditMembers = false
        var canAddMembers = false
        var isPublic = false
        var isCreator = false
        
        if case .creator = group.role {
            isCreator = true
        }
        switch group.role {
            case .admin, .creator:
                canEditGroupInfo = true
                canEditMembers = true
                canAddMembers = true
            case .member:
                break
        }
        if !group.hasBannedPermission(.banChangeInfo) {
            canEditGroupInfo = true
        }
        if !group.hasBannedPermission(.banAddMembers) {
            canAddMembers = true
        }
        
        if canAddMembers {
            result.append(.addMember)
        }
        
        result.append(.mute)
        result.append(.more)
    }
    return result
}

func peerInfoCanEdit(peer: Peer?, cachedData: CachedPeerData?) -> Bool {
    if let user = peer as? TelegramUser {
        if user.isDeleted {
            return false
        }
        return true
    } else if peer is TelegramChannel || peer is TelegramGroup {
        return true
    }
    return false
}
