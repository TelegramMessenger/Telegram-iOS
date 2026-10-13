import Foundation
import UIKit
import Display
import QuickLook
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import GalleryUI
import ContextUI
import LegacyComponents
import LegacyMediaPickerUI
import SaveToCameraRoll
import OverlayStatusController
import PresentationDataUtils
import AppBundle

public enum AvatarGalleryEntryId: Hashable {
    case topImage
    case image(EngineMedia.Id)
    case resource(String)
}

private final class AvatarGalleryContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let actionsOnTop: Bool
    
    init(sourceView: UIView, actionsOnTop: Bool = false) {
        self.sourceView = sourceView
        self.actionsOnTop = actionsOnTop
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.actionsOnTop ? .top : .bottom)
    }
}

/// The server photo an entry drawn from the peer record (`TelegramUser.photo`) shows, when the record
/// says which one it is.
private func avatarGalleryEntryPeerPhotoId(_ entry: AvatarGalleryEntry) -> Int64? {
    guard let entryRepresentation = largestImageRepresentation(entry.representations.map({ $0.representation })), let entryResource = entryRepresentation.resource as? CloudPeerPhotoSizeMediaResource else {
        return nil
    }
    return entryResource.photoId
}

private func avatarGalleryEntryMatchesImage(_ entry: AvatarGalleryEntry, _ image: TelegramMediaImage) -> Bool {
    guard let photoId = avatarGalleryEntryPeerPhotoId(entry) else {
        return false
    }
    return image.imageId.namespace == Namespaces.Media.CloudImage && image.imageId.id == photoId
}

private func avatarGalleryEntryWithVideoRepresentations(_ entry: AvatarGalleryEntry, videoRepresentations: [VideoRepresentationWithReference], immediateThumbnailData: Data?) -> AvatarGalleryEntry {
    switch entry {
    case let .topImage(representations, _, peer, indexData, _, category):
        return .topImage(representations, videoRepresentations, peer, indexData, immediateThumbnailData, category)
    default:
        return entry
    }
}

public func peerInfoProfilePhotos(context: AccountContext, peerId: EnginePeer.Id) -> Signal<Any, NoError> {
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> mapToSignal { peer -> Signal<[AvatarGalleryEntry]?, NoError> in
        guard let peer = peer else {
            return .single(nil)
        }
        return initialAvatarGalleryEntries(account: context.account, engine: context.engine, peer: peer)
    }
    |> distinctUntilChanged
    |> mapToSignal { entries -> Signal<(Bool, [AvatarGalleryEntry])?, NoError> in
        if let entries = entries {
            if var firstEntry = entries.first {
                return context.account.postbox.peerView(id: peerId)
                |> mapToSignal { peerView -> Signal<(Bool, [AvatarGalleryEntry])?, NoError>in
                    if let peer = peerViewMainPeer(peerView) {
                        var secondEntry: TelegramMediaImage?
                        var lastEntry: TelegramMediaImage?
                        if let cachedData = peerView.cachedData as? CachedUserData {
                            if let firstRepresentation = firstEntry.representations.first, firstRepresentation.representation.isPersonal {
                                if firstRepresentation.representation.hasVideo, case let .known(photo) = cachedData.personalPhoto, let peerReference = PeerReference(peer) {
                                    firstEntry = .topImage(firstEntry.representations, photo?.videoRepresentations.map { VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) } ?? [], firstEntry.peer, firstEntry.indexData, firstEntry.immediateThumbnailData, nil)
                                }
                                if case let .known(photo) = cachedData.photo {
                                    secondEntry = photo
                                }
                            }
                            if case let .known(photo) = cachedData.fallbackPhoto {
                                lastEntry = photo
                                if let photo, firstEntry.videoRepresentations.isEmpty, !photo.videoRepresentations.isEmpty, avatarGalleryEntryMatchesImage(firstEntry, photo), let peerReference = PeerReference(peer) {
                                    let videoRepresentations = photo.videoRepresentations.map {
                                        VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource))
                                    }
                                    firstEntry = avatarGalleryEntryWithVideoRepresentations(firstEntry, videoRepresentations: videoRepresentations, immediateThumbnailData: firstEntry.immediateThumbnailData ?? photo.immediateThumbnailData)
                                }
                            }
                        }
                        return fetchedAvatarGalleryEntries(engine: context.engine, account: context.account, peer: EnginePeer(peer), firstEntry: firstEntry, secondEntry: secondEntry, lastEntry: lastEntry)
                        |> map(Optional.init)
                    } else {
                        return .single(nil)
                    }
                }
            } else {
                return .single((true, []))
            }
        } else {
            return context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peerId)
            |> map { _ -> (Bool, [AvatarGalleryEntry])? in
                return nil
            }
        }
    }
    |> map { items -> Any in
        if let items = items {
            return items
        } else {
            return peerInfoProfilePhotos(context: context, peerId: peerId)
        }
    }
}

public func peerInfoProfilePhotosWithCache(context: AccountContext, peerId: EnginePeer.Id) -> Signal<(Bool, [AvatarGalleryEntry]), NoError> {
    return context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: context.account.postbox, network: context.account.network, peerId: peerId, fetch: peerInfoProfilePhotos(context: context, peerId: peerId))
    |> map { items -> (Bool, [AvatarGalleryEntry]) in
        return items as? (Bool, [AvatarGalleryEntry]) ?? (true, [])
    }
}

