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
    func unblockPeer() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let unblockingPeer = self.unblockingPeer
        unblockingPeer.set(true)
        
        var restartBot = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
            restartBot = true
        }
        self.editMessageDisposable.set((self.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peerId, isBlocked: false)
        |> afterDisposed({ [weak self] in
            Queue.mainQueue().async {
                unblockingPeer.set(false)
                if let strongSelf = self, restartBot {
                    strongSelf.startBot(strongSelf.presentationInterfaceState.botStartPayload)
                }
            }
        })).startStrict())
    }
    
    func reportPeer() {
        guard let renderedPeer = self.presentationInterfaceState.renderedPeer, let peer = renderedPeer.chatMainPeer, let chatPeer = renderedPeer.peer else {
            return
        }
        self.chatDisplayNode.dismissInput()
        
        if let peer = peer as? TelegramChannel, let username = peer.addressName, !username.isEmpty {
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            
            var items: [ActionSheetItem] = []
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ReportSpamAndLeave, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.deleteChat(reportChatSpam: true)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            self.present(actionSheet, in: .window(.root))
        } else if let _ = peer as? TelegramUser {
            let presentationData = self.presentationData
            let controller = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            var reportSpam = true
            var deleteChat = true
            var items: [ActionSheetItem] = []
            if !peer.isDeleted {
                items.append(ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(EnginePeer(peer).compactDisplayTitle).string))
            }
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
                ActionSheetCheckboxItem(title: presentationData.strings.ReportSpam_DeleteThisChat, label: "", value: deleteChat, action: { [weak controller] checkValue in
                    deleteChat = checkValue
                    controller?.updateItem(groupIndex: 0, itemIndex: 2, { item in
                        if let item = item as? ActionSheetCheckboxItem {
                            return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                        }
                        return item
                    })
                }),
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(EnginePeer(peer).compactDisplayTitle).string, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).startStandalone()
                    if let _ = chatPeer as? TelegramSecretChat {
                        let _ = strongSelf.context.engine.peers.terminateSecretChat(peerId: chatPeer.id, requestRemoteHistoryRemoval: true).startStandalone()
                    }
                    if deleteChat {
                        let _ = strongSelf.context.engine.peers.removePeerChat(peerId: chatPeer.id, reportChatSpam: reportSpam).startStandalone()
                        strongSelf.effectiveNavigationController?.filterController(strongSelf, animated: true)
                    } else if reportSpam {
                        let _ = strongSelf.context.engine.peers.reportPeer(peerId: peer.id, reason: .spam, message: "").startStandalone()
                    }
                })
            ] as [ActionSheetItem])
            
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        } else {
            let title: String
            var infoString: String?
            if let _ = peer as? TelegramGroup {
                title = self.presentationData.strings.Conversation_ReportSpamAndLeave
                infoString = self.presentationData.strings.Conversation_ReportSpamGroupConfirmation
            } else if let channel = peer as? TelegramChannel {
                title = self.presentationData.strings.Conversation_ReportSpamAndLeave
                if case .group = channel.info {
                    infoString = self.presentationData.strings.Conversation_ReportSpamGroupConfirmation
                } else {
                    infoString = self.presentationData.strings.Conversation_ReportSpamChannelConfirmation
                }
            } else {
                title = self.presentationData.strings.Conversation_ReportSpam
                infoString = self.presentationData.strings.Conversation_ReportSpamConfirmation
            }
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            
            var items: [ActionSheetItem] = []
            if let infoString = infoString {
                items.append(ActionSheetTextItem(title: infoString))
            }
            items.append(ActionSheetButtonItem(title: title, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.deleteChat(reportChatSpam: true)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            self.present(actionSheet, in: .window(.root))
        }
    }
}
