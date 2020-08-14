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
import TelegramUIPreferences
import TelegramNotices
import AccountUtils
import DeviceAccess

enum PeerInfoUpdatingAvatar {
    case none
    case image(TelegramMediaImageRepresentation)
}

final class PeerInfoState {
    let isEditing: Bool
    let selectedMessageIds: Set<MessageId>?
    let updatingAvatar: PeerInfoUpdatingAvatar?
    let updatingBio: String?
    let avatarUploadProgress: CGFloat?
    
    init(
        isEditing: Bool,
        selectedMessageIds: Set<MessageId>?,
        updatingAvatar: PeerInfoUpdatingAvatar?,
        updatingBio: String?,
        avatarUploadProgress: CGFloat?
    ) {
        self.isEditing = isEditing
        self.selectedMessageIds = selectedMessageIds
        self.updatingAvatar = updatingAvatar
        self.updatingBio = updatingBio
        self.avatarUploadProgress = avatarUploadProgress
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress
        )
    }
    
    func withUpdatingAvatar(_ updatingAvatar: PeerInfoUpdatingAvatar?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress
        )
    }
    
    func withUpdatingBio(_ updatingBio: String?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: updatingBio,
            avatarUploadProgress: self.avatarUploadProgress
        )
    }
    
    func withAvatarUploadProgress(_ avatarUploadProgress: CGFloat?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: avatarUploadProgress
        )
    }
}

final class TelegramGlobalSettings {
    let suggestPhoneNumberConfirmation: Bool
    let accountsAndPeers: [(Account, Peer, Int32)]
    let activeSessionsContext: ActiveSessionsContext?
    let webSessionsContext: WebSessionsContext?
    let otherSessionsCount: Int?
    let proxySettings: ProxySettings
    let notificationAuthorizationStatus: AccessType
    let notificationWarningSuppressed: Bool
    let notificationExceptions: NotificationExceptionsList?
    let inAppNotificationSettings: InAppNotificationSettings
    let privacySettings: AccountPrivacySettings?
    let unreadTrendingStickerPacks: Int
    let archivedStickerPacks: [ArchivedStickerPackItem]?
    let hasPassport: Bool
    let hasWatchApp: Bool
    let enableQRLogin: Bool
    
    init(
        suggestPhoneNumberConfirmation: Bool,
        accountsAndPeers: [(Account, Peer, Int32)],
        activeSessionsContext: ActiveSessionsContext?,
        webSessionsContext: WebSessionsContext?,
        otherSessionsCount: Int?,
        proxySettings: ProxySettings,
        notificationAuthorizationStatus: AccessType,
        notificationWarningSuppressed: Bool,
        notificationExceptions: NotificationExceptionsList?,
        inAppNotificationSettings: InAppNotificationSettings,
        privacySettings: AccountPrivacySettings?,
        unreadTrendingStickerPacks: Int,
        archivedStickerPacks: [ArchivedStickerPackItem]?,
        hasPassport: Bool,
        hasWatchApp: Bool,
        enableQRLogin: Bool
    ) {
        self.suggestPhoneNumberConfirmation = suggestPhoneNumberConfirmation
        self.accountsAndPeers = accountsAndPeers
        self.activeSessionsContext = activeSessionsContext
        self.webSessionsContext = webSessionsContext
        self.otherSessionsCount = otherSessionsCount
        self.proxySettings = proxySettings
        self.notificationAuthorizationStatus = notificationAuthorizationStatus
        self.notificationWarningSuppressed = notificationWarningSuppressed
        self.notificationExceptions = notificationExceptions
        self.inAppNotificationSettings = inAppNotificationSettings
        self.privacySettings = privacySettings
        self.unreadTrendingStickerPacks = unreadTrendingStickerPacks
        self.archivedStickerPacks = archivedStickerPacks
        self.hasPassport = hasPassport
        self.hasWatchApp = hasWatchApp
        self.enableQRLogin = enableQRLogin
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
    let encryptionKeyFingerprint: SecretChatKeyFingerprint?
    let globalSettings: TelegramGlobalSettings?
    
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
        members: PeerInfoMembersData?,
        encryptionKeyFingerprint: SecretChatKeyFingerprint?,
        globalSettings: TelegramGlobalSettings?
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
        self.encryptionKeyFingerprint = encryptionKeyFingerprint
        self.globalSettings = globalSettings
    }
}

