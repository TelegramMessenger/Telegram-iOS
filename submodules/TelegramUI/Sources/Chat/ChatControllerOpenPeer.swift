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
    func openPeer(peer: EnginePeer?, navigation: ChatControllerInteractionNavigateToPeer, fromMessage: MessageReference?, fromReactionMessageId: MessageId? = nil, expandAvatar: Bool = false, peerTypes: ReplyMarkupButtonAction.PeerTypes? = nil) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            if case let .peer(currentPeerId) = self.chatLocation, peer?.id == currentPeerId {
                switch navigation {
                    case let .info(params):
                        var section: ChatNavigationButtonAction.ChatInfoSection?
                        if let params {
                            if params.switchToRecommendedChannels {
                                section = .recommendedChannels
                            } else if params.switchToGroupsInCommon {
                                section = .groupsInCommon
                            }
                            if params.ignoreInSavedMessages && currentPeerId == self.context.account.peerId {
                                self.playShakeAnimation()
                                return
                            }
                        }
                        self.navigationButtonAction(.openChatInfo(expandAvatar: expandAvatar, section: section))
                    case let .chat(textInputState, _, _):
                        if let textInputState = textInputState {
                            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return ($0.updatedInterfaceState {
                                    return $0.withUpdatedComposeInputState(textInputState)
                                }).updatedInputMode({ _ in
                                    return .text
                                })
                            })
                        } else {
                            self.playShakeAnimation()
                        }
                    case let .withBotStartPayload(botStart):
                        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedBotStartPayload(botStart.payload)
                        })
                    case .withAttachBot:
                        self.presentAttachmentMenu(subject: .default)
                    default:
                        break
                }
            } else {
                if let peer = peer {
                    do {
                        var chatPeerId: PeerId?
                        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramGroup {
                            chatPeerId = peer.id
                        } else if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .group = peer.info, case .member = peer.participationStatus {
                            chatPeerId = peer.id
                        }
                        
                        switch navigation {
                            case .info, .default:
                                let peerSignal: Signal<Peer?, NoError>
                                if let messageId = fromMessage?.id {
                                    peerSignal = loadedPeerFromMessage(account: self.context.account, peerId: peer.id, messageId: messageId)
                                } else {
                                    peerSignal = self.context.account.postbox.loadedPeerWithId(peer.id) |> map(Optional.init)
                                }
                                self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                                    if let strongSelf = self, let peer = peer {
                                        var mode: PeerInfoControllerMode = .generic
                                        if let _ = fromMessage, let chatPeerId = chatPeerId {
                                            mode = .group(chatPeerId)
                                        }
                                        if let fromReactionMessageId = fromReactionMessageId {
                                            mode = .reaction(fromReactionMessageId)
                                        }
                                        if case let .info(params) = navigation, let params {
                                            if params.switchToRecommendedChannels {
                                                mode = .recommendedChannels
                                            } else if params.switchToGroupsInCommon {
                                                mode = .groupsInCommon
                                            }
                                        }
                                        if peer.id == strongSelf.context.account.peerId {
                                            mode = .myProfile
                                        }
                                        var expandAvatar = expandAvatar
                                        if peer.smallProfileImage == nil {
                                            expandAvatar = false
                                        }
                                        if let validLayout = strongSelf.validLayout, validLayout.deviceMetrics.type == .tablet {
                                            expandAvatar = false
                                        }
                                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: false, requestsContext: nil) {
                                            strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                        }
                                    }
                                }))
                            case let .chat(textInputState, subject, peekData):
                                if let textInputState = textInputState {
                                    let _ = (ChatInterfaceState.update(engine: self.context.engine, peerId: peer.id, threadId: nil, { currentState in
                                        return currentState.withUpdatedComposeInputState(textInputState)
                                    })
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        if let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController {
                                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: subject, updateTextInputState: textInputState, peekData: peekData))
                                        }
                                    })
                                } else {
                                    if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                                        self.effectiveNavigationController?.pushViewController(ChatListControllerImpl(context: self.context, location: .forum(peerId: channel.id), controlsHistoryPreload: false, enableDebugActions: false))
                                    } else {
                                        self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(id: peer.id), subject: subject))
                                    }
                                }
                            case let .withBotStartPayload(botStart):
                                self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(id: peer.id), botStart: botStart))
                            case let .withAttachBot(attachBotStart):
                                if let navigationController = self.effectiveNavigationController {
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
                                }
                            case let .withBotApp(botAppStart):
                                if let navigationController = self.effectiveNavigationController {
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), botAppStart: botAppStart))
                                }
                        }
                    }
                } else {
                    switch navigation {
                        case .info:
                            break
                        case let .chat(textInputState, _, _):
                            if let textInputState = textInputState {
                                let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, updatedPresentationData: self.updatedPresentationData, requestPeerType: peerTypes.flatMap { $0.requestPeerTypes }, selectForumThreads: true))
                                controller.peerSelected = { [weak self, weak controller] peer, threadId in
                                    let peerId = peer.id
                                    
                                    if let strongSelf = self, let strongController = controller {
                                        if case let .peer(currentPeerId) = strongSelf.chatLocation, peerId == currentPeerId {
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                return ($0.updatedInterfaceState {
                                                    return $0.withUpdatedComposeInputState(textInputState)
                                                }).updatedInputMode({ _ in
                                                    return .text
                                                })
                                            })
                                            strongController.dismiss()
                                        } else {
                                            let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: threadId, { currentState in
                                                return currentState.withUpdatedComposeInputState(textInputState)
                                            })
                                            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                                                                                        
                                                if let navigationController = strongSelf.effectiveNavigationController {
                                                    let chatController: Signal<ChatController, NoError>
                                                    if let threadId {
                                                        chatController = chatControllerForForumThreadImpl(context: strongSelf.context, peerId: peerId, threadId: threadId)
                                                    } else {
                                                        chatController = .single(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peerId)))
                                                    }
                                                    
                                                    let _ = (chatController
                                                    |> deliverOnMainQueue).start(next: { [weak self, weak navigationController] chatController in
                                                        guard let strongSelf = self, let navigationController  else {
                                                            return
                                                        }
                                                        var viewControllers = navigationController.viewControllers
                                                        let lastController = viewControllers.last as! ViewController
                                                        if threadId != nil {
                                                            viewControllers.remove(at: viewControllers.count - 2)
                                                            lastController.navigationPresentation = .modal
                                                        }
                                                        viewControllers.insert(chatController, at: viewControllers.count - 1)
                                                        navigationController.setViewControllers(viewControllers, animated: false)
                                                        
                                                        strongSelf.controllerNavigationDisposable.set((chatController.ready.get()
                                                        |> filter { $0 }
                                                        |> take(1)
                                                        |> deliverOnMainQueue).startStrict(next: { [weak lastController] _ in
                                                            lastController?.dismiss()
                                                        }))
                                                    })
                                                }
                                            })
                                        }
                                    }
                                }
                                self.chatDisplayNode.dismissInput()
                                self.effectiveNavigationController?.pushViewController(controller)
                            }
                        default:
                            break
                    }
                }
            }
        })
    }
}
