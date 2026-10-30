import Foundation
import UIKit
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
import UrlEscaping
import ContextUI
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
import AlertComponent
import AlertCheckComponent
import ComponentFlow
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

extension ChatControllerImpl {
    func navigationButtonAction(_ action: ChatNavigationButtonAction) {
        switch action {
        case .spacer, .toggleInfoPanel:
            break
        case .toggleSideList:
            self.toggleSideList()
        case .cancelMessageSelection:
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
        case .clearHistory:
            guard !self.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            
            if case let .peer(peerId) = self.chatLocation {
                let beginClear: (InteractiveHistoryClearingType) -> Void = { [weak self] type in
                    self?.beginClearHistory(type: type)
                }
                
                let context = self.context
                let _ = (self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.CanDeleteHistory(id: peerId)
                )
                |> map { participantCount, canDeleteHistory -> (isLargeGroupOrChannel: Bool, canClearChannel: Bool) in
                    if let participantCount = participantCount {
                        return (participantCount > 1000, canDeleteHistory)
                    } else {
                        return (false, false)
                    }
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak self] parameters in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let (isLargeGroupOrChannel, canClearChannel) = parameters
                    
                    guard let peer = strongSelf.presentationInterfaceState.renderedPeer, let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
                        return
                    }
                    
                    enum ClearType {
                        case savedMessages
                        case secretChat
                        case group
                        case channel
                        case user
                    }
                    
                    let canClearCache: Bool
                    let canClearForMyself: ClearType?
                    let canClearForEveryone: ClearType?
                    
                    if peerId == strongSelf.context.account.peerId {
                        canClearCache = false
                        canClearForMyself = .savedMessages
                        canClearForEveryone = nil
                    } else if chatPeer is TelegramSecretChat {
                        canClearCache = false
                        canClearForMyself = .secretChat
                        canClearForEveryone = nil
                    } else if let group = chatPeer as? TelegramGroup {
                        canClearCache = false
                        
                        switch group.role {
                        case .creator:
                            canClearForMyself = .group
                            canClearForEveryone = nil
                        case .admin, .member:
                            canClearForMyself = .group
                            canClearForEveryone = nil
                        }
                    } else if let channel = chatPeer as? TelegramChannel {
                        if let username = channel.addressName, !username.isEmpty {
                            if isLargeGroupOrChannel {
                                canClearCache = true
                                canClearForMyself = nil
                                canClearForEveryone = canClearChannel ? .channel : nil
                            } else {
                                canClearCache = true
                                canClearForMyself = nil
                                
                                switch channel.info {
                                case .broadcast:
                                    if channel.flags.contains(.isCreator) {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    } else {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    }
                                case .group:
                                    if channel.flags.contains(.isCreator) {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    } else {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    }
                                }
                            }
                        } else {
                            if isLargeGroupOrChannel {
                                switch channel.info {
                                case .broadcast:
                                    canClearCache = true
                                    
                                    canClearForMyself = .channel
                                    canClearForEveryone = nil
                                case .group:
                                    canClearCache = false
                                    
                                    canClearForMyself = .channel
                                    canClearForEveryone = nil
                                }
                            } else {
                                switch channel.info {
                                case .broadcast:
                                    canClearCache = true
                                    
                                    if channel.flags.contains(.isCreator) {
                                        canClearForMyself = .channel
                                        canClearForEveryone = nil
                                    } else {
                                        canClearForMyself = .channel
                                        canClearForEveryone = nil
                                    }
                                case .group:
                                    canClearCache = false
                                    
                                    if channel.flags.contains(.isCreator) {
                                        canClearForMyself = .group
                                        canClearForEveryone = nil
                                    } else {
                                        canClearForMyself = .group
                                        canClearForEveryone = nil
                                    }
                                }
                            }
                        }
                    } else {
                        canClearCache = false
                        canClearForMyself = .user
                        
                        if let user = chatPeer as? TelegramUser, user.botInfo != nil {
                            canClearForEveryone = nil
                        } else {
                            canClearForEveryone = .user
                        }
                    }
                    
                    var actions: [AlertScreen.Action] = []
                    let clearAlertController: AlertScreen
                    
                    if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        actions.append(AlertScreen.Action(title: strongSelf.presentationData.strings.ScheduledMessages_ClearAllConfirmation, type: .destructive, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let alertController = textAlertController(
                                context: strongSelf.context,
                                title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle,
                                text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText,
                                actions: [
                                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                    }),
                                    TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                        beginClear(.scheduledMessages)
                                    })
                                ]
                            )
                            strongSelf.present(alertController, in: .window(.root))
                        }))
                        actions.append(AlertScreen.Action(title: strongSelf.presentationData.strings.Common_Cancel))
                        
                        clearAlertController = deleteChatPeerAlertScreen(context: strongSelf.context, peer: EnginePeer(mainPeer), chatPeer: EnginePeer(chatPeer), action: nil, title: strongSelf.presentationData.strings.ScheduledMessages_Title, actions: actions)
                    } else {
                        var alertAction: DeleteChatPeerAction?
                        if let _ = canClearForMyself ?? canClearForEveryone {
                            alertAction = .clearHistory(canClearCache: canClearCache)
                            
                            if let canClearForEveryone = canClearForEveryone {
                                let text: String
                                let confirmationText: String
                                switch canClearForEveryone {
                                case .user:
                                    text = strongSelf.presentationData.strings.ChatList_DeleteForEveryone(EnginePeer(mainPeer).compactDisplayTitle).string
                                    confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationText
                                default:
                                    text = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                    confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForAllMembersConfirmationText
                                }
                                actions.append(AlertScreen.Action(title: text, type: .destructive, action: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let alertController = textAlertController(
                                        context: strongSelf.context,
                                        title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle,
                                        text: confirmationText,
                                        actions: [
                                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                            }),
                                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                                beginClear(.forEveryone)
                                            })
                                        ]
                                    )
                                    strongSelf.present(alertController, in: .window(.root))
                                }))
                            }
                            if let canClearForMyself = canClearForMyself {
                                let text: String
                                switch canClearForMyself {
                                case .savedMessages, .secretChat:
                                    text = strongSelf.presentationData.strings.Conversation_ClearAll
                                default:
                                    text = strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser
                                }
                                actions.append(AlertScreen.Action(title: text, type: .destructive, action: { [weak self] in
                                    if mainPeer.id == context.account.peerId, let strongSelf = self {
                                        let alertController = textAlertController(
                                            context: strongSelf.context,
                                            title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle,
                                            text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText,
                                            actions: [
                                                TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                                }),
                                                TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                                    beginClear(.forLocalPeer)
                                                })
                                            ]
                                        )
                                        strongSelf.present(alertController, in: .window(.root))
                                    } else {
                                        beginClear(.forLocalPeer)
                                    }
                                }))
                            }
                        }
                        
                        if canClearCache {
                            actions.append(AlertScreen.Action(title: strongSelf.presentationData.strings.Conversation_ClearCache, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.navigationButtonAction(.clearCache)
                            }))
                        }
                        
                        if chatPeer.canSetupAutoremoveTimeout(accountPeerId: strongSelf.context.account.peerId) {
                            actions.append(AlertScreen.Action(title: strongSelf.presentationInterfaceState.autoremoveTimeout == nil ? strongSelf.presentationData.strings.Conversation_AutoremoveActionEnable : strongSelf.presentationData.strings.Conversation_AutoremoveActionEdit, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.presentAutoremoveSetup()
                            }))
                        }
                        
                        actions.append(AlertScreen.Action(title: strongSelf.presentationData.strings.Common_Cancel))
                        
                        clearAlertController = deleteChatPeerAlertScreen(context: strongSelf.context, peer: EnginePeer(mainPeer), chatPeer: EnginePeer(chatPeer), action: alertAction, actions: actions)
                    }
                    
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(clearAlertController, in: .window(.root))
                })
            }
        case let .openChatInfo(expandAvatar, section):
            // A tap on the header's pill or avatar: the profile this pushes expands out of them.
            let fromHeader = self.openChatInfoFromHeader
            self.openChatInfoFromHeader = false
            let _ = self.presentVoiceMessageDiscardAlert(action: { [weak self] in
                guard let self else {
                    return
                }
                guard let contentData = self.contentData else {
                    return
                }
                
                switch contentData.chatLocationInfoData {
                case let .peer(peerView):
                    self.navigationActionDisposable.set((peerView.get()
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
                        guard let self else {
                            return
                        }
                        guard var peer = peerView.peers[peerView.peerId] else {
                            return
                        }
                        if let channel = peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainPeer = peerView.peers[linkedMonoforumId] as? TelegramChannel {
                            peer = mainPeer
                            
                            guard let navigationController = self.effectiveNavigationController else {
                                return
                            }
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                navigationController: navigationController,
                                context: self.context,
                                chatLocation: .peer(.channel(mainPeer)),
                                chatLocationContextHolder: Atomic(value: nil),
                                keepStack: .always,
                                useExisting: false,
                                animated: true
                            ))
                            return
                        }
                        
                        if peer.restrictionText(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) == nil && !self.presentationInterfaceState.isNotAccessible {
                            if peer.id == self.context.account.peerId {
                                // With the side list, it lists Saved Messages' chats; the profile has no Chats tab.
                                var mode: PeerInfoControllerMode = .generic
                                if case .savedMessages = self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState) {
                                    mode = .chatSideList
                                }
                                if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), mode: mode, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                                    self.effectiveNavigationController?.pushViewController(infoController)
                                }
                            } else {
                                var expandAvatar = expandAvatar
                                if peer.smallProfileImage == nil {
                                    expandAvatar = false
                                }
                                if let validLayout = self.validLayout, validLayout.deviceMetrics.type == .tablet {
                                    expandAvatar = false
                                }
                                let mode: PeerInfoControllerMode
                                switch section {
                                case .groupsInCommon:
                                    mode = .groupsInCommon
                                case .recommendedChannels:
                                    mode = .recommendedChannels
                                default:
                                    mode = .generic
                                }
                                if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: true, requestsContext: self.contentData?.inviteRequestsContext) {
                                    if fromHeader {
                                        self.expansionProfileToPush = infoController
                                    }
                                    self.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }

                            let _ = self.dismissPreviewing?(false)
                        }
                    }))
                case .replyThread:
                    if let peer = self.presentationInterfaceState.renderedPeer?.peer, case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
                        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), mode: .forumTopic(thread: replyThreadMessage), avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                            self.effectiveNavigationController?.pushViewController(infoController)
                        }
                    } else if let monoforumPeer = self.presentationInterfaceState.renderedPeer?.peer, case let .replyThread(replyThreadMessage) = self.chatLocation, monoforumPeer.isMonoForum {
                        let context = self.context
                        if #available(iOS 13.0, *) {
                            Task { @MainActor [weak self] in
                                guard let peer = await context.engine.data.get(
                                    TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id(replyThreadMessage.threadId))
                                ).get() else {
                                    return
                                }
                                guard let self else {
                                    return
                                }
                                if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer, mode: .monoforum(monoforumPeer.id), avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                                    self.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }
                        }
                    } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum, case let .replyThread(message) = self.chatLocation {
                        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(channel), mode: .forumTopic(thread: message), avatarInitiallyExpanded: false, fromChat: true, requestsContext: self.contentData?.inviteRequestsContext) {
                            self.effectiveNavigationController?.pushViewController(infoController)
                        }
                    }
                case .customChatContents:
                    break
                }
            })
        case .search:
            self.interfaceInteraction?.beginMessageSearch(.everything, "")
        case .dismiss:
            if self.attemptNavigation({}) {
                self.dismiss()
            }
        case .clearCache:
            guard let contentData = self.contentData else {
                return
            }
            
            let controller = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: nil))
            self.present(controller, in: .window(.root))
            
            let disposable: MetaDisposable
            if let currentDisposable = self.clearCacheDisposable {
                disposable = currentDisposable
            } else {
                disposable = MetaDisposable()
                self.clearCacheDisposable = disposable
            }
        
            switch contentData.chatLocationInfoData {
            case let .peer(peerView):
                self.navigationActionDisposable.set((peerView.get()
                |> take(1)
                |> deliverOnMainQueue).startStrict(next: { [weak self, controller] peerView in
                    guard let strongSelf = self, let peer = peerView.peers[peerView.peerId] else {
                        return
                    }
                    let peerId = peer.id
                    
                    let _ = (strongSelf.context.engine.resources.collectCacheUsageStats(peerId: peer.id)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] result in
                        controller?.dismiss()
                        
                        guard let strongSelf = self, case let .result(stats) = result, let categories = stats.media[peer.id] else {
                            return
                        }
                        let presentationData = strongSelf.presentationData
                        
                        let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]
                        
                        var totalSize: Int64 = 0
                        
                        func stringForCategory(strings: PresentationStrings, category: PeerCacheUsageCategory) -> String {
                            switch category {
                                case .image:
                                    return strings.Cache_Photos
                                case .video:
                                    return strings.Cache_Videos
                                case .audio:
                                    return strings.Cache_Music
                                case .file:
                                    return strings.Cache_Files
                            }
                        }
                        
                        var sizeIndex: [PeerCacheUsageCategory: Int64] = [:]
                        var checkItems: [(category: PeerCacheUsageCategory, size: Int64, state: AlertCheckComponent.ExternalState)] = []
                        
                        for categoryId in validCategories {
                            if let media = categories[categoryId] {
                                var categorySize: Int64 = 0
                                for (_, size) in media {
                                    categorySize += size
                                }
                                sizeIndex[categoryId] = categorySize
                                totalSize += categorySize
                                if categorySize > 1024 {
                                    checkItems.append((categoryId, categorySize, AlertCheckComponent.ExternalState()))
                                }
                            }
                        }
                        
                        if checkItems.isEmpty {
                            strongSelf.presentClearCacheSuggestion()
                        } else {
                            let uncheckableSize = totalSize - checkItems.reduce(0, { $0 + $1.size })
                            
                            let isCategorySelected: (PeerCacheUsageCategory) -> Bool = { category in
                                if let item = checkItems.first(where: { $0.category == category }) {
                                    return item.state.value
                                }
                                return true
                            }
                            
                            var content = deleteChatPeerAlertContent(context: strongSelf.context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCache)
                            for item in checkItems {
                                content.append(AnyComponentWithIdentity(
                                    id: "category_\(item.category)",
                                    component: AnyComponent(
                                        AlertCheckComponent(title: "\(stringForCategory(strings: presentationData.strings, category: item.category)) · \(dataSizeString(item.size, formatting: DataSizeStringFormatting(presentationData: presentationData)))", alignment: .default, initialValue: true, externalState: item.state)
                                    )
                                ))
                            }
                            
                            let performClear: () -> Void = {
                                let clearCategories = sizeIndex.keys.filter({ isCategorySelected($0) })
                                let selectedSize = clearCategories.reduce(Int64(0), { $0 + (sizeIndex[$1] ?? 0) })
                                var clearMediaIds = Set<EngineMedia.Id>()
                                
                                var media = stats.media
                                if var categories = media[peerId] {
                                    for category in clearCategories {
                                        if let contents = categories[category] {
                                            for (mediaId, _) in contents {
                                                clearMediaIds.insert(mediaId)
                                            }
                                        }
                                        categories.removeValue(forKey: category)
                                    }
                                    
                                    media[peerId] = categories
                                }
                                
                                var clearResourceIds = Set<EngineMediaResource.Id>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(EngineMediaResource.Id(resourceId))
                                        }
                                    }
                                }
                                
                                var signal = strongSelf.context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds)
                                
                                var cancelImpl: (() -> Void)?
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                let progressSignal = Signal<Never, NoError> { subscriber in
                                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    return ActionDisposable { [weak controller] in
                                        Queue.mainQueue().async() {
                                            controller?.dismiss()
                                        }
                                    }
                                }
                                |> runOn(Queue.mainQueue())
                                |> delay(0.15, queue: Queue.mainQueue())
                                let progressDisposable = progressSignal.startStrict()
                                
                                signal = signal
                                |> afterDisposed {
                                    Queue.mainQueue().async {
                                        progressDisposable.dispose()
                                    }
                                }
                                cancelImpl = {
                                    disposable.set(nil)
                                }
                                disposable.set((signal
                                |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                                    if let strongSelf = self, let _ = strongSelf.validLayout {
                                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                                    }
                                }))

                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                            }
                            
                            let openStorageUsage: () -> Void = { [weak self] in
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                
                                if let strongSelf = self {
                                    let context = strongSelf.context
                                    let controller = StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
                                        return storageUsageExceptionsScreen(context: context, category: category)
                                    })
                                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                }
                            }
                            
                            let selectedSizeSignal: Signal<Int64, NoError> = combineLatest(checkItems.map { item -> Signal<Int64, NoError> in
                                return (Signal<Bool, NoError>.single(true) |> then(item.state.valueSignal))
                                |> map { value -> Int64 in
                                    return value ? item.size : 0
                                }
                            })
                            |> map { sizes -> Int64 in
                                return sizes.reduce(uncheckableSize, +)
                            }
                            |> distinctUntilChanged
                            
                            let actionsSignal: Signal<[AlertScreen.Action], NoError> = selectedSizeSignal
                            |> map { selectedSize -> [AlertScreen.Action] in
                                let title: String
                                if selectedSize == 0 {
                                    title = presentationData.strings.Cache_ClearNone
                                } else {
                                    title = presentationData.strings.Cache_Clear("\(dataSizeString(selectedSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string
                                }
                                return [
                                    AlertScreen.Action(id: "clear", title: title, type: .default, action: {
                                        performClear()
                                    }, isEnabled: .single(selectedSize != 0)),
                                    AlertScreen.Action(id: "storageUsage", title: presentationData.strings.ClearCache_StorageUsage, action: {
                                        openStorageUsage()
                                    }),
                                    AlertScreen.Action(title: presentationData.strings.Common_Cancel)
                                ]
                            }
                            
                            let controller = AlertScreen(
                                configuration: AlertScreen.Configuration(actionAlignment: .vertical),
                                contentSignal: .single(content),
                                actionsSignal: actionsSignal,
                                updatedPresentationData: (presentationData, strongSelf.context.sharedContext.presentationData)
                            )
                            strongSelf.chatDisplayNode.dismissInput()
                            strongSelf.present(controller, in: .window(.root))
                        }
                    })
                }))
            case .replyThread:
                break
            case .customChatContents:
                break
            }
        case .edit:
            self.editChat()
        }
    }
}