private enum PeerInfoScreenInputUserKind {
    case user
    case bot
    case support
    case settings
}

private enum PeerInfoScreenInputData: Equatable {
    case none
    case settings
    case user(userId: PeerId, secretChatId: PeerId?, kind: PeerInfoScreenInputUserKind)
    case channel
    case group(groupId: PeerId)
}

private func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<[PeerInfoPaneKey]?, NoError> {
    let tags: [(MessageTags, PeerInfoPaneKey)] = [
        (.photoOrVideo, .media),
        (.file, .files),
        (.music, .music),
        (.voiceOrInstantVideo, .voice),
        (.webPage, .links),
        (.gif, .gifs)
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
        case let .shortList(membersContext, _):
            return membersContext
        case let .longList(membersContext):
            return membersContext
        }
    }
}

private func peerInfoScreenInputData(context: AccountContext, peerId: PeerId, isSettings: Bool) -> Signal<PeerInfoScreenInputData, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> map { view -> PeerInfoScreenInputData in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return .none
        }
        if let user = peer as? TelegramUser {
            if isSettings && user.id == context.account.peerId {
                return .settings
            } else {
                let kind: PeerInfoScreenInputUserKind
                if user.flags.contains(.isSupport) {
                    kind = .support
                } else if user.botInfo != nil {
                    kind = .bot
                } else {
                    kind = .user
                }
                return .user(userId: user.id, secretChatId: nil, kind: kind)
            }
        } else if let channel = peer as? TelegramChannel {
            if case .group = channel.info {
                return .group(groupId: channel.id)
            } else {
                return .channel
            }
        } else if let group = peer as? TelegramGroup {
            return .group(groupId: group.id)
        } else if let secretChat = peer as? TelegramSecretChat {
            return .user(userId: secretChat.regularPeerId, secretChatId: peer.id, kind: .user)
        } else {
            return .none
        }
    }
    |> distinctUntilChanged
}

private func peerInfoProfilePhotos(context: AccountContext, peerId: PeerId) -> Signal<Any, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> mapToSignal { view -> Signal<AvatarGalleryEntry?, NoError> in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return .single(nil)
        }
        return initialAvatarGalleryEntries(account: context.account, peer: peer)
        |> map { entries in
            return entries.first
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { firstEntry -> Signal<(Bool, [AvatarGalleryEntry]), NoError> in
        if let firstEntry = firstEntry {
            return context.account.postbox.loadedPeerWithId(peerId)
            |> mapToSignal { peer -> Signal<(Bool, [AvatarGalleryEntry]), NoError>in
                return fetchedAvatarGalleryEntries(account: context.account, peer: peer, firstEntry: firstEntry)
            }
        } else {
            return .single((true, []))
        }
    }
    |> map { items -> Any in
        return items
    }
}

func peerInfoProfilePhotosWithCache(context: AccountContext, peerId: PeerId) -> Signal<(Bool, [AvatarGalleryEntry]), NoError> {
    return context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId))
    |> map { items -> (Bool, [AvatarGalleryEntry]) in
        return items as? (Bool, [AvatarGalleryEntry]) ?? (true, [])
    }
}

