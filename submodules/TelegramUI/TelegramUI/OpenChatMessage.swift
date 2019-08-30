import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import PassKit
import Lottie
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import GalleryUI
import InstantPageUI
import LocationUI
import StickerPackPreviewUI
import PeerAvatarGalleryUI
import PeerInfoUI
import SettingsUI
import AlertUI

private enum ChatMessageGalleryControllerData {
    case url(String)
    case pass(TelegramMediaFile)
    case instantPage(InstantPageGalleryController, Int, Media)
    case map(TelegramMediaMap)
    case stickerPack(StickerPackReference)
    case audio(TelegramMediaFile)
    case document(TelegramMediaFile)
    case gallery(GalleryController)
    case secretGallery(SecretMediaPreviewController)
    case chatAvatars(AvatarGalleryController, Media)
    case theme(TelegramMediaFile)
    case other(Media)
}

private func chatMessageGalleryControllerData(context: AccountContext, message: Message, navigationController: NavigationController?, standalone: Bool, reverseMessageGalleryOrder: Bool, mode: ChatControllerInteractionOpenMessageMode, synchronousLoad: Bool, actionInteraction: GalleryControllerActionInteraction?) -> ChatMessageGalleryControllerData? {
    var galleryMedia: Media?
    var otherMedia: Media?
    var instantPageMedia: (TelegramMediaWebpage, [InstantPageGalleryEntry])?
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            switch action.action {
            case let .photoUpdated(image):
                if let peer = messageMainPeer(message), let image = image {
                    let promise: Promise<[AvatarGalleryEntry]> = Promise([AvatarGalleryEntry.image(image.reference, image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: .media(media: .message(message: MessageReference(message), media: media), resource: $0.resource)) }), peer, message.timestamp, nil, message.id)])
                    let galleryController = AvatarGalleryController(context: context, peer: peer, remoteEntries: promise, replaceRootController: { controller, ready in
                        
                    })
                    return .chatAvatars(galleryController, image)
                }
            default:
                break
            }
        } else if let file = media as? TelegramMediaFile {
            galleryMedia = file
        } else if let image = media as? TelegramMediaImage {
            galleryMedia = image
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            if let file = content.file {
                galleryMedia = file
            } else if let image = content.image {
                if case .link = mode {
                } else if ["photo", "document", "video", "gif", "telegram_album"].contains(content.type) {
                    galleryMedia = image
                }
            }
            
            if let instantPage = content.instantPage, let galleryMedia = galleryMedia {
                switch instantPageType(of: content) {
                    case .album:
                        let medias = instantPageGalleryMedia(webpageId: webpage.webpageId, page: instantPage, galleryMedia: galleryMedia)
                        if medias.count > 1 {
                            instantPageMedia = (webpage, medias)
                        }      
                    default:
                        break
                }
            }
        } else if let mapMedia = media as? TelegramMediaMap {
            galleryMedia = mapMedia
        } else if let contactMedia = media as? TelegramMediaContact {
            otherMedia = contactMedia
        }
    }
    
    var stream = false
    var autoplayingVideo = false
    var landscape = false
    var timecode: Double? = nil
    
    switch mode {
        case .stream:
            stream = true
        case .automaticPlayback:
            autoplayingVideo = true
        case .landscape:
            autoplayingVideo = true
            landscape = true
        case let .timecode(time):
            timecode = time
        default:
            break
    }
    
    if let (webPage, instantPageMedia) = instantPageMedia, let galleryMedia = galleryMedia {
        var centralIndex: Int = 0
        for i in 0 ..< instantPageMedia.count {
            if instantPageMedia[i].media.media.id == galleryMedia.id {
                centralIndex = i
                break
            }
        }
        
        let gallery = InstantPageGalleryController(context: context, webPage: webPage, message: message, entries: instantPageMedia, centralIndex: centralIndex, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, replaceRootController: { [weak navigationController] controller, ready in
            if let navigationController = navigationController {
                navigationController.replaceTopController(controller, animated: false, ready: ready)
            }
        }, baseNavigationController: navigationController)
        return .instantPage(gallery, centralIndex, galleryMedia)
    } else if let galleryMedia = galleryMedia {
        if let mapMedia = galleryMedia as? TelegramMediaMap {
            return .map(mapMedia)
        } else if let file = galleryMedia as? TelegramMediaFile, (file.isSticker || file.isAnimatedSticker) {
            for attribute in file.attributes {
                if case let .Sticker(_, reference, _) = attribute {
                    if let reference = reference {
                        return .stickerPack(reference)
                    }
                    break
                }
            }
        } else if let file = galleryMedia as? TelegramMediaFile, file.isAnimatedSticker {
            return nil
        } else if let file = galleryMedia as? TelegramMediaFile, file.isMusic || file.isVoice || file.isInstantVideo {
            return .audio(file)
        } else if let file = galleryMedia as? TelegramMediaFile, file.mimeType == "application/vnd.apple.pkpass" || (file.fileName != nil && file.fileName!.lowercased().hasSuffix(".pkpass")) {
            return .pass(file)
        } else {
            if let file = galleryMedia as? TelegramMediaFile {
                if let fileName = file.fileName {
                    let ext = (fileName as NSString).pathExtension.lowercased()
                    if ext == "tgios-theme" {
                        return .theme(file)
                    } else if ext == "wav" || ext == "opus" {
                        return .audio(file)
                    } else if ext == "json", let fileSize = file.size, fileSize < 1024 * 1024 {
                        if let path = context.account.postbox.mediaBox.completedResourcePath(file.resource), let _ = LOTComposition(filePath: path) {
                            let gallery = GalleryController(context: context, source: .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                                navigationController?.replaceTopController(controller, animated: false, ready: ready)
                                }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                            return .gallery(gallery)
                        }
                    }
                    #if DEBUG
                    if ext == "mkv" {
                        let gallery = GalleryController(context: context, source: standalone ? .standaloneMessage(message) : .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                            navigationController?.replaceTopController(controller, animated: false, ready: ready)
                            }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                        return .gallery(gallery)
                    }
                    #endif
                }
                
                if internalDocumentItemSupportsMimeType(file.mimeType, fileName: file.fileName ?? "file") {
                    let gallery = GalleryController(context: context, source: .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                        navigationController?.replaceTopController(controller, animated: false, ready: ready)
                        }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                    return .gallery(gallery)
                }
                
                if !file.isVideo {
                    return .document(file)
                }
            }
            
            if message.containsSecretMedia {
                let gallery = SecretMediaPreviewController(context: context, messageId: message.id)
                return .secretGallery(gallery)
            } else {
                let gallery = GalleryController(context: context, source: standalone ? .standaloneMessage(message) : .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                    navigationController?.replaceTopController(controller, animated: false, ready: ready)
                    }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                gallery.temporaryDoNotWaitForReady = autoplayingVideo
                return .gallery(gallery)
            }
        }
    }
    if let otherMedia = otherMedia {
        return .other(otherMedia)
    } else {
        return nil
    }
}

