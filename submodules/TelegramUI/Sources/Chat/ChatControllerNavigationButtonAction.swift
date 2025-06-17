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

extension ChatControllerImpl {
    func navigationButtonAction(_ action: ChatNavigationButtonAction) {
        switch action {
        case .spacer, .toggleInfoPanel:
            break
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
                    
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    
                    if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ScheduledMessages_ClearAllConfirmation, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                                TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                }),
                                TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                    beginClear(.scheduledMessages)
                                })
                            ], parseMarkdown: true), in: .window(.root))
                        }))
                    } else {
                        if let _ = canClearForMyself ?? canClearForEveryone {
                            items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: EnginePeer(mainPeer), chatPeer: EnginePeer(chatPeer), action: .clearHistory(canClearCache: canClearCache), strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                            
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
                                items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: confirmationText, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                        }),
                                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                            beginClear(.forEveryone)
                                        })
                                    ], parseMarkdown: true), in: .window(.root))
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
                                items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if mainPeer.id == context.account.peerId, let strongSelf = self {
                                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                            }),
                                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                                beginClear(.forLocalPeer)
                                            })
                                        ], parseMarkdown: true), in: .window(.root))
                                    } else {
                                        beginClear(.forLocalPeer)
                                    }
                                }))
                            }
                        }
                        
                        if canClearCache {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ClearCache, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.navigationButtonAction(.clearCache)
                            }))
                        }
                        
                        if chatPeer.canSetupAutoremoveTimeout(accountPeerId: strongSelf.context.account.peerId) {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationInterfaceState.autoremoveTimeout == nil ? strongSelf.presentationData.strings.Conversation_AutoremoveActionEnable : strongSelf.presentationData.strings.Conversation_AutoremoveActionEdit, color: .accent, action: { [weak actionSheet] in
                                guard let actionSheet = actionSheet else {
                                    return
                                }
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                actionSheet.dismissAnimated()
                                
                                strongSelf.presentAutoremoveSetup()
                            }))
                        }
                    }

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(actionSheet, in: .window(.root))
                })
            }
        case let .openChatInfo(expandAvatar, section):
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
                                if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
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
                                if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer, mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: true, requestsContext: self.contentData?.inviteRequestsContext) {
                                    self.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }
                            
                            let _ = self.dismissPreviewing?(false)
                        }
                    }))
                case .replyThread:
                    if let peer = self.presentationInterfaceState.renderedPeer?.peer, case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
                        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer, mode: .forumTopic(thread: replyThreadMessage), avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                            self.effectiveNavigationController?.pushViewController(infoController)
                        }
                    } else if let peer = self.presentationInterfaceState.renderedPeer?.peer, case let .replyThread(replyThreadMessage) = self.chatLocation, peer.isMonoForum {
                        let context = self.context
                        if #available(iOS 13.0, *) {
                            Task { @MainActor [weak self] in
                                guard let peer = await context.engine.data.get(
                                    TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(replyThreadMessage.threadId))
                                ).get() else {
                                    return
                                }
                                guard let self else {
                                    return
                                }
                                if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                                    self.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }
                        }
                    } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum, case let .replyThread(message) = self.chatLocation {
                        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: channel, mode: .forumTopic(thread: message), avatarInitiallyExpanded: false, fromChat: true, requestsContext: self.contentData?.inviteRequestsContext) {
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
                |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
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
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        
                        var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                        
                        var itemIndex = 1
                        
                        var selectedSize: Int64 = 0
                        let updateTotalSize: () -> Void = { [weak controller] in
                            controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                                let title: String
                                let filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                                selectedSize = filteredSize
                                
                                if filteredSize == 0 {
                                    title = presentationData.strings.Cache_ClearNone
                                } else {
                                    title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string
                                }
                                
                                if let item = item as? ActionSheetButtonItem {
                                    return ActionSheetButtonItem(title: title, color: filteredSize != 0 ? .accent : .disabled, enabled: filteredSize != 0, action: item.action)
                                }
                                return item
                            })
                        }
                        
                        let toggleCheck: (PeerCacheUsageCategory, Int) -> Void = { [weak controller] category, itemIndex in
                            if let (value, size) = sizeIndex[category] {
                                sizeIndex[category] = (!value, size)
                            }
                            controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                                if let item = item as? ActionSheetCheckboxItem {
                                    return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                                }
                                return item
                            })
                            updateTotalSize()
                        }
                        var items: [ActionSheetItem] = []
                        
                        items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCache, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder))
                        
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
                        
                        for categoryId in validCategories {
                            if let media = categories[categoryId] {
                                var categorySize: Int64 = 0
                                for (_, size) in media {
                                    categorySize += size
                                }
                                sizeIndex[categoryId] = (true, categorySize)
                                totalSize += categorySize
                                if categorySize > 1024 {
                                    let index = itemIndex
                                    items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, formatting: DataSizeStringFormatting(presentationData: presentationData)), value: true, action: { value in
                                        toggleCheck(categoryId, index)
                                    }))
                                    itemIndex += 1
                                }
                            }
                        }
                        selectedSize = totalSize
                        
                        if items.isEmpty {
                            strongSelf.presentClearCacheSuggestion()
                        } else {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string, action: {
                                let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                                var clearMediaIds = Set<MediaId>()
                                
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
                                
                                var clearResourceIds = Set<MediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(resourceId)
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

                                dismissAction()
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                            }))
                            
                            items.append(ActionSheetButtonItem(title: presentationData.strings.ClearCache_StorageUsage, action: { [weak self] in
                                dismissAction()
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                
                                if let strongSelf = self {
                                    let context = strongSelf.context
                                    let controller = StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
                                        return storageUsageExceptionsScreen(context: context, category: category)
                                    })
                                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                }
                            }))
                            
                            controller.setItemGroups([
                                ActionSheetItemGroup(items: items),
                                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                            ])
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