public enum AvatarGalleryEntry: Equatable {
    case topImage([ImageRepresentationWithReference], [VideoRepresentationWithReference], EnginePeer?, GalleryItemIndexData?, Data?, String?)
    case image(EngineMedia.Id, TelegramMediaImageReference?, [ImageRepresentationWithReference], [VideoRepresentationWithReference], EnginePeer?, Int32?, GalleryItemIndexData?, EngineMessage.Id?, Data?, String?, Bool, TelegramMediaImage.EmojiMarkup?)
    
    public init(representation: TelegramMediaImageRepresentation, peer: EnginePeer) {
        self = .topImage([ImageRepresentationWithReference(representation: representation, reference: MediaResourceReference.standalone(resource: representation.resource))], [], peer, nil, nil, nil)
    }
    
    public var id: AvatarGalleryEntryId {
        switch self {
        case let .topImage(representations, _, _, _, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.stringRepresentation)
            }
            return .topImage
        case let .image(id, _, representations, _, _, _, _, _, _, _, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.stringRepresentation)
            }
            return .image(id)
        }
    }
    
    public var peer: EnginePeer? {
        switch self {
            case let .topImage(_, _, peer, _, _, _):
                return peer
            case let .image(_, _, _, _, peer, _, _, _, _, _, _, _):
                return peer
        }
    }
    
    public var representations: [ImageRepresentationWithReference] {
        switch self {
            case let .topImage(representations, _, _, _, _, _):
                return representations
            case let .image(_, _, representations, _, _, _, _, _, _, _, _, _):
                return representations
        }
    }
    
    public var immediateThumbnailData: Data? {
        switch self {
            case let .topImage(_, _, _, _, immediateThumbnailData, _):
                return immediateThumbnailData
            case let .image(_, _, _, _, _, _, _, _, immediateThumbnailData, _, _, _):
                return immediateThumbnailData
        }
    }
    
    public var videoRepresentations: [VideoRepresentationWithReference] {
        switch self {
            case let .topImage(_, videoRepresentations, _, _, _, _):
                return videoRepresentations
            case let .image(_, _, _, videoRepresentations, _, _, _, _, _, _, _, _):
                return videoRepresentations
        }
    }
    
    public var emojiMarkup: TelegramMediaImage.EmojiMarkup? {
        switch self {
            case .topImage:
                return nil
            case let .image(_, _, _, _, _, _, _, _, _, _, _, markup):
                return markup
        }
    }
    
    public var indexData: GalleryItemIndexData? {
        switch self {
            case let .topImage(_, _, _, indexData, _, _):
                return indexData
            case let .image(_, _, _, _, _, _, indexData, _, _, _, _, _):
                return indexData
        }
    }
    
    public static func ==(lhs: AvatarGalleryEntry, rhs: AvatarGalleryEntry) -> Bool {
        switch lhs {
            case let .topImage(lhsRepresentations, lhsVideoRepresentations, lhsPeer, lhsIndexData, lhsImmediateThumbnailData, lhsCategory):
                if case let .topImage(rhsRepresentations, rhsVideoRepresentations, rhsPeer, rhsIndexData, rhsImmediateThumbnailData, rhsCategory) = rhs, lhsRepresentations == rhsRepresentations, lhsVideoRepresentations == rhsVideoRepresentations, lhsPeer == rhsPeer, lhsIndexData == rhsIndexData, lhsImmediateThumbnailData == rhsImmediateThumbnailData, lhsCategory == rhsCategory {
                    return true
                } else {
                    return false
                }
            case let .image(lhsId, lhsImageReference, lhsRepresentations, lhsVideoRepresentations, lhsPeer, lhsDate, lhsIndexData, lhsMessageId, lhsImmediateThumbnailData, lhsCategory, lhsIsFallback, lhsEmojiMarkup):
                if case let .image(rhsId, rhsImageReference, rhsRepresentations, rhsVideoRepresentations, rhsPeer, rhsDate, rhsIndexData, rhsMessageId, rhsImmediateThumbnailData, rhsCategory, rhsIsFallback, rhsEmojiMarkup) = rhs, lhsId == rhsId, lhsImageReference == rhsImageReference, lhsRepresentations == rhsRepresentations, lhsVideoRepresentations == rhsVideoRepresentations, lhsPeer == rhsPeer, lhsDate == rhsDate, lhsIndexData == rhsIndexData, lhsMessageId == rhsMessageId, lhsImmediateThumbnailData == rhsImmediateThumbnailData, lhsCategory == rhsCategory, lhsIsFallback == rhsIsFallback, lhsEmojiMarkup == rhsEmojiMarkup {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class AvatarGalleryControllerPresentationArguments {
    let animated: Bool
    let transitionArguments: (AvatarGalleryEntry) -> GalleryTransitionArguments?
    
    public init(animated: Bool = true, transitionArguments: @escaping (AvatarGalleryEntry) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

public func normalizeEntries(_ entries: [AvatarGalleryEntry]) -> [AvatarGalleryEntry] {
   var updatedEntries: [AvatarGalleryEntry] = []
   let count: Int32 = Int32(entries.count)
   var index: Int32 = 0
   for entry in entries {
       let indexData = GalleryItemIndexData(position: index, totalCount: count)
       if case let .topImage(representations, videoRepresentations, peer, _, immediateThumbnailData, category) = entry {
           updatedEntries.append(.topImage(representations, videoRepresentations, peer, indexData, immediateThumbnailData, category))
       } else if case let .image(id, reference, representations, videoRepresentations, peer, date, _, messageId, immediateThumbnailData, category, isFallback, emojiMarkup) = entry {
           updatedEntries.append(.image(id, reference, representations, videoRepresentations, peer, date, indexData, messageId, immediateThumbnailData, category, isFallback, emojiMarkup))
       }
       index += 1
   }
   return updatedEntries
}

public func initialAvatarGalleryEntries(account: Account, engine: TelegramEngine, peer: EnginePeer) -> Signal<[AvatarGalleryEntry]?, NoError> {
    var initialEntries: [AvatarGalleryEntry] = []
    if !peer.profileImageRepresentations.isEmpty, let peerReference = PeerReference(peer) {
        initialEntries.append(.topImage(peer.profileImageRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), [], peer, nil, nil, nil))
    }
    
    guard let peerReference = PeerReference(peer) else {
        return .single(initialEntries)
    }
    switch peer {
    case .channel, .legacyGroup:
        break
    default:
        return .single(initialEntries)
    }
    
    return engine.data.get(TelegramEngine.EngineData.Item.Peer.Photo(id: peer.id))
    |> map { peerPhoto in
        var initialPhoto: TelegramMediaImage?
        if case let .known(value) = peerPhoto {
            initialPhoto = value
        }
        
        if let photo = initialPhoto {
            var representations = photo.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) })
            if photo.immediateThumbnailData == nil, let firstEntry = initialEntries.first, let firstRepresentation = firstEntry.representations.first {
                representations.insert(firstRepresentation, at: 0)
            }
            return [.image(photo.imageId, photo.reference, representations, photo.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, nil, nil, nil, photo.immediateThumbnailData, nil, false, photo.emojiMarkup)]
        } else {
            if case .known = peerPhoto {
                return []
            } else {
                return nil
            }
        }
    }
}

/// Builds a user's gallery from the user's photo list (`photos.getUserPhotos`).
///
/// The first slot is the peer record's current photo, `firstEntry`: it is the circle the gallery
/// expands from, and it is labelled the main photo. The list keeps its order when an older photo is
/// made the main one again (`photos.updateProfilePhoto` with an existing photo): the server replaces
/// that photo in the list with a copy under a new id and makes the copy the current photo. So the
/// current photo is looked up in the list and moved to the front rather than assumed to be first.
/// Drawing it over whatever the list starts with showed it twice and hid that photo
/// (bugs.telegram.org/c/15276). A current photo the list is known not to contain (the list stops at
/// 100, or the record is stale) gets a slot of its own for the same reason.
///
/// A personal photo, one the viewer set for a contact, is never in the contact's list. It takes the
/// place of the contact's current public photo, `secondEntry`, which is moved to the front and shown
/// again right after it; when that photo is not known, the list's first photo stands in for it.
/// `secondEntry` is only read for a personal photo. `lastEntry` is the fallback photo.
public func avatarGalleryUserEntries(peer: EnginePeer, peerReference: PeerReference, photos: [TelegramPeerPhoto], firstEntry: AvatarGalleryEntry?, secondEntry: TelegramMediaImage?, lastEntry: TelegramMediaImage?) -> [AvatarGalleryEntry] {
    let isPersonal = firstEntry?.representations.first?.representation.isPersonal == true

    var photos = photos
    var firstEntryHasOwnSlot = false
    if isPersonal {
        if let secondEntry {
            if let index = photos.firstIndex(where: { $0.image.imageId == secondEntry.imageId }) {
                photos.insert(photos.remove(at: index), at: 0)
            } else {
                photos.insert(TelegramPeerPhoto(image: secondEntry, reference: secondEntry.reference, date: photos.first?.date ?? 0, index: 0, totalCount: 0, messageId: nil), at: 0)
            }
        }
        if let current = photos.first {
            photos.insert(current, at: 1)
        }
    } else if let firstEntry, avatarGalleryEntryPeerPhotoId(firstEntry) != nil {
        if let index = photos.firstIndex(where: { avatarGalleryEntryMatchesImage(firstEntry, $0.image) }) {
            photos.insert(photos.remove(at: index), at: 0)
        } else {
            firstEntryHasOwnSlot = true
        }
    }
    if let lastEntry {
        photos.append(TelegramPeerPhoto(image: lastEntry, reference: lastEntry.reference, date: 0, index: photos.count, totalCount: 0, messageId: nil))
    }

    var result: [AvatarGalleryEntry] = []
    if firstEntryHasOwnSlot, let firstEntry {
        result.append(firstEntry)
    }
    for photo in photos {
        if result.isEmpty, let first = firstEntry {
            var videoRepresentations: [VideoRepresentationWithReference] = first.videoRepresentations
            var emojiMarkup: TelegramMediaImage.EmojiMarkup? = first.emojiMarkup
            if videoRepresentations.isEmpty, !isPersonal {
                videoRepresentations = photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) })
            }
            if emojiMarkup == nil, !isPersonal {
                emojiMarkup = photo.image.emojiMarkup
            }

            result.append(.image(photo.image.imageId, photo.image.reference, first.representations, videoRepresentations, peer, isPersonal ? 0 : photo.date, nil, photo.messageId, first.immediateThumbnailData ?? photo.image.immediateThumbnailData, nil, false, emojiMarkup))
        } else {
            result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, nil, photo.messageId, photo.image.immediateThumbnailData, nil, photo.image.id == lastEntry?.id, photo.image.emojiMarkup))
        }
    }
    if result.isEmpty, let firstEntry {
        result.append(firstEntry)
    }
    return normalizeEntries(result)
}

