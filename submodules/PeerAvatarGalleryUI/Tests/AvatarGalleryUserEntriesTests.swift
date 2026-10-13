import XCTest
import TelegramCore
import PeerAvatarGalleryUI

/// A user's avatar gallery draws its first slot from the peer record's current photo and pairs it
/// with one photo of the user's photo list. Each list photo has to appear exactly once, with the
/// current one first.
final class AvatarGalleryUserEntriesTests: XCTestCase {
    private let a = makePhoto(id: 101)
    private let b = makePhoto(id: 102)
    private let c = makePhoto(id: 103)

    // bugs.telegram.org/c/15276: after "Set as Main Photo" on the second photo the server still
    // lists [A, B, C] while the current photo is B. The first slot showed B under A's id and A was
    // gone from the gallery.
    func testOlderPhotoMadeMainIsShownFirstAndOnce() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 102))

        XCTAssertEqual(entries.map(\.shownPhotoId), [102, 101, 103])
        XCTAssertEqual(entries.map(\.mediaPhotoId), [102, 101, 103])
    }

    func testLastPhotoMadeMainMovesToTheFrontAndTheRestKeepTheirOrder() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 103))

        XCTAssertEqual(entries.map(\.shownPhotoId), [103, 101, 102])
        XCTAssertEqual(entries.map(\.mediaPhotoId), [103, 101, 102])
    }

    func testCurrentPhotoListedFirstKeepsTheServerOrder() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 101))

        XCTAssertEqual(entries.map(\.shownPhotoId), [101, 102, 103])
        XCTAssertEqual(entries.map(\.mediaPhotoId), [101, 102, 103])
        XCTAssertEqual(entries.map { $0.indexData?.position }, [0, 1, 2])
        XCTAssertEqual(entries.map { $0.indexData?.totalCount }, [3, 3, 3])
    }

    // The list is fetched separately from the peer record and stops at 100 photos. Drawing the
    // current photo over the list's first photo would hide that photo.
    func testCurrentPhotoMissingFromTheListGetsItsOwnSlot() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 999))

        XCTAssertEqual(entries.map(\.shownPhotoId), [999, 101, 102, 103])
        XCTAssertEqual(entries.map(\.mediaPhotoId), [nil, 101, 102, 103])
        XCTAssertEqual(entries.map { $0.indexData?.totalCount }, [4, 4, 4, 4])
    }

    // Without a photo id nothing tells whether the record's photo is in the list, and giving it a
    // slot of its own would show it twice whenever it is.
    func testPeerRecordWithoutPhotoIdTakesTheFirstSlot() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: nil))

        XCTAssertEqual(entries.map(\.mediaPhotoId), [101, 102, 103])
    }

    // A personal photo (set by the viewer for a contact) is never in the contact's list. It takes the
    // first photo's place and the contact's current public photo is inserted after it, so the public
    // photo has to be the one moved to the front.
    func testPersonalPhotoIsFollowedByTheCurrentPublicPhotoOnce() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true), secondEntry: self.b.image)

        XCTAssertEqual(entries.map(\.shownPhotoId), [555, 102, 101, 103])
    }

    func testPersonalPhotoWithTheFirstPhotoCurrent() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true), secondEntry: self.a.image)

        XCTAssertEqual(entries.map(\.shownPhotoId), [555, 101, 102, 103])
    }

    // The public photo is not known when the gallery is opened from a chat (no cached data is read
    // there): the personal photo used to take the list's first photo's place and hide it.
    func testPersonalPhotoWithoutTheCurrentPublicPhotoHidesNothing() {
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true))

        XCTAssertEqual(entries.map(\.shownPhotoId), [555, 101, 102, 103])
    }

    func testPersonalPhotoWithAPublicPhotoMissingFromTheList() {
        let d = makePhoto(id: 104)
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true), secondEntry: d.image)

        XCTAssertEqual(entries.map(\.shownPhotoId), [555, 104, 101, 102, 103])
    }

    // The callers never pass an empty list, but the builder is public.
    func testEmptyListKeepsTheFirstSlot() {
        XCTAssertEqual(makeEntries(photos: [], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true), secondEntry: self.b.image).map(\.shownPhotoId), [555, 102])
        XCTAssertEqual(makeEntries(photos: [], firstEntry: makePeerRecordEntry(photoId: 555, isPersonal: true)).map(\.shownPhotoId), [555])
        XCTAssertEqual(makeEntries(photos: [], firstEntry: makePeerRecordEntry(photoId: 102)).map(\.shownPhotoId), [102])
    }

    func testFallbackPhotoStaysLast() {
        let fallback = makePhoto(id: 104)
        let entries = makeEntries(photos: [self.a, self.b, self.c], firstEntry: makePeerRecordEntry(photoId: 102), lastEntry: fallback.image)

        XCTAssertEqual(entries.map(\.shownPhotoId), [102, 101, 103, 104])
        XCTAssertEqual(entries.map(\.isFallback), [false, false, false, true])
    }
}

