import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import UndoUI
import ContextUI
import TelegramPresentationData
import NotificationPeerExceptionController
import NotificationExceptionsScreen
import ShareController
import TranslateUI

extension PeerInfoScreenNode {
    func performButtonAction(key: PeerInfoHeaderButtonKey, buttonNode: PeerInfoHeaderButtonNode?, gesture: ContextGesture?) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController, let peer = self.data?.peer {
                if let channel = peer as? TelegramChannel, case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }
                        
                        guard let peer = await self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)).get() else {
                            return
                        }
                        
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default))
                    }
                } else {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                        if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                            var viewControllers = navigationController.viewControllers
                            viewControllers = viewControllers.filter { controller in
                                if controller is PeerInfoScreen {
                                    return false
                                }
                                return true
                            }
                            navigationController.setViewControllers(viewControllers, animated: false)
                        }
                    }))
                }
            }
        case .discussion:
            if let cachedData = self.data?.cachedData as? CachedChannelData, case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId {
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: linkedDiscussionPeerId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] linkedDiscussionPeer in
                    guard let self, let linkedDiscussionPeer else {
                        return
                    }
                    if let navigationController = controller.navigationController as? NavigationController {
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(linkedDiscussionPeer)))
                    }
                })
            }
        case .call:
            self.requestCall(isVideo: false)
        case .videoCall:
            self.requestCall(isVideo: true)
        case .voiceChat:
            self.requestCall(isVideo: false, gesture: gesture)
        case .mute:
            var displayCustomNotificationSettings = false
                        
            let chatIsMuted = peerInfoIsChatMuted(peer: self.data?.peer, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings)
            if chatIsMuted {
            } else {
                displayCustomNotificationSettings = true
            }
            if self.data?.threadData == nil, let channel = self.data?.peer as? TelegramChannel, channel.isForumOrMonoForum {
                displayCustomNotificationSettings = true
            }
            
            let peerId = self.data?.peer?.id ?? self.peerId
            
            if !displayCustomNotificationSettings {
                let _ = self.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self.chatLocation.threadId, muteInterval: 0).startStandalone()
                
                let iconColor: UIColor = .white
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                        "Middle.Group 1.Fill 1": iconColor,
                        "Top.Group 1.Fill 1": iconColor,
                        "Bottom.Group 1.Fill 1": iconColor,
                        "EXAMPLE.Group 1.Fill 1": iconColor,
                        "Line.Group 1.Stroke 1": iconColor
                ], title: nil, text: self.presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            } else {
                self.state = self.state.withHighlightedButton(.mute)
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_MuteFor, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mute2d"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    guard let strongSelf = self else {
                        return
                    }
                    var subItems: [ContextMenuItem] = []
                    
                    subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { c, _ in
                        c?.popItems()
                    })))
                    subItems.append(.separator)
                    
                    let presetValues: [Int32] = [
                        1 * 60 * 60,
                        8 * 60 * 60,
                        1 * 24 * 60 * 60,
                        7 * 24 * 60 * 60
                    ]
                    
                    for value in presetValues {
                        subItems.append(.action(ContextMenuActionItem(text: muteForIntervalString(strings: strongSelf.presentationData.strings, value: value), icon: { _ in
                            return nil
                        }, action: { _, f in
                            f(.default)
                            
                            let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: strongSelf.chatLocation.threadId, muteInterval: value).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_mute_for", scale: 0.066, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedFor(mutedForTimeIntervalString(strings: strongSelf.presentationData.strings, value: value)).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                    
                    subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_MuteForCustom, icon: { _ in
                        return nil
                    }, action: { _, f in
                        f(.default)
                        
                        self?.openCustomMute()
                    })))
                    
                    c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                })))
                
                items.append(.separator)
                
                var isSoundEnabled = true
                let notificationSettings = self.data?.threadNotificationSettings ?? self.data?.peerNotificationSettings
                if let notificationSettings {
                    switch notificationSettings.messageSound {
                    case .none:
                        isSoundEnabled = false
                    default:
                        break
                    }
                }
                
                if !chatIsMuted {
                    if !isSoundEnabled {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_EnableSound, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: strongSelf.chatLocation.threadId, sound: .default).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_on", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundEnabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_DisableSound, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOff"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: strongSelf.chatLocation.threadId, sound: .none).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_off", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundDisabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                }
                
                let context = self.context
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_NotificationsCustomize, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    let _ = (context.engine.data.get(
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> deliverOnMainQueue).startStandalone(next: { globalSettings in
                        guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                            return
                        }
                        let threadId = strongSelf.chatLocation.threadId
                        
                        let context = strongSelf.context
                        let updatePeerSound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let updatePeerNotificationInterval: (PeerId, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
                            return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: muteInterval) |> deliverOnMainQueue
                        }
                        
                        let updatePeerDisplayPreviews: (PeerId, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
                            peerId, displayPreviews in
                            return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: threadId, displayPreviews: displayPreviews) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesMuted: (PeerId, PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> = {
                            peerId, mute in
                            return context.engine.peers.updatePeerStoriesMutedSetting(peerId: peerId, mute: mute) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesHideSender: (PeerId, PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> = {
                            peerId, hideSender in
                            return context.engine.peers.updatePeerStoriesHideSenderSetting(peerId: peerId, hideSender: hideSender) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStorySound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerStorySoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let mode: NotificationExceptionMode
                        let defaultSound: PeerMessageSound
                        if let _ = peer as? TelegramUser {
                            mode = .users([:])
                            defaultSound = globalSettings.privateChats.sound._asMessageSound()
                        } else if let _ = peer as? TelegramSecretChat {
                            mode = .users([:])
                            defaultSound = globalSettings.privateChats.sound._asMessageSound()
                        } else if let channel = peer as? TelegramChannel {
                            if case .broadcast = channel.info {
                                mode = .channels([:])
                                defaultSound = globalSettings.channels.sound._asMessageSound()
                            } else {
                                mode = .groups([:])
                                defaultSound = globalSettings.groupChats.sound._asMessageSound()
                            }
                        } else {
                            mode = .groups([:])
                            defaultSound = globalSettings.groupChats.sound._asMessageSound()
                        }
                        let _ = mode
                        
                        let canRemove = false
                        
                        let exceptionController = notificationPeerExceptionController(context: context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, peer: EnginePeer(peer), threadId: threadId, isStories: nil, canRemove: canRemove, defaultSound: defaultSound, defaultStoriesSound: globalSettings.privateChats.storySettings.sound, edit: true, updatePeerSound: { peerId, sound in
                            let _ = (updatePeerSound(peer.id, sound)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                            })
                        }, updatePeerNotificationInterval: { peerId, muteInterval in
                            let _ = (updatePeerNotificationInterval(peerId, muteInterval)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let muteInterval = muteInterval, muteInterval == Int32.max {
                                    let iconColor: UIColor = .white
                                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                        "Middle.Group 1.Fill 1": iconColor,
                                        "Top.Group 1.Fill 1": iconColor,
                                        "Bottom.Group 1.Fill 1": iconColor,
                                        "EXAMPLE.Group 1.Fill 1": iconColor,
                                        "Line.Group 1.Stroke 1": iconColor
                                    ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                }
                            })
                        }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                            let _ = (updatePeerDisplayPreviews(peerId, displayPreviews)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                
                            })
                        }, updatePeerStoriesMuted: { peerId, mute in
                            let _ = (updatePeerStoriesMuted(peerId, mute)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStoriesHideSender: { peerId, hideSender in
                            let _ = (updatePeerStoriesHideSender(peerId, hideSender)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStorySound: { peerId, sound in
                            let _ = (updatePeerStorySound(peer.id, sound)
                            |> deliverOnMainQueue).startStandalone()
                        }, removePeerFromExceptions: {
                        }, modifiedPeer: {
                        })
                        exceptionController.navigationPresentation = .modal
                        controller.push(exceptionController)
                    })
                })))
                
                if chatIsMuted {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_ButtonUnmute, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unmute"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        
                        let _ = self.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self.chatLocation.threadId, muteInterval: 0).startStandalone()
                        
                        let iconColor: UIColor = .white
                        self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                                "Middle.Group 1.Fill 1": iconColor,
                                "Top.Group 1.Fill 1": iconColor,
                                "Bottom.Group 1.Fill 1": iconColor,
                                "EXAMPLE.Group 1.Fill 1": iconColor,
                                "Line.Group 1.Stroke 1": iconColor
                        ], title: nil, text: self.presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_MuteForever, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: strongSelf.chatLocation.threadId, muteInterval: Int32.max).startStandalone()
                        
                        let iconColor: UIColor = .white
                        strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                            "Middle.Group 1.Fill 1": iconColor,
                            "Top.Group 1.Fill 1": iconColor,
                            "Bottom.Group 1.Fill 1": iconColor,
                            "EXAMPLE.Group 1.Fill 1": iconColor,
                            "Line.Group 1.Stroke 1": iconColor
                        ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                }
                
                var tip: ContextController.Tip?
                tip = nil
                if !self.forumTopicNotificationExceptions.isEmpty {
                    items.append(.separator)
                    
                    let text: String = self.presentationData.strings.PeerInfo_TopicNotificationExceptions(Int32(self.forumTopicNotificationExceptions.count))
                    
                    items.append(.action(ContextMenuActionItem(
                        text: text,
                        textLayout: .multiline,
                        textFont: .small,
                        parseMarkdown: true,
                        badge: nil,
                        icon: { _ in
                            return nil
                        },
                        action: { [weak self] _, f in
                            guard let self else {
                                return
                            }
                            f(.default)
                            self.controller?.push(threadNotificationExceptionsScreen(context: self.context, peerId: self.peerId, notificationExceptions: self.forumTopicNotificationExceptions, updated: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                self.forumTopicNotificationExceptions = value
                            }))
                        }
                    )))
                }
                
                self.view.endEditing(true)
                
                if let sourceNode = self.headerNode.buttonNodes[.mute]?.referenceNode {
                    let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items), tip: tip)), gesture: gesture)
                    contextController.dismissed = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                            if let (layout, navigationHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        }
                    }
                    controller.presentInGlobalOverlay(contextController)
                }
            }
        case .more:
            guard let data = self.data, let peer = data.peer, let chatPeer = data.chatPeer else {
                return
            }
            let presentationData = self.presentationData
            self.state = self.state.withHighlightedButton(.more)
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
            
            var mainItemsImpl: (() -> Signal<[ContextMenuItem], NoError>)?
            mainItemsImpl = { [weak self] in
                var items: [ContextMenuItem] = []
                guard let strongSelf = self else {
                    return .single(items)
                }
                
                let allHeaderButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: false, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false, threadInfo: data.threadData?.info))
                let headerButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: true, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false, threadInfo: strongSelf.data?.threadData?.info))
                
                let filteredButtons = allHeaderButtons.subtracting(headerButtons)
                
                var currentAutoremoveTimeout: Int32?
                if let cachedData = data.cachedData as? CachedUserData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                } else if let cachedData = data.cachedData as? CachedGroupData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                } else if let cachedData = data.cachedData as? CachedChannelData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                }
                
                var canSetupAutoremoveTimeout = false
                
                if let secretChat = chatPeer as? TelegramSecretChat {
                    currentAutoremoveTimeout = secretChat.messageAutoremoveTimeout
                    canSetupAutoremoveTimeout = false
                } else if let group = chatPeer as? TelegramGroup {
                    if !group.hasBannedPermission(.banChangeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let user = chatPeer as? TelegramUser {
                    if user.id != strongSelf.context.account.peerId {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let channel = chatPeer as? TelegramChannel {
                    if channel.hasPermission(.changeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                }
                
                if filteredButtons.contains(.call) {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_ButtonCall, icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.requestCall(isVideo: false)
                    })))
                }
                if filteredButtons.contains(.search) {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChatSearch_SearchPlaceholder, icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.openChatWithMessageSearch()
                    })))
                }
                
                var hasDiscussion = false
                if let channel = chatPeer as? TelegramChannel {
                    switch channel.info {
                    case let .broadcast(info):
                        hasDiscussion = info.flags.contains(.hasDiscussionGroup)
                    case .group:
                        hasDiscussion = false
                    }
                }
                if !headerButtons.contains(.discussion) && hasDiscussion {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_ViewDiscussion, icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.performButtonAction(key: .discussion, buttonNode: nil, gesture: nil)
                    })))
                }
                
                if let user = peer as? TelegramUser {
                    if user.botInfo == nil && strongSelf.data?.encryptionKeyFingerprint == nil && !user.isDeleted {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ChangeWallpaper, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openChatForThemeChange()
                        })))
                    }
                                        
                    if let _ = user.botInfo {
                        if user.addressName != nil {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ShareBot, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                self?.openShareBot()
                            })))
                        }
                        
                        var addedPrivacy = false
                        var privacyPolicyUrl: String?
                        if let cachedData = (data.cachedData as? CachedUserData), let botInfo = cachedData.botInfo {
                            if let url = botInfo.privacyPolicyUrl {
                                privacyPolicyUrl = url
                            } else if botInfo.commands.contains(where: { $0.text == "privacy" }) {
                                
                            } else {
                                privacyPolicyUrl = presentationData.strings.WebApp_PrivacyPolicy_URL
                            }
                        }
                        if let privacyPolicyUrl {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotPrivacy, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: privacyPolicyUrl, forceExternal: false, presentationData: self.presentationData, navigationController: self.controller?.navigationController as? NavigationController, dismissInput: {})
                            })))
                            addedPrivacy = true
                        }
                        if let cachedData = data.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                            for command in botInfo.commands {
                                if command.text == "settings" {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotSettings, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .settings)
                                    })))
                                } else if command.text == "help" {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotHelp, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Help"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .help)
                                    })))
                                } else if command.text == "privacy" && !addedPrivacy {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotPrivacy, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .privacy)
                                    })))
                                }
                            }
                        }
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if let cachedUserData = strongSelf.data?.cachedData as? CachedUserData, let _ = cachedUserData.sendPaidMessageStars {
                            
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_StartSecretChat, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Lock"), color: theme.contextMenu.primaryColor)
                            }, action: { _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStartSecretChat()
                            })))
                        }
                    }
                    
                    if user.botInfo == nil && data.isContact, let peer = strongSelf.data?.peer as? TelegramUser, let phone = peer.phone {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_ShareContactButton, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                                let shareController = ShareController(context: strongSelf.context, subject: .media(.standalone(media: contact), nil), updatedPresentationData: strongSelf.controller?.updatedPresentationData)
                                shareController.completed = { [weak self] peerIds in
                                    if let strongSelf = self {
                                        let _ = (strongSelf.context.engine.data.get(
                                            EngineDataList(
                                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                            )
                                        )
                                        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            let peers = peerList.compactMap { $0 }
                                            
                                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            let text: String
                                            var savedMessages = false
                                            if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                                text = presentationData.strings.UserInfo_ContactForwardTooltip_SavedMessages_One
                                                savedMessages = true
                                            } else {
                                                if peers.count == 1, let peer = peers.first {
                                                    let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_Chat_One(peerName).string
                                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                                    let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                                } else if let peer = peers.first {
                                                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                                } else {
                                                    text = ""
                                                }
                                            }
                                            
                                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                                                if savedMessages, let self, action == .info {
                                                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                                                        guard let self, let peer else {
                                                            return
                                                        }
                                                        guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                                            return
                                                        }
                                                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                                    })
                                                }
                                                return false
                                            }), in: .current)
                                        })
                                    }
                                }
                                strongSelf.controller?.present(shareController, in: .window(.root))
                            }
                        })))
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser, !user.isDeleted && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if let cachedData = data.cachedData as? CachedUserData, cachedData.disallowedGifts == .All {
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_SendGift, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Gift"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let self {
                                    self.openPremiumGift()
                                }
                            })))
                        }
                    }
                    
                    if let cachedData = data.cachedData as? CachedUserData, canTranslateChats(context: strongSelf.context), cachedData.flags.contains(.translationHidden) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                    return current?.withIsEnabled(true)
                                }).startStandalone()
                                
                                Queue.mainQueue().after(0.2, {
                                    let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        self?.openChatForTranslation()
                                    })
                                })
                            }
                        })))
                    }
                    
                    let itemsCount = items.count
                                        
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.legacy(.autoremoveMessages)), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: user, chatPeer: chatPeer, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: user, chatPeer: user)
                            }
                        })))
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if data.isContact {
                            if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                            } else {
                                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_BlockUser, textColor: .destructive, icon: { theme in
                                    generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.destructiveColor)
                                }, action: { _, f in
                                    f(.dismissWithoutContent)
                                    
                                    self?.updateBlocked(block: true)
                                })))
                            }
                        }
                    } else if strongSelf.peerId.namespace == Namespaces.Peer.SecretChat && data.isContact {
                        if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_BlockUser, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.updateBlocked(block: true)
                            })))
                        }
                    }
                    
                    let finalItemsCount = items.count
                    
                    if finalItemsCount > itemsCount {
                        items.insert(.separator, at: itemsCount)
                    }
                } else if let channel = peer as? TelegramChannel {
                    if let cachedData = strongSelf.data?.cachedData as? CachedChannelData {
                        if case .broadcast = channel.info, cachedData.flags.contains(.starGiftsAvailable) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_SendGift, badge: nil, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Gift"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openPremiumGift()
                            })))
                        }
                        
                        let boostTitle: String
                        switch channel.info {
                        case .group:
                            boostTitle = presentationData.strings.PeerInfo_Group_Boost
                        case .broadcast:
                            boostTitle = presentationData.strings.PeerInfo_Channel_Boost
                        }
                        items.append(.action(ContextMenuActionItem(text: boostTitle, badge: nil, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Boost"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openBoost()
                        })))
                                                
                        if channel.hasPermission(.editStories) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_Channel_ArchivedStories, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStoryArchive()
                            })))
                        }
                        if cachedData.flags.contains(.canViewStats) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChannelInfo_Stats, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStats(section: .stats)
                            })))
                        }
                        if cachedData.flags.contains(.translationHidden) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let strongSelf = self {
                                    let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                        return current?.withIsEnabled(true)
                                    }).startStandalone()
                                    
                                    Queue.mainQueue().after(0.2, {
                                        let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                        |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                            self?.openChatForTranslation()
                                        })
                                    })
                                }
                            })))
                        }
                    }
                    
                    var canReport = true
                    if channel.adminRights != nil {
                        canReport = false
                    }
                    if channel.flags.contains(.isCreator) {
                        canReport = false
                    }
                    if canReport {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.ReportPeer_Report, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, f in
                            self?.openReport(type: .default, contextController: c, backAction: { c in
                                if let mainItemsImpl = mainItemsImpl {
                                    c.setItems(mainItemsImpl() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil, animated: true)
                                }
                            })
                        })))
                    }
                    
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            let baseText: String
                            if case .broadcast = channel.info {
                                baseText = strongSelf.presentationData.strings.PeerInfo_ChannelAutoDeleteInfo
                            } else {
                                baseText = strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: baseText + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.legacy(.autoremoveMessages)), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: channel, chatPeer: channel, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: channel, chatPeer: channel)
                            }
                        })))
                    }
                    
                    switch channel.info {
                    case .broadcast:
                        if case .member = channel.participationStatus, !headerButtons.contains(.leave) {
                            if !items.isEmpty {
                                items.append(.separator)
                            }
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Channel_LeaveChannel, textColor: .destructive, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: false)
                            })))
                        }
                    case .group:
                        if case .member = channel.participationStatus, !headerButtons.contains(.leave) {
                            if !items.isEmpty {
                                items.append(.separator)
                            }
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_LeaveGroup, textColor: .primary, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: false)
                            })))
                            if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canDeleteHistory) {
                                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_DeleteGroup, textColor: .destructive, icon: { theme in
                                    generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
                                }, action: { [weak self] _, f in
                                    f(.dismissWithoutContent)
                                    
                                    self?.openLeavePeer(delete: true)
                                })))
                            }
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.legacy(.autoremoveMessages)), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }

                    if let cachedData = data.cachedData as? CachedGroupData, cachedData.flags.contains(.translationHidden) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                    return current?.withIsEnabled(true)
                                }).startStandalone()
                                
                                Queue.mainQueue().after(0.2, {
                                    let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        self?.openChatForTranslation()
                                    })
                                })
                            }
                        })))
                    }
                    
                    var canReport = true
                    if case .creator = group.role {
                        canReport = false
                    }
                    if canReport {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.ReportPeer_Report, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, f in
                            self?.openReport(type: .default, contextController: c, backAction: { c in
                                if let mainItemsImpl = mainItemsImpl {
                                    c.setItems(mainItemsImpl() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil, animated: true)
                                }
                            })
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: group, chatPeer: group, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: group, chatPeer: group)
                            }
                        })))
                    }
                    
                    if case .Member = group.membership, !headerButtons.contains(.leave) {
                        if !items.isEmpty {
                            items.append(.separator)
                        }
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_LeaveGroup, textColor: .destructive, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openLeavePeer(delete: false)
                        })))
                        
                        if case .creator = group.role {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_DeleteGroup, textColor: .destructive, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: true)
                            })))
                        }
                    }
                }
                
                return .single(items)
            }
            
            self.view.endEditing(true)
            
            if let sourceNode = self.headerNode.buttonNodes[.more]?.referenceNode {
                let items = mainItemsImpl?() ?? .single([])
                
                let sourceView = sourceNode.view
                
                let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                contextController.dismissed = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                        if let (layout, navigationHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                        }
                    }
                }
                controller.presentInGlobalOverlay(contextController)
            }
        case .addMember:
            self.openAddMember()
        case .search:
            self.openChatWithMessageSearch()
        case .leave:
            self.openLeavePeer(delete: false)
        case .stop:
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_banned", scale: 0.066, colors: [:], title: self.presentationData.strings.PeerInfo_BotBlockedTitle, text: self.presentationData.strings.PeerInfo_BotBlockedText, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            self.updateBlocked(block: true)
        case .addContact:
            self.openAddContact()
        }
    }
}