func keepPeerInfoScreenDataHot(context: AccountContext, peerId: PeerId) -> Signal<Never, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: false)
    |> mapToSignal { inputData -> Signal<Never, NoError> in
        switch inputData {
        case .none, .settings:
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

func peerInfoScreenSettingsData(context: AccountContext, peerId: PeerId, accountsAndPeers: Signal<[(Account, Peer, Int32)], NoError>, activeSessionsContextAndCount: Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError>, notificationExceptions: Signal<NotificationExceptionsList?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, hasPassport: Signal<Bool, NoError>) -> Signal<PeerInfoScreenData, NoError> {
    let preferences = context.sharedContext.accountManager.sharedData(keys: [
        SharedDataKeys.proxySettings,
        ApplicationSpecificSharedDataKeys.inAppNotificationSettings,
        ApplicationSpecificSharedDataKeys.experimentalUISettings
    ])
    
    let notificationsAuthorizationStatus = Promise<AccessType>(.allowed)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsAuthorizationStatus.set(
            .single(.allowed)
                |> then(DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications)
            )
        )
    }
    
    let notificationsWarningSuppressed = Promise<Bool>(true)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsWarningSuppressed.set(
            .single(true)
                |> then(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
                    |> map { noticeView -> Bool in
                        let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                        if let timestamp = timestamp, timestamp > 0 {
                            return true
                        } else {
                            return false
                        }
                    }
            )
        )
    }
    
    return combineLatest(
        context.account.viewTracker.peerView(peerId, updateData: true),
        accountsAndPeers,
        activeSessionsContextAndCount,
        privacySettings,
        preferences,
        combineLatest(notificationExceptions, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get()),
        combineLatest(context.account.viewTracker.featuredStickerPacks(), archivedStickerPacks),
        hasPassport,
        (context.watchManager?.watchAppInstalled ?? .single(false)),
        context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        )
        |> map { peerView, accountsAndPeers, accountSessions, privacySettings, sharedPreferences, notifications, stickerPacks, hasPassport, hasWatchApp, accountPreferences -> PeerInfoScreenData in
            let (notificationExceptions, notificationsAuthorizationStatus, notificationsWarningSuppressed) = notifications
            let (featuredStickerPacks, archivedStickerPacks) = stickerPacks
            
            let proxySettings: ProxySettings = sharedPreferences.entries[SharedDataKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
            let inAppNotificationSettings: InAppNotificationSettings = sharedPreferences.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
            let experimentalUISettings: ExperimentalUISettings = sharedPreferences.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings] as? ExperimentalUISettings ?? ExperimentalUISettings.defaultSettings
            
            let unreadTrendingStickerPacks = featuredStickerPacks.reduce(0, { count, item -> Int in
                return item.unread ? count + 1 : count
            })
            
            var enableQRLogin = false
            if let appConfiguration = accountPreferences.values[PreferencesKeys.appConfiguration] as? AppConfiguration, let data = appConfiguration.data, let enableQR = data["qr_login_camera"] as? Bool, enableQR {
                enableQRLogin = true
            }
            
            let globalSettings = TelegramGlobalSettings(suggestPhoneNumberConfirmation: false, accountsAndPeers: accountsAndPeers, activeSessionsContext: accountSessions?.0, webSessionsContext: accountSessions?.2, otherSessionsCount: accountSessions?.1, proxySettings: proxySettings, notificationAuthorizationStatus: notificationsAuthorizationStatus, notificationWarningSuppressed: notificationsWarningSuppressed, notificationExceptions: notificationExceptions, inAppNotificationSettings: inAppNotificationSettings, privacySettings: privacySettings, unreadTrendingStickerPacks: unreadTrendingStickerPacks, archivedStickerPacks: archivedStickerPacks, hasPassport: hasPassport, hasWatchApp: hasWatchApp, enableQRLogin: enableQRLogin)
            
            return PeerInfoScreenData(
                peer: peerView.peers[peerId],
                cachedData: peerView.cachedData,
                status: nil,
                notificationSettings: nil,
                globalNotificationSettings: nil,
                isContact: false,
                availablePanes: [],
                groupsInCommon: nil,
                linkedDiscussionPeer: nil,
                members: nil,
                encryptionKeyFingerprint: nil,
                globalSettings: globalSettings
            )
    }
}

