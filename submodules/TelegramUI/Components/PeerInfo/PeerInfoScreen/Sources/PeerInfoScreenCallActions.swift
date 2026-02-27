import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import ContextUI
import CreateExternalMediaStreamScreen
import OverlayStatusController
import TelegramPresentationData
import PresentationDataUtils
import TelegramCallsUI
import AvatarNode

extension PeerInfoScreenNode {
    func requestCall(isVideo: Bool, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        let peerId = self.peerId
        let requestCall: (PeerId?, EngineGroupCallDescription?) -> Void = { [weak self] defaultJoinAsPeerId, activeCall in
            if let activeCall = activeCall {
                self?.context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { completion in
                    if let defaultJoinAsPeerId = defaultJoinAsPeerId {
                        result?(.dismissWithoutContent)
                        completion(defaultJoinAsPeerId)
                    } else {
                        self?.openVoiceChatDisplayAsPeerSelection(completion: { joinAsPeerId in
                            completion(joinAsPeerId)
                        }, gesture: gesture, contextController: contextController, result: result, backAction: backAction)
                    }
                }, activeCall: activeCall)
            } else {
                self?.openVoiceChatOptions(defaultJoinAsPeerId: defaultJoinAsPeerId, gesture: gesture, contextController: contextController)
            }
        }
        
