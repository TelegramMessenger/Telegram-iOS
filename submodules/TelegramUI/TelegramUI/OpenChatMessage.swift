import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
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
import PresentationDataUtils
import ShareController
import UndoUI

private enum ChatMessageGalleryControllerData {
    case url(String)
    case pass(TelegramMediaFile)
    case instantPage(InstantPageGalleryController, Int, Media)
    case map(TelegramMediaMap)
    case stickerPack(StickerPackReference)
    case audio(TelegramMediaFile)
    case document(TelegramMediaFile, Bool)
    case gallery(Signal<GalleryController, NoError>)
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
                            return .gallery(.single(gallery))
                        }
                    }
                    
                    if ext == "mkv" {
                        return .document(file, true)
                    }
                }
                
                if internalDocumentItemSupportsMimeType(file.mimeType, fileName: file.fileName ?? "file") {
                    let gallery = GalleryController(context: context, source: .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                        navigationController?.replaceTopController(controller, animated: false, ready: ready)
                        }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                    return .gallery(.single(gallery))
                }
                
                if !file.isVideo {
                    return .document(file, false)
                }
            }
            
            if message.containsSecretMedia {
                let gallery = SecretMediaPreviewController(context: context, messageId: message.id)
                return .secretGallery(gallery)
            } else {
                let startTimecode: Signal<Double?, NoError>
                if let timecode = timecode {
                    startTimecode = .single(timecode)
                } else {
                    startTimecode = mediaPlaybackStoredState(postbox: context.account.postbox, messageId: message.id)
                    |> map { state in
                        return state?.timestamp
                    }
                }
                
                return .gallery(startTimecode
                |> deliverOnMainQueue
                |> map { timecode in
                    let gallery = GalleryController(context: context, source: standalone ? .standaloneMessage(message) : .peerMessagesAtId(message.id), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
                        navigationController?.replaceTopController(controller, animated: false, ready: ready)
                    }, baseNavigationController: navigationController, actionInteraction: actionInteraction)
                    gallery.temporaryDoNotWaitForReady = autoplayingVideo
                    return gallery
                })
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
                break
            case let .instantPage(gallery, centralIndex, galleryMedia):
                return .instantPage(gallery, centralIndex, galleryMedia)
            default:
                break
        }
    }
    return nil
}

