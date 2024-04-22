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

extension ChatControllerImpl {
    func openStorySharing(messages: [Message]) {
        let context = self.context
        let subject: Signal<MediaEditorScreen.Subject?, NoError> = .single(.message(messages.map { $0.id }))
        
        let externalState = MediaEditorTransitionOutExternalState(
            storyTarget: nil,
            isForcedTarget: false,
            isPeerArchived: false,
            transitionOut: nil
        )
        
        let controller = MediaEditorScreen(
            context: context,
            mode: .storyEditor,
            subject: subject,
            transitionIn: nil,
            transitionOut: { _, _ in
                return nil
            },
            completion: { [weak self] result, commit in
                guard let self else {
                    return
                }
                let targetPeerId: EnginePeer.Id
                let target: Stories.PendingTarget
                if let sendAsPeerId = result.options.sendAsPeerId {
                    target = .peer(sendAsPeerId)
                    targetPeerId = sendAsPeerId
                } else {
                    target = .myStories
                    targetPeerId = self.context.account.peerId
                }
                externalState.storyTarget = target
                
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.proceedWithStoryUpload(target: target, result: result, existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
                }
                
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: targetPeerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer else {
                        return
                    }
                    let text: String
                    if case .channel = peer {
                        text = self.presentationData.strings.Story_MessageReposted_Channel(peer.compactDisplayTitle).string
                    } else {
                        text = self.presentationData.strings.Story_MessageReposted_Personal
                    }
                    Queue.mainQueue().after(0.25) {
                        self.present(UndoOverlayController(
                            presentationData: self.presentationData,
                            content: .forward(savedMessages: false, text: text),
                            elevatedLayout: false,
                            action: { _ in return false }
                        ), in: .current)
                        
                        Queue.mainQueue().after(0.1) {
                            self.chatDisplayNode.hapticFeedback.success()
                        }
                    }
                })

            }
        )
        self.push(controller)
    }
}
