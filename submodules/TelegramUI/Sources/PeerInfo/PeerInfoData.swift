import Foundation
import UIKit
import Postbox
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
    let highlightedButton: PeerInfoHeaderButtonKey?
    
    init(
        isEditing: Bool,
        selectedMessageIds: Set<MessageId>?,
        updatingAvatar: PeerInfoUpdatingAvatar?,
        updatingBio: String?,
        avatarUploadProgress: CGFloat?,
        highlightedButton: PeerInfoHeaderButtonKey?
    ) {
        self.isEditing = isEditing
        self.selectedMessageIds = selectedMessageIds
        self.updatingAvatar = updatingAvatar
        self.updatingBio = updatingBio
        self.avatarUploadProgress = avatarUploadProgress
        self.highlightedButton = highlightedButton
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton
        )
    }
    
    func withUpdatingAvatar(_ updatingAvatar: PeerInfoUpdatingAvatar?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton
        )
    }
    
    func withUpdatingBio(_ updatingBio: String?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton
        )
    }
    
    func withAvatarUploadProgress(_ avatarUploadProgress: CGFloat?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: avatarUploadProgress,
            highlightedButton: self.highlightedButton
        )
    }
    
    func withHighlightedButton(_ highlightedButton: PeerInfoHeaderButtonKey?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: highlightedButton
        )
    }
}

final class TelegramGlobalSettings {
    let suggestPhoneNumberConfirmation: Bool
    let suggestPasswordConfirmation: Bool
    let accountsAndPeers: [(AccountContext, EnginePeer, Int32)]
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
    let userLimits: EngineConfiguration.UserLimits
    let hasPassport: Bool
    let hasWatchApp: Bool
    let enableQRLogin: Bool
    
    init(
        suggestPhoneNumberConfirmation: Bool,
        suggestPasswordConfirmation: Bool,
        accountsAndPeers: [(AccountContext, EnginePeer, Int32)],
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
        userLimits: EngineConfiguration.UserLimits,
        hasPassport: Bool,
        hasWatchApp: Bool,
        enableQRLogin: Bool
    ) {
        self.suggestPhoneNumberConfirmation = suggestPhoneNumberConfirmation
        self.suggestPasswordConfirmation = suggestPasswordConfirmation
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
        self.userLimits = userLimits
        self.hasPassport = hasPassport
        self.hasWatchApp = hasWatchApp
        self.enableQRLogin = enableQRLogin
    }
}

final class PeerInfoScreenData {
    let peer: Peer?
    let chatPeer: Peer?
    let cachedData: CachedPeerData?
    let status: PeerInfoStatusData?
    let notificationSettings: TelegramPeerNotificationSettings?
    let globalNotificationSettings: EngineGlobalNotificationSettings?
    let isContact: Bool
    let availablePanes: [PeerInfoPaneKey]
    let groupsInCommon: GroupsInCommonContext?
    let linkedDiscussionPeer: Peer?
    let members: PeerInfoMembersData?
    let encryptionKeyFingerprint: SecretChatKeyFingerprint?
    let globalSettings: TelegramGlobalSettings?
    let invitations: PeerExportedInvitationsState?
    let requests: PeerInvitationImportersState?
    let requestsContext: PeerInvitationImportersContext?
    let threadData: MessageHistoryThreadData?
    let appConfiguration: AppConfiguration?
    