func chatMediaListPreviewControllerData(context: AccountContext, message: Message, standalone: Bool, reverseMessageGalleryOrder: Bool, navigationController: NavigationController?) -> Signal<ChatMessagePreviewControllerData?, NoError> {
    if let mediaData = chatMessageGalleryControllerData(context: context, message: message, navigationController: navigationController, standalone: standalone, reverseMessageGalleryOrder: reverseMessageGalleryOrder, mode: .default, synchronousLoad: true, actionInteraction: nil) {
        switch mediaData {
            case let .gallery(gallery):
                return gallery
                |> map { gallery in
                    return .gallery(gallery)
                }
            case let .instantPage(gallery, centralIndex, galleryMedia):
                return .single(.instantPage(gallery, centralIndex, galleryMedia))
            default:
                break
        }
    }
    return .single(nil)
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
                    var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
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
                
//                let controllerParams = LocationViewParams(sendLiveLocation: { location in
//                    let outMessage: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: location), replyToMessageId: nil, localGroupingKey: nil)
//                    params.enqueueMessage(outMessage)
//                }, stopLiveLocation: {
//                    params.context.liveLocationManager?.cancelLiveLocation(peerId: params.message.id.peerId)
//                }, openUrl: params.openUrl, openPeer: { peer in
//                    params.openPeer(peer, .info)
//                })
//                let controller = LocationViewController(context: params.context, mapMedia: mapMedia, params: controllerParams)
                let controller = legacyLocationController(message: params.message, mapMedia: mapMedia, context: params.context, openPeer: { peer in
                    params.openPeer(peer, .info)
                }, sendLiveLocation: { coordinate, period in
                    let outMessage: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: period)), replyToMessageId: nil, localGroupingKey: nil)
                    params.enqueueMessage(outMessage)
                }, stopLiveLocation: {
                    params.context.liveLocationManager?.cancelLiveLocation(peerId: params.message.id.peerId)
                }, openUrl: params.openUrl)
                controller.navigationPresentation = .modal
                params.navigationController?.pushViewController(controller)
                return true
            case let .stickerPack(reference):
                let controller = StickerPackScreen(context: params.context, mainStickerPack: reference, stickerPacks: [reference], sendSticker: params.sendSticker, actionPerformed: { info, items, action in
                    let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                    var animateInAsReplacement = false
                    if let navigationController = params.navigationController {
                        for controller in navigationController.overlayControllers {
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitActionAndReplacementAnimation()
                                animateInAsReplacement = true
                            }
                        }
                    }
                    switch action {
                    case .add:
                        params.navigationController?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).0, undo: false, info: info, topItem: items.first, account: params.context.account), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { _ in
                            return true
                        }))
                    case let .remove(positionInList):
                        params.navigationController?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).0, undo: true, info: info, topItem: items.first, account: params.context.account), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { action in
                            if case .undo = action {
                                let _ = addStickerPackInteractively(postbox: params.context.account.postbox, info: info, items: items, positionInList: positionInList).start()
                            }
                            return true
                        }))
                    }
                })
                params.dismissInput()
                params.present(controller, nil)
                return true
            case let .document(file, immediateShare):
                let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                if immediateShare {
                    let controller = ShareController(context: params.context, subject: .media(.standalone(media: file)), immediateExternalShare: true)
                    params.present(controller, nil)
                } else if let rootController = params.navigationController?.view.window?.rootViewController {
                    if let fileName = file.fileName, fileName.hasSuffix(".svgbg") {
                        let controller = WallpaperGalleryController(context: params.context, source: .wallpaper(.file(id: 0, accessHash: 0, isCreator: false, isDefault: false, isPattern: true, isDark: false, slug: "", file: file, settings: WallpaperSettings()), nil, nil, nil, nil, nil, nil))
                        params.present(controller, nil)
                    } else {
                        presentDocumentPreviewController(rootController: rootController, theme: presentationData.theme, strings: presentationData.strings, postbox: params.context.account.postbox, file: file)
                    }
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
                let _ = (gallery
                |> deliverOnMainQueue).start(next: { gallery in
                    params.present(gallery, GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                        let selectedTransitionNode = params.transitionNode(messageId, media)
                        if let selectedTransitionNode = selectedTransitionNode {
                            return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                        }
                        return nil
                    }))
                })
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
                params.dismissInput()
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
                            contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName, lastName: contact.lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: contact.phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
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
                params.navigationController?.pushViewController(controller)
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
                        case let .slug(slug, options, firstColor, secondColor, intensity, rotation):
                            source = .slug(slug, content.file, options, firstColor, secondColor, intensity, rotation, message)
                        case let .color(color):
                            source = .wallpaper(.color(color.argb), nil, nil, nil, nil, nil, message)
                        case let .gradient(topColor, bottomColor, rotation):
                            source = .wallpaper(.gradient(topColor.argb, bottomColor.argb, WallpaperSettings(rotation: rotation)), nil, nil, nil, nil, rotation, message)
                    }
                    
                    let controller = WallpaperGalleryController(context: context, source: source)
                    present(controller, nil)
                }
            })
        }
    }
}

func openChatTheme(context: AccountContext, message: Message, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            let _ = (context.sharedContext.resolveUrl(account: context.account, url: content.url)
            |> deliverOnMainQueue).start(next: { resolvedUrl in
                var file: TelegramMediaFile?
                var settings: TelegramThemeSettings?
                let themeMimeType = "application/x-tgtheme-ios"
                
                for attribute in content.attributes {
                    if case let .theme(attribute) = attribute {
                        if let attributeSettings = attribute.settings {
                            settings = attributeSettings
                        } else if let filteredFile = attribute.files.filter({ $0.mimeType == themeMimeType }).first {
                            file = filteredFile
                        }
                    }
                }
                
                if file == nil && settings == nil, let contentFile = content.file, contentFile.mimeType == themeMimeType {
                    file = contentFile
                }
                let displayUnsupportedAlert: () -> Void = {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    present(textAlertController(context: context, title: nil, text: presentationData.strings.Theme_Unsupported, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
                if case let .theme(slug) = resolvedUrl {
                    if let file = file {
                        if let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                            if let theme = makePresentationTheme(data: data) {
                                let controller = ThemePreviewController(context: context, previewTheme: theme, source: .slug(slug, file))
                                pushController(controller)
                            } else {
                                displayUnsupportedAlert()
                            }
                        }
                    } else if let settings = settings {
                        if let theme = makePresentationTheme(settings: settings, title: content.title) {
                            let controller = ThemePreviewController(context: context, previewTheme: theme, source: .themeSettings(slug, settings))
                            pushController(controller)
                        } else {
                            displayUnsupportedAlert()
                        }
                    }
                } else {
                    displayUnsupportedAlert()
                }
            })
        }
    }
}
