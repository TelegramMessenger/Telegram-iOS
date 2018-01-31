import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import PassKit

func openChatMessage(account: Account, message: Message, standalone: Bool, reverseMessageGalleryOrder: Bool, navigationController: NavigationController?, dismissInput: @escaping () -> Void, present: @escaping (ViewController, Any?) -> Void, transitionNode: @escaping (MessageId, Media) -> ASDisplayNode?, addToTransitionSurface: @escaping (UIView) -> Void, openUrl: (String) -> Void, openPeer: @escaping (Peer, ChatControllerInteractionNavigateToPeer) -> Void, callPeer: @escaping (PeerId) -> Void, sendSticker: @escaping (TelegramMediaFile) -> Void, setupTemporaryHiddenMedia: @escaping (Signal<InstantPageGalleryEntry?, NoError>, Int, Media) -> Void) -> Bool {
    var galleryMedia: Media?
    var otherMedia: Media?
    var instantPageMedia: [InstantPageGalleryEntry]?
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            galleryMedia = file
        } else if let image = media as? TelegramMediaImage {
            galleryMedia = image
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            if content.embedUrl != nil && !webEmbedVideoContentSupportsWebpage(content) {
                openUrl(content.url)
                return true
            } else {
                if let file = content.file {
                    galleryMedia = file
                } else if let image = content.image {
                    galleryMedia = image
                }
                if let instantPage = content.instantPage, let galleryMedia = galleryMedia {
                    switch websiteType(of: content) {
                        case .instagram, .twitter:
                            let medias = instantPageGalleryMedia(webpageId: webpage.webpageId, page: instantPage, galleryMedia: galleryMedia)
                            if medias.count > 1 {
                                instantPageMedia = medias
                            }
                        case .generic:
                            break
                    }
                }
            }
        } else if let mapMedia = media as? TelegramMediaMap {
            galleryMedia = mapMedia
        } else if let contactMedia = media as? TelegramMediaContact {
            otherMedia = contactMedia
        }
    }
    
    if let instantPageMedia = instantPageMedia, let galleryMedia = galleryMedia {
        var centralIndex: Int = 0
        for i in 0 ..< instantPageMedia.count {
            if instantPageMedia[i].media.media.id == galleryMedia.id {
                centralIndex = i
                break
            }
        }
        
        let gallery = InstantPageGalleryController(account: account, entries: instantPageMedia, centralIndex: centralIndex, replaceRootController: { [weak navigationController] controller, ready in
            if let navigationController = navigationController {
                navigationController.replaceTopController(controller, animated: false, ready: ready)
            }
        })
        setupTemporaryHiddenMedia(gallery.hiddenMedia, centralIndex, galleryMedia)
        
        dismissInput()
        present(gallery, InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry in
            var selectedTransitionNode: ASDisplayNode?
            if entry.index == centralIndex {
                selectedTransitionNode = transitionNode(message.id, galleryMedia)
            }
            if let selectedTransitionNode = selectedTransitionNode {
                return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: addToTransitionSurface)
            }
            return nil
        }))
        return true
    } else if let galleryMedia = galleryMedia {
        if let mapMedia = galleryMedia as? TelegramMediaMap {
            dismissInput()
            present(legacyLocationController(message: message, mapMedia: mapMedia, account: account, openPeer: { peer in
                openPeer(peer, .info)
            }, sendLiveLocation: { coordinate, period in
                let outMessage: EnqueueMessage = .message(text: "", attributes: [], media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: period), replyToMessageId: nil, localGroupingKey: nil)
                let _ = enqueueMessages(account: account, peerId: message.id.peerId, messages: [outMessage]).start()
            }, stopLiveLocation: {
                account.telegramApplicationContext.liveLocationManager?.cancelLiveLocation(peerId: message.id.peerId)
            }), nil)
        } else if let file = galleryMedia as? TelegramMediaFile, file.isSticker {
            for attribute in file.attributes {
                if case let .Sticker(_, reference, _) = attribute {
                    if let reference = reference {
                        let controller = StickerPackPreviewController(account: account, stickerPack: reference)
                        controller.sendSticker = sendSticker
                        dismissInput()
                        present(controller, nil)
                    }
                    break
                }
            }
        } else if let file = galleryMedia as? TelegramMediaFile, file.isMusic || file.isVoice || file.isInstantVideo {
            let location: PeerMessagesPlaylistLocation
            let playerType: MediaManagerPlayerType
            if (file.isVoice || file.isInstantVideo) && message.tags.contains(.voiceOrInstantVideo) {
                location = .messages(peerId: message.id.peerId, tagMask: .voiceOrInstantVideo, at: message.id)
                playerType = .voice
            } else if file.isMusic && message.tags.contains(.music) {
                location = .messages(peerId: message.id.peerId, tagMask: .music, at: message.id)
                playerType = .music
            } else {
                location = .singleMessage(message.id)
                playerType = (file.isVoice || file.isInstantVideo) ? .voice : .music
            }
            account.telegramApplicationContext.mediaManager.setPlaylist(PeerMessagesMediaPlaylist(postbox: account.postbox, network: account.network, location: location), type: playerType)
        } else if let file = galleryMedia as? TelegramMediaFile, file.mimeType == "application/vnd.apple.pkpass" || (file.fileName != nil && file.fileName!.lowercased().hasSuffix(".pkpass")) {
            let _ = (account.postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true))
            |> take(1)
            |> deliverOnMainQueue).start(next: { data in
                guard let navigationController = navigationController else {
                    return
                }
                if data.complete, let content = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    var error: NSError?
                    let pass = PKPass(data: content, error: &error)
                    if error == nil {
                        let controller = PKAddPassesViewController(pass: pass)
                        if let window = navigationController.view.window {
                            window.rootViewController?.present(controller, animated: true)
                        }
                    }
                }
            })
        } else {
            let gallery = GalleryController(account: account, source: standalone ? .standaloneMessage(message) : .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, replaceRootController: { [weak navigationController] controller, ready in
                navigationController?.replaceTopController(controller, animated: false, ready: ready)
            }, baseNavigationController: navigationController)
            
            dismissInput()
            present(gallery, GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                let selectedTransitionNode = transitionNode(messageId, media)
                if let selectedTransitionNode = selectedTransitionNode {
                    return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: addToTransitionSurface)
                }
                return nil
            }))
        }
        return true
    } else if let contact = otherMedia as? TelegramMediaContact {
        let _ = (account.postbox.modify { modifier -> (Peer?, Bool?) in
            if let peerId = contact.peerId {
                return (modifier.getPeer(peerId), modifier.isPeerContact(peerId: peerId))
            } else {
                return (nil, nil)
            }
            } |> deliverOnMainQueue).start(next: { peer, isContact in
                guard let peer = peer else {
                    return
                }
                
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationTheme: presentationData.theme)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                var items: [ActionSheetItem] = []
            
                if let peerId = contact.peerId {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_SendMessage, action: {
                        dismissAction()
                        
                        openPeer(peer, .chat(textInputState: nil, messageId: nil))
                    }))
                    if let isContact = isContact, !isContact {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_AddContact, action: {
                            dismissAction()
                            let _ = addContactPeerInteractively(account: account, peerId: peerId, phone: contact.phoneNumber).start()
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_TelegramCall, action: {
                        dismissAction()
                        callPeer(peerId)
                    }))
                }
                items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_PhoneCall, action: {
                    dismissAction()
                    account.telegramApplicationContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(contact.phoneNumber).replacingOccurrences(of: " ", with: ""))")
                }))
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                dismissInput()
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        return true
    }
    return false
}