func peerInfoScreenData(context: AccountContext, peerId: PeerId, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, isSettings: Bool, ignoreGroupInCommon: PeerId?) -> Signal<PeerInfoScreenData, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: isSettings)
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        switch inputData {
        case .none, .settings:
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
                members: nil,
                encryptionKeyFingerprint: nil,
                globalSettings: nil
            ))
        case let .user(userPeerId, secretChatId, kind):
            let groupsInCommon: GroupsInCommonContext?
            if case .user = kind {
                groupsInCommon = GroupsInCommonContext(account: context.account, peerId: userPeerId)
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
                let disposable = (context.account.viewTracker.peerView(userPeerId, updateData: false)
                |> map { view -> StatusInputData in
                    guard let user = view.peers[userPeerId] as? TelegramUser else {
                        return .none
                    }
                    if user.id == context.account.peerId {
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
                    guard let presence = view.peerPresences[userPeerId] as? TelegramUserPresence else {
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
                combinedKeys.append(.peerChatState(peerId: secretChatId))
            }
            return combineLatest(
                context.account.viewTracker.peerView(userPeerId, updateData: true),
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
                
                var encryptionKeyFingerprint: SecretChatKeyFingerprint?
                if let secretChatId = secretChatId, let peerChatStateView = combinedView.views[.peerChatState(peerId: secretChatId)] as? PeerChatStateView {
                    if let peerChatState = peerChatStateView.chatState as? SecretChatKeyState {
                        encryptionKeyFingerprint = peerChatState.keyFingerprint
                    }
                }
                
                var availablePanes = availablePanes
                if availablePanes != nil, groupsInCommon != nil, let cachedData = peerView.cachedData as? CachedUserData {
                    if cachedData.commonGroupCount != 0 {
                        availablePanes?.append(.groupsInCommon)
                    }
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[userPeerId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: groupsInCommon,
                    linkedDiscussionPeer: nil,
                    members: nil,
                    encryptionKeyFingerprint: encryptionKeyFingerprint,
                    globalSettings: nil
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
                    members: nil,
                    encryptionKeyFingerprint: nil,
                    globalSettings: nil
                )
            }
        case let .group(groupId):
            var onlineMemberCount: Signal<Int32?, NoError> = .single(nil)
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                onlineMemberCount = context.account.viewTracker.peerView(groupId, updateData: false)
                |> map { view -> Bool? in
                    if let cachedData = view.cachedData as? CachedChannelData, let peer = peerViewMainPeer(view) as? TelegramChannel {
                        if case .broadcast = peer.info {
                            return nil
                        } else if let memberCount = cachedData.participantsSummary.memberCount, memberCount > 50 {
                            return true
                        } else {
                            return false
                        }
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                |> mapToSignal { isLarge -> Signal<Int32?, NoError> in
                    if let isLarge = isLarge {
                        if isLarge {
                            return context.peerChannelMemberCategoriesContextsManager.recentOnline(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                            |> map(Optional.init)
                        } else {
                            return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                            |> map(Optional.init)
                        }
                    } else {
                        return .single(nil)
                    }
                }
            }
            
            let status = combineLatest(queue: .mainQueue(),
                context.account.viewTracker.peerView(groupId, updateData: false),
                onlineMemberCount
            )
            |> map { peerView, onlineMemberCount -> PeerInfoStatusData? in
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    if let onlineMemberCount = onlineMemberCount, onlineMemberCount > 1 {
                        var string = ""
                        
                        string.append("\(strings.Conversation_StatusMembers(Int32(memberCount))), ")
                        string.append(strings.Conversation_StatusOnline(Int32(onlineMemberCount)))
                        return PeerInfoStatusData(text: string, isActivity: false)
                    } else if memberCount > 0 {
                        return PeerInfoStatusData(text: strings.Conversation_StatusMembers(Int32(memberCount)), isActivity: false)
                    }
                } else if let group = peerView.peers[groupId] as? TelegramGroup, let cachedGroupData = peerView.cachedData as? CachedGroupData {
                    var onlineCount = 0
                    if let participants = cachedGroupData.participants {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        for participant in participants.participants {
                            if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                                let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                                switch relativeStatus {
                                case .online:
                                    onlineCount += 1
                                default:
                                    break
                                }
                            }
                        }
                    }
                    if onlineCount > 1 {
                        var string = ""
                        
                        string.append("\(strings.Conversation_StatusMembers(Int32(group.participantCount))), ")
                        string.append(strings.Conversation_StatusOnline(Int32(onlineCount)))
                        return PeerInfoStatusData(text: string, isActivity: false)
                    } else {
                        return PeerInfoStatusData(text: strings.Conversation_StatusMembers(Int32(group.participantCount)), isActivity: false)
                    }
                }
                
                return PeerInfoStatusData(text: strings.Group_Status, isActivity: false)
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
                    members: membersData,
                    encryptionKeyFingerprint: nil,
                    globalSettings: nil
                )
            }
        }
    }
}

func canEditPeerInfo(context: AccountContext, peer: Peer?) -> Bool {
    if context.account.peerId == peer?.id {
        return true
    }
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
    static let logout = PeerInfoMemberActions(rawValue: 1 << 2)
}

func availableActionsForMemberOfPeer(accountPeerId: PeerId, peer: Peer?, member: PeerInfoMember) -> PeerInfoMemberActions {
    var result: PeerInfoMemberActions = []
    
    if peer == nil {
        result.insert(.logout)
    } else if member.id != accountPeerId {
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
                case .account:
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
                case .account:
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
                case .account:
                    break
                }
            }
        }
    }
    
    return result
}

