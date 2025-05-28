import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import MobileCoreServices
import Intents
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import TextFormat
import TelegramBaseController
import AccountContext
import TelegramStringFormatting
import OverlayStatusController
import DeviceLocationManager
import ShareController
import UrlEscaping
import ContextUI
import ComposePollUI
import AlertUI
import PresentationDataUtils
import UndoUI
import TelegramCallsUI
import TelegramNotices
import GameUI
import ScreenCaptureDetection
import GalleryUI
import OpenInExternalAppUI
import LegacyUI
import InstantPageUI
import LocationUI
import BotPaymentsUI
import DeleteChatPeerActionSheetItem
import HashtagSearchUI
import LegacyMediaPickerUI
import Emoji
import PeerAvatarGalleryUI
import PeerInfoUI
import RaiseToListen
import UrlHandling
import AvatarNode
import AppBundle
import LocalizedPeerData
import PhoneNumberFormat
import SettingsUI
import UrlWhitelist
import TelegramIntents
import TooltipUI
import StatisticsUI
import MediaResources
import GalleryData
import ChatInterfaceState
import InviteLinksUI
import Markdown
import TelegramPermissionsUI
import Speak
import TranslateUI
import UniversalMediaPlayer
import WallpaperBackgroundNode
import ChatListUI
import CalendarMessageScreen
import ReactionSelectionNode
import ReactionListContextMenuContent
import AttachmentUI
import AttachmentTextInputPanelNode
import MediaPickerUI
import ChatPresentationInterfaceState
import Pasteboard
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import WebUI
import PremiumUI
import ImageTransparency
import StickerPackPreviewUI
import TextNodeWithEntities
import EntityKeyboard
import ChatTitleView
import EmojiStatusComponent
import ChatTimerScreen
import MediaPasteboardUI
import ChatListHeaderComponent
import ChatControllerInteraction
import FeaturedStickersScreen
import ChatEntityKeyboardInputNode
import StorageUsageScreen
import AvatarEditorScreen
import ChatScheduleTimeController
import ICloudResources
import StoryContainerScreen
import MoreHeaderButton
import VolumeButtons
import ChatAvatarNavigationNode
import ChatContextQuery
import PeerReportScreen
import PeerSelectionController
import SaveToCameraRoll
import ChatMessageDateAndStatusNode
import ReplyAccessoryPanelNode
import TextSelectionNode
import ChatMessagePollBubbleContentNode
import ChatMessageItem
import ChatMessageItemImpl
import ChatMessageItemView
import ChatMessageItemCommon
import ChatMessageAnimatedStickerItemNode
import ChatMessageBubbleItemNode
import ChatNavigationButton
import WebsiteType
import ChatQrCodeScreen
import PeerInfoScreen
import MediaEditorScreen
import WallpaperGalleryScreen
import WallpaperGridScreen
import VideoMessageCameraScreen
import TopMessageReactions
import AudioWaveform
import PeerNameColorScreen
import ChatEmptyNode
import ChatMediaInputStickerGridItem
import AdsInfoScreen
import PostSuggestionsSettingsScreen
import ChatSendStarsScreen

