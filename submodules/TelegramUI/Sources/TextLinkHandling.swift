import Foundation
import UIKit
import TelegramCore
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
import PresentationDataUtils
import UrlWhitelist
import UndoUI

func handleTextLinkActionImpl(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem) {
    let presentImpl: (ViewController, Any?) -> Void = { controllerToPresent, _ in
        controller.present(controllerToPresent, in: .window(.root))
    }
    
    let openResolvedPeerImpl: (EnginePeer?, ChatControllerInteractionNavigateToPeer) -> Void = { [weak controller] peer, navigation in
        guard let peer = peer else {
            return
        }
        context.sharedContext.openResolvedUrl(.peer(peer._asPeer(), navigation), context: context, urlContext: .generic, navigationController: (controller?.navigationController as? NavigationController), forceExternal: false, openPeer: { (peer, navigation) in
            switch navigation {
                case let .chat(_, subject, peekData):
                    if let navigationController = controller?.navigationController as? NavigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject, keepStack: .always, peekData: peekData))
                    }
                case .info:
                    let peerSignal: Signal<Peer?, NoError>
                    peerSignal = context.account.postbox.loadedPeerWithId(peer.id) |> map(Optional.init)
                    navigateDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { peer in
                        if let controller = controller, let peer = peer {
                            if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                (controller.navigationController as? NavigationController)?.pushViewController(infoController)
                            }
                        }
                    }))
                default:
                    break
            }
        }, sendFile: nil,
        sendSticker: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: nil,
        present: presentImpl, dismissInput: {}, contentContext: nil)
    }
    
    let openLinkImpl: (String) -> Void = { [weak controller] url in
        navigateDisposable.set((context.sharedContext.resolveUrl(context: context, peerId: peerId, url: url, skipUrlAuth: true) |> deliverOnMainQueue).start(next: { result in
            if let controller = controller {
                switch result {
                    case let .externalUrl(url):
                        context.sharedContext.applicationBindings.openUrl(url)
                    case let .peer(peer, navigation):
                        openResolvedPeerImpl(peer.flatMap(EnginePeer.init), navigation)
                    case let .channelMessage(peer, messageId, timecode):
                        if let navigationController = controller.navigationController as? NavigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(EnginePeer(peer)), subject: .message(id: .id(messageId), highlight: true, timecode: timecode)))
                        }
                    case let .replyThreadMessage(replyThreadMessage, messageId):
                        if let navigationController = controller.navigationController as? NavigationController {
                            let _ = ChatControllerImpl.openMessageReplies(context: context, navigationController: navigationController, present: { [weak controller] c, a in
                                controller?.present(c, in: .window(.root), with: a)
                            }, messageId: replyThreadMessage.messageId, isChannelPost: replyThreadMessage.isChannelPost, atMessage: messageId, displayModalProgress: true).start()
                        }
                    case let .replyThread(messageId):
                        if let navigationController = controller.navigationController as? NavigationController {
                            let _ = context.sharedContext.navigateToForumThread(context: context, peerId: messageId.peerId, threadId: Int64(messageId.id), messageId: nil, navigationController: navigationController, activateInput: nil, keepStack: .always).start()
                        }
                    case let .stickerPack(name, _):
                        let packReference: StickerPackReference = .name(name)
                        controller.present(StickerPackScreen(context: context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controller.navigationController as? NavigationController), in: .window(.root))
                    case let .instantView(webpage, anchor):
                        (controller.navigationController as? NavigationController)?.pushViewController(InstantPageController(context: context, webPage: webpage, sourcePeerType: .group, anchor: anchor))
                    case let .join(link):
                        controller.present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                            openResolvedPeerImpl(peer, .chat(textInputState: nil, subject: nil, peekData: peekData))
                        }, parentNavigationController: controller.navigationController as? NavigationController), in: .window(.root))
                    default:
                        break
                }
            }
        }))
    }
    
    let openPeerMentionImpl: (String) -> Void = { mention in
        navigateDisposable.set((context.engine.peers.resolvePeerByName(name: mention, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peer in
            openResolvedPeerImpl(peer, .default)
        }))
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    switch action {
        case .tap:
            switch itemLink {
                case .url(let url, var concealed):
                    let (parsedString, parsedConcealed) = parseUrl(url: url, wasConcealed: false)
                    if parsedConcealed {
                        concealed = true
                    }
                    
                    if concealed {
                        var rawDisplayUrl: String = parsedString
                        let maxLength = 180
                        if rawDisplayUrl.count > maxLength {
                            rawDisplayUrl = String(rawDisplayUrl[..<rawDisplayUrl.index(rawDisplayUrl.startIndex, offsetBy: maxLength - 2)]) + "..."
                        }
                        var displayUrl = rawDisplayUrl
                        displayUrl = displayUrl.replacingOccurrences(of: "\u{202e}", with: "")
                        controller.present(textAlertController(context: context, title: nil, text: presentationData.strings.Generic_OpenHiddenLinkAlert(displayUrl).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                            openLinkImpl(url)
                        })]), in: .window(.root))
                    } else {
                        openLinkImpl(url)
                    }
                case let .mention(mention):
                    openPeerMentionImpl(mention)
                case let .hashtag(_, hashtag):
                    if let peerId = peerId {
                        let peerSignal = context.account.postbox.loadedPeerWithId(peerId)
                        let _ = (peerSignal
                        |> deliverOnMainQueue).start(next: { peer in
                            let searchController = HashtagSearchController(context: context, peer: EnginePeer(peer), query: hashtag)
                            (controller.navigationController as? NavigationController)?.pushViewController(searchController)
                        })
                    }
            }
        case .longTap:
            switch itemLink {
                case let .url(url, _):
                    let canOpenIn = availableOpenInOptions(context: context, item: .url(url: url)).count > 1
                    let openText = canOpenIn ? presentationData.strings.Conversation_FileOpenIn : presentationData.strings.Conversation_LinkDialogOpen
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    let (displayUrl, _) = parseUrl(url: url, wasConcealed: false)
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: displayUrl),
                        ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            openLinkImpl(url)
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = url
                            
                            let content: UndoOverlayContent
                            if url.hasPrefix("tel:") {
                                content = .copy(text: presentationData.strings.Conversation_PhoneCopied)
                            } else if url.hasPrefix("mailto:") {
                                content = .copy(text: presentationData.strings.Conversation_EmailCopied)
                            } else {
                                content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
                            }
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_HashtagCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