enum ChatMessagePreviewControllerData {
    case instantPage(InstantPageGalleryController, Int, Media)
    case gallery(GalleryController)
}

func chatMessagePreviewControllerData(context: AccountContext, message: Message, standalone: Bool, reverseMessageGalleryOrder: Bool, navigationController: NavigationController?) -> ChatMessagePreviewControllerData? {
    if let mediaData = chatMessageGalleryControllerData(context: context, message: message, navigationController: navigationController, standalone: standalone, reverseMessageGalleryOrder: reverseMessageGalleryOrder, mode: .default, synchronousLoad: true, actionInteraction: nil) {
        switch mediaData {
            case let .gallery(gallery):
                return .gallery(gallery)
            case let .instantPage(gallery, centralIndex, galleryMedia):
                return .instantPage(gallery, centralIndex, galleryMedia)
            default:
                break
        }
    }
    return nil
}

func openChatMessageImpl(_ params: OpenChatMessageParams) -> Bool {
    if let mediaData = chatMessageGalleryControllerData(context: params.context, message: params.message, navigationController: params.navigationController, standalone: params.standalone, reverseMessageGalleryOrder: params.reverseMessageGalleryOrder, mode: params.mode, synchronousLoad: false, actionInteraction: params.actionInteraction) {
        switch mediaData {
            case let .url(url):
                params.openUrl(url)
                return true
            case let .pass(file):
                let _ = (params.context.account.postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true))
                |> take(1)
                |> deliverOnMainQueue).start(next: { data in
                    guard let navigationController = params.navigationController else {
                        return
                    }
                    if data.complete, let content = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                        if let pass = try? PKPass(data: content), let controller = PKAddPassesViewController(pass: pass) {
                            if let window = navigationController.view.window {
                                controller.popoverPresentationController?.sourceView = window
                                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                window.rootViewController?.present(controller, animated: true)
                            }
                        }
                    }
                })
                return true
            case let .instantPage(gallery, centralIndex, galleryMedia):
                params.setupTemporaryHiddenMedia(gallery.hiddenMedia |> map { a -> Any? in a }, centralIndex, galleryMedia)
                
                params.dismissInput()
                params.present(gallery, InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry in
                    var selectedTransitionNode: (ASDisplayNode, () -> (UIView?, UIView?))?
                    if entry.index == centralIndex {
                        selectedTransitionNode = params.transitionNode(params.message.id, galleryMedia)
                    }
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }))
                return true
            case let .map(mapMedia):
                params.dismissInput()
                
                let controller = legacyLocationController(message: params.message, mapMedia: mapMedia, context: params.context, isModal: params.modal, openPeer: { peer in
                    params.openPeer(peer, .info)
                }, sendLiveLocation: { coordinate, period in
                    let outMessage: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: period)), replyToMessageId: nil, localGroupingKey: nil)
                    params.enqueueMessage(outMessage)
                }, stopLiveLocation: {
                    params.context.liveLocationManager?.cancelLiveLocation(peerId: params.message.id.peerId)
                }, openUrl: params.openUrl)
                
                if params.modal {
                    params.present(controller, nil)
                } else {
                    params.navigationController?.pushViewController(controller)
                }
                return true
            case let .stickerPack(reference):
                let controller = StickerPackPreviewController(context: params.context, stickerPack: reference, parentNavigationController: params.navigationController)
                controller.sendSticker = params.sendSticker
                params.dismissInput()
                params.present(controller, nil)
                return true
            case let .document(file):
                let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                if let rootController = params.navigationController?.view.window?.rootViewController {
                    presentDocumentPreviewController(rootController: rootController, theme: presentationData.theme, strings: presentationData.strings, postbox: params.context.account.postbox, file: file)
                }
                return true
            case let .audio(file):
                let location: PeerMessagesPlaylistLocation
                let playerType: MediaManagerPlayerType
                var control = SharedMediaPlayerControlAction.playback(.play)
                if case let .timecode(time) = params.mode {
                    control = .seek(time)
                }
                if (file.isVoice || file.isInstantVideo) && params.message.tags.contains(.voiceOrInstantVideo) {
                    if params.standalone {
                        location = .recentActions(params.message)
                    } else {
                        location = .messages(peerId: params.message.id.peerId, tagMask: .voiceOrInstantVideo, at: params.message.id)
                    }
                    playerType = .voice
                } else if file.isMusic && params.message.tags.contains(.music) {
                    if params.standalone {
                            location = .recentActions(params.message)
                    } else {
                        location = .messages(peerId: params.message.id.peerId, tagMask: .music, at: params.message.id)
                    }
                    playerType = .music
                } else {
                    if params.standalone {
                        location = .recentActions(params.message)
                    } else {
                        location = .singleMessage(params.message.id)
                    }
                    playerType = (file.isVoice || file.isInstantVideo) ? .voice : .music
                }
                params.context.sharedContext.mediaManager.setPlaylist((params.context.account, PeerMessagesMediaPlaylist(postbox: params.context.account.postbox, network: params.context.account.network, location: location)), type: playerType, control: control)
                return true
            case let .gallery(gallery):
                params.dismissInput()
                params.present(gallery, GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                    let selectedTransitionNode = params.transitionNode(messageId, media)
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }))
                return true
            case let .secretGallery(gallery):
                params.dismissInput()
                params.present(gallery, GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                    let selectedTransitionNode = params.transitionNode(messageId, media)
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }))
                return true
            case let .other(otherMedia):
                if let contact = otherMedia as? TelegramMediaContact {
                    let _ = (params.context.account.postbox.transaction { transaction -> (Peer?, Bool?) in
                        if let peerId = contact.peerId {
                            return (transaction.getPeer(peerId), transaction.isPeerContact(peerId: peerId))
                        } else {
                            return (nil, nil)
                        }
                    } |> deliverOnMainQueue).start(next: { peer, isContact in
                        let contactData: DeviceContactExtendedData
                        if let vCard = contact.vCardData, let vCardData = vCard.data(using: .utf8), let parsed = DeviceContactExtendedData(vcard: vCardData) {
                            contactData = parsed
                        } else {
                            contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName, lastName: contact.lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: contact.phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
                        }
                        let controller = deviceContactInfoController(context: params.context, subject: .vcard(peer, nil, contactData), completed: nil, cancelled: nil)
                        params.navigationController?.pushViewController(controller)
                    })
                    return true
                }
            case let .chatAvatars(controller, media):
                params.dismissInput()
                params.chatAvatarHiddenMedia(controller.hiddenMedia |> map { value -> MessageId? in
                    if value != nil {
                        return params.message.id
                    } else {
                        return nil
                    }
                }, media)
                
                params.present(controller, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                    if let selectedTransitionNode = params.transitionNode(params.message.id, media) {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }))
            case let .theme(media):
                params.dismissInput()
                let path = params.context.account.postbox.mediaBox.completedResourcePath(media.resource)
                var previewTheme: PresentationTheme?
                if let path = path, let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                    let startTime = CACurrentMediaTime()
                    previewTheme = makePresentationTheme(data: data)
                    print("time \(CACurrentMediaTime() - startTime)")
                }
                
                guard let theme = previewTheme else {
                    return false
                }
                let controller = ThemePreviewController(context: params.context, previewTheme: theme, source: .media(.message(message: MessageReference(params.message), media: media)))
                params.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
    }
    return false
}

