import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import UniversalMediaPlayer
import AccountContext
import OverlayStatusController
import PresentationDataUtils
import TelegramCallsUI
import UndoUI

private func presentLiveLocationController(context: AccountContext, peerId: PeerId, controller: ViewController) {
    let presentImpl: (EngineMessage?) -> Void = { [weak controller] message in
        if let message = message, let strongController = controller {
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                controller?.view.endEditing(true)
            }, present: { c, a, _ in
                controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { _, _, _ in
                return nil
            }, addToTransitionSurface: { _ in
            }, openUrl: { _ in
            }, openPeer: { peer, navigation in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in
            }, enqueueMessage: { message in
                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in
            }, chatAvatarHiddenMedia: { _, _ in
            }))
        }
    }
    if let id = context.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
        |> deliverOnMainQueue).start(next: presentImpl)
    } else if let liveLocationManager = context.liveLocationManager {
        let _ = (liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
        |> take(1)
        |> map { peersAndMessages -> EngineMessage? in
            return peersAndMessages?.first?.1
        } |> deliverOnMainQueue).start(next: presentImpl)
    }
}

open class TelegramBaseController: ViewController, KeyShortcutResponder {
    private let context: AccountContext
    
    public var accessoryPanelContainer: ASDisplayNode?
    public private(set) var accessoryPanelContainerHeight: CGFloat = 0.0
    
    public var tempHideAccessoryPanels: Bool = false
    
    private var giftAuctionAccessoryPanel: GiftAuctionAccessoryPanel?
    private var giftAuctionStates: [GiftAuctionContext.State] = []
    private var giftAuctionDisposable: Disposable?
    
    private var dismissingPanel: ASDisplayNode?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    override open var additionalNavigationBarHeight: CGFloat {
        return 0.0
    }
    