    init(
        peer: Peer?,
        chatPeer: Peer?,
        cachedData: CachedPeerData?,
        status: PeerInfoStatusData?,
        notificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: EngineGlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: GroupsInCommonContext?,
        linkedDiscussionPeer: Peer?,
        members: PeerInfoMembersData?,
        encryptionKeyFingerprint: SecretChatKeyFingerprint?,
        globalSettings: TelegramGlobalSettings?,
        invitations: PeerExportedInvitationsState?,
        requests: PeerInvitationImportersState?,
        requestsContext: PeerInvitationImportersContext?,
        threadData: MessageHistoryThreadData?,
        appConfiguration: AppConfiguration?
    ) {
        self.peer = peer
        self.chatPeer = chatPeer
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
        self.invitations = invitations
        self.requests = requests
        self.requestsContext = requestsContext
        self.threadData = threadData
        self.appConfiguration = appConfiguration
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

private func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<[PeerInfoPaneKey]?, NoError> {
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
        let location = context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder)
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(location, index: .upperBound, anchorIndex: .upperBound, count: 20, clipHoles: false, fixedCombinedReadStates: nil, tagMask: tag)
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
    var key: PeerInfoPaneKey?
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

private func peerInfoScreenInputData(context: AccountContext, peerId: EnginePeer.Id, isSettings: Bool) -> Signal<PeerInfoScreenInputData, NoError> {
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> map { peer -> PeerInfoScreenInputData in
        guard let peer = peer else {
            return .none
        }
        if case let .user(user) = peer {
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
        } else if case let .channel(channel) = peer {
            if case .group = channel.info {
                return .group(groupId: channel.id)
            } else {
                return .channel
            }
        } else if case let .legacyGroup(group) = peer {
            return .group(groupId: group.id)
        } else if case let .secretChat(secretChat) = peer {
            return .user(userId: secretChat.regularPeerId, secretChatId: peer.id, kind: .user)
        } else {
            return .none
        }
    }
    |> distinctUntilChanged
}

func keepPeerInfoScreenDataHot(context: AccountContext, peerId: PeerId, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<Never, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: false)
    |> mapToSignal { inputData -> Signal<Never, NoError> in
        switch inputData {
        case .none, .settings:
            return .complete()
        case .user, .channel, .group:
            return combineLatest(
                context.peerChannelMemberCategoriesContextsManager.profileData(postbox: context.account.postbox, network: context.account.network, peerId: peerId, customData: peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder) |> ignoreValues),
                context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId)) |> ignoreValues
            )
            |> ignoreValues
        }
    }
}

func peerInfoScreenSettingsData(context: AccountContext, peerId: EnginePeer.Id, accountsAndPeers: Signal<[(AccountContext, EnginePeer, Int32)], NoError>, activeSessionsContextAndCount: Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError>, notificationExceptions: Signal<NotificationExceptionsList?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, hasPassport: Signal<Bool, NoError>) -> Signal<PeerInfoScreenData, NoError> {
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
        context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]),
        getServerProvidedSuggestions(account: context.account),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
    )
    |> map { peerView, accountsAndPeers, accountSessions, privacySettings, sharedPreferences, notifications, stickerPacks, hasPassport, hasWatchApp, accountPreferences, suggestions, limits -> PeerInfoScreenData in
        let (notificationExceptions, notificationsAuthorizationStatus, notificationsWarningSuppressed) = notifications
        let (featuredStickerPacks, archivedStickerPacks) = stickerPacks
        
        let proxySettings: ProxySettings = sharedPreferences.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
        let inAppNotificationSettings: InAppNotificationSettings = sharedPreferences.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
        
        let unreadTrendingStickerPacks = featuredStickerPacks.reduce(0, { count, item -> Int in
            return item.unread ? count + 1 : count
        })
        
        var enableQRLogin = false
        let appConfiguration = accountPreferences.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self)
        if let appConfiguration, let data = appConfiguration.data, let enableQR = data["qr_login_camera"] as? Bool, enableQR {
            enableQRLogin = true
        }
        
        let peer = peerView.peers[peerId]
        let globalSettings = TelegramGlobalSettings(
            suggestPhoneNumberConfirmation: suggestions.contains(.validatePhoneNumber),
            suggestPasswordConfirmation: suggestions.contains(.validatePassword),
            accountsAndPeers: accountsAndPeers,
            activeSessionsContext: accountSessions?.0,
            webSessionsContext: accountSessions?.2,
            otherSessionsCount: accountSessions?.1,
            proxySettings: proxySettings,
            notificationAuthorizationStatus: notificationsAuthorizationStatus,
            notificationWarningSuppressed: notificationsWarningSuppressed,
            notificationExceptions: notificationExceptions,
            inAppNotificationSettings: inAppNotificationSettings,
            privacySettings: privacySettings,
            unreadTrendingStickerPacks: unreadTrendingStickerPacks,
            archivedStickerPacks: archivedStickerPacks,
            userLimits: peer?.isPremium == true ? limits.1 : limits.0,
            hasPassport: hasPassport,
            hasWatchApp: hasWatchApp,
            enableQRLogin: enableQRLogin)
        
        return PeerInfoScreenData(
            peer: peer,
            chatPeer: peer,
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
            globalSettings: globalSettings,
            invitations: nil,
            requests: nil,
            requestsContext: nil,
            threadData: nil,
            appConfiguration: appConfiguration
        )
    }
}

