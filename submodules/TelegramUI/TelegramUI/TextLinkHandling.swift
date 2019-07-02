import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences

import SafariServices

func handleTextLinkAction(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem) {
    let presentImpl: (ViewController, Any?) -> Void = { controllerToPresent, _ in
        controller.present(controllerToPresent, in: .window(.root))
    }
    
    let openResolvedPeerImpl: (PeerId?, ChatControllerInteractionNavigateToPeer) -> Void = { [weak controller] peerId, navigation in
        openResolvedUrl(.peer(peerId, navigation), context: context, navigationController: (controller?.navigationController as? NavigationController), openPeer: { (peerId, navigation) in
            switch navigation {
                case let .chat(_, messageId):
                    if let navigationController = controller?.navigationController as? NavigationController {
                        navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(peerId), messageId: messageId, keepStack: .always)
                    }
                case .info:
                    let peerSignal: Signal<Peer?, NoError>
                    peerSignal = context.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
                    navigateDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { peer in
                        if let controller = controller, let peer = peer {
                            if let infoController = peerInfoController(context: context, peer: peer) {
                                (controller.navigationController as? NavigationController)?.pushViewController(infoController)
                            }
                        }
                    }))
                default:
                    break
            }
        }, present: presentImpl, dismissInput: {})
    }
    
    let openLinkImpl: (String) -> Void = { [weak controller] url in
        navigateDisposable.set((resolveUrl(account: context.account, url: url) |> deliverOnMainQueue).start(next: { result in
            if let controller = controller {
                switch result {
                    case let .externalUrl(url):
                        context.sharedContext.applicationBindings.openUrl(url)
                    case let .peer(peerId, _):
                        openResolvedPeerImpl(peerId, .default)
                    case let .channelMessage(peerId, messageId):
                        if let navigationController = controller.navigationController as? NavigationController {
                            navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(peerId), messageId: messageId)
                        }
                    case let .stickerPack(name):
                        controller.present(StickerPackPreviewController(context: context, stickerPack: .name(name), parentNavigationController: controller.navigationController as? NavigationController), in: .window(.root))
                    case let .instantView(webpage, anchor):
                        (controller.navigationController as? NavigationController)?.pushViewController(InstantPageController(context: context, webPage: webpage, sourcePeerType: .group, anchor: anchor))
                    case let .join(link):
                        controller.present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peerId in
                            openResolvedPeerImpl(peerId, .chat(textInputState: nil, messageId: nil))
                        }), in: .window(.root))
                    default:
                        break
                }
            }
        }))
    }
    
    let openPeerMentionImpl: (String) -> Void = { mention in
        navigateDisposable.set((resolvePeerByName(account: context.account, name: mention, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peerId in
            openResolvedPeerImpl(peerId, .default)
        }))
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    switch action {
        case .tap:
            switch itemLink {
                case let .url(url):
                    openLinkImpl(url)
                case let .mention(mention):
                    openPeerMentionImpl(mention)
                case let .hashtag(_, hashtag):
                    if let peerId = peerId {
                        let peerSignal = context.account.postbox.loadedPeerWithId(peerId)
                        let _ = (peerSignal
                        |> deliverOnMainQueue).start(next: { peer in
                            let searchController = HashtagSearchController(context: context, peer: peer, query: hashtag)
                            (controller.navigationController as? NavigationController)?.pushViewController(searchController)
                        })
                    }
            }
        case .longTap:
            switch itemLink {
                case let .url(url):
                    let canOpenIn = availableOpenInOptions(context: context, item: .url(url: url)).count > 1
                    let openText = canOpenIn ? presentationData.strings.Conversation_FileOpenIn : presentationData.strings.Conversation_LinkDialogOpen
                    let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: url),
                        ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            openLinkImpl(url)
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = url
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let link = URL(string: url) {
                                let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                            }
                        })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
                case let .mention(mention):
                    let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: mention),
                        ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            openPeerMentionImpl(mention)
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = mention
                        })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
                case let .hashtag(_, hashtag):
                    let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: hashtag),
                        ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let searchController = HashtagSearchController(context: context, peer: nil, query: hashtag)
                            (controller.navigationController as? NavigationController)?.pushViewController(searchController)
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = hashtag
                        })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
            }
    }
}