/// An open gallery takes the rebuilt photo list after a change of main photo, but keeps the image a
/// photo is shown with when that one is on disk and the rebuilt one is not: the rebuilt list draws
/// the previous main photo from its own sizes, which were never downloaded while the account record
/// was drawing it.
final class AvatarGalleryKeepingImagesTests: XCTestCase {
    private let a = makePhoto(id: 101)
    private let b = makePhoto(id: 102)
    private let c = makePhoto(id: 103)

    // Reported with the 15276 fix: setting a photo as main reloaded and re-downloaded both the new
    // main photo and the previous one. The new main photo's record files are filled from its sizes
    // when the change is stored, so only the previous one is kept.
    func testPreviousMainPhotoKeepsTheImageOnScreen() {
        let shown = [makeListEntry(self.b), makeRecordEntry(self.a), makeListEntry(self.c)]
        let rebuilt = [makeRecordEntry(self.b), makeListEntry(self.a), makeListEntry(self.c)]

        let result = avatarGalleryEntries(rebuilt, keepingImagesOf: shown, isOnDisk: isOnDisk(["102-record", "101-record", "102-list", "103-list"]))

        XCTAssertEqual(result.map(\.mediaPhotoId), [102, 101, 103])
        XCTAssertEqual(result.map(\.imageSource), [.record, .record, .list])
    }

    // The rebuilt image is the one the profile header shows and matches, and its reference stays
    // fetchable; a shown image that is not on disk has no advantage over it.
    func testShownImageNotOnDiskIsNotKept() {
        let result = avatarGalleryEntries([makeListEntry(self.a)], keepingImagesOf: [makeRecordEntry(self.a)], isOnDisk: isOnDisk([]))

        XCTAssertEqual(result.map(\.imageSource), [.list])
    }

    func testPhotoTheGalleryDoesNotShowKeepsTheRebuiltImage() {
        let d = makePhoto(id: 104)
        let result = avatarGalleryEntries([makeRecordEntry(d), makeListEntry(self.a)], keepingImagesOf: [makeListEntry(self.a)], isOnDisk: isOnDisk(["101-list"]))

        XCTAssertEqual(result.map(\.imageSource), [.record, .list])
    }

    // A personal photo's slot carries the id of the public photo after it; nothing tells which of
    // the two shown images belongs to which rebuilt slot.
    func testPhotoListedTwiceIsLeftAsRebuilt() {
        let shown = [makeListEntry(self.b), makeListEntry(self.b)]
        let rebuilt = [makeRecordEntry(self.b), makeRecordEntry(self.b)]

        XCTAssertEqual(avatarGalleryEntries(rebuilt, keepingImagesOf: shown, isOnDisk: isOnDisk(["102-list"])).map(\.imageSource), [.record, .record])
    }
}

/// `keys` are "<photo id>-list" or "<photo id>-record": the images on disk.
private func isOnDisk(_ keys: Set<String>) -> (AvatarGalleryEntry) -> Bool {
    return { entry in
        guard let id = entry.mediaPhotoId else {
            return false
        }
        switch entry.imageSource {
        case .list:
            return keys.contains("\(id)-list")
        case .record:
            return keys.contains("\(id)-record")
        case .other:
            return false
        }
    }
}

/// An entry drawn from the photo's own sizes, as the list shows every photo but the first.
private func makeListEntry(_ photo: TelegramPeerPhoto) -> AvatarGalleryEntry {
    let representations = photo.image.representations.map { ImageRepresentationWithReference(representation: $0, reference: .standalone(resource: $0.resource)) }
    return .image(photo.image.imageId, photo.image.reference, representations, [], peer, photo.date, nil, nil, nil, nil, false, nil)
}