func openChatInstantPage(account: Account, message: Message, navigationController: NavigationController) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            if let _ = content.instantPage {
                var textUrl: String?
                if let pageUrl = URL(string: content.url) {
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            for entity in attribute.entities {
                                switch entity.type {
                                case let .TextUrl(url):
                                    if let parsedUrl = URL(string: url) {
                                        if pageUrl.scheme == parsedUrl.scheme && pageUrl.host == parsedUrl.host && pageUrl.path == parsedUrl.path {
                                            textUrl = url
                                        }
                                    }
                                case .Url:
                                    let nsText = message.text as NSString
                                    var entityRange = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    if entityRange.location + entityRange.length > nsText.length {
                                        entityRange.location = max(0, nsText.length - entityRange.length)
                                        entityRange.length = nsText.length - entityRange.location
                                    }
                                    let url = nsText.substring(with: entityRange)
                                    if let parsedUrl = URL(string: url) {
                                        if pageUrl.scheme == parsedUrl.scheme && pageUrl.host == parsedUrl.host && pageUrl.path == parsedUrl.path {
                                            textUrl = url
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            break inner
                        }
                    }
                }
                var anchor: String?
                if let textUrl = textUrl, let anchorRange = textUrl.range(of: "#") {
                    anchor = String(textUrl[anchorRange.upperBound...])
                }
                
                let pageController = InstantPageController(account: account, webPage: webpage, anchor: anchor)
                navigationController.pushViewController(pageController)
            }
            break
        }
    }
}
