import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramNotices
import ChatSendMessageActionUI
import AccountContext
import TopMessageReactions
import ReactionSelectionNode
import ChatControllerInteraction
import ChatSendAudioMessageContextPreview

extension ChatSendMessageEffect {
    convenience init(_ effect: ChatSendMessageActionSheetController.SendParameters.Effect) {
        self.init(id: effect.id)
    }
}

func chatMessageDisplaySendMessageOptions(selfController: ChatControllerImpl, node: ASDisplayNode, gesture: ContextGesture) {
    guard let peerId = selfController.chatLocation.peerId, let textInputView = selfController.chatDisplayNode.textInputView(), let layout = selfController.validLayout else {
        return
    }
    let previousSupportedOrientations = selfController.supportedOrientations
    if layout.size.width > layout.size.height {
        selfController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .landscape)
    } else {
        selfController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    let _ = ApplicationSpecificNotice.incrementChatMessageOptionsTip(accountManager: selfController.context.sharedContext.accountManager, count: 4).startStandalone()
    
    var hasEntityKeyboard = false
    if case .media = selfController.presentationInterfaceState.inputMode {
        hasEntityKeyboard = true
    }
    
    let effectItems: Signal<[ReactionItem]?, NoError>
    if peerId != selfController.context.account.peerId && peerId.namespace == Namespaces.Peer.CloudUser {
        effectItems = effectMessageReactions(context: selfController.context)
        |> map(Optional.init)
    } else {
        effectItems = .single(nil)
    }
    
    let availableMessageEffects = selfController.context.availableMessageEffects |> take(1)
    let hasPremium = selfController.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfController.context.account.peerId))
    |> map { peer -> Bool in
        guard case let .user(user) = peer else {
            return false
        }
        return user.isPremium
    }
    
    let _ = (combineLatest(
        selfController.context.account.viewTracker.peerView(peerId) |> take(1),
        effectItems,
        availableMessageEffects,
        hasPremium
    )
    |> deliverOnMainQueue).startStandalone(next: { [weak selfController] peerView, effectItems, availableMessageEffects, hasPremium in
        guard let selfController, let peer = peerViewMainPeer(peerView) else {
            return
        }
        var sendWhenOnlineAvailable = false
        if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case let .present(until) = presence.status {
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if currentTime > until {
                sendWhenOnlineAvailable = true
            }
        }
        if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
            sendWhenOnlineAvailable = false
        }
        
        if sendWhenOnlineAvailable {
            let _ = ApplicationSpecificNotice.incrementSendWhenOnlineTip(accountManager: selfController.context.sharedContext.accountManager, count: 4).startStandalone()
        }
        
        var mediaPreview: ChatSendMessageContextScreenMediaPreview?
        if let videoRecorderValue = selfController.videoRecorderValue {
            mediaPreview = videoRecorderValue.makeSendMessageContextPreview()
        }
        if let mediaDraftState = selfController.presentationInterfaceState.interfaceState.mediaDraftState {
            if case let .audio(audio) = mediaDraftState {
                mediaPreview = ChatSendAudioMessageContextPreview(
                    context: selfController.context,
                    presentationData: selfController.presentationData,
                    wallpaperBackgroundNode: selfController.chatDisplayNode.backgroundNode,
                    waveform: audio.waveform
                )
            }
        }
        
        let controller = makeChatSendMessageActionSheetController(
            context: selfController.context,
            updatedPresentationData: selfController.updatedPresentationData,
            peerId: selfController.presentationInterfaceState.chatLocation.peerId,
            forwardMessageIds: selfController.presentationInterfaceState.interfaceState.forwardMessageIds,
            hasEntityKeyboard: hasEntityKeyboard,
            gesture: gesture,
            sourceSendButton: node,
            textInputView: textInputView,
            mediaPreview: mediaPreview,
            emojiViewProvider: selfController.chatDisplayNode.textInputPanelNode?.emojiViewProvider,
            wallpaperBackgroundNode: selfController.chatDisplayNode.backgroundNode,
            canSendWhenOnline: sendWhenOnlineAvailable,
            completion: { [weak selfController] in
                guard let selfController else {
                    return
                }
                selfController.supportedOrientations = previousSupportedOrientations
            },
            sendMessage: { [weak selfController] mode, parameters in
                guard let selfController else {
                    return
                }
                switch mode {
                case .generic:
                    selfController.controllerInteraction?.sendCurrentMessage(false, parameters?.effect.flatMap(ChatSendMessageEffect.init))
                case .silently:
                    selfController.controllerInteraction?.sendCurrentMessage(true, parameters?.effect.flatMap(ChatSendMessageEffect.init))
                case .whenOnline:
                    selfController.chatDisplayNode.sendCurrentMessage(scheduleTime: scheduleWhenOnlineTimestamp, messageEffect: parameters?.effect.flatMap(ChatSendMessageEffect.init)) { [weak selfController] in
                        guard let selfController else {
                            return
                        }
                        selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, saveInterfaceState: selfController.presentationInterfaceState.subject != .scheduledMessages, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))) }
                        })
                        selfController.openScheduledMessages()
                    }
                }
            },
            schedule: { [weak selfController] effect in
                guard let selfController else {
                    return
                }
                selfController.controllerInteraction?.scheduleCurrentMessage()
            }, openPremiumPaywall: { [weak selfController] c in
                guard let selfController else {
                    return
                }
                selfController.push(c)
            },
            reactionItems: (!textInputView.text.isEmpty || mediaPreview != nil) ? effectItems : nil,
            availableMessageEffects: availableMessageEffects,
            isPremium: hasPremium
        )
        selfController.sendMessageActionsController = controller
        if layout.isNonExclusive {
            selfController.present(controller, in: .window(.root))
        } else {
            selfController.presentInGlobalOverlay(controller, with: nil)
        }
    })
}
