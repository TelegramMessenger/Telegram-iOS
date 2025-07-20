import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import ChatInterfaceState
import TelegramCore
import SwiftSignalKit
import ChatTitleView
import AvatarNode
import ChatPresentationInterfaceState
import PeerInfoScreen
import TelegramNotices
import ChatListUI
import EmojiStatusComponent
import TelegramUIPreferences
import TranslateUI

extension ChatControllerImpl {
    final class ContentData {
        final class Configuration: Equatable {
            let subject: ChatControllerSubject?
            let selectionState: ChatInterfaceSelectionState?
            let reportReason: ChatPresentationInterfaceState.ReportReasonData?
            
            init(
                subject: ChatControllerSubject?,
                selectionState: ChatInterfaceSelectionState?,
                reportReason: ChatPresentationInterfaceState.ReportReasonData?
            ) {
                self.subject = subject
                self.selectionState = selectionState
                self.reportReason = reportReason
            }
            
            static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
                if lhs.subject != rhs.subject {
                    return false
                }
                if lhs.selectionState != rhs.selectionState {
                    return false
                }
                if lhs.reportReason != rhs.reportReason {
                    return false
                }
                return true
            }
        }
        
        enum InfoAvatar {
            case peer(peer: EnginePeer, imageOverride: AvatarNodeImageOverride?, contextActionIsEnabled: Bool, accessibilityLabel: String?)
            case emojiStatus(content: EmojiStatusComponent.Content, contextActionIsEnabled: Bool)
        }
        
        enum PerformDismissAction {
            case upgraded(EnginePeer.Id)
            case movedToForumTopics
            case dismiss
        }
        
        struct NextChannelToRead: Equatable {
            struct ThreadData: Equatable {
                let id: Int64
                let data: MessageHistoryThreadData
                
                init(id: Int64, data: MessageHistoryThreadData) {
                    self.id = id
                    self.data = data
                }
            }
            
            let peer: EnginePeer
            let threadData: ThreadData?
            let unreadCount: Int
            let location: TelegramEngine.NextUnreadChannelLocation
            
            init(peer: EnginePeer, threadData: ThreadData?, unreadCount: Int, location: TelegramEngine.NextUnreadChannelLocation) {
                self.peer = peer
                self.threadData = threadData
                self.unreadCount = unreadCount
                self.location = location
            }
        }
        
        struct State {
            var peerView: PeerView?
            var threadInfo: EngineMessageHistoryThread.Info?
            var infoAvatar: InfoAvatar?
            var navigationUserInfo: PeerInfoNavigationSourceTag?
            var chatTitleContent: ChatTitleContent?
            var storyStats: PeerStoryStats?
            var renderedPeer: RenderedPeer?
            var hasScheduledMessages: Bool = false
            var hasSearchTags: Bool = false
            var hasSavedChats: Bool = false
            var isPremiumRequiredForMessaging: Bool = false
            var contactStatus: ChatContactStatus?
            var adMessage: Message?
            var offerNextChannelToRead: Bool = false
            var nextChannelToRead: NextChannelToRead?
            var nextChannelToReadDisplayName: Bool = false
            var isNotAccessible: Bool = false
            var hasBots: Bool = false
            var hasBotCommands: Bool = false
            var botMenuButton: BotMenuButton = .commands
            var isArchived: Bool = false
            var peerIsMuted: Bool = false
            var peerDiscussionId: EnginePeer.Id?
            var peerGeoLocation: PeerGeoLocation?
            var explicitelyCanPinMessages: Bool = false
            var autoremoveTimeout: Int32?
            var currentSendAsPeerId: EnginePeer.Id?
            var copyProtectionEnabled: Bool = false
            var sendPaidMessageStars: StarsAmount?
            var alwaysShowGiftButton: Bool = false
            var disallowedGifts: TelegramDisallowedGifts?
            var appliedBoosts: Int32?
            var boostsToUnrestrict: Int32?
            var hasBirthdayToday: Bool = false
            var businessIntro: TelegramBusinessIntro?
            var peerVerification: PeerVerification?
            var starGiftsAvailable: Bool = false
            var performDismissAction: PerformDismissAction?
            var savedMessagesTopicPeer: EnginePeer?
            
            var keyboardButtonsMessage: Message?
            var pinnedMessageId: EngineMessage.Id?
            var pinnedMessage: ChatPinnedMessage?
            var peerIsBlocked: Bool = false
            var callsAvailable: Bool = true
            var callsPrivate: Bool = false
            var activeGroupCallInfo: ChatActiveGroupCallInfo?
            var slowmodeState: ChatSlowmodeState?
            
            var suggestPremiumGift: Bool = false
            var translationState: ChatPresentationTranslationState?
            var voiceMessagesAvailable: Bool = true
            var requestsState: PeerInvitationImportersState?
            var dismissedInvitationRequests: [Int64]?
            var customEmojiAvailable: Bool = false
            var threadData: ChatPresentationInterfaceState.ThreadData?
            var forumTopicData: ChatPresentationInterfaceState.ThreadData?
            var isGeneralThreadClosed: Bool?
            var premiumGiftOptions: [CachedPremiumGiftOption] = []
            var removePaidMessageFeeData: ChatPresentationInterfaceState.RemovePaidMessageFeeData?
        }
        
        private let presentationData: PresentationData
        
        private var peerDisposable: Disposable?
        private var titleDisposable: Disposable?
        private var preloadSavedMessagesChatsDisposable: Disposable?
        
        private var preloadHistoryPeerId: PeerId?
        private let preloadHistoryPeerIdDisposable = MetaDisposable()

        private var preloadNextChatPeerId: PeerId?
        private let preloadNextChatPeerIdDisposable = MetaDisposable()
        
        private var nextChannelToReadDisposable: Disposable?
        private let chatAdditionalDataDisposable = MetaDisposable()
        private var premiumOrStarsRequiredDisposable: Disposable?
        private var buttonKeyboardMessageDisposable: Disposable?
        private var cachedDataDisposable: Disposable?
        private var premiumGiftSuggestionDisposable: Disposable?
        private var translationStateDisposable: Disposable?
        
        private let isPeerInfoReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        private let isChatLocationInfoReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        private let isCachedDataReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        
        let chatLocation: ChatLocation
        let chatLocationInfoData: ChatLocationInfoData
        
        private(set) var state: State = State()
        var initialInterfaceState: (interfaceState: ChatInterfaceState, editMessage: Message?)?
        var initialNavigationBadge: String?
        var initialPersistentPeerData: ChatPresentationInterfaceState.PersistentPeerData?
        
        var overlayTitle: String? {
            var title: String?
            if let threadInfo = self.state.threadInfo {
                title = threadInfo.title
            } else if let peerView = self.state.peerView {
                if let peer = peerViewMainPeer(peerView) {
                    title = EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
                }
            }
            return title
        }
        
        let isReady = Promise<Bool>()
        var onUpdated: ((State) -> Void)?
        
        let scrolledToMessageId = ValuePromise<ScrolledToMessageId?>(nil, ignoreRepeated: true)
        var scrolledToMessageIdValue: ScrolledToMessageId? = nil {
            didSet {
                self.scrolledToMessageId.set(self.scrolledToMessageIdValue)
            }
        }
        
        var historyNavigationStack = ChatHistoryNavigationStack()
        
        let chatThemeEmoticonPromise = Promise<String?>()
        let chatWallpaperPromise = Promise<TelegramWallpaper?>()
        
        private(set) var inviteRequestsContext: PeerInvitationImportersContext?
        private var inviteRequestsDisposable: Disposable?
        