/// An entry drawn from the account record's peer-photo resources, as the list shows its first photo.
private func makeRecordEntry(_ photo: TelegramPeerPhoto) -> AvatarGalleryEntry {
    return .image(photo.image.imageId, photo.image.reference, makePeerRecordEntry(photoId: photo.image.imageId.id).representations, [], peer, photo.date, nil, nil, nil, nil, false, nil)
}

private enum ImageSource: Equatable {
    case list
    case record
    case other
}

private let peer: EnginePeer = .user(TelegramUser(
    id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)),
    accessHash: nil,
    firstName: "U",
    lastName: nil,
    username: nil,
    phone: nil,
    photo: [],
    botInfo: nil,
    restrictionInfo: nil,
    flags: UserInfoFlags(),
    emojiStatus: nil,
    usernames: [],
    storiesHidden: nil,
    nameColor: nil,
    backgroundEmojiId: nil,
    profileColor: nil,
    profileBackgroundEmojiId: nil,
    subscriberCount: nil,
    verificationIconFileId: nil
))

private func makeEntries(photos: [TelegramPeerPhoto], firstEntry: AvatarGalleryEntry, secondEntry: TelegramMediaImage? = nil, lastEntry: TelegramMediaImage? = nil) -> [AvatarGalleryEntry] {
    return avatarGalleryUserEntries(peer: peer, peerReference: .user(id: 1, accessHash: 1), photos: photos, firstEntry: firstEntry, secondEntry: secondEntry, lastEntry: lastEntry)
}

/// A list photo as `telegramMediaImageFromApiPhoto` makes it: cloud photo-size resources.
private func makePhoto(id: Int64) -> TelegramPeerPhoto {
    let representations = [(160, "a"), (640, "c")].map { side, sizeSpec in
        return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(side), height: Int32(side)), resource: CloudPhotoSizeMediaResource(datacenterId: 2, photoId: id, accessHash: 1, sizeSpec: sizeSpec, size: nil, fileReference: nil), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
    }
    let image = TelegramMediaImage(
        imageId: EngineMedia.Id(namespace: Namespaces.Media.CloudImage, id: id),
        representations: representations,
        immediateThumbnailData: nil,
        reference: .cloud(imageId: id, accessHash: 1, fileReference: nil),
        partialReference: nil,
        flags: []
    )
    return TelegramPeerPhoto(image: image, reference: image.reference, date: Int32(id), index: 0, totalCount: 0, messageId: nil)
}

/// The entry `initialAvatarGalleryEntries` makes from the peer record: `TelegramUser.photo`, i.e. the
/// peer-photo resources `parsedTelegramProfilePhoto` builds from `userProfilePhoto`.
private func makePeerRecordEntry(photoId: Int64?, isPersonal: Bool = false) -> AvatarGalleryEntry {
    let representations = [
        (PixelDimensions(width: 80, height: 80), CloudPeerPhotoSizeSpec.small),
        (PixelDimensions(width: 640, height: 640), CloudPeerPhotoSizeSpec.fullSize)
    ].map { dimensions, sizeSpec -> ImageRepresentationWithReference in
        let resource = CloudPeerPhotoSizeMediaResource(datacenterId: 2, photoId: photoId, sizeSpec: sizeSpec, volumeId: nil, localId: nil)
        return ImageRepresentationWithReference(
            representation: TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: isPersonal),
            reference: .standalone(resource: resource)
        )
    }
    return .topImage(representations, [], peer, nil, nil, nil)
}

private extension AvatarGalleryEntry {
    /// The photo the entry draws.
    var shownPhotoId: Int64? {
        guard let resource = self.representations.last?.representation.resource else {
            return nil
        }
        if let resource = resource as? CloudPeerPhotoSizeMediaResource {
            return resource.photoId
        } else if let resource = resource as? CloudPhotoSizeMediaResource {
            return resource.photoId
        } else {
            return nil
        }
    }

    /// The photo the entry acts on (Set as Main, Remove).
    var mediaPhotoId: Int64? {
        if case let .image(id, _, _, _, _, _, _, _, _, _, _, _) = self {
            return id.id
        } else {
            return nil
        }
    }

    var imageSource: ImageSource {
        switch self.representations.last?.representation.resource {
        case is CloudPhotoSizeMediaResource:
            return .list
        case is CloudPeerPhotoSizeMediaResource:
            return .record
        default:
            return .other
        }
    }

    var isFallback: Bool {
        if case let .image(_, _, _, _, _, _, _, _, _, _, isFallback, _) = self {
            return isFallback
        } else {
            return false
        }
    }
}
