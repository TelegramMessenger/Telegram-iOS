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
    public func presentThemeSelection() {
        guard self.themeScreen == nil else {
            return
        }
        let context = self.context
        let peerId = self.chatLocation.peerId
        
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
            var updated = state
            updated = updated.updatedInputMode({ _ in
                return .none
            })
            updated = updated.updatedShowCommands(false)
            return updated
        })
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let _ = (combineLatest(queue: Queue.mainQueue(), self.chatThemeEmoticonPromise.get(), animatedEmojiStickers)
        |> take(1)).startStandalone(next: { [weak self] themeEmoticon, animatedEmojiStickers in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            
            var canResetWallpaper = false
            if let cachedUserData = strongSelf.contentData?.state.peerView?.cachedData as? CachedUserData {
                canResetWallpaper = cachedUserData.wallpaper != nil
            }
            
            let controller = ChatThemeScreen(
                context: context,
                updatedPresentationData: strongSelf.updatedPresentationData,
                animatedEmojiStickers: animatedEmojiStickers,
                initiallySelectedEmoticon: themeEmoticon,
                peerName: strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer.flatMap(EnginePeer.init)?.compactDisplayTitle ?? "",
                canResetWallpaper: canResetWallpaper,
                previewTheme: { [weak self] emoticon, dark in
                    if let strongSelf = self {
                        strongSelf.presentCrossfadeSnapshot()
                        strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((emoticon, dark)))
                    }
                },
                changeWallpaper: { [weak self] in
                    guard let strongSelf = self, let peerId else {
                        return
                    }
                    if let themeController = strongSelf.themeScreen {
                        strongSelf.themeScreen = nil
                        themeController.dimTapped()
                    }                    
                    let dismissControllers = { [weak self] in
                        if let self, let navigationController = self.navigationController as? NavigationController {
                            let controllers = navigationController.viewControllers.filter({ controller in
                                if controller is WallpaperGalleryController || controller is AttachmentController {
                                    return false
                                }
                                return true
                            })
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                    var openWallpaperPickerImpl: ((Bool) -> Void)?
                    let openWallpaperPicker = { [weak self] animateAppearance in
                        guard let strongSelf = self else {
                            return
                        }
                        let controller = wallpaperMediaPickerController(
                            context: strongSelf.context,
                            updatedPresentationData: strongSelf.updatedPresentationData,
                            peer: EnginePeer(peer),
                            animateAppearance: animateAppearance,
                            completion: { [weak self] _, result in
                                guard let strongSelf = self, let asset = result as? PHAsset else {
                                    return
                                }
                                let controller = WallpaperGalleryController(context: strongSelf.context, source: .asset(asset), mode: .peer(EnginePeer(peer), false))
                                controller.navigationPresentation = .modal
                                controller.apply = { [weak self] wallpaper, options, editedImage, cropRect, brightness, forBoth in
                                    if let strongSelf = self {
                                        uploadCustomPeerWallpaper(context: strongSelf.context, wallpaper: wallpaper, mode: options, editedImage: editedImage, cropRect: cropRect, brightness: brightness, peerId: peerId, forBoth: forBoth, completion: {
                                            Queue.mainQueue().after(0.3, {
                                                dismissControllers()
                                            })
                                        })
                                    }
                                }
                                strongSelf.push(controller)
                            },
                            openColors: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let controller = standaloneColorPickerController(context: strongSelf.context, peer: EnginePeer(peer), push: { [weak self] controller in
                                    if let strongSelf = self {
                                        strongSelf.push(controller)
                                    }
                                }, openGallery: {
                                    openWallpaperPickerImpl?(false)
                                })
                                controller.navigationPresentation = .flatModal
                                strongSelf.push(controller)
                            }
                        )
                        controller.navigationPresentation = .flatModal
                        strongSelf.push(controller)
                    }
                    openWallpaperPickerImpl = openWallpaperPicker
                    openWallpaperPicker(true)
                },
                resetWallpaper: { [weak self] in
                    guard let strongSelf = self, let peerId else {
                        return
                    }
                    let _ = strongSelf.context.engine.themes.setChatWallpaper(peerId: peerId, wallpaper: nil, forBoth: false).startStandalone()
                },
                completion: { [weak self] emoticon in
                    guard let strongSelf = self, let peerId else {
                        return
                    }
                    if canResetWallpaper && emoticon != nil {
                        let _ = context.engine.themes.setChatWallpaper(peerId: peerId, wallpaper: nil, forBoth: false).startStandalone()
                    }
                    strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((emoticon ?? "", nil)))
                    let _ = context.engine.themes.setChatTheme(peerId: peerId, emoticon: emoticon).startStandalone(completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((nil, nil)))
                        }
                    })
                }
            )
            controller.navigationPresentation = .flatModal
            controller.passthroughHitTestImpl = { [weak self] _ in
                if let strongSelf = self {
                    return strongSelf.chatDisplayNode.historyNode.view
                } else {
                    return nil
                }
            }
            controller.dismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.historyNode.tapped = nil
                }
            }
            strongSelf.chatDisplayNode.historyNode.tapped = { [weak controller] in
                controller?.dimTapped()
            }
            strongSelf.push(controller)
            strongSelf.themeScreen = controller
        })
    }
    
    func presentEmojiList(references: [StickerPackReference], previewIconFile: TelegramMediaFile? = nil) {
        guard let packReference = references.first else {
            return
        }
        self.chatDisplayNode.dismissTextInput()
        
        let presentationData = self.presentationData
        let controller = StickerPackScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, mainStickerPack: packReference, stickerPacks: Array(references), previewIconFile: previewIconFile, parentNavigationController: self.effectiveNavigationController, sendEmoji: canSendMessagesToChat(self.presentationInterfaceState) ? { [weak self] text, attribute in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.sendEmoji(text, attribute, false)
            }
        } : nil, actionPerformed: { [weak self] actions in
            guard let strongSelf = self else {
                return
            }
            let context = strongSelf.context
            if actions.count > 1, let first = actions.first {
                if case .add = first.2 {
                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.EmojiPackActionInfo_AddedTitle, text: presentationData.strings.EmojiPackActionInfo_MultipleAddedText(Int32(actions.count)), undo: false, info: first.0, topItem: first.1.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                        return true
                    }))
                } else if actions.allSatisfy({
                    if case .remove = $0.2 {
                        return true
                    } else {
                        return false
                    }
                }) {
                    let isEmoji = actions[0].0.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_MultipleRemovedText(Int32(actions.count)) : presentationData.strings.StickerPackActionInfo_MultipleRemovedText(Int32(actions.count)), undo: true, info: actions[0].0, topItem: actions[0].1.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                        if case .undo = action {
                            var itemsAndIndices: [(StickerPackCollectionInfo, [StickerPackItem], Int)] = actions.compactMap { action -> (StickerPackCollectionInfo, [StickerPackItem], Int)? in
                                if case let .remove(index) = action.2 {
                                    return (action.0, action.1, index)
                                } else {
                                    return nil
                                }
                            }
                            itemsAndIndices.sort(by: { $0.2 < $1.2 })
                            for (info, items, index) in itemsAndIndices.reversed() {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: index).startStandalone()
                            }
                        }
                        return true
                    }))
                }
            } else if let (info, items, action) = actions.first {
                let isEmoji = info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                switch action {
                case .add:
                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedTitle : presentationData.strings.StickerPackActionInfo_AddedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedText(info.title).string : presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                        return true
                    }))
                case let .remove(positionInList):
                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string : presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                        if case .undo = action {
                            let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).startStandalone()
                        }
                        return true
                    }))
                }
            }
        })
        self.present(controller, in: .window(.root))
    }
}
