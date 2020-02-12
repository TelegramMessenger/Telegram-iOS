import Foundation
import UIKit
import TelegramCore
import SyncCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import AccountContext
import SafariServices
import OpenInExternalAppUI
import InstantPageUI
import HashtagSearchUI
import StickerPackPreviewUI
import JoinLinkPreviewUI

func handleTextLinkActionImpl(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem) {
    let presentImpl: (ViewController, Any?) -> Void = { controllerToPresent, _ in
        controller.present(controllerToPresent, in: .window(.root))
    }
    
    let openResolvedPeerImpl: (PeerId?, ChatControllerInteractionNavigateToPeer) -> Void = { [weak controller] peerId, navigation in
        context.sharedContext.openResolvedUrl(.peer(peerId, navigation), context: context, urlContext: .generic, navigationController: (controller?.navigationController as? NavigationController), openPeer: { (peerId, navigation) in
            switch navigation {
                case let .chat(_, subject):
                    if let navigationController = controller?.navigationController as? NavigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId), subject: subject, keepStack: .always))
                    }
                case .info:
                    let peerSignal: Signal<Peer?, NoError>
                    peerSignal = context.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
                    navigateDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { peer in
                        if let controller = controller, let peer = peer {
                            if let infoController = context.sharedContext.makePeerInfoController(context: context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
                                (controller.navigationController as? NavigationController)?.pushViewController(infoController)
                            }
                        }
                    }))
                default:
                    break
            }
        }, sendFile: nil,
        sendSticker: nil,
        present: presentImpl, dismissInput: {}, contentContext: nil)
    }
    
    let openLinkImpl: (String) -> Void = { [weak controller] url in
        navigateDisposable.set((context.sharedContext.resolveUrl(account: context.account, url: url) |> deliverOnMainQueue).start(next: { result in
            if let controller = controller {
                switch result {
                    case let .externalUrl(url):
                        context.sharedContext.applicationBindings.openUrl(url)
                    case let .peer(peerId, _):
                        openResolvedPeerImpl(peerId, .default)
                    case let .channelMessage(peerId, messageId):
                        if let navigationController = controller.navigationController as? NavigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId), subject: .message(messageId)))
                        }
                    case let .stickerPack(name):
                        let packReference: StickerPackReference = .name(name)
                        controller.present(StickerPackScreen(context: context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controller.navigationController as? NavigationController), in: .window(.root))
                    case let .instantView(webpage, anchor):
                        (controller.navigationController as? NavigationController)?.pushViewController(InstantPageController(context: context, webPage: webpage, sourcePeerType: .group, anchor: anchor))
                    case let .join(link):
                        controller.present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peerId in
                            openResolvedPeerImpl(peerId, .chat(textInputState: nil, subject: nil))
                        }, parentNavigationController: controller.navigationController as? NavigationController), in: .window(.root))
                    #if ENABLE_WALLET
                    case let .wallet(address, amount, comment):
                        context.sharedContext.openWallet(context: context, walletContext: .send(address: address, amount: amount, comment: comment)) { c in
                            (controller.navigationController as? NavigationController)?.pushViewController(c)
                        }
                    #endif
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
                    let actionSheet = ActionSheetController(presentationData: presentationData)
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
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
                case let .mention(mention):
                    let actionSheet = ActionSheetController(presentationData: presentationData)
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
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
                case let .hashtag(_, hashtag):
                    let actionSheet = ActionSheetController(presentationData: presentationData)
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
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controller.present(actionSheet, in: .window(.root))
            }
    }
}