func peerInfoHeaderButtons(peer: Peer?, cachedData: CachedPeerData?, isOpenedFromChat: Bool, videoCallsEnabled: Bool) -> [PeerInfoHeaderButtonKey] {
    var result: [PeerInfoHeaderButtonKey] = []
    if let user = peer as? TelegramUser {
        if !isOpenedFromChat {
            result.append(.message)
        }
        var callsAvailable = false
        var videoCallsAvailable = false
        if !user.isDeleted, user.botInfo == nil, !user.flags.contains(.isSupport) {
            if let cachedUserData = cachedData as? CachedUserData {
                callsAvailable = cachedUserData.voiceCallsAvailable
                videoCallsAvailable = cachedUserData.videoCallsAvailable
            }
            callsAvailable = true
        }
        if callsAvailable {
            result.append(.call)
            if videoCallsEnabled && videoCallsAvailable {
                result.append(.videoCall)
            }
        }
        result.append(.mute)
        if isOpenedFromChat {
            result.append(.search)
        }
        result.append(.more)
    } else if let channel = peer as? TelegramChannel {
        var displayLeave = !channel.flags.contains(.isCreator)
        var canViewStats = false
        if let cachedChannelData = cachedData as? CachedChannelData {
            canViewStats = cachedChannelData.flags.contains(.canViewStats)
        }
        switch channel.info {
        case .broadcast:
            if !channel.flags.contains(.isCreator) {
                displayLeave = true
            }
        case .group:
            displayLeave = false
            if channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers) {
                result.append(.addMember)
            }
        }
        switch channel.participationStatus {
        case .member:
            break
        default:
            displayLeave = false
        }
        if canViewStats {
            displayLeave = false
        }
        result.append(.mute)
        result.append(.search)
        if displayLeave {
            result.append(.leave)
        }
        var displayMore = true
        if displayLeave && !channel.flags.contains(.isCreator) {
            if let adminRights = channel.adminRights, !adminRights.isEmpty {
                displayMore = false
            }
        }
        if displayMore {
            result.append(.more)
        }
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
        result.append(.search)
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