extension ChatControllerImpl {
    func reloadChatLocation(chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, historyNode: ChatHistoryListNodeImpl, apply: @escaping ((Bool) -> Void) -> Void) {
        self.contentDataReady.set(false)
        
        self.contentDataDisposable?.dispose()
        
        let configuration: Signal<ChatControllerImpl.ContentData.Configuration, NoError> = self.presentationInterfaceStatePromise.get()
        |> map { presentationInterfaceState -> ChatControllerImpl.ContentData.Configuration in
            return ChatControllerImpl.ContentData.Configuration(
                subject: presentationInterfaceState.subject,
                selectionState: presentationInterfaceState.interfaceState.selectionState,
                reportReason: presentationInterfaceState.reportReason
            )
        }
        |> distinctUntilChanged
        
        let contentData = ChatControllerImpl.ContentData(
            context: self.context,
            chatLocation: chatLocation,
            chatLocationContextHolder: chatLocationContextHolder,
            initialSubject: self.subject,
            mode: self.mode,
            configuration: configuration,
            adMessagesContext: self.chatDisplayNode.adMessagesContext,
            currentChatListFilter: self.currentChatListFilter,
            customChatNavigationStack: self.customChatNavigationStack,
            presentationData: self.presentationData,
            historyNode: historyNode,
            inviteRequestsContext: self.contentData?.inviteRequestsContext
        )
        self.pendingContentData = (contentData, historyNode)
        self.contentDataDisposable = (contentData.isReady.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self, weak contentData, weak historyNode] _ in
            guard let self, let contentData, self.pendingContentData?.contentData === contentData else {
                return
            }
            
            apply({ [weak self, weak contentData] forceAnimation in
                guard let self, let contentData, self.pendingContentData?.contentData === contentData else {
                    return
                }
                
                self.contentData = contentData
                self.pendingContentData = nil
                self.contentDataUpdated(synchronous: true, forceAnimation: forceAnimation, previousState: contentData.state)
                
                self.chatThemeEmoticonPromise.set(contentData.chatThemeEmoticonPromise.get())
                self.chatWallpaperPromise.set(contentData.chatWallpaperPromise.get())
                
                if let historyNode {
                    self.setupChatHistoryNode(historyNode: historyNode)
                    
                    historyNode.contentPositionChanged(historyNode.visibleContentOffset())
                }
                
                self.contentDataReady.set(true)
                
                contentData.onUpdated = { [weak self, weak contentData] previousState in
                    guard let self, let contentData, self.contentData === contentData else {
                        return
                    }
                    self.contentDataUpdated(synchronous: false, forceAnimation: false, previousState: previousState)
                }
            })
        })
    }
    
    func contentDataUpdated(synchronous: Bool, forceAnimation: Bool, previousState: ContentData.State) {
        guard let contentData = self.contentData else {
            return
        }
        self.navigationBar?.userInfo = contentData.state.navigationUserInfo
        
        if self.chatTitleView?.titleContent != contentData.state.chatTitleContent {
            var animateTitleContents = false
            if !synchronous,  case let .messageOptions(_, _, info) = self.subject, case .reply = info {
                animateTitleContents = true
            }
            if animateTitleContents && self.chatTitleView?.titleContent != nil {
                self.chatTitleView?.animateLayoutTransition()
            }
            self.chatTitleView?.titleContent = contentData.state.chatTitleContent
        }
        
        if let infoAvatar = contentData.state.infoAvatar {
            switch infoAvatar {
            case let .peer(peer, imageOverride, contextActionIsEnabled, accessibilityLabel):
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.setPeer(context: self.context, theme: self.presentationData.theme, peer: peer, overrideImage: imageOverride, synchronousLoad: synchronous)
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.contextActionIsEnabled = contextActionIsEnabled
                self.chatInfoNavigationButton?.buttonItem.accessibilityLabel = accessibilityLabel
            case let .emojiStatus(content, contextActionIsEnabled):
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.setStatus(context: self.context, content: content)
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.contextActionIsEnabled = contextActionIsEnabled
                self.chatInfoNavigationButton?.buttonItem.accessibilityLabel = self.presentationData.strings.Conversation_ContextMenuOpenProfile
            }
        } else {
            (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.contextActionIsEnabled = false
        }
        
        if let avatarNode = self.avatarNode {
            avatarNode.avatarNode.setStoryStats(storyStats: contentData.state.storyStats.flatMap { storyStats -> AvatarNode.StoryStats? in
                if storyStats.totalCount == 0 {
                    return nil
                }
                if storyStats.unseenCount == 0 {
                    return nil
                }
                return AvatarNode.StoryStats(
                    totalCount: storyStats.totalCount,
                    unseenCount: storyStats.unseenCount,
                    hasUnseenCloseFriendsItems: storyStats.hasUnseenCloseFriends
                )
            }, presentationParams: AvatarNode.StoryPresentationParams(
                colors: AvatarNode.Colors(theme: self.presentationData.theme),
                lineWidth: 1.5,
                inactiveLineWidth: 1.5
            ), transition: .immediate)
        }
        
        self.chatDisplayNode.overlayTitle = contentData.overlayTitle
        
        self.chatDisplayNode.historyNode.nextChannelToRead = contentData.state.nextChannelToRead.flatMap { nextChannelToRead -> (peer: EnginePeer, threadData: (id: Int64, data: MessageHistoryThreadData)?, unreadCount: Int, location: TelegramEngine.NextUnreadChannelLocation)? in
            return (
                nextChannelToRead.peer,
                nextChannelToRead.threadData.flatMap { threadData -> (id: Int64, data: MessageHistoryThreadData) in
                    return (threadData.id, threadData.data)
                },
                nextChannelToRead.unreadCount,
                nextChannelToRead.location
            )
        }
        self.chatDisplayNode.historyNode.nextChannelToReadDisplayName = contentData.state.nextChannelToReadDisplayName
        self.updateNextChannelToReadVisibility()
        
        var animated = false
        if self.presentationInterfaceState.adMessage?.id != contentData.state.adMessage?.id {
            animated = true
        }
        if let peer = previousState.renderedPeer?.peer as? TelegramSecretChat, let updated = contentData.state.renderedPeer?.peer as? TelegramSecretChat, peer.embeddedState != updated.embeddedState {
            animated = true
        }
        if let peer = previousState.renderedPeer?.peer as? TelegramChannel, let updated = contentData.state.renderedPeer?.peer as? TelegramChannel {
            if peer.participationStatus != updated.participationStatus {
                animated = true
            }
        }
        
        var didDisplayActionsPanel = false
        if let contactStatus = previousState.contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
            if !peerStatusSettings.flags.isEmpty {
                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                    didDisplayActionsPanel = true
                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                    didDisplayActionsPanel = true
                } else if peerStatusSettings.contains(.canShareContact) {
                    didDisplayActionsPanel = true
                } else if peerStatusSettings.contains(.suggestAddMembers) {
                    didDisplayActionsPanel = true
                }
            }
        }
        if let contactStatus = previousState.contactStatus, contactStatus.managingBot != nil {
            didDisplayActionsPanel = true
        }
        if self.presentationInterfaceState.search != nil && self.presentationInterfaceState.hasSearchTags {
            didDisplayActionsPanel = true
        }
        
        var previousInvitationPeers: [EnginePeer] = []
        if let requestsState = previousState.requestsState {
            previousInvitationPeers = Array(requestsState.importers.compactMap({ $0.peer.peer.flatMap({ EnginePeer($0) }) }).prefix(3))
        }
        var previousInvitationRequestsPeersDismissed = false
        if let dismissedInvitationRequests = previousState.dismissedInvitationRequests, Set(previousInvitationPeers.map({ $0.id.toInt64() })) == Set(dismissedInvitationRequests) {
            previousInvitationRequestsPeersDismissed = true
        }
        if let requestsState = previousState.requestsState, requestsState.count > 0 && !previousInvitationRequestsPeersDismissed {
            didDisplayActionsPanel = true
        }
        
        var displayActionsPanel = false
        if let contactStatus = contentData.state.contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
            if !peerStatusSettings.flags.isEmpty {
                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                    displayActionsPanel = true
                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                    displayActionsPanel = true
                } else if peerStatusSettings.contains(.canShareContact) {
                    displayActionsPanel = true
                } else if peerStatusSettings.contains(.suggestAddMembers) {
                    displayActionsPanel = true
                }
            }
        }
        if let contactStatus = contentData.state.contactStatus, contactStatus.managingBot != nil {
            displayActionsPanel = true
        }
        if self.presentationInterfaceState.search != nil && contentData.state.hasSearchTags {
            displayActionsPanel = true
        }
        
        var invitationPeers: [EnginePeer] = []
        if let requestsState = contentData.state.requestsState {
            invitationPeers = Array(requestsState.importers.compactMap({ $0.peer.peer.flatMap({ EnginePeer($0) }) }).prefix(3))
        }
        var invitationRequestsPeersDismissed = false
        if let dismissedInvitationRequests = contentData.state.dismissedInvitationRequests, Set(invitationPeers.map({ $0.id.toInt64() })) == Set(dismissedInvitationRequests) {
            invitationRequestsPeersDismissed = true
        }
        if let requestsState = contentData.state.requestsState, requestsState.count > 0 && !invitationRequestsPeersDismissed {
            displayActionsPanel = true
        }
        
        if displayActionsPanel != didDisplayActionsPanel {
            animated = true
        }
        if previousState.pinnedMessage != contentData.state.pinnedMessage {
            animated = true
        }
        if forceAnimation {
            animated = true
        }
        
        self.updateChatPresentationInterfaceState(animated: animated && self.willAppear, interactive: false, { presentationInterfaceState in
            var presentationInterfaceState = presentationInterfaceState
            presentationInterfaceState = presentationInterfaceState.updatedPeer({ _ in
                return contentData.state.renderedPeer
            })
            presentationInterfaceState = presentationInterfaceState.updatedChatLocation(contentData.chatLocation)
            presentationInterfaceState = presentationInterfaceState.updatedIsNotAccessible(contentData.state.isNotAccessible)
            presentationInterfaceState = presentationInterfaceState.updatedContactStatus(contentData.state.contactStatus)
            presentationInterfaceState = presentationInterfaceState.updatedHasBots(contentData.state.hasBots)
            presentationInterfaceState = presentationInterfaceState.updatedHasBotCommands(contentData.state.hasBotCommands)
            presentationInterfaceState = presentationInterfaceState.updatedBotMenuButton(contentData.state.botMenuButton)
            presentationInterfaceState = presentationInterfaceState.updatedIsArchived(contentData.state.isArchived)
            presentationInterfaceState = presentationInterfaceState.updatedPeerIsMuted(contentData.state.peerIsMuted)
            presentationInterfaceState = presentationInterfaceState.updatedPeerDiscussionId(contentData.state.peerDiscussionId)
            presentationInterfaceState = presentationInterfaceState.updatedPeerGeoLocation(contentData.state.peerGeoLocation)
            presentationInterfaceState = presentationInterfaceState.updatedExplicitelyCanPinMessages(contentData.state.explicitelyCanPinMessages)
            presentationInterfaceState = presentationInterfaceState.updatedHasScheduledMessages(contentData.state.hasScheduledMessages)
            presentationInterfaceState = presentationInterfaceState.updatedAutoremoveTimeout(contentData.state.autoremoveTimeout)
            presentationInterfaceState = presentationInterfaceState.updatedCurrentSendAsPeerId(contentData.state.currentSendAsPeerId)
            presentationInterfaceState = presentationInterfaceState.updatedCopyProtectionEnabled(contentData.state.copyProtectionEnabled)
            presentationInterfaceState = presentationInterfaceState.updatedHasSearchTags(contentData.state.hasSearchTags)
            presentationInterfaceState = presentationInterfaceState.updatedIsPremiumRequiredForMessaging(contentData.state.isPremiumRequiredForMessaging)
            presentationInterfaceState = presentationInterfaceState.updatedSendPaidMessageStars(contentData.state.sendPaidMessageStars)
            presentationInterfaceState = presentationInterfaceState.updatedAlwaysShowGiftButton(contentData.state.alwaysShowGiftButton)
            presentationInterfaceState = presentationInterfaceState.updatedDisallowedGifts(contentData.state.disallowedGifts)
            presentationInterfaceState = presentationInterfaceState.updatedHasSavedChats(contentData.state.hasSavedChats)
            presentationInterfaceState = presentationInterfaceState.updatedAppliedBoosts(contentData.state.appliedBoosts)
            presentationInterfaceState = presentationInterfaceState.updatedBoostsToUnrestrict(contentData.state.boostsToUnrestrict)
            presentationInterfaceState = presentationInterfaceState.updatedHasBirthdayToday(contentData.state.hasBirthdayToday)
            presentationInterfaceState = presentationInterfaceState.updatedBusinessIntro(contentData.state.businessIntro)
            presentationInterfaceState = presentationInterfaceState.updatedAdMessage(contentData.state.adMessage)
            presentationInterfaceState = presentationInterfaceState.updatedPeerVerification(contentData.state.peerVerification)
            presentationInterfaceState = presentationInterfaceState.updatedStarGiftsAvailable(contentData.state.starGiftsAvailable)
            presentationInterfaceState = presentationInterfaceState.updatedSavedMessagesTopicPeer(contentData.state.savedMessagesTopicPeer)
            presentationInterfaceState = presentationInterfaceState.updatedKeyboardButtonsMessage(contentData.state.keyboardButtonsMessage)
            presentationInterfaceState = presentationInterfaceState.updatedPinnedMessageId(contentData.state.pinnedMessageId)
            presentationInterfaceState = presentationInterfaceState.updatedPinnedMessage(contentData.state.pinnedMessage)
            presentationInterfaceState = presentationInterfaceState.updatedPeerIsBlocked(contentData.state.peerIsBlocked)
            presentationInterfaceState = presentationInterfaceState.updatedCallsAvailable(contentData.state.callsAvailable)
            presentationInterfaceState = presentationInterfaceState.updatedCallsPrivate(contentData.state.callsPrivate)
            presentationInterfaceState = presentationInterfaceState.updatedActiveGroupCallInfo(contentData.state.activeGroupCallInfo)
            presentationInterfaceState = presentationInterfaceState.updatedSlowmodeState(contentData.state.slowmodeState)
            presentationInterfaceState = presentationInterfaceState.updatedSuggestPremiumGift(contentData.state.suggestPremiumGift)
            presentationInterfaceState = presentationInterfaceState.updatedTranslationState(contentData.state.translationState)
            presentationInterfaceState = presentationInterfaceState.updatedVoiceMessagesAvailable(contentData.state.voiceMessagesAvailable)
            presentationInterfaceState = presentationInterfaceState.updatedCustomEmojiAvailable(contentData.state.customEmojiAvailable)
            presentationInterfaceState = presentationInterfaceState.updatedThreadData(contentData.state.threadData)
            presentationInterfaceState = presentationInterfaceState.updatedForumTopicData(contentData.state.forumTopicData)
            presentationInterfaceState = presentationInterfaceState.updatedIsGeneralThreadClosed(contentData.state.isGeneralThreadClosed)
            presentationInterfaceState = presentationInterfaceState.updatedPremiumGiftOptions(contentData.state.premiumGiftOptions)
            
            presentationInterfaceState = presentationInterfaceState.updatedTitlePanelContext({ context in
                if contentData.state.pinnedMessageId != nil {
                    if !context.contains(where: { item in
                        switch item {
                        case .pinnedMessage:
                            return true
                        default:
                            return false
                        }
                    }) {
                        var updatedContexts = context
                        updatedContexts.append(.pinnedMessage)
                        return updatedContexts.sorted()
                    } else {
                        return context
                    }
                } else {
                    if let index = context.firstIndex(where: { item in
                        switch item {
                        case .pinnedMessage:
                            return true
                        default:
                            return false
                        }
                    }) {
                        var updatedContexts = context
                        updatedContexts.remove(at: index)
                        return updatedContexts
                    } else {
                        return context
                    }
                }
            })
            presentationInterfaceState = presentationInterfaceState.updatedTitlePanelContext { context in
                var peers: [EnginePeer] = []
                if let requestsState = contentData.state.requestsState {
                    peers = Array(requestsState.importers.compactMap({ $0.peer.peer.flatMap({ EnginePeer($0) }) }).prefix(3))
                }
                
                var peersDismissed = false
                if let dismissedInvitationRequests = contentData.state.dismissedInvitationRequests, Set(peers.map({ $0.id.toInt64() })) == Set(dismissedInvitationRequests) {
                    peersDismissed = true
                }
                if let requestsState = contentData.state.requestsState, requestsState.count > 0 && !peersDismissed {
                    if !context.contains(where: {
                        switch $0 {
                        case .inviteRequests(peers, requestsState.count):
                            return true
                        default:
                            return false
                        }
                    }) {
                        var updatedContexts = context.filter { c in
                            if case .inviteRequests = c {
                                return false
                            } else {
                                return true
                            }
                        }
                        updatedContexts.append(.inviteRequests(peers, requestsState.count))
                        return updatedContexts.sorted()
                    } else {
                        return context
                    }
                } else {
                    if let index = context.firstIndex(where: { item in
                        switch item {
                        case .inviteRequests:
                            return true
                        default:
                            return false
                        }
                    }) {
                        var updatedContexts = context
                        updatedContexts.remove(at: index)
                        return updatedContexts
                    } else {
                        return context
                    }
                }
            }
            
            let initialInterfaceState = contentData.initialInterfaceState
            contentData.initialInterfaceState = nil
            
            if !self.didInitializePersistentPeerInterfaceData, let initialPersistentPeerData = contentData.initialPersistentPeerData {
                self.didInitializePersistentPeerInterfaceData = true
                presentationInterfaceState = presentationInterfaceState.updatedPersistentData(initialPersistentPeerData)
            }
            
            presentationInterfaceState = presentationInterfaceState.updatedInterfaceState { interfaceState in
                var interfaceState = interfaceState
                if let initialInterfaceState {
                    interfaceState = initialInterfaceState.interfaceState
                }
                
                if let channel = contentData.state.renderedPeer?.peer as? TelegramChannel {
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
                } else if let group = contentData.state.renderedPeer?.peer as? TelegramGroup {
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
                
                return interfaceState
            }
            
            if let editMessage = initialInterfaceState?.editMessage {
                let (updatedState, updatedPreviewQueryState) = updatedChatEditInterfaceMessageState(context: self.context, state: presentationInterfaceState, message: editMessage)
                presentationInterfaceState = updatedState
                self.editingUrlPreviewQueryState?.1.dispose()
                self.editingUrlPreviewQueryState = updatedPreviewQueryState
            }
            
            return presentationInterfaceState
        })
        
        if let initialNavigationBadge = contentData.initialNavigationBadge {
            contentData.initialNavigationBadge = nil
            self.navigationItem.badge = initialNavigationBadge
        }
        
        if let performDismissAction = contentData.state.performDismissAction, !self.didHandlePerformDismissAction {
            self.didHandlePerformDismissAction = true
            
            switch performDismissAction {
            case let .upgraded(upgradedToPeerId):
                if let navigationController = self.effectiveNavigationController {
                    var viewControllers = navigationController.viewControllers
                    if let index = viewControllers.firstIndex(where: { $0 === self }) {
                        viewControllers[index] = ChatControllerImpl(context: self.context, chatLocation: .peer(id: upgradedToPeerId))
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }
            case .movedToForumTopics:
                if let peerView = contentData.state.peerView, let navigationController = self.effectiveNavigationController {
                    let chatListController = self.context.sharedContext.makeChatListController(context: self.context, location: .forum(peerId: peerView.peerId), controlsHistoryPreload: false, hideNetworkActivityStatus: false, previewing: false, enableDebugActions: false)
                    navigationController.replaceController(self, with: chatListController, animated: true)
                }
            case .dismiss:
                self.dismiss()
            }
        }
    }
    
    func reloadCachedData() {
        var measure_isFirstTime = true
        #if DEBUG
        let initTimestamp = self.initTimestamp
        #endif
        
        self.ready.set(combineLatest(queue: .mainQueue(), [
            self.contentDataReady.get(),
            self.wallpaperReady.get(),
            self.presentationReady.get()
        ])
        |> map { values in
            return !values.contains(where: { !$0 })
        }
        |> filter { $0 }
        |> take(1)
        |> distinctUntilChanged
        |> beforeNext { value in
            if measure_isFirstTime {
                measure_isFirstTime = false
                #if DEBUG
                let deltaTime = (CFAbsoluteTimeGetCurrent() - initTimestamp) * 1000.0
                print("Chat controller init to ready: \(deltaTime) ms")
                #endif
            }
        })
    }
    
    func loadDisplayNodeImpl() {
        if #available(iOS 18.0, *) {
            if self.context.sharedContext.immediateExperimentalUISettings.enableLocalTranslation {
                if engineExperimentalInternalTranslationService == nil, let hostView = self.context.sharedContext.mainWindow?.hostView {
                    let translationService = ExperimentalInternalTranslationServiceImpl(view: hostView.containerView)
                    engineExperimentalInternalTranslationService = translationService
                }
            } else {
                if engineExperimentalInternalTranslationService != nil {
                    engineExperimentalInternalTranslationService = nil
                }
            }
        }
        
        self.displayNode = ChatControllerNode(context: self.context, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, subject: self.subject, controllerInteraction: self.controllerInteraction!, chatPresentationInterfaceState: self.presentationInterfaceState, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, navigationBar: self.navigationBar, statusBar: self.statusBar, backgroundNode: self.chatBackgroundNode, controller: self)
        
        if let currentItem = self.tempVoicePlaylistCurrentItem {
            self.chatDisplayNode.historyNode.voicePlaylistItemChanged(nil, currentItem)
        }
        
        if case .peer(self.context.account.peerId) = self.chatLocation {
            var didDisplayTooltip = false
            if "".isEmpty {
                didDisplayTooltip = true
            }
            self.chatDisplayNode.historyNode.hasLotsOfMessagesUpdated = { [weak self] hasLotsOfMessages in
                guard let self, hasLotsOfMessages else {
                    return
                }
                if didDisplayTooltip {
                    return
                }
                didDisplayTooltip = true
                
                let _ = (ApplicationSpecificNotice.getSavedMessagesChatsSuggestion(accountManager: self.context.sharedContext.accountManager)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
                    guard let self else {
                        return
                    }
                    if counter >= 3 {
                        return
                    }
                    guard let navigationBar = self.navigationBar else {
                        return
                    }
                    
                    let tooltipScreen = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.Chat_SavedMessagesChatsTooltip), location: .point(navigationBar.frame, .top), displayDuration: .manual, shouldDismissOnTouch: { point, _ in
                        return .ignore
                    })
                    self.present(tooltipScreen, in: .current)
                    
                    let _ = ApplicationSpecificNotice.incrementSavedMessagesChatsSuggestion(accountManager: self.context.sharedContext.accountManager).startStandalone()
                })
            }
        }

        self.chatDisplayNode.historyNode.addContentOffset = { [weak self] offset, itemNode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatDisplayNode.messageTransitionNode.addContentOffset(offset: offset, itemNode: itemNode)
        }
        
        var closeOnEmpty = false
        if case .pinnedMessages = self.presentationInterfaceState.subject {
            closeOnEmpty = true
        } else if self.chatLocation.peerId == self.context.account.peerId {
            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let _ = data["ios_killswitch_disable_close_empty_saved"] {
            } else {
                closeOnEmpty = true
            }
        }
        
        if closeOnEmpty {
            self.chatDisplayNode.historyNode.addSetLoadStateUpdated({ [weak self] state, _ in
                guard let self else {
                    return
                }
                if case .empty = state {
                    if self.chatLocation.peerId == self.context.account.peerId {
                        if self.chatDisplayNode.historyNode.tag != nil {
                            self.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                                return state.updatedSearch(nil).updatedHistoryFilter(nil)
                            })
                        } else if case .replyThread = self.chatLocation {
                            self.dismiss()
                        }
                    } else {
                        self.dismiss()
                    }
                }
            })
        }
        
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> map { peer in
            return SendAsPeer(peer: peer, subscribers: nil, isPremiumRequired: false)
        }
        
        if let peerId = self.chatLocation.peerId, [Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup].contains(peerId.namespace) {
            self.sendAsPeersDisposable = (combineLatest(
                queue: Queue.mainQueue(),
                currentAccountPeer,
                self.context.account.postbox.peerView(id: peerId),
                self.context.engine.peers.sendAsAvailablePeers(peerId: peerId))
            ).startStrict(next: { [weak self] currentAccountPeer, peerView, peers in
                guard let strongSelf = self else {
                    return
                }
                
                if let channel = peerViewMainPeer(peerView) as? TelegramChannel, channel.isMonoForum {
                    return
                }
                
                let isPremium = strongSelf.presentationInterfaceState.isPremium
                
                var allPeers: [SendAsPeer]?
                if !peers.isEmpty {
                    if let channel = peerViewMainPeer(peerView) as? TelegramChannel, case .group = channel.info, channel.hasPermission(.canBeAnonymous) {
                        allPeers = peers
                        
                        var hasAnonymousPeer = false
                        for peer in peers {
                            if peer.peer.id == channel.id {
                                hasAnonymousPeer = true
                                break
                            }
                        }
                        if !hasAnonymousPeer {
                            allPeers?.insert(SendAsPeer(peer: channel, subscribers: 0, isPremiumRequired: false), at: 0)
                        }
                    } else if let channel = peerViewMainPeer(peerView) as? TelegramChannel, case let .broadcast(info) = channel.info, (info.flags.contains(.messagesShouldHaveSignatures) || info.flags.contains(.messagesShouldHaveProfiles)) {
                        allPeers = peers
                        
                        var hasAnonymousPeer = false
                        var hasSelfPeer = false
                        for peer in peers {
                            if peer.peer.id == channel.id {
                                hasAnonymousPeer = true
                            } else if peer.peer.id == strongSelf.context.account.peerId {
                                hasSelfPeer = true
                            }
                        }
                        if !hasSelfPeer {
                            allPeers?.insert(currentAccountPeer, at: 0)
                        }
                        if !hasAnonymousPeer {
                            allPeers?.insert(SendAsPeer(peer: channel, subscribers: 0, isPremiumRequired: false), at: 0)
                        }
                    } else {
                        allPeers = peers.filter { $0.peer.id != peerViewMainPeer(peerView)?.id }
                        allPeers?.insert(currentAccountPeer, at: 0)
                    }
                }
                if allPeers?.count == 1 {
                    allPeers = nil
                }
                
                var currentSendAsPeerId = strongSelf.presentationInterfaceState.currentSendAsPeerId
                if let peerId = currentSendAsPeerId, let peer = allPeers?.first(where: { $0.peer.id == peerId }) {
                    if !isPremium && peer.isPremiumRequired {
                        currentSendAsPeerId = nil
                    }
                } else {
                    currentSendAsPeerId = nil
                }
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    return $0.updatedSendAsPeers(allPeers).updatedCurrentSendAsPeerId(currentSendAsPeerId)
                })
            })
        }
        
        if let peerId = self.chatLocation.peerId {
            self.chatThemeEmoticonPromise.set(self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ThemeEmoticon(id: peerId)))
            let chatWallpaper = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Wallpaper(id: peerId))
            |> take(1)
            self.chatWallpaperPromise.set(chatWallpaper)
        } else {
            self.chatThemeEmoticonPromise.set(.single(nil))
            self.chatWallpaperPromise.set(.single(nil))
        }
        
        self.reloadCachedData()
        
        self.historyStateDisposable = self.chatDisplayNode.historyNode.historyState.get().startStrict(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: strongSelf.isViewLoaded && strongSelf.view.window != nil, {
                    $0.updatedChatHistoryState(state)
                })
                
                if let botStart = strongSelf.botStart, case let .loaded(isEmpty, _) = state {
                    strongSelf.botStart = nil
                    if !isEmpty {
                        strongSelf.startBot(botStart.payload)
                    }
                }
            }
        })
        
        if self.context.sharedContext.immediateExperimentalUISettings.crashOnLongQueries {
            let _ = (self.ready.get()
            |> filter({ $0 })
            |> take(1)
            |> timeout(0.8, queue: .concurrentDefaultQueue(), alternate: Signal { _ in
                preconditionFailure()
            })).startStandalone()
        }
        
        self.setupChatHistoryNode(historyNode: self.chatDisplayNode.historyNode)
        
        self.chatDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.chatDisplayNode.setupSendActionOnViewUpdate = { [weak self] f, messageCorrelationId in
            //print("setup layoutActionOnViewTransition")

            guard let self else {
                return
            }
            self.layoutActionOnViewTransitionAction = f
            
            self.chatDisplayNode.historyNode.layoutActionOnViewTransition = ({ [weak self] transition in
                f()
                if let strongSelf = self, let validLayout = strongSelf.validLayout {
                    strongSelf.layoutActionOnViewTransitionAction = nil
                    
                    var mappedTransition: (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?)?
                    
                    let isScheduledMessages: Bool
                    if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        isScheduledMessages = true
                    } else {
                        isScheduledMessages = false
                    }
                    let duration: Double = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNodeImpl.animationDuration : 0.18
                    let curve: ContainedViewLayoutTransitionCurve = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNodeImpl.verticalAnimationCurve : .easeInOut
                    let controlPoints: (Float, Float, Float, Float) = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNodeImpl.verticalAnimationControlPoints : (0.5, 0.33, 0.0, 0.0)

                    let shouldUseFastMessageSendAnimation = strongSelf.chatDisplayNode.shouldUseFastMessageSendAnimation
                    
                    strongSelf.chatDisplayNode.containerLayoutUpdated(validLayout, navigationBarHeight: strongSelf.navigationLayout(layout: validLayout).navigationFrame.maxY, transition: .animated(duration: duration, curve: curve), listViewTransaction: { updateSizeAndInsets, _, _, _ in

                        var options = transition.options
                        let _ = options.insert(.Synchronous)
                        let _ = options.insert(.LowLatency)
                        let _ = options.insert(.PreferSynchronousResourceLoading)

                        var deleteItems = transition.deleteItems
                        var insertItems: [ListViewInsertItem] = []
                        var stationaryItemRange: (Int, Int)?
                        var scrollToItem: ListViewScrollToItem?

                        if shouldUseFastMessageSendAnimation {
                            options.remove(.AnimateInsertion)
                            options.insert(.RequestItemInsertionAnimations)

                            deleteItems = transition.deleteItems.map({ item in
                                return ListViewDeleteItem(index: item.index, directionHint: nil)
                            })

                            var maxInsertedItem: Int?
                            var insertedIndex: Int?
                            for i in 0 ..< transition.insertItems.count {
                                let item = transition.insertItems[i]
                                if item.directionHint == .Down && (maxInsertedItem == nil || maxInsertedItem! < item.index) {
                                    maxInsertedItem = item.index
                                }
                                insertedIndex = item.index
                                insertItems.append(ListViewInsertItem(index: item.index, previousIndex: item.previousIndex, item: item.item, directionHint: item.directionHint == .Down ? .Up : nil))
                            }

                            if isScheduledMessages, let insertedIndex = insertedIndex {
                                scrollToItem = ListViewScrollToItem(index: insertedIndex, position: .visible, animated: true, curve: .Custom(duration: duration, controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3), directionHint: .Down)
                            } else if transition.historyView.originalView.laterId == nil {
                                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Custom(duration: duration, controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3), directionHint: .Up)
                            }

                            if let maxInsertedItem = maxInsertedItem {
                                stationaryItemRange = (maxInsertedItem + 1, Int.max)
                            }
                        }
                        
                        mappedTransition = (ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: deleteItems, insertItems: insertItems, updateItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, scrolledToSomeIndex: transition.scrolledToSomeIndex, peerType: transition.peerType, networkType: transition.networkType, animateIn: false, reason: transition.reason, flashIndicators: transition.flashIndicators, animateFromPreviousFilter: false), updateSizeAndInsets)
                    }, updateExtraNavigationBarBackgroundHeight: { value, hitTestSlop, cutout, _ in
                        strongSelf.additionalNavigationBarBackgroundHeight = value
                        strongSelf.additionalNavigationBarHitTestSlop = hitTestSlop
                        strongSelf.additionalNavigationBarCutout = cutout
                    })
                    
                    if let mappedTransition = mappedTransition {
                        return mappedTransition
                    }
                }
                return (transition, nil)
            }, messageCorrelationId)
        }
        
        self.chatDisplayNode.sendMessages = { [weak self] messages, silentPosting, scheduleTime, isAnyMessageTextPartitioned, postpone in
            guard let strongSelf = self else {
                return
            }
            
            var correlationIds: [Int64] = []
            for message in messages {
                switch message {
                case let .message(_, _, _, _, _, _, _, _, correlationId, _):
                    if let correlationId = correlationId {
                        correlationIds.append(correlationId)
                    }
                default:
                    break
                }
            }
            strongSelf.commitPurposefulAction()
            
            if let peerId = strongSelf.chatLocation.peerId {
                var hasDisabledContent = false
                if "".isEmpty {
                    hasDisabledContent = false
                }
                
                if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                    let forwardCount = messages.reduce(0, { count, message -> Int in
                        if case .forward = message {
                            return count + 1
                        } else {
                            return count
                        }
                    })
                    
                    var errorText: String?
                    if forwardCount > 1 {
                        errorText = strongSelf.presentationData.strings.Chat_AttachmentMultipleForwardDisabled
                    } else if isAnyMessageTextPartitioned {
                        errorText = strongSelf.presentationData.strings.Chat_MultipleTextMessagesDisabled
                    } else if hasDisabledContent {
                        errorText = strongSelf.restrictedSendingContentsText()
                    }
                    
                    if let errorText = errorText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        return
                    }
                }
                
                let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting ?? false, scheduleTime: scheduleTime, postpone: postpone)
                
                var forwardedMessages: [[EnqueueMessage]] = []
                var forwardSourcePeerIds = Set<PeerId>()
                for message in transformedMessages {
                    if case let .forward(source, _, _, _, _) = message {
                        forwardSourcePeerIds.insert(source.peerId)
                        
                        var added = false
                        if var last = forwardedMessages.last {
                            if let currentMessage = last.first, case let .forward(currentSource, _, _, _, _) = currentMessage, currentSource.peerId == source.peerId {
                                last.append(message)
                                added = true
                            }
                        }
                        if !added {
                            forwardedMessages.append([message])
                        }
                    }
                }
                
                let _ = (strongSelf.shouldDivertMessagesToScheduled(messages: transformedMessages)
                |> deliverOnMainQueue).start(next: { shouldDivert in
                    let signal: Signal<[MessageId?], NoError>
                    var shouldOpenScheduledMessages = false
                    if forwardSourcePeerIds.count > 1 {
                        var forwardedMessages = forwardedMessages
                        if shouldDivert {
                            forwardedMessages = forwardedMessages.map { messageGroup -> [EnqueueMessage] in
                                return messageGroup.map { message -> EnqueueMessage in
                                    return message.withUpdatedAttributes { attributes in
                                        var attributes = attributes
                                        attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                                        attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(Date().timeIntervalSince1970) + 10 * 24 * 60 * 60))
                                        return attributes
                                    }
                                }
                            }
                            shouldOpenScheduledMessages = true
                        }
                        
                        var signals: [Signal<[MessageId?], NoError>] = []
                        for messagesGroup in forwardedMessages {
                            signals.append(enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messagesGroup))
                        }
                        signal = combineLatest(signals)
                        |> map { results in
                            var ids: [MessageId?] = []
                            for result in results {
                                ids.append(contentsOf: result)
                            }
                            return ids
                        }
                    } else {
                        var transformedMessages = transformedMessages
                        if shouldDivert {
                            transformedMessages = transformedMessages.map { message -> EnqueueMessage in
                                return message.withUpdatedAttributes { attributes in
                                    var attributes = attributes
                                    attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(Date().timeIntervalSince1970) + 10 * 24 * 60 * 60))
                                    return attributes
                                }
                            }
                            shouldOpenScheduledMessages = true
                        }
                        
                        signal = enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: transformedMessages)
                    }
                    
                    let _ = (signal
                    |> deliverOnMainQueue).startStandalone(next: { messageIds in
                        guard let strongSelf = self else {
                            return
                        }
                        if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        } else {
                            strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                            
                            if shouldOpenScheduledMessages {
                                if let layoutActionOnViewTransitionAction = strongSelf.layoutActionOnViewTransitionAction {
                                    strongSelf.layoutActionOnViewTransitionAction = nil
                                    layoutActionOnViewTransitionAction()
                                }
                            }
                        }
                    })
                    
                    donateSendMessageIntent(account: strongSelf.context.account, sharedContext: strongSelf.context.sharedContext, intentContext: .chat, peerIds: [peerId])
                })
            } else if case let .customChatContents(customChatContents) = strongSelf.subject {
                switch customChatContents.kind {
                case .hashTagSearch:
                    break
                case .quickReplyMessageInput:
                    customChatContents.enqueueMessages(messages: messages)
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                case let .businessLinkSetup(link):
                    if messages.count > 1 {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.BusinessLink_AlertTextLimitText, actions: [
                            TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                        ]), in: .window(.root))
                        
                        return
                    }
                    
                    var text: String = ""
                    var entities: [MessageTextEntity] = []
                    if let message = messages.first {
                        if case let .message(textValue, attributes, _, _, _, _, _, _, _, _) = message {
                            text = textValue
                            for attribute in attributes {
                                if let attribute = attribute as? TextEntitiesMessageAttribute {
                                    entities = attribute.entities
                                }
                            }
                        }
                    }
                    
                    let _ = strongSelf.context.engine.accountData.editBusinessChatLink(url: link.url, message: text, entities: entities, title: link.title).start()
                    if case let .customChatContents(customChatContents) = strongSelf.subject {
                        customChatContents.businessLinkUpdate(message: text, entities: entities, title: link.title)
                    }
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .succeed(text: strongSelf.presentationData.strings.Business_Links_EditLinkToastSaved, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            }
            strongSelf.updateChatPresentationInterfaceState(interactive: true, { $0.updatedShowCommands(false) })
        }
        
        if case let .customChatContents(customChatContents) = self.subject {
            customChatContents.hashtagSearchResultsUpdate = { [weak self] searchResult in
                guard let self else {
                    return
                }
                let (results, state) = searchResult
                let isEmpty = results.totalCount == 0
                if isEmpty {
                    self.alwaysShowSearchResultsAsList = true
                }
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    var updatedState = current
                    if let data = current.search {
                        let messageIndices = results.messages.map({ $0.index }).sorted()
                        var currentIndex = messageIndices.last
                        if let previousResultId = data.resultsState?.currentId {
                            for index in messageIndices {
                                if index.id >= previousResultId {
                                    currentIndex = index
                                break
                                }
                            }
                        }
                        updatedState = updatedState.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: state, totalCount: results.totalCount, completed: results.completed)))
                    }
                    if isEmpty {
                        updatedState = updatedState.updatedDisplayHistoryFilterAsList(true)
                    }
                    return updatedState
                })
                self.searchResult.set(.single((results, state, .general(scope: .channels, tags: nil, minDate: nil, maxDate: nil))))
            }
        }
        
        self.chatDisplayNode.requestUpdateChatInterfaceState = { [weak self] transition, saveInterfaceState, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: true, saveInterfaceState: saveInterfaceState, { $0.updatedInterfaceState(f) })
        }
        
        self.chatDisplayNode.requestUpdateInterfaceState = { [weak self] transition, interactive, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: interactive, f)
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.updateShowWebView { _ in
                return false
            }
            if strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                if let rect = strongSelf.chatDisplayNode.frameForAttachmentButton() {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(strongSelf.chatDisplayNode.view, rect)
                }
                return
            }
            if let messageId = strongSelf.presentationInterfaceState.interfaceState.editMessage?.messageId {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).startStandalone(next: { message in
                    guard let strongSelf = self, let editMessageState = strongSelf.presentationInterfaceState.editMessageState else {
                        return
                    }
                    var originalMediaReference: AnyMediaReference?
                    if let message = message {
                        for media in message.media {
                            if let image = media as? TelegramMediaImage {
                                originalMediaReference = .message(message: MessageReference(message._asMessage()), media: image)
                            } else if let file = media as? TelegramMediaFile {
                                if file.isVideo || file.isAnimated {
                                    originalMediaReference = .message(message: MessageReference(message._asMessage()), media: file)
                                }
                            }
                        }
                    }
                    var editMediaOptions: MessageMediaEditingOptions?
                    if case let .media(options) = editMessageState.content {
                        editMediaOptions = options
                    }
                    strongSelf.presentEditingAttachmentMenu(editMediaOptions: editMediaOptions, editMediaReference: originalMediaReference)
                })
            } else {
                strongSelf.presentAttachmentMenu(subject: .default)
            }
        }
        self.chatDisplayNode.paste = { [weak self] data in
            switch data {
            case let .images(images):
                self?.displayPasteMenu(images.map { .image($0) })
            case let .video(data):
                let tempFilePath = NSTemporaryDirectory() + "\(Int64.random(in: 0...Int64.max)).mp4"
                let url = NSURL(fileURLWithPath: tempFilePath) as URL
                try? data.write(to: url)
                self?.displayPasteMenu([.video(url)])
            case let .gif(data):
                self?.enqueueGifData(data)
            case let .sticker(image, isMemoji):
                self?.enqueueStickerImage(image, isMemoji: isMemoji)
            case let .animatedSticker(data):
                self?.enqueueAnimatedStickerData(data)
            }
        }
        self.chatDisplayNode.updateTypingActivity = { [weak self] value in
            if let strongSelf = self {
                if value {
                    strongSelf.typingActivityPromise.set(Signal<Bool, NoError>.single(true)
                    |> then(
                        Signal<Bool, NoError>.single(false)
                        |> delay(4.0, queue: Queue.mainQueue())
                    ))
                    
                    if !strongSelf.didDisplayGroupEmojiTip, value {
                        strongSelf.didDisplayGroupEmojiTip = true
                        
                        Queue.mainQueue().after(2.0) {
                            strongSelf.displayGroupEmojiTooltip()
                        }
                    }
                    
                    if !strongSelf.didDisplaySendWhenOnlineTip, value {
                        strongSelf.didDisplaySendWhenOnlineTip = true
                        
                        strongSelf.displaySendWhenOnlineTipDisposable.set(
                            (strongSelf.typingActivityPromise.get()
                            |> filter { !$0 }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] _ in
                                if let strongSelf = self {
                                    Queue.mainQueue().after(2.0) {
                                        strongSelf.displaySendWhenOnlineTooltip()
                                    }
                                }
                            })
                        )
                    }
                } else {
                    strongSelf.typingActivityPromise.set(.single(false))
                }
            }
        }
        
        self.chatDisplayNode.dismissUrlPreview = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.interfaceState.editMessage {
                    if let link = strongSelf.presentationInterfaceState.editingUrlPreview?.url {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { presentationInterfaceState in
                            return presentationInterfaceState.updatedInterfaceState { interfaceState in
                                return interfaceState.withUpdatedEditMessage(interfaceState.editMessage.flatMap { editMessage in
                                    var editMessage = editMessage
                                    if !editMessage.disableUrlPreviews.contains(link) {
                                        editMessage.disableUrlPreviews.append(link)
                                    }
                                    return editMessage
                                })
                            }
                        })
                    }
                } else {
                    if let link = strongSelf.presentationInterfaceState.urlPreview?.url {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { presentationInterfaceState in
                            return presentationInterfaceState.updatedInterfaceState { interfaceState in
                                var composeDisableUrlPreviews = interfaceState.composeDisableUrlPreviews
                                if !composeDisableUrlPreviews.contains(link) {
                                    composeDisableUrlPreviews.append(link)
                                }
                                return interfaceState.withUpdatedComposeDisableUrlPreviews(composeDisableUrlPreviews)
                            }
                        })
                    }
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.downPressed = { [weak self] in
            guard let self else {
                return
            }
            
            if case let .customChatContents(contents) = self.presentationInterfaceState.subject, case .hashTagSearch = contents.kind {
                self.chatDisplayNode.historyNode.scrollToEndOfHistory()
            } else if let resultsState = self.presentationInterfaceState.search?.resultsState, !resultsState.messageIndices.isEmpty {
                if let currentId = resultsState.currentId, let index = resultsState.messageIndices.firstIndex(where: { $0.id == currentId }) {
                    if index != resultsState.messageIndices.count - 1 {
                        self.interfaceInteraction?.navigateMessageSearch(.later)
                    } else {
                        self.scrollToEndOfHistory()
                    }
                } else {
                    self.scrollToEndOfHistory()
                }
            } else {
                if let messageId = self.contentData?.historyNavigationStack.removeLast() {
                    self.navigateToMessage(from: nil, to: .id(messageId.id, NavigateToMessageParams(timestamp: nil, quote: nil)), rememberInStack: false)
                } else {
                    if case .known = self.chatDisplayNode.historyNode.visibleContentOffset() {
                        self.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    } else if case .peer = self.chatLocation {
                        self.scrollToEndOfHistory()
                    } else if case .replyThread = self.chatLocation {
                        self.scrollToEndOfHistory()
                    } else {
                        self.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                }
            }
        }
        self.chatDisplayNode.navigateButtons.upPressed = { [weak self] in
            guard let self else {
                return
            }
            
            if self.presentationInterfaceState.search?.resultsState != nil {
                self.interfaceInteraction?.navigateMessageSearch(.earlier)
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, let peerId = strongSelf.chatLocation.peerId {
                let signal = strongSelf.context.engine.messages.earliestUnseenPersonalMentionMessage(peerId: peerId, threadId: strongSelf.chatLocation.threadId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)))
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsButton.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                gesture.cancel()
                return
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var menuItems: [ContextMenuItem] = []
            menuItems.append(.action(ContextMenuActionItem(
                id: nil,
                text: strongSelf.presentationData.strings.WebSearch_RecentSectionClear,
                textColor: .primary,
                textLayout: .singleLine,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Read"), color: theme.contextMenu.primaryColor)
                },
                action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId else {
                        return
                    }
                    let _ = clearPeerUnseenPersonalMessagesInteractively(account: strongSelf.context.account, peerId: peerId, threadId: strongSelf.chatLocation.threadId).startStandalone()
                }
            )))
            let items = ContextController.Items(content: .list(menuItems))
            
            let controller = ContextController(presentationData: strongSelf.presentationData, source: .extracted(ChatMessageNavigationButtonContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, contentNode: strongSelf.chatDisplayNode.navigateButtons.mentionsButton.containerNode)), items: .single(items), recognizer: nil, gesture: gesture)
            
            strongSelf.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            })
            strongSelf.window?.presentInGlobalOverlay(controller)
        }
        
        self.chatDisplayNode.navigateButtons.reactionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, let peerId = strongSelf.chatLocation.peerId {
                let signal = strongSelf.context.engine.messages.earliestUnseenPersonalReactionMessage(peerId: peerId, threadId: strongSelf.chatLocation.threadId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.chatDisplayNode.historyNode.suspendReadingReactions = true
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), scrollPosition: .center(.top), completion: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                            guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item else {
                                                return
                                            }
                                            guard item.message.id == messageId else {
                                                return
                                            }
                                            var maybeUpdatedReaction: (MessageReaction.Reaction, Bool, EnginePeer?)?
                                            if let attribute = item.message.reactionsAttribute {
                                                for recentPeer in attribute.recentPeers {
                                                    if recentPeer.isUnseen {
                                                        maybeUpdatedReaction = (recentPeer.value, recentPeer.isLarge, item.message.peers[recentPeer.peerId].flatMap(EnginePeer.init))
                                                        break
                                                    }
                                                }
                                            }
                                            
                                            guard let (updatedReaction, updatedReactionIsLarge, updatedReactionPeer) = maybeUpdatedReaction else {
                                                return
                                            }
                                            
                                            guard let availableReactions = item.associatedData.availableReactions else {
                                                return
                                            }
                                            
                                            var avatarPeers: [EnginePeer] = []
                                            if item.message.id.peerId.namespace != Namespaces.Peer.CloudUser, let updatedReactionPeer = updatedReactionPeer {
                                                avatarPeers.append(updatedReactionPeer)
                                            }
                                            
                                            var reactionItem: ReactionItem?
                                            
                                            switch updatedReaction {
                                            case .builtin, .stars:
                                                for reaction in availableReactions.reactions {
                                                    guard let centerAnimation = reaction.centerAnimation else {
                                                        continue
                                                    }
                                                    guard let aroundAnimation = reaction.aroundAnimation else {
                                                        continue
                                                    }
                                                    if reaction.value == updatedReaction {
                                                        reactionItem = ReactionItem(
                                                            reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                                            appearAnimation: reaction.appearAnimation,
                                                            stillAnimation: reaction.selectAnimation,
                                                            listAnimation: centerAnimation,
                                                            largeListAnimation: reaction.activateAnimation,
                                                            applicationAnimation: aroundAnimation,
                                                            largeApplicationAnimation: reaction.effectAnimation,
                                                            isCustom: false
                                                        )
                                                        break
                                                    }
                                                }
                                            case let .custom(fileId):
                                                if let itemFile = item.message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                                                    let itemFile = TelegramMediaFile.Accessor(itemFile)
                                                    reactionItem = ReactionItem(
                                                        reaction: ReactionItem.Reaction(rawValue: updatedReaction),
                                                        appearAnimation: itemFile,
                                                        stillAnimation: itemFile,
                                                        listAnimation: itemFile,
                                                        largeListAnimation: itemFile,
                                                        applicationAnimation: nil,
                                                        largeApplicationAnimation: nil,
                                                        isCustom: true
                                                    )
                                                }
                                            }
                                            
                                            guard let targetView = itemNode.targetReactionView(value: updatedReaction) else {
                                                return
                                            }
                                            if let reactionItem = reactionItem {
                                                let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: strongSelf.chatDisplayNode.historyNode.takeGenericReactionEffect())
                                                
                                                strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                
                                                strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                                standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                standaloneReactionAnimation.animateReactionSelection(
                                                    context: strongSelf.context,
                                                    theme: strongSelf.presentationData.theme,
                                                    animationCache: strongSelf.controllerInteraction!.presentationContext.animationCache,
                                                    reaction: reactionItem,
                                                    avatarPeers: avatarPeers,
                                                    playHaptic: true,
                                                    isLarge: updatedReactionIsLarge,
                                                    targetView: targetView,
                                                    addStandaloneReactionAnimation: { standaloneReactionAnimation in
                                                        guard let strongSelf = self else {
                                                            return
                                                        }
                                                        strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                        standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                        strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                                    },
                                                    completion: { [weak standaloneReactionAnimation] in
                                                        standaloneReactionAnimation?.removeFromSupernode()
                                                    }
                                                )
                                            }
                                        }
                                        
                                        strongSelf.chatDisplayNode.historyNode.suspendReadingReactions = false
                                    })
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        self.chatDisplayNode.navigateButtons.reactionsButton.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                gesture.cancel()
                return
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var menuItems: [ContextMenuItem] = []
            menuItems.append(.action(ContextMenuActionItem(
                id: nil,
                text: strongSelf.presentationData.strings.Conversation_ReadAllReactions,
                textColor: .primary,
                textLayout: .singleLine,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Read"), color: theme.contextMenu.primaryColor)
                },
                action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId else {
                        return
                    }
                    let _ = clearPeerUnseenReactionsInteractively(account: strongSelf.context.account, peerId: peerId, threadId: strongSelf.chatLocation.threadId).startStandalone()
                }
            )))
            let items = ContextController.Items(content: .list(menuItems))
            
            let controller = ContextController(presentationData: strongSelf.presentationData, source: .extracted(ChatMessageNavigationButtonContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, contentNode: strongSelf.chatDisplayNode.navigateButtons.reactionsButton.containerNode)), items: .single(items), recognizer: nil, gesture: gesture)
            
            strongSelf.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            })
            strongSelf.window?.presentInGlobalOverlay(controller)
        }
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { [weak self] messageId, completion in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            
            guard !strongSelf.presentAccountFrozenInfoIfNeeded(delay: true) else {
                completion(.immediate, {})
                return
            }
            
            if let messageId = messageId {
                let intrinsicCanSendMessagesHere = canSendMessagesToChat(strongSelf.presentationInterfaceState)
                var canSendMessagesHere = intrinsicCanSendMessagesHere
                if case .standard(.embedded) = strongSelf.presentationInterfaceState.mode {
                    canSendMessagesHere = false
                }
                if case .inline = strongSelf.presentationInterfaceState.mode {
                    canSendMessagesHere = false
                }
                
                if canSendMessagesHere {
                    let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                        if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({
                                $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(
                                    messageId: message.id,
                                    quote: nil
                                ))
                            }).updatedReplyMessage(message).updatedSearch(nil).updatedShowCommands(false) }, completion: { t in
                                completion(t, {})
                            })
                            strongSelf.updateItemNodesSearchTextHighlightStates()
                            if !strongSelf.chatDisplayNode.ensureInputViewFocused() {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.chatDisplayNode.ensureInputViewFocused()
                                }
                            }
                        } else {
                            completion(.immediate, {})
                        }
                    }, alertAction: {
                        completion(.immediate, {})
                    }, delay: true)
                } else {
                    let replySubject = ChatInterfaceState.ReplyMessageSubject(
                        messageId: messageId,
                        quote: nil
                    )
                    
                    completion(.immediate, {
                        guard let self else {
                            return
                        }
                        if intrinsicCanSendMessagesHere {
                            if let peerId = self.chatLocation.peerId {
                                moveReplyToChat(selfController: self, peerId: peerId, threadId: self.chatLocation.threadId, replySubject: replySubject, completion: {})
                            }
                        } else {
                            moveReplyMessageToAnotherChat(selfController: self, replySubject: replySubject)
                        }
                    })
                }
            } else {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }) }, completion: { t in
                    completion(t, {})
                })
            }
        }, setupEditMessage: { [weak self] messageId, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                guard let messageId = messageId else {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        var state = state
                        state = state.updatedInterfaceState {
                            $0.withUpdatedEditMessage(nil)
                        }
                        state = state.updatedEditMessageState(nil)
                        return state
                    }, completion: completion)
                    
                    return
                }
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            var entities: [MessageTextEntity] = []
                            for attribute in message.attributes {
                                if let attribute = attribute as? TextEntitiesMessageAttribute {
                                    entities = attribute.entities
                                    break
                                }
                            }
                            var inputTextMaxLength: Int32 = 4096
                            var webpageUrl: String?
                            for media in message.media {
                                if media is TelegramMediaImage || media is TelegramMediaFile {
                                    inputTextMaxLength = strongSelf.context.userLimits.maxCaptionLength
                                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                    webpageUrl = content.url
                                }
                            }
                            
                            let inputText = chatInputStateStringWithAppliedEntities(message.text, entities: entities)
                            var disableUrlPreviews: [String] = []
                            if webpageUrl == nil {
                                disableUrlPreviews = detectUrls(inputText)
                            }
                            
                            var updated = state.updatedInterfaceState { interfaceState in
                                return interfaceState.withUpdatedEditMessage(ChatEditMessageState(messageId: messageId, inputState: ChatTextInputState(inputText: inputText), disableUrlPreviews: disableUrlPreviews, inputTextMaxLength: inputTextMaxLength, mediaCaptionIsAbove: nil))
                            }
                            
                            let (updatedState, updatedPreviewQueryState) = updatedChatEditInterfaceMessageState(context: strongSelf.context, state: updated, message: message)
                            updated = updatedState
                            strongSelf.editingUrlPreviewQueryState?.1.dispose()
                            strongSelf.editingUrlPreviewQueryState = updatedPreviewQueryState
                            
                            updated = updated.updatedInputMode({ _ in
                                return .text
                            })
                            updated = updated.updatedShowCommands(false)
                            
                            return updated
                        }, completion: completion)
                    }
                }, alertAction: {
                    completion(.immediate)
                }, delay: true)
            }
        }, beginMessageSelection: { [weak self] messageIds, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedSelectedMessages(messageIds) }.updatedShowCommands(false) }, completion: completion)
                    
                    if let selectionState = strongSelf.presentationInterfaceState.interfaceState.selectionState {
                        let count = selectionState.selectedIds.count
                        let text = strongSelf.presentationData.strings.VoiceOver_Chat_MessagesSelected(Int32(count))
                        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: text)
                    }
                }, alertAction: {
                    completion(.immediate)
                }, delay: true)
            } else {
                completion(.immediate)
            }
        }, cancelMessageSelection: { [weak self] transition in
            guard let self else {
                return
            }
            self.updateChatPresentationInterfaceState(transition: transition, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds, keepUpdated: false)
                    |> deliverOnMainQueue).startStrict(next: { actions in
                        if let strongSelf = self, !actions.options.isEmpty {
                            if let banAuthor = actions.banAuthor {
                                strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                            } else if !actions.banAuthors.isEmpty {
                                strongSelf.presentMultiBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, authors: actions.banAuthors, messageIds: messageIds, options: actions.options)
                            } else {
                                if actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
                                    strongSelf.presentClearCacheSuggestion()
                                } else {
                                    strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: actions.options, contextController: nil, completion: { _ in })
                                }
                            }
                        }
                    }))
                }
            }
        }, reportSelectedMessages: { [weak self] in
            if let strongSelf = self, let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                if let reportReason = strongSelf.presentationInterfaceState.reportReason {
                    let presentationData = strongSelf.presentationData
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } }, completion: { _ in
                        let _ = (strongSelf.context.engine.messages.reportContent(subject: .messages(Array(messageIds)), option: reportReason.option, message: reportReason.message)
                        |> deliverOnMainQueue).startStandalone(completed: {
                            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                        })
                    })
                } else {
                    strongSelf.context.sharedContext.makeContentReportScreen(
                        context: strongSelf.context,
                        subject: .messages(Array(messageIds).sorted()),
                        forceDark: false,
                        present: { [weak self] controller in
                            self?.push(controller)
                        },
                        completion: { [weak self] in
                            self?.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        },
                        requestSelectMessages: nil
                    )
                }
            }
        }, reportMessages: { [weak self] messages, contextController in
            guard let self, !messages.isEmpty else {
                return
            }
            contextController?.dismiss()
            self.context.sharedContext.makeContentReportScreen(
                context: self.context,
                subject: .messages(messages.map({ $0.id }).sorted()),
                forceDark: false,
                present: { [weak self] controller in
                    guard let self else {
                        return
                    }
                    self.push(controller)
                },
                completion: {},
                requestSelectMessages: nil
            )
        }, blockMessageAuthor: { [weak self] message, contextController in
            contextController?.dismiss(completion: {
                guard let strongSelf = self else {
                    return
                }
                
                let author = message.forwardInfo?.author
                
                guard let peer = author else {
                    return
                }
                
                let presentationData = strongSelf.presentationData
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                var reportSpam = true
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(EnginePeer(peer).compactDisplayTitle).string))
                items.append(contentsOf: [
                    ActionSheetCheckboxItem(title: presentationData.strings.Conversation_Moderate_Report, label: "", value: reportSpam, action: { [weak controller] checkValue in
                        reportSpam = checkValue
                        controller?.updateItem(groupIndex: 0, itemIndex: 1, { item in
                            if let item = item as? ActionSheetCheckboxItem {
                                return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                            }
                            return item
                        })
                    }),
                    ActionSheetButtonItem(title: presentationData.strings.Replies_BlockAndDeleteRepliesActionTitle, color: .destructive, action: {
                        dismissAction()
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).startStandalone()
                        let context = strongSelf.context
                        let _ = context.engine.messages.deleteAllMessagesWithForwardAuthor(peerId: message.id.peerId, forwardAuthorId: peer.id, namespace: Namespaces.Message.Cloud).startStandalone()
                        let _ = strongSelf.context.engine.peers.reportRepliesMessage(messageId: message.id, deleteMessage: true, deleteHistory: true, reportSpam: reportSpam).startStandalone()
                    })
                ] as [ActionSheetItem])
                
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        }, deleteMessages: { [weak self] messages, contextController, completion in
            if let strongSelf = self, !messages.isEmpty {
                guard !strongSelf.presentAccountFrozenInfoIfNeeded(delay: true) else {
                    completion(.default)
                    return
                }
                
                let messageIds = Set(messages.map { $0.id })
                strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds, keepUpdated: false)
                |> deliverOnMainQueue).startStrict(next: { actions in
                    if let strongSelf = self, !actions.options.isEmpty {
                        if let banAuthor = actions.banAuthor {
                            if let contextController = contextController {
                                contextController.dismiss(completion: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                                })
                            } else {
                                strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                                completion(.default)
                            }
                        } else {
                            var isAction = false
                            if messages.count == 1 {
                                for media in messages[0].media {
                                    if media is TelegramMediaAction {
                                        isAction = true
                                    }
                                }
                            }
                            if isAction && (actions.options == .deleteGlobally || actions.options == .deleteLocally) {
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: actions.options == .deleteLocally ? .forLocalPeer : .forEveryone).startStandalone()
                                completion(.dismissWithoutContent)
                            } else if (messages.first?.flags.isSending ?? false) {
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone, deleteAllInGroup: true).startStandalone()
                                completion(.dismissWithoutContent)
                            } else {
                                if actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
                                    strongSelf.presentClearCacheSuggestion()
                                    completion(.default)
                                } else {
                                    var isScheduled = false
                                    for id in messageIds {
                                        if Namespaces.Message.allScheduled.contains(id.namespace) {
                                            isScheduled = true
                                            break
                                        }
                                    }
                                    strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: isScheduled ? [.deleteLocally] : actions.options, contextController: contextController, completion: completion)
                                }
                            }
                        }
                    }
                }))
            }
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let forwardMessageIdsSet = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
                    strongSelf.forwardMessages(messageIds: forwardMessageIds)
                }
            }
        }, forwardCurrentForwardMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds {
                    strongSelf.forwardMessages(messageIds: forwardMessageIds, options: strongSelf.presentationInterfaceState.interfaceState.forwardOptionsState, resetCurrent: true)
                }
            }
        }, forwardMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                guard !strongSelf.presentAccountFrozenInfoIfNeeded(delay: true) else {
                    return
                }
                
                strongSelf.commitPurposefulAction()
                let forwardMessageIds = messages.map { $0.id }.sorted()
                strongSelf.forwardMessages(messageIds: forwardMessageIds)
            }
        }, updateForwardOptionsState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardOptionsState(f($0.forwardOptionsState ?? ChatInterfaceForwardOptionsState(hideNames: false, hideCaptions: false, unhideNamesOnCaptionChange: false))) }) })
            }
        }, presentForwardOptions: { [weak self] sourceNode in
            guard let self else {
                return
            }
            presentChatForwardOptions(selfController: self, sourceNode: sourceNode)
        }, presentReplyOptions: { [weak self] sourceNode in
            guard let self else {
                return
            }
            presentChatReplyOptions(selfController: self, sourceNode: sourceNode)
        }, presentLinkOptions: { [weak self] sourceNode in
            guard let self else {
                return
            }
            presentChatLinkOptions(selfController: self, sourceNode: sourceNode)
        }, shareSelectedMessages: { [weak self] in
            if let strongSelf = self, let selectedIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                strongSelf.commitPurposefulAction()
                let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                    selectedIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                ))
                |> map { messages -> [EngineMessage] in
                    return messages.values.compactMap { $0 }
                }
                |> deliverOnMainQueue).startStandalone(next: { messages in
                    if let strongSelf = self, !messages.isEmpty {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                        
                        let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                            return lhs.index < rhs.index
                        }).map { $0._asMessage() }), externalShare: true, immediateExternalShare: true, updatedPresentationData: strongSelf.updatedPresentationData)
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(shareController, in: .window(.root))
                    }
                })
            }
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                        }.updatedInputMode({ _ in updatedMode })
                })
                
                if !strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string.isEmpty {
                    strongSelf.silentPostTooltipController?.dismiss()
                }
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    var updated = $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
                    var dismissWebView = false
                    switch updatedInputMode {
                        case .text, .media, .inputButtons:
                            dismissWebView = true
                        default:
                            break
                    }
                    if dismissWebView {
                        updated = updated.updatedShowWebView(false)
                    }
                    return updated
                })
            }
        }, openStickers: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatDisplayNode.openStickers(beginWithEmoji: false)
            strongSelf.mediaRecordingModeTooltipController?.dismissImmediately()
        }, editMessage: { [weak self] in
            guard let strongSelf = self, let editMessage = strongSelf.presentationInterfaceState.interfaceState.editMessage else {
                return
            }
            
            let sourceMessage: Signal<EngineMessage?, NoError>
            sourceMessage = strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: editMessage.messageId))
            
            let _ = (sourceMessage
            |> deliverOnMainQueue).start(next: { [weak strongSelf] message in
                guard let strongSelf, let message else {
                    return
                }
                
                var disableUrlPreview = false
                
                var webpage: TelegramMediaWebpage?
                var webpagePreviewAttribute: WebpagePreviewMessageAttribute?
                if let urlPreview = strongSelf.presentationInterfaceState.editingUrlPreview {
                    if editMessage.disableUrlPreviews.contains(urlPreview.url) {
                        disableUrlPreview = true
                    } else {
                        webpage = urlPreview.webPage
                        webpagePreviewAttribute = WebpagePreviewMessageAttribute(leadingPreview: !urlPreview.positionBelowText, forceLargeMedia: urlPreview.largeMedia, isManuallyAdded: true, isSafe: false)
                    }
                }
                
                var invertedMediaAttribute: InvertMediaMessageAttribute?
                if let attribute = message.attributes.first(where: { $0 is InvertMediaMessageAttribute }) {
                    invertedMediaAttribute = attribute as? InvertMediaMessageAttribute
                }
                
                if let mediaCaptionIsAbove = editMessage.mediaCaptionIsAbove {
                    if mediaCaptionIsAbove {
                        invertedMediaAttribute = InvertMediaMessageAttribute()
                    } else {
                        invertedMediaAttribute = nil
                    }
                }
                
                let text = trimChatInputText(convertMarkdownToAttributes(expandedInputStateAttributedString(editMessage.inputState.inputText)))
                
                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if !entities.isEmpty {
                    entitiesAttribute = TextEntitiesMessageAttribute(entities: entities)
                }
                
                var inlineStickers: [MediaId: TelegramMediaFile] = [:]
                var firstLockedPremiumEmoji: TelegramMediaFile?
                text.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: text.length), using: { value, _, _ in
                    if let value = value as? ChatTextInputTextCustomEmojiAttribute {
                        if let file = value.file {
                            inlineStickers[file.fileId] = file
                            if file.isPremiumEmoji && !strongSelf.presentationInterfaceState.isPremium && strongSelf.chatLocation.peerId != strongSelf.context.account.peerId {
                                if firstLockedPremiumEmoji == nil {
                                    firstLockedPremiumEmoji = file
                                }
                            }
                        }
                    }
                })
                
                if let firstLockedPremiumEmoji = firstLockedPremiumEmoji {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.controllerInteraction?.displayUndo(.sticker(context: strongSelf.context, file: firstLockedPremiumEmoji, loop: true, title: nil, text: presentationData.strings.EmojiInput_PremiumEmojiToast_Text, undoText: presentationData.strings.EmojiInput_PremiumEmojiToast_Action, customAction: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.chatDisplayNode.dismissTextInput()
                        
                        let context = strongSelf.context
                        var replaceImpl: ((ViewController) -> Void)?
                        let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .animatedEmoji, forceDark: false, action: {
                            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .animatedEmoji, forceDark: false, dismissed: nil)
                            replaceImpl?(controller)
                        }, dismissed: nil)
                        replaceImpl = { [weak controller] c in
                            controller?.replace(with: c)
                        }
                        strongSelf.push(controller)
                    }))
                    
                    return
                }
                
                if text.length == 0 {
                    if strongSelf.presentationInterfaceState.editMessageState?.mediaReference != nil {
                    } else if message.media.contains(where: { media in
                        switch media {
                        case _ as TelegramMediaImage, _ as TelegramMediaFile, _ as TelegramMediaMap:
                            return true
                        default:
                            return false
                        }
                    }) {
                    } else {
                        if strongSelf.recordingModeFeedback == nil {
                            strongSelf.recordingModeFeedback = HapticFeedback()
                            strongSelf.recordingModeFeedback?.prepareError()
                        }
                        strongSelf.recordingModeFeedback?.error()
                        return
                    }
                }
                
                var updatingMedia = false
                let media: RequestEditMessageMedia
                if let editMediaReference = strongSelf.presentationInterfaceState.editMessageState?.mediaReference {
                    media = .update(editMediaReference)
                    updatingMedia = true
                } else if let webpage {
                    media = .update(.standalone(media: webpage))
                } else {
                    media = .keep
                }
                
                let _ = (strongSelf.context.account.postbox.messageAtId(editMessage.messageId)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] currentMessage in
                    if let strongSelf = self {
                        if let currentMessage = currentMessage {
                            let currentEntities = currentMessage.textEntitiesAttribute?.entities ?? []
                            let currentWebpagePreviewAttribute = currentMessage.webpagePreviewAttribute ?? WebpagePreviewMessageAttribute(leadingPreview: false, forceLargeMedia: nil, isManuallyAdded: true, isSafe: false)
                            
                            if currentMessage.text != text.string || currentEntities != entities || updatingMedia || webpagePreviewAttribute != currentWebpagePreviewAttribute || disableUrlPreview {
                                strongSelf.context.account.pendingUpdateMessageManager.add(messageId: editMessage.messageId, text: text.string, media: media, entities: entitiesAttribute, inlineStickers: inlineStickers, webpagePreviewAttribute: webpagePreviewAttribute, invertMediaAttribute: invertedMediaAttribute, disableUrlPreview: disableUrlPreview)
                            }
                        }
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            var state = state
                            state = state.updatedInterfaceState({ $0.withUpdatedEditMessage(nil) })
                            state = state.updatedEditMessageState(nil)
                            return state
                        })
                    }
                })
            })
        }, beginMessageSearch: { [weak self] domain, query in
            guard let strongSelf = self else {
                return
            }
            
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                var interactive = true
                if strongSelf.chatDisplayNode.isInputViewFocused {
                    interactive = false
                    strongSelf.context.sharedContext.mainWindow?.doNotAnimateLikelyKeyboardAutocorrectionSwitch()
                }
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: interactive, { current in
                    return current.updatedSearch(current.search == nil ? ChatSearchData(domain: domain).withUpdatedQuery(query) : current.search?.withUpdatedDomain(domain).withUpdatedQuery(query))
                }, completion: { [weak strongSelf] _ in
                    guard let strongSelf else {
                        return
                    }
                    strongSelf.chatDisplayNode.searchNavigationNode?.activate()
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
            })
        }, dismissMessageSearch: { [weak self] in
            guard let self else {
                return
            }
            
            if let customDismissSearch = self.customDismissSearch {
                customDismissSearch()
                return
            }
                
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                return current.updatedSearch(nil).updatedHistoryFilter(nil)
            })
            self.updateItemNodesSearchTextHighlightStates()
            self.searchResultsController = nil
        }, updateMessageSearch: { [weak self] query in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search {
                        return current.updatedSearch(data.withUpdatedQuery(query))
                    } else {
                        return current
                    }
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
                strongSelf.searchResultsController = nil
            }
        }, openSearchResults: { [weak self] in
            if let strongSelf = self, let searchData = strongSelf.presentationInterfaceState.search, let _ = searchData.resultsState {
                if let controller = strongSelf.searchResultsController {
                    strongSelf.chatDisplayNode.dismissInput()
                    if case let .inline(navigationController) = strongSelf.presentationInterfaceState.mode {
                        navigationController?.pushViewController(controller)
                    } else {
                        strongSelf.push(controller)
                    }
                } else {
                    let _ = (strongSelf.searchResult.get()
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] searchResult in
                        if let strongSelf = self, let (searchResult, searchState, searchLocation) = searchResult {
                            let controller = ChatSearchResultsController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, location: searchLocation, searchQuery: searchData.query, searchResult: searchResult, searchState: searchState, navigateToMessageIndex: { index in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.interfaceInteraction?.navigateMessageSearch(.index(index))
                            }, resultsUpdated: { results, state in
                                guard let strongSelf = self else {
                                    return
                                }
                                let updatedValue: (SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)? = (results, state, searchLocation)
                                strongSelf.searchResult.set(.single(updatedValue))
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                    if let data = current.search {
                                        let messageIndices = results.messages.map({ $0.index }).sorted()
                                        var currentIndex = messageIndices.last
                                        if let previousResultId = data.resultsState?.currentId {
                                            for index in messageIndices {
                                                if index.id >= previousResultId {
                                                    currentIndex = index
                                                    break
                                                }
                                            }
                                        }
                                        return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: state, totalCount: results.totalCount, completed: results.completed)))
                                    } else {
                                        return current
                                    }
                                })
                            })
                            strongSelf.chatDisplayNode.dismissInput()
                            if case let .inline(navigationController) = strongSelf.presentationInterfaceState.mode {
                                navigationController?.pushViewController(controller)
                            } else {
                                strongSelf.push(controller)
                            }
                            strongSelf.searchResultsController = controller
                        }
                    })
                }
            }
        }, navigateMessageSearch: { [weak self] action in
            if let strongSelf = self {
                var navigateIndex: MessageIndex?
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search, let resultsState = data.resultsState {
                        if let currentId = resultsState.currentId, let index = resultsState.messageIndices.firstIndex(where: { $0.id == currentId }) {
                            var updatedIndex: Int?
                            switch action {
                                case .earlier:
                                    if index != 0 {
                                        updatedIndex = index - 1
                                    }
                                case .later:
                                    if index != resultsState.messageIndices.count - 1 {
                                        updatedIndex = index + 1
                                    }
                                case let .index(index):
                                    if index >= 0 && index < resultsState.messageIndices.count {
                                        updatedIndex = index
                                    }
                            }
                            if let updatedIndex = updatedIndex {
                                navigateIndex = resultsState.messageIndices[updatedIndex]
                                return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: resultsState.messageIndices, currentId: resultsState.messageIndices[updatedIndex].id, state: resultsState.state, totalCount: resultsState.totalCount, completed: resultsState.completed)))
                            }
                        }
                    }
                    return current
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
                if let navigateIndex = navigateIndex {
                    switch strongSelf.chatLocation {
                    case .peer, .replyThread, .customChatContents:
                        strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                    }
                }
            }
        }, openCalendarSearch: { [weak self] in
            self?.openCalendarSearch(timestamp: Int32(Date().timeIntervalSince1970))
        }, toggleMembersSearch: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    if value {
                        return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                    } else if let search = state.search {
                        switch search.domain {
                        case .everything, .tag:
                            return state
                        case .members:
                            return state.updatedSearch(ChatSearchData(query: "", domain: .everything, domainSuggestionContext: .none, resultsState: nil))
                        case .member:
                            return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                        }
                    } else {
                        return state
                    }
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
            }
        }, navigateToMessage: { [weak self] messageId, dropStack, forceInCurrentChat, statusSubject in
            self?.navigateToMessage(from: nil, to: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), forceInCurrentChat: forceInCurrentChat, dropStack: dropStack, statusSubject: statusSubject)
        }, navigateToChat: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStandalone(next: { peer in
                guard let peer = peer else {
                    return
                }
                guard let strongSelf = self else {
                    return
                }
                
                if let navigationController = strongSelf.effectiveNavigationController {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: nil, keepStack: .always))
                }
            })
        }, navigateToProfile: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStandalone(next: { peer in
                if let strongSelf = self, let peer = peer {
                    strongSelf.openPeer(peer: peer, navigation: .default, fromMessage: nil)
                }
            })
        }, openPeerInfo: { [weak self] in
            self?.navigationButtonAction(.openChatInfo(expandAvatar: false, section: nil))
        }, togglePeerNotifications: { [weak self] in
            if let strongSelf = self, let peerId = strongSelf.chatLocation.peerId {
                let _ = strongSelf.context.engine.peers.togglePeerMuted(peerId: peerId, threadId: strongSelf.chatLocation.threadId).startStandalone()
            }
        }, sendContextResult: { [weak self] results, result, node, rect in
            guard let strongSelf = self else {
                return false
            }
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(node.view, rect)
                return false
            }
            strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.enqueueChatContextResult(results, result, postpone: postpone)
            })
            return true
        }, sendBotCommand: { [weak self] botPeer, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    let messageText: String
                    if let addressName = botPeer.addressName {
                        if peer is TelegramUser {
                            messageText = command
                        } else {
                            messageText = command + "@" + addressName
                        }
                    } else {
                        messageText = command
                    }
                    let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()
                            
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreviews([]) }
                            })
                        }
                    }, nil)
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(messageText, enabledTypes: .all)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    strongSelf.sendMessages([.message(text: messageText, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                    strongSelf.interfaceInteraction?.updateShowCommands { _ in
                        return false
                    }
                }
            }
        }, sendShortcut: { [weak self] shortcutId in
            guard let self else {
                return
            }
            guard let peerId = self.chatLocation.peerId else {
                return
            }
            
            self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreviews([]) }
            })
            
            if !self.presentationInterfaceState.isPremium {
                let controller = PremiumIntroScreen(context: self.context, source: .settings)
                self.push(controller)
                return
            }
            
            self.context.engine.accountData.sendMessageShortcut(peerId: peerId, id: shortcutId)
            
            /*self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                guard let self else {
                    return
                }
                self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreviews([]) }
                })
            }, nil)
            
            var messages: [EnqueueMessage] = []
            do {
                let message = shortcut.topMessage
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(message.text, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                
                messages.append(.message(
                    text: message.text,
                    attributes: attributes,
                    inlineStickers: [:],
                    mediaReference: message.media.first.flatMap { AnyMediaReference.standalone(media: $0) },
                    threadId: self.chatLocation.threadId,
                    replyToMessageId: nil,
                    replyToStoryId: nil,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                ))
            }
            
            self.sendMessages(messages)*/
        }, openEditShortcuts: { [weak self] in
            guard let self else {
                return
            }
            let _ = (self.context.sharedContext.makeQuickReplySetupScreenInitialData(context: self.context)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] initialData in
                guard let self else {
                    return
                }
                
                let controller = self.context.sharedContext.makeQuickReplySetupScreen(context: self.context, initialData: initialData)
                controller.navigationPresentation = .modal
                self.push(controller)
            })
        }, sendBotStart: { [weak self] payload in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.startBot(payload)
            }
        }, botSwitchChatWithPayload: { [weak self] peerId, payload in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                var isScheduled = false
                if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                    isScheduled = true
                }
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).startStandalone(next: { peer in
                    if let strongSelf = self, let peer = peer {
                        strongSelf.openPeer(peer: peer, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .automatic(returnToPeerId: currentPeerId, scheduled: isScheduled))), fromMessage: nil)
                    }
                })
            }
        }, beginMediaRecording: { [weak self] isVideo in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.dismissAllTooltips()
            
            strongSelf.mediaRecordingModeTooltipController?.dismiss()
            strongSelf.interfaceInteraction?.updateShowWebView { _ in
                return false
            }
            
            var bannedMediaInput = false
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if let channel = peer as? TelegramChannel {
                    if channel.hasBannedPermission(.banSendVoice) != nil && channel.hasBannedPermission(.banSendInstantVideos) != nil {
                        bannedMediaInput = true
                    } else if channel.hasBannedPermission(.banSendVoice) != nil {
                        if !isVideo {
                            strongSelf.controllerInteraction?.displayUndo(.info(title: nil, text: strongSelf.restrictedSendingContentsText(), timeout: nil, customUndoText: nil))
                            return
                        }
                    } else if channel.hasBannedPermission(.banSendInstantVideos) != nil {
                        if isVideo {
                            strongSelf.controllerInteraction?.displayUndo(.info(title: nil, text: strongSelf.restrictedSendingContentsText(), timeout: nil, customUndoText: nil))
                            return
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    if group.hasBannedPermission(.banSendVoice) && group.hasBannedPermission(.banSendInstantVideos) {
                        bannedMediaInput = true
                    } else if group.hasBannedPermission(.banSendVoice) {
                        if !isVideo {
                            strongSelf.controllerInteraction?.displayUndo(.info(title: nil, text: strongSelf.restrictedSendingContentsText(), timeout: nil, customUndoText: nil))
                            return
                        }
                    } else if group.hasBannedPermission(.banSendInstantVideos) {
                        if isVideo {
                            strongSelf.controllerInteraction?.displayUndo(.info(title: nil, text: strongSelf.restrictedSendingContentsText(), timeout: nil, customUndoText: nil))
                            return
                        }
                    }
                }
            }
            
            if bannedMediaInput {
                strongSelf.controllerInteraction?.displayUndo(.universal(animation: "premium_unlock", scale: 1.0, colors: ["__allcolors__": UIColor(white: 1.0, alpha: 1.0)], title: nil, text: strongSelf.restrictedSendingContentsText(), customUndoText: nil, timeout: nil))
                return
            }
                        
            let requestId = strongSelf.beginMediaRecordingRequestId
            let begin: () -> Void = {
                guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                    return
                }
                guard checkAvailableDiskSpace(context: strongSelf.context, push: { [weak self] c in
                    self?.present(c, in: .window(.root))
                }) else {
                    return
                }
                let hasOngoingCall: Signal<Bool, NoError> = strongSelf.context.sharedContext.hasOngoingCall.get()
                let _ = (hasOngoingCall
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { hasOngoingCall in
                    guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                        return
                    }
                    if hasOngoingCall {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_RecordingDisabledMessage, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    } else {
                        if isVideo {
                            strongSelf.requestVideoRecorder()
                        } else {
                            strongSelf.requestAudioRecorder(beginWithTone: false)
                        }
                    }
                })
            }
                        
            DeviceAccess.authorizeAccess(to: .microphone(isVideo ? .video : .audio), presentationData: strongSelf.presentationData, present: { c, a in
                self?.present(c, in: .window(.root), with: a)
            }, openSettings: {
                self?.context.sharedContext.applicationBindings.openSettings()
            }, { granted in
                guard let strongSelf = self, granted else {
                    return
                }
                if isVideo {
                    DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: strongSelf.presentationData, present: { c, a in
                        self?.present(c, in: .window(.root), with: a)
                    }, openSettings: {
                        self?.context.sharedContext.applicationBindings.openSettings()
                    }, { granted in
                        if granted {
                            begin()
                        }
                    })
                } else {
                    begin()
                }
            })
        }, finishMediaRecording: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            strongSelf.dismissMediaRecorder(action)
        }, stopMediaRecording: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            strongSelf.lockMediaRecordingRequestId = nil
            strongSelf.stopMediaRecorder(pause: true)
        }, lockMediaRecording: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lockMediaRecordingRequestId = strongSelf.beginMediaRecordingRequestId
            strongSelf.lockMediaRecorder()
        }, resumeMediaRecording: { [weak self] in
            guard let self else {
                return
            }
            self.resumeMediaRecorder()
        }, deleteRecordedMedia: { [weak self] in
            self?.deleteMediaRecording()
        }, sendRecordedMedia: { [weak self] silentPosting, viewOnce in
            self?.presentPaidMessageAlertIfNeeded(count: 1, completion: { [weak self] postpone in
                self?.sendMediaRecording(silentPosting: silentPosting, viewOnce: viewOnce, postpone: postpone)
            })
        }, displayRestrictedInfo: { [weak self] subject, displayType in
            guard let strongSelf = self else {
                return
            }
            

            let canBypassRestrictions = canBypassRestrictions(chatPresentationInterfaceState: strongSelf.presentationInterfaceState)
            
            let subjectFlags: [TelegramChatBannedRightsFlags]
            switch subject {
            case .stickers:
                subjectFlags = [.banSendStickers]
            case .mediaRecording, .premiumVoiceMessages:
                subjectFlags = [.banSendVoice, .banSendInstantVideos]
            }
                        
            var bannedPermission: (Int32, Bool)? = nil
            if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                for subjectFlag in subjectFlags {
                    if let value = channel.hasBannedPermission(subjectFlag, ignoreDefault: canBypassRestrictions) {
                        bannedPermission = value
                        break
                    }
                }
            } else if let group = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                for subjectFlag in subjectFlags {
                    if group.hasBannedPermission(subjectFlag) {
                        bannedPermission = (Int32.max, false)
                        break
                    }
                }
            }
            
            if let boostsToUnrestrict = (strongSelf.contentData?.state.peerView?.cachedData as? CachedChannelData)?.boostsToUnrestrict, boostsToUnrestrict > 0, let bannedPermission, !bannedPermission.1 {
                strongSelf.interfaceInteraction?.openBoostToUnrestrict()
                return
            }
            
            var displayToast = false
            
            if let (untilDate, personal) = bannedPermission {
                let banDescription: String
                switch subject {
                    case .stickers:
                        if untilDate != 0 && untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickersTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                        } else if personal {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickers
                        } else {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedStickers
                        }
                    case .mediaRecording:
                        if untilDate != 0 && untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                        } else if personal {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                        } else {
                            banDescription = strongSelf.restrictedSendingContentsText()
                            displayToast = true
                        }
                    case .premiumVoiceMessages:
                        banDescription = ""
                }
                if strongSelf.recordingModeFeedback == nil {
                    strongSelf.recordingModeFeedback = HapticFeedback()
                    strongSelf.recordingModeFeedback?.prepareError()
                }
                
                strongSelf.recordingModeFeedback?.error()
                
                switch displayType {
                    case .tooltip:
                        if displayToast {
                            strongSelf.controllerInteraction?.displayUndo(.universal(animation: "premium_unlock", scale: 1.0, colors: ["__allcolors__": UIColor(white: 1.0, alpha: 1.0)], title: nil, text: banDescription, customUndoText: nil, timeout: nil))
                        } else {
                            var rect: CGRect?
                            let isStickers: Bool = subject == .stickers
                            switch subject {
                            case .stickers:
                                rect = strongSelf.chatDisplayNode.frameForStickersButton()
                                if var rectValue = rect, let actionRect = strongSelf.chatDisplayNode.frameForInputActionButton() {
                                    rectValue.origin.y = actionRect.minY
                                    rect = rectValue
                                }
                            case .mediaRecording, .premiumVoiceMessages:
                                rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                            }
                            
                            if let tooltipController = strongSelf.mediaRestrictedTooltipController, strongSelf.mediaRestrictedTooltipControllerMode == isStickers {
                                tooltipController.updateContent(.text(banDescription), animated: true, extendTimer: true)
                            } else if let rect = rect {
                                strongSelf.mediaRestrictedTooltipController?.dismiss()
                                let tooltipController = TooltipController(content: .text(banDescription), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                                strongSelf.mediaRestrictedTooltipController = tooltipController
                                strongSelf.mediaRestrictedTooltipControllerMode = isStickers
                                tooltipController.dismissed = { [weak tooltipController] _ in
                                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRestrictedTooltipController === tooltipController {
                                        strongSelf.mediaRestrictedTooltipController = nil
                                    }
                                }
                                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                                    if let strongSelf = self {
                                        return (strongSelf.chatDisplayNode, rect)
                                    }
                                    return nil
                                }))
                            }
                        }
                    case .alert:
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: banDescription, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
            
            if case .premiumVoiceMessages = subject {
                let text: String
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer.flatMap({ EnginePeer($0) }) {
                    text = strongSelf.presentationInterfaceState.strings.Conversation_VoiceMessagesRestricted(peer.compactDisplayTitle).string
                } else {
                    text = ""
                }
                switch displayType {
                    case .tooltip:
                        let rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                        if let rect = rect {
                            strongSelf.mediaRestrictedTooltipController?.dismiss()
                            let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, padding: 2.0)
                            strongSelf.mediaRestrictedTooltipController = tooltipController
                            strongSelf.mediaRestrictedTooltipControllerMode = false
                            tooltipController.dismissed = { [weak tooltipController] _ in
                                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRestrictedTooltipController === tooltipController {
                                    strongSelf.mediaRestrictedTooltipController = nil
                                }
                            }
                            strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                                if let strongSelf = self {
                                    return (strongSelf.chatDisplayNode, rect)
                                }
                                return nil
                            }))
                        }
                    case .alert:
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            } else if case .mediaRecording = subject, strongSelf.presentationInterfaceState.hasActiveGroupCall {
                let rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                if let rect = rect {
                    strongSelf.mediaRestrictedTooltipController?.dismiss()
                    let text: String
                    if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                        text = strongSelf.presentationInterfaceState.strings.Conversation_LiveStreamMediaRecordingRestricted
                    } else {
                        text = strongSelf.presentationInterfaceState.strings.Conversation_VoiceChatMediaRecordingRestricted
                    }
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                    strongSelf.mediaRestrictedTooltipController = tooltipController
                    strongSelf.mediaRestrictedTooltipControllerMode = false
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRestrictedTooltipController === tooltipController {
                            strongSelf.mediaRestrictedTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, displayVideoUnmuteTip: { [weak self] location in
            guard let strongSelf = self, !strongSelf.didDisplayVideoUnmuteTooltip, let layout = strongSelf.validLayout, strongSelf.traceVisibility() && isTopmostChatController(strongSelf) else {
                return
            }
            if let location = location, location.y < strongSelf.navigationLayout(layout: layout).navigationFrame.maxY {
                return
            }
            let icon: UIImage?
            if layout.deviceMetrics.hasTopNotch || layout.deviceMetrics.hasDynamicIsland {
                icon = UIImage(bundleImageName: "Chat/Message/VolumeButtonIconX")
            } else {
                icon = UIImage(bundleImageName: "Chat/Message/VolumeButtonIcon")
            }
            if let location = location, let icon = icon {
                strongSelf.didDisplayVideoUnmuteTooltip = true
                strongSelf.videoUnmuteTooltipController?.dismiss()
                let tooltipController = TooltipController(content: .iconAndText(icon, strongSelf.presentationInterfaceState.strings.Conversation_PressVolumeButtonForSound), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, timeout: 3.5, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                strongSelf.videoUnmuteTooltipController = tooltipController
                tooltipController.dismissed = { [weak tooltipController] _ in
                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.videoUnmuteTooltipController === tooltipController {
                        strongSelf.videoUnmuteTooltipController = nil
                        ApplicationSpecificNotice.setVolumeButtonToUnmute(accountManager: strongSelf.context.sharedContext.accountManager)
                    }
                }
                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                    if let strongSelf = self {
                        return (strongSelf.chatDisplayNode, CGRect(origin: location, size: CGSize()))
                    }
                    return nil
                }))
            } else if let tooltipController = strongSelf.videoUnmuteTooltipController {
                tooltipController.dismissImmediately()
            }
        }, switchMediaRecordingMode: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            var bannedMediaInput = false
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if let channel = peer as? TelegramChannel {
                    if channel.hasBannedPermission(.banSendVoice) != nil && channel.hasBannedPermission(.banSendInstantVideos) != nil {
                        bannedMediaInput = true
                    } else if channel.hasBannedPermission(.banSendVoice) != nil {
                        if channel.hasBannedPermission(.banSendInstantVideos) == nil {
                            strongSelf.displayMediaRecordingTooltip()
                            return
                        }
                    } else if channel.hasBannedPermission(.banSendInstantVideos) != nil {
                        if channel.hasBannedPermission(.banSendVoice) == nil {
                            strongSelf.displayMediaRecordingTooltip()
                            return
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    if group.hasBannedPermission(.banSendVoice) && group.hasBannedPermission(.banSendInstantVideos) {
                        bannedMediaInput = true
                    } else if group.hasBannedPermission(.banSendVoice) {
                        if !group.hasBannedPermission(.banSendInstantVideos) {
                            strongSelf.displayMediaRecordingTooltip()
                            return
                        }
                    } else if group.hasBannedPermission(.banSendInstantVideos) {
                        if !group.hasBannedPermission(.banSendVoice) {
                            strongSelf.displayMediaRecordingTooltip()
                            return
                        }
                    }
                }
            }
            
            if bannedMediaInput {
                strongSelf.controllerInteraction?.displayUndo(.universal(animation: "premium_unlock", scale: 1.0, colors: ["__allcolors__": UIColor(white: 1.0, alpha: 1.0)], title: nil, text: strongSelf.restrictedSendingContentsText(), customUndoText: nil, timeout: nil))
                return
            }
            
            if strongSelf.recordingModeFeedback == nil {
                strongSelf.recordingModeFeedback = HapticFeedback()
                strongSelf.recordingModeFeedback?.prepareImpact()
            }
            
            strongSelf.recordingModeFeedback?.impact()
            var updatedMode: ChatTextInputMediaRecordingButtonMode?
            
            strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                return $0.updatedInterfaceState({ current in
                    let mode: ChatTextInputMediaRecordingButtonMode
                    switch current.mediaRecordingMode {
                        case .audio:
                            mode = .video
                        case .video:
                            mode = .audio
                    }
                    updatedMode = mode
                    return current.withUpdatedMediaRecordingMode(mode)
                }).updatedShowWebView(false)
            })
            
            if let updatedMode = updatedMode, updatedMode == .video {
                let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(accountManager: strongSelf.context.sharedContext.accountManager, count: 3).startStandalone()
            }
            
            strongSelf.displayMediaRecordingTooltip()
        }, setupMessageAutoremoveTimeout: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            if peerId.namespace == Namespaces.Peer.SecretChat {
                strongSelf.chatDisplayNode.dismissInput()
                
                if let peer = peer as? TelegramSecretChat {
                    let controller = ChatSecretAutoremoveTimerActionSheetController(context: strongSelf.context, currentValue: peer.messageAutoremoveTimeout == nil ? 0 : peer.messageAutoremoveTimeout!, applyValue: { value in
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: value == 0 ? nil : value).startStandalone()
                        }
                    })
                    strongSelf.present(controller, in: .window(.root))
                }
            } else {
                var currentAutoremoveTimeout: Int32? = strongSelf.presentationInterfaceState.autoremoveTimeout
                var canSetupAutoremoveTimeout = false
                
                if let secretChat = peer as? TelegramSecretChat {
                    currentAutoremoveTimeout = secretChat.messageAutoremoveTimeout
                    canSetupAutoremoveTimeout = true
                } else if let group = peer as? TelegramGroup {
                    if !group.hasBannedPermission(.banChangeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let user = peer as? TelegramUser {
                    if user.id != strongSelf.context.account.peerId && user.botInfo == nil {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let channel = peer as? TelegramChannel {
                    if channel.hasPermission(.changeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                }
                
                if canSetupAutoremoveTimeout {
                    strongSelf.presentAutoremoveSetup()
                } else if let currentAutoremoveTimeout = currentAutoremoveTimeout, let rect = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.messageAutoremoveTimeout(currentAutoremoveTimeout)) {
                    
                    let intervalText = timeIntervalString(strings: strongSelf.presentationData.strings, value: currentAutoremoveTimeout)
                    let text: String = strongSelf.presentationData.strings.Conversation_AutoremoveTimerSetToastText(intervalText).string
                    
                    strongSelf.mediaRecordingModeTooltipController?.dismiss()
                    
                    if let tooltipController = strongSelf.silentPostTooltipController {
                        tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
                    } else {
                        let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, timeout: 4.0)
                        strongSelf.silentPostTooltipController = tooltipController
                        tooltipController.dismissed = { [weak tooltipController] _ in
                            if let strongSelf = self, let tooltipController = tooltipController, strongSelf.silentPostTooltipController === tooltipController {
                                strongSelf.silentPostTooltipController = nil
                            }
                        }
                        strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                            if let strongSelf = self {
                                return (strongSelf.chatDisplayNode, rect)
                            }
                            return nil
                        }))
                    }
                }
            }
        }, sendSticker: { [weak self] file, clearInput, sourceView, sourceRect, sourceLayer, bubbleUpEmojiOrStickersets in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                return strongSelf.controllerInteraction?.sendSticker(file, false, false, nil, clearInput, sourceView, sourceRect, sourceLayer, bubbleUpEmojiOrStickersets) ?? false
            } else {
                return false
            }
        }, unblockPeer: { [weak self] in
            self?.unblockPeer()
        }, pinMessage: { [weak self] messageId, contextController in
            if let strongSelf = self, let currentPeerId = strongSelf.chatLocation.peerId {
                guard !strongSelf.presentAccountFrozenInfoIfNeeded(delay: true) else {
                    contextController?.dismiss(completion: nil)
                    return
                }
                
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    if strongSelf.canManagePin() {
                        let pinAction: (Bool, Bool) -> Void = { notify, forThisPeerOnlyIfPossible in
                            if let strongSelf = self {
                                let disposable: MetaDisposable
                                if let current = strongSelf.unpinMessageDisposable {
                                    disposable = current
                                } else {
                                    disposable = MetaDisposable()
                                    strongSelf.unpinMessageDisposable = disposable
                                }
                                disposable.set(strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: currentPeerId, update: .pin(id: messageId, silent: !notify, forThisPeerOnlyIfPossible: forThisPeerOnlyIfPossible)).startStrict(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.contentData?.scrolledToMessageIdValue = nil
                                }))
                            }
                        }
                        
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info, let contextController = contextController {
                            contextController.dismiss(completion: {
                                pinAction(true, false)
                            })
                        } else if let peer = peer as? TelegramUser, let contextController = contextController {
                            if peer.id == strongSelf.context.account.peerId {
                                contextController.dismiss(completion: {
                                    pinAction(true, true)
                                })
                            } else {
                                var contextItems: [ContextMenuItem] = []
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessagesFor(EnginePeer(peer).compactDisplayTitle).string, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c?.dismiss(completion: {
                                        pinAction(true, false)
                                    })
                                })))
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessagesForMe, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c?.dismiss(completion: {
                                        pinAction(true, true)
                                    })
                                })))
                                
                                contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil, animated: true)
                            }
                            return
                        } else {
                            if let contextController = contextController {
                                var contextItems: [ContextMenuItem] = []
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessageAlert_PinAndNotifyMembers, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c?.dismiss(completion: {
                                        pinAction(true, false)
                                    })
                                })))
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c?.dismiss(completion: {
                                        pinAction(false, false)
                                    })
                                })))
                                
                                contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil, animated: true)
                                
                                return
                            } else {
                                let continueAction: () -> Void = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    var pinImmediately = false
                                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                        pinImmediately = true
                                    } else if let _ = peer as? TelegramUser {
                                        pinImmediately = true
                                    }
                                    
                                    if pinImmediately {
                                        pinAction(true, false)
                                    } else {
                                        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError> = ChatControllerImpl.topPinnedMessageSignal(context: strongSelf.context, chatLocation: strongSelf.chatLocation, referenceMessage: nil)
                                        |> take(1)
                                        
                                        let _ = (topPinnedMessage
                                        |> deliverOnMainQueue).startStandalone(next: { value in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            let title: String?
                                            let text: String
                                            let actionLayout: TextAlertContentActionLayout
                                            let actions: [TextAlertAction]
                                            if let value = value, value.message.id > messageId {
                                                title = strongSelf.presentationData.strings.Conversation_PinOlderMessageAlertTitle
                                                text = strongSelf.presentationData.strings.Conversation_PinOlderMessageAlertText
                                                actionLayout = .vertical
                                                actions = [
                                                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlertPin, action: {
                                                        pinAction(false, false)
                                                    }),
                                                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                                    })
                                                ]
                                            } else {
                                                title = nil
                                                text = strongSelf.presentationData.strings.Conversation_PinMessageAlertGroup
                                                actionLayout = .horizontal
                                                actions = [
                                                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, action: {
                                                        pinAction(false, false)
                                                    }),
                                                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                                        pinAction(true, false)
                                                    })
                                                ]
                                            }
                                            
                                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: title, text: text, actions: actions, actionLayout: actionLayout), in: .window(.root))
                                        })
                                    }
                                }
                                
                                continueAction()
                            }
                        }
                    } else {
                        if let topPinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessage?.topMessageId {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                    var value = value
                                    value.closedPinnedMessageId = topPinnedMessageId
                                    return value
                                    })
                                })
                            })
                        }
                    }
                }
            }
        }, unpinMessage: { [weak self] id, askForConfirmation, contextController in
            let impl: () -> Void = {
                guard let strongSelf = self else {
                    return
                }
                guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                    return
                }
                
                if strongSelf.canManagePin() {
                    let action: () -> Void = {
                        if let strongSelf = self {
                            let disposable: MetaDisposable
                            if let current = strongSelf.unpinMessageDisposable {
                                disposable = current
                            } else {
                                disposable = MetaDisposable()
                                strongSelf.unpinMessageDisposable = disposable
                            }
                            
                            if askForConfirmation {
                                strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = true
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    return $0.updatedPendingUnpinnedAllMessages(true)
                                })
                                    
                                strongSelf.present(
                                    UndoOverlayController(
                                        presentationData: strongSelf.presentationData,
                                        content: .messagesUnpinned(
                                            title: strongSelf.presentationData.strings.Chat_MessagesUnpinned(1),
                                            text: "",
                                            undo: askForConfirmation,
                                            isHidden: false
                                        ),
                                        elevatedLayout: false,
                                        action: { action in
                                            switch action {
                                            case .commit:
                                                disposable.set((strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                                |> deliverOnMainQueue).startStrict(error: { _ in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                        return $0.updatedPendingUnpinnedAllMessages(false)
                                                    })
                                                }, completed: {
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                        return $0.updatedPendingUnpinnedAllMessages(false)
                                                    })
                                                }))
                                            case .undo:
                                                strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                    return $0.updatedPendingUnpinnedAllMessages(false)
                                                })
                                            default:
                                                break
                                            }
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            } else {
                                if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                                    strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.insert(id)
                                    strongSelf.present(
                                        UndoOverlayController(
                                            presentationData: strongSelf.presentationData,
                                            content: .messagesUnpinned(
                                                title: strongSelf.presentationData.strings.Chat_MessagesUnpinned(1),
                                                text: "",
                                                undo: true,
                                                isHidden: false
                                            ),
                                            elevatedLayout: false,
                                            action: { action in
                                                guard let strongSelf = self else {
                                                    return true
                                                }
                                                switch action {
                                                case .commit:
                                                    let _ = (strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                                    |> deliverOnMainQueue).startStandalone(completed: {
                                                        Queue.mainQueue().after(1.0, {
                                                            guard let strongSelf = self else {
                                                                return
                                                            }
                                                            strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.remove(id)
                                                        })
                                                    })
                                                case .undo:
                                                    strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.remove(id)
                                                default:
                                                    break
                                                }
                                                return true
                                            }
                                        ),
                                        in: .current
                                    )
                                } else {
                                    disposable.set((strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                    |> deliverOnMainQueue).startStrict())
                                }
                            }
                        }
                    }
                    if askForConfirmation {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_UnpinMessageAlert, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_Unpin, action: {
                            action()
                        }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                    } else {
                        action()
                    }
                } else {
                    if let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage {
                        let previousClosedPinnedMessageId = strongSelf.presentationInterfaceState.interfaceState.messageActionsState.closedPinnedMessageId
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                var value = value
                                value.closedPinnedMessageId = pinnedMessage.topMessageId
                                return value
                            }) })
                        })
                        strongSelf.present(
                            UndoOverlayController(
                                presentationData: strongSelf.presentationData,
                                content: .messagesUnpinned(
                                    title: strongSelf.presentationData.strings.Chat_PinnedMessagesHiddenTitle,
                                    text: strongSelf.presentationData.strings.Chat_PinnedMessagesHiddenText,
                                    undo: true,
                                    isHidden: false
                                ),
                                elevatedLayout: false,
                                action: { action in
                                    guard let strongSelf = self else {
                                        return true
                                    }
                                    switch action {
                                    case .commit:
                                        break
                                    case .undo:
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                                var value = value
                                                value.closedPinnedMessageId = previousClosedPinnedMessageId
                                                return value
                                            }) })
                                        })
                                    default:
                                        break
                                    }
                                    return true
                                }
                            ),
                            in: .current
                        )
                        strongSelf.updatedClosedPinnedMessageId?(pinnedMessage.topMessageId)
                    }
                }
            }
            
            if let contextController = contextController {
                contextController.dismiss(completion: {
                    impl()
                })
            } else {
                impl()
            }
        }, unpinAllMessages: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let topPinnedMessage: Signal<ChatPinnedMessage?, NoError> = ChatControllerImpl.topPinnedMessageSignal(context: strongSelf.context, chatLocation: strongSelf.chatLocation, referenceMessage: nil)
            |> take(1)
            
            let _ = (topPinnedMessage
            |> deliverOnMainQueue).startStandalone(next: { topPinnedMessage in
                guard let strongSelf = self, let topPinnedMessage = topPinnedMessage else {
                    return
                }
                
                if strongSelf.canManagePin() {
                    let count = strongSelf.presentationInterfaceState.pinnedMessage?.totalCount ?? 1
                    
                    strongSelf.requestedUnpinAllMessages?(count, topPinnedMessage.topMessageId)
                    strongSelf.dismiss()
                } else {
                    strongSelf.updatedClosedPinnedMessageId?(topPinnedMessage.topMessageId)
                    strongSelf.dismiss()
                }
            })
        }, openPinnedList: { [weak self] messageId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openPinnedMessages(at: messageId)
        }, shareAccountContact: { [weak self] in
            self?.shareAccountContact()
        }, reportPeer: { [weak self] in
            self?.reportPeer()
        }, presentPeerContact: { [weak self] in
            self?.addPeerContact()
        }, dismissReportPeer: { [weak self] in
            self?.dismissPeerContactOptions()
        }, deleteChat: { [weak self] in
            self?.deleteChat(reportChatSpam: false)
        }, beginCall: { [weak self] isVideo in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.controllerInteraction?.callPeer(peerId, isVideo)
            }
        }, toggleMessageStickerStarred: { [weak self] messageId in
            if let strongSelf = self, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                var stickerFile: TelegramMediaFile?
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isSticker {
                        stickerFile = file
                    }
                }
                if let stickerFile = stickerFile {
                    let context = strongSelf.context
                    let _ = (context.engine.stickers.isStickerSaved(id: stickerFile.fileId)
                    |> castError(AddSavedStickerError.self)
                    |> mapToSignal { isSaved -> Signal<(SavedStickerResult, Bool), AddSavedStickerError> in
                        return context.engine.stickers.toggleStickerSaved(file: stickerFile, saved: !isSaved)
                        |> map { result -> (SavedStickerResult, Bool) in
                            return (result, !isSaved)
                        }
                    }
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] result, added in
                        if let strongSelf = self {
                            switch result {
                                case .generic:
                                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: stickerFile, loop: true, title: nil, text: added ? strongSelf.presentationData.strings.Conversation_StickerAddedToFavorites : strongSelf.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: true, action: { _ in return false }), with: nil)
                                case let .limitExceeded(limit, premiumLimit):
                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                    let text: String
                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                        text = strongSelf.presentationData.strings.Premium_MaxFavedStickersFinalText
                                    } else {
                                        text = strongSelf.presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                    }
                                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: stickerFile, loop: true, title: strongSelf.presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: true, action: { [weak self] action in
                                        if let strongSelf = self {
                                            if case .info = action {
                                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                strongSelf.push(controller)
                                                return true
                                            }
                                        }
                                        return false
                                    }), with: nil)
                            }
                        }
                    })
                }
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, presentControllerInCurrent: { [weak self] controller, arguments in
            if controller is UndoOverlayController {
                self?.dismissAllTooltips()
            }
            self?.present(controller, in: .current, with: arguments)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, navigateFeed: { [weak self] in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.scrollToNextMessage()
            }
        }, openGrouping: {
        }, toggleSilentPost: { [weak self] in
            if let strongSelf = self {
                var value: Bool = false
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    $0.updatedInterfaceState {
                        value = !$0.silentPosting
                        return $0.withUpdatedSilentPosting(value)
                    }
                })
                strongSelf.saveInterfaceState()
                
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    for controller in navigationController.globalOverlayControllers {
                        if controller is VoiceChatOverlayController {
                            return
                        }
                    }
                }
                
                var rect: CGRect? = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(true))
                if rect == nil {
                    rect = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(false))
                }
                
                let text: String
                if !value {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOn
                } else {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOff
                }
                
                if let tooltipController = strongSelf.silentPostTooltipController {
                    tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
                } else if let rect = rect {
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                    strongSelf.silentPostTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.silentPostTooltipController === tooltipController {
                            strongSelf.silentPostTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, requestUnvoteInMessage: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            
            var signal = strongSelf.context.engine.messages.requestMessageSelectPollOption(messageId: id, opaqueIdentifiers: [])
            let disposables: DisposableDict<MessageId>
            if let current = strongSelf.selectMessagePollOptionDisposables {
                disposables = current
            } else {
                disposables = DisposableDict()
                strongSelf.selectMessagePollOptionDisposables = disposables
            }
            
            var cancelImpl: (() -> Void)?
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                    cancelImpl?()
                }))
                //strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.3, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.startStrict()
            
            signal = signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            cancelImpl = {
                disposables.set(nil, forKey: id)
            }
            
            disposables.set((signal
            |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                guard let self else {
                    return
                }
                if self.selectPollOptionFeedback == nil {
                    self.selectPollOptionFeedback = HapticFeedback()
                }
                self.selectPollOptionFeedback?.success()
            }), forKey: id)
        }, requestStopPollInMessage: { [weak self] id in
            guard let strongSelf = self, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) else {
                return
            }
            
            var maybePoll: TelegramMediaPoll?
            for media in message.media {
                if let poll = media as? TelegramMediaPoll {
                    maybePoll = poll
                    break
                }
            }
            
            guard let poll = maybePoll else {
                return
            }
            
            let actionTitle: String
            let actionButtonText: String
            switch poll.kind {
            case .poll:
                actionTitle = strongSelf.presentationData.strings.Conversation_StopPollConfirmationTitle
                actionButtonText = strongSelf.presentationData.strings.Conversation_StopPollConfirmation
            case .quiz:
                actionTitle = strongSelf.presentationData.strings.Conversation_StopQuizConfirmationTitle
                actionButtonText = strongSelf.presentationData.strings.Conversation_StopQuizConfirmation
            }
            
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: actionTitle),
                ActionSheetButtonItem(title: actionButtonText, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    let disposables: DisposableDict<MessageId>
                    if let current = strongSelf.selectMessagePollOptionDisposables {
                        disposables = current
                    } else {
                        disposables = DisposableDict()
                        strongSelf.selectMessagePollOptionDisposables = disposables
                    }
                    let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                    strongSelf.present(controller, in: .window(.root))
                    let signal = strongSelf.context.engine.messages.requestClosePoll(messageId: id)
                    |> afterDisposed { [weak controller] in
                        Queue.mainQueue().async {
                            controller?.dismiss()
                        }
                    }
                    disposables.set((signal
                    |> deliverOnMainQueue).startStrict(error: { _ in
                    }, completed: {
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.selectPollOptionFeedback == nil {
                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                        }
                        strongSelf.selectPollOptionFeedback?.success()
                    }), forKey: id)
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(actionSheet, in: .window(.root))
        }, updateInputLanguage: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedInterfaceState({ $0.withUpdatedInputLanguage(f($0.inputLanguage)) })
                })
            }
        }, unarchiveChat: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            let _ = (strongSelf.context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root)
            |> deliverOnMainQueue).startStandalone()
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: NSAttributedString?
                var inputMode: ChatInputMode?
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count))
                    }
                    inputMode = state.inputMode
                    return state
                })
                
                var link: String?
                if let text {
                    text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
                        if let linkAttribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                            link = linkAttribute.url
                        }
                    }
                }
                
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: strongSelf.updatedPresentationData, account: strongSelf.context.account, text: text?.string ?? "", link: link, allowEmpty: true, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link {
                            if !link.isEmpty {
                                strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                                    return (chatTextInputAddLinkAttribute(current, selectionRange: selectionRange, url: link), inputMode)
                                }
                            } else {
                                strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                                    return (chatTextInputRemoveLinkAttribute(current, selectionRange: selectionRange), inputMode)
                                }
                            }
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, {
                            return $0.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller, in: .window(.root))
                
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { $0.updatedInputMode({ _ in return .none }) })
            }
        }, displaySlowmodeTooltip: { [weak self] sourceView, nodeRect in
            guard let strongSelf = self, let slowmodeState = strongSelf.presentationInterfaceState.slowmodeState else {
                return
            }
            
            if let boostsToUnrestrict = (strongSelf.contentData?.state.peerView?.cachedData as? CachedChannelData)?.boostsToUnrestrict, boostsToUnrestrict > 0 {
                strongSelf.interfaceInteraction?.openBoostToUnrestrict()
                return
            }
            
            let rect = sourceView.convert(nodeRect, to: strongSelf.view)
            if let slowmodeTooltipController = strongSelf.slowmodeTooltipController {
                if let arguments = slowmodeTooltipController.presentationArguments as? TooltipControllerPresentationArguments, case let .node(f) = arguments.sourceAndRect, let (previousNode, previousRect) = f() {
                    if previousNode === strongSelf.chatDisplayNode && previousRect == rect {
                        return
                    }
                }
                
                strongSelf.slowmodeTooltipController = nil
                slowmodeTooltipController.dismiss()
            }
            let slowmodeTooltipController = ChatSlowmodeHintController(presentationData: strongSelf.presentationData, slowmodeState: 
                slowmodeState)
            slowmodeTooltipController.presentationArguments = TooltipControllerPresentationArguments(sourceNodeAndRect: {
                if let strongSelf = self {
                    return (strongSelf.chatDisplayNode, rect)
                }
                return nil
            })
            strongSelf.slowmodeTooltipController = slowmodeTooltipController
            
            strongSelf.window?.presentInGlobalOverlay(slowmodeTooltipController)
        }, displaySendMessageOptions: { [weak self] node, gesture in
            guard let self else {
                return
            }
            chatMessageDisplaySendMessageOptions(selfController: self, node: node, gesture: gesture)
        }, openScheduledMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.openScheduledMessages()
            }
        }, openPeersNearby: { [weak self] in
            if let strongSelf = self {
                let controller = strongSelf.context.sharedContext.makePeersNearbyController(context: strongSelf.context)
                controller.navigationPresentation = .master
                strongSelf.effectiveNavigationController?.pushViewController(controller, animated: true, completion: { })
            }
        }, displaySearchResultsTooltip: { [weak self] node, nodeRect in
            if let strongSelf = self {
                strongSelf.searchResultsTooltipController?.dismiss()
                let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.ChatSearch_ResultsTooltip), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                strongSelf.searchResultsTooltipController = tooltipController
                tooltipController.dismissed = { [weak tooltipController] _ in
                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.searchResultsTooltipController === tooltipController {
                        strongSelf.searchResultsTooltipController = nil
                    }
                }
                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                    if let strongSelf = self {
                        var rect = node.view.convert(node.view.bounds, to: strongSelf.chatDisplayNode.view)
                        rect = CGRect(origin: rect.origin.offsetBy(dx: nodeRect.minX, dy: nodeRect.minY - node.bounds.minY), size: nodeRect.size)
                        return (strongSelf.chatDisplayNode, rect)
                    }
                    return nil
                }))
           }
        }, unarchivePeer: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            unarchiveAutomaticallyArchivedPeer(account: strongSelf.context.account, peerId: peerId)
            
            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .succeed(text: strongSelf.presentationData.strings.Conversation_UnarchiveDone, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
        }, scrollToTop: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
        }, viewReplies: { [weak self] sourceMessageId, replyThreadResult in
            guard let strongSelf = self else {
                return
            }
            
            if let navigationController = strongSelf.effectiveNavigationController {
                let subject: ChatControllerSubject? = sourceMessageId.flatMap { ChatControllerSubject.message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false) }
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .replyThread(replyThreadResult), subject: subject, keepStack: .always))
            }
        }, activatePinnedListPreview: { [weak self] node, gesture in
            guard let strongSelf = self else {
                return
            }
            guard let peerId = strongSelf.chatLocation.peerId else {
                return
            }
            guard let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage else {
                return
            }
            let count = pinnedMessage.totalCount
            let topMessageId = pinnedMessage.topMessageId
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_ShowAllMessages, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PinnedList"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openPinnedMessages(at: nil)
                f(.dismissWithoutContent)
            })))
            
            if strongSelf.canManagePin() {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_UnpinAllMessages, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.performRequestedUnpinAllMessages(count: count, pinnedMessageId: topMessageId)
                    f(.dismissWithoutContent)
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_HidePinnedMessages, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.performUpdatedClosedPinnedMessageId(pinnedMessageId: topMessageId)
                    f(.dismissWithoutContent)
                })))
            }
            
            let chatLocation: ChatLocation
            if let _ = strongSelf.chatLocation.threadId {
                chatLocation = strongSelf.chatLocation
            } else {
                chatLocation = .peer(id: peerId)
            }
            
            let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: chatLocation, subject: .pinnedMessages(id: pinnedMessage.message.id), botStart: nil, mode: .standard(.previewing), params: nil)
            chatController.canReadHistory.set(false)
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: node, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.presentInGlobalOverlay(contextController)
        }, joinGroupCall: { [weak self] activeCall in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            strongSelf.joinGroupCall(peerId: peer.id, invite: nil, activeCall: EngineGroupCallDescription(activeCall))
        }, presentInviteMembers: { [weak self] in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            if !(peer is TelegramGroup || peer is TelegramChannel) {
                return
            }
            presentAddMembersImpl(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, parentController: strongSelf, groupPeer: peer, selectAddMemberDisposable: strongSelf.selectAddMemberDisposable, addMemberDisposable: strongSelf.addMemberDisposable)
        }, presentGigagroupHelp: { [weak self] in
            if let strongSelf = self {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.Conversation_GigagroupDescription, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
            }
        }, openSuggestPost: { [weak self] in
            guard let self else {
                return
            }
            guard let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel else {
                return
            }
            guard let monoforumPeerId = channel.linkedMonoforumId else {
                return
            }
            
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: monoforumPeerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] monoforumPeer in
                guard let self, let monoforumPeer else {
                    return
                }
                guard let navigationController = self.effectiveNavigationController else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(monoforumPeer), keepStack: .always))
            })
        }, editMessageMedia: { [weak self] messageId, draw in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.editMessageMedia(messageId, draw)
            }
        }, updateShowCommands: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowCommands(f($0.showCommands))
                })
            }
        }, updateShowSendAsPeers: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowSendAsPeers(f($0.showSendAsPeers))
                })
            }
        }, openInviteRequests: { [weak self] in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                let controller = inviteRequestsController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id, existingContext: strongSelf.contentData?.inviteRequestsContext)
                controller.navigationPresentation = .modal
                strongSelf.push(controller)
            }
        }, openSendAsPeer: { [weak self] node, gesture in
            guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId, let node = node as? ContextReferenceContentNode, let peers = strongSelf.presentationInterfaceState.sendAsPeers, let layout = strongSelf.validLayout else {
                return
            }
            
            let isPremium = strongSelf.presentationInterfaceState.isPremium
                        
            let cleanInsets = layout.intrinsicInsets
            let insets = layout.insets(options: .input)
            let bottomInset = max(insets.bottom, cleanInsets.bottom) + 43.0
            
            let defaultMyPeerId: PeerId
            if let channel = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .group = channel.info, channel.hasPermission(.canBeAnonymous) {
                defaultMyPeerId = channel.id
            } else if let channel = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case let .broadcast(info) = channel.info, info.flags.contains(.messagesShouldHaveProfiles) {
                defaultMyPeerId = channel.id
            } else {
                defaultMyPeerId = strongSelf.context.account.peerId
            }
            let myPeerId = strongSelf.presentationInterfaceState.currentSendAsPeerId ?? defaultMyPeerId
            
            var items: [ContextMenuItem] = []
            items.append(.custom(ChatSendAsPeerTitleContextItem(text: strongSelf.presentationInterfaceState.strings.Conversation_SendMesageAs.uppercased()), false))
            items.append(.custom(ChatSendAsPeerListContextItem(context: strongSelf.context, chatPeerId: peerId, peers: peers, selectedPeerId: myPeerId, isPremium: isPremium, presentToast: { [weak self] peer in
                if let strongSelf = self {
                    HapticFeedback().impact()
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, title: nil, text: strongSelf.presentationData.strings.Conversation_SendMesageAsPremiumInfo, action: strongSelf.presentationData.strings.EmojiInput_PremiumEmojiToast_Action, duration: 3), elevatedLayout: false, action: { [weak self] action in
                        guard let strongSelf = self else {
                            return true
                        }
                        if case .undo = action {
                            strongSelf.chatDisplayNode.dismissTextInput()
                            
                            let controller = PremiumIntroScreen(context: strongSelf.context, source: .settings)
                            strongSelf.push(controller)
                        }
                        return true
                    }), in: .current)
                }
                
            }), false))
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: node.view, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture, workaroundUseLegacyImplementation: true)
            contextController.dismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                        return $0.updatedShowSendAsPeers(false)
                    })
                }
            }
            strongSelf.presentInGlobalOverlay(contextController)
            
            strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                return $0.updatedShowSendAsPeers(true)
            })
        }, presentChatRequestAdminInfo: { [weak self] in
            self?.presentChatRequestAdminInfo()
        }, displayCopyProtectionTip: { [weak self] node, save in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer, let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                    messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                ))
                |> map { messages -> [EngineMessage] in
                    return messages.values.compactMap { $0 }
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak self] messages in
                    guard let strongSelf = self else {
                        return
                    }
                    enum PeerType {
                        case group
                        case channel
                        case bot
                        case user
                    }
                    var isBot = false
                    for message in messages {
                        if let author = message.author, case let .user(user) = author, user.botInfo != nil && !user.id.isVerificationCodes {
                            isBot = true
                            break
                        }
                    }
                    let type: PeerType
                    if isBot {
                        type = .bot
                    } else if let user = peer as? TelegramUser {
                        if user.botInfo != nil && !user.id.isVerificationCodes {
                            type = .bot
                        } else {
                            type = .user
                        }
                    } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        type = .channel
                    }  else {
                        type = .group
                    }
                    
                    let text: String
                    switch type {
                    case .group:
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledGroup : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledGroup
                    case .channel:
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledChannel : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledChannel
                    case .bot:
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledBot : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledBot
                    case .user:
                        text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledSecret : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledSecret
                    }
                    
                    strongSelf.copyProtectionTooltipController?.dismiss()
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                    strongSelf.copyProtectionTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.copyProtectionTooltipController === tooltipController {
                            strongSelf.copyProtectionTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            let rect = node.view.convert(node.view.bounds, to: strongSelf.chatDisplayNode.view).offsetBy(dx: 0.0, dy: 3.0)
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                })
           }
        }, openWebView: { [weak self] buttonText, url, simple, source in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.openWebView(buttonText, url, simple, source)
            }
        }, updateShowWebView: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowWebView(f($0.showWebView))
                })
            }
        }, insertText: { [weak self] text in
            guard let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction else {
                return
            }
            if !strongSelf.chatDisplayNode.isTextInputPanelActive {
                return
            }
            
            interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                
                let range = textInputState.selectionRange
                
                let updatedText = NSMutableAttributedString(attributedString: text)
                if range.lowerBound < inputText.length {
                    if let quote = inputText.attribute(ChatTextInputAttributes.block, at: range.lowerBound, effectiveRange: nil) {
                        updatedText.addAttribute(ChatTextInputAttributes.block, value: quote, range: NSRange(location: 0, length: updatedText.length))
                    }
                }
                inputText.replaceCharacters(in: NSMakeRange(range.lowerBound, range.count), with: updatedText)
                
                let selectionPosition = range.lowerBound + (updatedText.string as NSString).length
                
                return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
            }
            
            strongSelf.chatDisplayNode.updateTypingActivity(true)
        }, backwardsDeleteText: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.chatDisplayNode.isTextInputPanelActive {
                return
            }
            guard let textInputPanelNode = strongSelf.chatDisplayNode.textInputPanelNode else {
                return
            }
            textInputPanelNode.backwardsDeleteText()
        }, restartTopic: { [weak self] in
            guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId, let threadId = strongSelf.chatLocation.threadId else {
                return
            }
            let _ = strongSelf.context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: false).startStandalone()
        }, toggleTranslation: { [weak self] type in
            guard let self, let peerId = self.chatLocation.peerId else {
                return
            }
            let _ = (updateChatTranslationStateInteractively(engine: self.context.engine, peerId: peerId, threadId: self.chatLocation.threadId,  { current in
                return current?.withIsEnabled(type == .translated)
            })
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                if let self, type == .translated {
                    Queue.mainQueue().after(0.15) {
                        self.chatDisplayNode.historyNode.refreshPollActionsForVisibleMessages()
                    }
                }
            })
        }, changeTranslationLanguage: { [weak self] langCode in
            guard let self, let peerId = self.chatLocation.peerId else {
                return
            }
            let langCode = normalizeTranslationLanguage(langCode)
            let _ = updateChatTranslationStateInteractively(engine: self.context.engine, peerId: peerId, threadId: self.chatLocation.threadId, { current in
                return current?.withToLang(langCode).withIsEnabled(true)
            }).startStandalone()
        }, addDoNotTranslateLanguage: { [weak self] langCode in
            guard let self, let peerId = self.chatLocation.peerId else {
                return
            }
            let _ = updateTranslationSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
                var updated = current
                if var ignoredLanguages = updated.ignoredLanguages {
                    if !ignoredLanguages.contains(langCode) {
                        ignoredLanguages.append(langCode)
                    }
                    updated.ignoredLanguages = ignoredLanguages
                } else {
                    var ignoredLanguages = Set<String>()
                    ignoredLanguages.insert(self.presentationData.strings.baseLanguageCode)
                    for language in systemLanguageCodes() {
                        ignoredLanguages.insert(language)
                    }
                    ignoredLanguages.insert(langCode)
                    updated.ignoredLanguages = Array(ignoredLanguages)
                }
                return updated
            }).startStandalone()
            let _ = updateChatTranslationStateInteractively(engine: self.context.engine, peerId: peerId, threadId: self.chatLocation.threadId, { current in
                return nil
            }).startStandalone()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            var languageCode = presentationData.strings.baseLanguageCode
            let rawSuffix = "-raw"
            if languageCode.hasSuffix(rawSuffix) {
                languageCode = String(languageCode.dropLast(rawSuffix.count))
            }
            let locale = Locale(identifier: languageCode)
            let fromLanguage: String = locale.localizedString(forLanguageCode: langCode) ?? ""
            
            self.present(UndoOverlayController(presentationData: presentationData, content: .image(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/Translate"), color: .white)!, title: nil, text: presentationData.strings.Conversation_Translation_AddedToDoNotTranslateText(fromLanguage).string, round: false, undoText: presentationData.strings.Conversation_Translation_Settings), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self] action in
                if case .undo = action, let self {
                    let controller = translationSettingsController(context: self.context)
                    controller.navigationPresentation = .modal
                    self.push(controller)
                }
                return true
            }), in: .current)
        }, hideTranslationPanel: { [weak self] in
            guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId else {
                return
            }
            let context = strongSelf.context
            let presentationData = strongSelf.presentationData
            let _ = context.engine.messages.togglePeerMessagesTranslationHidden(peerId: peerId, hidden: true).startStandalone()

            var text: String = ""
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if peer is TelegramGroup {
                    text = presentationData.strings.Conversation_Translation_TranslationBarHiddenGroupText
                } else if let peer = peer as? TelegramChannel {
                    switch peer.info {
                    case .group:
                        text = presentationData.strings.Conversation_Translation_TranslationBarHiddenGroupText
                    case .broadcast:
                        text = presentationData.strings.Conversation_Translation_TranslationBarHiddenChannelText
                    }
                } else {
                    text = presentationData.strings.Conversation_Translation_TranslationBarHiddenChatText
                }
            }
            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .image(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/Translate"), color: .white)!, title: nil, text: text, round: false, undoText: presentationData.strings.Undo_Undo), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                    if case .undo = action {
                        let _ = context.engine.messages.togglePeerMessagesTranslationHidden(peerId: peerId, hidden: false).startStandalone()
                    }
                    return true
            }), in: .current)
        }, openPremiumGift: { [weak self] in
            guard let self, let peerId = self.chatLocation.peerId else {
                return
            }
            
            if peerId.namespace == Namespaces.Peer.CloudUser {
                self.presentAttachmentMenu(subject: .gift)
                Queue.mainQueue().after(0.5) {
                    let _ = ApplicationSpecificNotice.incrementDismissedPremiumGiftSuggestion(accountManager: self.context.sharedContext.accountManager, peerId: peerId, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
                }
            } else {
                let controller = self.context.sharedContext.makeGiftOptionsController(context: self.context, peerId: peerId, premiumOptions: [], hasBirthday: false, completion: { [weak self] in
                    guard let self, let peer = self.presentationInterfaceState.renderedPeer?.peer else {
                        return
                    }
                    if let controller = self.context.sharedContext.makePeerInfoController(
                        context: self.context,
                        updatedPresentationData: nil,
                        peer: peer,
                        mode: .gifts,
                        avatarInitiallyExpanded: false,
                        fromChat: false,
                        requestsContext: nil
                    ) {
                        self.push(controller)
                    }
                })
                self.push(controller)
            }
        }, openPremiumRequiredForMessaging: { [weak self] in
            guard let self else {
                return
            }
            let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .messageTags, forceDark: false, dismissed: nil)
            self.push(controller)
        }, openStarsPurchase: { [weak self] requiredStars in
            guard let self, let starsContext = self.context.starsContext else {
                return
            }
            let _ = (self.context.engine.payments.starsTopUpOptions()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                guard let self else {
                    return
                }
                let controller = self.context.sharedContext.makeStarsPurchaseScreen(context: self.context, starsContext: starsContext, options: options, purpose: .generic, completion: { _ in
                })
                self.push(controller)
            })
        }, openMessagePayment: {
            
        }, openBoostToUnrestrict: { [weak self] in
            guard let self else {
                return
            }
            
            guard !self.presentAccountFrozenInfoIfNeeded() else {
                return
            }
                        
            guard let peerId = self.chatLocation.peerId, let cachedData = self.contentData?.state.peerView?.cachedData as? CachedChannelData, let boostToUnrestrict = cachedData.boostsToUnrestrict else {
                return
            }
            
            HapticFeedback().impact()
            
            let _ = combineLatest(queue: Queue.mainQueue(),
                context.engine.peers.getChannelBoostStatus(peerId: peerId),
                context.engine.peers.getMyBoostStatus()
            ).startStandalone(next: { [weak self] boostStatus, myBoostStatus in
                guard let self, let boostStatus, let myBoostStatus else {
                    return
                }
                let boostController = PremiumBoostLevelsScreen(
                    context: self.context,
                    peerId: peerId,
                    mode: .user(mode: .unrestrict(Int(boostToUnrestrict))),
                    status: boostStatus,
                    myBoostStatus: myBoostStatus
                )
                self.push(boostController)
            })
        }, updateRecordingTrimRange: { [weak self] start, end, updatedEnd, apply in
            guard let self else {
                return
            }
            self.updateTrimRange(start: start, end: end, updatedEnd: updatedEnd, apply: apply)
        }, dismissAllTooltips: { [weak self] in
            guard let self else {
                return
            }
            self.dismissAllTooltips()
        }, updateHistoryFilter: { [weak self] update in
            guard let self else {
                return
            }
            
            let updatedFilter = update(self.presentationInterfaceState.historyFilter)
            
            let apply: () -> Void = { [weak self] in
                guard let self else {
                    return
                }
                
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    var state = state.updatedHistoryFilter(updatedFilter)
                    if let updatedFilter, let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: updatedFilter.customTag) {
                        if let search = state.search, search.domain != .tag(reaction) {
                            state = state.updatedSearch(ChatSearchData())
                        } else if state.search == nil {
                            state = state.updatedSearch(ChatSearchData())
                        }
                    }
                    return state
                })
            }
            
            if let updatedFilter, let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: updatedFilter.customTag) {
                let tag = updatedFilter.customTag
                
                let _ = (self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Messages.ReactionTagMessageCount(peerId: self.context.account.peerId, threadId: self.chatLocation.threadId, reaction: reaction)
                )
                |> deliverOnMainQueue).start(next: { [weak self] count in
                    guard let self else {
                        return
                    }
                    
                    var tagSearchInputPanelNode: ChatTagSearchInputPanelNode?
                    if let panelNode = self.chatDisplayNode.inputPanelNode as? ChatTagSearchInputPanelNode {
                        tagSearchInputPanelNode = panelNode
                    } else if let panelNode = self.chatDisplayNode.secondaryInputPanelNode as? ChatTagSearchInputPanelNode {
                        tagSearchInputPanelNode = panelNode
                    }
                    
                    if let tagSearchInputPanelNode, let count {
                        tagSearchInputPanelNode.prepareSwitchToFilter(tag: tag, count: count)
                    }
                    
                    apply()
                })
            } else {
                apply()
            }
        }, updateChatLocationThread: { [weak self] threadId, animationDirection in
            guard let self else {
                return
            }
            let defaultDirection: ChatControllerAnimateInnerChatSwitchDirection? = self.chatDisplayNode.chatLocationTabSwitchDirection(from: self.chatLocation.threadId, to: threadId).flatMap { direction -> ChatControllerAnimateInnerChatSwitchDirection in
                return direction ? .right : .left
            }
            self.updateChatLocationThread(threadId: threadId, animationDirection: animationDirection ?? defaultDirection)
        }, toggleChatSidebarMode: { [weak self] in
            guard let self else {
                return
            }
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { presentationInterfaceState in
                var persistentData = presentationInterfaceState.persistentData
                persistentData.topicListPanelLocation = !persistentData.topicListPanelLocation
                return presentationInterfaceState.updatedPersistentData(persistentData)
            })
        }, updateDisplayHistoryFilterAsList: { [weak self] displayAsList in
            guard let self else {
                return
            }
            
            if !displayAsList {
                self.alwaysShowSearchResultsAsList = false
                self.chatDisplayNode.alwaysShowSearchResultsAsList = false
            }
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                return state.updatedDisplayHistoryFilterAsList(displayAsList)
            })
        }, requestLayout: { [weak self] transition in
            if let strongSelf = self, let layout = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout, transition: transition)
            }
        }, chatController: { [weak self] in
            return self
        }, statuses: ChatPanelInterfaceInteractionStatuses(editingMessage: self.editingMessage.get(), startingBot: self.startingBot.get(), unblockingPeer: self.unblockingPeer.get(), searching: self.searching.get(), loadingMessage: self.loadingMessage.get(), inlineSearch: self.performingInlineSearch.get()))
        
        self.interfaceInteraction = interfaceInteraction
        
        if let search = self.focusOnSearchAfterAppearance {
            self.focusOnSearchAfterAppearance = nil
            self.interfaceInteraction?.beginMessageSearch(search.0, search.1)
        }
        
        self.chatDisplayNode.interfaceInteraction = interfaceInteraction
        
        self.context.sharedContext.mediaManager.galleryHiddenMediaManager.addTarget(self)
        self.galleryHiddenMesageAndMediaDisposable.set(self.context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().startStrict(next: { [weak self] ids in
            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                var messageIdAndMedia: [MessageId: [Media]] = [:]
                
                for id in ids {
                    if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                        messageIdAndMedia[messageId] = [media]
                    }
                }
                
                controllerInteraction.hiddenMedia = messageIdAndMedia
            
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        itemNode.updateHiddenMedia()
                    }
                }
            }
        }))
        
        self.chatDisplayNode.dismissAsOverlay = { [weak self] in
            if let strongSelf = self {
                strongSelf.statusBar.statusBarStyle = .Ignore
                strongSelf.chatDisplayNode.animateDismissAsOverlay(completion: {
                    self?.dismiss()
                })
            }
        }
        
        var lastEventTimestamp: Double = 0.0
        self.networkSpeedEventsDisposable = (self.context.account.network.networkSpeedLimitedEvents
        |> deliverOnMainQueue).start(next: { [weak self] event in
            guard let self else {
                return
            }
            
            switch event {
            case let .download(subject):
                if case let .message(messageId) = subject {
                    var isVisible = false
                    self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                            for (message, _) in item.content {
                                if message.id == messageId {
                                    isVisible = true
                                }
                            }
                        }
                    }
                    
                    if !isVisible {
                        return
                    }
                }
            case .upload:
                break
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent()
            if lastEventTimestamp + 10.0 < timestamp {
                lastEventTimestamp = timestamp
            } else {
                return
            }
            
            let title: String
            let text: String
            switch event {
            case .download:
                var speedIncreaseFactor = 10
                if let data = self.context.currentAppConfiguration.with({ $0 }).data, let value = data["upload_premium_speedup_download"] as? Double {
                    speedIncreaseFactor = Int(value)
                }
                title = self.presentationData.strings.Chat_SpeedLimitAlert_Download_Title
                text = self.presentationData.strings.Chat_SpeedLimitAlert_Download_Text("\(speedIncreaseFactor)").string
            case .upload:
                var speedIncreaseFactor = 10
                if let data = self.context.currentAppConfiguration.with({ $0 }).data, let value = data["upload_premium_speedup_upload"] as? Double {
                    speedIncreaseFactor = Int(value)
                }
                title = self.presentationData.strings.Chat_SpeedLimitAlert_Upload_Title
                text = self.presentationData.strings.Chat_SpeedLimitAlert_Upload_Text("\(speedIncreaseFactor)").string
            }
            let content: UndoOverlayContent = .universal(animation: "anim_speed_low", scale: 0.066, colors: [:], title: title, text: text, customUndoText: nil, timeout: 5.0)
            
            self.context.account.network.markNetworkSpeedLimitDisplayed()
            
            self.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, position: .top, action: { [weak self] action in
                guard let self else {
                    return false
                }
                switch action {
                case .info:
                    let context = self.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .fasterDownload, forceDark: false, action: {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .fasterDownload, forceDark: false, dismissed: nil)
                        replaceImpl?(controller)
                    }, dismissed: nil)
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    self.push(controller)
                    return true
                default:
                    break
                }
                return false
            }), in: .current)
        })
        
        if case .scheduledMessages = self.subject {
            self.postedScheduledMessagesEventsDisposable = (self.context.account.stateManager.sentScheduledMessageIds
            |> deliverOnMainQueue).start(next: { [weak self] ids in
                guard let self, let peerId = self.chatLocation.peerId else {
                    return
                }
                let filteredIds = Array(ids).filter({ $0.peerId == peerId })
                if filteredIds.isEmpty {
                    return
                }
                self.displayPostedScheduledMessagesToast(ids: filteredIds)
            })
        }
        
        self.displayNodeDidLoad()
    }
    
    func setupChatHistoryNode(historyNode: ChatHistoryListNodeImpl) {
        do {
            let peerId = self.chatLocation.peerId
            if let subject = self.subject, case .scheduledMessages = subject {
            } else {
                let throttledUnreadCountSignal = self.context.chatLocationUnreadCount(for: self.chatLocation, contextHolder: self.chatLocationContextHolder)
                |> mapToThrottled { value -> Signal<Int, NoError> in
                    return .single(value) |> then(.complete() |> delay(0.2, queue: Queue.mainQueue()))
                }
                self.buttonUnreadCountDisposable?.dispose()
                self.buttonUnreadCountDisposable = (throttledUnreadCountSignal
                |> deliverOnMainQueue).startStrict(next: { [weak self] count in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatDisplayNode.navigateButtons.unreadCount = Int32(count)
                })

                if case let .peer(peerId) = self.chatLocation {
                    self.chatUnreadCountDisposable?.dispose()
                    self.chatUnreadCountDisposable = (self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId),
                        TelegramEngine.EngineData.Item.Messages.TotalReadCounters(),
                        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                    )
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peerUnreadCount, totalReadCounters, notificationSettings in
                        guard let strongSelf = self else {
                            return
                        }
                        let unreadCount: Int32 = Int32(peerUnreadCount)
                        
                        let inAppSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                        let totalChatCount: Int32 = renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: totalReadCounters._asCounters()).0
                        
                        var globalRemainingUnreadChatCount = totalChatCount
                        if !notificationSettings._asNotificationSettings().isRemovedFromTotalUnreadCount(default: false) && unreadCount > 0 {
                            if case .messages = inAppSettings.totalUnreadCountDisplayCategory {
                                globalRemainingUnreadChatCount -= unreadCount
                            } else {
                                globalRemainingUnreadChatCount -= 1
                            }
                        }
                        
                        if globalRemainingUnreadChatCount > 0 {
                            strongSelf.navigationItem.badge = "\(globalRemainingUnreadChatCount)"
                        } else {
                            strongSelf.navigationItem.badge = ""
                        }
                    })
                
                    self.chatUnreadMentionCountDisposable?.dispose()
                    self.chatUnreadMentionCountDisposable = (self.context.account.viewTracker.unseenPersonalMessagesAndReactionCount(peerId: peerId, threadId: nil) |> deliverOnMainQueue).startStrict(next: { [weak self] mentionCount, reactionCount in
                        if let strongSelf = self {
                            if case .standard(.previewing) = strongSelf.presentationInterfaceState.mode {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = 0
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = 0
                            } else {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = mentionCount
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = reactionCount
                            }
                        }
                    })
                } else if let peerId = self.chatLocation.peerId, let threadId = self.chatLocation.threadId {
                    self.chatUnreadMentionCountDisposable?.dispose()
                    self.chatUnreadMentionCountDisposable = (self.context.account.viewTracker.unseenPersonalMessagesAndReactionCount(peerId: peerId, threadId: threadId) |> deliverOnMainQueue).startStrict(next: { [weak self] mentionCount, reactionCount in
                        if let strongSelf = self {
                            if case .standard(.previewing) = strongSelf.presentationInterfaceState.mode {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = 0
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = 0
                            } else {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = mentionCount
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = reactionCount
                            }
                        }
                    })
                }
                
                let engine = self.context.engine
                let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])

                let activitySpace: PeerActivitySpace?
                switch self.chatLocation {
                case let .peer(peerId):
                    activitySpace = PeerActivitySpace(peerId: peerId, category: .global)
                case let .replyThread(replyThreadMessage):
                    activitySpace = PeerActivitySpace(peerId: replyThreadMessage.peerId, category: .thread(replyThreadMessage.threadId))
                case .customChatContents:
                    activitySpace = nil
                }
                
                if let activitySpace = activitySpace, let peerId = peerId {
                    self.peerInputActivitiesDisposable?.dispose()
                    self.peerInputActivitiesDisposable = (self.context.account.peerInputActivities(peerId: activitySpace)
                    |> mapToSignal { activities -> Signal<[(Peer, PeerInputActivity)], NoError> in
                        var foundAllPeers = true
                        var cachedResult: [(Peer, PeerInputActivity)] = []
                        previousPeerCache.with { dict -> Void in
                            for (peerId, activity) in activities {
                                if let peer = dict[peerId] {
                                    cachedResult.append((peer, activity))
                                } else {
                                    foundAllPeers = false
                                    break
                                }
                            }
                        }
                        if foundAllPeers {
                            return .single(cachedResult)
                        } else {
                            return engine.data.get(EngineDataMap(
                                activities.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0.0) }
                            ))
                            |> map { peerMap -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let maybePeer = peerMap[peerId], let peer = maybePeer {
                                        result.append((peer._asPeer(), activity))
                                        peerCache[peerId] = peer._asPeer()
                                    }
                                }
                                let _ = previousPeerCache.swap(peerCache)
                                return result
                            }
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] activities in
                        if let strongSelf = self {
                            let displayActivities = activities.filter({
                                switch $0.1 {
                                    case .speakingInGroupCall, .interactingWithEmoji:
                                        return false
                                    default:
                                        return true
                                }
                            })
                            strongSelf.chatTitleView?.inputActivities = (peerId, displayActivities)
                            
                            strongSelf.peerInputActivitiesPromise.set(.single(activities))
                            
                            for activity in activities {
                                if case let .interactingWithEmoji(emoticon, messageId, maybeInteraction) = activity.1, let interaction = maybeInteraction {
                                    var found = false
                                    strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode({ itemNode in
                                        if !found, let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode, let item = itemNode.item {
                                            if item.message.id == messageId {
                                                itemNode.playEmojiInteraction(interaction)
                                                found = true
                                            }
                                        }
                                    })
                                    
                                    if found {
                                        let _ = strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .seeingEmojiInteraction(emoticon: emoticon), isPresent: true)
                                    }
                                }
                            }
                        }
                    })
                }
            }
            
            if let peerId = peerId {
                self.sentMessageEventsDisposable.set((self.context.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId)
                |> deliverOnMainQueue).startStrict(next: { [weak self] eventGroup in
                    guard let self else {
                        return
                    }
                    let inAppNotificationSettings = self.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                    if inAppNotificationSettings.playSounds, let firstEvent = eventGroup.first, !firstEvent.isSilent {
                        serviceSoundManager.playMessageDeliveredSound()
                    }
                    if self.presentationInterfaceState.subject != .scheduledMessages, let firstEvent = eventGroup.first, firstEvent.id.namespace == Namespaces.Message.ScheduledCloud {
                        if eventGroup.contains(where: { $0.isPendingProcessing }) {
                            self.openScheduledMessages(completion: { [weak self] c in
                                guard let self else {
                                    return
                                }
                                
                                c.dismissAllUndoControllers()
                                
                                Queue.mainQueue().after(0.5) { [weak c] in
                                    c?.displayProcessingVideoTooltip(messageId: firstEvent.id)
                                }
                                
                                c.present(
                                    UndoOverlayController(
                                        presentationData: self.presentationData,
                                        content: .universalImage(
                                            image: generateTintedImage(image: UIImage(bundleImageName: "Chat/ToastImprovingVideo"), color: .white)!,
                                            size: nil,
                                            title: self.presentationData.strings.Chat_ToastImprovingVideo_Title,
                                            text: self.presentationData.strings.Chat_ToastImprovingVideo_Text,
                                            customUndoText: nil,
                                            timeout: 5.0
                                        ),
                                        elevatedLayout: false,
                                        position: .top,
                                        action: { _ in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            })
                        }
                    }
                    
                    if self.shouldDisplayChecksTooltip {
                        Queue.mainQueue().after(1.0) { [weak self] in
                            self?.displayChecksTooltip()
                        }
                        self.shouldDisplayChecksTooltip = false
                        self.checksTooltipDisposable.set(self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.newcomerTicks.id).startStrict())
                    }
                    
                    if let shouldDisplayProcessingVideoTooltip = self.shouldDisplayProcessingVideoTooltip {
                        self.shouldDisplayProcessingVideoTooltip = nil
                        Queue.mainQueue().after(1.0) { [weak self] in
                            self?.displayProcessingVideoTooltip(messageId: shouldDisplayProcessingVideoTooltip)
                        }
                    }
                }))
            
                self.failedMessageEventsDisposable.set((self.context.account.pendingMessageManager.failedMessageEvents(peerId: peerId)
                |> deliverOnMainQueue).startStrict(next: { [weak self] reason in
                    if let strongSelf = self, strongSelf.currentFailedMessagesAlertController == nil {
                        let text: String
                        var title: String?
                        let moreInfo: Bool
                        switch reason {
                        case .flood:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorFlood
                            moreInfo = true
                        case .sendingTooFast:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorTooFast
                            title = strongSelf.presentationData.strings.Conversation_SendMessageErrorTooFastTitle
                            moreInfo = false
                        case .publicBan:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorGroupRestricted
                            moreInfo = true
                        case .mediaRestricted:
                            text = strongSelf.restrictedSendingContentsText()
                            moreInfo = false
                        case .slowmodeActive:
                            text = strongSelf.presentationData.strings.Chat_SlowmodeSendError
                            moreInfo = false
                        case .tooMuchScheduled:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorTooMuchScheduled
                            moreInfo = false
                        case .voiceMessagesForbidden:
                            strongSelf.interfaceInteraction?.displayRestrictedInfo(.premiumVoiceMessages, .alert)
                            return
                        case .nonPremiumMessagesForbidden:
                            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer {
                                text = strongSelf.presentationData.strings.Conversation_SendMessageErrorNonPremiumForbidden(EnginePeer(peer).compactDisplayTitle).string
                                moreInfo = false
                            } else {
                                return
                            }
                        }
                        let actions: [TextAlertAction]
                        if moreInfo {
                            actions = [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Generic_ErrorMoreInfo, action: {
                                self?.openPeerMention("spambot", navigation: .chat(textInputState: nil, subject: nil, peekData: nil))
                            }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        } else {
                            actions = [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        }
                        let controller = textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: title, text: text, actions: actions)
                        strongSelf.currentFailedMessagesAlertController = controller
                        strongSelf.present(controller, in: .window(.root))
                    }
                }))
                
                self.sentPeerMediaMessageEventsDisposable.dispose()
                self.sentPeerMediaMessageEventsDisposable.set(
                    (self.context.account.pendingPeerMediaUploadManager.sentMessageEvents(peerId: peerId)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                        if let self {
                            self.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }
                    })
                )
            }
        }
        
        historyNode.contentPositionChanged = { [weak self, weak historyNode] offset in
            guard let strongSelf = self, let historyNode, strongSelf.chatDisplayNode.historyNode === historyNode else {
                return
            }

            var minOffsetForNavigation: CGFloat = 40.0
            strongSelf.chatDisplayNode.historyNode.enumerateItemNodes { itemNode in
                if let itemNode = itemNode as? ChatMessageBubbleItemNode {
                    if let message = itemNode.item?.content.firstMessage, let adAttribute = message.adAttribute {
                        minOffsetForNavigation += itemNode.bounds.height

                        switch offset {
                        case let .known(offset):
                            if offset <= 50.0 {
                                strongSelf.chatDisplayNode.historyNode.markAdAsSeen(opaqueId: adAttribute.opaqueId)
                            }
                        default:
                            break
                        }
                    }
                }
                return false
            }
            
            let offsetAlpha: CGFloat
            let plainInputSeparatorAlpha: CGFloat
            switch offset {
                case let .known(offset):
                    if offset < minOffsetForNavigation {
                        offsetAlpha = 0.0
                    } else {
                        offsetAlpha = 1.0
                    }
                    if offset < 4.0 {
                        plainInputSeparatorAlpha = 0.0
                    } else {
                        plainInputSeparatorAlpha = 1.0
                    }
                case .unknown:
                    offsetAlpha = 1.0
                    plainInputSeparatorAlpha = 1.0
                case .none:
                    offsetAlpha = 0.0
                    plainInputSeparatorAlpha = 0.0
            }
            
            strongSelf.shouldDisplayDownButton = !offsetAlpha.isZero
            strongSelf.controllerInteraction?.recommendedChannelsOpenUp = !strongSelf.shouldDisplayDownButton
            strongSelf.updateDownButtonVisibility()
            strongSelf.chatDisplayNode.updatePlainInputSeparatorAlpha(plainInputSeparatorAlpha, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        historyNode.scrolledToIndex = { [weak self] toSubject, initial in
            if let strongSelf = self, case let .message(index) = toSubject.index {
                if case let .message(messageSubject, _, _, _) = strongSelf.subject, initial, case let .id(messageId) = messageSubject, messageId != index.id {
                    if messageId.peerId == index.id.peerId {
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.Conversation_MessageDoesntExist, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
                    }
                } else if let controllerInteraction = strongSelf.controllerInteraction {
                    var mappedId = index.id
                    if index.timestamp == 0 {
                        if case let .replyThread(message) = strongSelf.chatLocation, let channelMessageId = message.channelMessageId {
                            mappedId = channelMessageId
                        }
                    }
                    
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(mappedId) {
                        if toSubject.setupReply {
                            Queue.mainQueue().after(0.1) {
                                strongSelf.interfaceInteraction?.setupReplyMessage(mappedId, { _, f in f() })
                            }
                        }
                        
                        let highlightedState = ChatInterfaceHighlightedState(messageStableId: message.stableId, quote: toSubject.quote.flatMap { quote in ChatInterfaceHighlightedState.Quote(string: quote.string, offset: quote.offset) })
                        controllerInteraction.highlightedState = highlightedState
                        strongSelf.updateItemNodesHighlightedStates(animated: initial)
                        strongSelf.contentData?.scrolledToMessageIdValue = ScrolledToMessageId(id: mappedId, allowedReplacementDirection: [])
                        
                        var hasQuote = false
                        if let quote = toSubject.quote {
                            if message.text.contains(quote.string) {
                                hasQuote = true
                            } else {
                                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.Chat_ToastQuoteNotFound, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
                            }
                        }
                        
                        strongSelf.messageContextDisposable.set((Signal<Void, NoError>.complete() |> delay(hasQuote ? 1.5 : 0.7, queue: Queue.mainQueue())).startStrict(completed: {
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                if controllerInteraction.highlightedState == highlightedState {
                                    controllerInteraction.highlightedState = nil
                                    strongSelf.updateItemNodesHighlightedStates(animated: true)
                                }
                            }
                        }))
                        
                        if let (messageId, params) = strongSelf.scheduledScrollToMessageId {
                            strongSelf.scheduledScrollToMessageId = nil
                            if let timecode = params.timestamp, message.id == messageId {
                                Queue.mainQueue().after(0.2) {
                                    let _ = strongSelf.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .timecode(timecode)))
                                }
                            }
                        } else if case let .message(_, _, maybeTimecode, _) = strongSelf.subject, let timecode = maybeTimecode, initial {
                            Queue.mainQueue().after(0.2) {
                                let _ = strongSelf.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .timecode(timecode)))
                            }
                        }
                    }
                }
            }
        }
        
        historyNode.scrolledToSomeIndex = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contentData?.scrolledToMessageIdValue = nil
        }
        
        historyNode.maxVisibleMessageIndexUpdated = { [weak self] index in
            if let strongSelf = self, let contentData = strongSelf.contentData, !contentData.historyNavigationStack.isEmpty {
                contentData.historyNavigationStack.filterOutIndicesLessThan(index)
            }
        }
        
        self.hasActiveGroupCallDisposable?.dispose()
        let hasActiveCalls: Signal<Bool, NoError>
        if let callManager = self.context.sharedContext.callManager as? PresentationCallManagerImpl {
            hasActiveCalls = callManager.hasActiveCalls
            
            self.hasActiveGroupCallDisposable = ((callManager.currentGroupCallSignal
            |> map { call -> Bool in
                return call != nil
            }) |> deliverOnMainQueue).startStrict(next: { [weak self] hasActiveGroupCall in
                self?.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                    return state.updatedHasActiveGroupCall(hasActiveGroupCall)
                })
            })
        } else {
            hasActiveCalls = .single(false)
        }
        
        let shouldBeActive = combineLatest(self.context.sharedContext.mediaManager.audioSession.isPlaybackActive() |> deliverOnMainQueue, historyNode.hasVisiblePlayableItemNodes, hasActiveCalls)
        |> mapToSignal { [weak self] isPlaybackActive, hasVisiblePlayableItemNodes, hasActiveCalls -> Signal<Bool, NoError> in
            if hasVisiblePlayableItemNodes && !isPlaybackActive && !hasActiveCalls {
                return Signal<Bool, NoError> { [weak self] subscriber in
                    guard let strongSelf = self else {
                        subscriber.putCompletion()
                        return EmptyDisposable
                    }
                    
                    subscriber.putNext(strongSelf.traceVisibility() && isTopmostChatController(strongSelf) && !strongSelf.context.sharedContext.mediaManager.audioSession.isOtherAudioPlaying())
                    subscriber.putCompletion()
                    return EmptyDisposable
                } |> then(.complete() |> delay(1.0, queue: Queue.mainQueue())) |> restart
            } else {
                return .single(false)
            }
        }
        
        let buttonAction = { [weak self] in
            guard let self, self.traceVisibility() && isTopmostChatController(self) else {
                return
            }
            self.videoUnmuteTooltipController?.dismiss()
            
            var actions: [(Bool, (Double?) -> Void)] = []
            var hasUnconsumed = false
            self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let (action, _, _, isUnconsumed, _) = itemNode.playMediaWithSound() {
                    if case let .visible(fraction, _) = itemNode.visibility, fraction > 0.7 {
                        actions.insert((isUnconsumed, action), at: 0)
                        if !hasUnconsumed && isUnconsumed {
                            hasUnconsumed = true
                        }
                    }
                }
            }
            for (isUnconsumed, action) in actions {
                if (!hasUnconsumed || isUnconsumed) {
                    action(nil)
                    break
                }
            }
        }
        
        self.volumeButtonsListener = nil
        self.volumeButtonsListener = VolumeButtonsListener(
            sharedContext: self.context.sharedContext,
            isCameraSpecific: false,
            shouldBeActive: shouldBeActive,
            upPressed: buttonAction,
            downPressed: buttonAction
        )

        historyNode.openNextChannelToRead = { [weak self] peer, threadData, location in
            guard let strongSelf = self else {
                return
            }
            if let navigationController = strongSelf.effectiveNavigationController {
                let _ = ApplicationSpecificNotice.incrementNextChatSuggestionTip(accountManager: strongSelf.context.sharedContext.accountManager).startStandalone()

                let snapshotState = strongSelf.chatDisplayNode.prepareSnapshotState(
                    titleViewSnapshotState: strongSelf.chatTitleView?.prepareSnapshotState(),
                    avatarSnapshotState: (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.prepareSnapshotState()
                )

                var nextFolderId: Int32?
                switch location {
                case let .folder(id, _):
                    nextFolderId = id
                case .same:
                    nextFolderId = strongSelf.currentChatListFilter
                default:
                    nextFolderId = nil
                }
                
                var updatedChatNavigationStack = strongSelf.chatNavigationStack
                updatedChatNavigationStack.removeAll(where: { $0 == ChatNavigationStackItem(peerId: peer.id, threadId: threadData?.id) })
                if let peerId = strongSelf.chatLocation.peerId {
                    updatedChatNavigationStack.insert(ChatNavigationStackItem(peerId: peerId, threadId: strongSelf.chatLocation.threadId), at: 0)
                }
                
                let chatLocation: NavigateToChatControllerParams.Location
                if let threadData {
                    chatLocation = .replyThread(ChatReplyThreadMessage(
                        peerId: peer.id,
                        threadId: threadData.id,
                        channelMessageId: nil,
                        isChannelPost: false,
                        isForumPost: true,
                        isMonoforumPost: false,
                        maxMessage: nil,
                        maxReadIncomingMessageId: nil,
                        maxReadOutgoingMessageId: nil,
                        unreadCount: 0,
                        initialFilledHoles: IndexSet(),
                        initialAnchor: .automatic,
                        isNotAvailable: false
                    ))
                } else {
                    chatLocation = .peer(peer)
                }

                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: chatLocation, animated: false, chatListFilter: nextFolderId, chatNavigationStack: updatedChatNavigationStack, completion: { nextController in
                    (nextController as! ChatControllerImpl).animateFromPreviousController(snapshotState: snapshotState)
                }, customChatNavigationStack: strongSelf.customChatNavigationStack))
            }
        }
        
        historyNode.beganDragging = { [weak self] in
            guard let self else {
                return
            }
            if self.presentationInterfaceState.search != nil && self.presentationInterfaceState.historyFilter != nil {
                self.chatDisplayNode.historyNode.addAfterTransactionsCompleted { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.chatDisplayNode.dismissInput()
                }
            }
        }
    
        historyNode.didScrollWithOffset = { [weak self] offset, transition, itemNode, isTracking in
            guard let strongSelf = self else {
                return
            }

            //print("didScrollWithOffset offset: \(offset), itemNode: \(String(describing: itemNode))")
            
            if offset > 0.0 {
                if var scrolledToMessageIdValue = strongSelf.contentData?.scrolledToMessageIdValue {
                    scrolledToMessageIdValue.allowedReplacementDirection.insert(.up)
                    strongSelf.contentData?.scrolledToMessageIdValue = scrolledToMessageIdValue
                }
            } else if offset < 0.0 {
                strongSelf.contentData?.scrolledToMessageIdValue = nil
            }

            if let currentPinchSourceItemNode = strongSelf.currentPinchSourceItemNode {
                if let itemNode = itemNode {
                    if itemNode === currentPinchSourceItemNode {
                        strongSelf.currentPinchController?.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                    }
                } else {
                    strongSelf.currentPinchController?.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
            }
            
            if isTracking {
                strongSelf.chatDisplayNode.loadingPlaceholderNode?.addContentOffset(offset: offset, transition: transition)
            }
            strongSelf.chatDisplayNode.messageTransitionNode.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode, isRotated: strongSelf.chatDisplayNode.historyNode.rotated)
        }
        
        historyNode.hasAtLeast3MessagesUpdated = { [weak self] hasAtLeast3Messages in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: false, { $0.updatedHasAtLeast3Messages(hasAtLeast3Messages) })
            }
        }
        
        historyNode.hasPlentyOfMessagesUpdated = { [weak self] hasPlentyOfMessages in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: false, { $0.updatedHasPlentyOfMessages(hasPlentyOfMessages) })
            }
        }
        
        if self.didAppear {
            historyNode.canReadHistory.set(self.computedCanReadHistoryPromise.get())
        }
    }
}
