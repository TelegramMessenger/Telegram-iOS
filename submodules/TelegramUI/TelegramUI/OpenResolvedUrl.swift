import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import OverlayStatusController
import AlertUI
import PassportUI
import InstantPageUI
import StickerPackPreviewUI
import JoinLinkPreviewUI
import LanguageLinkPreviewUI
import SettingsUI

private func defaultNavigationForPeerId(_ peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer) -> ChatControllerInteractionNavigateToPeer {
    if case .default = navigation {
        if let peerId = peerId {
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .chat(textInputState: nil, subject: nil)
            } else {
                return .chat(textInputState: nil, subject: nil)
            }
        } else {
            return .info
        }
    } else {
        return navigation
    }
}

func openResolvedUrlImpl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)?, sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    switch resolvedUrl {
        case let .externalUrl(url):
            context.sharedContext.openExternalUrl(context: context, urlContext: urlContext, url: url, forceExternal: false, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: dismissInput)
        case let .peer(peerId, navigation):
            if let peerId = peerId {
                openPeer(peerId, defaultNavigationForPeerId(peerId, navigation: navigation))
            } else {
                present(textAlertController(context: context, title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case .inaccessiblePeer:
            present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Conversation_ErrorInaccessibleMessage, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload):
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .onlyGroups, .onlyManageable], title: presentationData.strings.UserInfo_InviteBotToGroup))
            controller.peerSelected = { [weak controller] peerId in
                if payload.isEmpty {
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let _ = (addGroupMember(account: context.account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    } else {
                        let _ = (addChannelMember(account: context.account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    }
                } else {
                    let _ = (requestStartBotInGroup(account: context.account, botPeerId: botPeerId, groupPeerId: peerId, payload: payload)
                    |> deliverOnMainQueue).start(next: { result in
                        if let navigationController = navigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                        }
                        switch result {
                            case let .channelParticipant(participant):
                                context.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
                            case .none:
                                break
                        }
                        controller?.dismiss()
                    }, error: { _ in
                        
                    })
                }
            }
            dismissInput()
            present(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
        case let .channelMessage(peerId, messageId):
            openPeer(peerId, .chat(textInputState: nil, subject: .message(messageId)))
        case let .stickerPack(name):
            dismissInput()
            let controller = StickerPackPreviewController(context: context, stickerPack: .name(name), parentNavigationController: navigationController)
            controller.sendSticker = sendSticker
            present(controller, nil)
        case let .instantView(webpage, anchor):
            navigationController?.pushViewController(InstantPageController(context: context, webPage: webpage, sourcePeerType: .channel, anchor: anchor))
        case let .join(link):
            dismissInput()
            present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peerId in
                openPeer(peerId, .chat(textInputState: nil, subject: nil))
            }), nil)
        case let .localization(identifier):
            dismissInput()
            present(LanguageLinkPreviewController(context: context, identifier: identifier), nil)
        case let .proxy(host, port, username, password, secret):
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .socks5(username: username, password: password))
            }

            dismissInput()
            present(ProxyServerActionSheetController(context: context, server: server), nil)
        case let .confirmationCode(code):
            if let topController = navigationController?.topViewController as? ChangePhoneNumberCodeController {
                topController.applyCode(code)
            } else {
                var found = false
                navigationController?.currentWindow?.forEachController({ controller in
                    if let controller = controller as? SecureIdPlaintextFormController {
                        controller.applyPhoneCode(code)
                        found = true
                    }
                })
                if !found {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    present(textAlertController(context: context, title: nil, text: presentationData.strings.AuthCode_Alert(formattedConfirmationCode(code)).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }
        case let .cancelAccountReset(phone, hash):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            present(controller, nil)
            let _ = (requestCancelAccountResetData(network: context.account.network, hash: hash)
            |> deliverOnMainQueue).start(next: { [weak controller] data in
                controller?.dismiss()
                present(confirmPhoneNumberCodeController(context: context, phoneNumber: phone, codeData: data), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, error: { [weak controller] error in
                controller?.dismiss()
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Login_CodeFloodError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            dismissInput()
        case let .share(url, text, to):
            let continueWithPeer: (PeerId) -> Void = { peerId in
                let textInputState: ChatTextInputState?
                if let text = text, !text.isEmpty {
                    if let url = url, !url.isEmpty {
                        let urlString = NSMutableAttributedString(string: "\(url)\n")
                        let textString = NSAttributedString(string: "\(text)")
                        let selectionRange: Range<Int> = urlString.length ..< (urlString.length + textString.length)
                        urlString.append(textString)
                        textInputState = ChatTextInputState(inputText: urlString, selectionRange: selectionRange)
                    } else {
                        textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(text)"))
                    }
                } else if let url = url, !url.isEmpty {
                    textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(url)"))
                } else {
                    textInputState = nil
                }
                
                if let textInputState = textInputState {
                    let _ = (context.account.postbox.transaction({ transaction -> Void in
                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                            if let currentState = currentState as? ChatInterfaceState {
                                return currentState.withUpdatedComposeInputState(textInputState)
                            } else {
                                return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                            }
                        })
                    })
                    |> deliverOnMainQueue).start(completed: {
                        navigationController?.pushViewController(ChatControllerImpl(context: context, chatLocation: .peer(peerId)))
                    })
                } else {
                    navigationController?.pushViewController(ChatControllerImpl(context: context, chatLocation: .peer(peerId)))
                }
            }
            
            if let to = to {
                let query = to.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789").inverted)
                let _ = (context.account.postbox.searchContacts(query: query)
                |> deliverOnMainQueue).start(next: { (peers, _) in
                    for case let peer as TelegramUser in peers {
                        if peer.phone == query {
                            continueWithPeer(peer.id)
                            break
                        }
                    }
                })
            } else {
                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                controller.peerSelected = { [weak controller] peerId in
                    if let strongController = controller {
                        strongController.dismiss()
                        continueWithPeer(peerId)
                    }
                }
                if let navigationController = navigationController {
                    context.sharedContext.applicationBindings.dismissNativeController()
                    (navigationController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                }
            }
        case let .wallpaper(parameter):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var controller: OverlayStatusController?
            
            let signal: Signal<TelegramWallpaper, GetWallpaperError>
            var options: WallpaperPresentationOptions?
            var color: UIColor?
            var intensity: Int32?
            switch parameter {
                case let .slug(slug, wallpaperOptions, patternColor, patternIntensity):
                    signal = getWallpaper(account: context.account, slug: slug)
                    options = wallpaperOptions
                    color = patternColor
                    intensity = patternIntensity
                    controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                    present(controller!, nil)
                case let .color(color):
                    signal = .single(.color(Int32(color.rgb)))
            }
            
            let _ = (signal
            |> deliverOnMainQueue).start(next: { [weak controller] wallpaper in
                controller?.dismiss()
                let galleryController = WallpaperGalleryController(context: context, source: .wallpaper(wallpaper, options, color, intensity, nil))
                present(galleryController, nil)
            }, error: { [weak controller] error in
                controller?.dismiss()
            })
            dismissInput()
        case let .theme(slug):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let signal = getTheme(account: context.account, slug: slug)
            |> mapToSignal { themeInfo -> Signal<(Data, TelegramTheme), GetThemeError> in
                return Signal<(Data, TelegramTheme), GetThemeError> { subscriber in
                    let disposables = DisposableSet()
                    let resource = themeInfo.file?.resource
                    
                    if let resource = resource {
                        disposables.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: resource)).start())
                        
                        let maybeFetched = context.sharedContext.accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: false)
                        |> mapToSignal { maybeData -> Signal<Data?, NoError> in
                            if maybeData.complete {
                                let loadedData = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                                return .single(loadedData)
                            } else {
                                return context.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: false)
                                |> map { next -> Data? in
                                    if next.size > 0, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []) {
                                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
                                        return data
                                    } else {
                                        return nil
                                    }
                                }
                            }
                        }
                   
                        disposables.add(maybeFetched.start(next: { data in
                            if let data = data {
                                subscriber.putNext((data, themeInfo))
                                subscriber.putCompletion()
                            }
                        }))
                    } else {
                        subscriber.putError(.generic)
                    }
                    
                    return disposables
                }
            }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            present(controller, nil)
            
            var cancelImpl: (() -> Void)?
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                present(controller, nil)
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.35, queue: Queue.mainQueue())
            
            let disposable = MetaDisposable()
            let progressDisposable = progressSignal.start()
            cancelImpl = {
                disposable.set(nil)
            }
            disposable.set((signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            |> deliverOnMainQueue).start(next: { [weak controller] dataAndTheme in
                controller?.dismiss()
                
                if let theme = makePresentationTheme(data: dataAndTheme.0) {
                    let previewController = ThemePreviewController(context: context, previewTheme: theme, source: .theme(dataAndTheme.1))
                    present(previewController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }, error: { [weak controller] error in
                let errorText: String
                switch error {
                    case .generic, .slugInvalid:
                        errorText = presentationData.strings.Theme_ErrorNotFound
                    case .unsupported:
                        errorText = presentationData.strings.Theme_Unsupported
                }
                present(textAlertController(context: context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                controller?.dismiss()
            }))
            dismissInput()
    }
}