        init(
            context: AccountContext,
            chatLocation: ChatLocation,
            chatLocationContextHolder: Atomic<ChatLocationContextHolder?>,
            initialSubject: ChatControllerSubject?,
            mode: ChatControllerPresentationMode,
            configuration: Signal<Configuration, NoError>,
            adMessagesContext: AdMessagesHistoryContext?,
            currentChatListFilter: Int32?,
            customChatNavigationStack: [EnginePeer.Id]?,
            presentationData: PresentationData,
            historyNode: ChatHistoryListNodeImpl,
            inviteRequestsContext: PeerInvitationImportersContext?
        ) {
            self.chatLocation = chatLocation
            self.presentationData = presentationData
            
            self.inviteRequestsContext = inviteRequestsContext
            
            let strings = self.presentationData.strings
            
            let chatLocationPeerId: PeerId? = chatLocation.peerId
            let peerId = chatLocationPeerId
            
            switch chatLocation {
            case .peer:
                self.chatLocationInfoData = .peer(Promise())
            case let .replyThread(replyThreadMessage):
                let promise = Promise<Message?>()
                if let effectiveMessageId = replyThreadMessage.effectiveMessageId {
                    promise.set(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: effectiveMessageId))
                    |> map { message -> Message? in
                        guard let message = message else {
                            return nil
                        }
                        return message._asMessage()
                    })
                } else {
                    promise.set(.single(nil))
                }
                self.chatLocationInfoData = .replyThread(promise)
            case .customChatContents:
                self.chatLocationInfoData = .customChatContents
            }
            
            if let peerId = chatLocation.peerId, peerId != context.account.peerId {
                switch initialSubject {
                case .pinnedMessages, .scheduledMessages, .messageOptions:
                    break
                default:
                    self.state.navigationUserInfo = PeerInfoNavigationSourceTag(peerId: peerId, threadId: chatLocation.threadId)
                }
            }
            
            let managingBot: Signal<ChatManagingBot?, NoError>
            if let peerId = chatLocation.peerId, peerId.namespace == Namespaces.Peer.CloudUser {
                managingBot = context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.ChatManagingBot(id: peerId)
                )
                |> mapToSignal { result -> Signal<ChatManagingBot?, NoError> in
                    guard let result else {
                        return .single(nil)
                    }
                    return context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: result.id)
                    )
                    |> map { botPeer -> ChatManagingBot? in
                        guard let botPeer else {
                            return nil
                        }
                        
                        return ChatManagingBot(bot: botPeer, isPaused: result.isPaused, canReply: result.canReply, settingsUrl: result.manageUrl)
                    }
                }
                |> distinctUntilChanged
            } else {
                managingBot = .single(nil)
            }
            
            if case let .peer(peerView) = self.chatLocationInfoData, let peerId = peerId {
                peerView.set(context.account.viewTracker.peerView(peerId))
                var onlineMemberCount: Signal<(total: Int32?, recent: Int32?), NoError> = .single((nil, nil))
                var hasScheduledMessages: Signal<Bool, NoError> = .single(false)
                
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    let recentOnlineSignal: Signal<(total: Int32?, recent: Int32?), NoError> = peerView.get()
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
                    onlineMemberCount = recentOnlineSignal
                }
                
                var isScheduledOrPinnedMessages = false
                switch initialSubject {
                case .scheduledMessages, .pinnedMessages, .messageOptions:
                    isScheduledOrPinnedMessages = true
                default:
                    break
                }
                
                if chatLocation.peerId != nil, !isScheduledOrPinnedMessages, peerId.namespace != Namespaces.Peer.SecretChat {
                    hasScheduledMessages = peerView.get()
                    |> take(1)
                    |> mapToSignal { view -> Signal<Bool, NoError> in
                        if let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendSomething) {
                            return .single(false)
                        } else {
                            return context.account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder))
                            |> map { view, _, _ in
                                return !view.entries.isEmpty
                            }
                        }
                    }
                }
                
                var displayedCountSignal: Signal<Int?, NoError> = .single(nil)
                var subtitleTextSignal: Signal<String?, NoError> = .single(nil)
                if case .pinnedMessages = initialSubject {
                    displayedCountSignal = ChatControllerImpl.topPinnedMessageSignal(context: context, chatLocation: chatLocation, referenceMessage: nil)
                    |> map { message -> Int? in
                        return message?.totalCount
                    }
                    |> distinctUntilChanged
                } else if case let .messageOptions(peerIds, messageIds, info) = initialSubject {
                    displayedCountSignal = configuration
                    |> map { configuration -> Int? in
                        if let selectionState = configuration.selectionState {
                            return selectionState.selectedIds.count
                        } else {
                            return messageIds.count
                        }
                    }
                    |> distinctUntilChanged
                    
                    let peers = context.account.postbox.multiplePeersView(peerIds)
                    |> take(1)
                    
                    switch info {
                    case let .forward(forward):
                        subtitleTextSignal = combineLatest(peers, forward.options, displayedCountSignal)
                        |> map { peersView, options, count in
                            let peers = peersView.peers.values
                            if !peers.isEmpty {
                                if peers.count == 1, let peer = peers.first {
                                    if let peer = peer as? TelegramUser {
                                        let displayName = EnginePeer(peer).compactDisplayTitle
                                        if count == 1 {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_UserMessageForwardHidden(displayName).string
                                            } else {
                                                return strings.Conversation_ForwardOptions_UserMessageForwardVisible(displayName).string
                                            }
                                        } else {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_UserMessagesForwardHidden(displayName).string
                                            } else {
                                                return strings.Conversation_ForwardOptions_UserMessagesForwardVisible(displayName).string
                                            }
                                        }
                                    } else if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                        if count == 1 {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_ChannelMessageForwardHidden
                                            } else {
                                                return strings.Conversation_ForwardOptions_ChannelMessageForwardVisible
                                            }
                                        } else {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_ChannelMessagesForwardHidden
                                            } else {
                                                return strings.Conversation_ForwardOptions_ChannelMessagesForwardVisible
                                            }
                                        }
                                    } else {
                                        if count == 1 {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_GroupMessageForwardHidden
                                            } else {
                                                return strings.Conversation_ForwardOptions_GroupMessageForwardVisible
                                            }
                                        } else {
                                            if options.hideNames {
                                                return strings.Conversation_ForwardOptions_GroupMessagesForwardHidden
                                            } else {
                                                return strings.Conversation_ForwardOptions_GroupMessagesForwardVisible
                                            }
                                        }
                                    }
                                } else {
                                    if count == 1 {
                                        if options.hideNames {
                                            return strings.Conversation_ForwardOptions_RecipientsMessageForwardHidden
                                        } else {
                                            return strings.Conversation_ForwardOptions_RecipientsMessageForwardVisible
                                        }
                                    } else {
                                        if options.hideNames {
                                            return strings.Conversation_ForwardOptions_RecipientsMessagesForwardHidden
                                        } else {
                                            return strings.Conversation_ForwardOptions_RecipientsMessagesForwardVisible
                                        }
                                    }
                                }
                            } else {
                                return nil
                            }
                        }
                    case let .reply(reply):
                        subtitleTextSignal = reply.selectionState.get()
                        |> map { selectionState -> String? in
                            if !selectionState.canQuote {
                                return nil
                            }
                            return strings.Chat_SubtitleQuoteSelectionTip
                        }
                    case let .link(link):
                        subtitleTextSignal = link.options
                        |> map { options -> String? in
                            if options.hasAlternativeLinks {
                                return strings.Chat_SubtitleLinkListTip
                            } else {
                                return nil
                            }
                        }
                        |> distinctUntilChanged
                    }
                }
                
                let hasPeerInfo: Signal<Bool, NoError>
                if peerId == context.account.peerId {
                    hasPeerInfo = .single(true)
                    |> then(
                        hasAvailablePeerInfoMediaPanes(context: context, peerId: peerId)
                    )
                } else {
                    hasPeerInfo = .single(true)
                }
                
                enum MessageOptionsTitleInfo {
                    case reply(hasQuote: Bool)
                }
                let messageOptionsTitleInfo: Signal<MessageOptionsTitleInfo?, NoError>
                if case let .messageOptions(_, _, info) = initialSubject {
                    switch info {
                    case .forward, .link:
                        messageOptionsTitleInfo = .single(nil)
                    case let .reply(reply):
                        messageOptionsTitleInfo = reply.selectionState.get()
                        |> map { selectionState -> Bool in
                            return selectionState.quote != nil
                        }
                        |> distinctUntilChanged
                        |> map { hasQuote -> MessageOptionsTitleInfo in
                            return .reply(hasQuote: hasQuote)
                        }
                    }
                } else {
                    messageOptionsTitleInfo = .single(nil)
                }
                
                self.titleDisposable = (combineLatest(
                    queue: Queue.mainQueue(),
                    peerView.get(),
                    onlineMemberCount,
                    displayedCountSignal,
                    subtitleTextSignal,
                    configuration,
                    hasPeerInfo,
                    messageOptionsTitleInfo
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] peerView, onlineMemberCount, displayedCount, subtitleText, configuration, hasPeerInfo, messageOptionsTitleInfo in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let previousState = strongSelf.state
                    
                    var isScheduledMessages = false
                    if case .scheduledMessages = configuration.subject {
                        isScheduledMessages = true
                    }
                    
                    if case let .messageOptions(_, _, info) = configuration.subject {
                        if case .reply = info {
                            let titleContent: ChatTitleContent
                            if case let .reply(hasQuote) = messageOptionsTitleInfo, hasQuote {
                                titleContent = .custom(strings.Chat_TitleQuoteSelection, subtitleText, false)
                            } else {
                                titleContent = .custom(strings.Chat_TitleReply, subtitleText, false)
                            }
                            
                            strongSelf.state.chatTitleContent = titleContent
                        } else if case .link = info {
                            strongSelf.state.chatTitleContent = .custom(strings.Chat_TitleLinkOptions, subtitleText, false)
                        } else if displayedCount == 1 {
                            strongSelf.state.chatTitleContent = .custom(strings.Conversation_ForwardOptions_ForwardTitleSingle, subtitleText, false)
                        } else {
                            strongSelf.state.chatTitleContent = .custom(strings.Conversation_ForwardOptions_ForwardTitle(Int32(displayedCount ?? 1)), subtitleText, false)
                        }
                    } else if let selectionState = configuration.selectionState {
                        if selectionState.selectedIds.count > 0 {
                            strongSelf.state.chatTitleContent = .custom(strings.Conversation_SelectedMessages(Int32(selectionState.selectedIds.count)), nil, false)
                        } else {
                            if let reportReason = configuration.reportReason {
                                strongSelf.state.chatTitleContent = .custom(reportReason.title, strings.Conversation_SelectMessages, false)
                            } else {
                                strongSelf.state.chatTitleContent = .custom(strings.Conversation_SelectMessages, nil, false)
                            }
                        }
                    } else if let peer = peerViewMainPeer(peerView) {
                        if case .pinnedMessages = configuration.subject {
                            strongSelf.state.chatTitleContent = .custom(strings.Chat_TitlePinnedMessages(Int32(displayedCount ?? 1)), nil, false)
                        } else if let channel = peer as? TelegramChannel, channel.isMonoForum {
                            if let linkedMonoforumId = channel.linkedMonoforumId, let mainPeer = peerView.peers[linkedMonoforumId] {
                                strongSelf.state.chatTitleContent = .peer(peerView: ChatTitleContent.PeerData(
                                    peerId: mainPeer.id,
                                    peer: mainPeer,
                                    isContact: false,
                                    isSavedMessages: false,
                                    notificationSettings: nil,
                                    peerPresences: [:],
                                    cachedData: nil
                                ), customTitle: nil, customSubtitle: strings.Chat_Monoforum_Subtitle, onlineMemberCount: (nil, nil), isScheduledMessages: false, isMuted: nil, customMessageCount: nil, isEnabled: true)
                            } else {
                                strongSelf.state.chatTitleContent = .custom(channel.debugDisplayTitle, nil, true)
                            }
                        } else {
                            strongSelf.state.chatTitleContent = .peer(peerView: ChatTitleContent.PeerData(peerView: peerView), customTitle: nil, customSubtitle: nil, onlineMemberCount: onlineMemberCount, isScheduledMessages: isScheduledMessages, isMuted: nil, customMessageCount: nil, isEnabled: hasPeerInfo)
                            
                            let imageOverride: AvatarNodeImageOverride?
                            if context.account.peerId == peer.id {
                                imageOverride = .savedMessagesIcon
                            } else if peer.id.isReplies {
                                imageOverride = .repliesIcon
                            } else if peer.id.isAnonymousSavedMessages {
                                imageOverride = .anonymousSavedMessagesIcon(isColored: true)
                            } else if peer.isDeleted {
                                imageOverride = .deletedIcon
                            } else {
                                imageOverride = nil
                            }
                            
                            let infoContextActionIsEnabled: Bool
                            if case .standard(.previewing) = mode {
                                infoContextActionIsEnabled = false
                            } else {
                                infoContextActionIsEnabled = peer.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) == nil
                            }
                            
                            strongSelf.state.infoAvatar = .peer(
                                peer: EnginePeer(peer),
                                imageOverride: imageOverride,
                                contextActionIsEnabled: infoContextActionIsEnabled,
                                accessibilityLabel: strings.Conversation_ContextMenuOpenProfile
                            )
                            
                            strongSelf.state.storyStats = peerView.storyStats
                        }
                    }
                    
                    strongSelf.isPeerInfoReady.set(true)
                    strongSelf.onUpdated?(previousState)
                })
                
                let threadInfo: Signal<EngineMessageHistoryThread.Info?, NoError>
                if let threadId = chatLocation.threadId {
                    let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: threadId)
                    threadInfo = context.account.postbox.combinedView(keys: [viewKey])
                    |> map { views -> EngineMessageHistoryThread.Info? in
                        guard let view = views.views[viewKey] as? MessageHistoryThreadInfoView else {
                            return nil
                        }
                        guard let data = view.info?.data.get(MessageHistoryThreadData.self) else {
                            return nil
                        }
                        return data.info
                    }
                    |> distinctUntilChanged
                } else {
                    threadInfo = .single(nil)
                }
                
                let hasSearchTags: Signal<Bool, NoError>
                if let peerId = chatLocation.peerId, peerId == context.account.peerId {
                    hasSearchTags = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: chatLocation.threadId)
                    )
                    |> map { tags -> Bool in
                        return !tags.isEmpty
                    }
                    |> distinctUntilChanged
                } else {
                    hasSearchTags = .single(false)
                }
                
                let hasSavedChats: Signal<Bool, NoError>
                if case .peer(context.account.peerId) = chatLocation {
                    hasSavedChats = context.engine.messages.savedMessagesHasPeersOtherThanSaved()
                } else {
                    hasSavedChats = .single(false)
                }
                
                let isPremiumRequiredForMessaging: Signal<Bool, NoError>
                if let peerId = chatLocation.peerId {
                    isPremiumRequiredForMessaging = context.engine.peers.subscribeIsPremiumRequiredForMessaging(id: peerId)
                    |> distinctUntilChanged
                } else {
                    isPremiumRequiredForMessaging = .single(false)
                }
                
                let adMessage: Signal<Message?, NoError>
                if let adMessagesContext {
                    adMessage = adMessagesContext.state |> map { $0.messages.first }
                } else {
                    adMessage = .single(nil)
                }
                
                let displayedPeerVerification: Signal<Bool, NoError>
                if let peerId = chatLocation.peerId {
                    displayedPeerVerification = ApplicationSpecificNotice.displayedPeerVerification(accountManager: context.sharedContext.accountManager, peerId: peerId)
                    |> take(1)
                } else {
                    displayedPeerVerification = .single(false)
                }
                
                let globalPrivacySettings = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.GlobalPrivacy())

                self.peerDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    peerView.get(),
                    context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global()),
                    onlineMemberCount,
                    hasScheduledMessages,
                    displayedCountSignal,
                    threadInfo,
                    hasSearchTags,
                    hasSavedChats,
                    isPremiumRequiredForMessaging,
                    managingBot,
                    adMessage,
                    displayedPeerVerification,
                    globalPrivacySettings
                ).startStrict(next: { [weak self] peerView, globalNotificationSettings, onlineMemberCount, hasScheduledMessages, pinnedCount, threadInfo, hasSearchTags, hasSavedChats, isPremiumRequiredForMessaging, managingBot, adMessage, displayedPeerVerification, globalPrivacySettings in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let previousState = strongSelf.state
                    
                    if strongSelf.state.peerView === peerView
                        && strongSelf.state.hasScheduledMessages == hasScheduledMessages
                        && strongSelf.state.threadInfo == threadInfo
                        && strongSelf.state.hasSearchTags == hasSearchTags
                        && strongSelf.state.hasSavedChats == hasSavedChats
                        && strongSelf.state.isPremiumRequiredForMessaging == isPremiumRequiredForMessaging
                        && managingBot == strongSelf.state.contactStatus?.managingBot
                        && adMessage?.id == strongSelf.state.adMessage?.id {
                        return
                    }
                    
                    strongSelf.state.hasScheduledMessages = hasScheduledMessages
                    
                    var upgradedToPeerId: PeerId?
                    var movedToForumTopics = false
                    if let previous = strongSelf.state.peerView, let group = previous.peers[previous.peerId] as? TelegramGroup, group.migrationReference == nil, let updatedGroup = peerView.peers[peerView.peerId] as? TelegramGroup, let migrationReference = updatedGroup.migrationReference {
                        upgradedToPeerId = migrationReference.peerId
                    }
                    if let previous = strongSelf.state.peerView, let channel = previous.peers[previous.peerId] as? TelegramChannel, !channel.isForumOrMonoForum, let updatedChannel = peerView.peers[peerView.peerId] as? TelegramChannel, updatedChannel.isForumOrMonoForum {
                        if updatedChannel.isForum && updatedChannel.flags.contains(.displayForumAsTabs) {
                        } else {
                            movedToForumTopics = true
                        }
                    }
                    
                    var shouldDismiss = false
                    if let previous = strongSelf.state.peerView, let group = previous.peers[previous.peerId] as? TelegramGroup, group.membership != .Removed, let updatedGroup = peerView.peers[peerView.peerId] as? TelegramGroup, updatedGroup.membership == .Removed {
                        shouldDismiss = true
                    } else if let previous = strongSelf.state.peerView, let channel = previous.peers[previous.peerId] as? TelegramChannel, channel.participationStatus != .kicked, let updatedChannel = peerView.peers[peerView.peerId] as? TelegramChannel, updatedChannel.participationStatus == .kicked {
                        shouldDismiss = true
                    } else if let previous = strongSelf.state.peerView, let secretChat = previous.peers[previous.peerId] as? TelegramSecretChat, case .active = secretChat.embeddedState, let updatedSecretChat = peerView.peers[peerView.peerId] as? TelegramSecretChat, case .terminated = updatedSecretChat.embeddedState {
                        shouldDismiss = true
                    }
                    
                    var wasGroupChannel: Bool?
                    if let previousPeerView = strongSelf.state.peerView, let info = (previousPeerView.peers[previousPeerView.peerId] as? TelegramChannel)?.info {
                        if case .group = info {
                            wasGroupChannel = true
                        } else {
                            wasGroupChannel = false
                        }
                    }
                    var isGroupChannel: Bool?
                    if let info = (peerView.peers[peerView.peerId] as? TelegramChannel)?.info {
                        if case .group = info {
                            isGroupChannel = true
                        } else {
                            isGroupChannel = false
                        }
                    }
                    let firstTime = strongSelf.state.peerView == nil
                    strongSelf.state.peerView = peerView
                    strongSelf.state.threadInfo = threadInfo
                    if wasGroupChannel != isGroupChannel {
                        if let isGroupChannel = isGroupChannel, isGroupChannel {
                            let (recentDisposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                            let (adminsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                            let disposable = DisposableSet()
                            disposable.add(recentDisposable)
                            disposable.add(adminsDisposable)
                            strongSelf.chatAdditionalDataDisposable.set(disposable)
                        } else {
                            strongSelf.chatAdditionalDataDisposable.set(nil)
                        }
                    }
                    
                    var peerIsMuted = false
                    if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                        if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                            peerIsMuted = true
                        } else if case .default = notificationSettings.muteState {
                            if let peer = peerView.peers[peerView.peerId] {
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
                    var starGiftsAvailable = false
                    var peerDiscussionId: PeerId?
                    var peerMonoforumId: PeerId?
                    var peerGeoLocation: PeerGeoLocation?
                    if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, let cachedData = peerView.cachedData as? CachedChannelData {
                        if case .broadcast = peer.info {
                            starGiftsAvailable = cachedData.flags.contains(.starGiftsAvailable)
                        } else {
                            peerGeoLocation = cachedData.peerGeoLocation
                        }
                        if case let .known(value) = cachedData.linkedDiscussionPeerId {
                            peerDiscussionId = value
                        }
                        if !peer.isMonoForum {
                            peerMonoforumId = peer.linkedMonoforumId
                        }
                    }
                    var renderedPeer: RenderedPeer?
                    var contactStatus: ChatContactStatus?
                    var businessIntro: TelegramBusinessIntro?
                    var sendPaidMessageStars: StarsAmount?
                    var alwaysShowGiftButton = false
                    var disallowedGifts: TelegramDisallowedGifts?
                    if let peer = peerView.peers[peerView.peerId] {
                        if let cachedData = peerView.cachedData as? CachedUserData {
                            contactStatus = ChatContactStatus(canAddContact: !peerView.peerIsContact, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: nil, managingBot: managingBot)
                            if case let .known(value) = cachedData.businessIntro {
                                businessIntro = value
                            }
                            if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                            } else {
                                sendPaidMessageStars = cachedData.sendPaidMessageStars
                                if cachedData.disallowedGifts != .All {
                                    alwaysShowGiftButton = globalPrivacySettings.displayGiftButton || cachedData.flags.contains(.displayGiftButton)
                                }
                                disallowedGifts = cachedData.disallowedGifts
                            }
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            var invitedBy: Peer?
                            if let invitedByPeerId = cachedData.invitedBy {
                                if let peer = peerView.peers[invitedByPeerId] {
                                    invitedBy = peer
                                }
                            }
                            contactStatus = ChatContactStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy, managingBot: managingBot)
                        } else if let cachedData = peerView.cachedData as? CachedChannelData {
                            var invitedBy: Peer?
                            if let invitedByPeerId = cachedData.invitedBy {
                                if let peer = peerView.peers[invitedByPeerId] {
                                    invitedBy = peer
                                }
                            }
                            contactStatus = ChatContactStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy, managingBot: managingBot)
                            
                            if let channel = peerView.peers[peerView.peerId] as? TelegramChannel {
                                if channel.isMonoForum {
                                    if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    } else if let sendPaidMessageStarsValue = cachedData.sendPaidMessageStars, sendPaidMessageStarsValue == .zero {
                                        sendPaidMessageStars = nil
                                    } else {
                                        sendPaidMessageStars = channel.sendPaidMessageStars
                                    }
                                } else {
                                    if channel.flags.contains(.isCreator) || channel.adminRights != nil {
                                    } else {
                                        if let personalSendPaidMessageStars = cachedData.sendPaidMessageStars {
                                            if personalSendPaidMessageStars == .zero {
                                                sendPaidMessageStars = nil
                                            } else {
                                                sendPaidMessageStars = personalSendPaidMessageStars
                                            }
                                        } else {
                                            sendPaidMessageStars = channel.sendPaidMessageStars
                                        }
                                    }
                                }
                            }
                        }
                        
                        var peers = SimpleDictionary<PeerId, Peer>()
                        peers[peer.id] = peer
                        if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                            peers[associatedPeer.id] = associatedPeer
                        }
                        renderedPeer = RenderedPeer(peerId: peer.id, peers: peers, associatedMedia: peerView.media)
                    }
                    
                    var isNotAccessible: Bool = false
                    if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                        isNotAccessible = cachedChannelData.isNotAccessible
                    }
                    
                    if firstTime && isNotAccessible {
                        context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerView.peerId)
                    }
                    
                    var hasBots: Bool = false
                    var hasBotCommands: Bool = false
                    var botMenuButton: BotMenuButton = .commands
                    var currentSendAsPeerId: PeerId?
                    var autoremoveTimeout: Int32?
                    var copyProtectionEnabled: Bool = false
                    var hasBirthdayToday = false
                    var peerVerification: PeerVerification?
                    if let peer = peerView.peers[peerView.peerId] {
                        if !displayedPeerVerification {
                            if let cachedUserData = peerView.cachedData as? CachedUserData {
                                peerVerification = cachedUserData.verification
                            } else if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                                peerVerification = cachedChannelData.verification
                            }
                        }
                        copyProtectionEnabled = peer.isCopyProtectionEnabled
                        if let cachedGroupData = peerView.cachedData as? CachedGroupData {
                            if !cachedGroupData.botInfos.isEmpty {
                                hasBots = true
                            }
                            let botCommands = cachedGroupData.botInfos.reduce(into: [], { result, info in
                                result.append(contentsOf: info.botInfo.commands)
                            })
                            if !botCommands.isEmpty {
                                hasBotCommands = true
                            }
                            if case let .known(value) = cachedGroupData.autoremoveTimeout {
                                autoremoveTimeout = value?.effectiveValue
                            }
                        } else if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                            if let channel = peer as? TelegramChannel, channel.isMonoForum {
                                if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    currentSendAsPeerId = channel.linkedMonoforumId
                                } else {
                                    currentSendAsPeerId = nil
                                }
                            } else {
                                currentSendAsPeerId = cachedChannelData.sendAsPeerId
                                if let channel = peer as? TelegramChannel, case .group = channel.info {
                                    if !cachedChannelData.botInfos.isEmpty {
                                        hasBots = true
                                    }
                                    let botCommands = cachedChannelData.botInfos.reduce(into: [], { result, info in
                                        result.append(contentsOf: info.botInfo.commands)
                                    })
                                    if !botCommands.isEmpty {
                                        hasBotCommands = true
                                    }
                                }
                            }
                            if case let .known(value) = cachedChannelData.autoremoveTimeout {
                                autoremoveTimeout = value?.effectiveValue
                            }
                        } else if let cachedUserData = peerView.cachedData as? CachedUserData {
                            botMenuButton = cachedUserData.botInfo?.menuButton ?? .commands
                            if case let .known(value) = cachedUserData.autoremoveTimeout {
                                autoremoveTimeout = value?.effectiveValue
                            }
                            if let botInfo = cachedUserData.botInfo, !botInfo.commands.isEmpty {
                                hasBotCommands = true
                            }
                            if let birthday = cachedUserData.birthday {
                                let today = Calendar.current.dateComponents(Set([.day, .month]), from: Date())
                                if today.day == Int(birthday.day) && today.month == Int(birthday.month) {
                                    hasBirthdayToday = true
                                }
                            }
                        }
                    }
                    
                    let isArchived: Bool = peerView.groupId == Namespaces.PeerGroup.archive
                    
                    var explicitelyCanPinMessages: Bool = false
                    if let cachedUserData = peerView.cachedData as? CachedUserData {
                        explicitelyCanPinMessages = cachedUserData.canPinMessages
                    } else if peerView.peerId == context.account.peerId {
                        explicitelyCanPinMessages = true
                    }
                    
                    #if DEBUG
                    peerMonoforumId = nil
                    #endif
                    
                    let preloadHistoryPeerId = peerMonoforumId ?? peerDiscussionId
                    if strongSelf.preloadHistoryPeerId != preloadHistoryPeerId {
                        strongSelf.preloadHistoryPeerId = preloadHistoryPeerId
                        if let preloadHistoryPeerId, let channel = peerView.peers[peerView.peerId] as? TelegramChannel, case .broadcast = channel.info {
                            let combinedDisposable = DisposableSet()
                            strongSelf.preloadHistoryPeerIdDisposable.set(combinedDisposable)
                            combinedDisposable.add(context.account.viewTracker.polledChannel(peerId: preloadHistoryPeerId).startStrict())
                            combinedDisposable.add(context.account.addAdditionalPreloadHistoryPeerId(peerId: preloadHistoryPeerId))
                        } else {
                            strongSelf.preloadHistoryPeerIdDisposable.set(nil)
                        }
                    }
                    
                    var appliedBoosts: Int32?
                    var boostsToUnrestrict: Int32?
                    if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                        appliedBoosts = cachedChannelData.appliedBoosts
                        boostsToUnrestrict = cachedChannelData.boostsToUnrestrict
                    }
                    
                    if strongSelf.premiumOrStarsRequiredDisposable == nil, sendPaidMessageStars != nil, let peerId = chatLocation.peerId {
                        strongSelf.premiumOrStarsRequiredDisposable = ((context.engine.peers.isPremiumRequiredToContact([peerId]) |> then(.complete() |> suspendAwareDelay(60.0, queue: Queue.concurrentDefaultQueue()))) |> restart).startStandalone()
                    }
                    
                    var adMessage = adMessage
                    if let peer = peerView.peers[peerView.peerId] as? TelegramUser, peer.botInfo != nil {
                    } else {
                        adMessage = nil
                    }
                    
                    strongSelf.state.isNotAccessible = isNotAccessible
                    strongSelf.state.contactStatus = contactStatus
                    strongSelf.state.hasBots = hasBots
                    strongSelf.state.hasBotCommands = hasBotCommands
                    strongSelf.state.botMenuButton = botMenuButton
                    strongSelf.state.isArchived = isArchived
                    strongSelf.state.peerIsMuted = peerIsMuted
                    strongSelf.state.peerDiscussionId = peerDiscussionId
                    strongSelf.state.peerGeoLocation = peerGeoLocation
                    strongSelf.state.explicitelyCanPinMessages = explicitelyCanPinMessages
                    strongSelf.state.hasScheduledMessages = hasScheduledMessages
                    strongSelf.state.autoremoveTimeout = autoremoveTimeout
                    strongSelf.state.currentSendAsPeerId = currentSendAsPeerId
                    strongSelf.state.copyProtectionEnabled = copyProtectionEnabled
                    strongSelf.state.hasSearchTags = hasSearchTags
                    strongSelf.state.isPremiumRequiredForMessaging = isPremiumRequiredForMessaging
                    strongSelf.state.sendPaidMessageStars = sendPaidMessageStars
                    strongSelf.state.alwaysShowGiftButton = alwaysShowGiftButton
                    strongSelf.state.disallowedGifts = disallowedGifts
                    strongSelf.state.hasSavedChats = hasSavedChats
                    strongSelf.state.appliedBoosts = appliedBoosts
                    strongSelf.state.boostsToUnrestrict = boostsToUnrestrict
                    strongSelf.state.hasBirthdayToday = hasBirthdayToday
                    strongSelf.state.businessIntro = businessIntro
                    strongSelf.state.adMessage = adMessage
                    strongSelf.state.peerVerification = peerVerification
                    strongSelf.state.starGiftsAvailable = starGiftsAvailable
                    
                    strongSelf.state.renderedPeer = renderedPeer
                    strongSelf.state.adMessage = adMessage

                    if case .standard(.default) = mode, let channel = renderedPeer?.chatMainPeer as? TelegramChannel, case .broadcast = channel.info {
                        var isRegularChat = false
                        if let subject = initialSubject {
                            if case .message = subject {
                                isRegularChat = true
                            }
                        } else {
                            isRegularChat = true
                        }
                        if strongSelf.nextChannelToReadDisposable == nil, let peerId = chatLocation.peerId, let customChatNavigationStack {
                            if let index = customChatNavigationStack.firstIndex(of: peerId), index != customChatNavigationStack.count - 1 {
                                let nextPeerId = customChatNavigationStack[index + 1]
                                strongSelf.nextChannelToReadDisposable = (combineLatest(queue: .mainQueue(),
                                    context.engine.data.subscribe(
                                        TelegramEngine.EngineData.Item.Peer.Peer(id: nextPeerId)
                                    ),
                                    ApplicationSpecificNotice.getNextChatSuggestionTip(accountManager: context.sharedContext.accountManager)
                                )
                                |> then(.complete() |> delay(1.0, queue: .mainQueue()))
                                |> restart).startStrict(next: { [weak strongSelf] nextPeer, nextChatSuggestionTip in
                                    guard let strongSelf else {
                                        return
                                    }
                                    
                                    let previousState = strongSelf.state

                                    var isUpdated = false
                                    
                                    if !strongSelf.state.offerNextChannelToRead {
                                        strongSelf.state.offerNextChannelToRead = true
                                        isUpdated = true
                                    }
                                    let nextChannelToRead = nextPeer.flatMap { nextPeer -> NextChannelToRead in
                                        return NextChannelToRead(peer: nextPeer, threadData: nil, unreadCount: 0, location: .same)
                                    }
                                    if strongSelf.state.nextChannelToRead != nextChannelToRead {
                                        strongSelf.state.nextChannelToRead = nextChannelToRead
                                        isUpdated = true
                                    }
                                    if strongSelf.state.nextChannelToReadDisplayName != (nextChatSuggestionTip >= 3) {
                                        strongSelf.state.nextChannelToReadDisplayName = nextChatSuggestionTip >= 3
                                        isUpdated = true
                                    }

                                    let nextPeerId = nextPeer?.id

                                    if strongSelf.preloadNextChatPeerId != nextPeerId {
                                        strongSelf.preloadNextChatPeerId = nextPeerId
                                        if let nextPeerId = nextPeerId {
                                            let combinedDisposable = DisposableSet()
                                            strongSelf.preloadNextChatPeerIdDisposable.set(combinedDisposable)
                                            combinedDisposable.add(context.account.viewTracker.polledChannel(peerId: nextPeerId).startStrict())
                                            combinedDisposable.add(context.account.addAdditionalPreloadHistoryPeerId(peerId: nextPeerId))
                                        } else {
                                            strongSelf.preloadNextChatPeerIdDisposable.set(nil)
                                        }
                                    }
                                    
                                    if isUpdated {
                                        strongSelf.onUpdated?(previousState)
                                    }
                                })
                            }
                        } else if isRegularChat, strongSelf.nextChannelToReadDisposable == nil {
                            //TODO:loc optimize
                            let accountPeerId = context.account.peerId
                            strongSelf.nextChannelToReadDisposable = (combineLatest(queue: .mainQueue(),
                                context.engine.peers.getNextUnreadChannel(peerId: channel.id, chatListFilterId: currentChatListFilter, getFilterPredicate: { data in
                                    return chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
                                }),
                                ApplicationSpecificNotice.getNextChatSuggestionTip(accountManager: context.sharedContext.accountManager)
                            )
                            |> then(.complete() |> delay(1.0, queue: .mainQueue()))
                            |> restart).startStrict(next: { [weak strongSelf] nextPeer, nextChatSuggestionTip in
                                guard let strongSelf else {
                                    return
                                }
                                
                                let previousState = strongSelf.state

                                var isUpdated = false
                                
                                if !strongSelf.state.offerNextChannelToRead {
                                    strongSelf.state.offerNextChannelToRead = true
                                    isUpdated = true
                                }
                                let nextChannelToRead = nextPeer.flatMap { nextPeer -> NextChannelToRead in
                                    return NextChannelToRead(peer: nextPeer.peer, threadData: nil, unreadCount: nextPeer.unreadCount, location: nextPeer.location)
                                }
                                if strongSelf.state.nextChannelToRead != nextChannelToRead {
                                    strongSelf.state.nextChannelToRead = nextChannelToRead
                                    isUpdated = true
                                }
                                if strongSelf.state.nextChannelToReadDisplayName != (nextChatSuggestionTip >= 3) {
                                    strongSelf.state.nextChannelToReadDisplayName = nextChatSuggestionTip >= 3
                                    isUpdated = true
                                }

                                let nextPeerId = nextPeer?.peer.id

                                if strongSelf.preloadNextChatPeerId != nextPeerId {
                                    strongSelf.preloadNextChatPeerId = nextPeerId
                                    if let nextPeerId = nextPeerId {
                                        let combinedDisposable = DisposableSet()
                                        strongSelf.preloadNextChatPeerIdDisposable.set(combinedDisposable)
                                        combinedDisposable.add(context.account.viewTracker.polledChannel(peerId: nextPeerId).startStrict())
                                        combinedDisposable.add(context.account.addAdditionalPreloadHistoryPeerId(peerId: nextPeerId))
                                    } else {
                                        strongSelf.preloadNextChatPeerIdDisposable.set(nil)
                                    }
                                }
                                
                                if isUpdated {
                                    strongSelf.onUpdated?(previousState)
                                }
                            })
                        }
                    }
                    
                    if let upgradedToPeerId {
                        strongSelf.state.performDismissAction = .upgraded(upgradedToPeerId)
                    } else if movedToForumTopics {
                        strongSelf.state.performDismissAction = .movedToForumTopics
                    } else if shouldDismiss {
                        strongSelf.state.performDismissAction = .dismiss
                    }
                    
                    strongSelf.isChatLocationInfoReady.set(true)
                    strongSelf.onUpdated?(previousState)
                })
                
                if peerId == context.account.peerId {
                    self.preloadSavedMessagesChatsDisposable?.dispose()
                    self.preloadSavedMessagesChatsDisposable = context.engine.messages.savedMessagesPeerListHead().start()
                }
            } else if case let .replyThread(messagePromise) = self.chatLocationInfoData, let peerId = peerId {
                self.isPeerInfoReady.set(true)
                
                let replyThreadType: ChatTitleContent.ReplyThreadType
                var replyThreadId: Int64?
                switch chatLocation {
                case .peer:
                    replyThreadType = .replies
                case let .replyThread(replyThreadMessage):
                    if replyThreadMessage.peerId == context.account.peerId {
                        replyThreadId = replyThreadMessage.threadId
                        replyThreadType = .replies
                    } else {
                        replyThreadId = replyThreadMessage.threadId
                        if replyThreadMessage.isChannelPost {
                            replyThreadType = .comments
                        } else {
                            replyThreadType = .replies
                        }
                    }
                case .customChatContents:
                    replyThreadType = .replies
                }
                
                let peerView = context.account.viewTracker.peerView(peerId)
                
                let messageAndTopic = messagePromise.get()
                |> mapToSignal { message -> Signal<(message: Message?, threadData: MessageHistoryThreadData?, messageCount: Int), NoError> in
                    guard let replyThreadId = replyThreadId else {
                        return .single((message, nil, 0))
                    }
                    let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: replyThreadId)
                    let countViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: replyThreadId, namespace: Namespaces.Message.Cloud, customTag: nil)
                    let localCountViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: replyThreadId, namespace: Namespaces.Message.Local, customTag: nil)
                    return context.account.postbox.combinedView(keys: [viewKey, countViewKey, localCountViewKey])
                    |> map { views -> (message: Message?, threadData: MessageHistoryThreadData?, messageCount: Int) in
                        guard let view = views.views[viewKey] as? MessageHistoryThreadInfoView else {
                            return (message, nil, 0)
                        }
                        var messageCount = 0
                        if let summaryView = views.views[countViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                            if replyThreadId == 1 {
                                messageCount += Int(count)
                            } else {
                                messageCount += max(Int(count) - 1, 0)
                            }
                        }
                        if let summaryView = views.views[localCountViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                            messageCount += Int(count)
                        }
                        return (message, view.info?.data.get(MessageHistoryThreadData.self), messageCount)
                    }
                }
                
                let savedMessagesPeerId: PeerId?
                if case let .replyThread(replyThreadMessage) = chatLocation, (replyThreadMessage.peerId == context.account.peerId || replyThreadMessage.isMonoforumPost) {
                    savedMessagesPeerId = PeerId(replyThreadMessage.threadId)
                } else {
                    savedMessagesPeerId = nil
                }
                
                let savedMessagesPeer: Signal<(peer: EnginePeer?, messageCount: Int, presence: EnginePeer.Presence?, isMonoforumFeeRemoved: Bool)?, NoError>
                if let savedMessagesPeerId {
                    let threadPeerId = savedMessagesPeerId
                    let basicPeerKey: PostboxViewKey = .peer(peerId: threadPeerId, components: [])
                    let countViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: savedMessagesPeerId.toInt64(), namespace: Namespaces.Message.Cloud, customTag: nil)
                    let threadInfoKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: savedMessagesPeerId.toInt64())
                    
                    savedMessagesPeer = context.account.postbox.combinedView(keys: [basicPeerKey, countViewKey, threadInfoKey])
                    |> map { views -> (peer: EnginePeer?, messageCount: Int, presence: EnginePeer.Presence?, isMonoforumFeeRemoved: Bool)? in
                        var peer: EnginePeer?
                        var presence: EnginePeer.Presence?
                        if let peerView = views.views[basicPeerKey] as? PeerView {
                            peer = peerViewMainPeer(peerView).flatMap(EnginePeer.init)
                            presence = peerView.peerPresences[threadPeerId].flatMap(EnginePeer.Presence.init)
                        }
                        
                        var messageCount = 0
                        if let summaryView = views.views[countViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                            messageCount += Int(count)
                        }
                        
                        var isMonoforumFeeRemoved = false
                        if let threadInfoView = views.views[threadInfoKey] as? MessageHistoryThreadInfoView, let threadInfo = threadInfoView.info?.data.get(MessageHistoryThreadData.self) {
                            isMonoforumFeeRemoved = threadInfo.isMessageFeeRemoved
                        }
                        
                        return (peer, messageCount, presence, isMonoforumFeeRemoved)
                    }
                    |> distinctUntilChanged(isEqual: { lhs, rhs in
                        if lhs?.peer != rhs?.peer {
                            return false
                        }
                        if lhs?.messageCount != rhs?.messageCount {
                            return false
                        }
                        if lhs?.presence != rhs?.presence {
                            return false
                        }
                        if lhs?.isMonoforumFeeRemoved != rhs?.isMonoforumFeeRemoved {
                            return false
                        }
                        return true
                    })
                } else {
                    savedMessagesPeer = .single(nil)
                }
                
                var isScheduledOrPinnedMessages = false
                switch initialSubject {
                case .scheduledMessages, .pinnedMessages, .messageOptions:
                    isScheduledOrPinnedMessages = true
                default:
                    break
                }
                
                var hasScheduledMessages: Signal<Bool, NoError> = .single(false)
                if chatLocation.peerId != nil, !isScheduledOrPinnedMessages, peerId.namespace != Namespaces.Peer.SecretChat {
                    let chatLocationContextHolder = chatLocationContextHolder
                    hasScheduledMessages = peerView
                    |> take(1)
                    |> mapToSignal { view -> Signal<Bool, NoError> in
                        if let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendSomething) {
                            return .single(false)
                        } else {
                            if case let .replyThread(message) = chatLocation, message.peerId == context.account.peerId {
                                return context.account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: .peer(id: context.account.peerId), contextHolder: Atomic(value: nil)))
                                |> map { view, _, _ in
                                    return !view.entries.isEmpty
                                }
                                |> distinctUntilChanged
                            } else {
                                return context.account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder))
                                |> map { view, _, _ in
                                    return !view.entries.isEmpty
                                }
                                |> distinctUntilChanged
                            }
                        }
                    }
                }
                
                var onlineMemberCount: Signal<(total: Int32?, recent: Int32?), NoError> = .single((nil, nil))
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    let recentOnlineSignal: Signal<(total: Int32?, recent: Int32?), NoError> = peerView
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
                    onlineMemberCount = recentOnlineSignal
                }
                
                let hasSearchTags: Signal<Bool, NoError>
                if let peerId = chatLocation.peerId, peerId == context.account.peerId {
                    hasSearchTags = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: chatLocation.threadId)
                    )
                    |> map { tags -> Bool in
                        return !tags.isEmpty
                    }
                    |> distinctUntilChanged
                } else {
                    hasSearchTags = .single(false)
                }
                
                let hasSavedChats: Signal<Bool, NoError>
                if case .peer(context.account.peerId) = chatLocation {
                    hasSavedChats = context.engine.messages.savedMessagesHasPeersOtherThanSaved()
                } else {
                    hasSavedChats = .single(false)
                }
                
                let isPremiumRequiredForMessaging: Signal<Bool, NoError>
                if let peerId = chatLocation.peerId {
                    isPremiumRequiredForMessaging = context.engine.peers.subscribeIsPremiumRequiredForMessaging(id: peerId)
                    |> distinctUntilChanged
                } else {
                    isPremiumRequiredForMessaging = .single(false)
                }
                
                let globalPrivacySettings = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.GlobalPrivacy())
                
                self.peerDisposable = (combineLatest(queue: Queue.mainQueue(),
                    peerView,
                    messageAndTopic,
                    savedMessagesPeer,
                    onlineMemberCount,
                    hasScheduledMessages,
                    hasSearchTags,
                    hasSavedChats,
                    isPremiumRequiredForMessaging,
                    managingBot,
                    globalPrivacySettings
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] peerView, messageAndTopic, savedMessagesPeer, onlineMemberCount, hasScheduledMessages, hasSearchTags, hasSavedChats, isPremiumRequiredForMessaging, managingBot, globalPrivacySettings in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let previousState = strongSelf.state
                        
                    strongSelf.state.hasScheduledMessages = hasScheduledMessages
                        
                    var renderedPeer: RenderedPeer?
                    var contactStatus: ChatContactStatus?
                    var copyProtectionEnabled = false
                    var businessIntro: TelegramBusinessIntro?
                    var sendPaidMessageStars: StarsAmount?
                    var alwaysShowGiftButton = false
                    var disallowedGifts: TelegramDisallowedGifts?
                    if let peer = peerView.peers[peerView.peerId] {
                        copyProtectionEnabled = peer.isCopyProtectionEnabled
                        if let cachedData = peerView.cachedData as? CachedUserData {
                            contactStatus = ChatContactStatus(canAddContact: !peerView.peerIsContact, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: nil, managingBot: managingBot)
                            if case let .known(value) = cachedData.businessIntro {
                                businessIntro = value
                            }
                            if cachedData.disallowedGifts != .All {
                                alwaysShowGiftButton = globalPrivacySettings.displayGiftButton || cachedData.flags.contains(.displayGiftButton)
                            }
                            disallowedGifts = cachedData.disallowedGifts
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            var invitedBy: Peer?
                            if let invitedByPeerId = cachedData.invitedBy {
                                if let peer = peerView.peers[invitedByPeerId] {
                                    invitedBy = peer
                                }
                            }
                            contactStatus = ChatContactStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy, managingBot: managingBot)
                        } else if let cachedData = peerView.cachedData as? CachedChannelData {
                            var invitedBy: Peer?
                            if let invitedByPeerId = cachedData.invitedBy {
                                if let peer = peerView.peers[invitedByPeerId] {
                                    invitedBy = peer
                                }
                            }
                            contactStatus = ChatContactStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy, managingBot: managingBot)
                           
                            if let channel = peerView.peers[peerView.peerId] as? TelegramChannel {
                                if channel.isMonoForum {
                                    if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    } else {
                                        sendPaidMessageStars = channel.sendPaidMessageStars
                                    }
                                } else {
                                    if channel.flags.contains(.isCreator) || channel.adminRights != nil {
                                    } else {
                                        sendPaidMessageStars = channel.sendPaidMessageStars
                                    }
                                }
                            }
                        }
                        
                        var peers = SimpleDictionary<PeerId, Peer>()
                        peers[peer.id] = peer
                        if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                            peers[associatedPeer.id] = associatedPeer
                        }
                        renderedPeer = RenderedPeer(peerId: peer.id, peers: peers, associatedMedia: peerView.media)
                    }
                    
                    if let savedMessagesPeerId {
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        if let presence = savedMessagesPeer?.presence {
                            peerPresences[savedMessagesPeerId] = presence._asPresence()
                        }
                        let mappedPeerData = ChatTitleContent.PeerData(
                            peerId: savedMessagesPeerId,
                            peer: savedMessagesPeer?.peer?._asPeer(),
                            isContact: true,
                            isSavedMessages: true,
                            notificationSettings: nil,
                            peerPresences: peerPresences,
                            cachedData: nil
                        )
                        
                        var customMessageCount: Int?
                        if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, peer.isMonoForum {
                        } else {
                            customMessageCount = savedMessagesPeer?.messageCount ?? 0
                        }
                        
                        strongSelf.state.chatTitleContent = .peer(peerView: mappedPeerData, customTitle: nil, customSubtitle: nil, onlineMemberCount: (nil, nil), isScheduledMessages: false, isMuted: false, customMessageCount: customMessageCount, isEnabled: true)
                        
                        strongSelf.state.peerView = peerView
                        
                        let imageOverride: AvatarNodeImageOverride?
                        if context.account.peerId == savedMessagesPeerId {
                            imageOverride = .myNotesIcon
                        } else if let peer = savedMessagesPeer?.peer, peer.id.isReplies {
                            imageOverride = .repliesIcon
                        } else if let peer = savedMessagesPeer?.peer, peer.id.isAnonymousSavedMessages {
                            imageOverride = .anonymousSavedMessagesIcon(isColored: true)
                        } else if let peer = savedMessagesPeer?.peer, peer.isDeleted {
                            imageOverride = .deletedIcon
                        } else {
                            imageOverride = nil
                        }
                        
                        if let peer = savedMessagesPeer?.peer {
                            var infoContextActionIsEnabled = false
                            if case .standard(.previewing) = mode {
                                infoContextActionIsEnabled = false
                            } else {
                                infoContextActionIsEnabled = true
                            }
                            strongSelf.state.infoAvatar = .peer(
                                peer: peer,
                                imageOverride: imageOverride,
                                contextActionIsEnabled: infoContextActionIsEnabled,
                                accessibilityLabel: strings.Conversation_ContextMenuOpenProfile
                            )
                        }
                        
                        var currentSendAsPeerId: PeerId?
                        if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, let cachedData = peerView.cachedData as? CachedChannelData {
                            if peer.isMonoForum {
                                if let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    currentSendAsPeerId = peer.linkedMonoforumId
                                } else {
                                    currentSendAsPeerId = nil
                                }
                            } else {
                                currentSendAsPeerId = cachedData.sendAsPeerId
                            }
                        }
                        
                        var removePaidMessageFeeData: ChatPresentationInterfaceState.RemovePaidMessageFeeData?
                        if let savedMessagesPeer, !savedMessagesPeer.isMonoforumFeeRemoved, let peer = savedMessagesPeer.peer, let channel = peerView.peers[peerView.peerId] as? TelegramChannel, let sendPaidMessageStars = channel.sendPaidMessageStars, channel.isMonoForum {
                            if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                removePaidMessageFeeData = ChatPresentationInterfaceState.RemovePaidMessageFeeData(
                                    peer: peer,
                                    amount: sendPaidMessageStars
                                )
                            }
                        }
                        
                        strongSelf.state.renderedPeer = renderedPeer
                        strongSelf.state.savedMessagesTopicPeer = savedMessagesPeer?.peer
                        strongSelf.state.hasSearchTags = hasSearchTags
                        strongSelf.state.hasSavedChats = hasSavedChats
                        strongSelf.state.hasScheduledMessages = hasScheduledMessages
                        strongSelf.state.currentSendAsPeerId = currentSendAsPeerId
                        strongSelf.state.removePaidMessageFeeData = removePaidMessageFeeData
                    } else {
                        let message = messageAndTopic.message
                        
                        var count = 0
                        if let message = message {
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyThreadMessageAttribute {
                                    count = Int(attribute.count)
                                    break
                                }
                            }
                        }
                        
                        var peerIsMuted = false
                        if let threadData = messageAndTopic.threadData {
                            if case let .muted(until) = threadData.notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                peerIsMuted = true
                            }
                        } else if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                peerIsMuted = true
                            }
                        }
                        
                        if let threadInfo = messageAndTopic.threadData?.info {
                            strongSelf.state.chatTitleContent = .peer(peerView: ChatTitleContent.PeerData(peerView: peerView), customTitle: threadInfo.title, customSubtitle: nil, onlineMemberCount: onlineMemberCount, isScheduledMessages: false, isMuted: peerIsMuted, customMessageCount: messageAndTopic.messageCount == 0 ? nil : messageAndTopic.messageCount, isEnabled: true)
                            
                            let avatarContent: EmojiStatusComponent.Content
                            if chatLocation.threadId == 1 {
                                avatarContent = .image(image: PresentationResourcesChat.chatGeneralThreadIcon(strongSelf.presentationData.theme), tintColor: nil)
                            } else if let fileId = threadInfo.icon {
                                avatarContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: strongSelf.presentationData.theme.list.mediaPlaceholderColor, themeColor: strongSelf.presentationData.theme.list.itemAccentColor, loopMode: .count(1))
                            } else {
                                avatarContent = .topic(title: String(threadInfo.title.prefix(1)), color: threadInfo.iconColor, size: CGSize(width: 32.0, height: 32.0))
                            }
                            
                            var infoContextActionIsEnabled = false
                            if case .standard(.previewing) = mode {
                                infoContextActionIsEnabled = false
                            } else {
                                infoContextActionIsEnabled = true
                            }
                            strongSelf.state.infoAvatar = .emojiStatus(content: avatarContent, contextActionIsEnabled: infoContextActionIsEnabled)
                        } else {
                            strongSelf.state.chatTitleContent = .replyThread(type: replyThreadType, count: count)
                        }
                        
                        var wasGroupChannel: Bool?
                        if let previousPeerView = strongSelf.state.peerView, let info = (previousPeerView.peers[previousPeerView.peerId] as? TelegramChannel)?.info {
                            if case .group = info {
                                wasGroupChannel = true
                            } else {
                                wasGroupChannel = false
                            }
                        }
                        var isGroupChannel: Bool?
                        if let info = (peerView.peers[peerView.peerId] as? TelegramChannel)?.info {
                            if case .group = info {
                                isGroupChannel = true
                            } else {
                                isGroupChannel = false
                            }
                        }
                        let firstTime = strongSelf.state.peerView == nil
                        
                        if wasGroupChannel != isGroupChannel {
                            if let isGroupChannel = isGroupChannel, isGroupChannel {
                                let (recentDisposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                                let (adminsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                                let disposable = DisposableSet()
                                disposable.add(recentDisposable)
                                disposable.add(adminsDisposable)
                                strongSelf.chatAdditionalDataDisposable.set(disposable)
                            } else {
                                strongSelf.chatAdditionalDataDisposable.set(nil)
                            }
                        }
                        
                        strongSelf.state.peerView = peerView
                        strongSelf.state.threadInfo = messageAndTopic.threadData?.info
                        
                        var peerDiscussionId: PeerId?
                        var peerMonoforumId: PeerId?
                        var peerGeoLocation: PeerGeoLocation?
                        var currentSendAsPeerId: PeerId?
                        if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, let cachedData = peerView.cachedData as? CachedChannelData {
                            if peer.isMonoForum {
                                if let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    currentSendAsPeerId = peer.linkedMonoforumId
                                } else {
                                    currentSendAsPeerId = nil
                                }
                            } else {
                                peerMonoforumId = peer.linkedMonoforumId
                                
                                currentSendAsPeerId = cachedData.sendAsPeerId
                                if case .group = peer.info {
                                    peerGeoLocation = cachedData.peerGeoLocation
                                }
                                if case let .known(value) = cachedData.linkedDiscussionPeerId {
                                    peerDiscussionId = value
                                }
                            }
                        }
                        
                        var isNotAccessible: Bool = false
                        if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                            isNotAccessible = cachedChannelData.isNotAccessible
                        }
                        
                        if firstTime && isNotAccessible {
                            context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerView.peerId)
                        }
                        
                        var hasBots: Bool = false
                        if let peer = peerView.peers[peerView.peerId] {
                            if let cachedGroupData = peerView.cachedData as? CachedGroupData {
                                if !cachedGroupData.botInfos.isEmpty {
                                    hasBots = true
                                }
                            } else if let cachedChannelData = peerView.cachedData as? CachedChannelData, let channel = peer as? TelegramChannel, case .group = channel.info {
                                if !cachedChannelData.botInfos.isEmpty {
                                    hasBots = true
                                }
                            }
                        }
                        
                        let isArchived: Bool = peerView.groupId == Namespaces.PeerGroup.archive
                        
                        var explicitelyCanPinMessages: Bool = false
                        if let cachedUserData = peerView.cachedData as? CachedUserData {
                            explicitelyCanPinMessages = cachedUserData.canPinMessages
                        } else if peerView.peerId == context.account.peerId {
                            explicitelyCanPinMessages = true
                        }
                        
                        #if DEBUG
                        peerMonoforumId = nil
                        #endif
                        
                        let preloadHistoryPeerId = peerMonoforumId ?? peerDiscussionId
                        if strongSelf.preloadHistoryPeerId != preloadHistoryPeerId {
                            strongSelf.preloadHistoryPeerId = preloadHistoryPeerId
                            if let preloadHistoryPeerId {
                                strongSelf.preloadHistoryPeerIdDisposable.set(context.account.addAdditionalPreloadHistoryPeerId(peerId: preloadHistoryPeerId))
                            } else {
                                strongSelf.preloadHistoryPeerIdDisposable.set(nil)
                            }
                        }
                        
                        var appliedBoosts: Int32?
                        var boostsToUnrestrict: Int32?
                        if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                            appliedBoosts = cachedChannelData.appliedBoosts
                            boostsToUnrestrict = cachedChannelData.boostsToUnrestrict
                        }
                        
                        if strongSelf.premiumOrStarsRequiredDisposable == nil, sendPaidMessageStars != nil, let peerId = chatLocation.peerId {
                            strongSelf.premiumOrStarsRequiredDisposable = ((context.engine.peers.isPremiumRequiredToContact([peerId]) |> then(.complete() |> suspendAwareDelay(60.0, queue: Queue.concurrentDefaultQueue()))) |> restart).startStandalone()
                        }
                        
                        strongSelf.state.renderedPeer = renderedPeer
                        strongSelf.state.isNotAccessible = isNotAccessible
                        strongSelf.state.contactStatus = contactStatus
                        strongSelf.state.hasBots = hasBots
                        strongSelf.state.isArchived = isArchived
                        strongSelf.state.peerIsMuted = peerIsMuted
                        strongSelf.state.peerDiscussionId = peerDiscussionId
                        strongSelf.state.peerGeoLocation = peerGeoLocation
                        strongSelf.state.explicitelyCanPinMessages = explicitelyCanPinMessages
                        strongSelf.state.hasScheduledMessages = hasScheduledMessages
                        strongSelf.state.currentSendAsPeerId = currentSendAsPeerId
                        strongSelf.state.copyProtectionEnabled = copyProtectionEnabled
                        strongSelf.state.hasSearchTags = hasSearchTags
                        strongSelf.state.isPremiumRequiredForMessaging = isPremiumRequiredForMessaging
                        strongSelf.state.hasSavedChats = hasSavedChats
                        strongSelf.state.appliedBoosts = appliedBoosts
                        strongSelf.state.boostsToUnrestrict = boostsToUnrestrict
                        strongSelf.state.businessIntro = businessIntro
                        strongSelf.state.sendPaidMessageStars = sendPaidMessageStars
                        strongSelf.state.alwaysShowGiftButton = alwaysShowGiftButton
                        strongSelf.state.disallowedGifts = disallowedGifts
                        
                        if let replyThreadId, let channel = renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum, strongSelf.nextChannelToReadDisposable == nil {
                            strongSelf.nextChannelToReadDisposable = (combineLatest(queue: .mainQueue(),
                            context.engine.peers.getNextUnreadForumTopic(peerId: channel.id, topicId: Int32(clamping: replyThreadId)),
                                ApplicationSpecificNotice.getNextChatSuggestionTip(accountManager: context.sharedContext.accountManager)
                            )
                            |> then(.complete() |> delay(1.0, queue: .mainQueue()))
                            |> restart).startStrict(next: { nextThreadData, nextChatSuggestionTip in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                let previousState = strongSelf.state

                                var isUpdated = false
                                
                                if !strongSelf.state.offerNextChannelToRead {
                                    strongSelf.state.offerNextChannelToRead = true
                                    isUpdated = true
                                }
                                let nextChannelToRead = nextThreadData.flatMap { nextThreadData -> NextChannelToRead in
                                    return NextChannelToRead(peer: EnginePeer(channel), threadData: NextChannelToRead.ThreadData(id: nextThreadData.id, data: nextThreadData.data), unreadCount: Int(nextThreadData.data.incomingUnreadCount), location: .same)
                                }
                                if strongSelf.state.nextChannelToRead != nextChannelToRead {
                                    strongSelf.state.nextChannelToRead = nextChannelToRead
                                    isUpdated = true
                                }
                                if strongSelf.state.nextChannelToReadDisplayName != (nextChatSuggestionTip >= 3) {
                                    strongSelf.state.nextChannelToReadDisplayName = nextChatSuggestionTip >= 3
                                    isUpdated = true
                                }
                                
                                if isUpdated {
                                    strongSelf.onUpdated?(previousState)
                                }
                            })
                        }
                    }
                    
                    strongSelf.isChatLocationInfoReady.set(true)
                    strongSelf.onUpdated?(previousState)
                })
            } else if case .customChatContents = self.chatLocationInfoData {
                self.titleDisposable?.dispose()
                self.titleDisposable = nil
                self.isPeerInfoReady.set(true)
                
                let peerView: Signal<PeerView?, NoError> = .single(nil)
                
                if case let .customChatContents(customChatContents) = initialSubject {
                    switch customChatContents.kind {
                    case .hashTagSearch:
                        break
                    case let .quickReplyMessageInput(shortcut, shortcutType):
                        switch shortcutType {
                        case .generic:
                            self.state.chatTitleContent = .custom("\(shortcut)", nil, false)
                        case .greeting:
                            self.state.chatTitleContent = .custom(strings.QuickReply_TitleGreetingMessage, nil, false)
                        case .away:
                            self.state.chatTitleContent = .custom(strings.QuickReply_TitleAwayMessage, nil, false)
                        }
                    case let .businessLinkSetup(link):
                        let linkUrl: String
                        if link.url.hasPrefix("https://") {
                            linkUrl = String(link.url[link.url.index(link.url.startIndex, offsetBy: "https://".count)...])
                        } else {
                            linkUrl = link.url
                        }
                        
                        self.state.chatTitleContent = .custom(link.title ?? strings.Business_Links_EditLinkTitle, linkUrl, false)
                    }
                } else {
                    self.state.chatTitleContent = .custom(" ", nil, false)
                }
                
                self.peerDisposable = (peerView
                |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
                    guard let self else {
                        return
                    }
                    
                    let previousState = self.state
                        
                    var renderedPeer: RenderedPeer?
                    if let peerView, let peer = peerView.peers[peerView.peerId] {
                        var peers = SimpleDictionary<PeerId, Peer>()
                        peers[peer.id] = peer
                        if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                            peers[associatedPeer.id] = associatedPeer
                        }
                        renderedPeer = RenderedPeer(peerId: peer.id, peers: peers, associatedMedia: peerView.media)
                        
                        self.state.infoAvatar = .peer(
                            peer: EnginePeer(peer),
                            imageOverride: nil,
                            contextActionIsEnabled: false,
                            accessibilityLabel: nil
                        )
                    } else {
                        self.state.infoAvatar = nil
                    }
                
                    self.state.peerView = peerView
                    self.state.renderedPeer = renderedPeer
                    
                    self.isChatLocationInfoReady.set(true)
                    self.onUpdated?(previousState)
                })
            }
            
            let initialData = historyNode.initialData
            |> take(1)
            |> deliverOnMainQueue
            |> beforeNext { [weak self] combinedInitialData in
                guard let strongSelf = self, let combinedInitialData else {
                    return
                }
                
                let previousState = strongSelf.state

                if let opaqueState = (combinedInitialData.initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState) {
                    var interfaceState = ChatInterfaceState.parse(opaqueState)

                    var pinnedMessageId: MessageId?
                    var peerIsBlocked: Bool = false
                    var callsAvailable: Bool = true
                    var callsPrivate: Bool = false
                    var activeGroupCallInfo: ChatActiveGroupCallInfo?
                    var slowmodeState: ChatSlowmodeState?
                    if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        
                        var canBypassRestrictions = false
                        if let boostsToUnrestrict = cachedData.boostsToUnrestrict, let appliedBoosts = cachedData.appliedBoosts, appliedBoosts >= boostsToUnrestrict {
                            canBypassRestrictions = true
                        }
                        if !canBypassRestrictions, let channel = combinedInitialData.initialData?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                            if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                                slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                            }
                        }
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                    } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                        peerIsBlocked = cachedData.isBlocked
                        callsAvailable = cachedData.voiceCallsAvailable
                        callsPrivate = cachedData.callsPrivate
                        pinnedMessageId = cachedData.pinnedMessageId
                    } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                    } else if let _ = combinedInitialData.cachedData as? CachedSecretChatData {
                    }
                    
                    if let channel = combinedInitialData.initialData?.peer as? TelegramChannel {
                        if channel.hasBannedPermission(.banSendVoice) != nil && channel.hasBannedPermission(.banSendInstantVideos) != nil {
                            interfaceState = interfaceState.withUpdatedMediaRecordingMode(.audio)
                        } else if channel.hasBannedPermission(.banSendVoice) != nil {
                            if channel.hasBannedPermission(.banSendInstantVideos) == nil {
                                interfaceState = interfaceState.withUpdatedMediaRecordingMode(.video)
                            }
                        } else if channel.hasBannedPermission(.banSendInstantVideos) != nil {
                            if channel.hasBannedPermission(.banSendVoice) == nil {
                                interfaceState = interfaceState.withUpdatedMediaRecordingMode(.audio)
                            }
                        }
                    } else if let group = combinedInitialData.initialData?.peer as? TelegramGroup {
                        if group.hasBannedPermission(.banSendVoice) && group.hasBannedPermission(.banSendInstantVideos) {
                            interfaceState = interfaceState.withUpdatedMediaRecordingMode(.audio)
                        } else if group.hasBannedPermission(.banSendVoice) {
                            if !group.hasBannedPermission(.banSendInstantVideos) {
                                interfaceState = interfaceState.withUpdatedMediaRecordingMode(.video)
                            }
                        } else if group.hasBannedPermission(.banSendInstantVideos) {
                            if !group.hasBannedPermission(.banSendVoice) {
                                interfaceState = interfaceState.withUpdatedMediaRecordingMode(.audio)
                            }
                        }
                    }
                    
                    if case let .replyThread(replyThreadMessageId) = chatLocation {
                        if let channel = combinedInitialData.initialData?.peer as? TelegramChannel, channel.isForumOrMonoForum {
                            pinnedMessageId = nil
                        } else {
                            pinnedMessageId = replyThreadMessageId.effectiveTopId
                        }
                    }
                    
                    var pinnedMessage: ChatPinnedMessage?
                    if let pinnedMessageId = pinnedMessageId {
                        if let cachedDataMessages = combinedInitialData.cachedDataMessages {
                            if let message = cachedDataMessages[pinnedMessageId] {
                                pinnedMessage = ChatPinnedMessage(message: message, index: 0, totalCount: 1, topMessageId: message.id)
                            }
                        }
                    }
                    
                    var buttonKeyboardMessage = combinedInitialData.buttonKeyboardMessage
                    if let buttonKeyboardMessageValue = buttonKeyboardMessage, buttonKeyboardMessageValue.isRestricted(platform: "ios", contentSettings: context.currentContentSettings.with({ $0 })) {
                        buttonKeyboardMessage = nil
                    }
                    
                    strongSelf.state.pinnedMessageId = pinnedMessageId
                    strongSelf.state.pinnedMessage = pinnedMessage
                    strongSelf.state.keyboardButtonsMessage = buttonKeyboardMessage
                    strongSelf.state.peerIsBlocked = peerIsBlocked
                    strongSelf.state.callsAvailable = callsAvailable
                    strongSelf.state.callsPrivate = callsPrivate
                    strongSelf.state.activeGroupCallInfo = activeGroupCallInfo
                    strongSelf.state.slowmodeState = slowmodeState
                    
                    var initialEditMessage: Message?
                    if let editMessage = interfaceState.editMessage, let message = combinedInitialData.initialData?.associatedMessages[editMessage.messageId] {
                        initialEditMessage = message
                    }
                        
                    strongSelf.initialInterfaceState = (interfaceState, initialEditMessage)
                } else {
                    strongSelf.initialInterfaceState = (ChatInterfaceState(), nil)
                }
                
                if let readStateData = combinedInitialData.readStateData {
                    if case let .peer(peerId) = chatLocation, let peerReadStateData = readStateData[peerId], let notificationSettings = peerReadStateData.notificationSettings {
                        
                        let inAppSettings = context.sharedContext.currentInAppNotificationSettings.with { $0 }
                        let (count, _) = renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: peerReadStateData.totalState ?? ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:]))
                        
                        var globalRemainingUnreadChatCount = count
                        if !notificationSettings.isRemovedFromTotalUnreadCount(default: false) && peerReadStateData.unreadCount > 0 {
                            if case .messages = inAppSettings.totalUnreadCountDisplayCategory {
                                globalRemainingUnreadChatCount -= peerReadStateData.unreadCount
                            } else {
                                globalRemainingUnreadChatCount -= 1
                            }
                        }
                        if globalRemainingUnreadChatCount > 0 {
                            strongSelf.initialNavigationBadge = "\(globalRemainingUnreadChatCount)"
                        }
                    }
                }
                
                strongSelf.onUpdated?(previousState)
            }
            
            let initialPersistentPeerData: Signal<ChatPresentationInterfaceState.PersistentPeerData?, NoError>
            if let peerId = chatLocation.peerId {
                initialPersistentPeerData = context.engine.peers.getPerstistentChatInterfaceState(peerId: peerId)
                |> map { value in
                    return value?.get(ChatPresentationInterfaceState.PersistentPeerData.self)
                }
            } else {
                initialPersistentPeerData = .single(nil)
            }
            let initialPersistentPeerDataReady = initialPersistentPeerData
            |> deliverOnMainQueue
            |> beforeNext { [weak self] value in
                guard let self else {
                    return
                }
                self.initialPersistentPeerData = value
            }
            |> map { _ -> Bool in true }
            
            self.isReady.set(combineLatest(queue: .mainQueue(), [
                self.isPeerInfoReady.get(),
                self.isChatLocationInfoReady.get(),
                self.isCachedDataReady.get(),
                historyNode.isReady,
                initialData |> map { _ -> Bool in true },
                initialPersistentPeerDataReady
            ])
            |> map { values in
                return !values.contains(where: { !$0 })
            }
            |> filter { $0 }
            |> take(1)
            |> distinctUntilChanged)
            
            self.buttonKeyboardMessageDisposable?.dispose()
            self.buttonKeyboardMessageDisposable = historyNode.buttonKeyboardMessage.startStrict(next: { [weak self] message in
                guard let strongSelf = self else {
                    return
                }
                var buttonKeyboardMessageUpdated = false
                if let currentButtonKeyboardMessage = strongSelf.state.keyboardButtonsMessage, let message = message {
                    if currentButtonKeyboardMessage.id != message.id || currentButtonKeyboardMessage.stableVersion != message.stableVersion {
                        buttonKeyboardMessageUpdated = true
                    }
                } else if (strongSelf.state.keyboardButtonsMessage != nil) != (message != nil) {
                    buttonKeyboardMessageUpdated = true
                }
                if buttonKeyboardMessageUpdated {
                    let previousState = strongSelf.state
                    strongSelf.state.keyboardButtonsMessage = message
                    strongSelf.onUpdated?(previousState)
                }
            })
            
            if let peerId = chatLocation.peerId {
                let customEmojiAvailable: Signal<Bool, NoError> = context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.SecretChatLayer(id: peerId)
                )
                |> map { layer -> Bool in
                    guard let layer = layer else {
                        return true
                    }
                    
                    return layer >= 144
                }
                |> distinctUntilChanged
                
                let isForum = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> map { peer -> Bool in
                    if case let .channel(channel) = peer {
                        return channel.isForumOrMonoForum
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                
                let threadData: Signal<ChatPresentationInterfaceState.ThreadData?, NoError>
                let forumTopicData: Signal<ChatPresentationInterfaceState.ThreadData?, NoError>
                if let threadId = chatLocation.threadId {
                    let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: threadId)
                    threadData = context.account.postbox.combinedView(keys: [viewKey])
                    |> map { views -> ChatPresentationInterfaceState.ThreadData? in
                        guard let view = views.views[viewKey] as? MessageHistoryThreadInfoView else {
                            return nil
                        }
                        guard let data = view.info?.data.get(MessageHistoryThreadData.self) else {
                            return nil
                        }
                        return ChatPresentationInterfaceState.ThreadData(title: data.info.title, icon: data.info.icon, iconColor: data.info.iconColor, isOwnedByMe: data.isOwnedByMe, isClosed: data.isClosed)
                    }
                    |> distinctUntilChanged
                    forumTopicData = .single(nil)
                } else {
                    forumTopicData = isForum
                    |> mapToSignal { isForum -> Signal<ChatPresentationInterfaceState.ThreadData?, NoError> in
                        if isForum {
                            let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: 1)
                            return context.account.postbox.combinedView(keys: [viewKey])
                            |> map { views -> ChatPresentationInterfaceState.ThreadData? in
                                guard let view = views.views[viewKey] as? MessageHistoryThreadInfoView else {
                                    return nil
                                }
                                guard let data = view.info?.data.get(MessageHistoryThreadData.self) else {
                                    return nil
                                }
                                return ChatPresentationInterfaceState.ThreadData(title: data.info.title, icon: data.info.icon, iconColor: data.info.iconColor, isOwnedByMe: data.isOwnedByMe, isClosed: data.isClosed)
                            }
                            |> distinctUntilChanged
                        } else {
                            return .single(nil)
                        }
                    }
                    threadData = .single(nil)
                }

                if case .standard(.previewing) = mode {
                } else if peerId.namespace != Namespaces.Peer.SecretChat && peerId != context.account.peerId && initialSubject != .scheduledMessages {
                    self.premiumGiftSuggestionDisposable?.dispose()
                    self.premiumGiftSuggestionDisposable = (ApplicationSpecificNotice.dismissedPremiumGiftSuggestion(accountManager: context.sharedContext.accountManager, peerId: peerId)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] timestamp in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let previousState = strongSelf.state
                        
                        let currentTime = Int32(Date().timeIntervalSince1970)
                        var suggest = true
                        if let timestamp, currentTime < timestamp + 60 * 60 * 24 {
                            suggest = false
                        }
                        strongSelf.state.suggestPremiumGift = suggest
                        
                        strongSelf.onUpdated?(previousState)
                    })
                    
                    var baseLanguageCode = self.presentationData.strings.baseLanguageCode
                    if baseLanguageCode.contains("-") {
                        baseLanguageCode = baseLanguageCode.components(separatedBy: "-").first ?? baseLanguageCode
                    }
                    let isPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                    |> map { peer -> Bool in
                        return peer?.isPremium ?? false
                    } |> distinctUntilChanged
                    
                    let isHidden = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.TranslationHidden(id: peerId))
                    |> distinctUntilChanged
                    
                    let hasAutoTranslate = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AutoTranslateEnabled(id: peerId))
                    |> distinctUntilChanged
                    
                    self.translationStateDisposable?.dispose()
                    self.translationStateDisposable = (combineLatest(
                        queue: .concurrentDefaultQueue(),
                        isPremium,
                        isHidden,
                        hasAutoTranslate,
                        ApplicationSpecificNotice.translationSuggestion(accountManager: context.sharedContext.accountManager)
                    ) |> mapToSignal { isPremium, isHidden, hasAutoTranslate, counterAndTimestamp -> Signal<ChatPresentationTranslationState?, NoError> in
                        var maybeSuggestPremium = false
                        if counterAndTimestamp.0 >= 3 {
                            maybeSuggestPremium = true
                        }
                        if (isPremium || maybeSuggestPremium || hasAutoTranslate) && !isHidden {
                            return chatTranslationState(context: context, peerId: peerId, threadId: chatLocation.threadId)
                            |> map { translationState -> ChatPresentationTranslationState? in
                                if let translationState, !translationState.fromLang.isEmpty && (translationState.fromLang != baseLanguageCode || translationState.isEnabled) {
                                    return ChatPresentationTranslationState(isEnabled: translationState.isEnabled, fromLang: translationState.fromLang, toLang: translationState.toLang ?? baseLanguageCode)
                                } else {
                                    return nil
                                }
                            }
                            |> distinctUntilChanged
                        } else {
                            return .single(nil)
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] chatTranslationState in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let previousState = strongSelf.state
                        
                        strongSelf.state.translationState = chatTranslationState
                        
                        strongSelf.onUpdated?(previousState)
                    })
                }
                
                let premiumGiftOptions: Signal<[CachedPremiumGiftOption], NoError> = .single([])
                |> then(
                    context.engine.payments.premiumGiftCodeOptions(peerId: peerId, onlyCached: true)
                    |> map { options in
                        return options.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                    }
                )
                
                let isTopReplyThreadMessageShown: Signal<Bool, NoError> = historyNode.isTopReplyThreadMessageShown.get()
                |> distinctUntilChanged
                
                let hasPendingMessages: Signal<Bool, NoError>
                let chatLocationPeerId = chatLocation.peerId
                
                if let chatLocationPeerId = chatLocationPeerId {
                    hasPendingMessages = context.account.pendingMessageManager.hasPendingMessages
                    |> mapToSignal { peerIds -> Signal<Bool, NoError> in
                        let value = peerIds.contains(chatLocationPeerId)
                        if value {
                            return .single(true)
                        } else {
                            return .single(false)
                        }
                    }
                    |> distinctUntilChanged
                } else {
                    hasPendingMessages = .single(false)
                }
                
                let topPinnedMessage: Signal<ChatPinnedMessage?, NoError>
                if let subject = initialSubject {
                    switch subject {
                    case .messageOptions, .pinnedMessages, .scheduledMessages:
                        topPinnedMessage = .single(nil)
                    default:
                        topPinnedMessage = ChatControllerImpl.topPinnedScrollMessage(context: context, chatLocation: chatLocation, historyNode: historyNode, scrolledToMessageId: self.scrolledToMessageId.get())
                    }
                } else {
                    topPinnedMessage = ChatControllerImpl.topPinnedScrollMessage(context: context, chatLocation: chatLocation, historyNode: historyNode, scrolledToMessageId: self.scrolledToMessageId.get())
                }
                
                self.cachedDataDisposable?.dispose()
                self.cachedDataDisposable = combineLatest(queue: .mainQueue(), historyNode.cachedPeerDataAndMessages,
                    hasPendingMessages,
                    isTopReplyThreadMessageShown,
                    topPinnedMessage,
                    customEmojiAvailable,
                    isForum,
                    threadData,
                    forumTopicData,
                    premiumGiftOptions
                ).startStrict(next: { [weak self] cachedDataAndMessages, hasPendingMessages, isTopReplyThreadMessageShown, topPinnedMessage, customEmojiAvailable, isForum, threadData, forumTopicData, premiumGiftOptions in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let previousState = strongSelf.state
                    
                    let (cachedData, messages) = cachedDataAndMessages
                    
                    if cachedData != nil {
                        var themeEmoticon: String? = nil
                        var chatWallpaper: TelegramWallpaper?
                        if let cachedData = cachedData as? CachedUserData {
                            themeEmoticon = cachedData.themeEmoticon
                            chatWallpaper = cachedData.wallpaper
                        } else if let cachedData = cachedData as? CachedGroupData {
                            themeEmoticon = cachedData.themeEmoticon
                        } else if let cachedData = cachedData as? CachedChannelData {
                            themeEmoticon = cachedData.themeEmoticon
                            chatWallpaper = cachedData.wallpaper
                        }
                        
                        strongSelf.chatThemeEmoticonPromise.set(.single(themeEmoticon))
                        strongSelf.chatWallpaperPromise.set(.single(chatWallpaper))
                    }
                    
                    var pinnedMessageId: MessageId?
                    var peerIsBlocked: Bool = false
                    var callsAvailable: Bool = false
                    var callsPrivate: Bool = false
                    var voiceMessagesAvailable: Bool = true
                    var slowmodeState: ChatSlowmodeState?
                    var activeGroupCallInfo: ChatActiveGroupCallInfo?
                    var inviteRequestsPending: Int32?
                    if let cachedData = cachedData as? CachedChannelData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        if !canBypassRestrictions(boostsToUnrestrict: strongSelf.state.boostsToUnrestrict, appliedBoosts: strongSelf.state.appliedBoosts) {
                            if let channel = strongSelf.state.renderedPeer?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                                if hasPendingMessages {
                                    slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .pendingMessages)
                                } else if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                                    slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                                }
                            }
                        }
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                        inviteRequestsPending = cachedData.inviteRequestsPending
                    } else if let cachedData = cachedData as? CachedUserData {
                        peerIsBlocked = cachedData.isBlocked
                        callsAvailable = cachedData.voiceCallsAvailable
                        callsPrivate = cachedData.callsPrivate
                        pinnedMessageId = cachedData.pinnedMessageId
                        voiceMessagesAvailable = cachedData.voiceMessagesAvailable
                    } else if let cachedData = cachedData as? CachedGroupData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                        inviteRequestsPending = cachedData.inviteRequestsPending
                    } else if let _ = cachedData as? CachedSecretChatData {
                    }
                    
                    var pinnedMessage: ChatPinnedMessage?
                    switch chatLocation {
                    case let .replyThread(replyThreadMessage):
                        if isForum {
                            pinnedMessageId = topPinnedMessage?.message.id
                            pinnedMessage = topPinnedMessage
                        } else {
                            if isTopReplyThreadMessageShown {
                                pinnedMessageId = nil
                            } else {
                                pinnedMessageId = replyThreadMessage.effectiveTopId
                            }
                            if let pinnedMessageId = pinnedMessageId {
                                if let message = messages?[pinnedMessageId] {
                                    pinnedMessage = ChatPinnedMessage(message: message, index: 0, totalCount: 1, topMessageId: message.id)
                                }
                            }
                        }
                    case .peer:
                        pinnedMessageId = topPinnedMessage?.message.id
                        pinnedMessage = topPinnedMessage
                    case .customChatContents:
                        pinnedMessageId = nil
                        pinnedMessage = nil
                    }
                    
                    var pinnedMessageUpdated = false
                    if let current = strongSelf.state.pinnedMessage, let updated = pinnedMessage {
                        if current != updated {
                            pinnedMessageUpdated = true
                        }
                    } else if (strongSelf.state.pinnedMessage != nil) != (pinnedMessage != nil) {
                        pinnedMessageUpdated = true
                    }
                    
                    let callsDataUpdated = strongSelf.state.callsAvailable != callsAvailable || strongSelf.state.callsPrivate != callsPrivate
                
                    let voiceMessagesAvailableUpdated = strongSelf.state.voiceMessagesAvailable != voiceMessagesAvailable
                    
                    var canManageInvitations = false
                    if let channel = strongSelf.state.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                        canManageInvitations = true
                    } else if let group = strongSelf.state.renderedPeer?.peer as? TelegramGroup {
                        if case .creator = group.role {
                            canManageInvitations = true
                        } else if case let .admin(rights, _) = group.role, rights.rights.contains(.canInviteUsers) {
                            canManageInvitations = true
                        }
                    }
                    
                    if canManageInvitations, let inviteRequestsPending = inviteRequestsPending, inviteRequestsPending >= 0 {
                        if strongSelf.inviteRequestsContext == nil {
                            let inviteRequestsContext = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
                            strongSelf.inviteRequestsContext = inviteRequestsContext
                        } else if let inviteRequestsContext = strongSelf.inviteRequestsContext {
                            let _ = (inviteRequestsContext.state
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { [weak inviteRequestsContext] state in
                                if state.count != inviteRequestsPending {
                                    inviteRequestsContext?.loadMore()
                                }
                            })
                        }
                        
                        if chatLocation.threadId == nil {
                            if strongSelf.inviteRequestsDisposable == nil, let inviteRequestsContext = strongSelf.inviteRequestsContext {
                                strongSelf.inviteRequestsDisposable = combineLatest(queue: Queue.mainQueue(), inviteRequestsContext.state, ApplicationSpecificNotice.dismissedInvitationRequests(accountManager: context.sharedContext.accountManager, peerId: peerId)).startStrict(next: { [weak strongSelf] requestsState, dismissedInvitationRequests in
                                    guard let strongSelf else {
                                        return
                                    }
                                    
                                    let previousState = strongSelf.state
                                    
                                    strongSelf.state.requestsState = requestsState
                                    strongSelf.state.dismissedInvitationRequests = dismissedInvitationRequests
                                    
                                    strongSelf.onUpdated?(previousState)
                                })
                            }
                        } else {
                            strongSelf.state.requestsState = nil
                            strongSelf.state.dismissedInvitationRequests = []
                        }
                    } else {
                        strongSelf.inviteRequestsContext = nil
                        strongSelf.state.requestsState = nil
                        strongSelf.state.dismissedInvitationRequests = []
                    }
                
                    var isUpdated = false
                    if strongSelf.state.pinnedMessageId != pinnedMessageId || strongSelf.state.pinnedMessage != pinnedMessage || strongSelf.state.peerIsBlocked != peerIsBlocked || pinnedMessageUpdated || callsDataUpdated || voiceMessagesAvailableUpdated || strongSelf.state.slowmodeState != slowmodeState || strongSelf.state.activeGroupCallInfo != activeGroupCallInfo || customEmojiAvailable != strongSelf.state.customEmojiAvailable || threadData != strongSelf.state.threadData || forumTopicData != strongSelf.state.forumTopicData || premiumGiftOptions != strongSelf.state.premiumGiftOptions {
                        isUpdated = true
                        
                        strongSelf.state.pinnedMessage = pinnedMessage
                        strongSelf.state.pinnedMessageId = pinnedMessageId
                        strongSelf.state.activeGroupCallInfo = activeGroupCallInfo
                        strongSelf.state.peerIsBlocked = peerIsBlocked
                        strongSelf.state.callsAvailable = callsAvailable
                        strongSelf.state.callsPrivate = callsPrivate
                        strongSelf.state.voiceMessagesAvailable = voiceMessagesAvailable
                        strongSelf.state.customEmojiAvailable = customEmojiAvailable
                        strongSelf.state.threadData = threadData
                        strongSelf.state.forumTopicData = forumTopicData
                        strongSelf.state.isGeneralThreadClosed = forumTopicData?.isClosed
                        strongSelf.state.premiumGiftOptions = premiumGiftOptions
                        strongSelf.state.slowmodeState = slowmodeState
                    }
                    
                    strongSelf.isCachedDataReady.set(true)
                    
                    if isUpdated {
                        strongSelf.onUpdated?(previousState)
                    }
                })
            } else {
                self.isCachedDataReady.set(true)
            }
        }
        
        deinit {
            self.peerDisposable?.dispose()
            self.titleDisposable?.dispose()
            self.preloadSavedMessagesChatsDisposable?.dispose()
            self.preloadHistoryPeerIdDisposable.dispose()
            self.preloadNextChatPeerIdDisposable.dispose()
            self.nextChannelToReadDisposable?.dispose()
            self.chatAdditionalDataDisposable.dispose()
            self.premiumOrStarsRequiredDisposable?.dispose()
            self.buttonKeyboardMessageDisposable?.dispose()
            self.cachedDataDisposable?.dispose()
            self.premiumGiftSuggestionDisposable?.dispose()
            self.translationStateDisposable?.dispose()
            self.inviteRequestsDisposable?.dispose()
        }
    }
}
