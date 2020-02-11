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
import PeerAvatarGalleryUI

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
    let groupsInCommon: GroupsInCommonContext?
    let linkedDiscussionPeer: Peer?
    let members: PeerInfoMembersData?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        status: PeerInfoStatusData?,
        notificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: GlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: GroupsInCommonContext?,
        linkedDiscussionPeer: Peer?,
        members: PeerInfoMembersData?
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
        self.members = members
    }
}

private enum PeerInfoScreenInputUserKind {
    case user
    case bot
    case support
}

private enum PeerInfoScreenInputData: Equatable {
    case none
    case user(userId: PeerId, secretChatId: PeerId?, kind: PeerInfoScreenInputUserKind)
    case channel
    case group(groupId: PeerId)
}

private func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<[PeerInfoPaneKey]?, NoError> {
    let tags: [(MessageTags, PeerInfoPaneKey)] = [
        (.photoOrVideo, .media),
        (.file, .files),
        (.music, .music),
        //(.voiceOrInstantVideo, .voice),
        (.webPage, .links)
    ]
    enum PaneState {
        case loading
        case empty
        case present
    }
    let loadedOnce = Atomic<Bool>(value: false)
    return combineLatest(queue: .mainQueue(), tags.map { tagAndKey -> Signal<(PeerInfoPaneKey, PaneState), NoError> in
        let (tag, key) = tagAndKey
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 20, clipHoles: false, fixedCombinedReadStates: nil, tagMask: tag)
        |> map { (view, _, _) -> (PeerInfoPaneKey, PaneState) in
            if view.entries.isEmpty {
                if view.isLoading {
                    return (key, .loading)
                } else {
                    return (key, .empty)
                }
            } else {
                return (key, .present)
            }
        }
    })
    |> map { keysAndStates -> [PeerInfoPaneKey]? in
        let loadedOnceValue = loadedOnce.with { $0 }
        var result: [PeerInfoPaneKey] = []
        var hasNonLoaded = false
        for (key, state) in keysAndStates {
            switch state {
            case .present:
                result.append(key)
            case .empty:
                break
            case .loading:
                hasNonLoaded = true
            }
        }
        if !hasNonLoaded || loadedOnceValue {
            if !loadedOnceValue {
                let _ = loadedOnce.swap(true)
            }
            return result
        } else {
            return nil
        }
    }
    |> distinctUntilChanged
}

struct PeerInfoStatusData: Equatable {
    var text: String
    var isActivity: Bool
}

enum PeerInfoMembersData: Equatable {
    case shortList(membersContext: PeerInfoMembersContext, members: [PeerInfoMember])
    case longList(PeerInfoMembersContext)
    
    var membersContext: PeerInfoMembersContext {
        switch self {
        case let .shortList(shortList):
            return shortList.membersContext
        case let .longList(membersContext):
            return membersContext
        }
    }
}

private func peerInfoScreenInputData(context: AccountContext, peerId: PeerId) -> Signal<PeerInfoScreenInputData, NoError> {
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
                return .group(groupId: channel.id)
            } else {
                return .channel
            }
        } else if let group = peer as? TelegramGroup {
            return .group(groupId: group.id)
        } else {
            return .none
        }
    }
    |> distinctUntilChanged
}

private func peerInfoProfilePhotos(context: AccountContext, peerId: PeerId) -> Signal<Any, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> map { view -> AvatarGalleryEntry? in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return nil
        }
        return initialAvatarGalleryEntries(peer: peer).first
    }
    |> distinctUntilChanged
    |> mapToSignal { firstEntry -> Signal<[AvatarGalleryEntry], NoError> in
        if let firstEntry = firstEntry {
            return context.account.postbox.loadedPeerWithId(peerId)
            |> mapToSignal { peer -> Signal<[AvatarGalleryEntry], NoError>in
                return fetchedAvatarGalleryEntries(account: context.account, peer: peer, firstEntry: firstEntry)
            }
        } else {
            return .single([])
        }
    }
    |> map { items -> Any in
        return items
    }
}

func peerInfoProfilePhotosWithCache(context: AccountContext, peerId: PeerId) -> Signal<[AvatarGalleryEntry], NoError> {
    return context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId))
    |> map { items -> [AvatarGalleryEntry] in
        return items as? [AvatarGalleryEntry] ?? []
    }
}

func keepPeerInfoScreenDataHot(context: AccountContext, peerId: PeerId) -> Signal<Never, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId)
    |> mapToSignal { inputData -> Signal<Never, NoError> in
        switch inputData {
        case .none:
            return .complete()
        case .user, .channel, .group:
            return combineLatest(
                context.peerChannelMemberCategoriesContextsManager.profileData(postbox: context.account.postbox, network: context.account.network, peerId: peerId, customData: peerInfoAvailableMediaPanes(context: context, peerId: peerId) |> ignoreValues),
                context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId)) |> ignoreValues
            )
            |> ignoreValues
        }
    }
}