/// `entries`, keeping for a photo that `shown` also contains the image it is shown with when that
/// image is on disk and the rebuilt one is not (`isOnDisk` tells whether an entry's largest image
/// is).
///
/// After a change of main photo the rebuilt list draws the previous main photo from its own sizes,
/// which were never needed while the account record was drawing it and so were never downloaded;
/// taking it as rebuilt reloaded a photo that is on screen and downloaded it again. The rebuilt image
/// is preferred otherwise: it is the one the profile header shows (which matches entries by value to
/// hide the one the gallery covers), and its reference stays valid, where the record's peer-photo
/// location of a photo that is no longer the current one may not.
///
/// A photo listed twice in either list (a personal photo's slot carries the id of the public photo
/// after it) is left as rebuilt, since there is no telling which image belongs to which slot.
public func avatarGalleryEntries(_ entries: [AvatarGalleryEntry], keepingImagesOf shown: [AvatarGalleryEntry], isOnDisk: (AvatarGalleryEntry) -> Bool) -> [AvatarGalleryEntry] {
    func imageId(_ entry: AvatarGalleryEntry) -> EngineMedia.Id? {
        if case let .image(id, _, _, _, _, _, _, _, _, _, _, _) = entry {
            return id
        } else {
            return nil
        }
    }
    var occurrences: [EngineMedia.Id: Int] = [:]
    for id in (entries + shown).compactMap(imageId) {
        occurrences[id, default: 0] += 1
    }
    var shownImages: [EngineMedia.Id: AvatarGalleryEntry] = [:]
    for entry in shown {
        if let id = imageId(entry), occurrences[id] == 2 {
            shownImages[id] = entry
        }
    }
    return entries.map { entry in
        guard case let .image(id, reference, _, _, peer, date, indexData, messageId, _, caption, isFallback, emojiMarkup) = entry, let shownEntry = shownImages[id], !isOnDisk(entry), isOnDisk(shownEntry) else {
            return entry
        }
        return .image(id, reference, shownEntry.representations, shownEntry.videoRepresentations, peer, date, indexData, messageId, shownEntry.immediateThumbnailData, caption, isFallback, emojiMarkup)
    }
}