func openChatInstantPage(context: AccountContext, message: Message, sourcePeerType: MediaAutoDownloadPeerType?, navigationController: NavigationController) {
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
                
                let pageController = InstantPageController(context: context, webPage: webpage, sourcePeerType: sourcePeerType ?? .channel, anchor: anchor)
                navigationController.pushViewController(pageController)
            }
            break
        }
    }
}

func openChatWallpaper(context: AccountContext, message: Message, present: @escaping (ViewController, Any?) -> Void) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            let _ = (context.sharedContext.resolveUrl(account: context.account, url: content.url)
            |> deliverOnMainQueue).start(next: { resolvedUrl in
                if case let .wallpaper(parameter) = resolvedUrl {
                    let source: WallpaperListSource
                    switch parameter {
                        case let .slug(slug, options, color, intensity):
                            source = .slug(slug, content.file, options, color, intensity, message)
                        case let .color(color):
                            source = .wallpaper(.color(Int32(color.rgb)), nil, nil, nil, message)
                    }
                    
                    let controller = WallpaperGalleryController(context: context, source: source)
                    present(controller, nil)
                }
            })
        }
    }
}

func openChatTheme(context: AccountContext, message: Message, present: @escaping (ViewController, Any?) -> Void) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            let _ = (context.sharedContext.resolveUrl(account: context.account, url: content.url)
            |> deliverOnMainQueue).start(next: { resolvedUrl in
                var file: TelegramMediaFile?
                let mimeType = "application/x-tgtheme-ios"
                if let contentFiles = content.files, let filteredFile = contentFiles.filter({ $0.mimeType == mimeType }).first {
                    file = filteredFile
                } else if let contentFile = content.file, contentFile.mimeType == mimeType {
                    file = contentFile
                }
                if case let .theme(slug) = resolvedUrl, let file = file {
                    if let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let theme = makePresentationTheme(data: data) {
                        let controller = ThemePreviewController(context: context, previewTheme: theme, source: .slug(slug, file))
                        present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                } else {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    present(textAlertController(context: context, title: nil, text: presentationData.strings.Theme_Unsupported, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            })
        }
    }
}