func peerInfoScreenData(context: AccountContext, peerId: PeerId, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, isSettings: Bool, hintGroupInCommon: PeerId?, existingRequestsContext: PeerInvitationImportersContext?, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<PeerInfoScreenData, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: isSettings)
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        switch inputData {
        case .none, .settings:
            return .single(PeerInfoScreenData(
                peer: nil,
                chatPeer: nil,
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
                globalSettings: nil,
                invitations: nil,
                requests: nil,
                requestsContext: nil,
                threadData: nil,
                appConfiguration: nil
            ))
        case let .user(userPeerId, secretChatId, kind):
            let groupsInCommon: GroupsInCommonContext?
            if [.user, .bot].contains(kind) {
                groupsInCommon = GroupsInCommonContext(account: context.account, peerId: userPeerId, hintGroupInCommon: hintGroupInCommon)
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
                            let (text, isActivity) = stringAndActivityForUserPresence(strings: strings, dateTimeFormat: dateTimeFormat, presence: EnginePeer.Presence(presence), relativeTo: Int32(timestamp), expanded: true)
                            return PeerInfoStatusData(text: text, isActivity: isActivity, key: nil)
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
                        subscriber.putNext(PeerInfoStatusData(text: strings.Bot_GenericBotStatus, isActivity: false, key: nil))
                    case .support:
                        subscriber.putNext(PeerInfoStatusData(text: strings.Bot_GenericSupportStatus, isActivity: false, key: nil))
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
                                    updateManager.reset(presence: EnginePeer.Presence(presence))
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
            
            var secretChatKeyFingerprint: Signal<EngineSecretChatKeyFingerprint?, NoError> = .single(nil)
            if let secretChatId = secretChatId {
                secretChatKeyFingerprint = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.SecretChatKeyFingerprint(id: secretChatId))
            }
            
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                secretChatKeyFingerprint,
                status
            )
            |> map { peerView, availablePanes, globalNotificationSettings, encryptionKeyFingerprint, status -> PeerInfoScreenData in
                var availablePanes = availablePanes
                if availablePanes != nil, groupsInCommon != nil, let cachedData = peerView.cachedData as? CachedUserData {
                    if cachedData.commonGroupCount != 0 {
                        availablePanes?.append(.groupsInCommon)
                    }
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[userPeerId],
                    chatPeer: peerView.peers[peerId],
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
                    globalSettings: nil,
                    invitations: nil,
                    requests: nil,
                    requestsContext: nil,
                    threadData: nil,
                    appConfiguration: nil
                )
            }
        case .channel:
            let status = context.account.viewTracker.peerView(peerId, updateData: false)
            |> map { peerView -> PeerInfoStatusData? in
                guard let _ = peerView.peers[peerId] as? TelegramChannel else {
                    return PeerInfoStatusData(text: strings.Channel_Status, isActivity: false, key: nil)
                }
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount != 0 {
                    return PeerInfoStatusData(text: strings.Conversation_StatusSubscribers(memberCount), isActivity: false, key: nil)
                } else {
                    return PeerInfoStatusData(text: strings.Channel_Status, isActivity: false, key: nil)
                }
            }
            |> distinctUntilChanged
            
            let invitationsContextPromise = Promise<PeerExportedInvitationsContext?>(nil)
            let invitationsStatePromise = Promise<PeerExportedInvitationsState?>(nil)
            
            let requestsContextPromise = Promise<PeerInvitationImportersContext?>(nil)
            let requestsStatePromise = Promise<PeerInvitationImportersState?>(nil)
            
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                status,
                invitationsContextPromise.get(),
                invitationsStatePromise.get(),
                requestsContextPromise.get(),
                requestsStatePromise.get()
            )
            |> map { peerView, availablePanes, globalNotificationSettings, status, currentInvitationsContext, invitations, currentRequestsContext, requests -> PeerInfoScreenData in
                var discussionPeer: Peer?
                if case let .known(maybeLinkedDiscussionPeerId) = (peerView.cachedData as? CachedChannelData)?.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = peerView.peers[linkedDiscussionPeerId] {
                    discussionPeer = peer
                }
                
                var canManageInvitations = false
                if let channel = peerViewMainPeer(peerView) as? TelegramChannel, let _ = peerView.cachedData as? CachedChannelData, channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                    canManageInvitations = true
                }
                if currentInvitationsContext == nil {
                    if canManageInvitations {
                        let invitationsContext = context.engine.peers.peerExportedInvitations(peerId: peerId, adminId: nil, revoked: false, forceUpdate: true)
                        invitationsContextPromise.set(.single(invitationsContext))
                        invitationsStatePromise.set(invitationsContext.state |> map(Optional.init))
                    }
                }
                
                if currentRequestsContext == nil {
                    if canManageInvitations {
                        let requestsContext = existingRequestsContext ?? context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
                        requestsContextPromise.set(.single(requestsContext))
                        requestsStatePromise.set(requestsContext.state |> map(Optional.init))
                    }
                }
                                                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    chatPeer: peerView.peers[peerId],
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
                    globalSettings: nil,
                    invitations: invitations,
                    requests: requests,
                    requestsContext: currentRequestsContext,
                    threadData: nil,
                    appConfiguration: nil
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
                            return context.peerChannelMemberCategoriesContextsManager.recentOnline(account: context.account, accountPeerId: context.account.peerId, peerId: peerId)
                            |> map(Optional.init)
                        } else {
                            return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
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
                        return PeerInfoStatusData(text: string, isActivity: false, key: nil)
                    } else if memberCount > 0 {
                        return PeerInfoStatusData(text: strings.Conversation_StatusMembers(Int32(memberCount)), isActivity: false, key: nil)
                    }
                } else if let group = peerView.peers[groupId] as? TelegramGroup, let cachedGroupData = peerView.cachedData as? CachedGroupData {
                    var onlineCount = 0
                    if let participants = cachedGroupData.participants {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        for participant in participants.participants {
                            if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                                let relativeStatus = relativeUserPresenceStatus(EnginePeer.Presence(presence), relativeTo: Int32(timestamp))
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
                        return PeerInfoStatusData(text: string, isActivity: false, key: nil)
                    } else {
                        return PeerInfoStatusData(text: strings.Conversation_StatusMembers(Int32(group.participantCount)), isActivity: false, key: nil)
                    }
                }
                
                return PeerInfoStatusData(text: strings.Group_Status, isActivity: false, key: nil)
            }
            |> distinctUntilChanged
            
            let membersData: Signal<PeerInfoMembersData?, NoError>
            if case .peer = chatLocation {
                let membersContext = PeerInfoMembersContext(context: context, peerId: groupId)
                membersData = combineLatest(membersContext.state, context.account.viewTracker.peerView(groupId, updateData: false))
                |> map { state, view -> PeerInfoMembersData? in
                    if state.members.count > 5 {
                        return .longList(membersContext)
                    } else {
                        return .shortList(membersContext: membersContext, members: state.members)
                    }
                }
                |> distinctUntilChanged
            } else {
                membersData = .single(nil)
            }
            
            let invitationsContextPromise = Promise<PeerExportedInvitationsContext?>(nil)
            let invitationsStatePromise = Promise<PeerExportedInvitationsState?>(nil)
            
            let requestsContextPromise = Promise<PeerInvitationImportersContext?>(nil)
            let requestsStatePromise = Promise<PeerInvitationImportersState?>(nil)
            
            let threadData: Signal<MessageHistoryThreadData?, NoError>
            if case let .replyThread(message) = chatLocation {
                let threadId = Int64(message.messageId.id)
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: threadId)
                threadData = context.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> MessageHistoryThreadData? in
                    guard let view = views.views[viewKey] as? MessageHistoryThreadInfoView else {
                        return nil
                    }
                    return view.info?.data.get(MessageHistoryThreadData.self)
                }
            } else {
                threadData = .single(nil)
            }
            
            return combineLatest(queue: .mainQueue(),
                context.account.viewTracker.peerView(groupId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: groupId, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                status,
                membersData,
                invitationsContextPromise.get(),
                invitationsStatePromise.get(),
                requestsContextPromise.get(),
                requestsStatePromise.get(),
                threadData,
                context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
            )
            |> map { peerView, availablePanes, globalNotificationSettings, status, membersData, currentInvitationsContext, invitations, currentRequestsContext, requests, threadData, preferencesView -> PeerInfoScreenData in
                var discussionPeer: Peer?
                if case let .known(maybeLinkedDiscussionPeerId) = (peerView.cachedData as? CachedChannelData)?.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = peerView.peers[linkedDiscussionPeerId] {
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
                
                var canManageInvitations = false
                if let group = peerViewMainPeer(peerView) as? TelegramGroup {
                    if case .creator = group.role {
                        canManageInvitations = true
                    } else if case let .admin(rights, _) = group.role, rights.rights.contains(.canInviteUsers) {
                        canManageInvitations = true
                    }
                } else if let channel = peerViewMainPeer(peerView) as? TelegramChannel, channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                    canManageInvitations = true
                }
                if currentInvitationsContext == nil {
                    if canManageInvitations {
                        let invitationsContext = context.engine.peers.peerExportedInvitations(peerId: peerId, adminId: nil, revoked: false, forceUpdate: true)
                        invitationsContextPromise.set(.single(invitationsContext))
                        invitationsStatePromise.set(invitationsContext.state |> map(Optional.init))
                    }
                }
                
                if currentRequestsContext == nil {
                    if canManageInvitations {
                        let requestsContext = existingRequestsContext ?? context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
                        requestsContextPromise.set(.single(requestsContext))
                        requestsStatePromise.set(requestsContext.state |> map(Optional.init))
                    }
                }
                
                var notificationSettings: TelegramPeerNotificationSettings?
                if let threadData = threadData {
                    notificationSettings = threadData.notificationSettings
                } else {
                    notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings
                }
                
                let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
              
                return PeerInfoScreenData(
                    peer: peerView.peers[groupId],
                    chatPeer: peerView.peers[groupId],
                    cachedData: peerView.cachedData,
                    status: status,
                    notificationSettings: notificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: nil,
                    linkedDiscussionPeer: discussionPeer,
                    members: membersData,
                    encryptionKeyFingerprint: nil,
                    globalSettings: nil,
                    invitations: invitations,
                    requests: requests,
                    requestsContext: currentRequestsContext,
                    threadData: threadData,
                    appConfiguration: appConfiguration
                )
            }
        }
    }
}