        if let cachedChannelData = self.data?.cachedData as? CachedChannelData {
            requestCall(cachedChannelData.callJoinPeerId, cachedChannelData.activeCall.flatMap(EngineGroupCallDescription.init))
            return
        } else if let cachedGroupData = self.data?.cachedData as? CachedGroupData {
            requestCall(cachedGroupData.callJoinPeerId, cachedGroupData.activeCall.flatMap(EngineGroupCallDescription.init))
            return
        }
        
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.controller?.push(self.context.sharedContext.makeSendInviteLinkScreen(context: self.context, subject: .groupCall(.create), peers: [TelegramForbiddenInvitePeer(
                peer: EnginePeer(peer),
                canInviteWithPremium: false,
                premiumRequiredToContact: false
            )], theme: self.presentationData.theme))
            return
        }
        
        self.context.requestCall(peerId: peer.id, isVideo: isVideo, completion: {})
    }
    
    func scheduleGroupCall() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        self.context.scheduleGroupCall(peerId: self.peerId, parentController: controller)
    }
    
    func createExternalStream(credentialsPromise: Promise<GroupCallStreamCredentials>?) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        self.controller?.push(CreateExternalMediaStreamScreen(context: self.context, peerId: self.peerId, credentialsPromise: credentialsPromise, mode: .create(liveStream: false)))
    }
    
    func createAndJoinGroupCall(peerId: PeerId, joinAsPeerId: PeerId?) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        if let _ = self.context.sharedContext.callManager {
            let startCall: (Bool) -> Void = { [weak self] endCurrentIfAny in
                guard let strongSelf = self else {
                    return
                }
                
                var cancelImpl: (() -> Void)?
                let presentationData = strongSelf.presentationData
                let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    self?.controller?.present(controller, in: .window(.root))
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                let createSignal = strongSelf.context.engine.calls.createGroupCall(peerId: peerId, title: nil, scheduleDate: nil, isExternalStream: false)
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = { [weak self] in
                    self?.activeActionDisposable.set(nil)
                }
                strongSelf.activeActionDisposable.set((createSignal
                |> deliverOnMainQueue).start(next: { [weak self] info in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { result in
                        result(joinAsPeerId)
                    }, activeCall: EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: info.isStream))
                }, error: { [weak self] error in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                    
                    let text: String
                    switch error {
                    case .generic, .scheduledTooLate:
                        text = strongSelf.presentationData.strings.Login_UnknownError
                    case .anonymousNotAllowed:
                        if let channel = strongSelf.data?.peer as? TelegramChannel, case .broadcast = channel.info {
                            text = strongSelf.presentationData.strings.LiveStream_AnonymousDisabledAlertText
                        } else {
                            text = strongSelf.presentationData.strings.VoiceChat_AnonymousDisabledAlertText
                        }
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }))
            }
            
            startCall(true)
        }
    }

    func openVoiceChatDisplayAsPeerSelection(completion: @escaping (PeerId) -> Void, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
        let dismissOnSelection = contextController == nil
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(context.account.peerId)
        |> map { peer in
            return [FoundPeer(peer: peer, subscribers: nil)]
        }
        let _ = (combineLatest(queue: Queue.mainQueue(), currentAccountPeer, self.displayAsPeersPromise.get() |> take(1))
        |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
            var result = currentAccountPeer
            result.append(contentsOf: availablePeers)
            return result
        }).startStandalone(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            if peers.count == 1, let peer = peers.first {
                result?(.dismissWithoutContent)
                completion(peer.peer.id)
            } else {
                var items: [ContextMenuItem] = []
                
                var isGroup = false
                for peer in peers {
                    if peer.peer is TelegramGroup {
                        isGroup = true
                        break
                    } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                        isGroup = true
                        break
                    }
                }
                
                items.append(.custom(VoiceChatInfoContextItem(text: isGroup ? strongSelf.presentationData.strings.VoiceChat_DisplayAsInfoGroup : strongSelf.presentationData.strings.VoiceChat_DisplayAsInfo, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Accounts"), color: theme.actionSheet.primaryTextColor)
                }), true))
                
                for peer in peers {
                    var subtitle: String?
                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        subtitle = strongSelf.presentationData.strings.VoiceChat_PersonalAccount
                    } else if let subscribers = peer.subscribers {
                        if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                        } else {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                        }
                    }

                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    let avatarSignal = peerAvatarCompleteImage(account: strongSelf.context.account, peer: EnginePeer(peer.peer), size: avatarSize)
                    items.append(.action(ContextMenuActionItem(text: EnginePeer(peer.peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), action: { _, f in
                        if dismissOnSelection {
                            f(.dismissWithoutContent)
                        }
                        completion(peer.peer.id)
                    })))
                    
                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        items.append(.separator)
                    }
                }
                if backAction != nil {
                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                    }, iconPosition: .left, action: { (c, _) in
                        if let c, let backAction = backAction {
                            backAction(c)
                        }
                    })))
                }
                
                if let contextController = contextController {
                    contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
                } else {
                    strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    
                    if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                        let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
            }
        })
    }

    func openVoiceChatOptions(defaultJoinAsPeerId: PeerId?, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil) {
        guard let chatPeer = self.data?.peer else {
            return
        }
        let context = self.context
        let peerId = self.peerId
        let defaultJoinAsPeerId = defaultJoinAsPeerId ?? self.context.account.peerId
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> map { peer in
            return [FoundPeer(peer: peer, subscribers: nil)]
        }
        let _ = (combineLatest(queue: Queue.mainQueue(), currentAccountPeer, self.displayAsPeersPromise.get() |> take(1))
        |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
            var result = currentAccountPeer
            result.append(contentsOf: availablePeers)
            return result
        }).startStandalone(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            if peers.count > 1 {
                var selectedPeer: FoundPeer?
                for peer in peers {
                    if peer.peer.id == defaultJoinAsPeerId {
                        selectedPeer = peer
                    }
                }
                if let peer = selectedPeer {
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_DisplayAs, textLayout: .secondLineWithValue(EnginePeer(peer.peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: EnginePeer(peer.peer), size: avatarSize)), action: { c, f in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.openVoiceChatDisplayAsPeerSelection(completion: { joinAsPeerId in
                            let _ = context.engine.calls.updateGroupCallJoinAsPeer(peerId: peerId, joinAs: joinAsPeerId).startStandalone()
                            self?.openVoiceChatOptions(defaultJoinAsPeerId: joinAsPeerId, gesture: nil, contextController: c)
                        }, gesture: gesture, contextController: c, result: f, backAction: { [weak self] c in
                            self?.openVoiceChatOptions(defaultJoinAsPeerId: defaultJoinAsPeerId, gesture: nil, contextController: c)
                        })
                        
                    })))
                    items.append(.separator)
                }
            }

            let createVoiceChatTitle: String
            let scheduleVoiceChatTitle: String
            if let channel = strongSelf.data?.peer as? TelegramChannel, case .broadcast = channel.info {
                createVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_CreateLiveStream
                scheduleVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_ScheduleLiveStream
            } else {
                createVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_CreateVoiceChat
                scheduleVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_ScheduleVoiceChat
            }
            
            items.append(.action(ContextMenuActionItem(text: createVoiceChatTitle, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VoiceChat"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                f(.dismissWithoutContent)
                
                self?.createAndJoinGroupCall(peerId: peerId, joinAsPeerId: defaultJoinAsPeerId)
            })))
            
            items.append(.action(ContextMenuActionItem(text: scheduleVoiceChatTitle, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Schedule"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                f(.dismissWithoutContent)
                
                self?.scheduleGroupCall()
            })))
            
            var credentialsPromise: Promise<GroupCallStreamCredentials>?
            var canCreateStream = false
            switch chatPeer {
            case let group as TelegramGroup:
                if case .creator = group.role {
                    canCreateStream = true
                }
            case let channel as TelegramChannel:
                if channel.hasPermission(.manageCalls) {
                    canCreateStream = true
                    credentialsPromise = Promise()
                    credentialsPromise?.set(context.engine.calls.getGroupCallStreamCredentials(peerId: peerId, isLiveStream: false, revokePreviousCredentials: false) |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in return .never() })
                }
            default:
                break
            }
            
            if canCreateStream {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChannelInfo_CreateExternalStream, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VoiceChat"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    self?.createExternalStream(credentialsPromise: credentialsPromise)
                })))
            }
            
            if let contextController = contextController {
                contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
            } else {
                strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                
                if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                    let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
        })
    }
}
