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
import PeerInfoVisualMediaPaneNode
import PhotoResources
import PeerInfoPaneNode
import WebUI

enum PeerInfoUpdatingAvatar {
    case none
    case image(TelegramMediaImageRepresentation)
}

enum AvatarUploadProgress {
    case value(CGFloat)
    case indefinite
}

final class PeerInfoState {
    let isEditing: Bool
    let selectedMessageIds: Set<MessageId>?
    let selectedStoryIds: Set<Int32>?
    let paneIsReordering: Bool
    let updatingAvatar: PeerInfoUpdatingAvatar?
    let updatingBio: String?
    let avatarUploadProgress: AvatarUploadProgress?
    let highlightedButton: PeerInfoHeaderButtonKey?
    let isEditingBirthDate: Bool
    let updatingBirthDate: TelegramBirthday??
    let personalChannels: [TelegramAdminedPublicChannel]?
    
    init(
        isEditing: Bool,
        selectedMessageIds: Set<MessageId>?,
        selectedStoryIds: Set<Int32>?,
        paneIsReordering: Bool,
        updatingAvatar: PeerInfoUpdatingAvatar?,
        updatingBio: String?,
        avatarUploadProgress: AvatarUploadProgress?,
        highlightedButton: PeerInfoHeaderButtonKey?,
        isEditingBirthDate: Bool,
        updatingBirthDate: TelegramBirthday??,
        personalChannels: [TelegramAdminedPublicChannel]?
    ) {
        self.isEditing = isEditing
        self.selectedMessageIds = selectedMessageIds
        self.selectedStoryIds = selectedStoryIds
        self.paneIsReordering = paneIsReordering
        self.updatingAvatar = updatingAvatar
        self.updatingBio = updatingBio
        self.avatarUploadProgress = avatarUploadProgress
        self.highlightedButton = highlightedButton
        self.isEditingBirthDate = isEditingBirthDate
        self.updatingBirthDate = updatingBirthDate
        self.personalChannels = personalChannels
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withSelectedStoryIds(_ selectedStoryIds: Set<Int32>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withPaneIsReordering(_ paneIsReordering: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withUpdatingAvatar(_ updatingAvatar: PeerInfoUpdatingAvatar?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withUpdatingBio(_ updatingBio: String?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withAvatarUploadProgress(_ avatarUploadProgress: AvatarUploadProgress?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withHighlightedButton(_ highlightedButton: PeerInfoHeaderButtonKey?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withIsEditingBirthDate(_ isEditingBirthDate: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withUpdatingBirthDate(_ updatingBirthDate: TelegramBirthday??) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: updatingBirthDate,
            personalChannels: self.personalChannels
        )
    }
    
    func withPersonalChannels(_ personalChannels: [TelegramAdminedPublicChannel]?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            selectedMessageIds: self.selectedMessageIds,
            selectedStoryIds: self.selectedStoryIds,
            paneIsReordering: self.paneIsReordering,
            updatingAvatar: self.updatingAvatar,
            updatingBio: self.updatingBio,
            avatarUploadProgress: self.avatarUploadProgress,
            highlightedButton: self.highlightedButton,
            isEditingBirthDate: self.isEditingBirthDate,
            updatingBirthDate: self.updatingBirthDate,
            personalChannels: personalChannels
        )
    }
}

final class TelegramGlobalSettings {
    let suggestPhoneNumberConfirmation: Bool
    let suggestPasswordConfirmation: Bool
    let suggestPasswordSetup: Bool
    let premiumGracePeriod: Bool
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
    let bots: [AttachMenuBot]
    let hasPassport: Bool
    let hasWatchApp: Bool
    let enableQRLogin: Bool
    
    init(
        suggestPhoneNumberConfirmation: Bool,
        suggestPasswordConfirmation: Bool,
        suggestPasswordSetup: Bool,
        premiumGracePeriod: Bool,
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
        bots: [AttachMenuBot],
        hasPassport: Bool,
        hasWatchApp: Bool,
        enableQRLogin: Bool
    ) {
        self.suggestPhoneNumberConfirmation = suggestPhoneNumberConfirmation
        self.suggestPasswordConfirmation = suggestPasswordConfirmation
        self.suggestPasswordSetup = suggestPasswordSetup
        self.premiumGracePeriod = premiumGracePeriod
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
        self.bots = bots
        self.hasPassport = hasPassport
        self.hasWatchApp = hasWatchApp
        self.enableQRLogin = enableQRLogin
    }
}

final class PeerInfoPersonalChannelData: Equatable {
    let peer: EngineRenderedPeer
    let subscriberCount: Int?
    let topMessages: [EngineMessage]
    let storyStats: PeerStoryStats?
    let isLoading: Bool
    
    init(peer: EngineRenderedPeer, subscriberCount: Int?, topMessages: [EngineMessage], storyStats: PeerStoryStats?, isLoading: Bool) {
        self.peer = peer
        self.subscriberCount = subscriberCount
        self.topMessages = topMessages
        self.storyStats = storyStats
        self.isLoading = isLoading
    }
    
    static func ==(lhs: PeerInfoPersonalChannelData, rhs: PeerInfoPersonalChannelData) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.subscriberCount != rhs.subscriberCount {
            return false
        }
        if lhs.topMessages != rhs.topMessages {
            return false
        }
        if lhs.storyStats != rhs.storyStats {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        return true
    }
}

final class PeerInfoScreenData {
    let peer: Peer?
    let chatPeer: Peer?
    let savedMessagesPeer: Peer?
    let cachedData: CachedPeerData?
    let status: PeerInfoStatusData?
    let peerNotificationSettings: TelegramPeerNotificationSettings?
    let threadNotificationSettings: TelegramPeerNotificationSettings?
    let globalNotificationSettings: EngineGlobalNotificationSettings?
    let availablePanes: [PeerInfoPaneKey]
    let groupsInCommon: GroupsInCommonContext?
    let linkedDiscussionPeer: Peer?
    let linkedMonoforumPeer: Peer?
    let members: PeerInfoMembersData?
    let storyListContext: StoryListContext?
    let storyArchiveListContext: StoryListContext?
    let botPreviewStoryListContext: StoryListContext?
    let encryptionKeyFingerprint: SecretChatKeyFingerprint?
    let globalSettings: TelegramGlobalSettings?
    let invitations: PeerExportedInvitationsState?
    let requests: PeerInvitationImportersState?
    let requestsContext: PeerInvitationImportersContext?
    let threadData: MessageHistoryThreadData?
    let appConfiguration: AppConfiguration?
    let isPowerSavingEnabled: Bool?
    let accountIsPremium: Bool
    let hasSavedMessageTags: Bool
    let hasBotPreviewItems: Bool
    let isPremiumRequiredForStoryPosting: Bool
    let personalChannel: PeerInfoPersonalChannelData?
    let starsState: StarsContext.State?
    let tonState: StarsContext.State?
    let starsRevenueStatsState: StarsRevenueStats?
    let starsRevenueStatsContext: StarsRevenueStatsContext?
    let revenueStatsState: StarsRevenueStats?
    let revenueStatsContext: StarsRevenueStatsContext?
    let profileGiftsContext: ProfileGiftsContext?
    let premiumGiftOptions: [PremiumGiftCodeOption]
    let webAppPermissions: WebAppPermissionsState?
    
    let _isContact: Bool
    var forceIsContact: Bool = false

    var isContact: Bool {
        if self.forceIsContact {
            return true
        } else {
            return self._isContact
        }
    }
    
    init(
        peer: Peer?,
        chatPeer: Peer?,
        savedMessagesPeer: Peer?,
        cachedData: CachedPeerData?,
        status: PeerInfoStatusData?,
        peerNotificationSettings: TelegramPeerNotificationSettings?,
        threadNotificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: EngineGlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: GroupsInCommonContext?,
        linkedDiscussionPeer: Peer?,
        linkedMonoforumPeer: Peer?,
        members: PeerInfoMembersData?,
        storyListContext: StoryListContext?,
        storyArchiveListContext: StoryListContext?,
        botPreviewStoryListContext: StoryListContext?,
        encryptionKeyFingerprint: SecretChatKeyFingerprint?,
        globalSettings: TelegramGlobalSettings?,
        invitations: PeerExportedInvitationsState?,
        requests: PeerInvitationImportersState?,
        requestsContext: PeerInvitationImportersContext?,
        threadData: MessageHistoryThreadData?,
        appConfiguration: AppConfiguration?,
        isPowerSavingEnabled: Bool?,
        accountIsPremium: Bool,
        hasSavedMessageTags: Bool,
        hasBotPreviewItems: Bool,
        isPremiumRequiredForStoryPosting: Bool,
        personalChannel: PeerInfoPersonalChannelData?,
        starsState: StarsContext.State?,
        tonState: StarsContext.State?,
        starsRevenueStatsState: StarsRevenueStats?,
        starsRevenueStatsContext: StarsRevenueStatsContext?,
        revenueStatsState: StarsRevenueStats?,
        revenueStatsContext: StarsRevenueStatsContext?,
        profileGiftsContext: ProfileGiftsContext?,
        premiumGiftOptions: [PremiumGiftCodeOption],
        webAppPermissions: WebAppPermissionsState?
    ) {
        self.peer = peer
        self.chatPeer = chatPeer
        self.savedMessagesPeer = savedMessagesPeer
        self.cachedData = cachedData
        self.status = status
        self.peerNotificationSettings = peerNotificationSettings
        self.threadNotificationSettings = threadNotificationSettings
        self.globalNotificationSettings = globalNotificationSettings
        self._isContact = isContact
        self.availablePanes = availablePanes
        self.groupsInCommon = groupsInCommon
        self.linkedDiscussionPeer = linkedDiscussionPeer
        self.linkedMonoforumPeer = linkedMonoforumPeer
        self.members = members
        self.storyListContext = storyListContext
        self.storyArchiveListContext = storyArchiveListContext
        self.botPreviewStoryListContext = botPreviewStoryListContext
        self.encryptionKeyFingerprint = encryptionKeyFingerprint
        self.globalSettings = globalSettings
        self.invitations = invitations
        self.requests = requests
        self.requestsContext = requestsContext
        self.threadData = threadData
        self.appConfiguration = appConfiguration
        self.isPowerSavingEnabled = isPowerSavingEnabled
        self.accountIsPremium = accountIsPremium
        self.hasSavedMessageTags = hasSavedMessageTags
        self.hasBotPreviewItems = hasBotPreviewItems
        self.isPremiumRequiredForStoryPosting = isPremiumRequiredForStoryPosting
        self.personalChannel = personalChannel
        self.starsState = starsState
        self.tonState = tonState
        self.starsRevenueStatsState = starsRevenueStatsState
        self.starsRevenueStatsContext = starsRevenueStatsContext
        self.revenueStatsState = revenueStatsState
        self.revenueStatsContext = revenueStatsContext
        self.profileGiftsContext = profileGiftsContext
        self.premiumGiftOptions = premiumGiftOptions
        self.webAppPermissions = webAppPermissions
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

public func hasAvailablePeerInfoMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<Bool, NoError> {
    let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
    let mediaPanes = peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: .peer(id: peerId), isMyProfile: false, chatLocationContextHolder: chatLocationContextHolder)
    |> map { panes -> Bool in
        if let panes {
            return !panes.isEmpty
        } else {
            return false
        }
    }
                         
    let hasSavedMessagesChats: Signal<Bool, NoError>
    if peerId == context.account.peerId {
        hasSavedMessagesChats = context.engine.messages.savedMessagesHasPeersOtherThanSaved()
        |> distinctUntilChanged
    } else {
        hasSavedMessagesChats = .single(false)
    }
    
    return combineLatest(queue: .mainQueue(), [mediaPanes, hasSavedMessagesChats])
    |> map { values in
        return values.contains(true)
    }
}

private func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId, chatLocation: ChatLocation, isMyProfile: Bool, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<[PeerInfoPaneKey]?, NoError> {
    var tags: [(MessageTags, PeerInfoPaneKey)] = []
    
    if !isMyProfile {
        tags = [
            (.photoOrVideo, .media),
            (.file, .files),
            (.music, .music),
            (.voiceOrInstantVideo, .voice),
            (.webPage, .links),
            (.gif, .gifs)
        ]
    }
    enum PaneState {
        case loading
        case empty
        case present
    }
    let loadedOnce = Atomic<Bool>(value: false)
    return combineLatest(queue: .mainQueue(), tags.map { tagAndKey -> Signal<(PeerInfoPaneKey, PaneState), NoError> in
        let (tag, key) = tagAndKey
        let location = context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder)
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(location, index: .upperBound, anchorIndex: .upperBound, count: 20, clipHoles: false, fixedCombinedReadStates: nil, tag: .tag(tag))
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
    return `deferred` {
        return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> mapToSignal { peer -> Signal<PeerInfoScreenInputData, NoError> in
            guard let peer = peer else {
                return .single(.none)
            }
            if case let .user(user) = peer {
                if isSettings && user.id == context.account.peerId {
                    return .single(.settings)
                } else {
                    let kind: PeerInfoScreenInputUserKind
                    if user.flags.contains(.isSupport) {
                        kind = .support
                    } else if user.botInfo != nil {
                        kind = .bot
                    } else {
                        kind = .user
                    }
                    return .single(.user(userId: user.id, secretChatId: nil, kind: kind))
                }
            } else if case let .channel(channel) = peer {
                if case .group = channel.info {
                    return .single(.group(groupId: channel.id))
                } else {
                    return .single(.channel)
                }
            } else if case let .legacyGroup(group) = peer {
                return .single(.group(groupId: group.id))
            } else if case let .secretChat(secretChat) = peer {
                return .single(.user(userId: secretChat.regularPeerId, secretChatId: peer.id, kind: .user))
            } else {
                return .single(.none)
            }
        }
        |> distinctUntilChanged
    }
}

public func keepPeerInfoScreenDataHot(context: AccountContext, peerId: PeerId, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<Never, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: false)
    |> mapToSignal { inputData -> Signal<Never, NoError> in
        switch inputData {
        case .none, .settings:
            return .complete()
        case .user, .channel, .group:
            var signals: [Signal<Never, NoError>] = []
            
            signals.append(context.peerChannelMemberCategoriesContextsManager.profileData(postbox: context.account.postbox, network: context.account.network, peerId: peerId, customData: peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, isMyProfile: false, chatLocationContextHolder: chatLocationContextHolder) |> ignoreValues) |> ignoreValues)
            signals.append(context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId)) |> ignoreValues)
            
            if case .user = inputData {
                signals.append(Signal { _ in
                    let listContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
                    let expiringListContext = PeerExpiringStoryListContext(account: context.account, peerId: peerId)
                    
                    return ActionDisposable {
                        let _ = listContext
                        let _ = expiringListContext
                    }
                })
            }
            
            return combineLatest(signals)
            |> ignoreValues
        }
    }
}

private func peerInfoPersonalOrLinkedChannel(context: AccountContext, peerId: EnginePeer.Id, isSettings: Bool) -> Signal<PeerInfoPersonalChannelData?, NoError> {
    let personalChannel: Signal<TelegramEngine.EngineData.Item.Peer.PersonalChannel.Result, NoError> = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> mapToSignal { peer -> Signal<TelegramEngine.EngineData.Item.Peer.PersonalChannel.Result, NoError> in
        guard let peer else {
            return .single(.known(nil))
        }
        if case .user = peer {
            return context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.PersonalChannel(id: peerId)
            )
        } else if case let .channel(channel) = peer, case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
            return .single(CachedTelegramPersonalChannel.known(TelegramPersonalChannel(peerId: linkedMonoforumId, subscriberCount: nil, topMessageId: nil)))
        }
        return .single(.known(nil))
    }
    
    return personalChannel
    |> distinctUntilChanged
    |> mapToSignal { personalChannel -> Signal<PeerInfoPersonalChannelData?, NoError> in
        guard case let .known(personalChannelValue) = personalChannel, let personalChannelValue else {
            return .single(nil)
        }
        
        return context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: personalChannelValue.peerId),
            TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: personalChannelValue.peerId)
        )
        |> mapToSignal { channelRenderedPeer, participantCount -> Signal<PeerInfoPersonalChannelData?, NoError> in
            guard let channelRenderedPeer, let channelPeer = channelRenderedPeer.peer else {
                return .single(nil)
            }
            
            let polledChannel: Signal<Void, NoError> = Signal<Void, NoError>.single(Void())
            |> then(
                context.account.viewTracker.polledChannel(peerId: channelPeer.id)
                |> ignoreValues
                |> map { _ -> Void in
                }
            )
            
            return combineLatest(
                context.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: channelPeer.id, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: []),
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.StoryStats(id: channelPeer.id)
                ),
                polledChannel
            )
            |> map { viewData, storyStats, _ -> PeerInfoPersonalChannelData? in
                let (view, _, _) = viewData
                var messages: [EngineMessage] = []
                for i in (0 ..< view.entries.count).reversed() {
                    if messages.isEmpty {
                        messages.append(EngineMessage(view.entries[i].message))
                    } else if messages[0].groupingKey != nil && messages[0].groupingKey == view.entries[i].message.groupingKey {
                        messages.append(EngineMessage(view.entries[i].message))
                    }
                }
                messages = messages.reversed()
                
                var isLoading = false
                if messages.isEmpty && view.isLoading {
                    isLoading = true
                }
                
                var mappedParticipantCount: Int?
                if let participantCount {
                    mappedParticipantCount = participantCount
                } else if let subscriberCount = personalChannelValue.subscriberCount {
                    mappedParticipantCount = Int(subscriberCount)
                }
                
                return PeerInfoPersonalChannelData(
                    peer: channelRenderedPeer,
                    subscriberCount: mappedParticipantCount,
                    topMessages: messages,
                    storyStats: storyStats,
                    isLoading: isLoading
                )
            }
        }
    }
    |> distinctUntilChanged
}