func canEditPeerInfo(context: AccountContext, peer: Peer?, threadData: MessageHistoryThreadData?) -> Bool {
    if context.account.peerId == peer?.id {
        return true
    }
    if let channel = peer as? TelegramChannel {
        if let threadData = threadData {
            if channel.hasPermission(.manageTopics) {
                return true
            }
            if threadData.author == context.account.peerId {
                return true
            }
        } else {
            if channel.hasPermission(.changeInfo) {
                return true
            }
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
                if !channel.flags.contains(.isGigagroup) {
                    result.insert(.restrict)
                }
                result.insert(.promote)
            } else {
                switch member {
                case let .channelMember(channelMember):
                    switch channelMember.participant {
                    case .creator:
                        break
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo {
                            if adminInfo.promotedBy == accountPeerId {
                                if !channel.flags.contains(.isGigagroup) {
                                    result.insert(.restrict)
                                }
                                if channel.hasPermission(.addAdmins) {
                                    result.insert(.promote)
                                }
                            }
                        } else {
                            if channel.hasPermission(.banMembers) && !channel.flags.contains(.isGigagroup) {
                                result.insert(.restrict)
                            }
                            if channel.hasPermission(.addAdmins) {
                                result.insert(.promote)
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
                case let .legacyGroupMember(_, _, invitedBy, _):
                    if invitedBy == accountPeerId {
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
                case let .legacyGroupMember(_, _, invitedBy, _):
                    if invitedBy == accountPeerId {
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

func peerInfoHeaderButtonIsHiddenWhileExpanded(buttonKey: PeerInfoHeaderButtonKey, isOpenedFromChat: Bool) -> Bool {
    var hiddenWhileExpanded = false
    if isOpenedFromChat {
        switch buttonKey {
        case .message, .search, .videoCall, .addMember, .leave, .discussion:
            hiddenWhileExpanded = true
        default:
            hiddenWhileExpanded = false
        }
    } else {
        switch buttonKey {
        case .search, .call, .videoCall, .addMember, .leave, .discussion:
            hiddenWhileExpanded = true
        default:
            hiddenWhileExpanded = false
        }
    }
    return hiddenWhileExpanded
}

func peerInfoHeaderButtons(peer: Peer?, cachedData: CachedPeerData?, isOpenedFromChat: Bool, isExpanded: Bool, videoCallsEnabled: Bool, isSecretChat: Bool, isContact: Bool, threadInfo: EngineMessageHistoryThread.Info?) -> [PeerInfoHeaderButtonKey] {
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
            } else {
                callsAvailable = true
                videoCallsAvailable = true
            }
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
        
        if user.botInfo != nil, let cachedData = cachedData as? CachedUserData, !cachedData.isBlocked {
            result.append(.stop)
        }
        
        if (isSecretChat && !isContact) || user.flags.contains(.isSupport) {
        } else {
            result.append(.more)
        }
    } else if let channel = peer as? TelegramChannel {
        if let _ = threadInfo {
            result.append(.mute)
            result.append(.search)
        } else {
            let hasVoiceChat = channel.flags.contains(.hasVoiceChat)
            let canStartVoiceChat = !hasVoiceChat && (channel.flags.contains(.isCreator) || channel.hasPermission(.manageCalls))
            let canManage = channel.flags.contains(.isCreator) || channel.adminRights != nil
            
            let hasDiscussion: Bool
            switch channel.info {
            case let .broadcast(info):
                hasDiscussion = info.flags.contains(.hasDiscussionGroup)
            case .group:
                hasDiscussion = false
            }
            
            let canLeave: Bool
            switch channel.participationStatus {
            case .member:
                canLeave = true
            default:
                canLeave = false
            }
            
            let canViewStats: Bool
            if let cachedChannelData = cachedData as? CachedChannelData {
                canViewStats = cachedChannelData.flags.contains(.canViewStats)
            } else {
                canViewStats = false
            }
            
            if hasVoiceChat || canStartVoiceChat {
                result.append(.voiceChat)
            }
            result.append(.mute)
            if hasDiscussion {
                result.append(.discussion)
            }
            result.append(.search)
            if canLeave {
                result.append(.leave)
            }
            
            var canReport = true
            if channel.isVerified || channel.adminRights != nil || channel.flags.contains(.isCreator)  {
                canReport = false
            }
            
            var hasMore = false
            if canReport || canViewStats {
                hasMore = true
                result.append(.more)
            }
            
            if hasDiscussion && isExpanded && result.count >= 5 {
                result.removeAll(where: { $0 == .search })
                if !hasMore {
                    hasMore = true
                    result.append(.more)
                }
            }
            
            if canLeave && isExpanded && (canManage || result.count >= 5) {
                result.removeAll(where: { $0 == .leave })
                if !hasMore {
                    hasMore = true
                    result.append(.more)
                }
            }
        }
    } else if let group = peer as? TelegramGroup {
        let hasVoiceChat = group.flags.contains(.hasVoiceChat)
        let canStartVoiceChat: Bool
        
        if !hasVoiceChat {
            if case .creator = group.role {
                canStartVoiceChat = true
            } else if case let .admin(rights, _) = group.role, rights.rights.contains(.canManageCalls) {
                canStartVoiceChat = true
            } else {
                canStartVoiceChat = false
            }
        } else {
            canStartVoiceChat = false
        }

        if hasVoiceChat || canStartVoiceChat {
            result.append(.voiceChat)
        }
        result.append(.mute)
        result.append(.search)
        result.append(.more)
    }
    
    return result
}

func peerInfoCanEdit(peer: Peer?, threadData: MessageHistoryThreadData?, cachedData: CachedPeerData?, isContact: Bool?) -> Bool {
    if let user = peer as? TelegramUser {
        if user.isDeleted {
            return false
        }
        if let isContact = isContact, !isContact {
            return false
        }
        return true
    } else if let peer = peer as? TelegramChannel {
        if peer.flags.contains(.isForum) {
            if peer.flags.contains(.isCreator) {
                return true
            } else if let threadData = threadData, threadData.isOwnedByMe {
                return true
            } else if peer.hasPermission(.manageTopics) {
                return true
            } else {
                return false
            }
        } else {
            if peer.flags.contains(.isCreator) {
                return true
            } else if peer.hasPermission(.changeInfo) {
                return true
            } else if let _ = peer.adminRights {
                return true
            }
            return false
        }
    } else if let peer = peer as? TelegramGroup {
        if case .creator = peer.role {
            return true
        } else if case let .admin(rights, _) = peer.role {
            if rights.rights.contains(.canAddAdmins) || rights.rights.contains(.canBanUsers) || rights.rights.contains(.canChangeInfo) || rights.rights.contains(.canInviteUsers) {
                return true
            }
            return false
        } else if !peer.hasBannedPermission(.banChangeInfo) {
            return true
        }
    }
    return false
}