public func fetchedAvatarGalleryEntries(engine: TelegramEngine, account: Account, peer: EnginePeer) -> Signal<[AvatarGalleryEntry], NoError> {
    return initialAvatarGalleryEntries(account: account, engine: engine, peer: peer)
    |> map { entries -> [AvatarGalleryEntry] in
        return entries ?? []
    }
    |> mapToSignal { initialEntries in
        return .single(initialEntries)
        |> then(
            engine.peers.requestPeerPhotos(peerId: peer.id)
            |> map { photos -> [AvatarGalleryEntry] in
                var result: [AvatarGalleryEntry] = []
                if photos.isEmpty {
                    result = initialEntries
                } else if let peerReference = PeerReference(peer) {
                    var index: Int32 = 0
                    if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peer.id.namespace) {
                        var initialMediaIds = Set<EngineMedia.Id>()
                        for entry in initialEntries {
                            if case let .image(mediaId, _, _, _, _, _, _, _, _, _, _, _) = entry {
                                initialMediaIds.insert(mediaId)
                            }
                        }
                        
                        var photosCount = photos.count
                        for i in 0 ..< photos.count {
                            let photo = photos[i]
                            if i == 0 && !initialMediaIds.contains(photo.image.imageId) {
                                photosCount += 1
                                for entry in initialEntries {
                                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                                    if case let .image(mediaId, imageReference, representations, videoRepresentations, peer, _, _, _, thumbnailData, _, _, emojiMarkup) = entry {
                                        result.append(.image(mediaId, imageReference, representations, videoRepresentations, peer, nil, indexData, nil, thumbnailData, nil, false, emojiMarkup))
                                        index += 1
                                    }
                                }
                            }
                            
                            let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                            result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil, false, photo.image.emojiMarkup))
                            index += 1
                        }
                    } else {
                        result = avatarGalleryUserEntries(peer: peer, peerReference: peerReference, photos: photos, firstEntry: initialEntries.first, secondEntry: nil, lastEntry: nil)
                    }
                }
                return result
            }
        )
    }
}

public func fetchedAvatarGalleryEntries(engine: TelegramEngine, account: Account, peer: EnginePeer, firstEntry: AvatarGalleryEntry, secondEntry: TelegramMediaImage?, lastEntry: TelegramMediaImage?) -> Signal<(Bool, [AvatarGalleryEntry]), NoError> {
    let initialEntries = [firstEntry]
    return Signal<(Bool, [AvatarGalleryEntry]), NoError>.single((false, initialEntries))
    |> then(
        engine.peers.requestPeerPhotos(peerId: peer.id)
        |> map { photos -> (Bool, [AvatarGalleryEntry]) in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = [firstEntry]
            if photos.isEmpty {
                result = initialEntries
                if let lastEntry, let firstEntry = result.first, firstEntry.videoRepresentations.isEmpty, !lastEntry.videoRepresentations.isEmpty, avatarGalleryEntryMatchesImage(firstEntry, lastEntry), let peerReference = PeerReference(peer) {
                    let videoRepresentations = lastEntry.videoRepresentations.map {
                        VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource))
                    }
                    result[0] = avatarGalleryEntryWithVideoRepresentations(firstEntry, videoRepresentations: videoRepresentations, immediateThumbnailData: firstEntry.immediateThumbnailData ?? lastEntry.immediateThumbnailData)
                }
            } else if let peerReference = PeerReference(peer) {
                var index: Int32 = 0
                
                if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peer.id.namespace) {
                    var initialMediaIds = Set<EngineMedia.Id>()
                    for entry in initialEntries {
                        if case let .image(mediaId, _, _, _, _, _, _, _, _, _, _, _) = entry {
                            initialMediaIds.insert(mediaId)
                        }
                    }
                    
                    var photosCount = photos.count
                    for i in 0 ..< photos.count {
                        let photo = photos[i]
                        var representations = photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) })
                        if i == 0 {
                            if !initialMediaIds.contains(photo.image.imageId) {
                                photosCount += 1
                                for entry in initialEntries {
                                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                                    if case let .image(mediaId, imageReference, representations, videoRepresentations, peer, _, _, _, thumbnailData, _, _, emojiMarkup) = entry {
                                        result.append(.image(mediaId, imageReference, representations, videoRepresentations, peer, nil, indexData, nil, thumbnailData, nil, false, emojiMarkup))
                                        index += 1
                                    }
                                }
                            } else if photo.image.immediateThumbnailData == nil, let firstEntry = initialEntries.first, let firstRepresentation = firstEntry.representations.first {
                                representations.insert(firstRepresentation, at: 0)
                            }
                        }
                        
                        let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                        result.append(.image(photo.image.imageId, photo.image.reference, representations, photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil, false, photo.image.emojiMarkup))
                        index += 1
                    }
                } else {
                    result = avatarGalleryUserEntries(peer: peer, peerReference: peerReference, photos: photos, firstEntry: firstEntry, secondEntry: secondEntry, lastEntry: lastEntry)
                }
            }
            return (true, result)
        }
    )
}