func peerInfoScreenSettingsData(context: AccountContext, peerId: EnginePeer.Id, accountsAndPeers: Signal<[(AccountContext, EnginePeer, Int32)], NoError>, activeSessionsContextAndCount: Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError>, notificationExceptions: Signal<NotificationExceptionsList?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, hasPassport: Signal<Bool, NoError>, starsContext: StarsContext?, tonContext: StarsContext?) -> Signal<PeerInfoScreenData, NoError> {
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
    
    let hasPassword: Signal<Bool?, NoError> = .single(nil) |> then(
        context.engine.auth.twoStepVerificationConfiguration()
        |> map { configuration -> Bool? in
            var notSet = false
            switch configuration {
            case let .notSet(pendingEmail):
                if pendingEmail == nil {
                    notSet = true
                }
            case .set:
                break
            }
            return !notSet
        }
    )
    |> distinctUntilChanged
    
    let storyListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
    let hasStories: Signal<Bool?, NoError> = storyListContext.state
    |> map { state -> Bool? in
        if !state.hasCache {
            return nil
        }
        return !state.items.isEmpty
    }
    |> distinctUntilChanged
    
    let botsKey = ValueBoxKey(length: 8)
    botsKey.setInt64(0, value: 0)
    
    //let iconLoaded = Atomic<[EnginePeer.Id: Bool]>(value: [:])
    let bots = context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: Namespaces.CachedItemCollection.attachMenuBots, id: botsKey))
    |> mapToSignal { entry -> Signal<[AttachMenuBot], NoError> in
        let bots: [AttachMenuBots.Bot] = entry?.get(AttachMenuBots.self)?.bots ?? []
        return context.engine.data.subscribe(
            EngineDataMap(bots.map(\.peerId).map(TelegramEngine.EngineData.Item.Peer.Peer.init))
        )
        |> mapToSignal { peersMap -> Signal<[AttachMenuBot], NoError> in
            var result: [Signal<AttachMenuBot?, NoError>] = []
            for bot in bots {
                if let maybePeer = peersMap[bot.peerId], let peer = maybePeer {
                    let resultBot = AttachMenuBot(peer: peer, shortName: bot.name, icons: bot.icons, peerTypes: bot.peerTypes, flags: bot.flags)
                    if bot.flags.contains(.showInSettings) {
                        result.append(.single(resultBot))
                    }
                }
            }
            return combineLatest(result)
            |> map { bots in
                var result: [AttachMenuBot] = []
                for bot in bots {
                    if let bot {
                        result.append(bot)
                    }
                }
                return result
            }
            |> distinctUntilChanged
        }
    }

    let starsState: Signal<StarsContext.State?, NoError>
    if let starsContext {
        starsState = starsContext.state
    } else {
        starsState = .single(nil)
    }
    let tonState: Signal<StarsContext.State?, NoError>
    if let tonContext {
        tonState = tonContext.state
    } else {
        tonState = .single(nil)
    }
    
    let profileGiftsContext = ProfileGiftsContext(account: context.account, peerId: peerId)
    
    return combineLatest(
        context.account.viewTracker.peerView(peerId, updateData: true),
        accountsAndPeers,
        activeSessionsContextAndCount,
        privacySettings,
        preferences,
        combineLatest(notificationExceptions, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get()),
        combineLatest(context.account.viewTracker.featuredStickerPacks(), archivedStickerPacks),
        hasPassport,
        context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]),
        context.engine.notices.getServerProvidedSuggestions(),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        ),
        hasPassword,
        context.sharedContext.automaticMediaDownloadSettings
        |> mapToSignal { settings -> Signal<Bool, NoError> in
            return automaticEnergyUsageShouldBeOn(settings: settings)
        }
        |> distinctUntilChanged,
        hasStories,
        bots,
        peerInfoPersonalOrLinkedChannel(context: context, peerId: peerId, isSettings: true),
        starsState,
        tonState
    )
    |> map { peerView, accountsAndPeers, accountSessions, privacySettings, sharedPreferences, notifications, stickerPacks, hasPassport, accountPreferences, suggestions, limits, hasPassword, isPowerSavingEnabled, hasStories, bots, personalChannel, starsState, tonState -> PeerInfoScreenData in
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
        
        var suggestPasswordSetup = false
        if suggestions.contains(.setupPassword), let hasPassword, !hasPassword {
            suggestPasswordSetup = true
        }
        
        let peer = peerView.peers[peerId]
        let globalSettings = TelegramGlobalSettings(
            suggestPhoneNumberConfirmation: suggestions.contains(.validatePhoneNumber),
            suggestPasswordConfirmation: suggestions.contains(.validatePassword),
            suggestPasswordSetup: suggestPasswordSetup,
            premiumGracePeriod: suggestions.contains(.gracePremium),
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
            bots: bots,
            hasPassport: hasPassport,
            hasWatchApp: false,
            enableQRLogin: enableQRLogin
        )
        
        return PeerInfoScreenData(
            peer: peer,
            chatPeer: peer,
            savedMessagesPeer: nil,
            cachedData: peerView.cachedData,
            status: nil,
            peerNotificationSettings: nil,
            threadNotificationSettings: nil,
            globalNotificationSettings: nil,
            isContact: false,
            availablePanes: [],
            groupsInCommon: nil,
            linkedDiscussionPeer: nil,
            linkedMonoforumPeer: nil,
            members: nil,
            storyListContext: hasStories == true ? storyListContext : nil,
            storyArchiveListContext: nil,
            botPreviewStoryListContext: nil,
            encryptionKeyFingerprint: nil,
            globalSettings: globalSettings,
            invitations: nil,
            requests: nil,
            requestsContext: nil,
            threadData: nil,
            appConfiguration: appConfiguration,
            isPowerSavingEnabled: isPowerSavingEnabled,
            accountIsPremium: peer?.isPremium ?? false,
            hasSavedMessageTags: false,
            hasBotPreviewItems: false,
            isPremiumRequiredForStoryPosting: true,
            personalChannel: personalChannel,
            starsState: starsState,
            tonState: tonState,
            starsRevenueStatsState: nil,
            starsRevenueStatsContext: nil,
            revenueStatsState: nil,
            revenueStatsContext: nil,
            profileGiftsContext: profileGiftsContext,
            premiumGiftOptions: [],
            webAppPermissions: nil
        )
    }
}

