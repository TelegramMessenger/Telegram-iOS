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
import InstantPageUI
import PeerAvatarGalleryUI
import GalleryUI
import MediaResources
import WebsiteType

public enum ChatMessageGalleryControllerData {
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

private func instantPageBlockMedia(pageId: MediaId, block: InstantPageBlock, media: [MediaId: Media], counter: inout Int) -> [InstantPageGalleryEntry] {
    switch block {
        case let .image(id, caption, _, _):
            if let m = media[id] {
                let result = [InstantPageGalleryEntry(index: Int32(counter), pageId: pageId, media: InstantPageMedia(index: counter, media: m, url: nil, caption: caption.text, credit: caption.credit), caption: caption.text, credit: caption.credit, location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0))]
                counter += 1
                return result
            }
        case let .video(id, caption, _, _):
            if let m = media[id] {
                let result = [InstantPageGalleryEntry(index: Int32(counter), pageId: pageId, media: InstantPageMedia(index: counter, media: m, url: nil, caption: caption.text, credit: caption.credit), caption: caption.text, credit: caption.credit, location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0))]
                counter += 1
                return result
            }
        case let .collage(items, _):
            var result: [InstantPageGalleryEntry] = []
            for item in items {
                result.append(contentsOf: instantPageBlockMedia(pageId: pageId, block: item, media: media, counter: &counter))
            }
            return result
        case let .slideshow(items, _):
            var result: [InstantPageGalleryEntry] = []
            for item in items {
                result.append(contentsOf: instantPageBlockMedia(pageId: pageId, block: item, media: media, counter: &counter))
            }
            return result
        default:
            break
    }
    return []
}

public func instantPageGalleryMedia(webpageId: MediaId, page: InstantPage, galleryMedia: Media) -> [InstantPageGalleryEntry] {
    var result: [InstantPageGalleryEntry] = []
    var counter: Int = 0
    
    for block in page.blocks {
        result.append(contentsOf: instantPageBlockMedia(pageId: webpageId, block: block, media: page.media, counter: &counter))
    }
    
    var found = false
    for item in result {
        if item.media.media.id == galleryMedia.id {
            found = true
            break
        }
    }
    
    if !found {
        result.insert(InstantPageGalleryEntry(index: Int32(counter), pageId: webpageId, media: InstantPageMedia(index: counter, media: galleryMedia, url: nil, caption: nil, credit: nil), caption: nil, credit: nil, location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0)), at: 0)
    }
    
    for i in 0 ..< result.count {
        let item = result[i]
        result[i] = InstantPageGalleryEntry(index: Int32(i), pageId: item.pageId, media: item.media, caption: item.caption, credit: item.credit, location: InstantPageGalleryEntryLocation(position: Int32(i), totalCount: Int32(result.count)))
    }
    return result
}

public func chatMessageGalleryControllerData(context: AccountContext, chatLocation: ChatLocation?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?, message: Message, navigationController: NavigationController?, standalone: Bool, reverseMessageGalleryOrder: Bool, mode: ChatControllerInteractionOpenMessageMode, source: GalleryControllerItemSource?, synchronousLoad: Bool, actionInteraction: GalleryControllerActionInteraction?) -> ChatMessageGalleryControllerData? {
    var standalone = standalone
    if message.id.peerId.namespace == Namespaces.Peer.CloudUser && message.id.namespace != Namespaces.Message.Cloud {
        standalone = true
    }
    
    var galleryMedia: Media?
    var otherMedia: Media?
    var instantPageMedia: (TelegramMediaWebpage, [InstantPageGalleryEntry])?
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            switch action.action {
            case let .photoUpdated(image):
                if let peer = messageMainPeer(EngineMessage(message)), let image = image {
                    let promise: Promise<[AvatarGalleryEntry]> = Promise([AvatarGalleryEntry.image(image.imageId, image.reference, image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: .media(media: .message(message: MessageReference(message), media: media), resource: $0.resource)) }), image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: .media(media: .message(message: MessageReference(message), media: media), resource: $0.resource)) }), peer._asPeer(), message.timestamp, nil, message.id, image.immediateThumbnailData, "action")])
                    let galleryController = AvatarGalleryController(context: context, peer: peer._asPeer(), sourceCorners: .roundRect(15.5), remoteEntries: promise, skipInitial: true, replaceRootController: { controller, ready in
                        
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
                if case .link = mode, !["video"].contains(content.type) {
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
                    }
                    /*if ext == "mkv" {
                        return .document(file, true)
                    }*/
                }
                
                if internalDocumentItemSupportsMimeType(file.mimeType, fileName: file.fileName ?? "file") {
                    let gallery = GalleryController(context: context, source: source ?? .peerMessagesAtId(messageId: message.id, chatLocation: chatLocation ?? .peer(id: message.id.peerId), chatLocationContextHolder: chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: timecode, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
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
                let startState: Signal<(timecode: Double?, rate: Double), NoError>
                if let timecode = timecode {
                    startState = .single((timecode: timecode, rate: 1.0))
                } else {
                    startState = mediaPlaybackStoredState(engine: context.engine, messageId: message.id)
                    |> map { state in
                        return (state?.timestamp, state?.playbackRate.doubleValue ?? 1.0)
                    }
                }
                
                return .gallery(startState
                |> deliverOnMainQueue
                |> map { startState in
                    let gallery = GalleryController(context: context, source: source ?? (standalone ? .standaloneMessage(message) : .peerMessagesAtId(messageId: message.id, chatLocation: chatLocation ?? .peer(id: message.id.peerId), chatLocationContextHolder: chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil))), invertItemOrder: reverseMessageGalleryOrder, streamSingleVideo: stream, fromPlayingVideo: autoplayingVideo, landscape: landscape, timecode: startState.timecode, playbackRate: startState.rate, synchronousLoad: synchronousLoad, replaceRootController: { [weak navigationController] controller, ready in
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

public enum ChatMessagePreviewControllerData {
    case instantPage(InstantPageGalleryController, Int, Media)
    case gallery(GalleryController)
}

public func chatMessagePreviewControllerData(context: AccountContext, chatLocation: ChatLocation?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?, message: Message, standalone: Bool, reverseMessageGalleryOrder: Bool, navigationController: NavigationController?) -> ChatMessagePreviewControllerData? {
    if let mediaData = chatMessageGalleryControllerData(context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, message: message, navigationController: navigationController, standalone: standalone, reverseMessageGalleryOrder: reverseMessageGalleryOrder, mode: .default, source: nil, synchronousLoad: true, actionInteraction: nil) {
        switch mediaData {
            case .gallery:
                break
            case let .instantPage(gallery, centralIndex, galleryMedia):
                return .instantPage(gallery, centralIndex, galleryMedia)
            default:
                break
        }
    }
    return nil
}

public func chatMediaListPreviewControllerData(context: AccountContext, chatLocation: ChatLocation?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?, message: Message, standalone: Bool, reverseMessageGalleryOrder: Bool, navigationController: NavigationController?) -> Signal<ChatMessagePreviewControllerData?, NoError> {
    if let mediaData = chatMessageGalleryControllerData(context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, message: message, navigationController: navigationController, standalone: standalone, reverseMessageGalleryOrder: reverseMessageGalleryOrder, mode: .default, source: nil, synchronousLoad: true, actionInteraction: nil) {
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