func peerInfoScreenData(context: AccountContext, peerId: PeerId, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> Signal<PeerInfoScreenData, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId)
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
                linkedDiscussionPeer: nil,
                members: nil
            ))
        case let .user(peerId, secretChatId, kind):
            let groupsInCommon: GroupsInCommonContext?
            if case .user = kind {
                groupsInCommon = GroupsInCommonContext(account: context.account, peerId: peerId)
            } else {
                groupsInCommon = nil
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
                status
            )
            |> map { peerView, availablePanes, combinedView, status -> PeerInfoScreenData in
                var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
                if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                    if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                        globalNotificationSettings = settings
                    }
                }
                
                var availablePanes = availablePanes
                if availablePanes != nil, groupsInCommon != nil, let cachedData = peerView.cachedData as? CachedUserData {
                    if cachedData.commonGroupCount != 0 {
                        availablePanes?.append(.groupsInCommon)
                    }
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: groupsInCommon,
                    linkedDiscussionPeer: nil,
                    members: nil
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
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: nil,
                    linkedDiscussionPeer: discussionPeer,
                    members: nil
                )
            }
        case let .group(groupId):
            let status = context.account.viewTracker.peerView(groupId, updateData: false)
            |> map { peerView -> PeerInfoStatusData? in
                guard let channel = peerView.peers[groupId] as? TelegramChannel else {
                    return PeerInfoStatusData(text: strings.Group_Status, isActivity: false)
                }
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount != 0 {
                    return PeerInfoStatusData(text: strings.Conversation_StatusMembers(memberCount), isActivity: false)
                } else {
                    return PeerInfoStatusData(text: strings.Group_Status, isActivity: false)
                }
            }
            |> distinctUntilChanged
            
            let membersContext = PeerInfoMembersContext(context: context, peerId: groupId)
            
            let membersData: Signal<PeerInfoMembersData?, NoError> = membersContext.state
            |> map { state -> PeerInfoMembersData? in
                if state.members.count > 5 {
                    return .longList(membersContext)
                } else {
                    return .shortList(membersContext: membersContext, members: state.members)
                }
            }
            |> distinctUntilChanged
            
            let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
            var combinedKeys: [PostboxViewKey] = []
            combinedKeys.append(globalNotificationsKey)
            return combineLatest(queue: .mainQueue(),
                context.account.viewTracker.peerView(groupId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: groupId),
                context.account.postbox.combinedView(keys: combinedKeys),
                status,
                membersData
            )
            |> map { peerView, availablePanes, combinedView, status, membersData -> PeerInfoScreenData in
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
                
                var availablePanes = availablePanes
                if let membersData = membersData, case .longList = membersData {
                    if availablePanes != nil {
                        availablePanes?.insert(.members, at: 0)
                    } else {
                        availablePanes = [.members]
                    }
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[groupId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: nil,
                    linkedDiscussionPeer: discussionPeer,
                    members: membersData
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

struct PeerInfoMemberActions: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let restrict = PeerInfoMemberActions(rawValue: 1 << 0)
    static let promote = PeerInfoMemberActions(rawValue: 1 << 1)
}

func availableActionsForMemberOfPeer(accountPeerId: PeerId, peer: Peer, member: PeerInfoMember) -> PeerInfoMemberActions {
    var result: PeerInfoMemberActions = []
    
    if member.id != accountPeerId {
        if let channel = peer as? TelegramChannel {
            if channel.flags.contains(.isCreator) {
                result.insert(.restrict)
                result.insert(.promote)
            } else {
                switch member {
                case let .channelMember(channelMember):
                    switch channelMember.participant {
                    case .creator:
                        break
                    case let .member(member):
                        if let adminInfo = member.adminInfo {
                            if adminInfo.promotedBy == accountPeerId {
                                result.insert(.restrict)
                                if channel.hasPermission(.addAdmins) {
                                    result.insert(.promote)
                                }
                            }
                        } else {
                            if channel.hasPermission(.banMembers) {
                                result.insert(.restrict)
                            }
                        }
                    }
                case .legacyGroupMember:
                    break
                }
            }
        } else if let group = peer as? TelegramGroup {
            switch group.role {
            case .creator:
                result.insert(.restrict)
                result.insert(.promote)
            case .admin:
                switch member {
                case let .legacyGroupMember(legacyGroupMember):
                    if legacyGroupMember.invitedBy == accountPeerId {
                        result.insert(.restrict)
                        result.insert(.promote)
                    }
                case .channelMember:
                    break
                }
            case .member:
                switch member {
                case let .legacyGroupMember(legacyGroupMember):
                    if legacyGroupMember.invitedBy == accountPeerId {
                        result.insert(.restrict)
                    }
                case .channelMember:
                    break
                }
            }
        }
    }
    
    return result
}

func peerInfoHeaderButtons(peer: Peer?, cachedData: CachedPeerData?) -> [PeerInfoHeaderButtonKey] {
    var result: [PeerInfoHeaderButtonKey] = []
    if let user = peer as? TelegramUser {
        result.append(.message)
        var callsAvailable = false
        if !user.isDeleted, user.botInfo == nil, !user.flags.contains(.isSupport) {
            if let cachedUserData = cachedData as? CachedUserData {
                callsAvailable = cachedUserData.callsAvailable
            }
            callsAvailable = true
        }
        if callsAvailable {
            result.append(.call)
        }
        result.append(.mute)
        result.append(.more)
    } else if let channel = peer as? TelegramChannel {
        switch channel.info {
        case .broadcast:
            if let cachedData = cachedData as? CachedChannelData {
                if cachedData.linkedDiscussionPeerId != nil {
                    result.append(.discussion)
                }
            }
        case .group:
            if channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers) {
                result.append(.addMember)
            }
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