func peerInfoScreenData(context: AccountContext, peerId: PeerId, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, isSettings: Bool, isMyProfile: Bool, hintGroupInCommon: PeerId?, existingRequestsContext: PeerInvitationImportersContext?, existingProfileGiftsContext: ProfileGiftsContext?, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, privacySettings: Signal<AccountPrivacySettings?, NoError>, forceHasGifts: Bool) -> Signal<PeerInfoScreenData, NoError> {
    return peerInfoScreenInputData(context: context, peerId: peerId, isSettings: isSettings)
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        let wasUpgradedGroup = Atomic<Bool?>(value: nil)
        
        switch inputData {
        case .none, .settings:
            return .single(PeerInfoScreenData(
                peer: nil,
                chatPeer: nil,
                savedMessagesPeer: nil,
                cachedData: nil,
                status: nil,
                peerNotificationSettings: nil,
                threadNotificationSettings: nil,
                globalNotificationSettings: nil,
                isContact: false,
                availablePanes: [],
                groupsInCommon: nil,
                linkedDiscussionPeer: nil,
                linkedMonoforumPeer: nil,
                members: nil,
                storyListContext: nil,
                storyArchiveListContext: nil,
                botPreviewStoryListContext: nil,
                encryptionKeyFingerprint: nil,
                globalSettings: nil,
                invitations: nil,
                requests: nil,
                requestsContext: nil,
                threadData: nil,
                appConfiguration: nil,
                isPowerSavingEnabled: nil,
                accountIsPremium: false,
                hasSavedMessageTags: false,
                hasBotPreviewItems: false,
                isPremiumRequiredForStoryPosting: true,
                personalChannel: nil,
                starsState: nil,
                tonState: nil,
                starsRevenueStatsState: nil,
                starsRevenueStatsContext: nil,
                revenueStatsState: nil,
                revenueStatsContext: nil,
                profileGiftsContext: nil,
                premiumGiftOptions: [],
                webAppPermissions: nil
            ))
        case let .user(userPeerId, secretChatId, kind):
            let groupsInCommon: GroupsInCommonContext?
            if isMyProfile {
                groupsInCommon = nil
            } else if [.user, .bot].contains(kind) {
                groupsInCommon = GroupsInCommonContext(account: context.account, peerId: userPeerId, hintGroupInCommon: hintGroupInCommon)
            } else {
                groupsInCommon = nil
            }
            
            let recommendedBots: Signal<RecommendedBots?, NoError>
            if case .bot = kind {
                recommendedBots = context.engine.peers.recommendedBots(peerId: userPeerId)
            } else {
                recommendedBots = .single(nil)
            }
            
            let premiumGiftOptions: Signal<[PremiumGiftCodeOption], NoError>
            let profileGiftsContext: ProfileGiftsContext?
            if case .user = kind {
                if isMyProfile || userPeerId != context.account.peerId {
                    profileGiftsContext = existingProfileGiftsContext ?? ProfileGiftsContext(account: context.account, peerId: userPeerId)
                } else {
                    profileGiftsContext = nil
                }
                premiumGiftOptions = .single([])
                |> then(
                    context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
                )
            } else {
                profileGiftsContext = nil
                premiumGiftOptions = .single([])
            }
            
            enum StatusInputData: Equatable {
                case none
                case presence(TelegramUserPresence)
                case bot(subscriberCount: Int32?)
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
                            var isHiddenStatus = false
                            switch presence.status {
                            case .recently(let isHidden), .lastWeek(let isHidden), .lastMonth(let isHidden):
                                isHiddenStatus = isHidden
                            default:
                                break
                            }
                            return PeerInfoStatusData(text: text, isActivity: isActivity, isHiddenStatus: isHiddenStatus, key: nil)
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
                        return .bot(subscriberCount: user.subscriberCount)
                    }
                    guard let presence = view.peerPresences[userPeerId] as? TelegramUserPresence else {
                        return .none
                    }
                    return .presence(presence)
                }
                |> distinctUntilChanged).start(next: { inputData in
                    switch inputData {
                    case let .bot(subscriberCount):
                        if let subscriberCount, subscriberCount > 0 {
                            subscriber.putNext(PeerInfoStatusData(text: strings.Conversation_StatusBotSubscribers(subscriberCount), isActivity: false, key: nil))
                        } else {
                            subscriber.putNext(PeerInfoStatusData(text: strings.Bot_GenericBotStatus, isActivity: false, key: nil))
                        }
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
            
            let storyListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
            let hasStories: Signal<Bool?, NoError> = storyListContext.state
            |> map { state -> Bool? in
                if !state.hasCache {
                    return nil
                }
                return !state.items.isEmpty
            }
            |> distinctUntilChanged
            
            let hasStoryArchive: Signal<Bool?, NoError>
            var storyArchiveListContext: StoryListContext?
            if isMyProfile {
                let storyArchiveListContextValue = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: true)
                storyArchiveListContext = storyArchiveListContextValue
                hasStoryArchive = storyArchiveListContextValue.state
                |> map { state -> Bool? in
                    if !state.hasCache {
                        return nil
                    }
                    return !state.items.isEmpty
                }
                |> distinctUntilChanged
            } else {
                hasStoryArchive = .single(false)
            }
            
            var botPreviewStoryListContext: StoryListContext?
            let hasBotPreviewItems: Signal<Bool, NoError>
            if case .bot = kind {
                let botPreviewStoryListContextValue = BotPreviewStoryListContext(account: context.account, engine: context.engine, peerId: peerId, language: nil, assumeEmpty: false)
                botPreviewStoryListContext = botPreviewStoryListContextValue
                hasBotPreviewItems = botPreviewStoryListContextValue.state
                |> map { state in
                    return !state.items.isEmpty
                }
                |> distinctUntilChanged
            } else {
                hasBotPreviewItems = .single(false)
            }
            
            let accountIsPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                return peer?.isPremium ?? false
            }
            |> distinctUntilChanged
            
            let savedMessagesPeer: Signal<EnginePeer?, NoError>
            if peerId == context.account.peerId, case let .replyThread(replyThreadMessage) = chatLocation {
                savedMessagesPeer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(replyThreadMessage.threadId)))
            } else {
                savedMessagesPeer = .single(nil)
            }
            
            let hasSavedMessages: Signal<Bool, NoError>
            let hasSavedMessagesChats: Signal<Bool, NoError>
            if case .peer = chatLocation {
                hasSavedMessages = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: context.account.peerId, threadId: peerId.toInt64(), tag: MessageTags()))
                |> map { count -> Bool in
                    if let count, count != 0 {
                        return true
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                
                if peerId == context.account.peerId {
                    hasSavedMessagesChats = combineLatest(
                        context.engine.messages.savedMessagesHasPeersOtherThanSaved(),
                        context.engine.data.get(
                            TelegramEngine.EngineData.Item.Peer.DisplaySavedChatsAsTopics()
                        )
                    )
                    |> map { hasChats, displayAsTopics -> Bool in
                        return hasChats || displayAsTopics
                    }
                    |> distinctUntilChanged
                } else {
                    hasSavedMessagesChats = context.engine.messages.savedMessagesPeerListHead()
                    |> map { headPeerId -> Bool in
                        return headPeerId != nil
                    }
                    |> distinctUntilChanged
                }
            } else {
                hasSavedMessages = .single(false)
                hasSavedMessagesChats = .single(false)
            }
            
            let hasSavedMessageTags: Signal<Bool, NoError>
            if let peerId = chatLocation.peerId {
                if case .peer = chatLocation {
                    if peerId != context.account.peerId {
                        hasSavedMessageTags = context.engine.data.subscribe(
                            TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: peerId.toInt64())
                        )
                        |> map { tags -> Bool in
                            return !tags.isEmpty
                        }
                        |> distinctUntilChanged
                    } else {
                        hasSavedMessageTags = context.engine.data.subscribe(
                            TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: nil)
                        )
                        |> map { tags -> Bool in
                            return !tags.isEmpty
                        }
                        |> distinctUntilChanged
                    }
                } else {
                    hasSavedMessageTags = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: peerId.toInt64())
                    )
                    |> map { tags -> Bool in
                        return !tags.isEmpty
                    }
                    |> distinctUntilChanged
                }
            } else {
                hasSavedMessageTags = .single(false)
            }
            
            let starsRevenueContextAndState = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<(StarsRevenueStatsContext?, StarsRevenueStats?), NoError> in
                var canViewStarsRevenue = false
                if let peer, case let .user(user) = peer, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) || context.sharedContext.applicationBindings.appBuildType == .internal || context.sharedContext.immediateExperimentalUISettings.devRequests {
                    canViewStarsRevenue = true
                }
                #if DEBUG
                canViewStarsRevenue = peerId != context.account.peerId
                #endif
                
                guard canViewStarsRevenue else {
                    return .single((nil, nil))
                }
                let starsRevenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: false)
                return starsRevenueStatsContext.state
                |> map { state -> (StarsRevenueStatsContext?, StarsRevenueStats?) in
                    return (starsRevenueStatsContext, state.stats)
                }
            }
            
            let revenueContextAndState = combineLatest(
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> distinctUntilChanged,
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CanViewRevenue(id: peerId))
                |> distinctUntilChanged
            )
            |> mapToSignal { peer, canViewRevenue -> Signal<(StarsRevenueStatsContext?, StarsRevenueStats?), NoError> in
                var canViewRevenue = canViewRevenue
                if let peer, case let .user(user) = peer, let _ = user.botInfo, context.sharedContext.applicationBindings.appBuildType == .internal || context.sharedContext.immediateExperimentalUISettings.devRequests {
                    canViewRevenue = true
                }
                #if DEBUG
                canViewRevenue = peerId != context.account.peerId
                #endif
                guard canViewRevenue else {
                    return .single((nil, nil))
                }
                let revenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: true)
                return revenueStatsContext.state
                |> map { state -> (StarsRevenueStatsContext?, StarsRevenueStats?) in
                    return (revenueStatsContext, state.stats)
                }
            }
            
            let webAppPermissions: Signal<WebAppPermissionsState?, NoError> = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<WebAppPermissionsState?, NoError> in
                if let peer, case let .user(user) = peer, let _ = user.botInfo {
                    return webAppPermissionsState(context: context, peerId: peerId)
                } else {
                    return .single(nil)
                }
            }
                     
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, isMyProfile: isMyProfile, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                secretChatKeyFingerprint,
                status,
                hasStories,
                hasStoryArchive,
                recommendedBots,
                accountIsPremium,
                savedMessagesPeer,
                hasSavedMessagesChats,
                hasSavedMessages,
                hasSavedMessageTags,
                hasBotPreviewItems,
                peerInfoPersonalOrLinkedChannel(context: context, peerId: peerId, isSettings: false),
                privacySettings,
                starsRevenueContextAndState,
                revenueContextAndState,
                premiumGiftOptions,
                webAppPermissions
            )
            |> map { peerView, availablePanes, globalNotificationSettings, encryptionKeyFingerprint, status, hasStories, hasStoryArchive, recommendedBots, accountIsPremium, savedMessagesPeer, hasSavedMessagesChats, hasSavedMessages, hasSavedMessageTags, hasBotPreviewItems, personalChannel, privacySettings, starsRevenueContextAndState, revenueContextAndState, premiumGiftOptions, webAppPermissions -> PeerInfoScreenData in
                var availablePanes = availablePanes
                if isMyProfile {
                    availablePanes?.insert(.stories, at: 0)
                    if let hasStoryArchive, hasStoryArchive {
                        availablePanes?.insert(.storyArchive, at: 1)
                    }
                    if availablePanes != nil, profileGiftsContext != nil, let cachedData = peerView.cachedData as? CachedUserData {
                        if let starGiftsCount = cachedData.starGiftsCount, starGiftsCount > 0 {
                            availablePanes?.insert(.gifts, at: hasStoryArchive == true ? 2 : 1)
                        }
                    }
                } else if let hasStories {
                    if hasStories, peerView.peers[peerView.peerId] is TelegramUser, peerView.peerId != context.account.peerId {
                        availablePanes?.insert(.stories, at: 0)
                    }
                    
                    if availablePanes != nil, profileGiftsContext != nil, let cachedData = peerView.cachedData as? CachedUserData, peerView.peerId != context.account.peerId {
                        if let starGiftsCount = cachedData.starGiftsCount, starGiftsCount > 0 {
                            availablePanes?.insert(.gifts, at: hasStories ? 1 : 0)
                        }
                    }
                    
                    if availablePanes != nil, groupsInCommon != nil, let cachedData = peerView.cachedData as? CachedUserData {
                        if cachedData.commonGroupCount != 0 {
                            availablePanes?.append(.groupsInCommon)
                        }
                    }
                    
                    if case .peer = chatLocation {
                        if peerId == context.account.peerId {
                            if hasSavedMessagesChats {
                                availablePanes?.insert(.savedMessagesChats, at: 0)
                            }
                        } else if hasSavedMessages && hasSavedMessagesChats {
                            if var availablePanesValue = availablePanes {
                                if let index = availablePanesValue.firstIndex(of: .media) {
                                    availablePanesValue.insert(.savedMessages, at: index + 1)
                                } else {
                                    availablePanesValue.insert(.savedMessages, at: 0)
                                }
                                availablePanes = availablePanesValue
                            }
                        }
                        
                        if let user = peerView.peers[peerView.peerId] as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp), botInfo.flags.contains(.canEdit) {
                            availablePanes?.insert(.botPreview, at: 0)
                        } else if let cachedData = peerView.cachedData as? CachedUserData, let botPreview = cachedData.botPreview, !botPreview.items.isEmpty {
                            availablePanes?.insert(.botPreview, at: 0)
                        }
                    }
                    
                    if let recommendedBots, recommendedBots.count > 0 {
                        availablePanes?.append(.similarBots)
                    }
                } else {
                    availablePanes = nil
                }
                
                let peer = peerView.peers[userPeerId]
                
                var globalSettings: TelegramGlobalSettings?
                if let privacySettings {
                    globalSettings = TelegramGlobalSettings(
                        suggestPhoneNumberConfirmation: false,
                        suggestPasswordConfirmation: false,
                        suggestPasswordSetup: false,
                        premiumGracePeriod: false,
                        accountsAndPeers: [],
                        activeSessionsContext: nil,
                        webSessionsContext: nil,
                        otherSessionsCount: nil,
                        proxySettings: ProxySettings(enabled: false, servers: [], activeServer: nil, useForCalls: false),
                        notificationAuthorizationStatus: .notDetermined,
                        notificationWarningSuppressed: false,
                        notificationExceptions: nil,
                        inAppNotificationSettings: InAppNotificationSettings(playSounds: false, vibrate: false, displayPreviews: false, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .chats, totalUnreadCountIncludeTags: .all, displayNameOnLockscreen: false, displayNotificationsFromAllAccounts: false, customSound: nil),
                        privacySettings: privacySettings,
                        unreadTrendingStickerPacks: 0,
                        archivedStickerPacks: nil,
                        userLimits: context.userLimits,
                        bots: [],
                        hasPassport: false,
                        hasWatchApp: false,
                        enableQRLogin: false)
                }
                
                return PeerInfoScreenData(
                    peer: peer,
                    chatPeer: peerView.peers[peerId],
                    savedMessagesPeer: savedMessagesPeer?._asPeer(),
                    cachedData: peerView.cachedData,
                    status: status,
                    peerNotificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    threadNotificationSettings: nil,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: groupsInCommon,
                    linkedDiscussionPeer: nil,
                    linkedMonoforumPeer: nil,
                    members: nil,
                    storyListContext: storyListContext,
                    storyArchiveListContext: storyArchiveListContext,
                    botPreviewStoryListContext: botPreviewStoryListContext,
                    encryptionKeyFingerprint: encryptionKeyFingerprint,
                    globalSettings: globalSettings,
                    invitations: nil,
                    requests: nil,
                    requestsContext: nil,
                    threadData: nil,
                    appConfiguration: nil,
                    isPowerSavingEnabled: nil,
                    accountIsPremium: accountIsPremium,
                    hasSavedMessageTags: hasSavedMessageTags,
                    hasBotPreviewItems: hasBotPreviewItems,
                    isPremiumRequiredForStoryPosting: false,
                    personalChannel: personalChannel,
                    starsState: nil,
                    tonState: nil,
                    starsRevenueStatsState: starsRevenueContextAndState.1,
                    starsRevenueStatsContext: starsRevenueContextAndState.0,
                    revenueStatsState: revenueContextAndState.1,
                    revenueStatsContext: revenueContextAndState.0,
                    profileGiftsContext: profileGiftsContext,
                    premiumGiftOptions: premiumGiftOptions,
                    webAppPermissions: webAppPermissions
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
            
            let storyListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
            let hasStories: Signal<Bool?, NoError> = storyListContext.state
            |> map { state -> Bool? in
                if !state.hasCache {
                    return nil
                }
                return !state.items.isEmpty
            }
            |> distinctUntilChanged
            
            let accountIsPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                return peer?.isPremium ?? false
            }
            |> distinctUntilChanged
            
            let hasSavedMessages: Signal<Bool, NoError>
            let hasSavedMessagesChats: Signal<Bool, NoError>
            if case .peer = chatLocation {
                hasSavedMessages = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: context.account.peerId, threadId: peerId.toInt64(), tag: MessageTags()))
                |> map { count -> Bool in
                    if let count, count != 0 {
                        return true
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                hasSavedMessagesChats = context.engine.messages.savedMessagesPeerListHead()
                |> map { headPeerId -> Bool in
                    return headPeerId != nil
                }
                |> distinctUntilChanged
            } else {
                hasSavedMessages = .single(false)
                hasSavedMessagesChats = .single(false)
            }
            
            let hasSavedMessageTags: Signal<Bool, NoError>
            if let peerId = chatLocation.peerId {
                hasSavedMessageTags = context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: peerId.toInt64())
                )
                |> map { tags -> Bool in
                    return !tags.isEmpty
                }
                |> distinctUntilChanged
            } else {
                hasSavedMessageTags = .single(false)
            }
            
            let isPremiumRequiredForStoryPosting: Signal<Bool, NoError> = isPremiumRequiredForStoryPosting(context: context)
            
            let starsRevenueContextAndState = context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.CanViewStarsRevenue(id: peerId)
            )
            |> distinctUntilChanged
            |> mapToSignal { canViewStarsRevenue -> Signal<(StarsRevenueStatsContext?, StarsRevenueStats?), NoError> in
                guard canViewStarsRevenue else {
                    return .single((nil, nil))
                }
                let starsRevenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: false)
                return starsRevenueStatsContext.state
                |> map { state -> (StarsRevenueStatsContext?, StarsRevenueStats?) in
                    return (starsRevenueStatsContext, state.stats)
                }
            }
            
            let revenueContextAndState = context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.CanViewRevenue(id: peerId)
            )
            |> distinctUntilChanged
            |> mapToSignal { canViewRevenue -> Signal<(StarsRevenueStatsContext?, StarsRevenueStats?), NoError> in
                guard canViewRevenue else {
                    return .single((nil, nil))
                }
                let revenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: true)
                return revenueStatsContext.state
                |> map { state -> (StarsRevenueStatsContext?, StarsRevenueStats?) in
                    return (revenueStatsContext, state.stats)
                }
            }
            
            let profileGiftsContext = ProfileGiftsContext(account: context.account, peerId: peerId)
            
            let personalChannel = peerInfoPersonalOrLinkedChannel(context: context, peerId: peerId, isSettings: false)
            
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId, chatLocation: chatLocation, isMyProfile: false, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                status,
                invitationsContextPromise.get(),
                invitationsStatePromise.get(),
                requestsContextPromise.get(),
                requestsStatePromise.get(),
                hasStories,
                accountIsPremium,
                context.engine.peers.recommendedChannels(peerId: peerId),
                hasSavedMessages,
                hasSavedMessagesChats,
                hasSavedMessageTags,
                isPremiumRequiredForStoryPosting,
                starsRevenueContextAndState,
                revenueContextAndState,
                profileGiftsContext.state,
                personalChannel
            )
            |> map { peerView, availablePanes, globalNotificationSettings, status, currentInvitationsContext, invitations, currentRequestsContext, requests, hasStories, accountIsPremium, recommendedChannels, hasSavedMessages, hasSavedMessagesChats, hasSavedMessageTags, isPremiumRequiredForStoryPosting, starsRevenueContextAndState, revenueContextAndState, profileGiftsState, personalChannel -> PeerInfoScreenData in
                var availablePanes = availablePanes
                if let hasStories {
                    if hasStories {
                        availablePanes?.insert(.stories, at: 0)
                    }
                    if let recommendedChannels, !recommendedChannels.channels.isEmpty {
                        availablePanes?.append(.similarChannels)
                    }
                    
                    if case .peer = chatLocation {
                        if hasSavedMessages, hasSavedMessagesChats, var availablePanesValue = availablePanes {
                            if let index = availablePanesValue.firstIndex(of: .media) {
                                availablePanesValue.insert(.savedMessages, at: index + 1)
                            } else if let index = availablePanesValue.firstIndex(of: .stories) {
                                availablePanesValue.insert(.savedMessages, at: index + 1)
                            } else {
                                availablePanesValue.insert(.savedMessages, at: 0)
                            }
                            availablePanes = availablePanesValue
                        }
                    }
                    
                    if availablePanes != nil, let cachedData = peerView.cachedData as? CachedChannelData {
                        if (cachedData.starGiftsCount ?? 0) > 0 || (profileGiftsState.count ?? 0) > 0 || forceHasGifts {
                            availablePanes?.insert(.gifts, at: hasStories ? 1 : 0)
                        }
                    }
                } else {
                    availablePanes = nil
                }
                
                var discussionPeer: Peer?
                if case let .known(maybeLinkedDiscussionPeerId) = (peerView.cachedData as? CachedChannelData)?.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = peerView.peers[linkedDiscussionPeerId] {
                    discussionPeer = peer
                }
                
                var monoforumPeer: Peer?
                if let channel = peerViewMainPeer(peerView) as? TelegramChannel, case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
                    monoforumPeer = peerView.peers[linkedMonoforumId]
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
                    savedMessagesPeer: nil,
                    cachedData: peerView.cachedData,
                    status: status,
                    peerNotificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    threadNotificationSettings: nil,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: nil,
                    linkedDiscussionPeer: discussionPeer,
                    linkedMonoforumPeer: monoforumPeer,
                    members: nil,
                    storyListContext: storyListContext,
                    storyArchiveListContext: nil,
                    botPreviewStoryListContext: nil,
                    encryptionKeyFingerprint: nil,
                    globalSettings: nil,
                    invitations: invitations,
                    requests: requests,
                    requestsContext: currentRequestsContext,
                    threadData: nil,
                    appConfiguration: nil,
                    isPowerSavingEnabled: nil,
                    accountIsPremium: accountIsPremium,
                    hasSavedMessageTags: hasSavedMessageTags,
                    hasBotPreviewItems: false,
                    isPremiumRequiredForStoryPosting: isPremiumRequiredForStoryPosting,
                    personalChannel: personalChannel,
                    starsState: nil,
                    tonState: nil,
                    starsRevenueStatsState: starsRevenueContextAndState.1,
                    starsRevenueStatsContext: starsRevenueContextAndState.0,
                    revenueStatsState: revenueContextAndState.1,
                    revenueStatsContext: revenueContextAndState.0,
                    profileGiftsContext: profileGiftsContext,
                    premiumGiftOptions: [],
                    webAppPermissions: nil
                )
            }
        case let .group(groupId):
            var onlineMemberCount: Signal<(total: Int32?, recent: Int32?), NoError> = .single((nil, nil))
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
                |> mapToSignal { isLarge -> Signal<(total: Int32?, recent: Int32?), NoError> in
                    if let isLarge = isLarge {
                        if isLarge {
                            return context.peerChannelMemberCategoriesContextsManager.recentOnline(account: context.account, accountPeerId: context.account.peerId, peerId: peerId)
                            |> map { value -> (total: Int32?, recent: Int32?) in
                                return (nil, value)
                            }
                        } else {
                            return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                            |> map { value -> (total: Int32?, recent: Int32?) in
                                return (value.total, value.recent)
                            }
                        }
                    } else {
                        return .single((nil, nil))
                    }
                }
            }
            
            let status = combineLatest(queue: .mainQueue(),
                context.account.viewTracker.peerView(groupId, updateData: false),
                onlineMemberCount
            )
            |> map { peerView, memberCountData -> PeerInfoStatusData? in
                let (preciseTotalMemberCount, onlineMemberCount) = memberCountData
                
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = preciseTotalMemberCount ?? cachedChannelData.participantsSummary.memberCount {
                    if let onlineMemberCount, onlineMemberCount > 1 {
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
            
            let storyListContext: StoryListContext?
            let hasStories: Signal<Bool?, NoError>
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                storyListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
                hasStories = storyListContext!.state
                |> map { state -> Bool? in
                    if !state.hasCache {
                        return nil
                    }
                    return !state.items.isEmpty
                }
                |> distinctUntilChanged
            } else {
                storyListContext = nil
                hasStories = .single(false)
            }
            
            let threadData: Signal<MessageHistoryThreadData?, NoError>
            if case let .replyThread(message) = chatLocation {
                let threadId = message.threadId
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
            
            let accountIsPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                return peer?.isPremium ?? false
            }
            |> distinctUntilChanged
            
            let hasSavedMessages: Signal<Bool, NoError>
            let hasSavedMessagesChats: Signal<Bool, NoError>
            if case .peer = chatLocation {
                hasSavedMessages = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: context.account.peerId, threadId: peerId.toInt64(), tag: MessageTags()))
                |> map { count -> Bool in
                    if let count, count != 0 {
                        return true
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                hasSavedMessagesChats = context.engine.messages.savedMessagesPeerListHead()
                |> map { headPeerId -> Bool in
                    return headPeerId != nil
                }
                |> distinctUntilChanged
            } else {
                hasSavedMessages = .single(false)
                hasSavedMessagesChats = .single(false)
            }
            
            let hasSavedMessageTags: Signal<Bool, NoError>
            if let peerId = chatLocation.peerId {
                hasSavedMessageTags = context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: peerId.toInt64())
                )
                |> map { tags -> Bool in
                    return !tags.isEmpty
                }
                |> distinctUntilChanged
            } else {
                hasSavedMessageTags = .single(false)
            }
            
            let starsRevenueContextAndState = context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.CanViewStarsRevenue(id: peerId)
            )
            |> distinctUntilChanged
            |> mapToSignal { canViewStarsRevenue -> Signal<(StarsRevenueStatsContext?, StarsRevenueStats?), NoError> in
                guard canViewStarsRevenue else {
                    return .single((nil, nil))
                }
                let starsRevenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: false)
                return starsRevenueStatsContext.state
                |> map { state -> (StarsRevenueStatsContext?, StarsRevenueStats?) in
                    return (starsRevenueStatsContext, state.stats)
                }
            }
            
            let isPremiumRequiredForStoryPosting: Signal<Bool, NoError> = isPremiumRequiredForStoryPosting(context: context)
            
            return combineLatest(queue: .mainQueue(),
                context.account.viewTracker.peerView(groupId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: groupId, chatLocation: chatLocation, isMyProfile: false, chatLocationContextHolder: chatLocationContextHolder),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                status,
                membersData,
                invitationsContextPromise.get(),
                invitationsStatePromise.get(),
                requestsContextPromise.get(),
                requestsStatePromise.get(),
                hasStories,
                threadData,
                context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]),
                accountIsPremium,
                hasSavedMessages,
                hasSavedMessagesChats,
                hasSavedMessageTags,
                isPremiumRequiredForStoryPosting,
                starsRevenueContextAndState
            )
            |> mapToSignal { peerView, availablePanes, globalNotificationSettings, status, membersData, currentInvitationsContext, invitations, currentRequestsContext, requests, hasStories, threadData, preferencesView, accountIsPremium, hasSavedMessages, hasSavedMessagesChats, hasSavedMessageTags, isPremiumRequiredForStoryPosting, starsRevenueContextAndState -> Signal<PeerInfoScreenData, NoError> in
                var discussionPeer: Peer?
                if case let .known(maybeLinkedDiscussionPeerId) = (peerView.cachedData as? CachedChannelData)?.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = peerView.peers[linkedDiscussionPeerId] {
                    discussionPeer = peer
                }
                
                var monoforumPeer: Peer?
                if let channel = peerViewMainPeer(peerView) as? TelegramChannel, case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
                    monoforumPeer = peerView.peers[linkedMonoforumId]
                }
                                
                var availablePanes = availablePanes
                if let membersData = membersData, case .longList = membersData {
                    if availablePanes != nil {
                        availablePanes?.insert(.members, at: 0)
                    } else {
                        availablePanes = [.members]
                    }
                }
                
                if let hasStories {
                    if hasStories {
                        availablePanes?.insert(.stories, at: 0)
                    }
                    if case .peer = chatLocation {
                        if hasSavedMessages, hasSavedMessagesChats, var availablePanesValue = availablePanes {
                            if let index = availablePanesValue.firstIndex(of: .media) {
                                availablePanesValue.insert(.savedMessages, at: index + 1)
                            } else if let index = availablePanesValue.firstIndex(of: .stories) {
                                availablePanesValue.insert(.savedMessages, at: index + 1)
                            } else {
                                availablePanesValue.insert(.savedMessages, at: 0)
                            }
                            availablePanes = availablePanesValue
                        }
                    }
                }
                                
                var canManageInvitations = false
                if let group = peerViewMainPeer(peerView) as? TelegramGroup {
                    let previousValue = wasUpgradedGroup.swap(group.migrationReference != nil)
                    if group.migrationReference != nil, let previousValue, !previousValue {
                        return .never()
                    }
                    
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
                
                let peerNotificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings
                let threadNotificationSettings = threadData?.notificationSettings
                
                let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
              
                return .single(PeerInfoScreenData(
                    peer: peerView.peers[groupId],
                    chatPeer: peerView.peers[groupId],
                    savedMessagesPeer: nil,
                    cachedData: peerView.cachedData,
                    status: status,
                    peerNotificationSettings: peerNotificationSettings,
                    threadNotificationSettings: threadNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes ?? [],
                    groupsInCommon: nil,
                    linkedDiscussionPeer: discussionPeer,
                    linkedMonoforumPeer: monoforumPeer,
                    members: membersData,
                    storyListContext: storyListContext,
                    storyArchiveListContext: nil,
                    botPreviewStoryListContext: nil,
                    encryptionKeyFingerprint: nil,
                    globalSettings: nil,
                    invitations: invitations,
                    requests: requests,
                    requestsContext: currentRequestsContext,
                    threadData: threadData,
                    appConfiguration: appConfiguration,
                    isPowerSavingEnabled: nil,
                    accountIsPremium: accountIsPremium,
                    hasSavedMessageTags: hasSavedMessageTags,
                    hasBotPreviewItems: false,
                    isPremiumRequiredForStoryPosting: isPremiumRequiredForStoryPosting,
                    personalChannel: nil,
                    starsState: nil,
                    tonState: nil,
                    starsRevenueStatsState: starsRevenueContextAndState.1,
                    starsRevenueStatsContext: starsRevenueContextAndState.0,
                    revenueStatsState: nil,
                    revenueStatsContext: nil,
                    profileGiftsContext: nil,
                    premiumGiftOptions: [],
                    webAppPermissions: nil
                ))
            }
        }
    }
}