    public init(context: AccountContext, navigationBarPresentationData: NavigationBarPresentationData?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.presentationDataDisposable = (self.updatedPresentationData.1
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        })
    }
    
    open var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.context.sharedContext.presentationData)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0
    private var additionalNavigationBarCutout: CGSize?

    override open func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        var additionalHeight: CGFloat = 0.0
        var panelStartY: CGFloat = 0.0
        
        if !self.giftAuctionStates.isEmpty {
            let panelHeight: CGFloat = 56.0
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: panelStartY), size: CGSize(width: layout.size.width, height: panelHeight))
            additionalHeight += panelHeight
            panelStartY += panelHeight
            
            let giftAuctionAccessoryPanel: GiftAuctionAccessoryPanel
            if let current = self.giftAuctionAccessoryPanel {
                giftAuctionAccessoryPanel = current
                transition.updateFrame(node: giftAuctionAccessoryPanel, frame: panelFrame)
                giftAuctionAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, isHidden: !self.displayNavigationBar, transition: transition)
            } else {
                giftAuctionAccessoryPanel = GiftAuctionAccessoryPanel(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, tapAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.giftAuctionStates.count == 1, let gift = self.giftAuctionStates.first?.gift, case let .generic(gift) = gift {
                        if let giftAuctionsManager = self.context.giftAuctionsManager {
                            let _ = (giftAuctionsManager.auctionContext(for: .giftId(gift.id))
                            |> deliverOnMainQueue).start(next: { [weak self] auction in
                                guard let self, let auction else {
                                    return
                                }
                                let controller = self.context.sharedContext.makeGiftAuctionBidScreen(context: self.context, toPeerId: auction.currentBidPeerId ?? self.context.account.peerId, text: nil, entities: nil, hideName: false, auctionContext: auction, acquiredGifts: nil)
                                self.push(controller)
                            })
                        }
                    } else {
                        let controller = self.context.sharedContext.makeGiftAuctionActiveBidsScreen(context: self.context)
                        self.push(controller)
                    }
                })
                if let accessoryPanelContainer = self.accessoryPanelContainer {
                    accessoryPanelContainer.addSubnode(giftAuctionAccessoryPanel)
                } else {
                    self.navigationBar?.additionalContentNode.addSubnode(giftAuctionAccessoryPanel)
                }
                self.giftAuctionAccessoryPanel = giftAuctionAccessoryPanel
                giftAuctionAccessoryPanel.frame = panelFrame

                giftAuctionAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, isHidden: !self.displayNavigationBar, transition: .immediate)
                if transition.isAnimated {
                    giftAuctionAccessoryPanel.animateIn(transition)
                }
            }
            giftAuctionAccessoryPanel.update(states: self.giftAuctionStates)
        } else if let giftAuctionAccessoryPanel = self.giftAuctionAccessoryPanel {
            self.giftAuctionAccessoryPanel = nil
            if transition.isAnimated {
                giftAuctionAccessoryPanel.animateOut(transition, completion: { [weak giftAuctionAccessoryPanel] in
                    giftAuctionAccessoryPanel?.removeFromSupernode()
                })
            } else {
                giftAuctionAccessoryPanel.removeFromSupernode()
            }
        }

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: transition)
        }
        
        self.accessoryPanelContainerHeight = additionalHeight
    }
    
    open var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
    
    open func joinGroupCall(peerId: PeerId, invite: String?, activeCall: EngineGroupCallDescription) {
        let context = self.context
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        self.view.endEditing(true)
        
        self.context.joinGroupCall(peerId: peerId, invite: invite, requestJoinAsPeerId: { completion in
            let currentAccountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map { peer in
                return [FoundPeer(peer: peer, subscribers: nil)]
            }
            
            let _ = (combineLatest(
                currentAccountPeer,
                context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.CallJoinAsPeerId(id: peerId))
            )
            |> map { currentAccountPeer, availablePeers, callJoinAsPeerId -> ([FoundPeer], EnginePeer.Id?) in
                var result = currentAccountPeer
                result.append(contentsOf: availablePeers)
                return (result, callJoinAsPeerId)
            }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] peers, callJoinAsPeerId in
                guard let strongSelf = self else {
                    return
                }
                
                let defaultJoinAsPeerId: PeerId? = callJoinAsPeerId
                                
                if peers.count == 1, let peer = peers.first {
                    completion(peer.peer.id)
                } else {
                    if let defaultJoinAsPeerId = defaultJoinAsPeerId {
                        completion(defaultJoinAsPeerId)
                    } else {
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        
                        var items: [ActionSheetItem] = []
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
                            
                        items.append(VoiceChatAccountHeaderActionSheetItem(title: presentationData.strings.VoiceChat_SelectAccount, text: isGroup ? presentationData.strings.VoiceChat_DisplayAsInfoGroup : presentationData.strings.VoiceChat_DisplayAsInfo))
                        for peer in peers {
                            var subtitle: String?
                            if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                                subtitle = presentationData.strings.VoiceChat_PersonalAccount
                            } else if let subscribers = peer.subscribers {
                                if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                                } else {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                                }
                            }
                            
                            items.append(VoiceChatPeerActionSheetItem(context: context, peer: EnginePeer(peer.peer), title: EnginePeer(peer.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), subtitle: subtitle ?? "", action: {
                                dismissAction()
                                completion(peer.peer.id)
                            }))
                        }
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        strongSelf.present(controller, in: .window(.root))
                    }
                }
            })
        }, activeCall: activeCall)
    }
    
    open func joinConferenceCall(message: EngineMessage) {
        var action: TelegramMediaAction?
        for media in message.media {
            if let media = media as? TelegramMediaAction {
                action = media
                break
            }
        }
        guard case let .conferenceCall(conferenceCall) = action?.action else {
            return
        }
        
        if let currentGroupCallController = self.context.sharedContext.currentGroupCallController as? VoiceChatController, case let .group(groupCall) = currentGroupCallController.call, let currentCallId = groupCall.callId, currentCallId == conferenceCall.callId {
            self.context.sharedContext.navigateToCurrentCall()
            return
        }
        
        let signal = self.context.engine.peers.joinCallInvitationInformation(messageId: message.id)
        let _ = (signal
        |> deliverOnMainQueue).startStandalone(next: { [weak self] resolvedCallLink in
            guard let self else {
                return
            }
            
            let _ = (self.context.engine.calls.getGroupCallPersistentSettings(callId: resolvedCallLink.id)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] value in
                guard let self else {
                    return
                }
                
                let value: PresentationGroupCallPersistentSettings = value?.get(PresentationGroupCallPersistentSettings.self) ?? PresentationGroupCallPersistentSettings.default
                
                self.context.joinConferenceCall(call: resolvedCallLink, isVideo: conferenceCall.flags.contains(.isVideo), unmuteByDefault: value.isMicrophoneEnabledByDefault)
            })
        }, error: { [weak self] error in
            guard let self else {
                return
            }
            switch error {
            case .doesNotExist:
                self.context.sharedContext.openCreateGroupCallUI(context: self.context, peerIds: conferenceCall.otherParticipants, parentController: self)
            default:
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                self.present(textAlertController(context: self.context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        })
    }
}
