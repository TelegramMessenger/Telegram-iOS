import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import OpenInExternalAppUI
import PresentationDataUtils
import OverlayStatusController
import HashtagSearchUI
import ShareController
import UndoUI

extension PeerInfoScreenNode {
    func openResolved(_ result: ResolvedUrl) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .chat(peerId: self.peerId, message: nil, updatedPresentationData: self.controller?.updatedPresentationData), navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { [weak self] peer, navigation in
            guard let strongSelf = self else {
                return
            }
            switch navigation {
            case let .chat(inputState, subject, peekData):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: subject, updateTextInputState: inputState, activateInput: inputState != nil ? .text : nil, keepStack: .always, peekData: peekData))
            case .info:
                if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                    if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        strongSelf.controller?.push(infoController)
                    }
                }
            case let .withBotStartPayload(startPayload):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botStart: startPayload, keepStack: .always))
            case let .withAttachBot(attachBotStart):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
            case let .withBotApp(botAppStart):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botAppStart: botAppStart))
            default:
                break
            }
        },
        sendFile: nil,
        sendSticker: nil,
        sendEmoji: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: { peerId, invite, call in
            
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, contentContext: nil, progress: nil, completion: nil)
    }
    
    func openUrl(url: String, concealed: Bool, external: Bool, forceExternal: Bool = false, commit: @escaping () -> Void = {}) {
        let _ = openUserGeneratedUrl(context: self.context, peerId: self.peerId, url: url, concealed: concealed, present: { [weak self] c in
            self?.controller?.present(c, in: .window(.root))
        }, openResolved: { [weak self] tempResolved in
            guard let strongSelf = self else {
                return
            }
            
            let result: ResolvedUrl = external ? .externalUrl(url) : tempResolved
            
            strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, forceExternal: forceExternal, forceUpdate: false, openPeer: { peer, navigation in
                self?.openPeer(peerId: peer.id, navigation: navigation)
                commit()
            }, sendFile: nil,
            sendSticker: nil,
            sendEmoji: nil,
            requestMessageActionUrlAuth: nil,
            joinVoiceChat: { peerId, invite, call in
                
            },
            present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, dismissInput: {
                self?.view.endEditing(true)
            }, contentContext: nil, progress: nil, completion: nil)
        })
    }
    
    func openUrlIn(_ url: String) {
        let actionSheet = OpenInActionSheetController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, item: .url(url: url), openUrl: { [weak self] url in
            if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                })
            }
        })
        self.controller?.present(actionSheet, in: .window(.root))
    }

    func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default) {
        let disposable: MetaDisposable
        if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
            disposable = resolvePeerByNameDisposable
        } else {
            disposable = MetaDisposable()
            self.resolvePeerByNameDisposable = disposable
        }
        var resolveSignal = self.context.engine.peers.resolvePeerByName(name: name, referrer: nil, ageLimit: 10)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
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
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            self?.resolvePeerByNameDisposable?.set(nil)
        }
        disposable.set((resolveSignal
        |> take(1)
        |> mapToSignal { peer -> Signal<Peer?, NoError> in
            return .single(peer?._asPeer())
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                if let peer = peer {
                    var navigation = navigation
                    if case .default = navigation {
                        if let peer = peer as? TelegramUser, peer.botInfo != nil {
                            navigation = .chat(textInputState: nil, subject: nil, peekData: nil)
                        }
                    }
                    strongSelf.openResolved(.peer(peer, navigation))
                } else {
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }))
    }
    
    func openHashtag(_ hashtag: String, peerName: String?) {
        if self.resolvePeerByNameDisposable == nil {
            self.resolvePeerByNameDisposable = MetaDisposable()
        }
        var resolveSignal: Signal<Peer?, NoError>
        if let peerName = peerName {
            resolveSignal = self.context.engine.peers.resolvePeerByName(name: peerName, referrer: nil)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(result) = result else {
                    return .complete()
                }
                return .single(result)
            }
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                return .single(peer?._asPeer())
            }
        } else {
            resolveSignal = self.context.account.postbox.loadedPeerWithId(self.peerId)
            |> map(Optional.init)
        }
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
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
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            self?.resolvePeerByNameDisposable?.set(nil)
        }
        self.resolvePeerByNameDisposable?.set((resolveSignal
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self, !hashtag.isEmpty {
                let searchController = HashtagSearchController(context: strongSelf.context, peer: peer.flatMap(EnginePeer.init), query: hashtag)
                strongSelf.controller?.push(searchController)
            }
        }))
    }

    func openUsername(value: String, isMainUsername: Bool, progress: Promise<Bool>?) {
        let url: String
        if value.hasPrefix("https://") {
            url = value
        } else {
            url = "https://t.me/\(value)"
        }
        
        let openShare: (TelegramCollectibleItemInfo?) -> Void = { [weak self] collectibleItemInfo in
            guard let self else {
                return
            }
            let shareController = ShareController(context: self.context, subject: .url(url), updatedPresentationData: self.controller?.updatedPresentationData, collectibleItemInfo: collectibleItemInfo)
            shareController.completed = { [weak self] peerIds in
                guard let strongSelf = self else {
                    return
                }
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
                        text = presentationData.strings.UserInfo_LinkForwardTooltip_SavedMessages_One
                        savedMessages = true
                    } else {
                        if peers.count == 1, let peer = peers.first {
                            let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_Chat_One(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                        } else if let peer = peers.first {
                            let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
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
            shareController.actionCompleted = { [weak self] in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            }
            self.view.endEditing(true)
            self.controller?.present(shareController, in: .window(.root))
        }
        
        if let pathComponents = URL(string: url)?.pathComponents, pathComponents.count >= 2, !pathComponents[1].isEmpty {
            let namePart = pathComponents[1]
            progress?.set(.single(true))
            let _ = (self.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: self.context, peerId: self.peerId, subject: .username(namePart))
            |> deliverOnMainQueue).start(next: { [weak self] initialData in
                guard let self else {
                    return
                }
                
                progress?.set(.single(false))
                
                if let initialData {
                    if isMainUsername {
                        openShare(initialData.collectibleItemInfo)
                    } else {
                        self.view.endEditing(true)
                        self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                    }
                } else {
                    openShare(nil)
                }
            })
        } else {
            openShare(nil)
        }
    }
}