public class AvatarGalleryController: ViewController, StandalonePresentableController {
    public enum SourceCorners {
        case none
        case round
        case roundRect(CGFloat)
    }
    
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let peer: EnginePeer
    private let sourceCorners: SourceCorners
    private let isSuggested: Bool
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    private let animatedIn = ValuePromise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private var adjustedForInitialPreviewingLayout = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [AvatarGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleContent = Promise<GalleryTitleView.Content?>()
    private let centralItemRightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    public var openAvatarSetup: ((@escaping () -> Void) -> Void)?
    
    public var removedEntry: ((AvatarGalleryEntry) -> Void)?
    
    private let _hiddenMedia = Promise<AvatarGalleryEntry?>(nil)
    public var hiddenMedia: Signal<AvatarGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let titleView: GalleryTitleView
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    
    private let editDisposable = MetaDisposable ()
    private let rebuiltEntriesDisposable = MetaDisposable()
    private var localEntriesChangeCount = 0

    public init(context: AccountContext, peer: EnginePeer, sourceCorners: SourceCorners = .round, remoteEntries: Promise<[AvatarGalleryEntry]>? = nil, isSuggested: Bool = false, skipInitial: Bool = false, centralEntryIndex: Int? = nil, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, synchronousLoad: Bool = false) {
        self.context = context
        self.peer = peer
        self.sourceCorners = sourceCorners
        self.isSuggested = isSuggested
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.replaceRootController = replaceRootController
        
        self.centralEntryIndex = centralEntryIndex
        
        self.titleView = GalleryTitleView(context: context, presentationData: self.presentationData)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.navigationItem.titleView = self.titleView
        
        self.statusBar.statusBarStyle = .White
        
        let remoteEntriesSignal: Signal<[AvatarGalleryEntry], NoError>
        if let remoteEntries = remoteEntries {
            remoteEntriesSignal = remoteEntries.get()
        } else {
            remoteEntriesSignal = fetchedAvatarGalleryEntries(engine: context.engine, account: context.account, peer: peer)
        }
        
        let initialSignal = initialAvatarGalleryEntries(account: context.account, engine: context.engine, peer: peer)
        |> map { entries -> [AvatarGalleryEntry] in
            return entries ?? []
        }
        
        let entriesSignal: Signal<[AvatarGalleryEntry], NoError> = skipInitial ? remoteEntriesSignal : (initialSignal |> then(remoteEntriesSignal))
        
        let presentationData = self.presentationData
        
        let semaphore: DispatchSemaphore?
        if synchronousLoad {
            semaphore = DispatchSemaphore(value: 0)
        } else {
            semaphore = nil
        }
        
        let syncResult = Atomic<(Bool, (() -> Void)?)>(value: (false, nil))
        
        self.disposable.set(combineLatest(entriesSignal, self.animatedIn.get()).start(next: { [weak self] entries, animatedIn in
            let f: () -> Void = {
                if let strongSelf = self, animatedIn {
                    let isFirstTime = strongSelf.entries.isEmpty
                    
                    var entries = entries
                    if !isFirstTime, let updated = entries.first, case let .image(mediaId, imageReference, _, videoRepresentations, peer, index, indexData, messageId, thumbnailData, caption, _, emojiMarkup) = updated, !videoRepresentations.isEmpty, let previous = strongSelf.entries.first, case let .topImage(representations, _, _, _, _, _) = previous {
                        let firstEntry = AvatarGalleryEntry.image(mediaId, imageReference, representations, videoRepresentations, peer, index, indexData, messageId, thumbnailData, caption, false, emojiMarkup)
                        entries.remove(at: 0)
                        entries.insert(firstEntry, at: 0)
                    }
                    
                    strongSelf.entries = entries
                    if strongSelf.centralEntryIndex == nil {
                        strongSelf.centralEntryIndex = 0
                    }
                    
                    if strongSelf.isSuggested, let firstEntry = entries.first {
                        strongSelf.navigationItem.title = !firstEntry.videoRepresentations.isEmpty ? strongSelf.presentationData.strings.Conversation_SuggestedVideoTitle : strongSelf.presentationData.strings.Conversation_SuggestedPhotoTitle
                    }
                    
                    if strongSelf.isViewLoaded {
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ entry in PeerAvatarImageGalleryItem(context: context, peer: peer, presentationData: presentationData, entry: entry, sourceCorners: sourceCorners, delete: strongSelf.canDelete ? { [weak self] sourceView in
                            self?.presentDeleteEntryConfirmation(entry, sourceView: sourceView, gesture: nil)
                            } : nil, setMain: { [weak self] in
                                self?.setMainEntry(entry)
                            }, edit: { [weak self] sourceView, gesture in
                                self?.editEntry(entry, sourceView: sourceView, gesture: gesture)
                        })
                        }), centralItemIndex: strongSelf.centralEntryIndex, synchronous: !isFirstTime)
                        
                        let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                            strongSelf?.didSetReady = true
                        }
                        strongSelf._ready.set(ready |> map { true })
                    }
                }
            }
            
            var process = false
            let _ = syncResult.modify { processed, _ in
                if !processed {
                    return (processed, f)
                }
                process = true
                return (true, nil)
            }
            semaphore?.signal()
            if process {
                Queue.mainQueue().async {
                    f()
                }
            }
        }))
        
        if let semaphore = semaphore {
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0)
        }
        
        var syncResultApply: (() -> Void)?
        let _ = syncResult.modify { processed, f in
            syncResultApply = f
            return (true, nil)
        }
        
        syncResultApply?()
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            if let strongSelf = self {
                strongSelf.navigationItem.setTitle(title, animated: strongSelf.navigationItem.title?.isEmpty ?? true)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleContent.get().start(next: { [weak self] titleContent in
            self?.titleView.setContent(content: titleContent)
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemRightBarButtonItems.get().start(next: { [weak self] rightBarButtonItems in
            self?.navigationItem.rightBarButtonItems = rightBarButtonItems
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
        self.editDisposable.dispose()
        self.rebuiltEntriesDisposable.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismissImmediately() {
        self._hiddenMedia.set(.single(nil))
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    private func dismiss(forceAway: Bool) {
        self.animatedIn.set(false)
        
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                var sourceHasRoundCorners = false
                if case .round = self.sourceCorners {
                    sourceHasRoundCorners = true
                }
                if (centralItemNode.index == 0 || !sourceHasRoundCorners), let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, pushController: { _ in
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        }, editMedia: { _ in
        }, controller: { [weak self] in
            return self
        }, currentItemNode: { [weak self] in
            return self?.galleryNode.pager.centralItemNode()
        })
        self.displayNode = GalleryControllerNode(context: self.context, controllerInteraction: controllerInteraction, titleView: self.titleView)
        self.displayNodeDidLoad()
        
        self.galleryNode.pager.updateOnReplacement = true
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        self.galleryNode.animateAlpha = false
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                    var sourceHasRoundCorners = false
                    if case .round = strongSelf.sourceCorners {
                        sourceHasRoundCorners = true
                    }
                    if centralItemNode.index != 0 && sourceHasRoundCorners {
                        return nil
                    }
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let presentationData = self.presentationData
        self.galleryNode.pager.replaceItems(self.entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] sourceView in
            self?.presentDeleteEntryConfirmation(entry, sourceView: sourceView, gesture: nil)
        } : nil, setMain: { [weak self] in
            self?.setMainEntry(entry)
        }, edit: { [weak self] sourceView, gesture in
            self?.editEntry(entry, sourceView: sourceView, gesture: gesture)
        }) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: AvatarGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleContent.set(node.titleContent())
                        strongSelf.centralItemRightBarButtonItems.set(node.rightBarButtonItems())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleContent.set(centralItemNode.titleContent())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                if presentationArguments.animated {
                    self.animatedIn.set(false)
                    centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        self.animatedIn.set(true)
                    })
                }
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        if !self.isPresentedInPreviewingContext() {
            self.galleryNode.setControlsHidden(false, animated: false)
            if let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                if presentationArguments.animated {
                    self.galleryNode.animateIn(animateContent: !nodeAnimatesItself, useSimpleAnimation: false)
                }
            }
        }
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
            return itemSize.aspectFitted(layout.size)
        } else {
            return nil
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if !self.adjustedForInitialPreviewingLayout && self.isPresentedInPreviewingContext() {
            self.adjustedForInitialPreviewingLayout = true
            self.galleryNode.setControlsHidden(true, animated: false)
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
                self.preferredContentSize = itemSize.aspectFitted(self.view.bounds.size)
                self.containerLayoutUpdated(ContainerViewLayout(size: self.preferredContentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(),  statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false), transition: .immediate)
                centralItemNode.activateAsInitial()
            }
        }
    }
    
    private var canDelete: Bool {
        let canDelete: Bool
        if self.peer.id == self.context.account.peerId {
            canDelete = true
        } else if case let .legacyGroup(group) = self.peer {
            switch group.role {
                case .creator, .admin:
                    canDelete = true
                case .member:
                    canDelete = false
            }
        } else if case let .channel(channel) = self.peer {
            canDelete = channel.hasPermission(.changeInfo)
        } else {
            canDelete = false
        }
        return canDelete
    }
    
    private func replaceEntries(_ entries: [AvatarGalleryEntry], centralItemIndex: Int = 0) {
        self.galleryNode.currentThumbnailContainerNode?.updateSynchronously = true
        self.galleryNode.pager.replaceItems(entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: self.peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] sourceView in
            self?.presentDeleteEntryConfirmation(entry, sourceView: sourceView, gesture: nil)
        } : nil, setMain: { [weak self] in
            self?.setMainEntry(entry)
        }, edit: { [weak self] sourceView, gesture in
            self?.editEntry(entry, sourceView: sourceView, gesture: gesture)
        }) }), centralItemIndex: centralItemIndex, synchronous: true)
        self.entries = entries
        self.galleryNode.currentThumbnailContainerNode?.updateSynchronously = false
    }

    /// Starts a local change of the entries (a new main photo, a removal), which supersedes any
    /// earlier one still waiting for its result or its rebuilt list: applied late, those would undo it.
    private func beginLocalEntriesChange() -> Int {
        self.localEntriesChangeCount += 1
        self.rebuiltEntriesDisposable.set(nil)
        return self.localEntriesChangeCount
    }

    /// Takes the account's rebuilt photo list once it starts with the new main photo, so the gallery
    /// shows the order the profile header and every later gallery will (`avatarGalleryUserEntries`).
    /// The gallery's own entries cannot produce it: they are no longer in the server's order once a
    /// photo has been moved to the front. The photo on screen stays on screen, and photos keep the
    /// images they are shown with where the rebuilt ones are not on disk
    /// (`avatarGalleryEntries(_:keepingImagesOf:isOnDisk:)`). A list that never starts with the new
    /// photo is not waited for past a few seconds: taken later, it would replace the gallery at an
    /// arbitrary moment.
    private func adoptRebuiltEntries(mainPhotoId: EngineMedia.Id) {
        self.rebuiltEntriesDisposable.set((peerInfoProfilePhotosWithCache(context: self.context, peerId: self.peer.id)
        |> filter { complete, entries in
            guard complete, let first = entries.first, case let .image(id, _, _, _, _, _, _, _, _, _, _, _) = first else {
                return false
            }
            return id == mainPhotoId
        }
        |> take(1)
        |> timeout(10.0, queue: Queue.mainQueue(), alternate: .complete())
        |> deliverOnMainQueue).start(next: { [weak self] _, entries in
            guard let self else {
                return
            }
            let resources = self.context.engine.resources
            let entries = normalizeEntries(avatarGalleryEntries(entries, keepingImagesOf: self.entries, isOnDisk: { entry in
                guard let representation = largestImageRepresentation(entry.representations.map({ $0.representation })) else {
                    return false
                }
                return resources.completedResourcePath(id: EngineMediaResource.Id(representation.resource.id)) != nil
            }))

            var centralItemIndex = 0
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), centralItemNode.index < self.entries.count, case let .image(centralId, _, _, _, _, _, _, _, _, _, _, _) = self.entries[centralItemNode.index] {
                if let index = entries.firstIndex(where: { entry in
                    if case let .image(id, _, _, _, _, _, _, _, _, _, _, _) = entry {
                        return id == centralId
                    } else {
                        return false
                    }
                }) {
                    centralItemIndex = index
                }
            }
            self.replaceEntries(entries, centralItemIndex: centralItemIndex)
            if let firstEntry = self.entries.first {
                self._hiddenMedia.set(.single(firstEntry))
            }
        }))
    }

    private func setMainEntry(_ rawEntry: AvatarGalleryEntry) {
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }

        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                } else {
                }
            case let .image(_, reference, _, _, _, _, _, _, _, _, _, _):
            if self.peer.id == self.context.account.peerId, let peerReference = PeerReference(self.peer) {
                    let changeCount = self.beginLocalEntriesChange()
                    if let reference = reference {
                        let _ = (self.context.engine.accountData.updatePeerPhotoExisting(reference: reference, representations: entry.representations.map({ $0.representation }), videoRepresentations: entry.videoRepresentations.map({ $0.representation }))
                        |> deliverOnMainQueue).start(next: { [weak self] photo in
                            if let strongSelf = self, strongSelf.localEntriesChangeCount == changeCount, let photo = photo, let firstEntry = strongSelf.entries.first, case let .image(_, _, _, _, _, index, indexData, messageId, _, caption, _, emojiMarkup) = firstEntry {
                                let updatedEntry = AvatarGalleryEntry.image(photo.imageId, photo.reference, photo.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), photo.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), strongSelf.peer, index, indexData, messageId, photo.immediateThumbnailData, caption, false, emojiMarkup)

                                var entries = strongSelf.entries
                                entries.remove(at: 0)
                                entries.insert(updatedEntry, at: 0)
                                strongSelf.replaceEntries(normalizeEntries(entries))
                                if let firstEntry = strongSelf.entries.first {
                                    strongSelf._hiddenMedia.set(.single(firstEntry))
                                }
                                strongSelf.adoptRebuiltEntries(mainPhotoId: photo.imageId)
                            }
                        })
                    }

                    if let index = self.entries.firstIndex(of: entry) {
                        // Only a first guess at the new order: it is right while the gallery is in
                        // the server's order, which an earlier change here may have undone. The
                        // rebuilt list replaces it once the change is applied.
                        var entries = self.entries
                        entries.remove(at: index)
                        // A slot without a photo stands for a current photo the list does not
                        // contain. Once another photo is the main one it stands for nothing this
                        // gallery can act on (Remove on it resolves to the first entry, which would
                        // now be the new main photo), and the rebuilt list does not have it either.
                        entries.removeAll(where: { entry in
                            if case .topImage = entry {
                                return true
                            } else {
                                return false
                            }
                        })
                        entries.insert(entry, at: 0)

                        self.replaceEntries(normalizeEntries(entries))
                        if let firstEntry = self.entries.first {
                            self._hiddenMedia.set(.single(firstEntry))
                        }
                    }
                }
        }
    }
    
    private func editEntry(_ rawEntry: AvatarGalleryEntry, sourceView rawSourceView: UIView, gesture: ContextGesture?) {
        let presentationData = self.presentationData
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Settings_SetNewProfilePhotoOrVideo, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, _ in
            c?.dismiss(completion: { [weak self] in
                self?.openAvatarSetup?({ [weak self] in
                    self?.dismissImmediately()
                })
            })
        })))

        var isFallback = false
        if case let .image(_, _, _, _, _, _, _, _, _, _, isFallbackValue, _) = rawEntry {
            isFallback = isFallbackValue
        }

        if self.peer.id == self.context.account.peerId, let position = rawEntry.indexData?.position, position > 0 || isFallback {
            let title: String
            if let _ = rawEntry.videoRepresentations.last {
                title = presentationData.strings.ProfilePhoto_SetMainVideo
            } else {
                title = presentationData.strings.ProfilePhoto_SetMainPhoto
            }
            items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: { [weak self] in
                    self?.setMainEntry(rawEntry)
                })
            })))
        }
        
        let deleteTitle: String
        if let _ = rawEntry.videoRepresentations.last {
            deleteTitle = presentationData.strings.Settings_RemoveVideo
        } else {
            deleteTitle = presentationData.strings.GroupInfo_SetGroupPhotoDelete
        }
        items.append(.action(ContextMenuActionItem(text: deleteTitle, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
        }, action: { [weak self] c, _ in
            guard let self, let c else {
                return
            }
            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: presentationData.strings.Settings_RemoveConfirmation, textColor: .destructive, icon: { _ in
                    return nil
                }, action: { [weak self] c, _ in
                    if let c {
                        c.dismiss(completion: { [weak self] in
                            self?.performDeleteEntry(rawEntry)
                        })
                    } else {
                        self?.performDeleteEntry(rawEntry)
                    }
                }))
            ]
            c.pushItems(items: .single(ContextController.Items(content: .list(items))))
        })))

        self.view.endEditing(true)

        let sourceView = self.navigationBar?.navigationButtonContextContainer(sourceView: rawSourceView) ?? rawSourceView
        let contextController = makeContextController(
            presentationData: presentationData.withUpdated(theme: defaultDarkColorPresentationTheme),
            source: .reference(AvatarGalleryContextReferenceContentSource(sourceView: sourceView)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: gesture
        )
        self.presentInGlobalOverlay(contextController)
    }

    private func presentDeleteEntryConfirmation(_ rawEntry: AvatarGalleryEntry, sourceView: UIView, gesture: ContextGesture?) {
        self.view.endEditing(true)
        
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: self.presentationData.strings.Settings_RemoveConfirmation, textColor: .destructive, icon: { _ in
                return nil
            }, action: { [weak self] c, _ in
                if let c {
                    c.dismiss(completion: { [weak self] in
                        self?.performDeleteEntry(rawEntry)
                    })
                } else {
                    self?.performDeleteEntry(rawEntry)
                }
            }))
        ]
        
        let contextController = makeContextController(
            presentationData: self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme),
            source: .reference(AvatarGalleryContextReferenceContentSource(sourceView: sourceView, actionsOnTop: true)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: gesture
        )
        self.presentInGlobalOverlay(contextController)
    }

    private func performDeleteEntry(_ rawEntry: AvatarGalleryEntry) {
        let _ = self.beginLocalEntriesChange()
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }

        self.removedEntry?(rawEntry)

        var focusOnItem: Int?
        var updatedEntries = self.entries
        var replaceItems = false
        var dismiss = false

        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                    // A top image carries no photo reference, so it can only be removed as "the
                    // current profile photo". Without this, deleting is a silent no-op whenever
                    // the photo list has not been fetched yet and the only entry is the one
                    // derived from the peer record.
                    let _ = self.context.engine.accountData.removeAccountPhoto(reference: nil).start()
                    dismiss = true
                } else {
                    if entry == self.entries.first {
                        let _ = self.context.engine.peers.updatePeerPhoto(peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        dismiss = true
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
                        }
                    }
                }
            case let .image(_, reference, _, _, _, _, _, messageId, _, _, isFallback, _):
                if self.peer.id == self.context.account.peerId {
                    if isFallback {
                        let _ = self.context.engine.accountData.updateFallbackPhoto(resource: nil, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                    } else if let reference = reference {
                        let _ = self.context.engine.accountData.removeAccountPhoto(reference: reference).start()
                    }

                    if entry == self.entries.first {
                        dismiss = true
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            replaceItems = true
                            updatedEntries.remove(at: index)
                            focusOnItem = index - 1
                        }
                    }
                } else {
                    if let messageId = messageId {
                        let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: [messageId], type: .forEveryone).start()
                    }

                    if entry == self.entries.first {
                        let _ = self.context.engine.peers.updatePeerPhoto(peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        dismiss = true
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            replaceItems = true
                            updatedEntries.remove(at: index)
                            focusOnItem = index - 1
                        }
                    }
                }
        }
        
        if replaceItems {
            updatedEntries = normalizeEntries(updatedEntries)
            self.galleryNode.pager.replaceItems(updatedEntries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: self.peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] sourceView in
                self?.presentDeleteEntryConfirmation(entry, sourceView: sourceView, gesture: nil)
            } : nil, setMain: { [weak self] in
                self?.setMainEntry(entry)
            }, edit: { [weak self] sourceView, gesture in
                self?.editEntry(entry, sourceView: sourceView, gesture: gesture)
            }) }), centralItemIndex: focusOnItem, synchronous: true)
            self.entries = updatedEntries
        }
        if dismiss {
            self._hiddenMedia.set(.single(nil))
            Queue.mainQueue().after(0.2) {
                self.dismiss(forceAway: true)
            }
        } else {
            if let firstEntry = self.entries.first {
                self._hiddenMedia.set(.single(firstEntry))
            }
        }
    }
}