func canEditPeerInfo(context: AccountContext, peer: Peer?, chatLocation: ChatLocation, threadData: MessageHistoryThreadData?) -> Bool {
    if context.account.peerId == peer?.id {
        return true
    }
    if let user = peer as? TelegramUser, let botInfo = user.botInfo {
        return botInfo.flags.contains(.canEdit)
    } else if let channel = peer as? TelegramChannel {
        if let threadData = threadData {
            if chatLocation.threadId == 1 {
                return false
            }
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
                case let .channelMember(channelMember, _):
                    switch channelMember.participant {
                    case .creator:
                        break
                    case let .member(_, _, adminInfo, _, _, _):
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
                case let .legacyGroupMember(_, _, invitedBy, _, _):
                    result.insert(.restrict)
                    if invitedBy == accountPeerId {
                        result.insert(.promote)
                    }
                case .channelMember:
                    break
                case .account:
                    break
                }
            case .member:
                switch member {
                case let .legacyGroupMember(_, _, invitedBy, _, _):
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

func peerInfoHeaderActionButtons(peer: Peer?, isSecretChat: Bool, isContact: Bool) -> [PeerInfoHeaderButtonKey] {
    var result: [PeerInfoHeaderButtonKey] = []
    if !isContact && !isSecretChat, let user = peer as? TelegramUser, user.botInfo == nil {
        result = [.message, .addContact]
    }
    
    if "".isEmpty {
        return []
    }
    
    return result
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
            if case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), !channel.hasPermission(.manageDirect) {
                result.append(.message)
            }
            result.append(.mute)
            if case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), !channel.hasPermission(.manageDirect) {
            } else if hasDiscussion {
                result.append(.discussion)
            }
            result.append(.search)
            if canLeave {
                result.append(.leave)
            }
            
            var canReport = true
            if channel.adminRights != nil || channel.flags.contains(.isCreator)  {
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

func peerInfoCanEdit(peer: Peer?, chatLocation: ChatLocation, threadData: MessageHistoryThreadData?, cachedData: CachedPeerData?, isContact: Bool?) -> Bool {
    if let user = peer as? TelegramUser {
        if user.isDeleted {
            return false
        }
        if let botInfo = user.botInfo {
            return botInfo.flags.contains(.canEdit)
        }
        if let isContact = isContact, !isContact {
            return false
        }
        return true
    } else if let peer = peer as? TelegramChannel {
        if peer.isForumOrMonoForum, let threadData = threadData {
            if peer.flags.contains(.isCreator) {
                return true
            } else if threadData.isOwnedByMe {
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

func peerInfoIsChatMuted(peer: Peer?, peerNotificationSettings: TelegramPeerNotificationSettings?, threadNotificationSettings: TelegramPeerNotificationSettings?, globalNotificationSettings: EngineGlobalNotificationSettings?) -> Bool {
    func isPeerMuted(peer: Peer?, peerNotificationSettings: TelegramPeerNotificationSettings?, globalNotificationSettings: EngineGlobalNotificationSettings?) -> Bool {
        var peerIsMuted = false
        if let peerNotificationSettings {
            if case .muted = peerNotificationSettings.muteState {
                peerIsMuted = true
            } else if case .default = peerNotificationSettings.muteState, let globalNotificationSettings {
                if let peer {
                    if peer is TelegramUser {
                        peerIsMuted = !globalNotificationSettings.privateChats.enabled
                    } else if peer is TelegramGroup {
                        peerIsMuted = !globalNotificationSettings.groupChats.enabled
                    } else if let channel = peer as? TelegramChannel {
                        switch channel.info {
                        case .group:
                            peerIsMuted = !globalNotificationSettings.groupChats.enabled
                        case .broadcast:
                            peerIsMuted = !globalNotificationSettings.channels.enabled
                        }
                    }
                }
            }
        }
        return peerIsMuted
    }
    
    var chatIsMuted = false
    if let threadNotificationSettings {
        if case .muted = threadNotificationSettings.muteState {
            chatIsMuted = true
        } else if let peerNotificationSettings {
            chatIsMuted = isPeerMuted(peer: peer, peerNotificationSettings: peerNotificationSettings, globalNotificationSettings: globalNotificationSettings)
        }
    } else {
        chatIsMuted = isPeerMuted(peer: peer, peerNotificationSettings: peerNotificationSettings, globalNotificationSettings: globalNotificationSettings)
    }
    return chatIsMuted
}

private var isPremiumRequired: Bool?
private func isPremiumRequiredForStoryPosting(context: AccountContext) -> Signal<Bool, NoError> {
    if let isPremiumRequired {
        return .single(isPremiumRequired)
    }
    
    return .single(true)
    |> then(
        context.engine.messages.checkStoriesUploadAvailability(target: .myStories)
        |> deliverOnMainQueue
        |> map { status -> Bool in
            if case .premiumRequired = status {
                return true
            } else {
                return false
            }
        } |> afterNext { value in
            isPremiumRequired = value
        }
    )
}
